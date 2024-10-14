import ../util/[stackstring, sparsemap], initreqs

when defined(device):
    proc mprotect(a1: pointer, a2: int, a3: cint): cint {.inline.} = discard
else:
    proc mprotect(a1: pointer, a2: int, a3: cint): cint {.importc, header: "<sys/mman.h>".}

const SLOTS = 20_000

const BUFFER = sizeof(byte) * 8

type
    Allocator* = proc (p: pointer; size: csize_t): pointer {.tags: [], raises: [], cdecl, gcsafe.}

    Allocation = object
        realPointer: pointer
        realSize: int32
        reported: bool
        resized: bool
        originalSize: int32
        protected: bool
        stack: StackString[500]

    MemTrace* = object
        allocs: StaticSparseMap[SLOTS, uint64, Allocation]
        deleted: StaticSparseMap[SLOTS, uint64, Allocation]
        totalAllocs: int

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

proc stringify(frame: PFrame, size: static int): StackString[size] =
    ## Convert a single PFrame to a string
    result &= frame.filename
    result &= ':'
    result &= frame.line.int32
    result &= ':'
    result &= frame.procname

iterator stackframes(frame: PFrame): PFrame =
    ## Walk a series of frames back to the beginning
    var current = frame
    while current != nil:
        if not current.filename.endsWith("/arc.nim"):
            yield current
        current = current.prev

proc printStack(pframe: PFrame) =
    for stack in stackframes(pframe):
        var str = stack.stringify(250)
        pdLog(str.cstr)

proc yesNo(flag: bool): char =
    return if flag: 'y' else: 'n'

proc print(alloc: Allocation, title: cstring, printMem: bool) =
    pdLog(
        "%s (resized: %c, original size: %i, fenced: %c)",
        title,
        alloc.resized.yesNo,
        alloc.originalSize,
        alloc.protected.yesNo,
    )
    pdLog(
        "  %p (Overall size: %i, internal size: %i)",
        alloc.realPointer,
        alloc.realSize,
        alloc.realSize - 2 * BUFFER
    )
    pdLog("  %s", alloc.stack.cstr)

    if printMem:
        dumpMemory(alloc.realPointer, alloc.realSize, pdLog)

proc ord(p: pointer): auto = cast[uint64](p)

proc `+`(a: pointer, b: Natural): pointer = cast[pointer](cast[uint64](a) + b.uint64)

proc `-`(a: pointer, b: Natural): pointer = cast[pointer](cast[uint64](a) - b.uint64)

proc input(p: pointer): pointer = p - BUFFER

proc output(p: pointer): pointer = p + BUFFER

proc realSize(size: Natural): auto = size + BUFFER * 2

proc isInvalid(p: pointer, realSize: Natural): bool =
    # Disable on device because of how slow it winds up being
    when not defined(device):
        let data = cast[ptr UncheckedArray[byte]](p)
        for i in 0..<BUFFER:
            if data[i] != 0:
                return true
        for i in (realSize - BUFFER)..<realSize:
            if data[i] != 0:
                return true
    return false

proc printPrior(trace: var MemTrace, p: pointer) =
    ## Returns the allocation just before the given allocation
    var distance = high(uint64)
    var found: Allocation
    let pInt = cast[uint64](p)
    for (_, alloc) in trace.allocs:
        let thisP = cast[uint64](alloc.realPointer)
        if pInt > thisP and pInt - thisP < distance:
            found = alloc
            distance = pInt - thisP

    if distance != high(uint64):
        found.print("Preceding allocation", printMem = false)
        pdLog("  Distance: %i", distance)

proc check(trace: var MemTrace) =
    if trace.totalAllocs mod 100 == 0:
        pdLog("Allocations count: %i (active: %i)", trace.totalAllocs, trace.allocs.size)

    for (_, alloc) in trace.allocs:
        if not alloc.protected and not alloc.reported and isInvalid(alloc.realPointer, alloc.realSize):
            alloc.reported = true
            alloc.print("CORRUPT! ", printMem = true)
            trace.printPrior(alloc.realPointer)

proc memRange(alloc: Allocation): Slice[uint64] =
    return cast[uint64](alloc.realPointer)..(cast[uint64](alloc.realPointer) + alloc.realSize.uint64)

proc checkOverlaps(trace: var MemTrace, title: cstring, newAlloc: Allocation) =
    let newRange = newAlloc.memRange
    for (_, alloc) in trace.allocs:
        let existingRange = alloc.memRange
        if existingRange.a in newRange or existingRange.b in newRange:
            pdLog("%s overlaps with existing allocation!", title)
            newAlloc.print(title, printMem = false)
            alloc.print("Overlaps with:", printMem = true)

proc unprotect(p: pointer, size: Natural) =
    discard mprotect(p, BUFFER, 7)
    discard mprotect(p + size + BUFFER, BUFFER, 7)

