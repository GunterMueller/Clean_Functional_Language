
#define GTS_STACK

#define CREATE_BUILD_BLOCK_LIST

// TODO:
// - use gts_stack
// - use gts_copy or gts_delete ?
// - re-organize

#include "globals.h"
#include "gts_runtime_id.h"
#include "global_registers.h"
#include "gts_build_block.h"
#include "gts_gdi.c"
#include "gts_debug.c"

#define stringP	source
#define root_nodeP nodeP

// 
.text
	ret
	nop
	nop
	nop
	ret
#include "stack1.c"

// als er iets misgaat waarschijnlijk in 2nd pass; last_restored_pointers

#define PREFIX_PER_NODE

	.MACRO _copy_argument_block_without_reserve l1
	/*
	** stackP points to beginning of reserved stack frame
	*/
	\l1:	
		movl	heapP,(stackP)
		addl	$4,stackP
		
		addl	$4,heapP
		decl	%ecx
		jne 	\l1
	.ENDM

	.MACRO _copy_argument_block_nodeP t l1 l2
#define t_heapP nodeP
		leal	-4(heapP),t_heapP
		
		subl	arity,free
		js	garbage_collection
	
		movl	stackP,\t
		subl	stackTop,\t			// temp = stackP - stackTop
		shrl	$2,\t
	
		cmpl	\t,arity			// arity < temp	
		jbe	\l1				// enough space between stackTop and stackP

		// arity > temp
		// arity = arity - temp
		
		subl	\t,arity			// arity - available space between stackTop and stackP
		subl	arity,free			// free -= rest of arity			
		js	garbage_collection
		
		addl	\t,arity			// restore arity	
		incl	heapP				// mark heapP to indicate that stackP must be copied to stackTOp
	\l1:	
		leal	(t_heapP,arity,4),\t
		subl	$4,stackP
		movl	\t,(stackP)
		addl	$4,heapP
		decl	%ecx
		jne		\l1
		
		testl	$1,heapP			// heapP points to free space
		jz	\l2
		decl	heapP
		movl	stackP,stackTop
	\l2:
#undef t_heapP
	.ENDM
	
	.MACRO _copy_block_to_heapP
		subl	arity,free			// enough free
		js	garbage_collection
	
		cld					// copy
		rep
		movsl
	.ENDM

#include "prefixes.h"

	/* precondition:
	** - descP contains (stringP); the descriptor to be decoded
	**
	** postcondition:
	** descP contains the *real* descriptor pointer
	*/
	.MACRO _decode_descriptor t0 non_d_prefix end_decode_descriptor
		movl	descP,\t0
		andl	$0xe0000000,\t0
		cmpl	$ N_PREFIX,\t0
		je		\non_d_prefix
		cmpl	$ C_PREFIX,\t0
		je		\non_d_prefix
		
		pushl	descP
		
		movl	descriptor_address_table,\t0
		andl	$0x00ffffff,descP			// strip prefix kind & arity
		movl	-4(\t0,descP),descP			// base address of descriptor
		
		popl	\t0
		shrl	$24,\t0
		andl	$0x0000001f,\t0				// t0 = arity
		
		leal	2(descP,\t0,8),descP
		
		jmp	\end_decode_descriptor
	
	\non_d_prefix:
		movl	descriptor_address_table,\t0
		andl	$0x00ffffff,descP			// strip prefix kind
		movl	-4(\t0,descP),descP
	\end_decode_descriptor:
	.ENDM
		
	.data
	.align 4
#ifdef GDI
gdi_backup:
	.long 0	
#endif

graph_string_backup:
	.long 0
graph_string_length:
	.long 0
esp_backup:
	.long 0

esi_backup:
	.long 0
entry_node_ptr:
	.long	0						// ptr in array which contains the addresses of each entry node
graph_pointers:
	.long	0						// ptr to graph_pointers field in gdi updated after each gc	

old_heap_pointer:
	.long 0
initfree:
	.long 0
last_restored_descP:
	.long 0

#ifdef PREFIX_PER_NODE
descriptor_address_table:
	.long 0
#endif

	.text

#ifdef PREFIX_PER_NODE
# define coded_graph %ecx
# define descriptor_pointers %edx

	.data
	.align 4
descriptor_address_table_backup:
	.long 0
stringP_offset:
	.long 0							// offset in string where decoding starts

block_i:
	.long	0
en_node_i:
	.long 	0
stringP_end:
	.long	0						// end encoded block
subblock_end:
	.long 	0

#ifdef CREATE_BUILD_BLOCK_LIST
build_block_list_last:
	.long	0
build_block_list:
	.long	0
build_block_list_flag:
	.long	0
#endif	
	.text

#include "fromClean9.c"

	// ----------------------------------------------------------------------------------
	// %eax		= index (Int)
	// %ecx		= graph (String)
	// %edx 	= descriptor address table (String; expanded by linker)

	.globl copy__string__to__graph__0x00010101
copy__string__to__graph__0x00010101:

#undef GDI

	movl	%eax,block_i						// backup block_i
	
#define temp nodeP
	movl	(%esp),temp
	movl	temp,en_node_i						// backup en_node_i
#undef temp
	
#define temp nodeP
	movl	-4(%esi),%eax
	movl	%eax,gdi_backup
