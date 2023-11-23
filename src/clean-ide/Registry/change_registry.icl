module change_registry

import StdEnv
import registry

Start = addStart
//Start = remStart

// StdMaybe

::	Maybe x
	=	Just x
	|	Nothing

isNothing :: !(Maybe .x) -> Bool
isNothing Nothing	= True
isNothing _		= False

fromJust :: !(Maybe .x) -> .x
fromJust (Just x) = x

// state

:: DialogLS =
	{ icl :: !Bool
	, dcl :: !Bool
	, abc :: !Bool
	, prj :: !Bool
/* DYN_LINK
	, dyn :: !Bool
*/
	, pcl :: !Bool
	, chp :: !Bool
	}

quoted_null_string :: !String -> String
quoted_null_string string = "\"" +++ string +++ "\"\0"

quoted_string :: !String -> String
quoted_string string = "\"" +++ string +++ "\""

change_registry_fun path ls
	# e			= []
	# rs		= 0
	# (r,e,rs)	= if ls.icl
					(enter_file_type_in_registry ".icl\0" "iclfile\0" "Clean implementation module\0" "open\0" True clean_ide_path_plus_arg clean_ide_application (Just (clean_icons 4)) e rs)
					(0,e,rs)
	# (r,e,rs)	= if ls.dcl
					(enter_file_type_in_registry ".dcl\0" "dclfile\0" "Clean definition module\0" "open\0" True clean_ide_path_plus_arg clean_ide_application (Just (clean_icons 3)) e rs)
					(0,e,rs)
	# (r,e,rs)	= if ls.prj
					(enter_file_type_in_registry ".prj\0" "prjfile\0" "Clean project file\0" "open\0" True clean_ide_path_plus_arg clean_ide_application (Just (clean_icons 1)) e rs)
					(0,e,rs)
/* DYN_LINK
	# (r,e,rs)	= if ls.dyn
					(enter_file_type_in_registry ".prj\0" "prjfile\0" "Clean project file\0" "dynamic link\0" False dynamic_linker_path_plus_arg dynamic_linker_application Nothing e rs)
					(0,e,rs)
*/
	# (r,e,rs)	= if ls.abc
					(enter_file_type_in_registry ".abc\0" "abcfile\0" "Clean ABC file\0" "open\0" True clean_ide_path_plus_arg clean_ide_application (Just (clean_icons 2)) e rs)
					(0,e,rs)
	# (r,e,rs)	= if ls.pcl
					(enter_file_type_in_registry ".pcl\0" "pclfile\0" "Clean time profile\0" "open\0" True time_profile_path_plus_arg time_profile_application (Just (clean_icons 5)) e rs)
					(0,e,rs)
	# (r,e,rs)	= if ls.chp
					(enter_file_type_in_registry ".hcl\0" "hclfile\0" "Clean heap profile\0" "open\0" True heap_profile_path_plus_arg heap_profile_application (Just (clean_icons 6)) e rs)
					(0,e,rs)
	= (e,ls)
where
	clean_ide_application			= "CleanIDE\0"
	clean_ide_path_plus_arg			= "\""+++path+++"CleanIDE.exe\" \"%1\"\0"
	clean_icons i					= path+++"CleanIDE.exe,"+++toString i+++"\0"
//	clean_icons i					= path+++"back_change_registry.exe,"+++toString i+++"\0"
//	clean_icons i					= path+++"CleanIcons,"+++toString i+++"\0"
	time_profile_application		= "ShowTimeProfile\0"
	time_profile_path_plus_arg		= "\""+++path+++"ShowTimeProfile.exe\" \"%1\"\0"
	heap_profile_application		= "ShowHeapProfile\0"
	heap_profile_path_plus_arg		= "\""+++path+++"ShowHeapProfile.exe\" \"%1\"\0"
/* DYN_LINK
	dynamic_linker_application		= "DynamicLinker\0"
	dynamic_linker_path_plus_arg	= "\""+++path+++"DynamicLinker.exe\" /s \"%1\"\0"
*/

// add...

