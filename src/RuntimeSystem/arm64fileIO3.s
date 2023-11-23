
	.data
	.p2align	3

freadstring_error:
	.ascii	"Error in freadsubstring parameters."
	.byte	10,0
	.byte	0,0,0
fwritestring_error:
	.ascii	"Error in fwritesubstring parameters."
	.byte	10,0
	.byte	0,0
	.text

	.globl	stdioF
	.globl	stderrF
	.globl	openF
	.globl	closeF
	.globl	reopenF
	.globl	readFC
	.globl	readFI
	.globl	readFR
	.globl	readFS
	.globl	readFString
	.globl	readLineF
	.globl	writeFC
	.globl	writeFI
	.globl	writeFR
	.globl	writeFS
	.globl	writeFString
	.globl	endF
	.globl	errorF
	.globl	positionF
	.globl	seekF
	.globl	shareF
	.globl	flushF
	.globl	openSF
	.globl	readSFC
	.globl	readSFI
	.globl	readSFR
	.globl	readSFS
	.globl	readLineSF
	.globl	endSF
	.globl	positionSF
	.globl	seekSF

# imports

	.globl	open_file
	.globl	open_stdio
	.globl	open_stderr
	.globl	re_open_file
	.globl	close_file
	.globl	file_read_char
	.globl	file_read_int
	.globl	file_read_real
	.globl	file_read_characters
	.globl	file_read_line
	.globl	file_write_char
	.globl	file_write_int
	.globl	file_write_real
	.globl	file_write_characters
	.globl	file_end
	.globl	file_error
	.globl	file_position
	.globl	file_seek
	.globl	file_share
	.globl	flush_file_buffer
	.globl	open_s_file
	.globl	file_read_s_char
	.globl	file_read_s_int
	.globl	file_read_s_real
	.globl	file_read_s_string
	.globl	file_read_s_line
	.globl	file_s_end
	.globl	file_s_position
	.globl	file_s_seek

	.globl	collect_0
	.globl	collect_1

	.globl	__STRING__

#	.d 0 0
#	jsr	stdioF
#	.o 0 2 f

stdioF:
	mov	x29,x30
	bl	open_stdio

	mov	x5,x0
	mov	x6,#-1
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 0
#	jsr	stderrF
#	.o 0 2 f

stderrF:
	mov	x29,x30
	bl	open_stderr

	mov	x5,x0
	mov	x6,#-1
	ldr	x30,[x28],#8
	ret	x29

#	.d 1 1 i
#	jsr	openF
#	.o 0 3 b f

openF:
	add	x0,x8,#8
	mov	x1,x6

	mov	x29,x30
	bl	open_file

	mov	x5,x0
	cmp	x0,#0
	mov	x6,#-1
	cset	w4,pl

	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	closeF
#	.o 0 1 b

closeF:
	mov	x0,x5

	mov	x29,x30
	bl	close_file

	mov	x6,x0

	ldr	x30,[x28],#8
	ret	x29

#	.d 0 3 f i
#	jsr reopenF
#	.o 0 3 b f

