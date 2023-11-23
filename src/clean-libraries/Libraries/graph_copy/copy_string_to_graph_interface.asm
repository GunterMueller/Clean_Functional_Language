
_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

extrn	collect_1:near

extrn	copy_string_to_graph:near
extrn	remove_forwarding_pointers_from_string:near

	_TEXT segment

public	__copy__string__to__graph

__copy__string__to__graph:
	push	rcx

	sub	rsp,8

	mov	r12,r9
	mov	r9,rsp
	lea	r8,[rdi+r15*8]
	mov	rdx,rdi
	mov	rbp,rsp
	sub	rsp,40
	or	rsp,8
	call	copy_string_to_graph
	mov	rsp,rbp
	mov	r9,r12

	test	rax,1
	je	__copy__string__to__graph_1

	mov	rcx,qword ptr 8[rsp]
	and	rax,-8

	mov	rdx,rax
	mov	rbp,rsp
	or	rsp,8
	mov	r12,r9
	sub	rsp,40
	call	remove_forwarding_pointers_from_string
	mov	rsp,rbp
	mov	r9,r12

	pop	rbx
	pop	rcx

	sub	rbx,rdi
	sar	rbx,3
	sub	r15,rbx
	call	collect_1
	add	r15,rbx
	jmp	__copy__string__to__graph

__copy__string__to__graph_1:
	mov	rbx,rdi
	mov	rdi,qword ptr [rsp]
	mov	rcx,rax
	sub	rbx,rdi
	sar	rbx,3
	add	r15,rbx
	add	rsp,16
	ret

_TEXT	ends

	end
