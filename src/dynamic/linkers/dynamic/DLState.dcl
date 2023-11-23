definition module DLState;

from StdFile import class FileEnv;
from StdOverloaded import class +(+);
from StdInt import instance + Int;
from StdMaybe import :: Maybe;
from StdDynamicTypes import :: LibraryInstanceTypeReference, :: TIO_TypeReference,
		:: TIO_TypeReference, :: LibRef;
from type_io_read import :: TIO_RecordType, :: TIO_DefinedSymbol,
			:: TypeTableTypeReference, :: TIO_ConstructorSymbol;
from ToAndFromGraph import :: ToAndFromGraphTable, :: ToAndFromGraphEntry, :: ToAndFromGraphEntryIndex;
from State import :: State, class symbol_n_to_offset;
from DynamicID import class DynamicIDs, :: DynamicID;
from ProcessSerialNumber import :: ProcessSerialNumber;
from StdDynamicVersion import :: Version;
from StdDynamicLowLevelInterface import :: DynamicInfo,::DynamicInfoArray, class DynamicInfoOps;
from type_io_equal_type_defs import :: EqTypesState;
from NamesTable import :: NamesTableElement;
from DefaultElem import class DefaultElem, class DefaultElemU;
from pdState import :: PDState;
from typetable import :: TypeTable, class TypeTableOps, class findTypeUsingTypeName;
from LinkerMessages import class AddMessage;
from LibraryInstance import class Library_Instances, :: LibraryInstances;
from dus_label import :: DusImplementation;
from StrictnessList import :: StrictnessList;
from TypeEquivalences import :: TypeEquivalences;

