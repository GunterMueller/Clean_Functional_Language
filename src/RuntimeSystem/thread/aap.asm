

	d2 equ r10
	d3 equ r11

 ifndef NEW_DESCRIPTORS
	extern	__cycle__in__spine:near
	extern	collect_2:near
 endif
 
_TEXT	segment para 'CODE'
_TEXT	ends
_DATA	segment para 'DATA'
_DATA	ends

	_TEXT segment

	public	ap_2
	public	ap_3
	public	ap_4
	public	ap_5
	public	ap_6
	public	ap_7
	public	ap_8
	public	ap_9
	public	ap_10
	public	ap_11
	public	ap_12
	public	ap_13
	public	ap_14
	public	ap_15
	public	ap_16
	public	ap_17
	public	ap_18
	public	ap_19
	public	ap_20
	public	ap_21
	public	ap_22
	public	ap_23
	public	ap_24
	public	ap_25
	public	ap_26
	public	ap_27
	public	ap_28
	public	ap_29
	public	ap_30
	public	ap_31
	public	ap_32

	public	add_empty_node_2
	public	add_empty_node_3
	public	add_empty_node_4
	public	add_empty_node_5
	public	add_empty_node_6
	public	add_empty_node_7
	public	add_empty_node_8
	public	add_empty_node_9
	public	add_empty_node_10
	public	add_empty_node_11
	public	add_empty_node_12
	public	add_empty_node_13
	public	add_empty_node_14
	public	add_empty_node_15
	public	add_empty_node_16
	public	add_empty_node_17
	public	add_empty_node_18
	public	add_empty_node_19
	public	add_empty_node_20
	public	add_empty_node_21
	public	add_empty_node_22
	public	add_empty_node_23
	public	add_empty_node_24
	public	add_empty_node_25
	public	add_empty_node_26
	public	add_empty_node_27
	public	add_empty_node_28
	public	add_empty_node_29
	public	add_empty_node_30
	public	add_empty_node_31
	public	add_empty_node_32

	public	yet_args_needed_5
	public	yet_args_needed_6
	public	yet_args_needed_7
	public	yet_args_needed_8
	public	yet_args_needed_9
	public	yet_args_needed_10
	public	yet_args_needed_11
	public	yet_args_needed_12
	public	yet_args_needed_13
	public	yet_args_needed_14
	public	yet_args_needed_15
	public	yet_args_needed_16
	public	yet_args_needed_17
	public	yet_args_needed_18
	public	yet_args_needed_19
	public	yet_args_needed_20
	public	yet_args_needed_21
	public	yet_args_needed_22
	public	yet_args_needed_23
	public	yet_args_needed_24
	public	yet_args_needed_25
	public	yet_args_needed_26
	public	yet_args_needed_27
	public	yet_args_needed_28
	public	yet_args_needed_29
	public	yet_args_needed_30
	public	yet_args_needed_31

ap_32:
	mov	rbp,qword ptr [r8]
	mov	rbx,32*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap32

ap_31:
	mov	rbp,qword ptr [r8]
	mov	rbx,31*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap31

ap_30:
	mov	rbp,qword ptr [r8]
	mov	rbx,30*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap30

ap_29:
	mov	rbp,qword ptr [r8]
	mov	rbx,29*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap29

ap_28:
	mov	rbp,qword ptr [r8]
	mov	rbx,28*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap28

ap_27:
	mov	rbp,qword ptr [r8]
	mov	rbx,27*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap27

ap_26:
	mov	rbp,qword ptr [r8]
	mov	rbx,26*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap26

ap_25:
	mov	rbp,qword ptr [r8]
	mov	rbx,25*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap25

ap_24:
	mov	rbp,qword ptr [r8]
	mov	rbx,24*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap24

ap_23:
	mov	rbp,qword ptr [r8]
	mov	rbx,23*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap23

ap_22:
	mov	rbp,qword ptr [r8]
	mov	rbx,22*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap22

ap_21:
	mov	rbp,qword ptr [r8]
	mov	rbx,21*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap21

