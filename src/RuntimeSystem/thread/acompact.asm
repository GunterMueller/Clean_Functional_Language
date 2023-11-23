
; mark used nodes and pointers in argument parts and link backward pointers

 if THREAD
	mov	rax,qword ptr heap_size_65_offset[r9]
 else
	mov	rax,qword ptr heap_size_65
 endif
	shl	rax,6
 if THREAD
	mov	qword ptr heap_size_64_65_offset[r9],rax 
 else
	mov	qword ptr heap_size_64_65,rax 
 endif

	lea	rax,(-16000)[rsp]
 if THREAD
	mov	qword ptr end_stack_offset[r9],rax
 else
	mov	qword ptr end_stack,rax
 endif

	mov	rax,qword ptr caf_list

	test	qword ptr flags,4096
	jne	pmarkr

	test	rax,rax 
	je	end_mark_cafs

mark_cafs_lp:
	push	(-8)[rax]

	lea	rsi,8[rax]
	mov	rax,qword ptr [rax]
	lea	rcx,[rsi+rax*8]

 if THREAD
	mov	qword ptr end_vector_offset[r9],rcx
 else
	mov	qword ptr end_vector,rcx 
 endif

	call	rmark_stack_nodes
	
	pop	rax
	test	rax,rax 
	jne	mark_cafs_lp

end_mark_cafs:
 if THREAD
	mov	rsi,qword ptr stack_p_offset[r9]

	mov	rcx,qword ptr stack_top_offset[r9]
	mov	qword ptr end_vector_offset[r9],rcx 
 else
	mov	rsi,qword ptr stack_p

	mov	rcx,qword ptr stack_top
	mov	qword ptr end_vector,rcx 
 endif

	call	rmark_stack_nodes

	call	add_mark_compact_garbage_collect_time
	
	jmp	compact_heap

pmarkr:
	test	rax,rax 
	je	end_rmarkp_cafs

rmarkp_cafs_lp:
	push	(-8)[rax]

	lea	rsi,8[rax]
	mov	rax,qword ptr [rax]
	lea	rcx,[rsi+rax*8]

 if THREAD
	mov	qword ptr end_vector_offset[r9],rcx
 else
	mov	qword ptr end_vector,rcx
 endif

	call	rmarkp_stack_nodes
	
	pop	rax
	test	rax,rax 
	jne	rmarkp_cafs_lp

end_rmarkp_cafs:
 if THREAD
	mov	rsi,qword ptr stack_p_offset[r9]

	mov	rcx,qword ptr stack_top_offset[r9]
	mov	qword ptr end_vector_offset[r9],rcx
 else
	mov	rsi,qword ptr stack_p

	mov	rcx,qword ptr stack_top
	mov	qword ptr end_vector,rcx
 endif

	call	rmarkp_stack_nodes

	call	add_mark_compact_garbage_collect_time
	
	jmp	compact_heap

	include	acompact_rmark.asm

	include	acompact_rmark_prefetch.asm

	include acompact_rmarkr.asm

; compact the heap

compact_heap:

	mov	rcx,offset finalizer_list
	mov	rdx,offset free_finalizer_list

	mov	rbp,qword ptr [rcx]
determine_free_finalizers_after_compact1:
 if THREAD
 	lea	rax,__Nil-8
	cmp	rbp,rax
 else
	lea	r9,__Nil-8
	cmp	rbp,r9
 endif
	je	end_finalizers_after_compact1

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif
	add	rax,rbp 
	mov	rbx,rax 
	and	rax,31*9
	shr	rbx,8
	mov	esi,dword ptr (bit_set_table2)[rax]
	test	esi,dword ptr [rdi+rbx*4]
	je	finalizer_not_used_after_compact1

	mov	rax,qword ptr [rbp]
	mov	rsi,rbp 
	jmp	finalizer_find_descriptor

finalizer_find_descriptor_lp:
	and	rax,-4
	mov	rsi,rax 
	mov	rax,qword ptr [rax]
