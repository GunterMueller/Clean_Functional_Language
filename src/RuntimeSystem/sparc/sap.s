
	.text

	.global	ap_2
	.global	ap_3
	.global	ap_4
	.global	ap_5
	.global	ap_6
	.global	ap_7
	.global	ap_8
	.global	ap_9
	.global	ap_10
	.global	ap_11
	.global	ap_12
	.global	ap_13
	.global	ap_14
	.global	ap_15
	.global	ap_16
	.global	ap_17
	.global	ap_18
	.global	ap_19
	.global	ap_20
	.global	ap_21
	.global	ap_22
	.global	ap_23
	.global	ap_24
	.global	ap_25
	.global	ap_26
	.global	ap_27
	.global	ap_28
	.global	ap_29
	.global	ap_30
	.global	ap_31
	.global	ap_32

	.global	add_empty_node_2
	.global	add_empty_node_3
	.global	add_empty_node_4
	.global	add_empty_node_5
	.global	add_empty_node_6
	.global	add_empty_node_7
	.global	add_empty_node_8
	.global	add_empty_node_9
	.global	add_empty_node_10
	.global	add_empty_node_11
	.global	add_empty_node_12
	.global	add_empty_node_13
	.global	add_empty_node_14
	.global	add_empty_node_15
	.global	add_empty_node_16
	.global	add_empty_node_17
	.global	add_empty_node_18
	.global	add_empty_node_19
	.global	add_empty_node_20
	.global	add_empty_node_21
	.global	add_empty_node_22
	.global	add_empty_node_23
	.global	add_empty_node_24
	.global	add_empty_node_25
	.global	add_empty_node_26
	.global	add_empty_node_27
	.global	add_empty_node_28
	.global	add_empty_node_29
	.global	add_empty_node_30
	.global	add_empty_node_31
	.global	add_empty_node_32

	.global	yet_args_needed_5
	.global	yet_args_needed_6
	.global	yet_args_needed_7
	.global	yet_args_needed_8
	.global	yet_args_needed_9
	.global	yet_args_needed_10
	.global	yet_args_needed_11
	.global	yet_args_needed_12
	.global	yet_args_needed_13
	.global	yet_args_needed_14
	.global	yet_args_needed_15
	.global	yet_args_needed_16
	.global	yet_args_needed_17
	.global	yet_args_needed_18
	.global	yet_args_needed_19
	.global	yet_args_needed_20
	.global	yet_args_needed_21
	.global	yet_args_needed_22
	.global	yet_args_needed_23
	.global	yet_args_needed_24
	.global	yet_args_needed_25
	.global	yet_args_needed_26
	.global	yet_args_needed_27
	.global	yet_args_needed_28
	.global	yet_args_needed_29
	.global	yet_args_needed_30
	.global	yet_args_needed_31

ap_32:
	ld	[a2],a3
	set	32*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap32
	inc	4,a4

ap_31:
	ld	[a2],a3
	set	31*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap31
	inc	4,a4

ap_30:
	ld	[a2],a3
	set	30*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap30
	inc	4,a4

ap_29:
	ld	[a2],a3
	set	29*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap29
	inc	4,a4

ap_28:
	ld	[a2],a3
	set	28*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap28
	inc	4,a4

ap_27:
	ld	[a2],a3
	set	27*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap27
	inc	4,a4

ap_26:
	ld	[a2],a3
	set	26*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap26
	inc	4,a4

ap_25:
	ld	[a2],a3
	set	25*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap25
	inc	4,a4

ap_24:
	ld	[a2],a3
	set	24*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap24
	inc	4,a4

ap_23:
	ld	[a2],a3
	set	23*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap23
	inc	4,a4

ap_22:
	ld	[a2],a3
	set	22*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap22
	inc	4,a4

ap_21:
	ld	[a2],a3
	set	21*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap21
	inc	4,a4

ap_20:
	ld	[a2],a3
	set	20*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap20
	inc	4,a4

ap_19:
	ld	[a2],a3
	set	19*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap19
	inc	4,a4

