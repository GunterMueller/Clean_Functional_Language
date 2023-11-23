
_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	_TEXT segment

	public	init_profiler
	public	profile_r
	public	profile_l
	public	profile_l2
	public	profile_n
	public	profile_n2
	public	profile_s
	public	profile_s2
	public	profile_t
	public	write_profile_stack
	public	stack_trace_depth

 ifndef LINUX
	extrn	allocate_memory:near
 endif
	extrn	__STRING__:near
	extrn	ab_stack_size:near
	extrn	ew_print_string:near
	extrn	ew_print_char:near
	extrn	ew_print_text:near
;	extrn	print_error:near
;	extrn	profile_stack_pointer:near

profile_t:
profile_r:
	sub	qword ptr profile_stack_pointer,8
	ret

profile_l:
profile_n:
profile_s:
	push	rbx
	mov	rbx,qword ptr profile_stack_pointer
	mov	qword ptr [rbx],rbp
	add	rbx,8
	mov	qword ptr profile_stack_pointer,rbx
	pop	rbx
	ret

profile_l2:
profile_n2:
profile_s2:
	push	rbx
	mov	rbx,qword ptr profile_stack_pointer
	mov	qword ptr [rbx],rbp
	mov	qword ptr 8[rbx],rbp
	add	rbx,16
	mov	qword ptr profile_stack_pointer,rbx
	pop	rbx
	ret

write_profile_stack:
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
 endif
	mov	rax,qword ptr profile_stack_pointer

	test	rax,rax
	je	stack_not_initialised

	push	rax

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	lea	rdi,stack_trace_string
 else
	lea	rcx,stack_trace_string
 endif
	call	ew_print_string
	mov	rsp,rbp

	pop	rax

;	mov	rbp,12
	mov	rbp,qword ptr stack_trace_depth
write_functions_on_stack:
	mov	rcx,qword ptr (-8)[rax]
	sub	rax,8

	test	rcx,rcx
	je	end_profile_stack

	push	rax
	push	rbp

	mov	edx,dword ptr (-4)[rcx]
 ifdef LINUX
	lea	rdi,8[rcx]
	mov	r12,rdx
 else
	add	rcx,8

	mov	r12d,dword ptr [rdx]
	lea	r13,4[rdx]
 endif

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16

	call	ew_print_string

 ifdef LINUX
	lea	rdi,module_string
 else
	lea	rcx,module_string
 endif
	call	ew_print_string

 ifdef LINUX
	mov	esi,dword ptr [r12]
	lea	rdi,4[r12]
 else
	mov	rdx,r12
	mov	rcx,r13
 endif
	call	ew_print_text

 ifdef LINUX
	mov	rdi,']'
 else
	mov	rcx,']'
 endif
	call	ew_print_char

 ifdef LINUX
	mov	rdi,10
 else
	mov	rcx,10
 endif
	call	ew_print_char

	mov	rsp,rbp

	pop	rbp
	pop	rax

	sub	rbp,1
	jne	write_functions_on_stack

end_profile_stack:
stack_not_initialised:
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	ret

init_profiler:
	mov	dword ptr profile_type,3

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,qword ptr ab_stack_size
	call	malloc
	mov	rsi,r13
	mov	rdi,r14
 else
 	mov	rcx,qword ptr ab_stack_size
	call	allocate_memory
 endif
	mov	rsp,rbp
	
	test	rax,rax
	je	init_profiler_error

	push	rax

	lea	rbx,start_string

	pop	rdx

	mov	qword ptr 8[rdx],rbx
	mov	qword ptr [rdx],0
	add	rdx,16
	mov	qword ptr profile_stack_pointer,rdx
	ret

init_profiler_error:
	mov	qword ptr profile_stack_pointer,0
	lea	rbp,not_enough_memory_for_profile_stack
	jmp	print_error

_TEXT	ends

	_DATA segment

	align (1 shl 3)

stack_trace_depth:
	dq	12
	align	(1 shl 3)

; m_system also defined in astartup.asm
; m_system:
;	dq	6
;	db	"System"
;	db	0
;	db	0

	dd	m_system
start_string:
	dq	0
	db	"start"
	db	0
	align	(1 shl 3)
not_enough_memory_for_profile_stack:
	db	"not enough memory for profile stack"
	db	10
	db	0
stack_trace_string:
	db	"Stack trace:"
	db	10
	db	0
module_string:
	db	" [module: "
	db	0
	align	(1 shl 3)

_DATA	ends

;	end
