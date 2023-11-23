// Problems:
// - check that an internal reference is created for reference to an entry node if
//   it is the current entry node.
// - garbage collection with DETERMINE_ENTRY_NODES has not been test. 

#define EXTRAATJE

// should also change 
#include "globals.h"
#include "gts_debug.c"

// _SystemDynamic
/*
:: T_ypeObjectType
	= T_ypeConsSymbol !T_ypeName !T_ypeID [T_ypeObjectType]
	| PV_Placeholder (T_ypeObjectType -> T_ypeObjectType) T_ypeObjectType
	| UPV_Placeholder (T_ypeObjectType -> T_ypeObjectType) T_ypeObjectType
	| UV_Placeholder (T_ypeObjectType -> T_ypeObjectType) T_ypeObjectType
*/

// T_ypeConsSymbol-Node
#define TOT_TCS_TYPE_NAME	4

// Argument block
#define TOT_TCS_TYPE_ID		0
#define TOT_TCS_TOT_LIST	4

#define BUILD_DESCRIPTOR_BITSET			// buils a bitset (1 bit = word containing descriptor ptr or not
#define CONVERT_LAZY_RUN_TIME_ID		// handles lazy type references
#define DYNAMIC_STRINGS					// store dynamic strings
#define USE_USED_CODE_LIBRARY_INSTANCE_ARRAY

#include "global_registers.h"
#include "gts_stack.c"
#include "extra_heap.c"
#include "colour.c"

	.align	4
	.data
set_entry_size_in_words:
	.long 	0
set_entry_size_in_bytes:
	.long	0
array_colour:
	.long	0							// colour of the array

#include "gts_build_block.h"
#include "gts_gdi.c"

#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3
#define LB_ENTRY_BSIZE		4			// entry size = 2 ^ LB_ENTRY_BSIZE_EXP (in bytes)
#define LB_ENTRY_BSIZE_EXP	2			
#define MAKE_ID(x)			x##_DL			// data
#define MAKE_ID_NDL(x)		x##_fixed_DL	// no stack
#define MAKE_ID_UDL(x)		x##_unfixed_DL	// unfixed stack
#define MAKE_ID_FDL(x)		x##_fixed_DL	// fixed stack
#define BOTH_FIXEDNESS		

#include "LinkedBlock.c"

#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3
#define NOT_A_POWER_OF_TWO_ENTRY_SIZE
#define LB_ENTRY_WSIZE		5			//5
#define MAKE_ID(x)			x##_EN				// data
#define MAKE_ID_NEN(x)		x##_fixed_EN		// no stack
#define MAKE_ID_UEN(x)		x##_unfixed_EN		// unfixed stack
#define MAKE_ID_FEN(x)		x##_fixed_EN		// fixed stack
#define BOTH_FIXEDNESS							// used in both unfixed and fixed contents		
#define MAKE_ID_EN(x)		x##_EN

#include "LinkedBlock.c"
// Format EN:
// word 0: 	descP
// word 1 (1234):
//			- 12 offset array index i.e. id of entry node
//			- 34 except for two least significant bits represents the block_id in offset array
// word 2:
//			Offset from block start to the entry node
// word 3: unused (might come in handy for nodeP)

#define EN_DESCP			0
#define EN_COLOUR			4

// EN/SN-node, EN_COLOUR (1234): 1 = reserved
#define ENSN_COLOUR_GET_COLOUR				0x00ffffff 		// 0x3fffffff// 1234, 12 reserverd, 34 = colour

// byte 1, bit 4: set iff EN-node otherwise it is an SN-node
#define ENSN_COLOUR_SET_EN_BIT				0x80000000

// byte 1, bit 3: set iff EN/SN-node has already been visited, used in 2nd pass (determination of EN-nodes)
#define ENSN_COLOUR_ALREADY_VISITED_MASK	0x40000000

// Multiple combinations of bits
#define ENSN_COLOUR_EN_BIT_AND_COLOUR		0xbfffffff

#define EN_NODE_INDEX		8

#define EN_BLOCK_OFFSET	12
#define EN_NODEP			12			// used in pass 2 (determine en nodes)

#define EN_NODE_LIST		16			// used in pass 3 (copying)
#define EN_NODE			16			// first used in pass 4 //3

// BlockInfo
#define INITIAL_BLOCK_N	4			// 0 is reservered for top-level dynamic; two least significant bits are unused
#define BLOCK_INCREASEMENT	4

