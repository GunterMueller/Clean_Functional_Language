!	File:	sstartup.s
!	Author:	John van Groningen
!	At:	University of Nijmegen
!	Machine:	Sun 4

#define SHARE_CHAR_INT
#define COPIED_VECTOR
#define MY_ITOS
#define FINALIZERS
#define STACK_OVERFLOW_EXCEPTION_HANDLER
#undef ADD_SYSTEM_TIME
#undef COUNT_GARBAGE_COLLECTIONS
#define SP_G5
#define MARK_GC
#define NEW_DESCRIPTORS

#ifdef NEW_DESCRIPTORS
# define ZERO_ARITY_DESCRIPTOR_OFFSET (-4)
#else
# define ZERO_ARITY_DESCRIPTOR_OFFSET (-12)
#endif

#define ldg(g,r) sethi %hi g,%o0 ; ld [%o0+%lo g],r
#define ldgr(g,r,ir) sethi %hi g,ir ; ld [ir+%lo g],r
#define stg(r,g) sethi %hi g,%o0 ; st r,[%o0+%lo g]
#define stgr(r,g,ir) sethi %hi g,ir ; st r,[ir+%lo g]
#define ldgsb(g,r) sethi %hi g,%o0 ; ldsb [%o0+%lo g],r
#define ldgub(g,r) sethi %hi g,%o0 ; ldub [%o0+%lo g],r
#define stgb(r,g) sethi %hi g,%o0 ; stb r,[%o0+%lo g]
#define seth(g,r) sethi %hi (g),r
#define setl(g,r) add r,%lo (g),r

#define setmbit(vector,bit_n,byte_offset,bit,byte,scratch) \
	mov	128,bit ;\
	srl	bit_n,3,byte_offset ;\
	ldub	[vector+byte_offset],byte ;\
	and	bit_n,7,scratch ;\
	srl	bit,scratch,bit ;\
	bset	bit,byte ;\
	stb	byte,[vector+byte_offset]

#define tstmbit(vector,bit_n,byte_offset,bit,byte,scratch) \
	mov	128,bit ;\
	srl	bit_n,3,byte_offset ;\
	ldub	[vector+byte_offset],byte ;\
	and	bit_n,7,scratch ;\
	srl	bit,scratch,bit ;\
	btst	bit,byte

#define tst_bit(vector,bit_n,byte_offset,bit,byte) \
	mov	128,bit ;\
	srl	bit_n,3,byte_offset ;\
	ldub	[vector+byte_offset],byte ;\
	and	bit_n,7,bit_n ;\
	srl	bit,bit_n,bit ;\
	btst	bit,byte

#define clrmbit(vector,bit_n,byte_offset,bit,byte,scratch) \
	mov	128,bit ;\
	srl	bit_n,3,byte_offset ;\
	ldub	[vector+byte_offset],byte ;\
	and	bit_n,7,scratch ;\
	srl	bit,scratch,bit ;\
	bclr	bit,byte ;\
	stb	byte,[vector+byte_offset]

#ifdef SOLARIS
#define lcomm(a) .comm a,4,4
#else
#define lcomm(a) .comm a,4
#endif

#define d0 %l0
#define d1 %l1
#define d2 %l2
#define d3 %l3
#define d4 %l4
#define d5 %l5
#define d6 %l6
#define d7 %l7
#define a0 %i0
#define a1 %i1
#define a2 %i2
#define a3 %i3
#define a4 %i4
#define a5 %i5
#define a6 %g6
#ifdef SP_G5
# define sp %g5
#else
# define sp %g7
#endif
	.data

	lcomm	(heap_mbp)
#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	lcomm	(begin_b_stack_p)
#else
	lcomm	(stack_mbp)
#endif
	lcomm	(heap_p)
	lcomm	(heap_p1)
	lcomm	(heap_p2)
heap_p3:	.long	0
heap_vector:	.long	0
	lcomm	(heap_size_33)
#ifdef COPIED_VECTOR
	lcomm	(heap_size_129)
	lcomm	(heap_copied_vector)
	lcomm	(heap_copied_vector_size)
#endif
heap_end_after_gc:	.long	0
	lcomm	(extra_heap)
	lcomm	(extra_heap_size)
	lcomm	(stack_p)
	.global	halt_sp
	lcomm	(halt_sp)

#ifdef MARK_GC
bit_counter:	.long	0
bit_vector_p:	.long	0
zero_bits_before_mark: .long	1
free_after_mark:	.long	1000
last_heap_free:	.long	0
lazy_array_list:	.long	0
#endif

caf_list:	.word	0
	.global	caf_listp
caf_listp: .word	0
! number of long words requested from the garbage collector
	lcomm	(alloc_size)
	lcomm	(basic_only)

#ifdef SOLARIS
	lcomm	(last_time)
	lcomm	(execute_time)
	lcomm	(garbage_collect_time)
	lcomm	(IO_time)
#else
	.comm	last_time,8
	.comm	execute_time,8
	.comm	garbage_collect_time,8
	.comm	IO_time,8
#endif

#ifdef SOLARIS
	.comm	jump_buffer,9*4,4
#else
	.comm	jump_buffer,9*4
#endif

zero_length_string:
	.word	__STRING__+2
	.word	0
true_string:
	.word	__STRING__+2
	.word	4
true_c_string:
	.ascii	"True"
	.byte	0,0,0,0
false_string:
	.word	__STRING__+2
	.word	5
false_c_string:
	.ascii	"False"
	.byte	0,0,0
file_c_string:
	.ascii	"File"
	.byte	0,0,0,0
garbage_collect_flag:
	.byte	0
	.byte	0,0,0
#ifdef COUNT_GARBAGE_COLLECTIONS
n_garbage_collections:	.word	0
#endif

#ifdef SOLARIS
	.comm	sprintf_buffer,32,4
#else
	.comm	sprintf_buffer,32
#endif
out_of_memory_string_1:
	.ascii	"Not enough memory to allocate heap and stack"
	.byte	10,0
printf_int_string:
	.ascii	"%d"
	.byte	0
printf_real_string:
	.ascii	"%g"
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
#ifdef COUNT_GARBAGE_COLLECTIONS
	.ascii	"("
#endif
	.byte	0
#ifdef COUNT_GARBAGE_COLLECTIONS
time_string_3:
	.ascii	") "
	.byte	0
#endif
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
#ifdef MARK_GC
marked_gc_string_1:
	.ascii	"Marked: "
	.byte	0
#endif

#ifdef SOLARIS
	.comm	sprintf_time_buffer,20
	.align	4
#else
	.comm	sprintf_time_buffer,20
	.align	2
#endif
first_one_bit_table:
	.byte	-1,7,6,6,5,5,5,5,4,4,4,4,4,4,4,4
	.byte	3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3
	.byte	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
	.byte	2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2
	.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	.byte	1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.byte	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

#ifdef SHARE_CHAR_INT
	.global	small_integers
	.global	static_characters
#ifdef SOLARIS
	.comm	small_integers,33*8,4
	.comm	static_characters,256*8,4
#else
	.comm	small_integers,33*8
	.comm	static_characters,256*8
#endif
#endif

#ifdef FINALIZERS
	.global	__Nil
	.global	e____system__kFinalizer
	.global	e____system__kFinalizerGCTemp
	.global	finalizer_list
finalizer_list:
	.long	0
free_finalizer_list:
	.long	0
#endif

	.text

	.global	@abc_main
	.global	print
	.global	print_char
	.global	print_int
	.global	print_real
	.global	print__string__
	.global	print__chars__sc
	.global	print_sc
	.global	print_symbol
	.global	print_symbol_sc
	.global	printD
	.global	DtoAC

	.global	push_t_r_args
	.global	push_a_r_args

	.global	halt
	.global	dump
	
	.global	catAC
	.global	sliceAC
	.global	updateAC
	.global	eqAC
	.global	cmpAC
	.global	string_to_string_node

	.global	create_array
	.global	create_arrayB
	.global	create_arrayC
	.global	create_arrayI
	.global	create_arrayR
	.global	create_R_array

	.global	_create_arrayB
	.global	_create_arrayC
	.global	_create_arrayI
	.global	_create_arrayR
	.global	_create_r_array

	.global	BtoAC
	.global	ItoAC
	.global	RtoAC
	.global	eqD

	.global	collect_0
	.global	collect_1
	.global	collect_2
	.global	collect_3

#if 0
	.global	e__system__nAP
	.global	e__system__eaAP
#endif
	.global	e__system__sAP
	.global	yet_args_needed
	.global	yet_args_needed_0
	.global	yet_args_needed_1
	.global	yet_args_needed_2
	.global	yet_args_needed_3
	.global	yet_args_needed_4

	.global	_c3,_c4,_c5,_c6,_c7,_c8,_c9,_c10,_c11,_c12
	.global	_c13,_c14,_c15,_c16,_c17,_c18,_c19,_c20,_c21,_c22
	.global	_c23,_c24,_c25,_c26,_c27,_c28,_c29,_c30,_c31,_c32

	.global	e__system__nind
	.global	e__system__eaind
! old names of the previous two labels for compatibility, remove later
	.global	__indirection,__eaind
	.global	e__system__dind
	.global	eval_fill

	.global	eval_upd_0,eval_upd_1,eval_upd_2,eval_upd_3,eval_upd_4
	.global	eval_upd_5,eval_upd_6,eval_upd_7,eval_upd_8,eval_upd_9
	.global	eval_upd_10,eval_upd_11,eval_upd_12,eval_upd_13,eval_upd_14
	.global	eval_upd_15,eval_upd_16,eval_upd_17,eval_upd_18,eval_upd_19
	.global	eval_upd_20,eval_upd_21,eval_upd_22,eval_upd_23,eval_upd_24
	.global	eval_upd_25,eval_upd_26,eval_upd_27,eval_upd_28,eval_upd_29
	.global	eval_upd_30,eval_upd_31,eval_upd_32
	
	.global	repl_args_b
	.global	push_arg_b
	.global	del_args
#if 0
	.global	o__S_P2
	.global	ea__S_P2
#endif

	.global	add_IO_time
	.global	add_execute_time
	
	.global	@IO_error
	.global	stack_overflow

	.global	out_of_memory_4
	
#ifdef SOLARIS
	.global	__start
#else
	.global	_start
#endif
	.global	__driver
	
! from system.abc:	
	.global	INT
	.global	CHAR
	.global	BOOL
	.global	REAL
	.global	FILE
	.global	__STRING__
	.global	__ARRAY__
	.global	__cycle__in__spine
	.global	__print__graph
	.global	__eval__to__nf

! from cgscon.c:
	.global	@w_print_char
	.global	@w_print_string
	.global	@w_print_text
	.global	@w_print_int
	.global	@w_print_real
	
	.global	@ew_print_char
	.global	@ew_print_text
	.global	@ew_print_string
	.global	@ew_print_int
	
	.global	@ab_stack_size
	.global	@heap_size
	.global	@flags
	.global	@execution_aborted

! from standard c library:
	.global	@malloc
	.global	@free
!	.global	@rand
	.global	@sprintf
	.global	@strlen

@abc_main:
	save	%o6,-128,%o6
	save	%o6,-256,%o6

	ldg	(@flags,d0)
	and	d0,1,d0
	stg	(d0,basic_only)

	ldg	(@heap_size,d0)
	sub	d0,3,%o0
	call	.udiv
	mov	33,%o1
	stgr	(%o0,heap_size_33,%o1)

#ifdef COPIED_VECTOR
	ldg	(@heap_size,d0)
	sub	d0,3,%o0
	call	.udiv
	mov	129,%o1
	stgr	(%o0,heap_size_129,%o1)
	inc	3,%o0
	andn	%o0,3,%o0
	stgr	(%o0,heap_copied_vector_size,%o1)
#endif

	ldgr	(@heap_size,%o0,%o1)
	inc	7,%o0
	andn	%o0,7,%o0
	stgr	(%o0,@heap_size,%o1)
	call	@malloc
	inc	3+4,%o0
	
	tst	%o0
	beq	no_memory_2
	nop

	stgr	(%o0,heap_mbp,%o1)
	inc	3,%o0
	and	%o0,-4,a6
	stg	(a6,heap_p)
	stg	(a6,heap_p1)

