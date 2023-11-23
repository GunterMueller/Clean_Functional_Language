// PASS: DELETE INDIRECTIONS
//
// Interface:
//
// #define ML(x)				x##id e.g. _1
// #define ENTRY_LABEL			delete_next_indirection##id
// #define ENTRY_LABEL_NODEP	delete_next_indirection_in_nodeP##id
// #define EXIT_LABEL			deletion_done (only needed in full deletion pass)
// #include "gts_delete.c"
// #undef EXIT_LABEL
//
// Note:
// - In case COPY_NAMES_PASS is defined only names are allocated from the heap. No other
//   allocations are done. There is no need to install an undo handler because it is
//	 not called.
//   If at the end the amount of free words (4 bytes) is negative, then there was not
//   enough space to copy all label/module names.

#ifdef COPY_NAMES_PASS 
# ifdef COLOUR_PASS
#  error "COPY_NAMES_PASS and COLOUR_PASS cannot be used together"
# endif
# ifdef DETERMINE_ENTRY_NODES_PASS
#  error "COPY_NAMES_PASS and DETERMINE_ENTRY_NODES_PASS cannot be used together"
# endif
#endif

#ifdef UNFIXED_STACK
# define PUSHL2					_pushl_gc
# define RESERVE_STACK_BLOCK	_reserve_stack_block_gc
# define COPY_STACK_BLOCK		_copy_stack_block_gc
#else
# define PUSHL2					_pushl_no_gc
# define RESERVE_STACK_BLOCK	_reserve_stack_block_no_gc
# define COPY_STACK_BLOCK		_copy_stack_block_no_gc
#endif

#define DESCRIPTOR_PREFIX_ENTRY_WSIZE	3
#define DESCRIPTOR_PREFIX_ENTRY_BSIZE 	(DESCRIPTOR_PREFIX_ENTRY_WSIZE * MACHINE_WORD_BSIZE)

#define DPT_PREFIX_SET_AND_STRING_PTR	0
#define DPT_VIRTUAL_BASE				4
#define DPT_DESCP_USAGE_SET_PTR		8

// Macros:	
#ifdef COPY_NAMES_PASS
# define t_indirection stackP
	.macro	_start_copying_names indirection
		pushl	stackP						// backup stackP	
		pushl	nodeP						// backup nodeP
		movl	\indirection,t_indirection
	.endm
	
# define nameP source

# define size arity
	.macro	_copy_name
		// precondition:
		// - prefix kind
		//   contains the prefix and in case of a d-prefix its arity in most significant
		//   byte
		// - nameP_backup
		//	 contains a pointer to the module name
		// - nameP 
		//	 contains a pointer to the function name
		// - t_indirection (and also indirection)
		//	 is current position in encoded graph (string)
		incl	n_nodes

		movl	(nameP),size					// get size
	
		testl	size,size						// function_name_size < 0
		jns		0f								// \copy_function_name				// yes, copy function_name

# define	name_p size
		shll	$1,name_p						// unmark, address of descriptor table entry		

		//	t_indirection	= string table address of reference to a function name
		//	nameP			= string table address of 1st occurence of function name	

# define t1 %eax
# define t2 name_p
		pushl	t2
		_prefix_kind_to_set t1,t2				// convert into singleton set of prefix
		popl	t2
# undef t2
		orl		t1,(name_p)
# undef t1

		// descStackBottom >= name_p; compute %eax = offset of descriptor address entry
		movl	stackTop,%eax
		subl	name_p,%eax						// %eax = %eax - name_p

		orl		prefix_kind,%eax				// add the prefix kind to the descriptor table entry set
		movl	%eax,(t_indirection)			// make reference from encoded graph (string) 
												// to the descriptor address table entry.
			
		jmp		3f								// \end_copying_names

0:
		// Unmarked function name. Copy it and mark it.		
		addl	$7,size		
		shrl	$2,size							// round string length up to a multiple of four
			
		subl	size,free
		js		1f								// skip name due too lack of memory and continue			
		
		subl	$ DESCRIPTOR_PREFIX_ENTRY_WSIZE,free
		js		1f
		
