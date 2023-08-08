# nim-png [Compiles 8/8/2023]
Reading, writing PNG format files with all chunk types. Allowing you to programmatically read and edit  png data  and files. [Currently Incomplete]

# PNG INFORMATION
https://www.w3.org/TR/png-3/

# PNG Chunk Names

"IHDR", "IDAT", "IEND", "PLTE", 
"bKGD", "cHRM", "dSIG", "eXIF", 
"gAMA", "hIST", "iCCP", "iTXt", 
"pHYs", "sBIT", "sPLT", "sRGB", 
"sTER", "tEXT", "tIME", "tRNS", 
"zTXt"


# Types

## BytesIterator
Iterator object for keeping track of the byte count and what not. 

### methods

#### hasNext()
```nim
iter.hasNext()
```
ask the iter if there are any byes left

#### nextByte()
reads the next byte out of the iter and move the index along
```nim
iter.NextByte()
```

#### nextChunk(size: int)
reads a large amount of bytes given by the chunk size byte sequence
```nim
iter.nextChunk(chunkSize)
```

#### bytesToDecimal(bytes: seq[byte])
converts the bytes into its decimal amount
```nim
iter.bytesToDecimal(bytes)
```
#### nextDecimal(size: int)
read size amount of bytes to a decimal integer
```nim
iter.nextDecimal(4)
```

#### remainingBytes()
returns the remaining bytes of the iter
```nim
iter.remainingBytes()
```

#### nextString(size: int)
reads the next <size> bytes to a string and progresses the iter
```nim
iter.nextString(4)
```
