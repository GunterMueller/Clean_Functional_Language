
; mark used nodes and pointers in argument parts and link backward pointers

	mov	rax,qword ptr heap_size_65+0
	shl	rax,6
	mov	qword ptr heap_size_64_65+0,rax 

	lea	rax,(-16000)[rsp]
	mov	qword ptr end_stack+0,rax

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_before_compact+0
	test	rax,rax
	je	no_gc_hook_before_compact
	call	rax
no_gc_hook_before_compact:
 endif

	mov	rax,qword ptr caf_list+0

	test	qword ptr flags+0,4096
	jne	pmarkr

	test	rax,rax 
	je	end_mark_cafs

mark_cafs_lp:
	push	(-8)[rax]

	lea	rsi,8[rax]
	mov	rax,qword ptr [rax]
	lea	rcx,[rsi+rax*8]

	mov	qword ptr end_vector+0,rcx 

	call	rmark_stack_nodes

	pop	rax
	test	rax,rax 
	jne	mark_cafs_lp

end_mark_cafs:
	mov	rsi,qword ptr stack_p+0

	mov	rcx,qword ptr stack_top+0
	mov	qword ptr end_vector+0,rcx 

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

	mov	qword ptr end_vector+0,rcx

	call	rmarkp_stack_nodes
	
	pop	rax
	test	rax,rax 
	jne	rmarkp_cafs_lp

end_rmarkp_cafs:
	mov	rsi,qword ptr stack_p+0

	mov	rcx,qword ptr stack_top+0
	mov	qword ptr end_vector+0,rcx

	call	rmarkp_stack_nodes

	call	add_mark_compact_garbage_collect_time
	
	jmp	compact_heap

	include	acompact_rmark.asm

	include	acompact_rmark_prefetch.asm

	include acompact_rmarkr.asm

; compact the heap

compact_heap:

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_between_mark_and_compact+0
	test	rax,rax
	je	no_gc_hook_between_mark_and_compact
	call	rax
no_gc_hook_between_mark_and_compact:
 endif

 ifdef PIC
	lea	rcx,finalizer_list+0
	lea	rdx,free_finalizer_list+0
 else
	mov	rcx,offset finalizer_list
	mov	rdx,offset free_finalizer_list
 endif

	mov	rbp,qword ptr [rcx]
determine_free_finalizers_after_compact1:
	lea	r9,__Nil-8+0
	cmp	rbp,r9
	je	end_finalizers_after_compact1

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rbp 
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

 ifdef PIC
	lea	r9,e____system__kFinalizerGCTemp+2+0
	mov	qword ptr [rsi],r9
 else
	mov	qword ptr [rsi],offset e____system__kFinalizerGCTemp+2
 endif

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
 ifdef PIC
	lea	r9,e____system__kFinalizerGCTemp+2+0
	mov	qword ptr [rbp],r9
 else
	mov	qword ptr [rbp],offset e____system__kFinalizerGCTemp+2
 endif

	mov	qword ptr [rdx],rbp 
	lea	rdx,8[rbp]

	mov	rbp,qword ptr 8[rbp]
	mov	qword ptr [rcx],rbp 

	jmp	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	mov	qword ptr [rdx],rbp 

	mov	rcx,qword ptr finalizer_list+0
	lea	r9,__Nil-8+0
	cmp	rcx,r9
	je	finalizer_list_empty
	test	rcx,3
	jne	finalizer_list_already_reversed
	mov	rax,qword ptr [rcx]
 ifdef PIC
	lea	r9,finalizer_list+1+0
	mov	qword ptr [rcx],r9
 else
	mov	qword ptr [rcx],offset finalizer_list+1
 endif
	mov	qword ptr finalizer_list+0,rax 
finalizer_list_already_reversed:
finalizer_list_empty:

 ifdef PIC
	lea	rsi,free_finalizer_list+0
 else
	mov	rsi,offset free_finalizer_list
 endif
	lea	r9,__Nil-8+0
	cmp	qword ptr [rsi],r9
	je	free_finalizer_list_empty

 ifdef PIC
	lea	r9,free_finalizer_list+8+0
	mov	qword ptr end_vector+0,r9
 else
	mov	qword ptr end_vector+0,offset free_finalizer_list+8
 endif

	test	qword ptr flags+0,4096
	je	no_pmarkr
	call	rmarkp_stack_nodes
	jmp	free_finalizer_list_empty
