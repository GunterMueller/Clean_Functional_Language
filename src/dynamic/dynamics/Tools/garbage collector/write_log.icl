implementation module write_log

import gc_state
import ExtArray
import Directory
import DynID
import StdEnv
import StdMaybe

:: Options
	= {
		// check options
		check_md5_system_dynamics					:: !Bool
	,	check_md5_system_libraries					:: !Bool
	
		// delete options (System)
	,	delete_unused_system_libraries 				:: !Bool
	,	delete_unused_system_dynamics				:: !Bool
	
	,	delete_unknown_files_in_system_folders		:: !Bool
	
		// delete options (User)
	,	delete_dangling_application_references		:: !Bool
	,	delete_dangling_dynamics_references			:: !Bool

		// really delete		
	,	really_delete								:: !Bool
			
		// log 
	,	log_path_name_ext							:: !Maybe String

	,	display_help								:: !Bool
	}	

initial_options :: Options	
initial_options
 	#! options
		= {
		// check options
			check_md5_system_dynamics					= False
		, 	check_md5_system_libraries					= False

		// delete options
		,	delete_unused_system_libraries 				= False
		,	delete_unused_system_dynamics				= False

		, 	delete_unknown_files_in_system_folders		= False		
		
		// delete options (User)
		,	delete_dangling_application_references		= False
		,	delete_dangling_dynamics_references			= False
		
		// really delete
		,	really_delete								= True
		
		,	log_path_name_ext							= Nothing
		
		,	display_help								= False
		}
	= options

	
