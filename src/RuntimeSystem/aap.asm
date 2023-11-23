
	d0 equ rax
	d1 equ rbx
	d2 equ r10
	d3 equ r11
	d7 equ r15
	a0 equ rcx
	a1 equ rdx
	a2 equ r8
	a3 equ r9
	a5 equ rsi
	a6 equ rdi

	d0l equ eax
	a2l equ r8d
	a3l equ r9d

	d1w equ bx

	qw equ qword ptr

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
	mov	a3,qw [a2]
	mov	d1,32*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap32

ap_31:
	mov	a3,qw [a2]
	mov	d1,31*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap31

ap_30:
	mov	a3,qw [a2]
	mov	d1,30*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap30

ap_29:
	mov	a3,qw [a2]
	mov	d1,29*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap29

ap_28:
	mov	a3,qw [a2]
	mov	d1,28*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap28

ap_27:
	mov	a3,qw [a2]
	mov	d1,27*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap27

ap_26:
	mov	a3,qw [a2]
	mov	d1,26*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap26

ap_25:
	mov	a3,qw [a2]
	mov	d1,25*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap25

ap_24:
	mov	a3,qw [a2]
	mov	d1,24*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap24

ap_23:
	mov	a3,qw [a2]
	mov	d1,23*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap23

ap_22:
	mov	a3,qw [a2]
	mov	d1,22*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap22

ap_21:
	mov	a3,qw [a2]
	mov	d1,21*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap21

ap_20:
	mov	a3,qw [a2]
	mov	d1,20*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap20

ap_19:
	mov	a3,qw [a2]
	mov	d1,19*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap19

ap_18:
	mov	a3,qw [a2]
	mov	d1,18*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap18

ap_17:
	mov	a3,qw [a2]
	mov	d1,17*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap17

ap_16:
	mov	a3,qw [a2]
	mov	d1,16*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap16

ap_15:
	mov	a3,qw [a2]
	mov	d1,15*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap15

ap_14:
	mov	a3,qw [a2]
	mov	d1,14*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap14

ap_13:
	mov	a3,qw [a2]
	mov	d1,13*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap13

ap_12:
	mov	a3,qw [a2]
	mov	d1,12*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap12

ap_11:
	mov	a3,qw [a2]
	mov	d1,11*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap11

ap_10:
	mov	a3,qw [a2]
	mov	d1,10*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap10

ap_9:
	mov	a3,qw [a2]
	mov	d1,9*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap9

ap_8:
	mov	a3,qw [a2]
	mov	d1,8*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap8

ap_7:
	mov	a3,qw [a2]
	mov	d1,7*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap7

ap_6:
	mov	a3,qw [a2]
	mov	d1,6*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap6

ap_5:
	mov	a3,qw [a2]
	mov	d1,5*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap5

ap_4:
	mov	a3,qw [a2]
	mov	d1,4*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap4

ap_3:
	mov	a3,qw [a2]
	mov	d1,3*8
	cmp	word ptr [a3],bx
	je	fast_ap

	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap3

ap_2:
	mov	a3,qw [a2]
	mov	d1,2*8
	cmp	word ptr [a3],bx
	jne	no_fast_ap2_

fast_ap_2_2_:
	movzx	d0,word ptr -2[a3]
	add	d1,a3
	mov	a3l,dword ptr -6[d1]
 ifdef PROFILE
	sub	a3,24
 else
	sub	a3,12
 endif
	cmp	d0,1
	jb	repl_args_0_2
	je	repl_args_1

	cmp	d0,3
	jb	repl_args_2

	mov	qw [a5],a0
	mov	qw 8[a5],a1
	lea	a5,16[a5]
	mov	a1,qw 16[a2]

	jmp	fast_ap_

no_fast_ap2_:
	mov	qw [a5],a0
	mov	a0,a1
	mov	a1,a2
	mov	a2l,dword ptr 2[a3]
	add	a5,8
	jmp	no_fast_ap2

fast_ap_2_2:
	mov	a2,a1
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8
	jmp	fast_ap_2_2_

fast_ap_2:
	mov	a2,a1
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

