import ../util/[stackstring, sparsemap, stackframe], initreqs

let allocStr = "alloc".stackstring(10)
let deallocStr = "dealloc".stackstring(10)
let reallocStr = "realloc".stackstring(10)

var recordFile: pointer = nil
var recordBytesWritten = 0

proc record[N: static int](
    action: StackString[10],
    input: pointer,
    output: pointer,
    size: Natural,
    frame: PFrame = getFrame()
) {.inline.} =

    var buffer: StackString[500]
    buffer &= action
    buffer &= ','
    buffer &= input
    buffer &= ','
    buffer &= output
    buffer &= ','
    buffer &= size.int32
    buffer &= ','
    buffer.appendStacktrace(frame)

    buffer.suffix('\n')

    if recordFile == nil:
        recordFile = pdOpen("memrecord.txt", pdFileModeAppend)

    recordBytesWritten += buffer.len
    discard pdWrite(recordFile, buffer.cstr, buffer.len.cuint)

    if recordBytesWritten > 2000:
        assert(pdClose(recordFile) == 0)

proc recordAlloc*(size: Natural): pointer {.inline.} =
    result = pdrealloc(nil, size.csize_t)
    record[5](allocStr, result, result, size)

proc recordRealloc*(p: pointer, newSize: Natural): pointer {.inline.} =
    result = pdrealloc(p, newSize.csize_t)
    record[5](reallocStr, p, result, newSize)

proc recordDealloc*(p: pointer) {.inline.} =
    record[5](deallocStr, p, p, 0)
    discard pdrealloc(p, 0)