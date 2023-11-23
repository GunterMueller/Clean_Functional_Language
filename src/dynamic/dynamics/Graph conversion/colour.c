
#include "globals.h"
#include "global_registers.h"
#include "gts_stack.c"

	.data
	.align	4
previous_colour_combinations:
	.long 	0

#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3
#define LB_ENTRY_BSIZE		4			// entry size = 2 ^ LB_ENTRY_BSIZE_EXP (in bytes)
#define LB_ENTRY_BSIZE_EXP	2			
#define MAKE_ID(x)			x##_CT
#define MAKE_ID_UCT(x)		x##_unfixed_CT
#define MAKE_ID_FCT(x)		x##_fixed_CT
#define BOTH_FIXEDNESS
#define MAKE_ID_CT(x)		x##_CT

#include "LinkedBlock.c"

// Format: CT
// During colouring:
// word	0: colour table index i.e. colour combination number
//
// During copying:
// word 0 (1234):
//			- 12 is the entry counter initialized at zero
//			- 34 without two least significant bits the block number
//			- the rest is reserved

	.text
	.align	4
init_colour_table:
	movl	$ 0,previous_colour_combinations
	call	MAKE_ID_UCT(lb_init)

// wordt aangeroepen vlak na begin maar de root is al veranderd.
	pushl	%ecx
	call	MAKE_ID_UCT(lb_alloc_entry)
	movl	$ 0,(%ecx)					// reset colour entry, array has size 1
	popl	%ecx
	
	ret
