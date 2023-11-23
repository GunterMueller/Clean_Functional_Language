implementation module ObjectToMem;

import StdEnv;	
import UnknownModuleOrSymbol;
import pdObjectToMem;
from utilities import mapSt, foldSt;
import link_switches;
import ReadObject;
import selectively_import_and_mark_labels;
import StdDynamicTypes;
import LibraryInstance;
import type_io_read;
import typetable;
import StdMaybe;
import State;
import pdExtInt;
import ExtArray;
import LinkerMessages;
import pdSymbolTable;
import _SystemDynamic;
import TypeEquivalences;
import RWSDebugChoice;

LinkUnknownSymbols :: [ModuleOrSymbolUnknown] !*State !Int !Libraries !*DLClientState *f -> *(*(!(Maybe WriteImageInfo),[Int],!*State,!*DLClientState),*f) | FileEnv f;
LinkUnknownSymbols unknown_modules_or_symbols state library_instance_i all_libraries dl_client_state io
	/*
	** unknown_symbols contains those symbols that have not yet been
	** placed into memory. Only these symbols should be loaded and linked.
	*/
	#! (unknown_symbols,state)
		= mapSt compute_file_n_symbol_n_for_symbol unknown_modules_or_symbols state;
	with {
		compute_file_n_symbol_n_for_symbol (SymbolUnknown _ symbol_name) state
			#! (file_n,symbol_n,state) = find_name symbol_name state;
			= ((file_n,symbol_n),state);
	};
	
	#! (base_address,wii,state,dl_client_state,io)
		= link_unknown_symbols unknown_symbols state library_instance_i all_libraries dl_client_state io;
	#! (ok,state) = IsErrorOccured state;
	| not ok
		= abort "error";
		
	/*
	** The address of all unknown symbols, if defined are encoded as a
	** string and returned *in the order* as in the unknown_modules_or_symbols
	** parameter. The conversion function uses the order to identify the
	** proper descriptor.
	*/ 
	#! (_,symbol_addresses,state)
		= foldl compute_symbol_address (base_address,[],state) unknown_modules_or_symbols
	= ((wii,symbol_addresses,state,dl_client_state),io);
where {
	compute_symbol_address (base_address,symbol_addresses,state) symbol
		#! symbol_name
			= extract_symbol_name symbol;
		| symbol_name == ""
			= (base_address,symbol_addresses,state);

			#! (file_n,symbol_n,state)
				= find_name symbol_name state;
			#! (symbol_address,state)
				= address_of_label2 file_n symbol_n state;				
			= (base_address,symbol_addresses ++ [ base_address + symbol_address],state);
	
	extract_symbol_name (ModuleUnknown _ symbol_name)
		= symbol_name;
	extract_symbol_name (SymbolUnknown  _ symbol_name )
		= symbol_name;
	extract_symbol_name _ 
		= abort "extract_symbol_name: no match";
}

move_names_table_from_library_instance_i_to_state library_instance_i dl_client_state
	// move namestable from library_instance to current state
	#! (names_table,dl_client_state)
		= acc_names_table library_instance_i dl_client_state;

	#! (state,dl_client_state)
		= acc_state (\s -> (s,EmptyState)) dl_client_state;
	#! state
		= { state &
			namestable = names_table
		};
	= (state,dl_client_state);
	
move_names_table_from_state_to_library_instance_i library_instance_i state dl_client_state
	#! (names_table,state)
		= select_namestable state;
	#! dl_client_state
		= { dl_client_state &
			app_linker_state = state
		,	cs_library_instances.lis_library_instances.[library_instance_i].li_names_table = names_table
			};		
	= dl_client_state;

skip_marked_symbols :: ![(Int,Int)] !*State -> *(![(Int,Int)],!*State);
skip_marked_symbols symbols0=:[(file_n,symbol_n):symbols1] state	
	#! (symbol_offset,state) = symbol_n_to_offset file_n symbol_n state;
	| state.marked_bool_a.[symbol_offset]
		= skip_marked_symbols symbols1 state;
		= (symbols0,state);
skip_marked_symbols [] state
	= ([],state);

link_unknown_symbols [] state library_instance_i all_libraries dl_client_state io
	= (0,Nothing,state,dl_client_state,io);		
