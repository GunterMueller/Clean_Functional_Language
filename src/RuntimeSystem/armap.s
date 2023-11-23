
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
	ldr	r11,[r8]
	mov	r3,#32*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap32

ap_31:
	ldr	r11,[r8]
	mov	r3,#31*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap31

ap_30:
	ldr	r11,[r8]
	mov	r3,#30*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap30

ap_29:
	ldr	r11,[r8]
	mov	r3,#29*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap29

ap_28:
	ldr	r11,[r8]
	mov	r3,#28*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap28

ap_27:
	ldr	r11,[r8]
	mov	r3,#27*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap27

ap_26:
	ldr	r11,[r8]
	mov	r3,#26*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap26

ap_25:
	ldr	r11,[r8]
	mov	r3,#25*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap25

ap_24:
	ldr	r11,[r8]
	mov	r3,#24*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap24

ap_23:
	ldr	r11,[r8]
	mov	r3,#23*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap23

ap_22:
	ldr	r11,[r8]
	mov	r3,#22*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap22

ap_21:
	ldr	r11,[r8]
	mov	r3,#21*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap21

ap_20:
	ldr	r11,[r8]
	mov	r3,#20*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap20

ap_19:
	ldr	r11,[r8]
	mov	r3,#19*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap19

ap_18:
	ldr	r11,[r8]
	mov	r3,#18*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap18

ap_17:
	ldr	r11,[r8]
	mov	r3,#17*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap17

ap_16:
	ldr	r11,[r8]
	mov	r3,#16*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap16

ap_15:
	ldr	r11,[r8]
	mov	r3,#15*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap15

ap_14:
	ldr	r11,[r8]
	mov	r3,#14*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap14

ap_13:
	ldr	r11,[r8]
	mov	r3,#13*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap13

ap_12:
	ldr	r11,[r8]
	mov	r3,#12*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap12

ap_11:
	ldr	r11,[r8]
	mov	r3,#11*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap11

ap_10:
	ldr	r11,[r8]
	mov	r3,#10*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap10

ap_9:
	ldr	r11,[r8]
	mov	r3,#9*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap9

ap_8:
	ldr	r11,[r8]
	mov	r3,#8*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap8

ap_7:
	ldr	r11,[r8]
	mov	r3,#7*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap7

ap_6:
	ldr	r11,[r8]
	mov	r3,#6*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap6

ap_5:
	ldr	r11,[r8]
	mov	r3,#5*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap5

ap_4:
	ldr	r11,[r8]
	mov	r3,#4*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap4

ap_3:
	ldr	r11,[r8]
	mov	r3,#3*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap

	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap3

ap_2:
	ldr	r11,[r8]
	mov	r3,#2*8
	ldrh	r12,[r11]
	cmp	r12,r3
	bne	no_fast_ap2_

