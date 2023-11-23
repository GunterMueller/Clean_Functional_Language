
_TEXT	ends
	_DATA segment
n_queue_items:
	dq	0
queue_first:
	dq	0
queue:
	dq	0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0
_DATA	ends
	_TEXT segment

pmark:
	mov	rax,qword ptr heap_size_65+0
	xor	rbx,rbx 

	mov	qword ptr n_marked_words+0,rbx
	shl	rax,6

	mov	qword ptr heap_size_64_65+0,rax
	mov	qword ptr lazy_array_list+0,rbx 

	lea	rsi,(-4000)[rsp]

	mov	qword ptr end_stack+0,rsi

	mov	r15,0
	mov	r8,0

	mov	r10,neg_heap_p3+0
	mov	r11,heap_size_64_65+0
	mov	r13,qword ptr end_stack+0
	mov	r14,0

 ifdef GC_HOOKS
	mov	rax,gc_hook_before_mark_prefetch+0
	test	rax,rax
	je	no_gc_hook_before_mark_prefetch
	call	rax
no_gc_hook_before_mark_prefetch:
 endif

	mov	rax,qword ptr caf_list+0

	test	rax,rax
	je	end_pmark_cafs

pmark_cafs_lp:
	mov	rbx,qword ptr [rax]
	mov	rbp,qword ptr (-8)[rax]

	push	rbp
	lea	rbp,8[rax]
	lea	r12,8[rax+rbx*8]

	call	pmark_stack_nodes

	pop	rax
	test	rax,rax 
	jne	pmark_cafs_lp

end_pmark_cafs:
	mov	rsi,qword ptr stack_top+0
	mov	rbp,qword ptr stack_p+0

	mov	r12,rsi 
	call	pmark_stack_nodes
	jmp	continue_mark_after_pmark

; %rbp : pointer to stack element
; %rdi : heap_vector
; %rax ,%rbx ,%rcx ,%rdx ,%rsi : free

pmark_stack_nodes:
	cmp	rbp,r12
	je	end_pmark_nodes
pmark_stack_nodes_:
	mov	rcx,qword ptr [rbp]

	add	rbp,8
	lea	rdx,[r10+rcx] 

	cmp	rdx,r11
	jnc	pmark_stack_nodes

	mov	rbx,rdx 
	and	rdx,31*8

	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif
	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_stack_nodes

	push	rbp 

	push	0

	jmp	pmark_node_

pmark_hnf_2:
	cmp	rsi,20000000h
	jbe	pmark_fits_in_word_6
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_6:
	add	r14,3

pmark_record_2_c:
	mov	rbx,qword ptr 8[rcx]
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
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif

	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_next_node

pmark_node_:

	prefetch	[rcx]

 ifdef PIC
	lea	r9,queue+0
	mov	qword ptr [r9+r8],rcx
 else
	mov	qword ptr (queue)[r8],rcx
 endif
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
	mov	rbp,qword ptr 8[rsp]
	cmp	rbp,r12
	je	pmark_last_item_in_queue

	mov	rcx,qword ptr [rbp]
	add	rbp,8
	mov	qword ptr 8[rsp],rbp 

	lea	rbp,[r10+rcx]
	cmp	rbp,r11
	jnc	pmark_add_items2
	mov	rax,rbp 
	and	rbp,31*8
	shr	rax,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rbp]
 else
	mov	esi,dword ptr (bit_set_table2)[rbp]
 endif
	test	esi,dword ptr [rdi+rax*4]
	jne	pmark_add_items2

	prefetch	[rcx]

 ifdef PIC
	lea	r9,queue+0
	mov	qword ptr [r9+r8],rcx 
 else
	mov	qword ptr (queue)[r8],rcx 
 endif
	add	r8,8
	and	r8,15*8

	sub	r15,1
	
	cmp	r15,-4
	jne	pmark_add_items2
	jmp	pmark_last_item_in_queue

pmark_add_stacked_item:
	add	rsp ,8

	lea	rbp,[r10+rcx]
	cmp	rbp,r11
	jnc	pmark_add_items
	mov	rax,rbp 
	and	rbp,31*8
	shr	rax,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rbp]
 else
	mov	esi,dword ptr (bit_set_table2)[rbp]
 endif
	test	esi,dword ptr [rdi+rax*4]
	jne	pmark_add_items

	prefetch	[rcx]

 ifdef PIC
	lea	r9,queue+0
	mov	qword ptr [r9+r8],rcx
 else
	mov	qword ptr (queue)[r8],rcx
 endif
	add	r8,8
	and	r8,15*8

	sub	r15,1

	cmp	r15,-4 
	jne	pmark_add_items

pmark_last_item_in_queue:
 ifdef PIC
	lea	r9,queue+0
	mov	rcx,qword ptr [r9+rdx]
 else
	mov	rcx,qword ptr (queue)[rdx]
 endif

	lea	rdx,[r10+rcx]

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif
		
	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_next_node

