##
## Creates a visualization image of memory allocations
##

import std/[os, strutils, parseutils, strformat, tables, algorithm]

doAssert(paramCount() == 1)

type
    EventKind = enum alloc, dealloc, realloc

    Event = object
        actionIndex: int
        kind: EventKind
        input, output, size, yCoord: int64
        stack: string

var events: seq[Event]

proc parse(actionIdx, lineNum: int, line: string, output: var Event): bool =
    let parts = line.split(',', 5)
    if parts.len != 5:
        stderr.writeLine(fmt"Invalid format on line {lineNum + 1}: {line}")
        return false
    else:
        try:
            output.kind = parseEnum[EventKind](parts[0])
        except ValueError as e:
            stderr.writeLine(fmt"Invalid action on line {lineNum + 1}: {e.msg}")
            return false

        if parseHex(parts[1], output.input) == 0:
            stderr.writeLine(fmt"Invalid input pointer on line {lineNum + 1}: {line}")
            return false

        if parseHex(parts[2], output.output) == 0:
            stderr.writeLine(fmt"Invalid output pointer on line {lineNum + 1}: {line}")
            return false

        output.yCoord = output.input
        output.size = parseInt(parts[3])
        output.stack = parts[4]
        output.actionIndex = actionIdx
        return true

block:
    var lineNum = 0
    var actionIdx = 0
    for line in lines(paramStr(1)):
        var event: Event
        if parse(actionIdx, lineNum, line, event):
            actionIdx += 1
            events.add(event)
        lineNum += 1

block:
    var adjustment = 0
    var maxOffset = 0
    for event in events.sortedByIt(it.output):
        let newY = min(maxOffset + 500, event.output - adjustment)
        maxOffset = max(maxOffset, newY + event.size)
        adjustment = event.output - newY
        events[event.actionIndex].yCoord = newY

proc memoryBounds(): tuple[minPointer, entries, minSize, maxYCoord: int64] =
    for event in events:
        let eventMin = min(event.input, event.output)
        result.minPointer = if result.minPointer == 0: eventMin else: min(eventMin, result.minPointer)

        if event.size > 0:
            result.minSize = if result.minSize == 0: event.size else: min(result.minSize, event.size)

        result.maxYCoord = max(event.yCoord + event.size, result.maxYCoord)

        case event.kind
        of alloc, dealloc: result.entries += 1
        of realloc: result.entries += 2

let (minPointer, entries, minSize, maxYCoord) = memoryBounds()

const ROW_WIDTH = 2
const LEGEND_HEIGHT = 28
const LEGEND_MARGIN = 5
const LEGEND_TEXT_Y = 20

let width = max(entries * ROW_WIDTH, 800)

let overallheight = maxYCoord div minSize + LEGEND_HEIGHT + LEGEND_MARGIN + 50

proc legendSwatch(x: int, class, title, hover: string): string =
    return fmt"""
        <rect class="{class}" height="{LEGEND_TEXT_Y}" width="{LEGEND_TEXT_Y}" y="4" x="{x}">
            <title>{hover}</title>
        </rect>
        <text x="{x + LEGEND_TEXT_Y + 10}" y="{LEGEND_TEXT_Y}" class="subtext">{title}</text>
    """

echo fmt"""<svg height="{overallheight}" width="{width}" xmlns="http://www.w3.org/2000/svg">"""
echo fmt"""
  <style>
    .alloc {{ fill: skyblue; }}
    .alloc-no-dealloc {{ fill: blue; }}
    .unmanaged-dealloc {{ fill: red; }}
    .alloc, .unmanaged-dealloc, .alloc-no-dealloc {{ opacity: 60%; }}
    .alloc:hover, .unmanaged-dealloc:hover, .alloc-no-dealloc:hover {{ opacity: 90%; }}

    .title {{ font-size: 18px; }}
    .subtext {{ font-size: 16px; }}
  </style>
  <rect x="0" y="0" width="100%" height="{LEGEND_HEIGHT}" stroke="black" fill="white" />
  <text x="5" y="{LEGEND_TEXT_Y}" class="title">Legend</text>

  <text x="100" y="{LEGEND_TEXT_Y}" class="subtext">↕ Memory Address</text>
  <text x="300" y="{LEGEND_TEXT_Y}" class="subtext">↔ Time</text>
  {legendSwatch(400, "alloc", "Memory Allocation", "A typical memory allocation with a correctly matched free")}
  {legendSwatch(630, "alloc-no-dealloc", "Unfreed Memory", "Memory that is allocated, but never freed")}
  {legendSwatch(840, "unmanaged-dealloc", "Unmanaged free", "An attempt to free memory that has no matching allocation. For example, a double free")}
"""

proc x(entryId: SomeInteger): auto = entryId * ROW_WIDTH

proc pointerName(pointerVal: int64): string =
    let hex = toHex(pointerVal)
    return fmt"0x{hex} (rel addr: {pointerVal - minPointer})"

proc rectangle(yCoord, size, startEntry, endEntry: int64; id, class, label: string): string =
    let width = endEntry.x - startEntry.x
    let height = size div minSize
    let y = yCoord div minSize + LEGEND_HEIGHT + LEGEND_MARGIN
    return [
        fmt"""<a href="#{id}">""",
        fmt""" <rect id="{id}" height="{height}" width="{width}" y="{y}" x="{startEntry.x}" class="{class}">""",
        fmt"""  <title>{label}</title>""",
        fmt""" </rect>""",
        fmt"""</a>""",
    ].join("\n")

proc label(event: Event): string =
    case event.kind
    of alloc: result = &"Allocation of {event.output.pointerName}\n"
    of dealloc: result = &"Deallocation of {event.input.pointerName}\n"
    of realloc: result = &"Realloc from {event.input.pointerName} to {event.output.pointerName}\n"

    result &= &"Size: {event.size}\n\n"
    result &= event.stack.split('|').join("\n")
    # fmt"""Action Indexes: {startEntry}-{endEntry}""",

proc rectangle(event: Event; startEntry, endEntry: int64; class: string): string =
    return rectangle(event.yCoord, event.size, startEntry, endEntry, $startEntry, class, event.label)

var openAllocs = initTable[int64, (int, Event)](events.len)

proc renderDealloc(entryId: int, dealloced: Event) =
    if dealloced.input in openAllocs:
        let (ogEntryId, event) = openAllocs[dealloced.input]
        echo event.rectangle(ogEntryId, entryId, "alloc")
        openAllocs.del(dealloced.input)
    else:
        echo rectangle(
            dealloced.yCoord,
            minSize * 2,
            0,
            entryId,
            $entryId,
            "unmanaged-dealloc",
            dealloced.label
        )

proc renderAlloc(entryId: int, event: Event) =
    doAssert(event.size > 0)
    if event.output in openAllocs:
        let (ogEntryId, event) = openAllocs[event.output]
        echo event.rectangle(ogEntryId, entryId, "alloc-no-dealloc")
    openAllocs[event.output] = (entryId, event)

block:
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