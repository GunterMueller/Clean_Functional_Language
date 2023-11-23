definition module type_io_read

from NamesTable import ::NamesTable, ::SNamesTable, ::NamesTableElement
from general import ::Optional;
from StdFile import ::Files
from pdSymbolTable import ::LibraryList;
from StrictnessList import ::StrictnessList
from StdOverloaded import class toString, class ==
from StdDynamicTypes import :: LibRef, :: LibraryInstanceTypeReference, :: TIO_TypeReference
from BitSet import :: BitSet
from StdMaybe import :: Maybe
from DefaultElem import class DefaultElem

// Hashtable
NAME_TABLE_SIZE			:== 4096;
NAME_TABLE_SIZE_MASK 	:== 4095;

:: HashTableElement
	= {	hte_name					:: !String
	,	hte_index					:: !Int
	,	hte_type_refs				:: !TypeName			// references types with same names
	,	hte_module_ref				:: !ModuleName
	}
	
:: TypeName
	= NoTypeName
	| TypeName [TIO_TypeReference]			// references to possibly different but equally named types
	;
	
isNoTypeName :: TypeName -> Bool
	
:: ModuleName
	= NoModuleName
	| ModuleName Int						// module index in {TIO_CommonDefs}-array
	;
get_type_name :: !TIO_TypeReference !String !*{#TIO_CommonDefs} -> (!String,!*{#TIO_CommonDefs});

name_hash :: !String -> Int;

type_io_find_name :: !String !*TypeIOState -> *(!Bool,!HashTableElement,!*TypeIOState);	

insert_name :: !(Optional Int) (Optional (!Int,!Int)) !.{#Char} !*TypeIOState -> *(!Int,!*TypeIOState);			

:: *TypeIOState = {
	// String index table; used during read_type_info
		tis_current_string_index	:: !Int
	// String hash table
	,	tis_string_hash_table		:: !*{[HashTableElement]}
	,	tis_string_table			:: !String						// * dynamic rts
	// Used by TypeDef
	,	tis_current_module_i		:: !Int
	,	tis_current_def_i			:: !Int							// type or cons def
	// ?
	,	tis_max_types_per_module		:: !{#Int}					// index in bitset column
	, 	tis_n_common_defs				:: !Int						
	,	tis_max_types					:: !Int
	// used after equivalent types have been determined
	,	tis_equivalent_type_definitions	:: !{#EquivalentTypeDef}	// * dynamic rts
	// used to reuse the read_type_info
	,	tis_reading_typ_file			:: !Bool					// .typ file
	};

default_type_io_state :: *TypeIOState

class ReadTypeInfo a
where
	read_type_info :: !*File !*TypeIOState -> (!Bool,!a,!*File,!*TypeIOState)
	
instance ReadTypeInfo TIO_CommonDefs

instance DefaultElem TIO_CommonDefs

// Type IO
::	TIO_CommonDefs =
	{	tio_com_type_defs 				:: !.{# TIO_CheckedTypeDef}
	,   tio_com_cons_defs				:: !.{# TIO_ConsDef}
	,	tio_imported_modules			:: !.{#Int}							// offsets in string table; becomes index in {#TIO_CommonDefs}
	,	tio_n_exported_com_type_defs	:: !Int
	,	tio_n_exported_com_cons_defs	:: !Int
	,	tio_module						:: !Int								// offset in string table
	,	tio_global_module_strings		:: !{#{#Char}}
	}
	
::	TIO_CheckedTypeDef	:== TIO_TypeDef TIO_TypeRhs

::	TIO_TypeDef type_rhs =
	{
		tio_td_name							:: !Int
	,	tio_td_arity						:: !Int
	,	tio_td_args							:: ![TIO_ATypeVar]		// - normalized so not necessary
	,	tio_td_rhs							:: !type_rhs
	
	// only used by after reading a TIO
	,	tio_type_equivalence_table_index	:: !Optional Int
	};

::	TIO_TypeRhs	= TIO_AlgType ![TIO_ConstructorSymbol]
				| TIO_SynType !TIO_AType
				| TIO_RecordType !TIO_RecordType
				| TIO_GenericDictionaryType !TIO_RecordType
				| TIO_AbstractType !TIO_BITVECT
				| TIO_UnknownType
				
::	TIO_DefinedSymbol = 
	{	tio_ds_ident			:: !Int
 	,	tio_ds_arity			:: !Int
	,	tio_ds_index			:: !TIO_Index					// waar wijst dit veld na? index in tio_com_cons_defs
	}

::	TIO_ConstructorSymbol =
	{	tio_cons :: !TIO_DefinedSymbol
	}

::	TIO_RecordType =
	{	tio_rt_constructor		:: !TIO_DefinedSymbol
	,	tio_rt_fields			:: !{# TIO_FieldSymbol}
	}

::	TIO_ConsDef =
	{	tio_cons_symb			:: !Int	
	,	tio_cons_type			:: !TIO_SymbolType
	,	tio_cons_type_index		:: !TIO_Index			// remove?
	,	tio_cons_exi_vars		:: ![TIO_ATypeVar]
	}

::	TIO_ATypeVar =
	{
		tio_atv_variable		:: !TIO_TypeVar
	}

::	TIO_AType =
	{
		tio_at_type				:: !TIO_Type
	}

::	TIO_Type =	TIO_TAS !TIO_TypeSymbIdent ![TIO_AType] !StrictnessList
			|	TIO_TAS_tcl !TIO_TypeSymbIdent !TIO_GlobalIndex ![TIO_AType] !StrictnessList
			|	(---->) infixr 9 !TIO_AType !TIO_AType
			|	(:@@:) infixl 9 !TIO_ConsVariable ![TIO_AType]
			|	TIO_TB !TIO_BasicType
			| 	TIO_GTV !TIO_TypeVar
			| 	TIO_TV !TIO_TypeVar
			|	TIO_TQV	TIO_TypeVar
			|	TIO_GenericFunction !{#Char} /*kind*/ !TIO_SymbolType
			|	TIO_TE
			|	TIO_DefaultElem

::	TIO_SymbolType =
	{	tio_st_vars				:: ![TIO_TypeVar]
	,	tio_st_args				:: ![TIO_AType]
	,	tio_st_args_strictness	:: !StrictnessList
	,	tio_st_arity			:: !Int
	,	tio_st_result			:: !TIO_AType
	}
	
::	TIO_BasicType	= TIO_BT_Int | TIO_BT_Char | TIO_BT_Real | TIO_BT_Bool | TIO_BT_Dynamic
					| TIO_BT_File | TIO_BT_World
					| TIO_BT_String !TIO_Type /* the internal string type synonym only used to type string denotations */
					
instance toString TIO_BasicType
	
::	TIO_TypeVar =
	{	
		tio_tv_name			:: !Int
	}

::	TIO_ConsVariable = TIO_CV 		!TIO_TypeVar
					 | TIO_TempCV 	!TIO_TempVarId
					 | TIO_TempQCV 	!TIO_TempVarId
					 
::	TIO_TempVarId		:== Int

::	TIO_TypeSymbIdent =
	{	tio_type_name_ref	:: !TIO_TypeReference
	,	tio_type_arity		:: !Int
	}

::	TIO_GlobalIndex =
	{	tio_glob_object		:: !TIO_Index
	,	tio_glob_module		:: !TIO_Index
	}
    
TIO_NoIndex	:== -1
	
class isTypeWithoutDefinition a :: !a -> Bool

instance isTypeWithoutDefinition TIO_TypeReference

makeTypeWithoutDefinition :: !String -> TIO_TypeReference

:: TypeTableTypeReference
	= TypeTableTypeReference !Int !TIO_TypeReference
	
instance toString TypeTableTypeReference

instance == TypeTableTypeReference

instance isTypeWithoutDefinition TypeTableTypeReference

instance == LibraryInstanceTypeReference;

instance == LibRef

instance isTypeWithoutDefinition LibraryInstanceTypeReference

:: 	TIO_Index	:== Int

::	TIO_BITVECT :== Int

::	TIO_FieldSymbol = { tio_fs_name :: !Int }

empty_tio_common_def :: TIO_CommonDefs

:: EquivalentTypeDef
	= { type_name	:: Int							// name of type
	,	partitions	:: !{#{# TIO_TypeReference}}	// grouped definitions by equality of a type with the above name 
	};

instance DefaultElem TIO_ConsDef
instance DefaultElem (TIO_TypeDef a) | DefaultElem a
instance DefaultElem TIO_TypeRhs

:: RTI
	= {	rti_n_libraries			:: !Int
	,	rti_library_list		:: !LibraryList
	,	rti_n_library_symbols	:: !Int
	};

default_RTI :: RTI;
	
read_type_information typ_file_name names_table files :== read_type_information_new True typ_file_name names_table files;

read_type_information_new :: !Bool !String !*NamesTable !*Files -> (!Bool,!RTI,!*{#TIO_CommonDefs},!*TypeIOState,!*NamesTable,!*Files)

initialize_type_io_state :: !*{#TIO_CommonDefs} !*TypeIOState -> (!*{#TIO_CommonDefs},!*TypeIOState)

get_name_from_string_table :: !Int !String -> String

instance DefaultElem (Maybe a)
