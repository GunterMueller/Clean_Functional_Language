
        .syntax unified
        .thumb

	.include "tmacros.s"

	.globl	profile_t
	.globl	profile_ti
	.globl	profile_r
	.globl	profile_l
	.globl	profile_n
	.globl	profile_s
	.globl	profile_l2
	.globl	profile_n2
	.globl	profile_s2
	.globl	init_profiler
	.globl	write_profile_stack

	.text

profile_t:
	lao	r7,profile_stack_pointer,0
	ldo	r7,r7,profile_stack_pointer,0
	subs	r7,r7,#4
	lao	r12,profile_stack_pointer,1
	sto	r7,r12,profile_stack_pointer,1
	bx	lr

profile_ti:
	lao	r7,profile_stack_pointer,0
	ldo	r7,r7,profile_stack_pointer,0
	subs	r7,r7,#4
	lao	r14,profile_stack_pointer,1
	sto	r7,r14,profile_stack_pointer,1
	bx	r12

profile_r:
	lao	r7,profile_stack_pointer,0
	ldo	r7,r7,profile_stack_pointer,0
	subs	r7,r7,#4
	lao	r12,profile_stack_pointer,1
	sto	r7,r12,profile_stack_pointer,1
	pop	{pc}

profile_l:
profile_n:
profile_s:
	lao	r7,profile_stack_pointer,2
	ldo	r7,r7,profile_stack_pointer,2
	str	r12,[r7],#4
	lao	r12,profile_stack_pointer,3
	sto	r7,r12,profile_stack_pointer,3
	bx	lr

profile_l2:
profile_n2:
profile_s2:
	lao	r7,profile_stack_pointer,4
	ldo	r7,r7,profile_stack_pointer,4
	strd	r12,r12,[r7],#8
	lao	r12,profile_stack_pointer,5
	sto	r7,r12,profile_stack_pointer,5
	bx	lr

.ifdef PIC
	lto	profile_stack_pointer,0
	lto	profile_stack_pointer,1
	lto	profile_stack_pointer,2
	lto	profile_stack_pointer,3
	lto	profile_stack_pointer,4
	lto	profile_stack_pointer,5
.endif

init_profiler:
	lao	r0,ab_stack_size,0
	ldo	r0,r0,ab_stack_size,0

	bl	malloc

	cmp	r0,#0
	beq	init_profiler_error

	lao	r1,start_string,0
	otoa	r1,start_string,0

	str	r1,[r0,#4]
	movs	r1,#0
	str	r1,[r0],#8

	lao	r7,profile_stack_pointer,6
	sto	r0,r7,profile_stack_pointer,6

	pop	{pc}

init_profiler_error:
	lao	r7,profile_stack_pointer,7
	sto	r0,r7,profile_stack_pointer,7

	lao	r0,not_enough_memory_for_profile_stack,0
	otoa	r0,not_enough_memory_for_profile_stack,0
        b       print_error

.ifdef PIC
	lto	ab_stack_size,0
	lto	start_string,0
	lto	profile_stack_pointer,6
	lto	profile_stack_pointer,7
	lto	not_enough_memory_for_profile_stack,0
.endif

write_profile_stack:
	lao	r7,profile_stack_pointer,8
	ldo	r4,r7,profile_stack_pointer,8

	cmp	r4,#0
	beq	stack_not_initialised

	lao	r0,stack_trace_string,0
	otoa	r0,stack_trace_string,0
	bl	ew_print_string

	lao	r7,stack_trace_depth,0
	ldo	r8,r7,stack_trace_depth,0

write_functions_on_stack:
	ldr	r7,[r4,#-4]!
	cmp	r7,#0
	beq	end_profile_stack

	adds	r0,r7,#4
	bl	ew_print_string

	lao	r0,module_string,0
	otoa	r0,module_string,0
	bl	ew_print_string

	ldr	r0,[r7,#-4]
	ldr	r1,[r0],#4
	bl	ew_print_text

	movs	r0,#']'
	bl	ew_print_char

	movs	r0,#10
	bl	ew_print_char

	subs	r8,r8,$1
	bne	write_functions_on_stack

stack_not_initialised:
end_profile_stack:
	pop	{pc}

.ifdef PIC
	lto	profile_stack_pointer,8
	lto	stack_trace_string,0
	lto	stack_trace_depth,0
	lto	module_string,0
.endif

	.data
	.p2align	2
profile_stack_pointer:
	.long	0
stack_trace_depth:
	.long	12

	.long	m_system
start_string:
	.long	0
	.asciz	"start"

	.p2align	2
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
	.p2align	2


