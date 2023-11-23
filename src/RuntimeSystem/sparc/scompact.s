
! mark used nodes and pointers in argument parts and link backward pointers

	ldg	(heap_size_33,d7)
	sll	d7,5,d7

 	ldg	(caf_list,d0)
	
	st	a4,[sp-4]
	
	tst	d0
	be	end_mark_cafs
	dec	4,sp

	dec	4,sp

mark_cafs_lp:
	ld	[d0-4],%g1
	add	d0,4,a2
	ld	[d0],d0
	st	%g1,[sp]
	sll	d0,2,d0
	add	a2,d0,a4

	dec	4,sp
	call	mark_stack_nodes
	st	%o7,[sp]

	ld	[sp],d0
	addcc	d0,0,d0
	bne	mark_cafs_lp
	nop

	inc	4,sp

end_mark_cafs:
	ldg	(stack_p,a2)

	ld	[sp],a4
	call	mark_stack_nodes
	st	%o7,[sp]

	b,a	compact_heap

mark_record:	
	deccc	258,d2
	be,a	mark_record_2
	lduh	[d0-2+2],%g1

	blu,a	mark_record_1
	lduh	[d0-2+2],%g1

mark_record_3:
	lduh	[d0-2+2],d2
	deccc	1,d2
	blu,a	mark_record_3_bb
	dec	4,a0

	be	mark_record_3_ab
	nop

	deccc	1,d2
	be	mark_record_3_aab
	nop

	b,a	mark_hnf_3

mark_record_3_bb:
	ld	[a0+8],a1

	sub	a1,d6,d0
	srl	d0,2,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)

	cmp	a1,a0
	bgu	mark_next_node
	nop

	cmp	%o0,1
	bne	not_next_byte_1
	srl	%o0,1,%o0

	inc	1,d1
	ldub	[%o4+d1],%o1
	mov	128,%o0
not_next_byte_1:
	btst	%o0,%o1
	be	not_yet_linked_bb
	bset	%o0,%o1
	
	sub	a0,d6,d0
	srl	d0,2,d0
	inc	2,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)

	ld	[a1],%o0
	add	a0,8+2+1,d0
	st	%o0,[a0+8]
	ba	mark_next_node
	st	d0,[a1]	
	
not_yet_linked_bb:
	stb	%o1,[%o4+d1]
	ld	[a1],%o0
	add	a0,8+2+1,d0
	st	%o0,[a0+8]
	ba	mark_next_node
	st	d0,[a1]	

mark_record_3_ab:
	ld	[a0+4],a1

	sub	a1,d6,d0
	srl	d0,2,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)

	cmp	a1,a0
	bgu	rmarkr_hnf_1
	nop

	cmp	%o0,1
	bne	not_next_byte_2
	srl	%o0,1,%o0

	inc	1,d1
	ldub	[%o4+d1],%o1
	mov	128,%o0
not_next_byte_2:
	btst	%o0,%o1
	be	not_yet_linked_ab
	bset	%o0,%o1

	sub	a0,d6,d0
	srl	d0,2,d0
	inc	1,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)

	ld	[a1],%o0
	add	a0,4+2+1,d0
	st	%o0,[a0+4]
	ba	rmarkr_hnf_1
	st	d0,[a1]
	
not_yet_linked_ab: 
	stb	%o1,[%o4+d1]
	ld	[a1],%o0
	add	a0,4+2+1,d0
	st	%o0,[a0+4]
	ba	rmarkr_hnf_1
	st	d0,[a1]

mark_record_3_aab:
	ld	[a0+4],a1

	sub	a1,d6,d0
	srl	d0,2,d0

	tstmbit	(%o4,d0,d1,%o0,%o1,%o2)
	bne	shared_argument_part
	bset	%o0,%o1

	stb	%o1,[%o4+d1]

	ld	[a0],%o0
	inc	4,a0
	or	%o0,2,%o0
	st	%o0,[a0-4]
	or	d3,d5,d3
	st	d3,[a0]
	
	ld	[a1],d2
	st	a0,[a1]
	mov	a1,d3
	mov	1,d5
	ba	rmarkr_node
	mov	d2,a0

mark_record_2:
	cmp	%g1,1
	bgu,a	mark_hnf_2
	ld	[a0],%o0

	be	rmarkr_hnf_1
	nop
	ba	mark_next_node
	dec	4,a0

mark_record_1:
	tst	%g1
	bne	rmarkr_hnf_1
	nop
	ba	mark_next_node
	dec	4,a0



mark_stack_nodes3:
	ba	mark_stack_nodes
	st	a0,[%i2-4]

mark_stack_nodes2:
	ld	[a0],%g1
	add	%i2,1-4,d0
	st	%g1,[%i2-4]
	st	d0,[a0]

mark_stack_nodes:
	cmp	a4,a2
	be	end_mark_nodes
	inc	4,a2

	ld	[a2-4],a0

	mov	128,%o3

	sub	a0,d6,d0
#ifdef SHARE_CHAR_INT
	cmp	d0,d7
	bcc	mark_stack_nodes
#endif
	srl	d0,2,d0

	srl	d0,3,%o0
	ldub	[%o4+%o0],%o1
	and	d0,7,%o2
	srl	%o3,%o2,%o3
	btst	%o3,%o1
	bne	mark_stack_nodes2
	bset	%o3,%o1

	stb	%o1,[%o4+%o0]
	
	clr	%l3
	mov	1,%l5

mark_arguments:
	ld	[a0],d0
	btst	2,d0
	be	mark_lazy_node
	ldsh	[d0-2],d2

	tst	d2
	be	mark_hnf_0
	cmp	d2,256
	bgeu	mark_record
	inc	4,a0

	deccc	2,d2
	be,a	mark_hnf_2
	ld	[a0],%o0

	bcs	rmarkr_hnf_1
	nop

mark_hnf_3:
	ld	[a0+4],a1
	
	mov	128,%o3

	sub	a1,d6,d0
	srl	d0,2,d0

	srl	d0,3,%o0
	ldub	[%o4+%o0],%o1
	and	d0,7,%o2
	srl	%o3,%o2,%o3
	btst	%o3,%o1
	bne	shared_argument_part
	bset	%o3,%o1

	stb	%o1,[%o4+%o0]

