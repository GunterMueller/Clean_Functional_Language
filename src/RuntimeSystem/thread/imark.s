
#define d0 %eax
#define d1 %ebx
#define a0 %ecx
#define a1 %edx
#define a2 %ebp
#define a3 %esi
#define a4 %edi
#define sp %esp

	movl	heap_vector_offset(a4),d0
	shrl	$2,d0
	movl	d0,heap_vector_d4_offset(a4)

#undef MARK_USING_REVERSAL

	movl	heap_size_33_offset(a4),d0
	xorl	d1,d1

	movl	d1,n_marked_words_offset(a4)
	shl	$5,d0

	movl	d0,heap_size_32_33_offset(a4)
	movl	d1,lazy_array_list_offset(a4)

	lea	-2000(sp),a3

	movl	caf_list,d0

	movl	a3,end_stack_offset(a4)

	test	d0,d0
	je	_end_mark_cafs

_mark_cafs_lp:
	movl	(d0),d1
	movl	-4(d0),a2

	pushl	a2
	lea	4(d0),a2
	lea	4(d0,d1,4),d0
	movl	d0,end_vector_offset(a4)

	call	_mark_stack_nodes

	popl	d0
	test	d0,d0
	jne	_mark_cafs_lp

_end_mark_cafs:
	movl	stack_top_offset(a4),a3
	movl	stack_p_offset(a4),a2

	movl	a3,end_vector_offset(a4)	
	call	_mark_stack_nodes

	movl	lazy_array_list_offset(a4),a0

	test	a0,a0
	je	no_restore_arrays

	push	a4

restore_arrays:
	movl	(a0),d1
	movl	$__ARRAY__+2,(a0)

	cmpl	$1,d1
	je	restore_array_size_1

	lea	(a0,d1,4),a1	
	movl	8(a1),d0
	test	d0,d0
	je	restore_lazy_array

	movl	d0,a2
	push	a1

	xorl	a1,a1
	movl	d1,d0
	movzwl	-2+2(a2),d1

	div	d1
	movl	d0,d1

	pop	a1
	movl	a2,d0

restore_lazy_array:
	movl	8(a0),a4
	movl	4(a0),a2
	movl	d1,4(a0)
	movl	4(a1),a3
	movl	d0,8(a0)
	movl	a2,4(a1)
	movl	a4,8(a1)

	test	d0,d0
	je	no_reorder_array

	movzwl	-2(d0),a1
	subl	$256,a1
	movzwl	-2+2(d0),a2
	cmpl	a1,a2
	je	no_reorder_array

	addl	$12,a0
	imull	a1,d1
	movl	a1,d0
	lea	(a0,d1,4),a1
	movl	a2,d1
	subl	a2,d0

	call	reorder	

no_reorder_array:
	movl	a3,a0
	testl	a0,a0
	jne	restore_arrays

	jmp	end_restore_arrays

restore_array_size_1:
	movl	4(a0),a2
	movl	8(a0),a1
	movl	d1,4(a0)
	movl	12(a0),d0	
	movl	a2,12(a0)
	movl	d0,8(a0)

	movl	a1,a0
	testl	a0,a0
	jne	restore_arrays

end_restore_arrays:
	pop	a4

no_restore_arrays:

#ifdef FINALIZERS
	movl	$finalizer_list,a0
	movl	$free_finalizer_list,a1

	movl	(a0),a2
determine_free_finalizers_after_mark:
	cmpl	$__Nil-4,a2
	je	end_finalizers_after_mark

	movl	neg_heap_p3_offset(a4),d1
	addl	a2,d1
	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1
	movl	bit_set_table(d0),a3
	testl	(,d1,4),a3
	je	finalizer_not_used_after_mark

	lea	4(a2),a0
	movl	4(a2),a2
	jmp	determine_free_finalizers_after_mark

finalizer_not_used_after_mark:
	movl	a2,(a1)
	lea	4(a2),a1

	movl	4(a2),a2
	movl	a2,(a0)
	jmp	determine_free_finalizers_after_mark

end_finalizers_after_mark:
	movl	a2,(a1)
#endif

	call	add_garbage_collect_time

#ifndef ADJUST_HEAP_SIZE
	movl	heap_size_33_offset(a4),d0
	shl	$3,d0
#else
	movl	bit_vector_size_offset(a4),d0
	movl	d0,a3
	shl	$2,a3
	
	push	a1
	push	d0

	movl	n_allocated_words_offset(a4),d0
	addl	n_marked_words_offset(a4),d0
	shl	$2,d0

	mull	@heap_size_multiple
	shrd	$8,a1,d0
	shrl	$8,a1

	movl	d0,d1
	testl	a1,a1
	
	pop	d0
	pop	a1
	
	je	not_largest_heap
	
	movl	heap_size_33_offset(a4),d1
	shl	$5,d1

not_largest_heap:
	cmpl	a3,d1
	jbe	no_larger_heap

	movl	heap_size_33_offset(a4),a3
	shl	$5,a3
	cmpl	a3,d1
	jbe	not_larger_then_heap
	movl	a3,d1
not_larger_then_heap:
	movl	d1,d0
	shr	$2,d0
	movl	d0,bit_vector_size_offset(a4)
no_larger_heap:
#endif
	movl	d0,a2

	movl	heap_vector_offset(a4),a3

	shrl	$5,a2

	testb	$31,d0b
	je	no_extra_word
	movl	$0,(a3,a2,4)
