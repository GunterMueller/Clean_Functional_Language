
	.data
	.globl	heap_size
heap_size:
	.long	2<<20
	.globl	ab_stack_size
ab_stack_size:
	.long	512<<10
	.globl	flags
flags:
	.long	0
	.globl	initial_heap_size
initial_heap_size:
	.long	256<<10
	.globl	heap_size_multiple
heap_size_multiple:
	.long	4<<8


