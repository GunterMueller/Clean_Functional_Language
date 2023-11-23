
is_dynamic_in_list:
	movl	(%ecx),%ecx												// get ptr to stored Dynamic-node

#define ptr_to_dynamic			%ecx
#define ptr_to_searched_dynamic %eax
#define temp 					%ebx	
	movl	ptr_to_dynamic_to_be_added,ptr_to_searched_dynamic		// retrieve searched dynamic

	test	ptr_to_searched_dynamic,ptr_to_searched_dynamic
	je		is_dynamic_in_list_end

	movl	4(ptr_to_dynamic),temp									// compare 1st fields
	cmpl	temp,4(ptr_to_searched_dynamic)
	jne 	is_dynamic_in_list_end

	movl	8(ptr_to_dynamic),temp									// compare 2nd fields
	cmpl	temp,8(ptr_to_searched_dynamic)
	jne 	is_dynamic_in_list_end
	
	movl	$0,ptr_to_dynamic_to_be_added
	movl	ptr_to_dynamic,stored_ptr_to_dynamic
#undef temp
#undef ptr_to_dynamic

is_dynamic_in_list_end:	
	ret

/*
** Disadvantages:
** - equally nodes can have several entries in the shared nodes array.
**   A node is equal if:
**   1) the descPs exactly match
**	 2) the nodes have the same colour
**   (A hash-table could be used to search whether or not the array already
**   contains such an element. There is always the possibility that a node
**   has to be split because a colouring might change. If colours change a
**   lot the table grows rapidly. It is probably not a good solution.)
**   The current solution guarantees:
**	 - each node there is exactly one sn entry
**   - element descriptors of arrays are also entered
*/
visit_nodes:
	_try_popl nodeP visit_nodes_done

visit_nodes_from_nodeP:
	// nodeP contains the candidate node to colour
#define sh_entry %ebx
	movl	(nodeP),sh_entry							// (nodeP) is always an indirection
	
	testl 	$1,sh_entry									// test bit#0 for indirection					
	jne 	visit_nodes_with_indirection				// if set then copy the indirection
	
	call	MAKE_ID_USN(lb_alloc_entry)					// alloc for node and colour index
	movl	sh_entry,SN_DESCP(%ecx)						// store descP
	
	movl	$ TOPLEVEL_COLOUR,SN_COLOUR(%ecx)			// alloc node
	
	leal	1(%ecx),%ecx								// make an indirection into 
	movl	%ecx,(nodeP)								// shared nodes table
	
	// a dynamic?
	cmpl	$ CLEAN_rDynamicTemp+2,sh_entry
	jne		visit_nodes_update_sh_entry

	// A dynamic is the same iff the value and type-field are the same pointers.
	movl	nodeP,ptr_to_dynamic_to_be_added
	pushl	%ebx
	pushl	%ecx
	movl	$ is_dynamic_in_list,%ecx
	call	MAKE_ID_UDL(lb_map_array)
	popl	%ecx
	popl	%ebx
	cmpl	$0,ptr_to_dynamic_to_be_added
	je		visit_nodes_update_sh_entry

	// dynamic is unique within list, add it.
	movl	ptr_to_dynamic_to_be_added,nodeP
	
	pushl	%ecx
	
	call	MAKE_ID_UDL(lb_alloc_entry)					// alloc for dynamic
	movl	nodeP,(%ecx)

	popl	%ecx	

visit_nodes_update_sh_entry:
	movl	%ecx,sh_entry								// indirection to sh_entry
	decl	sh_entry

	movl	$ TOPLEVEL_COLOUR,%ecx						//
	jmp		visit_nodes_initial_colour

visit_nodes_with_indirection:
	decl	sh_entry									// undo indirection, sh_entry is ptr in shared node

#define node_colour %ecx
	movl	SN_COLOUR(sh_entry),node_colour				// get node colour

visit_nodes_initial_colour:
	cmpl	previous_colour_combinations,node_colour	// node_colour >= previous_colour_combinations
	jae		visit_nodes									// skip colouring the current node because it has already been visited

	// node_colour < previous_colour_combinations i.e. node has not yet been (re-)coloured
	call	MAKE_ID_UCT(lb_index_of_entry)
#undef node_colour

#define colour_entry	%ecx
	cmpl	$0,(colour_entry)							// get colour table index at node_colour of the colour table
	jne		visit_nodes_already_assigned_a_new_colour	// a new colour has already been assigned to the old colour
	
	pushl	sh_entry									// back up sh_entry
#define temp2 sh_entry
	pushl	colour_entry								// backup colour entry

	call	MAKE_ID_UCT(lb_size)						// get new colour to be allocated

	movl	%ecx,temp2									// temp2 contains new colour
	popl	colour_entry								// restore colour entry
	movl	temp2,(colour_entry)						// set new node colour in table by using colour_entry

	popl	temp2										// restore sh_entry
#undef temp2
	
	pushl	%ecx
	call	MAKE_ID_UCT(lb_alloc_entry)					// allocate new colour
	popl	%ecx
	
visit_nodes_already_assigned_a_new_colour:
#define temp2 %ecx
	movl	(colour_entry),temp2						// replace (old) node colour by new colour
	movl	temp2,SN_COLOUR(sh_entry)
	movl	temp2,array_colour
	
#undef temp2

#undef colour_entry
	// node has been recoloured, now its children are put on the stack
	
	movl	SN_DESCP(sh_entry),descP					// get descriptor pointer of node
	
#undef sh_entry

visit_nodes_push_args:
#define ML(x)				x##_vs
#define ENTRY_LABEL		visit_nodes
#define ENTRY_LABEL_NODEP	visit_nodes_from_nodeP
#define UNFIXED_STACK
#define COLOUR_PASS
	testl	$2,descP
	je		ML(resolve_closure_indirection)

#include "gts_delete.c"							// PASS1: COLOURING

visit_nodes_done:
	ret
