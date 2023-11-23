
	mov	rax,qword ptr [rip+heap_size_65]
	xor	rbx,rbx 
	
	mov	qword ptr [rip+n_marked_words],rbx
	shl	rax,6

	mov	qword ptr [rip+lazy_array_list],rbx 
	mov	qword ptr [rip+heap_size_64_65],rax 
	
	lea	rsi,[rsp-4000]

	mov	rax,qword ptr [rip+caf_list]

	mov	qword ptr [rip+end_stack],rsi 

	mov	r10,[rip+neg_heap_p3]
	mov	r11,[rip+heap_size_64_65]
	mov	r13,qword ptr [rip+end_stack]
	mov	r14,0

	test	rax,rax 
	je	_end_mark_cafs

_mark_cafs_lp:
	mov	rbx,qword ptr [rax]
	mov	rbp,qword ptr [rax-8]

	push	rbp
	lea	rbp,[rax+8]
	lea	r12,[rax+rbx*8+8]

	call	_mark_stack_nodes

	pop	rax 
	test	rax,rax 
	att_jne	_mark_cafs_lp

_end_mark_cafs:
	mov	rsi,qword ptr [rip+stack_top]
	mov	rbp,qword ptr [rip+stack_p]

	mov	r12,rsi 
	att_call	_mark_stack_nodes

continue_mark_after_pmark:
	mov	qword ptr [rip+n_marked_words],r14

	mov	rcx,qword ptr [rip+lazy_array_list]

	test	rcx,rcx 
	je	end_restore_arrays

restore_arrays:
	mov	rbx ,qword ptr [rcx]
	lea	r9,[rip+__ARRAY__+2]
	mov	qword ptr [rcx],r9

	cmp	rbx,1
	je	restore_array_size_1

	lea	rdx,[rcx+rbx*8]
	mov	rax,qword ptr [rdx+16]
	test	rax,rax 
	je	restore_lazy_array

	mov	rbp,rax 
	push	rdx 

	xor	rdx,rdx 
	mov	rax,rbx 
	movzx	rbx,word ptr [rbp-2+2]

	div	rbx 
	mov	rbx,rax 

	pop	rdx
	mov	rax,rbp 

restore_lazy_array:
	mov	rdi,qword ptr [rcx+16]
	mov	rbp,qword ptr [rcx+8]
	mov	qword ptr [rcx+8],rbx 
	mov	rsi,qword ptr [rdx+8]
	mov	qword ptr [rcx+16],rax 
	mov	qword ptr [rdx+8],rbp 
	mov	qword ptr [rdx+16],rdi 

	test	rax,rax
	je	no_reorder_array

	movzx	rdx,word ptr [rax-2]
	sub	rdx,256
	movzx	rbp,word ptr [rax-2+2]
	cmp	rbp,rdx 
	att_je	no_reorder_array

	add	rcx,24
	imul	rbx,rdx 
	mov	rax,rdx 
	lea	rdx,[rcx+rbx*8]
	mov	rbx,rbp 
	sub	rax,rbp 

	att_call	reorder

no_reorder_array:
	mov	rcx,rsi 
	test	rcx,rcx 
	att_jne	restore_arrays

	att_jmp	end_restore_arrays

restore_array_size_1:
	mov	rbp,qword ptr [rcx+8]
	mov	rdx,qword ptr [rcx+16]
	mov	qword ptr [rcx+8],rbx 
	mov	rax,qword ptr [rcx+24]
	mov	qword ptr [rcx+24],rbp 
	mov	qword ptr [rcx+16],rax 

	mov	rcx,rdx 
	test	rcx,rcx 
	att_jne	restore_arrays

end_restore_arrays:
	mov	rdi,qword ptr [rip+heap_vector]
	lea	rcx,[rip+finalizer_list]
	lea	rdx,[rip+free_finalizer_list]

	mov	rbp,qword ptr [rcx]
determine_free_finalizers_after_mark:
	lea	r9,[rip+__Nil-8]
	cmp	rbp,r9
	je	end_finalizers_after_mark

	lea	rax,[r10+rbp]
	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rax]
	test	esi,dword ptr [rdi+rbx*4]
	je	finalizer_not_used_after_mark

	lea	rcx,[rbp+8]
	mov	rbp,qword ptr [rbp+8]
	att_jmp	determine_free_finalizers_after_mark

finalizer_not_used_after_mark:
	mov	qword ptr [rdx],rbp 
	lea	rdx,[rbp+8]

	mov	rbp,qword ptr [rbp+8]
	mov	qword ptr [rcx],rbp 
	att_jmp	determine_free_finalizers_after_mark

end_finalizers_after_mark:
	mov	qword ptr [rdx],rbp 

	att_call	add_garbage_collect_time

	mov	rax,qword ptr [rip+bit_vector_size]

	mov	rdi,qword ptr [rip+n_allocated_words]
	add	rdi,qword ptr [rip+n_marked_words]
	shl	rdi,3

	mov	rsi,rax
	shl	rsi,3

	push	rdx 
	push	rax 

	mov	rax,rdi 
	mul	qword ptr [rip+_heap_size_multiple]
	shrd	rax,rdx,8
	shr	rdx,8

	mov	rbx,rax 
	test	rdx,rdx 
	
	pop	rax 
	pop	rdx 
	
	je	not_largest_heap

	mov	rbx,qword ptr [rip+heap_size_65]
	shl	rbx,6

