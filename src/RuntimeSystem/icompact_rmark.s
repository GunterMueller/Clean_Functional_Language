
rmark_stack_nodes1:
	movl	(a0),d1
	leal	1(a3),d0
	movl	d1,(a3)
	movl	d0,(a0)

rmark_next_stack_node:
	addl	$4,a3
rmark_stack_nodes:
	cmpl	end_vector,a3
	je	end_rmark_nodes

rmark_more_stack_nodes:
	movl	(a3),a0

	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_stack_node
#endif

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	movl	(a4,d1,4),a2
	test	d0,a2
	jne	rmark_stack_nodes1
	
	orl	d0,a2
	movl	a2,(a4,d1,4)
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	rmark_stack_nodes1
#endif

	movl	(a0),d0
	call	rmark_stack_node

	addl	$4,a3
	cmpl	end_vector,a3
	jne	rmark_more_stack_nodes
	ret

rmark_stack_node:
	subl	$8,sp
	movl	d0,(a3)
	lea	1(a3),a2
	movl	a3,4(sp)
	movl	$-1,d1
	movl	$0,(sp)
	movl	a2,(a0)
	jmp	rmark_no_reverse

rmark_node_d1:
	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_node
#endif
	jmp	rmark_node_

rmark_hnf_2:
	leal	4(a0),d1
	movl	4(a0),d0
	subl	$8,sp

	movl	a0,a3
	movl	(a0),a0

	movl	d1,4(sp)
	movl	d0,(sp)	

	cmpl	end_stack,sp
	jb	rmark_using_reversal

rmark_node:
	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_node
#endif
	movl	a3,d1

rmark_node_:
#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a1
	andl	$31*4,d0
	shrl	$7,a1
	movl	bit_set_table(d0),d0
	movl	(a4,a1,4),a2
	test	d0,a2
	jne	rmark_reverse_and_mark_next_node
	
	orl	d0,a2
	movl	a2,(a4,a1,4)
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	rmark_reverse_and_mark_next_node
#endif

	movl	(a0),d0
rmark_arguments:
	cmpl	d1,a0
	ja	rmark_no_reverse

	lea	1(a3),a2
	movl	d0,(a3)
	movl	a2,(a0)

rmark_no_reverse:
	testb	$2,d0b
	je	rmark_lazy_node

	movzwl	-2(d0),a2
	test	a2,a2
	je	rmark_hnf_0

	addl	$4,a0

	cmp	$256,a2
	jae	rmark_record

	subl	$2,a2
	je	rmark_hnf_2
	jc	rmark_hnf_1

rmark_hnf_3:
	movl	4(a0),a1
rmark_hnf_3_:
	cmpl	end_stack,sp
	jb	rmark_using_reversal_

	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0	
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	test	(a4,d1,4),d0
	jne	rmark_shared_argument_part

	orl	d0,(a4,d1,4)	
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	rmark_shared_argument_part
#endif

rmark_no_shared_argument_part:
	subl	$8,sp
	movl	a0,4(sp)
	lea	4(a0),a3
	movl	(a0),a0
	lea	(a1,a2,4),a1
	movl	a0,(sp)

rmark_push_hnf_args:
	movl	(a1),d1
	subl	$8,sp
	movl	a1,4(sp)
	subl	$4,a1
	movl	d1,(sp)

	subl	$1,a2
	jg	rmark_push_hnf_args

	movl	(a1),a0

	cmpl	a3,a1
	ja	rmark_no_reverse_argument_pointer

	lea	3(a3),a2
	movl	a0,(a3)
	movl	a2,(a1)

	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_node
#endif
	movl	a1,d1
	jmp	rmark_node_

rmark_no_reverse_argument_pointer:
	movl	a1,a3
	jmp	rmark_node

rmark_shared_argument_part:
	cmpl	a0,a1
	ja	rmark_hnf_1

	movl	(a1),d1
	leal	4+2+1(a0),d0
	movl	d0,(a1)
	movl	d1,4(a0)
	jmp	rmark_hnf_1

rmark_record:
	subl	$258,a2
	je	rmark_record_2
	jb	rmark_record_1

rmark_record_3:
	movzwl	-2+2(d0),a2
	movl	4(a0),a1
	subl	$1,a2
	jb	rmark_record_3_bb
	je	rmark_record_3_ab
	subl	$1,a2
	je	rmark_record_3_aab
	jmp	rmark_hnf_3_

rmark_record_3_bb:
	subl	$4,a0

	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	orl	d0,(a4,a2,4)