#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3
#define NOT_A_POWER_OF_TWO_ENTRY_SIZE
#define LB_ENTRY_WSIZE		3			
#define MAKE_ID(x)			x##_BI
#define BI_INFO			0
#define BI_N_EN_NODES		4
#define BI_SIZE			8
#define MAKE_ID_FBI(x)		x##_fixed_BI		// fixed stack
#define FIXED
#define MAKE_ID_BI(x)		x##_BI

#include "LinkedBlock.c"

#ifdef DYNAMIC_STRINGS

# define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
# define N_LB_ENTRIES_EXP	3
# define NOT_A_POWER_OF_TWO_ENTRY_SIZE
# define LB_ENTRY_WSIZE		3			//5
# define MAKE_ID(x)			x##_DS			// data
# define MAKE_ID_NDS(x)		x##_fixed_DS	// no stack
# define MAKE_ID_UDS(x)		x##_unfixed_DS	// unfixed stack
# define MAKE_ID_FDS(x)		x##_fixed_DS	// fixed stack
# define BOTH_FIXEDNESS		
# define MAKE_ID_DS(x)		x##_DS			

#include "LinkedBlock.c"

#endif // DYNAMIC_STRINGS

#include "gts_undo.c"

#ifdef CONVERT_LAZY_RUN_TIME_ID
// also change RunTimeIDW in DynamicLinkerInterface

# define RTID_LAST_FIELD			RTID_ASSIGNED_DISK_ID
# define RTID_SIZE					(RTID_LAST_FIELD + 4)

# define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
# define N_LB_ENTRIES_EXP	3
# define NOT_A_POWER_OF_TWO_ENTRY_SIZE
# define LB_ENTRY_WSIZE		3
# define MAKE_ID(x)			x##_RTID			// data
# define MAKE_ID_NRTID(x)	x##_fixed_RTID		// no stack
# define MAKE_ID_URTID(x)	x##_unfixed_RTID	// unfixed stack
# define MAKE_ID_FRTID(x)	x##_fixed_RTID		// fixed stack
# define BOTH_FIXEDNESS		
# define MAKE_ID_RTID(x)		x##_RTID			

# include "LinkedBlock.c"

# include "gts_runtime_id.h"
#endif

#include "gts_range_id.c"

// StdDynamicLowLevelInterface
/*
:: LazyDynamicReference
	= { 
		ldr_id					:: !Int			// run-time id of lazy dynamic
	,	ldr_lazy_dynamic_index	:: !Int			// disk id for build_lazy_block
	};
*/

// Node, *incorrect* for node
// unboxed
#define LDR_ID							0
#define LDR_LAZY_DYNAMIC_INDEX			4

#include "gts_build_lazy_block_id.c"
#include "gts_copy_graph_to_string_arguments.h"
#include "gts_copy_graph_to_string_results.h"

// -------------------------------------------------------------------------------------------
// HEADER
//
// Notice that part of the header is shared by different applications
//
// To add a new field:
// 1. add the field either in the common section or just for dumpDynamic
// 2. if its the last field, then mention it as the last field by replacing it in the
//    HEADER_SIZE-macro. (just below)

// Shared by:
// StdDynamicLowLevelInterface.{icl,dcl}; build_dynamic_header
// in application dumpDynamic & dynamic linker

// OBSOLETE:
// - StdDynamic.icl (StdEnv)
// - read_dynamic.icl (dumpDynamic)
// - dynamics.icl (dumpDynamic,dynamic linker)
//
// Probably only by StdDynamicLowLevelInterface.icl
#define HEADER_SIZE_OFFSET		8		// header size (in bytes)
#define VERSION_NUMBER_OFFSET	12		// version (major,minor) 		// little or big endian format?
#define GRAPH_OFFSET			16		// graph offset
#define GRAPH_SIZE				20		// graph size
#define BLOCK_TABLE_OFFSET		24
#define BLOCK_TABLE_SIZE		28
#define DYNAMIC_RTS_INFO_OFFSET	32		// info from dynamic rts; filled in by StdDynamic.icl
#define DYNAMIC_RTS_INFO_SIZE	36
// End sharing for StdDynamic.icl

#define STRINGTABLE_OFFSET		40		// stringtable offset
#define STRINGTABLE_SIZE		44		// stringtable size
#define DESCADDTRESTABLE_OFFSET	48		// descriptor address table offset
#define DESCADDRESSTABLE_SIZE	52		// descriptor address table size
#define N_NODES					56		// n_dynamics