#undef temp

	/*
	# (graph2,_)
		= copy_string_to_graph 
			(s_adr % (8,size s_adr)) 			// %edx
			0									// %ebx offset in graph_block 
			graph_block							// %ecx graph
			gdid								// -4(%esi) unboxed GlobalDynamicInfo
			bk_entries 							// -8(%esi)
			block_i 							// %eax
			en_node_i;							// (%esp)
	*/

	movl	%eax,gdi_backup
	
	movl	$0,%eax		// klopt dit
	/*
	** This entry should only be called once from Clean with a fresh encoded graph because
	** the algoritm destructively updates the graph. The last_restored_descP marks where 
	** the decoding algoritm was forced to quit because there wasn't enough free memory
	** available.
	** The descriptor pointer in the encoded graph have then partly been converted into
	** real descriptor pointers.
	*/
	// WARNING: the encoded graph is modified. These modifications are *not* undone.

	// backup & process parameters ...
	movl	%eax,stringP_offset			// offset in %ecx where decoding starts

#ifdef GDI
	movl	GDI_GRAPH(gdi),%eax
	leal	4(%eax),%eax
#else
	leal	4(%ecx),%eax
#endif
	movl	%eax,last_restored_descP
#endif

// pass 1; entry point *after* garbage collection
copy__string__to__graph:
#ifdef CREATE_BUILD_BLOCK_LIST
	movl	$__Nil-4,build_block_list
	movl	$__Nil-4,build_block_list_last

	movl	-4(%esi),nodeP						// nodeP = address of gdi
	movl	8(nodeP),nodeP						// nodeP = address of gdi's arg block
	movl	GDI_DUMMY(nodeP),nodeP
	movl	4(nodeP),nodeP
	movl	nodeP,build_block_list_flag
#endif

#define temp nodeP
	movl	-4(%esi),temp						// temp = address of gdi
	movl	8(temp),temp						// temp = address of gdi's arg block

	movl	GDI_GRAPH_POINTERS(temp),temp
	movl	temp,graph_pointers					// temp = address of graph_pointers field	
#undef temp

	//  Backup
	movl	%edx,descriptor_address_table_backup

	leal	8(%edx),%eax
	movl	%eax,descriptor_address_table

	// %ecx backup
#ifdef GDI
# define temp	%eax
	movl	gdi,gdi_backup					// backup gdi ptr
	
	movl	GDI_GRAPH(gdi),%ecx				// ptr to encoded graph (string)
	movl	%ecx,graph_string_backup
# undef temp
#else
	movl	%ecx,graph_string_backup		// backup pointer
#endif

	movl	heapP,old_heap_pointer

#define temp nodeP
	movl	4(%ecx),temp
	movl	temp,graph_string_length		// backup length
#undef temp
	//  ... backup & process parameters

	// initialize ...
#ifdef PREFIX_PER_NODE
	movl	end_heap,stackP
	leal	32(stackP),stackP

	movl	stackP,stackBottom
#else
	movl	end_heap,stackP
#endif
	
	movl	stackP,stackTop
	
	movl	stackP,free
	subl	heapP,free
	shrl	$2,free
	movl	free,initfree
	
	movl	%esp,esp_backup				// backup %esp (B/C stack ptr)
	movl	%esi,esi_backup				// backup %esi (A stack ptr)
	// ...	

	movl	%ecx,graph_string_backup
	
	// compute end address of current block
#define temp nodeP
	movl	4(%ecx),temp				// get length of encoded graph
	leal	8(%ecx,temp),temp
	movl	temp,stringP_end			// store end address of encoded graph
#undef temp

	leal	8(%ecx),stringP				// set ptr to encoded graph

	movl	$0,stringP_offset			// set offset where to start decoding
	
0:
	_pushl1	stringP						// push address of an entry node

	// stringP_offset moet goed gezet worden	?
	
	call	copy_next_node				// decode node
	
	cmpl	stringP_end,stringP			// complete block decoded
	jb	 	0b							//0b

	movl	esi_backup,descP					

	// reserve array
	subl	$3,free								// reserve for array header	
#define bk_entries nodeP
	movl	-8(descP),bk_entries
	subl	4(bk_entries),free					// reserve for array data	
	js		garbage_collection

	movl	descP,%esi							// restore %esi (A-stack ptr)

	// adjust gdi to point to the array being created
#define block_index arity
	movl	block_i,block_index
#define temp descP
	movl	-4(%esi),temp						// temp = address of gdi
	movl	8(temp),temp						// temp = address of gdi's arg block
	movl	8(temp),temp						// temp = address of graph_pointers field
	
	movl	heapP,12(temp,block_index,4)		// store pointer to new array
#undef temp
#undef block_index	

#define temp descP
	movl	$__ARRAY__+2,temp					
	movl	temp,(heapP)						// create ARRAY node
#undef temp
	
#define n_node_entries descP

#undef bk_entries
#define graph_string nodeP
	movl	graph_string_backup,graph_string	// restore encoded graph	

#define bk_entries arity
	movl	-8(%esi),bk_entries
	movl	4(bk_entries),n_node_entries
	movl	n_node_entries,4(heapP)				// set array size
	
	movl	$0,8(heapP)							// boxed array so the gc updates the addresses
												// of the entry nodes.			
#define temp %esi
	pushl	temp								// backup %esi A/B-stack pointer
	
#define node_entry_i %edx
	movl	$0,node_entry_i
	
	leal	12(heapP),heapP
	pushl	heapP

