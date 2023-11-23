implementation module decode_dynamic;

import StdEnv;
import shared_buffer;
import link_library_instance;
import dynamics;
import pdObjectToMem;
import link_switches;
import ExtArray;
import ExtString;
from DynamicLinkerInterface import ::GetBlockAddress_Out(..), instance EnDecode GetBlockAddress_Out,::RunTimeIDW(..), instance DefaultElem RunTimeIDW, instance EnDecode RunTimeIDW;
import utilities;
import memory_mapped_files;
from ExtFile import ExtractPathAndFile,ExtractPathFileAndExtension,ExtractFileName;
import DynamicID;
from DynID import extract_dynamic_or_library_identification,CONVERTED_ENCODED_DYNAMIC_FILE_NAME_INTO_PATH,
					CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION;
import StdDynamicTypes;
import BitSet;
import typetable;
import ToAndFromGraph;
import EnDecode;
import ProcessSerialNumber;
import LibraryInstance;
import State;
import StdDynamicLowLevelInterface;
import dus_label;
import StdDynamicVersion;
import UnknownModuleOrSymbol;
import pdExtInt;
import DefaultElem;
import LinkerMessages;
import StdMaybe;

// should be moved to Request.icl
ComputeDescAddressTable2_n_args					:== 4;
ComputeDescAddressTable2_n_copy_request_args	:== 6;

init_lazy_dynamic :: !.Int !*DLClientState !*f -> *(Int,*DLClientState,!*f) | FileEnv f;
init_lazy_dynamic dynamic_info_index dl_client_state io
	= init_dynamic2 dynamic_info_index dl_client_state io;

