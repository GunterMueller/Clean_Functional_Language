
	mov	rax,qword ptr heap_size_65+0
	xor	rbx,rbx 
	
	mov	qword ptr n_marked_words+0,rbx
	shl	rax,6

	mov	qword ptr lazy_array_list+0,rbx
	mov	qword ptr heap_size_64_65+0,rax
	
	lea	rsi,(-4000)[rsp]

	mov	qword ptr end_stack+0,rsi 

	mov	r10,neg_heap_p3+0
	mov	r11,heap_size_64_65+0
	mov	r13,qword ptr end_stack+0
	mov	r14,0

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_before_mark+0
	test	rax,rax
	je	no_gc_hook_before_mark
	call	rax
no_gc_hook_before_mark:
 endif

	mov	rax,qword ptr caf_list+0

	test	rax,rax 
	je	_end_mark_cafs

_mark_cafs_lp:
	mov	rbx,qword ptr [rax]
	mov	rbp,qword ptr (-8)[rax]

	push	rbp
	lea	rbp,8[rax]
	lea	r12,8[rax+rbx*8]

	call	_mark_stack_nodes

	pop	rax 
	test	rax,rax 
	jne	_mark_cafs_lp

_end_mark_cafs:
	mov	rsi,qword ptr stack_top+0
	mov	rbp,qword ptr stack_p+0

	mov	r12,rsi 
	call	_mark_stack_nodes

continue_mark_after_pmark:
	mov	qword ptr n_marked_words+0,r14

	mov	rcx,qword ptr lazy_array_list+0

	test	rcx,rcx 
	je	end_restore_arrays

restore_arrays:
	mov	rbx,qword ptr [rcx]
	lea	r9,__ARRAY__+2+0
	mov	qword ptr [rcx],r9

	cmp	rbx,1
	je	restore_array_size_1

	lea	rdx,[rcx+rbx*8]
	mov	rax,qword ptr 16[rdx]
	test	rax,rax 
	je	restore_lazy_array

	mov	rbp,rax 
	push	rdx 

	xor	rdx,rdx 
	mov	rax,rbx 
	movzx	rbx,word ptr (-2+2)[rbp]

	div	rbx 
	mov	rbx,rax 

	pop	rdx
	mov	rax,rbp 

restore_lazy_array:
	mov	rdi,qword ptr 16[rcx]
	mov	rbp,qword ptr 8[rcx]
	mov	qword ptr 8[rcx],rbx 
	mov	rsi,qword ptr 8[rdx]
	mov	qword ptr 16[rcx],rax 
	mov	qword ptr 8[rdx],rbp 
	mov	qword ptr 16[rdx],rdi 

	test	rax,rax
	je	no_reorder_array

	movzx	rdx,word ptr (-2)[rax]
	sub	rdx,256
	movzx	rbp,word ptr (-2+2)[rax]
	cmp	rbp,rdx 
	je	no_reorder_array

	add	rcx,24
	imul	rbx,rdx 
	mov	rax,rdx 
	lea	rdx,[rcx+rbx*8]
	mov	rbx,rbp 
	sub	rax,rbp 

	call	reorder

no_reorder_array:
	mov	rcx,rsi 
	test	rcx,rcx 
	jne	restore_arrays

	jmp	end_restore_arrays

restore_array_size_1:
	mov	rbp,qword ptr 8[rcx]
	mov	rdx,qword ptr 16[rcx]
	mov	qword ptr 8[rcx],rbx 
	mov	rax,qword ptr 24[rcx]
	mov	qword ptr 24[rcx],rbp 
	mov	qword ptr 16[rcx],rax 

	mov	rcx,rdx 
	test	rcx,rcx 
	jne	restore_arrays

end_restore_arrays:
	mov	rdi,qword ptr heap_vector+0
	lea	rcx,finalizer_list+0
	lea	rdx,free_finalizer_list+0

	mov	rbp,qword ptr [rcx]
determine_free_finalizers_after_mark:
	lea	r9,__Nil-8+0
	cmp	rbp,r9
	je	end_finalizers_after_mark

	lea	rax,[r10+rbp]
	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rax]
 else
	mov	esi,dword ptr (bit_set_table2)[rax]
 endif
	test	esi,dword ptr [rdi+rbx*4]
	je	finalizer_not_used_after_mark

	lea	rcx,8[rbp]
	mov	rbp,qword ptr 8[rbp]
	jmp	determine_free_finalizers_after_mark

finalizer_not_used_after_mark:
	mov	qword ptr [rdx],rbp 
	lea	rdx,8[rbp]

	mov	rbp,qword ptr 8[rbp]
	mov	qword ptr [rcx],rbp 
	jmp	determine_free_finalizers_after_mark

end_finalizers_after_mark:
	mov	qword ptr [rdx],rbp 

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_after_mark+0
	test	rax,rax
	je	no_gc_hook_after_mark
	call	rax
no_gc_hook_after_mark:
 endif

	call	add_garbage_collect_time

	mov	rax,qword ptr bit_vector_size+0

	mov	rdi,qword ptr n_allocated_words+0
	add	rdi,qword ptr n_marked_words+0
	shl	rdi,3

	mov	rsi,rax
	shl	rsi,3

	push	rdx 
	push	rax 

	mov	rax,rdi 
	mul	qword ptr heap_size_multiple+0
	shrd	rax,rdx,8
	shr	rdx,8

	mov	rbx,rax 
	test	rdx,rdx 
	
	pop	rax 
	pop	rdx 
	
	je	not_largest_heap

	mov	rbx,qword ptr heap_size_65+0
	shl	rbx,6

not_largest_heap:
	cmp	rbx,rsi 
	jbe	no_larger_heap
	
	mov	rsi,qword ptr heap_size_65+0
	shl	rsi,6
	cmp	rbx,rsi
	jbe	not_larger_than_heap
	mov	rbx,rsi 
not_larger_than_heap:
	mov	rax,rbx 
	shr	rax,3
	mov	qword ptr bit_vector_size+0,rax
no_larger_heap:

	mov	rbp,rax

	mov	rdi,qword ptr heap_vector+0

	shr	rbp,5

	test	al,31
	je	no_extra_word

	mov	dword ptr [rdi+rbp*4],0

