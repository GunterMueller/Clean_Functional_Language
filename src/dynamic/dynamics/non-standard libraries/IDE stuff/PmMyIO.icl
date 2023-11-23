implementation module PmMyIO

/* OS dependent module */
/* Primitives which 'should be' in the standard CLEAN IO lib */

import StdEnv
//import expand_8_3_names_in_path
import UtilDate

//import StdIO
dirseparator	:==	'\\'				// OS separator between folder- and filenames in a pathname

//---
/*
import code from "cCrossCall_12.obj", "cdebug_12.obj", "cpicture_12.obj", "htmlhelp.obj", "util_12.obj"
import code from "cGameLib_12.obj", "cOSGameLib_12.obj", "ddutil.obj", "Dsutil.obj", "cprinter_12.obj"
//import code from "cTCP.obj"
import code from library "advapi32_library"
import code from library "comctl32_library"
import code from library "shell32_library"
import code from library "winmm_library"
import code from library "ole32_library"
import code from library "ddraw_library"
import code from library "dsound_library"
//import code from library "mykernel_library"
import code from library "kernel32_library"
import code from library "shell32_library"
import code from library "advapi32_library"
*/
::	OSToolbox
	:==	Int
/*
WinLaunchApp2 :: !{#Char} !{#Char} !Bool !*OSToolbox -> ( !Bool, !*OSToolbox)
WinLaunchApp2 _ _ _ _
	= code
	{
		.inline WinLaunchApp2
			ccall WinLaunchApp2 "SSII-II"
		.end
	}
*/
WinGetModulePath ::  {#Char}
WinGetModulePath
	= code
	{
		.inline WinGetModulePath
			ccall WinGetModulePath "-S"
		.end
	}

WinFileModifiedDate ::  !{#Char} -> ( !Bool, !Int, !Int, !Int, !Int, !Int, !Int)
WinFileModifiedDate _
	= code
	{
		.inline WinFileModifiedDate
			ccall WinFileModifiedDate "S-IIIIIII"
		.end
	}

WinFileExists ::  !{#Char} ->  Bool
WinFileExists _
	= code
	{
		.inline WinFileExists
			ccall WinFileExists "S-I"
		.end
	}

//--
/*
LaunchApplication :: !{#Char} !{#Char} !Bool !Files -> ( !Bool, !Files)
LaunchApplication execpath homepath console files
	# (ok,_) = WinLaunchApp2 execpath homepath console 42
	= (ok,files)
*/
/*	Returns True if the file name exists.
*/

FExists	:: !String !Files -> (!Bool, !Files)
FExists name files =  (WinFileExists name, files)


/*	Returns the last modification date of the indicated file.
*/
FModified :: !String !Files -> (!DATE, !Files);
FModified name files =  ( daterec, files);
where
  (exist, year, month, day, hour, minute, second) 
      =  WinFileModifiedDate name;
	daterec 
	  =  { exists=exist, yy=year, mm=month, dd=day,
                         h=hour, m=minute, s=second };


/*	Returns directory in which the indicated application resides.
*/

FStartUpDir :: !String !Files -> (!String, !Files);
FStartUpDir _ files = (expand_8_3_names_in_path name, files);
where 
  name  =  RemoveFileName WinGetModulePath;

GetFullApplicationPath :: !*Files -> ({#Char}, *Files);
GetFullApplicationPath files
	=	FStartUpDir "" files;


RemoveFileName :: !String -> String;
RemoveFileName path
	| found	= (path % (0, dec position));
			= path;
where 
	(found,position)	= LastColon path last;
	last				= dec (size path);
		
LastColon :: !String !Int -> (!Bool, !Int);
LastColon s i
	| i <= 0
		= (False,0);
	| dirseparator==s.[i]
	 	= (True, i);
		= LastColon s (dec i);

//-- expand_8_3_names_in_path

FindFirstFile :: !String -> (!Int,!String);
FindFirstFile file_name
	# find_data = createArray 318 '\0';
	# handle = FindFirstFile_ file_name find_data;
	= (handle,find_data);

FindFirstFile_ :: !String !String -> Int;
FindFirstFile_ file_name find_data
	= code {
		ccall FindFirstFileA@8 "Pss:I"
	}

FindClose :: !Int -> Int;
FindClose handle = code {
		ccall FindClose@4 "PI:I"
	}

find_null_char_in_string :: !Int !String -> Int;
find_null_char_in_string i s
	| i<size s && s.[i]<>'\0'
		= find_null_char_in_string (i+1) s;
		= i;

find_data_file_name find_data
	# i = find_null_char_in_string 44 find_data;
	= find_data % (44,i-1);

find_first_file_and_close :: !String -> (!Bool,!String);
find_first_file_and_close file_name
	# (handle,find_data) = FindFirstFile file_name;
	| handle <> (-1)
		# r = FindClose handle;
		| r==r
			= (True,find_data);
			= (False,find_data);
		= (False,"");

find_last_backslash_in_string i s
	| i<0
		= (False,-1);
	| s.[i]=='\\'
		= (True,i);
		= find_last_backslash_in_string (i-1) s;

expand_8_3_names_in_path :: !{#Char} -> {#Char};
expand_8_3_names_in_path path_and_file_name
	# (found_backslash,back_slash_index) = find_last_backslash_in_string (size path_and_file_name-1) path_and_file_name;
	| not found_backslash
		= path_and_file_name;
	# path = expand_8_3_names_in_path (path_and_file_name % (0,back_slash_index-1));
	# file_name = path_and_file_name % (back_slash_index+1,size path_and_file_name-1);
	# path_and_file_name = path+++"\\"+++file_name;
	# (ok,find_data) = find_first_file_and_close (path_and_file_name+++"\0");
	| ok
		= path+++"\\"+++find_data_file_name find_data;
		= path_and_file_name;

//--
/*
FAIL :== 0xFFFFFFFF
//FILE_ATTRIBUTE_READONLY :==
import StdFile
FReadOnly :: !{#Char} !Files -> (!Bool, !Files)
FReadOnly path files
	# (atts,files) = GetFileAttributes (path+++"\0") files
	| atts == FAIL = (False,files)
	= (True,files)
	
//WinFileReadOnly ::  !{#Char} ->  DoubleWord
GetFileAttributes path fs
	= code
	{
			ccall GetFileAttributesA@4 "PS-I"
		.end
	}
*/
//Start world
//	# (res,world) = accFiles (FReadOnly "C:\\testfile") world
//	= res

import StdPathname, Directory

FReadOnly :: !{#Char} !*env -> (!Bool, !*env) | FileSystem env
FReadOnly path files
	# dir = RemoveFilename path
	# fnm = RemovePath path
	# ((ok,dir),files) = pd_StringToPath dir files
	| not ok = (False,files)
	# ((err,dct),files) = getDirectoryContents dir files
	| err <> NoDirError = (False,files)
//	# dct = map (\{fileInfo}->fileInfo.pi_fileInfo) dct
	# dct = filter (\{fileName}->fileName==fnm) dct
	| isEmpty dct = (False,files)
	= ((hd dct).fileInfo.pi_fileInfo.isReadOnly,files)
	
	