finalizer_find_descriptor:
	test	rax,1
	jne	finalizer_find_descriptor_lp

	mov	qword ptr [rsi],offset e____system__kFinalizerGCTemp+2

	cmp	rbp,rcx 
	ja	finalizer_no_reverse

	mov	rax,qword ptr [rbp]
	lea	rsi,1[rcx]
	mov	qword ptr [rbp],rsi 
	mov	qword ptr [rcx],rax 

finalizer_no_reverse:
	lea	rcx,8[rbp]
	mov	rbp,qword ptr 8[rbp]
	jmp	determine_free_finalizers_after_compact1

finalizer_not_used_after_compact1:
	mov	qword ptr [rbp],offset e____system__kFinalizerGCTemp+2

	mov	qword ptr [rdx],rbp 
	lea	rdx,8[rbp]

	mov	rbp ,qword ptr 8[rbp]
	mov	qword ptr [rcx],rbp 

	jmp	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	mov	qword ptr [rdx],rbp 

	mov	rcx,qword ptr finalizer_list
 if THREAD
	lea	rax,__Nil-8
	cmp	rcx,rax
 else
	lea	r9,__Nil-8
	cmp	rcx,r9
endif
	je	finalizer_list_empty
	test	rcx,3
	jne	finalizer_list_already_reversed
	mov	rax,qword ptr [rcx]
	mov	qword ptr [rcx],offset finalizer_list+1
	mov	qword ptr finalizer_list,rax 
finalizer_list_already_reversed:
finalizer_list_empty:

	mov	rbp ,offset free_finalizer_list
 if THREAD
	lea	rax,__Nil-8
	cmp	qword ptr [rbp],rax
 else
	lea	r9,__Nil-8
	cmp	qword ptr [rbp],r9
 endif
	je	free_finalizer_list_empty

 if THREAD
	mov	qword ptr end_vector_offset[r9],offset free_finalizer_list+8
 else
	mov	qword ptr end_vector,offset free_finalizer_list+8
 endif

	test	qword ptr flags,4096
	je	no_pmarkr
	call	rmarkp_stack_nodes
	jmp	free_finalizer_list_empty
no_pmarkr:
	call	rmark_stack_nodes

free_finalizer_list_empty:

 if THREAD
	mov	rax,qword ptr heap_size_65_offset[r9]
 else
	mov	rax,qword ptr heap_size_65
 endif
	mov	rbx,rax 
	shl	rbx,6

 if THREAD
	add	rbx,qword ptr heap_p3_offset[r9]
	mov	qword ptr end_heap_p3_offset[r9],rbx 
 else
	add	rbx,qword ptr heap_p3
	mov	qword ptr end_heap_p3,rbx 
 endif

	add	rax,3
	shr	rax,2
	mov	r12,rax

 if THREAD
	mov	r8,qword ptr heap_vector_offset[r9]
 else
	mov	r8,qword ptr heap_vector
 endif

	lea	rbx,4[r8]
	neg	rbx
 if THREAD
	mov	qword ptr neg_heap_vector_plus_4_offset[r9],rbx 

 	mov	rdi,qword ptr heap_p3_offset[r9]
 else
	mov	qword ptr neg_heap_vector_plus_4,rbx 

	mov	rdi,qword ptr heap_p3
 endif
	xor	rsi,rsi 
	jmp	skip_zeros

; %rax ,%rcx ,%rbp : free
find_non_zero_long:
skip_zeros:
	sub	r12,1
	jc	end_move
	mov	esi,dword ptr [r8]
	add	r8,4
	test	rsi,rsi 
	je	skip_zeros
; %rbp : free
end_skip_zeros:
 if THREAD
	mov	rbp,qword ptr neg_heap_vector_plus_4_offset[r9]
 else
	mov	rbp,qword ptr neg_heap_vector_plus_4
 endif

	add	rbp,r8

	shl	rbp,6
 if THREAD
	add	rbp,qword ptr heap_p3_offset[r9]
 else
	add	rbp,qword ptr heap_p3
 endif