no_extra_word:

	subl	n_marked_words_offset(a4),d0
	shl	$2,d0
	movl	d0,n_last_heap_free_bytes_offset(a4)

	testl	$2,@flags
	je	_no_heap_use_message2

	pushl	$marked_gc_string_1
	call	@ew_print_string
	addl	$4,sp

	movl	n_marked_words_offset(a4),d0
	shll	$2,d0
	pushl	d0
	call	@ew_print_int
	addl	$4,sp

	pushl	$heap_use_after_gc_string_2
	call	@ew_print_string
	addl	$4,sp

_no_heap_use_message2:

#ifdef FINALIZERS
	call	call_finalizers
#endif

	movl	n_allocated_words_offset(a4),a3
	xorl	d1,d1

	movl	heap_vector_offset(a4),a0
	movl	d1,n_free_words_after_mark_offset(a4)

_scan_bits:
	cmpl	(a0),d1
	je	_zero_bits
	movl	d1,(a0)
	addl	$4,a0
	subl	$1,a2
	jne	_scan_bits

	jmp	_end_scan

_zero_bits:
	lea	4(a0),a1
	addl	$4,a0
	subl	$1,a2
	jne	_skip_zero_bits_lp1
	jmp	_end_bits

_skip_zero_bits_lp:
	test	d0,d0
	jne	_end_zero_bits
_skip_zero_bits_lp1:
	movl	(a0),d0
	addl	$4,a0
	subl	$1,a2
	jne	_skip_zero_bits_lp

	test	d0,d0
	je	_end_bits
	movl	a0,d0
	movl	d1,-4(a0)
	subl	a1,d0
	jmp	_end_bits2	

_end_zero_bits:
	movl	a0,d0
	subl	a1,d0
	shl	$3,d0
	addl	d0,n_free_words_after_mark_offset(a4)
	movl	d1,-4(a0)

	cmpl	a3,d0
	jb	_scan_bits

_found_free_memory:
	movl	a2,bit_counter_offset(a4)
	movl	a0,bit_vector_p_offset(a4)

	lea	-4(a1),d1
	subl	heap_vector_offset(a4),d1
	shl	$5,d1

	movl	heap_p3_offset(a4),a2
	addl	d1,a2
	movl	a2,free_heap_offset(a4)

	movl	stack_top_offset(a4),a3

	lea	(a2,d0,4),d1
	movl	d1,heap_end_after_gc_offset(a4)
	subl	$32,d1
	movl	d1,end_heap_offset(a4)

	pop	d1
	pop	d0
	ret

_end_bits:
	movl	a0,d0
	subl	a1,d0
	addl	$4,d0
_end_bits2:
	shl	$3,d0
	addl	d0,n_free_words_after_mark_offset(a4)
	cmpl	a3,d0
	jae	_found_free_memory

_end_scan:
	movl	a2,bit_counter_offset(a4)
	jmp	compact_gc

/ a2: pointer to stack element
/ a4: heap_vector
/ d0,d1,a0,a1,a3: free

_mark_stack_nodes:
	cmpl	end_vector_offset(a4),a2
	je	_end_mark_nodes

_mark_stack_nodes_:
	movl	(a2),a0
	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_d4_offset(a4),d0

	addl	$4,a2

	addl	a0,d1
	cmpl	heap_size_32_33_offset(a4),d1
	jnc	_mark_stack_nodes

	movl	$31*4,a1
	andl	d1,a1	
	shrl	$7,d1
	addl	d0,d1

	movl	bit_set_table(a1),a3
	testl	(,d1,4),a3
	jne	_mark_stack_nodes

	pushl	a2

#ifdef MARK_USING_REVERSAL
	movl	$1,a3
	jmp	__mark_node

__end_mark_using_reversal:
	popl	a2
	movl	a0,-4(a2)
	jmp	_mark_stack_nodes
#else
	pushl	$0

	jmp	_mark_arguments

_mark_hnf_2:
	cmpl	$0x20000000,a3
	jbe	fits_in_word_6
	orl	$1,4(,d1,4)
fits_in_word_6:
	addl	$3,n_marked_words_offset(a4)

_mark_record_2_c:
	movl	4(a0),d1
	push	d1

	cmpl	end_stack_offset(a4),sp
	jb	__mark_using_reversal

_mark_node2:
_shared_argument_part:
	movl	(a0),a0

_mark_node:
	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_d4_offset(a4),d0

	addl	a0,d1
	cmpl	heap_size_32_33_offset(a4),d1
	jnc	_mark_next_node

	movl	$31*4,a1
	andl	d1,a1	
	shrl	$7,d1
	addl	d0,d1
	movl	bit_set_table(a1),a3		
	testl	(,d1,4),a3
	jne	_mark_next_node

_mark_arguments:
	movl	(a0),d0
	test	$2,d0
	je	_mark_lazy_node
	
	movzwl	-2(d0),a2
	test	a2,a2
	je	_mark_hnf_0

	orl	a3,(,d1,4)
	addl	$4,a0

	cmpl	$256,a2
	jae	_mark_record

	subl	$2,a2
	je	_mark_hnf_2
	jb	_mark_hnf_1

_mark_hnf_3:
	movl	4(a0),a1

	cmpl	$0x20000000,a3
	jbe	fits_in_word_1
	orl	$1,4(,d1,4)
fits_in_word_1:	

	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_d4_offset(a4),a3
	addl	a1,d1

	addl	$3,n_marked_words_offset(a4)

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	a3,d1

	movl	bit_set_table(d0),a3
	testl	(,d1,4),a3
	jne	_shared_argument_part

_no_shared_argument_part:
	orl	a3,(,d1,4)
	addl	$1,a2

	addl	a2,n_marked_words_offset(a4)
	lea	(d0,a2,4),d0
	lea	-4(a1,a2,4),a1

	cmpl	$32*4,d0
	jbe	fits_in_word_2
	orl	$1,4(,d1,4)
