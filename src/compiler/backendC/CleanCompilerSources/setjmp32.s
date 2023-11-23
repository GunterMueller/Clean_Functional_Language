	.text
	.align 4
	.globl	_setjmp
	.globl	__setjmp3
_setjmp:
__setjmp3:
	movl	4(%esp),%eax
	movl	%ebp,(%eax)
	movl	%ebx,4(%eax)
	movl	%ecx,8(%eax)
	movl	%edx,12(%eax)
	movl	%esi,16(%eax)
	movl	%edi,20(%eax)
	movl	%esp,24(%eax)
	movl	(%esp),%edx
	movl	%edx,28(%eax)
	movl	12(%eax),%edx
	subl	%eax,%eax
	ret
	.align 4