ap_18:
	ld	[a2],a3
	set	18*8,d1
	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap18
	inc	4,a4

ap_17:
	ld	[a2],a3
	set	17*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap17
	inc	4,a4

ap_16:
	ld	[a2],a3
	set	16*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap16
	inc	4,a4

ap_15:
	ld	[a2],a3
	set	15*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap15
	inc	4,a4

ap_14:
	ld	[a2],a3
	set	14*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap14
	inc	4,a4

ap_13:
	ld	[a2],a3
	set	13*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap13
	inc	4,a4

ap_12:
	ld	[a2],a3
	set	12*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap12
	inc	4,a4

ap_11:
	ld	[a2],a3
	set	11*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap11
	inc	4,a4

ap_10:
	ld	[a2],a3
	set	10*80,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap10
	inc	4,a4

ap_9:
	ld	[a2],a3
	set	9*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap9
	inc	4,a4

ap_8:
	ld	[a2],a3
	set	8*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap8
	inc	4,a4

ap_7:
	ld	[a2],a3
	set	7*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap7
	inc	4,a4

ap_6:
	ld	[a2],a3
	set	6*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap6
	inc	4,a4

ap_5:
	ld	[a2],a3
	set	5*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap5
	inc	4,a4

ap_4:
	ld	[a2],a3
	set	4*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap4
	inc	4,a4

ap_3:
	ld	[a2],a3
	set	3*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq,a	fast_ap_
	lduh	[a3-2],d0

	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap3
	inc	4,a4

ap_2:
 	ld	[a2],a3
 	set	2*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	bne,a	no_fast_ap2_
	st	a0,[a4]

fast_ap_2_2_:
	lduh	[a3-2],d0
	add	d1,a3,d1
	ld	[d1-6],a3
#ifdef PROFILE
	dec	32,a3
#else
	dec	16,a3
#endif
	cmp	d0,1
	bltu	repl_args_0_2
	nop
	beq	repl_args_1
	cmp	d0,3
	bltu	repl_args_2
	nop

	st	a0,[a4]
	st	a1,[a4+4]
	inc	8,a4
	ba	fast_ap__
	ld	[a2+8],a1


no_fast_ap2_:
!	st	a0,[a4]
	mov	a1,a0
	mov	a2,a1
	ld	[a3+2],a2
	ba	no_fast_ap2
	inc	4,a4

fast_ap_2_2:
	mov	a1,a2
	mov	a0,a1
	ld	[a4-4],a0
	ba	fast_ap_2_2_
	dec	4,a4

fast_ap_2:
	mov	a1,a2
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

fast_ap:
	lduh	[a3-2],d0
fast_ap_:
	add	d1,a3,d1
	ld	[d1-6],a3
#ifdef PROFILE
	dec	32,a3
#else
	dec	16,a3
#endif
	cmp	d0,1
	bltu	repl_args_0
	nop
	beq	repl_args_1
	cmp	d0,3
	bltu	repl_args_2
	nop

	st	a0,[a4]
	st	a1,[a4+4]
	inc	8,a4
	ld	[a2+8],a1

fast_ap__:
	ld	[a2+4],a2
	beq	repl_args_3

	cmp	d0,5
	bltu	repl_args_4
	nop
	beq	repl_args_5
	cmp	d0,7
	bltu	repl_args_6
	nop

	sll	d0,2,d0
	dec	8,d0

repl_args_7_:
	ld	[a1+d0],%o0
	st	%o0,[a4]
	dec	4,d0
	cmp	d0,(6*4)-8
	bne	repl_args_7_
	inc	4,a4

repl_args_6:
	ld	[a1+16],d0
	st	d0,[a4]
	ld	[a1+12],d0
	st	d0,[a4+4]
	ld	[a1+8],d0
	st	d0,[a4+8]
	ld	[a1+4],a0
	ld	[a1],a1
	jmp	a3
	inc	12,a4

repl_args_0_2:
	jmp	a3
	nop

repl_args_0:
	mov	a1,a2
	mov	a0,a1
	ld	[a4-4],a0
	jmp	a3
	dec	4,a4

