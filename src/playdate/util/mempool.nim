##
## Set of memory allocation methods that pools pointers to small bits of memory
##
## On allocation, normalizes memory allocation sizes to fit into one of three buckets:
##
## 1. <= 64B
## 2. <= 128B
## 3. > 128B
##
## If memory is available from a pool for buckets 1 and 2, it will be reused. For bucket 3, the underlying
## allocator will always be called.
##
## If there aren't any pointers available in the pool, then new memory will be allocated. An extra byte will be
## prepended to the memory, which is used to store the bucket it fits in.
##
## On deallocation, memory from buckets 1 and 2 are added back to the pool, if there is room in the pool. If there
## is no room, it's just deallocated.
##
## For the sake of simplicity, this allocator doesn't touch reallocations. During reallocation, everything is dumped
## into bucket 3, regardless of the size.
##

import stackring, pointermath

const memPoolSmallCount {.intdefine.} = 256
const memPoolSmallSize = 64
const memPoolSmallTag = 1'u8
var small: StackRing[memPoolSmallCount, pointer]

const memPoolMediumCount {.intdefine.} = 128
const memPoolMediumSize = 128
const memPoolMediumTag = 2'u8
var medium: StackRing[memPoolMediumCount, pointer]

const memPoolLargeTag = 3'u8

proc poolAlloc*(alloc: auto, size: Natural): pointer =
    ## Allocates memory from a pool, when possible

    var rawPointer: pointer = nil
    var tag: uint8

    template fromPool(sizeTag, memPool, memSize) =
        tag = sizeTag
        rawPointer = memPool.popFirst(nil)
        if rawPointer == nil:
            rawPointer = alloc(nil, memSize + 1)

    if size <= memPoolSmallSize:
        fromPool(memPoolSmallTag, small, memPoolSmallSize)
    elif size <= memPoolMediumSize:
        fromPool(memPoolMediumTag, medium, memPoolMediumSize)
    else:
        tag = memPoolLargeTag
        rawPointer = alloc(nil, csize_t(size + 1))

    rawPointer[0] = tag
    return rawPointer + 1

proc poolRealloc*(alloc: auto, p: pointer, newSize: Natural): pointer =
    let p = p - 1
    var rawPointer = alloc(p, (newSize + 1).csize_t)

    # If we resize a pointer, just treat it as a mempool large
    rawPointer[0] = memPoolLargeTag

    return rawPointer + 1

proc poolDealloc*(alloc: auto, p: pointer) =
    let p = p - 1

    template poolReturn(pool) =
        if not pool.addLast(p):
            discard alloc(p, 0)

    case p[0]
    of memPoolSmallTag: poolReturn(small)
    of memPoolMediumTag: poolReturn(medium)
    of memPoolLargeTag: discard alloc(p, 0)
    else: assert(false, "Attempting to release untagged memory")
