
mark_stack_nodes3:
	pop	a2

	movl	a0,-4(a2)
	jmp	mark_stack_nodes

mark_stack_nodes2:
	pop	a2

mark_stack_nodes1:
	movl	(a0),d1
	leal	1-4(a2),d0
	movl	d1,-4(a2)
	movl	d0,(a0)

mark_stack_nodes:
	cmpl	end_vector,a2
	je	end_mark_nodes

	movl	(a2),a0
	addl	$4,a2

	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	mark_stack_nodes
#endif

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	movl	(a4,d1,4),a3
	test	d0,a3
	jne	mark_stack_nodes1
	
	orl	d0,a3
	push	a2

	movl	a3,(a4,d1,4)
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	mark_stack_nodes1
	push	a2
#endif

	movl	$1,a3

mark_arguments:
	movl	(a0),d0
	testb	$2,d0b
	je	mark_lazy_node

	movzwl	-2(d0),a2
	test	a2,a2
	je	mark_hnf_0

	addl	$4,a0

	cmp	$256,a2
	jae	mark_record

	subl	$2,a2
	je	mark_hnf_2
	jc	mark_hnf_1

mark_hnf_3:
	movl	4(a0),a1

	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	test	(a4,d1,4),d0
	jne	shared_argument_part

	orl	d0,(a4,d1,4)	
#else
	shrl	$2,d0
	bts	d0,(a4)
	jc	shared_argument_part
#endif

no_shared_argument_part:
	orl	$2,(a0)
	movl	a3,4(a0)
	addl	$4,a0

	orl	$1,(a1)
	leal	(a1,a2,4),a1

	movl	(a1),a2
	movl	a0,(a1)
	movl	a1,a3
	movl	a2,a0
	jmp	mark_node

shared_argument_part:
	cmpl	a0,a1
	ja	mark_hnf_1

	movl	(a1),d1
	leal	4+2+1(a0),d0
	movl	d0,(a1)
	movl	d1,4(a0)
	jmp	mark_hnf_1

mark_record:	
	subl	$258,a2
	je	mark_record_2
	jb	mark_record_1

mark_record_3:
	movzwl	-2+2(d0),a2
	subl	$1,a2
	jb	mark_record_3_bb
	je	mark_record_3_ab
	dec	a2
	je	mark_record_3_aab
	jmp	mark_hnf_3

mark_record_3_bb:
	movl	8-4(a0),a1
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
	ja	mark_next_node

#ifdef NO_BIT_INSTRUCTIONS
	add	d0,d0
	jne	bit_in_same_word1
	inc	a2
	mov	$1,d0
bit_in_same_word1:
	testl	(a4,a2,4),d0
	je	not_yet_linked_bb
#else
	inc	d0
	bts	d0,(a4)
	jnc	not_yet_linked_bb
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
not_yet_linked_bb:
#endif
	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	mark_next_node

#ifdef NO_BIT_INSTRUCTIONS
not_yet_linked_bb:
	orl	d0,(a4,a2,4)
	movl	(a1),a2
	lea	8+2+1(a0),d0
	movl	a2,8(a0)
	movl	d0,(a1)
	jmp	mark_next_node
#endif

mark_record_3_ab:
	movl	4(a0),a1

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
	ja	mark_hnf_1

#ifdef NO_BIT_INSTRUCTIONS
	add	d0,d0
	jne	bit_in_same_word2
	inc	a2
	mov	$1,d0
bit_in_same_word2:
	testl	(a4,a2,4),d0
	je	not_yet_linked_ab
#else
	inc	d0
	bts	d0,(a4)
	jnc	not_yet_linked_ab
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
not_yet_linked_ab: 
#endif

	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	mark_hnf_1

#ifdef NO_BIT_INSTRUCTIONS
not_yet_linked_ab: 
	orl	d0,(a4,a2,4)
	movl	(a1),a2
	lea	4+2+1(a0),d0
	movl	a2,4(a0)
	movl	d0,(a1)
	jmp	mark_hnf_1
#endif

mark_record_3_aab:
	movl	4(a0),a1

	movl	neg_heap_p3,d0
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,d0
	shrl	$7,a2
	movl	bit_set_table(d0),d0
	testl	(a4,a2,4),d0
	jne	shared_argument_part
	orl	d0,(a4,a2,4)
#else
	shr	$2,d0
	bts	d0,(a4)
	jc	shared_argument_part
