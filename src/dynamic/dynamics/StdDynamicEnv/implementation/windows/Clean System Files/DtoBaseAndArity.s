
	.align	4
	.text

	.globl	DtoBaseAndArity
DtoBaseAndArity:
	// input:
	// %eax		= a-stack
	//
	// output:
	// %ebx		= 1st component, descriptor base
	// %eax		= 2nd component, partial arity
	//
	testb	$2,%al
	jne		DtoBaseAndArity_
	
	movl	$ cannot_deal_with_closure,%ecx
	jmp		DtoBaseAndArity_record
	
DtoBaseAndArity_:	
	lea		-2(%eax),%ebp							# %ebp points to partial arity
	movswl	(%ebp),%ebx								# load partial arity in %ebx
	cmp		$256,%ebx								# strict record
	jae		DtoBaseAndArity_record

	shl		$3,%ebx									# %ebx = arity * 8
	sub		%ebx,%ebp								# %ebp = %ebp - %ebx (descriptor_base)
	
DtoBaseAndArity_record:
	movzwl	-2(%eax),%eax
	movl	%ebp,%ebx
	ret
	
	.data
	.align	4
cannot_deal_with_closure:
	.long 	__STRING__
	.long	41
	.ascii "DtoBaseAndArity cannot deal with closures"
//          12345678901234567890123456789012345678901
	.byte 0,0,0,0
	
	.align	4
records_not_checked_yet:
	.long 	__STRING__
	.long	38
	.ascii "DtoBaseAndArity records not yet tested"
//          12345678901234567890123456789012345678901
	.byte 0,0,0,0
	
	
	