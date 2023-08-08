import os
import strutils
import tables
import zlib


type 
  PNGFile = ref object 
    headerWidth: uint32
    headerHeight: uint32
    headerBitDepth: uint8
    headerColorType: uint8
    headerCompressionMethod: uint8
    headerFilterMethod: uint8
    headerInterlaceMethod: uint8
    animationNumberOfFrames: uint32
    animationNumberOfPlays: uint32
    frameControlSequenceNumber: uint32
    frameControlWidth: uint32
    frameControlHeight: uint32
    frameControlXOffset: uint32
    frameControlYOffset: uint32
    frameControlDelayNum: uint16
    frameControlDelayDen: uint16
    frameControlDisposeOp: uint8
    frameControlBlendOp: uint8
    frameDataChunkSequenceNumber: uint32
    imageLastModificationYear: uint32
    imageLastModificationMonth: uint8
    imageLastModificationDay: uint8
    imageLastModificationHour: uint8
    imageLastModificationMinute: uint8
    imageLastModificationSecond: uint8
    suggestedPaletteName: uint8
    suggestedPaletteNullSeparator: uint8
    suggestedPaletteSampleDepth: uint8
    suggestedPaletteData: seq[byte]
    physicalPixelDimensionsPixelsPerUnitXAxis: uint32
    physicalPixelDimensionsPixelsPerUnitYAxis: uint32
    physicalPixelDimensionsPixelsPerUnitSpecifier: uint8
    imageHistogramFrequency: uint16
    imageHistogramData: seq[byte]
    backgroundColorGreyScale: uint16
    backgroundColorRed: uint16
    backgroundColorGreen: uint16
    backgroundColorBlue: uint16
    backgroundColorPaletteIndex: uint8
    internationalTextualDataKeyword: uint8
    internationalTextualDataCompressionFlag: uint8
    internationalTextualDataCompressionMethod: uint8
    internationalTextualDataLanguageTag: uint8
    internationalTextualDataTranslatedKeyword: uint8
    internationalTextualDataText: seq[byte]
    compressedTextualDataKeyword: seq[byte]
    compressedTextualDataKeywordValue: uint8 
    compressedTextualDataCompressionMethod: uint8 
    compressedTextualDataDataStream: seq[byte]
    textualDataKeyword: seq[byte]
    textualDataKeywordValue: uint8
    textualDataTextString1: seq[byte]
    textualDataTextString: string
    palette: seq[seq[uint8]]
    imageData: seq[byte]

type
  BytesRef = ref object
    bytes: seq[byte]
    index: int

proc newBytesRef(bytes: seq[byte]): BytesRef =
  result = BytesRef(bytes: bytes, index: 0)

type
  ByteIterator = ref object
    bytes: BytesRef

proc initByteIterator(bytes: seq[byte]): ByteIterator =
  result.bytes = newBytesRef(bytes)

proc nextString(it: var ByteIterator, size: int): string =
  var buffer: string
  for i in 0..<size:
    if it.bytes.index < len(it.bytes.bytes):
      buffer.add char(it.bytes.bytes[it.bytes.index])
      it.bytes.index += 1
    else:
      break
  return buffer

proc nextU8(iter: var ByteIterator): uint8 =
  if iter.bytes.index >= iter.bytes.bytes.len:
    raise newException(ValueError, "No more bytes to read")
  let value = iter.bytes.bytes[iter.bytes.index]
  iter.bytes.index += 1
  return value

proc nextU16(iter: var ByteIterator): uint16 =
  if iter.bytes.index + 1 >= iter.bytes.bytes.len:
    raise newException(ValueError, "Not enough bytes to read uint16")
  let value = (ord(iter.bytes.bytes[iter.bytes.index]) shl 8) or ord(iter.bytes.bytes[iter.bytes.index + 1])
  iter.bytes.index += 2
  return value.uint16

proc nextU32(iter: var ByteIterator): uint32 =
  if iter.bytes.index + 3 >= iter.bytes.bytes.len:
    raise newException(ValueError, "Not enough bytes to read uint32")
  let value = (ord(iter.bytes.bytes[iter.bytes.index]) shl 24) or
              (ord(iter.bytes.bytes[iter.bytes.index + 1]) shl 16) or
              (ord(iter.bytes.bytes[iter.bytes.index + 2]) shl 8) or
              ord(iter.bytes.bytes[iter.bytes.index + 3])
  iter.bytes.index += 4
  return value.uint32

