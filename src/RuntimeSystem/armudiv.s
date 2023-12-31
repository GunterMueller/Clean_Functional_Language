
	.arch	armv7-a
        .fpu	vfpv3-d16
	.text

	.globl	udivide
udivide:
	cmp	r4,#32
	bls	udivide_by_small_number

	clz	r1,r4
	clz	r2,r3
	rsb	r1,r1,#31-16
	add	r1,r1,r2
	mov	r2,#0

	cmp	r1,#32-16
	bhs	udivide_large_result

	add	r1,r1,r1,lsl #1
	add	pc,pc,r1,lsl #2
	nop

	.set	shift,32-16
	.rept	32-16
	.set	shift,shift-1
	subs	r1,r3,r4,lsl #shift
	movcs	r3,r1
	orrcs	r2,r2,#1<<shift
	.endr

	mov	r4,r2
	ldr	pc,[sp],#4

udivide_large_result:
	bpl	udivide_result_0

	vmov    s13,r3
	vmov    s15,r4
	vcvt.f64.u32	d6,s13
	vcvt.f64.u32	d7,s15
	vdiv.f64	d7,d6,d7
	vcvt.u32.f64	s15,d7
	vmov	r4,s15
	ldr	pc,[sp],#4

udivide_result_0:
	mov	r4,#0
	ldr	pc,[sp],#4

udivide_by_small_number:
	add	r1,pc,r4,lsl #3
	ldrb	r4,[r1,#(udiv_mod_table+1)-(udivide_by_small_number+8)]
	ldr	r2,[r1,#(udiv_mod_table+4)-(udivide_by_small_number+8)]
	ldrb	r1,[r1,#udiv_mod_table-(udivide_by_small_number+8)]
	adds	r3,r3,r4
	umullcc	r4,r2,r3,r2
	lsr	r4,r2,r1
	ldr	pc,[sp],#4

udiv_mod_table:
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