fast_ap_2_2_:
	add	r3,r3,r11
	ldrh	r4,[r11,#-2]
	ldr	r2,[r3,#-6]
.ifdef PROFILE
	sub	r2,r2,#16
.else
	sub	r2,r2,#8
.endif
	cmp	r4,#1
	blo	repl_args_0_2
	beq	repl_args_1

	cmp	r4,#3
	blo	repl_args_2

	str	r7,[r9,#4]
	str	r6,[r9],#8

	ldr	r7,[r8,#8]

	b	fast_ap_

no_fast_ap2_:
	str	r6,[r9],#4
	mov	r6,r7
	mov	r7,r8
	b	no_fast_ap2

fast_ap_2_2:
	mov	r8,r7
	mov	r7,r6
	ldr	r6,[r9,#-4]!
	b	fast_ap_2_2_

fast_ap_2:
	mov	r8,r7
	mov	r7,r6
	ldr	r6,[r9,#-4]!

fast_ap:
	add	r3,r3,r11
	ldrh	r4,[r11,#-2]
	ldr	r2,[r3,#-6]
.ifdef PROFILE
	sub	r2,r2,#16
.else
	sub	r2,r2,#8
.endif
	cmp	r4,#1
	blo	repl_args_0
	beq	repl_args_1

	cmp	r4,#3
	blo	repl_args_2

	str	r7,[r9,#4]
	str	r6,[r9],#8

	ldr	r7,[r8,#8]

fast_ap_:
	ldr	r8,[r8,#4]
	beq	repl_args_3

	cmp	r4,#5
	blo	repl_args_4
	beq	repl_args_5

	cmp	r4,#7
	blo	repl_args_6

	sub	r4,r4,#2

repl_args_7_:
	ldr	r1,[r7,r4,lsl #2]
	str	r1,[r9],#4
	sub	r4,r4,#1
	cmp	r4,#6-2
	bne	repl_args_7_

repl_args_6:
	ldr	r4,[r7,#16]
	str	r4,[r9],#12
	ldr	r4,[r7,#12]
	str	r4,[r9,#-8]
	ldr	r4,[r7,#8]
	str	r4,[r9,#-4]
	ldr	r6,[r7,#4]
	ldr	r7,[r7]
	bx	r2

repl_args_0:
	mov	r8,r7
	mov	r7,r6
	ldr	r6,[r9,#-4]!
repl_args_0_2:
	bx	r2

repl_args_1:
	ldr	r8,[r8,#4]
	bx	r2

repl_args_2:
	str	r6,[r9],#4
	mov	r6,r7
	ldr	r7,[r8,#8]
	ldr	r8,[r8,#4]
	bx	r2

repl_args_3:
	ldr	r6,[r7,#4]
	ldr	r7,[r7]
	bx	r2

repl_args_4:
	ldr	r4,[r7,#8]
	str	r4,[r9],#4
	ldr	r6,[r7,#4]
	ldr	r7,[r7]
	bx	r2

repl_args_5:
	ldr	r4,[r7,#12]
	str	r4,[r9],#8
	ldr	r4,[r7,#8]
	str	r4,[r9,#-4]
	ldr	r6,[r7,#4]
	ldr	r7,[r7]
	bx	r2

no_fast_ap32:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#31*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap31:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#30*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap30:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#29*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap29:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#28*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap28:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#27*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap27:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#26*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap26:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#25*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap25:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#24*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap24:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#23*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap23:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#22*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap22:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#21*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap21:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#20*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap20:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#19*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap19:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#18*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap18:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#17*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap17:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#16*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap16:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#15*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap15:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#14*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap14:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#13*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap13:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#12*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap12:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#11*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap11:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#10*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap10:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#9*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap9:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#8*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap8:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#7*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap7:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#6*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap6:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#5*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap5:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#4*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap4:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#3*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2

no_fast_ap3:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r11,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!

	mov	r3,#2*8
	ldrh	r12,[r11]
	cmp	r12,r3
	beq	fast_ap_2_2

no_fast_ap2:
	ldr	r12,[r11,#2]
	str	pc,[sp,#-4]!
	blx	r12
	ldr	r8,[r6]
	mov	r7,r6
	ldr	r6,[r9,#-4]!
	ldr	r12,[r8,#2]
	bx	r12

	.ltorg

add_empty_node_2:
	subs	r5,r5,#3
	blo	add_empty_node_2_gc
add_empty_node_2_gc_:
	lao	r12,__cycle__in__spine,1
	mov	r8,r7
	mov	r7,r6
	mov	r6,r10
	otoa	r12,__cycle__in__spine,1
	str	r12,[r10],#12
	bx	lr
add_empty_node_2_gc:
	str	lr,[sp,#-4]!
	bl	collect_2
	ldr	lr,[sp],#4
	b	add_empty_node_2_gc_

add_empty_node_3:
	subs	r5,r5,#3
	blo	add_empty_node_3_gc
add_empty_node_3_gc_:
	lao	r12,__cycle__in__spine,2
	str	r10,[r9],#4
	otoa	r12,__cycle__in__spine,2
	str	r12,[r10],#12
	bx	lr
add_empty_node_3_gc:
	str	lr,[sp,#-4]!
	bl	collect_3
	ldr	lr,[sp],#4
	b	add_empty_node_3_gc_

add_empty_node_4:
	subs	r5,r5,#3
	blo	add_empty_node_4_gc
add_empty_node_4_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	str	r10,[r9,#-4]
	lao	r12,__cycle__in__spine,3
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,3
	str	r12,[r10],#12
	bx	lr
add_empty_node_4_gc:
	str	lr,[sp,#-4]!
	bl	collect_3
	ldr	lr,[sp],#4
	b	add_empty_node_4_gc_

add_empty_node_5:
	subs	r5,r5,#3
	blo	add_empty_node_5_gc
add_empty_node_5_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	str	r10,[r9,#-8]
	lao	r12,__cycle__in__spine,4
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,4
	str	r12,[r10],#12
	bx	lr
add_empty_node_5_gc:
	str	lr,[sp,#-4]!
	bl	collect_3
	ldr	lr,[sp],#4
	b	add_empty_node_5_gc_

add_empty_node_6:
	subs	r5,r5,#3
	blo	add_empty_node_6_gc
add_empty_node_6_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
	str	r10,[r9,#-12]
	lao	r12,__cycle__in__spine,5
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,5
	str	r12,[r10],#12
	bx	lr
add_empty_node_6_gc:
	bl	collect_3
	b	add_empty_node_6_gc_

add_empty_node_7:
	subs	r5,r5,#3
	blo	add_empty_node_7_gc
add_empty_node_7_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
	ldr	r11,[r9,#-16]
	str	r11,[r9,#-12]
	str	r10,[r9,#-16]
	lao	r12,__cycle__in__spine,6
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,6
	str	r12,[r10],#12
	bx	lr
add_empty_node_7_gc:
	bl	collect_3
	b	add_empty_node_7_gc_

add_empty_node_8:
	subs	r5,r5,#3
	blo	add_empty_node_8_gc
add_empty_node_8_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
	ldr	r11,[r9,#-16]
	str	r11,[r9,#-12]
	ldr	r11,[r9,#-20]
	str	r11,[r9,#-16]
	str	r10,[r9,#-20]
	lao	r12,__cycle__in__spine,7
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,7
	str	r12,[r10],#12
	bx	lr
add_empty_node_8_gc:
	bl	collect_3
	b	add_empty_node_8_gc_

add_empty_node_9:
	subs	r5,r5,#3
	blo	add_empty_node_9_gc
add_empty_node_9_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
	ldr	r11,[r9,#-16]
	str	r11,[r9,#-12]
	ldr	r11,[r9,#-20]
	str	r11,[r9,#-16]
	ldr	r11,[r9,#-24]
	str	r11,[r9,#-20]
	str	r10,[r9,#-24]
	lao	r12,__cycle__in__spine,8
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,8
	str	r12,[r10],#12
	bx	lr
add_empty_node_9_gc:
	bl	collect_3
	b	add_empty_node_9_gc_

add_empty_node_10:
	subs	r5,r5,#3
	blo	add_empty_node_10_gc
add_empty_node_10_gc_:
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
	ldr	r11,[r9,#-16]
	str	r11,[r9,#-12]
	ldr	r11,[r9,#-20]
	str	r11,[r9,#-16]
	ldr	r11,[r9,#-24]
	str	r11,[r9,#-20]
	ldr	r11,[r9,#-28]
	str	r11,[r9,#-24]
	str	r10,[r9,#-28]
	lao	r12,__cycle__in__spine,9
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,9
	str	r12,[r10],#12
	bx	lr
add_empty_node_10_gc:
	bl	collect_3
	b	add_empty_node_10_gc_

add_empty_node_31:
	mov	r3,#7
	b	add_empty_node_11_
add_empty_node_27:
	mov	r3,#6
	b	add_empty_node_11_
add_empty_node_23:
	mov	r3,#5
	b	add_empty_node_11_
add_empty_node_19:
	mov	r3,#4
	b	add_empty_node_11_
add_empty_node_15:
	mov	r3,#3
	b	add_empty_node_11_
add_empty_node_11:
	mov	r3,#2
add_empty_node_11_:
	subs	r5,r5,#3
	blo	add_empty_node_11_gc
add_empty_node_11_gc_:
	mov	r4,r9
add_empty_node_11_lp:
	ldr	r11,[r4,#-4]
	str	r11,[r4]
	ldr	r11,[r4,#-8]
	str	r11,[r4,#-4]
	ldr	r11,[r4,#-12]
	str	r11,[r4,#-8]
	ldr	r11,[r4,#-16]
	str	r11,[r4,#-12]
	sub	r4,r4,#16
	subs	r3,r3,#1
	bne	add_empty_node_11_lp
	str	r10,[r4]
	lao	r12,__cycle__in__spine,10
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,10
	str	r12,[r10],#12
	bx	lr
add_empty_node_11_gc:
	bl	collect_3
	b	add_empty_node_11_gc_

add_empty_node_32:
	mov	r3,#7
	b	add_empty_node_12_
add_empty_node_28:
	mov	r3,#6
	b	add_empty_node_12_
add_empty_node_24:
	mov	r3,#5
	b	add_empty_node_12_
add_empty_node_20:
	mov	r3,#4
	b	add_empty_node_12_
add_empty_node_16:
	mov	r3,#3
	b	add_empty_node_12_
add_empty_node_12:
	mov	r3,#2
add_empty_node_12_:
	subs	r5,r5,#3
	blo	add_empty_node_12_gc
add_empty_node_12_gc_:
	mov	r4,r9
	ldr	r11,[r9,#-4]
	str	r11,[r9]
add_empty_node_12_lp:
	ldr	r11,[r4,#-8]
	str	r11,[r4,#-4]
	ldr	r11,[r4,#-12]
	str	r11,[r4,#-8]
	ldr	r11,[r4,#-16]
	str	r11,[r4,#-12]
	ldr	r11,[r4,#-20]
	str	r11,[r4,#-16]!
	subs	r3,r3,#1
	bne	add_empty_node_12_lp
	str	r10,[r4,#-4]
	lao	r12,__cycle__in__spine,11
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,11
	str	r12,[r10],#12
	bx	lr
add_empty_node_12_gc:
	bl	collect_3
	b	add_empty_node_12_gc_

add_empty_node_29:
	mov	r3,#6
	b	add_empty_node_13_
add_empty_node_25:
	mov	r3,#5
	b	add_empty_node_13_
add_empty_node_21:
	mov	r3,#4
	b	add_empty_node_13_
add_empty_node_17:
	mov	r3,#3
	b	add_empty_node_13_
add_empty_node_13:
	mov	r3,#2
add_empty_node_13_:
	subs	r5,r5,#3
	blo	add_empty_node_13_gc
add_empty_node_13_gc_:
	mov	r4,r9
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
add_empty_node_13_lp:
	ldr	r11,[r4,#-12]
	str	r11,[r4,#-8]
	ldr	r11,[r4,#-16]
	str	r11,[r4,#-12]
	ldr	r11,[r4,#-20]
	str	r11,[r4,#-16]
	ldr	r11,[r4,#-24]
	str	r11,[r4,#-20]
	sub	r4,r4,#16
	subs	r3,r3,#1
	bne	add_empty_node_13_lp
	str	r10,[r4,#-8]
	lao	r12,__cycle__in__spine,12
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,12
	str	r12,[r10],#12
	bx	lr
add_empty_node_13_gc:
	bl	collect_3
	b	add_empty_node_13_gc_

add_empty_node_30:
	mov	r3,#6
	b	add_empty_node_14_
add_empty_node_26:
	mov	r3,#5
	b	add_empty_node_14_
add_empty_node_22:
	mov	r3,#4
	b	add_empty_node_14_
add_empty_node_18:
	mov	r3,#3
	b	add_empty_node_14_
add_empty_node_14:
	mov	r3,#2
	b	add_empty_node_14_
add_empty_node_14_:
	subs	r5,r5,#3
	blo	add_empty_node_14_gc
add_empty_node_14_gc:
	mov	r4,r9
	ldr	r11,[r9,#-4]
	str	r11,[r9]
	ldr	r11,[r9,#-8]
	str	r11,[r9,#-4]
	ldr	r11,[r9,#-12]
	str	r11,[r9,#-8]
add_empty_node_14_lp:
	ldr	r11,[r4,#-16]
	str	r11,[r4,#-12]
	ldr	r11,[r4,#-20]
	str	r11,[r4,#-16]
	ldr	r11,[r4,#-24]
	str	r11,[r4,#-20]
	ldr	r11,[r4,#-28]
	str	r11,[r4,#-24]
	sub	r4,r4,#16
	subs	r3,r3,#1
	bne	add_empty_node_14_lp
	str	r10,[r4,#-12]
	lao	r12,__cycle__in__spine,13
	add	r9,r9,#4
	otoa	r12,__cycle__in__spine,13
	str	r12,[r10],#12
	bx	lr
add_empty_node_14_gc_:
	bl	collect_3
	b	add_empty_node_14_gc_

.ifdef PIC
	lto	__cycle__in__spine,1
	lto	__cycle__in__spine,2
	lto	__cycle__in__spine,3
	lto	__cycle__in__spine,4
	lto	__cycle__in__spine,5
	lto	__cycle__in__spine,6
	lto	__cycle__in__spine,7
	lto	__cycle__in__spine,8
	lto	__cycle__in__spine,9
	lto	__cycle__in__spine,10
	lto	__cycle__in__spine,11
	lto	__cycle__in__spine,12
	lto	__cycle__in__spine,13
.endif
	.ltorg

yet_args_needed_0:
	subs	r5,r5,#2
	blo	yet_args_needed_0_gc
yet_args_needed_0_gc_r:
	str	r6,[r10,#4]
	ldr	r4,[r7]
	mov	r6,r10
	add	r4,r4,#8
	str	r4,[r10],#8
	ldr	pc,[sp],#4

yet_args_needed_0_gc:
	bl	collect_2
	b	yet_args_needed_0_gc_r


	.p2align	2
	subs	r5,r5,#3
	b	build_node_2
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_1:
	subs	r5,r5,#3
	blo	yet_args_needed_1_gc
yet_args_needed_1_gc_r:
	str	r6,[r10,#8]
	ldr	r4,[r7]
	mov	r6,r10
	add	r4,r4,#8
	str	r4,[r10]
	ldr	r3,[r7,#4]
	str	r3,[r10,#4]
	add	r10,r10,#12
	ldr	pc,[sp],#4

yet_args_needed_1_gc:
	bl	collect_2
	b	yet_args_needed_1_gc_r

build_node_2:
	blo	build_node_2_gc
build_node_2_gc_r:
	str	r3,[r10]
	str	r7,[r10,#4]
	str	r6,[r10,#8]
	mov	r6,r10
	add	r10,r10,#12
	ldr	pc,[sp],#4

build_node_2_gc:
	bl	collect_2
	b	build_node_2_gc_r


	.p2align	2	
	subs	r5,r5,#5
	b	build_node_3
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_2:
	subs	r5,r5,#5
	blo	gc_22
gc_r_22:
	ldr	r4,[r7]
	str	r6,[r10,#4]
	add	r4,r4,#8
	ldr	r8,[r7,#4]
	str	r4,[r10,#8]
	add	r6,r10,#8
	str	r8,[r10,#12]
	ldr	r8,[r7,#8]
	str	r8,[r10]
	str	r10,[r10,#16]
	add	r10,r10,#20
	ldr	pc,[sp],#4

gc_22:	bl	collect_2
	b	gc_r_22

build_node_3:
	blo	build_node_3_gc
build_node_3_gc_r:
	str	r3,[r10]
	add	r8,r10,#12
	str	r7,[r10,#4]
	str	r8,[r10,#8]
	str	r6,[r10,#12]
	mov	r6,r10
	ldr	r8,[r9,#-4]
	subs	r9,r9,#4
	str	r8,[r10,#16]
	add	r10,r10,#20
	ldr	pc,[sp],#4

build_node_3_gc:
	bl	collect_2
	b	build_node_3_gc_r


	.p2align	2	
	subs	r5,r5,#6
	b	build_node_4
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_3:
	subs	r5,r5,#6
	blo	gc_23
gc_r_23:
	ldr	r4,[r7]
	str	r6,[r10,#8]
	add	r4,r4,#8
	ldr	r8,[r7,#4]
	str	r4,[r10,#12]
	ldr	r7,[r7,#8]
	str	r8,[r10,#16]
	ldr	r8,[r7]
	str	r10,[r10,#20]
	str	r8,[r10]
	ldr	r8,[r7,#4]
	add	r6,r10,#12
	str	r8,[r10,#4]
	add	r10,r10,#24
	ldr	pc,[sp],#4

gc_23:	bl	collect_2
	b	gc_r_23

build_node_4:
	blo	build_node_4_gc
build_node_4_gc_r:
	str	r3,[r10]
	add	r8,r10,#12
	str	r7,[r10,#4]
	str	r8,[r10,#8]
	str	r6,[r10,#12]
	mov	r6,r10
	ldr	r8,[r9,#-4]
	str	r8,[r10,#16]
	ldr	r8,[r9,#-8]
	subs	r9,r9,#8
	str	r8,[r10,#20]
	add	r10,r10,#24
	ldr	pc,[sp],#4

build_node_4_gc:
	bl	collect_2
	b	build_node_4_gc_r


	.p2align	2
	subs	r5,r5,#7
	b	build_node_5
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_4:
	subs	r5,r5,#7
	blo	gc_24
gc_r_24:
	ldr	r4,[r7]
	str	r6,[r10,#12]
	add	r4,r4,#8
	ldr	r8,[r7,#4]
	str	r4,[r10,#16]
	ldr	r7,[r7,#8]
	str	r8,[r10,#20]
	ldr	r8,[r7]
	str	r10,[r10,#24]
	str	r8,[r10]
	ldr	r8,[r7,#4]
	add	r6,r10,#16
	str	r8,[r10,#4]
	ldr	r8,[r7,#8]
	str	r8,[r10,#8]
	add	r10,r10,#28
	ldr	pc,[sp],#4

gc_24:	bl	collect_2
	b	gc_r_24

build_node_5:
	blo	build_node_5_gc
build_node_5_gc_r:
	str	r3,[r10]
	add	r8,r10,#12
	str	r7,[r10,#4]
	str	r8,[r10,#8]
	str	r6,[r10,#12]
	mov	r6,r10
	ldr	r8,[r9,#-4]
	str	r8,[r10,#16]
	ldr	r8,[r9,#-8]
	str	r8,[r10,#20]
	ldr	r8,[r9,#-12]
	subs	r9,r9,#12
	str	r8,[r10,#24]
	add	r10,r10,#28
	ldr	pc,[sp],#4

build_node_5_gc:
	bl	collect_2
	b	build_node_5_gc_r


	.p2align	2	
	mov	r4,#8
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_5:
	ldr	r3,[r7]
	mov	r4,#8
	b	yet_args_needed_


	.p2align	2	
	mov	r4,#9
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_6:
	ldr	r3,[r7]
	mov	r4,#9
	b	yet_args_needed_

	.p2align	2
	mov	r4,#10
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_7:
	ldr	r3,[r7]
	mov	r4,#10
	b	yet_args_needed_

	.p2align	2
	mov	r4,#11
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_8:
	ldr	r3,[r7]
	mov	r4,#11
	b	yet_args_needed_

	.p2align	2
	mov	r4,#12
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_9:
	ldr	r3,[r7]
	mov	r4,#12
	b	yet_args_needed_

	.p2align	2
	mov	r4,#13
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_10:
	ldr	r3,[r7]
	mov	r4,#13
	b	yet_args_needed_

	.p2align	2
	mov	r4,#14
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_11:
	ldr	r3,[r7]
	mov	r4,#14
	b	yet_args_needed_

	.p2align	2
	mov	r4,#15
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_12:
	ldr	r3,[r7]
	mov	r4,#15
	b	yet_args_needed_

	.p2align	2
	mov	r4,#16
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_13:
	ldr	r3,[r7]
	mov	r4,#16
	b	yet_args_needed_

	.p2align	2
	mov	r4,#17
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_14:
	ldr	r3,[r7]
	mov	r4,#17
	b	yet_args_needed_

	.p2align	2
	mov	r4,#18
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_15:
	ldr	r3,[r7]
	mov	r4,#18
	b	yet_args_needed_

	.p2align	2
	mov	r4,#19
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_16:
	ldr	r3,[r7]
	mov	r4,#19
	b	yet_args_needed_

	.p2align	2
	mov	r4,#20
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_17:
	ldr	r3,[r7]
	mov	r4,#20
	b	yet_args_needed_

	.p2align	2
	mov	r4,#21
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_18:
	ldr	r3,[r7]
	mov	r4,#21
	b	yet_args_needed_

	.p2align	2
	mov	r4,#22
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_19:
	ldr	r3,[r7]
	mov	r4,#22
	b	yet_args_needed_

	.p2align	2
	mov	r4,#23
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_20:
	ldr	r3,[r7]
	mov	r4,#23
	b	yet_args_needed_

	.p2align	2
	mov	r4,#24
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_21:
	ldr	r3,[r7]
	mov	r4,#24
	b	yet_args_needed_

	.p2align	2
	mov	r4,#25
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_22:
	ldr	r3,[r7]
	mov	r4,#25
	b	yet_args_needed_

	.p2align	2	
	mov	r4,#26
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_23:
	ldr	r3,[r7]
	mov	r4,#26
	b	yet_args_needed_

	.p2align	2
	mov	r4,#27
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_24:
	ldr	r3,[r7]
	mov	r4,#27
	b	yet_args_needed_

	.p2align	2	
	mov	r4,#28
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_25:
	ldr	r3,[r7]
	mov	r4,#28
	b	yet_args_needed_

	.p2align	2
	mov	r4,#29
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_26:
	ldr	r3,[r7]
	mov	r4,#29
	b	yet_args_needed_

	.p2align	2
	mov	r4,#30
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_27:
	ldr	r3,[r7]
	mov	r4,#30
	b	yet_args_needed_

	.p2align	2
	mov	r4,#31
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_28:
	ldr	r3,[r7]
	mov	r4,#31
	b	yet_args_needed_

	.p2align	2
	mov	r4,#32
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_29:
	ldr	r3,[r7]
	mov	r4,#32
	b	yet_args_needed_

	.p2align	2
	mov	r4,#33
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_30:
	ldr	r3,[r7]
	mov	r4,#33
	b	yet_args_needed_

	.p2align	2
	mov	r4,#34
	b	build_node_
.ifdef PROFILE
	nop
	nop
.endif
yet_args_needed_31:
	ldr	r3,[r7]
	mov	r4,#34
	b	yet_args_needed_

yet_args_needed:
@ for more than 4 arguments
	ldr	r3,[r7]
	ldrh	r4,[r3,#-2]
	add	r4,r4,#3
yet_args_needed_:
	subs	r5,r5,r4
	blo	yet_args_needed_gc
yet_args_needed_gc_r:
	subs	r4,r4,#3+1+4
	str	r3,[sp,#-4]!
	str	r6,[sp,#-4]!
	ldr	r3,[r7,#4]
	ldr	r7,[r7,#8]
	mov	r8,r10
	ldr	r6,[r7]
	str	r6,[r10]
	ldr	r6,[r7,#4]
	str	r6,[r10,#4]
	ldr	r6,[r7,#8]
	str	r6,[r10,#8]
	add	r7,r7,#12
	add	r10,r10,#12

yet_args_needed_cp_a:
	ldr	r6,[r7],#4
	str	r6,[r10],#4
	subs	r4,r4,#1
	bge	yet_args_needed_cp_a

	ldr	r6,[sp],#4
	str	r6,[r10]
	ldr	r4,[sp],#4
	add	r4,r4,#8
	str	r4,[r10,#4]
	add	r6,r10,#4
	str	r3,[r10,#8]
	str	r8,[r10,#12]
	add	r10,r10,#16
	ldr	pc,[sp],#4

yet_args_needed_gc:
	bl	collect_2
	b	yet_args_needed_gc_r

build_node_:
	subs	r5,r5,r4
	blo	build_node_gc
build_node_gc_r:
	str	r3,[r10]
	add	r8,r10,#12
	str	r7,[r10,#4]
	str	r8,[r10,#8]
	str	r6,[r10,#12]
	mov	r6,r10
	ldr	r8,[r9,#-4]
	str	r8,[r10,#16]
	ldr	r8,[r9,#-8]
	str	r8,[r10,#20]
	ldr	r8,[r9,#-12]
	subs	r9,r9,#12
	str	r8,[r10,#24]
	add	r10,r10,#28

	subs	r4,r4,#5+2
build_node_cp_a:
	ldr	r8,[r9,#-4]!
	str	r8,[r10],#4
	subs	r4,r4,#1
	bne	build_node_cp_a

	ldr	pc,[sp],#4

build_node_gc:
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
	ldr	r12,[sp]
	lao	r8,apupd_upd,0
	otoa	r8,apupd_upd,0
	cmp	r12,r8
	lao	r8,ap_1,0
	bne	ap_upd

	ldr	r8,[r9,#-4]
	ldr	r4,[r9,#-8]
	lao	r12,e__system__nind,23
	subs	r9,r9,#4
	otoa	r12,e__system__nind,23
	str	r12,[r8]
	str	r4,[r8,#4]
ap_1:
	ldr	r8,[r7]
	ldr	r12,[r8,#2]
	bx	r12

apupd_2:
	ldr	r12,[sp]
	lao	r8,apupd_upd,1
	otoa	r8,apupd_upd,1
	cmp	r12,r8
	lao	r8,ap_2,0
	bne	ap_upd

	ldr	r8,[r9,#-8]
	ldr	r4,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	lao	r12,e__system__nind,24
	subs	r9,r9,#4
	otoa	r12,e__system__nind,24
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_2

apupd_3:
	ldr	r12,[sp]
	lao	r8,apupd_upd,2
	otoa	r8,apupd_upd,2
	cmp	r12,r8
	lao	r8,ap_3,0
	bne	ap_upd

	ldr	r8,[r9,#-12]
	ldr	r4,[r9,#-16]
	ldr	r3,[r9,#-8]
	str	r3,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	lao	r12,e__system__nind,25
	subs	r9,r9,#4
	otoa	r12,e__system__nind,25
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_3

apupd_4:
	ldr	r12,[sp]
	lao	r8,apupd_upd,3
	otoa	r8,apupd_upd,3
	cmp	r12,r8
	lao	r8,ap_4,0
	bne	ap_upd

	ldr	r8,[r9,#-16]
	ldr	r4,[r9,#-20]
	ldr	r3,[r9,#-12]
	str	r3,[r9,#-16]
	ldr	r3,[r9,#-8]
	str	r3,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	lao	r12,e__system__nind,26
	subs	r9,r9,#4
	otoa	r12,e__system__nind,26
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_4

apupd_5:
	ldr	r12,[sp]
	lao	r8,apupd_upd,4
	otoa	r8,apupd_upd,4
	cmp	r12,r8
	lao	r8,ap_5,0
	bne	ap_upd

	ldr	r8,[r9,#-20]
	ldr	r4,[r9,#-24]
	ldr	r3,[r9,#-16]
	str	r3,[r9,#-20]
	ldr	r3,[r9,#-12]
	str	r3,[r9,#-16]
	ldr	r3,[r9,#-8]
	str	r3,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	lao	r12,e__system__nind,27
	subs	r9,r9,#4
	otoa	r12,e__system__nind,27
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_5

apupd_6:
	ldr	r12,[sp]
	lao	r8,apupd_upd,5
	otoa	r8,apupd_upd,5
	cmp	r12,r8
	lao	r8,ap_6,0
	bne	ap_upd

	ldr	r8,[r9,#-24]
	ldr	r4,[r9,#-28]
	ldr	r3,[r9,#-20]
	str	r3,[r9,#-24]
	ldr	r3,[r9,#-16]
	str	r3,[r9,#-20]
	ldr	r3,[r9,#-12]
	str	r3,[r9,#-16]
	ldr	r3,[r9,#-8]
	str	r3,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	lao	r12,e__system__nind,28
	subs	r9,r9,#4
	otoa	r12,e__system__nind,28
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_6

apupd_7:
	ldr	r12,[sp]
	lao	r8,apupd_upd,6
	otoa	r8,apupd_upd,6
	cmp	r12,r8
	lao	r8,ap_7,0
	bne	ap_upd

	ldr	r8,[r9,#-28]
	ldr	r4,[r9,#-32]
	str	pc,[sp,#-4]!
	bl	move_8
	lao	r12,e__system__nind,29
	subs	r9,r9,#4
	otoa	r12,e__system__nind,29
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_7

apupd_8:
	ldr	r12,[sp]
	lao	r8,apupd_upd,7
	otoa	r8,apupd_upd,7
	cmp	r12,r8
	lao	r8,ap_8,0
	bne	ap_upd

	ldr	r8,[r9,#-32]
	ldr	r4,[r9,#-36]
	str	pc,[sp,#-4]!
	bl	move_9
	lao	r12,e__system__nind,30
	subs	r9,r9,#4
	otoa	r12,e__system__nind,30
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_8

apupd_9:
	ldr	r12,[sp]
	lao	r8,apupd_upd,8
	otoa	r8,apupd_upd,8
	cmp	r12,r8
	lao	r8,ap_9,0
	bne	ap_upd

	ldr	r8,[r9,#-36]
	ldr	r4,[r9,#-40]
	str	pc,[sp,#-4]!
	bl	move_10
	lao	r12,e__system__nind,31
	subs	r9,r9,#4
	otoa	r12,e__system__nind,31
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_9

apupd_10:
	ldr	r12,[sp]
	lao	r8,apupd_upd,9
	otoa	r8,apupd_upd,9
	cmp	r12,r8
	lao	r8,ap_10,0
	bne	ap_upd

	ldr	r8,[r9,#-40]
	ldr	r4,[r9,#-44]
	str	pc,[sp,#-4]!
	bl	move_11
	lao	r12,e__system__nind,32
	subs	r9,r9,#4
	otoa	r12,e__system__nind,32
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_10

apupd_11:
	ldr	r12,[sp]
	lao	r8,apupd_upd,10
	otoa	r8,apupd_upd,10
	cmp	r12,r8
	lao	r8,ap_11,0
	bne	ap_upd

	ldr	r8,[r9,#-44]
	ldr	r4,[r9,#-48]
	str	pc,[sp,#-4]!
	bl	move_12
	lao	r12,e__system__nind,33
	subs	r9,r9,#4
	otoa	r12,e__system__nind,33
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_11

apupd_12:
	ldr	r12,[sp]
	lao	r8,apupd_upd,11
	otoa	r8,apupd_upd,11
	cmp	r12,r8
	lao	r8,ap_12,0
	bne	ap_upd

	ldr	r8,[r9,#-48]
	ldr	r4,[r9,#-52]
	str	pc,[sp,#-4]!
	bl	move_13
	lao	r12,e__system__nind,34
	subs	r9,r9,#4
	otoa	r12,e__system__nind,34
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_12

apupd_13:
	ldr	r12,[sp]
	lao	r8,apupd_upd,12
	otoa	r8,apupd_upd,12
	cmp	r12,r8
	lao	r8,ap_13,0
	bne	ap_upd

	ldr	r8,[r9,#-52]
	ldr	r4,[r9,#-56]
	str	pc,[sp,#-4]!
	bl	move_14
	lao	r12,e__system__nind,35
	subs	r9,r9,#4
	otoa	r12,e__system__nind,35
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_13

apupd_14:
	ldr	r12,[sp]
	lao	r8,apupd_upd,13
	otoa	r8,apupd_upd,13
	cmp	r12,r8
	lao	r8,ap_14,0
	bne	ap_upd

	ldr	r8,[r9,#-56]
	ldr	r4,[r9,#-60]
	str	pc,[sp,#-4]!
	bl	move_15
	lao	r12,e__system__nind,36
	subs	r9,r9,#4
	otoa	r12,e__system__nind,36
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_14

apupd_15:
	ldr	r12,[sp]
	lao	r8,apupd_upd,14
	otoa	r8,apupd_upd,14
	cmp	r12,r8
	lao	r8,ap_15,0
	bne	ap_upd

	ldr	r8,[r9,#-60]
	ldr	r4,[r9,#-64]
	str	pc,[sp,#-4]!
	bl	move_16
	lao	r12,e__system__nind,37
	subs	r9,r9,#4
	otoa	r12,e__system__nind,37
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_15

apupd_16:
	ldr	r12,[sp]
	lao	r8,apupd_upd,15
	otoa	r8,apupd_upd,15
	cmp	r12,r8
	lao	r8,ap_16,0
	bne	ap_upd

	ldr	r8,[r9,#-64]
	ldr	r4,[r9,#-68]
	str	pc,[sp,#-4]!
	bl	move_17
	lao	r12,e__system__nind,38
	subs	r9,r9,#4
	otoa	r12,e__system__nind,38
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_16

apupd_17:
	ldr	r12,[sp]
	lao	r8,apupd_upd,16
	otoa	r8,apupd_upd,16
	cmp	r12,r8
	lao	r8,ap_17,0
	bne	ap_upd

	ldr	r8,[r9,#-68]
	ldr	r4,[r9,#-72]
	str	pc,[sp,#-4]!
	bl	move_18
	lao	r12,e__system__nind,39
	subs	r9,r9,#4
	otoa	r12,e__system__nind,39
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_17

apupd_18:
	ldr	r12,[sp]
	lao	r8,apupd_upd,17
	otoa	r8,apupd_upd,17
	cmp	r12,r8
	lao	r8,ap_18,0
	bne	ap_upd

	ldr	r8,[r9,#-72]
	ldr	r4,[r9,#-76]
	str	pc,[sp,#-4]!
	bl	move_19
	lao	r12,e__system__nind,40
	subs	r9,r9,#4
	otoa	r12,e__system__nind,40
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_18

apupd_19:
	ldr	r12,[sp]
	lao	r8,apupd_upd,18
	otoa	r8,apupd_upd,18
	cmp	r12,r8
	lao	r8,ap_19,0
	bne	ap_upd

	ldr	r8,[r9,#-76]
	ldr	r4,[r9,#-80]
	str	pc,[sp,#-4]!
	bl	move_20
	lao	r12,e__system__nind,41
	subs	r9,r9,#4
	otoa	r12,e__system__nind,41
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_19

apupd_20:
	ldr	r12,[sp]
	lao	r8,apupd_upd,19
	otoa	r8,apupd_upd,19
	cmp	r12,r8
	lao	r8,ap_20,0
	bne	ap_upd

	ldr	r8,[r9,#-80]
	ldr	r4,[r9,#-84]
	str	pc,[sp,#-4]!
	bl	move_21
	lao	r12,e__system__nind,42
	subs	r9,r9,#4
	otoa	r12,e__system__nind,42
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_20

apupd_21:
	ldr	r12,[sp]
	lao	r8,apupd_upd,20
	otoa	r8,apupd_upd,20
	cmp	r12,r8
	lao	r8,ap_21,0
	bne	ap_upd

	ldr	r8,[r9,#-84]
	ldr	r4,[r9,#-88]
	str	pc,[sp,#-4]!
	bl	move_22
	lao	r12,e__system__nind,43
	subs	r9,r9,#4
	otoa	r12,e__system__nind,43
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_21

apupd_22:
	ldr	r12,[sp]
	lao	r8,apupd_upd,21
	otoa	r8,apupd_upd,21
	cmp	r12,r8
	lao	r8,ap_22,0
	bne	ap_upd

	ldr	r8,[r9,#-88]
	ldr	r4,[r9,#-92]
	str	pc,[sp,#-4]!
	bl	move_23
	lao	r12,e__system__nind,44
	subs	r9,r9,#4
	otoa	r12,e__system__nind,44
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_22

apupd_23:
	ldr	r12,[sp]
	lao	r8,apupd_upd,22
	otoa	r8,apupd_upd,22
	cmp	r12,r8
	lao	r8,ap_23,0
	bne	ap_upd

	ldr	r8,[r9,#-92]
	ldr	r4,[r9,#-96]
	str	pc,[sp,#-4]!
	bl	move_24
	lao	r12,e__system__nind,45
	subs	r9,r9,#4
	otoa	r12,e__system__nind,45
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_23

apupd_24:
	ldr	r12,[sp]
	lao	r8,apupd_upd,23
	otoa	r8,apupd_upd,23
	cmp	r12,r8
	lao	r8,ap_24,0
	bne	ap_upd

	ldr	r8,[r9,#-96]
	ldr	r4,[r9,#-100]
	str	pc,[sp,#-4]!
	bl	move_25
	lao	r12,e__system__nind,46
	subs	r9,r9,#4
	otoa	r12,e__system__nind,46
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_24

apupd_25:
	ldr	r12,[sp]
	lao	r8,apupd_upd,24
	otoa	r8,apupd_upd,24
	cmp	r12,r8
	lao	r8,ap_25,0
	bne	ap_upd

	ldr	r8,[r9,#-100]
	ldr	r4,[r9,#-104]
	str	pc,[sp,#-4]!
	bl	move_26
	lao	r12,e__system__nind,47
	subs	r9,r9,#4
	otoa	r12,e__system__nind,47
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_25

apupd_26:
	ldr	r12,[sp]
	lao	r8,apupd_upd,25
	otoa	r8,apupd_upd,25
	cmp	r12,r8
	lao	r8,ap_26,0
	bne	ap_upd

	ldr	r8,[r9,#-104]
	ldr	r4,[r9,#-108]
	str	pc,[sp,#-4]!
	bl	move_27
	lao	r12,e__system__nind,48
	subs	r9,r9,#4
	otoa	r12,e__system__nind,48
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_26

apupd_27:
	ldr	r12,[sp]
	lao	r8,apupd_upd,26
	otoa	r8,apupd_upd,26
	cmp	r12,r8
	lao	r8,ap_27,0
	bne	ap_upd

	ldr	r8,[r9,#-108]
	ldr	r4,[r9,#-112]
	str	pc,[sp,#-4]!
	bl	move_28
	lao	r12,e__system__nind,49
	subs	r9,r9,#4
	otoa	r12,e__system__nind,49
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_27

apupd_28:
	ldr	r12,[sp]
	lao	r8,apupd_upd,27
	otoa	r8,apupd_upd,27
	cmp	r12,r8
	lao	r8,ap_28,0
	bne	ap_upd

	ldr	r8,[r9,#-112]
	ldr	r4,[r9,#-116]
	str	pc,[sp,#-4]!
	bl	move_29
	lao	r12,e__system__nind,50
	subs	r9,r9,#4
	otoa	r12,e__system__nind,50
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_28

apupd_29:
	ldr	r12,[sp]
	lao	r8,apupd_upd,28
	otoa	r8,apupd_upd,28
	cmp	r12,r8
	lao	r8,ap_29,0
	bne	ap_upd

	ldr	r8,[r9,#-116]
	ldr	r4,[r9,#-120]
	str	pc,[sp,#-4]!
	bl	move_30
	lao	r12,e__system__nind,51
	subs	r9,r9,#4
	otoa	r12,e__system__nind,51
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_29

apupd_30:
	ldr	r12,[sp]
	lao	r8,apupd_upd,29
	otoa	r8,apupd_upd,29
	cmp	r12,r8
	lao	r8,ap_30,0
	bne	ap_upd

	ldr	r8,[r9,#-120]
	ldr	r4,[r9,#-124]
	str	pc,[sp,#-4]!
	bl	move_31
	lao	r12,e__system__nind,52
	subs	r9,r9,#4
	otoa	r12,e__system__nind,52
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_30

apupd_31:
	ldr	r12,[sp]
	lao	r8,apupd_upd,30
	otoa	r8,apupd_upd,30
	cmp	r12,r8
	lao	r8,ap_31,0
	bne	ap_upd

	ldr	r8,[r9,#-124]
	ldr	r4,[r9,#-128]
	str	pc,[sp,#-4]!
	bl	move_32
	lao	r12,e__system__nind,53
	subs	r9,r9,#4
	otoa	r12,e__system__nind,53
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_31

apupd_32:
	ldr	r12,[sp]
	lao	r8,apupd_upd,31
	otoa	r8,apupd_upd,31
	cmp	r12,r8
	lao	r8,ap_32,0
	bne	ap_upd

	ldr	r8,[r9,#-128]
	ldr	r4,[r9,#-132]
	str	pc,[sp,#-4]!
	bl	move_33
	lao	r12,e__system__nind,54
	subs	r9,r9,#4
	otoa	r12,e__system__nind,54
	str	r12,[r8]
	str	r4,[r8,#4]
	b	ap_32

ap_upd:
.ifdef PIC
ap_1__u0:
ap_2__u0:
ap_3__u0:
ap_4__u0:
ap_5__u0:
ap_6__u0:
ap_7__u0:
ap_8__u0:
ap_9__u0:
ap_10__u0:
ap_11__u0:
ap_12__u0:
ap_13__u0:
ap_14__u0:
ap_15__u0:
ap_16__u0:
ap_17__u0:
ap_18__u0:
ap_19__u0:
ap_20__u0:
ap_21__u0:
ap_22__u0:
ap_23__u0:
ap_24__u0:
ap_25__u0:
ap_26__u0:
ap_27__u0:
ap_28__u0:
ap_29__u0:
ap_30__u0:
ap_31__u0:
ap_32__u0:
	add	r8,r8,pc
.endif
	str	pc,[sp,#-4]!
	blx	r8
apupd_upd:
	ldr	r7,[r9,#-4]
	subs	r9,r9,#4
	ldr	r4,[r6]
	str	r4,[r7]
	ldr	r4,[r6,#4]
	str	r4,[r7,#4]
	ldr	r4,[r6,#8]
	mov	r6,r7
	str	r4,[r7,#8]	
	ldr	pc,[sp],#4

move_33:
	ldr	r3,[r9,#-124]
	str	r3,[r9,#-128]
move_32:
	ldr	r3,[r9,#-120]
	str	r3,[r9,#-124]
move_31:
	ldr	r3,[r9,#-116]
	str	r3,[r9,#-120]
move_30:
	ldr	r3,[r9,#-112]
	str	r3,[r9,#-116]
move_29:
	ldr	r3,[r9,#-108]
	str	r3,[r9,#-112]
move_28:
	ldr	r3,[r9,#-104]
	str	r3,[r9,#-108]
move_27:
	ldr	r3,[r9,#-100]
	str	r3,[r9,#-104]
move_26:
	ldr	r3,[r9,#-96]
	str	r3,[r9,#-100]
move_25:
	ldr	r3,[r9,#-92]
	str	r3,[r9,#-96]
move_24:
	ldr	r3,[r9,#-88]
	str	r3,[r9,#-92]
move_23:
	ldr	r3,[r9,#-84]
	str	r3,[r9,#-88]
move_22:
	ldr	r3,[r9,#-80]
	str	r3,[r9,#-84]
move_21:
	ldr	r3,[r9,#-76]
	str	r3,[r9,#-80]
move_20:
	ldr	r3,[r9,#-72]
	str	r3,[r9,#-76]
move_19:
	ldr	r3,[r9,#-68]
	str	r3,[r9,#-72]
move_18:
	ldr	r3,[r9,#-64]
	str	r3,[r9,#-68]
move_17:
	ldr	r3,[r9,#-60]
	str	r3,[r9,#-64]
move_16:
	ldr	r3,[r9,#-56]
	str	r3,[r9,#-60]
move_15:
	ldr	r3,[r9,#-52]
	str	r3,[r9,#-56]
move_14:
	ldr	r3,[r9,#-48]
	str	r3,[r9,#-52]
move_13:
	ldr	r3,[r9,#-44]
	str	r3,[r9,#-48]
move_12:
	ldr	r3,[r9,#-40]
	str	r3,[r9,#-44]
move_11:
	ldr	r3,[r9,#-36]
	str	r3,[r9,#-40]
move_10:
	ldr	r3,[r9,#-32]
	str	r3,[r9,#-36]
move_9:
	ldr	r3,[r9,#-28]
	str	r3,[r9,#-32]
move_8:
	ldr	r3,[r9,#-24]
	str	r3,[r9,#-28]
move_7:
	ldr	r3,[r9,#-20]
	str	r3,[r9,#-24]
	ldr	r3,[r9,#-16]
	str	r3,[r9,#-20]
	ldr	r3,[r9,#-12]
	str	r3,[r9,#-16]
	ldr	r3,[r9,#-8]
	str	r3,[r9,#-12]
	ldr	r3,[r9,#-4]
	str	r3,[r9,#-8]
	ldr	pc,[sp],#4

.ifdef PIC
	lto	apupd_upd,0
	lto	ap_1,0
	lto	e__system__nind,23
	lto	apupd_upd,1
	lto	ap_2,0
	lto	e__system__nind,24
	lto	apupd_upd,2
	lto	ap_3,0
	lto	e__system__nind,25
	lto	apupd_upd,3
	lto	ap_4,0
	lto	e__system__nind,26
	lto	apupd_upd,4
	lto	ap_5,0
	lto	e__system__nind,27
	lto	apupd_upd,5
	lto	ap_6,0
	lto	e__system__nind,28
	lto	apupd_upd,6
	lto	ap_7,0
	lto	e__system__nind,29
	lto	apupd_upd,7
	lto	ap_8,0
	lto	e__system__nind,30
	lto	apupd_upd,8
	lto	ap_9,0
	lto	e__system__nind,31
	lto	apupd_upd,9
	lto	ap_10,0
	lto	e__system__nind,32
	lto	apupd_upd,10
	lto	ap_11,0
	lto	e__system__nind,33
	lto	apupd_upd,11
	lto	ap_12,0
	lto	e__system__nind,34
	lto	apupd_upd,12
	lto	ap_13,0
	lto	e__system__nind,35
	lto	apupd_upd,13
	lto	ap_14,0
	lto	e__system__nind,36
	lto	apupd_upd,14
	lto	ap_15,0
	lto	e__system__nind,37
	lto	apupd_upd,15
	lto	ap_16,0
	lto	e__system__nind,38
	lto	apupd_upd,16
	lto	ap_17,0
	lto	e__system__nind,39
	lto	apupd_upd,17
	lto	ap_18,0
	lto	e__system__nind,40
	lto	apupd_upd,18
	lto	ap_19,0
	lto	e__system__nind,41
	lto	apupd_upd,19
	lto	ap_20,0
	lto	e__system__nind,42
	lto	apupd_upd,20
	lto	ap_21,0
	lto	e__system__nind,43
	lto	apupd_upd,21
	lto	ap_22,0
	lto	e__system__nind,44
	lto	apupd_upd,22
	lto	ap_23,0
	lto	e__system__nind,45
	lto	apupd_upd,23
	lto	ap_24,0
	lto	e__system__nind,46
	lto	apupd_upd,24
	lto	ap_25,0
	lto	e__system__nind,47
	lto	apupd_upd,25
	lto	ap_26,0
	lto	e__system__nind,48
	lto	apupd_upd,26
	lto	ap_27,0
	lto	e__system__nind,49
	lto	apupd_upd,27
	lto	ap_28,0
	lto	e__system__nind,50
	lto	apupd_upd,28
	lto	ap_29,0
	lto	e__system__nind,51
	lto	apupd_upd,29
	lto	ap_30,0
	lto	e__system__nind,52
	lto	apupd_upd,30
	lto	ap_31,0
	lto	e__system__nind,53
	lto	apupd_upd,31
	lto	ap_32,0
	lto	e__system__nind,54
.endif
