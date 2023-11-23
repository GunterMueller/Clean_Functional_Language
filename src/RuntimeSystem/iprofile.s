
#undef DEBUG_PROFILER

#define ALLOCATION_PROFILE
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
	.global	openF
	.global	closeF
	.global	writeFC
	.global	writeFI
	.global	print_error
	.global	@ab_stack_size
	.global	@ew_print_string
	.global	@ew_print_char
	.global	@create_profile_file_name
	.global	@stack_trace_depth

#define	next		0
#define	time_hi		4
#define	time_lo		8
#define	n_profiler_calls	12
#define	n_strict_calls	16
#define	n_lazy_calls	20
#define	n_curried_calls	24
#define	n_words_allocated	28
#define	name		32
#define	FunctionProfile	36
	
	.text
profile_t:
	push	d0
	push	a1
	rdtsc

	push	a0
	mov	profile_stack_pointer,a0

	push	d1	
	mov	-4(a0),d1
	
	sub	$4,a0
	mov	d1,global_last_tail_call

	mov	a0,profile_stack_pointer

	sub	global_time_lo,d0	
	sbb	global_time_hi,a1

	add	d0,time_lo(d1)	
	adc	a1,time_hi(d1)
	
	incl	n_profiler_calls(d1)

#ifdef ALLOCATION_PROFILE
 	mov	end_heap,a0
	sub	a4,a0
	mov	global_n_bytes_free,d0
	add	$32,a0	
	sub	a0,d0
	mov	a0,global_n_bytes_free
	sar	$2,d0
	add	d0,n_words_allocated(d1)
#endif

	pop	d1
	pop	a0

	rdtsc
	mov	a1,global_time_hi
	pop	a1
	mov	d0,global_time_lo
	pop	d0
	ret

profile_r:
	push	d0
	push	a1
	rdtsc

	push	a0
	mov	profile_stack_pointer,a0

	push	d1	
	mov	-4(a0),d1

	sub	$4,a0
	movl	$0,global_last_tail_call

	mov	a0,profile_stack_pointer

	sub	global_time_lo,d0
	sbb	global_time_hi,a1

	add	d0,time_lo(d1)
	adc	a1,time_hi(d1)

	incl	n_profiler_calls(d1)

#ifdef ALLOCATION_PROFILE
 	mov	end_heap,a0
	sub	a4,a0
	mov	global_n_bytes_free,d0
	add	$32,a0	
	sub	a0,d0
	mov	a0,global_n_bytes_free
	sar	$2,d0
	add	d0,n_words_allocated(d1)
#endif

	pop	d1
	pop	a0

	rdtsc
	mov	a1,global_time_hi
	pop	a1
	mov	d0,global_time_lo
	pop	d0
	ret

profile_l:
	push	d0
	push	a1
	rdtsc

	push	d1
	mov	(a2),d1

	test	d1,d1
	je	allocate_function_profile_record_l
allocate_function_profile_record_lr:
	push	a0
	
	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0

	test	a2,a2
	jne	use_tail_calling_function_l

	mov	-4(a0),a2
use_tail_calling_function_lr:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	mov	d1,(a0)
	add	$4,a0
	
	incl	n_curried_calls(d1)
	jmp	profile_n_

allocate_function_profile_record_l:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_lr

use_tail_calling_function_l:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_lr

profile_l2:
	push	d0
	push	a1
	rdtsc

	push	d1
	mov	(a2),d1

	test	d1,d1
	je	allocate_function_profile_record_l2
allocate_function_profile_record_l2r:
	push	a0
	
	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0
	
	test	a2,a2
	jne	use_tail_calling_function_l2

	mov	-4(a0),a2
use_tail_calling_function_l2r:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	mov	d1,(a0)
	mov	d1,4(a0)
	add	$8,a0

	incl	n_curried_calls(d1)
	jmp	profile_n_

allocate_function_profile_record_l2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_l2r

use_tail_calling_function_l2:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_l2r

profile_n:
	push	d0
	push	a1
	rdtsc
		
	push	d1
	mov	(a2),d1
	
	test	d1,d1
	je	allocate_function_profile_record_n
allocate_function_profile_record_nr:
	push	a0
	
	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0

	test	a2,a2
	jne	use_tail_calling_function_n

	mov	-4(a0),a2
use_tail_calling_function_nr:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	mov	d1,(a0)
	add	$4,a0

	incl	n_lazy_calls(d1)
	jmp	profile_n_

allocate_function_profile_record_n:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_nr

use_tail_calling_function_n:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_nr

