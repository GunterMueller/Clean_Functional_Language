implementation module UtilIO

import code from library "util_io_kernel_lib" // GetShortPathNameA@12

import StdArray, StdBool, StdClass, StdFile, StdList, StdTuple, StdString
import UtilDate
import StdPathname, Directory
from Platform import DirSeparator,get_module_file_name,expand_8_3_names_in_path,find_first_file_and_close
from StdMisc import abort

FReadOnly :: !{#Char} !*env -> (!Bool, !*env) | FileSystem env
FReadOnly path files
	# ((ok,dir),files)	= pd_StringToPath path files
	| not ok
		= (False,files)
	# ((err,fi),files)	= getFileInfo dir files
	| err <> NoDirError
		= (False,files)
	= (fi.pi_fileInfo.isReadOnly,files)

FFileSize :: !{#Char} !*env -> (!(!Bool,!Int), !*env) | FileSystem env
FFileSize path files
	# ((ok,dir),files)	= pd_StringToPath path files
	| not ok
		= ((False,0),files)
	# ((err,fi),files)	= getFileInfo dir files
	| err <> NoDirError
		= ((False,0),files)
	= ((True,fst fi.pi_fileInfo.fileSize),files)

//	Returns True if the file exists.

FExists	:: !String !Files -> (!Bool, !Files)
FExists name files
	#! (file_exists,_) = find_first_file_and_close (name+++"\0")
	= (file_exists,files)

ByteOffset_ftLastWriteTime :== 20;
Sizeof_FILETIME :== 8;
Sizeof_SYSTEMTIME :== 16;

//	Returns the last modification date of the indicated file.

FileTimeToSystemTime :: !{#Char} !*{#Char} !*state -> (!Int,!{#Char},!*state);
FileTimeToSystemTime fileTime systemTime state = code {
	push_a 0
	update_a 2 1
	ccall FileTimeToSystemTime@8 "Pss:I:AA"
}

FModified :: !String !Files -> (!DATE, !Files);
FModified name files
	# (ok,find_data) = find_first_file_and_close (name+++"\0")
	| ok
		# last_write_time = find_data % (ByteOffset_ftLastWriteTime,ByteOffset_ftLastWriteTime+Sizeof_FILETIME-1);
		# (r,system_time,files) = FileTimeToSystemTime last_write_time (createArray Sizeof_SYSTEMTIME '\0') files;
		| r<>0
			# year   = toInt system_time.[ 0]+(toInt system_time.[ 1]<<8);
			  month  = toInt system_time.[ 2]+(toInt system_time.[ 3]<<8);
			  day    = toInt system_time.[ 6]+(toInt system_time.[ 7]<<8);
			  hour   = toInt system_time.[ 8]+(toInt system_time.[ 9]<<8);
			  minute = toInt system_time.[10]+(toInt system_time.[11]<<8);
			  second = toInt system_time.[12]+(toInt system_time.[13]<<8);
			= ({exists=True, yy=year, mm=month, dd=day, h=hour, m=minute, s=second} ,files);
			= ({exists=True, yy=0, mm=0, dd=0, h=0, m=0, s=0}, files);
		= ({exists=False, yy=0, mm=0, dd=0, h=0, m=0, s=0}, files);

onOSX	:: Bool
onOSX
	= False

//	Returns directory in which the indicated application resides.

FStartUpDir :: !String !Files -> (!String, !Files);
FStartUpDir _ files = (expand_8_3_names_in_path name, files);
where 
  name  =  RemoveFileName get_module_path;

get_module_path :: {#Char}
get_module_path
	# (file_name_buffer,file_name_size,state) = get_module_file_name []
	= file_name_buffer % (0,file_name_size-1)

GetFullApplicationPath :: !*Files -> ({#Char}, *Files);
GetFullApplicationPath files
	= FStartUpDir "" files;

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
	| DirSeparator==s.[i]
	 	= (True, i);
		= LastColon s (dec i);

FindFirstFile :: !String -> (!Int,!String);
FindFirstFile file_name
	# find_data = createArray 320 '\0';
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

GetLongPathName :: !String -> String;
GetLongPathName short_path = expand_8_3_names_in_path short_path;
// of analoog aan GetShortPathName kernelfunctie aanroepen...

GetShortPathName :: !String -> (!Bool,!String);
GetShortPathName long_path
	#! long_path = if null_terminated long_path (long_path+++"\0")
	#! (result,short_path) = Helper long_path
	#! short_path = if null_terminated short_path (short_path%(0,size short_path - 2))
	= (result <> 0,short_path);
where
	lsize = size long_path
	null_terminated = long_path.[lsize-1] == '\0'
	
	Helper long_path
		#! s_short_path
			= GetShortPathName_ long_path "\0" 0;
		#! short_path
			= createArray s_short_path '\0';
		#! result
			= GetShortPathName_ long_path short_path s_short_path;
		= (result,short_path)

	GetShortPathName_ :: !String !String !Int -> Int;
	GetShortPathName_ long_path short_path s_short_path
		= code {
			ccall GetShortPathNameA@12 "PssI:I"
			}

GetCurrentDirectory :: (!Bool,!String)
GetCurrentDirectory
	// GetCurrentDirectory yields the size without the zero char, except when called with NULL and 0 !
	#! buffer_size_including_zero_char = GetCurrentDirectory_ 0 "\0"
	#! buffer = createArray buffer_size_including_zero_char '\0'
	#! n_chars_without_zero_char = GetCurrentDirectory_ buffer_size_including_zero_char buffer
	| n_chars_without_zero_char==0
		= (False,"")
	| size buffer>0 && buffer.[size buffer-1]=='\0'
		= (True,buffer % (0,size buffer-2))
		= (True,buffer)
where
	GetCurrentDirectory_ :: !Int !String -> Int
	GetCurrentDirectory_ buffer_size buffer
		= code {
			ccall GetCurrentDirectoryA@8 "PIs:I"
			}
