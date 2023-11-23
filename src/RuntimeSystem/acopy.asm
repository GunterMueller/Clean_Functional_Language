
COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP = 1

	push	rsi

	mov	rdi,heap_p2+0

	mov	rax,heap_size_257+0
	shl	rax,7
	mov	semi_space_size+0,rax 
	lea	rsi,[rdi+rax]

	mov	qword ptr (heap2_begin_and_end+8)+0,rsi 

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_before_copy+0
	test	rax,rax
	je	no_gc_hook_before_copy
	call	rax
no_gc_hook_before_copy:
 endif

	mov	rax,qword ptr caf_list+0
	test	rax,rax 
	je	end_copy_cafs

copy_cafs_lp:
	push	(-8)[rax]
	
	lea	rbp,8[rax]
	mov	rbx,qword ptr [rax]
	sub	rbx,1
	call	copy_lp2
	
	pop	rax 
	test	rax,rax 
	jne	copy_cafs_lp

end_copy_cafs:
	mov	rbx,qword ptr [rsp]
	mov	rbp,stack_p+0
	sub	rbx,rbp 
	shr	rbx,3

	sub	rbx,1
	jb	end_copy0
	call	copy_lp2
end_copy0:
	mov	rbp,heap_p2+0

	jmp	copy_lp1
;
;	Copy all referenced nodes to the other semi space
;

in_hnf_1_2:
	dec	rbx 
copy_lp2_lp1:
	call	copy_lp2
copy_lp1:
	cmp	rbp,rdi 
	jae	end_copy1

	mov	rax,[rbp]
	add	rbp,8
	test	al,2
	je	not_in_hnf_1
in_hnf_1:
	movzx	rbx,word ptr (-2)[rax]

	test	rbx,rbx 
	je	copy_array_21

	cmp	rbx,2
	jbe	in_hnf_1_2

	cmp	rbx,256
	jae	copy_record_21
	
	mov	rax,8[rbp]

	test	al,1
	jne	node_without_arguments_part

	push	rbx 
	xor	rbx,rbx 
	
	call	copy_lp2

	pop	rbx 
	add	rbp,8

	sub	rbx,2
	jmp	copy_lp2_lp1

node_without_arguments_part:
	dec	rax 
	xor	rbx,rbx 

	mov	8[rbp],rax 
	call	copy_lp2
	
	add	rbp,8
	jmp	copy_lp1

copy_record_21:
	sub	rbx,258
	ja	copy_record_arguments_3

	movzx	rbx,word ptr (-2+2)[rax]
 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	jb	in_hnf_1_2

	sub	rbx,1
	ja	copy_lp2_lp1
	jmp	copy_node_arity1
 else
	jb	copy_record_arguments_1

	sub	rbx,1
	ja	copy_lp2_lp1
	je	copy_node_arity1
	add	rbp,16
	jmp	copy_lp1

copy_record_arguments_1:
	dec	rbx
	jmp	copy_lp2_lp1
	je	copy_lp2_lp1
	add	rbp,8
	jmp	copy_lp1
 endif

copy_record_arguments_3:
	test	byte ptr 8[rbp],1
	jne	record_node_without_arguments_part

	movzx	rdx,word ptr (-2+2)[rax]
 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	sub	rdx,1
 else
	test	rdx,rdx 
	je	copy_record_arguments_3b
	sub	rdx,1
	je	copy_record_arguments_3abb
 endif

	lea	rcx,(3*8)[rbp+rbx*8]
	push	rcx 
	push	rdx 

	sub	rbx,rbx 
	call	copy_lp2
	
	add	rbp,8
	pop	rbx 
	dec	rbx 
	call	copy_lp2

	pop	rbp 
	jmp	copy_lp1

 ife COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_arguments_3abb:
	push	rbx 
	sub	rbx,rbx 
	
	call	copy_lp2
	
	pop	rbx 
	
	lea	rbp,(2*8)[rbp+rbx*8]
	jmp	copy_lp1

copy_record_arguments_3b:
	lea	rbp,(3*8)[rbp+rbx*8]
	jmp	copy_lp1
 endif

record_node_without_arguments_part:
	and	qword ptr 8[rbp],-2

 ife COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr (-2+2)[rax],0
	je	record_node_without_arguments_part_3b
 endif

	sub	rbx,rbx 
	call	copy_lp2

	add	rbp,8
	jmp	copy_lp1

 ife COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