#ifdef COPIED_VECTOR
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copied_vector1
	nop

	ldg	(heap_size_129,d1)
	sll	d1,6,d1
	add	a6,d1,d0
	stg	(d0,heap_copied_vector)
	stg	(d0,heap_end_after_gc)
	ldg	(heap_copied_vector_size,%o1)
	add	d0,%o1,d0
	stg	(d0,heap_p2)
	b,a	copied_vector1
no_copied_vector1:
#endif

	ldg	(@heap_size,d1)
	srl	d1,1,d1
	add	a6,d1,d0
	stg	(d0,heap_end_after_gc)
	stg	(d0,heap_p2)
copied_vector1:

	ldg	(@ab_stack_size,d0)
#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	call	@allocate_stack
	add	d0,0,%o0
#else
	call	@malloc
	add	d0,3,%o0
#endif
	
	tst	%o0
	beq	no_memory_3
	nop

#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	ldgr	(@ab_stack_size,d0,%o1)
	inc	3,d0
	and	d0,-4,d0

	sub	%o0,d0,%i4
	stgr	(%i4,stack_p,%o1)

	add	%o0,d0,sp
	set	8192,%o1
	add	sp,%o1,sp
	stg	(sp,begin_b_stack_p)
#else
	stgr	(%o0,stack_mbp,%o1)
	inc	3,%o0
	and	%o0,-4,d0

	mov	d0,%i4
	ldg	(@ab_stack_size,sp)
	add	sp,d0,sp
	stg	(d0,stack_p)
#endif

#ifdef SHARE_CHAR_INT
	set	small_integers,a0
	mov	0,d0
	set	INT+2,d1
make_small_integers_lp:
	st	d1,[a0]
	st	d0,[a0+4]
	inc	1,d0
	cmp	d0,33
	bne	make_small_integers_lp
	inc	8,a0

	set	static_characters,a0
	mov	0,d0
	set	CHAR+2,d1
make_static_characters_lp:
	st	d1,[a0]
	st	d0,[a0+4]
	inc	1,d0
	cmp	d0,256
	bne	make_static_characters_lp
	inc	8,a0
#endif

	set	caf_list+4,a0
	stg	(a0,caf_listp)

#ifdef FINALIZERS
	set	__Nil-8,a0
	stg	(a0,finalizer_list)
	stg	(a0,free_finalizer_list)
#endif

#ifdef COPIED_VECTOR
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copied_vector2
	nop

	ldg	(heap_size_129,d7)
	ba	copied_vector2
	sll	d7,6-2,d7
no_copied_vector2:
#endif
	ldg	(@heap_size,d7)
	srl	d7,3,d7

copied_vector2:

	seth	(garbage_collect_flag,%o0)
	clrb	[%o0+%lo garbage_collect_flag]

	ldg	(@flags,d0)
	btst	32+64,d0
	beq	no_compact_or_mark_gc
	nop

	ldg	(heap_size_33,d0)
	sll	d0,3,d7
	stg	(a6,heap_vector)
	add	a6,d0,a6
	add	a6,3,a6
	andn	a6,3,a6
	stg	(a6,heap_p3)
	sll	d0,5,d0
	add	d0,a6,d0
	stg	(d0,heap_end_after_gc)
	mov	-1,d0
	seth	(garbage_collect_flag,%o0)
	stb	d0,[%o0+%lo garbage_collect_flag]

no_compact_or_mark_gc:

	dec	4,sp
	call	init_timer
	st	%o7,[sp]

	stg	(sp,halt_sp)

	seth	(jump_buffer,%o0)
	call	@setjmp
	setl	(jump_buffer,%o0)

	tst	%o0
	bne	exit
	nop

	set	__cycle__in__spine,a5

	dec	4,sp
#ifdef SOLARIS
	call	__start
#else
	call	_start
#endif
	st	%o7,[sp]
	
exit:
	dec	4,sp
	call	add_execute_time
	st	%o7,[sp]

	ldg	(@flags,d0)
	andcc	d0,8,%g0
	beq	no_print_execution_time
	nop
	
	seth	(time_string_1,%o0)
	call	@ew_print_string
	setl	(time_string_1,%o0)
	
	set	execute_time,a0
	ld	[a0],d0
#ifndef SOLARIS
	ld	[a0+4],d1
#endif
	dec	4,sp
	call	print_time
	st	%o7,[sp]
	
	seth	(time_string_2,%o0)
	call	@ew_print_string
	setl	(time_string_2,%o0)

#ifdef COUNT_GARBAGE_COLLECTIONS
	sethi	%hi n_garbage_collections,%o0
	call	@ew_print_int
	ld	[%o0+%lo n_garbage_collections],%o0

	seth	(time_string_3,%o0)
	call	@ew_print_string
	setl	(time_string_3,%o0)
#endif

	set	garbage_collect_time,a0
	ld	[a0],d0
#ifndef SOLARIS
	ld	[a0+4],d1
#endif
	dec	4,sp
	call	print_time
	st	%o7,[sp]
	
	seth	(time_string_4,%o0)
	call	@ew_print_string
	setl	(time_string_4,%o0)

#ifdef SOLARIS
	set	execute_time,a0
	ld	[a0],d0
	set	garbage_collect_time,a0
	ld	[a0],d2
	add	d0,d2,d0
	set	IO_time,a0
	ld	[a0],d2
	add	d0,d2,d0
#else
	set	execute_time,a0
	ld	[a0],d0
	ld	[a0+4],d1

	set	garbage_collect_time,a0
	ld	[a0],d2
	ld	[a0+4],%l3
	add	d0,d2,d0
	add	d1,d3,d1
	set	1000000,d4
	cmp	d1,d4
	bcs	no_usec_overflow_1
	nop
	sub	d1,d4,d1
	inc	1,d0
no_usec_overflow_1:
	
	set	IO_time,a0
	ld	[a0],d2
	ld	[a0+4],d3
	add	d0,d2,d0
	add	d1,d3,d1
	cmp	d1,d4
	bcs	no_usec_overflow_2
	nop
	sub	d1,d4,d1
	inc	1,d0
no_usec_overflow_2:
#endif
	dec	4,sp
	call	print_time
	st	%o7,[sp]
	
	call	@ew_print_char
	mov	10,%o0

no_print_execution_time:
exit_3:
#ifndef STACK_OVERFLOW_EXCEPTION_HANDLER
	seth	(stack_mbp,%o1)
	call	@free
	ld	[%o1+%lo stack_mbp],%o0
#endif
exit_2:
	seth	(heap_mbp,%o1)
	call	@free
	ld	[%o1+%lo heap_mbp],%o0

exit_1:
	restore
	ret
	restore

__driver:
	ldgr	(@flags,%o0,%o1)
	btst	16,%o0
	beq	__print__graph
	nop	
	b,a	__eval__to__nf

print_time:
#ifdef SOLARIS
	call	_sysconf
	mov	3,%o0

	mov	%o0,d2

	mov	%o0,%o1
	call	.udiv
	mov	d0,%o0
	
	mov	%o0,d3
	
	mov	d2,%o1
	call	.urem
	mov	d0,%o0
	
	call	.umul
	mov	100,%o1
	
	call	.udiv
	mov	d2,%o1
	
	mov	%o0,%o3
	set	sprintf_time_string,%o1
	set	sprintf_time_buffer,%o0
	call	@sprintf
	mov	d3,%o2
#else
	set	10000,%o1
	call	.udiv
	mov	d1,%o0
	
	mov	%o0,%o3
	set	sprintf_time_string,%o1
	set	sprintf_time_buffer,%o0
	call	@sprintf
	mov	d0,%o2
#endif

	sethi	%hi sprintf_time_buffer,%o0
	call	@ew_print_string
	or	%o0,%lo sprintf_time_buffer,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

no_memory_2:
	seth	(out_of_memory_string_1,%o0)
	call	@ew_print_string
	setl	(out_of_memory_string_1,%o0)
	b,a	exit_1
	
no_memory_3:
	seth	(out_of_memory_string_1,%o0)
	call	@ew_print_string
	setl	(out_of_memory_string_1,%o0)
	b,a	exit_1

print_sc:
	ldg	(basic_only,%o1)
	tst	%o1
	bne	end_print
	nop
print:	
	call	@w_print_string
	mov	d0,%o0

end_print:
	ld	[sp],%o7
	retl
	inc	4,sp

dump:
	dec	4,sp
	call	print
	st	%o7,[sp]
	
	b,a	halt

printD:	btst	2,d0
	bne	printD_
	nop
	ba	print_string_a2
	mov	d0,a2

DtoAC:	btst	2,d0
	bne	DtoAC_
	nop

	add	d0,4,a0
	ba	build_string
	ld	[d0],d0

DtoAC_:
	ldsh	[d0-2],d1
#ifdef NEW_DESCRIPTORS
	cmp	d1,256
	bgeu,a	DtoAC_string_a0
	ld	[d0-6],a0
	
	lduh	[d0],d1
	add	d0,10,a0
	add	a0,d1,a0

DtoAC_string_a0:
	ld	[a0],d0
	ba	build_string
	inc	4,a0
#else
	add	d0,-2,a2
	cmp	d1,256
	bgeu	DtoAC_record
	sll	d1,3,d1
	sub	a2,d1,a2
DtoAC_record:
	ba	DtoAC_string_a2
	ld	[a2-4],a2

DtoAC_string_a2:
	ld	[a2],d0
	ba	build_string
	add	a2,4,a0
#endif

print_symbol:
	ba	print_symbol_2
	clr	d1

print_symbol_sc:
	ldg	(basic_only,d1)
print_symbol_2:
	ld	[a0],d0
	
	set	INT+2,%o0
	cmp	%o0,d0
	beq	print_int_node
	nop
	set	CHAR+2,%o0
	cmp	%o0,d0
	beq	print_char_node
	nop
	set	BOOL+2,%o0
	cmp	%o0,d0
	beq	print_bool
	nop
	set	REAL+2,%o0
	cmp	%o0,d0
	beq	print_real_node
	nop
	
	tst	d1
	bne	end_print_symbol
	nop

printD_:
	ldsh	[d0-2],d1
#ifdef NEW_DESCRIPTORS
	cmp	d1,256
	bgeu,a	print_string_a2
	ld	[d0-6],a2

	lduh	[d0],d1
	add	d0,10,a2
	ba	print_string_a2
	add	a2,d1,a2
#else
	add	d0,-2,a2
	cmp	d1,256
	bgeu	print_record
	sll	d1,3,d1
	sub	a2,d1,a2
print_record:
	ba	print_string_a2
	ld	[a2-4],a2
#endif

end_print_symbol:
	ld	[sp],%o7
	retl
	inc	4,sp

print_int_node:
	call	@w_print_int
	ld	[a0+4],%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print_int:
	call	@w_print_int
	mov	d0,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print_char:
	ldg	(basic_only,d1)
	tst	d1
	bne	print_char_node_bo
	nop
	b,a	print_char_node_sc
	
print_char_node:
	tst	d1
	bne	print_char
	ld	[a0+4],d0
print_char_node_sc:
	call	@w_print_char
	mov	0x27,%o0
	
	call	@w_print_char
	mov	d0,%o0

	call	@w_print_char
	mov	0x27,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print_char_node_bo:
	call	@w_print_char
	mov	d0,%o0

	ld	[sp],%o7
	retl
	inc	4,sp
	
print_bool:
	ldsb	[a0+7],%o0

	tst	%o0
	beq	print_false
	nop
print_true:
	sethi	%hi true_c_string,%o0
	call	@w_print_string
	or	%o0,%lo true_c_string,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print_false:
	sethi	%hi false_c_string,%o0
	call	@w_print_string
	or	%o0,%lo false_c_string,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print_real:
	st	%f0,[sp-8]
	st	%f1,[sp-4]
	ld	[sp-8],%o0
	call	@w_print_real
	ld	[sp-4],%o1

	ld	[sp],%o7
	retl
	inc	4,sp

