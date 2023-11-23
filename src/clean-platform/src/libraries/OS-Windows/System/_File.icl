implementation module System._File

import StdEnv

import Data.Error
from System.File import :: FileInfo{..}
import System.OSError
import System._Pointer
import System._Windows

_fileExists :: !String !*World -> (!Bool, !*World)
_fileExists filename world
# win32FindData = createArray WIN32_FIND_DATA_size_bytes '\0'
# (handle, world) = findFirstFileA (packString filename) win32FindData world
| handle == INVALID_HANDLE_VALUE = (False, world)
# (_,world) = findClose handle world
= (True, world)

_deleteFile :: !String !*World -> (!Bool, !*World)
_deleteFile filename world
	# (ret,world) = deleteFileA (packString filename) world
	= (ret <> 0, world)

_getFileInfo :: !String !*World -> (!MaybeOSError FileInfo, !*World)
_getFileInfo filename world
	# win32FindData = createArray WIN32_FIND_DATA_size_bytes '\0'
	# (handle, world) = findFirstFileA (packString filename) win32FindData world
	| handle == INVALID_HANDLE_VALUE = getLastOSError world
	# creationTime     = fileTimeToTimeSpec (toFileTimeArray win32FindData WIN32_FIND_DATA_ftCreationTime_bytes_offset)
	# lastModifiedTime = fileTimeToTimeSpec (toFileTimeArray win32FindData WIN32_FIND_DATA_ftLastWriteTime_bytes_offset)
	# lastAccessedTime = fileTimeToTimeSpec (toFileTimeArray win32FindData WIN32_FIND_DATA_ftLastAccessTime_bytes_offset)
	# info = creationTime
	# info =	{ directory			= toDWORD win32FindData bitand FILE_ATTRIBUTE_DIRECTORY > 0
				, creationTime		= creationTime
				, lastModifiedTime	= lastModifiedTime
				, lastAccessedTime	= lastAccessedTime
				, sizeHigh			= 0
				, sizeLow			= size (win32FindData % (WIN32_FIND_DATA_ftCreationTime_bytes_offset, WIN32_FIND_DATA_ftCreationTime_bytes_offset + FILETIME_size_bytes))
				}
	= (Ok info, world)
where
	toFileTimeArray :: !{#Char} !Int -> {#Int}
	toFileTimeArray a o = IF_INT_64_OR_32 {unpackInt8 a o} {unpackInt4S a o,unpackInt4S a (o+4)}

	toDWORD :: !{#Char} -> DWORD
	toDWORD s = toInt s.[3] << 24 bitor toInt s.[2] << 16 bitor toInt s.[1] << 8 bitor toInt s.[0] //little-endian

_moveFile :: !String !String !*World -> (!MaybeOSError (), !*World)
_moveFile oldpath newpath world
	# (ok, world) = moveFileA (packString oldpath) (packString newpath) world
	| not ok = getLastOSError world
	= (Ok (), world)
