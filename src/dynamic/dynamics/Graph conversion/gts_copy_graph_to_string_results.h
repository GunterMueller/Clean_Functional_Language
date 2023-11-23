// DynamicGraphConversion
/*
:: *CopyGraphToStringResults
	= {
		cgtsr_encoded_dynamic			:: !*{#Char}
	,	cgtsr_code_library_instances	:: !*{#Int}
	,	cgtsr_type_library_instances	:: !*{#Int}
	,	cgtsr_lazy_dynamic_references	:: !{#LazyDynamicReference}
	,	cgtsr_runtime_ids				:: !{#RunTimeID}
	};
*/

// Node, *incorrect* for unboxed array
#define CGTSR_ENCODED_DYNAMIC			4

// Argument block; boxed
#define CGTSR_CODE_LIBRARY_INSTANCES	0
#define CGTSR_TYPE_LIBRARY_INSTANCES	4
#define CGTSR_LAZY_DYNAMIC_REFERENCES	8
#define CGTSR_RUNTIME_IDS				12

// Unboxed
// nothing

#define CGTSR_LAST_FIELD_OF_ARG_BLOCK	CGTSR_RUNTIME_IDS
#define CGTSR_ARG_BLOCK_SIZE			(CGTSR_LAST_FIELD_OF_ARG_BLOCK + 4)


