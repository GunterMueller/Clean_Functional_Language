module StaticLinker

import StdInt,StdFile,StdArray,StdBool,StdChar,StdString,StdClass
import StdList, StdEnum, StdMisc

import Linker
import ArgEnv
import linkargs
import UtilStrictLists
import set_return_code
import edata
import DebugUtilities
import ExtFile
import get_startup_dir		// Module

debug normal_mode debug_mode :== normal_mode;

/*
Te doen:
	- relocs section wordt niet goed gecreerd
	- efficientie verbeteren; naar disk schrijven van Maarten's project duurt 40 seconden
		(instance in CommonObjectToDisk, een algemene buffer maken waarin de string gelezen wordt, one pass link implementeren
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


print i limit s commandline
	| i >= limit
		= abort s;
		= print (inc i) limit (s +++ commandline.[i]) commandline;

Start world
	# commandline
		= getCommandLine;

	# s_commandline
		= size commandline
		
//	# commandline 
//		= print 0 s_commandline "!!" commandline
	# (default_dir,world)
		= accFiles FStartUpDir world
//	| True
//		= abort default_dir
		
	# linkoptspath
		= debug(if (s_commandline >= 3 && commandline.[1] == "-I") commandline.[2] (default_dir +++ "\\linkopts"))
		"C:\\WINDOWS\\Desktop\\Clean\\linkopts_test";

//				(default_dir +++ "\\linkopts1")
//				(default_dir +++ "\\linkopts")
//		        ("C:\\WINDOWS\\Desktop\\Clean\\linkopts1");
//		        ("C:\\WINDOWS\\Desktop\\Clean\\linkopts_hello");
		         
	# errors_path
		= debug (if (s_commandline >= 5 && commandline.[3] == "-O") commandline.[4] (default_dir +++ "\\linkerrs"))
//				(default_dir +++ "\\linkerrs")
				("C:\\WINDOWS\\Desktop\\Clean\\linkerrs1");
//				("C:\\WINDOWS\\Desktop\\Clean\\linkerrs_hello1");
		
//	# linkoptspath = applicationpath "\\tools\\linkopts"//"linkopts"
	# ((linkopts,ok,message),world)	= accFiles (ReadLinkOpts linkoptspath) world
	| not ok
		#! (_,world)	= accFiles (WriteLinkErrors errors_path [message]) world
		#! world		= set_return_code (-1) world
		= world;
	# file_names			= StrictListToList linkopts.object_paths
	# library_file_names	= StrictListToList linkopts.dynamic_libs
	# exename				= debug (linkopts.exe_path) 
//			("C:\\WINDOWS\\Desktop\\Sharing\\hello.exe"); 
			("C:\\WINDOWS\\Desktop\\Clean\\s.exe"); 
//	# exename				= linkopts.exe_path
//	# ocw					= linkopts.open_console
	# stat					= linkopts.static_link
	# static_libs			= StrictListToList linkopts.static_libs
	# (errors,platform_link_options,world)
		= default_platform_link_options linkopts world;
	# (state,world)
		= case (isEmpty errors) of 
			True
				// no errors	
				# (state,world) = accFiles (link_xcoff_files stat file_names library_file_names static_libs exename platform_link_options) world
				-> (state,world)
			False
				# linker_messages_state
					= setLinkerMessages errors DefaultLinkerMessages;
				-> ({ EmptyState & linker_messages_state = linker_messages_state },world);

	# (messages,state)
		= GetLinkerMessages state;		
			
	# (err,world) = accFiles (WriteLinkErrors errors_path [ toString m \\ m <- messages]) world
	
	#! (ok,state)
		= IsErrorOccured state;

		
	
	| ok && isNothing err
		=  world;
	
		#! world 
			= set_return_code (-1) world
		= F (p  [ toString m \\ m <- messages]) world;
where 		
	p []
		= "";
	p [x:xs]
		= x +++ "\n" +++ (p xs);
		
	// for a normal executable
	default_platform_link_options linkopts=:{dll_names,gen_dll,stack_size,open_console,gen_relocs,gen_linkmap,link_resources,res_path} world
		// console window
		# platform_link_options
			= plo_set_console_window open_console DefaultPlatformLinkOptions;
			
		// relocations and dll
		# (errors,platform_link_options,world)
			= set_dll_options gen_dll platform_link_options world;

		// link map
		# platform_link_options
			= plo_set_gen_linkmap gen_linkmap platform_link_options;
		
		// resources
		# platform_link_options
			= (plo_set_gen_resource link_resources res_path platform_link_options)

		// bug fix
		# platform_link_options
			= plo_set_c_stack_size (max stack_size 0x00010000) platform_link_options;		

		= (errors,platform_link_options,world);
	where 
		set_dll_options False platform_link_options world
			= ([],plo_set_gen_relocs gen_relocs platform_link_options,world);
		

		set_dll_options _ platform_link_options world
			// file name specified
			| dll_names == ""
				# error
					= LinkerError "No file containing exported DLL functions specified";
				= ([error],platform_link_options,world);
				
			// generate DLL
			#! (errors,exported_functions,world)
				= read_exported_entries world;
				
			#! platform_link_options
				= plo_set_base_va 0x80000000 platform_link_options;
			#! platform_link_options
				= plo_set_make_dll True platform_link_options;
			#! platform_link_options
				= plo_set_gen_relocs True platform_link_options;
			#! platform_link_options
				= plo_set_exported_symbols exported_functions platform_link_options;
			#! platform_link_options
				= plo_set_main_entry "_DllMain@12" platform_link_options;
			
				
/*
	default_platform_link_options2 ocw
		= { DefaultPlatformLinkOptions &
			open_console_window 	= ocw,
			base_va 			= ,
			make_dll			= True,
			relocations_needed	= True,
			exported_symbols 	= exported_symbols,
			main_entry			= "_DllMain@12"
		};
	
*/
			
			= (errors,platform_link_options,world);
			
		where
			read_exported_entries world
				// open exported functions file
				# (ok,file,world)
					= fopen dll_names FReadText world;
				| not ok
					#! msg
						= LinkerError ("file '" +++ dll_names +++ "' containing exported DLL functions could not be read");
					= ([msg],[],world);
					
				# (errors,exported_functions,file)
					= read_entries [] [] 1 file
					
				// close file
				# (_,world)
					= fclose file world;
					
				// sanity checks
				| isEmpty exported_functions
					#! msg
						= LinkerError ("file '" +++ dll_names +++ "' does not contain exported DLL functions");
					= ([msg],[],world);

				= (errors,exported_functions,world); 
			where
				read_entries efs errors line_n file
					# (end_of_file,file)
						= fend file;
					| end_of_file
						= (errors,efs,file)
						
					// read line
					# (line,file)
						= freadline file;
					#! (errors2,public_name,internal_name)
						= parse_line line;
	
					= read_entries (if (internal_name == "") efs [(public_name,internal_name):efs]) (errors ++ errors2) (inc line_n) file;
				where				
					parse_line line
						// syntax: 		public_name[=:internal name] garbage newline 
						//		   	|	internal_name
						//			|	newline
						// public_name,internal_name: sequence of alpha numeric characters including the
						// underscore. garbage is a sequence of characters.
						# (name_found,i)
							= CharIndexFunc line 0 (\c -> not (isAlphanum c || c == '_' ) );
						| not name_found
							= ([],"","");
							
						#! name
							= line % (0,i-1);
						| line.[i] == ':' && line.[inc i] == '='
							# (internal_name_found,j)
								= CharIndexFunc line (i + 2) (\c -> not (isAlphanum c || c == '_' ) );
							| i + 2 == j
								= ([LinkerError ("file '" +++ dll_names +++ "' expected internal name at line " +++ toString line_n)],"","");
								
							# internal_name
								= line % (i+2,j-1);
							= ([],name,internal_name);
							
						= ([],"",name);
/*
	// for a dll
	default_platform_link_options2 ocw
		= { DefaultPlatformLinkOptions &
			open_console_window 	= ocw,
			base_va 			= 0x80000000,
			make_dll			= True,
			relocations_needed	= True,
			exported_symbols 	= exported_symbols,
			main_entry			= "_DllMain@12"
		};
	
	// example dll's
	exported_symbols
		= [ Entry exported_symbol_f, Entry exported_symbol_g];
	exported_symbol_f
		= { EmptyExportEntry &
			label_name = "f",							// public name
			internal_name = InternalName "BOOL"			// internal name
		};
	exported_symbol_g
		= { EmptyExportEntry &
			label_name = "g",							// public name
			internal_name =InternalName "INT"			// internal name
		};
*/