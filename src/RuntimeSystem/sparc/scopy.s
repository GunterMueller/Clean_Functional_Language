
	ldg	(heap_p2,a6)
	ldg	(heap_size_129,d7)
	sll	d7,6,d7
	add	a6,d7,%o4

	set	INT+2,d3
	set	CHAR+2,d4

	ldg	(caf_list,d0)
	tst	d0
	beq	end_copy_cafs
	nop

#ifdef SP_G5
	dec	4,sp
#endif

copy_cafs_lp:
#ifdef SP_G5
	ld	[d0-4],%g1
#else
	ld	[d0-4],%g5
#endif
	add	d0,4,a2
	ld	[d0],d5
#ifdef SP_G5
	st	%g1,[sp]
#endif	
	call	copy_lp2
	dec	d5

#ifdef SP_G5
	ld	[sp],d0
	addcc	d0,0,d0
#else
	addcc	%g5,0,d0
#endif	
	bne	copy_cafs_lp
	nop

#ifdef SP_G5
	inc	4,sp
#endif

end_copy_cafs:

	ldg	(stack_p,a2)

	sub	a4,a2,d5
	deccc	4,d5
	blu	no_call_copy_lp2
	srl	d5,2,d5

	call	copy_lp2+4
	ld	[a2],a1

no_call_copy_lp2:
	ldg	(heap_p2,a2)


!
!	Copy all referenced nodes to the other semi space
!

st_copy_lp1:
	set	copy_lp1-8,%o7
copy_lp1:
	cmp	a2,a6
	bcc	end_copy1
	nop

	ld	[a2],d0
	btst	2,d0
	be	not_in_hnf_1
	inc	4,a2

in_hnf_1:
	lduh	[d0-2],d5

	tst	d5
	be	copy_array_21
	cmp	d5,2
	bleu,a	copy_lp2
	dec	d5

	cmp	d5,256
	bgeu	copy_record_21
	nop
	
	ld	[%i2+4],%o0
	btst	1,%o0
	bne	node_without_arguments_part
	mov	d5,d6

in_hnf_1_c:
	call	copy_lp2
	mov	0,d5

	inc	4,a2
	sub	d6,2,d5

	ba	copy_lp2
	inc	copy_lp1-8-in_hnf_1_c,%o7

node_without_arguments_part:
	bclr	1,%o0
	st	%o0,[%i2+4]
node_without_arguments_part_c:
	call	copy_lp2
	clr	d5
	inc	4,a2
	ba	copy_lp1
	inc	copy_lp1-8-node_without_arguments_part_c,%o7

copy_record_21:
	deccc	258,d5
	bgu	copy_record_arguments_3
	nop

	blu	copy_record_arguments_1
	lduh	[d0-2+2],d5

	deccc	1,d5
	bgu,a	copy_lp2+4
	ld	[a2],a1

#if 1
	ba,a	copy_node_arity1
#else
	be	copy_node_arity1
	nop
	ba	copy_lp1
	inc	8,a2
#endif

copy_record_arguments_1:
#if 1
	ba	copy_lp2
	mov	0,d5
#else
	tst	d5
	bne	copy_lp2
	mov	0,d5
	ba	copy_lp1
	inc	4,a2
#endif

copy_record_arguments_3:
	ld	[a2+4],%o1
	btst	1,%o1
	bne	record_node_without_arguments_part

	lduh	[d0-2+2],d1
#if 1
	inc	2+1,d5
	dec	1,d1
#else
	tst	d1
	be	copy_record_arguments_3b
	inc	2+1,d5

	deccc	1,d1
	be,a	copy_record_arguments_3abb
	dec	1,d5
#endif

	sll	d5,2,d5
	add	a2,d5,%o1
	dec	4,sp
	st	%o1,[sp]
	mov	d1,d6
	call	copy_lp2
	mov	0,d5
	
	inc	4,a2
copy_record_arguments_3_c:
	call	copy_lp2
	sub	d6,1,d5

	ld	[sp],a2
	inc	4,sp
	ba	copy_lp1
	inc	copy_lp1-8-copy_record_arguments_3_c,%o7

#if 0
copy_record_arguments_3abb:
	sll	d5,2,d6
