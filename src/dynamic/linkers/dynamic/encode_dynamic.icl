implementation module encode_dynamic;

import StdEnv;
import UnknownModuleOrSymbol;
import dynamics;
import dus_label;
import pdObjectToMem;
import link_library_instance;
import ExtArray;
from DynID import extract_dynamic_or_library_identification;
import utilities;
from DynamicLinkerInterface import ::RunTimeIDW(..), instance EnDecode RunTimeIDW, instance DefaultElem RunTimeIDW;
import EnDecode;
import StdDynamicLowLevelInterface;
import LibraryInstance;
import LinkerMessages;
import ToAndFromGraph;
import StdDynamicTypes;
import RWSDebugChoice;
import typetable;
import StdMaybe;
import DefaultElem;
import pdExtInt;

from ProcessSerialNumber import instance toString ProcessSerialNumber;

// get address of the graph to string function
HandleGetGraphToStringMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem, FileEnv f;
HandleGetGraphToStringMessage client_id [label_names_encoded_in_msg] s io
	#! (client_exists,dl_client_state,s)
		= RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "GetGraphToStringFunction (internal error): client not registered" client_id dl_client_state s io;

	#! (dl_client_state)
		= AddDebugMessage "GetGraphToStringFunction" dl_client_state;

	#! (l,graph_to_string,dl_client_state,s,io) 
		= case True of {
			True
				// The conversion-functions are shared among all library instances. The Clean-data structures used within
				// these functions may only have a single implementation.
				#! ({tafge_version=latest_version,tafge_conversion},tfge_index,dl_client_state)
					= get_from_graph_function_address2 Nothing dl_client_state;
				| isJust tafge_conversion
					// conversion-functions have already been linked. Re-use these functions
					#! (dlink_dir,s) = GetDynamicLinkerDirectory s;
					#! module_name = dlink_dir +++ "\\" +++ copy_graph_to_string +++ "_" +++ (toFileNameSubString latest_version) +++ ".obj";
					#! symbol_name = "e__DynamicGraphConversion__d" +++ copy__graph__to__string +++ "__" +++ toFileNameSubString latest_version;
					#! graph_to_string = [ModuleUnknown module_name symbol_name];
					-> ([fromJust tafge_conversion],graph_to_string,dl_client_state,s,io);

				#! (dlink_dir,s) = GetDynamicLinkerDirectory s;
				#! module_name = dlink_dir +++ "\\" +++ copy_graph_to_string +++ "_" +++ (toFileNameSubString latest_version) +++ ".obj";
				#! symbol_name = "e__DynamicGraphConversion__d" +++ copy__graph__to__string +++ "__" +++ toFileNameSubString latest_version;
				#! graph_to_string = [ModuleUnknown module_name symbol_name];

				#! (Just main_library_instance_i,dl_client_state)
					= dl_client_state!cs_main_library_instance_i;

				#! (dl_client_state,s,io)
					= add_object_module_to_library_instance module_name main_library_instance_i dl_client_state s io;

				#! label
					= { default_elem &
						dusl_label_name				= symbol_name
					,	dusl_linked 				= False
					,	dusl_label_kind				= DSL_RUNTIME_SYSTEM_LABEL
					};
						
				#! (_,l,dl_client_state,io)
					= load_code_library_instance (Just [label]) main_library_instance_i dl_client_state io
				# dl_client_state
					= { dl_client_state & cs_to_and_from_graph.tafgt_from_graphs.[tfge_index].tafge_conversion = Just (hd l) };
				-> (l,graph_to_string,dl_client_state,s,io);
		};

	// check for errors		
	#! (ok,dl_client_state)
		= IsErrorOccured dl_client_state;
	| not ok
		= (not ok,client_id,AddToDLServerState dl_client_state s,io);
		
	// DLClientState
	# (cs_n_lazy_dynamics,dl_client_state) = dl_client_state!cs_n_lazy_dynamics;
		
	# (msg,dl_client_state)
		= build_range_table dl_client_state;
	# encoded_l = EncodeClientMessage l +++ msg +++ FromIntToString cs_n_lazy_dynamics;
	# io = SendAddressToClient client_id encoded_l io;
		
	// verbose		
	#! dl_client_state = DEBUG_INFO (SetLinkerMessages (produce_verbose_output graph_to_string l []) dl_client_state) dl_client_state;

	= (not ok,client_id,AddToDLServerState dl_client_state s,io);
