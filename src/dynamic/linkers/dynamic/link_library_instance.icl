implementation module link_library_instance;

import StdMaybe;
import dus_label, ObjectToMem, pdObjectToMem;
from SearchObject import add_modules2, add_library2;
import lib, ReadObject;
from DynID import ADD_TYPE_LIBRARY_EXTENSION,ADD_CODE_LIBRARY_EXTENSION;
import ExtFile, utilities;
import Directory, StdDynamicTypes;
import type_io_read, typetable;
import LibraryInstance, State;
import StdDynamicLowLevelInterface, UnknownModuleOrSymbol;
import ExtArray, NamesTable, LinkerMessages, Redirections;
from pdSymbolTable import :: LibraryList(..);
from TypeEquivalences import :: TypeEquivalences, :: Replacement{frm,to}, addTypeEquivalences, getTypeEquivalences;
from pdSortSymbols import sort_modules;

// from predef import UnderscoreSystemDynamicModule_String, DynamicRepresentation_String;
// FIXME: move this to a module that's shared by the compiler and the linker
UnderscoreSystemDynamicModule_String	:== "_SystemDynamic";	
DynamicRepresentation_String			:== "DynamicTemp"; // "_DynamicTemp"		

initialize_library_instance :: Int !*DLClientState *f -> (!Bool,!*DLClientState,!*f) | FileEnv f;
initialize_library_instance library_instance_i dl_client_state io
	| dl_client_state.cs_library_instances.lis_library_instances.[library_instance_i].li_library_initialized
		= (False,dl_client_state,io);	

	# msg = "begin initialize_library_instance " +++ toString library_instance_i;
	# dl_client_state = AddDebugMessage msg dl_client_state;

	# (li_library_name,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_library_name;
	# (type_table_i,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
	# (state,dl_client_state)
		= get_state dl_client_state;

	# (Just main_library_instance_i,dl_client_state) = dl_client_state!cs_main_library_instance_i;
	# (do_dump_dynamic,dl_client_state) = dl_client_state!do_dump_dynamic;

	# (share_runtime_system,dl_client_state) = dl_client_state!cs_share_runtime_system;
	# dl_client_state = { dl_client_state & cs_share_runtime_system = True };
	# dl_client_state
		= case share_runtime_system of {
			False
				-> { dl_client_state & cs_main_library_instance_i = Just library_instance_i };
			_
				-> dl_client_state;
		};

	// load library
	# ({rti_n_libraries=n_libraries,rti_n_library_symbols=n_library_symbols,rti_library_list=library_list},dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_rti;

	// mark library instance i as initialized
	#! dl_client_state = { dl_client_state & cs_library_instances.lis_library_instances.[library_instance_i].li_library_initialized = True };

	#! (n_old_libraries,state) = state!n_libraries;
	#  first_library_n = ~(n_libraries + n_old_libraries);
	// import DLL symbols
	#! (symbol_n,library_n,names_table)
		= ImportDynamicLibrarySymbols library_list 0 first_library_n create_names_table;
	| symbol_n <> n_library_symbols || library_n <> (~n_old_libraries)
		= abort "LoadCodeLibraryInstance: internal error; .typ-file corrupt";
	
	// LibraryList
	#! state = add_library2 n_libraries n_library_symbols library_list state;

	# (all_libraries,dl_client_state) = dl_client_state!cs_library_instances.lis_all_libraries;
	# all_libraries = Libraries library_list all_libraries;
	#! dl_client_state = {dl_client_state & cs_library_instances.lis_all_libraries=all_libraries};
	
	// load code library *without* run-time system which is shared with the main library
	// instance.
	# (do_dump_dynamic,dl_client_state) = dl_client_state!do_dump_dynamic;

	# (rs,dl_client_state)
		= case share_runtime_system of {
			False
				-> (default_redirection_state,dl_client_state);
			_
				# (cs_main_library_instance_i,dl_client_state) = dl_client_state!cs_main_library_instance_i;
				# main_library_instance_i = fromJust cs_main_library_instance_i;

				# library_name = (snd (ExtractPathAndFile li_library_name));
				# library_name = "_" +++ (library_name % (0,size library_name - 2))   +++ "_options.o";
				# rts_objects
					= ["_startup0.o",library_name,"_startup1.o","_startup2.o","_startup1Profile.o","_startup1Trace.o","_system.o"];
				#! (names_table,dl_client_state)
					= acc_names_table main_library_instance_i dl_client_state;					

				# rs
					= { default_redirection_state &
					 	rs_main_names_table		= names_table
					,	rs_rts_modules			= rts_objects
					};
				-> (rs,dl_client_state);
		};
	
	# (n_xcoff_files,state) = state!n_xcoff_files;
	# code_lib_name = ADD_CODE_LIBRARY_EXTENSION li_library_name;
	# (s_names_table,names_table) = usize names_table;
	# ((errors, xcoff_l, names_table, rs),io)
