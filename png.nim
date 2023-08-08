import std/os
import tables
import strutils
import zlib 
import ctypes

type
  ByteIterator = object
    bytes: seq[byte]
    index: int
    chunkSize: int

type
  PNGFile = object
    filePath: cstring
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
    imageLastModificationYear: uint16
    imageLastModificationMonth: uint8
    imageLastModificationDay: uint8
    imageLastModificationHour: uint8
    imageLastModificationMinute: uint8
    imageLastModificationSecond: uint8
    suggestedPaletteName: uint8
    suggestedPaletteNullSeparator: uint8
    suggestedPaletteSampleDepth: uint8
    suggestedPaletteData: openArray[uint8 or int8]
    physicalPixelDimensionsPixelsPerUnitXAxis: uint32
    physicalPixelDimensionsPixelsPerUnitYAxis: uint32
    physicalPixelDimensionsPixelsPerUnitSpecifier: uint8
    imageHistogramFrequency: uint16
    imageHistogramData: openArray[uint8 or int8]
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
    internationalTextualDataText: openArray[uint8 or int8]
    compressedTextualDataKeyword: array[uint8 or int8]
    compressedTextualDataKeywordValue: uint8 
    compressedTextualDataCompressionMethod: uint8 
    compressedTextualDataDataStream: openArray[uint8 or int8]
    textualDataKeyword: openArray[uint8 or int8]
    textualDataKeywordValue: uint8
    textualDataTextString1: openArray[uint8 or int8]
    textualDataTextString: string
    palette: openArray[tuple[int, int, int]]
    imageData: openArray[uint8]
    

const 
  dtString = 0
  dtInt = 1
  greyScaleString: string = "GrayScale"
  greyScaleInt: int8 = 0 
  trueColorString: string = "TrueColor"
  trueColorInt: int8 = 2
  indexedColorString: string = "IndexedColor"
  indexedColorInt: int8 = 4
  greyScaleWithAlphaString: string = "GreyScaleWithAlpha"
  greyScaleIntWithAlphaInt: int8 = 6 
  trueColorWithAlphaString: string = "TrueColorWithAlpha"
  trueColorIntWithAlphaInt: int8 = 8


const chunkNames: seq[string] = [
  "IHDR", "IDAT", "IEND", "PLTE", 
  "bKGD", "cHRM", "dSIG", "eXIF", 
  "gAMA", "hIST", "iCCP", "iTXt", 
  "pHYs", "sBIT", "sPLT", "sRGB", 
  "sTER", "tEXT", "tIME", "tRNS", 
  "zTXt"
]

proc getBlendOp(value: uint8): string = 
  if value == 0:
    result = "Source"
  else:
    result = "Over"

proc getDisposeOp(value: uint8): string = 
  case value:
    of 0:
      result = "None"
    of 1:
      result = "Background"
    of 2:
      result = "Previous"

proc getColorType(value: int8): string =
  #[
    Read the color type from int to string value
  ]# 
  case value:
    of 0:
      result = greyScaleString
    of 2:
      result = trueColorString
    of 4:
      result = indexedColorString
    of 6:
      result = greyScaleWithAlphaString
    of 8:
      result = trueColorWithAlphaString

proc initByteIterator(bytes: seq[byte]): ByteIterator =
  #[
    initilize a new ByteIterator with bytes
  ]#
  result.bytes = bytes
  result.index = 0

proc hasNext(it: ByteIterator): bool =
  return it.index < it.bytes.len

proc nextByte(it: var ByteIterator): byte =
  if hasNext(it):
    let byteValue = it.bytes[it.index]
    it.index += 1
    return byteValue  

proc nextChunk(it: var ByteIterator, size: int): openArray[uint8, int8] = 
  var buffer: openArray[uint8 or int8]
  var bt: byte
  for i in 0..<size:
    if it.hasNext():
      bt = nextByte(it)
      buffer.add(bt)
  return buffer

proc keepGoing(it: ByteIterator, distance: int8) = 
  it.index+=distance 

proc bytesToDecimal(bytes: seq[byte]): int =
  var r: int = 0
  for bt in bytes:
    r = r * 256 + int(bt)
  return r

