implementation module System._CopyFile

import StdEnv
import System._Pointer
import System.OSError
import System._Windows

_copyFile :: !String !String !*World -> (!MaybeOSError (), !*World)
_copyFile src dest world
	# (ok, world) = copyFileA (packString src) (packString dest) True world
	| not ok = getLastOSError world
	= (Ok (), world)
