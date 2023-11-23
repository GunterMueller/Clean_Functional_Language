
	.intel_syntax noprefix

	.data
	.align	8

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
.if 0
	.globl	flushF
.endif
	.globl	openSF
	.globl	readSFC
	.globl	readSFI
	.globl	readSFR
	.globl	readSFS
	.globl	readLineSF
	.globl	endSF
	.globl	positionSF
	.globl	seekSF

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
.if 0
	.globl	flush_file_buffer
.endif
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

	.globl	print_error

	.globl	__STRING__

stdioF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	call	open_stdio
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rbx,rax
	mov	rax,-1
	ret

stderrF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	call	open_stderr
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rbx,rax
	mov	rax,-1
	ret

openF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	lea	rdi,8[rcx]
	call	open_file
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	xor	r10,r10
	test	rax,rax
	setns	r10b
	mov	rbx,rax
	mov	rax,-1
	ret

closeF:	
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	close_file
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14
	ret

reopenF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	rbx,r10
	mov	r14,rdi
	mov	rdi,r10
	call	re_open_file
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10d,eax	
	mov	rax,-1
	ret

readFC:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_char
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	cmp	eax,-1
	je	readFC_eof

	mov	r10,rax
	mov	rax,-1
	mov	r11,1
	ret

readFC_eof:
	xor	r10,r10
	mov	rax,-1
	xor	r11,r11
	ret

readFI:
	mov	rbp,rsp
	sub	rsp,8
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	lea	rsi,[rsp]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_int
	mov	r10,[rsp]
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r11,rax
	mov	rax,-1
	ret

readFR:
	mov	rbp,rsp
	sub	rsp,8
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	lea	rsi,[rsp]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_real

	movlpd	xmm0,[rsp]	
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1	
	ret

readFString:
	mov	rbp,8[rcx]
	cmp	r11,rbp
	jae	readFString_error

	sub	rbp,r11
	cmp	r10,rbp
	ja	readFString_error

	push	rcx

	push	r11

	lea	rdx,16[rcx+r11]
	mov	rbp,rsp
	or	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_characters
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	add	rsp,8
	pop	rcx
	
	mov	r10,rax
	mov	rax,-1
	ret

readFString_error:
	mov	rbp,offset freadstring_error
	jmp	print_error

readFS:	lea	rbp,16+7[rax]
	shr	rbp,3
	sub	r15,rbp
	jb	readFS_gc
readFS_r_gc:
	add	r15,rbp

	mov	qword ptr [rdi],offset __STRING__+2
	mov	8[rdi],rax
	mov	rbx,r10

	lea	rdx,16[rdi]
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	lea	rsi,8[rdi]
	mov	r14,rdi
	mov	rdi,r10
	call	file_read_characters
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

readFS_end:
	add	rax,16+7
	mov	rcx,rdi
	shr	rax,3
	sub	r15,rax
	lea	rdi,[rdi+rax*8]
	mov	rax,-1
	ret

readFS_gc:	push	rbp
	call	collect_0
	pop	rbp
	jmp	readFS_r_gc

readLineF:
	cmp	r15,32+2
	jb	readLineF_gc

