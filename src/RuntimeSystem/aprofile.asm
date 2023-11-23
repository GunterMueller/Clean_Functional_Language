
_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	_TEXT segment

	public	init_profiler
	public	profile_r
	public profile_l
	public profile_l2
	public profile_n
	public profile_n2
	public profile_s
	public profile_s2
	public profile_t
	public	write_profile_information
	public	write_profile_stack
	public	stack_trace_depth

 ifndef LINUX
	extrn	allocate_memory:near
 endif
	extrn	__STRING__:near
	extrn	openF:near
	extrn	closeF:near
	extrn	writeFC:near
	extrn	writeFI:near
	extrn	ab_stack_size:near
	extrn	ew_print_string:near
	extrn	ew_print_char:near
	extrn	ew_print_text:near
	extrn	create_profile_file_name:near
;	extrn	print_error:near
;	extrn	profile_stack_pointer:near

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
	mov	rcx,qword ptr profile_stack_pointer

	sub	edx,dword ptr global_time_hi
	push	rbx
	mov	ebx,dword ptr global_time_lo
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx
	mov	rbx,qword ptr (-8)[rcx]

	add	rax,rdx
	
	sub	rcx,8
	mov	qword ptr global_last_tail_call,rbx

	mov	qword ptr profile_stack_pointer,rcx

	inc	qword ptr n_profiler_calls[rbx]
	add	qword ptr time[rbx],rax

	mov	rax,qword ptr global_n_words_free
	mov	qword ptr global_n_words_free,r15
	sub	rax,r15
	add	qword ptr n_words_allocated[rbx],rax

	pop	rbx
	pop	rcx

	rdtsc
	mov	dword ptr global_time_hi,edx
	pop	rdx
	mov	dword ptr global_time_lo,eax
	pop	rax
	ret

profile_r:
	push	rax
	push	rdx
	rdtsc

	push	rcx
	mov	rcx,qword ptr profile_stack_pointer

	sub	edx,dword ptr global_time_hi
	push	rbx
	mov	ebx,dword ptr global_time_lo
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx
	mov	rbx,qword ptr (-8)[rcx]

	add	rax,rdx

	sub	rcx,8
	mov	qword ptr global_last_tail_call,0

	mov	qword ptr profile_stack_pointer,rcx

	inc	qword ptr n_profiler_calls[rbx]
	add	qword ptr time[rbx],rax

	mov	rax,qword ptr global_n_words_free
	mov	qword ptr global_n_words_free,r15
	sub	rax,r15
	add	qword ptr n_words_allocated[rbx],rax

	pop	rbx
	pop	rcx

	rdtsc
	mov	dword ptr global_time_hi,edx
	pop	rdx
	mov	dword ptr global_time_lo,eax
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
	
	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer

	test	rbp,rbp
	jne	use_tail_calling_function_l

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_lr:

	mov	qword ptr [rcx],rbx
	add	rcx,8
	
	inc	qword ptr n_curried_calls[rbx]
	jmp	profile_n_

allocate_function_profile_record_l:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_lr

use_tail_calling_function_l:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_lr

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
	
	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer
	
	test	rbp,rbp
	jne	use_tail_calling_function_l2

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_l2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr 8[rcx],rbx
	add	rcx,16

	inc	qword ptr n_curried_calls[rbx]
	jmp	profile_n_

allocate_function_profile_record_l2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_l2r

use_tail_calling_function_l2:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_l2r

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
	
	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer

	test	rbp,rbp
	jne	use_tail_calling_function_n

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_nr:

	mov	qword ptr [rcx],rbx
	add	rcx,8

	inc	qword ptr n_lazy_calls[rbx]
	jmp	profile_n_

allocate_function_profile_record_n:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_nr

use_tail_calling_function_n:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_nr

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
	
	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer

	test	rbp,rbp
	jne	use_tail_calling_function_n2

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_n2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr 8[rcx],rbx
	add	rcx,16

	inc	qword ptr n_lazy_calls[rbx]
	jmp	profile_n_

allocate_function_profile_record_n2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_n2r

use_tail_calling_function_n2:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_n2r

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

	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer
	
	test	rbp,rbp
	jne	use_tail_calling_function_s2

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_s2r:

	mov	qword ptr [rcx],rbx
	mov	qword ptr 8[rcx],rbx
	add	rcx,16
	jmp	profile_s_

allocate_function_profile_record_s2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_s2r

use_tail_calling_function_s2:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_s2r

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

	mov	rbp,qword ptr global_last_tail_call
	mov	rcx,qword ptr profile_stack_pointer
	
	test	rbp,rbp
	jne	use_tail_calling_function_s

	mov	rbp,qword ptr (-8)[rcx]
use_tail_calling_function_sr:

	mov	qword ptr [rcx],rbx
	add	rcx,8

profile_s_:
	inc	qword ptr n_strict_calls[rbx]