# define temp nodeP
		movl	descStackTop,temp				// temp = descStackTop
		subl	$ DESCRIPTOR_PREFIX_ENTRY_BSIZE,temp
		movl	temp,descStackTop
		
		movl	temp,prefix_address_entry_ptr	
# undef temp

		cld
		movsl									// copy string length
	
# define temp nodeP
		movl	(nameP),temp					// temp = 1st four characters
		shll	$1,temp
		
# define temp2 descP
		pushl	temp2

		movl	(temp),temp2					// get 1st four characters
		movl	temp2,(heapP)					// put them directly in heap
		
		movl	temp,current_descP				// backup reference to current descriptor
# undef temp2

# undef temp

		// Replace descriptor reference in string by the offset to its function name. Simply
		// adding the offset to the heapP produces the address of the function name.
# define string_offset nodeP	
		leal	(heapP),string_offset			// string_offset = current heapP (which points just after the string length)
		subl	string_table_base,string_offset // string_offset (from string base table) = start_of_string - string_table_base
		
# define t0	%ebx
# define t1	%ecx
# define t2	stackP
		pushl	t1
		pushl	t2

		movl	prefix_address_entry_ptr,t0

		movl	string_offset,(t0)				// dpe (offset 0): lower 24 bits offset in stringtable
	
# define temp %eax
		// current_descP = pointer in descriptor usage table
		movl	current_descP,temp
		movl	temp,DPT_DESCP_USAGE_SET_PTR(t0)
		movl	t0,(temp)							// make descriptor usage entry point to preliminary descriptor address table
# undef temp
		movl	t0,%eax

		// store prefix_kind and descriptor address offset (in encoded graph)
		movl	stackTop,t1						// invariant: descStackBottom >= t0	
		
		subl	t0,t1							// t1 = descStackBottom - t0 i.e t1 >= 0 representing the offset to the dpe
		orl		prefix_kind,t1					// or it with current prefix_kind
		movl	t1,(t_indirection)				// modify the encoded graph to point to the dpe
		
		_prefix_kind_to_set t1,t2				// convert into singleton set of the prefix (in t1)

		orl		t1,(t0)							// add singleton set to most significant byte of dpe (offset 0)
		
		movl	$0,4(t0)						// dpe (offset 4) = 0

		popl 	t2
		popl	t1
		popl	t0
# undef t2
# undef t1
# undef t0

# undef string_offset	

		// Modify descriptor string:
		//
		// - function name length (at -4(nameP))
		//   replaced by a marked heap address which points the characters of the function name. 
		//   At that position in the string the name occurred first. The most significant bit is
		//   set to indicate the markedness.
		//   
		// - first long at (nameP)
		//   pointer to the string of the previous list element. The length is at offset -4 of
		//   this pointer. The list is terminated by 0.
		//   
		// Note:
		// Because a function (or module for that matter) name consists of at least one character
		// which is rounded up to one machine word which is just enough to store a pointer in it.
# define marked_heapP nodeP
		shrl	$1,marked_heapP					// mark heapP
		orl 	$0x80000000,marked_heapP
		movl	marked_heapP,-4(nameP)			// replace length by marked heapP
# undef marked_heapP

		addl	$4,heapP
		addl	$4,nameP

# define temp nodeP
		movl	function_name_list,temp

		movl	temp,-4(nameP)					// replace first characters by this address
	
		leal	-8(nameP),temp					// start of new name

		movl	temp,function_name_list
# undef temp

		subl	$2,size							// size -= 2
		
		rep										// copy rest of string
		movsl	
	1:	
		// copy module name
# define moduleP nameP
		// module name, nameP  contains the function_name
		movl	nameP_backup,moduleP			// restore nameP to module
	
		movl	(moduleP),size					// get size
	
		test	size,size
		jns		2f								//\copy_module_name				// unmarked
	
		// module_name is marked. It suffices to store a pointer to it
		subl	$1,free							// free < 1
		js		3f								//\end_copying_names
	
