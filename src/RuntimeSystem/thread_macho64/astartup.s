
	.set LINUX,1
	.set USE_LIBM,0
	.set NEW_DESCRIPTORS,1
	.set MEASURE_GC,0

	.macro att_jmp
	.att_syntax
	jmp	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_call
	.att_syntax
	call	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_je
	.att_syntax
	je	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jne
	.att_syntax
	jne	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_ja
	.att_syntax
	ja	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jae
	.att_syntax
	jae	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jb
	.att_syntax
	jb	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jbe
	.att_syntax
	jbe	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jc
	.att_syntax
	jc	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jnc
	.att_syntax
	jnc	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jg
	.att_syntax
	jg	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jge
	.att_syntax
	jge	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jl
	.att_syntax
	jl	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jle
	.att_syntax
	jle	$0
	.intel_syntax noprefix
	.endmacro

	.macro att_jz
	.att_syntax
	jz	$0
	.intel_syntax noprefix
	.endmacro

/*	File:	astartup.s */
/*	Author:	John van Groningen */
/*	Machine:	amd64 */

 .if LINUX
	.intel_syntax noprefix
 .endif

 .if ! LINUX
	.globl	convert_real_to_string
 .endif
 .if ! LINUX
	.globl	write_heap
 .endif
	.globl	_return_code
	.globl	_execution_aborted
	.globl	e____system__kFinalizerGCTemp
	.globl	e____system__kFinalizer

 .if LINUX
	.globl	_times
	.globl	_exit
	.globl	_pthread_key_create
 .else
	.globl	GetTickCount
	.globl	ExitProcess
 .endif

 .if USE_LIBM
	.globl	cos
	.globl	sin
	.globl	tan
	.globl	atan
 .endif

	.data
	.align	3

	.globl	_tlsp_tls_index
_tlsp_tls_index:	.quad	0

vector_p:	.quad	0
vector_counter:	.quad	0
	
last_time:	.quad	0
execute_time:	.quad	0
garbage_collect_time:	.quad	0
IO_time:	.quad	0

compact_garbage_collect_time:	.quad	0
mark_compact_garbage_collect_time:	.quad	0
total_gc_bytes:	.quad	0
total_compact_gc_bytes:	.quad	0

	.globl	int_to_real_scratch
int_to_real_scratch:	.quad	0

heap_end_write_heap:	.quad	0
d3_flag_write_heap:	.quad	0

	.globl	a_stack_guard_page
a_stack_guard_page:	.quad	0

	.globl	profile_stack_pointer
profile_stack_pointer:	.quad	0

dll_initisialised:	.quad	0
	.globl	end_b_stack
end_b_stack:	.quad	0
basic_only:	.quad	0

n_marked_words:
	.quad	0

caf_list:
	.quad	0
	.globl	caf_listp
caf_listp:
	.quad	0
	
zero_length_string:
	.quad	__STRING__+2
	.quad	0
true_string:
	.quad	__STRING__+2
	.quad	4
true_c_string:
	.ascii	"True"
	.byte	0,0,0,0
false_string:
	.quad	__STRING__+2
	.quad	5
false_c_string:
	.ascii	"False"
	.byte	0,0,0
file_c_string:
	.ascii	"File"
	.byte	0,0,0,0

	.comm	sprintf_buffer,32

tls_alloc_error_string:
	.ascii	"Could not allocate thread local variable"
	.byte	10,0
out_of_memory_string_1:
	.ascii	"Not enough memory to allocate heap and stack"
	.byte	10,0
printf_int_string:
	.ascii	"%d"
	.byte	0
printf_real_string:
	.ascii	"%.15g"
	.byte	0
printf_string_string:
	.ascii	"%s"
	.byte	0
printf_char_string:
	.ascii	"%c"
	.byte	0
garbage_collect_string_1:
	.ascii	"A stack: "
	.byte	0
garbage_collect_string_2:
	.ascii	" bytes. BC stack: "
	.byte	0
garbage_collect_string_3:
	.ascii	" bytes."
	.byte	10,0
heap_use_after_gc_string_1:
	.ascii	"Heap use after garbage collection: "
	.byte	0
heap_use_after_compact_gc_string_1:
	.ascii	"Heap use after compacting garbage collection: "
	.byte	0
heap_use_after_gc_string_2:
	.ascii	" Bytes."
	.byte	10,0
stack_overflow_string:
	.ascii	"Stack overflow."
	.byte	10,0
out_of_memory_string_4:
	.ascii	"Heap full."
	.byte	10,0
time_string_1:
	.ascii	"Execution: "
	.byte	0
time_string_2:
	.ascii	"  Garbage collection: "
	.byte	0

time_string_3:
	.ascii	" "
	.byte	0

time_string_4:
	.ascii	"  Total: "
	.byte	0
high_index_string:
	.ascii	"Index too high in UPDATE string."
	.byte	10,0
low_index_string:
	.ascii	"Index negative in UPDATE string."
	.byte	10,0
IO_error_string:
	.ascii	"IO error: "
	.byte	0
new_line_string:
	.byte	10,0
	
sprintf_time_string:
	.ascii	"%d.%02d"
	.byte	0

marked_gc_string_1:
	.ascii	"Marked: "
	.byte	0

 .if PROFILE
	.align	3
m_system:
	.long	6
	.ascii	"System"
	.byte	0
	.byte	0

	.long	m_system-.
garbage_collector_name:
	.quad	0
	.ascii	"garbage_collector"
	.byte	0
	.align	3
 .endif

	.align	4
	.globl	sign_real_mask
sign_real_mask:
	.quad	0x8000000000000000,0x8000000000000000
	.globl	abs_real_mask
abs_real_mask:
	.quad	0x7fffffffffffffff,0x7fffffffffffffff

	.align 3
NAN_real:
	.long	0x0ffffffff,0x7fffffff
one_real:
	.long	0x00000000,0x3ff00000
zero_real:
	.long	0x00000000,0x00000000

	.align 2 
bit_set_table:
	.long	0x00000001,0x00000002,0x00000004,0x00000008
	.long	0x00000010,0x00000020,0x00000040,0x00000080
	.long	0x00000100,0x00000200,0x00000400,0x00000800
	.long	0x00001000,0x00002000,0x00004000,0x00008000
	.long	0x00010000,0x00020000,0x00040000,0x00080000
	.long	0x00100000,0x00200000,0x00400000,0x00800000
	.long	0x01000000,0x02000000,0x04000000,0x08000000
	.long	0x10000000,0x20000000,0x40000000,0x80000000
	.long	0
bit_set_table2:
	.long	0x00000001,0,0x00000002,0,0x00000004,0,0x00000008,0
	.long	0x00000010,0,0x00000020,0,0x00000040,0,0x00000080,0
	.long	0x00000100,0,0x00000200,0,0x00000400,0,0x00000800,0
	.long	0x00001000,0,0x00002000,0,0x00004000,0,0x00008000,0
	.long	0x00010000,0,0x00020000,0,0x00040000,0,0x00080000,0
	.long	0x00100000,0,0x00200000,0,0x00400000,0,0x00800000,0
	.long	0x01000000,0,0x02000000,0,0x04000000,0,0x08000000,0
	.long	0x10000000,0,0x20000000,0,0x40000000,0,0x80000000,0
	.long	0,0
bit_clear_table:
	.long	0x0fffffffe,0x0fffffffd,0x0fffffffb,0x0fffffff7
	.long	0x0ffffffef,0x0ffffffdf,0x0ffffffbf,0x0ffffff7f
	.long	0x0fffffeff,0x0fffffdff,0x0fffffbff,0x0fffff7ff
	.long	0x0ffffefff,0x0ffffdfff,0x0ffffbfff,0x0ffff7fff
	.long	0x0fffeffff,0x0fffdffff,0x0fffbffff,0x0fff7ffff
	.long	0x0ffefffff,0x0ffdfffff,0x0ffbfffff,0x0ff7fffff
	.long	0x0feffffff,0x0fdffffff,0x0fbffffff,0x0f7ffffff
	.long	0x0efffffff,0x0dfffffff,0x0bfffffff,0x7fffffff
	.long	0x0ffffffff
bit_clear_table2:
	.long	0x0fffffffe,-1,0x0fffffffd,-1,0x0fffffffb,-1,0x0fffffff7,-1
	.long	0x0ffffffef,-1,0x0ffffffdf,-1,0x0ffffffbf,-1,0x0ffffff7f,-1
	.long	0x0fffffeff,-1,0x0fffffdff,-1,0x0fffffbff,-1,0x0fffff7ff,-1
	.long	0x0ffffefff,-1,0x0ffffdfff,-1,0x0ffffbfff,-1,0x0ffff7fff,-1
	.long	0x0fffeffff,-1,0x0fffdffff,-1,0x0fffbffff,-1,0x0fff7ffff,-1
	.long	0x0ffefffff,-1,0x0ffdfffff,-1,0x0ffbfffff,-1,0x0ff7fffff,-1
	.long	0x0feffffff,-1,0x0fdffffff,-1,0x0fbffffff,-1,0x0f7ffffff,-1
	.long	0x0efffffff,-1,0x0dfffffff,-1,0x0bfffffff,-1,0x7fffffff,-1
	.long	0x0ffffffff,-1
first_one_bit_table:
	.byte	-1,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	7,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	6,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	5,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0
	.byte	4,0,1,0,2,0,1,0,3,0,1,0,2,0,1,0

	.align	2 
	.comm	sprintf_time_buffer,20

	.align	3

/*	.globl	small_integers */
	.comm	small_integers,33*16
/*	.globl	static_characters */
	.comm	static_characters,256*16

/*	.globl	clean_exception_handler */
/*	.globl	clean_unwind_info */
/*clean_unwind_info: */
/*	DD	000000009H */
/*	DD	imagerel(clean_exception_handler) */




	.comm	main_thread_local_storage,768

heap_p1_offset			= 0
heap_p2_offset			= 8
heap_p3_offset			= 16

saved_heap_p_offset		= 24
saved_r15_offset		= 32
saved_a_stack_p_offset		= 40

heap_vector_offset		= 48

end_vector_offset		= 56 /* temp */
neg_heap_vector_plus_4_offset	= 64 /* temp */

heap_size_64_65_offset		= 72 /* temp */
heap_size_257_offset		= 80

heap_copied_vector_offset	= 88

heap_end_after_gc_offset	= 96

extra_heap_offset		= 104
extra_heap_size_offset		= 112

stack_top_offset		= 120 /* temp */
stack_p_offset			= 128

halt_sp_offset			= 136

n_allocated_words_offset	= 144 /* temp */

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

n_marked_words_offset		= 256 /* temp */
end_stack_offset		= 264 /* temp */
lazy_array_list_offset		= 272 /* temp */

heap_size_offset		= 280
heap_size_65_offset		= 288
a_stack_size_offset		= 296
garbage_collect_flag_offset	= 304
semi_space_size_offset		= 312 /* temp */
neg_heap_p3_offset		= 320 /* temp */
end_heap_p3_offset		= 328 /* temp */

