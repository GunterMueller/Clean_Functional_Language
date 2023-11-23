definition module UtilIO

/* OS dependent module */

/* Primitives which 'should be' in the standard CLEAN IO lib */

import StdString, StdFile
import UtilDate

LaunchApplication :: !{#Char} !{#Char} !Bool !Files -> ( !Bool, !Files)

//	Returns True if the file name exists.
FExists	:: !String !Files -> (!Bool, !Files)

//	Returns the last modification date of the indicated file.
FModified :: !String !Files -> (!DATE, !Files)

//	Returns directory in which the indicated application resides.
//FStartUpDir :: !String !Files -> (!String, !Files)
GetFullApplicationPath :: !*Files -> ({#Char}, *Files)

// Returns True if the file exists and is read-only
FReadOnly :: !{#Char} !*env -> (!Bool, !*env) | FileSystem env

GetLongPathName :: !String -> String;
GetShortPathName :: !String -> (!Bool,!String);

LaunchTheDocument :: !String !String !Int !*a -> (!Int,!*a)
