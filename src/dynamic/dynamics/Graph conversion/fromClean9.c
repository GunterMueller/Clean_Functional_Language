// fromClean9.c: contents copied and modified from cg.exe
//
// copy_string_to_graph2 :: !String !Int !GlobalDynamicInfoDummy -> (.a,!Int)
// copy_string_to_graph2 adr graph_i gdid
// 		= abort "copy_string_to_graph2"
//
// the code following this code should be the function copy_string_to_graph
// do a find on "graph2" replace by "graph__0x00010101"
	.data
	.align 4
	// module name
m__StdDynamic:
	.long	10
	.ascii	"StdDynamic"
	.byte	0,0
	
	// descriptor
	.align	4
	.long	CLEAN_dcopy_string_to_graph+2
	.globl	CLEAN_dcopy_string_to_graph
CLEAN_dcopy_string_to_graph:
 	.word	0
	.word	56
	.long	yet_args_needed_0
	.word	1
	.word	48
	.long	yet_args_needed_1
	.word	2
	.word	40
	.long	yet_args_needed_2
	.word	3
	.word	32
	.long	yet_args_needed_3
	.word	4
	.word	24
	.long	yet_args_needed_4
	.word	5
	.word	16
	.long	yet_args_needed
	.word	6
	.word	8
	.long	CLEAN_lcopy_string_to_graph
	.word	7
	.word	0
	.word	0
	.word	7
	.long	m__StdDynamic
i_95:
l_39:
	.long	21
	.ascii	"copy_string_to_g"
	.ascii	"raph2"
	.byte	0,0,0
		
	// text
	.text
	.align	8
	jmp		acopy_string_to_graph
	.align	8
	jmp		acopy_string_to_graph
	.align	8
	nop
	nop
	nop
	nop
CLEAN_lcopy_string_to_graph:
	movl	%ecx,(%esi)
	movl	8(%edx),%ecx
	movl	16(%ecx),%ebp
	movl	%ebp,4(%esi)
	movl	12(%ecx),%ebp
	movl	%ebp,8(%esi)
	movl	8(%ecx),%ebp
	movl	%ebp,12(%esi)
	movl	4(%ecx),%ebp
	movl	%ebp,16(%esi)
	movl	(%ecx),%ecx
	movl	4(%edx),%edx
	leal	20(%esi),%esi
acopy_string_to_graph:
	call	eacopy__string__to__graph__0x00010101_P22
	cmpl	end_heap,%edi
	jae	i_183
i_184:
	movl	$INT+2,(%edi)
	movl	%eax,4(%edi)
	movl	%edi,%eax
	movl	$__Tuple+18,8(%edi)
	movl	%ecx,12(%edi)
	movl	%eax,16(%edi)
	leal	8(%edi),%ecx
	addl	$20,%edi
	ret
	
i_183:
	call	collect_1
	jmp	i_184
i_185:
	call	collect_1
	jmp	i_186
	
	.align	4
	.long	CLEAN_dcopy_string_to_graph
	.long	7
	.globl	CLEAN_ncopy_string_to_graph
CLEAN_ncopy_string_to_graph:
	movl	28(%ecx),%ebp
	movl	%ebp,4(%esi)
	movl	24(%ecx),%ebp
	movl	%ebp,8(%esi)
	movl	20(%ecx),%ebp
	movl	%ebp,12(%esi)
	movl	16(%ecx),%ebp
	movl	%ebp,16(%esi)
	movl	12(%ecx),%ebp
	movl	%ebp,20(%esi)
	movl	%ecx,(%esi)
	movl	$__cycle__in__spine,(%ecx)
	movl	4(%ecx),%edx
	movl	8(%ecx),%ecx
	leal	24(%esi),%esi
	call	eacopy__string__to__graph__0x00010101_P22
	cmpl	end_heap,%edi
	jae	i_185
i_186:
	movl	$INT+2,(%edi)
	movl	%eax,4(%edi)
	movl	%edi,%eax
	movl	-4(%esi),%edx
	movl	$__Tuple+18,(%edx)
	movl	%ecx,4(%edx)
	movl	%eax,8(%edx)
	movl	%edx,%ecx
	addl	$8,%edi
	leal	-4(%esi),%esi
	ret
	.globl	CLEAN_scopy_string_to_graph
CLEAN_scopy_string_to_graph:
	pushl	%eax
	movl	-4(%esi),%eax
	movl	4(%eax),%ebp
	movl	%ebp,-4(%esi)
	popl	%eax
	jmp	scopy__string__to__graph__0x00010101_P22
eacopy__string__to__graph__0x00010101_P22:
	movl	%ecx,(%esi)
	movl	%edx,%ecx
	movl	-20(%esi),%edx
	leal	4(%esi),%esi
	testb	$2,(%edx)
	jne	e_38
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_38:
	movl	-20(%esi),%edx
	testb	$2,(%edx)
	jne	e_39
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_39:
	movl	-16(%esi),%edx
	testb	$2,(%edx)
	jne	e_40
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_40:
	movl	-12(%esi),%edx
	testb	$2,(%edx)
	jne	e_41
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_41:
	movl	-8(%esi),%edx
	testb	$2,(%edx)
	jne	e_42
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_42:
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	leal	-4(%esi),%esi
	testb	$2,(%ecx)
	jne	e_43
	movl	%edx,(%esi)
	addl	$4,%esi
	call	*(%ecx)
	movl	-4(%esi),%edx
	subl	$4,%esi
e_43:
	testb	$2,(%edx)
	jne	e_44
	movl	%ecx,(%esi)
	addl	$4,%esi
	movl	%edx,%ecx
	call	*(%edx)
	movl	%ecx,%edx
	movl	-4(%esi),%ecx
	subl	$4,%esi
e_44:
	movl	-20(%esi),%eax
	pushl	4(%eax)
	movl	4(%ecx),%ebx
	movl	-16(%esi),%ecx
	movl	4(%ecx),%eax
	movl	4(%edx),%edx
	movl	-8(%esi),%ecx
	movl	4(%ecx),%ebp
	movl	%ebp,-16(%esi)
	movl	-12(%esi),%ecx
	movl	4(%ecx),%ebp
	movl	%ebp,-20(%esi)
	movl	-4(%esi),%ecx
	movl	4(%ecx),%ecx
	leal	-12(%esi),%esi
scopy__string__to__graph__0x00010101_P22:
	nop
//	int3
	nop
	nop
	nop
	
	