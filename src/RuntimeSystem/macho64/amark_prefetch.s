

	.data
n_queue_items:
	.quad	0
queue_first:
	.quad	0
queue:
	.quad	0,0,0,0,0,0,0,0
	.quad	0,0,0,0,0,0,0,0

	.text

pmark:
	mov	rax,qword ptr [rip+heap_size_65]
	xor	rbx,rbx 

	mov	qword ptr [rip+n_marked_words],rbx
	shl	rax,6

	mov	qword ptr [rip+heap_size_64_65],rax
	mov	qword ptr [rip+lazy_array_list],rbx 
	
	lea	rsi,[rsp-4000]

	mov	rax,qword ptr [rip+caf_list]

	mov	qword ptr [rip+end_stack],rsi 

	mov	r15,0
	mov	r8,0

	mov	r10,[rip+neg_heap_p3]
	mov	r11,[rip+heap_size_64_65]
	mov	r13,qword ptr [rip+end_stack]
	mov	r14,0

	test	rax,rax
	je	end_pmark_cafs

pmark_cafs_lp:
	mov	rbx,qword ptr [rax]
	mov	rbp,qword ptr [rax-8]

	push	rbp
	lea	rbp,[rax+8]
	lea	r12,[rax+rbx*8+8]

	call	pmark_stack_nodes

	pop	rax
	test	rax,rax 
	att_jne	pmark_cafs_lp

end_pmark_cafs:
	mov	rsi,qword ptr [rip+stack_top]
	mov	rbp,qword ptr [rip+stack_p]

	mov	r12,rsi 
	att_call	pmark_stack_nodes
	att_jmp	continue_mark_after_pmark

/* %rbp : pointer to stack element */
/* %rdi : heap_vector */
/* %rax ,%rbx ,%rcx ,%rdx ,%rsi : free */

pmark_stack_nodes:
	cmp	rbp,r12
	je	end_pmark_nodes
pmark_stack_nodes_:
	mov	rcx,qword ptr [rbp]

	add	rbp,8
	lea	rdx,[r10+rcx] 

	cmp	rdx,r11
	att_jnc	pmark_stack_nodes

	mov	rbx,rdx 
	and	rdx,31*8

	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_stack_nodes

	push	rbp 

	push	0

	jmp	pmark_node_

pmark_hnf_2:
	cmp	rsi,0x20000000
	jbe	pmark_fits_in_word_6
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_6:
	add	r14,3

pmark_record_2_c:
	mov	rbx,qword ptr [rcx+8]
	push	rbx 

	cmp	rsp,r13
	jb	pmarkr_using_reversal

pmark_node2:
pmark_shared_argument_part:
	mov	rcx,qword ptr [rcx]

pmark_node:
	lea	rdx,[r10+rcx]
	cmp	rdx,r11
	jnc	pmark_next_node

	mov	rbx,rdx 
	and	rdx,31*8

	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_next_node

pmark_node_:

	prefetch	[rcx]

	lea	r9,[rip+queue]
	mov	qword ptr [r9+r8],rcx 
	lea	rdx,[r8+r15*8]
	add	r8,8

	and	r8,15*8
	and	rdx,15*8

	cmp	r15,-4
	je	pmark_last_item_in_queue

pmark_add_items:
	mov	rcx,qword ptr [rsp]
	test	rcx,rcx 
	jne	pmark_add_stacked_item

pmark_add_items2:
	mov	rbp,qword ptr [rsp+8]
	cmp	rbp,r12
	att_je	pmark_last_item_in_queue

	mov	rcx,qword ptr [rbp]
	add	rbp,8
	mov	qword ptr [rsp+8],rbp 

	lea	rbp,[r10+rcx]
	cmp	rbp,r11
	att_jnc	pmark_add_items2
	mov	rax,rbp 
	and	rbp,31*8
	shr	rax,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rbp]
	test	esi,dword ptr [rdi+rax*4]
	att_jne	pmark_add_items2

	prefetch	[rcx]

	lea	r9,[rip+queue]
	mov	qword ptr [r9+r8],rcx 
	add	r8,8
	and	r8,15*8

	sub	r15,1
	
	cmp	r15,-4
	att_jne	pmark_add_items2
	att_jmp	pmark_last_item_in_queue

