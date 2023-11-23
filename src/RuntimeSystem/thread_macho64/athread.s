
/*	File:	athread.a */
/*	Author:	John van Groningen */
/*	Machine:	amd64 */

	.intel_syntax noprefix

	.text

	.globl	_pthread_setspecific
	.globl	_pthread_getspecific
	.globl	_clean_new_thread

_clean_new_thread:
	push	rbx
	push	rbp
	push	r12
	push	r13
	push	r14
	push	r15

	sub	rsp,24
	mov	qword ptr 8[rsp],rdi

	mov	rdi,768
	att_call	_malloc

	mov	rbx,rax

	mov	rdi,qword ptr _tlsp_tls_index[rip]
	mov	rsi,rax
	att_call	_pthread_setspecific

	mov	r9,rbx

	mov	rdi,qword ptr 8[rsp]

	mov	rbx,qword ptr 8[rdi]
	test	rbx,rbx
	cmove	rbx,qword ptr (main_thread_local_storage+heap_size_offset)[rip]
	mov	qword ptr heap_size_offset[r9],rbx

	mov	rbx,qword ptr 16[rdi]
	test	rbx,rbx
	cmove	rbx,qword ptr (main_thread_local_storage+a_stack_size_offset)[rip]
	mov	qword ptr a_stack_size_offset[r9],rbx
	
	call	init_thread

	mov	qword ptr saved_heap_p_offset[r9],rdi
	mov	qword ptr saved_r15_offset[r9],r15
	mov	qword ptr saved_a_stack_p_offset[r9],rsi

	mov	qword ptr halt_sp_offset[r9],rsp

	mov	rdi,qword ptr 8[rsp]
	call	qword ptr [rdi]

	mov	rdi,qword ptr _tlsp_tls_index[rip]
	att_call	_pthread_getspecific
	mov	r9,rax

	add	rsp,24

	jmp	exit_thread

init_thread:
	lea	rax,128[rsp]
	sub	rsp,32+8

	mov	rax,qword ptr heap_size_offset[r9]
	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,65
	div	rbx
	mov	qword ptr heap_size_65_offset[r9],rax

	mov	rax,qword ptr heap_size_offset[r9]
	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,257
	div	rbx

	mov	heap_size_257_offset[r9],rax

	add	rax,7
	and	rax,-8

	mov	qword ptr heap_copied_vector_size_offset[r9],rax
	mov	qword ptr heap_end_after_copy_gc_offset[r9],0

	mov	rax,qword ptr heap_size_offset[r9]
	add	rax,7
	and	rax,-8
	mov	qword ptr heap_size_offset[r9],rax 
	add	rax,7

	mov	rbp,rsp
	and	rsp,-16

	mov	rbx,r9

 .if LINUX
	mov	rdi,rax
	att_call	_malloc
 .else
	mov	rcx,rax
	call	allocate_memory
 .endif
	mov	rsp,rbp

	mov	r9,rbx

	test	rax,rax 
	je	init_thread_no_memory_2

	mov	heap_mbp_offset[r9],rax

	lea	rdi,7[rax]
	and	rdi,-8

	mov	heap_p_offset[r9],rdi 

	mov	rbp,rsp
	and	rsp,-16

	mov	rbx,r9

 .if LINUX
	mov	r14,rdi
	mov	rdi,qword ptr a_stack_size_offset[r9]
	add	rdi,7
	att_call	_malloc
	mov	rdi,r14
 .else
	mov	rcx,qword ptr a_stack_size_offset[r9]
	add	rcx,7
  .if 0
	call	allocate_memory_with_guard_page_at_end
  .else
	call	allocate_memory
  .endif
 .endif
	mov	rsp,rbp

	mov	r9,rbx
	
	test	rax,rax 
	je	init_thread_no_memory_3

	mov	stack_mbp_offset[r9],rax 

	add	rax,qword ptr a_stack_size_offset[r9]
	add	rax,7+4095
	and	rax,-4096