record_node_without_arguments_part_3b:
	add	rbp,16
	jmp	copy_lp1
 endif

not_in_hnf_1:
	movsxd	rbx,dword ptr (-4)[rax]
	cmp	rbx,257
	jge	copy_unboxed_closure_arguments
	sub	rbx,1
	jg	copy_lp2_lp1

copy_node_arity1:
	xor	rbx,rbx 
	call	copy_lp2

	add	rbp,8
	jmp	copy_lp1

copy_unboxed_closure_arguments:
	je	copy_unboxed_closure_arguments1

	xor	rax,rax
	mov	al,bh 
	and	rbx,255
	sub	rbx,rax 

	sub	rbx,1
	jl	copy_unboxed_closure_arguments_without_pointers
	
	push	rax 
	call	copy_lp2
	pop	rax 

copy_unboxed_closure_arguments_without_pointers:
	lea	rbp,[rbp+rax*8]
	jmp	copy_lp1

copy_unboxed_closure_arguments1:
	add	rbp,16
	jmp	copy_lp1

copy_array_21:
	mov	rbx,qword ptr 8[rbp]
	add	rbp,16
	test	rbx,rbx 
	je	copy_array_21_a

	movzx	rax,word ptr (-2)[rbx]
	movzx	rbx,word ptr (-2+2)[rbx]
	sub	rax,256
	test	rbx,rbx 
	je	copy_array_21_b

	cmp	rbx,rax 
	je	copy_array_21_r_a

copy_array_21_ab:
	cmp	qword ptr (-16)[rbp],0
	je	copy_lp1

	sub	rax,rbx 
	shl	rax,3
	sub	rbx,1

	push	rbx 
	push	rax 
	mov	rbx,qword ptr (-16)[rbp]
	sub	rbx,1
	push	rbx 

copy_array_21_lp_ab:
	mov	rbx,qword ptr 16[rsp]
	call	copy_lp2

	add	rbp,qword ptr 8[rsp]
	sub	qword ptr [rsp],1
	jnc	copy_array_21_lp_ab
	
	add	rsp,24
	jmp	copy_lp1

copy_array_21_b:
	mov	rbx,qword ptr (-16)[rbp]
	imul	rbx,rax 
	lea	rbp,[rbp+rbx*8]
	jmp	copy_lp1

copy_array_21_r_a:
	mov	rbx,qword ptr (-16)[rbp]
	imul	rbx,rax
	sub	rbx,1
	jc	copy_lp1
	jmp	copy_lp2_lp1

copy_array_21_a:
	mov	rbx,qword ptr (-16)[rbp]
	sub	rbx,1
	jc	copy_lp1
	jmp	copy_lp2_lp1

;
;	Copy nodes to the other semi-space
;

copy_lp2:
	mov	rdx,qword ptr [rbp]

; selectors:
continue_after_selector_2:
	mov	rcx,qword ptr [rdx]
	test	cl,2
	je	not_in_hnf_2

in_hnf_2:
	movzx	rax,word ptr (-2)[rcx]
	test	rax,rax
	je	copy_arity_0_node2

	cmp	rax,256
	jae	copy_record_2

	sub	rax,2
	mov	[rbp],rdi 

	lea	rbp,8[rbp ]
	ja	copy_hnf_node2_3

	mov	[rdi],rcx
	jb	copy_hnf_node2_1

	inc	rdi
	mov	rcx,8[rdx]

	mov	[rdx],rdi 
	mov	rax,16[rdx]

	sub	rbx,1
	mov	(8-1)[rdi],rcx 

	mov	(16-1)[rdi],rax 
	lea	rdi,(24-1)[rdi]

	jae	copy_lp2
	ret

copy_hnf_node2_1:
	inc	rdi 
	mov	rax,8[rdx]

	sub	rbx,1
	mov	[rdx],rdi

	mov	(8-1)[rdi],rax 
	lea	rdi,(16-1)[rdi]

	jae	copy_lp2
	ret

copy_hnf_node2_3:
	mov	[rdi],rcx 
	inc	rdi 

	mov	[rdx],rdi 
	mov	rcx,8[rdx]

	mov	(8-1)[rdi],rcx 
	mov	rcx,16[rdx]

	add	rdi,24-1
	mov	rdx,[rcx]
	
	test	dl,1
	jne	arguments_already_copied_2

	mov	(-8)[rdi],rdi 
	add	rcx,8

	mov	[rdi],rdx 
	inc	rdi

	mov	(-8)[rcx],rdi 
	add	rdi,8-1