0:
	movl	12(bk_entries,node_entry_i,4),temp	// temp = starting offset for a node entry in the graph_string
	movl	8(graph_string,temp),temp			// temp = address of node entry
	
	movl	temp,(heapP)						// store node entry address in the new array
	addl	$4,heapP
	
	incl	node_entry_i
	cmpl	n_node_entries,node_entry_i
	jb		0b	
#undef node_entry_i			// %edx
#undef bk_entries			// arity
#undef n_node_entries		// descP

	// determine address of entry node to be returned
	popl	temp								// restore address of newly created array
	
#define entry_node_i descP
	movl	en_node_i,entry_node_i				// get entry node
	
	movl	(temp,entry_node_i,4),%ecx
#undef entry_node_i
	
	popl	temp								// restore %esi
#undef temp

	// cleanup stack
	leal	-8(%esi),%esi
	popl	%eax
	
# ifdef CREATE_BUILD_BLOCK_LIST
	cmpl	$0,build_block_list_flag
	je		no_evaluate_build_block_nodes

	movl	%ecx,(%esi)
	addl	$4,%esi

	movl	build_block_list,%ecx
evaluate_build_block_nodes:
	cmpl	$__Nil-4,%ecx
	je		end_evaluate_build_block_nodes

	movl	4(%ecx),%edx

	testl	$2,(%edx)
	jne		build_block_node_already_evaluated

	movl	%ecx,(%esi)
	addl	$4,%esi

	movl	(%edx),%ebp
	movl	%edx,%ecx

	cmpl	$ CLEAN_nbuild_block,%ebp
	je		build_block_node_ok
	int3
build_block_node_ok:
	call	e__DynamicGraphConversion__nbuild__block__without__evaluating__graph
	movl	$e__DynamicGraphConversion__nbuild__block__indirection,(%ecx)	// 2 tuple -> indirection to first tuple element

	movl	-4(%esi),%ecx
	subl	$4,%esi

build_block_node_already_evaluated:
	movl	8(%ecx),%ecx
	jmp		evaluate_build_block_nodes

end_evaluate_build_block_nodes:
	lea		12+16(%edi),%ecx
	movl	$__Cons+18,(%edi)
	movl	$__Nil-4,8(%edi)
	movl	%ecx,4(%edi)

	movl	-4(%esi),%ecx
	subl	$4,%esi

no_evaluate_build_block_nodes:
#endif

	ret

	// ... initialize

copy_next_node:
	_stack_empty copy_done
	
	movl	(stringP),descP				// get descriptor offset
	
	subl	$1,free
	js		garbage_collection
	
	_popl1	root_nodeP
	
	testl	$1,descP				// indirection?
	jne		copy_indirection			// yes, copy indirection

	/* last_restored_descP */
	cmpl	last_restored_descP,stringP		// stringP <= last_restored_descP
#ifdef PREFIX_PER_NODE
	jbe		copy_descriptor    //Martijn
#else
	jbe		skip_descriptor_pointer_computation
#endif
	
	movl	stringP,last_restored_descP

#ifdef PREFIX_PER_NODE
# define t0 arity
	_decode_descriptor t0 l349_non_d_prefix l350_end_decode_descriptor
# undef t0
#endif

copy_descriptor:
	addl	$4,stringP
	movl	descP,(heapP)				// store descriptor	

#ifdef PREFIX_PER_NODE
	testl	$2,descP				// in hnf?
	je		copy_closure				// yes, copy closure
#endif
	
	movl	heapP,(root_nodeP)			// root node points to currently being created node
	movl	heapP,-4(stringP)			// make indirection UNCOMMENT ME!!!	
	addl	$4,heapP				// move to arguments part of node
	
	cmpl	$INT+2,descP
	je 		copy_integer
	cmpl	$CHAR+2,descP
	je		copy_char
	cmpl	$BOOL+2,descP
	je		copy_bool
	cmpl	$REAL+2,descP
	je		copy_real
	cmpl	$__STRING__+2,descP
	je 		copy_string
	cmpl	$__ARRAY__+2,descP
	je		copy_array
	
	/*
	** copy_argument_pointers
	*/
copy_argument_pointers:
	movzwl	-2(descP),arity
	
	cmpl	$0,arity				// arity == 0
	je		copy_zero_argument_pointers
	cmpl	$1,arity				// arity == 1
	je 		copy_one_argument_pointer
	cmpl	$2,arity				// arity == 2
	je		copy_two_argument_pointers
	cmpl	$256,arity				// arity == 256
	jae		copy_record
	
copy_more_arguments_between_2_and_256:
	subl	$2,free
	js		garbage_collection
	
	pushl	heapP					// backup nodeP
#define nodeP_for_rest_arguments nodeP
	leal	8(heapP),nodeP_for_rest_arguments
	movl	nodeP_for_rest_arguments,4(heapP)	// 2nd argument of node is pointer to rest arguments
	
	movl	nodeP_for_rest_arguments,heapP		// heapP += 8
#undef nodeP_for_rest_arguments

	decl	arity
	
	_copy_argument_block_nodeP descP copy_more_arguments_between_2_and_256a copy_more_arguments_between_2_and_256b

#define temp nodeP
	popl	temp					// restore heapP to first argument
	
	_pushl1 temp //copy_more_arguments_between_2_and_256c
#undef temp
	
	jmp	copy_next_node
	
copy_zero_argument_pointers:
	addl	$1,free					// undo descriptor
	subl	$4,heapP
	
