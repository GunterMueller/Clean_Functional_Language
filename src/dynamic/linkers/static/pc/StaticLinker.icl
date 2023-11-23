module StaticLinker;

import StdEnv, StdStrictLists, StdMaybe, ArgEnv, set_return_code;
import Linker, linkargs, ExtFile, get_startup_dir, LinkerMessages;
import UtilStrictLists, ExtString, State, PlatformLinkOptions;

/*
Te doen:
	- de library list wordt leeggegooid door compute_imported_library_symbol_offsets. De functies 
	  write_imported_library_functins_code *en*
	  write_idata
	  gaan hiervan uit. Zij moeten dus de marked_bool_a als argument meekrijgen en erop testen.
	  Dit is alleen geldig in geval van een 'normale' link.
	- eliminatie van read_static_lib_files in Linker.icl (plus omgevende code)
	  static libs zijn eigenlijk gewone object modules. De enige functie die hiervoor moet worden aangepast, is
	  de functie read_xcoff. Je zou dan de static libraries gewoon aan de lijst van te laden objecten kunnen
	  toevoegen.
*/
instance toString LinkerMessage
where {
	toString (LinkerError error)
		= "Linker error: " +++ error;
	toString (LinkerWarning warning)
		= "Linker warning: " +++ warning;
	toString (Verbose msg)
		= "Linker message: " +++ msg;
};

