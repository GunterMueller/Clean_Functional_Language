
.globl	copy_graph_to_string
.globl	remove_forwarding_pointers_from_graph
.globl	collect_0

	.text

.globl	__copy__graph__to__string

__copy__graph__to__string:
	str	x8,[x26],#8

__copy__graph__to__string_0:
	mov	x29,x30

	add	x2,x27,x25,lsl #3
	mov	x1,x27
	mov	x0,x8
	bl	copy_graph_to_string

	str	x0,[x28,#-8]!

	add	x1,x27,x25,lsl #3
	ldr	x0,[x26,#-8]
	bl	remove_forwarding_pointers_from_graph

	ldr	x9,[x28],#8

	cmp	x9,#0
	bne	__copy__graph__to__string_1

	add	x6,x25,#1
	sub	x25,x25,x6

	str	x29,[x28,#-8]!
	bl	collect_0
	add	x25,x25,x6
	ldr	x8,[x26,#-8]
	b	__copy__graph__to__string_0

__copy__graph__to__string_1:
	ldr	x6,[x9,#8]
	sub	x26,x26,#8
	mov	x8,x9

	add	x6,x6,#16+7
	and	x5,x6,#-8
	add	x27,x27,x5
	sub	x25,x25,x6,lsr #3

	ldr	x30,[x28],#8
	ret	x29

