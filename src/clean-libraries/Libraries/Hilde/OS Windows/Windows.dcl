definition module Windows

import StdOverloaded, Marshall

NULL :== 0
INVALID_HANDLE_VALUE :== -1
INVALID_SET_FILE_POINTER :== -1
MAX_PATH :== 260
STILL_ACTIVE :== 259
FILE_ATTRIBUTE_READONLY	:== 1
FILE_ATTRIBUTE_HIDDEN :== 2
FILE_ATTRIBUTE_SYSTEM :== 4
FILE_ATTRIBUTE_DIRECTORY :== 16
FILE_ATTRIBUTE_ARCHIVE :== 32
FILE_ATTRIBUTE_NORMAL :== 128
CREATE_DEFAULT_ERROR_MODE :== 67108864
CREATE_NEW_CONSOLE :== 16
CREATE_NEW_PROCESS_GROUP :== 512
CREATE_SUSPENDED :== 4
DETACHED_PROCESS :== 8
CREATE_NO_WINDOW :== 0x8000000
PROCESS_TERMINATE :== 1
PROCESS_CREATE_THREAD :== 2
PROCESS_VM_OPERATION :== 8
PROCESS_VM_READ :== 16
PROCESS_VM_WRITE :== 32
PROCESS_DUP_HANDLE :== 64
PROCESS_CREATE_PROCESS :== 128
PROCESS_SET_QUOTA :== 256
PROCESS_SET_INFORMATION :== 512
PROCESS_QUERY_INFORMATION :== 1024

:: Handle = {handle :: !Int}

:: StartupInfo = StartupInfo 

:: ProcessInfo = 
	{ hProcess :: !Handle
	, hThread :: !Handle
	, dwProcessId :: !Int
	, dwThreadId :: !Int
	}

:: Win32FindData =
	{ dwFileAttributes :: !Int
	, cFileName :: !String
	}

instance marshall Handle Int
instance unmarshall Handle Int

instance marshall Handle {#Char}
instance unmarshall Handle {#Char}

instance marshall_ StartupInfo {#Char}

instance marshall_ ProcessInfo {#Char}
instance unmarshall ProcessInfo {#Char}

instance marshall_ Win32FindData {#Char}
instance unmarshall Win32FindData {#Char}

GetLastError :: !*env -> (!Int, !*env)
CloseHandle :: !Handle !*env -> (!Bool, !*env)
FindFirstFile :: !String !*env -> (!Bool, Handle, Win32FindData, !*env)
FindNextFile :: !Handle !*env -> (!Bool, Win32FindData, !*env)
FindClose :: !Handle !*env -> (!Bool, !*env)
DeleteFile :: !String !*env -> (!Bool, !*env)
CreateDirectory :: !String !*env -> (!Bool, !*env)
RemoveDirectory :: !String !*env -> (!Bool, !*env)
GetConsoleTitle :: !*env -> (!Bool, !*{#Char}, !*env)
CreateProcess :: !String !Bool !Int !*env -> (!Bool, !ProcessInfo, !*env)
TerminateProcess :: !Handle !Int !*env -> (!Bool, !*env)
GetCurrentProcessId :: !*env -> (!Int, !*env)
OpenProcess :: !Int !Bool !Int !*env -> (!Bool, !Handle, !*env)
SetCurrentDirectory :: !String !*env -> (!Bool, !*env)
