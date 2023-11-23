

	.globl	_copy_graph_to_string
	.globl	_remove_forwarding_pointers_from_graph
	.globl	collect_1

	.text

	.intel_syntax noprefix

	.globl	__copy__graph__to__string

__copy__graph__to__string:
	push	rcx

	mov	r12,rsi
	mov	r13,rdi

	mov	rdi,rcx
	mov	rsi,r13
	lea	rdx,[r13+r15*8]

	mov	rbp,rsp
	and	rsp,-8
	.att_syntax
	call	_copy_graph_to_string
	.intel_syntax noprefix
	mov	rsp,rbp
	mov	rcx,qword ptr [rsp]
	push	rax

	mov	rdi,rcx
	lea	rsi,[r13+r15*8]

	mov	rbp,rsp
	and	rsp,-8
	.att_syntax
	call	_remove_forwarding_pointers_from_graph
	.intel_syntax noprefix
	mov	rsp,rbp
	pop	rcx

	mov	rsi,r12
	mov	rdi,r13

	test	rcx,rcx
	.att_syntax
	jne	__copy__graph__to__string_1
	.intel_syntax noprefix

	pop	rcx

	lea	rbx,1[r15]
	sub	r15,rbx
	.att_syntax
	call	collect_1
	.intel_syntax noprefix
	add	r15,rbx
	.att_syntax
	jmp	__copy__graph__to__string
	.intel_syntax noprefix

__copy__graph__to__string_1:
	add	rsp,8

	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	and	rax,-8
	add	rdi,rax
	sar	rax,3
	sub	r15,rax
	ret
