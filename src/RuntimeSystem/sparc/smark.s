
	ldg	(heap_size_33,d0)

_fill_ones:	btst	3,d0
	beq	_end_fill_ones
	mov	-1,%o1

	stb	%o1,[%o4+d0]
	ba	_fill_ones
	inc	1,d0
_end_fill_ones:

	clr	d4
	ldg	(heap_size_33,d7)
	stg	(d4,lazy_array_list)
	sethi	%hi 0x80000000,%g3
	
	sub	sp,4000,a3
	sll	d7,5,d7

	ldg	(caf_list,d0)
	
	st	a4,[sp-4]
	
	tst	d0
	be	_end_mark_cafs
	dec	4,sp

	dec	4,sp

_mark_cafs_lp:
	ld	[d0-4],%g1
	add	d0,4,a2
	ld	[d0],d0
	st	%g1,[sp]
	sll	d0,2,d0
	add	a2,d0,a4

	dec	4,sp
	call	_mark_stack_nodes
	st	%o7,[sp]

	ld	[sp],d0
	addcc	d0,0,d0
	bne	_mark_cafs_lp
	nop

	inc	4,sp

_end_mark_cafs:
	ldg	(stack_p,a2)

	ld	[sp],a4
	call	_mark_stack_nodes
	st	%o7,[sp]

	ldg	(lazy_array_list,a0)

	tst	a0
	beq	end_restore_arrays
	nop

restore_arrays:
	ld	[a0],d3		! size
	ld	[a0+4],d1	! second last element

	set	__ARRAY__+2,%o0
	ld	[a0+8],d2	! last element

	cmp	d3,1
	beq	restore_array_size_1
	st	%o0,[a0]

	sll	d3,2,a1
	add	a0,a1,a1
	
	ld	[a1+8],d0	! descriptor

	tst	d0
	beq	restore_lazy_array
	nop

	lduh	[d0-2+2],%o0
	udiv	d3,%o0,d3

restore_lazy_array:
	st	d3,[a0+4]
	ld	[a1+4],a3	! next
	st	d0,[a0+8]

	st	d1,[a1+4]

	tst	d0
	beq	no_reorder_array
	st	d2,[a1+8]

	lduh	[d0-2],%o1
	dec	256,%o1
	cmp	%o1,%o0
	beq	no_reorder_array
	nop
	
	mov	%o1,d0
	mov	%o0,d1
	sll	d3,2,d3
	umul	d3,d0,d3
	inc	12,a0
	add	a0,d3,a1
	sub	d0,d1,d0

	call	reorder	
	mov	d4,%g1

	mov	%g1,d4

no_reorder_array:
	addcc	a3,0,a0
	bne	restore_arrays
	nop

	b,a	end_restore_arrays

restore_array_size_1:
	st	d3,[a0+4]
	ld	[a0+12],a3	! descriptor
	
	st	d1,[a0+12]
	st	a3,[a0+8]

	addcc	d2,0,a0
	bne	restore_arrays
	nop

end_restore_arrays:

#ifdef FINALIZERS
	set	finalizer_list,a0
	set	free_finalizer_list,a1

	ld	[a0],a2
determine_free_finalizers_after_mark:
	set	__Nil-8,%o0
	cmp	%o0,a2
	beq	end_finalizers_after_mark
	sub	a2,d6,d1

	srl	d1,2,d1

	srl	d1,3,%o0
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	beq	finalizer_not_used_after_mark
	nop

	add	a2,4,a0
	ba	determine_free_finalizers_after_mark
	ld	[a2+4],a2

finalizer_not_used_after_mark:
	st	a2,[a1]
	add	a2,4,a1

	ld	[a2+4],a2
	ba	determine_free_finalizers_after_mark
	st	a2,[a0]

end_finalizers_after_mark:
	st	a2,[a1]
#endif

	dec	4,sp
	call	add_garbage_collect_time
	st	%o7,[sp]

	ldg	(heap_size_33,d5)
	inc	3,d5
	srl	d5,2,d5
	
	stg	(d5,bit_counter)
	stg	(%o4,bit_vector_p)

	sll	d4,2,d4

	ldg	(heap_size_33,d0)
	sll	d0,5,d0
	sub	d0,d4,d0

	stg	(d0,last_heap_free)

#ifdef COUNT_GARBAGE_COLLECTIONS
	sethi	%hi n_garbage_collections,%o1
	ld	[%o1+%lo n_garbage_collections],%o2
	inc	1,%o2
#endif
	ldg	(@flags,%o0)
	btst	2,%o0
	beq	_no_heap_use_message2
#ifdef COUNT_GARBAGE_COLLECTIONS
	st	%o2,[%o1+%lo n_garbage_collections]
#else
	nop
#endif

	st	%o4,[sp-4]

	seth	(marked_gc_string_1,%o0)
	call	@ew_print_string
	setl	(marked_gc_string_1,%o0)

	call	@ew_print_int
	mov	d4,%o0

	seth	(heap_use_after_gc_string_2,%o0)
	call	@ew_print_string
	setl	(heap_use_after_gc_string_2,%o0)

	ld	[sp-4],%o4

_no_heap_use_message2:
#ifdef FINALIZERS
	call	call_finalizers
	nop
	ldg	(heap_vector,%o4)
#endif

	ldg	(alloc_size,d2)
	mov	d5,d0
	mov	%o4,a0

	stg	(%g0,free_after_mark)

_scan_bits:
	ld	[a0],%o0	!
	inc	4,a0
	tst	%o0
	beq	_zero_bits
	deccc	d0
	clr	[a0-4]
	bne,a	_scan_bits+4
	ld	[a0],%o0

	b,a	_end_scan

_zero_bits:
	beq	_end_bits
	mov	a0,a1

