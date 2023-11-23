
;	File:	astartup.asm
;	Author:	John van Groningen
;	Machine:	amd64

_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	d2 equ r10
	d3 equ r11
	d4 equ r12
	d5 equ r13

	d3d equ r11d
	d4d equ r12d

	d2b equ r10b

 ifdef LINUX
	.intel_syntax noprefix
 endif

	THREAD equ 1

 ifndef LINUX
	extrn	convert_real_to_string:near
 endif
 ifndef LINUX
	extrn	write_heap:near
 endif
	extrn	return_code:near
	extrn	execution_aborted:near
	extrn	e____system__kFinalizerGCTemp:near
	extrn	e____system__kFinalizer:near

 ifdef LINUX
	.globl	times
	.globl	exit
 else
	extrn	GetTickCount:near
	extrn	ExitProcess:near
 endif
 if THREAD
	extrn	TlsAlloc:near
 endif

 ifdef USE_LIBM
	extrn	cos:near
	extrn	sin:near
	extrn	tan:near
	extrn	atan:near
 endif

NEW_DESCRIPTORS = 1

	_DATA segment
	align	(1 shl 3)

 ife THREAD
semi_space_size	dq	0

heap_p1	dq	0
heap_p2	dq	0
heap_p3	dq	0
neg_heap_p3	dq	0
end_heap_p3	dq	0

neg_heap_vector_plus_4	dq	0

heap_size_64_65	dq	0
heap_vector	dq	0
stack_top	dq	0
end_vector	dq	0

heap_size_257	dq	0
heap_copied_vector	dq	0

heap_end_after_gc	dq	0
extra_heap	dq	0
extra_heap_size	dq	0
stack_p	dq	0
halt_sp	dq	0

n_allocated_words	dq	0
 endif

 if THREAD
	public	tlsp_tls_index
tlsp_tls_index	dq	0
 endif

last_time	dq	0
execute_time	dq	0
garbage_collect_time	dq	0
IO_time	dq	0

compact_garbage_collect_time	dq	0
mark_compact_garbage_collect_time	dq	0
total_gc_bytes	dq	0
total_compact_gc_bytes	dq	0

 ife THREAD
	public	saved_heap_p
saved_heap_p label ptr
	dq	0
	dq	0

	public	saved_a_stack_p
saved_a_stack_p	dq	0

	public	end_a_stack
end_a_stack	dq	0

	public	int_to_real_scratch
int_to_real_scratch	dq	0
 endif

heap_end_write_heap	dq	0
d3_flag_write_heap	dq	0

 ife THREAD
heap2_begin_and_end label ptr
		dq	0
		dq	0
 endif

	public	a_stack_guard_page
a_stack_guard_page	dq	0

	public	profile_stack_pointer
profile_stack_pointer	dq	0

dll_initialised	dq	0
 ife THREAD
	public	end_b_stack
end_b_stack	dq	0
 endif
basic_only	dq	0
 ife THREAD
heap_size_65	dq	0
heap_copied_vector_size	dq	0
heap_end_after_copy_gc	dq	0
heap_mbp	dq	0
heap_p		dq	0
stack_mbp	dq	0

bit_counter	label ptr
	dq	0
bit_vector_p	label ptr
	dq	0
zero_bits_before_mark	label ptr
	dq	1
n_free_words_after_mark	label ptr
	dq	1000
n_last_heap_free_bytes	label ptr
	dq	0
lazy_array_list	label ptr
	dq	0
n_marked_words	label ptr
	dq	0
end_stack	label ptr
	dq	0

bit_vector_size	label ptr
	dq	0
 endif

 if THREAD
 
	comm	main_thread_local_storage:512

heap_p1_offset			= 0
heap_p2_offset			= 8
heap_p3_offset			= 16

saved_heap_p_offset		= 24
saved_r15_offset		= 32
saved_a_stack_p_offset		= 40

heap_vector_offset		= 48
end_vector_offset		= 56 ; temp
neg_heap_vector_plus_4_offset	= 64 ; temp

heap_size_64_65_offset		= 72 ; temp
heap_size_257_offset		= 80

heap_copied_vector_offset	= 88

heap_end_after_gc_offset	= 96

extra_heap_offset		= 104
extra_heap_size_offset		= 112

stack_top_offset		= 120 ; temp
stack_p_offset			= 128

halt_sp_offset			= 136

n_allocated_words_offset	= 144 ; temp

heap2_begin_and_end_offset	= 152
heap_copied_vector_size_offset	= 168
heap_end_after_copy_gc_offset	= 176
heap_mbp_offset			= 184
heap_p_offset			= 192
stack_mbp_offset		= 200
bit_counter_offset		= 208
bit_vector_p_offset		= 216
bit_vector_size_offset		= 224
zero_bits_before_mark_offset	= 232
n_free_words_after_mark_offset	= 240
n_last_heap_free_bytes_offset	= 248
n_marked_words_offset		= 256 ; temp
end_stack_offset		= 264 ; temp
lazy_array_list_offset		= 272 ; temp
heap_size_offset		= 280
heap_size_65_offset		= 288
a_stack_size_offset		= 296
garbage_collect_flag_offset	= 304

semi_space_size_offset	= 312 ; temp
neg_heap_p3_offset		= 320 ; temp
end_heap_p3_offset		= 328 ; temp

 endif

caf_list	label ptr
	dq	0
	public	caf_listp
caf_listp	label ptr
	dq	0
	
zero_length_string	label ptr
	dq	__STRING__+2
	dq	0
true_string	label ptr
	dq	__STRING__+2
	dq	4
true_c_string	label ptr
	db	"True"
	db	0,0,0,0
false_string	label ptr
	dq	__STRING__+2
	dq	5
false_c_string	label ptr
	db	"False"
	db	0,0,0
file_c_string	label ptr
	db	"File"
	db	0,0,0,0
 ife THREAD
garbage_collect_flag	label ptr
	db	0
	db	0,0,0
	align	(1 shl 3)
 endif

	comm	sprintf_buffer:32

out_of_memory_string_1	label ptr
	db	"Not enough memory to allocate heap and stack"
	db	10,0
printf_int_string	label ptr
	db	"%d"
	db	0
printf_real_string	label ptr
	db	"%.15g"
	db	0
printf_string_string	label ptr
	db	"%s"
	db	0
printf_char_string	label ptr
	db	"%c"
	db	0
garbage_collect_string_1	label ptr
	db	"A stack: "
	db	0
garbage_collect_string_2	label ptr
	db	" bytes. BC stack: "
	db	0
garbage_collect_string_3	label ptr
	db	" bytes."
	db	10,0
heap_use_after_gc_string_1	label ptr
	db	"Heap use after garbage collection: "
	db	0
heap_use_after_compact_gc_string_1	label ptr
	db	"Heap use after compacting garbage collection: "
	db	0
heap_use_after_gc_string_2	label ptr
	db	" Bytes."
	db	10,0
stack_overflow_string	label ptr
	db	"Stack overflow."
	db	10,0
out_of_memory_string_4	label ptr
	db	"Heap full."
	db	10,0
time_string_1	label ptr
	db	"Execution: "
	db	0
time_string_2	label ptr
	db	"  Garbage collection: "
	db	0
time_string_3	label ptr
	db	" "
	db	0
time_string_4	label ptr
	db	"  Total: "
	db	0
high_index_string	label ptr
	db	"Index too high in UPDATE string."
	db	10,0
low_index_string	label ptr
	db	"Index negative in UPDATE string."
	db	10,0
IO_error_string	label ptr
	db	"IO error: "
	db	0
new_line_string	label ptr
	db	10,0
sprintf_time_string	label ptr
	db	"%d.%02d"
	db	0
marked_gc_string_1	label ptr
	db	"Marked: "
	db	0
 if THREAD
tls_alloc_error_string	label ptr
	db	"Could not allocate thread local storage index"
	db	10,0
 endif

 ifdef PROFILE
	align	8
m_system:
	dd	6
	db	"System"
	db	0
	db	0

	dd	m_system
garbage_collector_name:
	dq	0
	db	"garbage_collector"
	db	0
	align	8
 endif

	align	16
	public	sign_real_mask
sign_real_mask	label ptr
	dq	8000000000000000h,8000000000000000h
	public	abs_real_mask
abs_real_mask	label ptr
	dq	7fffffffffffffffh,7fffffffffffffffh

	align (1 shl 3) 
NAN_real	label ptr
	dd	0ffffffffh,7fffffffh
one_real	label ptr
	dd	00000000h,3ff00000h
zero_real	label ptr
	dd	00000000h,00000000h

	align (1 shl 2) 
bit_set_table	label ptr
	dd	00000001h,00000002h,00000004h,00000008h
	dd	00000010h,00000020h,00000040h,00000080h
	dd	00000100h,00000200h,00000400h,00000800h
	dd	00001000h,00002000h,00004000h,00008000h
	dd	00010000h,00020000h,00040000h,00080000h
	dd	00100000h,00200000h,00400000h,00800000h
	dd	01000000h,02000000h,04000000h,08000000h
	dd	10000000h,20000000h,40000000h,80000000h
	dd	0
bit_set_table2	label ptr
	dd	00000001h,0,00000002h,0,00000004h,0,00000008h,0
	dd	00000010h,0,00000020h,0,00000040h,0,00000080h,0
	dd	00000100h,0,00000200h,0,00000400h,0,00000800h,0
	dd	00001000h,0,00002000h,0,00004000h,0,00008000h,0
	dd	00010000h,0,00020000h,0,00040000h,0,00080000h,0
	dd	00100000h,0,00200000h,0,00400000h,0,00800000h,0
	dd	01000000h,0,02000000h,0,04000000h,0,08000000h,0
	dd	10000000h,0,20000000h,0,40000000h,0,80000000h,0
	dd	0,0
bit_clear_table	label ptr
	dd	0fffffffeh,0fffffffdh,0fffffffbh,0fffffff7h
	dd	0ffffffefh,0ffffffdfh,0ffffffbfh,0ffffff7fh
	dd	0fffffeffh,0fffffdffh,0fffffbffh,0fffff7ffh
	dd	0ffffefffh,0ffffdfffh,0ffffbfffh,0ffff7fffh
	dd	0fffeffffh,0fffdffffh,0fffbffffh,0fff7ffffh
	dd	0ffefffffh,0ffdfffffh,0ffbfffffh,0ff7fffffh
	dd	0feffffffh,0fdffffffh,0fbffffffh,0f7ffffffh
	dd	0efffffffh,0dfffffffh,0bfffffffh,7fffffffh
	dd	0ffffffffh
bit_clear_table2	label ptr
	dd	0fffffffeh,-1,0fffffffdh,-1,0fffffffbh,-1,0fffffff7h,-1
	dd	0ffffffefh,-1,0ffffffdfh,-1,0ffffffbfh,-1,0ffffff7fh,-1
	dd	0fffffeffh,-1,0fffffdffh,-1,0fffffbffh,-1,0fffff7ffh,-1
	dd	0ffffefffh,-1,0ffffdfffh,-1,0ffffbfffh,-1,0ffff7fffh,-1
	dd	0fffeffffh,-1,0fffdffffh,-1,0fffbffffh,-1,0fff7ffffh,-1
	dd	0ffefffffh,-1,0ffdfffffh,-1,0ffbfffffh,-1,0ff7fffffh,-1
	dd	0feffffffh,-1,0fdffffffh,-1,0fbffffffh,-1,0f7ffffffh,-1
	dd	0efffffffh,-1,0dfffffffh,-1,0bfffffffh,-1,7fffffffh,-1
	dd	0ffffffffh,-1
first_one_bit_table	label ptr
	db	-1,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	7,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	db	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0

	align(1 shl  2) 
	comm	sprintf_time_buffer:20

	align(1 shl  3)

;	public	small_integers
	comm	small_integers:33*16
;	public	static_characters
	comm	static_characters:256*16

;	extrn	clean_exception_handler:near
;	public	clean_unwind_info
;clean_unwind_info:
;	DD	000000009H
;	DD	imagerel(clean_exception_handler)

_DATA	ends
	_TEXT segment

	public	abc_main
	public	print
	public	print_char
	public	print_int
	public	print_real
	public	print__string__
	public	print__chars__sc
	public	print_sc
	public	print_symbol
	public	print_symbol_sc
	public	printD
	public	DtoAC
	public	push_t_r_args
	public	push_a_r_args
	public	halt
	public	dump

	public	catAC
	public	sliceAC
	public	updateAC
	public	eqAC
	public	cmpAC

	public	string_to_string_node
	public	int_array_to_node
	public	real_array_to_node

	public	_create_arrayB
	public	_create_arrayC
	public	_create_arrayI
	public	_create_arrayI32
	public	_create_arrayR
	public	_create_arrayR32
	public	_create_r_array
	public	create_array
	public	create_arrayB
	public	create_arrayC
	public	create_arrayI
	public	create_arrayI32
	public	create_arrayR
	public	create_arrayR32
	public	create_R_array

	public	BtoAC
	public	ItoAC
	public	RtoAC
	public	eqD

	public	collect_0
	public	collect_1
	public	collect_2
	public	collect_3

	public	yet_args_needed
	public	yet_args_needed_0
	public	yet_args_needed_1
	public	yet_args_needed_2
	public	yet_args_needed_3
	public	yet_args_needed_4

	public	_c3,_c4,_c5,_c6,_c7,_c8,_c9,_c10,_c11,_c12
	public	_c13,_c14,_c15,_c16,_c17,_c18,_c19,_c20,_c21,_c22
	public	_c23,_c24,_c25,_c26,_c27,_c28,_c29,_c30,_c31,_c32

	public	e__system__nind
	public	e__system__eaind
; old names of the previous two labels for compatibility, remove later
	public	__indirection,__eaind
	extrn	e__system__dind:near
	public	eval_fill

	public	eval_upd_0,eval_upd_1,eval_upd_2,eval_upd_3,eval_upd_4
	public	eval_upd_5,eval_upd_6,eval_upd_7,eval_upd_8,eval_upd_9
	public	eval_upd_10,eval_upd_11,eval_upd_12,eval_upd_13,eval_upd_14
	public	eval_upd_15,eval_upd_16,eval_upd_17,eval_upd_18,eval_upd_19
	public	eval_upd_20,eval_upd_21,eval_upd_22,eval_upd_23,eval_upd_24
	public	eval_upd_25,eval_upd_26,eval_upd_27,eval_upd_28,eval_upd_29
	public	eval_upd_30,eval_upd_31,eval_upd_32

	public	repl_args_b
	public	push_arg_b
	public	del_args

	public	add_IO_time
	public	add_execute_time
	public	IO_error
	public	stack_overflow

	public	out_of_memory_4
	public	print_error

 ifdef LINUX
	.globl	__start
 else
	extrn	_start:near
 endif

 ifdef PROFILE
;	extrn	init_profiler:near
;	extrn	profile_n:near
;	extrn	profile_s:near
;	extrn	profile_r:near
;	extrn	write_profile_information:near
;	extrn	write_profile_stack:near
 endif

  ifdef USE_LIBM
	public	cos_real
	public	sin_real
	public	tan_real
	public	asin_real
	public	acos_real
	public	atan_real
	public	ln_real
	public	log10_real
	public	exp_real
	public	pow_real
 endif
	public	entier_real
	public	r_to_i_real
 ifdef USE_LIBM
	public	_c_pow
	public	_c_log10
	public	_c_entier
 endif

	public	__driver