:: *DLServerState
	= {
	// general data
		quit_server						:: !Bool
	,	application_path				:: !String
	,	static_application_as_client	:: !Bool
	
	// clients
	,	dl_client_states				:: *[*DLClientState]
	
	// client windows
//	,	global_client_window			:: !GlobalClientWindow
	
	// conversions
	,	convert_functions				:: !ConvertFunctions
	
	// NEW TO HANDLE .LIB DEMANDS
	,	dlss_lib_mode					:: !Bool
	,	dlss_lib_command_line			:: !{{#Char}}
	};
		
instance DefaultElemU DLServerState;

AddToDLServerState :: *DLClientState *DLServerState -> *DLServerState; 	
RemoveFromDLServerState :: !ProcessSerialNumber !*DLServerState -> (!Bool,!*DLClientState,!*DLServerState);
	
acc_dl_client_states :: ([*DLClientState] -> (.x,[*DLClientState])) !*DLServerState -> (.x,!*DLServerState);
app_dl_client_states :: ([*DLClientState] -> [*DLClientState]) !*DLServerState -> *DLServerState;

selacc_client_state :: !ProcessSerialNumber (*DLClientState -> (.x,*DLClientState)) !*DLServerState -> (.x,!*DLServerState);

selacc_app_linker_state :: !ProcessSerialNumber !(*State -> *(.a,*State)) !*DLServerState -> *(.a,*DLServerState);

:: *DLClientState
	= { 
	// client identification
		id						:: !ProcessSerialNumber
	,	initial_link			:: !Bool		
	// application linker state
	,	app_linker_state		:: !*State
	// support for block dynamics (only one
	,	dynamic_ids				:: !*DynamicID	
	// Library implementation
	,	cs_main_library_name	:: !String
	,	cs_type_tables			:: !*{#TypeTable}
	,	cs_dynamic_info			:: !*DynamicInfoArray
	,	cs_library_instances		:: !*LibraryInstances	// all info specific to a library instance
	,	cs_main_library_instance_i	:: !Maybe Int
	,	cs_intra_type_equalities	:: !*EqTypesState	
	,	cs_to_and_from_graph	:: !ToAndFromGraphTable	
	,	cs_n_fixed_available_types	:: !Maybe Int	
	,	do_dump_dynamic			:: !Bool
	,	cs_n_lazy_dynamics		:: !Int						// first free dynamic
	,	cs_lazy_dynamic_index_to_dynamic_id	:: !*{#LazyDynamicInfo}		// indexed by lazy_dynamic_index (rt) with No meaning not initialized, Yes is initialized and dynamic id is the integer
	,	cs_share_runtime_system	:: !Bool
	,	cs_conversion			:: ![ConversionInfo]
	,	cs_dlink_dir			:: !String
	,	cs_type_equivalences :: !*TypeEquivalences
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
	
instance DefaultElem LazyDynamicInfo;
	
instance DynamicIDs DLClientState;
	
instance DefaultElemU DLClientState;

instance AddMessage DLClientState;

// ClientWindows
timer_id 	:== 0;
free_id		:== timer_id + 1;

app_state ::  (*State -> *State) !*DLClientState -> *DLClientState;
acc_state ::  (*State -> (!.x,!*State)) !*DLClientState -> (!.x,*DLClientState);

class AppPdState s
where {
	app_pd_state :: !(*PDState -> *PDState) !*s -> *s
};

instance AppPdState DLClientState;
instance AppPdState State;

class AccPdState s
where {
	acc_pd_state :: !(*PDState -> (!.x,!*PDState)) !*s -> (!.x,!*s)
};

instance AccPdState State;
instance AccPdState DLClientState;

InitServerState :: !*DLServerState !*a -> (!*DLServerState,!*a) | FileEnv a;

:: ConvertFunctions = {
		graph_to_string :: [Version]
	,	string_to_graph :: [Version]
	};
	
GetDynamicLinkerDirectory :: !*DLServerState -> (!String,!*DLServerState);

eager_read_version :: !Version !*DLClientState !*DLServerState -> (!Bool,!Version,!*DLClientState,!*DLServerState);		
eager_write_version :: !*DLClientState !*DLServerState -> (!Bool,!Version,!*DLClientState,!*DLServerState);	

get_type_tables :: !*DLClientState -> *(*{#*TypeTable},*DLClientState);
get_ets :: !*DLClientState -> *(!*EqTypesState,*DLClientState);

instance TypeTableOps DLClientState;
instance DynamicInfoOps DLClientState;

instance Library_Instances DLClientState;

get_from_graph_function_address2 :: !(Maybe Version) !*DLClientState -> (ToAndFromGraphEntry,ToAndFromGraphEntryIndex,!*DLClientState);
get_to_graph_function_address2 :: !(Maybe Version) !*DLClientState -> (Maybe (ToAndFromGraphEntry,ToAndFromGraphEntryIndex),!*DLClientState);

instance symbol_n_to_offset DLClientState;

findLabel :: !String !Int !*DLClientState -> (!Maybe (!Int,!Int),!*DLClientState);
isLabelImplemented :: !Int !Int !*DLClientState -> (!Maybe Int,!*DLClientState);

// Type label name generation
get_type_label_names :: !TIO_TypeReference !Int !*DLClientState -> (!String,!String,[String],!*DLClientState);

generate_algebraic_type_label_names :: !TIO_TypeReference !Int !String !TIO_ConstructorSymbol !*([String],!*DLClientState) -> ([String],!*DLClientState);
generate_record_label :: !.TIO_TypeReference !.Int !String !String !TIO_RecordType !*DLClientState -> ([String],*DLClientState);

acc_names_table :: !Int !*DLClientState -> *(.{!NamesTableElement},*DLClientState);	

print_type_table_reference :: !Int !TIO_TypeReference !{#*TypeTable} -> (!String,{#*TypeTable});

get_lazy_dynamic_index_to_dynamic_id :: !*DLClientState -> *(!*{#LazyDynamicInfo},!*DLClientState);

get_number_of_type_tables :: *DLClientState -> *(Int,*DLClientState);

has_strict_field :: !Int !Int !Bool !StrictnessList -> Bool;

add_object_module_to_library_instance :: {#.Char} !.Int !*DLClientState .a !*f -> *(*DLClientState,.a,!*f) | FileEnv f;


get_state :: !*DLClientState -> (!*State,!*DLClientState);

internal_error :: !{#Char} !ProcessSerialNumber !*DLClientState !*DLServerState .a -> *(!Bool,!ProcessSerialNumber,!DLServerState,.a);		

replaceLabel :: !String !Int !Int !Int !String !*DLClientState -> *DLClientState;
replaceSymbol :: !Int !Int !Int !Int !*DLClientState -> *DLClientState;

get_dynamic_id :: !Int !*DLClientState -> (!(Maybe (!Int,!Int)),!*DLClientState);

collect_equivalent_context_types :: .LibraryInstanceTypeReference u:[.LibraryInstanceTypeReference] !*DLClientState -> *(v:[LibraryInstanceTypeReference],*DLClientState), [u <= v];

RegisterLibrary :: (Maybe .Int) !{#.Char} !*DLClientState !*f -> *(Int,Int,*DLClientState,!*f) | FileEnv f;

determine_implementation_for_dus_entry :: !String !String !Int !Int !Int !*DLClientState -> *(.DusImplementation,*DLClientState);

instance findTypeUsingTypeName DLClientState;

extractTypeTable_i :: !LibRef !*DLClientState -> (!Int,!*DLClientState);

get_info_library_instance_type_reference :: !LibraryInstanceTypeReference !*DLClientState -> ((!String,!String,Int,Int,TIO_TypeReference),*DLClientState);

get_names :: !TIO_TypeReference !Int !*DLClientState -> *(!String,!String,*DLClientState);

convert_lit_type_reference_to_type_table_reference :: !.LibraryInstanceTypeReference !*DLClientState -> *(.TypeTableTypeReference,*DLClientState);

output_message_begin :: !{#.Char} !ProcessSerialNumber !*DLClientState -> *DLClientState;