pmark_add_stacked_item:
	add	rsp ,8

	lea	rbp,[r10+rcx]
	cmp	rbp,r11
	att_jnc	pmark_add_items
	mov	rax,rbp 
	and	rbp,31*8
	shr	rax,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rbp]
	test	esi,dword ptr [rdi+rax*4]
	att_jne	pmark_add_items

	prefetch	[rcx]

	lea	r9,[rip+queue]
	mov	qword ptr [r9+r8],rcx 
	add	r8,8
	and	r8,15*8

	sub	r15,1

	cmp	r15,-4 
	att_jne	pmark_add_items

pmark_last_item_in_queue:
	lea	r9,[rip+queue]
	mov	rcx,qword ptr [r9+rdx]

	lea	rdx,[r10+rcx]

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr[r9+rdx]
		
	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_next_node

pmark_arguments:
	mov	rax,qword ptr [rcx]
	test	rax,2
	je	pmark_lazy_node
	
	movzx	rbp,word ptr [rax-2]

	test	rbp,rbp 
	je	pmark_hnf_0

	or	dword ptr [rdi+rbx*4],esi 
	add	rcx,8

	cmp	rbp,256
	jae	pmark_record

	sub	rbp,2
	att_je	pmark_hnf_2
	jb	pmark_hnf_1

pmark_hnf_3:
	mov	rdx,qword ptr [rcx+8]

	cmp	rsi,0x20000000
	jbe	pmark_fits_in_word_1
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_1:	

	add	r14,3
	lea	rax,[r10+rdx]
	mov	rbx,rax 

	and	rax,31*8
	shr	rbx,8

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rax]

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_shared_argument_part

pmark_no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],esi 
	add	rbp,1

	add	r14,rbp 
	lea	rax,[rax+rbp*8]
	lea	rdx,[rdx+rbp*8-8]

	cmp	rax,32*8
	jbe	pmark_fits_in_word_2
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_2:

	mov	rbx,qword ptr [rdx]
	sub	rbp,2
	push	rbx 

pmark_push_hnf_args:
	mov	rbx,qword ptr [rdx-8]
	sub	rdx,8
	push	rbx 
	sub	rbp,1
	att_jge	pmark_push_hnf_args

	cmp	rsp,r13
	att_jae	pmark_node2

	att_jmp	pmarkr_using_reversal

pmark_hnf_1:
	cmp	rsi,0x40000000
	jbe	pmark_fits_in_word_4
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_4:
	add	r14,2
	mov	rcx,qword ptr [rcx]
	att_jmp	pmark_node

pmark_lazy_node_1:
	add	rcx,8
	or	dword ptr [rdi+rbx*4],esi 
	cmp	rsi,0x20000000
	jbe	pmark_fits_in_word_3
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_3:
	add	r14,3

	cmp	rbp,1
	att_je	pmark_node2

pmark_selector_node_1:
	add	rbp,2
	mov	rdx,qword ptr [rcx]
	je	pmark_indirection_node

	lea	rsi,[r10+rdx]
	mov	rbx,rsi 

	shr	rbx,8
	and	rsi,31*8

	add	rbp,1

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rsi]
	jle	pmark_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	pmark_node3

	cmp	word ptr [rbp-2],2
	jbe	pmark_small_tuple_or_record

