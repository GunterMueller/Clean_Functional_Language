implementation module Linker;

// FIXME: remove this dependency
from StdDynamicTypes import FILE_IDENTIFICATION;
from DynIDMacros import CREATE_ENCODED_LIBRARY_FILE_NAME, CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION,
						ADD_CODE_LIBRARY_EXTENSION, ADD_TYPE_LIBRARY_EXTENSION;
import StdEnv;
from StdMisc import abort;
from ReadObject import class ExtFileSystem, instance ExtFileSystem Files, read_xcoff_files,read_library_files,read_library_files_new,read_library_files2; // only for PC,read_static_lib_files;
from lib import ::ImportLibrary(..);
from piObjectToDisk import write_object_to_disk;
import SymbolTable, ObjectToDisk, ExtString, ExtFile;
import LinkerMessages, LibraryDynamics, State, PlatformLinkOptions;
import directory_structure, md5, Directory, StdMaybe;
import Redirections, NamesTable, pdSymbolTable, link32or64bits;
// windows ...
from lib import read_static_lib_files, ::ReadStaticLibState(..), default_rsl_state, ::ImportLibrary;
import link_switches, expand_8_3_names_in_path, selectively_import_and_mark_labels, utilities;

append_library_lists EmptyLibraryList library_list
	= library_list;
append_library_lists (Library s i1 lsl i2 xs) library_list
	= (Library s i1 lsl i2 (append_library_lists xs library_list));

select_import_libraries :: !*ReadStaticLibState -> *([ImportLibrary],*ReadStaticLibState);
select_import_libraries rsl_state=:{import_libraries}
	= (import_libraries,{rsl_state & import_libraries = []});

link_xcoff_files :: !Bool ![String] ![String] ![String] !String !String !String !Int !PlatformLinkOptions !Files  -> (!*State,!Files);
link_xcoff_files normal_static_link file_names library_file_names static_libraries dynamics_path lib_name_obj_path application_file_name stack_size platform_link_options files
	# (ok,state,platform_link_options,files)
		= read_files_and_link normal_static_link file_names library_file_names static_libraries application_file_name platform_link_options files;
	| not ok
		= (state,files);
	| normal_static_link
		= write_files_for_static_link platform_link_options state files;
	| size lib_name_obj_path==0
		# state & linker_messages_state = setLinkerMessages [LinkerError "Path name of lib_name.o missing"] state.linker_messages_state;
		= (state,files);
		= write_files_for_dynamic_link file_names library_file_names static_libraries dynamics_path lib_name_obj_path application_file_name stack_size state platform_link_options files;

