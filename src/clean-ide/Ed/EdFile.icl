implementation module EdFile

// reading and writing text files

import StdBool, StdFile, StdArray, StdInt, StdString, StdChar, StdFunc
import UtilNewlinesFile
import EdText, StrictList
import StdError
import UtilIO
import Platform

readText :: !String !*env -> ((Error Text,NewlineConvention,Bool), !*env) | FileSystem env
readText name env
  # (openOk,file,env)	= fopen name FReadData env
  | not openOk				
	= ((Error "error while opening file",NewlineConventionNone,False), env)
  # (readOnly,env)		= FReadOnly name env
  # (conv,lines,file)	= readConvLines file
    lines				= slFromList lines
	(readError, file)	= ferror file 
	(closeOk, env)		= fclose file env
  | readError
	= ((Error "error while reading file",conv,readOnly), env)	
  | not closeOk
	= ((Error "error while closing file",conv,readOnly), env)
  | otherwise
	= ((Ok (stringsToText lines),conv,readOnly), env)

writeText :: !String !NewlineConvention !Text !*env -> (Maybe String,!*env) | FileSystem env
writeText fileName nc text env
  # (ok, file, env) 		= PlatformDependant
  								(fopen fileName FWriteData env) // get proper line-endings on PC...sigh
								(fopen fileName FWriteText env)	// get correct creatorCode on Mac...
  | not ok
    = (Just "error opening file for writing",env)
  # file					= writeLines (textToStrings text) file
	(writeError, file)		= ferror file 
    (closeOk, env)			= fclose file env
  | writeError
	= (Just "error while writing file", env)	
  | not closeOk
    = (Just "error closing file",env)
  = (Nothing,env)
where
	writeLines :: (StrictList String) *File -> *File
	writeLines SNil file 
	  = file
	writeLines (SCons string SNil) file
	  = fwrites string file
	writeLines (SCons string strings) file 
	  # file = fwrites (string +++ ncString) file
	  = writeLines strings file
	
	ncString
		| nc == NewlineConventionNone	= "\n"
		= toString nc