fast_ap:
	movzx	d0,word ptr -2[a3]
	add	d1,a3
	mov	a3l,dword ptr -6[d1]
 ifdef PROFILE
	sub	a3,24
 else
	sub	a3,12
 endif
	cmp	d0,1
	jb	repl_args_0
	je	repl_args_1

	cmp	d0,3
	jb	repl_args_2

	mov	qw [a5],a0
	mov	qw 8[a5],a1
	lea	a5,16[a5]
	mov	a1,qw 16[a2]

fast_ap_:
	mov	a2,qw 8[a2]
	je	repl_args_3

	cmp	d0,5
	jb	repl_args_4
	je	repl_args_5

	cmp	d0,7
	jb	repl_args_6

repl_args_7_:
	mov	rbp,qw -16[a1+d0*8]
	mov	qw [a5],rbp
	sub	d0,1
	add	a5,8
	cmp	d0,6
	jne	repl_args_7_

repl_args_6:
	mov	d0,qw 32[a1]
	mov	qw [a5],d0
	mov	d0,qw 24[a1]
	mov	qw 8[a5],d0
	mov	d0,qw 16[a1]
	mov	qw 16[a5],d0
	mov	a0,qw 8[a1]
	mov	a1,qw [a1]
	add	a5,24
	jmp	a3

repl_args_0:
	mov	a2,a1
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8
repl_args_0_2:
	jmp	a3

repl_args_1:
	mov	a2,qw 8[a2]
	jmp	a3

repl_args_2:
	mov	qw [a5],a0
	mov	a0,a1
	add	a5,8
	mov	a1,qw 16[a2]
	mov	a2,qw 8[a2]
	jmp	a3

repl_args_3:
	mov	a0,qw 8[a1]
	mov	a1,qw [a1]
	jmp	a3

repl_args_4:
	mov	d0,qw 16[a1]
	mov	qw [a5],d0
	mov	a0,qw 8[a1]
	mov	a1,qw [a1]
	add	a5,8
	jmp	a3

repl_args_5:
	mov	d0,qw 24[a1]
	mov	qw [a5],d0
	mov	d0,qw 16[a1]
	mov	qw 8[a5],d0
	mov	a0,qw 8[a1]
	mov	a1,qw [a1]
	add	a5,16
	jmp	a3


no_fast_ap32:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,31*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap31:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,30*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap30:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,29*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap29:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,28*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap28:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,27*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap27:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,26*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap26:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,25*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap25:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,24*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap24:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,23*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap23:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,22*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap22:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,21*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap21:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,20*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap20:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,19*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap19:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,18*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap18:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,17*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap17:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,16*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap16:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,15*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap15:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,14*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap14:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,13*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap13:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,12*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap12:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,11*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap11:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,10*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap10:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,9*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap9:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,8*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap8:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,7*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap7:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,6*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap6:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,5*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap5:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,4*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap4:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,3*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap3:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8

	mov	d1,2*8
 	cmp	word ptr [a3],d1w
	je	fast_ap_2_2

	mov	a2l,dword ptr 2[a3]
no_fast_ap2:
	call	a2
	mov	a3,qw [a0]
	mov	a1,a0
	mov	a0,qw -8[a5]
	sub	a5,8
	mov	a2l,dword ptr 2[a3]
	jmp	a2


add_empty_node_2:
	sub	d7,3
	jb	add_empty_node_2_gc
add_empty_node_2_gc_:
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	mov	a2,a1
	mov	a1,a0
	mov	a0,a6
	add	a6,24
	ret
add_empty_node_2_gc:
	call	collect_2
	jmp	add_empty_node_2_gc_

add_empty_node_3:
	sub	d7,3
	jb	add_empty_node_3_gc