no_extra_word:
	sub	rax,qword ptr n_marked_words+0
	shl	rax,3
	mov	qword ptr n_last_heap_free_bytes+0,rax 

	mov	rax,qword ptr n_marked_words+0
	shl	rax,3
	add	qword ptr total_gc_bytes+0,rax

	test	qword ptr flags+0,2
	je	_no_heap_use_message2

	mov	r12,rsp
	and	rsp,-16
 ifdef LINUX
	mov	r13,rsi
	mov	r14,rdi

	lea	rdi,marked_gc_string_1+0
 else
	sub	rsp,32

	lea	rcx,marked_gc_string_1
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rdi,qword ptr n_marked_words+0
	shl	rdi,3
 else
	mov	rcx,qword ptr n_marked_words
	shl	rcx,3
 endif
	call	ew_print_int

 ifdef LINUX
	lea	rdi,heap_use_after_gc_string_2+0
 else
	lea	rcx,heap_use_after_gc_string_2
 endif
	call	ew_print_string

 ifdef LINUX
	mov	rsi,r13
	mov	rdi,r14
 endif
	mov	rsp,r12

_no_heap_use_message2:
	call	call_finalizers

	mov	rsi,qword ptr n_allocated_words+0
	xor	rbx,rbx 

	mov	rcx,rdi
	mov	qword ptr n_free_words_after_mark+0,rbx

_scan_bits:
	cmp	ebx,dword ptr [rcx]
	je	_zero_bits
	mov	dword ptr [rcx],ebx 
	add	rcx,4
	sub	rbp,1
	jne	_scan_bits

	jmp	_end_scan

_zero_bits:
	lea	rdx,4[rcx]
	add	rcx,4
	sub	rbp,1
	jne	_skip_zero_bits_lp1
	jmp	_end_bits

_skip_zero_bits_lp:
	test	rax,rax 
	jne	_end_zero_bits
_skip_zero_bits_lp1:
	mov	eax,dword ptr [rcx]
	add	rcx,4
	sub	rbp,1
	jne	_skip_zero_bits_lp

	test	rax,rax
	je	_end_bits
	mov	rax,rcx
	mov	dword ptr (-4)[rcx],ebx
	sub	rax,rdx
	jmp	_end_bits2	

_end_zero_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	shl	rax,3
	add	qword ptr n_free_words_after_mark+0,rax
	mov	dword ptr (-4)[rcx],ebx

	cmp	rax,rsi
	jb	_scan_bits

_found_free_memory:
	mov	qword ptr bit_counter+0,rbp
	mov	qword ptr bit_vector_p+0,rcx

	lea	rbx,(-4)[rdx]
	sub	rbx,rdi 
	shl	rbx,6
	mov	rdi,qword ptr heap_p3+0
	add	rdi,rbx 

	mov	r15,rax
	lea	rbx,[rdi+rax*8]

	sub	r15,rsi
	mov	rsi,qword ptr stack_top+0

	mov	qword ptr heap_end_after_gc+0,rbx 

	jmp	restore_registers_after_gc_and_return

_end_bits:
	mov	rax,rcx 
	sub	rax,rdx 
	add	rax,4
_end_bits2:
	shl	rax,3
	add	qword ptr n_free_words_after_mark+0,rax
	cmp	rax,rsi 
	jae	_found_free_memory

_end_scan:
	mov	qword ptr bit_counter+0,rbp
	jmp	compact_gc

; %rbp : pointer to stack element
; %rdi : heap_vector
; %rax ,%rbx ,%rcx ,%rdx ,%rsi : free

_mark_stack_nodes:
	cmp	rbp,r12
	je	_end_mark_nodes
_mark_stack_nodes_:
	mov	rcx,qword ptr [rbp]

	add	rbp,8
	lea	rdx,[r10+rcx]

	cmp	rdx,r11
	jnc	_mark_stack_nodes

	mov	rbx,rdx
	and	rdx,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif

	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_stack_nodes

	push	rbp
	push	0
	jmp	_mark_arguments

_mark_hnf_2:
	cmp	rsi,20000000h
	jbe	fits_in_word_6
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_6:
	add	r14,3

_mark_record_2_c:
	mov	rbx,qword ptr 8[rcx]
	push	rbx 

	cmp	rsp,r13
	jb	__mark_using_reversal

_mark_node2:
_shared_argument_part:
	mov	rcx,qword ptr [rcx]

_mark_node:
	lea	rdx,[r10+rcx]
	cmp	rdx,r11
	jnc	_mark_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif

	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_next_node

_mark_arguments:
	mov	rax,qword ptr [rcx]
	test	rax,2
	je	_mark_lazy_node
	
	movzx	rbp,word ptr (-2)[rax]

	test	rbp,rbp
	je	_mark_hnf_0

	or	dword ptr [rdi+rbx*4],esi 
	add	rcx,8

	cmp	rbp,256
	jae	_mark_record

	sub	rbp,2
	je	_mark_hnf_2
	jb	_mark_hnf_1

_mark_hnf_3:
	mov	rdx,qword ptr 8[rcx]

	cmp	rsi,20000000h
	jbe	fits_in_word_1
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_1:	

	add	r14,3
	lea	rax,[r10+rdx]
	mov	rbx,rax
	
	and	rax,31*8
	shr	rbx,8

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rax]
 else
	mov	esi,dword ptr (bit_set_table2)[rax]
 endif

	test	esi,dword ptr [rdi+rbx*4]
	jne	_shared_argument_part

_no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],esi 
	add	rbp,1

	add	r14,rbp 
	lea	rax,[rax+rbp*8]
	lea	rdx,(-8)[rdx+rbp*8]

	cmp	rax,32*8
	jbe	fits_in_word_2
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_2:

	mov	rbx,qword ptr [rdx]
	sub	rbp,2
	push	rbx 

_push_hnf_args:
	mov	rbx,qword ptr (-8)[rdx]
	sub	rdx,8
	push	rbx 
	sub	rbp,1
	jge	_push_hnf_args

	cmp	rsp,r13
	jae	_mark_node2

	jmp	__mark_using_reversal

