// gts_undo
//
// Undo handler in case garbage collection occurs.
#ifdef GTS_UNDO
# error "gts undo more than once included"
#endif

#define GTS_UNDO

	.align	4
	.data
current_undo:
	.long	0
	
	.macro _set_undo_handler undo_address
	movl	\undo_address,current_undo
	.endm
	
	.macro	_set_default_undo_handler
		_set_undo_handler	$garbage_collection2
	.endm

	.align	4
	.text

undo_handler:
	jmp		*(current_undo)
	
	// undos
	// -------------------------------------------------------------------------------------
undo_colouring:
	// To undo:
	// - descP of a node points to a descriptor
	// - descP of a node points to a SN(/EN)-node which points to a descriptor
	movl	stackBottom,stackP
	movl	esp_backup,%esp

	_set_undo_handler $undo_colouring_types

	movl	root_node,nodeP
	
	// restore top-level DynamicTemp node
	movl	(nodeP),descP
	decl	descP
	movl 	(descP),descP
	movl	descP,(nodeP)
	
	movl	4(nodeP),nodeP					// 1st argument of DynamicTemp	
	jmp		undo_sn_nodes_from_nodeP

undo_colouring_types:
	movl	stackBottom,stackP
	movl	esp_backup,%esp
	
	_set_default_undo_handler

	movl	root_node,nodeP
	movl	8(nodeP),nodeP					// 2nd arg of DynamicTemp
	jmp		undo_sn_nodes_from_nodeP
	
undo_sn_nodes_stack_empty:
	jmp		*(current_undo)

	// undo SN-pointers in nodes
undo_sn_nodes:
	_try_popl	nodeP undo_sn_nodes_stack_empty

undo_sn_nodes_from_nodeP:
	movl	(nodeP),descP
	andl	$0xfffffffe,descP

undo_sn_nodes_from_nodeP2:
	cmpl	heapP,descP
	jb		undo_sn_nodes					// descP < heapP
	cmpl	extraheapBottom,descP
	ja		undo_sn_nodes					// descP > extraheapBottom
	
	// SN node found
	movl	SN_DESCP(descP),descP
	movl	descP,(nodeP)

#define ML(x)				x##_undo_sn

	testl	$2,descP
	je		ML(resolve_closure_indirection)

#define ENTRY_LABEL			undo_sn_nodes
#define ENTRY_LABEL_NODEP	undo_sn_nodes_from_nodeP
#define FIXED_STACK

#include "gts_delete.c"

undo_copying:
	call	restore__Module_descriptors

	// reset pointers
	movl	stackBottom,stackP
	movl	esp_backup,%esp
	
	call	undo_copying2
	jmp		garbage_collection2

undo_copying2:
	// To undo:
	// - (nodeP) has bit#0 set. Two cases:
	//		1) (nodeP) < heapP i.e. an indirection via the encoded graph
	//		2) otherwise i.e. (nodeP) is a SN/EN-pointer
	// - ModuleIDs have been replaced by DiskIDs
	// - __Module- descriptors have been linked together

/*
	// reset pointers
	movl	stackBottom,stackP
	movl	esp_backup,%esp

	_set_default_undo_handler	
*/

	movl	root_node,nodeP
	
	jmp		undo_en_and_sn_nodes_from_nodeP
	
undo_en_and_sn_nodes:
	_try_popl	nodeP undo_copying_end		// in case an error between two passes

undo_en_and_sn_nodes_from_nodeP:
	
	movl	(nodeP),descP					// get descP	
	testl	$1,descP
	jz		undo_en_and_sn_nodes			// (nodeP) has already been replaced
	
	andl	$0xfffffffe,descP				// undo indirection
	
	cmpl	heapP,descP
	jae		undo_copying_single_indirection	// descP >= heapP i.e. single indirection
	movl	(descP),descP					// get at SN/EN-node
	
undo_copying_single_indirection:
	movl	SN_DESCP(descP),descP			// get real descP

undo_en_and_sn_nodes_node_restored:
	movl	descP,(nodeP)					// restore descP in node

#define ML(x)				x##_undo_en_sn

	testl	$2,descP
	je		ML(resolve_closure_indirection)

#define ENTRY_LABEL			undo_en_and_sn_nodes
#define ENTRY_LABEL_NODEP	undo_en_and_sn_nodes_from_nodeP
#define FIXED_STACK

#include "gts_delete.c"

undo_copying_end:
	ret
	
	// --------------------------------------------------------------------------------------
undo_descriptor_usage:
	// To undo:
	// - the indirections made by the copying pass by calling undo_copying2.
	// - the modified descriptors	
	// reset pointers
	movl	stackBottom,stackP

	movl	esp_backup,%esp

	// first undo descriptors (undo_copying might depend on that)	
	movl	$ undo_descriptor,%ecx
	call	MAKE_ID_FSN(lb_map_array)

	movl	$ 0,%ecx
	call	MAKE_ID_FEN(lb_index_of_entry)	// get top-level dynamic
	
	call	undo_descriptor

	// secondly remove indirections from graph
	call	undo_copying2					// undo indirections
	jmp		garbage_collection2
	
undo_descriptor:
#define sn_or_en_entry %ecx
	movl	SN_DESCP(sn_or_en_entry),descP	// get descriptor
	
	call	compute_label_name_ptr
#define desc_nameP source

#define temp descP
	movl	4(desc_nameP),temp
	testl	temp,temp
	jns		undo_descriptor_ok
	
	shll	$1,temp							// get pointer in descriptor set usage table
	
	movl	(temp),temp						// get backuped first four characters
		
	movl	temp,4(desc_nameP)				// restore them in the descriptor
#undef temp
#undef desc_nameP
undo_descriptor_ok:
	ret
	// --------------------------------------------------------------------------------------	

	.text
