
	.fpu	vfp3

	.include "armmacros.s"

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
@	.globl	flushF
	.globl	openSF
	.globl	readSFC
	.globl	readSFI
	.globl	readSFR
	.globl	readSFS
	.globl	readLineSF
	.globl	endSF
	.globl	positionSF
	.globl	seekSF

@ imports

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

@	.d 0 0
#	jsr	stdioF
#	.o 0 2 f

stdioF:
	mov	r4,sp
	bic	sp,sp,#4
	bl	open_stdio
	mov	sp,r4

	mov	r3,r0
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 0
@	jsr	stderrF
@	.o 0 2 f

stderrF:
	mov	r4,sp
	bic	sp,sp,#4
	bl	open_stderr
	mov	sp,r4

	mov	r3,r0
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 1 1 i
@	jsr	openF
@	.o 0 3 b f

openF:
	add	r0,r6,#4
	mov	r1,r4
	mov	r4,sp
	bic	sp,sp,#4
	bl	open_file
	mov	sp,r4

	mov	r3,r0
	cmp	r0,#0
	mov	r4,#-1
	movmi	r2,#0
	movpl	r2,#1
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	closeF
@	.o 0 1 b

closeF:
	mov	r0,r3
	mov	r4,sp
	bic	sp,sp,#4
	bl	close_file
	mov	sp,r4
	mov	r4,r0
	ldr	pc,[sp],#4

@	.d 0 3 f i
@	jsr reopenF
@	.o 0 3 b f

reopenF:
	mov	r0,r2
	mov	r1,r4
	mov	r6,r2
	mov	r4,sp
	bic	sp,sp,#4
	bl	re_open_file
	mov	sp,r4

	neg	r2,r0
	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readFC
@	.o 0 4 b c f

readFC:
	mov	r0,r3
	mov	r6,r3
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_char
	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	cmp	r0,#-1
	beq	readFC_eof

	mov	r2,r0
	mov	r1,#1
	ldr	pc,[sp],#4
	
readFC_eof:
	mov	r2,#0
	mov	r3,#0
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readFI
@	.o 0 4 b i f

readFI:
	sub	sp,sp,#4
	mov	r0,r3
	mov	r1,sp
	mov	r6,r3
	
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_int
	mov	sp,r4

	ldr	r2,[sp],#4
	mov	r3,r6
	mov	r4,#-1
	neg	r1,r0
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readFR
@	.o 0 5 b r f

readFR:
	mov	r4,sp
	bic	sp,sp,#4
	mov	r0,r3
	sub	sp,sp,#8
	mov	r6,r3
	mov	r1,sp
	bl	file_read_real
	vldr.f64	d0,[sp]
	mov	sp,r4
	mov	r3,r6
	mov	r4,#-1
	neg	r2,r0
	ldr	pc,[sp],#4

@	.d 0 3 f i
@	jsr readFS
@	.o 1 2 f

readFS:
	add	r12,r4,#8+3
	subs	r1,r5,r12,lsr #2
	blo	readFS_gc