rmarkp_n_queue_items_16_offset	= 352 /* temp */
rmarkp_queue_first_offset	= 360 /* temp */

n_queue_items_offset		= 368 /* temp */
queue_first_offset		= 376 /* temp */

queue_offset			= 384 /* temp */

rmarkp_queue_offset		= 512 /* temp */




	.text

	.globl	_abc_main
	.globl	print
	.globl	print_char
	.globl	print_int
	.globl	print_real
	.globl	print__string__
	.globl	print__chars__sc
	.globl	print_sc
	.globl	print_symbol
	.globl	print_symbol_sc
	.globl	printD
	.globl	DtoAC
	.globl	push_t_r_args
	.globl	push_a_r_args
	.globl	halt
	.globl	dump

	.globl	catAC
	.globl	sliceAC
	.globl	updateAC
	.globl	eqAC
	.globl	cmpAC

	.globl	string_to_string_node
	.globl	int_array_to_node
	.globl	real_array_to_node

	.globl	_create_arrayB
	.globl	_create_arrayC
	.globl	_create_arrayI
	.globl	_create_arrayI32
	.globl	_create_arrayR
	.globl	_create_arrayR32
	.globl	_create_r_array
	.globl	create_array
	.globl	create_arrayB
	.globl	create_arrayC
	.globl	create_arrayI
	.globl	create_arrayI32
	.globl	create_arrayR
	.globl	create_arrayR32
	.globl	create_R_array

	.globl	BtoAC
	.globl	ItoAC
	.globl	RtoAC
	.globl	eqD

	.globl	collect_0
	.globl	collect_1
	.globl	collect_2
	.globl	collect_3

	.globl	yet_args_needed
	.globl	yet_args_needed_0
	.globl	yet_args_needed_1
	.globl	yet_args_needed_2
	.globl	yet_args_needed_3
	.globl	yet_args_needed_4

	.globl	_c3,_c4,_c5,_c6,_c7,_c8,_c9,_c10,_c11,_c12
	.globl	_c13,_c14,_c15,_c16,_c17,_c18,_c19,_c20,_c21,_c22
	.globl	_c23,_c24,_c25,_c26,_c27,_c28,_c29,_c30,_c31,_c32

	.globl	e__system__nind
	.globl	e__system__eaind
/* old names of the previous two labels for compatibility, remove later */
	.globl	__indirection,__eaind
	.globl	e__system__dind
	.globl	eval_fill

	.globl	eval_upd_0,eval_upd_1,eval_upd_2,eval_upd_3,eval_upd_4
	.globl	eval_upd_5,eval_upd_6,eval_upd_7,eval_upd_8,eval_upd_9
	.globl	eval_upd_10,eval_upd_11,eval_upd_12,eval_upd_13,eval_upd_14
	.globl	eval_upd_15,eval_upd_16,eval_upd_17,eval_upd_18,eval_upd_19
	.globl	eval_upd_20,eval_upd_21,eval_upd_22,eval_upd_23,eval_upd_24
	.globl	eval_upd_25,eval_upd_26,eval_upd_27,eval_upd_28,eval_upd_29
	.globl	eval_upd_30,eval_upd_31,eval_upd_32

	.globl	repl_args_b
	.globl	push_arg_b
	.globl	del_args

	.globl	add_IO_time
	.globl	add_execute_time
	.globl	_IO_error
	.globl	stack_overflow

	.globl	out_of_memory_4
	.globl	print_error

 .if LINUX
	.globl	__start
 .else
	.globl	_start
 .endif

 .if PROFILE
/*	.globl	init_profiler */
/*	.globl	profile_n */
/*	.globl	profile_s */
/*	.globl	profile_r */
/*	.globl	write_profile_information */
/*	.globl	write_profile_stack */
 .endif

  .if USE_LIBM
	.globl	cos_real
	.globl	sin_real
	.globl	tan_real
	.globl	asin_real
	.globl	acos_real
	.globl	atan_real
	.globl	ln_real
	.globl	log10_real
	.globl	exp_real
	.globl	pow_real
 .endif
	.globl	entier_real
	.globl	r_to_i_real
  .if USE_LIBM
	.globl	_c_pow
	.globl	_c_log10
	.globl	_c_entier
 .endif

	.globl	__driver

/* from system.abc: */
	.globl	dINT
	.globl	INT32
	.globl	CHAR
	.globl	BOOL
	.globl	REAL
	.globl	REAL32
	.globl	FILE
	.globl	__STRING__
	.globl	__ARRAY__
	.globl	__cycle__in__spine
	.globl	__print__graph
	.globl	__eval__to__nf

/* from wcon.c: */
	.globl	_w_print_char
	.globl	_w_print_string
	.globl	_w_print_text
	.globl	_w_print_int
	.globl	_w_print_real

	.globl	_ew_print_char
	.globl	_ew_print_text
	.globl	_ew_print_string
	.globl	_ew_print_int

	.globl	_ew_print_real

	.globl	_ab_stack_size
	.globl	_heap_size
	.globl	_flags

/* from standard c library: */

 .if ! LINUX
	.globl	allocate_memory
	.globl	allocate_memory_with_guard_page_at_end
	.globl	free_memory
 .endif
 
	.globl	_heap_size_multiple
	.globl	_initial_heap_size

	.globl	_min_write_heap_size

	.globl	__Nil
/*	.globl	finalizer_list */
	.comm	finalizer_list,8
/*	.globl	free_finalizer_list */
	.comm	free_finalizer_list,8

_abc_main:
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

	mov	halt_sp_offset[r9],rsp

 .if PROFILE
	call	init_profiler
 .endif

 .if LINUX
	att_call	__start

exit_:
 .else
	call	_start

exit:
 .endif

	call	exit_clean

init_error:
	pop	rdi
	pop	rsi
	pop	rbp
	pop	rdx
	pop	rcx
	pop	rbx

 .if LINUX
	mov	eax,dword ptr _return_code[rip]
	jne	return_code_set_1
	mov	eax,-1
return_code_set_1:
 .endif
	ret


	.globl	DllMain
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
 .if ! LINUX
	.byte	0x49
	push	rsp
	.byte	0x49
	push	rbp
	.byte	0x49
	push	rsi
	.byte	0x49
	push	rdi
 .else
	push	r12
	push	r13
	push	r14
	push	r15
 .endif
	mov	qword ptr dll_initisialised[rip],1

	att_call	init_clean
	test	rax,rax
	jne	init_dll_error

	att_call	init_timer

	mov	halt_sp_offset[r9],rsp 

 .if PROFILE
	att_call	init_profiler
 .endif

	mov	qword ptr saved_heap_p_offset[r9],rdi
	mov	qword ptr saved_r15_offset[r9],r15
	mov	qword ptr saved_a_stack_p_offset[r9],rsi

	mov	rax,1
	jmp	exit_dll_init

init_dll_error:
	xor	rax,rax
	att_jmp	exit_dll_init
	
DLL_PROCESS_DETACH:
	push	rbx 
	push	rbp 
	push	rsi 
	push	rdi
 .if ! LINUX
	.byte	0x49
	push	rsp
	.byte	0x49
	push	rbp
	.byte	0x49
	push	rsi
	.byte	0x49
	push	rdi
 .else
	push	r12
	push	r13
	push	r14
	push	r15
 .endif
	
	mov	rdi,qword ptr saved_heap_p_offset[r9]
	mov	r15,qword ptr saved_r15_offset[r9]
	mov	rsi,qword ptr saved_a_stack_p_offset[r9]

	att_call	exit_clean

exit_dll_init:
 .if ! LINUX
	.byte	0x49
	pop	rdi
	.byte	0x49
	pop	rsi
	.byte	0x49
	pop	rbp
	.byte	0x49
	pop	rsp
 .else
	pop	r15
	pop	r14
	pop	r13
	pop	r12
 .endif
	pop	rdi 
	pop	rsi 
	pop	rbp 
	pop	rbx 
	ret

init_clean:
	sub	rsp,8

	mov	rdi,rsp
	sub	rsi,rsi

	mov	rbp,rsp
	and	rsp,-16
	att_call	_pthread_key_create
	mov	rsp,rbp

 	lea	r9,main_thread_local_storage[rip]

	test	eax,eax
	att_jne	tls_alloc_error

	mov	rdi,qword ptr [rsp]
	mov	rsi,r9

	mov	qword ptr _tlsp_tls_index[rip],rdi

	mov	rbp,rsp
	and	rsp,-16
 	call	_pthread_setspecific
	mov	rsp,rbp

 	lea	r9,main_thread_local_storage[rip]

	test	eax,eax
	att_jne	tls_alloc_error

	add	rsp,8

 	lea	r9,main_thread_local_storage[rip]

	lea	rax,128[rsp]
	sub	rsp,32+8

	mov	rax,qword ptr _flags[rip]
	and	rax,1
	mov	basic_only[rip],rax 

/*	call	allow_prefetch_for_athlon */

	mov	rax,qword ptr _heap_size[rip]
	mov	qword ptr heap_size_offset[r9],rax
	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,65
	div	rbx
 	mov	qword ptr heap_size_65_offset[r9],rax

	mov	rax,qword ptr heap_size_offset[r9]
	sub	rax,7
	xor	rdx,rdx 
	mov	rbx,257
	div	rbx
	mov	heap_size_257_offset[r9],rax
	add	rax,7
	and	rax,-8
	mov	qword ptr heap_copied_vector_size_offset[r9],rax
	mov	qword ptr heap_end_after_copy_gc_offset[r9],0

	mov	rax,qword ptr heap_size_offset[r9]
	add	rax,7
	and	rax,-8
	mov	qword ptr heap_size_offset[r9],rax
	add	rax,7

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	rdi,rax
	call	_malloc
 .else
	mov	rcx,rax
	call	allocate_memory
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

	test	rax,rax 
	je	no_memory_2

	mov	heap_mbp_offset[r9],rax
	lea	rdi,7[rax]
	and	rdi,-8
	mov	heap_p_offset[r9],rdi 

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r14,rdi
	mov	rdi,qword ptr _ab_stack_size[rip]
	mov	qword ptr a_stack_size_offset[r9],rdi
	add	rdi,7
	att_call	_malloc
	mov	rdi,r14
 .else
	mov	rcx,qword ptr _ab_stack_size
	add	rcx,7
	call	allocate_memory_with_guard_page_at_end
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

	test	rax,rax
	je	no_memory_3

	mov	stack_mbp_offset[r9],rax

	add	rax,qword ptr a_stack_size_offset[r9]
	add	rax,7+4095
	and	rax,-4096
	mov	qword ptr a_stack_guard_page[rip],rax
	sub	rax,qword ptr a_stack_size_offset[r9]

	add	rax,7
	and	rax,-8

	mov	rsi,rax
	mov	stack_p_offset[r9],rax

	lea	rcx,small_integers[rip]
	xor	rax,rax 
	lea	rbx,(dINT+2)[rip]