print_real_node:
	ld	[a0+4],%o0
	call	@w_print_real
	ld	[a0+8],%o1

	ld	[sp],%o7
	retl
	inc	4,sp

print_string_a2:
	ld	[a2],%o1
	call	@w_print_text
	add	a2,4,%o0

	ld	[sp],%o7
	retl
	inc	4,sp

print__chars__sc:
	ldg	(basic_only,%o1)
	tst	%o1
	bne	no_print_chars
	nop

print__string__:
	ld	[a0+4],%o1
	call	@w_print_text
	add	a0,8,%o0
no_print_chars:
	ld	[sp],%o7
	retl
	inc	4,sp

push_a_r_args:
	ld	[a0+8],a1
	dec	2,a1
	lduh	[a1],d3
	dec	256,d3
	lduh	[a1+2],d1
	inc	4,a1
	sub	d3,d1,d2
	sll	d0,2,d0
	mov	0,d4
	dec	d3
mul_array_size_lp:
	deccc	d3
	bcc	mul_array_size_lp
	add	d4,d0,d4

	inc	12,a0
	add	a0,d4,a0
	ld	[sp],%o7
	inc	4,sp

	sll	d1,2,%o0
	add	a0,%o0,a0
	ba	push_a_elements
	mov	a0,a3

push_a_elements_lp:
	dec	4,a3
	st	%o0,[a4]
	inc	4,a4
push_a_elements:
	deccc	d1
	bcc,a	push_a_elements_lp
	ld	[a3-4],%o0

	sll	d2,2,%o0
	ba	push_b_elements
	add	a0,%o0,a0

push_b_elements_lp:
	dec	4,a0
	st	%o0,[sp-4]
	dec	4,sp
push_b_elements:
	deccc	d2
	bcc,a	push_b_elements_lp
	ld	[a0-4],%o0

	retl
	mov	a1,d0

push_t_r_args:
	ld	[a0],a1
	inc	4,a0
	dec	2,a1
	lduh	[a1],d3
	lduh	[a1+2],d1
	dec	256,d3
	add	a1,4,d0
	sub	d3,d1,d2

	sll	d3,2,d4
	cmp	d3,2
	bleu	small_record
	add	a0,d4,a1
	
	ld	[a0+4],a1
	dec	4,a1
	add	a1,d4,a1
small_record:
	ld	[sp],%o7
	ba	push_r_b_elements
	inc	4,sp

push_r_b_elements_lp:
	bne	not_first_arg_b
	dec	4,sp
	
	ld	[a0],%o0
	b	push_r_b_elements
	st	%o0,[sp]
not_first_arg_b:
	ld	[a1-4],%o0
	dec	4,a1
	st	%o0,[sp]
push_r_b_elements:
	deccc	d2
	bcc,a	push_r_b_elements_lp
	deccc	d3

	b,a	push_r_a_elements

push_r_a_elements_lp:
	bne	not_first_arg_a
	inc	4,a4

	ld	[a0],%o0
	b	push_r_a_elements
	st	%o0,[a4-4]

not_first_arg_a:
	ld	[a1-4],%o0
	dec	4,a1
	st	%o0,[a4-4]
push_r_a_elements:
	deccc	d1
	bcc,a	push_r_a_elements_lp
	deccc	d3

	retl
	nop

BtoAC:
	tst	d0
	be	BtoAC_false
	ld	[sp],%o7
BtoAC_true:
	sethi	%hi true_string,a0
	or	a0,%lo true_string,a0
	retl
	inc	4,sp
	
BtoAC_false:
	sethi	%hi false_string,a0
	or	a0,%lo false_string,a0
	retl
	inc	4,sp
	
RtoAC:
	st	%f0,[sp-8]
	st	%f1,[sp-4]
	set	printf_real_string,%o1
	ld	[sp-8],%o2
	set	sprintf_buffer,%o0
	call	@sprintf
	ld	[sp-4],%o3

	b,a	D_to_S_x
	
ItoAC:
#ifdef MY_ITOS
	sethi	%hi sprintf_buffer,a0

	tst	d0
	bpos	no_minus
	or	a0,%lo sprintf_buffer,a0

	mov	45,%o0
	stb	%o0,[a0]
	inc	a0
	subcc	%g0,d0,d0
no_minus:
	be	zero_digit
	add	a0,12,a2

calculate_digits:
	cmp	d0,10
	blu	last_digit
	mov	d0,%o0

	call	.urem
	mov	10,%o1

	add	%o0,48,a1
	stb	a1,[a2]

	mov	d0,%o0
	call	.udiv
	mov	10,%o1
	
	mov	%o0,d0

	b	calculate_digits
	inc	a2

last_digit:
	tst	d0
	be	no_zero
	nop
zero_digit:
	add	d0,48,d0
	stb	d0,[a2]
	inc	a2
no_zero:
	add	a0,12,a1

reverse_digits:
	ldub	[a2-1],d1
	dec	a2
	stb	d1,[a0]
	cmp	a2,a1
	bne	reverse_digits
	inc	a0

	clrb	[a0]

	set	sprintf_buffer,d0
	ba	sprintf_buffer_to_string
	sub	a0,d0,d0

#else	
	mov	d0,%o2
	set	printf_int_string,%o1
	set	sprintf_buffer,%o0
	call	@sprintf
	nop
#endif

D_to_S_x:
	sethi	%hi sprintf_buffer,%o0
	call	@strlen
	or	%o0,%lo sprintf_buffer,%o0

	mov	%o0,d0

#ifdef MY_ITOS
sprintf_buffer_to_string:
	set	sprintf_buffer,a0
#endif
! d0 : length, a0 : string
build_string:
	add	d0,3,d1
	srl	d1,2,d1
	dec	2,d7
	subcc	d7,d1,d7
	bpos	D_to_S_no_gc
	nop
	
	mov	a0,d2
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
	mov	d2,a0

D_to_S_no_gc:
	mov	a6,d2
	set	__STRING__+2,%o0
	st	%o0,[a6]
	st	d0,[a6+4]
	ba	D_to_S_cp_str_2
	inc	8,a6
D_to_S_cp_str_1:
	ld	[a0],%o0
	inc	4,a0
	st	%o0,[a6]
	inc	4,a6
D_to_S_cp_str_2:
	deccc	d1
	bpos	D_to_S_cp_str_1
	nop
	
	ld	[sp],%o7
	mov	d2,a0
	retl
	inc	4,sp

eqD:	ld	[a0],d0
	ld	[a1],%o0
	cmp	d0,%o0
	bne	eqD_false
	nop
	set	INT+2,%o0
	cmp	d0,%o0
	be	eqD_INT
	nop
	set	CHAR+2,%o0
	cmp	d0,%o0
	be	eqD_CHAR
	nop
	set	BOOL+2,%o0
	cmp	d0,%o0
	be	eqD_BOOL
	nop
	set	REAL+2,%o0
	cmp	d0,%o0
	be	eqD_REAL
	nop

	ld	[sp],%o7
	mov	-1,d0
	retl
	inc	4,sp

eqD_CHAR:
eqD_INT:	ld	[a0+4],d1
	ld	[a1+4],%o0
	clr	d0
	cmp	d1,%o0
	beq,a	eqD_CHAR_true
	mov	-1,d0
eqD_CHAR_true:
	ld	[sp],%o7
	retl
	inc	4,sp

eqD_BOOL:	ldsb	[a0+7],d1
	ldsb	[a1+7],%o0
	clr	d0
	cmp	d1,%o0
	beq,a	eqD_BOOL_true
	mov	-1,d0
eqD_BOOL_true:
	ld	[sp],%o7
	retl
	inc	4,sp

eqD_REAL:	ld	[a0+4],%f0
	ld	[a0+8],%f1
	ld	[a1+4],%f2
	ld	[a1+8],%f3
	clr	d0
	fcmpd	%f0,%f2
	nop
	fbe,a	eqD_REAL_true
	mov	-1,d0
eqD_REAL_true:
	ld	[sp],%o7
	retl
	inc	4,sp
	
eqD_false:
	ld	[sp],%o7
	clr	d0
	retl
	inc	4,sp

!
!	the timer
!

init_timer:
#ifdef SOLARIS
	call	@times
	sub	sp,16,%o0
	
	ld	[sp-16],d0

	stg	(d0,last_time)
	stg	(%g0,execute_time)
	stg	(%g0,garbage_collect_time)
	stg	(%g0,IO_time)
#else
	sub	sp,88,%o1
	call	@getrusage
	clr	%o0
	
	set	last_time,a0
	ld	[sp-88],d0
	ld	[sp-84],d1

# ifdef ADD_SYSTEM_TIME
	ld	[sp-80],%o0
	add	d0,%o0,d0
	ld	[sp-76],%o0
	add	d1,%o0,d1
	set	1000000,%o0
	cmp	d1,%o0
	bl	no_micro_seconds_overflow1
	nop
	sub	d1,%o0,d1
	inc	1,d0
no_micro_seconds_overflow1:
# endif
	st	d0,[a0]
	st	d1,[a0+4]
	
	set	execute_time,a0
# ifdef ADD_SYSTEM_TIME
	st	d0,[a0]
	st	d1,[a0+4]
# else
	clr	[a0]
	clr	[a0+4]
# endif
	set	garbage_collect_time,a0
	clr	[a0]
	clr	[a0+4]
	set	IO_time,a0
	clr	[a0]
	clr	[a0+4]
#endif
	ld	[sp],%o7
	retl
	inc	4,sp

get_time_diff:
#ifdef SOLARIS
	call	@times
	sub	sp,16,%o0
	
	ld	[sp-16],d0
	sethi	%hi last_time,a0
	ld	[a0+%lo last_time],d2
	st	d0,[a0+%lo last_time]
	sub	d0,d2,d0
#else
	sub	sp,88,%o1
	call	@getrusage
	clr	%o0
	
	ld	[sp-88],d0
	ld	[sp-84],d1
# ifdef ADD_SYSTEM_TIME
	ld	[sp-80],%o0
	add	d0,%o0,d0
	ld	[sp-76],%o0
	add	d1,%o0,d1
	set	1000000,%o0
	cmp	d1,%o0
	bl	no_micro_seconds_overflow2
	nop
	sub	d1,%o0,d1
	inc	1,d0
no_micro_seconds_overflow2:
# endif
	set	last_time,a0
	ld	[a0],d2
	st	d0,[a0]
	sub	d0,d2,d0
	ld	[a0+4],d2
	st	d1,[a0+4]
	subcc	d1,d2,d1
	bpos	get_time_diff_1
	nop
	set	1000000,d2
	add	d1,d2,d1
	dec	1,d0
get_time_diff_1:
#endif
	ld	[sp],%o7
	retl
	inc	4,sp
	
add_execute_time:
	dec	4,sp
	call	get_time_diff
	st	%o7,[sp]
	
	set	execute_time,a0
add_time:
#ifdef SOLARIS
	ld	[a0],d2
	add	d0,d2,d0
	st	d0,[a0]
#else
	ld	[a0],d2
	add	d0,d2,d0
	st	d0,[a0]
	ld	[a0+4],d2
	add	d1,d2,d1
	set	1000000,d2
	cmp	d1,d2
	bcs	add_execute_time_1
	nop
	sub	d1,d2,d1
	inc	1,d0
	st	d0,[a0]
add_execute_time_1:
	st	d1,[a0+4]
#endif
	ld	[sp],%o7
	retl
	inc	4,sp

add_garbage_collect_time:
	dec	4,sp
	call	get_time_diff
	st	%o7,[sp]

	sethi	%hi garbage_collect_time,a0
	ba	add_time
	or	a0,%lo garbage_collect_time,a0

add_IO_time:
	dec	4,sp
	call	get_time_diff
	st	%o7,[sp]

	sethi	%hi IO_time,a0
	ba	add_time
	or	a0,%lo IO_time,a0

!
!	the garbage collector
!