; from system.abc:
	extrn	dINT:near
	extrn	INT32:near
	extrn	CHAR:near
	extrn	BOOL:near
	extrn	REAL:near
	extrn	REAL32:near
	extrn	FILE:near
	extrn	__STRING__:near
	extrn	__ARRAY__:near
	extrn	__cycle__in__spine:near
	extrn	__print__graph:near
	extrn	__eval__to__nf:near

; from wcon.c:
	extrn	w_print_char:near
	extrn	w_print_string:near
	extrn	w_print_text:near
	extrn	w_print_int:near
	extrn	w_print_real:near

	extrn	ew_print_char:near
	extrn	ew_print_text:near
	extrn	ew_print_string:near
	extrn	ew_print_int:near
	extrn	ew_print_real:near

	extrn	ab_stack_size:near
	extrn	heap_size:near
	extrn	flags:near

; from standard c library:

 ifndef LINUX
	extrn	allocate_memory:near
  ife THREAD
	extrn	allocate_memory_with_guard_page_at_end:near
  endif
	extrn	free_memory:near
 endif
 
	extrn	heap_size_multiple:near
	extrn	initial_heap_size:near

	extrn	min_write_heap_size:near

	extrn	__Nil:near
;	public	finalizer_list
	comm	finalizer_list:qword
;	public	free_finalizer_list
	comm	free_finalizer_list:qword

abc_main:
	push	rbx
	push	rcx
	push	rdx 
	push	rbp 
	push	rsi 
	push	rdi 

	call	init_clean
	test	rax,rax
	jne	init_error

	call	init_timer

 if THREAD
	mov	halt_sp_offset[r9],rsp
 else
	mov	halt_sp,rsp
 endif

 ifdef PROFILE
	call	init_profiler
 endif

 ifdef LINUX
	call	__start

exit_:
 else
	call	_start

exit:
 endif

	call	exit_clean

init_error:
	pop	rdi
	pop	rsi
	pop	rbp
	pop	rdx
	pop	rcx
	pop	rbx

 ifdef LINUX
	mov	eax,dword ptr return_code
	jne	return_code_set_1
	mov	eax,-1
return_code_set_1:
 endif
	ret


	public	DllMain
DllMain:
	cmp	edx,1
	je	DLL_PROCESS_ATTACH
	jb	DLL_PROCESS_DETACH
	ret

DLL_PROCESS_ATTACH:
	push	rbx 
	push	rbp 
	push	rsi 
	push	rdi
 ifndef LINUX
	db	49h
	push	rsp
	db	49h
	push	rbp
	db	49h
	push	rsi
	db	49h
	push	rdi
 else
	push	r12
	push	r13
	push	r14
	push	r15
 endif
	mov	qword ptr dll_initialised,1

	call	init_clean
	test	rax,rax
	jne	init_dll_error

	call	init_timer

 if THREAD
	mov	halt_sp_offset[r9],rsp 
 else
	mov	halt_sp,rsp 
 endif

 ifdef PROFILE
	call	init_profiler
 endif

 if THREAD
	mov	qword ptr saved_heap_p_offset[r9],rdi
	mov	qword ptr saved_r15_offset[r9],r15
	mov	qword ptr saved_a_stack_p_offset[r9],rsi
 else
	mov	qword ptr saved_heap_p,rdi
	mov	qword ptr saved_heap_p+8,r15
	mov	saved_a_stack_p,rsi
 endif

	mov	rax,1
	jmp	exit_dll_init

init_dll_error:
	xor	rax,rax
	jmp	exit_dll_init
	
DLL_PROCESS_DETACH:
	push	rbx 
	push	rbp 
	push	rsi 
	push	rdi
 ifndef LINUX
	db	49h
	push	rsp
	db	49h
	push	rbp
	db	49h
	push	rsi
	db	49h
	push	rdi
 else
	push	r12
	push	r13
	push	r14
	push	r15
 endif

 if THREAD
	mov	rdi,qword ptr saved_heap_p_offset[r9]
	mov	r15,qword ptr saved_r15_offset[r9]
	mov	rsi,qword ptr saved_a_stack_p_offset[r9]
 else
	mov	rdi,qword ptr saved_heap_p
	mov	r15,qword ptr saved_heap_p+8
	mov	rsi,saved_a_stack_p
 endif

	call	exit_clean

exit_dll_init:
 ifndef LINUX
	db	49h
	pop	rdi
	db	49h
	pop	rsi
	db	49h
	pop	rbp
	db	49h
	pop	rsp
 else
	pop	r15
	pop	r14
	pop	r13
	pop	r12
 endif
	pop	rdi 
	pop	rsi 
	pop	rbp 
	pop	rbx 
	ret

init_clean:
 if THREAD
  ifdef LINUX
	sub	rsp,8

	mov	rdi,rsp
	sub	rsi,rsi

	mov	rbp,rsp
	and	rsp,-16
	call	pthread_key_create
	mov	rsp,rbp

 	lea	r9,main_thread_local_storage

	test	eax,eax
	jne	tls_alloc_error

	mov	rdi,qword ptr [rsp]
	mov	rsi,r9

	mov	qword ptr tlsp_tls_index,rdi

	mov	rbp,rsp
	and	rsp,-16
 	call	pthread_setspecific
	mov	rsp,rbp

 	lea	r9,main_thread_local_storage

	test	eax,eax
	jne	tls_alloc_error

	add	rsp,8

 	lea	r9,main_thread_local_storage
  else
 	sub	rsp,32
	call	TlsAlloc
	add	rsp,32

	cmp	rax,64
	jae	tls_alloc_error

	mov	qword ptr tlsp_tls_index,rax

 	lea	r9,main_thread_local_storage

	mov	qword ptr gs:[1480h+rax*8],r9
  endif
 endif

	lea	rax,128[rsp]
	sub	rsp,32+8

 ife THREAD
	sub	rax,qword ptr ab_stack_size
	mov	end_b_stack,rax
 endif
	mov	rax,qword ptr flags
	and	rax,1
	mov	basic_only,rax 

;	call	allow_prefetch_for_athlon

	mov	rax,qword ptr heap_size
 if THREAD
	mov	heap_size_offset[r9],rax
 endif
	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,65
	div	rbx
 if THREAD
	mov	qword ptr heap_size_65_offset[r9],rax 

	mov	rax,qword ptr heap_size_offset[r9]
 else
	mov	qword ptr heap_size_65,rax 

	mov	rax,qword ptr heap_size
 endif

	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,257
	div	rbx
 if THREAD
	mov	heap_size_257_offset[r9],rax
 else
	mov	heap_size_257,rax
 endif
	add	rax,7
	and	rax,-8
 if THREAD
	mov	qword ptr heap_copied_vector_size_offset[r9],rax
	mov	qword ptr heap_end_after_copy_gc_offset[r9],0

	mov	rax,qword ptr heap_size_offset[r9]
 else
	mov	qword ptr heap_copied_vector_size,rax
	mov	qword ptr heap_end_after_copy_gc,0

	mov	rax,qword ptr heap_size
 endif
	add	rax,7
	and	rax,-8
 if THREAD
	mov	qword ptr heap_size_offset[r9],rax
 else
	mov	qword ptr heap_size,rax
 endif
	add	rax,7

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	rdi,rax
	call	malloc
 else
	mov	rcx,rax
	call	allocate_memory
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

	test	rax,rax 
	je	no_memory_2

 if THREAD
	mov	heap_mbp_offset[r9],rax
 else
	mov	heap_mbp,rax
 endif
	lea	rdi,7[rax]
	and	rdi,-8
 if THREAD
	mov	heap_p_offset[r9],rdi 
 else
	mov	heap_p,rdi 
 endif

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r14,rdi
	mov	rdi,qword ptr ab_stack_size
  if THREAD
	mov	qword ptr a_stack_size_offset[r9],rdi
  endif
	add	rdi,7
	call	malloc
	mov	rdi,r14
 else
	mov	rcx,qword ptr ab_stack_size
  if THREAD
	mov	qword ptr a_stack_size_offset[r9],rcx
  endif
	add	rcx,7
  if THREAD
	call	allocate_memory
  else
	call	allocate_memory_with_guard_page_at_end
  endif
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	
	test	rax,rax 
	je	no_memory_3

 if THREAD
	mov	stack_mbp_offset[r9],rax 

	add	rax,qword ptr a_stack_size_offset[r9]
 else
	mov	stack_mbp,rax 

	add	rax,qword ptr ab_stack_size
 endif
	add	rax,7+4095
	and	rax,-4096
	mov	qword ptr a_stack_guard_page,rax
 if THREAD
	sub	rax,qword ptr a_stack_size_offset[r9]
 else
	sub	rax,qword ptr ab_stack_size
 endif

	add	rax,7
	and	rax,-8

	mov	rsi,rax
 if THREAD
	mov	stack_p_offset[r9],rax
 else
	mov	stack_p,rax
 endif
 ife THREAD
	add	rax,qword ptr ab_stack_size
	sub	rax,64
	mov	qword ptr end_a_stack,rax 
 endif
	lea	rcx,small_integers
	xor	rax,rax 
	lea	rbx,(dINT+2)

make_small_integers_lp:
	mov	[rcx],rbx 
	mov	8[rcx],rax 
	inc	rax 
	add	rcx,16
	cmp	rax,33
	jne	make_small_integers_lp

	lea	rcx,static_characters
	xor	rax,rax 
	lea	rbx,(CHAR+2)

make_static_characters_lp:
	mov	[rcx],rbx 
	mov	8[rcx],rax 
	inc	rax 
	add	rcx,16
	cmp	rax,256
	jne	make_static_characters_lp

	lea	rcx,(caf_list+8)
	mov	qword ptr caf_listp,rcx 

	lea	rcx,__Nil-8
	mov	qword ptr finalizer_list,rcx
	mov	qword ptr free_finalizer_list,rcx

 if THREAD
	mov	heap_p1_offset[r9],rdi

	mov	rbp,qword ptr heap_size_257_offset[r9]
 else
	mov	heap_p1,rdi

	mov	rbp,qword ptr heap_size_257
 endif
	shl	rbp,4
	lea	rax,[rdi+rbp*8]
 if THREAD
	mov	heap_copied_vector_offset[r9],rax
	add	rax,heap_copied_vector_size_offset[r9]
	mov	heap_p2_offset[r9],rax

	mov	byte ptr garbage_collect_flag_offset[r9],0
 else
	mov	heap_copied_vector,rax
	add	rax,heap_copied_vector_size
	mov	heap_p2,rax

	mov	byte ptr garbage_collect_flag,0
 endif

	test	byte ptr flags,64
	je	no_mark1

 if THREAD
	mov	rax,qword ptr heap_size_65_offset[r9]
	mov	qword ptr heap_vector_offset[r9],rdi 
 else
	mov	rax,qword ptr heap_size_65
	mov	qword ptr heap_vector,rdi 
 endif
	add	rdi,rax

	add	rdi,7
	and	rdi,-8

 if THREAD
	mov	qword ptr heap_p3_offset[r9],rdi
 else
	mov	qword ptr heap_p3,rdi
 endif
	lea	rbp,[rax*8]
 if THREAD
	mov	byte ptr garbage_collect_flag_offset [r9],-1
 else
	mov	byte ptr garbage_collect_flag,-1
 endif

no_mark1:
	mov	rax,qword ptr initial_heap_size

	mov	rbx,4000
	test	byte ptr flags,64
	jne	no_mark9
	add	rbx,rbx 
no_mark9:

	cmp	rax,rbx 
	jle	too_large_or_too_small
	shr	rax,3
	cmp	rax,rbp 
	jge	too_large_or_too_small
	mov	rbp,rax 
too_large_or_too_small:

	lea	rax,[rdi+rbp*8]
 if THREAD
	mov	heap_end_after_gc_offset[r9],rax
 else
	mov	heap_end_after_gc,rax
 endif

	test	byte ptr flags,64
	je	no_mark2
 if THREAD
	mov	qword ptr bit_vector_size_offset[r9],rbp
 else
	mov	qword ptr bit_vector_size,rbp
 endif
no_mark2:

	mov	r15,rbp

	add	rsp,32+8
	xor	rax,rax
	ret

 if THREAD
tls_alloc_error:
	mov	rbp,rsp
	and	rsp,-16
  ifdef LINUX
	lea	rdi,tls_alloc_error_string
  else
	lea	rcx,tls_alloc_error_string
  endif
	call	ew_print_string
	mov	rsp,rbp

	add	rsp,8
	mov	rax,1
	ret
 endif

no_memory_2:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	lea	rdi,out_of_memory_string_1
 else
	lea	rcx,out_of_memory_string_1
 endif
	call	ew_print_string
	mov	rsp,rbp

	mov	qword ptr execution_aborted,1

	add	rsp,32
 if THREAD
 	mov	r9,rbx
 endif
	mov	rax,1
	ret

no_memory_3:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	lea	rdi,out_of_memory_string_1
 else
	lea	ecx,out_of_memory_string_1
 endif
	call	ew_print_string

	mov	qword ptr execution_aborted,1

 if THREAD
 	mov	r9,rbx
 endif

 ifdef LINUX
  if THREAD
	mov	rdi,heap_mbp_offset[r9]
  else
	mov	rdi,heap_mbp
  endif
	call	free
 else
  if THREAD
	mov	rcx,heap_mbp_offset[r9]
  else
	mov	rcx,heap_mbp
  endif
	call	free_memory
 endif

	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	add	rsp,32
	mov	rax,1
	ret

exit_clean:
	call	add_execute_time

	mov	rax,qword ptr flags
	test	al,8
	je	no_print_execution_time

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifndef LINUX
	sub	rsp,32
 endif

 ifdef LINUX
	lea	rdi,time_string_1
 else
	lea	rcx,time_string_1
 endif
	call	ew_print_string

	mov	rax,execute_time
	call	print_time
	
 ifdef LINUX
	lea	rdi,time_string_2
 else
	lea	rcx,time_string_2
 endif
	call	ew_print_string

	mov	rax,garbage_collect_time
 ifdef MEASURE_GC
 else
	add	rax,mark_compact_garbage_collect_time
	add	rax,compact_garbage_collect_time
 endif
	call	print_time

 ifdef MEASURE_GC

  ifdef LINUX
	lea	rdi,time_string_3
  else
	lea	rcx,time_string_3
  endif
	call	ew_print_string

	mov	rax,mark_compact_garbage_collect_time
	call	print_time

  ifdef LINUX
	lea	rdi,time_string_3
  else
	lea	rcx,time_string_3
  endif
	call	ew_print_string

	mov	rax,compact_garbage_collect_time
	call	print_time
 
 endif

 ifdef LINUX
	lea	rdi,time_string_4
 else
	lea	rcx,time_string_4
 endif
	call	ew_print_string

	mov	rax,execute_time
	add	rax,garbage_collect_time
	add	rax,IO_time

	add	rax,mark_compact_garbage_collect_time
	add	rax,compact_garbage_collect_time

	call	print_time

 ifdef LINUX
	mov	rdi,10
 else
	mov	rcx,10
 endif
	call	ew_print_char

 ifdef MEASURE_GC

  ifdef LINUX
	mov	rdi,total_gc_bytes
  else
	mov	rcx,total_gc_bytes
  endif
	call	ew_print_int

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

  ifdef LINUX
	mov rdi,total_compact_gc_bytes
  else
	mov rcx,total_compact_gc_bytes
  endif
	call	ew_print_int

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr garbage_collect_time
	divsd	xmm0,xmm1
	call	ew_print_real

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr mark_compact_garbage_collect_time
	divsd	xmm0,xmm1
	call	ew_print_real

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr compact_garbage_collect_time
	divsd	xmm0,xmm1
	call	ew_print_real

  ifdef LINUX
	mov	rdi,10
  else
	mov	rcx,10
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	ew_print_real

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr mark_compact_garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	ew_print_real

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr compact_garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	ew_print_real

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr mark_compact_garbage_collect_time
	cvtsi2sd	xmm3,qword ptr compact_garbage_collect_time
	addsd	xmm2,xmm3
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	ew_print_real

  ifdef LINUX
	mov	rdi,10
  else
	mov	rcx,10
  endif
	call	ew_print_char
 
 endif

	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

