implementation module Platform

import code from library "platform_kernel_library"

import StdArray, StdEnum, StdList, StdClass, StdBool, StdMisc
import ArgEnv
import logfile, set_return_code

PlatformDependant win mac :== win

cl_args =: getCommandLine

filter_opts [] = []
filter_opts [h:t]
	| h.[0] == '-'	= filter_opts (drop 1 t)
	= [h:filter_opts t]

get_arg n
	= get_arg n [a \\ a <-: cl_args]
where
	get_arg n [] = (False,"")
	get_arg n [h:t]
		| h == n = case t of [] -> (True,""); [h:_] -> (True,h)
		= get_arg n t

get_env n
	# e = getEnvironmentVariable n
	= case e of
		EnvironmentVariableUndefined	-> (False,"")
		EnvironmentVariable v			-> (True,v)

get_ini file section key default`
	# (size,buffer,tb) = GetPrivateProfileString section key default` (createArray 256 '\0') 256 file []
	= buffer % (0,size-1)

GetPrivateProfileString :: !String !String !String !*{#Char} !Int !String !*state -> (!Int,!{#Char},!*state)
GetPrivateProfileString appName keyName default returnedString returnedStringSize fileName state = code {
	push_a 0
	update_a 2 1
	update_a 3 2
	update_a 4 3
	update_a 5 4
	update_a 3 5
	ccall GetPrivateProfileStringA@24 "PssssIs:I:AA"
}

batchOptions :: !*World -> (!Bool,Bool,String,*File,!*World)
batchOptions world
	=	case [arg \\ arg <-: getCommandLine] of
			[_, "--batch-build", prj]
				-> batch False prj world
			[_, "--batch-force-build", prj]
				-> batch True prj world
			_
				->	(True, abort "force_update", abort "project file", abort "logfile", world)
where
	batch force_update prj world
		# (ok,logfile,world)	= openLogfile prj world
		| not ok
			=   (False, force_update, prj, logfile, wAbort ("--batch-build failed while opening logfile.\n") world)
			=	(False, force_update, prj, logfile, world)

wAbort :: !String !*World -> *World
wAbort message world
	# stderr	= fwrites message stderr
	# (_,world)	= fclose stderr world
	# world		= set_return_code_world (-1) world
	= world

//====

get_module_file_name :: !*state -> (!{#Char},!Int,!*state)
get_module_file_name state
	= get_module_file_name 261 state
where
	get_module_file_name :: !Int !*state -> (!{#Char},!Int,!*state)
	get_module_file_name file_name_size state
		# (file_name_size_result,file_name,state)
			= GetModuleFileName 0 (createArray file_name_size '\0') state
		| file_name_size_result<file_name_size
			= (file_name,file_name_size_result,state)
		# (last_error,state) = GetLastError state
		| last_error==0/*ERROR_SUCCESS*/
			= (file_name,file_name_size_result,state)
		| last_error==122/*ERROR_INSUFFICIENT_BUFFER*/
			= get_module_file_name (file_name_size+file_name_size) state
			= abort "get_module_file_name failed"

GetModuleFileName :: !Int !*{#Char} !*state -> (!Int,!{#Char},!*state)
GetModuleFileName hModule file_name_buffer state = code {
	push_a 0
	push_a 0
	push_arraysize CHAR 0 1
	push_b 1
	update_b 1 2
	updatepop_b 0 1
	ccall GetModuleFileNameA@12 "PpsI:I:AA"
}

GetLastError :: !*state -> (!Int,*state)
GetLastError state = code {
	ccall GetLastError@0 "P:I:A"
}

inifilename
	# (file_name_buffer,file_name_size,state) = get_module_file_name []
	=: file_name_buffer % (0,file_name_size-4)+++"ini\0"

section =: "Paths\0"
tooltempkey =: "tooltemp\0"
envskey =: "envsdir\0"
prefskey =: "prefsdir\0"

tooltempdefault	=: StartUpDir +++. "\\Temp\0"
envsdefault		=: StartUpDir +++. "\\Config\0"
prefsdefault	=: StartUpDir +++. "\\Config\0"

TempDir :: String
TempDir =:
	let
		(has_arg,arg) = get_arg "-tempdir"
		(has_env,env) = get_env "TEMPDIR"
		ini = get_ini inifilename section tooltempkey tooltempdefault
	in if has_arg arg (if has_env env ini)

EnvsDir :: String
EnvsDir =:
	let
		(has_arg,arg) = get_arg "-envsdir"
		(has_env,env) = get_env "ENVSDIR"
		ini = get_ini inifilename section envskey envsdefault
	in if has_arg arg (if has_env env ini)

PrefsDir :: String
PrefsDir =:
	let
		(has_arg,arg) = get_arg "-prefsdir"
		(has_env,env) = get_env "PREFSDIR"
		ini = get_ini inifilename section prefskey prefsdefault
	in if has_arg arg (if has_env env ini)

StartUpDir :: String
StartUpDir =: expand_8_3_names_in_path (RemoveFileName WinGetModulePath)

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

find_first_file_and_close :: !{#Char} -> (!Bool,!{#Char});
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

WinGetModulePath ::  {#Char}
WinGetModulePath
	# (file_name_buffer,file_name_size,state) = get_module_file_name []
	= file_name_buffer % (0,file_name_size-1)

onOSX	:: Bool
onOSX
	= False

application_path :: !String -> String // same as applicationpath in StdSystem
application_path fname
	# (module_directory_path,_) = get_module_directory_path []
	= module_directory_path+++fname

skip_file_name_at_end :: !Int !{#Char} -> Int
skip_file_name_at_end i s
	| i>=0
		# c=s.[i]
		| c=='\\' || c=='/' || c==':'
			= i
			= skip_file_name_at_end (i-1) s
		= i

get_module_directory_path :: !*state -> (!{#Char},!*state)
get_module_directory_path state
	# (file_name_buffer,file_name_size,state) = get_module_file_name state
	# separator_index = skip_file_name_at_end (file_name_size-1) file_name_buffer
	// remove "\\\\?\\" ?
	= (file_name_buffer % (0,separator_index),state)
