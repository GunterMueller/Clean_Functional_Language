module checkdynamics

from StdReal import entier; // RWS marker

import StdEnv
import Directory
import DynID
from DynamicLinkerInterface import GetDynamicLinkerPath
import ExtString
from DynamicUtilities import ExtractPathFileAndExtension
import ExtArray
import StdDynamicLowLevelInterface
import md5
import write_log
import gc_state
import ArgEnv	
import utilities
import StdMaybe
import StdDynamic
import code from library "ClientChannel_library"
 	
//parse_command_line :: [String] !Options !*World -> (!Options,!*World)	
parse_command_line ["--help":_] options world
	= ({options & display_help = True},world)

parse_command_line ["--md5check":as] options world
	#! (args,additional_args_to_option)
		= fetch_additional_arguments as []
	#! options
		= foldSt set_md5_flags additional_args_to_option options
		with
			set_md5_flags "dynamics" options
				= { options & check_md5_system_dynamics = True }
			set_md5_flags "libraries" options
				= { options & check_md5_system_libraries = True }
			set_md5_flags arg options
				= abort ("unknown suboption '" +++ arg +++ "' for --md5check")
	= parse_command_line args options world

parse_command_line ["--delete-in-system-space":as] options world
	#! (args,additional_args_to_option)
		= fetch_additional_arguments as []
	#! options
		= foldSt set_delete_in_system_space_flags additional_args_to_option options
		with
			set_delete_in_system_space_flags "unused-libraries" options
				= { options & delete_unused_system_libraries = True }
			set_delete_in_system_space_flags "unused-dynamics" options
				= { options & delete_unused_system_dynamics = True }
			set_delete_in_system_space_flags "unused-files" options
				= { options & delete_unknown_files_in_system_folders = True }
			set_delete_in_system_space_flags arg options
				= abort ("unknown suboption '" +++ arg +++ "' for --delete-in-system-space")
	= parse_command_line args options world

parse_command_line ["--delete-unknown-files-in-system-space":as] options world
	#! options
		= { options & delete_unknown_files_in_system_folders = True }
	= parse_command_line as options world

parse_command_line ["--delete-dangling-references-in-user-space":as] options world
	#! (args,additional_args_to_option)
		= fetch_additional_arguments as []
	#! options
		= foldSt set_delete_dangling_references additional_args_to_option options
		with
			set_delete_dangling_references "dynamics" options
				= { options & delete_dangling_dynamics_references = True }
			set_delete_dangling_references "applications" options
				= { options & delete_dangling_application_references = True }
			set_delete_dangling_references arg options
				= abort ("unknown suboption '" +++ arg +++ "' for --delete-dangling-references-in-user-space")
	= parse_command_line args options world
	
parse_command_line ["--do-not-really-delete":as] options world
	#! options
		= { options & really_delete = False }
	= parse_command_line as options world
	
parse_command_line ["--output",file_name:as] options world
	#! options
		= { options & log_path_name_ext = Just file_name }
	= parse_command_line as options world

parse_command_line [] state=:{display_help} world
	= ({state & display_help = display_help},world)

parse_command_line [o:_] state=:{display_help} world
	= abort ("unknown option '" +++ o +++ "'")

fetch_additional_arguments [] additional_args
	= ([],reverse additional_args)
fetch_additional_arguments l=:[arg:args] additional_args
	| fst (starts "--" arg)
		= (l,reverse additional_args)		
		= fetch_additional_arguments args [arg:additional_args]

Start world	
	#! commandline
		= getCommandLine

	#! (options,world)
		= parse_command_line (tl [ arg \\ arg <-: commandline ]) initial_options world;
	| options.display_help
		#! help
			= [
				"Usage: checkdynamics ..."
			, 	"Checks the internal integrity of the dynamics system."
			,	""
			,	"--help"			
			,	"  This text."
			,	"--output <log_file_name>"		
			,	"  Place output in <folder>."
			,	"--md5check {dynamics,libraries}"
			,	"  Checks the system dynamics and/or libraries."
			,	"--delete-in-system-space {unused-libraries,unused-dynamics,unused-files}"
			,   "  Deletes unused files in system space."
			,	"--delete-unknown-files-in-system-space"
			,	"  Deletes unknown files in the system space."
			,	"--delete-dangling-references-in-user-space {dynamics,applications}"
			,	"  Deletes user dynamics and applications with dangling references in"
			,	"  system space."
			,	"--do-not-really-delete"
			,	"  Doesn't delete anything"
			,	""
			,	"Default behaviour:"
			,	"When provided with the appropriate options, files *are* deleted from the"
			,	"filesystem."
			,	""
			,	"Report bugs to <clean@cs.kun.nl>."
			,	""
			]
		= quit help world
	| isNothing options.log_path_name_ext
		# error
			= [ 
				"--output <log_file_name> expected"
			,	""
			]
		= quit error world

	#! (state,world)
		= analyze_dynamic_system options world
	#! world
		= write_log options state world
	= (stderr,world)
