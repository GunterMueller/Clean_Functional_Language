
COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP = 1

	push	rsi

	mov	rdi,[rip+heap_p2]

	mov	rax,[rip+heap_size_257]
	shl	rax,7
	mov	[rip+semi_space_size],rax 
	lea	rsi,[rdi+rax]

	mov	qword ptr [rip+heap2_begin_and_end+8],rsi 

	mov	rax,qword ptr [rip+caf_list]
	test	rax,rax 
	je	end_copy_cafs

copy_cafs_lp:
	push	[rax-8]
	
	lea	rbp,[rax+8]
	mov	rbx,qword ptr [rax]
	sub	rbx,1
	call	copy_lp2
	
	pop	rax
	test	rax,rax
	att_jne	copy_cafs_lp

end_copy_cafs:
	mov	rbx,qword ptr [rsp]
	mov	rbp,[rip+stack_p]
	sub	rbx,rbp
	shr	rbx,3

	sub	rbx,1
	jb	end_copy0
	att_call	copy_lp2
end_copy0:
	mov	rbp,[rip+heap_p2]

	jmp	copy_lp1
/* */
/*	Copy all referenced nodes to the other semi space */
/* */

in_hnf_1_2:
	dec	rbx
copy_lp2_lp1:
	att_call	copy_lp2
copy_lp1:
	cmp	rbp,rdi
	jae	end_copy1

	mov	rax,[rbp]
	add	rbp,8
	test	al,2
	je	not_in_hnf_1
in_hnf_1:
	movzx	rbx,word ptr [rax-2]

	test	rbx,rbx
	je	copy_array_21

	cmp	rbx,2
	att_jbe	in_hnf_1_2

	cmp	rbx,256
	jae	copy_record_21
	
	mov	rax,[rbp+8]

	test	al,1
	jne	node_without_arguments_part

	push	rbx
	xor	rbx,rbx 
	
	att_call	copy_lp2

	pop	rbx 
	add	rbp,8

	sub	rbx,2
	att_jmp	copy_lp2_lp1

node_without_arguments_part:
	dec	rax 
	xor	rbx,rbx 

	mov	[rbp+8],rax 
	att_call	copy_lp2
	
	add	rbp,8
	att_jmp	copy_lp1

copy_record_21:
	sub	rbx,258
	ja	copy_record_arguments_3

	movzx	rbx,word ptr [rax-2+2]
 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	att_jb	in_hnf_1_2

	sub	rbx,1
	att_ja	copy_lp2_lp1
	jmp	copy_node_arity1
 .else
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
 .endif

copy_record_arguments_3:
	test	byte ptr [rbp+8],1
	jne	record_node_without_arguments_part

	movzx	rdx,word ptr [rax-2+2]
 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	sub	rdx,1
 .else
	test	rdx,rdx 
	je	copy_record_arguments_3b
	sub	rdx,1
	je	copy_record_arguments_3abb
 .endif

	lea	rcx,[rbp+rbx*8+3*8]
	push	rcx 
	push	rdx 

	sub	rbx,rbx 
	att_call	copy_lp2
	
	add	rbp,8
	pop	rbx 
	dec	rbx 
	att_call	copy_lp2

	pop	rbp 
	att_jmp	copy_lp1

 .if ! COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_arguments_3abb:
	push	rbx 
	sub	rbx,rbx 
	
	call	copy_lp2
	
	pop	rbx 
	
	lea	rbp,[rbp+rbx*8+2*8]
	jmp	copy_lp1

copy_record_arguments_3b:
	lea	rbp,[rbp+rbx*8+3*8]
	jmp	copy_lp1
 .endif

record_node_without_arguments_part:
	and	qword ptr [rbp+8],-2

 .if ! COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr [rax-2+2],0
	je	record_node_without_arguments_part_3b
 .endif

	sub	rbx,rbx 
	att_call	copy_lp2

	add	rbp,8
	att_jmp	copy_lp1

 .if ! COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
