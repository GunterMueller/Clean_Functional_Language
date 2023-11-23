
_TEXT	ends
	_DATA segment
rmarkp_n_queue_items_16:
	dq	0
rmarkp_queue_first:
	dq	0
rmarkp_queue:
	dq	0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0
_DATA	ends
	_TEXT segment

rmarkp_stack_nodes1:
	mov	rbx,qword ptr [rcx]
	lea	rax,1[rsi]
	mov	qword ptr [rsi],rbx
	mov	qword ptr [rcx],rax

rmarkp_next_stack_node:
	add	rsi,8
rmarkp_stack_nodes:
	cmp	rsi,qword ptr end_vector+0
	je	end_rmarkp_nodes

rmarkp_more_stack_nodes:
	mov	rcx,qword ptr [rsi]

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_stack_node

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	mov	ebp,dword ptr [rdi+rbx*4]
	test	rbp,rax 
	jne	rmarkp_stack_nodes1

	or	rbp,rax
	mov	dword ptr [rdi+rbx*4],ebp 

	mov	rax,qword ptr [rcx]
	call	rmarkp_stack_node

	add	rsi,8
	cmp	rsi,qword ptr end_vector+0
	jne	rmarkp_more_stack_nodes
	ret

rmarkp_stack_node:
	sub	rsp,16
	mov	qword ptr [rsi],rax 
	lea	rbp,1[rsi]
	mov	qword ptr 8[rsp],rsi 
	mov	rbx,-1
	mov	qword ptr [rsp],0
	mov	qword ptr [rcx],rbp 
	jmp	rmarkp_no_reverse

rmarkp_node_d1:
	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_node

	jmp	rmarkp_node_

rmarkp_hnf_2:
	lea	rbx,8[rcx]
	mov	rax,qword ptr 8[rcx]
	sub	rsp,16

	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]

	mov	qword ptr 8[rsp],rbx 
	mov	qword ptr [rsp],rax 

	cmp	rsp,qword ptr end_stack+0
	jb	rmark_using_reversal

rmarkp_node:
	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_node

	mov	rbx,rsi 

rmarkp_node_:



	mov	rdx,rax 
	and	rax,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rdx*4]
	jne	rmarkp_reverse_and_mark_next_node

	mov	rbp,qword ptr rmarkp_queue_first+0
	mov	rdx,qword ptr rmarkp_n_queue_items_16+0

	prefetch	[rcx]
 ifdef PIC
	lea	r9,rmarkp_queue+0
	mov	qword ptr [r9+rbp],rcx
	mov	qword ptr 8[r9+rbp],rsi
	mov	qword ptr 16[r9+rbp],rbx
 else
	mov	qword ptr rmarkp_queue[rbp],rcx
	mov	qword ptr rmarkp_queue+8[rbp],rsi
	mov	qword ptr rmarkp_queue+16[rbp],rbx
 endif
	lea	rbx,[rbp+rdx]
	add	rbp,32

	and	rbp,7*32
	and	rbx,7*32

	mov	qword ptr rmarkp_queue_first+0,rbp

	cmp	rdx,-(4*32)
	je	rmarkp_last_item_in_queue

rmarkp_add_items:
	mov	rcx,[rsp]
	cmp	rcx,1
	jbe	rmarkp_add_stacked_item

	mov	rsi,8[rsp]
	add	rsp,16

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_add_items

	mov	rdx,rax
	and	rax,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr bit_set_table2[rax]
 endif
	mov	ebp,dword ptr [rdi+rdx*4]
	test	rbp,rax
	je	rmarkp_add_item

	cmp	rcx,rsi
	ja	rmarkp_add_items

	mov	rax,[rcx]
	mov	[rsi],rax
	add	rsi,1
	mov	[rcx],rsi
	jmp	rmarkp_add_items

rmarkp_add_stacked_item:
	je	rmarkp_last_item_in_queue
rmarkp_add_items2:
	mov	rsi,8[rsp]
	add	rsi,8
	cmp	rsi,qword ptr end_vector+0
	je	rmarkp_last_item_in_queue

	mov	rcx,[rsi]
	mov	8[rsp],rsi

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_add_items2

	mov	rdx,rax
	and	rax,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr bit_set_table2[rax]
 endif
	mov	ebp,dword ptr [rdi+rdx*4]
	test	rbp,rax
	je	rmarkp_add_item2

	mov	rax,[rcx]
	mov	[rsi],rax
	add	rsi,1
	mov	[rcx],rsi
	jmp	rmarkp_add_items2

