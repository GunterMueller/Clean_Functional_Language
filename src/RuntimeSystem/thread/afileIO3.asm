
; nonvolatile registers: rbx rsi rdi rbp r12 r13 r14 r15
; volatile    registers: rax rcx rdx r8 r9 r10 r11

	THREAD equ 1

_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	_DATA segment
	align	8

freadstring_error:
	db	"Error in freadsubstring parameters."
	db	10,0
	db	0,0,0
fwritestring_error:
	db	"Error in fwritesubstring parameters."
	db	10,0
	db	0,0

	extrn	clean_exception_handler:near
	public	clean_unwind_info
clean_unwind_info:
	DD	000000009H
	DD	imagerel(clean_exception_handler)

_DATA	ends

	_TEXT segment

	public	stdioF
	public	stderrF
	public	openF
	public	closeF
	public	reopenF
	public	readFC
	public	readFI
	public	readFR
	public	readFS
	public	readFString
	public	readLineF
	public	writeFC
	public	writeFI
	public	writeFR
	public	writeFS
	public	writeFString
	public	endF
	public	errorF
	public	positionF
	public	seekF
	public	shareF
	public	flushF
	public	openSF
	public	readSFC
	public	readSFI
	public	readSFR
	public	readSFS
	public	readLineSF
	public	endSF
	public	positionSF
	public	seekSF

; imports

	extrn	open_file:near
	extrn	open_stdio:near
	extrn	open_stderr:near
	extrn	re_open_file:near
	extrn	close_file:near
	extrn	file_read_char:near
	extrn	file_read_int:near
	extrn	file_read_real:near
	extrn	file_read_characters:near
	extrn	file_read_line:near
	extrn	file_write_char:near
	extrn	file_write_int:near
	extrn	file_write_real:near
	extrn	file_write_characters:near
	extrn	file_end:near
	extrn	file_error:near
	extrn	file_position:near
	extrn	file_seek:near
	extrn	file_share:near
	extrn	flush_file_buffer:near
	extrn	open_s_file:near
	extrn	file_read_s_char:near
	extrn	file_read_s_int:near
	extrn	file_read_s_real:near
	extrn	file_read_s_string:near
	extrn	file_read_s_line:near
	extrn	file_s_end:near
	extrn	file_s_position:near
	extrn	file_s_seek:near

	extrn	collect_0:near
	extrn	collect_1:near

	extrn	print_error:near

	extrn	__STRING__:near

stdioF:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,32
	call	open_stdio
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rbx,rax
	mov	rax,-1
	ret

stderrF:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,32
	call	open_stderr
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rbx,rax
	mov	rax,-1
	ret

openF:
	mov	rbp,rsp
	and	rsp,-16

	mov	rdx,rax
	add	rcx,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,32
	call	open_file
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	xor	r10,r10
	test	rax,rax
	setns	r10b
	mov	rbx,rax
	mov	rax,-1
	ret

closeF:	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	close_file
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	ret

reopenF:
	mov	rdx,rax
	mov	rcx,r10
	mov	rbx,r10

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	re_open_file
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10d,eax
	mov	rax,-1
	ret

readFC:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_char
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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
	sub	rsp,40+8
 if THREAD
	mov	r14,r9
 endif
	and	rsp,-16

	lea	rdx,32[rsp]
	mov	rcx,rbx
	call	file_read_int

	mov	r10,32[rsp]

	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r11,rax
	mov	rax,-1
	ret

readFR:
	mov	rbp,rsp
	sub	rsp,40+8
 if THREAD
	mov	r14,r9
 endif
	and	rsp,-16

	lea	rdx,32[rsp]
	mov	rcx,rbx
	call	file_read_real

	movlpd	xmm0,qword ptr 32[rsp]
	
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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

	lea	r8,16[rcx+r11]
	mov	rdx,rsp
	mov	rcx,rbx
	
	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_characters
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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

	lea	r8,__STRING__+2
	mov	qword ptr [rdi],r8
;	mov	qword ptr [rdi],offset __STRING__+2

	lea	r8,16[rdi]
	mov	8[rdi],rax
	lea	rdx,8[rdi]
	mov	rcx,r10

	mov	rbx,r10

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_characters
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif

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
	lea	r8,__STRING__+2
	mov	qword ptr [rdi],r8
;	mov	qword ptr [rdi],offset __STRING__+2

	lea	r8,16[rdi]
	lea	rdx,-16[r15*8]
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_line
	mov	rsp,rbp

	mov	8[rdi],rax
 if THREAD
	mov	r9,r14
 endif
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

	lea	rbp,__STRING__+2
	mov	qword ptr [rdi],rbp