#endif
	addl	$2,(a0)
	movl	a3,4(a0)
	addl	$4,a0
	
	movl	(a1),a3
	movl	a0,(a1)
	movl	a3,a0
	lea	1(a1),a3
	jmp	mark_node

mark_record_2:
	cmpw	$1,-2+2(d0)
	ja	mark_hnf_2
	je	mark_hnf_1
	subl	$4,a0
	jmp	mark_next_node

mark_record_1:
	cmpw	$0,-2+2(d0)
	jne	mark_hnf_1
	subl	$4,a0
	jmp	mark_next_node

mark_lazy_node_1:
/ selectors:
	jne	mark_selector_node_1

mark_hnf_1:
	movl	(a0),a2
	movl	a3,(a0)

	leal	2(a0),a3
	movl	a2,a0
	jmp	mark_node

/ selectors
mark_indirection_node:
	movl	neg_heap_p3,d1
	leal	-4(a0,d1),d1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,d0
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_clear_table(d0),d0
	andl	d0,(a4,d1,4)
#else
	shrl	$2,d1
	btr	d1,(a4)
#endif
	movl	(a0),a0
	jmp	mark_node

mark_selector_node_1:
	addl	$3,a2
	je	mark_indirection_node

	movl	(a0),a1

	movl	neg_heap_p3,d1
	addl	a1,d1
	shrl	$2,d1

	addl	$1,a2
	jle	mark_record_selector_node_1

