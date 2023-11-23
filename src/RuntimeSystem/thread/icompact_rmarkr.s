
rmark_using_reversal:
	pushl	a3
	pushl	a3
	movl	$1,a3
	jmp	rmarkr_node

rmark_using_reversal_:
	subl	$4,a0
	pushl	d1
	pushl	a3
	cmpl	d1,a0
	ja	rmark_no_undo_reverse_1
	movl	a0,(a3)
	movl	d0,(a0)
rmark_no_undo_reverse_1:
	movl	$1,a3
	jmp	rmarkr_arguments

rmark_array_using_reversal:
	pushl	d1
	pushl	a3
	cmpl	d1,a0
	ja	rmark_no_undo_reverse_2
	movl	a0,(a3)
	movl	$__ARRAY__+2,(a0)
rmark_no_undo_reverse_2:
	movl	$1,a3
	jmp	rmarkr_arguments

rmarkr_hnf_2:
	orl	$2,(a0)
	movl	4(a0),a2
	movl	a3,4(a0)
	leal	4(a0),a3
	movl	a2,a0

rmarkr_node:
	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_d4_offset(a4),a2
	addl	a0,d1
	cmpl	heap_size_32_33_offset(a4),d1
	jnc	rmarkr_next_node_after_static

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	a2,d1

	movl	bit_set_table(d0),d0
	movl	(,d1,4),a2
	test	d0,a2
	jne	rmarkr_next_node

	orl	d0,a2
	movl	a2,(,d1,4)

rmarkr_arguments:
	movl	(a0),d0
	testb	$2,d0b
	je	rmarkr_lazy_node

	movzwl	-2(d0),a2
	test	a2,a2
	je	rmarkr_hnf_0

	addl	$4,a0

	cmp	$256,a2
	jae	rmarkr_record

	subl	$2,a2
	je	rmarkr_hnf_2
	jc	rmarkr_hnf_1

rmarkr_hnf_3:
	movl	4(a0),a1

	movl	neg_heap_p3_offset(a4),d1
	addl	a1,d1

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(d0),d0		
	test	(,d1,4),d0
	jne	rmarkr_shared_argument_part

	orl	d0,(,d1,4)

rmarkr_no_shared_argument_part:
	orl	$2,(a0)
	movl	a3,4(a0)
	addl	$4,a0

	orl	$1,(a1)
	leal	(a1,a2,4),a1

	movl	(a1),a2
	movl	a0,(a1)
	movl	a1,a3
	movl	a2,a0
	jmp	rmarkr_node

rmarkr_shared_argument_part:
	cmpl	a0,a1
	ja	rmarkr_hnf_1

	movl	(a1),d1
	leal	4+2+1(a0),d0
	movl	d0,(a1)
	movl	d1,4(a0)
	jmp	rmarkr_hnf_1

rmarkr_record:
	subl	$258,a2
	je	rmarkr_record_2
	jb	rmarkr_record_1

rmarkr_record_3:
	movzwl	-2+2(d0),a2
	subl	$1,a2
	jb	rmarkr_record_3_bb
	je	rmarkr_record_3_ab
	dec	a2
	je	rmarkr_record_3_aab
	jmp	rmarkr_hnf_3

rmarkr_record_3_bb:
	movl	8-4(a0),a1
	subl	$4,a0

	movl	neg_heap_p3_offset(a4),a2
	addl	a1,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	orl	d0,(,a2,4)

	cmpl	a0,a1
	ja	rmarkr_next_node

	add	d0,d0
	jne	rmarkr_bit_in_same_word1
	inc	a2
	mov	$1,d0
rmarkr_bit_in_same_word1:
	testl	(,a2,4),d0
	je	rmarkr_not_yet_linked_bb

	movl	neg_heap_p3_offset(a4),a2
	addl	a0,a2

	addl	$2*4,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	orl	d0,(,a2,4)

	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	rmarkr_next_node

rmarkr_not_yet_linked_bb:
	orl	d0,(,a2,4)
	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	rmarkr_next_node

rmarkr_record_3_ab:
	movl	4(a0),a1

	movl	neg_heap_p3_offset(a4),a2
	addl	a1,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	orl	d0,(,a2,4)

	cmpl	a0,a1
	ja	rmarkr_hnf_1

	add	d0,d0
	jne	rmarkr_bit_in_same_word2
	inc	a2
	mov	$1,d0
