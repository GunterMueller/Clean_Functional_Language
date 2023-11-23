
	.text

	.globl	init_profiler
	.globl	profile_r
	.globl profile_l
	.globl profile_l2
	.globl profile_n
	.globl profile_n2
	.globl profile_s
	.globl profile_s2
	.globl profile_t
	.globl	write_profile_stack
	.globl	stack_trace_depth

 .if ! LINUX
	.globl	allocate_memory
 .endif
	.globl	__STRING__
	.globl	_ab_stack_size
	.globl	_ew_print_string
	.globl	_ew_print_char
	.globl	_ew_print_text
/*	.globl	print_error */
/*	.globl	profile_stack_pointer */

next		= 0
name_		= 8
FunctionProfile	= 16

profile_t:
	sub	qword ptr [rip+profile_stack_pointer],8
	ret

profile_r:
	sub	qword ptr [rip+profile_stack_pointer],8
	ret

profile_l:
	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_l
allocate_function_profile_record_lr:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	add	rbp,8
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_l:
	call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_lr

profile_l2:
	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_l2
allocate_function_profile_record_l2r:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	mov	qword ptr [rbp+8],rbx
	add	rbp,16
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_l2:
	att_call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_l2r

profile_n:
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_n
allocate_function_profile_record_nr:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	add	rbp,8
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_n:
	att_call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_nr

profile_n2:
	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_n2
allocate_function_profile_record_n2r:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	mov	qword ptr [rbp+8],rbx
	add	rbp,16
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_n2:
	att_call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_n2r

profile_s2:
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_s2
allocate_function_profile_record_s2r:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	mov	qword ptr [rbp+8],rbx
	add	rbp,16
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_s2:
	att_call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_s2r

profile_s:
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_s
allocate_function_profile_record_sr:
	mov	rbp,qword ptr [rip+profile_stack_pointer]

	mov	qword ptr [rbp],rbx
	add	rbp,8
	mov	qword ptr [rip+profile_stack_pointer],rbp

	pop	rbx
	ret

allocate_function_profile_record_s:
	att_call	allocate_function_profile_record
	att_jmp	allocate_function_profile_record_sr

/* argument: rbp: function name adress-4 */
/* result:   rbx: function profile record adress */

allocate_function_profile_record:
	push	rax
	mov	rax,qword ptr [rip+global_n_free_records_in_block]
	mov	rbx,qword ptr [rip+global_last_allocated_block]

	test	rax,rax
	jne	no_alloc

	push	rcx
	push	rdx
	push	rbp

 .if LINUX
	sub	rsp,104
	mov	qword ptr [rsp],rsi
	mov	qword ptr [rsp+8],rdi
	mov	qword ptr [rsp+16],r8
	mov	qword ptr [rsp+24],r10
	mov	qword ptr [rsp+32],r11
	movsd	qword ptr [rsp+40],xmm0
	movsd	qword ptr [rsp+48],xmm1
	movsd	qword ptr [rsp+56],xmm2
	movsd	qword ptr [rsp+64],xmm3
	movsd	qword ptr [rsp+72],xmm4
	movsd	qword ptr [rsp+80],xmm5
	movsd	qword ptr [rsp+88],xmm6
	movsd	qword ptr [rsp+96],xmm7
 .else
	sub	rsp,72
	mov	qword ptr [rsp],r8
	mov	qword ptr [rsp+8],r10
	mov	qword ptr [rsp+16],r11
	movsd	qword ptr [rsp+24],xmm0
	movsd	qword ptr [rsp+32],xmm1
	movsd	qword ptr [rsp+40],xmm2
	movsd	qword ptr [rsp+48],xmm3
	movsd	qword ptr [rsp+56],xmm4
	movsd	qword ptr [rsp+64],xmm5
 .endif

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	mov	rdi,8192
			/* 512*FunctionProfile */
	att_call	_malloc
 .else
	mov	rcx,512*FunctionProfile
	call	allocate_memory
 .endif
	mov	rsp,rbp

 .if LINUX
	mov	rsi,qword ptr [rsp]
	mov	rdi,qword ptr [rsp+8]
	mov	r8,qword ptr [rsp+16]
	mov	r10,qword ptr [rsp+24]
	mov	r11,qword ptr [rsp+32]
	movlpd	xmm0,qword ptr [rsp+40]
	movlpd	xmm1,qword ptr [rsp+48]
	movlpd	xmm2,qword ptr [rsp+56]
	movlpd	xmm3,qword ptr [rsp+64]
	movlpd	xmm4,qword ptr [rsp+72]
	movlpd	xmm5,qword ptr [rsp+80]
	movlpd	xmm6,qword ptr [rsp+88]
	movlpd	xmm7,qword ptr [rsp+96]
	add	rsp,104
 .else
	mov	r8,qword ptr [rsp]
	mov	r10,qword ptr [rsp+8]
	mov	r11,qword ptr [rsp+16]
	movlpd	xmm0,qword ptr [rsp+24]
	movlpd	xmm1,qword ptr [rsp+32]
	movlpd	xmm2,qword ptr [rsp+40]
	movlpd	xmm3,qword ptr [rsp+48]
	movlpd	xmm4,qword ptr [rsp+56]
	movlpd	xmm5,qword ptr [rsp+64]
	add	rsp,72
 .endif

	test	rax,rax

	pop	rbp
	pop	rdx
	pop	rcx

	je	no_memory

	mov	rbx,rax
	mov	rax,512
	mov	qword ptr [rip+global_last_allocated_block],rbx

no_alloc:	
	dec	rax
	mov	qword ptr [rip+global_n_free_records_in_block],rax
	lea	rax,[rbx+FunctionProfile]
	mov	qword ptr [rip+global_last_allocated_block],rax

	mov	rax,qword ptr [rip+global_profile_records]
	mov	qword ptr [rbx+name_],rbp

	mov	qword ptr [rbx+next],rax
	mov	qword ptr [rip+global_profile_records],rbx

	mov	qword ptr [rbp],rbx
	pop	rax
	ret

no_memory:
	lea	rbp,[rip+not_enough_memory_for_profiler]
	pop	rax
	att_jmp	print_error

write_profile_stack:
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
 .endif
	mov	rax,qword ptr [rip+profile_stack_pointer]

	test	rax,rax
	je	stack_not_initialised

	push	rax

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	lea	rdi,[rip+stack_trace_string]
 .else
	lea	rcx,stack_trace_string
 .endif
	att_call	_ew_print_string
	mov	rsp,rbp

	pop	rax

/*	mov	rbp,12 */
	mov	rbp,qword ptr [rip+stack_trace_depth]
write_functions_on_stack:
	mov	rbx,qword ptr [rax-8]
	sub	rax,8

	test	rbx,rbx
	je	end_profile_stack

	push	rax
	mov	rcx,qword ptr [rbx+name_]

	push	rbp

 .if LINUX
	movsxd	rdx,dword ptr [rcx-4]
	lea	rdx,[rcx+rdx-4]
	lea	rdi,[rcx+8]
	mov	r12,rdx
 .else
	mov	edx,dword ptr [rcx-4]
	add	rcx,8

	mov	r12d,dword ptr [rdx]
	lea	r13,[rdx+4]
 .endif

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16

	att_call	_ew_print_string

 .if LINUX
	lea	rdi,[rip+module_string]
 .else
	lea	rcx,module_string
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	esi,dword ptr [r12]
	lea	rdi,[r12+4]
 .else
	mov	rdx,r12
	mov	rcx,r13
 .endif
	att_call	_ew_print_text

 .if LINUX
	mov	rdi,93 # ']'
 .else
	mov	rcx,93 # ']'
 .endif
	att_call	_ew_print_char

 .if LINUX
	mov	rdi,10
 .else
	mov	rcx,10
 .endif
	att_call	_ew_print_char

	mov	rsp,rbp

	pop	rbp
	pop	rax

	sub	rbp,1
	att_jne	write_functions_on_stack

end_profile_stack:
stack_not_initialised:
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	ret

init_profiler:
	mov	dword ptr [rip+_profile_type],3

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,qword ptr [rip+_ab_stack_size]
	att_call	_malloc
	mov	rsi,r13
	mov	rdi,r14
 .else
 	mov	rcx,qword ptr ab_stack_size
	call	allocate_memory
 .endif
	mov	rsp,rbp
	
	test	rax,rax
	je	init_profiler_error

	push	rax

	lea	rbp,[rip+start_string]
	att_call	allocate_function_profile_record

	pop	rdx

	mov	qword ptr [rdx+8],rbx
	mov	qword ptr [rdx],0
	add	rdx,16
	mov	qword ptr [rip+profile_stack_pointer],rdx
	ret

init_profiler_error:
	mov	qword ptr [rip+profile_stack_pointer],0
	lea	rbp,[rip+not_enough_memory_for_profile_stack]
	att_jmp	print_error



	.data

	.align 8

global_n_free_records_in_block:
	.quad 0
/* 0 n free records in block */
global_last_allocated_block:
	.quad 0
/* 8 latest allocated block */
global_profile_records:
	.quad 0
/* 16 profile record list */

stack_trace_depth:
	.quad	12
	.align	8

/* m_system also defined in istartup.s */
/*
m_system:
	.quad	6
	.ascii	"System"
	.byte	0
	.byte	0
*/
	.long	m_system-.
start_string:
	.quad	0
	.ascii	"start"
	.byte	0
	.align	8
not_enough_memory_for_profile_stack:
	.ascii	"not enough memory for profile stack"
	.byte	10
	.byte	0
not_enough_memory_for_profiler:
	.ascii	"not enough memory for profiler"
	.byte	10
	.byte	0
stack_trace_string:
	.ascii	"Stack trace:"
	.byte	10
	.byte	0
module_string:
	.ascii	" [module: "
	.byte	0
	.align	8



/*	end */
