
ZERO_ARITY_DESCRIPTOR_OFFSET = -4
COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP = 1

	push	{r5}

	lao	r7,heap_p2,9
	ldo	r6,r7,heap_p2,9

	lao	r7,heap_size_129,4
	ldo	r1,r7,heap_size_129,4
	lsl	r1,r1,#6

	lao	r7,semi_space_size,0
	sto	r1,r7,semi_space_size,0

	add	r5,r6,r1

@ r8 = INT+2
@ r9 = CHAR+2
	laol	r8,INT+2,INT_o_2,6
	laol	r9,CHAR+2,CHAR_o_2,2
	otoa	r8,INT_o_2,6
	otoa	r9,CHAR_o_2,2

.if WRITE_HEAP
	laol	r7,heap2_begin_and_end+4,heap2_begin_and_end_o_4,0
	sto	r5,r7,heap2_begin_and_end_o_4,0
.endif

	sub	sp,sp,#16

	lao	r7,caf_list,0
	ldo	r1,r7,caf_list,0
	tst	r1,r1
	beq	end_copy_cafs

copy_cafs_lp:
	ldr	r7,[r1,#-4]
	push	{r7}

	add	r4,r1,#4
	ldr	r0,[r1]
	mov	r10,#-2
	bl	copy_lp2

	pop	{r1}
	cmp	r1,#0
	bne	copy_cafs_lp

end_copy_cafs:
	ldr	r0,[sp,#16]
	lao	r7,stack_p,4
	ldo	r4,r7,stack_p,4
	sub	r0,r0,r4
	lsr	r0,r0,#2

	cmp	r0,#0
	beq	end_copy0
	mov	r10,#-2
	bl	copy_lp2
end_copy0:
	lao	r7,heap_p2,10
	ldo	r4,r7,heap_p2,10

	bl	copy_lp1

	add	sp,sp,#16

	lao	r7,heap_end_after_gc,10
	sto	r5,r7,heap_end_after_gc,10

.ifdef FINALIZERS
	lao	r2,finalizer_list,1
	lao	r3,free_finalizer_list,3
	otoa	r2,finalizer_list,1
	otoa	r3,free_finalizer_list,3
	ldr	r4,[r2]

determine_free_finalizers_after_copy:
	ldr	r1,[r4]
	tst	r1,#3
	bne	finalizer_not_used_after_copy

	ldr	r4,[r4,#4]
	str	r1,[r2]
	add	r2,r1,#4
	b	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	laol	r7,__Nil-4,__Nil_o_m4,3
	otoa	r7,__Nil_o_m4,3
	cmp	r4,r7
	beq	end_finalizers_after_copy

	str	r4,[r3]
	add	r3,r4,#4
	ldr	r4,[r4,#4]
	b	determine_free_finalizers_after_copy	

end_finalizers_after_copy:
	str	r4,[r2]
	str	r4,[r3]
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
	add	r10,r4,r0,lsl #2

copy_lp2_lp1:
copy_lp2:
	ldr	r3,[r4],#4
	sub	r11,r4,#4

copy_lp2__lp1:
copy_lp2_:
@ selectors:
continue_after_selector_2:
	ldr	r2,[r3]
	tst	r2,#2
	beq	not_in_hnf_2

in_hnf_2:
	ldrh	r1,[r2,#-2]
	cmp	r1,#0
	beq	copy_arity_0_node2

	cmp	r1,#256
	bhs	copy_record_2

	subs	r1,r1,#2
	str	r6,[r11]
	bhi	copy_hnf_node2_3

	str	r2,[r6]
	blo	copy_hnf_node2_1

	ldr	r2,[r3,#4]

	str	r6,[r3]
	ldr	r1,[r3,#8]

	subs	r0,r0,#1
	str	r2,[r6,#4]

	str	r1,[r6,#8]
	add	r6,r6,#12

	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_hnf_node2_1:
	ldr	r1,[r3,#4]

	subs	r0,r0,#1
	str	r6,[r3]

	str	r1,[r6,#4]
	add	r6,r6,#8

	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_hnf_node2_3:
	str	r2,[r6]

	str	r6,[r3]
	ldr	r2,[r3,#4]

	str	r2,[r6,#4]
	ldr	r2,[r3,#8]

	add	r6,r6,#12
	ldr	r3,[r2]

	tst	r3,#1
	bne	arguments_already_copied_2

	str	r6,[r6,#-4]

	str	r3,[r6],#1

	str	r6,[r2],#4
	add	r6,r6,#4-1

cp_hnf_arg_lp2:
	ldr	r3,[r2],#4
	str	r3,[r6],#4
	subs	r1,r1,#1
	bne	cp_hnf_arg_lp2

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

arguments_already_copied_2:
	str	r3,[r6,#-4]

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_arity_0_node2:
	cmp	r2,r8 @ INT+2
	blo	copy_real_file_or_string_2

	cmp	r2,r9 @ CHAR+2
	bhi	copy_normal_hnf_0_2

copy_int_bool_or_char_2:
	ldr	r1,[r3,#4]
	beq	copy_char_2

	cmp	r2,r8 @ INT+2
	bne	no_small_int_or_char_2

copy_int_2:
	cmp	r1,#33
	bhs	no_small_int_or_char_2

	lao	r7,small_integers,1
	subs	r0,r0,#1
	otoa	r7,small_integers,1

	add	r1,r7,r1,lsl #3

	str	r1,[r11]
	bne	copy_lp2

	mov	r4,r10
	b	copy_lp1

copy_char_2:
	and	r1,r1,#255

	lao	r7,static_characters,1
	subs	r0,r0,#1
	otoa	r7,static_characters,1

	add	r1,r7,r1,lsl #3

	str	r1,[r11]
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

no_small_int_or_char_2:
copy_record_node2_1_b:
	str	r1,[r5,#-4]
	str	r2,[r5,#-8]!

	str	r5,[r3]

	str	r5,[r11]

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_normal_hnf_0_2:
	sub	r2,r2,#2-ZERO_ARITY_DESCRIPTOR_OFFSET
	subs	r0,r0,#1

	str	r2,[r11]
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_real_file_or_string_2:
	laol	r7,__STRING__+2,__STRING___o_2,7
	otoa	r7,__STRING___o_2,7
	cmp	r2,r7
	bls	copy_string_or_array_2

copy_real_or_file_2:
	str	r2,[r5,#-12]!

	ldr	r1,[r3,#4]
	ldr	r2,[r3,#8]

	str	r5,[r3]

	str	r5,[r11]

	str	r1,[r5,#4]
	subs	r0,r0,#1

	str	r2,[r5,#8]

	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

already_copied_2:
	subs	r0,r0,#1

	str	r2,[r11]

	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_record_2:
	ldrh	r7,[r2,#-2+2]
	sub	r1,r1,#256
	subs	r1,#2
	bhi	copy_record_node2_3
	blo	copy_record_node2_1

	cmp	r7,#0
	beq	copy_real_or_file_2

	str	r6,[r11]
	str	r2,[r6]

	ldr	r1,[r3,#4]

	str	r6,[r3]

	str	r1,[r6,#4]
	ldr	r1,[r3,#8]

	str	r1,[r6,#8]

	add	r6,r6,#12	
	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_record_node2_1:
	ldr	r1,[r3,#4]

	cmp	r7,#0
	beq	copy_record_node2_1_b

	str	r6,[r11]
	str	r2,[r6]

	str	r1,[r6,#4]

	str	r6,[r3]

	add	r6,r6,#8
	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_record_node2_3:
	cmp	r7,#1
	bls	copy_record_node2_3_ab_or_b

	push	{r1}

	str	r6,[r3]
	ldr	r1,[r3,#8]

	str	r2,[r6]
	ldr	r3,[r3,#4]

	str	r3,[r6,#4]
	str	r6,[r11]

	ldr	r7,[r1]
	mov	r2,r1
	tst	r7,#1
	bne	record_arguments_already_copied_2

	add	r3,r6,#12

	pop	{r1}
	str	r3,[r6,#8]

	add	r6,r6,#13
	ldr	r3,[r2]

	str	r6,[r2],#4

	str	r3,[r6,#-1]
	add	r6,r6,#3

cp_record_arg_lp2:
	ldr	r3,[r2],#4

	str	r3,[r6],#4

	subs	r1,r1,#1
	bne	cp_record_arg_lp2

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

record_arguments_already_copied_2:
	ldr	r3,[r2]
	pop	{r1}

	str	r3,[r6,#8]
	add	r6,r6,#12

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_record_node2_3_ab_or_b:
	blo	copy_record_node2_3_b

copy_record_node2_3_ab:
	push	{r1}

	lao	r7,heap_p1,9

	str	r6,[r3]
	ldr	r1,[r3,#8]

	ldo	r7,r7,heap_p1,9

	str	r2,[r6]
	ldr	r3,[r3,#4]

	mov	r2,r1
	sub	r1,r1,r7

	lao	r7,heap_copied_vector,4

	str	r3,[r6,#4]

	lsr	r3,r1,#6
	lsr	r1,r1,#3

	and	r1,r1,#31

	ldo	r7,r7,heap_copied_vector,4
	and	r3,r3,#-4

	str	r6,[r11]

	add	r3,r3,r7

	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r3]
	tst	r1,r7
	bne	record_arguments_already_copied_2

	orr	r7,r7,r1
	str	r7,[r3]
	pop	{r1}

	sub	r5,r5,#4

	lsl	r1,r1,#2
	sub	r5,r5,r1

	push	{r5}
	add	r5,r5,#1

	str	r5,[r6,#8]
	add	r6,r6,#12

	ldr	r3,[r2]
	b	cp_record_arg_lp3_c

copy_record_node2_3_b:
	push	{r1}
	add	r1,r5,#-12

	lao	r7,heap_p1,10

	str	r1,[r3]
	ldr	r1,[r3,#8]

	ldo	r7,r7,heap_p1,10

	str	r2,[r5,#-12]
	ldr	r3,[r3,#4]

	mov	r2,r1
	sub	r1,r1,r7

	lao	r7,heap_copied_vector,5

	str	r3,[r5,#-8]

	lsr	r3,r1,#6
	sub	r5,r5,#12
	lsr	r1,r1,#3

	and	r1,r1,#31

	ldo	r7,r7,heap_copied_vector,5
	and	r3,r3,#-4

	str	r5,[r11]

	add	r3,r3,r7

	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r3]
	tst	r1,r7
	bne	record_arguments_already_copied_3_b

	orr	r7,r7,r1
	str	r7,[r3]
	pop	{r1}

	mov	r3,r5
	sub	r5,r5,#4

	lsl	r1,r1,#2
	sub	r5,r5,r1

	str	r5,[r3,#8]

	ldr	r3,[r2]

	push	{r5}
	add	r5,r5,#1

cp_record_arg_lp3_c:
	str	r5,[r2],#4

	str	r3,[r5,#-1]
	add	r5,r5,#3

cp_record_arg_lp3:
	ldr	r3,[r2],#4

	str	r3,[r5],#4

	subs	r1,r1,#4
	bne	cp_record_arg_lp3

	pop	{r5}

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

record_arguments_already_copied_3_b:
	ldr	r3,[r2]
	pop	{r1}

	sub	r3,r3,#1
	str	r3,[r5,#8]

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

not_in_hnf_2:
	tst	r2,#1
	beq	already_copied_2

	ldr	r1,[r2,#-1-4]
	cmp	r1,#0
	ble	copy_arity_0_node2_

copy_node2_1_:
	and	r1,r1,#255
	subs	r1,r1,#2
	blt	copy_arity_1_node2
copy_node2_3:
	str	r6,[r11]
	str	r2,[r6]
	str	r6,[r3]
	ldr	r2,[r3,#4]
	add	r3,r3,#8
	str	r2,[r6,#4]
	add	r6,r6,#8

cp_arg_lp2:
	ldr	r2,[r3],#4
	str	r2,[r6],#4
	subs	r1,r1,#1
	bhs	cp_arg_lp2

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_arity_1_node2__:
	pop	{r0}
copy_arity_1_node2:
copy_arity_1_node2_:
	str	r6,[r11]
	str	r6,[r3]

	ldr	r1,[r3,#4]
	str	r2,[r6]

	str	r1,[r6,#4]
	add	r6,r6,#12

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_indirection_2:
	mov	r1,r3
	ldr	r3,[r3,#4]

	ldr	r2,[r3]
	tst	r2,#2
	bne	in_hnf_2

	tst	r2,#1
	beq	already_copied_2

	ldr	r7,[r2,#-1-4]
	cmp	r7,#-2
	beq	skip_indirections_2

	movs	r1,r7
	ble	copy_arity_0_node2_
	b	copy_node2_1_

skip_indirections_2:
	ldr	r3,[r3,#4]

	ldr	r2,[r3]
	tst	r2,#2
	bne	update_indirection_list_2
	tst	r2,#1
	beq	update_indirection_list_2

	ldr	r7,[r2,#-1-4]
	cmp	r7,#-2
	beq	skip_indirections_2

update_indirection_list_2:
	add	r2,r1,#4
	ldr	r1,[r1,#4]
	str	r3,[r2]
	cmp	r3,r1
	bne	update_indirection_list_2

	b	continue_after_selector_2

copy_selector_2:
	cmp	r1,#-2
	beq	copy_indirection_2
	blt	copy_record_selector_2

	ldr	r1,[r3,#4]

	push	{r0}

	ldr	r0,[r1]
 	tst	r0,#2
	beq	copy_arity_1_node2__

	ldrh	r7,[r0,#-2]
	cmp	r7,#2
	bls	copy_selector_2_

	ldr	r0,[r1,#8]
	ldrb	r7,[r0]
	tst	r7,#1
	bne	copy_arity_1_node2__

.ifdef PIC
	add	r12,r2,#-8+4
.endif
	ldr	r2,[r2,#-1-8]
	lao	r7,e__system__nind,8
.ifdef PIC
	ldrh	r2,[r12,r2]
.else
	ldrh	r2,[r2,#4]
.endif
	otoa	r7,e__system__nind,8
	str	r7,[r3]

	cmp	r2,#8
	blt	copy_selector_2_1
	beq	copy_selector_2_2

	sub	r0,r0,#12
	ldr	r2,[r2,r0]
	pop	{r0}
	str	r2,[r3,#4]
	mov	r3,r2
	b	continue_after_selector_2

copy_selector_2_1:
	ldr	r2,[r1,#4]
	pop	{r0}
	str	r2,[r3,#4]
	mov	r3,r2
	b	continue_after_selector_2

copy_selector_2_2:
	ldr	r2,[r0]
	pop	{r0}
	str	r2,[r3,#4]
	mov	r3,r2
	b	continue_after_selector_2

copy_selector_2_:
.ifdef PIC
	add	r12,r2,#-8+4
.endif
	ldr	r2,[r2,#-1-8]
	pop	{r0}

	lao	r7,e__system__nind,9
.ifdef PIC
	ldrh	r2,[r12,r2]
.else
	ldrh	r2,[r2,#4]
.endif
	otoa	r7,e__system__nind,9
	str	r7,[r3]

	ldr	r2,[r1,r2]
	str	r2,[r3,#4]
	mov	r3,r2
	b	continue_after_selector_2

copy_record_selector_2:
	cmp	r1,#-3
	ldr	r1,[r3,#4]
	ldr	r1,[r1]
	beq	copy_strict_record_selector_2

 	tst	r1,#2
	beq	copy_arity_1_node2_

	ldrh	r7,[r1,#-2]
	cmp	r7,#258
	bls	copy_record_selector_2_

	ldrh	r7,[r1,#-2+2]
	cmp	r7,#2
	bhs	copy_selector_2__

	lao	r7,heap_p1,11

	ldr	r1,[r3,#4]
	push	{r3}

	ldo	r7,r7,heap_p1,11

	ldr	r1,[r1,#8]

	sub	r1,r1,r7

	lao	r7,heap_copied_vector,6

	lsr	r3,r1,#6
	lsr	r1,r1,#3

	ldo	r7,r7,heap_copied_vector,6

	and	r3,r3,#-4
	and	r1,r1,#31

	add	r3,r3,r7

	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r3]
	ands	r1,r1,r7
	pop	{r3}
	beq	copy_record_selector_2_
	b	copy_arity_1_node2_
copy_selector_2__:
	ldr	r1,[r3,#4]
	ldr	r1,[r1,#8]
	ldrb	r7,[r1]
	tst	r7,#1
	bne	copy_arity_1_node2_
copy_record_selector_2_:
.ifdef PIC
	add	r12,r2,#-8+4
.endif
	ldr	r1,[r2,#-1-8]
	lao	r7,e__system__nind,10
	ldr	r2,[r3,#4]
	otoa	r7,e__system__nind,10
	str	r7,[r3]

.ifdef PIC
	ldrh	r1,[r12,r1]
.else
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	ble	copy_record_selector_3
	ldr	r2,[r2,#8]
	sub	r1,r1,#12
copy_record_selector_3:
	ldr	r2,[r2,r1]

	str	r2,[r3,#4]

	mov	r3,r2
	b	continue_after_selector_2

copy_strict_record_selector_2:
	tst	r1,#2
	beq	copy_arity_1_node2_

	ldrh	r7,[r1,#-2]
	cmp	r7,#258
	bls	copy_strict_record_selector_2_

	ldrh	r7,[r1,#-2+2]
	cmp	r7,#2
	blo	copy_strict_record_selector_2_b

 	ldr	r1,[r3,#4]
	ldr	r1,[r1,#8]
	ldrb	r7,[r1]
	tst	r7,#1
	bne	copy_arity_1_node2_

	b	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
	lao	r7,heap_p1,12

 	ldr	r1,[r3,#4]
	push	{r3}

	ldo	r7,r7,heap_p1,12

	ldr	r1,[r1,#8]

	sub	r1,r1,r7

	lao	r7,heap_copied_vector,7

	lsr	r3,r1,#6
	lsr	r1,r1,#3

	ldo	r7,r7,heap_copied_vector,7

	and	r3,r3,#-4
	and	r1,r1,#31

	add	r3,r3,r7

	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r3]
	ands	r1,r1,r7
	pop	{r3}

	bne	copy_arity_1_node2_

copy_strict_record_selector_2_:
.ifdef PIC
	add	r12,r2,#-8+4
.endif
	ldr	r1,[r2,#-1-8]

	push	{r0}
	ldr	r2,[r3,#4]

.ifdef PIC
	ldrh	r0,[r1,r12]!
.else
	ldrh	r0,[r1,#4]
.endif
	cmp	r0,#8
	ble	copy_strict_record_selector_3
	ldr	r7,[r2,#8]
	add	r0,r0,r7
	ldr	r0,[r0,#-12]
	b	copy_strict_record_selector_4
copy_strict_record_selector_3:
	ldr	r0,[r2,r0]
copy_strict_record_selector_4:
	str	r0,[r3,#4]

.ifdef PIC
	ldrh	r0,[r1,#6-4]
.else
	ldrh	r0,[r1,#6]
.endif
	tst	r0,r0
	beq	copy_strict_record_selector_6
	cmp	r0,#8
	ble	copy_strict_record_selector_5
	ldr	r2,[r2,#8]
	sub	r0,r0,#12
copy_strict_record_selector_5:
	ldr	r0,[r2,r0]
	str	r0,[r3,#8]
copy_strict_record_selector_6:

.ifdef PIC
	ldr	r2,[r1,#-4-4]
.else
	ldr	r2,[r1,#-4]
.endif
	str	r2,[r3]
	pop	{r0}
	tst	r2,#2
	bne	in_hnf_2
hlt:	b	hlt

copy_arity_0_node2_:
	blt	copy_selector_2

	str	r2,[r5,#-12]!
	str	r5,[r11]
	str	r5,[r3]

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_string_or_array_2:
.ifdef DLL
	beq	copy_string_2
	laol	r7,__ARRAY__+2,__ARRAY___o_2,15
	otoa	r7,__ARRAY___o_2,15
	cmp	r2,r7
	blo	copy_normal_hnf_0_2
	mov	r2,r3
	b	copy_array_2
copy_string_2:
	mov	r2,r3
.else
	mov	r2,r3
	bne	copy_array_2
.endif
	lao	r7,heap_p1,13
	ldo	r7,r7,heap_p1,13
	sub	r3,r3,r7
	
	lao	r7,semi_space_size,1
	ldo	r7,r7,semi_space_size,1
	cmp	r3,r7
	bhs	copy_string_or_array_constant

	ldr	r3,[r2,#4]

	add	r3,r3,#3
	push	{r0}

	lsr	r1,r3,#2
	and	r3,r3,#-4

	sub	r5,r5,r3

	ldr	r0,[r2],#4

	str	r0,[r5,#-8]!

	str	r5,[r11]
	str	r5,[r2,#-4]
	add	r3,r5,#4

cp_s_arg_lp2:
	ldr	r0,[r2],#4

	str	r0,[r3],#4

	subs	r1,r1,#1
	bge	cp_s_arg_lp2

	pop	{r0}
	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

copy_array_2:
	lao	r7,heap_p1,14
	ldo	r7,r7,heap_p1,14
	sub	r3,r3,r7
	
	lao	r7,semi_space_size,2
	ldo	r7,r7,semi_space_size,2
	cmp	r3,r7
	bhs	copy_string_or_array_constant

	push	{r0}

	ldr	r1,[r2,#8]
	cmp	r1,#0
	beq	copy_array_a2

	ldrh	r0,[r1,#-2]

	cmp	r0,#0
	beq	copy_strict_basic_array_2

	sub	r0,r0,#256
	ldr	r7,[r2,#4]
	mul	r0,r7,r0
	b	copy_array_a3

copy_array_a2:
	ldr	r0,[r2,#4]
copy_array_a3:
	mov	r3,r6

	add	r6,r6,#12
	add	r6,r6,r0,lsl #2

	str	r3,[r11]
	ldr	r1,[r2]

	str	r1,[r3]

	str	r3,[r2],#4
	add	r3,r3,#4

	add	r1,r0,#1
	b	cp_s_arg_lp2

copy_strict_basic_array_2:
	ldr	r0,[r2,#4]
	cmp	r1,r8 @ INT+2
	beq	copy_int_array_2

	laol	r7,BOOL+2,BOOL_o_2,4
	otoa	r7,BOOL_o_2,4
	cmp	r1,r7
	beq	copy_bool_array_2

	add	r0,r0,r0
copy_int_array_2:
	add	r3,r5,#-12

	sub	r3,r3,r0,lsl #2
	ldr	r1,[r2]

	str	r3,[r11]

	mov	r5,r3

	str	r1,[r3]

	str	r3,[r2],#4
	add	r3,r3,#4

	add	r1,r0,#1
	b	cp_s_arg_lp2

copy_bool_array_2:
	add	r0,r0,#3
	lsr	r0,r0,#2
	b	copy_int_array_2

copy_string_or_array_constant:
	str	r2,[r11]

	subs	r0,r0,#1
	bne	copy_lp2
	mov	r4,r10
	b	copy_lp1

@
@	Copy all referenced nodes to the other semi space
@

copy_lp1:
	cmp	r4,r6
	bhs	end_copy1

	ldr	r1,[r4],#4
	tst	r1,#2
	beq	not_in_hnf_1
in_hnf_1:
	ldrh	r0,[r1,#-2]

	cmp	r0,#0
	beq	copy_array_21

	cmp	r0,#2
	bls	copy_lp2_lp1_all_pointers

	cmp	r0,#256
	bhs	copy_record_21

	ldr	r7,[r4,#4]
	tst	r7,#1
	bne	node_without_arguments_part

	ldr	r3,[r4],#8
	sub	r11,r4,#8
	sub	r10,r4,#4
	add	r10,r10,r0,lsl #2
	b	copy_lp2__lp1

copy_record_21:
	sub	r0,r0,#256
	subs	r0,r0,#2
	bhi	copy_record_arguments_3

	ldrh	r0,[r1,#-2+2]
	blo	copy_record_arguments_1

	add	r10,r4,#8

	cmp	r0,#1
	bhi	copy_lp2_lp1
	b	copy_node_arity1

copy_record_arguments_1:
	add	r10,r4,#4
	b	copy_lp2_lp1

copy_record_arguments_3:
	ldr	r7,[r4,#4]
	tst	r7,#1
	bne	record_node_without_arguments_part

	ldrh	r3,[r1,#-2+2]

	add	r2,r4,r0,lsl #2
	add	r10,r2,#3*4
	mov	r0,r3

	ldr	r3,[r4],#8
	sub	r11,r4,#8
	b	copy_lp2__lp1

node_without_arguments_part:
record_node_without_arguments_part:
	ldr	r3,[r4],#8
	sub	r1,r7,#1

	mov	r0,#1
	sub	r11,r4,#8
	str	r1,[r4,#-4]
	mov	r10,r4
	b	copy_lp2__lp1

not_in_hnf_1:
	ldr	r0,[r1,#-1-4]
	cmp	r0,#256
	bgt	copy_unboxed_closure_arguments

	cmp	r0,#1
	bgt	copy_lp2_lp1_all_pointers

copy_node_arity1:
	ldr	r3,[r4],#8
	mov	r0,#1
	sub	r11,r4,#8
	mov	r10,r4
	b	copy_lp2__lp1

copy_unboxed_closure_arguments:
	ldr	r7,=257
	cmp	r0,r7
	beq	copy_unboxed_closure_arguments1

	uxtb	r1,r0,ror #8
	and	r10,r0,#255

	subs	r0,r10,r1
	add	r10,r4,r10,lsl #2
	bne	copy_lp2_lp1

copy_unboxed_closure_arguments_without_pointers:
	mov	r4,r10
	b	copy_lp1

copy_unboxed_closure_arguments1:
	add	r4,r4,#8
	b	copy_lp1

copy_array_21:
	ldr	r0,[r4,#4]
	add	r4,r4,#8
	cmp	r0,#0
	beq	copy_array_21_a

	ldrh	r1,[r0,#-2]
	ldrh	r0,[r0,#-2+2]
	sub	r1,r1,#256
	cmp	r0,#0
	beq	copy_array_21_b

	cmp	r0,r1
	bne	copy_array_21_ab

copy_array_21_r_a:
	ldr	r0,[r4,#-8]
	mul	r0,r1,r0
	cmp	r0,#0
	beq	copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_a:
	ldr	r0,[r4,#-8]
	cmp	r0,#0
	beq	copy_lp1
	b	copy_lp2_lp1_all_pointers

copy_array_21_b:
	ldr	r0,[r4,#-8]
	mul	r0,r1,r0
	add	r4,r4,r0,lsl #2
	b	copy_lp1

copy_array_21_ab:
	ldr	r7,[r4,#-8]
	cmp	r7,#0
	beq	copy_lp1

	str	r7,[sp,#0]
	lsl	r1,r1,#2
	str	r0,[sp,#8]
	str	r1,[sp,#4]

copy_array_21_lp_ab:
	add	r10,r4,r1
	str	r10,[sp,#12]
	mov	r10,#-1
	b	copy_lp2

end_copy1:
	cmp	r4,#-1
	it	ne
	bxne	lr

copy_array_21_lp_ab_next:
	ldr	r4,[sp,#12]
	ldr	r7,[sp]
	ldr	r0,[sp,#8]
	ldr	r1,[sp,#4]
	subs	r7,r7,#1
	str	r7,[sp]
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
