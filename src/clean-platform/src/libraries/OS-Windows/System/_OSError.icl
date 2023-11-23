implementation module System._OSError

import StdEnv

import System.OSError
import System._Windows
import System._Pointer

_getLastOSErrorCode :: !*w -> (!OSErrorCode, !*w)
_getLastOSErrorCode world = getLastError world

_osErrorCodeToMessage :: !OSErrorCode -> OSErrorMessage
_osErrorCodeToMessage errorCode
	# msgBuf = createArray 1 0
	# ok = formatMessageA
        (FORMAT_MESSAGE_ALLOCATE_BUFFER bitor FORMAT_MESSAGE_FROM_SYSTEM bitor FORMAT_MESSAGE_IGNORE_INSERTS)
        NULL
        errorCode
        LANGUAGE_NEUTRAL_SUBLANG_DEFAULT
        msgBuf
        0
        NULL
     | ok <> ok = undef						//Force eval of ok
     # message = derefString msgBuf.[0]
     | size message <> size message = undef	//Force eval of message
     # hMem = localFree msgBuf.[0]
     | hMem <> hMem = undef					//Force eval of hMem
     = message % (0, size message - 3)		//Strip CR+LF
