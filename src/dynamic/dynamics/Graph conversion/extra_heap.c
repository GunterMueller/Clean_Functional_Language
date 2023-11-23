
#include "globals.h"
#include "global_registers.h"
#include "gts_stack.c"

// ------------------------------------------------------------------------------------------	
// %ecx = contains string

#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3
#define LB_ENTRY_BSIZE		8			// entry size = 2 ^ LB_ENTRY_BSIZE_EXP (in bytes)
#define LB_ENTRY_BSIZE_EXP	3			
#define MAKE_ID(x)			x##_SN					// data
#define MAKE_ID_NSN(x)		x##_fixed_SN			// no stack
#define MAKE_ID_USN(x)		x##_unfixed_SN			// unfixed stack
#define MAKE_ID_FSN(x)		x##_fixed_SN			// fixed stack
#define BOTH_FIXEDNESS								// used in both unfixed and fixed contexts
#define MAKE_ID_SN(x)		x##_SN

#include "LinkedBlock.c"

// Shared nodes array
#define SN_DESCP			0
#define SN_COLOUR			4

#define TOPLEVEL_COLOUR		0

// Format: SN
// word 0:	descP
// word 1 (1234)
//			- highest significant bit of byte 3: 0 = means normal node (during colouring)
//												 1 = EN-node see its format in graph_to_string.c
//			- rest of 34: colour table index i.e. colour combination number
abort:
	movl	esp_backup,%esp
	movl	old_heap_pointer,%edi
	popl	%esi
	
	call	print__string__
	jmp		halt
	
	.data
	.align	4
lb_index_of_entry_internal_error_string:
	.long	__STRING__+2
	.long	57
	.ascii	"lb_index_of_entry_internal_error_string: (internal error)"
	//       012345678901234567890123456789012345678901234567890123456
	.byte 	0
	.byte 	0
	.byte 	0
	.byte	0