ap_20:
	mov	rbp,qword ptr [r8]
	mov	rbx,20*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap20

ap_19:
	mov	rbp,qword ptr [r8]
	mov	rbx,19*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap19

ap_18:
	mov	rbp,qword ptr [r8]
	mov	rbx,18*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap18

ap_17:
	mov	rbp,qword ptr [r8]
	mov	rbx,17*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap17

ap_16:
	mov	rbp,qword ptr [r8]
	mov	rbx,16*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap16

ap_15:
	mov	rbp,qword ptr [r8]
	mov	rbx,15*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap15

ap_14:
	mov	rbp,qword ptr [r8]
	mov	rbx,14*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap14

ap_13:
	mov	rbp,qword ptr [r8]
	mov	rbx,13*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap13

ap_12:
	mov	rbp,qword ptr [r8]
	mov	rbx,12*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap12

ap_11:
	mov	rbp,qword ptr [r8]
	mov	rbx,11*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap11

ap_10:
	mov	rbp,qword ptr [r8]
	mov	rbx,10*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap10

ap_9:
	mov	rbp,qword ptr [r8]
	mov	rbx,9*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap9

ap_8:
	mov	rbp,qword ptr [r8]
	mov	rbx,8*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap8

ap_7:
	mov	rbp,qword ptr [r8]
	mov	rbx,7*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap7

ap_6:
	mov	rbp,qword ptr [r8]
	mov	rbx,6*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap6

ap_5:
	mov	rbp,qword ptr [r8]
	mov	rbx,5*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap5

ap_4:
	mov	rbp,qword ptr [r8]
	mov	rbx,4*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap4

ap_3:
	mov	rbp,qword ptr [r8]
	mov	rbx,3*8
	cmp	word ptr [rbp],bx
	je	fast_ap

	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap3

ap_2:
	mov	rbp,qword ptr [r8]
	mov	rbx,2*8
	cmp	word ptr [rbp],bx
	jne	no_fast_ap2_

fast_ap_2_2_:
	movzx	rax,word ptr -2[rbp]
	add	rbx,rbp
	mov	ebp,dword ptr -6[rbx]
 ifdef PROFILE
	sub	rbp,24
 else
	sub	rbp,12
 endif
	cmp	rax,1
	jb	repl_args_0_2
	je	repl_args_1

	cmp	rax,3
	jb	repl_args_2

	mov	qword ptr [rsi],rcx
	mov	qword ptr 8[rsi],rdx
	lea	rsi,16[rsi]
	mov	rdx,qword ptr 16[r8]

	jmp	fast_ap_

no_fast_ap2_:
	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	mov	rdx,r8
	mov	r8d,dword ptr 2[rbp]
	add	rsi,8
	jmp	no_fast_ap2

fast_ap_2_2:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8
	jmp	fast_ap_2_2_

fast_ap_2:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

fast_ap:
	movzx	rax,word ptr -2[rbp]
	add	rbx,rbp
	mov	ebp,dword ptr -6[rbx]
 ifdef PROFILE
	sub	rbp,24
 else
	sub	rbp,12
 endif
	cmp	rax,1
	jb	repl_args_0
	je	repl_args_1

	cmp	rax,3
	jb	repl_args_2

	mov	qword ptr [rsi],rcx
	mov	qword ptr 8[rsi],rdx
	lea	rsi,16[rsi]
	mov	rdx,qword ptr 16[r8]

fast_ap_:
	mov	r8,qword ptr 8[r8]
	je	repl_args_3

	cmp	rax,5
	jb	repl_args_4
	je	repl_args_5

	cmp	rax,7
	jb	repl_args_6

repl_args_7_:
	mov	rbx,qword ptr -16[rdx+rax*8]
	mov	qword ptr [rsi],rbx
	sub	rax,1
	add	rsi,8
	cmp	rax,6
	jne	repl_args_7_