// physically reads in file and initializes the administration for the dynamic by init_dynamic2
init_dynamic :: {#.Char} !Bool !Int !Int !{#String} !*DLClientState !*f -> *(!Int,!*DLClientState,!*f) | FileEnv f & FileSystem f;
init_dynamic file_name False id block_i args dl_client_state io
	= (id,dl_client_state,io);
init_dynamic file_name first_time id block_i args dl_client_state io
	// create a new id
	#! (id,dl_client_state) = new_dynamic_id dl_client_state;

	# msg = "Dynamic ID " +++ toString id +++ " (" +++ fst (ExtractPathFileAndExtension (snd (ExtractPathAndFile file_name))) +++ ")";
	#! dl_client_state = AddDebugMessage msg dl_client_state;
	
	# (id,dl_client_state,io)
		= get_tables_from_dynamic args file_name id dl_client_state io;		

	= init_dynamic2 id dl_client_state io;
where {
	get_tables_from_dynamic :: !{#String} !String !Int !*DLClientState *f -> *(Int,*DLClientState,*f) | FileSystem f;
	get_tables_from_dynamic args file_name dynamic_info_index dl_client_state io
		#! dynamic_access
			= case (size args) of {
				ComputeDescAddressTable2_n_args
					-> "FILE";		// file containing dynamic is read by dynamic rts
				ComputeDescAddressTable2_n_copy_request_args 
					-> "VIEW";		// view passed by the rts is read by dynamic rts
			};
		#! dl_client_state
 			= AddDebugMessage ("Access method: " +++ dynamic_access) dl_client_state;
		| size args == ComputeDescAddressTable2_n_args
			// open dynamic
			#! (ok,dynamic_header,file,io)
				= open_dynamic_as_binary file_name io;
			| not ok
				#! (_,io)
					= close_dynamic_as_binary file io;
				#! msg = "could not open dynamic '" +++ file_name +++ "'";
				#! dl_client_state = AddMessage (LinkerError msg) dl_client_state;
				= (0,dl_client_state,io);

			# (file,dynamic_info_index,dl_client_state,io)
				= read_from_dynamic dynamic_info_index file_name file dl_client_state io dynamic_header;

			# (_,io)
				= close_dynamic_as_binary file io;
			= (dynamic_info_index,dl_client_state,io);

		| size args == ComputeDescAddressTable2_n_copy_request_args
			# file_mapping_handle = toInt args.[4];
			# s_buffer = toInt args.[5];

			# (ok,file)
				= OpenExistingSharedBuffer file_mapping_handle s_buffer
			| not ok
				= abort "get_tables_from_dynamic: OpenExistingSharedBuffer failed";
				
			# (ok,dynamic_header,file)
				= read_dynamic_header file;
			| not ok
				= abort "get_tables_from_dynamic: error reading dynamic header";

			# (file,dynamic_info_index,dl_client_state,io)
				= read_from_dynamic dynamic_info_index file_name file dl_client_state io dynamic_header;
			| CloseExistingSharedBuffer file
				= (dynamic_info_index,dl_client_state,io);
				= abort "unreachable";
}

init_dynamic2 dynamic_info_index dl_client_state io
	#! ({di_disk_type_equivalent_classes,di_n_blocks},dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_info_index];
	| di_n_blocks <= 0
		= abort "init_dynamic2; internal error; dynamic has no blocks";
	
	// lazy dynamics ...
	#! (di_lazy_dynamics_a,dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_info_index].di_lazy_dynamics_a;
	#! (cs_n_lazy_dynamics,dl_client_state) = dl_client_state!cs_n_lazy_dynamics;
	#! n_lazy_disk_dynamics = size di_lazy_dynamics_a;
	#! di_disk_to_rt_dynamic_indices = createArray n_lazy_disk_dynamics 0;
	
	// allocate lazy dynamic ids for each lazy disk dynamic id
	#! dl_client_state = AddDebugMessage ("Lazy dynamics: " +++ toString n_lazy_disk_dynamics) dl_client_state
	#! (di_disk_to_rt_dynamic_indices,cs_n_lazy_dynamics,dl_client_state)
		= loopAst (
			\index (di_disk_to_rt_dynamic_indices,cs_n_lazy_dynamics,dl_client_state) ->
				let {
					msg = toString cs_n_lazy_dynamics +++ ": '" +++ di_lazy_dynamics_a.[index]
				} in
					({di_disk_to_rt_dynamic_indices & [index] = ~cs_n_lazy_dynamics},inc cs_n_lazy_dynamics,AddDebugMessage msg dl_client_state)
			) 
			(di_disk_to_rt_dynamic_indices,cs_n_lazy_dynamics,dl_client_state) n_lazy_disk_dynamics;

	// extend array to include new lazy dynamics
	#! (cs_lazy_dynamic_index_to_dynamic_id,dl_client_state) = get_lazy_dynamic_index_to_dynamic_id dl_client_state;
	#! (last_added_lazy_dynamic,cs_lazy_dynamic_index_to_dynamic_id) = extend_array_nu n_lazy_disk_dynamics cs_lazy_dynamic_index_to_dynamic_id;
	#! s_cs_lazy_dynamic_index_to_dynamic_id = inc last_added_lazy_dynamic;
	#! cs_lazy_dynamic_index_to_dynamic_id
		= ALLOW_LAZY_LIBRARY_REFERENCES
			(loopbAst (associate_lazy_dynamic_with_its_main_dynamic dynamic_info_index) cs_lazy_dynamic_index_to_dynamic_id (s_cs_lazy_dynamic_index_to_dynamic_id - n_lazy_disk_dynamics) s_cs_lazy_dynamic_index_to_dynamic_id)
			cs_lazy_dynamic_index_to_dynamic_id
			;

	#! dl_client_state = { dl_client_state &	cs_lazy_dynamic_index_to_dynamic_id = cs_lazy_dynamic_index_to_dynamic_id,
												cs_n_lazy_dynamics	= cs_n_lazy_dynamics };
	# dl_client_state = { dl_client_state & cs_dynamic_info.[dynamic_info_index].di_disk_to_rt_dynamic_indices = di_disk_to_rt_dynamic_indices };

	// get info about the library instances used by the dynamic
	# (di_library_instance_to_library_index,dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_info_index].di_library_instance_to_library_index;
	# (di_library_index_to_library_name,dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_info_index].di_library_index_to_library_name;
		
	# (x,(dl_client_state,io))
		= (mapSt f [ x \\ x <-: di_library_index_to_library_name] (dl_client_state,io));
	with {
		f required_library_id (dl_client_state=:{cs_library_instances={lis_n_library_instances}},io)
			// extract_dynamic_or_library_identification
			#! ccc = find_library_id (extract_dynamic_or_library_identification required_library_id);
			#! (r,dl_client_state)
				= findQ 0 lis_n_library_instances ccc dl_client_state;
			| isNothing r
				# unnecessary = Just dynamic_info_index;
				# (library_instance_i,_,dl_client_state,io)
					= RegisterLibrary unnecessary required_library_id dl_client_state io;
				= (library_instance_i,(dl_client_state,io));
				= (fromJust r,(dl_client_state,io));
		where {
			findQ i limit func st
				| i == limit
					= (Nothing,st);
					#! (r,st)
						= func i st;
					| isNothing r
						= findQ (inc i) limit func st;
						= (r,st);
						
			find_library_id required_library_id library_instance_i dl_client_state
				| library_instance_i < RTID_LIBRARY_INSTANCE_ID_START 
					= (Nothing,dl_client_state)
				#! (library_id,dl_client_state) = dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_id;
				| library_id == required_library_id
					= (Just library_instance_i,dl_client_state);
					= (Nothing,dl_client_state)
		};
	};
	#! x = to_help_the_type_checker { elem \\ elem  <- x };
	with {
		to_help_the_type_checker :: !{#Int} -> {#Int};
		to_help_the_type_checker i 
			= i;
	};

	# s_library_instance_runtime_ids = size di_library_instance_to_library_index;
	# library_instance_runtime_ids	// indexed by RunTimeID(diskID) to obtain library instance id
		= force_unboxed_int_array (createArray s_library_instance_runtime_ids (-1));
		
	# (library_instance_runtime_ids,_,dl_client_state,io)
		= mapAiSt (convert_string_id_to_runtime_id_for_a_library_instance x) di_library_instance_to_library_index 
			(library_instance_runtime_ids,di_library_index_to_library_name,dl_client_state,io);
	# library_instance_runtime_ids
		= mapAiSt eliminate_library_redirections di_library_instance_to_library_index library_instance_runtime_ids;
	
	// ComputeDescAddress still contains diskIDs instead of real RunTimeIDs, so the conversion table
	// must be preserved.
	# dl_client_state = { dl_client_state & 
			cs_dynamic_info.[dynamic_info_index].di_disk_id_to_library_instance_i = library_instance_runtime_ids
		,	cs_dynamic_info.[dynamic_info_index].di_has_block_been_used = createArray di_n_blocks False
		};

	// printing					
	#! dl_client_state
		= AddDebugMessage "References to type-libraries i.e. type tables" dl_client_state;
	#! (type_tables,dl_client_state)
		= get_type_tables dl_client_state;
	#! (type_tables,dl_client_state)
		= loopAfill print_library_name type_tables dl_client_state;
	#! dl_client_state = { dl_client_state & cs_type_tables = type_tables };
	
	#! (di_type_redirection_table,dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_info_index].di_type_redirection_table;
		
	#! (di_type_redirection_table,(dl_client_state,io))
		= real_mapAiSt convert_to_runtime_idw di_type_redirection_table (dl_client_state,io)
	
	#! dl_client_state = { dl_client_state & cs_dynamic_info.[dynamic_info_index].di_rt_type_redirection_table = di_type_redirection_table };
	= (dynamic_info_index,dl_client_state,io);
where {
	convert_to_runtime_idw i type (dl_client_state,io)
		# (rt_type,(dl_client_state,io))
			= convert_encoded_type_reference_to_rt_type_reference dynamic_info_index type (dl_client_state,io);
			
		# ((type_name,module_name,_,_,_),dl_client_state)
			= get_info_library_instance_type_reference rt_type dl_client_state;

		# runtime_idw = { default_elem & rtid_runtime_id = encode_lib_ref rt_type};
		= (runtime_idw,(dl_client_state,io));
	
	associate_lazy_dynamic_with_its_main_dynamic main_dynamic_id i cs_lazy_dynamic_index_to_dynamic_id
		= { cs_lazy_dynamic_index_to_dynamic_id & [i] = {default_elem & ldi_parent_index = main_dynamic_id} };

	eliminate_library_redirections i _ library_instance_runtime_ids
		= library_instance_runtime_ids;
				
	force_unboxed_int_array :: !*{#Int} -> *{#Int};
	force_unboxed_int_array i = i;
	
	convert_string_id_to_runtime_id_for_a_library_instance x library_instance_string_id (LIK_LibraryInstance {LIK_LibraryInstance | lik_index_in_di_library_index_to_library_name=library_name_i}) s=:(library_instance_runtime_ids,di_library_index_to_library_name,dl_client_state,io)
		// skip reserved elements
		| library_instance_string_id < RTID_DISKID_RENUMBER_START 
			= s
			
		// convert into run-time index for library instance
		#! (library_instance_i,dl_client_state,io)
			= (x.[library_name_i],dl_client_state,io); // DynamicInfo
			
		# library_instance_runtime_ids
			= { library_instance_runtime_ids & [library_instance_string_id] = library_instance_i };
		= (library_instance_runtime_ids,di_library_index_to_library_name,dl_client_state,io);

	print_library_name i a dl_client_state
		// printing
		# (tt_loaded,a) = a![i].tt_loaded;
		# (tt_name,a) = a![i].tt_name;
		# msg = toString i +++ (if tt_loaded " (Loaded)" " (Not loaded)") +++ ": " +++ tt_name;
		#! dl_client_state = AddDebugMessage msg dl_client_state;
		= (a,dl_client_state);
};

read_from_dynamic :: !Int !String !*f !*DLClientState !.a !.DynamicHeader -> *(!*f,!Int,!*DLClientState,!.a) | BinaryDynamicIO f;
read_from_dynamic dynamic_info_index file_name file dl_client_state=:{cs_dlink_dir} io dynamic_header
	// read descriptor usage set table
	#! (ok,descriptor_usage_table,file)
		= read_descriptor_usage_table_from_dynamic dynamic_header file;
	| not ok
		#! msg = "could not read descriptor usage table '" +++ file_name +++ "'";
		#! dl_client_state = AddMessage (LinkerError msg) dl_client_state;
		= (file,0,dl_client_state,io);
	
	// read string table
	#! (ok,stringtable,file)
		= read_string_table_from_dynamic dynamic_header file;
	#! dl_client_state
		= case ok of {
			True
				-> dl_client_state;
			False
				#! msg = "could not read string table from '" +++ file_name +++ "'";
				-> AddMessage (LinkerError msg) dl_client_state;
		};

	// read block table
	#! (ok,block_table,file)
		= read_block_table_from_dynamic dynamic_header file;
	#! dl_client_state
		= case ok of {
			True
				-> dl_client_state;
			False
				#! msg = "could not read block table from '" +++ file_name +++ "'";
				-> AddMessage (LinkerError msg) dl_client_state;
		};

	// read dynamic rts info
	#! (ok2,dynamic_info,file)
		= read_rts_info_from_dynamic dynamic_header file;
	#! dynamic_info
		= FILE_IDENTIFICATION
			{ dynamic_info & 
				di_library_index_to_library_name = { CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION cs_dlink_dir id \\ id <-: dynamic_info.di_library_index_to_library_name }
			,	di_lazy_dynamics_a = { CONVERTED_ENCODED_DYNAMIC_FILE_NAME_INTO_PATH cs_dlink_dir lazy_dynamic_id \\ lazy_dynamic_id <-: dynamic_info.di_lazy_dynamics_a }
			}
			dynamic_info;
		// APPEND_LAZY_DYNAMIC_PATH
		// DynamicInfo
	#! dl_client_state
		= case ok2 of {
			True
				-> dl_client_state;
			False
				#! msg = "could not read dynamic rts info from '" +++ file_name +++ "'";
				-> AddMessage (LinkerError msg) dl_client_state;
		};
	# dynamic_info
		= { dynamic_info &
			di_string_table				= stringtable
		,	di_descriptor_usage_table	= descriptor_usage_table
		,	di_version					= toVersion dynamic_header.version_number
		,	di_file_name				= file_name
		,	di_n_blocks					= size block_table
		};
	# dl_client_state = UpdateDynamicInfo dynamic_info_index dynamic_info dl_client_state
	= (file,dynamic_info_index,dl_client_state,io);

// ComputeDescAddressTable2
LinkPartition :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileSystem f & FileEnv f;
LinkPartition client_id [args] s io
	#! (client_exists,dl_client_state,s) 
		= RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "LinkPartition (internal error): client not registered" client_id dl_client_state s io;

	#! args = ExtractArguments '\n' 0 args [];
	#! l_args = length args
	#! is_non_copy_request = l_args == ComputeDescAddressTable2_n_args;
	#! is_copy_request = l_args == ComputeDescAddressTable2_n_copy_request_args;
	| not (is_non_copy_request || is_copy_request)
		= internal_error ("LinkPartition (internal error): didn't get expected arguments " +++ toString l_args) client_id dl_client_state s io;

	// extract arguments
	#! args = { arg \\ arg <- args };
	#! file_name = args.[0];
	#! first_time = args.[1] == "True";
	#! id = toInt args.[2];
	#! block_i = toInt args.[3];
	
	#! title = "LinkPartition, patition: " +++ toString block_i +++ " (" +++ ExtractFileName file_name +++ ")";
	#! dl_client_state = output_message_begin title client_id dl_client_state
		
	#! (id,dl_client_state,io)
		= init_dynamic file_name first_time id block_i args dl_client_state io;
		
	// mark block as used ...
	#! (di_has_block_been_used,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_has_block_been_used;
	#! di_has_block_been_used
		= { x \\ x <-: di_has_block_been_used };		// make unique
	#! dl_client_state = { dl_client_state & 
			cs_dynamic_info.[id].di_has_block_been_used = { di_has_block_been_used & [block_i] = True }
		};
	// ... mark block as used
		
	# ({di_version,di_string_table,di_descriptor_usage_table,di_library_instance_to_library_index},dl_client_state) = dl_client_state!cs_dynamic_info.[id];

	#! n_disk_libraries = size di_library_instance_to_library_index;
	#! used_disk_libraries = NewBitSet n_disk_libraries;
	
	#! (ok,latest_version,dl_client_state,s)
		= eager_read_version di_version dl_client_state s;

	#! (dlink_dir,s) = GetDynamicLinkerDirectory s;
	#! module_name = dlink_dir +++ "\\" +++ copy_string_to_graph +++ "_" +++ (toFileNameSubString latest_version) +++ ".obj";
	#! symbol_name = "e__DynamicGraphConversion__d" +++ copy__string__to__graph +++ "__" +++ toFileNameSubString latest_version;

	#! (Just main_library_instance_i,dl_client_state)
		= dl_client_state!cs_main_library_instance_i;	
	# conversion_dus_label
		= { default_elem &
			dusl_label_name				= symbol_name
		,	dusl_library_instance_i		= main_library_instance_i
		,	dusl_linked					= False
		};
	// ...
	# initial_labels = [];

	// link in graph conversion function if necessary ...
	# (do_dump_dynamic,dl_client_state)
		= dl_client_state!do_dump_dynamic;
	# (a,dl_client_state,s,io)
		= case do_dump_dynamic of {
			True
				-> (0,dl_client_state,s,io);
			_
				# (maybe_to_graph_entry,dl_client_state)
					= get_to_graph_function_address2 (Just latest_version) dl_client_state;
				| isNothing maybe_to_graph_entry
					// Required conversion function not present
					-> abort ("LinkPartition: required conversion function not found >>" +++ toFileNameSubString latest_version);
				
				#! ({tafge_conversion},i)
					= fromJust maybe_to_graph_entry
				#! (a,dl_client_state,s,io)
					= case tafge_conversion of {
						Nothing
							# (dl_client_state,s,io)
								= add_object_module_to_library_instance module_name main_library_instance_i dl_client_state s io;
							# (_,[address:_],dl_client_state,io)
								= load_code_library_instance (Just [conversion_dus_label]) main_library_instance_i dl_client_state io;
							# dl_client_state
								= { dl_client_state &
									cs_to_and_from_graph.tafgt_to_graphs.[i].tafge_conversion = Just address };
							-> (address,dl_client_state,s,io);
						Just address
							-> (address,dl_client_state,s,io);
					};
				-> (a,dl_client_state,s,io);
		};
	// ...
				
	// address 	 
	#! (n_addresses,used_disk_libraries)
		= mapAiSt (compute_used_libraries_in_current_block block_i) di_descriptor_usage_table (length initial_labels,used_disk_libraries);
	#! (used_disk_libraries,(dus_labels,dl_client_state,s,io))
		= enum_setSt (link_library_instance di_string_table di_descriptor_usage_table block_i id n_addresses) used_disk_libraries (initial_labels,dl_client_state,s,io);
	
	// -----------------------------------------------
	#! addresses = createArray n_addresses 0;
	#! dus_labels_a = createArray n_addresses default_elem;
		
	#! (addresses,dus_labels)
		= foldSt fill_addresses_and_dus_labels dus_labels (addresses,dus_labels_a);
		
	#! dus_labels = [conversion_dus_label : [ dus_label \\ dus_label <-: dus_labels ] ];
	#! symbol_addresses = [ a : [ address \\ address <-: addresses ] ];
		
	#! (dl_client_state,io)
		= case first_time of {
			False
				-> (dl_client_state,SendAddressToClient client_id (/* toString DYN_OK,*/ id,symbol_addresses) io);
			True
				#! ({di_disk_id_to_library_instance_i,di_disk_to_rt_dynamic_indices,di_rt_type_redirection_table},dl_client_state) = dl_client_state!cs_dynamic_info.[id];
				#! msg
					= {	gba_o_diskid_to_runtimeid			= di_disk_id_to_library_instance_i
					,	gba_o_disk_to_rt_dynamic_indices	= di_disk_to_rt_dynamic_indices
					,	gba_o_id							= id
					,	gba_o_addresses						= (FromIntToString id) +++ foldl (\s i -> s +++ (FromIntToString i)) "" symbol_addresses
					,	gba_o_rt_type_redirection_table		= di_rt_type_redirection_table
					}
				-> (dl_client_state,SendAddressToClient client_id (encode msg) io);
		};

	// check for errors		
	#! (ok,dl_client_state)
		= IsErrorOccured dl_client_state;
	| not ok
		= (not ok,client_id,AddToDLServerState dl_client_state s,io);

	// verbose	
	# messages
		= if do_dump_dynamic
			(foldl2 produce_verbose_output2 [] (tl dus_labels) (tl symbol_addresses))
			(foldl2 produce_verbose_output2 [] dus_labels symbol_addresses);
	#! dl_client_state
		= DEBUG_INFO (SetLinkerMessages messages dl_client_state) dl_client_state;

	= (not ok,client_id,AddToDLServerState dl_client_state s,io);
where {
	
	fill_addresses_and_dus_labels:: !u:DusLabel !*(!*{#Int},!*{#DusLabel}) -> (!*{#Int},!*{#DusLabel});
	fill_addresses_and_dus_labels dus_label=:{dusl_linked,dusl_ith_address,dusl_address} (addresses,dus_labels_a)
		#! addresses
			= { addresses & [dusl_ith_address] = dusl_address };
		#! dus_labels_a
			= { dus_labels_a & [dusl_ith_address] = dus_label };
		= (addresses,dus_labels_a);
	
	// computes which disk libraries are needed to build the current block
	compute_used_libraries_in_current_block :: !.Int .a !.DescriptorUsageEntry !*(!.Int,!*BitSet) -> (Int,.BitSet);
	compute_used_libraries_in_current_block block_i _ {bitset,prefix_set_and_string_ptr,dus_library_instance_nr_on_disk} (ith_address,used_disk_libraries)
		#! (prefixes,_,_)
			= determine_prefixes3 prefix_set_and_string_ptr;

		#! ith_address
			= if (fst (isBitSetMember bitset block_i)) (ith_address + length prefixes) ith_address;
		#! used_disk_libraries
			= AddBitSet used_disk_libraries dus_library_instance_nr_on_disk;
			
		= (ith_address,used_disk_libraries);
		
	lookup_library_id :: !Int (!*{#Int},!{#{String}},!*DLClientState) -> (!*{#Int},!{#{String}},!*DLClientState);
	lookup_library_id index (type_table_id_array,library_names,dl_client_state)
		# (type_table_id,dl_client_state)
			= AddReferenceToTypeTable library_names.[index] dl_client_state;
		# type_table_id_array
			= { type_table_id_array & [index] = type_table_id };
		= (type_table_id_array,library_names,dl_client_state);

	Pl [] s
		= s;
	Pl [ModuleUnknown module_name symbol_name:xs] s
		= Pl xs ("(" +++ module_name +++ "," +++ symbol_name +++ ")\n " +++ s);
};

link_library_instance stringtable descriptor_usage_table block_i id n_addresses disk_library_i (dus_labels,dl_client_state,s,io)
	#! (stringtable,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_string_table;
	#! (descriptor_usage_table,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_descriptor_usage_table;
	#! (library_instance_i,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_disk_id_to_library_instance_i.[disk_library_i];

	#! (labels_linked,n_addresses2,labels,dl_client_state)
		= mapAiSt dus_entry_of_proper_library_instance_and_block descriptor_usage_table (True,0,[],dl_client_state);
	| n_addresses <> n_addresses2
		= abort "link_library_instance; internal error; number of addresses should be the same";

	// print ...
	# title
		= "Linking library #" +++ toString library_instance_i +++ " (block " +++ toString block_i +++ ")";
	#! dl_client_state
		= AddDebugMessage title dl_client_state;
	// ... print
		
	# (dl_client_state,s,io)
		= case labels_linked of {
			True
				// all current library instance labels have already been linked.
				-> (dl_client_state,s,io);
			False	

				#! (_,_,dl_client_state/*,s*/,io)
					= load_code_library_instance (Just labels) library_instance_i dl_client_state /*s*/ io;
					 
				// what types have been linked in under water?
				#! (li_type_table_i,dl_client_state)
					= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
					
				// If a type is eagerly linked i.e. all labels implementing the type have been linked, then 
				// the LoadLibraryInstance_new-application is unnecessary because it is guaranteed that all
				// type labels have already been linked.
				// If lazy linking of type is to be supported, the unlinked_labels_of_types might become
				// handy.
				// 
				// Note:
				// An efficiency improving technique might be to separate the actual link/relocation process
				// from the marking/module offset computation. Then all libraries required to satisfy a
				// request are linked at once.				
				-> (dl_client_state,s,io);
		};	
	#! (new_dus_labels,dl_client_state)
		= mapSt compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class3 labels dl_client_state;
	= (dus_labels ++ new_dus_labels,dl_client_state,s,io);
where {
	compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class3 :: !DusLabel !*DLClientState -> (!DusLabel,*DLClientState);
	compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class3 dus_label dl_client_state
		#! (label_address,dl_client_state)
			= compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class2 dus_label dl_client_state;
		#! dus_label
			= { dus_label &
				dusl_address = label_address
			};
			
		= (dus_label,dl_client_state);	
	where {
		compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class2 :: !DusLabel !*DLClientState -> *(Int,*DLClientState);
		compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class2 {dusl_label_name,dusl_library_instance_i} dl_client_state
			#! (maybe_label,dl_client_state)
				= findLabel dusl_label_name dusl_library_instance_i dl_client_state;
			| isNothing maybe_label
				= abort ("compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class; internal error; label should exist '" +++ dusl_label_name +++ "'");
				
			#! (file_n,symbol_n)
				= fromJust maybe_label;
			#! (maybe_label_address,dl_client_state)
				= isLabelImplemented file_n symbol_n dl_client_state;
			| isNothing maybe_label_address
				= abort ("compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class; internal error; label should exist (unmarked) '" +++ dusl_label_name +++ "'" +++ toString dusl_library_instance_i);

			#! label_address
				= fromJust maybe_label_address
				
			// print ...
			#! (file_name,dl_client_state) = dl_client_state!app_linker_state.xcoff_a.[file_n].file_name
			# file_n_symbol_n = " (" +++ toString file_n +++ "," +++ toString symbol_n +++ ")";
			# title = "Label: " +++ dusl_label_name +++ " at " +++ hex_int label_address +++ file_n_symbol_n;
			#! dl_client_state = AddDebugMessage title dl_client_state;
			# title = " in file: " +++ (ExtractFileName file_name);
			#! dl_client_state = AddDebugMessage title dl_client_state;
			// ... print

			= (label_address,dl_client_state);
	}; // compute_addresses_for_labels_belonging_to_an_implemented_type_equivalent_class3

	dus_entry_of_proper_library_instance_and_block :: .a !.DescriptorUsageEntry !*(.Bool,.Int,u:[w:DusLabel],*DLClientState) -> *(Bool,Int,v:[x:DusLabel],*DLClientState), [w <= x, u <= v];
	dus_entry_of_proper_library_instance_and_block _ dus_entry=:{bitset,prefix_set_and_string_ptr,dus_library_instance_nr_on_disk} (labels_linked,ith_address,labels,dl_client_state)
		#! is_entry_block_member
			= (fst (isBitSetMember bitset block_i));
		| not is_entry_block_member
			= (labels_linked,ith_address,labels,dl_client_state);
			
		| disk_library_i == dus_library_instance_nr_on_disk
			// same library and in the same block
			= generate_label_name ith_address labels dl_client_state;
			
			#! (prefixes,_,_)
				= determine_prefixes3 prefix_set_and_string_ptr;
			= (labels_linked,ith_address + length prefixes,labels,dl_client_state);

	where {
		generate_label_name ith_address labels dl_client_state
			// get descriptor name	
			#! (prefixes,string_offset,_)
				= determine_prefixes3 prefix_set_and_string_ptr;			
		
			#! descriptor_module_table
				= []; // overbodig?
			#! (descriptor_and_module_name=:(descriptor_name,module_name),descriptor_module_table)
				= get_descriptor_and_module_name string_offset stringtable descriptor_module_table;
				
			#! used_library_instances
				= NewBitSet 0; // overbodig?
			#! (dus_implementation=:{dusi_linked},dl_client_state)
				= determine_implementation_for_dus_entry descriptor_name module_name dus_library_instance_nr_on_disk prefix_set_and_string_ptr id dl_client_state;
				
			// insert prefixes
			#! (l,(ith_address,_))
				= mapSt generate_dus_label2 prefixes (ith_address,dus_implementation);
			= (labels_linked && dusi_linked,ith_address,labels ++ l,dl_client_state);
		where {
			generate_dus_label2 prefix (ith_address,dus_implementation)
				#! (dus_label,dus_implementation)
					= generate_dus_label prefix dus_implementation;
				#! dus_label
					= { dus_label &
						dusl_ith_address = ith_address
					};
				= (dus_label,(inc ith_address,dus_implementation));
		} // generate_label_name
	} // dus_entry_of_proper_library_instance_and_block

}

HandleRegisterLazyDynamicMessage :: !ProcessSerialNumber [String] !*DLServerState !*f -> (!Bool,!ProcessSerialNumber,!*DLServerState, !*f) | FileEnv f;
HandleRegisterLazyDynamicMessage client_id [args] s io
	#! (client_exists,dl_client_state,s) 
		= RemoveFromDLServerState client_id s;
	| not client_exists
		= internal_error "HandleRegisterLazyDynamicMessage (internal error): client not registered" client_id dl_client_state s io;

	#! (dl_client_state) = AddDebugMessage "HandleRegisterLazyDynamicMessage" dl_client_state;
	#! rt_lazy_dynamic_index = extract_int_argument args // run-time ptr
		with {
			extract_int_argument s
				| size s==5 && s.[4]=='\n'
					= FromStringToInt s 0;
		}
	// Using the run-time lazy dynamic index (rt_lazy_dynamic_index), the id of the main dynamic i.e. the 
	// top-level dynamic is determined. 
	#! (result,dl_client_state)
		= get_dynamic_id rt_lazy_dynamic_index dl_client_state
	| isNothing result
		= abort ("HandleRegisterLazyDynamicMessage; get_dynamic_id; lazy_dynamic_index cannot be found (" +++ toString rt_lazy_dynamic_index +++ ")");
		
	// dynamic found
	// 1. map file
	// 2. initialize dynamic (using code in ComputeDescAddressTable2)
	#! (disk_lazy_dynamic_index,id) = fromJust result;
	#! main_dynamic_id = id; // run-time pointer
	// extract file name from dynamic containing the lazy dynamic	
	# (file_name,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_lazy_dynamics_a.[disk_lazy_dynamic_index];

	// assign the lazy dynamic a run-time id
	#! (id,dl_client_state) = new_dynamic_id dl_client_state;
	#! lazy_dynamic_id = id;

	#! (lazy_dynamic_info=:{ldi_lazy_dynamic_index_to_dynamic=has_lazy_dynamic_already_been_initialized},dl_client_state)
		= dl_client_state!cs_lazy_dynamic_index_to_dynamic_id.[~rt_lazy_dynamic_index];
	#! initialized_lazy_dynamic
		= isJust has_lazy_dynamic_already_been_initialized;
		// the dynamic associated from which the build_lazy_block wants to build a block has already
		// been initialized.
		
	#! dl_client_state
		= case initialized_lazy_dynamic of {
			True	
					-> dl_client_state;
			_		
					# lazy_dynamic_info = { lazy_dynamic_info & ldi_lazy_dynamic_index_to_dynamic = Just id };
					-> { dl_client_state & cs_lazy_dynamic_index_to_dynamic_id.[~rt_lazy_dynamic_index] = lazy_dynamic_info };
		};
		
	// map file into memory of client ...
	# client_process_id = GetOSProcessSerialNumber client_id;
	# (dynamic_rts_process_handle,st)
		= OpenProcess (STANDARD_RIGHTS_REQUIRED bitor PROCESS_ALL_ACCESS) FALSE client_process_id initialState;

	# (ok,file,exported_handle)
		= CreateSharedBufferFromFile2 dynamic_rts_process_handle file_name;
	| not ok
		= abort "could not create memory mapped file";

	// body ...		
	# (file,id,dl_client_state,io)
		= case initialized_lazy_dynamic of {
			False
				# (ok,dynamic_header,file)
					= read_dynamic_header file;
				| not ok
					-> abort "get_tables_from_dynamic: error reading dynamic header";
			
				# (file,id,dl_client_state,io)
					= read_from_dynamic id file_name file dl_client_state io dynamic_header;
				-> (file,id,dl_client_state,io);
			True
				-> (file,fromJust has_lazy_dynamic_already_been_initialized,dl_client_state,io);
		};
			
	| not (CloseExistingSharedBuffer file) || not (CloseST st)
		= abort "stop";
	// ... map file into memory of client
	
	// initialize dynamic
	#! (dl_client_state,io)
		= case initialized_lazy_dynamic of {
			False
				#! (_,dl_client_state,io)
					= init_lazy_dynamic id dl_client_state io;
				// lazy dynamic at rt_lazy_dynamic_index is assigned dynamic id, now type references must be
				// converted. Promotion of lazy dynamic to a dynamic
				-> (dl_client_state,io);
			True
				-> (dl_client_state,io);
		};
		
	# (di_string_table,dl_client_state) = dl_client_state!cs_dynamic_info.[id].di_string_table;

	// msg ...
	#! ({di_disk_id_to_library_instance_i,di_disk_to_rt_dynamic_indices,di_rt_type_redirection_table},dl_client_state) = dl_client_state!cs_dynamic_info.[id];

	// due to 1.3 bug, a six tuple cannot be exported. Therefore I pack the file_name
	// with the exported handle.
	#! msg
		= ((exported_handle,
		file_name),
		di_disk_id_to_library_instance_i,
		// lazy dynamics...
		 di_disk_to_rt_dynamic_indices,
		// ... lazy dynamics
		id
		,di_rt_type_redirection_table
		);
	// ... msg
	#! io = SendAddressToClient client_id (encode msg) io;
	#! ok = True
	= (not ok,client_id,AddToDLServerState dl_client_state s,io);

class convert_encoded_type_reference_to_rt_type_reference a :: !Int !a !(!*DLClientState,*f) -> *(!a,!(!*DLClientState,!*f)) | FileEnv f;

instance convert_encoded_type_reference_to_rt_type_reference LibRef
where {
	convert_encoded_type_reference_to_rt_type_reference id lit_type_reference st
		= convert_encoded_type_reference_to_rt_type_reference_LibRef id lit_type_reference st;
}; 

convert_encoded_type_reference_to_rt_type_reference_LibRef :: !.Int !.LibRef !*(!*DLClientState,*a) -> *(.LibRef,*(*DLClientState,*a))| FileEnv a;
convert_encoded_type_reference_to_rt_type_reference_LibRef id (LibRef disk_library_instance) (dl_client_state,io)
	#! ({di_disk_id_to_library_instance_i},dl_client_state) = dl_client_state!cs_dynamic_info.[id];
	= (LibRef (di_disk_id_to_library_instance_i.[disk_library_instance]),(dl_client_state,io));
	
instance convert_encoded_type_reference_to_rt_type_reference LibraryInstanceTypeReference
where {
	convert_encoded_type_reference_to_rt_type_reference id lit_type_reference st
		= convert_encoded_type_reference_to_rt_type_reference_LibraryInstanceTypeReference id lit_type_reference st;
};

convert_encoded_type_reference_to_rt_type_reference_LibraryInstanceTypeReference :: !.Int !.LibraryInstanceTypeReference !*(!*DLClientState,*a) -> *(.LibraryInstanceTypeReference,*(!*DLClientState,!*a)) | FileEnv a;
convert_encoded_type_reference_to_rt_type_reference_LibraryInstanceTypeReference id (LIT_TypeReference lib_ref tio_type_reference) st
	#! (lib_ref,st)
		= convert_encoded_type_reference_to_rt_type_reference id lib_ref st;
	= (LIT_TypeReference lib_ref tio_type_reference,st);