pmark_large_tuple_or_record:
	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
	lea	rsi,[rip+bit_set_table2]
	mov	ebp,dword ptr [rsi+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	pmark_node3

	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx

	cmp	rax,16
	jl	pmark_tuple_selector_node_1
	mov	rdx,r9
	je	pmark_tuple_selector_node_2
	mov	rcx,qword ptr [r9+rax-24]
	mov	qword ptr [rbp],rcx
	att_jmp	pmark_node

pmark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [rbp],rcx
	att_jmp	pmark_node	

pmark_small_tuple_or_record:
	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx
pmark_tuple_selector_node_1:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx	
	att_jmp	pmark_node

pmark_record_selector_node_1:
	je	pmark_strict_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	pmark_node3

	cmp	word ptr [rbp-2],258
	att_jbe	pmark_small_tuple_or_record

	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
	lea	rsi,[rip+bit_set_table2]
	mov	ebp,dword ptr [rsi+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	pmark_node3

	movsxd	rbp,dword ptr [rax-8]
	add	rax,rbp
	lea	rbp,[rip+e__system__nind]
	mov	qword ptr [rcx-8],rbp
	movzx	eax,word ptr [rax+4-8]
	mov	rbp,rcx

	cmp	rax,16
	jle	pmark_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
pmark_record_selector_node_2:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx
	att_jmp	pmark_node

pmark_strict_record_selector_node_1:
	test	esi,dword ptr [rdi+rbx*4]
	att_jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	att_je	pmark_node3

	cmp	word ptr [rbp-2],258
	jbe	pmark_select_from_small_record

	mov	rbp,qword ptr [rdx+16]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp 
	and	rbp,31*8
	shr	rbx,8
	lea	rsi,[rip+bit_set_table2]
	mov	ebp,dword ptr [rsi+rbp]
	test	ebp,dword ptr [rdi+rbx*4]
	att_jne	pmark_node3
	
pmark_select_from_small_record:
	movsxd	rbx,dword ptr [rax-8]
	add	rax,rbx
	sub	rcx,8

	movzx	ebx,word ptr [rax+4-8]
	cmp	rbx,16
	jle	pmark_strict_record_selector_node_2
	mov	rbx,qword ptr [r9+rbx-24]
	jmp	pmark_strict_record_selector_node_3
pmark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
pmark_strict_record_selector_node_3:
	mov	qword ptr [rcx+8],rbx

	movzx	ebx,word ptr [rax+6-8]
	test	rbx,rbx
	je	pmark_strict_record_selector_node_5
	cmp	rbx,16
	jle	pmark_strict_record_selector_node_4
	mov	rdx,r9
	sub	rbx,24
pmark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rdx+rbx]
	mov	qword ptr [rcx+16],rbx
pmark_strict_record_selector_node_5:

	mov	rax,qword ptr [rax-8-8]
	mov	qword ptr [rcx],rax
	att_jmp	pmark_next_node

pmark_indirection_node:
pmark_node3:
	mov	rcx,rdx 
	att_jmp	pmark_node

pmark_next_node:
	pop	rcx 
	test	rcx,rcx 
	att_jne	pmark_node

	pop	rbp 
	cmp	rbp,r12
	att_jne	pmark_stack_nodes_

end_pmark_nodes:
	test	r15,r15
	je	end_pmark_nodes_

	push	rbp 

	push	0

	lea	rdx,[r8+r15*8]
	add	r15,1

	and	rdx,15*8

	att_jmp	pmark_last_item_in_queue

end_pmark_nodes_:
	ret

pmark_lazy_node:
	movsxd	rbp,dword ptr [rax-4]
	test	rbp,rbp 
	je	pmark_node2_bb

	cmp	rbp,1
	att_jle	pmark_lazy_node_1

	cmp	rbp,256
	jge	pmark_closure_with_unboxed_arguments
	inc	rbp 
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]
	lea	rcx,[rcx+rbp*8]

	cmp	rdx,32*8
	jbe	pmark_fits_in_word_7
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_7:
	sub	rbp,3
pmark_push_lazy_args:
	mov	rbx,qword ptr [rcx-8]
	sub	rcx,8
	push	rbx 
	sub	rbp,1
	att_jge	pmark_push_lazy_args

	sub	rcx,8

	cmp	rsp,r13
	att_jae	pmark_node2
	
	att_jmp	pmarkr_using_reversal

pmark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255
	sub	rbp,1
	att_je	pmark_node2_bb

	shr	rax,8
	add	rbp,2
	
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]

	sub	rbp,rax 

	cmp	rdx,32*8
	jbe	pmark_fits_in_word_7_
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_7_:
	sub	rbp,2
	att_jl	pmark_next_node

	lea	rcx,[rcx+rbp*8+16]
	att_jne	pmark_push_lazy_args

pmark_closure_with_one_boxed_argument:
	mov	rcx,qword ptr [rcx-8]
	att_jmp	pmark_node

pmark_hnf_0:
	lea	r9,[rip+__STRING__+2]
	cmp	rax,r9
	jbe	pmark_string_or_array

	or	dword ptr [rdi+rbx*4],esi 

	lea	r9,[rip+CHAR+2]
	cmp	rax,r9
	ja	pmark_normal_hnf_0

pmark_bool:
	add	r14,2

	cmp	rsi,0x40000000
	att_jbe	pmark_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	pmark_next_node

pmark_normal_hnf_0:
	inc	r14
	att_jmp	pmark_next_node

pmark_node2_bb:
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,3

	cmp	rsi,0x20000000
	att_jbe	pmark_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	pmark_next_node

pmark_record:
	sub	rbp,258
	je	pmark_record_2
	jl	pmark_record_1