no_print_execution_time:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
  if THREAD
	mov	rdi,stack_mbp_offset[r9]
  else
	mov	rdi,stack_mbp
  endif
	call	free
  if THREAD
 	mov	r9,rbx
  endif

  if THREAD
	mov	rdi,heap_mbp_offset[r9]
  else
	mov	rdi,heap_mbp
  endif
	call	free
 else
   if THREAD
	mov	rcx,stack_mbp_offset[r9]
   else
	mov	rcx,stack_mbp
   endif
	sub	rsp,32
	call	free_memory
  if THREAD
 	mov	r9,rbx
  endif

  if THREAD
	mov	rcx,heap_mbp_offset[r9]
  else
	mov	rcx,heap_mbp
  endif
	call	free_memory
	add	rsp,32
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

 ifdef PROFILE
  ifndef TRACE
	call	write_profile_information
  endif
 endif

	ret

__driver:
	mov	rbp,qword ptr flags
	test	rbp,16
	je	__print__graph
	jmp	__eval__to__nf

print_time:
	push	rbp
 if THREAD
	mov	r14,r9
 	push	rbx
 endif

	xor	rdx,rdx 
	mov	rbx,1000
	div	rbx
	mov	rcx,rax 
	mov	rax,rdx 
	xor	rdx,rdx 
	mov	rbx,10
	div	rbx

	push	rax

	mov	rbp,rsp
	and	rsp,-16
 ifdef LINUX
	mov	rdi,rcx
 else
	sub	rsp,32
 endif
	call	ew_print_int
	mov	rsp,rbp

	lea	rcx,sprintf_time_buffer

	xor	rdx,rdx 
	mov	rbx,10

;	movb	$'.',(%rcx)
	mov	byte ptr [rcx],46

	pop	rax

	div	rbx 
	add	rax,48
	add	rdx,48
	mov	byte ptr 1[rcx],al 
	mov	byte ptr 2[rcx],dl 

	mov	rbp,rsp
	and	rsp,-16
 ifdef LINUX
	mov	rsi,3
	mov	rdi,rcx
 else
	mov	rdx,3
	sub	rsp,32
 endif
	call	ew_print_text
	mov	rsp,rbp

 if THREAD
 	pop	rbx
 	mov	r9,r14
 endif
	pop	rbp
	ret

print_sc:
	mov	rbp,basic_only
	test	rbp,rbp 
	jne	end_print

print:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rax
 else
	mov	rcx,rax
	sub	rsp,32
 endif
	call	w_print_string
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

end_print:
	ret

dump:
	call	print
	jmp	halt

printD:	test	al,2
	jne	printD_

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi

	lea	rdi,4[rax]
	mov	esi,0[rax]
 else
	lea	rcx,4[rax]
	mov	edx,dword ptr [rax]
	sub	rsp,32
 endif
	call	w_print_text
 ifdef LINUX
	mov	rsi,r13
	mov	rsi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

DtoAC_record:
 ifdef NEW_DESCRIPTORS
	movsxd	rbp,dword ptr (-6)[rax]
 else
	movsx	rbp,dword ptr (-4)[rbp]
 endif
	jmp	DtoAC_string_a2

DtoAC:	test	al,2
	jne	DtoAC_

	mov	rbp,rax 
	jmp	DtoAC_string_a2

DtoAC_:
 ifdef NEW_DESCRIPTORS
	cmp	word ptr (-2)[rax],256
	jae	DtoAC_record

	movzx	rbx,word ptr [rax]
	lea	rbp,10[rax+rbx]
 else
	lea	rbp,(-2)[rax]
	movsx	rbx,word ptr [rbp]
	cmp	rbx,256
	jae	DtoAC_record

	shl	rbx,3
	sub	rbp,rbx 

 	movzx	rbx,word ptr (-2)[rbp]
	lea	rbp,4[rbp+rbx*8]
 endif

DtoAC_string_a2:
	mov	eax,dword ptr [rbp]
	lea	rcx,4[rbp]
	jmp	build_string

print_symbol:
	xor	rbx,rbx 
	jmp	print_symbol_2

print_symbol_sc:
	mov	rbx,basic_only
print_symbol_2:
	mov	rax,[rcx]

	cmp	rax,offset dINT+2
	je	print_int_node

	cmp	rax,offset CHAR+2
	je	print_char_denotation

	cmp	rax,offset BOOL+2
	je	print_bool

	cmp	rax,offset REAL+2
	je	print_real_node
	
	test	rbx,rbx 
	jne	end_print_symbol

printD_:
 ifdef NEW_DESCRIPTORS
	cmp	word ptr (-2)[rax],256
	jae	print_record

	movzx	rbx,word ptr [rax]
	lea	rbp,10[rax+rbx]
	jmp	print_string_a2

print_record:
	movsxd	rbp,dword ptr (-6)[rax]
	jmp	print_string_a2
 else
	lea	rbp,(-2)[rax]
	movsx	rbx,word ptr [rbp]
	cmp	rbx,256
	jae	print_record

	shl	rbx,3
	sub	rbp,rbx

  	movzx	rbx,word ptr (-2)[rbp]
	lea	rbp,4[rbp+rbx*8]
	jmp	print_string_a2

print_record:
	mov	ebp,(-4)[rbp]
	jmp	print_string_a2
 endif

end_print_symbol:
	ret

print_int_node:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,8[rcx]
 else
	sub	rsp,32
	mov	rcx,8[rcx]
 endif
	call	w_print_int
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_int:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rax
 else
	mov	rcx,rax
	sub	rsp,32
 endif
	call	w_print_int
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_char_denotation:
	test	rbx,rbx 
	jne	print_char_node

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	r14,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
 else
	sub	rsp,32
 endif
	mov	rbx,8[rcx]

 ifdef LINUX
	mov	rdi,0x27
 else
	mov	rcx,27h
 endif
	call	w_print_char

 ifdef LINUX
	mov	rdi,rbx
 else
	mov	rcx,rbx
 endif
	call	w_print_char

 ifdef LINUX
	mov	rdi,0x27
 else
	mov	rcx,27h
 endif
	call	w_print_char

 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,r14
 endif
	ret

print_char_node:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
 
	mov	rdi,8[rcx]
else
	mov	rcx,8[rcx]
	sub	rsp,32
 endif
	call	w_print_char
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret
	
print_char:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	
	mov	rdi,rax
 else
	mov	rcx,rax 
	sub	rsp,32
 endif
	call	w_print_char
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_bool:
	movsx	rcx,byte ptr 8[rcx]
	test	rcx,rcx 
	je	print_false

print_true:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,true_c_string
 else
	lea	rcx,true_c_string
	sub	rsp,32
 endif
	call	w_print_string
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_false:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,false_c_string
 else
	lea	rcx,false_c_string
	sub	rsp,32
 endif
	call	w_print_string
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_real_node:
	movlpd	xmm0,qword ptr 8[rcx]
print_real:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
 else
	sub	rsp,32
 endif
	call	w_print_real
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print_string_a2:
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,4[rbp]
	mov	esi,0[rbp]
	mov	rbp,rsp
	and	rsp,-16
 else
	lea	rcx,4[rbp]
	mov	edx,0[rbp]
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
 endif
	call	w_print_text
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	ret

print__chars__sc:
	mov	rbp,basic_only
	test	rbp,rbp 
	jne	no_print_chars

print__string__:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rsi,8[rcx]
	lea	rdi,16[rcx]
 else
	mov	rdx,8[rcx]
	lea	rcx,16[rcx]
	sub	rsp,32
 endif
	call	w_print_text
 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
no_print_chars:
	ret

push_a_r_args:
	push	rdi

	mov	rdx,qword ptr 16[rcx]
	sub	rdx,2
	movzx	rdi,word ptr [rdx]
	sub	rdi,256
	movzx	rbx,word ptr 2[rdx]
	add	rdx,4
	push	rdx 
		
	mov	rdx,rdi 
	sub	rdx,rbx 

	shl	rax,3
	lea	rcx,24[rcx+rbx*8]
	dec	rdi 
mul_array_size_lp:
	add	rcx,rax 
	sub	rdi,1
	jnc	mul_array_size_lp

	lea	rdi,[rcx+rdx*8]
	jmp	push_a_elements
push_a_elements_lp:
	mov	rax,qword ptr (-8)[rcx]
	sub	rcx,8
	mov	qword ptr [rsi],rax 
	add	rsi,8
push_a_elements:
	sub	rbx,1
	jnc	push_a_elements_lp

	mov	rcx,rdi
	pop	rax
	pop	rdi

	pop	rbp 
	jmp	push_b_elements
push_b_elements_lp:
	push	(-8)[rcx]
	sub	rcx,8
push_b_elements:
	sub	rdx,1
	jnc	push_b_elements_lp

	jmp	rbp

push_t_r_args:
	pop	rbp

	mov	rdx,qword ptr [rcx]
	add	rcx,8
	sub	rdx,2
	movzx	rax,word ptr [rdx]
	sub	rax,256
	movzx	rbx,word ptr 2[rdx]
	add	rdx,4

	mov	qword ptr [rsi],rdx
	mov	qword ptr 8[rsi],rbx

	sub	rbx,rax
	neg	rbx 

	lea	rdx,[rcx+rax*8]
	cmp	rax,2
	jbe	small_record
	mov	rdx,qword ptr 8[rcx]
	lea	rdx,(-8)[rdx+rax*8]
small_record:
	jmp	push_r_b_elements

push_r_b_elements_lp:
	dec	rax 
	jne	not_first_arg_b
	
	push	[rcx]
	jmp	push_r_b_elements
not_first_arg_b:
	push	(-8)[rdx]
	sub	rdx,8
push_r_b_elements:
	sub	rbx,1
	jnc	push_r_b_elements_lp

	mov	rbx,qword ptr 8[rsi]
	push	rbp
	push	[rsi]
	jmp	push_r_a_elements

push_r_a_elements_lp:
	dec	rax 
	jne	not_first_arg_a
	
	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rsi],rbp
	add	rsi,8
	jmp	push_r_a_elements
not_first_arg_a:
	mov	rbp,qword ptr (-8)[rdx]
	sub	rdx,8
	mov	qword ptr [rsi],rbp
	add	rsi,8
push_r_a_elements:
	sub	rbx,1
	jnc	push_r_a_elements_lp

	pop	rax 
	ret

BtoAC:
	test	al,al 
	je	BtoAC_false
BtoAC_true:
	mov	rcx,offset true_string
	ret
BtoAC_false:
	mov	rcx,offset false_string
	ret

RtoAC:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rsi,printf_real_string
	lea	rdi,sprintf_buffer
	mov	rax,1
	call	sprintf
	mov	rsi,r13
	mov	rdi,r14
 else
	lea	rdx,sprintf_buffer
	sub	rsp,32
	call	convert_real_to_string
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif
	jmp	return_sprintf_buffer

ItoAC:
	mov	rcx,offset sprintf_buffer
	call	int_to_string
	
	mov	rax,rcx
	sub	rax,offset sprintf_buffer

	jmp	sprintf_buffer_to_string

	public	convert_int_to_string
convert_int_to_string:
	push	rbp
	push	rbx
	mov	rax,rdx
	call	int_to_string
	mov	rax,rcx 
	pop	rbx
	pop	rbp
	ret

int_to_string:
	test	rax,rax
	jns	no_minus
	mov	byte ptr [rcx],45
	inc	rcx
	neg	rax 
no_minus:
	mov	rbp,rcx

	je	zero_digit
	
calculate_digits:
	cmp	rax,10
	jb	last_digit

	mov	rdx,0cccccccccccccccdh
	mov	rbx,rax 

	mul	rdx  

	mov	rax,rdx 
	and	rdx,-8
	add	rbx,48

	shr	rax,3
	sub	rbx,rdx
	shr	rdx,2

	sub	rbx,rdx
	mov	byte ptr [rcx],bl 

	inc	rcx
	jmp	calculate_digits

last_digit:
	test	rax,rax 
	je	no_zero
zero_digit:
	add	rax,48
	mov	byte ptr [rcx],al 
	inc	rcx
no_zero:
	mov	rdx,rcx

reverse_digits:
	dec	rdx
	cmp	rbp,rdx
	jae	end_reverse_digits
	mov	bl,byte ptr [rbp]
	mov	al,byte ptr [rdx] 
	mov	byte ptr [rdx],bl
	mov	byte ptr [rbp],al
	inc	rbp
	jmp	reverse_digits

end_reverse_digits:
	mov	byte ptr [rcx],0
	ret

return_sprintf_buffer:
	mov	rax,offset sprintf_buffer-1
skip_characters:
	inc	rax 
	cmp	byte ptr [rax],0
	jne	skip_characters

	sub	rax,offset sprintf_buffer

sprintf_buffer_to_string:
	mov	rcx,offset sprintf_buffer
build_string:

	lea	rbx,16+7[rax]
	shr	rbx,3

	sub	r15,rbx
	jge	D_to_S_no_gc

	push	rcx 
	call	collect_0
	pop	rcx 

D_to_S_no_gc:
 if THREAD
	lea	rbp,__STRING__+2
	sub	rbx,2
	mov	qword ptr [rdi],rbp
	mov	8[rdi],rax 
	mov	rbp,rdi 
 else
	sub	rbx,2
	mov	rbp,rdi
	lea	r9,__STRING__+2
	mov	qword ptr [rdi],r9
	mov	8[rdi],rax 
 endif
	add	rdi,16
	jmp	D_to_S_cp_str_2

D_to_S_cp_str_1:
	mov	rax,[rcx]
	add	rcx,8
	mov	[rdi],rax 
	add	rdi,8
D_to_S_cp_str_2:
	sub	rbx,1
	jnc	D_to_S_cp_str_1
	
	mov	rcx,rbp 
	ret

eqD:	mov	rax,[rcx]
	cmp	rax,[rdx]
	jne	eqD_false

	cmp	rax,offset dINT+2
	je	eqD_INT
	cmp	rax,offset CHAR+2
	je	eqD_CHAR
	cmp	rax ,offset BOOL+2
	je	eqD_BOOL
	cmp	rax ,offset REAL+2
	je	eqD_REAL

	mov	rax ,1
	ret

