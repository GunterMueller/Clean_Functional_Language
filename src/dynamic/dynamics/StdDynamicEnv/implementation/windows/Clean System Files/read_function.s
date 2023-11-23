
	.text
	.globl read__function

	.align 4
	
# read_function :: !Int -> (!Bool,.a)
read__function:
	movl	%eax,%ecx
	subl    $4,%ecx
	movl	$1,%eax
	ret

	.align	4
