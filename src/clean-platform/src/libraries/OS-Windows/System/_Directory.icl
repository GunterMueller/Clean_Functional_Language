implementation module System._Directory

import StdArray, StdBool, StdClass, StdInt, StdChar, StdString

import System.File
import System.FilePath
import System.OSError

import qualified System._Windows
import System._Pointer

createDirectory :: !FilePath !*w -> (!MaybeOSError (), !*w)
createDirectory path world
	# (ok,world)	= 'System._Windows'.createDirectoryA (packString path) 'System._Windows'.NULL world
	| ok
		= (Ok (), world)
	| otherwise
		= getLastOSError world

removeDirectory :: !FilePath !*w -> (!MaybeOSError (), !*w)
removeDirectory path world
	# (ok,world)	= 'System._Windows'.removeDirectoryA (packString path) world
	| ok
		= (Ok (), world)
	| otherwise
		= getLastOSError world

readDirectory :: !FilePath !*w -> (!MaybeOSError [FilePath], !*w)
readDirectory path world
	# win32FindData = createArray 'System._Windows'.WIN32_FIND_DATA_size_bytes '\0'
	# (handle, world) = 'System._Windows'.findFirstFileA (packString (path </> "*.*")) win32FindData world
	| handle == 'System._Windows'.INVALID_HANDLE_VALUE = getLastOSError world
	# (entry, world)	= readEntry win32FindData world
	# (entries,world)	= readEntries handle win32FindData world
	# (ok,world) = 'System._Windows'.findClose handle world
	| not ok = getLastOSError world
	= (Ok [entry:entries], world)
where
	readEntries :: !'System._Windows'.HANDLE !'System._Windows'.LPWIN32_FIND_DATA !*w -> (![String],!*w)
	readEntries handle win32FindData world
		# (ok,world)	= 'System._Windows'.findNextFileA handle win32FindData world
		| not ok
			= ([],world)
		# (entry,world)		= readEntry win32FindData world
		# (entries,world)	= readEntries handle win32FindData world
		= ([entry:entries],world)
	
	readEntry :: !'System._Windows'.LPWIN32_FIND_DATA !*w -> (!String,!*w) 
	readEntry win32FindData world 
		= (unpackString (win32FindData % ('System._Windows'.WIN32_FIND_DATA_cFileName_bytes_offset, 'System._Windows'.WIN32_FIND_DATA_cFileName_bytes_offset + 'System._Windows'.MAX_PATH - 1)), world)

getCurrentDirectory :: !*w -> (!MaybeOSError FilePath, !*w)
getCurrentDirectory world
	# buf			= createArray 'System._Windows'.MAX_PATH '\0'
	# (res,world)	= 'System._Windows'.getCurrentDirectoryA 'System._Windows'.MAX_PATH buf world
	| res == 0
		= getLastOSError world
	| otherwise
		= (Ok (unpackString buf),world)

setCurrentDirectory :: !FilePath !*w -> (!MaybeOSError (), !*w)
setCurrentDirectory path world 
	# (ok,world)	= 'System._Windows'.setCurrentDirectoryA (packString path) world
	| ok
		= (Ok (), world)
	| otherwise
		= getLastOSError world