repl_args_1:
	jmp	a3
	ld	[a2+4],a2

repl_args_2:
	st	a0,[a4]
	mov	a1,a0
	ld	[a2+8],a1
	ld	[a2+4],a2
	jmp	a3
	inc	4,a4

repl_args_3:
	ld	[a1+4],a0
	jmp	a3
	ld	[a1],a1

repl_args_4:
	ld	[a1+8],d0
	st	d0,[a4]
	ld	[a1+4],a0
	ld	[a1],a1
	jmp	a3
	inc	4,a4

repl_args_5:
	ld	[a1+12],d0
	st	d0,[a4]
	ld	[a1+8],d0
	st	d0,[a4+4]
	ld	[a1+4],a0
	ld	[a1],a1
	jmp	a3
	inc	8,a4

no_fast_ap32:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,31*8
	beq,a	fast_ap_2
	mov	31*8,d1

	ld	[a3+2],a2
no_fast_ap31:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,30*8
	beq,a	fast_ap_2
	mov	30*8,d1

	ld	[a3+2],a2
no_fast_ap30:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,29*8
	beq,a	fast_ap_2
	mov	29*8,d1

	ld	[a3+2],a2
no_fast_ap29:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,28*8
	beq,a	fast_ap_2
	mov	28*8,d1

	ld	[a3+2],a2
no_fast_ap28:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,27*8
	beq,a	fast_ap_2
	mov	27*8,d1

	ld	[a3+2],a2
no_fast_ap27:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,26*8
	beq,a	fast_ap_2
	mov	26*8,d1

	ld	[a3+2],a2
no_fast_ap26:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,25*8
	beq,a	fast_ap_2
	mov	25*8,d1

	ld	[a3+2],a2
no_fast_ap25:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,24*8
	beq,a	fast_ap_2
	mov	24*8,d1

	ld	[a3+2],a2
no_fast_ap24:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,23*8
	beq,a	fast_ap_2
	mov	23*8,d1

	ld	[a3+2],a2
no_fast_ap23:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,22*8
	beq,a	fast_ap_2
	mov	22*8,d1

	ld	[a3+2],a2
no_fast_ap22:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,21*8
	beq,a	fast_ap_2
	mov	21*8,d1

	ld	[a3+2],a2
no_fast_ap21:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,20*8
	beq,a	fast_ap_2
	mov	20*8,d1

	ld	[a3+2],a2
no_fast_ap20:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,19*8
	beq,a	fast_ap_2
	mov	19*8,d1

	ld	[a3+2],a2
no_fast_ap19:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,18*8
	beq,a	fast_ap_2
	mov	18*8,d1

	ld	[a3+2],a2
no_fast_ap18:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,17*8
	beq,a	fast_ap_2
	mov	17*8,d1

	ld	[a3+2],a2
no_fast_ap17:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,16*8
	beq,a	fast_ap_2
	mov	16*8,d1

	ld	[a3+2],a2
no_fast_ap16:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,15*8
	beq,a	fast_ap_2
	mov	15*8,d1

	ld	[a3+2],a2
no_fast_ap15:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,14*8
	beq,a	fast_ap_2
	mov	14*8,d1

	ld	[a3+2],a2
no_fast_ap14:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,13*8
	beq,a	fast_ap_2
	mov	13*8,d1

	ld	[a3+2],a2
no_fast_ap13:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,12*8
	beq,a	fast_ap_2
	mov	12*8,d1

	ld	[a3+2],a2
no_fast_ap12:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,11*8
	beq,a	fast_ap_2
	mov	11*8,d1

	ld	[a3+2],a2
no_fast_ap11:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4
	ld	[a3+2],a2

 	lduh	[a3],%o1
	cmp	%o1,10*8
	beq,a	fast_ap_2
	mov	10*8,d1

	ld	[a3+2],a2
no_fast_ap10:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,9*8
	beq,a	fast_ap_2
	mov	9*8,d1

	ld	[a3+2],a2
no_fast_ap9:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,8*8
	beq,a	fast_ap_2
	mov	8*8,d1

	ld	[a3+2],a2
