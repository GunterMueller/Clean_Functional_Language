
ZERO_ARITY_DESCRIPTOR_OFFSET = -8

rmark_stack_nodes1:
	ldr	x3,[x8]
	add	x4,x7,#1
	str	x3,[x7]
	str	x4,[x8]

rmark_next_stack_node:
	add	x7,x7,#8
rmark_stack_nodes:
	cmp	x7,x5 // end_vector
	beq	end_rmark_nodes

rmark_more_stack_nodes:
	ldr	x8,[x7]

	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_stack_node

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w10,[x27,x3,lsl #2]
	tst	x10,x4
	bne	rmark_stack_nodes1

	orr	x10,x10,x4
	str	w10,[x27,x3,lsl #2]

	ldr	x4,[x8]

	str	x30,[x28,#-8]!
	bl	rmark_stack_node

	add	x7,x7,#8
	cmp	x7,x5 // end_vector
	bne	rmark_more_stack_nodes

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

rmark_stack_node:
	str	x4,[x7]
	add	x10,x7,#1
	stp	xzr,x7,[x28,#-16]!
	mov	x3,#-1
	str	x10,[x8]
	b	rmark_no_reverse

rmark_node_d1:
	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_node

	b	rmark_node_

rmark_hnf_2:
	add	x3,x8,#8
	ldr	x4,[x8,#8]

	mov	x7,x8
	ldr	x8,[x8]

	stp	x4,x3,[x28,#-16]!

	cmp	x28,x0
	blo	rmark_using_reversal

rmark_node:
	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_node

	mov	x3,x7

rmark_node_:
	lsr	x9,x4,#8
	ubfx	x4,x4,#3,#5
	ldr	w10,[x27,x9,lsl #2]
	mov	x16,#1
	lsl	x4,x16,x4
	tst	x10,x4
	bne	rmark_reverse_and_mark_next_node

	orr	x10,x10,x4
	str	w10,[x27,x9,lsl #2]

	ldr	x4,[x8]
rmark_arguments:
	cmp	x8,x3
	bhi	rmark_no_reverse

	add	x10,x7,#1
	str	x4,[x7]
	str	x10,[x8]

rmark_no_reverse:
	tbz	x4,#1,rmark_lazy_node

	ldrh	w10,[x4,#-2]
	cbz	x10,rmark_hnf_0

	add	x8,x8,#8

	cmp	x10,#256
	bhs	rmark_record

	subs	x10,x10,#2
	beq	rmark_hnf_2
	bcc	rmark_hnf_1

rmark_hnf_3:
	ldr	x9,[x8,#8]
rmark_hnf_3_:
	cmp	x28,x0
	blo	rmark_using_reversal_

	sub	x4,x9,x11

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x3,lsl #2]
	tst	x4,x16
	bne	rmark_shared_argument_part

	orr	x16,x16,x4	
	str	w16,[x27,x3,lsl #2]	

rmark_no_shared_argument_part:
	str	x8,[x28,#-8]
	add	x7,x8,#8
	ldr	x8,[x8]
	add	x9,x9,x10,lsl #3
	str	x8,[x28,#-16]!

rmark_push_hnf_args:
	ldr	x3,[x9]
	stp	x3,x9,[x28,#-16]!
	sub	x9,x9,#8

	subs	x10,x10,#1
	bgt	rmark_push_hnf_args

	ldr	x8,[x9]

	cmp	x9,x7
	bhi	rmark_no_reverse_argument_pointer

	add	x10,x7,#3
	str	x8,[x7]
	str	x10,[x9]

	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_node

	mov	x3,x9
	b	rmark_node_

rmark_no_reverse_argument_pointer:
	mov	x7,x9
	b	rmark_node

rmark_shared_argument_part:
	cmp	x9,x8
	bhi	rmark_hnf_1

	ldr	x3,[x9]
	add	x4,x8,#8+2+1
	str	x4,[x9]
	str	x3,[x8,#8]
	b	rmark_hnf_1

rmark_record:
	subs	x10,x10,#258
	beq	rmark_record_2
	blo	rmark_record_1

rmark_record_3:
	ldrh	w10,[x4,#-2+2]
	ldr	x9,[x8,#8]
	subs	x10,x10,#1
	blo	rmark_record_3_bb
	beq	rmark_record_3_ab
	subs	x10,x10,#1
	beq	rmark_record_3_aab
	b	rmark_hnf_3_

rmark_record_3_bb:
	sub	x8,x8,#8

	sub	x4,x9,x11

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	cmp	x9,x8
	bhi	rmark_next_node

	adds	w4,w4,w4
	bne	rmark_bit_in_same_word1
	add	x10,x10,#1
	mov	x4,#1
rmark_bit_in_same_word1:
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	beq	rmark_not_yet_linked_bb

	sub	x4,x8,x11

	add	x4,x4,#2*8
	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
rmark_not_yet_linked_bb:
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x10,[x9]
	add	x4,x8,#16+2+1
	str	x10,[x8,#16]
	str	x4,[x9]
	b	rmark_next_node

rmark_record_3_ab:
	sub	x4,x9,x11

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	cmp	x9,x8
	bhi	rmark_hnf_1

	adds	w4,w4,w4
	bne	rmark_bit_in_same_word2
	add	x10,x10,#1
	mov	x4,#1
rmark_bit_in_same_word2:
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	beq	rmark_not_yet_linked_ab

	sub	x4,x8,x11

	add	x4,x4,#8
	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4

	ldr	w16,[x27,x10,lsl #2]
rmark_not_yet_linked_ab:
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x10,[x9]
	add	x4,x8,#8+2+1
	str	x10,[x8,#8]
	str	x4,[x9]
	b	rmark_hnf_1

rmark_record_3_aab:
	cmp	x28,x0
	blo	rmark_using_reversal_

	sub	x4,x9,x11

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	bne	rmark_shared_argument_part

	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x16,[x8]
	add	x7,x8,#8
	stp	x16,x8,[x28,#-16]!

	ldr	x8,[x9]

	cmp	x9,x7
	bhi	rmark_no_reverse_argument_pointer

	add	x10,x7,#3
	str	x8,[x7]
	str	x10,[x9]

	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_node

	mov	x3,x9
	b	rmark_node_

rmark_record_2:
	ldrh	w16,[x4,#-2+2]
	cmp	x16,#1
	bhi	rmark_hnf_2
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_record_1:
	ldrh	w16,[x4,#-2+2]
	cbnz	x16,rmark_hnf_1
	b	rmark_next_node

rmark_lazy_node_1:
# selectors:
	bne	rmark_selector_node_1

rmark_hnf_1:
	mov	x7,x8
	ldr	x8,[x8]
	b	rmark_node

# selectors
rmark_indirection_node:
	sub	x8,x8,#8
	sub	x9,x8,x11

	ubfx	x10,x9,#3,#5
	lsr	x9,x9,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w16,[x27,x9,lsl #2]
	bic	x16,x16,x10
	str	w16,[x27,x9,lsl #2]

	mov	x9,x8
	cmp	x8,x3
	ldr	x8,[x8,#8]
	str	x8,[x7]
	bhi	rmark_node_d1
	str	x4,[x9]
	b	rmark_node_d1

rmark_selector_node_1:
	cmp	w10,#(-2)-1
	beq	rmark_indirection_node

	ldr	x9,[x8]
	mov	x1,x3

	sub	x3,x9,x11

	cmp	w10,#(-3)-1
	ble	rmark_record_selector_node_1

	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

	ldr	x3,[x9]
	tbz	x3,#1,rmark_hnf_1

	ldrh	w16,[x3,#-2]
	cmp	x16,#2
	bls	rmark_small_tuple_or_record

rmark_large_tuple_or_record:
	ldr	x3,[x9,#16]
	sub	x3,x3,x11

	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

	add	x16,x8,#-8
	sub	x3,x16,x11

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]

	ubfx	x6,x3,#3,#5
	lsr	x3,x3,#8
.ifdef PIC
	ldrh	w4,[x16,x4]
.endif
	mov	x16,#1
	lsl	x6,x16,x6
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x6
	str	w16,[x27,x3,lsl #2]

.ifndef PIC
	ldrh	w4,[x4,#4]
.endif
	mov	x3,x1

	cmp	x4,#16
	blt	rmark_tuple_or_record_selector_node_2

	ldr	x9,[x9,#16]
	beq	rmark_tuple_selector_node_2

	sub	x4,x4,#24
	mov	x6,x8
	ldr	x8,[x9,x4]
	str	x8,[x7]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x6,#-8]
	str	x8,[x6]
	b	rmark_node_d1

rmark_tuple_selector_node_2:
	mov	x6,x8
	ldr	x8,[x9]
	str	x8,[x7]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x6,#-8]
	str	x8,[x6]
	b	rmark_node_d1

rmark_record_selector_node_1:
	beq	rmark_strict_record_selector_node_1

	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

	ldr	x3,[x9]
	tbz	x3,#1,rmark_hnf_1

	ldrh	w16,[x3,#-2]
	cmp	x16,#258
	bls	rmark_small_tuple_or_record

	ldr	x3,[x9,#16]
	sub	x3,x3,x11

	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

rmark_small_tuple_or_record:
	add	x16,x8,#-8
	sub	x3,x16,x11

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]

	ubfx	x6,x3,#3,#5
	lsr	x3,x3,#8
.ifdef PIC
	ldrh	w4,[x16,x4]
.endif
	mov	x16,#1
	lsl	x6,x16,x6
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x6
	str	w16,[x27,x3,lsl #2]

.ifndef PIC
	ldrh	w4,[x4,#4]
.endif
	mov	x3,x1

	cmp	x4,#16
	ble	rmark_tuple_or_record_selector_node_2
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
rmark_tuple_or_record_selector_node_2:
	mov	x6,x8
	ldr	x8,[x9,x4]
	str	x8,[x7]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x6,#-8]
	str	x8,[x6]
	b	rmark_node_d1

rmark_strict_record_selector_node_1:
	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

	ldr	x3,[x9]
	tbz	x3,#1,rmark_hnf_1

	ldrh	w16,[x3,#-2]
	cmp	x16,#258
	bls	rmark_select_from_small_record

	ldr	x3,[x9,#16]
	sub	x3,x3,x11

	ubfx	x10,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x10,x16,x10
	ldr	w3,[x27,x3,lsl #2]
	tst	x3,x10
	bne	rmark_hnf_1

rmark_select_from_small_record:
	ldr	w3,[x4,#-8]
.ifdef PIC
	add	x16,x4,#-8+4
.endif
	sub	x8,x8,#8

	cmp	x8,x1
	bhi	rmark_selector_pointer_not_reversed

.ifdef PIC
	ldrh	w4,[x3,x16]!
.else
	ldrh	w4,[x3,#4]
.endif
	cmp	x4,#16
	ble	rmark_strict_record_selector_node_2
	ldr	x16,[x9,#16]
	sub	x4,x4,#24
	ldr	x4,[x4,x16]
	b	rmark_strict_record_selector_node_3
rmark_strict_record_selector_node_2:
	ldr	x4,[x9,x4]
rmark_strict_record_selector_node_3:
	str	x4,[x8,#8]

.ifdef PIC
	ldrh	w4,[x3,#6-4]
.else
	ldrh	w4,[x3,#6]
.endif
	cbz	x4,rmark_strict_record_selector_node_5
	cmp	x4,#16
	ble	rmark_strict_record_selector_node_4
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
rmark_strict_record_selector_node_4:
	ldr	x4,[x9,x4]
	str	x4,[x8,#16]
rmark_strict_record_selector_node_5:
	ldr	x4,[x3,#-8]
	add	x7,x7,#1
	str	x7,[x8]
	str	x4,[x7,#-1]
	b	rmark_next_node

rmark_selector_pointer_not_reversed:
.ifdef PIC
	ldrh	w4,[x3,x16]!
.else
	ldrh	w4,[x3,#4]
.endif
	cmp	x4,#16
	ble	rmark_strict_record_selector_node_6
	ldr	x16,[x9,#16]
	sub	x4,x4,#24
	ldr	x4,[x4,x16]
	b	rmark_strict_record_selector_node_7
rmark_strict_record_selector_node_6:
	ldr	x4,[x9,x4]
rmark_strict_record_selector_node_7:
	str	x4,[x8,#8]

.ifdef PIC
	ldrh	w4,[x3,#6-4]
.else
	ldrh	w4,[x3,#6]
.endif
	cbz	x4,rmark_strict_record_selector_node_9
	cmp	x4,#16
	ble	rmark_strict_record_selector_node_8
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
rmark_strict_record_selector_node_8:
	ldr	x4,[x9,x4]
	str	x4,[x8,#16]
rmark_strict_record_selector_node_9:
	ldr	x4,[x3,#-8]
	str	x4,[x8]
	b	rmark_next_node

rmark_reverse_and_mark_next_node:
	cmp	x8,x3
	bhi	rmark_next_node

	ldr	x4,[x8]
	str	x4,[x7]
	add	x7,x7,#1
	str	x7,[x8]

# a2,d1: free

rmark_next_node:
	ldp	x8,x7,[x28],#16

	cmp	x8,#1
	bhi	rmark_node

rmark_next_node_:
end_rmark_nodes:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

rmark_lazy_node:
	ldr	w10,[x4,#-4]
	cbz	x10,rmark_next_node

	add	x8,x8,#8

	subs	w10,w10,#1
	ble	rmark_lazy_node_1

	cmp	x10,#255
	bge	rmark_closure_with_unboxed_arguments

rmark_closure_with_unboxed_arguments_:
	add	x8,x8,x10,lsl #3

rmark_push_lazy_args:
	ldr	x3,[x8]
	subs	x10,x10,#1
	stp	x3,x8,[x28,#-16]!
	sub	x8,x8,#8
	bgt	rmark_push_lazy_args

	mov	x7,x8
	ldr	x8,[x8]
	cmp	x28,x0
	bhs	rmark_node

	b	rmark_using_reversal

rmark_closure_with_unboxed_arguments:
# (a_size+b_size)+(b_size<<8)
#	addl	$1,a2
	lsr	x4,x10,#8
	and	x10,x10,#255
	subs	x10,x10,x4
#	subl	$1,a2
	bgt	rmark_closure_with_unboxed_arguments_
	beq	rmark_hnf_1
	b	rmark_next_node

rmark_hnf_0:
	cmp	x4,x12 // INT+2
	beq	rmark_int_3

	cmp	x4,x13 // CHAR+2
 	beq	rmark_char_3

	blo	rmark_no_normal_hnf_0

	sub	x10,x8,x11

	ubfx	x9,x10,#3,#5
	lsr	x10,x10,#8
	mov	x16,#1
	lsl	x9,x16,x9
	ldr	w16,[x27,x10,lsl #2]
	bic	x16,x16,x9
	str	w16,[x27,x10,lsl #2]

	add	x9,x4,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	str	x9,[x7]
	cmp	x8,x3
	bhi	rmark_next_node
	str	x4,[x8]
	b	rmark_next_node

rmark_int_3:
	ldr	x10,[x8,#8]
	cmp	x10,#33
	bcs	rmark_next_node

	add	x9,x14,x10,lsl #4 // small_integers
	str	x9,[x7]
	sub	x10,x8,x11

	ubfx	x9,x10,#3,#5
	lsr	x10,x10,#8
	mov	x16,#1
	lsl	x9,x16,x9
	ldr	w16,[x27,x10,lsl #2]
	bic	x16,x16,x9
	str	w16,[x27,x10,lsl #2]

	cmp	x8,x3
	bhi	rmark_next_node
	str	x4,[x8]
	b	rmark_next_node

rmark_char_3:
	ldrb	w9,[x8,#8]

	add	x9,x15,x9,lsl #4 // static characters
	sub	x10,x8,x11

	str	x9,[x7]

	ubfx	x9,x10,#3,#5
	lsr	x10,x10,#8
	mov	x16,#1
	lsl	x9,x16,x9
	ldr	w16,[x27,x10,lsl #2]
	bic	x16,x16,x9
	str	w16,[x27,x10,lsl #2]

	cmp	x8,x3
	bhi	rmark_next_node
	str	x4,[x8]
	b	rmark_next_node

rmark_no_normal_hnf_0:
	cmp	x4,x17 // __ARRAY__+2
	bne	rmark_next_node

	ldr	x4,[x8,#16]
	cbz	x4,rmark_lazy_array

	ldrh	w9,[x4,#-2+2]
	cbz	x9,rmark_b_array

	ldrh	w4,[x4,#-2]
	cbz	x4,rmark_b_array

	cmp	x28,x0
	blo	rmark_array_using_reversal

	subs	x4,x4,#256
	cmp	x9,x4
	mov	x3,x9
	beq	rmark_a_record_array

rmark_ab_record_array:
	ldr	x9,[x8,#8]
	add	x8,x8,#16
	str	x8,[x28,#-8]!

	mul	x9,x4,x9
	lsl	x9,x9,#3

	subs	x4,x4,x3
	add	x8,x8,#8
	add	x9,x9,x8

	mov	x29,x30
	bl	reorder
	mov	x30,x29

	ldr	x8,[x28],#8
	mov	x4,x3
	ldr	x16,[x8,#-8]
	mul	x4,x16,x4
	b	rmark_lr_array

rmark_b_array:
	sub	x4,x8,x11

	add	x4,x4,#8

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]
	b	rmark_next_node

rmark_a_record_array:
	ldr	x4,[x8,#8]
	add	x8,x8,#16
	cmp	x3,#2
	blo	rmark_lr_array

	mul	x4,x3,x4
	b	rmark_lr_array

rmark_lazy_array:
	cmp	x28,x0
	blo	rmark_array_using_reversal

	ldr	x4,[x8,#8]
	add	x8,x8,#16

rmark_lr_array:
	sub	x3,x8,x11
	lsr	x3,x3,#3
	add	x3,x3,x4

	lsr	x9,x3,#5
	and	x3,x3,#31
	mov	x16,#1
	lsl	x3,x16,x3
	ldr	w16,[x27,x9,lsl #2]
	orr	x16,x16,x3
	str	w16,[x27,x9,lsl #2]

	cmp	x4,#1
	bls	rmark_array_length_0_1
	mov	x9,x8
	add	x8,x8,x4,lsl #3

	ldr	x4,[x8]
	ldr	x3,[x9]
	str	x4,[x9]
	str	x3,[x8]

	ldr	x4,[x8,#-8]!
	ldr	x3,[x9,#-8]!
	str	x3,[x8]
	str	x4,[x9]
	str	x8,[x28,#-8]!
	mov	x7,x9
	b	rmark_array_nodes

rmark_array_nodes1:
	cmp	x8,x7
	bhi	rmark_next_array_node

	ldr	x3,[x8]
	add	x4,x7,#1
	str	x3,[x7]
	str	x4,[x8]

rmark_next_array_node:
	ldr	x16,[x28]
	add	x7,x7,#8
	cmp	x7,x16
	beq	end_rmark_array_node

rmark_array_nodes:
	ldr	x8,[x7]

	sub	x4,x8,x11
	cmp	x4,x2
	bcs	rmark_next_array_node

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w10,[x27,x3,lsl #2]
	tst	x10,x4
	bne	rmark_array_nodes1

	orr	x10,x10,x4
	str	w10,[x27,x3,lsl #2]

	ldr	x4,[x8]

	str	x30,[x28,#-8]!
	bl	rmark_array_node

	ldr	x16,[x28]
	add	x7,x7,#8
	cmp	x7,x16
	bne	rmark_array_nodes

end_rmark_array_node:
	add	x28,x28,#8
	b	rmark_next_node

rmark_array_node:
	mov	x3,x7
	mov	x16,#1
	stp	x16,x7,[x28,#-16]!
	b	rmark_arguments

rmark_array_length_0_1:
	add	x8,x8,#-16
	blo	rmark_next_node

	ldr	x3,[x8,#24]
	ldr	x10,[x8,#16]
	str	x10,[x8,#24]
	ldr	x10,[x8,#8]
	str	x10,[x8,#16]
	str	x3,[x8,#8]!
	b	rmark_hnf_1

	.ltorg