fits_in_word_2:

	movl	(a1),d1
	subl	$2,a2
	pushl	d1

_push_hnf_args:
	movl	-4(a1),d1
	subl	$4,a1
	pushl	d1
	subl	$1,a2
	jge	_push_hnf_args

	cmpl	end_stack_offset(a4),sp
	jae	_mark_node2

	jmp	__mark_using_reversal

_mark_hnf_1:
	cmpl	$0x40000000,a3
	jbe	fits_in_word_4
	orl	$1,4(,d1,4)
fits_in_word_4:
	addl	$2,n_marked_words_offset(a4)
	movl	(a0),a0
	jmp	_mark_node

_mark_lazy_node_1:
	addl	$4,a0
	orl	a3,(,d1,4)
	cmpl	$0x20000000,a3
	jbe	fits_in_word_3
	orl	$1,4(,d1,4)
fits_in_word_3:
	addl	$3,n_marked_words_offset(a4)

	cmpl	$1,a2
	je	_mark_node2

_mark_selector_node_1:
	cmpl	$-2,a2
	movl	(a0),a1
	je	_mark_indirection_node

	movl	neg_heap_p3_offset(a4),d1
	addl	a1,d1

	movl	$31*4,a3
	andl	d1,a3
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	cmpl	$-3,a2

	movl	bit_set_table(a3),a3
	jle	_mark_record_selector_node_1

	testl	(,d1,4),a3
	jne	_mark_node3

	movl	(a1),a2
	testl	$2,a2
	je	_mark_node3

	cmpw	$2,-2(a2)
	jbe	_small_tuple_or_record

_large_tuple_or_record:
	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	_mark_node3

	movl	-8(d0),d0
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	movzwl	4(d0),d0
	cmpl	$8,d0
	jl	_mark_tuple_selector_node_1
	movl	8(a1),a1
	je	_mark_tuple_selector_node_2
	movl	-12(a1,d0),a0
	movl	a0,(a2)
	jmp	_mark_node

_mark_tuple_selector_node_2:
	movl	(a1),a0
	movl	a0,(a2)
	jmp	_mark_node

_small_tuple_or_record:
	movl	-8(d0),d0
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	movzwl	4(d0),d0
_mark_tuple_selector_node_1:
	movl	(a1,d0),a0
	movl	a0,(a2)
	jmp	_mark_node

_mark_record_selector_node_1:
	je	_mark_strict_record_selector_node_1

	testl	(,d1,4),a3
	jne	_mark_node3

	movl	(a1),a2
	testl	$2,a2
	je	_mark_node3

	cmpw	$258,-2(a2)
	jbe	_small_tuple_or_record

	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	_mark_node3

	movl	-8(d0),d0
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	movzwl	4(d0),d0
	cmpl	$8,d0
	jle	_mark_record_selector_node_2
	movl	8(a1),a1
	subl	$12,d0
_mark_record_selector_node_2:
	movl	(a1,d0),a0

	movl	a0,(a2)
	jmp	_mark_node

_mark_strict_record_selector_node_1:
	testl	(,d1,4),a3
	jne	_mark_node3

	movl	(a1),a2
	testl	$2,a2
	je	_mark_node3

	cmpw	$258,-2(a2)
	jbe	_select_from_small_record

	movl	8(a1),d1
	addl	neg_heap_p3_offset(a4),d1	

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	_mark_node3
	
_select_from_small_record:
	movl	-8(d0),d0

	subl	$4,a0
	
	movzwl	4(d0),d1
	cmpl	$8,d1
	jle	_mark_strict_record_selector_node_2
	addl	8(a1),d1
	movl	-12(d1),d1
	jmp	_mark_strict_record_selector_node_3
_mark_strict_record_selector_node_2:
	movl	(a1,d1),d1
_mark_strict_record_selector_node_3:
	movl	d1,4(a0)

	movzwl	6(d0),d1
	testl	d1,d1
	je	_mark_strict_record_selector_node_5
	cmpl	$8,d1
	jle	_mark_strict_record_selector_node_4
	movl	8(a1),a1
	subl	$12,d1
_mark_strict_record_selector_node_4:
	movl	(a1,d1),d1
	movl	d1,8(a0)
_mark_strict_record_selector_node_5:

	movl	-4(d0),d0
	movl	d0,(a0)
	jmp	_mark_next_node

_mark_indirection_node:
_mark_node3:
	movl	a1,a0
	jmp	_mark_node

_mark_next_node:
	popl	a0
	test	a0,a0
	jne	_mark_node

	popl	a2
	cmpl	end_vector_offset(a4),a2
	jne	_mark_stack_nodes_

_end_mark_nodes:
	ret

_mark_lazy_node:
	movl	-4(d0),a2
	test	a2,a2
	je	_mark_real_or_file

	cmpl	$1,a2
	jle	_mark_lazy_node_1

	cmpl	$257,a2
	jge	_mark_closure_with_unboxed_arguments
	incl	a2
	orl	a3,(,d1,4)

	addl	a2,n_marked_words_offset(a4)
	lea	(a1,a2,4),a1
	lea	(a0,a2,4),a0

	cmpl	$32*4,a1
	jbe	fits_in_word_7
	orl	$1,4(,d1,4)
fits_in_word_7:
	subl	$3,a2
_push_lazy_args:
	movl	-4(a0),d1
	subl	$4,a0
	push	d1
	subl	$1,a2
	jge	_push_lazy_args

	subl	$4,a0

	cmpl	end_stack_offset(a4),sp
	jae	_mark_node2
	
	jmp	__mark_using_reversal