//		= accFiles (read_code_library2 n_xcoff_files code_lib_name names_table rs) io;
		= accFiles (read_object_files_in_library n_xcoff_files code_lib_name names_table rs) io;

	// restore name table
	# dl_client_state
		= case share_runtime_system of {
			False
				-> dl_client_state;
			_
				# (cs_main_library_instance_i,dl_client_state) = dl_client_state!cs_main_library_instance_i;
				# main_library_instance_i = fromJust cs_main_library_instance_i;
				-> {dl_client_state & cs_library_instances.lis_library_instances.[main_library_instance_i].li_names_table = rs.rs_main_names_table};
		};

	#! state = { state & namestable = names_table};

	// add_module
	#! state = add_modules2 xcoff_l state;

	// ------------------------
	// A lazy dynamic is marked by a BUILD_BLOCK_LABEL or a BUILD_LAZY_BLOCK_LABEL. Each library also defines these
	// two labels. Without precautions, these copies would also be put in the image, making the conversion routines
	// much more complex. Therefore the copy of the main library instance is taken and references of other library
	// instance are redirected to those of the main library instance.
	// backup namestable from state
	#! (names_table,state) = select_namestable state;
	#! dl_client_state
		= { dl_client_state &
			cs_library_instances.lis_library_instances.[library_instance_i].li_names_table = names_table
		};
		
	#! (state,dl_client_state)
		= case share_runtime_system of {
			False
				-> (state,dl_client_state);
			True
				// backup state
				#! dl_client_state = { dl_client_state & app_linker_state = state };
					
				// replace BUILD_BLOCK_LABEL
				#! (Just main_library_instance_i,dl_client_state)
					= dl_client_state!cs_main_library_instance_i;
				#! (Just (build_block_file_n,build_block_symbol_n),dl_client_state)
					= findLabel BUILD_BLOCK_LABEL main_library_instance_i dl_client_state;

				// replace BUILD_LAZY_BLOCK_LABEL
				#! (Just (build_lazy_block_file_n,build_lazy_block_symbol_n),dl_client_state)
					= findLabel BUILD_LAZY_BLOCK_LABEL main_library_instance_i dl_client_state;

				#! dl_client_state
					= case (do_dump_dynamic) of {
						True 
							-> dl_client_state;
						_
							#! dl_client_state
								= replaceLabel BUILD_BLOCK_LABEL library_instance_i build_block_file_n build_block_symbol_n BUILD_BLOCK_LABEL dl_client_state;
							#! dl_client_state
								= replaceLabel BUILD_LAZY_BLOCK_LABEL library_instance_i build_lazy_block_file_n build_lazy_block_symbol_n BUILD_LAZY_BLOCK_LABEL dl_client_state;
							-> dl_client_state;
					};
				
				// extract state
				-> acc_state (\state -> (state,EmptyState)) dl_client_state;
		};

	// restore namestable in state
	#! dl_client_state
	 = { dl_client_state &
	 		app_linker_state	= state
	 	,	cs_library_instances.lis_library_instances.[library_instance_i].li_library_list = library_list
	 };
	= (share_runtime_system,dl_client_state,io);