no_fast_ap8:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,7*8
	beq,a	fast_ap_2
	mov	7*8,d1

	ld	[a3+2],a2
no_fast_ap7:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,6*8
	beq,a	fast_ap_2
	mov	6*8,d1

	ld	[a3+2],a2
no_fast_ap6:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,5*8
	beq,a	fast_ap_2
	mov	5*8,d1

	ld	[a3+2],a2
no_fast_ap5:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,4*8
	beq,a	fast_ap_2
	mov	4*8,d1

	ld	[a3+2],a2
no_fast_ap4:
	dec	4,sp
	call	a2
	st	%o7,[sp]
	
	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	dec	4,a4

 	lduh	[a3],%o1
	cmp	%o1,3*8
	beq,a	fast_ap_2
	mov	3*8,d1

	ld	[a3+2],a2
no_fast_ap3:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0

	set	2*8,d1
 	lduh	[a3],%o1
	cmp	%o1,d1
	beq	fast_ap_2_2
	dec	4,a4

	ld	[a3+2],a2
no_fast_ap2:
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[a0],a3
	mov	a0,a1
	ld	[a4-4],a0
	ld	[a3+2],a2
	jmp	a2
	dec	4,a4

add_empty_node_2:
	deccc	3,d7
	bltu	add_empty_node_2_gc
	nop
add_empty_node_2_gc_:
	st	a5,[a6]
	mov	a1,a2
	mov	a0,a1
	mov	a6,a0
	inc	12,a6
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_2_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_2_gc_

add_empty_node_3:
	deccc	3,d7
	bltu	add_empty_node_3_gc
	nop
add_empty_node_3_gc_:
	st	a5,[a6]
	st	a6,[a4]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_3_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_3_gc_

add_empty_node_4:
	deccc	3,d7
	bltu	add_empty_node_4_gc
	nop
add_empty_node_4_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	st	a5,[a6]
	st	a6,[a4-4]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_4_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_4_gc_

add_empty_node_5:
	deccc	3,d7
	bltu	add_empty_node_5_gc
	nop
add_empty_node_5_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	st	a5,[a6]
	st	a6,[a4-8]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_5_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_5_gc_

add_empty_node_6:
	deccc	3,d7
	bltu	add_empty_node_6_gc
	nop
add_empty_node_6_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	st	a5,[a6]
	st	a6,[a4-12]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_6_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_6_gc_

add_empty_node_7:
	deccc	3,d7
	bltu	add_empty_node_7_gc
	nop
add_empty_node_7_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	ld	[a4-16],a3
	st	a3,[a4-12]
	st	a5,[a6]
	st	a6,[a4-16]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_7_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_7_gc_

add_empty_node_8:
	deccc	3,d7
	bltu	add_empty_node_8_gc
	nop
add_empty_node_8_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	ld	[a4-16],a3
	st	a3,[a4-12]
	ld	[a4-20],a3
	st	a3,[a4-16]
	st	a5,[a6]
	st	a6,[a4-20]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_8_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_8_gc_


add_empty_node_9:
	deccc	3,d7
	bltu	add_empty_node_9_gc
	nop
add_empty_node_9_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	ld	[a4-16],a3
	st	a3,[a4-12]
	ld	[a4-20],a3
	st	a3,[a4-16]
	ld	[a4-24],a3
	st	a3,[a4-20]
	st	a5,[a6]
	st	a6,[a4-24]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_9_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_9_gc_

add_empty_node_10:
	deccc	3,d7
	bltu	add_empty_node_10_gc
	nop
add_empty_node_10_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	ld	[a4-16],a3
	st	a3,[a4-12]
	ld	[a4-20],a3
	st	a3,[a4-16]
	ld	[a4-24],a3
	st	a3,[a4-20]
	ld	[a4-28],a3
	st	a3,[a4-24]
	st	a5,[a6]
	st	a6,[a4-28]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_10_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_10_gc_

add_empty_node_11:
	deccc	3,d7
	bltu	add_empty_node_11_gc
	nop
