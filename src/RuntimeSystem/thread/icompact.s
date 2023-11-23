
/ mark used nodes and pointers in argument parts and link backward pointers

	movl	heap_vector_offset(a4),d0
	shrl	$2,d0
	movl	d0,heap_vector_d4_offset(a4)

	movl	heap_size_33_offset(a4),d0
	shl	$5,d0
	movl	d0,heap_size_32_33_offset(a4)

	lea	-8000(sp),a3

	movl	caf_list,d0
	movl	a3,end_stack_offset(a4)

	test	d0,d0
	je	end_mark_cafs

mark_cafs_lp:
	pushl	-4(d0)

	lea	4(d0),a3
	movl	(d0),d0
	lea	(a3,d0,4),a0

	movl	a0,end_vector_offset(a4)

	call	rmark_stack_nodes
	
	popl	d0
	test	d0,d0
	jne	mark_cafs_lp

end_mark_cafs:
	movl	stack_p_offset(a4),a3

	movl	stack_top_offset(a4),a0
	movl	a0,end_vector_offset(a4)
	call	rmark_stack_nodes
	
	jmp	compact_heap

#include "icompact_rmark.s"
#include "icompact_rmarkr.s"

/ compact the heap

compact_heap:

#ifdef FINALIZERS
	movl	$finalizer_list,a0
	movl	$free_finalizer_list,a1

	movl	(a0),a2
determine_free_finalizers_after_compact1:
	cmpl	$__Nil-4,a2
	je	end_finalizers_after_compact1

	movl	neg_heap_p3_offset(a4),d1
	movl	heap_vector_offset(a4),a3
	addl	a2,d1

	movl	$31*4,d0
	andl	d1,d0
	shrl	$7,d1

	movl	bit_set_table(d0),d0
	testl	(a3,d1,4),d0
	je	finalizer_not_used_after_compact1

	movl	(a2),d0
	movl	a2,a3
	jmp	finalizer_find_descriptor

finalizer_find_descriptor_lp:
	andl	$-4,d0
	movl	d0,a3
	movl	(d0),d0
finalizer_find_descriptor:
	test	$1,d0
	jne	finalizer_find_descriptor_lp

	movl	$e____system__kFinalizerGCTemp+2,(a3)

	cmpl	a0,a2
	ja	finalizer_no_reverse

	movl	(a2),d0
	leal	1(a0),a3
	movl	a3,(a2)
	movl	d0,(a0)

finalizer_no_reverse:
	lea	4(a2),a0
	movl	4(a2),a2
	jmp	determine_free_finalizers_after_compact1

finalizer_not_used_after_compact1:
	movl	$e____system__kFinalizerGCTemp+2,(a2)

	movl	a2,(a1)
	lea	4(a2),a1

	movl	4(a2),a2
	movl	a2,(a0)

	jmp	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	movl	a2,(a1)	

	movl	finalizer_list,a0
	cmpl	$__Nil-4,a0
	je	finalizer_list_empty
	testl	$3,a0
	jne	finalizer_list_already_reversed
	movl	(a0),d0
	movl	$finalizer_list+1,(a0)
	movl	d0,finalizer_list
finalizer_list_already_reversed:
finalizer_list_empty:

	movl	$free_finalizer_list,a3
	cmpl	$__Nil-4,(a3)

	je	free_finalizer_list_empty

	movl	$free_finalizer_list+4,end_vector_offset(a4)

	call	rmark_stack_nodes
free_finalizer_list_empty:
#endif