pmark_record_3:
	add	r14,3

	cmp	rsi,0x20000000
	jbe	pmark_fits_in_word_13
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_13:
	mov	rdx,qword ptr [rcx+8]

	movzx	rbx,word ptr [rax-2+2]
	lea	rsi,[r10+rdx] 

	mov	rax,rsi 
	and	rsi,31*8

	shr	rax,8
	sub	rbx,1

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rsi]
	jb	pmark_record_3_bb

	test	edx,dword ptr [rdi+rax*4]
	att_jne	pmark_node2

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]

	cmp	rsi,32*8
	jbe	pmark_push_record_arguments
	or	dword ptr [rdi+rax*4+4],1
pmark_push_record_arguments:
	mov	rdx,qword ptr [rcx+8]
	mov	rbp,rbx 
	shl	rbx,3
	add	rdx,rbx 
	sub	rbp,1
	att_jge	pmark_push_hnf_args

	att_jmp	pmark_node2

pmark_record_3_bb:
	test	edx,dword ptr [rdi+rax*4]
	att_jne	pmark_next_node

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]
	
	cmp	rsi,32*8
	att_jbe	pmark_next_node

	or	dword ptr [rdi+rax*4+4],1
	att_jmp	pmark_next_node

pmark_record_2:
	cmp	rsi,0x20000000
	jbe	pmark_fits_in_word_12
	or	dword ptr [rdi+rbx*4+4],1
pmark_fits_in_word_12:
	add	r14,3

	cmp	word ptr [rax-2+2],1
	att_ja	pmark_record_2_c
	att_je	pmark_node2
	att_jmp	pmark_next_node

pmark_record_1:
	cmp	word ptr [rax-2+2],0
	att_jne	pmark_hnf_1

	att_jmp	pmark_bool

pmark_string_or_array:
	je	pmark_string_

pmark_array:
	mov	rbp,qword ptr [rcx+16]
	test	rbp,rbp 
	je	pmark_lazy_array

	movzx	rax,word ptr [rbp-2]

	test	rax,rax 
	je	pmark_strict_basic_array

	movzx	rbp,word ptr [rbp-2+2]
	test	rbp,rbp 
	je	pmark_b_record_array

	cmp	rsp,r13
	jb	pmark_array_using_reversal

	sub	rax,256
	cmp	rax,rbp 
	je	pmark_a_record_array

pmark_ab_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr [rcx+8]

	imul	rax,rbp 
	add	rax,3

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	pmark_end_set_ab_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	pmark_last_ab_array_bits

pmark_ab_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax
	att_jb	pmark_ab_array_lp

pmark_last_ab_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_ab_array_bits:
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
	jmp	pmark_ab_array_begin

pmark_ab_array:
	mov	rbx,qword ptr [rsp+16]
	push	rax 
	push	rbp 
	lea	r12,[rbp+rbx]

	att_call	pmark_stack_nodes

	mov	rbx,qword ptr [rsp+8+16]
	pop	rbp 
	pop	rax 
	add	rbp,rbx 
pmark_ab_array_begin:
	sub	rax,1
	att_jnc	pmark_ab_array

	pop	r12
	add	rsp,16
	att_jmp	pmark_next_node

pmark_a_record_array:
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
	jae	pmark_end_set_a_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	pmark_last_a_array_bits

pmark_a_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax 
	att_jb	pmark_a_array_lp

pmark_last_a_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_a_array_bits:
	pop	rax 
	lea	rbp,[rcx+24]

	push	r12
	lea	r12,[rcx+rax*8+24]

	att_call	pmark_stack_nodes

	pop	r12
	att_jmp	pmark_next_node

pmark_lazy_array:
	cmp	rsp,r13
	att_jb	pmark_array_using_reversal

	or	dword ptr [rdi+rbx*4],esi 
	mov	rax,qword ptr [rcx+8]

	add	rax,3

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	pmark_end_set_lazy_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	pmark_last_lazy_array_bits

pmark_lazy_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax
	att_jb	pmark_lazy_array_lp

pmark_last_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_lazy_array_bits:
	mov	rax,qword ptr [rcx+8]
	lea	rbp,[rcx+24]

	push	r12
	lea	r12,[rcx+rax*8+24]

	att_call	pmark_stack_nodes

	pop	r12
	att_jmp	pmark_next_node

pmark_array_using_reversal:
	push	0
	mov	rsi,1
	jmp	pmarkr_node