add_empty_node_11_gc_:
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
	ld	[a4-16],a3
	st	a3,[a4-12]
	ld	[a4-20],a3
	st	a3,[a4-16]
	ld	[a4-24],a3
	st	a3,[a4-20]
	ld	[a4-28],a3
	st	a3,[a4-24]
	ld	[a4-32],a3
	st	a3,[a4-28]
	st	a5,[a6]
	st	a6,[a4-32]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_11_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_11_gc_

add_empty_node_32:
	ba	add_empty_node_12_
	mov	7,d1

add_empty_node_28:
	ba	add_empty_node_12_
	mov	6,d1

add_empty_node_24:
	ba	add_empty_node_12_
	mov	5,d1

add_empty_node_20:
	ba	add_empty_node_12_
	mov	4,d1

add_empty_node_16:
	ba	add_empty_node_12_
	mov	3,d1

add_empty_node_12:
	mov	2,d1
add_empty_node_12_:
	deccc	3,d7
	bltu	add_empty_node_12_gc
	nop
add_empty_node_12_gc_:
	mov	a4,d0
	ld	[a4-4],a3
	st	a3,[a4]
add_empty_node_12_lp:
	ld	[d0-8],a3
	st	a3,[d0-4]
	ld	[d0-12],a3
	st	a3,[d0-8]
	ld	[d0-16],a3
	st	a3,[d0-12]
	ld	[d0-20],a3
	st	a3,[d0-16]
	deccc	1,d1
	bne	add_empty_node_12_lp
	dec	16,d0
	
	st	a5,[a6]
	st	a6,[d0-4]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_12_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_12_gc_

add_empty_node_29:
	ba	add_empty_node_13_
	mov	6,d1

add_empty_node_25:
	ba	add_empty_node_13_
	mov	5,d1

add_empty_node_21:
	ba	add_empty_node_13_
	mov	4,d1

add_empty_node_17:
	ba	add_empty_node_13_
	mov	3,d1

add_empty_node_13:
	mov	2,d1
add_empty_node_13_:
	deccc	3,d7
	bltu	add_empty_node_13_gc
	nop
add_empty_node_13_gc_:
	mov	a4,d0
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
add_empty_node_13_lp:
	ld	[d0-12],a3
	st	a3,[d0-8]
	ld	[d0-16],a3
	st	a3,[d0-12]
	ld	[d0-20],a3
	st	a3,[d0-16]
	ld	[d0-24],a3
	st	a3,[d0-20]
	deccc	1,d1
	bne	add_empty_node_13_lp
	dec	16,d0

	st	a5,[a6]
	st	a6,[d0-8]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_13_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_13_gc_

add_empty_node_30:
	ba	add_empty_node_14_
	mov	6,d1

add_empty_node_26:
	ba	add_empty_node_14_
	mov	5,d1

add_empty_node_22:
	ba	add_empty_node_14_
	mov	4,d1

add_empty_node_18:
	ba	add_empty_node_14_
	mov	3,d1

add_empty_node_14:
	mov	2,d1
add_empty_node_14_:
	deccc	3,d7
	bltu	add_empty_node_14_gc
	nop
add_empty_node_14_gc_:
	mov	a4,d0
	ld	[a4-4],a3
	st	a3,[a4]
	ld	[a4-8],a3
	st	a3,[a4-4]
	ld	[a4-12],a3
	st	a3,[a4-8]
add_empty_node_14_lp:
	ld	[d0-16],a3
	st	a3,[d0-12]
	ld	[d0-20],a3
	st	a3,[d0-16]
	ld	[d0-24],a3
	st	a3,[d0-20]
	ld	[d0-28],a3
	st	a3,[d0-24]
	deccc	1,d1
	bne	add_empty_node_14_lp
	dec	16,d0

	st	a5,[a6]
	st	a6,[d0-12]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_14_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_14_gc_

add_empty_node_31:
	ba	add_empty_node_15_
	mov	7,d1

add_empty_node_27:
	ba	add_empty_node_15_
	mov	6,d1

add_empty_node_23:
	ba	add_empty_node_15_
	mov	5,d1

add_empty_node_19:
	ba	add_empty_node_15_
	mov	4,d1

