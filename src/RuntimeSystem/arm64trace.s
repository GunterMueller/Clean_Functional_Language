
	.globl	profile_t
	.globl	profile_l
	.globl	profile_n
	.globl	profile_s
	.globl	profile_r
	.globl	profile_l2
	.globl	profile_n2
	.globl	profile_s2
	.globl	init_profiler
	.globl	write_profile_stack

	.text

profile_l:
profile_n:
profile_s:
	adrp	x17,profile_stack_pointer
	ldr	x17,[x17,#:lo12:profile_stack_pointer]
	str	x16,[x17],#8
	adrp	x16,profile_stack_pointer
	str	x17,[x16,#:lo12:profile_stack_pointer]

	mov	x17,x30
	mov	x30,x29
	ret	x17

profile_l2:
profile_n2:
profile_s2:
	adrp	x17,profile_stack_pointer
	ldr	x17,[x17,#:lo12:profile_stack_pointer]
	stp	x16,x16,[x17],#16
	adrp	x16,profile_stack_pointer
	str	x17,[x16,#:lo12:profile_stack_pointer]

	mov	x17,x30
	mov	x30,x29
	ret	x17

profile_t:
	adrp	x17,profile_stack_pointer
	ldr	x16,[x17,#:lo12:profile_stack_pointer]
	sub	x16,x16,8
	str	x16,[x17,#:lo12:profile_stack_pointer]

	mov	x17,x30
	mov	x30,x29
	ret	x17

profile_r:
	adrp	x17,profile_stack_pointer
	ldr	x16,[x17,#:lo12:profile_stack_pointer]
	sub	x16,x16,8
	str	x16,[x17,#:lo12:profile_stack_pointer]

	mov	x29,x30
        ldr	x30,[x28],#8
        ret	x29

init_profiler:
	mov	x29,x30

	adrp	x16,ab_stack_size
	ldr	x16,[x16,#:lo12:ab_stack_size]

	add	x0,x16,#7
	bl	malloc

	cbz	x0,init_profiler_error

	adrp	x1,start_string
	add	x1,x1,#:lo12:start_string

	stp	xzr,x1,[x0],#16

	adrp	x16,profile_stack_pointer
	str	x0,[x16,#:lo12:profile_stack_pointer]

        ldr	x30,[x28],#8
        ret	x29

init_profiler_error:
	adrp	x16,profile_stack_pointer
	str	x0,[x16,#:lo12:profile_stack_pointer]

	adrp	x10,not_enough_memory_for_profile_stack
	add	x10,x10,#:lo12:not_enough_memory_for_profile_stack
	b	print_error

write_profile_stack:
	mov	x29,x30

	mov	x19,sp
	and	sp,x19,#-16

	sub	x28,x28,24

	adrp	x16,profile_stack_pointer
	ldr	x6,[x16,#:lo12:profile_stack_pointer]

	cbz	x6,end_profile_stack

	adrp	x16,stack_trace_depth
	ldr	x5,[x16,#:lo12:stack_trace_depth]

	stp	x5,x6,[x28]
	adrp	x0,stack_trace_string
	add	x0,x0,#:lo12:stack_trace_string
	bl	ew_print_string
	ldp	x5,x6,[x28]

write_functions_on_stack:
	ldr	x4,[x6,#-8]!
	cbz	x4,end_profile_stack

	stp	x5,x6,[x28]

	str	x4,[x28,#16]

	add	x0,x4,#12
	bl	ew_print_string

	adrp	x0,module_string
	add	x0,x0,#:lo12:module_string
	bl	ew_print_string

	ldr	x4,[x28,#16]

	ldr	w0,[x4,#8]
	ldr	w1,[x0],#4
	bl	ew_print_text

	mov	x0,#']'
	bl	ew_print_char

	mov	x0,#10
	bl	ew_print_char

	ldp	x5,x6,[x28]

	subs	x5,x5,#1
	bne	write_functions_on_stack

end_profile_stack:
	add	x28,x28,24

	mov	sp,x19

        ldr	x30,[x28],#8
        ret	x29

	.data
	.p2align	3
profile_stack_pointer:
	.quad	0
stack_trace_depth:
	.quad	12

	.p2align	3
start_string:
	.quad	0
	.long	m_system
	.asciz	"start"

not_enough_memory_for_profile_stack:
	.ascii	"not enough memory for profile stack"
	.byte	10
	.byte	0
stack_trace_string:
	.ascii	"Stack trace:"
	.byte	10
	.byte	0
module_string:
	.asciz	" [module: "

	.p2align	3

