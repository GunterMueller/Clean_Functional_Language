
COMPACT_MARK_WITH_STACK = 1
NO_BIT_INSTRUCTIONS = 1

@ mark used nodes and pointers in argument parts and link backward pointers

	lao	r7,heap_size_33,10
	ldo	r1,r7,heap_size_33,10
	lsl	r1,r1,#5
	lao	r7,heap_size_32_33,1
	sto	r1,r7,heap_size_32_33,1
@ heap_size_32_33 in r10
	mov	r10,r1

	lao	r7,heap_p3,11
	ldo	r12,r7,heap_p3,11
@ heap_p3 in r12

.if COMPACT_MARK_WITH_STACK
	add	r5,sp,#-8000
.endif
	lao	r7,caf_list,2
	ldo	r1,r7,caf_list,2
.if COMPACT_MARK_WITH_STACK
	lao	r7,end_stack,1
	sto	r5,r7,end_stack,1
@ end_stack in r8
	mov	r8,r5
.endif
	cmp	r1,#0
	beq	end_mark_cafs

mark_cafs_lp:
	ldr	r7,[r1,#-4]
	push	{r7}
.if COMPACT_MARK_WITH_STACK
	add	r5,r1,#4
	ldr	r1,[r1]
	add	r2,r5,r1,lsl #2
.else
	add	r4,r1,#4
	ldr	r1,[r1]
	add	r2,r4,r1,lsl #2
.endif
	lao	r7,end_vector,13
	sto	r2,r7,end_vector,13

	adr	r14,1+0f
	push	{r14}
.if COMPACT_MARK_WITH_STACK
	bl	rmark_stack_nodes
.else
	bl	mark_stack_nodes
.endif
0:
	pop	{r1}
	tst	r1,r1
	bne	mark_cafs_lp

end_mark_cafs:
.if COMPACT_MARK_WITH_STACK
	lao	r7,stack_p,6
	ldo	r5,r7,stack_p,6
.else
	lao	r7,stack_p,6
	ldo	r4,r7,stack_p,6
.endif

	lao	r7,stack_top,4
	ldo	r2,r7,stack_top,4
	lao	r7,end_vector,14
	sto	r2,r7,end_vector,14
	adr	r14,1+0f
	push	{r14}
.if COMPACT_MARK_WITH_STACK
	bl	rmark_stack_nodes
.else
	bl	mark_stack_nodes
.endif
0:
.ifdef MEASURE_GC
	adr	r14,1+0f
	push	{r14}
	bl	add_mark_compact_garbage_collect_time
0:
.endif

	b	compact_heap

.ifdef PIC
	lto	heap_size_33,10
	lto	heap_size_32_33,1
	lto	heap_p3,11
	lto	caf_list,2
 .if COMPACT_MARK_WITH_STACK
	lto	end_stack,1
 .endif
 	lto	end_vector,13
	lto	stack_p,6
	lto	stack_top,4
	lto	end_vector,14
.endif
	.ltorg

.if COMPACT_MARK_WITH_STACK
	.include "tcompact_rmark.s"
	.include "tcompact_rmarkr.s"
.else
	.include "tcompact_mark.s"
.endif

@ compact the heap

compact_heap:

.ifdef FINALIZERS
	lao	r2,finalizer_list,3
	lao	r3,free_finalizer_list,5
	otoa	r2,finalizer_list,3
	otoa	r3,free_finalizer_list,5

	ldr	r4,[r2]
determine_free_finalizers_after_compact1:
	laol	r7,__Nil-4,__Nil_o_m4,5
	otoa	r7,__Nil_o_m4,5
	cmp	r4,r7
	beq	end_finalizers_after_compact1

	lao	r7,heap_p3,12
	ldo	r1,r7,heap_p3,12
	sub	r1,r4,r1
	lsr	r0,r1,#7
	and	r1,r1,#31*4
	lsr	r5,r1,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	beq	finalizer_not_used_after_compact1

	ldr	r1,[r4]
	mov	r5,r4
	b	finalizer_find_descriptor

finalizer_find_descriptor_lp:
	and	r1,r1,#-4
	mov	r5,r1
	ldr	r1,[r1]
finalizer_find_descriptor:
	tst	r1,#1
	bne	finalizer_find_descriptor_lp

	laol	r7,e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,0
	sto	r7,r5,e____system__kFinalizerGCTemp_o_2,0

	cmp	r4,r2
	bhi	finalizer_no_reverse

	ldr	r1,[r4]
	str	r2,[r4]
	str	r1,[r2]

finalizer_no_reverse:
	add	r2,r4,#4
	ldr	r4,[r4,#4]
	b	determine_free_finalizers_after_compact1

finalizer_not_used_after_compact1:
	laol	r7,e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,1
	sto	r7,r4,e____system__kFinalizerGCTemp_o_2,1

	str	r4,[r3]
	add	r3,r4,#4

	ldr	r4,[r4,#4]
	str	r4,[r2]

	b	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	str	r4,[r3]	

	lao	r7,finalizer_list,4
	ldo	r2,r7,finalizer_list,4
	laol	r7,__Nil-4,__Nil_o_m4,6
	otoa	r7,__Nil_o_m4,6
	cmp	r2,r7
	beq	finalizer_list_empty
	tst	r2,#3
	bne	finalizer_list_already_reversed
	ldr	r1,[r2]
	laol	r7,finalizer_list+1,finalizer_list_o_1,0
	otoa	r7,finalizer_list_o_1,0
	str	r7,[r2]
	lao	r7,finalizer_list,5
	sto	r1,r7,finalizer_list,5
finalizer_list_already_reversed:
finalizer_list_empty:

 .if COMPACT_MARK_WITH_STACK
	lao	r5,free_finalizer_list,6
	otoa	r5,free_finalizer_list,6
	ldr	r2,[r5]
 .else
	lao	r4,free_finalizer_list,6
	otoa	r4,free_finalizer_list,6
	ldr	r2,[r4]
 .endif
	laol	r7,__Nil-4,__Nil_o_m4,7
	otoa	r7,__Nil_o_m4,7
	cmp	r2,r7
	beq	free_finalizer_list_empty
	laol	r2,free_finalizer_list+4,free_finalizer_list_o_4,0
	otoa	r2,free_finalizer_list_o_4,0
	lao	r7,end_vector,15
	sto	r2,r7,end_vector,15
 .if COMPACT_MARK_WITH_STACK
	adr	r14,1+0f
	push	{r14}
	bl	rmark_stack_nodes
0:
 .else
	adr	r14,1+0f
	push	{r14}
	bl	mark_stack_nodes
0:
 .endif
free_finalizer_list_empty:
.endif

	lao	r7,heap_size_33,11
	ldo	r1,r7,heap_size_33,11
	mov	r0,r1
	lsl	r0,r0,#5

	lao	r7,heap_p3,13
	ldo	r7,r7,heap_p3,13
	add	r0,r0,r7

	lao	r7,end_heap_p3,0
	sto	r0,r7,end_heap_p3,0
@ end_heap_p3 in r8
 	mov	r8,r0

	add	r1,r1,#3
	lsr	r1,r1,#2
@ vector_counter in r10
	mov	r10,r1

	lao	r7,heap_vector,9
	ldo	r2,r7,heap_vector,9
@ vector_p in r9
	mov	r9,r2

	mov	r7,#-4
	rsb	r0,r2,r7
	lao	r7,neg_heap_vector_plus_4,0
	sto	r0,r7,neg_heap_vector_plus_4,0

	lao	r7,heap_p3,14
	ldo	r6,r7,heap_p3,14
	mov	r5,#0
@ heap_p3 in r12
	mov	r12,r6
	b	skip_zeros

@ d0,a0,a2: free
find_non_zero_long:
skip_zeros:
	subs	r10,r10,#1
	bcc	end_copy
	ldr	r5,[r9],#4
	cmp	r5,#0
	beq	skip_zeros
@ a2: free
end_skip_zeros:
	lao	r7,neg_heap_vector_plus_4,1
	ldo	r4,r7,neg_heap_vector_plus_4,1
	add	r4,r4,r9

	add	r4,r12,r4,lsl #5

bsf_and_copy_nodes:
	neg	r7,r5
	and	r7,r7,r5
	clz	r0,r7
	rsb	r0,r0,#31

copy_nodes:
	ldr	r1,[r4,r0,lsl #2]

	bic	r5,r5,r7

	add	r7,r4,#4
	add	r2,r7,r0,lsl #2

	tst	r1,#3
	beq	begin_update_list_2

	ldr	r0,[r1,#-3-8]
	sub	r1,r1,#3

	eor	r3,r0,#2
	tst	r3,#3
	beq	end_list_2
find_descriptor_2:
	and	r0,r0,#-4
	ldr	r0,[r0]
	eor	r3,r0,#2
	tst	r3,#3
	bne	find_descriptor_2

end_list_2:
	mov	r3,r0
	ldrh	r0,[r0,#-2]
	cmp	r0,#256
	blo	no_record_arguments

	ldrh	r3,[r3,#-2+2]
	subs	r3,r3,#2
	bhs	copy_record_arguments_aa

	sub	r0,r0,#256
	sub	r0,r0,#3

copy_record_arguments_all_b:
	push	{r0}
	lao	r7,heap_vector,10
	ldo	r0,r7,heap_vector,10

update_up_list_1r:
	mov	r3,r1
	sub	r1,r1,r12

	push	{r2}

	and	r2,r1,#31*4
	lsr	r1,r1,#7
	lsr	r2,r2,#2
	mov	r7,#1
	lsl	r2,r7,r2

	ldr	r1,[r0,r1,lsl #2]

	ands	r1,r1,r2

	pop	{r2}
	beq	copy_argument_part_1r

	ldr	r1,[r3]
	str	r6,[r3]
	subs	r1,r1,#3
	b	update_up_list_1r

copy_argument_part_1r:
	ldr	r1,[r3]
	str	r6,[r3]
	str	r1,[r6],#4

	sub	r1,r2,r12
	lsr	r1,r1,#2

	mov	r0,r1
	and	r0,r0,#31
	cmp	r0,#1
	bhs	bit_in_this_word

	sub	r10,r10,#1
	ldr	r5,[r9],#4

	lao	r7,neg_heap_vector_plus_4,2
	ldo	r4,r7,neg_heap_vector_plus_4,2
	add	r4,r4,r9
	add	r4,r12,r4,lsl #5

bit_in_this_word:
	mov	r7,#1
	lsl	r7,r7,r0
	bic	r5,r5,r7

	pop	{r0}

copy_b_record_argument_part_arguments:
	ldr	r1,[r2],#4
	str	r1,[r6],#4
	subs	r0,r0,#1
	bcs	copy_b_record_argument_part_arguments

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

copy_record_arguments_aa:
	sub	r0,r0,r3
	sub	r0,r0,#258

	push	{r0}
	push	{r3}

update_up_list_2r:
	mov	r3,r1
	ldr	r1,[r3]
	and	r0,r1,#3
	subs	r0,r0,#3
	bne	copy_argument_part_2r

	str	r6,[r3]
	subs	r1,r1,#3
	b	update_up_list_2r

copy_argument_part_2r:
	str	r6,[r3]
	cmp	r1,r2
	blo	copy_record_argument_2
	cmp	r1,r8
	bhs	copy_record_argument_2
	mov	r3,r1
	ldr	r1,[r3]
	str	r6,[r3]
copy_record_argument_2:
	str	r1,[r6],#4

	pop	{r0}
	subs	r0,r0,#1
	bcc	no_pointers_in_record

copy_record_pointers:
	ldr	r3,[r2],#4
	cmp	r3,r2
	blo	copy_record_pointers_2
	cmp	r3,r8
	bhs	copy_record_pointers_2
	ldr	r1,[r3]
	str	r6,[r3]
	mov	r3,r1
copy_record_pointers_2:
	str	r3,[r6],#4
	subs	r0,r0,#1
	bcs	copy_record_pointers

no_pointers_in_record:
	pop	{r0}

	subs	r0,r0,#1
	bcc	no_non_pointers_in_record

copy_non_pointers_in_record:
	ldr	r1,[r2],#4
	str	r1,[r6],#4
	subs	r0,r0,#1
	bcs	copy_non_pointers_in_record

no_non_pointers_in_record:
	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

no_record_arguments:
	subs	r0,r0,#3
update_up_list_2:
	mov	r3,r1
	ldr	r1,[r1]
	str	r6,[r3]
	add	r1,r1,#1
	tst	r1,#3
	bne	copy_argument_part_2

	sub	r1,r1,#4
	b	update_up_list_2

copy_argument_part_2:
	sub	r1,r1,#1
	cmp	r1,r2
	bcc	copy_arguments_1
	cmp	r1,r8
	bcs	copy_arguments_1
	mov	r3,r1
	ldr	r1,[r1]
	str	r6,[r3]
copy_arguments_1:
	str	r1,[r6],#4

copy_argument_part_arguments:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	copy_arguments_2
	cmp	r3,r8
	bcs	copy_arguments_2
	ldr	r1,[r3]
	str	r6,[r3]
	mov	r3,r1
copy_arguments_2:
	str	r3,[r6],#4
	subs	r0,r0,#1
	bcs	copy_argument_part_arguments

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

update_list_2:
	str	r6,[r3]
begin_update_list_2:
	mov	r3,r1
	ldr	r1,[r1]
update_list__2:
	ands	r0,r1,#3
	beq	update_list_2
	cmp	r0,#3
	bne	end_update_list_2
	add	r3,r1,#-3
	ldr	r1,[r1,#-3]
	b	update_list__2

end_update_list_2:
	str	r6,[r3]

	str	r1,[r6],#4

	tst	r1,#2
	beq	move_lazy_node

	ldrh	r0,[r1,#-2]
	tst	r0,r0
	beq	move_hnf_0

	cmp	r0,#256
	bhs	move_record

	subs	r0,r0,#2
	bcc	move_hnf_1
	beq	move_hnf_2

move_hnf_3:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_hnf_3_1
	cmp	r3,r8
	bcs	move_hnf_3_1
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_hnf_3_1:
	str	r3,[r6]

	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_hnf_3_2
	cmp	r3,r8
	bcs	move_hnf_3_2
	add	r1,r6,#4+2+1
	ldr	r0,[r3]
	str	r1,[r3]
	mov	r3,r0
move_hnf_3_2:
	str	r3,[r6,#4]
	add	r6,r6,#8

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_2:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_hnf_2_1
	cmp	r3,r8
	bcs	move_hnf_2_1
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_hnf_2_1:
	str	r3,[r6]

	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_hnf_2_2
	cmp	r3,r8
	bcs	move_hnf_2_2
	add	r1,r6,#4
	ldr	r0,[r3]
	str	r1,[r3]
	mov	r3,r0
move_hnf_2_2:
	str	r3,[r6,#4]
	add	r6,r6,#8

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_1:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_hnf_1_
	cmp	r3,r8
	bcs	move_hnf_1_
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_hnf_1_:
	str	r3,[r6],#4

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_record:
	subs	r0,r0,#258
	blo	move_record_1
	beq	move_record_2

move_record_3:
	ldrh	r0,[r1,#-2+2]
	subs	r0,r0,#1
	bhi	move_hnf_3

	ldr	r3,[r2],#4
	blo	move_record_3_1b

move_record_3_1a:
	cmp	r3,r2
	blo	move_record_3_1b
	cmp	r3,r8
	bhs	move_record_3_1b
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_record_3_1b:
	str	r3,[r6],#4

	ldr	r3,[r2],#4
	cmp	r3,r2
	blo	move_record_3_2
	cmp	r3,r8
	bhs	move_record_3_2

	push	{r4}
	sub	r1,r3,r12

	lao	r7,heap_vector,11
	ldo	r0,r7,heap_vector,11
	add	r1,r1,#4
	and	r4,r1,#31*4
	lsr	r1,r1,#7
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r0,r1,lsl #2]
	tst	r4,r7
	beq	not_linked_record_argument_part_3_b

	sub	r1,r6,r12

	and	r4,r1,#31*4
	lsr	r1,r1,#7
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r7,[r0,r1,lsl #2]
	orr	r7,r7,r4
	str	r7,[r0,r1,lsl #2]
	pop	{r4}
	b	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	ldr	r7,[r0,r1,lsl #2]
	orr	r7,r7,r4
	str	r7,[r0,r1,lsl #2]

	sub	r1,r6,r12

	and	r4,r1,#31*4
	lsr	r1,r1,#7

	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r0,r1,lsl #2]
	bic	r7,r7,r4
	str	r7,[r0,r1,lsl #2]
	pop	{r4}

linked_record_argument_part_3_b:
	ldr	r0,[r3]
	add	r1,r6,#2+1
	str	r1,[r3]
	mov	r3,r0
move_record_3_2:
	str	r3,[r6],#4

	sub	r0,r2,r12
	lsr	r0,r0,#2
	subs	r0,r0,#1
	and	r0,r0,#31
	cmp	r0,#2
	blo	bit_in_next_word

	mov	r7,#1
	lsl	r7,r7,r0
	bic	r5,r5,r7

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

bit_in_next_word:
	sub	r10,r10,#1
	ldr	r5,[r9],#4

	mov	r7,#1
	lsl	r7,r7,r0
	bic	r5,r5,r7

	cmp	r5,#0
	beq	skip_zeros
	b	end_skip_zeros

move_record_2:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#1
	bhi	move_hnf_2
	blo	move_real_or_file

move_record_2_ab:
	ldr	r3,[r2],#4
	cmp	r3,r2
	blo	move_record_2_1
	cmp	r3,r8
	bhs	move_record_2_1
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_record_2_1:
	str	r3,[r6]
	ldr	r0,[r2],#4
	str	r0,[r6,#4]
	add	r6,r6,#8

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_record_1:
	ldrh	r0,[r1,#-2+2]
	tst	r0,r0
	bne	move_hnf_1
	b	move_int_bool_or_char

move_real_or_file:
	ldr	r1,[r2],#4
	str	r1,[r6],#4
move_int_bool_or_char:
	ldr	r1,[r2],#4
	str	r1,[r6],#4
copy_normal_hnf_0:
	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_0:
	laol	r7,INT+2,INT_o_2,13
	otoa	r7,INT_o_2,13
	cmp	r1,r7
	blo	move_real_file_string_or_array
	laol	r7,CHAR+2,CHAR_o_2,8
	otoa	r7,CHAR_o_2,8
	cmp	r1,r7
	bls	move_int_bool_or_char
.ifdef DLL
move_normal_hnf_0:
.endif

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_real_file_string_or_array:
	laol	r7,__STRING__+2,__STRING___o_2,10
	otoa	r7,__STRING___o_2,10
	cmp	r1,r7
	bhi	move_real_or_file
	bne	move_array

	ldr	r1,[r2]
	add	r1,r1,#3
	lsr	r1,r1,#2

cp_s_arg_lp3:
	ldr	r0,[r2],#4
	str	r0,[r6],#4
	subs	r1,r1,#1
	bcs	cp_s_arg_lp3

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_array:
.ifdef DLL
	laol	r7,__ARRAY__+2,__ARRAY___o_2,2
	otoa	r7,__ARRAY___o_2,2
	cmp	r1,r7
	blo	move_normal_hnf_0
.endif
	cmp	r5,#0
	bne	bsf_and_end_array_bit

skip_zeros_a:
	ldr	r5,[r9],#4
	sub	r10,r10,#1
	cmp	r5,#0
	beq	skip_zeros_a

	lao	r7,neg_heap_vector_plus_4,3
	ldo	r4,r7,neg_heap_vector_plus_4,3
	add	r4,r4,r9

	add	r4,r12,r4,lsl #5

bsf_and_end_array_bit:
	neg	r7,r5
	and	r7,r7,r5
	clz	r0,r7
	rsb	r0,r0,#31

end_array_bit:
	bic	r5,r5,r7

	add	r0,r4,r0,lsl #2

	cmp	r2,r0
	bne	move_a_array

move_b_array:
	ldr	r3,[r2]
	str	r3,[r6]
	ldr	r0,[r2,#4]!
	ldrh	r1,[r0,#-2]
	add	r6,r6,#4
	tst	r1,r1
	beq	move_strict_basic_array

	subs	r1,r1,#256
	mul	r3,r1,r3
	mov	r1,r3
	b	cp_s_arg_lp3

move_strict_basic_array:
	mov	r1,r3
	laol	r7,INT+2,INT_o_2,14
	otoa	r7,INT_o_2,14
	cmp	r0,r7
	beq	cp_s_arg_lp3

	laol	r7,BOOL+2,BOOL_o_2,7
	otoa	r7,BOOL_o_2,7
	cmp	r0,r7
	beq	move_bool_array

	add	r1,r1,r1
	b	cp_s_arg_lp3

move_bool_array:
	add	r1,r1,#3
	lsr	r1,r1,#2
	b	cp_s_arg_lp3

move_a_array:
	mov	r3,r0
	subs	r0,r0,r2
	lsr	r0,r0,#2

	push	{r5}

	subs	r0,r0,#1
	blo	end_array

	ldr	r5,[r2]
	ldr	r1,[r3,#-4]
	str	r5,[r3,#-4]
	str	r1,[r6]
	ldr	r1,[r3]
	ldr	r5,[r2,#4]
	add	r2,r2,#8
	str	r5,[r3]
	str	r1,[r6,#4]
	add	r6,r6,#8
	tst	r1,r1
	beq	st_move_array_lp

	ldrh	r5,[r1,#-2+2]
	ldrh	r1,[r1,#-2]
	subs	r1,r1,#256
	cmp	r1,r5
	beq	st_move_array_lp

move_array_ab:
	push	{r2}

	ldr	r3,[r6,#-8]
	mov	r0,r5
	mul	r3,r1,r3
	lsl	r3,r3,#2

	subs	r1,r1,r0
	add	r3,r3,r2
	adr	r14,1+0f
	push	{r14}
	bl	reorder
0:
	pop	{r2}
	subs	r0,r0,#1
	subs	r1,r1,#1

	push	{r0}
	push	{r1}
	ldr	r7,[r6,#-8]
	push	{r7}
	b	st_move_array_lp_ab

move_array_ab_lp1:
	ldr	r1,[sp,#8]
move_array_ab_a_elements:
	ldr	r0,[r2],#4
	cmp	r0,r2
	blo	move_array_element_ab
	cmp	r0,r8
	bcs	move_array_element_ab
	mov	r3,r0
	ldr	r0,[r3]
	str	r6,[r3]
move_array_element_ab:
	str	r0,[r6],#4
	subs	r1,r1,#1
	bcs	move_array_ab_a_elements

	ldr	r1,[sp,#4]
move_array_ab_b_elements:
	ldr	r0,[r2],#4
	str	r0,[r6],#4
	subs	r1,r1,#1
	bcs	move_array_ab_b_elements

st_move_array_lp_ab:
	ldr	r7,[sp]
	subs	r7,r7,#1
	str	r7,[sp]
	bcs	move_array_ab_lp1

	add	sp,sp,#12
	b	end_array	

move_array_lp1:
	ldr	r1,[r2],#4
	add	r6,r6,#4
	cmp	r1,r2
	blo	move_array_element
	cmp	r1,r8
	bcs	move_array_element
	ldr	r5,[r1]
	mov	r3,r1
	str	r5,[r6,#-4]
	add	r1,r6,#-4
	str	r1,[r3]

	subs	r0,r0,#1
	bcs	move_array_lp1

	b	end_array

move_array_element:
	str	r1,[r6,#-4]
st_move_array_lp:
	subs	r0,r0,#1
	bcs	move_array_lp1

end_array:
	pop	{r5}

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node:
	mov	r3,r1
	ldr	r0,[r3,#-1-4]
	tst	r0,r0
	beq	move_lazy_node_0

	subs	r0,r0,#1
	ble	move_lazy_node_1

	cmp	r0,#256
	bge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_lazy_node_arguments_
	cmp	r3,r8
	bcs	move_lazy_node_arguments_
	ldr	r1,[r3]
	str	r1,[r6]
	str	r6,[r3]
	add	r6,r6,#4
	subs	r0,r0,#1
	bcs	move_lazy_node_arguments

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_arguments_:
	str	r3,[r6],#4
	subs	r0,r0,#1
	bcs	move_lazy_node_arguments

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_1:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_lazy_node_1_
	cmp	r3,r8
	bcs	move_lazy_node_1_
	ldr	r0,[r3]
	str	r6,[r3]
	mov	r3,r0
move_lazy_node_1_:
	str	r3,[r6]
	add	r6,r6,#8

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_0:
	add	r6,r6,#8

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments:
	beq	move_closure_with_unboxed_arguments_1
	add	r0,r0,#1
	mov	r1,r0
	and	r0,r0,#255
	lsr	r1,r1,#8
	subs	r0,r0,r1
	beq	move_non_pointers_of_closure

	push	{r1}

move_closure_with_unboxed_arguments_lp:
	ldr	r3,[r2],#4
	cmp	r3,r2
	bcc	move_closure_with_unboxed_arguments_
	cmp	r3,r8
	bcs	move_closure_with_unboxed_arguments_
	ldr	r1,[r3]
	str	r1,[r6]
	str	r6,[r3]
	add	r6,r6,#4
	subs	r0,r0,#1
	bne	move_closure_with_unboxed_arguments_lp

	pop	{r1}
	b	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_:
	str	r3,[r6],#4
	subs	r0,r0,#1
	bne	move_closure_with_unboxed_arguments_lp

	pop	{r1}

move_non_pointers_of_closure:
	ldr	r0,[r2],#4
	str	r0,[r6],#4
	subs	r1,r1,#1
	bne	move_non_pointers_of_closure

	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments_1:
	ldr	r1,[r2]
	str	r1,[r6]
	add	r6,r6,#8
	cmp	r5,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long	

.ifdef PIC
 .ifdef FINALIZERS
	lto	finalizer_list,3
	lto	free_finalizer_list,5
	ltol	__Nil-4,__Nil_o_m4,5
	lto	heap_p3,12
	ltol	e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,0
	ltol	e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,1
	lto	finalizer_list,4
	ltol	__Nil-4,__Nil_o_m4,6
	ltol	finalizer_list+1,finalizer_list_o_1,0
	lto	finalizer_list,5
	lto	free_finalizer_list,6
	ltol	__Nil-4,__Nil_o_m4,7
	ltol	free_finalizer_list+4,free_finalizer_list_o_4,0
	lto	end_vector,15
 .endif
	lto	heap_size_33,11
	lto	heap_p3,13
	lto	end_heap_p3,0
	lto	heap_vector,9
	lto	neg_heap_vector_plus_4,0
	lto	heap_p3,14
	lto	neg_heap_vector_plus_4,1
	lto	heap_vector,10
	lto	neg_heap_vector_plus_4,2
	lto	heap_vector,11
	lto	neg_heap_vector_plus_4,3
	ltol	INT+2,INT_o_2,13
	ltol	CHAR+2,CHAR_o_2,8
	ltol	__STRING__+2,__STRING___o_2,10
	ltol	INT+2,INT_o_2,14
	ltol	BOOL+2,BOOL_o_2,7
 .ifdef DLL
	laol	__ARRAY__+2,__ARRAY___o_2,2
 .endif
.endif
	.ltorg
.ifdef PIC
 .ifdef FINALIZERS
	lto	finalizer_list,6
	ltol	__Nil-4,__Nil_o_m4,8
	ltol	e____system__kFinalizer+2,e____system__kFinalizer_o_2,0
 .endif
.endif

end_copy:

.ifdef FINALIZERS
	lao	r7,finalizer_list,6
	ldo	r2,r7,finalizer_list,6

restore_finalizer_descriptors:
	laol	r7,__Nil-4,__Nil_o_m4,8
	otoa	r7,__Nil_o_m4,8
	cmp	r2,r7
	beq	end_restore_finalizer_descriptors

	laol	r7,e____system__kFinalizer+2,e____system__kFinalizer_o_2,0
	otoa	r7,e____system__kFinalizer_o_2,0
	str	r7,[r2]
	ldr	r2,[r2,#4]
	b	restore_finalizer_descriptors

end_restore_finalizer_descriptors:
.endif
