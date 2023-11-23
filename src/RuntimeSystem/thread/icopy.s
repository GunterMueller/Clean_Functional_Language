
a4_copy_sp_offset	= 0
heap_p1_copy_sp_offset	= 4
heap_p2_copy_sp_offset	= 8
semi_space_size_sp_offset = 12
stack_p_copy_sp_offset	= 16
heap_copied_vector_copy_sp_offset = 20
copy_sp_offset_5	= 24
copy_sp_offset_4	= 28
copy_sp_offset_3	= 32
copy_sp_offset_2	= 36
copy_sp_offset_1	= 40

	push	a3

	lea	-44(sp),sp
	movl	a4,a4_copy_sp_offset(sp)

	movl	heap_p1_offset(a4),d0
	movl	d0,heap_p1_copy_sp_offset(sp)

	movl	stack_p_offset(a4),d0
	movl	d0,stack_p_copy_sp_offset(sp)

	movl	heap_copied_vector_offset(a4),d0
	movl	d0,heap_copied_vector_copy_sp_offset(sp)

	movl	heap_size_129_offset(a4),d0
	shl	$6,d0

	movl	heap_p2_offset(a4),a4
	movl	a4,heap_p2_copy_sp_offset(sp)

	movl	d0,semi_space_size_sp_offset(sp)
	lea	(a4,d0),a3

#ifdef WRITE_HEAP
	movl	a3,heap2_begin_and_end+4
#endif

	movl	caf_list,d0
	test	d0,d0
	je	end_copy_cafs

copy_cafs_lp:
	movl	-4(d0),a1
	movl	(d0),d1
	lea	4(d0),a2

	movl	a1,copy_sp_offset_1(sp)

	subl	$1,d1
	call	copy_lp2

	movl	copy_sp_offset_1(sp),d0
	test	d0,d0
	jne	copy_cafs_lp

end_copy_cafs:
	movl	44(sp),d1

	mov	stack_p_copy_sp_offset(sp),a2
	sub	a2,d1
	shr	$2,d1

	sub	$1,d1
	jb	end_copy0
	call	copy_lp2
end_copy0:
	movl	heap_p2_copy_sp_offset(sp),a2

	jmp	copy_lp1
/
/	Copy all referenced nodes to the other semi space
/

in_hnf_1_2:
	dec	d1
copy_lp2_lp1:
	call	copy_lp2
copy_lp1:
	cmp	a4,a2
	jae	end_copy1

	mov	(a2),d0
	add	$4,a2
	testb	$2,d0b
	je	not_in_hnf_1
in_hnf_1:
	movzwl	-2(d0),d1

	test	d1,d1
	je	copy_array_21

	cmp	$2,d1
	jbe	in_hnf_1_2

	cmp	$256,d1
	jae	copy_record_21
	
	mov	4(a2),d0
	testb	$1,d0b
	jne	node_without_arguments_part

	movl	d1,copy_sp_offset_2(sp)
	xorl	d1,d1
	
	call	copy_lp2

	movl	copy_sp_offset_2(sp),d1
	add	$4,a2

	sub	$2,d1
	jmp	copy_lp2_lp1

node_without_arguments_part:
	dec	d0
	xorl	d1,d1

	mov	d0,4(a2)
	call	copy_lp2
	
	add	$4,a2
	jmp	copy_lp1

copy_record_21:
	subl	$258,d1
	ja	copy_record_arguments_3

	movzwl	-2+2(d0),d1
	jb	copy_record_arguments_1

	subl	$1,d1
	ja	copy_lp2_lp1
	jmp	copy_node_arity1

copy_record_arguments_1:
	dec	d1
	jmp	copy_lp2_lp1

copy_record_arguments_3:
	testb	$1,4(a2)
	jne	record_node_without_arguments_part

	movzwl	-2+2(d0),a1
	subl	$1,a1

	lea	3*4(a2,d1,4),a0
	movl	a0,copy_sp_offset_2(sp)
	movl	a1,copy_sp_offset_3(sp)

	sub	d1,d1
	call	copy_lp2

	addl	$4,a2
	movl	copy_sp_offset_3(sp),d1
	dec	d1
	call	copy_lp2

	movl	copy_sp_offset_2(sp),a2
	jmp	copy_lp1