cp_hnf_arg_lp2:
	mov	rdx,[rcx]
	add	rcx,8

	mov	[rdi],rdx 
	add	rdi,8

	dec	rax 
	jne	cp_hnf_arg_lp2

	sub	rbx,1
	jae	copy_lp2
	ret

arguments_already_copied_2:
	mov	(-8)[rdi],rdx 

	sub	rbx,1
	jae	copy_lp2
	ret

copy_arity_0_node2:
 ifdef PIC
	lea	r9,__STRING__+2+0
	cmp	rcx,r9
 else
	cmp	rcx,offset __STRING__+2
 endif
	jbe	copy_string_or_array_2

 ifdef PIC
	lea	r9,CHAR+2+0
	cmp	rcx,r9
 else
	cmp	rcx,offset CHAR+2
 endif
	ja	copy_normal_hnf_0_2

copy_int_bool_or_char_2:
	mov	rax,8[rdx]
	je	copy_char_2

 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rcx,r9
 else
	cmp	rcx,offset dINT+2
 endif
	jne	no_small_int_or_char_2

copy_int_2:
	cmp	rax,33
	jae	no_small_int_or_char_2

	shl	rax,4
	add	rbp,8

 ifdef PIC
	lea	r9,small_integers+0
	add	rax,r9
 else
	add	rax,offset small_integers
 endif
	sub	rbx,1

	mov	(-8)[rbp],rax 
	jae	copy_lp2
	ret

copy_char_2:	
	and	rax,255

	shl	rax,4
	add	rbp,8

 ifdef PIC
	lea	r9,static_characters+0
	add	rax,r9
 else
	add	rax,offset static_characters
 endif
	sub	rbx,1

	mov	(-8)[rbp],rax 
	jae	copy_lp2
	ret
	
no_small_int_or_char_2:
 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_node2_1_b:
 endif
	mov	(-16)[rsi],rcx 
	add	rbp,8

	mov	(-8)[rsi],rax 
	sub	rsi,15

	mov	[rdx],rsi 
	dec	rsi

	mov	(-8)[rbp],rsi 

	sub	rbx,1
	jae	copy_lp2
	ret

copy_normal_hnf_0_2:
 ifdef NEW_DESCRIPTORS
	sub	rcx,2-(-8)
 else
	sub	rcx,2-(-12)
 endif
	sub	rbx,1

	mov	[rbp],rcx 
	lea	rbp,8[rbp]
	jae	copy_lp2
	ret

already_copied_2:
	dec	rcx 
	sub	rbx,1

	mov	[rbp],rcx 
	lea	rbp,8[rbp]

	jae	copy_lp2
	ret

copy_record_2:
	sub	rax,258
	ja	copy_record_node2_3

 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
 	jb	copy_record_node2_1
 
 	cmp	word ptr (-2+2)[rcx],0
	je	copy_record_node2_bb

	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,1[rdi]
	mov	rax,qword ptr 8[rdx]

	mov	qword ptr [rdx],rcx

	mov	qword ptr 8[rdi],rax
	mov	rax,qword ptr 16[rdx]

	add	rbp,8
	mov	qword ptr 16[rdi],rax

	add	rdi,24
	sub	rbx,1
	jae	copy_lp2
	ret

copy_record_node2_1:
	mov	rax,qword ptr 8[rdx]

	cmp	word ptr (-2+2)[rcx],0
	je	copy_record_node2_1_b

	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,1[rdi]
	mov	qword ptr 8[rdi],rax

	mov	qword ptr [rdx],rcx
	add	rbp,8

	add	rdi,16
	sub	rbx,1
	jae	copy_lp2
	ret

copy_record_node2_bb:
	mov	(-24)[rsi],rcx 
	sub	rsi,24-1

	mov	[rdx],rsi 
	dec	rsi 

	mov	rax,8[rdx]
	mov	rcx,16[rdx]

	mov	[rbp],rsi 
	add	rbp,8

	mov	8[rsi],rax 
	sub	rbx,1

	mov	16[rsi],rcx 

	jae	copy_lp2
	ret
 else
	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,1[rdi]
	mov	rax,qword ptr 8[rdx]

	mov	qword ptr [rdx],rcx
	jb	copy_record_node2_1

	mov	qword ptr 8[rdi],rax
	mov	rax,qword ptr 16[rdx]

	add	rbp,8
	mov	qword ptr 16[rdi],rax

	add	rdi,24
	sub	rbx,1
	jae	copy_lp2
	ret

