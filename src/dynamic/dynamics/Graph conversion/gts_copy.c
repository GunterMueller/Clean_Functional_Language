// PASS: COPY GRAPH
// 
// Interface:
//
// #define ML(x)				x##id e.g. _1
// #define ENTRY_LABEL			copy_next_node					*
// #define ENTRY_LABEL_NODEP	copy_next_node_in_nodeP			*
// #define EXIT_LABEL			copy_done
// #include "gts_copy.c"
// #undef EXIT_LABEL
//

#ifdef UNFIXED_STACK
# define PUSHL2					_pushl_gc
# define RESERVE_STACK_BLOCK	_reserve_stack_block_gc
# define COPY_STACK_BLOCK		_copy_stack_block_gc
#else
# define PUSHL2					_pushl_no_gc
# define RESERVE_STACK_BLOCK	_reserve_stack_block_no_gc
# define COPY_STACK_BLOCK		_copy_stack_block_no_gc
#endif

// mutally exclusive options
#include "gts_shared_macros.c"
	
// Macros:

	// _copy_heap_block:
	//
	// call by:
	//
	// -	source
	//	the source address
	// -    arity
	//	number of longs to copy 	
#define COPY_HEAP_BLOCK			ML(_copy_heap_block)
	.macro ML(_copy_heap_block)
		subl 	arity,free					// free < length
		js 		undo_handler
		
		cld
		rep
		movsl
	.endm
	
// Code:
ENTRY_LABEL:
 	_try_popl nodeP EXIT_LABEL				//ML(copy_done)
 	
ENTRY_LABEL_NODEP:
	movl 	(nodeP),descP					// get descriptor pointer
	cmpl	heapP,descP						// descP <= heapP
	jbe		ML(copy_indirection)
	
	// descP > heapP i.e. descP points in shared nodes table
	decl	descP

#ifdef EXTRAATJE
# define temp %ecx
	movl	SN_COLOUR(descP),temp							// get colour of node
	andl	$ ENSN_COLOUR_GET_COLOUR,temp
	cmpl	temp,current_colour
	je		8f

	movl	EN_NODE_INDEX(descP),temp
	
	// store encoded external reference (identical to earlier case)
	subl	$1,free
	js		undo_handler
	orl		$3,temp
	movl	temp,(heapP)
	addl	$4,heapP

	jmp		ENTRY_LABEL
	
8:
	movl	SN_COLOUR(descP),temp							// get colour of node
	testl	$ ENSN_COLOUR_SET_EN_BIT,temp
 	jz		ML(copy_non_shared_node)						// marked, ignore reference
 
 	orl		$ ENSN_COLOUR_ALREADY_VISITED_MASK,SN_COLOUR(descP)	// mark entry node as copied
	
	movl	heapP,temp										// set EN-node offset
	subl	old_heap_pointer,temp

	movl	temp,EN_BLOCK_OFFSET(descP)

	movl	nodeP,EN_NODE(descP)							// also done in gts_delete (next pass)

	jmp		ML(copy_non_shared_node)
# undef temp
#endif

	cmpl	nodeP,mark_en_current_en_node
	je		ML(copy_non_shared_node)

#define temp %ecx
	movl	SN_COLOUR(descP),temp			// get colour of node

	testl	$ ENSN_COLOUR_SET_EN_BIT,temp
	jz		ML(copy_non_shared_node)

	movl	EN_NODE_INDEX(descP),temp		// at least the second reference
		
	// encode external reference
	subl	$1,free
	js		undo_handler
	orl		$3,temp
	movl	temp,(heapP)
	addl	$4,heapP

	jmp		ENTRY_LABEL
#undef temp

ML(copy_non_shared_node):
	// copy descriptor and make indirection
	subl 	$1,free							// free < 1
	js		undo_handler

	leal 	1(heapP),%ecx					// indirection (%ecx) = heapP (heapP) + 1
	movl 	%ecx,(nodeP)					// update descriptor entry of node *in graph*

	movl 	descP,(heapP)					// descP (descP) at location heapP *in string being encoded*
	addl 	$4,heapP						// reserve space for descP

	// also for arrays
	movl	SN_DESCP(descP),descP

	testl 	$2,descP						// test if in hnf (bit#1)?
	je		ML(copy_closure)				// no, copy closure

	// node in hnf
	movzwl	-2(descP),arity					// get arity (%cx) of descriptor	
	testl	arity,arity
	jne		ML(copy_argument_pointers)		// if not zero, the copy argument pointer

	cmpl	$INT+2,descP
	je		ML(copy_integer)
	cmpl	$CHAR+2,descP
	je		ML(copy_integer)
	cmpl	$BOOL+2,descP
	je		ML(copy_integer)
	cmpl 	$REAL+2,descP
	je 		ML(copy_real)
	cmpl 	$__STRING__+2,descP
	je		ML(copy_string)
	cmpl 	$__ARRAY__+2,descP
	je 		ML(copy_array)

	jmp		ENTRY_LABEL

