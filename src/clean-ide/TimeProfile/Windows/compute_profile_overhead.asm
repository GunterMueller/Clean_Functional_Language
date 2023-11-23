_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	extern	p_time:near
	extern	g_time_hi:near
	extern	g_time_lo:near

	_TEXT segment

profile_:
	push	rax
	push	rdx

	rdtsc

	sub	edx,dword ptr g_time_hi
	push	rbx
	mov	ebx,dword ptr g_time_lo
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx
	add	rax,rdx

	add	qword ptr p_time,rax
	pop	rbx

	rdtsc

	mov	dword ptr g_time_hi,edx
	pop	rdx
	mov	dword ptr g_time_lo,eax
	pop	rax
	ret

	public	compute_profile_overhead

compute_profile_overhead:
	mov	rax,rcx
	push	rbx
	push	rcx
	push	rdx
	push	rbp

	xor	rcx,rcx
	xor	rdx,rdx
	mov	rbx,100000

	call	profile_
	mov	qword ptr p_time,rcx

compute_profile_overhead_lp1:
	lea	rbp,p_time
	call	profile_

	add	rcx,rcx
	add	rdx,rdx

	sub	rbx,1
	jne	compute_profile_overhead_lp1

	mov	rcx,qword ptr p_time
	mov	qword ptr [rax],rcx

	xor	rcx,rcx
	xor	rdx,rdx
	mov	rbx,100000

	call	profile_
	mov	qword ptr p_time,rcx

compute_profile_overhead_lp2:
	add	rcx,rcx
	add	rdx,rdx
	
	sub	rbx,1
	jne	compute_profile_overhead_lp2

	call	profile_

	mov	rcx,qword ptr p_time
	mov	qword ptr 8[rax],rcx

	pop	rbp
	pop	rdx
	pop	rcx
	pop	rbx

	ret

_TEXT	ends
	end
