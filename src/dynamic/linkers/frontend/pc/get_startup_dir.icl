implementation module get_startup_dir

import StdArray, StdClass, StdString, StdFile, StdInt, StdChar
import expand_8_3_names_in_path

MAX_PATH		:== 260
dirseparator	:==	'\\'				// OS separator between folder- and filenames in a pathname

FStartUpDir :: !Files -> (!String, !Files);
FStartUpDir files
	# (ok,path)	= GetModuleFileName;
	| not ok = ("",files)
	# name		=  RemoveFileName path 
	= (expand_8_3_names_in_path name, files);

GetModuleFileName :: (!Bool,!String)
GetModuleFileName
	#! buf = createArray (MAX_PATH+1) '\0'
	#! res = GetModuleFileName_ 0 buf MAX_PATH
	= (res <> 0,buf)
where
	GetModuleFileName_ :: !Int !String !Int -> Int
	GetModuleFileName_ handle buffer buf_length
		= code {
			ccall GetModuleFileNameA@12 "PIsI:I"
			}

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