proc nextU64(iter: var ByteIterator): uint64 =
  if iter.bytes.index + 7 >= iter.bytes.bytes.len:
    raise newException(ValueError, "Not enough bytes to read uint64")
  let value = uint64(iter.bytes.bytes[iter.bytes.index]) shl 56 or
              uint64(iter.bytes.bytes[iter.bytes.index + 1]) shl 48 or
              uint64(iter.bytes.bytes[iter.bytes.index + 2]) shl 40 or
              uint64(iter.bytes.bytes[iter.bytes.index + 3]) shl 32 or
              uint64(iter.bytes.bytes[iter.bytes.index + 4]) shl 24 or
              uint64(iter.bytes.bytes[iter.bytes.index + 5]) shl 16 or
              uint64(iter.bytes.bytes[iter.bytes.index + 6]) shl 8 or
              uint64(iter.bytes.bytes[iter.bytes.index + 7])
  iter.bytes.index += 8
  return value.uint64

proc readFileToBytes(filePath: string): seq[byte] =
  var file = open(filePath, fmRead)
  var fileSize = os.getFileSize(filePath)
  var bytes: seq[byte]
  setLen(bytes, fileSize)
  discard readBytes(file, bytes, 0, fileSize)  # Use discard to ignore the return value
  file.close()
  return bytes


proc getBytes(filePath: string): seq[byte] = 
  var file = open(filePath, fmRead)
  var bytes: seq[byte]
  discard readBytes(file, bytes, 0, os.getFileSize(filePath))
  return bytes

proc readHeaderChunk(bytes: seq[byte]): Table = 
  var headerProps: Table[string, int] = initTable[string, string]()
  var tags: seq[seq] = [(4, "width"), (4, "height"), (1, "bit depth"), (1, "color type"), (1, "compression method"), (1, "filter method"), (1, "interlace method") ]
  var tagLen = len(tags)
  var citer = initByteIterator(bytes)
  for i in 0..tagLen:
    if tags[0] == 4:
      headerProps[tags[i][1]] = citer.nextU32()
    else:
      headerProps[tags[i][1]] = citer.nextU8()
  return headerProps

proc readPaletteChunk(bytes: seq[byte]): seq[seq[uint8]] = 
  var palette: seq[seq[uint8]] = @[]
  var numberOfColors = len(bytes).div(3)
  var count: int = 0
  var arr: seq[uint8]
  var citer = initByteIterator(bytes)
  for i in 0..numberOfColors:
    arr.add(citer.nextU8())
    count+=1
    if count == 2:
      count = 0
      palette.add(arr)
  return palette

proc remainingBytes(it: var ByteIterator): seq[byte] =
  var buffer: seq[byte] = @[]
  for i in it.bytes.index..it.bytes.bytes.len:
    buffer.add(it.bytes.bytes[i])
  return buffer

proc nextChunk(it: var ByteIterator, size:int): seq[byte] =
  var buffer: seq[byte]
  for i in 0..size:
    buffer.add(it.nextU8())
  return buffer 

proc keepGoing(it: var ByteIterator, size:int) =  
  it.bytes.index+=size

proc uint8SeqToString(seq: seq[uint8]): string =
  var result = newString(seq.len)
  for i, value in seq:
    result[i] = char(value)
  return result

proc readDataChunk(bytes: seq[byte]): auto =
  var r: seq[uint8]
  var rptr: ptr uint8 = addr r[0]
  var refPtr: ptr byte = unsafeAddr bytes[0]
  var dataculong = system.culong(bytes.len)
  discard uncompress(rptr, dataculong, refPtr, dataculong)
  return r


