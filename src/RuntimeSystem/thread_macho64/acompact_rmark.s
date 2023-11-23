
rmark_stack_nodes1:
	mov	rbx,qword ptr [rcx]
	lea	rax,1[rsi]
	mov	qword ptr [rsi],rbx
	mov	qword ptr [rcx],rax

rmark_next_stack_node:
	add	rsi,8

rmark_stack_nodes:
	cmp	rsi,qword ptr end_vector_offset[r9]
	je	end_rmark_nodes

rmark_more_stack_nodes:
	mov	rcx,qword ptr [rsi]

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	att_jnc	rmark_next_stack_node

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	mov	ebp,dword ptr [rdi+rbx*4]
	test	rbp,rax 
	att_jne	rmark_stack_nodes1

	or	rbp,rax
	mov	dword ptr [rdi+rbx*4],ebp 

	mov	rax,qword ptr [rcx]
	call	rmark_stack_node

	add	rsi,8
	cmp	rsi,qword ptr end_vector_offset[r9]
	att_jne	rmark_more_stack_nodes
	ret

rmark_stack_node:
	sub	rsp,16
	mov	qword ptr [rsi],rax 
	lea	rbp,1[rsi]
	mov	qword ptr 8[rsp],rsi 
	mov	rbx,-1
	mov	qword ptr [rsp],0
	mov	qword ptr [rcx],rbp 
	jmp	rmark_no_reverse

rmark_node_d1:
	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	jnc	rmark_next_node

	jmp	rmark_node_

rmark_hnf_2:
	lea	rbx,8[rcx]
	mov	rax,qword ptr 8[rcx]
	sub	rsp,16

	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]

	mov	qword ptr 8[rsp],rbx 
	mov	qword ptr [rsp],rax 

	cmp	rsp,qword ptr end_stack_offset[r9]
	jb	rmark_using_reversal

rmark_node:
	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	att_jnc	rmark_next_node

	mov	rbx,rsi 

rmark_node_:
	mov	rdx,rax 
	and	rax,31*8
	shr	rdx,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	mov	ebp,dword ptr [rdi+rdx*4]
	test	rbp,rax 
	jne	rmark_reverse_and_mark_next_node
	
	or	rbp,rax 
	mov	dword ptr [rdi+rdx*4],ebp 

	mov	rax,qword ptr [rcx]
rmark_arguments:
	cmp	rcx,rbx 
	att_ja	rmark_no_reverse

	lea	rbp,1[rsi]
	mov	qword ptr [rsi],rax 
	mov	qword ptr [rcx],rbp 

rmark_no_reverse:
	test	al,2
	je	rmark_lazy_node

	movzx	rbp,word ptr (-2)[rax]
	test	rbp,rbp 
	je	rmark_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	rmark_record

	sub	rbp,2
	att_je	rmark_hnf_2
	jc	rmark_hnf_1

rmark_hnf_3:
	mov	rdx,qword ptr 8[rcx]
rmark_hnf_3_:
	cmp	rsp,qword ptr end_stack_offset[r9]
	jb	rmark_using_reversal_

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rdx 

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	test	eax,[rdi+rbx*4]
	jne	rmark_shared_argument_part

	or	dword ptr [rdi+rbx*4],eax 

rmark_no_shared_argument_part:
	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	lea	rsi,8[rcx]
	mov	rcx,qword ptr [rcx]
	lea	rdx,[rdx+rbp*8]
	mov	qword ptr [rsp],rcx 

rmark_push_hnf_args:
	mov	rbx,qword ptr [rdx]
	sub	rsp,16
	mov	qword ptr 8[rsp],rdx 
	sub	rdx,8
	mov	qword ptr [rsp],rbx 

	sub	rbp,1
	att_jg	rmark_push_hnf_args

	mov	rcx,qword ptr [rdx]

	cmp	rdx,rsi 
	ja	rmark_no_reverse_argument_pointer

	lea	rbp,3[rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rdx],rbp 

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	att_jnc	rmark_next_node

	mov	rbx,rdx 
	att_jmp	rmark_node_