rmarkp_add_item2:
	prefetch	[rcx]
	mov	rbp,qword ptr rmarkp_queue_first+0
	mov	rdx,qword ptr rmarkp_n_queue_items_16+0

 ifdef PIC
 	lea	r9,rmarkp_queue+0
	mov	qword ptr [r9+rbp],rcx
	mov	qword ptr 8[r9+rbp],rsi
	mov	qword ptr 16[r9+rbp],-1
 else
	mov	qword ptr rmarkp_queue[rbp],rcx
	mov	qword ptr rmarkp_queue+8[rbp],rsi
	mov	qword ptr rmarkp_queue+16[rbp],-1
 endif
	add	rbp,32
	and	rbp,7*32

	sub	rdx,32

	mov	qword ptr rmarkp_queue_first+0,rbp
	mov	qword ptr rmarkp_n_queue_items_16+0,rdx

	cmp	rdx,-(4*32)
	jne	rmarkp_add_items2
	jmp	rmarkp_last_item_in_queue

rmarkp_add_items3:
	mov	rsi,8[rsp]
	add	rsi,8
	cmp	rsi,24[rsp]
	je	rmarkp_last_item_in_queue

	mov	rcx,[rsi]
	mov	8[rsp],rsi

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_add_items3

	mov	rdx,rax
	and	rax,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr bit_set_table2[rax]
 endif
	mov	ebp,[rdi+rdx*4]
	test	rbp,rax
	je	rmarkp_add_item3

	cmp	rcx,rsi
	ja	rmarkp_add_items3

	mov	rax,[rcx]
	mov	[rsi],rax
	add	rsi,1
	mov	[rcx],rsi
	jmp	rmarkp_add_items3

rmarkp_add_item3:
	prefetch	[rcx]
	mov	rbp,qword ptr rmarkp_queue_first+0
	mov	rdx,qword ptr rmarkp_n_queue_items_16+0

 ifdef PIC
	lea	r9,rmarkp_queue+0
	mov	qword ptr [r9+rbp],rcx
	mov	qword ptr 8[r9+rbp],rsi
	mov	qword ptr 16[r9+rbp],rsi
 else
	mov	qword ptr rmarkp_queue[rbp],rcx
	mov	qword ptr rmarkp_queue+8[rbp],rsi
	mov	qword ptr rmarkp_queue+16[rbp],rsi
 endif
	add	rbp,32
	and	rbp,7*32

	sub	rdx,32

	mov	qword ptr rmarkp_queue_first+0,rbp
	mov	qword ptr rmarkp_n_queue_items_16+0,rdx

	cmp	rdx,-(4*32)
	jne	rmarkp_add_items3
	jmp	rmarkp_last_item_in_queue

rmarkp_add_item:
	prefetch	[rcx]
	mov	rbp,qword ptr rmarkp_queue_first+0
	mov	rdx,qword ptr rmarkp_n_queue_items_16+0

 ifdef PIC
	lea	r9,rmarkp_queue+0
	mov	qword ptr [r9+rbp],rcx
	mov	qword ptr 8[r9+rbp],rsi
	mov	qword ptr 16[r9+rbp],rsi
 else
	mov	qword ptr rmarkp_queue[rbp],rcx
	mov	qword ptr rmarkp_queue+8[rbp],rsi
	mov	qword ptr rmarkp_queue+16[rbp],rsi
 endif
	add	rbp,32
	and	rbp,7*32

	sub	rdx,32

	mov	qword ptr rmarkp_queue_first+0,rbp
	mov	qword ptr rmarkp_n_queue_items_16+0,rdx

	cmp	rdx,-(4*32)
	jne	rmarkp_add_items

rmarkp_last_item_in_queue:
 ifdef PIC
	lea	r9,rmarkp_queue+0
	mov	rcx,qword ptr [r9+rbx]
 else
	mov	rcx,qword ptr rmarkp_queue[rbx]
 endif

	mov	rax,qword ptr neg_heap_p3+0

 ifdef PIC
	mov	rsi,qword ptr 8[r9+rbx]
	mov	rbx,qword ptr 16[r9+rbx]
 else
	mov	rsi,qword ptr rmarkp_queue+8[rbx]
	mov	rbx,qword ptr rmarkp_queue+16[rbx]
 endif

	add	rax,rcx