eqD_CHAR:
eqD_INT:
	mov	rbx,8[rcx]
	xor	rax,rax 
	cmp	rbx,8[rdx]
	sete	al
	ret

eqD_BOOL:
	mov	bl,byte ptr 8[rcx]
	xor	rax,rax 
	cmp	bl,byte ptr 8[rdx]
	sete	al 
	ret

eqD_REAL:
	movlpd	xmm0,qword ptr 8[rcx]
	comisd	xmm0,qword ptr 8[rdx]
	fnstsw	ax
	and	ah,68
	xor	ah,64
	sete	al
	and	rax,1
	ret

eqD_false:
	xor	rax ,rax 
	ret
;
;	the timer
;


init_timer:
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rsp
	call    times
	mov	rsi,r13
	mov	rdi,r14
	mov	eax,[rsp]
	imul	eax,10
 else
	call	GetTickCount
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

	mov	last_time,rax
	xor	rax,rax
	mov	execute_time,rax
	mov	garbage_collect_time,rax
	mov	IO_time,rax

	mov	mark_compact_garbage_collect_time,rax 
	mov	compact_garbage_collect_time,rax 

	ret

get_time_diff:
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rsp
	call    times
	mov	rsi,r13
	mov	rdi,r14
	mov	eax,[rsp]
	imul	eax,10
 else
	call	GetTickCount
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

	lea	rcx,last_time
	mov	rdx,[rcx]
	mov	[rcx],rax 
	sub	rax,rdx
	ret
	
add_execute_time:
	call	get_time_diff
	lea	rcx,execute_time

add_time:
	add	rax,[rcx]
	mov	[rcx],rax 
	ret

add_garbage_collect_time:
	call	get_time_diff
	mov	rcx,offset garbage_collect_time
	jmp	add_time

add_IO_time:
	call	get_time_diff
	mov	rcx,offset IO_time
	jmp	add_time

add_mark_compact_garbage_collect_time:
	call	get_time_diff
	mov	rcx,offset mark_compact_garbage_collect_time
	jmp	add_time

add_compact_garbage_collect_time:
	call	get_time_diff
	mov	rcx,offset compact_garbage_collect_time
	jmp	add_time
;
;	the garbage collector
;

collect_3:
 ifdef PROFILE
	lea	rbp,garbage_collector_name
	call	profile_s
 endif
	mov	[rsi],rcx 
	mov	8[rsi],rdx 
	mov	16[rsi],r8
	add	rsi,24
	call	collect_0_
	mov	r8,(-8)[rsi]
	mov	rdx,(-16)[rsi]
	mov	rcx,(-24)[rsi]
	sub	rsi,24
 ifdef PROFILE
	jmp	profile_r
 else
	ret
 endif

collect_2:
 ifdef PROFILE
	lea	rbp,garbage_collector_name
	call	profile_s
 endif
	mov	[rsi],rcx 
	mov	8[rsi],rdx 
	add	rsi,16
	call	collect_0_
	mov	rdx,(-8)[rsi]
	mov	rcx,(-16)[rsi]
	sub	rsi,16
 ifdef PROFILE
	jmp	profile_r
 else
	ret
 endif

collect_1:
 ifdef PROFILE
	lea	rbp,garbage_collector_name
	call	profile_s
 endif
	mov	[rsi],rcx 
	add	rsi,8
	call	collect_0_
	mov	rcx,(-8)[rsi]
	sub	rsi,8
 ifdef PROFILE
	jmp	profile_r
 else
	ret
 endif

collect_0:
 ifdef PROFILE
	lea	rbp,garbage_collector_name
	call	profile_s
 endif
	call	collect_0_
 ifdef PROFILE
	jmp	profile_r
 else
	ret
 endif

collect_0_:
	mov	rbp,rdi

	push	rax
	push	rbx

 if THREAD
	mov	rbx,qword ptr heap_end_after_gc_offset[r9]
 else
	mov	rbx,qword ptr heap_end_after_gc
 endif
	sub	rbx,rdi

	shr	rbx,3
	sub	rbx,r15
 if THREAD
	mov	qword ptr n_allocated_words_offset[r9],rbx
 else
	mov	qword ptr n_allocated_words,rbx
 endif

	test	byte ptr flags,64
	je	no_mark3

 if THREAD
	mov	rbp,qword ptr bit_counter_offset[r9]
 else
	mov	rbp,qword ptr bit_counter
 endif
	test	rbp,rbp 
	je	no_scan

	push	rsi
	mov	rsi,rbx

	xor	rbx,rbx
 if THREAD
	mov	rcx,qword ptr bit_vector_p_offset[r9]
 else
	mov	rcx,qword ptr bit_vector_p
 endif

scan_bits:
	cmp	ebx,dword ptr[rcx]
	je	zero_bits
	mov	dword ptr [rcx],ebx 
	add	rcx,4
	sub	rbp,1
	jne	scan_bits

	jmp	end_scan

zero_bits:
	lea	rdx,4[rcx]
	add	rcx,4
	sub	rbp,1
	jne	skip_zero_bits_lp1
	jmp	end_bits

skip_zero_bits_lp:
	test	rax,rax 
	jne	end_zero_bits
skip_zero_bits_lp1:
	mov	eax,dword ptr [rcx]
	add	rcx,4
	sub	rbp,1
	jne	skip_zero_bits_lp

	test	rax,rax 
	je	end_bits
	mov	dword ptr (-4)[rcx],ebx 
	mov	rax,rcx 
	sub	rax,rdx 
	jmp	end_bits2

end_zero_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	shl	rax,3
 if THREAD
	add	qword ptr n_free_words_after_mark_offset[r9],rax 
 else
	add	qword ptr n_free_words_after_mark,rax
 endif
	mov	dword ptr (-4)[rcx],ebx

	cmp	rax,rsi
	jb	scan_bits

found_free_memory:
 if THREAD
	mov	qword ptr bit_counter_offset[r9],rbp
	mov	qword ptr bit_vector_p_offset[r9],rcx
 else
	mov	qword ptr bit_counter,rbp
	mov	qword ptr bit_vector_p,rcx
 endif

	lea	rbp,(-4)[rdx]
 if THREAD
	sub	rbp,qword ptr heap_vector_offset[r9]
 else
	sub	rbp,qword ptr heap_vector
 endif
	shl	rbp,6
 if THREAD
	mov	rdi,qword ptr heap_p3_offset[r9]
 else
	mov	rdi,qword ptr heap_p3
 endif
	add	rdi,rbp 

	lea	rbp,[rdi+rax*8]
 if THREAD
	mov	qword ptr heap_end_after_gc_offset[r9],rbp
 else
	mov	qword ptr heap_end_after_gc,rbp
 endif

	mov	r15,rax
	sub	r15,rsi

	pop	rsi 
	pop	rbx 
	pop	rax 
	ret

end_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	add	rax,4
end_bits2:
	shl	rax,3
 if THREAD
	add	qword ptr n_free_words_after_mark_offset[r9],rax 
 else
	add	qword ptr n_free_words_after_mark,rax 
 endif
	cmp	rax,rsi 
	jae	found_free_memory

end_scan:
	pop	rsi
 if THREAD
	mov	qword ptr bit_counter_offset[r9],rbp 
 else
	mov	qword ptr bit_counter,rbp 
 endif

no_scan:

no_mark3:
 if THREAD
	movsx	rax,byte ptr garbage_collect_flag_offset[r9]
 else
	movsx	rax,byte ptr garbage_collect_flag
 endif
	test	rax,rax 
	jle	collect

	sub	rax,2
 if THREAD
	mov	byte ptr garbage_collect_flag_offset[r9],al 

	mov	rbp,qword ptr extra_heap_size_offset[r9]
 else
	mov	byte ptr garbage_collect_flag,al 

	mov	rbp,qword ptr extra_heap_size
 endif
	cmp	rbx,rbp 
	ja	collect

 if THREAD
	mov	rdi,qword ptr extra_heap_offset[r9]
 else
	mov	rdi,qword ptr extra_heap
 endif

	mov	r15,rbp

	lea	rbp,[rdi+rbp*8]
 if THREAD
	mov	qword ptr heap_end_after_gc_offset[r9],rbp
 else
	mov	qword ptr heap_end_after_gc,rbp
 endif

	sub	r15,rbx

	pop	rbx 
	pop	rax 
	ret

collect:
 ifdef LINUX
	sub	rsp,104
 else
	sub	rsp,88
 endif
	mov	32[rsp],r10
	mov	24[rsp],r11
	mov	16[rsp],r12
	mov	8[rsp],r13
	mov	[rsp],r14
	movsd	40[rsp],xmm0
	movsd	48[rsp],xmm1
	movsd	56[rsp],xmm2
	movsd	64[rsp],xmm3
	movsd	72[rsp],xmm4
	movsd	80[rsp],xmm5
 ifdef LINUX
	movsd	88[rsp],xmm6
	movsd	96[rsp],xmm7
 endif

	call	add_execute_time

	test	qword ptr flags,4
	je	no_print_stack_sizes

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
 	mov	r13,rsi
	mov	r14,rdi
 else
	sub	rsp,32
 endif

 if 0
  ifdef LINUX
	mov	rdi,qword ptr 64[rsp]
  else
	mov	rcx,qword ptr 96[rsp]
  endif
	call	ew_print_int

  ifdef LINUX
	mov	rdi,32
  else
	mov	rcx,32
  endif
	call	ew_print_char
 endif

 ifdef LINUX
	lea	rdi,garbage_collect_string_1
 else
	lea	rcx,garbage_collect_string_1
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rdi,r13
  if THREAD
	mov	r9,rbx
	sub	rdi,stack_p_offset[r9]
  else
	sub	rdi,stack_p
  endif
 else
	mov	rcx,rsi
  if THREAD
	mov	r9,rbx
	sub	rcx,stack_p_offset[r9]
  else
	sub	rcx,stack_p
  endif
 endif
	call	ew_print_int

 ifdef LINUX
	lea	rdi,garbage_collect_string_2
 else
	lea	rcx,garbage_collect_string_2
 endif
	call	ew_print_string

 ifdef LINUX
  if THREAD
	mov	r9,rbx
	mov	rdi,halt_sp_offset[r9]
  else
	mov	rdi,halt_sp
  endif
	sub	rdi,rsp 
 else
  if THREAD
	mov	r9,rbx
	mov	rcx,halt_sp_offset[r9]
  else
	mov	rcx,halt_sp
  endif
	sub	rcx,rsp 
 endif
	call	ew_print_int

 ifdef LINUX
	lea	rdi,garbage_collect_string_3
 else
	lea	rcx,garbage_collect_string_3
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,rbp
  if THREAD
 	mov	r9,rbx
  endif

no_print_stack_sizes:
 if THREAD
	mov	rax,stack_p_offset[r9]
	add	rax,qword ptr a_stack_size_offset[r9]
 else
	mov	rax,stack_p
	add	rax,qword ptr ab_stack_size
 endif
	cmp	rsi,rax 
	ja	stack_overflow

	test	byte ptr flags,64
	jne	compacting_collector

 if THREAD
	cmp	byte ptr garbage_collect_flag_offset[r9],0
 else
	cmp	byte ptr garbage_collect_flag,0
 endif
	jne	compacting_collector

 if THREAD
	mov	rbp,heap_copied_vector_offset[r9]

	cmp	qword ptr heap_end_after_copy_gc_offset[r9],0
 else
	mov	rbp,heap_copied_vector

	cmp	qword ptr heap_end_after_copy_gc,0
 endif

	je	zero_all

	mov	rax,rdi
 if THREAD
	sub	rax,qword ptr heap_p1_offset[r9]
 else
	sub	rax,qword ptr heap_p1
 endif
	add	rax,127*8
	shr	rax,9
	call	zero_bit_vector

 if THREAD
	mov	rdx,qword ptr heap_end_after_copy_gc_offset[r9]
	sub	rdx,qword ptr heap_p1_offset[r9]
 else
	mov	rdx,qword ptr heap_end_after_copy_gc
	sub	rdx,qword ptr heap_p1
 endif
	shr	rdx,7
	and	rdx,-4

 if THREAD
	mov	rbp,qword ptr heap_copied_vector_offset[r9]
	mov	rax,qword ptr heap_copied_vector_size_offset[r9]
 else
	mov	rbp,qword ptr heap_copied_vector
	mov	rax,qword ptr heap_copied_vector_size
 endif
	add	rbp,rdx 
	sub	rax,rdx 
	shr	rax,2

 if THREAD
	mov	qword ptr heap_end_after_copy_gc_offset[r9],0
 else
	mov	qword ptr heap_end_after_copy_gc,0
 endif

	call	zero_bit_vector
	jmp	end_zero_bit_vector

zero_all:
 if THREAD
	mov	rax,heap_copied_vector_size_offset[r9]
 else
	mov	rax,heap_copied_vector_size
 endif
	shr	rax,2
	call	zero_bit_vector

end_zero_bit_vector:

	include	acopy.asm

 if THREAD
	mov	qword ptr heap2_begin_and_end_offset[r9],rsi 
 else
	mov	qword ptr heap2_begin_and_end,rsi 
 endif
	mov	r15,rsi
	sub	r15,rdi

 if THREAD
	mov	rax,heap_size_257_offset[r9]
 else
	mov	rax,heap_size_257
 endif
	shl	rax,7
	sub	rax,r15
	add	qword ptr total_gc_bytes,rax

	shr	r15,3

	pop	rsi 

	call	add_garbage_collect_time

 if THREAD
	sub	r15,qword ptr n_allocated_words_offset[r9]
 else
	sub	r15,qword ptr n_allocated_words
 endif
	jc	switch_to_mark_scan

	lea	rax,[r15+r15*4]
	shl	rax,6
 if THREAD
	mov	rbx,qword ptr heap_size_offset[r9]
 else
	mov	rbx,qword ptr heap_size
 endif
	mov	rcx,rbx 
	shl	rbx,2
	add	rbx,rcx 
	add	rbx,rbx 
	add	rbx,rcx
	cmp	rax,rbx
	jnc	no_mark_scan

switch_to_mark_scan:
 if THREAD
	mov	rax,qword ptr heap_size_65_offset[r9]
 else
	mov	rax,qword ptr heap_size_65
 endif
	shl	rax,6
 if THREAD
	mov	rbx,qword ptr heap_p_offset[r9]

	mov	rcx,qword ptr heap_p1_offset[r9]
	cmp	rcx,qword ptr heap_p2_offset[r9]
 else
	mov	rbx,qword ptr heap_p

	mov	rcx,qword ptr heap_p1
	cmp	rcx,qword ptr heap_p2
 endif
	jc	vector_at_begin
	
vector_at_end:
 if THREAD
	mov	qword ptr heap_p3_offset[r9],rbx 
 else
	mov	qword ptr heap_p3,rbx
 endif
	add	rbx,rax
 if THREAD
	mov	qword ptr heap_vector_offset[r9],rbx 

	mov	rax,qword ptr heap_p1_offset[r9]
	mov	qword ptr extra_heap_offset[r9],rax 
 else
	mov	qword ptr heap_vector,rbx

	mov	rax,qword ptr heap_p1
	mov	qword ptr extra_heap,rax
 endif
	sub	rbx,rax
	shr	rbx,3
 if THREAD
	mov	qword ptr extra_heap_size_offset[r9],rbx
 else
	mov	qword ptr extra_heap_size,rbx
 endif
	jmp	switch_to_mark_scan_2