no_shared_argument_part:
	ld	[a0],%o0
	bset	%l5,%l3
	bset	2,%o0
	st	%o0,[a0]
	st	%l3,[a0+4]
	inc	4,a0

	ld	[a1],%o0
	sll	d2,2,d2
	bset	1,%o0
	st	%o0,[a1]
	add	a1,d2,a1

	ld	[a1],d2
	st	a0,[a1]
	mov	a1,%l3
	clr	%l5
	ba	rmarkr_node
	mov	d2,a0

shared_argument_part:
	cmp	a1,a0
	bgu	rmarkr_hnf_1
	nop

	ld	[a1],%o0
	add	a0,4+2+1,d0
	st	d0,[a1]
	ba	rmarkr_hnf_1
	st	%o0,[a0+4]

mark_lazy_node_1:
	bne	mark_selector_node_1
	nop

rmarkr_hnf_1:
	ld	[a0],d2
	bset	d5,d3
	st	d3,[a0]
	mov	a0,d3
	mov	2,d5
	ba	rmarkr_node
	mov	d2,a0

mark_indirection_node:
	sub	a0,4,%o1
	sub	%o1,d6,%o1
	srl	%o1,2,%o1

	srl	%o1,3,d2
	ldub	[%o4+d2],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1
	stb	%g1,[%o4+d2]

	ba	rmarkr_node
	ld	[a0],a0

mark_selector_node_1:
	inccc	3,d2
	be	mark_indirection_node
	nop
	
	ld	[a0],a1
	sub	a1,d6,%o1
	srl	%o1,2,%o1

	inccc	d2
	ble	mark_record_selector_node_1
	srl	%o1,3,d2

	ldub	[%o4+d2],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

	ld	[a1],d2
	btst	2,d2
	be	rmarkr_hnf_1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,2
	bleu	rmarkr_small_tuple_or_record
	nop

rmarkr_large_tuple_or_record:
	ld	[a1+8],d1
	sub	d1,d6,%o1
	srl	%o1,2,%o1

	srl	%o1,3,d2
	ldub	[%o4+d2],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

#ifdef NEW_DESCRIPTORS
	ld	[d0-8],d0

	sub	a0,4,d2

	set	__indirection,%g1
	lduh	[d0+4],d0

	sub	d2,d6,%o1
	srl	%o1,2,%o1

	st	%g1,[a0-4]

	srl	%o1,3,a0
	ldub	[%o4+a0],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1

	cmp	d0,8
	bltu	rmarkr_tuple_or_record_selector_node_2
	stb	%g1,[%o4+a0]

	beq,a	rmarkr_tuple_selector_node_2
	ld	[d1],a0

rmarkr_tuple_or_record_selector_node_g2:
	sub	d1,12,a0
	ld	[a0+d0],a0

rmarkr_tuple_selector_node_2:
	ba	rmarkr_node
	st	a0,[d2+4]
#else
rmarkr_small_tuple_or_record:
	sub	a0,4,d2
	sub	d2,d6,%o1
	srl	%o1,2,%o1

	srl	%o1,3,d1
	ldub	[%o4+d1],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1
	stb	%g1,[%o4+d1]

	ld	[d0-8],%g1
	mov	a1,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	set	__indirection,%g1
	st	%g1,[d2]
	ba	rmarkr_node
	st	a0,[d2+4]
#endif

mark_record_selector_node_1:
	beq	mark_strict_record_selector_node_1
	ldub	[%o4+d2],%g1

	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

	ld	[a1],d2
	btst	2,d2
	be	rmarkr_hnf_1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,258
	bleu	rmarkr_small_tuple_or_record
	nop

#ifdef NEW_DESCRIPTORS
	ld	[a1+8],d1

	sub	d1,d6,%o1
	srl	%o1,2,%o1

	srl	%o1,3,d2
	ldub	[%o4+d2],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

rmarkr_small_tuple_or_record:
	ld	[d0-8],d0

	sub	a0,4,d2

	set	__indirection,%g1
	lduh	[d0+4],d0

	sub	d2,d6,%o1
	srl	%o1,2,%o1

	st	%g1,[a0-4]

	srl	%o1,3,a0
	ldub	[%o4+a0],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1

	cmp	d0,8
	bgtu	rmarkr_tuple_or_record_selector_node_g2
	stb	%g1,[%o4+a0]

rmarkr_tuple_or_record_selector_node_2:
	ld	[a1+d0],a0
	ba	rmarkr_node
	st	a0,[d2+4]
#else
	b,a	rmarkr_large_tuple_or_record
#endif

mark_strict_record_selector_node_1:
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

	ld	[a1],d2
	btst	2,d2
	be	rmarkr_hnf_1
	nop

	ldsh	[d2-2],%g1
	cmp	%g1,258
	bleu	select_from_small_record
	nop

	ld	[a1+8],d1
	sub	d1,d6,%o1
	srl	%o1,2,%o1

	srl	%o1,3,d2
	ldub	[%o4+d2],%g1
	and	%o1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	btst	%g3,%g1
	bne	rmarkr_hnf_1
	nop

select_from_small_record:
#ifdef NEW_DESCRIPTORS
	ld	[d0-8],%g1
	dec	4,a0
	lduh	[%g1+4],d0
	cmp	d0,8
	bleu,a	rmarkr_strict_record_selector_node_2
	ld	[a1+d0],d0

	dec	12,d0
	ld	[d1+d0],d0
rmarkr_strict_record_selector_node_2:
	st	d0,[a0+4]

	lduh	[%g1+6],d0
	tst	d0
	beq	rmarkr_strict_record_selector_node_5
	cmp	d0,8
	bleu,a	rmarkr_strict_record_selector_node_4
	ld	[a1+d0],d0

	mov	d1,a1
	dec	12,d0
	ld	[a1+d0],d0
rmarkr_strict_record_selector_node_4:
	st	d0,[a0+8]
rmarkr_strict_record_selector_node_5:
	ld	[%g1-4],d0
	ba	mark_next_node
	st	d0,[a0]