not_largest_heap:
	cmp	rbx,rsi 
	jbe	no_larger_heap
	
	mov	rsi,qword ptr [rip+heap_size_65]
	shl	rsi,6
	cmp	rbx,rsi
	jbe	not_larger_than_heap
	mov	rbx,rsi 
not_larger_than_heap:
	mov	rax,rbx 
	shr	rax,3
	mov	qword ptr [rip+bit_vector_size],rax
no_larger_heap:

	mov	rbp,rax

	mov	rdi,qword ptr [rip+heap_vector]

	shr	rbp,5

	test	al,31
	je	no_extra_word

	mov	dword ptr [rdi+rbp*4],0

no_extra_word:
	sub	rax,qword ptr [rip+n_marked_words]
	shl	rax,3
	mov	qword ptr [rip+n_last_heap_free_bytes],rax

	mov	rax,qword ptr [rip+n_marked_words]
	shl	rax,3
	add	qword ptr [rip+total_gc_bytes],rax

	test	qword ptr [rip+_flags],2
	je	_no_heap_use_message2

	mov	r12,rsp
	and	rsp,-16
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi

	lea	rdi,[rip+marked_gc_string_1]
 .else
	sub	rsp,32

	lea	rcx,marked_gc_string_1
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rdi,qword ptr [rip+n_marked_words]
	shl	rdi,3
 .else
	mov	rcx,qword ptr n_marked_words
	shl	rcx,3
 .endif
	att_call	_ew_print_int

 .if LINUX
	lea	rdi,[rip+heap_use_after_gc_string_2]
 .else
	lea	rcx,heap_use_after_gc_string_2
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,r12

_no_heap_use_message2:
	att_call	call_finalizers

	mov	rsi,qword ptr [rip+n_allocated_words]
	xor	rbx,rbx 

	mov	rcx,rdi 
	mov	qword ptr [rip+n_free_words_after_mark],rbx

_scan_bits:
	cmp	ebx,dword ptr [rcx]
	je	_zero_bits
	mov	dword ptr [rcx],ebx 
	add	rcx,4
	sub	rbp,1
	att_jne	_scan_bits

	jmp	_end_scan

_zero_bits:
	lea	rdx,[rcx+4]
	add	rcx,4
	sub	rbp,1
	jne	_skip_zero_bits_lp1
	jmp	_end_bits

_skip_zero_bits_lp:
	test	rax,rax 
	jne	_end_zero_bits
_skip_zero_bits_lp1:
	mov	eax,dword ptr [rcx]
	add	rcx,4
	sub	rbp,1
	att_jne	_skip_zero_bits_lp

	test	rax,rax
	att_je	_end_bits
	mov	rax,rcx
	mov	dword ptr [rcx-4],ebx
	sub	rax,rdx
	jmp	_end_bits2	

_end_zero_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	shl	rax,3
	add	qword ptr [rip+n_free_words_after_mark],rax
	mov	dword ptr [rcx-4],ebx 

	cmp	rax,rsi
	att_jb	_scan_bits

_found_free_memory:
	mov	qword ptr [rip+bit_counter],rbp
	mov	qword ptr [rip+bit_vector_p],rcx 

	lea	rbx,[rdx-4]
	sub	rbx,rdi 
	shl	rbx,6
	mov	rdi,qword ptr [rip+heap_p3]
	add	rdi,rbx 

	mov	r15,rax
	lea	rbx,[rdi+rax*8]

	sub	r15,rsi
	mov	rsi,qword ptr [rip+stack_top]

	mov	qword ptr [rip+heap_end_after_gc],rbx

	att_jmp	restore_registers_after_gc_and_return

_end_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	add	rax,4
_end_bits2:
	shl	rax,3
	add	qword ptr [rip+n_free_words_after_mark],rax
	cmp	rax,rsi 
	att_jae	_found_free_memory

_end_scan:
	mov	qword ptr [rip+bit_counter],rbp
	att_jmp	compact_gc

/* %rbp : pointer to stack element */
/* %rdi : heap_vector */
/* %rax ,%rbx ,%rcx ,%rdx ,%rsi : free */

_mark_stack_nodes:
	cmp	rbp,r12
	je	_end_mark_nodes
_mark_stack_nodes_:
	mov	rcx,qword ptr [rbp]

	add	rbp,8
	lea	rdx,[r10+rcx]

	cmp	rdx,r11
	att_jnc	_mark_stack_nodes

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	_mark_stack_nodes

	push	rbp
	push	0
	jmp	_mark_arguments

_mark_hnf_2:
	cmp	rsi,0x20000000
	jbe	fits_in_word_6
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_6:
	add	r14,3

_mark_record_2_c:
	mov	rbx,qword ptr [rcx+8]
	push	rbx 

	cmp	rsp,r13
	jb	__mark_using_reversal

_mark_node2:
_shared_argument_part:
	mov	rcx,qword ptr [rcx]