copy_record_node2_1:
	add	rbp,8
	mov	qword ptr 8[rdi],rax 

	add	rdi,16
	sub	rbx,1
	jae	copy_lp2
	ret
 endif

copy_record_node2_3:
 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
 	cmp	word ptr (-2+2)[rcx],1
 	jbe	copy_record_node2_3_ab_or_b
 endif

	push	rax 
	lea	rax,1[rdi]
	
	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr 16[rdx]

	mov	qword ptr [rdi],rcx 
	mov	rdx,qword ptr 8[rdx]

 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	mov	qword ptr 8[rdi],rdx 
	mov	qword ptr [rbp],rdi
	add	rbp,8

	mov	rcx,rax
	test	byte ptr [rax],1		
	jne	record_arguments_already_copied_2
 else
	mov	rcx,rax
	sub	rax,qword ptr heap_p1

	shr	rax,4
	mov	qword ptr 8[rdi],rdx 

	mov	rdx,rax 
	and	rax,31

	shr	rdx,3
	mov	qword ptr [rbp],rdi

	and	rdx,-4
  ifdef PIC
	lea	r9,bit_set_table+0
	mov	eax,dword ptr [r9+rax*4]
  else
	mov	eax,dword ptr (bit_set_table)[rax*4]
  endif

	add	rdx,qword ptr heap_copied_vector
	add	rbp,8

	test	eax,[rdx]
	jne	record_arguments_already_copied_2

	or	[rdx],eax
 endif
	lea	rdx,24[rdi]

	pop	rax
	mov	qword ptr 16[rdi],rdx

	add	rdi,25
	mov	rdx,qword ptr [rcx]

	mov	qword ptr [rcx],rdi
	add	rcx,8

	mov	qword ptr (-1)[rdi],rdx
	add	rdi,7

cp_record_arg_lp2:
	mov	rdx,qword ptr [rcx]
	add	rcx,8

	mov	qword ptr [rdi],rdx
	add	rdi,8

	sub	rax,1
	jne	cp_record_arg_lp2

	sub	rbx,1
	jae	copy_lp2
	ret

record_arguments_already_copied_2:
	mov	rdx,qword ptr [rcx]
	pop	rax 

	mov	qword ptr 16[rdi],rdx 
	add	rdi,24

	sub	rbx,1
	jae	copy_lp2
	ret

 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_node2_3_ab_or_b:
	jb	copy_record_node2_3_b

	push	rax
	lea	rax,1[rdi]

	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr 16[rdx]

	mov	qword ptr [rdi],rcx 
	mov	rdx,qword ptr 8[rdx]

	mov	rcx,rax
	sub	rax,qword ptr heap_p1+0

	shr	rax,4
	mov	qword ptr 8[rdi],rdx 

	mov	rdx,rax 
	and	rax,31

	shr	rdx,3
	mov	qword ptr [rbp],rdi

	and	rdx,-4
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	eax,dword ptr [r9+rax*4]
 else
	mov	eax,dword ptr (bit_set_table)[rax*4]
 endif

	add	rdx,qword ptr heap_copied_vector+0
	add	rbp,8

	test	eax,[rdx]
	jne	record_arguments_already_copied_2

	or	[rdx],eax
	pop	rax

	sub	rsi,8

	shl	rax,3
	sub	rsi,rax
	
	push	rsi
	add	rsi,1
	
	mov	qword ptr 16[rdi],rsi
	add	rdi,24
	
	mov	rdx,qword ptr [rcx]
	jmp	cp_record_arg_lp3_c

copy_record_node2_3_b:
	push	rax
	lea	rax,(-24+1)[rsi]

	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr 16[rdx]

	mov	qword ptr (-24)[rsi],rcx 
	mov	rdx,qword ptr 8[rdx]

	mov	rcx,rax
	sub	rax,qword ptr heap_p1+0

	shr	rax,4
	mov	qword ptr (-16)[rsi],rdx 

	mov	rdx,rax 
	and	rax,31
	sub	rsi,24

	shr	rdx,3
	mov	qword ptr [rbp],rsi

	and	rdx,-4
 ifdef PIC
	lea	r9,bit_set_table+0
	mov	eax,dword ptr [r9+rax*4]
 else
	mov	eax,dword ptr (bit_set_table)[rax*4]
 endif

	add	rdx,qword ptr heap_copied_vector+0
	add	rbp,8

	test	eax,[rdx]
	jne	record_arguments_already_copied_3_b

	or	[rdx],eax
	pop	rax

	mov	rdx,rsi
	sub	rsi,8

	shl	rax,3
	sub	rsi,rax

	mov	qword ptr 16[rdx],rsi

	mov	rdx,qword ptr [rcx]

	push	rsi
	add	rsi,1

