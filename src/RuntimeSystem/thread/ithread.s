/
/	File:	ithread.s
/	Author:	John van Groningen
/	Machine:	Intel 386

#define d0 %eax
#define d1 %ebx
#define a0 %ecx
#define a1 %edx
#define a2 %ebp
#define a3 %esi
#define a4 %edi
#define sp %esp

#define d0w %ax
#define d1w %bx
#define a0w %cx
#define a1w %dx
#define a2w %bp
#define a3w %si
#define a4w %di

#define d0b %al
#define d1b %bl
#define a0b %cl
#define a1b %dl

#define d0lb %al
#define d0hb %ah
#define d1lb %bl
#define d1hb %bh

	.text

	.globl	@GetProcessHeap?0
	.globl	@HeapAlloc?12

	.globl	@clean_new_thread

@clean_new_thread:
	call	@GetProcessHeap?0

	pushl	$256
	pushl	$0
	push	d0
	call	@HeapAlloc?12

	movl	d0,a4
	movl	tlsp_tls_index,d0
	movl	a4,%fs:0x0e10(,d0,4)

	movl	4(sp),a0

	movl	4(a0),d1
	test	d1,d1
	jne	clean_new_thread_1
	movl	main_thread_local_storage+heap_size_offset,d1
clean_new_thread_1:
	movl	d1,heap_size_offset(a4)

	movl	8(a0),d1
	test	d1,d1
	jne	clean_new_thread_2
	movl	main_thread_local_storage+a_stack_size_offset,d1
clean_new_thread_2:
	movl	d1,a_stack_size_offset(a4)

	call	init_thread

	movl	a3,saved_a_stack_p_offset(a4)
	movl	sp,halt_sp_offset (a4)

	movl	4(sp),d0
	push	d0
	call	*(d0)
	addl	$4,sp

	movl	tlsp_tls_index,a4
	movl	%fs:0x0e10(,a4,4),a4	
	jmp	exit_thread

init_thread:
	movl	heap_size_offset(a4),d0
#ifdef PREFETCH2
	sub	$63,d0
#else
	sub	$3,d0
#endif
	xorl	a1,a1
	mov	$33,d1
	div	d1
	movl	d0,heap_size_33_offset(a4)

	movl	heap_size_offset(a4),d0
	sub	$3,d0
	xorl	a1,a1
	mov	$129,d1
	div	d1
	mov	d0,heap_size_129_offset(a4)
	add	$3,d0
	andl	$-4,d0
	movl	d0,heap_copied_vector_size_offset(a4)
	movl	$0,heap_end_after_copy_gc_offset(a4)

	movl	heap_size_offset(a4),d0
	add	$7,d0

	push	d0
#ifdef USE_CLIB
	call	@malloc
#else
	call	@allocate_memory
#endif
	add	$4,sp
	
	test	d0,d0
	je	init_thread_no_memory_2

	mov	d0,heap_mbp_offset(a4)
	addl	$3,d0
	and	$-4,d0
	mov	d0,free_heap_offset(a4)
	mov	d0,heap_p_offset(a4)

	movl	a_stack_size_offset(a4),a2
	add	$3,a2

	push	a2
#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	call	@allocate_memory_with_guard_page_at_end
#else
# ifdef USE_CLIB
	call	@malloc
# else
	call	@allocate_memory
# endif
#endif
	add	$4,sp
	
	test	d0,d0
	je	init_thread_no_memory_3

	mov	d0,stack_mbp_offset(a4)
#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	addl	a_stack_size_offset(a4),d0
	addl	$3+4095,d0
	andl	$-4096,d0
	movl	d0,a_stack_guard_page
	subl	a_stack_size_offset(a4),d0
#endif
	add	$3,d0
	andl	$-4,d0

	mov	d0,a3
	mov	d0,stack_p_offset(a4)

/	lea	caf_list+4,a0
/	movl	a0,caf_listp

/ #ifdef FINALIZERS
/	movl	$__Nil-4,finalizer_list
/	movl	$__Nil-4,free_finalizer_list
/ #endif

	mov	free_heap_offset(a4),a1
	mov	a1,heap_p1_offset(a4)

	movl	heap_size_129_offset(a4),a2
	shl	$4,a2
	lea	(a1,a2,4),d0
	mov	d0,heap_copied_vector_offset(a4)
	add	heap_copied_vector_size_offset(a4),d0
	mov	d0,heap_p2_offset(a4)

	movb	$0,garbage_collect_flag_offset(a4)

# ifdef MARK_AND_COPY_GC
	testb	$64,@flags
	je	init_thread_no_mark1
# endif

# if defined (MARK_GC) || defined (COMPACT_GC_ONLY)
	movl	heap_size_33_offset(a4),d0
	movl	a1,heap_vector_offset(a4)
	addl	d0,a1
#  ifdef PREFETCH2
	addl	$63,a1
	andl	$-64,a1
#  else
	addl	$3,a1
	andl	$-4,a1
#  endif
	movl	a1,free_heap_offset(a4)
	movl	a1,heap_p3_offset(a4)
	lea	(,d0,8),a2
	movb	$-1,garbage_collect_flag_offset(a4)
# endif

# ifdef MARK_AND_COPY_GC
init_thread_no_mark1:
# endif

# ifdef ADJUST_HEAP_SIZE
	movl	@initial_heap_size,d0
#  ifdef MARK_AND_COPY_GC
	movl	$(MINIMUM_HEAP_SIZE_2),d1
	testb	$64,@flags
	jne	init_thread_no_mark9
	addl	d1,d1
init_thread_no_mark9:
#  else
#   if defined (MARK_GC) || defined (COMPACT_GC_ONLY)
	movl	$(MINIMUM_HEAP_SIZE),d1
#   else
	movl	$(MINIMUM_HEAP_SIZE_2),d1
#   endif
#  endif

	cmpl	d1,d0
	jle	init_thread_too_large_or_too_small
	shr	$2,d0
	cmpl	a2,d0
	jge	init_thread_too_large_or_too_small
	movl	d0,a2
init_thread_too_large_or_too_small:
# endif

	lea	(a1,a2,4),d0
	mov	d0,heap_end_after_gc_offset(a4)
	subl	$32,d0
	movl	d0,end_heap_offset(a4)

# ifdef MARK_AND_COPY_GC
	testb	$64,@flags
	je	init_thread_no_mark2
# endif

# if defined (MARK_GC) && defined (ADJUST_HEAP_SIZE)
	movl	a2,bit_vector_size_offset(a4)
# endif

# ifdef MARK_AND_COPY_GC
init_thread_no_mark2:
# endif

	movl	$0,bit_counter_offset(a4)
	movl	$0,zero_bits_before_mark_offset(a4)

	xor	%eax,%eax
	ret

init_thread_no_memory_2:
	movl	$1,%eax
	ret

init_thread_no_memory_3:
	push	heap_mbp_offset(a4)
#ifdef USE_CLIB
	call	@free
#else
	call	@free_memory
#endif
	add	$4,sp

	movl	$1,%eax
	ret

exit_thread:
	call	add_execute_time

	push	stack_mbp_offset(a4)
#ifdef USE_CLIB
	call	@free
#else
	call	@free_memory
#endif
	add	$4,sp

	push	heap_mbp_offset(a4)
#ifdef USE_CLIB
	call	@free
#else
	call	@free_memory
#endif
	add	$4,sp

	call	@GetProcessHeap?0

	pushl	a4
	pushl	$0
	push	d0
	call	@HeapFree?12

	ret