_skip_zero_bits_lp:
	ld	[a0],d1
	inc	4,a0
	tst	d1
	bne	_end_zero_bits
	deccc	d0
	bne,a	_skip_zero_bits_lp+4
	ld	[a0],d1

	ba	_end_bits+4
	sub	a0,a1,d1	

_end_zero_bits:
	clr	[a0-4]

	sub	a0,a1,d1
	sll	d1,3,d1

	seth	(free_after_mark,%o0)
	ld	[%o0+%lo free_after_mark],%o1
	cmp	d1,d2
	add	%o1,d1,%o1
	blu	_scan_next
	st	%o1,[%o0+%lo free_after_mark]

_found_free_memory:
	stg	(d0,bit_counter)
	stg	(a0,bit_vector_p)

	sub	d1,d2,d7

	ldg	(heap_vector,%o1)
	sub	a1,4,d0
	sub	d0,%o1,d0
	ldg	(heap_p3,%o1)
	sll	d0,5,d0
	add	d0,%o1,d0
	mov	d0,a6

	sll	d1,2,d1
	add	d0,d1,d0
	stg	(d0,heap_end_after_gc)

	ld	[sp],d0
	ld	[sp+4],d1
	ld	[sp+8],d2
	ld	[sp+12],d3
	ld	[sp+16],d4
	ld	[sp+20],d5
	ld	[sp+24],d6

	ld	[sp+28],%o7
	retl
	inc	32,sp

_scan_next:
	tst	d0
	bne,a	_scan_bits+4
	ld	[a0],%o0

	b,a	_end_scan

_end_bits:
	sub	a0,a1,d1	!
	inc	4,d1
	sll	d1,3,d1

	seth	(free_after_mark,%o0)
	ld	[%o0+%lo free_after_mark],%o1
	cmp	d1,d2
	add	%o1,d1,%o1
	bgeu	_found_free_memory
	st	%o1,[%o0+%lo free_after_mark]

_end_scan:
	stg	(d0,bit_counter)
	b,a	compact_gc


_mark_stack_nodes:
	cmp	a2,a4
	be	_end_mark_nodes
	inc	4,a2

	ld	[a2-4],a0

	sub	a0,d6,d1
#ifdef SHARE_CHAR_INT
	cmp	d1,d7
	bcc	_mark_stack_nodes
#endif
	srl	d1,5,%o0
	srl	d1,2,d1
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	bne	_mark_stack_nodes
	nop

#if 0
	add	a2,-4,%o0
	mov	0,d3
	mov	1,d5
	st	%o0,[sp-4]
	call	__mark__node
	dec	4,sp

_mark_next_node:
	b,a	_mark_stack_nodes
#else
	clr	[sp-4]
	ba	_mark_arguments
	dec	4,sp

_mark_hnf_2:
	cmp	%o3,4
	bgeu	fits_in_word_6
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_6:
	st	%o1,[%o4+%o0]
	inc	3,d4

_mark_record_2_c:
	ld	[a0+4],%o0
	dec	4,sp
	cmp	sp,a3
	blu	__mark_using_reversal
	st	%o0,[sp]
	
	ld	[a0],a0

_mark_node:
	sub	a0,d6,d1
	cmp	d1,d7
	bcc	_mark_next_node
	srl	d1,2,d1

	srl	d1,3,%o0
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	bne	_mark_next_node
	nop

_mark_arguments:
	ld	[a0],d0
	btst	2,d0
	be	_mark_lazy_node
	ldsh	[d0-2],d2

	tst	d2
	be	_mark_hnf_0
	cmp	d2,256
	bgeu	_mark_record
	inc	4,a0

	deccc	2,d2
	be	_mark_hnf_2
	nop
	bcs	_mark_hnf_1
	nop

_mark_hnf_3:
	cmp	%o3,4
	bgeu	fits_in_word_1
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_1:
	st	%o1,[%o4+%o0]

	ld	[a0+4],a1
	
	sub	a1,d6,d0
	srl	d0,5,%o0
	srl	d0,2,d0
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d0,%o3

	btst	%o3,%o1
	bne	_shared_argument_part
	inc	3,d4

_no_shared_argument_part:
	sll	d2,2,%o2
	inc	1,d2

	add	a1,%o2,a1
	and	d0,31,%o2

	add	%o2,d2,%o2
	add	d4,d2,d4

	cmp	%o2,32
	bleu	fits_in_word_2
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_2:
	st	%o1,[%o4+%o0]

	ld	[a1],%o0
	dec	2,d2
	st	%o0,[sp-4]
	dec	4,sp

_push_hnf_args:
	ld	[a1-4],%o0
	dec	4,a1
	st	%o0,[sp-4]
	deccc	d2
	bcc	_push_hnf_args
	dec	4,sp

	cmp	sp,a3
	bgeu,a	_mark_node
	ld	[a0],a0
	
	b,a	__mark_using_reversal

_mark_hnf_1:
	cmp	%o3,2
	bgeu	fits_in_word_4
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_4:
	st	%o1,[%o4+%o0]
	inc	2,d4

_shared_argument_part:
	ba	_mark_node
	ld	[a0],a0

_mark_lazy_node_1:
	cmp	%o3,4
	bgeu	fits_in_word_3
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_3:
	st	%o1,[%o4+%o0]

	cmp	d2,1
	bne	_mark_selector_node_1
	inc	3,d4

	ba	_mark_node
	ld	[a0],a0

_mark_selector_node_1:
	inccc	2,d2
	beq 	_mark_indirection_node
	ld	[a0],a1

	sub	a1,d6,d1
	srl	d1,5,%o0

	inccc	1,d2
	ble	_mark_record_selector_node_1
	srl	d1,2,d1

	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	bne,a	_mark_node
	mov	a1,a0

	ld	[a1],d2
	btst	2,d2
	be,a	_mark_node
	mov	a1,a0

	ldsh	[d2-2],%g1
	cmp	%g1,2
	bleu	_small_tuple_or_record
	nop
	