add_empty_node_15:
	mov	3,d1
add_empty_node_15_:
	deccc	3,d7
	bltu	add_empty_node_15_gc
	nop
add_empty_node_15_gc_:
	mov	a4,d0
add_empty_node_15_lp:
	ld	[d0-4],a3
	st	a3,[d0]
	ld	[d0-8],a3
	st	a3,[d0-4]
	ld	[d0-12],a3
	st	a3,[d0-8]
	ld	[d0-16],a3
	st	a3,[d0-12]
	deccc	1,d1
	bne	add_empty_node_15_lp
	dec	16,d0

	st	a5,[a6]
	st	a6,[d0]
	inc	12,a6
	inc	4,a4
	ld	[sp],%o7
	retl
	inc	4,sp
add_empty_node_15_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	add_empty_node_15_gc_

yet_args_needed_0:
	deccc	2,d7
	bltu	yet_args_needed_0_gc
	nop
yet_args_needed_0_gc_r:
	st	a0,[a6+4]
	inc	8,a6
	ld	[a1],d0
	sub	a6,8,a0
	inc	8,d0
	st	d0,[a6-8]

	ld	[sp],%o7
	retl
	inc	4,sp

yet_args_needed_0_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_0_gc_r


	deccc	3,d7
	bgeu,a	build_node_2
	st	d1,[a6]
	ba,a	build_node_2_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_1:
	deccc	3,d7
	bltu	yet_args_needed_1_gc
	nop
yet_args_needed_1_gc_r:
	st	a0,[a6+8]
	ld	[a1],d0
	mov	a6,a0
	inc	8,d0
	st	d0,[a6]
	ld	[a1+4],d1
	st	d1,[a6+4]
	inc	12,a6

	ld	[sp],%o7
	retl
	inc	4,sp	

yet_args_needed_1_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_1_gc_r

build_node_2:
	st	a1,[a6+4]
	st	a0,[a6+8]
	mov	a6,a0
	inc	12,a6
	ld	[sp],%o7
	retl
	inc	4,sp

build_node_2_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba	build_node_2
	st	d1,[a6]

	deccc	5,d7
	bgeu,a	build_node_3
	st	d1,[a6]
	ba,a	build_node_3_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_2:
	deccc	5,d7
	bltu	yet_args_needed_2_gc
	nop
yet_args_needed_2_gc_r:
	ld	[a1],d0
	st	a0,[a6+4]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[a6+8]
	add	a6,8,a0
	ld	[a1+8],%o0
	st	d2,[a6+12]
	st	%o0,[a6]
	st	a6,[a6+16]
	inc	20,a6

	ld	[sp],%o7
	retl
	inc	4,sp	

yet_args_needed_2_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_2_gc_r

build_node_3:
	st	a2,[a6+4]
	st	a1,[a6+12]
	inc	12,a6
	st	a6,[a6-4]
	st	a0,[a6+4]
	sub	a6,12,a0
	inc	8,a6
	ld	[sp],%o7
	retl
	inc	4,sp

build_node_3_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_3
	st	d1,[a6]

	deccc	6,d7
	bgeu,a	build_node_4
	st	d1,[a6]
	ba,a	build_node_4_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_3:
	deccc	6,d7
	bltu	yet_args_needed_2_gc
	nop
yet_args_needed_3_gc_r:
	ld	[a1],d0
	st	a0,[a6+8]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[a6+12]
	ld	[a1+8],a1
	st	d2,[a6+16]
	ld	[a1],%o0
	ld	[a1+4],%o1
	st	%o0,[a6]
	st	a6,[a6+20]
	add	a6,12,a0
	st	%o1,[a6+4]
	inc	24,a6

	ld	[sp],%o7
	retl
	inc	4,sp	

yet_args_needed_3_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_3_gc_r

build_node_4:
	st	a2,[a6+4]
	st	a1,[a6+12]
	inc	12,a6
	st	a6,[a6-4]
	st	a0,[a6+4]
	sub	a6,12,a0
	ld	[a4-4],a2
	dec	4,a4
	st	a2,[a6+8]
	inc	12,a6
	ld	[sp],%o7
	retl
	inc	4,sp