profile_n2:
	push	d0
	push	a1
	rdtsc

	push	d1
	mov	(a2),d1

	test	d1,d1
	je	allocate_function_profile_record_n2
allocate_function_profile_record_n2r:
	push	a0
	
	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0

	test	a2,a2
	jne	use_tail_calling_function_n2

	mov	-4(a0),a2
use_tail_calling_function_n2r:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	mov	d1,(a0)
	mov	d1,4(a0)
	add	$8,a0

	incl	n_lazy_calls(d1)
	jmp	profile_n_

allocate_function_profile_record_n2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_n2r

use_tail_calling_function_n2:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_n2r

profile_s2:
	push	d0
	push	a1
	rdtsc
		
	push	d1
	mov	(a2),d1
	
	test	d1,d1
	je	allocate_function_profile_record_s2
allocate_function_profile_record_s2r:
	push	a0

	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0
	
	test	a2,a2
	jne	use_tail_calling_function_s2

	mov	-4(a0),a2
use_tail_calling_function_s2r:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	movl	d1,(a0)
	movl	d1,4(a0)
	add	$8,a0
	jmp	profile_s_

allocate_function_profile_record_s2:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_s2r

use_tail_calling_function_s2:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_s2r

profile_s:
	push	d0
	push	a1
	rdtsc
	
	push	d1
	movl	(a2),d1
	
	test	d1,d1
	je	allocate_function_profile_record_s
allocate_function_profile_record_sr:
	push	a0

	mov	global_last_tail_call,a2
	mov	profile_stack_pointer,a0
	
	test	a2,a2
	jne	use_tail_calling_function_s

	mov	-4(a0),a2
use_tail_calling_function_sr:

#ifdef DEBUG_PROFILER
	testl	(d1),d1
#endif
	movl	d1,(a0)
	add	$4,a0

profile_s_:
	incl	n_strict_calls(d1)

profile_n_:
	mov	a0,profile_stack_pointer

	sub	global_time_lo,d0
	sbb	global_time_hi,a1

	add	d0,time_lo(a2)
	adc	a1,time_hi(a2)

	incl	n_profiler_calls(a2)

#ifdef ALLOCATION_PROFILE
 	mov	end_heap,a0
	sub	a4,a0
	mov	global_n_bytes_free,d0
	add	$32,a0	
	sub	a0,d0
	mov	a0,global_n_bytes_free
	sar	$2,d0
	add	d0,n_words_allocated(a2)
#endif

	pop	a0
	pop	d1

	rdtsc
	mov	a1,global_time_hi
	pop	a1
	mov	d0,global_time_lo
	pop	d0
	ret

allocate_function_profile_record_s:
	call	allocate_function_profile_record
	jmp	allocate_function_profile_record_sr

use_tail_calling_function_s:
	movl	$0,global_last_tail_call
	jmp	use_tail_calling_function_sr


/ argument: a2: function name adress-4
/ result:   d1: function profile record adress

allocate_function_profile_record:
	push	d0
	mov	global_n_free_records_in_block,d0
	mov	global_last_allocated_block,d1

	test	d0,d0
	jne	no_alloc

	push	d1
	push	a0
	push	a1

	pushl	$128*FunctionProfile
#ifdef LINUX
	call	@malloc
#else
	call	@allocate_memory
#endif
	add	$4,sp

	test	d0,d0

	pop	a1
	pop	a0
	pop	d1

	je	no_memory

	mov	d0,d1
	mov	$128,d0
	mov	d1,global_last_allocated_block

no_alloc:	
	dec	d0
	mov	d0,global_n_free_records_in_block
	lea	FunctionProfile(d1),d0
	mov	d0,global_last_allocated_block

	xor	d0,d0
	mov	d0,time_hi(d1)
	mov	d0,time_lo(d1)
	mov	d0,n_profiler_calls(d1)
	mov	d0,n_strict_calls(d1)
	mov	d0,n_lazy_calls(d1)
	mov	d0,n_curried_calls(d1)
	mov	d0,n_words_allocated(d1)

	mov	global_profile_records,d0
	mov	a2,name(d1)

	mov	d0,next(d1)
	mov	d1,global_profile_records
	
	mov	d1,(a2)
	pop	d0
	ret

no_memory:
	movl	$not_enough_memory_for_profiler,a2
	pop	d0
	jmp	print_error

write_profile_information:
	pushl	$profile_file_name
	call	@create_profile_file_name
	addl	$4,sp

	mov	$1,d0
	mov	$profile_file_name,a0
	call	openF

	pop	a0
	test	d1,d1
	je	cannot_open
	
	mov	global_profile_records,a2

