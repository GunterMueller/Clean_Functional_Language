
	// _create_entry_node
	//
	// precondition:
	// ( - nodeP is the going-to-be entry node in which the SN-pointer (in descP) is replaced by an
	//   EN-pointer. FALSE )
	// - descP is the SN-pointer (see above). To be computed as follows ((nodeP) - 1) (pseudo assembler
	//   notation)
	// - ML(external_ref) is the NodeIndex which has been generated by _make_reference. This pointer
	//   is stored for subsequent references to the node.
	//
	// postcondition:
	// - an entry node has been made. The following fields have been filled: EN_DESCP, EN_COLOUR,
	//   EN_NODE_INDEX. The fields EN_BLOCK_OFFSET and EN_NODE have *not* been filled.
	// - registers: descP has been destroyed. NodeP is preserved. %ecx contains EN-pointer.
	.macro ML(_create_entry_node)
#define entry_node %ecx
	call	MAKE_ID_FEN(lb_alloc_entry)		// alloc entry node

	pushl	nodeP
#define temp nodeP
	movl	SN_DESCP(descP),temp			
	movl	temp,EN_DESCP(entry_node)		// copy descP
	
	movl	SN_COLOUR(descP),temp
	orl		$ ENSN_COLOUR_SET_EN_BIT,temp				
	movl	temp,EN_COLOUR(entry_node)		// mark as entry node
	
	movl	ML(external_ref),temp
	movl	temp,EN_NODE_INDEX(entry_node)	// copy external reference	
#undef temp
	popl	nodeP
#undef entry_node
	.endm

	.macro ML(_build_external_reference)
	// IN:
	// (- descP contains pointer to *shared nodes* array)
	// - %ecx contains node_colour (node_colour comes from the shared nodes array)
	// OUT:
	// - %ecx (was: descP) contains the external reference to be encoded pointing to that node
	//
	// nodeP, descP are not changed, only %ecx is changed
	//
	// An external reference look like:
	// word (1234):
	//		- 12 entry node index
	//		- 34 except for two least signficant bits which are zero; block index
#define ct_entry %ecx
#define temp nodeP
	pushl	nodeP
	pushl	descP
	
	call	MAKE_ID_FCT(lb_index_of_entry)			// get colour table entry for node_colour
	
	movl	(ct_entry),temp							// temp = ct entry
	cmpl	$0,temp									// temp <> ct_entry i.e. need not initialise
	jne 	0f
	
	// initialize and allocate first external reference
	movl	block_n,temp							// get new block number
	movl	temp,descP								// new block number is also first reference to entry node
		
	orl		$0x00010000,temp						// increase entry index to point to the next free entry index
	movl	temp,(ct_entry)							// store it
	
	movl	$ block_n,temp
	addl	$ BLOCK_INCREASEMENT,(temp)				// increase to next available block
	
	// added:
	movl	descP,%ecx
	jmp		1f
		
	// allocate entry index
0:	
	pushl	temp									// backup external reference

	// decode, increase and encode the entry index counter
	shrl	$16,temp
	incl	temp									// increase entry index counter
	shll	$16,temp
	
	andl	$0x0000ffff,(ct_entry)
	orl		temp,(ct_entry) 
#undef ct_entry

	popl	%ecx	//descP							// restore external reference
1:
	popl	descP
	popl	nodeP
#undef temp
	.endm
	
	.data
	.align	4
ML(external_ref):
	.long 	0
	
	.text