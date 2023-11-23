
!	File:	cgsfileIO2.s
!	Author:	John van Groningen
!	At:	University of Nijmegen
!	Machine:	Sun 4

#define SP_G5

#define d0 %l0
#define d1 %l1
#define d2 %l2
#define d3 %l3
#define d4 %l4
#define d5 %l5
#define d6 %l6
#define d7 %l7
#define a0 %i0
#define a1 %i1
#define a2 %i2
#define a3 %i3
#define a4 %i4
#define a5 %i5
#define a6 %g6
#ifdef SP_G5
# define sp %g5
#else
# define sp %g7
#endif

	.data

	.align	8

tmp_real:	.double	0

	.text

	.global	stderrF
	.global	stdioF
	.global	openF
	.global	closeF
	.global	reopenF
	.global	readFC
	.global	readFI
	.global	readFR
	.global	readFS
	.global	readLineF
	.global	writeFC
	.global	writeFI
	.global	writeFR
	.global	writeFS
	.global	endF
	.global	errorF
	.global	positionF
	.global	seekF
	.global	shareF
	
	.global	openSF
	.global	readSFC
	.global	readSFI
	.global	readSFR
	.global	readSFS
	.global	readLineSF
	.global	endSF
	.global	positionSF
	.global	seekSF

! imports

	.global	@IO_error
	.global	@open_stdio
	.global	@open_stderr
	.global	@open_file
	.global	@re_open_file
	.global	@close_file
	.global	@file_read_char
	.global	@file_read_int
	.global	@file_read_real
	.global	@file_read_string
	.global	@file_read_line
	.global	@file_write_char
	.global	@file_write_int
	.global	@file_write_real
	.global	@file_write_string
	.global	@file_end
	.global	@file_error
	.global	@file_position
	.global	@file_seek
	.global	@file_share

	.global	@open_s_file
	.global	@file_read_s_char
	.global	@file_read_s_int
	.global	@file_read_s_real
	.global	@file_read_s_string
	.global	@file_read_s_line
	.global	@file_s_end
	.global	@file_s_position
	.global	@file_s_seek

	.global	collect_0
	.global	collect_1
	.global	out_of_memory_4

	.global	__STRING__

stdioF:	call	@open_stdio
	nop
	
	mov	%o0,%l1
	mov	-1,%l0

	ld	[sp],%o7
	retl
	inc	4,sp

stderrF:	call	@open_stderr
	nop
	
	mov	%o0,%l1
	mov	-1,%l0

	ld	[sp],%o7
	retl
	inc	4,sp

openF:	mov	%l0,%o1
	call	@open_file
	add	%i0,4,%o0

	orcc	%o0,%g0,%l1
	mov	-1,%l0
	ld	[sp],%o7
	clr	%l2
	bpos,a	openF_1
	mov	-1,%l2
openF_1:
	retl
	inc	4,sp

closeF:	call	@close_file
	mov	%l1,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

reopenF:
	mov	%l2,%o0
	call	@re_open_file
	mov	%l0,%o1
	
	mov	%l2,%l1
	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

readFC:
	call	@file_read_char
	mov	%l1,%o0

	mov	%o0,%l2
	addcc	%o0,1,%g0
	be	readFC_eof
	set	-1,%l0
	
	ld	[sp],%o7
	set	-1,%l3
	retl
	inc	4,sp

readFC_eof:
	ld	[sp],%o7
	clr	%l2
	clr	%l3
	retl
	inc	4,sp

readFI:
	sub	sp,4,%o1
	call	@file_read_int
	mov	%l1,%o0
	
	ld	[sp-4],%l2
	set	-1,%l0
	ld	[sp],%o7
	mov	%o0,%l3
	retl
	inc	4,sp

readFR:
	set	tmp_real,%o1
	call	@file_read_real
	mov	%l1,%o0

	sethi	%hi tmp_real,%g1
	ldd	[%g1+%lo tmp_real],%f0
	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

readFS:
	add	%l0,8+3,%l5
	srl	%l5,2,%l5
	subcc	%l7,%l5,%l7
	bneg	readFS_gc
	nop

readFS_r_gc:
	add	d7,%l5,d7
	mov	%l2,%l4
	mov	%g6,%l3
	
	set	__STRING__+2,%o0
	st	%o0,[%g6]
	inc	4,%g6
	
	mov	%g6,%o2
	mov	%l0,%o1
	call	@file_read_string
	mov	%l2,%o0

readFS_end:
	inc	3,d0
	and	d0,-4,d0
	inc	4,%g6
	add	a6,d0,a6
	srl	d0,2,d0
	inc	2,d0
	sub	d7,d0,d7
	
	mov	%l3,%i0
	mov	%l4,%l1
	ld	[sp],%o7
	set	-1,d0
	retl
	inc	4,sp