#define DESCRIPTOR_BITSET_OFFSET	60
#define DESCRIPTOR_BITSET_SIZE		64 

#define HEADER_SIZE				(DESCRIPTOR_BITSET_SIZE-4)		//((last_field + 4)	- 8)=last_field-4  //32

#define HEADER_SIZE_IN_WORDS	(HEADER_SIZE / 4)	// in words

// Descriptor for graph_to_string function
// called by writeDynamic
	.data
#ifdef BUILD_DESCRIPTOR_BITSET
descriptor_bitset_start:
	.long	0
descriptor_bitset_end:
	.long	0
#endif

retry_after_gc:
	.long	0
type_string_ptr:
	.long 0

m__StdDynamic:
	.long	10
	.ascii	"StdDynamic"
	.byte	0,0

	.align 4
	.long	CLEAN_dcopy_graph_to_string+2
	.globl	CLEAN_dcopy_graph_to_string
CLEAN_dcopy_graph_to_string:
	.word	0
	.word	8
	.long	CLEAN_lcopy_graph_to_string
	.word	1
	.word	0
	.word	0
	.word	1
	.long	m__StdDynamic
i_133:
l_39:
	.long	23
	.ascii	"copy_graph_to_st"
	.ascii	"ring_OK"
	.byte	0

	.align 4
test_string:
	.ascii 	"test_string"
	.byte 0
		
// Global variables across passes
	.align	4	
t_stackP:
	.long 	0
initfree:	
	.long 0										// initial free words (4 bytes)

// backup variables
ecx_backup:
	.long	0
edx_backup:
	.long	0
	
old_heap_pointer:
	.long 0										// %edi before encoding started
	
root_node:
	.long 0										// graph to be encoded	

type_table_usage:
	.long 0
range_table:
	.long	0
	
#ifdef USE_USED_CODE_LIBRARY_INSTANCE_ARRAY
used_code_library_instance_array:
	.long	0
#endif

esp_backup:
	.long 0
esi_backup:
	.long 0

// -------------------------------------------------------------------------------------------
// .text

	.align 	4
	.text
	.align	4
CLEAN_lcopy_graph_to_string:
	cmpl	end_b_stack,%esp
	jb		stack_overflow
	call	ea11
	cmpl	end_heap,%edi
	jae		i_408
i_409:
	movl	$ CLEAN_rWrap+2,(%edi)
	movl	%ecx,4(%edi)
	movl	%edi,%ecx
	addl	$8,%edi
	ret

i_408:
	call	collect_1
	jmp		i_409

ea11:
	testb	$2,(%ecx)
	jne		e_44
	cmpl	end_a_stack,%esi
	jae		stack_overflow
	call	*(%ecx)
e_44:
	movl	4(%ecx),%ecx

	// pass1
copy__graph__to__string__0x00010101:
#ifdef DYNAMIC_STRINGS
	call	init_lazy_block_id
#endif

	/*
	** Warning: 
	** This function needs at least some space to operate. Because the run-time system
	** probably uses memory both before and after the call, not enough memory will 
	** cause an access violation.
	** called by the Clean and the garbage collector
	*/	
	// backup state; DO_NOT_CHANGE ...
	movl	%ecx,ecx_backup

#define temp %eax
	movl	CGTSA_DYNAMIC(%ecx),temp				// find root
	movl	temp,root_node

	movl	8(%ecx),%edx							// get arg block

	movl	CGTSA_TYPE_LIBRARY_INSTANCES(%edx),temp	// copy type library instances array
	movl	temp,type_table_usage
	
#ifdef USE_USED_CODE_LIBRARY_INSTANCE_ARRAY
	movl	CGTSA_CODE_LIBRARY_INSTANCES(%edx),temp	// copy type library instances array
	movl	temp,used_code_library_instance_array
#endif

	movl	CGTSA_RANGE_TABLE(%edx),temp			// copy range table
	movl	temp,range_table
