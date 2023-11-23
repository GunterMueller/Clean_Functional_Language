definition module System._WinBase

import System._WinDef, StdInt
from _SystemArray import class Array(select,uselect,update), instance Array {#} Int
from System.Time import :: Timespec

/*
 * Record definitions, size and field offsets
 */

INT_SIZE :== IF_INT_64_OR_32 8 4

:: FILETIME :== {#Char}
FILETIME_size_bytes :== FILETIME_size_int * INT_SIZE
FILETIME_size_int :== 2

:: LPSYSTEMTIME :== {#Char}
SYSTEMTIME_size_bytes			:== 16//4 * INT_SIZE//16
SYSTEMTIME_wYear_offset			:== 0
SYSTEMTIME_wMonth_offset		:== 2
SYSTEMTIME_wDayOfWeek_offset	:== 4
SYSTEMTIME_wDay_offset			:== 6
SYSTEMTIME_wHour_offset			:== 8
SYSTEMTIME_wMinute_offset		:== 10
SYSTEMTIME_wSecond_offset		:== 12
SYSTEMTIME_wMilliseconds_offset	:== 14

:: LPSECURITY_ATTRIBUTES :== Int
:: SECURITY_ATTRIBUTES   :== {#Int}
:: LPTHREAD_START_ROUTINE :==Int
:: LPOVERLAPPED :== Int
OVERLAPPED_SIZE_BYTES		:== IF_INT_64_OR_32 40 20
CRITICAL_SECTION_SIZE_BYTES	:== IF_INT_64_OR_32 48 24
:: LPCRITICAL_SECTION :== Int

:: LPSTARTUPINFO :== {#Int}
STARTUPINFO_size_bytes :== IF_INT_64_OR_32 104 68
STARTUPINFO_size_int :== IF_INT_64_OR_32 13 17
STARTUPINFO_cb_int_offset :== 0
STARTUPINFO_set_dwFlags dwFlags struct :== IF_INT_64_OR_32
	(let (v,s) = struct![7] in {s & [7]=(v bitand 0xffffffff) bitor (dwFlags << 32)})
	{struct & [11]=dwFlags}
STARTUPINFO_hStdInput_int_offset :== IF_INT_64_OR_32 10 14
STARTUPINFO_hStdOutput_int_offset :== IF_INT_64_OR_32 11 15
STARTUPINFO_hStdError_int_offset :== IF_INT_64_OR_32 12 16

:: LPWIN32_FIND_DATA :== {#Char}
WIN32_FIND_DATA_size_bytes :== 320
WIN32_FIND_DATA_dwFileAttributes_bytes_offset :== 0
WIN32_FIND_DATA_ftCreationTime_bytes_offset :== 4
WIN32_FIND_DATA_ftLastAccessTime_bytes_offset :== 12
WIN32_FIND_DATA_ftLastWriteTime_bytes_offset :== 20
WIN32_FIND_DATA_nFileSizeHigh_bytes_offset :==28 
WIN32_FIND_DATA_nFileSizeLow_bytes_offset :== 32
WIN32_FIND_DATA_cFileName_bytes_offset :== 44

FILE_ATTRIBUTE_DIRECTORY :== 16

:: LPPROCESS_INFORMATION :== {#Int}
PROCESS_INFORMATION_size_bytes :== IF_INT_64_OR_32 24 16
PROCESS_INFORMATION_size_int :== IF_INT_64_OR_32 3 4
PROCESS_INFORMATION_hProcess_int_offset :== 0
PROCESS_INFORMATION_hThread_int_offset :== 1

SECURITY_ATTRIBUTES_SIZE_BYTES							:== INT_SIZE * SECURITY_ATTRIBUTES_SIZE_INT
SECURITY_ATTRIBUTES_SIZE_INT                            :== 3
SECURITY_ATTRIBUTES_nLength_BYTES_OFFSET				:== 0
SECURITY_ATTRIBUTES_nLength_INT_OFFSET				    :== 0
SECURITY_ATTRIBUTES_lpSecurityDescriptor_BYTES_OFFSET	:== INT_SIZE
SECURITY_ATTRIBUTES_bInheritHandle_BYTES_OFFSET			:== INT_SIZE * 2
SECURITY_ATTRIBUTES_bInheritHandle_INT_OFFSET			:== 2

/*
 * Macros
 */

DETACHED_PROCESS :== 8
FORMAT_MESSAGE_ALLOCATE_BUFFER :== 0x00000100
FORMAT_MESSAGE_FROM_SYSTEM :== 0x00001000
FORMAT_MESSAGE_IGNORE_INSERTS :== 0x00000200
INFINITE :== 0xFFFFFFFF
LANGUAGE_NEUTRAL_SUBLANG_DEFAULT :== 0x400
STARTF_USESTDHANDLES :== 0x00000100
STATUS_PENDING :== 0x00000103
STILL_ACTIVE :== STATUS_PENDING
WAIT_ABANDONED_0 :== 0x80
WAIT_FAILED :== 0xFFFFFFFF
WAIT_OBJECT_0 :== 0
WAIT_TIMEOUT :== 258

GENERIC_READ :== 0x80000000
GENERIC_WRITE :== 0x40000000
FILE_SHARE_READ :== 0x00000001
FILE_SHARE_WRITE :== 0x00000002

CREATE_ALWAYS		:== 2
CREATE_NEW			:== 1
OPEN_ALWAYS			:== 4
OPEN_EXISTING		:== 3
TRUNCATE_EXISTING	:== 5

FILE_ATTRIBUTE_NORMAL :== 128
LOCKFILE_EXCLUSIVE_LOCK :== 0x00000002

HEAP_ZERO_MEMORY :== 0x00000008
CREATE_SUSPENDED :== 0x00000004
SYNCHRONIZE :== 0x00100000

HANDLE_FLAG_INHERIT :== 0x00000001

/*
 * Windows API calls 
 */

closeHandle :: !HANDLE !*w -> (!Bool,!*w)
setHandleInformation :: !HANDLE !DWORD !DWORD !*w -> (!Bool, !*w)
	
createFileA :: !String !DWORD !DWORD !LPSECURITY_ATTRIBUTES 
	!DWORD !DWORD !HANDLE !*w -> (!HANDLE, !*w)
	
readFile :: !HANDLE !LPVOID !DWORD !LPDWORD !LPOVERLAPPED !*w -> (!Bool, !*w)

writeFile :: !HANDLE !String !DWORD !LPDWORD !LPOVERLAPPED !*w -> (!Bool, !*w)

setEndOfFile :: !HANDLE !*w -> (!Bool, !*w)

lockFileEx :: !HANDLE !DWORD !DWORD !DWORD !DWORD !LPOVERLAPPED !*w -> (!Bool, !*w)

unlockFile :: !HANDLE !DWORD !DWORD !DWORD !DWORD !*w -> (!Bool, !*w)

getFileSize :: !HANDLE !LPDWORD !*w -> (!DWORD, !*w)

getFullPathNameA :: !String !DWORD !String !LPTSTR !*w -> (!DWORD, !*w)

createDirectoryA :: !String !LPSECURITY_ATTRIBUTES !*w -> (!Bool, !*w)

createProcessA :: !String !String !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int !LPVOID
					!LPCTSTR !LPSTARTUPINFO !LPPROCESS_INFORMATION !*w -> (!Bool,!*w)

createProcessA_dir :: !String !String !LPSECURITY_ATTRIBUTES !LPSECURITY_ATTRIBUTES !Bool !Int !LPVOID
					!String !LPSTARTUPINFO !LPPROCESS_INFORMATION !*w -> (!Bool,!*w)

terminateProcess :: !HANDLE !Int !*w -> (!Bool, !*w)

deleteFileA :: !String !*w -> (!Int, !*w)

fileTimeToSystemTime :: !FILETIME !LPSYSTEMTIME !*w -> (!Bool, *w)

findClose :: !HANDLE !*w -> (!Bool, !*w)

findFirstFileA :: !String !LPWIN32_FIND_DATA !*w -> (!HANDLE, !*w)

findNextFileA :: !HANDLE !LPWIN32_FIND_DATA !*w -> (!Bool, !*w)

formatMessageA :: !DWORD !LPCVOID !DWORD !DWORD !{#LPTSTR} !DWORD !Int -> DWORD

getCurrentDirectoryA :: !DWORD !{#Char} !*w -> (!DWORD, *w)

getExitCodeProcess :: !HANDLE !*w -> (!Bool,!Int,!*w);


getLastError :: !*w -> (!Int, !*w)

localFree :: !HLOCAL -> HLOCAL

moveFileA :: !String !String !*w -> (!Bool, !*w)

copyFileA :: !String !String !Bool !*w -> (!Bool, !*w)

removeDirectoryA :: !String !*w -> (!Bool, !*w)

setCurrentDirectoryA :: !String !*w -> (!Bool, !*w)

waitForSingleObject :: !HANDLE !Int !*env -> (!Int,!*env)

waitForMultipleObjects :: !Int !{#HANDLE} !Bool !Int !*env -> (!Int, !*env)

getProcessHeap :: !*env -> (!HANDLE, !*env)

heapAlloc :: !HANDLE !DWORD !SIZE_T !*env -> (!LPVOID, !*env)
heapFree :: !HANDLE !DWORD !LPVOID !*env -> (!Bool, !*env)
heapCreate :: !DWORD !SIZE_T !SIZE_T !*w -> (!HANDLE, !*w)

CreateThread :: !LPSECURITY_ATTRIBUTES !SIZE_T !LPTHREAD_START_ROUTINE !LPVOID !DWORD !*w -> (!HANDLE,!DWORD,!*w)
ResumeThread :: !HANDLE !*w -> (!DWORD, *w)
TerminateThread :: !HANDLE !DWORD !*w -> (!Bool, *w)

initializeCriticalSection :: !LPCRITICAL_SECTION !*w -> *w
initializeCriticalSectionAndSpinCount :: !LPCRITICAL_SECTION !DWORD !*w -> (!Bool, !*w)
enterCriticalSection :: !LPCRITICAL_SECTION !*w -> *w
leaveCriticalSection :: !LPCRITICAL_SECTION !*w -> *w

createMutexA :: !LPSECURITY_ATTRIBUTES !Bool !LPCTSTR !*env -> (!HANDLE, !*env)
releaseMutex :: !HANDLE !*env -> (!Bool, !*env)
createEventA :: !LPSECURITY_ATTRIBUTES !Bool !Bool !LPCTSTR !*w -> (!HANDLE, !*w)
setEvent :: !HANDLE !*env -> (!Bool, !*env)

WinGetThreadId :: !HANDLE !*w -> (!DWORD, !*w)
WinGetCurrentThreadId :: !*w -> (!DWORD, !*w)
WinOpenThread :: !DWORD !Bool !DWORD *w -> (!DWORD, !*w)

sleep :: !DWORD !*w -> *w

createPipe :: !PHANDLE !PHANDLE !SECURITY_ATTRIBUTES !DWORD !*w -> (!Bool, !*w)
peekNamedPipe :: !HANDLE !LPVOID !DWORD !LPDWORD !LPDWORD !LPDWORD !*w -> (!Bool, !*w)

GetSystemTimeAsFileTime :: !{#Int} !*World -> (!{#Int},!*World)
fileTimeToTimeSpec :: !{#Int} -> Timespec