repl_args_6:
	mov	rax,qword ptr 32[rdx]
	mov	qword ptr [rsi],rax
	mov	rax,qword ptr 24[rdx]
	mov	qword ptr 8[rsi],rax
	mov	rax,qword ptr 16[rdx]
	mov	qword ptr 16[rsi],rax
	mov	rcx,qword ptr 8[rdx]
	mov	rdx,qword ptr [rdx]
	add	rsi,24
	jmp	rbp

repl_args_0:
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8
repl_args_0_2:
	jmp	rbp

repl_args_1:
	mov	r8,qword ptr 8[r8]
	jmp	rbp

repl_args_2:
	mov	qword ptr [rsi],rcx
	mov	rcx,rdx
	add	rsi,8
	mov	rdx,qword ptr 16[r8]
	mov	r8,qword ptr 8[r8]
	jmp	rbp

repl_args_3:
	mov	rcx,qword ptr 8[rdx]
	mov	rdx,qword ptr [rdx]
	jmp	rbp

repl_args_4:
	mov	rax,qword ptr 16[rdx]
	mov	qword ptr [rsi],rax
	mov	rcx,qword ptr 8[rdx]
	mov	rdx,qword ptr [rdx]
	add	rsi,8
	jmp	rbp

repl_args_5:
	mov	rax,qword ptr 24[rdx]
	mov	qword ptr [rsi],rax
	mov	rax,qword ptr 16[rdx]
	mov	qword ptr 8[rsi],rax
	mov	rcx,qword ptr 8[rdx]
	mov	rdx,qword ptr [rdx]
	add	rsi,16
	jmp	rbp


no_fast_ap32:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,31*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap31:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,30*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap30:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,29*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap29:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,28*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap28:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,27*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap27:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,26*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap26:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,25*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap25:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,24*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap24:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,23*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap23:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,22*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap22:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,21*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap21:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,20*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap20:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,19*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap19:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,18*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap18:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,17*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap17:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,16*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap16:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,15*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap15:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,14*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap14:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,13*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap13:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,12*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap12:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,11*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap11:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,10*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap10:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,9*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap9:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,8*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap8:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,7*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap7:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,6*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap6:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,5*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap5:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,4*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap4:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,3*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap3:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8

	mov	rbx,2*8
 	cmp	word ptr [rbp],bx
	je	fast_ap_2_2

	mov	r8d,dword ptr 2[rbp]
no_fast_ap2:
	call	r8
	mov	rbp,qword ptr [rcx]
	mov	rdx,rcx
	mov	rcx,qword ptr -8[rsi]
	sub	rsi,8
	mov	r8d,dword ptr 2[rbp]
	jmp	r8


add_empty_node_2:
	sub	r15,3
	jb	add_empty_node_2_gc
add_empty_node_2_gc_:
	mov	qword ptr [rdi],offset __cycle__in__spine
	mov	r8,rdx
	mov	rdx,rcx
	mov	rcx,rdi
	add	rdi,24
	ret
add_empty_node_2_gc:
	call	collect_2
	jmp	add_empty_node_2_gc_

add_empty_node_3:
	sub	r15,3
	jb	add_empty_node_3_gc