_mark_node:
	lea	rdx,[r10+rcx]
	cmp	rdx,r11
	jnc	_mark_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	_mark_next_node

_mark_arguments:
	mov	rax,qword ptr [rcx]
	test	rax,2
	je	_mark_lazy_node
	
	movzx	rbp,word ptr [rax-2]

	test	rbp,rbp
	je	_mark_hnf_0

	or	dword ptr [rdi+rbx*4],esi 
	add	rcx,8

	cmp	rbp,256
	jae	_mark_record

	sub	rbp,2
	att_je	_mark_hnf_2
	jb	_mark_hnf_1

_mark_hnf_3:
	mov	rdx,qword ptr [rcx+8]

	cmp	rsi,0x20000000
	jbe	fits_in_word_1
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_1:	

	add	r14,3
	lea	rax,[r10+rdx]
	mov	rbx,rax
	
	and	rax,31*8
	shr	rbx,8

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rax]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	_shared_argument_part

_no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],esi 
	add	rbp,1

	add	r14,rbp 
	lea	rax,[rax+rbp*8]
	lea	rdx,[rdx+rbp*8-8]

	cmp	rax,32*8
	jbe	fits_in_word_2
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_2:

	mov	rbx,qword ptr [rdx]
	sub	rbp,2
	push	rbx 

_push_hnf_args:
	mov	rbx,qword ptr [rdx-8]
	sub	rdx,8
	push	rbx 
	sub	rbp,1
	att_jge	_push_hnf_args

	cmp	rsp,r13
	att_jae	_mark_node2

	att_jmp	__mark_using_reversal

_mark_hnf_1:
	cmp	rsi,0x40000000
	jbe	fits_in_word_4
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_4:
	add	r14,2
	mov	rcx,qword ptr [rcx]
	att_jmp	_mark_node

_mark_lazy_node_1:
	add	rcx,8
	or	dword ptr [rdi+rbx*4],esi 
	cmp	rsi,0x20000000
	jbe	fits_in_word_3
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_3:
	add	r14,3

	cmp	rbp,1
	att_je	_mark_node2

_mark_selector_node_1:
	add	rbp,2
	mov	rdx,qword ptr [rcx]
	je	_mark_indirection_node

	lea	rsi,[r10+rdx]
	mov	rbx,rsi 

	shr	rbx,8
	and	rsi,31*8

	add	rbp,1

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rsi]
	jle	_mark_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	_mark_node3

	cmp	word ptr [rbp-2],2
	jbe	_small_tuple_or_record

_large_tuple_or_record:
	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
	lea	r8,[rip+bit_set_table2]
	mov	ebp,dword ptr [r8+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	_mark_node3

	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx

	cmp	rax,16
	jl	_mark_tuple_selector_node_1
	mov	rdx,r9
	je	_mark_tuple_selector_node_2
	mov	rcx,qword ptr [r9+rax-24]
	mov	qword ptr [rbp],rcx
	att_jmp	_mark_node

_mark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [rbp],rcx
	att_jmp	_mark_node	

_small_tuple_or_record:
	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx
_mark_tuple_selector_node_1:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx	
	att_jmp	_mark_node

_mark_record_selector_node_1:
	je	_mark_strict_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	_mark_node3

	cmp	word ptr [rbp-2],258
	att_jbe	_small_tuple_or_record

	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
	lea	r8,[rip+bit_set_table2]
	mov	ebp,dword ptr [r8+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	_mark_node3

	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx

	cmp	rax,16
	jle	_mark_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
_mark_record_selector_node_2:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx
	att_jmp	_mark_node

_mark_strict_record_selector_node_1:
	test	esi,dword ptr [rdi+rbx*4]
	att_jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	_mark_node3

	cmp	word ptr [rbp-2],258
	jbe	_select_from_small_record

	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp 
	and	rbp,31*8
	shr	rbx,8
	lea	r8,[rip+bit_set_table2]
	mov	ebp,dword ptr [r8+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	_mark_node3

_select_from_small_record:
	movsxd	rbx,dword ptr [rax-8]
	add	rax,rbx
	sub	rcx,8

	movzx	ebx,word ptr [rax+4-8]
	cmp	rbx,16
	jle	_mark_strict_record_selector_node_2
	mov	rbx,qword ptr [r9+rbx-24]
	jmp	_mark_strict_record_selector_node_3
_mark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
_mark_strict_record_selector_node_3:
	mov	qword ptr [rcx+8],rbx

	movzx	ebx,word ptr [rax+6-8]
	test	rbx,rbx
	je	_mark_strict_record_selector_node_5
	cmp	rbx,16
	jle	_mark_strict_record_selector_node_4
	mov	rdx,r9
	sub	rbx,24
_mark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rdx+rbx]
	mov	qword ptr [rcx+16],rbx
_mark_strict_record_selector_node_5:

	mov	rax,qword ptr [rax-8-8]
	mov	qword ptr [rcx],rax
	att_jmp	_mark_next_node

_mark_indirection_node:
_mark_node3:
	mov	rcx,rdx 
	att_jmp	_mark_node

_mark_next_node:
	pop	rcx 
	test	rcx,rcx 
	att_jne	_mark_node

	pop	rbp 
	cmp	rbp,r12
	att_jne	_mark_stack_nodes_

_end_mark_nodes:
	ret

_mark_lazy_node:
	movsxd	rbp,dword ptr [rax-4]
	test	rbp,rbp 
	je	_mark_node2_bb

	cmp	rbp,1
	att_jle	_mark_lazy_node_1

	cmp	rbp,256
	jge	_mark_closure_with_unboxed_arguments
	inc	rbp
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]
	lea	rcx,[rcx+rbp*8]

	cmp	rdx,32*8
	jbe	fits_in_word_7
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_7:
	sub	rbp,3
_push_lazy_args:
	mov	rbx,qword ptr [rcx-8]
	sub	rcx,8
	push	rbx
	sub	rbp,1
	att_jge	_push_lazy_args

	sub	rcx,8

	cmp	rsp,r13
	att_jae	_mark_node2
	
	att_jmp	__mark_using_reversal

_mark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255
	sub	rbp,1
	att_je	_mark_node2_bb

	shr	rax,8
	add	rbp,2

	or	dword ptr [rdi+rbx*4],esi 
	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]

	sub	rbp,rax

	cmp	rdx,32*8
	jbe	fits_in_word_7_
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_7_:
	sub	rbp,2
	att_jl	_mark_next_node

	lea	rcx,[rcx+rbp*8+16]
	att_jne	_push_lazy_args

