implementation module first_run

import StdEnv, StdMaybe
//import StdDebug
import registry, version
import UtilIO, PmPath

//==

import code from library "errorkernel_library"

GetLastError :: Int
GetLastError = code {
	ccall GetLastError@4 "P:I"
	}

//==

GetApplicationNameAndPath :: (String,String)
GetApplicationNameAndPath = (app_name,app_path)
where
	path		= winGetModulePath
	long_path	= GetLongPathName path
	app_name	= GetFileName long_path
	app_path	= GetFilePath path

GetFileName :: !String -> String;
GetFileName path
	| found	= (path % (inc position, dec (size path)));
			= path;
where 
	(found,position)	= LastColon path last;
	last				= dec (size path);
		
GetFilePath :: !String -> String;
GetFilePath path
	| found	= (path % (0, position));
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

StripExtension :: !String -> String
StripExtension path
	| found	= (path % (0, dec position));
			= path;
where 
	(found,position)	= LastPeriod path last;
	last				= dec (size path);

LastPeriod :: !String !Int -> (!Bool, !Int);
LastPeriod s i
	| i <= 0
		= (False,0);
	| '.'==s.[i]
	 	= (True, i);
		= LastPeriod s (dec i);

finish :: !(PSt Void) -> PSt Void
finish ps
	# (_,ps) = openDialog Void (Dialog "Bye" NilLS [WindowClose (noLS closeProcess)]) ps
	#! ps = ps
	= ps

//==

ReadVersionInfo :: String
ReadVersionInfo
	# t			= 7
	# dummy		= "abcd"
	# (r,t)		= GetFileVersionInfoSize path dummy t
	| r == 0
		= ""
//		= abort "GetFileVersionInfoSize failed...\n"
	# data		= createArray r '@'
	# (r,t)		= GetFileVersionInfo path 0 r data t
	| r == 0
		= ""
//		= abort ("GetFileVersionInfo failed...\n"+++toString GetLastError+++"\n")
	# buff		= "@@@@"
	# blen		= "@@@@"
	# (r,t)		= VerQueryValue data vers buff blen t
	| r == 0
		= ""
//		= abort "VerQueryValue failed...\n"
	| blen == zero
		= ""
//		= abort "No FileVersion info...\n"
	# sptr		= s2i buff
	# slen		= s2i blen
//	# info		= toString sptr +++ " :: " +++ toString slen
	# info		= {read_char p \\ p <- [sptr..] & x <- [1..slen-1]}
	= info
where
	path = winGetModulePath+++."\0"
	vers = "\\StringFileInfo\\040904B0\\FileVersion\0"
	zero = "\0\0\0\0"
	s2i s = (toInt s.[3] << 24) bitor (toInt s.[2] << 16) bitor (toInt s.[1] << 8) bitor (toInt s.[0])

//==

:: CheckResult
	= MyEntry
	| NoEntry
	| DiffEntry
	| ErrEntry !String

:: DialogResult
	= Yes
	| No
	| Never

first_run :: !String !String !String !String ![(String,String)] !(PSt .ls) -> (!Bool,(String,String),!PSt .ls)
first_run pcl_name pcl_path hcl_name hcl_path flags ps
	# (ide_name,ide_path) = GetApplicationNameAndPath
	# (app_path,ps)			= accFiles GetFullApplicationPath ps
	# app_path				= GetLongPathName app_path
	# pcl_path				= fulAppPath app_path pcl_path
	# pcl_path				= case GetShortPathName pcl_path of
								(True,pcl_path)	-> pcl_path
								_				-> pcl_path
	# hcl_path				= fulAppPath app_path hcl_path
	# hcl_path				= case GetShortPathName hcl_path of
								(True,hcl_path)	-> hcl_path
								_				-> hcl_path
	# (run,ps)				= check_flags ide_path ide_name flags ps
	| not run
		= (False,(ide_name,ide_path),ps)
	# (res,ps)				= check_registry ide_name ide_path ps
	= case res of
		MyEntry				-> (False,(ide_name,ide_path),ps)
		NoEntry
			# (res,ps)		= init_dialog ps
			-> case res of
				Yes			# (err,ps)	= set_registry ide_name ide_path pcl_name pcl_path hcl_name hcl_path ps
							| err <> ""
								# ps	= err_dialog False err ps
								-> (False,(ide_name,ide_path),ps)
							-> (False,(ide_name,ide_path),ps)
				No			-> (False,(ide_name,ide_path),ps)
				Never		-> (True,(ide_name,ide_path),ps)
		DiffEntry
			# (res,ps)		= delta_dialog ps
			-> case res of
				Yes			# (err,ps)	= set_registry ide_name ide_path pcl_name pcl_path hcl_name hcl_path ps
							| err <> ""
								# ps	= err_dialog False err ps
								-> (False,(ide_name,ide_path),ps)
							-> (False,(ide_name,ide_path),ps)
				No			-> (False,(ide_name,ide_path),ps)
				Never		-> (True,(ide_name,ide_path),ps)
		ErrEntry err
			# ps			= err_dialog True err ps
			-> (False,(ide_name,ide_path),ps)


