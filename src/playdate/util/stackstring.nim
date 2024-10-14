import system/ansi_c

type
    StackString*[N : static int] = object
        ## A string allocated directly on the stack
        data: array[N, char]
        len: int32

proc len*(s: StackString): auto {.inline.} = s.len

proc capacity*[N: static int](s: StackString[N]): auto {.inline.} = N - 1

proc isFull*[N: static int](s: StackString[N]): auto {.inline.} = s.len >= s.capacity

template cstr*(s: StackString): auto = cast[cstring](addr s.data)

proc `$`*[N: static int](str: StackString[N]): string =
    ## Convert back to a nim native string
    assert(str.len < N)
    assert(str.data[str.len] == '\0')
    result = newString(str.len)
    for i in 0..<str.len:
        result[i] = str.data[i]

proc `==`*[AN: static int, BN: static int](a: StackString[AN], b: StackString[BN]): bool =
    ## Comparison
    if a.len != b.len:
        return false

    for i in 0..<a.len:
        if a.data[i] != b.data[i]:
            return false

    return true

proc `&=`*[N: static int](str: var StackString[N], other: cstring) =
    ## Append a cstring to a StackString
    var i = 0'i32
    var max = str.capacity - str.len
    while other[i] != '\0' and i < max:
        str.data[str.len + i] = other[i]
        i += 1
    str.len += i
    str.data[str.len] = '\0'

proc stackstring*(input: cstring, N: static int): StackString[N] =
    ## Constructor
    result &= input

proc stackstring*(value: StackString): auto {.inline.} = value
    ## Create a stack string from a number

proc strformat(format: cstring, value: auto, size: static int): StackString[size] {.inline.} =
    result.len = c_sprintf(cast[cstring](addr result.data), format, value)

proc stackstring*(value: int32): auto = strformat("%i", value, len($high(value.type)) + 1)
    ## Create a stack string from a number

proc stackstring*(value: pointer): auto = strformat("%p", value, 19)
    ## Create a stack string from a pointer

proc stackstring*(value: char): auto = strformat("%c", value, 2)
    ## Create a stack string from a character

proc stackstring*(value: byte): auto =
    ## Create a stack string from a byte
    if value == 0: stackstring("0x00", 5) else: strformat("%#04x", value, 5)

proc `&`*[AN: static int, BN: static int](a: StackString[AN], b: StackString[BN]): StackString[AN + BN] =
    ## Concat two stack strings
    result.len = a.len + b.len
    for i in 0..<a.len: result.data[i] = a.data[i]
    for i in 0..<b.len: result.data[i + a.len] = b.data[i]
    result.data[result.len] = '\0'

proc append*[AN: static int, BN: static int](a: var StackString[AN], b: StackString[BN]) =
    ## Appends a value to this stack string
    let newContentLen = min(AN - a.len - 1, b.len)
    for i in 0..<newContentLen:
        a.data[a.len + i] = b.data[i]
    a.len += newContentLen
    a.data[a.len] = '\0'

proc `&=`*(str: var StackString, other: auto) =
    str.append(stackstring(other))

proc suffix*[N: static int](str: var StackString[N], other: auto) =
    ## Adds a value to the end of a stack string
    let suff = stackstring(other)
    let newContentLen = min(N - 1, suff.len)
    let baseIdx = min(str.len, N - newContentLen - 1)
    for i in 0..<newContentLen:
        str.data[baseIdx + i] = suff.data[i]
    str.len = baseIdx + newContentLen
    str.data[str.len] = '\0'

proc clear*[N: static int](str: var StackString[N]) =
    ## Clears all data out of a string
    zeroMem(addr str, sizeof(StackString[N]))

proc appendBasename*[N: static int](str: var StackString[N], path: cstring) =
    ## Appends the basename of a path to a string
    let len = path.len
    var i = len - 1
    while i >= 0 and path[i] != '/':
        i -= 1
    for j in (i + 1)..<len:
        str &= path[j]