/*	mov	qword ptr a_stack_guard_page[rip],rax */
	sub	rax,qword ptr a_stack_size_offset[r9]

	add	rax,7
	and	rax,-8

	mov	rsi,rax

	mov	stack_p_offset[r9],rax

/*	lea	rcx,(caf_list+8) */
/*	mov	qword ptr caf_listp,rcx */

/*	lea	rcx,__Nil-8 */
/*	mov	qword ptr finalizer_list,rcx */
/*	mov	qword ptr free_finalizer_list,rcx */

	mov	heap_p1_offset[r9],rdi

	mov	rbp,qword ptr heap_size_257_offset[r9]
	shl	rbp,4
	lea	rax,[rdi+rbp*8]
	mov	heap_copied_vector_offset[r9],rax
	add	rax,heap_copied_vector_size_offset[r9]
	mov	heap_p2_offset[r9],rax

	mov	byte ptr garbage_collect_flag_offset[r9],0

	test	byte ptr _flags[rip],64
	je	init_thread_no_mark1

	mov	rax,qword ptr heap_size_65_offset[r9]
	mov	qword ptr heap_vector_offset[r9],rdi
	add	rdi,rax

	add	rdi,7
	and	rdi,-8

	mov	qword ptr heap_p3_offset[r9],rdi
	lea	rbp,[rax*8]
	mov	byte ptr garbage_collect_flag_offset [r9],-1

init_thread_no_mark1:
	mov	rax,qword ptr heap_size_offset[r9]

	mov	rbx,4000
	test	byte ptr _flags[rip],64
	jne	init_thread_no_mark9
	add	rbx,rbx 
init_thread_no_mark9:

	cmp	rax,rbx 
	jle	init_thread_too_large_or_too_small
	shr	rax,3
	cmp	rax,rbp 
	att_jge	init_thread_too_large_or_too_small
	mov	rbp,rax 
init_thread_too_large_or_too_small:

	lea	rax,[rdi+rbp*8]
	mov	heap_end_after_gc_offset[r9],rax

	test	byte ptr _flags[rip],64
	je	init_thread_no_mark2
	mov	qword ptr bit_vector_size_offset[r9],rbp
init_thread_no_mark2:

	mov	qword ptr bit_counter_offset[r9],0
	mov	qword ptr zero_bits_before_mark_offset[r9],0

	mov	r15,rbp

	add	rsp,32+8
	xor	rax,rax
	ret

init_thread_no_memory_2:
	mov	rax,1
	ret

init_thread_no_memory_3:
	mov	rbp,rsp
	and	rsp,-16

	mov	rbx,r9

 .if LINUX
	mov	rdi,heap_mbp_offset[r9]
	att_call	_free
 .else
	mov	rcx,heap_mbp_offset[r9]
	call	free_memory
 .endif

	mov	rsp,rbp

	mov	r9,rbx

	add	rsp,32

	mov	rax,1
	ret


exit_thread:
	att_call	add_execute_time

	mov	rbp,rsp
	and	rsp,-16

	mov	rbx,r9

 .if LINUX
	mov	rdi,stack_mbp_offset[r9]
	att_call	_free

	mov	r9,rbx

	mov	rdi,heap_mbp_offset[r9]
	att_call	_free

	mov	rdi,rbx
	att_call	_free
 .else
	mov	rcx,stack_mbp_offset[r9]
	sub	rsp,32
	call	free_memory

	mov	r9,rbx

	mov	rcx,heap_mbp_offset[r9]
	call	free_memory

	call	GetProcessHeap

	mov	rcx,rax
	xor	rdx,rdx
	mov	r8,rbx
	call	HeapFree

	add	rsp,32
 .endif

	mov	rsp,rbp

	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	rbp
	pop	rbx

	xor	rax,rax
	ret

/* bit_counter_offset = 0 ? */
/* zero_bits_before_mark_offset = 1 =0 ? */

/* a_stack_guard_page */
/* caf_list */
/* caf_listp */
/* finalizer_list */
/* free_finalizer_list */
/* initial_heap_size */
