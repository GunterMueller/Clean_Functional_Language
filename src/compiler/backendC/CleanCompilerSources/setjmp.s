	.text
	.align 4
	.globl	_setjmp
_setjmp:
	movq	%rbp,(%rcx)
	movq	%rbx,8(%rcx)

	movq	%rsi,32(%rcx)
	movq	%rdi,40(%rcx)
	movq	%rsp,48(%rcx)
	movq	(%rsp),%rdx
	movq	%rdx,56(%rcx)

	movq	%r8,64(%rcx)
	movq	%r9,72(%rcx)
	movq	%r10,80(%rcx)
	movq	%r11,88(%rcx)
	movq	%r12,96(%rcx)
	movq	%r13,104(%rcx)
	movq	%r14,112(%rcx)
	movq	%r15,120(%rcx)

	subq	%rax,%rax
	ret
	.align 4

