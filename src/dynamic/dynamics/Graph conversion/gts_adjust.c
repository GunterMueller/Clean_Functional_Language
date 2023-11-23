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

	/*
	// pre-conditions: 
	// - t1 contains to the encoded descP e.g. movl (stringP),t1
	// - stringP points to the encoded descriptor
	// - t1 is not an indirection
	//
	// post condition:
	// - (stringP) is changed
	// - stringP is advanced with 4
	//
	// identical code in:
	// adjust_offset_per_block
	*/ 
	.macro ML(_adapt_encoded_graph) t12
#define stringP	source

#define t0	descP	// %ebx
#define t2	nodeP	// %eax
		pushl	t2
		movl	t0,tijdelijk
		
		movl	\t12,t2
	
		andl	$0x00ffffff,\t12
		movl	stackTop,t0
		subl	\t12,t0						// t0 = stackTop - offset
		
		movl	4(t0),\t12					// t12 = virtual base offset
		
		cmpl	$0,\t12
		jnz		9f							// \virtual_base_offset_already_computed
	
		// The virtual base offset should already have been computed but it isn't if control
		// reaches this point. How come?
		int3
		
		popl	%eax	
		movl	tijdelijk,%ebx	

		movl	virtual_base_offset,\t12	// compute virtual base offset
		movl	\t12,4(t0)
		
		// determine bitset size
		movl	(t0),t2
	
		// MAKE OFFSET DESCRIPTOR TABLE ..
		subl	$1,free
		js		undo_handler			// gap between the string table and the intermediate data structure

		movl	t2,(heapP)
		leal	4(heapP),heapP
		// .. MAKE OFFSET DESCRIPTOR TABLE 
	
		andl	$0xff000000,t2
		shrl	$24,t2
		
		addl	$n_bits,t2
		movzbl	(t2),t2						// t2 = #bitset
	
		leal	(\t12,t2,4),t2
		movl	t2,virtual_base_offset		// advance virtual base offset with #bitset * 4
		
		movl	(stringP),t2
		
	9:	// virtual base offset has already been computed
		andl	$0xff000000,t2
		shrl	$29,t2						// t2 = prefix kind of encoded node
		
		addl	$n_possible_prefixes_before_prefix,t2
		movzbl	(t2),t2						// t2 = set of prefixes which *can* occur before the desired prefix
		
		movl	(t0),t0
		andl	$0xff000000,t0
		shrl	$24,t0						// t0 = set of needed prefixes
	
		andl	t2,t0						// t0 = set of needed prefixes which *occur* before the desired prefix
	
		addl	$n_bits,t0
		movzbl	(t0),t0						// t0 = #needed prefixes which *occur* before the desired prefix
		
		leal	(\t12,t0,4),t0				// t0 = virtual_base_offset + (#needed prefixes * 4)
		andl	$0x00ffffff,t0				
		
		movl	(stringP),\t12
		andl	$0xff000000,\t12			// get prefix kind and arity
		orl		t0,\t12
		movl	\t12,(stringP)				// update encoded graph with just computed virtual offset for the prefix kind
		
		popl	t2
#undef t0
#undef t2
				
		/*
		// precondition: stringP always points at a descP in the encoded graph
		//
		// Adapt the lower 24 bits to hold the virtual offset in the descriptor address table. The descriptor address
		// table is generated by the linker at run-time. The order is important. Only the first four bytes of the 
		// intermediate structure are stored.
		//
		*/
		leal	4(stringP),stringP			// descriptor has been modified to point to the proper prefix
	// .. ADAPT ENCODED GRAPH
	.endm

#define temp arity
	ML(_adapt_encoded_graph) temp
#undef temp

	popl	descP

// mutally exclusive options
#include "gts_shared_macros.c"
	
// Code:
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
	pushl	stringP							// backup stringP

	movl	8(nodeP),source	
	decl	arity

	COPY_STACK_BLOCK temp

	popl	stringP							// restore stringP
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
	leal	4(stringP),stringP
	jmp 	ENTRY_LABEL
