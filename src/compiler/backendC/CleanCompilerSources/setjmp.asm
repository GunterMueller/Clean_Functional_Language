
_TEXT	segment para 'CODE'

	align	(1 shl 4)
	public	_setjmp
_setjmp:
	mov	qword ptr [rcx],rbp
	mov	qword ptr 8[rcx],rbx

	mov	qword ptr 32[rcx],rsi
	mov	qword ptr 40[rcx],rdi
	mov	qword ptr 48[rcx],rsp
	mov	rdx,qword ptr [rsp]
	mov	qword ptr 56[rcx],rdx

	mov	qword ptr 64[rcx],r8
	mov	qword ptr 72[rcx],r9
	mov	qword ptr 80[rcx],r10
	mov	qword ptr 88[rcx],r11
	mov	qword ptr 96[rcx],r12
	mov	qword ptr 104[rcx],r13
	mov	qword ptr 112[rcx],r14
	mov	qword ptr 120[rcx],r15

	sub	rax,rax
	ret
	nop
	align	(1 shl 4)

_TEXT	ends
	end