readFS_gc:	dec	4,sp
	call	collect_0
	st	%o7,[sp]

	b,a	readFS_r_gc

readLineF:
	mov	32+2,%l5
	subcc	%l7,%l5,%g0
	bneg	readLineF_gc
	nop

readLineF_r_gc:
	mov	%l1,%l4
	mov	a6,%l3

	set	__STRING__+2,%o0
	st	%o0,[a6]
	inc	4,a6
	
	add	a6,4,%o2
	sub	%l7,2,%o1
	sll	%o1,2,%o1
	call	@file_read_line
	mov	%l4,%o0

	orcc	%o0,%g0,%l0
	bpos	readFS_end
	st	%l0,[a6]

	tst	%l5
	be	out_of_memory_4
	nop

	sub	%l7,2,%l0
	sll	%l0,2,%l0
	st	%l0,[a6]
	inc	4,a6
	add	a6,%l0,a6

	add	%l7,32+2,%l5
	neg	%l5,%l7
	mov	%l3,%i0

	dec	4,sp
	call	collect_1
	st	%o7,[sp]

	add	%l7,%l5,%l7
	mov	%i0,%i1

	ld	[%i1+4],%l0
	inc	8,%i1
	add	%l0,3,%l1
	srl	%l1,2,%l1
	dec	2,%l7
	sub	%l7,%l1,%l7

	set	__STRING__+2,%o0
	st	%o0,[a6]
	mov	a6,%l3
	st	%l0,[a6+4]
	b	st_copy_string1
	inc	8,a6
copy_st_lp1:
	inc	4,%i1
	st	%g1,[a6]
	inc	4,a6
st_copy_string1:
	deccc	1,%l1
	bcc,a	copy_st_lp1
	ld	[%i1],%g1

	mov	a6,%o2
	sll	%l7,2,%o1
	call	@file_read_line
	mov	%l4,%o0

	orcc	%o0,%g0,%l0
	bneg	out_of_memory_4
	mov	%l3,%i0

	ld	[%i0+4],%g1

	add	%l0,3,%l1

	add	%g1,%l0,%g1
	st	%g1,[%i0+4]

	srl	%l1,2,%l1
	sub	%l7,%l1,%l7
	sll	%l1,2,%l1
	add	a6,%l1,a6
	
	mov	%l4,%l1
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

readLineF_gc:
	sub	%l7,%l5,%l7
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
	
	add	%l7,%l5,%l7
	b	readLineF_r_gc
	clr	%l5

writeFC:
	mov	%l1,%o1
	call	@file_write_char
	mov	%l2,%o0

	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

writeFI:
	mov	%l1,%o1
	call	@file_write_int
	mov	%l2,%o0

	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

writeFR:
	sethi	%hi tmp_real,%g1
	std	%f0,[%g1+%lo tmp_real]
	mov	%l1,%o2
 	call	@file_write_real
	ldd	[%g1+%lo tmp_real],%o0

	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

writeFS:
	mov	%l1,%o1
	call	@file_write_string
	add	%i0,4,%o0

	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

endF:
	call	@file_end
	mov	%l1,%o0

	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

errorF:
	call	@file_error
	mov	%l1,%o0

	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

positionF:
	call	@file_position
	mov	%l1,%o0

	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

seekF:
	mov	%l0,%o2
	mov	%l1,%o1
	mov	%l3,%o0
	call	@file_seek
	mov	%l3,%l1

	mov	%o0,%l2
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp

shareF:
	call	@file_share
	mov	%l1,%o0
	
	ld	[sp],%o7
	set	-1,%l0
	retl
	inc	4,sp
	
openSF:	mov	%l0,%o1
	call	@open_s_file
	add	%i0,4,%o0

	orcc	%o0,%g0,%l1
	mov	0,%l0
	ld	[sp],%o7
	clr	%l2
	bpos,a	openSF_1
	mov	-1,%l2
openSF_1:
	retl
	inc	4,sp

readSFC:
	sub	sp,4,%o1
	st	%l0,[sp-4]
	call	@file_read_s_char
	mov	%l1,%o0

	mov	%o0,%l2
	addcc	%o0,1,%g0
	be	readSFC_eof
	ld	[sp-4],%l0

	ld	[sp],%o7
	mov	-1,%l3
	retl
	inc	4,sp

readSFC_eof:
	clr	%l2
	ld	[sp],%o7
	clr	%l3
	retl
	inc	4,sp

readSFI:
	sub	sp,4,%o2
	st	%l0,[sp-4]
	sub	sp,8,%o1
	call	@file_read_s_int
	mov	%l1,%o0

	ld	[sp-8],%l2
	ld	[sp-4],%l0
	ld	[sp],%o7
	mov	%o0,%l3
	retl
	inc	4,sp

