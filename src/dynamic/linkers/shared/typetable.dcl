definition module typetable;

from StdMaybe import :: Maybe;
from type_io_read import :: TypeIOState, :: RTI, :: TIO_CommonDefs;
from StdDynamicTypes import :: TIO_TypeReference;

:: *TypeTable = {
	// Name
		tt_name					:: !String
	,	tt_loaded				:: !Bool				// type tables are loaded lazily
	// type information
	,	tt_type_io_state		:: !*TypeIOState
	,	tt_tio_common_defs		:: !*{#TIO_CommonDefs}
	,	tt_n_tio_common_defs	:: !Int
	// library info; should move to .lib
	, 	tt_rti					:: RTI	
	// hash 
	,	tt_hash_table			:: !{#{#TypeTableHashElement}}
	};

:: HashTable
	:== {#{#TypeTableHashElement}};
	
default_type_table :: *TypeTable;

:: TypeTableHashElement
	= {
		tthe_module_index	:: !Int								// stringtable index for Module
	,	tthe_kind			:: !TypeTableHashElementNameKind	// for Type and Constructor
	};
	
:: TypeTableHashElementNameKind
	= TTHE_ModuleName
	| TTHE_TypeName !TIO_TypeReference	!Int				// type reference, stringtable index of Type name
	| TTHE_ConstructorName !TIO_TypeReference !Int			// constructor type reference, stringtable index of Constructor name
	| TTHE_PredefinedConstructorName !TIO_TypeReference		// isTypeWithoutDefinition must return True on the type reference
	; 

class TypeTableOps s
where {
	AddReferenceToTypeTable :: !String !*s -> (!Int,!*s);
	
	AddTypeTable :: !Int *TypeTable !*s -> *s
};

instance TypeTableOps {#*TypeTable};

class findTypeUsingTypeName s :: !String !String !Int !*s -> (!Maybe TIO_TypeReference,!*s);

instance findTypeUsingTypeName {#TypeTable};

class findTypeUsingConstructorName s :: !String !String !Int !*s -> (!Maybe TIO_TypeReference,!*s);

instance findTypeUsingConstructorName {#TypeTable};

class findModuleName s :: !String !Int !*s -> (!Maybe Int,!*s);

instance findModuleName {#TypeTable};

hashValue :: !String -> Int;