cp_record_arg_lp3_c:
	mov	qword ptr [rcx],rsi
	add	rcx,8
	mov	qword ptr (-1) [rsi],rdx
	add	rsi,7

cp_record_arg_lp3:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	
	mov	qword ptr [rsi],rdx
	add	rsi,8
	
	sub	rax,8
	jne	cp_record_arg_lp3
	
	pop	rsi

	sub	rbx,1
	jae	copy_lp2
	ret

record_arguments_already_copied_3_b:
	mov	rdx,qword ptr [rcx]
	pop	rax

	sub	rdx,1
	mov	qword ptr 16[rsi],rdx

	sub	rbx,1
	jae	copy_lp2
	ret
 endif

not_in_hnf_2:
	test	cl,1
	jne	already_copied_2

	movsxd	rax,dword ptr (-4)[rcx]
	test	rax,rax 
	jle	copy_arity_0_node2_

copy_node2_1_:
	and	rax,255
	sub	rax,2
	jl	copy_arity_1_node2
copy_node2_3:
	mov	[rbp],rdi 
	add	rbp,8
	mov	[rdi],rcx 
	inc	rdi
	mov	[rdx],rdi
	mov	rcx,8[rdx]
	add	rdx,16
	mov	(8-1)[rdi],rcx 
	add	rdi,16-1

cp_arg_lp2:
	mov	rcx,[rdx]
	add	rdx,8
	mov	[rdi],rcx 
	add	rdi,8
	sub	rax,1
	jae	cp_arg_lp2

	sub	rbx,1
	jae	copy_lp2
	ret

 ifdef PROFILE_GRAPH
copy_arity_2_node2_:
	mov	rax,16[rdx]
	mov	16[rdi],rax
 endif
copy_arity_1_node2:
copy_arity_1_node2_:
	mov	[rbp],rdi 
	inc	rdi 

	add	rbp,8
	mov	[rdx],rdi 

	mov	rax,8[rdx]
	mov	(-1)[rdi],rcx 

	mov	(8-1)[rdi],rax 
	add	rdi,24-1

	sub	rbx,1
	jae	copy_lp2
	ret

copy_indirection_2:
	mov	rax,rdx 
	mov	rdx,8[rdx]

	mov	rcx,[rdx]
	test	cl,2
	jne	in_hnf_2

	test	cl,1
	jne	already_copied_2

	cmp	dword ptr (-4)[rcx],-2
	je	skip_indirections_2

	movsxd	rax,dword ptr(-4)[rcx]
	test	rax,rax 
	jle	copy_arity_0_node2_
	jmp	copy_node2_1_

skip_indirections_2:
	mov	rdx,8[rdx]

	mov	rcx,[rdx]
	test	cl,2
	jne	update_indirection_list_2
	test	cl,1
	jne	update_indirection_list_2

	cmp	dword ptr (-4)[rcx],-2
	je	skip_indirections_2

update_indirection_list_2:
	lea	rcx,8[rax]
	mov	rax,8[rax]
	mov	[rcx],rdx 
	cmp	rdx,rax 
	jne	update_indirection_list_2

	jmp	continue_after_selector_2

copy_selector_2:
	cmp	rax,-2
	je	copy_indirection_2
	jl	copy_record_selector_2

	mov	rax,8[rdx]
 ifdef NEW_DESCRIPTORS
	mov	d2,[rax]
	test	d2b,2
  ifdef PROFILE_GRAPH
	je	copy_arity_2_node2_
  else
	je	copy_arity_1_node2_
  endif

 ifdef PIC
	movsxd	d3,dword ptr (-8)[rcx]
 else
	mov	d3d,dword ptr (-8)[rcx]
 endif

	cmp	word ptr (-2)[d2],2
	jbe	copy_selector_2_
 
 	mov	d2,16[rax]

	test	byte ptr [d2],1
  ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
  else
	jne	copy_arity_1_node2_
  endif

 ifdef PIC
	movzx	d3,word ptr (4-8)[rcx+d3]
	lea	r9,e__system__nind+0
	mov	qword ptr [rdx],r9
 else
	movzx	d3,word ptr 4[d3]
	mov	qword ptr [rdx],offset e__system__nind
 endif

	cmp	d3,16
	jl	copy_selector_2_1
	je	copy_selector_2_2

	mov	rcx,qword ptr (-24)[d2+d3]
	mov	qword ptr 8[rdx],rcx
	mov	rdx,rcx
	jmp	continue_after_selector_2