_mark_closure_with_unboxed_arguments:
	je	_mark_real_or_file

	movl	a2,d0
	andl	$255,a2

	shrl	$8,d0
	addl	$1,a2

	orl	a3,(,d1,4)
	addl	a2,n_marked_words_offset(a4)
	lea	(a1,a2,4),a1

	subl	d0,a2

	cmpl	$32*4,a1
	jbe	fits_in_word_7_
	orl	$1,4(,d1,4)
fits_in_word_7_:
	subl	$2,a2
	jl	_mark_next_node

	lea	8(a0,a2,4),a0
	jne	_push_lazy_args

_mark_closure_with_one_boxed_argument:
	movl	-4(a0),a0
	jmp	_mark_node

_mark_hnf_0:
	cmpl	$INT+2,d0
	jb	_mark_real_file_or_string

	orl	a3,(,d1,4)

	cmpl	$CHAR+2,d0
	ja	_mark_normal_hnf_0

_mark_bool:
	addl	$2,n_marked_words_offset(a4)

	cmpl	$0x40000000,a3
	jbe	_mark_next_node

	orl	$1,4(,d1,4)
	jmp	_mark_next_node

_mark_normal_hnf_0:
	incl	n_marked_words_offset(a4)
	jmp	_mark_next_node

_mark_real_file_or_string:
	cmpl	$__STRING__+2,d0
	jbe	_mark_string_or_array

_mark_real_or_file:
	orl	a3,(,d1,4)
	addl	$3,n_marked_words_offset(a4)

	cmpl	$0x20000000,a3
	jbe	_mark_next_node

	orl	$1,4(,d1,4)
	jmp	_mark_next_node

_mark_record:
	subl	$258,a2
	je	_mark_record_2
	jl	_mark_record_1

_mark_record_3:
	addl	$3,n_marked_words_offset(a4)

	cmpl	$0x20000000,a3
	jbe	fits_in_word_13
	orl	$1,4(,d1,4)
fits_in_word_13:
	movl	4(a0),a1
	movzwl	-2+2(d0),d1

	movl	neg_heap_p3_offset(a4),d0
	addl	a1,d0

	movl	$31*4,a3
	andl	d0,a3
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0

	subl	$1,d1

	movl	bit_set_table(a3),a1
	jb	_mark_record_3_bb

	testl	(,d0,4),a1
	jne	_mark_node2

	addl	$1,a2
	orl	a1,(,d0,4)
	addl	a2,n_marked_words_offset(a4)
	lea	(a3,a2,4),a3

	cmpl	$32*4,a3
	jbe	_push_record_arguments
	orl	$1,4(,d0,4)
_push_record_arguments:
	movl	4(a0),a1
	movl	d1,a2
	shl	$2,d1
	addl	d1,a1
	subl	$1,a2
	jge	_push_hnf_args

	jmp	_mark_node2

_mark_record_3_bb:
	testl	(,d0,4),a1
	jne	_mark_next_node

	addl	$1,a2
	orl	a1,(,d0,4)
	addl	a2,n_marked_words_offset(a4)
	lea	(a3,a2,4),a3
	
	cmpl	$32*4,a3
	jbe	_mark_next_node

	orl	$1,4(,d0,4)
	jmp	_mark_next_node

_mark_record_2:
	cmpl	$0x20000000,a3
	jbe	fits_in_word_12
	orl	$1,4(,d1,4)
fits_in_word_12:
	addl	$3,n_marked_words_offset(a4)

	cmpw	$1,-2+2(d0)
	ja	_mark_record_2_c
	je	_mark_node2
	jmp	_mark_next_node

_mark_record_1:
	cmpw	$0,-2+2(d0)
	jne	_mark_hnf_1

	jmp	_mark_bool

_mark_string_or_array:
	je	_mark_string_

_mark_array:
	movl	8(a0),a2
	test	a2,a2
	je	_mark_lazy_array

	movzwl	-2(a2),d0

	testl	d0,d0
	je	_mark_strict_basic_array

	movzwl	-2+2(a2),a2
	testl	a2,a2
	je	_mark_b_record_array

	cmpl	end_stack_offset(a4),sp
	jb	_mark_array_using_reversal

	subl	$256,d0
	cmpl	a2,d0
	je	_mark_a_record_array

_mark_ab_record_array:
	orl	a3,(,d1,4)
	movl	4(a0),a2

	imull	a2,d0
	addl	$3,d0

	addl	d0,n_marked_words_offset(a4)
	lea	-4(a0,d0,4),d0

	addl	neg_heap_p3_offset(a4),d0
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0
	
	cmpl	d0,d1
	jae	_end_set_ab_array_bits

	incl	d1
	movl	$1,a2
	cmpl	d0,d1
	jae	_last_ab_array_bits

_mark_ab_array_lp:
	orl	a2,(,d1,4)
	incl	d1
	cmpl	d0,d1
	jb	_mark_ab_array_lp

_last_ab_array_bits:
	orl	a2,(,d1,4)

_end_set_ab_array_bits:
	movl	4(a0),d0
	movl	8(a0),a1
	movzwl	-2+2(a1),d1
	movzwl	-2(a1),a1
	shll	$2,d1
	lea	-1024(,a1,4),a1
	pushl	d1
	pushl	a1
	lea	12(a0),a2
	pushl	end_vector_offset(a4)
	jmp	_mark_ab_array_begin
	
_mark_ab_array:
	movl	8(sp),d1
	pushl	d0
	pushl	a2
	lea	(a2,d1),d0

	movl	d0,end_vector_offset(a4)
	call	_mark_stack_nodes

	movl	4+8(sp),d1
	popl	a2
	popl	d0
	addl	d1,a2
_mark_ab_array_begin:
	subl	$1,d0
	jnc	_mark_ab_array

	popl	end_vector_offset(a4)
	addl	$8,sp
	jmp	_mark_next_node