_large_tuple_or_record:
	ld	[a1+8],d1
	sub	d1,d6,%o0
	srl	%o0,5,%g1
	srl	%o0,2,%o0

	andn	%g1,3,%g1
	ld	[%o4+%g1],%g1
	srl	%g3,%o0,%o3

	btst	%o3,%g1
	bne,a	_mark_node
	mov	a1,a0

#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]
	sub	a0,4,d2
	lduh	[d0+4],d0
	cmp	d0,8
	bltu,a	_mark_tuple_selector_node_1
	ld	[a1+d0],a0

	beq	_mark_tuple_selector_node_2
	mov	d1,a1

	sub	d0,12,d0
	ld	[a1+d0],a0
	ba	_mark_node
	st	a0,[d2+4]

_mark_tuple_selector_node_2:
	ld	[a1],a0
	ba	_mark_node
	st	a0,[d2+4]
#endif

_small_tuple_or_record:
#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]
	sub	a0,4,d2
	lduh	[d0+4],d0
	ld	[a1+d0],a0
_mark_tuple_selector_node_1:
	ba	_mark_node
	st	a0,[d2+4]
#else
	sub	a0,4,d2

	ld	[d0-8],%g1
	mov	a1,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	set	__indirection,%g1
	st	%g1,[d2]
	ba	_mark_node
	st	a0,[d2+4]
#endif

_mark_record_selector_node_1:
	beq	_mark_strict_record_selector_node_1
	andn	%o0,3,%o0

	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	bne,a	_mark_node
	mov	a1,a0

	ld	[a1],d2
	btst	2,d2
	be,a	_mark_node
	mov	a1,a0

	ldsh	[d2-2],%g1
	cmp	%g1,258
	bleu	_small_tuple_or_record
	nop

#ifdef NEW_DESCRIPTORS
	ld	[a1+8],d1

	sub	d1,d6,%o0
	srl	%o0,5,%g1
	srl	%o0,2,%o0

	andn	%g1,3,%g1
	ld	[%o4+%g1],%g1
	srl	%g3,%o0,%o3

	btst	%o3,%g1
	bne,a	_mark_node
	mov	a1,a0

	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]
	mov	a0,d2
	lduh	[d0+4],d0
	cmp	d0,8
	bleu	_mark_record_selector_node_2
	nop
	
	mov	d1,a1
	sub	d0,12,d0
_mark_record_selector_node_2:
	ld	[a1+d0],a0
	ba	_mark_node
	st	a0,[d2]
#else
	b,a	_large_tuple_or_record
#endif

_mark_strict_record_selector_node_1:
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	bne,a	_mark_node
	mov	a1,a0

	ld	[a1],d2
	btst	2,d2
	be,a	_mark_node
	mov	a1,a0

	ldsh	[d2-2],%g1
	cmp	%g1,258
	bleu	_select_from_small_record
	nop
	
	ld	[a1+8],d1
	sub	d1,d6,d1
	srl	d1,5,%o0
	srl	d1,2,d1

	andn	%o0,3,%o0
	ld	[%o4+%o0],%g1
	srl	%g3,d1,%o3

	btst	%o3,%g1
	bne,a	_mark_node
	mov	a1,a0

_select_from_small_record:
#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	dec	4,a0
	lduh	[d0+4],%g1
	cmp	%g1,8
	bleu,a	_mark_strict_record_selector_node_2
	ld	[a1+%g1],%g1

	dec	12,%g1
	ld	[d1+%g1],%g1

_mark_strict_record_selector_node_2:
	st	%g1,[a0+4]
	
	lduh	[d0+6],%g1
	tst	%g1
	beq	_mark_strict_record_selector_node_5
	ld	[d0-4],d0

	cmp	%g1,8
	bleu,a	_mark_strict_record_selector_node_4
	ld	[a1+%g1],%g1

	dec	12,%g1
	ld	[d1+%g1],%g1
_mark_strict_record_selector_node_4:
	st	%g1,[a0+8]
_mark_strict_record_selector_node_5:
	ba	_mark_next_node
	st	d0,[a0]
#else
	ld	[d0-8],%g1
	dec	4,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	b,a	_mark_next_node
#endif

_mark_indirection_node:
	ba	_mark_node
	mov	a1,a0

_mark_next_node:
	ld	[sp],a0
	inc	4,sp
	tst	a0
	bne	_mark_node
	nop
	b,a	_mark_stack_nodes

_mark_lazy_node:
	tst	d2
	be	_mark_real_or_file
	add	d0,-2,a1

	cmp	d2,1
	ble,a	_mark_lazy_node_1
	inc	4,a0
	
	cmp	d2,256
	bge	_mark_closure_with_unboxed_arguments
	nop

	inc	1,d2
	and	d1,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2

	cmp	%o2,32
	bleu	fits_in_word_7
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_7:
	st	%o1,[%o4+%o0]

	sll	d2,2,%g2
	add	a0,%g2,a0

	dec	3,d2
_push_lazy_args:
	ld	[a0-4],%o0
	dec	4,a0
	st	%o0,[sp-4]
	deccc	d2
	bcc	_push_lazy_args
	dec	4,sp

	cmp	sp,a3
	bgeu,a	_mark_node
	ld	[a0-4],a0
	
	ba	__mark_using_reversal
	dec	4,a0

_mark_closure_with_unboxed_arguments:
	srl	d2,8,%g2
	and	d2,255,d2
	deccc	1,d2
	beq	_mark_real_or_file
	inc	2,d2

	and	d1,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2

	cmp	%o2,32
	bleu	fits_in_word_7_
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_7_:
	st	%o1,[%o4+%o0]

	sub	d2,%g2,d2
	sll	d2,2,%g2
	deccc	2,d2
	blt	_mark_next_node
	nop
	
	bne	_push_lazy_args
	add	a0,%g2,a0