link_unknown_symbols unknown_symbols state=:{n_xcoff_symbols,n_library_symbols,n_xcoff_files} library_instance_i all_libraries dl_client_state io
	# (unknown_symbols,state) = skip_marked_symbols unknown_symbols state;
	| isEmpty unknown_symbols
		= (0,Nothing,state,dl_client_state,io);
	#! newly_marked_bool_a = createArray (n_xcoff_symbols + n_library_symbols) False;
	#! (newly_marked_bool_a,state)
		= foldSt (\(file_n,symbol_n) s -> selective_import_symbol file_n symbol_n s) unknown_symbols (newly_marked_bool_a,state);
	// ensure that all needed prefixes are linked ...
	#! (context_types,newly_marked_bool_a,state,dl_client_state,io)
		= case (library_instance_i < 0) of {
			True
				// a hack to load in the conversion functions which are
				// added to names table of the main library instance.
				-> ([],newly_marked_bool_a,state,dl_client_state,io);
			False
				#! dl_client_state
					= move_names_table_from_state_to_library_instance_i library_instance_i state dl_client_state;
				#! (context_types,_,(newly_marked_bool_a,dl_client_state,io))
					= loop_on_types2 library_instance_i (newly_marked_bool_a,dl_client_state,io);
				#! (state,dl_client_state)
					= move_names_table_from_library_instance_i_to_state library_instance_i dl_client_state;
				-> (context_types,newly_marked_bool_a,state,dl_client_state,io);
		};
	#! (already_marked_bool_a,state) = select_marked_bool_a state;
	#! state = { state & marked_bool_a	= newly_marked_bool_a };	

	#! (base_address,wii,state,io)
		= write_image all_libraries state io;

	/*
	// TEST
	#! (file_n,symbol_n,state) = find_name "qd" state;
	// mark qd-symbol
	#! (file_n_offset,state) = selacc_marked_offset_a file_n state;
	#! (dest_qd_address,state) = selacc_module_offset_a (file_n_offset + symbol_n) state;
	#! (toolbox,io) = GetToolBox io;
	#! toolbox = copy_mem qd_address 206 dest_qd_address toolbox;	
	#! io = PutToolBox toolbox io;
	*/

	/*
	// test
	#! (qd_address,state) = acc_pd_state (\pd_state=:{qd_address} -> (qd_address,pd_state)) state;
	#! state = F ("qd_address(3): " +++ (hex_int qd_address)) state;
	*/

	// merge previous and new marked symbols
	#! (marked_bool_a,state) = select_marked_bool_a state;
	#! all_marked_bool_a = or_bool_arrays marked_bool_a already_marked_bool_a;	
	#! state = {state & marked_bool_a = all_marked_bool_a};

	#! dl_client_state
		= move_names_table_from_state_to_library_instance_i library_instance_i state dl_client_state;

	// print ...
	# code_size
		= " (" +++ toString (wii.wii_code_end - wii.wii_code_start) +++ " bytes)"
	#! dl_client_state
		= AddDebugMessage ("Code: " +++ (hex_int wii.wii_code_start) +++ " - " +++ (hex_int wii.wii_code_end) +++ code_size ) dl_client_state
	# data_size
		= " (" +++ toString (wii.wii_data_end - wii.wii_data_start) +++ " bytes)"
	#! dl_client_state
		= AddDebugMessage ("Data: " +++ (hex_int wii.wii_data_start) +++ " - " +++ (hex_int wii.wii_data_end) +++ data_size ) dl_client_state

	#! (n_xcoff_files,dl_client_state)
		= dl_client_state!app_linker_state.n_xcoff_files;
	#! dl_client_state
		= OUPUT_DYNAMIC_DEBUG_INFO (loopAst (foo marked_bool_a) dl_client_state n_xcoff_files) dl_client_state;
	#! (state,dl_client_state)
		= move_names_table_from_library_instance_i_to_state library_instance_i dl_client_state;

	= (base_address,Just wii,state,dl_client_state,io);

