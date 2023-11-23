	.text
	.align 4
	.globl	_longjmp
	.globl	longjmp
_longjmp:
longjmp:
	movq	48(%rcx),%rsp
	movq	56(%rcx),%rsi

	movq	(%rcx),%rbp
	movq	8(%rcx),%rbx

	movq	%rsi,(%rsp)

	movq	32(%rcx),%rsi
	movq	40(%rcx),%rdi

	movq	64(%rcx),%r8
	movq	72(%rcx),%r9
	movq	80(%rcx),%r10
	movq	88(%rcx),%r11
	movq	96(%rcx),%r12
	movq	104(%rcx),%r13
	movq	112(%rcx),%r14
	movq	120(%rcx),%r15

	movq	%rdx,%rax
	ret
	nop
	.align 4