rmark_no_reverse_argument_pointer:
	mov	rsi,rdx 
	att_jmp	rmark_node

rmark_shared_argument_part:
	cmp	rdx,rcx 
	att_ja	rmark_hnf_1

	mov	rbx,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr [rdx],rax 
	mov	qword ptr 8[rcx],rbx 
	att_jmp	rmark_hnf_1

rmark_record:
	sub	rbp,258
	je	rmark_record_2
	jb	rmark_record_1

rmark_record_3:
	movzx	rbp,word ptr (-2+2)[rax]
	mov	rdx,qword ptr (16-8)[rcx]
	sub	rbp,1
	jb	rmark_record_3_bb
	je	rmark_record_3_ab
	sub	rbp,1
	je	rmark_record_3_aab
	att_jmp	rmark_hnf_3_

rmark_record_3_bb:
	sub	rcx,8

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	or	dword ptr [rdi+rbp*4],eax 
	
	cmp	rdx,rcx 
	att_ja	rmark_next_node

	add	eax,eax 
	jne	rmark_bit_in_same_word1
	inc	rbp
	mov	rax,1
rmark_bit_in_same_word1:
	test	eax,dword ptr [rdi+rbp*4]
	je	rmark_not_yet_linked_bb

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	add	rax,16

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	or	dword ptr [rdi+rbp*4],eax 

	mov	rbp,qword ptr [rdx]
	lea	rax,(16+2+1)[rcx]
	mov	qword ptr 16[rcx],rbp 
	mov	qword ptr [rdx],rax 
	att_jmp	rmark_next_node

rmark_not_yet_linked_bb:
	or	dword ptr [rdi+rbp*4],eax 
	mov	rbp,qword ptr [rdx]
	lea	rax,(16+2+1)[rcx]
	mov	qword ptr 16[rcx],rbp 
	mov	qword ptr [rdx],rax 
	att_jmp	rmark_next_node

rmark_record_3_ab:
	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	or	dword ptr [rdi+rbp*4],eax 

	cmp	rdx,rcx 
	att_ja	rmark_hnf_1

	add	eax,eax 
	jne	rmark_bit_in_same_word2
	inc	rbp
	mov	rax,1
rmark_bit_in_same_word2:
	test	eax,dword ptr [rdi+rbp*4]
	je	rmark_not_yet_linked_ab

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx
	add	rax,8

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	or	dword ptr [rdi+rbp*4],eax 

	mov	rbp,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr 8[rcx],rbp 
	mov	qword ptr [rdx],rax 
	att_jmp	rmark_hnf_1

rmark_not_yet_linked_ab:
	or	dword ptr [rdi+rbp*4],eax 
	mov	rbp,qword ptr [rdx]
	lea	rax,(8+2+1)[rcx]
	mov	qword ptr 8[rcx],rbp 
	mov	qword ptr [rdx],rax 
	att_jmp	rmark_hnf_1

rmark_record_3_aab:
	cmp	rsp,qword ptr end_stack_offset[r9]
	att_jb	rmark_using_reversal_

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rdx 

	mov	rbp,rax 
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	test	eax,dword ptr [rdi+rbp*4]
	att_jne	rmark_shared_argument_part
	or	dword ptr [rdi+rbp*4],eax 

	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	lea	rsi,8[rcx]
	mov	rcx,qword ptr [rcx]
	mov	qword ptr [rsp],rcx 

	mov	rcx,qword ptr [rdx]

	cmp	rdx,rsi 
	att_ja	rmark_no_reverse_argument_pointer

	lea	rbp,3[rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr [rdx],rbp 

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	att_jnc	rmark_next_node

	mov	rbx,rdx 
	att_jmp	rmark_node_

rmark_record_2:
	cmp	word ptr (-2+2)[rax],1
	att_ja	rmark_hnf_2
	att_je	rmark_hnf_1
	att_jmp	rmark_next_node

rmark_record_1:
	cmp	word ptr (-2+2)[rax],0
	att_jne	rmark_hnf_1
	att_jmp	rmark_next_node

rmark_lazy_node_1:
/* selectors: */
	jne	rmark_selector_node_1

rmark_hnf_1:
	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]
	att_jmp	rmark_node

