
	.intel_syntax noprefix

	.macro	jmp_short_opcode
	.byte	0xeb
	.endmacro

/*	d0 = rax */
/*	d1 = rbx */
/*	d2 = r10 */
/*	d3 = r11 */
/*	d7 = r15 */
/*	a0 = rcx */
/*	a1 = rdx */
/*	a2 = r8 */
/*	a3 = r9 */
/*	a4 = rsi */
/*	a6 = rdi */

/*	d0l = eax */
/*	a2l = r8d */
/*	a3l = r9d */

/*	d1w = bx */

/*	qw = qword ptr */

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
	mov	r9,qword ptr [r8]
	mov	rbx,32*16
	cmp	word ptr [r9],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap32

ap_31:
	mov	r9,qword ptr [r8]
	mov	rbx,31*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap31

ap_30:
	mov	r9,qword ptr [r8]
	mov	rbx,30*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap30

ap_29:
	mov	r9,qword ptr [r8]
	mov	rbx,29*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap29

ap_28:
	mov	r9,qword ptr [r8]
	mov	rbx,28*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap28

ap_27:
	mov	r9,qword ptr [r8]
	mov	rbx,27*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap27

ap_26:
	mov	r9,qword ptr [r8]
	mov	rbx,26*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap26

ap_25:
	mov	r9,qword ptr [r8]
	mov	rbx,25*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap25

ap_24:
	mov	r9,qword ptr [r8]
	mov	rbx,24*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap24

ap_23:
	mov	r9,qword ptr [r8]
	mov	rbx,23*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap23

ap_22:
	mov	r9,qword ptr [r8]
	mov	rbx,22*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap22

ap_21:
	mov	r9,qword ptr [r8]
	mov	rbx,21*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap21

ap_20:
	mov	r9,qword ptr [r8]
	mov	rbx,20*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap20

ap_19:
	mov	r9,qword ptr [r8]
	mov	rbx,19*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap19

ap_18:
	mov	r9,qword ptr [r8]
	mov	rbx,18*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap18

ap_17:
	mov	r9,qword ptr [r8]
	mov	rbx,17*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap17

ap_16:
	mov	r9,qword ptr [r8]
	mov	rbx,16*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap16

ap_15:
	mov	r9,qword ptr [r8]
	mov	rbx,15*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap15

ap_14:
	mov	r9,qword ptr [r8]
	mov	rbx,14*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap14

ap_13:
	mov	r9,qword ptr [r8]
	mov	rbx,13*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap13

ap_12:
	mov	r9,qword ptr [r8]
	mov	rbx,12*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap12

ap_11:
	mov	r9,qword ptr [r8]
	mov	rbx,11*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap11

ap_10:
	mov	r9,qword ptr [r8]
	mov	rbx,10*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap10

ap_9:
	mov	r9,qword ptr [r8]
	mov	rbx,9*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap9

ap_8:
	mov	r9,qword ptr [r8]
	mov	rbx,8*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap8

ap_7:
	mov	r9,qword ptr [r8]
	mov	rbx,7*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap7

ap_6:
	mov	r9,qword ptr [r8]
	mov	rbx,6*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap6

ap_5:
	mov	r9,qword ptr [r8]
	mov	rbx,5*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap5

ap_4:
	mov	r9,qword ptr [r8]
	mov	rbx,4*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap4

ap_3:
	mov	r9,qword ptr [r8]
	mov	rbx,3*16
	cmp	word ptr [r9],bx
	att_je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap3

ap_2:
	mov	r9,qword ptr [r8]
	mov	rbx,2*16
	cmp	word ptr [r9],bx
	jne	no_fast_ap2_

fast_ap_2_2_:
	movzx	rax,word ptr [r9-2]
	add	rbx,r9
	mov	r9,qword ptr [rbx-10]
 .if PROFILE
	sub	r9,24
 .else
	sub	r9,12
 .endif
	cmp	rax,1
	jb	repl_args_0_2
	je	repl_args_1

	cmp	rax,3
	jb	repl_args_2

	mov	qword ptr [rsi],rcx
	mov	qword ptr [rsi+8],rdx
	lea	rsi,[rsi+16]
	mov	rdx,qword ptr [r8+16]

	jmp	fast_ap_