pmark_arguments:
	mov	rax,qword ptr [rcx]
	test	rax,2
	je	pmark_lazy_node
	
	movzx	rbp,word ptr (-2)[rax]

	test	rbp,rbp 
	je	pmark_hnf_0

	or	dword ptr [rdi+rbx*4],esi 
	add	rcx,8

	cmp	rbp,256
	jae	pmark_record

	sub	rbp,2
	je	pmark_hnf_2
	jb	pmark_hnf_1

pmark_hnf_3:
	mov	rdx,qword ptr 8[rcx]

	cmp	rsi,20000000h
	jbe	pmark_fits_in_word_1
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_1:	

	add	r14,3
	lea	rax,[r10+rdx]
	mov	rbx,rax 

	and	rax,31*8
	shr	rbx,8

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rax]
 else
	mov	esi,dword ptr (bit_set_table2)[rax]
 endif

	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_shared_argument_part

pmark_no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],esi 
	add	rbp,1

	add	r14,rbp 
	lea	rax,[rax+rbp*8]
	lea	rdx,(-8)[rdx+rbp*8]

	cmp	rax,32*8
	jbe	pmark_fits_in_word_2
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_2:

	mov	rbx,qword ptr [rdx]
	sub	rbp,2
	push	rbx 

pmark_push_hnf_args:
	mov	rbx,qword ptr (-8)[rdx]
	sub	rdx,8
	push	rbx 
	sub	rbp,1
	jge	pmark_push_hnf_args

	cmp	rsp,r13
	jae	pmark_node2

	jmp	pmarkr_using_reversal

pmark_hnf_1:
	cmp	rsi,40000000h
	jbe	pmark_fits_in_word_4
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_4:
	add	r14,2
	mov	rcx,qword ptr [rcx]
	jmp	pmark_node

pmark_lazy_node_1:
	add	rcx,8
	or	dword ptr [rdi+rbx*4],esi 
	cmp	rsi,20000000h
	jbe	pmark_fits_in_word_3
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_3:
	add	r14,3

	cmp	rbp,1
	je	pmark_node2

pmark_selector_node_1:
	add	rbp,2
	mov	rdx,qword ptr [rcx]
	je	pmark_indirection_node

	lea	rsi,[r10+rdx]
	mov	rbx,rsi 

	shr	rbx,8
	and	rsi,31*8

	add	rbp,1

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rsi]
 else
	mov	esi,dword ptr (bit_set_table2)[rsi]
 endif
	jle	pmark_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	pmark_node3

	cmp	word ptr (-2)[rbp],2
	jbe	pmark_small_tuple_or_record