record_node_without_arguments_part:
	andl	$-2,4(a2)

	sub	d1,d1
	call	copy_lp2
	
	addl	$4,a2
	jmp	copy_lp1

not_in_hnf_1:
	mov	-4(d0),d1
	cmpl	$257,d1
	jge	copy_unboxed_closure_arguments
	sub	$1,d1
	jg	copy_lp2_lp1

copy_node_arity1:
	xorl	d1,d1
	call	copy_lp2

	add	$4,a2
	jmp	copy_lp1

copy_unboxed_closure_arguments:
	je	copy_unboxed_closure_arguments1

	xorl	d0,d0
	movb	d1hb,d0lb
	andl	$255,d1
	sub	d0,d1

	subl	$1,d1
	jl	copy_unboxed_closure_arguments_without_pointers
	
	movl	d0,copy_sp_offset_2(sp)
	call	copy_lp2
	movl	copy_sp_offset_2(sp),d0

copy_unboxed_closure_arguments_without_pointers:
	lea	(a2,d0,4),a2
	jmp	copy_lp1

copy_unboxed_closure_arguments1:
	addl	$8,a2
	jmp	copy_lp1

copy_array_21:
	movl	4(a2),d1
	addl	$8,a2
	test	d1,d1
	je	copy_array_21_a

	movzwl	-2(d1),d0
	movzwl	-2+2(d1),d1
	subl	$256,d0
	test	d1,d1
	je	copy_array_21_b

	cmpl	d0,d1
	je	copy_array_21_r_a

copy_array_21_ab:
	cmpl	$0,-8(a2)
	je	copy_lp1

	subl	d1,d0
	shl	$2,d0
	subl	$1,d1

	movl	d1,copy_sp_offset_2(sp)
	movl	d0,copy_sp_offset_3(sp)
	movl	-8(a2),d1
	subl	$1,d1
	movl	d1,copy_sp_offset_4(sp)

copy_array_21_lp_ab:
	movl	copy_sp_offset_2(sp),d1
	call	copy_lp2

	addl	copy_sp_offset_3(sp),a2
	subl	$1,copy_sp_offset_4(sp)
	jnc	copy_array_21_lp_ab
	
	jmp	copy_lp1

copy_array_21_b:
	movl	-8(a2),d1
	imull	d0,d1
	lea	(a2,d1,4),a2
	jmp	copy_lp1

copy_array_21_r_a:
	movl	-8(a2),d1
	imull	d0,d1
	subl	$1,d1
	jc	copy_lp1
	jmp	copy_lp2_lp1

copy_array_21_a:
	movl	-8(a2),d1
	subl	$1,d1
	jc	copy_lp1
	jmp	copy_lp2_lp1

/
/	Copy nodes to the other semi-space
/

copy_lp2:
	movl	(a2),a1

/ selectors:
continue_after_selector_2:
	movl	(a1),a0
	testb	$2,a0b
	je	not_in_hnf_2

in_hnf_2:
	movzwl	-2(a0),d0
	test	d0,d0
	je	copy_arity_0_node2

	cmp	$256,d0
	jae	copy_record_2

	sub	$2,d0
	mov	a4,(a2)

	lea	4(a2),a2
	ja	copy_hnf_node2_3

	mov	a0,(a4)
	jb	copy_hnf_node2_1

	inc	a4
	mov	4(a1),a0

	mov	a4,(a1)
	mov	8(a1),d0

	sub	$1,d1
	mov	a0,4-1(a4)

	mov	d0,8-1(a4)
	lea	12-1(a4),a4

	jae	copy_lp2
	ret

copy_hnf_node2_1:
	inc	a4
	mov	4(a1),d0

	sub	$1,d1
	mov	a4,(a1)

	mov	d0,4-1(a4)
	lea	8-1(a4),a4

	jae	copy_lp2
	ret