_mark_closure_with_one_boxed_argument:
	mov	rcx,qword ptr [rcx-8]
	att_jmp	_mark_node

_mark_hnf_0:
	lea	r9,[rip+__STRING__+2]
	cmp	rax,r9
	jbe	_mark_string_or_array

	or	dword ptr [rdi+rbx*4],esi 

	lea	r9,[rip+CHAR+2]
	cmp	rax,r9
	ja	_mark_normal_hnf_0

_mark_real_int_bool_or_char:
	add	r14,2

	cmp	rsi,0x40000000
	att_jbe	_mark_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	_mark_next_node

_mark_normal_hnf_0:
	inc	r14
	att_jmp	_mark_next_node

_mark_node2_bb:
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,3

	cmp	rsi,0x20000000
	att_jbe	_mark_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	_mark_next_node

_mark_record:
	sub	rbp,258
	je	_mark_record_2
	jl	_mark_record_1

_mark_record_3:
	add	r14,3

	cmp	rsi,0x20000000
	jbe	fits_in_word_13
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_13:
	mov	rdx,qword ptr [rcx+8]

	movzx	rbx,word ptr [rax-2+2]
	lea	rsi,[r10+rdx]

	mov	rax,rsi 
	and	rsi,31*8

	shr	rax,8
	sub	rbx,1

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rsi]
	jb	_mark_record_3_bb

	test	edx,dword ptr [rdi+rax*4]
	att_jne	_mark_node2

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]

	cmp	rsi,32*8
	jbe	_push_record_arguments
	or	dword ptr [rdi+rax*4+4],1
_push_record_arguments:
	mov	rdx,qword ptr [rcx+8]
	mov	rbp,rbx 
	shl	rbx,3
	add	rdx,rbx 
	sub	rbp,1
	att_jge	_push_hnf_args

	att_jmp	_mark_node2

_mark_record_3_bb:
	test	edx,dword ptr [rdi+rax*4]
	att_jne	_mark_next_node

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]
	
	cmp	rsi,32*8
	att_jbe	_mark_next_node

	or	dword ptr [rdi+rax*4+4],1
	att_jmp	_mark_next_node

_mark_record_2:
	cmp	rsi,0x20000000
	jbe	fits_in_word_12
	or	dword ptr [rdi+rbx*4+4],1
fits_in_word_12:
	add	r14,3

	cmp	word ptr [rax-2+2],1
	att_ja	_mark_record_2_c
	att_je	_mark_node2
	att_jmp	_mark_next_node

_mark_record_1:
	cmp	word ptr [rax-2+2],0
	att_jne	_mark_hnf_1

	att_jmp	_mark_real_int_bool_or_char

_mark_string_or_array:
	je	_mark_string_

_mark_array:
	mov	rbp,qword ptr [rcx+16]
	test	rbp,rbp
	je	_mark_lazy_array

	movzx	rax,word ptr [rbp-2]

	test	rax,rax 
	je	_mark_strict_basic_array

	movzx	rbp,word ptr [rbp-2+2]
	test	rbp,rbp 
	je	_mark_b_record_array

	cmp	rsp,r13
	jb	_mark_array_using_reversal

	sub	rax,256
	cmp	rax,rbp 
	je	_mark_a_record_array

_mark_ab_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr [rcx+8]

	imul	rax,rbp 
	add	rax,3

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	jae	_end_set_ab_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_ab_array_bits

_mark_ab_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	att_jb	_mark_ab_array_lp

_last_ab_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

_end_set_ab_array_bits:
	mov	rax,qword ptr [rcx+8]
	mov	rdx,qword ptr [rcx+16]
	movzx	rbx,word ptr [rdx-2+2]
	movzx	rdx,word ptr [rdx-2]
	shl	rbx,3
	lea	rdx,[rdx*8-2048]
	push	rbx
	push	rdx
	lea	rbp,[rcx+24]
	push	r12
	jmp	_mark_ab_array_begin
	