/* selectors */
rmark_indirection_node:
	mov	rdx,qword ptr neg_heap_p3_offset[r9]
	sub	rcx,8
	add	rdx,rcx 

	mov	rbp,rdx 
	and	rbp,31*8
	shr	rdx,8
	lea	r11,bit_clear_table2[rip]
	mov	ebp,dword ptr [r11+rbp]
	and	dword ptr [rdi+rdx*4],ebp 

	mov	rdx,rcx
	cmp	rcx,rbx 
	mov	rcx,qword ptr 8[rcx]
	mov	qword ptr [rsi],rcx 
	att_ja	rmark_node_d1
	mov	qword ptr [rdx],rax 
	att_jmp	rmark_node_d1

rmark_selector_node_1:
	add	rbp,3
	att_je	rmark_indirection_node

	mov	rdx,qword ptr [rcx]
	mov	r12,rbx

	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	add	rbx,rdx 
	shr	rbx,3

	add	rbp,1
	jle	rmark_record_selector_node_1

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
	lea	r11,bit_set_table[rip]
	mov	ebp,dword ptr [r11+rbp*4]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	att_jne	rmark_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	att_je	rmark_hnf_1

	cmp	word ptr (-2)[rbx],2
	jbe	rmark_small_tuple_or_record

rmark_large_tuple_or_record:
	mov	r10,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	add	rbx,r10
	shr	rbx,3

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
	lea	r11,bit_set_table[rip]
	mov	ebp,dword ptr [r11+rbp*4]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	att_jne	rmark_hnf_1

	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	lea	rbx,(-8)[rcx+rbx]

	movsxd	r11,dword ptr (-8)[rax]
	add	rax,r11

	mov	r11,rbx 
	and	r11,31*8
	shr	rbx,8
	lea	r13,bit_clear_table2[rip]
	mov	r11d,dword ptr [r13+r11]
	and	dword ptr [rdi+rbx*4],r11d

	movzx	eax,word ptr (4-8)[rax]
	mov	rbx,r12

	lea	r11,e__system__nind[rip]
	mov	qword ptr (-8)[rcx],r11

	cmp	rax,16
	jl	rmark_tuple_or_record_selector_node_2

	mov	rdx,rcx
	je	rmark_tuple_selector_node_2

	mov	rcx,qword ptr (-24)[r10+rax]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rdx],rcx
	att_jmp	rmark_node_d1

rmark_tuple_selector_node_2:
	mov	rcx,qword ptr [r10]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rdx],rcx
	att_jmp	rmark_node_d1

rmark_record_selector_node_1:
	je	rmark_strict_record_selector_node_1

	mov	rbp,rbx
	shr	rbx,5
	and	rbp,31
	lea	r11,bit_set_table[rip]
	mov	ebp,dword ptr [r11+rbp*4]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp
	att_jne	rmark_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	att_je	rmark_hnf_1

	cmp	word ptr (-2)[rbx],258
	att_jbe	rmark_small_tuple_or_record

	mov	r10,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	add	rbx,r10
	shr	rbx,3

	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
	lea	r11,bit_set_table[rip]
	mov	ebp,dword ptr [r11+rbp*4]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	att_jne	rmark_hnf_1

rmark_small_tuple_or_record:
	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	lea	rbx,(-8)[rcx+rbx]

	movsxd	r11,dword ptr(-8)[rax]
	add	rax,r11

	mov	r11,rbx
	and	r11,31*8
	shr	rbx,8
	lea	r13,bit_clear_table2[rip]
	mov	r11d,dword ptr [r13+r11]
	and	dword ptr [rdi+rbx*4],r11d 

	movzx	eax,word ptr (4-8)[rax]
	mov	rbx,r12

	lea	r11,e__system__nind[rip]
	mov	qword ptr (-8)[rcx],r11

	cmp	rax,16
	att_jle	rmark_tuple_or_record_selector_node_2
	mov	rdx,r10
	sub	rax,24
