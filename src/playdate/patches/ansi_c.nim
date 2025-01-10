##
## Patch file overrides for:
## https://github.com/nim-lang/Nim/blob/0a058a6b8f32749ebb19bfcd824b9f219d317f68/lib/system/ansi_c.nim
##

import ../util/initreqs, system/memory

{.push hints:off, stack_trace: off, profiler: off.}

proc c_memchr*(s: pointer, c: cint, n: csize_t): pointer {.error.}

proc c_memcmp*(a, b: pointer, size: csize_t): cint {.noSideEffect, inline.} =
  nimCmpMem(a, b, size)

proc c_memcpy*(a, b: pointer, size: csize_t): pointer {.discardable.} =
  nimCopyMem(a, b, size)

proc c_memmove*(a, b: pointer, size: csize_t): pointer {.discardable.} =
  c_memcpy(a, b, size) # Yes, copymem and memmove technically have different implementations. Forgive me.

proc c_memset*(p: pointer, value: cint, size: csize_t): pointer {.discardable, error.}

proc c_strcmp*(a, b: cstring): cint {.noSideEffect.} =
  var s1 = cast[uint64](a)
  var s2 = cast[uint64](b)
  while (cast[ptr char](s1)[] != '\0') and (cast[ptr char](s1)[] == cast[ptr char](s2)[]):
    inc(s1)
    inc(s2)
  return cint(cast[ptr uint8](s1)[] - cast[ptr uint8](s2)[])

proc c_strlen*(a: cstring): csize_t {.noSideEffect.} = nimCStrLen(a).csize_t

proc c_abort*() {.error, noSideEffect, noreturn.}


when defined(nimBuiltinSetjmp):
  type
    C_JmpBuf* = array[5, pointer]
elif defined(linux) and defined(amd64):
  type
    C_JmpBuf* {.importc: "jmp_buf", header: "<setjmp.h>", bycopy.} = object
        abi: array[200 div sizeof(clong), clong]
else:
  type
    C_JmpBuf* {.importc: "jmp_buf", header: "<setjmp.h>".} = object


type CSighandlerT = proc (a: cint) {.noconv.}
when defined(windows):
  const
    SIGABRT* = cint(22)
    SIGFPE* = cint(8)
    SIGILL* = cint(4)
    SIGINT* = cint(2)
    SIGSEGV* = cint(11)
    SIGTERM = cint(15)
    SIG_DFL* = cast[CSighandlerT](0)
elif defined(macosx) or defined(linux) or defined(freebsd) or
     defined(openbsd) or defined(netbsd) or defined(solaris) or
     defined(dragonfly) or defined(nintendoswitch) or defined(genode) or
     defined(aix) or hostOS == "standalone":
  const
    SIGABRT* = cint(6)
    SIGFPE* = cint(8)
    SIGILL* = cint(4)
    SIGINT* = cint(2)
    SIGSEGV* = cint(11)
    SIGTERM* = cint(15)
    SIGPIPE* = cint(13)
    SIG_DFL* = CSighandlerT(nil)
elif defined(haiku):
  const
    SIGABRT* = cint(6)
    SIGFPE* = cint(8)
    SIGILL* = cint(4)
    SIGINT* = cint(2)
    SIGSEGV* = cint(11)
    SIGTERM* = cint(15)
    SIGPIPE* = cint(7)
    SIG_DFL* = CSighandlerT(nil)
else:
  when defined(nimscript):
    {.error: "SIGABRT not ported to your platform".}
  else:
    var
      SIGINT* {.importc: "SIGINT", nodecl.}: cint
      SIGSEGV* {.importc: "SIGSEGV", nodecl.}: cint
      SIGABRT* {.importc: "SIGABRT", nodecl.}: cint
      SIGFPE* {.importc: "SIGFPE", nodecl.}: cint
      SIGILL* {.importc: "SIGILL", nodecl.}: cint
      SIG_DFL* {.importc: "SIG_DFL", nodecl.}: CSighandlerT
    when defined(macosx) or defined(linux):
      var SIGPIPE* {.importc: "SIGPIPE", nodecl.}: cint

when defined(macosx):
  const SIGBUS* = cint(10)
elif defined(haiku):
  const SIGBUS* = cint(30)

# "nimRawSetjmp" is defined by default for certain platforms, so we need the
# "nimStdSetjmp" escape hatch with it.
when defined(nimSigSetjmp):
  proc c_longjmp*(jmpb: C_JmpBuf, retval: cint) {.
    header: "<setjmp.h>", importc: "siglongjmp".}
  proc c_setjmp*(jmpb: C_JmpBuf): cint =
    proc c_sigsetjmp(jmpb: C_JmpBuf, savemask: cint): cint {.
      header: "<setjmp.h>", importc: "sigsetjmp".}
    c_sigsetjmp(jmpb, 0)
