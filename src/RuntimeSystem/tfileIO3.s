
	.arch	armv7-a
	.fpu	vfp3
	.syntax unified
	.thumb

	.include "tmacros.s"

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
#	.o 0 2 f # r0 r1

stdioF:
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	open_stdio
	mov	sp,r4

	mov	r1,#-1
	pop	{pc}

@	.d 0 0
@	jsr	stderrF
@	.o 0 2 f # r0 r1

stderrF:
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	open_stderr
	mov	sp,r4

	mov	r1,#-1
	pop	{pc}

@	.d 1 1 i # r2 r1
@	jsr	openF
@	.o 0 3 b f # r10 r0 r1

openF:
	adds	r0,r2,#4
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	open_file
	mov	sp,r4

	cmp	r0,#0
	mov	r1,#-1
	ite	mi
	movmi	r10,#0
	movpl	r10,#1
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	closeF
@	.o 0 1 b # r1

closeF:
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	close_file
	mov	sp,r4
	mov	r1,r0
	pop	{pc}

@	.d 0 3 f i # r10 r0 r1
@	jsr reopenF
@	.o 0 3 b f # r10 r0 r1

reopenF:
	mov	r0,r10
	mov	r7,r10
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	re_open_file
	mov	sp,r4

	neg	r10,r0
	mov	r0,r7
	mov	r1,#-1
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	readFC
@	.o 0 4 b c f # r9 r10 r0 r1

readFC:
	mov	r7,r0
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	file_read_char
	mov	sp,r4

	mov	r1,#-1
	cmp	r0,#-1
	beq	readFC_eof

	mov	r10,r0
	mov	r0,r7
	mov	r9,#1
	pop	{pc}
	
readFC_eof:
	mov	r0,r7
	mov	r10,#0
	mov	r9,#0
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	readFI
@	.o 0 4 b i f # r9 r10 r0 r1

readFI:
	sub	sp,sp,#4
	mov	r7,r0
	mov	r1,sp
	
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	bl	file_read_int
	mov	sp,r4

	mov	r1,#-1
	ldr	r10,[sp],#4
	neg	r9,r0
	mov	r0,r7
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	readFR
@	.o 0 5 b r f # r10 d0 r0 r1

readFR:
	mov	r4,sp
	bic	r12,r4,#4
	mov	sp,r12
	mov	r7,r0
	sub	sp,sp,#8
	mov	r1,sp
	bl	file_read_real
	vldr.f64	d0,[sp]
	mov	sp,r4
	mov	r1,#-1
	neg	r10,r0
	mov	r0,r7
	pop	{pc}

@	.d 0 3 f i # r10 r0 r1
@	jsr readFS
@	.o 1 2 f # r2 r0 r1

readFS:
	add	r7,r1,#8+3
	subs	r9,r11,r7,lsr #2
	blo	readFS_gc
readFS_r_gc:
	laol	r7,__STRING__+2,__STRING___o_2,0
	otoa	r7,__STRING___o_2,0
	strd	r7,r1,[r6]

	mov	r0,r10
	add	r1,r6,#4
	add	r2,r6,#8
	mov	r4,r10

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_characters
	mov	sp,r7

readFS_end:
	add	r7,r0,#8+3
	mov	r0,r4
	mov	r2,r6
	and	r7,r7,#-4
	add	r6,r6,r7
	sub	r11,r11,r7,lsr #2
	mov	r1,#-1
	pop	{pc}

readFS_gc:
	mov	r11,r9
	bl	collect_0
	add	r7,r1,#8+3
	add	r11,r11,r7,lsr #2
	b	readFS_r_gc

@	.d 1 4 i i f # r2 r9 r10 r0 r1
@	jsr readFString
@	.o 1 3 i f # r2 r10 r0 r1

