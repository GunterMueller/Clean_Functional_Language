definition module UtilIO

import StdString, StdFile
import UtilDate

//	Returns True if the file exists.
FExists	:: !String !Files -> (!Bool, !Files)

//	Returns the last modification date of the indicated file.
FModified :: !String !Files -> (!DATE, !Files)

//	Returns directory in which the indicated application resides.
FStartUpDir :: !String !Files -> (!String, !Files)
GetFullApplicationPath :: !*Files -> ({#Char}, *Files)

// Returns True if the file exists and is read-only
FReadOnly :: !{#Char} !*env -> (!Bool, !*env) | FileSystem env
FFileSize :: !{#Char} !*env -> (!(!Bool,!Int), !*env) | FileSystem env

GetLongPathName :: !String -> String;
GetShortPathName :: !String -> (!Bool,!String);

GetCurrentDirectory :: (!Bool,!String)