vector_at_begin:
 if THREAD
	mov	qword ptr heap_vector_offset[r9],rbx
	add	rbx,qword ptr heap_size_offset[r9]
 else
	mov	qword ptr heap_vector,rbx
	add	rbx,qword ptr heap_size
 endif
	sub	rbx,rax
 if THREAD
	mov	qword ptr heap_p3_offset[r9],rbx 
 else
	mov	qword ptr heap_p3,rbx
 endif

 if THREAD
	mov	qword ptr extra_heap_offset[r9],rbx 
	mov	rcx,qword ptr heap_p2_offset[r9]
 else
	mov	qword ptr extra_heap,rbx 
	mov	rcx,qword ptr heap_p2
 endif
	sub	rcx,rbx 
	shr	rcx,3
 if THREAD
	mov	qword ptr extra_heap_size_offset[r9],rcx 
 else
	mov	qword ptr extra_heap_size,rcx 
 endif

switch_to_mark_scan_2:
 if THREAD
	mov	rax,heap_size_257_offset[r9]
 else
	mov	rax,heap_size_257
 endif
	shl	rax,7-3
	sub	rax,r15
	shl	rax,3

 if THREAD
	mov	byte ptr garbage_collect_flag_offset[r9],1
 else
	mov	byte ptr garbage_collect_flag,1
 endif

	lea	rcx,heap_use_after_gc_string_1

	test	r15,r15
	jns	end_garbage_collect

 if THREAD
	mov	byte ptr garbage_collect_flag_offset[r9],-1

	mov	rbx,qword ptr extra_heap_size_offset[r9]
 else
	mov	byte ptr garbage_collect_flag,-1

	mov	rbx,qword ptr extra_heap_size
 endif
	mov	r15,rbx
 if THREAD
	sub	r15,qword ptr n_allocated_words_offset[r9]
 else
	sub	r15,qword ptr n_allocated_words
 endif
	js	out_of_memory_4_3

 if THREAD
	mov	rdi,qword ptr extra_heap_offset[r9]
 else
	mov	rdi,qword ptr extra_heap
 endif
	shl	rbx,3
	add	rbx,rdi
 if THREAD
	mov	qword ptr heap_end_after_gc_offset[r9],rbx
 else
	mov	qword ptr heap_end_after_gc,rbx
 endif

	mov	qword ptr heap_end_write_heap,rdi 

	mov	qword ptr d3_flag_write_heap,1
	jmp	end_garbage_collect_

no_mark_scan:
; exchange the semi_spaces
 if THREAD
	mov	rax,heap_p1_offset[r9]
	mov	rbx,heap_p2_offset[r9]
	mov	heap_p2_offset[r9],rax 
	mov	heap_p1_offset[r9],rbx 

	mov	rax,heap_size_257_offset[r9]
 else
	mov	rax,heap_p1
	mov	rbx,heap_p2
	mov	heap_p2,rax 
	mov	heap_p1,rbx 

	mov	rax,heap_size_257
 endif
	shl	rax,7-3
	mov	rbx,rax
	sub	rax,r15

	mov	rcx,rax
	imul	qword ptr heap_size_multiple
	shrd	rax,rdx,9
	shr	rdx,9
	jne	no_small_heap1

	cmp	rax,4000
	jge	not_too_small1
	mov	rax,4000
not_too_small1:
	sub	rbx,rax 
	jb	no_small_heap1

	sub	r15,rbx
	shl	rbx,3
 if THREAD
	mov	rbp,qword ptr heap_end_after_gc_offset[r9]
	mov	qword ptr heap_end_after_copy_gc_offset[r9],rbp 
 else
	mov	rbp,qword ptr heap_end_after_gc
	mov	qword ptr heap_end_after_copy_gc,rbp 
 endif
	sub	rbp,rbx
 if THREAD
	mov	qword ptr heap_end_after_gc_offset[r9],rbp
 else
	mov	qword ptr heap_end_after_gc,rbp
 endif

no_small_heap1:
	mov	rax,rcx
	shl	rax,3

	lea	rcx,heap_use_after_gc_string_1

end_garbage_collect:

	mov	qword ptr heap_end_write_heap,rdi 
	mov	qword ptr d3_flag_write_heap,0

end_garbage_collect_:
	test	qword ptr flags,2
	je	no_heap_use_message

	push	rax

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif

 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi	

	mov	rdi,rcx
 else
	sub	rsp,32
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rdi,[rbp]
 else
	mov	rcx,[rbp]
 endif
	call	ew_print_int

 ifdef LINUX
	lea	rdi,heap_use_after_gc_string_2
 else
	lea	rcx,heap_use_after_gc_string_2
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 else
 	add	rsp,32
 endif
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

	pop	rax

no_heap_use_message:
	call	call_finalizers
	 
	test	byte ptr flags,32
	je	no_write_heap

	cmp	rax,qword ptr min_write_heap_size
	jb	no_write_heap

	push	rcx 
	push 	rdx 
	push	rbp 
	push	rsi 
	push	rdi 

	sub	rsp,128

	mov	rax,qword ptr d3_flag_write_heap
	test	rax,rax 
	jne	copy_to_compact_with_alloc_in_extra_heap

 if THREAD
	movsx	rax,byte ptr garbage_collect_flag_offset[r9]

	mov	rcx,qword ptr heap2_begin_and_end_offset[r9]
	mov	rdx,qword ptr (heap2_begin_and_end_offset+8)[r9]

	lea	rbx,heap_p1_offset[r9]
 else
	movsx	rax,byte ptr garbage_collect_flag

	mov	rcx,qword ptr heap2_begin_and_end
	mov	rdx,qword ptr (heap2_begin_and_end+8)

	mov	rbx,offset heap_p1
 endif
	
	test	rax,rax 
	je	gc0

 if THREAD
	lea	rbx,heap_p2_offset[r9]
 else
	mov	rbx,offset heap_p2
 endif
	jg	gc1

 if THREAD
	lea	rbx,heap_p3_offset[r9]
 else
	mov	rbx,offset heap_p3
 endif
	xor	rcx,rcx 
	xor	rdx,rdx 

gc0:
gc1:
	mov	rbx,qword ptr [rbx]
	
	mov	rax,rsp 
	
	mov	qword ptr [rax],rbx 
	mov	qword ptr 8[rax],rdi 
	
	mov	qword ptr 16[rax],rcx 
	mov	qword ptr 24[rax],rdx 
	
 if THREAD
	mov	rbx ,qword ptr stack_p_offset[r9]
 else
	mov	rbx ,qword ptr stack_p
 endif
	mov	qword ptr 32[rax],rbx 

	mov	qword ptr 40[rax],rsi 
	mov	qword ptr 48[rax],0
	mov	qword ptr 56[rax],0
	
	mov	qword ptr 64[rax],offset small_integers
	mov	qword ptr 72[rax],offset static_characters
	
	mov	qword ptr 80[rax],offset dINT+2
	mov	qword ptr 88[rax],offset CHAR+2
	mov	qword ptr 96[rax],offset REAL+2
	mov	qword ptr 104[rax],offset BOOL+2
	mov	qword ptr 112[rax],offset __STRING__+2
	mov	qword ptr 120[rax],offset __ARRAY__+2

	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
 ifdef LINUX
	mov	rdi,rax
 else
	mov	rcx,rax
	sub	rsp,32
 endif
 ifndef LINUX
	call	write_heap
 endif
	mov	rsp,rbp
	add	rsp,128
 if THREAD
 	mov	r9,rbx
 endif
	
	pop	rdi 
	pop	rsi 
	pop	rbp 
	pop	rdx 
	pop	rcx 
no_write_heap:

restore_registers_after_gc_and_return:
	mov	r10,32[rsp]
	mov	r11,24[rsp]
	mov	r12,16[rsp]
	mov	r13,8[rsp]
	mov	r14,[rsp]
	movlpd	xmm0,40[rsp]
	movlpd	xmm1,48[rsp]
	movlpd	xmm2,56[rsp]
	movlpd	xmm3,64[rsp]
	movlpd	xmm4,72[rsp]
	movlpd	xmm5,80[rsp]
 ifdef LINUX
	movlpd	xmm6,88[rsp]
	movlpd	xmm7,96[rsp]
	add	rsp,104
 else
	add	rsp,88
 endif
	pop	rbx 
	pop	rax 
	ret

call_finalizers:
	mov	rax,qword ptr free_finalizer_list

call_finalizers_lp:
 if THREAD
	lea	rbx,__Nil-8
	cmp	rax,rbx
 else
	lea	r9,__Nil-8
	cmp	rax,r9
 endif
	je	end_call_finalizers
	push	8[rax]
	mov	rbx,qword ptr 16[rax]
	push	8[rbx]
	call	qword ptr [rbx]
	add	rsp,8
	pop	rax 
	jmp	call_finalizers_lp
end_call_finalizers:

 if THREAD
	lea	rbx,__Nil-8
	mov	qword ptr free_finalizer_list,rbx
 else
	lea	r9,__Nil-8
	mov	qword ptr free_finalizer_list,r9
 endif
	ret

copy_to_compact_with_alloc_in_extra_heap:
 if THREAD
	mov	rcx,qword ptr heap2_begin_and_end_offset[r9]
	mov	rdx,qword ptr (heap2_begin_and_end_offset+8)[r9]
	lea	rbx,heap_p2_offset[r9]
 else
	mov	rcx,qword ptr heap2_begin_and_end
	mov	rdx,qword ptr (heap2_begin_and_end+8)
	mov	rbx,offset heap_p2
 endif
	jmp	gc1

allow_prefetch_for_athlon:
	test	qword ptr flags,4096
	jne	no_prefetch_flag

	xor	rax,rax
	cpuid
	test	rax,rax
	jz	disable_prefetch_flag

 ifdef LINUX
	cmp	rbx,'A'+('u'*0x100)+('t'*0x10000)+('h'*0x1000000)
	jne	disable_prefetch_flag
	cmp	rdx,'e'+('n'*0x100)+('t'*0x10000)+('i'*0x1000000)
	jne	disable_prefetch_flag
	cmp	rcx,'c'+('A'*0x100)+('M'*0x10000)+('D'*0x1000000)
	jne	disable_prefetch_flag
 else
	cmp	rbx,'A'+('u' shl 8)+('t' shl 16)+('h' shl 24)
	jne	disable_prefetch_flag
	cmp	rdx,'e'+('n' shl 8)+('t' shl 16)+('i' shl 24)
	jne	disable_prefetch_flag
	cmp	rcx,'c'+('A' shl 8)+('M' shl 16)+('D' shl 24)
	jne	disable_prefetch_flag
 endif

;	mov	rax,1
;	cpuid
;	and	rax,0f00h
;	cmp	rax,600h
;	je	keep_prefetch_flag

	ret

disable_prefetch_flag:
	and	qword ptr flags,-4097
keep_prefetch_flag:
no_prefetch_flag:
	ret

out_of_memory_4_3:
out_of_memory_4_2:
out_of_memory_4_1:
out_of_memory_4:
	call	add_garbage_collect_time
	
	mov	rbp,offset out_of_memory_string_4
	jmp	print_error

zero_bit_vector:
	xor	rdx,rdx 
	test	al,1
	je	zero_bits1_1
	mov	dword ptr [rbp],edx 
	add	rbp,4
zero_bits1_1:
	shr	rax,1

	mov	rbx,rax 
	shr	rax,1
	test	bl,1
	je	zero_bits1_5

	sub	rbp,8
	jmp	zero_bits1_2

zero_bits1_4:
	mov	dword ptr [rbp],edx 
	mov	dword ptr 4[rbp],edx 
zero_bits1_2:
	mov	dword ptr 8[rbp],edx 
	mov	dword ptr 12[rbp],edx 
	add	rbp,16
zero_bits1_5:
	sub	rax,1
	jae	zero_bits1_4
	ret

reorder:
	push	rsi 
	push	rbp 

	mov	rbp,rax 
	shl	rbp,3
	mov	rsi,rbx 
	shl	rsi,3
	add	rcx,rsi 
	sub	rdx,rbp 

	push	rsi 
	push	rbp 
	push	rbx 
	push	rax 
	jmp	st_reorder_lp

reorder_lp:
	mov	rbp,qword ptr [rcx]
	mov	rsi,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rbp 
	sub	rdx,8
	mov	qword ptr [rcx],rsi 
	add	rcx,8
	
	dec	rax
	jne	next_b_in_element
	mov	rax,qword ptr [rsp]
	add	rcx,qword ptr 24[rsp]
next_b_in_element:
	dec	rbx 
	jne	next_a_in_element
	mov	rbx,qword ptr 8[rsp]
	sub	rdx,qword ptr 16[rsp]
next_a_in_element:
st_reorder_lp:
	cmp	rdx,rcx 
	ja	reorder_lp

	pop	rax 
	pop	rbx 
	add	rsp,16
	pop	rbp 
	pop	rsi 
	ret

;
;	the sliding compacting garbage collector
;

compacting_collector:
; zero all mark bits

 if THREAD
	mov	rax,qword ptr heap_p3_offset[r9]
 else
	mov	rax,qword ptr heap_p3
 endif
	neg	rax
 if THREAD
	mov	qword ptr neg_heap_p3_offset[r9],rax 

	mov	qword ptr stack_top_offset[r9],rsi

	mov	rdi,qword ptr heap_vector_offset[r9]
 else
	mov	qword ptr neg_heap_p3,rax

	mov	qword ptr stack_top,rsi

	mov	rdi,qword ptr heap_vector
 endif

	test	byte ptr flags,64
	je	no_mark4

 if THREAD
	cmp	qword ptr zero_bits_before_mark_offset[r9],0
 else
	cmp	qword ptr zero_bits_before_mark,0
 endif
	je	no_zero_bits

 if THREAD
	mov	qword ptr zero_bits_before_mark_offset[r9],0
 else
	mov	qword ptr zero_bits_before_mark,0
 endif

no_mark4:
	mov	rbp,rdi
 if THREAD
	mov	rax,qword ptr heap_size_65_offset[r9]
 else
	mov	rax,qword ptr heap_size_65
 endif
	add	rax,3
	shr	rax,2

	xor	rbx,rbx

	test	al,1
	je	zero_bits_1
	mov	dword ptr [rbp],ebx 
	add	rbp,4
zero_bits_1:
	mov	rcx,rax 
	shr	rax,2

	test	cl,2
	je	zero_bits_5

	sub	rbp,8
	jmp	zero_bits_2

zero_bits_4:
	mov	dword ptr [rbp],ebx 
	mov	dword ptr 4[rbp],ebx 
zero_bits_2:
	mov	dword ptr 8[rbp],ebx 
	mov	dword ptr 12[rbp],ebx 
	add	rbp,16
zero_bits_5:
	sub	rax,1
	jnc	zero_bits_4

	test	byte ptr flags,64
	je	no_mark5