#ifdef NO_BIT_INSTRUCTIONS
	push	d0
	movl	d1,d0
	shrl	$5,d1
	andl	$31,d0
	movl	bit_set_table(,d0,4),d0
	movl	(a4,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	mark_hnf_1
#else
	bt	d1,(a4)
	jc	mark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	mark_hnf_1

	cmpw	$2,-2(d1)
	jbe	small_tuple_or_record

large_tuple_or_record:
	movl	8(a1),d1
	addl	neg_heap_p3,d1
	shrl	$2,d1

#ifdef NO_BIT_INSTRUCTIONS
	push	d0
	movl	d1,d0
	shrl	$5,d1
	andl	$31,d0
	movl	bit_set_table(,d0,4),d0
	movl	(a4,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	mark_hnf_1
#else
	bt	d1,(a4)
	jc	mark_hnf_1
#endif
small_tuple_or_record:
	movl	neg_heap_p3,d1
	lea	-4(a0,d1),d1

	pushl	a0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)
#else
	shrl	$2,d1
	btr	d1,(a4)
#endif
	movl	-8(d0),d0

	movl	a1,a0
	push	a2
	call	*4(d0)
	pop	a2
	pop	a1

	movl	$e__system__nind,-4(a1)
	movl	a0,(a1)
	
	jmp	mark_node

mark_record_selector_node_1:
	je	mark_strict_record_selector_node_1

#ifdef NO_BIT_INSTRUCTIONS
	push	d0
	movl	d1,d0
	shrl	$5,d1
	andl	$31,d0
	movl	bit_set_table(,d0,4),d0
	movl	(a4,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	mark_hnf_1
#else
	bt	d1,(a4)
	jc	mark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	mark_hnf_1

	cmpw	$258,-2(d1)
	jbe	small_tuple_or_record
	jmp	large_tuple_or_record

mark_strict_record_selector_node_1:
#ifdef NO_BIT_INSTRUCTIONS
	push	d0
	movl	d1,d0
	shrl	$5,d1
	andl	$31,d0
	movl	bit_set_table(,d0,4),d0
	movl	(a4,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	mark_hnf_1
#else
	bt	d1,(a4)
	jc	mark_hnf_1
#endif
	movl	(a1),d1
	testb	$2,d1b
	je	mark_hnf_1

	cmpw	$258,-2(d1)
	jbe	select_from_small_record

	movl	8(a1),d1
	addl	neg_heap_p3,d1
#ifdef NO_BIT_INSTRUCTIONS
	push	d0
	movl	d1,d0
	shrl	$7,d1
	andl	$31*4,d0
	movl	bit_set_table(d0),d0
	movl	(a4,d1,4),d1
	andl	d0,d1
	pop	d0
	jne	mark_hnf_1
#else
	shrl	$2,d1
	bt	d1,(a4)
	jc	mark_hnf_1
#endif

select_from_small_record:
/ changed 24-1-97
	movl	-8(d0),d0
	subl	$4,a0
	
	call	*4(d0)

	jmp	mark_next_node

mark_hnf_2:
	orl	$2,(a0)
	movl	4(a0),a2
	movl	a3,4(a0)
	leal	4(a0),a3
	movl	a2,a0

mark_node:
	movl	neg_heap_p3,d0
	addl	a0,d0
#ifdef SHARE_CHAR_INT
	cmpl	heap_size_32_33,d0
	jnc	mark_next_node_after_static
#endif

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	movl	bit_set_table(d0),d0
	movl	(a4,d1,4),a2
	test	d0,a2
	jne	mark_next_node
	
	orl	d0,a2
	movl	a2,(a4,d1,4)
	jmp	mark_arguments
#else
	shrl	$2,d0
	bts	d0,(a4)
	jnc	mark_arguments
#endif

/ a2,d1: free

mark_next_node:
	test	$3,a3
	jne	mark_parent

	movl	-4(a3),a2
	movl	$3,d1
	
	andl	a2,d1
	subl	$4,a3

	cmpl	$3,d1
	je	argument_part_cycle1

	movl	4(a3),a1
	movl	a1,(a3)

c_argument_part_cycle1:
	cmpl	a3,a0
	ja	no_reverse_1

	movl	(a0),a1
	leal	4+1(a3),d0
	movl	a1,4(a3)
	movl	d0,(a0)
	
	orl	d1,a3
	movl	a2,a0
	xorl	d1,a0
	jmp	mark_node

no_reverse_1:
	movl	a0,4(a3)
	movl	a2,a0
	orl	d1,a3
	xorl	d1,a0
	jmp	mark_node

mark_lazy_node:
	movl	-4(d0),a2
	test	a2,a2
	je	mark_next_node

	addl	$4,a0

	subl	$1,a2
	jle	mark_lazy_node_1

	cmpl	$255,a2
	jge	mark_closure_with_unboxed_arguments

mark_closure_with_unboxed_arguments_:
	orl	$2,(a0)
	leal	(a0,a2,4),a0

	movl	(a0),a2
	movl	a3,(a0)
	movl	a0,a3
	movl	a2,a0
	jmp	mark_node

mark_closure_with_unboxed_arguments:
/ (a_size+b_size)+(b_size<<8)
/	addl	$1,a2
	movl	a2,d0
	andl	$255,a2
	shrl	$8,d0
	subl	d0,a2
/	subl	$1,a2
	jg	mark_closure_with_unboxed_arguments_
	je	mark_hnf_1
	subl	$4,a0
	jmp	mark_next_node

mark_hnf_0:
#ifdef SHARE_CHAR_INT
	cmpl	$INT+2,d0
	je	mark_int_3

	cmpl	$CHAR+2,d0
 	je	mark_char_3

	jb	no_normal_hnf_0

	movl	neg_heap_p3,d1
	addl	a0,d1
#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)
#else
	shrl	$2,d1
	btr	d1,(a4)
#endif
	lea	ZERO_ARITY_DESCRIPTOR_OFFSET-2(d0),a0
	jmp	mark_next_node_after_static

mark_int_3:
	movl	4(a0),a2
	cmpl	$33,a2
	jnc	mark_next_node

	movl	neg_heap_p3,d1
	addl	a0,d1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a0
	andl	$31*4,a0
	shrl	$7,d1
	movl	bit_clear_table(a0),a0
	andl	a0,(a4,d1,4)
#else
	shrl	$2,d1
	btr	d1,(a4)
#endif
	lea	small_integers(,a2,8),a0
	jmp	mark_next_node_after_static

mark_char_3:
	movl	neg_heap_p3,d1

	movzbl	4(a0),d0
	addl	a0,d1

#ifdef NO_BIT_INSTRUCTIONS
	movl	d1,a2
	andl	$31*4,a2
	shrl	$7,d1
	movl	bit_clear_table(a2),a2
	andl	a2,(a4,d1,4)
#else
	shrl	$2,d1
	btr	d1,(a4)
#endif

	lea	static_characters(,d0,8),a0
	jmp	mark_next_node_after_static
	
no_normal_hnf_0:
#endif

	cmpl	$__ARRAY__+2,d0
	jne	mark_next_node

	movl	8(a0),d0
	test	d0,d0
	je	mark_lazy_array

	movzwl	-2+2(d0),d1
	test	d1,d1
	je	mark_b_record_array

	movzwl	-2(d0),d0
	test	d0,d0
	je	mark_b_record_array

	subl	$256,d0
	cmpl	d0,d1
	je	mark_a_record_array

mark_ab_record_array:
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
	jmp	mark_lr_array

mark_b_record_array:
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
	jmp	mark_next_node

mark_a_record_array:
	movl	4(a0),d0
	addl	$8,a0
	cmpl	$2,d1
	jb	mark_lr_array

	imull	d1,d0
	jmp	mark_lr_array

mark_lazy_array:
	movl	4(a0),d0
	addl	$8,a0

mark_lr_array:
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
	jbe	mark_array_length_0_1

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
	jmp	mark_node

mark_array_length_0_1:
	lea	-8(a0),a0
	jb	mark_next_node

	movl	12(a0),d1
	movl	8(a0),a2
	movl	a2,12(a0)
	movl	4(a0),a2
	movl	a2,8(a0)
	movl	d1,4(a0)
	addl	$4,a0
	jmp	mark_hnf_1

/ a2: free

mark_parent:
	movl	a3,d1
	andl	$3,d1

	andl	$-4,a3
	je	mark_stack_nodes2

	subl	$1,d1
	je	argument_part_parent

	movl	(a3),a2
	
	cmpl	a3,a0
	ja	no_reverse_2

	movl	a0,a1
	leal	1(a3),d0
	movl	(a1),a0
	movl	d0,(a1)

no_reverse_2:
	movl	a0,(a3)
	leal	-4(a3),a0
	movl	a2,a3
	jmp	mark_next_node
	

argument_part_parent:
	movl	(a3),a2

	movl	a3,a1
	movl	a0,a3
	movl	a1,a0

skip_upward_pointers:
	movl	a2,d0
	andl	$3,d0
	cmpl	$3,d0
	jne	no_upward_pointer

	leal	-3(a2),a1
	movl	-3(a2),a2
	jmp	skip_upward_pointers

no_upward_pointer:
	cmpl	a0,a3
	ja	no_reverse_3

	movl	a3,d1
	movl	(a3),a3
	leal	1(a0),d0
	movl	d0,(d1)
	
no_reverse_3:
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
	ja	no_reverse_4

	movl	(a0),d0
	movl	d0,4(a1)
	leal	4+2+1(a1),d0
	movl	d0,(a0)
	movl	a2,a0
	andl	$-4,a0
	jmp	mark_node

no_reverse_4:
	movl	a0,4(a1)
	movl	a2,a0
	andl	$-4,a0
	jmp	mark_node

argument_part_cycle1:
	movl	4(a3),d0
	push	a1

skip_pointer_list1:
	movl	a2,a1
	andl	$-4,a1
	movl	(a1),a2
	movl	$3,d1
	andl	a2,d1
	cmpl	$3,d1
	je	skip_pointer_list1

	movl	d0,(a1)
	pop	a1
	jmp	c_argument_part_cycle1

#ifdef SHARE_CHAR_INT
mark_next_node_after_static:
	test	$3,a3
	jne	mark_parent_after_static

	movl	-4(a3),a2
	movl	$3,d1
	
	andl	a2,d1
	subl	$4,a3

	cmpl	$3,d1
	je	argument_part_cycle2
	
	movl	4(a3),d0
	movl	d0,(a3)

c_argument_part_cycle2:
	movl	a0,4(a3)
	movl	a2,a0
	orl	d1,a3
	xorl	d1,a0
	jmp	mark_node

mark_parent_after_static:
	movl	a3,d1
	andl	$3,d1

	andl	$-4,a3
	je	mark_stack_nodes3

	subl	$1,d1
	je	argument_part_parent_after_static

	movl	(a3),a2
	movl	a0,(a3)
	leal	-4(a3),a0
	movl	a2,a3
	jmp	mark_next_node
	
argument_part_parent_after_static:
	movl	(a3),a2

	movl	a3,a1
	movl	a0,a3
	movl	a1,a0

/	movl	(a1),a2
skip_upward_pointers_2:
	movl	a2,d0
	andl	$3,d0
	cmpl	$3,d0
	jne	no_reverse_3

/	movl	a2,a1
/	andl	$-4,a1
/	movl	(a1),a2
	lea	-3(a2),a1
	movl	-3(a2),a2
	jmp	skip_upward_pointers_2

argument_part_cycle2:
	movl	4(a3),d0
	push	a1

skip_pointer_list2:
	movl	a2,a1
	andl	$-4,a1
	movl	(a1),a2
	movl	$3,d1
	andl	a2,d1
	cmpl	$3,d1
	je	skip_pointer_list2

	movl	d0,(a1)
	pop	a1
	jmp	c_argument_part_cycle2
#endif

end_mark_nodes:
	ret