copy_record_arguments_3abb_c:
	call	copy_lp2	
	mov	0,d5

	add	a2,d6,a2
	ba	copy_lp1
	inc	copy_lp1-8-copy_record_arguments_3abb_c,%o7

copy_record_arguments_3b:
	sll	d5,2,d5
	ba	copy_lp1
	add	a2,d5,a2
#endif

record_node_without_arguments_part:
	bclr	1,%o1
	st	%o1,[a2+4]
	tst	d1
	be,a	copy_lp1
	inc	8,a2
record_node_without_arguments_part_c:
	call	copy_lp2
	clr	d5
	
	inc	4,a2
	ba	copy_lp1
	inc	copy_lp1-8-record_node_without_arguments_part_c,%o7

not_in_hnf_1:
	ld	[d0-4],d5

	cmp	d5,257
	bge,a	copy_unboxed_closure_arguments
	srl	d5,8,d6

	deccc	d5
	bg,a	copy_lp2+4
	ld	[a2],a1

copy_node_arity1:
	call	copy_lp2
	clr	%l5

	inc	4,a2
	ba	copy_lp1
	inc	copy_lp1-8-copy_node_arity1,%o7

copy_unboxed_closure_arguments:
!	srl	d5,8,d6
	be	copy_unboxed_closure_arguments1
	andcc	d5,255,d5

	subcc	d5,d6,d5
	be	no_pointers_in_unboxed_closure
	sll	d6,2,d6

copy_unboxed_closure_arguments_c:
	call	copy_lp2
	dec	d5

	add	a2,d6,a2
	ba	copy_lp1
	inc	copy_lp1-8-copy_unboxed_closure_arguments_c,%o7	

no_pointers_in_unboxed_closure:
	ba	copy_lp1
	add	a2,d6,a2

copy_unboxed_closure_arguments1:
	ba	copy_lp1
	inc	8,a2

copy_array_21:
	ld	[a2+4],d1
	ld	[a2],d5
	inc	8,a2
	tst	d1
	be,a	copy_array_21_a
	deccc	1,d5

	lduh	[d1-2],d0
	lduh	[d1-2+2],d1
	dec	256,d0
	tst	d1
	be	copy_array_21_b
	cmp	d0,d1
	be	copy_array_21_r_a
	nop

copy_array_21_ab:
	deccc	1,d5
	bcs,a	copy_lp1
	cmp	a2,a6

	sub	d0,d1,d0
	sll	d0,2,d0
	dec	1,d1

	mov	d5,d6
	st	d1,[sp-4]
	st	d0,[sp-8]
	dec	8,sp
copy_array_21_lp_ab:
	call	copy_lp2
	ld	[sp+4],d5

	ld	[sp],%o1
	deccc	d6
	bcc	copy_array_21_lp_ab
	add	a2,%o1,a2
	
	inc	8,sp
	ba	copy_lp1
	inc	copy_lp1-8-copy_array_21_lp_ab,%o7

copy_array_21_b:
	dec	1,d0
	mov	0,d2
mul_array_length_lp_1:
	deccc	d0
	bcc	mul_array_length_lp_1
	add	d2,d5,d2

	sll	d2,2,d2	
	ba	copy_lp1
	add	a2,d2,a2

copy_array_21_r_a:
	dec	1,d0
	mov	0,d2
mul_array_length_lp_2:
	deccc	d0
	bcc	mul_array_length_lp_2
	add	d2,d5,d2

	subcc	d2,1,d5
copy_array_21_a:
	bcc,a	copy_lp2+4
	ld	[a2],a1
		
	ba,a	copy_lp1

!
!	Copy root nodes to the other semi-space
!

copy_lp2:
	ld	[a2],a1	!

continue_after_selector_2:
	ld	[a1],d0
	btst	2,d0
	bne	in_hnf_2
	btst	1,d0
	bne	already_copied_2
	bclr	1,d0

	ldsb	[d0-1],d2
	tst	d2
	be	copy_arity_0_node2_
	mov	d0,a0

copy_node2_1_:
	deccc	2,d2
	bl	copy_arity_1_node2
	nop

copy_node2_3:
	st	%g6,[%i2]
	inc	4,%i2
	st	d0,[%g6]
	or	%g6,1,a0
	st	a0,[a1]
	ld	[a1+4],%o0
	inc	8,a1
	st	%o0,[%g6+4]
	inc	8,%g6

