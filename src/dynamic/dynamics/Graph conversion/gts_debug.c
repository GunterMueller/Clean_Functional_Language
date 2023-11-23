#ifndef GTS_DEBUG_C
#define GTS_DEBUG_C

	.macro save_regs
		pushl	%eax
		pushl	%ebx
		pushl	%ecx
		pushl	%edx
	.endm
	
	.macro restore_regs
		popl	%edx
		popl	%ecx
		popl	%ebx
		popl	%eax
	.endm
	
	.macro print_string
		save_regs
		call	_w_print_string
		addl	$4,%esp
		restore_regs
	.endm
	
	.macro print_int
		save_regs
		call	_w_print_int
		addl	$4,%esp
		restore_regs
	.endm

	.macro print_char
		save_regs
		call	_w_print_char
		addl	$4,%esp
		restore_regs
	.endm

/*
#define DEBUG_DETERMINATION_OF_EN_NODES
#define DEBUG_BLOCK_COPYING
#define DEBUG_ADJUSTING_OFFSETS
#define DEBUG_GC
#define DEBUG_DELETE_INDIRECTIONS
#define DEBUG_STARTUP
#define DEBUG_COLOURING
*/

# ifdef DEBUG_STARTUP
startup_str:
	.ascii "\n\nEncoding node at %edi: "
	.byte 0
startup_underline_str:
	.ascii "\n-------------------------------------------\n"
	.byte 0
startup_gc_retry:
	.ascii " (GC-RETRY)"
	.byte 0
# endif

# ifdef DEBUG_COLOURING
n_dynamics_str:
	.ascii "\ndynamics to be coloured: "
	.byte 0
# endif

	.data 
# ifdef DEBUG_DETERMINATION_OF_EN_NODES
colouring_str:
	.ascii "current colour is "
	.byte 0
colour_change_str:
	.ascii "colour change to "
	.byte 0
pass_determine_entry_nodes:
	.ascii "*START* PASS: Determining entry nodes\n"
	.byte 0
end_pass_determine_entry_nodes:
	.ascii "*END* PASS: Determining entry nodes\n"
	.byte 0
# endif

# ifdef DEBUG_BLOCK_COPYING
copying_block_str:
	.ascii "copy colour "
	.byte 0
entry_node_str:
	.ascii "  entry node "
	.byte 0
entry_node_block1:
	.ascii	" (block "
	.byte 0
entry_node_block2:
	.ascii ")   %edi: "
	.byte 0
entry_node_encoded_at:
	.ascii "          at %edi: "
	.byte 0
entry_node_already_encoded:
	.ascii "  (skipped because already encoded)"
	.byte 0
pass_block_copying:
	.ascii "*START* PASS: Block copying\n"
	.byte 0
end_pass_block_copying:
	.ascii "*END* PASS: Block copying\n"
	.byte 0
# endif 

# ifdef DEBUG_DELETE_INDIRECTIONS
pass_delete_indirections:
	.ascii	"*START* PASS: Delete indirections\n"
	.byte	0
end_pass_delete_indirections:
	.ascii "*END* PASS: Delete indirections\n"
	.byte 0	
# endif

# ifdef DEBUG_ADJUSTING_OFFSETS
adjust_block:
	.ascii "Adjusting block "
	.byte 0
virtual_offset:
	.ascii " virtual offset " 
	.byte 0

# endif

# ifdef DEBUG_GC
gc_message:
	.ascii "\n\nGARBAGE COLLECTION"
	.byte 0
# endif
	
	.text
	
#ifdef EXAMPLE
# ifdef DEBUG_DETERMINATION_OF_EN_NODES
	save_regs 
	
	pushl	$colouring_str
	call	_w_print_string
	addl	$4,%esp
	

	pushl	current_colour
	call	_w_print_int
	addl	$4,%esp

	pushl	$'\n'
	call	_w_print_char
	addl	$4,%esp

	restore_regs
# endif	
#endif 

#ifdef DEBUG_STRING_TO_GRAPH
building_block_i:
	.ascii	"Building block "
	.byte	0
#endif 
	
#endif