_mark_ab_array:
	mov	rbx,qword ptr [rsp+16]
	push	rax
	push	rbp
	lea	r12,[rbp+rbx]

	att_call	_mark_stack_nodes

	mov	rbx,qword ptr [rsp+8+16]
	pop	rbp
	pop	rax
	add	rbp,rbx 
_mark_ab_array_begin:
	sub	rax,1
	att_jnc	_mark_ab_array

	pop	r12
	add	rsp,16
	att_jmp	_mark_next_node

_mark_a_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr [rcx+8]

	imul	rax,rbp 
	push	rax

	add	rax,3

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	_end_set_a_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_a_array_bits

_mark_a_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax
	att_jb	_mark_a_array_lp

_last_a_array_bits:
	or	dword ptr [rdi+rbx*4],ebp

_end_set_a_array_bits:
	pop	rax 
	lea	rbp,[rcx+24]

	push	r12
	lea	r12,[rcx+rax*8+24]

	att_call	_mark_stack_nodes

	pop	r12
	att_jmp	_mark_next_node

_mark_lazy_array:
	cmp	rsp,r13
	att_jb	_mark_array_using_reversal

	or	dword ptr [rdi+rbx*4],esi 
	mov	rax,qword ptr [rcx+8]

	add	rax,3

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	_end_set_lazy_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_lazy_array_bits

_mark_lazy_array_lp:
	or	dword ptr [rdi+rbx*4],ebp
	inc	rbx
	cmp	rbx,rax
	att_jb	_mark_lazy_array_lp

_last_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],ebp

_end_set_lazy_array_bits:
	mov	rax,qword ptr [rcx+8]
	lea	rbp,[rcx+24]

	push	r12
	lea	r12,[rcx+rax*8+24]

	att_call	_mark_stack_nodes

	pop	r12
	att_jmp	_mark_next_node

_mark_array_using_reversal:
	push	0
	mov	rsi,1
	jmp	__mark_node

_mark_strict_basic_array:
	mov	rax,qword ptr [rcx+8]
	lea	r9,[rip+INT+2]
	cmp	rbp,r9
	jle	_mark_strict_int_or_real_array
	lea	r9,[rip+BOOL+2]
	cmp	rbp,r9
	je	_mark_strict_bool_array
_mark_strict_int32_or_real32_array:
	add	rax,6+1
	shr	rax,1
	jmp	_mark_basic_array_
_mark_strict_int_or_real_array:
	add	rax,3
	att_jmp	_mark_basic_array_
_mark_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	att_jmp	_mark_basic_array_

_mark_b_record_array:
	mov	rbp,qword ptr [rcx+8]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	att_jmp	_mark_basic_array_

_mark_string_:
	mov	rax,qword ptr [rcx+8]
	add	rax,16+7
	shr	rax,3

_mark_basic_array_:
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	att_jae	_mark_next_node

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_string_bits

_mark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	att_jb	_mark_string_lp

_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	att_jmp	_mark_next_node

__end_mark_using_reversal:
	pop	rdx 
	test	rdx,rdx 
	att_je	_mark_next_node
	mov	qword ptr [rdx],rcx 
	att_jmp	_mark_next_node

__mark_using_reversal:
	push	rcx 
	mov	rsi,1
	mov	rcx,qword ptr [rcx]
	att_jmp	__mark_node

__mark_arguments:
	mov	rax,qword ptr [rcx]
	test	al,2
	je	__mark_lazy_node

	movzx	rbp,word ptr [rax-2]
	test	rbp,rbp 
	je	__mark_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	__mark__record

	sub	rbp,2
	je	__mark_hnf_2
	jb	__mark_hnf_1

__mark_hnf_3:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx

	cmp	rdx,0x20000000

	mov	rax,qword ptr [rcx+8]

	jbe	fits__in__word__1
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word__1:
	add	rax,r10

	mov	rbx,rax 
	and	rax,31*8

	shr	rbx,8

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rax]
	test	edx,dword ptr [rdi+rbx*4]
	jne	__shared_argument_part

__no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],edx 
	mov	rdx,qword ptr [rcx+8]

	add	rbp,1
	mov	qword ptr [rcx+8],rsi 

	add	r14,rbp 
	add	rcx,8

	shl	rbp,3
	or	qword ptr [rdx],1

	add	rax,rbp
	add	rdx,rbp

	cmp	rax,32*8
	jbe	fits__in__word__2
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word__2:

	mov	rbp ,qword ptr [rdx-8]
	mov	qword ptr [rdx-8],rcx 
	lea	rsi,[rdx-8]
	mov	rcx,rbp 
	att_jmp	__mark_node

__mark_hnf_1:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x40000000
	att_jbe	__shared_argument_part
	or	dword ptr [rdi+rbx*4+4],1
__shared_argument_part:
	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi
	lea	rsi,[rcx+2]
	mov	rcx,rbp 
	att_jmp	__mark_node

__mark_no_selector_2:
	pop	rbx
