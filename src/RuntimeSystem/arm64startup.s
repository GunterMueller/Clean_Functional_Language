#
#	File:	 arm64startup.s
#	Author:	 John van Groningen
#	Machine: AArch64

# B stack registers:     x6 x5 x4 x3 x2 x1 x0
# A stack registers:     x8 x9 x10 x11 x12 x13 x14 x15
# scratch registers      x16 (ip) x17 (fp)
# n free heap words:     x25
# A stack pointer:       x26
# heap pointer:          x27
# B stack pointer:       x28
# link/scratch register: x30
# descriptor registers:  x20 x21 x22 x23 x24

USE_CLIB = 1

SHARE_CHAR_INT = 1
MY_ITOS = 1
FINALIZERS = 1
STACK_OVERFLOW_EXCEPTION_HANDLER = 0
WRITE_HEAP = 0

# DEBUG = 0
PREFETCH2 = 0

NO_BIT_INSTRUCTIONS = 1
ADJUST_HEAP_SIZE = 1
MARK_GC = 1
MARK_AND_COPY_GC = 1

NEW_DESCRIPTORS = 1

# #define PROFILE

COMPACT_GC_ONLY = 0

MINIMUM_HEAP_SIZE = 8000
MINIMUM_HEAP_SIZE_2 = 4000

.ifdef LINUX
# define section(n) .section    .text.n,"ax"
.else
# define section(n) .text
.endif

DESCRIPTOR_ARITY_OFFSET	= (-2)
ZERO_ARITY_DESCRIPTOR_OFFSET = (-4)

	.hidden	semi_space_size
	.comm	semi_space_size,8,8

	.hidden	heap_mbp
	.comm	heap_mbp,8,8
	.hidden	stack_mbp
	.comm	stack_mbp,8,8
	.hidden	heap_p
	.comm	heap_p,8,8
	.hidden	heap_p1
	.comm	heap_p1,8,8
	.hidden	heap_p2
	.comm	heap_p2,8,8
	.hidden	heap_p3
	.comm	heap_p3,8,8
	.hidden	end_heap_p3
	.comm	end_heap_p3,8,8
	.hidden	heap_size_65
	.comm	heap_size_65,8,8
	.hidden	vector_p
	.comm	vector_p,8,8
	.hidden	vector_counter
	.comm	vector_counter,8,8
	.hidden	neg_heap_vector_plus_4
	.comm	neg_heap_vector_plus_4,8,8

	.hidden	heap_vector
	.comm	heap_vector,8,8
	.hidden stack_top
	.comm	stack_top,8,8

	.hidden	heap_size_257
	.comm	heap_size_257,8,8
	.hidden	heap_copied_vector
	.comm	heap_copied_vector,8,8
	.hidden	heap_copied_vector_size
	.comm	heap_copied_vector_size,8,8
	.hidden	heap_end_after_copy_gc
	.comm	heap_end_after_copy_gc,8,8

	.hidden	heap_end_after_gc
	.comm	heap_end_after_gc,8,8
	.hidden	extra_heap
	.comm	extra_heap,8,8
	.hidden	extra_heap_size
	.comm	extra_heap_size,8,8
	.hidden	stack_p
	.comm	stack_p,8,8
	.hidden	halt_sp
	.comm	halt_sp,8

	.hidden	n_allocated_words
	.comm	n_allocated_words,8,8
	.hidden	basic_only
	.comm	basic_only,8,8

	.hidden	last_time
	.comm	last_time,8,8
	.hidden	execute_time
	.comm	execute_time,8,8
	.hidden	garbage_collect_time
	.comm	garbage_collect_time,8,8
	.hidden	IO_time
	.comm	IO_time,8,8

	.globl	saved_heap_p
	.hidden	saved_heap_p
	.comm	saved_heap_p,8,8

	.globl	saved_a_stack_p
	.hidden	saved_a_stack_p
	.comm	saved_a_stack_p,8,8

	.globl	end_a_stack
	.hidden	end_a_stack
	.comm	end_a_stack,8,8

	.globl	end_b_stack
	.hidden	end_b_stack
	.comm	end_b_stack,8,8

	.hidden	dll_initisialised
	.comm	dll_initisialised,8,8

.if WRITE_HEAP
	.comm	heap_end_write_heap,8,8
	.comm	d3_flag_write_heap,8,8
	.comm	heap2_begin_and_end,16,8
.endif

.if STACK_OVERFLOW_EXCEPTION_HANDLER
	.comm	a_stack_guard_page,8,8
.endif

	.globl	profile_stack_pointer
	.hidden	profile_stack_pointer
	.comm	profile_stack_pointer,8,8

	.data
	.p2align	3

.if MARK_GC
bit_counter:
	.quad	0
bit_vector_p:
	.quad	0
zero_bits_before_mark:
	.quad	1
n_free_words_after_mark:
	.quad	1000
n_last_heap_free_bytes:
	.quad	0
lazy_array_list:
	.quad	0
n_marked_words:
	.quad	0
end_stack:
	.quad	0
 .if ADJUST_HEAP_SIZE
bit_vector_size:
	.quad	0
 .endif
.endif

caf_list:
	.quad	0
	.globl	caf_listp
	.hidden	caf_listp
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
garbage_collect_flag:
	.byte	0
	.byte	0,0,0

	.hidden	sprintf_buffer
	.comm	sprintf_buffer,32,8

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
	.asciz	"A stack: "
garbage_collect_string_2:
	.asciz	" bytes. BC stack: "
garbage_collect_string_3:
	.ascii	" bytes."
	.byte	10,0
heap_use_after_gc_string_1:
	.ascii	"Heap use after garbage collection: "
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

.if MARK_GC
marked_gc_string_1:
	.ascii	"Marked: "
	.byte	0
.endif
.ifdef PROFILE
	.p2align	2
  .ifdef LINUX
	.globl	m_system
  .endif
m_system:
	.long	6
	.ascii	"System"
	.byte	0
	.byte	0

	.p2align	3
garbage_collector_name:
	.quad	0
	.long	m_system
	.asciz	"garbage_collector"
	.p2align	2
.endif

.ifdef DLL
start_address:
	.long	0
.endif
	.p2align	2
	.hidden	sprintf_time_buffer
	.comm	sprintf_time_buffer,20

	.p2align	2
.if SHARE_CHAR_INT
	.globl	small_integers
	.hidden	small_integers
	.comm	small_integers,33*16,8
	.globl	static_characters
	.hidden	static_characters
	.comm	static_characters,256*16,8
.endif

.ifdef SHARED_LIBRARY
	.section .init_array
	.long   clean_init

	.section .fini_array
	.long   clean_fini
.endif

	.text

	.globl	abc_main
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
	.globl	repl_r_a_args_n_a
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
	.globl	_create_arrayR
	.globl	_create_arrayI32
	.globl	_create_arrayR32
	.globl	_create_r_array
	.globl	create_array
	.globl	create_arrayB
	.globl	create_arrayC
	.globl	create_arrayI
	.globl	create_arrayR
	.globl	create_arrayI32
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
 
	.globl	_c3,_c4,_c5,_c6,_c7,_c8,_c9,_c10,_c11,_c12
	.hidden	_c3,_c4,_c5,_c6,_c7,_c8,_c9,_c10,_c11,_c12
	.globl	_c13,_c14,_c15,_c16,_c17,_c18,_c19,_c20,_c21,_c22
	.hidden	_c13,_c14,_c15,_c16,_c17,_c18,_c19,_c20,_c21,_c22
	.globl	_c23,_c24,_c25,_c26,_c27,_c28,_c29,_c30,_c31,_c32
	.hidden	_c23,_c24,_c25,_c26,_c27,_c28,_c29,_c30,_c31,_c32

	.globl	e__system__eaind
	.hidden	e__system__eaind
	.globl	e__system__nind
	.hidden	e__system__nind
# old name of the previous label for compatibility, remove later
	.globl	__indirection
	.hidden	__indirection
	.globl	e__system__dind
	.hidden	e__system__dind
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
	.globl	IO_error
	.globl	stack_overflow

	.globl	out_of_memory_4
	.globl	print_error
.ifndef DLL
	.global	_start
.endif
	.globl	sin_real
	.globl	cos_real
	.globl	tan_real
	.globl	asin_real
	.globl	acos_real
	.globl	atan_real
	.globl	ln_real
	.globl	log10_real
	.globl	exp_real
	.globl	pow_real
	.globl	r_to_i_real
	.globl	entier_real

.ifdef PROFILE
	.globl	init_profiler
	.globl	profile_s,profile_n,profile_r,profile_t
	.globl	write_profile_stack
 .ifndef TRACE
	.globl	write_profile_information
 .endif
.endif
	.globl	__driver

# from system.abc:	
	.globl	INT
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

# from wcon.c:
	.globl	w_print_char
	.globl	w_print_string
	.globl	w_print_text
	.globl	w_print_int
	.globl	w_print_real

	.globl	ew_print_char
	.globl	ew_print_text
	.globl	ew_print_string
	.globl	ew_print_int

	.globl	ab_stack_size
	.globl	heap_size
	.globl	flags

# from standard c library:
	.globl	malloc
	.globl	free
	.globl	sprintf
	.globl	strlen

.if STACK_OVERFLOW_EXCEPTION_HANDLER
	.globl	allocate_memory_with_guard_page_at_end
.endif
.if ADJUST_HEAP_SIZE
	.global	heap_size_multiple
	.global	initial_heap_size
.endif
.if WRITE_HEAP
	.global	min_write_heap_size
.endif
.if FINALIZERS
	.global	__Nil
	.globl	finalizer_list
	.hidden	finalizer_list
	.comm	finalizer_list,8,8
	.globl	free_finalizer_list
	.hidden	free_finalizer_list
	.comm	free_finalizer_list,8,8
.endif