no_zero_bits:
 if THREAD
	mov	rax,qword ptr n_last_heap_free_bytes_offset[r9]
	mov	rbx,qword ptr n_free_words_after_mark_offset[r9]
 else
	mov	rax,qword ptr n_last_heap_free_bytes
	mov	rbx,qword ptr n_free_words_after_mark
 endif
	shl	rbx,3

	mov	rbp,rbx 
	shl	rbp,3
	add	rbp,rbx 
	shr	rbp,2

	cmp	rax,rbp 
	jg	compact_gc

 if THREAD
	mov	rbx,qword ptr bit_vector_size_offset[r9]
 else
	mov	rbx,qword ptr bit_vector_size
 endif
	shl	rbx,3

	sub	rax,rbx 
	neg	rax

	imul	qword ptr heap_size_multiple
	shrd	rax,rdx,7
	shr	rdx,7
	jne	no_smaller_heap
	
	cmp	rax,rbx 
	jae	no_smaller_heap
	
	cmp	rbx,8000
	jbe	no_smaller_heap
	
	jmp	compact_gc
no_smaller_heap:
	test	qword ptr flags,4096
	jne	pmark

	include	amark.asm

	include	amark_prefetch.asm

compact_gc:
 if THREAD
	mov	qword ptr zero_bits_before_mark_offset[r9],1
	mov	qword ptr n_last_heap_free_bytes_offset[r9],0
	mov	qword ptr n_free_words_after_mark_offset[r9],1000
 else
	mov	qword ptr zero_bits_before_mark,1
	mov	qword ptr n_last_heap_free_bytes,0
	mov	qword ptr n_free_words_after_mark,1000
 endif

no_mark5:

	include	acompact.asm

 if THREAD
	mov	rsi,qword ptr stack_top_offset[r9]
 else
	mov	rsi,qword ptr stack_top
 endif

 if THREAD
	mov	rbx,qword ptr heap_size_65_offset[r9]
 else
	mov	rbx,qword ptr heap_size_65
 endif
	shl	rbx,6
 if THREAD
	add	rbx,qword ptr heap_p3_offset[r9]
 else
	add	rbx,qword ptr heap_p3
 endif

 if THREAD
	mov	qword ptr heap_end_after_gc_offset[r9],rbx
 else
	mov	qword ptr heap_end_after_gc,rbx
 endif

	sub	rbx,rdi
	shr	rbx,3

 if THREAD
	sub	rbx,qword ptr n_allocated_words_offset[r9]
 else
	sub	rbx,qword ptr n_allocated_words
 endif
	mov	r15,rbx
	jc	out_of_memory_4_1

	mov	rax,rbx
	shl	rax,2
	add	rax,rbx
	shl	rax,4
 if THREAD
	cmp	rax,qword ptr heap_size_offset[r9]
 else
	cmp	rax,qword ptr heap_size
 endif
	jc	out_of_memory_4_2

 	test	byte ptr flags,64
	je	no_mark_6

 if THREAD
	mov	rax,qword ptr neg_heap_p3_offset[r9]
 else
	mov	rax,qword ptr neg_heap_p3
 endif
	add	rax,rdi
 if THREAD
	mov	rbx,qword ptr n_allocated_words_offset[r9]
 else
	mov	rbx,qword ptr n_allocated_words
 endif
	lea	rax,[rax+rbx*8]

 if THREAD
	mov	rbx,qword ptr heap_size_65_offset[r9]
 else
	mov	rbx,qword ptr heap_size_65
 endif
	shl	rbx,6
	
	imul	qword ptr heap_size_multiple
	shrd	rax,rdx,8
	shr	rdx,8
	jne	no_small_heap2

	and	rax,-4

	cmp	rax,8000
	jae	not_too_small2
	mov	rax,8000
not_too_small2:
	mov	rcx,rbx 
	sub	rcx,rax 
	jb	no_small_heap2

 if THREAD
	sub	qword ptr heap_end_after_gc_offset[r9],rcx
 else
	sub	qword ptr heap_end_after_gc,rcx
 endif
	shr	rcx,3
	sub	r15,rcx

	mov	rbx,rax

no_small_heap2:
	shr	rbx,3
 if THREAD
	mov	qword ptr bit_vector_size_offset[r9],rbx
 else
	mov	qword ptr bit_vector_size,rbx
 endif

no_mark_6:
	jmp	no_copy_garbage_collection

no_copy_garbage_collection:
	call	add_compact_garbage_collect_time

	mov	rax,rdi
 if THREAD
	sub	rax,qword ptr heap_p3_offset[r9]
 else
	sub	rax,qword ptr heap_p3
 endif

	add	qword ptr total_compact_gc_bytes,rax 

	mov	rax,rdi
 if THREAD
	sub	rax,qword ptr heap_p3_offset[r9]
	mov	rbx,qword ptr n_allocated_words_offset[r9]
 else
	sub	rax,qword ptr heap_p3
	mov	rbx,qword ptr n_allocated_words
 endif
	lea	rax,[rax+rbx*8]

	lea	rcx,heap_use_after_compact_gc_string_1
	jmp	end_garbage_collect

 if 0
	public	clean_exception_handler_

clean_exception_handler_:

	jmp	clean_exception_handler_
 endif
 if 0
	mov	rax,qword ptr [rcx]
	cmp	dword ptr [rax],0c00000fdh
	je  	stack_overflow_exception

	cmp	dword ptr [rax],80000001h
	je  	guard_page_or_access_violation_exception

	cmp	dword ptr [rax] ,0c0000005h
	je  	guard_page_or_access_violation_exception

no_stack_overflow_exception:
	mov	rax,0
	ret

guard_page_or_access_violation_exception:
	mov	rax,qword ptr 16[rax]
	and	rax,-4096
	cmp	qword ptr a_stack_guard_page,rax
	jne 	no_stack_overflow_exception
	
	cmp	qword ptr a_stack_guard_page,0
	je  	no_stack_overflow_exception

stack_overflow_exception:
	mov	rax,qword ptr 8[rcx]
	mov	qword ptr (0F8h)[rax],offset stack_overflow

	mov	rax,-1
	ret
 endif

stack_overflow:
	call	add_execute_time

	mov	rbp,offset stack_overflow_string
	jmp	print_error

IO_error:
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif

	mov	rbx,rcx
 ifdef LINUX
	lea	rdi,IO_error_string
 else
	sub	rsp,32
	lea	rcx,IO_error_string
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rdi,rbx
 else
	mov	rcx,rbx
 endif
	call	ew_print_string

 ifdef LINUX
	lea	rdi,new_line_string
 else
	lea	rcx,new_line_string
 endif
	call	ew_print_string

	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

	jmp	halt

print_error:
 ifdef LINUX
	mov	rdi,rbp
 else
	mov	rcx,rbp 
 endif
	mov	rbp,rsp
	and	rsp,-16
 if THREAD
	mov	rbx,r9
 endif
	call	ew_print_string
	mov	rsp,rbp
 if THREAD
 	mov	r9,rbx
 endif

halt:
 if THREAD
	mov	rsp,halt_sp_offset[r9]
 else
	mov	rsp,halt_sp
 endif

 ifdef PROFILE
	call	write_profile_stack
 endif

	mov	qword ptr execution_aborted,1

	cmp	qword ptr dll_initialised,0
 ifdef LINUX
	je	exit_
 else
	je	exit
 endif
 ifdef LINUX
	cmp	dword ptr return_code,0
 else
	cmp	qword ptr return_code,0
 endif
	jne	return_code_set
 ifdef LINUX
	mov	dword ptr return_code,-1
 else
	mov	qword ptr return_code,-1
 endif
return_code_set:
 ifdef LINUX
	mov	edi,dword ptr return_code
	and	rsp,-16
	call	exit
 else
	push	qword ptr return_code
	call	(ExitProcess)
 endif
	jmp	return_code_set

e__system__eaind:
__eaind:
eval_fill:
	mov	[rsi],rcx 
	add	rsi,8
	mov	rcx,rdx 
	call	qword ptr [rdx]
	mov	rdx,rcx 
	mov	rcx,(-8)[rsi]
	sub	rsi,8
	
	mov	rbp,[rdx]
	mov	[rcx],rbp 
	mov	rbp,8[rdx]
	mov	8[rcx],rbp 
	mov	rbp,16[rdx]
	mov	16[rcx],rbp 
	ret

	align	(1 shl 2) 
	lea	rax,e__system__eaind
	jmp	rax
 ifdef LINUX
; pc relative lea instruction is one byte longer
	db	0,0
 else
	db	0,0,0
 endif
	dd	e__system__dind
	dd	-2
e__system__nind:
__indirection:
	mov	rdx,8[rcx]
	mov	rax,[rdx]
	test	al,2

	je	eval_fill2

	mov	[rcx],rax 
	mov	rbp,8[rdx]
	mov	8[rcx],rbp 
	mov	rbp,16[rdx]
	mov	16[rcx],rbp 
	ret

eval_fill2:
 if THREAD
	lea	rbp,__cycle__in__spine
	mov	qword ptr [rcx],rbp
 else
	lea	r9,__cycle__in__spine
	mov	qword ptr [rcx],r9
 endif
	mov	qword ptr [rsi],rcx 

	test	byte ptr flags,64
	je	__cycle__in__spine	

	add	rsi,8
	mov	rcx,rdx 
	call	rax 
	mov	rdx,rcx
	mov	rcx,qword ptr (-8)[rsi]
	sub	rsi,8
	
	mov	rbp,[rdx]
	mov	[rcx],rbp
	mov	rbp,8[rdx]
	mov	8[rcx],rbp
	mov	rbp,16[rdx]
	mov	16[rcx],rbp 
	ret

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_0:
	mov	qword ptr [rdx],offset e__system__nind
	mov	8[rdx],rcx 
	jmp	rbp

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_1:
	mov	qword ptr [rdx],offset e__system__nind
	mov	rax,8[rdx]
	mov	8[rdx],rcx 
	mov	rdx,rax 
	jmp	rbp

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_2:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	8[rdx],rcx
	mov	rdx,16[rdx]
	jmp	rbp 

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_3:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	8[rdx],rcx
	mov	[rsi],rcx
	mov	rcx,24[rdx]
	add	rsi,8
	mov	rdx,16[rdx]
	jmp	rbp

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_4:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	8[rdx],rcx 
	mov	[rsi],rcx 
	mov	rbx,32[rdx]
	mov	8[rsi],rbx 
	mov	rcx,24[rdx]
	add	rsi,16
	mov	rdx,16[rdx]
	jmp	rbp

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_5:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	[rsi],rcx 
	mov	8[rdx],rcx 
	mov	rbx,40[rdx]
	mov	8[rsi],rbx 
	mov	rbx,32[rdx]
	mov	16[rsi],rbx 
	mov	rcx,24[rdx]
	add	rsi,24
	mov	rdx,16[rdx]
	jmp	rbp

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_6:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	[rsi],rcx 
	mov	8[rdx],rcx 
	mov	rbx,48[rdx]
	mov	8[rsi],rbx
	mov	rbx,40[rdx]
	mov	16[rsi],rbx 
	mov	rbx,32[rdx]
	mov	24[rsi],rbx 
	mov	rcx,24[rdx]
	add	rsi,32
	mov	rdx,16[rdx]
	jmp	rbp 

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_7:
	mov	rax,0
	mov	rbx,40
eval_upd_n:
	mov	qword ptr [rdx],offset e__system__nind
	mov	r8,8[rdx]
	mov	[rsi],rcx 
	mov	8[rdx],rcx 
	add	rdx,rbx 
	mov	rbx,16[rdx ]
	mov	8[rsi],rbx 
	mov	rbx,8[rdx]
	mov	16[rsi],rbx 
	mov	rbx,[rdx]
	mov	24[rsi],rbx 
	add	rsi,32

eval_upd_n_lp:
	mov	rbx,(-8)[rdx]
	sub	rdx,8
	mov	[rsi],rbx 
	add	rsi,8
	sub	rax,1
	jnc	eval_upd_n_lp

	mov	rcx,(-8)[rdx]
	mov	rdx,(-16)[rdx ]
	jmp	rbp 

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_8:
	mov	rax,1
	mov	rbx,48
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_9:
	mov	rax,2
	mov	rbx,56
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_10:
	mov	rax,3
	mov	rbx,64
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_11:
	mov	rax,4
	mov	rbx,72
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_12:
	mov	rax,5
	mov	rbx,80
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_13:
	mov	rax,6
	mov	rbx,88
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_14:
	mov	rax,7
	mov	rbx,96
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_15:
	mov	rax,8
	mov	rbx,104
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_16:
	mov	rax,9
	mov	rbx,112
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_17:
	mov	rax,10
	mov	rbx,120
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_18:
	mov	rax,11
	mov	rbx,128
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_19:
	mov	rax,12
	mov	rbx,136
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_20:
	mov	rax,13
	mov	rbx,144
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_21:
	mov	rax,14
	mov	rbx,152
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_22:
	mov	rax,15
	mov	rbx,160
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_23:
	mov	rax,16
	mov	rbx,168
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_24:
	mov	rax,17
	mov	rbx,176
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_25:
	mov	rax,18
	mov	rbx,184
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_26:
	mov	rax,19
	mov	rbx,192
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_27:
	mov	rax,20
	mov	rbx,200
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_28:
	mov	rax,21
	mov	rbx,208
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_29:
	mov	rax,22
	mov	rbx,216
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_30:
	mov	rax,23
	mov	rbx,224
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_31:
	mov	rax,24
	mov	rbx,232
	jmp	eval_upd_n

 ifdef PROFILE
	call	profile_n
	mov	rbp,rax
 endif
eval_upd_32:
	mov	rax,25
	mov	rbx,240
	jmp	eval_upd_n

;
;	STRINGS
;

catAC:
	mov	rax,8[rcx]
	mov	rbx,8[rdx]
	lea	rbp,16+7[rax+rbx]
	shr	rbp,3
	sub	r15,rbp
	jl	gc_3
gc_r_3:
	add	rcx,16
	add	rdx,16

; fill_node

	mov	r8,rdi
	mov	qword ptr [rdi],offset __STRING__+2

; store length

	lea	rbp,[rax+rbx]
	mov	8[rdi],rbp 
	add	rdi,16

; copy string 1

	lea	rbp,7[rbx]
	shr	rbp,3
	add	rbx,rdi 

	xchg	rcx,rbp 
	xchg	rsi,rdx 
	cld
	rep movsq
	mov	rsi,rdx 
	mov	rcx,rbp 

	mov	rdi,rbx 

; copy_string 2

cat_string_6:
	mov	rbp,rax 
	shr	rbp,3
	je	cat_string_9

cat_string_7:
	mov	rbx,[rcx]
	add	rcx,8
	mov	[rdi],rbx 
	add	rdi,8
	dec	rbp 
	jne	cat_string_7
	
cat_string_9:
	test	al,4
	je	cat_string_10
	mov	ebx,dword ptr [rcx]
	add	rcx,4
	mov	dword ptr [rdi],ebx 
	add	rdi,4
cat_string_10:
	test	al,2
	je	cat_string_11
	mov	bx,word ptr [rcx]
	add	rcx,2
	mov	word ptr [rdi],bx 
	add	rdi,2
cat_string_11:
	test	al,1
	je	cat_string_12
	mov	bl,byte ptr [rcx]
	mov	byte ptr [rdi],bl 
	inc	rdi
cat_string_12:

	mov	rcx,r8
; align heap pointer
	add	rdi,7
	and	rdi,-8
	ret

gc_3:	call	collect_2
	jmp	gc_r_3