no_fast_ap2_:
	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8,qword ptr [r9+6]
	add	rsi,8
	jmp	no_fast_ap2

fast_ap_2_2:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8
	att_jmp	fast_ap_2_2_

fast_ap_2:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

fast_ap:
	movzx	rax,word ptr [r9-2]
	add	rbx,r9
	mov	r9,qword ptr [rbx-10]
 .if PROFILE
	sub	r9,24
 .else
	sub	r9,12
 .endif
	cmp	rax,1
	jb	repl_args_0
	att_je	repl_args_1

	cmp	rax,3
	att_jb	repl_args_2

	mov	qword ptr [rsi],rcx
	mov	qword ptr [rsi+8],rdx
	lea	rsi,[rsi+16]
	mov	rdx,qword ptr [r8+16]

fast_ap_:
	mov	r8,qword ptr [r8+8]
	je	repl_args_3

	cmp	rax,5
	jb	repl_args_4
	je	repl_args_5

	cmp	rax,7
	jb	repl_args_6

repl_args_7_:
	mov	rbp,qword ptr [rdx+rax*8-16]
	mov	qword ptr [rsi],rbp
	sub	rax,1
	add	rsi,8
	cmp	rax,6
	att_jne	repl_args_7_

repl_args_6:
	mov	rax,qword ptr [rdx+32]
	mov	qword ptr [rsi],rax
	mov	rax,qword ptr [rdx+24]
	mov	qword ptr [rsi+8],rax
	mov	rax,qword ptr [rdx+16]
	mov	qword ptr [rsi+16],rax
	mov	rcx,qword ptr [rdx+8]
	mov	rdx,qword ptr [rdx]
	add	rsi,24
	jmp	r9

repl_args_0:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8
repl_args_0_2:
	jmp	r9

repl_args_1:
	mov	r8,qword ptr [r8+8]
	jmp	r9

repl_args_2:
	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	add	rsi,8
	mov	rdx,qword ptr [r8+16]
	mov	r8,qword ptr [r8+8]
	jmp	r9

repl_args_3:
	mov	rcx,qword ptr [rdx+8]
	mov	rdx,qword ptr [rdx]
	jmp	r9

repl_args_4:
	mov	rax,qword ptr [rdx+16]
	mov	qword ptr [rsi],rax
	mov	rcx,qword ptr [rdx+8]
	mov	rdx,qword ptr [rdx]
	add	rsi,8
	jmp	r9

repl_args_5:
	mov	rax,qword ptr [rdx+24]
	mov	qword ptr [rsi],rax
	mov	rax,qword ptr [rdx+16]
	mov	qword ptr [rsi+8],rax
	mov	rcx,qword ptr [rdx+8]
	mov	rdx,qword ptr [rdx]
	add	rsi,16
	jmp	r9


no_fast_ap32:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,31*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap31:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,30*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap30:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,29*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap29:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,28*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap28:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,27*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap27:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,26*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap26:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,25*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap25:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,24*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap24:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,23*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap23:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,22*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap22:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,21*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap21:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,20*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap20:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,19*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap19:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,18*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap18:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,17*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap17:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,16*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap16:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,15*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap15:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,14*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap14:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,13*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap13:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,12*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap12:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,11*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap11:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,10*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap10:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,9*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap9:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,8*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap8:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,7*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap7:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,6*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap6:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,5*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap5:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,4*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap4:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,3*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2

	mov	r8,qword ptr [r9+6]
no_fast_ap3:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8

	mov	rbx,2*16
 	cmp	word ptr [r9],bx
	att_je	fast_ap_2_2

	mov	r8,qword ptr [r9+6]
no_fast_ap2:
	call	r8
	mov	r9,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr [rsi-8]
	sub	rsi,8
	jmp	qword ptr [r9+6]


add_empty_node_2:
	sub	r15,3
	jb	add_empty_node_2_gc
add_empty_node_2_gc_:
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,rdi
	add	rdi,24
	ret