add_empty_node_3_gc_:
	mov	qw [a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_3_gc:
	call	collect_3
	jmp	add_empty_node_3_gc_

add_empty_node_4:
	sub	d7,3
	jb	add_empty_node_4_gc
add_empty_node_4_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	qw -8[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_4_gc:
	call	collect_3
	jmp	add_empty_node_4_gc_

add_empty_node_5:
	sub	d7,3
	jb	add_empty_node_5_gc
add_empty_node_5_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	qw -16[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_5_gc:
	call	collect_3
	jmp	add_empty_node_5_gc_

add_empty_node_6:
	sub	d7,3
	jb	add_empty_node_6_gc
add_empty_node_6_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	qw -24[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_6_gc:
	call	collect_3
	jmp	add_empty_node_6_gc_

add_empty_node_7:
	sub	d7,3
	jb	add_empty_node_7_gc
add_empty_node_7_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	a3,qw -32[a5]
	mov	qw -24[a5],a3
	mov	qw -32[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_7_gc:
	call	collect_3
	jmp	add_empty_node_7_gc_

add_empty_node_8:
	sub	d7,3
	jb	add_empty_node_8_gc
add_empty_node_8_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	a3,qw -32[a5]
	mov	qw -24[a5],a3
	mov	a3,qw -40[a5]
	mov	qw -32[a5],a3
	mov	qw -40[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_8_gc:
	call	collect_3
	jmp	add_empty_node_8_gc_

add_empty_node_9:
	sub	d7,3
	jb	add_empty_node_9_gc
add_empty_node_9_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	a3,qw -32[a5]
	mov	qw -24[a5],a3
	mov	a3,qw -40[a5]
	mov	qw -32[a5],a3
	mov	a3,qw -48[a5]
	mov	qw -40[a5],a3
	mov	qw -48[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_9_gc:
	call	collect_3
	jmp	add_empty_node_9_gc_

add_empty_node_10:
	sub	d7,3
	jb	add_empty_node_10_gc
add_empty_node_10_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	a3,qw -32[a5]
	mov	qw -24[a5],a3
	mov	a3,qw -40[a5]
	mov	qw -32[a5],a3
	mov	a3,qw -48[a5]
	mov	qw -40[a5],a3
	mov	a3,qw -56[a5]
	mov	qw -48[a5],a3
	mov	qw -56[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_10_gc:
	call	collect_3
	jmp	add_empty_node_10_gc_

add_empty_node_11:
	sub	d7,3
	jb	add_empty_node_11_gc
add_empty_node_11_gc_:
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
	mov	a3,qw -32[a5]
	mov	qw -24[a5],a3
	mov	a3,qw -40[a5]
	mov	qw -32[a5],a3
	mov	a3,qw -48[a5]
	mov	qw -40[a5],a3
	mov	a3,qw -56[a5]
	mov	qw -48[a5],a3
	mov	a3,qw -64[a5]
	mov	qw -56[a5],a3
	mov	qw -64[a5],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_11_gc:
	call	collect_3
	jmp	add_empty_node_11_gc_

add_empty_node_32:
	mov	d1,7
	jmp	add_empty_node_12_
add_empty_node_28:
	mov	d1,6
	jmp	add_empty_node_12_
add_empty_node_24:
	mov	d1,5
	jmp	add_empty_node_12_
add_empty_node_20:
	mov	d1,4
	jmp	add_empty_node_12_
add_empty_node_16:
	mov	d1,3
	jmp	add_empty_node_12_
add_empty_node_12:
	mov	d1,2
add_empty_node_12_:
	sub	d7,3
	jb	add_empty_node_12_gc
add_empty_node_12_gc_:
	mov	d0,a5
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
add_empty_node_12_lp:
	mov	a3,qw -16[d0]
	mov	qw -8[d0],a3
	mov	a3,qw -24[d0]
	mov	qw -16[d0],a3
	mov	a3,qw -32[d0]
	mov	qw -24[d0],a3
	mov	a3,qw -40[d0]
	mov	qw -32[d0],a3
	sub	d0,32
	sub	d1,1
	jne	add_empty_node_12_lp
	mov	qw -8[d0],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_12_gc:
	call	collect_3
	jmp	add_empty_node_12_gc_

add_empty_node_29:
	mov	d1,6
	jmp	add_empty_node_13_
add_empty_node_25:
	mov	d1,5
	jmp	add_empty_node_13_
add_empty_node_21:
	mov	d1,4
	jmp	add_empty_node_13_
add_empty_node_17:
	mov	d1,3
	jmp	add_empty_node_13_
add_empty_node_13:
	mov	d1,2
add_empty_node_13_:
	sub	d7,3
	jb	add_empty_node_13_gc
add_empty_node_13_gc_:
	mov	d0,a5
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
add_empty_node_13_lp:
	mov	a3,qw -24[d0]
	mov	qw -16[d0],a3
	mov	a3,qw -32[d0]
	mov	qw -24[d0],a3
	mov	a3,qw -40[d0]
	mov	qw -32[d0],a3
	mov	a3,qw -48[d0]
	mov	qw -40[d0],a3
	sub	d0,32
	sub	d1,1
	jne	add_empty_node_13_lp
	mov	qw -16[d0],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_13_gc:
	call	collect_3
	jmp	add_empty_node_13_gc_

add_empty_node_30:
	mov	d1,6
	jmp	add_empty_node_14_
add_empty_node_26:
	mov	d1,5
	jmp	add_empty_node_14_
add_empty_node_22:
	mov	d1,4
	jmp	add_empty_node_14_
add_empty_node_18:
	mov	d1,3
	jmp	add_empty_node_14_
add_empty_node_14:
	mov	d1,2
add_empty_node_14_:
	sub	d7,3
	jb	add_empty_node_14_gc
add_empty_node_14_gc_:
	mov	d0,a5
	mov	a3,qw -8[a5]
	mov	qw [a5],a3
	mov	a3,qw -16[a5]
	mov	qw -8[a5],a3
	mov	a3,qw -24[a5]
	mov	qw -16[a5],a3
add_empty_node_14_lp:
	mov	a3,qw -32[d0]
	mov	qw -24[d0],a3
	mov	a3,qw -40[d0]
	mov	qw -32[d0],a3
	mov	a3,qw -48[d0]
	mov	qw -40[d0],a3
	mov	a3,qw -56[d0]
	mov	qw -48[d0],a3
	sub	d0,32
	sub	d1,1
	jne	add_empty_node_14_lp
	mov	qw -24[d0],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_14_gc:
	call	collect_3
	jmp	add_empty_node_14_gc_

add_empty_node_31:
	mov	d1,7
	jmp	add_empty_node_15_
add_empty_node_27:
	mov	d1,6
	jmp	add_empty_node_15_
add_empty_node_23:
	mov	d1,5
	jmp	add_empty_node_15_
add_empty_node_19:
	mov	d1,4
	jmp	add_empty_node_15_
add_empty_node_15:
	mov	d1,3
add_empty_node_15_:
	sub	d7,3
	jb	add_empty_node_15_gc
add_empty_node_15_gc_:
	mov	d0,a5
add_empty_node_15_lp:
	mov	a3,qw -8[d0]
	mov	qw [d0],a3
	mov	a3,qw -16[d0]
	mov	qw -8[d0],a3
	mov	a3,qw -24[d0]
	mov	qw -16[d0],a3
	mov	a3,qw -32[d0]
	mov	qw -24[d0],a3
	sub	d0,32
	sub	d1,1
	jne	add_empty_node_15_lp
	mov	qw [d0],a6
 ifdef PIC
	lea	rbp,__cycle__in__spine+0
	mov	qw [a6],rbp
 else
	mov	qw [a6],offset __cycle__in__spine
 endif
	add	a5,8
	add	a6,24
	ret
add_empty_node_15_gc:
	call	collect_3
	jmp	add_empty_node_15_gc_


yet_args_needed_0:
	sub	d7,2
	jb	yet_args_needed_0_gc
yet_args_needed_0_gc_r:
	mov	qw 8[a6],a0
	mov	d0,qw [a1]
	mov	a0,a6
	add	d0,8
	mov	qw [a6],d0
	add	a6,16
	ret

yet_args_needed_0_gc:
	call	collect_2
	jmp	yet_args_needed_0_gc_r


	align	(4)
	sub	d7,3
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
	sub	d7,3
	jb	yet_args_needed_1_gc
yet_args_needed_1_gc_r:
	mov	qw 16[a6],a0
	mov	d0,qw [a1]
	mov	a0,a6
	add	d0,8
	mov	qw [a6],d0
	mov	d1,qw 8[a1]
	mov	qw 8[a6],d1
	add	a6,24
	ret

yet_args_needed_1_gc:
	call	collect_2
	jmp	yet_args_needed_1_gc_r

build_node_2_gc_r:
	mov	qw [a6],d1
	mov	qw 8[a6],a1
	mov	qw 16[a6],a0
	mov	a0,a6
	add	a6,24
	ret

build_node_2_gc:
	call	collect_2
	jmp	build_node_2_gc_r


	align	(4)
	sub	d7,5
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
	sub	d7,5
	jb	gc_22
gc_r_22:
	mov	d0,qw [a1]
	mov	qw 8[a6],a0
	add	d0,8
	mov	d2,qw 8[a1]
	mov	qw 16[a6],d0
	lea	a0,16[a6]
	mov	rbp,qw 16[a1]
	mov	qw 24[a6],d2
	mov	qw [a6],rbp
	mov	qw 32[a6],a6
	add	a6,40
	ret

gc_22:	call	collect_2
	jmp	gc_r_22

build_node_3_gc_r:
	mov	qw [a6],d1
	lea	rbp,24[a6]
	mov	qw 8[a6],a2
	mov	qw 16[a6],rbp
	mov	qw 24[a6],a1
	mov	qw 32[a6],a0
	mov	a0,a6
	add	a6,40
	ret

build_node_3_gc:
	call	collect_2
	jmp	build_node_3_gc_r


	align	(4)
	sub	d7,6
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
	sub	d7,6
	jb	gc_23
gc_r_23:
	mov	d0,qw [a1]
	mov	qw 16[a6],a0
	add	d0,8
	mov	d2,qw 8[a1]
	mov	qw 24[a6],d0
	mov	a1,qw 16[a1]
	mov	qw 32[a6],d2
	mov	rbp,qw [a1]
	mov	qw 40[a6],a6
	mov	qw [a6],rbp
	mov	rbp,qw 8[a1]
	lea	a0,24[a6]
	mov	qw 8[a6],rbp
	add	a6,48
	ret

gc_23:	call	collect_2
	jmp	gc_r_23

build_node_4_gc_r:
	mov	qw [a6],d1
	lea	rbp,24[a6]
	mov	qw 8[a6],a2
	mov	qw 16[a6],rbp
	mov	qw 24[a6],a1
	mov	qw 32[a6],a0
	mov	a0,a6
	mov	rbp,qw -8[a5]
	mov	qw 40[a6],rbp
	sub	a5,8
	add	a6,48
	ret

build_node_4_gc:
	call	collect_2
	jmp	build_node_4_gc_r


	align	(4)
	sub	d7,7
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
	sub	d7,7
	jb	gc_24
gc_r_24:
	mov	d0,qw [a1]
	mov	qw 24[a6],a0
	add	d0,8
	mov	d2,qw 8[a1]
	mov	qw 32[a6],d0
	mov	a1,qw 16[a1]
	mov	qw 40[a6],d2
	mov	rbp,qw [a1]
	mov	48[a6],a6
	mov	qw [a6],rbp
	mov	rbp,qw 8[a1]
	lea	a0,32[a6]
	mov	qw 8[a6],rbp
	mov	rbp,qw 16[a1]
	mov	qw 16[a6],rbp
	add	a6,56
	ret

gc_24:	call	collect_2
	jmp	gc_r_24

build_node_5_gc_r:
	mov	qw [a6],d1
	lea	rbp,24[a6]
	mov	qw 8[a6],a2
	mov	qw 16[a6],rbp
	mov	qw 24[a6],a1
	mov	qw 32[a6],a0
	mov	a0,a6
	mov	rbp,qw -8[a5]
	mov	qw 40[a6],rbp
	mov	rbp,qw -16[a5]
	mov	qw 48[a6],rbp
	sub	a5,16
	add	a6,56
	ret

build_node_5_gc:
	call	collect_2
	jmp	build_node_5_gc_r


	align	(4)
	mov	d0l,8
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
	mov	d1,qw [a1]
	mov	d0,8
	jmp	yet_args_needed_


	align	(4)
	mov	d0l,9
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
	mov	d1,qw [a1]
	mov	d0,9
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,10
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
	mov	d1,qw [a1]
	mov	d0,10
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,11
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
	mov	d1,qw [a1]
	mov	d0,11
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,12
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
	mov	d1,qw [a1]
	mov	d0,12
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,13
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
	mov	d1,qw [a1]
	mov	d0,13
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,14
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
	mov	d1,qw [a1]
	mov	d0,14
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,15
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
	mov	d1,qw [a1]
	mov	d0,15
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,16
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
	mov	d1,qw [a1]
	mov	d0,16
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,17
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
	mov	d1,qw [a1]
	mov	d0,17
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,18
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
	mov	d1,qw [a1]
	mov	d0,18
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,19
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
	mov	d1,qw [a1]
	mov	d0,19
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,20
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
	mov	d1,qw [a1]
	mov	d0,20
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,21
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
	mov	d1,qw [a1]
	mov	d0,21
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,22
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
	mov	d1,qw [a1]
	mov	d0,22
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,23
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
	mov	d1,qw [a1]
	mov	d0,23
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,24
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
	mov	d1,qw [a1]
	mov	d0,24
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,25
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
	mov	d1,qw [a1]
	mov	d0,25
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,26
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
	mov	d1,qw [a1]
	mov	d0,26
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,27
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
	mov	d1,qw [a1]
	mov	d0,27
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,28
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
	mov	d1,qw [a1]
	mov	d0,28
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,29
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
	mov	d1,qw [a1]
	mov	d0,29
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,30
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
	mov	d1,qw [a1]
	mov	d0,30
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,31
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
	mov	d1,qw [a1]
	mov	d0,31
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,32
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
	mov	d1,qw [a1]
	mov	d0,32
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,33
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
	mov	d1,qw [a1]
	mov	d0,33
	jmp	yet_args_needed_

	align	(4)
	mov	d0l,34
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
	mov	d1,qw [a1]
	mov	d0,34
	jmp	yet_args_needed_

yet_args_needed:
	mov	d1,qw [a1]
	movzx	d0,word ptr -2[d1]
	add	d0,3
yet_args_needed_:
	sub	d7,d0
	jb	yet_args_needed_gc
yet_args_needed_gc_r:
	mov	d3,qw 8[a1]
	sub	d0,3+1+4
	mov	a1,qw 16[a1]
	mov	d2,a6
	mov	rbp,qw [a1]
	mov	qw [a6],rbp
	mov	rbp,qw 8[a1]
	mov	qw 8[a6],rbp
	mov	rbp,qw 16[a1]
	mov	qw 16[a6],rbp
	add	a1,24
	add	a6,24

yet_args_needed_cp_a:
	mov	rbp,qw [a1]
	add	a1,8
	mov	qw [a6],rbp
	add	a6,8
	sub	d0,1
	jge	yet_args_needed_cp_a

	mov	qw [a6],a0
	add	d1,8
	mov	qw 8[a6],d1
	lea	a0,8[a6]
	mov	qw 16[a6],d3
	mov	qw 24[a6],d2
	add	a6,32
	ret

yet_args_needed_gc:
	call	collect_2
	jmp	yet_args_needed_gc_r

build_node_:
	sub	d7,d0
	jb	build_node_gc
build_node_gc_r:
	mov	qw [a6],d1
	lea	rbp,24[a6]
	mov	qw 8[a6],a2
	mov	qw 16[a6],rbp
	mov	qw 24[a6],a1
	mov	qw 32[a6],a0
	mov	a0,a6
	mov	a2,qw -8[a5]
	mov	qw 40[a6],a2
	mov	a2,qw -16[a5]
	sub	a5,16
	mov	qw 48[a6],a2
	add	a6,56

	sub	d0,5+2
build_node_cp_a:
	mov	a2,qw -8[a5]
	sub	a5,8
	mov	qw [a6],a2
	add	a6,8
	sub	d0,1
	jne	build_node_cp_a

	ret

build_node_gc:
	call	collect_3
	jmp	build_node_gc_r
	
_TEXT	ends

 ifndef NEW_DESCRIPTORS
	end
 endif
