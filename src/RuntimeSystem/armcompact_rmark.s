
ZERO_ARITY_DESCRIPTOR_OFFSET = -4

rmark_stack_nodes1:
	ldr	r3,[r6]
	add	r4,r9,#1
	str	r3,[r9]
	str	r4,[r6]

rmark_next_stack_node:
	add	r9,r9,#4
rmark_stack_nodes:
	lao	r12,end_vector,16
	ldo	r12,r12,end_vector,16
	cmp	r9,r12
	beq	end_rmark_nodes

rmark_more_stack_nodes:
	ldr	r6,[r9]

	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_stack_node

	lsr	r3,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r8,[r10,r3,lsl #2]
	tst	r8,r4
	bne	rmark_stack_nodes1

	orr	r8,r8,r4
	str	r8,[r10,r3,lsl #2]

	ldr	r4,[r6]
	str	pc,[sp,#-4]!
	bl	rmark_stack_node

	add	r9,r9,#4
	lao	r12,end_vector,17
	ldo	r12,r12,end_vector,17
	cmp	r9,r12
	bne	rmark_more_stack_nodes
	ldr	pc,[sp],#4

rmark_stack_node:
	subs	sp,sp,#8
	str	r4,[r9]
	add	r8,r9,#1
	str	r9,[sp,#4]
	mov	r3,#-1
	mov	r12,#0
	str	r12,[sp]
	str	r8,[r6]
	b	rmark_no_reverse

rmark_node_d1:
	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_node

	b	rmark_node_

rmark_hnf_2:
	add	r3,r6,#4
	ldr	r4,[r6,#4]
	sub	sp,sp,#8

	mov	r9,r6
	ldr	r6,[r6]

	str	r3,[sp,#4]
	str	r4,[sp]	

	cmp	sp,r0
	blo	rmark_using_reversal

rmark_node:
	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_node

	mov	r3,r9

rmark_node_:
	lsr	r7,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	ldr	r8,[r10,r7,lsl #2]
	mov	r12,#1
	lsl	r4,r12,r4
	tst	r8,r4
	bne	rmark_reverse_and_mark_next_node

	orr	r8,r8,r4
	str	r8,[r10,r7,lsl #2]

	ldr	r4,[r6]
rmark_arguments:
	cmp	r6,r3
	bhi	rmark_no_reverse

	add	r8,r9,#1
	str	r4,[r9]
	str	r8,[r6]

rmark_no_reverse:
	tst	r4,#2
	beq	rmark_lazy_node

	ldrh	r8,[r4,#-2]
	cmp	r8,#0
	beq	rmark_hnf_0

	add	r6,r6,#4

	cmp	r8,#256
	bhs	rmark_record

	subs	r8,r8,#2
	beq	rmark_hnf_2
	bcc	rmark_hnf_1

rmark_hnf_3:
	ldr	r7,[r6,#4]
rmark_hnf_3_:
	cmp	sp,r0
	blo	rmark_using_reversal_

	sub	r4,r7,r11

	lsr	r3,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r3,lsl #2]
	tst	r4,r12
	bne	rmark_shared_argument_part

	ldr	r12,[r10,r3,lsl #2]	
	orr	r12,r12,r4	
	str	r12,[r10,r3,lsl #2]	

rmark_no_shared_argument_part:
	subs	sp,sp,#8
	str	r6,[sp,#4]
	add	r9,r6,#4
	ldr	r6,[r6]
	add	r7,r7,r8,lsl #2
	str	r6,[sp]

rmark_push_hnf_args:
	ldr	r3,[r7]
	subs	sp,sp,#8
	str	r7,[sp,#4]
	subs	r7,r7,#4
	str	r3,[sp]

	subs	r8,r8,#1
	bgt	rmark_push_hnf_args

	ldr	r6,[r7]

	cmp	r7,r9
	bhi	rmark_no_reverse_argument_pointer

	add	r8,r9,#3
	str	r6,[r9]
	str	r8,[r7]

	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_node

	mov	r3,r7
	b	rmark_node_

rmark_no_reverse_argument_pointer:
	mov	r9,r7
	b	rmark_node

rmark_shared_argument_part:
	cmp	r7,r6
	bhi	rmark_hnf_1

	ldr	r3,[r7]
	add	r4,r6,#4+2+1
	str	r4,[r7]
	str	r3,[r6,#4]
	b	rmark_hnf_1

rmark_record:
	mov	r12,#258/2
	subs	r8,r8,r12,lsl #1
	beq	rmark_record_2
	blo	rmark_record_1

rmark_record_3:
	ldrh	r8,[r4,#-2+2]
	ldr	r7,[r6,#4]
	subs	r8,r8,#1
	blo	rmark_record_3_bb
	beq	rmark_record_3_ab
	subs	r8,r8,#1
	beq	rmark_record_3_aab
	b	rmark_hnf_3_

rmark_record_3_bb:
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
	bhi	rmark_next_node

	adds	r4,r4,r4
	bne	rmark_bit_in_same_word1
	add	r8,r8,#1
	mov	r4,#1
rmark_bit_in_same_word1:
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	beq	rmark_not_yet_linked_bb

	sub	r4,r6,r11

	add	r4,r4,#2*4
	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
rmark_not_yet_linked_bb:
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	ldr	r8,[r7]
	add	r4,r6,#8+2+1
	str	r8,[r6,#8]
	str	r4,[r7]
	b	rmark_next_node

rmark_record_3_ab:
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
	bhi	rmark_hnf_1

	adds	r4,r4,r4
	bne	rmark_bit_in_same_word2
	add	r8,r8,#1
	mov	r4,#1
rmark_bit_in_same_word2:
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	beq	rmark_not_yet_linked_ab

	sub	r4,r6,r11

	add	r4,r4,#4
	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4

	ldr	r12,[r10,r8,lsl #2]
rmark_not_yet_linked_ab:
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	ldr	r8,[r7]
	add	r4,r6,#4+2+1
	str	r8,[r6,#4]
	str	r4,[r7]
	b	rmark_hnf_1

rmark_record_3_aab:
	cmp	sp,r0
	blo	rmark_using_reversal_

	sub	r4,r7,r11

	lsr	r8,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r12,[r10,r8,lsl #2]
	tst	r4,r12
	bne	rmark_shared_argument_part

	ldr	r12,[r10,r8,lsl #2]
	orr	r12,r12,r4
	str	r12,[r10,r8,lsl #2]

	subs	sp,sp,#8
	str	r6,[sp,#4]
	add	r9,r6,#4
	ldr	r6,[r6]
	str	r6,[sp]

	ldr	r6,[r7]

	cmp	r7,r9
	bhi	rmark_no_reverse_argument_pointer

	add	r8,r9,#3
	str	r6,[r9]
	str	r8,[r7]

	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_node

	mov	r3,r7
	b	rmark_node_

rmark_record_2:
	ldrh	r12,[r4,#-2+2]
	cmp	r12,#1
	bhi	rmark_hnf_2
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_record_1:
	ldrh	r12,[r4,#-2+2]
	cmp	r12,#0
	bne	rmark_hnf_1
	b	rmark_next_node

rmark_lazy_node_1:
@ selectors:
	bne	rmark_selector_node_1

rmark_hnf_1:
	mov	r9,r6
	ldr	r6,[r6]
	b	rmark_node

@ selectors
rmark_indirection_node:
	subs	r6,r6,#4
	sub	r7,r6,r11

	and	r8,r7,#31*4
	lsr	r7,r7,#7
	lsr	r8,r8,#2
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r12,[r10,r7,lsl #2]
	bic	r12,r12,r8
	str	r12,[r10,r7,lsl #2]

	mov	r7,r6
	cmp	r6,r3
	ldr	r6,[r6,#4]
	str	r6,[r9]
	bhi	rmark_node_d1
	str	r4,[r7]
	b	rmark_node_d1

rmark_selector_node_1:
	cmp	r8,#(-2)-1
	beq	rmark_indirection_node

	ldr	r7,[r6]
	mov	r1,r3

	sub	r3,r7,r11
	lsr	r3,r3,#2

	cmp	r8,#(-3)-1
	ble	rmark_record_selector_node_1

	and	r8,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmark_hnf_1

	ldrh	r12,[r3,#-2]
	cmp	r12,#2
	bls	rmark_small_tuple_or_record

rmark_large_tuple_or_record:
	ldr	r3,[r7,#8]
	sub	r3,r3,r11
	lsr	r3,r3,#2

	and	r8,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

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
	mov	r3,r1

	cmp	r4,#8
	blt	rmark_tuple_or_record_selector_node_2
	ldr	r7,[r7,#8]
	beq	rmark_tuple_selector_node_2
	add	r6,r4,#-12
	ldr	r6,[r7,r6]
	ldr	r7,[sp],#4
	str	r6,[r9]
	lao	r12,e__system__nind,17
	otoa	r12,e__system__nind,17
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmark_node_d1

rmark_tuple_selector_node_2:
	ldr	r6,[r7]
	ldr	r7,[sp],#4
	str	r6,[r9]
	lao	r12,e__system__nind,18
	otoa	r12,e__system__nind,18
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmark_node_d1

rmark_record_selector_node_1:
	beq	rmark_strict_record_selector_node_1

	and	r8,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmark_hnf_1

	ldrh	r12,[r3,#-2]
	mov	r3,#258/2
	cmp	r12,r3,lsl #1
	bls	rmark_small_tuple_or_record

	ldr	r3,[r7,#8]
	sub	r3,r3,r11
	lsr	r3,r3,#2

	and	r8,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

rmark_small_tuple_or_record:
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
	mov	r3,r1

	cmp	r4,#8
	ble	rmark_tuple_or_record_selector_node_2
	ldr	r7,[r7,#8]
	subs	r4,r4,#12
rmark_tuple_or_record_selector_node_2:
	ldr	r6,[r7,r4]
	ldr	r7,[sp],#4
	str	r6,[r9]
	lao	r12,e__system__nind,19
	otoa	r12,e__system__nind,19
	str	r12,[r7,#-4]
	str	r6,[r7]
	b	rmark_node_d1

rmark_strict_record_selector_node_1:
	and	r8,r3,#31
	lsr	r3,r3,#5
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

	ldr	r3,[r7]
	tst	r3,#2
	beq	rmark_hnf_1

	ldrh	r12,[r3,#-2]
	mov	r3,#258/2
	cmp	r12,r3,lsl #1
	bls	rmark_select_from_small_record

	ldr	r3,[r7,#8]
	sub	r3,r3,r11

	and	r8,r3,#31*4
	lsr	r3,r3,#7
	lsr	r8,r8,#2
	mov	r12,#1
	lsl	r8,r12,r8
	ldr	r3,[r10,r3,lsl #2]
	tst	r3,r8
	bne	rmark_hnf_1

rmark_select_from_small_record:
	ldr	r3,[r4,#-8]
.ifdef PIC
	add	r12,r4,#-8+4
.endif
	subs	r6,r6,#4

	cmp	r6,r1
	bhi	rmark_selector_pointer_not_reversed

.ifdef PIC
	ldrh	r4,[r3,r12]!
.else
	ldrh	r4,[r3,#4]
.endif
	cmp	r4,#8
	ble	rmark_strict_record_selector_node_2
	ldr	r12,[r7,#8]
	add	r4,r4,r12
	ldr	r4,[r4,#-12]
	b	rmark_strict_record_selector_node_3
rmark_strict_record_selector_node_2:
	ldr	r4,[r7,r4]
rmark_strict_record_selector_node_3:
	str	r4,[r6,#4]

.ifdef PIC
	ldrh	r4,[r3,#6-4]
.else
	ldrh	r4,[r3,#6]
.endif
	cmp	r4,#0
	beq	rmark_strict_record_selector_node_5
	cmp	r4,#8
	ble	rmark_strict_record_selector_node_4
	ldr	r7,[r7,#8]
	sub	r4,r4,#12
rmark_strict_record_selector_node_4:
	ldr	r4,[r7,r4]
	str	r4,[r6,#8]
rmark_strict_record_selector_node_5:

.ifdef PIC
	ldr	r4,[r3,#-4-4]
.else
	ldr	r4,[r3,#-4]
.endif
	add	r9,r9,#1
	str	r9,[r6]
	str	r4,[r9,#-1]
	b	rmark_next_node

rmark_selector_pointer_not_reversed:
.ifdef PIC
	ldrh	r4,[r3,r12]!
.else
	ldrh	r4,[r3,#4]
.endif
	cmp	r4,#8
	ble	rmark_strict_record_selector_node_6
	ldr	r12,[r7,#8]
	add	r4,r4,r12
	ldr	r4,[r4,#-12]
	b	rmark_strict_record_selector_node_7
rmark_strict_record_selector_node_6:
	ldr	r4,[r7,r4]
rmark_strict_record_selector_node_7:
	str	r4,[r6,#4]

.ifdef PIC
	ldrh	r4,[r3,#6-4]
.else
	ldrh	r4,[r3,#6]
.endif
	cmp	r4,#0
	beq	rmark_strict_record_selector_node_9
	cmp	r4,#8
	ble	rmark_strict_record_selector_node_8
	ldr	r7,[r7,#8]
	subs	r4,r4,#12
rmark_strict_record_selector_node_8:
	ldr	r4,[r7,r4]
	str	r4,[r6,#8]
rmark_strict_record_selector_node_9:

.ifdef PIC
	ldr	r4,[r3,#-4-4]
.else
	ldr	r4,[r3,#-4]
.endif
	str	r4,[r6]
	b	rmark_next_node

rmark_reverse_and_mark_next_node:
	cmp	r6,r3
	bhi	rmark_next_node

	ldr	r4,[r6]
	str	r4,[r9]
	add	r9,r9,#1
	str	r9,[r6]

@ a2,d1: free

rmark_next_node:
	ldr	r6,[sp]
	ldr	r9,[sp,#4]
	add	sp,sp,#8

	cmp	r6,#1
	bhi	rmark_node

rmark_next_node_:
end_rmark_nodes:
	ldr	pc,[sp],#4

rmark_lazy_node:
	ldr	r8,[r4,#-4]
	cmp	r8,#0
	beq	rmark_next_node

	add	r6,r6,#4

	subs	r8,r8,#1
	ble	rmark_lazy_node_1

	cmp	r8,#255
	bge	rmark_closure_with_unboxed_arguments

rmark_closure_with_unboxed_arguments_:
	add	r6,r6,r8,lsl #2

rmark_push_lazy_args:
	ldr	r3,[r6]
	sub	sp,sp,#8
	str	r6,[sp,#4]
	sub	r6,r6,#4
	str	r3,[sp]
	subs	r8,r8,#1
	bgt	rmark_push_lazy_args

	mov	r9,r6
	ldr	r6,[r6]
	cmp	sp,r0
	bhs	rmark_node

	b	rmark_using_reversal

rmark_closure_with_unboxed_arguments:
@ (a_size+b_size)+(b_size<<8)
@	addl	$1,a2
	mov	r4,r8
	and	r8,r8,#255
	lsr	r4,r4,#8
	subs	r8,r8,r4
@	subl	$1,a2
	bgt	rmark_closure_with_unboxed_arguments_
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_hnf_0:
	laol	r12,INT+2,INT_o_2,11
	otoa	r12,INT_o_2,11
	cmp	r4,r12
	beq	rmark_int_3

	laol	r12,CHAR+2,CHAR_o_2,6
	otoa	r12,CHAR_o_2,6
	cmp	r4,r12
 	beq	rmark_char_3

	blo	rmark_no_normal_hnf_0

	sub	r8,r6,r11

	and	r7,r8,#31*4
	lsr	r8,r8,#7
	lsr	r7,r7,#2
	mov	r12,#1
	lsl	r7,r12,r7
	ldr	r12,[r10,r8,lsl #2]
	bic	r12,r12,r7
	str	r12,[r10,r8,lsl #2]

	add	r7,r4,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	str	r7,[r9]
	cmp	r6,r3
	bhi	rmark_next_node
	str	r4,[r6]
	b	rmark_next_node

rmark_int_3:
	ldr	r8,[r6,#4]
	cmp	r8,#33
	bcs	rmark_next_node

	lao	r12,small_integers,3
	otoa	r12,small_integers,3
	add	r7,r12,r8,lsl #3
	str	r7,[r9]
	sub	r8,r6,r11

	and	r7,r8,#31*4
	lsr	r8,r8,#7
	lsr	r7,r7,#2
	mov	r12,#1
	lsl	r7,r12,r7
	ldr	r12,[r10,r8,lsl #2]
	bic	r12,r12,r7
	str	r12,[r10,r8,lsl #2]

	cmp	r6,r3
	bhi	rmark_next_node
	str	r4,[r6]
	b	rmark_next_node

rmark_char_3:
	ldrb	r7,[r6,#4]

	lao	r12,static_characters,3
	otoa	r12,static_characters,3
	add	r7,r12,r7,lsl #3
	sub	r8,r6,r11

	str	r7,[r9]

	and	r7,r8,#31*4
	lsr	r8,r8,#7
	lsr	r7,r7,#2
	mov	r12,#1
	lsl	r7,r12,r7
	ldr	r12,[r10,r8,lsl #2]
	bic	r12,r12,r7
	str	r12,[r10,r8,lsl #2]

	cmp	r6,r3
	bhi	rmark_next_node
	str	r4,[r6]
	b	rmark_next_node

rmark_no_normal_hnf_0:
	laol	r12,__ARRAY__+2,__ARRAY___o_2,17
	otoa	r12,__ARRAY___o_2,17
	cmp	r4,r12
	bne	rmark_next_node

	ldr	r4,[r6,#8]
	cmp	r4,#0
	beq	rmark_lazy_array

	ldrh	r7,[r4,#-2+2]
	tst	r7,r7
	beq	rmark_b_array

	ldrh	r4,[r4,#-2]
	cmp	r4,#0
	beq	rmark_b_array

	cmp	sp,r0
	blo	rmark_array_using_reversal

	subs	r4,r4,#256
	cmp	r7,r4
	mov	r3,r7
	beq	rmark_a_record_array

rmark_ab_record_array:
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
	b	rmark_lr_array

rmark_b_array:
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
	b	rmark_next_node

rmark_a_record_array:
	ldr	r4,[r6,#4]
	add	r6,r6,#8
	cmp	r3,#2
	blo	rmark_lr_array

	mul	r4,r3,r4
	b	rmark_lr_array

rmark_lazy_array:
	cmp	sp,r0
	blo	rmark_array_using_reversal

	ldr	r4,[r6,#4]
	add	r6,r6,#8

rmark_lr_array:
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
	bls	rmark_array_length_0_1
	mov	r7,r6
	add	r6,r6,r4,lsl #2

	ldr	r4,[r6]
	ldr	r3,[r7]
	str	r4,[r7]
	str	r3,[r6]

	ldr	r4,[r6,#-4]!
	ldr	r3,[r7,#-4]!
	str	r3,[r6]
	str	r4,[r7]
	str	r6,[sp,#-4]!
	mov	r9,r7
	b	rmark_array_nodes

rmark_array_nodes1:
	cmp	r6,r9
	bhi	rmark_next_array_node

	ldr	r3,[r6]
	add	r4,r9,#1
	str	r3,[r9]
	str	r4,[r6]

rmark_next_array_node:
	add	r9,r9,#4
	ldr	r12,[sp]
	cmp	r9,r12
	beq	end_rmark_array_node

rmark_array_nodes:
	ldr	r6,[r9]

	sub	r4,r6,r11
	cmp	r4,r2
	bcs	rmark_next_array_node

	lsr	r3,r4,#7
	lsr	r4,r4,#2
	and	r4,r4,#31
	mov	r12,#1
	lsl	r4,r12,r4
	ldr	r8,[r10,r3,lsl #2]
	tst	r8,r4
	bne	rmark_array_nodes1

	orr	r8,r8,r4
	str	r8,[r10,r3,lsl #2]

	ldr	r4,[r6]
	str	pc,[sp,#-4]!
	bl	rmark_array_node

	add	r9,r9,#4
	ldr	r12,[sp]
	cmp	r9,r12
	bne	rmark_array_nodes

end_rmark_array_node:
	add	sp,sp,#4
	b	rmark_next_node

rmark_array_node:
	sub	sp,sp,#8
	str	r9,[sp,#4]
	mov	r3,r9
	mov	r12,#1
	str	r12,[sp]
	b	rmark_arguments

rmark_array_length_0_1:
	add	r6,r6,#-8
	blo	rmark_next_node

	ldr	r3,[r6,#12]
	ldr	r8,[r6,#8]
	str	r8,[r6,#12]
	ldr	r8,[r6,#4]
	str	r8,[r6,#8]
	str	r3,[r6,#4]
	add	r6,r6,#4
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