where
	quit lines world
		#! stderr
			= foldSt (\line stderr -> fwritec '\n' (fwrites line stderr)) lines stderr
		= (stderr,world)

		
analyze_dynamic_system options=:{check_md5_system_dynamics,check_md5_system_libraries} world
	// read list of roots
	#! root_path_file_ext = (GetDynamicLinkerPath+++"\\"+++"rootDir.txt")

	#! (ok,root_file,world)
		= fopen root_path_file_ext FReadText world
	| not ok
		= abort ("could not open '" +++ root_path_file_ext +++ "'")
	
	#! (root_paths,root_file)
		= read_root_lines root_file []
		with
			read_root_lines root_file roots
				#! (end_of_file,root_file)
					= fend root_file
				| end_of_file
					= (roots,root_file)
				
				#! (stripped_line,root_file)					
					= freadline_without_nl root_file
				= read_root_lines root_file (if (size stripped_line == 0) roots [stripped_line:roots])

				
	#! (_,world)
		= fclose root_file world	

	// what about subdirs specified?
	// must be absolute
	// dynamic linker may not be running other dynamic applications

	#! ((ok,root_p),world)
		= pd_StringToPath (hd (reverse root_paths)) world
	| not ok
		= abort "error";
		
	#! (user_state,world)
		= list_folder_contents root_p (initial_user_state,world)
		with
			list_folder_contents root_p=:(AbsolutePath name root) (s,world)
				#! ((dir_error,dir_entries),world)
					= getDirectoryContents root_p world
				| dir_error <> NoDirError
					= abort "error reading dir"
					
				#! (root_path,world)
					= pathToPD_String root_p world
					
				#! (s,world)
					= foldSt handle_dir_entry dir_entries (s,world)
					with
						handle_dir_entry {fileName,fileInfo={pi_fileInfo={isDirectory=True}}} (s,world)
							| fileName == "." || fileName == ".."
								= (s,world)
							= list_folder_contents (AbsolutePath name (root ++ [PathDown fileName])) (s,world)
						handle_dir_entry dir_entry=:{fileName} (s,world)
							#! (s,world)
								= process_dir_entry dir_entry (s,world)
							= (s,world)
						where
							process_dir_entry dir_entry=:{fileName} (s,world)
								| ends fileName ".dyn"
									#! user_dynamic_path_file_ext
										= root_path +++ "\\" +++ fileName

									#! (ok,user_dynamic_file,world)
										= fopen user_dynamic_path_file_ext FReadText world
									| not ok
										= abort ("cannot open '" +++ user_dynamic_path_file_ext +++ "'")
										
									#! (system_dynamic_id,user_dynamic_file)
										= freadline_without_nl user_dynamic_file
									 
									#! (_,world)
										= fclose user_dynamic_file world

									# user_dynamic
										= { initial_user_dynamic &
											ud_name				= fileName
										,	ud_path_name_ext	= user_dynamic_path_file_ext
										,	ud_system_id		= system_dynamic_id
										}
									= ({s & us_dynamics = [user_dynamic:s.us_dynamics]},world)									
								| ends fileName ".bat"
									// read batch file
									#! bat_path_file_ext
										= root_path +++ "\\" +++ fileName

									#! (ok,bat_file,world)
										= fopen bat_path_file_ext FReadText world
									| not ok
										= abort ("cannot open '" +++ bat_path_file_ext +++ "'")
										
									#! (line,bat_file) 
										= freadline bat_file
										
									# (_,world)
										= fclose bat_file world					
										
									// a dynamic application?
									#! (maybe_substring)
										= contains_substring "DynamicLinker" line
									| isNothing maybe_substring
										= (s,world)

									#! maybe_typ_lib_id
										= findAi determine_library_id (ParseCommandLine line)
										with
											determine_library_id _ arg
												// search for <md5>_<md5>.lib
												| size arg == 32 + 1 + 32 + 4 // <<- arg
													= Just (fst (ExtractPathFileAndExtension arg))
													= Nothing
									| isNothing maybe_typ_lib_id
										// malformed dynamic application; generate an error
										= (s,world)
										
									# typ_lib_id
										= fromJust maybe_typ_lib_id
										
									# dynamic_app
										= { initial_user_application &
											da_name				= fileName
										,	da_path_name_ext	= bat_path_file_ext
										,	da_library_id		= typ_lib_id
										}
									= ({s & us_applications = [dynamic_app:s.us_applications]},world)									
									
									= (s,world)								
				= (s,world)
				
	#! state
		= { initial_state &
			s_user_dynamics			= { ud \\ ud <- user_state.us_dynamics }
		,	s_user_applications		= { ua \\ ua <- user_state.us_applications }
		}
				
	// get info for {DS_LIBRARIES_DIR.DS_SYSTEM_DYNAMICS_DIR}
	#! dynamic_linker_path
		= GetDynamicLinkerPath;
		
	// get system libraries
	#! library_path
		= dynamic_linker_path +++ "\\" +++ DS_LIBRARIES_DIR;
	#! ((ok,library_p),world)
		= pd_StringToPath library_path world
	#! ((dir_error,dir_entries),world)
		= getDirectoryContents library_p world
	| not ok || dir_error <> NoDirError
		= abort ("error opening dir '" +++ library_path +++ "'")
		

	// filter garbage from system library folder	
	#! (system_libraries,non_system_libraries)
		= foldSt split (tl (tl dir_entries)) ([],[])
		with
			split {fileName} (system_libraries,non_system_libraries)
				| is_system_library fileName
					= ([fileName:system_libraries],non_system_libraries)
					= (system_libraries,[fileName:non_system_libraries])
			where
				is_system_library fileName
					# (fileName_without_ext,ext)
						= ExtractPathFileAndExtension fileName
					= size fileName_without_ext == (32 + 1 + 32) && (ext == EXTENSION_CODE_LIBRARY || ext == EXTENSION_TYPE_LIBRARY)
	#! state
		= { state & non_system_libraries = non_system_libraries }
					
	// input list: 1) only unique library files and 2) extension either .typ or .lib
	#! (system_libraries,world)
		= check_and_convert (sort system_libraries) [] world
		with
			check_and_convert [] accu world 
				= (accu,world)
			check_and_convert [fileName:xs] accu world
				#! (library_name,ext)
					= ExtractPathFileAndExtension fileName

				#! system_library
					= {
						l_id				= library_name
					,	l_used				= False
					,	l_passed_md5_check	= Nothing
					,	l_lib_ok			= True
					,	l_typ_ok			= True
					}
				| not (isEmpty xs)
					#! (library_name2,ext2)
						= ExtractPathFileAndExtension (hd xs)
					| library_name == library_name2
						// same libraries but different extensions, OK
						
						#! (system_library,world)
							= case check_md5_system_libraries of
								True
									#! (md5_lib,world)
										= getMd5DigestFromFile (library_path +++ "\\" +++ library_name +++ "." +++ EXTENSION_CODE_LIBRARY) world
									#! (md5_typ,world)
										= getMd5DigestFromFile (library_path +++ "\\" +++ library_name +++ "." +++ EXTENSION_TYPE_LIBRARY) world
									#! md5
										= md5_lib +++ "_" +++ md5_typ

									#! system_library
										= { system_library & l_passed_md5_check = Just (library_name == md5) }
									-> (system_library,world)
								_
									-> (system_library,world)
						= check_and_convert (tl xs) [system_library:accu] world
					
						= missing_system_library library_name ext system_library world
						
					= missing_system_library library_name ext system_library world
			where
				missing_system_library library_name EXTENSION_CODE_LIBRARY system_library world
					#! system_library
						= { system_library & l_typ_ok = False }
					= check_and_convert xs [system_library:accu] world
				missing_system_library library_name EXTENSION_TYPE_LIBRARY system_library world
					#! system_library
						= { system_library & l_lib_ok = False }
					= check_and_convert xs [system_library:accu] world
 				
	#! system_libraries
		= { system_library \\ system_library <- system_libraries }
						
	#! state
		= { state & system_libraries = system_libraries }
		
	// get system dynamics
	#! system_dynamics_path
		= dynamic_linker_path +++ "\\" +++ DS_SYSTEM_DYNAMICS_DIR;
	#! ((ok,system_dynamics_p),world)
		= pd_StringToPath system_dynamics_path world
	#! ((dir_error,dir_entries),world)
		= getDirectoryContents system_dynamics_p world
	| not ok || dir_error <> NoDirError
		= abort ("error opening dir '" +++ system_dynamics_path +++ "'")

	// filter garbage from system dynamics folder	
	#! (system_dynamics,non_system_dynamics,world)
		= foldSt split (tl (tl dir_entries)) ([],[],world)
		with
			split {fileName} (system_dynamics,non_system_dynamics,world)
				| is_system_dynamic fileName

					#! system_dynamic
						= { initial_system_dynamic & 
							sd_id 				= fst (ExtractPathFileAndExtension fileName)
						}
					#! (system_dynamic,world)
						= case check_md5_system_dynamics of
							True	
								#! (md5_fileName,world)
									= getMd5DigestFromFile (system_dynamics_path +++ "\\" +++ fileName) world
								#! system_dynamic
									= { system_dynamic &
										sd_passed_md5_check = Just (md5_fileName == fileName_without_ext)
									}		
								-> (system_dynamic,world)
							_
								-> (system_dynamic,world)
					= ([system_dynamic:system_dynamics],non_system_dynamics,world)
				
					= (system_dynamics,[fileName:non_system_dynamics],world)
			where
				is_system_dynamic fileName
					= size fileName_without_ext == 32 && ext == EXTENSION_SYSTEM_DYNAMIC
					
				(fileName_without_ext,ext)
					= ExtractPathFileAndExtension fileName

	#! state
		= { state & 
			system_dynamics = { system_dynamic \\ system_dynamic <- system_dynamics }
		,	non_system_dynamics = non_system_dynamics 
		}
	
	// reference count
	// 1. mark initial system libraries used by dynamic applications
	#! (user_applications,state)
		= get_user_applications state;

	#! (user_applications,state)
		= mapAeiauSt mark_library user_applications state
		with 
			mark_library da=:{da_name,da_library_id} ith_da user_applications state
				#! (maybe_system_library_index,state)
					= find_system_library da_library_id state
				| isNothing maybe_system_library_index
					// ERROR: dangling dynamic application
					#! user_applications
						= { user_applications & [ith_da].da_library_exists = False }
					= (user_applications,state)
					
					#! state
						= { state & system_libraries.[fromJust maybe_system_library_index].l_used = True}
					= (user_applications,state)

	#! state
		= { state & 
			s_user_applications	= user_applications
		}
			
	// 2. reference count from initial user dynamics
	#! (user_dynamics,state)
		= get_user_dynamics state
	
	#! (user_dynamics,(state,world))
		= mapAeiauSt ref_user_count user_dynamics (state,world)
		with 
			dangling_system_dynamic user_dynamics (state,world)
				// ERROR: dangling user dynamic
				= (False,user_dynamics,(state,world))
				
			ref_user_count ud=:{ud_name,ud_system_id} ith_ud user_dynamics (state,world)
				#! (ok,user_dynamics,(state,world))
					= ref_count ud_system_id user_dynamics (state,world)
				#! user_dynamics
					= case ok of
						True		-> user_dynamics
						_			->  { user_dynamics & [ith_ud].ud_system_exists = False }
				= (user_dynamics,(state,world))
					
			ref_count ud_system_id user_dynamics (state,world) 
				// check existence in fs and state
				#! ud_path_name_ext
					= (CONVERTED_ENCODED_DYNAMIC_FILE_NAME_INTO_PATH dynamic_linker_path ud_system_id) 
				#! (ok,dh,ud_file,world)
					= open_dynamic_as_binary ud_path_name_ext world
				| not ok
					// ERROR: read error
					= dangling_system_dynamic user_dynamics (state,world)
					
				#! (ok,{di_lazy_dynamics_a=system_dynamics,di_library_index_to_library_name=system_libraries},ud_file)
					= read_rts_info_from_dynamic dh ud_file

				#! (_,world)
					= close_dynamic_as_binary ud_file world
				| not ok
					// ERROR: unreadable system dynamic
					= dangling_system_dynamic user_dynamics (state,world)
					
				#! (maybe_system_dynamic_index,state)
					= find_system_dynamic ud_system_id state
				| isNothing maybe_system_dynamic_index
					// ERROR: unexistant in state
					= dangling_system_dynamic user_dynamics (state,world)

				// system dynamic exists 
			 	#! system_dynamic_index
			 		= fromJust maybe_system_dynamic_index
			 	
			 	#! (sd_count,state)
			 		= state!system_dynamics.[system_dynamic_index].sd_count;	
			 	#! state 
			 		= { state & system_dynamics.[system_dynamic_index].sd_count = inc sd_count}
			
				// mark system library used by the system dynamic
			 	#! (fail_list,state,world)
			 		= mapASt ref_count_system_library system_libraries ([],state,world)
			 		with
			 			ref_count_system_library system_library_id (fail_list,state,world)
							#! (maybe_system_library_index,state)
								= find_system_library system_library_id state
							| isNothing maybe_system_library_index
								= ([system_library_id:fail_list],state,world)	
								//= abort ("dangling ref to '" +++ system_library_id +++ "'")
			 				
							#! system_libraries
								= { state & system_libraries.[fromJust maybe_system_library_index].l_used = True}
							= (fail_list,state,world)

			 	#! state 
			 		= { state & system_dynamics.[system_dynamic_index].sd_unknown_libraries = { failing_lib_id \\ failing_lib_id <- fail_list} }

				#! (fail_list2,user_dynamics,state,world)
					= mapASt ref_count_system_dynamic system_dynamics ([],user_dynamics,state,world)
					with
						ref_count_system_dynamic system_dynamic_id (fail_list2,user_dynamics,state,world)
							#! (ok,user_dynamics,(state,world))
								= ref_count system_dynamic_id user_dynamics (state,world) 
							| not ok
								= ([system_dynamic_id:fail_list2],user_dynamics,state,world)
								= (fail_list2,user_dynamics,state,world)
							
			 	#! state 
			 		= { state & system_dynamics.[system_dynamic_index].sd_unknown_system_dynamics = { failing_lib_id \\ failing_lib_id <- fail_list2} }
			 	= (True,user_dynamics,(state,world))
		
	#! state
		= { state & 
			s_user_dynamics		= user_dynamics
		}
	= (state,world) 
	
	