#else
	shrl	$2,d0
	bts	d0,(a4)
#endif

	cmpl	a0,a1
	ja	rmark_next_node

#ifdef NO_BIT_INSTRUCTIONS
	add	d0,d0
	jne	rmark_bit_in_same_word1
	inc	a2
	mov	$1,d0
rmark_bit_in_same_word1:
	testl	(a4,a2,4),d0
	je	rmark_not_yet_linked_bb
#else
	inc	d0
	bts	d0,(a4)
	jnc	rmark_not_yet_linked_bb
#endif
	movl	neg_heap_p3,d0
	addl	a0,d0

#ifdef NO_BIT_INSTRUCTIONS
	addl	$2*4,d0
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	orl	d0,(a4,a2,4)
#else
	shrl	$2,d0
	addl	$2,d0
	bts	d0,(a4)	
rmark_not_yet_linked_bb:
#endif
	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	rmark_next_node

#ifdef NO_BIT_INSTRUCTIONS
rmark_not_yet_linked_bb:
	orl	d0,(a4,a2,4)
	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	rmark_next_node
#endif

rmark_record_3_ab:
	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	orl	d0,(a4,a2,4)
#else
	shr	$2,d0
	bts	d0,(a4)
#endif
	cmpl	a0,a1
	ja	rmark_hnf_1

#ifdef NO_BIT_INSTRUCTIONS
	add	d0,d0
	jne	rmark_bit_in_same_word2
	inc	a2
	mov	$1,d0
rmark_bit_in_same_word2:
	testl	(a4,a2,4),d0
	je	rmark_not_yet_linked_ab
#else
	inc	d0
	bts	d0,(a4)
	jnc	rmark_not_yet_linked_ab
#endif

	movl	neg_heap_p3,d0
	addl	a0,d0

#ifdef NO_BIT_INSTRUCTIONS
	addl	$4,d0
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	orl	d0,(a4,a2,4)
#else
	shr	$2,d0
	inc	d0
	bts	d0,(a4)
rmark_not_yet_linked_ab: 
#endif

	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	rmark_hnf_1

#ifdef NO_BIT_INSTRUCTIONS
rmark_not_yet_linked_ab:
	orl	d0,(a4,a2,4)
	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	rmark_hnf_1
#endif

rmark_record_3_aab:
	cmpl	end_stack,sp
	jb	rmark_using_reversal_

	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	testl	(a4,a2,4),d0
	jne	rmark_shared_argument_part

	orl	d0,(a4,a2,4)
#else
	shr	$2,d0
	bts	d0,(a4)
	jc	rmark_shared_argument_part
#endif

	subl	$8,sp
	movl	a0,4(sp)
	lea	4(a0),a3
	movl	(a0),a0
	movl	a0,(sp)

	movl	(a1),a0

	cmpl	a3,a1
	ja	rmark_no_reverse_argument_pointer

	lea	3(a3),a2
	movl	a0,(a3)
	movl	a2,(a1)

	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_node
#endif
	movl	a1,d1
	jmp	rmark_node_

rmark_record_2:
	cmpw	$1,-2+2(d0)
	ja	rmark_hnf_2
	je	rmark_hnf_1
	jmp	rmark_next_node

rmark_record_1:
	cmpw	$0,-2+2(d0)
	jne	rmark_hnf_1
	jmp	rmark_next_node

rmark_lazy_node_1:
/ selectors:
	jne	rmark_selector_node_1

rmark_hnf_1:
	movl	a0,a3
	movl	(a0),a0
	jmp	rmark_node

/ selectors
rmark_indirection_node:
	movl	neg_heap_p3,a1
	subl	$4,a0
	addl	a0,a1

#ifdef NO_BIT_INSTRUCTIONS
	movl	a1,a2
	andl	$31*4,a2
	shrl	$7,a1
	movl	bit_clear_table(a2),a2
	andl	a2,(a4,a1,4)
#else
	shrl	$2,a1
	btr	a1,(a4)
#endif
	movl	a0,a1
	cmpl	d1,a0
	movl	4(a0),a0
	movl	a0,(a3)
	ja	rmark_node_d1
	movl	d0,(a1)
	jmp	rmark_node_d1

rmark_selector_node_1:
	addl	$3,a2
	je	rmark_indirection_node

	movl	(a0),a1
	movl	d1,pointer_compare_address

	movl	neg_heap_p3,d1
	addl	a1,d1
	shrl	$2,d1

	addl	$1,a2
	jle	rmark_record_selector_node_1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	shrl	$5,d1
	andl	$31,a2
	movl	bit_set_table(,a2,4),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1
