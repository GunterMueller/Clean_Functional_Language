definition module fileSystem

// import StdEnv, Directory
from StdFile import class FileSystem
from StdOverloaded import class ==
from Directory import :: Path, :: PathStep

instance == PathStep
instance == Path

separate :: (a -> Bool) [a] -> ([a],[a])
/* The result is the list, separated by the condition. 
	(left ones fulfill that, right ones don't)
*/

collectFiles :: Path [String] *f -> ([String],[String],*f) | FileSystem f
/*
  This function scans the directory structure for files with 
  certain extensions.
  It gets 1. root directory, 2. list of extensions we are looking for
  3. world
  gives back:
  1. list of files 2. log messages 3. world
*/

