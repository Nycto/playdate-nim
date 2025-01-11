##
## This file is a re-implementation of malloc.nim in the Nim standard library.It allows Nim itself to use the
## memory allocators provided by the playdate SDK.
##
## It works by by patching it in as a replacement in your configs.nim file, like this:
##
## ```nim
## patchFile("stdlib", "malloc", nimblePlaydatePath / "src/playdate/bindings/malloc")
## ```
##
## This patching is automatically configured when using `playdate/build/config`, as recommended by the setup
## documentation.
##

{.push stackTrace: off.}

import ../util/initreqs

when defined(mempool):
    import ../util/mempool
    proc rawAlloc(size: Natural): pointer {.inline.} = poolAlloc(pdrealloc, size)
    proc rawDealloc(p: pointer) {.inline.} = poolDealloc(pdrealloc, p)
    proc rawRealloc(p: pointer, size: Natural): pointer {.inline.} = poolRealloc(pdrealloc, p, size)

else:
    proc rawAlloc(size: Natural): pointer {.inline.} = pdrealloc(nil, size.csize_t)
    proc rawRealloc(p: pointer, size: Natural): pointer {.inline.} = pdrealloc(p, size.csize_t)
    proc rawDealloc(p: pointer) {.inline.} = discard pdrealloc(p, 0)

when defined(memProfiler):

    # Forward declaration for memory profiling support
    proc nimProfile(requestedSize: int)

    proc doAlloc(size: Natural): pointer =
        # Integrage with: https://nim-lang.org/docs/estp.html
        try:
            nimProfile(size.int)
        except:
            discard
        return rawAlloc(size)

    proc doRealloc(p: pointer, size: Natural): pointer = rawRealloc(p, size)
    proc doDealloc(p: pointer) = rawDealloc(p)

elif defined(memtrace):
    import ../util/memtrace
    var trace: MemTrace
    proc doAlloc(size: Natural): pointer = allocTrace(trace, size, rawAlloc)
    proc doRealloc(p: pointer, size: Natural): pointer = reallocTrace(trace, p, size, rawRealloc)
    proc doDealloc(p: pointer) = deallocTrace(trace, p, rawDealloc)

elif defined(memrecord):
    import ../util/memrecord
    proc doAlloc(size: Natural): pointer = recordAlloc(size, rawAlloc)
    proc doRealloc(p: pointer, size: Natural): pointer = recordRealloc(p, size, rawRealloc)
    proc doDealloc(p: pointer) = recordDealloc(p, rawDealloc)

else:
    proc doAlloc(size: Natural): pointer = rawAlloc(size)
    proc doRealloc(p: pointer, size: Natural): pointer = rawRealloc(p, size)
    proc doDealloc(p: pointer) = rawDealloc(p)

proc allocImpl(size: Natural): pointer =
    {.cast(tags: []).}:
        return doAlloc(size.csize_t)

proc alloc0Impl(size: Natural): pointer =
    result = allocImpl(size)
    zeroMem(result, size)

proc reallocImpl(p: pointer, newSize: Natural): pointer =
    {.cast(tags: []).}:
        return doRealloc(p, newSize.csize_t)

proc realloc0Impl(p: pointer, oldsize, newSize: Natural): pointer =
    result = reallocImpl(p, newSize.csize_t)
    if newSize > oldSize:
        zeroMem(cast[pointer](cast[uint](result) + uint(oldSize)), newSize - oldSize)

proc deallocImpl(p: pointer) =
    {.cast(tags: []).}:
        doDealloc(p)

# The shared allocators map on the regular ones

proc allocSharedImpl(size: Natural): pointer {.used.} = allocImpl(size)

proc allocShared0Impl(size: Natural): pointer {.used.} = alloc0Impl(size)

proc reallocSharedImpl(p: pointer, newSize: Natural): pointer {.used.} = reallocImpl(p, newSize)

proc reallocShared0Impl(p: pointer, oldsize, newSize: Natural): pointer {.used.} = realloc0Impl(p, oldSize, newSize)

proc deallocSharedImpl(p: pointer) {.used.} = deallocImpl(p)

proc getOccupiedMem(): int {.used.} = discard
proc getFreeMem(): int {.used.} = discard
proc getTotalMem(): int {.used.} = discard
proc deallocOsPages() {.used.} = discard

{.pop.}