record_node_without_arguments_part_3b:
	add	rbp,16
	jmp	copy_lp1
 .endif

not_in_hnf_1:
	movsxd	rbx,dword ptr [rax-4]
	cmp	rbx,257
	jge	copy_unboxed_closure_arguments
	sub	rbx,1
	att_jg	copy_lp2_lp1

copy_node_arity1:
	xor	rbx,rbx 
	att_call	copy_lp2

	add	rbp,8
	att_jmp	copy_lp1

copy_unboxed_closure_arguments:
	je	copy_unboxed_closure_arguments1

	xor	rax,rax
	mov	al,bh 
	and	rbx,255
	sub	rbx,rax 

	sub	rbx,1
	jl	copy_unboxed_closure_arguments_without_pointers
	
	push	rax 
	att_call	copy_lp2
	pop	rax 

copy_unboxed_closure_arguments_without_pointers:
	lea	rbp,[rbp+rax*8]
	att_jmp	copy_lp1

copy_unboxed_closure_arguments1:
	add	rbp,16
	att_jmp	copy_lp1

copy_array_21:
	mov	rbx,qword ptr [rbp+8]
	add	rbp,16
	test	rbx,rbx 
	je	copy_array_21_a

	movzx	rax,word ptr [rbx-2]
	movzx	rbx,word ptr [rbx-2+2]
	sub	rax,256
	test	rbx,rbx 
	je	copy_array_21_b

	cmp	rbx,rax 
	je	copy_array_21_r_a

copy_array_21_ab:
	cmp	qword ptr [rbp-16],0
	att_je	copy_lp1

	sub	rax,rbx 
	shl	rax,3
	sub	rbx,1

	push	rbx 
	push	rax 
	mov	rbx,qword ptr [rbp-16]
	sub	rbx,1
	push	rbx 

copy_array_21_lp_ab:
	mov	rbx,qword ptr [rsp+16]
	att_call	copy_lp2

	add	rbp,qword ptr [rsp+8]
	sub	qword ptr [rsp],1
	att_jnc	copy_array_21_lp_ab
	
	add	rsp,24
	att_jmp	copy_lp1

copy_array_21_b:
	mov	rbx,qword ptr [rbp-16]
	imul	rbx,rax 
	lea	rbp,[rbp+rbx*8]
	att_jmp	copy_lp1

copy_array_21_r_a:
	mov	rbx,qword ptr [rbp-16]
	imul	rbx,rax
	sub	rbx,1
	att_jc	copy_lp1
	att_jmp	copy_lp2_lp1

copy_array_21_a:
	mov	rbx,qword ptr [rbp-16]
	sub	rbx,1
	att_jc	copy_lp1
	att_jmp	copy_lp2_lp1

/* */
/*	Copy nodes to the other semi-space */
/* */

copy_lp2:
	mov	rdx,qword ptr [rbp]

/* selectors: */
continue_after_selector_2:
	mov	rcx,qword ptr [rdx]
	test	cl,2
	je	not_in_hnf_2

in_hnf_2:
	movzx	rax,word ptr [rcx-2]
	test	rax,rax
	je	copy_arity_0_node2

	cmp	rax,256
	jae	copy_record_2

	sub	rax,2
	mov	[rbp],rdi 

	lea	rbp,[rbp +8]
	ja	copy_hnf_node2_3

	mov	[rdi],rcx
	jb	copy_hnf_node2_1

	inc	rdi
	mov	rcx,[rdx+8]

	mov	[rdx],rdi 
	mov	rax,[rdx+16]

	sub	rbx,1
	mov	[rdi+8-1],rcx 

	mov	[rdi+16-1],rax 
	lea	rdi,[rdi+24-1]

	att_jae	copy_lp2
	ret

copy_hnf_node2_1:
	inc	rdi 
	mov	rax,[rdx+8]

	sub	rbx,1
	mov	[rdx],rdi

	mov	[rdi+8-1],rax 
	lea	rdi,[rdi+16-1]

	att_jae	copy_lp2
	ret