collect_3:
	st	a0,[%i4]
	st	a1,[%i4+4]
	st	a2,[%i4+8]
	inc	12,%i4

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

	ld	[%i4-12],a0
	ld	[%i4-8],a1
	ld	[%i4-4],a2
	dec	12,%i4

	ld	[sp],%o7
	retl
	inc	4,sp

collect_2:
	st	a0,[%i4]
	st	a1,[%i4+4]
	inc	8,%i4

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

	ld	[%i4-8],a0
	ld	[%i4-4],a1
	dec	8,%i4

	ld	[sp],%o7
	retl
	inc	4,sp

collect_1:
	st	a0,[%i4]
	inc	4,%i4

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

	ld	[%i4-4],a0
	dec	4,%i4

	ld	[sp],%o7
	retl
	inc	4,sp

collect_0:
#ifdef MARK_GC
	ldg	(@flags,%o0)
	btst	64,%o0
	beq	no_mark_gc1
	seth	(bit_counter,%g1)

	ld	[%g1+%lo bit_counter],%o2
	tst	%o2
	beq	no_scan
	or	%g1,%lo bit_counter,%g1

	ld	[%g1+heap_end_after_gc-bit_counter],%o4
	ld	[%g1+bit_vector_p-bit_counter],a0
	sub	%o4,a6,%o4
	srl	%o4,2,%o4
	sub	%o4,d7,%o4

scan_bits:
	ld	[a0],%o0	!
	inc	4,a0
	tst	%o0
	beq	zero_bits
	deccc	%o2	
	clr	[a0-4]
	bne,a	scan_bits+4
	ld	[a0],%o0

	b,a	end_scan

zero_bits:
	beq	end_bits
	mov	a0,a1

skip_zero_bits_lp:
	ld	[a0],%o3	!
	inc	4,a0
	tst	%o3
	bne	end_zero_bits
	deccc	%o2
	bne,a	skip_zero_bits_lp+4
	ld	[a0],%o3

	ba	end_bits+4
	sub	a0,a1,%o3

end_zero_bits:
	clr	[a0-4]	!

	sub	a0,a1,%o3
	sll	%o3,3,%o3

	ld	[%g1+free_after_mark-bit_counter],%o1
	cmp	%o3,%o4
	add	%o1,%o3,%o1
	blu	scan_next
	st	%o1,[%g1+free_after_mark-bit_counter]

found_free_memory:
	st	%o2,[%g1+bit_counter-bit_counter]
	st	a0,[%g1+bit_vector_p-bit_counter]

	sub	%o3,%o4,d7

	ld	[%g1+heap_vector-bit_counter],%o1
	sub	a1,4,%o2
	sub	%o2,%o1,%o2
	ld	[%g1+heap_p3-bit_counter],%o1
	sll	%o2,5,%o2

	add	%o2,%o1,a6

	sll	%o3,2,%o3
	add	a6,%o3,%o2
	
	ld	[sp],%o7
	st	%o2,[%g1+heap_end_after_gc-bit_counter]
	retl
	inc	4,sp

scan_next:
	tst	%o2
	bne,a	scan_bits+4
	ld	[a0],%o0

	b,a	end_scan

end_bits:
	sub	a0,a1,%o3	!
	inc	4,%o3
	sll	%o3,3,%o3

	ld	[%g1+free_after_mark-bit_counter],%o1
	cmp	%o3,%o4
	add	%o1,%o3,%o1
	bgeu	found_free_memory
	st	%o1,[%g1+free_after_mark-bit_counter]

end_scan:
	st	%o2,[%g1+bit_counter-bit_counter]
no_scan:

no_mark_gc1:
#endif

	dec	28,sp
	st	d0,[sp]
	st	d1,[sp+4]
	st	d2,[sp+8]
	st	d3,[sp+12]
	st	d4,[sp+16]
	st	d5,[sp+20]
	st	d6,[sp+24]

	seth	(garbage_collect_flag,%g1)
	ldsb	[%g1+%lo garbage_collect_flag],%o0
	tst	%o0
	ble	collect
	nop

	dec	2,%o0
	stb	%o0,[%g1+%lo garbage_collect_flag]

	ldg	(heap_end_after_gc,d0)
	sub	d0,a6,d0
	srl	d0,2,d0
	sub	d0,%l7,d0
	ldg	(extra_heap_size,d1)
	cmp	d0,d1
	bgu	collect
	nop

	ldg	(extra_heap_size,d1)
	sub	d1,d0,%l7

	ldg	(extra_heap,a6)
	sll	d1,2,d1
	add	d1,a6,d1
	stg	(d1,heap_end_after_gc)

	ld	[sp],d0
	ld	[sp+4],d1
	ld	[sp+8],d2
	ld	[sp+12],d3
	ld	[sp+16],d4
	ld	[sp+20],d5
	ld	[sp+24],d6

	ld	[sp+28],%o7
	retl
	inc	32,sp

collect:
	dec	4,sp
	call	add_execute_time
	st	%o7,[sp]

	ldgr	(@flags,%o0,%o1)
	btst	4,%o0
	beq	no_print_stack_sizes
	nop	

	seth	(garbage_collect_string_1,%o0)
	call	@ew_print_string
	setl	(garbage_collect_string_1,%o0)


	ldg	(stack_p,a0)
	sub	%i4,a0,%o0
#ifdef STACK_OVERFLOW_EXCEPTION_HANDLER
	ldgr	(@begin_b_stack_p,d0,%o1)
#else
	ldgr	(@ab_stack_size,%o2,%o1)
	add	a0,%o2,d0
#endif
	call	@ew_print_int
	sub	d0,sp,d0

	seth	(garbage_collect_string_2,%o0)
	call	@ew_print_string
	setl	(garbage_collect_string_2,%o0)
	
	call	@ew_print_int
	mov	d0,%o0

	seth	(garbage_collect_string_3,%o0)
	call	@ew_print_string
	setl	(garbage_collect_string_3,%o0)

no_print_stack_sizes:
	cmp	%i4,sp
	bgu	stack_overflow
	nop

#ifdef MARK_GC
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	collect2_0
	nop
#endif

	ldgsb	(garbage_collect_flag,%o1)
	tst	%o1
	bne	collect2_0
	nop

#ifdef COPIED_VECTOR
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copied_vector3
	nop

	ldg	(heap_copied_vector,a2)
	ldg	(heap_copied_vector_size,d0)
	srl	d0,2,d0

	btst	1,d0
	be	zero_bits1_1
	srl	d0,1,d0

	clr	[%i2]
	inc	4,%i2
zero_bits1_1:
	btst	1,d0
	be	zero_bits1_5
	srl	d0,1,d0

	ba	zero_bits1_2
	dec	8,%i2

	clr	[%i2]
zero_bits1_4:
	clr	[%i2+4]
zero_bits1_2:
	clr	[%i2+8]
	clr	[%i2+12]
	inc	16,%i2
zero_bits1_5:
	deccc	d0
	bpos,a	zero_bits1_4
	clr	[%i2]

no_copied_vector3:
#endif

! calculate alloc_size
	ldg	(heap_end_after_gc,d0)
	sub	d0,a6,d0
	srl	d0,2,d0
	sub	d0,d7,d0
	stg	(d0,alloc_size)

#include "scopy.a"

	stg	(%o4,heap_end_after_gc)

	sub	%o4,%g6,%l7
	srl	%l7,2,%l7

	dec	4,sp
	call	add_garbage_collect_time
	st	%o7,[sp]

	ldg	(alloc_size,%o1)
	subcc	%l7,%o1,%l7
	bneg	switch_to_mark_scan
!	bneg	out_of_memory_4
	nop

	sll	%l7,2,d0
	add	d0,%l7,d0
	sll	d0,5,d0
	ldg	(@heap_size,d2)
	sll	d2,2,d1
	add	d1,d2,d1
	sll	d1,1,d1
	add	d1,d2,d1
	cmp	d0,d1
	bcc	no_mark_scan
!	ba	no_mark_scan
	nop

switch_to_mark_scan:
	ldg	(heap_size_33,d0)
	sll	d0,5,d0
	ldg	(heap_p,d1)

	ldg	(heap_p1,d2)
	ldg	(heap_p2,%o1)
	cmp	d2,%o1
	bcs	vector_at_begin
	nop
	
vector_at_end:
	stg	(d1,heap_p3)
	add	d1,d0,d1
	stg	(d1,heap_vector)
	
	ldg	(heap_p1,d0)
	stg	(d0,extra_heap)
	sub	d1,d0,d1
	srl	d1,2,d1
	stg	(d1,extra_heap_size)
	ba	switch_to_mark_scan_2
	nop

vector_at_begin:
	stg	(d1,heap_vector)
	ldgr	(@heap_size,%o0,%o1)
	add	d1,%o0,d1
	sub	d1,d0,d1
	stg	(d1,heap_p3)
	
	stg	(d1,extra_heap)
	ldg	(heap_p2,d2)
	sub	d2,d1,d2
	srl	d2,2,d2
	stg	(d2,extra_heap_size)

switch_to_mark_scan_2:
	ldg	(@heap_size,d0)
	srl	d0,3,d0
	sub	d0,%l7,d0
	sll	d0,2,d0
	
	mov	1,%o1
	stgb	(%o1,garbage_collect_flag)
	
	tst	d7
	bpos	end_garbage_collect
	nop
	
	mov	-1,%o1
	stgb	(%o1,garbage_collect_flag)
	
	ldg	(extra_heap_size,d1)
	ldg	(alloc_size,%l7)
	subcc	d1,%l7,%l7
	bneg	out_of_memory_4
	nop

	ldg	(extra_heap,%g6)
	sll	d1,2,d1
	add	d1,%g6,d1
	stg	(d1,heap_end_after_gc)
	ba	end_garbage_collect
	nop

no_mark_scan:
! exchange the semi_spaces

	ldg	(heap_p1,d0)
	ldg	(heap_p2,%o1)
	stg	(d0,heap_p2)
	stg	(%o1,heap_p1)

#ifdef COPIED_VECTOR
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copied_vector5
	nop

	ldg	(heap_size_129,d0)
	ba	copied_vector5
	sll	d0,6-2,d0
no_copied_vector5:
#endif

	ldg	(@heap_size,d0)
	srl	d0,3,d0

copied_vector5:

	sub	d0,d7,d0
	sll	d0,2,d0


end_garbage_collect:
#ifdef COUNT_GARBAGE_COLLECTIONS
	sethi	%hi n_garbage_collections,%o1
	ld	[%o1+%lo n_garbage_collections],%o2
	inc	1,%o2
#endif
	ldg	(@flags,%o0)
	btst	2,%o0
	beq	no_heap_use_message
#ifdef COUNT_GARBAGE_COLLECTIONS
	st	%o2,[%o1+%lo n_garbage_collections]
#else
	nop
#endif

	seth	(heap_use_after_gc_string_1,%o0)
	call	@ew_print_string
	setl	(heap_use_after_gc_string_1,%o0)

	call	@ew_print_int
	mov	d0,%o0

	seth	(heap_use_after_gc_string_2,%o0)
	call	@ew_print_string
	setl	(heap_use_after_gc_string_2,%o0)

no_heap_use_message:
#ifdef FINALIZERS
	call	call_finalizers
	nop
#endif

	ld	[sp],d0
	ld	[sp+4],d1
	ld	[sp+8],d2
	ld	[sp+12],d3
	ld	[sp+16],d4
	ld	[sp+20],%l5
	ld	[sp+24],%l6

	ld	[sp+28],%o7
	retl
	inc	32,sp

#ifdef FINALIZERS
call_finalizers:
	ldg	(free_finalizer_list,d0)

call_finalizers_lp:
	set	__Nil-8,%o1
	cmp	d0,%o1
	beq	end_call_finalizers
	nop
	
	ld	[d0+8],d1
	ld	[d0+4],d0

	ld	[d1],%o1
	ld	[d1+4],%o0
	
	save	%o6,-128,%o6

	call	%i1
	nop

	b	call_finalizers_lp
	restore

end_call_finalizers:
	stg	(%o1,free_finalizer_list)
	retl
	nop
#endif