rmarkp_node_no_prefetch:



	mov	rdx,rax 
	and	rax,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	mov	ebp,dword ptr [rdi+rdx*4]
	test	rbp,rax 
	jne	rmarkp_reverse_and_mark_next_node
	
	or	rbp,rax 
	mov	dword ptr [rdi+rdx*4],ebp 

	mov	rax,qword ptr [rcx]
rmarkp_arguments:
	cmp	rcx,rbx 
	ja	rmarkp_no_reverse

	lea	rbp,1[rsi]
	mov	qword ptr [rsi],rax 
	mov	qword ptr [rcx],rbp 

rmarkp_no_reverse:
	test	al,2
	je	rmarkp_lazy_node

	movzx	rbp,word ptr (-2)[rax]
	test	rbp,rbp 
	je	rmarkp_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	rmarkp_record

	sub	rbp,2
	je	rmarkp_hnf_2
	jc	rmarkp_hnf_1

rmarkp_hnf_3:
	mov	rdx,qword ptr 8[rcx]
rmarkp_hnf_3_:
	cmp	rsp,qword ptr end_stack+0
	jb	rmark_using_reversal_

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdx 

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,[rdi+rbx*4]
	jne	rmarkp_shared_argument_part

	or	dword ptr [rdi+rbx*4],eax 

rmarkp_no_shared_argument_part:
	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	lea	rsi,8[rcx]
	mov	rcx,qword ptr [rcx]
	lea	rdx,[rdx+rbp*8]
	mov	qword ptr [rsp],rcx 

rmarkp_push_hnf_args:
	mov	rbx,qword ptr [rdx]
	sub	rsp,16
	mov	qword ptr 8[rsp],rdx 
	sub	rdx,8
	mov	qword ptr [rsp],rbx 

	sub	rbp,1
	jg	rmarkp_push_hnf_args

	mov	rcx,qword ptr [rdx]

	cmp	rdx,rsi 
	ja	rmarkp_no_reverse_argument_pointer

	lea	rbp,3[rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rdx],rbp 

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_node

	mov	rbx,rdx 
	jmp	rmarkp_node_

rmarkp_no_reverse_argument_pointer:
	mov	rsi,rdx 

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_node
	mov	rbx,rsi
	jmp	rmarkp_node_no_prefetch

rmarkp_shared_argument_part:
	cmp	rdx,rcx 
	ja	rmarkp_hnf_1

	mov	rbx,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr [rdx],rax 
	mov	qword ptr 8[rcx],rbx 
	jmp	rmarkp_hnf_1

rmarkp_record:
	sub	rbp,258
	je	rmarkp_record_2
	jb	rmarkp_record_1

rmarkp_record_3:
	movzx	rbp,word ptr (-2+2)[rax]
	mov	rdx,qword ptr (16-8)[rcx]
	sub	rbp,1
	jb	rmarkp_record_3_bb
	je	rmarkp_record_3_ab
	sub	rbp,1
	je	rmarkp_record_3_aab
	jmp	rmarkp_hnf_3_

rmarkp_record_3_bb:
	sub	rcx,8

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	or	dword ptr [rdi+rbp*4],eax 
	
	cmp	rdx,rcx 
	ja	rmarkp_next_node

	add	eax,eax 
	jne	rmarkp_bit_in_same_word1
	inc	rbp
	mov	rax,1
rmarkp_bit_in_same_word1:
	test	eax,dword ptr [rdi+rbp*4]
	je	rmarkp_not_yet_linked_bb

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	add	rax,16

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	or	dword ptr [rdi+rbp*4],eax 

	mov	rbp,qword ptr [rdx]
	lea	rax,(16+2+1)[rcx]
	mov	qword ptr 16[rcx],rbp 
	mov	qword ptr [rdx],rax 
	jmp	rmarkp_next_node

rmarkp_not_yet_linked_bb:
	or	dword ptr [rdi+rbp*4],eax 
	mov	rbp,qword ptr [rdx]
	lea	rax,(16+2+1)[rcx]
	mov	qword ptr 16[rcx],rbp 
	mov	qword ptr [rdx],rax 
	jmp	rmarkp_next_node