empty_string:
	mov	rcx,offset zero_length_string
	ret

sliceAC:
	mov	rbp,8[rcx]
	test	rbx,rbx 
	jns	slice_string_1
	xor	rbx,rbx 
slice_string_1:
	cmp	rbx,rbp 
	jge	empty_string
	cmp	rax,rbx 
	jl	empty_string
	inc	rax 
	cmp	rax,rbp 
	jle	slice_string_2
	mov	rax,rbp 
slice_string_2:
	sub	rax,rbx 

	lea	rbp,(16+7)[rax]
	shr	rbp,3

	sub	r15,rbp
	jl	gc_4
r_gc_4:
	sub	rbp,2
	lea	rdx,16[rcx+rbx]

	mov	qword ptr [rdi],offset __STRING__+2
	mov	8[rdi],rax 

; copy part of string
	mov	rcx,rbp 
	mov	rbp,rdi
	add	rdi,16

	xchg	rsi,rdx 
	cld
	rep movsq
	mov	rsi,rdx 
	mov	rcx,rbp 
	ret

gc_4:
	mov	rbp,rdx 
	call	collect_1
	lea	rbp,(16+7)[rax]
	shr	rbp,3
	jmp	r_gc_4

updateAC:
	mov	rbp,8[rcx]
	cmp	rbx,rbp 
	jae	update_string_error

	add	rbp,16+7
	shr	rbp,3

	sub	r15,rbp
	jl	gc_5
r_gc_5:
	mov	rbp,8[rcx]
	add	rbp,7
	shr	rbp,3

	mov	rdx,rcx 
	mov	r8,rdi 
	mov	qword ptr [rdi],offset __STRING__+2
	mov	rcx,8[rdx]
	add	rdx,16
	mov	8[rdi],rcx 
	add	rdi,16

	add	rbx,rdi

	mov	rcx,rbp 
	xchg	rsi,rdx 
	cld
	rep movsq
	mov	rsi,rdx 

	mov	byte ptr [rbx],al 
	mov	rcx,r8 
	ret

gc_5:	call	collect_1
	jmp	r_gc_5

update_string_error:
	mov	rbp,offset high_index_string
	test	rax,rax 
	jns	update_string_error_2
	mov	rbp,offset low_index_string
update_string_error_2:
	jmp	print_error

eqAC:
	mov	rax,8[rcx]
	cmp	rax,8[rdx]
	jne	equal_string_ne
	add	rcx,16
	add	rdx,16
	mov	rbx,rax 
	and	rbx,7
	shr	rax,3
	je	equal_string_d
equal_string_1:
	mov	rbp,[rcx]
	cmp	rbp,[rdx]
	jne	equal_string_ne
	add	rcx,8
	add	rdx,8
	dec	rax
	jne	equal_string_1
equal_string_d:
	test	bl,4
	je	equal_string_w
	mov	eax,dword ptr [rcx]
	cmp	eax,dword ptr [rdx]
	jne	equal_string_ne
	add	rcx,4
	add	rdx,4
equal_string_w:
	test	bl,2
	je	equal_string_b
	mov	ax,word ptr [rcx]
	cmp	ax,word ptr [rdx]
	jne	equal_string_ne
	add	rcx,2
	add	rdx,2
equal_string_b:
	test	bl,1
	je	equal_string_eq
	mov	bl,byte ptr [rcx]
	cmp	bl,byte ptr [rdx]
	jne	equal_string_ne
equal_string_eq:
	mov	rax,1
	ret
equal_string_ne:
	xor	rax,rax 
	ret

cmpAC:
	mov	rbx,8[rcx]
	mov	rbp,8[rdx]
	add	rcx,16
	add	rdx,16
	cmp	rbp,rbx 
	jb	cmp_string_less
	ja	cmp_string_more
	xor	rax,rax 
	jmp	cmp_string_chars
cmp_string_more:
	mov	rax,1
	jmp	cmp_string_chars
cmp_string_less:
	mov	rax,-1
	mov	rbx,rbp 
	jmp	cmp_string_chars

cmp_string_1:
	mov	rbp,[rdx]
	cmp	rbp,[rcx]
	jne	cmp_string_ne_q
	add	rdx,8
	add	rcx,8
cmp_string_chars:
	sub	rbx,8
	jnc	cmp_string_1
cmp_string_d:
	test	bl,4
	je	cmp_string_w
	mov	ebp,dword ptr [rdx]
	cmp	ebp,dword ptr [rcx]
	jne	cmp_string_ne_d
	add	rdx,4
	add	rcx,4
cmp_string_w:
	test	bl,2
	je	cmp_string_b
	mov	bpl,byte ptr [rdx]
	cmp	bpl,byte ptr [rcx]
	jne	cmp_string_ne
	mov	bpl,byte ptr 1[rdx]
	cmp	bpl,byte ptr 1[rcx]
	jne	cmp_string_ne
	add	rdx,2
	add	rcx,2
cmp_string_b:
	test	bl,1
	je	cmp_string_eq
	mov	bl,byte ptr [rdx]
	cmp	bl,byte ptr [rcx]
	jne	cmp_string_ne
cmp_string_eq:
	ret
cmp_string_ne_d:
	mov	r10d,[rcx]
	bswap	ebp
	bswap	r10d
	cmp	ebp,r10d
	jmp	cmp_string_ne
cmp_string_ne_q:
	mov	r10,[rcx]
	bswap	rbp
	bswap	r10
	cmp	rbp,r10
cmp_string_ne:
	ja	cmp_string_r1
	mov	rax,-1
	ret
cmp_string_r1:
	mov	rax,1
	ret

string_to_string_node:
	mov	rax,qword ptr [rcx]
	add	rcx,8

	lea	rbx,16+7[rax]
	shr	rbx,3

	sub	r15,rbx
	jl	string_to_string_node_gc

string_to_string_node_r:
	sub	rbx,2
	mov	qword ptr [rdi],offset __STRING__+2
	mov	qword ptr 8[rdi],rax 
	mov	rbp,rdi
	add	rdi,16
	jmp	string_to_string_node_4
	
string_to_string_node_2:
	mov	rax,qword ptr [rcx]
	add	rcx,8
	mov	qword ptr [rdi],rax 
	add	rdi,8
string_to_string_node_4:
	sub	rbx,1
	jge	string_to_string_node_2

	mov	rcx,rbp 
	ret

string_to_string_node_gc:
	push	rcx
	call	collect_0
	pop	rcx
	jmp	string_to_string_node_r


int_array_to_node:
	mov	rax,qword ptr -16[rcx]
	lea	rbx,3[rax]
	sub	r15,rbx
	jl	int_array_to_node_gc

int_array_to_node_r:
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	rdx,rcx
	mov	qword ptr 8[rdi],rax
	mov	rcx,rdi
	mov	qword ptr 16[rdi],offset dINT+2
	add	rdi,24
	jmp	int_or_real_array_to_node_4

int_or_real_array_to_node_2:
	mov	rbx,qword ptr [rdx]
	add	rdx,8
	mov	qword ptr [rdi],rbx
	add	rdi,8
int_or_real_array_to_node_4:
	sub	rax,1
	jge	int_or_real_array_to_node_2

	ret

int_array_to_node_gc:
	push	rcx
	call	collect_0
	pop	rcx
	jmp	int_array_to_node_r


real_array_to_node:
	mov	rax,qword ptr -16[rcx]
	lea	rbx,3[rax]
	sub	r15,rbx
	jl	real_array_to_node_gc

real_array_to_node_r:
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	rdx,rcx
	mov	qword ptr 8[rdi],rax
	mov	rcx,rdi
	mov	qword ptr 16[rdi],offset REAL+2
	add	rdi,24
	jmp	int_or_real_array_to_node_4

real_array_to_node_gc:
	push	rcx
	call	collect_0
	pop	rcx
	jmp	real_array_to_node_r


	align	(1 shl 2)
	dd	3
_c3:	jmp	__cycle__in__spine
	align	(1 shl 2)

	dd	4
_c4:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	5
_c5:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	6
_c6:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	7
_c7:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	8
_c8:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	9
_c9:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	10
_c10:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	11
_c11:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	12
_c12:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	13
_c13:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	14
_c14:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	15
_c15:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	16
_c16:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	17
_c17:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	18
_c18:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	19
_c19:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	20
_c20:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	21
_c21:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	22
_c22:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	23
_c23:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	24
_c24:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	25
_c25:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	26
_c26:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	27
_c27:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	28
_c28:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	29
_c29:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	30
_c30:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	31
_c31:	jmp	__cycle__in__spine
	align	(1 shl 2)
	dd	32
_c32:	jmp	__cycle__in__spine

;
;	ARRAYS
;

_create_arrayB:
	mov	rbx,rax 
	add	rax,24+7
	shr	rax,3
	sub	r15,rax
	jge	no_collect_4574
	call	collect_0
no_collect_4574:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rbx 
	mov	qword ptr 16[rdi],offset BOOL+2
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayC:
	mov	rbx,rax
	add	rax,16+7
	shr	rax,3
	sub	r15,rax
	jge	no_collect_4573
	call	collect_0
no_collect_4573:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __STRING__+2
	mov	qword ptr 8[rdi],rbx 
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayI:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4572
	call	collect_0
no_collect_4572:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax
	lea	rbp,dINT+2
	mov	qword ptr 16[rdi],rbp
	lea	rdi,24[rdi+rax*8]
	ret

_create_arrayI32:
	mov	rbx,rax
	add	rax,6+1
	shr	rax,1
	sub	r15,rax
	jge	no_collect_3572
	call	collect_0
no_collect_3572:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rbx
	mov	qword ptr 16[rdi],offset INT32+2
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayR:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4580
	call	collect_0
no_collect_4580:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax
	mov	qword ptr 16[rdi],offset REAL+2
	lea	rdi,24[rdi+rax*8]
	ret

_create_arrayR32:
	mov	rbx,rax
	add	rax,6+1
	shr	rax,1
	sub	r15,rax
	jge	no_collect_3580
	call	collect_0
no_collect_3580:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax
	mov	qword ptr 16[rdi],offset REAL32+2
	lea	rdi,[rdi+rax*8]
	ret

; rax : number of elements, rbx: element descriptor
; r10 : element size, r11 : element a size, rcx :a_element-> rcx : array

_create_r_array:
	mov	rbp,rax
	imul	rbp,r10
	add	rbp,3
	sub	r15,rbp
	jge	no_collect_4586
	call	collect_1
no_collect_4586:
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	rdx,rcx
	mov	qword ptr 8[rdi],rax
	mov	rcx,rdi 
	mov	qword ptr 16[rdi],rbx
	add	rdi,24

	test	r11,r11
	je	_create_r_array_0
	sub	r11,2
	jc	_create_r_array_1
	je	_create_r_array_2
	sub	r11,2
	jc	_create_r_array_3
	je	_create_r_array_4
	jmp	_create_r_array_5

_create_r_array_0:
	imul	r10,rax
	lea	rdi,[rdi+r10*8]
	ret

_create_r_array_1:
	shl	r10,3
	jmp	_st_fillr1_array
_fillr1_array:
	mov	qword ptr [rdi],rdx
	add	rdi,r10 
_st_fillr1_array:
	sub	rax,1
	jnc	_fillr1_array
	ret

_create_r_array_2:
	shl	r10,3
	jmp	_st_fillr2_array
_fillr2_array:
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rdx
	add	rdi,r10 
_st_fillr2_array:
	sub	rax,1
	jnc	_fillr2_array
	ret

_create_r_array_3:
	shl	r10,3
	jmp	_st_fillr3_array
_fillr3_array:
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rdx
	mov	qword ptr 16[rdi],rdx
	add	rdi,r10 
_st_fillr3_array:
	sub	rax,1
	jnc	_fillr3_array
	ret

_create_r_array_4:
	shl	r10,3
	jmp	_st_fillr4_array
_fillr4_array:
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rdx
	mov	qword ptr 16[rdi],rdx
	mov	qword ptr 24[rdi],rdx
	add	rdi,r10 
_st_fillr4_array:
	sub	rax,1
	jnc	_fillr4_array
	ret

_create_r_array_5:
	sub	r10,4
	sub	r10,r11
	sub	r11,1
	shl	r10,3
	jmp	_st_fillr5_array

_fillr5_array:
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rdx
	mov	qword ptr 16[rdi],rdx
	mov	qword ptr 24[rdi],rdx
	add	rdi,32

	mov	rbx,r11
_copy_elem_5_lp:
	mov	qword ptr [rdi],rdx
	add	rdi,8
	sub	rbx,1
	jnc	_copy_elem_5_lp

	add	rdi,r10 
_st_fillr5_array:
	sub	rax,1
	jnc	_fillr5_array
	
	ret

create_arrayB:
	mov	r10,rbx
	add	rbx,24+7
	shr	rbx,3
	sub	r15,rbx
	jge	no_collect_4575
	call	collect_0
no_collect_4575:
	mov	rbp,rax
	sub	rbx,3
	shl	rbp,8
	or	rax,rbp
	mov	rbp,rax
	shl	rbp,16
	or	rax,rbp
	mov	rbp,rax 
	shl	rbp,32
	or	rax,rbp
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],r10
	mov	qword ptr 16[rdi],offset BOOL+2
	add	rdi,24
	jmp	create_arrayBCI

create_arrayC:
	mov	r10,rbx
	add	rbx,16+7
	shr	rbx,3
	sub	r15,rbx
	jge	no_collect_4578
	call	collect_0
no_collect_4578:
	mov	rbp,rax
	sub	rbx,2
	shl	rbp,8
	or	rax,rbp
	mov	rbp,rax
	shl	rbp,16
	or	rax,rbp
	mov	rbp,rax
	shl	rbp,32
	or	rax,rbp
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __STRING__+2
	mov	qword ptr 8[rdi],r10
	add	rdi,16
	jmp	create_arrayBCI

create_arrayI32:
	mov	r10,rbx
	add	rbx,6+1
	shr	rbx,1
	sub	r15,rbx
	jge	no_collect_3577
	call	collect_0
no_collect_3577:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],r10
	mov	qword ptr 16[rdi],offset INT32+2
	add	rdi,24

	sub	rbx,3

	mov	ebp,eax
	shl	rax,32
	or	rax,rbp
	jmp	create_arrayBCI

create_arrayI:
	lea	rbp,3[rbx]
	sub	r15,rbp
	jge	no_collect_4577
	call	collect_0
no_collect_4577:
	mov	rcx,rdi 
	lea	rbp,__ARRAY__+2
	mov	qword ptr [rdi],rbp
	mov	qword ptr 8[rdi],rbx 
	lea	rbp,dINT+2
	mov	qword ptr 16[rdi],rbp
	add	rdi,24
create_arrayBCI:
	mov	rdx,rbx
	shr	rbx,1
	test	dl,1
	je	st_filli_array

	mov	qword ptr [rdi],rax 
	add	rdi,8
	jmp	st_filli_array

filli_array:
	mov	qword ptr [rdi],rax 
	mov	qword ptr 8[rdi],rax 
	add	rdi,16
st_filli_array:
	sub	rbx,1
	jnc	filli_array

	ret