cp_arg_lp2:
	ld	[a1],%o0
	inc	4,a1
	st	%o0,[%g6]
	deccc	d2
	bpos	cp_arg_lp2
	inc	4,%g6
	
	deccc	d5
	bpos,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

copy_arity_1_node2:
	bcc	copy_selector_2
	nop

copy_arity_1_node2_:
	st	%g6,[%i2]
	or	%g6,1,a0
	st	a0,[a1]
	ld	[a1+4],%o0
	st	d0,[%g6]
	inc	4,a2
	st	%o0,[%g6+4]

	deccc	d5
	bpos	copy_lp2
	inc	12,%g6

	retl
	nop

copy_indirection_2:
	mov	a1,d1
	ld	[a1+4],a1
	
	ld	[a1],d0

	btst	2,d0
	bne	in_hnf_2

	btst	1,d0
	bne	already_copied_2
	bclr	1,d0

	ldsb	[d0-1],d2
	tst	d2
	be	copy_arity_0_node2_
	mov	d0,a0

	cmp	d2,-2
	bne	copy_node2_1_
	nop

skip_indirections_2:
	ld	[a1+4],a1
	ld	[a1],d0

	btst	2,d0
	bne	update_indirection_list_2

	btst	1,d0
	bne	update_indirection_list_2
	bclr	1,d0

	ld	[d0-4],%o0
	cmp	%o0,-2
	be	skip_indirections_2
	mov	d0,a0

update_indirection_list_2:
	add	d1,4,a0
	ld	[a0],d1
	st	a1,[a0]
	cmp	a1,d1
	bne	update_indirection_list_2
	nop

	ba,a	continue_after_selector_2

copy_selector_2:
	inccc	4,d2
	be	copy_indirection_2
	nop
	bl,a	copy_record_selector_2
	inccc	1,d2

	ld	[a0-8],d2

 	ld	[a1+4],a0
	ld	[a0],d1
 	btst	2,d1
	be	copy_arity_1_node2_
	nop

	ldsh	[d1-2],%g1
	cmp	%g1,2
	bleu	copy_selector_2_
	nop

#ifndef NEW_DESCRIPTORS
copy_selector_2__:
#endif
#if 1
	ld	[a0+8],d1
	ld	[d1],%g1
#else
	ld	[a0+8],%g1
	ld	[%g1],%g1
#endif

	btst	1,%g1
	bne	copy_arity_1_node2_
	nop

#ifdef NEW_DESCRIPTORS
	lduh	[d2+4],d2
	set	__indirection,%g1
	st	%g1,[a1]

	cmp	d2,8
	blu,a	copy_selector_2_1
	ld	[a0+4],a0
	beq,a	copy_selector_2_2
	ld	[d1],a0

	sub	d1,12,d1
	ld	[d1+d2],a0
copy_selector_2_1:
copy_selector_2_2:
	st	a0,[a1+4]
	ld	[a0],d0
	ba	continue_after_selector_2
	mov	a0,a1

copy_selector_2_:
	lduh	[d2+4],d2
	set	__indirection,%g1
	st	%g1,[a1]

	ld	[a0+d2],a0
	st	a0,[a1+4]
	ld	[a0],d0
	ba	continue_after_selector_2
	mov	a0,a1
#else
copy_selector_2_:
#endif
	ld	[d2+4],%g1
	mov	a1,d2

	mov	%o7,%o5

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	mov	%o5,%o7

	st	a0,[d2+4]
	set	__indirection,%g1
	st	%g1,[d2]

	ba	continue_after_selector_2
	mov	a0,a1

copy_record_selector_2:
	beq	copy_strict_record_selector_2
	ld	[a0-8],d2

 	ld	[a1+4],a0
 	ld	[a0],d1
	btst	2,d1
	be	copy_arity_1_node2_
	nop

	ldsh	[d1-2],%g1
	cmp	%g1,258
#ifdef NEW_DESCRIPTORS
	bleu	copy_record_selector_2_
#else
	bleu	copy_selector_2_
#endif
	nop

#if 1
	lduh	[d1-2+2],%g1
	cmp	%g1,2
	bgeu	copy_selector_2__
	nop

	ld	[a0+8],d1
	ldg	(heap_p1,%o1)
	ldg	(heap_copied_vector,%g1)
	sub	d1,%o1,%o3
	srl	%o3,2+1,%o3

	tst_bit	(%g1,%o3,%o2,%o0,%o1)