pmark_large_tuple_or_record:
	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	rsi,bit_set_table2+0
	mov	ebp,dword ptr [rsi+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	pmark_node3

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
  else
	mov	eax,(-8)[rax]
  endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	rbp,rcx

	cmp	rax,16
	jl	pmark_tuple_selector_node_1
	mov	rdx,r9
	je	pmark_tuple_selector_node_2
	mov	rcx,qword ptr (-24)[r9+rax]
	mov	qword ptr [rbp],rcx
	jmp	pmark_node

pmark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [rbp],rcx
	jmp	pmark_node	
 endif

pmark_small_tuple_or_record:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
  else
	mov	eax,(-8)[rax]
  endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	rbp,rcx
pmark_tuple_selector_node_1:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx	
 else
	mov	eax,(-8)[rax]
	push	rcx
	mov	rcx,rdx
	mov	eax,4[rax]
	call	near ptr rax
	pop	rdx
	
	lea	r9,e__system__nind
	mov	qword ptr (-8)[rdx],r9
	mov	qword ptr [rdx],rcx
 endif
	jmp	pmark_node

pmark_record_selector_node_1:
	je	pmark_strict_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	pmark_node3

	cmp	word ptr (-2)[rbp],258
	jbe	pmark_small_tuple_or_record
 ifdef NEW_DESCRIPTORS
	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	rsi,bit_set_table2+0
	mov	ebp,dword ptr [rsi+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	pmark_node3

 ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
 else
	mov	eax,(-8)[rax]
 endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
 ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
 else
	movzx	eax,word ptr 4[rax]
 endif
	mov	rbp,rcx

	cmp	rax,16
	jle	pmark_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
pmark_record_selector_node_2:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx
	jmp	pmark_node
 else
	jmp	pmark_large_tuple_or_record
 endif

pmark_strict_record_selector_node_1:
	test	esi,dword ptr [rdi+rbx*4]
	jne	pmark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	pmark_node3

	cmp	word ptr (-2)[rbp],258
	jbe	pmark_select_from_small_record

	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp 
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	rsi,bit_set_table2+0
	mov	ebp,dword ptr [rsi+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	pmark_node3
	
pmark_select_from_small_record:
 ifdef PIC
	movsxd	rbx,dword ptr(-8)[rax]
	add	rax,rbx
 else
	mov	eax,(-8)[rax]
 endif
	sub	rcx,8

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movzx	ebx,word ptr (4-8)[rax]
  else
	movzx	ebx,word ptr 4[rax]
  endif
	cmp	rbx,16
	jle	pmark_strict_record_selector_node_2
	mov	rbx,qword ptr (-24)[r9+rbx]
	jmp	pmark_strict_record_selector_node_3
pmark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
pmark_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rbx

  ifdef PIC
	movzx	ebx,word ptr (6-8)[rax]
  else
	movzx	ebx,word ptr 6[rax]
  endif
	test	rbx,rbx
	je	pmark_strict_record_selector_node_5
	cmp	rbx,16
	jle	pmark_strict_record_selector_node_4
	mov	rdx,r9
	sub	rbx,24
pmark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rdx+rbx]
	mov	qword ptr 16[rcx],rbx
pmark_strict_record_selector_node_5:

  ifdef PIC
	mov	rax,qword ptr ((-8)-8)[rax]
  else
	mov	rax,qword ptr (-8)[rax]
  endif
	mov	qword ptr [rcx],rax
 else
	mov	eax,4[rax]
	call	near ptr rax
 endif
	jmp	pmark_next_node

pmark_indirection_node:
pmark_node3:
	mov	rcx,rdx 
	jmp	pmark_node

pmark_next_node:
	pop	rcx 
	test	rcx,rcx 
	jne	pmark_node

	pop	rbp 
	cmp	rbp,r12
	jne	pmark_stack_nodes_

end_pmark_nodes:
	test	r15,r15
	je	end_pmark_nodes_

	push	rbp 

	push	0

	lea	rdx,[r8+r15*8]
	add	r15,1

	and	rdx,15*8

	jmp	pmark_last_item_in_queue

end_pmark_nodes_:
	ret

pmark_lazy_node:
	movsxd	rbp,dword ptr (-4)[rax]
	test	rbp,rbp 
	je	pmark_node2_bb

	cmp	rbp,1
	jle	pmark_lazy_node_1

	cmp	rbp,256
	jge	pmark_closure_with_unboxed_arguments
	inc	rbp 
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]
	lea	rcx,[rcx+rbp*8]

	cmp	rdx,32*8
	jbe	pmark_fits_in_word_7
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_7:
	sub	rbp,3
pmark_push_lazy_args:
	mov	rbx,qword ptr (-8)[rcx]
	sub	rcx,8
	push	rbx 
	sub	rbp,1
	jge	pmark_push_lazy_args

	sub	rcx,8

	cmp	rsp,r13
	jae	pmark_node2
	
	jmp	pmarkr_using_reversal

pmark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255
	sub	rbp,1
	je	pmark_node2_bb

	shr	rax,8
	add	rbp,2
	
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]

	sub	rbp,rax 

	cmp	rdx,32*8
	jbe	pmark_fits_in_word_7_
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_7_:
	sub	rbp,2
	jl	pmark_next_node

	lea	rcx,16[rcx+rbp*8]
	jne	pmark_push_lazy_args

pmark_closure_with_one_boxed_argument:
	mov	rcx,qword ptr (-8)[rcx]
	jmp	pmark_node

pmark_hnf_0:
	lea	r9,__STRING__+2+0
	cmp	rax,r9
	jbe	pmark_string_or_array

	or	dword ptr [rdi+rbx*4],esi 

	lea	r9,CHAR+2+0
	cmp	rax,r9
	ja	pmark_normal_hnf_0

pmark_bool:
	add	r14,2

	cmp	rsi,40000000h
	jbe	pmark_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	pmark_next_node

pmark_normal_hnf_0:
	inc	r14
	jmp	pmark_next_node

pmark_node2_bb:
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,3

	cmp	rsi,20000000h
	jbe	pmark_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	pmark_next_node

pmark_record:
	sub	rbp,258
	je	pmark_record_2
	jl	pmark_record_1

pmark_record_3:
	add	r14,3

	cmp	rsi,20000000h
	jbe	pmark_fits_in_word_13
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_13:
	mov	rdx,qword ptr 8[rcx]

	movzx	rbx,word ptr (-2+2)[rax]
	lea	rsi,[r10+rdx] 

	mov	rax,rsi 
	and	rsi,31*8

	shr	rax,8
	sub	rbx,1

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rsi]
 else
	mov	edx,dword ptr (bit_set_table2)[rsi]
 endif
	jb	pmark_record_3_bb

	test	edx,dword ptr [rdi+rax*4]
	jne	pmark_node2

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]

	cmp	rsi,32*8
	jbe	pmark_push_record_arguments
	or	dword ptr 4[rdi+rax*4],1