#else
	ld	[d0-8],%g1
	dec	4,a0
	ld	[%g1+4],%g1

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	b,a	mark_next_node
#endif

mark_hnf_2:
	bset	2,%o0
	st	%o0,[a0]
	inc	4,a0
	ld	[a0],d2
	bset	d5,d3
	st	d3,[a0]
	mov	a0,%l3
	clr	d5
	mov	d2,a0

rmarkr_node:
	sub	a0,d6,d0
#ifdef SHARE_CHAR_INT
	cmp	d0,%l7
	bcc	mark_next_node_after_static
#endif
	srl	d0,2,d0

	srl	d0,3,%o0
	ldub	[%o4+%o0],%o1
	and	d0,7,%o2
	mov	128,%o3
	srl	%o3,%o2,%o3
	btst	%o3,%o1
	bset	%o3,%o1
	be	mark_arguments
	stb	%o1,[%o4+%o0]

mark_next_node:
	tst	d5	!
	bne,a	mark_parent+4
	tst	d3

	ld	[d3-4],d2
	dec	4,d3

	and	d2,3,d5
	cmp	d5,3
	be	argument_part_cycle1
	ld	[d3+4],%o0

	st	%o0,[d3]

c_argument_part_cycle1:
	cmp	a0,d3
	bgu	no_reverse_1
	nop

	ld	[a0],%o0
	add	%l3,4+1,d0
	st	%o0,[%l3+4]
	st	d0,[a0]
	ba	rmarkr_node
	andn	d2,3,a0

no_reverse_1:
	st	a0,[%l3+4]
	ba	rmarkr_node
	andn	d2,3,a0

mark_lazy_node:
	tst	d2
	be	mark_next_node
	add	d0,-2,a1

	deccc	d2
	ble	mark_lazy_node_1
	inc	4,a0

 	cmp	d2,255
	bgeu,a	mark_closure_with_unboxed_arguments
	srl	d2,8,d0

mark_closure_with_unboxed_arguments_:
	ld	[a0],%o0
	sll	d2,2,d2
	bset	2,%o0
	st	%o0,[a0]
	add	a0,d2,a0

	ld	[a0],d2
	bset	%l5,%l3
	st	%l3,[a0]
	mov	a0,%l3
	clr	%l5
	ba	rmarkr_node
	mov	d2,a0

mark_closure_with_unboxed_arguments:
!	inc	d2
!	srl	d2,8,d0
	and	d2,255,d2
	subcc	d2,d0,d2
!	deccc	d2
	bgt	mark_closure_with_unboxed_arguments_
	nop
	
	beq	rmarkr_hnf_1
	nop
	
	b	mark_next_node	
	dec	4,a0

mark_hnf_0:
#ifdef SHARE_CHAR_INT
	set	INT+2,%g1
	cmp	d0,%g1
	bne	no_int_3
	nop

	ld	[a0+4],d2
	cmp	d2,33
	bcc	mark_next_node
	nop

	sub	a0,d6,d1
	srl	d1,2,d1

	srl	d1,3,d0
	ldub	[%o4+d0],%g1
	and	d1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1
	stb	%g1,[%o4+d0]

	set	small_integers,a0
	sll	d2,3,d2
	ba	mark_next_node_after_static
	add	a0,d2,a0
no_int_3:

	set	CHAR+2,%g1
 	cmp	d0,%g1
 	bne	no_char_3
	nop

	sub	a0,%l6,d1
	srl	d1,2,d1

	srl	d1,3,d0
	ldub	[%o4+d0],%g1
	and	d1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1
	stb	%g1,[%o4+d0]

	ldub	[a0+7],d2
	set	static_characters,a0
	sll	d2,3,d2
	ba	mark_next_node_after_static
	add	a0,d2,a0

no_char_3:
	blu	no_normal_hnf_0
	nop

	sub	a0,%l6,d1
	srl	d1,2,d1

	sub	d0,2-ZERO_ARITY_DESCRIPTOR_OFFSET,a0

	srl	d1,3,d0
	ldub	[%o4+d0],%g1
	and	d1,7,%g2
	mov	128,%g3
	srl	%g3,%g2,%g3
	bclr	%g3,%g1
	ba	mark_next_node_after_static
	stb	%g1,[%o4+d0]
	
no_normal_hnf_0:
#endif
	set	__ARRAY__+2,%o0
	cmp	d0,%o0
	bne,a	mark_next_node+4
	tst	d5

	ld	[a0+8],d1
	tst	d1
	be,a	mark_lazy_array
	ld	[a0+4],d0

	lduh	[d1-2],d0
	tst	d0
	be,a	mark_b_record_array
	sub	a0,d6,d0

	lduh	[d1-2+2],d1
	tst	d1
	be,a	mark_b_record_array
	sub	a0,d6,d0

	dec	256,d0
	cmp	d0,d1
	be,a	mark_a_record_array
	ld	[a0+4],d0

mark_ab_record_array:
	mov	d2,%o2
	mov	d3,%o3
	mov	d4,%g2
	mov	d5,%o5
	mov	d6,%g3

	ld	[a0+4],d2
	inc	8,a0

	mov	a0,%g4

	sll	d2,2,d2
	sub	d0,2,d3
	mov	d2,a1
mul_array_length_ab1:
	deccc	1,d3
	bcc	mul_array_length_ab1
	add	a1,d2,a1

	sub	d0,d1,d0
	inc	4,a0
	call	reorder
	add	a1,a0,a1

!	mov	a0,d0

	mov	%g4,a0

!	sub	d0,a0,d0
!	srl	d0,2,d0
!	dec	1,d0

	ld	[a0-4],d2
	deccc	2,d1
	bcs	skip_mul_array_length_a1_
	mov	d2,d0
mul_array_length_a1_:
	deccc	1,d1
	bcc	mul_array_length_a1_
	add	d0,d2,d0
skip_mul_array_length_a1_:
	
	mov	%g3,d6
	mov	%o5,d5
	mov	%g2,d4
	mov	%o3,d3
	ba	mark_lr_array
	mov	%o2,d2

