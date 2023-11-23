// This code must cleaned up.
// Walking the graph here isn't necessary once the encoded nodes can be identified
// from the string (by using a bitset).
#define EXTRAATJE1
// --------------------------------------------------------------------------------------------------
	.data
	.align 4
virtual_base_offset:
	.long	0
descriptor_address_table_base:
	.long	0
descP_backup:
	.long	0

n_bits:	
	.byte	/*   0-15  */	0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
	.byte	/*  16-31  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
	.byte	/*  32-47  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
	.byte	/*  48-63  */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/*  64-79  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
	.byte	/*  80-95  */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/*  96-111 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/* 112-127 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
	.byte	/* 128-143 */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
	.byte	/* 144-159 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/* 160-175 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/* 176-191 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
	.byte	/* 192-207 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6
	.byte	/* 208-223 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
	.byte	/* 224-239 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7
	.byte	/* 240-255 */	4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
	
	.align	4	

current_block_index:
	.long	0
current_block_index_word:
	.long 	0
current_block_index_bit:
	.long 	0
current_block_n_en_nodes:
	.long	0
tijdelijk:
	.long 	0
	
	.text

// loops over block infos
// computes offsets only for used descriptors and sets the current block in
// current_block_index.
adjust_offset_per_block:
	movl	$0,current_block_n_en_nodes				// count amount of entry nodes in a block
	pushl	%ecx									// backup BI-ptr

	// determine block index
#define block_index nodeP
	movl	(%ecx),block_index
	
	andl	$0x0000fffc,block_index
	shrl	$2,block_index							// convert block number to set index
	
	movl	block_index,current_block_index
		
	// compute proper word in set
#define temp descP
	movl	block_index,temp
	shrl	$5,temp
	movl	temp,current_block_index_word	
#undef temp

	// compute proper bit within that word
	andl	$31,block_index
	
	movl	block_index,%ecx					// %cl = number of bits to shift
#define temp descP
	movl	$1,temp								// make mask
	shll	%cl,temp
	movl	temp,current_block_index_bit
#undef temp
	
#undef block_index

	// initialize block
#define desc_prefix_entry descP

	// TODO:
	// - stackP should re-initialized for each stack. In this way routines executing
	//   between passes does not need to save it.
	pushl	stackP								
#define dus_p stackP
	movl	dus_start,dus_p
#ifdef STORE_USAGE_BIT_SET_SIZE
	leal	DUS_HEADER_BSIZE(dus_p),dus_p		// skip usage entry size
#endif
	movl	$4,virtual_base_offset				// initial virtual base offset

	// adjusting block 0
	// there is always at least one descriptor
adjust_offset_per_block_end_initialize_loop:
	movl	DUS_DESC_ADDRESS_ENTRY(dus_p),desc_prefix_entry
	// determine whether the descriptor is used by the current block
#define setP arity
	// later
	movl	DPT_DESCP_USAGE_SET_PTR(desc_prefix_entry),setP
	//	addl	current_block_index_word,setP		// compute proper word in set and 

#define temp nodeP
	movl	current_block_index_word,temp
	leal	(setP,temp,4),setP
#undef temp

	movl	DUS_SET(setP),setP						// load it (4 means first four characters)
	testl	current_block_index_bit,setP
	jz		adjust_offset_per_block_skip_descriptor
	
	// descriptor is used by block
#undef setP

	// identical with _adapt_encoded_graph ...	
#define temp nodeP
	movl	virtual_base_offset,temp			// set virtual base offset
	movl	temp,DPT_VIRTUAL_BASE(desc_prefix_entry)

#define temp2 arity
	movl	DPT_PREFIX_SET_AND_STRING_PTR(desc_prefix_entry),temp2

	andl	$0xff000000,temp2
	shrl	$24,temp2
	
	addl	$n_bits,temp2
	movzbl	(temp2),temp2						// bitset length
	
	leal	(temp,temp2,4),temp2				
	
	movl	temp2,virtual_base_offset
#undef temp2

#undef temp
	// ... identical with _adapt_encoded_graph

adjust_offset_per_block_skip_descriptor:
	addl	dus_entry_bsize,dus_p
	cmpl	dus_end,dus_p
	jb		adjust_offset_per_block_end_initialize_loop
# undef dus_p

	popl	stackP