copy_hnf_node2_3:
	mov	[rdi],rcx 
	inc	rdi 

	mov	[rdx],rdi 
	mov	rcx,[rdx+8]

	mov	[rdi+8-1],rcx 
	mov	rcx,[rdx+16]

	add	rdi,24-1
	mov	rdx,[rcx]
	
	test	dl,1
	jne	arguments_already_copied_2

	mov	[rdi-8],rdi 
	add	rcx,8

	mov	[rdi],rdx 
	inc	rdi

	mov	[rcx-8],rdi 
	add	rdi,8-1

cp_hnf_arg_lp2:
	mov	rdx,[rcx]
	add	rcx,8

	mov	[rdi],rdx 
	add	rdi,8

	dec	rax 
	att_jne	cp_hnf_arg_lp2

	sub	rbx,1
	att_jae	copy_lp2
	ret

arguments_already_copied_2:
	mov	[rdi-8],rdx 

	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_arity_0_node2:
	lea	r9,[rip+__STRING__+2]
	cmp	rcx,r9
	jbe	copy_string_or_array_2

	lea	r9,[rip+CHAR+2]
	cmp	rcx,r9
	ja	copy_normal_hnf_0_2

copy_int_bool_or_char_2:
	mov	rax,[rdx+8]
	je	copy_char_2

	lea	r9,[rip+INT+2]
	cmp	rcx,r9
	jne	no_small_int_or_char_2

copy_int_2:
	cmp	rax,33
	att_jae	no_small_int_or_char_2

	shl	rax,4
	add	rbp,8

	lea	r9,[rip+small_integers]
	add	rax,r9
	sub	rbx,1

	mov	[rbp-8],rax 
	att_jae	copy_lp2
	ret

copy_char_2:	
	and	rax,255

	shl	rax,4
	add	rbp,8

	lea	r9,[rip+static_characters]
	add	rax,r9
	sub	rbx,1

	mov	[rbp-8],rax 
	att_jae	copy_lp2
	ret
	
no_small_int_or_char_2:
 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_node2_1_b:
 .endif
	mov	[rsi-16],rcx 
	add	rbp,8

	mov	[rsi-8],rax 
	sub	rsi,15

	mov	[rdx],rsi 
	dec	rsi

	mov	[rbp-8],rsi

	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_normal_hnf_0_2:
	sub	rcx,2-(-8)
	sub	rbx,1

	mov	[rbp],rcx 
	lea	rbp,[rbp+8]
	att_jae	copy_lp2
	ret

already_copied_2:
	dec	rcx 
	sub	rbx,1

	mov	[rbp],rcx 
	lea	rbp,[rbp+8]

	att_jae	copy_lp2
	ret

copy_record_2:
	sub	rax,258
	ja	copy_record_node2_3

 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
 	jb	copy_record_node2_1
 
 	cmp	word ptr [rcx-2+2],0
	att_je	copy_record_node2_bb

	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,[rdi+1]
	mov	rax,qword ptr [rdx+8]

	mov	qword ptr [rdx],rcx

	mov	qword ptr [rdi+8],rax
	mov	rax,qword ptr [rdx+16]

	add	rbp,8
	mov	qword ptr [rdi+16],rax

	add	rdi,24
	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_record_node2_1:
	mov	rax,qword ptr [rdx+8]

	cmp	word ptr [rcx-2+2],0
	att_je	copy_record_node2_1_b

	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,[rdi+1]
	mov	qword ptr [rdi+8],rax

	mov	qword ptr [rdx],rcx
	add	rbp,8

	add	rdi,16
	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_record_node2_bb:
	mov [rsi-24],rcx 
	sub	rsi,24-1

	mov	[rdx],rsi 
	dec	rsi 

	mov	rax,[rdx+8]
	mov	rcx,[rdx+16]

	mov	[rbp],rsi 
	add	rbp,8

	mov	[rsi+8],rax 
	sub	rbx,1

	mov [rsi+16],rcx 

	att_jae	copy_lp2
	ret

 .else
	mov	qword ptr [rbp],rdi
	mov	qword ptr [rdi],rcx

	lea	rcx,[rdi+1]
	mov	rax,qword ptr [rdx+8]

	mov	qword ptr [rdx],rcx
	jb	copy_record_node2_1

	mov	qword ptr [rdi+8],rax
	mov	rax,qword ptr [rdx+16]

	add	rbp,8
	mov	qword ptr [rdi+16],rax

	add	rdi,24
	sub	rbx,1
	jae	copy_lp2
	ret