_mark_a_record_array:
	orl	a3,(,d1,4)
	movl	4(a0),a2

	imull	a2,d0
	movl	d0,a1

	addl	$3,d0

	addl	d0,n_marked_words_offset(a4)
	lea	-4(a0,d0,4),d0

	addl	neg_heap_p3_offset(a4),d0
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0
	
	cmpl	d0,d1
	jae	_end_set_a_array_bits

	incl	d1
	movl	$1,a2
	cmpl	d0,d1
	jae	_last_a_array_bits

_mark_a_array_lp:
	orl	a2,(,d1,4)
	incl	d1
	cmpl	d0,d1
	jb	_mark_a_array_lp

_last_a_array_bits:
	orl	a2,(,d1,4)

_end_set_a_array_bits:
	lea	12(a0),a2
	lea	12(a0,a1,4),d0

	pushl	end_vector_offset(a4)
	movl	d0,end_vector_offset(a4)
	call	_mark_stack_nodes
	popl	end_vector_offset(a4)

	jmp	_mark_next_node

_mark_lazy_array:
	cmpl	end_stack_offset(a4),sp
	jb	_mark_array_using_reversal

	orl	a3,(,d1,4)
	movl	4(a0),d0

	movl	d0,a1
	addl	$3,d0

	addl	d0,n_marked_words_offset(a4)
	lea	-4(a0,d0,4),d0

	addl	neg_heap_p3_offset(a4),d0
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0
	
	cmpl	d0,d1
	jae	_end_set_lazy_array_bits

	incl	d1
	movl	$1,a2
	cmpl	d0,d1
	jae	_last_lazy_array_bits

_mark_lazy_array_lp:
	orl	a2,(,d1,4)
	incl	d1
	cmpl	d0,d1
	jb	_mark_lazy_array_lp

_last_lazy_array_bits:
	orl	a2,(,d1,4)

_end_set_lazy_array_bits:
	lea	12(a0),a2
	lea	12(a0,a1,4),d0

	pushl	end_vector_offset(a4)
	movl	d0,end_vector_offset(a4)
	call	_mark_stack_nodes
	popl	end_vector_offset(a4)

	jmp	_mark_next_node

_mark_array_using_reversal:
	pushl	$0
	movl	$1,a3
	jmp	__mark_node

_mark_strict_basic_array:
	movl	4(a0),d0
	cmpl	$INT+2,a2
	je	_mark_strict_int_array
	cmpl	$BOOL+2,a2
	je	_mark_strict_bool_array
_mark_strict_real_array:
	addl	d0,d0
_mark_strict_int_array:
	addl	$3,d0
	jmp	_mark_basic_array_
_mark_strict_bool_array:
	addl	$12+3,d0
	shrl	$2,d0
	jmp	_mark_basic_array_

_mark_b_record_array:
	movl	4(a0),a2
	subl	$256,d0
	imull	a2,d0
	addl	$3,d0
	jmp	_mark_basic_array_

_mark_string_:
	movl	4(a0),d0
	addl	$8+3,d0
	shrl	$2,d0

_mark_basic_array_:
	orl	a3,(,d1,4)

	addl	d0,n_marked_words_offset(a4)
	lea	-4(a0,d0,4),d0

	addl	neg_heap_p3_offset(a4),d0
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0

	cmpl	d0,d1
	jae	_mark_next_node

	incl	d1
	movl	$1,a2
	cmpl	d0,d1
	jae	_last_string_bits

_mark_string_lp:
	orl	a2,(,d1,4)
	incl	d1
	cmpl	d0,d1
	jb	_mark_string_lp

_last_string_bits:
	orl	a2,(,d1,4)
	jmp	_mark_next_node

__end_mark_using_reversal:
	popl	a1
	test	a1,a1
	je	_mark_next_node
	movl	a0,(a1)
	jmp	_mark_next_node
#endif

__mark_using_reversal:
	pushl	a0
	movl	$1,a3
	movl	(a0),a0
	jmp	__mark_node

__mark_arguments:
	movl	(a0),d0
	test	$2,d0
	je	__mark_lazy_node

	movzwl	-2(d0),a2
	testl	a2,a2
	je	__mark_hnf_0

	addl	$4,a0

	cmpl	$256,a2
	jae	__mark__record

	subl	$2,a2
	je	__mark_hnf_2
	jb	__mark_hnf_1

__mark_hnf_3:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)

	orl	a1,(,d1,4)

	cmpl	$0x20000000,a1

	movl	heap_vector_d4_offset(a4),a1

	jbe	fits__in__word__1
	orl	$1,4(,d1,4)
fits__in__word__1:
	movl	4(a0),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1
	addl	a1,d1

	movl	bit_set_table(d0),a1
	testl	(,d1,4),a1
	jne	__shared_argument_part

__no_shared_argument_part:
	orl	a1,(,d1,4)
	movl	4(a0),a1

	addl	$1,a2
	movl	a3,4(a0)

	addl	a2,n_marked_words_offset(a4)
	addl	$4,a0

	shl	$2,a2
	orl	$1,(a1)

	addl	a2,d0
	addl	a2,a1

	cmpl	$32*4,d0
	jbe	fits__in__word__2
	orl	$1,4(,d1,4)
fits__in__word__2:

	movl	-4(a1),a2
	movl	a0,-4(a1)
	lea	-4(a1),a3
	movl	a2,a0
	jmp	__mark_node

__mark_hnf_1:
	movl	bit_set_table(a1),a1
	addl	$2,n_marked_words_offset(a4)
	orl	a1,(,d1,4)
	cmpl	$0x40000000,a1
	jbe	__shared_argument_part
	orl	$1,4(,d1,4)