uninstall :: !(PSt .ls)	-> (![String],!PSt .ls)
uninstall ps
	# (e,rs) = ([],0)
	# (e,rs) = remove_file_type_from_registry ".icl\0" "iclfile\0" "open\0" e rs
	# (e,rs) = remove_file_type_from_registry ".dcl\0" "dclfile\0" "open\0" e rs
	# (e,rs) = remove_file_type_from_registry ".prj\0" "prjfile\0" "open\0" e rs
	# (e,rs) = remove_file_type_from_registry ".abc\0" "abcfile\0" "open\0" e rs
	# (e,rs) = remove_file_type_from_registry ".pcl\0" "pclfile\0" "open\0" e rs
	# (e,rs) = remove_file_type_from_registry ".hcl\0" "hclfile\0" "open\0" e rs
	# (e,rs) = remove_ide_from_registry e rs
	= (e,ps)

	
//==

read_version_flag ps
	# (ok,file,ps)		= fopen "VERSION.txt" FReadText ps
	| not ok = abort "no VERSION"
	# (flag_vers,file)	= freadline file
	# (flag_name,file)	= freadline file
	# (flag_path,file)	= freadline file
	# flag_vers			= dropnl flag_vers
	# flag_name			= dropnl flag_name
	# flag_path			= dropnl flag_path
	# (_,ps)			= fclose file ps
	= ((flag_name,flag_path,flag_vers),ps)
where
	dropnl s = {c \\ c <-: s | c <> '\xA' && c <> '\xD'}

write_version_flag (flag_name,flag_path,flag_vers) ps
	# (ok,file,ps)	= fopen "VERSION.txt" FWriteText ps
	| not ok = abort "set failed"
	# file			= writeln flag_vers file
	# file			= writeln flag_name file
	# file			= writeln flag_path file
	# (_,ps)		= fclose file ps
	= ps
where
	writeln s f = f <<< s <<< '\n'

check_flags :: !String !String ![(String,String)] !(PSt .l) -> (!Bool,!PSt .l)
check_flags _ _ [] ps = (True,ps)
check_flags app_path app_name [(flag_name,flag_path):flags] ps
	| app_path == flag_path && app_name == flag_name
		= (False,ps)
	= check_flags app_path app_name flags ps

check_registry :: !String !String !(PSt .l) -> (!CheckResult,!PSt .l)
check_registry app_name app_path ps
	# (name,path,errs)	= get_ide_from_registry
	| notEmpty errs
		= (NoEntry,ps)
	| name <> app_name || path <> app_path
		= (DiffEntry,ps)
	= (MyEntry,ps)

set_registry :: !String !String !String !String !String !String !(PSt .l) -> (!String,!PSt .l)
set_registry ide_name ide_path pcl_name pcl_path hcl_name hcl_path ps
	# (err,r)	= enter_ide_in_registry (ide_name+++"\0") (ide_path+++"\0") [] 7
	| notEmpty err || r <> 7
		= (hd err,ps)
	# err		= change_ide_registry_fun ide_name ide_path
	| notEmpty err
		= (hd err,ps)
	# err		= change_pcl_registry_fun ide_name ide_path pcl_name pcl_path
	| notEmpty err
		= (hd err,ps)
	# err		= change_hcl_registry_fun ide_name ide_path hcl_name hcl_path
	| notEmpty err
		= (hd err,ps)
	= ("",ps)

import StdIO

init_dialog :: !(PSt .l) -> (!DialogResult,!PSt .l)
init_dialog ps
	# (okId,ps)			= openId ps
	# (cancelId,ps)		= openId ps
	# (dialogId,ps)		= openId ps
	# ((err,res),ps)	= openModalDialog No (idef okId cancelId dialogId) ps
	| err <> NoError || isNothing res
		= (No,ps)
	= (fromJust res,ps)

