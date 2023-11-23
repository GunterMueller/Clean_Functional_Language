
	.seg	".text"

	.global	_start

_start:
	clr	%fp

	orcc	0,%g1,%o0
	be	no_atexit
	sub	%sp,32,%sp

	call	atexit
	nop

no_atexit:
	sethi	%hi _fini,%o0
	call	_init
	or	%o0,%lo _fini,%o0
	
	ld	[%sp+32+64],%o0
	add	32+68,%sp,%o1
	sll	%o0,2,%o2
	inc	4,%o2
	set	_environ,%o3
	call	main
	add	%o1,%o2,%o2

	call	exit
	nop
	
	call	_exit
	nop

