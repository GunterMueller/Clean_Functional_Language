
#define d0 %eax
#define d1 %ebx
#define a0 %ecx
#define a1 %edx
#define a2 %ebp
#define a3 %esi
#define a4 %edi
#define a5 %esp
#define sp %esp

// # saved registers: %ebx %esi %edi %ebp
// #                   d1   a3   a4   a2

	.data
#if defined (DOS) || defined (_WINDOWS_) || defined (ELF)
	.align	8
#else
	.align	3
#endif

tmp_real:	.double	0
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
#ifndef OLD_READ_STRING
	.globl	readFString
#endif
	.globl	readLineF
	.globl	writeFC
	.globl	writeFI
	.globl	writeFR
	.globl	writeFS
#ifndef OLD_WRITE_STRING
	.globl	writeFString
#endif
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

// # imports

	.globl	@open_file
	.globl	@open_stdio
	.globl	@open_stderr
	.globl	@re_open_file
	.globl	@close_file
	.globl	@file_read_char
	.globl	@file_read_int
	.globl	@file_read_real
#ifdef OLD_READ_STRING
	.globl	@file_read_string
#else
	.globl	@file_read_characters
#endif
	.globl	@file_read_line
	.globl	@file_write_char
	.globl	@file_write_int
	.globl	@file_write_real
#ifdef OLD_WRITE_STRING
	.globl	@file_write_string
#else
	.globl	@file_write_characters
#endif
	.globl	@file_end
	.globl	@file_error
	.globl	@file_position
	.globl	@file_seek
	.globl	@file_share
	.globl	@flush_file_buffer
	.globl	@open_s_file
	.globl	@file_read_s_char
	.globl	@file_read_s_int
	.globl	@file_read_s_real
	.globl	@file_read_s_string
	.globl	@file_read_s_line
	.globl	@file_s_end
	.globl	@file_s_position
	.globl	@file_s_seek

	.globl	collect_0
	.globl	collect_1

	.globl	__STRING__

stdioF:	call	@open_stdio
	movl	d0,d1
	movl	$-1,d0
	ret

stderrF:	call	@open_stderr
	movl	d0,d1
	movl	$-1,d0
	ret

openF:	pushl	d0
	addl	$4,a0
	pushl	a0
	call	@open_file
	addl	$8,sp

	xorl	d1,d1
	testl	d0,d0
	setns	%bl
	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

closeF:	pushl	d1
	call	@close_file
	addl	$4,sp
	ret

reopenF:
// #	popl	d0
// #	pushl	d0
	pushl	d1
	call	@re_open_file
	addl	$8,sp

	xchg	d0,d1
	
	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

readFC:
	pushl	d1

	pushl	d1
	call	@file_read_char
	addl	$4,sp

	movl	4(sp),a2
	movl	$-1,4(sp)

	cmpl	$-1,d0
	je	readFC_eof

	movl	$1,d1
	jmp	*a2

readFC_eof:
	xorl	d0,d0
	xorl	d1,d1
	jmp	*a2

readFI:
	pushl	d1

	subl	$8,sp
	lea	4(sp),a2
	movl	a2,(sp)
	pushl	d1
	call	@file_read_int
	addl	$8,sp

	movl	d0,d1
	popl	d0

	movl	4(sp),a2
	movl	$-1,4(sp)
	jmp	*a2

readFR:
	pushl	$tmp_real
	pushl	d1
	finit
	call	@file_read_real
	addl	$8,sp

	fldl	tmp_real
	fstp	%st(1)
	
	xchg	d0,d1

	movl	(sp),a2
	movl	$-1,(sp)	
	jmp	*a2

#ifndef OLD_READ_STRING
readFString:
	movl	4(a0),a2
	cmpl	a2,d1
	jae	readFString_error

	subl	d1,a2
	cmpl	a2,d0
	ja	readFString_error

	movl	(sp),a1
	pushl	a0

	pushl	d0
	movl	sp,a2
	lea	8(a0,d1),a0

	pushl	a0
	pushl	a2
	pushl	a1
	call	@file_read_characters
	addl	$12+4,sp

	popl	a0
	
	movl	d0,d1
	popl	d0
	
	addl	$4,sp
	popl	a2
	pushl	$-1
	jmp	*a2

readFString_error:
	movl	$freadstring_error,a2
	jmp	print_error
#endif

readFS:	popl	a1
	lea	3(a1),a2
	andl	$-4,a2
	lea	-32+8(a4,a2),a2
	cmpl	end_heap,a2
	ja	readFS_gc
readFS_r_gc:

#ifdef OLD_READ_STRING
	movl	$__STRING__+2,(a4)
	addl	$4,a4
	
	pushl	a4
	pushl	a1
	pushl	d1
	call	@file_read_string
	addl	$12,sp