reopenF:
	mov	x0,x4
	mov	x1,x6

	mov	x29,x30
	str	x4,[x28,#-8]!
	bl	re_open_file
	ldr	x5,[x28],#8

	neg	x4,x0
	mov	x6,#-1
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	readFC
#	.o 0 4 b c f

readFC:
	mov	x0,x5

	mov	x29,x30
	str	x5,[x28,#-8]!
	bl	file_read_char
	ldr	x5,[x28],#8

	mov	x6,#-1
	cmp	x0,#-1
	beq	readFC_eof

	mov	x4,x0
	mov	x3,#1
	ldr	x30,[x28],#8
	ret	x29
	
readFC_eof:
	mov	x4,#0
	mov	x5,#0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	readFI
#	.o 0 4 b i f

readFI:
	mov	x0,x5
	sub	x1,x28,#8
	
	mov	x29,x30
	str	x5,[x28,#-16]!
	bl	file_read_int
	ldr	x5,[x28],#8

	mov	x6,#-1
	neg	x3,x0
	ldp	x4,x30,[x28],#16
	ret	x29

#	.d 0 2 f
#	jsr	readFR
#	.o 0 5 b r f

readFR:
	mov	x0,x5
	sub	x1,x28,#8

	mov	x29,x30
	str	x5,[x28,#-16]!
	bl	file_read_real
	ldr	x5,[x28],#8

	ldr	d0,[x28],#8

	mov	x6,#-1
	neg	x4,x0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 3 f i
#	jsr readFS
#	.o 1 2 f

readFS:
	add	x16,x6,#16+7
	subs	x1,x25,x16,lsr #3
	blo	readFS_gc
readFS_r_gc:
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	stp	x16,x6,[x27]
	add	x1,x27,#8
	mov	x0,x4

	str	x4,[x28,#-8]!
	add	x2,x27,#16

	mov	x29,x30
	bl	file_read_characters
	ldr	x5,[x28],#8
	mov	x30,x29

readFS_end:
	add	x4,x0,#16+7
	mov	x8,x27
	and	x4,x4,#-8
	add	x27,x27,x4
	sub	x25,x25,x4,lsr #3
	mov	x6,#-1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

readFS_gc:
	mov	x25,x1
	str	x30,[x28,#-8]!
	bl	collect_0
	add	x16,x6,#16+7
	add	x25,x25,x16,lsr #3
	b	readFS_r_gc

#	.d 1 4 i i f
#	jsr readFString
#	.o 1 3 i f

readFString:
	ldr	x0,[x8,#8]
	cmp	x3,x0
	bhs	readFString_error

	sub	x0,x0,x3
	cmp	x4,x0
	bhi	readFString_error

	str	x4,[x28,#-8]!
	add	x4,x8,#16
	mov	x0,x5
	str	x4,[x28,#-8]!
	add	x4,x4,x1
	mov	x1,x28
	
	mov	x29,x30
	bl	file_read_characters

	ldr	x5,[x28,#8]
	add	x28,x28,#16
	mov	x4,x0

	mov	x6,#-1
	ldr	x30,[x28],#8
	ret	x29

readFString_error:
	adrp	x10,freadstring_error
	add	x10,x10,#:lo12:freadstring_error
	b	print_error

#	.d 0 2 f
#	jsr readLineF
#	.o 1 2 f

readLineF:
	subs	x4,x25,#32+2
	blo	readLineF_gc

readLineF_r_gc:
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	add	x2,x27,#16
	str	x16,[x27]
	lsl	x1,x25,#3
	mov	x0,x5
	sub	x1,x1,#16

	mov	x29,x30
	stp	x1,x5,[x28,#-16]!
	bl	file_read_line
	ldp	x9,x5,[x28],#16
	mov	x30,x29

	str	x0,[x27,#8]

	cmp	x0,#0
	bpl	readFS_end

	mov	x8,x27
	add	x27,x27,#16
	add	x27,x27,x9

readLineF_lp:
	str	x9,[x8,#8]

	mov	x25,#-(32+4)
	sub	x25,x25,x9,lsr #3

	str	x30,[x28,#-8]!
	bl	collect_1

	ldr	x6,[x8,#8]
	add	x25,x25,#32+4
	add	x11,x8,#16
	add	x25,x25,x6,lsr #3

	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	mov	x8,x27
	add	x1,x27,x25,lsl #3
	str	x16,[x27]

	add	x4,x6,#7
	lsr	x4,x4,#3

	str	x6,[x27,#8]
	add	x27,x27,#16
	b	st_copy_string1

copy_st_lp1:
	ldr	x16,[x11],#8
	str	x16,[x27],#8
st_copy_string1:
	subs	x4,x4,#1
	bcs	copy_st_lp1

	mov	x2,x27
	sub	x1,x1,x27
	mov	x0,x5

	mov	x29,x30
	stp	x1,x5,[x28,#-16]!
	bl	file_read_line
	ldp	x9,x5,[x28],#16
	mov	x30,x29

	cmp	x0,#0
	bmi	readLineF_again

	ldr	x6,[x8,#8]
	add	x6,x6,x0
	str	x6,[x8,#8]
	add	x16,x0,#7
	and	x16,x16,#-8
	add	x27,x27,x16
	add	x16,x6,#16+7
	sub	x25,x25,x16,lsr #3
	mov	x6,#-1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

readLineF_gc:
	mov	x25,x4
	str	x30,[x28,#-8]!
	bl	collect_0
	add	x25,x25,#32+2
	b	readLineF_r_gc

readLineF_again:
	ldr	x6,[x8,#8]
	add	x27,x27,x9
	add	x9,x9,x6
	b	readLineF_lp

#	.d 0 3 i f
#	jsr writeFI
#	.o 0 2 f

writeFC:
	mov	x1,x5
	mov	x0,x4

	mov	x29,x30
	str	x5,[x28,#-8]!
	bl	file_write_char

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 3 i f
#	jsr writeFI
#	.o 0 2 f

writeFI:
	mov	x1,x5
	mov	x0,x4

	mov	x29,x30
	str	x5,[x28,#-8]!
	bl	file_write_int

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 4 r f
#	jsr writeFR
#	.o 0 2 f

writeFR:
	mov	x0,x5

	mov	x29,x30
	str	x5,[x28,#-8]!
 	bl	file_write_real

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 1 2 f
#	jsr writeFS
#	.o 0 2 f

writeFS:
	mov	x2,x5
	ldr	x1,[x8,#8]
	add	x0,x8,#16

	mov	x29,x30
	str	x5,[x28,#-8]!
	bl	file_write_characters

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 1 4 i i f
#	jsr writeFString
#	.o 0 2 f

writeFString:
	ldr	x0,[x8,#8]
	cmp	x3,x0
	bhs	writeFString_error

	sub	x0,x0,x3
	cmp	x4,x0
	bhi	writeFString_error

	mov	x1,x4
	mov	x2,x5
	add	x0,x8,#16
	str	x5,[x28,#-8]!
	add	x0,x0,x1

	mov	x29,x30
	bl	file_write_characters

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

writeFString_error:
	adrp	x10,fwritestring_error
	add	x10,x10,#:lo12:fwritestring_error
	b	print_error

#	.d 0 2 f
#	jsr endF
#	.o 0 3 b f

endF:
	mov	x0,x5
	str	x5,[x28,#-8]!

	mov	x29,x30
	bl	file_end

	ldp	x5,x30,[x28],#16
	neg	x4,x0
	mov	x6,#-1
	ret	x29

#	.d 0 2 f
#	jsr errorF
#	.o 0 3 b f

errorF:
	mov	x0,x5
	str	x5,[x28,#-8]!

	mov	x29,x30
	bl	file_error

	neg	x4,x0
	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 2 f
#	jsr positionF
#	.o 0 3 i f

positionF:
	mov	x0,x5
	str	x5,[x28,#-8]!

	mov	x29,x30
	bl	file_position

	mov	x4,x0
	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 4 f i i
#	jsr seekF
#	.o 0 3 b f

seekF:
	mov	x0,x3
	str	x3,[x28,#-8]!
	mov	x1,x5
	mov	x2,x6

	mov	x29,x30
	bl	file_seek

	neg	x4,x0
	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 2 f
#	jsr shareF
#	.o 0 2 f

shareF:
	mov	x0,x1
	str	x5,[x28,#-8]!

	mov	x29,x30
	bl	file_share

	ldp	x5,x30,[x28],#16
	mov	x6,#-1
	ret	x29

#	.d 0 2 f
#	jsr flushF
#	.o 0 3 b f

flushF:
	mov	x0,x5
	str	x5,[x28,#-8]!

	mov	x29,x30
	bl	flush_file_buffer

	ldp	x5,x30,[x28],#16
	mov	x4,x0
	mov	x6,#-1
	ret	x29

#	.d 1 1 i
#	jsr	openSF
#	.o 0 3 b f

openSF:
	add	x0,x8,#8
	mov	x1,x6

	mov	x29,x30
	bl	open_s_file

	cmp	x0,#0
	cset	w4,pl

	mov	x5,x0
	mov	x6,#0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	readSFC
#	.o 0 4 b c f

readSFC:
	stp	x5,x6,[x28,#-16]!
	mov	x1,x28
	mov	x0,x5

	mov	x29,x30
	bl	file_read_s_char

	ldp	x5,x6,[x28],#16

	mov	x4,x0
	cmp	x0,#-1
	beq	readSFC_eof

	mov	x3,#1
	ldr	x30,[x28],#8
	ret	x29

readSFC_eof:
	mov	x4,#0
	mov	x3,#0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	readSFI
#	.o 0 4 b i f

readSFI:
	stp	x5,x6,[x28,#-16]!
	mov	x2,x28
	sub	x1,x28,#8
	sub	x28,x28,#8
	mov	x0,x5

	mov	x29,x30
	bl	file_read_s_int

	neg	x3,x0
	ldr	x4,[x28],#8
	ldp	x5,x6,[x28],#16
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr	readSFR
#	.o 0 5 b r f

readSFR:
	stp	x5,x6,[x28,#-16]!
	mov	x2,x28
	mov	x0,x5
	sub	x1,x28,#8
	sub	x28,x28,#8

	mov	x29,x30
	bl	file_read_s_real

	ldr	d0,[x28],#8
	ldp	x5,x6,[x28],#16
	neg	x4,x0	
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 3 f i
#	jsr readSFS
#	.o 1 2 f

readSFS:
	add	x16,x6,#16+7
	subs	x3,x25,x16,lsr #3
	blo	readSFS_gc

readSFS_r_gc:
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	str	x16,[x27]
	mov	x1,x6
	mov	x0,x4
	stp	x5,x4,[x28,#-16]!
	add	x2,x27,#8
	mov	x3,x28

	mov	x29,x30
	bl	file_read_s_string
	mov	x30,x29

	ldp	x6,x5,[x28],#16
	mov	x30,x29

readSFS_end:
	add	x4,x0,#17+7
	mov	x8,x27
	and	x4,x4,#-8
	add	x27,x27,x4
	sub	x25,x25,x4,lsr #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

readSFS_gc:
	mov	x25,x3
	str	x30,[x28,#-8]!
	bl	collect_0
	add	x16,x6,#8+3
	add	x25,x25,x16,lsr #2
	b	readSFS_r_gc

#	.d 0 2 f
#	jsr readLineSF
#	.o 1 2 f

readLineSF:
	subs	x4,x25,#32+2
	blo	readLineSF_gc

readLineSF_r_gc:
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	add	x2,x27,#16
	str	x16,[x27]
	lsl	x1,x25,#3
	mov	x0,x5
	sub	x1,x1,#16

	stp	x1,x5,[x28,#-16]!
	str	x6,[x28,#-8]!
	mov	x3,x28
	mov	x29,x30
	bl	file_read_s_line
	ldr	x6,[x28],#8
	ldp	x9,x5,[x28],#16
	mov	x30,x29

	str	x0,[x27,#8]

	cmp	x0,#0
	bpl	readSFS_end

	mov	x8,x27

readLineSF_again:
	str	x9,[x8,#8]

	add	x27,x27,#16
	mov	x25,#-(32+4)
	add	x27,x27,x9
	sub	x25,x25,x9,lsr #3

	str	x30,[x28,#-8]!
	bl	collect_1

	ldr	x4,[x8,#8]
	add	x25,x25,#32+4
	add	x11,x8,#16

	add	x25,x25,x4,lsr #3

	str	x27,[x28,#-8]!

	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	add	x1,x27,x25,lsl #3
	str	x16,[x27]

	add	x8,x4,#7
	lsr	x8,x8,#3

	str	x4,[x27,#8]
	add	x27,x27,#16
	b	st_copy_string2

copy_st_lp2:
	ldr	x16,[x11],#8
	str	x16,[x27],#8
st_copy_string2:
	subs	x8,x8,#1
	bcs	copy_st_lp2

	sub	x1,x1,x27
	mov	x0,x5

	add	x9,x1,x4
	mov	x2,x27
	stp	x9,x5,[x28,#-16]!
	str	x6,[x28,#-8]!
	mov	x3,x28
	mov	x29,x30
	bl	file_read_s_line
	ldr	x6,[x28],#8
	ldp	x9,x5,[x28],#16
	mov	x30,x29

	ldr	x8,[x28],#8

	cmp	x0,#0
	bmi	readLineSF_again

	ldr	x4,[x8,#8]
	add	x4,x4,x0
	str	x4,[x8,#8]
	add	x16,x0,#7
	and	x16,x16,#-8
	add	x27,x27,x16
	add	x16,x4,#16+7
	sub	x25,x25,x16,lsr #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

readLineSF_gc:
	mov	x25,x4
	str	x30,[x28,#-8]!
	bl	collect_0
	add	x25,x25,#32+2
	b	readLineSF_r_gc

#	.d 0 2 f
#	jsr endSF
#	.o 0 1 b

endSF:
	mov	x1,x6
	mov	x0,x5

	mov	x29,x30
	bl	file_s_end

	neg	x6,x0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 2 f
#	jsr positionSF
#	.o 0 1 i

positionSF:
	mov	x1,x6
	mov	x0,x5

	mov	x29,x30
	bl	file_s_position

	mov	x6,x0
	ldr	x30,[x28],#8
	ret	x29

#	.d 0 4 f i i
#	jsr seekSF
#	.o 0 3 b f

seekSF:
	stp	x4,x3,[x28,#-16]!
	mov	x0,x3
	mov	x1,x5
	mov	x2,x6
	mov	x3,x28
	
	mov	x29,x30
	bl	file_s_seek

	neg	x4,x0
	ldp	x6,x5,[x28],#16
	ldr	x30,[x28],#8
	ret	x29