mark_b_record_array:
	srl	d0,2,d0
	inc	1,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)
	b,a	mark_next_node

mark_a_record_array:
	deccc	2,d1
	blu	mark_lr_array
	inc	8,a0

	mov	d0,d2
mul_array_length:
	deccc	1,d1
	bcc	mul_array_length
	add	d0,d2,d0

	b,a	mark_lr_array

mark_lazy_array:
	inc	8,a0

mark_lr_array:
	sub	a0,d6,d1
	srl	d1,2,d1
	add	d1,d0,d1
	setmbit	(%o4,d1,d2,%o0,%o1,%o2)

	cmp	d0,1
	bleu	mark_array_length_0_1
	nop

	mov	a0,a1
	sll	d0,2,d0
	add	a0,d0,a0

	ld	[a0],d2
	ld	[a1],%o0
	st	d2,[a1]
	st	%o0,[a0]
	
	ld	[a0-4],d2
	dec	4,a0
	inc	2,d2
	ld	[a1-4],%o0
	dec	4,a1
	st	%o0,[a0]
	st	d2,[a1]

	ld	[a0-4],d2
	dec	4,a0
	or	d3,d5,d3
	st	d3,[a0]
	mov	a0,d3
	mov	0,d5
	ba	rmarkr_node
	mov	d2,a0

mark_array_length_0_1:
	blu,a	mark_next_node
	dec	8,a0
	
	ld	[a0+4],d1
	ld	[a0],%o0
	ld	[a0-4],%o1
	st	%o0,[a0+4]
	st	%o1,[a0]
	st	d1,[a0-4]
	ba	rmarkr_hnf_1
	dec	4,a0

mark_parent:
	tst	d3
	be	mark_stack_nodes2
	nop

	deccc	d5
	be	argument_part_parent
	nop

	ld	[%l3],d2
	
	cmp	a0,%l3
	bgu	no_reverse_2
	nop

	mov	a0,a1
	add	%l3,1,d0
	ld	[a1],a0
	st	d0,[a1]

no_reverse_2:
	st	a0,[%l3]
	sub	%l3,4,a0
	and	d2,3,%l5
	ba	mark_next_node
	andn	d2,3,%l3
	
argument_part_parent:
	mov	%l3,a1
	mov	a0,%l3
	mov	a1,a0

	ld	[a1],d2
skip_upward_pointers:
	and	d2,3,d0
	cmp	d0,3
	bne	no_upward_pointer
	nop
	andn	d2,3,a1
	ba	skip_upward_pointers
	ld	[a1],d2

no_upward_pointer:
	cmp	%l3,a0
	bgu	no_reverse_3
	nop

	mov	%l3,%g6
	ld	[%l3],%l3
	add	a0,1,d0
	st	d0,[%g6]
	
no_reverse_3:
	st	%l3,[a1]

	andn	d2,3,%l3

	dec	4,%l3
	mov	%l3,a1
	ld	[a1],d2
	and	d2,3,%l5
	ld	[a1+4],%o0
	
	cmp	a0,a1
	bgu	no_reverse_4
	st	%o0,[a1]

	ld	[a0],%o0
	st	%o0,[a1+4]
	add	a1,4+2+1,d0
	st	d0,[a0]
	ba	rmarkr_node
	andn	d2,3,a0

no_reverse_4:
	st	a0,[a1+4]
	ba	rmarkr_node
	andn	d2,3,a0

argument_part_cycle1:
	mov	a1,d1
!
skip_pointer_list1:
	andn	d2,3,a1
	ld	[a1],d2
	and	d2,3,d5
	cmp	d5,3
	be,a	skip_pointer_list1+4
	andn	d2,3,a1

	st	%o0,[a1]
	ba	c_argument_part_cycle1
	mov	d1,a1

#ifdef SHARE_CHAR_INT
mark_next_node_after_static:
	tst	d5
	bne	mark_parent_after_static
	nop

	dec	4,%l3
	ld	[%l3],d2
	ld	[%l3+4],%o0
	and	d2,3,%l5
	
	cmp	%l5,3
	be	argument_part_cycle2
	nop
	
	st	%o0,[%l3]

c_argument_part_cycle2:
	st	a0,[%l3+4]
	ba	rmarkr_node
	andn	d2,3,a0

mark_parent_after_static:
	tst	d3
	be	mark_stack_nodes3
	nop

	deccc	d5
	be	argument_part_parent_after_static
	nop

	ld	[d3],d2
	st	a0,[d3]
	sub	d3,4,a0
	and	d2,3,d5
	ba	mark_next_node
	andn	d2,3,d3
	
argument_part_parent_after_static:
	mov	d3,a1
	mov	a0,d3
	mov	a1,a0

	ld	[a1],d2
skip_upward_pointers_2:
	and	d2,3,d0
	cmp	d0,3
	bne	no_reverse_3
	nop
	andn	d2,3,a1
	ba	skip_upward_pointers_2
	ld	[a1],d2

argument_part_cycle2:
	mov	a1,d1

skip_pointer_list2:
	andn	d2,3,a1
	ld	[a1],d2
	and	d2,3,%l5
	cmp	%l5,3
	be	skip_pointer_list2
	nop

	st	%o0,[a1]
	ba	c_argument_part_cycle2
	mov	d1,a1
#endif

end_mark_nodes:
	ld	[sp],%o7
	retl
	inc	4,sp

! compact the heap
compact_heap:

#ifdef FINALIZERS
	set	finalizer_list,a0
	set	free_finalizer_list,a1

	ld	[a0],a2
determine_free_finalizers_after_compact1:
	set	__Nil-8,%o0
	cmp	%o0,a2
	beq	end_finalizers_after_compact1
	mov	128,%o3

	sub	a2,d6,d0
	srl	d0,2,d0
	srl	d0,3,%o0
	ldub	[%o4+%o0],%o1
	and	d0,7,%o2
	srl	%o3,%o2,%o3
	btst	%o3,%o1
	beq	finalizer_not_used_after_compact1
	nop

	ld	[a2],d0
	b	finalizer_find_descriptor
	mov	a2,a3

finalizer_find_descriptor_lp:
	andn	d0,3,d0
	mov	d0,a3
	ld	[d0],d0