make_small_integers_lp:
	mov	[rcx],rbx 
	mov	8[rcx],rax 
	inc	rax 
	add	rcx,16
	cmp	rax,33
	att_jne	make_small_integers_lp

	lea	rcx,static_characters[rip]
	xor	rax,rax 
	lea	rbx,(CHAR+2)[rip]

make_static_characters_lp:
	mov	[rcx],rbx 
	mov	8[rcx],rax 
	inc	rax 
	add	rcx,16
	cmp	rax,256
	att_jne	make_static_characters_lp

	lea	rcx,(caf_list+8)[rip]
	mov	qword ptr caf_listp[rip],rcx 

	lea	rcx,__Nil-8[rip]
	mov	qword ptr finalizer_list[rip],rcx
	mov	qword ptr free_finalizer_list[rip],rcx

	mov	heap_p1_offset[r9],rdi

	mov	rbp,qword ptr heap_size_257_offset[r9]
	shl	rbp,4
	lea	rax,[rdi+rbp*8]
	mov	heap_copied_vector_offset[r9],rax
	add	rax,heap_copied_vector_size_offset[r9]
	mov	heap_p2_offset[r9],rax

	mov	byte ptr garbage_collect_flag_offset[r9],0

	test	byte ptr _flags[rip],64
	je	no_mark1

	mov	rax,qword ptr heap_size_65_offset[r9]
	mov	qword ptr heap_vector_offset[r9],rdi
	add	rdi,rax

	add	rdi,7
	and	rdi,-8

	mov	qword ptr heap_p3_offset[r9],rdi
	lea	rbp,[rax*8]
	mov	byte ptr garbage_collect_flag_offset[r9],-1

no_mark1:
	mov	rax,qword ptr _initial_heap_size[rip]

	mov	rbx,4000
	test	byte ptr _flags[rip],64
	jne	no_mark9
	add	rbx,rbx 
no_mark9:

	cmp	rax,rbx 
	jle	too_large_or_too_small
	shr	rax,3
	cmp	rax,rbp 
	att_jge	too_large_or_too_small
	mov	rbp,rax 
too_large_or_too_small:

	lea	rax,[rdi+rbp*8]
	mov	heap_end_after_gc_offset[r9],rax

	test	byte ptr _flags[rip],64
	att_je	no_mark2
	mov	qword ptr bit_vector_size_offset[r9],rbp
no_mark2:

	mov	r15,rbp

	add	rsp,32+8
	xor	rax,rax
	ret

tls_alloc_error:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	lea	rdi,tls_alloc_error_string[rip]
 .else
	lea	rcx,tls_alloc_error_string
 .endif
	att_call	_ew_print_string
	mov	rsp,rbp

	mov	qword ptr _execution_aborted[rip],1

	add	rsp,8
 	mov	r9,rbx
	mov	rax,1
	ret

no_memory_2:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	lea	rdi,out_of_memory_string_1[rip]
 .else
	lea	rcx,out_of_memory_string_1
 .endif
	att_call	_ew_print_string
	mov	rsp,rbp

	mov	qword ptr _execution_aborted[rip],1

	add	rsp,32
 	mov	r9,rbx
	mov	rax,1
	ret

no_memory_3:
	mov	rbp,rsp
	and	rsp,-16

	mov	rbx,r9
 .if LINUX
	lea	rdi,out_of_memory_string_1[rip]
 .else
	lea	ecx,out_of_memory_string_1
 .endif
	att_call	_ew_print_string

	mov	qword ptr _execution_aborted[rip],1
  	mov	r9,rbx

 .if LINUX
	mov	rdi,heap_mbp_offset[r9]
	att_call	_free
 .else
	mov	rcx,heap_mbp
	call	free_memory
 .endif

	mov	rsp,rbp
 	mov	r9,rbx

	add	rsp,32
	mov	rax,1
	ret

exit_clean:
	att_call	add_execute_time

	mov	rax,qword ptr _flags[rip]
	test	al,8
	je	no_print_execution_time

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if ! LINUX
	sub	rsp,32
 .endif

 .if LINUX
	lea	rdi,time_string_1[rip]
 .else
	lea	rcx,time_string_1
 .endif
	att_call	_ew_print_string
	
	mov	rax,execute_time[rip]
	call	print_time
	
 .if LINUX
	lea	rdi,time_string_2[rip]
 .else
	lea	rcx,time_string_2
 .endif
	att_call	_ew_print_string

	mov	rax,garbage_collect_time[rip]
 .if MEASURE_GC
 .else
	add	rax,mark_compact_garbage_collect_time[rip]
	add	rax,compact_garbage_collect_time[rip]
 .endif
	att_call	print_time

 .if MEASURE_GC

  .if LINUX
	lea	rdi,time_string_3
  .else
	lea	rcx,time_string_3
  .endif
	call	_ew_print_string

	mov	rax,mark_compact_garbage_collect_time
	call	print_time

  .if LINUX
	lea	rdi,time_string_3
  .else
	lea	rcx,time_string_3
  .endif
	call	_ew_print_string

	mov	rax,compact_garbage_collect_time
	call	print_time
 
 .endif

 .if LINUX
	lea	rdi,time_string_4[rip]
 .else
	lea	rcx,time_string_4
 .endif
	att_call	_ew_print_string

	mov	rax,execute_time[rip]
	add	rax,garbage_collect_time[rip]
	add	rax,IO_time[rip]

	add	rax,mark_compact_garbage_collect_time[rip]
	add	rax,compact_garbage_collect_time[rip]

	att_call	print_time

 .if LINUX
	mov	rdi,10
 .else
	mov	rcx,10
 .endif
	att_call	_ew_print_char

 .if MEASURE_GC

  .if LINUX
	mov	rdi,total_gc_bytes
  .else
	mov	rcx,total_gc_bytes
  .endif
	call	_ew_print_int

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

  .if LINUX
	mov rdi,total_compact_gc_bytes
  .else
	mov rcx,total_compact_gc_bytes
  .endif
	call	_ew_print_int

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr garbage_collect_time
	divsd	xmm0,xmm1
	call	_ew_print_real

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr mark_compact_garbage_collect_time
	divsd	xmm0,xmm1
	call	_ew_print_real

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm0,qword ptr compact_garbage_collect_time
	divsd	xmm0,xmm1
	call	_ew_print_real

  .if LINUX
	mov	rdi,10
  .else
	mov	rcx,10
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	_ew_print_real

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr mark_compact_garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	_ew_print_real

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr compact_garbage_collect_time
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	_ew_print_real

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	call	_ew_print_char

	mov	rax,1000
	cvtsi2sd	xmm1,rax
	cvtsi2sd	xmm2,qword ptr mark_compact_garbage_collect_time
	cvtsi2sd	xmm3,qword ptr compact_garbage_collect_time
	addsd	xmm2,xmm3
	divsd	xmm2,xmm1
	mov	rax,qword ptr total_compact_gc_bytes
	cvtsi2sd	xmm0,rax
	divsd	xmm0,xmm2
	call	_ew_print_real

  .if LINUX
	mov	rdi,10
  .else
	mov	rcx,10
  .endif
	call	_ew_print_char
 
 .endif

	mov	rsp,rbp
 	mov	r9,rbx

no_print_execution_time:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	rdi,stack_mbp_offset[r9]
	att_call	_free
 	mov	r9,rbx

	mov	rdi,heap_mbp_offset[r9]
	att_call	_free
 .else
	mov	rcx,stack_mbp
	sub	rsp,32
	call	free_memory
 	mov	r9,rbx

	mov	rcx,heap_mbp
	call	free_memory
	add	rsp,32
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

 .if PROFILE
  .if ! TRACE
	call	write_profile_information
  .endif
 .endif

	ret

__driver:
	mov	rbp,qword ptr _flags[rip]
	test	rbp,16
	att_je	__print__graph
	att_jmp	__eval__to__nf

print_time:
	push	rbp
	mov	r14,r9
 	push	rbx

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
 .if LINUX
	mov	rdi,rcx
 .else
	sub	rsp,32
 .endif
	att_call	_ew_print_int
	mov	rsp,rbp

	lea	rcx,sprintf_time_buffer[rip]

	xor	rdx,rdx 
	mov	rbx,10

/*	movb	$'.',(%rcx ) */
	mov	byte ptr [rcx],46

	pop	rax

	div	rbx 
	add	rax,48
	add	rdx,48
	mov	byte ptr 1[rcx],al 
	mov	byte ptr 2[rcx],dl 

	mov	rbp,rsp
	and	rsp,-16
 .if LINUX
	mov	rsi,3
	mov	rdi,rcx
 .else
	mov	rdx,3
	sub	rsp,32
 .endif
	att_call	_ew_print_text
	mov	rsp,rbp

 	pop	rbx
 	mov	r9,r14
	pop	rbp
	ret

print_sc:
	mov	rbp,basic_only[rip]
	test	rbp,rbp 
	jne	end_print

print:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rax
 .else
	mov	rcx,rax
	sub	rsp,32
 .endif
	att_call	_w_print_string
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

end_print:
	ret

dump:
	att_call	print
	att_jmp	halt

printD:	test	al,2
	jne	printD_

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi

	lea	rdi,4[rax]
	mov	esi,0[rax]
 .else
	lea	rcx,4[rax]
	mov	edx,dword ptr [rax]
	sub	rsp,32
 .endif
	att_call	_w_print_text
 .if LINUX
	mov	rsi,r13
	mov	rsi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

DtoAC_record:
	movsxd	rbx,dword ptr (-6)[rax]
	lea	rbp,(-6)[rax+rbx]
	jmp	DtoAC_string_a2

DtoAC:	test	al,2
	jne	DtoAC_

	mov	rbp,rax 
	att_jmp	DtoAC_string_a2

DtoAC_:
 .if NEW_DESCRIPTORS
	cmp	word ptr (-2)[rax],256
	att_jae	DtoAC_record

	movzx	rbx,word ptr [rax]
	lea	rbp,10[rax+rbx]
 .else
	lea	rbp,(-2)[rax]
	movsx	rbx,word ptr [rbp]
	cmp	rbx,256
	jae	DtoAC_record

	shl	rbx,3
	sub	rbp,rbx 

 	movzx	rbx,word ptr (-2)[rbp]
	lea	rbp,4[rbp+rbx*8]
 .endif

DtoAC_string_a2:
	mov	eax,dword ptr [rbp]
	lea	rcx,4[rbp]
	jmp	build_string

print_symbol:
	xor	rbx,rbx 
	jmp	print_symbol_2

print_symbol_sc:
	mov	rbx,basic_only[rip]
print_symbol_2:
	mov	rax,[rcx]

	lea	rbp,dINT+2[rip]
	cmp	rax,rbp
	je	print_int_node

	lea	rbp,CHAR+2[rip]
	cmp	rax,rbp
	je	print_char_denotation

	lea	rbp,BOOL+2[rip]
	cmp	rax,rbp
	je	print_bool

	lea	rbp,REAL+2[rip]
	cmp	rax,rbp
	je	print_real_node
	
	test	rbx,rbx 
	jne	end_print_symbol