pmark_push_record_arguments:
	mov	rdx,qword ptr 8[rcx]
	mov	rbp,rbx 
	shl	rbx,3
	add	rdx,rbx 
	sub	rbp,1
	jge	pmark_push_hnf_args

	jmp	pmark_node2

pmark_record_3_bb:
	test	edx,dword ptr [rdi+rax*4]
	jne	pmark_next_node

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]
	
	cmp	rsi,32*8
	jbe	pmark_next_node

	or	dword ptr 4[rdi+rax*4],1
	jmp	pmark_next_node

pmark_record_2:
	cmp	rsi,20000000h
	jbe	pmark_fits_in_word_12
	or	dword ptr 4[rdi+rbx*4],1
pmark_fits_in_word_12:
	add	r14,3

	cmp	word ptr (-2+2)[rax],1
	ja	pmark_record_2_c
	je	pmark_node2
	jmp	pmark_next_node

pmark_record_1:
	cmp	word ptr (-2+2)[rax],0
	jne	pmark_hnf_1

	jmp	pmark_bool

pmark_string_or_array:
	je	pmark_string_

pmark_array:
	mov	rbp,qword ptr 16[rcx]
	test	rbp,rbp 
	je	pmark_lazy_array

	movzx	rax,word ptr (-2)[rbp]

	test	rax,rax 
	je	pmark_strict_basic_array

	movzx	rbp,word ptr (-2+2)[rbp]
	test	rbp,rbp 
	je	pmark_b_record_array

	cmp	rsp,r13
	jb	pmark_array_using_reversal

	sub	rax,256
	cmp	rax,rbp 
	je	pmark_a_record_array

pmark_ab_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr 8[rcx]

	imul	rax,rbp 
	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

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
	jb	pmark_ab_array_lp

pmark_last_ab_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_ab_array_bits:
	mov	rax,qword ptr 8[rcx]
	mov	rdx,qword ptr 16[rcx]
	movzx	rbx,word ptr (-2+2)[rdx]
	movzx	rdx,word ptr (-2)[rdx]
	shl	rbx,3
	lea	rdx,(-2048)[rdx*8]
	push	rbx 
	push	rdx 
	lea	rbp,24[rcx]
	push	r12
	jmp	pmark_ab_array_begin

pmark_ab_array:
	mov	rbx,qword ptr 16[rsp]
	push	rax 
	push	rbp 
	lea	r12,[rbp+rbx]

	call	pmark_stack_nodes

	mov	rbx,qword ptr (8+16)[rsp]
	pop	rbp 
	pop	rax 
	add	rbp,rbx 
pmark_ab_array_begin:
	sub	rax,1
	jnc	pmark_ab_array

	pop	r12
	add	rsp,16
	jmp	pmark_next_node

pmark_a_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr 8[rcx]

	imul	rax,rbp 
	push	rax 

	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

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
	jb	pmark_a_array_lp

pmark_last_a_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_a_array_bits:
	pop	rax 
	lea	rbp,24[rcx]

	push	r12
	lea	r12,24[rcx+rax*8]

	call	pmark_stack_nodes

	pop	r12
	jmp	pmark_next_node

pmark_lazy_array:
	cmp	rsp,r13
	jb	pmark_array_using_reversal

	or	dword ptr [rdi+rbx*4],esi 
	mov	rax,qword ptr 8[rcx]

	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

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
	jb	pmark_lazy_array_lp

pmark_last_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

pmark_end_set_lazy_array_bits:
	mov	rax,qword ptr 8[rcx]
	lea	rbp,24[rcx]

	push	r12
	lea	r12,24[rcx+rax*8]

	call	pmark_stack_nodes

	pop	r12
	jmp	pmark_next_node

pmark_array_using_reversal:
	push	0
	mov	rsi,1
	jmp	pmarkr_node

pmark_strict_basic_array:
	mov	rax,qword ptr 8[rcx]
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset dINT+2
 endif
	jle	pmark_strict_int_or_real_array
 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset BOOL+2
 endif
	je	pmark_strict_bool_array
	add	rax,6+1
	shr	rax,1
	jmp	pmark_basic_array_
pmark_strict_int_or_real_array:
	add	rax,3
	jmp	pmark_basic_array_
pmark_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	jmp	pmark_basic_array_

pmark_b_record_array:
	mov	rbp,qword ptr 8[rcx]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	pmark_basic_array_

pmark_string_:
	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	shr	rax,3

pmark_basic_array_:
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	pmark_next_node

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	pmark_last_string_bits

pmark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	jb	pmark_string_lp

pmark_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	jmp	pmark_next_node

end_pmarkr_using_reversal:
	pop	rdx
	test	rdx,rdx 
	je	pmark_next_node
	mov	qword ptr [rdx],rcx 
	jmp	pmark_next_node


