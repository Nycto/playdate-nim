
proc ord*(p: pointer): auto = cast[uint64](p)

proc `+`*(a: pointer, b: Natural): pointer = cast[pointer](cast[uint64](a) + b.uint64)

proc `-`*(a: pointer, b: Natural): pointer = cast[pointer](cast[uint64](a) - b.uint64)

proc `[]`*(p: pointer): ptr UncheckedArray[uint8] {.inline.} =
    return cast[ptr UncheckedArray[uint8]](p)

proc `[]=`*(p: pointer, offset: Natural, value: uint8) =
    (p + offset)[][0] = value

proc `[]`*(p: pointer, offset: Natural): uint8 =
    return (p + offset)[][0]
