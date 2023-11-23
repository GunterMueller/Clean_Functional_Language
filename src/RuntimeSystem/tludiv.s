	.arch   armv7-a
	.syntax unified
	.thumb
	.fpu    vfpv3-d16

	.text
	.global ludivide
ludivide:
	adds	r0,r0,r0
	adcs	r2,r10,r10
	it	cc
	cmpcc	r2,r1
	it	cs
	subcs	r2,r2,r1

	.rept 31
	adcs	r0,r0,r0
	adcs	r2,r2,r2
	it	cc
	cmpcc	r2,r1
	it	cs
	subcs	r2,r2,r1
	.endr

	adc	r1,r0,r0
	mov	r0,r2

	ldr     pc,[sp],#4