bsf_and_copy_nodes:
	movzx	rax,sil
	test	rax,rax
	jne	found_bit1
	movzx	rcx,si
	shr	rcx,8
	jne	found_bit2
	mov	rax,rsi 
	and	rax,0ff0000h
	jne	found_bit3
	mov	rcx,rsi
	shr	rcx,24
	movzx	rcx,byte ptr first_one_bit_table[rcx*1]
	add	rcx,24
	jmp	copy_nodes

found_bit3:
	shr	rax,16
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
	add	rcx,16
	jmp	copy_nodes

found_bit2:
	movzx	rcx,byte ptr first_one_bit_table[rcx*1]
	add	rcx,8
	jmp	copy_nodes

found_bit1:
	movzx	rcx,byte ptr first_one_bit_table[rax*1]

copy_nodes:
	mov	rax,qword ptr [rbp+rcx*8]
	shr	esi,1
	lea	rbp,8[rbp+rcx*8]
	shr	esi,cl
	mov	rcx,rbp

	dec	rax

	test	rax,2
	je	begin_update_list_2

move_argument_part:
	mov	rbx,qword ptr (-18)[rax]
	sub	rax,2

	test	rbx,1
	je	end_list_2
find_descriptor_2:
	and	rbx,-4
	mov	rbx,qword ptr [rbx]
	test	rbx,1
	jne	find_descriptor_2

end_list_2:
	mov	rdx,rbx 
	movzx	rbx,word ptr (-2)[rbx]
	cmp	rbx,256
	jb	no_record_arguments

	movzx	rdx,word ptr (-2+2)[rdx]
	sub	rdx,2
	jae	copy_record_arguments_aa

	sub	rbx,256+3

copy_record_arguments_all_b:
	push	rbx
 if THREAD
	mov	rbx,qword ptr heap_vector_offset[r9]
 else
	mov	rbx,qword ptr heap_vector
 endif

update_up_list_1r:
	mov	rdx,rax
 if THREAD
	add	rax,qword ptr neg_heap_p3_offset[r9]
 else
	add	rax,qword ptr neg_heap_p3
 endif

	push	rcx 

	mov	rcx,rax 

	shr	rax,8
	and	rcx,31*8

	mov	ecx,dword ptr bit_set_table2[rcx*1]
	mov	eax,dword ptr [rbx+rax*4]

	and	rax,rcx 

	pop	rcx 
	je	copy_argument_part_1r

	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdx],rdi 
	sub	rax,3
	jmp	update_up_list_1r

copy_argument_part_1r:
	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdx],rdi 
	mov	qword ptr [rdi],rax 
	add	rdi,8

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif
	add	rax,rcx
	shr	rax,3

	mov	rbx,rax
	and	rbx,31
	cmp	rbx,1
	jae	bit_in_this_word

	dec	r12
	mov	esi,dword ptr [r8]
	add	r8,4

 if THREAD
	mov	rbp,qword ptr neg_heap_vector_plus_4_offset[r9]
 else
	mov	rbp,qword ptr neg_heap_vector_plus_4
 endif
	add	rbp,r8
	shl	rbp,6
 if THREAD
	add	rbp,qword ptr heap_p3_offset[r9]
 else
	add	rbp,qword ptr heap_p3
 endif

bit_in_this_word:
	shr	esi,1
	add	rbp,8

	pop	rbx 

copy_b_record_argument_part_arguments:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rax 
	add	rdi,8
	sub	rbx,1
	jnc	copy_b_record_argument_part_arguments

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

copy_record_arguments_aa:
	sub	rbx,256+2
	sub	rbx,rdx 
	
	push	rbx 
	push	rdx 

update_up_list_2r:
	mov	rdx,rax 
	mov	rax,qword ptr [rdx]
	mov	rbx,3
	and	rbx,rax 
	sub	rbx,3
	jne	copy_argument_part_2r

	mov	qword ptr [rdx],rdi 
	sub	rax,3
	jmp	update_up_list_2r

copy_argument_part_2r:
	mov	qword ptr [rdx],rdi 
	cmp	rax,rcx 
	jb	copy_record_argument_2

 if THREAD
	cmp	rax,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rax,qword ptr end_heap_p3
 endif
	jae	copy_record_argument_2

	mov	rdx,rax 
	mov	rax,qword ptr [rdx]
	lea	rbx,1[rdi]
	mov	qword ptr [rdx],rbx 
