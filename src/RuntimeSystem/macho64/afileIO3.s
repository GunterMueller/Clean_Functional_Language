
	.intel_syntax noprefix

	.macro att_jmp
	.att_syntax
	jmp	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_call
	.att_syntax
	call	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_ja
	.att_syntax
	ja	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jnc
	.att_syntax
	jnc	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jns
	.att_syntax
	jns	$0
	.intel_syntax noprefix
	.endmacro

	.data
	.align	3

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

	.globl	_open_file
	.globl	_open_stdio
	.globl	_open_stderr
	.globl	_re_open_file
	.globl	_close_file
	.globl	_file_read_char
	.globl	_file_read_int
	.globl	_file_read_real
	.globl	_file_read_characters
	.globl	_file_read_line
	.globl	_file_write_char
	.globl	_file_write_int
	.globl	_file_write_real
	.globl	_file_write_characters
	.globl	_file_end
	.globl	_file_error
	.globl	_file_position
	.globl	_file_seek
	.globl	_file_share
	.globl	_flush_file_buffer
	.globl	_open_s_file
	.globl	_file_read_s_char
	.globl	_file_read_s_int
	.globl	_file_read_s_real
	.globl	_file_read_s_string
	.globl	_file_read_s_line
	.globl	_file_s_end
	.globl	_file_s_position
	.globl	_file_s_seek

	.globl	collect_0
	.globl	collect_1

	.globl	print_error

	.globl	__STRING__

stdioF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	att_call	_open_stdio
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rbx,rax
	mov	rax,-1
	ret

stderrF:	
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	att_call	_open_stderr
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rbx,rax
	mov	rax,-1
	ret

openF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	lea	rdi,[rcx+8]
	att_call	_open_file
	mov	rsp,rbp
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
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_close_file
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	ret

reopenF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	rbx,r10
	mov	r14,rdi
	mov	rdi,r10
	att_call	_re_open_file
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10d,eax	
	mov	rax,-1
	ret

readFC:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_char
	mov	rsp,rbp
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
	mov	r13,rsi
	lea	rsi,[rsp]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_int
	mov	r10,[rsp]
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r11,rax
	mov	rax,-1
	ret

readFR:
	mov	rbp,rsp
	sub	rsp,8
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[rsp]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_real

	movlpd	xmm0,[rsp]	
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1	
	ret

readFString:
	mov	rbp,[rcx+8]
	cmp	r11,rbp
	jae	readFString_error

	sub	rbp,r11
	cmp	r10,rbp
	att_ja	readFString_error

	push	rcx

	push	r11

	lea	rdx,[rcx+r11+16]
	mov	rbp,rsp
	or	rsp,-16
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_characters
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	add	rsp,8
	pop	rcx
	
	mov	r10,rax
	mov	rax,-1
	ret

readFString_error:
	lea	rbp,[rip+freadstring_error]
	att_jmp	print_error

readFS:	lea	rbp,[rax+16+7]
	shr	rbp,3
	sub	r15,rbp
	jb	readFS_gc
readFS_r_gc:
	add	r15,rbp

	lea	rbx,[rip+__STRING__+2]
	mov	qword ptr [rdi],rbx
	mov [rdi+8],rax
	mov	rbx,r10

	lea	rdx,[rdi+16]
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[rdi+8]
	mov	r14,rdi
	mov	rdi,r10
	att_call	_file_read_characters
	mov	rsp,rbp
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
	att_call	collect_0
	pop	rbp
	att_jmp	readFS_r_gc

readLineF:
	cmp	r15,32+2
	jb	readLineF_gc

readLineF_r_gc:
	lea	rdx,[rip+__STRING__+2]
	mov	qword ptr [rdi],rdx

	lea	rdx,[rdi+16]
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8-16]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_line
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov [rdi+8],rax

	test	rax,rax
	att_jns	readFS_end

	lea	rax,[r15*8-16]
	mov	r12,rdi
	mov [rdi+8],rax
	add	rdi,16

readLineF_lp:
	add	rdi,rax

	mov	r13,[r12+8]
	mov	rcx,r12
	shr	r13,3
	xor	r15,r15
	add	r13,2+32
	sub	r15,r13
	
	att_call	collect_1

	add	r15,r13
	mov	rax,[rcx+8]
	lea	rdx,[rcx+16]
	lea	rcx,[rax+7]
	shr	rcx,3
	sub	r15,2
	sub	r15,rcx

	mov	r12,rdi

	lea	rbp,[rip+__STRING__+2]
	mov	qword ptr [rdi],rbp

	mov [rdi+8],rax
	add	rdi,16
	jmp	st_copy_string1

copy_st_lp1:
	mov	rbp,[rdx]
	add	rdx,8
	mov	[rdi],rbp
	add	rdi,8
st_copy_string1:
	sub	rcx,1
	att_jnc	copy_st_lp1

	mov	rdx,rdi
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_line
	mov	rsp,rbp
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
	att_call	collect_0
	add	r15,32+2
	att_jmp	readLineF_r_gc