out_of_memory_4:
	dec	4,sp
	call	add_garbage_collect_time
	st	%o7,[sp]
	
	seth	(out_of_memory_string_4,%o0)
	b	print_error
	setl	(out_of_memory_string_4,%o0)


reorder:
	mov	d0,d2
	mov	d1,d3
	sll	d0,2,d4
	sll	d1,2,d5
	add	a0,d5,a0
	ba	st_reorder_lp
	sub	a1,d4,a1

reorder_lp:
	ld	[a1-4],%o0
	st	d6,[a1-4]
	st	%o0,[a0]
	
	deccc	1,d2
	bne	next_b_in_element
	inc	4,a0

	mov	d0,d2
	add	a0,d5,a0
next_b_in_element:
	deccc	1,d3
	bne	next_a_in_element
	dec	4,a1

	mov	d1,d3
	sub	a1,d4,a1
next_a_in_element:
st_reorder_lp:
	cmp	a1,a0
	bgu,a	reorder_lp
	ld	[a0],d6

	retl
	nop
!
!	the sliding compacting garbage collector
!

collect2_0:
! zero all mark bits

	ldg	(heap_p3,d6)
	ldg	(heap_vector,%o4)
	ldg	(heap_end_after_gc,d5)
	sub	d5,a6,d5
	srl	d5,2,d5
	sub	d5,d7,d5
	stg	(d5,alloc_size)

#ifdef MARK_GC
	ldg	(@flags,%o0)
	btst	64,%o0
	be	no_mark_gc3
	sethi	%hi zero_bits_before_mark,%o0

	ld	[%o0+%lo zero_bits_before_mark],%o1
	tst	%o1
	beq	no_zero_bits
	nop

	clr	[%o0+%lo zero_bits_before_mark]
no_mark_gc3:
#endif

	mov	%o4,%i2
	ldg	(heap_size_33,d0)
	inc	3,d0
	srl	d0,2,d0

	btst	1,d0
	be	zero_bits_1
	srl	d0,1,d0
	
	clr	[%i2]
	inc	4,%i2
zero_bits_1:
	btst	1,d0
	be	zero_bits_5
	srl	d0,1,d0

	ba	zero_bits_2
	dec	8,%i2

	clr	[%i2]
zero_bits_4:
	clr	[%i2+4]
zero_bits_2:
	clr	[%i2+8]
	clr	[%i2+12]
	inc	16,%i2
zero_bits_5:
	deccc	d0
	bpos,a	zero_bits_4
	clr	[%i2]

#ifdef MARK_GC
no_zero_bits:
	ldg	(@flags,%o0)
	btst	64,%o0
	be	no_mark_gc4
	nop

	ldg	(last_heap_free,d0)
	ldg	(free_after_mark,d1)
	sll	d1,2,d1

	sll	d1,3,d2
	add	d2,d1,d1
	srl	d1,2,d1

	cmp	d0,d1
	bgu	compact_gc
	nop

#include	"smark.a"

compact_gc:
	mov	1,d0
	stg	(d0,zero_bits_before_mark)
	sethi	%hi last_heap_free,%o0
	st	%g0,[%o0+%lo last_heap_free]
	mov	1000,%o1
	stg	(%o1,free_after_mark)

no_mark_gc4:
#endif

#include "scompact.a"

	ldg	(heap_size_33,d7)
	sll	d7,5,d7
	ldg	(heap_p3,%o1)
	add	d7,%o1,d7
	stg	(d7,heap_end_after_gc)
	sub	d7,%g6,d7
	srl	d7,2,d7

	ldg	(alloc_size,%o1)
	subcc	d7,%o1,d7
	bneg	out_of_memory_4
	nop

	mov	%l7,d0
	sll	d0,2,d0
	add	d0,%l7,d0
	sll	d0,3,d0
	ldg	(@heap_size,%o1)
	cmp	d0,%o1
	bcs	out_of_memory_4
	nop

	sll	d0,2,d0
	ldg	(@heap_size,d1)
	sll	d1,5,d1
	ldg	(@heap_size,%o1)
	sub	d1,%o1,d1

	ldg	(@flags,%o1)
	btst	32,%o1
	bne	no_copy_garbage_collection

#ifdef MARK_GC
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copy_garbage_collection
	nop
#endif

	cmp	d0,d1
	ble	no_copy_garbage_collection
!	ba	no_copy_garbage_collection
	nop

	ldg	(heap_p,d0)
	stg	(d0,heap_p1)
#ifdef COPIED_VECTOR
	ldg	(@flags,%o0)
	btst	64,%o0
	bne	no_copied_vector6
	nop

	ldg	(heap_size_129,d1)
	sll	d1,6,d1
	add	d0,d1,d0
	stg	(d0,heap_copied_vector)
	stg	(d0,heap_end_after_gc)
	ldg	(heap_copied_vector_size,d1)
	add	d1,d0,d1
	stg	(d1,heap_p2)
	b,a	copied_vector6

no_copied_vector6:
#endif
	ldg	(@heap_size,d1)
	srl	d1,1,d1
	add	d0,d1,d0
	stg	(d0,heap_p2)
	stg	(d0,heap_end_after_gc)

copied_vector6:

	sub	d0,%g6,d0
	srl	d0,2,d0
	mov	d0,%l7
	ldg	(alloc_size,%o1)
	sub	%l7,%o1,%l7
	
	ldg	(heap_p3,d0)
	ldg	(heap_vector,%o1)
	cmp	d0,%o1
	ble	vector_at_end_2
	nop

	ldg	(heap_vector,d1)
	stg	(d1,extra_heap)
	sub	d0,d1,d0
	srl	d0,2,d0
	stg	(d0,extra_heap_size)

	mov	2,%o1
	stgb	(%o1,garbage_collect_flag)
	
	ba	no_copy_garbage_collection
	nop

vector_at_end_2:
	stgb	(%g0,garbage_collect_flag)

no_copy_garbage_collection:
	dec	4,sp
	call	add_garbage_collect_time
	st	%o7,[sp]
	
	mov	%g6,d0
	sub	d0,%l6,d0
	ldg	(alloc_size,d1)
	sll	d1,2,d1
	
	ba	end_garbage_collect
	add	d0,d1,d0

stack_overflow:
	dec	4,sp
	call	add_execute_time
	st	%o7,[sp]

	set	stack_overflow_string,%o0
	ba	print_error
	nop

@IO_error:
	save	%o6,-128,%o6

	set	IO_error_string,%o0
	call	@ew_print_string
	nop
	
	call	@ew_print_string
	mov	a0,%o0

	set	new_line_string,%o0
	call	@ew_print_string
	nop

	ba	halt
	restore

print_error:
	call	@ew_print_string
	nop	

halt:
	mov	1,d0
	stg	(d0,@execution_aborted)

	ldg	(halt_sp,sp)
	set	jump_buffer,%o0
	call	@longjmp
	mov	1,%o1

e__system__eaind:
__eaind:
eval_fill:
	st	a0,[%i4]
	inc	4,%i4
	mov	a1,a0
	ld	[a1],a1
	dec	4,sp
	call	a1
	st	%o7,[sp]
	mov	a0,a1
	ld	[%i4-4],a0
	dec	4,%i4
	
	ld	[a1],%g1
	st	%g1,[a0]
	ld	[a1+4],%g1
	st	%g1,[a0+4]
	ld	[a1+8],%g1
	st	%g1,[a0+8]

	ld	[sp],%o7
	retl
	inc	4,sp

	b,a	e__system__eaind
	nop
	nop
	.word	e__system__dind	
	.word	-2
e__system__nind:
__indirection:
	ld	[a0+4],a1
	ld	[a1],d0
	btst	2,d0
#ifdef MARK_GC
	be,a	eval_fill2
	st	a5,[a0]
#else
	be	__cycle__in__spine
	nop
#endif
	st	d0,[a0]
	ld	[a1+4],%g1
	st	%g1,[a0+4]
	ld	[a1+8],%g1
	st	%g1,[a0+8]

	ld	[sp],%o7
	retl
	inc	4,sp

#ifdef MARK_GC
eval_fill2:
	ldg	(@flags,%o0)
	btst	64,%o0
	be	__cycle__in__spine
	st	a0,[a4]

	inc	4,a4
	mov	a1,a0
	
	dec	4,sp
	call	d0
	st	%o7,[sp]

	ld	[a4-4],a1
	ld	[a0],%o0
	dec	4,a4
	st	%o0,[a1]
	ld	[a0+4],%o0
	st	%o0,[a1+4]
	ld	[a0+8],%o0
	ld	[sp],%o7
	st	%o0,[a1+8]
	mov	a1,a0
	retl
	inc	4,sp
#endif

eval_upd_0:
	set	__indirection,%i3
	st	%i3,[a1]
	jmp	%i2
	st	a0,[a1+4]
eval_upd_1:
	set	__indirection,%i3
	st	%i3,[a1]
	ld	[a1+4],d0
	st	a0,[a1+4]
	jmp	%i2
	mov	d0,a1
eval_upd_2:
	mov	%i2,%i3
	set	__indirection,%i2
	st	%i2,[a1]
	ld	[a1+4],%i2
	st	a0,[a1+4]
	jmp	%i3
	ld	[a1+8],a1
eval_upd_3:
	mov	%i2,%i3
	set	__indirection,%i2
	st	%i2,[a1]
	ld	[a1+4],%i2
	st	a0,[%i4]
	st	a0,[a1+4]
	inc	4,%i4
	ld	[a1+12],a0
	jmp	%i3
	ld	[a1+8],a1
eval_upd_4:
	mov	%i2,%i3
	set	__indirection,%i2
	st	%i2,[a1]
	ld	[a1+4],%i2
	st	a0,[%i4]
	st	a0,[a1+4]
	ld	[a1+16],%g1
	st	%g1,[%i4+4]
	inc	8,%i4
	ld	[a1+12],a0
	jmp	%i3
	ld	[a1+8],a1
eval_upd_5:
	mov	%i2,%i3
	set	__indirection,%i2
	st	%i2,[a1]
	ld	[a1+4],%i2
	st	a0,[%i4]
	st	a0,[a1+4]
	ld	[a1+20],%g1
	st	%g1,[%i4+4]
	ld	[a1+16],%g1
	st	%g1,[%i4+8]
	inc	12,%i4
	ld	[a1+12],a0
	jmp	%i3
	ld	[a1+8],a1
eval_upd_6:
	mov	%i2,%i3
	set	__indirection,%i2
	st	%i2,[a1]
	ld	[a1+4],%i2
	st	a0,[%i4]
	st	a0,[a1+4]
	ld	[a1+24],%g1
	st	%g1,[%i4+4]
	ld	[a1+20],%g1
	st	%g1,[%i4+8]
	ld	[a1+16],%g1
	st	%g1,[%i4+12]
	inc	16,%i4
	ld	[a1+12],a0
	jmp	%i3
	ld	[a1+8],a1
eval_upd_7:
	mov	0,d0
	mov	20,d1
eval_upd_n:
	mov	a2,a3
	set	__indirection,a2
	st	a2,[a1]
	ld	[a1+4],a2
	st	a0,[a4]
	st	a0,[a1+4]
	add	a1,d1,a1
	ld	[a1+8],%g1
	st	%g1,[a4+4]
	ld	[a1+4],%g1
	st	%g1,[a4+8]
	ld	[a1],%g1
	st	%g1,[a4+12]
	inc	16,a4
eval_upd_n_lp:
	ld	[a1-4],%g1
	dec	4,a1
	st	%g1,[a4]
	deccc	d0
	bcc	eval_upd_n_lp
	inc	4,a4
	ld	[a1-4],a0
	jmp	a3
	ld	[a1-8],a1
eval_upd_8:
	mov	1,d0
	ba	eval_upd_n
	mov	24,d1
eval_upd_9:
	mov	2,d0
	ba	eval_upd_n
	mov	28,d1
eval_upd_10:
	mov	3,d0
	ba	eval_upd_n
	mov	32,d1
eval_upd_11:
	mov	4,d0
	ba	eval_upd_n
	mov	36,d1
eval_upd_12:
	mov	5,d0
	ba	eval_upd_n
	mov	40,d1