copy_hnf_node2_3:
	mov	a0,(a4)
	inc	a4

	mov	a4,(a1)
	mov	4(a1),a0

	mov	a0,4-1(a4)
	mov	8(a1),a0

	add	$12-1,a4
	mov	(a0),a1
	
	testb	$1,a1b
	jne	arguments_already_copied_2

	mov	a4,-4(a4)
	add	$4,a0

	mov	a1,(a4)
	inc	a4

	mov	a4,-4(a0)
	add	$4-1,a4

cp_hnf_arg_lp2:
	mov	(a0),a1
	add	$4,a0

	mov	a1,(a4)
	add	$4,a4

	dec	d0
	jne	cp_hnf_arg_lp2

	sub	$1,d1
	jae	copy_lp2
	ret

arguments_already_copied_2:
	mov	a1,-4(a4)

	sub	$1,d1
	jae	copy_lp2
	ret

copy_arity_0_node2:
	cmp	$INT+2,a0
	jb	copy_real_file_or_string_2

	cmp	$CHAR+2,a0
	ja	copy_normal_hnf_0_2

	mov	4(a1),d0

	je	copy_char_2

	cmp	$INT+2,a0
	jne	no_small_int_or_char_2

copy_int_2:
	cmp	$33,d0
	jae	no_small_int_or_char_2

	shl	$3,d0
	add	$4,a2

	add	$small_integers,d0
	sub	$1,d1

	mov	d0,-4(a2)
	jae	copy_lp2

	ret

copy_char_2:	
	andl	$255,d0

	shl	$3,d0
	add	$4,a2

	add	$static_characters,d0
	sub	$1,d1

	mov	d0,-4(a2)
	jae	copy_lp2
	ret
	
no_small_int_or_char_2:

copy_record_node2_1_b:
	mov	a0,-8(a3)
	add	$4,a2

	mov	d0,-4(a3)
	sub	$7,a3

	mov	a3,(a1)
	dec	a3
	
	mov	a3,-4(a2)

	sub	$1,d1
	jae	copy_lp2
	ret

copy_normal_hnf_0_2:
	sub	$2-ZERO_ARITY_DESCRIPTOR_OFFSET,a0
	sub	$1,d1

	mov	a0,(a2)
	lea	4(a2),a2

	jae	copy_lp2
	ret

copy_real_file_or_string_2:
	cmpl	$__STRING__+2,a0
	jbe	copy_string_or_array_2

copy_real_or_file_2:
	mov	a0,-12(a3)
	sub	$12-1,a3

	mov	a3,(a1)
	dec	a3

	mov	4(a1),d0
	mov	8(a1),a0

	mov	a3,(a2)
	add	$4,a2

	mov	d0,4(a3)
	sub	$1,d1

	mov	a0,8(a3)

	jae	copy_lp2
	ret

already_copied_2:
	dec	a0
	sub	$1,d1

	mov	a0,(a2)
	lea	4(a2),a2
	
	jae	copy_lp2
	ret

copy_record_2:
	subl	$258,d0
	ja	copy_record_node2_3
	jb	copy_record_node2_1

	cmpw	$0,-2+2(a0)
	je	copy_real_or_file_2

	movl	a4,(a2)
	movl	a0,(a4)

	lea	1(a4),a0
	movl	4(a1),d0

	movl	a0,(a1)

	movl	d0,4(a4)
	movl	8(a1),d0

	addl	$4,a2
	movl	d0,8(a4)

	addl	$12,a4	
	sub	$1,d1
	jae	copy_lp2
	ret

copy_record_node2_1:
	movl	4(a1),d0

	cmpw	$0,-2+2(a0)
	je	copy_record_node2_1_b

	movl	a4,(a2)
	movl	a0,(a4)

	lea	1(a4),a0
	movl	d0,4(a4)

	movl	a0,(a1)
	addl	$4,a2

	addl	$8,a4
	sub	$1,d1
	jae	copy_lp2
	ret