#define temp arity
	leal	-6(descP),temp
	movl	temp,(root_nodeP)
	
	movl	temp,-4(stringP)			// set correct address for indirections
#undef temp
	jmp 	copy_next_node
		
copy_one_argument_pointer:
	subl	$1,free
	js	garbage_collection
	
	_pushl1 heapP // copy_one_argument_pointer1
	
	addl	$4,heapP
	jmp	copy_next_node
	
copy_two_argument_pointers:
	subl	$2,free
	js	garbage_collection
	
#define temp arity
	leal	4(heapP),temp
	_pushl1 temp  //copy_two_argument_pointers1
#undef temp
	_pushl1 heapP //copy_two_argument_pointers2
	addl	$8,heapP
	jmp	copy_next_node
	
	/*
	** copy_integer
	*/
#define base descP
copy_integer:
	movl	$small_integers,base
	
copy_integer_or_char:
#define value arity
	movl	(stringP),value
	addl	$4,stringP
	cmpl	$32,value				// 0 <= value <= 32
copy_integer_or_char2:
	jbe	copy_small_integer_or_char		// use predefined node
	
copy_value:
	subl	$1,free
	js	garbage_collection
	
	movl	value,(heapP)
	
	addl	$4,heapP
	jmp	copy_next_node
	
copy_small_integer_or_char:
	addl	$1,free					// undo node for integer
	subl	$4,heapP
	
#define small_integers_base descP
	leal	(base,value,8),value
	movl	value,(root_nodeP)
	
	movl	value,-8(stringP)			// set indirection

	jmp	copy_next_node	

	/* copy_char */
copy_char:
	movl	$static_characters,base

	movl	(stringP),value
	addl	$4,stringP
	cmpl	$255,value
	jmp	copy_integer_or_char2
#undef base

	/* copy_bool */
copy_bool:
	movl	(stringP),value
	addl	$4,stringP
	jmp	copy_value
	
	/* copy_real */
copy_real:
	subl	$2,free
	js	garbage_collection
	
	movl	(stringP),value
	movl	value,(heapP)
	movl	4(stringP),value
	movl	value,4(heapP)
	
	addl	$8,heapP
	addl	$8,stringP
	jmp	copy_next_node
#undef value
		
	/*  copy_indirection */
	.macro _decode_block_i_from_external_reference reg
		andl	$0x0000fffc,\reg
		shrl	$2,\reg
	.endm
	
	.macro _decode_en_node_i_from_external_reference reg
		shrl	$16,\reg
	.endm
	
	.macro _decode_internal_indirection reg
		shrl	$2,\reg
	.endm

copy_indirection:	
	decl	descP
	testl	$2,descP
	jz		0f
	
# define COLOUR_GRAPH_REMOVE_REFS_TO_DECODED_BLOCKS
# ifdef COLOUR_GRAPH_REMOVE_REFS_TO_DECODED_BLOCKS
#  define block_array %ecx
	pushl	%ecx
	pushl	descP

	movl	graph_pointers,block_array			// graph_pointers
	
	_decode_block_i_from_external_reference descP
	
	movl	12(block_array,descP,4),block_array	// get block
	cmpl	$0,4(block_array)
	je	 	copy_indirection2

	popl	descP
	
	_decode_en_node_i_from_external_reference descP
	movl	12(block_array,descP,4),descP
	popl	%ecx
	movl	descP,(root_nodeP)
	
	addl	$4,stringP
	
	jmp		copy_next_node
# endif //COLOUR_GRAPH_REMOVE_REFS_TO_DECODED_BLOCKS

copy_indirection2:
# ifdef COLOUR_GRAPH_REMOVE_REFS_TO_DECODED_BLOCKS
	popl	descP
	popl	%ecx
# endif

# ifdef CREATE_BUILD_BLOCK_LIST
	cmpl	$0,build_block_list_flag
	je		no_build_block_list

	subl	$10,free
	js		garbage_collection

	lea		12+16(%edi),%ecx
	movl	$__Cons+18,(%edi)
	movl	$__Nil-4,8(%edi)
	movl	%ecx,4(%edi)

	movl	build_block_list_last,%ecx
	cmpl	$__Nil-4,%ecx
	je		first_build_block_list_element

	movl	%edi,8(%ecx)
	jmp		not_first_build_block_list_element

first_build_block_list_element:
	movl	%edi,build_block_list

not_first_build_block_list_element:
	movl	%edi,build_block_list_last
	addl	$12,%edi

no_build_block_list:
# else
	subl	$7,free
	js		garbage_collection
#endif

	// create GlobalDynamicInfoDummy record
# define temp %ecx
	movl	$ CLEAN_cGlobalDynamicInfoDummy,(%edi)
	movl	gdi_backup,temp
	movl	temp,4(%edi)						// wrap GlobalDynamicInfo back into a GlobalDynamicInfoDummy-record

	movl	$INT+2,8(%edi)						// create INT
	incl	descP
	movl	descP,12(%edi)

	movl	$ CLEAN_nbuild_block,16(%edi)
	leal	8(%edi),temp
	movl	temp,20(%edi)						// INT ptr
	movl	heapP,24(heapP)

	leal	16(heapP),temp
	movl	temp,(root_nodeP)
# undef temp

	leal	28(%edi),%edi
	addl	$4,stringP

	jmp		copy_next_node

	// internal indirection
0:
	_decode_internal_indirection descP

	addl	$4,stringP						// using this instruction; copy_indirection can certainly be optimized
	