#define temp	%eax
ML(copy_indirection):
	// An indirection means that a certain node is referenced at least twice. All second
	// or later references to a particular node end up here.
	//	descP - 1		: pointer to an already encoded shared node in the string
	//					  being built.
	//  heapP			: pointer in the being built string which will contain the
	//					  offset back to the node.
	decl	descP
	
	// descP -1			: contains a shared node pointer
	incl	n_references_to_entry_nodes
	
#define sh_entry temp
	movl	descP,sh_entry
	movl	(sh_entry),sh_entry				// pointer to shared entry
	
#define node_colour %ecx
	movl	SN_COLOUR(sh_entry),node_colour	// get node colour

	// REF NAAR CURRENT EN-NODE MOET ALS INTERNE INDIRECTIE GECODEERD WORDEN
	pushl	node_colour
	andl	$ ENSN_COLOUR_GET_COLOUR,node_colour
	cmpl	current_colour,node_colour		// current_colour <> node_colour i.e. external reference
	je		ML(copy_internal_indirection)
	popl	node_colour

	testl	$ ENSN_COLOUR_SET_EN_BIT,node_colour
	jnz		ML(copy_external_indirection)

//2 ...
ML(copy_internal_indirection):
//2 ...
	subl 	$1,free							// free < 1
	js		undo_handler

	// internal references or indirections are difficult because the encoding
	// of a certain component may not occupy succesive space. This should be
	// compensated. Either by some additional administration or by implementing
	// the construction of the entry node tree	
	movl	heapP,temp
	subl	descP,temp						// offset = heapP - descP
	shll	$2,temp 
	orl		$1,temp							// internal indirection

	movl 	temp,(heapP)
	addl 	$4,heapP
	jmp 	ENTRY_LABEL
#undef temp

ML(copy_external_indirection):
	movl	%ebx,ML(old_heapP)					// backup old heap position
		
	movl	SN_COLOUR(%eax),%ebx
	testl	$ ENSN_COLOUR_SET_EN_BIT,%ebx
	jz		ML(copy_indirection_unmarked)

	// An entry node
	movl	EN_NODE_INDEX(%eax),%ebx
	
	subl	$1,free
	js		undo_handler
	orl		$3,%ebx
	movl	%ebx,(heapP)
	addl	$4,heapP
	
	jmp		ENTRY_LABEL
	
ML(copy_indirection_unmarked):
	// at old_heapP is the SN-pointer to be replaced.
	pushl	%eax
	movl	ML(old_heapP),%eax
	popl	%eax
	
	// an unmarked entry node i.e. a sn-node has been discovered. Notice that %ecx
	// contains the node colour.	
	// create external reference (similar to earlier case)
#define temp %ecx
	ML(_build_external_reference)
	
	movl	temp,ML(external_ref)					// reference backup
	
	// store encoded external reference (identical to earlier case)
	subl	$1,free
	js		undo_handler
	orl		$3,temp
	movl	temp,(heapP)
	addl	$4,heapP
#undef temp

	movl	%eax,descP								// SN-pointer

	ML(_create_entry_node)							// replace and initialise EN-pointer in node
	
	// EN_BLOCK_OFFSET berekenen	
#define temp %eax
	movl	ML(old_heapP),temp
	
	movl	%ecx,(temp)								// replace SN-node by equivalent EN-node

	subl	old_heap_pointer,temp
	
	movl	temp,EN_BLOCK_OFFSET(%ecx)
#undef temp
	jmp		ENTRY_LABEL