delta_dialog :: !(PSt .l) -> (!DialogResult,!PSt .l)
delta_dialog ps
	# (okId,ps)			= openId ps
	# (cancelId,ps)		= openId ps
	# (dialogId,ps)		= openId ps
	# ((err,res),ps)	= openModalDialog No (ddef okId cancelId dialogId) ps
	| err <> NoError || isNothing res
		= (No,ps)
	= (fromJust res,ps)
idef okId cancelId dialogId = Dialog "Ide Integration"
	(	TextControl "The Clean Ide is currently not integrated" [ControlPos (Left,zero)]
	:+:	TextControl "into the Windows operating system." [ControlPos (Left,zero)]
	:+:	TextControl "Do this now?" [ControlPos (Left,zero)]
	:+:	ButtonControl "Never"
		[ ControlPos (Right,zero)
		, ControlFunction (dfun Never dialogId)
		]
	:+:	ButtonControl "No"	
		[ ControlPos (LeftOfPrev,zero)
		, ControlFunction (dfun No dialogId)
		, ControlId cancelId
		]
	:+: ButtonControl "Yes"	
		[ ControlPos (LeftOfPrev,zero)
		, ControlFunction (dfun Yes dialogId)
		, ControlId okId
		]
	)
	[ WindowId		dialogId
	, WindowOk		okId
	, WindowCancel	cancelId
	]
ddef okId cancelId dialogId = Dialog "Ide Integration"
	(	TextControl "A different Clean Ide is currently integrated" [ControlPos (Left,zero)]
	:+:	TextControl "into the Windows operating system." [ControlPos (Left,zero)]
	:+:	TextControl "Use this copy instead?" [ControlPos (Left,zero)]
	:+:	ButtonControl "Never"
		[ ControlPos (Right,zero)
		, ControlFunction (dfun Never dialogId)
		]
	:+:	ButtonControl "No"	
		[ ControlPos (LeftOfPrev,zero)
		, ControlFunction (dfun No dialogId)
		, ControlId cancelId
		]
	:+: ButtonControl "Yes"	
		[ ControlPos (LeftOfPrev,zero)
		, ControlFunction (dfun Yes dialogId)
		, ControlId okId
		]
	)
	[ WindowId		dialogId
	, WindowOk		okId
	, WindowCancel	cancelId
	]
dfun ret dId (_,ps)
	= (ret,closeWindow dId ps)

err_dialog wasChecking err ps
	# (okId,ps)		= openId ps
	# (dlogId,ps)	= openId ps
	# (_,ps)		= openModalDialog Void
						(	Dialog (if wasChecking "Check Registry Failed!" "Setting Registry Failed!")
							( edef okId dlogId) 
							[ WindowOk okId
							, WindowId dlogId
							]
						) ps
	= ps
where
	edef okId dlogId
		=	TextControl (if wasChecking "Checking the windows registry failed:" "Setting the windows registry failed:")
			[ ControlPos (Left,zero)
			]
		:+:	TextControl err [ControlPos (Left,zero)]
		:+: ButtonControl "OK" [ControlPos (Right,zero),ControlId okId,ControlFunction (noLS (closeWindow dlogId))]

//==

Start`
	# (err,rs)			= ([],7)
	# (err,found,rs)	= check_file_type_in_registry registry_name command err rs
	| notEmpty err
		= hd err +++. "\n"
	# mine				= quoted winGetModulePath
	| found <> mine
		= "Different: " +++. found +++. " <=> " +++. mine +++. "\n"
	= "Same...\n"
	
where
	registry_name	= "iclfile\0"
	command			= "open\0"

	quoted string	= "\"" +++ string +++ "\" \"%1\""

//---

notEmpty [] = False
notEmpty _ = True

//---

import code from "cCrossCall_121.obj", "cCrossCallProcedureTable_121.obj", "cAcceleratorTable_121.obj", "cCrossCallCursor_121.obj",
				 "util_121.obj"
import code from library "userExt_library"

// from clCCall_12.dcl...

winGetModulePath ::  {#Char}
winGetModulePath
	= code
	{
		.inline WinGetModulePath
			ccall WinGetModulePath "-S"
		.end
	}

//---

:: RegistryKey	:== [String]

key_to_string [] = ""
key_to_string [k:ks] = "\\" +++ k % (0,size k-2) +++ key_to_string ks

//---

check_file_type_in_registry :: !String !String ![String] !RegistryState -> (![String],!String,!RegistryState)
check_file_type_in_registry registry_name command e rs
	# (e`,r,rs)	= check_registry_key key rs
	# e			= e++e`
	= (e,r,rs)