# define name_p size
		shll	$1,name_p						// unmark, address of module name
	
# define offset nodeP
		movl	name_p,offset
		subl	heapP,offset					// offset = name_p - heapP
	
		movl	offset,(heapP)
# undef offset
# undef name_p
		addl	$4,heapP
		jmp		3f								//\end_copying_names
	
2:
		addl	$7,size
		shrl	$2,size
	
		subl	size,free
		js		3f								//\end_copying_names

		cld
		movsl									// copy module name length
	
# define marked_heapP nodeP
		leal	(heapP),marked_heapP
		shrl 	$1,marked_heapP
		orl 	$0x80000000,marked_heapP
		movl	marked_heapP,-4(moduleP)
# undef marked_heapP

		movsl									// copy first 4 characters
	
# define temp nodeP
		movl	module_name_list,temp

		movl	temp,-4(moduleP)
	
		leal	-8(moduleP),temp
		movl	temp,module_name_list
# undef temp
	
		subl	$2,size							// size	-= 2
	
		rep 
		movsl	
# undef size
3:
		popl	nodeP						// restore nodeP
		popl 	stackP						// restore stackP
	.endm
	
	// precondition:
	// t1	= base (descriptor prefix entry) dpe offset
	// t2	= dummy
	//
	// postcondition:
	// t1 	= singleton set containing the prefix
	// t2	= dummy
	.macro _prefix_kind_to_set t1 t2
		movl	$prefix_to_set,\t2

		movl 	prefix_kind,\t1
		shrl	$29,\t1
		
		movl	(\t2,\t1,4),\t1
		shll	$24,\t1
	.endm	
#endif // COPY_NAMES_PASS

#include "gts_shared_macros.c"

#ifdef COPY_NAMES_PASS
ENTRY_LABEL:
	_try_popl nodeP EXIT_LABEL				// deletion_done
	
ENTRY_LABEL_NODEP:
# define indirection	%ecx
	movl 	(nodeP),indirection				// get indirection pointer
	
	testl 	$1,indirection					// test bit#0 for indirection
	je		ENTRY_LABEL						// continue with next indirection
	
	leal	-1(indirection),indirection		// indirection is current position in encoded graph (string)
	movl	(indirection),descP				// retrieve the descP for current graph node

	testl	$ ENSN_COLOUR_SET_EN_BIT,SN_COLOUR(descP)
	jz		0f
	
	andl	$ ENSN_COLOUR_GET_COLOUR,SN_COLOUR(descP)
	
	movl	nodeP,EN_NODE(descP)			// !!!!kan waarschijnlijk verhuizen naar de copy functie
0:
	movl	SN_DESCP(descP),descP			// descP point to a SN/EN-node

	movl	descP,(nodeP)					// restore descP in current graph node
				
	testl 	$2,descP						// test if in hnf (bit#1)?
	je		ML(resolve_closure_indirection)	// no, copy closure
	
ML(resolve_indirection):
	
	_start_copying_names indirection

	// INSERT PREFIX KIND AND ARITY ENCODING .. (should be a macro)	
	// precondition:
	// descP 	is a valid descriptor
	movzwl	-2(descP),arity					// descriptor (partial) arity
	cmpl	$256,arity	
	jb		ML(no_record_descriptor)
	
ML(record_descriptor):
	// test for {k,r}-prefix
# define temp nodeP
	movzbl	2(descP),temp					// first char of type string
	cmpl	$'d',temp
	jne		ML(rd_r_prefix)
	movl	$ K_PREFIX,prefix_kind			// k-prefix
	jmp		ML(rd_kr_flag_set)
ML(rd_r_prefix):
	movl	$ R_PREFIX,prefix_kind			// r-prefix
ML(rd_kr_flag_set):
# undef temp

# define temp nodeP
	movl	-10(descP),temp					// get module descriptor
	movl	temp,nameP_backup
# undef temp

	movl	-6(descP),nameP					// get ptr to function name

	jmp		ML(function_name_marked)
	
