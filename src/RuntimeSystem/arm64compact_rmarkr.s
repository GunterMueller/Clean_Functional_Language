
ZERO_ARITY_DESCRIPTOR_OFFSET = -8

rmark_using_reversal:
	stp	x7,x7,[x28,#-16]!
	mov	x7,#1
	b	rmarkr_node

rmark_using_reversal_:
	sub	x8,x8,#8
	stp	x7,x3,[x28,#-16]!
	cmp	x8,x3
	bhi	rmark_no_undo_reverse_1
	str	x8,[x7]
	str	x4,[x8]
rmark_no_undo_reverse_1:
	mov	x7,#1
	b	rmarkr_arguments

rmark_array_using_reversal:
	stp	x7,x3,[x28,#-16]!
	cmp	x8,x3
	bhi	rmark_no_undo_reverse_2
	str	x8,[x7]
	str	x17,[x8] // __ARRAY__+2
rmark_no_undo_reverse_2:
	mov	x7,#1
	b	rmarkr_arguments

rmarkr_hnf_2:
	ldr	x16,[x8]
	orr	x16,x16,#2
	str	x16,[x8]
	ldr	x10,[x8,#8]
	str	x7,[x8,#8]
	add	x7,x8,#8
	mov	x8,x10

rmarkr_node:
	sub	x4,x8,x11
	cmp	x4,x2
	bhs	rmarkr_next_node_after_static

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w10,[x27,x3,lsl #2]
	tst	x10,x4
	bne	rmarkr_next_node

	orr	x10,x10,x4
	str	w10,[x27,x3,lsl #2]

rmarkr_arguments:
	ldr	x4,[x8]
	tbz	x4,#1,rmarkr_lazy_node

	ldrh	w10,[x4,#-2]
	cbz	x10,rmarkr_hnf_0

	add	x8,x8,#8

	cmp	x10,#256
	bhs	rmarkr_record

	subs	x10,x10,#2
	beq	rmarkr_hnf_2
	blo	rmarkr_hnf_1

rmarkr_hnf_3:
	ldr	x9,[x8,#8]

	sub	x4,x9,x11

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x3,lsl #2]
	tst	x4,x16
	bne	rmarkr_shared_argument_part

	orr	x16,x16,x4	
	str	w16,[x27,x3,lsl #2]	

rmarkr_no_shared_argument_part:
	ldr	x16,[x8]
	orr	x16,x16,#2
	str	x16,[x8]
	str	x7,[x8,#8]!

	ldr	x16,[x9]
	orr	x16,x16,#1
	str	x16,[x9]
	add	x9,x9,x10,lsl #3

	ldr	x10,[x9]
	str	x8,[x9]
	mov	x7,x9
	mov	x8,x10
	b	rmarkr_node

rmarkr_shared_argument_part:
	cmp	x9,x8
	bhi	rmarkr_hnf_1

	ldr	x3,[x9]
	add	x4,x8,#8+2+1
	str	x4,[x9]
	str	x3,[x8,#8]
	b	rmarkr_hnf_1

rmarkr_record:
	subs	x10,x10,#258
	beq	rmarkr_record_2
	blo	rmarkr_record_1

rmarkr_record_3:
	ldrh	w10,[x4,#-2+2]
	subs	x10,x10,#1
	blo	rmarkr_record_3_bb
	beq	rmarkr_record_3_ab
	subs	x10,x10,#1
	beq	rmarkr_record_3_aab
	b	rmarkr_hnf_3

rmarkr_record_3_bb:
	ldr	x9,[x8,#16-8]
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
	bhi	rmarkr_next_node

	adds	w4,w4,w4
	bne	rmarkr_bit_in_same_word1
	add	x10,x10,#1
	mov	x4,#1
rmarkr_bit_in_same_word1:
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	beq	rmarkr_not_yet_linked_bb

	sub	x4,x8,x11

	add	x4,x4,#2*8

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
rmarkr_not_yet_linked_bb:
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x10,[x9]
	add	x4,x8,#16+2+1
	str	x10,[x8,#16]
	str	x4,[x9]
	b	rmarkr_next_node

rmarkr_record_3_ab:
	ldr	x9,[x8,#8]

	sub	x4,x9,x11

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	cmp	x9,x8
	bhi	rmarkr_hnf_1

	adds	w4,w4,w4
	bne	rmarkr_bit_in_same_word2
	add	x10,x10,#1
	mov	x4,#1
rmarkr_bit_in_same_word2:
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	beq	rmarkr_not_yet_linked_ab

	sub	x4,x8,x11

	add	x4,x4,#8
	
	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
rmarkr_not_yet_linked_ab: 
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x10,[x9]
	add	x4,x8,#8+2+1
	str	x10,[x8,#8]
	str	x4,[x9]
	b	rmarkr_hnf_1

rmarkr_record_3_aab:
	ldr	x9,[x8,#8]

	sub	x4,x9,x11

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	tst	x4,x16
	bne	rmarkr_shared_argument_part
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	ldr	x16,[x8]
	add	x16,x16,#2
	str	x16,[x8]
	str	x7,[x8,#8]!

	ldr	x7,[x9]
	str	x8,[x9]
	mov	x8,x7
	add	x7,x9,#1
	b	rmarkr_node

rmarkr_record_2:
	ldrh	w16,[x4,#-2+2]
	cmp	x16,#1
	bhi	rmarkr_hnf_2
	beq	rmarkr_hnf_1
	sub	x8,x8,#8
	b	rmarkr_next_node

rmarkr_record_1:
	ldrh	w16,[x4,#-2+2]
	cbnz	x16,rmarkr_hnf_1
	sub	x8,x8,#8
	b	rmarkr_next_node

rmarkr_lazy_node_1:
# selectors:
	bne	rmarkr_selector_node_1

rmarkr_hnf_1:
	ldr	x10,[x8]
	str	x7,[x8]

	add	x7,x8,#2
	mov	x8,x10
	b	rmarkr_node

# selectors
rmarkr_indirection_node:
	add	x16,x8,#-8

	sub	x3,x16,x11

	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	mov	x4,#1
	lsl	x4,x4,x16
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x4
	str	w16,[x27,x3,lsl #2]

	ldr	x8,[x8]
	b	rmarkr_node

rmarkr_selector_node_1:
	cmp	w10,#(-2)-1
	beq	rmarkr_indirection_node

	ldr	x9,[x8]

	sub	x3,x9,x11
	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	eor	x16,x16,#(1<<63)+63
	ldr	w3,[x27,x3,lsl #2]
	lsr	x16,x16,x16
	tst	x3,x16
	bne	rmarkr_hnf_1

	ldr	x3,[x9]
	tbz	x3,#1,rmarkr_hnf_1

	cmp	w10,#(-3)-1

	ldrh	w16,[x3,#-2]

	ble	rmarkr_record_selector_node_1

	cmp	x16,#2
	bls	rmarkr_small_tuple_or_record

rmarkr_large_tuple_or_record:
	ldr	x3,[x9,#16]

	sub	x3,x3,x11
	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	eor	x16,x16,#(1<<63)+63
	ldr	w3,[x27,x3,lsl #2]
	lsr	x16,x16,x16
	tst	x3,x16
	bne	rmarkr_hnf_1

	sub	x16,x8,#8
	sub	x3,x16,x11

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]

	ubfx	x1,x3,#3,#5
	lsr	x3,x3,#8
.ifdef PIC
	ldrh	w4,[x16,x4]
.endif
	mov	x16,#1
	lsl	x1,x16,x1
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x1
	str	w16,[x27,x3,lsl #2]

.ifndef PIC
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	blt	rmarkr_tuple_or_record_selector_node_2
	ldr	x9,[x9,#16]
	beq	rmarkr_tuple_selector_node_2
	sub	x4,x4,#24
	mov	x1,x8
	ldr	x8,[x9,x4]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x1,#-8]
	str	x8,[x1]
	b	rmarkr_node

rmarkr_tuple_selector_node_2:
	mov	x1,x8
	ldr	x8,[x9]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x1,#-8]
	str	x8,[x1]
	b	rmarkr_node

rmarkr_record_selector_node_1:
	beq	rmarkr_strict_record_selector_node_1

	cmp	x16,#258
	bls	rmarkr_small_tuple_or_record

	ldr	x3,[x9,#16]

	sub	x3,x3,x11
	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	eor	x16,x16,#(1<<63)+63
	ldr	w3,[x27,x3,lsl #2]
	lsr	x16,x16,x16
	tst	x3,x16
	bne	rmarkr_hnf_1

rmarkr_small_tuple_or_record:
	sub	x16,x8,#8
	sub	x3,x16,x11

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]

	ubfx	x1,x3,#3,#5
	lsr	x3,x3,#8
.ifdef PIC
	ldrh	w4,[x16,x4]
.endif
	mov	x16,#1
	lsl	x1,x16,x1
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x1
	str	w16,[x27,x3,lsl #2]

.ifndef PIC
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	ble	rmarkr_tuple_or_record_selector_node_2
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
rmarkr_tuple_or_record_selector_node_2:
	mov	x1,x8
	ldr	x8,[x9,x4]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x1,#-8]
	str	x8,[x1]
	b	rmarkr_node

rmarkr_strict_record_selector_node_1:
	cmp	x16,#258
	bls	rmarkr_select_from_small_record

	ldr	x3,[x9,#8]
	sub	x3,x3,x11

	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	eor	x16,x16,#(1<<63)+63
	ldr	w3,[x27,x3,lsl #2]
	lsr	x16,x16,x16
	tst	x3,x16
	bne	rmarkr_hnf_1

rmarkr_select_from_small_record:
.ifdef PIC
	ldr	x16,[x4,#-8]
	add	x4,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif
	sub	x8,x8,#4

.ifdef PIC
	ldrh	w3,[x4,x16]!
.else
	ldrh	w3,[x4,#4]
.endif
	cmp	x3,#16
	ble	rmarkr_strict_record_selector_node_2
	ldr	x16,[x9,#16]
	add	x3,x3,x16
	ldr	x3,[x3,#-24]
	b	rmarkr_strict_record_selector_node_3
rmarkr_strict_record_selector_node_2:
	ldr	x3,[x9,x3]
rmarkr_strict_record_selector_node_3:
	str	x3,[x8,#8]

.ifdef PIC
	ldrh	w3,[x4,#6-4]
.else
	ldrh	w3,[x4,#6]
.endif
	cbz	x3,rmarkr_strict_record_selector_node_5
	cmp	x3,#16
	ble	rmarkr_strict_record_selector_node_4
	ldr	x9,[x9,#16]
	subs	x3,x3,#24
rmarkr_strict_record_selector_node_4:
	ldr	x3,[x9,x3]
	str	x3,[x8,#16]
rmarkr_strict_record_selector_node_5:
	ldr	x4,[x4,#-8]
	str	x4,[x8]
	b	rmarkr_next_node

# a2,d1: free

rmarkr_next_node:
	tst	x7,#3
	bne	rmarkr_parent

	ldr	x10,[x7,#-8]!

	and	x3,x10,#3
	cmp	x3,#3
	beq	rmarkr_argument_part_cycle1

	ldr	x9,[x7,#8]
	str	x9,[x7]

rmarkr_c_argument_part_cycle1:
	cmp	x8,x7
	bhi	rmarkr_no_reverse_1

	ldr	x9,[x8]
	add	x4,x7,#8+1
	str	x9,[x7,#8]
	str	x4,[x8]

	eor	x8,x10,x3
	orr	x7,x7,x3
	b	rmarkr_node

rmarkr_no_reverse_1:
	str	x8,[x7,#8]
	eor	x8,x10,x3
	orr	x7,x7,x3
	b	rmarkr_node

rmarkr_lazy_node:
	ldr	w10,[x4,#-4]
	cbz	x10,rmarkr_next_node

	add	x8,x8,#8

	subs	w10,w10,#1
	ble	rmarkr_lazy_node_1

	cmp	x10,#255
	bge	rmarkr_closure_with_unboxed_arguments

rmarkr_closure_with_unboxed_arguments_:
	ldr	x16,[x8]
	orr	x16,x16,#2
	str	x16,[x8]
	add	x8,x8,x10,lsl #3

	ldr	x10,[x8]
	str	x7,[x8]
	mov	x7,x8
	mov	x8,x10
	b	rmarkr_node

rmarkr_closure_with_unboxed_arguments:
# (a_size+b_size)+(b_size<<8)
#	addl	$1,a2
	lsr	x4,x10,#8
	and	x10,x10,#255
	subs	x10,x10,x4
#	subl	$1,a2
	bgt	rmarkr_closure_with_unboxed_arguments_
	beq	rmarkr_hnf_1
	sub	x8,x8,#8
	b	rmarkr_next_node

rmarkr_hnf_0:
	cmp	x4,x12 // INT+2
	beq	rmarkr_int_3

	cmp	x4,x13 // CHAR+2
 	beq	rmarkr_char_3

	blo	rmarkr_no_normal_hnf_0

	sub	x3,x8,x11

	ubfx	x8,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x8,x16,x8
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x8
	str	w16,[x27,x3,lsl #2]

	add	x8,x4,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	b	rmarkr_next_node_after_static

rmarkr_int_3:
	ldr	x10,[x8,#8]
	cmp	x10,#33
	bhs	rmarkr_next_node

	sub	x3,x8,x11

	ubfx	x8,x3,#3,#5
	lsr	x3,x3,#8
	mov	x16,#1
	lsl	x8,x16,x8
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x8
	str	w16,[x27,x3,lsl #2]

	add	x8,x14,x10,lsl #4 // small integers
	b	rmarkr_next_node_after_static

rmarkr_char_3:
	ldrb	w4,[x8,#8]

	sub	x3,x8,x11

	ubfx	x16,x3,#3,#5
	lsr	x3,x3,#8
	mov	x10,#1
	lsl	x10,x10,x16
	ldr	w16,[x27,x3,lsl #2]
	bic	x16,x16,x10
	str	w16,[x27,x3,lsl #2]

	add	x8,x15,x4,lsl #4 // static_characters
	b	rmarkr_next_node_after_static

rmarkr_no_normal_hnf_0:
	cmp	x4,x17 // __ARRAY__+2
	bne	rmarkr_next_node

	ldr	x4,[x8,#16]
	cbz	x4,rmarkr_lazy_array

	ldrh	w3,[x4,#-2+2]
	cbz	x3,rmarkr_b_array

	ldrh	w4,[x4,#-2]
	cbz	x4,rmarkr_b_array

	sub	x4,x4,#256
	cmp	x3,x4
	beq	rmarkr_a_record_array

rmarkr_ab_record_array:
	ldr	x9,[x8,#8]
	add	x8,x8,#16

	str	x8,[x28,#-8]!

	mul	x9,x4,x9
	lsl	x9,x9,#3

	sub	x4,x4,x3
	add	x8,x8,#8
	add	x9,x9,x8

	mov	x29,x30
	bl	reorder
	mov	x30,x29

	ldr	x8,[x28],#8

	mov	x4,x3
	ldr	x16,[x8,#-8]
	mul	x4,x16,x4
	b	rmarkr_lr_array

rmarkr_b_array:
	sub	x4,x8,x11

	add	x4,x4,#8

	lsr	x10,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x4,x16,x4
	ldr	w16,[x27,x10,lsl #2]
	orr	x16,x16,x4
	str	w16,[x27,x10,lsl #2]

	b	rmarkr_next_node

rmarkr_a_record_array:
	ldr	x4,[x8,#8]
	add	x8,x8,#16
	cmp	x3,#2
	blo	rmarkr_lr_array

	mul	x4,x3,x4
	b	rmarkr_lr_array

rmarkr_lazy_array:
	ldr	x4,[x8,#8]
	add	x8,x8,#16

rmarkr_lr_array:
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
	bls	rmarkr_array_length_0_1

	mov	x9,x8
	add	x8,x8,x4,lsl #3

	ldr	x4,[x8]
	ldr	x3,[x9]
	str	x4,[x9]
	str	x3,[x8]

	ldr	x4,[x8,#-8]!
	ldr	x3,[x9,#-8]!
	add	x4,x4,#2
	str	x3,[x8]
	str	x4,[x9]

	ldr	x4,[x8,#-8]!
	str	x7,[x8]
	mov	x7,x8
	mov	x8,x4
	b	rmarkr_node

rmarkr_array_length_0_1:
	add	x8,x8,#-16
	blo	rmarkr_next_node

	ldr	x3,[x8,#24]
	ldr	x10,[x8,#16]
	str	x10,[x8,#24]
	ldr	x10,[x8,#8]
	str	x10,[x8,#16]
	str	x3,[x8,#8]!
	b	rmarkr_hnf_1

# a2: free

rmarkr_parent:
	and	x3,x7,#3

	ands	x7,x7,#-4
	beq	end_rmarkr

	subs	x3,x3,#1
	beq	rmarkr_argument_part_parent

	ldr	x10,[x7]

	cmp	x8,x7
	bhi	rmarkr_no_reverse_2

	mov	x9,x8
	add	x4,x7,#1
	ldr	x8,[x9]
	str	x4,[x9]

rmarkr_no_reverse_2:
	str	x8,[x7]
	add	x8,x7,#-8
	mov	x7,x10
	b	rmarkr_next_node


rmarkr_argument_part_parent:
	ldr	x10,[x7]

	mov	x9,x7
	mov	x7,x8
	mov	x8,x9

rmarkr_skip_upward_pointers:
	and	x4,x10,#3
	cmp	x4,#3
	bne	rmarkr_no_upward_pointer

	add	x9,x10,#-3
	ldr	x10,[x10,#-3]
	b	rmarkr_skip_upward_pointers

rmarkr_no_upward_pointer:
	cmp	x7,x8
	bhi	rmarkr_no_reverse_3

	mov	x3,x7
	ldr	x7,[x7]
	add	x4,x8,#1
	str	x4,[x3]

rmarkr_no_reverse_3:
	str	x7,[x9]
	add	x7,x10,#-8

	and	x7,x7,#-4

	mov	x9,x7
	ldr	x10,[x7]

	and	x3,x10,#3
	ldr	x4,[x9,#8]

	orr	x7,x7,x3
	str	x4,[x9]

	cmp	x8,x9
	bhi	rmarkr_no_reverse_4

	ldr	x4,[x8]
	str	x4,[x9,#8]
	add	x4,x9,#8+2+1
	str	x4,[x8]
	and	x8,x10,#-4
	b	rmarkr_node

rmarkr_no_reverse_4:
	str	x8,[x9,#8]
	and	x8,x10,#-4
	b	rmarkr_node

rmarkr_argument_part_cycle1:
	ldr	x4,[x7,#8]

rmarkr_skip_pointer_list1:
	and	x1,x10,#-4
	ldr	x10,[x1]
	and	x3,x10,#3
	cmp	x3,#3
	beq	rmarkr_skip_pointer_list1

	str	x4,[x1]
	b	rmarkr_c_argument_part_cycle1

rmarkr_next_node_after_static:
	tst	x7,#3
	bne	rmarkr_parent_after_static

	ldr	x10,[x7,#-8]!

	and	x3,x10,#3
	cmp	x3,#3
	beq	rmarkr_argument_part_cycle2

	ldr	x4,[x7,#8]
	str	x4,[x7]

rmarkr_c_argument_part_cycle2:
	str	x8,[x7,#8]
	eor	x8,x10,x3
	orr	x7,x7,x3
	b	rmarkr_node

rmarkr_parent_after_static:
	and	x3,x7,#3

	ands	x7,x7,#-4
	beq	end_rmarkr_after_static

	subs	x3,x3,#1
	beq	rmarkr_argument_part_parent_after_static

	ldr	x10,[x7]
	str	x8,[x7]
	add	x8,x7,#-8
	mov	x7,x10
	b	rmarkr_next_node

rmarkr_argument_part_parent_after_static:
	ldr	x10,[x7]

	mov	x9,x7
	mov	x7,x8
	mov	x8,x9

#	movl	(a1),a2
rmarkr_skip_upward_pointers_2:
	and	x4,x10,#3
	cmp	x4,#3
	bne	rmarkr_no_reverse_3

#	movl	a2,a1
#	andl	$-4,a1
#	movl	(a1),a2
	add	x9,x10,#-3
	ldr	x10,[x10,#-3]
	b	rmarkr_skip_upward_pointers_2

rmarkr_argument_part_cycle2:
	ldr	x4,[x7,#8]

rmarkr_skip_pointer_list2:
	and	x1,x10,#-4
	ldr	x10,[x1]
	and	x3,x10,#3
	cmp	x3,#3
	beq	rmarkr_skip_pointer_list2

	str	x4,[x1]
	b	rmarkr_c_argument_part_cycle2

end_rmarkr_after_static:
	ldr	x7,[x28],#16
	str	x8,[x7]
	b	rmarkr_next_stack_node

end_rmarkr:
	ldp	x7,x3,[x28],#16

	cmp	x8,x3
	bhi	rmarkr_no_reverse_5

	mov	x9,x8
	add	x4,x7,#1
	ldr	x8,[x8]
	str	x4,[x9]

rmarkr_no_reverse_5:
	str	x8,[x7]

rmarkr_next_stack_node:
	cmp	x28,x0
	bhs	rmark_next_node

	ldp	x8,x7,[x28],#16

	cmp	x8,#1
	bhi	rmark_using_reversal

	b	rmark_next_node_

	.ltorg