where
	key			= ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"command\0"]
	
check_registry_key :: !RegistryKey !RegistryState -> (![String],!String,!RegistryState)
check_registry_key key rs
	= check HKEY_CURRENT_USER key True rs
where
	check :: !Int !RegistryKey !Bool !RegistryState -> (![String],!String,!RegistryState)
	check hkey [] is_a_string rs
		# data = createArray 256 '@'
		# size = {c \\ c <-: "\0\1\0\0"}
		# (r,rs) = if is_a_string
			(RegQueryValueEx hkey "\0" 0 0 data size rs)
			(RegQueryValueEx hkey "EditFlags\0" 0 0 data size rs)
		| r<>ERROR_SUCCESS
			= (["RegQueryValueEx failed\n"], "", rs)
		# size = convert2 size
		# value = data%(0,size-2)
		= ([],value,rs)
	check hkey [path:path_list] is_a_string rs
		#	(r,hkey2,rs) = RegOpenKeyEx hkey path 0 KEY_ALL_ACCESS rs
		| r<>ERROR_SUCCESS
			#	(r,hkey2,rs) = RegOpenKeyEx  hkey path 0 (KEY_READ bitor KEY_SET_VALUE) rs
			| r<>ERROR_SUCCESS
				= (["RegOpenKeyEx failed\n"], "", rs)
			# (e,r,rs) = check hkey2 path_list is_a_string rs
			# (_,rs) = RegCloseKey hkey2 rs
			= (e,r,rs)
		# (e,r,rs) = check hkey2 path_list is_a_string rs
		# (_,rs) = RegCloseKey hkey2 rs
		= (e,r,rs)

