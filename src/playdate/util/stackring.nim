type
    StackRing*[N: static int; T] = object
        ## A ring buffer initialized onthe stack
        data: array[N, T]
        head, tail, count: int32

proc checkDefinition[N, T](ring: var StackRing[N, T]) {.inline.} =
    # static:
    #     assert(N.isPowerOfTwo, "StackRing sizes must be a power of two")
    discard

proc len*(ring: var StackRing): auto =
    ring.checkDefinition
    return ring.count

proc addLast*[N, T](ring: var StackRing[N, T], item: T): bool =
    ring.checkDefinition
    if ring.count < N:
        inc ring.count
        ring.data[ring.tail] = item
        ring.tail = (ring.tail + 1) and (N - 1)
        return true

proc popFirst*[N, T](ring: var StackRing[N, T], otherwise: T = default(T)): T =
    ring.checkDefinition
    if ring.count > 0:
        dec ring.count
        result = ring.data[ring.head]
        reset(ring.data[ring.head])
        ring.head = (ring.head + 1) and (N - 1)
    else:
        return otherwise