rmarkp_record_3_ab:
	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	or	dword ptr [rdi+rbp*4],eax 

	cmp	rdx,rcx 
	ja	rmarkp_hnf_1

	add	eax,eax 
	jne	rmarkp_bit_in_same_word2
	inc	rbp
	mov	rax,1
rmarkp_bit_in_same_word2:
	test	eax,dword ptr [rdi+rbp*4]
	je	rmarkp_not_yet_linked_ab

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	add	rax,8

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	or	dword ptr [rdi+rbp*4],eax 

	mov	rbp,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr 8[rcx],rbp 
	mov	qword ptr [rdx],rax 
	jmp	rmarkp_hnf_1

rmarkp_not_yet_linked_ab:
	or	dword ptr [rdi+rbp*4],eax 
	mov	rbp,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr 8[rcx],rbp 
	mov	qword ptr [rdx],rax 
	jmp	rmarkp_hnf_1

rmarkp_record_3_aab:
	cmp	rsp,qword ptr end_stack+0
	jb	rmark_using_reversal_

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbp*4]
	jne	rmarkp_shared_argument_part
	or	dword ptr [rdi+rbp*4],eax 

	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	lea	rsi,8[rcx]
	mov	rcx,qword ptr [rcx]
	mov	qword ptr [rsp],rcx 

	mov	rcx,qword ptr [rdx]

	cmp	rdx,rsi 
	ja	rmarkp_no_reverse_argument_pointer

	lea	rbp,3[rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rdx],rbp 

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_node

	mov	rbx,rdx 
	jmp	rmarkp_node_

rmarkp_record_2:
	cmp	word ptr (-2+2)[rax],1
	ja	rmarkp_hnf_2
	je	rmarkp_hnf_1
	jmp	rmarkp_next_node

rmarkp_record_1:
	cmp	word ptr (-2+2)[rax],0
	jne	rmarkp_hnf_1
	jmp	rmarkp_next_node

rmarkp_lazy_node_1:
; selectors:
	jne	rmarkp_selector_node_1

rmarkp_hnf_1:
	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]
	jmp	rmarkp_node

; selectors
rmarkp_indirection_node:
	mov	rdx,qword ptr neg_heap_p3+0
	sub	rcx,8
	add	rdx,rcx 

	mov	rbp,rdx 
	and	rbp,31*8
	shr	rdx,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	ebp,dword ptr [r9+rbp]
 else
	mov	ebp,dword ptr (bit_clear_table2)[rbp]
 endif
	and	dword ptr [rdi+rdx*4],ebp 

	mov	rdx,rcx
	cmp	rcx,rbx 
	mov	rcx,qword ptr 8[rcx]
	mov	qword ptr [rsi],rcx 
	ja	rmarkp_node_d1
	mov	qword ptr [rdx],rax 
	jmp	rmarkp_node_d1

rmarkp_selector_node_1:
	add	rbp,3
	je	rmarkp_indirection_node

	mov	rdx,qword ptr [rcx]
	mov	qword ptr pointer_compare_address+0,rbx 

	mov	rbx,qword ptr neg_heap_p3+0
	add	rbx,rdx 
	shr	rbx,3

	add	rbp,1
	jle	rmarkp_record_selector_node_1

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebp,dword ptr [r9+rbp*4]
 else
	mov	ebp,dword ptr (bit_set_table)[rbp*4]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	jne	rmarkp_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	je	rmarkp_hnf_1

	cmp	word ptr (-2)[rbx],2
	jbe	rmarkp_small_tuple_or_record

