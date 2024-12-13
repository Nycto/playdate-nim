import unittest, playdate/util/stackring, std/options

suite "Stack ring":

    test "Pushing and popping":
        var ring: StackRing[4, int]

        check(ring.len == 0)
        check(ring.addLast(2))
        check(ring.len == 1)
        check(ring.addLast(4))
        check(ring.len == 2)
        check(ring.addLast(6))
        check(ring.len == 3)

        check(ring.popFirst() == 2)
        check(ring.len == 2)
        check(ring.popFirst() == 4)
        check(ring.len == 1)
        check(ring.popFirst() == 6)
        check(ring.len == 0)
        check(ring.popFirst() == 0)

    test "Wrapping around the storage length":
        var ring: StackRing[4, int]

        for i in 0..19:
            check(ring.len == 0)
            check(ring.addLast(i))
            check(ring.len == 1)
            check(ring.popFirst() == i)

    test "Pushing onto a full ring":
        var ring: StackRing[2, int]
        check(ring.len == 0)
        check(ring.addLast(1))
        check(ring.len == 1)
        check(ring.addLast(2))
        check(ring.len == 2)
        check(not ring.addLast(3))
        check(ring.len == 2)

        check(ring.popFirst() == 1)
        check(ring.popFirst() == 2)
        check(ring.popFirst() == 0)

    test "Popping from an empty ring":
        var ring: StackRing[2, int]
        check(ring.popFirst() == 0)