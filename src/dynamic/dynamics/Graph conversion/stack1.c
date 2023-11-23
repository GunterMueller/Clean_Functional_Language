#ifndef STACK1_C
#define STACK1_C
	// obsolete; should be replaced by gts_stack.c but string_to_graph still uses this
	// file.

#include "globals.h"
#include "global_registers.h"

	.align	4
	
	.data
	.align 4
stackTop:
	.long	0	
stackBottom:
	.long 	0
	// -----------------------------------------------------------------------------------
descStackTop:
	.long 0						// initialized at stackTop; is stack pointer
	
	.text
	
	.macro _pushl1 reg 					//label //gc
		cmpl	stackTop,stackP			// stackP > stackTop
		ja		0f						//jae 	\label
		
		subl	$1,free		 
		js 		garbage_collection		// \gc
		subl	$4,stackTop				// stackTop -= 4
	0:	
		subl 	$4,stackP				// stackP -= 4
		movl 	\reg,(stackP)				
	.endm
	
	// stack

	// _popl
	.macro _popl1 reg
		_popl_gc \reg garbage_collection
	.endm

	.macro _popl_gc reg gc
		cmpl	stackBottom,stackP
		je	\gc
		
		movl	(stackP),\reg
		addl	$4,stackP
	.endm

	// _stack_empty
	.macro _stack_empty label
		cmpl	stackBottom,stackP
		je 		\label
	.endm

	.macro N_reserve_stack_block t // l1 l2
		movl	stackP,\t
		subl	stackTop,\t				// temp = stackP - stackTop
		shrl	$2,\t
		
		cmpl	\t,arity				// arity < temp
		jbe		0f						// \l1	// enough space between stackTop and stackP
		
		// arity > temp
		// arity = arity - temp
		
		subl	\t,arity				// arity - available space between stackTop and stackP
		subl	arity,free				// free -= rest of arity			
		js		garbage_collection
		
		addl	\t,arity
		shll	$2,arity

		subl	arity,stackP			// stackP -= arity
		
		movl	stackP,stackTop
		shrl	$2,arity				// arity /= 4
		jmp		1f						//\l2
		
	0:		// \l1:
		movl	arity,\t	
		shll	$2,arity				// arity *= 4
		subl 	arity,stackP			//  reserve space between stackTop and stackP
		movl	\t,arity		
	1:		// \l2:
	.endm	

	/*
	** _copy_heap_block:
	**
	** call by:
	**
	** -	source
	**	the source address
	** -    arity
	**	number of longs to copy 	
	*/
	
	.macro _copy_heap_block
		subl 	arity,free			// free < length
		js 	garbage_collection
		
		cld
		rep
		movsl
	.endm

	/*
	** _copy_stack_block:
	**
	** call by:
	** -	source
	**	the source address
	** -    arity
	**	number of longs to copy
	** - 	t
	** 	temporary register
	** - 	l
	**	a globally unique label name
	**
	** result:
	** -	if possible arity * 4 longs of the stack have been reserved, containing
	** 	the longs stored at source; the first long is stored at the tos.
	*/
/*
	.macro N_copy_stack_block t l1 l2
		N_copy_stack_block_gc \t \l1 \l2 garbage_collection
	.endm
*/

	.macro N_copy_stack_block t // l1 l2
		
		/*
		** N_reserve_stack_block \t \l1 \l2
		*/
		movl	stackP,\t
		subl	stackTop,\t			// temp = stackP - stackTop
		shrl	$2,\t
	
		cmpl	\t,arity			// arity < temp
		jbe		0f					// \l1	// enough space between stackTop and stackP
		
		// arity > temp
		// arity = arity - temp
		subl	\t,arity			// arity - available space between stackTop and stackP
		subl	arity,free			// free -= rest of arity			
		js		garbage_collection
	
		addl	\t,arity
		shll	$2,arity

		subl	arity,stackP			// stackP -= arity
		movl	stackP,stackTop
		
//		subl	arity,stackTop			// stackTop -= arity
		shrl	$2,arity			// arity /= 4
		jmp		1f		// \l2
		
	0:			// \l1:
		movl	arity,\t	
		shll	$2,arity			// arity *= 4
		subl 	arity,stackP			//  reserve space between stackTop and stackP
		movl	\t,arity		
	1: 	//\l2:
		
		/*
		** Copy part
		*/
		
		movl	heapP,\t
		movl	stackP,heapP
		
		cld
		rep 
		movsl
		
		movl	\t,heapP
	.endm	

//#ifdef DYNAMIC_SUPPORT
	.macro _done //okdone
		cmpl	esp_backup,%esp
		je		0f  	// \okdone	
		ret
	0:   //\okdone:
	.endm
//#endif

// ------------------------------------------------------------------------------------------
// support for a moveable stack

// ecx = amount of bytes to move; preserves all registers except for status
	.align	4
	.text
	nop
	nop
	nop
	nop
	
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
	
move_stack_loop:
	cmpl	stackP,stackBottom
	je 		move_stack_downwards2
	
	movl	(stackP),temp
	movl	temp,(newStackP)
	
	addl	$4,stackP
	addl	$4,newStackP
	
	jmp		move_stack_loop
	
move_stack_downwards2:
	popl	stackP

	movl	stackBottom,temp
	subl	n_bytes,temp				
	movl	temp,stackBottom			// stackBotom -= n_words
	
	movl	stackTop,temp
	subl	n_bytes,temp				
	movl	temp,stackTop				// stackTop -= n_words
#undef temp
#undef newStackP
	
	popl	%ebx
	popl	%eax
	popl	%edi
	popl	%esi

	ret
	nop
	nop
	nop
	nop
	nop
	nop
	
#undef n_bytes

#endif