no_pmarkr:
	call	rmark_stack_nodes

free_finalizer_list_empty:

	mov	rax,qword ptr heap_size_65+0
	mov	rbx,rax 
	shl	rbx,6

	add	rbx,qword ptr heap_p3+0

	mov	qword ptr end_heap_p3+0,rbx

	add	rax,3
	shr	rax,2
	mov	r12,rax

	mov	r8,qword ptr heap_vector+0

	lea	rbx,4[r8]
	neg	rbx
	mov	qword ptr neg_heap_vector_plus_4+0,rbx 

	mov	rdi,qword ptr heap_p3+0
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
	mov	rbp,qword ptr neg_heap_vector_plus_4+0

	add	rbp,r8

	shl	rbp,6
	add	rbp,qword ptr heap_p3+0

bsf_and_copy_nodes:
	movzx	rax,sil
 ifdef PIC
	lea	r9,first_one_bit_table+0
 endif
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
 ifdef PIC
	movzx	rcx,byte ptr [r9+rcx*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rcx*1]
 endif
	add	rcx,24
	jmp	copy_nodes

found_bit3:
	shr	rax,16
 ifdef PIC
	movzx	rcx,byte ptr [r9+rax*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
 endif
	add	rcx,16
	jmp	copy_nodes

found_bit2:
 ifdef PIC
	movzx	rcx,byte ptr [r9+rcx*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rcx*1]
 endif
	add	rcx,8
	jmp	copy_nodes

found_bit1:
 ifdef PIC
	movzx	rcx,byte ptr [r9+rax*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
 endif
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
	mov	rbx,qword ptr heap_vector+0

update_up_list_1r:
	mov	rdx,rax
	add	rax,qword ptr neg_heap_p3+0

	push	rcx 

	mov	rcx,rax 

	shr	rax,8
	and	rcx,31*8

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	ecx,dword ptr [r9+rcx*1]
 else
	mov	ecx,dword ptr bit_set_table2[rcx*1]
 endif
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

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rcx
	shr	rax,3

	mov	rbx,rax
	and	rbx,31
	cmp	rbx,1
	jae	bit_in_this_word

	dec	r12
	mov	esi,dword ptr [r8]
	add	r8,4

	mov	rbp,qword ptr neg_heap_vector_plus_4+0
	add	rbp,r8
	shl	rbp,6
	add	rbp,qword ptr heap_p3+0

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

	cmp	rax,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rax,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
	jnc	move_hnf_2_2

	lea	rax,(8+1)[rdi]
	mov	rbx,qword ptr [rdx]
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
	jae	move_record_3_2

	mov	rax,qword ptr neg_heap_p3+0

	push	rbp 

	add	rax,rdx 

	mov	rbx,qword ptr heap_vector+0
	add	rax,8
	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	ebp,dword ptr [r9+rbp]
 else
	mov	ebp,dword ptr bit_set_table2[rbp]
 endif
	test	ebp,dword ptr [rbx+rax*4]
	je	not_linked_record_argument_part_3_b

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdi 

	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
 ifdef PIC
	mov	ebp,dword ptr [r9+rbp]
 else
	mov	ebp,dword ptr bit_set_table2[rbp]
 endif
	or	dword ptr [rbx+rax*4],ebp
	pop	rbp

	jmp	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	or	dword ptr [rbx+rax*4],ebp 

	mov	rax,qword ptr neg_heap_p3+0
	add	rax,rdi 

	mov	rbp,rax 
	and	rbp,31*8
	shr	rax,8
 ifdef PIC
	lea	r9,bit_clear_table2+0
	mov	ebp,dword ptr [r9+rbp]
 else
	mov	ebp,dword ptr bit_clear_table2[rbp]
 endif
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

	mov	rbx,qword ptr neg_heap_p3+0
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

 ifdef PIC
	lea	r9,bit_clear_table+0
	and	esi,dword ptr [r9+rbx*4]
 else
	and	esi,dword ptr bit_clear_table[rbx*4]
 endif

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

	cmp	rdx,qword ptr end_heap_p3+0
	jae	move_record_2_1

	lea	rax,1[rdi]
	mov	rbx,qword ptr [rdx]
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
 ifdef PIC
	lea	r9,__STRING__+2+0
	cmp	rax,r9
 else
	cmp	rax,offset __STRING__+2
 endif
	jbe	move_string_or_array
 ifdef PIC
	lea	r9,CHAR+2+0
	cmp	rax,r9
 else
	cmp	rax,offset CHAR+2
 endif
	jbe	move_real_int_bool_or_char
 ifdef PIC
move_normal_hnf_0:
 endif

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
 ifdef PIC
	lea	r9,__ARRAY__+2+0
	cmp	rax,r9
	jb	move_normal_hnf_0
 endif
	test	rsi,rsi
	push	rcx
	jne	bsf_and_end_array_bit

skip_zeros_a:
	sub	r12,1
	mov	esi,dword ptr [r8]
	add	r8,4
	test	rsi,rsi
	je	skip_zeros_a

	mov	rbp,qword ptr neg_heap_vector_plus_4+0
	add	rbp,r8

	shl	rbp,6

	add	rbp,qword ptr heap_p3+0

bsf_and_end_array_bit:
	mov	rax,rsi
 ifdef PIC
	lea	r9,first_one_bit_table+0
 endif
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
 ifdef PIC
	movzx	rcx,byte ptr [r9+rdx*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rdx*1]
 endif
	add	rcx,24
	jmp	end_array_bit
a_found_bit3:
	shr	rax,16
 ifdef PIC
	movzx	rcx,byte ptr [r9+rax*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
 endif
	add	rcx,16
	jmp	end_array_bit
a_found_bit2:
	shr	rdx,8
 ifdef PIC
	movzx	rcx,byte ptr [r9+rdx*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rdx*1]
 endif
	add	rcx,8
	jmp	end_array_bit
a_found_bit1:
 ifdef PIC
	movzx	rcx,byte ptr [r9+rax*1]
 else
	movzx	rcx,byte ptr first_one_bit_table[rax*1]
 endif

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
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rbx,r9
 else
	cmp	rbx,offset dINT+2
 endif
	jle	cp_s_arg_lp3
 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rbx,r9
 else
	cmp	rbx,offset BOOL+2
 endif
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

	cmp	rbx,qword ptr end_heap_p3+0
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

	cmp	rax,qword ptr end_heap_p3+0
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
ifdef PROFILE_GRAPH
	jle	move_selector_or_indirection
else
	jle	move_lazy_node_1
endif

	cmp	rbx,256
	jge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_lazy_node_arguments_

	cmp	rdx,qword ptr end_heap_p3+0
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

ifdef PROFILE_GRAPH
move_selector_or_indirection:
	mov	rbx,257
	cmp	rbx,0
	jmp	move_closure_with_unboxed_arguments
endif

move_lazy_node_1:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	cmp	rdx,rcx 
	jc	move_lazy_node_1_

	cmp	rdx,qword ptr end_heap_p3+0
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

	cmp	rdx,qword ptr end_heap_p3+0
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

	mov	rcx,qword ptr finalizer_list+0

restore_finalizer_descriptors:
	lea	r9,__Nil-8+0
	cmp	rcx,r9
	je	end_restore_finalizer_descriptors

 ifdef PIC
	lea	r9,e____system__kFinalizer+2+0
	mov	qword ptr [rcx],r9
 else
	mov	qword ptr [rcx],offset e____system__kFinalizer+2
 endif
	mov	rcx,qword ptr 8[rcx]
	jmp	restore_finalizer_descriptors

end_restore_finalizer_descriptors:

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_after_compact+0
	test	rax,rax
	je	no_gc_hook_after_compact
	call	rax
no_gc_hook_after_compact:
 endif