printD_:
	cmp	word ptr (-2)[rax],256
	jae	print_record

	movzx	rbx,word ptr [rax]
	lea	rbp,10[rax+rbx]
	jmp	print_string_a2

print_record:
	movsxd	rbp,dword ptr (-6)[rax]
	lea	rbp,-6[rax+rbp]
	att_jmp	print_string_a2

end_print_symbol:
	ret

print_int_node:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,8[rcx]
 .else
	sub	rsp,32
	mov	rcx,8[rcx]
 .endif
	att_call	_w_print_int
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_int:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rax
 .else
	mov	rcx,rax
	sub	rsp,32
 .endif
	att_call	_w_print_int
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_char_denotation:
	test	rbx,rbx 
	jne	print_char_node

	mov	rbp,rsp
	and	rsp,-16
	mov	r14,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
 .else
	sub	rsp,32
 .endif
	mov	rbx,8[rcx]

 .if LINUX
	mov	rdi,0x27
 .else
	mov	rcx,0x27
 .endif
	att_call	_w_print_char

 .if LINUX
	mov	rdi,rbx
 .else
	mov	rcx,rbx
 .endif
	att_call	_w_print_char

 .if LINUX
	mov	rdi,0x27
 .else
	mov	rcx,0x27
 .endif
	att_call	_w_print_char

 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,r14
	ret

print_char_node:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
 
	mov	rdi,8[rcx]
.else
	mov	rcx,8[rcx]
	sub	rsp,32
 .endif
	att_call	_w_print_char
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret
	
print_char:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	
	mov	rdi,rax
 .else
	mov	rcx,rax 
	sub	rsp,32
 .endif
	att_call	_w_print_char
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_bool:
	movsx	rcx,byte ptr 8[rcx]
	test	rcx,rcx 
	je	print_false

print_true:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,true_c_string[rip]
 .else
	lea	rcx,true_c_string
	sub	rsp,32
 .endif
	att_call	_w_print_string
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_false:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,false_c_string[rip]
 .else
	lea	rcx,false_c_string
	sub	rsp,32
 .endif
	att_call	_w_print_string
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_real_node:
	movlpd	xmm0,qword ptr 8[rcx]
print_real:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
 .else
	sub	rsp,32
 .endif
	att_call	_w_print_real
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print_string_a2:
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rdi,4[rbp]
	mov	esi,0[rbp]
	mov	rbp,rsp
	and	rsp,-16
 .else
	lea	rcx,4[rbp]
	mov	edx,0[rbp]
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
 .endif
	att_call	_w_print_text
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	ret

print__chars__sc:
	mov	rbp,basic_only[rip]
	test	rbp,rbp 
	jne	no_print_chars

print__string__:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rsi,8[rcx]
	lea	rdi,16[rcx]
 .else
	mov	rdx,8[rcx]
	lea	rcx,16[rcx]
	sub	rsp,32
 .endif
	att_call	_w_print_text
 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
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
	att_jnc	mul_array_size_lp

	lea	rdi,[rcx+rdx*8]
	jmp	push_a_elements
push_a_elements_lp:
	mov	rax,qword ptr (-8)[rcx]
	sub	rcx,8
	mov	qword ptr [rsi],rax 
	add	rsi,8
push_a_elements:
	sub	rbx,1
	att_jnc	push_a_elements_lp

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
	att_jnc	push_b_elements_lp

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
	att_jmp	push_r_b_elements
not_first_arg_b:
	push	(-8)[rdx]
	sub	rdx,8
push_r_b_elements:
	sub	rbx,1
	att_jnc	push_r_b_elements_lp

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
	att_jmp	push_r_a_elements
not_first_arg_a:
	mov	rbp,qword ptr (-8)[rdx]
	sub	rdx,8
	mov	qword ptr [rsi],rbp
	add	rsi,8
push_r_a_elements:
	sub	rbx,1
	att_jnc	push_r_a_elements_lp

	pop	rax 
	ret

BtoAC:
	test	al,al 
	je	BtoAC_false
BtoAC_true:
	lea	rcx,true_string[rip]
	ret
BtoAC_false:
	lea	rcx,false_string[rip]
	ret

RtoAC:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	lea	rsi,printf_real_string[rip]
	lea	rdi,sprintf_buffer[rip]
	mov	rax,1
	call	_sprintf
	mov	rsi,r13
	mov	rdi,r14
 .else
	lea	rdx,sprintf_buffer
	sub	rsp,32
	call	convert_real_to_string
 .endif
	mov	rsp,rbp
 	mov	r9,rbx
	jmp	return_sprintf_buffer

ItoAC:
	lea	rcx,sprintf_buffer[rip]
	call	int_to_string
	
	mov	rax,rcx
	lea	rcx,sprintf_buffer[rip]
	sub	rax,rcx

	jmp	sprintf_buffer_to_string

	.globl	convert_int_to_string
convert_int_to_string:
	push	rbp
	push	rbx
	mov	rax,rdx
	att_call	int_to_string
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

	mov	rdx,0x0cccccccccccccccd
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
	att_jmp	calculate_digits

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
	att_jmp	reverse_digits

end_reverse_digits:
	mov	byte ptr [rcx],0
	ret

return_sprintf_buffer:
	lea	rax,(sprintf_buffer-1)[rip]
skip_characters:
	inc	rax 
	cmp	byte ptr [rax],0
	att_jne	skip_characters

	lea	rcx,sprintf_buffer[rip]
	sub	rax,rcx

sprintf_buffer_to_string:
	lea	rcx,sprintf_buffer[rip]
build_string:

	lea	rbx,16+7[rax]
	shr	rbx,3

	sub	r15,rbx
	jge	D_to_S_no_gc

	push	rcx 
	att_call	collect_0
	pop	rcx 

D_to_S_no_gc:
	sub	rbx,2
	lea	rbp,__STRING__+2[rip]
	mov	qword ptr [rdi],rbp
	mov	rbp,rdi
	mov	8[rdi],rax 
	add	rdi,16
	jmp	D_to_S_cp_str_2

D_to_S_cp_str_1:
	mov	rax,[rcx]
	add	rcx,8
	mov	[rdi],rax 
	add	rdi,8
D_to_S_cp_str_2:
	sub	rbx,1
	att_jnc	D_to_S_cp_str_1
	
	mov	rcx,rbp 
	ret

eqD:	mov	rax,[rcx]
	cmp	rax,[rdx]
	jne	eqD_false

	lea	rbp,dINT+2[rip]
	cmp	rax,rbp
	je	eqD_INT
	lea	rbp,CHAR+2[rip]
	cmp	rax,rbp
	je	eqD_CHAR
	lea	rbp,BOOL+2[rip]
	cmp	rax,rbp
	je	eqD_BOOL
	lea	rbp,REAL+2[rip]
	cmp	rax,rbp
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
/* */
/*	the timer */
/* */


init_timer:
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rsp
	att_call    _times
	mov	rsi,r13
	mov	rdi,r14
	mov	eax,[rsp]
	imul	eax,10
 .else
	call	GetTickCount
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

	mov	last_time[rip],rax 
	xor	rax,rax 
	mov	execute_time[rip],rax 
	mov	garbage_collect_time[rip],rax 
	mov	IO_time[rip],rax 

	mov	mark_compact_garbage_collect_time[rip],rax 
	mov	compact_garbage_collect_time[rip],rax 

	ret

get_time_diff:
	mov	rbp,rsp
	and	rsp,-16
	sub	rsp,32
	mov	rbx,r9
 .if LINUX
	mov	r13,rsi
	mov	r14,rdi
	mov	rdi,rsp
	att_call    _times
	mov	rsi,r13
	mov	rdi,r14
	mov	eax,[rsp]
	imul	eax,10
 .else
	call	GetTickCount
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

	lea	rcx,last_time[rip]
	mov	rdx,[rcx]
	mov	[rcx],rax 
	sub	rax,rdx
	ret
	
add_execute_time:
	att_call	get_time_diff
	lea	rcx,execute_time[rip]

add_time:
	add	rax,[rcx]
	mov	[rcx],rax 
	ret

add_garbage_collect_time:
	att_call	get_time_diff
	lea	rcx,garbage_collect_time[rip]
	att_jmp	add_time

add_IO_time:
	att_call	get_time_diff
	lea	rcx,IO_time[rip]
	att_jmp	add_time

add_mark_compact_garbage_collect_time:
	att_call	get_time_diff
	lea	rcx,mark_compact_garbage_collect_time[rip]
	att_jmp	add_time

add_compact_garbage_collect_time:
	att_call	get_time_diff
	lea	rcx,compact_garbage_collect_time[rip]
	att_jmp	add_time
/* */
/*	the garbage collector */
/* */

collect_3:
 .if PROFILE
	lea	rbp,garbage_collector_name[rip]
	att_call	profile_s
 .endif
	mov	[rsi],rcx 
	mov	8[rsi],rdx 
	mov	16[rsi],r8
	add	rsi,24
	call	collect_0_
	mov	r8,(-8)[rsi]
	mov	rdx,(-16)[rsi]
	mov	rcx,(-24)[rsi]
	sub	rsi,24
 .if PROFILE
	jmp	profile_r
 .else
	ret
 .endif

collect_2:
 .if PROFILE
	lea	rbp,garbage_collector_name[rip]
	att_call	profile_s
 .endif
	mov	[rsi],rcx 
	mov	8[rsi],rdx 
	add	rsi,16
	att_call	collect_0_
	mov	rdx,(-8)[rsi]
	mov	rcx,(-16)[rsi]
	sub	rsi,16
 .if PROFILE
	att_jmp	profile_r
 .else
	ret
 .endif

collect_1:
 .if PROFILE
	lea	rbp,garbage_collector_name[rip]
	att_call	profile_s
 .endif
	mov	[rsi],rcx 
	add	rsi,8
	att_call	collect_0_
	mov	rcx,(-8)[rsi]
	sub	rsi,8
 .if PROFILE
	att_jmp	profile_r
 .else
	ret
 .endif

collect_0:
 .if PROFILE
	lea	rbp,garbage_collector_name[rip]
	att_call	profile_s
 .endif
	att_call	collect_0_
 .if PROFILE
	att_jmp	profile_r
 .else
	ret
 .endif

collect_0_:
	mov	rbp,rdi 

	push	rax
	push	rbx

	mov	rbx,qword ptr heap_end_after_gc_offset[r9]
	sub	rbx,rdi

	shr	rbx,3
	sub	rbx,r15
	mov	qword ptr n_allocated_words_offset[r9],rbx

	test	byte ptr _flags[rip],64
	je	no_mark3

	mov	rbp,qword ptr bit_counter_offset[r9]
	test	rbp,rbp 
	je	no_scan

	push	rsi
	mov	rsi,rbx

	xor	rbx,rbx 
	mov	rcx,qword ptr bit_vector_p_offset[r9]

