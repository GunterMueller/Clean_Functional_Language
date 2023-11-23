
ZERO_ARITY_DESCRIPTOR_OFFSET = -8

#undef COUNT_GARBAGE_COLLECTIONS
#undef MARK_USING_REVERSAL
#undef COMPARE_HEAP_AFTER_MARK
#undef DEBUG_MARK_COLLECT

# heap_vector in x27
	adrp	x16,heap_size_65
	ldr	x4,[x16,#:lo12:heap_size_65]
# heap_vector+4 in x11
	add	x11,x27,#4
	mov	x3,#0

# heap_p3 in x0

	adrp	x16,heap_p3
	ldr	x0,[x16,#:lo12:heap_p3]

# n_marked_words in x2
	mov	x2,#0

	lsl	x1,x4,#6
# heap_size_64_65 in x1
	adrp	x12,INT+2
	add	x12,x12,#:lo12:INT+2
	adrp	x13,CHAR+2
	add	x13,x13,#:lo12:CHAR+2
	adrp	x14,__STRING__+2
	add	x14,x14,#:lo12:__STRING__+2
	adrp	x15,BOOL+2
	add	x15,x15,#:lo12:BOOL+2
// end_vector in x5

	stp	x19,x20,[sp,#-16]!

	adrp	x20,e__system__nind
	add	x20,x20,#:lo12:e__system__nind

	adrp	x16,lazy_array_list
	str	x3,[x16,#:lo12:lazy_array_list]

	add	x7,x28,#-4000

	adrp	x16,caf_list
	ldr	x4,[x16,#:lo12:caf_list]

	adrp	x16,end_stack
# end_stack in x17
	mov	x17,x7
	str	x7,[x16,#:lo12:end_stack]

	cbz	x4,_end_mark_cafs

_mark_cafs_lp:
	ldr	x3,[x4]
	ldr	x10,[x4,#-8]

	str	x10,[x28,#-8]!
	add	x10,x4,#8
	add	x16,x4,#8
	add	x5,x16,x3,lsl #3 // end_vector

	str	x30,[x28,#-8]!
	bl	_mark_stack_nodes

	ldr	x4,[x28],#8
	cbnz	x4,_mark_cafs_lp

_end_mark_cafs:
	adrp	x16,stack_p
	ldr	x10,[x16,#:lo12:stack_p]
	adrp	x16,stack_top
	ldr	x5,[x16,#:lo12:stack_top] // end_vector

	str	x30,[x28,#-8]!
	bl	_mark_stack_nodes

	ldp	x19,x20,[sp],#16

	adrp	x16,lazy_array_list
	ldr	x8,[x16,#:lo12:lazy_array_list]

	cbz	x8,end_restore_arrays

restore_arrays:
	ldr	x3,[x8]
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x8]

	cmp	x3,#1
	beq	restore_array_size_1

	add	x9,x8,x3,lsl #3	
	ldr	x4,[x9,#16]
	cbz	x4,restore_lazy_array

	ldrh	w10,[x4,#-2+2]
	udiv	x3,x3,x10

restore_lazy_array:
	ldr	x27,[x8,#16]
	ldr	x10,[x8,#8]
	str	x3,[x8,#8]
	ldr	x7,[x9,#8]
	str	x4,[x8,#16]
	str	x10,[x9,#8]
	str	x27,[x9,#16]

	cbz	x4,no_reorder_array

	ldrh	w9,[x4,#-2]
	sub	x9,x9,#256
	ldrh	w10,[x4,#-2+2]
	cmp	x10,x9
	beq	no_reorder_array

	add	x8,x8,#24
	mul	x3,x9,x3
	mov	x4,x9
	add	x9,x8,x3,lsl #3
	mov	x3,x10
	sub	x4,x4,x10

	bl	reorder

no_reorder_array:
	mov	x8,x7
	cbnz	x7,restore_arrays

	b	end_restore_arrays

restore_array_size_1:
	ldr	x10,[x8,#8]
	ldr	x9,[x8,#16]
	str	x3,[x8,#8]
	ldr	x4,[x8,#24]	
	str	x10,[x8,#24]
	str	x4,[x8,#16]

	mov	x8,x9
	cbnz	x9,restore_arrays

end_restore_arrays:

.ifdef FINALIZERS
	adrp	x16,heap_vector
	ldr	x27,[x16,#:lo12:heap_vector]
	adrp	x8,finalizer_list
	add	x8,x8,#:lo12:finalizer_list
	adrp	x9,free_finalizer_list
	add	x9,x9,#:lo12:free_finalizer_list

	ldr	x10,[x8]
determine_free_finalizers_after_mark:
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x10,x16
	beq	end_finalizers_after_mark

	sub	x4,x10,x0
	lsr	x3,x4,#8
	ubfx	x7,x4,#3,#5
	mov	x16,#1
	lsl	x7,x16,x7

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	beq	finalizer_not_used_after_mark

	add	x8,x10,#8
	ldr	x10,[x10,#8]
	b	determine_free_finalizers_after_mark

finalizer_not_used_after_mark:
	str	x10,[x9]
	add	x9,x10,#8

	ldr	x10,[x10,#8]
	str	x10,[x8]
	b	determine_free_finalizers_after_mark

end_finalizers_after_mark:
	str	x10,[x9]
.endif

	str	x2,[x28,#-8]!

	bl	add_garbage_collect_time

	ldr	x2,[x28],#8

.ifdef ADJUST_HEAP_SIZE
	adrp	x16,bit_vector_size
	ldr	x4,[x16,#:lo12:bit_vector_size]
.else
	adrp	x16,heap_size_65
	ldr	x4,[x16,#:lo12:heap_size_65]
	lsl	x4,x4,#3
.endif

.ifdef ADJUST_HEAP_SIZE
	adrp	x16,n_allocated_words
	ldr	x27,[x16,#:lo12:n_allocated_words]
	add	x27,x27,x2
	lsl	x27,x27,#3

	lsl	x7,x4,#3

	stp	x4,x9,[sp,#-16]!

	adrp	x16,heap_size_multiple
	ldr	x16,[x16,#:lo12:heap_size_multiple]
	umulh	x9,x16,x27
	mul	x4,x16,x27
	lsr	x4,x4,#8
	orr	x4,x4,x9,lsl #64-8
	lsr	x9,x9,#8

	mov	x3,x4
	cmp	x9,#0

	ldp	x4,x9,[sp],#16

	beq	not_largest_heap

	adrp	x16,heap_size_65
	ldr	x3,[x16,#:lo12:heap_size_65]
	lsl	x3,x3,#6

not_largest_heap:
	cmp	x3,x7
	bls	no_larger_heap

	adrp	x16,heap_size_65
	ldr	x7,[x16,#:lo12:heap_size_65]
	lsl	x7,x7,#6
	cmp	x3,x7
	bls	not_larger_then_heap
	mov	x3,x7
not_larger_then_heap:
	lsr	x4,x3,#3
	adrp	x16,bit_vector_size
	str	x4,[x16,#:lo12:bit_vector_size]
no_larger_heap:
.endif
	mov	x10,x4

# heap_vector in x27
	adrp	x16,heap_vector
	ldr	x27,[x16,#:lo12:heap_vector]
# heap_vector+4 in x11
	add	x11,x27,#4

	lsr	x10,x10,#5

	tst	x4,#31
	beq	no_extra_word

	str	wzr,[x27,x10,lsl #2]

no_extra_word:
	sub	x4,x4,x2
	lsl	x4,x4,#3
	adrp	x16,n_last_heap_free_bytes
	str	x4,[x16,#:lo12:n_last_heap_free_bytes]

	stp	x2,x10,[x28,#-16]!

	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#1,_no_heap_use_message2

	adrp	x0,marked_gc_string_1
	add	x0,x0,#:lo12:marked_gc_string_1
	bl	ew_print_string

	ldr	x2,[x28]
	lsl	x0,x2,#3
	bl	ew_print_int

	adrp	x0,heap_use_after_gc_string_2
	add	x0,x0,#:lo12:heap_use_after_gc_string_2
	bl	ew_print_string

_no_heap_use_message2:

.ifdef FINALIZERS
	bl	call_finalizers
.endif

	ldp	x2,x10,[x28],#16

	adrp	x16,n_allocated_words
	ldr	x7,[x16,#:lo12:n_allocated_words]
	mov	x3,#0

# n_free_words_after_mark in x2
	mov	x8,x27
	mov	x2,#0

_scan_bits:
	ldr	w16,[x8]
	cbz	x16,_zero_bits
	str	wzr,[x8],#4
	subs	x10,x10,#1
	bne	_scan_bits

	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]
	b	_end_scan

_zero_bits:
	add	x9,x8,#4
	add	x8,x8,#4
	subs	x10,x10,#1
	bne	_skip_zero_bits_lp1

	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]
	b	_end_bits

_skip_zero_bits_lp:
	cbnz	x4,_end_zero_bits
_skip_zero_bits_lp1:
	ldr	w4,[x8],#4
	subs	x10,x10,#1
	bne	_skip_zero_bits_lp

	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]

	cbz	x4,_end_bits
	str	wzr,[x8,#-4]
	sub	x4,x8,x9
	b	_end_bits2

_end_zero_bits:
	sub	x4,x8,x9
	lsl	x4,x4,#3
	add	x2,x2,x4
	str	wzr,[x8,#-4]

	cmp	x4,x7
	blo	_scan_bits

# n_free_words_after_mark updated
_found_free_memory:
	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]
	adrp	x16,bit_counter
	str	x10,[x16,#:lo12:bit_counter]
	adrp	x16,bit_vector_p
	str	x8,[x16,#:lo12:bit_vector_p]

	sub	x25,x4,x7

	add	x3,x9,#-4
	sub	x3,x3,x27
	adrp	x16,heap_p3
	ldr	x27,[x16,#:lo12:heap_p3]
	lsl	x3,x3,#6
	add	x27,x27,x3

	adrp	x16,stack_top
	ldr	x7,[x16,#:lo12:stack_top]

	add	x3,x27,x4,lsl #3
	adrp	x16,heap_end_after_gc
	str	x3,[x16,#:lo12:heap_end_after_gc]

	ldp	x6,x30,[sp,#48]
	ldp	x4,x5,[sp,#32]
	ldp	x2,x3,[sp,#16]
	ldp	x0,x1,[sp],#64

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

# n_free_words_after_mark updated
_end_bits:
	sub	x4,x8,x9
	add	x4,x4,#4
_end_bits2:
	lsl	x4,x4,#3
	add	x2,x2,x4

	cmp	x4,x7
	bhs	_found_free_memory

	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]

# n_free_words_after_mark updated
_end_scan:
	adrp	x16,bit_counter
	str	x10,[x16,#:lo12:bit_counter]
	b	compact_gc

	.ltorg

# a2: pointer to stack element
# a4: heap_vector
# d0,d1,a0,a1,a3: free

_mark_stack_nodes:
	cmp	x10,x5 // end_vector
	beq	_end_mark_nodes
_mark_stack_nodes_:
	ldr	x8,[x10],#8

	sub	x9,x8,x0
	cmp	x9,x1
	bcs	_mark_stack_nodes

	lsr	x3,x9,#8
	ubfx	x9,x9,#3,#5
	mov	x16,#1
	lsl	x7,x16,x9

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_mark_stack_nodes

	str	x10,[x28,#-8]!

.ifdef MARK_USING_REVERSAL
	mov	x7,#1
	b	__mark_node

__end_mark_using_reversal:
	ldr	x10,[x28],#8
	str	x8,[x10,#-8]
	b	_mark_stack_nodes
.else
	str	xzr,[x28,#-8]!

	b	_mark_arguments

_mark_hnf_2:
	tst	x7,#0xc0000000
	beq	fits_in_word_6
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_6:
	add	x2,x2,#3

_mark_record_2_c:
	ldr	x3,[x8,#8]
	str	x3,[x28,#-8]!

	cmp	x28,x17 // end_stack
	blo	__mark_using_reversal

_mark_node2:
_shared_argument_part:
	ldr	x8,[x8]

_mark_node:
	sub	x9,x8,x0
	cmp	x9,x1
	bcs	_mark_next_node

	lsr	x3,x9,#8
	ubfx	x9,x9,#3,#5
	mov	x16,#1
	lsl	x7,x16,x9

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_mark_next_node

_mark_arguments:
	ldr	x4,[x8]
	tbz	x4,#1,_mark_lazy_node

	ldrh	w10,[x4,#-2]
	cbz	x10,_mark_hnf_0

	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	add	x8,x8,#8

	cmp	x10,#256
	bhs	_mark_record

	subs	x10,x10,#2
	beq	_mark_hnf_2
	blo	_mark_hnf_1

_mark_hnf_3:
	ldr	x9,[x8,#8]

	tst	x7,#0xc0000000
	beq	fits_in_word_1
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_1:	

	sub	x4,x9,x0
	add	x2,x2,#3

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5
	mov	x16,#1
	lsl	x7,x16,x4

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_shared_argument_part

_no_shared_argument_part:
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	add	x10,x10,#1

	add	x2,x2,x10
	add	x4,x4,x10
	add	x16,x9,#-8
	add	x9,x16,x10,lsl #3

	cmp	x4,#32
	bls	fits_in_word_2
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_2:

	ldr	x3,[x9]
	sub	x10,x10,#2
	str	x3,[x28,#-8]!

_push_hnf_args:
	ldr	x3,[x9,#-8]!
	subs	x10,x10,#1
	str	x3,[x28,#-8]!
	bge	_push_hnf_args

	cmp	x28,x17
	bhs	_mark_node2

	b	__mark_using_reversal

_mark_hnf_1:
	tbz	x7,#31,fits_in_word_4
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_4:
	add	x2,x2,#2
	ldr	x8,[x8]
	b	_mark_node

_mark_lazy_node_1:
	add	x8,x8,#8
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]

	tst	x7,#0xc0000000
	beq	fits_in_word_3
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_3:
	add	x2,x2,#3

	cmp	w10,#1
	beq	_mark_node2

_mark_selector_node_1:
	cmp	w10,#-2
	ldr	x9,[x8]
	beq	_mark_indirection_node

	sub	x7,x9,x0

	lsr	x3,x7,#8
	ubfx	x7,x7,#3,#5

	cmp	w10,#-3

	mov	x16,#1
	lsl	x7,x16,x7

	ble	_mark_record_selector_node_1

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_mark_node3

	ldr	x10,[x9]
	tbz	x10,#1,_mark_node3

	ldrh	w16,[x10,#-2]
	cmp	x16,#2
	bls	_small_tuple_or_record

_large_tuple_or_record:
	ldr	x10,[x9,#16]
	sub	x10,x10,x0
	lsr	x3,x10,#8
	ubfx	x10,x10,#3,#5
	mov	x16,#1
	lsl	x10,x16,x10

	ldr	w16,[x27,x3,lsl #2]
	tst	x10,x16
	bne	_mark_node3

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x16,x4]
.else
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	blt	_mark_tuple_selector_node_1
	ldr	x9,[x9,#16]
	beq	_mark_tuple_selector_node_2
	add	x16,x4,#-24
	ldr	x8,[x9,x16]
	str	x8,[x10]
	b	_mark_node

_mark_tuple_selector_node_2:
	ldr	x8,[x9]
	str	x8,[x10]
	b	_mark_node

_small_tuple_or_record:
.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x16,x4]
.else
	ldrh	w4,[x4,#4]
.endif
_mark_tuple_selector_node_1:
	ldr	x8,[x9,x4]
	str	x8,[x10]
	b	_mark_node

_mark_record_selector_node_1:
	beq	_mark_strict_record_selector_node_1

	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_mark_node3

	ldr	x10,[x9]
	tbz	x10,#1,_mark_node3

	ldrh	w16,[x10,#-2]
	cmp	x16,#258
	bls	_small_tuple_or_record

	ldr	x10,[x9,#16]
	sub	x10,x10,x0
	lsr	x3,x10,#7
	and	x10,x10,#31*4
	lsr	x10,x10,#2
	mov	x16,#1
	lsl	x10,x16,x10

	ldr	w16,[x27,x3,lsl #2]
	tst	x10,x16
	bne	_mark_node3

.ifdef PIC
	add	x16,x4,#-8+4
.endif
	ldr	w4,[x4,#-8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x16,x4]
.else
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	ble	_mark_record_selector_node_2
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
_mark_record_selector_node_2:
	ldr	x8,[x9,x4]

	str	x8,[x10]
	b	_mark_node

_mark_strict_record_selector_node_1:
	ldr	w16,[x27,x3,lsl #2]
	tst	x7,x16
	bne	_mark_node3

	ldr	x10,[x9]
	tbz	x10,#1,_mark_node3

	ldrh	w16,[x10,#-2]
	cmp	x16,#258
	bls	_select_from_small_record

	ldr	x10,[x9,#8]
	sub	x10,x10,x0
	lsr	x3,x10,#7
	and	x10,x10,#31*4
	lsr	x10,x10,#2
	mov	x16,#1
	lsl	x10,x16,x10

	ldr	w16,[x27,x3,lsl #2]
	tst	x10,x16
	bne	_mark_node3

_select_from_small_record:
.ifdef PIC
	ldr	x16,[x4,#-8]
	add	x4,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif

	sub	x8,x8,#8

.ifdef PIC
	ldrh	w3,[x4,x16]!
.else
	ldrh	w3,[x4,#4]
.endif
	cmp	x3,#16
	ble	_mark_strict_record_selector_node_2
	ldr	x16,[x9,#16]
	add	x3,x3,x16
	ldr	x3,[x3,#-24]
	b	_mark_strict_record_selector_node_3
_mark_strict_record_selector_node_2:
	ldr	x3,[x9,x3]
_mark_strict_record_selector_node_3:
	str	x3,[x8,#8]
.ifdef PIC
	ldrh	w3,[x4,#6-4]
.else
	ldrh	w3,[x4,#6]
.endif
	cbz	x3,_mark_strict_record_selector_node_5
	cmp	x3,#16
	ble	_mark_strict_record_selector_node_4
	ldr	x9,[x9,#16]
	sub	x3,x3,#24
_mark_strict_record_selector_node_4:
	ldr	x3,[x9,x3]
	str	x3,[x8,#16]
_mark_strict_record_selector_node_5:
	ldr	x4,[x4,#-8]
	str	x4,[x8]
	b	_mark_next_node

_mark_indirection_node:
_mark_node3:
	mov	x8,x9
	b	_mark_node

_mark_next_node:
	ldr	x8,[x28],#8
	cbnz	x8,_mark_node

	ldr	x10,[x28],#8
	cmp	x10,x5 // end_vector
	bne	_mark_stack_nodes_

_end_mark_nodes:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_mark_lazy_node:
	ldr	w10,[x4,#-4]
	cbz	x10,_mark_node2_bb

	cmp	w10,#1
	ble	_mark_lazy_node_1

	cmp	x10,#256
	bge	_mark_closure_with_unboxed_arguments
	add	x10,x10,#1

	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]

	add	x2,x2,x10
	add	x9,x9,x10
	add	x8,x8,x10,lsl #3

	cmp	x9,#32
	bls	fits_in_word_7
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits_in_word_7:
	sub	x10,x10,#3
_push_lazy_args:
	ldr	x3,[x8,#-8]!
	subs	x10,x10,#1
	str	x3,[x28,#-8]!
	bge	_push_lazy_args

	sub	x8,x8,#8

	cmp	x28,x17
	bhs	_mark_node2

	b	__mark_using_reversal

_mark_closure_with_unboxed_arguments:
	ubfx	x4,x10,#8,#8
	and	x10,x10,#255
	subs	x10,x10,#1
	beq	_mark_node2_bb

	add	x10,x10,#2

	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	add	x2,x2,x10
	add	x9,x9,x10

	sub	x10,x10,x4

	cmp	x9,#32
	bls	fits_in_word_7_
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits_in_word_7_:
	subs	x10,x10,#2
	blt	_mark_next_node

	add	x16,x8,#16
	add	x8,x16,x10,lsl #3
	bne	_push_lazy_args

_mark_closure_with_one_boxed_argument:
	ldr	x8,[x8,#-8]
	b	_mark_node

_mark_hnf_0:
	cmp	x4,x14 // __STRING__+2
	bls	_mark_string_or_array

	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]

	cmp	x4,x13 // CHAR+2
	bhi	_mark_normal_hnf_0

_mark_real_int_bool_or_char:
	add	x2,x2,#2

	tbz	x7,#31,_mark_next_node

	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
	b	_mark_next_node

_mark_normal_hnf_0:
	add	x2,x2,#1
	b	_mark_next_node

_mark_node2_bb:
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	add	x2,x2,#3

	tst	x7,#0xc0000000
	beq	_mark_next_node

	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
	b	_mark_next_node

_mark_record:
	subs	x10,x10,#258
	beq	_mark_record_2
	blt	_mark_record_1

_mark_record_3:
	add	x2,x2,#3

	tst	x7,#0xc0000000
	beq	fits_in_word_13
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits_in_word_13:
	ldr	x9,[x8,#8]

	ldrh	w3,[x4,#-2+2]
	sub	x7,x9,x0

	lsr	x4,x7,#8
	ubfx	x7,x7,#3,#5

	subs	x3,x3,#1

	mov	x16,#1
	lsl	x9,x16,x7
	ldr	w16,[x27,x4,lsl #2]

	blo	_mark_record_3_bb

	tst	x9,x16
	bne	_mark_node2

	add	x10,x10,#1
	orr	x16,x16,x9
	str	w16,[x27,x4,lsl #2]
	add	x2,x2,x10
	add	x7,x7,x10

	cmp	x7,#32
	bls	_push_record_arguments
	ldr	w9,[x11,x4,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x4,lsl #2]
_push_record_arguments:
	ldr	x9,[x8,#8]

	subs	x10,x3,#1

	add	x9,x9,x3,lsl #3

	bge	_push_hnf_args

	b	_mark_node2

_mark_record_3_bb:
	tst	x9,x16
	bne	_mark_next_node

	add	x10,x10,#1
	orr	x16,x16,x9
	str	w16,[x27,x4,lsl #2]
	add	x2,x2,x10
	add	x7,x7,x10

	cmp	x7,#32
	bls	_mark_next_node

	ldr	w9,[x11,x4,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x4,lsl #2]
	b	_mark_next_node

_mark_record_2:
	tst	x7,#0xc0000000
	beq	fits_in_word_12
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits_in_word_12:
	add	x2,x2,#3

	ldrh	w16,[x4,#-2+2]
	cmp	x16,#1
	bhi	_mark_record_2_c
	beq	_mark_node2
	b	_mark_next_node

_mark_record_1:
	ldrh	w16,[x4,#-2+2]
	cbnz	x16,_mark_hnf_1

	b	_mark_real_int_bool_or_char

_mark_string_or_array:
	beq	_mark_string_

_mark_array:
	ldr	x10,[x8,#16]
	cbz	x10,_mark_lazy_array

	ldrh	w4,[x10,#-2]
	cbz	x4,_mark_strict_basic_array

	ldrh	w10,[x10,#-2+2]
	cbz	x10,_mark_b_record_array

	cmp	x28,x17
	blo	_mark_array_using_reversal

	sub	x4,x4,#256
	cmp	x4,x10
	beq	_mark_a_record_array

_mark_ab_record_array:
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	ldr	x10,[x8,#8]

	mul	x4,x10,x4
	add	x4,x4,#3

	add	x2,x2,x4
	add	x16,x8,#-8
	add	x4,x16,x4,lsl #3

	sub	x4,x4,x0
	lsr	x4,x4,#8

	cmp	x3,x4
	bhs	_end_set_ab_array_bits

	add	x3,x3,#1
	cmp	x3,x4
	bhs	_last_ab_array_bits

_mark_ab_array_lp:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x4
	blo	_mark_ab_array_lp

_last_ab_array_bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]

_end_set_ab_array_bits:
	ldr	x4,[x8,#8]
	ldr	x9,[x8,#16]
	ldrh	w3,[x9,#-2+2]
	ldrh	w9,[x9,#-2]
	lsl	x3,x3,#3
	sub	x9,x9,#256
	lsl	x9,x9,#3
	str	x3,[x28,#-8]!
	str	x9,[x28,#-8]!
	add	x10,x8,#24

	str	x5,[x28,#-8]! // end_vector
	b	_mark_ab_array_begin

_mark_ab_array:
	ldr	x3,[x28,#16]
	str	x4,[x28,#-8]!
	str	x10,[x28,#-8]!
	add	x5,x10,x3 // end_vector

	str	x30,[x28,#-8]!
	bl	_mark_stack_nodes

	ldr	x3,[x28,#8+16]
	ldr	x10,[x28],#8
	ldr	x4,[x28],#8
	add	x10,x10,x3
_mark_ab_array_begin:
	subs	x4,x4,#1
	bcs	_mark_ab_array

	ldr	x5,[x28],#24 // end_vector
	b	_mark_next_node

_mark_a_record_array:
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	ldr	x10,[x8,#8]

	mul	x4,x10,x4
	str	x4,[x28,#-8]!

	add	x4,x4,#3

	add	x2,x2,x4
	add	x16,x8,#-8
	add	x4,x16,x4,lsl #3

	sub	x4,x4,x0
	lsr	x4,x4,#8

	cmp	x3,x4
	bhs	_end_set_a_array_bits

	add	x3,x3,#1
	cmp	x3,x4
	bhs	_last_a_array_bits

_mark_a_array_lp:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x4
	blo	_mark_a_array_lp

_last_a_array_bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]

_end_set_a_array_bits:
	ldr	x4,[x28],#8
	add	x10,x8,#24

	str	x5,[x28,#-8]! // end_vector
	add	x16,x8,#24
	add	x5,x16,x4,lsl #3 // end_vector

	str	x30,[x28,#-8]!
	bl	_mark_stack_nodes

	ldr	x5,[x28],#8 // end_vector
	b	_mark_next_node

_mark_lazy_array:
	cmp	x28,x17
	blo	_mark_array_using_reversal

	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]
	ldr	x4,[x8,#8]

	add	x4,x4,#3

	add	x2,x2,x4
	add	x16,x8,#-8
	add	x4,x16,x4,lsl #3

	sub	x4,x4,x0
	lsr	x4,x4,#8

	cmp	x3,x4
	bhs	_end_set_lazy_array_bits

	add	x3,x3,#1
	cmp	x3,x4
	bhs	_last_lazy_array_bits

_mark_lazy_array_lp:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x4
	blo	_mark_lazy_array_lp

_last_lazy_array_bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]

_end_set_lazy_array_bits:
	ldr	x4,[x8,#8]
	add	x10,x8,#24

	str	x5,[x28,#-8]! // end_vector
	add	x16,x8,#24
	add	x5,x16,x4,lsl #3 // end_vector

	str	x30,[x28,#-8]!
	bl	_mark_stack_nodes

	ldr	x5,[x28],#8 // end_vector
	b	_mark_next_node

_mark_array_using_reversal:
	str	xzr,[x28,#-8]!
	mov	x7,#1
	b	__mark_node

_mark_strict_basic_array:
	ldr	x4,[x8,#8]
	cmp	x10,x12 // INT+2
	ble	_mark_strict_int_or_real_array
	cmp	x10,x15 // BOOL+2
	beq	_mark_strict_bool_array
_mark_strict_int32_or_real32_array:
	add	x4,x4,#6+1
	lsr	x4,x4,#1
	b	_mark_basic_array_
_mark_strict_int_or_real_array:
	add	x4,x4,#3
	b	_mark_basic_array_
_mark_strict_bool_array:
	add	x4,x4,#24+7
	lsr	x4,x4,#3
	b	_mark_basic_array_

_mark_b_record_array:
	ldr	x10,[x8,#8]
	sub	x4,x4,#256
	mul	x4,x10,x4
	add	x4,x4,#3
	b	_mark_basic_array_

_mark_string_:
	ldr	x4,[x8,#8]
	add	x4,x4,#16+7
	lsr	x4,x4,#3

_mark_basic_array_:
	orr	x16,x16,x7
	str	w16,[x27,x3,lsl #2]

	add	x2,x2,x4
	add	x16,x8,#-8
	add	x4,x16,x4,lsl #3

	sub	x4,x4,x0
	lsr	x4,x4,#8

	cmp	x3,x4
	bhs	_mark_next_node

	add	x3,x3,#1
	cmp	x3,x4
	bhs	_last_string_bits

_mark_string_lp:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x4
	blo	_mark_string_lp

_last_string_bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	b	_mark_next_node

__end_mark_using_reversal:
	ldr	x9,[x28],#8
	cbz	x9,_mark_next_node
	str	x8,[x9]
	b	_mark_next_node
.endif

	.ltorg

__mark_using_reversal:
	str	x8,[x28,#-8]!
	mov	x7,#1
	ldr	x8,[x8]
	b	__mark_node

// x3,x9,x10,x16 contain bit vector word index,bit index,mask and word value
__mark_arguments:
	ldr	x4,[x8]
	orr	x16,x16,x10

	tbz	x4,#1,__mark_lazy_node

	ldrh	w10,[x4,#-2]
	cbz	x10,__mark_hnf_0

	add	x8,x8,#8

	cmp	x10,#256
	bhs	__mark_record

	subs	x10,x10,#2
	beq	__mark_hnf_2
	blo	__mark_hnf_1

__mark_hnf_3:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	fits__in__word__1
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits__in__word__1:
	ldr	x9,[x8,#8]
	sub	x4,x9,x0

	lsr	x3,x4,#8
	ubfx	x4,x4,#3,#5

	mov	x29,#1
	lsl	x29,x29,x4

	ldr	w16,[x27,x3,lsl #2]
	tst	x29,x16
	bne	__shared_argument_part

__no_shared_argument_part:
	orr	x16,x16,x29
	str	w16,[x27,x3,lsl #2]

	add	x10,x10,#1
	str	x7,[x8,#8]!

	ldr	x16,[x9]
	add	x2,x2,x10

	orr	x16,x16,#1
	str	x16,[x9]

	add	x4,x4,x10
	add	x9,x9,x10,lsl #3

	cmp	x4,#32
	bls	fits__in__word__2
	ldr	w7,[x11,x3,lsl #2]
	orr	x7,x7,#1
	str	w7,[x11,x3,lsl #2]
fits__in__word__2:

	ldr	x10,[x9,#-8]
	str	x8,[x9,#-8]
	add	x7,x9,#-8
	mov	x8,x10
	b	__mark_node

__mark_hnf_1:
	add	x2,x2,#2
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-2
	bls	__shared_argument_part
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
__shared_argument_part:
	ldr	x10,[x8]
	str	x7,[x8]
	add	x7,x8,#2
	mov	x8,x10
	b	__mark_node

__mark_no_selector_1:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	__shared_argument_part

	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
	b	__shared_argument_part

__mark_lazy_node_1:
	beq	__mark_no_selector_1

__mark_selector_node_1:
	cmp	w10,#-2
	beq	__mark_indirection_node

	cmp	w10,#-3

	ldr	x10,[x8]

	ble	__mark_record_selector_node_1

	sub	x29,x10,x0
	lsr	x19,x29,#8
	ubfx	x29,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w19,[x27,x19,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x19
	bne	__mark_no_selector_1

	ldr	x29,[x10]
	tbz	x29,#1,__mark_no_selector_1

	ldrh	w29,[x29,#-2]
	cmp	x29,#2
	bls	__small_tuple_or_record

__large_tuple_or_record:	
	ldr	x10,[x10,#16]
	sub	x29,x10,x0
	lsr	x10,x29,#8
	ubfx	x29,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w10,[x27,x10,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x10
	bne	__mark_no_selector_1

.ifdef PIC
	ldr	w16,[x4,#-8]
	add	x4,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif
	ldr	x9,[x8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x4,x16]
.else
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	blt	__mark_tuple_selector_node_1
	ldr	x9,[x9,#16]
	beq	__mark_tuple_selector_node_2
	sub	x4,x4,#24
	ldr	x8,[x9,x4]
	str	x8,[x10]
	b	__mark_node

__mark_tuple_selector_node_2:
	ldr	x8,[x9]
	str	x8,[x10]
	b	__mark_node

__small_tuple_or_record:
.ifdef PIC
	ldr	w16,[x4,#-8]
	add	x4,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif
	ldr	x9,[x8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x4,x16]
.else
	ldrh	w4,[x4,#4]
.endif
__mark_tuple_selector_node_1:
	ldr	x8,[x9,x4]
	str	x8,[x10]
	b	__mark_node

__mark_record_selector_node_1:
	beq	__mark_strict_record_selector_node_1

	sub	x29,x10,x0
	lsr	x19,x29,#8
	ubfx	x29,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w19,[x27,x19,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x19
	bne	__mark_no_selector_1

	ldr	x29,[x10]
	tbz	x29,#1,__mark_no_selector_1

	ldrh	w29,[x29,#-2]
	cmp	x29,#258
	bls	__small_record

	ldr	x10,[x10,#16]
	sub	x29,x10,x0
	lsr	x10,x29,#8
	ubfx	x29,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w10,[x27,x10,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x10
	bne	__mark_no_selector_1

__small_record:
.ifdef PIC
	ldr	x16,[x4,#-8]
	add	x4,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif
	ldr	x9,[x8]
	str	x20,[x8,#-8] // e__system__nind
	mov	x10,x8

.ifdef PIC
	ldrh	w4,[x4,x16]
.else
	ldrh	w4,[x4,#4]
.endif
	cmp	x4,#16
	ble	__mark_record_selector_node_2
	ldr	x9,[x9,#16]
	sub	x4,x4,#24
__mark_record_selector_node_2:
	ldr	x8,[x9,x4]

	str	x8,[x10]
	b	__mark_node

__mark_strict_record_selector_node_1:
	sub	x29,x10,x0
	lsr	x19,x29,#8
	ubfx	x4,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w19,[x27,x19,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x19
	bne	__mark_no_selector_1

	ldr	x29,[x10]
	tbz	x29,#1,__mark_no_selector_1

	ldrh	w29,[x29,#-2]
	cmp	x29,#258
	ble	__select_from_small_record

	ldr	x10,[x10,#16]
	sub	x29,x10,x0
	lsr	x10,x29,#8
	ubfx	x29,x29,#3,#5
	eor	x29,x29,#(1<<63)+63 // set msb and compute 63-x

	ldr	w10,[x27,x10,lsl #2]
	lsr	x29,x29,x29
	tst	x29,x10
	bne	__mark_no_selector_1

__select_from_small_record:
.ifdef PIC
	ldr	w4,[x4,#-8]
	add	x16,x4,#-8+4
.else
	ldr	w4,[x4,#-8]
.endif
	ldr	x9,[x8],#-8

.ifdef PIC
	ldrh	w3,[x4,x16]!
.else
	ldrh	w3,[x4,#4]
.endif
	cmp	x3,#16
	ble	__mark_strict_record_selector_node_2
	ldr	x16,[x9,#16]
	add	x3,x3,x16
	ldr	x3,[x3,#-24]
	b	__mark_strict_record_selector_node_3
__mark_strict_record_selector_node_2:
	ldr	x3,[x9,x3]
__mark_strict_record_selector_node_3:
	str	x3,[x8,#8]

.ifdef PIC
	ldrh	w3,[x4,#6-4]
.else
	ldrh	w3,[x4,#6]
.endif
	tst	x3,x3
	beq	__mark_strict_record_selector_node_5
	cmp	x3,#16
	ble	__mark_strict_record_selector_node_4
	ldr	x9,[x9,#16]
	sub	x3,x3,#24
__mark_strict_record_selector_node_4:
	ldr	x3,[x9,x3]
	str	x3,[x8,#16]
__mark_strict_record_selector_node_5:
	ldr	x4,[x4,#-8]
	str	x4,[x8]
	b	__mark_node

__mark_indirection_node:
	ldr	x8,[x8]
	b	__mark_node

__mark_hnf_2:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	fits__in__word__6
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits__in__word__6:

__mark_record_2_c:
	ldr	x4,[x8]
	ldr	x10,[x8,#8]
	orr	x4,x4,#2
	str	x7,[x8,#8]
	str	x4,[x8]
	add	x7,x8,#8
	mov	x8,x10

__mark_node:
	sub	x9,x8,x0
	cmp	x9,x1
	bhs	__mark_next_node

	lsr	x3,x9,#8
	ubfx	x9,x9,#3,#5
	mov	x29,#1
	lsl	x10,x29,x9

	ldr	w16,[x27,x3,lsl #2]
	tst	x10,x16
	beq	__mark_arguments

__mark_next_node:
	tst	x7,#3
	bne	__mark_parent

	ldr	x10,[x7,#-8]
	ldr	x9,[x7]
	str	x8,[x7]
	str	x9,[x7,#-8]!

	and	x8,x10,#-4
	and	x10,x10,#3
	orr	x7,x7,x10
	b	__mark_node

__mark_parent:
	mov	x3,x7
	ands	x7,x7,#-4
	beq	__end_mark_using_reversal

	and	x3,x3,#3
	ldr	x10,[x7]
	str	x8,[x7]

	subs	x3,x3,#1
	beq	__argument_part_parent

	add	x8,x7,#-8
	mov	x7,x10
	b	__mark_next_node

__argument_part_parent:
	and	x10,x10,#-4
	mov	x9,x7
	ldr	x8,[x10,#-8]
	ldr	x3,[x10]
	str	x3,[x10,#-8]
	str	x9,[x10]
	add	x7,x10,#2-8
	b	__mark_node

__mark_lazy_node:
	ldr	w10,[x4,#-4]
	cbz	x10,__mark_node2_bb

	add	x8,x8,#8
	cmp	w10,#1
	ble	__mark_lazy_node_1
	cmp	w10,#256
	bge	__mark_closure_with_unboxed_arguments

	add	x4,x10,#1	
	str	w16,[x27,x3,lsl #2]

	sub	x10,x10,#1
	add	x4,x9,x4
	add	x2,x2,x4

	cmp	x4,#32
	bls	fits__in__word__7
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits__in__word__7:
__mark_closure_with_unboxed_arguments__2:
	add	x9,x8,x10,lsl #3
	ldr	x4,[x8]
	orr	x4,x4,#2
	str	x4,[x8]	
	ldr	x8,[x9]
	str	x7,[x9]
	mov	x7,x9
	b	__mark_node

__mark_closure_with_unboxed_arguments:
	lsr	x4,x10,#8
	and	x10,x10,#255

	subs	x10,x10,#1
	beq	__mark_closure_1_with_unboxed_argument

	add	x10,x10,#2
	str	w16,[x27,x3,lsl #2]

	add	x2,x2,x10
	add	x9,x9,x10
	sub	x10,x10,x4

	cmp	x9,#32
	bls	fits__in_word_7_
	ldr	w16,[x11,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x11,x3,lsl #2]
fits__in_word_7_:

	subs	x10,x10,#2
	bgt	__mark_closure_with_unboxed_arguments__2
	beq	__shared_argument_part
	sub	x8,x8,#8
	b	__mark_next_node

__mark_closure_1_with_unboxed_argument:
	sub	x8,x8,#8
	b	__mark_node2_bb

__mark_hnf_0:
	cmp	x4,x12 // INT+2
	bne	__no_int_3

	ldr	x10,[x8,#8]
	cmp	x10,#33
	blo	____small_int

__mark_real_bool_or_small_string:
	add	x2,x2,#2
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-2
	bls	__mark_next_node

	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
	b	__mark_next_node

____small_int:
	adrp	x8,small_integers
	add	x8,x8,#:lo12:small_integers
	add	x8,x8,x10,lsl #4
	b	__mark_next_node

__no_int_3:
	cmp	x4,x14 // __STRING__+2
	bls	__mark_string_or_array

 	cmp	x4,x13 // CHAR+2
 	bne	__no_char_3

	ldrb	w10,[x8,#8]
	adrp	x8,static_characters
	add	x8,x8,#:lo12:static_characters
	add	x8,x8,x10,lsl #4
	b	__mark_next_node

__no_char_3:
	blo	__mark_real_bool_or_small_string

	add	x8,x4,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	b	__mark_next_node

__mark_node2_bb:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	__mark_next_node

	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
	b	__mark_next_node

__mark_record:
	subs	x10,x10,#258
	beq	__mark_record_2
	blt	__mark_record_1

__mark_record_3:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	fits__in__word__13
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits__in__word__13:
	ldrh	w3,[x4,#-2+2]

	ldr	x9,[x8,#8]
	sub	x16,x9,x0
	lsr	x4,x16,#8
	ubfx	x16,x16,#3,#5

	mov	x29,#1
	lsl	x29,x29,x16

	ldr	w16,[x27,x4,lsl #2]
	tst	x29,x16
	bne	__shared_record_argument_part

	orr	x16,x16,x29
	str	w16,[x27,x4,lsl #2]

	lsl	w29,w29,w10
	add	x10,x10,#1
	add	x2,x2,x10

	cbnz	x29,fits__in__word__14
	ldr	w16,[x11,x4,lsl #2]
	orr	x16,x16,#1
	str	w16,[x11,x4,lsl #2]
fits__in__word__14:
	subs	x3,x3,#1

	blt	__mark_record_3_bb
	beq	__shared_argument_part

	str	x7,[x8,#8]!

	subs	x3,x3,#1
	beq	__mark_record_3_aab

	add	x7,x9,x3,lsl #3
	ldr	x4,[x9]
	orr	x4,x4,#1
	ldr	x10,[x7]
	str	x4,[x9]
	str	x8,[x7]
	mov	x8,x10
	b	__mark_node

__mark_record_3_bb:
	sub	x8,x8,#8
	b	__mark_next_node

__mark_record_3_aab:
	ldr	x10,[x9]
	str	x8,[x9]
	add	x7,x9,#1
	mov	x8,x10
	b	__mark_node

__shared_record_argument_part:
	cbnz	x3,__shared_argument_part
	sub	x8,x8,#8
	b	__mark_next_node

__mark_record_2:
	add	x2,x2,#3
	str	w16,[x27,x3,lsl #2]

	cmp	x9,#32-3
	bls	fits__in__word_12
	ldr	w9,[x11,x3,lsl #2]
	orr	x9,x9,#1
	str	w9,[x11,x3,lsl #2]
fits__in__word_12:
	ldrh	w16,[x4,#-2+2]
	cmp	x16,#1
	bhi	__mark_record_2_c
	beq	__shared_argument_part
	sub	x8,x8,#8
	b	__mark_next_node

__mark_record_1:
	ldrh	w29,[x4,#-2+2]
	cbnz	x29,__mark_hnf_1
	sub	x8,x8,#8
	b	__mark_real_bool_or_small_string

__mark_string_or_array:
	beq	__mark_string_

__mark_array:
	ldr	x10,[x8,#16]
	cbz	x10,__mark_lazy_array

	ldrh	w4,[x10,#-2]
	cbz	x4,__mark_strict_basic_array

	ldrh	w10,[x10,#-2+2]
	cbz	x10,__mark_b_record_array

	sub	x4,x4,#256
	cmp	x4,x10
	beq	__mark_a_record_array

__mark__ab__record__array:
	stp	x3,x16,[x28,#-16]!
	mov	x3,x10

	ldr	x10,[x8,#8]
	add	x8,x8,#16
	str	x8,[x28,#-8]!

	lsl	x10,x10,#3
	mov	x9,x4
	mul	x9,x10,x9

	sub	x4,x4,x3
	add	x8,x8,#8
	add	x9,x9,x8

	mov	x29,x30
	bl	reorder
	mov	x30,x29

	ldr	x8,[x28],#8

	mov	x16,x4
	mov	x4,x3
	mov	x3,x16
	ldr	x10,[x8,#-8]
	mul	x4,x10,x4
	mul	x3,x10,x3
	add	x2,x2,x3
	add	x3,x3,x4

	lsl	x3,x3,#3
	sub	x10,x8,x0
	add	x10,x10,x3

	ldp	x3,x16,[x28],#16

	str	w16,[x27,x3,lsl #2]

	add	x9,x8,x4,lsl #3
	b	__mark_r_array

__mark_a_record_array:
	ldr	x29,[x8,#8]
	add	x8,x8,#16
	mul	x4,x29,x4
	b	__mark_lr_array

__mark_lazy_array:
	ldr	x4,[x8,#8]
	add	x8,x8,#16

__mark_lr_array:
	str	w16,[x27,x3,lsl #2]
	add	x9,x8,x4,lsl #3
	sub	x10,x9,x0
__mark_r_array:
	lsr	x10,x10,#8

	cmp	x3,x10
	bhs	__skip_mark_lazy_array_bits

	add	x3,x3,#1

__mark_lazy_array_bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x10
	bls	__mark_lazy_array_bits

__skip_mark_lazy_array_bits:
	add	x2,x2,#3
	add	x2,x2,x4

	cmp	x4,#1
	bls	__mark_array_length_0_1

	ldr	x10,[x9]
	ldr	x3,[x8]
	str	x3,[x9]
	str	x10,[x8]

	ldr	x10,[x9,#-8]!
	adrp	x16,lazy_array_list
	ldr	x3,[x16,#:lo12:lazy_array_list]
	add	x10,x10,#2
	str	x3,[x9]
	str	x10,[x8,#-8]
	str	x4,[x8,#-16]!
#	adrp	x16,lazy_array_list
	str	x8,[x16,#:lo12:lazy_array_list]

	ldr	x8,[x9,#-8]
	str	x7,[x9,#-8]
	add	x7,x9,#-8
	b	__mark_node

__mark_array_length_0_1:
	add	x8,x8,#-16
	blo	__mark_next_node

	ldr	x3,[x8,#24]
	ldr	x10,[x8,#16]
	adrp	x16,lazy_array_list
	ldr	x9,[x16,#:lo12:lazy_array_list]
	str	x10,[x8,#24]	
	str	x9,[x8,#16]
	str	x4,[x8]
#	adrp	x16,lazy_array_list
	str	x8,[x16,#:lo12:lazy_array_list]
	str	x3,[x8,#8]!

	ldr	x10,[x8]
	str	x7,[x8]
	add	x7,x8,#2
	mov	x8,x10
	b	__mark_node

__mark_b_record_array:
	ldr	x10,[x8,#8]
	sub	x4,x4,#256
	mul	x4,x10,x4
	add	x4,x4,#3
	b	__mark_basic_array

__mark_strict_basic_array:
	ldr	x4,[x8,#8]
	cmp	x10,x12 // INT+2
	ble	__mark__strict__int__or_real_array
	cmp	x10,x15 // BOOL+2
	beq	__mark__strict__bool__array
__mark__strict__int32_or_real32__array:
	add	x4,x4,#6+1
	lsr	x4,x4,#1
	b	__mark_basic_array
__mark__strict__int__or_real_array:
	add	x4,x4,#3
	b	__mark_basic_array
__mark__strict__bool__array:
	add	x4,x4,#24+7
	lsr	x4,x4,#3
	b	__mark_basic_array

__mark_string_:
	ldr	x4,[x8,#8]
	add	x4,x4,#16+7
	lsr	x4,x4,#3

__mark_basic_array:
	add	x2,x2,x4
	str	w16,[x27,x3,lsl #2]

	add	x16,x8,#-8
	add	x4,x16,x4,lsl #3

	sub	x4,x4,x0
	lsr	x4,x4,#8

	cmp	x3,x4
	bhs	__mark_next_node

	add	x3,x3,#1
	cmp	x3,x4
	bhs	__last__string__bits

__mark_string_lp:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	add	x3,x3,#1
	cmp	x3,x4
	blo	__mark_string_lp

__last__string__bits:
	ldr	w16,[x27,x3,lsl #2]
	orr	x16,x16,#1
	str	w16,[x27,x3,lsl #2]
	b	__mark_next_node

	.ltorg