readFS_r_gc:
	laol	r12,__STRING__+2,__STRING___o_2,0
	otoa	r12,__STRING___o_2,0
	str	r12,[r10]
	add	r1,r10,#4
	str	r4,[r10,#4]
	mov	r0,r2
	mov	r8,r2
	add	r2,r10,#8

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_characters
	mov	sp,r4
	mov	r3,r8

readFS_end:
	add	r2,r0,#8+3
	mov	r6,r10
	and	r2,r2,#-4
	add	r10,r10,r2
	sub	r5,r5,r2,lsr #2
	mov	r4,#-1
	ldr	pc,[sp],#4

readFS_gc:
	mov	r5,r1
	bl	collect_0
	add	r12,r4,#8+3
	add	r5,r5,r12,lsr #2
	b	readFS_r_gc

@	.d 1 4 i i f
@	jsr readFString
@	.o 1 3 i f

readFString:
	ldr	r0,[r6,#4]
	cmp	r1,r0
	bhs	readFString_error

	sub	r0,r0,r1
	cmp	r2,r0
	bhi	readFString_error

	str	r2,[sp,#-4]!
	add	r2,r6,#8
	mov	r0,r3
	mov	r8,r3
	add	r2,r2,r1
	mov	r1,sp
	
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_characters
	mov	sp,r4
	mov	r3,r8

	ldr	r2,[sp],#4

	mov	r4,#-1
	ldr	pc,[sp],#4

readFString_error:
	lao	r8,freadstring_error,0
	otoa	r8,freadstring_error,0
	b	print_error

@	.d 0 2 f
@	jsr readLineF
@	.o 1 2 f

readLineF:
	subs	r2,r5,#32+2
	blo	readLineF_gc

readLineF_r_gc:
	laol	r12,__STRING__+2,__STRING___o_2,1
	otoa	r12,__STRING___o_2,1
	add	r2,r10,#8
	str	r12,[r10]
	lsl	r1,r5,#2
	mov	r0,r3
	sub	r1,r1,#8
	mov	r7,r1
	mov	r8,r3
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_line
	mov	sp,r4
	mov	r3,r8

	str	r0,[r10,#4]

	cmp	r0,#0
	bpl	readFS_end

	mov	r6,r10

readLineF_again:
	str	r7,[r6,#4]

	add	r10,#8
	mov	r5,#-(32+4)
	add	r10,r10,r7
	sub	r5,r5,r7,lsr #2
	bl	collect_1

	ldr	r4,[r6,#4]
	add	r5,r5,#32+4
	add	r11,r6,#8

	add	r5,r5,r4,lsr #2

	laol	r12,__STRING__+2,__STRING___o_2,2
	otoa	r12,__STRING___o_2,2
	mov	r6,r10
	add	r1,r10,r5,lsl #2
	str	r12,[r10]

	add	r2,r4,#3
	lsr	r2,r2,#2

	str	r4,[r10,#4]
	add	r10,r10,#8
	b	st_copy_string1

copy_st_lp1:
	ldr	r12,[r11],#4
	str	r12,[r10],#4
st_copy_string1:
	subs	r2,r2,#1
	bcs	copy_st_lp1

	mov	r2,r10
	sub	r1,r1,r10
	mov	r0,r3
	mov	r8,r3

	add	r7,r1,r4

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_line
	mov	sp,r4
	mov	r3,r8

	cmp	r0,#0
	bmi	readLineF_again

	ldr	r4,[r6,#4]
	add	r4,r4,r0
	str	r4,[r6,#4]
	add	r12,r0,#3
	and	r12,r12,#-4
	add	r10,r10,r12
	add	r12,r4,#8+3
	sub	r5,r5,r12,lsr #2
	mov	r4,#-1
	ldr	pc,[sp],#4

readLineF_gc:
	mov	r5,r2
	bl	collect_0
	add	r5,r5,#32+2
	b	readLineF_r_gc

@	.d 0 3 i f
@	jsr writeFI
@	.o 0 2 f

writeFC:
	mov	r6,r3
	mov	r1,r3
	mov	r0,r2

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_write_char
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 3 i f
@	jsr writeFI
@	.o 0 2 f

writeFI:
	mov	r6,r3
	mov	r1,r3
	mov	r0,r2

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_write_int
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 4 r f
@	jsr writeFR
@	.o 0 2 f

writeFR:
	mov	r6,r3
	mov	r0,r3

	mov	r4,sp
	bic	sp,sp,#4
 	bl	file_write_real
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 1 2 f
@	jsr writeFS
@	.o 0 2 f

writeFS:
	mov	r2,r3
	ldr	r1,[r6,#4]
	add	r0,r6,#8	
	mov	r6,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_write_characters
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 1 4 i i f
@	jsr writeFString
@	.o 0 2 f

writeFString:
	ldr	r0,[r6,#4]
	cmp	r1,r0
	bhs	writeFString_error

	sub	r0,r0,r1
	cmp	r2,r0
	bhi	writeFString_error

	mov	r1,r2
	mov	r2,r3
	add	r0,r6,#8
	mov	r6,r3
	add	r0,r0,r1

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_write_characters
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

writeFString_error:
	lao	r8,fwritestring_error,0
	otoa	r8,fwritestring_error,0
	b	print_error

@	.d 0 2 f
@	jsr endF
@	.o 0 3 b f

endF:
	mov	r0,r3
	mov	r6,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_end
 	mov	sp,r4

	neg	r2,r0
	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr errorF
@	.o 0 3 b f

errorF:
	mov	r0,r3
	mov	r6,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_error
 	mov	sp,r4

	neg	r2,r0
	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr positionF
@	.o 0 3 i f

positionF:
	mov	r0,r3
	mov	r6,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_position
 	mov	sp,r4

	mov	r2,r0
	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 4 f i i
@	jsr seekF
@	.o 0 3 b f

seekF:
	mov	r0,r1
	mov	r6,r1
	mov	r1,r3
	mov	r2,r4

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_seek
 	mov	sp,r4

	neg	r2,r0
	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr shareF
@	.o 0 2 f

shareF:
	mov	r0,r1
	mov	r6,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_share
 	mov	sp,r4

	mov	r3,r6
	mov	r4,#-1
	ldr	pc,[sp],#4

@	.d 1 1 i
@	jsr	openSF
@	.o 0 3 b f

openSF:
	add	r0,r6,#4
	mov	r1,r4

	mov	r4,sp
	bic	sp,sp,#4
	bl	open_s_file
 	mov	sp,r4

	cmp	r0,#0
	movmi	r2,#0
	movpl	r2,#1

	mov	r3,r0
	mov	r4,#0
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readSFC
@	.o 0 4 b c f

readSFC:
	str	r4,[sp,#-4]!
	mov	r6,r3
	mov	r1,sp
	mov	r0,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_s_char
 	mov	sp,r4

	ldr	r4,[sp],#4
	mov	r3,r6

	mov	r2,r0
	cmp	r0,#-1
	beq	readSFC_eof

	mov	r1,#1
	ldr	pc,[sp],#4

readSFC_eof:
	mov	r2,#0
	mov	r1,#0
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readSFI
@	.o 0 4 b i f

readSFI:
	str	r4,[sp,#-4]!
	mov	r6,r3
	mov	r2,sp
	sub	r1,sp,#4
	sub	sp,sp,#4
	mov	r0,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_s_int
 	mov	sp,r4

	neg	r1,r0
	ldr	r2,[sp],#4
	mov	r3,r6
	ldr	r4,[sp],#4
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr	readSFR
@	.o 0 5 b r f

readSFR:
	str	r4,[sp,#-4]!
	mov	r6,r3
	mov	r2,sp

	mov	r4,sp
	bic	sp,sp,#4
	mov	r0,r3
	sub	r1,sp,#8
	sub	sp,sp,#8
	bl	file_read_s_real
	vldr.f64	d0,[sp]
	mov	sp,r4

	mov	r3,r6
	ldr	r4,[sp],#4
	neg	r2,r0	
	ldr	pc,[sp],#4

@	.d 0 3 f i
@	jsr readSFS
@	.o 1 2 f

readSFS:
	add	r12,r4,#8+3
	subs	r1,r5,r12,lsr #2
	blo	readSFS_gc

readSFS_r_gc:
	laol	r12,__STRING__+2,__STRING___o_2,3
	otoa	r12,__STRING___o_2,3
	str	r12,[r10]
	mov	r1,r4
	mov	r0,r2
	mov	r6,r2
	str	r3,[sp,#-4]!
	add	r2,r10,#4
	mov	r3,sp

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_s_string
	mov	sp,r4
	mov	r3,r6

	ldr	r4,[sp],#4

readSFS_end:
	add	r2,r0,#8+3
	mov	r6,r10
	and	r2,r2,#-4
	add	r10,r10,r2
	sub	r5,r5,r2,lsr #2
	ldr	pc,[sp],#4

readSFS_gc:
	mov	r5,r1
	bl	collect_0
	add	r12,r4,#8+3
	add	r5,r5,r12,lsr #2
	b	readSFS_r_gc

@	.d 0 2 f
@	jsr readLineSF
@	.o 1 2 f

readLineSF:
	subs	r2,r5,#32+2
	blo	readLineSF_gc

readLineSF_r_gc:
	laol	r12,__STRING__+2,__STRING___o_2,4
	otoa	r12,__STRING___o_2,4
	add	r2,r10,#8
	str	r12,[r10]
	lsl	r1,r5,#2
	mov	r0,r3
	sub	r1,r1,#8
	mov	r7,r1
	mov	r8,r3
	str	r4,[sp,#-4]!
	mov	r3,sp
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_s_line
	mov	sp,r4
	mov	r3,r8
	ldr	r4,[sp],#4

	str	r0,[r10,#4]

	cmp	r0,#0
	bpl	readSFS_end

	mov	r6,r10

readLineSF_again:
	str	r7,[r6,#4]

	add	r10,#8
	mov	r5,#-(32+4)
	add	r10,r10,r7
	sub	r5,r5,r7,lsr #2
	bl	collect_1

	ldr	r2,[r6,#4]
	add	r5,r5,#32+4
	add	r11,r6,#8

	add	r5,r5,r2,lsr #2

	str	r10,[sp,#-4]!

	laol	r12,__STRING__+2,__STRING___o_2,5
	otoa	r12,__STRING___o_2,5
	add	r1,r10,r5,lsl #2
	str	r12,[r10]

	add	r6,r2,#3
	lsr	r6,r6,#2

	str	r2,[r10,#4]
	add	r10,r10,#8
	b	st_copy_string2

copy_st_lp2:
	ldr	r12,[r11],#4
	str	r12,[r10],#4
st_copy_string2:
	subs	r6,r6,#1
	bcs	copy_st_lp2

	sub	r1,r1,r10
	mov	r0,r3
	mov	r8,r3

	add	r7,r1,r2
	mov	r2,r10
	str	r4,[sp,#-4]!
	mov	r3,sp
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_read_s_line
	mov	sp,r4
	mov	r3,r8
	ldr	r4,[sp],#4

	ldr	r6,[sp],#4

	cmp	r0,#0
	bmi	readLineSF_again

	ldr	r2,[r6,#4]
	add	r2,r2,r0
	str	r2,[r6,#4]
	add	r12,r0,#3
	and	r12,r12,#-4
	add	r10,r10,r12
	add	r12,r2,#8+3
	sub	r5,r5,r12,lsr #2
	ldr	pc,[sp],#4

readLineSF_gc:
	mov	r5,r2
	bl	collect_0
	add	r5,r5,#32+2
	b	readLineSF_r_gc

@	.d 0 2 f
@	jsr endSF
@	.o 0 1 b

endSF:
	mov	r1,r4
	mov	r0,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_s_end
 	mov	sp,r4

	neg	r4,r0
	ldr	pc,[sp],#4

@	.d 0 2 f
@	jsr positionSF
@	.o 0 1 i

positionSF:
	mov	r1,r4
	mov	r0,r3

	mov	r4,sp
	bic	sp,sp,#4
	bl	file_s_position
 	mov	sp,r4

	mov	r4,r0
	ldr	pc,[sp],#4

@	.d 0 4 f i i
@	jsr seekSF
@	.o 0 3 b f

seekSF:
	str	r2,[sp,#-4]!
	mov	r6,r1
	mov	r0,r1
	mov	r1,r3
	mov	r2,r4
	mov	r3,sp
	
	mov	r4,sp
	bic	sp,sp,#4
	bl	file_s_seek
 	mov	sp,r4

	neg	r2,r0
	ldr	r4,[sp],#4
	mov	r3,r6
	ldr	pc,[sp],#4

.ifdef PIC
	lto	freadstring_error,0
	ltol	__STRING__+2,__STRING___o_2,0
	ltol	__STRING__+2,__STRING___o_2,1
	ltol	__STRING__+2,__STRING___o_2,2
	lto	fwritestring_error,0
	ltol	__STRING__+2,__STRING___o_2,3
	ltol	__STRING__+2,__STRING___o_2,4
	ltol	__STRING__+2,__STRING___o_2,5
.endif