pmarkr_using_reversal:
	push	rcx 
	mov	rsi,1
	mov	rcx,qword ptr [rcx]
	jmp	pmarkr_node

pmarkr_arguments:
	mov	rax,qword ptr [rcx]
	test	al,2
	je	pmarkr_lazy_node

	movzx	rbp,word ptr (-2)[rax]
	test	rbp,rbp 
	je	pmarkr_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	pmarkr_record

	sub	rbp,2
	je	pmarkr_hnf_2
	jb	pmarkr_hnf_1

pmarkr_hnf_3:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rdx,20000000h

	mov	rax,qword ptr 8[rcx]

	jbe	pmarkr_fits_in_word_1
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_1:
	add	rax,r10

	mov	rbx,rax 
	and	rax,31*8

	shr	rbx,8

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rax]
 else
	mov	edx,dword ptr (bit_set_table2)[rax]
 endif
	test	edx,dword ptr [rdi+rbx*4]
	jne	pmarkr_shared_argument_part

pmarkr_no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],edx 
	mov	rdx,qword ptr 8[rcx]

	add	rbp,1
	mov	qword ptr 8[rcx],rsi 

	add	r14,rbp 
	add	rcx,8

	shl	rbp,3
	or	qword ptr [rdx],1

	add	rax,rbp
	add	rdx,rbp

	cmp	rax,32*8
	jbe	pmarkr_fits_in_word_2
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_2:

	mov	rbp ,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rcx 
	lea	rsi,(-8)[rdx]
	mov	rcx,rbp 
	jmp	pmarkr_node

pmarkr_hnf_1:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,40000000h
	jbe	pmarkr_shared_argument_part
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_shared_argument_part:
	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi 
	lea	rsi,2[rcx]
	mov	rcx,rbp
	jmp	pmarkr_node

pmarkr_no_selector_2:
	pop	rbx 
pmarkr_no_selector_1:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	pmarkr_shared_argument_part

	or	dword ptr 4[rdi+rbx*4],1
	jmp	pmarkr_shared_argument_part

pmarkr_lazy_node_1:
	je	pmarkr_no_selector_1

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
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	pmarkr_no_selector_2

	cmp	word ptr (-2)[rbx],2
	jbe	pmarkr_small_tuple_or_record

pmarkr_large_tuple_or_record:
	mov	r8,qword ptr 16[rbp]
	mov	r9,r8

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]
	jne	pmarkr_no_selector_2

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rdx,dword ptr (-8)[rax]
	add	rax,rdx
  else
	mov	eax,dword ptr (-8)[rax]
  endif
	lea	rdx,e__system__nind+0
	pop	rbx 

	mov	qword ptr (-8)[rcx],rdx
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	r8,rcx

	cmp	rax,16
	jl	pmarkr_tuple_selector_node_1
	mov	rdx,r9
	je	pmarkr_tuple_selector_node_2
	mov	rcx,qword ptr (-24)[r9+rax]
	mov	qword ptr [r8],rcx
	jmp	pmarkr_node

pmarkr_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [r8],rcx
	jmp	pmarkr_node
 endif

pmarkr_small_tuple_or_record:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rdx,dword ptr(-8)[rax]
	add	rax,rdx
  else
	mov	eax,(-8)[rax]
  endif
	lea	rdx,e__system__nind+0
	pop	rbx 

	mov	qword ptr (-8)[rcx],rdx
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	r8,rcx
pmarkr_tuple_selector_node_1:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	jmp	pmarkr_node
 else
	mov	eax,(-8)[rax]
	pop	rbx 

	push	rcx
	mov	rcx,qword ptr [rcx]
	mov	eax,4[rax]
	call	near ptr rax
	pop	rdx 

	mov	qword ptr (-8)[rdx],offset e__system__nind
	mov	qword ptr [rdx],rcx 
 endif
	jmp	pmarkr_node

pmarkr_record_selector_node_1:
	je	pmarkr_strict_record_selector_node_1

	mov	rbx,rax
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax
	jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	pmarkr_no_selector_2
	
	cmp	word ptr (-2)[rbx],258
 ifdef NEW_DESCRIPTORS
	jbe	pmarkr_small_record

	mov	r8,qword ptr 16[rbp]
 ifndef PIC
	mov	r9,r8
 endif

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]

 ifdef PIC
	mov	r9,qword ptr 16[rbp]
 endif

	jne	pmarkr_no_selector_2

pmarkr_small_record:
  ifdef PIC
	movsxd	rdx,dword ptr (-8)[rax]
	add	rax,rdx
  else
	mov	eax,dword ptr (-8)[rax]
  endif
	lea	rdx,e__system__nind+0
	pop	rbx 

	mov	qword ptr (-8)[rcx],rdx
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	r8,rcx

	cmp	rax,16
	jle	pmarkr_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