convert :: {#Char} -> String
convert s
	# l = [toString (toInt c) \\ c <-: s]
	= foldr (\l r -> l+++.";"+++.r) "" l

convert2 s
	# l = [toInt c \\ c <-: s]
	= foldr (\l r -> l + (r << 8)) 0 l

//==

:: DialogLS =
	{ icl :: !Bool
	, dcl :: !Bool
	, abc :: !Bool
	, prj :: !Bool
	, pcl :: !Bool
	, hcl :: !Bool
	}

change_hcl_registry_fun :: !String !String !String !String -> [String]
change_hcl_registry_fun ide_name ide_path hcl_name hcl_path
	# (e,rs)	= ([],0)
	# (e,rs)	= enter_file_type_in_registry hclMapping e rs
	= e
where
	hclMapping =
		{ fm_extension		= ".hcl\0"
		, fm_registry_name	= "hclfile\0"
		, fm_shell_name		= "Clean heap profile\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\""+++hcl_path+++hcl_name+++"\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (ide_path+++ide_name+++",6\0"))
		}
	application	= StripExtension hcl_name +++. "\0"

change_pcl_registry_fun :: !String !String !String !String -> [String]
change_pcl_registry_fun ide_name ide_path pcl_name pcl_path
	# (e,rs)	= ([],0)
	# (e,rs)	= enter_file_type_in_registry pclMapping e rs
	= e
where
	pclMapping =
		{ fm_extension		= ".pcl\0"
		, fm_registry_name	= "pclfile\0"
		, fm_shell_name		= "Clean time profile\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\"" +++ pcl_path +++ pcl_name +++ "\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (ide_path+++ide_name+++",5\0"))
		}
	application	= StripExtension pcl_name +++. "\0"

change_ide_registry_fun name path
	# (e,rs)	= ([],0)
	# (e,rs)	= enter_file_type_in_registry iclMapping e rs
	# (e,rs)	= enter_file_type_in_registry dclMapping e rs
	# (e,rs)	= enter_file_type_in_registry prjMapping e rs
	# (e,rs)	= enter_file_type_in_registry abcMapping e rs
	= e
where
	abcMapping =
		{ fm_extension		= ".abc\0"
		, fm_registry_name	= "abcfile\0"
		, fm_shell_name		= "Clean ABC file\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\"" +++ path +++ name +++ "\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (path+++name+++",2\0"))
		}
	prjMapping =
		{ fm_extension		= ".prj\0"
		, fm_registry_name	= "prjfile\0"
		, fm_shell_name		= "Clean project file\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\"" +++ path +++ name +++ "\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (path+++name+++",1\0"))
		}
	iclMapping =
		{ fm_extension		= ".icl\0"
		, fm_registry_name	= "iclfile\0"
		, fm_shell_name		= "Clean implementation module\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\"" +++ path +++ name +++"\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (path+++name+++",4\0"))
		}
	dclMapping =
		{ fm_extension		= ".dcl\0"
		, fm_registry_name	= "dclfile\0"
		, fm_shell_name		= "Clean definition module\0"
		, fm_command		= "open\0"
		, fm_use_dde		= True
		, fm_executable		= "\"" +++ path +++ name +++ "\" \"%1\"\0"
		, fm_application	= application
		, fm_icon			= (Just (path+++name+++",3\0"))
		}
	application	= StripExtension name +++. "\0"

//==

:: FileMapping =
	{ fm_extension		:: !String			// the extension being mapped							[NULL-terminated]
	, fm_registry_name	:: !String			// the filetype name used internally in the registry	[NULL-terminated]
	, fm_shell_name		:: !String			// the filetype description visible to Windows users	[NULL-terminated]
	, fm_command		:: !String			// the command being mapped								[NULL-terminated]
	, fm_use_dde		:: !Bool			// ...
	, fm_executable		:: !String			// quoted path to executable plus arguments				[NULL-terminated]
	, fm_application	:: !String			// application name										[NULL-terminated]
	, fm_icon			:: !Maybe String	// resource identifier string							[NULL-terminated]
	}

enter_ide_in_registry name path e rs
	# (e,rs) = add_to_registry ["Software\0","Clean\0"]							"\0" True e rs
	# (e,rs) = add_to_registry ["Software\0","Clean\0","CleanIDE\0"]			"\0" True e rs
	# (e,rs) = add_to_registry ["Software\0","Clean\0","CleanIDE\0","Name\0"]	name True e rs
	# (e,rs) = add_to_registry ["Software\0","Clean\0","CleanIDE\0","Path\0"]	path True e rs
	= (e,rs)
	
remove_ide_from_registry e rs
	# (e,rs)=remove_from_registry ["Software\0","Clean\0","CleanIDE\0","Name\0"]	e rs
	# (e,rs)=remove_from_registry ["Software\0","Clean\0","CleanIDE\0","Path\0"]	e rs
	# (e,rs)=remove_from_registry ["Software\0","Clean\0","CleanIDE\0"]				e rs
	# (e,rs)=remove_from_registry ["Software\0","Clean\0"]							e rs
	= (e,rs)

get_ide_from_registry :: (!String,!String,![String])
get_ide_from_registry
	# rs				= 7
	# (nerr,name,rs)	= check_registry_key ["Software\0","Clean\0","CleanIDE\0","Name\0"] rs
	# (perr,path,rs)	= check_registry_key ["Software\0","Clean\0","CleanIDE\0","Path\0"] rs
	= (name,path,nerr++perr)

enter_file_type_in_registry :: !FileMapping [String] !RegistryState -> (![String],!RegistryState)
enter_file_type_in_registry fm e rs
	# (e,rs) = add_to_registry p1 fm.fm_registry_name True e rs
	# (e,rs) = add_to_registry p2 fm.fm_shell_name True e rs
	# (e,rs) = add_to_registry p3 "\0" True e rs
	# (e,rs) = add_to_registry p4 "\x1\0\0\0" False e rs
	# (e,rs) = add_to_registry p5 fm.fm_executable True e rs
	| not fm.fm_use_dde
		= (e,rs)
	# (e,rs) = add_to_registry p6 "%1\0" True e rs
	# (e,rs) = add_to_registry p7 "CLEANOPEN\0" True e rs
	# (e,rs) = add_to_registry p8 fm.fm_application True e rs
	| isNothing fm.fm_icon
		= (e,rs)
	# (e,rs) = add_to_registry p9 (fromJust fm.fm_icon) True e rs
	= (e,rs)
where
	p1 = ["SOFTWARE\0","Classes\0",fm.fm_extension]
	p2 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name]
	p3 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0"]
	p4 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0",fm.fm_command]
	p5 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0",fm.fm_command,"command\0"]
	p6 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0",fm.fm_command,"ddeexec\0"]
	p7 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0",fm.fm_command,"ddeexec\0","topic\0"]
	p8 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"Shell\0",fm.fm_command,"ddeexec\0","Application\0"]
	p9 = ["SOFTWARE\0","Classes\0",fm.fm_registry_name,"DefaultIcon\0"]