addStart
	# ls =
		{ icl = True
		, dcl = True
		, abc = True
		, prj = True
//		, dyn = True
		, pcl = True
		, chp = True
		}
	| GetFileAttributes (path+++"CleanIDE.exe\0")==(-1)
		= abort "CleanIDE.exe not found in this directory, registry not changed\n"
	# ls = case GetFileAttributes (path+++"ShowHeapProfile.exe\0") of
		(-1)	-> {ls & chp = False}		// = abort "ShowHeapProfile.exe not found in this directory, registry not changed\n"
		_		-> ls
	# ls = case GetFileAttributes (path+++"ShowTimeProfile.exe\0") of
		(-1)	-> {ls & pcl = False}		// = abort "ShowTimeProfile.exe not found in this directory, registry not changed\n"
		_		-> ls
/*
	# ls = case GetFileAttributes (path+++"DynamicLinker.exe\0") of
		(-1)	-> {ls & dyn = False}		// = abort "DynamicLinker.exe not found in this directory, registry not changed\n"
		_		-> ls
*/
 	# tb = 42
	# e = remStart
	# (ok,e,tb) = force e tb
	| ok
		= e
	# (e,_) = change_registry_fun path ls
	# (ok,e,tb) = force e tb
	| ok
		= e
 	| tb == 42
		= e
	= e
where
	path						= get_path

force :: !.a !.b -> (Bool,.a,.b)
force x y = (False,x,y)

// remove...

remStart
	# e=[]
	# rs=0
	# (r1,e,rs) = remove_file_type_from_registry ".icl\0" "iclfile\0" e rs
	# (r2,e,rs) = remove_file_type_from_registry ".dcl\0" "dclfile\0" e rs
	# (r3,e,rs) = remove_file_type_from_registry ".prj\0" "prjfile\0" e rs
	# (r4,e,rs) = remove_file_type_from_registry ".abc\0" "abcfile\0" e rs
	# (r5,e,rs) = remove_file_type_from_registry ".pcl\0" "pclfile\0" e rs
	# (r6,e,rs) = remove_file_type_from_registry ".hcl\0" "hclfile\0" e rs
	= e

//--

parse_command_line_path :: Int Char Int -> (!Int,!Int)
parse_command_line_path begin_path end_char command_line
	# end_path	= if (read_char (command_line+begin_path)<>'\0') (begin_path+1) begin_path
	# end_path	= find_end_char end_path
	# end_path	= find_backslash_or_colon end_path
	= (begin_path,end_path)
where
	find_end_char end_path
		# c		= read_char (command_line+end_path)
		| c<>'\0' && c<>end_char
			= find_end_char (end_path+1)
		= end_path
	find_backslash_or_colon end_path
		# c		= read_char (command_line+end_path-1)
		| end_path>begin_path && c<>'\\' && c<>':'
			= find_backslash_or_colon (end_path-1)
		= end_path

get_path :: String
get_path
	# command_line			= GetCommandLine
	# (begin_path,end_path) = if (read_char command_line=='\"')
								(parse_command_line_path 1 '\"' command_line)
								(parse_command_line_path 0 ' ' command_line)
	= {read_char (command_line+i) \\ i<-[begin_path..end_path-1]}

//--

add_to_registry :: Int [String] String Bool RegistryState -> (!Int,!RegistryState)
add_to_registry hkey1 [] value value_is_a_string rs
	# (r,rs) = if value_is_a_string
			(RegSetValueEx hkey1 "\0" 0 REG_SZ value (size value) rs)
			(RegSetValueEx hkey1 "EditFlags\0" 0 REG_BINARY value 4 rs)
	| r<>ERROR_SUCCESS
		= abort "RegSetValueEx failed\n" // 1
		= (0,rs)
