
ZERO_ARITY_DESCRIPTOR_OFFSET = -4
NO_BIT_INSTRUCTIONS = 1

rmark_using_reversal:
	str	r9,[sp,#-4]!
	str	r9,[sp,#-4]!
	mov	r9,#1
	b	rmarkr_node

rmark_using_reversal_:
	subs	r6,r6,#4
	str	r3,[sp,#-4]!
	str	r9,[sp,#-4]!
	cmp	r6,r3
	bhi	rmark_no_undo_reverse_1
	str	r6,[r9]
	str	r4,[r6]
rmark_no_undo_reverse_1:
	mov	r9,#1
	b	rmarkr_arguments

rmark_array_using_reversal:
	str	r3,[sp,#-4]!
	str	r9,[sp,#-4]!
	cmp	r6,r3
	bhi	rmark_no_undo_reverse_2
	str	r6,[r9]
	laol	r12,__ARRAY__+2,__ARRAY___o_2,18
	otoa	r12,__ARRAY___o_2,18
	str	r12,[r6]
rmark_no_undo_reverse_2:
	mov	r9,#1
	b	rmarkr_arguments

rmarkr_hnf_2:
	ldr	r12,[r6]
	orr	r12,r12,#2
	str	r12,[r6]
	ldr	r8,[r6,#4]
	str	r9,[r6,#4]
	add	r9,r6,#4
	mov	r6,r8

rmarkr_node:
	sub	r4,r6,r11
	cmp	r4,r2
	bhs	rmarkr_next_node_after_static

	lsr	r3,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r8,[r10,r3,lsl #2]
	tst	r8,r4
	bne	rmarkr_next_node

	orr	r8,r8,r4
	str	r8,[r10,r3,lsl #2]

rmarkr_arguments:
	ldr	r4,[r6]
	tst	r4,#2
	beq	rmarkr_lazy_node

	ldrh	r8,[r4,#-2]
	tst	r8,r8
	beq	rmarkr_hnf_0

	add	r6,r6,#4

	cmp	r8,#256
	bhs	rmarkr_record

	subs	r8,r8,#2
	beq	rmarkr_hnf_2
	blo	rmarkr_hnf_1

rmarkr_hnf_3:
	ldr	r7,[r6,#4]

	sub	r4,r7,r11

	lsr	r3,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r3,lsl #2]
	tst	r4,r12
	bne	rmarkr_shared_argument_part

	orr	r12,r12,r4	
	str	r12,[r10,r3,lsl #2]	

rmarkr_no_shared_argument_part:
	ldr	r12,[r6]
	orr	r12,r12,#2
	str	r12,[r6]
	str	r9,[r6,#4]
	add	r6,r6,#4

	ldr	r12,[r7]
	orr	r12,r12,#1
	str	r12,[r7]
	add	r7,r7,r8,lsl #2

	ldr	r8,[r7]
	str	r6,[r7]
	mov	r9,r7
	mov	r6,r8
	b	rmarkr_node

rmarkr_shared_argument_part:
	cmp	r7,r6
	bhi	rmarkr_hnf_1

	ldr	r3,[r7]
	add	r4,r6,#4+2+1
	str	r4,[r7]
	str	r3,[r6,#4]
	b	rmarkr_hnf_1

rmarkr_record:
	mov	r12,#258/2
	subs	r8,r8,r12,lsl #1
	beq	rmarkr_record_2
	blo	rmarkr_record_1

rmarkr_record_3:
	ldrh	r8,[r4,#-2+2]
	subs	r8,r8,#1
	blo	rmarkr_record_3_bb
	beq	rmarkr_record_3_ab
	subs	r8,r8,#1
	beq	rmarkr_record_3_aab
	b	rmarkr_hnf_3

rmarkr_record_3_bb:
	ldr	r7,[r6,#8-4]
	subs	r6,r6,#4

	sub	r4,r7,r11

	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	cmp	r7,r6
	bhi	rmarkr_next_node

	adds	r4,r4,r4
	bne	rmarkr_bit_in_same_word1
	add	r8,r8,#1
	mov	r4,#1
rmarkr_bit_in_same_word1:
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	beq	rmarkr_not_yet_linked_bb

	sub	r4,r6,r11

	add	r4,r4,#2*4
	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
rmarkr_not_yet_linked_bb:
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	ldr	r8,[r7]
	add	r4,r6,#8+2+1
	str	r8,[r6,#8]
	str	r4,[r7]
	b	rmarkr_next_node

rmarkr_record_3_ab:
	ldr	r7,[r6,#4]

	sub	r4,r7,r11

	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	cmp	r7,r6
	bhi	rmarkr_hnf_1

	adds	r4,r4,r4
	bne	rmarkr_bit_in_same_word2
	add	r8,r8,#1
	mov	r4,#1
rmarkr_bit_in_same_word2:
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	beq	rmarkr_not_yet_linked_ab

	sub	r4,r6,r11

	add	r4,r4,#4
	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
rmarkr_not_yet_linked_ab: 
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	ldr	r8,[r7]
	add	r4,r6,#4+2+1
	str	r8,[r6,#4]
	str	r4,[r7]
	b	rmarkr_hnf_1

rmarkr_record_3_aab:
	ldr	r7,[r6,#4]

	sub	r4,r7,r11

	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	bne	rmarkr_shared_argument_part
	ldr	r12,[r10,r8,lsl #2]
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	ldr	r12,[r6]
	add	r12,r12,#2
	str	r12,[r6]
	str	r9,[r6,#4]
	add	r6,r6,#4

	ldr	r9,[r7]
	str	r6,[r7]
	mov	r6,r9
	add	r9,r7,#1
	b	rmarkr_node

rmarkr_record_2:
	ldrh	r12,[r4,#-2+2]
	cmp	r12,#1
	bhi	rmarkr_hnf_2
	beq	rmarkr_hnf_1
	subs	r6,r6,#4
	b	rmarkr_next_node

rmarkr_record_1:
	ldrh	r12,[r4,#-2+2]
	cmp	r12,#0
	bne	rmarkr_hnf_1
	subs	r6,r6,#4
	b	rmarkr_next_node

rmarkr_lazy_node_1:
@ selectors:
	bne	rmarkr_selector_node_1

rmarkr_hnf_1:
	ldr	r8,[r6]
	str	r9,[r6]

	add	r9,r6,#2
	mov	r6,r8
	b	rmarkr_node

@ selectors
rmarkr_indirection_node:
	add	r12,r6,#-4
	sub	r3,r12,r11

	and	r4,r3,#31*4
	lsr	r3,r3,#7
	lsr	r12,r4,#2
	mov	r4,#1
	lsl	r4,r4,r12
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r4
	str	r12,[r10,r3,lsl #2]

	ldr	r6,[r6]
	b	rmarkr_node

rmarkr_selector_node_1:
	cmp	r8,#(-2)-1
	beq	rmarkr_indirection_node

	ldr	r7,[r6]

	sub	r3,r7,r11
	lsr	r3,r3,#2

	cmp	r8,#(-3)-1
	ble	rmarkr_record_selector_node_1

	str	r4,[sp,#-4]!
	and	r4,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmarkr_hnf_1

	ldrh	r12,[r3,#-2]
	cmp	r12,#2
	bls	rmarkr_small_tuple_or_record

rmarkr_large_tuple_or_record:
	ldr	r3,[r7,#8]
	sub	r3,r3,r11
	lsr	r3,r3,#2

	str	r4,[sp,#-4]!
	and	r4,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

	add	r12,r6,#-4
	sub	r3,r12,r11

	str	r6,[sp,#-4]!

.ifdef PIC
	add	r12,r4,#-8+4
.endif
	ldr	r4,[r4,#-8]

	and	r6,r3,#31*4
	lsr	r3,r3,#7
	lsr	r6,r6,#2
.ifdef PIC
	ldrh	r4,[r12,r4]
.endif
	mov	r12,#1
	lsl	r6,r12,r6
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r6
	str	r12,[r10,r3,lsl #2]

.ifndef PIC
	ldrh	r4,[r4,#4]
.endif
	cmp	r4,#8
	blt	rmarkr_tuple_or_record_selector_node_2
	ldr	r7,[r7,#8]
	beq	rmarkr_tuple_selector_node_2
	add	r12,r4,#-12
	ldr	r6,[r7,r12]
	ldr	r7,[sp],#4
	lao	r12,e__system__nind,20
	otoa	r12,e__system__nind,20
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmarkr_node

rmarkr_tuple_selector_node_2:
	ldr	r6,[r7]
	ldr	r7,[sp],#4
	lao	r12,e__system__nind,21
	otoa	r12,e__system__nind,21
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmarkr_node

rmarkr_record_selector_node_1:
	beq	rmarkr_strict_record_selector_node_1

	str	r4,[sp,#-4]!
	and	r4,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmarkr_hnf_1

	ldrh	r12,[r3,#-2]
	mov	r3,#258/2
	cmp	r12,r3,lsl #1
	bls	rmarkr_small_tuple_or_record

	ldr	r3,[r7,#8]
	sub	r3,r3,r11
	lsr	r3,r3,#2

	str	r4,[sp,#-4]!
	and	r4,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

rmarkr_small_tuple_or_record:
	add	r12,r6,#-4
	sub	r3,r12,r11

	str	r6,[sp,#-4]!
.ifdef PIC
	add	r12,r4,#-8+4
.endif
	ldr	r4,[r4,#-8]

	and	r6,r3,#31*4
	lsr	r3,r3,#7
	lsr	r6,r6,#2
.ifdef PIC
	ldrh	r4,[r12,r4]
.endif
	mov	r12,#1
	lsl	r6,r12,r6
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r6
	str	r12,[r10,r3,lsl #2]

.ifndef PIC
	ldrh	r4,[r4,#4]
.endif
	cmp	r4,#8
	ble	rmarkr_tuple_or_record_selector_node_2
	ldr	r7,[r7,#8]
	sub	r4,r4,#12
rmarkr_tuple_or_record_selector_node_2:
	ldr	r6,[r7,r4]
	ldr	r7,[sp],#4
	lao	r12,e__system__nind,22
	otoa	r12,e__system__nind,22
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmarkr_node

rmarkr_strict_record_selector_node_1:
	str	r4,[sp,#-4]!
	and	r4,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmarkr_hnf_1

	ldrh	r12,[r3,#-2]
	mov	r3,#258/2
	cmp	r12,r3,lsl #1
	bls	rmarkr_select_from_small_record

	ldr	r3,[r7,#8]
	sub	r3,r3,r11

	str	r4,[sp,#-4]!
	and	r4,r3,#31*4
	lsr	r3,r3,#7
	lsr	r4,r4,#2
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r4
	ldr	r4,[sp],#4
	bne	rmarkr_hnf_1

rmarkr_select_from_small_record:
.ifdef PIC
	ldr	r12,[r4,#-8]
	add	r4,r4,#-8+4
.else
	ldr	r4,[r4,#-8]
.endif
	sub	r6,r6,#4

.ifdef PIC
	ldrh	r3,[r4,r12]!
.else
	ldrh	r3,[r4,#4]
.endif
	cmp	r3,#8
	ble	rmarkr_strict_record_selector_node_2
	ldr	r12,[r7,#8]
	add	r3,r3,r12
	ldr	r3,[r3,#-12]
	b	rmarkr_strict_record_selector_node_3
rmarkr_strict_record_selector_node_2:
	ldr	r3,[r7,r3]
rmarkr_strict_record_selector_node_3:
	str	r3,[r6,#4]

.ifdef PIC
	ldrh	r3,[r4,#6-4]
.else
	ldrh	r3,[r4,#6]
.endif
	tst	r3,r3
	beq	rmarkr_strict_record_selector_node_5
	cmp	r3,#8
	ble	rmarkr_strict_record_selector_node_4
	ldr	r7,[r7,#8]
	subs	r3,r3,#12
rmarkr_strict_record_selector_node_4:
	ldr	r3,[r7,r3]
	str	r3,[r6,#8]
rmarkr_strict_record_selector_node_5:

.ifdef PIC
	ldr	r4,[r4,#-4-4]
.else
	ldr	r4,[r4,#-4]
.endif
	str	r4,[r6]
	b	rmarkr_next_node

@ a2,d1: free

rmarkr_next_node:
	tst	r9,#3
	bne	rmarkr_parent

	ldr	r8,[r9,#-4]
	mov	r3,#3

	and	r3,r3,r8
	subs	r9,r9,#4

	cmp	r3,#3
	beq	rmarkr_argument_part_cycle1

	ldr	r7,[r9,#4]
	str	r7,[r9]

rmarkr_c_argument_part_cycle1:
	cmp	r6,r9
	bhi	rmarkr_no_reverse_1

	ldr	r7,[r6]
	add	r4,r9,#4+1
	str	r7,[r9,#4]
	str	r4,[r6]

	orr	r9,r9,r3
	mov	r6,r8
	eor	r6,r6,r3
	b	rmarkr_node

rmarkr_no_reverse_1:
	str	r6,[r9,#4]
	mov	r6,r8
	orr	r9,r9,r3
	eor	r6,r6,r3
	b	rmarkr_node

rmarkr_lazy_node:
	ldr	r8,[r4,#-4]
	tst	r8,r8
	beq	rmarkr_next_node

	add	r6,r6,#4

	subs	r8,r8,#1
	ble	rmarkr_lazy_node_1

	cmp	r8,#255
	bge	rmarkr_closure_with_unboxed_arguments

rmarkr_closure_with_unboxed_arguments_:
	ldr	r12,[r6]
	orr	r12,r12,#2
	str	r12,[r6]
	add	r6,r6,r8,lsl #2

	ldr	r8,[r6]
	str	r9,[r6]
	mov	r9,r6
	mov	r6,r8
	b	rmarkr_node

rmarkr_closure_with_unboxed_arguments:
@ (a_size+b_size)+(b_size<<8)
@	addl	$1,a2
	mov	r4,r8
	and	r8,r8,#255
	lsr	r4,r4,#8
	subs	r8,r8,r4
@	subl	$1,a2
	bgt	rmarkr_closure_with_unboxed_arguments_
	beq	rmarkr_hnf_1
	subs	r6,r6,#4
	b	rmarkr_next_node

rmarkr_hnf_0:
	laol	r12,INT+2,INT_o_2,12
	otoa	r12,INT_o_2,12
	cmp	r4,r12
	beq	rmarkr_int_3

	laol	r12,CHAR+2,CHAR_o_2,7
	otoa	r12,CHAR_o_2,7
	cmp	r4,r12
 	beq	rmarkr_char_3

	blo	rmarkr_no_normal_hnf_0

	sub	r3,r6,r11

	and	r6,r3,#31*4
	lsr	r3,r3,#7
	lsr	r12,r6,#2
	mov	r6,#1
	lsl	r6,r6,r12
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r6
	str	r12,[r10,r3,lsl #2]

	add	r6,r4,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	b	rmarkr_next_node_after_static

rmarkr_int_3:
	ldr	r8,[r6,#4]
	cmp	r8,#33
	bhs	rmarkr_next_node

	sub	r3,r6,r11

	and	r6,r3,#31*4
	lsr	r3,r3,#7
	lsr	r12,r6,#2
	mov	r6,#1
	lsl	r6,r6,r12
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r6
	str	r12,[r10,r3,lsl #2]

	lao	r12,small_integers,4
	otoa	r12,small_integers,4
	add	r6,r12,r8,lsl #3
	b	rmarkr_next_node_after_static

rmarkr_char_3:
	ldrb	r4,[r6,#4]
	sub	r3,r6,r11

	and	r8,r3,#31*4
	lsr	r3,r3,#7
	lsr	r12,r8,#2
	mov	r8,#1
	lsl	r8,r8,r12
	ldr	r12,[r10,r3,lsl #2]
	bic	r12,r12,r8
	str	r12,[r10,r3,lsl #2]

	lao	r12,static_characters,4
	otoa	r12,static_characters,4
	add	r6,r12,r4,lsl #3
	b	rmarkr_next_node_after_static

rmarkr_no_normal_hnf_0:
	laol	r12,__ARRAY__+2,__ARRAY___o_2,19
	otoa	r12,__ARRAY___o_2,19
	cmp	r4,r12
	bne	rmarkr_next_node

	ldr	r4,[r6,#8]
	cmp	r4,#0
	beq	rmarkr_lazy_array

	ldrh	r3,[r4,#-2+2]
	cmp	r3,#0
	beq	rmarkr_b_array

	ldrh	r4,[r4,#-2]
	cmp	r4,#0
	beq	rmarkr_b_array

	subs	r4,r4,#256
	cmp	r3,r4
	beq	rmarkr_a_record_array

rmarkr_ab_record_array:
	ldr	r7,[r6,#4]
	add	r6,r6,#8
	str	r6,[sp,#-4]!

	mul	r7,r4,r7
	lsl	r7,r7,#2

	subs	r4,r4,r3
	add	r6,r6,#4
	add	r7,r7,r6
	str	pc,[sp,#-4]!
	bl	reorder

	ldr	r6,[sp],#4
	mov	r4,r3
	ldr	r12,[r6,#-4]
	mul	r4,r12,r4
	b	rmarkr_lr_array

rmarkr_b_array:
	sub	r4,r6,r11

	add	r4,r4,#4
	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	b	rmarkr_next_node

rmarkr_a_record_array:
	ldr	r4,[r6,#4]
	add	r6,r6,#8
	cmp	r3,#2
	blo	rmarkr_lr_array

	mul	r4,r3,r4
	b	rmarkr_lr_array

rmarkr_lazy_array:
	ldr	r4,[r6,#4]
	add	r6,r6,#8

rmarkr_lr_array:
	sub	r3,r6,r11
	lsr	r3,r3,#2
	add	r3,r3,r4

	lsr	r7,r3,#5
	and	r3,r3,#31
	mov	r12,#1
	lsl	r3,r12,r3
	ldr	r12,[r10,r7,lsl #2]
	orr	r12,r12,r3
	str	r12,[r10,r7,lsl #2]

	cmp	r4,#1
	bls	rmarkr_array_length_0_1

	mov	r7,r6
	add	r6,r6,r4,lsl #2

	ldr	r4,[r6]
	ldr	r3,[r7]
	str	r4,[r7]
	str	r3,[r6]

	ldr	r4,[r6,#-4]
	subs	r6,r6,#4
	add	r4,r4,#2
	ldr	r3,[r7,#-4]
	subs	r7,r7,#4
	str	r3,[r6]
	str	r4,[r7]

	ldr	r4,[r6,#-4]
	subs	r6,r6,#4
	str	r9,[r6]
	mov	r9,r6
	mov	r6,r4
	b	rmarkr_node

rmarkr_array_length_0_1:
	add	r6,r6,#-8
	blo	rmarkr_next_node

	ldr	r3,[r6,#12]
	ldr	r8,[r6,#8]
	str	r8,[r6,#12]
	ldr	r8,[r6,#4]
	str	r8,[r6,#8]
	str	r3,[r6,#4]
	add	r6,r6,#4
	b	rmarkr_hnf_1

@ a2: free

rmarkr_parent:
	and	r3,r9,#3

	bics	r9,r9,#3
	beq	end_rmarkr

	subs	r3,r3,#1
	beq	rmarkr_argument_part_parent

	ldr	r8,[r9]

	cmp	r6,r9
	bhi	rmarkr_no_reverse_2

	mov	r7,r6
	add	r4,r9,#1
	ldr	r6,[r7]
	str	r4,[r7]

rmarkr_no_reverse_2:
	str	r6,[r9]
	add	r6,r9,#-4
	mov	r9,r8
	b	rmarkr_next_node


rmarkr_argument_part_parent:
	ldr	r8,[r9]

	mov	r7,r9
	mov	r9,r6
	mov	r6,r7

rmarkr_skip_upward_pointers:
	mov	r4,r8
	and	r4,r4,#3
	cmp	r4,#3
	bne	rmarkr_no_upward_pointer

	add	r7,r8,#-3
	ldr	r8,[r8,#-3]
	b	rmarkr_skip_upward_pointers

rmarkr_no_upward_pointer:
	cmp	r9,r6
	bhi	rmarkr_no_reverse_3

	mov	r3,r9
	ldr	r9,[r9]
	add	r4,r6,#1
	str	r4,[r3]

rmarkr_no_reverse_3:
	str	r9,[r7]
	add	r9,r8,#-4

	and	r9,r9,#-4

	mov	r7,r9
	mov	r3,#3

	ldr	r8,[r9]

	and	r3,r3,r8
	ldr	r4,[r7,#4]

	orr	r9,r9,r3
	str	r4,[r7]

	cmp	r6,r7
	bhi	rmarkr_no_reverse_4

	ldr	r4,[r6]
	str	r4,[r7,#4]
	add	r4,r7,#4+2+1
	str	r4,[r6]
	mov	r6,r8
	and	r6,r6,#-4
	b	rmarkr_node

rmarkr_no_reverse_4:
	str	r6,[r7,#4]
	mov	r6,r8
	and	r6,r6,#-4
	b	rmarkr_node

rmarkr_argument_part_cycle1:
	ldr	r4,[r9,#4]
	str	r7,[sp,#-4]!

rmarkr_skip_pointer_list1:
	mov	r7,r8
	and	r7,r7,#-4
	ldr	r8,[r7]
	mov	r3,#3
	and	r3,r3,r8
	cmp	r3,#3
	beq	rmarkr_skip_pointer_list1

	str	r4,[r7]
	ldr	r7,[sp],#4
	b	rmarkr_c_argument_part_cycle1

rmarkr_next_node_after_static:
	tst	r9,#3
	bne	rmarkr_parent_after_static

	ldr	r8,[r9,#-4]
	mov	r3,#3

	and	r3,r3,r8
	subs	r9,r9,#4

	cmp	r3,#3
	beq	rmarkr_argument_part_cycle2

	ldr	r4,[r9,#4]
	str	r4,[r9]

rmarkr_c_argument_part_cycle2:
	str	r6,[r9,#4]
	mov	r6,r8
	orr	r9,r9,r3
	eor	r6,r6,r3
	b	rmarkr_node

rmarkr_parent_after_static:
	and	r3,r9,#3

	ands	r9,r9,#-4
	beq	end_rmarkr_after_static

	subs	r3,r3,#1
	beq	rmarkr_argument_part_parent_after_static

	ldr	r8,[r9]
	str	r6,[r9]
	add	r6,r9,#-4
	mov	r9,r8
	b	rmarkr_next_node

rmarkr_argument_part_parent_after_static:
	ldr	r8,[r9]

	mov	r7,r9
	mov	r9,r6
	mov	r6,r7

@	movl	(a1),a2
rmarkr_skip_upward_pointers_2:
	mov	r4,r8
	and	r4,r4,#3
	cmp	r4,#3
	bne	rmarkr_no_reverse_3

@	movl	a2,a1
@	andl	$-4,a1
@	movl	(a1),a2
	add	r7,r8,#-3
	ldr	r8,[r8,#-3]
	b	rmarkr_skip_upward_pointers_2

rmarkr_argument_part_cycle2:
	ldr	r4,[r9,#4]
	str	r7,[sp,#-4]!

rmarkr_skip_pointer_list2:
	mov	r7,r8
	and	r7,r7,#-4
	ldr	r8,[r7]
	mov	r3,#3
	and	r3,r3,r8
	cmp	r3,#3
	beq	rmarkr_skip_pointer_list2

	str	r4,[r7]
	ldr	r7,[sp],#4
	b	rmarkr_c_argument_part_cycle2

end_rmarkr_after_static:
	ldr	r9,[sp]
	add	sp,sp,#8
	str	r6,[r9]
	b	rmarkr_next_stack_node

end_rmarkr:
	ldr	r9,[sp],#4
	ldr	r3,[sp],#4

	cmp	r6,r3
	bhi	rmark_no_reverse_4

	mov	r7,r6
	add	r4,r9,#1
	ldr	r6,[r6]
	str	r4,[r7]

rmark_no_reverse_4:
	str	r6,[r9]

rmarkr_next_stack_node:
	cmp	sp,r0
	bhs	rmark_next_node

	ldr	r6,[sp]
	ldr	r9,[sp,#4]
	add	sp,sp,#8

	cmp	r6,#1
	bhi	rmark_using_reversal

	b	rmark_next_node_

.ifdef PIC
	ltol	__ARRAY__+2,__ARRAY___o_2,18
	lto	e__system__nind,20
	lto	e__system__nind,21
	lto	e__system__nind,22
	ltol	INT+2,INT_o_2,12
	ltol	CHAR+2,CHAR_o_2,7
	lto	small_integers,4
	lto	static_characters,4
	ltol	__ARRAY__+2,__ARRAY___o_2,19
.endif
	.ltorg