copy_selector_2_1:
	mov	rcx,qword ptr 8[rax]
	mov	qword ptr 8[rdx],rcx
	mov	rdx,rcx
	jmp	continue_after_selector_2

copy_selector_2_2:
	mov	rcx,qword ptr [d2]
	mov	qword ptr 8[rdx],rcx
	mov	rdx,rcx
	jmp	continue_after_selector_2

copy_selector_2_:
  ifdef PIC
	movzx	d3,word ptr (4-8)[rcx+d3]
	lea	r9,e__system__nind+0
	mov	qword ptr [rdx],r9
  else
	movzx	d3,word ptr 4[d3]
	mov	qword ptr [rdx],offset e__system__nind
  endif

	mov	rcx,qword ptr [rax+d3]
	mov	qword ptr 8[rdx],rcx
	mov	rdx,rcx
	jmp	continue_after_selector_2
 else
	mov	rax,[rax]
 	test	al,2
  ifdef PROFILE_GRAPH
	je	copy_arity_2_node2_
  else
	je	copy_arity_1_node2_
  endif

	cmp	word ptr (-2)[rax],2
	jbe	copy_selector_2_

  if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_selector_2__:
  endif
	mov	rax,8[rdx]
	mov	rax,16[rax]
	test	byte ptr [rax],1
  ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
  else
	jne	copy_arity_1_node2_
  endif

copy_selector_2_:
	mov	eax,(-8)[rcx]

	mov	rcx,8[rdx]
	push	rdx 
	push	rbp
	mov	eax,4[rax]
	call	near ptr rax
	pop	rbp 
	pop	rdx 

	mov	qword ptr [rdx],offset e__system__nind
	mov	8[rdx],rcx

	mov	rdx,rcx 
	jmp	continue_after_selector_2
 endif

copy_record_selector_2:
	cmp	rax,-3
 	mov	rax,qword ptr 8[rdx]
	mov	d2,qword ptr [rax]
	je	copy_strict_record_selector_2

 	test	d2b,2
  ifdef PROFILE_GRAPH
	je	copy_arity_2_node2_
  else
	je	copy_arity_1_node2_
  endif

	mov	d3d,dword ptr (-8)[rcx]

	cmp	word ptr (-2)[d2],258
 ifdef NEW_DESCRIPTORS
	jbe	copy_record_selector_2_
 else
	jbe	copy_selector_2_
 endif

 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr (-2+2)[d2],2
	jae	copy_selector_2__
 endif

	mov	d4,qword ptr 16[rax]

	lea	d2,(-24)[d4]
	sub	d4,qword ptr heap_p1+0

	mov	d5,d4 
	and	d4,31*16

	shr	d5,7
	
	shr	d4,2
	and	d5,-4

	add	d5,qword ptr heap_copied_vector+0

 ifdef PIC
	lea	r9,bit_set_table+0
	mov	d4d,dword ptr [r9+d4]
 else
	mov	d4d,dword ptr (bit_set_table)[d4]
 endif

	and	d4d,dword ptr [d5]

 ifdef NEW_DESCRIPTORS
  if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	je	copy_record_selector_2_
   ifdef PROFILE_GRAPH
	jmp	copy_arity_2_node2_
   else
	jmp	copy_arity_1_node2_
   endif
copy_selector_2__:
	mov	d4,qword ptr 16[rax]
	lea	d2,(-24)[d4]
	test	byte ptr [d4],1
   ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
   else
	jne	copy_arity_1_node2_
   endif
  else
   ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
   else
	jne	copy_arity_1_node2_
   endif
  endif
copy_record_selector_2_:
 ifdef PIC
	movzx	d3,word ptr (4-8)[rcx+d3]
	lea	r9,e__system__nind+0
	mov	qword ptr [rdx],r9
 else
	movzx	d3,word ptr 4[d3]
	mov	qword ptr [rdx],offset e__system__nind
 endif

	cmp	d3,16
	jle	copy_record_selector_3
	mov	rax,d2