pmark_strict_basic_array:
	mov	rax,qword ptr [rcx+8]
	lea	r9,[rip+INT+2]
	cmp	rbp,r9
	jle	pmark_strict_int_or_real_array
	lea	r9,[rip+BOOL+2]
	cmp	rbp,r9
	je	pmark_strict_bool_array
	add	rax,6+1
	shr	rax,1
	jmp	pmark_basic_array_
pmark_strict_int_or_real_array:
	add	rax,3
	att_jmp	pmark_basic_array_
pmark_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	att_jmp	pmark_basic_array_

pmark_b_record_array:
	mov	rbp,qword ptr [rcx+8]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	att_jmp	pmark_basic_array_

pmark_string_:
	mov	rax,qword ptr [rcx+8]
	add	rax,16+7
	shr	rax,3

pmark_basic_array_:
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rax 
	lea	rax,[rcx+rax*8-8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	att_jae	pmark_next_node

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	pmark_last_string_bits

pmark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	att_jb	pmark_string_lp

pmark_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	att_jmp	pmark_next_node

end_pmarkr_using_reversal:
	pop	rdx 
	test	rdx,rdx 
	att_je	pmark_next_node
	mov	qword ptr [rdx],rcx 
	att_jmp	pmark_next_node


pmarkr_using_reversal:
	push	rcx 
	mov	rsi,1
	mov	rcx,qword ptr [rcx]
	att_jmp	pmarkr_node

pmarkr_arguments:
	mov	rax,qword ptr [rcx]
	test	al,2
	je	pmarkr_lazy_node

	movzx	rbp,word ptr [rax-2]
	test	rbp,rbp 
	je	pmarkr_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	pmarkr_record

	sub	rbp,2
	je	pmarkr_hnf_2
	jb	pmarkr_hnf_1

pmarkr_hnf_3:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rdx,0x20000000

	mov	rax,qword ptr [rcx+8]

	jbe	pmarkr_fits_in_word_1
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_1:
	add	rax,r10

	mov	rbx,rax 
	and	rax,31*8

	shr	rbx,8

	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rax]
	test	edx,dword ptr [rdi+rbx*4]
	jne	pmarkr_shared_argument_part

pmarkr_no_shared_argument_part:
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
	jbe	pmarkr_fits_in_word_2
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_2:

	mov	rbp ,qword ptr [rdx-8]
	mov	qword ptr [rdx-8],rcx 
	lea	rsi,[rdx-8]
	mov	rcx,rbp 
	att_jmp	pmarkr_node

pmarkr_hnf_1:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x40000000
	att_jbe	pmarkr_shared_argument_part
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_shared_argument_part:
	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi 
	lea	rsi,[rcx+2]
	mov	rcx,rbp
	att_jmp	pmarkr_node

pmarkr_no_selector_2:
	pop	rbx 
pmarkr_no_selector_1:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	att_jbe	pmarkr_shared_argument_part

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	pmarkr_shared_argument_part

pmarkr_lazy_node_1:
	att_je	pmarkr_no_selector_1

pmarkr_selector_node_1:
	add	rbp,2
	je	pmarkr_indirection_node

	add	rbp,1

	push	rbx 
	mov	rbp,qword ptr [rcx]
	push	rax 
	lea	rax,[r10+rbp]

	jle	pmarkr_record_selector_node_1

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	att_jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	pmarkr_no_selector_2

	cmp	word ptr [rbx-2],2
	jbe	pmarkr_small_tuple_or_record

pmarkr_large_tuple_or_record:
	mov	r8,qword ptr [rbp+16]
	mov	r9,r8

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]
	att_jne	pmarkr_no_selector_2

	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx 

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx

	cmp	rax,16
	jl	pmarkr_tuple_selector_node_1
	mov	rdx,r9
	je	pmarkr_tuple_selector_node_2
	mov	rcx,qword ptr [r9+rax-24]
	mov	qword ptr [r8],rcx
	att_jmp	pmarkr_node

pmarkr_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [r8],rcx
	att_jmp	pmarkr_node

pmarkr_small_tuple_or_record:
	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx 

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx
pmarkr_tuple_selector_node_1:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	att_jmp	pmarkr_node

