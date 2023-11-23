
	.text
	.global ludivide
ludivide:
	adds	r3,r3,r3
	adcs	r2,r2,r2
	cmpcc	r2,r4
	subcs	r2,r2,r4

	.rept 31
	adcs	r3,r3,r3
	adcs	r2,r2,r2
	cmpcc	r2,r4
	subcs	r2,r2,r4
	.endr
	
	adc	r4,r3,r3
	mov	r3,r2

	ldr     pc,[sp],#4
	