__mark_no_selector_1:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	att_jbe	__shared_argument_part

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	__shared_argument_part

__mark_lazy_node_1:
	att_je	__mark_no_selector_1

__mark_selector_node_1:
	add	rbp,2
	je	__mark_indirection_node

	add	rbp,1

	push	rbx
	mov	rbp,qword ptr [rcx]
	push	rax 
	lea	rax,[r10+rbp] 

	jle	__mark_record_selector_node_1

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	att_jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	__mark_no_selector_2

	cmp	word ptr [rbx-2],2
	jbe	__small_tuple_or_record

__large_tuple_or_record:
	mov	r8,qword ptr [rbp+16]

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]
	
	mov	r9,qword ptr [rbp+16]

	att_jne	__mark_no_selector_2

	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx

	cmp	rax,16
	jl	__mark_tuple_selector_node_1
	je	__mark_tuple_selector_node_2
	mov	rcx,qword ptr [r9+rax-24]
	mov	qword ptr [r8],rcx
	att_jmp	__mark_node

__mark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [r8],rcx
	att_jmp	__mark_node

__small_tuple_or_record:
	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx 

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx
__mark_tuple_selector_node_1:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	att_jmp	__mark_node
	att_jmp	__mark_node

__mark_record_selector_node_1:
	je	__mark_strict_record_selector_node_1

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax
	att_jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	__mark_no_selector_2

	cmp	word ptr [rbx-2],258
	jbe	__small_record

	mov	r8,qword ptr [rbp+16]

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]

	mov	r9,qword ptr [rbp+16]

	att_jne	__mark_no_selector_2

__small_record:
	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx 

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx

	cmp	rax,16
	jle	__mark_record_selector_node_2
	mov	rbp,r9
	sub	rax,24
__mark_record_selector_node_2:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	att_jmp	__mark_node

__mark_strict_record_selector_node_1:
	mov	rbx,rax
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx *4]
	pop	rax 
	att_jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	__mark_no_selector_2

	cmp	word ptr [rbx-2],258
	jle	__select_from_small_record

	mov	r8,qword ptr [rbp+16]

	add	r8,r10
	mov	rbx,r8 
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]

	mov	r9,qword ptr [rbp+16]

	att_jne	__mark_no_selector_2
	
__select_from_small_record:
	movsxd	rbx,dword ptr [rax-8]
	add	rax,rbx
	sub	rcx,8

	movzx	ebx,word ptr [rax+4-8]
	cmp	rbx,16
	jle	__mark_strict_record_selector_node_2
	mov	rbx,qword ptr [r9+rbx-24]
	jmp	__mark_strict_record_selector_node_3
__mark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rbp+rbx]
__mark_strict_record_selector_node_3:
	mov	qword ptr [rcx+8],rbx

	movzx	ebx,word ptr [rax+6-8]
	test	rbx,rbx
	je	__mark_strict_record_selector_node_5
	cmp	rbx,16
	jle	__mark_strict_record_selector_node_4
	mov	rbp,r9
	sub	rbx,24
__mark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rbp+rbx]
	mov	qword ptr [rcx+16],rbx
__mark_strict_record_selector_node_5:
	pop	rbx

	mov	rax,qword ptr [rax-8-8]
	mov	qword ptr [rcx],rax
	att_jmp	__mark_node

__mark_indirection_node:
	mov	rcx,qword ptr [rcx]
	att_jmp	__mark_node

__mark_hnf_2:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx
	cmp	rdx,0x20000000
	jbe	fits__in__word__6
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word__6:

__mark_record_2_c:
	mov	rax,qword ptr [rcx]
	mov	rbp,qword ptr [rcx+8]
	or	rax,2
	mov	qword ptr [rcx+8],rsi 
	mov	qword ptr [rcx],rax 
	lea	rsi,[rcx+8]
	mov	rcx,rbp

__mark_node:
	lea	rdx,[r10+rcx]
	cmp	rdx,r11
	jae	__mark_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	ebp,dword ptr [r9+rdx]
	test	ebp,dword ptr [rdi+rbx*4]
	att_je	__mark_arguments

__mark_next_node:
	test	rsi,3
	jne	__mark_parent

	mov	rbp,qword ptr [rsi-8]
	mov	rdx,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rsi-8],rdx 
	sub	rsi,8

	mov	rcx,rbp 
	and	rbp,3
	and	rcx,-4
	or	rsi,rbp 
	att_jmp	__mark_node

__mark_parent:
	mov	rbx,rsi 
	and	rsi,-4
	att_je	__end_mark_using_reversal

	and	rbx,3
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 

	sub	rbx,1
	je	__argument_part_parent
	
	lea	rcx,[rsi-8]
	mov	rsi,rbp 
	att_jmp	__mark_next_node

__argument_part_parent:
	and	rbp,-4
	mov	rdx,rsi 
	mov	rcx,qword ptr [rbp-8]
	mov	rbx,qword ptr [rbp]
	mov	qword ptr [rbp-8],rbx 
	mov	qword ptr [rbp],rdx 
	lea	rsi,[rbp+2-8]
	att_jmp	__mark_node