readFString:
	ldr	r8,[r2,#4]
	cmp	r9,r8
	bhs	readFString_error

	sub	r8,r8,r9
	cmp	r10,r8
	bhi	readFString_error

	mov	r8,r2
	str	r10,[sp,#-4]!
	mov	r1,sp
	add	r2,r2,#8
	add	r2,r2,r9
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_characters
	mov	sp,r7

	mov	r0,r4
	ldr	r10,[sp],#4
	mov	r2,r8
	mov	r1,#-1
	pop	{pc}

readFString_error:
	lao	r4,freadstring_error,0
	otoa	r4,freadstring_error,0
	b	print_error

@	.d 0 2 f # r0 r1
@	jsr readLineF
@	.o 1 2 f # r2 r0 r1

readLineF:
	subs	r10,r11,#32+2
	blo	readLineF_gc

readLineF_r_gc:
	laol	r7,__STRING__+2,__STRING___o_2,1
	otoa	r7,__STRING___o_2,1

	add	r2,r6,#8
	str	r7,[r6]
	lsl	r1,r11,#2
	mov	r4,r0
	subs	r1,#8
	mov	r9,r1

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_line
	mov	sp,r7

	str	r0,[r6,#4]

	cmp	r0,#0
	bpl	readFS_end

	mov	r2,r6

readLineF_again:
	str	r9,[r2,#4]

	add	r6,#8
	mov	r11,#-(32+4)
	add	r6,r6,r9
	sub	r11,r11,r9,lsr #2
	mov	r0,r4
	bl	collect_1

	ldr	r4,[r2,#4]
	add	r11,r11,#32+4
	add	r12,r2,#8

	add	r11,r11,r4,lsr #2

	laol	r7,__STRING__+2,__STRING___o_2,2
	otoa	r7,__STRING___o_2,2
	mov	r8,r6
	add	r1,r6,r11,lsl #2
	str	r7,[r6]

	add	r10,r4,#3
	lsr	r10,r10,#2

	str	r4,[r6,#4]
	adds	r6,#8
	b	st_copy_string1

copy_st_lp1:
	ldr	r7,[r12],#4
	str	r7,[r6],#4
st_copy_string1:
	subs	r10,r10,#1
	bcs	copy_st_lp1

	mov	r2,r6
	sub	r1,r1,r6
	add	r9,r1,r4
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12	
	bl	file_read_line
	mov	sp,r7

	mov	r2,r8

	cmp	r0,#0
	bmi	readLineF_again

	ldr	r1,[r2,#4]
	add	r1,r1,r0
	str	r1,[r2,#4]
	adds	r7,r0,#3
	mov	r0,r4
	and	r7,r7,#-4
	add	r6,r6,r7
	add	r7,r1,#8+3
	sub	r11,r11,r7,lsr #2
	mov	r1,#-1
	pop	{pc}

readLineF_gc:
	mov	r11,r10
	bl	collect_0
	add	r11,r11,#32+2
	b	readLineF_r_gc

@	.d 0 3 i f # r10 r0 r1
@	jsr writeFI
@	.o 0 2 f # r0 r1

writeFC:
	mov	r4,r0
	mov	r1,r0
	mov	r0,r10

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_write_char
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 3 i f # r10 r0 r1
@	jsr writeFI
@	.o 0 2 f # r0 r1

writeFI:
	mov	r4,r0
	mov	r1,r0
	mov	r0,r10

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_write_int
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 4 r f # d0 r0 r1
@	jsr writeFR
@	.o 0 2 f # r0 r1

writeFR:
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
 	bl	file_write_real
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 1 2 f # r2 r0 r1
@	jsr writeFS
@	.o 0 2 f # r0 r1

writeFS:
	ldr	r1,[r2,#4]
	mov	r4,r0
	add	r0,r2,#8
	mov	r2,r4

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_write_characters
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 1 4 i i f # r2 r9 r10 r0 r1
@	jsr writeFString
@	.o 0 2 f # r0 r1

writeFString:
	ldr	r8,[r2,#4]
	cmp	r9,r8
	bhs	writeFString_error

	sub	r8,r8,r9
	cmp	r10,r8
	bhi	writeFString_error

	mov	r4,r0
	mov	r1,r10
	add	r0,r2,#8
	mov	r2,r4
	add	r0,r0,r9

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_write_characters
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

writeFString_error:
	lao	r4,fwritestring_error,0
	otoa	r4,fwritestring_error,0
	b	print_error

@	.d 0 2 f # r0 r1
@	jsr endF
@	.o 0 3 b f # r10 r0 r1

endF:
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_end
 	mov	sp,r7

	neg	r10,r0
	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr errorF
@	.o 0 3 b f # r10 r0 r1

errorF:
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_error
 	mov	sp,r7

	neg	r10,r0
	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr positionF
@	.o 0 3 i f # r10 r0 r1

positionF:
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_position
 	mov	sp,r7

	mov	r10,r0
	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 4 f i i # r9 r10 r0 r1 
@	jsr seekF
@	.o 0 3 b f # r10 r0 r1

seekF:
	mov	r2,r1
	mov	r1,r0
	mov	r0,r9
	mov	r4,r9

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_seek
 	mov	sp,r7

	neg	r10,r0
	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr shareF
@	.o 0 2 f # r0 r1

shareF:
	mov	r4,r0

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_share
 	mov	sp,r7

	mov	r0,r4
	mov	r1,#-1
	pop	{pc}

@	.d 1 1 i # r2 r1
@	jsr	openSF
@	.o 0 3 b f # r10 r0 r1

openSF:
	add	r0,r2,#4

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	open_s_file
 	mov	sp,r7

	cmp	r0,#0
	ite	mi
	movmi	r10,#0
	movpl	r10,#1

	movs	r1,#0
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	readSFC
@	.o 0 4 b c f # r9 r10 r0 r1 

readSFC:
	push	{r1}
	mov	r4,r0
	mov	r1,sp

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_s_char
 	mov	sp,r7

	pop	{r1}
	cmp	r0,#-1
	beq	readSFC_eof

	mov	r10,r0
	mov	r0,r4
	mov	r9,#1
	pop	{pc}

readSFC_eof:
	mov	r0,r4
	mov	r10,#0
	mov	r9,#0
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr	readSFI
@	.o 0 4 b i f # r9 r10 r0 r1

readSFI:
	push	{r1}
	mov	r4,r0
	mov	r2,sp
	sub	r1,sp,#4
	sub	sp,sp,#4

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_s_int
 	mov	sp,r7

	ldr	r10,[sp],#4
	neg	r9,r0
	mov	r0,r4
	pop	{r1,pc}

@	.d 0 2 f # r0 r1
@	jsr	readSFR
@	.o 0 5 b r f # r10 d0 r0 r1

readSFR:
	push	{r1}
	mov	r4,r0
	mov	r2,sp

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12

	sub	r1,sp,#8
	sub	sp,sp,#8
	bl	file_read_s_real
	vldr.f64	d0,[sp]

	mov	sp,r7

	neg	r10,r0
	mov	r0,r4
	pop	{r1,pc}

@	.d 0 3 f i # r10 r0 r1
@	jsr readSFS
@	.o 1 2 f # r2 r0 r1

readSFS:
	add	r7,r1,#8+3
	subs	r9,r11,r7,lsr #2
	blo	readSFS_gc

readSFS_r_gc:
	laol	r7,__STRING__+2,__STRING___o_2,3
	otoa	r7,__STRING___o_2,3
	str	r7,[r6]
	mov	r4,r10
	push	{r0}
	mov	r0,r10
	add	r2,r6,#4
	mov	r3,sp

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_s_string
	mov	sp,r7

	pop	{r1}

readSFS_end:
	add	r7,r0,#8+3
	mov	r0,r4
	mov	r2,r6
	and	r7,r7,#-4
	add	r6,r6,r7
	sub	r11,r11,r7,lsr #2
	pop	{pc}

readSFS_gc:
	mov	r11,r9
	bl	collect_0
	add	r7,r1,#8+3
	add	r11,r11,r7,lsr #2
	b	readSFS_r_gc

@	.d 0 2 f # r0 r1
@	jsr readLineSF
@	.o 1 2 f # r2 r0 r1

readLineSF:
	subs	r10,r11,#32+2
	blo	readLineSF_gc

readLineSF_r_gc:
	laol	r7,__STRING__+2,__STRING___o_2,4
	otoa	r7,__STRING___o_2,4

	add	r2,r6,#8
	str	r7,[r6]
	push	{r1}
	lsl	r1,r11,#2
	mov	r4,r0
	subs	r1,#8
	mov	r3,sp
	mov	r9,r1

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_s_line
	mov	sp,r7

	pop	{r1}
	str	r0,[r6,#4]

	cmp	r0,#0
	bpl	readSFS_end

	mov	r2,r6

readLineSF_again:
	str	r9,[r2,#4]

	add	r6,#8
	mov	r11,#-(32+4)
	add	r6,r6,r9
	sub	r11,r11,r9,lsr #2
	mov	r0,r4
	bl	collect_1

	ldr	r4,[r2,#4]
	add	r11,r11,#32+4
	add	r12,r2,#8

	add	r11,r11,r4,lsr #2

	mov	r8,r6

	laol	r7,__STRING__+2,__STRING___o_2,5
	otoa	r7,__STRING___o_2,5

	push	{r1}

	add	r1,r6,r11,lsl #2
	str	r7,[r6]

	add	r10,r4,#3
	lsr	r10,r10,#2

	str	r4,[r6,#4]
	adds	r6,#8
	b	st_copy_string2

copy_st_lp2:
	ldr	r7,[r12],#4
	str	r7,[r6],#4
st_copy_string2:
	subs	r10,r10,#1
	bcs	copy_st_lp2

	mov	r2,r6
	sub	r1,r1,r6
	add	r9,r1,r4
	mov	r4,r0
	mov	r3,sp

	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_read_s_line
	mov	sp,r7

	pop	{r1}

	mov	r2,r8

	cmp	r0,#0
	bmi	readLineSF_again

	ldr	r10,[r2,#4]
	adds	r7,r0,#3
	add	r10,r10,r0
	str	r10,[r2,#4]
	mov	r0,r4
	and	r7,r7,#-4
	add	r6,r6,r7
	add	r7,r10,#8+3
	sub	r11,r11,r7,lsr #2
	pop	{pc}

readLineSF_gc:
	mov	r11,r10
	bl	collect_0
	add	r11,r11,#32+2
	b	readLineSF_r_gc

@	.d 0 2 f # r0 r1
@	jsr endSF
@	.o 0 1 b # r1

endSF:
	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_s_end
 	mov	sp,r7

	neg	r1,r0
	pop	{pc}

@	.d 0 2 f # r0 r1
@	jsr positionSF
@	.o 0 1 i # r1

positionSF:
	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_s_position
 	mov	sp,r7

	mov	r1,r0
	pop	{pc}

@	.d 0 4 f i i # r9 r10 r0 r1
@	jsr seekSF
@	.o 0 3 b f # r10 r0 r1

seekSF:
	str	r10,[sp,#-4]!
	mov	r4,r9
	mov	r0,r9
	mov	r1,r0
	mov	r2,r1
	mov	r3,sp
	
	mov	r7,sp
	bic	r12,r7,#4
	mov	sp,r12
	bl	file_s_seek
 	mov	sp,r7

	neg	r10,r0
	mov	r0,r4
	pop	{r1,pc}

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
