
	.text

	.globl	init_profiler
	.globl	profile_r
	.globl	profile_l
	.globl	profile_l2
	.globl	profile_n
	.globl	profile_n2
	.globl	profile_s
	.globl	profile_s2
	.globl	profile_t
	.globl	write_profile_information
	.globl	write_profile_stack
	.globl	stack_trace_depth

 .if ! LINUX
	.globl	allocate_memory
 .endif
	.globl	__STRING__
	.globl	openF
	.globl	closeF
	.globl	writeFC
	.globl	writeFI
	.globl	_ab_stack_size
	.globl	_ew_print_string
	.globl	_ew_print_char
	.globl	_ew_print_text
	.globl	_create_profile_file_name

	.globl	profile_file_name
/* extrn print_error */
/* extrn profile_stack_pointer */

next		= 0
time		= 8
n_profiler_calls = 16
n_strict_calls	= 24
n_lazy_calls	= 32
n_curried_calls	= 40
n_words_allocated = 48
name_		= 56
FunctionProfile	= 64

profile_t:
	push	rax
	push	rdx
	rdtsc

	push	rcx
	mov	rcx,qword ptr [rip+profile_stack_pointer]

	sub	edx,dword ptr [rip+global_time_hi]
	push	rbx
	mov	ebx,dword ptr [rip+global_time_lo]
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx
	mov	rbx,qword ptr [rcx-8]

	add	rax,rdx
	
	sub	rcx,8
	mov	qword ptr [rip+global_last_tail_call],rbx

	mov	qword ptr [rip+profile_stack_pointer],rcx

	inc	qword ptr [rbx+n_profiler_calls]
	add	qword ptr [rbx+time],rax

	mov	rax,qword ptr [rip+global_n_words_free]
	mov	qword ptr [rip+global_n_words_free],r15
	sub	rax,r15
	add	qword ptr [rbx+n_words_allocated],rax

	pop	rbx
	pop	rcx

	rdtsc
	mov	dword ptr [rip+global_time_hi],edx
	pop	rdx
	mov	dword ptr [rip+global_time_lo],eax
	pop	rax
	ret

profile_r:
	push	rax
	push	rdx
	rdtsc

	push	rcx
	mov	rcx,qword ptr [rip+profile_stack_pointer]

	sub	edx,dword ptr [rip+global_time_hi]
	push	rbx
	mov	ebx,dword ptr [rip+global_time_lo]
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx
	mov	rbx,qword ptr [rcx-8]

	add	rax,rdx

	sub	rcx,8
	mov	qword ptr [rip+global_last_tail_call],0

	mov	qword ptr [rip+profile_stack_pointer],rcx

	inc	qword ptr [rbx+n_profiler_calls]
	add	qword ptr [rbx+time],rax

	mov	rax,qword ptr [rip+global_n_words_free]
	mov	qword ptr [rip+global_n_words_free],r15
	sub	rax,r15
	add	qword ptr [rbx+n_words_allocated],rax

	pop	rbx
	pop	rcx

	rdtsc
	mov	dword ptr [rip+global_time_hi],edx
	pop	rdx
	mov	dword ptr [rip+global_time_lo],eax
	pop	rax
	ret

profile_l:
	push	rax
	push	rdx
	rdtsc

	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_l
allocate_function_profile_record_lr:
	push	rcx
	
	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]

	test	rbp,rbp
	jne	use_tail_calling_function_l

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_lr:

	mov	qword ptr [rcx],rbx
	add	rcx,8
	
	inc	qword ptr [rbx+n_curried_calls]
	att_jmp profile_n_

allocate_function_profile_record_l:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_lr

use_tail_calling_function_l:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_lr

profile_l2:
	push	rax
	push	rdx
	rdtsc

	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_l2
allocate_function_profile_record_l2r:
	push	rcx
	
	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]
	
	test	rbp,rbp
	jne	use_tail_calling_function_l2

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_l2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr [rcx+8],rbx
	add	rcx,16

	inc	qword ptr [rbx+n_curried_calls]
	att_jmp profile_n_

allocate_function_profile_record_l2:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_l2r

use_tail_calling_function_l2:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_l2r

profile_n:
	push	rax
	push	rdx
	rdtsc
		
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_n
allocate_function_profile_record_nr:
	push	rcx
	
	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]

	test	rbp,rbp
	jne	use_tail_calling_function_n

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_nr:

	mov	qword ptr [rcx],rbx
	add	rcx,8

	inc	qword ptr [rbx+n_lazy_calls]
	att_jmp profile_n_