copy_record_node2_1:
	add	rbp,8
	mov	qword ptr [rdi+8],rax 

	add	rdi,16
	sub	rbx,1
	jae	copy_lp2
	ret
 .endif

copy_record_node2_3:
 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
 	cmp	word ptr [rcx-2+2],1
 	jbe	copy_record_node2_3_ab_or_b
 .endif

	push	rax 
	lea	rax,[rdi+1]
	
	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr [rdx+16]

	mov	qword ptr [rdi],rcx 
	mov	rdx,qword ptr [rdx+8]

 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	mov	qword ptr [rdi+8],rdx 
	mov	qword ptr [rbp],rdi
	add	rbp,8

	mov	rcx,rax
	test	byte ptr [rax],1		
	jne	record_arguments_already_copied_2
 .else
	mov	rcx,rax 
	sub	rax,qword ptr heap_p1

	shr	rax,4
	mov	qword ptr [rdi+8],rdx 

	mov	rdx,rax 
	and	rax,31

	shr	rdx,3
	mov	qword ptr [rbp],rdi

	and	rdx,-4
	mov	eax,dword ptr [rax*4+bit_set_table]

	add	rdx,qword ptr heap_copied_vector
	add	rbp,8

	test	eax,[rdx]
	jne	record_arguments_already_copied_2

	or	[rdx],eax
 .endif
	lea	rdx,[rdi+24]

	pop	rax
	mov	qword ptr [rdi+16],rdx

	add	rdi,25
	mov	rdx,qword ptr [rcx]

	mov	qword ptr [rcx],rdi
	add	rcx,8

	mov	qword ptr [rdi-1],rdx
	add	rdi,7

cp_record_arg_lp2:
	mov	rdx,qword ptr [rcx]
	add	rcx,8

	mov	qword ptr [rdi],rdx
	add	rdi,8

	sub	rax,1
	att_jne	cp_record_arg_lp2

	sub	rbx,1
	att_jae	copy_lp2
	ret

record_arguments_already_copied_2:
	mov	rdx,qword ptr [rcx]
	pop	rax 

	mov	qword ptr [rdi+16],rdx 
	add	rdi,24

	sub	rbx,1
	att_jae	copy_lp2
	ret

 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
copy_record_node2_3_ab_or_b:
	jb	copy_record_node2_3_b

	push	rax
	lea	rax,[rdi+1]

	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr [rdx+16]

	mov	qword ptr [rdi],rcx 
	mov	rdx,qword ptr [rdx+8]

	mov	rcx,rax 
	sub	rax,qword ptr [rip+heap_p1]

	shr	rax,4
	mov	qword ptr [rdi+8],rdx 

	mov	rdx,rax 
	and	rax,31

	shr	rdx,3
	mov	qword ptr [rbp],rdi

	and	rdx,-4
	lea	r9,[rip+bit_set_table]
	mov	eax,dword ptr [r9+rax*4]

	add	rdx,qword ptr [rip+heap_copied_vector]
	add	rbp,8

	test	eax,[rdx]
	att_jne	record_arguments_already_copied_2

	or	[rdx],eax
	pop	rax

	sub	rsi,8

	shl	rax,3
	sub	rsi,rax
	
	push	rsi
	add	rsi,1
	
	mov	qword ptr [rdi+16],rsi
	add	rdi,24
	
	mov	rdx,qword ptr [rcx]
	jmp	cp_record_arg_lp3_c