pmarkr_record_selector_node_2:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	jmp	pmarkr_node
 else
	jbe	pmarkr_small_tuple_or_record
	jmp	pmarkr_large_tuple_or_record
 endif

pmarkr_strict_record_selector_node_1:
	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	jne	pmarkr_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	pmarkr_no_selector_2

	cmp	word ptr (-2)[rbx],258
	jle	pmarkr_select_from_small_record

	mov	r8,qword ptr 16[rbp]
 ifndef PIC
	mov	r9,r8
 endif

	add	r8,r10
	mov	rbx,r8 
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]

 ifdef PIC
	mov	r9,qword ptr 16[rbp]
 endif

	jne	pmarkr_no_selector_2

pmarkr_select_from_small_record:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbx,dword ptr(-8)[rax]
	add	rax,rbx
  else
	mov	eax,(-8)[rax]
  endif
	sub	rcx,8

  ifdef PIC
	movzx	ebx,word ptr (4-8)[rax]
  else
	movzx	ebx,word ptr 4[rax]
  endif
	cmp	rbx,16
	jle	pmarkr_strict_record_selector_node_2
	mov	rbx,qword ptr (-24)[r9+rbx]
	jmp	pmarkr_strict_record_selector_node_3
pmarkr_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
pmarkr_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rbx

  ifdef PIC
	movzx	ebx,word ptr (6-8)[rax]
  else
	movzx	ebx,word ptr 6[rax]
  endif
	test	rbx,rbx
	je	pmarkr_strict_record_selector_node_5
	cmp	rbx,16
	jle	pmarkr_strict_record_selector_node_4
	mov	rbp,r9
	sub	rbx,24
pmarkr_strict_record_selector_node_4:
	mov	rbx,qword ptr [rbp+rbx]
	mov	qword ptr 16[rcx],rbx
pmarkr_strict_record_selector_node_5:
	pop	rbx

  ifdef PIC
	mov	rax,qword ptr ((-8-8))[rax]
  else
	mov	rax,qword ptr (-8)[rax]
  endif
	mov	qword ptr [rcx],rax
 else
	mov	eax,(-8)[rax]
	pop	rbx 
	mov	rdx,qword ptr [rcx]
	sub	rcx,8
	mov	eax,4[rax]
	call	near ptr rax
 endif
	jmp	pmarkr_node

pmarkr_indirection_node:
	mov	rcx,qword ptr [rcx]
	jmp	pmarkr_node

pmarkr_hnf_2:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	pmarkr_fits_in_word_6
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_6:

pmarkr_record_2_c:
	mov	rax,qword ptr [rcx]
	mov	rbp,qword ptr 8[rcx]
	or	rax,2
	mov	qword ptr 8[rcx],rsi 
	mov	qword ptr [rcx],rax 
	lea	rsi,8[rcx]
	mov	rcx,rbp 

pmarkr_node:
	lea	rdx,[r10+rcx] 

	cmp	rdx,r11
	jae	pmarkr_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	ebp,dword ptr [r9+rdx]
 else
	mov	ebp,dword ptr (bit_set_table2)[rdx]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	je	pmarkr_arguments

pmarkr_next_node:
	test	rsi,3
	jne	pmarkr_parent

	mov	rbp,qword ptr (-8)[rsi]
	mov	rdx,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr (-8)[rsi],rdx 
	sub	rsi,8

	mov	rcx,rbp 
	and	rbp,3
	and	rcx,-4
	or	rsi,rbp 
	jmp	pmarkr_node

pmarkr_parent:
	mov	rbx,rsi 
	and	rsi,-4
	je	end_pmarkr_using_reversal

	and	rbx,3
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 

	sub	rbx,1
	je	pmarkr_argument_part_parent

	lea	rcx,(-8)[rsi]
	mov	rsi,rbp 
	jmp	pmarkr_next_node
	
pmarkr_argument_part_parent:
	and	rbp,-4
	mov	rdx,rsi 
	mov	rcx,qword ptr (-8)[rbp]
	mov	rbx,qword ptr [rbp]
	mov	qword ptr (-8)[rbp],rbx 
	mov	qword ptr [rbp],rdx 
	lea	rsi,(2-8)[rbp]
	jmp	pmarkr_node