_mark_closure_with_one_boxed_argument:
	ba	_mark_node
	ld	[a0-4],a0

_mark_hnf_0:
	set	INT+2,%g1
	cmp	d0,%g1
	blu	_mark_real_file_or_string
	seth	(CHAR+2,%g1)

	setl	(CHAR+2,%g1)
	cmp	d0,%g1
	bgu	_mark_normal_hnf_0
	nop

_mark_bool_or_small_string:
	cmp	%o3,2
	bgeu	fits_in_word_8
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_8:
	st	%o1,[%o4+%o0]
	ba	_mark_next_node
	inc	2,d4

_mark_normal_hnf_0:
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	ba	_mark_next_node
	inc	1,d4

_mark_real_file_or_string:
	set	__STRING__+2,%g1
	cmp	d0,%g1
	bleu	_mark_string_or_array
	nop

_mark_real_or_file:
	cmp	%o3,4
	bgeu	fits_in_word_9
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_9:
	st	%o1,[%o4+%o0]
	ba	_mark_next_node
	inc	3,d4

_mark_record:
	deccc	258,d2
	be,a	_mark_record_2
	lduh	[d0-2+2],%g1

	blu,a	_mark_record_1
	lduh	[d0-2+2],%g1

_mark_record_3:
	cmp	%o3,4
	lduh	[d0-2+2],d1
	bgeu	fits_in_word_13
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_13:
	st	%o1,[%o4+%o0]

	ld	[a0+4],a1
	inc	3,d4

	sub	a1,d6,d0
	srl	d0,5,%o0
	srl	d0,2,d0
	andn	%o0,3,%o0

	deccc	1,d1
	ld	[%o4+%o0],%o1
	blu	_mark_record_3_bb
	srl	%g3,d0,%o3

	btst	%o3,%o1
	bne,a	_mark_node
	ld	[a0],a0

	inc	1,d2
	and	d0,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2

	bset	%o3,%o1
	cmp	%o2,32
	bleu	_push_record_arguments
	st	%o1,[%o4+%o0]

	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	st	%o1,[%o4+%o0]

_push_record_arguments:
	subcc	d1,1,d2

	sll	d1,2,d1
	bgeu	_push_hnf_args
	add	a1,d1,a1

	ba	_mark_node
	ld	[a0],a0

_mark_record_3_bb:
	btst	%o3,%o1
	bne	_mark_next_node
	inc	1,d2

	and	d0,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2

	bset	%o3,%o1
	cmp	%o2,32
	bleu	_mark_next_node
	st	%o1,[%o4+%o0]

	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	ba	_mark_next_node
	st	%o1,[%o4+%o0]

_mark_record_2:
	cmp	%o3,4
	bgeu	fits_in_word_12
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits_in_word_12:
	st	%o1,[%o4+%o0]

	cmp	%g1,1
	bgu	_mark_record_2_c
	inc	3,d4

	be,a	_mark_node
	ld	[a0],a0

	b,a	_mark_next_node

_mark_record_1:
	tst	%g1
	bne	_mark_hnf_1
	nop
	b,a	_mark_bool_or_small_string

_mark_string_or_array:
	beq,a	_mark_string
	ld	[a0+4],d0

_mark_array:
	ld	[a0+8],d1
	tst	d1
	be	_mark_lazy_array
	nop

	lduh	[d1-2],d0
	tst	d0
	be	_mark_strict_basic_array
	nop

	lduh	[d1-2+2],d1
	tst	d1
	be	_mark_b_record_array
	nop
	cmp	sp,a3
	blu	__mark_array_using_reversal
	nop

	ld	[a0+4],d2
	sub	d0,256,d3
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	umul	d2,d3,d0

	cmp	d1,d3
	beq	_mark_lazy_or_a_record_array
	inc	d4

_mark_ab_record_array:
	inc	3-1,d0
	add	d4,d0,d4

	sll	d0,2,d0
	add	a0,d0,d0
	
	sub	d0,d6,d0
	srl	d0,5,d0
	andn	d0,3,d0
	cmp	%o0,d0
	bgeu	_end_set_ab_array_bits
	nop
	
	inc	4,%o0
	cmp	%o0,d0
	bgeu	_last_ab_array_bits
	nop

_mark_ab_array_lp:
	st	%g3,[%o4+%o0]
	inc	4,%o0
	cmp	%o0,d0
	bltu,a	_mark_ab_array_lp+4
	st	%g3,[%o4+%o0]

_last_ab_array_bits:
	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	st	%o1,[%o4+%o0]
	
_end_set_ab_array_bits:
	st	a2,[sp-8]
	st	a4,[sp-4]

	sll	d3,2,d3
	add	a0,12,a2

	st	d3,[sp-20]
	sll	d1,2,d1
	st	d1,[sp-16]
	dec	28,sp
	
	cmp	d2,0
	beq	_mark_ab_array_0
	nop

_mark_ab_array:
	ld	[sp+12],d1
	st	d2,[sp+4]
	st	a2,[sp]
	
	add	a2,d1,a4

	dec	4,sp
	call	_mark_stack_nodes
	st	%o7,[sp]

	ld	[sp+4],d2
	ld	[sp],a2
	ld	[sp+8],d3

	deccc	d2
	bne	_mark_ab_array
	add	a2,d3,a2

_mark_ab_array_0:
	inc	28,sp
	ld	[sp-8],a2
	ba	_mark_next_node
	ld	[sp-4],a4

_mark_lazy_array:
	cmp	sp,a3
	blu	__mark_array_using_reversal
	nop

	ld	[a0+4],d0
	bset	%o3,%o1
	inc	d4
	st	%o1,[%o4+%o0]

