implementation module System._CopyFile

import StdEnv
import System._Pointer
import System.File
import System.OSError
import System._Posix
import System._Linux

_copyFile :: !String !String !*World -> (!MaybeOSError (), !*World)
_copyFile src dest w
	# (mfi, w) = getFileInfo src w
	| isError mfi = (liftError mfi, w)
	# (in_fd, w) = opens (packString src) O_RDONLY w
	| in_fd == -1 = getLastOSError w
	# (out_fd, w) = opens (packString dest) (O_WRONLY bitor O_CREAT) w
	| out_fd == -1 = exitWithCurrentError (snd o close in_fd) w
	# (ok, w) = sendfile out_fd in_fd 0 (fromOk mfi).sizeLow w
	| ok == -1 = exitWithCurrentError (snd o close out_fd o snd o close in_fd) w
	# (ok, w) = close in_fd w
	| ok == -1 = exitWithCurrentError (snd o close out_fd) w
	# (ok, w) = close out_fd w
	| ok == -1 = getLastOSError w
	= (Ok (), w)
where
	// Exit with the current error but do some things first that may change the OSError
	exitWithCurrentError :: !.(*World -> *World) !*World -> (!MaybeOSError (), !*World)
	exitWithCurrentError cont w = case getLastOSError w of
		(Error e, w) = (Error e, cont w)
		(Ok (), w) = abort "Shouldn't occur"