rmarkp_large_tuple_or_record:
	mov	d2,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3+0
	add	rbx,d2
	shr	rbx,3

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebp,dword ptr [r9+rbp*4]
 else
	mov	ebp,dword ptr (bit_set_table)[rbp*4]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	jne	rmarkp_hnf_1

 ifdef NEW_DESCRIPTORS
	mov	rbx,qword ptr neg_heap_p3+0
	lea	rbx,(-8)[rcx+rbx]

  ifdef PIC
	movsxd	d3,dword ptr(-8)[rax]
	add	rax,d3
  else
	mov	eax,(-8)[rax]
  endif

	mov	d3,rbx 
	and	d3,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	d3d,dword ptr [r9+d3]
 else
	mov	d3d,dword ptr (bit_clear_table2)[d3]
 endif
	and	dword ptr [rdi+rbx*4],d3d

 ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
 else
	movzx	eax,word ptr 4[rax]
 endif
	mov	rbx,qword ptr pointer_compare_address+0

 ifdef PIC
	lea	r9,e__system__nind+0
	mov	qword ptr (-8)[rcx],r9
 else
	mov	qword ptr (-8)[rcx],offset e__system__nind
 endif

	cmp	rax,16
	jl	rmarkp_tuple_or_record_selector_node_2

	mov	rdx,rcx
	je	rmarkp_tuple_selector_node_2

	mov	rcx,qword ptr (-24)[d2+rax]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rdx],rcx
	jmp	rmarkp_node_d1

rmarkp_tuple_selector_node_2:
	mov	rcx,qword ptr [d2]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rdx],rcx
	jmp	rmarkp_node_d1
 else
rmarkp_small_tuple_or_record:
	mov	rbx,qword ptr neg_heap_p3
	lea	rbx,(-8)[rcx+rbx]

	push	rcx

	mov	rcx,rbx 
	and	rcx,31*8
	shr	rbx,8
	mov	ecx,dword ptr (bit_clear_table2)[rcx]
	and	dword ptr [rdi+rbx*4],ecx 

	mov	eax,(-8)[rax]

	mov	rcx,rdx 
	push	rsi
	mov	eax,4[rax]
	call	near ptr rax
	pop	rsi
	pop	rdx

	mov	qword ptr [rsi],rcx 

	mov	rbx,qword ptr pointer_compare_address+0

	mov	qword ptr (-8)[rdx],offset e__system__nind
	mov	qword ptr [rdx],rcx 
	jmp	rmarkp_node_d1
 endif

rmarkp_record_selector_node_1:
	je	rmarkp_strict_record_selector_node_1

	mov	rbp,rbx
	shr	rbx,5
	and	rbp,31
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebp,dword ptr [r9+rbp*4]
 else
	mov	ebp,dword ptr (bit_set_table)[rbp*4]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp
	jne	rmarkp_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	je	rmarkp_hnf_1

	cmp	word ptr (-2)[rbx],258
	jbe	rmarkp_small_tuple_or_record

 ifdef NEW_DESCRIPTORS
	mov	d2,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3+0
	add	rbx,d2
	shr	rbx,3

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebp,dword ptr [r9+rbp*4]
 else
	mov	ebp,dword ptr (bit_set_table)[rbp*4]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	jne	rmarkp_hnf_1

rmarkp_small_tuple_or_record:
	mov	rbx,qword ptr neg_heap_p3+0
	lea	rbx,(-8)[rcx+rbx]

 ifdef PIC
	movsxd	d3,dword ptr(-8)[rax]
	add	rax,d3
 else
	mov	eax,(-8)[rax]
 endif

	mov	d3,rbx
	and	d3,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	d3d,dword ptr [r9+d3]
 else
	mov	d3d,dword ptr (bit_clear_table2)[d3]
 endif
	and	dword ptr [rdi+rbx*4],d3d 

 ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
 else
	movzx	eax,word ptr 4[rax]
 endif
	mov	rbx,qword ptr pointer_compare_address+0

 ifdef PIC
	lea	r9,e__system__nind+0
	mov	qword ptr (-8)[rcx],r9
 else
	mov	qword ptr (-8)[rcx],offset e__system__nind
 endif

	cmp	rax,16
	jle	rmarkp_tuple_or_record_selector_node_2
	mov	rdx,d2
	sub	rax,24
rmarkp_tuple_or_record_selector_node_2:
	mov	rbp,rcx
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rbp],rcx
	mov	rdx,rbp
	jmp	rmarkp_node_d1
 else
	jmp	rmarkp_large_tuple_or_record
 endif

