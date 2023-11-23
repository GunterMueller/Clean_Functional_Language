_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	_TEXT segment

	public	profile_t
	public	profile_r
	public	profile_l
	public	profile_l2
	public	profile_n
	public	profile_n2
	public	profile_s
	public	profile_s2
	public	write_profile_stack
	public	write_profile_information
	public	init_profiler
	public	get_time_stamp_counter
	public	measure_profile_overhead

	extrn	profile_data_stack_ptr:near
	extrn	profile_last_tail_call:near
	extrn	ab_stack_size:near

	extrn	c_profile_l:near
	extrn	c_profile_n:near
	extrn	c_profile_s:near
	extrn	c_write_profile_stack:near
	extrn	c_write_profile_information:near
	extrn	c_init_profiler:near

ticks	= 8
allocated_words	= 16
tail_and_return_calls = 24

profile_t:
	push	rax
	push	rdx

	rdtsc
	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	rax,qword ptr profile_data_stack_ptr
	mov	rax,[rax]
	mov	qword ptr profile_last_tail_call,rax

	jmp	profile_r_

profile_r:
	push	rax
	push	rdx

	rdtsc
	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	rax,qword ptr profile_data_stack_ptr
	mov	rax,[rax]
	mov	qword ptr profile_last_tail_call,0
profile_r_:
	add	qword ptr ticks[rax],rdx

	mov	rdx,qword ptr words_free
	mov	qword ptr words_free,r15
	sub	rdx,r15
	add	qword ptr allocated_words[rax],rdx

	inc	dword ptr tail_and_return_calls[rax]

	sub	qword ptr profile_data_stack_ptr,8
	mov	rdx,qword ptr profile_data_stack_ptr
	mov	rdx,[rdx]
	mov	qword ptr profile_current_cost_centre,rdx

	rdtsc
	shl	rdx,32
	add	rdx,rax
	mov	qword ptr tick_count,rdx

	pop	rdx
	pop	rax
	ret

profile_l:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_l
	jmp	end_profile_call

profile_l2:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_l
	jmp	end_profile_call_2

profile_n:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	r9,rcx

	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_n
	jmp	end_profile_call

profile_n2:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	r9,rcx

	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_n
	jmp	end_profile_call_2

profile_eval_upd:
	push	rax
	push	rdx
	push	rcx
	mov	rcx,rdx
	rdtsc
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	r9,rcx

	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_n
	jmp	end_profile_call

profile_s:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_s
	jmp	end_profile_call

profile_s2:
	push	rax
	push	rdx
	rdtsc
	push	rcx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	r9
	push	r10
	push	r11
	push	rbp

 ifdef LINUX
	mov	rdi,rbp

	mov	rsi,rdx
	shl	rsi,32
	add	rsi,rax
	sub	rsi,qword ptr tick_count

	mov	rdx,qword ptr words_free
	sub	rdx,r15
 else
	mov	rcx,rbp

	shl	rdx,32
	add	rdx,rax
	sub	rdx,qword ptr tick_count

	mov	r8,qword ptr words_free
	sub	r8,r15
 endif
	mov	qword ptr words_free,r15

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_profile_s

end_profile_call_2:
	mov	rax,qword ptr profile_data_stack_ptr
	mov	rdx,[rax]
	add	rax,8
	mov	qword ptr profile_data_stack_ptr,rax
	mov	[rax],rdx
	jmp	end_profile_call_

end_profile_call:
	mov	rax,qword ptr profile_data_stack_ptr
	mov	rdx,[rax]
end_profile_call_:
	mov	qword ptr profile_current_cost_centre,rdx
	mov	rsp,rbp

	pop	rbp
	pop	r11
	pop	r10
	pop	r9
	pop	r8
 ifdef LINUX
	pop	rdi
	pop	rsi
 endif
	pop	rcx

	rdtsc
	shl	rdx,32
	add	rdx,rax
	mov	qword ptr tick_count,rdx

	pop	rdx
	pop	rax
	ret

write_profile_stack:
	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_write_profile_stack
	mov	rsp,rbp
	ret

write_profile_information:
	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
	call	c_write_profile_information
	mov	rsp,rbp
	ret

init_profiler:
	mov	dword ptr profile_type,2

	push	rax
	push	rdx
 ifdef LINUX
	push	rsi
	push	rdi
 endif
	push	r8
	push	rcx

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	rdi,qword ptr ab_stack_size
 else
	mov	rcx,qword ptr ab_stack_size
 endif
	call	c_init_profiler
	mov	rsp,rbp

	pop	rcx
	pop	r8
 ifdef LINUX
	pop	rdi
	pop	rsi
 endif

	rdtsc
	shl	rdx,32
	add	rdx,rax
	mov	qword ptr tick_count,rdx

	mov	qword ptr words_free,r15

	pop	rdx
	pop	rax
	ret

get_time_stamp_counter:
	rdtsc
	shl	rdx,32
	add	rax,rdx
	ret

measure_profile_overhead:
	push	rbp
	lea	rbp,measure_profile_overhead_dummy

	rdtsc
	shl	rdx,32
	add	rdx,rax
	mov	qword ptr tick_count,rdx

	call	profile_s
	mov	rax,99999
measure_profile_overhead_lp1:
	call	profile_s
	add	rcx,rcx
	add	rdx,rdx
	call	profile_r
	add	rcx,rcx
	add	rdx,rdx
	sub	rax,1
	jne	measure_profile_overhead_lp1
	call	profile_r

	mov	rax,100000
measure_profile_overhead_lp2:
	add	rcx,rcx
	add	rdx,rdx
	add	r8,r8
	add	r9,r9
	sub	rax,1
	jne	measure_profile_overhead_lp2

	rdtsc
	shl	rdx,32
	add	rax,rdx
	sub	rax,qword ptr tick_count

	pop	rbp
	ret

_TEXT	ends

	_DATA segment

tick_count	dq	0
words_free	dq	0

	align	8
	dd	m_system
measure_profile_overhead_dummy:
	db	0

	align (1 shl 3)

_DATA	ends

;	end