rmarkr_bit_in_same_word2:
	testl	(,a2,4),d0
	je	rmarkr_not_yet_linked_ab

	movl	neg_heap_p3_offset(a4),a2
	addl	a0,a2

	addl	$4,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	orl	d0,(,a2,4)

	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	rmarkr_hnf_1

rmarkr_not_yet_linked_ab:
	orl	d0,(,a2,4)
	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	rmarkr_hnf_1

rmarkr_record_3_aab:
	movl	4(a0),a1

	movl	neg_heap_p3_offset(a4),a2
	addl	a1,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	testl	(,a2,4),d0
	jne	rmarkr_shared_argument_part
	orl	d0,(,a2,4)

	addl	$2,(a0)
	movl	a3,4(a0)
	addl	$4,a0
	
	movl	(a1),a3
	movl	a0,(a1)
	movl	a3,a0
	lea	1(a1),a3
	jmp	rmarkr_node

rmarkr_record_2:
	cmpw	$1,-2+2(d0)
	ja	rmarkr_hnf_2
	je	rmarkr_hnf_1
	subl	$4,a0
	jmp	rmarkr_next_node

rmarkr_record_1:
	cmpw	$0,-2+2(d0)
	jne	rmarkr_hnf_1
	subl	$4,a0
	jmp	rmarkr_next_node

rmarkr_lazy_node_1:
/ selectors:
	jne	rmarkr_selector_node_1

rmarkr_hnf_1:
	movl	(a0),a2
	movl	a3,(a0)

	leal	2(a0),a3
	movl	a2,a0
	jmp	rmarkr_node

/ selectors
rmarkr_indirection_node:
	movl	neg_heap_p3_offset(a4),d1
	leal	-4(a0,d1),d1

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(d0),d0
	andl	d0,(,d1,4)

	movl	(a0),a0
	jmp	rmarkr_node

rmarkr_selector_node_1:
	addl	$3,a2
	je	rmarkr_indirection_node

	movl	(a0),a1

	movl	neg_heap_p3_offset(a4),d1
	addl	a1,d1

	addl	$1,a2
	jle	rmarkr_record_selector_node_1

	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(,d0),d0
	andl	(,d1,4),d0
	pop	d0
	jne	rmarkr_hnf_1

	movl	(a1),d1
	testb	$2,d1b
	je	rmarkr_hnf_1

	cmpw	$2,-2(d1)
	jbe	rmarkr_small_tuple_or_record

rmarkr_large_tuple_or_record:
	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1

	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(,d0),d0
	andl	(,d1,4),d0
	pop	d0
	jne	rmarkr_hnf_1

	movl	neg_heap_p3_offset(a4),d1
	lea	-4(a0,d1),d1

	push	a0

	movl	-8(d0),d0

	movl	$31*4,a0
	andl	d1,a0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(a0),a0
	andl	a0,(,d1,4)

	movzwl	4(d0),d0
	cmpl	$8,d0
	jl	rmarkr_tuple_or_record_selector_node_2
	movl	8(a1),a1
	je	rmarkr_tuple_selector_node_2
	movl	-12(a1,d0),a0
	pop	a1
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmarkr_node

rmarkr_tuple_selector_node_2:
	movl	(a1),a0
	pop	a1
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmarkr_node