readLineF_again:
	mov	rcx,[r12+8]
	lea	rax,[r15*8]
	add	rcx,rax
	mov [r12+8],rcx
	att_jmp	readLineF_lp

writeFC:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rbx
	mov	r14,rdi
	mov	rdi,r10
	att_call	_file_write_char
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFI:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rbx
	mov	r14,rdi
	mov	rdi,r10
	att_call	_file_write_int
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFR:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
 	att_call	_file_write_real
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFS:
	mov	rdx,rbx
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,[rcx+8]
	mov	r14,rdi
	lea	rdi,[rcx+16]
	att_call	_file_write_characters
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1
	ret

writeFString:
	mov	rbp,[rcx+8]
	cmp	r11,rbp
	jae	writeFString_error

	sub	rbp,r11
	cmp	r10,rbp
	att_ja	writeFString_error

	mov	rdx,rbx
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,r10
	mov	r14,rdi
	lea	rdi,[rcx+r11+16]
	att_call	_file_write_characters
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	rax,-1

	ret

writeFString_error:
	lea	rbp,[rip+fwritestring_error]
	att_jmp	print_error

endF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_end
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

errorF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_error
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

positionF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_position
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

seekF:
	mov	rdx,rax
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rbx
	mov	rbx,r11
	mov	r14,rdi
	mov	rdi,r11
	att_call	_file_seek
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

shareF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_share
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	
	mov	rax,-1
	ret

flushF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rbx
	call	_flush_file_buffer
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax
	mov	rax,-1
	ret

openSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	lea	rdi,[rcx+8]
	att_call	_open_s_file
	mov	rsp,rbp
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
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_s_char
	mov	rsp,rbp
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
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_s_int
	mov	rsp,rbp
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
	mov	r13,rsi
	mov	rsi,rbp
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_s_real
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	movlpd	xmm0,[rsp]
	mov	r10,rax
	add	rsp,8
	pop	rax

	ret

readSFS:
	lea	rbp,[rax+16+7]
	shr	rbp,3
	sub	r15,rbp
	jb	readSFS_gc
readSFS_r_gc:
	add	r15,rbp

	lea	rcx,[rip+__STRING__+2]
	mov	qword ptr [rdi],rcx

	push	rbx

	mov	rbx,r10
	
	mov	rcx,rsp
	lea	rdx,[rdi+8]
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,r10
	att_call	_file_read_s_string
	mov	rsp,rbp
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
	att_call	collect_0
	pop	rbp
	att_jmp	readSFS_r_gc

readLineSF:
	cmp	r15,32+2
	ja	readLineSF_gc

readLineSF_r_gc:
	push	rax

	lea	rcx,[rip+__STRING__+2]
	mov	qword ptr [rdi],rcx

	mov	rcx,rsp
	lea	rdx,[rdi+16]
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8-16]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_s_line
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov [rdi+8],rax

	test	rax,rax
	att_jns	readSFS_end

	lea	rax,[r15*8-16]
	mov	r12,rdi
	mov [rdi+8],rax
	add	rdi,16

readLineSF_lp:
	add	rdi,rax

	mov	r13,[r12+8]
	mov	rcx,r12
	shr	r13,3
	xor	r15,r15
	add	r13,2+32
	sub	r15,r13

	att_call	collect_1

	add	r15,r13
	mov	rax,[rcx+8]
	lea	rdx,[rcx+16]
	lea	rcx,[rax+7]
	shr	rcx,3
	sub	r15,2
	sub	r15,rcx

	mov	r12,rdi

	lea	rbp,[rip+__STRING__+2]
	mov	qword ptr [rdi],rbp

	mov [rdi+8],rax
	add	rdi,16
	jmp	st_copy_string2

copy_st_lp2:
	mov	rbp,[rdx]
	add	rdx,8
	mov	[rdi],rbp
	add	rdi,8
st_copy_string2:
	sub	rcx,1
	att_jnc	copy_st_lp2

	mov	rcx,rsp
	mov	rdx,rdi
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	lea	rsi,[r15*8]
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_read_s_line
	mov	rsp,rbp
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
	att_call	collect_0
	add	r15,32+2
	att_jmp	readLineSF_r_gc

readLineSF_again:
	mov	rcx,[r12+8]
	lea	rax,[r15*8]
	add	rcx,rax
	mov [r12+8],rcx
	att_jmp	readLineSF_lp

endSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_s_end
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	ret

positionSF:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	rsi,rax
	mov	r14,rdi
	mov	rdi,rbx
	att_call	_file_s_position
	mov	rsp,rbp
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
	mov	r13,rsi
	mov	rsi,r10
	mov	r14,rdi
	mov	rdi,r11
	att_call	_file_s_seek
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14

	mov	r10,rax	
	pop	rax

	ret
