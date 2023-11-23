
#define MODULE_NAMES

#define d0 %eax
#define d1 %ebx
#define a0 %ecx
#define a1 %edx
#define a2 %ebp
#define a3 %esi
#define a4 %edi
#define sp %esp

#if defined(_WINDOWS_)
# define	align(n) .align (1<<n)
#else
# define	align(n) .align n
#endif

	.global	init_profiler
	.global	profile_r
	.global profile_l
	.global profile_l2
	.global profile_n
	.global profile_n2
	.global profile_s
	.global profile_s2
	.global profile_t
	.global	write_profile_information
	.global	write_profile_stack

#ifdef LINUX
	.global	@malloc
#else
	.global	@allocate_memory
#endif
	.global	__STRING__
	.global	writeFC
	.global	writeFI
	.global	print_error
	.global	@ab_stack_size
	.global	@ew_print_string
	.global	@ew_print_char
	.global	@stack_trace_depth

#define	next		0
#define	name		4
#define	FunctionProfile	8

	.text
profile_t:
profile_r:
	subl	$4,profile_stack_pointer
	ret

profile_l:
profile_n:
profile_s:
	push	d1
	mov	profile_stack_pointer,d1
	mov	a2,(d1)
	add	$4,d1
	mov	d1,profile_stack_pointer
	pop	d1
	ret

profile_l2:
profile_n2:
profile_s2:
	push	d1
	mov	profile_stack_pointer,d1
	mov	a2,(d1)
	mov	a2,4(d1)
	add	$8,d1
	mov	d1,profile_stack_pointer
	pop	d1
	ret

write_profile_information:
	ret
	
write_profile_stack:
	mov	profile_stack_pointer,d0

	test	d0,d0
	je	stack_not_initialised

	push	d0
	
	push	$stack_trace_string
	call	@ew_print_string
	add	$4,sp
	
	pop	d0
	
/	mov	$12,a2
	movl	@stack_trace_depth,a2
write_functions_on_stack:
	mov	-4(d0),a0
	sub	$4,d0

	test	a0,a0
	je	end_profile_stack

	push	d0
	push	a2

#ifdef MODULE_NAMES
	movl	-4(a0),a1
#endif

	add	$4,a0

#ifdef MODULE_NAMES
	pushl	(a1)
	addl	$4,a1
	pushl	a1
#endif

	push	a0
	call	@ew_print_string
	add	$4,sp

#ifdef MODULE_NAMES
	pushl	$module_string
	call	@ew_print_string
	add	$4,sp

	call	@ew_print_text
	addl	$8,sp

	pushl	$']'
	call	@ew_print_char
	add	$4,sp
#endif

	pushl	$10
	call	@ew_print_char
	add	$4,sp

	pop	a2
	pop	d0

	sub	$1,a2
	jne	write_functions_on_stack
	
end_profile_stack:
stack_not_initialised:
	ret

init_profiler:
	movl	$3,@profile_type

	pushl	@ab_stack_size
#ifdef LINUX
	call	@malloc
#else
	call	@allocate_memory
#endif
	add	$4,sp
	
	test	d0,d0
	je	init_profiler_error

	push	d0
	
	mov	$start_string,d1

	pop	a1

	mov	d1,4(a1)
	movl	$0,(a1)
	add	$8,a1
	mov	a1,profile_stack_pointer
	ret

init_profiler_error:
	movl	$0,profile_stack_pointer
	movl	$not_enough_memory_for_profile_stack,a2
	jmp	print_error

	.data

	align	(2)
@stack_trace_depth:
	.long	12
#ifdef MODULE_NAMES
# if 0
/ m_system also defined in istartup.s
m_system:
	.long	6
	.ascii	"System"
	.byte	0
	.byte	0
# endif
	.long	m_system
#endif
start_string:
	.long	0
	.asciz	"start"
	align	(2)
not_enough_memory_for_profile_stack:
	.ascii	"not enough memory for profile stack"
	.byte	10
	.byte	0
stack_trace_string:
	.ascii	"Stack trace:"
	.byte	10
	.byte	0
#ifdef MODULE_NAMES
module_string:
	.asciz	" [module: "
#endif
	align	(2)