copy_record_node2_3_b:
	push	rax
	lea	rax,[rsi-24+1]

	mov	qword ptr [rdx],rax 
	mov	rax,qword ptr [rdx+16]

	mov	qword ptr [rsi-24],rcx 
	mov	rdx,qword ptr [rdx+8]

	mov	rcx,rax 
	sub	rax,qword ptr [rip+heap_p1]

	shr	rax,4
	mov	qword ptr [rsi-16],rdx 

	mov	rdx,rax 
	and	rax,31
	sub	rsi,24

	shr	rdx,3
	mov	qword ptr [rbp],rsi

	and	rdx,-4
	lea	r9,[rip+bit_set_table]
	mov	eax,dword ptr [r9+rax*4]

	add	rdx,qword ptr [rip+heap_copied_vector]
	add	rbp,8

	test	eax,[rdx]
	jne	record_arguments_already_copied_3_b

	or	[rdx],eax
	pop	rax

	mov	rdx,rsi
	sub	rsi,8

	shl	rax,3
	sub	rsi,rax

	mov	qword ptr [rdx+16],rsi

	mov	rdx,qword ptr [rcx]

	push	rsi
	add	rsi,1

cp_record_arg_lp3_c:
	mov	qword ptr [rcx],rsi
	add	rcx,8
	mov	qword ptr [rsi-1],rdx
	add	rsi,7

cp_record_arg_lp3:
	mov	rdx,qword ptr [rcx]
	add	rcx,8
	
	mov	qword ptr [rsi],rdx
	add	rsi,8
	
	sub	rax,8
	att_jne	cp_record_arg_lp3
	
	pop	rsi

	sub	rbx,1
	att_jae	copy_lp2
	ret

record_arguments_already_copied_3_b:
	mov	rdx,qword ptr [rcx]
	pop	rax
	
	sub	rdx,1
	mov	qword ptr [rsi+16],rdx
	
	sub	rbx,1
	att_jae	copy_lp2
	ret
 .endif

not_in_hnf_2:
	test	cl,1
	att_jne	already_copied_2

	movsxd	rax,dword ptr [rcx-4]
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
	mov	rcx,[rdx+8]
	add	rdx,16
	mov [rdi+8-1],rcx 
	add	rdi,16-1

cp_arg_lp2:
	mov	rcx,[rdx]
	add	rdx,8
	mov	[rdi],rcx 
	add	rdi,8
	sub	rax,1
	att_jae	cp_arg_lp2

	sub	rbx,1
	att_jae	copy_lp2
	ret

 .if PROFILE_GRAPH
copy_arity_2_node2_:
	mov	rax,16[rdx]
	mov	16[rdi],rax
 .endif
copy_arity_1_node2:
copy_arity_1_node2_:
	mov	[rbp],rdi 
	inc	rdi 

	add	rbp,8
	mov	[rdx],rdi 

	mov	rax,[rdx+8]
	mov [rdi-1],rcx 

	mov [rdi+8-1],rax 
	add	rdi,24-1

	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_indirection_2:
	mov	rax,rdx 
	mov	rdx,[rdx+8]

	mov	rcx,[rdx]
	test	cl,2
	att_jne	in_hnf_2

	test	cl,1
	att_jne	already_copied_2

	cmp	dword ptr [rcx-4],-2
	je	skip_indirections_2

	movsxd	rax,dword ptr [rcx-4]
	test	rax,rax 
	att_jle	copy_arity_0_node2_
	att_jmp	copy_node2_1_

skip_indirections_2:
	mov	rdx,[rdx+8]

	mov	rcx,[rdx]
	test	cl,2
	jne	update_indirection_list_2
	test	cl,1
	att_jne	update_indirection_list_2

	cmp	dword ptr [rcx-4],-2
	att_je	skip_indirections_2