#define node_pointer arity
	leal	-4(stringP),node_pointer

	subl	descP,node_pointer				// heap_address = stringP - descP
	movl	(node_pointer),node_pointer		// get node pointer earlier stored in string
	movl	node_pointer,(root_nodeP)
#undef node_pointer
	jmp	copy_next_node
#undef node_pointer

	/* copy_record */
#define nrPointers nodeP
#define recordSize descP
copy_record:
	movzwl	(descP),nrPointers			// nrPointers = # boxed arguments
	subl	$256,arity				// arity -= 256
	
	subl	arity,free				// free < arity for heap nodes
	js	garbage_collection
	
	cmpl	$0,arity
	je	copy_next_node
	
	movl	$4,recordSize				
	
	cmpl	$1,arity
	je 	copy_record_with_one_cell
	cmpl	$2,arity
	je	copy_record_with_two_cells
	
	subl	$1,free					// free < arity
	js	garbage_collection
	
	pushl	heapP					// nodeP of first argument
	pushl	nrPointers				// backup nrPointers
	
#define temp descP
	leal	8(heapP),temp
	movl	temp,4(heapP)				// nodeP of rest arguments
	
	movl	temp,heapP				// heapP += 8
#undef temp

#define nrUnboxed descP
	movl	arity,nrUnboxed
	subl	nrPointers,nrUnboxed			// nrUnboxed = #unboxed arguments
	
	cmpl	$0,nrPointers				// arity - 1 arguments are to be copied
	je	only_unboxed_args
	decl	nrPointers
	jmp	copy_boxed_args
only_unboxed_args:
	decl	nrUnboxed

copy_boxed_args:
	movl	nrPointers,arity			// nrPointers == 0
	testl	%ecx,%ecx
	je  	copy_unboxed_args			// no boxed arguments in rest arguments

	pushl	nrPointers
	pushl	nrUnboxed
	
	_copy_argument_block_nodeP nrUnboxed copy_boxed_args1 copy_boxed_args2
	
	popl	nrUnboxed
	popl	nrPointers
	
copy_unboxed_args:
	movl	nrUnboxed,arity				// nrUnboxed == 0
	testl	%ecx,%ecx
	je  	copy_first_argument			// no unboxed arguments in rest arguments 

	subl	arity,free
	js 	garbage_collection
	
	cld
	rep
	movsl						// copy boxed arguments
	
copy_first_argument:
	popl	nrPointers
#define t_heapP descP
	popl	t_heapP					// first argument nodeP 
	
	cmpl	$0,nrPointers 
	jne	copy_first_boxed_argument
	
#define temp nodeP
	movl	(stringP),temp				// first argument is unboxed
	movl	temp,(t_heapP)
#undef temp
	
	addl	$4,stringP
	jmp	copy_next_node
	
copy_first_boxed_argument:
	_pushl1 t_heapP //copy_first_boxed_argument1
	
	jmp	copy_next_node
	
	/* copy_record_with_two_cells */
copy_record_with_two_cells:
	movl	$8,recordSize
	
	cmpl	$1,nrPointers
	ja	copy_record_with_cells_boxed		
	
#define value arity
	movl	(stringP),value
	addl	$4,stringP
	movl	value,4(heapP)				// store unboxed in second argument nodeP
#undef value
	jmp	copy_record_with_one_cell

copy_record_with_cells_boxed:
#define temp arity
	leal	4(heapP),temp
	_pushl1	temp //copy_record_with_cells_boxed1 	// push nodeP of 2nd argument
#undef temp
	
	/*
	** copy_record_with_one_cell
	*/
copy_record_with_one_cell:
	cmpl	$0,nrPointers
	jne	copy_record_with_one_cell_boxed
	
#define temp arity
	movl	(stringP),temp				// get unboxed argument
	addl	$4,stringP
	
	movl	temp,(heapP)				// store it
#undef temp

	addl	recordSize,heapP
	jmp	copy_next_node
	
copy_record_with_one_cell_boxed:
	_pushl1 heapP //copy_record_with_one_cell_boxed1
	
	addl	recordSize,heapP	
	jmp	copy_next_node
#undef nrUnboxed
#undef nrPointers

	/* copy_string */
#define length arity
copy_string:
	movl	(stringP),length
	
	cmpl	$0,length
	je	copy_zero_length_string
	
	addl	$7,length
	shrl	$2,length
	
	_copy_block_to_heapP 
	
	jmp	copy_next_node
	
copy_zero_length_string:
	subl	$1,free
	js	garbage_collection
	
	addl	$4,stringP
	
	movl	length,(heapP)
	addl	$4,heapP
	
	jmp	copy_next_node
#undef length	

	/* copy_array */
#define size arity
copy_array:
	subl	$2,free
	js 	garbage_collection

	movl	4(stringP),descP			// copy descP

#ifdef PREFIX_PER_NODE
	cmpl	$0,descP		
	je	copy_array2
	
	cmpl	last_restored_descP,stringP		// stringP <= last_restored_descP
	jbe 	copy_array2
	
#define t0 size
	_decode_descriptor t0 l850_non_d_prefix l851_end_decode_descriptor
#undef t0

copy_array2:
	movl	descP,4(heapP)	
#endif
	
	movl	(stringP),size				// copy size
	movl	size,(heapP)
	
#ifdef PREFIX_PER_NODE
#else
	movl	descP,4(heapP)