#else
	bt	d1,(a4)
	jc	rmark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	rmark_hnf_1

	cmpw	$2,-2(d1)
	jbe	rmark_small_tuple_or_record

rmark_large_tuple_or_record:
	movl	8(a1),d1
	addl	neg_heap_p3,d1
	shrl	$2,d1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	shrl	$5,d1
	andl	$31,a2
	movl	bit_set_table(,a2,4),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1
#else
	bt	d1,(a4)
	jc	rmark_hnf_1
#endif

#ifdef NEW_DESCRIPTORS
	movl	neg_heap_p3,d1
	lea	-4(a0,d1),d1

	pushl	a0

	movl	-8(d0),d0

	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)

	movzwl	4(d0),d0
	movl	pointer_compare_address,d1

	cmpl	$8,d0
	jl	rmark_tuple_or_record_selector_node_2
	movl	8(a1),a1
	je	rmark_tuple_selector_node_2
	movl	-12(a1,d0),a0
	pop	a1
	movl	a0,(a3)
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmark_node_d1

rmark_tuple_selector_node_2:
	movl	(a1),a0
	pop	a1
	movl	a0,(a3)
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmark_node_d1
#else
rmark_small_tuple_or_record:
	movl	neg_heap_p3,d1
	lea	-4(a0,d1),d1

	pushl	a0

# ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)
# else
	shrl	$2,d1
	btr	d1,(a4)
# endif
	movl	-8(d0),d0

	movl	a1,a0
	pushl	a3
	call	*4(d0)
	pop	a3
	pop	a1

	movl	a0,(a3)

	movl	pointer_compare_address,d1

	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmark_node_d1
#endif

rmark_record_selector_node_1:
	je	rmark_strict_record_selector_node_1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	shrl	$5,d1
	andl	$31,a2
	movl	bit_set_table(,a2,4),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1
#else
	bt	d1,(a4)
	jc	rmark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	rmark_hnf_1

	cmpw	$258,-2(d1)
#ifdef NEW_DESCRIPTORS
	jbe	rmark_small_tuple_or_record

	movl	8(a1),d1
	addl	neg_heap_p3,d1
	shrl	$2,d1

	movl	d1,a2
	shrl	$5,d1
	andl	$31,a2
	movl	bit_set_table(,a2,4),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1

rmark_small_tuple_or_record:
	movl	neg_heap_p3,d1
	lea	-4(a0,d1),d1

	pushl	a0

	movl	-8(d0),d0

	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)

	movzwl	4(d0),d0
	movl	pointer_compare_address,d1

	cmpl	$8,d0
	jle	rmark_tuple_or_record_selector_node_2
	movl	8(a1),a1
	subl	$12,d0
rmark_tuple_or_record_selector_node_2:
	movl	(a1,d0),a0
	pop	a1
	movl	a0,(a3)
	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	jmp	rmark_node_d1
#else
	jbe	rmark_small_tuple_or_record
	jmp	rmark_large_tuple_or_record
#endif

rmark_strict_record_selector_node_1:
#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	shrl	$5,d1
	andl	$31,a2
	movl	bit_set_table(,a2,4),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1
#else
	bt	d1,(a4)
	jc	rmark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	rmark_hnf_1

	cmpw	$258,-2(d1)
	jbe	rmark_select_from_small_record

	movl	8(a1),d1
	addl	neg_heap_p3,d1
#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	shrl	$7,d1
	andl	$31*4,a2
	movl	bit_set_table(a2),a2
	movl	(a4,d1,4),d1
	andl	a2,d1
	jne	rmark_hnf_1
#else
	shrl	$2,d1
	bt	d1,(a4)
	jc	rmark_hnf_1
#endif

rmark_select_from_small_record:
	movl	-8(d0),d1
	subl	$4,a0

	cmpl	pointer_compare_address,a0
	ja	rmark_selector_pointer_not_reversed

#ifdef NEW_DESCRIPTORS
	movzwl	4(d1),d0
	cmpl	$8,d0
	jle	rmark_strict_record_selector_node_2
	addl	8(a1),d0
	movl	-12(d0),d0
	jmp	rmark_strict_record_selector_node_3
rmark_strict_record_selector_node_2:
	movl	(a1,d0),d0
