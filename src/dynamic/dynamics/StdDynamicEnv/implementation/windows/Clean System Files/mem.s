	
	.data
buffer:
	.long 0
	.long 0
	
	.text
	.globl read__word
read__word:
	movl	(%eax),%eax
	ret

	.globl read__half__word
read__half__word:
	movzwl	(%eax),%eax
	ret

	.globl read__byte
read__byte:
	movzbl  (%eax),%eax
	ret

	.globl	address__of__buffer
address__of__buffer:
	movl	$buffer,%eax
	ret

	.globl	write__word
write__word:
	movl	%ebx,(%eax)
	ret
	
	.globl	get__module__id
get__module__id:
	movl	-4(%ecx),%eax
	ret
