// DynamicGraphConversion
/*
:: *CopyGraphToStringArguments
	= {
		cgtsa_dynamic					:: Dynamic
	,	cgtsa_code_library_instances	:: !*{#Int}
	,	cgtsa_type_library_instances	:: !*{#Int}
	,	cgtsa_range_table				:: !{#Char}
	};
*/

// Node, *incorrect* for unboxed array
#define CGTSA_DYNAMIC					4

// Argument block; boxed
#define CGTSA_CODE_LIBRARY_INSTANCES	0
#define CGTSA_TYPE_LIBRARY_INSTANCES	4
#define CGTSA_RANGE_TABLE				8

// Unboxed
// nothing

#define CGTSA_LAST_FIELD_OF_ARG_BLOCK	CGTSA_RANGE_TABLE
#define CGTSA_ARG_BLOCK_SIZE			(CGTSA_LAST_FIELD_OF_ARG_BLOCK + 4)