#else
	ld	[a0+8],%o3
	ldg	(heap_p1,%o1)
	ldg	(heap_copied_vector,%g1)
	sub	%o3,%o1,%o3
	srl	%o3,2+1,%o3

	tstmbit	(%g1,%o3,d1,%o0,%o1,%o2)
#endif

#ifdef NEW_DESCRIPTORS
# if 1
 	beq	copy_record_selector_2_
 	nop
	ba,a	copy_arity_1_node2_

copy_selector_2__:
	ld	[a0+8],d1
	ld	[d1],%g1
	btst	1,%g1
	bne	copy_arity_1_node2_
	nop
# else
	bne	copy_arity_1_node2_
	nop
# endif
copy_record_selector_2_:
	lduh	[d2+4],d2
	set	__indirection,%g1
	st	%g1,[a1]
	
	cmp	d2,8
	bleu,a	copy_record_selector_3
	ld	[a0+d2],a0

	sub	d2,12,d2
	ld	[d1+d2],a0
copy_record_selector_3:
	st	a0,[a1+4]
	ld	[a0],d0
	ba	continue_after_selector_2
	mov	a0,a1
#else
	bne	copy_arity_1_node2_
	nop

 	ba,a	copy_selector_2_
#endif

copy_strict_record_selector_2:
 	ld	[a1+4],a0
	ld	[a0],d1
	btst	2,d1
	be	copy_arity_1_node2_
	nop

	ldsh	[d1-2],%g1
	cmp	%g1,258
	bleu	copy_strict_record_selector_2_
	nop

#if 1
	lduh	[d1-2+2],%g1
	cmp	%g1,2
	bltu	copy_strict_record_selector_2_b
	nop

	ld	[a0+8],d1
	ld	[d1],%g1
	btst	1,%g1
	bne	copy_arity_1_node2_
	nop
	ba,a	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
#endif

#if 1
	ld	[a0+8],d1
	ldg	(heap_p1,%o1)
	ldg	(heap_copied_vector,%g1)
	sub	d1,%o1,%o3
	srl	%o3,2+1,%o3

	tst_bit	(%g1,%o3,%o2,%o0,%o1)
#else
	ld	[a0+8],%o3
	ldg	(heap_p1,%o1)
	ldg	(heap_copied_vector,%g1)
	sub	%o3,%o1,%o3
	srl	%o3,2+1,%o3

	tstmbit	(%g1,%o3,d1,%o0,%o1,%o2)
#endif
	bne	copy_arity_1_node2_
	nop

copy_strict_record_selector_2_:
#ifdef NEW_DESCRIPTORS
	lduh	[d2+4],d0
	cmp	d0,8
	bleu,a	copy_strict_record_selector_3
	ld	[a0+d0],d0

	sub	d0,12,d0
	ld	[d1+d0],d0
copy_strict_record_selector_3:
copy_strict_record_selector_4:
	st	d0,[a1+4]

	lduh	[d2+6],d0
	cmp	d0,0
	beq	copy_strict_record_selector_6
	cmp	d0,8
	bleu,a	copy_strict_record_selector_5
	ld	[a0+d0],d0

	sub	d0,12,d0
	ld	[d1+d0],d0
copy_strict_record_selector_5:
	st	d0,[a1+8]
copy_strict_record_selector_6:
	ld	[d2-4],d0
	ba	in_hnf_2
	st	d0,[a1]
#else
	ld	[d2+4],%g1

	mov	a1,d0
	mov	a0,a1
	mov	d0,a0

	mov	%o7,%o5

	dec	4,sp
	call	%g1
	st	%o7,[sp]

	mov	%o5,%o7

	mov	a0,a1
	ba	in_hnf_2
	ld	[a1],d0
#endif

copy_arity_0_node2_:	
	st	d0,[%o4-12]
	dec	12,%o4
	st	%o4,[%i2]
	or	%o4,1,d2
	st	d2,[a1]
	inc	4,%i2

	deccc	%l5
	bpos,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