__mark_lazy_node:
	movsxd	rbp,dword ptr [rax-4]
	test	rbp,rbp 
	je	__mark_node2_bb

	add	rcx,8
	cmp	rbp,1
	att_jle	__mark_lazy_node_1
	cmp	rbp,256
	jge	__mark_closure_with_unboxed_arguments

	add	rbp,1
	mov	rax,rdx 
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,rbp

	lea	rax,[rax+rbp*8]
	sub	rbp,2

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rax,32*8
	jbe	fits__in__word__7
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word__7:
__mark_closure_with_unboxed_arguments__2:
	lea	rdx,[rcx+rbp*8]
	mov	rax,qword ptr [rcx]
	or	rax,2
	mov	qword ptr [rcx],rax 
	mov	rcx,qword ptr [rdx]
	mov	qword ptr [rdx],rsi 
	mov	rsi,rdx 
	att_jmp	__mark_node

__mark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255

	sub	rbp,1
	je	__mark_closure_1_with_unboxed_argument
	add	rbp,2

	shr	rax,8
	add	r14,rbp 

	push	rcx 
	lea	rcx,[rdx+rbp*8]

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	sub	rbp,rax 

	or	dword ptr [rdi+rbx*4],edx 
	cmp	rcx,32*8
	jbe	fits__in_word_7_
	or	dword ptr [rdi+rbx*4+4],1
fits__in_word_7_:
	pop	rcx 
	sub	rbp,2
	att_jg	__mark_closure_with_unboxed_arguments__2
	att_je	__shared_argument_part
	sub	rcx,8
	att_jmp	__mark_next_node

__mark_closure_1_with_unboxed_argument:
	sub	rcx,8
	att_jmp	__mark_node2_bb

__mark_hnf_0:
	lea	r9,[rip+INT+2]
	cmp	rax,r9
	jne	__no_int_3

	mov	rbp,qword ptr [rcx+8]
	cmp	rbp,33
	jb	____small_int

__mark_real_bool_or_small_string:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x40000000
	att_jbe	__mark_next_node
	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	__mark_next_node

____small_int:
	shl	rbp,4
	lea	rcx,[rip+small_integers]
	add	rcx,rbp
	att_jmp	__mark_next_node

__no_int_3:
	lea	r9,[rip+__STRING__+2]
	cmp	rax,r9
	jbe	__mark_string_or_array

 	lea	r9,[rip+CHAR+2]
 	cmp	rax,r9
 	jne	__no_char_3

	movzx	rbp,byte ptr [rcx+8]
	shl	rbp,4
	lea	rcx,[rip+static_characters]
	add	rcx,rbp
	att_jmp	__mark_next_node

__no_char_3:
	att_jb	__mark_real_bool_or_small_string

	lea	rcx,[rax-8-2]
	att_jmp	__mark_next_node

__mark_node2_bb:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx

	cmp	rdx,0x20000000
	att_jbe	__mark_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	__mark_next_node

__mark__record:
	sub	rbp,258
	je	__mark_record_2
	jl	__mark_record_1

__mark_record_3:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	jbe	fits__in__word__13
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word__13:
	movzx	rbx,word ptr [rax-2+2]

	mov	rdx,qword ptr [rcx+8]
	add	rdx,r10
	mov	rax,rdx 
	and	rdx,31*8
	shr	rax,8

	push	rsi 

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]
	test	esi,dword ptr [rdi+rax*4]
	jne	__shared_record_argument_part

	add	rbp,1
	or	dword ptr [rdi+rax *4],esi

	lea	rdx,[rdx+rbp*8]
	add	r14,rbp 

	pop	rsi 

	cmp	rdx,32*8
	jbe	fits__in__word__14
	or	dword ptr [rdi+rax*4+4],1
fits__in__word__14:
	sub	rbx,1
	mov	rdx,qword ptr [rcx+8]
	jl	__mark_record_3_bb
	att_je	__shared_argument_part

	mov	qword ptr [rcx+8],rsi 
	add	rcx,8

	sub	rbx,1
	je	__mark_record_3_aab

	lea	rsi,[rdx+rbx*8]
	mov	rax,qword ptr [rdx]
	or	rax,1
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rdx],rax 
	mov	qword ptr [rsi],rcx 
	mov	rcx,rbp 
	att_jmp	__mark_node

__mark_record_3_bb:
	sub	rcx,8
	att_jmp	__mark_next_node

__mark_record_3_aab:
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdx],rcx 
	lea	rsi,[rdx+1]
	mov	rcx,rbp 
	att_jmp	__mark_node

__shared_record_argument_part:
	mov	rdx,qword ptr [rcx+8]

	pop	rsi

	test	rbx,rbx 
	att_jne	__shared_argument_part
	sub	rcx,8
	att_jmp	__mark_next_node

__mark_record_2:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	jbe	fits__in__word_12
	or	dword ptr [rdi+rbx*4+4],1
fits__in__word_12:
	cmp	word ptr [rax-2+2],1
	att_ja	__mark_record_2_c
	att_je	__shared_argument_part
	sub	rcx,8
	att_jmp	__mark_next_node

