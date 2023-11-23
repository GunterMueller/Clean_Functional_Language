
	.arch	armv7-a
	.syntax unified
	.thumb
        .fpu	vfpv3-d16
	.text

	.globl	divide
divide:
	eor	r7,r0,r1
	cmp	r1,#0
	it	lt
	neglt	r1,r1
	cmp	r0,#0
	it	lt
	neglt	r0,r0

	cmp	r1,#32
	bls	divide_by_small_number

	clz	r9,r1
	clz	r10,r0
	rsb	r9,r9,#31-5-11
	add	r9,r9,r10
	mov	r10,#0

	cmp	r9,#32-5-11
	bhs	divide_large_result

	add	r9,r9,r9,lsl #1
	lsl	r9,r9,#2
	add	pc,r9
	nop

	.set	shift,32-5-11
	.rept	32-5-11
	.set	shift,shift-1
	subs	r9,r0,r1,lsl #shift
	itt	cs
	movcs	r0,r9
	orrcs	r10,r10,#1<<shift
	.endr

	mov	r1,r10
	cmp	r7,#0
	it	lt
	neglt	r1,r1
	pop	{pc}

divide_large_result:
	bpl	divide_result_0

	vmov    s13,r0
	vmov    s15,r1
	vcvt.f64.u32	d6,s13
	vcvt.f64.u32	d7,s15
	vdiv.f64	d7,d6,d7
	vcvt.u32.f64	s15,d7
	vmov	r1,s15
	cmp	r7,#0
	it	lt
	neglt	r1,r1
	pop	{pc}

divide_result_0:
	mov	r1,#0
	pop	{pc}

divide_by_small_number:
	adr	r9,div_mod_table
	add	r9,r9,r1,lsl #3
	ldrb	r1,[r9,#1]
	ldr	r10,[r9,#4]
	ldrb	r9,[r9]
	adds	r0,r0,r1
	it	cc
	umullcc	r1,r10,r0,r10
	lsr	r1,r10,r9
	cmp	r7,#0
	it	lt
	neglt	r1,r1
	pop	{pc}

	.globl	modulo	
modulo:
	cmp	r1,#0
	it	lt
	neglt	r1,r1
	movs	r7,r0
	it	lt
	neglt	r0,r0

	cmp	r1,#32
	bls	modulo_of_small_number

	clz	r9,r1
	clz	r10,r0
	rsb	r9,r9,#31-5-11
	add	r9,r9,r10

	cmp	r9,#32-5-11
	bhs	modulo_large_divide_result

	lsl	r9,r9,#3
	add	pc,r9
	nop

	.set	shift,32
	.rept	32
	.set	shift,shift-1
	subs	r9,r0,r1,lsl #shift
	it	cs
	movcs	r0,r9
	.endr

modulo_divide_result_0:
	mov	r1,r0
	cmp	r7,#0
	it	lt
	neglt	r1,r1
	pop	{pc}

modulo_large_divide_result:
	bpl	modulo_divide_result_0

	vmov    s13,r0
	vmov    s15,r1
	vcvt.f64.u32	d6,s13
	vcvt.f64.u32	d7,s15
	vdiv.f64	d7,d6,d7
	vcvt.u32.f64	s15,d7
	vmov	r10,s15
	b	modulo_from_quotient

modulo_of_small_number:
	adr	r9,div_mod_table
	add	r9,r9,r1,lsl #3
	ldrb	r8,[r9,1]
	ldr	r10,[r9,#4]
	ldrb	r9,[r9]
	adds	r14,r0,r8
	it	cc
	umullcc	r8,r10,r14,r10
	lsr	r10,r10,r9
modulo_from_quotient:
@	mls	r1,r1,r10,r0
	neg	r1,r1
	mla	r1,r1,r10,r0
	cmp	r7,#0
	it	lt
	neglt	r1,r1
	pop	{pc}

div_mod_table:
	.long	0,0
	.long	0x100,0xffffffff
	.long	0,0x80000000
	.long	1,0xaaaaaaab
	.long	0,0x40000000
	.long	2,0xcccccccd
	.long	2,0xaaaaaaab
	.long	0x102,0x92492492
	.long	0,0x20000000
	.long	1,0x38e38e39
	.long	3,0xcccccccd
	.long	3,0xba2e8ba3
	.long	3,0xaaaaaaab
	.long	2,0x4ec4ec4f
	.long	0x103,0x92492492
	.long	3,0x88888889
	.long	0,0x10000000
	.long	4,0xf0f0f0f1
	.long	2,0x38e38e39
	.long	0x104,0xd79435e5
	.long	4,0xcccccccd
	.long	0x104,0xc30c30c3
	.long	4,0xba2e8ba3
	.long	4,0xb21642c9
	.long	4,0xaaaaaaab
	.long	3,0x51eb851f
	.long	3,0x4ec4ec4f
	.long	0x104,0x97b425ed	
	.long	0x104,0x92492492
	.long	4,0x8d3dcb09
	.long	4,0x88888889
	.long	0x104,0x84210842
	.long	0,0x08000000

