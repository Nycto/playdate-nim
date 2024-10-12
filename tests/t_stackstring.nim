import unittest, playdate/util/stackstring, strutils, sequtils

suite "Stack allocated strings":

    test "Should be constructable from cstrings":
        check($stackstring("abc", 4) == "abc")
        check($stackstring("def", 4) == "def")
        check($stackstring("lmnop", 10) == "lmnop")
        check($stackstring("this is longer than allocated", 5) == "this")

    test "Comparing stack strings":
        check(stackstring("abc", 4) == stackstring("abc", 4))
        check(stackstring("abc", 4) == stackstring("abc", 50))
        check(stackstring("abc", 4) != stackstring("def", 4))

    test "Int to string":
        check($stackstring(1234'i32) == "1234")
        check($stackstring(2147483647'i32) == "2147483647")

    test "Pointer to string":
        check($stackstring(cast[pointer](0x7ffc3f97a5c0)) == "0x7ffc3f97a5c0")
        check($stackstring(cast[pointer](0xFFFFFFFFFFFFFFFF)) == "0xffffffffffffffff")

    test "Char to string":
        check($stackstring('a') == "a")

    test "byte to string":
        check($stackstring(0x00.byte) == "0x00")
        check($stackstring(0x01.byte) == "0x01")
        check($stackstring(0xFF.byte) == "0xff")

    test "Concatentating stack strings":
        check($(stackstring("abc", 4) & stackstring("abc", 4)) == "abcabc")

    test "Appending to a string":
        var str: StackString[16]
        check($str == "")

        str.append(stackstring("foo", 10))
        check($str == "foo")

        str.append(stackstring(" bar baz", 10))
        check($str == "foo bar baz")

        str.append(stackstring(" this is way too much content that would overflow things", 20))
        check($str == "foo bar baz thi")

        str.append(stackstring("Ignored", 20))
        check($str == "foo bar baz thi")

    test "Appending values to a string":
        var str: StackString[16]

        str &= stackstring("foo", 10)
        check($str == "foo")

        str &= ' '
        check($str == "foo ")

        str &= 123'i32
        check($str == "foo 123")

    test "Suffixing a value on a string":
        var str: StackString[16]

        str.suffix(stackstring("foo bar", 20))
        check($str == "foo bar")

        str.suffix(stackstring(" baz", 20))
        check($str == "foo bar baz")

        str.suffix(stackstring("What the", 20))
        check($str == "foo barWhat the")

    test "Clearing values":
        var str = stackstring("abc", 10)
        str.clear()
        check(str.len == 0)
        check($str == "")

    test "appending c strings":
        var str: StackString[16]
        str &= "foo".cstring
        check($str == "foo")
        check(str.len == 3)

        str &= " and wakka".cstring
        check($str == "foo and wakka")
        check(str.len == 13)

        str &= " ugh".cstring
        check($str == "foo and wakka u")
        check(str.len == 15)

        str &= " ugh".cstring
        check($str == "foo and wakka u")
        check(str.len == 15)

    test "isFull":
        var str = stackstring("foo", 10)
        check(not str.isFull)
        str &= "bar".stackstring(10)
        check(not str.isFull)
        str &= "baz".stackstring(10)
        check(str.isFull)

    test "Memory dumping":
        var result: string
        proc addToResult(str: auto) = result &= $str
        var value = [ 'a'.byte, 'b'.byte, 'c'.byte, 0x01, 0x02, 0x03 ]
        dumpMemory(addr value, value.len, addToResult)
        check(result == "a b c 0x01 0x02 0x03")

    test "Multi-line Memory dumping":
        var result: string
        proc addToResult(str: auto) = result &= $str & "\n"
        var data: array[255, byte]
        for i in 0..<data.len:
            data[i] = i.byte

        dumpMemory(addr data, data.len, addToResult)
        let expect = [
            "0x00 0x01 0x02 0x03 0x04 0x05 0x06 0x07 0x08 0x09 0x0a 0x0b 0x0c 0x0d 0x0e 0x0f",
            "0x10 0x11 0x12 0x13 0x14 0x15 0x16 0x17 0x18 0x19 0x1a 0x1b 0x1c 0x1d 0x1e 0x1f",
            "0x20 0x21 0x22 0x23 0x24 0x25 0x26 0x27 0x28 ) * + , - . /",
            "0 1 2 3 4 5 6 7 8 9 : ; < = > ?",
            "@ A B C D E F G H I J K L M N O",
            "P Q R S T U V W X Y Z [ \\ ] ^ _",
            "` a b c d e f g h i j k l m n o",
            "p q r s t u v w x y z { | } ~ 0x7f",
            "0x80 0x81 0x82 0x83 0x84 0x85 0x86 0x87 0x88 0x89 0x8a 0x8b 0x8c 0x8d 0x8e 0x8f",
            "0x90 0x91 0x92 0x93 0x94 0x95 0x96 0x97 0x98 0x99 0x9a 0x9b 0x9c 0x9d 0x9e 0x9f",
            "0xa0 0xa1 0xa2 0xa3 0xa4 0xa5 0xa6 0xa7 0xa8 0xa9 0xaa 0xab 0xac 0xad 0xae 0xaf",
            "0xb0 0xb1 0xb2 0xb3 0xb4 0xb5 0xb6 0xb7 0xb8 0xb9 0xba 0xbb 0xbc 0xbd 0xbe 0xbf",
            "0xc0 0xc1 0xc2 0xc3 0xc4 0xc5 0xc6 0xc7 0xc8 0xc9 0xca 0xcb 0xcc 0xcd 0xce 0xcf",
            "0xd0 0xd1 0xd2 0xd3 0xd4 0xd5 0xd6 0xd7 0xd8 0xd9 0xda 0xdb 0xdc 0xdd 0xde 0xdf",
            "0xe0 0xe1 0xe2 0xe3 0xe4 0xe5 0xe6 0xe7 0xe8 0xe9 0xea 0xeb 0xec 0xed 0xee 0xef",
            "0xf0 0xf1 0xf2 0xf3 0xf4 0xf5 0xf6 0xf7 0xf8 0xf9 0xfa 0xfb 0xfc 0xfd 0xfe",
            "",
        ]

        for i, line in split(result, "\n").toSeq:
            check(expect[i] == line)