copy_record_node2_3:
	cmpw	$1,-2+2(a0)
	jbe	copy_record_node2_3_ab_or_b

	movl	d0,copy_sp_offset_5+4(sp)
	lea	1(a4),d0
	
	movl	d0,(a1)
	movl	8(a1),d0

	movl	a0,(a4)
	movl	4(a1),a1

	movl	a1,4(a4)
	movl	a4,(a2)
	addl	$4,a2

	movl	d0,a0
	testl	$1,(d0)
	jne	record_arguments_already_copied_2

	lea	12(a4),a1

	movl	copy_sp_offset_5+4(sp),d0

	movl	a1,8(a4)

	addl	$13,a4
	movl	(a0),a1

	movl	a4,(a0)
	addl	$4,a0

	movl	a1,-1(a4)
	addl	$3,a4

cp_record_arg_lp2:
	movl	(a0),a1
	addl	$4,a0

	movl	a1,(a4)
	addl	$4,a4

	subl	$1,d0
	jne	cp_record_arg_lp2

	subl	$1,d1
	jae	copy_lp2
	ret

record_arguments_already_copied_2:
	movl	(a0),a1

	movl	copy_sp_offset_5+4(sp),d0

	movl	a1,8(a4)
	addl	$12,a4

	subl	$1,d1
	jae	copy_lp2
	ret

copy_record_node2_3_ab_or_b:
	jb	copy_record_node2_3_b

copy_record_node2_3_ab:
	movl	d0,copy_sp_offset_5+4(sp)

	lea	1(a4),d0
	
	movl	d0,(a1)
	movl	8(a1),d0

	movl	a0,(a4)
	movl	4(a1),a1

	movl	d0,a0
	subl	heap_p1_copy_sp_offset+4(sp),d0

	shr	$3,d0
	movl	a1,4(a4)

	mov	d0,a1
	and	$31,d0

	shr	$3,a1
	movl	a4,(a2)

	andl	$-4,a1
	mov	bit_set_table(,d0,4),d0

	addl	heap_copied_vector_copy_sp_offset+4(sp),a1
	addl	$4,a2

	test	(a1),d0
	jne	record_arguments_already_copied_2

	or	d0,(a1)
	movl	copy_sp_offset_5+4(sp),d0

	subl	$4,a3

	shl	$2,d0
	subl	d0,a3

	movl	a3,copy_sp_offset_5+4(sp)
	addl	$1,a3

	movl	a3,8(a4)
	addl	$12,a4

	movl	(a0),a1
	jmp	cp_record_arg_lp3_c

copy_record_node2_3_b:
	movl	d0,copy_sp_offset_5+4(sp)
	lea	-12+1(a3),d0
	
	movl	d0,(a1)
	movl	8(a1),d0

	movl	a0,-12(a3)
	movl	4(a1),a1

	movl	d0,a0
	subl	heap_p1_copy_sp_offset+4(sp),d0

	shr	$3,d0
	movl	a1,-8(a3)

	mov	d0,a1
	and	$31,d0
	subl	$12,a3

	shr	$3,a1
	movl	a3,(a2)

	andl	$-4,a1
	mov	bit_set_table(,d0,4),d0

	addl	heap_copied_vector_copy_sp_offset+4(sp),a1
	addl	$4,a2

	test	(a1),d0
	jne	record_arguments_already_copied_3_b

	or	d0,(a1)
	movl	copy_sp_offset_5+4(sp),d0

	movl	a3,a1
	subl	$4,a3

	shl	$2,d0
	subl	d0,a3

	movl	a3,8(a1)

	movl	(a0),a1

	movl	a3,copy_sp_offset_5+4(sp)
	addl	$1,a3

cp_record_arg_lp3_c:
	movl	a3,(a0)
	addl	$4,a0
	movl	a1,-1(a3)

	addl	$3,a3

cp_record_arg_lp3:
	movl	(a0),a1
	addl	$4,a0

	movl	a1,(a3)
	addl	$4,a3

	subl	$4,d0
	jne	cp_record_arg_lp3

	movl	copy_sp_offset_5+4(sp),a3

	subl	$1,d1
	jae	copy_lp2
	ret