proc readPNG(filePath: string) =
  let nullByte: uint8 = 0
  var nullPtr: ptr uint8 = unsafeAddr nullByte
  var bytes: seq[byte] = readFileToBytes(filePath) 
  var biter = initByteIterator(bytes)
  var ccIter: ByteIterator
  var byteLength = len(bytes)
  var signature: string = biter.nextString(8)
  var nextSize: uint32
  var nexttchunk: seq[byte]
  var chunks: seq[seq[byte]]
  var nextAmount: int
  var chunkTag: string
  var chunkTags: seq[string] = @[]
  # PNG Properties
  # Description of variable:
  #  the section of the data then the name of the value  header(inside the IHDR)Width(the value of the width) -> headerWidth
  var headerWidth: uint32
  var headerHeight: uint32
  var headerBitDepth: uint8
  var headerColorType: uint8
  var headerCompressionMethod: uint8
  var headerFilterMethod: uint8
  var headerInterlaceMethod: uint8
  var animationNumberOfFrames: uint32
  var animationNumberOfPlays: uint32
  var frameControlSequenceNumber: uint32
  var frameControlWidth: uint32
  var frameControlHeight: uint32
  var frameControlXOffset: uint32
  var frameControlYOffset: uint32
  var frameControlDelayNum: uint16
  var frameControlDelayDen: uint16
  var frameControlDisposeOp: uint8
  var frameControlBlendOp: uint8
  var frameDataChunkSequenceNumber: uint32
  var imageLastModificationYear: uint32
  var imageLastModificationMonth: uint8
  var imageLastModificationDay: uint8
  var imageLastModificationHour: uint8
  var imageLastModificationMinute: uint8
  var imageLastModificationSecond: uint8
  var suggestedPaletteName: uint8
  var suggestedPaletteNullSeparator: uint8
  var suggestedPaletteSampleDepth: uint8
  var suggestedPaletteData: seq[byte]
  var physicalPixelDimensionsPixelsPerUnitXAxis: uint32
  var physicalPixelDimensionsPixelsPerUnitYAxis: uint32
  var physicalPixelDimensionsPixelsPerUnitSpecifier: uint8
  var imageHistogramFrequency: uint16
  var imageHistogramData: seq[byte]
  var backgroundColorGreyScale: uint16
  var backgroundColorRed: uint16
  var backgroundColorGreen: uint16
  var backgroundColorBlue: uint16
  var backgroundColorPaletteIndex: uint8
  var internationalTextualDataKeyword: uint8
  var internationalTextualDataCompressionFlag: uint8
  var internationalTextualDataCompressionMethod: uint8
  var internationalTextualDataLanguageTag: uint8
  var internationalTextualDataTranslatedKeyword: uint8
  var internationalTextualDataText: seq[byte]
  var compressedTextualDataKeyword: seq[byte]
  var compressedTextualDataKeywordValue: uint8 
  var compressedTextualDataCompressionMethod: uint8 
  var compressedTextualDataDataStream: seq[byte]
  var textualDataKeyword: seq[byte]
  var textualDataKeywordValue: uint8
  var textualDataTextString1: seq[byte]
  var textualDataTextString: string
  var palette: seq[seq[uint8]] = @[]
  var imageData: seq[byte]

  while true:
    nextSize = biter.nextU32()
    nexttchunk = biter.nextChunk(nextSize.int)
    ccIter = initByteIterator(nexttchunk)
    chunkTag = ccIter.nextString(8)
    chunkTags.add(chunkTag)

    if chunkTag == "IDHR":
      headerWidth = ccIter.nextU32()
      headerHeight = ccIter.nextU32()
      headerBitDepth = ccIter.nextU8()
      headerColorType = ccIter.nextU8()
      headerCompressionMethod = ccIter.nextU8()
      headerFilterMethod = ccIter.nextU8()
      headerInterlaceMethod = ccIter.nextU8()
    elif chunkTag == "PLTE":
      palette = readPaletteChunk(ccIter.remainingBytes())
    elif chunkTag == "IDAT":
      imageData = readDataChunk(ccIter.remainingBytes())
    elif chunkTag == "acTL":
      animationNumberOfFrames = ccIter.nextU32()
      animationNumberOfPlays = ccIter.nextU32()
    elif chunkTag == "fcTL":
      frameControlSequenceNumber = ccIter.nextU32()
      frameControlWidth = ccIter.nextU32()
      frameControlHeight = ccIter.nextU32()
      frameControlXOffset = ccIter.nextU32()
      frameControlYOffset = ccIter.nextU32()
      frameControlDelayNum = ccIter.nextU16()
      frameControlDelayDen = ccIter.nextU16()
      frameControlDisposeOp = ccIter.nextU8()
      frameControlBlendOp = ccIter.nextU8()
    elif chunkTag == "ifAT":
      frameDataChunkSequenceNumber = ccIter.nextU32()
      # incomplete
    elif chunkTag == "tIME":
      imageLastModificationYear = ccIter.nextU16()
      imageLastModificationMonth = ccIter.nextU8()
      imageLastModificationDay = ccIter.nextU8()
      imageLastModificationHour = ccIter.nextU8()
      imageLastModificationMinute = ccIter.nextU8()
      imageLastModificationSecond = ccIter.nextU8()
    elif chunkTag == "eXIf":
      # INCOMPLETE
      continue  
    elif chunkTag == "sPLT":
      suggestedPaletteName = ccIter.nextU8()
      suggestedPaletteNullSeparator = ccIter.nextU8()
      suggestedPaletteSampleDepth = ccIter.nextU8()
      suggestedPaletteData = ccIter.remainingBytes()
    elif chunkTag == "pHYs":
      physicalPixelDimensionsPixelsPerUnitXAxis = ccIter.nextU32()
      physicalPixelDimensionsPixelsPerUnitYAxis = ccIter.nextU32()
      physicalPixelDimensionsPixelsPerUnitSpecifier = ccIter.nextU8()
    elif chunkTag == "hIST":
      imageHistogramFrequency = ccIter.nextU16()
      imageHistogramData = ccIter.remainingBytes()
    elif chunkTag == "bKGD":
      backgroundColorGreyScale = ccIter.nextU16()
      backgroundColorRed = ccIter.nextU16()
      backgroundColorGreen = ccIter.nextU16()
      backgroundColorBlue = ccIter.nextU16()
      backgroundColorPaletteIndex = ccIter.nextU8()
    elif chunkTag == "iTXt":
      internationalTextualDataKeyword = ccIter.nextU8()
      ccIter.keepGoing(1)
      internationalTextualDataCompressionFlag = ccIter.nextU8()
      internationalTextualDataCompressionMethod = ccIter.nextU8()
      internationalTextualDataLanguageTag = ccIter.nextU8()
      ccIter.keepGoing(1)
      internationalTextualDataTranslatedKeyword = ccIter.nextU8()
      ccIter.keepGoing(1)
      internationalTextualDataText = ccIter.remainingBytes()
    elif chunkTag == "zTXt": # Compressed Textual Data Chunk
      while compressedTextualDataKeywordValue != nullByte:
        compressedTextualDataKeywordValue = ccIter.nextU8()
        compressedTextualDataKeyword.add(compressedTextualDataKeywordValue)
      compressedTextualDataCompressionMethod = ccIter.nextU8()
      compressedTextualDataDataStream = ccIter.remainingBytes()
    elif chunkTag == "tEXt":
      while textualDataKeywordValue != nullByte:
        textualDataKeywordValue = ccIter.nextU8()
        textualDataKeyword.add(textualDataKeywordValue)
      textualDataTextString1 = ccIter.remainingBytes()
      textualDataTextString = uint8SeqToString(textualDataTextString1)
    elif chunkTag == "IEND":
      break
    nextAmount = biter.bytes.index + 4 
    if nextAmount > byteLength:
      break