#endif
	
	addl	$8,heapP
	addl	$8,stringP				// stringP += 8
	
	cmpl	$0,size
	je	copy_next_node
	
	cmpl	$0,descP
	je	copy_array_pointers
	cmpl	$INT+2,descP
	je	copy_int_array				// copy unboxed array of integers/chars
	cmpl	$BOOL+2,descP
	je	copy_bool_array
	cmpl	$REAL+2,descP
	je	copy_real_array

	/* copy_record_array */
#define	nrBoxedFields nodeP
copy_record_array:
	movzwl	(descP),nrBoxedFields			// #boxed fields
	cmpl	$0,nrBoxedFields
	je 	copy_boxed_record_array

	pushl 	nodeP
	
	pushl	stackP
	mull	size
	popl	stackP					// %eax = #boxed fields * array size
	
	pushl	size
	movl	%eax,size
	
#define temp nodeP
	N_reserve_stack_block temp // copy_record_array1 copy_record_array2
#undef temp

	popl	size
	popl	nodeP

#define s_UnboxedFields descP	
	movzwl	-2(descP),s_UnboxedFields		// s_UnboxedFields = total size of record (array element)
	subl	$256,s_UnboxedFields
	subl	nrBoxedFields,s_UnboxedFields		// s_UnboxedFields = size of unboxed part of record
	
	pushl	stackP					// backup stackP
copy_record_fields:
	pushl	size

copy_boxed_record_fields:
	movl	nrBoxedFields,arity			// arity = # boxed fields to copy
	
	_copy_argument_block_without_reserve copy_record_array3
	
copy_unboxed_record_fields:
	movl	s_UnboxedFields,arity			// arity = size of unboxed fields to copy
	
	_copy_block_to_heapP
		
	popl	size
	decl	%ecx
	jne 	copy_record_fields
	
	popl	stackP					// restore stackP
	
	jmp	copy_next_node
#undef s_UnboxedFields

#define s_UnboxedFields nodeP	
copy_boxed_record_array:
	movzwl	-2(descP),s_UnboxedFields		// s_UnboxedFields = total size of record (array element)
	subl	$256,s_UnboxedFields
	
	pushl	stackP
	mull	size
	movl	%eax,size
	popl	stackP
	
	_copy_block_to_heapP
	
	jmp	copy_next_node
#undef s_UnboxedFields
	
copy_bool_array:
	addl	$3,size
	shrl	$2,size
	
copy_int_array:
	_copy_block_to_heapP
	
	jmp	copy_next_node
	
copy_real_array:
	shll	$1,size
	
	jmp	copy_int_array
	
copy_array_pointers:
	_copy_argument_block_nodeP descP copy_array_pointers1 copy_array_pointers2
	
	jmp	copy_next_node
		
copy_build_lazy_block_closure:
	// (%esi):	node index
	// 4(%esi): lazy dynamic index (disk; should be converted)
#define temp %eax
	// closure-node:
	// (%edi)	node_index
	
#ifdef SHARING_ACROSS_CONVERSIONS		// vanaf 8(%edi) -4
	// 4(%edi)	lazy dynamic_index
	// 8(%edi)	28(%edi) // graph_pointers
	//
	// INT-node (node_index):
	// 12(%edi)  INT
	// 16(%edi) node_index
	//
	// INT-node (lazy dynamic index):
	// 20(%edi)	INT
	// 24(%edi) lazy dynamic index
	//
	// ARRAY-node (because closure is boxed)
	// 28(%edi)	ARRAY
	// 32(%edi)	graph_pointers
	// 36(%edi) ...
	
	subl	$10,free						// closure_nde args(=4) + 2 INT-nodes(=4)
#else
	// 4(%edi)	lazy dynamic_index
	//
	// INT-node (node_index):
	// 8(%edi)  INT
	// 12(%edi) node_index
	//
	// INT-node (lazy dynamic index):
	// 16(%edi)	INT
	// 20(%edi) lazy dynamic index
	subl	$6,free						// closure_nde args + 2 INT-nodes
#endif
	js		garbage_collection

	movl	BUILD_LAZY_DYNAMIC_ON_DISK__NODE_INDEX(stringP),temp
#ifdef SHARING_ACROSS_CONVERSIONS
	movl	temp,16(heapP)
#else
	movl	temp,12(heapP)
#endif
	
	movl	BUILD_LAZY_DYNAMIC_ON_DISK__DYNAMIC_ID(stringP),temp
	
	// disk to runtime lazy dynamic id ...
#define temp2 %ebx
	movl	gdi_backup,temp2
	movl	8(temp2),temp2
	movl	GDI_DISK_TO_RT_DYNAMIC_INDICES (temp2),temp2

	leal	12(temp2,temp,4),temp		// temp2 = base of gdi_disk_to_rt_dynamic_indices
	movl	(temp),temp	
#undef temp2
	// ... disk to runtime lazy dynamic id
	
#ifdef SHARING_ACROSS_CONVERSIONS
	movl	temp,24(heapP)
#else
	movl	temp,20(heapP)
#endif
	
#ifdef SHARING_ACROSS_CONVERSIONS
	leal	12(heapP),temp
#else
	leal	8(heapP),temp
#endif
	movl	temp,(heapP)

#ifdef SHARING_ACROSS_CONVERSIONS
	leal	20(heapP),temp				// lazy_dynamic_index
	movl	temp,4(heapP)
	
	leal	28(heapP),temp
	movl	temp,8(heapP)				// ptr to ARRAY-node