proc protect(p: pointer, size: Natural): bool =
    if mprotect(p, BUFFER, 1) != 0:
        return false

    if mprotect(p + size + BUFFER, BUFFER, 1) != 0:
        discard mprotect(p, BUFFER, 7)
        return false

    return true

proc zeroBuffers(p: pointer, size: Natural) =
    zeroMem(p, BUFFER)
    zeroMem(p + size + BUFFER, BUFFER)
    if p.isInvalid(size.realSize):
        pdLog("Zeroing failed! ")
        dumpMemory(p, size.realSize, pdLog)

let allocStr = "alloc".stackstring(10)
let deallocStr = "dealloc".stackstring(10)
let reallocStr = "realloc".stackstring(10)

var recordFile: pointer

proc stacktrace(frames: PFrame, size: static int): StackString[size] =
    var isFirst = true
    for frame in stackframes(frames):
        if isFirst:
            isFirst = false
        elif result.isFull:
            break
        else:
            result &= '|'
        var str = stringify(frame, 200)
        result &= str

proc record[N: static int](
    action: StackString[10],
    input: pointer,
    output: pointer,
    size: Natural,
    frame: PFrame = getFrame()
) {.inline.} =
    when defined(memrecord):
        if recordFile == nil:
            recordFile = pdOpen("memrecord.txt", 2 shl 2)

        var buffer: StackString[1000]
        buffer &= action
        buffer &= ','
        buffer &= input
        buffer &= ','
        buffer &= output
        buffer &= ','
        buffer &= size.int32
        buffer &= ','
        buffer &= frame.stacktrace(500)

        buffer.suffix('\n')

        discard pdWrite(recordFile, buffer.cstr, buffer.len.cuint)

proc traceAlloc(trace: var MemTrace, alloc: Allocator, size: Natural): pointer {.inline.} =
    trace.totalAllocs += 1
    trace.check

    let realPointer = alloc(nil, size.realSize.csize_t)
    result = realPointer.output

    zeroBuffers(realPointer, size)
    let protected = protect(realPointer, size)

    let entry = Allocation(
        realSize: size.realSize.int32,
        realPointer: realPointer,
        protected: protected,
        stack: getFrame().stacktrace(500),
    )

    trace.allocs[realPointer.ord] = entry

proc alloc*(trace: var MemTrace, alloc: Allocator, size: Natural): pointer {.inline.} =
    when defined(memtrace):
        result = traceAlloc(trace, alloc, size)
    else:
        result = alloc(nil, size.csize_t)
    record[5](allocStr, result, result, size)

proc traceRealloc(trace: var MemTrace, alloc: Allocator, p: pointer, newSize: Natural): pointer {.inline.} =
    trace.check

    let realInPointer = p.input
    let origSize = trace.allocs[realInPointer.ord].realSize
    unprotect(realInPointer, origSize)

    let realOutPointer = alloc(realInPointer, newSize.realSize.csize_t)
    result = realOutPointer.output

    zeroBuffers(realOutPointer, newSize)
    let protected = protect(realOutPointer, newSize)

    trace.allocs.delete(realInPointer.ord)

    let entry = Allocation(
        realSize: newSize.realSize.int32,
        realPointer: realOutPointer,
        stack: getFrame().stacktrace(500),
        resized: true,
        protected: protected,
        originalSize: origSize,
    )

    trace.checkOverlaps("Resized allocation", entry)

    trace.allocs[realOutPointer.ord] = entry

proc realloc*(trace: var MemTrace, alloc: Allocator, p: pointer, newSize: Natural): pointer {.inline.} =
    when defined(memtrace):
        result = traceRealloc(trace, alloc, p, newSize)
    else:
        result = alloc(p, newSize.csize_t)
    record[5](reallocStr, p, result, newSize)

proc traceDealloc(trace: var MemTrace, alloc: Allocator, p: pointer) {.inline.} =
    trace.check
    let realPointer = p.input
    if realPointer.ord notin trace.allocs:
        pdLog("Attempting to dealloc unmanaged memory! %p", p)
        getFrame().printStack()
        if realPointer.ord notin trace.deleted:
            trace.printPrior(p)
        else:
            trace.deleted[realPointer.ord].print("Previously deallocated", printMem = false)
        return
    else:
        var local = trace.allocs[realPointer.ord]
        local.stack = getFrame().stacktrace(500)

        unprotect(realPointer, local.realSize)
        discard alloc(realPointer, 0)
        trace.deleted[realPointer.ord] = local
        trace.allocs.delete(realPointer.ord)

proc dealloc*(trace: var MemTrace, alloc: Allocator, p: pointer) {.inline.} =
    record[5](deallocStr, p, p, 0)
    when defined(memtrace): traceDealloc(trace, alloc, p) else: discard alloc(p, 0)