in_hnf_2:	lduh	[d0-2],d2
	tst	d2
	beq	copy_arity_0_node2

	cmp	d2,256
	bgeu	copy_record_2
	deccc	2,d2
	
	bgu	copy_hnf_node2_3
	st	a6,[a2]
		
	bcs	copy_hnf_node2_1
	or	a6,1,a0

	st	d0,[a6]
	ld	[a1+4],%o0
	st	a0,[a1]
	ld	[a1+8],%o1
	st	%o0,[a6+4]
	inc	4,a2
	st	%o1,[a6+8]
	inc	12,a6

	deccc	d5
	bpos,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

copy_hnf_node2_1:
	st	d0,[%g6]
	inc	4,%i2
	st	a0,[a1]
	ld	[a1+4],%o0
	st	%o0,[%g6+4]
	inc	8,%g6

	deccc	d5
	bpos,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

copy_hnf_node2_3:
	inc	4,a2
	st	d0,[a6]
	or	a6,1,d1
	st	d1,[a1]
	ld	[a1+4],%o0
	st	%o0,[a6+4]

	ld	[a1+8],a0
	ld	[a0],d1
	btst	1,d1
	bne	arguments_already_copied_2
	inc	12,a6

	st	a6,[a6-4]
	or	a6,1,a1
	st	d1,[a6]
	inc	4,a6
	st	a1,[a0]
	inc	4,a0

cp_hnf_arg_lp2:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[a6]
	deccc	d2
	bg	cp_hnf_arg_lp2
	inc	4,a6

	deccc	d5
	bpos,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

arguments_already_copied_2:
	deccc	%l5
	bpos	copy_lp2
	st	d1,[%g6-4]

	retl
	nop
	
copy_arity_0_node2:
	cmp	d0,d3
	blu	copy_real_file_or_string_2

	cmp	d0,d4
	bgu	copy_normal_hnf_0_2
	nop

copy_int_bool_or_char_2:
#ifdef SHARE_CHAR_INT
	bne	no_char_2
	cmp	d3,d0
	
	ldub	[a1+7],d2
	set	static_characters,a0
	sll	d2,3,d2
	add	a0,d2,a0
	st	a0,[%i2]

	deccc	%l5
	bpos	copy_lp2
	inc	4,%i2
	
	retl
	nop

no_char_2:
	bne	no_small_int_or_char_2
	ld	[a1+4],%o0

	cmp	%o0,33
	bcc	no_small_int_or_char_2
	sll	%o0,3,d2

	set	small_integers,a0
	add	a0,d2,a0
	st	a0,[%i2]

	deccc	%l5
	bpos	copy_lp2
	inc	4,%i2

	retl
	nop
	
no_small_int_or_char_2:
#else
no_small_int_or_char_2:
	ld	[a1+4],%o0
#endif
	st	d0,[%o4-8]
	dec	8,%o4
	st	%o0,[%o4+4]
	or	%o4,1,d2
	st	%o4,[%i2]
	inc	4,%i2

	deccc	%l5
	bpos	copy_lp2
	st	d2,[a1]

	retl
	nop

copy_normal_hnf_0_2:
	sub	d0,2-ZERO_ARITY_DESCRIPTOR_OFFSET,a0
	st	a0,[%i2]

	deccc	%l5
	bpos	copy_lp2
	inc	4,%i2

	retl
	nop

copy_real_file_or_string_2:
	set	__STRING__+2,%o0
	cmp	d0,%o0
	bleu	copy_string_or_array_2
	nop

copy_real_or_file_2:
	st	d0,[%o4-12]
	ld	[a1+4],%o0
	add	%o4,1-12,d2
	st	d2,[a1]
	ld	[a1+8],%o1
	st	%o0,[%o4-8]
	inc	4,a2
	st	%o1,[%o4-4]
	dec	12,%o4

	deccc	d5
	bge	copy_lp2
	st	%o4,[a2-4]

	retl
	nop

already_copied_2:
	st	d0,[a2]
	deccc	d5
	bpos	copy_lp2
	inc	4,a2

	retl
	nop