build_node_4_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_4
	st	d1,[a6]

	deccc	7,d7
	bgeu,a	build_node_5
	st	d1,[a6]
	ba,a	build_node_5_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_4:
	deccc	7,d7
	bltu	yet_args_needed_4_gc
	nop
yet_args_needed_4_gc_r:
	ld	[a1],d0
	st	a0,[a6+12]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[a6+16]
	ld	[a1+8],a1
	st	d2,[a6+20]
	ld	[a1],%o0
	ld	[a1+4],%o1
	st	%o0,[a6]
	st	a6,[a6+24]
	add	a6,16,a0
	ld	[a1+8],%o2
	st	%o1,[a6+4]
	st	%o2,[a6+8]
	inc	28,a6

	ld	[sp],%o7
	retl
	inc	4,sp	

yet_args_needed_4_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_4_gc_r

build_node_5:
	st	a2,[a6+4]
	st	a1,[a6+12]
	inc	12,a6
	st	a6,[a6-4]
	st	a0,[a6+4]
	sub	a6,12,a0
	ld	[a4-4],a2
	st	a2,[a6+8]
	ld	[a4-8],a2
	dec	8,a4
	st	a2,[a6+12]
	inc	16,a6

	ld	[sp],%o7
	retl
	inc	4,sp

build_node_5_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_5
	st	d1,[a6]

	deccc	8,d7
	bgeu,a	build_node_
	mov	1,d0
	ba,a	build_node_6_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_5:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	8,d0

build_node_6_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	1,d0

	deccc	9,d7
	bgeu,a	build_node_
	mov	2,d0
	ba,a	build_node_7_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_6:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	9,d0

build_node_7_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	2,d0

	deccc	10,d7
	bgeu,a	build_node_
	mov	3,d0
	ba,a	build_node_8_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_7:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	10,d0

build_node_8_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	3,d0

	deccc	11,d7
	bgeu,a	build_node_
	mov	4,d0
	ba,a	build_node_9_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_8:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	11,d0

build_node_9_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	4,d0

	deccc	12,d7
	bgeu,a	build_node_
	mov	5,d0
	ba,a	build_node_10_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_9:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	12,d0

build_node_10_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	5,d0

	deccc	13,d7
	bgeu,a	build_node_
	mov	6,d0
	ba,a	build_node_11_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_10:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	13,d0

build_node_11_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	6,d0

	deccc	14,d7
	bgeu,a	build_node_
	mov	7,d0
	ba,a	build_node_12_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_11:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	14,d0

build_node_12_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	7,d0

	deccc	15,d7
	bgeu,a	build_node_
	mov	8,d0
	ba,a	build_node_13_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_12:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	15,d0

build_node_13_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	8,d0

	deccc	16,d7
	bgeu,a	build_node_
	mov	9,d0
	ba,a	build_node_14_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_13:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	16,d0

build_node_14_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	9,d0

	deccc	17,d7
	bgeu,a	build_node_
	mov	10,d0
	ba,a	build_node_15_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_14:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	17,d0

build_node_15_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	10,d0

	deccc	18,d7
	bgeu,a	build_node_
	mov	11,d0
	ba,a	build_node_16_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_15:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	18,d0

build_node_16_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	11,d0

	deccc	19,d7
	bgeu,a	build_node_
	mov	12,d0
	ba,a	build_node_17_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_16:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	19,d0

build_node_17_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	12,d0

	deccc	20,d7
	bgeu,a	build_node_
	mov	13,d0
	ba,a	build_node_18_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_17:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	20,d0

build_node_18_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	13,d0

	deccc	21,d7
	bgeu,a	build_node_
	mov	14,d0
	ba,a	build_node_19_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_18:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	21,d0

build_node_19_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	14,d0

	deccc	22,d7
	bgeu,a	build_node_
	mov	15,d0
	ba,a	build_node_20_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_19:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	22,d0

build_node_20_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	15,d0

	deccc	23,d7
	bgeu,a	build_node_
	mov	16,d0
	ba,a	build_node_21_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_20:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	23,d0