adjust_offset_per_block_end_initialize:
	// The following is valid at this point:
	// - offsets of *used* descriptor have been computed
	// - current_block_index contains the block being adjusted
	//
	// block = piece of encoded graph
	//
	// Now all references to descriptors in the block have to
	// be adjusted.

	movl	$ adjust_offsets_in_EN_block,%ecx
	call	MAKE_ID_FEN(lb_map_array)

	popl	%ecx								// restore BI-ptr
#define temp nodeP
	movl 	current_block_n_en_nodes,temp
	movl	temp,BI_N_EN_NODES(%ecx)			// update BI
#undef temp		
	ret

// The conditions above must be valid. This routine partially adapts the
// block with which the EN-node is associated.		
adjust_offsets_in_EN_block:
#define en_node %ecx

#define en_block nodeP
	movl	EN_NODE_INDEX(en_node),en_block
	andl	$0x0000fffc,en_block
	shrl	$2,en_block							// convert block number to set index

	cmpl	current_block_index,en_block
	jne 	adjust_offsets_in_EN_block_share_prefixes_done

#ifdef DEBUG_ADJUSTING_OFFSETS
	save_regs 
	
	pushl	en_block	
	call	_w_print_int
	addl	$4,%esp

	pushl	$'\n'
	call	_w_print_char
	addl	$4,%esp

	restore_regs
#endif

#undef en_block
	incl	current_block_n_en_nodes			// count amount of entry nodes in the current block
	

#ifdef EXTRAATJE
	testl	$ ENSN_COLOUR_ALREADY_VISITED_MASK,SN_COLOUR(en_node)
	jz		8f														
	// en-node which has already visited (which belongs to current block)
	ret	
8:
#endif 
	// compute string offset for the EN-node
#define string_start nodeP
#define en_block_offset descP
	movl	old_heap_pointer,string_start
	
	movl	EN_BLOCK_OFFSET(en_node),en_block_offset
	
	leal	(string_start,en_block_offset),%esi
#undef string_start
#undef en_block_offset

	movl	EN_NODE(en_node),nodeP				// make EN-node root node
#undef en_node

	// start adjusting
	movl	heapP,descriptor_address_table_base	// to be removed (?)

	movl	(stringP),%ecx							// get encoded descP

	
	// determine descP of entry node
	movl	(nodeP),descP
	leal	-1(descP),descP
	pushl	(descP)
	
	jmp		adjust_offsets_in_EN_block_share_next_prefixes_skip_root_EN //adjust_offsets_in_EN_block_share_prefixes_in_nodeP

// -----------------
// An entry node has been found. If it belongs to another colour i.e. block as the current 
// colour i.e. current block, then it is external to the block being adjusted. 
// If both entries belong to the same colour i.e. block, then it is unknown if this pass
// can continue adjusting offsets. If the next address at which to adjust does not equal 
// the address at which the found entry node starts, then the remaining nodes can be 
// adjusted.
// If not and the stack is empty i.e. no more nodes to adjust then we have arrived at the
// true end of the subcomponent of the current entry. We can then safely quit the process.
// Otherwise the current subcomponent is interleaved with other components.
// At the moment is not quite clear for me if this can happen, but I detect it. A solution
// could be to change the copying algoritm to terminate copying a subcomponent if an entry
// node of the same colour is encountered. In this case an internal indirection is needed
// to refer to the other subcomponent. This has not been implemented yet.

adjust_offsets_in_EN_block_entry_node_found:
	// nodeP is an entry node
#define en_node descP
	movl	(nodeP),en_node
	decl	en_node									// undo EN-indirection
	
#define en_block_n arity	
	movl	EN_NODE_INDEX(en_node),en_block_n
	andl	$0x0000fffc,en_block_n 
	shrl	$2,en_block_n
	
	// test ..
	movl	$0,times
	// ... test
	
	cmpl	current_block_index,en_block_n			// equally coloured?
	jne		adjust_offsets_in_EN_block_share_next_prefixes	// no
	
#ifdef EXTRAATJE1
	testl	$ ENSN_COLOUR_ALREADY_VISITED_MASK,SN_COLOUR(en_node)
	jnz		adjust_offsets_in_EN_block_share_next_prefixes			// equally coloured but already visited

	
 	orl		$ ENSN_COLOUR_ALREADY_VISITED_MASK,SN_COLOUR(en_node)	// mark entry node as copied

//	movl	(en_node),descP

	movl	(stringP),%ecx							// get encoded descP
	pushl	(en_node)
	
	jmp		adjust_offsets_in_EN_block_share_next_prefixes_skip_root_EN
#endif 

	// determine whether to continue adjusting offsets for the current entry node