add_empty_node_2_gc:
	att_call	collect_2
	att_jmp	add_empty_node_2_gc_

add_empty_node_3:
	sub	r15,3
	jb	add_empty_node_3_gc
add_empty_node_3_gc_:
	mov	qword ptr [rsi],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_3_gc:
	att_call	collect_3
	att_jmp	add_empty_node_3_gc_

add_empty_node_4:
	sub	r15,3
	jb	add_empty_node_4_gc
add_empty_node_4_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	qword ptr [rsi-8],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_4_gc:
	att_call	collect_3
	att_jmp	add_empty_node_4_gc_

add_empty_node_5:
	sub	r15,3
	jb	add_empty_node_5_gc
add_empty_node_5_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	qword ptr [rsi-16],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_5_gc:
	att_call	collect_3
	att_jmp	add_empty_node_5_gc_

add_empty_node_6:
	sub	r15,3
	jb	add_empty_node_6_gc
add_empty_node_6_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	qword ptr [rsi-24],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_6_gc:
	att_call	collect_3
	att_jmp	add_empty_node_6_gc_

add_empty_node_7:
	sub	r15,3
	jb	add_empty_node_7_gc
add_empty_node_7_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	r9,qword ptr [rsi-32]
	mov	qword ptr [rsi-24],r9
	mov	qword ptr [rsi-32],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_7_gc:
	att_call	collect_3
	att_jmp	add_empty_node_7_gc_

add_empty_node_8:
	sub	r15,3
	jb	add_empty_node_8_gc
add_empty_node_8_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	r9,qword ptr [rsi-32]
	mov	qword ptr [rsi-24],r9
	mov	r9,qword ptr [rsi-40]
	mov	qword ptr [rsi-32],r9
	mov	qword ptr [rsi-40],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_8_gc:
	att_call	collect_3
	att_jmp	add_empty_node_8_gc_

add_empty_node_9:
	sub	r15,3
	jb	add_empty_node_9_gc
add_empty_node_9_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	r9,qword ptr [rsi-32]
	mov	qword ptr [rsi-24],r9
	mov	r9,qword ptr [rsi-40]
	mov	qword ptr [rsi-32],r9
	mov	r9,qword ptr [rsi-48]
	mov	qword ptr [rsi-40],r9
	mov	qword ptr [rsi-48],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_9_gc:
	att_call	collect_3
	att_jmp	add_empty_node_9_gc_

add_empty_node_10:
	sub	r15,3
	jb	add_empty_node_10_gc
add_empty_node_10_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	r9,qword ptr [rsi-32]
	mov	qword ptr [rsi-24],r9
	mov	r9,qword ptr [rsi-40]
	mov	qword ptr [rsi-32],r9
	mov	r9,qword ptr [rsi-48]
	mov	qword ptr [rsi-40],r9
	mov	r9,qword ptr [rsi-56]
	mov	qword ptr [rsi-48],r9
	mov	qword ptr [rsi-56],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_10_gc:
	att_call	collect_3
	att_jmp	add_empty_node_10_gc_

add_empty_node_11:
	sub	r15,3
	jb	add_empty_node_11_gc
add_empty_node_11_gc_:
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
	mov	r9,qword ptr [rsi-32]
	mov	qword ptr [rsi-24],r9
	mov	r9,qword ptr [rsi-40]
	mov	qword ptr [rsi-32],r9
	mov	r9,qword ptr [rsi-48]
	mov	qword ptr [rsi-40],r9
	mov	r9,qword ptr [rsi-56]
	mov	qword ptr [rsi-48],r9
	mov	r9,qword ptr [rsi-64]
	mov	qword ptr [rsi-56],r9
	mov	qword ptr [rsi-64],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_11_gc:
	att_call	collect_3
	att_jmp	add_empty_node_11_gc_

add_empty_node_32:
	mov	rbx,7
	att_jmp	add_empty_node_12_
add_empty_node_28:
	mov	rbx,6
	att_jmp	add_empty_node_12_
add_empty_node_24:
	mov	rbx,5
	att_jmp	add_empty_node_12_
add_empty_node_20:
	mov	rbx,4
	att_jmp	add_empty_node_12_