pmarkr_record_selector_node_1:
	je	pmarkr_strict_record_selector_node_1

	mov	rbx,rax
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	att_jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	pmarkr_no_selector_2
	
	cmp	word ptr [rbx-2],258
	jbe	pmarkr_small_record

	mov	r8,qword ptr [rbp+16]

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]

	mov	r9,qword ptr [rbp+16]

	att_jne	pmarkr_no_selector_2

pmarkr_small_record:
	movsxd	rdx,dword ptr [rax-8]
	add	rax,rdx
	lea	rdx,[rip+e__system__nind]
	pop	rbx 

	mov	qword ptr [rcx-8],rdx
	movzx	eax,word ptr [rax+4-8]
	mov	r8,rcx

	cmp	rax,16
	jle	pmarkr_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
pmarkr_record_selector_node_2:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	att_jmp	pmarkr_node

pmarkr_strict_record_selector_node_1:
	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	eax,dword ptr [r9+rax]
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	att_jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	att_je	pmarkr_no_selector_2

	cmp	word ptr [rbx-2],258
	jle	pmarkr_select_from_small_record

	mov	r8,qword ptr [rbp+16]

	add	r8,r10
	mov	rbx,r8 
	and	r8,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	r8d,dword ptr [r9+r8]
	test	r8d,dword ptr [rdi+rbx*4]

	mov	r9,qword ptr [rbp+16]

	att_jne	pmarkr_no_selector_2

pmarkr_select_from_small_record:
	movsxd	rbx,dword ptr [rax-8]
	add	rax,rbx
	sub	rcx,8

	movzx	ebx,word ptr [rax+4-8]
	cmp	rbx,16
	jle	pmarkr_strict_record_selector_node_2
	mov	rbx,qword ptr [r9+rbx-24]
	jmp	pmarkr_strict_record_selector_node_3
pmarkr_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
pmarkr_strict_record_selector_node_3:
	mov	qword ptr [rcx+8],rbx

	movzx	ebx,word ptr [rax+6-8]
	test	rbx,rbx
	je	pmarkr_strict_record_selector_node_5
	cmp	rbx,16
	jle	pmarkr_strict_record_selector_node_4
	mov	rbp,r9
	sub	rbx,24
pmarkr_strict_record_selector_node_4:
	mov	rbx,qword ptr [rbp+rbx]
	mov	qword ptr [rcx+16],rbx
pmarkr_strict_record_selector_node_5:
	pop	rbx

	mov	rax,qword ptr [rax-8-8]
	mov	qword ptr [rcx],rax
	att_jmp	pmarkr_node

pmarkr_indirection_node:
	mov	rcx,qword ptr [rcx]
	att_jmp	pmarkr_node

pmarkr_hnf_2:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	jbe	pmarkr_fits_in_word_6
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_6:

pmarkr_record_2_c:
	mov	rax,qword ptr [rcx]
	mov	rbp,qword ptr [rcx+8]
	or	rax,2
	mov	qword ptr [rcx+8],rsi 
	mov	qword ptr [rcx],rax 
	lea	rsi,[rcx+8]
	mov	rcx,rbp 

pmarkr_node:
	lea	rdx,[r10+rcx] 

	cmp	rdx,r11
	jae	pmarkr_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
	lea	r9,[rip+bit_set_table2]
	mov	ebp,dword ptr [r9+rdx]
	test	ebp,dword ptr [rdi+rbx*4]
	att_je	pmarkr_arguments

pmarkr_next_node:
	test	rsi,3
	jne	pmarkr_parent

	mov	rbp,qword ptr [rsi-8]
	mov	rdx,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rsi-8],rdx 
	sub	rsi,8

	mov	rcx,rbp 
	and	rbp,3
	and	rcx,-4
	or	rsi,rbp 
	att_jmp	pmarkr_node

pmarkr_parent:
	mov	rbx,rsi 
	and	rsi,-4
	att_je	end_pmarkr_using_reversal

	and	rbx,3
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 

	sub	rbx,1
	je	pmarkr_argument_part_parent

	lea	rcx,[rsi-8]
	mov	rsi,rbp 
	att_jmp	pmarkr_next_node
	
pmarkr_argument_part_parent:
	and	rbp,-4
	mov	rdx,rsi 
	mov	rcx,qword ptr [rbp-8]
	mov	rbx,qword ptr [rbp]
	mov	qword ptr [rbp-8],rbx 
	mov	qword ptr [rbp],rdx 
	lea	rsi,[rbp+2-8]
	att_jmp	pmarkr_node