#undef temp

	// REAL
	// (nodeP)		descP to REAL
	// 4(nodeP)		least significant part of real
	// 8(nodeP)		most significant part of real
	// encoding processor specific
#define temp	%ecx
ML(copy_real):
	leal	8(stringP),stringP
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

	cmpl	$ CLEAN_nbuild_lazy_block,descP
	je		ML(build_lazy_block)

	cmpl	$ CLEAN_nbuild_block,descP
	jne		ML(continue2)

ML(build_lazy_block):
	addl	$8,stringP
	
#ifdef SHARING_ACROSS_CONVERSIONS
	movl	BUILD_DYNAMIC_GDID__PTR(nodeP),nodeP
	testl	$2,(nodeP)
	jnz		ML(no_closure)
	
	movl	4(nodeP),nodeP								// argument of closure is GlobalDynamicInfo
ML(no_closure):	
	
	movl	8(nodeP),nodeP
	movl	GDI_GRAPH_POINTERS(nodeP),nodeP
	
	jmp		ENTRY_LABEL_NODEP		
#endif

	jmp		ENTRY_LABEL
ML(continue2):
	pushl	stringP							// backup stringP

	leal	4(nodeP),source
	COPY_STACK_BLOCK temp

	popl	stringP							// restore stringP	
	jmp 	ENTRY_LABEL
	