_mark_hnf_1:
	cmp	rsi,40000000h
	jbe	fits_in_word_4
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_4:
	add	r14,2
	mov	rcx,qword ptr [rcx]
	jmp	_mark_node

_mark_lazy_node_1:
	add	rcx,8
	or	dword ptr [rdi+rbx*4],esi 
	cmp	rsi,20000000h
	jbe	fits_in_word_3
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_3:
	add	r14,3

	cmp	rbp,1
	je	_mark_node2

_mark_selector_node_1:
	add	rbp,2
	mov	rdx,qword ptr [rcx]
	je	_mark_indirection_node

	lea	rsi,[r10+rdx]
	mov	rbx,rsi 

	shr	rbx,8
	and	rsi,31*8

	add	rbp,1

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rsi]
 else
	mov	esi,dword ptr (bit_set_table2)[rsi]
 endif
	jle	_mark_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	_mark_node3

	cmp	word ptr (-2)[rbp],2
	jbe	_small_tuple_or_record

_large_tuple_or_record:
	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	r8,bit_set_table2+0
	mov	ebp,dword ptr [r8+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	_mark_node3

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
  else
	mov	eax,(-8)[rax]
  endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	rbp,rcx

	cmp	rax,16
	jl	_mark_tuple_selector_node_1
	mov	rdx,r9
	je	_mark_tuple_selector_node_2
	mov	rcx,qword ptr (-24)[r9+rax]
	mov	qword ptr [rbp],rcx
	jmp	_mark_node

_mark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [rbp],rcx
	jmp	_mark_node	
 endif

_small_tuple_or_record:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
  else
	mov	eax,(-8)[rax]
  endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	rbp,rcx
_mark_tuple_selector_node_1:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx	
 else
	mov	eax,(-8)[rax]
	push	rcx
	mov	rcx,rdx
	mov	eax,4[rax]
	call	near ptr rax
	pop	rdx 

	lea	r9,e__system__nind
	mov	qword ptr (-8)[rdx],r9
	mov	qword ptr [rdx],rcx 
 endif
	jmp	_mark_node

_mark_record_selector_node_1:
	je	_mark_strict_record_selector_node_1

	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	_mark_node3

	cmp	word ptr (-2)[rbp],258
	jbe	_small_tuple_or_record
 ifdef NEW_DESCRIPTORS
	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	r8,bit_set_table2+0
	mov	ebp,dword ptr [r8+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	_mark_node3

  ifdef PIC
	movsxd	rbp,dword ptr(-8)[rax]
	add	rax,rbp
  else
	mov	eax,(-8)[rax]
  endif
	lea	rbp,e__system__nind+0
	mov	qword ptr (-8)[rcx],rbp
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	rbp,rcx

	cmp	rax,16
	jle	_mark_record_selector_node_2
	mov	rdx,r9
	sub	rax,24
_mark_record_selector_node_2:
	mov	rcx,qword ptr [rdx+rax]
	mov	qword ptr [rbp],rcx
	jmp	_mark_node
 else
	jmp	_large_tuple_or_record
 endif

_mark_strict_record_selector_node_1:
	test	esi,dword ptr [rdi+rbx*4]
	jne	_mark_node3

	mov	rbp,qword ptr [rdx]
	test	rbp,2
	je	_mark_node3

	cmp	word ptr (-2)[rbp],258
	jbe	_select_from_small_record

	mov	rbp,qword ptr 16[rdx]
	mov	r9,rbp

	add	rbp,r10
	mov	rbx,rbp 
	and	rbp,31*8
	shr	rbx,8
 ifdef PIC
	lea	r8,bit_set_table2+0
	mov	ebp,dword ptr [r8+rbp]
 else
	mov	ebp,dword ptr (bit_set_table2)[rbp]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	jne	_mark_node3

_select_from_small_record:
 ifdef PIC
	movsxd	rbx,dword ptr (-8)[rax]
	add	rax,rbx
 else
	mov	eax,dword ptr (-8)[rax]
 endif
	sub	rcx,8

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movzx	ebx,word ptr (4-8)[rax]
  else
	movzx	ebx,word ptr 4[rax]
  endif
	cmp	rbx,16
	jle	_mark_strict_record_selector_node_2
	mov	rbx,qword ptr (-24)[r9+rbx]
	jmp	_mark_strict_record_selector_node_3
_mark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rdx+rbx]
_mark_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rbx

  ifdef PIC
	movzx	ebx,word ptr (6-8)[rax]
  else
	movzx	ebx,word ptr 6[rax]
  endif
	test	rbx,rbx
	je	_mark_strict_record_selector_node_5
	cmp	rbx,16
	jle	_mark_strict_record_selector_node_4
	mov	rdx,r9
	sub	rbx,24
_mark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rdx+rbx]
	mov	qword ptr 16[rcx],rbx
_mark_strict_record_selector_node_5:

  ifdef PIC
	mov	rax,qword ptr ((-8)-8)[rax]
  else
	mov	rax,qword ptr (-8)[rax]
  endif
	mov	qword ptr [rcx],rax
 else
	mov	eax,4[rax]
	call	near ptr rax
 endif
	jmp	_mark_next_node

_mark_indirection_node:
_mark_node3:
	mov	rcx,rdx 
	jmp	_mark_node

_mark_next_node:
	pop	rcx 
	test	rcx,rcx 
	jne	_mark_node

	pop	rbp 
	cmp	rbp,r12
	jne	_mark_stack_nodes_

_end_mark_nodes:
	ret

_mark_lazy_node:
	movsxd	rbp,dword ptr (-4)[rax]
	test	rbp,rbp 
	je	_mark_node2_bb

	cmp	rbp,1
	jle	_mark_lazy_node_1

	cmp	rbp,256
	jge	_mark_closure_with_unboxed_arguments
	inc	rbp
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]
	lea	rcx,[rcx+rbp*8]

	cmp	rdx,32*8
	jbe	fits_in_word_7
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_7:
	sub	rbp,3
_push_lazy_args:
	mov	rbx,qword ptr (-8)[rcx]
	sub	rcx,8
	push	rbx
	sub	rbp,1
	jge	_push_lazy_args

	sub	rcx,8

	cmp	rsp,r13
	jae	_mark_node2
	
	jmp	__mark_using_reversal

_mark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255
	sub	rbp,1
	je	_mark_node2_bb

	shr	rax,8
	add	rbp,2

	or	dword ptr [rdi+rbx*4],esi 
	add	r14,rbp 
	lea	rdx,[rdx+rbp*8]

	sub	rbp,rax

	cmp	rdx,32*8
	jbe	fits_in_word_7_
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_7_:
	sub	rbp,2
	jl	_mark_next_node

	lea	rcx,16[rcx+rbp*8]
	jne	_push_lazy_args

_mark_closure_with_one_boxed_argument:
	mov	rcx,qword ptr (-8)[rcx]
	jmp	_mark_node

_mark_hnf_0:
	lea	r9,__STRING__+2+0
	cmp	rax,r9
	jbe	_mark_string_or_array

	or	dword ptr [rdi+rbx*4],esi 

	lea	r9,CHAR+2+0
	cmp	rax,r9
	ja	_mark_normal_hnf_0

_mark_real_int_bool_or_char:
	add	r14,2

	cmp	rsi,40000000h
	jbe	_mark_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	_mark_next_node

 ifdef PIC
_mark_normal_hnf_0_:
	or	dword ptr [rdi+rbx*4],esi
 endif

_mark_normal_hnf_0:
	inc	r14
	jmp	_mark_next_node

_mark_node2_bb:
	or	dword ptr [rdi+rbx*4],esi 
	add	r14,3

	cmp	rsi,20000000h
	jbe	_mark_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	_mark_next_node

_mark_record:
	sub	rbp,258
	je	_mark_record_2
	jl	_mark_record_1

_mark_record_3:
	add	r14,3

	cmp	rsi,20000000h
	jbe	fits_in_word_13
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_13:
	mov	rdx,qword ptr 8[rcx]

	movzx	rbx,word ptr (-2+2)[rax]
	lea	rsi,[r10+rdx]

	mov	rax,rsi 
	and	rsi,31*8

	shr	rax,8
	sub	rbx,1

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rsi]
 else
	mov	edx,dword ptr (bit_set_table2)[rsi]
 endif
	jb	_mark_record_3_bb

	test	edx,dword ptr [rdi+rax*4]
	jne	_mark_node2

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]

	cmp	rsi,32*8
	jbe	_push_record_arguments
	or	dword ptr 4[rdi+rax*4],1
_push_record_arguments:
	mov	rdx,qword ptr 8[rcx]
	mov	rbp,rbx 
	shl	rbx,3
	add	rdx,rbx 
	sub	rbp,1
	jge	_push_hnf_args

	jmp	_mark_node2

_mark_record_3_bb:
	test	edx,dword ptr [rdi+rax*4]
	jne	_mark_next_node

	add	rbp,1
	or	dword ptr [rdi+rax*4],edx 
	add	r14,rbp 
	lea	rsi,[rsi+rbp*8]
	
	cmp	rsi,32*8
	jbe	_mark_next_node

	or	dword ptr 4[rdi+rax*4],1
	jmp	_mark_next_node

_mark_record_2:
	cmp	rsi,20000000h
	jbe	fits_in_word_12
	or	dword ptr 4[rdi+rbx*4],1
fits_in_word_12:
	add	r14,3

	cmp	word ptr (-2+2)[rax],1
	ja	_mark_record_2_c
	je	_mark_node2
	jmp	_mark_next_node

_mark_record_1:
	cmp	word ptr (-2+2)[rax],0
	jne	_mark_hnf_1

	jmp	_mark_real_int_bool_or_char

_mark_string_or_array:
	je	_mark_string_

 ifdef PIC
	lea	r9,__ARRAY__+2+0
	cmp	rax,r9
	jb	_mark_normal_hnf_0_
 endif

_mark_array:
	mov	rbp,qword ptr 16[rcx]
	test	rbp,rbp
	je	_mark_lazy_array

	movzx	rax,word ptr (-2)[rbp]

	test	rax,rax 
	je	_mark_strict_basic_array

	movzx	rbp,word ptr (-2+2)[rbp]
	test	rbp,rbp 
	je	_mark_b_record_array

	cmp	rsp,r13
	jb	_mark_array_using_reversal

	sub	rax,256
	cmp	rax,rbp 
	je	_mark_a_record_array

_mark_ab_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr 8[rcx]

	imul	rax,rbp 
	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	jae	_end_set_ab_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_ab_array_bits

_mark_ab_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	jb	_mark_ab_array_lp

_last_ab_array_bits:
	or	dword ptr [rdi+rbx*4],ebp 

_end_set_ab_array_bits:
	mov	rax,qword ptr 8[rcx]
	mov	rdx,qword ptr 16[rcx]
	movzx	rbx,word ptr (-2+2)[rdx]
	movzx	rdx,word ptr (-2)[rdx]
	shl	rbx,3
	lea	rdx,(-2048)[rdx*8]
	push	rbx
	push	rdx
	lea	rbp,24[rcx]
	push	r12
	jmp	_mark_ab_array_begin
	
_mark_ab_array:
	mov	rbx,qword ptr 16[rsp]
	push	rax
	push	rbp
	lea	r12,[rbp+rbx]

	call	_mark_stack_nodes

	mov	rbx,qword ptr (8+16)[rsp]
	pop	rbp
	pop	rax
	add	rbp,rbx 
_mark_ab_array_begin:
	sub	rax,1
	jnc	_mark_ab_array

	pop	r12
	add	rsp,16
	jmp	_mark_next_node

_mark_a_record_array:
	or	dword ptr [rdi+rbx*4],esi 
	mov	rbp,qword ptr 8[rcx]

	imul	rax,rbp 
	push	rax

	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	_end_set_a_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_a_array_bits

_mark_a_array_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx 
	cmp	rbx,rax
	jb	_mark_a_array_lp

_last_a_array_bits:
	or	dword ptr [rdi+rbx*4],ebp

_end_set_a_array_bits:
	pop	rax 
	lea	rbp,24[rcx]

	push	r12
	lea	r12,24[rcx+rax*8]

	call	_mark_stack_nodes

	pop	r12
	jmp	_mark_next_node

