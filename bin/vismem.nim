##
## Creates a visualization image of memory allocations
##

import std/[os, strutils, parseutils, strformat, tables]

doAssert(paramCount() == 1)

type
    EventKind = enum alloc, dealloc, realloc

    Event = object
        kind: EventKind
        input, output, size: int64
        stack: string

proc copy(
    event: Event,
    kind: EventKind = event.kind,
    input: int64 = event.input,
    output: int64 = event.output,
    size: int64 = event.size,
): Event =
    result.kind = kind
    result.input = input
    result.output = output
    result.size = size
    result.stack = event.stack

var events: seq[Event]

proc parse(line: string): Event =
    let parts = line.split(',', 5)
    doAssert(parts.len == 5)
    result.kind = parseEnum[EventKind](parts[0])
    doAssert(parseHex(parts[1], result.input) > 0)
    doAssert(parseHex(parts[2], result.output) > 0)
    result.size = parseInt(parts[3])
    result.stack = parts[4]

for line in lines(paramStr(1)):
    events.add(parse(line))

proc memoryBounds(): tuple[minPointer, maxPointer, entries, minSize: int64] =
    for event in events:
        let eventMin = min(event.input, event.output)
        result.minPointer = if result.minPointer == 0: eventMin else: min(eventMin, result.minPointer)
        result.maxPointer = max(max(event.input, event.output) + event.size, result.maxPointer)
        doAssert(result.minPointer < result.maxPointer)

        if event.size > 0:
            result.minSize = if result.minSize == 0: event.size else: min(result.minSize, event.size)

        case event.kind
        of alloc, dealloc: result.entries += 1
        of realloc: result.entries += 2

const ROW_WIDTH = 2

let (minPointer, maxPointer, entries, minSize) = memoryBounds()

let overallheight = (maxPointer - minPointer) div minSize
echo fmt"""<svg height="{overallheight}" width="{entries * ROW_WIDTH}" xmlns="http://www.w3.org/2000/svg">"""
echo """
  <style>
    .alloc {
      fill: skyblue;
      stroke-width: 1px;
    }
    .alloc-no-dealloc {
      fill: blue;
    }
    .unmanaged-dealloc {
      fill: red;
    }

    .alloc, .unmanaged-dealloc, .alloc-no-dealloc {
      opacity: 60%;
    }

    .alloc:hover, .unmanaged-dealloc:hover, .alloc-no-dealloc:hover {
        opacity: 90%;
    }
  </style>
"""

proc y(pointerVal: SomeInteger): auto = (pointerVal - minPointer) div minSize

proc x(entryId: SomeInteger): auto = entryId * ROW_WIDTH

proc pointerName(pointerVal: int64): string =
    let hex = toHex(pointerVal)
    return fmt"{pointerVal - minPointer} (0x{hex})"

proc rectangle(startPtr, size, startEntry, endEntry: int64; id, class, label, stack: string): string =
    let width = endEntry.x - startEntry.x
    let height = size div minSize
    return [
        fmt"""<a href="#{id}">""",
        fmt""" <rect id="{id}" height="{height}" width="{width}" y="{startPtr.y}" x="{startEntry.x}" class="{class}">""",
        fmt"""  <title>""",
        fmt"""{label}""",
        fmt"""Addr: {startPtr.pointerName}""",
        fmt"""Size: {size}""",
        fmt"""Action Indexes: {startEntry}-{endEntry}""",
        fmt"""{stack.split('|').join("\n")}""",
        fmt"""  </title>""",
        fmt""" </rect>""",
        fmt"""</a>""",
    ].join("\n")

proc label(event: Event): string =
    case event.kind
    of alloc: return fmt"Allocation of {event.output.pointerName}"
    of dealloc: return fmt"Deallocation of {event.input.pointerName}"
    of realloc: return fmt"Realloc from {event.input.pointerName} to {event.output.pointerName}"

proc rectangle(event: Event; startEntry, endEntry: int64; class: string): string =
    return rectangle(event.output, event.size, startEntry, endEntry, $startEntry, class, event.label, event.stack)

var openAllocs = initTable[int64, (int, Event)](events.len)

proc renderDealloc(entryId: int, dealloced: Event) =
    if dealloced.input in openAllocs:
        let (ogEntryId, event) = openAllocs[dealloced.input]
        echo event.rectangle(ogEntryId, entryId, "alloc")
        openAllocs.del(dealloced.input)
    else:
        echo rectangle(
            dealloced.input,
            minSize * 2,
            0,
            entryId,
            $entryId,
            "unmanaged-dealloc",
            dealloced.label,
            dealloced.stack
        )

proc renderAlloc(entryId: int, event: Event) =
    doAssert(event.size > 0)
    if event.output in openAllocs:
        let (ogEntryId, event) = openAllocs[event.output]
        echo event.rectangle(ogEntryId, entryId, "alloc-no-dealloc")
    openAllocs[event.output] = (entryId, event)

var i = 0
for event in events:
    case event.kind
    of dealloc:
        doAssert(event.input == event.output)
        doAssert(event.size == 0)
        renderDealloc(i, event)
    of realloc:
        renderDealloc(i, event)
        i += 1
        renderAlloc(i, event)
    of alloc:
        doAssert(event.input == event.output)
        renderAlloc(i, event)
    i += 1

for _, (entryId, event) in openAllocs:
    echo event.rectangle(entryId, entries, "alloc-no-dealloc")

echo "</svg>"