ML(no_record_descriptor):
# define	temp nodeP
	movzwl	(descP),temp					// temp = (partial) arity * 8
	lea		10(descP,temp),nameP
	shll	$24,arity

	testw 	$1,-8(nameP)					// test flag
	jnz		ML(no_rd_t_prefix)

	movl	$ D_PREFIX,prefix_kind			// d-prefix
	orl		arity,prefix_kind 				// inefficient
	jmp		ML(no_rd_dt_flag_set)
ML(no_rd_t_prefix):
	movl	$ T_PREFIX,prefix_kind			// t-prefix
ML(no_rd_dt_flag_set):

# define temp2 descP
	movl	-4(nameP),temp2			
	movl	temp2,nameP_backup				// nameP = ptr to module name
# undef temp2
# undef temp
	// post condition:
	// - prefix kind
	//   contains the prefix and in case of a d-prefix its arity in most significant
	//   byte
	// - nameP_backup
	//	 contains a pointer to the module name
	// - nameP 
	//	 contains a pointer to the function name
	// .. INSERT PREFIX KIND AND ARITY ENCODING (should be a macro)	

ML(function_name_marked):
	_copy_name

	movl	(nodeP),descP
#endif // COPY_NAMES_PASS

#ifdef DETERMINE_ENTRY_NODES_PASS
	// does not allocate memory
ENTRY_LABEL:
	_try_popl nodeP EXIT_LABEL

ENTRY_LABEL_NODEP:
	movl	(nodeP),descP
	andl	$0xfffffffe,descP				// remove indirection

# define node_colour arity
	movl	SN_COLOUR(descP),node_colour
//1	testl	$ ENSN_COLOUR_ALREADY_VISITED_MASK,node_colour				
//1	jnz		ENTRY_LABEL 					// node has already been visited but there might still be a colour change
	
	andl	$ ENSN_COLOUR_GET_COLOUR,node_colour
	cmpl	node_colour,current_colour
	je		ML(niet_af)

//#define MORE_ENTRY_NODES; verdere verfijning van het onderstaande.
# ifdef EXTRAATJE1
	// node_colour <> current_colour i.e. colour change
	movl	SN_COLOUR(descP),node_colour			// get colour of node
	testl	$ ENSN_COLOUR_SET_EN_BIT,node_colour
	jnz 	ENTRY_LABEL							// is al op de stack
	
	// not an en-node yet
	andl	$ ENSN_COLOUR_GET_COLOUR,node_colour
	
	ML(_build_external_reference)
	
	movl	node_colour,ML(external_ref)

	ML(_create_entry_node)

	// notice that the EN-node has not yet been copied in the string
#  define entry_node %ecx
#  define temp descP
	leal	1(entry_node),temp				
	movl	temp,(nodeP)					// change descP of node to the created entry node
	
	movl	nodeP,EN_NODEP(entry_node)		// NEW!!!! to find the EN-node in the copy pass.
#  undef temp
#  undef entry_node	

	pushl	nodeP							// visit different coloured node later

	jmp		ENTRY_LABEL
# endif

	// node_colour <> current_colour i.e. colour change
	movl	SN_COLOUR(descP),node_colour
	andl	$ ENSN_COLOUR_EN_BIT_AND_COLOUR,node_colour
	testl	$ ENSN_COLOUR_SET_EN_BIT,node_colour
	jnz 	2f
	
	ML(_build_external_reference)
	jmp		3f
2:
	movl	EN_NODE_INDEX(descP),node_colour
3:
	movl	node_colour,ML(external_ref)

	// look if node has already been marked as an entry node
	movl	SN_COLOUR(descP),node_colour	// get colour of node
	andl	$ ENSN_COLOUR_EN_BIT_AND_COLOUR,node_colour
	testl	$ ENSN_COLOUR_SET_EN_BIT,node_colour
 	jnz		ENTRY_LABEL						// marked, ignore reference
//1# undef node_colour 

	ML(_create_entry_node)

	// notice that the EN-node has not yet been copied in the string