profile_n_:
	mov	qword ptr profile_stack_pointer,rcx

	sub	edx,dword ptr global_time_hi
	mov	ebx,dword ptr global_time_lo
	mov	eax,eax

	shl	rdx,32
	sub	rax,rbx

	add	rax,rdx

	inc	qword ptr n_profiler_calls[rbp]
	add	qword ptr time[rbp],rax

	mov	rax,qword ptr global_n_words_free
	mov	qword ptr global_n_words_free,r15
	sub	rax,r15
	add	qword ptr n_words_allocated[rbp],rax

	pop	rcx
	pop	rbx

	rdtsc
	mov	dword ptr global_time_hi,edx
	pop	rdx
	mov	dword ptr global_time_lo,eax
	pop	rax
	ret

allocate_function_profile_record_s:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_sr

use_tail_calling_function_s:
	mov	qword ptr global_last_tail_call,0
	jmp	use_tail_calling_function_sr


; argument: rbp: function name adress-4
; result:   rbx: function profile record adress

allocate_function_profile_record:
	push	rax
	mov	rax,qword ptr global_n_free_records_in_block
	mov	rbx,qword ptr global_last_allocated_block

	test	rax,rax
	jne	no_alloc

	push	rcx
	push	rdx
	push	rbp

 ifdef LINUX
	sub	rsp,104
	mov	qword ptr [rsp],rsi
	mov	qword ptr 8[rsp],rdi
	mov	qword ptr 16[rsp],r8
	mov	qword ptr 24[rsp],r10
	mov	qword ptr 32[rsp],r11
	movsd	qword ptr 40[rsp],xmm0
	movsd	qword ptr 48[rsp],xmm1
	movsd	qword ptr 56[rsp],xmm2
	movsd	qword ptr 64[rsp],xmm3
	movsd	qword ptr 72[rsp],xmm4
	movsd	qword ptr 80[rsp],xmm5
	movsd	qword ptr 88[rsp],xmm6
	movsd	qword ptr 96[rsp],xmm7
 else
	sub	rsp,72
	mov	qword ptr [rsp],r8
	mov	qword ptr 8[rsp],r10
	mov	qword ptr 16[rsp],r11
	movsd	qword ptr 24[rsp],xmm0
	movsd	qword ptr 32[rsp],xmm1
	movsd	qword ptr 40[rsp],xmm2
	movsd	qword ptr 48[rsp],xmm3
	movsd	qword ptr 56[rsp],xmm4
	movsd	qword ptr 64[rsp],xmm5
 endif

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	rdi,8192
			; 128*FunctionProfile
	call	malloc
 else
	mov	rcx,128*FunctionProfile
	call	allocate_memory
 endif
	mov	rsp,rbp

 ifdef LINUX
	mov	rsi,qword ptr [rsp]
	mov	rdi,qword ptr 8[rsp]
	mov	r8,qword ptr 16[rsp]
	mov	r10,qword ptr 24[rsp]
	mov	r11,qword ptr 32[rsp]
	movlpd	xmm0,qword ptr 40[rsp]
	movlpd	xmm1,qword ptr 48[rsp]
	movlpd	xmm2,qword ptr 56[rsp]
	movlpd	xmm3,qword ptr 64[rsp]
	movlpd	xmm4,qword ptr 72[rsp]
	movlpd	xmm5,qword ptr 80[rsp]
	movlpd	xmm6,qword ptr 88[rsp]
	movlpd	xmm7,qword ptr 96[rsp]
	add	rsp,104
 else
	mov	r8,qword ptr [rsp]
	mov	r10,qword ptr 8[rsp]
	mov	r11,qword ptr 16[rsp]
	movlpd	xmm0,qword ptr 24[rsp]
	movlpd	xmm1,qword ptr 32[rsp]
	movlpd	xmm2,qword ptr 40[rsp]
	movlpd	xmm3,qword ptr 48[rsp]
	movlpd	xmm4,qword ptr 56[rsp]
	movlpd	xmm5,qword ptr 64[rsp]
	add	rsp,72
 endif

	test	rax,rax

	pop	rbp
	pop	rdx
	pop	rcx

	je	no_memory

	mov	rbx,rax
	mov	rax,128
	mov	qword ptr global_last_allocated_block,rbx

no_alloc:	
	dec	rax
	mov	qword ptr global_n_free_records_in_block,rax
	lea	rax,FunctionProfile[rbx]
	mov	qword ptr global_last_allocated_block,rax

	xor	rax,rax
	mov	qword ptr time[rbx],rax
	mov	qword ptr n_profiler_calls[rbx],rax
	mov	qword ptr n_strict_calls[rbx],rax
	mov	qword ptr n_lazy_calls[rbx],rax
	mov	qword ptr n_curried_calls[rbx],rax
	mov	qword ptr n_words_allocated[rbx],rax

	mov	rax,qword ptr global_profile_records
	mov	qword ptr name_[rbx],rbp

	mov	qword ptr next[rbx],rax
	mov	qword ptr global_profile_records,rbx

	mov	qword ptr [rbp],rbx
	pop	rax
	ret