__mark_record_1:
	cmp	word ptr [rax-2+2],0
	att_jne	__mark_hnf_1
	sub	rcx,8
	att_jmp	__mark_real_bool_or_small_string

__mark_string_or_array:
	je	__mark_string_

__mark_array:
	mov	rbp,qword ptr [rcx+16]
	test	rbp,rbp 
	je	__mark_lazy_array

	movzx	rax,word ptr [rbp-2]
	test	rax,rax 
	je	__mark_strict_basic_array

	movzx	rbp,word ptr [rbp-2+2]
	test	rbp,rbp 
	je	__mark_b_record_array

	sub	rax,256
	cmp	rax,rbp 
	je	__mark_a_record_array

__mark__ab__record__array:
	push	rdx 
	push	rbx 
	mov	rbx,rbp 

	mov	rbp,qword ptr [rcx+8]
	add	rcx,16
	push	rcx 

	shl	rbp,3
	mov	rdx,rax 
	imul	rdx,rbp 

	sub	rax,rbx 
	add	rcx,8
	add	rdx,rcx 

	att_call	reorder
	
	pop	rcx 

	xchg	rax,rbx 
	mov	rbp,qword ptr [rcx-8]
	imul	rax,rbp 
	imul	rbx,rbp 
	add	r14,rbx 
	add	rbx,rax 

	shl	rbx,3
	lea	rbp,[r10+rcx]
	add	rbp,rbx 

	pop	rbx 
	pop	rdx 

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	or	dword ptr [rdi+rbx*4],edx

	lea	rdx,[rcx+rax*8]
	jmp	__mark_r_array

__mark_a_record_array:
	imul	rax,qword ptr [rcx+8]
	add	rcx,16
	jmp	__mark_lr_array

__mark_lazy_array:
	mov	rax,qword ptr [rcx+8]
	add	rcx,16

__mark_lr_array:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	mov	rbp,r10
	or	dword ptr [rdi+rbx*4],edx 
	lea	rdx,[rcx+rax*8]
	add	rbp,rdx 
__mark_r_array:
	shr	rbp,8

	cmp	rbx,rbp 
	jae	__skip_mark_lazy_array_bits

	inc	rbx 

__mark_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],1
	inc	rbx
	cmp	rbx,rbp 
	att_jbe	__mark_lazy_array_bits

__skip_mark_lazy_array_bits:
	add	r14,3
	add	r14,rax 

	cmp	rax,1
	jbe	__mark_array_length_0_1

	mov	rbp,qword ptr [rdx]
	mov	rbx,qword ptr [rcx]
	mov	qword ptr [rdx],rbx 
	mov	qword ptr [rcx],rbp 
	
	mov	rbp,qword ptr [rdx-8]
	sub	rdx,8
	mov	rbx,qword ptr [rip+lazy_array_list]
	add	rbp,2
	mov	qword ptr [rdx],rbx 
	mov	qword ptr [rcx-8],rbp 
	mov	qword ptr [rcx-16],rax 
	sub	rcx,16
	mov	qword ptr [rip+lazy_array_list],rcx

	mov	rcx,qword ptr [rdx-8]
	mov	qword ptr [rdx-8],rsi 
	lea	rsi,[rdx-8]
	att_jmp	__mark_node

__mark_array_length_0_1:
	lea	rcx,[rcx-16]
	att_jb	__mark_next_node

	mov	rbx,qword ptr [rcx+24]
	mov	rbp,qword ptr [rcx+16]
	mov	rdx,qword ptr [rip+lazy_array_list]
	mov	qword ptr [rcx+24],rbp 
	mov	qword ptr [rcx+16],rdx 
	mov	qword ptr [rcx],rax 
	mov	qword ptr [rip+lazy_array_list],rcx 
	mov	qword ptr [rcx+8],rbx 
	add	rcx,8

	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi 
	lea	rsi,[rcx+2]
	mov	rcx,rbp 
	att_jmp	__mark_node

__mark_b_record_array:
	mov	rbp,qword ptr [rcx+8]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	__mark_basic_array

__mark_strict_basic_array:
	mov	rax,qword ptr [rcx+8]
	lea	r9,[rip+INT+2]
	cmp	rbp,r9
	jle	__mark__strict__int__or__real__array
	lea	r9,[rip+BOOL+2]
	cmp	rbp,r9
	je	__mark__strict__bool__array
__mark__strict__int32__or__real32__array:
	add	rax,6+1
	shr	rax,1
	att_jmp	__mark_basic_array
__mark__strict__int__or__real__array:
	add	rax,3
	att_jmp	__mark_basic_array
__mark__strict__bool__array:
	add	rax,24+7
	shr	rax,3
	att_jmp	__mark_basic_array

__mark_string_:
	mov	rax,qword ptr [rcx+8]
	add	rax,16+7
	shr	rax,3

__mark_basic_array:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,rax 

	or	dword ptr [rdi+rbx*4],edx 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	att_jae	__mark_next_node

	inc	rbx 
	mov	rbp,1

	cmp	rbx,rax 
	att_jae	__last__string__bits

__mark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	att_jb	__mark_string_lp

__last__string__bits:
	or	dword ptr [rdi+rbx*4],ebp 
	att_jmp	__mark_next_node