_mark_lazy_array:
	cmp	rsp,r13
	jb	_mark_array_using_reversal

	or	dword ptr [rdi+rbx*4],esi 
	mov	rax,qword ptr 8[rcx]

	add	rax,3

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	_end_set_lazy_array_bits

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_lazy_array_bits

_mark_lazy_array_lp:
	or	dword ptr [rdi+rbx*4],ebp
	inc	rbx
	cmp	rbx,rax
	jb	_mark_lazy_array_lp

_last_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],ebp

_end_set_lazy_array_bits:
	mov	rax,qword ptr 8[rcx]
	lea	rbp,24[rcx]

	push	r12
	lea	r12,24[rcx+rax*8]

	call	_mark_stack_nodes

	pop	r12
	jmp	_mark_next_node

_mark_array_using_reversal:
	push	0
	mov	rsi,1
	jmp	__mark_node

_mark_strict_basic_array:
	mov	rax,qword ptr 8[rcx]
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset dINT+2
 endif
	jle	_mark_strict_int_or_real_array
 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset BOOL+2
 endif
	je	_mark_strict_bool_array
_mark_strict_int32_or_real32_array:
	add	rax,6+1
	shr	rax,1
	jmp	_mark_basic_array_
_mark_strict_int_or_real_array:
	add	rax,3
	jmp	_mark_basic_array_
_mark_strict_bool_array:
	add	rax,24+7
	shr	rax,3
	jmp	_mark_basic_array_

_mark_b_record_array:
	mov	rbp,qword ptr 8[rcx]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	_mark_basic_array_

_mark_string_:
	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	shr	rax,3

_mark_basic_array_:
	or	dword ptr [rdi+rbx*4],esi 

	add	r14,rax 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8
	
	cmp	rbx,rax 
	jae	_mark_next_node

	inc	rbx 
	mov	rbp,1
	cmp	rbx,rax 
	jae	_last_string_bits

_mark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	jb	_mark_string_lp

_last_string_bits:
	or	dword ptr [rdi+rbx*4],ebp 
	jmp	_mark_next_node

__end_mark_using_reversal:
	pop	rdx 
	test	rdx,rdx 
	je	_mark_next_node
	mov	qword ptr [rdx],rcx 
	jmp	_mark_next_node

__mark_using_reversal:
	push	rcx 
	mov	rsi,1
	mov	rcx,qword ptr [rcx]
	jmp	__mark_node

__mark_arguments:
	mov	rax,qword ptr [rcx]
	test	al,2
	je	__mark_lazy_node

	movzx	rbp,word ptr (-2)[rax]
	test	rbp,rbp 
	je	__mark_hnf_0

	add	rcx,8

	cmp	rbp,256
	jae	__mark__record

	sub	rbp,2
	je	__mark_hnf_2
	jb	__mark_hnf_1

__mark_hnf_3:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx

	cmp	rdx,20000000h

	mov	rax,qword ptr 8[rcx]

	jbe	fits__in__word__1
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word__1:
	add	rax,r10

	mov	rbx,rax 
	and	rax,31*8

	shr	rbx,8

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rax]
 else
	mov	edx,dword ptr (bit_set_table2)[rax]
 endif
	test	edx,dword ptr [rdi+rbx*4]
	jne	__shared_argument_part

__no_shared_argument_part:
	or	dword ptr [rdi+rbx*4],edx 
	mov	rdx,qword ptr 8[rcx]

	add	rbp,1
	mov	qword ptr 8[rcx],rsi 

	add	r14,rbp 
	add	rcx,8

	shl	rbp,3
	or	qword ptr [rdx],1

	add	rax,rbp
	add	rdx,rbp

	cmp	rax,32*8
	jbe	fits__in__word__2
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word__2:

	mov	rbp ,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rcx 
	lea	rsi,(-8)[rdx]
	mov	rcx,rbp 
	jmp	__mark_node

__mark_hnf_1:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,40000000h
	jbe	__shared_argument_part
	or	dword ptr 4[rdi+rbx*4],1
__shared_argument_part:
	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi
	lea	rsi,2[rcx]
	mov	rcx,rbp 
	jmp	__mark_node

__mark_no_selector_2:
	pop	rbx
__mark_no_selector_1:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	__shared_argument_part

	or	dword ptr 4[rdi+rbx*4],1
	jmp	__shared_argument_part

__mark_lazy_node_1:
	je	__mark_no_selector_1

__mark_selector_node_1:
	add	rbp,2
	je	__mark_indirection_node

	add	rbp,1

	push	rbx
	mov	rbp,qword ptr [rcx]
	push	rax 
	lea	rax,[r10+rbp] 

	jle	__mark_record_selector_node_1

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax 
	jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	__mark_no_selector_2

	cmp	word ptr (-2)[rbx],2
	jbe	__small_tuple_or_record

__large_tuple_or_record:
	mov	r8,qword ptr 16[rbp]
 ifndef PIC
	mov	r9,r8
 endif

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]

 ifdef PIC
	mov	r9,qword ptr 16[rbp]
 endif

	jne	__mark_no_selector_2

 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rdx,dword ptr (-8)[rax]
	add	rax,rdx
  else
	mov	eax,dword ptr (-8)[rax]
  endif
	lea	rdx,e__system__nind+0
	pop	rbx

	mov	qword ptr (-8)[rcx],rdx
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	r8,rcx

	cmp	rax,16
	jl	__mark_tuple_selector_node_1
	je	__mark_tuple_selector_node_2
	mov	rcx,qword ptr (-24)[r9+rax]
	mov	qword ptr [r8],rcx
	jmp	__mark_node

__mark_tuple_selector_node_2:
	mov	rcx,qword ptr [r9]
	mov	qword ptr [r8],rcx
	jmp	__mark_node
 endif

__small_tuple_or_record:
 ifdef NEW_DESCRIPTORS
   ifdef PIC
	movsxd	rdx,dword ptr (-8)[rax]
	add	rax,rdx
  else
	mov	eax,dword ptr (-8)[rax]
  endif
	lea	rdx,e__system__nind+0
	pop	rbx 

	mov	qword ptr (-8)[rcx],rdx
  ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
  else
	movzx	eax,word ptr 4[rax]
  endif
	mov	r8,rcx