read_files_and_link :: !Bool ![String] ![String] ![String] !String !PlatformLinkOptions !Files  -> (!Bool,!*State,!PlatformLinkOptions,!Files);
read_files_and_link normal_static_link file_names library_file_names static_libraries application_file_name platform_link_options files
	// platform independent options
	#! one_pass_link = True;
	/* WARNING:
		The MAC only supports one pass linking. Thus the one_pass_link *must* be set to
		True. The PC simply ignores the flag.
	*/
	// read object files
	#! (any_extra_sections,read_xcoff_files_errors,sections,n_xcoff_files,xcoff_list,names_table,files,_)
		= read_xcoff_files False file_names create_names_table one_pass_link files 0 default_redirection_state;
	| not (isEmpty read_xcoff_files_errors)
		# linker_messages_state = setLinkerMessages [LinkerError e \\ e <- read_xcoff_files_errors] DefaultLinkerMessages;
		= (False, {EmptyState & linker_messages_state = linker_messages_state},platform_link_options,files);
	# platform_link_options = plo_set_sections sections platform_link_options;
	# platform_link_options = plo_any_extra_sections any_extra_sections platform_link_options;
	// read static libraries
	# (errors,xcoff_list,names_table,n_xcoff_files,files,lib_library_list,n_library_symbols,n_total_libraries)
		= case (sel_platform True False) of { 
			True
				// winos
				#! (errors,xcoff_list, _, names_table, n_xcoff_files, files,rsl_state,_)
					= read_static_lib_files static_libraries [] names_table n_xcoff_files xcoff_list files default_rsl_state default_redirection_state;
				# (import_libraries,rsl_state) = select_import_libraries rsl_state;
				# n_import_libraries = length import_libraries;
				#! n_libraries = n_import_libraries + length library_file_names;
				#! import_libraries = [[ il_name:il_symbols] \\ {il_name,il_symbols} <- import_libraries ];
				#! (library_list,n_library_symbols,names_table)
					= read_library_files2 import_libraries (~n_libraries) 0 names_table;
				-> (errors,xcoff_list,names_table,n_xcoff_files,files,library_list,n_library_symbols,n_libraries);			
			False
				#! n_libraries = length library_file_names;
				-> ([],xcoff_list,names_table,n_xcoff_files,files,EmptyLibraryList,0,n_libraries);
		};
	| not (isEmpty errors)
		# linker_messages_state = setLinkerMessages [LinkerError e \\ e <- errors] DefaultLinkerMessages;
		= (False, {EmptyState & linker_messages_state = linker_messages_state},platform_link_options,files);
	// read dynamic libraries	
	#! n_libraries = length library_file_names;
	   (read_library_errors,library_list,n_library_symbols,files,names_table)
		= read_library_files library_file_names (~n_libraries) /* old 0 */ n_library_symbols files names_table;
	| not (isEmpty read_library_errors)
		# linker_messages_state = setLinkerMessages [LinkerError e \\ e <- read_library_errors] DefaultLinkerMessages;
		= (False, {EmptyState & linker_messages_state = linker_messages_state},platform_link_options,files);
	# n_libraries = n_total_libraries;
	# library_list = append_library_lists lib_library_list library_list;		
	# (base_va,platform_link_options) = plo_get_base_va platform_link_options;
	# linker_state_info = { one_pass_link = one_pass_link, normal_static_link = normal_static_link,
							linker_state_base_va = base_va};
	#! state
		= { EmptyState &
			linker_state_info = linker_state_info
		,	application_name		= application_file_name
		,	n_libraries				= n_libraries
		,	n_xcoff_files			= n_xcoff_files
		,	n_library_symbols		= n_library_symbols
		,	namestable				= names_table
		,	library_list			= library_list
		,	library_file_names		= library_file_names
		};
	#! (state,platform_link_options,files) 
		= (ALLOW_UNUSED_UNDEFINED_SYMBOLS resolve_symbol_references_lazily try_to_resolve_references_immediately) 
		xcoff_list state platform_link_options files;
	# (ok,state) = IsErrorOccured state;
	| not ok
		= (False,state,platform_link_options,files);
		= (True,state,platform_link_options,files);

write_files_for_static_link :: !*PlatformLinkOptions !*State !*Files -> (!*State,!*Files);
write_files_for_static_link platform_link_options state files
	# (state,platform_link_options,files)
		= write_object_to_disk platform_link_options state files;
	# (ok,state) = IsErrorOccured state;
	| ok
		# (_,_,state,platform_link_options,files)
			= post_process state platform_link_options files;
		= (state,files);
		= (state,files);