proc nextChars(it: BytesIterator, size:int): openArray[char] =
  var buffer: openArray[char]
  var ui: uint8
  for i in 0..size:
    ui = it.nextU8()
    buffer.add(chr(ui))
    fbi.index+=1
  return buffer

proc nextU8(it: BytesIterator): uint8 =
  var buffer = it.nextByte()
  result = int(buffer)

proc nextU16(it: BytesIterator): uint16 =
  var bytes: openArray[uint8 or uint] = it.nextChunk(2)
  result = (ord(bytes[0]) shl 8) or ord(bytes[1])

proc nextU32(it: BytesIterator): uint32 =
  var bytes: openArray[uint8 or int8] = it.nextChunk(4)
  result = (ord(bytes[0]) shl 24) or (ord(bytes[1]) shl 16) or (ord(bytes[2]) shl 8) or ord(bytes[3])

proc nextU64(it: BytesIterator): uint64 =
  var bytes: openArray[uint8 or int8] = it.nextChunk(8)
  result = uint64(bytes[0]) shl 56 or
           uint64(bytes[1]) shl 48 or
           uint64(bytes[2]) shl 40 or
           uint64(bytes[3]) shl 32 or
           uint64(bytes[4]) shl 24 or
           uint64(bytes[5]) shl 16 or
           uint64(bytes[6]) shl 8 or
           uint64(bytes[7])

proc remainingBytes(bit: BytesIterator): openArray[uint8 or int8] = 
  var bytes: openArray[uint8 or int8] = bit.bytes[bit.index..bit.length]
  return bytes

proc bytesToString(bytes: seq[byte]): string =
  result = newString(bytes.len)
  for i, bt in pairs(bytes):
    result[i] = chr(bt)

proc nextString(it: var ByteIterator, size: int): string = 
  var byteSequence: openArray[uint8 or int8] = it.nextChunk(size)
  result = newString(size)
  for i, bt in pairs(byteSequence):
    result[i] = chr(bt)

proc getBytes(filePath: string): seq[byte] = 
  var file = open(filePath, fmRead)
  var bytes: seq[byte]
  discard readBytes(file, bytes, 0, os.getFileSize(filePath))
  return bytes

proc readHeaderChunk(bytes: seq[byte]): Table = 
  var headerProps: Table[string, int] = initTable[string, string]()
  var tags: seq[tuple[int, string]] = [
    (4, "width"), (4, "height"), (1, "bit depth"), 
    (1, "color type"), (1, "compression method"), 
    (1, "filter method"), (1, "interlace method") ]
  var tagLen = len(tags)
  var citer = BytesIterator(bytes)
  for i in 0..tagLen:
    if tags[0] == 4:
      headerProps[tags[i][1]] = citer.nextU32()
    else:
      headerProps[tags[i][1]] = citer.nextU8()
  return headerProps

proc readPaletteChunk(bytes: openArray[uint8 or int]): openArray[tuple[int, int, int]] = 
  var palette: openArray[tuple[int, int, int]]
  var numberOfColors = len(bytes)//3
  var count: int = 0
  var arr: array[int, int, int]
  var citer = BytesIterator(bytes)
  for i in 0..numberOfColors:
    arr[i] = citer.nextByte()
    count+=1
    if count == 2:
      count = 0
      palette.add(arr)
  return palette

proc readDataChunk(bytes: openArray[uint8 or int8]): openArray =
  var data: seq[uint8] = bytes.toSeq()
  var bytesPointer: ptr = ptr(bytes)
  var dataculong = ctypes.culong(data.len)
  var resultPointer: ptr = ptr(result)
  uncompress(resultPointer, bytesPointer, dataculong)
  