rmarkp_strict_record_selector_node_1:
	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebp,dword ptr [r9+rbp*4]
 else
	mov	ebp,dword ptr (bit_set_table)[rbp*4]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	jne	rmarkp_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	je	rmarkp_hnf_1

	cmp	word ptr (-2)[rbx],258
	jbe	rmarkp_select_from_small_record

	mov	d2,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3+0
	add	rbx,d2
	mov	rbp,rbx 

	shr	rbx,8
	and	rbp,31*8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	ebp,dword ptr [r9+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp
	jne	rmarkp_hnf_1

rmarkp_select_from_small_record:
 ifdef PIC
	movsxd	rbx,dword ptr(-8)[rax]
	add	rbx,rax
 else
	mov	ebx,(-8)[rax]
 endif
	sub	rcx,8

	cmp	rcx,qword ptr pointer_compare_address+0
	ja	rmarkp_selector_pointer_not_reversed

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movzx	eax,word ptr (4-8)[rbx]
  else
	movzx	eax,word ptr 4[rbx]
  endif
	cmp	rax,16
	jle	rmarkp_strict_record_selector_node_2
	mov	rax,qword ptr (-24)[d2+rax]
	jmp	rmarkp_strict_record_selector_node_3
rmarkp_strict_record_selector_node_2:
	mov	rax,qword ptr [rdx+rax]
rmarkp_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rax

  ifdef PIC
	movzx	eax,word ptr (6-8)[rbx]
  else
	movzx	eax,word ptr 6[rbx]
  endif
	test	rax,rax
	je	rmarkp_strict_record_selector_node_5
	cmp	rax,16
	jle	rmarkp_strict_record_selector_node_4
	mov	rdx,d2
	sub	rax,24
rmarkp_strict_record_selector_node_4:
	mov	rax,qword ptr [rdx+rax]
	mov	qword ptr 16[rcx],rax
rmarkp_strict_record_selector_node_5:

  ifdef PIC
	mov	rax,qword ptr ((-8)-8)[rbx]
  else
	mov	rax,qword ptr (-8)[rbx]
  endif
 else
	mov	qword ptr [rcx],rax 
	mov	qword ptr [rsi],rcx 
	
	push	rsi
	mov	ebx,4[rbx]
	call	near ptr rbx
	pop	rsi 

	mov	rax,qword ptr [rcx]
 endif
	add	rsi,1
	mov	qword ptr [rcx],rsi 
	mov	qword ptr (-1)[rsi],rax 
	jmp	rmarkp_next_node

rmarkp_selector_pointer_not_reversed:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movzx	eax,word ptr (4-8)[rbx]
  else
	movzx	eax,word ptr 4[rbx]
  endif
	cmp	rax,16
	jle	rmarkp_strict_record_selector_node_6
	mov	rax,qword ptr (-24)[d2+rax]
	jmp	rmarkp_strict_record_selector_node_7
rmarkp_strict_record_selector_node_6:
	mov	rax,qword ptr [rdx+rax]
rmarkp_strict_record_selector_node_7:
	mov	qword ptr 8[rcx],rax

  ifdef PIC
	movzx	eax,word ptr (6-8)[rbx]
  else
	movzx	eax,word ptr 6[rbx]
  endif
	test	rax,rax
	je	rmarkp_strict_record_selector_node_9
	cmp	rax,16
	jle	rmarkp_strict_record_selector_node_8
	mov	rdx,d2
	sub	rax,24
rmarkp_strict_record_selector_node_8:
	mov	rax,qword ptr [rdx+rax]
	mov	qword ptr 16[rcx],rax
rmarkp_strict_record_selector_node_9:

  ifdef PIC
	mov	rax,qword ptr ((-8)-8)[rbx]
  else
	mov	rax,qword ptr (-8)[rbx]
  endif
	mov	qword ptr [rcx],rax
 else
	mov	ebx,4[rbx]
	call	near ptr rbx
 endif
	jmp	rmarkp_next_node

rmarkp_reverse_and_mark_next_node:
	cmp	rcx,rbx 
	ja	rmarkp_next_node

	mov	rax,qword ptr [rcx]
	mov	qword ptr [rsi],rax 
	add	rsi,1
	mov	qword ptr [rcx],rsi 

; %rbp ,%rbx : free

rmarkp_next_node:
	mov	rcx,qword ptr [rsp]
	mov	rsi,qword ptr 8[rsp]
	add	rsp,16

	cmp	rcx,1
	ja	rmarkp_node

rmarkp_next_node_:
	mov	rdx,qword ptr rmarkp_n_queue_items_16+0
	test	rdx,rdx
	je	end_rmarkp_nodes

	sub	rsp,16

	mov	rbp,qword ptr rmarkp_queue_first+0

	lea	rbx,[rbp+rdx]
	add	rdx,32

	and	rbx,7*32

	mov	qword ptr rmarkp_n_queue_items_16+0,rdx
	jmp	rmarkp_last_item_in_queue

end_rmarkp_nodes:
	ret

rmarkp_lazy_node:
	movsxd	rbp,dword ptr (-4)[rax]
	test	rbp,rbp
	je	rmarkp_next_node

	add	rcx,8

	sub	rbp,1
	jle	rmarkp_lazy_node_1

	cmp	rbp,255
	jge	rmarkp_closure_with_unboxed_arguments

rmarkp_closure_with_unboxed_arguments_:
	lea	rcx,[rcx+rbp*8]

rmarkp_push_lazy_args:
	mov	rbx,qword ptr [rcx]
	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	sub	rcx,8
	mov	qword ptr [rsp],rbx 
	sub	rbp,1
	jg	rmarkp_push_lazy_args

	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]

	cmp	rsp,qword ptr end_stack+0
	jae	rmarkp_node

	jmp	rmark_using_reversal