allocate_function_profile_record_n:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_nr

use_tail_calling_function_n:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_nr

profile_n2:
	push	rax
	push	rdx
	rdtsc

	push	rbx
	mov	rbx,qword ptr [rbp]

	test	rbx,rbx
	je	allocate_function_profile_record_n2
allocate_function_profile_record_n2r:
	push	rcx
	
	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]

	test	rbp,rbp
	jne	use_tail_calling_function_n2

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_n2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr [rcx+8],rbx
	add	rcx,16

	inc	qword ptr [rbx+n_lazy_calls]
	att_jmp profile_n_

allocate_function_profile_record_n2:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_n2r

use_tail_calling_function_n2:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_n2r

profile_s2:
	push	rax
	push	rdx
	rdtsc
		
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_s2
allocate_function_profile_record_s2r:
	push	rcx

	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]
	
	test	rbp,rbp
	jne	use_tail_calling_function_s2

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_s2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr [rcx+8],rbx
	add	rcx,16
	att_jmp profile_s_

allocate_function_profile_record_s2:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_s2r

use_tail_calling_function_s2:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_s2r

profile_s:
	push	rax
	push	rdx
	rdtsc
	
	push	rbx
	mov	rbx,qword ptr [rbp]
	
	test	rbx,rbx
	je	allocate_function_profile_record_s
allocate_function_profile_record_sr:
	push	rcx

	mov	rbp,qword ptr [rip+global_last_tail_call]
	mov	rcx,qword ptr [rip+profile_stack_pointer]
	
	test	rbp,rbp
	jne	use_tail_calling_function_s

	mov	rbp,qword ptr [rcx-8]
use_tail_calling_function_sr:

	mov	qword ptr [rcx],rbx
	add	rcx,8

profile_s_:
	inc	qword ptr [rbx+n_strict_calls]

profile_n_:
	mov	qword ptr [rip+profile_stack_pointer],rcx

	sub	edx,dword ptr [rip+global_time_hi]
	mov	ebx,dword ptr [rip+global_time_lo]
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx

	add	rax,rdx

	inc	qword ptr [rbp+n_profiler_calls]
	add	qword ptr [rbp+time],rax

	mov	rax,qword ptr [rip+global_n_words_free]
	mov	qword ptr [rip+global_n_words_free],r15
	sub	rax,r15
	add	qword ptr [rbp+n_words_allocated],rax

	pop	rcx
	pop	rbx

	rdtsc
	mov	dword ptr [rip+global_time_hi],edx
	pop	rdx
	mov	dword ptr [rip+global_time_lo],eax
	pop	rax
	ret

allocate_function_profile_record_s:
	att_call allocate_function_profile_record
	att_jmp allocate_function_profile_record_sr

use_tail_calling_function_s:
	mov	qword ptr [rip+global_last_tail_call],0
	att_jmp use_tail_calling_function_sr


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
			/* 128*FunctionProfile */
	att_call _malloc
 .else
	mov	rcx,128*FunctionProfile
	att_call allocate_memory
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
	mov	rax,128
	mov	qword ptr [rip+global_last_allocated_block],rbx

no_alloc:	
	dec	rax
	mov	qword ptr [rip+global_n_free_records_in_block],rax
	lea	rax,[rbx+FunctionProfile]
	mov	qword ptr [rip+global_last_allocated_block],rax

	xor	rax,rax
	mov	qword ptr [rbx+time],rax
	mov	qword ptr [rbx+n_profiler_calls],rax
	mov	qword ptr [rbx+n_strict_calls],rax
	mov	qword ptr [rbx+n_lazy_calls],rax
	mov	qword ptr [rbx+n_curried_calls],rax
	mov	qword ptr [rbx+n_words_allocated],rax

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
	att_jmp print_error

write_profile_information:
	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,[rip+profile_file_name]
 .else
	lea	rcx,[rip+profile_file_name]
 .endif
	att_call _create_profile_file_name
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp

	mov	rax,1
	lea	rcx,[rip+profile_file_name]
	att_call openF

	test	r10,r10
	je	cannot_open
	
	mov	rbp,qword ptr [rip+global_profile_records]

write_profile_lp:	
	test	rbp,rbp
	je	end_list

	mov	rdx,qword ptr [rbp+name_]

	push	rbp

	push	rdx

	movsxd	rax,dword ptr [rdx-4]
	lea	rdx,[rdx+rax-4]
	mov	eax,dword ptr [rdx]
	add	rdx,4