scan_bits:
	cmp	ebx,dword ptr[rcx]
	je	zero_bits
	mov	dword ptr [rcx],ebx 
	add	rcx,4
	sub	rbp,1
	att_jne	scan_bits

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
	att_jne	skip_zero_bits_lp

	test	rax,rax 
	att_je	end_bits
	mov	dword ptr (-4)[rcx],ebx 
	mov	rax,rcx 
	sub	rax,rdx 
	jmp	end_bits2

end_zero_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	shl	rax,3
	add	qword ptr n_free_words_after_mark_offset[r9],rax
	mov	dword ptr (-4)[rcx],ebx

	cmp	rax,rsi
	att_jb	scan_bits

found_free_memory:
	mov	qword ptr bit_counter_offset[r9],rbp 
	mov	qword ptr bit_vector_p_offset[r9],rcx 

	lea	rbp,(-4)[rdx]
	sub	rbp,qword ptr heap_vector_offset[r9]
	shl	rbp,6
	mov	rdi,qword ptr heap_p3_offset[r9]
	add	rdi,rbp 

	lea	rbp,[rdi+rax*8]
	mov	qword ptr heap_end_after_gc_offset[r9],rbp 

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
	add	qword ptr n_free_words_after_mark_offset[r9],rax 
	cmp	rax,rsi 
	att_jae	found_free_memory

end_scan:
	pop	rsi 
	mov	qword ptr bit_counter_offset[r9],rbp

no_scan:

no_mark3:
	movsx	rax,byte ptr garbage_collect_flag_offset[r9]
	test	rax,rax 
	jle	collect

	sub	rax,2
	mov	byte ptr garbage_collect_flag_offset[r9],al 

	mov	rbp,qword ptr extra_heap_size_offset[r9]
	cmp	rbx,rbp 
	att_ja	collect

	mov	rdi,qword ptr extra_heap_offset[r9]

	mov	r15,rbp

	lea	rbp,[rdi+rbp*8]
	mov	qword ptr heap_end_after_gc_offset[r9],rbp 

	sub	r15,rbx

	pop	rbx 
	pop	rax 
	ret

collect:
 .if LINUX
	sub	rsp,104
 .else
	sub	rsp,88
 .endif
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
 .if LINUX
	movsd	88[rsp],xmm6
	movsd	96[rsp],xmm7
 .endif

	att_call	add_execute_time

	test	qword ptr _flags[rip],4
	je	no_print_stack_sizes

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
 	mov	r13,rsi
	mov	r14,rdi
 .else
	sub	rsp,32
 .endif

 .if 0
  .if LINUX
	mov	rdi,qword ptr 64[rsp]
  .else
	mov	rcx,qword ptr 96[rsp]
  .endif
	call	_ew_print_int

  .if LINUX
	mov	rdi,32
  .else
	mov	rcx,32
  .endif
	att_call	_ew_print_char
 .endif

 .if LINUX
	lea	rdi,garbage_collect_string_1[rip]
 .else
	lea	rcx,garbage_collect_string_1
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rdi,r13
	mov	r9,rbx
	sub	rdi,stack_p_offset[r9]
 .else
	mov	rcx,rsi 
	sub	rcx,stack_p
 .endif
	att_call	_ew_print_int

 .if LINUX
	lea	rdi,garbage_collect_string_2[rip]
 .else
	lea	rcx,garbage_collect_string_2
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	r9,rbx
	mov	rdi,halt_sp_offset[r9]
	sub	rdi,rsp 
 .else
	mov	rcx,halt_sp
	sub	rcx,rsp 
 .endif
	att_call	_ew_print_int

 .if LINUX
	lea	rdi,garbage_collect_string_3[rip]
 .else
	lea	rcx,garbage_collect_string_3
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

no_print_stack_sizes:
	mov	rax,stack_p_offset[r9]
	add	rax,qword ptr a_stack_size_offset[r9]
	cmp	rsi,rax 
	att_ja	stack_overflow

	test	byte ptr _flags[rip],64
	jne	compacting_collector

	cmp	byte ptr garbage_collect_flag_offset[r9],0
	att_jne	compacting_collector

	mov	rbp,heap_copied_vector_offset[r9]

	cmp	qword ptr heap_end_after_copy_gc_offset[r9],0
	je	zero_all

	mov	rax,rdi
	sub	rax,qword ptr heap_p1_offset[r9]
	add	rax,127*8
	shr	rax,9
	call	zero_bit_vector

	mov	rdx,qword ptr heap_end_after_copy_gc_offset[r9]
	sub	rdx,qword ptr heap_p1_offset[r9]
	shr	rdx,7
	and	rdx,-4

	mov	rbp,qword ptr heap_copied_vector_offset[r9]
	mov	rax,qword ptr heap_copied_vector_size_offset[r9]
	add	rbp,rdx 
	sub	rax,rdx 
	shr	rax,2

	mov	qword ptr heap_end_after_copy_gc_offset[r9],0

	att_call	zero_bit_vector
	jmp	end_zero_bit_vector

zero_all:
	mov	rax,heap_copied_vector_size_offset[r9]
	shr	rax,2
	att_call	zero_bit_vector

end_zero_bit_vector:

	.include	"acopy.s"

	mov	qword ptr heap2_begin_and_end_offset[r9],rsi 

	mov	r15,rsi
	sub	r15,rdi

	mov	rax,heap_size_257_offset[r9]
	shl	rax,7
	sub	rax,r15
	add	qword ptr total_gc_bytes[rip],rax

	shr	r15,3

	pop	rsi 

	att_call	add_garbage_collect_time

	sub	r15,qword ptr n_allocated_words_offset[r9]
	jc	switch_to_mark_scan

	lea	rax,[r15+r15*4]
	shl	rax,6
	mov	rbx,qword ptr heap_size_offset[r9]
	mov	rcx,rbx 
	shl	rbx,2
	add	rbx,rcx 
	add	rbx,rbx 
	add	rbx,rcx
	cmp	rax,rbx
	jnc	no_mark_scan

switch_to_mark_scan:
	mov	rax,qword ptr heap_size_65_offset[r9]
	shl	rax,6
	mov	rbx,qword ptr heap_p_offset[r9]

	mov	rcx,qword ptr heap_p1_offset[r9]
	cmp	rcx,qword ptr heap_p2_offset[r9]
	jc	vector_at_begin
	
vector_at_end:
	mov	qword ptr heap_p3_offset[r9],rbx 
	add	rbx,rax 
	mov	qword ptr heap_vector_offset[r9],rbx 
	
	mov	rax,qword ptr heap_p1_offset[r9]
	mov	qword ptr extra_heap_offset[r9],rax 
	sub	rbx,rax 
	shr	rbx,3
	mov	qword ptr extra_heap_size_offset[r9],rbx
	jmp	switch_to_mark_scan_2

vector_at_begin:
	mov	qword ptr heap_vector_offset[r9],rbx
	add	rbx,qword ptr heap_size_offset[r9]
	sub	rbx,rax 
	mov	qword ptr heap_p3_offset[r9],rbx 
	
	mov	qword ptr extra_heap_offset[r9],rbx
	mov	rcx,qword ptr heap_p2_offset[r9]
	sub	rcx,rbx 
	shr	rcx,3
	mov	qword ptr extra_heap_size_offset[r9],rcx 

switch_to_mark_scan_2:
	mov	rax,heap_size_257_offset[r9]
	shl	rax,7-3
	sub	rax,r15
	shl	rax,3

	mov	byte ptr garbage_collect_flag_offset[r9],1

	lea	rcx,heap_use_after_gc_string_1[rip]

	test	r15,r15
	jns	end_garbage_collect
	
	mov	byte ptr garbage_collect_flag_offset[r9],-1
	
	mov	rbx,qword ptr extra_heap_size_offset[r9]
	mov	r15,rbx
	sub	r15,qword ptr n_allocated_words_offset[r9]
	js	out_of_memory_4_3

	mov	rdi,qword ptr extra_heap_offset[r9]
	shl	rbx,3
	add	rbx,rdi
	mov	qword ptr heap_end_after_gc_offset[r9],rbx

	mov	qword ptr heap_end_write_heap[rip],rdi

	mov	qword ptr d3_flag_write_heap[rip],1
	jmp	end_garbage_collect_

no_mark_scan:
/* exchange the semi_spaces */
	mov	rax,heap_p1_offset[r9]
	mov	rbx,heap_p2_offset[r9]
	mov	heap_p2_offset[r9],rax 
	mov	heap_p1_offset[r9],rbx 

	mov	rax,heap_size_257_offset[r9]
	shl	rax,7-3
	mov	rbx,rax
	sub	rax,r15

	mov	rcx,rax
	imul	qword ptr _heap_size_multiple[rip]
	shrd	rax,rdx,9
	shr	rdx,9
	jne	no_small_heap1

	cmp	rax,4000
	jge	not_too_small1
	mov	rax,4000
not_too_small1:
	sub	rbx,rax 
	att_jb	no_small_heap1

	sub	r15,rbx
	shl	rbx,3
	mov	rbp,qword ptr heap_end_after_gc_offset[r9]
	mov	qword ptr heap_end_after_copy_gc_offset[r9],rbp 
	sub	rbp,rbx 
	mov	qword ptr heap_end_after_gc_offset[r9],rbp 

no_small_heap1:
	mov	rax,rcx
	shl	rax,3

	lea	rcx,heap_use_after_gc_string_1[rip]

end_garbage_collect:

	mov	qword ptr heap_end_write_heap[rip],rdi 
	mov	qword ptr d3_flag_write_heap[rip],0

end_garbage_collect_:
	push	rax

	test	qword ptr _flags[rip],2
	je	no_heap_use_message

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9

 .if LINUX
	mov	r13,rsi
	mov	r14,rdi	

	mov	rdi,rcx
 .else
	sub	rsp,32
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rdi,[rbp]
 .else
	mov	rcx,[rbp]
 .endif
	att_call	_ew_print_int

 .if LINUX
	lea	rdi,heap_use_after_gc_string_2[rip]
 .else
	lea	rcx,heap_use_after_gc_string_2
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rsi,r13
	mov	rdi,r14
 .else
 	add	rsp,32
 .endif
	mov	rsp,rbp
 	mov	r9,rbx