# define entry_node %ecx
# define temp descP
	leal	1(entry_node),temp				
	movl	temp,(nodeP)					// change descP of node to the created entry node
	
	movl	nodeP,EN_NODEP(entry_node)		// NEW!!!! to find the EN-node in the copy pass.
# undef temp
# undef entry_node	

	pushl	nodeP							// visit different coloured node later

	jmp		ENTRY_LABEL

ML(niet_af):
	movl	SN_COLOUR(descP),node_colour
	testl	$ ENSN_COLOUR_ALREADY_VISITED_MASK,node_colour				
	jnz		ENTRY_LABEL 					// node has already been visited but there might still be a colour change

	// 	andl	$ ENSN_COLOUR_GET_COLOUR,node_colour

# undef node_colour
	orl		$ ENSN_COLOUR_ALREADY_VISITED_MASK,SN_COLOUR(descP)	// mark node

	// node_colour == current_colour
	movl	SN_DESCP(descP),descP

	testl	$2,descP
	je		ML(resolve_closure_indirection)
#endif // DETERMINE_ENTRY_NODES_PASS

	// --------------------------------------------------------
	// BODY
	cmpl	$__ARRAY__+2,descP
	je		ML(delete_in_array)
	
	movzwl	-2(descP),arity					// get arity
	
	cmpl	$0,arity						// arity == 0
	je		ENTRY_LABEL
	cmpl	$1,arity						// arity == 1
	je 		ML(delete_in_first_argument)		
	cmpl	$2,arity						// arity == 2
	je		ML(delete_in_second_and_first)
	cmpl	$256,arity						// arity >= 256
	jae		ML(delete_in_record)
	
	//  2 < arity < 256
ML(delete_argument_pointers):
	movl	8(nodeP),source					// set source
	decl	arity					
	
#define temp	%ebx
	COPY_STACK_BLOCK temp
#undef temp

	jmp		ML(delete_in_first_argument)
	
ML(delete_in_second_and_first):
#define temp	%ebx
	movl	8(nodeP),temp
	PUSHL2	temp
#undef temp