readLineF_r_gc:
	mov	qword ptr [rdi],offset __STRING__+2

	lea	rdx,16[rdi]
	push	r9
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,-16[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_line
	mov	rsp,rbp
	pop	r9
	mov	rsi,r13
	mov	rdi,r14

	mov	8[rdi],rax

	test	rax,rax
	jns	readFS_end

	lea	rax,-16[r15*8]
	mov	r12,rdi
	mov	8[rdi],rax
	add	rdi,16

readLineF_lp:
	add	rdi,rax

	mov	r13,8[r12]
	mov	rcx,r12
	shr	r13,3
	xor	r15,r15
	add	r13,2+32
	sub	r15,r13
	
	call	collect_1

	add	r15,r13
	mov	rax,8[rcx]
	lea	rdx,16[rcx]
	lea	rcx,7[rax]
	shr	rcx,3
	sub	r15,2
	sub	r15,rcx

	mov	r12,rdi

	mov	qword ptr [rdi],offset __STRING__+2

	mov	8[rdi],rax
	add	rdi,16
	jmp	st_copy_string1

copy_st_lp1:
	mov	rbp,[rdx]
	add	rdx,8
	mov	[rdi],rbp
	add	rdi,8
st_copy_string1:
	sub	rcx,1
	jnc	copy_st_lp1

	mov	rdx,rdi
	push	r9
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_line
	mov	rsp,rbp
	pop	r9
	mov	rsi,r13
	mov	rdi,r14

	test	rax,rax
	js	readLineF_again

	add	8[r12],rax
	add	rax,7

	mov	rcx,r12

	shr	rax,3
	sub	r15,rax
	lea	rdi,[rdi+rax*8]

	mov	rax,-1
	ret

readLineF_gc:
	sub	r15,32+2
	call	collect_0
	add	r15,32+2
	jmp	readLineF_r_gc

readLineF_again:
	mov	rcx,8[r12]
	lea	rax,[r15*8]
	add	rcx,rax
	mov	8[r12],rcx
	jmp	readLineF_lp

writeFC:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbx
	mov	r14,rdi
	mov	rdi,r10
	call	file_write_char
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFI:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbx
	mov	r14,rdi
	mov	rdi,r10
	call	file_write_int
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFR:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
 	call	file_write_real
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFS:
	mov	rdx,rbx
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,8[rcx]
	mov	r14,rdi
	lea	rdi,16[rcx]
	call	file_write_characters
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFString:
	mov	rbp,8[rcx]
	cmp	r11,rbp
	jae	writeFString_error

	sub	rbp,r11
	cmp	r10,rbp
	ja	writeFString_error

	mov	rdx,rbx
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,r10
	mov	r14,rdi
	lea	rdi,16[rcx+r11]
	call	file_write_characters
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1

	ret

writeFString_error:
	mov	rbp,offset fwritestring_error
	jmp	print_error

endF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	file_end
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

errorF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	file_error
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

positionF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	file_position
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

seekF:
	mov	rdx,rax
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbx
	mov	rbx,r11
	mov	r14,rdi
	mov	rdi,r11
	call	file_seek
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

shareF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	file_share
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14
	
	mov	rax,-1
	ret
.if 0
flushF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	flush_file_buffer
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret
.endif

openSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	lea	rdi,8[rcx]
	call	open_s_file
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	xor	r10,r10
	test	rax,rax
	setns	r10b

	mov	rbx,rax
	xor	rax,rax
	ret

readSFC:
	push	rax

	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_s_char
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	cmp	eax,-1
	je	readSFC_eof

	mov	r10d,eax
	pop	rax
	mov	r11,1
	ret

readSFC_eof:
	pop	rax
	xor	r10,r10
	xor	r11,r11
	ret

readSFI:
	push	rax
	mov	rdx,rsp
	sub	rsp,8
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_s_int
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	pop	r10
	mov	r11,rax
	pop	rax
	
	ret

readSFR:
	push	rax
	mov	rdx,rsp
	sub	rsp,8
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_s_real
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	movlpd	xmm0,[rsp]
	mov	r10,rax
	add	rsp,8
	pop	rax

	ret

readSFS:
	lea	rbp,16+7[rax]
	shr	rbp,3
	sub	r15,rbp
	jb	readSFS_gc
readSFS_r_gc:
	add	r15,rbp

	mov	qword ptr [rdi],offset __STRING__+2

	push	rbx

	mov	rbx,r10
	
	mov	rcx,rsp
	lea	rdx,8[rdi]
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,r10
	call	file_read_s_string
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

readSFS_end:
	add	rax,16+7
	mov	rcx,rdi
	shr	rax,3
	sub	r15,rax
	lea	rdi,[rdi+rax*8]
	pop	rax
	ret

readSFS_gc:	push	rbp
	call	collect_0
	pop	rbp
	jmp	readSFS_r_gc

readLineSF:
	cmp	r15,32+2
	jb	readLineSF_gc

readLineSF_r_gc:
	push	rax

	mov	qword ptr [rdi],offset __STRING__+2

	mov	rcx,rsp
	lea	rdx,16[rdi]
	push	r9
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,-16[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_s_line
	mov	rsp,rbp
	pop	r9
	mov	rsi,r13
	mov	rdi,r14

	mov	8[rdi],rax

	test	rax,rax
	jns	readSFS_end

	lea	rax,-16[r15*8]
	mov	r12,rdi
	mov	8[rdi],rax
	add	rdi,16

readLineSF_lp:
	add	rdi,rax

	mov	r13,8[r12]
	mov	rcx,r12
	shr	r13,3
	xor	r15,r15
	add	r13,2+32
	sub	r15,r13

	call	collect_1

	add	r15,r13
	mov	rax,8[rcx]
	lea	rdx,16[rcx]
	lea	rcx,7[rax]
	shr	rcx,3
	sub	r15,2
	sub	r15,rcx

	mov	r12,rdi

	mov	qword ptr [rdi],offset __STRING__+2

	mov	8[rdi],rax
	add	rdi,16
	jmp	st_copy_string2

copy_st_lp2:
	mov	rbp,[rdx]
	add	rdx,8
	mov	[rdi],rbp
	add	rdi,8
st_copy_string2:
	sub	rcx,1
	jnc	copy_st_lp2

	mov	rcx,rsp
	mov	rdx,rdi
	push	r9
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	call	file_read_s_line
	mov	rsp,rbp
	pop	r9
	mov	rsi,r13
	mov	rdi,r14

	test	rax,rax
	js	readLineSF_again

	add	8[r12],rax
	add	rax,7

	mov	rcx,r12

	shr	rax,3
	sub	r15,rax
	lea	rdi,[rdi+rax*8]

	pop	rax
	ret

readLineSF_gc:
	sub	r15,32+2
	call	collect_0
	add	r15,32+2
	jmp	readLineSF_r_gc

readLineSF_again:
	mov	rcx,8[r12]
	lea	rax,[r15*8]
	add	rcx,rax
	mov	8[r12],rcx
	jmp	readLineSF_lp

endSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,rbx
	call	file_s_end
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	ret

positionSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,rbx
	call	file_s_position
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	ret

seekSF:
	push	rbx
	mov	rcx,rsp
	mov	rdx,rax

	mov	rbx,r11

	mov	rbp,rsp
	and	rsp,-16
	mov	r12,r9
	mov	r13,rsi
	mov	rsi,r10
	mov	r14,rdi
	mov	rdi,r11
	call	file_s_seek
	mov	rsp,rbp
	mov	r9,r12
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax	
	pop	rax

	ret