foo marked_bool_a file_n dl_client_state
	#! (n_symbols,dl_client_state)
		= dl_client_state!app_linker_state.xcoff_a.[file_n].n_symbols;
	#! dl_client_state
		= loopAst bar dl_client_state n_symbols;
		with {
			bar symbol_n dl_client_state
					#! (symbol_offset,dl_client_state)
					= symbol_n_to_offset file_n symbol_n dl_client_state;
				| not (marked_bool_a.[symbol_offset])
					= dl_client_state;
					
					#! (maybe_symbol_address,dl_client_state)
						= label_address_of file_n symbol_n dl_client_state
						with {
							label_address_of file_n symbol_n dl_client_state
								#! (maybe_address,dl_client_state)
									= acc_state (address_of_label2_ file_n symbol_n) dl_client_state;
								| isNothing maybe_address
									= (Nothing,dl_client_state);
									
								| fromJust maybe_address == 0
									= (Nothing,dl_client_state);
									
									= (maybe_address,dl_client_state);
						};
					| isNothing maybe_symbol_address
						= dl_client_state;
						
					#! symbol_address
						= fromJust maybe_symbol_address;
//								#! msg
//									= (hex_int symbol_address) +++ ": (" +++ toString file_n +++ "," +++ toString symbol_n +++ ")"
//								#! dl_client_state
//									= AddMessage (Verbose msg) dl_client_state;
						= dl_client_state
		};
	= dl_client_state;

strict_or :: !Bool !Bool -> Bool;
strict_or a b = a||b;

or_bool_arrays marked_bool_a2 marked_bool_a = { strict_or b1 b2 \\ b1<-:marked_bool_a2 & b2<-:marked_bool_a };
	
ReadLibraryFiles2 :: ![String] !Int !Int !NamesTable !*Files -> ((!Bool,!LibraryList,!Int,!NamesTable),!*Files);
ReadLibraryFiles2 l library_n n_library_symbols0 names_table0 files0
	#! (b,l,i,f,n)
		= ReadLibraryFiles l library_n n_library_symbols0 files0 names_table0;
	= ((b,l,i,n),f);
	
	ReadLibraryFiles :: ![String] !Int !Int !*Files !NamesTable -> (!Bool,!LibraryList,!Int,!*Files,!NamesTable);
	ReadLibraryFiles [] library_n n_library_symbols0 files0 names_table0
		= (True,EmptyLibraryList,n_library_symbols0,files0,names_table0);
	ReadLibraryFiles [file_name:file_names] library_n n_library_symbols0 files0 names_table0
		#! (ok1,library_name,library_symbols,n_library_symbols,files1,names_table1)
			= read_library_file file_name library_n files0 names_table0;
		| ok1
			#! (ok10,libraries,n_library_symbols1,files2,names_table2)
				= ReadLibraryFiles file_names (inc library_n) (n_library_symbols0+n_library_symbols) files1 names_table1;		
			= (ok10,Library library_name /* mac */ 0 library_symbols n_library_symbols libraries,n_library_symbols1,files2,names_table2);
			
			= abort ("ReadLibraryFiles2: could not read '" +++ file_name +++ "'");

// It is assumed that a library instance is only loaded once which implies that if the library instance implements some
// type, then all its labels implementing that type must have been linked. The initial marking just marks the symbols
// reachable from set of root symbols. In general label prefixes may not refer to eachother, so they have to be marked
// explicitly. This function carries out this task.
// Vraag: Kunnen we niet gewoon alleen over de externe types lopen? Of over alle pattern gematchte types?
//loop_on_types :: !.Int !*(*{#.Bool},!*DLClientState,*a) -> *([(!{#Char},!LibraryInstanceTypeReference,!Int)],[.b],*(.{#Bool},*DLClientState,*a)) | FileEnv a;
loop_on_types2 library_instance_i (newly_marked_bool_a,dl_client_state=:{cs_main_library_instance_i},io)
	// general
	#! (type_table_i,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
	#! (tt_n_tio_common_defs,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_n_tio_common_defs;
	#! (context_types,labels,newly_marked_bool_a,dl_client_state,io)
		= loopAst (loop_on_module type_table_i) ([],[],newly_marked_bool_a,dl_client_state,io) tt_n_tio_common_defs;
	= (context_types,labels,(newly_marked_bool_a,dl_client_state,io));
