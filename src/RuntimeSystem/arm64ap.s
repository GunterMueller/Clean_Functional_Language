
	.text

	.globl	ap_2
	.globl	ap_3
	.globl	ap_4
	.globl	ap_5
	.globl	ap_6
	.globl	ap_7
	.globl	ap_8
	.globl	ap_9
	.globl	ap_10
	.globl	ap_11
	.globl	ap_12
	.globl	ap_13
	.globl	ap_14
	.globl	ap_15
	.globl	ap_16
	.globl	ap_17
	.globl	ap_18
	.globl	ap_19
	.globl	ap_20
	.globl	ap_21
	.globl	ap_22
	.globl	ap_23
	.globl	ap_24
	.globl	ap_25
	.globl	ap_26
	.globl	ap_27
	.globl	ap_28
	.globl	ap_29
	.globl	ap_30
	.globl	ap_31
	.globl	ap_32

	.globl	add_empty_node_2
	.globl	add_empty_node_3
	.globl	add_empty_node_4
	.globl	add_empty_node_5
	.globl	add_empty_node_6
	.globl	add_empty_node_7
	.globl	add_empty_node_8
	.globl	add_empty_node_9
	.globl	add_empty_node_10
	.globl	add_empty_node_11
	.globl	add_empty_node_12
	.globl	add_empty_node_13
	.globl	add_empty_node_14
	.globl	add_empty_node_15
	.globl	add_empty_node_16
	.globl	add_empty_node_17
	.globl	add_empty_node_18
	.globl	add_empty_node_19
	.globl	add_empty_node_20
	.globl	add_empty_node_21
	.globl	add_empty_node_22
	.globl	add_empty_node_23
	.globl	add_empty_node_24
	.globl	add_empty_node_25
	.globl	add_empty_node_26
	.globl	add_empty_node_27
	.globl	add_empty_node_28
	.globl	add_empty_node_29
	.globl	add_empty_node_30
	.globl	add_empty_node_31
	.globl	add_empty_node_32

	.globl	yet_args_needed
	.globl	yet_args_needed_0
	.globl	yet_args_needed_1
	.globl	yet_args_needed_2
	.globl	yet_args_needed_3
	.globl	yet_args_needed_4
	.globl	yet_args_needed_5
	.globl	yet_args_needed_6
	.globl	yet_args_needed_7
	.globl	yet_args_needed_8
	.globl	yet_args_needed_9
	.globl	yet_args_needed_10
	.globl	yet_args_needed_11
	.globl	yet_args_needed_12
	.globl	yet_args_needed_13
	.globl	yet_args_needed_14
	.globl	yet_args_needed_15
	.globl	yet_args_needed_16
	.globl	yet_args_needed_17
	.globl	yet_args_needed_18
	.globl	yet_args_needed_19
	.globl	yet_args_needed_20
	.globl	yet_args_needed_21
	.globl	yet_args_needed_22
	.globl	yet_args_needed_23
	.globl	yet_args_needed_24
	.globl	yet_args_needed_25
	.globl	yet_args_needed_26
	.globl	yet_args_needed_27
	.globl	yet_args_needed_28
	.globl	yet_args_needed_29
	.globl	yet_args_needed_30
	.globl	yet_args_needed_31

ap_32:
	ldr	x11,[x10]
	mov	x5,#32*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap32

ap_31:
	ldr	x11,[x10]
	mov	x5,#31*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap31

ap_30:
	ldr	x11,[x10]
	mov	x5,#30*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap30

ap_29:
	ldr	x11,[x10]
	mov	x5,#29*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap29

ap_28:
	ldr	x11,[x10]
	mov	x5,#28*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap28

ap_27:
	ldr	x11,[x10]
	mov	x5,#27*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap27

ap_26:
	ldr	x11,[x10]
	mov	x5,#26*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap26

ap_25:
	ldr	x11,[x10]
	mov	x5,#25*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap25

ap_24:
	ldr	x11,[x10]
	mov	x5,#24*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap24

ap_23:
	ldr	x11,[x10]
	mov	x5,#23*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap23

ap_22:
	ldr	x11,[x10]
	mov	x5,#22*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap22

ap_21:
	ldr	x11,[x10]
	mov	x5,#21*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap21

ap_20:
	ldr	x11,[x10]
	mov	x5,#20*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap20

ap_19:
	ldr	x11,[x10]
	mov	x5,#19*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap19

ap_18:
	ldr	x11,[x10]
	mov	x5,#18*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap18

ap_17:
	ldr	x11,[x10]
	mov	x5,#17*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap17

ap_16:
	ldr	x11,[x10]
	mov	x5,#16*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap16

ap_15:
	ldr	x11,[x10]
	mov	x5,#15*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap15

ap_14:
	ldr	x11,[x10]
	mov	x5,#14*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap14

ap_13:
	ldr	x11,[x10]
	mov	x5,#13*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap13

ap_12:
	ldr	x11,[x10]
	mov	x5,#12*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap12

ap_11:
	ldr	x11,[x10]
	mov	x5,#11*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap11

