
#define SP_G5

#ifdef SP_G5
# define sp %g5
#else
# define sp %g7
#endif

	.global	r_to_i_real
	.global	entier_real
	.global	acos_real
	.global	pow_real
	.global	cos_real
	.global	exp_real
	.global	asin_real
	.global	atan_real
	.global	log10_real
	.global	tan_real
	.global	ln_real
	.global	sin_real
	
!
!	REALS
!

exp_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@exp
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

ln_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@log
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

log10_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@log10
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

pow_real:
	std	%f2,[%fp-8]
	ld	[%fp-8],%o0
	ld	[%fp-4],%o1
	std	%f0,[%fp-8]
	ld	[%fp-8],%o2
	call	@pow
	ld	[%fp-4],%o3
	ld	[sp],%o7
	retl
	inc	4,sp

sin_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@sin
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

cos_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@cos
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

tan_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@tan
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp
	
acos_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@acos
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

asin_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@asin
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp

atan_real:
	std	%f0,[%fp-8]
	ld	[%fp-8],%o0
	call	@atan
	ld	[%fp-4],%o1
	ld	[sp],%o7
	retl
	inc	4,sp
	
entier_real:
	sethi	%hi d_0,%o0
	ldd	[%o0+%lo d_0],%f2
	fdtoi	%f0,%f4
	ld	[sp],%o7
	st	%f4,[%fp-4]
	fcmpd	%f0,%f2
	ld	[%fp-4],%l0
	fbge	entier_real_2
	nop
	fitod	%f4,%f2
	fcmpd	%f0,%f2
	nop
	fbne,a	entier_real_2
	dec	%l0
entier_real_2:
	retl
	inc	4,sp

	.data
	.align	8
d_0:	.double	0r0.0
d_0_5:	.double	0r0.5
	.text

r_to_i_real:
	sethi	%hi d_0,%o0
	ldd	[%o0+%lo d_0],%f2
	sethi	%hi d_0_5,%o0
	fcmpd	%f0,%f2
	ldd	[%o0+%lo d_0_5],%f4
	nop
	fbge,a	r_to_i_real_2
	faddd	%f0,%f4,%f0
	fsubd	%f0,%f4,%f0
r_to_i_real_2:
	fdtoi	%f0,%f2
	st	%f2,[%fp-4]
	ld	[sp],%o7
	ld	[%fp-4],%l0
	retl
	inc	4,sp