proc readPNG(filePath: string) =
  var bytes = getBytes(filePath) 
  var biter = ByteIterator(bytes)
  var byteLength = len(bytes)
  var signature: string = biter.nextString(8)
  var nextSize: uint32
  var nextChunk: openArray[uint8 or int8]
  var chunks: openArray[openArray[uint8 or int8]]
  var nextAmount: uint32
  var chunkTag: string
  var chunkTags: openArray[string] = @[]
  var props: openArray[string, ]
  var pngHeaderData: Table[string, string]
  var pngPaletteData: openArray[tuple[int, int, int]]
  var pngImageData: string
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
  var imageLastModificationYear: uint16
  var imageLastModificationMonth: uint8
  var imageLastModificationDay: uint8
  var imageLastModificationHour: uint8
  var imageLastModificationMinute: uint8
  var imageLastModificationSecond: uint8
  var suggestedPaletteName: uint8
  var suggestedPaletteNullSeparator: uint8
  var suggestedPaletteSampleDepth: uint8
  var suggestedPaletteData: openArray[uint8 or int8]
  var physicalPixelDimensionsPixelsPerUnitXAxis: uint32
  var physicalPixelDimensionsPixelsPerUnitYAxis: uint32
  var physicalPixelDimensionsPixelsPerUnitSpecifier: uint8
  var imageHistogramFrequency: uint16
  var imageHistogramData: openArray[uint8 or int8]
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
  var internationalTextualDataText: openArray[uint8 or int8]
  var compressedTextualDataKeyword: array[uint8 or int8]
  var compressedTextualDataKeywordValue: uint8 
  var compressedTextualDataCompressionMethod: uint8 
  var compressedTextualDataDataStream: openArray[uint8 or int8]
  var textualDataKeyword: openArray[uint8 or int8]
  var textualDataKeywordValue: uint8
  var textualDataTextString1: openArray[uint8 or int8]
  var textualDataTextString: string
  var palette: openArray[tuple[int, int, int]]
  var imageData: openArray[uint8]

  while true:
    nextSize = biter.nextU32()
    nextChunk = biter.nextChunk(nextSize)
    ccIter = BytesIterator(nextChunk)
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
      while compressedTextualDataKeyword != 0x00:
        compressedTextualDataKeywordValue = ccIter.nextU8()
        compressedTextualDataKeyword.add(compressedTextualDataKeywordValue)
      compressedTextualDataCompressionMethod = ccIter.nextU8()
      compressedTextualDataDataStream = ccIter.remainingBytes()
    elif chunkTag == "tEXt":
      while textualDataKeywordValue != 0x00:
        textualDataKeywordValue = ccIter.nextU8()
        textualDataKeyword.add(textualDataKeywordValue)
      textualDataTextString1 = ccIter.remainingBytes()
      textualDataTextString = bytesToString(textualDataTextString1)
    elif chunkTag == "IEND":
      break
    nextAmount = biter.index + 4 
    if nextAmount > byteLength:
      break 

proc initPNGFile(filePath: cstring): PNGFile = 
  result = PNGFile
  result.filePath = filePath 

proc read(pngObject: PNGFile) =
  var bytes = getBytes(pngObject.filePath) 
  var biter = ByteIterator(bytes)
  var byteLength = len(bytes)
  var signature: string = biter.nextString(8)
  var nextSize: uint32
  var nextChunk: openArray[uint8 or int8]
  var chunks: openArray[openArray[uint8 or int8]]
  var nextAmount: uint32
  var chunkTag: string
  var chunkTags: openArray[string] = @[]
  var props: openArray[string, ]
  var png: PNGFile

  while true:
    nextSize = biter.nextU32()
    nextChunk = biter.nextChunk(nextSize)
    ccIter = BytesIterator(nextChunk)
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
      while png.compressedTextualDataKeyword != 0x00:
        png.compressedTextualDataKeywordValue = ccIter.nextU8()
        png.compressedTextualDataKeyword.add(compressedTextualDataKeywordValue)
      png.compressedTextualDataCompressionMethod = ccIter.nextU8()
      png.compressedTextualDataDataStream = ccIter.remainingBytes()
    elif chunkTag == "tEXt":
      while png.textualDataKeywordValue != 0x00:
        png.textualDataKeywordValue = ccIter.nextU8()
        png.textualDataKeyword.add(textualDataKeywordValue)
      png.textualDataTextString1 = ccIter.remainingBytes()
      png.textualDataTextString = bytesToString(textualDataTextString1)
    elif chunkTag == "IEND":
      break
    nextAmount = biter.index + 4 
    if nextAmount > byteLength:
      break
  return png
  