#undef temp

	pushl 	%esi							// backup A-stack pointer
	movl	%esp,esp_backup					// backup esp
	movl	%esi,esi_backup					// backup esi
	movl	heapP,old_heap_pointer			// backup heap pointer

	// compute free space
	movl	end_heap,free
	leal	32(free),free		
	subl 	heapP,free						// free = stackP - heapP (in bytes)
	shrl 	$2,free							// free /= 4 (in longs)
	movl	free,initfree					// initfree = initial amount of memory available
	// ... DO_NOT_CHANGE (The garbage collector handler depends upon correct initialization)

	_set_default_undo_handler

	// After the first pass, the stack size will be fixed but the second pass which deletes
	// indirections in SN-nodes traverses the graph as a whole in contrast to the first 
	// colouring pass which traverses the graph on a dynamic base.
	// However, the graph has almost been traversed completely because the top-level dynamic
	// has been traversed. Additional 8 bytes for its two arguments are needed, to increase
	// the maximum stack size.
	// At label copy_done_colouring_finished the stack is enlarged by the size of the two
	// arguments of the top-level dynamic by subtracting 2 * 4 bytes from the StackTop. In
	// this way the stack is always big enough.
	subl	$2,free
	js 		undo_handler

	// initialize stack
	movl	end_heap,stackP
	leal	32(stackP),stackP				// end_heap + 32 is invalid; thus 32 - 4 = 28
	movl	stackP,extraheapBottom
	movl	stackP,extraP
	movl	stackP,stackBottom
	movl	stackP,stackTop
	
	subl	$(2 + HEADER_SIZE_IN_WORDS),free			
	js 		undo_handler

	movl 	$__STRING__+2,(heapP)					// store STRING descriptor
	movl 	$0,4(heapP)								// string length is zero

	leal	((2 * 4) + HEADER_SIZE)(heapP),heapP

	movl	%ecx,nodeP								// top node of graph to be encoded 
	
#ifdef CONVERT_LAZY_RUN_TIME_ID
	call 	MAKE_ID_NRTID(lb_init)
#endif

	call	MAKE_ID_NSN(lb_init)
	call	MAKE_ID_NDL(lb_init)
	jmp		start_pass1

// --------------------------------------------------------------------------------------------------------
// 2nd pass

	.data
	.align 4
function_name_list:
	.long 0
module_name_list:
	.long 0
n_nodes:
	.long 0

#include "prefixes.h"

	.align 4
	.data
	.align	4
s_copy_done:
	.long	__STRING__+2
	.long	9
	.ascii	"copy_done"
	//       012345678
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0	
s_interleaved_subcomponents:
	.long	__STRING__+2
	.long	66
	.ascii	"graph_to_string ERROR: interleaved subcomponents are unimplemented"
	//       012345678901234567890123456789012345678901234567890123456789012345
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0	

	.align 4

debug_count:
	.long 	0
counter:
	.long	0
en_list_base_address:
	.long	0
	
	.data
	.align	4
blocks_are_not_successive:
	.long	__STRING__+2
	.long	117
//	.ascii	"(graph_to_string; internal error) blocks are not successive"
	//       012345678901234567890123456789012345678901234567890123456789012345
	//		 0         1         2         3         4         5
	.ascii  "(graph_to_string.c; internal error; blocks are not successive): pa"
	.ascii	"ss the HyperStrictEvaluation-option to WriteDynamic"
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0
	
	.align	4
build_block_cannot_be_stored:
	.long	__STRING__+2
	.long	72
	//       012345678901234567890123456789012345678901234567890123456789012345
	//		 0         1         2         3         4         5
	.ascii  "(graph_to_string.c; internal error; build_block-closure cannot be "
	.ascii	"stored."
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0	
	.align 	4
counter_backup:
	.long	0
	.align	4
current_colour:
	.long	0
block_n:
	.long	0						// points to free block number
old_heapP:
	.long	0						// point to start address of block

dus_entry_bsize:					// size of descriptor usage set-entry
	.long 	0	
	
// adapt also function read_descriptor_usage_table in StdDynamicLowLevelInterface.icl
// fixed part:
#define DUS_DESC_ADDRESS_ENTRY	0
#define DUS_LIBRARY_NUMBER		4
#define DUS_FIXED_ENTRY_BSIZE	(DUS_LIBRARY_NUMBER + 4)
#define DUS_FIXED_ENTRY_WSIZE	(DUS_FIXED_ENTRY_BSIZE / MACHINE_WORD_BSIZE)
// variable part:
#define DUS_SET					8

	// -------------------------------------------------------------
	// pass2
	.data
ptr_to_dynamic_to_be_added:
	.long	0
stored_ptr_to_dynamic:
	.long 	0
current_dynamic_node:
	.long 	0 

	.text
#include "gts_colour_graph.c"

reset_colour_table_entry:
	movl	$0,(%ecx)							// should be initialized at zero
	ret

copy_done_no_top_level_dynamic:
	int3
	jmp		copy_done_no_top_level_dynamic

	// PASS 1: colour graph