eval_upd_13:
	mov	6,d0
	ba	eval_upd_n
	mov	44,d1
eval_upd_14:
	mov	7,d0
	ba	eval_upd_n
	mov	48,d1
eval_upd_15:
	mov	8,d0
	ba	eval_upd_n
	mov	52,d1
eval_upd_16:
	mov	9,d0
	ba	eval_upd_n
	mov	56,d1
eval_upd_17:
	mov	10,d0
	ba	eval_upd_n
	mov	60,d1
eval_upd_18:
	mov	11,d0
	ba	eval_upd_n
	mov	64,d1
eval_upd_19:
	mov	12,d0
	ba	eval_upd_n
	mov	68,d1
eval_upd_20:
	mov	13,d0
	ba	eval_upd_n
	mov	72,d1
eval_upd_21:
	mov	14,d0
	ba	eval_upd_n
	mov	76,d1
eval_upd_22:
	mov	15,d0
	ba	eval_upd_n
	mov	80,d1
eval_upd_23:
	mov	16,d0
	ba	eval_upd_n
	mov	84,d1
eval_upd_24:
	mov	17,d0
	ba	eval_upd_n
	mov	88,d1
eval_upd_25:
	mov	18,d0
	ba	eval_upd_n
	mov	92,d1
eval_upd_26:
	mov	19,d0
	ba	eval_upd_n
	mov	96,d1
eval_upd_27:
	mov	20,d0
	ba	eval_upd_n
	mov	100,d1
eval_upd_28:
	mov	21,d0
	ba	eval_upd_n
	mov	104,d1
eval_upd_29:
	mov	22,d0
	ba	eval_upd_n
	mov	108,d1
eval_upd_30:
	mov	23,d0
	ba	eval_upd_n
	mov	112,d1
eval_upd_31:
	mov	24,d0
	ba	eval_upd_n
	mov	116,d1
eval_upd_32:
	mov	25,d0
	ba	eval_upd_n
	mov	120,d1

!
!	STRINGS
!

catAC:
	ld	[a0+4],d0
	inc	8,a0
	ld	[a1+4],d1
	inc	8,a1

	add	d0,d1,d2
	add	d2,3+8,d5
	srl	d5,2,d5
	subcc	d7,d5,d7
! reserve one word extra, because 
! word after the string may changed
	ble	gc_3
	add	d2,3,d6
gc_r_3:

	set	__STRING__+2,%o0
	st	%o0,[a6]
	mov	a6,d5
	inc	8,a6
	st	d2,[a6-4]

! copy string 1

	add	d1,3,d2
	srl	d2,2,d2
	ba	cat_string_4
	mov	a6,a2

cat_string_3:
	inc	4,a1
	st	%o0,[a2]
	inc	4,a2
cat_string_4:
	deccc	d2
	bge,a	cat_string_3
	ld	[a1],%o0

! copy string 2

	andn	d1,3,%o0
	add	a6,%o0,a2

	inc	3,d0
	srl	d0,2,d0

	andcc	d1,3,%o0
	be	cat_string_al0_1
	mov	-1,%o1

cat_string_al123:
	ld	[a2],d3
	sll	%o0,3,%o2
	mov	32,%o3
	sub	%o3,%o2,%o3
	sll	%o1,%o3,%o1
	ba	cat_string_al123_1
	and	d3,%o1,d3

cat_string_al123_0:
	inc	4,a0
	srl	%o0,%o2,d4
	or	d3,d4,d3
	st	d3,[a2]
	inc	4,a2
	sll	%o0,%o3,d3	
cat_string_al123_1:
	deccc	d0
	bge,a	cat_string_al123_0
	ld	[a0],%o0

	st	d3,[a2]

	bclr	3,d6
	ld	[sp],%o7
	mov	d5,a0
	add	a6,d6,a6
	retl
	inc	4,sp

cat_string_al0_0:
	inc	4,a0
	st	%o0,[a2]
	inc	4,a2
cat_string_al0_1:
	deccc	d0
	bge,a	cat_string_al0_0
	ld	[a0],%o0

	bclr	3,d6
	ld	[sp],%o7
	mov	d5,a0
	add	a6,d6,a6
	retl
	inc	4,sp

gc_3:
	dec	8,a0
	dec	8,a1

	dec	4,sp
	call	collect_2
	st	%o7,[sp]

	inc	8,a0
	ba	gc_r_3
	inc	8,a1

empty_string:
	ld	[sp],%o7
	set	zero_length_string,a0
	retl
	inc	4,sp

sliceAC:
	ld	[a0+4],d2
	add	a0,8,a2

	tst	d1
	bl,a	slice_string_1
	clr	d1
slice_string_1:
	cmp	d1,d2
	bge	empty_string
	cmp	d0,d1
	bl	empty_string
	inc	d0
	cmp	d0,d2
	bg,a	slice_string_2
	mov	d2,d0
slice_string_2:
	sub	d0,d1,d0

	add	d0,3,d2
	srl	d2,2,d2
	
	dec	2,d7
	subcc	d7,d2,d7
	bneg	gc_4
	nop
r_gc_4:
	set	__STRING__+2,%o0
	st	%o0,[a6]
	mov	a6,d5
	inc	8,a6
	st	d0,[a6-4]

	andcc	d1,3,%o0
	be	slice_string_al0_1
	add	a2,d1,a2

slice_string_al123:
	sub	a2,%o0,a2
	sll	%o0,3,%o2
	mov	32,%o3
	sub	%o3,%o2,%o3
	ld	[a2],d3
	ba	slice_string_al123_1
	sll	d3,%o2,d4

slice_string_al123_0:
	inc	4,a2
	srl	%o0,%o3,%o1
	or	d4,%o1,d4
	st	d4,[a6]
	inc	4,a6
	sll	%o0,%o2,d4
slice_string_al123_1:
	deccc	d2
	bge,a	slice_string_al123_0
	ld	[a2+4],%o0

	ld	[sp],%o7
	mov	d5,a0
	retl
	inc	4,sp
	
slice_string_al0_0:
	inc	4,a2
	st	%o0,[a6]
	inc	4,a6
slice_string_al0_1:
	deccc	d2
	bge,a	slice_string_al0_0
	ld	[a2],%o0

	ld	[sp],%o7
	mov	d5,a0
	retl
	inc	4,sp

gc_4:	dec	4,sp
	call	collect_1
	st	%o7,[sp]
	ba	r_gc_4
	add	a0,8,a2

updateAC:
	ld	[a0+4],d2
	cmp	d1,d2
	bcc	update_string_error
	add	a0,8,a2

	add	d2,3,d3
	srl	d3,2,d3
	
	dec	2,d7
	subcc	d7,d3,d7
	bneg	gc_5
	inc	8,d1
r_gc_5:
	set	__STRING__+2,%o0
	st	%o0,[%g6]
	mov	a6,a0
	inc	8,%g6
	ba	update_string_5
	st	d2,[a6-4]

update_string_4:
	inc	4,a2
	st	%o0,[a6]
	inc	4,a6
update_string_5:
	deccc	d3
	bge,a	update_string_4
	ld	[a2],%o0

	ld	[sp],%o7
	stb	d0,[a0+d1]
	retl
	inc	4,sp

gc_5:	dec	4,sp
	call	collect_1
	st	%o7,[sp]
	ba	r_gc_5
	add	a0,8,a2

update_string_error:
	set	high_index_string,%o0
	tst	d0
	bpos	print_error
	nop
	set	low_index_string,%o0
update_string_error_2:
	ba	print_error
	nop


eqAC:
	ld	[a0+4],d0
	ld	[a1+4],%o0
	inc	8,a0
	cmp	d0,%o0
	bne	equal_string_ne
	inc	8,a1

	and	d0,3,d1
	srl	d0,2,d0
	deccc	d0
	bcs	equal_string_b
	nop
	ld	[a1],%o0
equal_string_1:
	inc	4,a1
	ld	[a0],%o1
	inc	4,a0
	cmp	%o1,%o0
	bne	equal_string_ne
	deccc	d0
	bge,a	equal_string_1
	ld	[a1],%o0

equal_string_b:
	deccc	d1
	bcs	equal_string_eq
	nop
	ldub	[a1],%o0
equal_string_2:
	inc	a1
	ldub	[a0],%o1
	inc	a0
	cmp	%o1,%o0
	bne	equal_string_ne
	deccc	d1
	bge,a	equal_string_2
	ldub	[a1],%o0
equal_string_eq:
	ld	[sp],%o7
	mov	-1,d0
	retl
	inc	4,sp
equal_string_ne:
	ld	[sp],%o7
	clr	d0
	retl
	inc	4,sp	

cmpAC:
	ld	[a0+4],d1
	inc	8,a0
	ld	[a1+4],d2
	inc	8,a1

	cmp	d2,d1
	bcs,a	cmp_string_less
	mov	-1,d0
	bgu,a	cmp_string_chars
	mov	1,d0
	ba	cmp_string_chars
	clr	d0
cmp_string_less:
	mov	d2,d1
cmp_string_chars:	
	and	d1,3,d2
	srl	d1,2,d1
	deccc	d1
	bcs	cmp_string_b
	nop
	ld	[a0],%o0
cmp_string_1:
	inc	4,a0
	ld	[a1],%o1
	inc	4,a1
	cmp	%o1,%o0
	bne	cmp_string_ne
	nop
	deccc	d1
	bge,a	cmp_string_1
	ld	[a0],%o0

cmp_string_b:
	deccc	d2
	bcs	cmp_string_eq
	nop
	ldub	[a0],%o0
cmp_string_2:
	inc	a0
	ldub	[a1],%o1
	inc	a1
	cmp	%o1,%o0
	bne	cmp_string_ne
	nop
	deccc	d2
	bge,a	cmp_string_2
	ldub	[a0],%o0
cmp_string_eq:
	ld	[sp],%o7
	retl
	inc	4,sp
cmp_string_ne:
	bgu	cmp_string_r1
	nop
	ld	[sp],%o7
	mov	-1,d0
	retl
	inc	4,sp
cmp_string_r1:
	ld	[sp],%o7
	mov	1,d0
	retl
	inc	4,sp

string_to_string_node:
	ld	[a0],d0
	inc	4,a0

	add	d0,3,d1
	srl	d1,2,d1
	
	dec	2,d7
	subcc	d7,d1,d7
	bneg	string_to_string_node_gc
	nop

string_to_string_node_r:
	set	__STRING__+2,%o0
	st	%o0,[%g6]
	mov	%g6,d2
	st	d0,[%g6+4]
	b	string_to_string_node_4
	inc	8,%g6
	
string_to_string_node_2:
	st	%o0,[%g6]
	inc	4,a0
	inc	4,%g6
string_to_string_node_4:
	deccc	d1
	bge,a	string_to_string_node_2
	ld	[a0],%o0

	mov	d2,a0
	ld	[sp],%o7
	retl
	inc	4,sp

string_to_string_node_gc:
	st	a0,[sp-4]
	dec	8,sp
	call	collect_0
	st	%o7,[sp]

	ld	[sp],a0
	b	string_to_string_node_r
	inc	4,sp

	.word	3
_c3:	b,a	__cycle__in__spine
	.word	4
_c4:	b,a	__cycle__in__spine
	.word	5
_c5:	b,a	__cycle__in__spine
	.word	6
_c6:	b,a	__cycle__in__spine
	.word	7
_c7:	b,a	__cycle__in__spine
	.word	8
_c8:	b,a	__cycle__in__spine
	.word	9
_c9:	b,a	__cycle__in__spine
	.word	10
_c10:	b,a	__cycle__in__spine
	.word	11
_c11:	b,a	__cycle__in__spine
	.word	12
_c12:	b,a	__cycle__in__spine
	.word	13
_c13:	b,a	__cycle__in__spine
	.word	14
_c14:	b,a	__cycle__in__spine
	.word	15
_c15:	b,a	__cycle__in__spine
	.word	16
_c16:	b,a	__cycle__in__spine
	.word	17
_c17:	b,a	__cycle__in__spine
	.word	18