add_empty_node_16:
	mov	rbx,3
	att_jmp	add_empty_node_12_
add_empty_node_12:
	mov	rbx,2
add_empty_node_12_:
	sub	r15,3
	jb	add_empty_node_12_gc
add_empty_node_12_gc_:
	mov	rax,rsi
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
add_empty_node_12_lp:
	mov	r9,qword ptr [rax-16]
	mov	qword ptr [rax-8],r9
	mov	r9,qword ptr [rax-24]
	mov	qword ptr [rax-16],r9
	mov	r9,qword ptr [rax-32]
	mov	qword ptr [rax-24],r9
	mov	r9,qword ptr [rax-40]
	mov	qword ptr [rax-32],r9
	sub	rax,32
	sub	rbx,1
	att_jne	add_empty_node_12_lp
	mov	qword ptr [rax-8],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_12_gc:
	att_call	collect_3
	att_jmp	add_empty_node_12_gc_

add_empty_node_29:
	mov	rbx,6
	jmp	add_empty_node_13_
add_empty_node_25:
	mov	rbx,5
	att_jmp	add_empty_node_13_
add_empty_node_21:
	mov	rbx,4
	att_jmp	add_empty_node_13_
add_empty_node_17:
	mov	rbx,3
	att_jmp	add_empty_node_13_
add_empty_node_13:
	mov	rbx,2
add_empty_node_13_:
	sub	r15,3
	jb	add_empty_node_13_gc
add_empty_node_13_gc_:
	mov	rax,rsi
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
add_empty_node_13_lp:
	mov	r9,qword ptr [rax-24]
	mov	qword ptr [rax-16],r9
	mov	r9,qword ptr [rax-32]
	mov	qword ptr [rax-24],r9
	mov	r9,qword ptr [rax-40]
	mov	qword ptr [rax-32],r9
	mov	r9,qword ptr [rax-48]
	mov	qword ptr [rax-40],r9
	sub	rax,32
	sub	rbx,1
	att_jne	add_empty_node_13_lp
	mov	qword ptr [rax-16],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_13_gc:
	att_call	collect_3
	att_jmp	add_empty_node_13_gc_

add_empty_node_30:
	mov	rbx,6
	att_jmp	add_empty_node_14_
add_empty_node_26:
	mov	rbx,5
	att_jmp	add_empty_node_14_
add_empty_node_22:
	mov	rbx,4
	att_jmp	add_empty_node_14_
add_empty_node_18:
	mov	rbx,3
	att_jmp	add_empty_node_14_
add_empty_node_14:
	mov	rbx,2
add_empty_node_14_:
	sub	r15,3
	jb	add_empty_node_14_gc
add_empty_node_14_gc_:
	mov	rax,rsi
	mov	r9,qword ptr [rsi-8]
	mov	qword ptr [rsi],r9
	mov	r9,qword ptr [rsi-16]
	mov	qword ptr [rsi-8],r9
	mov	r9,qword ptr [rsi-24]
	mov	qword ptr [rsi-16],r9
add_empty_node_14_lp:
	mov	r9,qword ptr [rax-32]
	mov	qword ptr [rax-24],r9
	mov	r9,qword ptr [rax-40]
	mov	qword ptr [rax-32],r9
	mov	r9,qword ptr [rax-48]
	mov	qword ptr [rax-40],r9
	mov	r9,qword ptr [rax-56]
	mov	qword ptr [rax-48],r9
	sub	rax,32
	sub	rbx,1
	att_jne	add_empty_node_14_lp
	mov	qword ptr [rax-24],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_14_gc:
	att_call	collect_3
	att_jmp	add_empty_node_14_gc_

add_empty_node_31:
	mov	rbx,7
	att_jmp	add_empty_node_15_
add_empty_node_27:
	mov	rbx,6
	att_jmp	add_empty_node_15_
add_empty_node_23:
	mov	rbx,5
	att_jmp	add_empty_node_15_
add_empty_node_19:
	mov	rbx,4
	att_jmp	add_empty_node_15_
add_empty_node_15:
	mov	rbx,3
add_empty_node_15_:
	sub	r15,3
	jb	add_empty_node_15_gc
add_empty_node_15_gc_:
	mov	rax,rsi