elif defined(nimBuiltinSetjmp):
  proc c_longjmp*(jmpb: C_JmpBuf, retval: cint) =
    # Apple's Clang++ has trouble converting array names to pointers, so we need
    # to be very explicit here.
    proc c_builtin_longjmp(jmpb: ptr pointer, retval: cint) {.
      importc: "__builtin_longjmp", nodecl.}
    # The second parameter needs to be 1 and sometimes the C/C++ compiler checks it.
    c_builtin_longjmp(unsafeAddr jmpb[0], 1)
  proc c_setjmp*(jmpb: C_JmpBuf): cint =
    proc c_builtin_setjmp(jmpb: ptr pointer): cint {.
      importc: "__builtin_setjmp", nodecl.}
    c_builtin_setjmp(unsafeAddr jmpb[0])

elif defined(nimRawSetjmp) and not defined(nimStdSetjmp):
  when defined(windows):
    # No `_longjmp()` on Windows.
    proc c_longjmp*(jmpb: C_JmpBuf, retval: cint) {.
      header: "<setjmp.h>", importc: "longjmp".}
    when defined(vcc) or defined(clangcl):
      proc c_setjmp*(jmpb: C_JmpBuf): cint {.
        header: "<setjmp.h>", importc: "setjmp".}
    else:
      # The Windows `_setjmp()` takes two arguments, with the second being an
      # undocumented buffer used by the SEH mechanism for stack unwinding.
      # Mingw-w64 has been trying to get it right for years, but it's still
      # prone to stack corruption during unwinding, so we disable that by setting
      # it to NULL.
      # More details: https://github.com/status-im/nimbus-eth2/issues/3121
      when defined(nimHasStyleChecks):
        {.push styleChecks: off.}

      proc c_setjmp*(jmpb: C_JmpBuf): cint =
        proc c_setjmp_win(jmpb: C_JmpBuf, ctx: pointer): cint {.
          header: "<setjmp.h>", importc: "_setjmp".}
        c_setjmp_win(jmpb, nil)

      when defined(nimHasStyleChecks):
        {.pop.}
  else:
    proc c_longjmp*(jmpb: C_JmpBuf, retval: cint) {.
      header: "<setjmp.h>", importc: "_longjmp".}
    proc c_setjmp*(jmpb: C_JmpBuf): cint {.
      header: "<setjmp.h>", importc: "_setjmp".}
else:
  proc c_longjmp*(jmpb: C_JmpBuf, retval: cint) {.
    header: "<setjmp.h>", importc: "longjmp".}
  proc c_setjmp*(jmpb: C_JmpBuf): cint {.
    header: "<setjmp.h>", importc: "setjmp".}

proc c_signal*(sign: cint, handler: CSighandlerT): CSighandlerT {.
  importc: "signal", header: "<signal.h>", discardable.}
proc c_raise*(sign: cint): cint {.importc: "raise", header: "<signal.h>".}

type
  CFile {.incompleteStruct.} = object
  CFilePtr* = ptr CFile ## The type representing a file handle.

var
  cstderr*: CFilePtr
  cstdout*: CFilePtr
  cstdin*: CFilePtr

proc c_fprintf*(f: CFilePtr, frmt: cstring): cint {.varargs, discardable.} =
  pdError("c_fprintf should not be called")

proc c_printf*(frmt: cstring): cint {.error, varargs, discardable.}

proc c_fputs*(c: cstring, f: CFilePtr): cint =
  pdError("c_fputs should not be called")

proc c_fputc*(c: char, f: CFilePtr): cint =
  pdError("c_fputc should not be called")

proc c_sprintf*(buf, frmt: cstring): cint {.
  importc: "sprintf", header: "<stdio.h>", varargs, noSideEffect.}
  # we use it only in a way that cannot lead to security issues

proc c_snprintf*(buf: cstring, n: csize_t, frmt: cstring): cint {.error, varargs, noSideEffect.}

proc c_malloc*(size: csize_t): pointer {.error.}

proc c_calloc*(nmemb, size: csize_t): pointer {.error.}

proc c_free*(p: pointer) {.error.}

proc c_realloc*(p: pointer, newsize: csize_t): pointer {.error.}

proc c_fwrite*(buf: pointer, size, n: csize_t, f: CFilePtr): csize_t =
  pdError("c_fwrite should not be called")

proc c_fflush*(f: CFilePtr): cint =
  pdError("c_fflush should not be called")

proc rawWriteString*(f: CFilePtr, s: cstring, length: int) {.nonReloadable, inline.} =
  pdError("rawWriteString should not be called")

proc rawWrite*(f: CFilePtr, s: cstring) {.nonReloadable, inline.} =
  pdError("rawWrite should not be called")

{.pop.}
