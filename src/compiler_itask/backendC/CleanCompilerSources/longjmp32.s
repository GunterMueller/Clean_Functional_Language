	.text
	.align 4
	.globl	_longjmp
_longjmp:
	movl	4(%esp),%edi
	movl	8(%esp),%eax

	movl	24(%edi),%esp
	movl	28(%edi),%esi

	movl	(%edi),%ebp
	movl	4(%edi),%ebx
	movl	8(%edi),%ecx
	movl	12(%edi),%edx

	movl	%esi,(%esp)

	movl	16(%edi),%esi
	movl	20(%edi),%edi
	ret
	nop
	.align 4

