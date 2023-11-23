	
	.data
	.long 0
	.long 0
	
	.text
	.globl _createsharedstring
_createsharedstring:
	movl	$__STRING__+2,(%ebx)
	movl	%eax,4(%ebx)
	movl	%ebx,%eax	
	ret
        int3