copy_string_or_array_2:
	bne	copy_array_2
	mov	a1,a0

	ldg	(heap_p1,d1)
	sub	a1,d1,d1
	cmp	d1,d7
	bcc	copy_string_constant
	inc	4,a2

	ld	[a0+4],d2

	ld	[a0],%o0
	inc	3,d2

	srl	d2,2,d2

	sll	d2,2,d1
	sub	%o4,8,a1
	sub	a1,d1,a1

	st	a1,[a2-4]
	add	a1,1,d0

	mov	a1,%o4
	inc	4,a1	
	st	%o0,[a1-4]
	st	d0,[a0]
	inc	4,a0

cp_s_arg_lp2:
	ld	[a0],%o0	
	inc	4,a0
	st	%o0,[a1]
	inc	4,a1
	deccc	d2
	bge,a	cp_s_arg_lp2+4
	ld	[a0],%o0	

	deccc	d5
	bge,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

copy_string_constant:
	deccc	d5
	bge	copy_lp2
	st	a1,[a2-4]

	retl
	nop

copy_array_2:
	ld	[a0+8],d0
	tst	d0
	be	copy_array_a2
	ld	[a0+4],d2

	lduh	[d0-2],d1
	tst	d1
	be	copy_strict_basic_array_2
	nop

	sub	d1,257,d0
	mov	d2,d1
	mov	0,d2
mul_length_2:
	deccc	d0
	bcc	mul_length_2
	add	d2,d1,d2

copy_array_a2:
	mov	a6,a1
	sll	d2,2,d1
	add	a6,d1,a6
	inc	12,a6

	st	a1,[a2]
	inc	4,a2
	add	a1,1,d0

	ld	[a0],%o0
	inc	4,a1
	st	%o0,[a1-4]
	st	d0,[a0]
	inc	4,a0

	ba	cp_s_arg_lp2
	inc	1,d2	

copy_strict_basic_array_2:
	cmp	d0,d3
	beq	copy_int_array_2
	nop

	set	BOOL+2,%o0
	cmp	d0,%o0
	beq,a	copy_bool_array_2
	inc	3,d2

	add	d2,d2,d2
copy_int_array_2:
	sll	d2,2,d1
	sub	%o4,12,a1
	sub	a1,d1,a1

	st	a1,[a2]
	inc	4,a2
	add	a1,1,d0

	ld	[a0],%o0
	mov	a1,%o4
	inc	4,a1	
	st	%o0,[a1-4]
	st	d0,[a0]
	inc	4,a0

	ba	cp_s_arg_lp2
	inc	d2

copy_bool_array_2:
	ba	copy_int_array_2
	srl	d2,2,d2

copy_record_2:
	deccc	258-2,d2
	bgu	copy_record_node2_3
	lduh	[d0-2+2],%o0

	bcs	copy_record_node2_1
	cmp	%o0,0

	beq	copy_real_or_file_2
	nop

	st	a6,[a2]
	st	d0,[a6]
	add	a6,1,a0
	st	a0,[a1]
	ld	[a1+4],%o1
	inc	4,a2
	st	%o1,[a6+4]
	ld	[a1+8],%o1
	st	%o1,[a6+8]
	
	deccc	d5
	bge	copy_lp2
	inc	12,a6

	retl
	nop

copy_record_node2_1:
	beq	copy_record_node2_1_b
	ld	[a1+4],%o0

	st	a6,[a2]
	st	d0,[a6]
	add	a6,1,a0
	st	a0,[a1]
	inc	4,a2
	st	%o0,[a6+4]

	deccc	d5
	bge	copy_lp2
	inc	8,a6

	retl
	nop

copy_record_node2_1_b:
	st	d0,[%o4-8]
	add	%o4,1-8,d2
	st	d2,[a1]
	inc	4,a2
	st	%o0,[%o4-4]
	dec	8,%o4

	deccc	d5
	bge	copy_lp2
	st	%o4,[a2-4]

	retl
	nop

copy_record_node2_3:
	cmp	%o0,1
	bleu	copy_record_node2_3_ab_or_b
	ld	[a1+4],%o1

	st	a6,[a2]
	st	d0,[a6]
	add	a6,1,d1
	st	d1,[a1]
	inc	4,a2
	st	%o1,[a6+4]
	ld	[a1+8],a0

#if 1
	ld	[a0],%o1
	btst	1,%o1
	bne	record_arguments_already_copied_2
	nop