rmark_tuple_or_record_selector_node_2:
	mov	rbp,rcx
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rsi],rcx
	mov	qword ptr [rbp],rcx
	mov	rdx,rbp
	att_jmp	rmark_node_d1

rmark_strict_record_selector_node_1:
	mov	rbp,rbx 
	shr	rbx,5
	and	rbp,31
	lea	r11,bit_set_table[rip]
	mov	ebp,dword ptr [r11+rbp*4]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp 
	att_jne	rmark_hnf_1

	mov	rbx,qword ptr [rdx]
	test	bl,2
	att_je	rmark_hnf_1

	cmp	word ptr (-2)[rbx],258
	jbe	rmark_select_from_small_record

	mov	r10,qword ptr 16[rdx]

	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	add	rbx,r10
	mov	rbp,rbx 

	shr	rbx,8
	and	rbp,31*8
	lea	r11,bit_set_table2[rip]
	mov	ebp,dword ptr [r11+rbp]
	mov	ebx,dword ptr [rdi+rbx*4]
	and	rbx,rbp
	att_jne	rmark_hnf_1

rmark_select_from_small_record:
	movsxd	rbx,dword ptr(-8)[rax]
	add	rbx,rax
	sub	rcx,8

	cmp	rcx,r12
	ja	rmark_selector_pointer_not_reversed

	movzx	eax,word ptr (4-8)[rbx]
	cmp	rax,16
	jle	rmark_strict_record_selector_node_2
	mov	rax,qword ptr (-24)[r10+rax]
	jmp	rmark_strict_record_selector_node_3
rmark_strict_record_selector_node_2:
	mov	rax,qword ptr [rdx+rax]
rmark_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rax

	movzx	eax,word ptr (6-8)[rbx]
	test	rax,rax
	je	rmark_strict_record_selector_node_5
	cmp	rax,16
	jle	rmark_strict_record_selector_node_4
	mov	rdx,r10
	sub	rax,24
rmark_strict_record_selector_node_4:
	mov	rax,qword ptr [rdx+rax]
	mov	qword ptr 16[rcx],rax
rmark_strict_record_selector_node_5:

	mov	rax,qword ptr ((-8)-8)[rbx]

	add	rsi,1
	mov	qword ptr [rcx],rsi 
	mov	qword ptr (-1)[rsi],rax 
	att_jmp	rmark_next_node

rmark_selector_pointer_not_reversed:
	movzx	eax,word ptr (4-8)[rbx]
	cmp	rax,16
	jle	rmark_strict_record_selector_node_6
	mov	rax,qword ptr (-24)[r10+rax]
	jmp	rmark_strict_record_selector_node_7
rmark_strict_record_selector_node_6:
	mov	rax,qword ptr [rdx+rax]
rmark_strict_record_selector_node_7:
	mov	qword ptr 8[rcx],rax

	movzx	eax,word ptr (6-8)[rbx]
	test	rax,rax
	je	rmark_strict_record_selector_node_9
	cmp	rax,16
	jle	rmark_strict_record_selector_node_8
	mov	rdx,r10
	sub	rax,24
rmark_strict_record_selector_node_8:
	mov	rax,qword ptr [rdx+rax]
	mov	qword ptr 16[rcx],rax
rmark_strict_record_selector_node_9:

	mov	rax,qword ptr ((-8)-8)[rbx]
	mov	qword ptr [rcx],rax
	att_jmp	rmark_next_node

rmark_reverse_and_mark_next_node:
	cmp	rcx,rbx 
	att_ja	rmark_next_node

	mov	rax,qword ptr [rcx]
	mov	qword ptr [rsi],rax 
	add	rsi,1
	mov	qword ptr [rcx],rsi 

/* rbp,rbx : free */

rmark_next_node:
	mov	rcx,qword ptr [rsp]
	mov	rsi,qword ptr 8[rsp]
	add	rsp,16

	cmp	rcx,1
	att_ja	rmark_node