#else
	movl	$__STRING__+2,(a4)

	lea	8(a4),a2
	addl	$4,a4

	pushl	a2
	movl	a1,(a4)
	pushl	a4	
	pushl	d1
	call	@file_read_characters
	addl	$12,sp	
#endif
readFS_end:
	lea	-4(a4),a0

	addl	$3,d0
	andl	$-4,d0
	lea	4(a4,d0),a4

	movl	$-1,d0
	ret

readFS_gc:	pushl	a1
	call	collect_0l
	popl	a1
	jmp	readFS_r_gc

readLineF:
	lea	-32+(4*(32+2))(a4),a2
	cmpl	end_heap,a2
	ja	readLineF_gc

readLineF_r_gc:
	movl	$__STRING__+2,(a4)
	lea	8(a4),a0
	addl	$4,a4

	pushl	a0
	movl	end_heap,a1
	addl	$32-4,a1
	subl	a4,a1
	pushl	a1
	pushl	d1
	call	@file_read_line
	addl	$12,sp

	movl	d0,(a4)

	testl	d0,d0
	jns	readFS_end

	lea	-4(a4),a0

readLineF_again:
	movl	end_heap,a1
	addl	$32,a1
	lea	-8(a1),d0
	subl	a0,d0
	movl	d0,4(a0)
	movl	a1,a4

	lea	-32+4*(32+2)(a4,d0),a2
	call	collect_1l

	movl	4(a0),d0
	lea	8(a0),a1
	
	pushl	a4

	movl	$__STRING__+2,(a4)

	lea	3(d0),a0
	shr	$2,a0

	movl	d0,4(a4)
	addl	$8,a4
	jmp	st_copy_string1

copy_st_lp1:
	movl	(a1),a2
	addl	$4,a1
	movl	a2,(a4)
	addl	$4,a4
st_copy_string1:
	subl	$1,a0
	jnc	copy_st_lp1

	pushl	a4
	movl	end_heap,a2
	addl	$32,a2
	subl	a4,a2
	pushl	a2
	pushl	d1
	call	@file_read_line
	addl	$12,sp

	popl	a0

	testl	d0,d0
	js	readLineF_again

	addl	d0,4(a0)
	addl	$3,d0
	andl	$-4,d0
	addl	d0,a4

	movl	$-1,d0
	ret

readLineF_gc:
	call	collect_0l
	jmp	readLineF_r_gc

writeFC:
	movl	d0,(sp)
	pushl	d1
	movl	d0,d1
	call	@file_write_char
	addl	$8,sp

	movl	$-1,d0
	ret

writeFI:
	movl	d0,(sp)
	pushl	d1
	movl	d0,d1
	call	@file_write_int
	addl	$8,sp

	movl	$-1,d0
	ret

writeFR:
	pushl	d1
	subl	$8,sp
	fstpl	(sp)
	finit
 	call	@file_write_real
	addl	$12,sp

	movl	$-1,d0
	ret

writeFS:
	pushl	d1
#ifdef OLD_WRITE_STRING
	addl	$4,a0
	pushl	a0
	call	@file_write_string
	addl	$8,sp
#else
	pushl	4(a0)
	addl	$8,a0
	pushl	a0
	call	@file_write_characters
	addl	$12,sp
#endif
	movl	$-1,d0
	ret

#ifndef OLD_WRITE_STRING
writeFString:
	movl	4(a0),a2
	cmpl	a2,d1
	jae	writeFString_error

	subl	d1,a2
	cmpl	a2,d0
	ja	writeFString_error

	lea	8(a0,d1),a0
	movl	(sp),d1

	pushl	d0
	pushl	a0
	call	@file_write_characters
	addl	$12+4,sp

	movl	$-1,d0

	ret

writeFString_error:
	movl	$fwritestring_error,a2
	jmp	print_error
#endif

endF:
	pushl	d1
	call	@file_end
	addl	$4,sp

	xchg	d0,d1

	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

errorF:
	pushl	d1
	call	@file_error
	addl	$4,sp

	xchg	d0,d1

	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

positionF:
	pushl	d1
	call	@file_position
	addl	$4,sp

	xchg	d0,d1

	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

seekF:
	pushl	d1
	call	@file_seek
	addl	$12,sp

	xchg	d0,d1

	movl	(sp),a2
	movl	$-1,(sp)
	jmp	*a2

shareF:
	pushl	d1
	call	@file_share
	addl	$4,sp
	
	movl	$-1,d0
	ret

flushF:
	pushl	d1
	call	@flush_file_buffer
	movl	4(sp),a2
	xchg	d0,d1
	movl	$-1,4(sp)
	movl	a2,(sp)
	ret