copy_done:
start_pass1:
	call	MAKE_ID_NEN(lb_init)					// initialize Entry Node (EN) array
#define en_node %ecx	
	movl	root_node,nodeP

	call	MAKE_ID_NEN(lb_alloc_entry)
	movl	(nodeP),descP
	movl	descP,EN_DESCP(en_node)
	
	movl	$ TOPLEVEL_COLOUR,EN_COLOUR(en_node)

	// update root node (from this point on: only U and F permitted)
	leal	1(en_node),en_node
	movl	en_node,(nodeP)
#undef en_node

	_set_undo_handler $undo_colouring

	// colour rest of graph
	cmpl	$ CLEAN_rDynamicTemp+2,descP
	jne 	copy_done_no_top_level_dynamic

	call 	MAKE_ID_UDL(lb_alloc_entry)			// add top level dynamic to dynamic list
	movl	nodeP,(%ecx)

	call	init_colour_table					// initialize colour table
		
#define counter %ecx
#define limit %ebx
	movl	$1,limit
	movl	$0,counter							// counter initialized at zero

copy_done_loop:
	pushl	limit
	movl	counter,counter_backup

	call	MAKE_ID_UDL(lb_index_of_entry)
	movl	(%ecx),nodeP						// nodeP is a DynamicTemp node
	movl	nodeP,current_dynamic_node

	// colour value
	call	MAKE_ID_UCT(lb_size)
	movl	%ecx,previous_colour_combinations
	
	pushl	8(nodeP)							// backup type node
	movl	4(nodeP),nodeP						// current node is value node

	movl	$ reset_colour_table_entry,%ecx
	call	MAKE_ID_UCT(lb_map_array)			// reset colour table

	call	visit_nodes_from_nodeP				// colour it

	// colour type
	call	MAKE_ID_UCT(lb_size)
	movl	%ecx,previous_colour_combinations

	popl	nodeP

	movl	$ reset_colour_table_entry,%ecx
	call	MAKE_ID_UCT(lb_map_array)			// reset colour table

	call	visit_nodes_from_nodeP				// colour it

	movl	counter_backup,counter
	popl	limit

	cmpl	$0,counter
	jne 	limit_does_not_change_any_more

	pushl	counter
	call	MAKE_ID_UDL(lb_size)				// n_dynamics
	movl	%ecx,limit
	popl	counter

limit_does_not_change_any_more:
	incl 	counter

	cmpl	counter,limit
	jne		copy_done_loop	

#undef counter
#undef limit
	movl	MAKE_ID_SN(lb_root),%eax

	// --------------------------------------------------------------------------------------
	// PASS 2: determing entry nodes
copy_done_colouring_finished:		
	// The 8 bytes have already been reserved during initialization. It is mainly
	// done for making the undo_colouring-routine more simple.
	subl	$8,stackTop

#define sh_entry descP
#undef sh_entry
	movl	$ reset_colour_table_entry,%ecx
	call	MAKE_ID_FCT(lb_map_array)			// reset colour table

	movl	$0,%ecx
	call	MAKE_ID_FEN(lb_index_of_entry)
#define entry_node %ecx
	orl		$ ENSN_COLOUR_SET_EN_BIT,EN_COLOUR(entry_node)	// mark as entry node

	movl	$0,EN_NODE_INDEX(entry_node)

#define temp nodeP
	movl	root_node,nodeP
	movl	nodeP,EN_NODEP(entry_node)			// NEW!!! set nodeP to be used in pass 2
#undef temp

#undef entry_node

	movl	$ INITIAL_BLOCK_N,block_n			// initialize block_n
	
	call	MAKE_ID_FBI(lb_init)

	// assumption: at least one dynamic
#define temp2 %ecx
	movl	root_node,nodeP						// nodeP = root nodeP

	// set colour of root dynamic
	movl	$ 0,temp2
	call	MAKE_ID_FEN(lb_index_of_entry)
	movl	EN_COLOUR(temp2),temp2
	andl	$ ENSN_COLOUR_GET_COLOUR,temp2
	movl	temp2,current_colour

	call	init_range_id

#include "gts_determine_entry_nodes.c"

	// --------------------------------------------------------------------------------------
copy_equally_coloured_nodes_finished:
	call	restore__Module_descriptors

	movl	heapP,graph_end							// backup end of graph encoding

