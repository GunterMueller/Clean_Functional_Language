_TEXT	segment para 'CODE'

	align	(1 shl 4)
	public	_longjmp
	public	longjmp
_longjmp:
longjmp:
	mov	rsp,qword ptr 48[rcx]
	mov	rsi,qword ptr 56[rcx]

	mov	rbp,qword ptr [rcx]
	mov	rbx,qword ptr 8[rcx]

	mov	qword ptr [rsp],rsi

	mov	rsi,qword ptr 32[rcx]
	mov	rdi,qword ptr 40[rcx]

	mov	r8,qword ptr 64[rcx]
	mov	r9,qword ptr 72[rcx]
	mov	r10,qword ptr 80[rcx]
	mov	r11,qword ptr 88[rcx]
	mov	r12,qword ptr 96[rcx]
	mov	r13,qword ptr 104[rcx]
	mov	r14,qword ptr 112[rcx]
	mov	r15,qword ptr 120[rcx]

	mov	rax,rdx
	ret
	nop
	align	(1 shl 4)

_TEXT	ends
	end