copy_record_argument_2:
	mov	qword ptr [rdi],rax 
	add	rdi,8

	pop	rbx 
	sub	rbx,1
	jc	no_pointers_in_record

copy_record_pointers:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jb	copy_record_pointers_2

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jae	copy_record_pointers_2

	mov	rax,qword ptr [rdx]
	inc	rdi 
	mov	qword ptr [rdx],rdi 
	dec	rdi 
	mov	rdx,rax 
copy_record_pointers_2:
	mov	qword ptr [rdi],rdx 
	add	rdi,8
	sub	rbx,1
	jnc	copy_record_pointers

no_pointers_in_record:
	pop	rbx 
	
	sub	rbx,1
	jc	no_non_pointers_in_record

copy_non_pointers_in_record:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rax 
	add	rdi,8
	sub	rbx,1
	jnc	copy_non_pointers_in_record

no_non_pointers_in_record:

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

no_record_arguments:
	sub	rbx,3
update_up_list_2:
	mov	rdx,rax
	mov	rax,qword ptr [rax]
	inc	rax
	mov	qword ptr [rdx],rdi
	test	al,3
	jne	copy_argument_part_2

	sub	rax,4
	jmp	update_up_list_2

copy_argument_part_2:
	dec	rax 
	cmp	rax,rcx 
	jc	copy_arguments_1

 if THREAD
	cmp	rax,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rax,qword ptr end_heap_p3
 endif
	jnc	copy_arguments_1

	mov	rdx,rax
	mov	rax,qword ptr [rax]
	inc	rdi 
	mov	qword ptr [rdx],rdi 
	dec	rdi 
copy_arguments_1:
	mov	qword ptr [rdi],rax 
	add	rdi,8

copy_argument_part_arguments:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	copy_arguments_2

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	copy_arguments_2

	mov	rax,qword ptr [rdx]
	inc	rdi 
	mov	qword ptr [rdx],rdi 
	dec	rdi
	mov	rdx,rax 
copy_arguments_2:
	mov	qword ptr [rdi],rdx 
	add	rdi,8
	sub	rbx,1
	jnc	copy_argument_part_arguments

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

update_list_2_:
	dec	rax 
	mov	qword ptr [rdx],rdi 
begin_update_list_2:
	mov	rdx,rax 
	mov	rax,qword ptr [rax]
update_list__2:
	test	rax,1
	jz	end_update_list_2
	test	rax,2
	jz	update_list_2_
	lea	rdx,(-3)[rax]
	mov	rax,qword ptr (-3)[rax]
	jmp	update_list__2

end_update_list_2:
	mov	qword ptr [rdx],rdi 

	mov	qword ptr [rdi],rax 
	add	rdi,8

	test	al,2
	je	move_lazy_node

	movzx	rbx,word ptr (-2)[rax]
	test	rbx,rbx 
	je	move_hnf_0

	cmp	rbx,256
	jae	move_record

	sub	rbx,2
	jc	move_hnf_1
	je	move_hnf_2

