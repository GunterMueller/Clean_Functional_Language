// ------------------------------------------------------------------------------------------	
// Linked block implementation
/*	
	Interface:

	// User definable
#define N_LB_ENTRIES		8			// n entries = 2 ^ N_LB_ENTRIES_EXP
#define N_LB_ENTRIES_EXP	3

#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
#define LB_ENTRY_WSIZE		5			// entry size = 5 words (= 5 * 4 bytes)
#else
#define LB_ENTRY_BSIZE		4			// entry size = 2 ^ LB_ENTRY_BSIZE_EXP (in bytes) 
#define LB_ENTRY_BSIZE_EXP	2
#endif
			
#define MAKE_ID(x)			x##_Example

#include "LinkedBlock.c"

	Description:
	The above text creates a linked list of tables. Each table has N_LB_ENTRIES-entries.
	Each entry has size LB_ENTRY_BSIZE. The following routines are available:
	
	Variables:
	MAKE_ID(lb_root)			// ptr to root of list
	
	Subroutines:
	MAKE_ID(lb_init)			// initializes the linked block
	MAKE_ID(lb_alloc_entry)		// allocates entry, OUT: %ecx ptr to newly created entry
	MAKE_ID(lb_index_of_entry)	// gets ptr to indexed entry, IN: %ecx valid zero based index, OUT: %ecx ptr to entry
	MAKE_ID(lb_size)			// computes array size, OUT: %ecx array size
	MAKE_ID(lb_map_array)		// maps on array, IN: %ecx address of map function
*/

#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
# ifdef LB_ENTRY_BSIZE
#  error "LinkedBlock: internal error"
# endif
# ifdef LB_ENTRY_BSIZE_EXP
#  error "LinkedBlock: internal error"
# endif
#endif

	// Implementation

#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
# define LB_ENTRY_BSIZE	(LB_ENTRY_WSIZE * MACHINE_WORD_BSIZE)
#endif

#define LB_BLOCK_BSIZE	((N_LB_ENTRIES * LB_ENTRY_BSIZE) + 4)
#define LB_BLOCK_WSIZE	(LB_BLOCK_BSIZE / MACHINE_WORD_BSIZE)
		
	.text
	.align 4
MAKE_IDP(lb_init):
	movl	$0,MAKE_ID(lb_root)
	movl	$0,MAKE_ID(lb_n_blocks)
	ret
	
// IN:
// nothing
// OUT
// - %ecx = ptr to allocated entry
MAKE_IDP(lb_alloc_entry):
	// a new block needed?
	cmpl	$0,MAKE_ID(lb_root)
	je		MAKE_IDP(lb_alloc_entry_new_block)
	cmpl	$ N_LB_ENTRIES,MAKE_ID(lb_entry)
	je		MAKE_IDP(lb_alloc_entry_new_block)
	
MAKE_IDP(lb_alloc_entry_block_allocated):
#define temp %ecx
	movl	MAKE_ID(lb_entry),temp
#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
	imull	$ LB_ENTRY_BSIZE,temp
#else
	shll	$ LB_ENTRY_BSIZE_EXP,temp
#endif
	addl	MAKE_ID(lb_current_block),temp
	addl	$ 4,temp
#undef temp
	incl	MAKE_ID(lb_entry)	
	ret	

MAKE_IDP(lb_alloc_entry_new_block):
	// allocate a new block
	call	MAKE_IDP(lb_alloc_block)
	jmp		MAKE_IDP(lb_alloc_entry_block_allocated)
	
// IN:
// - precondition; lb_entry == N_LB_ENTRIES or lb_root = 0; current block is full
// OUT:
// %ecx = ptr to newly allocated empty block
//
MAKE_IDP(lb_alloc_block):
	subl 	$ LB_BLOCK_WSIZE,free
	js 		undo_handler
	
#define lb_block %ecx
	movl	$ LB_BLOCK_BSIZE,lb_block
	call	APPEND_P(alloc_from_extra_heap)
	
	movl	$0,(lb_block)						// ptr to next lb_block

	movl	$0,MAKE_ID(lb_entry)				// zero entries in lb_block
	
	incl	MAKE_ID(lb_n_blocks)				// increase block counter
	
	cmpl	$0,MAKE_ID(lb_root)
	je		MAKE_IDP(lb_alloc_initial_block)
	
#define temp %ebx
	pushl	temp
	movl	MAKE_ID(lb_current_block),temp		
	movl	lb_block,(temp)						// make previous block point to current block
	popl	temp
#undef temp

	movl	lb_block,MAKE_ID(lb_current_block)	// make newly allocated block the current one
	ret
	