#define temp %ebx
ML(copy_argument_pointers):
	cmpl 	$1,arity
	je		ML(push_first_argument_pointer)
	cmpl 	$2,arity
	je		ML(push_second_and_first)
	cmpl 	$256,arity
	jae 	ML(copy_record)

	// 2 < arity < 256
	// (nodeP)		descP
	// 4(nodeP)		ptr to first arg
	// 8(nodeP)		ptr to arg block
	movl	8(nodeP),source	
	decl	arity

	COPY_STACK_BLOCK temp

	jmp 	ML(push_first_argument_pointer)
#undef	temp

#define	temp	%ebx
ML(push_second_and_first):
	movl	8(nodeP),temp
	PUSHL2	temp
#undef temp

ML(push_first_argument_pointer):
	movl	4(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP
				
	// INT
	// (nodeP)		descP to INT
	// 4(nodeP)		integer value
#define temp	%ecx
ML(copy_integer):
	subl 	$1,free							// free < 1
	js		undo_handler
			
	movl 	4(nodeP),temp
	movl 	temp,(heapP)
	
	addl 	$4,heapP
	jmp 	ENTRY_LABEL
#undef temp

	// REAL
	// (nodeP)		descP to REAL
	// 4(nodeP)		least significant part of real
	// 8(nodeP)		most significant part of real
	// encoding processor specific
#define temp	%ecx
ML(copy_real):
	subl 	$2,free							// free < 2			
	js		undo_handler

	movl 	4(nodeP),temp
	movl 	temp,(heapP)
	movl 	8(nodeP),temp
	movl 	temp,4(heapP)
	
	addl 	$8,heapP
	jmp 	ENTRY_LABEL
#undef temp

	// CLOSURE
	// -8(descP)	descP
	// -4(descP)	arity of closure
	// descP		text ptr to code
#define temp	%ebx
ML(copy_closure):	
	movl	-4(descP),arity
	cmpl	$0,arity
	jl		ML(copy_closure1)
	je		ENTRY_LABEL
	
	cmpl 	$256,arity						// arity >= 256
	jae 	ML(copy_unboxed_closure)

	// build_lazy_block
	// ----------------
	cmpl	$ CLEAN_nbuild_lazy_block,descP
	jne 	ML(no22)

// store NodeIndex
	movl	BUILD_DYNAMIC_NODE__INDEX_PTR(nodeP),temp	// temp is an INT-node
	movl	4(temp),temp							// get node-index

	movl	temp,BUILD_LAZY_DYNAMIC_ON_DISK__NODE_INDEX(heapP)

	call	MAKE_ID_FDS(lb_alloc_entry)
		
	movl	8(nodeP),%ebx
	movl	4(%ebx),%ebx
		
	pushl	%ebx

	jmp		ML(convert_run_time_id)
ML(no22):

	// build_block
	// -----------
	cmpl	$ CLEAN_nbuild_block,descP
	jne 	ML(continue)

	subl 	$2,free							// free < 2			
	js		undo_handler
	
	// store NodeIndex
	movl	BUILD_DYNAMIC_NODE__INDEX_PTR(nodeP),temp	// temp is an INT-node
	movl	4(temp),temp							// get node-index
	movl	temp,BUILD_LAZY_DYNAMIC_ON_DISK__NODE_INDEX(heapP)
	
	// store Dynamic
	// sharing equal pointer is not done.
#ifdef DYNAMIC_STRINGS
	movl	BUILD_DYNAMIC_GDID__PTR(nodeP),temp
	testl	$2,(temp)
	jnz		ML(no_closure)
	
	movl	4(temp),temp								// argument of closure is GlobalDynamicInfo
ML(no_closure):
	pushl	temp
	movl	4(temp),temp
	
	cmpl	$__STRING__+2,(temp)
	je 		ML(a_string)
	// not a string. how to get the dynamic string?
	
	popl	temp

ML(a_string):
	call	MAKE_ID_FDS(lb_alloc_entry)

	// get run-time id
	popl	temp
	 	
	movl	8(temp),temp			// arg block ptr

# ifdef SHARING_ACROSS_CONVERSIONS
	pushl	temp
# endif

	movl	GDI_ID(temp),temp		// get ID

	pushl	temp					// backup dynamic ID

ML(convert_run_time_id):
	movl	$ INVALID_DYNAMIC_ID,LDR_ID(%ecx)	
	pushl	%ecx
	
	call	convert_dynamic_id_into_build_lazy_block_id
	
	popl	%ecx
	
	movl	%ebx,LDR_LAZY_DYNAMIC_INDEX(%ecx)
	movl	%ebx,BUILD_LAZY_DYNAMIC_ON_DISK__DYNAMIC_ID(heapP)
		
	popl	temp					// restore dynamic ID
	movl	temp,LDR_ID(%ecx)		// field will be put in ldr_id	
#endif // DYNAMIC_STRINGS	
	
	addl	$ BUILD_LAZY_DYNAMIC_ON_DISK__BSIZE,heapP

#ifdef SHARING_ACROSS_CONVERSIONS
	popl	nodeP
	movl	GDI_GRAPH_POINTERS(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP		
#else
	jmp		ENTRY_LABEL	
#endif

ML(continue):
	leal	4(nodeP),source
	COPY_STACK_BLOCK temp
	
	jmp 	ENTRY_LABEL
	
ML(copy_closure1):
	movl	4(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP
#undef temp		

	// UNBOXED CLOSURE
	// (descP)		high byte, number of unboxed args
	// 				low_bytes, number of args
	// arity < 2:
	// 4(nodeP)		1st arg
	// 8(nodeP)		2nd arg if any
	//
	// arity > 2:
	// 4(nodeP)		1st arg
	// 8(nodeP)		ptr to arg block
	//
	// Boxed args block if any precede unboxed args block
#define nrUnboxed	nodeP
#define nrUnboxedL	%al
#define nrPointers	arity
#define nrPointersH	%ch
#define temp		%ebx

ML(copy_unboxed_closure):
	leal	4(nodeP),source					// set source

	xorl 	nrUnboxed,nrUnboxed
	movb	nrPointersH,nrUnboxedL
	andl	$255,arity
	sub		nrUnboxed,arity					// arity = # boxed arguments

	COPY_STACK_BLOCK temp
	
	movl	nrUnboxed,arity					// arity = # unboxed arguments
	
	COPY_HEAP_BLOCK

	jmp		ENTRY_LABEL
#undef nrUnboxed
#undef nrUnboxedL
#undef nrPointers
#undef nrPointersH
#undef temp

	// RECORD
	// -2(descP)	arity
	// (descP)		# boxed args (ptrs)
ML(copy_record):
	// temporary register assignments
#define nrPointers	%esi
	movzwl 	(descP),nrPointers				// nrPointers (boxed arguments)
	subl 	$256,arity						// arity -= 256 (real arity)
		
#define nrUnboxed		%ebx
	movl 	arity,nrUnboxed
	subl 	nrPointers,nrUnboxed			// nrUnboxed = arity - nrPointers
	
	cmpl 	$0,arity
	je		ENTRY_LABEL						// arity == 0
	cmpl 	$1,arity
	je		ML(record_with_one_cell)		// arity == 1
	cmpl	$2,arity
	je		ML(record_with_two_cells)		// arity == 2

	pushl	nrPointers
		
	// arity contains total arity
	cmpl	$0,nrPointers					// nrPointers == 0
	je		ML(only_unboxed_args)
	
	decl	nrPointers						// 4(nodeP) is a boxed	 
	jmp		ML(copy_args)					// argument
ML(only_unboxed_args):
	decl	nrUnboxed						// only unboxed, decrement
											// count			
ML(copy_args):
	movl	nrPointers,arity				// #boxed arguments in 8(nodeP)
	movl	8(nodeP),source					// set source						

	testl	%ecx,%ecx
	je  	ML(copy_unboxed_args)

	pushl	nrUnboxed
	
#define temp %ebx
	COPY_STACK_BLOCK temp
#undef temp
	popl	nrUnboxed

ML(copy_unboxed_args):
	movl	nrUnboxed,arity					// #unboxed arguments in 8(nodeP)
	testl	%ecx,%ecx
	je  	ML(copy_first_arg)
	
	COPY_HEAP_BLOCK

ML(copy_first_arg):
	popl 	nrPointers
	jmp		ML(record_with_one_cell)
#undef nrUnboxed	

	// RECORD with two elements
ML(record_with_two_cells):
	cmpl 	$1,nrPointers					
	ja		ML(second_is_pointer)			// nrPointers > 1
	
	// copy unboxed args
	subl	$1,free							// free < 1
	js		undo_handler

#define temp	%ebx		
	movl 	8(nodeP),temp
	movl 	temp,(heapP)
	
	addl 	$4,heapP
	jmp 	ML(record_with_one_cell)
	
	// two boxed args
ML(second_is_pointer):
	movl 	8(nodeP),temp
	PUSHL2 temp
#undef temp
	
ML(record_with_one_cell):
	cmpl 	$0,nrPointers				
	jne		ML(first_arg_is_pointer)
		
	// one unboxed arg
	subl 	$1,free							// free < 1
	js		undo_handler	

#define temp	%ebx	
	movl 	4(nodeP),temp
	movl 	temp,(heapP)
#undef temp
	
	addl 	$4,heapP
	jmp 	ENTRY_LABEL
	
ML(first_arg_is_pointer):
	movl 	4(nodeP),nodeP
	jmp 	ENTRY_LABEL_NODEP
#undef nrPointers

	// STRING
	// (nodeP)		descP to STRING
	// 4(nodeP)		length
	// 8(nodeP)		string
#define temp	%ebx
#define length	arity
ML(copy_string):
	movl 	4(nodeP),length
	
	test 	length,length
	je 		ML(string_length_zero)
	
	addl 	$7,length						// length = 4 + 4(nodeP) + 3
	shrl 	$2,length						// length in longs	
	
	leal	4(nodeP),source					// set source
	
	COPY_HEAP_BLOCK

	jmp 	ENTRY_LABEL
	
ML(string_length_zero):
	subl	$1,free			
	js		undo_handler
	
	movl	length,(heapP)
	addl	$4,heapP
	
	jmp 	ENTRY_LABEL
#undef temp
#undef length

	// ARRAY
	// (nodeP)		descP to ARRAY
	// 4(nodeP)		size
	// 8(nodeP)		0, boxed array
	//				otherwise, element descP
	// 12(nodeP)	element block
ML(copy_array):
#define size	arity
	subl	$2,free				
	js		undo_handler
	
	movl	8(nodeP),descP	
	movl 	descP,4(heapP)						// store descriptor in string

	cmpl	$1,descP							// indirection or boxed array? descP <= 1
	jbe		ML(copy_array2)				

	// indirection; no boxed or already existing indirection	
#define temp arity
	leal	5(heapP),temp
	movl	temp,8(nodeP)
#undef	temp

ML(copy_array2):
	movl	4(nodeP),size

	movl	size,(heapP)
	addl	$8,heapP

	cmpl	$0,size								
	je		ENTRY_LABEL							// array size == 0

	leal	12(nodeP),source					// set source
	
	cmpl	$0,descP	
	je		ML(copy_array_pointers)				// copy boxed array elements
	cmpl 	$INT+2,descP
	je		ML(copy_int_array)					// copy unboxed array of integers/chars
	cmpl	$BOOL+2,descP
	je		ML(copy_bool_array)					// copy unboxed array of booleans
	cmpl	$REAL+2,descP				
	je		ML(copy_real_array)					// copy unboxed array of reals
	
	jmp 	ML(copy_record_array)				// copy array with records elements
			
#define temp	%ebx
ML(copy_array_pointers):
	COPY_STACK_BLOCK temp 

	jmp		ENTRY_LABEL
#undef temp

ML(copy_int_array):
	COPY_HEAP_BLOCK								// copy size, elem. descriptor and elements

	jmp 	ENTRY_LABEL
	
ML(copy_bool_array):
	addl 	$3,size								// size = size + 3					
	shrl  	$2,size								// size /= 4 (in longs)
	jmp		ML(copy_int_array)
	
ML(copy_real_array):
	shll	$1,size								// size *= 2	
	jmp		ML(copy_int_array)
		
	// RECORD ARRAY
	// (nodeP)		descP to ARRAY
	// 4(nodeP)		size
	// 8(nodeP)		record element descP
	// 12(nodeP)	record elements block
	// 
	// -2(descP)	#longs which is the recordsize
	// (descP)		#a-fields in record (word,0)
	//
 	// Purpose:
 	// Copies an array containing records with at least one unboxed field. Other
 	// records are handled by copy_record. If the record element type are unboxed
 	// the copy_unboxed_record_array is called.
	.data
	.align 4
ML(t_stackP):	
	.long 0	
ML(unboxed_fields_size):
	.long 0
	
	// copy indirection
ML(old_heapP):
	.long	0

 	.text
ML(copy_record_array):
	// compute boxed size part of the array and reserve stack memory
	movl	stackP,ML(t_stackP)				// backup stackP
			
#define	temp		nodeP
#define t_nodeP		arity
#define temp2		source					// was: %esi 
	movl	nodeP,t_nodeP
	
	movzwl	(descP),temp					// #boxed fields per records
	cmpl	$0,temp							// any boxed arguments?
	je		ML(copy_unboxed_record_array)	// ok, copy only boxed
	
	mull	4(t_nodeP)						// temp = size of boxed part of array (in longs) 
	xchg	nodeP,arity
	
	movl	ML(t_stackP),stackP				// restore stackP	

	nop
	RESERVE_STACK_BLOCK temp2

#undef	temp
#undef 	t_nodeP
#undef	temp2

	// compute unboxed size part of the array and reserve heap memory
	movl	stackP,ML(t_stackP)				// backup stackP
	
#define	temp	nodeP
#define temp2	stackP
#define t_nodeP	arity

	movl	nodeP,t_nodeP
		
	movzwl	(descP),temp2
	movzwl	-2(descP),temp					// total record size in bytes
	subl	$256,temp		
	subl	temp2,temp						// temp = total record size - nrFieldPointers
	movl	temp,ML(unboxed_fields_size)
	mull	4(t_nodeP)
	
	subl	%eax,free						// free < unboxed record size
	js		undo_handler
	
	movl	t_nodeP,nodeP
#undef temp
#undef temp2

	movl 	ML(t_stackP),stackP				// restore stackP
	
	// assumption: amount of boxed and unboxed args is at least one
#define nrBoxedFields	%ebx
	movzwl	(descP),nrBoxedFields			// #boxed fields
	
	pushl	free							// backup free
#define nrUnboxedFields	free
	movl	ML(unboxed_fields_size),nrUnboxedFields		// #unboxed fields

	leal	12(nodeP),source				// set source
	cld
	
#define count	nodeP
	movl	4(nodeP),count
	
	pushl	stackP							// backup tos
	
ML(copy_boxed_fields):
	xchg	heapP,stackP					// exchange heapP and stackP

	movl	nrBoxedFields,arity				// amount of boxed fields to copy

	cld
	rep
	movsl
	
	xchg 	heapP,stackP					// exchange

ML(copy_unboxed_fields):
	movl	nrUnboxedFields,arity			// amount of unboxed fields to copy
	
	cld
	rep
	movsl
	
ML(copied_one_array_record):
	decl	count
	jne		ML(copy_boxed_fields)
	
	popl	stackP
	popl	free
	
	jmp 	ENTRY_LABEL

ML(copy_unboxed_record_array):
	leal	12(t_nodeP),source					// set source
	
#define	s_unboxed_record_array	%eax
	movzwl	-2(descP),s_unboxed_record_array	// total record size (in longs)
	subl	$256,s_unboxed_record_array
	mull	4(t_nodeP)							// get array size
	movl	ML(t_stackP),stackP					// restore stackP
					
	movl	s_unboxed_record_array,arity		// set arity
#undef s_unboxed_record_array
	
	COPY_HEAP_BLOCK
	
	jmp		ENTRY_LABEL
#undef record_size
#undef nrPointers
#undef t_nodeP	

#ifndef GTS_COPY_DEFINE_ONLY_ONCE
# define	GTS_COPY_DEFINE_ONLY_ONCE
	.data
	.align	4
// order r t c k d n

//	To compute the proper offset from the virtual base offset, it is necessary
//	to known what prefixes preceded the desired prefix e.g. suppose the offset
//	for k-prefix is desired,

n_possible_prefixes_before_prefix:
	.byte	32+16+8+4+2		// n-prefix; 00|111110
	.byte	32+16+8+4		// d-prefix; 00|111100
	.byte	32+16+8			// k_prefix; 00|111000
	.byte	32+16			// c_prefix; 00|110000
	.byte	32				// t_prefix; 00|100000 
	.byte	0				// r_prefix; 00|000000
n_references_to_entry_nodes:
	.long	0						// kan weg
#endif 	
	.text
	.align	4
	
#undef ML

#undef ENTRY_LABEL
#undef ENTRY_LABEL_NODEP
#undef COPY_STACK_BLOCK
#undef RESERVE_STACK_BLOCK
#undef PUSHL2
#undef COPY_HEAP_BLOCK
#ifdef UNFIXED_STACK
# undef UNFIXED_STACK
#endif