#else
	leal	16(heapP),temp
	movl	temp,4(heapP)
#endif
	
	movl	$INT+2,temp
#ifdef SHARING_ACROSS_CONVERSIONS
	movl	temp,12(heapP)
	movl	temp,20(heapP)	
#else
	movl	temp,8(heapP)
	movl	temp,16(heapP)	
#endif

	addl	$ BUILD_LAZY_DYNAMIC_ON_DISK__BSIZE,stringP
	
#ifdef SHARING_ACROSS_CONVERSIONS
	// create ARRAY node
	movl	$ARRAY+2,temp
	movl	temp,28(heapP)

	leal	32(heapP),temp
	_pushl1	temp							// put here a ref to graph pointers on stack

	addl	$40,heapP
#else	
	addl	$24,heapP
#endif

	jmp		copy_next_node
#undef temp

	/* copy_closure	*/
	// moet er niet ook een pointer in stringP opgeslagen worden die wijst
	// naar de aangemaakte knoop?
copy_closure:	
	movl	descP,(heapP)				// store descriptor pointer
	movl	heapP,(root_nodeP)			// make root node point to closure
	movl	heapP,-4(stringP)			// store pointer for indirections
	addl	$4,heapP				// heapP += 4
	
	movl	-4(descP),arity				// get closure arity
	
	cmpl	$ CLEAN_nbuild_lazy_block,descP
	je	 	copy_build_lazy_block_closure

	cmpl	$0,arity
	jl	copy_closure_arity_1			// arity < 0, then copy closure of arity 1
	
	je	copy_closure_arity_0			
	cmpl	$1,arity
	je 	copy_closure_arity_1
	
	cmpl	$256,arity
	jae	copy_unboxed_closure
	
	_copy_argument_block_nodeP descP copy_clsoure1 copy_closure2
	
	jmp	copy_next_node

copy_closure_arity_0:
	subl	$2,free
	js	garbage_collection
	
	addl	$8,heapP
	jmp	copy_next_node
	
copy_closure_arity_1:
	subl	$2,free
	js 	garbage_collection

	_pushl1	heapP //copy_closure_arity2

	addl	$8,heapP
	jmp	copy_next_node
	
#define nrUnboxed	nodeP
#define nrUnboxedL	%al
#define nrPointers	arity
#define nrPointersH	%ch
#define temp		%ebx
copy_unboxed_closure:
	xorl	nrUnboxed,nrUnboxed
	movb	nrPointersH,nrUnboxedL
	andl	$255,arity
	
	cmpl	$0,arity	
	je	copy_unboxed_closure_arity0
	cmpl	$1,arity
	je 	copy_unboxed_closure_arity1
	
	sub	nrUnboxed,arity				// arity = # boxed arguments
		
	pushl	nrUnboxed

	testl	%ecx,%ecx
	je  	copy_unboxed_closure_heapP
	
	_copy_argument_block_nodeP descP copy_unboxed_closure1 copy_unboxed_closure2
	
copy_unboxed_closure_heapP:
	popl	arity
	
	_copy_block_to_heapP

	jmp	copy_next_node
	
copy_unboxed_closure_arity0:
	subl	$2,free
	js	garbage_collection
	
	addl	$8,heapP
	jmp	copy_next_node
	
copy_unboxed_closure_arity1:
	subl	$2,free
	js	garbage_collection
	
	cmpl	$0,nrUnboxed
	jne	copy_unboxed_closure_arity1_value

	/*
	** komt hier nooit dan zou het een record geweest
	** moeten zijn
	*/
	_pushl1 heapP //copy_unboxed_closure_arity1_1
	
	addl	$8,heapP
	jmp	copy_next_node
	
copy_unboxed_closure_arity1_value:
	movl	(stringP),temp				// get value
	movl	temp,(heapP)				// store it
	
	
	addl	$4,stringP
	addl	$8,heapP
	jmp	copy_next_node
#undef nrUnboxed
#undef nrUnboxedL
#undef nrPointers
#undef nrPointersH
#undef temp

	/* 2nd pass; copy_done */
copy_done:
	ret

	/* garbage_collection */

#define stringP2 nodeP
garbage_collection:
	movl	graph_string_backup,stringP2
	
	// statement below is replacing WAS (also below) because the string
	// starts just after the STRING-descp and its length
	leal	8(stringP2),stringP2
	addl	stringP_offset,stringP2
	pushl	free
	
	// stringP points to the last descriptor which has been converted to its pointer.
restore_next_descP:
	cmpl	stringP,stringP2			// stringP2 > stringP
	jae 	restore_done 				//start_over
	
#define indirection descP
	movl	(stringP2),indirection			// get description pointer or indirection offset within string
	
	testl	$1,indirection				// indirection?
	jne		skip_indirection			// yes, skip indirection
	
	movl	(indirection),descP			// use indirection to get descriptor pointer
	
	movl	descP,(stringP2)			// restore descriptor pointer
	addl	$4,stringP2				// advance in string
	
	testl	$2,descP				// in hnf?
	je	restore_closure				// no, restore closure
#undef indirection
	
	cmpl	$INT+2,descP
	je 		skip_integer
	cmpl	$CHAR+2,descP
	je		skip_integer
	cmpl	$BOOL+2,descP
	je		skip_integer
	cmpl	$REAL+2,descP
	je 		skip_real
	cmpl	$__STRING__+2,descP
	je 		skip_string
	cmpl	$__ARRAY__+2,descP
	je		skip_array
	
	movzwl	-2(descP),arity
	subl	$256,arity				// arity < 256, only boxed arguments which take no string space
	jl		restore_next_descP
	
	/* restore_boxed_record */