freadline_without_nl root_file
	#! (line,root_file)
		= freadline root_file
	#! s_line 
		= size line
	| s_line == 0
		= (line,root_file)
		
	#! last_index 
		= dec (s_line)
	#! stripped_line
		= if (line.[last_index] == '\n') (line % (0, dec last_index)) line
	= (stripped_line,root_file)
	
get_system_libraries state=:{system_libraries}
	= (system_libraries,{state & system_libraries = {}})

get_system_dynamics state=:{system_dynamics}
	= (system_dynamics,{state & system_dynamics = {}})


get_user_applications state=:{s_user_applications}
	= (s_user_applications,{state & s_user_applications = {}})

// get_user_dynamics
get_user_dynamics state=:{s_user_dynamics}
	= (s_user_dynamics,{state & s_user_dynamics = {}})

find_system_library da_library_id state
	#! (system_libraries,state)
		= get_system_libraries state
		
	#! (maybe_system_library_index,system_libraries)
		= findAieu find_system_library_ system_libraries
		
	#! state
		= { state & system_libraries = system_libraries }
	= (maybe_system_library_index,state)
where
	find_system_library_ i {l_id}
		| l_id == da_library_id
			= Just i
			= Nothing
			
find_system_dynamic :: !String !*State -> (Maybe Int,!*State)
find_system_dynamic system_dynamic_id state
	#! (system_dynamics,state)
		= get_system_dynamics state
		
	#! (maybe_system_dynamic_index,system_dynamics)
		= findAieu find_system_dynamic_ system_dynamics
		
	#! state
		= { state & system_dynamics = system_dynamics }
	= (maybe_system_dynamic_index,state)
where
	find_system_dynamic_ i {sd_id}
		| system_dynamic_id == sd_id
			= Just i
			= Nothing


// from pdRequest...
ParseCommandLine :: !String -> {#{#Char}}
ParseCommandLine s
	# command_line
		= parse_command_line s 0 []
	# command_line
		= [hd command_line:tl command_line]
	= { s \\ s <- command_line }
where 
	parse_command_line :: String Int [{#Char}] -> [{#Char}]
	parse_command_line s i l
		| i == (size s)
			= l
			
			| (s.[i] <> '\"')
				// not found, no " then search for space
				#! (_,index)
					= CharIndex s i ' '
				= parse_command_line s (skip_spaces s index) (l ++ [s % (i,index-1)])
				
		
				#! (found,index)
					= CharIndex s (i+1) '\"'
				| found
					= parse_command_line s (skip_spaces s (index+1)) (l ++ [s % (i+1,index-1)])
					
					= abort "parse_command_line: an error"
	skip_spaces :: String Int -> Int
	skip_spaces s i
		| (size s) == i
			= size s
			| s.[i] == ' '
				= skip_spaces s (inc i)
				= i
// ... from pdRequest