import stackstring, ../bindings/initreqs

proc endsWith(a, b: cstring): bool =
    let aLen = a.len
    let bLen = b.len
    if aLen < bLen:
        return false

    let delta = aLen - bLen
    for i in 0..<bLen:
        if a[i + delta] != b[i]:
            return false

    return true

proc appendFrame[N: static int](output: var StackString[N], frame: PFrame, compact: static bool = false) =
    ## Convert a single PFrame to a string
    if compact:
        output.appendBasename(frame.filename)
    else:
        output &= frame.filename
    output &= ':'
    output &= frame.line.int32
    output &= ':'
    output &= frame.procname

iterator stackframes*(frame: PFrame = getFrame()): PFrame =
    ## Walk a series of frames back to the beginning
    var current = frame
    while current != nil:
        if not current.filename.endsWith("/arc.nim"):
            yield current
        current = current.prev

proc printStack*(frames: PFrame = getFrame()) =
    var buffer: StackString[500]
    for frame in stackframes(frames):
        buffer.clear
        buffer.appendFrame(frame)
        pdLog(buffer.cstr)

proc appendStacktrace*[N: static int](data: var StackString[N], frames: PFrame = getFrame()) =
    var isFirst = true
    for frame in stackframes(frames):
        if data.isFull:
            break
        elif isFirst:
            isFirst = false
        else:
            data &= ';'
        data.appendFrame(frame, compact = true)