a4_compact_sp_offset		= 0
heap_p3_compact_sp_offset	= 4
heap_vector_compact_sp_offset	= 8
neg_heap_p3_compact_sp_offset	= 12
neg_heap_vector_plus_4_compact_sp_offset = 16
vector_counter_compact_sp_offset = 20
vector_p_compact_sp_offset	= 24
end_heap_p3_compact_sp_offset	= 28
compact_sp_offset_2		= 32
compact_sp_offset_1		= 36

	lea	-40(sp),sp
	movl	a4,a4_compact_sp_offset(sp)

	movl	heap_p3_offset(a4),d0
	movl	d0,heap_p3_compact_sp_offset(sp)

	movl	neg_heap_p3_offset(a4),d0
	movl	d0,neg_heap_p3_compact_sp_offset(sp)

	movl	heap_vector_offset(a4),d0
	movl	d0,heap_vector_compact_sp_offset(sp)

	movl	heap_size_33_offset(a4),d0

	movl	d0,d1
	shl	$5,d1

	addl	heap_p3_compact_sp_offset(sp),d1

	movl	d1,end_heap_p3_compact_sp_offset(sp)

	addl	$3,d0
	shr	$2,d0
	
	movl	heap_vector_compact_sp_offset(sp),a0

	lea	4(a0),d1
	negl	d1
	movl	d1,neg_heap_vector_plus_4_compact_sp_offset(sp)

	movl	heap_p3_compact_sp_offset(sp),a4
	xorl	a3,a3
	jmp	skip_zeros

/ d0,a0,a2: free
find_non_zero_long:
	movl	vector_counter_compact_sp_offset(sp),d0
	movl	vector_p_compact_sp_offset(sp),a0
skip_zeros:
	subl	$1,d0
	jc	end_copy
	movl	(a0),a3
	addl	$4,a0
	testl	a3,a3
	je	skip_zeros
/ a2: free
end_skip_zeros:
	movl	neg_heap_vector_plus_4_compact_sp_offset(sp),a2
	movl	d0,vector_counter_compact_sp_offset(sp)

	addl	a0,a2
	movl	a0,vector_p_compact_sp_offset(sp)

	shl	$5,a2
	addl	heap_p3_compact_sp_offset(sp),a2

#ifdef NO_BIT_INSTRUCTIONS
bsf_and_copy_nodes:
	movl	a3,d0
	movl	a3,a0
	andl	$0xff,d0
	jne	found_bit1
	andl	$0xff00,a0
	jne	found_bit2
	movl	a3,d0
	movl	a3,a0
	andl	$0xff0000,d0
	jne	found_bit3
	shrl	$24,a0
	movzbl	first_one_bit_table(,a0,1),d1
	addl	$24,d1
	jmp	copy_nodes

found_bit3:
	shrl	$16,d0
	movzbl	first_one_bit_table(,d0,1),d1
	addl	$16,d1
	jmp	copy_nodes

found_bit2:
	shrl	$8,a0
	movzbl	first_one_bit_table(,a0,1),d1
	addl	$8,d1
	jmp	copy_nodes

found_bit1:	
	movzbl	first_one_bit_table(,d0,1),d1
#else
	bsf	a3,d1
#endif

copy_nodes:
	movl	(a2,d1,4),d0
#ifdef NO_BIT_INSTRUCTIONS
	andl	bit_clear_table(,d1,4),a3
#else
	btr	d1,a3
#endif
	leal	4(a2,d1,4),a0
	dec	d0

	test	$2,d0
	je	begin_update_list_2

	movl	-10(d0),d1
	subl	$2,d0

	test	$1,d1
	je	end_list_2
find_descriptor_2:
	andl	$-4,d1
	movl	(d1),d1
	test	$1,d1
	jne	find_descriptor_2

end_list_2:
	movl	d1,a1
	movzwl	-2(d1),d1
	cmpl	$256,d1
	jb	no_record_arguments

	movzwl	-2+2(a1),a1
	subl	$2,a1
	jae	copy_record_arguments_aa

	subl	$256+3,d1

copy_record_arguments_all_b:
	movl	d1,compact_sp_offset_1(sp)

	movl	heap_vector_compact_sp_offset(sp),d1

update_up_list_1r:
	movl	d0,a1
	addl	neg_heap_p3_compact_sp_offset(sp),d0

#ifdef NO_BIT_INSTRUCTIONS
	pushl	a0
	movl	d0,a0

	shrl	$7,d0
	andl	$31*4,a0

	movl	bit_set_table(,a0,1),a0
	movl	(d1,d0,4),d0

	andl	a0,d0

	popl	a0
	je	copy_argument_part_1r
#else
	shrl	$2,d0
	bt	d0,(d1)
	jnc	copy_argument_part_1r
#endif
	movl	(a1),d0
	movl	a4,(a1)
	subl	$3,d0
	jmp	update_up_list_1r

copy_argument_part_1r:
	movl	(a1),d0
	movl	a4,(a1)
	movl	d0,(a4)
	addl	$4,a4

	movl	neg_heap_p3_compact_sp_offset(sp),d0
	addl	a0,d0
	shr	$2,d0
	
	mov	d0,d1
	andl	$31,d1
	cmp	$1,d1
	jae	bit_in_this_word

	movl	vector_counter_compact_sp_offset(sp),d0
	movl	vector_p_compact_sp_offset(sp),a1
	dec	d0
	movl	(a1),a3
	addl	$4,a1

	movl	neg_heap_vector_plus_4_compact_sp_offset(sp),a2
	addl	a1,a2
	shl	$5,a2
	addl	heap_p3_compact_sp_offset(sp),a2

	movl	a1,vector_p_compact_sp_offset(sp)
	movl	d0,vector_counter_compact_sp_offset(sp)

bit_in_this_word:
#ifdef NO_BIT_INSTRUCTIONS
	andl	bit_clear_table(,d1,4),a3
#else
	btr	d1,a3
#endif

	movl	compact_sp_offset_1(sp),d1

copy_b_record_argument_part_arguments:
	movl	(a0),d0
	addl	$4,a0
	movl	d0,(a4)
	addl	$4,a4
	subl	$1,d1
	jnc	copy_b_record_argument_part_arguments

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

copy_record_arguments_aa:
	subl	$256+2,d1
	subl	a1,d1
	
	movl	d1,compact_sp_offset_1(sp)
	mov	a1,compact_sp_offset_2(sp)

update_up_list_2r:
	movl	d0,a1
	movl	(a1),d0
	movl	$3,d1
	andl	d0,d1
	subl	$3,d1
	jne	copy_argument_part_2r

	movl	a4,(a1)
	subl	$3,d0
	jmp	update_up_list_2r

copy_argument_part_2r:
	movl	a4,(a1)
	cmpl	a0,d0
	jb	copy_record_argument_2

	cmpl	end_heap_p3_compact_sp_offset(sp),d0
	jae	copy_record_argument_2

	movl	d0,a1
	movl	(a1),d0
	lea	1(a4),d1
	movl	d1,(a1)
copy_record_argument_2:
	movl	d0,(a4)
	addl	$4,a4

	movl	compact_sp_offset_2(sp),d1
	subl	$1,d1
	jc	no_pointers_in_record

copy_record_pointers:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jb	copy_record_pointers_2

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jae	copy_record_pointers_2

	movl	(a1),d0
	inc	a4
	movl	a4,(a1)
	dec	a4
	movl	d0,a1
copy_record_pointers_2:
	movl	a1,(a4)
	addl	$4,a4
	subl	$1,d1
	jnc	copy_record_pointers

no_pointers_in_record:
	movl	compact_sp_offset_1(sp),d1
	
	subl	$1,d1
	jc	no_non_pointers_in_record

copy_non_pointers_in_record:
	movl	(a0),d0
	addl	$4,a0
	movl	d0,(a4)
	addl	$4,a4
	subl	$1,d1
	jnc	copy_non_pointers_in_record

no_non_pointers_in_record:
#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

no_record_arguments:
	subl	$3,d1
update_up_list_2:
	movl	d0,a1
	movl	(d0),d0
	inc	d0
	movl	a4,(a1)
	testb	$3,d0b
	jne	copy_argument_part_2

	subl	$4,d0
	jmp	update_up_list_2

copy_argument_part_2:
	dec	d0
	cmpl	a0,d0
	jc	copy_arguments_1

	cmpl	end_heap_p3_compact_sp_offset(sp),d0
	jnc	copy_arguments_1

	movl	d0,a1
	movl	(d0),d0
	inc	a4
	movl	a4,(a1)
	dec	a4
copy_arguments_1:
	movl	d0,(a4)
	addl	$4,a4

copy_argument_part_arguments:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	copy_arguments_2

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	copy_arguments_2

	movl	(a1),d0
	inc	a4
	movl	a4,(a1)
	dec	a4
	movl	d0,a1
copy_arguments_2:
	movl	a1,(a4)
	addl	$4,a4
	subl	$1,d1
	jnc	copy_argument_part_arguments

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

update_list_2_:
	dec	d0
update_list_2:
	movl	a4,(a1)
begin_update_list_2:
	movl	d0,a1
	movl	(d0),d0
update_list__2:
	test	$1,d0
	jz	end_update_list_2
	test	$2,d0
	jz	update_list_2_
	lea	-3(d0),a1
	movl	-3(d0),d0
	jmp	update_list__2

end_update_list_2:
	movl	a4,(a1)

	movl	d0,(a4)
	addl	$4,a4

	testb	$2,d0b
	je	move_lazy_node

	movzwl	-2(d0),d1
	testl	d1,d1
	je	move_hnf_0

	cmp	$256,d1
	jae	move_record

	subl	$2,d1
	jc	move_hnf_1
	je	move_hnf_2

move_hnf_3:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_hnf_3_1

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_hnf_3_1

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_hnf_3_1:
	movl	a1,(a4)
	
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_hnf_3_2

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_hnf_3_2

	lea	4+2+1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_hnf_3_2:
	movl	a1,4(a4)
	addl	$8,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_hnf_2:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_hnf_2_1

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_hnf_2_1

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_hnf_2_1:
	movl	a1,(a4)
	
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_hnf_2_2

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_hnf_2_2

	lea	4+1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_hnf_2_2:
	movl	a1,4(a4)
	addl	$8,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_hnf_1:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_hnf_1_

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_hnf_1_

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_hnf_1_:
	movl	a1,(a4)
	addl	$4,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_record:
	subl	$258,d1
	jb	move_record_1
	je	move_record_2

move_record_3:
	movzwl	-2+2(d0),d1
	subl	$1,d1
	ja	move_hnf_3

	movl	(a0),a1
	lea	4(a0),a0
	jb	move_record_3_1b

move_record_3_1a:
	cmpl	a0,a1
	jb	move_record_3_1b

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jae	move_record_3_1b

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_record_3_1b:
	movl	a1,(a4)
	addl	$4,a4

	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jb	move_record_3_2

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jae	move_record_3_2

	movl	neg_heap_p3_compact_sp_offset(sp),d0
#ifdef NO_BIT_INSTRUCTIONS
	movl	a2,compact_sp_offset_1(sp)
#endif
	addl	a1,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	heap_vector_compact_sp_offset(sp),d1
	addl	$4,d0
	movl	d0,a2
	andl	$31*4,a2
	shrl	$7,d0
	movl	bit_set_table(a2),a2
	testl	(d1,d0,4),a2
	je	not_linked_record_argument_part_3_b
#else
	shr	$2,d0
	inc	d0

	movl	heap_vector_compact_sp_offset(sp),d1
	bts	d0,(d1)
	jnc	not_linked_record_argument_part_3_b
#endif

	movl	neg_heap_p3_compact_sp_offset(sp),d0
	addl	a4,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,a2
	shrl	$7,d0
	movl	bit_set_table(a2),a2
	orl	a2,(d1,d0,4)
	movl	compact_sp_offset_1(sp),a2
#else
	shr	$2,d0
	bts	d0,(d1)
#endif
	jmp	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
#ifdef NO_BIT_INSTRUCTIONS
	orl	a2,(d1,d0,4)
#endif
	movl	neg_heap_p3_compact_sp_offset(sp),d0
	addl	a4,d0

#ifdef NO_BIT_INSTRUCTIONS
	movl	d0,a2
	andl	$31*4,a2
	shrl	$7,d0
	movl	bit_clear_table(a2),a2
	andl	a2,(d1,d0,4)
	movl	compact_sp_offset_1(sp),a2
#else
	shr	$2,d0
	btr	d0,(d1)
#endif

linked_record_argument_part_3_b:
	movl	(a1),d1
	lea	2+1(a4),d0
	movl	d0,(a1)
	movl	d1,a1
move_record_3_2:
	movl	a1,(a4)
	addl	$4,a4

	movl	neg_heap_p3_compact_sp_offset(sp),d1
	addl	a0,d1
	shr	$2,d1
	dec	d1
	andl	$31,d1
	cmp	$2,d1
	jb	bit_in_next_word
	
#ifdef NO_BIT_INSTRUCTIONS
	andl	bit_clear_table(,d1,4),a3
#else
	btr	d1,a3
#endif

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long
	
bit_in_next_word:
	movl	vector_counter_compact_sp_offset(sp),d0
	movl	vector_p_compact_sp_offset(sp),a0
	dec	d0
	movl	(a0),a3
	addl	$4,a0

#ifdef NO_BIT_INSTRUCTIONS
	andl	bit_clear_table(,d1,4),a3
#else
	btr	d1,a3
#endif
	testl	a3,a3
	je	skip_zeros
	jmp	end_skip_zeros

move_record_2:
	cmpw	$1,-2+2(d0)
	ja	move_hnf_2
	jb	move_real_or_file

move_record_2_ab:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jb	move_record_2_1

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jae	move_record_2_1

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_record_2_1:
	movl	a1,(a4)
	movl	(a0),d1
	addl	$4,a0
	movl	d1,4(a4)
	addl	$8,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_record_1:
	movzwl	-2+2(d0),d1
	test	d1,d1
	jne	move_hnf_1
	jmp	move_int_bool_or_char

move_real_or_file:
	movl	(a0),d0
	addl	$4,a0
	movl	d0,(a4)
	addl	$4,a4
move_int_bool_or_char:
	movl	(a0),d0
	addl	$4,a0
	movl	d0,(a4)
	addl	$4,a4
copy_normal_hnf_0:
#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_hnf_0:
	cmpl	$INT+2,d0
	jb	move_real_file_string_or_array
	cmpl	$CHAR+2,d0
	jbe	move_int_bool_or_char

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_real_file_string_or_array:
	cmpl	$__STRING__+2,d0
	ja	move_real_or_file
	jne	move_array

	movl	(a0),d0
	addl	$3,d0
	shr	$2,d0

cp_s_arg_lp3:
	movl	(a0),d1
	addl	$4,a0
	movl	d1,(a4)
	addl	$4,a4
	subl	$1,d0
	jnc	cp_s_arg_lp3

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_array:
#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_end_array_bit
#else
	bsf	a3,d1
	jne	end_array_bit
#endif
	movl	a0,compact_sp_offset_1(sp)

	movl	vector_counter_compact_sp_offset(sp),d0
	movl	vector_p_compact_sp_offset(sp),a0

skip_zeros_a:
	subl	$1,d0
	movl	(a0),a3
	addl	$4,a0
	testl	a3,a3
	je	skip_zeros_a

	movl	neg_heap_vector_plus_4_compact_sp_offset(sp),a2
	addl	a0,a2
	movl	d0,vector_counter_compact_sp_offset(sp)

	shl	$5,a2
	movl	a0,vector_p_compact_sp_offset(sp)

	addl	heap_p3_compact_sp_offset(sp),a2

	movl	compact_sp_offset_1(sp),a0

#ifdef NO_BIT_INSTRUCTIONS
bsf_and_end_array_bit:
	movl	a3,d0
	movl	a3,a1
	andl	$0xff,d0
	jne	a_found_bit1
	andl	$0xff00,a1
	jne	a_found_bit2
	movl	a3,d0
	movl	a3,a1
	andl	$0xff0000,d0
	jne	a_found_bit3
	shrl	$24,a1
	movzbl	first_one_bit_table(,a1,1),d1
	addl	$24,d1
	jmp	end_array_bit
a_found_bit3:
	shrl	$16,d0
	movzbl	first_one_bit_table(,d0,1),d1
	addl	$16,d1
	jmp	end_array_bit
a_found_bit2:
	shrl	$8,a1
	movzbl	first_one_bit_table(,a1,1),d1
	addl	$8,d1
	jmp	end_array_bit
a_found_bit1:
	movzbl	first_one_bit_table(,d0,1),d1

#else
	bsf	a3,d1
#endif

end_array_bit:
#ifdef NO_BIT_INSTRUCTIONS
	andl	bit_clear_table(,d1,4),a3
#else
	btr	d1,a3
#endif
	leal	(a2,d1,4),d1

	cmpl	d1,a0
	jne	move_a_array

move_b_array:
	movl	(a0),a1
	movl	a1,(a4)
	movl	4(a0),d1
	addl	$4,a0
	movzwl	-2(d1),d0
	addl	$4,a4
	test	d0,d0
	je	move_strict_basic_array

	subl	$256,d0
	imull	d0,a1
	movl	a1,d0
	jmp	cp_s_arg_lp3

move_strict_basic_array:
	movl	a1,d0
	cmpl	$INT+2,d1
	je	cp_s_arg_lp3

	cmpl	$BOOL+2,d1
	je	move_bool_array

	addl	d0,d0
	jmp	cp_s_arg_lp3

move_bool_array:
	addl	$3,d0
	shr	$2,d0
	jmp	cp_s_arg_lp3

move_a_array:
	movl	d1,a1
	subl	a0,d1
	shr	$2,d1

	pushl	a3

	subl	$1,d1
	jb	end_array

	movl	(a0),a3
	movl	-4(a1),d0
	movl	a3,-4(a1)
	movl	d0,(a4)
	movl	(a1),d0
	movl	4(a0),a3
	addl	$8,a0
	movl	a3,(a1)
	movl	d0,4(a4)
	addl	$8,a4
	test	d0,d0
	je	st_move_array_lp

	movzwl	-2+2(d0),a3
	movzwl	-2(d0),d0
	subl	$256,d0
	cmpl	a3,d0
	je	st_move_array_lp

move_array_ab:
	pushl	a0

	movl	-8(a4),a1
	movl	a3,d1
	imull	d0,a1
	shl	$2,a1

	subl	d1,d0
	addl	a0,a1
	call	reorder

	popl	a0
	subl	$1,d1
	subl	$1,d0

	pushl	d1
	pushl	d0
	pushl	-8(a4)
	jmp	st_move_array_lp_ab

move_array_ab_lp1:
	movl	8(sp),d0
move_array_ab_a_elements:
	movl	(a0),d1
	addl	$4,a0
	cmpl	a0,d1
	jb	move_array_element_ab

	cmpl	end_heap_p3_compact_sp_offset+16(sp),d1
	jnc	move_array_element_ab

	movl	d1,a1
	movl	(a1),d1
	inc	a4
	movl	a4,(a1)
	dec	a4
move_array_element_ab:
	movl	d1,(a4)
	addl	$4,a4
	subl	$1,d0
	jnc	move_array_ab_a_elements

	movl	4(sp),d0
move_array_ab_b_elements:
	movl	(a0),d1
	addl	$4,a0
	movl	d1,(a4)
	addl	$4,a4
	subl	$1,d0
	jnc	move_array_ab_b_elements

st_move_array_lp_ab:
	subl	$1,(sp)
	jnc	move_array_ab_lp1

	addl	$12,sp
	jmp	end_array	

move_array_lp1:
	movl	(a0),d0
	addl	$4,a0
	addl	$4,a4
	cmpl	a0,d0
	jb	move_array_element

	cmpl	end_heap_p3_compact_sp_offset+4(sp),d0
	jnc	move_array_element

	movl	(d0),a3
	movl	d0,a1
	movl	a3,-4(a4)
	leal	-4+1(a4),d0
	movl	d0,(a1)

	subl	$1,d1
	jnc	move_array_lp1

	jmp	end_array

move_array_element:
	movl	d0,-4(a4)
st_move_array_lp:
	subl	$1,d1
	jnc	move_array_lp1

end_array:
	popl	a3

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_lazy_node:
	movl	d0,a1
	movl	-4(a1),d1
	test	d1,d1
	je	move_lazy_node_0

	subl	$1,d1
	jle	move_lazy_node_1

	cmpl	$256,d1
	jge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_lazy_node_arguments_

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_lazy_node_arguments_

	movl	(a1),d0
	movl	d0,(a4)
	lea	1(a4),d0
	addl	$4,a4
	movl	d0,(a1)
	subl	$1,d1
	jnc	move_lazy_node_arguments

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_lazy_node_arguments_:
	movl	a1,(a4)
	addl	$4,a4
	subl	$1,d1
	jnc	move_lazy_node_arguments
	
#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_lazy_node_1:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_lazy_node_1_

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_lazy_node_1_

	lea	1(a4),d0
	movl	(a1),d1
	movl	d0,(a1)
	movl	d1,a1
move_lazy_node_1_:
	movl	a1,(a4)
	addl	$8,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_lazy_node_0:
	addl	$8,a4

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_closure_with_unboxed_arguments:
	je	move_closure_with_unboxed_arguments_1
	addl	$1,d1
	movl	d1,d0
	andl	$255,d1
	shrl	$8,d0
	subl	d0,d1
	je	move_non_pointers_of_closure

	movl	d0,compact_sp_offset_1(sp)

move_closure_with_unboxed_arguments_lp:
	movl	(a0),a1
	addl	$4,a0
	cmpl	a0,a1
	jc	move_closure_with_unboxed_arguments_

	cmpl	end_heap_p3_compact_sp_offset(sp),a1
	jnc	move_closure_with_unboxed_arguments_

	movl	(a1),d0
	movl	d0,(a4)
	lea	1(a4),d0
	addl	$4,a4
	movl	d0,(a1)
	subl	$1,d1
	jne	move_closure_with_unboxed_arguments_lp

	movl	compact_sp_offset_1(sp),d0
	jmp	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_:
	movl	a1,(a4)
	addl	$4,a4
	subl	$1,d1
	jne	move_closure_with_unboxed_arguments_lp

	movl	compact_sp_offset_1(sp),d0

move_non_pointers_of_closure:
	movl	(a0),d1
	addl	$4,a0
	movl	d1,(a4)
	addl	$4,a4
	subl	$1,d0
	jne	move_non_pointers_of_closure

#ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
#else
	bsf	a3,d1
	jne	copy_nodes
#endif
	jmp	find_non_zero_long

move_closure_with_unboxed_arguments_1:
	movl	(a0),d0
	movl	d0,(a4)
	addl	$8,a4
# ifdef NO_BIT_INSTRUCTIONS
	test	a3,a3
	jne	bsf_and_copy_nodes
# else
	bsf	a3,d1
	jne	copy_nodes
# endif
	jmp	find_non_zero_long	

end_copy:

#ifdef FINALIZERS
	movl	finalizer_list,a0

restore_finalizer_descriptors:
	cmpl	$__Nil-4,a0
	je	end_restore_finalizer_descriptors

	movl	$e____system__kFinalizer+2,(a0)
	movl	4(a0),a0
	jmp	restore_finalizer_descriptors

end_restore_finalizer_descriptors:
#endif

	movl	a4,a2
	movl	a4_compact_sp_offset(sp),a4
	lea	40(sp),sp