parse_commandline_arguments :: !Int !{{#Char}} ![#{#Char}!] ![#{#Char}!] !LinkInfo`
	-> (!Bool,!{#Char},![#{#Char}!],![#{#Char}!],!LinkInfo`);
parse_commandline_arguments arg_n commandline reversed_object_files reversed_dynamic_libs link_info
	| arg_n<size commandline
		# arg = commandline.[arg_n];
		| size arg>0 && arg.[0]<>'-'
			# reversed_object_files = [# arg : reversed_object_files !];
			= parse_commandline_arguments (arg_n+1) commandline reversed_object_files reversed_dynamic_libs link_info
		| size arg>2 && arg.[1]=='l'
			# reversed_dynamic_libs = [# arg % (2,size arg-1) : reversed_dynamic_libs !];
			= parse_commandline_arguments (arg_n+1) commandline reversed_object_files reversed_dynamic_libs link_info
		| arg=="-o" && arg_n+1<size commandline
			# link_info & exe_path = commandline.[arg_n+1];
			= parse_commandline_arguments (arg_n+2) commandline reversed_object_files reversed_dynamic_libs link_info
			= (False,"Error in argument "+++toString arg_n+++" : "+++arg,reversed_object_files,reversed_dynamic_libs,link_info);
		= (True,"",reversed_object_files,reversed_dynamic_libs,link_info);

append_reversed_file_names [#file_name:reversed_file_names!] paths
	= append_reversed_file_names reversed_file_names (file_name :! paths);
append_reversed_file_names [#!] paths
	= paths;

getLinkOpts :: !{{#Char}} !{#Char} !*World -> *(!Bool,!LinkInfo`,!{#Char},!{#Char},!*World);
getLinkOpts commandline default_dir world
	| size commandline<=1 || (size commandline>=3 && commandline.[1]=="-I")
		# linkoptspath
			= if (size commandline<=1)
				(default_dir +++ "\\linkopts")
				commandline.[2];
		# errors_path
			= if (size commandline>=5 && commandline.[3]=="-O")
				commandline.[4]
				(default_dir +++ "\\linkerrs");
		# ((linkopts,ok,message),world)	= accFiles (ReadLinkOpts linkoptspath) world
		= (ok,linkopts,message,errors_path,world);
		# link_info = emptyLinkInfo`;
		# (ok,message,reversed_object_files,reversed_dynamic_libs,link_info) = parse_commandline_arguments 1 commandline [#!] [#!] link_info;
		# link_info
			& object_paths = append_reversed_file_names reversed_object_files link_info.object_paths
			, dynamic_libs = append_reversed_file_names reversed_dynamic_libs link_info.dynamic_libs;
		= (ok,link_info,message,"",world);

Start world
	# commandline = getCommandLine;
	# (default_dir,world) = accFiles FStartUpDir world;
	# (ok,linkopts,message,errors_path,world) = getLinkOpts commandline default_dir world;
	| not ok
		# (_,world)	= accFiles (WriteLinkErrors errors_path [message]) world
		= set_return_code (-1) world

	// object_paths may contain .libs
	# (objects_paths,extra_static_lib_paths)
		= split_objects_and_libs linkopts.object_paths [] []

	# file_names			= objects_paths
	# library_file_names	= StrictListToList linkopts.dynamic_libs
	# exename				= linkopts.exe_path 
	# stat					= linkopts.static_link
	# static_libs			= (StrictListToList linkopts.static_libs) ++ extra_static_lib_paths
	# (errors,platform_link_options,world)
		= default_platform_link_options linkopts world
	# (state,world)
		= case (isEmpty errors) of {
			True
				// no errors
				-> accFiles (link_xcoff_files stat file_names library_file_names static_libs linkopts.dynamics_path linkopts.lib_name_obj_path exename linkopts.stack_size platform_link_options) world;
			False
				# linker_messages_state = setLinkerMessages errors DefaultLinkerMessages
				# state = { EmptyState & linker_messages_state = linker_messages_state };
				-> (state,world);
		};
	# (messages,state) = GetLinkerMessages state
	# (err,world) = accFiles (WriteLinkErrors errors_path [ toString m \\ m <- messages]) world
	# (ok,state) = IsErrorOccured state
	| ok && isNothing err
		= world
		= set_return_code (-1) world
where {
	split_objects_and_libs Nil objects_paths extra_static_lib_paths
		= (reverse objects_paths,extra_static_lib_paths);
	split_objects_and_libs (f:!fs) objects_paths extra_static_lib_paths
		| snd (ExtractPathFileAndExtension f) == "lib"
			= split_objects_and_libs fs objects_paths [f:extra_static_lib_paths];
			= split_objects_and_libs fs [f:objects_paths] extra_static_lib_paths;

	// for a normal executable
	default_platform_link_options linkopts=:{dll_names,gen_dll,stack_size,open_console,gen_relocs,gen_symbol_table,gen_linkmap,link_resources,res_path} world
		// console window
		# platform_link_options = plo_set_console_window open_console DefaultPlatformLinkOptions;
		# platform_link_options = plo_set_generate_symbol_table gen_symbol_table platform_link_options;
		// relocations and dll
		# (errors,platform_link_options,world)
			= set_dll_options gen_dll platform_link_options world;
		// link map
		# platform_link_options = plo_set_gen_linkmap gen_linkmap platform_link_options;
		// resources
		# platform_link_options = plo_set_gen_resource link_resources res_path platform_link_options;
		// bug fix
		# platform_link_options = plo_set_c_stack_size (max stack_size 0x00010000) platform_link_options;
		= (errors,platform_link_options,world);
	where {
		set_dll_options False platform_link_options world
			= ([],plo_set_gen_relocs gen_relocs platform_link_options,world);
		set_dll_options _ platform_link_options world
			// file name specified
			| dll_names == ""
				# error = LinkerError "No file containing exported DLL functions specified";
				= ([error],platform_link_options,world);
			
			// generate DLL
			# (errors,exported_functions,world)
				= read_exported_entries world;

			#! platform_link_options = plo_set_base_va 0x10000000 platform_link_options;
			#! platform_link_options = plo_set_make_dll True platform_link_options;
			#! platform_link_options = plo_set_gen_relocs True platform_link_options;
			#! platform_link_options = plo_set_exported_symbols exported_functions platform_link_options;
			#! platform_link_options = plo_set_main_entry (Link32or64bits "_DllMain@12" "DllMain") platform_link_options;
			= (errors,platform_link_options,world);
		where {
			read_exported_entries world
				// open exported functions file
				# (ok,file,world)
					= fopen dll_names FReadText world
				| not ok
					# msg = LinkerError ("file '" +++ dll_names +++ "' containing exported DLL functions could not be read")
					= ([msg],[],world)
				
				# (errors,exported_functions,file)
					= read_entries [] [] 1 file
					
				// close file
				# (_,world) = fclose file world
					
				// sanity checks
				| isEmpty exported_functions
					#! msg = LinkerError ("file '" +++ dll_names +++ "' does not contain exported DLL functions")
					= ([msg],[],world)

				= (errors,exported_functions,world) 
			where {
				read_entries efs errors line_n file
					# (end_of_file,file) = fend file
					| end_of_file
						= (errors,efs,file)
						
					// read line
					# (line,file) = freadline file
					# (errors2,public_name,internal_name) = parse_line line
	
					= read_entries (if (internal_name == "") efs [(public_name,internal_name):efs]) (errors ++ errors2) (inc line_n) file
				where {
					parse_line line
						// syntax: 		public_name[=:internal name] garbage newline 
						//		   	|	internal_name
						//			|	newline
						// public_name,internal_name: sequence of alpha numeric characters including the
						// underscore. garbage is a sequence of characters.
						# (name_found,i)
							= CharIndexFunc line 0 (\c -> not (isAlphanum c || c == '_' ) )
						| not name_found
							= ([],"","")
							
						# name = line % (0,i-1)
						| line.[i] == ':' && line.[inc i] == '='
							# (internal_name_found,j)
								= CharIndexFunc line (i + 2) (\c -> not (isAlphanum c || c == '_' ) )
							| i + 2 == j
								= ([LinkerError ("file '" +++ dll_names +++ "' expected internal name at line " +++ toString line_n)],"","")

							# internal_name = line % (i+2,j-1)
							= ([],name,internal_name)
							
						= ([],"",name)
				}
			}	
		} 
	}
}