update_indirection_list_2:
	lea	rcx,[rax+8]
	mov	rax,[rax+8]
	mov	[rcx],rdx 
	cmp	rdx,rax 
	att_jne	update_indirection_list_2

	att_jmp	continue_after_selector_2

copy_selector_2:
	cmp	rax,-2
	att_je	copy_indirection_2
	jl	copy_record_selector_2

	mov	rax,[rdx+8]

	mov	r10,[rax]
	test	r10b,2
 .if PROFILE_GRAPH
	att_je	copy_arity_2_node2_
 .else
	att_je	copy_arity_1_node2_
 .endif

	movsxd	r11,dword ptr [rcx-8]

	cmp	word ptr [r10-2],2
	jbe	copy_selector_2_
 
 	mov	r10,[rax+16]

	test	byte ptr [r10],1
 .if PROFILE_GRAPH
	att_jne	copy_arity_2_node2_
 .else
	att_jne	copy_arity_1_node2_
 .endif

	movzx	r11,word ptr [rcx+r11+4-8]
	lea	r9,[rip+e__system__nind]
	mov	qword ptr [rdx],r9

	cmp	r11,16
	jl	copy_selector_2_1
	je	copy_selector_2_2

	mov	rcx,qword ptr [r10+r11-24]
	mov	qword ptr [rdx+8],rcx
	mov	rdx,rcx
	att_jmp	continue_after_selector_2

copy_selector_2_1:
	mov	rcx,qword ptr [rax+8]
	mov	qword ptr [rdx+8],rcx
	mov	rdx,rcx
	att_jmp	continue_after_selector_2

copy_selector_2_2:
	mov	rcx,qword ptr [r10]
	mov	qword ptr [rdx+8],rcx
	mov	rdx,rcx
	att_jmp	continue_after_selector_2

copy_selector_2_:
	movzx	r11,word ptr [rcx+r11+4-8]
	lea	r9,[rip+e__system__nind]
	mov	qword ptr [rdx],r9

	mov	rcx,qword ptr [rax+r11]
	mov	qword ptr [rdx+8],rcx
	mov	rdx,rcx
	att_jmp	continue_after_selector_2

copy_record_selector_2:
	cmp	rax,-3
 	mov	rax,qword ptr [rdx+8]
	mov	r10,qword ptr [rax]
	je	copy_strict_record_selector_2

 	test	r10b,2
 .if PROFILE_GRAPH
	att_je	copy_arity_2_node2_
 .else
	att_je	copy_arity_1_node2_
 .endif

	movsxd	r11,dword ptr [rcx-8]

	cmp	word ptr [r10-2],258
	jbe	copy_record_selector_2_

 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr [r10-2+2],2
	jae	copy_selector_2__
 .endif

	mov	r12,qword ptr [rax+16]

	lea	r10,[r12-24]
	sub	r12,qword ptr [rip+heap_p1]

	mov	r13,r12 
	and	r12,31*16

	shr	r13,7
	
	shr	r12,2
	and	r13,-4

	add	r13,qword ptr [rip+heap_copied_vector]

	lea	r9,[rip+bit_set_table]
	mov	r12d,dword ptr [r9+r12]

	and	r12d,dword ptr [r13]
 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	att_je	copy_record_selector_2_
  .if PROFILE_GRAPH
	att_jmp	copy_arity_2_node2_
  .else
	att_jmp	copy_arity_1_node2_
  .endif
copy_selector_2__:
	mov	r12,qword ptr [rax+16]
	lea	r10,[r12-24]
	test	byte ptr [r12],1
  .if PROFILE_GRAPH
	att_jne	copy_arity_2_node2_
  .else
	att_jne	copy_arity_1_node2_
  .endif
 .else
  .if PROFILE_GRAPH
	att_jne	copy_arity_2_node2_
  .else
	att_jne	copy_arity_1_node2_
  .endif
 .endif
