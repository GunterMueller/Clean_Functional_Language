implementation module DLState;

from containers import arg_is_strict;
import SearchObject;
import ReadObject;
import link_library_instance;
import StdEnv;
import State;
import ProcessSerialNumber;
from ExtFile import ExtractPathAndFile;
import Set;
import DynamicLink;
import Directory;
import ExtInt;
import dynamics; // internal constants for dynamics
import DynamicID;
import StdDynamicLowLevelInterface;
import typetable;
import LibraryInstance;
import type_io_equal_type_defs;
// import TypeImplementationTable;
import ToAndFromGraph;
import ExtList;
import link_switches;
from utilities import fold2St;
import ExtString;
from type_io_common import UnderscoreSystemModule;
import predefined_types;
from DynID import DS_CONVERSION_DIR;
import StdDynamicTypes;
import RWSDebugChoice;
import StdDynamicVersion;
import DefaultElem;
import type_io_read;
import dus_label;
import pdSortSymbols;
import LinkerMessages;
import StdMaybe;
import NamesTable;
import pdSymbolTable;
import Redirections;
from TypeEquivalences import :: TypeEquivalences, newTypeEquivalences;

:: *DLServerState
	= {
	// general data
		quit_server						:: !Bool
	,	application_path				:: !String
	,	static_application_as_client	:: !Bool	
	// clients
	,	dl_client_states				:: *[*DLClientState]
	// conversions
	,	convert_functions				:: !ConvertFunctions
	// NEW TO HANDLE .LIB DEMANDS
	,	dlss_lib_mode					:: !Bool
	,	dlss_lib_command_line			:: !{{#Char}}
	};

instance DefaultElemU DLServerState
where {
	default_elemU
		= {
		// general data
			quit_server						= False
		,	application_path				= ""
		,	static_application_as_client	= False		
		// clients
		,	dl_client_states				= []
		// conversions
		,	convert_functions				= default_convertfunctions
		// NEW TO HANDLE .LIB DEMANDS
		,	dlss_lib_mode					= False
		,	dlss_lib_command_line			= {}
		};
};

AddToDLServerState :: *DLClientState *DLServerState -> *DLServerState; 	
AddToDLServerState dl_client_state dl_server_state=:{dl_client_states}
	# dl_client_state = AddDebugMessage "" dl_client_state;
	# dl_client_state = AddDebugMessage "" dl_client_state;
	= { dl_server_state & dl_client_states = [dl_client_state:dl_client_states] };

RemoveFromDLServerState :: !ProcessSerialNumber !*DLServerState -> (!Bool,!*DLClientState,!*DLServerState);
RemoveFromDLServerState client_id dl_server_state=:{dl_client_states}
	#! (l,r)
		= splitAtPred f dl_client_states [] [];
	#! (l_empty,l)
		=  is_empty l;
	| not l_empty
		#! dl_server_state = { dl_server_state & dl_client_states	= r };
		= (True,hd l,dl_server_state);
		
		= (False,default_elemU,{dl_server_state & dl_client_states = r});
where {
	f dl_client_state=:{id}
		= (id == client_id,dl_client_state);
};	
	
acc_dl_client_states :: ([*DLClientState] -> (.x,[*DLClientState])) !*DLServerState -> (.x,!*DLServerState);
acc_dl_client_states f dl_server_state=:{dl_client_states}
	#! (x,dl_client_states)
		= f dl_client_states;
	= (x, {dl_server_state & dl_client_states = dl_client_states} );
	
app_dl_client_states :: ([*DLClientState] -> [*DLClientState]) !*DLServerState -> *DLServerState;
app_dl_client_states f dl_server_state=:{dl_client_states}
	= {dl_server_state & dl_client_states = f dl_client_states};

selacc_client_state :: !ProcessSerialNumber (*DLClientState -> (.x,*DLClientState)) !*DLServerState -> (.x,!*DLServerState);
selacc_client_state client_id g dl_server_state=:{dl_client_states}
	#! (l,r)
		= splitAtPred f dl_client_states [] [];
	#! (l_empty,l)
		=  is_empty l;
	| not l_empty
		#! (x,l)
			= g (hd l);
		#! dl_server_state = { dl_server_state & dl_client_states = [l:r] };
		= (x,dl_server_state);
where {
	f dl_client_state=:{id}
		= (id == client_id,dl_client_state);
};

selacc_app_linker_state :: !ProcessSerialNumber !(*State -> *(.a,*State)) !*DLServerState -> *(.a,*DLServerState);
selacc_app_linker_state client_id f dl_server_state
	#! (x,dl_server_state)
		= selacc_client_state client_id w dl_server_state;
	= (x,dl_server_state);
where {
	w dl_client_state=:{app_linker_state}
		#! (x,app_linker_state)
			= f app_linker_state;
		= (x, {dl_client_state & app_linker_state = app_linker_state});
};

:: ConversionInfo
	= {
		ci_version						:: !Version
	,	ci_has_from_graph_been_added	:: !Bool
	,	ci_has_to_graph_been_added		:: !Bool
	};
	
:: LazyDynamicInfo 
	= {
		ldi_lazy_dynamic_index_to_dynamic	:: !Maybe Int
	,	ldi_parent_index					:: !Int 				// index in cs_dynamic_info
	};
	
instance DefaultElem LazyDynamicInfo
where {
	default_elem
		= {
			ldi_lazy_dynamic_index_to_dynamic	= Nothing
		,	ldi_parent_index					= 0xffffffff
		};
};

instance DynamicIDs DLClientState
where {
	new_dynamic_id dl_client_state=:{dynamic_ids}
		# (id,dynamic_ids) = new_dynamic_id dynamic_ids;
		= (id,{dl_client_state & dynamic_ids = dynamic_ids});
		
	free_dynamic_id id dl_client_state=:{dynamic_ids}
		# dynamic_ids = free_dynamic_id id dynamic_ids;
		= {dl_client_state & dynamic_ids = dynamic_ids};
		
	is_valid_id id dl_client_state=:{dynamic_ids}
		# dynamic_ids = is_valid_id id dynamic_ids;
		= {dl_client_state & dynamic_ids = dynamic_ids};

	is_valid_id2 id dl_client_state=:{dynamic_ids}
		# (ok,dynamic_ids) = is_valid_id2 id dynamic_ids;
		= (ok,{dl_client_state & dynamic_ids = dynamic_ids});
};

acc_dynamic_ids :: (*DynamicID -> (.x,!*DynamicID)) !*DLClientState -> (.x,!*DLClientState);
acc_dynamic_ids f dl_client_state=:{dynamic_ids}
	# (x,dynamic_ids) = f dynamic_ids;
	= (x,{dl_client_state & dynamic_ids = dynamic_ids});
	
instance DefaultElemU DLClientState
where {
	default_elemU
		= { 
		// client identification
			id					= DefaultProcessSerialNumber
		,	initial_link		= False
		// application linker state
		,	app_linker_state	= EmptyState
		// support for block dynamics
		,	dynamic_ids			= default_dynamic_id
		// Library implementation
		,	cs_main_library_name	= {}
		,	cs_type_tables			= {}
		,	cs_dynamic_info			= {}
		,	cs_library_instances	= default_library_instances
		,	cs_main_library_instance_i	= Nothing	
		,	cs_intra_type_equalities	= default_eq_types_state
		,	cs_to_and_from_graph		= default_elemU
		,	cs_n_fixed_available_types	= Nothing
		,	do_dump_dynamic			= False
		,	cs_n_lazy_dynamics		= INITIAL_LAZY_DYNAMIC_INDEX
		,	cs_lazy_dynamic_index_to_dynamic_id	= createArray INITIAL_LAZY_DYNAMIC_INDEX default_elem
		,	cs_share_runtime_system	= False
		,	cs_conversion			= []
		,	cs_dlink_dir			= ""
		,	cs_type_equivalences = newTypeEquivalences
		};
};

// ADDED
instance AddMessage DLClientState
where {
	AddMessage linker_message dl_client_state=:{app_linker_state}
		#! app_linker_state = AddMessage linker_message app_linker_state;
		= {dl_client_state & app_linker_state = app_linker_state};

	AddDebugMessage linker_message dl_client_state=:{app_linker_state}
		#! app_linker_state = AddDebugMessage linker_message app_linker_state;
		= {dl_client_state & app_linker_state = app_linker_state};
		
	IsErrorOccured dl_client_state=:{app_linker_state}
		#! (ok,app_linker_state) = IsErrorOccured app_linker_state;
		= (ok,{dl_client_state & app_linker_state = app_linker_state});
		
	GetLinkerMessages dl_client_state=:{app_linker_state}
		#! (messages,app_linker_state) = GetLinkerMessages app_linker_state;
		= (messages,{ dl_client_state & app_linker_state = app_linker_state });
		
	SetLinkerMessages messages dl_client_state=:{app_linker_state}
		#! app_linker_state = SetLinkerMessages messages app_linker_state;
		= {dl_client_state & app_linker_state = app_linker_state};
};

app_state ::  (*State -> *State) !*DLClientState -> *DLClientState;
app_state f dl_client_state=:{app_linker_state}
	= { dl_client_state & app_linker_state = f app_linker_state };
	

acc_state ::  (*State -> (!.x,!*State)) !*DLClientState -> (!.x,*DLClientState);
acc_state f dl_client_state=:{app_linker_state}
	# (x,app_linker_state)
		= f app_linker_state;
	= (x,{dl_client_state & app_linker_state = app_linker_state});
	
class AppPdState s
where {
	app_pd_state :: !(*PDState -> *PDState) !*s -> *s
};

instance AppPdState DLClientState
where {
	app_pd_state f dl_client_state
		= app_state (\s=:{pd_state} -> {s & pd_state = f pd_state}) dl_client_state
};

instance AppPdState State
where {
	app_pd_state f state=:{pd_state}
		= {state & pd_state = f pd_state};
};

class AccPdState s
where {
	acc_pd_state :: !(*PDState -> (!.x,!*PDState)) !*s -> (!.x,!*s)
};

instance AccPdState State
where {
	acc_pd_state f state=:{pd_state}
		#! (x,pd_state)
			= f pd_state;
		= (x,{ state & pd_state = pd_state});
};

instance AccPdState DLClientState
where {
	acc_pd_state f dl_client_state=:{app_linker_state}
		#! (x,app_linker_state)
			= acc_pd_state f app_linker_state;
		= (x,{dl_client_state & app_linker_state = app_linker_state});
};

// --------------------------------------------------------------------------------------------------------------------------
// VERSION MANAGEMENT OF CONVERSION FUNCTIONS

:: ConvertFunctions = {
		graph_to_string :: [Version]
	,	string_to_graph :: [Version]
	};
	
default_convertfunctions :: ConvertFunctions;
default_convertfunctions 
	= { ConvertFunctions |
		graph_to_string = []
	,	string_to_graph = []
	};
		
/*
** Two situations at the moment, looking for
** - an appropriate graph_to_string function (write)
**   The highest major and minor version are being used to store dynamics. 
** - an appropriate string_to_graph function (read)
**   The expected and required major version numbers *must* match. Because
**   minor version number stand for non-structural bugfixes, the highest
**   minor version is taken.
**
** The situation is different when using unique and/or lazy read and written
** dynamics. An unique dynamic should probably always be saved using the 
** major version used during storing of the dynamic, the minor could be the 
** most recent. This is also valid for a lazily read or written dynamic.
**
** The major version number is mainly for (large) structural changes to the
** conversion functions e.g. the arity of each function is stored in five
** bits, hence an arity of maximal 31 is the limit. This can be improved by
** making the reasonable assumption that a partial arity of 30 should be
** enough. The full arity whatever it is can then be represented by zero. In
** this case zero is interpreted differently, so a major version change is
** necessary.
** An example for minor change is a check that the arity of the function is
** smaller than the 31-limit. This change is minor because it does not affect
** the interpretation of the dynamic.
**
** hex ASCII representation of the 4 byte version number:
** 0	(msb): reserved e.g. flags for endianess, without pointers/with pointers, uniqueness or not
** 1 		 : major, higher part
** 2 		 : major, lower part
** 3		 : minor 
*/	

eager_read_version :: !Version !*DLClientState !*DLServerState -> (!Bool,!Version,!*DLClientState,!*DLServerState);	
eager_read_version {major=major_required} dl_client_state dl_server_state=:{convert_functions={string_to_graph}} 
	#! minors
		= filter (\{major} -> major == major_required) string_to_graph;
	| isEmpty minors
		#! msg
			= "No string_to_graph function with major version " +++ toString major_required +++ " present"
		#! dl_client_state
			= AddMessage (LinkerError msg) dl_client_state;
		= (False,DefaultVersion,dl_client_state,dl_server_state);
	= (True,last minors,dl_client_state,dl_server_state);
	
eager_write_version :: !*DLClientState !*DLServerState -> (!Bool,!Version,!*DLClientState,!*DLServerState);	
eager_write_version dl_client_state dl_server_state=:{convert_functions={graph_to_string=[]}}
	= abort "eager_write_version; there are no conversion functions";

eager_write_version dl_client_state dl_server_state=:{convert_functions={graph_to_string}}
	= (True,last graph_to_string,dl_client_state,dl_server_state); 
	
GetDynamicLinkerDirectory :: !*DLServerState -> (!String,!*DLServerState);
GetDynamicLinkerDirectory dl_server_state=:{application_path}
	= (application_path +++ "\\" +++ DS_CONVERSION_DIR,dl_server_state);

InitServerState :: !*DLServerState !*a -> (!*DLServerState,!*a) | FileEnv a;
InitServerState dl_server_state=:{convert_functions} io
	#! (dlink_dir,dl_server_state)
		= GetDynamicLinkerDirectory dl_server_state;
	#! ((ok,dlink_path),io)
		= accFiles (pd_StringToPath dlink_dir) io
	| not ok
		= abort "InitServerState: internal error 1";
			
	#! ((dir_error,dir_entries),io)
		= accFiles (getDirectoryContents dlink_path) io
	| dir_error <> NoDirError
		= abort "InitServerState: internal error 2";

	#! (graph_to_string,string_to_graph)
		= build_conversions dir_entries [] [];
	#! convert_functions
		= { convert_functions &
			graph_to_string = sortBy less_version graph_to_string 
		,	string_to_graph = sortBy less_version string_to_graph
		};
	#! dl_server_state
		= { DLServerState | dl_server_state &
			convert_functions 	= convert_functions
		};
	= (dl_server_state,io);
where {
	// smallest major and minor at start of the version list
	less_version {major=major1,minor=minor1} {major=major2,minor=minor2}
		| major1 < major2
			= True;
			| major1 == major2
				= minor1 < minor2;
				= False;

	build_conversions [] graph_to_string string_to_graph
		= (graph_to_string,string_to_graph);
	build_conversions [{fileName}:ds] graph_to_string string_to_graph
		#! (found,s_prefix)
			= starts copy_graph_to_string_0x fileName;
		| not found
			#! (found,s_prefix)
				= starts copy_string_to_graph_0x fileName;
			| not found
				= build_conversions ds graph_to_string string_to_graph;
				
				// a string_to_graph function found
				#! version
					= from_base_i fileName 16 s_prefix 8;
				= build_conversions ds graph_to_string [toVersion version:string_to_graph];
					
			// a graph_to_string function
			#! version
				= from_base_i fileName 16 s_prefix 8;
			= build_conversions ds [toVersion version:graph_to_string] string_to_graph;

	copy_graph_to_string_0x
		=> copy_graph_to_string +++ "_0x";
		
	copy_string_to_graph_0x
		=> copy_string_to_graph +++ "_0x";
}

instance TypeTableOps DLClientState
where {
	AddReferenceToTypeTable type_table_reference dl_client_state
		# (cs_type_tables,dl_client_state)
			= get_type_tables dl_client_state;
		# (type_table_index,cs_type_tables)
			= AddReferenceToTypeTable type_table_reference cs_type_tables;
		# dl_client_state
			= { dl_client_state &
				cs_type_tables = cs_type_tables
			};
		= (type_table_index,dl_client_state);
		
	AddTypeTable type_table_index type_table dl_client_state
		# (cs_type_tables,dl_client_state)
			= get_type_tables dl_client_state;
		# cs_type_tables
			= AddTypeTable type_table_index type_table cs_type_tables;
		# dl_client_state
			= { dl_client_state &
				cs_type_tables = cs_type_tables
			};
		= dl_client_state;			
};

get_type_tables :: !*DLClientState -> *(*{#*TypeTable},*DLClientState);
get_type_tables dl_client_state=:{cs_type_tables}
	= (cs_type_tables,{dl_client_state & cs_type_tables = {}});
	
get_ets :: !*DLClientState -> *(!*EqTypesState,*DLClientState);
get_ets dl_client_state=:{cs_intra_type_equalities}
	= (cs_intra_type_equalities,{dl_client_state & cs_intra_type_equalities = default_eq_types_state});

instance DynamicInfoOps DLClientState
where {
	UpdateDynamicInfo dynamic_info_index dynamic_info dl_client_state
		= { dl_client_state & cs_dynamic_info = UpdateDynamicInfo dynamic_info_index dynamic_info dl_client_state.cs_dynamic_info };
};

instance Library_Instances DLClientState
where {
	AddLibraryInstance dynamic_index library_name type_table_i dl_client_state=:{cs_library_instances}
		# (library_instance_i,cs_library_instances)
			= AddLibraryInstance dynamic_index library_name type_table_i cs_library_instances;
		= (library_instance_i,{dl_client_state & cs_library_instances = cs_library_instances});
};

import ExtArray;
from type_io_common import PredefinedModuleName;
from utilities import foldSt;

get_info_library_instance_type_reference :: !LibraryInstanceTypeReference !*DLClientState -> ((!String,!String,Int,Int,TIO_TypeReference),*DLClientState);
get_info_library_instance_type_reference (LIT_TypeReference (LibRef library_instance_i) tio_type_ref) dl_client_state
	# (type_table_i,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
	# (type_name,module_name,dl_client_state)
		= get_names tio_type_ref type_table_i dl_client_state;
	= ((type_name,module_name,type_table_i,library_instance_i,tio_type_ref),dl_client_state);

get_names :: !TIO_TypeReference !Int !*DLClientState -> *(!String,!String,*DLClientState);
get_names {tio_type_without_definition=Just type_name} type_table_i dl_client_state
	= (type_name,PredefinedModuleName,dl_client_state);
	
get_names {tio_type_without_definition=Nothing,tio_tr_module_n,tio_tr_type_def_n} type_table_i dl_client_state
    #! (string_table,dl_client_state)
        = dl_client_state!cs_type_tables.[type_table_i].tt_type_io_state.tis_string_table;

	// get type name
    #! (tio_td_name,dl_client_state)
        = dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n].tio_td_name;
	# type_name
		= get_name_from_string_table tio_td_name string_table;
        
     // get module name
    #! (tio_module,dl_client_state)
        = dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module;
	# module_name
		= get_name_from_string_table tio_module string_table;
     
	= (type_name,module_name,dl_client_state);
	
get_from_graph_function_address2 :: !(Maybe Version) !*DLClientState -> (ToAndFromGraphEntry,ToAndFromGraphEntryIndex,!*DLClientState);
get_from_graph_function_address2 maybe_version dl_client_state
	#! (cs_to_and_from_graph,dl_client_state)
		= get_cs_to_and_from_graph dl_client_state;
	#! (x1,x2,cs_to_and_from_graph)
		= get_from_graph_function_address maybe_version cs_to_and_from_graph;
	#! dl_client_state
		= { dl_client_state &
			cs_to_and_from_graph = cs_to_and_from_graph
		};
	= (x1,x2,dl_client_state);

get_to_graph_function_address2 :: !(Maybe Version) !*DLClientState -> (Maybe (ToAndFromGraphEntry,ToAndFromGraphEntryIndex),!*DLClientState);
get_to_graph_function_address2 maybe_version dl_client_state
	#! (cs_to_and_from_graph,dl_client_state)
		= get_cs_to_and_from_graph dl_client_state;
	#! (x,cs_to_and_from_graph)
		= get_to_graph_function_address maybe_version cs_to_and_from_graph;
	#! dl_client_state
		= { dl_client_state &
			cs_to_and_from_graph = cs_to_and_from_graph
		};
	= (x,dl_client_state);

get_cs_to_and_from_graph dl_client_state=:{cs_to_and_from_graph}
	= (cs_to_and_from_graph,{dl_client_state & cs_to_and_from_graph = default_elemU});

instance symbol_n_to_offset DLClientState
where {
	symbol_n_to_offset file_n symbol_n dl_client_state
		#! (symbol_index,dl_client_state)
			= acc_state (\state -> symbol_n_to_offset file_n symbol_n state) dl_client_state;
		= (symbol_index,dl_client_state);
};

findLabel :: !String !Int !*DLClientState -> (!Maybe (!Int,!Int),!*DLClientState);
findLabel label_name library_instance_i dl_client_state
	#! (names_table_element,dl_client_state)
		= find_symbol_in_symbol_table_new label_name (\index dl_client_state -> dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_names_table.[index]) dl_client_state;
	#! label_name_found
		= get names_table_element;
	= (label_name_found,dl_client_state);
where {
	get (NamesTableElement _ symbol_n file_n _)
		= Just (file_n,symbol_n);
	get _
		= Nothing;
};

isLabelImplemented :: !Int !Int !*DLClientState -> (!Maybe Int,!*DLClientState);
isLabelImplemented file_n symbol_n dl_client_state
	| file_n < 0
		= abort "isLabelImplemented; internal error; cannot deal with file_n < 0";
	#! (first_symbol_n,dl_client_state)
		= dl_client_state!app_linker_state.marked_offset_a.[file_n];
	#! (marked,dl_client_state)
		=  dl_client_state!app_linker_state.marked_bool_a.[first_symbol_n+symbol_n];
	| not marked
		= (Nothing,dl_client_state);
		
	#! (symbol_address,dl_client_state)
		= acc_state (address_of_label2 file_n symbol_n) dl_client_state;
	= (Just symbol_address,dl_client_state);

has_strict_field :: !Int !Int !Bool !StrictnessList -> Bool;
has_strict_field _ _ True _
	= True;
has_strict_field i arity _ tio_st_args_strictness
	| i == arity
		= False;
		= has_strict_field (inc i) arity (arg_is_strict i tio_st_args_strictness) tio_st_args_strictness;

get_type_label_names :: !TIO_TypeReference !Int !*DLClientState -> (!String,!String,[String],!*DLClientState);
get_type_label_names {tio_type_without_definition=Just type_name} type_table_i dl_client_state
	#! list
		= filter (\{pt_type_name} -> type_name == pt_type_name) PredefinedTypes;
	| isEmpty list
		= abort ("get_type_label_names; internal error; unknown predefined type '" +++ type_name +++ "'");

	#! pt_constructor_names
		= map (\label_name -> gen_label_name True (label_name,UnderscoreSystemModule) '?') (hd list).pt_constructor_names;
	= (type_name,UnderscoreSystemModule,pt_constructor_names,dl_client_state);

get_type_label_names type_def=:{tio_tr_module_n,tio_tr_type_def_n} type_table_i dl_client_state
	#! (string_table_i,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_type_io_state.tis_string_table;
	#! (tio_module,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module;
	#! module_name = get_name_from_string_table tio_module string_table_i;

	// list with constructor names
	#! ({tio_td_name,tio_td_rhs},dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n];
	#! type_name = get_name_from_string_table tio_td_name string_table_i;
	= case tio_td_rhs of {
		TIO_AlgType defined_symbols
			# (label_names,dl_client_state)
				= foldSt (generate_algebraic_type_label_names type_def type_table_i string_table_i) defined_symbols ([],dl_client_state);
			# (td_labels, dl_client_state)
				= generate_reified_typedef_labels type_def type_table_i type_name string_table_i dl_client_state
			# label_names = label_names ++ td_labels
			-> (type_name,module_name,label_names,dl_client_state);
		TIO_RecordType tio_record_type
			# (label_names,dl_client_state)
				= generate_record_label type_def type_table_i string_table_i type_name tio_record_type dl_client_state;
			# (td_labels, dl_client_state)
				= generate_reified_typedef_labels type_def type_table_i type_name string_table_i dl_client_state
			# label_names = label_names ++ td_labels
			-> (type_name,module_name,label_names,dl_client_state);
		TIO_GenericDictionaryType tio_record_type
			# (label_names,dl_client_state)
				= generate_record_label type_def type_table_i string_table_i type_name tio_record_type dl_client_state;
			-> (type_name,module_name,label_names,dl_client_state);
		TIO_SynType _
			| OUTPUT_UNIMPLEMENTED_FEATURES_WARNINGS 
					(True <<- ("get_type_label_names; elimination of synonym types should still be done"))
					(True)
			-> (type_name,module_name,[],dl_client_state);
		s
			-> abort "get_type_label_names; internal error" <<- s;
	};
	
generate_record_label :: !.TIO_TypeReference !.Int !String !String !TIO_RecordType !*DLClientState -> ([String],*DLClientState);
generate_record_label {tio_tr_module_n} type_table_i string_table_i record_descriptor_name {tio_rt_constructor={tio_ds_arity,tio_ds_index},tio_rt_fields} dl_client_state
	// get module name
	#! (tio_module,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module;
	#! module_name
		= get_name_from_string_table tio_module string_table_i;

	#! (tio_st_args_strictness,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_cons_defs.[tio_ds_index].tio_cons_type.tio_st_args_strictness;
	#! is_strict_record
		= has_strict_field 0 tio_ds_arity False tio_st_args_strictness;

	#! r_prefixed_label
		= gen_label_name True (record_descriptor_name,module_name) 'r';
	| is_strict_record
		// strict
		#! t_prefixed_label
			= gen_label_name True (record_descriptor_name,module_name) 't';
		#! c_prefixed_label
			= gen_label_name True (record_descriptor_name,module_name) 'c';
		= ([r_prefixed_label,t_prefixed_label,c_prefixed_label],dl_client_state);
		
		// non strict record
		= ([r_prefixed_label],dl_client_state);

generate_algebraic_type_label_names :: !TIO_TypeReference !Int !String !TIO_ConstructorSymbol !*([String],!*DLClientState) -> ([String],!*DLClientState);
generate_algebraic_type_label_names {tio_tr_module_n} type_table_i string_table_i
		{tio_cons={tio_ds_ident,tio_ds_index,tio_ds_arity}} (label_names,dl_client_state)
	#! (tio_module,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module;
	#! module_name
		= get_name_from_string_table tio_module string_table_i;

	#! constructor_name
		= get_name_from_string_table tio_ds_ident string_table_i;

	#! (tio_cons_type=:{tio_st_args_strictness},dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_cons_defs.[tio_ds_index].tio_cons_type;

	#! is_strict_constructor
		= has_strict_field 0 tio_ds_arity False tio_st_args_strictness;

	#! d_prefixed_label
		= gen_label_name True (constructor_name,module_name) 'd';
	| is_strict_constructor
		// strict
		#! k_prefixed_label
			= gen_label_name True (constructor_name,module_name) 'k';
		#! n_prefixed_label
			= gen_label_name True (constructor_name,module_name) 'n';

		#! label_names
			= [k_prefixed_label,d_prefixed_label,n_prefixed_label:label_names];
		=  (label_names,dl_client_state);

		// non-strict
		#! label_names
			= [d_prefixed_label:label_names];
		=  (label_names,dl_client_state);

generate_reified_typedef_labels :: !TIO_TypeReference !Int !String !String !*DLClientState -> ([String], DLClientState);
generate_reified_typedef_labels {tio_type_without_definition=Just _} type_table_i type_name string_table_i dl_client_state
	=  ([],dl_client_state);
generate_reified_typedef_labels {tio_tr_module_n} type_table_i type_name string_table_i dl_client_state
	#! (tio_module,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module
	#! module_name
		= get_name_from_string_table tio_module string_table_i;

	#! d_prefixed_label
		= gen_label_name True ("TD;" +++ type_name,module_name) 'd';
	=  ([d_prefixed_label],dl_client_state);


acc_library_instances :: .(*LibraryInstances -> *(.a,*LibraryInstances)) !*DLClientState -> *(.a,*DLClientState);
acc_library_instances f dl_client_state=:{cs_library_instances}
	# (x,cs_library_instances)
		= f cs_library_instances;
	= (x,{dl_client_state & cs_library_instances = cs_library_instances});
	
acc_lis_library_instances :: .(*{#*LibraryInstance} -> *(.a,*{#*LibraryInstance})) !*LibraryInstances -> *(.a,*LibraryInstances);
acc_lis_library_instances f cs_library_instances=:{lis_library_instances}
	# (x,lis_library_instances)
		= f lis_library_instances;
	= (x,{cs_library_instances & lis_library_instances = lis_library_instances} );
	
acc_library_instance :: .(*{!NamesTableElement} -> *(.a,*{!NamesTableElement})) !*LibraryInstance -> *(.a,*LibraryInstance);	
acc_library_instance f library_instance=:{li_names_table}
	# (x,li_names_table)
		= f li_names_table;
	= (x,{library_instance & li_names_table = li_names_table});

acc_names_table :: !Int !*DLClientState -> *(.{!NamesTableElement},*DLClientState);	
acc_names_table library_instance_i dl_client_state
	= acc_library_instances (\library_instances -> acc_lis_library_instances select_library_instance library_instances) dl_client_state;
where {
	select_library_instance library_instances 
		# (library_instance,library_instances)
			= replace library_instances library_instance_i default_library_instance;
			
		# (x,library_instance)
			= acc_library_instance (\nt -> (nt,{})) library_instance;
		# library_instances
			= { library_instances & [library_instance_i] = library_instance };
		= (x,library_instances); 
}


print_type_table_reference :: !Int !TIO_TypeReference !{#*TypeTable} -> (!String,{#*TypeTable});
print_type_table_reference type_table_i {tio_tr_module_n,tio_tr_type_def_n,tio_type_without_definition=Nothing} type_tables
	#! (string_table_i,type_tables)
		= type_tables![type_table_i].tt_type_io_state.tis_string_table;
	#! (tio_td_name,type_tables)
		= type_tables![type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n].tio_td_name;
	#! type_name
		= get_name_from_string_table tio_td_name string_table_i;
	= (type_name,type_tables);
print_type_table_reference type_table_i {tio_type_without_definition=Just type_name} type_tables
	= (type_name,type_tables);
	
get_lazy_dynamic_index_to_dynamic_id :: !*DLClientState -> *(!*{#LazyDynamicInfo},!*DLClientState);
get_lazy_dynamic_index_to_dynamic_id dl_client_state=:{cs_lazy_dynamic_index_to_dynamic_id}
	= (cs_lazy_dynamic_index_to_dynamic_id,{dl_client_state & cs_lazy_dynamic_index_to_dynamic_id = {} });

// utility
get_number_of_type_tables :: *DLClientState -> *(Int,*DLClientState);
get_number_of_type_tables dl_client_state
	// get number of type tables
	# (type_tables,dl_client_state)
		= get_type_tables dl_client_state;
	# (n_type_tables,type_tables)
		= usize type_tables
	# dl_client_state
		= { dl_client_state & cs_type_tables = type_tables };
	= (n_type_tables,dl_client_state);

add_object_module_to_library_instance :: {#.Char} !.Int !*DLClientState .a !*f -> *(*DLClientState,.a,!*f) | FileEnv f;
add_object_module_to_library_instance object_name library_instance_i dl_client_state s io
	# (state,dl_client_state)
		= get_state dl_client_state;

	// extract namestable
	#! (names_table,dl_client_state)
		= acc_names_table library_instance_i dl_client_state;					
	#! state
		= {state & namestable = names_table };

	// add new object module
	# (ok,labels,state,dl_client_state,s,io)
		= load_object object_name 0 "" state dl_client_state s io;
	| not ok || (not (isEmpty labels))
		= abort ("add_object_module_to_library_instance; internal error" +++  (fst3 (hd labels)));

	// restoring namestable
	#! (names_table,state)
		= get_names_table state;
	#! dl_client_state
		= { dl_client_state & cs_library_instances.lis_library_instances.[library_instance_i].li_names_table = names_table };		

	# dl_client_state
		= { dl_client_state & app_linker_state = state };
	= (dl_client_state,s,io);
where {
	get_names_table state=:{namestable}
		= (namestable,{state & namestable = {}});
};

get_state :: !*DLClientState -> (!*State,!*DLClientState);
get_state dl_client_state=:{app_linker_state}
	= (app_linker_state,{dl_client_state & app_linker_state = EmptyState});

internal_error :: !{#Char} !ProcessSerialNumber !*DLClientState !*DLServerState .a -> *(!Bool,!ProcessSerialNumber,!DLServerState,.a);		
internal_error message client_id dl_client_state=:{app_linker_state=state} s io
	#! dl_client_state
		= { dl_client_state &
			id					= client_id
		,	app_linker_state	= AddMessage (LinkerError message) state
		};
	= (True,client_id,AddToDLServerState dl_client_state s,io);

from selectively_import_and_mark_labels import replace_section_label_by_label2, has_section_label_already_been_replaced;

replaceLabel :: !String !Int !Int !Int !String !*DLClientState -> *DLClientState;
replaceLabel refering_label library_instance_i file_n symbol_n chosen_label_name dl_client_state
	#! ((symbol_hash,ref_file_n,ref_symbol_n,names_table_element_list),dl_client_state)
		= split_symbol_list_in_symbol_table refering_label
		 (\index dl_client_state -> dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_names_table.[index]) dl_client_state;
	| ref_file_n == file_n && ref_symbol_n == symbol_n
		= dl_client_state;
		
	#! new_names_table_element
		= NamesTableElement refering_label symbol_n file_n names_table_element_list;
	#! dl_client_state
		= { dl_client_state & 
			cs_library_instances.lis_library_instances.[library_instance_i].li_names_table.[symbol_hash] = new_names_table_element
		};
		
	// The chosen_label_name which implements a type can be referenced within the defining object module or
	// from some other object module. The latter references are resolved by name using the names table. The
	// former reference by symbol index. These references are accounted for by marking the symbol itself and
	// its defining section (module) as linked and by copying the address of the defining module of the chosen
	// symbol to that referencing module.
	=	replaceSymbol ref_file_n ref_symbol_n file_n symbol_n dl_client_state;

replaceSymbol :: !Int !Int !Int !Int !*DLClientState -> *DLClientState;
replaceSymbol ref_file_n ref_symbol_n file_n symbol_n dl_client_state
	// find module containing referencing symbol	
	#! (ref_module_n,dl_client_state)
		= acc_state (replace_section_label_by_label2 ref_file_n ref_symbol_n) dl_client_state;

	// find module containing chosen symbol
	#! (chosen_symbol,dl_client_state) 
		= dl_client_state!app_linker_state.xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	#! (chosen_symbol_not_yet_implemented,chosen_module_n,dl_client_state)
		= case chosen_symbol of {
			Label _ _ module_n 
				-> (False,module_n,dl_client_state);
			SectionLabel section_n _
				#! (module_n,dl_client_state)
					= dl_client_state!app_linker_state.xcoff_a.[file_n].symbol_table.section_symbol_ns.[section_n];
				-> (True,module_n,dl_client_state);
		};
		
	// compute address of chosen module_n
	#! (chosen_module_n_index,dl_client_state)
		= symbol_n_to_offset file_n chosen_module_n dl_client_state;
	#! (chosen_module_n_address,dl_client_state)
		= dl_client_state!app_linker_state.module_offset_a.[chosen_module_n_index];

	// mark referencing module as marked by settings its address to that of the chosen module
	#! (ref_module_n_index,dl_client_state)
		= symbol_n_to_offset ref_file_n ref_module_n dl_client_state;
	#! dl_client_state
		= { dl_client_state &
			app_linker_state.module_offset_a.[ref_module_n_index] 	= f chosen_module_n_address chosen_module_n_index chosen_symbol_not_yet_implemented ref_module_n_index
		,	app_linker_state.marked_bool_a.[ref_module_n_index]		= True
		};
	with {
		f 0 chosen_module_n_index chosen_symbol_not_yet_implemented ref_module_n_index
			| chosen_symbol_not_yet_implemented
				= ~chosen_module_n_index;
		f chosen_module_n_address _ _ _
			= chosen_module_n_address;
	};
		
	#! (ref_symbol_n_index,dl_client_state)
		= symbol_n_to_offset ref_file_n ref_symbol_n dl_client_state;
	#! dl_client_state
		= { dl_client_state &
			app_linker_state.marked_bool_a.[ref_symbol_n_index]		= True
		};
	= dl_client_state;

get_dynamic_id :: !Int !*DLClientState -> (!(Maybe (!Int,!Int)),!*DLClientState);
get_dynamic_id searched_rt_lazy_dynamic_index dl_client_state
	#! (n_dynamics,dl_client_state) = dl_client_state!dynamic_ids.did_counter;
	#! (result,dl_client_state)
		= findAst is_searched_dynamic_index dl_client_state n_dynamics; 
	= (result,dl_client_state);
where {
	is_searched_dynamic_index dynamic_index dl_client_state
		// determine whether the dynamic id is valid
		# (is_valid_dynamic_index,dl_client_state) = is_valid_id2 dynamic_index dl_client_state;
		| not is_valid_dynamic_index
			= (Nothing,dl_client_state);
		// valid, extract array holding all run-time lazy dynamic indices
		# (di_disk_to_rt_dynamic_indices,dl_client_state) = dl_client_state!cs_dynamic_info.[dynamic_index].di_disk_to_rt_dynamic_indices;
		# result
			= findAi is_lazy_disk_dynamic di_disk_to_rt_dynamic_indices;
		= (result,dl_client_state);
	where {
		is_lazy_disk_dynamic disk_lazy_dynamic_index rt_lazy_dynamic_index 
			| searched_rt_lazy_dynamic_index == rt_lazy_dynamic_index
				= Just (disk_lazy_dynamic_index,dynamic_index);
				= Nothing;
	};
};
	
extractTypeTable_i :: !LibRef !*DLClientState -> (!Int,!*DLClientState);
extractTypeTable_i (LibRef library_instance_i) dl_client_state
	= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
	
EqualType type1 type2 dl_client_state
	# (type_tables,dl_client_state)
		= get_type_tables dl_client_state;
	# (ets,dl_client_state)
		= get_ets dl_client_state;
		
	# (rt_type_reference1,dl_client_state)
		= convert_lit_type_reference_to_type_table_reference type1 dl_client_state; 
	# (rt_type_reference2,dl_client_state)
		= convert_lit_type_reference_to_type_table_reference type2 dl_client_state; 

	# (equivalent_type_defs,type_tables,ets)
		= equal_type_defs rt_type_reference1 rt_type_reference2 type_tables ets;
			
	# dl_client_state
		= { dl_client_state & 
			cs_type_tables = type_tables
		,	cs_intra_type_equalities = ets
		 };

	= (equivalent_type_defs,dl_client_state);
	
convert_lit_type_reference_to_type_table_reference :: !.LibraryInstanceTypeReference !*DLClientState -> *(.TypeTableTypeReference,*DLClientState);
convert_lit_type_reference_to_type_table_reference (LIT_TypeReference lib_ref tio_type_ref) dl_client_state
	#! (type_table_i,dl_client_state)
		= extractTypeTable_i lib_ref dl_client_state;
	= (TypeTableTypeReference type_table_i tio_type_ref,dl_client_state);
	
extractType (LIT_TypeReference lib_ref {tio_type_without_definition=Nothing,tio_tr_module_n,tio_tr_type_def_n}) dl_client_state
	# (type_table_i,dl_client_state)
		= extractTypeTable_i lib_ref dl_client_state
	#! (tio_type_def,dl_client_state)
		= dl_client_state!cs_type_tables.[type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_com_type_defs.[tio_tr_type_def_n];
	= (tio_type_def,dl_client_state);

collect_equivalent_context_types :: .LibraryInstanceTypeReference u:[.LibraryInstanceTypeReference] !*DLClientState -> *(v:[LibraryInstanceTypeReference],*DLClientState), [u <= v];
collect_equivalent_context_types representant typesQ dl_client_state=:{cs_library_instances={lis_n_library_instances}}
	#! types = typesQ;
	#! (all_types,dl_client_state)
		= loopAst collect_context_types (types,dl_client_state) lis_n_library_instances;
	= (all_types,dl_client_state);
where {
	collect_context_types library_instance_i (types,dl_client_state)
		| library_instance_i < RTID_LIBRARY_INSTANCE_ID_START
			= (types,dl_client_state);
		
			#! ((type_name,module_name,type_table_i,library_instance_j,tio_type_ref),dl_client_state)
				= get_info_library_instance_type_reference representant dl_client_state;
				
			#! hash_value_of_name
				= hashValue type_name;
			#! (type_table_i,dl_client_state)
				= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;


			#! (l,dl_client_state)
				= dl_client_state!cs_type_tables.[type_table_i].tt_hash_table.[hash_value_of_name];
			#! (types,dl_client_state)
				= loopAst (look_for_type type_name l type_table_i library_instance_i) (types,dl_client_state) (size l)
			= (types,dl_client_state);
	where {
		look_for_type type_name a type_table_i library_instance_i i s=:(l,dl_client_state)
			= case a.[i].tthe_kind of {
				TTHE_TypeName tio_type_reference type_name_i
					// extract type name of found type
				    #! (string_table,dl_client_state)
				        = dl_client_state!cs_type_tables.[type_table_i].tt_type_io_state.tis_string_table;
					# found_type_name
						= get_name_from_string_table type_name_i string_table;
						
					// 
					| type_name <> found_type_name
						-> (l,dl_client_state);
						
						#! lit_type_reference
							= LIT_TypeReference (LibRef library_instance_i) tio_type_reference;
						# (equivalent_types,dl_client_state)
							= EqualType lit_type_reference representant dl_client_state;
						-> (if equivalent_types [lit_type_reference:l] l ,dl_client_state);
				_
					-> s;
				};
	}; // collect_context_types
}; // collect_equivalent_context_types

/*
** Loads a module in memory. If necessary e.g. (size symbol_name) > 0 then it is
** checked if the module is its defining module. Accordingly to the result, the
** returned bool is set. If it is false, the module is not loaded e.g. integrated
** with existing modules.
*/ 
load_object object_path_name_ext object_fp_in_library symbol_name state=:{linker_state_info={one_pass_link},n_xcoff_files} dl_client_state dl_server_state io
	/*
	** If symbol_name must be defined (length greater than zero), then create a
	** new, empty names_table because it is unknown if the specified module
	** actually defines the symbol.
	*/	
	#! (names_table,state)
		= case (size symbol_name) of {
			0 
				#! (names_table,state)
					= select_namestable state;	
				#! (s_names_table,names_table)
					= usize names_table;
				| s_names_table == 0
					-> abort "names table is zero"
				-> (names_table,state);
			_ 
				-> (create_names_table,state);					
		}			

	// read object file	
	#! (redirection_state,state)	= get_redirection_state state;		
	#! ((any_extra_sections,errors,xcoff_list,names_table,redirection_state),io)
 		= accFiles (ReadXcoffM False object_path_name_ext object_fp_in_library names_table one_pass_link n_xcoff_files redirection_state) io;
 	#! state = put_redirection_state redirection_state state;
	| not (isEmpty errors)
		#! state
			= { state & namestable = names_table };
		#! messages
			= [LinkerError m \\ m <- errors];
		= (False,[],SetLinkerMessages messages state,dl_client_state,dl_server_state,io);

	// if necessary, check if symbol_name is defined in this module
	#! (symbol_found,names_table,state)
		= case (size symbol_name) of {
			0 
				// symbol_name needs not be defined
				-> (True,names_table,state);
			_
				// symbol_name must be defined
				#! (names_table_element,names_table)
					= find_symbol_in_symbol_table symbol_name names_table
				-> case names_table_element of {			
					NamesTableElement _ _ _ _
						#! (old_namestable,state)
							= select_namestable state;
						-> (True, (MergeNamesTables old_namestable names_table),state);
					_
						-> (False,names_table,state);
					}
			}
	| not symbol_found
		#! state
			= { state & namestable = names_table };
		#! message
			= "module '" +++ object_path_name_ext +++ "' requires symbol " +++ symbol_name +++ "to be defined";
		= (False,[],AddMessage (LinkerError message) state,dl_client_state,dl_server_state,io);
	
	// import as many symbols as can be resolved; sort on macos probably not needed
	#! map_function
		= sel_platform
			sort_modules																				// winos
			(\xcoff -> sort_modules (split_data_symbol_lists_without_removing_unmarked_symbols xcoff))	// macos
			;
	#!  (undefined_symbols,xcoff_list,names_table)
		=  import_symbols_in_xcoff_files /*[sort_modules xcoff]*/ (map map_function xcoff_list) n_xcoff_files [] names_table;
	#! state
		= update_namestable names_table state;
	= (True,undefined_symbols,/*add_module (hd xcoffs) state*/ foldl (\state xcoff -> add_module xcoff state) state xcoff_list,dl_client_state,dl_server_state,io);

RegisterLibrary :: (Maybe .Int) !{#.Char} !*DLClientState !*f -> *(Int,Int,*DLClientState,!*f) | FileEnv f;
RegisterLibrary dynamic_index library_name s io
	# (type_table_i,s)
		= AddReferenceToTypeTable library_name s;
	# (library_instance_i,s)
		= AddLibraryInstance dynamic_index library_name type_table_i s;
		
	// print		
	# msg = "Register library as library #" +++ toString library_instance_i +++ " and name '" +++ 
			snd (ExtractPathAndFile library_name) +++ "'";
	#! s = AddDebugMessage msg s;

	#! (s,io) = LoadTypeTable library_instance_i type_table_i s io;
	#! (ok,s,io) = initialize_library_instance library_instance_i s io
	= (library_instance_i,type_table_i,s,io);

// RWS:
// Removed the usage of the type implementation module, and things still seem
// to work, but I've an eery feeling a mapping on equivalent types still has to
// be done here
determine_implementation_for_dus_entry :: !String !String !Int !Int !Int !*DLClientState -> *(.DusImplementation,*DLClientState);
determine_implementation_for_dus_entry descriptor_name module_name dus_library_instance_nr_on_disk prefix_set_and_string_ptr id dl_client_state=:{cs_main_library_instance_i}
	#! (library_instance_i,dl_client_state)
		= dl_client_state!cs_dynamic_info.[id].di_disk_id_to_library_instance_i.[dus_library_instance_nr_on_disk];
	#! (type_table_i,dl_client_state)
		= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
		
	#! descriptor_name_as_used_in_type_table
		= convert_descriptor_name_to_type_constructor_name (is_record (get_prefix_set prefix_set_and_string_ptr)) descriptor_name;
	#! (result,dl_client_state)
		= findTypeUsingConstructorName descriptor_name_as_used_in_type_table module_name type_table_i dl_client_state;
	| isNothing result
		// label is not a Clean type but e.g. a closure, a function. It *cannot* be a non-Clean label (rts) because they
		// cannot occur in the datagraph. The implementation
		// comes from the current library instance except for run-time system label which should always come from
		// the main-library instance.
		| module_name == UnderscoreSystemModule
			# dus_implementation
				= { 
					dusi_descriptor_name	= descriptor_name
				,	dusi_module_name		= module_name
				,	dusi_library_instance_i	= fromJust cs_main_library_instance_i
				,	dusi_linked				= False
				,	dusi_label_kind			= DSL_RUNTIME_SYSTEM_LABEL
				};
			= (dus_implementation,dl_client_state);

			# dus_implementation
				= { 
					dusi_descriptor_name	= descriptor_name
				,	dusi_module_name		= module_name
				,	dusi_library_instance_i	= library_instance_i
				,	dusi_linked				= False
				,	dusi_label_kind			= DSL_CLEAN_LABEL_BUT_NOT_A_TYPE
				};
			= (dus_implementation,dl_client_state);
		
		// Label belongs to a Clean-type			
		# (is_type_equation,type_implementation_ref,dl_client_state)
//	RWS	removed	= findImplementationType (LIT_TypeReference (LibRef library_instance_i) (fromJust result)) dl_client_state;
			= (True, (LIT_TypeReference (LibRef library_instance_i) (fromJust result)), dl_client_state);
		| not is_type_equation
			// a Clean type without equation. The implementation of the type comes from the current library
			// instance. Possibilities:
			// (KAN NIET) - rts-label	-> use rts-label from main library_instance_i
			// - otherwise	-> use labels from library instance i
			# dus_implementation
				= { 
					dusi_descriptor_name	= descriptor_name
				,	dusi_module_name		= module_name
				,	dusi_library_instance_i	= library_instance_i
				,	dusi_linked				= False
				,	dusi_label_kind			= DSL_RUNTIME_SYSTEM_LABEL
				};
			= (dus_implementation,dl_client_state);

			// Get possible implementation type
			# type_implementation_ref
				= fromJust type_implementation_ref;
			# (chosen_implementation_type,dl_client_state)
// RWS removed				= getImplementationType type_implementation_ref dl_client_state;
				= (Nothing, dl_client_state);

			// Clean type in equivalence class
			| isNothing chosen_implementation_type
				// A Clean type belong to some type equivalence class *without* implementation. The implementation
				// chosen is that of the current library instance.

				// <library_instance_i,descriptor_name,module_name>
			# dus_implementation
				= { 
					dusi_descriptor_name	= descriptor_name
				,	dusi_module_name		= module_name
				,	dusi_library_instance_i	= library_instance_i
				,	dusi_linked				= False
				,	dusi_label_kind			= DSL_RUNTIME_SYSTEM_LABEL
				};
			= (dus_implementation,dl_client_state);
				
				// a Clean type, member of a type equivalence class and *with* implementation
				// <library_instance_i of chosen implementation type,descriptor_name,module_name of the chosen library instance>
				# (new_module_name,new_library_instance_i,dl_client_state)
					= case (fromJust chosen_implementation_type) of {
						(LIT_TypeReference (LibRef library_instance_i) {tio_type_without_definition=Just _})
							// an internal type
							-> (module_name,library_instance_i,dl_client_state);
						(LIT_TypeReference (LibRef library_instance_i) {tio_tr_module_n})
							#! (li_type_table_i,dl_client_state)
								= dl_client_state!cs_library_instances.lis_library_instances.[library_instance_i].li_type_table_i;
							#! (tio_module,dl_client_state)
								= dl_client_state!cs_type_tables.[li_type_table_i].tt_tio_common_defs.[tio_tr_module_n].tio_module;
							#! (string_table_i,dl_client_state)
								= dl_client_state!cs_type_tables.[li_type_table_i].tt_type_io_state.tis_string_table;
							#! module_name
								= get_name_from_string_table tio_module string_table_i;
							-> (module_name,library_instance_i,dl_client_state)
					};
					
				# dus_implementation
					= { 
						dusi_descriptor_name	= descriptor_name
					,	dusi_module_name		= new_module_name
					,	dusi_library_instance_i	= new_library_instance_i
					,	dusi_linked				= True		//
					,	dusi_label_kind			= DSL_TYPE_EQUIVALENT_CLASS_WITH_IMPLEMENTATION
					};
				= (dus_implementation,dl_client_state);
where {
	convert_descriptor_name_to_type_constructor_name True constructor_name
		= "_" +++ constructor_name;
	convert_descriptor_name_to_type_constructor_name is_record constructor_name
		= constructor_name;
};

instance findTypeUsingTypeName DLClientState
where {
	findTypeUsingTypeName type_name module_name type_table_i dl_client_state
		# (type_tables,dl_client_state)
			= get_type_tables dl_client_state;
		# (result,type_tables)
			= findTypeUsingTypeName type_name module_name type_table_i type_tables;
		# dl_client_state = { dl_client_state & cs_type_tables = type_tables };
		= (result,dl_client_state);
};

instance findTypeUsingConstructorName DLClientState
where {
	findTypeUsingConstructorName type_name module_name type_table_i dl_client_state
		# (type_tables,dl_client_state)
			= get_type_tables dl_client_state;
		# (result,type_tables)
			= findTypeUsingConstructorName type_name module_name type_table_i type_tables;
		# dl_client_state = { dl_client_state & cs_type_tables	= type_tables };
		= (result,dl_client_state);
};

output_message_begin :: !{#.Char} !ProcessSerialNumber !*DLClientState -> *DLClientState;
output_message_begin title client_id dl_client_state
	#! title = title +++ " (" +++ toString client_id +++ ")"
	# dl_client_state = AddDebugMessage "" dl_client_state;
	# dl_client_state = AddDebugMessage title dl_client_state;
	= AddDebugMessage (createArray (size title) '-') dl_client_state;