rmark_next_node_:
end_rmark_nodes:
	ret

rmark_lazy_node:
	movsxd	rbp,dword ptr (-4)[rax]
	test	rbp,rbp
	att_je	rmark_next_node

	add	rcx,8

	sub	rbp,1
	att_jle	rmark_lazy_node_1

	cmp	rbp,255
	jge	rmark_closure_with_unboxed_arguments

rmark_closure_with_unboxed_arguments_:
	lea	rcx,[rcx+rbp*8]

rmark_push_lazy_args:
	mov	rbx,qword ptr [rcx]
	sub	rsp,16
	mov	qword ptr 8[rsp],rcx 
	sub	rcx,8
	mov	qword ptr [rsp],rbx 
	sub	rbp,1
	att_jg	rmark_push_lazy_args

	mov	rsi,rcx 
	mov	rcx,qword ptr [rcx]

	cmp	rsp,qword ptr end_stack_offset[r9]
	att_jae	rmark_node

	att_jmp	rmark_using_reversal

rmark_closure_with_unboxed_arguments:
/* (a_size+b_size)+(b_size<<8) */
/*	addl	$1,%rbp  */
	mov	rax,rbp 
	and	rbp,255
	shr	rax,8
	sub	rbp,rax 
/*	subl	$1,%rbp  */
	att_jg	rmark_closure_with_unboxed_arguments_
	att_je	rmark_hnf_1
	att_jmp	rmark_next_node

rmark_hnf_0:
	lea	rbp,dINT+2[rip]
	cmp	rax,rbp
	je	rmark_int_3

	lea	rbp,CHAR+2[rip]
	cmp	rax,rbp
 	je	rmark_char_3

	jb	rmark_no_normal_hnf_0

	mov	rbp,qword ptr neg_heap_p3_offset[r9]
	add	rbp,rcx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
	lea	r11,bit_clear_table2[rip]
	mov	edx,dword ptr [r11+rdx]
	and	dword ptr [rdi+rbp*4],edx 

	lea	rdx,((-8)-2)[rax]
	mov	qword ptr [rsi],rdx 
	cmp	rcx,rbx 
	att_ja	rmark_next_node
	mov	qword ptr [rcx],rax 
	att_jmp	rmark_next_node

rmark_int_3:
	mov	rbp,qword ptr 8[rcx]
	cmp	rbp,33
	att_jnc	rmark_next_node

	shl	rbp,4
	lea	rdx,small_integers[rip]
	add	rdx,rbp
	mov	rbp,qword ptr neg_heap_p3_offset[r9]
	mov	qword ptr [rsi],rdx 
	add	rbp,rcx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
	lea	r11,bit_clear_table2[rip]
	mov	edx,dword ptr [r11+rdx]
	and	dword ptr [rdi+rbp*4],edx 

	cmp	rcx,rbx
	att_ja	rmark_next_node
	mov	qword ptr [rcx],rax 
	att_jmp	rmark_next_node

rmark_char_3:
	movzx	rdx,byte ptr 8[rcx]
	mov	rbp,qword ptr neg_heap_p3_offset[r9]

	shl	rdx,4
	add	rbp,rcx 
	lea	r11,static_characters[rip]
	add	rdx,r11
	mov	qword ptr [rsi],rdx 

	mov	rdx,rbp 
	and	rdx,31*8
	shr	rbp,8
	lea	r11,bit_clear_table2[rip]
	mov	edx,dword ptr [r11+rdx]
	and	dword ptr [rdi+rbp*4],edx

	cmp	rcx,rbx
	att_ja	rmark_next_node
	mov	qword ptr [rcx],rax 
	att_jmp	rmark_next_node