_c18:	b,a	__cycle__in__spine
	.word	19
_c19:	b,a	__cycle__in__spine
	.word	20
_c20:	b,a	__cycle__in__spine
	.word	21
_c21:	b,a	__cycle__in__spine
	.word	22
_c22:	b,a	__cycle__in__spine
	.word	23
_c23:	b,a	__cycle__in__spine
	.word	24
_c24:	b,a	__cycle__in__spine
	.word	25
_c25:	b,a	__cycle__in__spine
	.word	26
_c26:	b,a	__cycle__in__spine
	.word	27
_c27:	b,a	__cycle__in__spine
	.word	28
_c28:	b,a	__cycle__in__spine
	.word	29
_c29:	b,a	__cycle__in__spine
	.word	30
_c30:	b,a	__cycle__in__spine
	.word	31
_c31:	b,a	__cycle__in__spine
	.word	32
_c32:	b,a	__cycle__in__spine

!
!	ARRAYS
!

create_arrayB:
	mov	d1,d2
	inc	3,d1
	srl	d1,2,d1
	dec	3,d7
	subcc	d7,d1,d7
	bpos	no_collect_4575
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_4575:
	sll	d0,8,d3
	or	d0,d3,d0
	sll	d0,16,d3
	or	d0,d3,d0
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d2,[a6+4]
	set	BOOL+2,%o0
	st	%o0,[a6+8]
	ba	create_arrayBCI
	inc	12,a6

create_arrayC:
	mov	d1,d2
	inc	3,d1
	srl	d1,2,d1
	dec	2,d7
	subcc	d7,d1,d7
	bpos	no_collect_4578
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_4578:
	sll	d0,8,d3
	or	d0,d3,d0
	sll	d0,16,d3
	or	d0,d3,d0
	mov	a6,a0
	set	__STRING__+2,%o0
	st	%o0,[a6]
	st	d2,[a6+4]
	ba	create_arrayBCI
	inc	8,a6

create_arrayI:
	dec	3,d7
	subcc	d7,d1,d7
	bpos	no_collect_4577
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_4577:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d1,[a6+4]
	set	INT+2,%o0
	st	%o0,[a6+8]
	inc	12,a6

create_arrayBCI:
	btst	1,d1
	be	st_filli_array
	srl	d1,1,d1

	st	d0,[a6]
	ba	st_filli_array
	inc	4,a6

filli_array:
	st	d0,[a6+4]
	inc	8,a6
st_filli_array:
	deccc	1,d1
	bcc,a	filli_array
	st	d0,[a6]

	ld	[sp],%o7
	retl
	inc	4,sp

create_arrayR:
	st	%f0,[sp-8]
	st	%f1,[sp-4]
	ld	[sp-8],d1
	ld	[sp-4],d2

 	dec	3,d7
	sub	d7,d0,d7
	subcc	d7,d0,d7
	bpos	no_collect_4579
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4579:
	mov	a6,a0
	set	__ARRAY__+2,%o0
	st	%o0,[a6]
	st	d0,[a6+4]
	set	REAL+2,%o0
	st	%o0,[a6+8]
	ba	st_fillr_array
	inc	12,a6
fillr_array:
	st	d2,[a6+4]
	inc	8,a6
st_fillr_array:
	deccc	1,d0
	bcc,a	fillr_array
	st	d1,[a6]
	ld	[sp],%o7
	retl	
	inc	4,sp

create_array:
	dec	3,d7
	subcc	d7,d0,d7
	bpos	no_collect_4576
	nop
	dec	4,sp
	call	collect_1
	st	%o7,[sp]
no_collect_4576:
	mov	a0,d1
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]

	st	%g0,[a6+8]
	inc	12,a6
	ld	[sp],a1
	ba	fillr1_array
	inc	4,sp

create_R_array:
	deccc	2,d2
	bcs	create_R_array_1
	nop
	be	create_R_array_2
	nop
	deccc	2,d2
	bcs	create_R_array_3
	nop
	be	create_R_array_4
	nop
	b,a	create_R_array_5

create_R_array_1:
	dec	3,d7
	subcc	d7,d0,d7
	bpos	no_collect_4581
	nop
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4581:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]

	inc	12,a6
	ld	[sp],a1

	tst	d3
	be	r_array_1_b
	inc	4,sp

	ba	fillr1_array
	ld	[a4-4],d1

r_array_1_b:
	ld	[sp],d1

fillr1_array:
	btst	1,d0
	be	st_fillr1_array_1
	srl	d0,1,d0
	st	d1,[a6]
	ba	st_fillr1_array_1
	inc	4,a6

fillr1_array_lp:
	st	d1,[a6+4]
	inc	8,a6
st_fillr1_array_1:
	deccc	1,d0
	bcc,a	fillr1_array_lp
	st	d1,[a6]

	jmp	a1+8
	nop

create_R_array_2:
	dec	3,d7
	sub	d7,d0,d7
	subcc	d7,d0,d7
	bpos	no_collect_4582
	nop
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4582:
	set	__ARRAY__+2,%o0

	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]
	inc	12,a6

	ld	[sp],a1

	deccc	1,d3
	bcs	r_array_2_bb
	inc	4,sp

	be	r_array_2_ab
	nop
r_array_2_aa:
	ld	[a4-4],d1
	ba	st_fillr2_array
	ld	[a4-8],d2
r_array_2_ab:
	ld	[a4-4],d1
	ba	st_fillr2_array
	ld	[sp],d2
r_array_2_bb:
	ld	[sp],d1
	ba	st_fillr2_array
	ld	[sp+4],d2

fillr2_array_1:
	st	d2,[a6+4]
	inc	8,a6
st_fillr2_array:
	deccc	1,d0
	bcc,a	fillr2_array_1
	st	d1,[a6]

	jmp	a1+8
	nop

create_R_array_3:
	dec	3,d7
	sub	d7,d0,d7
	sub	d7,d0,d7
	subcc	d7,d0,d7
	bpos	no_collect_4583
	nop
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4583:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]
	inc	12,a6

	ld	[sp],a1
	add	sp,4,a2

	tst	d3
	be	r_array_3
	inc	4,sp

	sll	d3,2,d4
	sub	a4,d4,a3
	dec	1,d3
copy_a_to_b_lp3:
	ld	[a3],%o0
	inc	4,a3
	st	%o0,[sp-4]
	deccc	1,d3
	bcc	copy_a_to_b_lp3
	dec	4,sp
r_array_3:
	ld	[sp],d1
	ld	[sp+4],d2
	ld	[sp+8],d3
	ba	st_fillr3_array
	mov	a2,sp
fillr3_array_1:
	st	d2,[a6+4]
	st	d3,[a6+8]
	inc	12,a6
st_fillr3_array:
	deccc	1,d0
	bcc,a	fillr3_array_1
	st	d1,[a6]

	jmp	a1+8
	nop

create_R_array_4:
	dec	3,d7
	sll	d0,2,d2
	subcc	d7,d2,d7
	bpos	no_collect_4584
	nop
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4584:
	set	__ARRAY__+2,%o1
	mov	a6,a0
	st	%o1,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]
	inc	12,a6

	ld	[sp],a1
	add	sp,4,a2

	tst	d3
	be	r_array_4
	inc	4,sp

	sll	d3,2,d4
	sub	a4,d4,a3
	dec	1,d3
copy_a_to_b_lp4:
	ld	[a3],%o1
	inc	4,a3
	st	%o1,[sp-4]
	deccc	1,d3
	bcc	copy_a_to_b_lp4
	dec	4,sp

r_array_4:
	ld	[sp],d1
	ld	[sp+4],d2
	ld	[sp+8],d3
	ld	[sp+12],d4
	ba	st_fillr4_array
	mov	a2,sp

fillr4_array:
	st	d2,[a6+4]
	st	d3,[a6+8]
	st	d4,[a6+12]
	inc	16,a6
st_fillr4_array:
	deccc	1,d0
	bcc,a	fillr4_array
	st	d1,[a6]

	jmp	a1+8
	nop

create_R_array_5:
	dec	3,d7
	sll	d0,2,d4
	sub	d7,d4,d7
	dec	1,d2
	mov	d2,d5
sub_size_lp:
	deccc	1,d5
	bcc	sub_size_lp
	subcc	d7,d0,d7

	bpos	no_collect_4585
	nop
	dec	4,sp
	call	collect_0
	st	%o7,[sp]
no_collect_4585:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]
	inc	12,a6

	ld	[sp],a1
	add	sp,4,a2
	mov	d2,d5

	tst	d3
	be	r_array_5
	inc	4,sp

	sll	d3,2,d4
	sub	a4,d4,a3
	dec	1,d3
copy_a_to_b_lp5:
	ld	[a3],%o0
	inc	4,a3
	st	%o0,[sp-4]
	deccc	1,d3
	bcc	copy_a_to_b_lp5
	dec	4,sp
r_array_5:
	ld	[sp],d1
	ld	[sp+4],d2
	ld	[sp+8],d3
	ba	st_fillr5_array
	ld	[sp+12],d4

fillr5_array_1:
	st	d2,[a6+4]
	mov	d5,d6
	st	d3,[a6+8]
	add	sp,16,a3
	st	d4,[a6+12]
	inc	16,a6
	ld	[a3],%o0
copy_elem_lp5:
	inc	4,a3
	st	%o0,[a6]
	inc	4,a6
	deccc	1,d6
	bcc,a	copy_elem_lp5
	ld	[a3],%o0
st_fillr5_array:
	deccc	1,d0
	bcc,a	fillr5_array_1
	st	d1,[a6]

	jmp	a1+8
	mov	a2,sp

!
!	AP code
!

#if 0
e__system__eaAP:
	st	a0,[%i4]
	inc	4,%i4
	mov	a1,a0
	ba	ea_ap
	mov	%i2,a1

	sethi	%hi e__system__eaAP,%i2
	ba	eval_upd_2
	inc	%lo e__system__eaAP,%i2
	.word	e__system__AP
	.word	2
e__system__nAP:
	st	a0,[%i4]
	st	a5,[a0]
	ld	[a0+4],a1
	ld	[a0+8],a0
	inc	4,%i4
ea_ap:
	ld	[a1],d0
	btst	2,d0
	bne	ap_1
	nop

	st	a0,[%i4]
	mov	a1,a0
	inc	4,%i4
	dec	4,sp
	call	d0
	st	%o7,[sp]
	mov	a0,a1
	ld	[%i4-4],a0
	dec	4,%i4
ap_1:	
	ld	[a1],a2
	ld	[a2+4-2],a2
	dec	4,sp
	call	a2
	st	%o7,[sp]

	ld	[%i4-4],%i2
	dec	4,%i4
	ld	[a0],d0
	ld	[a0+4],d1
	st	d0,[%i2]
	ld	[a0+8],d2
	st	d1,[%i2+4]
	st	d2,[%i2+8]
	mov	%i2,a0

	ld	[sp],%o7
	retl
	inc	4,sp
#endif

e__system__sAP:
	ld	[a1],a2
	ld	[a2+4-2],a2
	jmp	a2
	nop

_create_arrayB:
	mov	d0,d1
	inc	3,d0
	srl	d0,2,d0
	dec	3,d7
	subcc	d7,d0,d7
	bpos	no_collect_3575
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_3575:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d1,[a6+4]
	set	BOOL+2,%o0
	st	%o0,[a6+8]
	inc	12,a6

	sll	d0,2,d0
	add	a6,d0,a6
	ld	[sp],%o7
	retl
	inc	4,sp

_create_arrayC:
	mov	d0,d1
	inc	3,d0
	srl	d0,2,d0
	dec	2,d7
	subcc	d7,d0,d7
	bpos	no_collect_3578
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_3578:
	set	__STRING__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d1,[a6+4]
	inc	8,a6
	sll	d0,2,d0
	add	a6,d0,a6
	ld	[sp],%o7
	retl
	inc	4,sp