add_empty_node_3_gc_:
	mov	qword ptr [rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_3_gc:
	call	collect_3
	jmp	add_empty_node_3_gc_

add_empty_node_4:
	sub	r15,3
	jb	add_empty_node_4_gc
add_empty_node_4_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	qword ptr -8[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_4_gc:
	call	collect_3
	jmp	add_empty_node_4_gc_

add_empty_node_5:
	sub	r15,3
	jb	add_empty_node_5_gc
add_empty_node_5_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	qword ptr -16[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_5_gc:
	call	collect_3
	jmp	add_empty_node_5_gc_

add_empty_node_6:
	sub	r15,3
	jb	add_empty_node_6_gc
add_empty_node_6_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	qword ptr -24[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_6_gc:
	call	collect_3
	jmp	add_empty_node_6_gc_

add_empty_node_7:
	sub	r15,3
	jb	add_empty_node_7_gc
add_empty_node_7_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	rbp,qword ptr -32[rsi]
	mov	qword ptr -24[rsi],rbp
	mov	qword ptr -32[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_7_gc:
	call	collect_3
	jmp	add_empty_node_7_gc_

add_empty_node_8:
	sub	r15,3
	jb	add_empty_node_8_gc
add_empty_node_8_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	rbp,qword ptr -32[rsi]
	mov	qword ptr -24[rsi],rbp
	mov	rbp,qword ptr -40[rsi]
	mov	qword ptr -32[rsi],rbp
	mov	qword ptr -40[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_8_gc:
	call	collect_3
	jmp	add_empty_node_8_gc_

add_empty_node_9:
	sub	r15,3
	jb	add_empty_node_9_gc
add_empty_node_9_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	rbp,qword ptr -32[rsi]
	mov	qword ptr -24[rsi],rbp
	mov	rbp,qword ptr -40[rsi]
	mov	qword ptr -32[rsi],rbp
	mov	rbp,qword ptr -48[rsi]
	mov	qword ptr -40[rsi],rbp
	mov	qword ptr -48[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_9_gc:
	call	collect_3
	jmp	add_empty_node_9_gc_

add_empty_node_10:
	sub	r15,3
	jb	add_empty_node_10_gc
add_empty_node_10_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	rbp,qword ptr -32[rsi]
	mov	qword ptr -24[rsi],rbp
	mov	rbp,qword ptr -40[rsi]
	mov	qword ptr -32[rsi],rbp
	mov	rbp,qword ptr -48[rsi]
	mov	qword ptr -40[rsi],rbp
	mov	rbp,qword ptr -56[rsi]
	mov	qword ptr -48[rsi],rbp
	mov	qword ptr -56[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_10_gc:
	call	collect_3
	jmp	add_empty_node_10_gc_

add_empty_node_11:
	sub	r15,3
	jb	add_empty_node_11_gc
add_empty_node_11_gc_:
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
	mov	rbp,qword ptr -32[rsi]
	mov	qword ptr -24[rsi],rbp
	mov	rbp,qword ptr -40[rsi]
	mov	qword ptr -32[rsi],rbp
	mov	rbp,qword ptr -48[rsi]
	mov	qword ptr -40[rsi],rbp
	mov	rbp,qword ptr -56[rsi]
	mov	qword ptr -48[rsi],rbp
	mov	rbp,qword ptr -64[rsi]
	mov	qword ptr -56[rsi],rbp
	mov	qword ptr -64[rsi],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_11_gc:
	call	collect_3
	jmp	add_empty_node_11_gc_

add_empty_node_32:
	mov	rbx,7
	jmp	add_empty_node_12_
add_empty_node_28:
	mov	rbx,6
	jmp	add_empty_node_12_
add_empty_node_24:
	mov	rbx,5
	jmp	add_empty_node_12_
add_empty_node_20:
	mov	rbx,4
	jmp	add_empty_node_12_
add_empty_node_16:
	mov	rbx,3
	jmp	add_empty_node_12_
add_empty_node_12:
	mov	rbx,2
add_empty_node_12_:
	sub	r15,3
	jb	add_empty_node_12_gc
add_empty_node_12_gc_:
	mov	rax,rsi
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
add_empty_node_12_lp:
	mov	rbp,qword ptr -16[rax]
	mov	qword ptr -8[rax],rbp
	mov	rbp,qword ptr -24[rax]
	mov	qword ptr -16[rax],rbp
	mov	rbp,qword ptr -32[rax]
	mov	qword ptr -24[rax],rbp
	mov	rbp,qword ptr -40[rax]
	mov	qword ptr -32[rax],rbp
	sub	rax,32
	sub	rbx,1
	jne	add_empty_node_12_lp
	mov	qword ptr -8[rax],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_12_gc:
	call	collect_3
	jmp	add_empty_node_12_gc_

add_empty_node_29:
	mov	rbx,6
	jmp	add_empty_node_13_
add_empty_node_25:
	mov	rbx,5
	jmp	add_empty_node_13_
add_empty_node_21:
	mov	rbx,4
	jmp	add_empty_node_13_
add_empty_node_17:
	mov	rbx,3
	jmp	add_empty_node_13_
add_empty_node_13:
	mov	rbx,2
add_empty_node_13_:
	sub	r15,3
	jb	add_empty_node_13_gc
add_empty_node_13_gc_:
	mov	rax,rsi
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
add_empty_node_13_lp:
	mov	rbp,qword ptr -24[rax]
	mov	qword ptr -16[rax],rbp
	mov	rbp,qword ptr -32[rax]
	mov	qword ptr -24[rax],rbp
	mov	rbp,qword ptr -40[rax]
	mov	qword ptr -32[rax],rbp
	mov	rbp,qword ptr -48[rax]
	mov	qword ptr -40[rax],rbp
	sub	rax,32
	sub	rbx,1
	jne	add_empty_node_13_lp
	mov	qword ptr -16[rax],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_13_gc:
	call	collect_3
	jmp	add_empty_node_13_gc_

add_empty_node_30:
	mov	rbx,6
	jmp	add_empty_node_14_
add_empty_node_26:
	mov	rbx,5
	jmp	add_empty_node_14_
add_empty_node_22:
	mov	rbx,4
	jmp	add_empty_node_14_
add_empty_node_18:
	mov	rbx,3
	jmp	add_empty_node_14_
add_empty_node_14:
	mov	rbx,2
add_empty_node_14_:
	sub	r15,3
	jb	add_empty_node_14_gc
add_empty_node_14_gc_:
	mov	rax,rsi
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr [rsi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr -8[rsi],rbp
	mov	rbp,qword ptr -24[rsi]
	mov	qword ptr -16[rsi],rbp
add_empty_node_14_lp:
	mov	rbp,qword ptr -32[rax]
	mov	qword ptr -24[rax],rbp
	mov	rbp,qword ptr -40[rax]
	mov	qword ptr -32[rax],rbp
	mov	rbp,qword ptr -48[rax]
	mov	qword ptr -40[rax],rbp
	mov	rbp,qword ptr -56[rax]
	mov	qword ptr -48[rax],rbp
	sub	rax,32
	sub	rbx,1
	jne	add_empty_node_14_lp
	mov	qword ptr -24[rax],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_14_gc:
	call	collect_3
	jmp	add_empty_node_14_gc_

add_empty_node_31:
	mov	rbx,7
	jmp	add_empty_node_15_
add_empty_node_27:
	mov	rbx,6
	jmp	add_empty_node_15_
add_empty_node_23:
	mov	rbx,5
	jmp	add_empty_node_15_
add_empty_node_19:
	mov	rbx,4
	jmp	add_empty_node_15_
add_empty_node_15:
	mov	rbx,3
add_empty_node_15_:
	sub	r15,3
	jb	add_empty_node_15_gc
add_empty_node_15_gc_:
	mov	rax,rsi
add_empty_node_15_lp:
	mov	rbp,qword ptr -8[rax]
	mov	qword ptr [rax],rbp
	mov	rbp,qword ptr -16[rax]
	mov	qword ptr -8[rax],rbp
	mov	rbp,qword ptr -24[rax]
	mov	qword ptr -16[rax],rbp
	mov	rbp,qword ptr -32[rax]
	mov	qword ptr -24[rax],rbp
	sub	rax,32
	sub	rbx,1
	jne	add_empty_node_15_lp
	mov	qword ptr [rax],rdi
	mov	qword ptr [rdi],offset __cycle__in__spine
	add	rsi,8
	add	rdi,24
	ret
add_empty_node_15_gc:
	call	collect_3
	jmp	add_empty_node_15_gc_


yet_args_needed_0:
	sub	r15,2
	jb	yet_args_needed_0_gc
yet_args_needed_0_gc_r:
	mov	qword ptr 8[rdi],rcx
	mov	rax,qword ptr [rdx]
	mov	rcx,rdi
	add	rax,8
	mov	qword ptr [rdi],rax
	add	rdi,16
	ret

yet_args_needed_0_gc:
	call	collect_2
	jmp	yet_args_needed_0_gc_r


	align	(4)
	sub	r15,3
	jae short build_node_2_gc_r
	jmp short build_node_2_gc
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_1:
	sub	r15,3
	jb	yet_args_needed_1_gc
yet_args_needed_1_gc_r:
	mov	qword ptr 16[rdi],rcx
	mov	rax,qword ptr [rdx]
	mov	rcx,rdi
	add	rax,8
	mov	qword ptr [rdi],rax
	mov	rbx,qword ptr 8[rdx]
	mov	qword ptr 8[rdi],rbx
	add	rdi,24
	ret

yet_args_needed_1_gc:
	call	collect_2
	jmp	yet_args_needed_1_gc_r

build_node_2_gc_r:
	mov	qword ptr [rdi],rbx
	mov	qword ptr 8[rdi],rdx
	mov	qword ptr 16[rdi],rcx
	mov	rcx,rdi
	add	rdi,24
	ret

build_node_2_gc:
	call	collect_2
	jmp	build_node_2_gc_r


	align	(4)
	sub	r15,5
	jae short build_node_3_gc_r
	jmp short build_node_3_gc
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_2:
	sub	r15,5
	jb	gc_22
gc_r_22:
	mov	rax,qword ptr [rdx]
	mov	qword ptr 8[rdi],rcx
	add	rax,8
	mov	d2,qword ptr 8[rdx]
	mov	qword ptr 16[rdi],rax
	lea	rcx,16[rdi]
	mov	rbp,qword ptr 16[rdx]
	mov	qword ptr 24[rdi],d2
	mov	qword ptr [rdi],rbp
	mov	qword ptr 32[rdi],rdi
	add	rdi,40
	ret

gc_22:	call	collect_2
	jmp	gc_r_22

build_node_3_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,24[rdi]
	mov	qword ptr 8[rdi],r8
	mov	qword ptr 16[rdi],rbp
	mov	qword ptr 24[rdi],rdx
	mov	qword ptr 32[rdi],rcx
	mov	rcx,rdi
	add	rdi,40
	ret

build_node_3_gc:
	call	collect_2
	jmp	build_node_3_gc_r


	align	(4)
	sub	r15,6
	jae short build_node_4_gc_r
	jmp short build_node_4_gc
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_3:
	sub	r15,6
	jb	gc_23
gc_r_23:
	mov	rax,qword ptr [rdx]
	mov	qword ptr 16[rdi],rcx
	add	rax,8
	mov	d2,qword ptr 8[rdx]
	mov	qword ptr 24[rdi],rax
	mov	rdx,qword ptr 16[rdx]
	mov	qword ptr 32[rdi],d2
	mov	rbp,qword ptr [rdx]
	mov	qword ptr 40[rdi],rdi
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr 8[rdx]
	lea	rcx,24[rdi]
	mov	qword ptr 8[rdi],rbp
	add	rdi,48
	ret

gc_23:	call	collect_2
	jmp	gc_r_23

build_node_4_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,24[rdi]
	mov	qword ptr 8[rdi],r8
	mov	qword ptr 16[rdi],rbp
	mov	qword ptr 24[rdi],rdx
	mov	qword ptr 32[rdi],rcx
	mov	rcx,rdi
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr 40[rdi],rbp
	sub	rsi,8
	add	rdi,48
	ret

build_node_4_gc:
	call	collect_2
	jmp	build_node_4_gc_r


	align	(4)
	sub	r15,7
	jae short build_node_5_gc_r
	jmp 	build_node_5_gc
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_4:
	sub	r15,7
	jb	gc_24
gc_r_24:
	mov	rax,qword ptr [rdx]
	mov	qword ptr 24[rdi],rcx
	add	rax,8
	mov	d2,qword ptr 8[rdx]
	mov	qword ptr 32[rdi],rax
	mov	rdx,qword ptr 16[rdx]
	mov	qword ptr 40[rdi],d2
	mov	rbp,qword ptr [rdx]
	mov	48[rdi],rdi
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr 8[rdx]
	lea	rcx,32[rdi]
	mov	qword ptr 8[rdi],rbp
	mov	rbp,qword ptr 16[rdx]
	mov	qword ptr 16[rdi],rbp
	add	rdi,56
	ret

gc_24:	call	collect_2
	jmp	gc_r_24

build_node_5_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,24[rdi]
	mov	qword ptr 8[rdi],r8
	mov	qword ptr 16[rdi],rbp
	mov	qword ptr 24[rdi],rdx
	mov	qword ptr 32[rdi],rcx
	mov	rcx,rdi
	mov	rbp,qword ptr -8[rsi]
	mov	qword ptr 40[rdi],rbp
	mov	rbp,qword ptr -16[rsi]
	mov	qword ptr 48[rdi],rbp
	sub	rsi,16
	add	rdi,56
	ret

build_node_5_gc:
	call	collect_2
	jmp	build_node_5_gc_r


	align	(4)
	mov	eax,8
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_5:
	mov	rbx,qword ptr [rdx]
	mov	rax,8
	jmp	yet_args_needed_


	align	(4)
	mov	eax,9
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_6:
	mov	rbx,qword ptr [rdx]
	mov	rax,9
	jmp	yet_args_needed_

	align	(4)
	mov	eax,10
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_7:
	mov	rbx,qword ptr [rdx]
	mov	rax,10
	jmp	yet_args_needed_

	align	(4)
	mov	eax,11
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_8:
	mov	rbx,qword ptr [rdx]
	mov	rax,11
	jmp	yet_args_needed_

	align	(4)
	mov	eax,12
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_9:
	mov	rbx,qword ptr [rdx]
	mov	rax,12
	jmp	yet_args_needed_

	align	(4)
	mov	eax,13
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_10:
	mov	rbx,qword ptr [rdx]
	mov	rax,13
	jmp	yet_args_needed_

	align	(4)
	mov	eax,14
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_11:
	mov	rbx,qword ptr [rdx]
	mov	rax,14
	jmp	yet_args_needed_

	align	(4)
	mov	eax,15
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_12:
	mov	rbx,qword ptr [rdx]
	mov	rax,15
	jmp	yet_args_needed_

	align	(4)
	mov	eax,16
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_13:
	mov	rbx,qword ptr [rdx]
	mov	rax,16
	jmp	yet_args_needed_

	align	(4)
	mov	eax,17
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_14:
	mov	rbx,qword ptr [rdx]
	mov	rax,17
	jmp	yet_args_needed_

	align	(4)
	mov	eax,18
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_15:
	mov	rbx,qword ptr [rdx]
	mov	rax,18
	jmp	yet_args_needed_

	align	(4)
	mov	eax,19
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_16:
	mov	rbx,qword ptr [rdx]
	mov	rax,19
	jmp	yet_args_needed_

	align	(4)
	mov	eax,20
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_17:
	mov	rbx,qword ptr [rdx]
	mov	rax,20
	jmp	yet_args_needed_

	align	(4)
	mov	eax,21
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_18:
	mov	rbx,qword ptr [rdx]
	mov	rax,21
	jmp	yet_args_needed_

	align	(4)
	mov	eax,22
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_19:
	mov	rbx,qword ptr [rdx]
	mov	rax,22
	jmp	yet_args_needed_

	align	(4)
	mov	eax,23
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_20:
	mov	rbx,qword ptr [rdx]
	mov	rax,23
	jmp	yet_args_needed_

	align	(4)
	mov	eax,24
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_21:
	mov	rbx,qword ptr [rdx]
	mov	rax,24
	jmp	yet_args_needed_

	align	(4)
	mov	eax,25
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_22:
	mov	rbx,qword ptr [rdx]
	mov	rax,25
	jmp	yet_args_needed_

	align	(4)
	mov	eax,26
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_23:
	mov	rbx,qword ptr [rdx]
	mov	rax,26
	jmp	yet_args_needed_

	align	(4)
	mov	eax,27
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_24:
	mov	rbx,qword ptr [rdx]
	mov	rax,27
	jmp	yet_args_needed_

	align	(4)
	mov	eax,28
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_25:
	mov	rbx,qword ptr [rdx]
	mov	rax,28
	jmp	yet_args_needed_

	align	(4)
	mov	eax,29
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_26:
	mov	rbx,qword ptr [rdx]
	mov	rax,29
	jmp	yet_args_needed_

	align	(4)
	mov	eax,30
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_27:
	mov	rbx,qword ptr [rdx]
	mov	rax,30
	jmp	yet_args_needed_

	align	(4)
	mov	eax,31
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_28:
	mov	rbx,qword ptr [rdx]
	mov	rax,31
	jmp	yet_args_needed_

	align	(4)
	mov	eax,32
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_29:
	mov	rbx,qword ptr [rdx]
	mov	rax,32
	jmp	yet_args_needed_

	align	(4)
	mov	eax,33
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_30:
	mov	rbx,qword ptr [rdx]
	mov	rax,33
	jmp	yet_args_needed_

	align	(4)
	mov	eax,34
	jmp	build_node_
	nop
	nop
	align	(4)	
 ifdef PROFILE
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
 endif
yet_args_needed_31:
	mov	rbx,qword ptr [rdx]
	mov	rax,34
	jmp	yet_args_needed_

yet_args_needed:
	mov	rbx,qword ptr [rdx]
	movzx	rax,word ptr -2[rbx]
	add	rax,3
yet_args_needed_:
	sub	r15,rax
	jb	yet_args_needed_gc
yet_args_needed_gc_r:
	mov	d3,qword ptr 8[rdx]
	sub	rax,3+1+4
	mov	rdx,qword ptr 16[rdx]
	mov	d2,rdi
	mov	rbp,qword ptr [rdx]
	mov	qword ptr [rdi],rbp
	mov	rbp,qword ptr 8[rdx]
	mov	qword ptr 8[rdi],rbp
	mov	rbp,qword ptr 16[rdx]
	mov	qword ptr 16[rdi],rbp
	add	rdx,24
	add	rdi,24

yet_args_needed_cp_a:
	mov	rbp,qword ptr [rdx]
	add	rdx,8
	mov	qword ptr [rdi],rbp
	add	rdi,8
	sub	rax,1
	jge	yet_args_needed_cp_a

	mov	qword ptr [rdi],rcx
	add	rbx,8
	mov	qword ptr 8[rdi],rbx
	lea	rcx,8[rdi]
	mov	qword ptr 16[rdi],d3
	mov	qword ptr 24[rdi],d2
	add	rdi,32
	ret

yet_args_needed_gc:
	call	collect_2
	jmp	yet_args_needed_gc_r

build_node_:
	sub	r15,rax
	jb	build_node_gc
build_node_gc_r:
	mov	qword ptr [rdi],rbx
	lea	rbp,24[rdi]
	mov	qword ptr 8[rdi],r8
	mov	qword ptr 16[rdi],rbp
	mov	qword ptr 24[rdi],rdx
	mov	qword ptr 32[rdi],rcx
	mov	rcx,rdi
	mov	r8,qword ptr -8[rsi]
	mov	qword ptr 40[rdi],r8
	mov	r8,qword ptr -16[rsi]
	sub	rsi,16
	mov	qword ptr 48[rdi],r8
	add	rdi,56

	sub	rax,5+2
build_node_cp_a:
	mov	r8,qword ptr -8[rsi]
	sub	rsi,8
	mov	qword ptr [rdi],r8
	add	rdi,8
	sub	rax,1
	jne	build_node_cp_a

	ret

build_node_gc:
	call	collect_3
	jmp	build_node_gc_r
	
_TEXT	ends

 ifndef NEW_DESCRIPTORS
	end
 endif