move_hnf_3:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_hnf_3_1

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_hnf_3_1

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx 
move_hnf_3_1:
	mov	qword ptr [rdi],rdx 
	
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_hnf_3_2

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_hnf_3_2

	lea	rax,(8+2+1)[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx
move_hnf_3_2:
	mov	qword ptr 8[rdi],rdx 
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_hnf_2:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_hnf_2_1

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_hnf_2_1

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx 
move_hnf_2_1:
	mov	qword ptr [rdi],rdx 
	
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_hnf_2_2

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_hnf_2_2

	lea	rax,(8+1)[rdi]
	mov	rbx ,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx
move_hnf_2_2:
	mov	qword ptr 8[rdi],rdx 
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_hnf_1:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_hnf_1_

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_hnf_1_

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx
move_hnf_1_:
	mov	qword ptr [rdi],rdx 
	add	rdi,8

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_record:
	sub	rbx,258
	jb	move_record_1
	je	move_record_2

move_record_3:
	movzx	rbx,word ptr (-2+2)[rax]
	sub	rbx,1
	ja	move_hnf_3

	mov	rdx,qword ptr [rcx]
	lea	rcx,8[rcx]
	jb	move_record_3_1b

move_record_3_1a:
	cmp	rdx,rcx 
	jb	move_record_3_1b

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jae	move_record_3_1b

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx 
move_record_3_1b:
	mov	qword ptr [rdi],rdx 
	add	rdi,8

	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jb	move_record_3_2

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jae	move_record_3_2

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif

	push	rbp 

	add	rax,rdx 

 if THREAD
	mov	rbx,qword ptr heap_vector_offset[r9]
 else
	mov	rbx,qword ptr heap_vector
 endif
	add	rax,8
	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
	mov	ebp,dword ptr bit_set_table2[rbp]
	test	ebp,dword ptr [rbx+rax*4]
	je	not_linked_record_argument_part_3_b

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif
	add	rax,rdi 

	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
	mov	ebp,dword ptr bit_set_table2[rbp]
	or	dword ptr [rbx+rax*4],ebp
	pop	rbp

	jmp	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	or	dword ptr [rbx+rax*4],ebp 

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif
	add	rax,rdi 

	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
	mov	ebp,dword ptr bit_clear_table2[rbp]
	and	dword ptr [rbx+rax*4],ebp 
	pop	rbp 

linked_record_argument_part_3_b:
	mov	rbx,qword ptr [rdx]
	lea	rax,(2+1)[rdi]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx 
move_record_3_2:
	mov	qword ptr [rdi],rdx 
	add	rdi,8

 if THREAD
	mov	rbx,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rbx,qword ptr neg_heap_p3
 endif
	add	rbx,rcx
	shr	rbx,3
	dec	rbx
	and	rbx,31
	cmp	rbx,2
	jb	bit_in_next_word

	shr	esi,2
	add	rbp,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

bit_in_next_word:
	dec	r12
	mov	esi,dword ptr [r8]
	add	r8,4

	and	esi,dword ptr bit_clear_table[rbx*4]

	test	rsi,rsi
	je	skip_zeros
	jmp	end_skip_zeros

move_record_2:
	cmp	word ptr (-2+2)[rax],1
	ja	move_hnf_2
	jb	move_record_2bb

move_record_2_ab:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jb	move_record_2_1

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jae	move_record_2_1

	lea	rax,1[rdi]
	mov	rbx ,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx
move_record_2_1:
	mov	qword ptr [rdi],rdx 
	mov	rbx,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr 8[rdi],rbx 
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_record_1:
	movzx	rbx,word ptr (-2+2)[rax]
	test	rbx,rbx 
	jne	move_hnf_1
	jmp	move_real_int_bool_or_char

move_record_2bb:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rax 
	add	rdi,8
move_real_int_bool_or_char:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rax 
	add	rdi,8
copy_normal_hnf_0:

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_hnf_0:
 if THREAD
	lea	rbx,__STRING__+2
	cmp	rax,rbx
 else
	lea	r9,__STRING__+2
	cmp	rax,r9
 endif
	jbe	move_string_or_array
	cmp	rax,offset CHAR+2
	jbe	move_real_int_bool_or_char

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_string_or_array:
	jne	move_array

	mov	rax,qword ptr [rcx]
	add	rax,7
	shr	rax,3

cp_s_arg_lp3:
	mov	rbx,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rbx 
	add	rdi,8
	sub	rax,1
	jnc	cp_s_arg_lp3

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_array:
	test	rsi,rsi
	push	rcx
	jne	bsf_and_end_array_bit

skip_zeros_a:
	sub	r12,1
	mov	esi,dword ptr [r8]
	add	r8,4
	test	rsi,rsi
	je	skip_zeros_a

 if THREAD
	mov	rbp,qword ptr neg_heap_vector_plus_4_offset[r9]
 else
	mov	rbp,qword ptr neg_heap_vector_plus_4
 endif
	add	rbp,r8

	shl	rbp,6

 if THREAD
	add	rbp,qword ptr heap_p3_offset[r9]
 else
	add	rbp,qword ptr heap_p3
 endif

bsf_and_end_array_bit:
	mov	rax,rsi
	mov	rdx,rsi
	and	rax,0ffh
	jne	a_found_bit1
	and	rdx,0ff00h
	jne	a_found_bit2
	mov	rax,rsi
	mov	rdx,rsi
	and	rax,0ff0000h
	jne	a_found_bit3
	shr	rdx,24
	movzx	rcx,byte ptr first_one_bit_table[rdx*1]
	add	rcx,24
	jmp	end_array_bit
a_found_bit3:
	shr	rax,16
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
	add	rcx,16
	jmp	end_array_bit
a_found_bit2:
	shr	rdx,8
	movzx	rcx,byte ptr first_one_bit_table[rdx*1]
	add	rcx,8
	jmp	end_array_bit
a_found_bit1:
	movzx	rcx,byte ptr first_one_bit_table[rax*1]

end_array_bit:
	lea	rbx,[rbp+rcx*8]
	shr	esi,1
	lea	rbp,8[rbp+rcx*8]
	shr	esi,cl
	pop	rcx

	cmp	rcx,rbx
	jne	move_a_array

move_b_array:
	mov	rdx,qword ptr [rcx]
	mov	qword ptr [rdi],rdx
	mov	rbx,qword ptr 8[rcx]
	add	rcx,8

	movzx	rax,word ptr (-2)[rbx]
	add	rdi,8
	test	rax,rax 
	je	move_strict_basic_array

	sub	rax,256
	imul	rdx,rax 
	mov	rax,rdx
	jmp	cp_s_arg_lp3

move_strict_basic_array:
	mov	rax,rdx
	cmp	rbx,offset dINT+2
	jle	cp_s_arg_lp3
	cmp	rbx,offset BOOL+2
	je	move_bool_array

move_int32_or_real32_array:
	add	rax,1
	shr	rax,1
	jmp	cp_s_arg_lp3

move_bool_array:
	add	rax,7
	shr	rax,3
	jmp	cp_s_arg_lp3

move_a_array:
	mov	rdx,rbx
	sub	rbx,rcx
	shr	rbx,3

	push	rsi
	sub	rbx,1
	jb	end_array
	mov	rsi,qword ptr [rcx]

	mov	rax,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rsi

	mov	qword ptr [rdi],rax 

	mov	rax,qword ptr [rdx]

	mov	rsi,qword ptr 8[rcx]
	add	rcx,16

	mov	qword ptr [rdx],rsi 

	mov	qword ptr 8[rdi],rax 
	add	rdi,16

	test	rax,rax 
	je	st_move_array_lp

	movzx	rsi,word ptr (-2+2)[rax]
	movzx	rax,word ptr (-2)[rax]
	sub	rax,256
	cmp	rax,rsi 
	je	st_move_array_lp

move_array_ab:
	push	rcx 

	mov	rdx,qword ptr (-16)[rdi]
	mov	rbx,rsi 
	imul	rdx,rax 
	shl	rdx,3

	sub	rax,rbx 
	add	rdx,rcx 
	call	reorder

	pop	rcx 
	sub	rbx,1
	sub	rax,1

	push	rbx 
	push	rax 
	push	(-16)[rdi]
	jmp	st_move_array_lp_ab

move_array_ab_lp1:
	mov	rax,qword ptr 16[rsp]
move_array_ab_a_elements:
	mov	rbx,qword ptr [rcx]
	add	rcx,8
	cmp	rbx,rcx 
	jb	move_array_element_ab

 if THREAD
	cmp	rbx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rbx,qword ptr end_heap_p3
 endif
	jnc	move_array_element_ab

	mov	rdx,rbx 
	mov	rbx,qword ptr [rdx]
	inc	rdi
	mov	qword ptr [rdx],rdi 
	dec	rdi
move_array_element_ab:
	mov	qword ptr [rdi],rbx 
	add	rdi,8
	sub	rax,1
	jnc	move_array_ab_a_elements

	mov	rax,qword ptr 8[rsp]
move_array_ab_b_elements:
	mov	rbx,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rbx 
	add	rdi,8
	sub	rax,1
	jnc	move_array_ab_b_elements

st_move_array_lp_ab:
	sub	qword ptr [rsp],1
	jnc	move_array_ab_lp1

	add	rsp,24
	jmp	end_array	

move_array_lp1:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	add	rdi,8
	cmp	rax,rcx 
	jb	move_array_element

 if THREAD
	cmp	rax,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rax,qword ptr end_heap_p3
 endif
	jnc	move_array_element

	mov	rsi,qword ptr [rax]
	mov	rdx,rax 
	mov	qword ptr (-8)[rdi],rsi 
	lea	rax,(-8+1)[rdi]
	mov	qword ptr [rdx],rax 

	sub	rbx,1
	jnc	move_array_lp1

	jmp	end_array

move_array_element:
	mov	qword ptr (-8)[rdi],rax 
st_move_array_lp:
	sub	rbx,1
	jnc	move_array_lp1

end_array:
	pop	rsi

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_lazy_node:
	mov	rdx,rax 
	movsxd	rbx,dword ptr (-4)[rdx]
	test	rbx,rbx 
	je	move_lazy_node_0

	sub	rbx,1
	jle	move_lazy_node_1

	cmp	rbx,256
	jge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_lazy_node_arguments_

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_lazy_node_arguments_

	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdi],rax 
	lea	rax,1[rdi]
	add	rdi,8
	mov	qword ptr [rdx],rax 
	sub	rbx,1
	jnc	move_lazy_node_arguments

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_lazy_node_arguments_:
	mov	qword ptr [rdi],rdx 
	add	rdi,8
	sub	rbx,1
	jnc	move_lazy_node_arguments
	
	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_lazy_node_1:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_lazy_node_1_

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_lazy_node_1_

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
	mov	qword ptr [rdx],rax 
	mov	rdx,rbx 