readSFR:
	sub	sp,4,%o2
	st	%l0,[sp-4]
	set	tmp_real,%o1	
	call	@file_read_s_real
	mov	%l1,%o0

	sethi	%hi tmp_real,%g1
	ldd	[%g1+%lo tmp_real],%f0
	ld	[sp-4],%l0
	ld	[sp],%o7
	mov	%o0,%l2
	retl
	inc	4,sp

readSFS:
	add	%l0,8+3,%l5
	srl	%l5,2,%l5
	subcc	%l7,%l5,%l7
	bneg	readSFS_gc
	nop

readSFS_r_gc:
	add	%l7,%l5,%l7
	mov	%l2,%l4
	mov	%g6,%l3

	set	__STRING__+2,%o0
	st	%o0,[%g6]
	inc	4,%g6

	sub	sp,4,%o3
	st	%l1,[sp-4]
	mov	%g6,%o2
	mov	%l0,%o1
	call	@file_read_s_string
	mov	%l2,%o0

readSFS_end:
	inc	3,%l0
	and	%l0,-4,%l0
	inc	4,%g6
	add	%g6,%l0,%g6
	srl	%l0,2,%l0
	inc	4,%l0
	sub	%l7,%l0,%l7

	mov	%l3,%i0
	mov	%l4,%l1
	ld	[sp],%o7
	ld	[sp-4],%l0
	retl
	inc	4,sp

readSFS_gc:	dec	4,sp
	call	collect_0
	st	%o7,[sp]
	
	b,a	readSFS_r_gc

readLineSF:
	mov	32+2,%l5
	subcc	%l7,%l5,%g0
	bneg	readLineSF_gc
	nop

readLineSF_r_gc:
	st	%l0,[sp-4]
	mov	%l1,%l4
	mov	%g6,%l3
	
	set	__STRING__+2,%o0
	st	%o0,[%g6]
	inc	4,%g6

	sub	sp,4,%o3
	add	%g6,4,%o2
	sub	%l7,2,%o1
	sll	%o1,2,%o1
	call	@file_read_s_line
	mov	%l4,%o0

	orcc	%o0,%g0,%l0
	bpos	readSFS_end
	st	%l0,[%g6]

	tst	%l5
	be	out_of_memory_4
	nop

	sub	%l7,2,%l0
	sll	%l0,2,%l0
	st	%l0,[%g6]
	inc	4,%g6
	add	%g6,%l0,%g6

	add	%l7,32+2,%l5
	neg	%l5,%l7
	mov	%l3,%i0

	dec	4,sp
	call	collect_1
	st	%o7,[sp]

	add	%l7,%l5,%l7

	mov	%i0,%i1
	ld	[%i1+4],%l0
	inc	8,%i1
	add	%l0,3,%l1
	srl	%l1,2,%l1
	dec	2,%l7
	sub	%l7,%l1,%l7

	set	__STRING__+2,%o0
	st	%o0,[%g6]
	mov	%g6,%l3
	st	%l0,[%g6+4]
	b	st_copy_string2
	inc	8,%g6

copy_st_lp2:
	inc	4,%i1
	st	%g1,[%g6]
	inc	4,%g6
st_copy_string2:
	deccc	1,%l1
	bcc,a	copy_st_lp2
	ld	[%i1],%g1

	sub	sp,4,%o3
	mov	%g6,%o2
	sll	%l7,2,%o1
	call	@file_read_s_line
	mov	%l4,%o0

	orcc	%o0,%g0,%l0
	bneg	out_of_memory_4
	mov	%l3,%i0

	ld	[%i0+4],%g1
	add	%l0,3,%l1

	add	%g1,%l0,%g1
	st	%g1,[%i0+4]

	srl	%l1,2,%l1
	sub	%l7,%l1,%l7
	sll	%l1,2,%l1
	add	%g6,%l1,%g6
	
	ld	[sp-4],%l0
	ld	[sp],%o7
	mov	%l4,%l1
	retl
	inc	4,sp

readLineSF_gc:
	sub	%l7,%l5,%l7
	dec	4,sp
	call	collect_0
	st	%o7,[sp]

	add	%l7,%l5,%l7
	b	readLineSF_r_gc
	clr	%l5

endSF:
	mov	%l0,%o1
	call	@file_s_end
	mov	%l1,%o0
	
	ld	[sp],%o7
	mov	%o0,%l0
	retl
	inc	4,sp

positionSF:
	mov	%l0,%o1
	call	@file_s_position
	mov	%l1,%o0
	
	ld	[sp],%o7
	mov	%o0,%l0
	retl
	inc	4,sp

seekSF:
	sub	sp,4,%o3
	st	%l2,[sp-4]
	mov	%l0,%o2
	mov	%l1,%o1
	mov	%l3,%o0
	call	@file_s_seek
	mov	%l3,%l1
	
	ld	[sp-4],%l0
	ld	[sp],%o7
	mov	%o0,%l2
	retl
	inc	4,sp