no_memory:
	lea	rbp,not_enough_memory_for_profiler
	pop	rax
	jmp	print_error

write_profile_information:
	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,profile_file_name
 else
	lea	rcx,profile_file_name
 endif
	call	create_profile_file_name
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp

	mov	rax,1
	lea	rcx,profile_file_name
	call	openF

	test	r10,r10
	je	cannot_open
	
	mov	rbp,qword ptr global_profile_records

write_profile_lp:	
	test	rbp,rbp
	je	end_list

	mov	rdx,qword ptr name_[rbp]

	push	rbp

	push	rdx

	mov	edx,dword ptr (-4)[rdx]
	mov	eax,dword ptr [rdx]
	add	rdx,4

write_module_name_lp:
	sub	rax,1
	jc	end_module_name

	push	rax
	push	rdx

	movzx	r10,byte ptr [rdx]
	call	writeFC

	pop	rdx
	pop	rax

	add	rdx,1
	jmp	write_module_name_lp

end_module_name:
	mov	r10,' '
	call	writeFC

	pop	rdx

	add	rdx,7
	
write_function_name_lp:
	movzx	r10,byte ptr 1[rdx]
	add	rdx,1

	test	r10,r10
	je	end_function_name

	push	rdx

	call	writeFC

	pop	rdx

	jmp	write_function_name_lp

end_function_name:
	mov	r10,' '
	call	writeFC

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr n_strict_calls[rbp]
	call	writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr n_lazy_calls[rbp]
	call	writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr n_curried_calls[rbp]
	call	writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr n_profiler_calls[rbp]
	call	writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr n_words_allocated[rbp]
	call	writeFI_space

	mov	rbp,qword ptr [rsp]
	mov	r10,qword ptr time[rbp]
	call	writeFI

	mov	r10,10
	call	writeFC

	pop	rbp
	mov	rbp,qword ptr next[rbp]
	jmp	write_profile_lp

writeFI_space:
	call	writeFI

	mov	r10,' '
	jmp	writeFC

end_list:
	call	closeF

cannot_open:
	ret

write_profile_stack:
	mov	rax,qword ptr profile_stack_pointer

	test	rax,rax
	je	stack_not_initialised

	push	rax

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,stack_trace_string
 else
	lea	rcx,stack_trace_string
 endif
	call	ew_print_string
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp

	pop	rax

;	mov	rbp,12
	mov	rbp,qword ptr stack_trace_depth
write_functions_on_stack:
	mov	rbx,qword ptr (-8)[rax]
	sub	rax,8

	test	rbx,rbx
	je	end_profile_stack

	push	rax
	mov	rcx,qword ptr name_[rbx]

	push	rbp

	mov	edx,dword ptr (-4)[rcx]
	add	rcx,8

	mov	r12d,dword ptr [rdx]
	lea	r13,4[rdx]

	mov	rbp,rsp
	sub	rsp,40
	and	rsp,-16
 ifdef LINUX
	mov	r11,rsi
	mov	r14,rdi
	mov	rdi,rcx
 endif
	call	ew_print_string

 ifdef LINUX
	lea	rdi,module_string
 else
	lea	rcx,module_string
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rsi,r12
	mov	rdi,r13
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
 
ifdef LINUX
	mov	rsi,r11
	mov	rdi,r14
 endif
	mov	rsp,rbp

	pop	rbp
	pop	rax

	sub	rbp,1
	jne	write_functions_on_stack
	
end_profile_stack:
stack_not_initialised:
	ret

init_profiler:
	mov	dword ptr profile_type,1

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

	lea	rbp,start_string
	call	allocate_function_profile_record

	pop	rdx

	mov	qword ptr 8[rdx],rbx
	mov	qword ptr [rdx],0
	add	rdx,16
	mov	qword ptr profile_stack_pointer,rdx
	mov	qword ptr global_last_tail_call,0

	mov	qword ptr global_n_words_free,r15

	rdtsc
	mov	dword ptr global_time_hi,edx
	mov	dword ptr global_time_lo,eax
	ret

init_profiler_error:
	mov	qword ptr profile_stack_pointer,0
	lea	rbp,not_enough_memory_for_profile_stack
	jmp	print_error

_TEXT	ends

	_DATA segment

	align (1 shl 3)

global_n_free_records_in_block:
	dq 0
; 0 n free records in block
global_last_allocated_block:
	dq 0
; 8 latest allocated block
global_profile_records:
	dq 0
; 16 profile record list
global_time_hi:
	dd 0
; 24 clock
global_time_lo:
	dd 0
global_last_tail_call:
	dq 0
; last tail calling function
global_n_words_free:
	dq 0

profile_file_name:
	dq	__STRING__+2
	dq	0
	dq	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dq	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	dq	0
stack_trace_depth:
	dq	12
	align	(1 shl 3)

; m_system also defined in istartup.s
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
not_enough_memory_for_profiler:
	db	"not enough memory for profiler"
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