no_heap_use_message:
	call	call_finalizers

	pop	rax

	test	byte ptr _flags[rip],32
	je	no_write_heap

	cmp	rax,qword ptr _min_write_heap_size[rip]
	att_jb	no_write_heap

	push	rcx 
	push 	rdx 
	push	rbp 
	push	rsi 
	push	rdi 

	sub	rsp,128

	mov	rax,qword ptr d3_flag_write_heap[rip]
	test	rax,rax 
	jne	copy_to_compact_with_alloc_in_extra_heap

	movsx	rax,byte ptr garbage_collect_flag_offset[r9]
	
	mov	rcx,qword ptr heap2_begin_and_end_offset[r9]
	mov	rdx,qword ptr (heap2_begin_and_end_offset+8)[r9]

	lea	rbx,heap_p1_offset[r9]
	
	test	rax,rax 
	je	gc0
	
	lea	rbx,heap_p2_offset[r9]
	jg	gc1

	lea	rbx,heap_p3_offset[r9]
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
	
	mov	rbx,qword ptr stack_p_offset[r9]

	mov	qword ptr 32[rax],rbx 

	mov	qword ptr 40[rax],rsi 
	mov	qword ptr 48[rax],0
	mov	qword ptr 56[rax],0
	
	lea	rbp,small_integers[rip]
	mov	qword ptr 64[rax],rbp
	lea	rbp,static_characters[rip]
	mov	qword ptr 72[rax],rbp

	lea	rbp,dINT+2[rip]
	mov	qword ptr 80[rax],rbp
	lea	rbp,CHAR+2[rip]
	mov	qword ptr 88[rax],rbp
	lea	rbp,REAL+2[rip]
	mov	qword ptr 96[rax],rbp
	lea	rbp,BOOL+2[rip]
	mov	qword ptr 104[rax],rbp
	lea	rbp,__STRING__+2[rip]
	mov	qword ptr 112[rax],rbp
	lea	rbp,__ARRAY__+2[rip]
	mov	qword ptr 120[rax],rbp

	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
 .if LINUX
	mov	rdi,rax
 .else
	mov	rcx,rax
	sub	rsp,32
 .endif
 .if ! LINUX
	call	write_heap
 .endif
	mov	rsp,rbp

	add	rsp,128

 	mov	r9,rbx
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
 .if LINUX
	movlpd	xmm6,88[rsp]
	movlpd	xmm7,96[rsp]
	add	rsp,104
 .else
	add	rsp,88
 .endif
	pop	rbx 
	pop	rax 
	ret

call_finalizers:
	mov	rax,qword ptr free_finalizer_list[rip]

call_finalizers_lp:
	lea	rbx,__Nil-8[rip]
	cmp	rax,rbx
	je	end_call_finalizers
	push	8[rax]
	mov	rbx,qword ptr 16[rax]
	push	8[rbx]
	call	qword ptr [rbx]
	add	rsp,8
	pop	rax 
	att_jmp	call_finalizers_lp
end_call_finalizers:

	lea	rbx,__Nil-8[rip]
	mov	qword ptr free_finalizer_list[rip],rbx
	ret

copy_to_compact_with_alloc_in_extra_heap:
	mov	rcx,qword ptr heap2_begin_and_end_offset[r9]
	mov	rdx,qword ptr (heap2_begin_and_end_offset+8)[r9]
	lea	rbx,heap_p2_offset[r9]
	att_jmp	gc1

allow_prefetch_for_athlon:
	test	qword ptr _flags[rip],4096
	jne	no_prefetch_flag

	xor	rax,rax
	cpuid
	test	rax,rax
	jz	disable_prefetch_flag

 .if LINUX
	cmp	rbx,'A+('u*0x100)+('t*0x10000)+('h*0x1000000)
	att_jne	disable_prefetch_flag
	cmp	rdx,'e+('n*0x100)+('t*0x10000)+('i*0x1000000)
	att_jne	disable_prefetch_flag
	cmp	rcx,'c+('A*0x100)+('M*0x10000)+('D*0x1000000)
	att_jne	disable_prefetch_flag
 .else
	cmp	rbx,'A'+('u' shl 8)+('t' shl 16)+('h' shl 24)
	jne	disable_prefetch_flag
	cmp	rdx,'e'+('n' shl 8)+('t' shl 16)+('i' shl 24)
	jne	disable_prefetch_flag
	cmp	rcx,'c'+('A' shl 8)+('M' shl 16)+('D' shl 24)
	jne	disable_prefetch_flag
 .endif

/*	mov	rax,1 */
/*	cpuid */
/*	and	rax,0x0f00 */
/*	cmp	rax,0x600 */
/*	je	keep_prefetch_flag */

	ret

disable_prefetch_flag:
	and	qword ptr _flags[rip],-4097
keep_prefetch_flag:
no_prefetch_flag:
	ret

out_of_memory_4_3:
out_of_memory_4_2:
out_of_memory_4_1:
out_of_memory_4:
	att_call	add_garbage_collect_time
	
	lea	rbp,out_of_memory_string_4[rip]
	att_jmp	print_error

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
	att_jae	zero_bits1_4
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
	att_ja	reorder_lp

	pop	rax 
	pop	rbx 
	add	rsp,16
	pop	rbp 
	pop	rsi 
	ret

/* */
/*	the sliding compacting garbage collector */
/* */

compacting_collector:
/* zero all mark bits */

	mov	rax,qword ptr heap_p3_offset[r9]
	neg	rax
	mov	qword ptr neg_heap_p3_offset[r9],rax 

	mov	qword ptr stack_top_offset[r9],rsi

	mov	rdi,qword ptr heap_vector_offset[r9]

	test	byte ptr _flags[rip],64
	je	no_mark4

	cmp	qword ptr zero_bits_before_mark_offset[r9],0
	je	no_zero_bits

	mov	qword ptr zero_bits_before_mark_offset[r9],0

no_mark4:
	mov	rbp,rdi
	mov	rax,qword ptr heap_size_65_offset[r9]
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
	att_jnc	zero_bits_4

	test	byte ptr _flags[rip],64
	je	no_mark5

no_zero_bits:
	mov	rax,qword ptr n_last_heap_free_bytes_offset[r9]
	mov	rbx,qword ptr n_free_words_after_mark_offset[r9]
	shl	rbx,3

	mov	rbp,rbx 
	shl	rbp,3
	add	rbp,rbx 
	shr	rbp,2

	cmp	rax,rbp 
	jg	compact_gc

	mov	rbx,qword ptr bit_vector_size_offset[r9]
	shl	rbx,3

	sub	rax,rbx 
	neg	rax

	imul	qword ptr _heap_size_multiple[rip]
	shrd	rax,rdx,7
	shr	rdx,7
	jne	no_smaller_heap
	
	cmp	rax,rbx 
	att_jae	no_smaller_heap
	
	cmp	rbx,8000
	att_jbe	no_smaller_heap
	
	att_jmp	compact_gc
no_smaller_heap:
	test	qword ptr _flags[rip],4096
	jne	pmark

	.include	"amark.s"

	.include	"amark_prefetch.s"

compact_gc:
	mov	qword ptr zero_bits_before_mark_offset[r9],1
	mov	qword ptr n_last_heap_free_bytes_offset[r9],0
	mov	qword ptr n_free_words_after_mark_offset[r9],1000

no_mark5:

	.include	"acompact.s"

	mov	rsi,qword ptr stack_top_offset[r9]

	mov	rbx,qword ptr heap_size_65_offset[r9]
	shl	rbx,6
	add	rbx,qword ptr heap_p3_offset[r9]

	mov	qword ptr heap_end_after_gc_offset[r9],rbx 

	sub	rbx,rdi
	shr	rbx,3

	sub	rbx,qword ptr n_allocated_words_offset[r9]
	mov	r15,rbx
	att_jc	out_of_memory_4_1

	mov	rax,rbx
	shl	rax,2
	add	rax,rbx
	shl	rax,4
	cmp	rax,qword ptr heap_size_offset[r9]
	att_jc	out_of_memory_4_2

 	test	byte ptr _flags[rip],64
	je	no_mark_6

	mov	rax,qword ptr neg_heap_p3_offset[r9]
	add	rax,rdi 
	mov	rbx,qword ptr n_allocated_words_offset[r9]
	lea	rax,[rax+rbx*8]

	mov	rbx,qword ptr heap_size_65_offset[r9]
	shl	rbx,6
	
	imul	qword ptr _heap_size_multiple[rip]
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
	att_jb	no_small_heap2
	
	sub	qword ptr heap_end_after_gc_offset[r9],rcx 
	shr	rcx,3
	sub	r15,rcx

	mov	rbx,rax

no_small_heap2:
	shr	rbx,3
	mov	qword ptr bit_vector_size_offset[r9],rbx

no_mark_6:
	jmp	no_copy_garbage_collection

no_copy_garbage_collection:
	att_call	add_compact_garbage_collect_time

	mov	rax,rdi
	sub	rax,qword ptr heap_p3_offset[r9]

	add	qword ptr total_compact_gc_bytes[rip],rax 

	mov	rax,rdi 
	sub	rax,qword ptr heap_p3_offset[r9]
	mov	rbx,qword ptr n_allocated_words_offset[r9]
	lea	rax,[rax+rbx*8]

	lea	rcx,heap_use_after_compact_gc_string_1[rip]
	att_jmp	end_garbage_collect

	.globl	clean_exception_handler_

clean_exception_handler_:

	att_jmp	clean_exception_handler_

	mov	rax,qword ptr [rcx]
	cmp	dword ptr [rax],0x0c00000fd
	je  	stack_overflow_exception

	cmp	dword ptr [rax],0x80000001
	je  	guard_page_or_access_violation_exception

	cmp	dword ptr [rax] ,0x0c0000005
	att_je  	guard_page_or_access_violation_exception

no_stack_overflow_exception:
	mov	rax,0
	ret

guard_page_or_access_violation_exception:
	mov	rax,qword ptr 16[rax]
	and	rax,-4096
	cmp	qword ptr a_stack_guard_page[rip],rax
	att_jne 	no_stack_overflow_exception

	cmp	qword ptr a_stack_guard_page[rip],0
	att_je  	no_stack_overflow_exception

stack_overflow_exception:
	mov	rax,qword ptr 8[rcx]
	lea	rax,stack_overflow[rip]
	mov	qword ptr (0x0F8)[rax],rax

	mov	rax,-1
	ret

stack_overflow:
	att_call	add_execute_time

	lea	rbp,stack_overflow_string[rip]
	att_jmp	print_error

_IO_error:
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9

	mov	rbx,rcx
 .if LINUX
	lea	rdi,IO_error_string[rip]
 .else
	sub	rsp,32
	lea	rcx,IO_error_string
 .endif
	att_call	_ew_print_string

 .if LINUX
	mov	rdi,rbx
 .else
	mov	rcx,rbx
 .endif
	att_call	_ew_print_string

 .if LINUX
	lea	rdi,new_line_string[rip]
 .else
	lea	rcx,new_line_string
 .endif
	att_call	_ew_print_string

	mov	rsp,rbp
 	mov	r9,rbx

	att_jmp	halt

print_error:
 .if LINUX
	mov	rdi,rbp
 .else
	mov	rcx,rbp 
 .endif
	mov	rbp,rsp
	and	rsp,-16
	mov	rbx,r9
	att_call	_ew_print_string
	mov	rsp,rbp
 	mov	r9,rbx

halt:
	mov	rsp,halt_sp_offset[r9]

 .if PROFILE
	call	write_profile_stack
 .endif

	mov	qword ptr _execution_aborted[rip],1

	cmp	qword ptr dll_initisialised[rip],0
 .if LINUX
	att_je	exit_
 .else
	je	exit
 .endif
 .if LINUX
	cmp	dword ptr _return_code[rip],0
 .else
	cmp	qword ptr return_code,0
 .endif
	jne	return_code_set
 .if LINUX
	mov	dword ptr _return_code[rip],-1
 .else
	mov	qword ptr return_code,-1
 .endif