create_arrayR32:
	cvtsd2ss	xmm0,xmm0
	movss	dword ptr (-8)[rsp],xmm0
	mov	r10,rax
	add	rax,6+1
	shr	rax,1
	mov	ebx,dword ptr (-8)[rsp]
	sub	r15,rax
	jge	no_collect_3579
	call	collect_0
no_collect_3579:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],r10
	mov	qword ptr 16[rdi],offset REAL32+2
	add	rdi,24

	sub	rax,3

	mov	edx,ebx
	shl	rbx,32
	or	rbx,rdx
	jmp	st_fillr_array

create_arrayR:
	movsd	qword ptr (-8)[rsp],xmm0
	lea	rbp,3[rax]

	mov	rbx,qword ptr (-8)[rsp]

	sub	r15,rbp
	jge	no_collect_4579
	call	collect_0
no_collect_4579:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax
	mov	qword ptr 16[rdi],offset REAL+2
	add	rdi,24
	jmp	st_fillr_array
fillr_array:
	mov	qword ptr [rdi],rbx 
	add	rdi,8
st_fillr_array:
	sub	rax,1
	jnc	fillr_array

	ret

create_array:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4576
	call	collect_1
no_collect_4576:
	mov	rbx,rcx 
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],0
	add	rdi,24

	jmp	fillr1_array




; in rax: number of elements, rbx: element descriptor
; r10 : element size, r11 : element a size -> rcx : array

create_R_array:
	sub	r10,2
	jc	create_R_array_1
	je	create_R_array_2
	sub	r10,2
	jc	create_R_array_3
	je	create_R_array_4
	jmp	create_R_array_5

create_R_array_1:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4581
	call	collect_0
no_collect_4581:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],rbx 
	add	rdi,24

	test	r11,r11
	je	r_array_1_b

	mov	rbx,qword ptr (-8)[rsi]
	jmp	fillr1_array

r_array_1_b:
	mov	rbx,qword ptr 8[rsp]

fillr1_array:
	mov	rdx,rax 
	shr	rax,1
	test	dl,1
	je	st_fillr1_array_1

	mov	qword ptr [rdi],rbx
	add	rdi,8
	jmp	st_fillr1_array_1

fillr1_array_lp:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],rbx 
	add	rdi,16
st_fillr1_array_1:
	sub	rax,1
	jnc	fillr1_array_lp

	ret

create_R_array_2:
	lea	rbp,3[rax*2]
	sub	r15,rbp
	jge	no_collect_4582
	call	collect_0
no_collect_4582:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],rbx 
	add	rdi,24

	sub	r11,1
	jc	r_array_2_bb
	je	r_array_2_ab
r_array_2_aa:
	mov	rbx,qword ptr (-8)[rsi]
	mov	rbp,qword ptr (-16)[rsi]
	jmp	st_fillr2_array
r_array_2_ab:
	mov	rbx,qword ptr (-8)[rsi]
	mov	rbp,qword ptr 8[rsp]
	jmp	st_fillr2_array
r_array_2_bb:
	mov	rbx,qword ptr 8[rsp]
	mov	rbp,qword ptr 16[rsp]
	jmp	st_fillr2_array

fillr2_array_1:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],rbp 
	add	rdi,16
st_fillr2_array:
	sub	rax,1
	jnc	fillr2_array_1

	ret

create_R_array_3:
	lea	rbp,3[rax+rax*2]
	sub	r15,rbp
	jge	no_collect_4583
	call	collect_0
no_collect_4583:
	mov	rcx,rdi
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],rbx 
	add	rdi,24

	pop	rdx 
	mov	r12,rsp 

	test	r11,r11 
	je	r_array_3
	
	lea	r13,0[r11*8]
	mov	rbp,rsi
	sub	rbp,r13

	sub	r11,1

copy_a_to_b_lp3:
	push	[rbp]
	add	rbp,8
	sub	r11,1
	jnc	copy_a_to_b_lp3

r_array_3:
	mov	rbx,qword ptr [rsp]
	mov	r13,qword ptr 8[rsp]
	mov	rbp,qword ptr 16[rsp]
	
	mov	rsp,r12
	push	rdx

	jmp	st_fillr3_array

fillr3_array_1:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],r13
	mov	qword ptr 16[rdi],rbp 
	add	rdi,24
st_fillr3_array:
	sub	rax,1
	jnc	fillr3_array_1

	ret

create_R_array_4:
	lea	rbp,3[rax*4]
	sub	r15,rbp
	jge	no_collect_4584
	call	collect_0
no_collect_4584:
	mov	rcx,rdi 
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],rbx 
	add	rdi,24

	pop	rdx 
	mov	r12,rsp 

	test	r11,r11 
	je	r_array_4

	lea	r13,0[r11*8]
	mov	rbp,rsi
	sub	rbp,r13
	sub	r11,1

copy_a_to_b_lp4:
	push	[rbp]
	add	rbp,8
	sub	r11,1
	jnc	copy_a_to_b_lp4

r_array_4:
	mov	rbx,qword ptr [rsp]
	mov	r13,qword ptr 8[rsp]
	mov	r14,qword ptr 16[rsp]
	mov	rbp,qword ptr 24[rsp]

	mov	rsp,r12
	push	rdx
	
	jmp	st_fillr4_array

fillr4_array:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],r13 
	mov	qword ptr 16[rdi],r14 
	mov	qword ptr 24[rdi],rbp 
	add	rdi,32
st_fillr4_array:
	sub	rax,1
	jnc	fillr4_array

	ret

create_R_array_5:
	lea	r12,4[r10]
	mov	rbp,rax
	imul	rbp,r12
	add	rbp,3
	sub	r15,rbp
	jge	no_collect_4585
	call	collect_0
no_collect_4585:
	mov	qword ptr [rdi],offset __ARRAY__+2
	mov	qword ptr 8[rdi],rax
	mov	qword ptr 16[rdi],rbx
	mov	rcx,rdi
	add	rdi,24

	pop	rdx
	mov	r12,rsp
	
	test	r11,r11 
	je	r_array_5

	lea	r13,0[r11*8]
	mov	rbp,rsi
	sub	rbp,r13
	sub	r11,1

copy_a_to_b_lp5:
	push	[rbp]
	add	rbp,8
	sub	r11,1
	jnc	copy_a_to_b_lp5

r_array_5:
	mov	r13,qword ptr [rsp]
	mov	r14,qword ptr 8[rsp]
 if THREAD
	lea	rbx,32[rsp+r10*8]
 endif
	mov	r8,qword ptr 16[rsp]
 if THREAD
	mov	r10,qword ptr 24[rsp]
 else
	mov	r9,qword ptr 24[rsp]
 endif
	add	rsp,32

 ife THREAD
	sub	r10,1
 endif
	jmp	st_fillr5_array

fillr5_array_1:
	mov	qword ptr [rdi],r13 
	mov	qword ptr 8[rdi],r14

	mov	r11,rsp
 ife THREAD
	mov	rbx,r10 
 endif

	mov	qword ptr 16[rdi],r8
 if THREAD
	mov	qword ptr 24[rdi],r10
 else
	mov	qword ptr 24[rdi],r9
 endif
	add	rdi,32

copy_elem_lp5:
	mov	rbp,qword ptr [r11]
	add	r11,8
	mov	qword ptr [rdi],rbp 
	add	rdi,8
 if THREAD
	cmp	r11,rbx
	jne	copy_elem_lp5
 else
	sub	rbx,1
	jnc	copy_elem_lp5
 endif

st_fillr5_array:
	sub	rax,1
	jnc	fillr5_array_1

	mov	rsp,r12
	jmp	rdx

 ifndef NEW_DESCRIPTORS
yet_args_needed:
; for more than 4 arguments
	mov	r10,[rdx]
	movzx	rax,word ptr (-2)[r10]
	add	rax,3
	sub	r15,rax
	jl	gc_1
gc_r_1:	sub	rax,3+1+4
	mov	rbx,8[rdx]
	add	r10,8
	mov	rdx,16[rdx]
	mov	rbp,rdi
	mov	r8,[rdx]
	mov	[rdi],r8 
	mov	r8,8[rdx]
	mov	8[rdi],r8 
	mov	r8,16[rdx]
	mov	16[rdi],r8 
	add	rdx,24
	add	rdi,24

cp_a:	mov	r8,[rdx]
	add	rdx,8
	mov	[rdi],r8 
	add	rdi,8
	sub	rax,1
	jge	cp_a

	mov	[rdi],rcx 
	mov	8[rdi],r10 
	lea	rcx,8[rdi]
	mov	16[rdi],rbx 
	mov	24[rdi],rbp 
	add	rdi,32
	ret

gc_1:
	call	collect_2
	jmp	gc_r_1

yet_args_needed_0:
	sub	r15,2
	jl	gc_20
gc_r_20:
	mov	8[rdi],rcx 
	mov	rax,[rdx]
	mov	rcx,rdi
	add	rax,8
	mov	[rdi],rax 
	add	rdi,16
	ret

gc_20:
	call	collect_2
	jmp	gc_r_20

yet_args_needed_1:
	sub	r15,3
	jl	gc_21
gc_r_21:
	mov	16[rdi],rcx 
	mov	rax,[rdx]
	mov	rcx,rdi
	add	rax,8
	mov	[rdi],rax 
	mov	rbx,8[rdx]
	mov	8[rdi],rbx 
	add	rdi,24
	ret

gc_21:
	call	collect_2
	jmp	gc_r_21

yet_args_needed_2:
	sub	r15,5
	jl	gc_22
gc_r_22:
	mov	rax,[rdx]
	mov	8[rdi],rcx 
	add	rax,8
	mov	rbp,8[rdx]
	mov	16[rdi],rax 
	lea	rcx,16[rdi]
	mov	24[rdi],rbp 
	mov	rbp,16[rdx]
	mov	[rdi],rbp 
	mov	32[rdi],rdi 
	add	rdi,40
	ret

gc_22:
	call	collect_2
	jmp	gc_r_22

yet_args_needed_3:
	sub	r15,6
	jl	gc_23
gc_r_23:
	mov	rax,[rdx]
	mov	16[rdi],rcx 
	add	rax,8
	mov	rbp,8[rdx]
	mov	24[rdi],rax 
	mov	rdx,16[rdx]
	mov	32[rdi],rbp 
	mov	rbp,[rdx]
	mov	40[rdi],rdi 
	mov	[rdi],rbp 
	mov	rbp,8[rdx]
	lea	rcx,24[rdi]
	mov	8[rdi],rbp 
	add	rdi,48
	ret

gc_23:
	call	collect_2
	jmp	gc_r_23

yet_args_needed_4:
	sub	r15,7
	jl	gc_24
gc_r_24:
	mov	rax,[rdx]
	mov	24[rdi],rcx 
	add	rax,8
	mov	rbp,8[rdx]
	mov	32[rdi],rax 
	mov	rdx,16[rdx]
	mov	40[rdi],rbp 
	mov	rbp,[rdx]
	mov	48[rdi],rdi 
	mov	[rdi],rbp 
	mov	rbp,8[rdx]
	lea	rcx,32[rdi]
	mov	8[rdi],rbp 
	mov	rbp,16[rdx ]
	mov	16[rdi],rbp 
	add	rdi,56
	ret

gc_24:
	call	collect_2
	jmp	gc_r_24
 endif

repl_args_b:
	test	rax,rax 
	jle	repl_args_b_1

	dec	rax 
	je	repl_args_b_4

	mov	rdx,16[rcx]
	sub	rbx,2
	jne	repl_args_b_2

	mov	[rsi],rdx 
	add	rsi,8
	jmp	repl_args_b_4

repl_args_b_2:
	lea	rdx,[rdx+rax*8]

repl_args_b_3:
	mov	rbp,(-8)[rdx]
	sub	rdx,8
	mov	[rsi],rbp 
	add	rsi,8
	dec	rax 
	jne	repl_args_b_3

repl_args_b_4:
	mov	rbp,8[rcx]
	mov	[rsi],rbp 
	add	rsi,8
repl_args_b_1:
	ret

push_arg_b:
	cmp	rbx,2
	jb	push_arg_b_1
	jne	push_arg_b_2
	cmp	rbx,rax 
	je	push_arg_b_1
push_arg_b_2:
	mov	rcx,16[rcx]
	sub	rbx,2
push_arg_b_1:
	mov	rcx,[rcx+rbx*8]
	ret

del_args:
	mov	rbx,[rcx]
	sub	rbx,rax 
	movsx	rax,word ptr (-2)[rbx]
	sub	rax,2
	jge	del_args_2

	mov	[rdx],rbx 
	mov	rbp,8[rcx]
	mov	8[rdx],rbp 
	mov	rbp,16[rcx]
	mov	16[rdx],rbp 
	ret

del_args_2:
	jne	del_args_3

	mov	[rdx],rbx 
	mov	rbp,8[rcx]
	mov	8[rdx],rbp 
	mov	rbp,16[rcx]
	mov	rbp,[rbp]
	mov	16[rdx],rbp 
	ret

del_args_3:
	sub	r15,rax
	jl	del_args_gc
del_args_r_gc:
	mov	[rdx],rbx 
	mov	16[rdx],rdi 
	mov	rbp,8[rcx]
	mov	rcx,16[rcx]
	mov	8[rdx],rbp 

del_args_copy_args:
	mov	rbp,[rcx]
	add	rcx,8
	mov	[rdi],rbp 
	add	rdi,8
	sub	rax,1
	jg	del_args_copy_args

	ret

del_args_gc:
	call	collect_2
	jmp	del_args_r_gc

 ifdef USE_LIBM
cos_real:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	call	cos
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	ret

sin_real:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	call	sin
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	ret

tan_real:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	call	tan
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	ret

atan_real:
	mov	rbp,rsp
	and	rsp,-16
	mov	r13,rsi
	mov	r14,rdi
	call	atan
	mov	rsp,rbp
	mov	rsi,r13
	mov	rdi,r14
	ret

asin_real:
acos_real:
ln_real:
log10_real:
exp_real:
pow_real:
exp2_real_:
_c_log10:
_c_pow:
_c_entier:
	int 3
	ret
 endif
	
entier_real:
	cvttsd2si rax,xmm0
	ucomisd	xmm0,qword ptr real_0_0
	jb	entier_real_m
	ret

entier_real_m:
	movsd	qword ptr (-8)[rsp],xmm0
	mov	rcx,qword ptr (-8)[rsp]
	mov	rbx,rcx
	shr rcx,52
	cmp rcx,0bffh
	jb	entier_real_m_small
	cmp	rcx,0bffh+52
	jae	entier_real_m_large
	sub	rcx,0bffh-12
	shl	rbx,cl
	je	entier_m_exact
entier_real_m_small:
	sub	rax,1
entier_real_m_large:
entier_m_exact:
	ret

r_to_i_real:
	cvtsd2si rax,xmm0
	ret

	public	getheapend

getheapend:
	lea	rbx,[rdi+r15*8]
 if THREAD
	mov	rax,heap_end_after_gc_offset[r9]
 else
	mov	rax,heap_end_after_gc
 endif
	ret

_TEXT	ends

	include	..\areals.asm

 ifdef PROFILE
  ifdef TRACE
	include	..\atrace.asm
  else
	include	..\aprofile.asm
  endif
 endif

 ifdef NEW_DESCRIPTORS
	include	aap.asm
 endif

 ifdef THREAD
	include	athread.asm
 endif

	end

