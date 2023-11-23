
ZERO_ARITY_DESCRIPTOR_OFFSET = -4

#undef COUNT_GARBAGE_COLLECTIONS
#undef MARK_USING_REVERSAL
#undef COMPARE_HEAP_AFTER_MARK
#undef DEBUG_MARK_COLLECT

	lao	r7,heap_size_33,6
	ldo	r1,r7,heap_size_33,6
	mov	r0,#0

@ heap_p3 in r8

	lao	r7,heap_p3,9
	ldo	r8,r7,heap_p3,9

@ n_marked_words in r10

	mov	r10,#0

	lsl	r9,r1,#5
@ heap_size_32_33 in r9
	lao	r7,heap_size_32_33,0
	sto	r9,r7,heap_size_32_33,0

	lao	r7,lazy_array_list,0
	sto	r0,r7,lazy_array_list,0

	add	r5,sp,#-2000

	lao	r7,caf_list,1
	ldo	r1,r7,caf_list,1

	lao	r7,end_stack,0
@ end_stack in r12
	mov	r12,r5
	sto	r5,r7,end_stack,0

	tst	r1,r1
	beq	_end_mark_cafs

_mark_cafs_lp:
	ldr	r0,[r1]
	ldr	r4,[r1,#-4]

	str	r4,[sp,#-4]!
	add	r4,r1,#4
	add	r7,r1,#4
	add	r1,r7,r0,lsl #2
	lao	r7,end_vector,0
	sto	r1,r7,end_vector,0

	adr	r14,1+0f
	push	{r14}
	bl	_mark_stack_nodes
0:
	ldr	r1,[sp],#4
	tst	r1,r1
	bne	_mark_cafs_lp

_end_mark_cafs:
	lao	r7,stack_top,2
	ldo	r5,r7,stack_top,2
	lao	r7,stack_p,5
	ldo	r4,r7,stack_p,5

	lao	r7,end_vector,1
	sto	r5,r7,end_vector,1
	adr	r14,1+0f
	push	{r14}
	bl	_mark_stack_nodes
0:
	lao	r7,lazy_array_list,1
	ldo	r2,r7,lazy_array_list,1

	cmp	r2,#0
	beq	end_restore_arrays

restore_arrays:
	ldr	r0,[r2]
	laol	r7,__ARRAY__+2,__ARRAY___o_2,16
	otoa	r7,__ARRAY___o_2,16
	str	r7,[r2]

	cmp	r0,#1
	beq	restore_array_size_1

	add	r3,r2,r0,lsl #2	
	ldr	r1,[r3,#8]
	cmp	r1,#0
	beq	restore_lazy_array

	ldrh	r4,[r1,#-2+2]

	neg	r7,r4
	and	r7,r7,r4
@ r7 contains lowest 1 bit of r4
	clz	r7,r7
	rsb	r7,r7,#31
	lsr	r4,r4,r7
	lsr	r0,r0,r7
	adr	r6,1f
	sub	r4,r4,#1
	add	r4,r4,r4
	ldr	r4,[r6,r4]
	b	skip_mod_inverse_table
1:
	.word	1
	.word	-1431655765
	.word	-858993459
	.word	-1227133513
	.word	954437177
	.word	-1171354717
	.word	-991146299
	.word	-286331153
	.word	-252645135
	.word	678152731
	.word	1022611261
	.word	-373475417
	.word	-1030792151
	.word	1749801491
	.word	1332920885
	.word	-1108378657

skip_mod_inverse_table:
	mul	r0,r4,r0

restore_lazy_array:
	ldr	r6,[r2,#8]
	ldr	r4,[r2,#4]
	str	r0,[r2,#4]
	ldr	r5,[r3,#4]
	str	r1,[r2,#8]
	str	r4,[r3,#4]
	str	r6,[r3,#8]

	cmp	r1,#0
	beq	no_reorder_array

	ldrh	r3,[r1,#-2]
	sub	r3,r3,#256
	ldrh	r4,[r1,#-2+2]
	cmp	r4,r3
	beq	no_reorder_array

	add	r2,r2,#12
	mul	r0,r3,r0
	mov	r1,r3
	add	r3,r2,r0,lsl #2
	mov	r0,r4
	sub	r1,r1,r4

	adr	r14,1+0f
	push	{r14}
	bl	reorder
0:
no_reorder_array:
	mov	r2,r5
	cmp	r2,#0
	bne	restore_arrays

	b	end_restore_arrays

restore_array_size_1:
	ldr	r4,[r2,#4]
	ldr	r3,[r2,#8]
	str	r0,[r2,#4]
	ldr	r1,[r2,#12]	
	str	r4,[r2,#12]
	str	r1,[r2,#8]

	mov	r2,r3
	tst	r2,r2
	bne	restore_arrays

end_restore_arrays:

.ifdef FINALIZERS
	lao	r7,heap_vector,7
	ldo	r6,r7,heap_vector,7
	lao	r2,finalizer_list,2
	lao	r3,free_finalizer_list,4
	otoa	r2,finalizer_list,2
	otoa	r3,free_finalizer_list,4

	ldr	r4,[r2]
determine_free_finalizers_after_mark:
	laol	r7,__Nil-4,__Nil_o_m4,4
	otoa	r7,__Nil_o_m4,4
	cmp	r4,r7
	beq	end_finalizers_after_mark

	sub	r1,r4,r8
	lsr	r0,r1,#7
	and	r1,r1,#31*4
	lsr	r5,r1,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	beq	finalizer_not_used_after_mark

	add	r2,r4,#4
	ldr	r4,[r4,#4]
	b	determine_free_finalizers_after_mark

finalizer_not_used_after_mark:
	str	r4,[r3]
	add	r3,r4,#4

	ldr	r4,[r4,#4]
	str	r4,[r2]
	b	determine_free_finalizers_after_mark

end_finalizers_after_mark:
	str	r4,[r3]
.endif

	push	{r3}

	adr	r14,1+0f
	push	{r14}
	bl	add_garbage_collect_time
0:
	pop	{r3}

.ifdef ADJUST_HEAP_SIZE
	lao	r7,bit_vector_size,3
	ldo	r1,r7,bit_vector_size,3
.else
	lao	r7,heap_size_33,7
	ldo	r1,r7,heap_size_33,7
	lsl	r1,r1,#3
.endif

.ifdef ADJUST_HEAP_SIZE
	lao	r7,n_allocated_words,7
	ldo	r6,r7,n_allocated_words,7
	add	r6,r6,r10
	lsl	r6,r6,#2

	lsl	r5,r1,#2

	str	r3,[sp,#-4]!
	str	r1,[sp,#-4]!

	lao	r7,heap_size_multiple,3
	ldo	r7,r7,heap_size_multiple,3
	umull	r1,r3,r7,r6
	lsr	r1,r1,#8
	orr	r1,r1,r3,lsl #32-8
	lsr	r3,r3,#8

	mov	r0,r1
	cmp	r3,#0

	ldr	r1,[sp],#4
	ldr	r3,[sp],#4

	beq	not_largest_heap

	lao	r7,heap_size_33,8
	ldo	r0,r7,heap_size_33,8
	lsl	r0,r0,#5

not_largest_heap:
	cmp	r0,r5
	bls	no_larger_heap

	lao	r7,heap_size_33,9
	ldo	r5,r7,heap_size_33,9
	lsl	r5,r5,#5
	cmp	r0,r5
	bls	not_larger_then_heap
	mov	r0,r5
not_larger_then_heap:
	lsr	r1,r0,#2
	lao	r7,bit_vector_size,4
	sto	r1,r7,bit_vector_size,4
no_larger_heap:
.endif
	mov	r4,r1

	lao	r7,heap_vector,8
	ldo	r6,r7,heap_vector,8

	lsr	r4,r4,#5

	tst	r1,#31
	beq	no_extra_word

	mov	r7,#0
	str	r7,[r6,r4,lsl #2]

no_extra_word:
	sub	r1,r1,r10
	lsl	r1,r1,#2
	lao	r7,n_last_heap_free_bytes,2
	sto	r1,r7,n_last_heap_free_bytes,2

	lao	r7,flags,15
	ldo	r7,r7,flags,15
	tst	r7,#2
	beq	_no_heap_use_message2

	str	r10,[sp,#-4]!

	lao	r0,marked_gc_string_1,0
	otoa	r0,marked_gc_string_1,0
	bl	ew_print_string

	ldr	r10,[sp]
	lsl	r0,r10,#2
	bl	ew_print_int

	lao	r0,heap_use_after_gc_string_2,1
	otoa	r0,heap_use_after_gc_string_2,1
	bl	ew_print_string

	ldr	r10,[sp],#4

_no_heap_use_message2:

.ifdef FINALIZERS
	adr	r14,1+0f
	push	{r14}
	bl	call_finalizers
0:
.endif

	lao	r7,n_allocated_words,8
	ldo	r5,r7,n_allocated_words,8
	mov	r0,#0

@ n_free_words_after_mark in r10
	mov	r2,r6
	mov	r10,#0

_scan_bits:
	ldr	r7,[r2]
	cmp	r0,r7
	beq	_zero_bits
	str	r0,[r2],#4
	subs	r4,r4,#1
	bne	_scan_bits

	lao	r7,n_free_words_after_mark,5
	sto	r10,r7,n_free_words_after_mark,5
	b	_end_scan

_zero_bits:
	add	r3,r2,#4
	add	r2,r2,#4
	subs	r4,r4,#1
	bne	_skip_zero_bits_lp1

	lao	r7,n_free_words_after_mark,6
	sto	r10,r7,n_free_words_after_mark,6
	b	_end_bits

_skip_zero_bits_lp:
	cmp	r1,#0
	bne	_end_zero_bits
_skip_zero_bits_lp1:
	ldr	r1,[r2],#4
	subs	r4,r4,#1
	bne	_skip_zero_bits_lp

	lao	r7,n_free_words_after_mark,7
	sto	r10,r7,n_free_words_after_mark,7

	cmp	r1,#0
	beq	_end_bits
	mov	r1,r2
	str	r0,[r2,#-4]
	subs	r1,r1,r3
	b	_end_bits2

_end_zero_bits:
	sub	r1,r2,r3
	lsl	r1,r1,#3
	add	r10,r10,r1
	str	r0,[r2,#-4]

	cmp	r1,r5
	blo	_scan_bits

@ n_free_words_after_mark updated
_found_free_memory:
	lao	r7,n_free_words_after_mark,8
	sto	r10,r7,n_free_words_after_mark,8
	lao	r7,bit_counter,3
	sto	r4,r7,bit_counter,3
	lao	r7,bit_vector_p,2
	sto	r2,r7,bit_vector_p,2

	sub	r11,r1,r5

	add	r0,r3,#-4
	sub	r0,r0,r6
	lsl	r0,r0,#5
	lao	r7,heap_p3,10
	ldo	r6,r7,heap_p3,10
	add	r6,r6,r0

	lao	r7,stack_top,3
	ldo	r5,r7,stack_top,3

	add	r0,r6,r1,lsl #2
	lao	r7,heap_end_after_gc,11
	sto	r0,r7,heap_end_after_gc,11

	ldmia	sp!,{r0-r1,r8-r10,pc}

@ n_free_words_after_mark updated
_end_bits:
	sub	r1,r2,r3
	add	r1,r1,#4
_end_bits2:
	lsl	r1,r1,#3
	add	r10,r10,r1

	cmp	r1,r5
	bhs	_found_free_memory

	lao	r7,n_free_words_after_mark,9
	sto	r10,r7,n_free_words_after_mark,9

@ n_free_words_after_mark updated
_end_scan:
	lao	r7,bit_counter,4
	sto	r4,r7,bit_counter,4
	b	compact_gc

.ifdef PIC
	lto	heap_size_33,6
	lto	heap_p3,9
	lto	heap_size_32_33,0
	lto	lazy_array_list,0
	lto	caf_list,1
	lto	end_stack,0
	lto	end_vector,0
	lto	stack_top,2
	lto	stack_p,5
	lto	end_vector,1
	lto	lazy_array_list,1
	ltol	__ARRAY__+2,__ARRAY___o_2,16
.ifdef FINALIZERS
	lto	heap_vector,7
	lto	finalizer_list,2
	lto	free_finalizer_list,4
	ltol	__Nil-4,__Nil_o_m4,4
.endif
.ifdef ADJUST_HEAP_SIZE
	lto	bit_vector_size,3
.else
	lto	heap_size_33,7
.endif
.ifdef ADJUST_HEAP_SIZE
	lto	n_allocated_words,7
	lto	heap_size_multiple,3
	lto	heap_size_33,8
	lto	heap_size_33,9
	lto	bit_vector_size,4
.endif
	lto	heap_vector,8
	lto	n_last_heap_free_bytes,2
	lto	flags,15
	lto	marked_gc_string_1,0
	lto	heap_use_after_gc_string_2,1
	lto	n_allocated_words,8
	lto	n_free_words_after_mark,5
	lto	n_free_words_after_mark,6
	lto	n_free_words_after_mark,7
	lto	n_free_words_after_mark,8
	lto	bit_counter,3
	lto	bit_vector_p,2
	lto	heap_p3,10
	lto	stack_top,3
	lto	heap_end_after_gc,11
	lto	n_free_words_after_mark,9
	lto	bit_counter,4
.endif
	.ltorg

@ a2: pointer to stack element
@ a4: heap_vector
@ d0,d1,a0,a1,a3: free

_mark_stack_nodes:
	lao	r7,end_vector,2
	ldo	r7,r7,end_vector,2
	cmp	r4,r7
	beq	_end_mark_nodes
_mark_stack_nodes_:
	ldr	r2,[r4],#4

	sub	r3,r2,r8
	cmp	r3,r9
	bcs	_mark_stack_nodes

	lsr	r0,r3,#7
	and	r3,r3,#31*4
	lsr	r5,r3,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_mark_stack_nodes

	str	r4,[sp,#-4]!

.ifdef MARK_USING_REVERSAL
	mov	r5,#1
	b	__mark_node

__end_mark_using_reversal:
	ldr	r4,[sp],#4
	str	r2,[r4,#-4]
	b	_mark_stack_nodes
.else
	mov	r7,#0
	str	r7,[sp,#-4]!

	b	_mark_arguments

_mark_hnf_2:
	cmp	r5,#0x20000000
	bls	fits_in_word_6
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_6:
	add	r10,r10,#3

_mark_record_2_c:
	ldr	r0,[r2,#4]
	str	r0,[sp,#-4]!

	cmp	sp,r12
	blo	__mark_using_reversal

_mark_node2:
_shared_argument_part:
	ldr	r2,[r2]

_mark_node:
	sub	r3,r2,r8
	cmp	r3,r9
	bcs	_mark_next_node

	lsr	r0,r3,#7
	and	r3,r3,#31*4	
	lsr	r5,r3,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_mark_next_node

_mark_arguments:
	ldr	r1,[r2]
	tst	r1,#2
	beq	_mark_lazy_node

	ldrh	r4,[r1,#-2]

	cmp	r4,#0
	beq	_mark_hnf_0

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	add	r2,r2,#4

	cmp	r4,#256
	bhs	_mark_record

	subs	r4,r4,#2
	beq	_mark_hnf_2
	blo	_mark_hnf_1

_mark_hnf_3:
	ldr	r3,[r2,#4]

	cmp	r5,#0x20000000
	bls	fits_in_word_1
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_1:	

	sub	r1,r3,r8
	add	r10,r10,#3

	lsr	r0,r1,#7
	and	r1,r1,#31*4

	lsr	r5,r1,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_shared_argument_part

_no_shared_argument_part:
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	add	r4,r4,#1

	add	r10,r10,r4
	add	r1,r1,r4,lsl #2
	add	r7,r3,#-4
	add	r3,r7,r4,lsl #2

	cmp	r1,#32*4
	bls	fits_in_word_2
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_2:

	ldr	r0,[r3]
	sub	r4,r4,#2
	str	r0,[sp,#-4]!

_push_hnf_args:
	ldr	r0,[r3,#-4]!
	str	r0,[sp,#-4]!
	subs	r4,r4,#1
	bge	_push_hnf_args

	cmp	sp,r12
	bhs	_mark_node2

	b	__mark_using_reversal

_mark_hnf_1:
	cmp	r5,#0x40000000
	bls	fits_in_word_4
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_4:
	add	r10,r10,#2
	ldr	r2,[r2]
	b	_mark_node

_mark_lazy_node_1:
	add	r2,r2,#4
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	cmp	r5,#0x20000000
	bls	fits_in_word_3
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_3:
	add	r10,r10,#3

	cmp	r4,#1
	beq	_mark_node2

_mark_selector_node_1:
	cmp	r4,#-2
	ldr	r3,[r2]
	beq	_mark_indirection_node

	sub	r5,r3,r8

	lsr	r0,r5,#7
	and	r5,r5,#31*4

	cmp	r4,#-3

	lsr	r5,r5,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ble	_mark_record_selector_node_1

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_mark_node3

	ldr	r4,[r3]
	tst	r4,#2
	beq	_mark_node3

	ldrh	r7,[r4,#-2]
	cmp	r7,#2
	bls	_small_tuple_or_record

_large_tuple_or_record:
	ldr	r4,[r3,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	_mark_node3

	lao	r4,e__system__nind,11
.ifdef PIC
	add	r7,r1,#-8+4
.endif
	ldr	r1,[r1,#-1-8]
	otoa	r4,e__system__nind,11
	str	r4,[r2,#-4]
	mov	r4,r2

.ifdef PIC
	ldrh	r1,[r7,r1]
.else
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	blt	_mark_tuple_selector_node_1
	ldr	r3,[r3,#8]
	beq	_mark_tuple_selector_node_2
	add	r7,r1,#-12
	ldr	r2,[r3,r7]
	str	r2,[r4]
	b	_mark_node

_mark_tuple_selector_node_2:
	ldr	r2,[r3]
	str	r2,[r4]
	b	_mark_node

_small_tuple_or_record:
	lao	r4,e__system__nind,12
.ifdef PIC
	add	r7,r1,#-8+4
.endif
	ldr	r1,[r1,#-1-8]
	otoa	r4,e__system__nind,12
	str	r4,[r2,#-4]
	mov	r4,r2

.ifdef PIC
	ldrh	r1,[r7,r1]
.else
	ldrh	r1,[r1,#4]
.endif
_mark_tuple_selector_node_1:
	ldr	r2,[r3,r1]
	str	r2,[r4]
	b	_mark_node

_mark_record_selector_node_1:
	beq	_mark_strict_record_selector_node_1

	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_mark_node3

	ldr	r4,[r3]
	tst	r4,#2
	beq	_mark_node3

	ldrh	r7,[r4,#-2]
	cmp	r7,#258
	bls	_small_tuple_or_record

	ldr	r4,[r3,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	_mark_node3

	lao	r4,e__system__nind,13
.ifdef PIC
	add	r7,r1,#-8+4
.endif
	ldr	r1,[r1,#-1-8]
	otoa	r4,e__system__nind,13
	str	r4,[r2,#-4]
	mov	r4,r2

.ifdef PIC
	ldrh	r1,[r7,r1]
.else
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	ble	_mark_record_selector_node_2
	ldr	r3,[r3,#8]
	sub	r1,r1,#12
_mark_record_selector_node_2:
	ldr	r2,[r3,r1]

	str	r2,[r4]
	b	_mark_node

_mark_strict_record_selector_node_1:
	ldr	r7,[r6,r0,lsl #2]
	tst	r5,r7
	bne	_mark_node3

	ldr	r4,[r3]
	tst	r4,#2
	beq	_mark_node3

	ldrh	r7,[r4,#-2]
	cmp	r7,#258
	bls	_select_from_small_record

	ldr	r4,[r3,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	_mark_node3

_select_from_small_record:
.ifdef PIC
	ldr	r7,[r1,#-1-8]
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
	ble	_mark_strict_record_selector_node_2
	ldr	r7,[r3,#8]
	add	r0,r0,r7
	ldr	r0,[r0,#-12]
	b	_mark_strict_record_selector_node_3
_mark_strict_record_selector_node_2:
	ldr	r0,[r3,r0]
_mark_strict_record_selector_node_3:
	str	r0,[r2,#4]
.ifdef PIC
	ldrh	r0,[r1,#6-4]
.else
	ldrh	r0,[r1,#6]
.endif
	tst	r0,r0
	beq	_mark_strict_record_selector_node_5
	cmp	r0,#8
	ble	_mark_strict_record_selector_node_4
	ldr	r3,[r3,#8]
	sub	r0,r0,#12
_mark_strict_record_selector_node_4:
	ldr	r0,[r3,r0]
	str	r0,[r2,#8]
_mark_strict_record_selector_node_5:

.ifdef PIC
	ldr	r1,[r1,#-4-4]
.else
	ldr	r1,[r1,#-4]
.endif
	str	r1,[r2]
	b	_mark_next_node

_mark_indirection_node:
_mark_node3:
	mov	r2,r3
	b	_mark_node

_mark_next_node:
	ldr	r2,[sp],#4
	tst	r2,r2
	bne	_mark_node

	lao	r7,end_vector,3
	ldr	r4,[sp],#4
	ldo	r7,r7,end_vector,3
	cmp	r4,r7
	bne	_mark_stack_nodes_

_end_mark_nodes:
	ldr	pc,[sp],#4

_mark_lazy_node:
	ldr	r4,[r1,#-1-4]
	tst	r4,r4
	beq	_mark_real_or_file

	cmp	r4,#1
	ble	_mark_lazy_node_1

	cmp	r4,#256
	bge	_mark_closure_with_unboxed_arguments
	add	r4,r4,#1
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]

	add	r10,r10,r4
	add	r3,r3,r4,lsl #2
	add	r2,r2,r4,lsl #2

	cmp	r3,#32*4
	bls	fits_in_word_7
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits_in_word_7:
	sub	r4,r4,#3
_push_lazy_args:
	ldr	r0,[r2,#-4]!
	str	r0,[sp,#-4]!
	subs	r4,r4,#1
	bge	_push_lazy_args

	sub	r2,r2,#4

	cmp	sp,r12
	bhs	_mark_node2

	b	__mark_using_reversal

_mark_closure_with_unboxed_arguments:
	mov	r1,r4
	and	r4,r4,#255
	subs	r4,r4,#1
	beq	_mark_real_or_file

	lsr	r1,r1,#8
	add	r4,r4,#2

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	add	r10,r10,r4
	add	r3,r3,r4,lsl #2

	sub	r4,r4,r1

	cmp	r3,#32*4
	bls	fits_in_word_7_
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits_in_word_7_:
	subs	r4,r4,#2
	blt	_mark_next_node

	add	r7,r2,#8
	add	r2,r7,r4,lsl #2
	bne	_push_lazy_args

_mark_closure_with_one_boxed_argument:
	ldr	r2,[r2,#-4]
	b	_mark_node

_mark_hnf_0:
	laol	r7,INT+2,INT_o_2,7
	otoa	r7,INT_o_2,7
	cmp	r1,r7
	blo	_mark_real_file_or_string

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]

	laol	r7,CHAR+2,CHAR_o_2,3
	otoa	r7,CHAR_o_2,3
	cmp	r1,r7
	bhi	_mark_normal_hnf_0

_mark_bool:
	add	r10,r10,#2

	cmp	r5,#0x40000000
	bls	_mark_next_node

	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
	b	_mark_next_node

_mark_normal_hnf_0:
	add	r10,r10,#1
	b	_mark_next_node

_mark_real_file_or_string:
	laol	r7,__STRING__+2,__STRING___o_2,8
	otoa	r7,__STRING___o_2,8
	cmp	r1,r7
	bls	_mark_string_or_array

_mark_real_or_file:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	add	r10,r10,#3

	cmp	r5,#0x20000000
	bls	_mark_next_node

	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
	b	_mark_next_node

_mark_record:
	subs	r4,r4,#258
	beq	_mark_record_2
	blt	_mark_record_1

_mark_record_3:
	add	r10,r10,#3

	cmp	r5,#0x20000000
	bls	fits_in_word_13
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits_in_word_13:
	ldr	r3,[r2,#4]

	ldrh	r0,[r1,#-2+2]
	sub	r5,r3,r8

	lsr	r1,r5,#7
	and	r5,r5,#31*4

	subs	r0,r0,#1

	lsr	r3,r5,#2
	mov	r7,#1
	lsl	r3,r7,r3

	blo	_mark_record_3_bb

	ldr	r7,[r6,r1,lsl #2]
	tst	r3,r7
	bne	_mark_node2

	add	r4,r4,#1
	ldr	r7,[r6,r1,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r1,lsl #2]
	add	r10,r10,r4
	add	r5,r5,r4,lsl #2

	cmp	r5,#32*4
	bls	_push_record_arguments
	add	r7,r6,#4
	ldr	r3,[r7,r1,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r1,lsl #2]
_push_record_arguments:
	ldr	r3,[r2,#4]
	mov	r4,r0
	lsl	r0,r0,#2
	add	r3,r3,r0
	subs	r4,r4,#1
	bge	_push_hnf_args

	b	_mark_node2

_mark_record_3_bb:
	ldr	r7,[r6,r1,lsl #2]
	tst	r3,r7
	bne	_mark_next_node

	add	r4,r4,#1
	ldr	r7,[r6,r1,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r1,lsl #2]
	add	r10,r10,r4
	add	r5,r5,r4,lsl #2

	cmp	r5,#32*4
	bls	_mark_next_node

	add	r7,r6,#4
	ldr	r3,[r7,r1,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r1,lsl #2]
	b	_mark_next_node

_mark_record_2:
	cmp	r5,#0x20000000
	bls	fits_in_word_12
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits_in_word_12:
	add	r10,r10,#3

	ldrh	r7,[r1,#-2+2]
	cmp	r7,#1
	bhi	_mark_record_2_c
	beq	_mark_node2
	b	_mark_next_node

_mark_record_1:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#0
	bne	_mark_hnf_1

	b	_mark_bool

_mark_string_or_array:
	beq	_mark_string_

_mark_array:
	ldr	r4,[r2,#8]
	cmp	r4,#0
	beq	_mark_lazy_array

	ldrh	r1,[r4,#-2]

	cmp	r1,#0
	beq	_mark_strict_basic_array

	ldrh	r4,[r4,#-2+2]
	cmp	r4,#0
	beq	_mark_b_record_array

	cmp	sp,r12
	blo	_mark_array_using_reversal

	sub	r1,r1,#256
	cmp	r1,r4
	beq	_mark_a_record_array

_mark_ab_record_array:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	ldr	r4,[r2,#4]

	mul	r1,r4,r1
	add	r1,r1,#3

	add	r10,r10,r1
	add	r7,r2,#-4
	add	r1,r7,r1,lsl #2

	sub	r1,r1,r8
	lsr	r1,r1,#7

	cmp	r0,r1
	bhs	_end_set_ab_array_bits

	add	r0,r0,#1
	mov	r4,#1
	cmp	r0,r1
	bhs	_last_ab_array_bits

_mark_ab_array_lp:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r1
	blo	_mark_ab_array_lp

_last_ab_array_bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]

_end_set_ab_array_bits:
	ldr	r1,[r2,#4]
	ldr	r3,[r2,#8]
	ldrh	r0,[r3,#-2+2]
	ldrh	r3,[r3,#-2]
	lsl	r0,r0,#2
	sub	r3,r3,#256
	lsl	r3,r3,#2
	str	r0,[sp,#-4]!
	str	r3,[sp,#-4]!
	add	r4,r2,#12

	lao	r7,end_vector,4
	ldo	r7,r7,end_vector,4
	str	r7,[sp,#-4]!
	b	_mark_ab_array_begin

_mark_ab_array:
	ldr	r0,[sp,#8]
	str	r1,[sp,#-4]!
	str	r4,[sp,#-4]!
	add	r1,r4,r0

	lao	r7,end_vector,5
	sto	r1,r7,end_vector,5
	adr	r14,1+0f
	push	{r14}
	bl	_mark_stack_nodes
0:
	ldr	r0,[sp,#4+8]
	ldr	r4,[sp],#4
	ldr	r1,[sp],#4
	add	r4,r4,r0
_mark_ab_array_begin:
	subs	r1,r1,#1
	bcs	_mark_ab_array

	ldr	r2,[sp]
	lao	r7,end_vector,6
	sto	r2,r7,end_vector,6
	add	sp,sp,#12
	b	_mark_next_node

_mark_a_record_array:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	ldr	r4,[r2,#4]

	mul	r1,r4,r1
	str	r1,[sp,#-4]!

	add	r1,r1,#3

	add	r10,r10,r1
	add	r7,r2,#-4
	add	r1,r7,r1,lsl #2

	sub	r1,r1,r8
	lsr	r1,r1,#7

	cmp	r0,r1
	bhs	_end_set_a_array_bits

	add	r0,r0,#1
	mov	r4,#1
	cmp	r0,r1
	bhs	_last_a_array_bits

_mark_a_array_lp:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r1
	blo	_mark_a_array_lp

_last_a_array_bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]

_end_set_a_array_bits:
	ldr	r1,[sp],#4
	add	r4,r2,#12

	lao	r7,end_vector,7
	ldo	r7,r7,end_vector,7
	str	r7,[sp,#-4]!
	add	r7,r2,#12
	add	r1,r7,r1,lsl #2

	lao	r7,end_vector,8
	sto	r1,r7,end_vector,8
	adr	r14,1+0f
	push	{r14}
	bl	_mark_stack_nodes
0:
	ldr	r2,[sp],#4
	lao	r7,end_vector,9
	sto	r2,r7,end_vector,9
	b	_mark_next_node

_mark_lazy_array:
	cmp	sp,r12
	blo	_mark_array_using_reversal

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]
	ldr	r1,[r2,#4]

	add	r1,r1,#3

	add	r10,r10,r1
	add	r7,r2,#-4
	add	r1,r7,r1,lsl #2

	sub	r1,r1,r8
	lsr	r1,r1,#7

	cmp	r0,r1
	bhs	_end_set_lazy_array_bits

	add	r0,r0,#1
	mov	r4,#1
	cmp	r0,r1
	bhs	_last_lazy_array_bits

_mark_lazy_array_lp:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r1
	blo	_mark_lazy_array_lp

_last_lazy_array_bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]

_end_set_lazy_array_bits:
	ldr	r1,[r2,#4]
	add	r4,r2,#12

	lao	r7,end_vector,10
	ldo	r7,r7,end_vector,10
	str	r7,[sp,#-4]!
	add	r7,r2,#12
	add	r1,r7,r1,lsl #2

	lao	r7,end_vector,11
	sto	r1,r7,end_vector,11
	adr	r14,1+0f
	push	{r14}
	bl	_mark_stack_nodes
0:
	ldr	r2,[sp],#4
	lao	r7,end_vector,12
	sto	r2,r7,end_vector,12
	b	_mark_next_node

_mark_array_using_reversal:
	mov	r7,#0
	str	r7,[sp,#-4]!
	mov	r5,#1
	b	__mark_node

_mark_strict_basic_array:
	ldr	r1,[r2,#4]
	laol	r7,INT+2,INT_o_2,8
	otoa	r7,INT_o_2,8
	cmp	r4,r7
	beq	_mark_strict_int_array
	laol	r7,BOOL+2,BOOL_o_2,5
	otoa	r7,BOOL_o_2,5
	cmp	r4,r7
	beq	_mark_strict_bool_array
_mark_strict_real_array:
	add	r1,r1,r1
_mark_strict_int_array:
	add	r1,r1,#3
	b	_mark_basic_array_
_mark_strict_bool_array:
	add	r1,r1,#12+3
	lsr	r1,r1,#2
	b	_mark_basic_array_

_mark_b_record_array:
	ldr	r4,[r2,#4]
	sub	r1,r1,#256
	mul	r1,r4,r1
	add	r1,r1,#3
	b	_mark_basic_array_

_mark_string_:
	ldr	r1,[r2,#4]
	add	r1,r1,#8+3
	lsr	r1,r1,#2

_mark_basic_array_:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r0,lsl #2]

	add	r10,r10,r1
	add	r7,r2,#-4
	add	r1,r7,r1,lsl #2

	sub	r1,r1,r8
	lsr	r1,r1,#7

	cmp	r0,r1
	bhs	_mark_next_node

	add	r0,r0,#1
	mov	r4,#1
	cmp	r0,r1
	bhs	_last_string_bits

_mark_string_lp:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r1
	blo	_mark_string_lp

_last_string_bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	b	_mark_next_node

__end_mark_using_reversal:
	ldr	r3,[sp],#4
	tst	r3,r3
	beq	_mark_next_node
	str	r2,[r3]
	b	_mark_next_node
.endif

.ifdef PIC
	lto	end_vector,2
	lto	e__system__nind,11
	lto	e__system__nind,12
	lto	e__system__nind,13
	lto	end_vector,3
	ltol	INT+2,INT_o_2,7
	ltol	CHAR+2,CHAR_o_2,3
	ltol	__STRING__+2,__STRING___o_2,8
	lto	end_vector,4
	lto	end_vector,5
	lto	end_vector,6
	lto	end_vector,7
	lto	end_vector,8
	lto	end_vector,9
	lto	end_vector,10
	lto	end_vector,11
	lto	end_vector,12
	ltol	INT+2,INT_o_2,8
	ltol	BOOL+2,BOOL_o_2,5
.endif
	.ltorg

__mark_using_reversal:
	str	r2,[sp,#-4]!
	mov	r5,#1
	ldr	r2,[r2]
	b	__mark_node

__mark_arguments:
	ldr	r1,[r2]
	tst	r1,#2
	beq	__mark_lazy_node

	ldrh	r4,[r1,#-2]
	tst	r4,r4
	beq	__mark_hnf_0

	add	r2,r2,#4

	cmp	r4,#256
	bhs	__mark__record

	subs	r4,r4,#2
	beq	__mark_hnf_2
	blo	__mark_hnf_1

__mark_hnf_3:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]

	cmp	r3,#0x20000000
	bls	fits__in__word__1
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in__word__1:
	ldr	r7,[r2,#4]
	sub	r1,r7,r8

	lsr	r0,r1,#7
	and	r1,r1,#31*4

	lsr	r3,r1,#2
	mov	r7,#1
	lsl	r3,r7,r3

	ldr	r7,[r6,r0,lsl #2]
	tst	r3,r7
	bne	__shared_argument_part

__no_shared_argument_part:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	ldr	r3,[r2,#4]

	add	r4,r4,#1
	str	r5,[r2,#4]

	add	r10,r10,r4
	add	r2,r2,#4

	lsl	r4,r4,#2
	ldr	r7,[r3]
	orr	r7,r7,#1
	str	r7,[r3]

	add	r1,r1,r4
	add	r3,r3,r4

	cmp	r1,#32*4
	bls	fits__in__word__2
	add	r7,r6,#4
	ldr	r5,[r7,r0,lsl #2]
	orr	r5,r5,#1
	str	r5,[r7,r0,lsl #2]
fits__in__word__2:

	ldr	r4,[r3,#-4]
	str	r2,[r3,#-4]
	add	r5,r3,#-4
	mov	r2,r4
	b	__mark_node

__mark_hnf_1:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#2
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r3,#0x40000000
	bls	__shared_argument_part
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
__shared_argument_part:
	ldr	r4,[r2]
	str	r5,[r2]
	add	r5,r2,#2
	mov	r2,r4
	b	__mark_node

__mark_no_selector_2:
	ldr	r0,[sp],#4
__mark_no_selector_1:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3
	ldr	r7,[r6,r0,lsl #2]	
	orr	r7,r7,r3	
	str	r7,[r6,r0,lsl #2]	
	cmp	r3,#0x20000000
	bls	__shared_argument_part

	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
	b	__shared_argument_part

__mark_lazy_node_1:
	beq	__mark_no_selector_1

__mark_selector_node_1:
	cmp	r4,#-2
	beq	__mark_indirection_node

	cmp	r4,#-3

	str	r0,[sp,#-4]!
	ldr	r4,[r2]
	str	r1,[sp,#-4]!

	ble	__mark_record_selector_node_1

	sub	r1,r4,r8
	lsr	r0,r1,#7
	and	r1,r1,#31*4
	lsr	r1,r1,#2
	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r6,r0,lsl #2]
	tst	r1,r7
	ldr	r1,[sp],#4
	bne	__mark_no_selector_2

	ldr	r0,[r4]
	tst	r0,#2
	beq	__mark_no_selector_2

	ldrh	r7,[r0,#-2]
	cmp	r7,#2
	bls	__small_tuple_or_record

__large_tuple_or_record:	
	ldr	r4,[r4,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	__mark_no_selector_2

.ifdef PIC
	ldr	r7,[r1,#-1-8]
	add	r1,r1,#-8+4
.else
	ldr	r1,[r1,#-1-8]
.endif
	lao	r4,e__system__nind,14
	ldr	r3,[r2]
	otoa	r4,e__system__nind,14
	str	r4,[r2,#-4]
	mov	r4,r2

	ldr	r0,[sp],#4

.ifdef PIC
	ldrh	r1,[r1,r7]
.else
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	blt	__mark_tuple_selector_node_1
	ldr	r3,[r3,#8]
	beq	__mark_tuple_selector_node_2
	sub	r1,r1,#12
	ldr	r2,[r3,r1]
	str	r2,[r4]
	b	__mark_node

__mark_tuple_selector_node_2:
	ldr	r2,[r3]
	str	r2,[r4]
	b	__mark_node

__small_tuple_or_record:
.ifdef PIC
	ldr	r7,[r1,#-1-8]
	add	r1,r1,#-8+4
.else
	ldr	r1,[r1,#-1-8]
.endif
	lao	r4,e__system__nind,15
	ldr	r3,[r2]
	otoa	r4,e__system__nind,15
	str	r4,[r2,#-4]
	mov	r4,r2

	ldr	r0,[sp],#4

.ifdef PIC
	ldrh	r1,[r1,r7]
.else
	ldrh	r1,[r1,#4]
.endif
__mark_tuple_selector_node_1:
	ldr	r2,[r3,r1]
	str	r2,[r4]
	b	__mark_node

__mark_record_selector_node_1:
	beq	__mark_strict_record_selector_node_1

	sub	r1,r4,r8
	lsr	r0,r1,#7
	and	r1,r1,#31*4
	lsr	r1,r1,#2
	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r6,r0,lsl #2]
	tst	r1,r7
	ldr	r1,[sp],#4
	bne	__mark_no_selector_2

	ldr	r0,[r4]
	tst	r0,#2
	beq	__mark_no_selector_2

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	bls	__small_record

	ldr	r4,[r4,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	__mark_no_selector_2

__small_record:
.ifdef PIC
	ldr	r7,[r1,#-1-8]
	add	r1,r1,#-8+4
.else
	ldr	r1,[r1,#-1-8]
.endif
	lao	r4,e__system__nind,16
	ldr	r3,[r2]
	otoa	r4,e__system__nind,16
	str	r4,[r2,#-4]
	mov	r4,r2

	ldr	r0,[sp],#4

.ifdef PIC
	ldrh	r1,[r1,r7]
.else
	ldrh	r1,[r1,#4]
.endif
	cmp	r1,#8
	ble	__mark_record_selector_node_2
	ldr	r3,[r3,#8]
	sub	r1,r1,#12
__mark_record_selector_node_2:
	ldr	r2,[r3,r1]

	str	r2,[r4]
	b	__mark_node

__mark_strict_record_selector_node_1:
	sub	r1,r4,r8
	lsr	r0,r1,#7
	and	r1,r1,#31*4
	lsr	r1,r1,#2
	mov	r7,#1
	lsl	r1,r7,r1

	ldr	r7,[r6,r0,lsl #2]
	tst	r1,r7
	ldr	r1,[sp],#4
	bne	__mark_no_selector_2

	ldr	r0,[r4]
	tst	r0,#2
	beq	__mark_no_selector_2

	ldrh	r7,[r0,#-2]
	cmp	r7,#258
	ble	__select_from_small_record

	ldr	r4,[r4,#8]
	sub	r4,r4,r8
	lsr	r0,r4,#7
	and	r4,r4,#31*4
	lsr	r4,r4,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	bne	__mark_no_selector_2

__select_from_small_record:
.ifdef PIC
	ldr	r1,[r1,#-1-8]
	add	r7,r1,#-8+4
.else
	ldr	r1,[r1,#-1-8]
.endif
	ldr	r3,[r2]
	ldr	r0,[sp],#4
	sub	r2,r2,#4

.ifdef PIC
	ldrh	r0,[r1,r7]!
.else
	ldrh	r0,[r1,#4]
.endif
	cmp	r0,#8
	ble	__mark_strict_record_selector_node_2
	ldr	r7,[r3,#8]
	add	r0,r0,r7
	ldr	r0,[r0,#-12]
	b	__mark_strict_record_selector_node_3
__mark_strict_record_selector_node_2:
	ldr	r0,[r3,r0]
__mark_strict_record_selector_node_3:
	str	r0,[r2,#4]

.ifdef PIC
	ldrh	r0,[r1,#6-4]
.else
	ldrh	r0,[r1,#6]
.endif
	tst	r0,r0
	beq	__mark_strict_record_selector_node_5
	cmp	r0,#8
	ble	__mark_strict_record_selector_node_4
	ldr	r3,[r3,#8]
	sub	r0,r0,#12
__mark_strict_record_selector_node_4:
	ldr	r0,[r3,r0]
	str	r0,[r2,#8]
__mark_strict_record_selector_node_5:

.ifdef PIC
	ldr	r1,[r1,#-4-4]
.else
	ldr	r1,[r1,#-4]
.endif
	str	r1,[r2]
	b	__mark_node

__mark_indirection_node:
	ldr	r2,[r2]
	b	__mark_node

__mark_hnf_2:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r3,#0x20000000
	bls	fits__in__word__6
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in__word__6:

__mark_record_2_c:
	ldr	r1,[r2]
	ldr	r4,[r2,#4]
	orr	r1,r1,#2
	str	r5,[r2,#4]
	str	r1,[r2]
	add	r5,r2,#4
	mov	r2,r4

__mark_node:
	sub	r3,r2,r8
	cmp	r3,r9
	bhs	__mark_next_node

	lsr	r0,r3,#7
	and	r3,r3,#31*4
	lsr	r4,r3,#2
	mov	r7,#1
	lsl	r4,r7,r4

	ldr	r7,[r6,r0,lsl #2]
	tst	r4,r7
	beq	__mark_arguments

__mark_next_node:
	tst	r5,#3
	bne	__mark_parent

	ldr	r4,[r5,#-4]
	ldr	r3,[r5]
	str	r2,[r5]
	str	r3,[r5,#-4]
	sub	r5,r5,#4

	mov	r2,r4
	and	r4,r4,#3
	and	r2,r2,#-4
	orr	r5,r5,r4
	b	__mark_node

__mark_parent:
	mov	r0,r5
	bics	r5,r5,#3
	beq	__end_mark_using_reversal

	and	r0,r0,#3
	ldr	r4,[r5]
	str	r2,[r5]

	subs	r0,r0,#1
	beq	__argument_part_parent

	add	r2,r5,#-4
	mov	r5,r4
	b	__mark_next_node

__argument_part_parent:
	and	r4,r4,#-4
	mov	r3,r5
	ldr	r2,[r4,#-4]
	ldr	r0,[r4]
	str	r0,[r4,#-4]
	str	r3,[r4]
	add	r5,r4,#2-4
	b	__mark_node

__mark_lazy_node:
	ldr	r4,[r1,#-1-4]
	tst	r4,r4
	beq	__mark_real_or_file

	add	r2,r2,#4
	cmp	r4,#1
	ble	__mark_lazy_node_1
	cmp	r4,#256
	bge	__mark_closure_with_unboxed_arguments

	add	r4,r4,#1	
	mov	r1,r3
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,r4

	add	r1,r1,r4,lsl #2
	sub	r4,r4,#2

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]

	cmp	r1,#32*4
	bls	fits__in__word__7
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in__word__7:
__mark_closure_with_unboxed_arguments__2:
	add	r3,r2,r4,lsl #2
	ldr	r1,[r2]
	orr	r1,r1,#2
	str	r1,[r2]	
	ldr	r2,[r3]
	str	r5,[r3]
	mov	r5,r3
	b	__mark_node

__mark_closure_with_unboxed_arguments:
	mov	r1,r4
	and	r4,r4,#255

	subs	r4,r4,#1
	beq	__mark_closure_1_with_unboxed_argument
	add	r4,r4,#2

	lsr	r1,r1,#8
	add	r10,r10,r4

	str	r2,[sp,#-4]!
	add	r2,r3,r4,lsl #2

	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	sub	r4,r4,r1

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r2,#32*4
	bls	fits__in_word_7_
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in_word_7_:
	ldr	r2,[sp],#4
	subs	r4,r4,#2
	bgt	__mark_closure_with_unboxed_arguments__2
	beq	__shared_argument_part
	sub	r2,r2,#4
	b	__mark_next_node

__mark_closure_1_with_unboxed_argument:
	sub	r2,r2,#4
	b	__mark_real_or_file

__mark_hnf_0:
	laol	r7,INT+2,INT_o_2,9
	otoa	r7,INT_o_2,9
	cmp	r1,r7
	bne	__no_int_3

	ldr	r4,[r2,#4]
	cmp	r4,#33
	blo	____small_int

__mark_bool_or_small_string:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#2
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r3,#0x40000000
	bls	__mark_next_node
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
	b	__mark_next_node

____small_int:
	lao	r2,small_integers,2
	otoa	r2,small_integers,2
	add	r2,r2,r4,lsl #3
	b	__mark_next_node

__no_int_3:
	blo	__mark_real_file_or_string

	laol	r7,CHAR+2,CHAR_o_2,4
	otoa	r7,CHAR_o_2,4
 	cmp	r1,r7
 	bne	__no_char_3

	ldrb	r4,[r2,#4]
	lao	r2,static_characters,2
	otoa	r2,static_characters,2
	add	r2,r2,r4,lsl #3
	b	__mark_next_node

__no_char_3:
	blo	__mark_bool_or_small_string

	add	r2,r1,#ZERO_ARITY_DESCRIPTOR_OFFSET-2
	b	__mark_next_node

__mark_real_file_or_string:
	laol	r7,__STRING__+2,__STRING___o_2,9
	otoa	r7,__STRING___o_2,9
	cmp	r1,r7
	bls	__mark_string_or_array

__mark_real_or_file:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]

	cmp	r3,#0x20000000
	bls	__mark_next_node

	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
	b	__mark_next_node

__mark__record:
	subs	r4,r4,#258
	beq	__mark_record_2
	blt	__mark_record_1

__mark_record_3:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r3,#0x20000000
	bls	fits__in__word__13
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in__word__13:
	ldrh	r0,[r1,#-2+2]

	ldr	r3,[r2,#4]
	sub	r3,r3,r8
	mov	r1,r3
	and	r3,r3,#31*4
	lsr	r1,r1,#7

	str	r5,[sp,#-4]!

	lsr	r5,r3,#2
	mov	r7,#1
	lsl	r5,r7,r5

	ldr	r7,[r6,r1,lsl #2]
	tst	r5,r7
	bne	__shared_record_argument_part

	add	r4,r4,#1
	ldr	r7,[r6,r1,lsl #2]
	orr	r7,r7,r5
	str	r7,[r6,r1,lsl #2]

	add	r3,r3,r4,lsl #2
	add	r10,r10,r4

	ldr	r5,[sp],#4

	cmp	r3,#32*4
	bls	fits__in__word__14
	add	r7,r6,#4
	ldr	r3,[r7,r1,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r1,lsl #2]
fits__in__word__14:
	subs	r0,r0,#1
	ldr	r3,[r2,#4]
	blt	__mark_record_3_bb
	beq	__shared_argument_part

	str	r5,[r2,#4]
	add	r2,r2,#4

	subs	r0,r0,#1
	beq	__mark_record_3_aab

	add	r5,r3,r0,lsl #2
	ldr	r1,[r3]
	orr	r1,r1,#1
	ldr	r4,[r5]
	str	r1,[r3]
	str	r2,[r5]
	mov	r2,r4
	b	__mark_node

__mark_record_3_bb:
	sub	r2,r2,#4
	b	__mark_next_node

__mark_record_3_aab:
	ldr	r4,[r3]
	str	r2,[r3]
	add	r5,r3,#1
	mov	r2,r4
	b	__mark_node

__shared_record_argument_part:
	ldr	r3,[r2,#4]

	ldr	r5,[sp],#4

	tst	r0,r0
	bne	__shared_argument_part
	sub	r2,r2,#4
	b	__mark_next_node

__mark_record_2:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,#3
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	cmp	r3,#0x20000000
	bls	fits__in__word_12
	add	r7,r6,#4
	ldr	r3,[r7,r0,lsl #2]
	orr	r3,r3,#1
	str	r3,[r7,r0,lsl #2]
fits__in__word_12:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#1
	bhi	__mark_record_2_c
	beq	__shared_argument_part
	sub	r2,r2,#4
	b	__mark_next_node

__mark_record_1:
	ldrh	r7,[r1,#-2+2]
	cmp	r7,#0
	bne	__mark_hnf_1
	sub	r2,r2,#4
	b	__mark_bool_or_small_string

__mark_string_or_array:
	beq	__mark_string_

__mark_array:
	ldr	r4,[r2,#8]
	cmp	r4,#0
	beq	__mark_lazy_array

	ldrh	r1,[r4,#-2]
	cmp	r1,#0
	beq	__mark_strict_basic_array

	ldrh	r4,[r4,#-2+2]
	tst	r4,r4
	beq	__mark_b_record_array

	sub	r1,r1,#256
	cmp	r1,r4
	beq	__mark_a_record_array

__mark__ab__record__array:
	str	r3,[sp,#-4]!
	str	r0,[sp,#-4]!
	mov	r0,r4

	ldr	r4,[r2,#4]
	add	r2,r2,#8
	str	r2,[sp,#-4]!

	lsl	r4,r4,#2
	mov	r3,r1
	mul	r3,r4,r3

	sub	r1,r1,r0
	add	r2,r2,#4
	add	r3,r3,r2

	adr	r14,1+0f
	push	{r14}
	bl	reorder
0:
	ldr	r2,[sp],#4

	mov	r7,r1
	mov	r1,r0
	mov	r0,r7
	ldr	r4,[r2,#-4]
	mul	r1,r4,r1
	mul	r0,r4,r0
	add	r10,r10,r0
	add	r0,r0,r1

	lsl	r0,r0,#2
	sub	r4,r2,r8
	add	r4,r4,r0

	ldr	r0,[sp],#4
	ldr	r3,[sp],#4

	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]

	add	r3,r2,r1,lsl #2
	b	__mark_r_array

__mark_a_record_array:
	ldr	r7,[r2,#4]
	mul	r1,r7,r1
	add	r2,r2,#8	
	b	__mark_lr_array

__mark_lazy_array:
	ldr	r1,[r2,#4]
	add	r2,r2,#8

__mark_lr_array:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	add	r3,r2,r1,lsl #2
	sub	r4,r3,r8
__mark_r_array:
	lsr	r4,r4,#7

	cmp	r0,r4
	bhs	__skip_mark_lazy_array_bits

	add	r0,r0,#1

__mark_lazy_array_bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,#1
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r4
	bls	__mark_lazy_array_bits

__skip_mark_lazy_array_bits:
	add	r10,r10,#3
	add	r10,r10,r1

	cmp	r1,#1
	bls	__mark_array_length_0_1

	ldr	r4,[r3]
	ldr	r0,[r2]
	str	r0,[r3]
	str	r4,[r2]

	ldr	r4,[r3,#-4]
	sub	r3,r3,#4
	lao	r7,lazy_array_list,2
	ldo	r0,r7,lazy_array_list,2
	add	r4,r4,#2
	str	r0,[r3]
	str	r4,[r2,#-4]
	str	r1,[r2,#-8]!
	lao	r7,lazy_array_list,3
	sto	r2,r7,lazy_array_list,3

	ldr	r2,[r3,#-4]
	str	r5,[r3,#-4]
	add	r5,r3,#-4
	b	__mark_node

__mark_array_length_0_1:
	add	r2,r2,#-8
	blo	__mark_next_node

	ldr	r0,[r2,#12]
	ldr	r4,[r2,#8]
	lao	r7,lazy_array_list,4
	ldo	r3,r7,lazy_array_list,4
	str	r4,[r2,#12]	
	str	r3,[r2,#8]
	str	r1,[r2]
	lao	r7,lazy_array_list,5	
	sto	r2,r7,lazy_array_list,5
	str	r0,[r2,#4]
	add	r2,r2,#4

	ldr	r4,[r2]
	str	r5,[r2]
	add	r5,r2,#2
	mov	r2,r4
	b	__mark_node

__mark_b_record_array:
	ldr	r4,[r2,#4]
	sub	r1,r1,#256
	mul	r1,r4,r1
	add	r1,r1,#3
	b	__mark_basic_array

__mark_strict_basic_array:
	ldr	r1,[r2,#4]
	laol	r7,INT+2,INT_o_2,10
	otoa	r7,INT_o_2,10
	cmp	r4,r7
	beq	__mark__strict__int__array
	laol	r7,BOOL+2,BOOL_o_2,6
	otoa	r7,BOOL_o_2,6
	cmp	r4,r7
	beq	__mark__strict__bool__array
__mark__strict__real__array:
	add	r1,r1,r1
__mark__strict__int__array:
	add	r1,r1,#3
	b	__mark_basic_array
__mark__strict__bool__array:
	add	r1,r1,#12+3
	lsr	r1,r1,#2
	b	__mark_basic_array

__mark_string_:
	ldr	r1,[r2,#4]
	add	r1,r1,#8+3
	lsr	r1,r1,#2

__mark_basic_array:
	lsr	r3,r3,#2
	mov	r7,#1
	lsl	r3,r7,r3
	add	r10,r10,r1

	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r3
	str	r7,[r6,r0,lsl #2]
	add	r7,r2,#-4
	add	r1,r7,r1,lsl #2

	sub	r1,r1,r8
	lsr	r1,r1,#7

	cmp	r0,r1
	bhs	__mark_next_node

	add	r0,r0,#1
	mov	r4,#1

	cmp	r0,r1
	bhs	__last__string__bits

__mark_string_lp:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	add	r0,r0,#1
	cmp	r0,r1
	blo	__mark_string_lp

__last__string__bits:
	ldr	r7,[r6,r0,lsl #2]
	orr	r7,r7,r4
	str	r7,[r6,r0,lsl #2]
	b	__mark_next_node

.ifdef PIC
	lto	e__system__nind,14
	lto	e__system__nind,15
	lto	e__system__nind,16
	lto	small_integers,2
	lto	static_characters,2
	lto	lazy_array_list,2
	lto	lazy_array_list,3
	lto	lazy_array_list,4
	lto	lazy_array_list,5
.endif

.ifdef PIC
	ltol	INT+2,INT_o_2,9
	ltol	CHAR+2,CHAR_o_2,4
	ltol	__STRING__+2,__STRING___o_2,9
	ltol	INT+2,INT_o_2,10
	ltol	BOOL+2,BOOL_o_2,6
.endif
	.ltorg
