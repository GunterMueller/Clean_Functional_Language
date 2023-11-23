
ZERO_ARITY_DESCRIPTOR_OFFSET = -4
NO_BIT_INSTRUCTIONS = 1

rmark_using_reversal:
	push	{r5}
	push	{r5}
	mov	r5,#1
	b	rmarkr_node

rmark_using_reversal_:
	subs	r2,r2,#4
	push	{r0}
	push	{r5}
	cmp	r2,r0
	bhi	rmark_no_undo_reverse_1
	str	r2,[r5]
	str	r1,[r2]
rmark_no_undo_reverse_1:
	mov	r5,#1
	b	rmarkr_arguments

rmark_array_using_reversal:
	push	{r0}
	push	{r5}
	cmp	r2,r0
	bhi	rmark_no_undo_reverse_2
	str	r2,[r5]
	laol	r7,__ARRAY__+2,__ARRAY___o_2,18
	otoa	r7,__ARRAY___o_2,18
	str	r7,[r2]
rmark_no_undo_reverse_2:
	mov	r5,#1
	b	rmarkr_arguments

rmarkr_hnf_2:
	ldr	r7,[r2]
	orr	r7,r7,#2
	str	r7,[r2]
	ldr	r4,[r2,#4]
	str	r5,[r2,#4]
	add	r5,r2,#4
	mov	r2,r4

rmarkr_node:
	sub	r1,r2,r12
	cmp	r1,r10
	bhs	rmarkr_next_node_after_static

	lsr	r0,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r4,[r6,r0,lsl #2]
	tst	r4,r1
	bne	rmarkr_next_node

	orr	r4,r4,r1
	str	r4,[r6,r0,lsl #2]

rmarkr_arguments:
	ldr	r1,[r2]
	tst	r1,#2
	beq	rmarkr_lazy_node

	ldrh	r4,[r1,#-2]
	tst	r4,r4
	beq	rmarkr_hnf_0

	add	r2,r2,#4

	cmp	r4,#256
	bhs	rmarkr_record

	subs	r4,r4,#2
	beq	rmarkr_hnf_2
	blo	rmarkr_hnf_1

rmarkr_hnf_3:
	ldr	r3,[r2,#4]

	sub	r1,r3,r12

	lsr	r0,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r0,lsl #2]
	tst	r1,r7
	bne	rmarkr_shared_argument_part

	orr	r7,r7,r1	
	str	r7,[r6,r0,lsl #2]	

rmarkr_no_shared_argument_part:
	ldr	r7,[r2]
	orr	r7,r7,#2
	str	r7,[r2]
	str	r5,[r2,#4]
	add	r2,r2,#4

	ldr	r7,[r3]
	orr	r7,r7,#1
	str	r7,[r3]
	add	r3,r3,r4,lsl #2

	ldr	r4,[r3]
	str	r2,[r3]
	mov	r5,r3
	mov	r2,r4
	b	rmarkr_node

rmarkr_shared_argument_part:
	cmp	r3,r2
	bhi	rmarkr_hnf_1

	ldr	r0,[r3]
	add	r1,r2,#4+2+1
	str	r1,[r3]
	str	r0,[r2,#4]
	b	rmarkr_hnf_1

rmarkr_record:
	subs	r4,r4,#258
	beq	rmarkr_record_2
	blo	rmarkr_record_1

rmarkr_record_3:
	ldrh	r4,[r1,#-2+2]
	subs	r4,r4,#1
	blo	rmarkr_record_3_bb
	beq	rmarkr_record_3_ab
	subs	r4,r4,#1
	beq	rmarkr_record_3_aab
	b	rmarkr_hnf_3

rmarkr_record_3_bb:
	ldr	r3,[r2,#8-4]
	subs	r2,r2,#4

	sub	r1,r3,r12

	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	cmp	r3,r2
	bhi	rmarkr_next_node

	adds	r1,r1,r1
	bne	rmarkr_bit_in_same_word1
	add	r4,r4,#1
	mov	r1,#1
rmarkr_bit_in_same_word1:
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	beq	rmarkr_not_yet_linked_bb

	sub	r1,r2,r12

	add	r1,r1,#2*4
	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
rmarkr_not_yet_linked_bb:
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	ldr	r4,[r3]
	add	r1,r2,#8+2+1
	str	r4,[r2,#8]
	str	r1,[r3]
	b	rmarkr_next_node

rmarkr_record_3_ab:
	ldr	r3,[r2,#4]

	sub	r1,r3,r12

	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	cmp	r3,r2
	bhi	rmarkr_hnf_1

	adds	r1,r1,r1
	bne	rmarkr_bit_in_same_word2
	add	r4,r4,#1
	mov	r1,#1
rmarkr_bit_in_same_word2:
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	beq	rmarkr_not_yet_linked_ab

	sub	r1,r2,r12

	add	r1,r1,#4
	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
rmarkr_not_yet_linked_ab: 
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	ldr	r4,[r3]
	add	r1,r2,#4+2+1
	str	r4,[r2,#4]
	str	r1,[r3]
	b	rmarkr_hnf_1

rmarkr_record_3_aab:
	ldr	r3,[r2,#4]

	sub	r1,r3,r12

	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	bne	rmarkr_shared_argument_part
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	ldr	r7,[r2]
	add	r7,r7,#2
	str	r7,[r2]
	str	r5,[r2,#4]
	add	r2,r2,#4

	ldr	r5,[r3]
	str	r2,[r3]
	mov	r2,r5
	add	r5,r3,#1
	b	rmarkr_node

rmarkr_record_2:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#1
	bhi	rmarkr_hnf_2
	beq	rmarkr_hnf_1
	subs	r2,r2,#4
	b	rmarkr_next_node

rmarkr_record_1:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#0
	bne	rmarkr_hnf_1
	subs	r2,r2,#4
	b	rmarkr_next_node

rmarkr_lazy_node_1:
@ selectors:
	bne	rmarkr_selector_node_1

rmarkr_hnf_1:
	ldr	r4,[r2]
	str	r5,[r2]

	add	r5,r2,#2
	mov	r2,r4
	b	rmarkr_node

@ selectors
rmarkr_indirection_node:
	add	r7,r2,#-4
	sub	r0,r7,r12

	and	r1,r0,#31*4
	lsr	r0,r0,#7
	lsr	r7,r1,#2
	mov	r1,#1
	lsl	r1,r1,r7
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r1
	str	r7,[r6,r0,lsl #2]

	ldr	r2,[r2]
	b	rmarkr_node

rmarkr_selector_node_1:
	cmp	r4,#(-2)-1
	beq	rmarkr_indirection_node

	ldr	r3,[r2]

	sub	r0,r3,r12
	lsr	r0,r0,#2

	cmp	r4,#(-3)-1
	ble	rmarkr_record_selector_node_1

	push	{r1}
	and	r1,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmarkr_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#2
	bls	rmarkr_small_tuple_or_record

rmarkr_large_tuple_or_record:
	ldr	r0,[r3,#8]
	sub	r0,r0,r12
	lsr	r0,r0,#2

	push	{r1}
	and	r1,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

	add	r7,r2,#-4
	sub	r0,r7,r12

	push	{r2}

.ifdef PIC
	add	r7,r1,#-8+4
.endif
	ldr	r1,[r1,#-1-8]

	and	r2,r0,#31*4
	lsr	r0,r0,#7
	lsr	r2,r2,#2
.ifdef PIC
	ldrh	r1,[r7,r1]
.endif
	mov	r7,#1
	lsl	r2,r7,r2
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r2
	str	r7,[r6,r0,lsl #2]

.ifndef PIC
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	blt	rmarkr_tuple_or_record_selector_node_2
	ldr	r3,[r3,#8]
	beq	rmarkr_tuple_selector_node_2
	add	r7,r1,#-12
	ldr	r2,[r3,r7]
	pop	{r3}
	lao	r7,e__system__nind,20
	otoa	r7,e__system__nind,20
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmarkr_node

rmarkr_tuple_selector_node_2:
	ldr	r2,[r3]
	pop	{r3}
	lao	r7,e__system__nind,21
	otoa	r7,e__system__nind,21
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmarkr_node

rmarkr_record_selector_node_1:
	beq	rmarkr_strict_record_selector_node_1

	push	{r1}
	and	r1,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmarkr_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	bls	rmarkr_small_tuple_or_record

	ldr	r0,[r3,#8]
	sub	r0,r0,r12
	lsr	r0,r0,#2

	push	{r1}
	and	r1,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

rmarkr_small_tuple_or_record:
	add	r7,r2,#-4
	sub	r0,r7,r12

	push	{r2}
.ifdef PIC
	add	r7,r1,#-8+4
.endif
	ldr	r1,[r1,#-1-8]

	and	r2,r0,#31*4
	lsr	r0,r0,#7
	lsr	r2,r2,#2
.ifdef PIC
	ldrh	r1,[r7,r1]
.endif
	mov	r7,#1
	lsl	r2,r7,r2
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r2
	str	r7,[r6,r0,lsl #2]

.ifndef PIC
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	ble	rmarkr_tuple_or_record_selector_node_2
	ldr	r3,[r3,#8]
	sub	r1,r1,#12
rmarkr_tuple_or_record_selector_node_2:
	ldr	r2,[r3,r1]
	pop	{r3}
	lao	r7,e__system__nind,22
	otoa	r7,e__system__nind,22
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmarkr_node

rmarkr_strict_record_selector_node_1:
	push	{r1}
	and	r1,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmarkr_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	bls	rmarkr_select_from_small_record

	ldr	r0,[r3,#8]
	sub	r0,r0,r12

	push	{r1}
	and	r1,r0,#31*4
	lsr	r0,r0,#7
	lsr	r1,r1,#2
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r1
	pop	{r1}
	bne	rmarkr_hnf_1

rmarkr_select_from_small_record:
.ifdef PIC
	ldr	r7,[r1,#-8]
	add	r1,r1,#-8+4
.else
	ldr	r1,[r1,#-1-8]
.endif
	sub	r2,r2,#4

.ifdef PIC
	ldrh	r0,[r1,r7]!
.else
	ldrh	r0,[r1,#4]
.endif
	cmp	r0,#8
	ble	rmarkr_strict_record_selector_node_2
	ldr	r7,[r3,#8]
	add	r0,r0,r7
	ldr	r0,[r0,#-12]
	b	rmarkr_strict_record_selector_node_3
rmarkr_strict_record_selector_node_2:
	ldr	r0,[r3,r0]
rmarkr_strict_record_selector_node_3:
	str	r0,[r2,#4]

.ifdef PIC
	ldrh	r0,[r1,#6-4]
.else
	ldrh	r0,[r1,#6]
.endif
	tst	r0,r0
	beq	rmarkr_strict_record_selector_node_5
	cmp	r0,#8
	ble	rmarkr_strict_record_selector_node_4
	ldr	r3,[r3,#8]
	subs	r0,r0,#12
rmarkr_strict_record_selector_node_4:
	ldr	r0,[r3,r0]
	str	r0,[r2,#8]
rmarkr_strict_record_selector_node_5:

.ifdef PIC
	ldr	r1,[r1,#-4-4]
.else
	ldr	r1,[r1,#-4]
.endif
	str	r1,[r2]
	b	rmarkr_next_node

@ a2,d1: free

rmarkr_next_node:
	tst	r5,#3
	bne	rmarkr_parent

	ldr	r4,[r5,#-4]
	mov	r0,#3

	and	r0,r0,r4
	subs	r5,r5,#4

	cmp	r0,#3
	beq	rmarkr_argument_part_cycle1

	ldr	r3,[r5,#4]
	str	r3,[r5]

rmarkr_c_argument_part_cycle1:
	cmp	r2,r5
	bhi	rmarkr_no_reverse_1

	ldr	r3,[r2]
	add	r1,r5,#4
	str	r3,[r5,#4]
	str	r1,[r2]

	orr	r5,r5,r0
	mov	r2,r4
	eor	r2,r2,r0
	b	rmarkr_node

rmarkr_no_reverse_1:
	str	r2,[r5,#4]
	mov	r2,r4
	orr	r5,r5,r0
	eor	r2,r2,r0
	b	rmarkr_node

rmarkr_lazy_node:
	ldr	r4,[r1,#-1-4]
	tst	r4,r4
	beq	rmarkr_next_node

	add	r2,r2,#4

	subs	r4,r4,#1
	ble	rmarkr_lazy_node_1

	cmp	r4,#255
	bge	rmarkr_closure_with_unboxed_arguments

rmarkr_closure_with_unboxed_arguments_:
	ldr	r7,[r2]
	orr	r7,r7,#2
	str	r7,[r2]
	add	r2,r2,r4,lsl #2

	ldr	r4,[r2]
	str	r5,[r2]
	mov	r5,r2
	mov	r2,r4
	b	rmarkr_node

rmarkr_closure_with_unboxed_arguments:
@ (a_size+b_size)+(b_size<<8)
@	addl	$1,a2
	mov	r1,r4
	and	r4,r4,#255
	lsr	r1,r1,#8
	subs	r4,r4,r1
@	subl	$1,a2
	bgt	rmarkr_closure_with_unboxed_arguments_
	beq	rmarkr_hnf_1
	subs	r2,r2,#4
	b	rmarkr_next_node

rmarkr_hnf_0:
	laol	r7,INT+2,INT_o_2,12
	otoa	r7,INT_o_2,12
	cmp	r1,r7
	beq	rmarkr_int_3

	laol	r7,CHAR+2,CHAR_o_2,7
	otoa	r7,CHAR_o_2,7
	cmp	r1,r7
 	beq	rmarkr_char_3

	blo	rmarkr_no_normal_hnf_0

	sub	r0,r2,r12

	and	r2,r0,#31*4
	lsr	r0,r0,#7
	lsr	r7,r2,#2
	mov	r2,#1
	lsl	r2,r2,r7
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r2
	str	r7,[r6,r0,lsl #2]

	add	r2,r1,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	b	rmarkr_next_node_after_static

rmarkr_int_3:
	ldr	r4,[r2,#4]
	cmp	r4,#33
	bhs	rmarkr_next_node

	sub	r0,r2,r12

	and	r2,r0,#31*4
	lsr	r0,r0,#7
	lsr	r7,r2,#2
	mov	r2,#1
	lsl	r2,r2,r7
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r2
	str	r7,[r6,r0,lsl #2]

	lao	r7,small_integers,4
	otoa	r7,small_integers,4
	add	r2,r7,r4,lsl #3
	b	rmarkr_next_node_after_static

rmarkr_char_3:
	ldrb	r1,[r2,#4]
	sub	r0,r2,r12

	and	r4,r0,#31*4
	lsr	r0,r0,#7
	lsr	r7,r4,#2
	mov	r4,#1
	lsl	r4,r4,r7
	ldr	r7,[r6,r0,lsl #2]
	bic	r7,r7,r4
	str	r7,[r6,r0,lsl #2]

	lao	r7,static_characters,4
	otoa	r7,static_characters,4
	add	r2,r7,r1,lsl #3
	b	rmarkr_next_node_after_static

rmarkr_no_normal_hnf_0:
	laol	r7,__ARRAY__+2,__ARRAY___o_2,19
	otoa	r7,__ARRAY___o_2,19
	cmp	r1,r7
	bne	rmarkr_next_node

	ldr	r1,[r2,#8]
	cmp	r1,#0
	beq	rmarkr_lazy_array

	ldrh	r0,[r1,#-2+2]
	cmp	r0,#0
	beq	rmarkr_b_array

	ldrh	r1,[r1,#-2]
	cmp	r1,#0
	beq	rmarkr_b_array

	subs	r1,r1,#256
	cmp	r0,r1
	beq	rmarkr_a_record_array

rmarkr_ab_record_array:
	ldr	r3,[r2,#4]
	add	r2,r2,#8
	push	{r2}

	mul	r3,r1,r3
	lsl	r3,r3,#2

	subs	r1,r1,r0
	add	r2,r2,#4
	add	r3,r3,r2
	adr	r14,1+0f
	push	{r14}
	bl	reorder
0:
	pop	{r2}
	mov	r1,r0
	ldr	r7,[r2,#-4]
	mul	r1,r7,r1
	b	rmarkr_lr_array

rmarkr_b_array:
	sub	r1,r2,r12

	add	r1,r1,#4
	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	b	rmarkr_next_node

rmarkr_a_record_array:
	ldr	r1,[r2,#4]
	add	r2,r2,#8
	cmp	r0,#2
	blo	rmarkr_lr_array

	mul	r1,r0,r1
	b	rmarkr_lr_array

rmarkr_lazy_array:
	ldr	r1,[r2,#4]
	add	r2,r2,#8

rmarkr_lr_array:
	sub	r0,r2,r12
	lsr	r0,r0,#2
	add	r0,r0,r1

	lsr	r3,r0,#5
	and	r0,r0,#31
	mov	r7,#1
	lsl	r0,r7,r0
	ldr	r7,[r6,r3,lsl #2]
	orr	r7,r7,r0
	str	r7,[r6,r3,lsl #2]

	cmp	r1,#1
	bls	rmarkr_array_length_0_1

	mov	r3,r2
	add	r2,r2,r1,lsl #2

	ldr	r1,[r2]
	ldr	r0,[r3]
	str	r1,[r3]
	str	r0,[r2]

	ldr	r1,[r2,#-4]
	subs	r2,r2,#4
	add	r1,r1,#2
	ldr	r0,[r3,#-4]
	subs	r3,r3,#4
	str	r0,[r2]
	str	r1,[r3]

	ldr	r1,[r2,#-4]
	subs	r2,r2,#4
	str	r5,[r2]
	mov	r5,r2
	mov	r2,r1
	b	rmarkr_node

rmarkr_array_length_0_1:
	add	r2,r2,#-8
	blo	rmarkr_next_node

	ldr	r0,[r2,#12]
	ldr	r4,[r2,#8]
	str	r4,[r2,#12]
	ldr	r4,[r2,#4]
	str	r4,[r2,#8]
	str	r0,[r2,#4]
	add	r2,r2,#4
	b	rmarkr_hnf_1

@ a2: free

rmarkr_parent:
	and	r0,r5,#3

	bics	r5,r5,#3
	beq	end_rmarkr

	subs	r0,r0,#1
	beq	rmarkr_argument_part_parent

	ldr	r4,[r5]

	cmp	r2,r5
	bhi	rmarkr_no_reverse_2

	mov	r3,r2
	ldr	r2,[r3]
	str	r5,[r3]

rmarkr_no_reverse_2:
	str	r2,[r5]
	add	r2,r5,#-4
	mov	r5,r4
	b	rmarkr_next_node


rmarkr_argument_part_parent:
	ldr	r4,[r5]

	mov	r3,r5
	mov	r5,r2
	mov	r2,r3

rmarkr_skip_upward_pointers:
	mov	r1,r4
	and	r1,r1,#3
	cmp	r1,#3
	bne	rmarkr_no_upward_pointer

	add	r3,r4,#-3
	ldr	r4,[r4,#-3]
	b	rmarkr_skip_upward_pointers

rmarkr_no_upward_pointer:
	cmp	r5,r2
	bhi	rmarkr_no_reverse_3

	mov	r0,r5
	ldr	r5,[r5]
	str	r2,[r0]

rmarkr_no_reverse_3:
	str	r5,[r3]
	add	r5,r4,#-4

	and	r5,r5,#-4

	mov	r3,r5
	mov	r0,#3

	ldr	r4,[r5]

	and	r0,r0,r4
	ldr	r1,[r3,#4]

	orr	r5,r5,r0
	str	r1,[r3]

	cmp	r2,r3
	bhi	rmarkr_no_reverse_4

	ldr	r1,[r2]
	str	r1,[r3,#4]
	add	r1,r3,#4+2+1
	str	r1,[r2]
	mov	r2,r4
	and	r2,r2,#-4
	b	rmarkr_node

rmarkr_no_reverse_4:
	str	r2,[r3,#4]
	mov	r2,r4
	and	r2,r2,#-4
	b	rmarkr_node

rmarkr_argument_part_cycle1:
	ldr	r1,[r5,#4]
	push	{r3}

rmarkr_skip_pointer_list1:
	mov	r3,r4
	and	r3,r3,#-4
	ldr	r4,[r3]
	mov	r0,#3
	and	r0,r0,r4
	cmp	r0,#3
	beq	rmarkr_skip_pointer_list1

	str	r1,[r3]
	pop	{r3}
	b	rmarkr_c_argument_part_cycle1

rmarkr_next_node_after_static:
	tst	r5,#3
	bne	rmarkr_parent_after_static

	ldr	r4,[r5,#-4]
	mov	r0,#3

	and	r0,r0,r4
	subs	r5,r5,#4

	cmp	r0,#3
	beq	rmarkr_argument_part_cycle2

	ldr	r1,[r5,#4]
	str	r1,[r5]

rmarkr_c_argument_part_cycle2:
	str	r2,[r5,#4]
	mov	r2,r4
	orr	r5,r5,r0
	eor	r2,r2,r0
	b	rmarkr_node

rmarkr_parent_after_static:
	and	r0,r5,#3

	ands	r5,r5,#-4
	beq	end_rmarkr_after_static

	subs	r0,r0,#1
	beq	rmarkr_argument_part_parent_after_static

	ldr	r4,[r5]
	str	r2,[r5]
	add	r2,r5,#-4
	mov	r5,r4
	b	rmarkr_next_node

rmarkr_argument_part_parent_after_static:
	ldr	r4,[r5]

	mov	r3,r5
	mov	r5,r2
	mov	r2,r3

@	movl	(a1),a2
rmarkr_skip_upward_pointers_2:
	mov	r1,r4
	and	r1,r1,#3
	cmp	r1,#3
	bne	rmarkr_no_reverse_3

@	movl	a2,a1
@	andl	$-4,a1
@	movl	(a1),a2
	add	r3,r4,#-3
	ldr	r4,[r4,#-3]
	b	rmarkr_skip_upward_pointers_2

rmarkr_argument_part_cycle2:
	ldr	r1,[r5,#4]
	push	{r3}

rmarkr_skip_pointer_list2:
	mov	r3,r4
	and	r3,r3,#-4
	ldr	r4,[r3]
	mov	r0,#3
	and	r0,r0,r4
	cmp	r0,#3
	beq	rmarkr_skip_pointer_list2

	str	r1,[r3]
	pop	{r3}
	b	rmarkr_c_argument_part_cycle2

end_rmarkr_after_static:
	ldr	r5,[sp],#8
	str	r2,[r5]
	b	rmarkr_next_stack_node

end_rmarkr:
	ldr	r0,[sp,#4]
	ldr	r5,[sp],#8

	cmp	r2,r0
	bhi	rmark_no_reverse_4

	mov	r3,r2
	ldr	r2,[r2]
	str	r5,[r3]

rmark_no_reverse_4:
	str	r2,[r5]

rmarkr_next_stack_node:
	cmp	sp,r8
	bhs	rmark_next_node

	ldr	r2,[sp]
	ldr	r5,[sp,#4]
	add	sp,sp,#8

	cmp	r2,#1
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