copy_record_selector_2_:
	movzx	r11,word ptr [rcx+r11+4-8]
	lea	r9,[rip+e__system__nind]
	mov	qword ptr [rdx],r9

	cmp	r11,16
	jle	copy_record_selector_3
	mov	rax,r10
copy_record_selector_3:
	mov	rcx,qword ptr [rax+r11]
	mov	qword ptr [rdx+8],rcx
	mov	rdx,rcx
	att_jmp	continue_after_selector_2

copy_strict_record_selector_2:
	test	r10b,2
 .if PROFILE_GRAPH
	att_je	copy_arity_2_node2_
 .else
	att_je	copy_arity_1_node2_
 .endif

	movsxd	r11,dword ptr [rcx-8]

	cmp	word ptr [r10-2],258
	jbe	copy_strict_record_selector_2_

 .if COPY_RECORDS_WITHOUT_POINTERS_TO_END_OF_HEAP
	cmp	word ptr [r10-2+2],2
	jb	copy_strict_record_selector_2_b

	mov	r12,qword ptr [rax+16]
	lea	r10,[r12-24]
	test	byte ptr [r12],1
  .if PROFILE_GRAPH
	att_jne	copy_arity_2_node2_
  .else
	att_jne	copy_arity_1_node2_
  .endif

	att_jmp	copy_strict_record_selector_2_

copy_strict_record_selector_2_b:
 .endif

	mov	r12,qword ptr [rax+16]

	lea	r10,[r12-24]
	sub	r12,qword ptr [rip+heap_p1]

	mov	r13,r12 
	and	r12,31*16

	shr	r13,7

	shr	r12,2
	and	r13,-4

	add	r13,qword ptr [rip+heap_copied_vector]

	lea	r9,[rip+bit_set_table]
	mov	r12d,dword ptr [r9+r12]
	
	and	r12d,[r13]

 .if PROFILE_GRAPH
	att_jne	copy_arity_2_node2_
 .else
	att_jne	copy_arity_1_node2_
 .endif

copy_strict_record_selector_2_:
	add	r11,rcx
	movzx	rcx,word ptr [r11+4-8]
	cmp	rcx,16
	jle	copy_strict_record_selector_3
	mov	rcx,qword ptr [r10+rcx]
	jmp	copy_strict_record_selector_4
copy_strict_record_selector_3:
	mov	rcx,qword ptr [rax+rcx]
copy_strict_record_selector_4:
	mov	qword ptr [rdx+8],rcx

	movzx	rcx,word ptr [r11+6-8]
	test	rcx,rcx
	je	copy_strict_record_selector_6
	cmp	rcx,16
	jle	copy_strict_record_selector_5
	mov	rax,r10
copy_strict_record_selector_5:
	mov	rcx,qword ptr [rax+rcx]
	mov	qword ptr [rdx+16],rcx
copy_strict_record_selector_6:

	mov	rcx,qword ptr [r11-8-8]
	mov	qword ptr [rdx],rcx
	att_jmp	in_hnf_2

copy_arity_0_node2_:
	att_jl	copy_selector_2

	mov [rsi-24],rcx 
	sub	rsi,24
	mov	[rbp],rsi 
	lea	rax,[rsi+1]

	add	rbp,8
	mov	[rdx],rax 

	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_string_or_array_2:
	mov	rcx,rdx 
	jne	copy_array_2

	sub	rdx,[rip+heap_p1]
	cmp	rdx,[rip+semi_space_size]
	jae	copy_string_or_array_constant

	mov	rdx,[rcx+8]
	add	rbp,8

	add	rdx,7
	push	rbx

	mov	rax,rdx 
	and	rdx,-8
	
	shr	rax,3
	sub	rsi,rdx 

	mov	rbx,[rcx]
	add	rcx,8

	mov [rsi-16],rbx 
	sub	rsi,16

	mov [rbp-8],rsi 
	lea	rdx,[rsi+1]
	
	mov [rcx-8],rdx 
	lea	rdx,[rsi+8]

