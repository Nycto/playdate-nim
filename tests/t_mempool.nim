import unittest, playdate/util/mempool

proc pdrealloc(p: pointer; size: csize_t): pointer =
    if p == nil:
        return allocShared(size)
    elif size == 0:
        deallocShared(p)
        return nil
    else:
        return reallocShared(p, size)

template checkPointer(mem: pointer, size: Natural) =
    let ary = cast[ptr UncheckedArray[uint8]](mem)
    for i in 0..<size:
        ary[i] = uint8(i mod high(uint8).int)

    for i in 0..<size:
        check(ary[i] == uint8(i mod high(uint8).int))

template bulkAlloc(size) =
    var pointers: array[500, pointer]
    for i in 0..<pointers.len:
        pointers[i] = poolAlloc(pdrealloc, size)

    for p in pointers:
        checkPointer(p, size)

    for p in pointers:
        poolDealloc(pdrealloc, p)

suite "Mem pool":

    test "Acquiring values of various sizes":
        bulkAlloc(32)
        bulkAlloc(64)
        bulkAlloc(96)
        bulkAlloc(128)
        bulkAlloc(256)

    test "Reallocing":
        var mem = poolAlloc(pdrealloc, 32)
        checkPointer(mem, 32)
        mem = poolRealloc(pdrealloc, mem, 96)
        checkPointer(mem, 96)
        poolDealloc(pdrealloc, mem)