add_empty_node_15_lp:
	mov	r9,qword ptr [rax-8]
	mov	qword ptr [rax],r9
	mov	r9,qword ptr [rax-16]
	mov	qword ptr [rax-8],r9
	mov	r9,qword ptr [rax-24]
	mov	qword ptr [rax-16],r9
	mov	r9,qword ptr [rax-32]
	mov	qword ptr [rax-24],r9
	sub	rax,32
	sub	rbx,1
	att_jne	add_empty_node_15_lp
	mov	qword ptr [rax],rdi
	lea	rbp,[rip+__cycle__in__spine]
	mov	qword ptr [rdi],rbp
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_15_gc:
	att_call	collect_3
	att_jmp	add_empty_node_15_gc_


yet_args_needed_0:
	sub	r15,2
	jb	yet_args_needed_0_gc
yet_args_needed_0_gc_r:
	mov	qword ptr [rdi+8],rcx
	mov	rax,qword ptr [rdx]
	mov	rcx,rdi
	add	rax,16
	mov	qword ptr [rdi],rax
	add	rdi,16
	ret

yet_args_needed_0_gc:
	att_call	collect_2
	att_jmp	yet_args_needed_0_gc_r


	.p2align 3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jmp	build_node_2_gc
	.p2align 3
	nop
	nop
	nop
	nop
	sub	r15,3
	jae	build_node_2_gc_r
	jmp_short_opcode
	.byte	-24	
	.p2align 3
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
 .endif
yet_args_needed_1:
	sub	r15,3
	jb	yet_args_needed_1_gc_
/* yet_args_needed_1_gc_ to avoid a bug in the Mach-O assembler */
yet_args_needed_1_gc_r:
	mov	qword ptr [rdi+16],rcx
	mov	rax,qword ptr [rdx]
	mov	rcx,rdi
	add	rax,16
	mov	qword ptr [rdi],rax
	mov	rbx,qword ptr [rdx+8]
	mov	qword ptr [rdi+8],rbx
	add	rdi,24
	ret

yet_args_needed_1_gc:
yet_args_needed_1_gc_:
	att_call	collect_2
	att_jmp	yet_args_needed_1_gc_r

build_node_2_gc_r:
	mov	qword ptr [rdi],rbx
	mov	qword ptr [rdi+8],rdx
	mov	qword ptr [rdi+16],rcx
	mov	rcx,rdi
	add	rdi,24
	ret

build_node_2_gc:
	att_call	collect_2
	att_jmp	build_node_2_gc_r


	.p2align 3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jmp build_node_3_gc
	.p2align 3
	nop
	nop
	nop
	nop
	sub	r15,5
	att_jae	build_node_3_gc_r
	jmp_short_opcode
	.byte	-24
	.p2align 3
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_2:
	sub	r15,5
	jb	gc_22
gc_r_22:
	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdi+8],rcx
	add	rax,16
	mov	r10,qword ptr [rdx+8]
	mov	qword ptr [rdi+16],rax
	lea	rcx,[rdi+16]
	mov	rbp,qword ptr [rdx+16]
	mov	qword ptr [rdi+24],r10
	mov	qword ptr [rdi],rbp
	mov	qword ptr [rdi+32],rdi
	add	rdi,40
	ret

gc_22:	att_call	collect_2
	att_jmp	gc_r_22

build_node_3_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,[rdi+24]
	mov	qword ptr [rdi+8],r8
	mov	qword ptr [rdi+16],rbp
	mov	qword ptr [rdi+24],rdx
	mov	qword ptr [rdi+32],rcx
	mov	rcx,rdi
	add	rdi,40
	ret

build_node_3_gc:
	att_call	collect_2
	att_jmp	build_node_3_gc_r

	.p2align 3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jmp	build_node_4_gc
	.p2align 3
	nop
	nop
	nop
	nop
	sub	r15,6
	jae	build_node_4_gc_r
	jmp_short_opcode
	.byte	-24
	.p2align 3
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_3:
	sub	r15,6
	jb	gc_23
