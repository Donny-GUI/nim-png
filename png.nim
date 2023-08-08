import std/os
import tables
import strutils


type
  ByteIterator = object
    bytes: seq[byte]
    index: int
    chunkSize: int

type 
  Chunk = object
    length: uint8
    name: string
    data: seq[uint8]
    crc: array[4, uint8]

type 
  Tag = tuple[byteCount: int, valueName: string]

const 
  dtString = 0
  dtInt = 1

const chunkNames: seq[string] = [
  "IHDR", "IDAT", "IEND", "PLTE", 
  "bKGD", "cHRM", "dSIG", "eXIF", 
  "gAMA", "hIST", "iCCP", "iTXt", 
  "pHYs", "sBIT", "sPLT", "sRGB", 
  "sTER", "tEXT", "tIME", "tRNS", 
  "zTXt"
]

type  
    DataTag = tuple[bitSize: int, valueName: string, dataType: int]

proc initByteIterator(bytes: seq[byte]): ByteIterator =
  result.bytes = bytes
  result.index = 0

proc hasNext(it: ByteIterator): bool =
  return it.index < it.bytes.len

proc nextByte(it: var ByteIterator): byte =
  if hasNext(it):
    let byteValue = it.bytes[it.index]
    it.index += 1
    return byteValue  

proc nextChunk(it: var ByteIterator, size: int): seq[byte] = 
  var buffer: seq[byte]
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

proc nextDecimal(it: var ByteIterator, size: int): int =
  var buffer = it.nextChunk(size)
  result = 0
  for bt in buffer:
    result = result * 256 + int(bt)

proc remainingBytes(bit: BytesIterator): seq[byte] = 
  var bytes: seq[byte] = bit.bytes[bit.index..bit.length]
  return bytes

proc bytesToString(bytes: seq[byte]): string =
  result = newString(bytes.len)
  for i, byte in pairs(bytes):
    result[i] = char(byte)

proc nextString(it: var ByteIterator, size: int): string = 
  var byteSequence = it.nextChunk(size)
  result = newString(size)
  for i, bt in pairs(byteSequence):
    result[i] = char(bt)

proc getBytes(filePath: string): seq[byte] = 
  var file = open(filePath, fmRead)
  var bytes: seq[byte]
  discard readBytes(file, bytes, 0, os.getFileSize(filePath))
  return bytes

proc readHeaderChunk(bytes: seq[byte]): Table = 
  var headerProps: Table[string, string] = initTable[string, string]()
  var tags: seq[tuple[int, string]] = [
    (4, "width"), (4, "height"), (1, "bit depth"), 
    (1, "color type"), (1, "compression method"), 
    (1, "filter method"), (1, "interlace method") ]
  var tagLen = len(tags)
  var citer = BytesIterator(bytes)
  for i in 0..tagLen:
    if tags[0] == 4:
      headerProps[tags[i][1]] = citer.nextString(tags[i][0])
    else:
      headerProps[tags[i][1]] = citer.nextDecimal(tags[i][0])
  return headerProps

proc readDataChunk(bytes: seq[byte]): Table = 
  var dataHeader: Table[string, string] = initTable[string, string]()
  var tags: seq[tuple[int, string]] = [
    (4, "deflate compression"), (1, "fcheck value"), 
    (1, "compressed DEFLATE block"), (4, "zlib check value"), (4, "crc")]
  var tagLen = len(tags)
  var citer = BytesIterator(bytes)
  for i in 0..tagLen:
    if tags[0] == 4:
      dataProps[tags[i][1]] = citer.nextString(tags[i][0])
    else:
      dataProps[tags[i][1]] = citer.nextDecimal(tags[i][0])
  return dataProps

proc readPaletteChunk(bytes: seq[byte]): seq[tuple[int, int, int]] = 
  var palette: seq[tuple[int, int, int]]
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
  
proc readPNG(filePath: string) =
  var bytes = getBytes(filePath) 
  var biter = ByteIterator(bytes)
  var byteLength = len(bytes)
  var signature: string = biter.nextString(8)
  var nextSize: int
  var nextChunk: seq[byte]
  var chunks: seq[seq[byte]]
  var nextAmount: int
  var chunkTag: string
  var chunkTags: seq[string] = []
  var props: seq[string, ]
  var pngHeaderData: Table[string, string]

  while true:
    remaining = @[]
    nextSize = biter.nextDecimal(4)
    nextChunk = biter.nextChunk(nextSize)
    ccIter = BytesIterator(nextChunk)
    chunkTag = ccIter.nextString(8)
    chunkTags.add(chunkTag)
    if chunkTag == "IDHR":
      pngHeaderData = readHeaderChunk(ccIter.remainingBytes())
    elif chunkTag == "PLTE":
      pngPaletteData = readPaletteChunk(ccIter.remainingBytes())
    elif chunkTag == "IDAT":

    elif chunkTag == "IEND":
      break

    case chunkTag:
      of "IDHR":
        propDict["header"] = readHeaderChunk(cciter.bytes[4:])
    
    nextAmount = biter.index + 4 
    if nextAmount > byteLength:
      break
  