#define nrPointers free
#define nrUnboxed arity
restore_boxed_record:
	movzwl	(descP),nrPointers
	subl	nrPointers,nrUnboxed			// nrUnboxed = arity - nrPointers
	
	leal	(stringP2,nrUnboxed,4),stringP2		// stringP2 += nrUnboxed * 4 
	jmp		restore_next_descP
#undef nrPointers
#undef nrUnboxed

restore_build_lazy_block:
	addl	$ BUILD_LAZY_DYNAMIC_ON_DISK__BSIZE,stringP2
	jmp		restore_next_descP

	/* restore_closure */	
restore_closure:	
	cmpl	$ CLEAN_nbuild_lazy_block,descP
	je 		restore_build_lazy_block

	movl	-4(descP),arity
	cmpl	$256,arity				// arity < 256
	jb		restore_next_descP			
	
#define nrUnboxed descP
#define nrUnboxedL %bl
#define nrPointers arity
#define nrPointersH %ch
	xorl	nrUnboxed,nrUnboxed
	movb	nrPointersH,nrUnboxedL			// nrUnboxed = # unboxed arguments
	
	leal	(stringP2,nrUnboxed,4),stringP2		// stringP2 += nrUnboxed * 4 
	jmp		restore_next_descP
#undef nrUnboxed
#undef nrUnboxedL
#undef nrPointers
#undef nrPointersH

	/* skip_integer/skip_indirection */
skip_integer:
skip_indirection:
	addl	$4,stringP2				// skip integer
	jmp		restore_next_descP
	
	/* skip_real */
skip_real:
	addl	$8,stringP2				// skip real (two longs)
	jmp		restore_next_descP
	
	/* skip_string */
#define size arity
skip_string:
	movl	(stringP2),size				// get string size
	addl	$7,size
	shrl	$2,size					// round up to allocated longs
	
	leal	(stringP2,size,4),stringP2		// stringP2 = stringP2 + (# longs) * 4, skip string
	jmp		restore_next_descP
#undef size

	/* skip_array */
#define size arity
skip_array:	
	movl	(stringP2),size				// get size
	movl	4(stringP2),descP			// get descP

	addl	$8,stringP2				// stringP2 += 8
	
	cmpl	$0,size					// size == 0
	je		restore_next_descP			// nothing to skip
	
	cmpl	$0,descP
	je	restore_next_descP			// only boxed arguments, nothing to skip
	cmpl	$INT+2,descP
	je	skip_int_array
	cmpl	$BOOL+2,descP
	je	skip_bool_array
	cmpl	$REAL+2,descP
	je	skip_real_array
	
	/* skip_record_array */
#define nrPointers free
	movzwl	(descP),nrPointers			// nrPointers = # boxed arguments
	pushl	nodeP
	
#define nrUnboxed nodeP
	movzwl	-2(descP),nrUnboxed			// nrUnboxed = total size of record (array element)
	subl	$256,nrUnboxed
	subl	nrPointers,nrUnboxed			// nrUnboxed = size of unboxed part of record
		
	mull	size
	movl	%eax,size
	
	popl	nodeP
	
	leal	(stringP2,size,4),stringP2		// stringP2 += (nrUnboxed * size) * 4
	
	jmp	restore_next_descP
#undef nrUnboxed
#undef nrPointers
		
skip_int_array:
	leal	(stringP2,size,4),stringP2		// stringP2 += size * 4
	jmp	restore_next_descP
	
skip_bool_array:
	addl	$3,size
	shrl	$2,size
	
	leal	(stringP2,size,4),stringP2		// stringP2 = stringP2 + (# longs) * 4
	jmp	restore_next_descP
	
skip_real_array:
	leal	(stringP2,size,8),stringP2		// stringP2 += size * 8
	jmp	restore_next_descP
#undef size

#undef stringP2

restore_done:
	popl	free

	/* start_over */

start_over:	
	movl	graph_string_backup,%ecx
	
#define temp nodeP
	movl	graph_string_length,temp		// restore length of string encoding the graph
	movl	temp,4(%ecx)
#undef temp
	
	movl	esp_backup,%esp				// restore B/C-stack
	movl	esi_backup,%esi
	
	movl	old_heap_pointer,heapP			// restore heap pointer
		
#define usedCells nodeP
	movl	initfree,usedCells
	subl	free,usedCells				// usedCells = # required cells
	
	leal	-32(heapP,usedCells,4),free		// compute new heap pointer
#undef usedCells

	movl	descriptor_address_table_backup,%edx
	movl	graph_string_backup,%ecx

	// compute offset of last_restored_descP from the encoded graph
	subl	%ecx,last_restored_descP	// last_restored_descP (offset) = last_restored_descP (address) - old %ecx (address of second graph)

#ifdef GDI
	movl	gdi_backup,gdi
#endif

	call	collect_2l
	
#ifdef GDI
#define temp %ebx
	movl	GDI_GRAPH(gdi),temp
	addl	temp,last_restored_descP
#else
	addl	%ecx,last_restored_descP
#endif

#define temp nodeP
	movl	-4(%esi),%eax
	movl	%eax,gdi_backup
#undef temp
	jmp		copy__string__to__graph