record_arguments_already_copied_3_b:
	movl	(a0),a1

	movl	d0,copy_sp_offset_5+4(sp)

	subl	$1,a1
	movl	a1,8(a3)

	subl	$1,d1
	jae	copy_lp2
	ret

not_in_hnf_2:
	testb	$1,a0b
	jne	already_copied_2

	mov	-4(a0),d0
	test	d0,d0
	jle	copy_arity_0_node2_

copy_node2_1_:
	andl	$255,d0
	sub	$2,d0
	jl	copy_arity_1_node2
copy_node2_3:
	mov	a4,(a2)
	add	$4,a2
	mov	a0,(a4)
	inc	a4
	mov	a4,(a1)
	mov	4(a1),a0
	add	$8,a1
	mov	a0,4-1(a4)
	add	$8-1,a4

cp_arg_lp2:
	mov	(a1),a0
	add	$4,a1
	mov	a0,(a4)
	add	$4,a4
	sub	$1,d0
	jae	cp_arg_lp2
	
	sub	$1,d1
	jae	copy_lp2
	ret

copy_arity_1_node2__:
	movl	copy_sp_offset_5+4(sp),d1

copy_arity_1_node2:
copy_arity_1_node2_:
	mov	a4,(a2)
	inc	a4

	add	$4,a2
	mov	a4,(a1)

	mov	4(a1),d0
	mov	a0,-1(a4)

	mov	d0,4-1(a4)
	add	$12-1,a4

	sub	$1,d1
	jae	copy_lp2
	ret

copy_indirection_2:
	mov	a1,d0
	mov	4(a1),a1

	mov	(a1),a0
	testb	$2,a0b
	jne	in_hnf_2

	testb	$1,a0b
	jne	already_copied_2

	cmpl	$-2,-4(a0)
	je	skip_indirections_2

	mov	-4(a0),d0
	test	d0,d0
	jle	copy_arity_0_node2_
	jmp	copy_node2_1_

skip_indirections_2:
	mov	4(a1),a1

	mov	(a1),a0
	testb	$2,a0b
	jne	update_indirection_list_2
	testb	$1,a0b
	jne	update_indirection_list_2

	cmpl	$-2,-4(a0)
	je	skip_indirections_2

update_indirection_list_2:
	lea	4(d0),a0
	mov	4(d0),d0
	mov	a1,(a0)
	cmp	d0,a1
	jne	update_indirection_list_2

	jmp	continue_after_selector_2

copy_selector_2:
	cmpl	$-2,d0
	je	copy_indirection_2
	jl	copy_record_selector_2

	mov	4(a1),d0

	movl	d1,copy_sp_offset_5+4(sp)

	mov	(d0),d1
 	testb	$2,d1b
	je	copy_arity_1_node2__

	cmpw	$2,-2(d1)
	jbe	copy_selector_2_

	movl	8(d0),d1
	testb	$1,(d1)
	jne	copy_arity_1_node2__

	movl	-8(a0),a0

	movzwl	4(a0),a0
	movl	$e__system__nind,(a1)

	cmpl	$8,a0
	jl	copy_selector_2_1
	je	copy_selector_2_2

	movl	-12(d1,a0),a0

	movl	copy_sp_offset_5+4(sp),d1

	movl	a0,4(a1)
	movl	a0,a1
	jmp	continue_after_selector_2

copy_selector_2_1:
	movl	4(d0),a0

	movl	copy_sp_offset_5+4(sp),d1

	movl	a0,4(a1)
	movl	a0,a1
	jmp	continue_after_selector_2

copy_selector_2_2:
	movl	(d1),a0

	movl	copy_sp_offset_5+4(sp),d1

	movl	a0,4(a1)
	movl	a0,a1
	jmp	continue_after_selector_2
	
copy_selector_2_:
	movl	-8(a0),a0

	movl	copy_sp_offset_5+4(sp),d1

	movzwl	4(a0),a0
	movl	$e__system__nind,(a1)

	movl	(d0,a0),a0
	movl	a0,4(a1)
	movl	a0,a1
	jmp	continue_after_selector_2

