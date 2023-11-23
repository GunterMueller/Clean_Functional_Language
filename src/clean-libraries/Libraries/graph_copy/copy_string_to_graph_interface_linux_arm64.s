
.globl	copy_string_to_graph
.globl	remove_forwarding_pointers_from_string
.globl	collect_0

	.text

.globl	__copy__string__to__graph

__copy__string__to__graph:
	str	x8,[x26],#8

__copy__string__to__graph_0:
	mov	x29,x30

	sub	x28,x28,#8

	mov	x3,x28
	add	x2,x27,x25,lsl #3
	mov	x1,x27
	mov	x0,x8
	bl	copy_string_to_graph

	tst	x0,#1
	beq	__copy__string__to__graph_1

	and	x1,x0,#-8
	ldr	x0,[x26,#-8]
	bl	remove_forwarding_pointers_from_string

	ldr	x9,[x28],#8
	sub	x6,x9,x27
	lsr	x6,x6,#3
	sub	x25,x25,x6
	str     x29,[x28,#-8]!
	bl	collect_0
	add	x25,x25,x6
	ldr	x8,[x26,#-8]
	b	__copy__string__to__graph_0

__copy__string__to__graph_1:
	ldr	x16,[x28],#8
	sub	x26,x26,#8
	mov	x8,x0
	sub	x6,x16,x27
	mov	x27,x16
	sub	x25,x25,x6,lsr #3

	ldr	x30,[x28],#8
	ret	x29