return_code_set:
 .if LINUX
	mov	edi,dword ptr _return_code[rip]
	and	rsp,-16
	att_call	_exit
 .else
	push	qword ptr return_code
	call	(ExitProcess)
 .endif
	att_jmp	return_code_set

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

	.align	2 
	lea	rax,e__system__eaind[rip]
	jmp	rax
	.byte	0,0,0
	.long	0x80000000 /* e__system__dind */
	.long	-2
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
	lea	rbp,__cycle__in__spine[rip]
	mov	qword ptr [rcx],rbp
	mov	qword ptr [rsi],rcx 

	test	byte ptr _flags[rip],64
	att_je	__cycle__in__spine

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

 .if PROFILE
	call	profile_n
	mov	rbp,rax
 .endif
eval_upd_0:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
	mov	8[rdx],rcx 
	jmp	rbp

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_1:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
	mov	rax,8[rdx]
	mov	8[rdx],rcx 
	mov	rdx,rax 
	jmp	rbp

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_2:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
	mov	r8,8[rdx]
	mov	8[rdx],rcx
	mov	rdx,16[rdx]
	jmp	rbp 

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_3:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
	mov	r8,8[rdx]
	mov	8[rdx],rcx
	mov	[rsi],rcx
	mov	rcx,24[rdx]
	add	rsi,8
	mov	rdx,16[rdx]
	jmp	rbp

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_4:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
	mov	r8,8[rdx]
	mov	8[rdx],rcx 
	mov	[rsi],rcx 
	mov	rbx,32[rdx]
	mov	8[rsi],rbx 
	mov	rcx,24[rdx]
	add	rsi,16
	mov	rdx,16[rdx]
	jmp	rbp

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_5:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
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

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_6:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
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

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_7:
	mov	rax,0
	mov	rbx,40
eval_upd_n:
	lea	r8,e__system__nind[rip]
	mov	qword ptr [rdx],r8
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
	att_jnc	eval_upd_n_lp

	mov	rcx,(-8)[rdx]
	mov	rdx,(-16)[rdx ]
	jmp	rbp 

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_8:
	mov	rax,1
	mov	rbx,48
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_9:
	mov	rax,2
	mov	rbx,56
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_10:
	mov	rax,3
	mov	rbx,64
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_11:
	mov	rax,4
	mov	rbx,72
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_12:
	mov	rax,5
	mov	rbx,80
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_13:
	mov	rax,6
	mov	rbx,88
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_14:
	mov	rax,7
	mov	rbx,96
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_15:
	mov	rax,8
	mov	rbx,104
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_16:
	mov	rax,9
	mov	rbx,112
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_17:
	mov	rax,10
	mov	rbx,120
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_18:
	mov	rax,11
	mov	rbx,128
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_19:
	mov	rax,12
	mov	rbx,136
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_20:
	mov	rax,13
	mov	rbx,144
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_21:
	mov	rax,14
	mov	rbx,152
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_22:
	mov	rax,15
	mov	rbx,160
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_23:
	mov	rax,16
	mov	rbx,168
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_24:
	mov	rax,17
	mov	rbx,176
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_25:
	mov	rax,18
	mov	rbx,184
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_26:
	mov	rax,19
	mov	rbx,192
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_27:
	mov	rax,20
	mov	rbx,200
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_28:
	mov	rax,21
	mov	rbx,208
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_29:
	mov	rax,22
	mov	rbx,216
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_30:
	mov	rax,23
	mov	rbx,224
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_31:
	mov	rax,24
	mov	rbx,232
	att_jmp	eval_upd_n

 .if PROFILE
	att_call	profile_n
	mov	rbp,rax
 .endif
eval_upd_32:
	mov	rax,25
	mov	rbx,240
	att_jmp	eval_upd_n

/* */
/*	STRINGS */
/* */

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

/* fill_node */

	mov	r8,rdi
	lea	rbp,__STRING__+2[rip]
	mov	qword ptr [rdi],rbp

/* store length */

	lea	rbp,[rax+rbx]
	mov	8[rdi],rbp 
	add	rdi,16

/* copy string 1 */

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

/* copy_string 2 */

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
	att_jne	cat_string_7
	
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
/* .align heap pointer */
	add	rdi,7
	and	rdi,-8
	ret

gc_3:	att_call	collect_2
	att_jmp	gc_r_3

empty_string:
	lea	rcx,zero_length_string[rip]
	ret

sliceAC:
	mov	rbp,8[rcx]
	test	rbx,rbx 
	jns	slice_string_1
	xor	rbx,rbx 
slice_string_1:
	cmp	rbx,rbp 
	att_jge	empty_string
	cmp	rax,rbx 
	att_jl	empty_string
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

	lea	rcx,__STRING__+2[rip]
	mov	qword ptr [rdi],rcx
	mov	8[rdi],rax 

/* copy part of string */
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
	att_call	collect_1
	lea	rbp,(16+7)[rax]
	shr	rbp,3
	att_jmp	r_gc_4

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
	lea	rcx,__STRING__+2[rip]
	mov	qword ptr [rdi],rcx
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

gc_5:	att_call	collect_1
	att_jmp	r_gc_5

update_string_error:
	lea	rbp,high_index_string[rip]
	test	rax,rax 
	jns	update_string_error_2
	lea	rbp,low_index_string[rip]
update_string_error_2:
	att_jmp	print_error

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
	att_jne	equal_string_ne
	add	rcx,8
	add	rdx,8
	dec	rax
	att_jne	equal_string_1
equal_string_d:
	test	bl,4
	je	equal_string_w
	mov	eax,dword ptr [rcx]
	cmp	eax,dword ptr [rdx]
	att_jne	equal_string_ne
	add	rcx,4
	add	rdx,4
equal_string_w:
	test	bl,2
	je	equal_string_b
	mov	ax,word ptr [rcx]
	cmp	ax,word ptr [rdx]
	att_jne	equal_string_ne
	add	rcx,2
	add	rdx,2
equal_string_b:
	test	bl,1
	je	equal_string_eq
	mov	bl,byte ptr [rcx]
	cmp	bl,byte ptr [rdx]
	att_jne	equal_string_ne
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
	att_jmp	cmp_string_chars
cmp_string_less:
	mov	rax,-1
	mov	rbx,rbp 
	att_jmp	cmp_string_chars

cmp_string_1:
	mov	rbp,[rdx]
	cmp	rbp,[rcx]
	jne	cmp_string_ne_q
	add	rdx,8
	add	rcx,8
cmp_string_chars:
	sub	rbx,8
	att_jnc	cmp_string_1
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
	att_jne	cmp_string_ne
	add	rdx,2
	add	rcx,2
cmp_string_b:
	test	bl,1
	je	cmp_string_eq
	mov	bl,byte ptr [rdx]
	cmp	bl,byte ptr [rcx]
	att_jne	cmp_string_ne
cmp_string_eq:
	ret
cmp_string_ne_d:
	mov	r10d,[rcx]
	bswap	ebp
	bswap	r10d
	cmp	ebp,r10d
	att_jmp	cmp_string_ne
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
	lea	rbp,__STRING__+2[rip]
	mov	qword ptr [rdi],rbp
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
	att_jge	string_to_string_node_2

	mov	rcx,rbp 
	ret

string_to_string_node_gc:
	push	rcx
	att_call	collect_0
	pop	rcx
	att_jmp	string_to_string_node_r


int_array_to_node:
	mov	rax,qword ptr -16[rcx]
	lea	rbx,3[rax]
	sub	r15,rbx
	jl	int_array_to_node_gc

int_array_to_node_r:
	lea	rbx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rbx
	mov	rdx,rcx
	mov	qword ptr 8[rdi],rax
	mov	rcx,rdi
	lea	rbx,dINT+2[rip]
	mov	qword ptr 16[rdi],rbx
	add	rdi,24
	jmp	int_or_real_array_to_node_4

int_or_real_array_to_node_2:
	mov	rbx,qword ptr [rdx]
	add	rdx,8
	mov	qword ptr [rdi],rbx
	add	rdi,8
int_or_real_array_to_node_4:
	sub	rax,1
	att_jge	int_or_real_array_to_node_2

	ret

int_array_to_node_gc:
	push	rcx
	att_call	collect_0
	pop	rcx
	att_jmp	int_array_to_node_r


real_array_to_node:
	mov	rax,qword ptr -16[rcx]
	lea	rbx,3[rax]
	sub	r15,rbx
	jl	real_array_to_node_gc

real_array_to_node_r:
	lea	rbx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rbx
	mov	rdx,rcx
	mov	qword ptr 8[rdi],rax
	mov	rcx,rdi
	lea	rbx,REAL+2[rip]
	mov	qword ptr 16[rdi],rbx
	add	rdi,24
	att_jmp	int_or_real_array_to_node_4

real_array_to_node_gc:
	push	rcx
	att_call	collect_0
	pop	rcx
	att_jmp	real_array_to_node_r


	.align	2
	.long	3
_c3:	att_jmp	__cycle__in__spine
	.align	2

	.long	4
_c4:	att_jmp	__cycle__in__spine
	.align	2
	.long	5
_c5:	att_jmp	__cycle__in__spine
	.align	2
	.long	6
_c6:	att_jmp	__cycle__in__spine
	.align	2
	.long	7
_c7:	att_jmp	__cycle__in__spine
	.align	2
	.long	8
_c8:	att_jmp	__cycle__in__spine
	.align	2
	.long	9
_c9:	att_jmp	__cycle__in__spine
	.align	2
	.long	10
_c10:	att_jmp	__cycle__in__spine
	.align	2
	.long	11
_c11:	att_jmp	__cycle__in__spine
	.align	2
	.long	12
_c12:	att_jmp	__cycle__in__spine
	.align	2
	.long	13
_c13:	att_jmp	__cycle__in__spine
	.align	2
	.long	14
_c14:	att_jmp	__cycle__in__spine
	.align	2
	.long	15
_c15:	att_jmp	__cycle__in__spine
	.align	2
	.long	16
_c16:	att_jmp	__cycle__in__spine
	.align	2
	.long	17
_c17:	att_jmp	__cycle__in__spine
	.align	2
	.long	18
_c18:	att_jmp	__cycle__in__spine
	.align	2
	.long	19
_c19:	att_jmp	__cycle__in__spine
	.align	2
	.long	20
_c20:	att_jmp	__cycle__in__spine
	.align	2
	.long	21
_c21:	att_jmp	__cycle__in__spine
	.align	2
	.long	22
_c22:	att_jmp	__cycle__in__spine
	.align	2
	.long	23
_c23:	att_jmp	__cycle__in__spine
	.align	2
	.long	24
_c24:	att_jmp	__cycle__in__spine
	.align	2
	.long	25
_c25:	att_jmp	__cycle__in__spine
	.align	2
	.long	26
_c26:	att_jmp	__cycle__in__spine
	.align	2
	.long	27