rmarkp_closure_with_unboxed_arguments:
; (a_size+b_size)+(b_size<<8)
;	addl	$1,%rbp 
	mov	rax,rbp 
	and	rbp,255
	shr	rax,8
	sub	rbp,rax 
;	subl	$1,%rbp 
	jg	rmarkp_closure_with_unboxed_arguments_
	je	rmarkp_hnf_1
	jmp	rmarkp_next_node

rmarkp_hnf_0:
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rax,r9
 else
	cmp	rax,offset dINT+2
 endif
	je	rmarkp_int_3

 ifdef PIC
	lea	r9,CHAR+2+0
	cmp	rax,r9
 else
	cmp	rax,offset CHAR+2
 endif
 	je	rmarkp_char_3

	jb	rmarkp_no_normal_hnf_0

	mov	rbp,qword ptr neg_heap_p3+0
	add	rbp,rcx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_clear_table2)[rdx]
 endif
	and	dword ptr [rdi+rbp*4],edx 

 ifdef NEW_DESCRIPTORS
	lea	rdx,((-8)-2)[rax]
 else
	lea	rdx,((-12)-2)[rax]
 endif
	mov	qword ptr [rsi],rdx 
	cmp	rcx,rbx 
	ja	rmarkp_next_node
	mov	qword ptr [rcx],rax 
	jmp	rmarkp_next_node

rmarkp_int_3:
	mov	rbp,qword ptr 8[rcx]
	cmp	rbp,33
	jnc	rmarkp_next_node

	shl	rbp,4
 ifdef PIC
	lea	rdx,small_integers+0
	add	rdx,rbp
 else
	lea	rdx,(small_integers)[rbp]
 endif
	mov	rbp,qword ptr neg_heap_p3+0
	mov	qword ptr [rsi],rdx 
	add	rbp,rcx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_clear_table2)[rdx]
 endif
	and	dword ptr [rdi+rbp*4],edx 

	cmp	rcx,rbx
	ja	rmarkp_next_node
	mov	qword ptr [rcx],rax 
	jmp	rmarkp_next_node

rmarkp_char_3:
	movzx	rdx,byte ptr 8[rcx]
	mov	rbp,qword ptr neg_heap_p3+0

	shl	rdx,4
	add	rbp,rcx
 ifdef PIC
	lea	r9,static_characters+0
	add	rdx,r9
 else
	add	rdx,offset static_characters
 endif
	mov	qword ptr [rsi],rdx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_clear_table2)[rdx]
 endif
	and	dword ptr [rdi+rbp*4],edx

	cmp	rcx,rbx
	ja	rmarkp_next_node
	mov	qword ptr [rcx],rax 
	jmp	rmarkp_next_node

rmarkp_no_normal_hnf_0:
	lea	r9,__ARRAY__+2+0
	cmp	rax,r9
	jne	rmarkp_next_node

	mov	rax,qword ptr 16[rcx]
	test	rax,rax 
	je	rmarkp_lazy_array

	movzx	rdx,word ptr (-2+2)[rax]
	test	rdx,rdx
	je	rmarkp_b_array

	movzx	rax,word ptr (-2)[rax]
	test	rax,rax 
	je	rmarkp_b_array

	cmp	rsp,qword ptr end_stack+0
	jb	rmark_array_using_reversal

	sub	rax,256
	cmp	rdx,rax 
	mov	rbx,rdx
	je	rmarkp_a_record_array

