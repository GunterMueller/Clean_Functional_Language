implementation module LibraryDynamics;

import State;
import PlatformLinkOptions;
import ExtFile;
import lib;
from type_io_write import create_type_archive;
import StdEnv;
import LinkerMessages;

build_type_and_code_library :: [String] [String] ![String] !String !*State !*PlatformLinkOptions !*Files -> (!*State,!*PlatformLinkOptions,!*Files);
build_type_and_code_library objects dlls2 libs app_name state platform_link_options files
	// cancel if libs
	| not (isEmpty libs)
		= (AddMessage (LinkerError "cannot use static libraries yet") state,platform_link_options,files);

	// patch, IDE should not give ClientChannel-argument anymore;
	# dlls = filter (\dll_name -> not (snd (ExtractPathAndFile dll_name) == "ClientChannel_library")) dlls2;

//	#! (open_console,platform_link_options) = plo_get_console_windows platform_link_options;
	#! app_name_without_extension = fst (ExtractPathFileAndExtension app_name); // +++ (if open_console "c" "g"); 

	// generate .lib
	#! lib_name = app_name_without_extension +++ ".lib";
	#! (errors, files) = CreateArchive lib_name objects files;
	| not (isEmpty errors)
		= (AddMessage (LinkerError (hd errors)) state,platform_link_options,files);
		
	// write dll file names in .lib; unimplemented
	
	// generate .typ
	#! dlls = map replace_static_client_channel_by_client_channel dlls
	#! typ_name = app_name_without_extension +++ ".typ";
	#! (ok,files) = create_type_archive objects dlls typ_name files;

	= (state,platform_link_options,files);

build_type_library :: [String] [String] ![String] !String !*State !*PlatformLinkOptions !*Files -> (!*State,!*PlatformLinkOptions,!*Files);
build_type_library objects dlls2 libs app_name state platform_link_options files
	// cancel if libs
	| not (isEmpty libs)
		= (AddMessage (LinkerError "cannot use static libraries yet") state,platform_link_options,files);

	// patch, IDE should not give ClientChannel-argument anymore;
	# dlls = filter (\dll_name -> not (snd (ExtractPathAndFile dll_name) == "ClientChannel_library")) dlls2;

	# app_name_without_extension = fst (ExtractPathFileAndExtension app_name);

	// generate .typ
	# dlls = map replace_static_client_channel_by_client_channel dlls
	# typ_name = app_name_without_extension +++ ".typ";
	# (ok,files) = create_type_archive objects dlls typ_name files;
	= (state,platform_link_options,files);

replace_static_client_channel_by_client_channel dll_name
	# (path,file_and_extension)
		= ExtractPathAndFile dll_name;
	| file_and_extension == "StaticClientChannel_library"
		= path +++ "\\ClientChannel_library";
		= dll_name;