copy_record_selector_3:
	mov	rcx,qword ptr [rax+d3]
	mov	qword ptr 8[rdx],rcx
	mov	rdx,rcx
	jmp	continue_after_selector_2
 else
  ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
  else
	jne	copy_arity_1_node2_
  endif
 	jmp	copy_selector_2_
 endif

copy_strict_record_selector_2:
	test	d2b,2
 ifdef PROFILE_GRAPH
	je	copy_arity_2_node2_
 else
	je	copy_arity_1_node2_
 endif

 ifdef PIC
	movsxd	d3,dword ptr (-8)[rcx]
 else
	mov	d3d,dword ptr (-8)[rcx]
 endif

	cmp	word ptr (-2)[d2],258
	jbe	copy_strict_record_selector_2_

 if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr (-2+2)[d2],2
	jb	copy_strict_record_selector_2_b

	mov	d4,qword ptr 16[rax]
	lea	d2,(-24)[d4]
	test	byte ptr [d4],1
 ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
 else
	jne	copy_arity_1_node2_
 endif

	jmp	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
 endif

	mov	d4,qword ptr 16[rax]

	lea	d2,(-24)[d4]
	sub	d4,qword ptr heap_p1+0

	mov	d5,d4 
	and	d4,31*16

	shr	d5,7

	shr	d4,2
	and	d5,-4

	add	d5,qword ptr heap_copied_vector+0

 ifdef PIC
	lea	r9,bit_set_table+0
	mov	d4d,dword ptr [r9+d4]
 else
	mov	d4d,dword ptr (bit_set_table)[d4]
 endif
	
	and	d4d,[d5]

 ifdef PROFILE_GRAPH
	jne	copy_arity_2_node2_
 else
	jne	copy_arity_1_node2_
 endif

copy_strict_record_selector_2_:
 ifdef PIC
	add	d3,rcx
 endif
 ifdef NEW_DESCRIPTORS
  ifdef PIC
	movzx	rcx,word ptr (4-8)[d3]
  else
	movzx	rcx,word ptr 4[d3]
  endif
	cmp	rcx,16
	jle	copy_strict_record_selector_3
	mov	rcx,qword ptr [d2+rcx]
	jmp	copy_strict_record_selector_4
copy_strict_record_selector_3:
	mov	rcx,qword ptr [rax+rcx]
copy_strict_record_selector_4:
	mov	qword ptr 8[rdx],rcx

 ifdef PIC
	movzx	rcx,word ptr (6-8)[d3]
 else
	movzx	rcx,word ptr 6[d3]
 endif
	test	rcx,rcx
	je	copy_strict_record_selector_6
	cmp	rcx,16
	jle	copy_strict_record_selector_5
	mov	rax,d2
copy_strict_record_selector_5:
	mov	rcx,qword ptr [rax+rcx]
	mov	qword ptr 16[rdx],rcx
copy_strict_record_selector_6:

 ifdef PIC
	mov	rcx,qword ptr ((-8)-8)[d3]
 else
	mov	rcx,qword ptr (-8)[d3]
 endif
	mov	qword ptr [rdx],rcx
	jmp	in_hnf_2
 else
 	mov	rcx,rdx 
	mov	rdx,qword ptr 8[rdx]
	
	push	rbp
	mov	eax,4[d3]
	call	near ptr rax
	pop	rbp 

	mov	rdx,rcx 
	mov	rcx,qword ptr [rcx]
	test	cl,2
	jne	in_hnf_2
	hlt
 endif

copy_arity_0_node2_:
	jl	copy_selector_2

	mov	(-24)[rsi],rcx 
	sub	rsi,24
	mov	[rbp],rsi 
	lea	rax,1[rsi]

	add	rbp,8
	mov	[rdx],rax 

	sub	rbx,1
	jae	copy_lp2
	ret

copy_string_or_array_2:
 ifdef PIC
	je	copy_string_2
	lea	r9,__ARRAY__+2+0
	cmp	rcx,r9
	jb	copy_normal_hnf_0_2
	mov	rcx,rdx
	jmp	copy_array_2
copy_string_2:
	mov	rcx,rdx
 else
	mov	rcx,rdx
	jne	copy_array_2
 endif
	sub	rdx,heap_p1+0
	cmp	rdx,semi_space_size+0
	jae	copy_string_or_array_constant

	mov	rdx,8[rcx]
	add	rbp,8

	add	rdx,7
	push	rbx

	mov	rax,rdx 
	and	rdx,-8
	
	shr	rax,3
	sub	rsi,rdx 

	mov	rbx,[rcx]
	add	rcx,8

	mov	(-16)[rsi],rbx 
	sub	rsi,16

	mov	(-8)[rbp],rsi 
	lea	rdx,1[rsi]
	
	mov	(-8)[rcx],rdx 
	lea	rdx,8[rsi]