MAKE_IDP(lb_alloc_initial_block):
	movl	lb_block,MAKE_ID(lb_root)			// make root point to initial block
	movl	lb_block,MAKE_ID(lb_current_block)	// make newly allocated block the current one	
	ret
#undef lb_block

// IN:
// - %ecx = valid zero-based index
// OUT:
// - %ecx = ptr to entry
MAKE_IDP(lb_index_of_entry):
#define index %ecx
#define temp %eax
	pushl	temp
	pushl	index
	
	movl	MAKE_ID(lb_root),temp
	cmpl	$0,temp
	je 		MAKE_IDP(lb_index_of_entry_internal_error)

	shrl	$ N_LB_ENTRIES_EXP,index

MAKE_IDP(lb_index_of_entry_loop):
	cmpl	$0,index
	je		MAKE_IDP(lb_index_of_entry_found)
	
	movl	(temp),temp
	
	decl	index
	jmp		MAKE_IDP(lb_index_of_entry_loop)
	
MAKE_IDP(lb_index_of_entry_found):
	popl	index
	
	andl	$ N_LB_ENTRIES - 1,index

#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
	imull	$ LB_ENTRY_BSIZE,index
#else
	shll	$ LB_ENTRY_BSIZE_EXP,index
#endif
	addl	temp,index
	addl	$4,index

	popl	temp
	ret
#undef temp
#undef index

MAKE_IDP(lb_index_of_entry_internal_error):
	movl	$ lb_index_of_entry_internal_error_string,%ecx
	jmp		abort
	
// IN:
// - precondition: at least one block allocated
// OUT:
// - array size in %ecx
MAKE_IDP(lb_size):
#define temp %ecx
	cmpl	$0,MAKE_ID(lb_root)
	je		MAKE_IDP(lb_size_is_zero)			// empty list gives zero sized array

	movl	MAKE_ID(lb_n_blocks),temp
	cmpl	$0,temp
	je		MAKE_IDP(lb_size2)
	
	decl	temp								// current non-full block doesn't count
MAKE_IDP(lb_size2):
	shll	$ N_LB_ENTRIES_EXP,temp
	addl	MAKE_ID(lb_entry),temp
	ret

MAKE_IDP(lb_size_is_zero):
	movl	$0,temp
	ret
#undef temp

// IN:
// - %ecx = address of function operating on a element
// OUT:
// - array has been mapped
// WARNING: only one level map is supported
MAKE_IDP(lb_map_array):
	pushl	%eax								// backup registers
	pushl	%ebx
	
	movl	%ecx,MAKE_ID(lb_map_array_user_defined_function)
	
#define block_base %eax
	movl	MAKE_ID(lb_root),block_base			// root of linked blocks
	
MAKE_IDP(lb_map_array_next_block):
	cmpl	$0,block_base						
	je		MAKE_IDP(lb_map_array_finished)		// no next block, finish
	
	cmpl	$0,(block_base)
	je		MAKE_IDP(lb_map_in_current_block)	// block is current block
	
	// block is full and not current
#define counter %ebx
#define entry %ecx
	movl	$0,counter
	leal	4(block_base),entry

MAKE_IDP(lb_map_array_next_entry):
	cmpl	$ N_LB_ENTRIES,counter
	je		MAKE_IDP(lb_map_array1)

	// %ecx = ptr to array entry
	pushl	block_base
	pushl	counter
	pushl	entry
	call	*(MAKE_ID(lb_map_array_user_defined_function))
	popl	entry
	popl	counter
	popl	block_base
	
	addl	$ LB_ENTRY_BSIZE,entry
	incl	counter
	
	jmp		MAKE_IDP(lb_map_array_next_entry)
	
MAKE_IDP(lb_map_array1):
	movl	(block_base),block_base
	
	jmp		MAKE_IDP(lb_map_array_next_block)

MAKE_IDP(lb_map_in_current_block):
	movl	$0,counter
	leal	4(block_base),entry
	
MAKE_IDP(lb_map_array_next_entry_within_current_block):
	cmpl	MAKE_ID(lb_entry),counter
	je		MAKE_IDP(lb_map_array_finished)

	// %ecx = ptr to array entry
	pushl	counter
	pushl	entry
	call	*(MAKE_ID(lb_map_array_user_defined_function))
	popl	entry
	popl	counter
	
	addl	$ LB_ENTRY_BSIZE,entry
	incl	counter
	
	jmp		MAKE_IDP(lb_map_array_next_entry_within_current_block)	
#undef entry
#undef counter
	
MAKE_IDP(lb_map_array_finished):	
	popl	%ebx									// restore registers
	popl	%eax
	ret	

#ifdef NOT_A_POWER_OF_TWO_ENTRY_SIZE
# undef LB_ENTRY_BSIZE
#endif