abc_main:
	str	x30,[sp,#-16]!

	stp	x19,x20,[sp,#-80]!
	adrp	x20,BOOL+2
	add	x20,x20,#:lo12:BOOL+2
	stp	x21,x22,[sp,#16]
	adrp	x21,CHAR+2
	add	x21,x21,#:lo12:CHAR+2
	adrp	x22,INT+2
	add	x22,x22,#:lo12:INT+2
	stp	x23,x24,[sp,#32]
	adrp	x23,REAL+2
	add	x23,x23,#:lo12:REAL+2
	adrp	x24,__cycle__in__spine
	add	x24,x24,#:lo12:__cycle__in__spine
	stp	x25,x26,[sp,#48]
	stp	x27,x28,[sp,#64]


.ifdef DLL
	ldr	x4,[sp,#28]
	adrp	x16,start_address
	str	x4,[x16,#:lo12:start_address]
.endif
	bl	init_clean
	cbnz	x0,init_error

	bl	init_timer

	mov	x3,sp
	adrp	x16,halt_sp
	str	x3,[x16,#:lo12:halt_sp]

.ifdef PROFILE
	str	x30,[x28,#-8]!
	bl	init_profiler
.endif

.ifdef DLL
	adrp	x16,start_address
	ldr	x4,[x16,#:lo12:start_address]
	str	x30,[x28,#-8]!
	br	x4
.else
	str	x30,[x28,#-8]!
	bl	__start
.endif

exit:
	bl	exit_clean

init_error:
	ldp	x19,x20,[sp]
	ldp	x21,x22,[sp,#16]
	ldp	x23,x24,[sp,#32]
	ldp	x25,x26,[sp,#48]
	ldp	x27,x28,[sp,#64]
	add	sp,sp,#80

	ldr	x30,[sp],#16
	ret	x30
	
	.globl	clean_init
clean_init:
	str	x30,[sp,#-16]!

	stp	x19,x20,[sp,#-80]!
	adrp	x20,BOOL+2
	add	x20,x20,#:lo12:BOOL+2
	stp	x21,x22,[sp,#16]
	adrp	x21,CHAR+2
	add	x21,x21,#:lo12:CHAR+2
	adrp	x22,INT+2
	add	x22,x22,#:lo12:INT+2
	stp	x23,x24,[sp,#32]
	adrp	x23,REAL+2
	add	x23,x23,#:lo12:REAL+2
	adrp	x24,__cycle__in__spine
	add	x24,x24,#:lo12:__cycle__in__spine
	stp	x25,x26,[sp,#48]
	stp	x27,x28,[sp,#64]

	adrp	x16,dll_initisialised
	mov	x0,#1
	str	x0,[x16,#:lo12:dll_initisialised]

	bl	init_clean
	cbnz	x0,init_dll_error

	bl	init_timer

	mov	x3,sp
	adrp	x16,halt_sp
	str	x3,[x16,#:lo12:halt_sp]

 .ifdef PROFILE
	str	x30,[x28,#-8]!
	bl	init_profiler
 .endif

	adrp	x16,saved_heap_p
	add	x16,x16,#:lo12:saved_heap_p
	str	x27,[x16]
	str	x25,[x16,#8]
	adrp	x16,saved_a_stack_p
	str	x26,[x16,#:lo12:saved_a_stack_p]

	mov	x4,#1
	b	exit_dll_init

init_dll_error:
	mov	x4,#0
	b	exit_dll_init

	.globl	clean_fini
clean_fini:
	str	x30,[sp,#-16]!

	stp	x27,x11,[sp,#-16]
	stp	x10,x26,[sp,#-32]
	stp	x8,x9,[sp,#-48]
	stp	x4,x25,[sp,#-64]!

	adrp	x16,saved_heap_p
	add	x16,x16,#:lo12:saved_heap_p
	ldr	x27,[x16]
	ldr	x25,[x16,#4]
	adrp	x16,saved_a_stack_p
	ldr	x26,[x16,#:lo12:saved_a_stack_p]

	str	x30,[sp,#-16]!
	bl	exit_clean

exit_dll_init:
	ldp	x8,x9,[sp,#16]
	ldp	x10,x26,[sp,#32]
	ldp	x27,x11,[sp,#48]
	ldr	x30,[sp,#64]
	ldp	x4,x25,[sp],#80
	ret	x30

init_clean:
	str	x30,[sp,#-16]!

	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]

	add	x0,x16,#7
	bl	malloc

	cbz	x0,no_memory_1

	adrp	x16,end_b_stack
	str	x0,[x16,#:lo12:end_b_stack]
	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]
	and	x16,x16,#-8

	add	x28,x0,x16

	adrp	x4,flags
	ldr	x4,[x4,#:lo12:flags]
	and	x4,x4,#1
	adrp	x16,basic_only
	str	x4,[x16,#:lo12:basic_only]

	adrp	x4,heap_size
	ldr	x4,[x4,#:lo12:heap_size]
.if PREFETCH2
	sub	x4,x4,#63
.else
	sub	x4,x4,#7
.endif
	mov	x16,#65
	udiv	x4,x4,x16
	adrp	x16,heap_size_65
	str	x4,[x16,#:lo12:heap_size_65]

	adrp	x4,heap_size
	ldr	x4,[x4,#:lo12:heap_size]
	subs	x4,x4,#7
	mov	x16,#257
	udiv	x4,x4,x16
	adrp	x16,heap_size_257
	str	x4,[x16,#:lo12:heap_size_257]
	add	x4,x4,#7
	and	x4,x4,#-8
	adrp	x16,heap_copied_vector_size
	str	x4,[x16,#:lo12:heap_copied_vector_size]
	adrp	x16,heap_end_after_copy_gc
	mov	x17,#0
	str	x17,[x16,#:lo12:heap_end_after_copy_gc]

	adrp	x16,heap_size
	ldr	x4,[x16,#:lo12:heap_size]
	add	x4,x4,#7
	and	x4,x4,#-8
	str	x4,[x16,#:lo12:heap_size]

	add	x0,x4,#7
	bl	malloc
	cbz	x0,no_memory_2

	adrp	x16,heap_mbp
	str	x0,[x16,#:lo12:heap_mbp]
	add	x27,x0,#7
	and	x27,x27,#-8
	adrp	x16,heap_p
	str	x27,[x16,#:lo12:heap_p]

	adrp	x10,ab_stack_size
	ldr	x10,[x10,#:lo12:ab_stack_size]
	add	x10,x10,#7

	mov	x0,x10
.if STACK_OVERFLOW_EXCEPTION_HANDLER
	bl	allocate_memory_with_guard_page_at_end
.else
	bl	malloc
.endif

	mov	x4,x0
	cbz	x0,no_memory_3

	adrp	x16,stack_mbp
	str	x4,[x16,#:lo12:stack_mbp]
.if STACK_OVERFLOW_EXCEPTION_HANDLER
	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]
	add	x4,x4,x16
	adrp	x16,a_stack_guard_page
	add	x4,x4,#4096
	add	x4,x4,#(3+4095)-4096
	bic	x4,x4,#255
	bic	x4,x4,#4095-255
	str	x4,[x16,#:lo12:a_stack_guard_page]
	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]
	sub	x4,x4,x16
.endif
	add	x4,x4,#3
	and	x4,x4,#-4

	mov	x26,x4
	adrp	x16,stack_p
	str	x4,[x16,#:lo12:stack_p]

	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]
	add	x4,x4,x16
	subs	x4,x4,#64
	adrp	x16,end_a_stack
	str	x4,[x16,#:lo12:end_a_stack]

.if SHARE_CHAR_INT
	adrp	x8,small_integers
	add	x8,x8,#:lo12:small_integers
	mov	x4,#0
	adrp	x3,INT+2
	add	x3,x3,#:lo12:INT+2

make_small_integers_lp:
	stp	x3,x4,[x8],#16
	add	x4,x4,#1
	cmp	x4,#33
	bne	make_small_integers_lp

	adrp	x8,static_characters
	add	x8,x8,#:lo12:static_characters
	mov	x4,#0
	adrp	x3,CHAR+2
	add	x3,x3,#:lo12:CHAR+2

make_static_characters_lp:
	stp	x3,x4,[x8],#16
	add	x4,x4,#1
	cmp	x4,#256
	bne	make_static_characters_lp
.endif

	adrp	x8,caf_list+8
	add	x8,x8,#:lo12:caf_list+8
	adrp	x16,caf_listp
	str	x8,[x16,#:lo12:caf_listp]

.if FINALIZERS
	adrp	x17,__Nil-8
	add	x17,x17,#:lo12:__Nil-8
	adrp	x16,finalizer_list
	str	x17,[x16,#:lo12:finalizer_list]
	adrp	x16,free_finalizer_list
	str	x17,[x16,#:lo12:free_finalizer_list]
.endif

	adrp	x16,heap_p1
	str	x27,[x16,#:lo12:heap_p1]

	adrp	x10,heap_size_257
	ldr	x10,[x10,#:lo12:heap_size_257]
	lsl	x10,x10,#4
	add	x4,x27,x10,lsl #3
	adrp	x16,heap_copied_vector
	str	x4,[x16,#:lo12:heap_copied_vector]
	adrp	x16,heap_copied_vector_size
	ldr	x16,[x16,#:lo12:heap_copied_vector_size]
	add	x4,x4,x16
	adrp	x16,heap_p2
	str	x4,[x16,#:lo12:heap_p2]

	mov	x17,#0
	adrp	x16,garbage_collect_flag
	strb	w17,[x16,#:lo12:garbage_collect_flag]

 .if MARK_AND_COPY_GC
 	adrp	x16,flags
 	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark1 // 64
 .endif

 .if MARK_GC || COMPACT_GC_ONLY
	adrp	x4,heap_size_65
	ldr	x4,[x4,#:lo12:heap_size_65]
	adrp	x16,heap_vector
	str	x27,[x16,#:lo12:heap_vector]
	add	x27,x27,x4
  .if PREFETCH2
	add	x27,x27,#63
	and	x27,x27,#-64
  .else
	add	x27,x27,#7
	and	x27,x27,#-8
  .endif
	adrp	x16,heap_p3
	str	x27,[x16,#:lo12:heap_p3]
	lsl	x10,x4,#3
	mov	x17,#-1
	adrp	x16,garbage_collect_flag
	strb	w17,[x16,#:lo12:garbage_collect_flag]
 .endif

 .if MARK_AND_COPY_GC
no_mark1:
 .endif

 .if ADJUST_HEAP_SIZE
 	adrp	x4,initial_heap_size
 	ldr	x4,[x4,#:lo12:initial_heap_size]
  .if MARK_AND_COPY_GC
	mov	x3,#MINIMUM_HEAP_SIZE_2
	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tst	x16,#64
	bne	no_mark9
	add	x3,x3,x3
no_mark9:
  .else
   .if MARK_GC || COMPACT_GC_ONLY
	mov	x3,#MINIMUM_HEAP_SIZE
   .else
	mov	x3,#MINIMUM_HEAP_SIZE_2
   .endif
  .endif

	cmp	x4,x3
	ble	too_large_or_too_small
	lsr	x4,x4,#3
	cmp	x4,x10
	bge	too_large_or_too_small
	mov	x10,x4
too_large_or_too_small:
 .endif

	add	x4,x27,x10,lsl #3
	adrp	x16,heap_end_after_gc
	str	x4,[x16,#:lo12:heap_end_after_gc]

	mov	x25,x10

 .if MARK_AND_COPY_GC
 	adrp	x16,flags
 	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark2 // 64
 .endif

 .if MARK_GC && ADJUST_HEAP_SIZE
	adrp	x16,bit_vector_size
	str	x10,[x16,#:lo12:bit_vector_size]
 .endif

 .if MARK_AND_COPY_GC
no_mark2:
 .endif

	ldr	x30,[sp],#16
	mov	x0,#0
	ret	x30

no_memory_3:
	adrp	x0,heap_mbp
	ldr	x0,[x0,#:lo12:heap_mbp]
	bl	free

no_memory_2:
	adrp	x0,end_b_stack
	ldr	x0,[x0,#:lo12:end_b_stack]
	bl	free

no_memory_1:
	adrp	x0,out_of_memory_string_1
	add	x0,x0,#:lo12:out_of_memory_string_1
	bl	ew_print_string

.ifdef _WINDOWS_
?	movl	$1,@execution_aborted
.endif

	ldr	x30,[sp],#16
	mov	x0,#1
	ret	x30

exit_clean:
	str	x30,[sp,#-16]!
	bl	add_execute_time

	adrp	x4,flags
	ldr	x4,[x4,#:lo12:flags]
	tst	x4,#8
	beq	no_print_execution_time

	adrp	x0,time_string_1
	add	x0,x0,#:lo12:time_string_1
	bl	ew_print_string

	adrp	x16,execute_time
	ldr	x4,[x16,#:lo12:execute_time]
	bl	print_time

	adrp	x0,time_string_2
	add	x0,x0,#:lo12:time_string_2
	bl	ew_print_string

	adrp	x16,garbage_collect_time
	ldr	x4,[x16,#:lo12:garbage_collect_time]
	bl	print_time

	adrp	x0,time_string_4
	add	x0,x0,#:lo12:time_string_4
	bl	ew_print_string

	adrp	x4,execute_time
	ldr	x4,[x4,#:lo12:execute_time]
	adrp	x16,garbage_collect_time
	ldr	x16,[x16,#:lo12:garbage_collect_time]
	add	x4,x4,x16
	adrp	x16,IO_time
	ldr	x16,[x16,#:lo12:IO_time]
	add	x4,x4,x16

	bl	print_time

	mov	x0,#10
	bl	ew_print_char

no_print_execution_time:
	adrp	x0,stack_mbp
	ldr	x0,[x0,#:lo12:stack_mbp]
	bl	free

	adrp	x0,heap_mbp
	ldr	x0,[x0,#:lo12:heap_mbp]
	bl	free

.ifdef PROFILE
 .ifndef TRACE
	str	x30,[x28,#-8]!
	bl	write_profile_information
 .endif
.endif

	ldr	x30,[sp],#16
	ret	x30

__driver:
	adrp	x10,flags
	ldr	x10,[x10,#:lo12:flags]
	tst	x10,#16
	beq	__print__graph
	b	__eval__to__nf

	.ltorg

print_time:
	str	x30,[sp,#-16]!

#	divide by 1000
	ldr	x16,=2361183241434822607
	lsr	x8,x4,#3
	umulh	x8,x16,x8
	lsr	x8,x8,#4

	mov	x17,#1000
	msub	x4,x8,x17,x4

#	divide by 10
	ldr	x16,=-3689348814741910323
	umulh	x4,x16,x4
	lsr	x4,x4,#3

.if USE_CLIB
	mov	x3,x4
	mov	x2,x8
	adrp	x1,sprintf_time_string
	add	x1,x1,#:lo12:sprintf_time_string
	adrp	x0,sprintf_time_buffer
	add	x0,x0,sprintf_time_buffer
	bl	sprintf

	adrp	x0,sprintf_time_buffer
	add	x0,x0,sprintf_time_buffer
	bl	ew_print_string
.else
	mov	x0,x8
	bl	ew_print_int

	adrp	x8,sprintf_time_buffer
	add	x8,x8,#:lo12:sprintf_time_buffer

	mov	x9,#0
	mov	x3,#10

	mov	x16,#46
	strb	w16,[x8]

#	divide by 10
	ldr	x16,=-3689348814741910323
	umulh	x0,x16,x4
	lsr	x0,x0,#3

	sub	x4,x4,x0,lsl #1
	sub	x4,x4,x0,lsl #3

	add	x4,x4,#48
	add	x9,x9,#48
	strb	w0,[x8,#1]
	strb	w4,[x8,#2]

	mov	x1,#3
	mov	x0,x8
	bl	ew_print_text
.endif
	ldr	x30,[sp],#16
	ret	x30

print_sc:
	adrp	x16,basic_only
	ldr	x10,[x16,#:lo12:basic_only]
	cmp	x10,#0
	bne	end_print

print:
	mov	x0,x6
	mov	x29,x30
	bl	w_print_string
	ldr	x30,[x28],#8
	ret	x29

end_print:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

dump:
	str	x30,[x28,#-8]!
	bl	print
	b	halt

printD:	tst	x6,#2
	bne	printD_

	mov	x10,x6
	b	print_string_a2

DtoAC_record:
	ldr	w10,[x6,#-6]
#.ifdef PIC
.if 0
	add	x16,x6,#-6
	add	x10,x10,x16
.endif
	b	DtoAC_string_a2

DtoAC:	tst	x6,#2
	bne	DtoAC_

	mov	x10,x6
	b	DtoAC_string_a2

DtoAC_:
	ldrh	w16,[x6,#-2]
	cmp	x16,#256
	bhs	DtoAC_record

  	ldrh	w3,[x6]
  	add	x16,x6,#10
  	add	x10,x16,x3

DtoAC_string_a2:
	ldr	w6,[x10]
	add	x8,x10,#4
	b	build_string

print_symbol:
	mov	x3,#0
	b	print_symbol_2

print_symbol_sc:
	adrp	x16,basic_only
	ldr	x3,[x16,#:lo12:basic_only]
print_symbol_2:
	ldr	x6,[x8]

	adrp	x16,INT+2
	add	x16,x16,#:lo12:INT+2
	cmp	x6,x16
	beq	print_int_node

	adrp	x16,CHAR+2
	add	x16,x16,#:lo12:CHAR+2
	cmp	x6,x16
	beq	print_char_denotation

	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2
	cmp	x6,x16
	beq	print_bool

	adrp	x16,REAL+2
	add	x16,x16,#:lo12:REAL+2
	cmp	x6,x16
	beq	print_real_node

	cmp	x3,#0
	bne	end_print_symbol

printD_:
	ldrh	w16,[x6,#-2]
	cmp	x16,#256
	bhs	print_record

  	ldrh	w3,[x6]
  	add	x16,x6,#10
  	add	x10,x16,x3
	b	print_string_a2

print_record:
	ldr	w10,[x6,#-6]
#.ifdef PIC
.if 0
	add	x16,x6,#-6
	add	x10,x10,x16
.endif
	b	print_string_a2

end_print_symbol:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

print_int_node:
	ldr	x0,[x8,#8]

	str	x30,[x28,#-8]!
	bl	w_print_int
	ldr	x30,[x28],#8

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

print_int:
	mov	x0,x6

	str	x30,[x28,#-8]!
	bl	w_print_int
	ldr	x30,[x28],#8

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

print_char_denotation:
	cbnz	x3,print_char_node

	mov	x29,x30

	ldr	x16,[x8,#8]
	str	x16,[x28,#-8]!

	mov	x0,#0x27
	bl	w_print_char

	ldr	x0,[x28],#8
	bl	w_print_char

	mov	x0,#0x27
	bl	w_print_char

	ldr	x30,[x28],#8
	ret	x29

print_char_node:
	mov	x29,x30

	ldr	x0,[x8,#8]
	bl	w_print_char

	ldr	x30,[x28],#8
	ret	x29

print_char:
	mov	x0,x6

	str	x30,[x28,#-8]
	bl	w_print_char
	ldr	x30,[x28],#8

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

print_bool:
	ldrsb	x8,[x8,#8]
	tst	x8,x8
	beq	print_false

print_true:
	adrp	x0,true_c_string
	add	x0,x0,#:lo12:true_c_string
	mov	x29,x30
	bl	w_print_string
	ldr	x30,[x28],#8
	ret	x29

print_false:
	adrp	x0,false_c_string
	add	x0,x0,#:lo12:false_c_string
	mov	x29,x30
	bl	w_print_string
	ldr	x30,[x28],#8
	ret	x29

print_real:
	b	print_real_
print_real_node:
	ldr	d0,[x8,#8]
print_real_:
	mov	x19,sp
	and	sp,x19,#-16
	mov	x29,x30
	bl	w_print_real
	mov	sp,x19
	ldr	x30,[x28],#8
	ret	x29

print_string_a2:
	ldr	w1,[x10]
	add	x0,x10,#4
	mov	x29,x30
	bl	w_print_text
	ldr	x30,[x28],#8
	ret	x29

print__chars__sc:
	adrp	x16,basic_only
	ldr	x10,[x16,#:lo12:basic_only]
	cbnz	x10,no_print_chars

print__string__:
	ldr	x1,[x8,#8]
	add	x0,x8,#16
	mov	x29,x30
	bl	w_print_text
	ldr	x30,[x28],#8
	ret	x29

no_print_chars:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

push_a_r_args:
	str	x27,[x28,#-8]!

	ldr	x9,[x8,#8]
	subs	x9,x9,#2
	ldrh	w27,[x9]
	sub	x27,x27,#256
	ldrh	w3,[x9,#2]
	add	x9,x9,#4
	str	x9,[x28,#-8]!

	sub	x9,x27,x3

	lsl	x6,x6,#2
	add	x16,x8,#12
	add	x8,x16,x3,lsl #2
	subs	x27,x27,#1
mul_array_size_lp:
	add	x8,x8,x6
	subs	x27,x27,#1
	bcs	mul_array_size_lp

	add	x27,x8,x9,lsl #2
	b	push_a_elements
push_a_elements_lp:
	ldr	x6,[x8,#-8]!
	str	x6,[x26],#8
push_a_elements:
	subs	x3,x3,#1
	bcs	push_a_elements_lp

	mov	x8,x27
	ldr	x6,[x28],#8
	ldr	x27,[x28],#8

	mov	x29,x30
	ldr	x30,[x28],#8
	b	push_b_elements
push_b_elements_lp:
	ldr	x16,[x8,#-8]!
	str	x16,[x28,#-8]!
push_b_elements:
	subs	x9,x9,#1
	bcs	push_b_elements_lp

	ret	x29

push_t_r_args:
	ldr	x6,[x8],#8

	mov	x29,x30
	ldr	x30,[x28],#8

	sub	x6,x6,#2
	ldrh	w5,[x6]
	sub	x5,x5,#256
	ldrh	w3,[x6,#2]
	add	x6,x6,#4

	sub	x4,x5,x3

	add	x9,x8,x5,lsl #3
	cmp	x5,#2
	bls	small_record
	ldr	x9,[x8,#8]
	add	x16,x9,#-8
	add	x9,x16,x5,lsl #3
small_record:

	b	push_r_b_elements
push_r_b_elements_lp:
	subs	x5,x5,#1
	bne	not_first_arg_b

	ldr	x16,[x8]
	str	x16,[x28,#-8]!
	b	push_r_b_elements
not_first_arg_b:
	ldr	x16,[x9,#-8]!
	str	x16,[x28,#-8]!
push_r_b_elements:
	subs	x4,x4,#1
	bcs	push_r_b_elements_lp

	b	push_r_a_elements
push_r_a_elements_lp:
	subs	x5,x5,#1
	bne	not_first_arg_a

	ldr	x10,[x8]
	str	x10,[x26],#8
	b	push_r_a_elements
not_first_arg_a:
	ldr	x10,[x9,#-8]!
	str	x10,[x26],#8
push_r_a_elements:
	subs	x3,x3,#1
	bcs	push_r_a_elements_lp

	ret	x29

repl_r_a_args_n_a:
	ldr	x9,[x8]

	mov	x29,x30
	ldr	x30,[x28],#8

	ldrh	w6,[x9]
	cmp	x6,#0
	beq	repl_r_a_args_n_a_0
	cmp	x6,#2
	blo	repl_r_a_args_n_a_1
	ldr	x10,[x8,#16]
	beq	repl_r_a_args_n_a_2

	sub	x5,x6,#1
	add	x9,x10,x5,lsl #3

repl_r_a_args_n_a_4:
	ldr	x10,[x9,#-8]!
	str	x10,[x26],#8
	subs	x5,x5,#1
	bne	repl_r_a_args_n_a_4

repl_r_a_args_n_a_1:
	ldr	x10,[x8,#8]
	str	x10,[x26],#8
repl_r_a_args_n_a_0:
	ret	x29

repl_r_a_args_n_a_2:
	ldrh	w5,[x9,#-2]
	cmp	x5,#258
	beq	repl_r_a_args_n_a_3
	ldr	x10,[x10]
repl_r_a_args_n_a_3:
	str	x10,[x26],#8
	b	repl_r_a_args_n_a_1

BtoAC:
	tst	x6,x6
	beq	BtoAC_false
BtoAC_true:
	adrp	x8,true_string
	add	x8,x8,#:lo12:true_string
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
BtoAC_false:
	adrp	x8,false_string
	add	x8,x8,#:lo12:false_string
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

RtoAC:
.if USE_CLIB
	fmov	x2,d0
	adrp	x1,printf_real_string
	add	x1,x1,#:lo12:printf_real_string
	adrp	x0,sprintf_buffer
	add	x0,x0,#:lo12:sprintf_buffer
	mov	x29,x30
	bl	sprintf
	mov	x30,x29
.else
	adrp	x0,sprintf_buffer
	add	x0,x0,sprintf_buffer
	bl	convert_real_to_string
.endif
	b	return_sprintf_buffer

ItoAC:
.if MY_ITOS
	adrp	x8,sprintf_buffer
	add	x8,x8,#:lo12:sprintf_buffer
	str	x30,[X28,#-8]!
	bl	int_to_string

	adrp	x16,sprintf_buffer
	add	x16,x16,#:lo12:sprintf_buffer
	sub	x6,x8,x16
	b	sprintf_buffer_to_string

int_to_string:
	tst	x6,x6
	bpl	no_minus
	mov	x16,#45
	strb	w16,[x8],#1
	neg	x6,x6
no_minus:
	add	x10,x8,#24

	beq	zero_digit

	ldr	x2,=-3689348814741910323

calculate_digits:
	cmp	x6,#10
	blo	last_digit

	umulh	x9,x2,x6
	add	x3,x6,#48

	lsr	x6,x9,#3

	and	x9,x9,#-8
	sub	x3,x3,x9
	sub	x3,x3,x9,lsr #2
	strb	w3,[x10],#1
	b	calculate_digits

last_digit:
	cbz	x6,no_zero
zero_digit:
	add	x6,x6,#48
	strb	w6,[x10],#1
no_zero:
	add	x9,x8,#24

reverse_digits:
	ldrb	w3,[x10,#-1]!
	strb	w3,[x8],#1
	cmp	x9,x10
	bne	reverse_digits

	strb	wzr,[x8]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
.else
	mov	x2,x6
	adrp	x1,printf_int_string
	add	x1,x1,#:lo12:printf_int_string
	adrp	x0,sprintf_buffer
	add	x0,x0,#:lo12:sprintf_buffer
	mov	x29,x30
	bl	sprintf
	mov	x30,x29
.endif

return_sprintf_buffer:
.if USE_CLIB
	adrp	x0,sprintf_buffer
	add	x0,x0,#:lo12:sprintf_buffer
	mov	x29,x30
	bl	strlen
	mov	x6,x0
	mov	x30,x29
.else
	adrp	x6,sprintf_buffer-1
	add	x6,x6,#:lo12:sprintf_buffer-1
skip_characters:
	ldrb	w16,[x6,#1]!
	cbnz	x16,skip_characters

	adrp	x16,sprintf_buffer
	add	x16,x16,#:lo12:sprintf_buffer
	sub	x6,x6,x16
.endif

.if MY_ITOS
sprintf_buffer_to_string:
	adrp	x8,sprintf_buffer
	add	x8,x8,#:lo12:sprintf_buffer
build_string:
.endif
	add	x5,x6,#7
	lsr	x5,x5,#3
	add	x5,x5,#2

	subs	x25,x25,x5
	bhs	D_to_S_no_gc

	str	x8,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x8,[x28],#8

D_to_S_no_gc:
	sub	x5,x5,#2
	mov	x10,x27
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	stp	x16,x6,[x27],#16
	b	D_to_S_cp_str_2

D_to_S_cp_str_1:
	ldr	x6,[x8],#8
	str	x6,[x27],#8
D_to_S_cp_str_2:
	subs	x5,x5,#1
	bcs	D_to_S_cp_str_1

	mov	x8,x10
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

eqD:	ldr	x4,[x8]
	ldr	x16,[x9]
	cmp	x4,x16
	bne	eqD_false

	adrp	x16,INT+2
	add	x16,x16,#:lo12:INT+2
	cmp	x4,x16
	beq	eqD_INT
	adrp	x16,CHAR+2
	add	x16,x16,#:lo12:CHAR+2
	cmp	x4,x16
	beq	eqD_CHAR
	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2
	cmp	x4,x16
	beq	eqD_BOOL
	adrp	x16,REAL+2
	add	x16,x16,#:lo12:REAL+2
	cmp	x4,x16
	beq	eqD_REAL

	mov	x6,#1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

eqD_CHAR:
eqD_INT:
	ldr	x3,[x8,#8]
	ldr	x16,[x9,#8]
	cmp	x3,x16
	cset	x6,eq
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

eqD_BOOL:
	ldrb	w3,[x8,#8]
	ldrb	w16,[x9,#8]
	cmp	x3,x16
	cset	x6,eq
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

eqD_REAL:
	ldr	d0,[x8,#8]
	ldr	d1,[x9,#8]
	fcmp	d1,d0
	cset	x6,eq
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

eqD_false:
	mov	x6,#0
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
#
#	the timer
#

init_timer:
	str	x30,[sp,#-16]!

	sub	sp,sp,#32
	mov	x0,sp
	bl	times
	ldr	x4,[sp],#32
	add	x4,x4,x4
	add	x4,x4,x4,lsl #2

	ldr	x30,[sp],#16

	adrp	x16,last_time
	str	x4,[x16,#:lo12:last_time]
	mov	x4,#0
	adrp	x16,execute_time
	str	x4,[x16,#:lo12:execute_time]
	adrp	x16,garbage_collect_time
	str	x4,[x16,#:lo12:garbage_collect_time]
	adrp	x16,IO_time
	str	x4,[x16,#:lo12:IO_time]

	ret	x30

get_time_diff:
	str	x30,[sp,#-16]!

	sub	sp,sp,#32
	mov	x0,sp
	bl	times
	ldr	x4,[sp],#32
	add	x4,x4,x4
	add	x4,x4,x4,lsl #2

	ldr	x30,[sp],#16

	adrp	x8,last_time
	add	x8,x8,last_time
	ldr	x9,[x8]
	str	x4,[x8]
	subs	x4,x4,x9

	ret	x30

add_execute_time:
	str	x30,[sp,#-16]!
	bl	get_time_diff
	adrp	x8,execute_time
	add	x8,x8,#:lo12:execute_time

add_time:
	ldr	x16,[x8]
	add	x4,x4,x16
	str	x4,[x8]
	ldr	x30,[sp],#16
	ret	x30

add_garbage_collect_time:
	str	x30,[sp,#-16]!
	bl	get_time_diff
	adrp	x8,garbage_collect_time
	add	x8,x8,#:lo12:garbage_collect_time
	b	add_time

add_IO_time:
	str	x30,[sp,#-16]!
	bl	get_time_diff
	adrp	x8,IO_time
	add	x8,x8,#:lo12:IO_time
	b	add_time

	.ltorg

#
#	the garbage collector
#

collect_3:
.ifdef PROFILE
	adrp	x16,garbage_collector_name
	add	x16,x16,#:lo12:garbage_collector_name
	mov	x29,x30
	bl	profile_s
.endif
	str	x30,[x28,#-8]!
	str	x10,[x26,#16]
	stp	x8,x9,[x26],#24
	bl	collect_0_
	ldr	x10,[x26,#-8]
	ldp	x8,x9,[x26,#-24]!
.ifdef PROFILE
	b	profile_r
.else
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
.endif

collect_2:
.ifdef PROFILE
	adrp	x16,garbage_collector_name
	add	x16,x16,#:lo12:garbage_collector_name
	mov	x29,x30
	bl	profile_s
.endif
	stp	x8,x9,[x26],#16
	str	x30,[x28,#-8]!
	bl	collect_0_
	ldp	x8,x9,[x26,#-16]!
.ifdef PROFILE
	b	profile_r
.else
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
.endif

collect_1:
.ifdef PROFILE
	adrp	x16,garbage_collector_name
	add	x16,x16,#:lo12:garbage_collector_name
	mov	x29,x30
	bl	profile_s
.endif
	str	x8,[x26],#8
	str	x30,[x28,#-8]!
	bl	collect_0_
	ldr	x8,[x26,#-8]!
.ifdef PROFILE
	b	profile_r
.else
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
.endif

.ifdef PROFILE
collect_0:
	adrp	x16,garbage_collector_name
	add	x16,x16,#:lo12:garbage_collector_name
	mov	x29,x30
	bl	profile_s
	str	x30,[x28,#-8]!
	bl	collect_0_
	b	profile_r
.endif

.ifndef PROFILE
collect_0:
.endif
collect_0_:
	stp	x0,x1,[sp,#-64]!
	stp	x2,x3,[sp,#16]
	stp	x4,x5,[sp,#32]
	stp	x6,x30,[sp,#48]

	adrp	x16,heap_end_after_gc
	ldr	x16,[x16,#:lo12:heap_end_after_gc]
	sub	x10,x16,x27
	lsr	x10,x10,#3
	sub	x10,x10,x25
	adrp	x16,n_allocated_words
	str	x10,[x16,#:lo12:n_allocated_words]

.if MARK_AND_COPY_GC
	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark3 // 64
.endif

.if MARK_GC
	adrp	x16,bit_counter
	ldr	x10,[x16,#:lo12:bit_counter]
	cbz	x10,no_scan

	str	x26,[x28,#-8]!

	adrp	x16,n_allocated_words
	ldr	x26,[x16,#:lo12:n_allocated_words]
	adrp	x16,bit_vector_p
	ldr	x8,[x16,#:lo12:bit_vector_p]
	adrp	x16,n_free_words_after_mark
	ldr	x2,[x16,#:lo12:n_free_words_after_mark]

scan_bits:
	ldr	w16,[x8]
	cbz	x16,zero_bits
	str	wzr,[x8],#4
	subs	x10,x10,#1
	bne	scan_bits

	b	end_scan

zero_bits:
	add	x9,x8,#4
	add	x8,x8,#4
	subs	x10,x10,#1
	bne	skip_zero_bits_lp1
	b	end_bits

skip_zero_bits_lp:
	cbnz	x4,end_zero_bits
skip_zero_bits_lp1:
	ldr	w4,[x8],#4
	subs	x10,x10,#1
	bne	skip_zero_bits_lp

	cbz	x4,end_bits
	str	wzr,[x8,#-4]
	subs	x4,x8,x9
	b	end_bits2

end_zero_bits:
	sub	x4,x8,x9
	lsl	x4,x4,#3
	str	wzr,[x8,#-4]
	add	x2,x2,x4

	cmp	x4,x26
	blo	scan_bits

found_free_memory:
	adrp	x16,bit_counter
	str	x10,[x16,#:lo12:bit_counter]
	adrp	x16,bit_vector_p
	str	x8,[x16,#:lo12:bit_vector_p]
	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]

	sub	x25,x4,x26

	add	x10,x9,#-4
	adrp	x16,heap_vector
	ldr	x16,[x16,#:lo12:heap_vector]
	sub	x10,x10,x16
	lsl	x10,x10,#6
	adrp	x16,heap_p3
	ldr	x27,[x16,#:lo12:heap_p3]
	add	x27,x27,x10

	add	x10,x27,x4,lsl #3
	adrp	x16,heap_end_after_gc
	str	x10,[x16,#:lo12:heap_end_after_gc]

	ldr	x26,[x28],#8

	ldp	x6,x30,[sp,#48]
	ldp	x4,x5,[sp,#32]
	ldp	x2,x3,[sp,#16]
	ldp	x0,x1,[sp],#64

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

end_bits:
	sub	x4,x8,x9
	add	x4,x4,#4
end_bits2:
	lsl	x4,x4,#3
	add	x2,x2,x4
	cmp	x4,x26
	bhs	found_free_memory

end_scan:
	ldr	x26,[x28],#8

	adrp	x16,bit_counter
	str	x10,[x16,#:lo12:bit_counter]
	adrp	x16,n_free_words_after_mark
	str	x2,[x16,#:lo12:n_free_words_after_mark]

no_scan:
.endif

# to do: check value in x10

.if MARK_AND_COPY_GC
no_mark3:
.endif

	adrp	x16,garbage_collect_flag
	ldrsb	x4,[x16,#:lo12:garbage_collect_flag]
	cmp	x4,#0
	ble	collect

	sub	x4,x4,#2
	adrp	x16,garbage_collect_flag
	strb	w4,[x16,#:lo12:garbage_collect_flag]

	adrp	x3,extra_heap_size
	ldr	x3,[x3,#:lo12:extra_heap_size]
	cmp	x10,x3
	bhi	collect

	sub	x25,x3,x10

	adrp	x27,extra_heap
	ldr	x27,[x27,#:lo12:extra_heap]
	add	x3,x27,x3,lsl #3
	adrp	x16,heap_end_after_gc
	str	x3,[x16,#:lo12:heap_end_after_gc]

	ldp	x6,x30,[sp,#48]
	ldp	x4,x5,[sp,#32]
	ldp	x2,x3,[sp,#16]
	ldp	x0,x1,[sp],#64

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

collect:
	bl	add_execute_time

	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#2,no_print_stack_sizes

	adrp	x0,garbage_collect_string_1
	add	x0,x0,#:lo12:garbage_collect_string_1
	bl	ew_print_string

	mov	x4,x26
	adrp	x16,stack_p
	ldr	x16,[x16,#:lo12:stack_p]
	sub	x0,x4,x16
	bl	ew_print_int

	adrp	x0,garbage_collect_string_2
	add	x0,x0,#:lo12:garbage_collect_string_2
	bl	ew_print_string

	adrp	x16,halt_sp
	ldr	x4,[x16,#:lo12:halt_sp]
	mov	x0,sp
	sub	x0,x4,x0
	bl	ew_print_int

	adrp	x0,garbage_collect_string_3
	add	x0,x0,#:lo12:garbage_collect_string_3
	bl	ew_print_string

no_print_stack_sizes:
	adrp	x16,stack_p
	ldr	x4,[x16,#:lo12:stack_p]
	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]
	add	x4,x4,x16
	cmp	x26,x4
	bhi	stack_overflow

.if MARK_AND_COPY_GC
	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tbnz	x16,#6,compacting_collector // 64
.else
 .if MARK_GC
	b	compacting_collector
 .endif
.endif

.if MARK_AND_COPY_GC || !MARK_GC
	adrp	x16,garbage_collect_flag
	ldrsb	x16,[x16,#:lo12:garbage_collect_flag]
	cbnz	x16,compacting_collector

	adrp	x16,heap_copied_vector
	ldr	x10,[x16,#:lo12:heap_copied_vector]

	adrp	x16,heap_end_after_copy_gc
	ldr	x16,[x16,#:lo12:heap_end_after_copy_gc]
	cbz	x16,zero_all

	adrp	x16,heap_p1
	ldr	x16,[x16,#:lo12:heap_p1]
	subs	x4,x27,x16
	add	x4,x4,#127*8
	lsr	x4,x4,#9
	bl	zero_bit_vector

	adrp	x16,heap_end_after_copy_gc
	ldr	x9,[x16,#:lo12:heap_end_after_copy_gc]
	adrp	x16,heap_p1
	ldr	x16,[x16,#:lo12:heap_p1]
	subs	x9,x9,x16
	lsr	x9,x9,#7
	and	x9,x9,#-4

	adrp	x16,heap_copied_vector
	ldr	x10,[x16,#:lo12:heap_copied_vector]
	adrp	x16,heap_copied_vector_size
	ldr	x4,[x16,#:lo12:heap_copied_vector_size]
	add	x10,x10,x9
	sub	x4,x4,x9
	lsr	x4,x4,#2

	adrp	x16,heap_end_after_copy_gc
	mov	x9,#0
	str	x9,[x16,#:lo12:heap_end_after_copy_gc]

	bl	zero_bit_vector
	b	end_zero_bit_vector

zero_all:
	adrp	x16,heap_copied_vector_size
	ldr	x4,[x16,#:lo12:heap_copied_vector_size]
	lsr	x4,x4,#2
	bl	zero_bit_vector

end_zero_bit_vector:

	.include "arm64copy.s"

.if WRITE_HEAP
	adrp	x16,heap2_begin_and_end
	str	x27,[x16,#:lo12:heap2_begin_and_end]
.endif

	bl	add_garbage_collect_time

	sub	x10,x27,x26
	lsr	x10,x10,#3

	mov	x27,x26
	ldr	x26,[sp],#16

	adrp	x16,n_allocated_words
	ldr	x16,[x16,#:lo12:n_allocated_words]
	subs	x10,x10,x16
	mov	x25,x10
	bls	switch_to_mark_scan

	add	x4,x10,x10,lsl #2
	lsl	x4,x4,#6
	adrp	x3,heap_size
	ldr	x3,[x3,#:lo12:heap_size]
	mov	x8,x3
	lsl	x3,x3,#2
	add	x3,x3,x8
	add	x3,x3,x3
	add	x3,x3,x8
	cmp	x4,x3
	bhs	no_mark_scan
#	b	no_mark_scan

switch_to_mark_scan:
	adrp	x4,heap_size_65
	ldr	x4,[x4,#:lo12:heap_size_65]
	lsl	x4,x4,#6
	adrp	x16,heap_p
	ldr	x3,[x16,#:lo12:heap_p]

	adrp	x8,heap_p1
	ldr	x8,[x8,#:lo12:heap_p1]
	adrp	x16,heap_p2
	ldr	x16,[x16,#:lo12:heap_p2]
	cmp	x8,x16
	bcc	vector_at_begin

vector_at_end:
	adrp	x16,heap_p3
	str	x3,[x16,#:lo12:heap_p3]
	add	x3,x3,x4
	adrp	x16,heap_vector
	str	x3,[x16,#:lo12:heap_vector]

	adrp	x4,heap_p1
	ldr	x4,[x4,#:lo12:heap_p1]
	adrp	x16,extra_heap
	str	x4,[x16,#:lo12:extra_heap]
	sub	x3,x3,x4
	lsr	x3,x3,#3
	adrp	x16,extra_heap_size
	str	x3,[x16,#:lo12:extra_heap_size]
	b	switch_to_mark_scan_2

vector_at_begin:
	adrp	x16,heap_vector
	str	x3,[x16,#:lo12:heap_vector]
	adrp	x16,heap_size
	ldr	x16,[x16,#:lo12:heap_size]
	add	x3,x3,x16
	sub	x3,x3,x4
	adrp	x16,heap_p3
	str	x3,[x16,#:lo12:heap_p3]

	adrp	x16,extra_heap
	str	x3,[x16,#:lo12:extra_heap]
	adrp	x8,heap_p2
	ldr	x8,[x8,#:lo12:heap_p2]
	sub	x8,x8,x3
	lsr	x8,x8,#3
	adrp	x16,extra_heap_size
	str	x8,[x16,#:lo12:extra_heap_size]

switch_to_mark_scan_2:
	adrp	x4,heap_size
	ldr	x4,[x4,#:lo12:heap_size]
	lsr	x4,x4,#4
	sub	x4,x4,x10
	lsl	x4,x4,#3

	mov	x17,#1
	adrp	x16,garbage_collect_flag
	strb	w17,[x16,#:lo12:garbage_collect_flag]

	cmp	x25,#0
	bpl	end_garbage_collect

	mov	x17,#-1
	strb	w17,[x16,#:lo12:garbage_collect_flag]

	adrp	x3,extra_heap_size
	ldr	x3,[x3,#:lo12:extra_heap_size]
	adrp	x16,n_allocated_words
	ldr	x16,[x16,#:lo12:n_allocated_words]
	subs	x25,x3,x16
	bmi	out_of_memory_4

	adrp	x27,extra_heap
	ldr	x27,[x27,#:lo12:extra_heap]
	lsl	x3,x3,#3
	add	x3,x3,x27
	adrp	x16,heap_end_after_gc
	str	x3,[x16,#:lo12:heap_end_after_gc]
.if WRITE_HEAP
	adrp	x16,heap_end_write_heap
	str	x27,[x16,#:lo12:heap_end_write_heap]
	mov	x17,#1
	adrp	x16,d3_flag_write_heap
	str	x17,[x16,#:lo12:d3_flag_write_heap]
	b	end_garbage_collect_
.else
	b	end_garbage_collect
.endif
no_mark_scan:
# exchange the semi_spaces
	adrp	x4,heap_p1
	ldr	x4,[x4,#:lo12:heap_p1]
	adrp	x3,heap_p2
	ldr	x3,[x3,#:lo12:heap_p2]
	adrp	x16,heap_p2
	str	x4,[x16,#:lo12:heap_p2]
	adrp	x16,heap_p1
	str	x3,[x16,#:lo12:heap_p1]

	adrp	x4,heap_size_257
	ldr	x4,[x4,#:lo12:heap_size_257]
	lsl	x4,x4,#7-3

 .ifdef MUNMAP
	adrp	x16,heap_p2
	ldr	x3,[x16,#:lo12:heap_p2]
	add	x8,x3,x4,lsl #2
	add	x3,x3,#4095
	and	x3,x3,#-4096
	and	x8,x8,#-4096
	subs	x8,x8,x3
	bls	no_pages
	str	x4,[sp,#-4]!

	str	x8,[sp,#-4]!
	str	x3,[sp,#-4]!
	str	x30,[sp,#-4]!
	bl	_munmap
	add	sp,sp,#8

	ldr	x4,[sp],#4
no_pages:
 .endif

 .if ADJUST_HEAP_SIZE
	mov	x3,x4
 .endif
	sub	x4,x4,x10

 .if ADJUST_HEAP_SIZE
	mov	x8,x4
	adrp	x16,heap_size_multiple
	ldr	x16,[x16,#:lo12:heap_size_multiple]
	umulh	x9,x16,x4
	mul	x4,x16,x4
	lsr	x4,x4,#9
	orr	x4,x4,x9,lsl #32-9
	lsr	x9,x9,#9
	cbnz	x9,no_small_heap1

	cmp	x4,#MINIMUM_HEAP_SIZE_2
	bhs	not_too_small1
	mov	x4,#MINIMUM_HEAP_SIZE_2
not_too_small1:
	subs	x3,x3,x4
	blo	no_small_heap1

	sub	x25,x25,x3
	lsl	x3,x3,#3
	adrp	x10,heap_end_after_gc
	ldr	x10,[x10,#:lo12:heap_end_after_gc]
	adrp	x16,heap_end_after_copy_gc
	str	x10,[x16,#:lo12:heap_end_after_copy_gc]
	sub	x10,x10,x3
	adrp	x16,heap_end_after_gc
	str	x10,[x16,#:lo12:heap_end_after_gc]

no_small_heap1:
	mov	x4,x8
 .endif

	lsl	x4,x4,#3
.endif

end_garbage_collect:
.if WRITE_HEAP
	adrp	x16,heap_end_write_heap
	str	x27,[x16,#:lo12:heap_end_write_heap]
	mov	x17,#0
	adrp	x16,d3_flag_write_heap
	str	x17,[x16,#:lo12:d3_flag_write_heap]
end_garbage_collect_:
.endif

	str	x4,[x28,#-8]!

	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#1,no_heap_use_message

	str	x4,[x28,#-8]!

	adrp	x0,heap_use_after_gc_string_1
	add	x0,x0,#:lo12:heap_use_after_gc_string_1
	bl	ew_print_string

	ldr	x0,[x28],#8
	bl	ew_print_int

	adrp	x0,heap_use_after_gc_string_2
	add	x0,x0,#:lo12:heap_use_after_gc_string_2
	bl	ew_print_string

no_heap_use_message:

.if FINALIZERS
	bl	call_finalizers
.endif

	ldr	x4,[x28],#8

.if WRITE_HEAP
	# Check whether memory profiling is on or off
	adrp	x16,flags
	ldr	x16,[x16,#:lo12:flags]
	tst	x16,#32
	beq	no_write_heap

	adrp	x16,min_write_heap_size
	ldr	x16,[x16,#:lo12:min_write_heap_size]
	cmp	x4,x16
	blo	no_write_heap

	str	x8,[sp,#-4]!
	str 	x9,[sp,#-4]!
	str	x10,[sp,#-4]!
	str	x26,[sp,#-4]!
	str	x27,[sp,#-4]!

	subs	sp,sp,#64

	adrp	x16,d3_flag_write_heap
	ldr	x4,[x16,#:lo12:d3_flag_write_heap]
	tst	x4,x4
	bne	copy_to_compact_with_alloc_in_extra_heap	

	adrp	x4,garbage_collect_flag
	ldrsb	x4,[x4,#:lo12:garbage_collect_flag]

	adrp	x16,heap2_begin_and_end
	ldr	x8,[x16,#:lo12:heap2_begin_and_end]
	adrp	x16,heap2_begin_and_end+4
	ldr	x9,[x16,#:lo12:heap2_begin_and_end+4]

	adrp	x3,heap_p1
	add	x3,x3,#:lo12:heap_p1

	tst	x4,x4
	beq	gc0

	adrp	x3,heap_p2
	add	x3,x3,#:lo12:heap_p2
	bgt	gc1

	adrp	x3,heap_p3
	add	x3,x3,#:lo12:heap_p3
	mov	x8,#0
	mov	x9,#0

gc0:
gc1:
	ldr	x3,[x3]

?	/* fill record */

	mov	x4,sp

	str	x3,[x4,#0]
?	movl	a4,4(d0)			// klop dit?

?	movl	a0,8(d0)			// heap2_begin
?	movl	a1,12(d0)			// heap2_end

	adrp	x16,stack_p
	ldr	x3,[x16,#:lo12:stack_p]
?	movl	d1,16(d0)			// stack_begin

?	movl	a3,20(d0)			// stack_end
?	movl	$0,24(d0)			// text_begin
?	movl	$0,28(d0)			// data_begin

?	movl	$small_integers,32(d0)	// small_integers
?	movl	$static_characters,36(d0)	// small_characters

?	movl	$INT+2,40(d0)		// INT-descP
?	movl	$CHAR+2,44(d0)		// CHAR-descP
?	movl	$REAL+2,48(d0)		// REAL-descP
?	movl	$BOOL+2,52(d0)		// BOOL-descP
?	movl	$__STRING__+2,56(d0)	// STRING-descP
?	movl	$__ARRAY__+2,60(d0)		// ARRAY-descP

	str	x4,[sp,#-4]!
	bl	write_heap

	add	sp,sp,#68

	ldr	x27,[sp],#4
	ldr	x26,[sp],#4
	ldr	x10,[sp],#4
	ldr	x9,[sp],#4
	ldr	x8,[sp],#4
no_write_heap:

.endif

	ldp	x6,x30,[sp,#48]
	ldp	x4,x5,[sp,#32]
	ldp	x2,x3,[sp,#16]
	ldp	x0,x1,[sp],#64

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.ltorg

.if FINALIZERS
call_finalizers:
	adrp	x16,free_finalizer_list
	ldr	x4,[x16,#:lo12:free_finalizer_list]

call_finalizers_lp:
	adrp	x16,__Nil-8
	add	x16,x16,#:lo12:__Nil-8
	cmp	x4,x16
	beq	end_call_finalizers
	ldr	x16,[x4,#4]
	str	x16,[sp,#-16]!
	ldr	x3,[x4,#8]
	ldr	x16,[x3,#4]
	str	x16,[sp,#8]!
	ldr	x16,[x3]
	blr	x16
	ldr	x4,[sp,#8]
	add	sp,sp,#16
	b	call_finalizers_lp
end_call_finalizers:
	adrp	x17,__Nil-8
	add	x17,x17,#:lo12:__Nil-8
	adrp	x16,free_finalizer_list
	str	x17,[x16,#:lo12:free_finalizer_list]
	ret	x30
.endif

.if WRITE_HEAP
copy_to_compact_with_alloc_in_extra_heap:
	adrp	x16,heap2_begin_and_end
	ldr	x8,[x16,#:lo12:heap2_begin_and_end]
	adrp	x16,heap2_begin_and_end+4
	ldr	x9,[x16,#:lo12:heap2_begin_and_end+4]
	adrp	x3,heap_p2
	add	x3,x3,#:lo12:heap_p2
	b	gc1
.endif

out_of_memory_4:
	bl	add_garbage_collect_time

	adrp	x10,out_of_memory_string_4
	add	x10,x10,#:lo12:out_of_memory_string_4
	b	print_error

zero_bit_vector:
	mov	x9,#0
	tbz	x4,#0,zero_bits1_1
	str	w9,[x10],#4
zero_bits1_1:
	lsr	x4,x4,#1

	mov	x3,x4
	lsr	x4,x4,#1
	tbz	x3,#0,zero_bits1_5

	sub	x10,x10,#8
	b	zero_bits1_2

zero_bits1_4:
	stp	w9,w9,[x10]
zero_bits1_2:
	stp	w9,w9,[x10,#8]
	add	x10,x10,#16
zero_bits1_5:
	subs	x4,x4,#1
	bhs	zero_bits1_4

	ret	x30

reorder:
	stp	x12,x13,[x28,#-16]
	stp	x6,x11,[x28,#-32]
	stp	x10,x7,[x28,#-48]!

	mov	x11,x3
	mov	x6,x4

	lsl	x10,x4,#3
	lsl	x7,x3,#3
	add	x8,x8,x7
	sub	x9,x9,x10

	mov	x13,x7
	mov	x12,x10
	b	st_reorder_lp

reorder_lp:
	ldr	x10,[x8]
	ldr	x7,[x9,#-8]
	str	x10,[x9,#-8]!
	str	x7,[x8],#8

	subs	x4,x4,#1
	bne	next_b_in_element
	mov	x4,x6
	add	x8,x8,x13
next_b_in_element:
	subs	x3,x3,#1
	bne	next_a_in_element
	mov	x3,x11
	subs	x9,x9,x12
next_a_in_element:
st_reorder_lp:
	cmp	x9,x8
	bhi	reorder_lp

	mov	x3,x11
	mov	x4,x6

	ldp	x12,x13,[x28,#32]
	ldp	x6,x11,[x28,#16]
	ldp	x10,x7,[x28],#48
	ret	x30

#
#	the sliding compacting garbage collector
#

compacting_collector:
# zero all mark bits

	adrp	x16,stack_top
	str	x26,[x16,#:lo12:stack_top]

	adrp	x16,heap_vector
	ldr	x27,[x16,#:lo12:heap_vector]

.if MARK_GC
 .if MARK_AND_COPY_GC
 	adrp	x16,flags
 	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark4 // 64
 .endif
 	adrp	x16,zero_bits_before_mark
 	add	x16,x16,#:lo12:zero_bits_before_mark
 	ldr	x17,[x16]
	cbz	x17,no_zero_bits

	mov	x17,#0
	str	x17,[x16]

 .if MARK_AND_COPY_GC
no_mark4:
 .endif
.endif

	mov	x10,x27
	adrp	x4,heap_size_65
	ldr	x4,[x4,#:lo12:heap_size_65]
	add	x4,x4,#3
	lsr	x4,x4,#2

	tbz	x4,#0,zero_bits_1
	str	wzr,[x10],#4
zero_bits_1:
	mov	x8,x4
	lsr	x4,x4,#2

	tbz	x8,#1,zero_bits_5

	sub	x10,x10,#8
	b	zero_bits_2

zero_bits_4:
	stp	wzr,wzr,[x10]
zero_bits_2:
	stp	wzr,wzr,[x10,#8]
	add	x10,x10,#16
zero_bits_5:
	subs	x4,x4,#1
	bcs	zero_bits_4

.if MARK_GC
 .if MARK_AND_COPY_GC
 	adrp	x16,flags
 	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark5 // 64
 .endif
no_zero_bits:
	adrp	x16,n_last_heap_free_bytes
	ldr	x4,[x16,#:lo12:n_last_heap_free_bytes]
	adrp	x16,n_free_words_after_mark
	ldr	x3,[x16,#:lo12:n_free_words_after_mark]

.if 1
	lsr	x4,x4,#3
.else
	lsl	x3,x3,#3
.endif

	add	x10,x3,x3,lsl #3
	lsr	x10,x10,#2

	cmp	x4,x10
	bgt	compact_gc

 .if ADJUST_HEAP_SIZE
	adrp	x16,bit_vector_size
	ldr	x3,[x16,#:lo12:bit_vector_size]
	lsl	x3,x3,#3

	sub	x4,x3,x4

	adrp	x16,heap_size_multiple
	ldr	x16,[x16,#:lo12:heap_size_multiple]
	umulh	x9,x16,x4
	mul	x4,x16,x4
	lsr	x4,x4,#7
	orr	x4,x4,x9,lsl #32-7
	lsr	x9,x9,#7
	cbnz	x9,no_smaller_heap

	cmp	x4,x3
	bhs	no_smaller_heap

	mov	x16,#MINIMUM_HEAP_SIZE
	cmp	x3,x16
	bls	no_smaller_heap

	b	compact_gc
no_smaller_heap:
 .endif

	.include "arm64mark.s"

compact_gc:
	mov	x17,#1
	adrp	x16,zero_bits_before_mark
	str	x17,[x16,#:lo12:zero_bits_before_mark]
	mov	x17,#0
	adrp	x16,n_last_heap_free_bytes
	str	x17,[x16,#:lo12:n_last_heap_free_bytes]
	mov	x17,#1000
	adrp	x16,n_free_words_after_mark
	str	x17,[x16,#:lo12:n_free_words_after_mark]
 .if MARK_AND_COPY_GC
no_mark5:
 .endif
.endif

	.include "arm64compact.s"

	adrp	x16,stack_top
	ldr	x26,[x16,#:lo12:stack_top]

	adrp	x3,heap_size_65
	ldr	x3,[x3,#:lo12:heap_size_65]
	lsl	x3,x3,#6
	adrp	x16,heap_p3
	ldr	x16,[x16,#:lo12:heap_p3]
	add	x3,x3,x16

	adrp	x16,heap_end_after_gc
	str	x3,[x16,#:lo12:heap_end_after_gc]

	subs	x3,x3,x27
	lsr	x3,x3,#3

	adrp	x16,n_allocated_words
	ldr	x16,[x16,#:lo12:n_allocated_words]
	subs	x3,x3,x16
	mov	x25,x3
	bcc	out_of_memory_4

	add	x4,x3,x3,lsl #2
	lsl	x4,x4,#4
	adrp	x16,heap_size
	ldr	x16,[x16,#:lo12:heap_size]
	cmp	x4,x16
	bcc	out_of_memory_4

.if MARK_GC || COMPACT_GC_ONLY
 .if MARK_GC && ADJUST_HEAP_SIZE
  .if MARK_AND_COPY_GC
  	adrp	x16,flags
  	ldr	x16,[x16,#:lo12:flags]
	tbz	x16,#6,no_mark_6 // 64
  .endif

	adrp	x16,heap_p3
	ldr	x4,[x16,#:lo12:heap_p3]
	sub	x4,x27,x4
	adrp	x16,n_allocated_words
	ldr	x3,[x16,#:lo12:n_allocated_words]
	add	x4,x4,x3,lsl #2

	adrp	x3,heap_size_65
	ldr	x3,[x3,#:lo12:heap_size_65]
	lsl	x3,x3,#6

	adrp	x16,heap_size_multiple
	ldr	x16,[x16,#:lo12:heap_size_multiple]
	umulh	x9,x16,x4
	mul	x4,x16,x4
	lsr	x4,x4,#8
	orr	x4,x4,x9,lsl #64-8
	lsr	x9,x9,#8
	cbnz	x9,no_small_heap2

	and	x4,x4,#-8

	mov	x16,#MINIMUM_HEAP_SIZE
	cmp	x4,x16
	bhs	not_too_small2
	mov	x4,#MINIMUM_HEAP_SIZE
not_too_small2:
	mov	x8,x3
	subs	x8,x8,x4
	blo	no_small_heap2

	adrp	x16,heap_end_after_gc
	ldr	x17,[x16,#:lo12:heap_end_after_gc]
	sub	x17,x17,x8
	adrp	x16,heap_end_after_gc
	str	x17,[x16,#:lo12:heap_end_after_gc]

	sub	x25,x25,x8,lsr #3

	mov	x3,x4

no_small_heap2:
	lsr	x3,x3,#3
	adrp	x16,bit_vector_size
	str	x3,[x16,#:lo12:bit_vector_size]

  .if MARK_AND_COPY_GC
no_mark_6:
  .endif
 .endif
	b	no_copy_garbage_collection
.else
# to do prevent overflow
	lsl	x4,x4,#2
	adrp	x16,heap_size
	ldr	x16,[x16,#:lo12:heap_size]
	lsl	x8,x16,#5
	sub	x8,x8,x16
	cmp	x4,x8
	ble	no_copy_garbage_collection

	adrp	x16,heap_p
	ldr	x4,[x16,#:lo12:heap_p]
	adrp	x16,heap_p1
	str	x4,[x16,#:lo12:heap_p1]

	adrp	x16,heap_size_257
	ldr	x3,[x16,#:lo12:heap_size_257]
	lsl	x3,x3,#7
	add	x4,x4,x3
	adrp	x16,heap_copied_vector
	str	x4,[x16,#:lo12:heap_copied_vector]
	adrp	x16,heap_end_after_gc
	str	x4,[x16,#:lo12:heap_end_after_gc]
	adrp	x16,heap_copied_vector_size
	ldr	x3,[x16,#:lo12:heap_copied_vector_size]
	add	x3,x3,x4
	adrp	x16,heap_p2
	str	x3,[x16,#:lo12:heap_p2]

	adrp	x16,heap_p3
	ldr	x4,[x16,#:lo12:heap_p3]
	adrp	x16,heap_vector
	ldr	x16,[x16,#:lo12:heap_vector]
	cmp	x4,x16
	ble	vector_at_end_2

	adrp	x16,heap_vector
	ldr	x3,[x16,#:lo12:heap_vector]
	adrp	x16,extra_heap
	str	x3,[x16,#:lo12:extra_heap]
	subs	x4,x4,x3
	lsr	x4,x4,#2
	adrp	x16,extra_heap_size
	str	x4,[x16,#:lo12:extra_heap_size]

	mov	x17,#2
	adrp	x16,garbage_collect_flag
	strb	w17,[x16,#:lo12:garbage_collect_flag]
	b	no_copy_garbage_collection

vector_at_end_2:
	mov	x17,#0
	adrp	x16,garbage_collect_flag
	strb	w17,[x16,#:lo12:garbage_collect_flag]
.endif

no_copy_garbage_collection:
	bl	add_garbage_collect_time

	mov	x4,x27
	adrp	x16,heap_p3
	ldr	x16,[x16,#:lo12:heap_p3]
	sub	x4,x4,x16
	adrp	x16,n_allocated_words
	ldr	x3,[x16,#:lo12:n_allocated_words]
	add	x4,x4,x3,lsl #2
	b	end_garbage_collect

stack_overflow:
	str	x30,[sp,#-16]!
	bl	add_execute_time

	adrp	x10,stack_overflow_string
	add	x10,x10,#:lo12:stack_overflow_string
	b	print_error

IO_error:
	str	x0,[sp,#-16]!

	adrp	x0,IO_error_string
	add	x0,x0,#:lo12:IO_error_string
	bl	ew_print_string

	ldr	x0,[sp],#16
	bl	ew_print_string

	adrp	x0,new_line_string
	add	x0,x0,#:lo12:new_line_string
	bl	ew_print_string

	b	halt

print_error:
	mov	x0,x10
	bl	ew_print_string

halt:
	adrp	x16,halt_sp
	ldr	x16,[x16,#:lo12:halt_sp]
	mov	sp,x16

.ifdef PROFILE
	str	x30,[x28,#-8]!
	bl	write_profile_stack
.endif

	b	exit

	.ltorg

e__system__eaind:
eval_fill:
	str	x8,[x26],#8
	mov	x8,x9
	ldr	x16,[x9]
	str	x30,[x28,#-8]!
	blr	x16
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	ldr	x10,[x9]
	str	x10,[x8]
	ldr	x10,[x9,#8]
	str	x10,[x8,#8]
	ldr	x10,[x9,#16]
	str	x10,[x8,#16]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.p2align	2
	b	e__system__eaind
	nop
	nop
.ifdef PIC
	.long	e__system__dind-.
.else
	.long	e__system__dind
.endif
	.long	-2
e__system__nind:
__indirection:
	ldr	x9,[x8,#8]
	ldr	x4,[x9]
	tst	x4,#2
.if MARK_GC
	beq	eval_fill2
.else
	beq	__cycle__in__spine
.endif
	str	x4,[x8]
	ldr	x10,[x9,#8]
	str	x10,[x8,#8]
	ldr	x10,[x9,#16]
	str	x10,[x8,#16]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

.if MARK_GC
eval_fill2:
 .if 0
	adrp	x16,__cycle__in__spine
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x8]
 .else
	str	x24,[x8]
 .endif
	str	x8,[x26]
 .if MARK_AND_COPY_GC
 	adrp	x16,flags
 	ldr	x16,[x16,#:lo12:flags]
 	tst	x16,#64
	beq	__cycle__in__spine	
 .endif
	add	x26,x26,#8
	mov	x8,x9
	
	str	x30,[x28,#-8]!
	blr	x4
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	ldr	x10,[x9]
	str	x10,[x8]
	ldr	x10,[x9,#8]
	str	x10,[x8,#8]
	ldr	x10,[x9,#16]
	str	x10,[x8,#16]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
.endif

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_0:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	str	x8,[x9,#8]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_1:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x4,[x9,#8]
	str	x8,[x9,#8]
	mov	x9,x4
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_2:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x9,#8]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_3:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x9,#8]
	str	x8,[x26],#8
	ldr	x8,[x9,#24]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_4:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x9,#8]
	str	x8,[x26]
	ldr	x3,[x9,#32]
	str	x3,[x26,#8]
	add	x26,x26,#16
	ldr	x8,[x9,#24]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_5:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x26]
	str	x8,[x9,#8]
	ldr	x3,[x9,#40]
	str	x3,[x26,#8]
	ldr	x3,[x9,#32]
	str	x3,[x26,#16]
	add	x26,x26,#24
	ldr	x8,[x9,#24]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_6:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x26]
	str	x8,[x9,#8]
	ldr	x3,[x9,#48]
	str	x3,[x26,#8]
	ldr	x3,[x9,#40]
	str	x3,[x26,#16]
	ldr	x3,[x9,#32]
	str	x3,[x26,#24]
	add	x26,x26,#32
	ldr	x8,[x9,#24]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_7:
	mov	x4,#0
	mov	x3,#20
eval_upd_n:
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	add	x2,x9,x3
	str	x16,[x9]
	ldr	x10,[x9,#8]
	str	x8,[x26]
	str	x8,[x9,#8]
	ldr	x3,[x2,#16]
	str	x3,[x26,#8]
	ldr	x3,[x2,#8]
	str	x3,[x26,#16]
	ldr	x3,[x2]
	str	x3,[x26,#24]
	add	x26,x26,#32

eval_upd_n_lp:
	ldr	x3,[x2,#-8]!
	str	x3,[x26],#8
	subs	x4,x4,#1
	bcs	eval_upd_n_lp

	ldr	x8,[x9,#24]
	ldr	x9,[x9,#16]
	br	x11

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_8:
	mov	x4,#1
	mov	x3,#24
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_9:
	mov	x4,#2
	mov	x3,#28
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_10:
	mov	x4,#3
	mov	x3,#32
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_11:
	mov	x4,#4
	mov	x3,#36
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_12:
	mov	x4,#5
	mov	x3,#40
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_13:
	mov	x4,#6
	mov	x3,#44
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_14:
	mov	x4,#7
	mov	x3,#48
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_15:
	mov	x4,#8
	mov	x3,#52
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_16:
	mov	x4,#9
	mov	x3,#56
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_17:
	mov	x4,#10
	mov	x3,#60
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_18:
	mov	x4,#11
	mov	x3,#64
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_19:
	mov	x4,#12
	mov	x3,#68
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_20:
	mov	x4,#13
	mov	x3,#72
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_21:
	mov	x4,#14
	mov	x3,#76
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_22:
	mov	x4,#15
	mov	x3,#80
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_23:
	mov	x4,#16
	mov	x3,#84
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_24:
	mov	x4,#17
	mov	x3,#88
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_25:
	mov	x4,#18
	mov	x3,#92
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_26:
	mov	x4,#19
	mov	x3,#96
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_27:
	mov	x4,#20
	mov	x3,#100
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_28:
	mov	x4,#21
	mov	x3,#104
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_29:
	mov	x4,#22
	mov	x3,#108
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_30:
	mov	x4,#23
	mov	x3,#112
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_31:
	mov	x4,#24
	mov	x3,#116
	b	eval_upd_n

.ifdef PROFILE
	mov	x29,x30
	bl	profile_n
.endif
eval_upd_32:
	mov	x4,#25
	mov	x3,#120
	b	eval_upd_n

#
#	STRINGS
#
	.section .text.	(catAC)
catAC:
	ldr	x4,[x8,#8]
	ldr	x3,[x9,#8]
	add	x2,x4,x3
	add	x1,x2,#16+7
	lsr	x1,x1,#3

	subs	x25,x25,x1
	blo	gc_3
gc_r_3:
	add	x10,x8,#16
	add	x9,x9,#16

# fill_node

	mov	x8,x27
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2

# store descriptor and length

	stp	x16,x2,[x27],#16

# copy string 1

	add	x2,x3,#7
	add	x3,x3,x27
	lsr	x2,x2,#3
	cbz	x2,catAC_after_copy_lp1

catAC_copy_lp1:
	ldr	x16,[x9],#8
	subs	x2,x2,#1
	str	x16,[x27],#8
	bne	catAC_copy_lp1

catAC_after_copy_lp1:
	mov	x27,x3

# copy_string 2

cat_string_6:
	lsr	x2,x4,#3
	cbz	x2,cat_string_8

cat_string_7:
	ldr	x3,[x10],#8
	subs	x2,x2,#1
# store not aligned
	str	x3,[x27],#8
	bne	cat_string_7

cat_string_8:
	tbz	x4,#2,cat_string_9
	ldr	w3,[x10],#4
	str	w3,[x27],#4
cat_string_9:
	tbz	x4,#1,cat_string_10
	ldrh	w3,[x10],#2
	strh	w3,[x27],#2
cat_string_10:
	tbz	x4,#0,cat_string_11
	ldrb	w3,[x10]
	strb	w3,[x27],#1
cat_string_11:

# align heap pointer
	add	x27,x27,#7
	and	x27,x27,#-8
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_3:	str	x30,[x28,#-8]!
	bl	collect_2
	b	gc_r_3

empty_string:
	adrp	x8,zero_length_string
	add	x8,x8,#:lo12:zero_length_string
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.section .text.sliceAC,"ax"
sliceAC:
	ldr	x10,[x8,#8]
	tst	x5,x5
	bpl	slice_string_1
	mov	x5,#0
slice_string_1:
	cmp	x5,x10
	bge	empty_string
	cmp	x6,x5
	blt	empty_string
	add	x6,x6,#1
	cmp	x6,x10
	ble	slice_string_2
	mov	x6,x10
slice_string_2:
	sub	x6,x6,x5

	add	x2,x6,#16+7
	lsr	x2,x2,#3

	subs	x25,x25,x2	
	blo	gc_4
r_gc_4:
	sub	x2,x2,#2
	add	x9,x8,x5
	add	x9,x9,#16

	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	str	x16,[x27]

	mov	x8,x27
	stp	x16,x6,[x27],#16

# copy part of string
	cbz	x2,sliceAC_after_copy_lp
	
sliceAC_copy_lp:
# load not aligned
	ldr	x16,[x9],#8
	subs	x2,x2,#1
	str	x16,[x27],#8
	bne	sliceAC_copy_lp
		
sliceAC_after_copy_lp:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_4:	str	x30,[x28,#-8]!
	bl	collect_1
	b	r_gc_4

	.section .text.updateAC,"ax"
updateAC:
	ldr	x10,[x8,#8]
	cmp	x5,x10
	bhs	update_string_error

	add	x10,x10,#16+7
	lsr	x10,x10,#3

	subs	x25,x25,x10
	blo	gc_5
r_gc_5:
	ldr	x10,[x8,#8]
	add	x10,x10,#7
	lsr	x10,x10,#3

	mov	x9,x8
	mov	x8,x27

	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	str	x16,[x27]
	ldr	x16,[x9,#8]
	add	x9,x9,#16
	str	x16,[x27,#8]
	add	x27,x27,#16

	add	x5,x5,x27

	cmp	x10,#0
	beq	updateAC_after_copy_lp

updateAC_copy_lp:
	ldr	x16,[x9],#8
	str	x16,[x27],#8
	subs	x10,x10,#1
	bne	updateAC_copy_lp

updateAC_after_copy_lp:
	strb	w6,[x5]

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_5:	str	x30,[x28,#-8]!
	bl	collect_1
	b	r_gc_5

update_string_error:
	adrp	x10,high_index_string
	add	x10,x10,#:lo12:high_index_string
	tst	x5,x5
	bpl	update_string_error_2
	adrp	x10,low_index_string
	add	x10,x10,#:lo12:low_index_string
update_string_error_2:
	b	print_error

	.section .text.eqAC,"ax"
eqAC:
	ldr	x4,[x8,#8]
	ldr	x16,[x9,#8]
	cmp	x4,x16
	bne	equal_string_ne
	add	x8,x8,#16
	add	x9,x9,#16
	and	x3,x4,#7
	lsr	x4,x4,#3
	cbz	x4,equal_string_b
equal_string_1:
	ldr	x10,[x8],#8
	ldr	x16,[x9],#8
	cmp	x10,x16
	bne	equal_string_ne
	subs	x4,x4,#1
	bne	equal_string_1
equal_string_b:
	tbz	x3,#2,equal_string_2
	ldr	w4,[x8],#4
	ldr	w16,[x9],#4
	cmp	x4,x16
	bne	equal_string_ne
equal_string_2:
	tbz	x3,#1,equal_string_3
	ldrh	w4,[x8],#2
	ldrh	w16,[x9],#2
	cmp	x4,x16
	bne	equal_string_ne
equal_string_3:
	tbz	x3,#0,equal_string_eq
	ldrb	w3,[x8]
	ldrb	w16,[x9]
	cmp	x3,x16
	bne	equal_string_ne
equal_string_eq:
	mov	x6,#1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
equal_string_ne:
	mov	x6,#0
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.section .text.cmpAC,"ax"
cmpAC:
	ldr	x3,[x8,#8]
	ldr	x10,[x9,#8]
	add	x8,x8,#16
	add	x9,x9,#16
	cmp	x10,x3
	blo	cmp_string_less
	bhi	cmp_string_more
	mov	x6,#0
	b	cmp_string_chars
cmp_string_more:
	mov	x6,#1
	b	cmp_string_chars
cmp_string_less:
	mov	x6,#-1
	mov	x3,x10
	b	cmp_string_chars

cmp_string_1:
	ldr	x10,[x9],#8
	ldr	x16,[x8],#8
	cmp	x10,x16
	bne	cmp_string_ne8
cmp_string_chars:
	subs	x3,x3,#8
	bcs	cmp_string_1
cmp_string_b:
# to do compare bytes using and instead of ldrb
	tbz	x3,#2,cmp_string_2
	ldr	w10,[x9],#4
	ldr	w16,[x8],#4
	cmp	x10,x16
	beq	cmp_string_2
	rev32	x10,x10
	rev32	x16,x16
	b	cmp_string_ne_cmp
cmp_string_2:
	tbz	x3,#1,cmp_string_3
	ldrh	w10,[x9],#2
	ldrh	w16,[x8],#2
	cmp	x10,x16
	beq	cmp_string_3
	rev16	w10,w10
	rev16	w16,w16
	b	cmp_string_ne_cmp
cmp_string_3:
	tbz	x3,#0,cmp_string_eq
	ldrb	w10,[x9]
	ldrb	w16,[x8]
	cmp	x10,x16
	bne	cmp_string_ne
cmp_string_eq:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

cmp_string_ne8:
	rev	x10,x10
	rev	x16,x16
cmp_string_ne_cmp:
	cmp	x10,x16
cmp_string_ne:
	bhi	cmp_string_r1
	mov	x6,#-1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
cmp_string_r1:
	mov	x6,#1
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.section .text.string_to_string_node,"ax"
string_to_string_node:
	ldr	x10,[x8],#8

	add	x4,x10,#7
	lsr	x4,x4,#3

	add	x16,x4,#2
	subs	x25,x25,x16
	blo	string_to_string_node_gc

string_to_string_node_r:
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	str	x16,[x27]
	str	x10,[x27,#8]
	mov	x10,x27
	add	x27,x27,#16
	b	string_to_string_node_4

string_to_string_node_2:
	ldr	x16,[x8],#8
	str	x16,[x27],#8
string_to_string_node_4:
	subs	x4,x4,#1
	bge	string_to_string_node_2

	mov	x8,x10
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

string_to_string_node_gc:
	stp	x9,x10,[x28,#-16]
	str	x8,[x28,#-24]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldp	x9,x10,[x28,#8]
	ldr	x8,[x28],#24
	b	string_to_string_node_r

	.section .text.int_array_to_node,"ax"
int_array_to_node:
	ldr	x4,[x8,#-8]

	add	x16,x4,#3
	subs	x25,x25,x16
	blo	int_array_to_node_gc

int_array_to_node_r:
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	mov	x9,x8
	str	x4,[x27,#8]
	mov	x8,x27
	adrp	x16,INT+2
	add	x16,x16,#:lo12:INT+2
	str	x16,[x27,#16]
	add	x27,x27,#24
	b	int_array_to_node_4

int_array_to_node_2:
	ldr	x16,[x9],#8
	str	x16,[x27],#8
int_array_to_node_4:
	subs	x4,x4,#1
	bge	int_array_to_node_2

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

int_array_to_node_gc:
	str	x8,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x8,[x28],#8
	b	int_array_to_node_r

	.section .text.real_array_to_node,"ax"
real_array_to_node:
	ldr	x4,[x8,#-16]

	add	x16,x4,#3
	subs	x25,x25,x16
	blo	real_array_to_node_gc

real_array_to_node_r:
	mov	x9,x8
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x4,[x27,#8]
	mov	x8,x27
	adrp	x16,REAL+2
	add	x16,x16,#:lo12:REAL+2
	str	x16,[x27,#16]
	add	x27,x27,#24
	b	real_array_to_node_4

real_array_to_node_2:
	ldr	x16,[x9],#8
	str	x16,[x27],#8
real_array_to_node_4:
	subs	x4,x4,#1
	bge	real_array_to_node_2

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

real_array_to_node_gc:
	str	x8,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x8,[x28],#8
	b	real_array_to_node_r

	.text

	.p2align	2
	.long	3
_c3:	b	__cycle__in__spine
	.p2align	2

	.long	4
_c4:	b	__cycle__in__spine
	.p2align	2
	.long	5
_c5:	b	__cycle__in__spine
	.p2align	2
	.long	6
_c6:	b	__cycle__in__spine
	.p2align	2
	.long	7
_c7:	b	__cycle__in__spine
	.p2align	2
	.long	8
_c8:	b	__cycle__in__spine
	.p2align	2
	.long	9
_c9:	b	__cycle__in__spine
	.p2align	2
	.long	10
_c10:	b	__cycle__in__spine
	.p2align	2
	.long	11
_c11:	b	__cycle__in__spine
	.p2align	2
	.long	12
_c12:	b	__cycle__in__spine
	.p2align	2
	.long	13
_c13:	b	__cycle__in__spine
	.p2align	2
	.long	14
_c14:	b	__cycle__in__spine
	.p2align	2
	.long	15
_c15:	b	__cycle__in__spine
	.p2align	2
	.long	16
_c16:	b	__cycle__in__spine
	.p2align	2
	.long	17
_c17:	b	__cycle__in__spine
	.p2align	2
	.long	18
_c18:	b	__cycle__in__spine
	.p2align	2
	.long	19
_c19:	b	__cycle__in__spine
	.p2align	2
	.long	20
_c20:	b	__cycle__in__spine
	.p2align	2
	.long	21
_c21:	b	__cycle__in__spine
	.p2align	2
	.long	22
_c22:	b	__cycle__in__spine
	.p2align	2
	.long	23
_c23:	b	__cycle__in__spine
	.p2align	2
	.long	24
_c24:	b	__cycle__in__spine
	.p2align	2
	.long	25
_c25:	b	__cycle__in__spine
	.p2align	2
	.long	26
_c26:	b	__cycle__in__spine
	.p2align	2
	.long	27
_c27:	b	__cycle__in__spine
	.p2align	2
	.long	28
_c28:	b	__cycle__in__spine
	.p2align	2
	.long	29
_c29:	b	__cycle__in__spine
	.p2align	2
	.long	30
_c30:	b	__cycle__in__spine
	.p2align	2
	.long	31
_c31:	b	__cycle__in__spine
	.p2align	2
	.long	32
_c32:	b	__cycle__in__spine

#
#	ARRAYS
#/

_create_arrayB:
	add	x3,x6,#7
	lsr	x3,x3,#3

	add	x16,x3,#3
	subs	x25,x25,x16
	bhs	_create_arrayB_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayB_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2
	str	x16,[x27,#16]
	add	x16,x27,#24
	add	x27,x16,x3,lsl #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_arrayC:
	add	x3,x6,#7
	lsr	x3,x3,#3

	add	x16,x3,#2
	subs	x25,x25,x16
	bhs	_create_arrayC_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayC_no_collect:
	mov	x8,x27
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2
	stp	x16,x6,[x27],#16
	mov	x29,x30
	ldr	x30,[x28],#8
	add	x27,x27,x3,lsl #3
	ret	x29

_create_arrayI:
	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	_create_arrayI_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayI_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,INT+2
	add	x16,x16,#:lo12:INT+2
	str	x16,[x27,#16]
	add	x16,x27,#24
	add	x27,x16,x6,lsl #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_arrayR:
	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	_create_arrayR_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayR_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,REAL+2
	add	x16,x16,#:lo12:REAL+2
	str	x16,[x27,#16]
	add	x16,x27,#24
	add	x27,x16,x6,lsl #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_arrayI32:
	add	x6,x6,#1
	lsr	x6,x6,#1
	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	_create_arrayI32_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayI32_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,INT32+2
	add	x16,x16,#:lo12:INT32+2
	str	x16,[x27,#16]
	add	x16,x27,#24
	add	x27,x16,x6,lsl #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_arrayR32:
	add	x6,x6,#1
	lsr	x6,x6,#1
	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	_create_arrayR32_no_collect
	str	x30,[x28,#-8]!
	bl	collect_0
_create_arrayR32_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,REAL32+2
	add	x16,x16,#:lo12:REAL32+2
	str	x16,[x27,#16]
	add	x16,x27,#24
	add	x27,x16,x6,lsl #3
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

# x6: number of elements, x5: element descriptor
# x4: element size, x3: element a size, a0:a_element-> a0: array

_create_r_array:
	mul	x16,x6,x4
	add	x16,x16,#3
	subs	x25,x25,x16
	bhs	_create_r_array_no_collect

	str	x30,[x28,#-8]!
	bl	collect_1

_create_r_array_no_collect:
	mov	x10,x8

	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]

	mov	x8,x27
	add	x27,x27,#24

# x6: number of elements, a0: array
# x4: element size, x3: element a size, a2:a_element

	cmp	x3,#0
	beq	_create_r_array_0
	cmp	x3,#2
	blo	_create_r_array_1
	beq	_create_r_array_2
	cmp	x3,#4
	blo	_create_r_array_3
	beq	_create_r_array_4
	b	_create_r_array_5

_create_r_array_0:
	lsl	x4,x4,#3
	mul	x16,x6,x4
	add	x27,x27,x16
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_r_array_1:
	lsl	x4,x4,#3
	b	_st_fillr1_array
_fillr1_array:
	str	x10,[x27]
	add	x27,x27,x4
_st_fillr1_array:
	subs	x6,x6,#1
	bcs	_fillr1_array
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_r_array_2:
	lsl	x4,x4,#3
	b	_st_fillr2_array
_fillr2_array:
	stp	x10,x10,[x27]
	add	x27,x27,x4
_st_fillr2_array:
	subs	x6,x6,#1
	bcs	_fillr2_array
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_r_array_3:
	lsl	x4,x4,#3
	b	_st_fillr3_array
_fillr3_array:
	stp	x10,x10,[x27]
	str	x10,[x27,#16]
	add	x27,x27,x4
_st_fillr3_array:
	subs	x6,x6,#1
	bcs	_fillr3_array
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_r_array_4:
	lsl	x4,x4,#3
	b	_st_fillr4_array
_fillr4_array:
	stp	x10,x10,[x27]
	stp	x10,x10,[x27,#16]
	add	x27,x27,x4
_st_fillr4_array:
	subs	x6,x6,#1
	bcs	_fillr4_array
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

_create_r_array_5:
	sub	x4,x4,x3
	lsl	x4,x4,#3
	b	_st_fillr5_array

_fillr5_array:
	stp	x10,x10,[x27]
	stp	x10,x10,[x27,#16]
	add	x27,x27,#32

	sub	x5,x3,#5
_copy_elem_5_lp:
	str	x10,[x27],#8
	subs	x5,x5,#1
	bcs	_copy_elem_5_lp

	add	x27,x27,x4
_st_fillr5_array:
	subs	x6,x6,#1
	bcs	_fillr5_array

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

create_arrayB:
	mov	x9,x5
	add	x5,x5,#7
	lsr	x5,x5,#3

	add	x16,x5,#3
	subs	x25,x25,x16
	bhs	create_arrayB_no_collect

	str	x9,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x9,[x28],#8

create_arrayB_no_collect:
	orr	x6,x6,x6,lsl #8

	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2

	orr	x6,x6,x6,lsl #16

	stp	x16,x9,[x27]
	adrp	x16,BOOL+2
	add	x16,x16,#:lo12:BOOL+2

	orr	x6,x6,x6,lsl #32

	str	x16,[x27,#16]
	add	x27,x27,#24
	b	create_arrayBCI

create_arrayC:
	mov	x9,x5
	add	x5,x5,#7
	lsr	x5,x5,#3

	add	x16,x5,#2
	subs	x25,x25,x16
	bhs	no_collect_4578

	str	x9,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x9,[x28],#8

no_collect_4578:
	orr	x6,x6,x6,lsl #8

	mov	x8,x27
	adrp	x16,__STRING__+2
	add	x16,x16,#:lo12:__STRING__+2

	orr	x6,x6,x6,lsl #16

	stp	x16,x9,[x27],#16

	orr	x6,x6,x6,lsl #32

	b	create_arrayBCI

create_arrayI32:
	mov	x9,x5
	add	x5,x5,#1
	lsr	x5,x5,#1

	add	x16,x5,#3
	subs	x25,x25,x16
	bhs	create_arrayI32_no_collect

	str	x9,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x9,[x28],#8

create_arrayI32_no_collect:
	orr	x6,x6,x6,lsl #32

	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x9,[x27,#8]
	adrp	x16,INT32+2
	add	x16,x16,#:lo12:INT32+2
	str	x16,[x27,#16]
	add	x27,x27,#24
	b	create_arrayBCI

create_arrayI:
	add	x16,x5,#3
	subs	x25,x25,x16
	bhs	create_arrayI_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_arrayI_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x5,[x27,#8]
	adrp	x16,INT+2
	add	x16,x16,#:lo12:INT+2
	str	x16,[x27,#16]
	add	x27,x27,#24
create_arrayBCI:
	tst	x5,#1
	lsr	x5,x5,#1
	beq	st_filli_array

	str	x6,[x27],#8
	b	st_filli_array

filli_array:
	stp	x6,x6,[x27],#16
st_filli_array:
	subs	x5,x5,#1
	bcs	filli_array

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

create_arrayR32:
	mov	x9,x6
	add	x5,x6,#1
	lsr	x5,x5,#1

	fcvt	s0,d0
	fmov	w6,s0

	add	x16,x5,#3
	subs	x25,x25,x16
	bhs	create_arrayR32_no_collect

	str	x9,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_0
	ldr	x9,[x28],#8

create_arrayR32_no_collect:
	orr	x6,x6,x6,lsl #32

	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x9,[x27,#8]
	adrp	x16,REAL32+2
	add	x16,x16,#:lo12:REAL32+2
	str	x16,[x27,#16]
	add	x27,x27,#24
	b	create_arrayBCI

create_arrayR:
	add	x16,x6,#3

	fmov	x5,d0

	subs	x25,x25,x16
	bhs	no_collect_4579

	str	x30,[x28,#-8]!
	bl	collect_0

no_collect_4579:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	adrp	x16,REAL+2
	add	x16,x16,#:lo12:REAL+2
	str	x16,[x27,#16]
	add	x27,x27,#24
	b	st_fillr_array
fillr_array:
	str	x5,[x27],#8
st_fillr_array:
	subs	x6,x6,#1
	bcs	fillr_array

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

create_array:
	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	create_array_no_collect

	str	x30,[x28,#-8]!
	bl	collect_1

create_array_no_collect:
	mov	x5,x8
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	mov	x16,#0
	str	x16,[x27,#16]
	add	x27,x27,#24
	mov	x3,x6
	b	fillr1_array

# in x6: number of elements, x5: element descriptor
# x4: element size, x3: element a size -> a0: array

create_R_array:
	cmp	x4,#2
	blo	create_R_array_1
	beq	create_R_array_2
	cmp	x4,#4
	blo	create_R_array_3
	beq	create_R_array_4
	b	create_R_array_5

create_R_array_1:
# x6: number of elements, x5: element descriptor
# x3: element a size

	add	x16,x6,#3
	subs	x25,x25,x16
	bhs	create_R_array_1_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_R_array_1_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]
	add	x27,x27,#24

	cbz	x3,r_array_1_b

	ldr	x5,[x26,#-8]
	b	fillr1_array

r_array_1_b:
	ldr	x5,[x28,#8]

fillr1_array:
	tst	x6,#1
	lsr	x6,x6,#1
	beq	st_fillr1_array_1

	str	x5,[x27],#8
	b	st_fillr1_array_1

fillr1_array_lp:
	stp	x5,x5,[x27],#16
st_fillr1_array_1:
	subs	x6,x6,#1
	bcs	fillr1_array_lp

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

create_R_array_2:
# x6: number of elements, x5: element descriptor
# x3: element a size

	add	x16,x6,x6
	add	x16,x16,#3
	subs	x25,x25,x16
	bhs	create_R_array_2_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_R_array_2_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]
	add	x27,x27,#24

	subs	x3,x3,#1
	blo	r_array_2_bb
	beq	r_array_2_ab
r_array_2_aa:
	ldr	x5,[x26,#-8]
	ldr	x10,[x26,#-16]
	b	st_fillr2_array
r_array_2_ab:
	ldr	x5,[x26,#-8]
	ldr	x10,[x28,#8]
	b	st_fillr2_array
r_array_2_bb:
	ldr	x5,[x28,#8]
	ldr	x10,[x28,#16]
	b	st_fillr2_array

fillr2_array_1:
	stp	x5,x10,[x27],#16
st_fillr2_array:
	subs	x6,x6,#1
	bcs	fillr2_array_1

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

create_R_array_3:
# x6: number of elements, x5: element descriptor
# x3: element a size

	add	x16,x6,x6,lsl #1
	add	x16,x16,#3
	subs	x25,x25,x16
	bhs	create_R_array_3_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_R_array_3_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]
	add	x27,x27,#24

	mov	x29,x30
	ldr	x30,[x28],#8
	mov	x4,x28

	cbz	x3,r_array_3

	sub	x10,x26,x3,lsl #3
	subs	x3,x3,#1

copy_a_to_b_lp3:
	ldr	x16,[x10],#8
	str	x16,[x28,#-8]!
	subs	x3,x3,#1
	bcs	copy_a_to_b_lp3

r_array_3:
	ldr	x5,[x28]
	ldr	x9,[x28,#8]
	ldr	x10,[x28,#16]

	mov	x28,x4
	b	st_fillr3_array

fillr3_array_1:
	stp	x5,x9,[x27]
	str	x10,[x27,#16]
	add	x27,x27,#24
st_fillr3_array:
	subs	x6,x6,#1
	bcs	fillr3_array_1

	ret	x29

create_R_array_4:
# x6: number of elements, x5: element descriptor
# x3: element a size

	lsl	x16,x6,#2
	add	x16,x16,#3
	subs	x25,x25,x16
	bhs	create_R_array_4_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_R_array_4_no_collect:
	mov	x8,x27
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]
	add	x27,x27,#24

	mov	x29,x30
	ldr	x30,[x28],#8
	mov	x4,x28

	cbz	x3,r_array_4
	
	sub	x10,x26,x3,lsl #3
	subs	x3,x3,#1

copy_a_to_b_lp4:
	ldr	x16,[x10],#8
	str	x16,[x28,#-8]!
	subs	x3,x3,#1
	bcs	copy_a_to_b_lp4

r_array_4:
	ldp	x0,x5,[x28]
	ldp	x9,x10,[x28,#16]

	mov	x28,x4
	b	st_fillr4_array

fillr4_array:
	stp	x0,x5,[x27]
	stp	x9,x10,[x27,#16]
	add	x27,x27,#32
st_fillr4_array:
	subs	x6,x6,#1
	bcs	fillr4_array

	ret	x29

create_R_array_5:
# x6: number of elements, x5: element descriptor
# x3: element a size, x4: element size

	mul	x16,x6,x4
	add	x16,x16,#3
	subs	x25,x25,x16
	bhs	create_R_array_5_no_collect

	str	x30,[x28,#-8]!
	bl	collect_0

create_R_array_5_no_collect:
	adrp	x16,__ARRAY__+2
	add	x16,x16,#:lo12:__ARRAY__+2
	str	x16,[x27]
	str	x6,[x27,#8]
	str	x5,[x27,#16]

	mov	x29,x30
	ldr	x30,[x28],#8
	mov	x17,x28

	cbz	x3,r_array_5

	sub	x10,x26,x3,lsl #3
	subs	x3,x3,#1

copy_a_to_b_lp5:
	ldr	x16,[x10],#8
	str	x16,[x28,#-8]!
	subs	x3,x3,#1
	bcs	copy_a_to_b_lp5

r_array_5:
	mov	x8,x27
	add	x27,x27,#24

	ldp	x5,x9,[x28]
	b	st_fillr5_array

fillr5_array_1:
	ldp	x0,x10,[x28,#16]

	stp	x5,x9,[x27]
	sub	x16,x4,#5
	stp	x0,x10,[x27,#16]

	add	x0,x28,#32
	add	x27,x27,#32

copy_elem_lp5:
	ldr	x10,[x0],#8
	str	x10,[x27],#8
	subs	x16,x16,#1
	bcs	copy_elem_lp5

st_fillr5_array:
	subs	x6,x6,#1
	bcs	fillr5_array_1

	mov	x28,x17

	ret	x29

repl_args_b:
	cmp	x6,#0
	ble	repl_args_b_1

	subs	x6,x6,#1
	beq	repl_args_b_4

	ldr	x9,[x8,#16]
	subs	x5,x5,#2
	bne	repl_args_b_2

	str	x9,[x26],#8
	b	repl_args_b_4

repl_args_b_2:
	add	x9,x9,x6,lsl #3

repl_args_b_3:
	ldr	x10,[x9,#-8]!
	str	x10,[x26],#8
	subs	x6,x6,#1
	bne	repl_args_b_3

repl_args_b_4:
	ldr	x10,[x8,#8]
	str	x10,[x26],#8
repl_args_b_1:
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

push_arg_b:
	cmp	x5,#2
	blo	push_arg_b_1
	bne	push_arg_b_2
	cmp	x5,x6
	beq	push_arg_b_1
push_arg_b_2:
	ldr	x8,[x8,#8]
	subs	x5,x5,#2
push_arg_b_1:
	ldr	x8,[x8,x5,lsl #3]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

del_args:
	ldr	x5,[x8]
	subs	x5,x5,x6
	ldrsh	x6,[x5,#-2]
	subs	x6,x6,#2
	bge	del_args_2

	str	x5,[x9]
	ldr	x10,[x8,#4]
	str	x10,[x9,#4]	
	ldr	x10,[x8,#8]
	str	x10,[x9,#8]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

del_args_2:
	bne	del_args_3

	str	x5,[x9]
	ldr	x10,[x8,#4]
	str	x10,[x9,#4]
	ldr	x10,[x8,#8]
	ldr	x10,[x10]
	str	x10,[x9,#8]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

del_args_3:
	subs	x25,x25,x6
	blo	del_args_gc
del_args_r_gc:
	str	x5,[x9]
	str	x27,[x9,#8]
	ldr	x10,[x8,#4]
	ldr	x8,[x8,#8]
	str	x10,[x9,#4]

del_args_copy_args:
	ldr	x10,[x8],#4
	str	x10,[x27],#4
	subs	x6,x6,#1
	bgt	del_args_copy_args

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

del_args_gc:
	bl	collect_2
	b	del_args_r_gc

	.section .text.sin_real,"ax"
sin_real:
	mov	x29,x30
	bl	sin
	ldr	x30,[x28],#8
	ret	x29

	.section .text.cos_real,"ax"
cos_real:
	mov	x29,x30
	bl	cos
	ldr	x30,[x28],#8
	ret	x29

	.section .text.tan_real,"ax"
tan_real:
	mov	x29,x30
	bl	tan
	ldr	x30,[x28],#8
	ret	x29

	.section .text.asin_real,"ax"	
asin_real:
	mov	x29,x30
	bl	asin
	ldr	x30,[x28],#8
	ret	x29

	.section .text.acos_real,"ax"
acos_real:
	mov	x29,x30
	bl	acos
	ldr	x30,[x28],#8
	ret	x29

	.section .text.atan_real,"ax"
atan_real:
	mov	x29,x30
	bl	atan
	ldr	x30,[x28],#8
	ret	x29

	.section .text.ln_real,"ax"
ln_real:
	mov	x29,x30
	bl	log
	ldr	x30,[x28],#8
	ret	x29

	.section .text.log10_real,"ax"
log10_real:
	mov	x29,x30
	bl	log10
	ldr	x30,[x28],#8
	ret	x29

	.section .text.exp_real,"ax"
exp_real:
	mov	x29,x30
	bl	exp
	ldr	x30,[x28],#8
	ret	x29

	.section .text.pow_real,"ax"
pow_real:
	fmov	d2,d0
	fmov	d0,d1
	fmov	d1,d2
	mov	x29,x30
	bl	pow
	ldr	x30,[x28],#8
	ret	x29

	.section .text.entier_real,"ax"
entier_real:
	mov	x29,x30
	bl	floor
	fcvtns	x0,d0
	ldr	x30,[x28],#8
	ret	x29

r_to_i_real:
	fcvtns	x0,d0
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

	.text

	.ltorg

.if NEW_DESCRIPTORS
	.include "arm64ap.s"
.endif
