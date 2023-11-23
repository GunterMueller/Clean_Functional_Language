
.globl	copy_graph_to_string
.globl	remove_forwarding_pointers_from_graph
.globl	collect_1

	.text

.globl	__copy__graph__to__string

__copy__graph__to__string:
	add	r2,r10,r5,lsl #2
	mov	r1,r10
	mov	r0,r6
	mov	r11,sp
	bic	sp,sp,#4
	bl	copy_graph_to_string
	mov	sp,r11

	str	r0,[sp,#-4]!

	add	r1,r10,r5,lsl #2
	mov	r0,r6
	mov	r11,sp
	bic	sp,sp,#4
	bl	remove_forwarding_pointers_from_graph
	mov	sp,r11

	ldr	r7,[sp],#4

	cmp	r7,#0
	bne	__copy__graph__to__string_1

	add	r4,r5,#1
	sub	r5,r5,r4
	bl	collect_1
	add	r5,r5,r4
	b	__copy__graph__to__string

__copy__graph__to__string_1:
	ldr	r4,[r7,#4]
	mov	r6,r7

	add	r4,r4,#8+3
	and	r3,r4,#-4
	add	r10,r10,r3
	sub	r5,r5,r4,lsr #2
	ldr	pc,[sp],#4

