#ifndef GTS_STACK
#define GTS_STACK

// Note:
// - pushl_gc and pushl_no_gc are wrongly chosen because in both cases garbage collection can occur.
//   In the former case indirections have to be restored and then code which pushl_no_gc would call
//   is called. Should be changed.
// - STACK_CHECKS are no option. The normal algorithm depends upon stack being checked as a means to
//   determine when all indirections have been undone.
// - After the first pass the stack is FIXED

// gts_stack.c
	// General:
	// - stackP (tos) points to occupied stackcell
	
	// precondition:
	// - maximum stack size is unknown
	.macro	_pushl_gc reg
		cmpl	stackTop,stackP			// stackP > stackTop
		ja		0f						//jae 	\label
		
		subl	$1,free		 
		js 		undo_handler			// \gc
		subl	$4,stackTop				// stackTop -= 4
	0:	
		subl 	$4,stackP				// stackP -= 4
		movl 	\reg,(stackP)				
	.endm	

	// precondition:
	// - maximum stack size is known
	.macro _pushl_no_gc reg
#ifdef STACK_CHECKS
		// check for stack overflow
		cmpl	stackTop,stackP
		jbe		undo_handler			// stackP <= stackTop i.e. internal error
#endif // STACK_CHECKS
		subl	$4,stackP				// stackP -= 4
		movl	\reg,(stackP)
	.endm
	
	.macro _stack_empty label
		cmpl	stackBottom,stackP
		je 		\label
	.endm
	
	.macro _popl reg
#ifdef STACK_CHECKS
		cmpl	stackBottom,stackP
		je		stack_underflow			// internal error
#endif
		movl	(stackP),\reg
		addl	$4,stackP
	.endm

	.macro _try_popl reg label
		cmpl	stackBottom,stackP
		je 		\label
		movl	(stackP),\reg
		addl	$4,stackP
	.endm
	
	.macro _reserve_stack_block_gc t 
		movl	stackP,\t
		subl	stackTop,\t				// temp = stackP - stackTop
		shrl	$2,\t
		
		cmpl	\t,arity				// arity < temp
		jbe		0f						// \l1	// enough space between stackTop and stackP
		
		// arity > temp
		// arity = arity - temp
		subl	\t,arity				// arity - available space between stackTop and stackP
		subl	arity,free				// free -= rest of arity			
		js		undo_handler
		
		addl	\t,arity
		shll	$2,arity

		subl	arity,stackP			// stackP -= arity
		
		movl	stackP,stackTop
		shrl	$2,arity				// arity /= 4
		jmp		1f						//\l2	
	0:
		movl	arity,\t	
		shll	$2,arity				// arity *= 4
		subl 	arity,stackP			//  reserve space between stackTop and stackP
		movl	\t,arity		
	1:
	.endm	
	
	.macro _reserve_stack_block_no_gc t
#ifdef STACK_CHECKS
		cmpl	stackTop,stackP				// stackP <= stackTop
		jbe		undo_handler
		
		// stackP > stackTop
		movl	stackP,\t		
		subl	stackTop,\t					// free_stack_space = stackP - stackTop
		shrl	$2,\t						// free_stack_space in longs
		
		cmpl	\t,arity					// arity > free_stack_space
		ja		undo_handler				// out of memory, garbage collect
#endif // STACK_CHECKS
		
		// Enough space available
		movl	arity,\t		
		shll	$2,\t						// temp = arity * 4
		subl	\t,stackP					// stackP -= arity * 4	
	.endm
	
	.macro _copy_stack_block_gc t
		// N_reserve_stack_block \t 
		movl	stackP,\t
		subl	stackTop,\t			// temp = stackP - stackTop
		shrl	$2,\t
	
		cmpl	\t,arity			// arity < temp
		jbe		0f					// enough space between stackTop and stackP
		
		// arity > temp
		// arity = arity - temp
		subl	\t,arity			// arity - available space between stackTop and stackP
		subl	arity,free			// free -= rest of arity			
		js		undo_handler
	
		addl	\t,arity
		shll	$2,arity

		subl	arity,stackP		// stackP -= arity
		movl	stackP,stackTop
		
		shrl	$2,arity			// arity /= 4
		jmp		1f		
		
	0:			
		movl	arity,\t	
		shll	$2,arity			// arity *= 4
		subl 	arity,stackP		//  reserve space between stackTop and stackP
		movl	\t,arity		
	1: 

		// copy part		
		movl	heapP,\t
		movl	stackP,heapP
		
		cld
		rep 
		movsl
		
		movl	\t,heapP
	.endm	

	.macro _copy_stack_block_no_gc t
#ifdef STACK_CHECKS
		cmpl	stackTop,stackP				// stackP <= stackTop
		jbe		undo_handler

		// stackP > stackTop
		movl	stackP,\t		
		subl	stackTop,\t					// free_stack_space = stackP - stackTop
		shrl	$2,\t						// free_stack_space in longs
		
		cmpl	\t,arity					// arity > free_stack_space
		ja		undo_handler				// out of memory, stack overflow
#endif // STACK_CHECKS
		
		// Enough space available, reserve stack memory
		movl	arity,\t		
		shll	$2,\t						// temp = arity * 4
		subl	\t,stackP					// stackP -= arity * 4
		
		// Copy to reserved memory area
		movl	heapP,\t					// backup heapP
		movl	stackP,heapP				// set destination		
		
		cld
		rep
		movsl
		
		movl	\t,heapP					// restore heapP
	.endm

/*	
// stack_overflow
// This is a serious error because the stack size as computed in the very first
// pass is too small. Mainly caused by a different traversal of the graph.
stack_overflow:
	int3
	jmp		stack_overflow
*/
stack_underflow:
	int3
	jmp		stack_underflow
	
	
	// (user) stack
	.data
	.align	4
stackTop:
	.long	0	
stackBottom:
	.long 	0
descStackTop:
	.long 	0		
	
	// extra heap (between (user) stack and end_heap + 32)
extraheapBottom:
	.long	0
extraP:
	.long	0
	
#define FIXED
#include "gts_alloc_from_extra_heap.c"

#define UNFIXED
#include "gts_alloc_from_extra_heap.c"

// ------------------------------------------------------------------------------------------
// support for a moveable stack

// ecx = amount of bytes to move; preserves all registers except for status
move_stack_downwards:
#define n_bytes	%ecx
	pushl	%esi
	pushl	%edi
	pushl	%eax
	pushl	%ebx
	
#define newStackP	%eax
#define temp		%ebx
	movl	stackP,newStackP
	subl	n_bytes,newStackP			// newStackP = stackP - n_bytes
	pushl	newStackP

	movl	stackBottom,%esi
	cmpl	stackP,%esi
	je 		move_stack_downwards2

move_stack_loop:
	movl	(stackP),temp
	addl	$4,stackP

	movl	temp,(newStackP)
	addl	$4,newStackP

	cmpl	stackP,%esi
	jne		move_stack_loop
	
move_stack_downwards2:
	popl	stackP

	subl	n_bytes,stackBottom			// stackBotom -= n_words
	subl	n_bytes,stackTop			// stackTop -= n_words
#undef temp
#undef newStackP
	
	popl	%ebx
	popl	%eax
	popl	%edi
	popl	%esi
	
	ret
#undef n_bytes
	
//#else
//#error "al defined"
#endif // GTS_STACK