openSF:	pushl	d0
	addl	$4,a0
	pushl	a0
	call	@open_s_file
	addl	$8,sp

	xorl	d1,d1
	testl	d0,d0
	setns	%bl

	movl	(sp),a2
	movl	$0,(sp)
	jmp	*a2

readSFC:
	pushl	d0
	movl	sp,a2
	pushl	a2
	pushl	d1
	call	@file_read_s_char
	addl	$8,sp

	popl	a0
	popl	a2

	pushl	a0
	pushl	d1

	cmpl	$-1,d0
	je	readSFC_eof

	movl	$1,d1
	jmp	*a2

readSFC_eof:
	xorl	d0,d0
	xorl	d1,d1
	jmp	*a2

readSFI:
	pushl	d0
	movl	sp,a2
	subl	$4,sp
	pushl	a2
	subl	$4,a2
	pushl	a2
	pushl	d1
	call	@file_read_s_int
	addl	$12,sp

	popl	a0
	popl	a1
	popl	a2

	pushl	a1
	pushl	d1
	movl	d0,d1
	movl	a0,d0
	jmp	*a2

readSFR:
	pushl	d0
	movl	sp,a2
	pushl	a2
	pushl	$tmp_real
	pushl	d1
	finit
	call	@file_read_s_real
	addl	$12,sp

	fldl	tmp_real
	xchg	d0,d1
	fstp	%st(1)

	popl	a0
	movl	(sp),a2
	movl	a0,(sp)
	jmp	*a2

readSFS:
	popl	a1
	lea	3(a1),a2
	andl	$-4,a2
	lea	-32+8(a4,a2),a2
	cmpl	end_heap,a2
	ja	readSFS_gc

readSFS_r_gc:
	movl	$__STRING__+2,(a4)
	addl	$4,a4

	pushl	d0
	movl	sp,a2
	pushl	a2
	pushl	a4
	pushl	a1
	pushl	d1
	call	@file_read_s_string
	addl	$16,sp

readSFS_end:
	lea	-4(a4),a0

	addl	$3,d0
	andl	$-4,d0
	lea	4(a4,d0),a4

	popl	d0
	ret

readSFS_gc:	pushl	a1
	call	collect_0l
	popl	a1
	jmp	readSFS_r_gc

readLineSF:
	lea	-32+(4*(32+2))(a4),a2
	cmpl	end_heap,a2
	ja	readLineSF_gc

readLineSF_r_gc:
	movl	$__STRING__+2,(a4)
	lea	8(a4),a0
	addl	$4,a4

	pushl	d0
	movl	sp,a2
	pushl	a2
	pushl	a0
	movl	end_heap,a1
	addl	$32-4,a1
	subl	a4,a1
	pushl	a1
	pushl	d1
	call	@file_read_s_line
	addl	$16,sp

	movl	d0,(a4)

	testl	d0,d0
	jns	readSFS_end

	lea	-4(a4),a0

readLineSF_again:
	movl	end_heap,a1
	addl	$32,a1
	lea	-8(a1),d0
	subl	a0,d0
	movl	d0,(a4)
	movl	a1,a4

	lea	-32+4*(32+2)(a4,d0),a2
	call	collect_1l

	movl	4(a0),d0
	lea	8(a0),a1

	pushl	a4

	movl	$__STRING__+2,(a4)

	lea	3(d0),a0
	shr	$2,a0

	movl	d0,4(a4)
	addl	$8,a4
	jmp	st_copy_string2

copy_st_lp2:
	movl	(a1),a2
	addl	$4,a1
	movl	a2,(a4)
	addl	$4,a4
st_copy_string2:
	subl	$1,a0
	jnc	copy_st_lp2

	lea	4(sp),a2
	pushl	a2
	pushl	a4
	movl	end_heap,a2
	addl	$32,a2
	subl	a4,a2
	pushl	a2
	pushl	d1
	call	@file_read_s_line
	addl	$16,sp

	popl	a0

	testl	d0,d0
	js	readLineSF_again
	
	addl	d0,4(a0)
	addl	$3,d0
	andl	$-4,d0
	addl	d0,a4

	popl	d0
	ret

readLineSF_gc:
	call	collect_0l
	jmp	readLineSF_r_gc

endSF:
	pushl	d0
	pushl	d1
	call	@file_s_end
	addl	$8,sp
	ret

positionSF:
	pushl	d0
	pushl	d1
	call	@file_s_position
	addl	$8,sp
	ret

seekSF:
	popl	a1
	popl	a0

	pushl	d0
	movl	sp,a2
	pushl	a2
	pushl	a0
	pushl	a1
	pushl	d1
	call	@file_s_seek
	addl	$16,sp

	popl	a0

	xchg	d0,d1

	movl	(sp),a2
	movl	a0,(sp)
	jmp	*a2