pmarkr_lazy_node:
	movsxd	rbp,dword ptr (-4)[rax]
	test	rbp,rbp 
	je	pmarkr_node2_bb

	add	rcx,8
	cmp	rbp,1
	jle	pmarkr_lazy_node_1
	cmp	rbp,256
	jge	pmarkr_closure_with_unboxed_arguments

	add	rbp,1
	mov	rax,rdx
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,rbp 

	lea	rax,[rax+rbp*8]
	sub	rbp,2

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rax,32*8
	jbe	pmarkr_fits_in_word_7
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_7:
pmarkr_closure_with_unboxed_arguments_2:
	lea	rdx,[rcx+rbp*8]
	mov	rax,qword ptr [rcx]
	or	rax,2
	mov	qword ptr [rcx],rax 
	mov	rcx,qword ptr [rdx]
	mov	qword ptr [rdx],rsi 
	mov	rsi,rdx 
	jmp	pmarkr_node

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

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	sub	rbp,rax 

	or	dword ptr [rdi+rbx*4],edx 
	cmp	rcx,32*8
	jbe	pmarkr_fits_in_word_7_
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_7_:
	pop	rcx
	sub	rbp,2
	jg	pmarkr_closure_with_unboxed_arguments_2
	je	pmarkr_shared_argument_part
	sub	rcx,8
	jmp	pmarkr_next_node

pmarkr_closure_1_with_unboxed_argument:
	sub	rcx,8
	jmp	pmarkr_node2_bb

pmarkr_hnf_0:
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rax,r9
 else
	cmp	rax,offset dINT+2
 endif
	jne	pmarkr_no_int_3

	mov	rbp,qword ptr 8[rcx]
	cmp	rbp,33
	jb	pmarkr_small_int

pmarkr_real_int_bool_or_small_string:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,40000000h
	jbe	pmarkr_next_node
	or	dword ptr 4[rdi+rbx*4],1
	jmp	pmarkr_next_node

pmarkr_small_int:
	shl	rbp,4
 ifdef PIC
	lea	rcx,small_integers+0
	add	rcx,rbp
 else
	lea	rcx,(small_integers)[rbp]
 endif
	jmp	pmarkr_next_node

pmarkr_no_int_3:
 ifdef PIC
	lea	r9,__STRING__+2+0
	cmp	rax,r9
 else
	cmp	rax,offset __STRING__+2
 endif
	jbe	pmarkr_string_or_array

 ifdef PIC
 	lea	r9,CHAR+2+0
 	cmp	rax,r9
 else
 	cmp	rax,offset CHAR+2
 endif
 	jne	pmarkr_no_char_3

	movzx	rbp,byte ptr 8[rcx]
	shl	rbp,4
 ifdef PIC
	lea	rcx,static_characters+0
	add	rcx,rbp
 else
	lea	rcx,(static_characters)[rbp]
 endif
	jmp	pmarkr_next_node

pmarkr_no_char_3:
	jb	pmarkr_real_int_bool_or_small_string

 ifdef NEW_DESCRIPTORS
	lea	rcx,((-8)-2)[rax]
 else
	lea	rcx,((-12)-2)[rax]
 endif
	jmp	pmarkr_next_node

pmarkr_node2_bb:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx 
	
	cmp	rdx,20000000h
	jbe	pmarkr_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	pmarkr_next_node

pmarkr_record:
	sub	rbp,258
	je	pmarkr_record_2
	jl	pmarkr_record_1

pmarkr_record_3:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	pmarkr_fits_in_word_13
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_13:
	movzx	rbx,word ptr (-2+2)[rax]

	mov	rdx,qword ptr 8[rcx]
	lea	rdx,[r10+rdx]
	mov	rax,rdx 
	and	rdx,31*8
	shr	rax,8

	push	rsi 

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif
	test	esi,dword ptr [rdi+rax*4]
	jne	pmarkr_shared_record_argument_part

	add	rbp,1
	or	dword ptr [rdi+rax*4],esi 

	lea	rdx,[rdx+rbp*8]
	add	r14,rbp 

	pop	rsi 

	cmp	rdx,32*8
	jbe	pmarkr_fits_in_word_14
	or	dword ptr 4[rdi+rax*4],1
pmarkr_fits_in_word_14:
	sub	rbx,1
	mov	rdx,qword ptr 8[rcx]
	jl	pmarkr_record_3_bb
	je	pmarkr_shared_argument_part

	mov	qword ptr 8[rcx],rsi 
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
	jmp	pmarkr_node

pmarkr_record_3_bb:
	sub	rcx,8
	jmp	pmarkr_next_node

pmarkr_record_3_aab:
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdx],rcx 
	lea	rsi,1[rdx]
	mov	rcx,rbp 
	jmp	pmarkr_node

pmarkr_shared_record_argument_part:
	mov	rdx,qword ptr 8[rcx]

	pop	rsi 

	test	rbx,rbx 
	jne	pmarkr_shared_argument_part
	sub	rcx,8
	jmp	pmarkr_next_node

pmarkr_record_2:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	pmarkr_fits_in_word_12
	or	dword ptr 4[rdi+rbx*4],1
pmarkr_fits_in_word_12:
	cmp	word ptr (-2+2)[rax],1
	ja	pmarkr_record_2_c
	je	pmarkr_shared_argument_part
	sub	rcx,8
	jmp	pmarkr_next_node