finalizer_find_descriptor:
	btst	1,d0
	bne	finalizer_find_descriptor_lp
	nop

	set	e____system__kFinalizerGCTemp+2,%o0
	st	%o0,[a3]

	cmp	a2,a0
	bgt	finalizer_no_reverse
	nop

	ld	[a2],d0
	add	a0,1,a3
	st	a3,[a2]
	st	d0,[a0]

finalizer_no_reverse:
	add	a2,4,a0
	ba	determine_free_finalizers_after_compact1
	ld	[a2+4],a2

finalizer_not_used_after_compact1:
	set	e____system__kFinalizerGCTemp+2,%o0
	st	%o0,[a2]

	st	a2,[a1]
	add	a2,4,a1

	ld	[a2+4],a2
	ba	determine_free_finalizers_after_compact1
	st	a2,[a0]

end_finalizers_after_compact1:
	st	a2,[a1]

	set	finalizer_list,%o1
	ld	[%o1],a0
	set	__Nil-8,%o0
	cmp	%o0,a0
	beq	finalizer_list_empty
	nop
	
	btst	3,a0
	bne	finalizer_list_already_reversed
	nop
	
	ld	[a0],d0
	add	%o1,1,%o0
	st	%o0,[a0]
	st	d0,[%o1]
finalizer_list_already_reversed:
finalizer_list_empty:

	set	free_finalizer_list,a2
	set	__Nil-8,%o0
	ld	[a2],%o1
	cmp	%o0,%o1
	beq	free_finalizer_list_empty
	nop

	dec	8,sp
	st	a4,[sp+4]

	add	a2,4,a4

	call	mark_stack_nodes
	st	%o7,[sp]
	
	ld	[sp],a4
	inc	4,sp

free_finalizer_list_empty:
#endif


	ldg	(heap_size_33,d5)
	sll	d5,5,d2

#ifdef SHARE_CHAR_INT
	add	d2,%l6,d2
#endif

	inc	3,%l5
	srl	%l5,2,%l5
!	set	INT+2,%l3
	
	mov	%o4,%i2
	mov	%l6,%g6
	ba	find_non_zero_long_2
	clr	d4

skip_zeros_2:
	tst	d4
	bne	end_skip_zeros
	inc	4,a2	
find_non_zero_long_2:
	deccc	d5
	bpos,a	skip_zeros_2
	ld	[a2],d4

	b,a	end_compact_heap

end_skip_zeros:
	sub	%i2,%o4,%l7
	dec	4,%l7
	sll	%l7,5,%l7
	add	%l7,%l6,%l7

skip_zero_bits:
	seth	(first_one_bit_table,%o0)	!
	srl	d4,24,%o1
	setl	(first_one_bit_table,%o0)
	ldsb	[%o0+%o1],d1
	tst	d1
	bpos,a	copy_nodes
	sll	d4,d1,d4

	tst	d4
	be	find_non_zero_long_2
	sethi	%hi 0xff000000,%o2

more_than_7:
	sll	d4,8,d4
	btst	d4,%o2
	beq	more_than_7
	inc	8<<2,d7

less_than_8:
	srl	d4,24,%o1
	ldsb	[%o0+%o1],d1
	sll	d4,d1,d4

copy_nodes:
	sll	d1,2,d1
	sll	d4,1,d4

	ld	[d7+d1],d0
	add	d7,d1,a0
	add	a0,4,d7
	inc	4,a0

	btst	2,d0
	beq	begin_update_list_2
	bclr	3,d0

	ld	[d0-8],d3
	mov	d0,a1
	btst	1,d3
	be	end_list_2
	bclr	1,d3
find_descriptor_2:
	andn	d3,2,a1
	ld	[a1],d3
	btst	1,d3
	bne	find_descriptor_2
	bclr	1,d3
end_list_2:
	lduh	[d3-2],d1

 	cmp	d1,256
	blu	no_record_arguments
	nop

	lduh	[d3-2+2],d3
	deccc	2,d3
	bgeu	copy_record_arguments_aa
	nop
	dec	256+3,d1

copy_record_arguments_all_b:
	mov	d1,%g2

update_up_list_1r:
	mov	d0,a1
	sub	d0,d6,d0
	srl	d0,2,d0

	tstmbit	(%o4,d0,d1,%o0,%o1,%o2)
	beq	copy_argument_part_1r
	nop

	ld	[a1],d0
	st	a6,[a1]
	ba	update_up_list_1r
	dec	3,d0

copy_argument_part_1r:
	ld	[a1],d0
	st	a6,[a1]
	st	d0,[a6]
	inc	4,a6

	mov	%g2,d1

copy_b_record_argument_part_arguments:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[%g6]
	deccc	d1
	bcc	copy_b_record_argument_part_arguments
	inc	4,%g6

	sub	%i2,%o4,%o0
	sll	%o0,5,%o0
	add	%o0,%l6,%o0

	cmp	%o0,d7
	inc	4,d7
	bne	skip_zero_bits
	sll	d4,1,d4

	deccc	%l5
	bneg	end_compact_heap
	sethi	%hi 0x80000000,%o1

	ld	[%i2],d4
	ba	skip_zeros_2
	bclr	%o1,d4

copy_record_arguments_aa:
	dec	256+2,d1
	sub	d1,d3,d1
	mov	d1,%g2

update_up_list_2r:
	mov	d0,a1
	ld	[a1],d0
	and	d0,3,d1
	deccc	3,d1
	bne	copy_argument_part_2r
	st	a6,[a1]

	ba	update_up_list_2r
	dec	3,d0

copy_argument_part_2r:
	cmp	d0,a0
	bleu	copy_record_argument_2
	nop
#ifdef SHARE_CHAR_INT
	cmp	d0,d2
	bgeu	copy_record_argument_2
	nop
#endif
	mov	d0,a1
	ld	[a1],d0
	add	a6,1,d1
	st	d1,[a1]
copy_record_argument_2:
	st	d0,[a6]
	inc	4,a6

	deccc	1,d3
	bcs	no_pointers_in_record
	nop