gc_r_23:
	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdi+16],rcx
	add	rax,16
	mov	r10,qword ptr [rdx+8]
	mov	qword ptr [rdi+24],rax
	mov	rdx,qword ptr [rdx+16]
	mov	qword ptr [rdi+32],r10
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdi+40],rdi
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr [rdx+8]
	lea	rcx,[rdi+24]
	mov	qword ptr [rdi+8],rbp
	add	rdi,48
	ret

gc_23:	att_call	collect_2
	att_jmp	gc_r_23

build_node_4_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,[rdi+24]
	mov	qword ptr [rdi+8],r8
	mov	qword ptr [rdi+16],rbp
	mov	qword ptr [rdi+24],rdx
	mov	qword ptr [rdi+32],rcx
	mov	rcx,rdi
	mov	rbp,qword ptr [rsi-8]
	mov	qword ptr [rdi+40],rbp
	sub	rsi,8
	add	rdi,48
	ret

build_node_4_gc:
	att_call	collect_2
	att_jmp	build_node_4_gc_r


	.p2align 3
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	jmp 	build_node_5_gc
	.p2align 3
	nop
	nop
	nop
	nop
	sub	r15,7
	jae	build_node_5_gc_r
	jmp_short_opcode
	.byte	-24
	.p2align 3
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_4:
	sub	r15,7
	jb	gc_24
gc_r_24:
	mov	rax,qword ptr [rdx]
	mov	qword ptr [rdi+24],rcx
	add	rax,16
	mov	r10,qword ptr [rdx+8]
	mov	qword ptr [rdi+32],rax
	mov	rdx,qword ptr [rdx+16]
	mov	qword ptr [rdi+40],r10
	mov	rbp,qword ptr [rdx]
	mov	[rdi+48],rdi
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr [rdx+8]
	lea	rcx,[rdi+32]
	mov	qword ptr [rdi+8],rbp
	mov	rbp,qword ptr [rdx+16]
	mov	qword ptr [rdi+16],rbp
	add	rdi,56
	ret

gc_24:	att_call	collect_2
	att_jmp	gc_r_24

build_node_5_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,[rdi+24]
	mov	qword ptr [rdi+8],r8
	mov	qword ptr [rdi+16],rbp
	mov	qword ptr [rdi+24],rdx
	mov	qword ptr [rdi+32],rcx
	mov	rcx,rdi
	mov	rbp,qword ptr [rsi-8]
	mov	qword ptr [rdi+40],rbp
	mov	rbp,qword ptr [rsi-16]
	mov	qword ptr [rdi+48],rbp
	sub	rsi,16
	add	rdi,56
	ret

build_node_5_gc:
	att_call	collect_2
	att_jmp	build_node_5_gc_r


	.align	2
	mov	eax,8
	jmp	build_node_
	nop
	nop
	.align	2	
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_5:
	mov	rbx,qword ptr [rdx]
	mov	rax,8
	jmp	yet_args_needed_


	.align	2
	mov	eax,9
	att_jmp	build_node_
	nop
	nop
	.align	2	
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_6:
	mov	rbx,qword ptr [rdx]
	mov	rax,9
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,10
	att_jmp	build_node_
	nop
	nop
	.align	2	
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_7:
	mov	rbx,qword ptr [rdx]
	mov	rax,10
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,11
	att_jmp	build_node_
	nop
	nop
	.align	2	
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_8:
	mov	rbx,qword ptr [rdx]
	mov	rax,11
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,12
	att_jmp	build_node_
	nop
	nop
	.align	2
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_9:
	mov	rbx,qword ptr [rdx]
	mov	rax,12
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,13
	att_jmp	build_node_
	nop
	nop
	.align	2	
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_10:
	mov	rbx,qword ptr [rdx]
	mov	rax,13
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,14
	att_jmp	build_node_
	nop
	nop
	.align	2
 .if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
 .endif
