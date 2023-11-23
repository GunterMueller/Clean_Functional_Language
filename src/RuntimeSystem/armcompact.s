
COMPACT_MARK_WITH_STACK = 1
NO_BIT_INSTRUCTIONS = 1

@ mark used nodes and pointers in argument parts and link backward pointers

	lao	r12,heap_size_33,10
	ldo	r4,r12,heap_size_33,10
	lsl	r4,r4,#5
	lao	r12,heap_size_32_33,1
	sto	r4,r12,heap_size_32_33,1
@ heap_size_32_33 in r2
	mov	r2,r4

	lao	r12,heap_p3,11
	ldo	r11,r12,heap_p3,11
@ heap_p3 in r11

.if COMPACT_MARK_WITH_STACK
	add	r9,sp,#-8000
.endif
	lao	r12,caf_list,2
	ldo	r4,r12,caf_list,2
.if COMPACT_MARK_WITH_STACK
	lao	r12,end_stack,1
	sto	r9,r12,end_stack,1
@ end_stack in r0
	mov	r0,r9
.endif
	cmp	r4,#0
	beq	end_mark_cafs

mark_cafs_lp:
	ldr	r12,[r4,#-4]
	str	r12,[sp,#-4]!
.if COMPACT_MARK_WITH_STACK
	add	r9,r4,#4
	ldr	r4,[r4]
	add	r6,r9,r4,lsl #2
.else
	add	r8,r4,#4
	ldr	r4,[r4]
	add	r6,r8,r4,lsl #2
.endif
	lao	r12,end_vector,13
	sto	r6,r12,end_vector,13

	str	pc,[sp,#-4]!
.if COMPACT_MARK_WITH_STACK
	bl	rmark_stack_nodes
.else
	bl	mark_stack_nodes
.endif

	ldr	r4,[sp],#4
	tst	r4,r4
	bne	mark_cafs_lp

end_mark_cafs:
.if COMPACT_MARK_WITH_STACK
	lao	r12,stack_p,6
	ldo	r9,r12,stack_p,6
.else
	lao	r12,stack_p,6
	ldo	r8,r12,stack_p,6
.endif

	lao	r12,stack_top,4
	ldo	r6,r12,stack_top,4
	lao	r12,end_vector,14
	sto	r6,r12,end_vector,14
	str	pc,[sp,#-4]!
.if COMPACT_MARK_WITH_STACK
	bl	rmark_stack_nodes
.else
	bl	mark_stack_nodes
.endif

.ifdef MEASURE_GC
	str	pc,[sp,#-4]!
	bl	add_mark_compact_garbage_collect_time
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
	.include "armcompact_rmark.s"
	.include "armcompact_rmarkr.s"
.else
	.include "armcompact_mark.s"
.endif

@ compact the heap

compact_heap:

.ifdef FINALIZERS
	lao	r6,finalizer_list,3
	lao	r7,free_finalizer_list,5
	otoa	r6,finalizer_list,3
	otoa	r7,free_finalizer_list,5

	ldr	r8,[r6]
determine_free_finalizers_after_compact1:
	laol	r12,__Nil-4,__Nil_o_m4,5
	otoa	r12,__Nil_o_m4,5
	cmp	r8,r12
	beq	end_finalizers_after_compact1

	lao	r12,heap_p3,12
	ldo	r4,r12,heap_p3,12
	sub	r4,r8,r4
	lsr	r3,r4,#7
	and	r4,r4,#31*4
	lsr	r9,r4,#2
	mov	r12,#1
	lsl	r9,r12,r9

	ldr	r12,[r10,r3,lsl #2]
	tst	r9,r12
	beq	finalizer_not_used_after_compact1

	ldr	r4,[r8]
	mov	r9,r8
	b	finalizer_find_descriptor

finalizer_find_descriptor_lp:
	and	r4,r4,#-4
	mov	r9,r4
	ldr	r4,[r4]
finalizer_find_descriptor:
	tst	r4,#1
	bne	finalizer_find_descriptor_lp

	laol	r12,e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,0
	otoa	r12,e____system__kFinalizerGCTemp_o_2,0
	str	r12,[r9]

	cmp	r8,r6
	bhi	finalizer_no_reverse

	ldr	r4,[r8]
	add	r9,r6,#1
	str	r9,[r8]
	str	r4,[r6]

finalizer_no_reverse:
	add	r6,r8,#4
	ldr	r8,[r8,#4]
	b	determine_free_finalizers_after_compact1

finalizer_not_used_after_compact1:
	laol	r12,e____system__kFinalizerGCTemp+2,e____system__kFinalizerGCTemp_o_2,1
	otoa	r12,e____system__kFinalizerGCTemp_o_2,1
	str	r12,[r8]

	str	r8,[r7]
	add	r7,r8,#4

	ldr	r8,[r8,#4]
	str	r8,[r6]

	b	determine_free_finalizers_after_compact1

end_finalizers_after_compact1:
	str	r8,[r7]	

	lao	r12,finalizer_list,4
	ldo	r6,r12,finalizer_list,4
	laol	r12,__Nil-4,__Nil_o_m4,6
	otoa	r12,__Nil_o_m4,6
	cmp	r6,r12
	beq	finalizer_list_empty
	tst	r6,#3
	bne	finalizer_list_already_reversed
	ldr	r4,[r6]
	laol	r12,finalizer_list+1,finalizer_list_o_1,0
	otoa	r12,finalizer_list_o_1,0
	str	r12,[r6]
	lao	r12,finalizer_list,5
	sto	r4,r12,finalizer_list,5
finalizer_list_already_reversed:
finalizer_list_empty:

 .if COMPACT_MARK_WITH_STACK
	lao	r9,free_finalizer_list,6
	otoa	r9,free_finalizer_list,6
	ldr	r6,[r9]
 .else
	lao	r8,free_finalizer_list,6
	otoa	r8,free_finalizer_list,6
	ldr	r6,[r8]
 .endif
	laol	r12,__Nil-4,__Nil_o_m4,7
	otoa	r12,__Nil_o_m4,7
	cmp	r6,r12
	beq	free_finalizer_list_empty
	laol	r6,free_finalizer_list+4,free_finalizer_list_o_4,0
	otoa	r6,free_finalizer_list_o_4,0
	lao	r12,end_vector,15
	sto	r6,r12,end_vector,15
 .if COMPACT_MARK_WITH_STACK
	str	pc,[sp,#-4]!
	bl	rmark_stack_nodes
 .else
	str	pc,[sp,#-4]!
	bl	mark_stack_nodes
 .endif
free_finalizer_list_empty:
.endif

	lao	r12,heap_size_33,11
	ldo	r4,r12,heap_size_33,11
	mov	r3,r4
	lsl	r3,r3,#5

	lao	r12,heap_p3,13
	ldo	r12,r12,heap_p3,13
	add	r3,r3,r12

	lao	r12,end_heap_p3,0
	sto	r3,r12,end_heap_p3,0
@ end_heap_p3 in r0
 	mov	r0,r3

	add	r4,r4,#3
	lsr	r4,r4,#2
@ vector_counter in r2
	mov	r2,r4

	lao	r12,heap_vector,9
	ldo	r6,r12,heap_vector,9
@ vector_p in r1
	mov	r1,r6

	mov	r12,#-4
	rsb	r3,r6,r12
	lao	r12,neg_heap_vector_plus_4,0
	sto	r3,r12,neg_heap_vector_plus_4,0

	lao	r12,heap_p3,14
	ldo	r10,r12,heap_p3,14
	mov	r9,#0
@ heap_p3 in r11
	mov	r11,r10
	b	skip_zeros

@ d0,a0,a2: free
find_non_zero_long:
skip_zeros:
	subs	r2,r2,#1
	bcc	end_copy
	ldr	r9,[r1],#4
	cmp	r9,#0
	beq	skip_zeros
@ a2: free
end_skip_zeros:
	lao	r12,neg_heap_vector_plus_4,1
	ldo	r8,r12,neg_heap_vector_plus_4,1
	add	r8,r8,r1

	add	r8,r11,r8,lsl #5

bsf_and_copy_nodes:
	neg	r12,r9
	and	r12,r12,r9
	clz	r3,r12
	rsb	r3,r3,#31

copy_nodes:
	ldr	r4,[r8,r3,lsl #2]

	bic	r9,r9,r12

	add	r12,r8,#4
	add	r6,r12,r3,lsl #2
	sub	r4,r4,#1

	tst	r4,#2
	beq	begin_update_list_2

	ldr	r3,[r4,#-10]
	subs	r4,r4,#2

	tst	r3,#1
	beq	end_list_2
find_descriptor_2:
	and	r3,r3,#-4
	ldr	r3,[r3]
	tst	r3,#1
	bne	find_descriptor_2

end_list_2:
	mov	r7,r3
	ldrh	r3,[r3,#-2]
	cmp	r3,#256
	blo	no_record_arguments

	ldrh	r7,[r7,#-2+2]
	subs	r7,r7,#2
	bhs	copy_record_arguments_aa

	sub	r3,r3,#256
	sub	r3,r3,#3

copy_record_arguments_all_b:
	str	r3,[sp,#-4]!
	lao	r12,heap_vector,10
	ldo	r3,r12,heap_vector,10

update_up_list_1r:
	mov	r7,r4
	sub	r4,r4,r11

	str	r6,[sp,#-4]!

	and	r6,r4,#31*4
	lsr	r4,r4,#7
	lsr	r6,r6,#2
	mov	r12,#1
	lsl	r6,r12,r6

	ldr	r4,[r3,r4,lsl #2]

	ands	r4,r4,r6

	ldr	r6,[sp],#4
	beq	copy_argument_part_1r

	ldr	r4,[r7]
	str	r10,[r7]
	subs	r4,r4,#3
	b	update_up_list_1r

copy_argument_part_1r:
	ldr	r4,[r7]
	str	r10,[r7]
	str	r4,[r10],#4

	sub	r4,r6,r11
	lsr	r4,r4,#2

	mov	r3,r4
	and	r3,r3,#31
	cmp	r3,#1
	bhs	bit_in_this_word

	sub	r2,r2,#1
	ldr	r9,[r1],#4

	lao	r12,neg_heap_vector_plus_4,2
	ldo	r8,r12,neg_heap_vector_plus_4,2
	add	r8,r8,r1
	add	r8,r11,r8,lsl #5

bit_in_this_word:
	mov	r12,#1
	lsl	r12,r12,r3
	bic	r9,r9,r12

	ldr	r3,[sp],#4

copy_b_record_argument_part_arguments:
	ldr	r4,[r6],#4
	str	r4,[r10],#4
	subs	r3,r3,#1
	bcs	copy_b_record_argument_part_arguments

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

copy_record_arguments_aa:
	mov	r12,#(256+2)/2
	sub	r3,r3,r7
	sub	r3,r3,r12,lsl #1

	str	r3,[sp,#-4]!
	str	r7,[sp,#-4]!

update_up_list_2r:
	mov	r7,r4
	ldr	r4,[r7]
	and	r3,r4,#3
	subs	r3,r3,#3
	bne	copy_argument_part_2r

	str	r10,[r7]
	subs	r4,r4,#3
	b	update_up_list_2r

copy_argument_part_2r:
	str	r10,[r7]
	cmp	r4,r6
	blo	copy_record_argument_2
.ifdef SHARE_CHAR_INT
	cmp	r4,r0
	bhs	copy_record_argument_2
.endif
	mov	r7,r4
	ldr	r4,[r7]
	add	r3,r10,#1
	str	r3,[r7]
copy_record_argument_2:
	str	r4,[r10],#4

	ldr	r3,[sp],#4
	subs	r3,r3,#1
	bcc	no_pointers_in_record

copy_record_pointers:
	ldr	r7,[r6],#4
	cmp	r7,r6
	blo	copy_record_pointers_2
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bhs	copy_record_pointers_2
.endif
	ldr	r4,[r7]
	add	r10,r10,#1
	str	r10,[r7]
	subs	r10,r10,#1
	mov	r7,r4
copy_record_pointers_2:
	str	r7,[r10],#4
	subs	r3,r3,#1
	bcs	copy_record_pointers

no_pointers_in_record:
	ldr	r3,[sp],#4

	subs	r3,r3,#1
	bcc	no_non_pointers_in_record

copy_non_pointers_in_record:
	ldr	r4,[r6],#4
	str	r4,[r10],#4
	subs	r3,r3,#1
	bcs	copy_non_pointers_in_record

no_non_pointers_in_record:
	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

no_record_arguments:
	subs	r3,r3,#3
update_up_list_2:
	mov	r7,r4
	ldr	r4,[r4]
	add	r4,r4,#1
	str	r10,[r7]
	tst	r4,#3
	bne	copy_argument_part_2

	subs	r4,r4,#4
	b	update_up_list_2

copy_argument_part_2:
	sub	r4,r4,#1
	cmp	r4,r6
	bcc	copy_arguments_1
.ifdef SHARE_CHAR_INT
	cmp	r4,r0
	bcs	copy_arguments_1
.endif
	mov	r7,r4
	ldr	r4,[r4]
	add	r10,r10,#1
	str	r10,[r7]
	subs	r10,r10,#1
copy_arguments_1:
	str	r4,[r10],#4

copy_argument_part_arguments:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	copy_arguments_2
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	copy_arguments_2
.endif
	ldr	r4,[r7]
	add	r10,r10,#1
	str	r10,[r7]
	subs	r10,r10,#1
	mov	r7,r4
copy_arguments_2:
	str	r7,[r10],#4
	subs	r3,r3,#1
	bcs	copy_argument_part_arguments

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

update_list_2_:
	subs	r4,r4,#1
update_list_2:
	str	r10,[r7]
begin_update_list_2:
	mov	r7,r4
	ldr	r4,[r4]
update_list__2:
	tst	r4,#1
	beq	end_update_list_2
	tst	r4,#2
	beq	update_list_2_
	add	r7,r4,#-3
	ldr	r4,[r4,#-3]
	b	update_list__2

end_update_list_2:
	str	r10,[r7]

	str	r4,[r10],#4

	tst	r4,#2
	beq	move_lazy_node

	ldrh	r3,[r4,#-2]
	tst	r3,r3
	beq	move_hnf_0

	cmp	r3,#256
	bhs	move_record

	subs	r3,r3,#2
	bcc	move_hnf_1
	beq	move_hnf_2

move_hnf_3:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_hnf_3_1
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_hnf_3_1
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_hnf_3_1:
	str	r7,[r10]

	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_hnf_3_2
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_hnf_3_2
.endif
	add	r4,r10,#4+2+1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_hnf_3_2:
	str	r7,[r10,#4]
	add	r10,r10,#8

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_2:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_hnf_2_1
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_hnf_2_1
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_hnf_2_1:
	str	r7,[r10]

	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_hnf_2_2
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_hnf_2_2
.endif
	add	r4,r10,#4+1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_hnf_2_2:
	str	r7,[r10,#4]
	add	r10,r10,#8

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_1:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_hnf_1_
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_hnf_1_
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_hnf_1_:
	str	r7,[r10],#4

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_record:
	mov	r12,#258/2
	subs	r3,r3,r12,lsl #1
	blo	move_record_1
	beq	move_record_2

move_record_3:
	ldrh	r3,[r4,#-2+2]
	subs	r3,r3,#1
	bhi	move_hnf_3

	ldr	r7,[r6],#4
	blo	move_record_3_1b

move_record_3_1a:
	cmp	r7,r6
	blo	move_record_3_1b
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bhs	move_record_3_1b
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_record_3_1b:
	str	r7,[r10],#4

	ldr	r7,[r6],#4
	cmp	r7,r6
	blo	move_record_3_2
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bhs	move_record_3_2
.endif
	str	r8,[sp,#-4]!
	sub	r4,r7,r11

	lao	r12,heap_vector,11
	ldo	r3,r12,heap_vector,11
	add	r4,r4,#4
	and	r8,r4,#31*4
	lsr	r4,r4,#7
	lsr	r8,r8,#2
	mov	r12,#1
	lsl	r8,r12,r8

	ldr	r12,[r3,r4,lsl #2]
	tst	r8,r12
	beq	not_linked_record_argument_part_3_b

	sub	r4,r10,r11

	and	r8,r4,#31*4
	lsr	r4,r4,#7
	lsr	r8,r8,#2
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r12,[r3,r4,lsl #2]
	orr	r12,r12,r8
	str	r12,[r3,r4,lsl #2]
	ldr	r8,[sp],#4
	b	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	ldr	r12,[r3,r4,lsl #2]
	orr	r12,r12,r8
	str	r12,[r3,r4,lsl #2]

	sub	r4,r10,r11

	and	r8,r4,#31*4
	lsr	r4,r4,#7

	lsr	r8,r8,#2
	mov	r12,#1
	mvn	r8,r12,lsl r8

	ldr	r12,[r3,r4,lsl #2]
	and	r12,r12,r8
	str	r12,[r3,r4,lsl #2]
	ldr	r8,[sp],#4

linked_record_argument_part_3_b:
	ldr	r3,[r7]
	add	r4,r10,#2+1
	str	r4,[r7]
	mov	r7,r3
move_record_3_2:
	str	r7,[r10],#4

	sub	r3,r6,r11
	lsr	r3,r3,#2
	subs	r3,r3,#1
	and	r3,r3,#31
	cmp	r3,#2
	blo	bit_in_next_word

	mov	r12,#1
	lsl	r12,r12,r3
	bic	r9,r9,r12

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

bit_in_next_word:
	sub	r2,r2,#1
	ldr	r9,[r1],#4

	mov	r12,#1
	lsl	r12,r12,r3
	bic	r9,r9,r12

	cmp	r9,#0
	beq	skip_zeros
	b	end_skip_zeros

move_record_2:
	ldrh	r12,[r4,#-2+2]
	cmp	r12,#1
	bhi	move_hnf_2
	blo	move_real_or_file

move_record_2_ab:
	ldr	r7,[r6],#4
	cmp	r7,r6
	blo	move_record_2_1
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bhs	move_record_2_1
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_record_2_1:
	str	r7,[r10]
	ldr	r3,[r6],#4
	str	r3,[r10,#4]
	add	r10,r10,#8

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_record_1:
	ldrh	r3,[r4,#-2+2]
	tst	r3,r3
	bne	move_hnf_1
	b	move_int_bool_or_char

move_real_or_file:
	ldr	r4,[r6],#4
	str	r4,[r10],#4
move_int_bool_or_char:
	ldr	r4,[r6],#4
	str	r4,[r10],#4
copy_normal_hnf_0:
	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_hnf_0:
	laol	r12,INT+2,INT_o_2,13
	otoa	r12,INT_o_2,13
	cmp	r4,r12
	blo	move_real_file_string_or_array
	laol	r12,CHAR+2,CHAR_o_2,8
	otoa	r12,CHAR_o_2,8
	cmp	r4,r12
	bls	move_int_bool_or_char
.ifdef DLL
move_normal_hnf_0:
.endif

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_real_file_string_or_array:
	laol	r12,__STRING__+2,__STRING___o_2,10
	otoa	r12,__STRING___o_2,10
	cmp	r4,r12
	bhi	move_real_or_file
	bne	move_array

	ldr	r4,[r6]
	add	r4,r4,#3
	lsr	r4,r4,#2

cp_s_arg_lp3:
	ldr	r3,[r6],#4
	str	r3,[r10],#4
	subs	r4,r4,#1
	bcs	cp_s_arg_lp3

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_array:
.ifdef DLL
	laol	r12,__ARRAY__+2,__ARRAY___o_2,2
	otoa	r12,__ARRAY___o_2,2
	cmp	r4,r12
	blo	move_normal_hnf_0
.endif
	cmp	r9,#0
	bne	bsf_and_end_array_bit

skip_zeros_a:
	ldr	r9,[r1],#4
	sub	r2,r2,#1
	cmp	r9,#0
	beq	skip_zeros_a

	lao	r12,neg_heap_vector_plus_4,3
	ldo	r8,r12,neg_heap_vector_plus_4,3
	add	r8,r8,r1

	add	r8,r11,r8,lsl #5

bsf_and_end_array_bit:
	neg	r12,r9
	and	r12,r12,r9
	clz	r3,r12
	rsb	r3,r3,#31

end_array_bit:
	bic	r9,r9,r12

	add	r3,r8,r3,lsl #2

	cmp	r6,r3
	bne	move_a_array

move_b_array:
	ldr	r7,[r6]
	str	r7,[r10]
	ldr	r3,[r6,#4]!
	ldrh	r4,[r3,#-2]
	add	r10,r10,#4
	tst	r4,r4
	beq	move_strict_basic_array

	subs	r4,r4,#256
	mul	r7,r4,r7
	mov	r4,r7
	b	cp_s_arg_lp3

move_strict_basic_array:
	mov	r4,r7
	laol	r12,INT+2,INT_o_2,14
	otoa	r12,INT_o_2,14
	cmp	r3,r12
	beq	cp_s_arg_lp3

	laol	r12,BOOL+2,BOOL_o_2,7
	otoa	r12,BOOL_o_2,7
	cmp	r3,r12
	beq	move_bool_array

	add	r4,r4,r4
	b	cp_s_arg_lp3

move_bool_array:
	add	r4,r4,#3
	lsr	r4,r4,#2
	b	cp_s_arg_lp3

move_a_array:
	mov	r7,r3
	subs	r3,r3,r6
	lsr	r3,r3,#2

	str	r9,[sp,#-4]!

	subs	r3,r3,#1
	blo	end_array

	ldr	r9,[r6]
	ldr	r4,[r7,#-4]
	str	r9,[r7,#-4]
	str	r4,[r10]
	ldr	r4,[r7]
	ldr	r9,[r6,#4]
	add	r6,r6,#8
	str	r9,[r7]
	str	r4,[r10,#4]
	add	r10,r10,#8
	tst	r4,r4
	beq	st_move_array_lp

	ldrh	r9,[r4,#-2+2]
	ldrh	r4,[r4,#-2]
	subs	r4,r4,#256
	cmp	r4,r9
	beq	st_move_array_lp

move_array_ab:
	str	r6,[sp,#-4]!

	ldr	r7,[r10,#-8]
	mov	r3,r9
	mul	r7,r4,r7
	lsl	r7,r7,#2

	subs	r4,r4,r3
	add	r7,r7,r6
	str	pc,[sp,#-4]!
	bl	reorder

	ldr	r6,[sp],#4
	subs	r3,r3,#1
	subs	r4,r4,#1

	str	r3,[sp,#-4]!
	str	r4,[sp,#-4]!
	ldr	r12,[r10,#-8]
	str	r12,[sp,#-4]!
	b	st_move_array_lp_ab

move_array_ab_lp1:
	ldr	r4,[sp,#8]
move_array_ab_a_elements:
	ldr	r3,[r6],#4
	cmp	r3,r6
	blo	move_array_element_ab
.ifdef SHARE_CHAR_INT
	cmp	r3,r0
	bcs	move_array_element_ab
.endif
	mov	r7,r3
	ldr	r3,[r7]
	add	r10,r10,#1
	str	r10,[r7]
	subs	r10,r10,#1
move_array_element_ab:
	str	r3,[r10],#4
	subs	r4,r4,#1
	bcs	move_array_ab_a_elements

	ldr	r4,[sp,#4]
move_array_ab_b_elements:
	ldr	r3,[r6],#4
	str	r3,[r10],#4
	subs	r4,r4,#1
	bcs	move_array_ab_b_elements

st_move_array_lp_ab:
	ldr	r12,[sp]
	subs	r12,r12,#1
	str	r12,[sp]
	bcs	move_array_ab_lp1

	add	sp,sp,#12
	b	end_array	

move_array_lp1:
	ldr	r4,[r6],#4
	add	r10,r10,#4
	cmp	r4,r6
	blo	move_array_element
.ifdef SHARE_CHAR_INT
	cmp	r4,r0
	bcs	move_array_element
.endif
	ldr	r9,[r4]
	mov	r7,r4
	str	r9,[r10,#-4]
	add	r4,r10,#-4+1
	str	r4,[r7]

	subs	r3,r3,#1
	bcs	move_array_lp1

	b	end_array

move_array_element:
	str	r4,[r10,#-4]
st_move_array_lp:
	subs	r3,r3,#1
	bcs	move_array_lp1

end_array:
	ldr	r9,[sp],#4

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node:
	mov	r7,r4
	ldr	r3,[r7,#-4]
	tst	r3,r3
	beq	move_lazy_node_0

	subs	r3,r3,#1
	ble	move_lazy_node_1

	cmp	r3,#256
	bge	move_closure_with_unboxed_arguments

move_lazy_node_arguments:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_lazy_node_arguments_
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_lazy_node_arguments_
.endif
	ldr	r4,[r7]
	str	r4,[r10]
	add	r4,r10,#1
	add	r10,r10,#4
	str	r4,[r7]
	subs	r3,r3,#1
	bcs	move_lazy_node_arguments

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_arguments_:
	str	r7,[r10],#4
	subs	r3,r3,#1
	bcs	move_lazy_node_arguments

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_1:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_lazy_node_1_
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_lazy_node_1_
.endif
	add	r4,r10,#1
	ldr	r3,[r7]
	str	r4,[r7]
	mov	r7,r3
move_lazy_node_1_:
	str	r7,[r10]
	add	r10,r10,#8

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_lazy_node_0:
	add	r10,r10,#8

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments:
	beq	move_closure_with_unboxed_arguments_1
	add	r3,r3,#1
	mov	r4,r3
	and	r3,r3,#255
	lsr	r4,r4,#8
	subs	r3,r3,r4
	beq	move_non_pointers_of_closure

	str	r4,[sp,#-4]!

move_closure_with_unboxed_arguments_lp:
	ldr	r7,[r6],#4
	cmp	r7,r6
	bcc	move_closure_with_unboxed_arguments_
.ifdef SHARE_CHAR_INT
	cmp	r7,r0
	bcs	move_closure_with_unboxed_arguments_
.endif
	ldr	r4,[r7]
	str	r4,[r10]
	add	r4,r10,#1
	add	r10,r10,#4
	str	r4,[r7]
	subs	r3,r3,#1
	bne	move_closure_with_unboxed_arguments_lp

	ldr	r4,[sp],#4
	b	move_non_pointers_of_closure

move_closure_with_unboxed_arguments_:
	str	r7,[r10],#4
	subs	r3,r3,#1
	bne	move_closure_with_unboxed_arguments_lp

	ldr	r4,[sp],#4

move_non_pointers_of_closure:
	ldr	r3,[r6],#4
	str	r3,[r10],#4
	subs	r4,r4,#1
	bne	move_non_pointers_of_closure

	cmp	r9,#0
	bne	bsf_and_copy_nodes
	b	find_non_zero_long

move_closure_with_unboxed_arguments_1:
	ldr	r4,[r6]
	str	r4,[r10]
	add	r10,r10,#8
	cmp	r9,#0
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
	lao	r12,finalizer_list,6
	ldo	r6,r12,finalizer_list,6

restore_finalizer_descriptors:
	laol	r12,__Nil-4,__Nil_o_m4,8
	otoa	r12,__Nil_o_m4,8
	cmp	r6,r12
	beq	end_restore_finalizer_descriptors

	laol	r12,e____system__kFinalizer+2,e____system__kFinalizer_o_2,0
	otoa	r12,e____system__kFinalizer_o_2,0
	str	r12,[r6]
	ldr	r6,[r6,#4]
	b	restore_finalizer_descriptors

end_restore_finalizer_descriptors:
.endif