ML(delete_in_first_argument):
	movl	4(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP
	
	// resolve_closure_indirection
	//
	// structure: (.text)
	// -8(descP)	descp //pointer to (real) total arity of descriptor
	// -4(descP)	total arity of {boxed,unboxed} closure
	// closure code
	// Descriptor:
	//	.long	pointer to arity 0 node 	// if n_yet_args_needed_entries == 0
	//	;
	//	.long	module_name_pointer
	//	.long	pointer to arity 0 * 8
	//	.word	0
	//	.word	n_yet_args_needed_entries	// e.g. total_arity
	//	
	//	descP:
	//	.word 	0				// arity 0
	//	.word	0
	//	.long 	yet_args_needed_0
	//	
	//	.
	//	.
	//	
	//	.word	total_arity - 1			// arity (total_arity - 1)
	//	.word 	(total_arity - 1) * 8 			
	//	.long	yet_args_needed_(total_arity-1)
	//	-----------------	
	//	
	//	.word	total_arity			// arity total_arity
	//	.word 	n_yet_args_needed_entries * 8		
	//	
	//	.long	length 				// function name
	//	.ascii  name
	//	.byte	0
	//	
	// Notes:
	//	1) n_yet_args_needed_entries
	//	   The number of yet_args_needed entries which normally equals the arity
	//	   of the Clean symbol. Except when the codegenerator detects no partial
	//	   applications of the symbol, then no entries are present. 
	//	   
	// or (if at least one unboxed arguments is present):
	//	.long	module_name_pointer
	//	.long	function_name_pointer
	//
	//	.byte 	arity
	//	.byte 	n_unboxed_args			// at least 1
	//	.word	0 				// flags?
	//	
	//	descP:
	//	.ascii  type_string 			// d,i,a ?
	//	.byte 	0
	//	
	//	function_name_pointer:
	//	.long	length				// function_name
	//	.ascii  name
	//	.byte 	0

#define temp	%ebx
ML(resolve_closure_indirection):
#ifdef COPY_NAMES_PASS
	_start_copying_names indirection
	
	cmpl	$ CLEAN_nbuild_block,descP
	jne 	ML(hier2)
	movl	$ CLEAN_nbuild_lazy_block,descP
ML(hier2):

	movl	-8(descP),nameP					// get descriptor ptr

# define temp2	nodeP

	movzwl	2(nameP),temp2
	lea		12(nameP,temp2),nameP

	// get module name
	movl	-4(nameP),temp2					// get module pointer
	movl	temp2,nameP_backup

	// 0 =< arity <= 256, generate prefix info
	testw	$1,-8(nameP)					// test flag
	jnz		ML(ruci_c_prefix)
	movl	$ N_PREFIX,prefix_kind
	jmp		ML(ruci_flag_set)
ML(ruci_c_prefix):
	movl	$ C_PREFIX,prefix_kind
ML(ruci_flag_set):

# undef temp2
	
	_copy_name
	
	movl	(nodeP),descP

ML(resolve_closure_arguments):
#endif // COPY_NAMES_PASS

	movl	-4(descP),arity
	cmpl	$0,arity
	jl		ML(resolve_closure_arguments2)
	
	je		ENTRY_LABEL
	
	cmpl	$256,arity				// arity >= 256
	jae		ML(resolve_unboxed_closure)

	cmpl	$ CLEAN_nbuild_lazy_block,descP
	je 		ENTRY_LABEL

	cmpl	$ CLEAN_nbuild_block,descP

#ifdef SHARING_ACROSS_CONVERSIONS
	jne		ML(no_build_block)

	movl	BUILD_DYNAMIC_GDID__PTR(nodeP),nodeP
	testl	$2,(nodeP)
	jnz		ML(no_closure)
	
	movl	4(nodeP),nodeP								// argument of closure is GlobalDynamicInfo
ML(no_closure):	
	movl	8(nodeP),nodeP
	movl	GDI_GRAPH_POINTERS(nodeP),nodeP
	
	jmp		ENTRY_LABEL_NODEP		
ML(no_build_block):
#else
	je		ENTRY_LABEL
#endif	

	leal	4(nodeP),source
	
	COPY_STACK_BLOCK temp
	
	jmp 	ENTRY_LABEL

ML(resolve_closure_arguments2):
	movl	4(nodeP),nodeP
	jmp		ENTRY_LABEL_NODEP	
#undef temp

#define nrUnboxed	nodeP
#define nrUnboxedL	%al
#define nrPointers	arity
#define nrPointersH	%ch
#define temp		%ebx

ML(resolve_unboxed_closure):
	leal	4(nodeP),source				// set source

	xorl 	nrUnboxed,nrUnboxed
	movb	nrPointersH,nrUnboxedL
	andl	$255,arity
	sub		nrUnboxed,arity				// arity = # boxed arguments

	je  	ML(resolve_unboxed_closure2)
	
	COPY_STACK_BLOCK temp
	
ML(resolve_unboxed_closure2):
	jmp		ENTRY_LABEL
	
#undef nrUnboxed
#undef nrPointers
#undef temp

	// delete indirections in an array
	//
	// Array-node structure:
	//	(nodeP)		array descriptor pointer
	//	4(nodeP)	number of elements
	//	8(nodeP)	element descriptor pointer
	//
	// Note:
	// 1) If the element descriptor pointer is zero, then it
	//    is a boxed array. The array elements are then 
	//    pointers
#ifdef COPY_NAMES_PASS
ML(delete_in_array_no_element_indirection2):
	movl	indirection,descP
	jmp		ML(delete_in_array_no_element_indirection)
#endif
	
ML(delete_in_array):
#ifdef COPY_NAMES_PASS
	// almost same as in resolve_indirection (macro van maken)
	// restore element descriptor pointer
	movl	8(nodeP),indirection
	
	/*
	// If the element descriptor is not an indirection, its name
	// has already been copied. However in case of a boxed array
	// or an unboxed record array containing also boxed elements
	// indirections may still exist.
	*/
	testl	$1,indirection
	je		ML(delete_in_array_no_element_indirection2)	// no indirection
	
	leal	-1(indirection),indirection
	movl	(indirection),descP

	movl	descP,8(nodeP)
	
	movl	$0,prefix_kind
	cmpl	$0,descP				
	je		ML(delete_in_array_no_element_indirection)	// boxed array, no name to copy
	
	_start_copying_names indirection

	movzwl	-2(descP),arity					// descriptor (partial) arity
	cmpl	$256,arity	
	jb		ML(dia_no_record_descriptor)
	
ML(dia_record_descriptor):
	// test for {k,r}-prefix
# define temp nodeP
	movzbl	2(descP),temp					// first char of type string
	cmpl	$'d',temp
	jne		ML(dia_rd_r_prefix)
	movl	$ K_PREFIX,prefix_kind				// k-prefix
	jmp		ML(dia_rd_kr_flag_set)
ML(dia_rd_r_prefix):
	movl	$ R_PREFIX,prefix_kind				// r-prefix
ML(dia_rd_kr_flag_set):
# undef temp

# define temp nodeP
	movl	-10(descP),temp					// get module descriptor
	movl	temp,nameP_backup
# undef temp

	movl	-6(descP),nameP					// get ptr to function name
	jmp		ML(dia_function_name_marked)

ML(dia_no_record_descriptor):
# define	temp nodeP
	movzwl	(descP),temp					// temp = (partial) arity * 8
	lea		10(descP,temp),nameP
	
	shll	$24,arity
	
	testw 	$1,-8(nameP)					// test flag
	jnz		ML(dia_no_rd_t_prefix)

	movl	$ D_PREFIX,prefix_kind			// d-prefix
	orl		arity,prefix_kind 				// inefficient
	jmp		ML(dia_no_rd_dt_flag_set)
ML(dia_no_rd_t_prefix):
	movl	$ T_PREFIX,prefix_kind			// t-prefix
ML(dia_no_rd_dt_flag_set):

# define temp2 descP
	movl	-4(nameP),temp2			
	movl	temp2,nameP_backup				// nameP = ptr to module name
# undef temp2
# undef temp

ML(dia_function_name_marked):
	_copy_name

	movl	8(nodeP),descP
	
ML(delete_in_array_no_element_indirection):
#else // COPY_NAMES_PASS
	movl	8(nodeP),descP
#endif 

	cmpl	$0,4(nodeP)						// empty array
	je		ENTRY_LABEL

	cmpl	$0,descP	
	je		ML(delete_in_array_pointers)	// delete in boxed array elements

#ifdef COLOUR_PASS
	// I could first search in sn-array for an entry having the same descriptor but for
	// now I just allocate a new entry
# define temp2 descP
	pushl	temp2

	call	MAKE_ID_USN(lb_alloc_entry)					// alloc for node and colour index

	movl	descP,SN_DESCP(%ecx)
	movl	array_colour,temp2
	movl	temp2,SN_COLOUR(%ecx)

	popl	temp2
# undef temp2
#endif

	cmpl	$INT+2,descP
	je		ENTRY_LABEL
	cmpl 	$BOOL+2,descP
	je		ENTRY_LABEL
	cmpl	$REAL+2,descP		
	je		ENTRY_LABEL
	
	jmp 	ML(delete_in_record_array)		// delete in record array
	
#define	temp		nodeP
#define t_nodeP		arity
#define temp2		source

ML(delete_in_record_array):
	movl	stackP,t_stackP					// backup stackP
	movl	nodeP,t_nodeP					// backup nodeP
	
	movzwl	(descP),temp					// #boxed fields per records
	cmpl	$0,temp							// any boxed arguments?
	je		ENTRY_LABEL						// only unboxed, continue deleting
	
	mull	4(t_nodeP)						// temp = size of boxed part of array (in longs)
	xchg	nodeP,arity
	
	movl	t_stackP,stackP					// restore stackP
	
	RESERVE_STACK_BLOCK temp2				// reserve stack

#undef t_nodeP	
#undef temp
#undef temp2

	// Copy the boxed part of the record array to stack
	leal	12(nodeP),source				// set source
	
	pushl	free
#define nrPointers free					
	movzwl	(descP),nrPointers				// get # boxed arguments
	
#define s_unboxed_arguments descP
	movzwl	-2(descP),s_unboxed_arguments	// get record size
	subl	$256,s_unboxed_arguments
	subl	nrPointers,s_unboxed_arguments	// s_unboxed_arguments = size of unboxed fields
	shll	$2,s_unboxed_arguments			// s_unboxed_arguments *= 4 (in bytes)
	
#define count	nodeP
	movl	4(nodeP),count					// get array size
	
	pushl	heapP
	movl	stackP,heapP					// set destination to stack start
	
ML(delete_boxed_fields):
	movl	nrPointers,arity				// set arity to # boxed fields
	
	cld
	rep
	movsl
	
	addl	s_unboxed_arguments,source		// skip unboxed fields of records
	
ML(deleted_boxed_fields_of_records):
	decl	count
	jne		ML(delete_boxed_fields)
	
	popl	heapP
	popl	free
	jmp		ENTRY_LABEL
#undef nrPointers
#undef s_unboxed_arguments
#undef count

#define size	arity
ML(delete_in_array_pointers):
	movl	4(nodeP),size					// get array size
	leal	12(nodeP),source
	
#define	temp	%ebx
	COPY_STACK_BLOCK temp
#undef temp
	
	jmp		ENTRY_LABEL

#define nrPointers	%esi
ML(delete_in_record):
	movzwl	(descP),nrPointers				// nrPointers (boxed arguments)
	subl	$256,arity						// arity -= 256 (real arity)
	
	cmpl	$0,nrPointers					// nrPointers == 0
	je		ENTRY_LABEL						// continue deleting indirections

	cmpl	$1,nrPointers					// nrPointers == 1
	je 		ML(delete_in_first_argument)
	cmpl	$2,nrPointers					// nrPointers == 2
	je 		ML(delete_two_in_record)
	
	movl	nrPointers,arity				// arity = # boxed arguments/fields
	jmp		ML(delete_argument_pointers)
	
ML(delete_two_in_record):
	cmpl	$2,arity						// arity == 2
	je		ML(delete_in_second_and_first)
	
#define temp %ebx
	movl	8(nodeP),temp
	movl	(temp),temp
	
	PUSHL2 temp
#undef temp
	
	jmp		ML(delete_in_first_argument)

// .data
#ifdef COPY_NAMES_PASS
	.data
delete_counter:
	.long	0
#endif								

#ifndef GTS_DELETE_PASS_ONLY_ONCE	
# define GTS_DELETE_PASS_ONLY_ONCE
	
	.data
	.align	4
prefix_to_set:
	.long	1			// n-prefix
	.long	2			// d-prefix
	.long	4			// k_prefix
	.long	8			// c_prefix
	.long	16			// t_prefix
	.long	32			// r_prefix	
	
	.align	4
prefix_kind:
	.long 0
nameP_backup:
	.long 0
current_descP:
	.long	0
prefix_address_entry_ptr:
	.long 	0
#endif

	.text	
	.align	4

#undef nrUnboxed
#undef nrPointers
#undef ENTRY_LABEL
#undef ENTRY_LABEL_NODEP
#undef COPY_STACK_BLOCK	
#undef RESERVE_STACK_BLOCK
#undef PUSHL2

#ifdef COLOUR_PASS 
# undef COLOUR_PASS
#endif
#ifdef COPY_NAMES_PASS 
# undef COPY_NAMES_PASS
#endif
#ifdef DETERMINE_ENTRY_NODES_PASS
# undef DETERMINE_ENTRY_NODES_PASS
#endif

#undef UNFIXED_STACK
#undef ML