pmarkr_lazy_node:
	movsxd	rbp,dword ptr [rax-4]
	test	rbp,rbp 
	je	pmarkr_node2_bb

	add	rcx,8
	cmp	rbp,1
	att_jle	pmarkr_lazy_node_1
	cmp	rbp,256
	jge	pmarkr_closure_with_unboxed_arguments

	add	rbp,1
	mov	rax,rdx 
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,rbp 

	lea	rax,[rax+rbp*8]
	sub	rbp,2

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rax,32*8
	jbe	pmarkr_fits_in_word_7
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_7:
pmarkr_closure_with_unboxed_arguments_2:
	lea	rdx,[rcx+rbp*8]
	mov	rax,qword ptr [rcx]
	or	rax,2
	mov	qword ptr [rcx],rax 
	mov	rcx,qword ptr [rdx]
	mov	qword ptr [rdx],rsi 
	mov	rsi,rdx 
	att_jmp	pmarkr_node

pmarkr_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255

	sub	rbp,1
	je	pmarkr_closure_1_with_unboxed_argument
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
	jbe	pmarkr_fits_in_word_7_
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_7_:
	pop	rcx
	sub	rbp,2
	att_jg	pmarkr_closure_with_unboxed_arguments_2
	att_je	pmarkr_shared_argument_part
	sub	rcx,8
	att_jmp	pmarkr_next_node

pmarkr_closure_1_with_unboxed_argument:
	sub	rcx,8
	att_jmp	pmarkr_node2_bb

pmarkr_hnf_0:
	lea	r9,[rip+INT+2]
	cmp	rax,r9
	jne	pmarkr_no_int_3

	mov	rbp,qword ptr [rcx+8]
	cmp	rbp,33
	jb	pmarkr_small_int

pmarkr_real_int_bool_or_small_string:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x40000000
	att_jbe	pmarkr_next_node
	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	pmarkr_next_node

pmarkr_small_int:
	shl	rbp,4
	lea	rcx,[rip+small_integers]
	add	rcx,rbp
	att_jmp	pmarkr_next_node

pmarkr_no_int_3:
	lea	r9,[rip+__STRING__+2]
	cmp	rax,r9
	jbe	pmarkr_string_or_array

 	lea	r9,[rip+CHAR+2]
 	cmp	rax,r9
 	jne	pmarkr_no_char_3

	movzx	rbp,byte ptr [rcx+8]
	shl	rbp,4
	lea	rcx,[rip+static_characters]
	add	rcx,rbp
	att_jmp	pmarkr_next_node

pmarkr_no_char_3:
	att_jb	pmarkr_real_int_bool_or_small_string

	lea	rcx,[rax-8-2]
	att_jmp	pmarkr_next_node

pmarkr_node2_bb:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx 
	
	cmp	rdx,0x20000000
	att_jbe	pmarkr_next_node

	or	dword ptr [rdi+rbx*4+4],1
	att_jmp	pmarkr_next_node

pmarkr_record:
	sub	rbp,258
	je	pmarkr_record_2
	jl	pmarkr_record_1

pmarkr_record_3:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	jbe	pmarkr_fits_in_word_13
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_13:
	movzx	rbx,word ptr [rax-2+2]

	mov	rdx,qword ptr [rcx+8]
	lea	rdx,[r10+rdx]
	mov	rax,rdx 
	and	rdx,31*8
	shr	rax,8

	push	rsi 

	lea	r9,[rip+bit_set_table2]
	mov	esi,dword ptr [r9+rdx]
	test	esi,dword ptr [rdi+rax*4]
	jne	pmarkr_shared_record_argument_part

	add	rbp,1
	or	dword ptr [rdi+rax*4],esi 

	lea	rdx,[rdx+rbp*8]
	add	r14,rbp 

	pop	rsi 

	cmp	rdx,32*8
	jbe	pmarkr_fits_in_word_14
	or	dword ptr [rdi+rax*4+4],1
pmarkr_fits_in_word_14:
	sub	rbx,1
	mov	rdx,qword ptr [rcx+8]
	jl	pmarkr_record_3_bb
	att_je	pmarkr_shared_argument_part

	mov	qword ptr [rcx+8],rsi 
	add	rcx,8

	sub	rbx,1
	je	pmarkr_record_3_aab

	lea	rsi,[rdx+rbx*8]
	mov	rax,qword ptr [rdx]
	or	rax,1
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rdx],rax 
	mov	qword ptr [rsi],rcx 
	mov	rcx,rbp
	att_jmp	pmarkr_node