copy_record_selector_2:
	cmpl	$-3,d0
 	movl	4(a1),d0
	movl	(d0),d0
	je	copy_strict_record_selector_2

 	testb	$2,d0b
	je	copy_arity_1_node2_

	cmpw	$258,-2(d0)
	jbe	copy_record_selector_2_

	cmpw	$2,-2+2(d0)
	jae	copy_selector_2__

 	movl	4(a1),d0
	movl	a1,copy_sp_offset_5+4(sp)

	movl	8(d0),a1
	subl	heap_p1_copy_sp_offset+4(sp),a1

	mov	$31*8,d0
	and	a1,d0
	shr	$6,a1
	
	shr	$1,d0
	andl	$-4,a1

	addl	heap_copied_vector_copy_sp_offset+4(sp),a1

	mov	bit_set_table(d0),d0
	andl	(a1),d0

	movl	copy_sp_offset_5+4(sp),a1

	je	copy_record_selector_2_
	jmp	copy_arity_1_node2_

copy_selector_2__:
	mov	4(a1),d0
	mov	8(d0),d0
	testb	$1,(d0)
	jne	copy_arity_1_node2_

copy_record_selector_2_:
	movl	-8(a0),d0
	movl	4(a1),a0
	movl	$e__system__nind,(a1)

	movzwl	4(d0),d0
	cmpl	$8,d0
	jle	copy_record_selector_3
	movl	8(a0),a0
	subl	$12,d0
copy_record_selector_3:
	movl	(a0,d0),a0

	movl	a0,4(a1)

	movl	a0,a1
	jmp	continue_after_selector_2

copy_strict_record_selector_2:
	testb	$2,d0b
	je	copy_arity_1_node2_

	cmpw	$258,-2(d0)
	jbe	copy_strict_record_selector_2_

	cmpw	$2,-2+2(d0)
	jb	copy_strict_record_selector_2_b

 	movl	4(a1),d0
	movl	8(d0),d0
	testb	$1,(d0)
	jne	copy_arity_1_node2_

	jmp	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
 	movl	4(a1),d0
	movl	a1,copy_sp_offset_5+4(sp)

	movl	8(d0),d0
	subl	heap_p1_copy_sp_offset+4(sp),d0

	mov	d0,a1
	and	$31*8,d0

	shr	$6,a1

	shr	$1,d0
	andl	$-4,a1

	addl	heap_copied_vector_copy_sp_offset+4(sp),a1

	mov	bit_set_table(d0),d0
	
	and	(a1),d0
	movl	copy_sp_offset_5+4(sp),a1

	jne	copy_arity_1_node2_

copy_strict_record_selector_2_:
	movl	-8(a0),d0

	movl	d1,copy_sp_offset_5+4(sp)

	movl	4(a1),a0

	movzwl	4(d0),d1
	cmpl	$8,d1
	jle	copy_strict_record_selector_3
	addl	8(a0),d1
	movl	-12(d1),d1
	jmp	copy_strict_record_selector_4
copy_strict_record_selector_3:
	movl	(a0,d1),d1
copy_strict_record_selector_4:
	movl	d1,4(a1)

	movzwl	6(d0),d1
	testl	d1,d1
	je	copy_strict_record_selector_6
	cmpl	$8,d1
	jle	copy_strict_record_selector_5
	movl	8(a0),a0
	subl	$12,d1
copy_strict_record_selector_5:
	movl	(a0,d1),d1
	movl	d1,8(a1)
copy_strict_record_selector_6:

	movl	-4(d0),a0
	movl	a0,(a1)

	movl	copy_sp_offset_5+4(sp),d1

	testb	$2,a0b
	jne	in_hnf_2
	hlt

copy_arity_0_node2_:
	jl	copy_selector_2

	mov	a0,-12(a3)
	sub	$12,a3
	mov	a3,(a2)
	lea	1(a3),d0

	add	$4,a2
	mov	d0,(a1)

	sub	$1,d1
	jae	copy_lp2
	ret