remove_file_type_from_registry :: !String !String !String ![String] !RegistryState -> (![String],!RegistryState)
remove_file_type_from_registry extension registry_name command e rs
	# (e,rs)=remove_from_registry p1 e rs
	# (e,rs)=remove_from_registry p2 e rs
	# (e,rs)=remove_from_registry p3 e rs
	# (e,rs)=remove_from_registry p4 e rs
	# (e,rs)=remove_from_registry p5 e rs
	# (e,rs)=remove_from_registry p6 e rs
	# (e,rs)=remove_from_registry p7 e rs
	# (e,rs)=remove_from_registry p8 e rs
	# (e,rs)=remove_from_registry p9 e rs
	= (e,rs)
where
	p1 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0","topic\0"]
	p2 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0","Application\0"]
	p3 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"ddeexec\0"]
	p4 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command,"command\0"]
	p5 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0",command]
	p6 = ["SOFTWARE\0","Classes\0",registry_name,"Shell\0"]
	p7 = ["SOFTWARE\0","Classes\0",registry_name,"DefaultIcon\0"]
	p8 = ["SOFTWARE\0","Classes\0",registry_name]
	p9 = ["SOFTWARE\0","Classes\0",extension]

//==

add_to_registry :: [String] String Bool [String] RegistryState -> (![String],!RegistryState)
add_to_registry path value is_a_string e rs
	# (r,rs)	= add_to_registry` HKEY_CURRENT_USER path value is_a_string rs
	# e = if (r<>0) (key_add_error path e) e
	= (e,rs)
where
	key_add_error :: [String] [String] -> [String]
	key_add_error p e = e++["Adding '" +++ key_to_string p+++"' failed\n"]

remove_from_registry :: [String] [String] RegistryState -> (![String],!RegistryState)
remove_from_registry path e rs
	# (r,rs)	= remove_from_registry` HKEY_CURRENT_USER path rs
	# e			= if (r<>0) (key_rem_error path e) e
	= (e,rs)
where
	key_rem_error :: [String] [String] -> [String]
	key_rem_error p e = e++["Removing '" +++ key_to_string p+++"' failed\n"]

//==

add_to_registry` :: Int [String] String Bool RegistryState -> (!Int,!RegistryState)
add_to_registry` hkey1 [] value value_is_a_string rs
	# (r,rs) = if value_is_a_string
			(RegSetValueEx hkey1 "\0" 0 REG_SZ value (size value) rs)
			(RegSetValueEx hkey1 "EditFlags\0" 0 REG_BINARY value 4 rs)
	| r<>ERROR_SUCCESS
		= (1,rs) // "RegSetValueEx failed\n"
		= (0,rs)
add_to_registry` hkey1 [path:path_list] value value_is_a_string rs
	#	(r,hkey2,dw,rs) = RegCreateKeyEx hkey1 path 0 "\0" REG_OPTION_NON_VOLATILE KEY_ALL_ACCESS 0 rs
	| r<>ERROR_SUCCESS
		#	(r,hkey2,dw,rs) = RegCreateKeyEx  hkey1 path 0 "\0" REG_OPTION_NON_VOLATILE (KEY_READ bitor KEY_SET_VALUE) 0 rs
		| r<>ERROR_SUCCESS
			= (2,rs) // "RegCreateKeyEx failed\n"
		# (r,rs) = add_to_registry` hkey2 path_list value value_is_a_string rs
		# (_,rs) = RegCloseKey hkey2 rs
		= (r,rs)
	# (r,rs) = add_to_registry` hkey2 path_list value value_is_a_string rs
	# (_,rs) = RegCloseKey hkey2 rs
	= (r,rs)

remove_from_registry` :: Int [String] RegistryState -> (!Int,!RegistryState)
remove_from_registry` hkey [path] rs
	# (r,rs) =RegDeleteKey hkey path rs
	| r==ERROR_SUCCESS
		= (0,rs)
		= (1,rs)
remove_from_registry` hkey [path:path_list] rs
	# (r,hkey2,rs) = RegOpenKeyEx hkey path 0 (KEY_READ bitor KEY_SET_VALUE) rs
	| r<>ERROR_SUCCESS
			= (1,rs)
	# (r,rs)=remove_from_registry` hkey2 path_list rs
	| r==r
		# (rc,rs) = RegCloseKey hkey2 rs
		| rc==rc
			= (r,rs)
			= (r,rs)