;	mov	qword ptr [rdi],offset __STRING__+2

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

	mov	r8,rdi
	lea	rdx,[r15*8]
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_line
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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
	mov	rcx,r10
	mov	rdx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_write_char
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1
	ret

writeFI:
	mov	rcx,r10
	mov	rdx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_write_int
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1
	ret

writeFR:
	mov	rdx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
 	call	file_write_real
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1
	ret

writeFS:
	mov	r8,rbx
	mov	rdx,8[rcx]
	add	rcx,16
	
	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_write_characters
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1
	ret

writeFString:
	mov	rbp,8[rcx]
	cmp	r11,rbp
	jae	writeFString_error

	sub	rbp,r11
	cmp	r10,rbp
	ja	writeFString_error

	mov	r8,rbx
	mov	rdx,r10
	lea	rcx,16[rcx+r11]
	
	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_write_characters
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1

	ret

writeFString_error:
	mov	rbp,offset fwritestring_error
	jmp	print_error

endF:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_end
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax
	mov	rax,-1
	ret

errorF:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_error
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax
	mov	rax,-1
	ret

positionF:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_position
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax
	mov	rax,-1
	ret

seekF:
	mov	r8,rax
	mov	rdx,rbx
	mov	rcx,r11
	
	mov	rbx,r11

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_seek
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax
	mov	rax,-1
	ret

shareF:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_share
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	rax,-1
	ret

flushF:
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	flush_file_buffer
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax
	mov	rax,-1
	ret

openSF:	mov	rdx,rax
	add	rcx,8

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	open_s_file
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	xor	r10,r10
	test	rax,rax
	setns	r10b

	mov	rbx,rax
	xor	rax,rax
	ret

readSFC:
	push	rax

	mov	rdx,rsp
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_s_char
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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
	mov	r8,rsp
	sub	rsp,8
	mov	rdx,rsp
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_read_s_int
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	pop	r10
	mov	r11,rax
	pop	rax
	
	ret

readSFR:
	push	rax
	mov	r8,rsp
	sub	rsp,8
	mov	rdx,rsp
	mov	rcx,rbx

	mov	rbp,rsp
	sub	rsp,40+8
 if THREAD
	mov	r14,r9
 endif
	and	rsp,-16
	call	file_read_s_real
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	movlpd	xmm0,qword ptr [rsp]
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

 if THREAD
	lea	rbp,__STRING__+2
	mov	qword ptr [rdi],rbp
 else
	lea	r9,__STRING__+2
	mov	qword ptr [rdi],r9
 endif
;	mov	qword ptr [rdi],offset __STRING__+2

	push	rbx

 if THREAD
	mov	r14,r9
 endif
	mov	r9,rsp
	lea	r8,8[rdi]
	mov	rdx,rax
	mov	rcx,r10
	
	mov	rbx,r10
	
	mov	rbp,rsp
	or	rsp,8
	sub	rsp,40
	call	file_read_s_string
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif

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
	ja	readLineSF_gc

readLineSF_r_gc:
	push	rax

 if THREAD
	lea	rbp,__STRING__+2
	mov	qword ptr [rdi],rbp
 else
	lea	r9,__STRING__+2
	mov	qword ptr [rdi],r9
 endif
;	mov	qword ptr [rdi],offset __STRING__+2

 if THREAD
	mov	r14,r9
 endif
	mov	r9,rsp
	lea	r8,16[rdi]
	lea	rdx,-16[r15*8]
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
	sub	rsp,40
	call	file_read_s_line
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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

	lea	rbp,__STRING__+2
	mov	qword ptr [rdi],rbp
;	mov	qword ptr [rdi],offset __STRING__+2

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

 if THREAD
	mov	r14,r9
 endif
	mov	r9,rsp
	mov	r8,rdi
	lea	rdx,[r15*8]
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
	sub	rsp,40
	call	file_read_s_line
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
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
	mov	rdx,rax
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_s_end
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	ret

positionSF:
	mov	rdx,rax
	mov	rcx,rbx

	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r14,r9
 endif
	sub	rsp,40
	call	file_s_position
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	ret

seekSF:
	push	rbx
 if THREAD
	mov	r14,r9
 endif
	mov	r9,rsp
	mov	r8,rax
	mov	rdx,r10
	mov	rcx,r11

	mov	rbx,r11

	mov	rbp,rsp
	or	rsp,8
	sub	rsp,40
	call	file_s_seek
	mov	rsp,rbp
 if THREAD
	mov	r9,r14
 endif
	mov	r10,rax	
	pop	rax

	ret

_TEXT	ends


	end
