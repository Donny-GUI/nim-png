import std/os
import tables
import strutils
import zlib 

type
  ByteIterator = object
    bytes: seq[byte]
    index: int
    chunkSize: int

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
  result = uncompress(data, data.len)
  
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

  while true:
    nextSize = biter.nextU32()
    nextChunk = biter.nextChunk(nextSize)
    ccIter = BytesIterator(nextChunk)
    chunkTag = ccIter.nextString(8)
    chunkTags.add(chunkTag)

    if chunkTag == "IDHR":
      pngHeaderData = readHeaderChunk(ccIter.remainingBytes())
    elif chunkTag == "PLTE":
      pngPaletteData = readPaletteChunk(ccIter.remainingBytes())
    elif chunkTag == "IDAT":
      pngImageData = readDataChunk(ccIter.remainingBytes())
    


    elif chunkTag == "IEND":
      break

    nextAmount = biter.index + 4 
    if nextAmount > byteLength:
      break 
  
