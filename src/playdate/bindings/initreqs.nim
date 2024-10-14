##
## Contains direct references to playdate apis that are required to be usable before the
## full API is itself available.
##

# This file is used by the memory tracer, which is swapped in to the nim standard library. That
# means it gets imported and used before the 'macros' lib is available. And because the playdate
# SDK import makes heavy use of macros, we can't use the standard file open proc here. So we define
# our own version of it.
type FileOpenProc = proc (name: cstring; mode: int): pointer {.cdecl, raises: [].}

var pdrealloc*: proc (p: pointer; size: csize_t): pointer {.tags: [], raises: [], cdecl, gcsafe.}
var pdLog*: proc (fmt: cstring) {.cdecl, varargs, raises: [].}
var pdOpen*: FileOpenProc
var pdWrite*: proc (file: pointer; buf: pointer; len: cuint): cint {.cdecl, raises: [].}

proc initPrereqs*(realloc, log, open, write: auto) =
    ## Sets pointers to functions that are needed early in the initialization process
    pdrealloc = realloc
    pdLog = log
    pdOpen = cast[FileOpenProc](open)
    pdWrite = write