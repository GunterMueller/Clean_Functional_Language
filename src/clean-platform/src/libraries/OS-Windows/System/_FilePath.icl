implementation module System._FilePath

import _SystemArray

import Data.Error
import System.OSError
import System._Pointer
import System._Windows

getFullPathName :: !String !*World -> (!MaybeOSError String, !*World)
getFullPathName relp w
	# buf     = createArray MAX_PATH '\0'
	# (res,w) = getFullPathNameA (packString relp) MAX_PATH buf NULL w
	| res == 0
		= getLastOSError w
	| otherwise
		= (Ok (unpackString buf), w)
