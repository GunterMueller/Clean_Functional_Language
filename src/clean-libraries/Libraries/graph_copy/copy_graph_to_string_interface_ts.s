
.globl	_copy_graph_to_string
.globl	_remove_forwarding_pointers_from_graph
.globl	collect_1l

heap_p_offset		= 112
heap_size_offset	= 136

	.text

.globl	__copy__graph__to__string

__copy__graph__to__string:
	pushl	%ecx

	pushl	heap_size_offset(%edi)
	pushl	heap_p_offset(%edi)
	movl	4(%edi),%ebx
	addl	$32,%ebx
	pushl	%ebx
	pushl	(%edi)
	pushl	%ecx
	call	_copy_graph_to_string
	addl	$20,%esp

	movl	(%esp),%ecx
	pushl	%eax

	movl	4(%edi),%ebx
	addl	$32,%ebx
	pushl	%ebx
	pushl	%ecx
	call	_remove_forwarding_pointers_from_graph
	addl	$8,%esp

	popl	%ecx

	testl	%ecx,%ecx
	jne	__copy__graph__to__string_1

	popl	%ecx

	movl	4(%edi),%ebp
	addl	$4-32+32,%ebp
	call	collect_1l
	jmp	__copy__graph__to__string

__copy__graph__to__string_1:
	addl	$4,%esp

	movl	4(%ecx),%eax
	addl	$8+3,%eax
	andl	$-4,%eax
	addl	%eax,(%edi)

	ret

