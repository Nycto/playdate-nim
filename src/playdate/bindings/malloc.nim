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

# Forward declaration for memory profiling support
when defined(memProfiler):
    proc nimProfile(requestedSize: int)

import ../util/[memtrace, initreqs]

var trace: MemTrace

proc allocImpl(size: Natural): pointer =
    # Integrage with: https://nim-lang.org/docs/estp.html
    {.cast(tags: []).}:
        when defined(memProfiler):
            try:
                nimProfile(size.int)
            except:
                discard

        return trace.alloc(pdrealloc, size.csize_t)

proc alloc0Impl(size: Natural): pointer =
    result = allocImpl(size)
    zeroMem(result, size)

proc reallocImpl(p: pointer, newSize: Natural): pointer =
    {.cast(tags: []).}:
        return trace.realloc(pdrealloc, p, newSize)

proc realloc0Impl(p: pointer, oldsize, newSize: Natural): pointer =
    result = reallocImpl(p, newSize.csize_t)
    if newSize > oldSize:
        zeroMem(cast[pointer](cast[uint](result) + uint(oldSize)), newSize - oldSize)

proc deallocImpl(p: pointer) =
    {.cast(tags: []).}:
        trace.dealloc(pdrealloc, p)

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