__mark_tuple_selector_node_1:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	jmp	__mark_node
 else
	mov	eax,(-8)[rax]
	pop	rbx 

	push	rcx 
	mov	rcx,qword ptr [rcx]
	mov	eax,4[rax]
	call	near ptr rax
	pop	rdx

	mov	qword ptr (-8)[rdx],offset e__system__nind
	mov	qword ptr [rdx],rcx 
 endif
	jmp	__mark_node

__mark_record_selector_node_1:
	je	__mark_strict_record_selector_node_1

	mov	rbx,rax 
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx*4]
	pop	rax
	jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	__mark_no_selector_2

	cmp	word ptr (-2)[rbx],258
 ifdef NEW_DESCRIPTORS
	jbe	__small_record

	mov	r8,qword ptr 16[rbp]
 ifndef PIC
	mov	r9,r8
 endif

	add	r8,r10
	mov	rbx,r8
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]

 ifdef PIC
	mov	r9,qword ptr 16[rbp]
 endif

	jne	__mark_no_selector_2

__small_record:
 ifdef PIC
	movsxd	rdx,dword ptr(-8)[rax]
	add	rax,rdx
 else
	mov	eax,(-8)[rax]
 endif
	lea	rdx,e__system__nind+0
	pop	rbx 

	mov	qword ptr (-8)[rcx],rdx
 ifdef PIC
	movzx	eax,word ptr (4-8)[rax]
 else
	movzx	eax,word ptr 4[rax]
 endif
	mov	r8,rcx

	cmp	rax,16
	jle	__mark_record_selector_node_2
	mov	rbp,r9
	sub	rax,24
__mark_record_selector_node_2:
	mov	rcx,qword ptr [rbp+rax]
	mov	qword ptr [r8],rcx
	jmp	__mark_node
 else
	jbe	__small_tuple_or_record
	jmp	__large_tuple_or_record
 endif

__mark_strict_record_selector_node_1:
	mov	rbx,rax
	and	rax,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	eax,dword ptr [r9+rax]
 else
	mov	eax,dword ptr (bit_set_table2)[rax]
 endif
	test	eax,dword ptr [rdi+rbx *4]
	pop	rax 
	jne	__mark_no_selector_2

	mov	rbx,qword ptr [rbp]
	test	bl,2
	je	__mark_no_selector_2

	cmp	word ptr (-2)[rbx],258
	jle	__select_from_small_record

	mov	r8,qword ptr 16[rbp]
 ifndef PIC
	mov	r9,r8
 endif

	add	r8,r10
	mov	rbx,r8 
	and	r8,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	r8d,dword ptr [r9+r8]
 else
	mov	r8d,dword ptr (bit_set_table2)[r8]
 endif
	test	r8d,dword ptr [rdi+rbx*4]

 ifdef PIC
	mov	r9,qword ptr 16[rbp]
 endif

	jne	__mark_no_selector_2

__select_from_small_record:
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movsxd	rbx,dword ptr(-8)[rax]
	add	rax,rbx
  else
	mov	eax,(-8)[rax]
  endif
	sub	rcx,8

  ifdef PIC
	movzx	ebx,word ptr (4-8)[rax]
  else
	movzx	ebx,word ptr 4[rax]
  endif
	cmp	rbx,16
	jle	__mark_strict_record_selector_node_2
	mov	rbx,qword ptr (-24)[r9+rbx]
	jmp	__mark_strict_record_selector_node_3
__mark_strict_record_selector_node_2:
	mov	rbx,qword ptr [rbp+rbx]
__mark_strict_record_selector_node_3:
	mov	qword ptr 8[rcx],rbx

  ifdef PIC
	movzx	ebx,word ptr (6-8)[rax]
  else
	movzx	ebx,word ptr 6[rax]
  endif
	test	rbx,rbx
	je	__mark_strict_record_selector_node_5
	cmp	rbx,16
	jle	__mark_strict_record_selector_node_4
	mov	rbp,r9
	sub	rbx,24
__mark_strict_record_selector_node_4:
	mov	rbx,qword ptr [rbp+rbx]
	mov	qword ptr 16[rcx],rbx
__mark_strict_record_selector_node_5:
	pop	rbx

  ifdef PIC
	mov	rax,qword ptr ((-8)-8)[rax]
  else
	mov	rax,qword ptr (-8)[rax]
  endif
	mov	qword ptr [rcx],rax
 else
	mov	eax,(-8)[rax]
	pop	rbx
	mov	rdx,qword ptr [rcx]
	sub	rcx,8
	mov	eax,4[rax]
	call	near ptr rax
 endif
	jmp	__mark_node

__mark_indirection_node:
	mov	rcx,qword ptr [rcx]
	jmp	__mark_node

__mark_hnf_2:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx
	cmp	rdx,20000000h
	jbe	fits__in__word__6
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word__6:

__mark_record_2_c:
	mov	rax,qword ptr [rcx]
	mov	rbp,qword ptr 8[rcx]
	or	rax,2
	mov	qword ptr 8[rcx],rsi 
	mov	qword ptr [rcx],rax 
	lea	rsi,8[rcx]
	mov	rcx,rbp

__mark_node:
	lea	rdx,[r10+rcx]
	cmp	rdx,r11
	jae	__mark_next_node

	mov	rbx,rdx 
	and	rdx,31*8
	shr	rbx,8
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	ebp,dword ptr [r9+rdx]
 else
	mov	ebp,dword ptr (bit_set_table2)[rdx]
 endif
	test	ebp,dword ptr [rdi+rbx*4]
	je	__mark_arguments

__mark_next_node:
	test	rsi,3
	jne	__mark_parent

	mov	rbp,qword ptr (-8)[rsi]
	mov	rdx,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 
	mov	qword ptr (-8)[rsi],rdx 
	sub	rsi,8

	mov	rcx,rbp 
	and	rbp,3
	and	rcx,-4
	or	rsi,rbp 
	jmp	__mark_node

__mark_parent:
	mov	rbx,rsi 
	and	rsi,-4
	je	__end_mark_using_reversal

	and	rbx,3
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rsi],rcx 

	sub	rbx,1
	je	__argument_part_parent
	
	lea	rcx,(-8)[rsi]
	mov	rsi,rbp 
	jmp	__mark_next_node

