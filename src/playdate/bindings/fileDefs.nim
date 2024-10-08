
type SDFilePtr* = pointer

type FileOptions* {.importc: "FileOptions", header: "pd_api.h".} = enum
    kFileRead = (1 shl 0), kFileReadData = (1 shl 1), kFileWrite = (1 shl 2),
    kFileAppend = (2 shl 2)

type FileStatRaw* {.importc: "FileStat", header: "pd_api.h".} = object
    isdir* {.importc: "isdir".}: cint
    size* {.importc: "size".}: cuint
    mYear* {.importc: "m_year".}: cint
    mMonth* {.importc: "m_month".}: cint
    mDay* {.importc: "m_day".}: cint
    mHour* {.importc: "m_hour".}: cint
    mMinute* {.importc: "m_minute".}: cint
    mSecond* {.importc: "m_second".}: cint

type FileStatPtr* = ptr FileStatRaw
type FileStat* = ref FileStatRaw

when not defined(SEEK_SET):
    const
        SEEK_SET* = 0
        SEEK_CUR* = 1
        SEEK_END* = 2