__shared_argument_part:
	movl	(a0),a2
	movl	a3,(a0)
	lea	2(a0),a3
	movl	a2,a0
	jmp	__mark_node

__mark_no_selector_2:
	popl	d1
__mark_no_selector_1:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)
	orl	a1,(,d1,4)	
	cmpl	$0x20000000,a1
	jbe	__shared_argument_part

	orl	$1,4(,d1,4)
	jmp	__shared_argument_part

__mark_lazy_node_1:
	je	__mark_no_selector_1

__mark_selector_node_1:
	cmpl	$-2,a2
	je	__mark_indirection_node

	cmpl	$-3,a2

	pushl	d1
	movl	(a0),a2
	pushl	d0
	movl	neg_heap_p3_offset(a4),d0

	jle	__mark_record_selector_node_1

	addl	a2,d0

	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(d0),d0
	testl	(,d1,4),d0
	popl	d0
	jne	__mark_no_selector_2

	movl	(a2),d1
	testb	$2,d1b
	je	__mark_no_selector_2

	cmpw	$2,-2(d1)
	jbe	__small_tuple_or_record

__large_tuple_or_record:	
	movl	8(a2),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	__mark_no_selector_2

	movl	-8(d0),d0
	movl	(a0),a1
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	popl	d1

	movzwl	4(d0),d0
	cmpl	$8,d0
	jl	__mark_tuple_selector_node_1
	movl	8(a1),a1
	je	__mark_tuple_selector_node_2
	subl	$12,d0
	movl	(a1,d0),a0
	movl	a0,(a2)
	jmp	__mark_node

__mark_tuple_selector_node_2:
	movl	(a1),a0
	movl	a0,(a2)
	jmp	__mark_node

__small_tuple_or_record:
	movl	-8(d0),d0
	movl	(a0),a1
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	popl	d1

	movzwl	4(d0),d0
__mark_tuple_selector_node_1:
	movl	(a1,d0),a0
	movl	a0,(a2)
	jmp	__mark_node

__mark_record_selector_node_1:
	je	__mark_strict_record_selector_node_1

	addl	a2,d0

	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(d0),d0
	testl	(,d1,4),d0
	popl	d0
	jne	__mark_no_selector_2

	movl	(a2),d1
	testb	$2,d1b
	je	__mark_no_selector_2

	cmpw	$258,-2(d1)
	jbe	__small_record

	movl	8(a2),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	__mark_no_selector_2

__small_record:
	movl	-8(d0),d0
	movl	(a0),a1
	movl	$e__system__nind,-4(a0)
	movl	a0,a2

	popl	d1

	movzwl	4(d0),d0
	cmpl	$8,d0
	jle	__mark_record_selector_node_2
	movl	8(a1),a1
	subl	$12,d0
__mark_record_selector_node_2:
	movl	(a1,d0),a0

	movl	a0,(a2)
	jmp	__mark_node

__mark_strict_record_selector_node_1:
	addl	a2,d0

	movl	d0,d1
	andl	$31*4,d0
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(d0),d0
	testl	(,d1,4),d0
	popl	d0
	jne	__mark_no_selector_2

	movl	(a2),d1
	testb	$2,d1b
	je	__mark_no_selector_2

	cmpw	$258,-2(d1)
	jle	__select_from_small_record

	movl	8(a2),d1
	addl	neg_heap_p3_offset(a4),d1

	movl	$31*4,a2
	andl	d1,a2
	shrl	$7,d1
	addl	heap_vector_d4_offset(a4),d1

	movl	bit_set_table(a2),a2
	testl	(,d1,4),a2
	jne	__mark_no_selector_2

__select_from_small_record:
	movl	-8(d0),d0
	movl	(a0),a1
	popl	d1
	subl	$4,a0

	movzwl	4(d0),d1
	cmpl	$8,d1
	jle	__mark_strict_record_selector_node_2
	addl	8(a1),d1
	movl	-12(d1),d1
	jmp	__mark_strict_record_selector_node_3
__mark_strict_record_selector_node_2:
	movl	(a1,d1),d1
__mark_strict_record_selector_node_3:
	movl	d1,4(a0)
	
	movzwl	6(d0),d1
	testl	d1,d1
	je	__mark_strict_record_selector_node_5
	cmpl	$8,d1
	jle	__mark_strict_record_selector_node_4
	movl	8(a1),a1
	subl	$12,d1
__mark_strict_record_selector_node_4:
	movl	(a1,d1),d1
	movl	d1,8(a0)
__mark_strict_record_selector_node_5:

	movl	-4(d0),d0
	movl	d0,(a0)
	jmp	__mark_node

__mark_indirection_node:
	movl	(a0),a0
	jmp	__mark_node

__mark_hnf_2:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)
	orl	a1,(,d1,4)
	cmpl	$0x20000000,a1
	jbe	fits__in__word__6
	orl	$1,4(,d1,4)
fits__in__word__6:

__mark_record_2_c:
	movl	(a0),d0
	movl	4(a0),a2
	orl	$2,d0
	movl	a3,4(a0)
	movl	d0,(a0)
	lea	4(a0),a3
	movl	a2,a0

__mark_node:
	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_d4_offset(a4),d0

	addl	a0,d1
	cmpl	heap_size_32_33_offset(a4),d1
	jae	__mark_next_node

	movl	$31*4,a1
	andl	d1,a1
	shrl	$7,d1
	addl	d0,d1
	movl	bit_set_table(a1),a2
	testl	(,d1,4),a2
	je	__mark_arguments

__mark_next_node:
	testl	$3,a3
	jne	__mark_parent

	movl	-4(a3),a2
	movl	(a3),a1
	movl	a0,(a3)
	movl	a1,-4(a3)
	subl	$4,a3

	movl	a2,a0
	andl	$3,a2
	andl	$-4,a0
	orl	a2,a3
	jmp	__mark_node

__mark_parent:
	movl	a3,d1
	andl	$-4,a3
	je	__end_mark_using_reversal

	andl	$3,d1
	movl	(a3),a2
	movl	a0,(a3)

	subl	$1,d1
	je	__argument_part_parent

	lea	-4(a3),a0
	movl	a2,a3
	jmp	__mark_next_node
	
__argument_part_parent:
	andl	$-4,a2
	movl	a3,a1
	movl	-4(a2),a0
	movl	(a2),d1
	movl	d1,-4(a2)
	movl	a1,(a2)
	lea	2-4(a2),a3
	jmp	__mark_node

__mark_lazy_node:
	movl	-4(d0),a2
	testl	a2,a2
	je	__mark_real_or_file

	addl	$4,a0
	cmpl	$1,a2
	jle	__mark_lazy_node_1
	cmpl	$257,a2
	jge	__mark_closure_with_unboxed_arguments

	addl	$1,a2
	movl	a1,d0
	movl	bit_set_table(a1),a1
	addl	a2,n_marked_words_offset(a4)

	lea	(d0,a2,4),d0
	subl	$2,a2

	orl	a1,(,d1,4)

	cmpl	$32*4,d0
	jbe	fits__in__word__7
	orl	$1,4(,d1,4)
fits__in__word__7:
__mark_closure_with_unboxed_arguments__2:
	lea	(a0,a2,4),a1
	movl	(a0),d0
	orl	$2,d0
	movl	d0,(a0)	
	movl	(a1),a0
	movl	a3,(a1)
	movl	a1,a3
	jmp	__mark_node

__mark_closure_with_unboxed_arguments:
	je	__mark_closure_1_with_unboxed_argument

	movl	bit_set_table(a1),d0
	orl	d0,(,d1,4)

	movl	a2,d0
	andl	$255,a2

	addl	$1,a2
	shrl	$8,d0
	addl	a2,n_marked_words_offset(a4)

	lea	(a1,a2,4),a1
	subl	d0,a2

	cmpl	$32*4,a1
	jbe	fits__in_word_7_
	orl	$1,4(,d1,4)
fits__in_word_7_:
	subl	$2,a2
	jg	__mark_closure_with_unboxed_arguments__2
	je	__shared_argument_part
	subl	$4,a0
	jmp	__mark_next_node

__mark_closure_1_with_unboxed_argument:
	subl	$4,a0
	jmp	__mark_real_or_file

__mark_hnf_0:
	cmpl	$INT+2,d0
	jne	__no_int_3

	movl	4(a0),a2
	cmpl	$33,a2
	jb	____small_int

__mark_bool_or_small_string:
	movl	bit_set_table(a1),a1
	addl	$2,n_marked_words_offset(a4)
	orl	a1,(,d1,4)
	cmpl	$0x40000000,a1
	jbe	__mark_next_node
	orl	$1,4(,d1,4)
	jmp	__mark_next_node

____small_int:
	lea	small_integers(,a2,8),a0
	jmp	__mark_next_node

__no_int_3:
	jb	__mark_real_file_or_string

 	cmpl	$CHAR+2,d0
 	jne	__no_char_3
	movzbl	4(a0),a2
	lea	static_characters(,a2,8),a0
	jmp	__mark_next_node

__no_char_3:
	jb	__mark_bool_or_small_string

	lea	ZERO_ARITY_DESCRIPTOR_OFFSET-2(d0),a0
	jmp	__mark_next_node
	
__mark_real_file_or_string:
	cmpl	$__STRING__+2,d0
	jbe	__mark_string_or_array

__mark_real_or_file:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)

	orl	a1,(,d1,4)
	
	cmpl	$0x20000000,a1
	jbe	__mark_next_node

	orl	$1,4(,d1,4)
	jmp	__mark_next_node

__mark__record:
	subl	$258,a2
	je	__mark_record_2
	jl	__mark_record_1

__mark_record_3:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)
	orl	a1,(,d1,4)
	cmpl	$0x20000000,a1
	jbe	fits__in__word__13
	orl	$1,4(,d1,4)
fits__in__word__13:
	movzwl	-2+2(d0),d1

	movl	4(a0),d0
	addl	neg_heap_p3_offset(a4),d0

	movl	$31*4,a1
	andl	d0,a1
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0

	pushl	a3

	movl	bit_set_table(a1),a3
	testl	(,d0,4),a3
	jne	__shared_record_argument_part

	addl	$1,a2
	orl	a3,(,d0,4)

	lea	(a1,a2,4),a1
	addl	a2,n_marked_words_offset(a4)

	popl	a3

	cmpl	$32*4,a1
	jbe	fits__in__word__14
	orl	$1,4(,d0,4)
fits__in__word__14:
	subl	$1,d1
	movl	4(a0),a1
	jl	__mark_record_3_bb
	je	__shared_argument_part

	movl	a3,4(a0)
	addl	$4,a0

	subl	$1,d1
	je	__mark_record_3_aab

	lea	(a1,d1,4),a3
	movl	(a1),d0
	orl	$1,d0
	movl	(a3),a2
	movl	d0,(a1)
	movl	a0,(a3)
	movl	a2,a0
	jmp	__mark_node

__mark_record_3_bb:
	subl	$4,a0
	jmp	__mark_next_node

__mark_record_3_aab:
	movl	(a1),a2
	movl	a0,(a1)
	lea	1(a1),a3
	movl	a2,a0
	jmp	__mark_node

__shared_record_argument_part:
	movl	4(a0),a1

	popl	a3

	test	d1,d1
	jne	__shared_argument_part
	subl	$4,a0
	jmp	__mark_next_node

