
ZERO_ARITY_DESCRIPTOR_OFFSET = -4
COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP = 1

	str	r9,[sp,#-4]!

	lao	r12,heap_p2,9
	ldo	r10,r12,heap_p2,9

	lao	r12,heap_size_129,4
	ldo	r4,r12,heap_size_129,4
	lsl	r4,r4,#6

	lao	r12,semi_space_size,0
	sto	r4,r12,semi_space_size,0

	add	r9,r10,r4

@ r0 = INT+2
@ r1 = CHAR+2
	laol	r0,INT+2,INT_o_2,6
	laol	r1,CHAR+2,CHAR_o_2,2
	otoa	r0,INT_o_2,6
	otoa	r1,CHAR_o_2,2

.if WRITE_HEAP
	laol	r12,heap2_begin_and_end+4,heap2_begin_and_end_o_4,0
	sto	r9,r12,heap2_begin_and_end_o_4,0
.endif

	sub	sp,sp,#16

	lao	r12,caf_list,0
	ldo	r4,r12,caf_list,0
	tst	r4,r4
	beq	end_copy_cafs

copy_cafs_lp:
	ldr	r12,[r4,#-4]
	str	r12,[sp,#-4]!

	add	r8,r4,#4
	ldr	r3,[r4]
	mov	r2,#-2
	bl	copy_lp2

	ldr	r4,[sp],#4
	cmp	r4,#0
	bne	copy_cafs_lp

end_copy_cafs:
	ldr	r3,[sp,#16]
	lao	r12,stack_p,4
	ldo	r8,r12,stack_p,4
	sub	r3,r3,r8
	lsr	r3,r3,#2

	cmp	r3,#0
	beq	end_copy0
	mov	r2,#-2
	bl	copy_lp2
end_copy0:
	lao	r12,heap_p2,10
	ldo	r8,r12,heap_p2,10

	bl	copy_lp1

	add	sp,sp,#16

	lao	r12,heap_end_after_gc,10
	sto	r9,r12,heap_end_after_gc,10

.ifdef FINALIZERS
	lao	r6,finalizer_list,1
	lao	r7,free_finalizer_list,3
	otoa	r6,finalizer_list,1
	otoa	r7,free_finalizer_list,3
	ldr	r8,[r6]

determine_free_finalizers_after_copy:
	ldr	r4,[r8]
	tst	r4,#1
	beq	finalizer_not_used_after_copy

	ldr	r8,[r8,#4]
	sub	r4,r4,#1
	str	r4,[r6]
	add	r6,r4,#4
	b	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	laol	r12,__Nil-4,__Nil_o_m4,3
	otoa	r12,__Nil_o_m4,3
	cmp	r8,r12
	beq	end_finalizers_after_copy

	str	r8,[r7]
	add	r7,r8,#4
	ldr	r8,[r8,#4]
	b	determine_free_finalizers_after_copy	

end_finalizers_after_copy:
	str	r8,[r6]
	str	r8,[r7]
.endif

	b	skip_copy_gc

.ifdef PIC
	lto	heap_p2,9
	lto	heap_size_129,4
	lto	semi_space_size,0
	ltol	INT+2,INT_o_2,6
	ltol	CHAR+2,CHAR_o_2,2
 .if WRITE_HEAP
	ltol	heap2_begin_and_end+4,heap2_begin_and_end_o_4,0
 .endif
	lto	caf_list,0
	lto	stack_p,4
	lto	heap_p2,10
	lto	heap_end_after_gc,10
 .ifdef FINALIZERS
	lto	finalizer_list,1
	lto	free_finalizer_list,3
	ltol	__Nil-4,__Nil_o_m4,3
 .endif
.endif
	.ltorg


@
@	Copy nodes to the other semi-space
@

copy_lp2_lp1_all_pointers:
	add	r2,r8,r3,lsl #2

copy_lp2_lp1:
copy_lp2:
	ldr	r7,[r8],#4
	sub	r5,r8,#4

copy_lp2__lp1:
copy_lp2_:
@ selectors:
continue_after_selector_2:
	ldr	r6,[r7]
	tst	r6,#2
	beq	not_in_hnf_2

in_hnf_2:
	ldrh	r4,[r6,#-2]
	cmp	r4,#0
	beq	copy_arity_0_node2

	cmp	r4,#256
	bhs	copy_record_2

	subs	r4,r4,#2
	str	r10,[r5]
	bhi	copy_hnf_node2_3

	str	r6,[r10],#1
	blo	copy_hnf_node2_1

	ldr	r6,[r7,#4]

	str	r10,[r7]
	ldr	r4,[r7,#8]

	subs	r3,r3,#1
	str	r6,[r10,#4-1]

	str	r4,[r10,#8-1]
	add	r10,r10,#12-1

	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_hnf_node2_1:
	ldr	r4,[r7,#4]

	subs	r3,r3,#1
	str	r10,[r7]

	str	r4,[r10,#4-1]
	add	r10,r10,#8-1

	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_hnf_node2_3:
	str	r6,[r10],#1

	str	r10,[r7]
	ldr	r6,[r7,#4]

	str	r6,[r10,#4-1]
	ldr	r6,[r7,#8]

	add	r10,r10,#12-1
	ldr	r7,[r6]

	tst	r7,#1
	bne	arguments_already_copied_2

	str	r10,[r10,#-4]

	str	r7,[r10],#1

	str	r10,[r6],#4
	add	r10,r10,#4-1

cp_hnf_arg_lp2:
	ldr	r7,[r6],#4
	str	r7,[r10],#4
	subs	r4,r4,#1
	bne	cp_hnf_arg_lp2

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

arguments_already_copied_2:
	str	r7,[r10,#-4]

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_arity_0_node2:
	cmp	r6,r0 @ INT+2
	blo	copy_real_file_or_string_2

	cmp	r6,r1 @ CHAR+2
	bhi	copy_normal_hnf_0_2

copy_int_bool_or_char_2:
	ldr	r4,[r7,#4]
	beq	copy_char_2

	cmp	r6,r0 @ INT+2
	bne	no_small_int_or_char_2

copy_int_2:
	cmp	r4,#33
	bhs	no_small_int_or_char_2

	lao	r12,small_integers,1
	subs	r3,r3,#1
	otoa	r12,small_integers,1

	add	r4,r12,r4,lsl #3

	str	r4,[r5]
	bne	copy_lp2

	mov	r8,r2
	b	copy_lp1

copy_char_2:
	and	r4,r4,#255

	lao	r12,static_characters,1
	subs	r3,r3,#1
	otoa	r12,static_characters,1

	add	r4,r12,r4,lsl #3

	str	r4,[r5]
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

no_small_int_or_char_2:
copy_record_node2_1_b:
	str	r6,[r9,#-8]

	str	r4,[r9,#-4]
	sub	r9,r9,#7

	str	r9,[r7]
	sub	r9,r9,#1

	str	r9,[r5]

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_normal_hnf_0_2:
	sub	r6,r6,#2-ZERO_ARITY_DESCRIPTOR_OFFSET
	subs	r3,r3,#1

	str	r6,[r5]
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_real_file_or_string_2:
	laol	r12,__STRING__+2,__STRING___o_2,7
	otoa	r12,__STRING___o_2,7
	cmp	r6,r12
	bls	copy_string_or_array_2

copy_real_or_file_2:
	str	r6,[r9,#-12]
	sub	r9,r9,#12-1

	str	r9,[r7]
	sub	r9,r9,#1

	ldr	r4,[r7,#4]
	ldr	r6,[r7,#8]

	str	r9,[r5]

	str	r4,[r9,#4]
	subs	r3,r3,#1

	str	r6,[r9,#8]

	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

already_copied_2:
	sub	r6,r6,#1
	subs	r3,r3,#1

	str	r6,[r5]

	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_record_2:
	ldrh	r12,[r6,#-2+2]
	sub	r4,r4,#256
	subs	r4,#2
	bhi	copy_record_node2_3
	blo	copy_record_node2_1

	cmp	r12,#0
	beq	copy_real_or_file_2

	str	r10,[r5]
	str	r6,[r10]

	add	r6,r10,#1
	ldr	r4,[r7,#4]

	str	r6,[r7]

	str	r4,[r10,#4]
	ldr	r4,[r7,#8]

	str	r4,[r10,#8]

	add	r10,r10,#12	
	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_record_node2_1:
	ldr	r4,[r7,#4]

	cmp	r12,#0
	beq	copy_record_node2_1_b

	str	r10,[r5]
	str	r6,[r10]

	add	r6,r10,#1
	str	r4,[r10,#4]

	str	r6,[r7]

	add	r10,r10,#8
	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_record_node2_3:
	cmp	r12,#1
	bls	copy_record_node2_3_ab_or_b

	str	r4,[sp,#-4]!
	add	r4,r10,#1

	str	r4,[r7]
	ldr	r4,[r7,#8]

	str	r6,[r10]
	ldr	r7,[r7,#4]

	str	r7,[r10,#4]
	str	r10,[r5]

	ldr	r12,[r4]
	mov	r6,r4
	tst	r12,#1
	bne	record_arguments_already_copied_2

	add	r7,r10,#12

	ldr	r4,[sp],#4
	str	r7,[r10,#8]

	add	r10,r10,#13
	ldr	r7,[r6]

	str	r10,[r6],#4

	str	r7,[r10,#-1]
	add	r10,r10,#3

cp_record_arg_lp2:
	ldr	r7,[r6],#4

	str	r7,[r10],#4

	subs	r4,r4,#1
	bne	cp_record_arg_lp2

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

record_arguments_already_copied_2:
	ldr	r7,[r6]
	ldr	r4,[sp],#4

	str	r7,[r10,#8]
	add	r10,r10,#12

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_record_node2_3_ab_or_b:
	blo	copy_record_node2_3_b

copy_record_node2_3_ab:
	str	r4,[sp,#-4]!
	add	r4,r10,#1

	lao	r12,heap_p1,9

	str	r4,[r7]
	ldr	r4,[r7,#8]

	ldo	r12,r12,heap_p1,9

	str	r6,[r10]
	ldr	r7,[r7,#4]

	mov	r6,r4
	sub	r4,r4,r12

	lao	r12,heap_copied_vector,4

	str	r7,[r10,#4]

	lsr	r7,r4,#6
	lsr	r4,r4,#3

	and	r4,r4,#31

	ldo	r12,r12,heap_copied_vector,4
	and	r7,r7,#-4

	str	r10,[r5]

	add	r7,r7,r12

	mov	r12,#1
	lsl	r4,r12,r4

	ldr	r12,[r7]
	tst	r4,r12
	bne	record_arguments_already_copied_2

	orr	r12,r12,r4
	str	r12,[r7]
	ldr	r4,[sp],#4

	sub	r9,r9,#4

	lsl	r4,r4,#2
	sub	r9,r9,r4

	str	r9,[sp,#-4]!
	add	r9,r9,#1

	str	r9,[r10,#8]
	add	r10,r10,#12

	ldr	r7,[r6]
	b	cp_record_arg_lp3_c

copy_record_node2_3_b:
	str	r4,[sp,#-4]!
	add	r4,r9,#-12+1

	lao	r12,heap_p1,10

	str	r4,[r7]
	ldr	r4,[r7,#8]

	ldo	r12,r12,heap_p1,10

	str	r6,[r9,#-12]
	ldr	r7,[r7,#4]

	mov	r6,r4
	sub	r4,r4,r12

	lao	r12,heap_copied_vector,5

	str	r7,[r9,#-8]

	lsr	r7,r4,#6
	sub	r9,r9,#12
	lsr	r4,r4,#3

	and	r4,r4,#31

	ldo	r12,r12,heap_copied_vector,5
	and	r7,r7,#-4

	str	r9,[r5]

	add	r7,r7,r12

	mov	r12,#1
	lsl	r4,r12,r4

	ldr	r12,[r7]
	tst	r4,r12
	bne	record_arguments_already_copied_3_b

	orr	r12,r12,r4
	str	r12,[r7]
	ldr	r4,[sp],#4

	mov	r7,r9
	sub	r9,r9,#4

	lsl	r4,r4,#2
	sub	r9,r9,r4

	str	r9,[r7,#8]

	ldr	r7,[r6]

	str	r9,[sp,#-4]!
	add	r9,r9,#1

cp_record_arg_lp3_c:
	str	r9,[r6],#4

	str	r7,[r9,#-1]
	add	r9,r9,#3

cp_record_arg_lp3:
	ldr	r7,[r6],#4

	str	r7,[r9],#4

	subs	r4,r4,#4
	bne	cp_record_arg_lp3

	ldr	r9,[sp],#4

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

record_arguments_already_copied_3_b:
	ldr	r7,[r6]
	ldr	r4,[sp],#4

	sub	r7,r7,#1
	str	r7,[r9,#8]

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

not_in_hnf_2:
	tst	r6,#1
	bne	already_copied_2

	ldr	r4,[r6,#-4]
	cmp	r4,#0
	ble	copy_arity_0_node2_

copy_node2_1_:
	and	r4,r4,#255
	subs	r4,r4,#2
	blt	copy_arity_1_node2
copy_node2_3:
	str	r10,[r5]
	str	r6,[r10]
	add	r10,r10,#1
	str	r10,[r7]
	ldr	r6,[r7,#4]
	add	r7,r7,#8
	str	r6,[r10,#4-1]
	add	r10,r10,#8-1

cp_arg_lp2:
	ldr	r6,[r7],#4
	str	r6,[r10],#4
	subs	r4,r4,#1
	bhs	cp_arg_lp2

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_arity_1_node2__:
	ldr	r3,[sp],#4
copy_arity_1_node2:
copy_arity_1_node2_:
	str	r10,[r5]
	add	r10,r10,#1

	str	r10,[r7]

	ldr	r4,[r7,#4]
	str	r6,[r10,#-1]

	str	r4,[r10,#4-1]
	add	r10,r10,#12-1

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_indirection_2:
	mov	r4,r7
	ldr	r7,[r7,#4]

	ldr	r6,[r7]
	tst	r6,#2
	bne	in_hnf_2

	tst	r6,#1
	bne	already_copied_2

	ldr	r12,[r6,#-4]
	cmp	r12,#-2
	beq	skip_indirections_2

	movs	r4,r12
	ble	copy_arity_0_node2_
	b	copy_node2_1_

skip_indirections_2:
	ldr	r7,[r7,#4]

	ldr	r6,[r7]
	tst	r6,#2
	bne	update_indirection_list_2
	tst	r6,#1
	bne	update_indirection_list_2

	ldr	r12,[r6,#-4]
	cmp	r12,#-2
	beq	skip_indirections_2

update_indirection_list_2:
	add	r6,r4,#4
	ldr	r4,[r4,#4]
	str	r7,[r6]
	cmp	r7,r4
	bne	update_indirection_list_2

	b	continue_after_selector_2

copy_selector_2:
	cmp	r4,#-2
	beq	copy_indirection_2
	blt	copy_record_selector_2

	ldr	r4,[r7,#4]

	str	r3,[sp,#-4]!

	ldr	r3,[r4]
 	tst	r3,#2
	beq	copy_arity_1_node2__

	ldrh	r12,[r3,#-2]
	cmp	r12,#2
	bls	copy_selector_2_

	ldr	r3,[r4,#8]
	ldrb	r12,[r3]
	tst	r12,#1
	bne	copy_arity_1_node2__

.ifdef PIC
	add	r11,r6,#-8+4
.endif
	ldr	r6,[r6,#-8]
	lao	r12,e__system__nind,8
.ifdef PIC
	ldrh	r6,[r11,r6]
.else
	ldrh	r6,[r6,#4]
.endif
	otoa	r12,e__system__nind,8
	str	r12,[r7]

	cmp	r6,#8
	blt	copy_selector_2_1
	beq	copy_selector_2_2

	sub	r3,r3,#12
	ldr	r6,[r6,r3]
	ldr	r3,[sp],#4
	str	r6,[r7,#4]
	mov	r7,r6
	b	continue_after_selector_2

copy_selector_2_1:
	ldr	r6,[r4,#4]
	ldr	r3,[sp],#4
	str	r6,[r7,#4]
	mov	r7,r6
	b	continue_after_selector_2

copy_selector_2_2:
	ldr	r6,[r3]
	ldr	r3,[sp],#4
	str	r6,[r7,#4]
	mov	r7,r6
	b	continue_after_selector_2

copy_selector_2_:
.ifdef PIC
	add	r11,r6,#-8+4
.endif
	ldr	r6,[r6,#-8]
	ldr	r3,[sp],#4

	lao	r12,e__system__nind,9
.ifdef PIC
	ldrh	r6,[r11,r6]
.else
	ldrh	r6,[r6,#4]
.endif
	otoa	r12,e__system__nind,9
	str	r12,[r7]

	ldr	r6,[r4,r6]
	str	r6,[r7,#4]
	mov	r7,r6
	b	continue_after_selector_2

copy_record_selector_2:
	cmp	r4,#-3
	ldr	r4,[r7,#4]
	ldr	r4,[r4]
	beq	copy_strict_record_selector_2

 	tst	r4,#2
	beq	copy_arity_1_node2_

	ldrh	r12,[r4,#-2]
	mov	r11,#258/2
	cmp	r12,r11,lsl #1
	bls	copy_record_selector_2_

	ldrh	r12,[r4,#-2+2]
	cmp	r12,#2
	bhs	copy_selector_2__

	lao	r12,heap_p1,11

	ldr	r4,[r7,#4]
	str	r7,[sp,#-4]!

	ldo	r12,r12,heap_p1,11

	ldr	r4,[r4,#8]

	sub	r4,r4,r12

	lao	r12,heap_copied_vector,6

	lsr	r7,r4,#6
	lsr	r4,r4,#3

	ldo	r12,r12,heap_copied_vector,6

	and	r7,r7,#-4
	and	r4,r4,#31

	add	r7,r7,r12

	mov	r12,#1
	lsl	r4,r12,r4

	ldr	r12,[r7]
	ands	r4,r4,r12
	ldr	r7,[sp],#4
	beq	copy_record_selector_2_
	b	copy_arity_1_node2_
copy_selector_2__:
	ldr	r4,[r7,#4]
	ldr	r4,[r4,#8]
	ldrb	r12,[r4]
	tst	r12,#1
	bne	copy_arity_1_node2_
copy_record_selector_2_:
.ifdef PIC
	add	r11,r6,#-8+4
.endif
	ldr	r4,[r6,#-8]
	lao	r12,e__system__nind,10
	ldr	r6,[r7,#4]
	otoa	r12,e__system__nind,10
	str	r12,[r7]

.ifdef PIC
	ldrh	r4,[r11,r4]
.else
	ldrh	r4,[r4,#4]
.endif
	cmp	r4,#8
	ble	copy_record_selector_3
	ldr	r6,[r6,#8]
	sub	r4,r4,#12
copy_record_selector_3:
	ldr	r6,[r6,r4]

	str	r6,[r7,#4]

	mov	r7,r6
	b	continue_after_selector_2

copy_strict_record_selector_2:
	tst	r4,#2
	beq	copy_arity_1_node2_

	ldrh	r12,[r4,#-2]
	mov	r11,#258/2
	cmp	r12,r11,lsl #1
	bls	copy_strict_record_selector_2_

	ldrh	r12,[r4,#-2+2]
	cmp	r12,#2
	blo	copy_strict_record_selector_2_b

 	ldr	r4,[r7,#4]
	ldr	r4,[r4,#8]
	ldrb	r12,[r4]
	tst	r12,#1
	bne	copy_arity_1_node2_

	b	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
	lao	r12,heap_p1,12

 	ldr	r4,[r7,#4]
	str	r7,[sp,#-4]!

	ldo	r12,r12,heap_p1,12

	ldr	r4,[r4,#8]

	sub	r4,r4,r12

	lao	r12,heap_copied_vector,7

	lsr	r7,r4,#6
	lsr	r4,r4,#3

	ldo	r12,r12,heap_copied_vector,7

	and	r7,r7,#-4
	and	r4,r4,#31

	add	r7,r7,r12

	mov	r12,#1
	lsl	r4,r12,r4

	ldr	r12,[r7]
	ands	r4,r4,r12
	ldr	r7,[sp],#4

	bne	copy_arity_1_node2_

copy_strict_record_selector_2_:
.ifdef PIC
	add	r11,r6,#-8+4
.endif
	ldr	r4,[r6,#-8]

	str	r3,[sp,#-4]!
	ldr	r6,[r7,#4]

.ifdef PIC
	ldrh	r3,[r4,r11]!
.else
	ldrh	r3,[r4,#4]
.endif
	cmp	r3,#8
	ble	copy_strict_record_selector_3
	ldr	r12,[r6,#8]
	add	r3,r3,r12
	ldr	r3,[r3,#-12]
	b	copy_strict_record_selector_4
copy_strict_record_selector_3:
	ldr	r3,[r6,r3]
copy_strict_record_selector_4:
	str	r3,[r7,#4]

.ifdef PIC
	ldrh	r3,[r4,#6-4]
.else
	ldrh	r3,[r4,#6]
.endif
	tst	r3,r3
	beq	copy_strict_record_selector_6
	cmp	r3,#8
	ble	copy_strict_record_selector_5
	ldr	r6,[r6,#8]
	sub	r3,r3,#12
copy_strict_record_selector_5:
	ldr	r3,[r6,r3]
	str	r3,[r7,#8]
copy_strict_record_selector_6:

.ifdef PIC
	ldr	r6,[r4,#-4-4]
.else
	ldr	r6,[r4,#-4]
.endif
	str	r6,[r7]
	ldr	r3,[sp],#4
	tst	r6,#2
	bne	in_hnf_2
hlt:	b	hlt

copy_arity_0_node2_:
	blt	copy_selector_2

	str	r6,[r9,#-12]!
	str	r9,[r5]
	add	r4,r9,#1

	str	r4,[r7]

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_string_or_array_2:
.ifdef DLL
	beq	copy_string_2
	laol	r12,__ARRAY__+2,__ARRAY___o_2,15
	otoa	r12,__ARRAY___o_2,15
	cmp	r6,r12
	blo	copy_normal_hnf_0_2
	mov	r6,r7
	b	copy_array_2
copy_string_2:
	mov	r6,r7
.else
	mov	r6,r7
	bne	copy_array_2
.endif
	lao	r12,heap_p1,13
	ldo	r12,r12,heap_p1,13
	sub	r7,r7,r12
	
	lao	r12,semi_space_size,1
	ldo	r12,r12,semi_space_size,1
	cmp	r7,r12
	bhs	copy_string_or_array_constant

	ldr	r7,[r6,#4]

	add	r7,r7,#3
	str	r3,[sp,#-4]!

	lsr	r4,r7,#2
	and	r7,r7,#-4

	sub	r9,r9,r7

	ldr	r3,[r6],#4

	str	r3,[r9,#-8]!

	str	r9,[r5]
	add	r7,r9,#1

	str	r7,[r6,#-4]
	add	r7,r9,#4

cp_s_arg_lp2:
	ldr	r3,[r6],#4

	str	r3,[r7],#4

	subs	r4,r4,#1
	bge	cp_s_arg_lp2

	ldr	r3,[sp],#4
	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

copy_array_2:
	lao	r12,heap_p1,14
	ldo	r12,r12,heap_p1,14
	sub	r7,r7,r12
	
	lao	r12,semi_space_size,2
	ldo	r12,r12,semi_space_size,2
	cmp	r7,r12
	bhs	copy_string_or_array_constant

	str	r3,[sp,#-4]!

	ldr	r4,[r6,#8]
	cmp	r4,#0
	beq	copy_array_a2

	ldrh	r3,[r4,#-2]

	cmp	r3,#0
	beq	copy_strict_basic_array_2

	sub	r3,r3,#256
	ldr	r12,[r6,#4]
	mul	r3,r12,r3
	b	copy_array_a3

copy_array_a2:
	ldr	r3,[r6,#4]
copy_array_a3:
	mov	r7,r10

	add	r10,r10,#12
	add	r10,r10,r3,lsl #2

	str	r7,[r5]
	ldr	r4,[r6]

	str	r4,[r7]

	add	r4,r7,#1
	add	r7,r7,#4

	str	r4,[r6],#4

	add	r4,r3,#1
	b	cp_s_arg_lp2

copy_strict_basic_array_2:
	ldr	r3,[r6,#4]
	cmp	r4,r0 @ INT+2
	beq	copy_int_array_2

	laol	r12,BOOL+2,BOOL_o_2,4
	otoa	r12,BOOL_o_2,4
	cmp	r4,r12
	beq	copy_bool_array_2

	add	r3,r3,r3
copy_int_array_2:
	add	r7,r9,#-12

	sub	r7,r7,r3,lsl #2
	ldr	r4,[r6]

	str	r7,[r5]

	mov	r9,r7

	str	r4,[r7]
	add	r4,r7,#1

	add	r7,r7,#4
	str	r4,[r6],#4

	add	r4,r3,#1
	b	cp_s_arg_lp2

copy_bool_array_2:
	add	r3,r3,#3
	lsr	r3,r3,#2
	b	copy_int_array_2

copy_string_or_array_constant:
	str	r6,[r5]

	subs	r3,r3,#1
	bne	copy_lp2
	mov	r8,r2
	b	copy_lp1

@
@	Copy all referenced nodes to the other semi space
@

copy_lp1:
	cmp	r8,r10
	bhs	end_copy1

	ldr	r4,[r8],#4
	tst	r4,#2
	beq	not_in_hnf_1
in_hnf_1:
	ldrh	r3,[r4,#-2]

	cmp	r3,#0
	beq	copy_array_21

	cmp	r3,#2
	bls	copy_lp2_lp1_all_pointers

	cmp	r3,#256
	bhs	copy_record_21

	ldr	r12,[r8,#4]
	tst	r12,#1
	bne	node_without_arguments_part

	ldr	r7,[r8],#8
	sub	r5,r8,#8
	sub	r2,r8,#4
	add	r2,r2,r3,lsl #2
	b	copy_lp2__lp1

copy_record_21:
	sub	r3,r3,#256
	subs	r3,r3,#2
	bhi	copy_record_arguments_3

	ldrh	r3,[r4,#-2+2]
	blo	copy_record_arguments_1

	add	r2,r8,#8

	cmp	r3,#1
	bhi	copy_lp2_lp1
	b	copy_node_arity1

copy_record_arguments_1:
	add	r2,r8,#4
	b	copy_lp2_lp1

copy_record_arguments_3:
	ldr	r12,[r8,#4]
	tst	r12,#1
	bne	record_node_without_arguments_part

	ldrh	r7,[r4,#-2+2]

	add	r6,r8,r3,lsl #2
	add	r2,r6,#3*4
	mov	r3,r7

	ldr	r7,[r8],#8
	sub	r5,r8,#8
	b	copy_lp2__lp1

node_without_arguments_part:
record_node_without_arguments_part:
	ldr	r7,[r8],#8
	sub	r4,r12,#1

	mov	r3,#1
	sub	r5,r8,#8
	str	r4,[r8,#-4]
	mov	r2,r8
	b	copy_lp2__lp1

not_in_hnf_1:
	ldr	r3,[r4,#-4]
	cmp	r3,#256
	bgt	copy_unboxed_closure_arguments

	cmp	r3,#1
	bgt	copy_lp2_lp1_all_pointers

copy_node_arity1:
	ldr	r7,[r8],#8
	mov	r3,#1
	sub	r5,r8,#8
	mov	r2,r8
	b	copy_lp2__lp1

copy_unboxed_closure_arguments:
	ldr	r12,=257
	cmp	r3,r12
	beq	copy_unboxed_closure_arguments1

	uxtb	r4,r3,ror #8
	and	r2,r3,#255

	subs	r3,r2,r4
	add	r2,r8,r2,lsl #2
	bne	copy_lp2_lp1

copy_unboxed_closure_arguments_without_pointers:
	mov	r8,r2
	b	copy_lp1

copy_unboxed_closure_arguments1:
	add	r8,r8,#8
	b	copy_lp1

copy_array_21:
	ldr	r3,[r8,#4]
	add	r8,r8,#8
	cmp	r3,#0
	beq	copy_array_21_a

	ldrh	r4,[r3,#-2]
	ldrh	r3,[r3,#-2+2]
	sub	r4,r4,#256
	cmp	r3,#0
	beq	copy_array_21_b

	cmp	r3,r4
	bne	copy_array_21_ab

copy_array_21_r_a:
	ldr	r3,[r8,#-8]
	mul	r3,r4,r3
	cmp	r3,#0
	beq	copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_a:
	ldr	r3,[r8,#-8]
	cmp	r3,#0
	beq	copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_b:
	ldr	r3,[r8,#-8]
	mul	r3,r4,r3
	add	r8,r8,r3,lsl #2
	b	copy_lp1

copy_array_21_ab:
	ldr	r12,[r8,#-8]
	cmp	r12,#0
	beq	copy_lp1

	str	r12,[sp,#0]
	lsl	r4,r4,#2
	str	r3,[sp,#8]
	str	r4,[sp,#4]

copy_array_21_lp_ab:
	add	r2,r8,r4
	str	r2,[sp,#12]
	mov	r2,#-1
	b	copy_lp2

end_copy1:
	cmp	r8,#-1
	bxne	lr

copy_array_21_lp_ab_next:
	ldr	r8,[sp,#12]
	ldr	r12,[sp]
	ldr	r3,[sp,#8]
	ldr	r4,[sp,#4]
	subs	r12,r12,#1
	str	r12,[sp]
	bne	copy_array_21_lp_ab

	b	copy_lp1

.ifdef PIC
	lto	small_integers,1
	lto	static_characters,1
	ltol	__STRING__+2,__STRING___o_2,7
	lto	heap_p1,9
	lto	heap_copied_vector,4
	lto	heap_p1,10
	lto	heap_copied_vector,5
	lto	e__system__nind,8
	lto	e__system__nind,9
	lto	heap_p1,11
	lto	heap_copied_vector,6
	lto	e__system__nind,10
	lto	heap_p1,12
	lto	heap_copied_vector,7
 .ifdef DLL
 	ltol	__ARRAY__+2,__ARRAY___o_2,15
 .endif
	lto	heap_p1,13
	lto	semi_space_size,1
	lto	heap_p1,14
	lto	semi_space_size,2
	ltol	BOOL+2,BOOL_o_2,4
.endif

	.ltorg

skip_copy_gc:
