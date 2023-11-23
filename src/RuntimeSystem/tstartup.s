@
@	File:	 tstartup.s
@	Author:	 John van Groningen
@	Machine: Thumb2

@ B stack registers:     r1 r0 r10 r9 r8
@ A stack registers:     r2 r3 r4 r12 (ip)
@ n free heap words:     r11 (fp)
@ A stack pointer:       r5
@ heap pointer:          r6
@ scratch register:      r7
@ B stack pointer:       r13 (sp)
@ link/scratch register: r14 (lr)

	.syntax unified
	.thumb
	.fpu vfp3

	.include "tmacros.s"

USE_CLIB = 1

SHARE_CHAR_INT = 1
MY_ITOS = 1
FINALIZERS = 1
STACK_OVERFLOW_EXCEPTION_HANDLER = 0
WRITE_HEAP = 0

@ DEBUG = 0
PREFETCH2 = 0

NO_BIT_INSTRUCTIONS = 1
ADJUST_HEAP_SIZE = 1
MARK_GC = 1
MARK_AND_COPY_GC = 1

NEW_DESCRIPTORS = 1

@ #define PROFILE
MODULE_NAMES_IN_TIME_PROFILER = 1

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
	.comm	semi_space_size,4

	.hidden	heap_mbp
	.comm	heap_mbp,4
	.hidden	stack_mbp
	.comm	stack_mbp,4
	.hidden	heap_p
	.comm	heap_p,4
	.hidden	heap_p1
	.comm	heap_p1,4
	.hidden	heap_p2
	.comm	heap_p2,4
	.hidden	heap_p3
	.comm	heap_p3,4
	.hidden	end_heap_p3
	.comm	end_heap_p3,4
	.hidden	heap_size_33
	.comm	heap_size_33,4
	.hidden	vector_p
	.comm	vector_p,4
	.hidden	vector_counter
	.comm	vector_counter,4
	.hidden	neg_heap_vector_plus_4
	.comm	neg_heap_vector_plus_4,4

	.hidden	heap_size_32_33
	.comm	heap_size_32_33,4
	.hidden	heap_vector
	.comm	heap_vector,4
	.hidden stack_top
	.comm	stack_top,4
	.hidden	end_vector
	.comm	end_vector,4

	.hidden	heap_size_129
	.comm	heap_size_129,4
	.hidden	heap_copied_vector
	.comm	heap_copied_vector,4
	.hidden	heap_copied_vector_size
	.comm	heap_copied_vector_size,4
	.hidden	heap_end_after_copy_gc
	.comm	heap_end_after_copy_gc,4

	.hidden	heap_end_after_gc
	.comm	heap_end_after_gc,4
	.hidden	extra_heap
	.comm	extra_heap,4
	.hidden	extra_heap_size
	.comm	extra_heap_size,4
	.hidden	stack_p
	.comm	stack_p,4
	.hidden	halt_sp
	.comm	halt_sp,4

	.hidden	n_allocated_words
	.comm	n_allocated_words,4
	.hidden	basic_only
	.comm	basic_only,4

	.hidden	last_time
	.comm	last_time,4
	.hidden	execute_time
	.comm	execute_time,4
	.hidden	garbage_collect_time
	.comm	garbage_collect_time,4
	.hidden	IO_time
	.comm	IO_time,4

	.globl	saved_heap_p
	.hidden	saved_heap_p
	.comm	saved_heap_p,8

	.globl	saved_a_stack_p
	.hidden	saved_a_stack_p
	.comm	saved_a_stack_p,4

	.globl	end_a_stack
	.hidden	end_a_stack
	.comm	end_a_stack,4

	.globl	end_b_stack
	.hidden	end_b_stack
	.comm	end_b_stack,4

	.hidden	dll_initisialised
	.comm	dll_initisialised,4

.if WRITE_HEAP
	.comm	heap_end_write_heap,4
	.comm	d3_flag_write_heap,4
	.comm	heap2_begin_and_end,8
.endif

.if STACK_OVERFLOW_EXCEPTION_HANDLER
	.comm	a_stack_guard_page,4
.endif

	.globl	profile_stack_pointer
	.hidden	profile_stack_pointer
	.comm	profile_stack_pointer,4

	.data
	.p2align	2

.if MARK_GC
bit_counter:
	.long	0
bit_vector_p:
	.long	0
zero_bits_before_mark:
	.long	1
n_free_words_after_mark:
	.long	1000
n_last_heap_free_bytes:
	.long	0
lazy_array_list:
	.long	0
n_marked_words:
	.long	0
end_stack:
	.long	0
 .if ADJUST_HEAP_SIZE
bit_vector_size:
	.long	0
 .endif
.endif

caf_list:
	.long	0
	.globl	caf_listp
	.hidden	caf_listp
caf_listp:
	.long	0

zero_length_string:
	.long	__STRING__+2
	.long	0
true_string:
	.long	__STRING__+2
	.long	4
true_c_string:
	.ascii	"True"
	.byte	0,0,0,0
false_string:
	.long	__STRING__+2
	.long	5
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
	.comm	sprintf_buffer,32

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
 .if MODULE_NAMES_IN_TIME_PROFILER
  .ifdef LINUX
	.globl	m_system
  .endif
m_system:
	.long	6
	.ascii	"System"
	.byte	0
	.byte	0
	.long	m_system

 .endif
garbage_collector_name:
	.long	0
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
	.comm	small_integers,33*8
	.globl	static_characters
	.hidden	static_characters
	.comm	static_characters,256*8
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
	.globl	_create_r_array
	.globl	create_array
	.globl	create_arrayB
	.globl	create_arrayC
	.globl	create_arrayI
	.globl	create_arrayR
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
@ old name of the previous label for compatibility, remove later
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

@ from system.abc:	
	.globl	INT
	.globl	CHAR
	.globl	BOOL
	.globl	REAL
	.globl	FILE
	.globl	__STRING__
	.globl	__ARRAY__
	.globl	__cycle__in__spine
	.globl	__print__graph
	.globl	__eval__to__nf

@ from wcon.c:
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

@ from standard c library:
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
	.comm	finalizer_list,4
	.globl	free_finalizer_list
	.hidden	free_finalizer_list
	.comm	free_finalizer_list,4
.endif