_mark_lazy_or_a_record_array:
	mov	d0,d2

	inc	3-1,d0
	st	a2,[sp-8]
	add	a0,12,a2

	add	d4,d0,d4
	sll	d0,2,d0
	add	a0,d0,d0
	
	sub	d0,d6,d0
	srl	d0,5,d0
	andn	d0,3,d0

	cmp	%o0,d0
	bgeu	_end_set_lazy_array_bits
	sll	d2,2,d2
	
	inc	4,%o0
	cmp	%o0,d0
	bgeu	_last_lazy_array_bits
	nop

_mark_lazy_array_lp:
	st	%g3,[%o4+%o0]
	inc	4,%o0
	cmp	%o0,d0
	bltu,a	_mark_lazy_array_lp+4
	st	%g3,[%o4+%o0]

_last_lazy_array_bits:
	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	st	%o1,[%o4+%o0]
	
_end_set_lazy_array_bits:
	st	a4,[sp-4]
	st	d1,[sp-12]
	add	a2,d2,a4

	dec	16,sp
	call	_mark_stack_nodes
	st	%o7,[sp]

	ld	[sp],d1
	inc	12,sp
	ld	[sp-8],a2
	ba	_mark_next_node
	ld	[sp-4],a4

__mark_array_using_reversal:
	mov	0,d3
	st	d3,[sp-4]
	mov	1,d5
	b	__mark__node
	dec	4,sp

_mark_strict_basic_array:
	ld	[a0+4],d0
	set	INT+2,%g1
	cmp	d1,%g1
	beq,a	_mark_basic_array_
	inc	3,d0
	set	BOOL+2,%g1
	cmp	d1,%g1
	beq,a	_mark_strict_bool_array
	inc	12+3,d0
_mark_strict_real_array:
	add	d0,d0,d0
	ba	_mark_basic_array_
	inc	3,d0
_mark_strict_bool_array:
	ba	_mark_basic_array_
	srl	d0,2,d0

_mark_b_record_array:
	ld	[a0+4],d1
	dec	256,d0
	umul	d1,d0,d0

	ba	_mark_basic_array_
	inc	3,d0

_mark_string:
	inc	8+3,d0
	srl	d0,2,d0

_mark_basic_array_:
	bset	%o3,%o1
	st	%o1,[%o4+%o0]
	add	d4,d0,d4

	sll	d0,2,d0
	add	a0,d0,a0
	dec	4,a0
	sub	a0,d6,d0
	srl	d0,5,d0
	andn	d0,3,d0
	
	cmp	%o0,d0
	bge	_mark_next_node
	inc	4,%o0

	cmp	%o0,d0
	bge	_last_string_bits
	nop
	
_mark_string_lp:
	st	%g3,[%o4+%o0]
	inc	4,%o0
	cmp	%o0,d0
	bltu,a	_mark_string_lp+4
	st	%g3,[%o4+%o0]

_last_string_bits:
	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	ba	_mark_next_node
	st	%o1,[%o4+%o0]
#endif

_end_mark_nodes:
	ld	[sp],%o7
	retl
	inc	4,sp

__end__mark__using__reversal:
	ld	[sp],a1
	tst	a1
	beq	_mark_next_node
	inc	4,sp
	ba	_mark_next_node
	st	a0,[a1]	

__end__mark__using__reversal__after__static:
	ld	[sp],a1
	st	a0,[a1]
	ba	_mark_next_node
	inc	4,sp

__mark_using_reversal:
	st	a0,[sp-4]
	mov	0,d3
	ld	[a0],a0
	mov	1,d5
	ba	__mark__node
	dec	4,sp

__mark__arguments:
	ld	[a0],d0
	btst	2,d0
	be	__mark__lazy__node
	ldsh	[d0-2],d2

	tst	d2
	be	__mark__hnf__0
	cmp	d2,256
	bgeu	__mark__record
	inc	4,a0

	deccc	2,d2
	be	__mark__hnf__2
	nop
	bcs	__mark__hnf__1
	nop

__mark__hnf__3:
	cmp	%o3,4
	bset	%o3,%o1
	bgeu	fits__in__word__1
	ld	[a0+4],a1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__1:
	st	%o1,[%o4+%o0]
	
	sub	a1,d6,d0
	srl	d0,5,%o0
	srl	d0,2,d0
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d0,%o3

	btst	%o3,%o1
	bne	__shared__argument__part
	inc	3,d4

__no__shared__argument__part:
	bset	d5,d3
	st	d3,[a0+4]
	inc	4,a0

	ld	[a1],%g1
	sll	d2,2,d1
	inc	1,d2

	bset	1,%g1
	add	d4,d2,d4

	and	d0,31,%o2
	st	%g1,[a1]
	add	%o2,d2,%o2
	add	a1,d1,a1

	cmp	%o2,32
	bleu	fits__in__word__2
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__2:
	st	%o1,[%o4+%o0]

	ld	[a1],d2
	clr	d5
	st	a0,[a1]
	mov	a1,d3
	ba	__mark__node
	mov	d2,a0

__mark__lazy__node__1:
	bne	__mark__selector__node__1
	nop

__mark__selector__1:
	cmp	%o3,4
	bgeu	fits__in__word__3
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__3:
	st	%o1,[%o4+%o0]
	ba	__shared__argument__part
	inc	3,d4

__mark__hnf__1:
	cmp	%o3,2
	bgeu	fits__in__word__4
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__4:
	st	%o1,[%o4+%o0]
	inc	2,d4

__shared__argument__part:
	ld	[a0],d2
	bset	d5,d3
	st	d3,[a0]
	mov	a0,d3
	mov	2,d5
	ba	__mark__node
	mov	d2,a0