rmarkr_record_selector_node_1:
	je	rmarkr_strict_record_selector_node_1

	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(,d0),d0
	movl	(,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	rmarkr_hnf_1

	movl	(a1),d1
	testb	$2,d1b
	je	rmarkr_hnf_1

	cmpw	$258,-2(d1)
	jbe	rmarkr_small_tuple_or_record

	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1

	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(,d0),d0
	andl	(,d1,4),d0
	pop	d0
	jne	rmarkr_hnf_1

rmarkr_small_tuple_or_record:
	movl	neg_heap_p3_offset(a4),d1
	lea	-4(a0,d1),d1

	push	a0

	movl	-8(d0),d0

	movl	$31*4,a0
	andl	d1,a0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(a0),a0
	andl	a0,(,d1,4)

	movzwl	4(d0),d0
	cmpl	$8,d0
	jle	rmarkr_tuple_or_record_selector_node_2
	movl	8(a1),a1
	subl	$12,d0
rmarkr_tuple_or_record_selector_node_2:
	movl	(a1,d0),a0
	pop	a1
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmarkr_node

rmarkr_strict_record_selector_node_1:
	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(,d0),d0
	andl	(,d1,4),d0
	pop	d0
	jne	rmarkr_hnf_1

	movl	(a1),d1
	testb	$2,d1b
	je	rmarkr_hnf_1

	cmpw	$258,-2(d1)
	jbe	rmarkr_select_from_small_record

	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1

	push	d0
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(d0),d0
	andl	(,d1,4),d0
	pop	d0
	jne	rmarkr_hnf_1

rmarkr_select_from_small_record:
	movl	-8(d0),d0
	subl	$4,a0

	movzwl	4(d0),d1
	cmpl	$8,d1
	jle	rmarkr_strict_record_selector_node_2
	addl	8(a1),d1
	movl	-12(d1),d1
	jmp	rmarkr_strict_record_selector_node_3
rmarkr_strict_record_selector_node_2:
	movl	(a1,d1),d1
rmarkr_strict_record_selector_node_3:
	movl	d1,4(a0)

	movzwl	6(d0),d1
	testl	d1,d1
	je	rmarkr_strict_record_selector_node_5
	cmpl	$8,d1
	jle	rmarkr_strict_record_selector_node_4
	movl	8(a1),a1
	subl	$12,d1
rmarkr_strict_record_selector_node_4:
	movl	(a1,d1),d1
	movl	d1,8(a0)
rmarkr_strict_record_selector_node_5:

	movl	-4(d0),d0
	movl	d0,(a0)
	jmp	rmarkr_next_node

/ a2,d1: free

rmarkr_next_node:
	test	$3,a3
	jne	rmarkr_parent

	movl	-4(a3),a2
	movl	$3,d1
	
	andl	a2,d1
	subl	$4,a3

	cmpl	$3,d1
	je	rmarkr_argument_part_cycle1

	movl	4(a3),a1
	movl	a1,(a3)

rmarkr_c_argument_part_cycle1:
	cmpl	a3,a0
	ja	rmarkr_no_reverse_1

	movl	(a0),a1
	leal	4+1(a3),d0
	movl	a1,4(a3)
	movl	d0,(a0)
	
	orl	d1,a3
	movl	a2,a0
	xorl	d1,a0
	jmp	rmarkr_node

rmarkr_no_reverse_1:
	movl	a0,4(a3)
	movl	a2,a0
	orl	d1,a3
	xorl	d1,a0
	jmp	rmarkr_node

rmarkr_lazy_node:
	movl	-4(d0),a2
	test	a2,a2
	je	rmarkr_next_node

	addl	$4,a0

	subl	$1,a2
	jle	rmarkr_lazy_node_1

	cmpl	$255,a2
	jge	rmarkr_closure_with_unboxed_arguments

rmarkr_closure_with_unboxed_arguments_:
	orl	$2,(a0)
	leal	(a0,a2,4),a0

	movl	(a0),a2
	movl	a3,(a0)
	movl	a0,a3
	movl	a2,a0
	jmp	rmarkr_node

rmarkr_closure_with_unboxed_arguments:
/ (a_size+b_size)+(b_size<<8)
/	addl	$1,a2
	movl	a2,d0
	andl	$255,a2
	shrl	$8,d0
	subl	d0,a2
/	subl	$1,a2
	jg	rmarkr_closure_with_unboxed_arguments_
	je	rmarkr_hnf_1
	subl	$4,a0
	jmp	rmarkr_next_node

rmarkr_hnf_0:
	cmpl	$INT+2,d0
	je	rmarkr_int_3

	cmpl	$CHAR+2,d0
 	je	rmarkr_char_3

	jb	rmarkr_no_normal_hnf_0

	movl	neg_heap_p3_offset(a4),d1
	addl	a0,d1

	movl	$31*4,a0
	andl	d1,a0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(a0),a0
	andl	a0,(,d1,4)

	lea	ZERO_ARITY_DESCRIPTOR_OFFSET-2(d0),a0
	jmp	rmarkr_next_node_after_static

rmarkr_int_3:
	movl	4(a0),a2
	cmpl	$33,a2
	jnc	rmarkr_next_node

	movl	neg_heap_p3_offset(a4),d1
	addl	a0,d1

	movl	$31*4,a0
	andl	d1,a0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(a0),a0
	andl	a0,(,d1,4)

	lea	small_integers(,a2,8),a0
	jmp	rmarkr_next_node_after_static

rmarkr_char_3:
	movl	neg_heap_p3_offset(a4),d1

	movzbl	4(a0),d0
	addl	a0,d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_clear_table(a2),a2
	andl	a2,(,d1,4)

	lea	static_characters(,d0,8),a0
	jmp	rmarkr_next_node_after_static

rmarkr_no_normal_hnf_0:
	cmpl	$__ARRAY__+2,d0
	jne	rmarkr_next_node

	movl	8(a0),d0
	test	d0,d0
	je	rmarkr_lazy_array

	movzwl	-2+2(d0),d1
	test	d1,d1
	je	rmarkr_b_array

	movzwl	-2(d0),d0
	test	d0,d0
	je	rmarkr_b_array

	subl	$256,d0
	cmpl	d0,d1
	je	rmarkr_a_record_array

rmarkr_ab_record_array:
	movl	4(a0),a1
	addl	$8,a0
	pushl	a0

	imull	d0,a1
	shl	$2,a1

	subl	d1,d0
	addl	$4,a0
	addl	a0,a1
	call	reorder
	
	popl	a0
	movl	d1,d0
	imull	-4(a0),d0	
	jmp	rmarkr_lr_array

rmarkr_b_array:
	movl	neg_heap_p3_offset(a4),a2
	addl	a0,a2

	addl	$4,a2

	movl	$31*4,d0
	andl	a2,d0
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	movl	bit_set_table(d0),d0
	orl	d0,(,a2,4)
	jmp	rmarkr_next_node

rmarkr_a_record_array:
	movl	4(a0),d0
	addl	$8,a0
	cmpl	$2,d1
	jb	rmarkr_lr_array

	imull	d1,d0
	jmp	rmarkr_lr_array

rmarkr_lazy_array:
	movl	4(a0),d0
	addl	$8,a0

rmarkr_lr_array:
	movl	neg_heap_p3_offset(a4),a1
	addl	a0,a1
	shrl	$2,a1
	addl	d0,a1

	movl	$31,d1
	andl	a1,d1
	shrl	$5,a1
	addl	heap_vector_d4_offset(a4),a1

	movl	bit_set_table(,d1,4),d1
	orl	d1,(,a1,4)

	cmpl	$1,d0
	jbe	rmarkr_array_length_0_1

	movl	a0,a1
	lea	(a0,d0,4),a0

	movl	(a0),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,(a0)
	
	movl	-4(a0),d0
	subl	$4,a0
	addl	$2,d0
	movl	-4(a1),d1
	subl	$4,a1
	movl	d1,(a0)
	movl	d0,(a1)

	movl	-4(a0),d0
	subl	$4,a0
	movl	a3,(a0)
	movl	a0,a3
	movl	d0,a0
	jmp	rmarkr_node

rmarkr_array_length_0_1:
	lea	-8(a0),a0
	jb	rmarkr_next_node

	movl	12(a0),d1
	movl	8(a0),a2
	movl	a2,12(a0)
	movl	4(a0),a2
	movl	a2,8(a0)
	movl	d1,4(a0)
	addl	$4,a0
	jmp	rmarkr_hnf_1

/ a2: free

rmarkr_parent:
	movl	a3,d1
	andl	$3,d1

	andl	$-4,a3
	je	end_rmarkr

	subl	$1,d1
	je	rmarkr_argument_part_parent

	movl	(a3),a2
	
	cmpl	a3,a0
	ja	rmarkr_no_reverse_2

	movl	a0,a1
	leal	1(a3),d0
	movl	(a1),a0
	movl	d0,(a1)

rmarkr_no_reverse_2:
	movl	a0,(a3)
	leal	-4(a3),a0
	movl	a2,a3
	jmp	rmarkr_next_node

rmarkr_argument_part_parent:
	movl	(a3),a2

	movl	a3,a1
	movl	a0,a3
	movl	a1,a0

rmarkr_skip_upward_pointers:
	movl	a2,d0
	andl	$3,d0
	cmpl	$3,d0
	jne	rmarkr_no_upward_pointer

	leal	-3(a2),a1
	movl	-3(a2),a2
	jmp	rmarkr_skip_upward_pointers

rmarkr_no_upward_pointer:
	cmpl	a0,a3
	ja	rmarkr_no_reverse_3

	movl	a3,d1
	movl	(a3),a3
	leal	1(a0),d0
	movl	d0,(d1)
	
rmarkr_no_reverse_3:
	movl	a3,(a1)
	lea	-4(a2),a3

	andl	$-4,a3

	movl	a3,a1
	movl	$3,d1

	movl	(a3),a2

	andl	a2,d1
	movl	4(a1),d0

	orl	d1,a3
	movl	d0,(a1)

	cmpl	a1,a0
	ja	rmarkr_no_reverse_4

	movl	(a0),d0
	movl	d0,4(a1)
	leal	4+2+1(a1),d0
	movl	d0,(a0)
	movl	a2,a0
	andl	$-4,a0
	jmp	rmarkr_node

rmarkr_no_reverse_4:
	movl	a0,4(a1)
	movl	a2,a0
	andl	$-4,a0
	jmp	rmarkr_node

rmarkr_argument_part_cycle1:
	movl	4(a3),d0
	push	a1

rmarkr_skip_pointer_list1:
	movl	a2,a1
	andl	$-4,a1
	movl	(a1),a2
	movl	$3,d1
	andl	a2,d1
	cmpl	$3,d1
	je	rmarkr_skip_pointer_list1

	movl	d0,(a1)
	pop	a1
	jmp	rmarkr_c_argument_part_cycle1

rmarkr_next_node_after_static:
	test	$3,a3
	jne	rmarkr_parent_after_static

	movl	-4(a3),a2
	movl	$3,d1
	
	andl	a2,d1
	subl	$4,a3

	cmpl	$3,d1
	je	rmarkr_argument_part_cycle2
	
	movl	4(a3),d0
	movl	d0,(a3)

rmarkr_c_argument_part_cycle2:
	movl	a0,4(a3)
	movl	a2,a0
	orl	d1,a3
	xorl	d1,a0
	jmp	rmarkr_node

rmarkr_parent_after_static:
	movl	a3,d1
	andl	$3,d1

	andl	$-4,a3
	je	end_rmarkr_after_static

	subl	$1,d1
	je	rmarkr_argument_part_parent_after_static

	movl	(a3),a2
	movl	a0,(a3)
	leal	-4(a3),a0
	movl	a2,a3
	jmp	rmarkr_next_node
	
rmarkr_argument_part_parent_after_static:
	movl	(a3),a2

	movl	a3,a1
	movl	a0,a3
	movl	a1,a0

/	movl	(a1),a2
rmarkr_skip_upward_pointers_2:
	movl	a2,d0
	andl	$3,d0
	cmpl	$3,d0
	jne	rmarkr_no_reverse_3

/	movl	a2,a1
/	andl	$-4,a1
/	movl	(a1),a2
	lea	-3(a2),a1
	movl	-3(a2),a2
	jmp	rmarkr_skip_upward_pointers_2

rmarkr_argument_part_cycle2:
	movl	4(a3),d0
	push	a1

rmarkr_skip_pointer_list2:
	movl	a2,a1
	andl	$-4,a1
	movl	(a1),a2
	movl	$3,d1
	andl	a2,d1
	cmpl	$3,d1
	je	rmarkr_skip_pointer_list2

	movl	d0,(a1)
	pop	a1
	jmp	rmarkr_c_argument_part_cycle2

end_rmarkr_after_static:
	movl	(sp),a3
	addl	$8,sp
	movl	a0,(a3)
	jmp	rmarkr_next_stack_node

end_rmarkr:
	popl	a3
	popl	d1

	cmpl	d1,a0
	ja	rmark_no_reverse_4

	movl	a0,a1
	leal	1(a3),d0
	movl	(a0),a0
	movl	d0,(a1)

rmark_no_reverse_4:
	movl	a0,(a3)

rmarkr_next_stack_node:
	cmpl	end_stack_offset(a4),sp
	jae	rmark_next_node

	movl	(sp),a0
	movl	4(sp),a3
	addl	$8,sp
	
	cmpl	$1,a0
	ja	rmark_using_reversal

	jmp	rmark_next_node_