rmark_strict_record_selector_node_3:
	movl	d0,4(a0)

	movzwl	6(d1),d0
	testl	d0,d0
	je	rmark_strict_record_selector_node_5
	cmpl	$8,d0
	jle	rmark_strict_record_selector_node_4
	movl	8(a1),a1
	subl	$12,d0
rmark_strict_record_selector_node_4:
	movl	(a1,d0),d0
	movl	d0,8(a0)
rmark_strict_record_selector_node_5:

	movl	-4(d1),d0
#else
	movl	d0,(a0)
	movl	a0,(a3)
	
	pushl	a3
	call	*4(d1)
	popl	a3

	movl	(a0),d0
#endif
	addl	$1,a3
	movl	a3,(a0)
	movl	d0,-1(a3)
	jmp	rmark_next_node

rmark_selector_pointer_not_reversed:
#ifdef NEW_DESCRIPTORS
	movzwl	4(d1),d0
	cmpl	$8,d0
	jle	rmark_strict_record_selector_node_6
	addl	8(a1),d0
	movl	-12(d0),d0
	jmp	rmark_strict_record_selector_node_7
rmark_strict_record_selector_node_6:
	movl	(a1,d0),d0
rmark_strict_record_selector_node_7:
	movl	d0,4(a0)

	movzwl	6(d1),d0
	testl	d0,d0
	je	rmark_strict_record_selector_node_9
	cmpl	$8,d0
	jle	rmark_strict_record_selector_node_8
	movl	8(a1),a1
	subl	$12,d0
rmark_strict_record_selector_node_8:
	movl	(a1,d0),d0
	movl	d0,8(a0)
rmark_strict_record_selector_node_9:

	movl	-4(d1),d0
	movl	d0,(a0)
#else
	call	*4(d1)
#endif
	jmp	rmark_next_node

rmark_reverse_and_mark_next_node:
	cmpl	d1,a0
	ja	rmark_next_node

	movl	(a0),d0
	movl	d0,(a3)
	addl	$1,a3
	movl	a3,(a0)

/ a2,d1: free

rmark_next_node:
	movl	(sp),a0
	movl	4(sp),a3
	addl	$8,sp

	cmpl	$1,a0
	ja	rmark_node

rmark_next_node_:
end_rmark_nodes:
	ret

rmark_lazy_node:
	movl	-4(d0),a2
	test	a2,a2
	je	rmark_next_node

	addl	$4,a0

	subl	$1,a2
	jle	rmark_lazy_node_1

	cmpl	$255,a2
	jge	rmark_closure_with_unboxed_arguments

rmark_closure_with_unboxed_arguments_:
	lea	(a0,a2,4),a0

rmark_push_lazy_args:
	movl	(a0),d1
	subl	$8,sp
	movl	a0,4(sp)
	subl	$4,a0
	movl	d1,(sp)
	subl	$1,a2
	jg	rmark_push_lazy_args

	movl	a0,a3
	movl	(a0),a0
	cmpl	end_stack,sp
	jae	rmark_node

	jmp	rmark_using_reversal

rmark_closure_with_unboxed_arguments:
/ (a_size+b_size)+(b_size<<8)
/	addl	$1,a2
	movl	a2,d0
	andl	$255,a2
	shrl	$8,d0
	subl	d0,a2
/	subl	$1,a2
	jg	rmark_closure_with_unboxed_arguments_
	je	rmark_hnf_1
	jmp	rmark_next_node

rmark_hnf_0:
#ifdef SHARE_CHAR_INT
	cmpl	$INT+2,d0
	je	rmark_int_3

	cmpl	$CHAR+2,d0
 	je	rmark_char_3

	jb	rmark_no_normal_hnf_0

	movl	neg_heap_p3,a2
	addl	a0,a2
#ifdef NO_BIT_INSTRUCTIONS
	movl	a2,a1
	andl	$31*4,a1
	shrl	$7,a2
	movl	bit_clear_table(a1),a1
	andl	a1,(a4,a2,4)
#else
	shrl	$2,a2
	btr	a2,(a4)
#endif
	lea	ZERO_ARITY_DESCRIPTOR_OFFSET-2(d0),a1
	movl	a1,(a3)
	cmpl	d1,a0
	ja	rmark_next_node
	movl	d0,(a0)
	jmp	rmark_next_node

rmark_int_3:
	movl	4(a0),a2
	cmpl	$33,a2
	jnc	rmark_next_node

	lea	small_integers(,a2,8),a1
	movl	neg_heap_p3,a2
	movl	a1,(a3)
	addl	a0,a2

