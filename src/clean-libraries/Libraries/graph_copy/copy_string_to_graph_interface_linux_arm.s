
.globl	collect_1

.globl	copy_string_to_graph
.globl	remove_forwarding_pointers_from_string

	.text

.globl	__copy__string__to__graph

__copy__string__to__graph:
	sub	sp,sp,#4

	mov	r3,sp
	add	r2,r10,r5,lsl #2
	mov	r1,r10
	mov	r0,r6
	mov	r11,sp
	bic	sp,sp,#4
	bl	copy_string_to_graph
	mov	sp,r11

	tst	r0,#1
	beq	__copy__string__to__graph_1

	ldr	r7,[sp],#4
	and	r1,r0,#-4
	mov	r0,r6
	mov	r11,sp
	bic	sp,sp,#4
	bl	remove_forwarding_pointers_from_string
	mov	sp,r11

	sub	r4,r7,r10
	sub	r5,r5,r4
	bl	collect_1
	add	r5,r5,r4
	b	__copy__string__to__graph

__copy__string__to__graph_1:
	ldr	r12,[sp],#4
	mov	r6,r0
	sub	r4,r12,r10
	mov	r10,r12
	sub	r5,r5,r4,lsr #2
	ldr	pc,[sp],#4