where {
	loop_on_module type_table_i tio_tr_module_n (context_types,labels,newly_marked_bool_a,dl_client_state,io)
		// loop on type definitions
		# (tio_com_type_defs,dl_client_state)
			= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs;
		# (context_types,labels,newly_marked_bool_a,dl_client_state,io)
			= mapAiSt loop_on_type_def tio_com_type_defs (context_types,labels,newly_marked_bool_a,dl_client_state,io);
		= (context_types,labels,newly_marked_bool_a,dl_client_state,io);
	where {
		// Determine which label prefixes have not yet been linked in. 
		loop_on_type_def tio_tr_type_def_n {tio_td_name} (context_types,labels,newly_marked_bool_a,dl_client_state,io)
			# tio_type_reference
				= { default_elem &
					tio_tr_module_n		= tio_tr_module_n
				,	tio_tr_type_def_n	= tio_tr_type_def_n
				};
			# type
				= LIT_TypeReference (LibRef library_instance_i) tio_type_reference;

			#! (li_type_table_i,dl_client_state)
				= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
			#! (type_name,_,labels_implementing_type,dl_client_state)
				= get_type_label_names tio_type_reference li_type_table_i dl_client_state;
			# (maybe_type_symbols, dl_client_state)
				=	mapSt (flip findLabel library_instance_i) labels_implementing_type dl_client_state
			# type_symbols
				=	[(label, fromJust s) \\ label <- labels_implementing_type & s <- maybe_type_symbols]
			#! (any_label_implemented,unlinked_labels,newly_marked_bool_a,dl_client_state)
				= foldSt any_label_implemented labels_implementing_type (False,[],newly_marked_bool_a,dl_client_state);
			| not any_label_implemented
				// type not about to be linked
				= (context_types,labels,newly_marked_bool_a,dl_client_state,io);
			// otherwise
				# cs_type_equivalences
					=	dl_client_state.cs_type_equivalences
				# (maybe_symbols, cs_type_equivalences)
					=	getTypeSymbols type cs_type_equivalences
				# dl_client_state
					=	{dl_client_state & cs_type_equivalences = cs_type_equivalences}
				| isNothing maybe_symbols
					# cs_type_equivalences
						=	dl_client_state.cs_type_equivalences
					# cs_type_equivalences
						=	setTypeSymbols type_symbols type cs_type_equivalences
					# dl_client_state
						=	{dl_client_state & cs_type_equivalences = cs_type_equivalences}
					# (newly_marked_bool_a, dl_client_state)
						=	import_symbols type_symbols newly_marked_bool_a dl_client_state;
					= (context_types,labels,newly_marked_bool_a,dl_client_state,io);
				// otherwise
					# dl_client_state
						=	redirect_symbols type_symbols (fromJust maybe_symbols) dl_client_state;
						with {
							redirect_symbols :: [({#Char}, (Int, Int))] [({#Char}, (Int, Int))] !*DLClientState -> *DLClientState;
							redirect_symbols frm to st
								| False <<- (type_name, "redirect_symbols")
									=	undef
								| length frm <> length to
									=	abort "redirect_symbols" <<- (length frm, length to)
								=	foldSt redirect_symbol [(f,t) \\ f <- frm & t <- to] st;
							
							redirect_symbol :: (({#Char}, (Int, Int)),({#Char}, (Int, Int))) !*DLClientState -> *DLClientState;
							redirect_symbol ((frm_label, (frm_file, frm_sym)), (to_label, (to_file, to_sym))) st
	//							=	replaceSymbol frm_file frm_sym to_file to_sym st;
								=	replaceLabel frm_label library_instance_i to_file to_sym to_label st;
					}
					#! (newly_marked_bool_a,dl_client_state)
						= unmark_type_implementation type_symbols newly_marked_bool_a dl_client_state;
					= (context_types,labels,newly_marked_bool_a,dl_client_state,io);

		// huidige library instance bevat al een gedeeltelijk implementation van het type				
		where {
			close_type_implementation labels newly_marked_bool_a dl_client_state
				#! (state,dl_client_state)
					= move_names_table_from_library_instance_i_to_state library_instance_i dl_client_state;
				#! (newly_marked_bool_a,state)
					= foldSt (\(_,file_n,symbol_n) s -> selective_import_symbol file_n symbol_n s) labels (newly_marked_bool_a,state);

				#! dl_client_state
					= move_names_table_from_state_to_library_instance_i library_instance_i state dl_client_state;
				= (newly_marked_bool_a,dl_client_state);
				
			import_symbols labels newly_marked_bool_a dl_client_state
				#! (state,dl_client_state)
					= move_names_table_from_library_instance_i_to_state library_instance_i dl_client_state;
				#! (newly_marked_bool_a,state)
					= foldSt (\(_,(file_n,symbol_n)) s -> selective_import_symbol file_n symbol_n s) labels (newly_marked_bool_a,state);

				#! dl_client_state
					= move_names_table_from_state_to_library_instance_i library_instance_i state dl_client_state;
				= (newly_marked_bool_a,dl_client_state);
				
			unmark_type_implementation labels newly_marked_bool_a dl_client_state
				# (newly_marked_bool_a,dl_client_state)
					= foldSt unmark_constructor_label labels (newly_marked_bool_a,dl_client_state);
				= (newly_marked_bool_a,dl_client_state);
			where {
				unmark_constructor_label (constructor_label_name,(file_n,symbol_n)) (newly_marked_bool_a,dl_client_state)
					# (symbol_index,dl_client_state)
						= symbol_n_to_offset file_n symbol_n dl_client_state;

					// check ...
					#! (is_newly_marked_label,newly_marked_bool)
						= newly_marked_bool_a![symbol_index];
					| not is_newly_marked_label
						// labels for constructors of a type which are not linked
						= (newly_marked_bool_a,dl_client_state);
	
						#! (is_marked_label,newly_marked_bool)
							= dl_client_state!app_linker_state.marked_bool_a.[symbol_index];
						| is_marked_label
							#! (ref_module_n,dl_client_state)
								= acc_state (replace_section_label_by_label2 file_n symbol_n) dl_client_state;
							# (module_index,dl_client_state)
								= symbol_n_to_offset file_n ref_module_n dl_client_state;
							
							// note that not everything is unmarked; only the constructor. The rest could be unmarked
							// iff it is not shared but this is costly to determine and only a few bytes are extra
							// allocated (probably those for the module_name).
							#! newly_marked_bool_a
								= { newly_marked_bool_a & [symbol_index] = False, [module_index] = False };
							#! (s_newly_marked_bool_a,newly_marked_bool_a)
								= usize newly_marked_bool_a;
								
							| False
								= undef;
							= (newly_marked_bool_a,dl_client_state);

							// replaceLabel should already have marked this
							= (newly_marked_bool_a,dl_client_state);
//							= abort ("unmark_constructor_label; internal error" +++ constructor_label_name);
					// ... check
			};
												
			// at_least_one_label_of_type_is_about_to_be_implemented_by_current_library
			any_label_implemented :: !{#Char} !*(!Bool,[({#Char},(Int,Int))],*{#Bool},!*DLClientState) -> *(!Bool,[({#Char},(Int,Int))],!*{#Bool},!*DLClientState);
			any_label_implemented label_name (any_label_implemented,unimplemented_labels,newly_marked_bool,dl_client_state)
				# (maybe_file_n_symbol_n,dl_client_state)
					= findLabel label_name library_instance_i dl_client_state;
				| isNothing maybe_file_n_symbol_n
					# dl_client_state
						= OUTPUT_UNIMPLEMENTED_FEATURES_WARNINGS
							(dl_client_state)
							dl_client_state;
					// for the time being do as if the label were implemented
					= (False,unimplemented_labels,newly_marked_bool,dl_client_state)
			
				# (file_n_symbol_n=:(file_n,symbol_n))
					= fromJust maybe_file_n_symbol_n;
				# (symbol_index,dl_client_state)
					= symbol_n_to_offset file_n symbol_n dl_client_state;

				#! (first_symbol_n,dl_client_state)
					= dl_client_state!app_linker_state.marked_offset_a.[file_n];
				#! (is_marked_label,newly_marked_bool)
					= newly_marked_bool![first_symbol_n+symbol_n];
				| is_marked_label
					= (True,unimplemented_labels,newly_marked_bool,dl_client_state);
					
					= (any_label_implemented,[(label_name,file_n_symbol_n):unimplemented_labels],newly_marked_bool,dl_client_state);
		} // loop_on_type_def
	}
};