write_profile_lp:	
	test	a2,a2
	je	end_list

	mov	name(a2),a1
	push	a2

#ifdef MODULE_NAMES
	push	a1
	
	movl	-4(a1),a1
	movl	(a1),d1
	addl	$4,a1

write_module_name_lp:
	subl	$1,d1
	jc	end_module_name

	pushl	d1
	movzbl	(a1),d1
	pushl	a1

	pushl	$l0
	pushl	a0
	jmp	writeFC
l0:
	popl	a1
	movl	d0,a0
	movl	d1,d0
	popl	d1
	addl	$1,a1
	jmp	write_module_name_lp
	
end_module_name:
	mov	$' ',d1
	push	$l00
	push	a0
	jmp	writeFC
l00:	mov	d0,a0
	mov	d1,d0

	pop	a1
#endif

	add	$3,a1
	
write_function_name_lp:
	movzbl	1(a1),d1
	add	$1,a1

	test	d1,d1
	je	end_function_name

	push	a1

	push	$l1
	push	a0
	jmp	writeFC
l1:	mov	d0,a0
	mov	d1,d0

	pop	a1
	jmp	write_function_name_lp

end_function_name:
	mov	$' ',d1
	push	$l2
	push	a0
	jmp	writeFC
l2:	mov	d0,a0
	mov	d1,d0

	mov	(sp),d1
	mov	n_strict_calls(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	n_lazy_calls(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	n_curried_calls(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	n_profiler_calls(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	n_words_allocated(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	time_hi(d1),d1
	call	writeFI_space

	mov	(sp),d1
	mov	time_lo(d1),d1

	pushl	$l3
	push	a0
	jmp	writeFI
l3:	mov	d0,a0
	mov	d1,d0

	mov	$10,d1
	pushl	$l4
	push	a0
	jmp	writeFC
l4:	mov	d0,a0
	mov	d1,d0

	pop	a2
	mov	next(a2),a2
	jmp	write_profile_lp

writeFI_space:
	pushl	$l5
	push	a0
	jmp	writeFI
l5:	mov	d0,a0
	mov	d1,d0

	push	$l6
	push	a0
	mov	$' ',d1
	jmp	writeFC
l6:	mov	d0,a0
	mov	d1,d0
	ret

end_list:
	mov	d0,d1
	call	closeF

cannot_open:
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
	mov	-4(d0),d1
	sub	$4,d0

	test	d1,d1
	je	end_profile_stack

	push	d0
	mov	name(d1),a0

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

	pushl	a0
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
	movl	$1,@profile_type

	pushfl
	movl	$0x200000,%eax
	pop	%ebx
	xor	%ebx,%eax
	push	%eax
	popfl
	pushfl
	pop	%eax
	xor	%ebx,%eax
	jz	no_tsc_error
	
	movl	$1,%eax
	cpuid
	andl	$16,%edx
	jz	no_tsc_error

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
	
	mov	$start_string,a2
	call	allocate_function_profile_record

	pop	a1

	mov	d1,4(a1)
	movl	$0,(a1)
	add	$8,a1
	mov	a1,profile_stack_pointer
	movl	$0,global_last_tail_call

 	mov	end_heap,a1
	sub	a4,a1
	add	$32,a1	
	mov	a1,global_n_bytes_free

	rdtsc
	mov	a1,global_time_hi
	mov	d0,global_time_lo
	ret

no_tsc_error:
	movl	$0,profile_stack_pointer
	movl	$no_tsc_error_string,a2
	jmp	print_error

init_profiler_error:
	movl	$0,profile_stack_pointer
	movl	$not_enough_memory_for_profile_stack,a2
	jmp	print_error

	.data
	align (2)

global_n_free_records_in_block:	.long 0
/ 0 n free records in block
global_last_allocated_block:	.long 0
/ 4 latest allocated block
global_profile_records:		.long 0
/ 8 profile record list
global_time_hi:			.long 0
/ 12 clock
global_time_lo:			.long 0	
global_last_tail_call:		.long 0
/ last tail calling function
global_n_bytes_free:		.long 0	

profile_file_name:
	.long	__STRING__+2
	.long	0
	.long	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.long	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.long	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.long	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	.long	0
@stack_trace_depth:
	.long	12
	align	(2)
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
no_tsc_error_string:
	.ascii	"cannot profile because this processor does not have a time stamp counter"
	.byte	10
	.byte	0
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
#ifdef MODULE_NAMES
module_string:
	.asciz	" [module: "
#endif
	align	(2)