__argument_part_parent:
	and	rbp,-4
	mov	rdx,rsi 
	mov	rcx,qword ptr (-8)[rbp]
	mov	rbx,qword ptr [rbp]
	mov	qword ptr (-8)[rbp],rbx 
	mov	qword ptr [rbp],rdx 
	lea	rsi,(2-8)[rbp]
	jmp	__mark_node

__mark_lazy_node:
	movsxd	rbp,dword ptr(-4)[rax]
	test	rbp,rbp 
	je	__mark_node2_bb

	add	rcx,8
	cmp	rbp,1
	jle	__mark_lazy_node_1
	cmp	rbp,256
	jge	__mark_closure_with_unboxed_arguments

	add	rbp,1
	mov	rax,rdx 
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,rbp

	lea	rax,[rax+rbp*8]
	sub	rbp,2

	or	dword ptr [rdi+rbx*4],edx 

	cmp	rax,32*8
	jbe	fits__in__word__7
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word__7:
__mark_closure_with_unboxed_arguments__2:
	lea	rdx,[rcx+rbp*8]
	mov	rax,qword ptr [rcx]
	or	rax,2
	mov	qword ptr [rcx],rax 
	mov	rcx,qword ptr [rdx]
	mov	qword ptr [rdx],rsi 
	mov	rsi,rdx 
	jmp	__mark_node

__mark_closure_with_unboxed_arguments:
	mov	rax,rbp 
	and	rbp,255

	sub	rbp,1
	je	__mark_closure_1_with_unboxed_argument
	add	rbp,2

	shr	rax,8
	add	r14,rbp 

	push	rcx 
	lea	rcx,[rdx+rbp*8]

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	sub	rbp,rax 

	or	dword ptr [rdi+rbx*4],edx 
	cmp	rcx,32*8
	jbe	fits__in_word_7_
	or	dword ptr 4[rdi+rbx*4],1
fits__in_word_7_:
	pop	rcx 
	sub	rbp,2
	jg	__mark_closure_with_unboxed_arguments__2
	je	__shared_argument_part
	sub	rcx,8
	jmp	__mark_next_node

__mark_closure_1_with_unboxed_argument:
	sub	rcx,8
	jmp	__mark_node2_bb

__mark_hnf_0:
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rax,r9
 else
	cmp	rax,offset dINT+2
 endif
	jne	__no_int_3

	mov	rbp,qword ptr 8[rcx]
	cmp	rbp,33
	jb	____small_int

__mark_real_bool_or_small_string:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,2
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,40000000h
	jbe	__mark_next_node
	or	dword ptr 4[rdi+rbx*4],1
	jmp	__mark_next_node

____small_int:
	shl	rbp,4
 ifdef PIC
	lea	rcx,small_integers+0
	add	rcx,rbp
 else
	lea	rcx,(small_integers)[rbp]
 endif
	jmp	__mark_next_node

__no_int_3:
 ifdef PIC
	lea	r9,__STRING__+2+0
	cmp	rax,r9
 else
	cmp	rax,offset __STRING__+2
 endif
	jbe	__mark_string_or_array

 ifdef PIC
 	lea	r9,CHAR+2+0
 	cmp	rax,r9
 else
	cmp	rax,offset CHAR+2
 endif
 	jne	__no_char_3

	movzx	rbp,byte ptr 8[rcx]
	shl	rbp,4
 ifdef PIC
	lea	rcx,static_characters+0
	add	rcx,rbp
 else
	lea	rcx,(static_characters)[rbp]
 endif
	jmp	__mark_next_node

__no_char_3:
	jb	__mark_real_bool_or_small_string

 ifdef PIC
__mark_normal_hnf_0:
 endif

 ifdef NEW_DESCRIPTORS
	lea	rcx,((-8)-2)[rax]
 else
	lea	rcx,((-12)-2)[rax]
 endif
	jmp	__mark_next_node

__mark_node2_bb:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3

	or	dword ptr [rdi+rbx*4],edx

	cmp	rdx,20000000h
	jbe	__mark_next_node

	or	dword ptr 4[rdi+rbx*4],1
	jmp	__mark_next_node

__mark__record:
	sub	rbp,258
	je	__mark_record_2
	jl	__mark_record_1

__mark_record_3:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	fits__in__word__13
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word__13:
	movzx	rbx,word ptr (-2+2)[rax]

	mov	rdx,qword ptr 8[rcx]
	add	rdx,r10
	mov	rax,rdx 
	and	rdx,31*8
	shr	rax,8

	push	rsi 

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	esi,dword ptr [r9+rdx]
 else
	mov	esi,dword ptr (bit_set_table2)[rdx]
 endif
	test	esi,dword ptr [rdi+rax*4]
	jne	__shared_record_argument_part

	add	rbp,1
	or	dword ptr [rdi+rax *4],esi

	lea	rdx,[rdx+rbp*8]
	add	r14,rbp 

	pop	rsi 

	cmp	rdx,32*8
	jbe	fits__in__word__14
	or	dword ptr 4[rdi+rax*4],1
fits__in__word__14:
	sub	rbx,1
	mov	rdx,qword ptr 8[rcx]
	jl	__mark_record_3_bb
	je	__shared_argument_part

	mov	qword ptr 8[rcx],rsi 
	add	rcx,8

	sub	rbx,1
	je	__mark_record_3_aab

	lea	rsi,[rdx+rbx*8]
	mov	rax,qword ptr [rdx]
	or	rax,1
	mov	rbp,qword ptr [rsi]
	mov	qword ptr [rdx],rax 
	mov	qword ptr [rsi],rcx 
	mov	rcx,rbp 
	jmp	__mark_node

__mark_record_3_bb:
	sub	rcx,8
	jmp	__mark_next_node

__mark_record_3_aab:
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdx],rcx 
	lea	rsi,1[rdx]
	mov	rcx,rbp 
	jmp	__mark_node

__shared_record_argument_part:
	mov	rdx,qword ptr 8[rcx]

	pop	rsi

	test	rbx,rbx 
	jne	__shared_argument_part
	sub	rcx,8
	jmp	__mark_next_node

__mark_record_2:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,3
	or	dword ptr [rdi+rbx*4],edx 
	cmp	rdx,20000000h
	jbe	fits__in__word_12
	or	dword ptr 4[rdi+rbx*4],1
