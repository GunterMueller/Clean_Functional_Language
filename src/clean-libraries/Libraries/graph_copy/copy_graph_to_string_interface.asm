
_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

extrn	copy_graph_to_string:near
extrn	remove_forwarding_pointers_from_graph:near
extrn	collect_1:near

 if THREAD
heap_p_offset			= 192
heap_size_offset		= 280
 endif

	_TEXT segment

public	__copy__graph__to__string

__copy__graph__to__string:
	push	rcx

 if THREAD
 	mov	rax,qword ptr heap_p_offset[r9]
 	mov	rbx,qword ptr heap_size_offset[r9]
 endif
	mov	rdx,rdi
	lea	r8,[rdi+r15*8]
	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r12,r9
	sub	rsp,48
	mov	qword ptr 32[rsp],rbx 	
 	mov	r9,rax
 else
	sub	rsp,40
 endif
	call	copy_graph_to_string
	mov	rsp,rbp
 if THREAD
	mov	r9,r12
 endif
	mov	rcx,qword ptr [rsp]
	push	rax

	lea	rdx,[rdi+r15*8]
	mov	rbp,rsp
	or	rsp,8
 if THREAD
	mov	r12,r9
 endif
	sub	rsp,40
	call	remove_forwarding_pointers_from_graph
	mov	rsp,rbp
 if THREAD
	mov	r9,r12
 endif
	pop	rcx

	test	rcx,rcx
	jne	__copy__graph__to__string_1

	pop	rcx

	lea	rbx,1[r15]
	sub	r15,rbx
	call	collect_1
	add	r15,rbx
	jmp	__copy__graph__to__string

__copy__graph__to__string_1:
	add	rsp,8

	mov	rax,qword ptr 8[rcx]
	add	rax,16+7
	and	rax,-8
	add	rdi,rax
	sar	rax,3
	sub	r15,rax
	ret

_TEXT	ends

	end