rmark_no_normal_hnf_0:
	lea	rbp,__ARRAY__+2[rip]
	cmp	rax,rbp
	att_jne	rmark_next_node

	mov	rax,qword ptr 16[rcx]
	test	rax,rax 
	je	rmark_lazy_array

	movzx	rdx,word ptr (-2+2)[rax]
	test	rdx,rdx
	je	rmark_b_array

	movzx	rax,word ptr (-2)[rax]
	test	rax,rax 
	att_je	rmark_b_array

	cmp	rsp,qword ptr end_stack_offset[r9]
	jb	rmark_array_using_reversal

	sub	rax,256
	cmp	rdx,rax 
	mov	rbx,rdx
	je	rmark_a_record_array

rmark_ab_record_array:
	mov	rdx,qword ptr 8[rcx]
	add	rcx,16
	push	rcx

	imul	rdx,rax 
	shl	rdx,3

	sub	rax,rbx 
	add	rcx,8
	add	rdx,rcx 
	att_call	reorder
	
	pop	rcx 
	mov	rax,rbx
	imul	rax,qword ptr (-8)[rcx]
	jmp	rmark_lr_array

rmark_b_array:
	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx
	add	rax,8
	mov	rbp,rax
	and	rax,31*8
	shr	rbp,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	or	dword ptr [rdi+rbp*4],eax

	att_jmp	rmark_next_node

rmark_a_record_array:
	mov	rax,qword ptr 8[rcx]
	add	rcx,16
	cmp	rbx,2
	att_jb	rmark_lr_array

	imul	rax,rbx 
	att_jmp	rmark_lr_array

rmark_lazy_array:
	cmp	rsp,qword ptr end_stack_offset[r9]
	att_jb	rmark_array_using_reversal

	mov	rax,qword ptr 8[rcx]
	add	rcx,16

rmark_lr_array:
	mov	rbx,qword ptr neg_heap_p3_offset[r9]
	add	rbx,rcx 
	shr	rbx,3
	add	rbx,rax 

	mov	rdx,rbx 
	and	rbx,31
	shr	rdx,5
	lea	r11,bit_set_table[rip]
	mov	ebx,dword ptr [r11+rbx*4]
	or	dword ptr [rdi+rdx*4],ebx 

	cmp	rax,1
	jbe	rmark_array_length_0_1

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
	jmp	rmark_array_nodes

rmark_array_nodes1:
	cmp	rcx,rsi 
	ja	rmark_next_array_node

	mov	rbx,qword ptr [rcx]
	lea	rax,1[rsi]
	mov	qword ptr [rsi],rbx 
	mov	qword ptr [rcx],rax 

rmark_next_array_node:
	add	rsi,8
	cmp	rsi,qword ptr [rsp]
	je	end_rmark_array_node

rmark_array_nodes:
	mov	rcx,qword ptr [rsi]

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rcx 

	cmp	rax,qword ptr heap_size_64_65_offset[r9]
	att_jnc	rmark_next_array_node

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
	lea	r11,bit_set_table2[rip]
	mov	eax,dword ptr [r11+rax]
	mov	ebp,dword ptr [rdi+rbx*4]
	test	rbp,rax 
	att_jne	rmark_array_nodes1
	
	or	rbp,rax 
	mov	dword ptr [rdi+rbx*4],ebp 

	mov	rax,qword ptr [rcx]
	call	rmark_array_node

	add	rsi,8
	cmp	rsi,qword ptr [rsp]
	att_jne	rmark_array_nodes

end_rmark_array_node:
	add	rsp,8
	att_jmp	rmark_next_node

rmark_array_node:
	sub	rsp,16
	mov	qword ptr 8[rsp],rsi 
	mov	rbx,rsi
	mov	qword ptr [rsp],1
	att_jmp	rmark_arguments

rmark_array_length_0_1:
	lea	rcx,-16[rcx]
	att_jb	rmark_next_node

	mov	rbx,qword ptr 24[rcx]
	mov	rbp,qword ptr 16[rcx]
	mov	qword ptr 24[rcx],rbp
	mov	rbp,qword ptr 8[rcx] 
	mov	qword ptr 16[rcx],rbp
	mov	qword ptr 8[rcx],rbx
	add	rcx,8
	att_jmp	rmark_hnf_1