write_module_name_lp:
	sub	rax,1
	jc	end_module_name

	push	rax
	push	rdx

	movzx	r10,byte ptr [rdx]
	att_call writeFC

	pop	rdx
	pop	rax

	add	rdx,1
	att_jmp write_module_name_lp

end_module_name:
	mov	r10,32 # ' '
	att_call writeFC

	pop	rdx

	add	rdx,7
	
write_function_name_lp:
	movzx	r10,byte ptr [rdx+1]
	add	rdx,1

	test	r10,r10
	je	end_function_name

	push	rdx

	att_call writeFC

	pop	rdx

	att_jmp write_function_name_lp

end_function_name:
	mov	r10,32 # ' '
	att_call writeFC

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+n_strict_calls]
	att_call writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+n_lazy_calls]
	att_call writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+n_curried_calls]
	att_call writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+n_profiler_calls]
	att_call writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+n_words_allocated]
	att_call writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr [rbp+time]
	att_call writeFI

	mov	r10,10
	att_call writeFC

	pop	rbp
	mov	rbp,qword ptr [rbp+next]
	att_jmp write_profile_lp

writeFI_space:
	att_call writeFI

	mov	r10,32 # ' '
	att_jmp writeFC

end_list:
	att_call closeF

cannot_open:
	ret

write_profile_stack:
	mov	rax,qword ptr [rip+profile_stack_pointer]

	test	rax,rax
	je	stack_not_initialised

	push	rax

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,[rip+stack_trace_string]
 .else
	lea	rcx,[rip+stack_trace_string]
 .endif
	att_call _ew_print_string
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
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
	mov	r11,rsi
	mov	r14,rdi
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

	att_call _ew_print_string

 .if LINUX
	lea	rdi,[rip+module_string]
 .else
	lea	rcx,[rip+module_string]
 .endif
	att_call _ew_print_string

 .if LINUX
	mov	esi,dword ptr [r12]
	lea	rdi,[r12+4]
 .else
	mov	rdx,r12
	mov	rcx,r13
 .endif
	att_call _ew_print_text

 .if LINUX
	mov	rdi,93 # ']'
 .else
	mov	rcx,93 # ']'
 .endif
	att_call _ew_print_char

 .if LINUX
	mov	rdi,10
 .else
	mov	rcx,10
 .endif
	att_call _ew_print_char
 
.if LINUX
	mov	rsi,r11
	mov	rdi,r14
 .endif
	mov	rsp,rbp

	pop	rbp
	pop	rax

	sub	rbp,1
	att_jne	write_functions_on_stack
	
end_profile_stack:
stack_not_initialised:
	ret

init_profiler:
	mov	dword ptr [rip+_profile_type],1

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,qword ptr [rip+_ab_stack_size]
	att_call _malloc
	mov	rsi,r13
	mov	rdi,r14
 .else
	mov	rcx,qword ptr [rip+ab_stack_size]
	att_call allocate_memory
 .endif
	mov	rsp,rbp
	
	test	rax,rax
	je	init_profiler_error

	push	rax

	lea	rbp,[rip+start_string]
	att_call allocate_function_profile_record

	pop	rdx

	mov	qword ptr [rdx+8],rbx
	mov	qword ptr [rdx],0
	add	rdx,16
	mov	qword ptr [rip+profile_stack_pointer],rdx
	mov	qword ptr [rip+global_last_tail_call],0

	mov	qword ptr [rip+global_n_words_free],r15

	rdtsc
	mov	dword ptr [rip+global_time_hi],edx
	mov	dword ptr [rip+global_time_lo],eax
	ret

init_profiler_error:
	mov	qword ptr [rip+profile_stack_pointer],0
	lea	rbp,[rip+not_enough_memory_for_profile_stack]
	att_jmp print_error

	.data

	.align	8

global_n_free_records_in_block:
	.quad	0
/* 0 n free records in block */
global_last_allocated_block:
	.quad	0
/* 8 latest allocated block */
global_profile_records:
	.quad	0
/* 16 profile record list */
global_time_hi:
	.long	0
/* 24 clock */
global_time_lo:
	.long	0
global_last_tail_call:
	.quad	0
/* last tail calling function */
global_n_words_free:
	.quad	0

profile_file_name:
	.quad	__STRING__+2
	.quad	0
	.quad	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.quad	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.quad	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.quad	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.quad	0

stack_trace_depth:
	.quad	12

	.align	8

/* m_system also defined in istartup.s */
/* m_system: */
/*	.quad	6 */
/*	.ascii	"System" */
/*	.byte	0 */
/*	.byte	0 */

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