abc_main:
	str	lr,[sp,#-4]!

	stmdb	sp!,{r4-r11}

.ifdef DLL
	ldr	r1,[sp,#28]
	lao	r7,start_address,0
	sto	r1,r7,start_address,0
.endif
	adr	r14,1+0f
	push	{r14}
	bl	init_clean
0:
	tst	r1,r1
	bne	init_error

	adr	r14,1+0f
	push	{r14}
	bl	init_timer
0:

	lao	r7,halt_sp,0
	sto	sp,r7,halt_sp,0

.ifdef PROFILE
	adr	r14,1+0f
	push	{r14}
	bl	init_profiler
0:
.endif

.ifdef DLL
	lao	r7,start_address,1
	ldo	r1,r7,start_address,1
	adr	r14,1+0f
	push	{r14}
	blx	r1
0:
.else
	adr	r14,1+0f
	push	{r14}
	bl	__start
0:
.endif

exit:
	adr	r14,1+0f
	push	{r14}
	bl	exit_clean
0:

init_error:
	ldmia	sp!,{r4-r11,pc}
	
	.globl	clean_init
clean_init:
	stmdb	sp!,{r4-r11,lr}

	lao	r7,dll_initisialised,0
	mov	r8,#1
	sto	r8,r7,dll_initisialised,0

	adr	r14,1+0f
	push	{r14}
	bl	init_clean
0:
	tst	r1,r1
	bne	init_dll_error

	adr	r14,1+0f
	push	{r14}
	bl	init_timer
0:

	lao	r7,halt_sp,1
	sto	sp,r7,halt_sp,1

 .ifdef PROFILE
	adr	r14,1+0f
	push	{r14}
	bl	init_profiler
0:
 .endif

	lao	r7,saved_heap_p,0
	otoa	r7,saved_heap_p,0
	str	r6,[r7]
	str	r11,[r7,#4]
	lao	r7,saved_a_stack_p,0
	sto	r5,r7,saved_a_stack_p,0

	mov	r1,#1
	b	exit_dll_init

init_dll_error:
	mov	r1,#0
	b	exit_dll_init

	.globl	clean_fini
clean_fini:
	stmdb	sp!,{r4-r11,lr}

	lao	r7,saved_heap_p,1
	otoa	r7,saved_heap_p,1
	ldr	r6,[r7]
	ldr	r11,[r7,#4]
	lao	r7,saved_a_stack_p,1
	ldo	r5,r7,saved_a_stack_p,1

	adr	r14,1+0f
	push	{r14}
	bl	exit_clean
0:

exit_dll_init:
	ldmia	sp!,{r4-r11,pc}

init_clean:
	add	r1,sp,#128
	lao	r7,ab_stack_size,0
	ldo	r7,r7,ab_stack_size,0
	sub	r1,r1,r7
	lao	r7,end_b_stack,0
	sto	r1,r7,end_b_stack,0

	lao	r7,flags,0
	ldo	r1,r7,flags,0
	and	r1,r1,#1
	lao	r7,basic_only,0
	sto	r1,r7,basic_only,0

	lao	r7,heap_size,0
	ldo	r1,r7,heap_size,0
.if PREFETCH2
	subs	r1,r1,#63
.else
	subs	r1,r1,#3
.endif
@	divide by 33
	ldr	r7,=1041204193
	umull	r12,r1,r7,r1
	lsr	r1,r1,#3
	lao	r7,heap_size_33,0
	sto	r1,r7,heap_size_33,0

	lao	r7,heap_size,1
	ldo	r1,r7,heap_size,1
	subs	r1,r1,#3
@	divide by 129
	ldr	r7,=266354561
	umull	r12,r1,r7,r1
	lsr	r1,r1,#3
	lao	r7,heap_size_129,0
	sto	r1,r7,heap_size_129,0
	add	r1,r1,#3
	and	r1,r1,#-4
	lao	r7,heap_copied_vector_size,0
	sto	r1,r7,heap_copied_vector_size,0
	lao	r7,heap_end_after_copy_gc,0
	mov	r12,#0
	sto	r12,r7,heap_end_after_copy_gc,0

	lao	r7,heap_size,2
	ldo	r1,r7,heap_size,2
	add	r1,r1,#7
	and	r1,r1,#-8
.ifdef PIC
	lao	r7,heap_size,3
.endif
	sto	r1,r7,heap_size,3
	add	r1,r1,#7

	mov	r0,r1
	bl	malloc

	movs	r1,r0
	beq	no_memory_2

	lao	r7,heap_mbp,0
	sto	r1,r7,heap_mbp,0
	add	r6,r1,#3
	and	r6,r6,#-4
	lao	r7,heap_p,0
	sto	r6,r7,heap_p,0

	lao	r4,ab_stack_size,1
	ldo	r4,r4,ab_stack_size,1
	add	r4,r4,#3

	mov	r0,r4
.if STACK_OVERFLOW_EXCEPTION_HANDLER
	bl	allocate_memory_with_guard_page_at_end
.else
	bl	malloc
.endif

	movs	r1,r0
	beq	no_memory_3

	lao	r7,stack_mbp,0
	sto	r1,r7,stack_mbp,0
.if STACK_OVERFLOW_EXCEPTION_HANDLER
	lao	r7,ab_stack_size,2
	ldo	r7,r7,ab_stack_size,2
	add	r1,r1,r7
	lao	r7,a_stack_guard_page,0
	add	r1,r1,#4096
	add	r1,r1,#(3+4095)-4096
	bic	r1,r1,#255
	bic	r1,r1,#4095-255
	sto	r1,r7,a_stack_guard_page,0
	lao	r7,ab_stack_size,3
	ldo	r7,r7,ab_stack_size,3
	sub	r1,r1,r7
.endif
	add	r1,r1,#3
	and	r1,r1,#-4

	mov	r5,r1
	lao	r7,stack_p,0
	sto	r1,r7,stack_p,0

	lao	r7,ab_stack_size,4
	ldo	r7,r7,ab_stack_size,4
	add	r1,r1,r7
	subs	r1,r1,#64
	lao	r7,end_a_stack,0
	sto	r1,r7,end_a_stack,0

.if SHARE_CHAR_INT
	lao	r2,small_integers,0
	otoa	r2,small_integers,0
	mov	r1,#0
	laol	r0,INT+2,INT_o_2,0
	otoa	r0,INT_o_2,0

make_small_integers_lp:
	str	r0,[r2]
	str	r1,[r2,#4]
	add	r1,r1,#1
	add	r2,r2,#8
	cmp	r1,#33
	bne	make_small_integers_lp

	lao	r2,static_characters,0
	otoa	r2,static_characters,0
	mov	r1,#0
	laol	r0,CHAR+2,CHAR_O_2,0
	otoa	r0,CHAR_O_2,0

make_static_characters_lp:
	str	r0,[r2]
	str	r1,[r2,#4]
	add	r1,r1,#1
	add	r2,r2,#8
	cmp	r1,#256
	bne	make_static_characters_lp
.endif

	laol	r2,caf_list+4,caf_list_o_4,0
	otoa	r2,caf_list_o_4,0
	lao	r7,caf_listp,0
	sto	r2,r7,caf_listp,0

.if FINALIZERS
	lao	r7,finalizer_list,0
	laol	r12,__Nil-4,__Nil_o_m4,0
	otoa	r12,__Nil_o_m4,0
	sto	r12,r7,finalizer_list,0
	lao	r7,free_finalizer_list,0
	sto	r12,r7,free_finalizer_list,0
.endif

	lao	r7,heap_p1,0
	sto	r6,r7,heap_p1,0

	lao	r7,heap_size_129,1
	ldo	r4,r7,heap_size_129,1
	lsl	r4,r4,#4
	add	r1,r6,r4,lsl #2
	lao	r7,heap_copied_vector,0
	sto	r1,r7,heap_copied_vector,0
	lao	r7,heap_copied_vector_size,1
	ldo	r7,r7,heap_copied_vector_size,1
	add	r1,r7
	lao	r7,heap_p2,0
	sto	r1,r7,heap_p2,0

	lao	r7,garbage_collect_flag,0
	mov	r12,#0
	stob	r12,r7,garbage_collect_flag,0

 .if MARK_AND_COPY_GC
 	lao	r7,flags,1
 	ldo	r7,r7,flags,1
 	tst	r7,#64
	beq	no_mark1
 .endif

 .if MARK_GC || COMPACT_GC_ONLY
	lao	r7,heap_size_33,1
	ldo	r1,r7,heap_size_33,1
	lao	r7,heap_vector,0
	sto	r6,r7,heap_vector,0
	add	r6,r6,r1
  .if PREFETCH2
	add	r6,r6,#63
	and	r6,r6,#-64
  .else
	add	r6,r6,#3
	and	r6,r6,#-4
  .endif
	lao	r7,heap_p3,0
	sto	r6,r7,heap_p3,0
	lsl	r4,r1,#3
	lao	r7,garbage_collect_flag,1
	mov	r12,#-1
	stob	r12,r7,garbage_collect_flag,1
 .endif

 .if MARK_AND_COPY_GC
no_mark1:
 .endif

 .if ADJUST_HEAP_SIZE
 	lao	r1,initial_heap_size,0
 	ldo	r1,r1,initial_heap_size,0
  .if MARK_AND_COPY_GC
	mov	r0,#MINIMUM_HEAP_SIZE_2
	lao	r7,flags,2
	ldo	r7,r7,flags,2
	tst	r7,#64
	bne	no_mark9
	add	r0,r0,r0
no_mark9:
  .else
   .if MARK_GC || COMPACT_GC_ONLY
	mov	r0,#MINIMUM_HEAP_SIZE
   .else
	mov	r0,#MINIMUM_HEAP_SIZE_2
   .endif
  .endif

	cmp	r1,r0
	ble	too_large_or_too_small
	lsr	r1,r1,#2
	cmp	r1,r4
	bge	too_large_or_too_small
	mov	r4,r1
too_large_or_too_small:
 .endif

	add	r1,r6,r4,lsl #2
	lao	r7,heap_end_after_gc,0
	sto	r1,r7,heap_end_after_gc,0

	mov	r11,r4

 .if MARK_AND_COPY_GC
 	lao	r7,flags,3
 	ldo	r7,r7,flags,3
 	tst	r7,#64
	beq	no_mark2
 .endif

 .if MARK_GC && ADJUST_HEAP_SIZE
	lao	r7,bit_vector_size,0
	sto	r4,r7,bit_vector_size,0
 .endif

 .if MARK_AND_COPY_GC
no_mark2:
 .endif

	mov	r1,#0
	pop	{pc}

no_memory_2:
	lao	r0,out_of_memory_string_1,0
	otoa	r0,out_of_memory_string_1,0
	bl	ew_print_string
.ifdef _WINDOWS_
?	movl	$1,@execution_aborted
.endif
	mov	r1,#1
	pop	{pc}

no_memory_3:
	lao	r0,out_of_memory_string_1,1
	otoa	r0,out_of_memory_string_1,1
	bl	ew_print_string
.ifdef _WINDOWS_
?	movl	$1,@execution_aborted
.endif

	lao	r0,heap_mbp,1
	ldo	r0,r0,heap_mbp,1
	bl	free

	mov	r1,#1
	pop	{pc}

exit_clean:
	adr	r14,1+0f
	push	{r14}
	bl	add_execute_time
0:
	lao	r1,flags,4
	ldo	r1,r1,flags,4
	tst	r1,#8
	beq	no_print_execution_time

	lao	r0,time_string_1,0
	otoa	r0,time_string_1,0
	bl	ew_print_string

	lao	r7,execute_time,0
	ldo	r1,r7,execute_time,0

	adr	r14,1+0f
	push	{r14}
	bl	print_time
0:
	lao	r0,time_string_2,0
	otoa	r0,time_string_2,0
	bl	ew_print_string

	lao	r7,garbage_collect_time,0
	ldo	r1,r7,garbage_collect_time,0

	adr	r14,1+0f
	push	{r14}
	bl	print_time
0:
	lao	r0,time_string_4,0
	otoa	r0,time_string_4,0
	bl	ew_print_string

	lao	r7,execute_time,1
	ldo	r1,r7,execute_time,1
	lao	r7,garbage_collect_time,1
	ldo	r7,r7,garbage_collect_time,1
	add	r1,r7
	lao	r7,IO_time,0
	ldo	r7,r7,IO_time,0
	add	r1,r7

	adr	r14,1+0f
	push	{r14}
	bl	print_time
0:
	mov	r0,#10
	bl	ew_print_char

no_print_execution_time:
	lao	r0,stack_mbp,1
	ldo	r0,r0,stack_mbp,1
	bl	free

	lao	r0,heap_mbp,2
	ldo	r0,r0,heap_mbp,2
	bl	free

.ifdef PROFILE
 .ifndef TRACE
	adr	r14,1+0f
	push	{r14}
	bl	write_profile_information
0:
 .endif
.endif
	pop	{pc}

__driver:
	lao	r4,flags,5
	ldo	r4,r4,flags,5
	tst	r4,#16
	beq	__print__graph
	b	__eval__to__nf

.ifdef PIC
 .ifdef DLL
	lto	start_address,0
 .endif
	lto	halt_sp,0
 .ifdef DLL
	lto	start_address,1
 .endif
	lto	dll_initisialised,0
	lto	halt_sp,1
	lto	saved_heap_p,0
	lto	saved_a_stack_p,0
	lto	saved_heap_p,1
	lto	saved_a_stack_p,1
	lto	ab_stack_size,0
	lto	end_b_stack,0
	lto	flags,0
	lto	basic_only,0
	lto	heap_size,0
	lto	heap_size_33,0
	lto	heap_size,1
	lto	heap_size_129,0
	lto	heap_copied_vector_size,0
	lto	heap_end_after_copy_gc,0
	lto	heap_size,2
	lto	heap_size,3
	lto	heap_mbp,0
	lto	heap_p,0
	lto	ab_stack_size,1
	lto	stack_mbp,0
 .if STACK_OVERFLOW_EXCEPTION_HANDLER
	lto	ab_stack_size,2
	lto	a_stack_guard_page,0
	lto	ab_stack_size,3
 .endif
	lto	stack_p,0
	lto	ab_stack_size,4
	lto	end_a_stack,0
	lto	small_integers,0
	ltol	INT+2,INT_o_2,0
	lto	static_characters,0
	ltol	CHAR+2,CHAR_O_2,0
	ltol	caf_list+4,caf_list_o_4,0
	lto	caf_listp,0
 .if FINALIZERS
	lto	finalizer_list,0
	ltol	__Nil-4,__Nil_o_m4,0
	lto	free_finalizer_list,0
 .endif
 	lto	heap_p1,0
	lto	heap_size_129,1
	lto	heap_copied_vector,0
	lto	heap_copied_vector_size,1
	lto	heap_p2,0
	lto	garbage_collect_flag,0
 .if MARK_AND_COPY_GC
	lto	flags,1
 .endif
 .if MARK_GC || COMPACT_GC_ONLY
	lto	heap_size_33,1
	lto	heap_vector,0
	lto	heap_p3,0
 	lto	garbage_collect_flag,1
 .endif
 .if ADJUST_HEAP_SIZE
 	lto	initial_heap_size,0
  .if MARK_AND_COPY_GC
	lto	flags,2
  .endif
 .endif
 	lto	heap_end_after_gc,0
 .if MARK_AND_COPY_GC
	lto	flags,3
 .endif
 .if MARK_GC && ADJUST_HEAP_SIZE
	lto	bit_vector_size,0
 .endif
	lto	out_of_memory_string_1,0
	lto	out_of_memory_string_1,1
	lto	heap_mbp,1
	lto	flags,4
	lto	time_string_1,0
	lto	execute_time,0
	lto	time_string_2,0
	lto	garbage_collect_time,0
	lto	time_string_4,0
	lto	execute_time,1
	lto	garbage_collect_time,1
	lto	IO_time,0
	lto	stack_mbp,1
	lto	heap_mbp,2
	lto	flags,5
.endif
	.ltorg

print_time:
@	divide by 1000
	ldr	r7,=274877907
	umull	r12,r2,r7,r1
	lsr	r2,r2,#6

	mov	r12,#-1025
	add	r12,r12,#-1000-(-1025)
	mla	r1,r2,r12,r1

@	divide by 10
	ldr	r7,=-858993459
	umull	r12,r1,r7,r1
	lsr	r1,r1,#3

.if USE_CLIB
	mov	r3,r1
	lao	r1,sprintf_time_string,0
	lao	r0,sprintf_time_buffer,0
	otoa	r1,sprintf_time_string,0
	otoa	r0,sprintf_time_buffer,0
	bl	sprintf

	lao	r0,sprintf_time_buffer,1
	otoa	r0,sprintf_time_buffer,1
	bl	ew_print_string
.else
	mov	r0,r2
	bl	ew_print_int

	lao	r2,sprintf_time_buffer,0
	otoa	r2,sprintf_time_buffer,0

	eor	r3,r3,r3
	mov	r0,#10

	mov	r7,#46
	strb	r7,[r2]

@	divide by 10
	ldr	r7,=-858993459
	umull	r12,r8,r7,r1
	lsr	r8,r8,#3

	sub	r1,r1,r8,lsl #1
	sub	r1,r1,r8,lsl #3

	add	r1,r1,#48
	add	r3,r3,#48
	strb	r8,[r2,#1]
	strb	r1,[r2,#2]

	mov	r1,#3
	mov	r0,r2
	bl	ew_print_text
.endif
	pop	{pc}

print_sc:
	lao	r7,basic_only,1
	ldo	r4,r7,basic_only,1
	cmp	r4,#0
	bne	end_print

print:
	mov	r0,r1
	bl	w_print_string

end_print:
	pop	{pc}

dump:
	adr	r14,1+0f
	push	{r14}
	bl	print
0:
	b	halt

printD:	tst	r1,#2
	bne	printD_

	mov	r4,r1
	b	print_string_a2

DtoAC_record:
	ldr	r4,[r1,#-6]
@.ifdef PIC
.if 0
	add	r7,r1,#-6
	add	r4,r4,r7
.endif
	b	DtoAC_string_a2

DtoAC:	tst	r1,#2
	bne	DtoAC_

	mov	r4,r1
	b	DtoAC_string_a2

DtoAC_:
	ldrh	r7,[r1,#-2]
	cmp	r7,#256
	bhs	DtoAC_record

  	ldrh	r0,[r1]
  	add	r7,r1,#10
  	add	r4,r7,r0

DtoAC_string_a2:
	ldr	r1,[r4]
	add	r2,r4,#4
	b	build_string

print_symbol:
	mov	r0,#0
	b	print_symbol_2

print_symbol_sc:
	lao	r7,basic_only,2
	ldo	r0,r7,basic_only,2
print_symbol_2:
	ldr	r1,[r2]

	laol	r7,INT+2,INT_o_2,1
	otoa	r7,INT_o_2,1
	cmp	r1,r7
	beq	print_int_node

	laol	r7,CHAR+2,CHAR_o_2,0
	otoa	r7,CHAR_o_2,0
	cmp	r1,r7
	beq	print_char_denotation

	laol	r7,BOOL+2,BOOL_o_2,0
	otoa	r7,BOOL_o_2,0
	cmp	r1,r7
	beq	print_bool

	laol	r7,REAL+2,REAL_o_2,0
	otoa	r7,REAL_o_2,0
	cmp	r1,r7
	beq	print_real_node

	cmp	r0,#0
	bne	end_print_symbol

printD_:
	ldrh	r7,[r1,#-2]
	cmp	r7,#256
	bhs	print_record

  	ldrh	r0,[r1]
  	add	r7,r1,#10
  	add	r4,r7,r0
	b	print_string_a2

print_record:
	ldr	r4,[r1,#-6]
@.ifdef PIC
.if 0
	add	r7,r1,#-6
	add	r4,r4,r7
.endif
	b	print_string_a2

end_print_symbol:
	pop	{pc}

print_int_node:
	ldr	r0,[r2,#4]
	bl	w_print_int
	pop	{pc}

print_int:
	mov	r0,r1
	bl	w_print_int
	pop	{pc}

print_char_denotation:
	tst	r0,r0
	bne	print_char_node

	ldr	r7,[r2,#4]
	str	r7,[sp,#-4]!

	mov	r0,#0x27
	bl	w_print_char

	ldr	r0,[sp],#4
	bl	w_print_char

	mov	r0,#0x27
	bl	w_print_char

	pop	{pc}

print_char_node:
	ldr	r0,[r2,#4]
	bl	w_print_char
	pop	{pc}

print_char:
	mov	r0,r1
	bl	w_print_char
	pop	{pc}

print_bool:
	ldsb	r2,[r2,#4]
	tst	r2,r2
	beq	print_false

print_true:
	lao	r0,true_c_string,0
	otoa	r0,true_c_string,0
	bl	w_print_string
	pop	{pc}

print_false:
	lao	r0,false_c_string,0
	otoa	r0,false_c_string,0
	bl	w_print_string
	pop	{pc}

print_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	b	print_real_
print_real_node:
.ifdef SOFT_FP_CC
	ldrd	r0,r1,[r2,#4]
.else
	vldr.f64 d0,[r2,#4]
.endif
print_real_:
	mov	r7,sp
	bic	r12,r7,#7
	mov	sp,r12
	bl	w_print_real
	mov	sp,r7
	pop	{pc}

print_string_a2:
	ldr	r1,[r4]
	add	r0,r4,#4
	bl	w_print_text
	pop	{pc}

print__chars__sc:
	lao	r7,basic_only,3
	ldo	r4,r7,basic_only,3
	cmp	r4,#0
	bne	no_print_chars

print__string__:
	ldr	r1,[r2,#4]
	add	r0,r2,#8
	bl	w_print_text
no_print_chars:
	pop	{pc}

push_a_r_args:
	str	r6,[sp,#-4]!

	ldr	r3,[r2,#8]
	subs	r3,r3,#2
	ldrh	r6,[r3]
	subs	r6,r6,#256
	ldrh	r0,[r3,#2]
	add	r3,r3,#4
	str	r3,[sp,#-4]!

	mov	r3,r6
	subs	r3,r3,r0

	lsl	r1,r1,#2
	add	r7,r2,#12
	add	r2,r7,r0,lsl #2
	subs	r6,r6,#1
mul_array_size_lp:
	add	r2,r2,r1
	subs	r6,r6,#1
	bcs	mul_array_size_lp

	add	r6,r2,r3,lsl #2
	b	push_a_elements
push_a_elements_lp:
	ldr	r1,[r2,#-4]!
	str	r1,[r5],#4
push_a_elements:
	subs	r0,r0,#1
	bcs	push_a_elements_lp

	mov	r2,r6
	ldr	r1,[sp],#4
	ldr	r6,[sp],#4

	ldr	r4,[sp],#4
	b	push_b_elements
push_b_elements_lp:
	ldr	r7,[r2,#-4]!
	str	r7,[sp,#-4]!
push_b_elements:
	subs	r3,r3,#1
	bcs	push_b_elements_lp

	mov	pc,r4

push_t_r_args:
	ldr	r4,[sp],#4

	ldr	r3,[r2]
	add	r2,r2,#4
	subs	r3,r3,#2
	ldrh	r1,[r3]
	subs	r1,r1,#256
	ldrh	r0,[r3,#2]
	add	r3,r3,#4

	str	r3,[r5]
	str	r0,[r5,#4]

	sub	r0,r1,r0

	add	r3,r2,r1,lsl #2
	cmp	r1,#2
	bls	small_record
	ldr	r3,[r2,#4]
	add	r7,r3,#-4
	add	r3,r7,r1,lsl #2
small_record:
	b	push_r_b_elements

push_r_b_elements_lp:
	subs	r1,r1,#1
	bne	not_first_arg_b

	ldr	r7,[r2]
	str	r7,[sp,#-4]!
	b	push_r_b_elements
not_first_arg_b:
	ldr	r7,[r3,#-4]!
	str	r7,[sp,#-4]!
push_r_b_elements:
	subs	r0,r0,#1
	bcs	push_r_b_elements_lp

	ldr	r0,[r5,#4]
	str	r4,[sp,#-4]!
	ldr	r7,[r5]
	str	r7,[sp,#-4]!
	b	push_r_a_elements

push_r_a_elements_lp:
	subs	r1,r1,#1
	bne	not_first_arg_a

	ldr	r4,[r2]
	str	r4,[r5],#4
	b	push_r_a_elements
not_first_arg_a:
	ldr	r4,[r3,#-4]!
	str	r4,[r5],#4
push_r_a_elements:
	subs	r0,r0,#1
	bcs	push_r_a_elements_lp

	ldr	r1,[sp],#4
	pop	{pc}

repl_r_a_args_n_a:
	ldr	r3,[r2]
	ldrh	r1,[r3]
	cmp	r1,#0
	beq	repl_r_a_args_n_a_0
	cmp	r1,#2
	blo	repl_r_a_args_n_a_1
	ldr	r4,[r2,#4]
	beq	repl_r_a_args_n_a_2

	sub	r1,r0,#1
	add	r3,r4,r1,lsl #2

repl_r_a_args_n_a_4:
	ldr	r4,[r3,#-4]!
	str	r4,[r5],#4
	subs	r0,r0,#1
	bne	repl_r_a_args_n_a_4

repl_r_a_args_n_a_1:
	ldr	r4,[r2,#4]
	str	r4,[r5],#4
repl_r_a_args_n_a_0:
	pop	{pc}

repl_r_a_args_n_a_2:
	ldrb	r1,[r3,#-2]
	cmp	r1,#2
	beq	repl_r_a_args_n_a_3
	ldr	r4,[r4]
repl_r_a_args_n_a_3:
	str	r4,[r5],#4
	b	repl_r_a_args_n_a_1

BtoAC:
	tst	r1,r1
	beq	BtoAC_false
BtoAC_true:
	lao	r2,true_string,0
	otoa	r2,true_string,0
	pop	{pc}
BtoAC_false:
	lao	r2,false_string,0
	otoa	r2,false_string,0
	pop	{pc}

RtoAC:
.if USE_CLIB
	vmov	r2,r3,d0
	lao	r1,printf_real_string,0
	lao	r0,sprintf_buffer,0
	otoa	r1,printf_real_string,0
	otoa	r0,sprintf_buffer,0
	mov	r7,sp
	and	r12,r7,#-8
	mov	sp,r12
	bl	sprintf
	mov	sp,r7
.else
	lao	r0,sprintf_buffer,1
	otoa	r0,sprintf_buffer,1
	bl	convert_real_to_string
.endif
	b	return_sprintf_buffer

ItoAC:
.if MY_ITOS
	lao	r2,sprintf_buffer,2
	otoa	r2,sprintf_buffer,2
	adr	r14,1+0f
	push	{r14}
	bl	int_to_string
0:
	lao	r7,sprintf_buffer,3
	otoa	r7,sprintf_buffer,3
	sub	r1,r2,r7
	b	sprintf_buffer_to_string

int_to_string:
	tst	r1,r1
	bpl	no_minus
	mov	r7,#45
	strb	r7,[r2],#1
	neg	r1,r1
no_minus:
	add	r4,r2,#12

	beq	zero_digit

	ldr	r10,=0xcccccccd 

calculate_digits:
	cmp	r1,#10
	blo	last_digit

	umull	r7,r3,r10,r1
	add	r0,r1,#48

	lsr	r1,r3,#3

	and	r3,r3,#-8
	sub	r0,r0,r3
	sub	r0,r0,r3,lsr #2
	strb	r0,[r4],#1
	b	calculate_digits

last_digit:
	tst	r1,r1
	beq	no_zero
zero_digit:
	add	r1,r1,#48
	strb	r1,[r4],#1
no_zero:
	add	r3,r2,#12

reverse_digits:
	ldrb	r0,[r4,#-1]!
	strb	r0,[r2],#1
	cmp	r3,r4
	bne	reverse_digits

	mov	r7,#0
	strb	r7,[r2]
	pop	{pc}
.else
	mov	r2,r1
	lao	r1,printf_int_string,0
	lao	r0,sprintf_buffer,4
	otoa	r1,printf_int_string,0
	otoa	r0,sprintf_buffer,4
	bl	sprintf
.endif

return_sprintf_buffer:
.if USE_CLIB
	lao	r0,sprintf_buffer,5
	otoa	r0,sprintf_buffer,5
	bl	strlen
	mov	r1,r0
.else
	laol	r1,sprintf_buffer-1,sprintf_buffer_o_m1,0
	otoa	r1,sprintf_buffer_o_m1,0
skip_characters:
	ldrb	r7,[r1,#1]!
	tst	r7,r7
	bne	skip_characters

	lao	r7,sprintf_buffer,6
	otoa	r7,sprintf_buffer,6
	sub	r1,r1,r7
.endif

.if MY_ITOS
sprintf_buffer_to_string:
	lao	r2,sprintf_buffer,7
	otoa	r2,sprintf_buffer,7
build_string:
.endif
	add	r0,r1,#3
	lsr	r0,r0,#2
	add	r0,r0,#2

	subs	r11,r11,r0
	bhs	D_to_S_no_gc

	str	r2,[sp,#-4]!
	bl	collect_0
	ldr	r2,[sp],#4

D_to_S_no_gc:
	subs	r0,r0,#2
	mov	r4,r6
	laol	r7,__STRING__+2,__STRING___o_2,0
	otoa	r7,__STRING___o_2,0
	str	r1,[r6,#4]
	str	r7,[r6],#8
	b	D_to_S_cp_str_2

D_to_S_cp_str_1:
	ldr	r1,[r2],#4
	str	r1,[r6],#4
D_to_S_cp_str_2:
	subs	r0,r0,#1
	bcs	D_to_S_cp_str_1

	mov	r2,r4
	pop	{pc}

eqD:	ldr	r1,[r2]
	ldr	r7,[r3]
	cmp	r1,r7
	bne	eqD_false

	laol	r7,INT+2,INT_o_2,2
	otoa	r7,INT_o_2,2
	cmp	r1,r7
	beq	eqD_INT
	laol	r7,CHAR+2,CHAR_o_2,1
	otoa	r7,CHAR_o_2,1
	cmp	r1,r7
	beq	eqD_CHAR
	laol	r7,BOOL+2,BOOL_o_2,1
	otoa	r7,BOOL_o_2,1
	cmp	r1,r7
	beq	eqD_BOOL
	laol	r7,REAL+2,REAL_o_2,1
	otoa	r7,REAL_o_2,1
	cmp	r1,r7
	beq	eqD_REAL

	mov	r1,#1
	pop	{pc}

eqD_CHAR:
eqD_INT:
	ldr	r0,[r2,#4]
	mov	r1,#0
	ldr	r7,[r3,#4]
	cmp	r0,r7
	it	eq
	moveq	r1,#1
	pop	{pc}

eqD_BOOL:
	ldrb	r0,[r2,#4]
	mov	r1,#0
	ldrb	r7,[r3,#4]
	cmp	r0,r7
	it	eq
	moveq	r1,#1
	pop	{pc}

eqD_REAL:
	vldr.f64 d0,[r2,#4]
	vldr.f64 d1,[r3,#4]
	mov	r1,#0
	vcmp.f64 d1,d0
	vmrs	APSR_nzcv,fpscr
	it	eq
	moveq	r1,#1
	pop	{pc}

eqD_false:
	mov	r1,#0
	pop	{pc}
@
@	the timer
@

init_timer:
	sub	sp,sp,#20
	mov	r0,sp
	bl	times
	ldr	r1,[sp]
	add	r1,r1,r1
	add	r1,r1,r1,lsl #2
	add	sp,sp,#20

	lao	r7,last_time,0
	sto	r1,r7,last_time,0
	eor	r1,r1,r1
	lao	r7,execute_time,2
	sto	r1,r7,execute_time,2
	lao	r7,garbage_collect_time,2
	sto	r1,r7,garbage_collect_time,2
	lao	r7,IO_time,1
	sto	r1,r7,IO_time,1

	pop	{pc}

get_time_diff:
	sub	sp,sp,#20
	mov	r0,sp
	bl	times
	ldr	r1,[sp]
	add	r1,r1,r1
	add	r1,r1,r1,lsl #2
	add	sp,sp,#20

	lao	r2,last_time,1
	otoa	r2,last_time,1
	ldr	r3,[r2]
	str	r1,[r2]
	subs	r1,r1,r3
	pop	{pc}

add_execute_time:
	adr	r14,1+0f
	push	{r14}
	bl	get_time_diff
0:
	lao	r2,execute_time,3
	otoa	r2,execute_time,3

add_time:
	ldr	r7,[r2]
	add	r1,r1,r7
	str	r1,[r2]
	pop	{pc}

add_garbage_collect_time:
	adr	r14,1+0f
	push	{r14}
	bl	get_time_diff
0:
	lao	r2,garbage_collect_time,3
	otoa	r2,garbage_collect_time,3
	b	add_time

add_IO_time:
	adr	r14,1+0f
	push	{r14}
	bl	get_time_diff
0:
	lao	r2,IO_time,2
	otoa	r2,IO_time,2
	b	add_time

.ifdef PIC
	lto	sprintf_time_string,0
	lto	sprintf_time_buffer,0
 .if USE_CLIB
	lto	sprintf_time_buffer,1
 .endif
	lto	basic_only,1
	lto	basic_only,2
	ltol	INT+2,INT_o_2,1
	ltol	CHAR+2,CHAR_o_2,0
	ltol	BOOL+2,BOOL_o_2,0
	ltol	REAL+2,REAL_o_2,0
	lto	true_c_string,0
	lto	false_c_string,0
	lto	basic_only,3
	lto	true_string,0
	lto	false_string,0
 .if USE_CLIB
	lto	printf_real_string,0
	lto	sprintf_buffer,0
 .else
	lto	sprintf_buffer,1
 .endif
 .if MY_ITOS
	lto	sprintf_buffer,2
	lto	sprintf_buffer,3
 .else
	lto	printf_int_string,0
	lto	sprintf_buffer,4
 .endif
 .if USE_CLIB
	lto	sprintf_buffer,5
 .else
	ltol	sprintf_buffer-1,sprintf_buffer_o_m1,0
	lto	sprintf_buffer,6
 .endif
 .if MY_ITOS
	lto	sprintf_buffer,7
 .endif
	ltol	__STRING__+2,__STRING___o_2,0
	ltol	INT+2,INT_o_2,2
	ltol	CHAR+2,CHAR_o_2,1
	ltol	BOOL+2,BOOL_o_2,1
	ltol	REAL+2,REAL_o_2,1
	lto	last_time,0
	lto	execute_time,2
	lto	garbage_collect_time,2
	lto	IO_time,1
	lto	last_time,1
	lto	execute_time,3
	lto	garbage_collect_time,3
	lto	IO_time,2
.endif
	.ltorg
.ifdef PIC
 .ifdef PROFILE
	lto	garbage_collector_name,0
	lto	garbage_collector_name,1
	lto	garbage_collector_name,2
	lto	garbage_collector_name,3
 .endif
	lto	heap_end_after_gc,1
	lto	n_allocated_words,0
 .if MARK_AND_COPY_GC
	lto	flags,6
 .endif
 .if MARK_GC
	lto	bit_counter,0
	lto	n_allocated_words,1
	lto	bit_vector_p,0
	lto	n_free_words_after_mark,0
	lto	bit_counter,1
	lto	bit_vector_p,1
	lto	n_free_words_after_mark,1
	lto	heap_vector,1
	lto	heap_p3,1
	lto	heap_end_after_gc,2
	lto	bit_counter,2
	lto	n_free_words_after_mark,2
 .endif
	lto	garbage_collect_flag,2
	lto	garbage_collect_flag,3
	lto	extra_heap_size,0
	lto	extra_heap,0
	lto	heap_end_after_gc,3
	lto	flags,7
	lto	garbage_collect_string_1,0
	lto	stack_p,1
	lto	garbage_collect_string_2,0
	lto	halt_sp,2
	lto	garbage_collect_string_3,0
	lto	stack_p,2
	lto	ab_stack_size,5
.endif

@
@	the garbage collector
@

collect_3:
	str	lr,[sp,#-4]!
.ifdef PROFILE
	lao	r7,garbage_collector_name,0
	otoa	r7,garbage_collector_name,0
	bl	profile_s
.endif
	str	r2,[r5]
	str	r3,[r5,#4]
	str	r4,[r5,#8]
	add	r5,r5,#12
	bl	collect_0_
	ldr	r4,[r5,#-4]
	ldr	r3,[r5,#-8]
	ldr	r2,[r5,#-12]!
.ifdef PROFILE
	b	profile_r
.else
	pop	{pc}
.endif

collect_2:
	str	lr,[sp,#-4]!
.ifdef PROFILE
	lao	r7,garbage_collector_name,1
	otoa	r7,garbage_collector_name,1
	bl	profile_s
.endif
	str	r2,[r5]
	str	r3,[r5,#4]
	add	r5,r5,#8
	bl	collect_0_
	ldr	r3,[r5,#-4]
	ldr	r2,[r5,#-8]!
.ifdef PROFILE
	b	profile_r
.else
	pop	{pc}
.endif

collect_1:
	str	lr,[sp,#-4]!
.ifdef PROFILE
	lao	r7,garbage_collector_name,2
	otoa	r7,garbage_collector_name,2
	bl	profile_s
.endif
	str	r2,[r5],#4
	bl	collect_0_
	ldr	r2,[r5,#-4]!
.ifdef PROFILE
	b	profile_r
.else
	pop	{pc}
.endif

.ifdef PROFILE
collect_0:
	str	lr,[sp,#-4]!
	lao	r7,garbage_collector_name,3
	otoa	r7,garbage_collector_name,3
	bl	profile_s
	bl	collect_0_
	b	profile_r
.endif

.ifndef PROFILE
collect_0:
.endif
collect_0_:
	stmdb	sp!,{r0-r1,r8-r10,lr}

	lao	r7,heap_end_after_gc,1
	ldo	r7,r7,heap_end_after_gc,1
	sub	r4,r7,r6
	lsr	r4,r4,#2
	sub	r4,r4,r11
	lao	r7,n_allocated_words,0
	sto	r4,r7,n_allocated_words,0

.if MARK_AND_COPY_GC
	lao	r7,flags,6
	ldo	r7,r7,flags,6
	tst	r7,#64
	beq	no_mark3
.endif

.if MARK_GC
	lao	r7,bit_counter,0
	ldo	r4,r7,bit_counter,0
	cmp	r4,#0
	beq	no_scan

	mov	r0,#0
	str	r5,[sp,#-4]!

	lao	r7,n_allocated_words,1
	ldo	r5,r7,n_allocated_words,1
	lao	r7,bit_vector_p,0
	ldo	r2,r7,bit_vector_p,0
	lao	r7,n_free_words_after_mark,0
	ldo	r10,r7,n_free_words_after_mark,0

scan_bits:
	ldr	r7,[r2]
	cmp	r0,r7
	beq	zero_bits
	str	r0,[r2],#4
	subs	r4,r4,#1
	bne	scan_bits

	b	end_scan

zero_bits:
	add	r3,r2,#4
	add	r2,r2,#4
	subs	r4,r4,#1
	bne	skip_zero_bits_lp1
	b	end_bits

skip_zero_bits_lp:
	cmp	r1,#0
	bne	end_zero_bits
skip_zero_bits_lp1:
	ldr	r1,[r2],#4
	subs	r4,r4,#1
	bne	skip_zero_bits_lp

	cmp	r1,#0
	beq	end_bits
	str	r0,[r2,#-4]
	subs	r1,r2,r3
	b	end_bits2

end_zero_bits:
	sub	r1,r2,r3
	lsl	r1,r1,#3
	str	r0,[r2,#-4]
	add	r10,r10,r1

	cmp	r1,r5
	blo	scan_bits

found_free_memory:
	lao	r7,bit_counter,1
	sto	r4,r7,bit_counter,1
	lao	r7,bit_vector_p,1
	sto	r2,r7,bit_vector_p,1
	lao	r7,n_free_words_after_mark,1
	sto	r10,r7,n_free_words_after_mark,1

	sub	r11,r1,r5

	add	r4,r3,#-4
	lao	r7,heap_vector,1
	ldo	r7,r7,heap_vector,1
	subs	r4,r4,r7
	lsl	r4,r4,#5
	lao	r7,heap_p3,1
	ldo	r6,r7,heap_p3,1
	add	r6,r6,r4

	add	r4,r6,r1,lsl #2
	lao	r7,heap_end_after_gc,2
	sto	r4,r7,heap_end_after_gc,2

	ldr	r5,[sp],#4

	ldmia	sp!,{r0-r1,r8-r10,pc}

end_bits:
	sub	r1,r2,r3
	add	r1,r1,#4
end_bits2:
	lsl	r1,r1,#3
	add	r10,r10,r1
	cmp	r1,r5
	bhs	found_free_memory

end_scan:
	ldr	r5,[sp],#4
	lao	r7,bit_counter,2
	sto	r4,r7,bit_counter,2
	lao	r7,n_free_words_after_mark,2
	sto	r10,r7,n_free_words_after_mark,2

no_scan:
.endif

@ to do: check value in r4

.if MARK_AND_COPY_GC
no_mark3:
.endif

	lao	r7,garbage_collect_flag,2
	ldosb	r1,r7,garbage_collect_flag,2
	cmp	r1,#0
	ble	collect

.ifdef PIC
	lao	r7,garbage_collect_flag,3
.endif
	sub	r1,r1,#2
	stob	r1,r7,garbage_collect_flag,3

	lao	r7,extra_heap_size,0
	ldo	r0,r7,extra_heap_size,0
	cmp	r4,r0
	bhi	collect

	sub	r11,r0,r4

	lao	r7,extra_heap,0
	ldo	r6,r7,extra_heap,0
	add	r0,r6,r0,lsl #2
	lao	r7,heap_end_after_gc,3
	sto	r0,r7,heap_end_after_gc,3

	ldmia	sp!,{r0-r1,r8-r10,pc}

collect:
	adr	r14,1+0f
	push	{r14}
	bl	add_execute_time
0:
	lao	r7,flags,7
	ldo	r7,r7,flags,7
	tst	r7,#4
	beq	no_print_stack_sizes

	lao	r0,garbage_collect_string_1,0
	otoa	r0,garbage_collect_string_1,0
	bl	ew_print_string

	mov	r1,r5
	lao	r7,stack_p,1
	ldo	r7,r7,stack_p,1
	sub	r0,r1,r7
	bl	ew_print_int

	lao	r0,garbage_collect_string_2,0
	otoa	r0,garbage_collect_string_2,0
	bl	ew_print_string

	lao	r7,halt_sp,2
	ldo	r1,r7,halt_sp,2
	mov	r0,sp
	sub	r0,r1,r0
	bl	ew_print_int

	lao	r0,garbage_collect_string_3,0
	otoa	r0,garbage_collect_string_3,0
	bl	ew_print_string

no_print_stack_sizes:
	lao	r7,stack_p,2
	ldo	r1,r7,stack_p,2
	lao	r7,ab_stack_size,5
	ldo	r7,r7,ab_stack_size,5
	add	r1,r1,r7
	cmp	r5,r1
	bhi	stack_overflow

.if MARK_AND_COPY_GC
	lao	r7,flags,8
	ldo	r7,r7,flags,8
	tst	r7,#64
	bne	compacting_collector
.else
 .if MARK_GC
	b	compacting_collector
 .endif
.endif

.if MARK_AND_COPY_GC || !MARK_GC
	lao	r7,garbage_collect_flag,4
	ldosb	r7,r7,garbage_collect_flag,4
	cmp	r7,#0
	bne	compacting_collector

	lao	r7,heap_copied_vector,1
	ldo	r4,r7,heap_copied_vector,1

	lao	r7,heap_end_after_copy_gc,1
	ldo	r7,r7,heap_end_after_copy_gc,1
	cmp	r7,#0
	beq	zero_all

	mov	r1,r6
	lao	r7,heap_p1,1
	ldo	r7,r7,heap_p1,1
	subs	r1,r1,r7
	add	r1,r1,#63*4
	lsr	r1,r1,#8
	adr	r14,1+0f
	push	{r14}
	bl	zero_bit_vector
0:
	lao	r7,heap_end_after_copy_gc,2
	ldo	r3,r7,heap_end_after_copy_gc,2
	lao	r7,heap_p1,2
	ldo	r7,r7,heap_p1,2
	subs	r3,r3,r7
	lsr	r3,r3,#6
	and	r3,r3,#-4

	lao	r7,heap_copied_vector,2
	ldo	r4,r7,heap_copied_vector,2
	lao	r7,heap_copied_vector_size,2
	ldo	r1,r7,heap_copied_vector_size,2
	add	r4,r4,r3
	subs	r1,r1,r3
	lsr	r1,r1,#2

	lao	r7,heap_end_after_copy_gc,3
	mov	r14,#0
	sto	r14,r7,heap_end_after_copy_gc,3

	adr	r14,1+0f
	push	{r14}
	bl	zero_bit_vector
0:
	b	end_zero_bit_vector

zero_all:
	lao	r7,heap_copied_vector_size,3
	ldo	r1,r7,heap_copied_vector_size,3
	lsr	r1,r1,#2
	adr	r14,1+0f
	push	{r14}
	bl	zero_bit_vector
0:

end_zero_bit_vector:

	.include "tcopy.s"

.if WRITE_HEAP
	lao	r7,heap2_begin_and_end,0
	sto	r5,r7,heap2_begin_and_end,0
.endif

	sub	r4,r5,r6
	lsr	r4,r4,#2

	ldr	r5,[sp],#4

	adr	r14,1+0f
	push	{r14}
	bl	add_garbage_collect_time
0:
	lao	r7,n_allocated_words,2
	ldo	r7,r7,n_allocated_words,2
	subs	r4,r4,r7
	mov	r11,r4
	bls	switch_to_mark_scan

	add	r1,r4,r4,lsl #2
	lsl	r1,r1,#5
	lao	r0,heap_size,4
	ldo	r0,r0,heap_size,4
	mov	r2,r0
	lsl	r0,r0,#2
	add	r0,r0,r2
	add	r0,r0,r0
	add	r0,r0,r2
	cmp	r1,r0
	bhs	no_mark_scan
@	b	no_mark_scan

switch_to_mark_scan:
	lao	r7,heap_size_33,2
	ldo	r1,r7,heap_size_33,2
	lsl	r1,r1,#5
	lao	r7,heap_p,1
	ldo	r0,r7,heap_p,1

	lao	r7,heap_p1,3
	ldo	r2,r7,heap_p1,3
	lao	r7,heap_p2,1
	ldo	r7,r7,heap_p2,1
	cmp	r2,r7
	bcc	vector_at_begin

vector_at_end:
	lao	r7,heap_p3,2
	sto	r0,r7,heap_p3,2
	add	r0,r0,r1
	lao	r7,heap_vector,2
	sto	r0,r7,heap_vector,2

	lao	r7,heap_p1,4
	ldo	r1,r7,heap_p1,4
	lao	r7,extra_heap,1
	sto	r1,r7,extra_heap,1
	subs	r0,r0,r1
	lsr	r0,r0,#2
	lao	r7,extra_heap_size,1
	sto	r0,r7,extra_heap_size,1
	b	switch_to_mark_scan_2

vector_at_begin:
	lao	r7,heap_vector,3
	sto	r0,r7,heap_vector,3
	lao	r7,heap_size,5
	ldo	r7,r7,heap_size,5
	add	r0,r0,r7
	subs	r0,r0,r1
	lao	r7,heap_p3,3
	sto	r0,r7,heap_p3,3

	lao	r7,extra_heap,2
	sto	r0,r7,extra_heap,2
	lao	r7,heap_p2,2
	ldo	r2,r7,heap_p2,2
	subs	r2,r2,r0
	lsr	r2,r2,#2
	lao	r7,extra_heap_size,2
	sto	r2,r7,extra_heap_size,2

switch_to_mark_scan_2:
	lao	r1,heap_size,6
	ldo	r1,r1,heap_size,6
	lsr	r1,r1,#3
	sub	r1,r1,r4
	lsl	r1,r1,#2

	lao	r7,garbage_collect_flag,5
	mov	r12,#1
	stob	r12,r7,garbage_collect_flag,5

	cmp	r4,#0
	bpl	end_garbage_collect

	mov	r12,#-1
	strb	r12,[r7]

	lao	r7,extra_heap_size,3
	ldo	r0,r7,extra_heap_size,3
	lao	r7,n_allocated_words,3
	ldo	r7,r7,n_allocated_words,3
	subs	r11,r0,r7
	bmi	out_of_memory_4

	lao	r7,extra_heap,3
	ldo	r6,r7,extra_heap,3
	lsl	r0,r0,#2
	add	r0,r0,r6
	lao	r7,heap_end_after_gc,4
	sto	r0,r7,heap_end_after_gc,4
.if WRITE_HEAP
	lao	r7,heap_end_write_heap,0
	sto	r6,r7,heap_end_write_heap,0
	lao	r7,d3_flag_write_heap,0
	mov	r12,#1
	sto	r12,r7,d3_flag_write_heap,0
	b	end_garbage_collect_
.else
	b	end_garbage_collect
.endif
no_mark_scan:
@ exchange the semi_spaces
	lao	r7,heap_p1,5
	ldo	r1,r7,heap_p1,5
	lao	r7,heap_p2,3
	ldo	r0,r7,heap_p2,3
	lao	r7,heap_p2,4
	sto	r1,r7,heap_p2,4
	lao	r7,heap_p1,6
	sto	r0,r7,heap_p1,6

	lao	r7,heap_size_129,2
	ldo	r1,r7,heap_size_129,2
	lsl	r1,r1,#6-2

 .ifdef MUNMAP
	lao	r7,heap_p2,5
	ldo	r0,r7,heap_p2,5
	add	r2,r0,r1,lsl #2
	add	r0,r0,#4095
	and	r0,r0,#-4096
	and	r2,r2,#-4096
	subs	r2,r2,r0
	bls	no_pages
	str	r1,[sp,#-4]!

	str	r2,[sp,#-4]!
	str	r0,[sp,#-4]!
	adr	r14,1+0f
	push	{r14}
	bl	_munmap
0:
	add	sp,sp,#8

	ldr	r1,[sp],#4
no_pages:
 .endif

 .if ADJUST_HEAP_SIZE
	mov	r0,r1
 .endif
	subs	r1,r1,r4

 .if ADJUST_HEAP_SIZE
	mov	r2,r1
	lao	r7,heap_size_multiple,0
	ldo	r7,r7,heap_size_multiple,0
	umull	r1,r3,r7,r1
	lsr	r1,r1,#9
	orr	r1,r1,r3,lsl #32-9
	lsrs	r3,r3,#9
	bne	no_small_heap1

	cmp	r1,#MINIMUM_HEAP_SIZE_2
	bhs	not_too_small1
	mov	r1,#MINIMUM_HEAP_SIZE_2
not_too_small1:
	subs	r0,r0,r1
	blo	no_small_heap1

	sub	r11,r11,r0
	lsl	r0,r0,#2
	lao	r7,heap_end_after_gc,5
	ldo	r4,r7,heap_end_after_gc,5
	lao	r7,heap_end_after_copy_gc,4
	sto	r4,r7,heap_end_after_copy_gc,4
	sub	r4,r4,r0
	lao	r7,heap_end_after_gc,6
	sto	r4,r7,heap_end_after_gc,6

no_small_heap1:
	mov	r1,r2
 .endif

	lsl	r1,r1,#2
.endif

end_garbage_collect:
.if WRITE_HEAP
	lao	r7,heap_end_write_heap,1
	sto	r6,r7,heap_end_write_heap,1
	lao	r7,d3_flag_write_heap,1
	mov	r12,#0
	sto	r12,r7,d3_flag_write_heap,1
end_garbage_collect_:
.endif

	str	r1,[sp,#-4]!

	lao	r7,flags,9
	ldo	r7,r7,flags,9
	tst	r7,#2
	beq	no_heap_use_message

	str	r1,[sp,#-4]!

	lao	r0,heap_use_after_gc_string_1,0
	otoa	r0,heap_use_after_gc_string_1,0
	bl	ew_print_string

	ldr	r0,[sp],#4
	bl	ew_print_int

	lao	r0,heap_use_after_gc_string_2,0
	otoa	r0,heap_use_after_gc_string_2,0
	bl	ew_print_string

no_heap_use_message:

.if FINALIZERS
	adr	r14,1+0f
	push	{r14}
	bl	call_finalizers
0:
.endif

	ldr	r1,[sp],#4

.if WRITE_HEAP
	@ Check whether memory profiling is on or off
	lao	r7,flags,10
	ldo	r7,r7,flags,10
	tst	r7,#32
	beq	no_write_heap

	lao	r7,min_write_heap_size,0
	ldo	r7,r7,min_write_heap_size,0
	cmp	r1,r7
	blo	no_write_heap

	str	r2,[sp,#-4]!
	str 	r3,[sp,#-4]!
	str	r4,[sp,#-4]!
	str	r5,[sp,#-4]!
	str	r6,[sp,#-4]!

	subs	sp,sp,#64

	lao	r7,d3_flag_write_heap,2
	ldo	r1,r7,d3_flag_write_heap,2
	tst	r1,r1
	bne	copy_to_compact_with_alloc_in_extra_heap	

	lao	r1,garbage_collect_flag,6
	ldosb	r1,r1,garbage_collect_flag,6

	lao	r7,heap2_begin_and_end,1
	ldo	r2,r7,heap2_begin_and_end,1
	laol	r7,heap2_begin_and_end+4,heap2_begin_and_end_o_4,0
	ldo	r3,r7,heap2_begin_and_end_o_4,0

	lao	r0,heap_p1,7
	otoa	r0,heap_p1,7

	tst	r1,r1
	beq	gc0

	lao	r0,heap_p2,6
	otoa	r0,heap_p2,6
	bgt	gc1

	lao	r0,heap_p3,4
	otoa	r0,heap_p3,4
	mov	r2,#0
	mov	r3,#0

gc0:
gc1:
	ldr	r0,[r0]

?	/* fill record */

	mov	r1,sp

	str	r0,[r1,#0]
?	movl	a4,4(d0)			// klop dit?

?	movl	a0,8(d0)			// heap2_begin
?	movl	a1,12(d0)			// heap2_end

	lao	r7,stack_p,3
	ldo	r0,r7,stack_p,3
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

	str	r1,[sp,#-4]!
	bl	write_heap

	add	sp,sp,#68

	ldr	r6,[sp],#4
	ldr	r5,[sp],#4
	ldr	r4,[sp],#4
	ldr	r3,[sp],#4
	ldr	r2,[sp],#4
no_write_heap:

.endif

	ldmia	sp!,{r0-r1,r8-r10,pc}

.ifdef PIC
 .if MARK_AND_COPY_GC
	lto	flags,8
 .endif
 .if MARK_AND_COPY_GC || !MARK_GC
	lto	garbage_collect_flag,4
	lto	heap_copied_vector,1
	lto	heap_end_after_copy_gc,1
	lto	heap_p1,1
	lto	heap_end_after_copy_gc,2
	lto	heap_p1,2
	lto	heap_copied_vector,2
	lto	heap_copied_vector_size,2
	lto	heap_end_after_copy_gc,3
	lto	heap_copied_vector_size,3
 .endif
 .if WRITE_HEAP
	lto	heap2_begin_and_end,0
 .endif
	lto	n_allocated_words,2
	lto	heap_size,4
	lto	heap_size_33,2
	lto	heap_p,1
	lto	heap_p1,3
	lto	heap_p2,1
	lto	heap_p3,2
	lto	heap_vector,2
	lto	heap_p1,4
	lto	extra_heap,1
	lto	extra_heap_size,1
	lto	heap_vector,3
	lto	heap_size,5
	lto	heap_p3,3
	lto	extra_heap,2
	lto	heap_p2,2
	lto	extra_heap_size,2
	lto	heap_size,6
	lto	garbage_collect_flag,5
	lto	extra_heap_size,3
	lto	n_allocated_words,3
	lto	extra_heap,3
	lto	heap_end_after_gc,4
 .if WRITE_HEAP
	lto	heap_end_write_heap,0
	lto	d3_flag_write_heap,0
 .endif
	lto	heap_p1,5
	lto	heap_p2,3
	lto	heap_p2,4
	lto	heap_p1,6
	lto	heap_size_129,2
 .ifdef MUNMAP
	lto	heap_p2,5
 .endif
 .if ADJUST_HEAP_SIZE
	lto	heap_size_multiple,0
	lto	heap_end_after_gc,5
	lto	heap_end_after_copy_gc,4
	lto	heap_end_after_gc,6
 .endif
 .if WRITE_HEAP
	lto	heap_end_write_heap,1
	lto	d3_flag_write_heap,1
 .endif
	lto	flags,9
	lto	heap_use_after_gc_string_1,0
	lto	heap_use_after_gc_string_2,0
 .if WRITE_HEAP
	lto	flags,10
	lto	min_write_heap_size,0
	lto	d3_flag_write_heap,2
	lto	garbage_collect_flag,6
	lto	heap2_begin_and_end,1
	ltol	heap2_begin_and_end+4,heap2_begin_and_end_o_4,0
	lto	heap_p1,7
	lto	heap_p2,6
	lto	heap_p3,4
	lto	stack_p,3
 .endif
.endif
	.ltorg
.ifdef PIC
 .if FINALIZERS
	lto	free_finalizer_list,1
	ltol	__Nil-4,__Nil_o_m4,1
	lto	free_finalizer_list,2
	ltol	__Nil-4,__Nil_o_m4,2
 .endif
 .if WRITE_HEAP
	lto	heap2_begin_and_end,2
	ltol	heap2_begin_and_end+4,heap2_begin_and_end_o_4,1
	lto	heap_p2,7
 .endif
	lto	out_of_memory_string_4,0
	lto	stack_top,0
	lto	heap_vector,4
 .if MARK_GC
  .if MARK_AND_COPY_GC
	lto	flags,11
  .endif
	lto	zero_bits_before_mark,0
 .endif
	lto	heap_size_33,3
 .if MARK_GC
  .if MARK_AND_COPY_GC
 	lto	flags,12
   .endif
	lto	n_last_heap_free_bytes,0
	lto	n_free_words_after_mark,3
  .endif
 .if ADJUST_HEAP_SIZE
	lto	bit_vector_size,1
	lto	heap_size_multiple,1
 .endif
.endif

.if FINALIZERS
call_finalizers:
	lao	r7,free_finalizer_list,1
	ldo	r1,r7,free_finalizer_list,1

call_finalizers_lp:
	laol	r7,__Nil-4,__Nil_o_m4,1
	otoa	r7,__Nil_o_m4,1
	cmp	r1,r7
	beq	end_call_finalizers
	ldr	r7,[r1,#4]
	str	r7,[sp,#-4]!
	ldr	r0,[r1,#8]
	ldr	r7,[r0,#4]
	str	r7,[sp,#-4]!
	ldr	r7,[r0]
	blx	r7
	add	sp,sp,#4
	ldr	r1,[sp],#4
	b	call_finalizers_lp
end_call_finalizers:
	lao	r7,free_finalizer_list,2
	laol	r12,__Nil-4,__Nil_o_m4,2
	otoa	r12,__Nil_o_m4,2
	sto	r12,r7,free_finalizer_list,2
	pop	{pc}
.endif

.if WRITE_HEAP
copy_to_compact_with_alloc_in_extra_heap:
	lao	r7,heap2_begin_and_end,2
	ldo	r2,r7,heap2_begin_and_end,2
	laol	r7,heap2_begin_and_end+4,heap2_begin_and_end_o_4,1
	ldo	r3,r7,heap2_begin_and_end_o_4,1
	lao	r0,heap_p2,7
	otoa	r0,heap_p2,7
	b	gc1
.endif

out_of_memory_4:
	adr	r14,1+0f
	push	{r14}
	bl	add_garbage_collect_time
0:

	lao	r4,out_of_memory_string_4,0
	otoa	r4,out_of_memory_string_4,0
	b	print_error

zero_bit_vector:
	eor	r3,r3,r3
	tst	r1,#1
	beq	zero_bits1_1
	str	r3,[r4]
	add	r4,r4,#4
zero_bits1_1:
	lsr	r1,r1,#1

	mov	r0,r1
	lsr	r1,r1,#1
	tst	r0,#1
	beq	zero_bits1_5

	subs	r4,r4,#8
	b	zero_bits1_2

zero_bits1_4:
	str	r3,[r4]
	str	r3,[r4,#4]
zero_bits1_2:
	str	r3,[r4,#8]
	str	r3,[r4,#12]
	add	r4,r4,#16
zero_bits1_5:
	subs	r1,r1,#1
	bhs	zero_bits1_4
	pop	{pc}

reorder:
	str	r5,[sp,#-4]!
	str	r4,[sp,#-4]!

	mov	r4,r1
	lsl	r4,r4,#2
	mov	r5,r0
	lsl	r5,r5,#2
	add	r2,r2,r5
	subs	r3,r3,r4

	str	r5,[sp,#-4]!
	str	r4,[sp,#-4]!
	str	r0,[sp,#-4]!
	str	r1,[sp,#-4]!
	b	st_reorder_lp

reorder_lp:
	ldr	r4,[r2]
	ldr	r5,[r3,#-4]
	str	r4,[r3,#-4]
	subs	r3,r3,#4
	str	r5,[r2]
	add	r2,r2,#4

	subs	r1,r1,#1
	bne	next_b_in_element
	ldr	r1,[sp]
	ldr	r7,[sp,#12]
	add	r2,r2,r7
next_b_in_element:
	subs	r0,r0,#1
	bne	next_a_in_element
	ldr	r0,[sp,#4]
	ldr	r7,[sp,#8]
	subs	r3,r3,r7
next_a_in_element:
st_reorder_lp:
	cmp	r3,r2
	bhi	reorder_lp

	ldr	r1,[sp],#4
	ldr	r0,[sp],#4
	add	sp,sp,#8
	ldr	r4,[sp],#4
	ldr	r5,[sp],#4
	pop	{pc}

@
@	the sliding compacting garbage collector
@

compacting_collector:
@ zero all mark bits

	lao	r7,stack_top,0
	sto	r5,r7,stack_top,0

	lao	r7,heap_vector,4
	ldo	r6,r7,heap_vector,4

.if MARK_GC
 .if MARK_AND_COPY_GC
 	lao	r7,flags,11
 	ldo	r7,r7,flags,11
	tst	r7,#64
	beq	no_mark4
 .endif
 	lao	r7,zero_bits_before_mark,0
 	otoa	r7,zero_bits_before_mark,0
 	ldr	r12,[r7]
 	cmp	r12,#0
	beq	no_zero_bits

	mov	r12,#0
	str	r12,[r7]

 .if MARK_AND_COPY_GC
no_mark4:
 .endif
.endif

	mov	r4,r6
	lao	r7,heap_size_33,3
	ldo	r1,r7,heap_size_33,3
	add	r1,r1,#3
	lsr	r1,r1,#2

	mov	r0,#0

	tst	r1,#1
	beq	zero_bits_1
	str	r0,[r4],#4
zero_bits_1:
	mov	r2,r1
	lsr	r1,r1,#2

	tst	r2,#2
	beq	zero_bits_5

	subs	r4,r4,#8
	b	zero_bits_2

zero_bits_4:
	str	r0,[r4]
	str	r0,[r4,#4]
zero_bits_2:
	str	r0,[r4,#8]
	str	r0,[r4,#12]
	add	r4,r4,#16
zero_bits_5:
	subs	r1,r1,#1
	bcs	zero_bits_4

.if MARK_GC
 .if MARK_AND_COPY_GC
 	lao	r7,flags,12
 	ldo	r7,r7,flags,12
 	tst	r7,#64
	beq	no_mark5
 .endif
no_zero_bits:
	lao	r7,n_last_heap_free_bytes,0
	ldo	r1,r7,n_last_heap_free_bytes,0
	lao	r7,n_free_words_after_mark,3
	ldo	r0,r7,n_free_words_after_mark,3

.if 1
	lsr	r1,r1,#2
.else
	lsl	r0,r0,#2
.endif

	add	r4,r0,r0,lsl #3
	lsr	r4,r4,#2

	cmp	r1,r4
	bgt	compact_gc

 .if ADJUST_HEAP_SIZE
	lao	r7,bit_vector_size,1
	ldo	r0,r7,bit_vector_size,1
	lsl	r0,r0,#2

	sub	r1,r0,r1

	lao	r7,heap_size_multiple,1
	ldo	r7,r7,heap_size_multiple,1
	umull	r1,r3,r7,r1
	lsr	r1,r1,#7
	orr	r1,r1,r3,lsl #32-7
	lsrs	r3,r3,#7
	bne	no_smaller_heap

	cmp	r1,r0
	bhs	no_smaller_heap

	cmp	r0,#MINIMUM_HEAP_SIZE
	bls	no_smaller_heap

	b	compact_gc
no_smaller_heap:
 .endif

	.include "tmark.s"

.ifdef PIC
	lto	zero_bits_before_mark,1
	lto	n_last_heap_free_bytes,1
	lto	n_free_words_after_mark,4
.endif

compact_gc:
	lao	r7,zero_bits_before_mark,1
	mov	r12,#1
	sto	r12,r7,zero_bits_before_mark,1
	lao	r7,n_last_heap_free_bytes,1
	mov	r12,#0
	sto	r12,r7,n_last_heap_free_bytes,1
	lao	r7,n_free_words_after_mark,4
	mov	r12,#1000
	sto	r12,r7,n_free_words_after_mark,4
 .if MARK_AND_COPY_GC
no_mark5:
 .endif
.endif

	.include "tcompact.s"

	lao	r7,stack_top,1
	ldo	r5,r7,stack_top,1

	lao	r7,heap_size_33,4
	ldo	r0,r7,heap_size_33,4
	lsl	r0,r0,#5
	lao	r7,heap_p3,5
	ldo	r7,r7,heap_p3,5
	add	r0,r0,r7

	lao	r7,heap_end_after_gc,7
	sto	r0,r7,heap_end_after_gc,7

	subs	r0,r0,r6
	lsr	r0,r0,#2

	lao	r7,n_allocated_words,4
	ldo	r7,r7,n_allocated_words,4
	subs	r0,r0,r7
	mov	r11,r0
	bcc	out_of_memory_4

	ldr	r7,=107374182
	cmp	r0,r7
	bhs	not_out_of_memory
	add	r1,r0,r0,lsl #2
	lsl	r1,r1,#3
	lao	r7,heap_size,7
	ldo	r7,r7,heap_size,7
	cmp	r1,r7
	bcc	out_of_memory_4
not_out_of_memory:

.if MARK_GC || COMPACT_GC_ONLY
 .if MARK_GC && ADJUST_HEAP_SIZE
  .if MARK_AND_COPY_GC
  	lao	r7,flags,13
  	ldo	r7,r7,flags,13
  	tst	r7,#64
	beq	no_mark_6
  .endif

	lao	r7,heap_p3,6
	ldo	r1,r7,heap_p3,6
	sub	r1,r6,r1
	lao	r7,n_allocated_words,5
	ldo	r0,r7,n_allocated_words,5
	add	r1,r1,r0,lsl #2

	lao	r7,heap_size_33,5
	ldo	r0,r7,heap_size_33,5
	lsl	r0,r0,#5

	lao	r7,heap_size_multiple,2
	ldo	r7,r7,heap_size_multiple,2
	umull	r1,r3,r7,r1
	lsr	r1,r1,#8
	orr	r1,r1,r3,lsl #32-8
	lsrs	r3,r3,#8
	bne	no_small_heap2

	and	r1,r1,#-4

	cmp	r1,#MINIMUM_HEAP_SIZE
	bhs	not_too_small2
	mov	r1,#MINIMUM_HEAP_SIZE
not_too_small2:
	mov	r2,r0
	subs	r2,r2,r1
	blo	no_small_heap2

	lao	r7,heap_end_after_gc,8
	otoa	r7,heap_end_after_gc,8
	ldr	r12,[r7]
	sub	r12,r12,r2
	str	r12,[r7]

	sub	r11,r11,r2,lsr #2

	mov	r0,r1

no_small_heap2:
	lsr	r0,r0,#2
	lao	r7,bit_vector_size,2
	sto	r0,r7,bit_vector_size,2

  .if MARK_AND_COPY_GC
no_mark_6:
  .endif
 .endif
	b	no_copy_garbage_collection
.else
@ to do prevent overflow
	lsl	r1,r1,#2
	lao	r7,heap_size,8
	ldo	r7,r7,heap_size,8
	lsl	r2,r7,#5
	sub	r2,r2,r7
	cmp	r1,r2
	ble	no_copy_garbage_collection

	lao	r7,heap_p,2
	ldo	r1,r7,heap_p,2
	lao	r7,heap_p1,8
	sto	r1,r7,heap_p1,8

	lao	r7,heap_size_129,3
	ldo	r0,r7,heap_size_129,3
	lsl	r0,r0,#6
	add	r1,r1,r0
	lao	r7,heap_copied_vector,3
	sto	r1,r7,heap_copied_vector,3
	lao	r7,heap_end_after_gc,9
	sto	r1,r7,heap_end_after_gc,9
	lao	r7,heap_copied_vector_size,4
	ldo	r0,r7,heap_copied_vector_size,4
	add	r0,r0,r1
	lao	r7,heap_p2,8
	sto	r0,r7,heap_p2,8

	lao	r7,heap_p3,7
	ldo	r1,r7,heap_p3,7
	lao	r7,heap_vector,5
	ldo	r7,r7,heap_vector,5
	cmp	r1,r7
	ble	vector_at_end_2

	lao	r7,heap_vector,6
	ldo	r0,r7,heap_vector,6
	lao	r7,extra_heap,4
	sto	r0,r7,extra_heap,4
	subs	r1,r1,r0
	lsr	r1,r1,#2
	lao	r7,extra_heap_size,4
	sto	r1,r7,extra_heap_size,4

	lao	r7,garbage_collect_flag,7
	mov	r12,#2
	stob	r12,r7,garbage_collect_flag,7
	b	no_copy_garbage_collection

vector_at_end_2:
	lao	r7,garbage_collect_flag,8
	mov	r12,#0
	stob	r12,r7,garbage_collect_flag,8
.endif

no_copy_garbage_collection:
	adr	r14,1+0f
	push	{r14}
	bl	add_garbage_collect_time
0:
	mov	r1,r6
	lao	r7,heap_p3,8
	ldo	r7,r7,heap_p3,8
	subs	r1,r1,r7
	lao	r7,n_allocated_words,6
	ldo	r0,r7,n_allocated_words,6
	add	r1,r1,r0,lsl #2
	b	end_garbage_collect

stack_overflow:
	adr	r14,1+0f
	push	{r14}
	bl	add_execute_time
0:
	lao	r4,stack_overflow_string,0
	otoa	r4,stack_overflow_string,0
	b	print_error

IO_error:
	str	r0,[sp]

	lao	r0,IO_error_string,0
	otoa	r0,IO_error_string,0
	bl	ew_print_string

	ldr	r0,[sp],#4
	bl	ew_print_string

	lao	r0,new_line_string,0
	otoa	r0,new_line_string,0
	bl	ew_print_string

	b	halt

print_error:
	mov	r0,r4
	bl	ew_print_string

halt:
	lao	r7,halt_sp,3
	ldo	sp,r7,halt_sp,3

.ifdef PROFILE
	adr	r14,1+0f
	push	{r14}
	bl	write_profile_stack
0:
.endif

	b	exit

.ifdef PIC
	lto	stack_top,1
	lto	heap_size_33,4
	lto	heap_p3,5
	lto	heap_end_after_gc,7
	lto	n_allocated_words,4
	lto	heap_size,7
 .if MARK_GC || COMPACT_GC_ONLY
  .if MARK_GC && ADJUST_HEAP_SIZE
   .if MARK_AND_COPY_GC
  	lto	flags,13
   .endif
	lto	heap_p3,6
	lto	n_allocated_words,5
	lto	heap_size_33,5
	lto	heap_size_multiple,2
	lto	heap_end_after_gc,8
	lto	bit_vector_size,2
  .endif
 .else
	lto	heap_size,8
	lto	heap_p,2
	lto	heap_p1,8
	lto	heap_size_129,3
	lto	heap_copied_vector,3
	lto	heap_end_after_gc,9
	lto	heap_copied_vector_size,4
	lto	heap_p2,8
	lto	heap_p3,7
	lto	heap_vector,5
	lto	heap_vector,6
	lto	extra_heap,4
	lto	extra_heap_size,4
	lto	garbage_collect_flag,7
	lto	garbage_collect_flag,8
 .endif
	lto	heap_p3,8
	lto	n_allocated_words,6
	lto	stack_overflow_string,0
	lto	IO_error_string,0
	lto	new_line_string,0
	lto	halt_sp,3
.endif
	.ltorg

e__system__eaind:
eval_fill:
	str	r2,[r5],#4
	mov	r2,r3
	ldr	r7,[r3]
	adr	r14,1+0f
	push	{r14}
	blx	r7
0:
	mov	r3,r2
	ldr	r2,[r5,#-4]!

	ldr	r4,[r3]
	str	r4,[r2]
	ldr	r4,[r3,#4]
	str	r4,[r2,#4]
	ldr	r4,[r3,#8]
	str	r4,[r2,#8]
	pop	{pc}

	.p2align	2
	b.w	e__system__eaind
	nop.w
	nop.w
.ifdef PIC
	.long	e__system__dind-.
.else
	.long	e__system__dind
.endif
	.long	-2
	.thumb_func
e__system__nind:
	.thumb_func
__indirection:
	ldr	r3,[r2,#4]
	ldr	r1,[r3]
	tst	r1,#2
.if MARK_GC
	beq	eval_fill2
.else
	beq	__cycle__in__spine
.endif
	str	r1,[r2]
	ldr	r4,[r3,#4]
	str	r4,[r2,#4]
	ldr	r4,[r3,#8]
	str	r4,[r2,#8]
	pop	{pc}

.if MARK_GC
eval_fill2:
	lao	r7,__cycle__in__spine,0
	otoa	r7,__cycle__in__spine,0
	str	r7,[r2]
	str	r2,[r5]
 .if MARK_AND_COPY_GC
 	lao	r7,flags,14
 	ldo	r7,r7,flags,14
 	tst	r7,#64
	beq	__cycle__in__spine	
 .endif
	add	r5,r5,#4
	mov	r2,r3
	
	adr	r14,1+0f
	push	{r14}
	blx	r1
0:
	mov	r3,r2
	ldr	r2,[r5,#-4]!

	ldr	r4,[r3]
	str	r4,[r2]
	ldr	r4,[r3,#4]
	str	r4,[r2,#4]
	ldr	r4,[r3,#8]
	str	r4,[r2,#8]
	pop	{pc}
.endif

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_0:
	lao	r7,e__system__nind,0
	otoa	r7,e__system__nind,0
	str	r7,[r3]
	str	r2,[r3,#4]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_1:
	lao	r7,e__system__nind,1
	otoa	r7,e__system__nind,1
	str	r7,[r3]
	ldr	r1,[r3,#4]
	str	r2,[r3,#4]
	mov	r3,r1
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_2:
	lao	r7,e__system__nind,2
	otoa	r7,e__system__nind,2
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r3,#4]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_3:
	lao	r7,e__system__nind,3
	otoa	r7,e__system__nind,3
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r3,#4]
	str	r2,[r5],#4
	ldr	r2,[r3,#12]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_4:
	lao	r7,e__system__nind,4
	otoa	r7,e__system__nind,4
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r3,#4]
	str	r2,[r5]
	ldr	r0,[r3,#16]
	str	r0,[r5,#4]
	add	r5,r5,#8
	ldr	r2,[r3,#12]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_5:
	lao	r7,e__system__nind,5
	otoa	r7,e__system__nind,5
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r5]
	str	r2,[r3,#4]
	ldr	r0,[r3,#20]
	str	r0,[r5,#4]
	ldr	r0,[r3,#16]
	str	r0,[r5,#8]
	add	r5,r5,#12
	ldr	r2,[r3,#12]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	adr	r14,1+0f
	push	{r14}
	bl	profile_n
0:
	mov	r4,r1
.endif
eval_upd_6:
	lao	r7,e__system__nind,6
	otoa	r7,e__system__nind,6
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r5]
	str	r2,[r3,#4]
	ldr	r0,[r3,#24]
	str	r0,[r5,#4]
	ldr	r0,[r3,#20]
	str	r0,[r5,#8]
	ldr	r0,[r3,#16]
	str	r0,[r5,#12]
	add	r5,r5,#16
	ldr	r2,[r3,#12]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_7:
	mov	r1,#0
	mov	r0,#20
eval_upd_n:
	lao	r7,e__system__nind,7
	otoa	r7,e__system__nind,7
	add	r10,r3,r0
	str	r7,[r3]
	ldr	r4,[r3,#4]
	str	r2,[r5]
	str	r2,[r3,#4]
	ldr	r0,[r10,#8]
	str	r0,[r5,#4]
	ldr	r0,[r10,#4]
	str	r0,[r5,#8]
	ldr	r0,[r10]
	str	r0,[r5,#12]
	add	r5,r5,#16

eval_upd_n_lp:
	ldr	r0,[r10,#-4]!
	str	r0,[r5],#4
	subs	r1,r1,#1
	bcs	eval_upd_n_lp

	ldr	r2,[r3,#12]
	ldr	r3,[r3,#8]
	mov	pc,r12

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_8:
	mov	r1,#1
	mov	r0,#24
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_9:
	mov	r1,#2
	mov	r0,#28
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_10:
	mov	r1,#3
	mov	r0,#32
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_11:
	mov	r1,#4
	mov	r0,#36
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_12:
	mov	r1,#5
	mov	r0,#40
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_13:
	mov	r1,#6
	mov	r0,#44
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_14:
	mov	r1,#7
	mov	r0,#48
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_15:
	mov	r1,#8
	mov	r0,#52
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_16:
	mov	r1,#9
	mov	r0,#56
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_17:
	mov	r1,#10
	mov	r0,#60
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_18:
	mov	r1,#11
	mov	r0,#64
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_19:
	mov	r1,#12
	mov	r0,#68
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_20:
	mov	r1,#13
	mov	r0,#72
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov	r12,r1
.endif
eval_upd_21:
	mov	r1,#14
	mov	r0,#76
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_22:
	mov	r1,#15
	mov	r0,#80
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_23:
	mov	r1,#16
	mov	r0,#84
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_24:
	mov	r1,#17
	mov	r0,#88
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_25:
	mov	r1,#18
	mov	r0,#92
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_26:
	mov	r1,#19
	mov	r0,#96
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_27:
	mov	r1,#20
	mov	r0,#100
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_28:
	mov	r1,#21
	mov	r0,#104
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_29:
	mov	r1,#22
	mov	r0,#108
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_30:
	mov	r1,#23
	mov	r0,#112
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_31:
	mov	r1,#24
	mov	r0,#116
	b	eval_upd_n

.ifdef PROFILE
	bl	profile_n
	mov.w	r12,r1
.endif
eval_upd_32:
	mov	r1,#25
	mov	r0,#120
	b	eval_upd_n

@
@	STRINGS
@
	.section .text.	(catAC)
catAC:
	ldr	r1,[r2,#4]
	ldr	r0,[r3,#4]
	add	r4,r1,r0
	add	r4,r4,#8+3
	lsr	r4,r4,#2

	subs	r11,r11,r4
	blo	gc_3
gc_r_3:
	add	r2,r2,#8
	add	r3,r3,#8

@ fill_node

	str	r6,[sp,#-4]!
	laol	r7,__STRING__+2,__STRING___o_2,1
	otoa	r7,__STRING___o_2,1
	str	r7,[r6]

@ store length

	add	r4,r1,r0
	str	r4,[r6,#4]
	add	r6,r6,#8

@ copy string 1

	add	r4,r0,#3
	add	r0,r0,r6
	lsrs	r4,r4,#2
	beq	catAC_after_copy_lp1

catAC_copy_lp1:
	ldr	r7,[r3],#4
	str	r7,[r6],#4
	subs	r4,r4,#1
	bne	catAC_copy_lp1

catAC_after_copy_lp1:
	mov	r6,r0

@ copy_string 2

cat_string_6:
	lsrs	r4,r1,#2
	beq	cat_string_9

cat_string_7:
	ldr	r0,[r2],#4
@ store not aligned
	str	r0,[r6],#4
	subs	r4,r4,#1
	bne	cat_string_7

cat_string_9:
	tst	r1,#2
	beq	cat_string_10
	ldrh	r0,[r2],#2
	strh	r0,[r6],#2
cat_string_10:
	tst	r1,#1
	beq	cat_string_11
	ldrb	r0,[r2]
	strb	r0,[r6],#1
cat_string_11:

	ldr	r2,[sp],#4
@ align heap pointer
	add	r6,r6,#3
	and	r6,r6,#-4
	pop	{pc}

gc_3:	bl	collect_2
	b	gc_r_3

empty_string:
	lao	r2,zero_length_string,0
	otoa	r2,zero_length_string,0
	pop	{pc}

.ifdef PIC
	ltol	__STRING__+2,__STRING___o_2,1
	lto	zero_length_string,0
.endif

	.section .text.sliceAC,"ax"
sliceAC:
	ldr	r4,[r2,#4]
	tst	r0,r0
	bpl	slice_string_1
	mov	r0,#0
slice_string_1:
	cmp	r0,r4
	bge	empty_string
	cmp	r1,r0
	blt	empty_string
	add	r1,r1,#1
	cmp	r1,r4
	ble	slice_string_2
	mov	r1,r4
slice_string_2:
	subs	r1,r1,r0

	add	r4,r1,#8+3
	lsr	r4,r4,#2

	subs	r11,r11,r4	
	blo	gc_4
r_gc_4:
	subs	r4,r4,#2
	add	r7,r2,#8
	add	r3,r7,r0

	laol	r7,__STRING__+2,__STRING___o_2,2
	otoa	r7,__STRING___o_2,2
	str	r7,[r6]
	str	r1,[r6,#4]

@ copy part of string
	mov	r2,r6
	add	r6,r6,#8

	cmp	r4,#0
	beq	sliceAC_after_copy_lp
	
sliceAC_copy_lp:
@ load not aligned
	ldr	r7,[r3],#4
	str	r7,[r6],#4
	subs	r4,r4,#1
	bne	sliceAC_copy_lp
		
sliceAC_after_copy_lp:
	pop	{pc}

gc_4:
	bl	collect_1
	add	r4,r1,#8+3
	lsr	r4,r4,#2
	b	r_gc_4

.ifdef PIC
	ltol	__STRING__+2,__STRING___o_2,2
.endif

	.section .text.updateAC,"ax"
updateAC:
	ldr	r4,[r2,#4]
	cmp	r0,r4
	bhs	update_string_error

	add	r4,r4,#8+3
	lsr	r4,r4,#2

	subs	r11,r11,r4
	blo	gc_5
r_gc_5:
	ldr	r4,[r2,#4]
	add	r4,r4,#3
	lsr	r4,r4,#2

	mov	r3,r2
	mov	r2,r6

	laol	r7,__STRING__+2,__STRING___o_2,3
	otoa	r7,__STRING___o_2,3
	str	r7,[r6]
	ldr	r7,[r3,#4]
	add	r3,r3,#8
	str	r7,[r6,#4]
	add	r6,r6,#8

	add	r0,r0,r6

	cmp	r4,#0
	beq	updateAC_after_copy_lp

updateAC_copy_lp:
	ldr	r7,[r3],#4
	str	r7,[r6],#4
	subs	r4,r4,#1
	bne	updateAC_copy_lp

updateAC_after_copy_lp:
	strb	r1,[r0]

	pop	{pc}

gc_5:	bl	collect_1
	b	r_gc_5

update_string_error:
	lao	r4,high_index_string,0
	otoa	r4,high_index_string,0
	tst	r1,r1
	bpl	update_string_error_2
	lao	r4,low_index_string,0
	otoa	r4,low_index_string,0
update_string_error_2:
	b	print_error

.ifdef PIC
	ltol	__STRING__+2,__STRING___o_2,3
	lto	high_index_string,0
	lto	low_index_string,0
.endif

	.section .text.eqAC,"ax"
eqAC:
	ldr	r1,[r2,#4]
	ldr	r7,[r3,#4]
	cmp	r1,r7
	bne	equal_string_ne
	add	r2,r2,#8
	add	r3,r3,#8
	and	r0,r1,#3
	lsrs	r1,r1,#2
	beq	equal_string_b
equal_string_1:
	ldr	r4,[r2]
	ldr	r7,[r3]
	cmp	r4,r7
	bne	equal_string_ne
	add	r2,r2,#4
	add	r3,r3,#4
	subs	r1,r1,#1
	bne	equal_string_1
equal_string_b:
	tst	r0,#2
	beq	equal_string_2
	ldrh	r1,[r2]
	ldrh	r7,[r3]
	cmp	r1,r7
	bne	equal_string_ne
	add	r2,r2,#2
	add	r3,r3,#2
equal_string_2:
	tst	r0,#1
	beq	equal_string_eq
	ldrb	r0,[r2]
	ldrb	r7,[r3]
	cmp	r0,r7
	bne	equal_string_ne
equal_string_eq:
	mov	r1,#1
	pop	{pc}
equal_string_ne:
	mov	r1,#0
	pop	{pc}

	.section .text.cmpAC,"ax"
cmpAC:
	ldr	r0,[r2,#4]
	ldr	r4,[r3,#4]
	add	r2,r2,#8
	add	r3,r3,#8
	cmp	r4,r0
	blo	cmp_string_less
	bhi	cmp_string_more
	mov	r1,#0
	b	cmp_string_chars
cmp_string_more:
	mov	r1,#1
	b	cmp_string_chars
cmp_string_less:
	mov	r1,#-1
	mov	r0,r4
	b	cmp_string_chars

cmp_string_1:
	ldr	r4,[r3]
	ldr	r7,[r2]
	cmp	r4,r7
	bne	cmp_string_ne4
	add	r3,r3,#4
	add	r2,r2,#4
cmp_string_chars:
	subs	r0,r0,#4
	bcs	cmp_string_1
cmp_string_b:
@ to do compare bytes using and instead of ldrb
	tst	r0,#2
	beq	cmp_string_2
	ldrb	r4,[r3]
	ldrb	r7,[r2]
	cmp	r4,r7
	bne	cmp_string_ne
	ldrb	r4,[r3,#1]
	ldrb	r7,[r2,#1]
	cmp	r4,r7
	bne	cmp_string_ne
	add	r3,r3,#2
	add	r2,r2,#2
cmp_string_2:
	tst	r0,#1
	beq	cmp_string_eq
	ldrb	r4,[r3]
	ldrb	r7,[r2]
	cmp	r4,r7
	bne	cmp_string_ne
cmp_string_eq:
	pop	{pc}
cmp_string_ne4:
@ to do compare bytes using and instead of ldrb
	ldrb	r0,[r3]
	ldrb	r7,[r2]
	cmp	r0,r7
	bne	cmp_string_ne
	ldrb	r0,[r3,#1]
	ldrb	r7,[r2,#1]
	cmp	r0,r7
	bne	cmp_string_ne
	ldrb	r0,[r3,#2]
	ldrb	r7,[r2,#2]
	cmp	r0,r7
	bne	cmp_string_ne
	ldrb	r0,[r3,#3]
	ldrb	r7,[r2,#3]
	cmp	r0,r7
cmp_string_ne:
	bhi	cmp_string_r1
	mov	r1,#-1
	pop	{pc}
cmp_string_r1:
	mov	r1,#1
	pop	{pc}

	.section .text.string_to_string_node,"ax"
string_to_string_node:
	ldr	r4,[r2],#4

	add	r1,r4,#3
	lsr	r1,r1,#2

	add	r7,r1,#2
	subs	r11,r11,r7
	blo	string_to_string_node_gc

string_to_string_node_r:
	laol	r7,__STRING__+2,__STRING___o_2,4
	otoa	r7,__STRING___o_2,4
	str	r7,[r6]
	str	r4,[r6,#4]
	mov	r4,r6
	add	r6,r6,#8
	b	string_to_string_node_4

string_to_string_node_2:
	ldr	r7,[r2],#4
	str	r7,[r6],#4
string_to_string_node_4:
	subs	r1,r1,#1
	bge	string_to_string_node_2

	mov	r2,r4
	pop	{pc}

string_to_string_node_gc:
	stmdb	sp!,{r2,r4}
	bl	collect_0
	ldmia	sp!,{r2,r4}
	b	string_to_string_node_r

.ifdef PIC
	ltol	__STRING__+2,__STRING___o_2,4
.endif

	.section .text.int_array_to_node,"ax"
int_array_to_node:
	ldr	r1,[r2,#-8]

	add	r7,r1,#3
	subs	r11,r11,r7
	blo	int_array_to_node_gc

int_array_to_node_r:
	laol	r7,__ARRAY__+2,__ARRAY___o_2,0
	otoa	r7,__ARRAY___o_2,0
	str	r7,[r6]
	mov	r3,r2
	str	r1,[r6,#4]
	mov	r2,r6
	laol	r7,INT+2,INT_o_2,3
	otoa	r7,INT_o_2,3
	str	r7,[r6,#8]
	add	r6,r6,#12
	b	int_array_to_node_4

int_array_to_node_2:
	ldr	r7,[r3],#4
	str	r7,[r6],#4
int_array_to_node_4:
	subs	r1,r1,#1
	bge	int_array_to_node_2

	pop	{pc}

int_array_to_node_gc:
	str	r2,[sp,#-4]!
	bl	collect_0
	ldr	r2,[sp],#4
	b	int_array_to_node_r

.ifdef PIC
	ltol	__ARRAY__+2,__ARRAY___o_2,0
	ltol	INT+2,INT_o_2,3
.endif

	.section .text.real_array_to_node,"ax"
real_array_to_node:
	ldr	r1,[r2,#-8]

	add	r7,r1,#3+1
	subs	r11,r11,r7
	blo	real_array_to_node_gc

real_array_to_node_r:
	tst	r6,#4
	orr	r6,r6,#4
	it	ne
	addne	r11,r11,#1
	mov	r3,r2
	laol	r7,__ARRAY__+2,__ARRAY___o_2,1
	otoa	r7,__ARRAY___o_2,1
	str	r7,[r6]
	str	r1,[r6,#4]
	mov	r2,r6
	laol	r7,REAL+2,REAL_o_2,2
	otoa	r7,REAL_o_2,2
	str	r7,[r6,#8]
	add	r6,r6,#12
	b	real_array_to_node_4

real_array_to_node_2:
	ldr	r7,[r3]
	str	r7,[r6]
	ldr	r4,[r3,#4]
	add	r3,r3,#8
	str	r4,[r6,#4]
	add	r6,r6,#8
real_array_to_node_4:
	subs	r1,r1,#1
	bge	real_array_to_node_2

	pop	{pc}

real_array_to_node_gc:
	str	r2,[sp,#-4]!
	bl	collect_0
	ldr	r2,[sp],#4
	b	real_array_to_node_r

.ifdef PIC
	ltol	__ARRAY__+2,__ARRAY___o_2,1
	ltol	REAL+2,REAL_o_2,2
.endif
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

@
@	ARRAYS
@

_create_arrayB:
	add	r0,r1,#3
	lsr	r0,r0,#2

	add	r7,r0,#3
	subs	r11,r11,r7
	bhs	no_collect_4574
	bl	collect_0
no_collect_4574:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,2
	otoa	r7,__ARRAY___o_2,2
	str	r7,[r6]
	str	r1,[r6,#4]
	laol	r7,BOOL+2,BOOL_o_2,2
	otoa	r7,BOOL_o_2,2
	str	r7,[r6,#8]
	add	r7,r6,#12
	add	r6,r7,r0,lsl #2
	pop	{pc}

_create_arrayC:
	add	r0,r1,#3
	lsr	r0,r0,#2

	add	r7,r0,#2
	subs	r11,r11,r7
	bhs	no_collect_4573
	bl	collect_0
no_collect_4573:
	mov	r2,r6
	laol	r7,__STRING__+2,__STRING___o_2,5
	otoa	r7,__STRING___o_2,5
	str	r7,[r6]
	str	r1,[r6,#4]
	add	r7,r6,#8
	add	r6,r7,r0,lsl #2
	pop	{pc}

_create_arrayI:
	add	r7,r1,#3
	subs	r11,r11,r7
	bhs	no_collect_4572
	bl	collect_0
no_collect_4572:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,3
	otoa	r7,__ARRAY___o_2,3
	str	r7,[r6]
	str	r1,[r6,#4]
	laol	r7,INT+2,INT_o_2,4
	otoa	r7,INT_o_2,4
	str	r7,[r6,#8]
	add	r7,r6,#12
	add	r6,r7,r1,lsl #2
	pop	{pc}

_create_arrayR:
	add	r7,r1,r1
	add	r7,r7,#3+1
	subs	r11,r11,r7
	bhs	no_collect_4580
	bl	collect_0
no_collect_4580:
	tst	r6,#4
	orr	r6,r6,#4
	it	ne
	addne	r11,r11,#1
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,4
	otoa	r7,__ARRAY___o_2,4
	str	r7,[r6]
	str	r1,[r6,#4]
	laol	r7,REAL+2,REAL_o_2,3
	otoa	r7,REAL_o_2,3
	str	r7,[r6,#8]
	add	r7,r6,#12
	add	r6,r7,r1,lsl #3
	pop	{pc}

@ r1: number of elements, r0: element descriptor
@ r10: element size, r9: element a size, a0:a_element-> a0: array

_create_r_array:
	mul	r7,r1,r10
	add	r7,r7,#3
	subs	r11,r11,r7
	bhs	no_collect_4586
	bl	collect_1
no_collect_4586:
	mov	r4,r2

	laol	r7,__ARRAY__+2,__ARRAY___o_2,5
	otoa	r7,__ARRAY___o_2,5
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]

	mov	r2,r6
	add	r6,r6,#12

@ r1: number of elements, a0: array
@ r10: element size, r9: element a size, a2:a_element

	cmp	r9,#0
	beq	_create_r_array_0
	cmp	r9,#2
	blo	_create_r_array_1
	beq	_create_r_array_2
	cmp	r9,#4
	blo	_create_r_array_3
	beq	_create_r_array_4
	b	_create_r_array_5

_create_r_array_0:
	lsl	r10,r10,#2
	mul	r7,r1,r10
	add	r6,r6,r7
	pop	{pc}

_create_r_array_1:
	lsl	r10,r10,#2
	b	_st_fillr1_array
_fillr1_array:
	str	r4,[r6]
	add	r6,r6,r10
_st_fillr1_array:
	subs	r1,r1,#1
	bcs	_fillr1_array
	pop	{pc}

_create_r_array_2:
	lsl	r10,r10,#2
	b	_st_fillr2_array
_fillr2_array:
	str	r4,[r6]
	str	r4,[r6,#4]
	add	r6,r6,r10
_st_fillr2_array:
	subs	r1,r1,#1
	bcs	_fillr2_array
	pop	{pc}

_create_r_array_3:
	lsl	r10,r10,#2
	b	_st_fillr3_array
_fillr3_array:
	str	r4,[r6]
	str	r4,[r6,#4]
	str	r4,[r6,#8]
	add	r6,r6,r10
_st_fillr3_array:
	subs	r1,r1,#1
	bcs	_fillr3_array
	pop	{pc}

_create_r_array_4:
	lsl	r10,r10,#2
	b	_st_fillr4_array
_fillr4_array:
	str	r4,[r6]
	str	r4,[r6,#4]
	str	r4,[r6,#8]
	str	r4,[r6,#12]
	add	r6,r6,r10
_st_fillr4_array:
	subs	r1,r1,#1
	bcs	_fillr4_array
	pop	{pc}

_create_r_array_5:
	sub	r10,r10,r9
	lsl	r10,r10,#2
	b	_st_fillr5_array

_fillr5_array:
	str	r4,[r6]
	str	r4,[r6,#4]
	str	r4,[r6,#8]
	str	r4,[r6,#12]
	add	r6,r6,#16

	sub	r0,r9,#5
_copy_elem_5_lp:
	str	r4,[r6],#4
	subs	r0,r0,#1
	bcs	_copy_elem_5_lp

	add	r6,r6,r10
_st_fillr5_array:
	subs	r1,r1,#1
	bcs	_fillr5_array

	pop	{pc}

create_arrayB:
	mov	r3,r0
	add	r0,r0,#3
	lsr	r0,r0,#2

	add	r7,r0,#3
	subs	r11,r11,r7
	bhs	no_collect_4575

	str	r3,[sp,#-4]!
	bl	collect_0
	ldr	r3,[sp],#4

no_collect_4575:
	orr	r1,r1,r1,lsl #8
	orr	r1,r1,r1,lsl #16
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,6
	otoa	r7,__ARRAY___o_2,6
	str	r7,[r6]
	str	r3,[r6,#4]
	laol	r7,BOOL+2,BOOL_o_2,3
	otoa	r7,BOOL_o_2,3
	str	r7,[r6,#8]
	add	r6,r6,#12
	b	create_arrayBCI

create_arrayC:
	mov	r3,r0
	add	r0,r0,#3
	lsr	r0,r0,#2

	add	r7,r0,#2
	subs	r11,r11,r7
	bhs	no_collect_4578

	str	r3,[sp,#-4]!
	bl	collect_0
	ldr	r3,[sp],#4

no_collect_4578:
	orr	r1,r1,r1,lsl #8
	orr	r1,r1,r1,lsl #16
	mov	r2,r6
	laol	r7,__STRING__+2,__STRING___o_2,6
	otoa	r7,__STRING___o_2,6
	str	r7,[r6]
	str	r3,[r6,#4]
	add	r6,r6,#8
	b	create_arrayBCI

create_arrayI:
	add	r7,r0,#3
	subs	r11,r11,r7
	bhs	no_collect_4577

	bl	collect_0

no_collect_4577:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,7
	otoa	r7,__ARRAY___o_2,7
	str	r7,[r6]
	str	r0,[r6,#4]
	laol	r7,INT+2,INT_o_2,5
	otoa	r7,INT_o_2,5
	str	r7,[r6,#8]
	add	r6,r6,#12
create_arrayBCI:
	tst	r0,#1
	lsr	r0,r0,#1
	beq	st_filli_array

	str	r1,[r6],#4
	b	st_filli_array

filli_array:
	str	r1,[r6]
	str	r1,[r6,#4]
	add	r6,r6,#8
st_filli_array:
	subs	r0,r0,#1
	bcs	filli_array

	pop	{pc}

create_arrayR:
	add	r7,r1,r1
	add	r7,r7,#3+1

	vmov	r0,r3,d0

	subs	r11,r11,r7
	bhs	no_collect_4579

	str	r3,[sp,#-4]!
	bl	collect_0
	ldr	r3,[sp],#4

no_collect_4579:
	tst	r6,#4
	orr	r6,r6,#4
	it	ne
	addne	r11,r11,#1

	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,8
	otoa	r7,__ARRAY___o_2,8
	str	r7,[r6]
	str	r1,[r6,#4]
	laol	r7,REAL+2,REAL_o_2,4
	otoa	r7,REAL_o_2,4
	str	r7,[r6,#8]
	add	r6,r6,#12
	b	st_fillr_array
fillr_array:
	str	r0,[r6]
	str	r3,[r6,#4]
	add	r6,r6,#8
st_fillr_array:
	subs	r1,r1,#1
	bcs	fillr_array

	pop	{pc}

create_array:
	add	r7,r1,#3
	subs	r11,r11,r7
	bhs	no_collect_4576

	bl	collect_1

no_collect_4576:
	mov	r0,r2
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,9
	otoa	r7,__ARRAY___o_2,9
	str	r7,[r6]
	str	r1,[r6,#4]
	mov	r7,#0
	str	r7,[r6,#8]
	add	r6,r6,#12
	mov	r9,r1
	b	fillr1_array

@ in r1: number of elements, r0: element descriptor
@ r10: element size, r9: element a size -> a0: array

create_R_array:
	cmp	r10,#2
	blo	create_R_array_1
	beq	create_R_array_2
	cmp	r10,#4
	blo	create_R_array_3
	beq	create_R_array_4
	b	create_R_array_5

create_R_array_1:
@ r1: number of elements, r0: element descriptor
@ r9: element a size

	add	r7,r1,#3
	subs	r11,r11,r7
	bhs	no_collect_4581

	bl	collect_0

no_collect_4581:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,10
	otoa	r7,__ARRAY___o_2,10
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]
	add	r6,r6,#12

	cmp	r9,#0
	beq	r_array_1_b

	ldr	r0,[r5,#-4]
	b	fillr1_array

r_array_1_b:
	ldr	r0,[sp,#4]

fillr1_array:
	tst	r1,#1
	lsr	r1,r1,#1
	beq	st_fillr1_array_1

	str	r0,[r6],#4
	b	st_fillr1_array_1

fillr1_array_lp:
	str	r0,[r6]
	str	r0,[r6,#4]
	add	r6,r6,#8
st_fillr1_array_1:
	subs	r1,r1,#1
	bcs	fillr1_array_lp

	pop	{pc}

create_R_array_2:
@ r1: number of elements, r0: element descriptor
@ r9: element a size

	add	r7,r1,r1
	add	r7,r7,#3
	subs	r11,r11,r7
	bhs	no_collect_4582

	bl	collect_0

no_collect_4582:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,11
	otoa	r7,__ARRAY___o_2,11
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]
	add	r6,r6,#12

	subs	r9,r9,#1
	blo	r_array_2_bb
	beq	r_array_2_ab
r_array_2_aa:
	ldr	r0,[r5,#-4]
	ldr	r4,[r5,#-8]
	b	st_fillr2_array
r_array_2_ab:
	ldr	r0,[r5,#-4]
	ldr	r4,[sp,#4]
	b	st_fillr2_array
r_array_2_bb:
	ldr	r0,[sp,#4]
	ldr	r4,[sp,#8]
	b	st_fillr2_array

fillr2_array_1:
	str	r0,[r6]
	str	r4,[r6,#4]
	add	r6,r6,#8
st_fillr2_array:
	subs	r1,r1,#1
	bcs	fillr2_array_1

	pop	{pc}

create_R_array_3:
@ r1: number of elements, r0: element descriptor
@ r9: element a size

	add	r7,r1,r1,lsl #1
	add	r7,r7,#3
	subs	r11,r11,r7
	bhs	no_collect_4583

	bl	collect_0

no_collect_4583:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,12
	otoa	r7,__ARRAY___o_2,12
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]
	add	r6,r6,#12

	ldr	lr,[sp],#4
	mov	r10,sp

	cmp	r9,#0
	beq	r_array_3

	sub	r4,r5,r9,lsl #2
	subs	r9,r9,#1

copy_a_to_b_lp3:
	ldr	r7,[r4],#4
	str	r7,[sp,#-4]!
	subs	r9,r9,#1
	bcs	copy_a_to_b_lp3

r_array_3:
	ldr	r0,[sp]
	ldr	r3,[sp,#4]
	ldr	r4,[sp,#8]	

	mov	sp,r10
	b	st_fillr3_array

fillr3_array_1:
	str	r0,[r6]
	str	r3,[r6,#4]
	str	r4,[r6,#8]
	add	r6,r6,#12
st_fillr3_array:
	subs	r1,r1,#1
	bcs	fillr3_array_1

	bx	lr

create_R_array_4:
@ r1: number of elements, r0: element descriptor
@ r9: element a size

	lsl	r7,r1,#2
	add	r7,r7,#3
	subs	r11,r11,r7
	bhs	no_collect_4584

	bl	collect_0

no_collect_4584:
	mov	r2,r6
	laol	r7,__ARRAY__+2,__ARRAY___o_2,13
	otoa	r7,__ARRAY___o_2,13
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]
	add	r6,r6,#12

	ldr	lr,[sp],#4
	mov	r10,sp

	cmp	r9,#0
	beq	r_array_4
	
	sub	r4,r5,r9,lsl #2
	subs	r9,r9,#1

copy_a_to_b_lp4:
	ldr	r7,[r4],#4
	str	r7,[sp,#-4]!
	subs	r9,r9,#1
	bcs	copy_a_to_b_lp4

r_array_4:
	ldr	r8,[sp]
	ldr	r0,[sp,#4]
	ldr	r3,[sp,#8]
	ldr	r4,[sp,#12]

	mov	sp,r10
	b	st_fillr4_array

fillr4_array:
	str	r8,[r6]
	str	r0,[r6,#4]
	str	r3,[r6,#8]
	str	r4,[r6,#12]
	add	r6,r6,#16
st_fillr4_array:
	subs	r1,r1,#1
	bcs	fillr4_array

	bx	lr

create_R_array_5:
@ r1: number of elements, r0: element descriptor
@ r9: element a size, r10: element size

	mul	r7,r1,r10
	add	r7,r7,#3
	subs	r11,r11,r7
	bhs	no_collect_4585

	bl	collect_0

no_collect_4585:
	laol	r7,__ARRAY__+2,__ARRAY___o_2,14
	otoa	r7,__ARRAY___o_2,14
	str	r7,[r6]
	str	r1,[r6,#4]
	str	r0,[r6,#8]

	ldr	lr,[sp],#4
	mov	r12,sp

	cmp	r9,#0
	beq	r_array_5

	sub	r4,r5,r9,lsl #2
	subs	r9,r9,#1

copy_a_to_b_lp5:
	ldr	r7,[r4],#4
	str	r7,[sp,#-4]!
	subs	r9,r9,#1
	bcs	copy_a_to_b_lp5

r_array_5:
	mov	r2,r6
	add	r6,r6,#12

	ldr	r0,[sp]
	ldr	r3,[sp,#4]
	b	st_fillr5_array

fillr5_array_1:
	str	r0,[r6]
	str	r3,[r6,#4]

	sub	r7,r10,#5

	ldr	r4,[sp,#8]
	str	r4,[r6,#8]

	ldr	r4,[sp,#12]
	add	r8,sp,#16
	str	r4,[r6,#12]
	add	r6,r6,#16

copy_elem_lp5:
	ldr	r4,[r8],#4
	str	r4,[r6],#4
	subs	r7,r7,#1
	bcs	copy_elem_lp5

st_fillr5_array:
	subs	r1,r1,#1
	bcs	fillr5_array_1

	mov	sp,r12

	bx	lr

repl_args_b:
	cmp	r1,#0
	ble	repl_args_b_1

	subs	r1,r1,#1
	beq	repl_args_b_4

	ldr	r3,[r2,#8]
	subs	r0,r0,#2
	bne	repl_args_b_2

	str	r3,[r5],#4
	b	repl_args_b_4

repl_args_b_2:
	add	r3,r3,r1,lsl #2

repl_args_b_3:
	ldr	r4,[r3,#-4]!
	str	r4,[r5],#4
	subs	r1,r1,#1
	bne	repl_args_b_3

repl_args_b_4:
	ldr	r4,[r2,#4]
	str	r4,[r5],#4
repl_args_b_1:
	pop	{pc}

push_arg_b:
	cmp	r0,#2
	blo	push_arg_b_1
	bne	push_arg_b_2
	cmp	r0,r1
	beq	push_arg_b_1
push_arg_b_2:
	ldr	r2,[r2,#8]
	subs	r0,r0,#2
push_arg_b_1:
	ldr	r2,[r2,r0,lsl #2]
	pop	{pc}

del_args:
	ldr	r0,[r2]
	subs	r0,r0,r1
	ldrsh	r1,[r0,#-2]
	subs	r1,r1,#2
	bge	del_args_2

	str	r0,[r3]
	ldr	r4,[r2,#4]
	str	r4,[r3,#4]	
	ldr	r4,[r2,#8]
	str	r4,[r3,#8]
	pop	{pc}

del_args_2:
	bne	del_args_3

	str	r0,[r3]
	ldr	r4,[r2,#4]
	str	r4,[r3,#4]
	ldr	r4,[r2,#8]
	ldr	r4,[r4]
	str	r4,[r3,#8]
	pop	{pc}

del_args_3:
	subs	r11,r11,r1
	blo	del_args_gc
del_args_r_gc:
	str	r0,[r3]
	str	r6,[r3,#8]
	ldr	r4,[r2,#4]
	ldr	r2,[r2,#8]
	str	r4,[r3,#4]

del_args_copy_args:
	ldr	r4,[r2],#4
	str	r4,[r6],#4
	subs	r1,r1,#1
	bgt	del_args_copy_args

	pop	{pc}

del_args_gc:
	bl	collect_2
	b	del_args_r_gc

	.section .text.sin_real,"ax"
sin_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	sin
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.cos_real,"ax"
cos_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	cos
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.tan_real,"ax"
tan_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	tan
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.asin_real,"ax"	
asin_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	asin
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.acos_real,"ax"
acos_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	acos
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.atan_real,"ax"
atan_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	atan
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.ln_real,"ax"
ln_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	log
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.log10_real,"ax"
log10_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	log10
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.exp_real,"ax"
exp_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	exp
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.pow_real,"ax"
pow_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d1
	vmov	r2,r3,d0
.else
	vmov.f64 d2,d0
	vmov.f64 d0,d1
	vmov.f64 d1,d2
.endif
	bl	pow
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif
	pop	{pc}

	.section .text.entier_real,"ax"
entier_real:
.ifdef SOFT_FP_CC
	vmov	r0,r1,d0
.endif
	bl	floor
.ifdef SOFT_FP_CC
	vmov	d0,r0,r1
.endif

r_to_i_real:
	vcvtr.s32.f64 s0,d0
	vmov	r1,s0
	pop	{pc}

	.text

.ifdef PIC
 .if MARK_GC
	lto	__cycle__in__spine,0
  .if MARK_AND_COPY_GC
 	lto	flags,14
  .endif
 .endif
	lto	e__system__nind,0
	lto	e__system__nind,1
	lto	e__system__nind,2
	lto	e__system__nind,3
	lto	e__system__nind,4
	lto	e__system__nind,5
	lto	e__system__nind,6
	lto	e__system__nind,7
	ltol	__STRING__+2,__STRING___o_2,5
	ltol	__STRING__+2,__STRING___o_2,6
	ltol	__ARRAY__+2,__ARRAY___o_2,2
	ltol	BOOL+2,BOOL_o_2,2
	ltol	__ARRAY__+2,__ARRAY___o_2,3
	ltol	INT+2,INT_o_2,4
	ltol	__ARRAY__+2,__ARRAY___o_2,4
	ltol	REAL+2,REAL_o_2,3
	ltol	__ARRAY__+2,__ARRAY___o_2,5
	ltol	__ARRAY__+2,__ARRAY___o_2,6
	ltol	BOOL+2,BOOL_o_2,3
	ltol	__ARRAY__+2,__ARRAY___o_2,7
	ltol	INT+2,INT_o_2,5
	ltol	__ARRAY__+2,__ARRAY___o_2,8
	ltol	REAL+2,REAL_o_2,4
	ltol	__ARRAY__+2,__ARRAY___o_2,9
	ltol	__ARRAY__+2,__ARRAY___o_2,10
	ltol	__ARRAY__+2,__ARRAY___o_2,11
	ltol	__ARRAY__+2,__ARRAY___o_2,12
	ltol	__ARRAY__+2,__ARRAY___o_2,13
	ltol	__ARRAY__+2,__ARRAY___o_2,14
.endif
	.ltorg

.if NEW_DESCRIPTORS
	.include "tap.s"
.endif
