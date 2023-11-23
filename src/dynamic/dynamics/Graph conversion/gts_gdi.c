#ifndef GTS_GDI_C
#define GTS_GDI_C

// DynamicGraphConversion
/*
:: GlobalDynamicInfo = {
	// general
		file_name		:: !String
	,	first_time		:: !Bool

	// block table
	,	id				:: !Int				// id from Dynamic Linker
	,	block_table		:: !BlockTable		
	,	graph_blocks	:: !{String}		// filepointer to start of graph
	,	graph_pointers	:: !{#.{Int}}
	
	// 
	,	diskid_to_runtimeid	:: !{#Int}		// conversion from DiskId (disguished as RunTimeId) to *real* runtimeID
	}
*/

// Node, *incorrect* for unboxed array
#define GDI_FILE_NAME					4

// Argument block; boxed
#define GDI_BLOCK_TABLE					0
#define GDI_GRAPH_BLOCKS				4
#define GDI_GRAPH_POINTERS				8
#define GDI_DISKID_TO_RUNTIMEID			12
#define GDI_DISK_TO_RT_DYNAMIC_INDICES	16
#define GDI_DUMMY						20
#define GDI_TYPE_REDIRECTION_TABLE		24
#define GDI_SHARED_BLOCKS				28

// unboxed
#define GDI_FIRST_TIME					32	//24		//20
#define GDI_ID							36	//28		//24

#define GDI_LAST_FIELD				GDI_ID
#define GDI_SIZE					(GDI_LAST_FIELD + 4)

#endif // GTS_GDI_C