cp_s_arg_lp2:
	mov	rbx,[rcx]
	add	rcx,8

	mov	[rdx],rbx 
	add	rdx,8

	sub	rax,1
	att_jge	cp_s_arg_lp2

	pop	rbx 
	sub	rbx,1
	att_jae	copy_lp2
	ret

copy_array_2:
	sub	rdx,[rip+heap_p1]
	cmp	rdx,[rip+semi_space_size]
	att_jae	copy_string_or_array_constant

	push	rbx 

	mov	rax,qword ptr [rcx+16]
	test	rax,rax 
	je	copy_array_a2

	movzx 	rbx,word ptr [rax-2]

	test	rbx,rbx 
	je	copy_strict_basic_array_2
	
	sub	rbx,256
	imul	rbx,qword ptr [rcx+8]
	jmp	copy_array_a3

copy_array_a2:
	mov	rbx,qword ptr [rcx+8]
copy_array_a3:
	mov	rdx,rdi 
	lea	rdi,[rdi+rbx*8+24]

	mov	qword ptr [rbp],rdx 
	mov	rax,qword ptr [rcx]

	add	rbp,8
	mov	qword ptr [rdx],rax 

	lea	rax,[rdx+1]
	add	rdx,8

	mov	qword ptr [rcx],rax 
	add	rcx,8

	lea	rax,[rbx+1]
	att_jmp	cp_s_arg_lp2

copy_strict_basic_array_2:
	mov	rbx,qword ptr [rcx+8]

	lea	r9,[rip+INT+2]
	cmp	rax,r9
	jle	copy_int_or_real_array_2

	lea	r9,[rip+BOOL+2]
	cmp	rax,r9
	je	copy_bool_array_2

copy_int32_or_real32_array_2:
	add	rbx,1
	shr	rbx,1

copy_int_or_real_array_2:
	shl	rbx,3
	lea	rdx,[rsi-24]

	sub	rdx,rbx 
	mov	rax,qword ptr [rcx]

	shr	rbx,3
	mov	qword ptr [rbp],rdx 

	add	rbp,8
	mov	rsi,rdx 
	
	mov	qword ptr [rdx],rax 
	lea	rax,[rdx+1]

	add	rdx,8
	mov	qword ptr [rcx],rax 

	add	rcx,8
	lea	rax,[rbx+1]
	att_jmp	cp_s_arg_lp2

copy_bool_array_2:
	add	rbx,7
	shr	rbx,3
	att_jmp	copy_int_or_real_array_2

copy_string_or_array_constant:
	mov	qword ptr [rbp],rcx 
	add	rbp,8

	sub	rbx,1
	att_jae	copy_lp2
	ret

end_copy1:
	mov [rip+heap_end_after_gc],rsi 

	lea	rcx,[rip+finalizer_list]
	lea	rdx,[rip+free_finalizer_list]
	mov	rbp,qword ptr [rip+finalizer_list]

determine_free_finalizers_after_copy:
	mov	rax,qword ptr [rbp]
	test	al,1
	je	finalizer_not_used_after_copy

	mov	rbp,qword ptr [rbp+8]
	sub	rax,1
	mov	qword ptr [rcx],rax 
	lea	rcx,[rax+8]
	att_jmp	determine_free_finalizers_after_copy

finalizer_not_used_after_copy:
	lea	r9,[rip+__Nil-8]
	cmp	rbp,r9
	je	end_finalizers_after_copy

	mov	qword ptr [rdx],rbp 
	lea	rdx,[rbp+8]
	mov	rbp,qword ptr [rbp+8]
	att_jmp	determine_free_finalizers_after_copy	

end_finalizers_after_copy:
	mov	qword ptr [rcx],rbp 
	mov	qword ptr [rdx],rbp 