where {
	build_range_table dl_client_state=:{cs_library_instances={lis_n_library_instances}}
		# (range_entries,dl_client_state)
			= loopAst build_range_entry3 ([],dl_client_state) lis_n_library_instances;
		# range_entries = { range_entry \\ range_entry <- range_entries };
		# n_sections = size range_entries;
		# range_id
			= {	rid_n_range_id_entries	= n_sections
			,	rid_n_type_tables		= lis_n_library_instances
			,	rid_range_entries		= range_entries
			};
		// rid_n_type_tables is indexed by run-time ids at run-time
		= (toString range_id,dl_client_state);
	where {
		build_range_entry3 library_instance_i (range_entries,dl_client_state)
			# (li_memory_areas,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_memory_areas;
			# range_entries
				= foldSt add_range_entry li_memory_areas range_entries;
			= (range_entries,dl_client_state);
		where {
			add_range_entry {ma_begin,ma_end} range_entries
				# range_id_entry
					= { ride_begin_address		= ma_begin
					,	ride_end_address		= ma_end
					,	ride_type_table_i		= library_instance_i
					};
				= [range_id_entry:range_entries];		
		};
	};
};

:: *DynamicInfoOutput
	= {
	// Libraries
		dio_n_library_instances					:: !Int											// size dio_library_instance_to_library_index
	,	dio_library_instance_to_library_index	:: !*{#LibraryInstanceToLibraryIndexInfo}		// indexed by a RunTimeID, index in di_library_index_to_library_name
	,	dio_library_index_to_library_name		:: !{#{#Char}}									// indexed by index from above array, string reference to {code,type}-library
	// reflects situation in encoded dynamic
	,	dio_used_library_instances				:: !{LibraryInstance1}							// maps rt-library instance index to encoded {non_lazy,lazy}-library instance index, if possible
	// Lazy dynamics
	,	dio_lazy_dynamics						:: !{#LazyDiskDynamicInfo}
	// Type equations
	,	dio_type_equivalence_classes			:: !{#{LibraryInstanceTypeReference}}			//!{DiskTypeEquivalentClass}
	,	dio_convert_rt_type_equivalence_class	:: !{Maybe Int}									// indexed by type_ref from type equivalent class and delivers index in dio_type_equivalence_classes
	};
	
:: LibraryInstance1
	= UnusedLibraryInstance
	| UsedLibraryInstance !Int				// (non-lazy in encoded dynamic) disk_library_instance_i, means that at least some code from that library has been linked in		
	| LazyLibraryInstance !Int !Int			// (lazy in encoded dynamic) lazy_dynamic_index disk_library_instance_i
	;

:: LazyDiskDynamicInfo
	= {
		ldi_runtime_id	:: !Int
	,	ldi_name		:: !String
	};

instance DefaultElem LazyDiskDynamicInfo
where {
	default_elem
		= {
			ldi_runtime_id	= default_elem
		,	ldi_name		= default_elem
		};
};
	
:: LibraryInstanceToLibraryIndexInfo
	= {
		litlii_kind												:: !LibraryInstanceKind
	,	litlii_index_in_di_library_index_to_library_name		:: !Int
	,	litlii_used_by_code										:: !Bool
	,	litlii_used_by_type										:: !Bool
	
	// Just _ 	= iff litlii_used_by_type == True and litlii_used_by_code == False
	// Nothing	= otherwise
	,	litlii_reference_to_library_instance_in_lazy_dynamic	:: !Maybe LibraryReference 
	};
	
instance DefaultElem LibraryInstanceToLibraryIndexInfo
where {
	default_elem
		= { 
			litlii_kind												= LIK_Empty
		,	litlii_index_in_di_library_index_to_library_name		= 0
		,	litlii_used_by_code										= False
		,	litlii_used_by_type										= False
		,	litlii_reference_to_library_instance_in_lazy_dynamic	= Nothing
		};
};

isLazyLibraryInstanceIndex :: LibraryInstanceToLibraryIndexInfo -> Bool;
isLazyLibraryInstanceIndex {litlii_used_by_code=False,litlii_used_by_type=True,litlii_reference_to_library_instance_in_lazy_dynamic=Just _}
	= True;
isLazyLibraryInstanceIndex _
	= False;

:: LibraryReference
	= {
		lr_library_instance_i	:: !Int			// disk library instance index w.r.t. lazy dynamic lr_dynamic_index_i
	,	lr_dynamic_index_i		:: !Int			// w.r.t. main dynamic
	};
	
instance == LibraryReference
where {
	(==) {lr_library_instance_i=lr_library_instance_i1,lr_dynamic_index_i=lr_dynamic_index_i1} {lr_library_instance_i,lr_dynamic_index_i}
		= lr_library_instance_i1 == lr_library_instance_i && lr_dynamic_index_i1 == lr_dynamic_index_i;
};
		
	
instance DefaultElem LibraryReference
where {
	default_elem
		= {
			lr_library_instance_i	= 0
		,	lr_dynamic_index_i		= 0
		};
};

:: DynamicInfoInput
	= {
		dii_library_instances_a			:: {Maybe LibraryInstanceInfo}				// used run-time library instances
	,	dii_lazy_dynamic_references		:: !{#LazyDynamicReference}					// used lazy dynamic by main dynamic
	,	dii_run_time_ids				:: !{#RunTimeIDW}							// references to types in type component
	};
	
:: LibraryInstanceInfo
	= {
		lii_used_by_code				:: !Bool
	,	lii_used_by_type				:: !Bool
	,	lii_encoded_library_instance	:: !Int			// assigned disk id for the run-time library instance
	};
	
instance DefaultElem LibraryInstanceInfo
where {
	default_elem
		= {
			lii_used_by_code				= False
		,	lii_used_by_type				= False
		,	lii_encoded_library_instance	= -1
		};
};

instance DefaultElemU DynamicInfoOutput
where {
	default_elemU
		= {
		// Libraries
			dio_n_library_instances					= 0
		,	dio_library_instance_to_library_index	= {}
		,	dio_library_index_to_library_name		= {}
		,	dio_used_library_instances				= {}
		
		// Lazy dynamics
		,	dio_lazy_dynamics						= {}
		
		// Type equations
		,	dio_type_equivalence_classes			= {}
		,	dio_convert_rt_type_equivalence_class	= {}
		};
};
	
:: *EliminateLazyReferencesState
	= {
		elrs_predefined_library_instance				:: !Int					// diskID
	,	elrs_library_instance_to_library_index_index	:: !*{#LibraryInstanceToLibraryIndexInfo}
	,	elrs_library_index_to_library_name				:: !*{#{#Char}}
	};
	
// send to get extra dynamic rts information
HandleGetDynamicRTSInfoMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem, FileEnv f;
HandleGetDynamicRTSInfoMessage client_id [arg] s io
	#! (client_exists,dl_client_state,s) 
		= RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "HandleGetDynamicRTSInfoMessage (internal error): client not registered" client_id dl_client_state s io;

	#! (dl_client_state)
		= AddDebugMessage "HandleGetDynamicRTSInfoMessage" dl_client_state;
	# dii = decode_arg_block arg;
	# (dio,dl_client_state)
		= determine_used_lazy_dynamics dii default_elemU dl_client_state;
	# (dio,dl_client_state)
		= determine_used_libraries dii dio dl_client_state;
	// -----------------------------------------------
	// UITPAKKEN
	#! (lazy_dynamics_a,dio) = dio!dio_lazy_dynamics;
	#! (di_disk_type_equivalent_classes,dio) = dio!dio_type_equivalence_classes;

	#! (library_instance_to_library_index_a,dio)
		= get dio;
	#! (library_index_to_library_name_a,dio) = dio!dio_library_index_to_library_name;
	#! di
		= { default_dynamic_info &
			di_library_instance_to_library_index	= { convert_litlii_to_library_instance_kind library_instance \\ library_instance <-: library_instance_to_library_index_a }	// LIBRARY INSTANCE TABLE
		,	di_library_index_to_library_name		= 
			if IS_NORMAL_FILE_IDENTIFICATION 
				library_index_to_library_name_a	// LIBRARY STRING TABLE
				{ extract_dynamic_or_library_identification library_name \\ library_name <-: library_index_to_library_name_a }
		,	di_disk_type_equivalent_classes			= di_disk_type_equivalent_classes
		,	di_lazy_dynamics_a						= { (FILE_IDENTIFICATION extract_dynamic_or_library_identification ldi_name) ldi_name \\ {ldi_name} <-: lazy_dynamics_a }
		};
	#! io = SendAddressToClient client_id (encode di) io;
	# ok = True
	= (not ok,client_id,AddToDLServerState dl_client_state s,io);
where {
    get dio=:{dio_library_instance_to_library_index}
     	= (dio_library_instance_to_library_index,{dio & dio_library_instance_to_library_index = {} });
     	
    convert_litlii_to_library_instance_kind litlii=:{litlii_index_in_di_library_index_to_library_name,litlii_reference_to_library_instance_in_lazy_dynamic}
		# lik_library_instance
			= { LIK_LibraryInstance | lik_index_in_di_library_index_to_library_name = litlii_index_in_di_library_index_to_library_name};
		= LIK_LibraryInstance lik_library_instance;

	decode_arg_block :: !String -> DynamicInfoInput;
	decode_arg_block arg_block
		# (library_instances_a,j)
			= help_type_checker2 (from_string 0 arg_block);		/// maps diskids to library_instances
		# library_instances_a
			= { if (x == -1)
					Nothing 
					(Just {	lii_used_by_code				= IS_CODE_LIBRARY_INSTANCE x
						,	lii_used_by_type				= IS_TYPE_LIBRARY_INSTANCE x
						,	lii_encoded_library_instance	= GET_LIBRARY_INSTANCE_I x
					})
			 \\ x <-: library_instances_a };
			 
		# (lazy_dynamic_references,k) = from_string j arg_block;
		# (run_time_ids,l) = from_string k arg_block;
		= {	dii_library_instances_a		= library_instances_a
		,	dii_lazy_dynamic_references	= lazy_dynamic_references
		,	dii_run_time_ids			= run_time_ids
		};
	where {
		help_type_checker2 :: (!{#Int},!Int) -> (!{#Int},!Int);
		help_type_checker2 i = i;
	};
}

// The build_block rt_lazy_dynamic id (defined in _SystemDynamic) have been collected in the LazyDynamicReferences-array by the
// conversion function. This functions puts them into a list.
determine_used_lazy_dynamics :: !DynamicInfoInput !*DynamicInfoOutput !*DLClientState -> (!*DynamicInfoOutput,!*DLClientState);
determine_used_lazy_dynamics dii=:{dii_lazy_dynamic_references=lazy_dynamic_references} dio dl_client_state
	// determine used lazy dynamics	
	# max_lazy_dynamic_index = mapASt (\{ldr_lazy_dynamic_index} accu -> max ldr_lazy_dynamic_index accu) lazy_dynamic_references (-1);
	# n_lazy_dynamics = inc max_lazy_dynamic_index;
	# lazy_dynamics_a = createArray n_lazy_dynamics default_elem;
	# (lazy_dynamics_a,dl_client_state)
		= mapASt collect_lazy_dynamic_reference lazy_dynamic_references (lazy_dynamics_a,dl_client_state);
	# dio = { dio & dio_lazy_dynamics = lazy_dynamics_a };
	= (dio,dl_client_state);
where {
	collect_lazy_dynamic_reference {ldr_id,ldr_lazy_dynamic_index} (lazy_dynamics_a,dl_client_state)
//JVG	|	ldr_id >= INITIAL_LAZY_DYNAMIC_INDEX
//JVG	|	#! rt_lazy_dynamic_index = ldr_id;
		|	ldr_id < 0
			#! rt_lazy_dynamic_index = ~ldr_id;
//
			#! (lazy_dynamic_info=:{ldi_parent_index,ldi_lazy_dynamic_index_to_dynamic=has_lazy_dynamic_already_been_initialized},dl_client_state)
//				= dl_client_state!cs_lazy_dynamic_index_to_dynamic_id.[rt_lazy_dynamic_index];
				= collect_lazy_dynamic_reference_a0 dl_client_state
				with {
					collect_lazy_dynamic_reference_a0 dl_client_state
						| rt_lazy_dynamic_index>size dl_client_state.cs_lazy_dynamic_index_to_dynamic_id
							= abort ("collect_lazy_dynamic_reference_a0 "+++toString rt_lazy_dynamic_index+++" "+++toString (size dl_client_state.cs_lazy_dynamic_index_to_dynamic_id))
							= dl_client_state!cs_lazy_dynamic_index_to_dynamic_id.[rt_lazy_dynamic_index];
				}

			// find index for lazy dynamic
			#! (dynamic_info,dl_client_state) = dl_client_state!cs_dynamic_info.[ldi_parent_index];
//			| False <<- dynamic_info.di_disk_to_rt_dynamic_indices
//				= undef;
			
			#! maybe_dynamic_index
				= findAi find_dynamic_index dynamic_info.di_disk_to_rt_dynamic_indices;
				with {
					find_dynamic_index i rt_dynamic_index
//JVG					| rt_lazy_dynamic_index == rt_dynamic_index
						| ldr_id == rt_dynamic_index
//
							= Just i;
							= Nothing;
				};
			| isNothing maybe_dynamic_index
				= abort "collect_lazy_dynamic_reference; internal error; lazy dynamic should have been assigned a unique id by its parent";
				
			#! dynamic_index = fromJust maybe_dynamic_index;
			#! dynamic_id = dynamic_info.di_lazy_dynamics_a.[dynamic_index];

			#! lazy_dynamics_a = { lazy_dynamics_a & [ldr_lazy_dynamic_index] = { ldi_runtime_id = ldr_id, ldi_name = dynamic_id } };
			= (lazy_dynamics_a,dl_client_state);
				
//			= abort ("***: " +++ (extract_dynamic_or_library_identification dynamic_id) ); \

		#! (di_file_name,dl_client_state) = dl_client_state!cs_dynamic_info.[ldr_id].di_file_name;
		#! lazy_dynamics_a = { lazy_dynamics_a & [ldr_lazy_dynamic_index] = { ldi_runtime_id = ldr_id, ldi_name = di_file_name } };
		= (lazy_dynamics_a,dl_client_state);
};

determine_used_libraries :: !DynamicInfoInput !*DynamicInfoOutput !*DLClientState -> (!*DynamicInfoOutput,!*DLClientState);
determine_used_libraries dii=:{dii_library_instances_a=library_instances_a,dii_lazy_dynamic_references=lazy_dynamic_references} dio dl_client_state
	// create library used
	# (n_type_tables,dl_client_state)
		= get_number_of_type_tables dl_client_state;
	# library_used
		= createArray n_type_tables False;
	
	// determine used type and code libraries
	# (library_instance_max_index,_,n_libraries_used,dl_client_state)
		= mapAiSt compute_amount_of_libraries_and_instance_used library_instances_a (0,library_used,0,dl_client_state);
	# n_library_instances
		= inc library_instance_max_index;
		
	// maps a type_table_i to its index in library_name_a (temp)
	# library_name_indices
		= createArray n_type_tables Nothing;
		
	// maps a library instance to its library name; LIBRARY INSTANCE TABLE
	# library_instance_to_library_index_a
		= createArray n_library_instances default_elem;
		
	// indexed by an element from library_instance_to_library_name_a to a library name; LIBRARY STRING TABLE
	# library_index_to_library_name_a
		= { "" \\ _ <- [1..n_libraries_used] };


	// fill LIBRARY INSTANCE TABLE and LIBRARY STRING TABLE
	# (_,library_instance_to_library_index_a,library_index_to_library_name_a,_,dl_client_state)
		= mapAiSt (fill_library_arrays n_libraries_used) library_instances_a (library_name_indices,library_instance_to_library_index_a,library_index_to_library_name_a,0,dl_client_state);
				
	// -----------------------------------------------
	// Store type equations for all library instances involved
	// library_instances_a contains the used library instances for the new dynamic being created. Type equations must
	// be inserted before the first block of the new dynamic will be demanded. These equations are called *eager* type
	// equations.
	// 
	# (lis_n_library_instances,dl_client_state)
		= dl_client_state!cs_library_instances.lis_n_library_instances;
		
	// Auxillary array which maps *used* library instances used in the main dynamic i.e. the dynamic being created to encoded
	// library instances. There are two kinds of library instances: library instances in the main dynamic and library instances
	// relative to a lazy dynamic of the main dynamic. The algorithm reflects this fact by also creating the array in two steps. 
	// step 1: collect the library instances directly used by the main dynamic
	#! used_library_instances
		= createArray lis_n_library_instances UnusedLibraryInstance;
	#! (used_library_instances,dl_client_state)
		= mapAiSt determine_the_used_library_instances_of_main_dynamic library_instances_a (used_library_instances,dl_client_state);

	// step 2: collect the used library instances of lazy dynamics which are used by the main dynamic			
	#! (used_library_instances,dl_client_state)
		= mapASt determine_the_used_library_instances_within_the_lazy_dynamics_of_the_main_dynamic lazy_dynamic_references (used_library_instances,dl_client_state)

	# dio
		= { dio &
			dio_n_library_instances					= n_library_instances
		,	dio_library_instance_to_library_index	= library_instance_to_library_index_a
		,	dio_library_index_to_library_name		= library_index_to_library_name_a

		,	dio_used_library_instances				= used_library_instances
		};
	= (dio,dl_client_state);
where {
	// computes from the library instances which physical libraries are being used. A physical library occurs at most once
	// in the LIBRARY STRING TABLE.
	compute_amount_of_libraries_and_instance_used :: !Int !(Maybe LibraryInstanceInfo) !*(!Int,*{#Bool},!Int,!*DLClientState) -> *(!Int,*{#Bool},!Int,!*DLClientState);
	
	compute_amount_of_libraries_and_instance_used library_instance_i (Just {lii_encoded_library_instance=library_instance_i_non_runtime_index}) s=:(library_instance_max_index,library_used,n_libraries_used,dl_client_state)
		// library_instance_i_non_runtime_index
		| library_instance_i < RTID_LIBRARY_INSTANCE_ID_START
			= s;
	
		// compute maximum library *instance* index
		# library_instance_max_index
			= max library_instance_max_index library_instance_i_non_runtime_index;
			
		// get type table for current library instance
		# (type_table_i,dl_client_state)
			= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
		| library_used.[type_table_i]
			= (library_instance_max_index,library_used,/* WAS inc*/ n_libraries_used,dl_client_state);
		
		# library_used
			= { library_used & [type_table_i] = True };
		= (library_instance_max_index,library_used,inc n_libraries_used,dl_client_state);
	compute_amount_of_libraries_and_instance_used _ _ s
		= s;

	// computes the LIBRARY INSTANCE TABLE in library_instance_to_library_index_a and the LIBRARY STRING TABLE in
	// library_index_to_library_name_a.
	// library_instance_i_non_runtime_index
	fill_library_arrays :: !Int !Int !(Maybe LibraryInstanceInfo) *(*{Maybe Int},*{#LibraryInstanceToLibraryIndexInfo},*{#String},.Int,*DLClientState) -> *(*{Maybe Int},*{#LibraryInstanceToLibraryIndexInfo},*{#String},Int,*DLClientState);
	fill_library_arrays n_libraries_used library_instance_i (Just {lii_used_by_code,lii_used_by_type,lii_encoded_library_instance=library_instance_i_non_runtime_index}) 
				s=:(library_name_indices,library_instance_to_library_index_a,library_index_to_library_name_a,free_library_index_to_library_name_index,dl_client_state)				
		| library_instance_i < RTID_LIBRARY_INSTANCE_ID_START
			= s;
	
		// get type table for current library instance
		# (type_table_i,dl_client_state)
			= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
		| isNothing library_name_indices.[type_table_i]
			// fill library_instance_to_library_index_a with index in library_index_to_library_name_a
			# library_instance_to_library_index_a
				= { library_instance_to_library_index_a & [library_instance_i_non_runtime_index] = 
				{default_elem &
					litlii_index_in_di_library_index_to_library_name	= free_library_index_to_library_name_index
				,	litlii_used_by_code									= lii_used_by_code
				,	litlii_used_by_type									= lii_used_by_type
				}			
				};
	
			// fill library_index_to_library_name_a
			# (li_library_name,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_library_name;
			# library_index_to_library_name_a = { library_index_to_library_name_a & [free_library_index_to_library_name_index] = li_library_name };

			# library_name_indices = { library_name_indices & [type_table_i] = Just free_library_index_to_library_name_index };
			
			# free_library_index_to_library_name_index = inc free_library_index_to_library_name_index;
			= (library_name_indices,library_instance_to_library_index_a,library_index_to_library_name_a,free_library_index_to_library_name_index,dl_client_state)
			
	
			# library_index_to_library_name
				= fromJust library_name_indices.[type_table_i];
	
			// fill library_instance_to_library_index_a with index in library_index_to_library_name_a
			# library_instance_to_library_index_a
				= { library_instance_to_library_index_a & [library_instance_i_non_runtime_index] =
	
				{default_elem &
					litlii_index_in_di_library_index_to_library_name	= free_library_index_to_library_name_index
				,	litlii_used_by_code									= lii_used_by_code
				,	litlii_used_by_type									= lii_used_by_type
				}			
	
				};
			= (library_name_indices,library_instance_to_library_index_a,library_index_to_library_name_a,free_library_index_to_library_name_index,dl_client_state);

	fill_library_arrays _ _ _ s
			= s;

	// collect used library *code* instances in a set
	// library_instance_i_non_runtime_index2
	determine_the_used_library_instances_of_main_dynamic :: .Int !(Maybe .LibraryInstanceInfo) !*(*{LibraryInstance1},!*DLClientState) -> (*{LibraryInstance1},!*DLClientState);
	determine_the_used_library_instances_of_main_dynamic library_instance_i (Just {lii_used_by_code=True,lii_encoded_library_instance=library_instance_i_non_runtime_index}) (used_library_instances,dl_client_state)			
		| library_instance_i < RTID_LIBRARY_INSTANCE_ID_START
			= (used_library_instances,dl_client_state);
	
		#! used_library_instances
			= { used_library_instances & [library_instance_i] = UsedLibraryInstance library_instance_i_non_runtime_index };
		= (used_library_instances,dl_client_state);
	determine_the_used_library_instances_of_main_dynamic _ _ s
		= s;

	// rt_dynamic_id -> set of library ids -> set of currently *used* library ids 
	// mark UnusedLibrary instance reachable from the set of lazy dynamics as LazyLibraryInstance
	// what about if it was a UsedLibraryInstance?
	determine_the_used_library_instances_within_the_lazy_dynamics_of_the_main_dynamic :: !.LazyDynamicReference !*(*{LibraryInstance1},!*DLClientState) -> *(*{LibraryInstance1},*DLClientState);
	determine_the_used_library_instances_within_the_lazy_dynamics_of_the_main_dynamic {ldr_id,ldr_lazy_dynamic_index} (used_library_instances,dl_client_state)
//JVG	| ldr_id >= INITIAL_LAZY_DYNAMIC_INDEX
		| ldr_id < 0
//
			// Test
			= (used_library_instances,dl_client_state);

		#! (di_disk_id_to_library_instance_i,dl_client_state) = dl_client_state!cs_dynamic_info.[ldr_id].di_disk_id_to_library_instance_i;
		#! used_library_instances = mapAiSt determine_the_used_library_instances_within_a_lazy_dynamic di_disk_id_to_library_instance_i used_library_instances;
		= (used_library_instances,dl_client_state);
	where {
		determine_the_used_library_instances_within_a_lazy_dynamic disk_library_instance_i library_instance_i used_library_instances
			| disk_library_instance_i < RTID_DISKID_RENUMBER_START || library_instance_i == TTUT_UNUSED
				= used_library_instances;
				
			| LLI_IS_LAZY_LIBRARY_INSTANCE library_instance_i
				= used_library_instances;
				
			#! (kind,used_library_instances)
				= used_library_instances![library_instance_i];

			#! used_library_instances
				= case kind of {
					UnusedLibraryInstance
						#! used_library_instances
							= { used_library_instances & 
								[library_instance_i] = LazyLibraryInstance ldr_lazy_dynamic_index disk_library_instance_i
							};
						-> used_library_instances;
					UsedLibraryInstance _
						-> used_library_instances;
					_
						// Library instance has already been used. If it is used by an UsedLibraryInstance,
						// then the dynamic being constructed uses an already constructed block i.e. a block
						// without build_block of another dynamic and at least some build_blocks. Because at
						// least one block has been included in the new dynamic, all the disk library instances 
						// have been converted to run-time library instances: there is no need for lazy type 
						// equations.
						-> used_library_instances;
				};
			= used_library_instances;
	};
};

:: *RedirectTypeReferenceState
	= {
		rtrs_default_library_instance_i		:: !Int
	};
	
instance DefaultElemU RedirectTypeReferenceState
where {
	default_elemU
		= { 
			rtrs_default_library_instance_i 	= 0
		};
};

find_type_table library_name dio=:{dio_library_index_to_library_name}
	# (found,dio_library_index_to_library_name)
		= findAieu (\i library_name2 -> if (library_name == library_name2) (Just i) Nothing) dio_library_index_to_library_name;
	| isJust found
		#! dio
			= { dio & dio_library_index_to_library_name	= dio_library_index_to_library_name };
		= (fromJust found,dio);

		# (new_library_name_index,dio_library_index_to_library_name) 
			= extend_array_nu 1 dio_library_index_to_library_name;
		# dio_library_index_to_library_name
			= { dio_library_index_to_library_name & [new_library_name_index] = library_name };
		#! dio
			= { dio & dio_library_index_to_library_name	= dio_library_index_to_library_name };
		= (new_library_name_index,dio);

is_used_library_instance used_library_instances (LIT_TypeReference (LibRef library_instance_j) _)
	= case used_library_instances.[library_instance_j] of {
		UsedLibraryInstance _ 	-> True;
		_						-> False;
	};
is_used_library_instance _ _
	= False;

// converts a library type reference into an encoded version of it provided dio_used_library_instances has been set.
convert_rt_type_reference_to_encoded_type_reference :: !LibraryInstanceTypeReference !DynamicInfoInput !*DynamicInfoOutput !*DLClientState !*f -> ((Maybe LibraryInstanceTypeReference),!*DynamicInfoOutput,!*DLClientState,!*f) | FileEnv f;
convert_rt_type_reference_to_encoded_type_reference t=:(LIT_TypeReference (LibRef library_instance_i) tio_type_ref) dii dio=:{dio_used_library_instances=used_library_instances} dl_client_state io
	# (maybe_encoded_type_reference,dio,dl_client_state,io)
		= case used_library_instances.[library_instance_i] of {
			UnusedLibraryInstance
				// ignore because it cannot be converted
				-> (Nothing,dio,dl_client_state,io);
			UsedLibraryInstance disk_library_instance_i
				#! encoded_type_reference
					= LIT_TypeReference (LibRef disk_library_instance_i) tio_type_ref;
				-> (Just encoded_type_reference,dio,dl_client_state,io);
			LazyLibraryInstance lazy_dynamic_index disk_library_instance_i
				// is there a type which contains; create new entry
				#! (types,dl_client_state)
					= collect_equivalent_context_types t [] dl_client_state;
				#! used_library_instances
					= filter (is_used_library_instance used_library_instances) types;
				| isEmpty used_library_instances
					// no used_library_instances
					#! (disk_library_instance_i,dio,dl_client_state)
						= add_type_table_of_library_instance_i library_instance_i dio dl_client_state;
					#! encoded_type_reference
						= LIT_TypeReference (LibRef disk_library_instance_i) tio_type_ref;
					-> (Just encoded_type_reference,dio,dl_client_state,io);
					
					-> (Just (hd used_library_instances),dio,dl_client_state,io);

		};
	= (maybe_encoded_type_reference,dio,dl_client_state,io);
where {
	add_type_table_of_library_instance_i library_instance_i dio=:{dio_n_library_instances} dl_client_state
		# (dio_library_instance_to_library_index,dio)
			= get_dio dio;
			with {
				get_dio dio=:{dio_library_instance_to_library_index}
					= (dio_library_instance_to_library_index,{dio & dio_library_instance_to_library_index = {}})
			};
	
		#! (library_name,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_library_name;
		#! (library_index,dio)
			= find_type_table library_name dio;
		| False
			= (library_index,dio,dl_client_state);
			
			#! (new_index,new_dio_library_instance_to_library_index)
				= extend_array 1 dio_library_instance_to_library_index;
				
			#! new_entry
				= { default_elem &
					litlii_kind											= LIK_LibraryInstance {LIK_LibraryInstance | lik_index_in_di_library_index_to_library_name = library_index}
				,	litlii_index_in_di_library_index_to_library_name	= library_index
				,	litlii_used_by_type									= True
				};
				
			#! new_dio_library_instance_to_library_index
				= { new_dio_library_instance_to_library_index & [new_index] = new_entry };
				
			#! dio
				= { dio &
					dio_n_library_instances					= inc dio_n_library_instances
				,	dio_library_instance_to_library_index	= new_dio_library_instance_to_library_index
				};
			= (new_index,dio,dl_client_state);
};

// Nothing als de type referentie niet binnen de te weg te schrijven dynamic valt.
add_type_table type_table_i dio dl_client_state
	#! (tt_name,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_name;
	#! (library_index,dio)
		= find_type_table tt_name dio;
	= (library_index,dio,dl_client_state);