copy_record_pointers:
	ld	[a0],a1
	inc	4,a0
	cmp	a1,a0
	blu	copy_record_pointers_2
	nop
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bgeu	copy_record_pointers_2
	nop
#endif
	ld	[a1],d1
	add	a6,1,d0
	st	d0,[a1]
	mov	d1,a1
copy_record_pointers_2:
	st	a1,[a6]
	deccc	1,d3
	bcc	copy_record_pointers
	inc	4,a6
	
no_pointers_in_record:
	tst	%g2
	be	no_non_pointers_in_record
	sub	%g2,1,d1

copy_non_pointers_in_record:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[a6]
!	deccc	1,d2
	deccc	1,d1
	bcc	copy_non_pointers_in_record
	inc	4,a6
no_non_pointers_in_record:
	b,a	skip_zero_bits

no_record_arguments:
	dec	3,d1
update_up_list_2:
	mov	d0,a1
	ld	[a1],d0
	and	d0,3,d3
	cmp	d3,3
	bne,a	copy_argument_part_2
	st	a6,[a1]

	st	%g6,[a1]
	ba	update_up_list_2
	andn	d0,3,d0

copy_argument_part_2:

! update_up_list_2:
!	mov	d0,a1
!	ld	[a1],d0
!	and	d0,3,d1
!	cmp	d1,3
!	bne	copy_argument_part_2
!	nop
!	st	%g6,[a1]
!	ba	update_up_list_2
!	andn	d0,3,d0
!
! copy_argument_part_2:	
!	st	%g6,[a1]
!
!	ld	[a1-8],d1
!	btst	1,d1
!	beq	end_list_2
!	nop
!	andn	d1,3,a1
! find_descriptor_2:
!	ld	[a1],d1
!	btst	1,d1
!	bne,a	find_descriptor_2
!	andn	d1,3,a1
! end_list_2:
!
!	lduh	[d1-2],d1
!	dec	3,d1

	cmp	d0,a0
	bcs	copy_arguments_1
	inc	4,%g6

#ifdef SHARE_CHAR_INT
	cmp	d0,d2
	bcc	copy_arguments_1
#endif
	mov	d0,a1
	ld	[a1],d0
	add	%g6,1-4,%l3
	st	%l3,[a1]
copy_arguments_1:
	st	d0,[%g6-4]

copy_argument_part_arguments:
	ld	[a0],a1
	inc	4,a0
	cmp	a1,a0
	bcs	copy_arguments_2
	nop
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_arguments_2
#endif
	or	%g6,1,d0
	ld	[a1],%l3
	st	d0,[a1]
	mov	%l3,a1

copy_arguments_2:
	st	a1,[%g6]
	deccc	1,d1
	bcc	copy_argument_part_arguments
	inc	4,%g6

	b,a	skip_zero_bits

update_list_2:
	st	%g6,[a1]
begin_update_list_2:
	mov	d0,a1
	ld	[a1],d0
update_list__2:
	btst	1,d0
	be	end_update_list_2
	bclr	1,d0
	btst	2,d0
	be	update_list_2
	bclr	2,d0
	mov	d0,a1
	ba	update_list__2
	ld	[a1],d0

end_update_list_2:
	st	%g6,[a1]

	btst	2,d0
	st	d0,[%g6]
	be	move_lazy_node
	inc	4,%g6

	lduh	[d0-2],d1
	tst	d1
	be	move_hnf_0
	cmp	d1,256
	bgeu	move_record
	nop

	deccc	2,d1
	bcs	copy_hnf_1
	nop
	be	copy_hnf_2
	nop

copy_hnf_3:
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_hnf_3_1
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_hnf_3_1
#endif
	or	%g6,1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
copy_hnf_3_1:
	st	a1,[%g6]
	
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_hnf_3_2
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_hnf_3_2
#endif
	add	%g6,4+2+1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
copy_hnf_3_2:
	st	a1,[%g6+4]
	ba	skip_zero_bits
	inc	8,%g6

copy_hnf_2:
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_hnf_2_1
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_hnf_2_1
#endif
	or	%g6,1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
copy_hnf_2_1:
	st	a1,[%g6]
	
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_hnf_2_2
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_hnf_2_2
#endif
	add	%g6,4+1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
copy_hnf_2_2:
	st	a1,[%g6+4]
	ba	skip_zero_bits
	inc	8,%g6

copy_hnf_1:
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_hnf_1_
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_hnf_1_
#endif
	or	%g6,1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
copy_hnf_1_:
	st	a1,[%g6]
	ba	skip_zero_bits
	inc	4,%g6

move_real_or_file:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[%g6]
	inc	4,%g6
move_int_bool_or_char:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[%g6]
	inc	4,%g6
copy_normal_hnf_0:
	ba	skip_zero_bits
	nop

move_hnf_0:
	set	INT+2,%l3
	cmp	d0,%l3
	blu	move_real_file_or_string
	seth	(CHAR+2,%o0)

	setl	(CHAR+2,%o0)
	cmp	d0,%o0
	bleu	move_int_bool_or_char
	nop
!	b,a	copy_normal_hnf_0
	b,a	skip_zero_bits

move_real_file_or_string:
	set	__STRING__+2,%o0
	cmp	d0,%o0
	bgu	move_real_or_file
	nop
	bne	move_array
	nop

move_string:
	ld	[a0],d0
	inc	3,d0
	srl	d0,2,d0

cp_s_arg_lp3:
	ld	[a0],%o0	!
	inc	4,a0
	st	%o0,[%g6]
	inc	4,%g6
	deccc	d0
	bge,a	cp_s_arg_lp3+4
	ld	[a0],%o0

	b,a	skip_zero_bits

move_record:
	deccc	258,d1
	blu,a	move_record_1
	lduh	[d0-2+2],%g1
	be,a	move_record_2
	lduh	[d0-2+2],%g1

move_record_3:
	lduh	[d0-2+2],d1
	deccc	1,d1
	bgu	copy_hnf_3
	nop

	ld	[a0],a1
	blu	move_record_3_1b
	inc	4,a0

move_record_3_1a:
	cmp	a1,a0
	blu	move_record_3_1b
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bgeu	move_record_3_1b
#endif
	add	a6,1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