ML(copy_closure1):
	movl	4(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP
# undef temp		

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
	pushl	stringP							// backup stringP

	leal	4(nodeP),source					// set source

	xorl 	nrUnboxed,nrUnboxed
	movb	nrPointersH,nrUnboxedL
	andl	$255,arity
	sub		nrUnboxed,arity					// arity = # boxed arguments

	COPY_STACK_BLOCK temp

	popl	stringP							// restore stringP
	leal	(stringP,nrUnboxed,4),stringP	// increase it with number of unboxed arguments
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
#define nrPointers	descP
	movzwl 	(descP),nrPointers				// nrPointers (boxed arguments)
	subl 	$256,arity						// arity -= 256 (real arity)
	
	cmpl 	$0,arity
	je		ENTRY_LABEL						// arity == 0
	cmpl 	$1,arity
	je		ML(record_with_one_cell)		// arity == 1
	cmpl	$2,arity
	je		ML(record_with_two_cells)		// arity == 2
	
#define nrUnboxed		arity
	subl	nrPointers,nrUnboxed

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
	xchgl	nrPointers,nrUnboxed			// %ecx = nrPointers
	cmpl	$0,%ecx
	je		ML(copy_first_arg)

	pushl	source							// backup stringP

	movl	8(nodeP),source					// set source
#define temp descP
	pushl	temp
	COPY_STACK_BLOCK temp
	popl	temp
#undef temp 

	popl	source							// restore stringP
				
ML(copy_first_arg):
	leal	(stringP,%ebx,4),stringP
	popl 	nrPointers
	jmp		ML(record_with_one_cell)
#undef nrUnboxed	

	// RECORD with two elements
ML(record_with_two_cells):
	cmpl 	$1,nrPointers					
	ja		ML(second_is_pointer)			// nrPointers > 1

	leal	4(stringP),stringP
	jmp 	ML(record_with_one_cell)
	
	// two boxed args
ML(second_is_pointer):
#define temp arity
	movl 	8(nodeP),temp
	PUSHL2 temp
#undef temp
	
ML(record_with_one_cell):
	cmpl 	$0,nrPointers				
	jne		ML(first_arg_is_pointer)
		
	// one unboxed arg
	leal	4(stringP),stringP
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
	
	addl 	$7,length						// length = 4 + 4(nodeP) + 3
	shrl 	$2,length						// length in longs	

	leal	(stringP,length,4),stringP
	jmp 	ENTRY_LABEL

	// ARRAY
	// (nodeP)		descP to ARRAY
	// 4(nodeP)		size
	// 8(nodeP)		0, boxed array
	//				otherwise, element descP
	// 12(nodeP)	element block
ML(copy_array):
	movl	8(nodeP),descP						// get element descP
	
#define t1 arity
	cmpl	$0,descP
	je		ML(share_prefixes_in_array2)
	
	leal	4(stringP),stringP					// advance stringP
	movl	(stringP),t1
	ML(_adapt_encoded_graph) t1
#undef t1

	movl	8(nodeP),descP						// restore element descP

	jmp		ML(copy_array2)
ML(share_prefixes_in_array2):
	leal	8(stringP),stringP					// advance stringP
#define size arity

ML(copy_array2):
	movl	4(nodeP),size

	cmpl	$0,size								
	je		ENTRY_LABEL							// array size == 0
	
	cmpl	$0,descP	
	je		ML(copy_array_pointers)				// copy boxed array elements
	cmpl 	$INT+2,descP
	je		ML(copy_int_array)					// copy unboxed array of integers/chars
	cmpl	$BOOL+2,descP
	je		ML(copy_bool_array)					// copy unboxed array of booleans
	cmpl	$CHAR+2,descP
	je 		ML(copy_bool_array)
	cmpl	$REAL+2,descP				
	je		ML(copy_real_array)					// copy unboxed array of reals
	
	jmp 	ML(copy_record_array)				// copy array with records elements
			
#define temp	%ebx
ML(copy_array_pointers):
	pushl	stringP
	leal	12(nodeP),source

	COPY_STACK_BLOCK temp 

	popl	stringP
	jmp		ENTRY_LABEL
#undef temp

ML(copy_int_array):
	leal	(stringP,size,4),stringP
	jmp 	ENTRY_LABEL
	
ML(copy_bool_array):
	addl 	$3,size								// size = size + 3					
	shrl  	$2,size								// size /= 4 (in longs)

	leal	(stringP,size,4),stringP
	jmp		ENTRY_LABEL
	
ML(copy_real_array):
	leal	(stringP,size,8),stringP
	jmp		ENTRY_LABEL
		
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
	pushl	stringP							// backup stringP

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

	pushl	stringP

	nop
	RESERVE_STACK_BLOCK temp2

	popl	stringP

#undef	temp
#undef 	t_nodeP
#undef	temp2

	// Copy the boxed part of the record array to stack
	leal	12(nodeP),source				// set source
	
	pushl	free
#define nrPointers free					
	movzwl	(descP),nrPointers				// boxed size of record
	
#define s_unboxed_arguments descP
	movzwl	-2(descP),s_unboxed_arguments			// total record size
	subl	$256,s_unboxed_arguments
	subl	nrPointers,s_unboxed_arguments			// s_unboxed_arguments = size of unboxed fields	
	shll	$2,s_unboxed_arguments				// s_unboxed_arguments *= 4 (in bytes)
	
#define count	nodeP
	movl	4(nodeP),count					// get array size
	
	pushl	heapP
	movl	stackP,heapP					// set destination to stack start
	
	pushl	count
ML(share_prefixes_in_record_array2):
	movl	nrPointers,arity				// set arity to # boxed fields
	
	cld
	rep
	movsl
	
	addl	s_unboxed_arguments,source
	decl	count
	jne		ML(share_prefixes_in_record_array2)
	
	popl	count
	
	popl	heapP
	popl	free
	
	// %ebx = unboxed record size 		(s_unboxed_arguments)
	// %eax = #array elements			(count)	
	pushl	%edx
	mull	%ebx
	popl	%edx
	
	popl	stringP
	leal	(stringP,%eax),stringP
	
	jmp		ENTRY_LABEL 					//share_next_prefix
#undef nrPointers
#undef s_unboxed_arguments
#undef count

ML(copy_unboxed_record_array):
	popl	stringP
	
#define temp %edx
	pushl	temp
	movl	4(arity),temp
	
#define s_unboxed_arguments nodeP
	movzwl	-2(descP),s_unboxed_arguments		// total record size
	subl	$256,s_unboxed_arguments
	shll	$2,s_unboxed_arguments				// s_unboxed_arguments *= 4 (in bytes)
	mull	temp

	popl	temp
	
	leal	(stringP,%eax),stringP
	jmp		ENTRY_LABEL
#undef s_unboxed_arguments
#undef temp

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
#ifdef UNFIXED_STACK
# undef UNFIXED_STACK
#endif