#define temp nodeP
	movl	EN_BLOCK_OFFSET(en_node),temp
	addl	old_heap_pointer,temp
	cmpl	temp,stringP									
	jne		adjust_offsets_in_EN_block_share_next_prefixes	// continue adjusting offsets
#undef temp
	_stack_empty adjust_offsets_in_EN_block_share_next_prefixes
	
#ifdef EXTRAATJE1
	int3
	movl	stackBottom,%edx	
	jmp			adjust_offsets_in_EN_block_share_prefixes_done
#endif

	movl	$ s_interleaved_subcomponents,%ecx
	jmp		abort
#undef en_block_n
#undef en_node

#ifdef BUILD_DESCRIPTOR_BITSET
set_descriptor_bit:
	pushl	nodeP
	pushl	descP
	pushl	%ecx
	
#define temp2 %ecx
	movl	stringP,temp2
	subl	graph_start,temp2					// temp2 = byte offset from graph_start

	shrl	$2,temp2							// temp2 = word offset from graph_start
	
#define word_address nodeP
	movl	temp2,word_address
	shrl	$5,word_address
	shll	$2,word_address
	
	addl	descriptor_bitset_start,word_address
	
	andl	$31,temp2							// index of bit to be set in that word
	
#define mask descP
	movl	$1,mask
	shll	%cl,mask
#undef temp2

	// update word
	orl		mask,(word_address)
#undef mask
#undef word_address	

	popl	%ecx
	popl	descP
	popl	nodeP
	ret
#endif 

	.data
times:
	.long 	0
	
	.text
	
adjust_offsets_in_EN_block_share_next_prefixes_skip_root_EN:
#ifdef BUILD_DESCRIPTOR_BITSET
	call	set_descriptor_bit
#endif
	jmp		adjust_offsets_in_EN_block_share_next_prefixes_skip_root_EN2

kk: 	
	int3
		
adjust_offsets_in_EN_block_share_next_prefixes:
	_try_popl nodeP adjust_offsets_in_EN_block_share_prefixes_done
	
	cmpl	$0,nodeP
	je		kk
	
adjust_offsets_in_EN_block_share_prefixes_in_nodeP:
#ifdef BUILD_DESCRIPTOR_BITSET
	call	set_descriptor_bit
#endif

	// pruning ... ; indirections; order is important
#define temp arity
	movl	(stringP),temp
	testl	$1,temp
	jne		adjust_offsets_in_EN_block_share_prefixes_indirection

	// entry_nodes
	testl	$1,(nodeP)
	jnz		adjust_offsets_in_EN_block_entry_node_found
	// ... pruning
	
	// no indirection or entry node
	movl	(nodeP),descP							// get descP
hack:
	pushl	descP
		
adjust_offsets_in_EN_block_share_next_prefixes_skip_root_EN2:
#undef temp

	// The test whether an offset has already been computed can be eliminated because
	// all offsets are precomputed.
#define ML(x)				x##_ao_en
#define ENTRY_LABEL			adjust_offsets_in_EN_block_share_next_prefixes
#define ENTRY_LABEL_NODEP	adjust_offsets_in_EN_block_share_prefixes_in_nodeP
#define EXIT_LABEL			adjust_offsets_in_EN_block_share_prefixes_done

#include "gts_adjust.c"

#undef EXIT_LABEL

adjust_offsets_in_EN_block_share_prefixes_done:
	ret
		
adjust_offsets_in_EN_block_share_prefixes_indirection:
	addl	$4,stringP
	jmp		adjust_offsets_in_EN_block_share_next_prefixes	
	
// -------------------------------------------------------------------------------------------------------
	
mark_EN_nodes_as_such:
#define en_node %ecx
#ifdef EXTRAATJE
	movl	EN_COLOUR(en_node),%ebx
	andl	$ ENSN_COLOUR_EN_BIT_AND_COLOUR,%ebx
	movl	%ebx,EN_COLOUR(en_node)
#endif

	movl	EN_NODE(en_node),nodeP				// get Entry Node
	
#define temp descP
	leal	1(%ecx),temp
	movl	temp,(nodeP)						// replace descriptor by indirection to Entry Node
#undef temp
	ret
#undef en_node

unmark_EN_nodes_as_such:
#define en_node %ecx
	movl	EN_NODE(en_node),nodeP
	
	movl	EN_DESCP(en_node),descP
	movl	descP,(nodeP)

	ret
#undef en_node