move_record_3_1b:
	st	a1,[a6]
	inc	4,a6

	ld	[a0],a1
	cmp	a1,a0
	blu	move_record_3_2
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bgeu	move_record_3_2
#endif
	sub	a1,d6,d0
	srl	d0,2,d0
	inc	1,d0

	tstmbit	(%o4,d0,d1,%o0,%o1,%o2)
	be	not_linked_record_argument_part_3_b
	bset	%o0,%o1

	sub	a6,d6,d0
	srl	d0,2,d0
	setmbit	(%o4,d0,d1,%o0,%o1,%o2)
	b,a	linked_record_argument_part_3_b

not_linked_record_argument_part_3_b:
	stb	%o1,[%o4+d1]

	sub	a6,d6,d0
	srl	d0,2,d0
	clrmbit	(%o4,d0,d1,%o0,%o1,%o2)

linked_record_argument_part_3_b:
	ld	[a1],d1
	add	a6,2+1,d0
	st	d0,[a1]
	mov	d1,a1
move_record_3_2:
	st	a1,[a6]
	inc	4,a6

	sub	%i2,%o4,%o0
	sll	%o0,5,%o0
	add	%o0,%l6,%o0

	cmp	%o0,d7
	be,a	bit_in_next_long
	sethi	%hi 0xc0000000,%o1

	inc	4,d7
	cmp	%o0,d7
	inc	4,d7
	bne	skip_zero_bits
	sll	d4,2,d4

	sethi	%hi 0x80000000,%o1

bit_in_next_long:
	deccc	%l5
	bneg	end_compact_heap
	nop

	ld	[%i2],d4
	ba	skip_zeros_2
	bclr	%o1,d4

move_record_2:
	cmp	%g1,1
	bgu	copy_hnf_2
	nop
	blu	move_real_or_file
	nop
move_record_2_ab:
	ld	[a0],a1
	cmp	a1,a0
	blu	move_record_2_1
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bgeu	move_record_2_1
	add	a6,1,d0
#endif
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
move_record_2_1:
	st	a1,[a6]
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[a6+4]
	ba	skip_zero_bits
	inc	8,a6

move_record_1:
	tst	%g1
	bne	copy_hnf_1
	nop
	ba	move_int_bool_or_char
	nop

move_real_array:
	tst	d4
	bneg	clear_bit_in_this_word
	sll	d4,1,d4

	ld	[a2],d4
	dec	d5
	sub	a2,%o4,d7
	inc	4,a2
	sll	d7,5,d7
	add	d7,%l6,d7

	sll	d4,1,d4
clear_bit_in_this_word:
	inc	4,d7

	add	%g6,8,d1
	andn	d1,4,d1

	ld	[a0],d0
	ba	begin_array_update_list_2
	bclr	1,d0

update_array_list_2:
	st	d1,[a1]
begin_array_update_list_2:
	mov	d0,a1
	ld	[a1],d0
update_array_list__2:
	btst	1,d0
	be	end_update_array_list_2
	bclr	1,d0
	btst	2,d0
	be	update_array_list_2
	bclr	2,d0
	mov	d0,a1
	ba	update_array_list__2
	ld	[a1],d0

end_update_array_list_2:
	st	d1,[a1]

	st	d0,[d1]
	inc	4,d1

	ld	[a0+4],d0
	inc	4,a0

	inc	16,%g6

	sll	d0,3,%o0
	sll	d0,1,d0

	add	%g6,%o0,%g6

move_real_array_reals:
	ld	[a0],%o0	!
	inc	4,a0
	st	%o0,[d1]
	inc	4,d1
	deccc	d0
	bge,a	move_real_array_reals+4
	ld	[a0],%o0

	b,a	skip_zero_bits

skip_zeros_2_a:
	ld	[a2],d4
	dec	d5
	tst	d4
	beq	skip_zeros_2_a
	inc	4,a2

end_skip_zeros_a:
	sub	%i2,%o4,d7
	dec	4,d7
	sll	d7,5,d7
	add	d7,%l6,d7

move_array:

skip_zero_bits_a:
	seth	(first_one_bit_table,%o0)	!
	srl	d4,24,%o1
	setl	(first_one_bit_table,%o0)
	ldsb	[%o0+%o1],d1
	tst	d1
	bpos,a	end_array_bit
	sll	d4,d1,d4

	tst	d4
	be	skip_zeros_2_a
	sethi	%hi 0xff000000,%o2

more_than_7_a:
	sll	d4,8,d4
	btst	d4,%o2
	beq	more_than_7_a
	inc	8<<2,d7

less_than_8_a:
	srl	d4,24,%o1
	ldsb	[%o0+%o1],d1
	sll	d4,d1,d4

end_array_bit:
	sll	d4,1,d4

	sll	d1,2,d1
	add	d7,d1,d7

	mov	d7,d1
	cmp	d7,a0
	bne	move_a_array
	inc	4,d7

move_b_array:
	ld	[a0],a1
	inc	4,a0
	st	a1,[a6]
	ld	[a0],d1
	lduh	[d1-2],d0
	tst	d0
	beq	move_strict_basic_array
	inc	4,a6
	
	sub	d0,257,d1
	mov	0,d0
mul_array_lp:
	deccc	d1
	bcc	mul_array_lp
	add	d0,a1,d0

	ba	cp_s_arg_lp3+4
	ld	[a0],%o0

move_strict_basic_array:
	set	INT+2,%o0
	cmp	d1,%o0
	beq	cp_s_arg_lp3
	mov	a1,d0

	set	BOOL+2,%o0
	cmp	d1,%o0
	beq	move_bool_array
	nop

	ba	cp_s_arg_lp3
	add	d0,d0,d0

move_bool_array:
	inc	3,d0
	ba	cp_s_arg_lp3
	srl	d0,2,d0

