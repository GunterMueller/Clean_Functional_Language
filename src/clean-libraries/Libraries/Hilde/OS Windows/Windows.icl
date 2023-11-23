implementation module Windows

import StdOverloaded, Marshall
import StdInt, StdString, StdMisc, StdBool, StdClass, StdChar, StdArray, StdList
import code from library "windowsKERNEL32_library"

instance marshall Handle Int
where
	marshall {handle} = copyInt handle

instance unmarshall Handle Int
where
	unmarshall x = {handle = x}

instance marshall Handle {#Char}
where
	marshall {handle} = marshall handle

instance unmarshall Handle {#Char}
where
	unmarshall x = {handle = unmarshall x}

instance marshall_ StartupInfo {#Char}
where
	marshall_ _ = zeroString 68

instance marshall_ ProcessInfo {#Char}
where
	marshall_ _ = zeroString 16

instance unmarshall ProcessInfo {#Char}
where
	unmarshall x 
		| size x <> 16 = abort "unmarshall ProcessInfo {#Char}"
		= {hProcess = unmarshall a, hThread = unmarshall b, dwProcessId = unmarshall c, dwThreadId = unmarshall d}
	where
		a = x % (0, 3)
		b = x % (4, 7)
		c = x % (8, 11)
		d = x % (12, 15)

instance marshall_ Win32FindData {#Char}
where
	marshall_ _ = zeroString (58 + MAX_PATH)

instance unmarshall Win32FindData {#Char}
where
	unmarshall x 
		| size x <> (58 + MAX_PATH) = abort "unmarshall Win32FindData {#Char}"
		= {dwFileAttributes = unmarshall (x % (0, 3)), cFileName = filename}
	where
		filename = case unmarshall (x % (44, 43 + MAX_PATH)) of
			"" -> unmarshall (x % (44 + MAX_PATH, 57 + MAX_PATH))
			else -> else

GetLastError :: !*env -> (!Int, !*env)
GetLastError world = code
	{	ccall GetLastError@0 "P:I:A"
	}

CloseHandle :: !Handle !*env -> (!Bool, !*env)
CloseHandle handle world
	# (ok, world) = closeHandle (marshall handle) world
	= (ok <> 0, world)
where
	closeHandle :: !Int !*env -> (!Int, !*env)
	closeHandle handle world = code inline {
		ccall	CloseHandle@4 "PI:I:A"
	}

FindFirstFile :: !String !*env -> (!Bool, Handle, Win32FindData, !*env)
FindFirstFile path world
	# (handle, buffer, world) = findFirstFile (marshall path) (marshall_ data) world
	= (handle <> INVALID_HANDLE_VALUE, unmarshall handle, unmarshall buffer, world)
where
	data :: Win32FindData
	data = undef
	
	findFirstFile :: !{#Char} !*{#Char} !*env -> (!Int, !*{#Char}, !*env)
	findFirstFile path data world = code inline {
		push_a		0		|A| 0:path 1:path 2:data 3:world
		update_a	2 1		|A| 0:path 1:data 2:data 3:world
		ccall FindFirstFileA@8 "Pss:I:AA"
	}

FindNextFile :: !Handle !*env -> (!Bool, Win32FindData, !*env)
FindNextFile handle world
	# (ok, data, world) = findNextFile (marshall handle) (marshall_ data) world
	= (ok <> 0, unmarshall data, world)
where
	data :: Win32FindData
	data = undef
	
	findNextFile :: !Int !*{#Char} !*env -> (!Int, !*{#Char}, !*env)
	findNextFile handle data world = code inline {
						||A 0:data | 1:world
		push_a		0	||A 0:data | 1:data | 2:world
		ccall FindNextFileA@8 "PIs:I:AA"
	}

FindClose :: !Handle !*env -> (!Bool, !*env)
FindClose handle world
	# (ok, world) = findClose (marshall handle) world
	= (ok <> 0, world)
where
	findClose :: !Int !*env -> (!Int, !*env)
	findClose handle world = code inline {
		ccall FindClose@4 "PI:I:A"
	}

DeleteFile :: !String !*env -> (!Bool, !*env)
DeleteFile path world 
	# (ok, world) = deleteFile (marshall path) world
	= (ok <> 0, world)
where
	deleteFile :: !{#Char} !*env -> (!Int, !*env)
	deleteFile path world = code inline {
		ccall DeleteFileA@4 "Ps:I:A"
	}

CreateDirectory :: !String !*env -> (!Bool, !*env)
CreateDirectory path world 
	# (ok, world) = createDirectory (marshall path) NULL world
	= (ok <> 0, world)
where
	createDirectory :: !{#Char} !Int !*env -> (!Int, !*env)
	createDirectory path _ world = code inline
	{	ccall CreateDirectoryA@8 "PsI:I:A"
	}

RemoveDirectory :: !String !*env -> (!Bool, !*env)
RemoveDirectory path world 
	# (ok, world) = removeDirectory (marshall path) world
	= (ok <> 0, world)
where
	removeDirectory :: !{#Char} !*env -> (!Int, !*env)
	removeDirectory path world = code inline
	{	ccall RemoveDirectoryA@4 "Ps:I:A"
	}

GetConsoleTitle :: !*env -> (!Bool, !*{#Char}, !*env)
GetConsoleTitle env
	# (ok, buffer, env) = getConsoleTitle MAX_PATH env
	= (ok <> 0, unmarshall buffer, env)
where
	getConsoleTitle :: !Int !*env -> (!Int, !*{#Char}, !*env)
	getConsoleTitle size world = code inline {
			push_b		0						|A| 0:world |B| 0:size 1:size
			create_array_ CHAR 0 1				|A| 0:!buffer 1:world |B| 0:size
			push_a		0						|A| 0:!buffer 1:!buffer 2:world |B| 0:size
			ccall GetConsoleTitleA@8 "PsI:I:AA"	|A| 0:!buffer 1:world |B| 0:result
		}

CreateProcess :: !String !Bool !Int !*env -> (!Bool, !ProcessInfo, !*env)
CreateProcess cmdline inherit flags world
	# (ok, buffer, world) = createProcess NULL (marshall cmdline) NULL NULL inherit flags NULL NULL  (marshall_ si) (marshall_ pi) world
	= (ok <> 0, unmarshall buffer, world)
where
	si :: StartupInfo
	si = undef
	pi :: ProcessInfo
	pi = undef
	createProcess :: !Int !{#Char} !Int !Int !Bool !Int !Int !Int !{#Char} !*{#Char} !*env -> (!Int, !*{#Char}, !*env)
	createProcess _ cmdline _ _ inherit flags _ _ startup info env = code inline {
						|A| cmdline startup info env
		push_a		0	|A| cmdline cmdline startup info env
		update_a	2 1	|A| cmdline startup startup info env
		update_a	3 2	|A| cmdline startup info info env
		ccall CreateProcessA@40 "PIsIIIIIIss:I:AA"
	}

TerminateProcess :: !Handle !Int !*env -> (!Bool, !*env)
TerminateProcess handle exitcode env 
	# (ok, env) = terminateProcess (marshall handle) exitcode env
	= (ok <> 0, env)
where
	terminateProcess :: !Int !Int !*env -> (!Int, !*env)
	terminateProcess handle exitcode env = code inline {
			ccall	TerminateProcess@8 "PII:I:A"
		}

GetCurrentProcessId :: !*env -> (!Int, !*env)
GetCurrentProcessId env = code {
		ccall	GetCurrentProcessId@0 "P:I:A"
	}

OpenProcess :: !Int !Bool !Int !*env -> (!Bool, !Handle, !*env)
OpenProcess access inherit id env
	# (handle, env) = openProcess access inherit id env
	= (handle <> NULL, unmarshall handle, env)
where
	openProcess :: !Int !Bool !Int !*env -> (!Int, !*env)
	openProcess access inherit id env = code inline {
			ccall	OpenProcess@12	"PIII:I:A"
		}

SetCurrentDirectory :: !String !*env -> (!Bool, !*env)
SetCurrentDirectory path env
	# (ok, env) = setCurrentDirectory (marshall path) env
	= (ok <> 0, env)
where
	setCurrentDirectory :: !{#Char} !*env -> (!Int, !*env)
	setCurrentDirectory path env = code inline {
			ccall	SetCurrentDirectoryA@4	"Ps:I:A"
		}