#ifdef BUILD_DESCRIPTOR_BITSET
# define temp %eax
	movl	heapP,temp
	subl	graph_start,temp						// encoded graph size (in bytes; always multiple of 4 bytes)
	
	shrl	$2,temp									// encoded graph size (in words)

	addl	$31,temp								
	shrl	$5,temp									// bitmapped graph size
		
	subl	temp,free								// reserve heap for bitmapped graph size
	js		undo_handler
	
	movl	heapP,descriptor_bitset_start
0:													// clear, initially no descriptors but there are of course
	movl 	$0,(heapP)								// always more than one.
	addl 	$4,heapP
	decl 	temp
	jnz		0b
# undef temp

	movl	heapP,descriptor_bitset_end
#endif 
	
#define temp nodeP
	call 	MAKE_ID_FBI(lb_size)					// # blocks allocated + allocated root block
	
	movl	block_n,temp
	shrl	$2,temp							
	cmpl	%ecx,temp
	je		0f

	// I think blocks are never interleaved because after the first pass it is
	// known which nodes belong to a block. Equally coloured nodes are encoded
	// together.
	// Using DETERMINE_ENTRY_NODES blocks are never interspersed with other
	// blocks
1:	
	int3

	movl	MAKE_ID_EN(lb_root),%ebx	
	movl	root_node,%eax
	movl	$ blocks_are_not_successive,%ecx
	jmp		abort

0:
#undef temp

#define temp nodeP
	// The associated descriptors of a block are computed here and stored just after the
	// stringtable.
	movl	block_n,temp
	
	shrl	$2,temp
	addl	$31,temp
	shrl	$5,temp								// temp = set size (in words)
	movl	temp,usage_bit_set_size
	
	addl	$ DUS_FIXED_ENTRY_WSIZE,temp		// temp = set size + size of fixed part
	movl	temp,set_entry_size_in_words		// store entry size in words
	
	shll	$2,temp
	movl	temp,set_entry_size_in_bytes		// store entry size in bytes
	
	movl	temp,dus_entry_bsize
	movl	heapP,dus_start

# define STORE_USAGE_BIT_SET_SIZE

#ifdef STORE_USAGE_BIT_SET_SIZE
# define DUS_USAGE_BIT_SIZE			0
# define DUS_N_USAGE_ENTRIES		4

# define DUS_HEADER_BSIZE		(DUS_N_USAGE_ENTRIES + 4)
# define DUS_HEADER_WSIZE		(DUS_N_USAGE_ENTRIES / MACHINE_WORD_BSIZE)

	subl	$2,free
	js		undo_handler

# define temp2 %ecx
	movl	usage_bit_set_size,temp2			// store entry size in words
	movl	temp2,DUS_USAGE_BIT_SIZE(heapP)
	
	movl	$0,n_usage_entries					// intilialize usage entry counter
	
	addl	$ DUS_HEADER_BSIZE,heapP
# undef temp2
#endif

	_set_undo_handler $undo_descriptor_usage
	
	movl	$ compute_descriptor_usage,%ecx
	call	MAKE_ID_FSN(lb_map_array)
	
	// The top-level dynamic is only inserted in the EN-table and not in the SN-table. Thus
	// compute_descriptor_usage 
	
	movl	$ 0,%ecx
	call	MAKE_ID_FEN(lb_index_of_entry)
	
	call	compute_descriptor_usage
	
	movl	$ compute_descriptor_usage,%ecx
	call	MAKE_ID_FEN(lb_map_array)

#define dus_n_usage_entries %eax
	movl	dus_start,dus_n_usage_entries
	
#define temp3 %ebx
	movl	n_usage_entries,temp3
	movl	temp3,DUS_N_USAGE_ENTRIES(dus_n_usage_entries)
#undef temp3
#undef dus_n_usage_entries

	movl	heapP,dus_end
	jmp		delete_indirections
#undef temp

	// compute_descriptor_usage:
	// 
	// the descriptor usage table is constructed for each SN-node. The algorithm can
	// be divided in:
	// - creating a dus-entry
	// - marking a dus-entry as used by a colour
	//
	// A dus entry looks like this:
	// 0	first four characters, backuped from the descriptor name
	// 4	library instance number
	// 12	marking set. Size is number of colours.
	// ?
	//
	// dynamicTemp voor root dynamic moet ook een entry in EN krijgen
	// call MAKE_ID_EN (het aflopen van SN is genoeg moet alleen nog root toevoegen)
	// descriptors van arrays 'inherit
	// TODO:
	// - descriptors van arrays (gaat goed)