cp_s_arg_lp2:
	mov	rbx,[rcx]
	add	rcx,8

	mov	[rdx],rbx 
	add	rdx,8

	sub	rax,1
	jge	cp_s_arg_lp2

	pop	rbx 
	sub	rbx,1
	jae	copy_lp2
	ret

copy_array_2:
	sub	rdx,heap_p1+0
	cmp	rdx,semi_space_size+0
	jae	copy_string_or_array_constant

	push	rbx 

	mov	rax,qword ptr 16[rcx]
	test	rax,rax 
	je	copy_array_a2

	movzx 	rbx,word ptr (-2)[rax]

	test	rbx,rbx 
	je	copy_strict_basic_array_2
	
	sub	rbx,256
	imul	rbx,qword ptr 8[rcx]
	jmp	copy_array_a3

copy_array_a2:
	mov	rbx,qword ptr 8[rcx]
copy_array_a3:
	mov	rdx,rdi 
	lea	rdi,24[rdi+rbx*8]

	mov	qword ptr [rbp],rdx 
	mov	rax,qword ptr [rcx]

	add	rbp,8
	mov	qword ptr [rdx],rax 

	lea	rax,1[rdx]
	add	rdx,8

	mov	qword ptr [rcx],rax 
	add	rcx,8

	lea	rax,1[rbx]
	jmp	cp_s_arg_lp2

copy_strict_basic_array_2:
	mov	rbx,qword ptr 8[rcx]

 ifdef PIC
	lea	r9,dINT+2+0
	cmp	rax,r9
 else
	cmp	rax,offset dINT+2
 endif
	jle	copy_int_or_real_array_2

 ifdef PIC
	lea	r9,BOOL+2+0
	cmp	rax,r9
 else
	cmp	rax,offset BOOL+2
 endif
	je	copy_bool_array_2

copy_int32_or_real32_array_2:
	add	rbx,1
	shr	rbx,1

copy_int_or_real_array_2:
	shl	rbx,3
	lea	rdx,(-24)[rsi]

	sub	rdx,rbx 
	mov	rax,qword ptr [rcx]

	shr	rbx,3
	mov	qword ptr [rbp],rdx 

	add	rbp,8
	mov	rsi,rdx 
	
	mov	qword ptr [rdx],rax 
	lea	rax,1[rdx]

	add	rdx,8
	mov	qword ptr [rcx],rax 

	add	rcx,8
	lea	rax,1[rbx]
	jmp	cp_s_arg_lp2

copy_bool_array_2:
	add	rbx,7
	shr	rbx,3
	jmp	copy_int_or_real_array_2

copy_string_or_array_constant:
	mov	qword ptr [rbp],rcx
	add	rbp,8

	sub	rbx,1
	jae	copy_lp2
	ret

end_copy1:
	mov	heap_end_after_gc+0,rsi

 ifdef PIC
	lea	rcx,finalizer_list+0
 else
	mov	rcx,offset finalizer_list
 endif
 ifdef PIC
	lea	rdx,free_finalizer_list+0
 else
	mov	rdx,offset free_finalizer_list
 endif
	mov	rbp,qword ptr finalizer_list+0

determine_free_finalizers_after_copy:
	mov	rax,qword ptr [rbp]
	test	al,1
	je	finalizer_not_used_after_copy

	mov	rbp,qword ptr 8[rbp]
	sub	rax,1
	mov	qword ptr [rcx],rax 
	lea	rcx,8[rax]
	jmp	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	lea	r9,__Nil-8+0
	cmp	rbp,r9
	je	end_finalizers_after_copy

	mov	qword ptr [rdx],rbp 
	lea	rdx,8[rbp]
	mov	rbp,qword ptr 8[rbp]
	jmp	determine_free_finalizers_after_copy

end_finalizers_after_copy:
	mov	qword ptr [rcx],rbp 
	mov	qword ptr [rdx],rbp

 ifdef GC_HOOKS
	mov	rax,qword ptr gc_hook_after_copy+0
	test	rax,rax
	je	no_gc_hook_after_copy
	call	rax
no_gc_hook_after_copy:
 endif

