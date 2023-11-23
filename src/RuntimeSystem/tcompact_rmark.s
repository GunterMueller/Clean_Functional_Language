
ZERO_ARITY_DESCRIPTOR_OFFSET = -4

rmark_stack_nodes1:
	ldr	r0,[r2]
	str	r0,[r5]
	str	r5,[r2]

rmark_next_stack_node:
	add	r5,r5,#4
rmark_stack_nodes:
	lao	r7,end_vector,16
	ldo	r7,r7,end_vector,16
	cmp	r5,r7
	beq	end_rmark_nodes

rmark_more_stack_nodes:
	ldr	r2,[r5]

	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_stack_node

	lsr	r0,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r4,[r6,r0,lsl #2]
	tst	r4,r1
	bne	rmark_stack_nodes1

	orr	r4,r4,r1
	str	r4,[r6,r0,lsl #2]

	ldr	r1,[r2]
	adr	r14,1+0f
	push	{r14}
	bl	rmark_stack_node
0:
	add	r5,r5,#4
	lao	r7,end_vector,17
	ldo	r7,r7,end_vector,17
	cmp	r5,r7
	bne	rmark_more_stack_nodes
	pop	{pc}

rmark_stack_node:
	subs	sp,sp,#8
	str	r1,[r5]
	str	r5,[sp,#4]
	mov	r0,#-1
	mov	r7,#0
	str	r7,[sp]
	str	r5,[r2]
	b	rmark_no_reverse

rmark_node_d1:
	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_node

	b	rmark_node_

rmark_hnf_2:
	add	r0,r2,#4
	ldr	r1,[r2,#4]
	sub	sp,sp,#8

	mov	r5,r2
	ldr	r2,[r2]

	str	r0,[sp,#4]
	str	r1,[sp]	

	cmp	sp,r8
	blo	rmark_using_reversal

rmark_node:
	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_node

	mov	r0,r5

rmark_node_:
	lsr	r3,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	ldr	r4,[r6,r3,lsl #2]
	mov	r7,#1
	lsl	r1,r7,r1
	tst	r4,r1
	bne	rmark_reverse_and_mark_next_node

	orr	r4,r4,r1
	str	r4,[r6,r3,lsl #2]

	ldr	r1,[r2]
rmark_arguments:
	cmp	r2,r0
	bhi	rmark_no_reverse

	str	r1,[r5]
	str	r5,[r2]

rmark_no_reverse:
	tst	r1,#2
	beq	rmark_lazy_node

	ldrh	r4,[r1,#-2]
	tst	r4,r4
	beq	rmark_hnf_0

	add	r2,r2,#4

	cmp	r4,#256
	bhs	rmark_record

	subs	r4,r4,#2
	beq	rmark_hnf_2
	bcc	rmark_hnf_1

rmark_hnf_3:
	ldr	r3,[r2,#4]
rmark_hnf_3_:
	cmp	sp,r8
	blo	rmark_using_reversal_

	sub	r1,r3,r12

	lsr	r0,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r0,lsl #2]
	tst	r1,r7
	bne	rmark_shared_argument_part

	ldr	r7,[r6,r0,lsl #2]	
	orr	r7,r7,r1	
	str	r7,[r6,r0,lsl #2]	

rmark_no_shared_argument_part:
	subs	sp,sp,#8
	str	r2,[sp,#4]
	add	r5,r2,#4
	ldr	r2,[r2]
	add	r3,r3,r4,lsl #2
	str	r2,[sp]

rmark_push_hnf_args:
	ldr	r0,[r3]
	subs	sp,sp,#8
	str	r3,[sp,#4]
	subs	r3,r3,#4
	str	r0,[sp]

	subs	r4,r4,#1
	bgt	rmark_push_hnf_args

	ldr	r2,[r3]

	cmp	r3,r5
	bhi	rmark_no_reverse_argument_pointer

	add	r4,r5,#3
	str	r2,[r5]
	str	r4,[r3]

	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_node

	mov	r0,r3
	b	rmark_node_

rmark_no_reverse_argument_pointer:
	mov	r5,r3
	b	rmark_node

rmark_shared_argument_part:
	cmp	r3,r2
	bhi	rmark_hnf_1

	ldr	r0,[r3]
	add	r1,r2,#4+2+1
	str	r1,[r3]
	str	r0,[r2,#4]
	b	rmark_hnf_1

rmark_record:
	subs	r4,r4,#258
	beq	rmark_record_2
	blo	rmark_record_1

rmark_record_3:
	ldrh	r4,[r1,#-2+2]
	ldr	r3,[r2,#4]
	subs	r4,r4,#1
	blo	rmark_record_3_bb
	beq	rmark_record_3_ab
	subs	r4,r4,#1
	beq	rmark_record_3_aab
	b	rmark_hnf_3_

rmark_record_3_bb:
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
	bhi	rmark_next_node

	adds	r1,r1,r1
	bne	rmark_bit_in_same_word1
	add	r4,r4,#1
	mov	r1,#1
rmark_bit_in_same_word1:
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	beq	rmark_not_yet_linked_bb

	sub	r1,r2,r12

	add	r1,r1,#2*4
	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
rmark_not_yet_linked_bb:
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	ldr	r4,[r3]
	add	r1,r2,#8+2+1
	str	r4,[r2,#8]
	str	r1,[r3]
	b	rmark_next_node

rmark_record_3_ab:
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
	bhi	rmark_hnf_1

	adds	r1,r1,r1
	bne	rmark_bit_in_same_word2
	add	r4,r4,#1
	mov	r1,#1
rmark_bit_in_same_word2:
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	beq	rmark_not_yet_linked_ab

	sub	r1,r2,r12

	add	r1,r1,#4
	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r6,r4,lsl #2]
rmark_not_yet_linked_ab:
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	ldr	r4,[r3]
	add	r1,r2,#4+2+1
	str	r4,[r2,#4]
	str	r1,[r3]
	b	rmark_hnf_1

rmark_record_3_aab:
	cmp	sp,r8
	blo	rmark_using_reversal_

	sub	r1,r3,r12

	lsr	r4,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r7,[r6,r4,lsl #2]
	tst	r1,r7
	bne	rmark_shared_argument_part

	ldr	r7,[r6,r4,lsl #2]
	orr	r7,r7,r1
	str	r7,[r6,r4,lsl #2]

	subs	sp,sp,#8
	str	r2,[sp,#4]
	add	r5,r2,#4
	ldr	r2,[r2]
	str	r2,[sp]

	ldr	r2,[r3]

	cmp	r3,r5
	bhi	rmark_no_reverse_argument_pointer

	add	r4,r5,#3
	str	r2,[r5]
	str	r4,[r3]

	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_node

	mov	r0,r3
	b	rmark_node_

rmark_record_2:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#1
	bhi	rmark_hnf_2
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_record_1:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#0
	bne	rmark_hnf_1
	b	rmark_next_node

rmark_lazy_node_1:
@ selectors:
	bne	rmark_selector_node_1

rmark_hnf_1:
	mov	r5,r2
	ldr	r2,[r2]
	b	rmark_node

@ selectors
rmark_indirection_node:
	subs	r2,r2,#4
	sub	r3,r2,r12

	and	r4,r3,#31*4
	lsr	r3,r3,#7
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r7,[r6,r3,lsl #2]
	bic	r7,r7,r4
	str	r7,[r6,r3,lsl #2]

	mov	r3,r2
	cmp	r2,r0
	ldr	r2,[r2,#4]
	str	r2,[r5]
	bhi	rmark_node_d1
	str	r1,[r3]
	b	rmark_node_d1

rmark_selector_node_1:
	cmp	r4,#(-2)-1
	beq	rmark_indirection_node

	ldr	r3,[r2]
	mov	r9,r0

	sub	r0,r3,r12
	lsr	r0,r0,#2

	cmp	r4,#(-3)-1
	ble	rmark_record_selector_node_1

	and	r4,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r4
	bne	rmark_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmark_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#2
	bls	rmark_small_tuple_or_record

rmark_large_tuple_or_record:
	ldr	r0,[r3,#8]
	sub	r0,r0,r12
	lsr	r0,r0,#2

	and	r4,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r4
	bne	rmark_hnf_1

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
	mov	r0,r9

	cmp	r1,#8
	blt	rmark_tuple_or_record_selector_node_2
	ldr	r3,[r3,#8]
	beq	rmark_tuple_selector_node_2
	add	r2,r1,#-12
	ldr	r2,[r3,r2]
	pop	{r3}
	str	r2,[r5]
	lao	r7,e__system__nind,17
	otoa	r7,e__system__nind,17
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmark_node_d1

rmark_tuple_selector_node_2:
	ldr	r2,[r3]
	pop	{r3}
	str	r2,[r5]
	lao	r7,e__system__nind,18
	otoa	r7,e__system__nind,18
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmark_node_d1

rmark_record_selector_node_1:
	beq	rmark_strict_record_selector_node_1

	and	r4,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r4
	bne	rmark_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmark_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	bls	rmark_small_tuple_or_record

	ldr	r0,[r3,#8]
	sub	r0,r0,r12
	lsr	r0,r0,#2

	and	r4,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r4
	bne	rmark_hnf_1

rmark_small_tuple_or_record:
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
	mov	r0,r9

	cmp	r1,#8
	ble	rmark_tuple_or_record_selector_node_2
	ldr	r3,[r3,#8]
	subs	r1,r1,#12
rmark_tuple_or_record_selector_node_2:
	ldr	r2,[r3,r1]
	pop	{r3}
	str	r2,[r5]
	lao	r7,e__system__nind,19
	otoa	r7,e__system__nind,19
	str	r7,[r3,#-4]
	str	r2,[r3]
	b	rmark_node_d1

rmark_strict_record_selector_node_1:
	and	r4,r0,#31
	lsr	r0,r0,#5
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	tst	r0,r4
	bne	rmark_hnf_1

	ldr	r0,[r3]
	tst	r0,#2
	beq	rmark_hnf_1

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	bls	rmark_select_from_small_record

	ldr	r0,[r3,#8]
	sub	r0,r0,r12

	and	r4,r0,#31*4
	lsr	r0,r0,#7
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4
	ldr	r0,[r6,r0,lsl #2]
	and	r0,r0,r4
	bne	rmark_hnf_1

rmark_select_from_small_record:
	ldr	r0,[r1,#-1-8]
.ifdef PIC
	add	r7,r1,#-8+4
.endif
	subs	r2,r2,#4

	cmp	r2,r9
	bhi	rmark_selector_pointer_not_reversed

.ifdef PIC
	ldrh	r1,[r0,r7]!
.else
	ldrh	r1,[r0,#4]
.endif
	cmp	r1,#8
	ble	rmark_strict_record_selector_node_2
	ldr	r7,[r3,#8]
	add	r1,r1,r7
	ldr	r1,[r1,#-12]
	b	rmark_strict_record_selector_node_3
rmark_strict_record_selector_node_2:
	ldr	r1,[r3,r1]
rmark_strict_record_selector_node_3:
	str	r1,[r2,#4]

.ifdef PIC
	ldrh	r1,[r0,#6-4]
.else
	ldrh	r1,[r0,#6]
.endif
	tst	r1,r1
	beq	rmark_strict_record_selector_node_5
	cmp	r1,#8
	ble	rmark_strict_record_selector_node_4
	ldr	r3,[r3,#8]
	sub	r1,r1,#12
rmark_strict_record_selector_node_4:
	ldr	r1,[r3,r1]
	str	r1,[r2,#8]
rmark_strict_record_selector_node_5:

.ifdef PIC
	ldr	r1,[r0,#-4-4]
.else
	ldr	r1,[r0,#-4]
.endif
	str	r5,[r2]
	str	r1,[r5]
	b	rmark_next_node

rmark_selector_pointer_not_reversed:
.ifdef PIC
	ldrh	r1,[r0,r7]!
.else
	ldrh	r1,[r0,#4]
.endif
	cmp	r1,#8
	ble	rmark_strict_record_selector_node_6
	ldr	r7,[r3,#8]
	add	r1,r1,r7
	ldr	r1,[r1,#-12]
	b	rmark_strict_record_selector_node_7
rmark_strict_record_selector_node_6:
	ldr	r1,[r3,r1]
rmark_strict_record_selector_node_7:
	str	r1,[r2,#4]

.ifdef PIC
	ldrh	r1,[r0,#6-4]
.else
	ldrh	r1,[r0,#6]
.endif
	tst	r1,r1
	beq	rmark_strict_record_selector_node_9
	cmp	r1,#8
	ble	rmark_strict_record_selector_node_8
	ldr	r3,[r3,#8]
	subs	r1,r1,#12
rmark_strict_record_selector_node_8:
	ldr	r1,[r3,r1]
	str	r1,[r2,#8]
rmark_strict_record_selector_node_9:

.ifdef PIC
	ldr	r1,[r0,#-4-4]
.else
	ldr	r1,[r0,#-4]
.endif
	str	r1,[r2]
	b	rmark_next_node

rmark_reverse_and_mark_next_node:
	cmp	r2,r0
	bhi	rmark_next_node

	ldr	r1,[r2]
	str	r1,[r5]
	str	r5,[r2]

@ a2,d1: free

rmark_next_node:
	ldr	r2,[sp]
	ldr	r5,[sp,#4]
	add	sp,sp,#8

	cmp	r2,#1
	bhi	rmark_node

rmark_next_node_:
end_rmark_nodes:
	pop	{pc}

rmark_lazy_node:
	ldr	r4,[r1,#-1-4]
	cmp	r4,#0
	beq	rmark_next_node

	add	r2,r2,#4

	subs	r4,r4,#1
	ble	rmark_lazy_node_1

	cmp	r4,#255
	bge	rmark_closure_with_unboxed_arguments

rmark_closure_with_unboxed_arguments_:
	add	r2,r2,r4,lsl #2

rmark_push_lazy_args:
	ldr	r0,[r2]
	sub	sp,sp,#8
	str	r2,[sp,#4]
	sub	r2,r2,#4
	str	r0,[sp]
	subs	r4,r4,#1
	bgt	rmark_push_lazy_args

	mov	r5,r2
	ldr	r2,[r2]
	cmp	sp,r8
	bhs	rmark_node

	b	rmark_using_reversal

rmark_closure_with_unboxed_arguments:
@ (a_size+b_size)+(b_size<<8)
@	addl	$1,a2
	mov	r1,r4
	and	r4,r4,#255
	lsr	r1,r1,#8
	subs	r4,r4,r1
@	subl	$1,a2
	bgt	rmark_closure_with_unboxed_arguments_
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_hnf_0:
	laol	r7,INT+2,INT_o_2,11
	otoa	r7,INT_o_2,11
	cmp	r1,r7
	beq	rmark_int_3

	laol	r7,CHAR+2,CHAR_o_2,6
	otoa	r7,CHAR_o_2,6
	cmp	r1,r7
 	beq	rmark_char_3

	blo	rmark_no_normal_hnf_0

	sub	r4,r2,r12

	and	r3,r4,#31*4
	lsr	r4,r4,#7
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	ldr	r7,[r6,r4,lsl #2]
	bic	r7,r7,r3
	str	r7,[r6,r4,lsl #2]

	add	r3,r1,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	str	r3,[r5]
	cmp	r2,r0
	bhi	rmark_next_node
	str	r1,[r2]
	b	rmark_next_node

rmark_int_3:
	ldr	r4,[r2,#4]
	cmp	r4,#33
	bcs	rmark_next_node

	lao	r7,small_integers,3
	otoa	r7,small_integers,3
	add	r3,r7,r4,lsl #3
	str	r3,[r5]
	sub	r4,r2,r12

	and	r3,r4,#31*4
	lsr	r4,r4,#7
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	ldr	r7,[r6,r4,lsl #2]
	bic	r7,r7,r3
	str	r7,[r6,r4,lsl #2]

	cmp	r2,r0
	bhi	rmark_next_node
	str	r1,[r2]
	b	rmark_next_node

rmark_char_3:
	ldrb	r3,[r2,#4]

	lao	r7,static_characters,3
	otoa	r7,static_characters,3
	add	r3,r7,r3,lsl #3
	sub	r4,r2,r12

	str	r3,[r5]

	and	r3,r4,#31*4
	lsr	r4,r4,#7
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	ldr	r7,[r6,r4,lsl #2]
	bic	r7,r7,r3
	str	r7,[r6,r4,lsl #2]

	cmp	r2,r0
	bhi	rmark_next_node
	str	r1,[r2]
	b	rmark_next_node

rmark_no_normal_hnf_0:
	laol	r7,__ARRAY__+2,__ARRAY___o_2,17
	otoa	r7,__ARRAY___o_2,17
	cmp	r1,r7
	bne	rmark_next_node

	ldr	r1,[r2,#8]
	tst	r1,r1
	beq	rmark_lazy_array

	ldrh	r3,[r1,#-2+2]
	tst	r3,r3
	beq	rmark_b_array

	ldrh	r1,[r1,#-2]
	tst	r1,r1
	beq	rmark_b_array

	cmp	sp,r8
	blo	rmark_array_using_reversal

	subs	r1,r1,#256
	cmp	r3,r1
	mov	r0,r3
	beq	rmark_a_record_array

rmark_ab_record_array:
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
	b	rmark_lr_array

rmark_b_array:
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
	b	rmark_next_node

rmark_a_record_array:
	ldr	r1,[r2,#4]
	add	r2,r2,#8
	cmp	r0,#2
	blo	rmark_lr_array

	mul	r1,r0,r1
	b	rmark_lr_array

rmark_lazy_array:
	cmp	sp,r8
	blo	rmark_array_using_reversal

	ldr	r1,[r2,#4]
	add	r2,r2,#8

rmark_lr_array:
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
	bls	rmark_array_length_0_1
	mov	r3,r2
	add	r2,r2,r1,lsl #2

	ldr	r1,[r2]
	ldr	r0,[r3]
	str	r1,[r3]
	str	r0,[r2]

	ldr	r1,[r2,#-4]!
	ldr	r0,[r3,#-4]!
	str	r0,[r2]
	str	r1,[r3]
	push	{r2}
	mov	r5,r3
	b	rmark_array_nodes

rmark_array_nodes1:
	cmp	r2,r5
	bhi	rmark_next_array_node

	ldr	r0,[r2]
	str	r0,[r5]
	str	r5,[r2]

rmark_next_array_node:
	add	r5,r5,#4
	ldr	r7,[sp]
	cmp	r5,r7
	beq	end_rmark_array_node

rmark_array_nodes:
	ldr	r2,[r5]

	sub	r1,r2,r12
	cmp	r1,r10
	bcs	rmark_next_array_node

	lsr	r0,r1,#7
	lsr	r1,r1,#2
	and	r1,r1,#31
	mov	r7,#1
	lsl	r1,r7,r1
	ldr	r4,[r6,r0,lsl #2]
	tst	r4,r1
	bne	rmark_array_nodes1

	orr	r4,r4,r1
	str	r4,[r6,r0,lsl #2]

	ldr	r1,[r2]
	adr	r14,1+0f
	push	{r14}
	bl	rmark_array_node
0:
	add	r5,r5,#4
	ldr	r7,[sp]
	cmp	r5,r7
	bne	rmark_array_nodes

end_rmark_array_node:
	add	sp,sp,#4
	b	rmark_next_node

rmark_array_node:
	sub	sp,sp,#8
	str	r5,[sp,#4]
	mov	r0,r5
	mov	r7,#1
	str	r7,[sp]
	b	rmark_arguments

rmark_array_length_0_1:
	add	r2,r2,#-8
	blo	rmark_next_node

	ldr	r0,[r2,#12]
	ldr	r4,[r2,#8]
	str	r4,[r2,#12]
	ldr	r4,[r2,#4]
	str	r4,[r2,#8]
	str	r0,[r2,#4]
	add	r2,r2,#4
	b	rmark_hnf_1

.ifdef PIC
	lto	end_vector,16
	lto	end_vector,17
	lto	e__system__nind,17
	lto	e__system__nind,18
	lto	e__system__nind,19
	ltol	INT+2,INT_o_2,11
	ltol	CHAR+2,CHAR_o_2,6
	lto	small_integers,3
	lto	static_characters,3
	ltol	__ARRAY__+2,__ARRAY___o_2,17
.endif
	.ltorg