compute_descriptor_usage:
#define sn_entry %ecx
	// compute pointer to descriptor name (similar to fragment in _copy_name)
#define temp nodeP
	movl	SN_COLOUR(sn_entry),temp
	andl	$ ENSN_COLOUR_GET_COLOUR,temp
	pushl	temp
	
	movl	SN_DESCP(sn_entry),descP

	cmpl	$ CLEAN_nbuild_block,descP
	jne		hiero
	movl	$ CLEAN_nbuild_lazy_block,descP
hiero:

#undef sn_entry

	call	compute_label_name_ptr
#define desc_nameP source

#define setP descP
	movl	4(desc_nameP),setP
	testl	setP,setP
	jns		3f									// allocate space for four characters and set
	
	shll	$1,setP
	jmp		compute_descriptor_usage_got_space_for_set

	// allocate space
3:
	subl	set_entry_size_in_words,free
	js		undo_handler
	
	// initialize new block
#ifdef STORE_USAGE_BIT_SET_SIZE
	incl	n_usage_entries						// count usage table entries
#endif

	movl	setP,(heapP)						// backup first four characters
	
#define setP_backup arity
	movl	heapP,setP_backup					// backup pointer
	
#define temp nodeP
	movl	heapP,temp
	shrl	$1,temp
	orl 	$0x80000000,temp
	movl	temp,4(desc_nameP)					// first four characters of descriptor are marked and are pointer to dus-entry
#undef temp

#define counter nodeP
#define limit descP
	movl	$0,counter
	movl	set_entry_size_in_words,limit
	decl	limit
	addl	$4,heapP
	
4:
	movl	$0,(heapP)
	addl	$4,heapP
	incl	counter
	cmpl	counter,limit
	jne		4b									// empty descriptor usage set					
#undef counter
#undef limit
	
	pushl	setP_backup							// backup ptr to dus entry
	movl	desc_nameP,%ebx						// load address in library
	call	find_code_library_instance_nr		// %eax = library instance number
	popl	setP								// restore ptr to dus_entry	
	movl	%eax,DUS_LIBRARY_NUMBER(setP)		// store library number
	
#undef setP_backup
compute_descriptor_usage_got_space_for_set:
	// setP = address of set entry
	// tos	= current colour
#define current_colour arity
	popl	current_colour
	call	MAKE_ID_FCT(lb_index_of_entry)		
#define associated_block current_colour
	movl	(associated_block),associated_block
	andl	$0x0000fffc,associated_block

	shrl	$2,associated_block					// get block_n
	
#define word_index_in_set nodeP
	movl	associated_block,word_index_in_set
	shrl	$5,word_index_in_set				// word index in set
	
	movl	word_index_in_set,word_index_in_set

#define bit_index_in_set_word associated_block
	movl	associated_block,bit_index_in_set_word	// index of bit to be set in that word
	andl	$31,bit_index_in_set_word
	
#define temp source
	movl	$1,temp
	shll	%cl,temp							// build proper mask
#undef associated_block
#undef bit_index_in_set_word
	
#define set_word arity
	movl	DUS_FIXED_ENTRY_BSIZE(setP,word_index_in_set,4),set_word
	orl		temp,set_word
	movl	set_word,DUS_FIXED_ENTRY_BSIZE(setP,word_index_in_set,4)
#undef set_word
#undef setP
#undef temp
#undef current_colour
#undef desc_nameP
	ret

// ****
// compute_label_name_ptr
// precondition:
// - descP contains a valid (unmodified) descriptor pointer
// postcondition:
// - source contains the descName

compute_label_name_ptr:
	testl	$2,descP							
	je		0f									// closure detected

	movzwl	-2(descP),arity
	cmpl	$256,arity
	jb		1f

#define desc_nameP source
	movl	-6(descP),desc_nameP				// get descriptor name
	ret

1:
#define temp nodeP
	movzwl	(descP),temp						// temp = partial arity * 8
	lea		10(descP,temp),desc_nameP
	ret
	
	// closures
0:
	movl	-8(descP),desc_nameP				// get descP
	
	movl	-4(descP),arity
	testl	arity,arity
	jns 	3f
	movl	$1,arity
3:	
	movzwl	2(desc_nameP),temp
	lea		12(desc_nameP,temp),desc_nameP
	ret
#undef temp
#undef desc_nameP
	ret

// -----------------------------------------------------------------------------------------
// Heap situation:
// - the modified descriptors i.e. first four characters have been backup and replaced by a pointer in the
//	 descriptor address table.
// - (nodeP) has bit#0 set. Two cases:
//		1) (nodeP) < heapP i.e. an indirection via the encoded graph
//		2) otherwise i.e. (nodeP) is a SN/EN-pointer

// pass 1; DELETE
#define ML(x)				x##_1
#define ENTRY_LABEL			delete_next_indirection_1
#define ENTRY_LABEL_NODEP	delete_next_indirection_in_nodeP_1
#define EXIT_LABEL			deletion_done_1

#define COPY_NAMES_PASS

delete_indirections:
	movl	$0,n_nodes

#define t0 %eax
	movl	stackTop,t0
	movl	t0,descStackTop
#undef t0
	movl	root_node,nodeP
	
	// descriptor prefix table may never start at offset 0
	movl	$0,function_name_list
	movl	$0,module_name_list

	movl	heapP,string_table_base

	jmp		ML(delete_next_indirection_in_nodeP)

#include "gts_delete.c"

#undef EXIT_LABEL

#include "gts_adjust_descriptor_offsets.c"

	.align 4

deletion_done_1:
	movl	heapP,string_table_end

#define	name_p arity
#define temp   nodeP
#define temp2 descP
removing_forwarding_pointers_in_strings:
	movl	function_name_list,name_p
#define t0 stackP
#define t1 source
#define t2 heapP
	pushl	t0
	pushl	t1
	pushl	t2
	movl	stackTop,t0
	movl	string_table_base,t2
	
remove_function_names:
	testl	name_p,name_p
	je		end_remove_function_names
 
	movl	(name_p),temp					// temp = address function name in descriptor
	shll	$1,temp						
	
	movl	(temp),temp
	andl	$0x00ffffff,temp
	leal	(t2,temp),temp					// temp = address in string table
		
	movl	-4(temp),temp2					// get length
	movl	temp2,(name_p)					// restore length in descriptor string

	movl	(temp),temp						// get 1st four characters
	movl	4(name_p),temp2					// exchange name_p with 1st four chars
	movl	temp,4(name_p)

	movl	temp2,name_p
	jmp	remove_function_names

end_remove_function_names:
	popl	t2
	popl	t1
	popl	t0
#undef t2
#undef t1
#undef t0

	movl	module_name_list,name_p

remove:
	testl	name_p,name_p
	je		end_remove_forwarding_pointers

	movl	(name_p),temp		
	shll	$1,temp							// temp = pointer to name of function
	
	movl	-4(temp),temp2					// get length
	movl	temp2,(name_p)					// restore length in descriptor string
	
	movl	(temp),temp						// get 1st four characters
	movl	4(name_p),temp2					// exchange name_p with 1st four chars
	movl	temp,4(name_p)

	movl	temp2,name_p
	jmp	remove
	
end_remove_forwarding_pointers:
#undef temp
#undef name_p
#undef temp2

	testl	free,free	
	js		undo_handler					// graph has been restored, do a gc (graph has been restored)

	_set_default_undo_handler

	movl	$ mark_EN_nodes_as_such,%ecx 	// EN-nodes are marked by setting bit#0
	call	MAKE_ID_FEN(lb_map_array)
	
	// computing the proper descP offset within a single component. The dynamic linker
	// will use the order of the descriptor address table to build a table for each block
	// separately.
	//
	// First the entry nodes of a particular block are traversed and marked as having been
	// visited, offsets are adapted accordingly.	
	
	pushl	%edi
	movl	$ adjust_offset_per_block,%ecx
	call	MAKE_ID_FBI(lb_map_array)

	movl	$ unmark_EN_nodes_as_such,%ecx
	call	MAKE_ID_FEN(lb_map_array)
	
	popl	%edi
	// encode descriptor prefix table ...
	
#define dus_p		arity
#define dus_end_p	descP

	movl	dus_start,dus_p
#ifdef STORE_USAGE_BIT_SET_SIZE
	leal	DUS_HEADER_BSIZE(dus_p),dus_p	// skip usage entry size
#endif

	movl	dus_end,dus_end_p
0:
#define temp nodeP
	movl	(dus_p),temp					// get descriptor prefix table ptr
	movl	DPT_PREFIX_SET_AND_STRING_PTR(temp),temp
	movl	temp,(dus_p)
#undef temp	

	addl	dus_entry_bsize,dus_p
	
	cmpl	dus_end_p,dus_p
	jb		0b
#undef dus_p
#undef dus_end_p
	// ... encode descriptor prefix table	

#include "gts_return.c"