move_lazy_node_1_:
	mov	qword ptr [rdi],rdx 
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_lazy_node_0:
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_closure_with_unboxed_arguments:
	je	move_closure_with_unboxed_arguments_1
	add	rbx,1
	mov	rax,rbx 
	and	rbx,255
	shr	rax,8
	sub	rbx,rax 
	je	move_non_pointers_of_closure

	push	rax 

move_closure_with_unboxed_arguments_lp:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_closure_with_unboxed_arguments_

 if THREAD
	cmp	rdx,qword ptr end_heap_p3_offset[r9]
 else
	cmp	rdx,qword ptr end_heap_p3
 endif
	jnc	move_closure_with_unboxed_arguments_

	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdi],rax 
	lea	rax,1[rdi]
	add	rdi,8
	mov	qword ptr [rdx],rax 
	sub	rbx,1
	jne	move_closure_with_unboxed_arguments_lp

	pop	rax 
	jmp	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_:
	mov	qword ptr [rdi],rdx 
	add	rdi,8
	sub	rbx,1
	jne	move_closure_with_unboxed_arguments_lp

	pop	rax 

move_non_pointers_of_closure:
	mov	rbx,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rbx 
	add	rdi,8
	sub	rax,1
	jne	move_non_pointers_of_closure

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

move_closure_with_unboxed_arguments_1:
	mov	rax,qword ptr [rcx]
	mov	qword ptr [rdi],rax 
	add	rdi,16

	test	rsi,rsi
	jne	bsf_and_copy_nodes
	jmp	find_non_zero_long

end_move:

	mov	rcx,qword ptr finalizer_list

restore_finalizer_descriptors:
 if THREAD
	lea	rbx,__Nil-8
	cmp	rcx,rbx
 else
	lea	r9,__Nil-8
	cmp	rcx,r9
 endif
	je	end_restore_finalizer_descriptors

	mov	qword ptr [rcx],offset e____system__kFinalizer+2
	mov	rcx,qword ptr 8[rcx]
	jmp	restore_finalizer_descriptors

end_restore_finalizer_descriptors:

