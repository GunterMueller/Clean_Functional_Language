
COMPACT_MARK_WITH_STACK = 1

# mark used nodes and pointers in argument parts and link backward pointers

	adrp	x2,heap_size_65
	ldr	x2,[x2,#:lo12:heap_size_65]
# heap_size_64_65 in x2
	lsl	x2,x2,#6

	adrp	x16,heap_p3
	ldr	x11,[x16,#:lo12:heap_p3]
# heap_p3 in x11
	adrp	x12,INT+2
	add	x12,x12,#:lo12:INT+2
	adrp	x13,CHAR+2
	add	x13,x13,#:lo12:CHAR+2

	adrp	x14,small_integers
	add	x14,x14,#:lo12:small_integers
	adrp	x15,static_characters
	add	x15,x15,#:lo12:static_characters
	adrp	x17,__ARRAY__+2
	add	x17,x17,#:lo12:__ARRAY__+2

.if COMPACT_MARK_WITH_STACK
	mov	x7,#-16000
	add	x7,x28,x7
.endif
	adrp	x4,caf_list
	ldr	x4,[x4,#:lo12:caf_list]
.if COMPACT_MARK_WITH_STACK
	adrp	x16,end_stack
	str	x7,[x16,#:lo12:end_stack]
# end_stack in x0
	mov	x0,x7
.endif

	cbz	x4,end_mark_cafs

mark_cafs_lp:
	ldr	x16,[x4,#-8]
	str	x16,[x28,#-8]!
	add	x7,x4,#8
	ldr	x4,[x4]
	add	x8,x7,x4,lsl #3
	mov	x5,x8 // end_vector

	str	x30,[x28,#-8]!
	bl	rmark_stack_nodes

	ldr	x4,[x28],#8
	cbnz	x4,mark_cafs_lp

end_mark_cafs:
	adrp	x7,stack_p
	ldr	x7,[x7,#:lo12:stack_p]

	adrp	x16,stack_top
	ldr	x8,[x16,#:lo12:stack_top]
	mov	x5,x8 // end_vector

	str	x30,[x28,#-8]!
	bl	rmark_stack_nodes

.ifdef MEASURE_GC
	bl	add_mark_compact_garbage_collect_time
.endif

	b	compact_heap

	.ltorg

.if COMPACT_MARK_WITH_STACK
	.include "arm64compact_rmark.s"
	.include "arm64compact_rmarkr.s"
.else
	.include "arm64compact_mark.s"
.endif

# compact the heap

compact_heap:

.ifdef FINALIZERS
	adrp	x8,finalizer_list
	add	x8,x8,#:lo12:finalizer_list
	adrp	x9,free_finalizer_list
	add	x9,x9,#:lo12:free_finalizer_list

	ldr	x10,[x8]
determine_free_finalizers_after_compact1:
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x10,x16
	beq	end_finalizers_after_compact1

	adrp	x4,heap_p3
	ldr	x4,[x4,#:lo12:heap_p3]
	sub	x4,x10,x4
	lsr	x3,x4,#8
	ubfx	x7,x4,#3,#5
	mov	x16,#1
	lsl	x7,x16,x7

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	beq	finalizer_not_used_after_compact1

	ldr	x4,[x10]
	mov	x7,x10
	b	finalizer_find_descriptor

finalizer_find_descriptor_lp:
	and	x4,x4,#-4
	mov	x7,x4
	ldr	x4,[x4]
finalizer_find_descriptor:
	tbnz	x4,#0,finalizer_find_descriptor_lp

	adrp	x16,e____system__kFinalizerGCTemp+2
	add	x16,x16,#:lo12:e____system__kFinalizerGCTemp+2
	str	x16,[x7]

	cmp	x10,x8
	bhi	finalizer_no_reverse

	ldr	x4,[x10]
	add	x7,x8,#1
	str	x7,[x10]
	str	x4,[x8]

finalizer_no_reverse:
	add	x8,x10,#8
	ldr	x10,[x10,#8]
	b	determine_free_finalizers_after_compact1

finalizer_not_used_after_compact1:
	adrp	x16,e____system__kFinalizerGCTemp+2
	add	x16,x16,#:lo12:e____system__kFinalizerGCTemp+2
	str	x16,[x10]

	str	x10,[x9]
	add	x9,x10,#8

	ldr	x10,[x10,#8]
	str	x10,[x8]

	b	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	str	x10,[x9]	

	adrp	x8,finalizer_list
	ldr	x8,[x8,#:lo12:finalizer_list]
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x8,x16
	beq	finalizer_list_empty
	tst	x8,#3
	bne	finalizer_list_already_reversed
	ldr	x4,[x8]
	adrp	x16,finalizer_list+1
	add	x16,x16,#:lo12:finalizer_list+1
	str	x16,[x8]
	adrp	x16,finalizer_list
	str	x4,[x16,#:lo12:finalizer_list]
finalizer_list_already_reversed:
finalizer_list_empty:

	adrp	x7,free_finalizer_list
	add	x7,x7,#:lo12:free_finalizer_list
	ldr	x8,[x7]
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x8,x16
	beq	free_finalizer_list_empty
	adrp	x8,free_finalizer_list+4
	add	x8,x8,#:lo12:free_finalizer_list+4
	mov	x5,x8 // end_vector

	str	x30,[x28,#-8]!
	bl	rmark_stack_nodes

free_finalizer_list_empty:
.endif

	adrp	x4,heap_size_65
	ldr	x4,[x4,#:lo12:heap_size_65]
	lsl	x3,x4,#6

	adrp	x16,heap_p3
	ldr	x16,[x16,#:lo12:heap_p3]
	add	x3,x3,x16

	adrp	x16,end_heap_p3
	str	x3,[x16,#:lo12:end_heap_p3]
# end_heap_p3 in x0
 	mov	x0,x3

	add	x4,x4,#3
	lsr	x4,x4,#2
# vector_counter in x2
	mov	x2,x4

	adrp	x8,heap_vector
	ldr	x8,[x8,#:lo12:heap_vector]
# vector_p in x1
	mov	x1,x8
# heap_vector in x14
	mov	x14,x8
# heap_vector_plus_4 in x15
	add	x15,x8,#4
	adrp	x11,heap_p3
	ldr	x11,[x11,#:lo12:heap_p3]
# heap_p3 in x11
	adrp	x29,__STRING__+2
	add	x29,x29,#:lo12:__STRING__+2
# __STRING__+2 in x29
	mov	x7,#0
	mov	x27,x11
	b	skip_zeros

find_non_zero_long:
skip_zeros:
	subs	x2,x2,#1
	bcc	end_copy
	ldr	w7,[x1],#4
	cbz	x7,skip_zeros

end_skip_zeros:
	sub	x10,x1,x15 // heap_vector_plus_4
	add	x10,x11,x10,lsl #6 // heap_p3

bsf_and_copy_nodes:
	neg	x16,x7
	and	x16,x16,x7
	clz	w3,w16
	eor	x3,x3,#31

copy_nodes:
	ldr	x4,[x10,x3,lsl #3]

	bic	x7,x7,x16

	add	x16,x10,#8
	add	x8,x16,x3,lsl #3



	tbnz	x4,#0,copy_node_reversed

node_not_reversed:
	b	node_not_reversed

copy_node_reversed:


	sub	x4,x4,#1

	tbz	x4,#1,begin_update_list_2

	ldr	x3,[x4,#-18]
	sub	x4,x4,#2

	tbz	x3,#0,end_list_2
find_descriptor_2:
	and	x3,x3,#-4
	ldr	x3,[x3]
	tbnz	x3,#0,find_descriptor_2

end_list_2:
	mov	x9,x3
	ldrh	w3,[x3,#-2]
	cmp	x3,#256
	blo	no_record_arguments

	ldrh	w9,[x9,#-2+2]
	subs	x9,x9,#2
	bhs	copy_record_arguments_aa

	sub	x3,x3,#256+3

copy_record_arguments_all_b:

update_up_list_1r:
	mov	x9,x4
	sub	x4,x4,x11

	ubfx	x17,x4,#3,#5
	lsr	x4,x4,#8
	mov	x16,#1
	lsl	x17,x16,x17
	ldr	w4,[x14,x4,lsl #2] // heap_vector
	tst	x4,x17
	beq	copy_argument_part_1r

	ldr	x4,[x9]
	str	x27,[x9]
	subs	x4,x4,#3
	b	update_up_list_1r

copy_argument_part_1r:
	ldr	x4,[x9]
	str	x27,[x9]
	str	x4,[x27],#8

	sub	x4,x8,x11
	lsr	x4,x4,#3

	and	x17,x4,#31
	cmp	x17,#1
	bhs	bit_in_this_word

	sub	x2,x2,#1
	ldr	w7,[x1],#4

	sub	x10,x1,x15 // heap_vector_plus_4
	add	x10,x11,x10,lsl #6

bit_in_this_word:
	mov	x16,#1
	lsl	x16,x16,x17
	bic	x7,x7,x16

copy_b_record_argument_part_arguments:
	ldr	x4,[x8],#8
	str	x4,[x27],#8
	subs	x3,x3,#1
	bcs	copy_b_record_argument_part_arguments

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

copy_record_arguments_aa:
	sub	x3,x3,x9
	sub	x3,x3,#256+2

update_up_list_2r:
	mov	x5,x4
	ldr	x4,[x4]
	and	x17,x4,#3
	cmp	x17,#3
	bne	copy_argument_part_2r

	str	x27,[x5]
	sub	x4,x4,#3
	b	update_up_list_2r

copy_argument_part_2r:
	str	x27,[x5]
	cmp	x4,x8
	blo	copy_record_argument_2
	cmp	x4,x0
	bhs	copy_record_argument_2
	mov	x5,x4
	ldr	x4,[x4]
	add	x17,x27,#1
	str	x17,[x5]
copy_record_argument_2:
	str	x4,[x27],#8

	subs	x9,x9,#1
	bcc	no_pointers_in_record

copy_record_pointers:
	ldr	x5,[x8],#8
	cmp	x5,x8
	blo	copy_record_pointers_2
	cmp	x5,x0
	bhs	copy_record_pointers_2
	ldr	x4,[x5]
	add	x17,x27,#1
	str	x17,[x5]
	mov	x5,x4
copy_record_pointers_2:
	str	x5,[x27],#8
	subs	x9,x9,#1
	bcs	copy_record_pointers

no_pointers_in_record:
	subs	x3,x3,#1
	bcc	no_non_pointers_in_record

copy_non_pointers_in_record:
	ldr	x4,[x8],#8
	str	x4,[x27],#8
	subs	x3,x3,#1
	bcs	copy_non_pointers_in_record

no_non_pointers_in_record:
	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

no_record_arguments:
	sub	x3,x3,#3
update_up_list_2:
	mov	x9,x4
	ldr	x4,[x4]
	add	x4,x4,#1
	str	x27,[x9]
	tst	x4,#3
	bne	copy_argument_part_2

	sub	x4,x4,#4
	b	update_up_list_2

copy_argument_part_2:
	sub	x4,x4,#1
	cmp	x4,x8
	bcc	copy_arguments_1
	cmp	x4,x0
	bcs	copy_arguments_1
	mov	x9,x4
	ldr	x4,[x4]
	add	x17,x27,#1
	str	x17,[x9]
copy_arguments_1:
	str	x4,[x27],#8

copy_argument_part_arguments:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	copy_arguments_2
	cmp	x9,x0
	bcs	copy_arguments_2
	ldr	x4,[x9]
	add	x17,x27,#1
	str	x17,[x9]
	mov	x9,x4
copy_arguments_2:
	str	x9,[x27],#8
	subs	x3,x3,#1
	bcs	copy_argument_part_arguments

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

update_list_2_:
	sub	x4,x4,#1
update_list_2:
	str	x27,[x9]
begin_update_list_2:
	mov	x9,x4
	ldr	x4,[x4]
update_list__2:
	tbz	x4,#0,end_update_list_2
	tbz	x4,#1,update_list_2_
	add	x9,x4,#-3
	ldr	x4,[x4,#-3]
	b	update_list__2

end_update_list_2:
	str	x27,[x9]

	str	x4,[x27],#8

	tbz	x4,#1,move_lazy_node

	ldrh	w3,[x4,#-2]
	tst	x3,x3
	beq	move_hnf_0

	cmp	x3,#256
	bhs	move_record

	subs	x3,x3,#2
	bcc	move_hnf_1
	beq	move_hnf_2

move_hnf_3:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_hnf_3_1
	cmp	x9,x0
	bcs	move_hnf_3_1
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_hnf_3_1:
	str	x9,[x27]

	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_hnf_3_2
	cmp	x9,x0
	bcs	move_hnf_3_2
	add	x4,x27,#8+2+1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_hnf_3_2:
	str	x9,[x27,#8]
	add	x27,x27,#16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_2:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_hnf_2_1
	cmp	x9,x0
	bcs	move_hnf_2_1
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_hnf_2_1:
	str	x9,[x27]

	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_hnf_2_2
	cmp	x9,x0
	bcs	move_hnf_2_2
	add	x4,x27,#8+1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_hnf_2_2:
	str	x9,[x27,#8]
	add	x27,x27,#16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_1:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_hnf_1_
	cmp	x9,x0
	bcs	move_hnf_1_
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_hnf_1_:
	str	x9,[x27],#8

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_record:
	subs	x3,x3,#258
	blo	move_record_1
	beq	move_record_2

move_record_3:
	ldrh	w3,[x4,#-2+2]
	subs	x3,x3,#1
	bhi	move_hnf_3

	ldr	x9,[x8],#8
	blo	move_record_3_1b

move_record_3_1a:
	cmp	x9,x8
	blo	move_record_3_1b
	cmp	x9,x0
	bhs	move_record_3_1b
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_record_3_1b:
	str	x9,[x27],#8

	ldr	x9,[x8],#8
	cmp	x9,x8
	blo	move_record_3_2
	cmp	x9,x0
	bhs	move_record_3_2

	sub	x4,x9,x11

	add	x4,x4,#8

	ubfx	x17,x4,#3,#5
	lsr	x4,x4,#8
	mov	x16,#1
	lsl	x17,x16,x17
	ldr	w16,[x14,x4,lsl #2] // heap_vector
	tst	x16,x17
	beq	not_linked_record_argument_part_3_b

	sub	x4,x27,x11

	ubfx	x17,x4,#3,#5
	lsr	x4,x4,#8
	mov	x16,#1
	lsl	x17,x16,x17
	ldr	w16,[x14,x4,lsl #2] // heap_vector
	orr	x16,x16,x17
	str	w16,[x14,x4,lsl #2] // heap_vector
	b	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	orr	x16,x16,x17
	str	w16,[x14,x4,lsl #2] // heap_vector

	sub	x4,x27,x11

	ubfx	x17,x4,#3,#5
	lsr	x4,x4,#8
	mov	x16,#1
	lsl	x17,x16,x17
	ldr	w16,[x14,x4,lsl #2] // heap_vector
	bic	x16,x16,x17
	str	w16,[x14,x4,lsl #2] // heap_vector

linked_record_argument_part_3_b:
	ldr	x3,[x9]
	add	x4,x27,#2+1
	str	x4,[x9]
	mov	x9,x3
move_record_3_2:
	str	x9,[x27],#8

	sub	x3,x8,x11
	lsr	x3,x3,#3
	sub	x3,x3,#1
	and	x3,x3,#31
	cmp	x3,#2
	blo	bit_in_next_word

	mov	x16,#1
	lsl	x16,x16,x3
	bic	x7,x7,x16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

bit_in_next_word:
	sub	x2,x2,#1
	ldr	w7,[x1],#4

	mov	x16,#1
	lsl	x16,x16,x3
	bic	x7,x7,x16

	cbz	x7,skip_zeros
	b	end_skip_zeros

move_record_2:
	ldrh	w16,[x4,#-2+2]
	cmp	x16,#1
	bhi	move_hnf_2
	blo	move_real_or_file

move_record_2_ab:
	ldr	x9,[x8],#8
	cmp	x9,x8
	blo	move_record_2_1
	cmp	x9,x0
	bhs	move_record_2_1
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_record_2_1:
	str	x9,[x27]
	ldr	x3,[x8],#8
	str	x3,[x27,#8]
	add	x27,x27,#16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_record_1:
	ldrh	w3,[x4,#-2+2]
	cbnz	x3,move_hnf_1
	b	move_real_int_bool_or_char

move_real_or_file:
	ldr	x4,[x8],#8
	str	x4,[x27],#8
move_real_int_bool_or_char:
	ldr	x4,[x8],#8
	str	x4,[x27],#8
copy_normal_hnf_0:
	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_0:
	cmp	x4,x29
	bls	move_string_or_array
	cmp	x4,x13 // CHAR+2
	bls	move_real_int_bool_or_char
.ifdef DLL
move_normal_hnf_0:
.endif

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_string_or_array:
	bne	move_array

	ldr	x4,[x8]
move_bool_array:
	add	x4,x4,#7
	lsr	x4,x4,#3

cp_s_arg_lp3:
	ldr	x3,[x8],#8
	str	x3,[x27],#8
	subs	x4,x4,#1
	bcs	cp_s_arg_lp3

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_array:
.ifdef DLL
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	cmp	x4,x16
	blo	move_normal_hnf_0
.endif
	cbnz	x7,bsf_and_end_array_bit

skip_zeros_a:
	ldr	w7,[x1],#4
	sub	x2,x2,#1
	cbz	x7,skip_zeros_a

	sub	x10,x1,x15 // heap_vector_plus_4
	add	x10,x11,x10,lsl #6

bsf_and_end_array_bit:
	neg	x16,x7
	and	x16,x16,x7
	clz	w3,w16
	eor	x3,x3,#31

end_array_bit:
	bic	x7,x7,x16

	add	x3,x10,x3,lsl #3

	cmp	x8,x3
	bne	move_a_array

move_b_array:
	ldr	x9,[x8]
	str	x9,[x27],#8
	ldr	x3,[x8,#8]!
	ldrh	w4,[x3,#-2]
	cbz	x4,move_strict_basic_array

	sub	x4,x4,#256
	mul	x4,x4,x9
	b	cp_s_arg_lp3

move_strict_basic_array:
	mov	x4,x9
	cmp	x3,x12 // INT+2
	bls	cp_s_arg_lp3

	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2
	cmp	x3,x16
	beq	move_bool_array

move_int32_or_real32_array:
	add	x4,x4,#1
	lsr	x4,x4,#1
	b	cp_s_arg_lp3

move_a_array:
	mov	x9,x3
	subs	x3,x3,x8
	lsr	x3,x3,#3

	subs	x3,x3,#1
	blo	end_array

	ldr	x5,[x8]
	ldr	x4,[x9,#-8]
	str	x5,[x9,#-8]
	str	x4,[x27]
	ldr	x4,[x9]
	ldr	x5,[x8,#8]
	add	x8,x8,#16
	str	x5,[x9]
	str	x4,[x27,#8]
	add	x27,x27,#16
	cbz	x4,st_move_array_lp

	ldrh	w5,[x4,#-2+2]
	ldrh	w4,[x4,#-2]
	sub	x4,x4,#256
	cmp	x4,x5
	beq	st_move_array_lp

move_array_ab:
	str	x8,[x28,#-8]!

	ldr	x9,[x27,#-16]
	mov	x3,x5
	mul	x9,x4,x9
	lsl	x9,x9,#3

	subs	x4,x4,x3
	add	x9,x9,x8

	mov	x6,x30
	bl	reorder
	mov	x30,x6

	ldr	x8,[x28],#8
	sub	x3,x3,#1
	sub	x4,x4,#1

	ldr	x6,[x27,#-16]
	mov	x16,x3
	mov	x17,x4
	b	st_move_array_lp_ab

move_array_ab_lp1:
	mov	x4,x16
move_array_ab_a_elements:
	ldr	x3,[x8],#8
	cmp	x3,x8
	blo	move_array_element_ab
	cmp	x3,x0
	bcs	move_array_element_ab
	mov	x9,x3
	ldr	x3,[x3]
	add	x5,x27,#1
	str	x5,[x9]
move_array_element_ab:
	str	x3,[x27],#8
	subs	x4,x4,#1
	bcs	move_array_ab_a_elements

	mov	x4,x17
move_array_ab_b_elements:
	ldr	x3,[x8],#8
	str	x3,[x27],#8
	subs	x4,x4,#1
	bcs	move_array_ab_b_elements

st_move_array_lp_ab:
	subs	x6,x6,#1
	bcs	move_array_ab_lp1

	b	end_array	

move_array_lp1:
	ldr	x4,[x8],#8
	add	x27,x27,#8
	cmp	x4,x8
	blo	move_array_element
	cmp	x4,x0
	bcs	move_array_element
	ldr	x5,[x4]
	mov	x9,x4
	str	x5,[x27,#-8]
	add	x4,x27,#-8+1
	str	x4,[x9]

	subs	x3,x3,#1
	bcs	move_array_lp1

	b	end_array

move_array_element:
	str	x4,[x27,#-8]
st_move_array_lp:
	subs	x3,x3,#1
	bcs	move_array_lp1

end_array:
	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node:
	mov	x9,x4
	ldr	w3,[x4,#-4]
	cbz	x3,move_lazy_node_0

	cmp	w3,#1
	ble	move_lazy_node_1

	cmp	x3,#257
	bge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_lazy_node_arguments_
	cmp	x9,x0
	bcs	move_lazy_node_arguments_
	ldr	x4,[x9]
	str	x4,[x27]
	add	x4,x27,#1
	add	x27,x27,#8
	str	x4,[x9]
	subs	x3,x3,#1
	bne	move_lazy_node_arguments

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_arguments_:
	str	x9,[x27],#8
	subs	x3,x3,#1
	bne	move_lazy_node_arguments

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_1:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_lazy_node_1_
	cmp	x9,x0
	bcs	move_lazy_node_1_
	add	x4,x27,#1
	ldr	x3,[x9]
	str	x4,[x9]
	mov	x9,x3
move_lazy_node_1_:
	str	x9,[x27],#16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_0:
	add	x27,x27,#16

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments:
	beq	move_closure_with_unboxed_arguments_1
	lsr	x4,x3,#8
	and	x3,x3,#255
	subs	x3,x3,x4
	beq	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_lp:
	ldr	x9,[x8],#8
	cmp	x9,x8
	bcc	move_closure_with_unboxed_arguments_
	cmp	x9,x0
	bcs	move_closure_with_unboxed_arguments_
	ldr	x5,[x9]
	str	x5,[x27]
	add	x5,x27,#1
	add	x27,x27,#8
	str	x5,[x9]
	subs	x3,x3,#1
	bne	move_closure_with_unboxed_arguments_lp

	b	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_:
	str	x9,[x27],#8
	subs	x3,x3,#1
	bne	move_closure_with_unboxed_arguments_lp

move_non_pointers_of_closure:
	ldr	x3,[x8],#8
	str	x3,[x27],#8
	subs	x4,x4,#1
	bne	move_non_pointers_of_closure

	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments_1:
	ldr	x4,[x8]
	str	x4,[x27],#16
	cbnz	x7,bsf_and_copy_nodes
	b	find_non_zero_long	

	.ltorg

end_copy:

.ifdef FINALIZERS
	adrp	x16,finalizer_list
	ldr	x8,[x16,:lo12:finalizer_list]

restore_finalizer_descriptors:
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x8,x16
	beq	end_restore_finalizer_descriptors

	adrp	x16,e____system__kFinalizer+2
	add	x16,x16,#:lo12:e____system__kFinalizer+2
	str	x16,[x8]
	ldr	x8,[x8,#8]
	b	restore_finalizer_descriptors

end_restore_finalizer_descriptors:
.endif