ap_10:
	ldr	x11,[x10]
	mov	x5,#10*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap10

ap_9:
	ldr	x11,[x10]
	mov	x5,#9*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap9

ap_8:
	ldr	x11,[x10]
	mov	x5,#8*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap8

ap_7:
	ldr	x11,[x10]
	mov	x5,#7*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap7

ap_6:
	ldr	x11,[x10]
	mov	x5,#6*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap6

ap_5:
	ldr	x11,[x10]
	mov	x5,#5*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap5

ap_4:
	ldr	x11,[x10]
	mov	x5,#4*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap4

ap_3:
	ldr	x11,[x10]
	mov	x5,#3*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap

	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap3

ap_2:
	ldr	x11,[x10]
	mov	x5,#2*8
	ldrh	w16,[x11]
	cmp	x16,x5
	bne	no_fast_ap2_

fast_ap_2_2_:
	add	x5,x5,x11
	ldrh	w6,[x11,#-2]
	ldr	w4,[x5,#-6]

	mov	x29,x30

.ifdef PROFILE
	sub	x4,x4,#16
.else
	sub	x4,x4,#8
.endif
	cmp	x6,#1
	blo	repl_args_0_2
	beq	repl_args_1

	cmp	x6,#3
	blo	repl_args_2

	str	x9,[x26,#8]
	str	x8,[x26],#16

	ldr	x9,[x10,#16]

	b	fast_ap_

no_fast_ap2_:
	str	x8,[x26],#8
	mov	x8,x9
	mov	x9,x10
	b	no_fast_ap2

fast_ap_2_2:
	mov	x10,x9
	mov	x9,x8
	ldr	x8,[x26,#-8]!
	b	fast_ap_2_2_

fast_ap_2:
	mov	x10,x9
	mov	x9,x8
	ldr	x8,[x26,#-8]!

fast_ap:
	add	x5,x5,x11
	ldrh	w6,[x11,#-2]
	ldr	w4,[x5,#-6]

	mov	x29,x30

.ifdef PROFILE
	sub	x4,x4,#16
.else
	sub	x4,x4,#8
.endif
	cmp	x6,#1
	blo	repl_args_0
	beq	repl_args_1

	cmp	x6,#3
	blo	repl_args_2

	str	x9,[x26,#8]
	str	x8,[x26],#16

	ldr	x9,[x10,#16]

fast_ap_:
	ldr	x10,[x10,#8]
	beq	repl_args_3

	cmp	x6,#5
	blo	repl_args_4
	beq	repl_args_5

	cmp	x6,#7
	blo	repl_args_6

	sub	x6,x6,#2

repl_args_7_:
	ldr	x3,[x9,x6,lsl #3]
	str	x3,[x26],#8
	sub	x6,x6,#1
	cmp	x6,#6-2
	bne	repl_args_7_

repl_args_6:
	ldr	x6,[x9,#32]
	str	x6,[x26],#24
	ldr	x6,[x9,#24]
	str	x6,[x26,#-16]
	ldr	x6,[x9,#16]
	str	x6,[x26,#-8]
	ldr	x8,[x9,#8]
	ldr	x9,[x9]
	br	x4

repl_args_0:
	mov	x10,x9
	mov	x9,x8
	ldr	x8,[x26,#-8]!
repl_args_0_2:
	br	x4

repl_args_1:
	ldr	x10,[x10,#8]
	br	x4

repl_args_2:
	str	x8,[x26],#8
	mov	x8,x9
	ldr	x9,[x10,#16]
	ldr	x10,[x10,#8]
	br	x4

repl_args_3:
	ldr	x8,[x9,#8]
	ldr	x9,[x9]
	br	x4

repl_args_4:
	ldr	x6,[x9,#16]
	str	x6,[x26],#8
	ldr	x8,[x9,#8]
	ldr	x9,[x9]
	br	x4

repl_args_5:
	ldr	x6,[x9,#24]
	str	x6,[x26],#16
	ldr	x6,[x9,#16]
	str	x6,[x26,#-8]
	ldr	x8,[x9,#8]
	ldr	x9,[x9]
	br	x4

no_fast_ap32:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#31*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap31:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#30*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap30:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#29*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap29:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#28*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap28:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#27*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap27:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#26*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap26:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#25*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap25:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#24*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap24:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#23*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap23:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#22*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap22:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#21*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap21:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#20*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap20:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#19*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap19:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#18*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap18:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#17*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap17:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#16*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap16:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#15*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap15:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#14*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap14:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#13*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap13:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#12*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap12:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#11*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap11:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#10*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap10:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#9*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap9:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#8*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap8:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#7*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap7:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#6*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap6:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#5*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap5:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#4*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap4:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#3*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2

no_fast_ap3:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x11,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!

	mov	x5,#2*8
	ldrh	w16,[x11]
	cmp	x16,x5
	beq	fast_ap_2_2

no_fast_ap2:
	ldr	w16,[x11,#2]
	str	x30,[x28,#-8]!
	blr	x16
	ldr	x10,[x8]
	mov	x9,x8
	ldr	x8,[x26,#-8]!
	ldr	w16,[x10,#2]
	br	x16

	.ltorg

add_empty_node_2:
	subs	x25,x25,#3
	blo	add_empty_node_2_gc
add_empty_node_2_gc_:
	adrp	x16,__cycle__in__spine
	mov	x10,x9
	mov	x9,x8
	mov	x8,x27
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_2_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_2
	ldr	x29,[x28],#8
	b	add_empty_node_2_gc_

add_empty_node_3:
	subs	x25,x25,#3
	blo	add_empty_node_3_gc
add_empty_node_3_gc_:
	adrp	x16,__cycle__in__spine
	str	x27,[x26],#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_3_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_3_gc_

add_empty_node_4:
	subs	x25,x25,#3
	blo	add_empty_node_4_gc
add_empty_node_4_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	str	x27,[x26,#-8]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_4_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_4_gc_

add_empty_node_5:
	subs	x25,x25,#3
	blo	add_empty_node_5_gc
add_empty_node_5_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	str	x27,[x26,#-16]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_5_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_5_gc_

add_empty_node_6:
	subs	x25,x25,#3
	blo	add_empty_node_6_gc
add_empty_node_6_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
	str	x27,[x26,#-24]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_6_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_6_gc_

add_empty_node_7:
	subs	x25,x25,#3
	blo	add_empty_node_7_gc
add_empty_node_7_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
	ldr	x11,[x26,#-32]
	str	x11,[x26,#-24]
	str	x27,[x26,#-32]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_7_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_7_gc_

add_empty_node_8:
	subs	x25,x25,#3
	blo	add_empty_node_8_gc
add_empty_node_8_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
	ldr	x11,[x26,#-32]
	str	x11,[x26,#-24]
	ldr	x11,[x26,#-40]
	str	x11,[x26,#-32]
	str	x27,[x26,#-40]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_8_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_8_gc_

add_empty_node_9:
	subs	x25,x25,#3
	blo	add_empty_node_9_gc
add_empty_node_9_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
	ldr	x11,[x26,#-32]
	str	x11,[x26,#-24]
	ldr	x11,[x26,#-40]
	str	x11,[x26,#-32]
	ldr	x11,[x26,#-48]
	str	x11,[x26,#-40]
	str	x27,[x26,#-48]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_9_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_9_gc_

add_empty_node_10:
	subs	x25,x25,#3
	blo	add_empty_node_10_gc
add_empty_node_10_gc_:
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
	ldr	x11,[x26,#-32]
	str	x11,[x26,#-24]
	ldr	x11,[x26,#-40]
	str	x11,[x26,#-32]
	ldr	x11,[x26,#-48]
	str	x11,[x26,#-40]
	ldr	x11,[x26,#-56]
	str	x11,[x26,#-48]
	str	x27,[x26,#-56]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_10_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_10_gc_

add_empty_node_31:
	mov	x5,#7
	b	add_empty_node_11_
add_empty_node_27:
	mov	x5,#6
	b	add_empty_node_11_
add_empty_node_23:
	mov	x5,#5
	b	add_empty_node_11_
add_empty_node_19:
	mov	x5,#4
	b	add_empty_node_11_
add_empty_node_15:
	mov	x5,#3
	b	add_empty_node_11_
add_empty_node_11:
	mov	x5,#2
add_empty_node_11_:
	subs	x25,x25,#3
	blo	add_empty_node_11_gc
add_empty_node_11_gc_:
	mov	x6,x26
add_empty_node_11_lp:
	ldr	x11,[x6,#-8]
	str	x11,[x6]
	ldr	x11,[x6,#-16]
	str	x11,[x6,#-8]
	ldr	x11,[x6,#-24]
	str	x11,[x6,#-16]
	ldr	x11,[x6,#-32]
	str	x11,[x6,#-24]
	sub	x6,x6,#32
	subs	x5,x5,#1
	bne	add_empty_node_11_lp
	str	x27,[x6]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_11_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_11_gc_

add_empty_node_32:
	mov	x5,#7
	b	add_empty_node_12_
add_empty_node_28:
	mov	x5,#6
	b	add_empty_node_12_
add_empty_node_24:
	mov	x5,#5
	b	add_empty_node_12_
add_empty_node_20:
	mov	x5,#4
	b	add_empty_node_12_
add_empty_node_16:
	mov	x5,#3
	b	add_empty_node_12_
add_empty_node_12:
	mov	x5,#2
add_empty_node_12_:
	subs	x25,x25,#3
	blo	add_empty_node_12_gc
add_empty_node_12_gc_:
	mov	x6,x26
	ldr	x11,[x26,#-8]
	str	x11,[x26]
add_empty_node_12_lp:
	ldr	x11,[x6,#-16]
	str	x11,[x6,#-8]
	ldr	x11,[x6,#-24]
	str	x11,[x6,#-16]
	ldr	x11,[x6,#-32]
	str	x11,[x6,#-24]
	ldr	x11,[x6,#-40]
	str	x11,[x6,#-32]!
	subs	x5,x5,#1
	bne	add_empty_node_12_lp
	str	x27,[x6,#-8]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_12_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_12_gc_

add_empty_node_29:
	mov	x5,#6
	b	add_empty_node_13_
add_empty_node_25:
	mov	x5,#5
	b	add_empty_node_13_
add_empty_node_21:
	mov	x5,#4
	b	add_empty_node_13_
add_empty_node_17:
	mov	x5,#3
	b	add_empty_node_13_
add_empty_node_13:
	mov	x5,#2
add_empty_node_13_:
	subs	x25,x25,#3
	blo	add_empty_node_13_gc
add_empty_node_13_gc_:
	mov	x6,x26
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
add_empty_node_13_lp:
	ldr	x11,[x6,#-24]
	str	x11,[x6,#-16]
	ldr	x11,[x6,#-32]
	str	x11,[x6,#-24]
	ldr	x11,[x6,#-40]
	str	x11,[x6,#-32]
	ldr	x11,[x6,#-48]
	str	x11,[x6,#-40]
	sub	x6,x6,#32
	subs	x5,x5,#1
	bne	add_empty_node_13_lp
	str	x27,[x6,#-16]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_13_gc:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_13_gc_

add_empty_node_30:
	mov	x5,#6
	b	add_empty_node_14_
add_empty_node_26:
	mov	x5,#5
	b	add_empty_node_14_
add_empty_node_22:
	mov	x5,#4
	b	add_empty_node_14_
add_empty_node_18:
	mov	x5,#3
	b	add_empty_node_14_
add_empty_node_14:
	mov	x5,#2
	b	add_empty_node_14_
add_empty_node_14_:
	subs	x25,x25,#3
	blo	add_empty_node_14_gc
add_empty_node_14_gc:
	mov	x6,x26
	ldr	x11,[x26,#-8]
	str	x11,[x26]
	ldr	x11,[x26,#-16]
	str	x11,[x26,#-8]
	ldr	x11,[x26,#-24]
	str	x11,[x26,#-16]
add_empty_node_14_lp:
	ldr	x11,[x6,#-32]
	str	x11,[x6,#-24]
	ldr	x11,[x6,#-40]
	str	x11,[x6,#-32]
	ldr	x11,[x6,#-48]
	str	x11,[x6,#-40]
	ldr	x11,[x6,#-56]
	str	x11,[x6,#-48]
	sub	x6,x6,#32
	subs	x5,x5,#1
	bne	add_empty_node_14_lp
	str	x27,[x6,#-24]
	adrp	x16,__cycle__in__spine
	add	x26,x26,#8
	add	x16,x16,#:lo12:__cycle__in__spine
	str	x16,[x27],#24
	mov	x16,x30
	mov	x30,x29
	ret	x16
add_empty_node_14_gc_:
	str	x29,[x28,#-8]!
	str	x30,[x28,#-8]!
	bl	collect_3
	ldr	x29,[x28],#8
	b	add_empty_node_14_gc_

yet_args_needed_0:
	subs	x25,x25,#2
	blo	yet_args_needed_0_gc
yet_args_needed_0_gc_r:
	str	x8,[x27,#8]
	ldr	x6,[x9]
	mov	x8,x27
	add	x6,x6,#8
	str	x6,[x27],#16
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

yet_args_needed_0_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	yet_args_needed_0_gc_r


	.p2align	2
	subs	x25,x25,#3
	b	build_node_2
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_1:
	subs	x25,x25,#3
	blo	yet_args_needed_1_gc
yet_args_needed_1_gc_r:
	str	x8,[x27,#16]
	ldr	x6,[x9]
	mov	x8,x27
	add	x6,x6,#8
	str	x6,[x27]
	ldr	x5,[x9,#8]
	str	x5,[x27,#8]
	add	x27,x27,#24
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

yet_args_needed_1_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	yet_args_needed_1_gc_r

build_node_2:
	blo	build_node_2_gc
build_node_2_gc_r:
	str	x5,[x27]
	str	x9,[x27,#8]
	str	x8,[x27,#16]
	mov	x8,x27
	add	x27,x27,#24
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

build_node_2_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	build_node_2_gc_r


	.p2align	2	
	subs	x25,x25,#5
	b	build_node_3
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_2:
	subs	x25,x25,#5
	blo	gc_22
gc_r_22:
	ldr	x6,[x9]
	str	x8,[x27,#8]
	add	x6,x6,#8
	ldr	x10,[x9,#8]
	str	x6,[x27,#16]
	add	x8,x27,#16
	str	x10,[x27,#24]
	ldr	x10,[x9,#16]
	str	x10,[x27]
	str	x27,[x27,#32]
	add	x27,x27,#40
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_22:	str	x30,[x28,#-8]!
	bl	collect_2
	b	gc_r_22

build_node_3:
	blo	build_node_3_gc
build_node_3_gc_r:
	str	x5,[x27]
	add	x10,x27,#24
	str	x9,[x27,#8]
	str	x10,[x27,#16]
	str	x8,[x27,#24]
	mov	x8,x27
	ldr	x10,[x26,#-8]!
	str	x10,[x27,#32]
	add	x27,x27,#40
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

build_node_3_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	build_node_3_gc_r


	.p2align	2	
	subs	x25,x25,#6
	b	build_node_4
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_3:
	subs	x25,x25,#6
	blo	gc_23
gc_r_23:
	ldr	x6,[x9]
	str	x8,[x27,#16]
	add	x6,x6,#8
	ldr	x10,[x9,#8]
	str	x6,[x27,#24]
	ldr	x9,[x9,#16]
	str	x10,[x27,#32]
	ldr	x10,[x9]
	str	x27,[x27,#40]
	str	x10,[x27]
	ldr	x10,[x9,#8]
	add	x8,x27,#24
	str	x10,[x27,#8]
	add	x27,x27,#48
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_23:	str	x30,[x28,#-8]!
	bl	collect_2
	b	gc_r_23

build_node_4:
	blo	build_node_4_gc
build_node_4_gc_r:
	str	x5,[x27]
	add	x10,x27,#24
	str	x9,[x27,#8]
	str	x10,[x27,#16]
	str	x8,[x27,#24]
	mov	x8,x27
	ldr	x10,[x26,#-8]
	str	x10,[x27,#32]
	ldr	x10,[x26,#-16]!
	str	x10,[x27,#40]
	add	x27,x27,#48
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

build_node_4_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	build_node_4_gc_r


	.p2align	2
	subs	x25,x25,#7
	b	build_node_5
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_4:
	subs	x25,x25,#7
	blo	gc_24
gc_r_24:
	ldr	x6,[x9]
	str	x8,[x27,#24]
	add	x6,x6,#8
	ldr	x10,[x9,#8]
	str	x6,[x27,#32]
	ldr	x9,[x9,#16]
	str	x10,[x27,#40]
	ldr	x10,[x9]
	str	x27,[x27,#48]
	str	x10,[x27]
	ldr	x10,[x9,#8]
	add	x8,x27,#32
	str	x10,[x27,#8]
	ldr	x10,[x9,#16]
	str	x10,[x27,#16]
	add	x27,x27,#56
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

gc_24:	str	x30,[x28,#-8]!
	bl	collect_2
	b	gc_r_24

build_node_5:
	blo	build_node_5_gc
build_node_5_gc_r:
	str	x5,[x27]
	add	x10,x27,#24
	str	x9,[x27,#8]
	str	x10,[x27,#16]
	str	x8,[x27,#24]
	mov	x8,x27
	ldr	x10,[x26,#-8]
	str	x10,[x27,#32]
	ldr	x10,[x26,#-16]
	str	x10,[x27,#40]
	ldr	x10,[x26,#-24]!
	str	x10,[x27,#48]
	add	x27,x27,#56
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

build_node_5_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	build_node_5_gc_r


	.p2align	2	
	mov	x6,#8
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_5:
	ldr	x5,[x9]
	mov	x6,#8
	b	yet_args_needed_


	.p2align	2	
	mov	x6,#9
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_6:
	ldr	x5,[x9]
	mov	x6,#9
	b	yet_args_needed_

	.p2align	2
	mov	x6,#10
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_7:
	ldr	x5,[x9]
	mov	x6,#10
	b	yet_args_needed_

	.p2align	2
	mov	x6,#11
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_8:
	ldr	x5,[x9]
	mov	x6,#11
	b	yet_args_needed_

	.p2align	2
	mov	x6,#12
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_9:
	ldr	x5,[x9]
	mov	x6,#12
	b	yet_args_needed_

	.p2align	2
	mov	x6,#13
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_10:
	ldr	x5,[x9]
	mov	x6,#13
	b	yet_args_needed_

	.p2align	2
	mov	x6,#14
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_11:
	ldr	x5,[x9]
	mov	x6,#14
	b	yet_args_needed_

	.p2align	2
	mov	x6,#15
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_12:
	ldr	x5,[x9]
	mov	x6,#15
	b	yet_args_needed_

	.p2align	2
	mov	x6,#16
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_13:
	ldr	x5,[x9]
	mov	x6,#16
	b	yet_args_needed_

	.p2align	2
	mov	x6,#17
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_14:
	ldr	x5,[x9]
	mov	x6,#17
	b	yet_args_needed_

	.p2align	2
	mov	x6,#18
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_15:
	ldr	x5,[x9]
	mov	x6,#18
	b	yet_args_needed_

	.p2align	2
	mov	x6,#19
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_16:
	ldr	x5,[x9]
	mov	x6,#19
	b	yet_args_needed_

	.p2align	2
	mov	x6,#20
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_17:
	ldr	x5,[x9]
	mov	x6,#20
	b	yet_args_needed_

	.p2align	2
	mov	x6,#21
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_18:
	ldr	x5,[x9]
	mov	x6,#21
	b	yet_args_needed_

	.p2align	2
	mov	x6,#22
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_19:
	ldr	x5,[x9]
	mov	x6,#22
	b	yet_args_needed_

	.p2align	2
	mov	x6,#23
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_20:
	ldr	x5,[x9]
	mov	x6,#23
	b	yet_args_needed_

	.p2align	2
	mov	x6,#24
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_21:
	ldr	x5,[x9]
	mov	x6,#24
	b	yet_args_needed_

	.p2align	2
	mov	x6,#25
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_22:
	ldr	x5,[x9]
	mov	x6,#25
	b	yet_args_needed_

	.p2align	2	
	mov	x6,#26
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_23:
	ldr	x5,[x9]
	mov	x6,#26
	b	yet_args_needed_

	.p2align	2
	mov	x6,#27
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_24:
	ldr	x5,[x9]
	mov	x6,#27
	b	yet_args_needed_

	.p2align	2	
	mov	x6,#28
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_25:
	ldr	x5,[x9]
	mov	x6,#28
	b	yet_args_needed_

	.p2align	2
	mov	x6,#29
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_26:
	ldr	x5,[x9]
	mov	x6,#29
	b	yet_args_needed_

	.p2align	2
	mov	x6,#30
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_27:
	ldr	x5,[x9]
	mov	x6,#30
	b	yet_args_needed_

	.p2align	2
	mov	x6,#31
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_28:
	ldr	x5,[x9]
	mov	x6,#31
	b	yet_args_needed_

	.p2align	2
	mov	x6,#32
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_29:
	ldr	x5,[x9]
	mov	x6,#32
	b	yet_args_needed_

	.p2align	2
	mov	x6,#33
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_30:
	ldr	x5,[x9]
	mov	x6,#33
	b	yet_args_needed_

	.p2align	2
	mov	x6,#34
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_31:
	ldr	x5,[x9]
	mov	x6,#34
	b	yet_args_needed_

yet_args_needed:
# for more than 4 arguments
	ldr	x5,[x9]
	ldrh	w6,[x5,#-2]
	add	x6,x6,#3
yet_args_needed_:
	subs	x25,x25,x6
	blo	yet_args_needed_gc
yet_args_needed_gc_r:
	subs	x6,x6,#3+1+4
	stp	x8,x5,[x28,#-16]!
	ldr	x5,[x9,#8]
	ldr	x9,[x9,#16]
	mov	x10,x27
	ldr	x8,[x9]
	str	x8,[x27]
	ldr	x8,[x9,#8]
	str	x8,[x27,#8]
	ldr	x8,[x9,#16]
	str	x8,[x27,#16]
	add	x9,x9,#24
	add	x27,x27,#24

yet_args_needed_cp_a:
	ldr	x8,[x9],#8
	str	x8,[x27],#8
	subs	x6,x6,#1
	bge	yet_args_needed_cp_a

	ldp	x8,x6,[x28],#16
	str	x8,[x27]
	add	x6,x6,#8
	str	x6,[x27,#8]
	add	x8,x27,#8
	str	x5,[x27,#16]
	str	x10,[x27,#24]
	add	x27,x27,#32
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

yet_args_needed_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	yet_args_needed_gc_r

build_node_:
	subs	x25,x25,x6
	blo	build_node_gc
build_node_gc_r:
	str	x5,[x27]
	add	x10,x27,#24
	str	x9,[x27,#8]
	str	x10,[x27,#16]
	str	x8,[x27,#24]
	mov	x8,x27
	ldr	x10,[x26,#-8]
	str	x10,[x27,#32]
	ldr	x10,[x26,#-16]
	str	x10,[x27,#40]
	ldr	x10,[x26,#-24]!
	str	x10,[x27,#48]
	add	x27,x27,#56

	subs	x6,x6,#5+2
build_node_cp_a:
	ldr	x10,[x26,#-8]!
	str	x10,[x27],#8
	subs	x6,x6,#1
	bne	build_node_cp_a

	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

build_node_gc:
	str	x30,[x28,#-8]!
	bl	collect_2
	b	build_node_gc_r

	.globl	apupd_1
	.globl	apupd_2
	.globl	apupd_3
	.globl	apupd_4
	.globl	apupd_5
	.globl	apupd_6
	.globl	apupd_7
	.globl	apupd_8
	.globl	apupd_9
	.globl	apupd_10
	.globl	apupd_11
	.globl	apupd_12
	.globl	apupd_13
	.globl	apupd_14
	.globl	apupd_15
	.globl	apupd_16
	.globl	apupd_17
	.globl	apupd_18
	.globl	apupd_19
	.globl	apupd_20
	.globl	apupd_21
	.globl	apupd_22
	.globl	apupd_23
	.globl	apupd_24
	.globl	apupd_25
	.globl	apupd_26
	.globl	apupd_27
	.globl	apupd_28
	.globl	apupd_29
	.globl	apupd_30
	.globl	apupd_31
	.globl	apupd_32
	.globl	e__system__nind

apupd_1:
	adr	x10,apupd_upd
	cmp	x30,x10
	bne	ap_1_ap_upd

	ldr	x10,[x26,#-8]
	ldr	x6,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
ap_1:
	ldr	x10,[x9]
	ldr	w16,[x10,#2]
	br	x16

ap_1_ap_upd:
	str	x30,[x28,#-8]!
	bl	ap_1
	b	ap_upd

apupd_2:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_2
	bne	ap_upd

	ldr	x10,[x26,#-16]
	ldr	x6,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_2

apupd_3:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_3
	bne	ap_upd

	ldr	x10,[x26,#-24]
	ldr	x6,[x26,#-32]
	ldr	x5,[x26,#-16]
	str	x5,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_3

apupd_4:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_4
	bne	ap_upd

	ldr	x10,[x26,#-32]
	ldr	x6,[x26,#-40]
	ldr	x5,[x26,#-24]
	str	x5,[x26,#-32]
	ldr	x5,[x26,#-16]
	str	x5,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_4

apupd_5:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_5
	bne	ap_upd

	ldr	x10,[x26,#-40]
	ldr	x6,[x26,#-48]
	ldr	x5,[x26,#-32]
	str	x5,[x26,#-40]
	ldr	x5,[x26,#-24]
	str	x5,[x26,#-32]
	ldr	x5,[x26,#-16]
	str	x5,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_5

apupd_6:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_6
	bne	ap_upd

	ldr	x10,[x26,#-48]
	ldr	x6,[x26,#-56]
	ldr	x5,[x26,#-40]
	str	x5,[x26,#-48]
	ldr	x5,[x26,#-32]
	str	x5,[x26,#-40]
	ldr	x5,[x26,#-24]
	str	x5,[x26,#-32]
	ldr	x5,[x26,#-16]
	str	x5,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_6

apupd_7:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_7
	bne	ap_upd

	ldr	x10,[x26,#-56]
	ldr	x6,[x26,#-64]
	str	x30,[x28,#-8]!
	bl	move_8
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_7

apupd_8:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_8
	bne	ap_upd

	ldr	x10,[x26,#-64]
	ldr	x6,[x26,#-72]
	str	x30,[x28,#-8]!
	bl	move_9
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_8

apupd_9:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_9
	bne	ap_upd

	ldr	x10,[x26,#-72]
	ldr	x6,[x26,#-80]
	str	x30,[x28,#-8]!
	bl	move_10
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_9

apupd_10:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_10
	bne	ap_upd

	ldr	x10,[x26,#-80]
	ldr	x6,[x26,#-88]
	str	x30,[x28,#-8]!
	bl	move_11
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_10

apupd_11:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_11
	bne	ap_upd

	ldr	x10,[x26,#-88]
	ldr	x6,[x26,#-96]
	str	x30,[x28,#-8]!
	bl	move_12
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_11

apupd_12:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_12
	bne	ap_upd

	ldr	x10,[x26,#-96]
	ldr	x6,[x26,#-104]
	str	x30,[x28,#-8]!
	bl	move_13
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_12

apupd_13:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_13
	bne	ap_upd

	ldr	x10,[x26,#-104]
	ldr	x6,[x26,#-112]
	str	x30,[x28,#-8]!
	bl	move_14
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_13

apupd_14:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_14
	bne	ap_upd

	ldr	x10,[x26,#-112]
	ldr	x6,[x26,#-120]
	str	x30,[x28,#-8]!
	bl	move_14
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_14

apupd_15:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_15
	bne	ap_upd

	ldr	x10,[x26,#-120]
	ldr	x6,[x26,#-128]
	str	x30,[x28,#-8]!
	bl	move_16
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_15

apupd_16:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_16
	bne	ap_upd

	ldr	x10,[x26,#-128]
	ldr	x6,[x26,#-136]
	str	x30,[x28,#-8]!
	bl	move_17
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_16

apupd_17:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_17
	bne	ap_upd

	ldr	x10,[x26,#-136]
	ldr	x6,[x26,#-144]
	str	x30,[x28,#-8]!
	bl	move_18
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_17

apupd_18:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_18
	bne	ap_upd

	ldr	x10,[x26,#-144]
	ldr	x6,[x26,#-152]
	str	x30,[x28,#-8]!
	bl	move_19
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_18

apupd_19:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_19
	bne	ap_upd

	ldr	x10,[x26,#-152]
	ldr	x6,[x26,#-160]
	str	x30,[x28,#-8]!
	bl	move_20
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_19

apupd_20:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_20
	bne	ap_upd

	ldr	x10,[x26,#-160]
	ldr	x6,[x26,#-168]
	str	x30,[x28,#-8]!
	bl	move_21
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_20

apupd_21:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_21
	bne	ap_upd

	ldr	x10,[x26,#-168]
	ldr	x6,[x26,#-176]
	str	x30,[x28,#-8]!
	bl	move_22
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_21

apupd_22:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_22
	bne	ap_upd

	ldr	x10,[x26,#-176]
	ldr	x6,[x26,#-184]
	str	x30,[x28,#-8]!
	bl	move_23
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_22

apupd_23:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_23
	bne	ap_upd

	ldr	x10,[x26,#-184]
	ldr	x6,[x26,#-192]
	str	x30,[x28,#-8]!
	bl	move_24
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_23

apupd_24:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_24
	bne	ap_upd

	ldr	x10,[x26,#-192]
	ldr	x6,[x26,#-200]
	str	x30,[x28,#-8]!
	bl	move_25
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_24

apupd_25:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_25
	bne	ap_upd

	ldr	x10,[x26,#-200]
	ldr	x6,[x26,#-208]
	str	x30,[x28,#-8]!
	bl	move_26
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_25

apupd_26:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_26
	bne	ap_upd

	ldr	x10,[x26,#-208]
	ldr	x6,[x26,#-216]
	str	x30,[x28,#-8]!
	bl	move_27
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_26

apupd_27:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_27
	bne	ap_upd

	ldr	x10,[x26,#-216]
	ldr	x6,[x26,#-224]
	str	x30,[x28,#-8]!
	bl	move_28
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_27

apupd_28:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_28
	bne	ap_upd

	ldr	x10,[x26,#-224]
	ldr	x6,[x26,#-232]
	str	x30,[x28,#-8]!
	bl	move_29
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_28

apupd_29:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_29
	bne	ap_upd

	ldr	x10,[x26,#-232]
	ldr	x6,[x26,#-240]
	str	x30,[x28,#-8]!
	bl	move_30
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_29

apupd_30:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_30
	bne	ap_upd

	ldr	x10,[x26,#-240]
	ldr	x6,[x26,#-248]
	str	x30,[x28,#-8]!
	bl	move_31
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_30

apupd_31:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_31
	bne	ap_upd

	ldr	x10,[x26,#-248]
	ldr	x6,[x26,#-256]
	str	x30,[x28,#-8]!
	bl	move_32
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_31

apupd_32:
	adr	x10,apupd_upd
	cmp	x30,x10
	adr	x10,ap_32
	bne	ap_upd
	
	sub	x16,x26,#-264
	ldr	x10,[x26,#-256]
	ldr	x6,[x16]
	str	x30,[x28,#-8]!
	bl	move_33
	adrp	x16,e__system__nind
	add	x16,x16,#:lo12:e__system__nind
	str	x16,[x10]
	sub	x26,x26,#8
	str	x6,[x10,#8]
	b	ap_32

ap_upd:
	str	x30,[x28,#-8]!
	blr	x10
apupd_upd:
	ldr	x9,[x26,#-8]!
	ldr	x6,[x8]
	str	x6,[x9]
	ldr	x6,[x8,#8]
	str	x6,[x9,#8]
	ldr	x6,[x8,#16]
	mov	x8,x9
	str	x6,[x9,#16]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29

move_33:
	ldr	x5,[x26,#-248]
	str	x5,[x26,#-256]
move_32:
	ldr	x5,[x26,#-240]
	str	x5,[x26,#-248]
move_31:
	ldr	x5,[x26,#-232]
	str	x5,[x26,#-240]
move_30:
	ldr	x5,[x26,#-224]
	str	x5,[x26,#-232]
move_29:
	ldr	x5,[x26,#-216]
	str	x5,[x26,#-224]
move_28:
	ldr	x5,[x26,#-208]
	str	x5,[x26,#-216]
move_27:
	ldr	x5,[x26,#-200]
	str	x5,[x26,#-208]
move_26:
	ldr	x5,[x26,#-192]
	str	x5,[x26,#-200]
move_25:
	ldr	x5,[x26,#-184]
	str	x5,[x26,#-192]
move_24:
	ldr	x5,[x26,#-176]
	str	x5,[x26,#-184]
move_23:
	ldr	x5,[x26,#-168]
	str	x5,[x26,#-176]
move_22:
	ldr	x5,[x26,#-160]
	str	x5,[x26,#-168]
move_21:
	ldr	x5,[x26,#-152]
	str	x5,[x26,#-160]
move_20:
	ldr	x5,[x26,#-144]
	str	x5,[x26,#-152]
move_19:
	ldr	x5,[x26,#-136]
	str	x5,[x26,#-144]
move_18:
	ldr	x5,[x26,#-128]
	str	x5,[x26,#-136]
move_17:
	ldr	x5,[x26,#-120]
	str	x5,[x26,#-128]
move_16:
	ldr	x5,[x26,#-112]
	str	x5,[x26,#-120]
move_15:
	ldr	x5,[x26,#-104]
	str	x5,[x26,#-112]
move_14:
	ldr	x5,[x26,#-96]
	str	x5,[x26,#-104]
move_13:
	ldr	x5,[x26,#-88]
	str	x5,[x26,#-96]
move_12:
	ldr	x5,[x26,#-80]
	str	x5,[x26,#-88]
move_11:
	ldr	x5,[x26,#-72]
	str	x5,[x26,#-80]
move_10:
	ldr	x5,[x26,#-64]
	str	x5,[x26,#-72]
move_9:
	ldr	x5,[x26,#-56]
	str	x5,[x26,#-64]
move_8:
	ldr	x5,[x26,#-48]
	str	x5,[x26,#-56]
move_7:
	ldr	x5,[x26,#-40]
	str	x5,[x26,#-48]
	ldr	x5,[x26,#-32]
	str	x5,[x26,#-40]
	ldr	x5,[x26,#-24]
	str	x5,[x26,#-32]
	ldr	x5,[x26,#-16]
	str	x5,[x26,#-24]
	ldr	x5,[x26,#-8]
	str	x5,[x26,#-16]
	mov	x29,x30
	ldr	x30,[x28],#8
	ret	x29
