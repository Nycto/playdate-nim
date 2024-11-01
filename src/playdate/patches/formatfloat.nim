## This module implements formatting floats as strings.
## Originally pulled from: https://raw.githubusercontent.com/nim-lang/Nim/refs/heads/devel/lib/std/formatfloat.nim

import system/ansi_c

proc addCstringN(result: var string, buf: cstring; buflen: int) =
  # no nimvm support needed, so it doesn't need to be fast here either
  let oldLen = result.len
  let newLen = oldLen + buflen
  result.setLen newLen
  c_memcpy(result[oldLen].addr, buf, buflen.csize_t)

import std/private/[dragonbox, schubfach]

proc writeFloatToBufferRoundtrip*(buf: var array[65, char]; value: BiggestFloat): int =
  ## This is the implementation to format floats.
  ##
  ## returns the amount of bytes written to `buf` not counting the
  ## terminating '\0' character.
  result = toChars(buf, value, forceTrailingDotZero=true).int
  buf[result] = '\0'

proc writeFloatToBufferRoundtrip*(buf: var array[65, char]; value: float32): int =
  result = float32ToChars(buf, value, forceTrailingDotZero=true).int
  buf[result] = '\0'

proc writeFloatToBuffer*(buf: var array[65, char]; value: BiggestFloat | float32): int {.inline.} =
    writeFloatToBufferRoundtrip(buf, value)

proc addFloatRoundtrip*(result: var string; x: float | float32) =
  var buffer {.noinit.}: array[65, char]
  let n = writeFloatToBufferRoundtrip(buffer, x)
  result.addCstringN(cast[cstring](buffer[0].addr), n)

proc addFloat*(result: var string; x: float | float32) {.inline.} =
  ## Converts float to its string representation and appends it to `result`.
  addFloatRoundtrip(result, x)
