// can be copied and pasted back in graph_to_string.c if wanted
#define ML(x)				x##_mark_en_nodes
#define ENTRY_LABEL			mark_en_nodes
#define ENTRY_LABEL_NODEP	mark_en_nodes_from_nodeP
#define EXIT_LABEL			mark_en_nodes_end

#define FIXED_STACK

#define DETERMINE_ENTRY_NODES_PASS

	// the undo handler for colouring nodes is valid
	// collect EN-nodes ...

mark_en_nodes_loop:
	jmp		ENTRY_LABEL_NODEP
#undef temp2 

#include "gts_delete.c"

mark_en_nodes_end:
#undef EXIT_LABEL
	// finished with one colour for now, see if there are still nodes left
	cmpl	esp_backup,%esp
	je		mark_en_nodes_finished

	popl	nodeP
	movl	(nodeP),descP

#define new_current_colour %ecx
	decl	descP
	movl	SN_COLOUR(descP),new_current_colour
	andl	$ ENSN_COLOUR_GET_COLOUR,new_current_colour
	movl	new_current_colour,current_colour
#undef new_current_colour

	jmp		mark_en_nodes_loop
	// ... collect EN-nodes

	// list EN-nodes of a block ...
collect_en_nodes_within_same_block:
#define entry_node %eax
	movl	%ecx,entry_node							// current EN-node
		
#define last %ecx
	movl	$0, EN_NODE_LIST(entry_node)
	
#ifdef EXTRAATJE
	movl	EN_COLOUR(entry_node),%ebx
	andl	$ ENSN_COLOUR_EN_BIT_AND_COLOUR,%ebx
	movl	%ebx,EN_COLOUR(entry_node)
#endif

	movl	EN_COLOUR(entry_node),last		
	andl	$ ENSN_COLOUR_GET_COLOUR,last		
	
	leal	(heapP,last,4),last
	
	cmpl	$0,(last)
	jne 	append_en_node_for_non_empty_list

	// keep pointer to first EN-node in a linked list of EN-nodes
#define temp %ebx
#define temp2 %edx
	pushl	temp2
	
	movl	en_list_base_address,temp2

	movl	counter,temp
	movl	entry_node,(temp2,temp,4)
	
	incl	counter
	
	popl	temp2
#undef temp2
#undef temp

	// change colour table entry to hold address of tail
#define temp %ebx
	lea		EN_NODE_LIST(entry_node),temp
	movl	temp,(last)									
#undef temp 
	ret

append_en_node_for_non_empty_list:
	// modify previous entry node to point to the current one
#define temp %ebx
	movl	(last),temp								// temp = ptr to EN_NODE_LIST(previous_entry_node)
	movl	entry_node,(temp)						
#undef temp

	//
#define temp %ebx
	leal	EN_NODE_LIST(entry_node),temp
	movl	temp,(last)
	ret
#undef temp
#undef last

#undef entry_node
	// ... list EN-nodes of a block

	.align 4
	.data
mark_en_current_en_node:
	.long	0
mark_en_counter:
	.long	0
mark_en_block:
	.long	0
mark_en_tail:
	.long 	0
	
	// --------------------------------------------------------------------------------------
	// PASS 3: block copying
	.align 	4	
	.text
mark_en_nodes_finished:
// block copying
#ifdef DYNAMIC_STRINGS
 	call	MAKE_ID_NDS(lb_init)
#endif
	
	movl	$ 0, counter
	movl	block_n,%ecx								// block_n = amount of blocks * 4

	call	alloc_from_extra_heap_fixed					// allocate array of blocks
	movl	%ecx,en_list_base_address					// ptr to array base of a block i.e. non-empty set of EN-nodes 

	// partitionate entry nodes in blocks ...
#define size1 %ecx
	call	MAKE_ID_FCT(lb_size)
	cmpl	size1,free
	js		undo_handler
	
#define ptr	%eax
#define end %ebx
	leal	(heapP,size1,4),end
	movl	heapP,ptr
	
clear_loop:
	cmpl	ptr,end
	je		clearing_done
	movl	$0,(ptr)
	addl	$4,ptr
	jmp		clear_loop
	
clearing_done:
#undef ptr
#undef end

#undef size1
	movl	$ collect_en_nodes_within_same_block,%ecx
	call	MAKE_ID_FEN(lb_map_array)
	
	// ... partitionate entry nodes in blocks
	
//	movl	$ restore_ct_table,%ecx
//	call	MAKE_ID_FEN(lb_map_array)
	
	_set_undo_handler $undo_copying
	
	movl	heapP,graph_start
			
	// copy loop ...
#define temp %ecx
	movl	block_n,temp
	shrl	$2,temp
	movl	temp,mark_en_block
#undef temp

#define counter %ecx
	movl	$-1,counter

mark_en_blocks:
	incl	counter

	cmpl	mark_en_block,counter
	je 		mark_en_nodes_copied
	
	movl	counter,mark_en_counter
	
#define en_node counter
	shll	$2,en_node
	addl	en_list_base_address,en_node				// ptr to ptr to EN-node
	movl	(en_node),en_node							// ptr to current en_node 					

#define new_current_colour %eax
	movl	-1(en_node),new_current_colour
	movl	SN_COLOUR(en_node),new_current_colour
	andl	$ ENSN_COLOUR_GET_COLOUR,new_current_colour
	movl	new_current_colour,current_colour
#undef new_current_colour

	movl	heapP,old_heapP								// backup start of block
	
mark_en_copy2:
#ifdef EXTRAATJE
# define temp %eax
	movl	SN_COLOUR(en_node),temp							// get colour of node

	testl	$ ENSN_COLOUR_SET_EN_BIT,temp
	jnz 	aap2
aap3:
	int3
	jmp		aap3
aap2:
	testl	$ ENSN_COLOUR_ALREADY_VISITED_MASK,temp
 	jz		aap	
 
	jmp		block_copied
# undef temp

aap:
#endif

#define temp %eax
	movl	EN_NODE_LIST(en_node),temp						// set tail 
	movl	temp,mark_en_tail
#undef temp

#define ML(x)				x##__pcn22
#define ENTRY_LABEL			copy_next_node_pcn22
#define ENTRY_LABEL_NODEP	copy_next_node_in_nodeP
#define EXIT_LABEL			mark_en_exit

	movl	EN_NODEP(en_node),nodeP
	movl	nodeP,mark_en_current_en_node					// set current EN-node

#ifndef EXTRAATJE
# define temp %ebx
	movl	heapP,temp										// set EN-node offset
	subl	old_heap_pointer,temp
	
	movl	temp,EN_BLOCK_OFFSET(en_node)
	movl	nodeP,EN_NODE(en_node)							// also done in gts_delete (next pass)
# undef temp
#endif
	jmp		copy_next_node_in_nodeP

	// node in eax

#include "gts_copy.c"									// copy nodes

#undef COPY_PASS

mark_en_exit:
#undef EXIT_LABEL

#define temp %eax
	movl	mark_en_tail,en_node
	cmpl	$0,en_node
	jne 	mark_en_copy2
#undef temp
#undef en_node

block_copied:
#define newHeapP descP
	movl	heapP,newHeapP
	subl	old_heapP,newHeapP
#define block_size newHeapP
	pushl	block_size
	
	movl	current_colour,%ecx
	call	MAKE_ID_FCT(lb_index_of_entry)

#define block_info block_size	
	movl	(%ecx),block_info
	andl	$0x0000fffc,block_info

	call	MAKE_ID_FBI(lb_alloc_entry)
	movl	block_info,(%ecx)
	
	popl	block_size
	movl	block_size,BI_SIZE(%ecx)
#undef newHeapP
#undef block_size
#undef block_info	
	
	movl	mark_en_counter,counter
	jmp		mark_en_blocks
#undef counter

mark_en_nodes_copied:
	movl	MAKE_ID_EN(lb_root),%ebx

	jmp		copy_equally_coloured_nodes_finished

#undef EXIT_LABEL
