{.push raises: [].}

import utils, fileDefs
export fileDefs

sdktype:
    type PlaydateFile* {.importc: "const struct playdate_file", header: "pd_api.h".} = object
        geterr {.importc: "geterr".}: proc (): cstring {.cdecl, raises: [].}
        listfiles {.importc: "listfiles".}: proc (path: cstring;
            callback: proc (path: cstring; userdata: pointer) {.cdecl.}; userdata: pointer;
            showhidden: cint): cint {.cdecl, raises: [].}
        stat {.importc: "stat".}: proc (path: cstring; stat: FileStatPtr): cint {.cdecl, raises: [].}
        mkdir {.importc: "mkdir".}: proc (path: cstring): cint {.cdecl, raises: [].}
        unlink {.importc: "unlink".}: proc (name: cstring; recursive: cint): cint {.cdecl, raises: [].}
        rename {.importc: "rename".}: proc (`from`: cstring; to: cstring): cint {.cdecl, raises: [].}
        open {.importc: "open".}: proc (name: cstring; mode: FileOptions): SDFilePtr {.cdecl, raises: [].}
        close {.importc: "close".}: proc (file: SDFilePtr): cint {.cdecl, raises: [].}
        read {.importc: "read".}: proc (file: SDFilePtr; buf: pointer; len: cuint): cint {.
            cdecl, raises: [].}
        write {.importc: "write".}: proc (file: SDFilePtr; buf: pointer; len: cuint): cint {.
            cdecl, raises: [].}
        flush {.importc: "flush".}: proc (file: SDFilePtr): cint {.cdecl, raises: [].}
        tell {.importc: "tell".}: proc (file: SDFilePtr): cint {.cdecl, raises: [].}
        seek {.importc: "seek".}: proc (file: SDFilePtr; pos: cint; whence: cint): cint {.
            cdecl, raises: [].}