proc readPNG(filePath: string): PNGFile =
  let nullByte: uint8 = 0
  var nullPtr: ptr uint8 = unsafeAddr nullByte
  var bytes: seq[byte] = readFileToBytes(filePath) 
  var biter = initByteIterator(bytes)
  var ccIter: ByteIterator
  var byteLength = len(bytes)
  var signature: string = biter.nextString(8)
  var nextSize: uint32
  var nexttchunk: seq[byte]
  var chunks: seq[seq[byte]]
  var nextAmount: int
  var chunkTag: string
  var chunkTags: seq[string] = @[]
  var png: PNGFile

  while true:
    nextSize = biter.nextU32()
    nexttchunk = biter.nextChunk(nextSize.int)
    ccIter = initByteIterator(nexttchunk)
    chunkTag = ccIter.nextString(8)
    chunkTags.add(chunkTag)

    if chunkTag == "IDHR":
      png.headerWidth = ccIter.nextU32()
      png.headerHeight = ccIter.nextU32()
      png.headerBitDepth = ccIter.nextU8()
      png.headerColorType = ccIter.nextU8()
      png.headerCompressionMethod = ccIter.nextU8()
      png.headerFilterMethod = ccIter.nextU8()
      png.headerInterlaceMethod = ccIter.nextU8()
    elif chunkTag == "PLTE":
      png.palette = readPaletteChunk(ccIter.remainingBytes())
    elif chunkTag == "IDAT":
      png.imageData = readDataChunk(ccIter.remainingBytes())
    elif chunkTag == "acTL":
      png.animationNumberOfFrames = ccIter.nextU32()
      png.animationNumberOfPlays = ccIter.nextU32()
    elif chunkTag == "fcTL":
      png.frameControlSequenceNumber = ccIter.nextU32()
      png.frameControlWidth = ccIter.nextU32()
      png.frameControlHeight = ccIter.nextU32()
      png.frameControlXOffset = ccIter.nextU32()
      png.frameControlYOffset = ccIter.nextU32()
      png.frameControlDelayNum = ccIter.nextU16()
      png.frameControlDelayDen = ccIter.nextU16()
      png.frameControlDisposeOp = ccIter.nextU8()
      png.frameControlBlendOp = ccIter.nextU8()
    elif chunkTag == "ifAT":
      png.frameDataChunkSequenceNumber = ccIter.nextU32()
      # incomplete
    elif chunkTag == "tIME":
      png.imageLastModificationYear = ccIter.nextU16()
      png.imageLastModificationMonth = ccIter.nextU8()
      png.imageLastModificationDay = ccIter.nextU8()
      png.imageLastModificationHour = ccIter.nextU8()
      png.imageLastModificationMinute = ccIter.nextU8()
      png.imageLastModificationSecond = ccIter.nextU8()
    elif chunkTag == "eXIf":
      # INCOMPLETE
      continue  
    elif chunkTag == "sPLT":
      png.suggestedPaletteName = ccIter.nextU8()
      png.suggestedPaletteNullSeparator = ccIter.nextU8()
      png.suggestedPaletteSampleDepth = ccIter.nextU8()
      png.suggestedPaletteData = ccIter.remainingBytes()
    elif chunkTag == "pHYs":
      png.physicalPixelDimensionsPixelsPerUnitXAxis = ccIter.nextU32()
      png.physicalPixelDimensionsPixelsPerUnitYAxis = ccIter.nextU32()
      png.physicalPixelDimensionsPixelsPerUnitSpecifier = ccIter.nextU8()
    elif chunkTag == "hIST":
      png.imageHistogramFrequency = ccIter.nextU16()
      png.imageHistogramData = ccIter.remainingBytes()
    elif chunkTag == "bKGD":
      png.backgroundColorGreyScale = ccIter.nextU16()
      png.backgroundColorRed = ccIter.nextU16()
      png.backgroundColorGreen = ccIter.nextU16()
      png.backgroundColorBlue = ccIter.nextU16()
      png.backgroundColorPaletteIndex = ccIter.nextU8()
    elif chunkTag == "iTXt":
      png.internationalTextualDataKeyword = ccIter.nextU8()
      ccIter.keepGoing(1)
      png.internationalTextualDataCompressionFlag = ccIter.nextU8()
      png.internationalTextualDataCompressionMethod = ccIter.nextU8()
      png.internationalTextualDataLanguageTag = ccIter.nextU8()
      ccIter.keepGoing(1)
      png.internationalTextualDataTranslatedKeyword = ccIter.nextU8()
      ccIter.keepGoing(1)
      png.internationalTextualDataText = ccIter.remainingBytes()
    elif chunkTag == "zTXt": # Compressed Textual Data Chunk
      while png.compressedTextualDataKeywordValue != nullByte:
        png.compressedTextualDataKeywordValue = ccIter.nextU8()
        png.compressedTextualDataKeyword.add(png.compressedTextualDataKeywordValue)
      png.compressedTextualDataCompressionMethod = ccIter.nextU8()
      png.compressedTextualDataDataStream = ccIter.remainingBytes()
    elif chunkTag == "tEXt":
      while png.textualDataKeywordValue != nullByte:
        png.textualDataKeywordValue = ccIter.nextU8()
        png.textualDataKeyword.add(png.textualDataKeywordValue)
      png.textualDataTextString1 = ccIter.remainingBytes()
      png.textualDataTextString = uint8SeqToString(png.textualDataTextString1)
    elif chunkTag == "IEND":
      break
    nextAmount = biter.bytes.index + 4 
    if nextAmount > byteLength:
      break
  return png