_c27:	att_jmp	__cycle__in__spine
	.align	2
	.long	28
_c28:	att_jmp	__cycle__in__spine
	.align	2
	.long	29
_c29:	att_jmp	__cycle__in__spine
	.align	2
	.long	30
_c30:	att_jmp	__cycle__in__spine
	.align	2
	.long	31
_c31:	att_jmp	__cycle__in__spine
	.align	2
	.long	32
_c32:	att_jmp	__cycle__in__spine

/* */
/*	ARRAYS */
/* */

_create_arrayB:
	mov	rbx,rax 
	add	rax,24+7
	shr	rax,3
	sub	r15,rax
	jge	no_collect_4574
	att_call	collect_0
no_collect_4574:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rbx 
	lea	rdx,BOOL+2[rip]
	mov	qword ptr 16[rdi],rdx
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayC:
	mov	rbx,rax
	add	rax,16+7
	shr	rax,3
	sub	r15,rax
	jge	no_collect_4573
	att_call	collect_0
no_collect_4573:
	mov	rcx,rdi 
	lea	rdx,__STRING__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rbx 
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayI:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4572
	att_call	collect_0
no_collect_4572:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax
	lea	rbp,dINT+2[rip]
	mov	qword ptr 16[rdi],rbp
	lea	rdi,24[rdi+rax*8]
	ret

_create_arrayI32:
	mov	rbx,rax
	add	rax,6+1
	shr	rax,1
	sub	r15,rax
	jge	no_collect_3572
	att_call	collect_0
no_collect_3572:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rbx
	lea	rdx,INT32+2[rip]
	mov	qword ptr 16[rdi],rdx
	lea	rdi,[rdi+rax*8]
	ret

_create_arrayR:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4580
	att_call	collect_0
no_collect_4580:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax
	lea	rdx,REAL+2[rip]
	mov	qword ptr 16[rdi],rdx
	lea	rdi,24[rdi+rax*8]
	ret

_create_arrayR32:
	mov	rbx,rax
	add	rax,6+1
	shr	rax,1
	sub	r15,rax
	jge	no_collect_3580
	att_call	collect_0
no_collect_3580:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax
	lea	rdx,REAL32+2[rip]
	mov	qword ptr 16[rdi],rdx
	lea	rdi,[rdi+rax*8]
	ret

/* rax : number of elements, rbx: element descriptor */
/* r10 : element size, r11 : element a size, rcx :a_element-> rcx : array */

_create_r_array:
	mov	rbp,rax
	imul	rbp,r10
	add	rbp,3
	sub	r15,rbp
	jge	no_collect_4586
	att_call	collect_1
no_collect_4586:
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
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
	att_jnc	_fillr1_array
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
	att_jnc	_fillr2_array
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
	att_jnc	_fillr3_array
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
	att_jnc	_fillr4_array
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
	att_jnc	_copy_elem_5_lp

	add	rdi,r10 
_st_fillr5_array:
	sub	rax,1
	att_jnc	_fillr5_array
	
	ret

create_arrayB:
	mov	r10,rbx
	add	rbx,24+7
	shr	rbx,3
	sub	r15,rbx
	jge	no_collect_4575
	att_call	collect_0
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
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],r10
	lea	rdx,BOOL+2[rip]
	mov	qword ptr 16[rdi],rdx
	add	rdi,24
	jmp	create_arrayBCI

create_arrayC:
	mov	r10,rbx
	add	rbx,16+7
	shr	rbx,3
	sub	r15,rbx
	jge	no_collect_4578
	att_call	collect_0
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
	lea	rdx,__STRING__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],r10
	add	rdi,16
	att_jmp	create_arrayBCI

create_arrayI32:
	mov	r10,rbx
	add	rbx,6+1
	shr	rbx,1
	sub	r15,rbx
	jge	no_collect_3577
	att_call	collect_0
no_collect_3577:
	mov	rcx,rdi 
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],r10
	lea	rdx,INT32+2[rip]
	mov	qword ptr 16[rdi],rdx
	add	rdi,24

	sub	rbx,3

	mov	ebp,eax
	shl	rax,32
	or	rax,rbp
	att_jmp	create_arrayBCI

create_arrayI:
	lea	rbp,3[rbx]
	sub	r15,rbp
	jge	no_collect_4577
	att_call	collect_0
no_collect_4577:
	mov	rcx,rdi 
	lea	rbp,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rbp
	mov	qword ptr 8[rdi],rbx 
	lea	rbp,dINT+2[rip]
	mov	qword ptr 16[rdi],rbp
	add	rdi,24
create_arrayBCI:
	mov	rdx,rbx
	shr	rbx,1
	test	dl,1
	je	st_filli_array

	mov	qword ptr [rdi],rax 
	add	rdi,8
	att_jmp	st_filli_array

filli_array:
	mov	qword ptr [rdi],rax 
	mov	qword ptr 8[rdi],rax 
	add	rdi,16
st_filli_array:
	sub	rbx,1
	att_jnc	filli_array

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
	att_call	collect_0
no_collect_3579:
	mov	rcx,rdi 
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],r10
	lea	rdx,REAL32+2[rip]
	mov	qword ptr 16[rdi],rdx
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
	att_call	collect_0
no_collect_4579:
	mov	rcx,rdi 
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax
	lea	rdx,REAL+2[rip]
	mov	qword ptr 16[rdi],rdx
	add	rdi,24
	att_jmp	st_fillr_array
fillr_array:
	mov	qword ptr [rdi],rbx 
	add	rdi,8
st_fillr_array:
	sub	rax,1
	att_jnc	fillr_array

	ret

create_array:
	lea	rbp,3[rax]
	sub	r15,rbp
	jge	no_collect_4576
	att_call	collect_1
no_collect_4576:
	mov	rbx,rcx 
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],0
	add	rdi,24

	jmp	fillr1_array




/* in rax: number of elements, rbx: element descriptor */
/* r10 : element size, r11 : element a size -> rcx : array */

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
	att_call	collect_0
no_collect_4581:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
	mov	qword ptr 8[rdi],rax 
	mov	qword ptr 16[rdi],rbx 
	add	rdi,24

	test	r11,r11
	je	r_array_1_b

	mov	rbx,qword ptr (-8)[rsi]
	att_jmp	fillr1_array

r_array_1_b:
	mov	rbx,qword ptr 8[rsp]

fillr1_array:
	mov	rdx,rax 
	shr	rax,1
	test	dl,1
	je	st_fillr1_array_1

	mov	qword ptr [rdi],rbx
	add	rdi,8
	att_jmp	st_fillr1_array_1

fillr1_array_lp:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],rbx 
	add	rdi,16
st_fillr1_array_1:
	sub	rax,1
	att_jnc	fillr1_array_lp

	ret

create_R_array_2:
	lea	rbp,3[rax*2]
	sub	r15,rbp
	jge	no_collect_4582
	att_call	collect_0
no_collect_4582:
	mov	rcx,rdi 
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
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
	att_jmp	st_fillr2_array
r_array_2_bb:
	mov	rbx,qword ptr 8[rsp]
	mov	rbp,qword ptr 16[rsp]
	att_jmp	st_fillr2_array

fillr2_array_1:
	mov	qword ptr [rdi],rbx 
	mov	qword ptr 8[rdi],rbp 
	add	rdi,16
st_fillr2_array:
	sub	rax,1
	att_jnc	fillr2_array_1

	ret

create_R_array_3:
	lea	rbp,3[rax+rax*2]
	sub	r15,rbp
	jge	no_collect_4583
	att_call	collect_0
no_collect_4583:
	mov	rcx,rdi
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
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
	att_jnc	copy_a_to_b_lp3

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
	att_jnc	fillr3_array_1

	ret

create_R_array_4:
	lea	rbp,3[rax*4]
	sub	r15,rbp
	jge	no_collect_4584
	att_call	collect_0
no_collect_4584:
	mov	rcx,rdi 
	lea	rdx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rdx
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
	att_jnc	copy_a_to_b_lp4

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
	att_jnc	fillr4_array

	ret

create_R_array_5:
	lea	r12,4[r10]
	mov	rbp,rax
	imul	rbp,r12
	add	rbp,3
	sub	r15,rbp
	jge	no_collect_4585
	att_call	collect_0
no_collect_4585:
	lea	rcx,__ARRAY__+2[rip]
	mov	qword ptr [rdi],rcx
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
	att_jnc	copy_a_to_b_lp5

r_array_5:
	mov	r13,qword ptr [rsp]
	mov	r14,qword ptr 8[rsp]

	lea	rbx,32[rsp+r10*8]

	mov	r8,qword ptr 16[rsp]
	mov	r10,qword ptr 24[rsp]
	add	rsp,32
	jmp	st_fillr5_array

fillr5_array_1:
	mov	qword ptr [rdi],r13 
	mov	qword ptr 8[rdi],r14

	mov	r11,rsp

	mov	qword ptr 16[rdi],r8
	mov	qword ptr 24[rdi],r10
	add	rdi,32

copy_elem_lp5:
	mov	rbp,qword ptr [r11]
	add	r11,8
	mov	qword ptr [rdi],rbp 
	add	rdi,8
	cmp	r11,rbx
	att_jne	copy_elem_lp5

st_fillr5_array:
	sub	rax,1
	att_jnc	fillr5_array_1

	mov	rsp,r12
	jmp	rdx 

 .if ! NEW_DESCRIPTORS
yet_args_needed:
/* for more than 4 arguments */
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
 .endif

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
	att_jmp	repl_args_b_4

repl_args_b_2:
	lea	rdx,[rdx+rax*8]

repl_args_b_3:
	mov	rbp,(-8)[rdx]
	sub	rdx,8
	mov	[rsi],rbp 
	add	rsi,8
	dec	rax 
	att_jne	repl_args_b_3

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
	att_je	push_arg_b_1
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
	att_jg	del_args_copy_args

	ret

del_args_gc:
	att_call	collect_2
	att_jmp	del_args_r_gc

 .if USE_LIBM
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
 .endif
	
entier_real:
	cvttsd2si rax,xmm0
	ucomisd	xmm0,qword ptr real_0_0[rip]
	jb	entier_real_m
	ret

entier_real_m:
	movsd	qword ptr (-8)[rsp],xmm0
	mov	rcx,qword ptr (-8)[rsp]
	mov	rbx,rcx
	shr rcx,52
	cmp rcx,0x0bff
	jb	entier_real_m_small
	cmp	rcx,0x0bff+52
	jae	entier_real_m_large
	sub	rcx,0x0bff-12
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

	.globl	getheapend

getheapend:
	lea	rbx,[rdi+r15*8]
	mov	rax,heap_end_after_gc_offset[r9]
	ret

	.include	"areals.s"

 .if PROFILE
  .if TRACE
	.include	"atrace.s"
  .else
	.include	"aprofile.s"
  .endif
 .endif

 .if NEW_DESCRIPTORS
	.include	"aap.s"
 .endif

	.include	"athread.s"