rmarkp_ab_record_array:
	mov	rdx,qword ptr 8[rcx]
	add	rcx,16
	push	rcx

	imul	rdx,rax 
	shl	rdx,3

	sub	rax,rbx 
	add	rcx,8
	add	rdx,rcx 
	call	reorder
	
	pop	rcx 
	mov	rax,rbx
	imul	rax,qword ptr (-8)[rcx]
	jmp	rmarkp_lr_array

rmarkp_b_array:
	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	add	rax,8
	mov	rbp,rax
	and	rax,31*8
	shr	rbp,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	or	dword ptr [rdi+rbp*4],eax

	jmp	rmarkp_next_node

rmarkp_a_record_array:
	mov	rax,qword ptr 8[rcx]
	add	rcx,16
	cmp	rbx,2
	jb	rmarkp_lr_array

	imul	rax,rbx 
	jmp	rmarkp_lr_array

rmarkp_lazy_array:
	cmp	rsp,qword ptr end_stack+0
	jb	rmark_array_using_reversal

	mov	rax,qword ptr 8[rcx]
	add	rcx,16

rmarkp_lr_array:
	mov	rbx,qword ptr neg_heap_p3+0
	add	rbx,rcx 
	shr	rbx,3
	add	rbx,rax 

	mov	rdx,rbx 
	and	rbx,31
	shr	rdx,5
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	ebx,dword ptr [r9+rbx*4]
 else
	mov	ebx,dword ptr (bit_set_table)[rbx*4]
 endif
	or	dword ptr [rdi+rdx*4],ebx 

	cmp	rax,1
	jbe	rmarkp_array_length_0_1

	mov	rdx,rcx 
	lea	rcx,[rcx+rax*8]

	mov	rax,qword ptr [rcx]

	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 

	mov	qword ptr [rcx],rbx 

	mov	rax,qword ptr (-8)[rcx]
	sub	rcx,8

	mov	rbx,qword ptr (-8)[rdx]

	sub	rdx,8
	mov	qword ptr [rcx],rbx 

	mov	qword ptr [rdx],rax 

	push	rcx
	mov	rsi,rdx 
	jmp	rmarkp_array_nodes

rmarkp_array_nodes1:
	cmp	rcx,rsi 
	ja	rmarkp_next_array_node

	mov	rbx,qword ptr [rcx]
	lea	rax,1[rsi]
	mov	qword ptr [rsi],rbx 
	mov	qword ptr [rcx],rax 

rmarkp_next_array_node:
	add	rsi,8
	cmp	rsi,qword ptr [rsp]
	je	end_rmarkp_array_node

rmarkp_array_nodes:
	mov	rcx,qword ptr [rsi]

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx

	cmp	rax,qword ptr heap_size_64_65+0
	jnc	rmarkp_next_array_node

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	mov	ebp,dword ptr [rdi+rbx*4]
	test	rbp,rax 
	jne	rmarkp_array_nodes1
	
	or	rbp,rax 
	mov	dword ptr [rdi+rbx*4],ebp 

	mov	rax,qword ptr [rcx]
	call	rmarkp_array_node

	add	rsi,8
	cmp	rsi,qword ptr [rsp]
	jne	rmarkp_array_nodes

end_rmarkp_array_node:
	add	rsp,8
	jmp	rmarkp_next_node

rmarkp_array_node:
	sub	rsp,16
	mov	qword ptr 8[rsp],rsi 
	mov	rbx,rsi
	mov	qword ptr [rsp],1
	jmp	rmarkp_arguments

rmarkp_array_length_0_1:
	lea	rcx,-16[rcx]
	jb	rmarkp_next_node

	mov	rbx,qword ptr 24[rcx]
	mov	rbp,qword ptr 16[rcx]
	mov	qword ptr 24[rcx],rbp
	mov	rbp,qword ptr 8[rcx] 
	mov	qword ptr 16[rcx],rbp
	mov	qword ptr 8[rcx],rbx
	add	rcx,8
	jmp	rmarkp_hnf_1