pmarkr_record_1:
	cmp	word ptr (-2+2)[rax],0
	jne	pmarkr_hnf_1
	sub	rcx,8
	jmp	pmarkr_real_int_bool_or_small_string

pmarkr_string_or_array:
	je	pmarkr_string_

pmarkr_array:
	mov	rbp,qword ptr 16[rcx]
	test	rbp,rbp 
	je	pmarkr_lazy_array

	movzx	rax,word ptr (-2)[rbp]
	test	rax,rax 
	je	pmarkr_strict_basic_array

	movzx	rbp,word ptr (-2+2)[rbp]
	test	rbp,rbp
	je	pmarkr_b_record_array

	sub	rax,256
	cmp	rax,rbp 
	je	pmarkr_a_record_array

pmarkr_ab_record_array:
	push	rdx 
	push	rbx 
	mov	rbx,rbp 

	mov	rbp,qword ptr 8[rcx]
	add	rcx,16
	push	rcx 

	shl	rbp,3
	mov	rdx,rax 
	imul	rdx,rbp 

	sub	rax,rbx 
	add	rcx,8
	add	rdx,rcx 

	call	reorder
	
	pop	rcx 

	xchg	rax,rbx 
	mov	rbp,qword ptr (-8)[rcx]
	imul	rax,rbp 
	imul	rbx,rbp 
	add	r14,rbx 
	add	rbx,rax 

	shl	rbx,3
	lea	rbp,[r10+rcx]
	add	rbp,rbx 

	pop	rbx 
	pop	rdx 

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	or	dword ptr [rdi+rbx*4],edx 

	lea	rdx,[rcx+rax*8]
	jmp	pmarkr_r_array

pmarkr_a_record_array:
	imul	rax,qword ptr 8[rcx]
	add	rcx,16
	jmp	pmarkr_lr_array

pmarkr_lazy_array:
	mov	rax,qword ptr 8[rcx]
	add	rcx,16

pmarkr_lr_array:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
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
	jbe	pmarkr_lazy_array_bits

pmarkr_skip_mark_lazy_array_bits:
	add	r14,3
	add	r14,rax 

	cmp	rax,1
	jbe	pmarkr_array_length_0_1

	mov	rbp,qword ptr [rdx]
	mov	rbx,qword ptr [rcx]
	mov	qword ptr [rdx],rbx 
	mov	qword ptr [rcx],rbp 
	
	mov	rbp,qword ptr (-8)[rdx]
	sub	rdx,8
	mov	rbx,qword ptr lazy_array_list+0
	add	rbp,2
	mov	qword ptr [rdx],rbx 
	mov	qword ptr (-8)[rcx],rbp 
	mov	qword ptr (-16)[rcx],rax 
	sub	rcx,16
	mov	qword ptr lazy_array_list+0,rcx 

	mov	rcx,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rsi 
	lea	rsi,(-8)[rdx]
	jmp	pmarkr_node

pmarkr_array_length_0_1:
	lea	rcx,(-16)[rcx]
	jb	pmarkr_next_node

	mov	rbx,qword ptr 24[rcx]
	mov	rbp,qword ptr 16[rcx]
	mov	rdx,qword ptr lazy_array_list+0
	mov	qword ptr 24[rcx],rbp 
	mov	qword ptr 16[rcx],rdx 
	mov	qword ptr [rcx],rax
	mov	qword ptr lazy_array_list+0,rcx
	mov	qword ptr 8[rcx],rbx
	add	rcx,8

	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi 
	lea	rsi,2[rcx]
	mov	rcx,rbp 
	jmp	pmarkr_node
	
pmarkr_b_record_array:
	mov	rbp,qword ptr 8[rcx]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	pmarkr_basic_array

pmarkr_strict_basic_array:
	mov	rax,qword ptr 8[rcx]
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset dINT+2
 endif
	jle	pmarkr_strict_int_or_real_array
 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset BOOL+2
 endif
	je	pmarkr_strict_bool_array
	add	rax,6+1
	shr	rax,1
	jmp	pmarkr_basic_array
pmarkr_strict_int_or_real_array:
	add	rax,3
	jmp	pmarkr_basic_array
pmarkr_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	jmp	pmarkr_basic_array

pmarkr_string_:
	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	shr	rax,3

pmarkr_basic_array:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,rax 

	or	dword ptr [rdi+rbx*4],edx 
	lea	rax,(-8)[rcx+rax*8]
	
	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	jae	pmarkr_next_node

	inc	rbx 
	mov	rbp,1

	cmp	rbx,rax 
	jae	pmarkr_last_string_bits

pmarkr_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax 
	jb	pmarkr_string_lp

pmarkr_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	jmp	pmarkr_next_node