__mark__selector__node__1:
	inccc	2,d2
	beq	__mark__indirection__node
	ld	[a0],a1

	inccc	1,d2

	sub	a1,d6,%o2
	srl	%o2,5,d2
	srl	%o2,2,%o2
	andn	d2,3,d2
	ld	[%o4+d2],%g1

	ble	__mark__record__selector__node__1
	srl	%g3,%o2,%g2

	btst	%g2,%g1
	bne	__mark__selector__1
	nop

	ld	[a1],d2
	btst	2,d2
	be	__mark__selector__1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,2
	bleu	__small__tuple__or__record
	nop

__large__tuple__or__record:
	ld	[a1+8],d1
	sub	d1,d6,%o2
	srl	%o2,5,d2
	srl	%o2,2,%o2
	andn	d2,3,d2
	ld	[%o4+d2],%g1
	srl	%g3,%o2,%g2

	btst	%g2,%g1
	bne	__mark__selector__1
	nop

#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]

	mov	a0,d2
	lduh	[d0+4],d0
	cmp	d0,8
	bltu,a	__mark_tuple_selector_node_1
	ld	[a1+d0],a0

	beq	__mark_tuple_selector_node_2
	mov	d1,a1

	dec	12,d0
	ld	[a1+d0],a0
	ba	__mark__node
	st	a0,[d2]

__mark_tuple_selector_node_2:
	ld	[a1],a0
	ba	__mark__node
	st	a0,[d2]
#endif

__small__tuple__or__record:
#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]
	mov	a0,d2
	lduh	[d0+4],d0
	ld	[a1+d0],a0
__mark_tuple_selector_node_1:
	ba	__mark__node
	st	a0,[d2]
#else
	sub	a0,4,d2

	ld	[d0-8],%g1
	mov	a1,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	set	__indirection,%g1
	st	%g1,[d2]
	ba	__mark__node
	st	a0,[d2+4]
#endif

__mark__record__selector__node__1:
	beq	__mark__strict__record__selector__node__1
	btst	%g2,%g1
	bne	__mark__selector__1
	nop

	ld	[a1],d2
	btst	2,d2
	be	__mark__selector__1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,258
#ifdef NEW_DESCRIPTORS
	bleu	__small__record
	nop

	ld	[a1+8],d1

	sub	d1,d6,%o0
	srl	%o0,5,%g1
	srl	%o0,2,%o0

	andn	%g1,3,%g1
	ld	[%o4+%g1],%g1
	srl	%g3,%o0,%o3

	btst	%o3,%g1
	bne	__mark__selector__1
	nop

__small__record:
	ld	[d0-8],d0
	set	__indirection,%g1
	st	%g1,[a0-4]
	lduh	[d0+4],d0
	cmp	d0,8
	bleu	__mark_record_selector_node_2
	mov	a0,d2

	mov	d1,a1
	dec	12,d0
__mark_record_selector_node_2:
	ld	[a1+d0],a0
	ba	__mark__node
	st	a0,[d2]
#else
	bleu	__small__tuple__or__record
	nop
	b,a	__large__tuple__or__record
#endif

__mark__strict__record__selector__node__1:
	bne	__mark__selector__1
	nop

	ld	[a1],d2
	btst	2,d2
	be	__mark__selector__1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,258
	ble	__select__from__small__record
	nop

	ld	[a1+8],%o2
	sub	%o2,d6,%o2
	srl	%o2,5,d2
	srl	%o2,2,%o2
	andn	d2,3,d2
	ld	[%o4+d2],%g1
	srl	%g3,%o2,%g2

	btst	%g2,%g1
	bne	__mark__selector__1
	nop

__select__from__small__record:
#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0
	dec	4,a0
	lduh	[d0+4],%g1
	cmp	%g1,8
	bleu,a	__mark_strict_record_selector_node_2
	ld	[a1+%g1],%g1

	dec	12,%g1
	ld	[d1+%g1],%g1
__mark_strict_record_selector_node_2:
	st	%g1,[a0+4]

	lduh	[d0+6],%g1
	tst	%g1
	beq	__mark_strict_record_selector_node_5
	ld	[d0-4],d0

	cmp	%g1,8
	bleu,a	__mark_strict_record_selector_node_4
	ld	[a1+%g1],%g1

	mov	d1,a1
	dec	12,%g1
	ld	[a1+%g1],%g1
__mark_strict_record_selector_node_4:
	st	%g1,[a0+8]
__mark_strict_record_selector_node_5:
	ba	__mark__node
	st	d0,[a0]
#else
	ld	[d0-8],%g1
	dec	4,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	b,a	__mark__node
#endif

__mark__indirection__node:
	ba	__mark__node
	mov	a1,a0

__mark__hnf__2:
	cmp	%o3,4
	bgeu	fits__in__word__6
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__6:
	st	%o1,[%o4+%o0]
	inc	3,d4

__mark__record__2__c:
	ld	[a0],%o0
	bset	d5,d3
	bset	2,%o0
	st	%o0,[a0]
	ld	[a0+4],d2
	st	d3,[a0+4]
	add	a0,4,d3
	clr	d5
	mov	d2,a0

__mark__node:
	sub	a0,d6,d1
#ifdef SHARE_CHAR_INT
	cmp	d1,d7
	bcc	__mark__next__node__after__static
#endif
	srl	d1,5,%o0
	srl	d1,2,d1
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d1,%o3

	btst	%o3,%o1
	beq	__mark__arguments
	nop

__mark__next__node:
	tst	d5
	bne	__mark__parent
	nop

__mark__next__node2:
	ld	[d3-4],d2
	dec	4,d3
	ld	[d3+4],%o0
	and	d2,3,d5

	st	%o0,[d3]

	st	a0,[d3+4]
	ba	__mark__node
	andn	d2,3,a0

