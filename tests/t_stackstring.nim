import unittest, playdate/util/stackstring

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