move_a_array:
	mov	d1,a1
	sub	d1,a0,d1
	srl	d1,2,d1
	deccc	1,d1
	blu	end_array
	nop

	ld	[a0],%o0
	ld	[a1-4],d0
	st	%o0,[a1-4]
	st	d0,[a6]
	ld	[a1],d0
	ld	[a0+4],%o0
	inc	8,a0
	st	%o0,[a1]
	st	d0,[a6+4]
	tst	d0
	be	st_move_array_lp
	inc	8,a6
	
	lduh	[d0-2+2],d3
	lduh	[d0-2],d0
	dec	256,d0

	cmp	d0,d3
	be	st_move_array_lp
	nop

move_array_ab:
	mov	d4,%o2
	mov	d5,%o3
	mov	d6,%o5

	mov	d2,%g2
	mov	a0,%g3

	ld	[a6-8],d2
	mov	d3,d1

	mov	d0,d3
	sll	d2,2,d2
	dec	2,d3
	mov	d2,a1
mul_array_length_ab2:
	deccc	d3
	bcc	mul_array_length_ab2
	add	a1,d2,a1

	sub	d0,d1,d0
	call	reorder
	add	a1,a0,a1

	ld	[a6-8],d3
	mov	%g3,a0
	mov	%g2,d2
	dec	1,d1
	ba	st_move_array_lp_ab
	dec	1,d0

move_array_ab_lp1:
	mov	d1,d4	!
move_array_ab_a_elements:
	ld	[a0],d5
	inc	4,a0
	cmp	d5,a0
	blu,a	move_array_element_ab+4
	st	d5,[a6]
#ifdef SHARE_CHAR_INT
	cmp	d5,d2
	bgeu,a	move_array_element_ab+4
	st	d5,[a6]
#endif
	mov	d5,a1
	mov	1,d6
	ld	[a1],d5
	add	d6,a6,d6
	st	d6,[a1]
move_array_element_ab:
	st	d5,[a6]	!
	deccc	d4
	bcc	move_array_ab_a_elements
	inc	4,a6

	mov	d0,d4
move_array_ab_b_elements:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[a6]
	deccc	d4
	bcc	move_array_ab_b_elements
	inc	4,a6
st_move_array_lp_ab:
	deccc	d3
	bcc,a	move_array_ab_lp1+4
	mov	d1,d4	!

end_array_ab:
	mov	%o5,d6
	mov	%o3,d5
	ba	end_array	
	mov	%o2,d4

move_array_lp1:
	ld	[a0],d0	!
	inc	4,a0
	cmp	d0,a0
	blu	move_array_element
	inc	4,a6
#ifdef SHARE_CHAR_INT
 	cmp	d0,d2
	bgeu,a	move_array_element+4
	st	d0,[a6-4]
#endif
	ld	[d0],%o0
	mov	d0,a1
	st	%o0,[a6-4]
	add	a6,-4+1,d0
	st	d0,[a1]

	deccc	d1
	bcc,a	move_array_lp1+4
	ld	[a0],d0

	b,a	end_array

move_array_element:
	st	d0,[a6-4]	!
st_move_array_lp:
	deccc	d1
	bcc,a	move_array_lp1+4
	ld	[a0],d0
end_array:
	b,a	skip_zero_bits

move_lazy_node:
	mov	d0,a1
	ldsh	[d0-2],d1

	tst	d1
	be	move_lazy_node_0

	deccc	d1
	ble	move_lazy_node_1

	cmp	d1,256
	bgeu,a	move_closure_with_unboxed_arguments
	inc	d1	

copy_lazy_node_arguments:
	ld	[a0],a1
	cmp	a1,a0
	bcs	copy_lazy_node_arguments_
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	copy_lazy_node_arguments__
	inc	4,%g6
#endif
	ld	[a1],%o0
	st	%o0,[%g6-4]
	add	%g6,1-4,d0
	deccc	d1
	bpos	copy_lazy_node_arguments
	st	d0,[a1]

	b,a	skip_zero_bits

copy_lazy_node_arguments_:
	inc	4,%g6
copy_lazy_node_arguments__:
	deccc	d1
	bpos	copy_lazy_node_arguments
	st	a1,[%g6-4]
	
	b,a	skip_zero_bits

move_lazy_node_1:
	ld	[a0],a1
	cmp	a1,a0
	bcs	move_lazy_node_1_
	inc	4,a0
#ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	move_lazy_node_1_
#endif
	add	%g6,1,d0
	ld	[a1],d1
	st	d0,[a1]
	mov	d1,a1
move_lazy_node_1_:
	st	a1,[%g6]
	ba	skip_zero_bits
	inc	8,%g6

move_lazy_node_0:
	ba	skip_zero_bits
	inc	8,a6

move_closure_with_unboxed_arguments:
!	inc	d1
	srl	d1,8,d0
	beq	move_closure_with_unboxed_arguments_1
	and	d1,255,d1

	subcc	d1,d0,d1
	beq	copy_non_pointers_of_closure
	nop

move_pointers_in_closure:
	ld	[a0],a1
	cmp	a1,a0
	bcs	move_pointers_in_closure_
	inc	4,a0
# ifdef SHARE_CHAR_INT
	cmp	a1,d2
	bcc	move_pointers_in_closure_
# endif
	add	a6,1,%o1
	ld	[a1],%o0
	st	%o1,[a1]
	mov	%o0,a1

move_pointers_in_closure_:
	deccc	d1
	inc	4,a6
	bne	move_pointers_in_closure
	st	a1,[a6-4]

copy_non_pointers_of_closure:
	deccc	d0

	ld	[a0],d1
	inc	4,a0

	inc	4,a6
	bne	copy_non_pointers_of_closure
	st	d1,[a6-4]

	b,a	skip_zero_bits

move_closure_with_unboxed_arguments_1:
	ld	[a0],d0
	inc	8,a6
	b	skip_zero_bits	
	st	d0,[a6-8]

end_compact_heap:

#ifdef FINALIZERS
	ldg	(finalizer_list,a0)

restore_finalizer_descriptors:
	set	__Nil-8,%o0
	cmp	%o0,a0
	beq	end_restore_finalizer_descriptors
	nop

	set	e____system__kFinalizer+2,%o0
	st	%o0,[a0]
	ba	restore_finalizer_descriptors
	ld	[a0+4],a0

end_restore_finalizer_descriptors:
#endif