__mark__lazy__node:
	tst	d2
	beq	__mark__real__or__file
	cmp	d2,1
	ble	__mark__lazy__node__1
	inc	4,a0

 	cmp	d2,256
	bgeu	__mark_closure_with_unboxed_arguments
	nop

	inc	1,d2
	and	d1,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2
	cmp	%o2,32
	bleu	fits__in__word__7
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__7:
	st	%o1,[%o4+%o0]
	
	dec	2,d2
__mark_closure_with_unboxed_arguments__2:
	ld	[a0],%o0
	sll	d2,2,d2
	bset	2,%o0
	st	%o0,[a0]
	add	a0,d2,a0

	ld	[a0],d2
	bset	d5,d3
	st	d3,[a0]
	mov	a0,d3
	clr	d5
	ba	__mark__node
	mov	d2,a0	

__mark_closure_with_unboxed_arguments:
	srl	d2,8,d0
	and	d2,255,d2
	deccc	1,d2
	beq	__mark_closure_1_with_unboxed_argument
	inc	2,d2

	and	d1,31,%o2
	add	d4,d2,d4
	add	%o2,d2,%o2

	cmp	%o2,32
	bleu	fits__in__word__7_
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__7_:
	st	%o1,[%o4+%o0]

	sub	d2,d0,d2
	deccc	2,d2
	bgt	__mark_closure_with_unboxed_arguments__2
	nop
	beq	__shared__argument__part
	nop
	ba	__mark__next__node
	dec	4,a0

__mark_closure_1_with_unboxed_argument:	
	ba	__mark__real__or__file
	dec	4,a0

__mark__hnf__0:
	set	INT+2,%g1
	cmp	d0,%g1
	bne	__no__int__3
	nop

	ld	[a0+4],d2
	cmp	d2,33
	bcs	____small____int
	sll	d2,3,d2

__mark__bool__or__small__string:
	cmp	%o3,2
	bgeu	fits__in__word__8
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__8:
	st	%o1,[%o4+%o0]
	ba	__mark__next__node
	inc	2,d4

____small____int:
	set	small_integers,a0
	ba	__mark__next__node__after__static
	add	a0,d2,a0

__no__int__3:
	blu	__mark__real__file__or__string	
	seth	(CHAR+2,%g1)

	setl	(CHAR+2,%g1)
 	cmp	d0,%g1
 	bne	__no__char__3
	nop

	ldub	[a0+7],d2
	set	static_characters,a0
	sll	d2,3,d2
	ba	__mark__next__node__after__static
	add	a0,d2,a0

__no__char__3:
	blu	__mark__bool__or__small__string
	nop

	ba	__mark__next__node__after__static
	sub	d0,2-ZERO_ARITY_DESCRIPTOR_OFFSET,a0

__mark__real__file__or__string:
	set	__STRING__+2,%g1
	cmp	d0,%g1
	bleu	__mark__string__or__array
	nop

__mark__real__or__file:
	cmp	%o3,4
	bgeu	fits__in__word__9
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__9:
	st	%o1,[%o4+%o0]
	ba	__mark__next__node
	inc	3,d4

__mark__record:
	deccc	258,d2
	be,a	__mark__record__2
	lduh	[d0-2+2],%g1

	blu,a	__mark__record__1
	lduh	[d0-2+2],%g1

__mark__record__3:
	cmp	%o3,4
	bset	%o3,%o1
	bgeu	fits__in__word__13
	ld	[a0+4],a1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__13:
	st	%o1,[%o4+%o0]

	lduh	[d0-2+2],d1

	sub	a1,d6,d0
	srl	d0,5,%o0
	srl	d0,2,d0
	andn	%o0,3,%o0
	ld	[%o4+%o0],%o1
	srl	%g3,d0,%o3

	btst	%o3,%o1
	bne	__shared__record__argument__part
	inc	3,d4

	inc	1,d2
	and	d0,31,%o2

	add	%o2,d2,%o2
	add	d4,d2,d4

	cmp	%o2,32
	bleu	fits__in__word__14
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word__14:
	st	%o1,[%o4+%o0]

	deccc	1,d1
	blu,a	__mark__next__node
	dec	4,a0

	be	__shared__argument__part
	nop

	deccc	1,d1
	bset	d5,d3
	st	d3,[a0+4]
	be	__mark__record__3__aab
	inc	4,a0

	ld	[a1],%g1
	sll	d1,2,d1
	bset	1,%g1
	st	%g1,[a1]

	add	a1,d1,a1

	ld	[a1],d2
	clr	d5
	st	a0,[a1]
	mov	a1,d3
	ba	__mark__node
	mov	d2,a0

__mark__record__3__aab:	
	ld	[a1],d2
	mov	1,d5
	st	a0,[a1]
	mov	a1,d3
	ba	__mark__node
	mov	d2,a0

__shared__record__argument__part:
	tst	d1
	bne	__shared__argument__part
	nop
	ba	__mark__next__node
	dec	4,a0

__mark__record__2:
	cmp	%o3,4
	bgeu	fits__in__word_12
	bset	%o3,%o1

	st	%o1,[%o4+%o0]
	inc	4,%o0

	ld	[%o4+%o0],%o1
	bset	%g3,%o1
fits__in__word_12:
	st	%o1,[%o4+%o0]
	inc	3,d4

	cmp	%g1,1
	bgu	__mark__record__2__c
	nop
	be	__shared__argument__part
	nop
	ba	__mark__next__node
	dec	4,a0

__mark__record__1:
	tst	%g1
	bne	__mark__hnf__1
	nop
	ba	__mark__bool__or__small__string
	dec	4,a0

__mark__string__or__array:
	beq	__mark__string__
	nop

__mark__array:
	ld	[a0+8],d1
	tst	d1
	be	__mark__lazy__array
	nop

	lduh	[d1-2],d0
	tst	d0
	be,a	__mark__strict__basic__array
	ld	[a0+4],d0

	lduh	[d1-2+2],d1
	tst	d1
	beq	__mark__b__record__array
	dec	256,d0

	cmp	d0,d1
	be,a	__mark__a__record__array
	ld	[a0+4],%g1