#ifdef NO_BIT_INSTRUCTIONS
	movl	a2,a1
	andl	$31*4,a1
	shrl	$7,a2
	movl	bit_clear_table(a1),a1
	andl	a1,(a4,a2,4)
#else
	shrl	$2,a2
	btr	a2,(a4)
#endif
	cmpl	d1,a0
	ja	rmark_next_node
	movl	d0,(a0)
	jmp	rmark_next_node

rmark_char_3:
	movzbl	4(a0),a1
	movl	neg_heap_p3,a2

	lea	static_characters(,a1,8),a1
	addl	a0,a2

	movl	a1,(a3)

#ifdef NO_BIT_INSTRUCTIONS
	movl	a2,a1
	andl	$31*4,a1
	shrl	$7,a2
	movl	bit_clear_table(a1),a1
	andl	a1,(a4,a2,4)
#else
	shrl	$2,a2
	btr	a2,(a4)
#endif
	cmpl	d1,a0
	ja	rmark_next_node
	movl	d0,(a0)
	jmp	rmark_next_node

rmark_no_normal_hnf_0:
#endif

	cmpl	$__ARRAY__+2,d0
	jne	rmark_next_node

	movl	8(a0),d0
	test	d0,d0
	je	rmark_lazy_array

	movzwl	-2+2(d0),a1
	test	a1,a1
	je	rmark_b_array

	movzwl	-2(d0),d0
	test	d0,d0
	je	rmark_b_array

	cmpl	end_stack,sp
	jb	rmark_array_using_reversal

	subl	$256,d0
	cmpl	d0,a1
	movl	a1,d1
	je	rmark_a_record_array

rmark_ab_record_array:
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
	jmp	rmark_lr_array

rmark_b_array:
	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef NO_BIT_INSTRUCTIONS
	addl	$4,d0
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	orl	d0,(a4,a2,4)
#else
	shrl	$2,d0
	inc	d0
	bts	d0,(a4)
#endif
	jmp	rmark_next_node

rmark_a_record_array:
	movl	4(a0),d0
	addl	$8,a0
	cmpl	$2,d1
	jb	rmark_lr_array

	imull	d1,d0
	jmp	rmark_lr_array

rmark_lazy_array:
	cmpl	end_stack,sp
	jb	rmark_array_using_reversal

	movl	4(a0),d0
	addl	$8,a0

rmark_lr_array:
	movl	neg_heap_p3,d1
	addl	a0,d1
	shrl	$2,d1
	addl	d0,d1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a1
	andl	$31,d1
	shrl	$5,a1
	movl	bit_set_table(,d1,4),d1
	orl	d1,(a4,a1,4)
#else
	bts	d1,(a4)
#endif
	cmpl	$1,d0
	jbe	rmark_array_length_0_1
	movl	a0,a1
	lea	(a0,d0,4),a0

	movl	(a0),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,(a0)

	movl	-4(a0),d0
	subl	$4,a0
	movl	-4(a1),d1
	subl	$4,a1
	movl	d1,(a0)
	movl	d0,(a1)
	pushl	a0
	movl	a1,a3
	jmp	rmark_array_nodes

rmark_array_nodes1:
	cmpl	a3,a0
	ja	rmark_next_array_node

	movl	(a0),d1
	leal	1(a3),d0
	movl	d1,(a3)
	movl	d0,(a0)

rmark_next_array_node:
	addl	$4,a3
	cmpl	(sp),a3
	je	end_rmark_array_node

rmark_array_nodes:
	movl	(a3),a0

	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	rmark_next_array_node
#endif

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	movl	(a4,d1,4),a2
	test	d0,a2
	jne	rmark_array_nodes1
	
	orl	d0,a2
	movl	a2,(a4,d1,4)
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	rmark_array_nodes1
#endif

	movl	(a0),d0
	call	rmark_array_node

	addl	$4,a3
	cmpl	(sp),a3
	jne	rmark_array_nodes

end_rmark_array_node:
	addl	$4,sp
	jmp	rmark_next_node

rmark_array_node:
	subl	$8,sp
	movl	a3,4(sp)
	movl	a3,d1
	movl	$1,(sp)
	jmp	rmark_arguments

rmark_array_length_0_1:
	lea	-8(a0),a0
	jb	rmark_next_node

	movl	12(a0),d1
	movl	8(a0),a2
	movl	a2,12(a0)
	movl	4(a0),a2
	movl	a2,8(a0)
	movl	d1,4(a0)
	addl	$4,a0
	jmp	rmark_hnf_1

	.data
pointer_compare_address:	.long	0
	.text