copy_string_or_array_2:
	movl	a1,a0
	jne	copy_array_2

	sub	heap_p1_copy_sp_offset+4(sp),a1
	cmp	semi_space_size_sp_offset+4(sp),a1
	jae	copy_string_or_array_constant

	mov	4(a0),a1
	add	$4,a2

	add	$3,a1

	movl	d1,copy_sp_offset_5+4(sp)

	mov	a1,d0
	and	$-4,a1
	
	shr	$2,d0
	sub	a1,a3

	mov	(a0),d1
	add	$4,a0

	mov	d1,-8(a3)
	sub	$8,a3

	mov	a3,-4(a2)
	lea	1(a3),a1
	
	mov	a1,-4(a0)
	lea	4(a3),a1

cp_s_arg_lp2:
	mov	(a0),d1
	add	$4,a0

	mov	d1,(a1)
	add	$4,a1

	subl	$1,d0
	jge	cp_s_arg_lp2

	movl	copy_sp_offset_5+4(sp),d1

	sub	$1,d1
	jae	copy_lp2
	ret

copy_array_2:
	sub	heap_p1_copy_sp_offset+4(sp),a1
	cmp	semi_space_size_sp_offset+4(sp),a1
	jae	copy_string_or_array_constant

	movl	d1,copy_sp_offset_5+4(sp)

	movl	8(a0),d0
	test	d0,d0
	je	copy_array_a2

	movzwl 	-2(d0),d1

	test	d1,d1
	je	copy_strict_basic_array_2
	
	subl	$256,d1
	imull	4(a0),d1
	jmp	copy_array_a3

copy_array_a2:
	movl	4(a0),d1
copy_array_a3:
	movl	a4,a1
	lea	12(a4,d1,4),a4

	movl	a1,(a2)
	movl	(a0),d0

	addl	$4,a2
	movl	d0,(a1)

	lea	1(a1),d0
	addl	$4,a1

	movl	d0,(a0)
	addl	$4,a0

	lea	1(d1),d0
	jmp	cp_s_arg_lp2

copy_strict_basic_array_2:
	movl	4(a0),d1
	cmpl	$INT+2,d0
	je	copy_int_array_2

	cmpl	$BOOL+2,d0
	je	copy_bool_array_2

	addl	d1,d1
copy_int_array_2:
	shl	$2,d1
	lea	-12(a3),a1

	subl	d1,a1
	movl	(a0),d0

	shr	$2,d1	
	movl	a1,(a2)

	addl	$4,a2
	movl	a1,a3
	
	movl	d0,(a1)
	lea	1(a1),d0

	addl	$4,a1
	movl	d0,(a0)

	addl	$4,a0
	lea	1(d1),d0
	jmp	cp_s_arg_lp2

copy_bool_array_2:
	add	$3,d1
	shr	$2,d1
	jmp	copy_int_array_2

copy_string_or_array_constant:
	movl	a0,(a2)
	add	$4,a2

	sub	$1,d1
	jae	copy_lp2
	ret

end_copy1:
#ifdef FINALIZERS
	movl	$finalizer_list,a0
	movl	$free_finalizer_list,a1
	movl	finalizer_list,a2

determine_free_finalizers_after_copy:
	movl	(a2),d0
	testb	$1,d0b
	je	finalizer_not_used_after_copy

	movl	4(a2),a2
	subl	$1,d0
	movl	d0,(a0)
	lea	4(d0),a0
	jmp	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	cmpl	$__Nil-4,a2
	je	end_finalizers_after_copy

	movl	a2,(a1)
	lea	4(a2),a1
	movl	4(a2),a2
	jmp	determine_free_finalizers_after_copy	

end_finalizers_after_copy:
	movl	a2,(a0)
	movl	a2,(a1)
#endif

	lea	-32(a3),a1

	movl	a4,a2
	movl	a4_copy_sp_offset(sp),a4
	lea	44(sp),sp

	movl	a2,free_heap_offset(a4)
	movl	a3,heap_end_after_gc_offset(a4)
	movl	a1,end_heap_offset(a4)