#else
	ldg	(heap_copied_vector,a1)
	ldg	(heap_p1,%o1)
	sub	a0,%o1,d0
	srl	d0,2+1,d0
	tstmbit	(a1,d0,d1,%o0,%o1,%o2)
	bne	record_arguments_already_copied_2
	bset	%o0,%o1

	stb	%o1,[a1+d1]
#endif
	add	a6,12,a1
	st	a1,[a6+8]
#if 0
	ld	[a0],%o1
#endif
	inc	1,a1
	st	a1,[a0]
	inc	4,a0
	st	%o1,[a6+12]
	inc	16,a6
	dec	1,d2
	ld	[a0],%o1
cp_record_arg_lp2:
	inc	4,a0
	st	%o1,[a6]
	inc	4,a6
	deccc	1,d2
	bcc,a	cp_record_arg_lp2
	ld	[a0],%o1

	deccc	d5
	bge,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

copy_record_node2_3_ab_or_b:
	bltu	copy_record_node2_3_b
	nop

copy_record_node2_3_ab:
	st	a6,[a2]
	st	d0,[a6]
	add	a6,1,d1
	st	d1,[a1]
	inc	4,a2
	st	%o1,[a6+4]
	ld	[a1+8],a0

	ldg	(heap_copied_vector,a1)
	ldg	(heap_p1,%o1)
	sub	a0,%o1,d0
	srl	d0,2+1,d0
	tstmbit	(a1,d0,d1,%o0,%o1,%o2)
	bne	record_arguments_already_copied_2
	bset	%o0,%o1

	sll	d2,2,%o0

	stb	%o1,[a1+d1]

	sub	%o4,%o0,a1
	sub	a1,3,%o0
	sub	a1,4,a1

	st	%o0,[a6+8]
	ba	cp_record_arg_lp3_c
	inc	12,a6

copy_record_node2_3_b:
	dec	12,%o4
	st	%o4,[a2]
	st	d0,[%o4]
	add	%o4,1,d1
	st	d1,[a1]
	inc	4,a2
	st	%o1,[%o4+4]
	ld	[a1+8],a0

	ldg	(heap_copied_vector,a1)
	ldg	(heap_p1,%o1)
	sub	a0,%o1,d0
	srl	d0,2+1,d0
	tstmbit	(a1,d0,d1,%o0,%o1,%o2)
	bne	record_arguments_already_copied_3
	bset	%o0,%o1

	sll	d2,2,%o0

	stb	%o1,[a1+d1]

	sub	%o4,%o0,a1
	sub	a1,3,%o0
	sub	a1,4,a1

	st	a1,[%o4+8]
	add	a1,1,%o0

cp_record_arg_lp3_c:

	ld	[a0],%o1
	st	%o0,[a0]

	inc	4,a0
	st	%o1,[a1]
	mov	a1,%o4

	ld	[a0],%o1

cp_record_arg_lp3:
	inc	4,a0
	st	%o1,[a1+4]
	inc	4,a1
	deccc	1,d2
	bne,a	cp_record_arg_lp3
	ld	[a0],%o1

	deccc	d5
	bge,a	copy_lp2+4
	ld	[a2],a1

	retl
	nop

record_arguments_already_copied_3:
	ld	[a0],%o0
	dec	1,%o0

	deccc	d5
	bge	copy_lp2
	st	%o0,[%o4+8]

	retl
	nop

record_arguments_already_copied_2:
	ld	[a0],%o0
	inc	12,a6

	deccc	d5
	bge	copy_lp2
	st	%o0,[a6-4]

	retl
	nop

end_copy1:

#ifdef FINALIZERS
	set	finalizer_list,a0
	set	free_finalizer_list,a1
	ld	[a0],a2

determine_free_finalizers_after_copy:
	ld	[a2],d0
	btst	1,d0
	beq	finalizer_not_used_after_copy
	nop

	ld	[a2+4],a2
	dec	d0
	st	d0,[a0]
	ba	determine_free_finalizers_after_copy
	add	d0,4,a0

finalizer_not_used_after_copy:
	set	__Nil-8,%o0
	cmp	a2,%o0
	beq	end_finalizers_after_copy
	nop

	st	a2,[a1]
	add	a2,4,a1
	ba	determine_free_finalizers_after_copy	
	ld	[a2+4],a2

end_finalizers_after_copy:
	st	a2,[a0]
	st	a2,[a1]
#endif
