
	.globl	collect_1

	.globl	_copy_string_to_graph
	.globl	_remove_forwarding_pointers_from_string

	.text

	.intel_syntax noprefix

	.globl	__copy__string__to__graph

__copy__string__to__graph:
	push	rcx

	sub	rsp,8

	mov	r12,rsi
	mov	r13,rdi

	mov	rdi,rcx
	mov	rsi,r13
	lea	rdx,[r13+r15*8]
	mov	rcx,rsp

	mov	rbp,rsp
	and	rsp,-8
	.att_syntax
	call	_copy_string_to_graph
	.intel_syntax noprefix
	mov	rsp,rbp

	mov	rsi,r12
	mov	rdi,r13

	test	rax,1
	.att_syntax
	je	__copy__string__to__graph_1
	.intel_syntax noprefix

	mov	rcx,qword ptr 8[rsp]
	and	rax,-8

	mov	r12,rsi
	mov	r13,rdi

	mov	rdi,rcx
	mov	rsi,rax

	mov	rbp,rsp
	and	rsp,-8
	.att_syntax
	call	_remove_forwarding_pointers_from_string
	.intel_syntax noprefix
	mov	rsp,rbp

	mov	rsi,r12
	mov	rdi,r13

	pop	rbx
	pop	rcx

	sub	rbx,rdi
	sar	rbx,3
	sub	r15,rbx
	.att_syntax
	call	collect_1
	.intel_syntax noprefix
	add	r15,rbx
	.att_syntax
	jmp	__copy__string__to__graph
	.intel_syntax noprefix

__copy__string__to__graph_1:
	mov	rbx,rdi
	mov	rdi,qword ptr [rsp]
	mov	rcx,rax
	sub	rbx,rdi
	sar	rbx,3
	add	r15,rbx
	add	rsp,16
	ret