yet_args_needed_11:
	mov	rbx,qword ptr [rdx]
	mov	rax,14
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,15
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_12:
	mov	rbx,qword ptr [rdx]
	mov	rax,15
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,16
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_13:
	mov	rbx,qword ptr [rdx]
	mov	rax,16
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,17
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_14:
	mov	rbx,qword ptr [rdx]
	mov	rax,17
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,18
	att_jmp	build_node_
	nop
	nop
	.align	2
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_15:
	mov	rbx,qword ptr [rdx]
	mov	rax,18
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,19
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_16:
	mov	rbx,qword ptr [rdx]
	mov	rax,19
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,20
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_17:
	mov	rbx,qword ptr [rdx]
	mov	rax,20
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,21
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_18:
	mov	rbx,qword ptr [rdx]
	mov	rax,21
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,22
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_19:
	mov	rbx,qword ptr [rdx]
	mov	rax,22
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,23
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_20:
	mov	rbx,qword ptr [rdx]
	mov	rax,23
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,24
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_21:
	mov	rbx,qword ptr [rdx]
	mov	rax,24
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,25
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_22:
	mov	rbx,qword ptr [rdx]
	mov	rax,25
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,26
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_23:
	mov	rbx,qword ptr [rdx]
	mov	rax,26
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,27
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_24:
	mov	rbx,qword ptr [rdx]
	mov	rax,27
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,28
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_25:
	mov	rbx,qword ptr [rdx]
	mov	rax,28
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,29
	att_jmp	build_node_
	nop
	nop
	.align	2
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_26:
	mov	rbx,qword ptr [rdx]
	mov	rax,29
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,30
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_27:
	mov	rbx,qword ptr [rdx]
	mov	rax,30
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,31
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_28:
	mov	rbx,qword ptr [rdx]
	mov	rax,31
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,32
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_29:
	mov	rbx,qword ptr [rdx]
	mov	rax,32
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,33
	att_jmp	build_node_
	nop
	nop
	.align	2	
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_30:
	mov	rbx,qword ptr [rdx]
	mov	rax,33
	att_jmp	yet_args_needed_

	.align	2
	mov	eax,34
	att_jmp	build_node_
	nop
	nop
	.align	2
.if PROFILE
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop	
	nop
	nop
	nop
	nop	
.endif
yet_args_needed_31:
	mov	rbx,qword ptr [rdx]
	mov	rax,34
	att_jmp	yet_args_needed_

yet_args_needed:
	mov	rbx,qword ptr [rdx]
	movzx	rax,word ptr [rbx-2]
	add	rax,3
yet_args_needed_:
	sub	r15,rax
	jb	yet_args_needed_gc
yet_args_needed_gc_r:
	mov	r11,qword ptr [rdx+8]
	sub	rax,3+1+4
	mov	rdx,qword ptr [rdx+16]
	mov	r10,rdi
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr [rdx+8]
	mov	qword ptr [rdi+8],rbp
	mov	rbp,qword ptr [rdx+16]
	mov	qword ptr [rdi+16],rbp
	add	rdx,24
	add	rdi,24

yet_args_needed_cp_a:
	mov	rbp,qword ptr [rdx]
	add	rdx,8
	mov	qword ptr [rdi],rbp
	add	rdi,8
	sub	rax,1
	att_jge	yet_args_needed_cp_a

	mov	qword ptr [rdi],rcx
	add	rbx,16
	mov	qword ptr [rdi+8],rbx
	lea	rcx,[rdi+8]
	mov	qword ptr [rdi+16],r11
	mov	qword ptr [rdi+24],r10
	add	rdi,32
	ret

yet_args_needed_gc:
	att_call	collect_2
	att_jmp	yet_args_needed_gc_r

build_node_:
	sub	r15,rax
	jb	build_node_gc
build_node_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,[rdi+24]
	mov	qword ptr [rdi+8],r8
	mov	qword ptr [rdi+16],rbp
	mov	qword ptr [rdi+24],rdx
	mov	qword ptr [rdi+32],rcx
	mov	rcx,rdi
	mov	r8,qword ptr [rsi-8]
	mov	qword ptr [rdi+40],r8
	mov	r8,qword ptr [rsi-16]
	sub	rsi,16
	mov	qword ptr [rdi+48],r8
	add	rdi,56

	sub	rax,5+2
build_node_cp_a:
	mov	r8,qword ptr [rsi-8]
	sub	rsi,8
	mov	qword ptr [rdi],r8
	add	rdi,8
	sub	rax,1
	att_jne	build_node_cp_a

	ret

build_node_gc:
	att_call	collect_3
	att_jmp	build_node_gc_r
	