where {
	read_code_library2 :: !Int !{#Char} !*{!NamesTableElement} !*RedirectionState !*Files
		   -> *(!*([{#Char}],!*[*Xcoff],!*{!NamesTableElement},!*RedirectionState),!*Files);
	read_code_library2 file_n code_lib_name names_table rs files 
		#! ((ok,code_lib_name_p),files)
			= pd_StringToPath code_lib_name files;
		#! ((dir_error,_),files)
			= getFileInfo code_lib_name_p files;
		| not ok || dir_error <> NoDirError
			= abort ("Error opening library file '" +++ code_lib_name +++ "'");

		# (errors, xcoff_l, _, names_table, file_n, files,_,rs)
			= read_static_lib_files [code_lib_name] [] names_table file_n [] files default_rsl_state rs;
		= ((errors, xcoff_l, names_table, rs), files);

	read_object_files_in_library :: !Int !{#Char} !*{!NamesTableElement} !*RedirectionState  !*Files
					  -> (!(![{#Char}],!*[*Xcoff],!*{!NamesTableElement},!*RedirectionState),!*Files);
	read_object_files_in_library file_n lib_file_name names_table rs files
		# (ok,lib_file,files) = fopen lib_file_name FReadText files;
		| not ok
			= abort ("Error opening library file '"+++lib_file_name+++"'");
		# (object_file_names,lib_file) = read_object_file_names lib_file;
		# (ok,files) = fclose lib_file files;
		| not ok
			= abort ("Error reading library file '"+++lib_file_name+++"'");
		# (libraries_path,_) = ExtractPathAndFile lib_file_name;
		  (dynamics_path,_) = ExtractPathAndFile libraries_path;
		  modules_path = dynamics_path+++"\\modules\\";
		# (objects,names_table,rs,files)
			= read_object_files object_file_names modules_path file_n lib_file_name names_table rs files;
		= (([],objects,names_table,rs),files);
	where {
		read_object_file_names :: !*File -> (![{#Char}],!*File);
		read_object_file_names lib_file
			# (line,lib_file) = freadline lib_file;
			# s=size line;
			| s==0
				= ([],lib_file);
			| line.[s-1]=='\n'
				# (lines,lib_file) = read_object_file_names lib_file;
				= ([line % (0,s-2):lines],lib_file);
				= ([line],lib_file);

		read_object_files :: ![{#Char}] !{#Char} !Int !{#Char} !*{!NamesTableElement} !*RedirectionState !*Files
												 -> *([*Xcoff],!*{!NamesTableElement},!*RedirectionState,!*Files);
		read_object_files [object_file_name:object_file_names] modules_path file_n lib_file_name names_table rs files
			# object_file_name = modules_path+++object_file_name;
			# (ok,object_file,files) = fopen object_file_name FReadData files;
			| not ok
				= abort ("Error opening object file '"+++object_file_name+++"'");
			# module_name = md5_module_name_to_object_name object_file_name;
			#! (any_extra_sections,_,_,_,object,names_table,object_file,rs)
				= read_xcoff_fileI module_name object_file_name 0 names_table True object_file file_n rs;
			# (ok,files) = fclose object_file files;
			| not ok
				= abort ("Error reading object file '"+++object_file_name+++"'");
			| any_extra_sections
				= abort ("read_xcoff_fileI: extra sections not yet implemented (in file "+++object_file_name+++")");
			| rs.RedirectionState.rs_change_rts_label
				# rs = {rs & rs_change_rts_label = False};
				= read_object_files object_file_names modules_path file_n lib_file_name names_table rs files
				# file_n = file_n+1;
				  object = sort_modules object;
				# (objects,names_table,rs,files)
					= read_object_files object_file_names modules_path file_n lib_file_name names_table rs files
				= ([object:objects],names_table,rs,files);
		read_object_files [] modules_path file_n lib_file_name names_table rs files
			= ([],names_table,rs,files);

		md5_module_name_to_object_name md5_module_name
			# i = find_last_backslash_index (size md5_module_name-1) md5_module_name;
			= snd (ExtractPathAndFile (md5_module_name % (0,i-1)+++".o"));
		
		find_last_backslash_index :: !Int !{#Char} -> Int;
		find_last_backslash_index i s
			| s.[i]=='\\'
				= i;
			| i>0
				= find_last_backslash_index (i-1) s;
				= abort ("Error in module name "+++s);
	}
}

// loads both the code library assumes type table has already been loaded. The redirections to be made are derived from the 
// type table and imposed on the code.
load_code_library_instance :: (Maybe [.DusLabel]) !.Int !*DLClientState !*f -> (!Int,[Int],!*DLClientState,!*f) | FileEnv f;
load_code_library_instance (Just []) library_instance_i dl_client_state io
	= (0,[],dl_client_state,io);
load_code_library_instance non_main_library library_instance_i dl_client_state io
	#! (_,dl_client_state,io)
		= initialize_library_instance library_instance_i dl_client_state io;
/*	RWS ...
*/
	# cs_type_equivalences = dl_client_state.cs_type_equivalences
	# (replacements, cs_type_equivalences)
		=	getTypeEquivalences library_instance_i cs_type_equivalences
	# dl_client_state = {dl_client_state & cs_type_equivalences = cs_type_equivalences}
	# (labels_list, dl_client_state)
		=	mapSt (replace library_instance_i) replacements dl_client_state;
		with {
			replace current {frm, to} st
				// only replace within the library here
				| current_library to current
					=	redirect_type_implementation_equivalent_class to [frm] st
					=	([], st);

			current_library (LIT_TypeReference (LibRef lib) _) current
				=	lib == current;
		}
	# labels_implementing_partitions
		=	foldr (++) [] labels_list
// ... RWS
	#! (library_list,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_library_list;

	#! dl_client_state = { dl_client_state & app_linker_state.library_list = library_list };

	#! (names_table,dl_client_state) = acc_names_table library_instance_i dl_client_state;
	#! (state,dl_client_state) = acc_state (\s -> (s,EmptyState)) dl_client_state;
	#! state = { state & namestable = names_table, library_list = library_list };

	#! (main_symbols,dl_client_state)
		= case non_main_library of {
			Nothing
				#! main_symbol = sel_platform "_mainCRTStartup" "main";
				#! main_symbols
					= [SymbolUnknown  "" main_symbol, SymbolUnknown "" BUILD_BLOCK_LABEL, SymbolUnknown "" BUILD_LAZY_BLOCK_LABEL];
				-> (main_symbols,dl_client_state);
			Just dus_labels
				// exclude label which already have been linked by other library instances
				#! labels = [SymbolUnknown "" dusl_label_name \\ {dusl_label_name,dusl_linked} <- dus_labels | not dusl_linked];
				-> (labels,dl_client_state);
		};
	#! main_symbols
		= main_symbols ++ [ SymbolUnknown "" label \\ label <- labels_implementing_partitions ];

	/*
	** The preliminary temp solution above ensures that the RunTimeID-constructor is allocated into
	** library space and not lazily allocated in space for the graph_to_string-conversion function
	** which is not a library instance and therefore not included in the table which is sent to the
	** application and contains start/end addresses for each library instance. 
	** In the future the RunTimeID constructor of the context library should be used.
	*/

	# (all_libraries,dl_client_state) = dl_client_state!cs_library_instances.lis_all_libraries;

	#! ((wii,p=:[start_addr:_],state,dl_client_state),io)
		= LinkUnknownSymbols main_symbols state library_instance_i all_libraries dl_client_state io;
	
	// LibraryList
	#! (names_table,state) = select_namestable state;
	#! (library_list,state) = state!library_list;

	#! dl_client_state
		= case wii of {
			Nothing
				-> dl_client_state;
			Just {wii_code_start,wii_code_end,wii_data_start,wii_data_end}
				#! (li_memory_areas,dl_client_state)
					= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_memory_areas;
				#! li_memory_areas
/* RWS ...
					= [{ma_begin=wii_data_start,ma_end=wii_data_end},{ma_begin=wii_code_start,ma_end=wii_code_end}:li_memory_areas];
	For some reason I don't understand a lot of {0..0} areas area added here,
	so let's just ignore those.
*/
					=	add_memory_area wii_data_start wii_data_end
							(add_memory_area wii_code_start wii_code_end li_memory_areas);
					with {
						add_memory_area start end list
							| start == 0 && end == 0
								=	list;
							// otherwise
								=	[{ma_begin=start,ma_end=end} : list];
					}
// ... RWS
				-> { dl_client_state &
						cs_library_instances.lis_library_instances.[library_instance_i].li_memory_areas = li_memory_areas
					};
		};

	// update
	#! dl_client_state 
		= {  dl_client_state &
			cs_library_instances.lis_library_instances.[library_instance_i].li_library_initialized = True
		,	cs_library_instances.lis_library_instances.[library_instance_i].li_library_list = library_list
		,	cs_library_instances.lis_library_instances.[library_instance_i].li_names_table = names_table
		,	app_linker_state = state
		}
	= (start_addr,p,dl_client_state,io);

replaceType :: !.LibraryInstanceTypeReference ![.LibraryInstanceTypeReference] !*DLClientState -> *DLClientState;
replaceType implemented_type type_implementations_to_redirect dl_client_state
	= snd (redirect_type_implementation_equivalent_class implemented_type type_implementations_to_redirect dl_client_state);

redirect_type_implementation_equivalent_class :: !.LibraryInstanceTypeReference ![.LibraryInstanceTypeReference] !*DLClientState
	-> ([{#Char}], *DLClientState);
redirect_type_implementation_equivalent_class (LIT_TypeReference (LibRef chosen_library_instance_i) chosen_tio_type_reference) type_implementations_to_redirect dl_client_state
	// get label names which implementent the chosen type implementation
	#! (li_chosen_type_table_i,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[chosen_library_instance_i].li_type_table_i;
	#! (chosen_type_name,_,label_strings_implementing_chosen_type,dl_client_state)
		= get_type_label_names chosen_tio_type_reference li_chosen_type_table_i  dl_client_state;
	#! (labels_implementing_chosen_type,dl_client_state)
		= mapSt (lookup_file_n_symbol_n_for_each_label chosen_library_instance_i) label_strings_implementing_chosen_type dl_client_state;

	// get labels for type_implementations_to_redirect
	#! (_,dl_client_state)
		= foldSt (redirect_type chosen_library_instance_i) type_implementations_to_redirect (labels_implementing_chosen_type,dl_client_state);
	= (label_strings_implementing_chosen_type, dl_client_state);
where {
	lookup_file_n_symbol_n_for_each_label chosen_library_instance_i type_label_name dl_client_state
		#! (maybe_file_n_symbol_n,dl_client_state)
			= findLabel type_label_name chosen_library_instance_i dl_client_state;
		| isNothing maybe_file_n_symbol_n
			= abort ("lookup_file_n_symbol_n_for_each_label; internal error in " +++ type_label_name);
		#! (file_n,symbol_n)
			= fromJust maybe_file_n_symbol_n;
		= ((file_n,symbol_n,type_label_name),dl_client_state);
};

redirect_type chosen_library_instance_i (LIT_TypeReference (LibRef library_instance_i) tio_type_reference) (labels_implementing_chosen_type,dl_client_state)
	#! (li_type_table_i,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
	#! (_,_,labels_implementing_type,dl_client_state)
		= get_type_label_names tio_type_reference li_type_table_i  dl_client_state;
		
	#! dl_client_state
		= fold2St redirect_type_label labels_implementing_type labels_implementing_chosen_type dl_client_state;
	= (labels_implementing_chosen_type,dl_client_state);
where {
	redirect_type_label refering_label chosen_label=:(file_n,symbol_n,chosen_label_name) dl_client_state
		= replaceLabel refering_label library_instance_i file_n symbol_n chosen_label_name dl_client_state;
};
redirect_type chosen_library_instance_i _ s
	= s;

LoadTypeTable :: !Int !Int *DLClientState *a -> *(*DLClientState,*a) | FileEnv a;
LoadTypeTable library_instance_i type_table_i dl_client_state io
	# (tt_loaded,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_loaded;
	| tt_loaded
		= (dl_client_state,io);

		// load type table
		# (tt_name,dl_client_state) = dl_client_state!cs_type_tables.[type_table_i].tt_name;
		# ((ok,rti,tio_common_defs,type_io_state,_),io)
			= accFiles (read_type_library_new False tt_name) io;
		| not ok
			# msg = "Loaded type table " +++ toString type_table_i +++ ": " +++ snd (ExtractPathAndFile tt_name);
			# dl_client_state = AddMessage (LinkerError msg) dl_client_state;
			= (dl_client_state,io);
		// create new type table
		# new_type_table
			= { default_type_table &
				tt_type_io_state		= type_io_state
			,	tt_tio_common_defs		= { x \\ x <-: tio_common_defs }
			,	tt_n_tio_common_defs	= size tio_common_defs
			,	tt_rti					= rti
			};
		# dl_client_state = AddTypeTable type_table_i new_type_table dl_client_state;
// RWS ...
	    # (string_table,dl_client_state) = dl_client_state!cs_type_tables.[type_table_i].tt_type_io_state.tis_string_table;
		# cs_type_equivalences = dl_client_state.cs_type_equivalences
		# cs_type_equivalences = addTypeEquivalences library_instance_i type_table_i string_table tio_common_defs cs_type_equivalences
		# dl_client_state = {dl_client_state & cs_type_equivalences = cs_type_equivalences}
// ... RWS

		// print that type library has been loaded
		#! dl_client_state = AddDebugMessage ("Loaded type table " +++ toString type_table_i +++ ": " +++ snd (ExtractPathAndFile tt_name)) dl_client_state;

		= (dl_client_state,io);
where {
	// old behaviour = create_new_names_table set to True
	read_type_library_new :: !Bool !String *Files -> *(*(Bool,RTI,.{#TIO_CommonDefs},*TypeIOState,*{!NamesTableElement}),*Files);	
	read_type_library_new create_new_names_table ls_main_code_type_lib files
		| create_new_names_table
			# (ok,rti,tio_common_defs,type_io_state,names_table,files)
				= read_type_information (ADD_TYPE_LIBRARY_EXTENSION ls_main_code_type_lib) create_names_table files;
			= ((ok,rti,tio_common_defs,type_io_state,names_table),files);
	
			// to prevent a names table being created and filled		
			# (ok,rti,tio_common_defs,type_io_state,names_table,files)
				= read_type_information_new create_new_names_table (ADD_TYPE_LIBRARY_EXTENSION ls_main_code_type_lib) {} files;
			= ((ok,rti,tio_common_defs,type_io_state,names_table),files);
};