write_files_for_dynamic_link :: ![{#Char}] ![{#Char}] ![{#Char}] !{#Char} !{#Char} !{#Char} !Int !*State !*PlatformLinkOptions !*Files -> (!*State,!*Files);
write_files_for_dynamic_link file_names library_file_names static_libraries dynamics_path lib_name_obj_path application_file_name stack_size state platform_link_options files
	# (md5_object_file_names,state,files)
		= create_modules_dir_and_write_object_files file_names dynamics_path state files;
	| isEmpty md5_object_file_names
		= (state,files);
	#! (r,state,platform_link_options,files)
		= write_code_and_type_library md5_object_file_names application_file_name dynamics_path file_names library_file_names static_libraries state platform_link_options files;
	= case r of {
		Nothing
			-> (state,files);
		Just (library_file_name,temp_code_p,temp_type_p)
			# (_,files) = fremove temp_code_p files;
			# (_,files) = fremove temp_type_p files;
			
			# (ok,files) = write_lib_name_obj_file lib_name_obj_path library_file_name files;
			| not ok
				# state & linker_messages_state = setLinkerMessages [LinkerError ("Writing "+++lib_name_obj_path+++"failed")] state.linker_messages_state;
				-> (state,files);			

			# (dynamic_linker_path, dynamic_linker_rts_options)
				= split_dynamics_path_and_options dynamics_path;
			  (dynamic_linker_dir,_) = ExtractPathAndFile dynamic_linker_path;
			  (application_dir,_) = ExtractPathAndFile application_file_name;

			# client_channel_dll_source_path = dynamic_linker_dir +++ "\\ClientChannel.dll";
			  client_channel_dll_destination_path = application_dir +++ "\\ClientChannel.dll";
			# (copy_file_error_code,files) = copy_file client_channel_dll_source_path client_channel_dll_destination_path files;
			| copy_file_error_code<>Rcopy_file_ok
				# error = copy_file_error_to_string copy_file_error_code client_channel_dll_source_path client_channel_dll_destination_path;
				  state = AddMessage (LinkerError error) state;
				-> (state,files);

			# startup0_object_path = dynamic_linker_dir +++ "\\_startup0.o";
			  dyn_link_app_object_path = dynamic_linker_dir +++ "\\dyn_link_app.o";
			  client_channel_library_path = dynamic_linker_dir +++ "\\ClientChannel_library";

			# dyn_app_object_files = [startup0_object_path,lib_name_obj_path,dyn_link_app_object_path];
			  dyn_app_libraries = [client_channel_library_path];

			# (is_console_application,platform_link_options) = plo_get_console_window platform_link_options

			# dyn_app_platform_link_options = DefaultPlatformLinkOptions;
			  dyn_app_platform_link_options = plo_set_c_stack_size (max stack_size 0x00010000) dyn_app_platform_link_options;
			  is_console_application = plo_set_console_window is_console_application dyn_app_platform_link_options;

			# (ok,dyn_app_state,dyn_app_platform_link_options,files)
				= read_files_and_link True dyn_app_object_files dyn_app_libraries [] application_file_name dyn_app_platform_link_options files;
			| not ok
				-> (state,files);
			# (dyn_app_state,files)
				= write_files_for_static_link dyn_app_platform_link_options dyn_app_state files;
			-> (state,files);
	  };

EXTRACT_FILE_NAME file_name
	:== (snd (ExtractPathAndFile (fst (ExtractPathFileAndExtension file_name))));

write_code_and_type_library :: ![{#Char}] !{#Char} !{#Char} ![{#Char}] ![{#Char}] ![{#Char}] !*State !*PlatformLinkOptions !*Files
															  -> (!Maybe ({#Char},Path,Path),!*State,!*PlatformLinkOptions,!*Files);
write_code_and_type_library md5_object_file_names application_file_name dynamics_path file_names library_file_names static_libraries state platform_link_options files
	#! (dynamic_linker_path,_)
		= ExtractPathAndFile dynamics_path;
	# (_,files)
		= ds_create_directory DS_LIBRARIES_DIR dynamic_linker_path files;

	// get root of dynamic linker
	#! encoded_library_identification = CREATE_ENCODED_LIBRARY_FILE_NAME "temp" "code" "type";
	#! rt_library_identification = CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION dynamic_linker_path encoded_library_identification;
		
	#! temp_code_path = ADD_CODE_LIBRARY_EXTENSION rt_library_identification;
	#! ((ok1,temp_code_p),files)
		= pd_StringToPath temp_code_path files;

	#! temp_type_path = ADD_TYPE_LIBRARY_EXTENSION rt_library_identification;
	#! ((ok2,temp_type_p),files)
		= pd_StringToPath temp_type_path files;
	| not ok1 || not ok2
		# msg = "cannot convert '" +++ (if (not ok1) temp_code_path temp_type_path) +++ "'";
		# state = AddMessage (LinkerError msg) state;
		= (Nothing,state,platform_link_options,files);

	// create libraries with temporary names
	#! (state,platform_link_options,files)
//		= build_type_and_code_library file_names library_file_names static_libraries rt_library_identification state platform_link_options files; // if object files are stored a .lib file
		= build_type_library file_names library_file_names static_libraries rt_library_identification state platform_link_options files;

	# (app_name_without_extension,_) = ExtractPathFileAndExtension rt_library_identification;
	# lib_name = app_name_without_extension +++ ".lib";
	# (ok,files)
		= create_text_lib_file lib_name md5_object_file_names files;
	| not ok
		# msg = "Writing the library file: '" +++lib_name+++"' failed";
		# state = AddMessage (LinkerError msg) state;
		= (Nothing,state,platform_link_options,files);

	// rename code library
	#! (code_lib_md5,files)
		= getMd5DigestFromFile temp_code_path files;
	#! (type_lib_md5,files)
		= getMd5DigestFromFile temp_type_path files;
	#! md5_name = CREATE_ENCODED_LIBRARY_FILE_NAME (EXTRACT_FILE_NAME application_file_name) code_lib_md5 type_lib_md5;
				
	#! md5_code_path
		= CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION dynamic_linker_path (ADD_CODE_LIBRARY_EXTENSION md5_name);
	
	#! x = Just (ADD_CODE_LIBRARY_EXTENSION md5_name,temp_code_p,temp_type_p);

	#! ((_,md5_code_p),files)
		= pd_StringToPath md5_code_path files;
	#! (dir_error,files)
		= fmove OverwriteFile temp_code_p md5_code_p files;
//		| dir_error <> NoDirError
//			#! state
//				= AddMessage (LinkerError (make_dir_error_readable dir_error md5_code_path)) state;
//			= (x,state,platform_link_options,files);

	// rename type library					
	#! md5_type_path = CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION dynamic_linker_path (ADD_TYPE_LIBRARY_EXTENSION md5_name);

	#! ((_,md5_type_p),files)
		= pd_StringToPath md5_type_path files;		
	#! (dir_error,files)
	 	= fmove OverwriteFile temp_type_p md5_type_p files;
//		| dir_error <> NoDirError
//			#! state
//				= AddMessage (LinkerError (make_dir_error_readable dir_error md5_type_path)) state;
//			= (x,state,platform_link_options,files);

		= (x,state,platform_link_options,files);

create_text_lib_file :: !{#Char} ![{#Char}] !*Files -> (!Bool,!*Files);
create_text_lib_file lib_name md5_object_file_names files
	# (ok,lib_file,files) = fopen lib_name FWriteText files;
	| not ok
		= (False,files);
	# lib_file = write_lines md5_object_file_names lib_file;
	= fclose lib_file files;
{
	write_lines [md5_object_file_name:md5_object_file_names] lib_file
		# lib_file = fwritec '\n' (fwrites md5_object_file_name lib_file);
		= write_lines md5_object_file_names lib_file;
	write_lines [] lib_file
		= lib_file;
}

write_lib_name_obj_file :: !{#Char} !{#Char} !*Files -> (!Bool,!*Files);
write_lib_name_obj_file lib_name_obj_path library_file_name files
	| size library_file_name<>69 // 32+1+32+4
		= abort "write_lib_name_obj_file: error in lib file name";
	# (ok,lib_name_obj_file,files) = fopen lib_name_obj_path FWriteData files;
	| not ok
		= (False,files);
	# lib_name_obj_file = lib_name_obj_file
		FWS "\x4c\x01\x03\x00\x00\x00\x00\x00\xd4\x00\x00\x00\x09\x00\x00\x00"
		FWS "\x00\x00\x05\x01\x2e\x74\x65\x78\x74\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x20\x00\x30\x60\x2e\x64\x61\x74"
		FWS "\x61\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x48\x00\x00\x00"
		FWS "\x8c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x40\x00\x30\xc0\x2e\x62\x73\x73\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x80\x00\x30\xc0";
	# lib_name_obj_file = fwrites library_file_name lib_name_obj_file;
	# lib_name_obj_file = lib_name_obj_file
		FWS      "\x00\x00\x00\x2e\x66\x69\x6c\x65\x00\x00\x00\x00\x00\x00\x00"
		FWS "\xfe\xff\x00\x00\x67\x01\x66\x61\x6b\x65\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x2e\x74\x65\x78\x74\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x01\x00\x00\x00\x03\x01\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x2e\x64\x61\x74"
		FWS "\x61\x00\x00\x00\x00\x00\x00\x00\x02\x00\x00\x00\x03\x01\x46\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x2e\x62\x73\x73\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\x00\x00"
		FWS "\x03\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x00\x00\x00\x00\x00\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00"
		FWS "\x02\x00\x00\x00\x02\x00\x0e\x00\x00\x00\x5f\x6c\x69\x62\x5f\x6e"
		FWS "\x61\x6d\x65\x00";
	= fclose lib_name_obj_file files;

split_dynamics_path_and_options :: !{#Char} -> (!{#Char},!{#Char});
split_dynamics_path_and_options path_and_options
	// start at index 2, assume that a ':' at index 1
	// is the drive letter of the dynamics linker path
	// (for example C:\Clean\Tools\..)
	// (yes, this is quite crude)
	# (found,index)
		= CharIndex path_and_options 2 ':'
	| found
		= (path_and_options%(0,index-1), path_and_options%(index+1,size path_and_options));
		= (path_and_options, "");

add_clean_unwind_info_if_64_bits entry_datas names_table
	:== Link32or64bits
			(entry_datas,names_table)
			(add_clean_unwind_info entry_datas names_table);

add_clean_unwind_info entry_datas names_table
	# (clean_unwind_info_names_table_element,names_table)
		= find_symbol_in_symbol_table "clean_unwind_info" names_table;
	# (NamesTableElement _ clean_unwind_info_symbol_n clean_unwind_info_file_n _) = clean_unwind_info_names_table_element;
	# entry_datas = [(True,"",clean_unwind_info_file_n,clean_unwind_info_symbol_n) : entry_datas];
	= (entry_datas,names_table);

try_to_resolve_references_immediately xcoff_list 
	state=:{linker_state_info={one_pass_link,normal_static_link},namestable=names_table
		, application_name=application_file_name,
		n_libraries,n_xcoff_files,n_library_symbols,library_list,library_file_names} platform_link_options files

	// resolve symbolic references by name
	#! (undefined_symbols,xcoff_list,names_table)
		= import_symbols_in_xcoff_files xcoff_list 0 [] names_table;
	| not (isEmpty undefined_symbols)
		# linker_messages_state
			= setLinkerMessages [LinkerError ("undefined symbol: " +++ symbol_name) \\ (symbol_name,_,_)<-undefined_symbols] DefaultLinkerMessages;
		= ({ EmptyState & linker_messages_state = linker_messages_state },platform_link_options,files);
		
	// check for the existence of main entry and any exported symbols
	# (main_entry_found,main_file_n,main_symbol_n,			// main entry
	   all_exported_symbols_found,entry_datas,				// exported symbols (found,symbol_name,file_n,symbol_n)
	   names_table,											// names table
	   platform_link_options)
	   	= find_root_symbols names_table platform_link_options;
	| not main_entry_found || not all_exported_symbols_found
		# undefined_main_entry
			= case main_entry_found of {
				True	-> [];
				False	-> ["Symbol \"main\" is not defined"];
			};
		# undefined_exported_entries
			= case all_exported_symbols_found of {
				True	-> [];
				False	-> [ ("Exported symbol \"" +++ name +++ "\" is not defined.") \\ (found,name,file_n,symbol_n) <- entry_datas | not found ];
			};
		# linker_messages_state
			= setLinkerMessages [LinkerError e \\ e <- (undefined_main_entry ++ undefined_exported_entries)] DefaultLinkerMessages;
		= ({ EmptyState & linker_messages_state = linker_messages_state },platform_link_options,files);

	# platform_link_options = plo_set_main_file_n_and_symbol_n main_file_n main_symbol_n platform_link_options

	// mark only used symbols
	# (entry_datas,names_table) = add_clean_unwind_info_if_64_bits entry_datas names_table
	# root_entries = [(True,"",main_file_n,main_symbol_n) : entry_datas];
	#! (unused_undefined_symbols,n_xcoff_symbols,marked_bool_a,marked_offset_a,xcoff_a,names_table)
		= mark_modules_list [] xcoff_list n_xcoff_files n_libraries n_library_symbols library_list root_entries names_table;
	| False //not (isEmpty undefined_symbols)
		# linker_messages_state
			= setLinkerMessages [LinkerError ("unused undefined symbol " +++ e) \\ e <- unused_undefined_symbols] DefaultLinkerMessages;
		= ({ EmptyState & linker_messages_state = linker_messages_state },platform_link_options,files);
	
	# linker_messages_state
		= setLinkerMessages [LinkerWarning ("unused undefined symbol " +++ e) \\ e <- unused_undefined_symbols] DefaultLinkerMessages;

	// create state
	# (base_va,platform_link_options) = plo_get_base_va platform_link_options;
	# linker_state_info = {	one_pass_link = one_pass_link, normal_static_link = normal_static_link,
							linker_state_base_va = base_va};
	#! state 
		= { EmptyState &
			// misc
				linker_state_info = linker_state_info
			// linker tables
			,	application_name		= application_file_name
			,	n_libraries				= n_libraries
			,	n_xcoff_files 			= n_xcoff_files
			,	n_xcoff_symbols			= n_xcoff_symbols
			,	n_library_symbols		= n_library_symbols
			
			,	marked_bool_a			= marked_bool_a
			,	marked_offset_a			= marked_offset_a
			,	xcoff_a 				= xcoff_a
			,	namestable				= names_table
		
			// dynamic libraries
			,	library_list 			= library_list
			,	library_file_names		= if normal_static_link [] (strip_paths_from_file_names library_file_names)
		};
	= (state,platform_link_options,files);
	
add_file_n_and_symbol_n_of_clean_unwind_info_if_64_bits file_n_and_symbol_n_of_entry_datas names_table
	:== Link32or64bits
			(file_n_and_symbol_n_of_entry_datas,names_table)
			(add_file_n_and_symbol_n_of_clean_unwind_info file_n_and_symbol_n_of_entry_datas names_table);

add_file_n_and_symbol_n_of_clean_unwind_info file_n_and_symbol_n_of_entry_datas names_table
	# (clean_unwind_info_names_table_element,names_table)
		= find_symbol_in_symbol_table "clean_unwind_info" names_table;
	# (NamesTableElement _ clean_unwind_info_symbol_n clean_unwind_info_file_n _) = clean_unwind_info_names_table_element;
	# file_n_and_symbol_n_of_entry_datas = [(clean_unwind_info_file_n,clean_unwind_info_symbol_n) : file_n_and_symbol_n_of_entry_datas]
	= (file_n_and_symbol_n_of_entry_datas,names_table);

check_presence_of_root_symbols state platform_link_options files
	# (names_table,state) = select_namestable state;

	// fix ...		
	# (names_table_element,names_table)
		= find_symbol_in_symbol_table "_start" names_table; 
	| not (isNamesTableElement names_table_element)
		# state = update_namestable names_table state;
		# state = AddMessage (LinkerError "The Start function of the application is undefined") state;
		= ([],state,platform_link_options,files);
	
	// check for the existence of main entry and any exported symbols
	# (main_entry_found,main_file_n,main_symbol_n,			// main entry
	   all_exported_symbols_found,entry_datas,				// exported symbols (found,symbol_name,file_n,symbol_n)
	   names_table,											// names table
	   platform_link_options)
	   	= find_root_symbols names_table platform_link_options;

	# file_n_and_symbol_n_of_entry_datas = [(file_n,symbol_n) \\ (True,_,file_n,symbol_n) <- entry_datas];
	# (file_n_and_symbol_n_of_entry_datas,names_table)
		= add_file_n_and_symbol_n_of_clean_unwind_info_if_64_bits file_n_and_symbol_n_of_entry_datas names_table;

	# state = update_namestable names_table state;
	| not main_entry_found || not all_exported_symbols_found
		# undefined_main_entry
			= case main_entry_found of {
				True
					-> [];
				False
					-> ["Symbol \"main\" is not defined"];
			};
		# undefined_exported_entries
			= case all_exported_symbols_found of {
				True
					-> [];
				False 
					-> [ ("Exported symbol \"" +++ name +++ "\" is not defined.") \\ (found,name,file_n,symbol_n) <- entry_datas | not found ];
			};
		# linker_messages_state
			= setLinkerMessages [LinkerError e \\ e <- (undefined_main_entry ++ undefined_exported_entries)] DefaultLinkerMessages;
		= ([],{ state & linker_messages_state = linker_messages_state },platform_link_options,files);
			
			
		# file_n_and_symbol_n_of_root_symbols
			= [ (main_file_n,main_symbol_n) : file_n_and_symbol_n_of_entry_datas];
		= (file_n_and_symbol_n_of_root_symbols,state,platform_link_options,files);
where {
	isNamesTableElement EmptyNamesTableElement	= False;
	isNamesTableElement	_						= True;
};
	
resolve_symbol_references_lazily xcoff_list 
		state=:{linker_state_info={normal_static_link},application_name=application_file_name,
		n_libraries,n_xcoff_files,n_library_symbols,library_list,library_file_names} platform_link_options files
	#! (n_xcoff_symbols,xcoff_list)
		= n_symbols_of_xcoff_list 0 xcoff_list;

	#! already_marked_bool_a 
		= createArray (n_xcoff_symbols+n_library_symbols) False;

	#! (marked_bool_a,marked_offset_a,xcoff_a)
		= create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list xcoff_list;
		
	#! (file_n_and_symbol_n_of_root_symbols,state,platform_link_options,files)
		= check_presence_of_root_symbols state platform_link_options files;		

	#! state 
		= { state &
			// misc
				n_xcoff_symbols			= n_xcoff_symbols	
			,	marked_bool_a			= already_marked_bool_a
			,	marked_offset_a			= marked_offset_a
			,	xcoff_a 				= xcoff_a
			,	library_file_names		= if normal_static_link [] (strip_paths_from_file_names library_file_names)
		};

	#! (marked_bool_a,state)
		= foldSt (\(file_n,symbol_n) s -> selective_import_symbol file_n symbol_n s) file_n_and_symbol_n_of_root_symbols (marked_bool_a,state)

	#! state = { state & marked_bool_a = marked_bool_a };
	= (state,platform_link_options,files);

create_modules_dir_and_write_object_files :: ![{#Char}] !{#Char} !*State !*Files -> (![{#Char}],!*State,!*Files);
create_modules_dir_and_write_object_files object_file_names dynamics_path state files
	# (dynamic_linker_dir,_) = ExtractPathAndFile dynamics_path;
	# modules_dir = dynamic_linker_dir +++ "\\modules";
	# (directory_exits,files) = create_directory modules_dir files;
	| not directory_exits
		# state = AddMessage (LinkerError ("Could not create directory '"+++modules_dir+++"'")) state;
		= ([],state,files);
		= write_object_files object_file_names modules_dir state files;
	where {
		write_object_files [] modules_dir state files
			= ([],state,files);
		write_object_files [object_file_name:object_file_names] modules_dir state files
			# (module_name,_) = ExtractPathFileAndExtension object_file_name;
			  (_,module_name) = ExtractPathAndFile module_name;
			  (maybe_object_file_md5,files) = getMd5DigestFromFile_ object_file_name files;
			= case maybe_object_file_md5 of {
				Nothing
					# state = AddMessage (LinkerError ("Error reading '"+++object_file_name+++"'")) state;
					-> ([],state,files);
				Just object_file_md5
					# directory_name = modules_dir+++"\\"+++module_name;
					  file_name = directory_name+++"\\"+++object_file_md5+++".o";
					  md5_object_file_name = module_name+++"\\"+++object_file_md5+++".o";
					  (file_exists,files) = determine_if_file_or_directory_exists file_name files;
					| file_exists
						# (md5_object_file_names,state,files)
							= write_object_files object_file_names modules_dir state files;
						-> ([md5_object_file_name:md5_object_file_names],state,files);
					# (directory_exists,files)
						= case (determine_if_file_or_directory_exists directory_name files) of {
							(True,files)
								-> (True,files);
							(False,files)
								-> create_directory directory_name files;
						}
					| not directory_exists
						# state = AddMessage (LinkerError ("Could not create directory '"+++directory_name+++"'")) state;
						-> ([],state,files);
						# (copy_file_error_code,files) = copy_file object_file_name file_name files;
						| copy_file_error_code==Rcopy_file_ok
							# (md5_object_file_names,state,files)
								= write_object_files object_file_names modules_dir state files;
							-> ([md5_object_file_name:md5_object_file_names],state,files);
							# error = copy_file_error_to_string copy_file_error_code object_file_name modules_dir;
							  state = AddMessage (LinkerError error) state;
							-> ([],state,files);
			}
	}

create_directory :: !{#Char} !*Files -> (!Bool,!*Files);
create_directory directory_name files
	#! ((ok,path),files) = pd_StringToPath directory_name files;
	| not ok
		= (False,files);
	# (createDirectory_error_code,files) = createDirectory path files;
	= case createDirectory_error_code of {
		NoDirError
			-> (True,files);
		AlreadyExists
			-> (True,files);
		_
			-> (False,files);
	};

determine_if_file_or_directory_exists :: !{#Char} !*Files -> (!Bool,!*Files);
determine_if_file_or_directory_exists file_name files
	# ((ok,path),files) = pd_StringToPath file_name files;
	| not ok
		= (False,files);
	# ((dir_error,_),files) = getFileInfo path files;
	= case dir_error of {
		NoDirError
			-> (True,files);
		_
			-> (False,files);
	};

Rcopy_file_ok:==0;
Rcopy_file_fopen_input_failed:==1;
Rcopy_file_fopen_output_failed:==2;
Rcopy_file_reading_failed:==3;
Rcopy_file_writing_failed:==4;

copy_file :: !{#Char} !{#Char} !*Files -> (!Int,!*Files);
copy_file input_file_name output_file_name files
	# (ok,input,files) = fopen input_file_name FReadData files;
	| not ok
		= (Rcopy_file_fopen_input_failed,files);
	# (ok,output,files) = fopen output_file_name FWriteData files;
	| not ok
		= (Rcopy_file_fopen_output_failed,files);
	# (input,output)
		= copy_file_ input output; 
		with {
			copy_file_ :: !*File !*File -> (!*File,!*File);
			copy_file_ src dst
				# (string,src) = freads src 4096;
				| size string<>0
					= copy_file_ src (fwrites string dst);
					= (src,dst);
		};
	# (ok,files) = fclose input files;
	| not ok
		# (ok,files) = fclose output files;
		= (Rcopy_file_reading_failed,files);
	# (ok,files) = fclose output files;
	| not ok
		= (Rcopy_file_writing_failed,files);
		= (Rcopy_file_ok,files);

copy_file_error_to_string copy_file_error_code input_file_name output_file_name
	= case copy_file_error_code of {
		Rcopy_file_fopen_input_failed
			-> "Could not open '"+++input_file_name+++"'";
		Rcopy_file_fopen_output_failed
			-> "Could not create '"+++output_file_name+++"'";
		Rcopy_file_reading_failed
			-> "Error reading '"+++input_file_name+++"'";
		Rcopy_file_writing_failed
			-> "Could not write '"+++output_file_name+++"'";
	};