__mark_record_2:
	movl	bit_set_table(a1),a1
	addl	$3,n_marked_words_offset(a4)
	orl	a1,(,d1,4)
	cmpl	$0x20000000,a1
	jbe	fits__in__word_12
	orl	$1,4(,d1,4)
fits__in__word_12:
	cmpw	$1,-2+2(d0)
	ja	__mark_record_2_c
	je	__shared_argument_part
	subl	$4,a0
	jmp	__mark_next_node

__mark_record_1:
	cmpw	$0,-2+2(d0)
	jne	__mark_hnf_1
	subl	$4,a0
	jmp	__mark_bool_or_small_string

__mark_string_or_array:
	je	__mark_string_

__mark_array:
	movl	8(a0),a2
	test	a2,a2
	je	__mark_lazy_array

	movzwl	-2(a2),d0
	test	d0,d0
	je	__mark_strict_basic_array

	movzwl	-2+2(a2),a2
	test	a2,a2
	je	__mark_b_record_array

	subl	$256,d0
	cmpl	a2,d0
	je	__mark_a_record_array

__mark__ab__record__array:
	pushl	a1
	pushl	d1
	movl	a2,d1

	movl	4(a0),a2
	addl	$8,a0
	pushl	a0

	shl	$2,a2
	movl	d0,a1
	imull	a2,a1

	subl	d1,d0
	addl	$4,a0
	addl	a0,a1

	call	reorder
	
	popl	a0

	xchg	d1,d0
	movl	-4(a0),a2
	imull	a2,d0
	imull	a2,d1
	addl	d1,n_marked_words_offset(a4)
	addl	d0,d1

	movl	neg_heap_p3_offset(a4),a2
	shl	$2,d1
	addl	a0,a2
	addl	d1,a2

	popl	d1
	popl	a1

	movl	bit_set_table(a1),a1
	orl	a1,(,d1,4)

	lea	(a0,d0,4),a1
	jmp	__mark_r_array

__mark_a_record_array:
	imull	4(a0),d0
	addl	$8,a0	
	jmp	__mark_lr_array

__mark_lazy_array:
	movl	4(a0),d0
	addl	$8,a0

__mark_lr_array:
	movl	bit_set_table(a1),a1
	movl	neg_heap_p3_offset(a4),a2
	orl	a1,(,d1,4)
	lea	(a0,d0,4),a1
	addl	a1,a2
__mark_r_array:
	shrl	$7,a2
	addl	heap_vector_d4_offset(a4),a2

	cmpl	a2,d1
	jae	__skip_mark_lazy_array_bits

	inc	d1

__mark_lazy_array_bits:
	orl	$1,(,d1,4)
	inc	d1
	cmpl	a2,d1
	jbe	__mark_lazy_array_bits

__skip_mark_lazy_array_bits:
	movl	n_marked_words_offset(a4),a2
	addl	$3,a2
	addl	d0,a2

	cmpl	$1,d0
	movl	a2,n_marked_words_offset(a4)
	jbe	__mark_array_length_0_1

	movl	(a1),a2
	movl	(a0),d1
	movl	d1,(a1)
	movl	a2,(a0)
	
	movl	-4(a1),a2
	subl	$4,a1
	movl	lazy_array_list_offset(a4),d1
	addl	$2,a2
	movl	d1,(a1)
	movl	a2,-4(a0)
	movl	d0,-8(a0)
	subl	$8,a0
	movl	a0,lazy_array_list_offset(a4)

	movl	-4(a1),a0
	movl	a3,-4(a1)
	lea	-4(a1),a3
	jmp	__mark_node

__mark_array_length_0_1:
	lea	-8(a0),a0
	jb	__mark_next_node

	movl	12(a0),d1
	movl	8(a0),a2
	movl	lazy_array_list_offset(a4),a1
	movl	a2,12(a0)	
	movl	a1,8(a0)
	movl	d0,(a0)
	movl	a0,lazy_array_list_offset(a4)	
	movl	d1,4(a0)
	addl	$4,a0

	movl	(a0),a2
	movl	a3,(a0)
	lea	2(a0),a3
	movl	a2,a0
	jmp	__mark_node
	
__mark_b_record_array:
	movl	4(a0),a2
	subl	$256,d0
	imull	a2,d0
	addl	$3,d0
	jmp	__mark_basic_array

__mark_strict_basic_array:
	movl	4(a0),d0
	cmpl	$INT+2,a2
	je	__mark__strict__int__array
	cmpl	$BOOL+2,a2
	je	__mark__strict__bool__array
__mark__strict__real__array:
	addl	d0,d0
__mark__strict__int__array:
	addl	$3,d0
	jmp	__mark_basic_array
__mark__strict__bool__array:
	addl	$12+3,d0
	shrl	$2,d0
	jmp	__mark_basic_array

__mark_string_:
	movl	4(a0),d0
	addl	$8+3,d0
	shr	$2,d0

__mark_basic_array:
	movl	bit_set_table(a1),a1
	addl	d0,n_marked_words_offset(a4)

	orl	a1,(,d1,4)
	lea	-4(a0,d0,4),d0

	addl	neg_heap_p3_offset(a4),d0
	shrl	$7,d0
	addl	heap_vector_d4_offset(a4),d0

	cmpl	d0,d1
	jae	__mark_next_node

	incl	d1
	movl	$1,a2

	cmpl	d0,d1
	jae	__last__string__bits

__mark_string_lp:
	orl	a2,(,d1,4)
	incl	d1
	cmpl	d0,d1
	jb	__mark_string_lp

__last__string__bits:
	orl	a2,(,d1,4)
	jmp	__mark_next_node
