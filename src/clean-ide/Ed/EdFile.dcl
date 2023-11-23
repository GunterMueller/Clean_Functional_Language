definition module EdFile

// reading and writing text files

import	StdError, StdMaybe
from	StdFile				import class FileSystem
from	EdText				import :: Text
from	UtilNewlinesFile	import :: NewlineConvention

readText	:: !String !*env -> ((Error Text,NewlineConvention,Bool), !*env) | FileSystem env
writeText	:: !String !NewlineConvention !Text	!*env -> (Maybe String, !*env)	| FileSystem env