fits__in__word_12:
	cmp	word ptr (-2+2)[rax],1
	ja	__mark_record_2_c
	je	__shared_argument_part
	sub	rcx,8
	jmp	__mark_next_node

__mark_record_1:
	cmp	word ptr (-2+2)[rax],0
	jne	__mark_hnf_1
	sub	rcx,8
	jmp	__mark_real_bool_or_small_string

__mark_string_or_array:
	je	__mark_string_

 ifdef PIC
	lea	r9,__ARRAY__+2+0
	cmp	rax,r9
	jb	__mark_normal_hnf_0
 endif

__mark_array:
	mov	rbp,qword ptr 16[rcx]
	test	rbp,rbp 
	je	__mark_lazy_array

	movzx	rax,word ptr (-2)[rbp]
	test	rax,rax 
	je	__mark_strict_basic_array

	movzx	rbp,word ptr (-2+2)[rbp]
	test	rbp,rbp 
	je	__mark_b_record_array

	sub	rax,256
	cmp	rax,rbp 
	je	__mark_a_record_array

__mark__ab__record__array:
	push	rdx 
	push	rbx 
	mov	rbx,rbp 

	mov	rbp,qword ptr 8[rcx]
	add	rcx,16
	push	rcx 

	shl	rbp,3
	mov	rdx,rax 
	imul	rdx,rbp 

	sub	rax,rbx 
	add	rcx,8
	add	rdx,rcx 

	call	reorder
	
	pop	rcx 

	xchg	rax,rbx 
	mov	rbp,qword ptr (-8)[rcx]
	imul	rax,rbp 
	imul	rbx,rbp 
	add	r14,rbx 
	add	rbx,rax 

	shl	rbx,3
	lea	rbp,[r10+rcx]
	add	rbp,rbx 

	pop	rbx 
	pop	rdx 

 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	or	dword ptr [rdi+rbx*4],edx

	lea	rdx,[rcx+rax*8]
	jmp	__mark_r_array

__mark_a_record_array:
	imul	rax,qword ptr 8[rcx]
	add	rcx,16
	jmp	__mark_lr_array

__mark_lazy_array:
	mov	rax,qword ptr 8[rcx]
	add	rcx,16

__mark_lr_array:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	mov	rbp,r10
	or	dword ptr [rdi+rbx*4],edx 
	lea	rdx,[rcx+rax*8]
	add	rbp,rdx 
__mark_r_array:
	shr	rbp,8

	cmp	rbx,rbp 
	jae	__skip_mark_lazy_array_bits

	inc	rbx 

__mark_lazy_array_bits:
	or	dword ptr [rdi+rbx*4],1
	inc	rbx
	cmp	rbx,rbp 
	jbe	__mark_lazy_array_bits

__skip_mark_lazy_array_bits:
	add	r14,3
	add	r14,rax 

	cmp	rax,1
	jbe	__mark_array_length_0_1

	mov	rbp,qword ptr [rdx]
	mov	rbx,qword ptr [rcx]
	mov	qword ptr [rdx],rbx 
	mov	qword ptr [rcx],rbp 
	
	mov	rbp,qword ptr (-8)[rdx]
	sub	rdx,8
	mov	rbx,qword ptr lazy_array_list+0
	add	rbp,2
	mov	qword ptr [rdx],rbx 
	mov	qword ptr (-8)[rcx],rbp 
	mov	qword ptr (-16)[rcx],rax 
	sub	rcx,16
	mov	qword ptr lazy_array_list+0,rcx 

	mov	rcx,qword ptr (-8)[rdx]
	mov	qword ptr (-8)[rdx],rsi 
	lea	rsi,(-8)[rdx]
	jmp	__mark_node

__mark_array_length_0_1:
	lea	rcx,(-16)[rcx]
	jb	__mark_next_node

	mov	rbx,qword ptr 24[rcx]
	mov	rbp,qword ptr 16[rcx]
	mov	rdx,qword ptr lazy_array_list+0
	mov	qword ptr 24[rcx],rbp 
	mov	qword ptr 16[rcx],rdx 
	mov	qword ptr [rcx],rax
	mov	qword ptr lazy_array_list+0,rcx
	mov	qword ptr 8[rcx],rbx
	add	rcx,8

	mov	rbp,qword ptr [rcx]
	mov	qword ptr [rcx],rsi 
	lea	rsi,2[rcx]
	mov	rcx,rbp 
	jmp	__mark_node

__mark_b_record_array:
	mov	rbp,qword ptr 8[rcx]
	sub	rax,256
	imul	rax,rbp 
	add	rax,3
	jmp	__mark_basic_array

__mark_strict_basic_array:
	mov	rax,qword ptr 8[rcx]
 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset dINT+2
 endif
	jle	__mark__strict__int__or__real__array
 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rbp,r9
 else
	cmp	rbp,offset BOOL+2
 endif
	je	__mark__strict__bool__array
__mark__strict__int32__or__real32__array:
	add	rax,6+1
	shr	rax,1
	jmp	__mark_basic_array
__mark__strict__int__or__real__array:
	add	rax,3
	jmp	__mark_basic_array
__mark__strict__bool__array:
	add	rax,24+7
	shr	rax,3
	jmp	__mark_basic_array

__mark_string_:
	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	shr	rax,3

__mark_basic_array:
 ifdef PIC
	lea	r9,bit_set_table2+0
	mov	edx,dword ptr [r9+rdx]
 else
	mov	edx,dword ptr (bit_set_table2)[rdx]
 endif
	add	r14,rax 

	or	dword ptr [rdi+rbx*4],edx 
	lea	rax,(-8)[rcx+rax*8]

	add	rax,r10
	shr	rax,8

	cmp	rbx,rax 
	jae	__mark_next_node

	inc	rbx 
	mov	rbp,1

	cmp	rbx,rax 
	jae	__last__string__bits

__mark_string_lp:
	or	dword ptr [rdi+rbx*4],ebp 
	inc	rbx
	cmp	rbx,rax 
	jb	__mark_string_lp

__last__string__bits:
	or	dword ptr [rdi+rbx*4],ebp 
	jmp	__mark_next_node