add_to_registry hkey1 [path:path_list] value value_is_a_string rs
	#	(r,hkey2,dw,rs) = RegCreateKeyEx hkey1 path 0 "\0" REG_OPTION_NON_VOLATILE KEY_ALL_ACCESS 0 rs
	| r<>ERROR_SUCCESS
		#	(r,hkey2,dw,rs) = RegCreateKeyEx  hkey1 path 0 "\0" REG_OPTION_NON_VOLATILE (KEY_READ bitor KEY_SET_VALUE) 0 rs
		| r<>ERROR_SUCCESS
			= abort "RegCreateKeyEx failed\n" // 1
			# (r,rs) = add_to_registry hkey2 path_list value value_is_a_string rs
			# (_,rs) = RegCloseKey hkey2 rs
			= (r,rs)
		# (r,rs) = add_to_registry hkey2 path_list value value_is_a_string rs
		# (_,rs) = RegCloseKey hkey2 rs
		= (r,rs)

remove_from_registry :: Int [String] RegistryState -> (!Int,!RegistryState)
remove_from_registry hkey [path] rs
	# (r,rs) =RegDeleteKey hkey path rs
	| r==ERROR_SUCCESS
		= (0,rs)
		= (1,rs)
remove_from_registry hkey [path:path_list] rs
	# (r,hkey2,rs) = RegOpenKeyEx hkey path 0 (KEY_READ bitor KEY_SET_VALUE) rs
	| r<>ERROR_SUCCESS
			= (1,rs)
	# (r,rs)=remove_from_registry hkey2 path_list rs
	| r==r
		# (rc,rs) = RegCloseKey hkey2 rs
		| rc==rc
			= (r,rs)
			= (r,rs)

//--

key_to_string [] = ""
key_to_string [k:ks] = "\\" +++ k % (0,size k-2) +++ key_to_string ks

//--

enter_file_type_in_registry :: {#Char} {#Char} {#Char} {#Char} Bool {#Char} {#Char} (Maybe {#Char}) [String] !Int -> (!Int,![String],!Int)
enter_file_type_in_registry extension registry_name shell_name command usedde executable application_name icon_name e rs
	# p = ["SOFTWARE\0","Classes\0",extension]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p registry_name True rs
	# e = if (r<>0) (key_add_error p e) e
	
	# p = ["SOFTWARE\0","Classes\0",registry_name]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p shell_name True rs
	# e = if (r<>0) (key_add_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0"]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p "\0" True rs
	# e = if (r<>0) (key_add_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p "\x1\0\0\0" False rs
	# e = if (r<>0) (key_add_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"command\0"]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p executable True rs
	# e = if (r<>0) (key_add_error p e) e

	| not usedde
		= (r,e,rs)
	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0"]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p "%1\0" True rs
	# e = if (r<>0) (key_add_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0","topic\0"]
	# (r,rs) =add_to_registry HKEY_LOCAL_MACHINE p "CLEANOPEN\0" True rs
	# e = if (r<>0) (key_add_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0","Application\0"]
	# (r,rs) =add_to_registry HKEY_LOCAL_MACHINE p application_name True rs
	# e = if (r<>0) (key_add_error p e) e

	| isNothing icon_name
		= (r,e,rs)
	# p = ["SOFTWARE\0","Classes\0",registry_name,"DefaultIcon\0"]
	# (r,rs) = add_to_registry HKEY_LOCAL_MACHINE p (fromJust icon_name) True rs
	# e = if (r<>0) (key_add_error p e) e

	= (r,e,rs)
where
	key_add_error :: [String] [String] -> [String]
	key_add_error p e = e++["Adding '" +++ key_to_string p+++"' failed\n"]

//--

remove_file_type_from_registry :: !String !String ![String] !RegistryState -> (!Int,![String],!RegistryState)
remove_file_type_from_registry extension registry_name e rs
	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0","open\0","ddeexec\0","topic\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0","open\0","ddeexec\0","Application\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0","open\0","ddeexec\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0","open\0","command\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0","open\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name,"DefaultIcon\0"]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",registry_name]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	# p = ["SOFTWARE\0","Classes\0",extension]
	# (r,rs)=remove_from_registry HKEY_LOCAL_MACHINE p rs
	# e = if (r<>0) (key_rem_error p e) e

	= (r,e,rs)
where
	key_rem_error :: [String] [String] -> [String]
	key_rem_error p e = e++["Removing '" +++ key_to_string p+++"' failed\n"]

//--

