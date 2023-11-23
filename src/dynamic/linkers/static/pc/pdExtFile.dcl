definition module pdExtFile;

from StdOverloaded import class toChar (toChar);
from StdInt import >>;
from StdFile import :: Files, class FileSystem, class FileEnv,
	fwritec;

path_separator :== '\\';

FileSize :: !String -> (!Bool,!Int);

(FWW) infixl;
(FWW) f w :== fwritec (toChar (w>>8)) (fwritec (toChar w) f);

(FWB) infixl;
(FWB) f b :== fwritec (toChar b) f;

// external utilities
//FetchFileTime :: !String -> (!Bool,!Int,!Int);
//CompareFileTimes :: !Int !Int !Int !Int -> Int;
GetShortPathName :: !String -> (!Bool,!String);

//file_exists :: !String !*f -> (!Bool,!*f) | FileEnv f;
//FileExists :: !String !*env -> (!Bool,!*env) | FileSystem env;

GetFullPathName :: !String -> (!Bool,!String);