pmarkr_record_3_bb:
	sub	rcx,8
	att_jmp	pmarkr_next_node

pmarkr_record_3_aab:
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdx],rcx 
	lea	rsi,[rdx+1]
	mov	rcx,rbp 
	att_jmp	pmarkr_node

pmarkr_shared_record_argument_part:
	mov	rdx,qword ptr [rcx+8]

	pop	rsi 

	test	rbx,rbx 
	att_jne	pmarkr_shared_argument_part
	sub	rcx,8
	att_jmp	pmarkr_next_node

pmarkr_record_2:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,0x20000000
	jbe	pmarkr_fits_in_word_12
	or	dword ptr [rdi+rbx*4+4],1
pmarkr_fits_in_word_12:
	cmp	word ptr [rax-2+2],1
	att_ja	pmarkr_record_2_c
	att_je	pmarkr_shared_argument_part
	sub	rcx,8
	att_jmp	pmarkr_next_node

pmarkr_record_1:
	cmp	word ptr [rax-2+2],0
	att_jne	pmarkr_hnf_1
	sub	rcx,8
	att_jmp	pmarkr_real_int_bool_or_small_string

pmarkr_string_or_array:
	je	pmarkr_string_

pmarkr_array:
	mov	rbp,qword ptr [rcx+16]
	test	rbp,rbp 
	je	pmarkr_lazy_array

	movzx	rax,word ptr [rbp-2]
	test	rax,rax 
	je	pmarkr_strict_basic_array

	movzx	rbp,word ptr [rbp-2+2]
	test	rbp,rbp
	je	pmarkr_b_record_array

	sub	rax,256
	cmp	rax,rbp 
	je	pmarkr_a_record_array

pmarkr_ab_record_array:
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
	jmp	pmarkr_r_array

pmarkr_a_record_array:
	imul	rax,qword ptr [rcx+8]
	add	rcx,16
	jmp	pmarkr_lr_array

pmarkr_lazy_array:
	mov	rax,qword ptr [rcx+8]
	add	rcx,16

pmarkr_lr_array:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	mov	rbp,r10
	or	dword ptr [rdi+rbx*4],edx
	lea	rdx,[rcx+rax*8]
	add	rbp,rdx 
pmarkr_r_array:
	shr	rbp,8

	cmp	rbx,rbp 
	jae	pmarkr_skip_mark_lazy_array_bits

	inc	rbx 

pmarkr_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],1
	inc	rbx 
	cmp	rbx,rbp 
	att_jbe	pmarkr_lazy_array_bits

pmarkr_skip_mark_lazy_array_bits:
	add	r14,3
	add	r14,rax 

	cmp	rax,1
	jbe	pmarkr_array_length_0_1

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
	att_jmp	pmarkr_node

pmarkr_array_length_0_1:
	lea	rcx,[rcx-16]
	att_jb	pmarkr_next_node

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
	att_jmp	pmarkr_node
	
pmarkr_b_record_array:
	mov	rbp,qword ptr [rcx+8]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	pmarkr_basic_array

pmarkr_strict_basic_array:
	mov	rax,qword ptr [rcx+8]
	lea	r9,[rip+INT+2]
	cmp	rbp,r9
	jle	pmarkr_strict_int_or_real_array
	lea	r9,[rip+BOOL+2]
	cmp	rbp,r9
	je	pmarkr_strict_bool_array
	add	rax,6+1
	shr	rax,1
	att_jmp	pmarkr_basic_array
pmarkr_strict_int_or_real_array:
	add	rax,3
	att_jmp	pmarkr_basic_array
pmarkr_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	att_jmp	pmarkr_basic_array

pmarkr_string_:
	mov	rax,qword ptr [rcx+8]
	add	rax,16+7
	shr	rax,3

pmarkr_basic_array:
	lea	r9,[rip+bit_set_table2]
	mov	edx,dword ptr [r9+rdx]
	add	r14,rax 

	or	dword ptr [rdi+rbx*4],edx 
	lea	rax,[rcx+rax*8-8]
	
	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	att_jae	pmarkr_next_node

	inc	rbx 
	mov	rbp,1

	cmp	rbx,rax 
	jae	pmarkr_last_string_bits

pmarkr_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax 
	att_jb	pmarkr_string_lp

pmarkr_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	att_jmp	pmarkr_next_node
