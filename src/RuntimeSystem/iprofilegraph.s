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

	.global	profile_t
	.global	profile_r
	.global	profile_l
	.global	profile_l2
	.global	profile_n
	.global	profile_n2
	.global	profile_s
	.global	profile_s2
	.global	write_profile_stack
	.global	write_profile_information
	.global	init_profiler
	.global	@get_time_stamp_counter
	.global	@measure_profile_overhead

	.global	@profile_data_stack_ptr
	.global	@profile_last_tail_call
	.global	@ab_stack_size

	.global	@c_profile_l
	.global	@c_profile_n
	.global	@c_profile_s
	.global	@c_write_profile_stack
	.global	@c_write_profile_information
	.global	@c_init_profiler

#define ticks_lo	8
#define ticks_hi	12
#define allocated_words_lo	16
#define allocated_words_hi	20
#define tail_and_return_calls	24

	.text
profile_t:
	push	d0
	push	a1
	rdtsc
	push	a0

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1

	mov	@profile_data_stack_ptr,a0
	mov	(a0),a0
	mov	a0,@profile_last_tail_call

	jmp	profile_r_

profile_r:
	push	d0
	push	a1
	rdtsc
	push	a0

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1

	mov	@profile_data_stack_ptr,a0
	mov	(a0),a0
	movl	$0,@profile_last_tail_call
profile_r_:
	add	d0,ticks_lo(a0)
	adc	a1,ticks_hi(a0)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	add	d0,allocated_words_lo(a0)
	adc	$0,allocated_words_hi(a0)

	incl	tail_and_return_calls(a0)

	sub	$4,@profile_data_stack_ptr
	mov	@profile_data_stack_ptr,a0
	mov	(a0),a0
	mov	a0,@profile_current_cost_centre

	pop	a0
	rdtsc
	mov	a1,tick_count_hi
	mov	d0,tick_count_lo

	pop	a1
	pop	d0
	ret

profile_l:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_l
	jmp	end_profile_call

profile_l2:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_l
	jmp	end_profile_call_2

profile_n:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a0,20(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_n
	jmp	end_profile_call

profile_n2:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a0,20(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_n
	jmp	end_profile_call_2

profile_eval_upd:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	mov	a1,20(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_n
	jmp	end_profile_call

profile_s:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_s
	jmp	end_profile_call

profile_s2:
	sub	$36,sp
	mov	d0,32(sp)
	mov	a1,28(sp)
	rdtsc
	mov	a0,24(sp)
	mov	a2,(sp)

	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1
	mov	a1,8(sp)
	mov	d0,4(sp)

	mov	end_heap,a1
	sub	a4,a1
	mov	bytes_free,d0
	add	$32,a1
	sub	a1,d0
	mov	a1,bytes_free
	sar	$2,d0
	mov	d0,12(sp)
	movl	$0,16(sp)

	call	@c_profile_s

end_profile_call_2:
	mov	@profile_data_stack_ptr,a0
	movl	(a0),a1
	add	$4,a0
	mov	a0,@profile_data_stack_ptr
	mov	a1,(a0)
	jmp	end_profile_call_

end_profile_call:
	mov	@profile_data_stack_ptr,a1
	mov	(a1),a1
end_profile_call_:
	mov	a1,@profile_current_cost_centre
	add	$24,sp

	pop	a0

	rdtsc
	mov	a1,tick_count_hi
	mov	d0,tick_count_lo

	pop	a1
	pop	d0
	ret

write_profile_stack:
	jmp	@c_write_profile_stack

write_profile_information:
	jmp	@c_write_profile_information

init_profiler:
	movl	$2,@profile_type

	push	d0
	push	a1

	push	@ab_stack_size
	call	@c_init_profiler
	add	$4,sp

	mov	end_heap,a1
	sub	a4,a1
	add	$32,a1
	mov	a1,bytes_free

	rdtsc
	mov	a1,tick_count_hi
	mov	d0,tick_count_lo

	pop	a1
	pop	d0
	ret

@get_time_stamp_counter:
	rdtsc
	ret

@measure_profile_overhead:
	push	a2
	lea	measure_profile_overhead_dummy,a2

	mov	end_heap,a1
	sub	a4,a1
	add	$32,a1
	mov	a1,bytes_free

	rdtsc
	mov	a1,tick_count_hi
	mov	d0,tick_count_lo

	call	profile_s
	mov	$99999,d0
measure_profile_overhead_lp1:
	call	profile_s
	add	a0,a0
	add	a1,a1
	add	a0,a0
	add	a1,a1
	call	profile_r
	sub	$1,d0
	jne	measure_profile_overhead_lp1
	call	profile_r

	mov	$100000,d0
measure_profile_overhead_lp2:
	add	a0,a0
	add	a1,a1
	add	a0,a0
	add	a1,a1
	sub	$1,d0
	jne	measure_profile_overhead_lp2

	rdtsc
	sub	tick_count_lo,d0
	sbb	tick_count_hi,a1

	pop	a2
	ret

	.data
	align	(2)
tick_count_lo:
	.long	0
tick_count_hi:
	.long	0
bytes_free:
	.long	0

	align	(2)
	.long	m_system
measure_profile_overhead_dummy:
	.byte	0