_create_arrayI:
	dec	3,d7
	subcc	d7,d0,d7
	bpos	no_collect_3577
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_3577:
	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	set	INT+2,%o0
	st	%o0,[a6+8]
	inc	12,a6

	sll	d0,2,d0
	add	a6,d0,a6
	ld	[sp],%o7
	retl
	inc	4,sp

_create_arrayR:
 	dec	3,d7
	sub	d7,d0,d7
	subcc	d7,d0,d7
	bpos	no_collect_3579
	nop

	dec	4,sp
	call	collect_0
	st	%o7,[sp]

no_collect_3579:
	mov	a6,a0
	set	__ARRAY__+2,%o0
	st	%o0,[a6]
	st	d0,[a6+4]
	set	REAL+2,%o0
	st	%o0,[a6+8]
	inc	12,a6
	sll	d0,3,d0
	add	a6,d0,a6
	ld	[sp],%o7
	retl	
	inc	4,sp

_create_r_array:
	dec	3,d7
	mov	d2,d5
sub_size_lp2:
	deccc	1,d5
	bg	sub_size_lp2
	sub	d7,d0,d7

	tst	d7
	bpos	no_collect_3585
	nop

	dec	4,sp
	call	collect_1
	st	%o7,[sp]

no_collect_3585:
	mov	a0,d4

	set	__ARRAY__+2,%o0
	mov	a6,a0
	st	%o0,[a6]
	st	d0,[a6+4]
	st	d1,[a6+8]
	inc	12,a6

	ld	[sp],a1

	tst	d3
	be	_create_r_array_0
	inc	4,sp

	deccc	2,d3
	bcs	_create_r_array_1
	nop
	be	_create_r_array_2
	nop
	deccc	2,d3
	bcs	_create_r_array_3
	nop
	be	_create_r_array_4
	nop
	b,a	_create_r_array_5

_create_r_array_0:
	tst	d2
	beq	_skip_fillr0_array_lp
	sll	d0,2,d0

_fillr0_array_1:
	deccc	d2
	bne	_fillr0_array_1
	add	a6,d0,a6

_skip_fillr0_array_lp:
	jmp	a1+8
	nop	

_create_r_array_1:
	tst	d0
	beq	_skip_fillr1_array_lp
	sll	d2,2,d2

_fillr1_array_lp:
	st	d4,[a6]
	deccc	d0
	bne	_fillr1_array_lp
	add	a6,d2,a6

_skip_fillr1_array_lp:
	jmp	a1+8
	nop

_create_r_array_2:
	tst	d0
	beq	_skip_fillr2_array_1
	sll	d2,2,d2

_fillr2_array_1:
	st	d4,[a6]
	st	d4,[a6+4]
	deccc	d0
	bne	_fillr2_array_1
	add	a6,d2,a6

_skip_fillr2_array_1:
	jmp	a1+8
	nop

_create_r_array_3:
	tst	d0
	beq	_skip_fillr3_array
	sll	d2,2,d2

_fillr3_array_1:
	st	d4,[a6]
	st	d4,[a6+4]
	st	d4,[a6+8]
	deccc	d0
	bne	_fillr3_array_1
	add	a6,d2,a6

_skip_fillr3_array:
	jmp	a1+8
	nop

_create_r_array_4:
	tst	d0
	beq	_skip_fillr4_array
	sll	d2,2,d2

_fillr4_array:
	st	d4,[a6]
	st	d4,[a6+4]
	st	d4,[a6+8]
	st	d4,[a6+12]
	deccc	d0
	bne	_fillr4_array
	add	a6,d2,a6

_skip_fillr4_array:
	jmp	a1+8
	nop

_create_r_array_5:
	mov	d3,d1
	dec	4,d2
	sub	d2,d3,d2
	ba	_st_fillr5_array
	sll	d2,2,d2

_fillr5_array_1:
	st	d4,[a6+4]
	mov	d1,d5
	st	d4,[a6+8]
	st	d4,[a6+12]
	inc	16,a6

_copy_elem_lp5:
	st	d4,[a6]
	deccc	d5
	bne	_copy_elem_lp5
	inc	4,a6

	add	a6,d2,a6
_st_fillr5_array:
	deccc	d0
	bge,a	_fillr5_array_1
	st	d4,[a6]

	jmp	a1+8
	nop

#ifndef NEW_DESCRIPTORS
yet_args_needed:
! for more than 4 arguments
	ld	[a1],d1
	lduh	[d1-2],d0
	dec	3,%l7
	subcc	%l7,d0,%l7
	bneg	gc_1
	nop

gc_r_1:	ld	[a1+4],%l3
	dec	1+4,d0
	ld	[a1+8],a1
	mov	%g6,d2
	ld	[a1],%o0
	ld	[a1+4],%o1
	st	%o0,[%g6]
	ld	[a1+8],%o2
	st	%o1,[%g6+4]
	inc	12,a1
	st	%o2,[%g6+8]
	inc	12,%g6

	ld	[a1],%o0
cp_a:	inc	4,a1
	st	%o0,[%g6]
	inc	4,%g6
	deccc	d0
	bge,a	cp_a
	ld	[a1],%o0

	st	a0,[%g6]
	inc	8,d1
	st	d1,[%g6+4]
	add	%g6,4,a0
	st	%l3,[%g6+8]
	ld	[sp],%o7
	st	d2,[%g6+12]
	inc	4,sp
	retl
	inc	16,%g6

gc_1:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	b,a	gc_r_1

yet_args_needed_0:
	deccc	2,%l7
	bneg	gc_20
	nop
gc_r_20:	st	a0,[%g6+4]
	ld	[a1],d0
	mov	%g6,a0
	inc	8,d0
	st	d0,[%g6]
	ld	[sp],%o7
	inc	8,%g6
	retl
	inc	4,sp

gc_20:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba	gc_r_20
	nop

yet_args_needed_1:
	deccc	3,%l7
	bneg	gc_21
	nop
gc_r_21:	st	a0,[%g6+8]
	ld	[a1],d0
	mov	%g6,a0
	inc	8,d0
	st	d0,[%g6]
	ld	[a1+4],d1
	st	d1,[%g6+4]
	ld	[sp],%o7
	inc	12,%g6
	retl
	inc	4,sp

gc_21:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	b,a	gc_r_21

yet_args_needed_2:
	deccc	5,%l7
	bneg	gc_22
	nop
gc_r_22:
	ld	[a1],d0
	st	a0,[%g6+4]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[%g6+8]
	add	%g6,8,a0
	ld	[a1+8],%o0
	st	d2,[%g6+12]
	ld	[sp],%o7
	st	%o0,[%g6]
	inc	4,sp
	st	%g6,[%g6+16]
	retl
	inc	20,%g6
	
gc_22:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba	gc_r_22
	nop

yet_args_needed_3:
	deccc	6,%l7
	bneg	gc_23
	nop
gc_r_23:
	ld	[a1],d0
	st	a0,[%g6+8]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[%g6+12]
	ld	[a1+8],a1
	st	d2,[%g6+16]
	ld	[a1],%o0
	st	%g6,[%g6+20]
	ld	[a1+4],%o1
	add	%g6,12,a0
	st	%o0,[%g6]
	ld	[sp],%o7
	inc	4,sp
	st	%o1,[%g6+4]
	retl
	inc	24,%g6

gc_23:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	b,a	gc_r_23

yet_args_needed_4:
	deccc	7,%l7
	bneg	gc_24
	nop
gc_r_24:
	ld	[a1],d0
	st	a0,[%g6+12]
	inc	8,d0
	ld	[a1+4],d2
	st	d0,[%g6+16]
	ld	[a1+8],a1
	st	d2,[%g6+20]
	ld	[a1],%o0
	st	%g6,[%g6+24]
	ld	[a1+4],%o1
	st	%o0,[%g6]
	add	%g6,16,a0
	ld	[a1+8],%o2
	st	%o1,[%g6+4]
	ld	[sp],%o7
	inc	4,sp
	st	%o2,[%g6+8]
	retl
	inc	28,%g6

gc_24:	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	ba	gc_r_24
	nop
#endif

repl_args_b:
	tst	d0
	ble	repl_args_b_1
	nop
	deccc	1,d0
	beq	repl_args_b_4
	nop
	ld	[a0+8],a1
	deccc	2,d1
	bne	repl_args_b_2
	nop
	st	a1,[%i4]
	ba	repl_args_b_4
	inc	4,%i4

repl_args_b_2:
	sll	d0,2,d1
	add	a1,d1,a1
	dec	1,d0
repl_args_b_3:
	ld	[a1-4],%o0
	st	%o0,[%i4]
	dec	4,a1
	inc	4,%i4
	tst	d0
	bne	repl_args_b_3
	dec	d0
repl_args_b_4:
	ld	[a0+4],%o0
	st	%o0,[%i4]
	inc	4,%i4
repl_args_b_1:
	ld	[sp],%o7
	retl
	inc	4,sp

push_arg_b:
	cmp	d1,2
	bcs	push_arg_b_1
	nop
	bne	push_arg_b_2
	nop
	cmp	d1,d0
	beq	push_arg_b_1
	nop
push_arg_b_2:
	ld	[a0+8],a0
	dec	2,d1
push_arg_b_1:
	ld	[sp],%o7
	sll	d1,2,d1
	ld	[a0+d1],a0
	retl
	inc	4,sp

del_args:
	ld	[a0],d1
	sub	d1,d0,d1
	lduh	[d1-2],d0
	deccc	2,d0
	bge	del_args_2
	nop
	ld	[a0+4],%o0
	st	d1,[a1]
	ld	[a0+8],%o1
	st	%o0,[a1+4]
	ld	[sp],%o7
	st	%o1,[a1+8]
	retl
	inc	4,sp

del_args_2:
	bne	del_args_3
	nop
	ld	[a0+4],%o0
	st	d1,[a1]
	ld	[a0+8],%o1
	st	%o0,[a1+4]
	ld	[%o1],%o1
	ld	[sp],%o7
	st	%o1,[a1+8]
	retl
	inc	4,sp

del_args_3:
	subcc	%l7,d0,%l7
	bneg	del_args_gc
	nop
del_args_r_gc:
	st	d1,[a1]
	ld	[a0+4],%o0
	st	%g6,[a1+8]
	ld	[a0+8],a0
	st	%o0,[a1+4]

	ld	[a0],%o0
del_args_copy_args:
	inc	4,a0
	st	%o0,[%g6]
	inc	4,%g6
	deccc	d0
	bg,a	del_args_copy_args
	ld	[a0],%o0

	ld	[sp],%o7	
	retl
	inc	4,sp

del_args_gc:
	dec	4,sp
	call	collect_2
	st	%o7,[sp]
	b,a	del_args_r_gc

#if 0
o__S_P2:
	ld	[a0],d0
	ldsh	[d0-2],d0
	cmp	d0,2
	be	o__S_P2_2
	ld	[a0+8],a0
	ld	[a0],a0
o__S_P2_2:
	ld	[sp],%o7	
	retl
	inc	4,sp

ea__S_P2:
	ld	[a1+4],d0
	set	__indirection,%i2
	st	%i2,[a1]
	st	a0,[a1+4]
	mov	d0,a1
	ld	[a1],d0
	btst	2,d0
	bne	ea__S_P2_1
	nop
	
	st	a0,[%i4]
	inc	4,%i4
	mov	a1,a0
	dec	4,sp
	call	d0
	st	%o7,[sp]
	mov	a0,a1
	ld	[%i4-4],a0
	dec	4,%i4

ea__S_P2_1:
	ld	[a1],d0
	ldsh	[d0-2],d0
	cmp	d0,2
	be	ea__S_P2_2
	ld	[a1+8],a1
	ld	[a1],a1
ea__S_P2_2:
	ld	[a1],d0
	btst	2,d0
	bne	ea__S_P2_3
	nop

	jmp	d0-20
	nop

ea__S_P2_3:
	st	d0,[a0]
	ld	[a1+4],%g1
	st	%g1,[a0+4]
	ld	[a1+8],%g1
	st	%g1,[a0+8]

	ld	[sp],%o7
	retl
	inc	4,sp
#endif

#ifdef NEW_DESCRIPTORS
# include "sap.s"
#endif