build_node_21_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	16,d0

	deccc	24,d7
	bgeu,a	build_node_
	mov	17,d0
	ba,a	build_node_22_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_21:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	24,d0

build_node_22_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	17,d0

	deccc	25,d7
	bgeu,a	build_node_
	mov	18,d0
	ba,a	build_node_23_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_22:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	25,d0

build_node_23_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	18,d0

	deccc	26,d7
	bgeu,a	build_node_
	mov	19,d0
	ba,a	build_node_24_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_23:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	26,d0

build_node_24_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	19,d0

	deccc	27,d7
	bgeu,a	build_node_
	mov	20,d0
	ba,a	build_node_25_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_24:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	27,d0

build_node_25_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	20,d0

	deccc	28,d7
	bgeu,a	build_node_
	mov	21,d0
	ba,a	build_node_26_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_25:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	28,d0

build_node_26_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	21,d0

	deccc	29,d7
	bgeu,a	build_node_
	mov	22,d0
	ba,a	build_node_27_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_26:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	29,d0

build_node_27_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	22,d0

	deccc	30,d7
	bgeu,a	build_node_
	mov	23,d0
	ba,a	build_node_28_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_27:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	30,d0

build_node_28_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	23,d0

	deccc	31,d7
	bgeu,a	build_node_
	mov	24,d0
	ba,a	build_node_29_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_28:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	31,d0

build_node_29_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	24,d0

	deccc	32,d7
	bgeu,a	build_node_
	mov	25,d0
	ba,a	build_node_30_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_29:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	32,d0

build_node_30_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	25,d0

	deccc	33,d7
	bgeu,a	build_node_
	mov	26,d0
	ba,a	build_node_31_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_30:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	33,d0

build_node_31_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	26,d0

	deccc	34,d7
	bgeu,a	build_node_
	mov	27,d0
	ba,a	build_node_32_gc
#ifdef PROFILE
	nop
	nop
	nop
	nop
#endif

yet_args_needed_31:
	ld	[a1],d1
	ba	yet_args_needed_
	mov	34,d0

build_node_32_gc:
	dec	4,sp
	call	collect_3
	st	%o7,[sp]
	ba	build_node_
	mov	27,d0

yet_args_needed:
	ld	[a1],d1
	lduh	[d1-2],d0
	inc	3,d0

yet_args_needed_:
	subcc	d7,d0,d7
	bltu	yet_args_needed_gc
	nop

yet_args_needed_gc_r:
	ld	[a1+4],d3
	dec	1+4+3,d0
	ld	[a1+8],a1
	mov	a6,d2
	ld	[a1],%o0
	ld	[a1+4],%o1
	st	%o0,[a6]
	ld	[a1+8],%o2
	st	%o1,[a6+4]
	inc	12,a1
	st	%o2,[a6+8]
	inc	12,a6

yet_args_needed_cp_a:
	ld	[a1],%o0
	inc	4,a1
	st	%o0,[a6]
	deccc	1,d0
	bge	yet_args_needed_cp_a
	inc	4,a6

	st	a0,[a6]
	inc	8,d1
	st	d1,[a6+4]
	add	a6,4,a0
	st	d3,[a6+8]
	st	d2,[a6+12]
	inc	16,a6

	ld	[sp],%o7
	retl
	inc	4,sp

yet_args_needed_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba,a	yet_args_needed_gc_r

build_node_:
	st	d1,[a6]
	st	a2,[a6+4]
	st	a1,[a6+12]
	inc	12,a6
	st	a6,[a6-4]
	st	a0,[a6+4]
	sub	a6,12,a0
	ld	[a4-4],a2
	st	a2,[a6+8]
	ld	[a4-8],a2
	dec	8,a4
	st	a2,[a6+12]
	inc	16,a6

build_node_cp_a:
	ld	[a4-4],a2
	dec	4,a4
	deccc	1,d0
	st	a2,[a6]
	bne	build_node_cp_a
	inc	4,a6
	
	ld	[sp],%o7
	retl
	inc	4,sp

