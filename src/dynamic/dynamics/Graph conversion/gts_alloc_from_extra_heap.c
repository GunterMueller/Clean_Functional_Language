// gts_alloc_from_extra_heap.c
//

// sanity checks
#ifdef FIXED
#ifdef UNFIXED
#error "gts_alloc_from_extra_heap.c: FIXED and UNFIXED cannot be defined at the same time"
#endif
#endif

#ifdef UNFIXED
#ifdef FIXED
#error "gts_alloc_from_extra_heap.c: FIXED and UNFIXED cannot be defined at the same time"
#endif
#endif

	.text
	.align	4
// %ecx = amount of bytes
// can only be used within the first pass.
#ifdef UNFIXED
alloc_from_extra_heap_unfixed:
#endif

#ifdef FIXED
alloc_from_extra_heap_fixed:
#endif
#define temp %eax
	pushl 	temp
	
	movl	extraP,temp								// extra heap pointer
	subl	%ecx,temp								
	cmpl	stackBottom,temp						// enough extra heap available
#ifdef FIXED
	jae		alloc_from_extra_heap_enough_room_fixed
#else
	jae		alloc_from_extra_heap_enough_room_fixed
#endif
	
	// extraP < stackBottom;  not enough space
	pushl	temp
	
#define temp2 %ebx
	pushl	temp2
	
	movl	stackBottom,temp2
	subl	temp,temp2								// extra bytes needed = stackBottom (temp2) - extraP (temp)
	movl	temp2,%ecx
	shrl	$2,temp2
	
	subl	temp2,free
	js		undo_handler
	
	call	move_stack_downwards
	
	popl	temp2
	popl	temp
	
#ifdef FIXED
alloc_from_extra_heap_enough_room_fixed:
#else
alloc_from_extra_heap_enough_room_unfixed:
#endif

	movl	temp,extraP								// update extra heap pointer
	movl	temp,%ecx

	popl	temp
	ret

#undef temp2	
#undef temp

#ifdef FIXED
#undef FIXED
#endif

#ifdef UNFIXED
#undef UNFIXED
#endif