write_log :: .Options !*State *a -> *a | FileSystem a
write_log options=:{log_path_name_ext} state=:{dynamic_linker_path} world
	#! (ok,output,world)
		= fopen (fromJust log_path_name_ext) FWriteText world;
	| not ok
		= abort "could not open file for writing"
		
		
	#! output
		= fwrites "CheckDynamics\n" output
	#! output
		= fwrites "-------------\n\n" output

	// libraries	
	#! output
		= fwrites "System libraries:\n\n" output	
	#! (output,world)
		= case (size state.system_libraries == 0) of
			True	
				-> (fwrites "No system libraries.\n" output,world)
			_
				#! (output,world)
					= mapASt print state.system_libraries (output,world)
					with
						print {l_id,l_used,l_lib_ok,l_typ_ok,l_passed_md5_check} (output,world)
							// Deletion ...
							#! (action,world)
								= case (not l_used && options.delete_unused_system_libraries) of
									True
										#! library_path
											= dynamic_linker_path +++ "\\" +++ DS_LIBRARIES_DIR;
										#! library_without_extension
											= library_path +++ "\\" +++ l_id
			
										// remove .lib						
										#! world
											= remove_library l_lib_ok library_without_extension EXTENSION_CODE_LIBRARY world			
			
										// remove .typ
										#! world
											= remove_library l_typ_ok library_without_extension EXTENSION_TYPE_LIBRARY world			
										-> ("DELETED",world)
									False
										-> ("",world)
							// ... Deletion
						
							// Output ...
							#! msg
								= l_id +++ " - " +++ (if l_used "USED" "UNUSED") +++ " "
							#! msg
								= if l_lib_ok msg (msg +++ "." +++ EXTENSION_CODE_LIBRARY +++ " Missing ")
							#! msg
								= if l_typ_ok msg (msg +++ "." +++ EXTENSION_TYPE_LIBRARY +++ " Missing ")
								
							#! msg 
								= msg +++ (if (isNothing l_passed_md5_check) "" (if (fromJust l_passed_md5_check) ", MD5 OK" ", MD5 FAILED"))
								
							#! output
								= fwrites (msg +++ " " +++ action +++ "\n") output	
							// ... Output
							= (output,world)
						where
							remove_library False library_without_extension extension world
								= world
							remove_library _ library_without_extension extension world
								#! l = (library_without_extension +++ "." +++ extension)
								#! ((ok,library_p),world)
									= pd_StringToPath l world
								| not ok
									= abort ("internal error; removing '" +++ l_id +++ "'")
									
								#! (_,world)
									= fremove_ options.really_delete library_p world
								= world
				-> (output,world)
						
	// non-system libraries
	#! output
		= fwrites "\n\nNon-system libraries:\n\n" output	
	#! (output,world)
		= case (isEmpty state.non_system_libraries ) of
			True	
				-> (fwrites "No non-system libraries.\n" output,world)
			_		
				#! (output,world)
					= foldSt print state.non_system_libraries (output,world)
					with
						print file_name (output,world)
							// Deletion ...
							#! (action,world)
								= case options.delete_unknown_files_in_system_folders of
									True
										#! library_path
											= dynamic_linker_path +++ "\\" +++ DS_LIBRARIES_DIR;
										#! non_system_library
											= library_path +++ "\\" +++ file_name
			
										#! (_,world)
											= fremove_path non_system_library options world
										
										-> ("DELETED",world)
									False
										-> ("",world)
							// ... Deletion
							
							// Output ...	
							#! output
								= fwrites (file_name +++ " " +++ action +++ "\n") output	
							// ... Output
							= (output,world)
				-> (output,world)
				
	// system dynamics
	#! system_dynamics_path
		= dynamic_linker_path +++ "\\" +++ DS_SYSTEM_DYNAMICS_DIR;

	#! output
		= fwrites "\n\nSystem dynamics:\n\n" output	
	#! (output,world)
		= case (size state.system_dynamics == 0) of
			True	
				-> (fwrites "No system dynamics.\n" output,world)
			_
				#! (output,world)
					= mapASt print state.system_dynamics (output,world)
					with
						print {sd_id,sd_count,sd_unknown_libraries,sd_unknown_system_dynamics,sd_passed_md5_check} (output,world)
							// Deletion ...
							#! (action,world)
								= case (sd_count == 0 && options.delete_unknown_files_in_system_folders) of
									True
										#! file_name
											= system_dynamics_path +++ "\\" +++ sd_id +++ "." +++ EXTENSION_SYSTEM_DYNAMIC
			
										#! (_,world)
											= fremove_path file_name options world
										
										-> ("DELETED",world)
									False
										-> ("",world)
							// ... Deletion
			
							// Output ...
							#! msg
								= sd_id +++ " - " +++ toString sd_count +++ 
								 (if (isNothing sd_passed_md5_check) "" (if (fromJust sd_passed_md5_check) ", MD5 OK" ", MD5 FAILED")) +++ " " +++ action +++ "\n"
							#! output
								= fwrites msg output
								
							#! output
								= output_missing_system_dynamics_or_libraries "system libraries" sd_unknown_libraries output
							#! output
								= output_missing_system_dynamics_or_libraries "system dynamics" sd_unknown_system_dynamics output
							// ... Output
							= (output,world)
						where
							output_missing_system_dynamics_or_libraries title sd_unknown output
								#! output
									= case (size sd_unknown) of
										0
											-> output
										_
											#! output
												= fwrites ("Missing " +++ title +++ ":\n") output
											#! output 
												= mapASt foo sd_unknown output
												with
													foo unknown output
														= fwrites ("\t" +++ unknown +++ "\n") output
											-> output
								= output
				-> (output,world)

	// non-system dynamics
	#! output
		= fwrites "\n\nNon-system dynamics:\n\n" output	
	#! (output,world)
		= case (isEmpty state.non_system_dynamics) of
			True	
				-> (fwrites "No non-system dynamics.\n" output,world)
			_
				#! (output,world)
					= foldSt print state.non_system_dynamics (output,world)
					with
						print file_name (output,world)
							// Deletion ...
							#! (action,world)
								= case (options.delete_unknown_files_in_system_folders) of
									True
										#! file_name_new
											= system_dynamics_path +++ "\\" +++ file_name
			
										#! (_,world)
											= fremove_path file_name_new options world
										
										-> ("DELETED",world)
									False
										-> ("",world)
							// ... Deletion
			
							// Output ...
							#! output
								= fwrites (file_name +++ " " +++ action +++ "\n") output	
							// ... Output
							= (output,world)
				-> (output,world)
				
	// dynamic applications
	#! output
		= fwrites "\n\nDynamic applications:\n\n" output	
	#! (output,world)
		= case (size state.s_user_applications == 0) of
			True	
				-> (fwrites "No dynamic applications.\n" output,world)
			_
				#! (output,world)
					= mapASt print state.s_user_applications (output,world)
					with
						print {da_name,da_path_name_ext,da_library_id,da_library_exists} (output,world)
							// Deletion ...
							#! (action,world)
								= case (options.delete_dangling_application_references && not da_library_exists) of
									True
										#! (_,world)
											= fremove_path da_path_name_ext options world
										-> ("DELETED",world)
									False
										-> ("",world)
							// ... Deletion
							#! msg
								= da_name +++ " - " +++ da_library_id +++ " " +++
									(if da_library_exists "OK" "Dangling") +++ " " +++ action +++ "\n"
							#! output
								= fwrites msg output
							= (output,world)
				-> (output,world)
				
	// user dynamics
	#! output
		= fwrites "\n\nUser dynamics:\n\n" output	
	#! (output,world)
		= case (size state.s_user_dynamics == 0) of
			True	
				-> (fwrites "No user dynamics.\n" output,world)
			_
				#! (output,world)
					= mapASt print state.s_user_dynamics (output,world)
						with
							print {ud_name,ud_system_id,ud_system_exists,ud_path_name_ext} (output,world)
								// Deletion ...
								#! (action,world)
									= case (options.delete_dangling_dynamics_references && not ud_system_exists) of
										True
											#! (_,world)
												= fremove_path ud_path_name_ext options world
											-> ("DELETED",world)
										False
											-> ("",world)
								// ... Deletion
				
								// Output ...
								#! msg
									= ud_name +++ " - " +++ ud_system_id +++ " " +++
										(if ud_system_exists "OK" "Dangling") +++ " " +++ action +++ "\n"
								#! output
									= fwrites msg output
								// ... Output
								= (output,world)
				-> (output,world)
	#! (_,world)
		= fclose output world		
	= world

// AUXILLARY FUNCTIONS
// ----------------------------------------------------------------------------------

fremove_path path_name_ext options world
	#! ((ok,path_name_ext_p),world)
		= pd_StringToPath path_name_ext world
	| not ok
		= abort ("internal error; removing '" +++ path_name_ext +++ "'")
		= fremove_ options.really_delete path_name_ext_p world

fremove_ True p world	= fremove p world
fremove_ _    p world	= (NoDirError,world)

// foldSt :: !(.a -> .(.st -> .st)) ![.a] !.st -> .st
foldSt op l st :== fold_st l st
	where
		fold_st [] st		= st
		fold_st [a:x] st	= fold_st x (op a st)
