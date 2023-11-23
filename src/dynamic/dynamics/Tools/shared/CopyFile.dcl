definition module CopyFile

from StdFile import class FileSystem
from Directory import :: Path, :: PathStep, :: DirError

LineListReadS :: String *World -> ([String],*World)
// reads the lines of a file given by its name

LineListWriteS :: String [String] *World -> *World
// writes lines to a file given by its name

CopyFile :: String String *env -> *env | FileSystem env
// copies a file to another name
// CopyFile source dest w -> w

FileSize :: String *World -> (Int, *World) 
// returns the size of a file

ClearDirectoryContents :: String *World -> *World
// clears the files in a directory ( does not clear the subdirectories )

createNestedDirectories :: Path *World -> (DirError, *World)
// creates nested directories ( from the current directory, goes through the
// path and creates all the directories mentioned

(\+\) infixl 6 :: Path Path -> Path
// concatenates the two paths

IsDirError :: DirError -> Bool
// returns true if argument is an error

ErrorType :: DirError -> String;
// returns the error as string

PathSteps :: Path -> [PathStep] 
// returns the steps of the path

ButLast :: Path -> Path
// the same path without the last step

CutLast :: Path -> (Path, Path)
// cut the last pathstep from the path

FileNameOf :: Path -> String
// returns the last step as string

WithoutExtension :: String -> String
// returns the beginning of the string if there's a . in it until the .
// otherwise ( no point after the last / or \ ) 

HasExtension :: String -> Bool
// returns true if there's a . after the last / or \ in the string

Extension :: String -> String
// returns the extension of the filename

FileNameFrom :: String -> String
// returns the filename from a full pathname

PathFrom :: String -> String
// returns the path from a path\filename