__mark__ab__record__array:
	mov	d2,%o2
	st	d3,[sp-12]
	mov	d4,%g1
	mov	d5,%o5
	mov	d6,%g2

	ld	[a0+4],d2
	inc	8,a0

	sll	d2,2,d2
	st	a0,[sp-4]
	umul	d2,d0,a1
	st	%o0,[sp-8]

	sub	d0,d1,d0
	inc	4,a0
	call	reorder
	add	a1,a0,a1
	
	ld	[sp-8],%o0
	mov	%g2,d6
	mov	%o5,d5
	ld	[sp-4],a0
	mov	%g1,d4
	ld	[sp-12],d3
	mov	%o2,d2

	ld	[a0-4],%g1
	mov	d0,a1
	umul	%g1,d1,d0
	umul	%g1,a1,d1
	add	d4,d1,d4
	add	d1,d0,d1

	sll	d1,2,d1
	add	a0,d1,d1
	sll	d0,2,a1
	add	a0,a1,a1
	ba	__mark__r__array
	sub	d1,d6,d1

__mark__a__record__array:
	umul	%g1,d0,d0
	inc	8,a0
	b,a	__mark__lr__array

__mark__lazy__array:
	ld	[a0+4],d0
	inc	8,a0

__mark__lr__array:
	sll	d0,2,a1
	add	a0,a1,a1
	sub	a1,d6,d1
__mark__r__array:
	srl	d1,5,d1
	inc	3,d4
	bset	%o3,%o1

	andn	d1,3,d1

	cmp	%o0,d1
	bgeu	__skip__mark__lazy__array__bits
	st	%o1,[%o4+%o0]

__mark__lazy__array__bits:
	inc	4,%o0
	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	cmp	%o0,d1
	bltu	__mark__lazy__array__bits
	st	%o1,[%o4+%o0]

__skip__mark__lazy__array__bits:
	set	lazy_array_list,%o2
	cmp	d0,1
	bleu	__mark__array__length__0__1
	add	d4,d0,d4

	ld	[a1],d2
	ld	[a0],%o0
	st	d2,[a0]
	st	%o0,[a1]
	
	ld	[a1-4],d2
	dec	4,a1
	ld	[%o2],%o1
	inc	2,d2
	st	%o1,[a1]
	st	d2,[a0-4]
	st	d0,[a0-8]
	dec	8,a0
	st	a0,[%o2]

	ld	[a1-4],a0
	dec	4,a1

	bset	d5,d3
	mov	0,d5
	st	d3,[a1]
	ba	__mark__node
	mov	a1,d3

__mark__array__length__0__1:
	blu	__mark__next__node
	dec	8,a0

	ld	[a0+12],d1
	ld	[a0+8],%o0
	ld	[%o2],%o3
	st	%o0,[a0+12]
	st	%o3,[a0+8]
	st	d0,[a0]

	st	a0,[%o2]
	st	d1,[a0+4]

	inc	4,a0

	ld	[a0],d2
	bset	d5,d3
	mov	2,d5
	st	d3,[a0]
	mov	a0,d3
	ba	__mark__node
	mov	d2,a0

__mark__b__record__array:
	ld	[a0+4],d1
	umul	d1,d0,d0
	ba	__mark__basic__array
	inc	3,d0

__mark__strict__basic__array:
	set	INT+2,%g1
	cmp	d1,%g1
	beq,a	__mark__basic__array
	inc	3,d0
	set	BOOL+2,%g1
	cmp	d1,%g1
	beq	__mark__strict__bool__array
	nop
__mark__strict__real__array:
	add	d0,d0,d0
	ba	__mark__basic__array
	inc	3,d0
__mark__strict__bool__array:
	inc	12+3,d0
	b	__mark__basic__array
	srl	d0,2,d0

__mark__string__:
	ld	[a0+4],d0
	inc	8+3,d0

	srl	d0,2,d0

__mark__basic__array:
	bset	%o3,%o1
	add	d4,d0,d4

	st	%o1,[%o4+%o0]

	sll	d0,2,d0
	add	a0,d0,d0
	dec	4,d0

	sub	d0,d6,d0
	srl	d0,5,d0
	andn	d0,3,d0
	
	cmp	%o0,d0
	bge	__mark__next__node
	inc	4,%o0

	cmp	%o0,d0
	bge	__last__string__bits
	nop
	
__mark__string__lp:
	st	%g3,[%o4+%o0]
	inc	4,%o0
	cmp	%o0,d0
	bltu,a	__mark__string__lp+4
	st	%g3,[%o4+%o0]

__last__string__bits:
	ld	[%o4+%o0],%o1
	bset	%g3,%o1
	ba	__mark__next__node
	st	%o1,[%o4+%o0]

__mark__parent:
	tst	d3
	be	__end__mark__using__reversal

	deccc	d5
	ld	[d3],d2
	be	__argument__part__parent
	st	a0,[d3]
	
	sub	d3,4,a0
	and	d2,3,d5
	ba	__mark__next__node
	andn	d2,3,d3
	
__argument__part__parent:
	mov	d3,a1

	andn	d2,3,d3
	dec	4,d3

	ld	[d3],a0
	ld	[d3+4],%o0
	mov	2,d5
	st	%o0,[d3]

	ba	__mark__node
	st	a1,[d3+4]

__mark__next__node__after__static:
	tst	d5
	beq	__mark__next__node2

	tst	d3
	be	__end__mark__using__reversal__after__static

	deccc	d5
	ld	[d3],d2
	be	__argument__part__parent
	st	a0,[d3]

	sub	d3,4,a0
	and	d2,3,d5
	ba	__mark__next__node
	andn	d2,3,d3
