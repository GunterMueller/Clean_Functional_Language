
_DATA	segment para 'DATA'
_DATA	ends

_T000	segment para 'CODE'

	public	sin_real

sin_real:
	ucomisd	xmm0,qword ptr real_pi_d_4
	jbe		sin_real_1					; x<=pi/4 | NAN
	ucomisd	xmm0,qword ptr real_3_pi_d_4
	jbe		sin_real_2
	ucomisd	xmm0,qword ptr real_5_pi_d_4
	jbe		sin_real_3
	ucomisd	xmm0,qword ptr real_7_pi_d_4
	jbe		sin_real_4
	ucomisd	xmm0,qword ptr real_9_pi_d_4
	jbe		sin_real_5

	ucomisd	xmm0,qword ptr real_36825084_pi
	jbe		sin_real_0

	ucomisd	xmm0,qword ptr real_2_p_53
	jae		sin_or_cos_real_too_large	; x>=-2^53

	call	rem_36825084_pi

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

	subsd	xmm13,xmm7
	jmp		sin_real_0_

sin_real_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi

	movq	xmm4,qword ptr round_even_c
	
	addsd	xmm1,qword ptr real_1_0	; x*4/pi+1
	
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1

	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi+1)

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm6,xmm4

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

sin_real_0_:
	ucomisd	xmm1,xmm5
	jne		sin_real_cos

sin_real_sin:
	ucomisd	xmm1,xmm6
	jne		sin_real_n_sin

	subsd	xmm0,xmm2
	subsd	xmm0,xmm3

	jmp		sin_real_p

sin_real_n_sin:
	movsd	xmm1,xmm3
	subsd	xmm0,xmm2
	subsd	xmm1,xmm0
	jmp		sin_real_m

sin_real_cos:
	subsd	xmm0,xmm2
	subsd	xmm0,xmm3

	ucomisd	xmm1,xmm6
	je		cos_real_p
	jmp		cos_real_m

sin_real_n:
	ucomisd	xmm0,qword ptr real_m_3_pi_d_4
	jae		sin_real_n_2
	ucomisd	xmm0,qword ptr real_m_5_pi_d_4
	jae		sin_real_n_3
	ucomisd	xmm0,qword ptr real_m_7_pi_d_4
	jae		sin_real_n_4
	ucomisd	xmm0,qword ptr real_m_9_pi_d_4
	jae		sin_real_n_5

	ucomisd	xmm0,qword ptr real_m_36825084_pi
	jae		sin_real_n_0

	ucomisd	xmm0,qword ptr real_m_2_p_53
	jbe		sin_or_cos_real_too_small_or_nan	; x<=-2^53 | NAN

	call	rem_n_36825084_pi

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

	subsd	xmm13,xmm7
	jmp		sin_real_n_0_

sin_real_n_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi
	
	movq	xmm4,qword ptr m_round_even_c

	subsd	xmm1,qword ptr real_1_0	; x*4/pi-1
	
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1

	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi-1)

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm6,xmm4

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

sin_real_n_0_:
	ucomisd	xmm1,xmm5
	je		sin_real_sin

	subsd	xmm0,xmm2
	subsd	xmm0,xmm3

	ucomisd	xmm1,xmm6
	jne		cos_real_p
	jmp		cos_real_m

sin_real_1:
	ucomisd	xmm0,qword ptr real_m_pi_d_4
	jb		sin_real_n				; ; x<-pi/4 | NAN

	ucomisd	xmm0,qword ptr real_0_43540000008249979402
	jae		sin_real_p_0_6
	ucomisd	xmm0,qword ptr real_m_0_43540000008249979402
	jbe		sin_real_m_0_6

	movsd	xmm1,xmm0				; x

	ucomisd	xmm0,qword ptr real_0_0
	je		sin_real_0_0			; sin -0.0 = -0.0

	mulsd	xmm0,xmm0				; x2

	movlpd	xmm5,qword ptr sin_p_0
	movlpd	xmm6,qword ptr sin_p_1

	movsd	xmm2,xmm1				; x
	mulsd	xmm1,xmm0				; x3
	
	movsd	xmm3,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

;	ucomisd	xmm3,qword ptr real_0_25 ; x2>=0.25 (|x|>0.5)

	mulsd	xmm3,xmm1				; x5

	movlpd	xmm7,qword ptr sin_p_2
	movlpd	xmm8,qword ptr sin_p_3
	
	mulsd	xmm5,xmm1				; p3
	mulsd	xmm1,xmm0				; x7

	mulsd	xmm6,xmm3				; p5
	mulsd	xmm3,xmm0				; x9

	mulsd	xmm7,xmm1				; p7
	mulsd	xmm1,xmm0				; x11
	
	mulsd	xmm8,xmm3				; p9
	mulsd	xmm3,xmm0				; x13

	mulsd	xmm1,qword ptr sin_p_4	; p11
	mulsd	xmm3,qword ptr sin_p_5	; p13
	
	movsd	xmm0,xmm2				; x

	addsd	xmm1,xmm3				; p11+p13
	addsd	xmm1,xmm8				; p9+p11+p13
	
;	jae		sin_real_1_l

	addsd	xmm1,xmm7				; p7+p9+p11+p13
	addsd	xmm1,xmm6				; p5+p7+p9+p11+p13
	addsd	xmm1,xmm5				; p3+p5+p7+p9+p11+p13
	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

sin_real_0_0:
	ret

;sin_real_1_l:
;	movlpd	xmm2,qword ptr real_47_bits
;	andpd	xmm2,xmm5				; p3h

;	addsd	xmm1,xmm7				; p7+p9+p11+p13

;	subsd	xmm5,xmm2				; p3l
;	addsd	xmm0,xmm2				; x+p3h

;	addsd	xmm1,xmm6				; p5+p7+p9+p11+p13
;	addsd	xmm1,xmm5				; p3l+p5+p7+p9+p11+p13
;	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

;	ret

sin_real_m_0_6:
	movlpd	xmm1,qword ptr real_m_0_600000000082499762577

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	lea		rcx,sin_p3_c
	lea		rdx,sin_p4_c

	cmova	rcx,rdx
	
	jmp		sin_real_0_6

sin_real_p_0_6:
	movlpd	xmm1,qword ptr real_0_600000000082499762577

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	lea		rcx,sin_p1_c
	lea		rdx,sin_p2_c

	cmovb	rcx,rdx

sin_real_0_6:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm7,qword ptr (sin_p1_3-sin_p1_c)[rcx]
	movlpd	xmm8,qword ptr (sin_p1_2-sin_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm7,xmm2				; p3
	mulsd	xmm8,xmm2				; p2

	movlpd	xmm9,qword ptr (sin_p1_5-sin_p1_c)[rcx]

	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8
	
	mulsd	xmm9,xmm4				; p5
	mulsd	xmm4,qword ptr (sin_p1_4-sin_p1_c)[rcx] ; p4

	movlpd	xmm11,qword ptr (sin_p1_7-sin_p1_c)[rcx]
	movlpd	xmm12,qword ptr (sin_p1_9-sin_p1_c)[rcx]

	mulsd	xmm11,xmm2				; p7
	mulsd	xmm2,qword ptr (sin_p1_6-sin_p1_c)[rcx] ; p6

	mulsd	xmm12,xmm0				; p9
	mulsd	xmm0,qword ptr (sin_p1_8-sin_p1_c)[rcx] ; p8
		
	addsd	xmm11,xmm12				; p9+p7
	addsd	xmm0,xmm2				; p8+p6

	movlpd	xmm2,qword ptr real_26_bits
	movsd	xmm3,xmm1				; x
	movlpd	xmm6,qword ptr (sin_p1_1l-sin_p1_c)[rcx]
	movlpd	xmm5,qword ptr (sin_p1_1h-sin_p1_c)[rcx]

	addsd	xmm9,xmm11				; p9+p7+p5
	addsd	xmm0,xmm4				; p8+p6+p4

	andpd	xmm2,xmm1				; x_h
	mulsd	xmm6,xmm1				; x*c1l
	movlpd	xmm13,qword ptr (sin_p1_0h-sin_p1_c)[rcx]

	addsd	xmm7,xmm9				; p9+p7+p5+p3
	addsd	xmm0,xmm8				; p8+p6+p4+p2

	subsd	xmm3,xmm2				; x_l
	mulsd	xmm2,xmm5				; x_h*c1h

	mulsd	xmm7,xmm1				; (p9+p7+p5+p3)(*x)

	movsd	xmm14,xmm13
	addsd	xmm13,xmm2				; x_h*c1h+c0h
	
	addsd	xmm0,xmm7				; p9+p8+..+p2

	subsd	xmm14,xmm13				; c0h-(x_h*c1h+c0h)
	mulsd	xmm3,xmm5				; x_l*c1h

;	addsd	xmm0,qword ptr (sin_p1_0l-sin_p1_c)[rcx]
	
	addsd	xmm14,xmm2				; (c0h-(x_h*c1h+c0h))+x_h*c1h
	addsd	xmm3,xmm6				; x_l*c1h+x*c1l
	
	addsd	xmm3,xmm14				; (c0h-(x_h*c1h+c0h))+x_h*c1h+x_l*c1h+x*c1l

	addsd	xmm0,xmm3
	addsd	xmm0,xmm13
	ret

sin_real_n_5:
	addsd	xmm0,qword ptr real_2_pi
	movlpd	xmm13,qword ptr real_m_2_pi_l
	jmp		sin_real_p

sin_real_5:
	subsd	xmm0,qword ptr real_2_pi
	movlpd	xmm13,qword ptr real_2_pi_l
	jmp		sin_real_p

cos_real_n_2:
	addsd	xmm0,qword ptr real_pi_d_2
	movlpd	xmm13,qword ptr real_m_pi_d_2_l
	jmp		sin_real_p

cos_real_4:
	subsd	xmm0,qword ptr real_3_pi_d_2
	movlpd	xmm13,qword ptr real_3_pi_d_2_l

sin_real_p:
	ucomisd	xmm0,qword ptr real_0_43540000008249979402

	movsd	xmm12,xmm0

	jae		sin_real_p_p_0_6
	ucomisd	xmm0,qword ptr real_m_0_43540000008249979402
	jb		sin_real_p_m_0_6

	subsd	xmm0,xmm13

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	subsd	xmm12,xmm1

	movlpd	xmm5,qword ptr sin_p_0
	movlpd	xmm6,qword ptr sin_p_1

	movsd	xmm2,xmm1				; x
	mulsd	xmm1,xmm0				; x3
	
	movsd	xmm3,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	subsd	xmm12,xmm13				; x_l
	movsd	xmm14,xmm3				; x2

;	ucomisd	xmm3,qword ptr real_0_25 ; x2>=0.25 (|x|>0.5)

	mulsd	xmm3,xmm1				; x5

	movlpd	xmm7,qword ptr sin_p_2
	movlpd	xmm8,qword ptr sin_p_3
		
	mulsd	xmm5,xmm1				; p3
	mulsd	xmm1,xmm0				; x7

	mulsd	xmm6,xmm3				; p5
	mulsd	xmm3,xmm0				; x9

	mulsd	xmm7,xmm1				; p7
	mulsd	xmm1,xmm0				; x11
	
	mulsd	xmm8,xmm3				; p9
	mulsd	xmm3,xmm0				; x13

	mulsd	xmm14,xmm12				; x_l*x2

	mulsd	xmm1,qword ptr sin_p_4	; p11
	mulsd	xmm3,qword ptr sin_p_5	; p13
	
	movsd	xmm0,xmm2				; x

	mulsd	xmm14,qword ptr real_0_5 ; 0.5*x_l*x2

	addsd	xmm1,xmm3				; p11+p13

	subsd	xmm12,xmm14				; x_l-0.5*x_l*x2

	addsd	xmm1,xmm8				; p9+p11+p13

;	jae		sin_real_p_l

	addsd	xmm1,xmm7				; p7+p9+p11+p13
	addsd	xmm1,xmm6				; p5+p7+p9+p11+p13
	addsd	xmm1,xmm5				; p3+p5+p7+p9+p11+p13

	addsd	xmm1,xmm12

	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

	ret

;sin_real_p_l:
;	movlpd	xmm2,qword ptr real_47_bits
;	andpd	xmm2,xmm5				; p3h

;	addsd	xmm1,xmm7				; p7+p9+p11+p13

;	subsd	xmm5,xmm2				; p3l
;	addsd	xmm0,xmm2				; x+p3h

;	addsd	xmm1,xmm6				; p5+p7+p9+p11+p13
;	addsd	xmm1,xmm5				; p3+p5+p7+p9+p11+p13

;	addsd	xmm1,xmm12

;	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

;	ret

sin_real_p_m_0_6:
	movlpd	xmm1,qword ptr real_m_0_600000000082499762577

	subsd	xmm0,xmm13

	ucomisd	xmm0,xmm1
	movsd	xmm15,xmm0				; x1
	subsd	xmm0,xmm1

	lea		rcx,sin_p3_c
	lea		rdx,sin_p4_c

	cmova	rcx,rdx
	jmp		sin_real_p_pm_0_6

sin_real_p_p_0_6:
	movlpd	xmm1,qword ptr real_0_600000000082499762577

	subsd	xmm0,xmm13

	ucomisd	xmm0,xmm1
	movsd	xmm15,xmm0				; x1
	subsd	xmm0,xmm1

	lea		rcx,sin_p1_c
	lea		rdx,sin_p2_c

	cmovb	rcx,rdx

sin_real_p_pm_0_6:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2
	subsd	xmm12,xmm15
	mulsd	xmm15,xmm15				; x1*x1

	movlpd	xmm7,qword ptr (sin_p1_3-sin_p1_c)[rcx]
	movlpd	xmm8,qword ptr (sin_p1_2-sin_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm7,xmm2				; p3
	mulsd	xmm8,xmm2				; p2
	subsd	xmm12,xmm13				; x_l

sin_real_pm_0_6:
	mulsd	xmm15,qword ptr real_0_5 ; 0.5*x1*x1

	movlpd	xmm9,qword ptr (sin_p1_5-sin_p1_c)[rcx]

	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8
	
	mulsd	xmm9,xmm4				; p5
	mulsd	xmm4,qword ptr (sin_p1_4-sin_p1_c)[rcx] ; p4

	mulsd	xmm15,xmm12				; x_l*0.5*x1*x1

	movlpd	xmm11,qword ptr (sin_p1_7-sin_p1_c)[rcx]
	movlpd	xmm10,qword ptr (sin_p1_9-sin_p1_c)[rcx]

	mulsd	xmm11,xmm2				; p7
	mulsd	xmm2,qword ptr (sin_p1_6-sin_p1_c)[rcx] ; p6

	mulsd	xmm10,xmm0				; p9
	mulsd	xmm0,qword ptr (sin_p1_8-sin_p1_c)[rcx] ; p8

	addsd	xmm11,xmm10				; p9+p7
	addsd	xmm0,xmm2				; p8+p6

	subsd	xmm12,xmm15				; x_l-x_l*0.5*x1*x1

	movlpd	xmm2,qword ptr real_26_bits
	movsd	xmm3,xmm1				; x
	movlpd	xmm6,qword ptr (sin_p1_1l-sin_p1_c)[rcx]
	movlpd	xmm5,qword ptr (sin_p1_1h-sin_p1_c)[rcx]

	addsd	xmm9,xmm11				; p9+p7+p5
	addsd	xmm0,xmm4				; p8+p6+p4

	andpd	xmm2,xmm1				; x_h
	mulsd	xmm6,xmm1				; x*c1l
	movlpd	xmm13,qword ptr (sin_p1_0h-sin_p1_c)[rcx]

	addsd	xmm7,xmm9				; p9+p7+p5+p3
	addsd	xmm0,xmm8				; p8+p6+p4+p2

	subsd	xmm3,xmm2				; x_l
	mulsd	xmm2,xmm5				; x_h*c1h

	mulsd	xmm7,xmm1				; (p9+p7+p5+p3)(*x)

	movsd	xmm14,xmm13
	addsd	xmm13,xmm2				; x_h*c1h+c0h
	
	addsd	xmm0,xmm7				; p9+p8+..+p2

	subsd	xmm14,xmm13				; c0h-(x_h*c1h+c0h)
	mulsd	xmm3,xmm5				; x_l*c1h

;	addsd	xmm0,qword ptr (sin_p1_0l-sin_p1_c)[rcx]
	addsd	xmm0,xmm12
	
	addsd	xmm14,xmm2				; (c0h-(x_h*c1h+c0h))+x_h*c1h
	addsd	xmm3,xmm6				; x_l*c1h+x*c1l
	
	addsd	xmm3,xmm14				; (c0h-(x_h*c1h+c0h))+x_h*c1h+x_l*c1h+x*c1l

	addsd	xmm0,xmm3
	addsd	xmm0,xmm13
	ret

sin_real_3:
	movlpd	xmm1,qword ptr real_pi
	movlpd	xmm13,qword ptr real_pi_l
	subsd	xmm1,xmm0
	jmp		sin_real_m

cos_real_n_4:
	movlpd	xmm1,qword ptr real_m_3_pi_d_2
	movlpd	xmm13,qword ptr real_m_3_pi_d_2_l
	subsd	xmm1,xmm0
	jmp		sin_real_m

sin_real_n_3:
	movlpd	xmm1,qword ptr real_m_pi
	movlpd	xmm13,qword ptr real_m_pi_l
	subsd	xmm1,xmm0
	jmp		sin_real_m

cos_real_2:
	movlpd	xmm1,qword ptr real_pi_d_2
	movlpd	xmm13,qword ptr real_pi_d_2_l
	subsd	xmm1,xmm0

sin_real_m:
	ucomisd	xmm1,qword ptr real_0_43540000008249979402

	movsd	xmm12,xmm1

	jae		sin_real_m_p_0_6
	ucomisd	xmm1,qword ptr real_m_0_43540000008249979402
	jbe		sin_real_m_m_0_6

	addsd	xmm1,xmm13

	movsd	xmm0,xmm1				; x
	mulsd	xmm1,xmm1				; x2

	subsd	xmm12,xmm0

	movlpd	xmm5,qword ptr sin_p_0
	movlpd	xmm6,qword ptr sin_p_1

	movsd	xmm2,xmm0				; x
	mulsd	xmm0,xmm1				; x3

;	ucomisd	xmm1,qword ptr real_0_25 ; x2>=0.25 (|x|>0.5)
	
	movsd	xmm3,xmm1				; x2
	mulsd	xmm1,xmm1				; x4

	addsd	xmm12,xmm13

	movsd	xmm14,xmm3
	mulsd	xmm3,xmm0				; x5

	movlpd	xmm7,qword ptr sin_p_2
	movlpd	xmm8,qword ptr sin_p_3
		
	mulsd	xmm5,xmm0				; p3
	mulsd	xmm0,xmm1				; x7

	mulsd	xmm6,xmm3				; p5
	mulsd	xmm3,xmm1				; x9

	mulsd	xmm7,xmm0				; p7
	mulsd	xmm0,xmm1				; x11
	
	mulsd	xmm8,xmm3				; p9
	mulsd	xmm3,xmm1				; x13

	mulsd	xmm14,xmm12

	mulsd	xmm0,qword ptr sin_p_4	; p11
	mulsd	xmm3,qword ptr sin_p_5	; p13
	
	movsd	xmm1,xmm2				; x

	mulsd	xmm14,qword ptr real_0_5

	addsd	xmm0,xmm3				; p11+p13

	subsd	xmm12,xmm14

	addsd	xmm0,xmm8				; p9+p11+p13

;	jae		sin_real_m_l

	addsd	xmm0,xmm7				; p7+p9+p11+p13
	addsd	xmm0,xmm6				; p5+p7+p9+p11+p13
	addsd	xmm0,xmm5				; p3+p5+p7+p9+p11+p13

	addsd	xmm0,xmm12

	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

	ret

;sin_real_m_l:
;	movlpd	xmm2,qword ptr real_47_bits
;	andpd	xmm2,xmm5				; p3h

;	addsd	xmm0,xmm7				; p7+p9+p11+p13

;	subsd	xmm5,xmm2				; p3l
;	addsd	xmm1,xmm2				; x+p3h

;	addsd	xmm0,xmm6				; p5+p7+p9+p11+p13
;	addsd	xmm0,xmm5				; p3+p5+p7+p9+p11+p13

;	addsd	xmm0,xmm12

;	addsd	xmm0,xmm1				; x+p3+p5+p7+p9+p11+p13

;	ret

sin_real_m_m_0_6:
	addsd	xmm1,xmm13

	movlpd	xmm0,qword ptr real_0_600000000082499762577

	ucomisd	xmm1,qword ptr real_m_0_600000000082499762577
	movsd	xmm15,xmm1				; x1
	addsd	xmm0,xmm1

	lea		rcx,sin_p3_c
	lea		rdx,sin_p4_c

	cmova	rcx,rdx
	jmp		sin_real_m_pm_0_6

sin_real_m_p_0_6:
	addsd	xmm1,xmm13

	movlpd	xmm0,qword ptr real_m_0_600000000082499762577

	ucomisd	xmm1,qword ptr real_0_600000000082499762577
	movsd	xmm15,xmm1				; x1
	addsd	xmm0,xmm1

	lea		rcx,sin_p1_c
	lea		rdx,sin_p2_c

	cmovb	rcx,rdx

sin_real_m_pm_0_6:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2
	subsd	xmm12,xmm15
	mulsd	xmm15,xmm15				; x1*x1

	movlpd	xmm7,qword ptr (sin_p1_3-sin_p1_c)[rcx]
	movlpd	xmm8,qword ptr (sin_p1_2-sin_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm7,xmm2				; p3
	mulsd	xmm8,xmm2				; p2

	addsd	xmm12,xmm13				; x_l
	jmp		sin_real_pm_0_6

	public	cos_real

cos_real:
	ucomisd	xmm0,qword ptr real_pi_d_4
	jbe		cos_real_1				; x<=pi/4 | NAN
	ucomisd	xmm0,qword ptr real_3_pi_d_4
	jbe		cos_real_2
	ucomisd	xmm0,qword ptr real_5_pi_d_4
	jbe		cos_real_3
	ucomisd	xmm0,qword ptr real_7_pi_d_4
	jbe		cos_real_4
	ucomisd	xmm0,qword ptr real_9_pi_d_4
	jbe		cos_real_5

	ucomisd	xmm0,qword ptr real_36825084_pi
	jbe		cos_real_0

	ucomisd	xmm0,qword ptr real_2_p_53
	jae		sin_or_cos_real_too_large	; x>=-2^53

	call	rem_36825084_pi

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

	subsd	xmm13,xmm7
	jmp		cos_real_0_

cos_real_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi
	
	addsd	xmm1,qword ptr real_1_0	; x*4/pi+1
	
	movq	xmm4,qword ptr round_even_c
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1

	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi+1)

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm6,xmm4

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

cos_real_0_:
	ucomisd	xmm1,xmm5
	jne		cos_real_sin

cos_real_cos:
	subsd	xmm0,xmm2
	subsd	xmm0,xmm3

	ucomisd	xmm1,xmm6
	je		cos_real_p
	jmp		cos_real_m

cos_real_sin:
	ucomisd	xmm1,xmm6
	jne		cos_real_p_sin

	movsd	xmm1,xmm3
	subsd	xmm0,xmm2
	subsd	xmm1,xmm0
	jmp		sin_real_m

cos_real_p_sin:
	subsd	xmm0,xmm2
	subsd	xmm0,xmm3
	jmp		sin_real_p

cos_real_n:
	ucomisd	xmm0,qword ptr real_m_3_pi_d_4
	jae		cos_real_n_2
	ucomisd	xmm0,qword ptr real_m_5_pi_d_4
	jae		cos_real_n_3
	ucomisd	xmm0,qword ptr real_m_7_pi_d_4
	jae		cos_real_n_4
	ucomisd	xmm0,qword ptr real_m_9_pi_d_4
	jae		cos_real_n_5

	ucomisd	xmm0,qword ptr real_m_36825084_pi
	jae		cos_real_n_0

	ucomisd	xmm0,qword ptr real_m_2_p_53
	jbe		sin_or_cos_real_too_small_or_nan	; x<=-2^53 | NAN

	call	rem_n_36825084_pi

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

	subsd	xmm13,xmm7
	jmp		cos_real_n_0_

cos_real_n_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi
	
	movq	xmm4,qword ptr m_round_even_c

	subsd	xmm1,qword ptr real_1_0	; x*4/pi-1
	
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1

	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi-1)

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm13,qword ptr real_pi_d_4_52_l

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm6,xmm4

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm13,xmm1

	andpd	xmm5,xmm1
	andpd	xmm6,xmm1

cos_real_n_0_:
	ucomisd	xmm1,xmm5
	je		cos_real_cos

	ucomisd	xmm1,xmm6
	je		cos_real_n_p_sin

	movsd	xmm1,xmm3
	subsd	xmm0,xmm2
	subsd	xmm1,xmm0
	jmp		sin_real_m

cos_real_n_p_sin:
	subsd	xmm0,xmm2
	subsd	xmm0,xmm3
	jmp		sin_real_p

cos_real_1:
	ucomisd	xmm0,qword ptr real_m_pi_d_4
	jb		cos_real_n				; x<-pi/4 | NAN

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm9,qword ptr real_17_bits
	movlpd	xmm5,qword ptr cos_p_0

	movsd	xmm8,xmm1				; x

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	andpd	xmm9,xmm1				; x_17_h
	movlpd	xmm10,qword ptr real_0_5

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movlpd	xmm7,qword ptr cos_p_2

	mulsd	xmm5,xmm4				; p4
	mulsd	xmm4,xmm2				; x10

	movsd	xmm6,xmm2				; x6
	mulsd	xmm2,xmm2				; x12

	mulsd	xmm7,xmm0				; p8
	mulsd	xmm0,xmm6				; x14

	mulsd	xmm6,qword ptr cos_p_1	; p6	
	mulsd	xmm4,qword ptr cos_p_3	; p10
	mulsd	xmm2,qword ptr cos_p_4	; p12
	mulsd	xmm0,qword ptr cos_p_5	; p14

	subsd	xmm8,xmm9				; x_17_l
	mulsd	xmm10,xmm9				; 0.5*x_17_h

	addsd	xmm0,xmm2				; p12+p14
	
	mulsd	xmm10,xmm9				; 0.5*x_17_h*x_17_h
	movlpd	xmm11,qword ptr real_1_0

	addsd	xmm0,xmm4				; p10+p12+p14

	mulsd	xmm8,qword ptr real_0_5	; 0.5*x_17_l
	addsd	xmm9,xmm1				; x+x_17_h

	addsd	xmm0,xmm7				; p8+p10+p12+p14

	mulsd	xmm8,xmm9				; 0.5*x_17_l*(x+x_17_h)

	addsd	xmm0,xmm6				; p6+p8+p10+p12+p14

	ucomisd	xmm10,qword ptr real_2_p_m_18 ; 0.5*x_17_h*x_17_h<2**-18
	jb		cos_real_1_s

	subsd	xmm11,xmm10				; 1.0-0.5*x_17_h*x_17_h

	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	subsd	xmm0,xmm8
	addsd	xmm0,xmm11

	ret

cos_real_1_s:
	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	subsd	xmm0,xmm8
	subsd	xmm0,xmm10
	addsd	xmm0,xmm11

	ret

cos_real_n_5:
	addsd	xmm0,qword ptr real_2_pi
	movlpd	xmm13,qword ptr real_m_2_pi_l
	jmp		cos_real_p

cos_real_5:
	subsd	xmm0,qword ptr real_2_pi
	movlpd	xmm13,qword ptr real_2_pi_l
	jmp		cos_real_p

sin_real_n_4:
	addsd	xmm0,qword ptr real_3_pi_d_2
	movlpd	xmm13,qword ptr real_m_3_pi_d_2_l
	jmp		cos_real_p

sin_real_2:
	subsd	xmm0,qword ptr real_pi_d_2
	movlpd	xmm13,qword ptr real_pi_d_2_l

cos_real_p:
	movsd	xmm12,xmm0
	subsd	xmm0,xmm13

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	subsd	xmm12,xmm1

	movlpd	xmm9,qword ptr real_17_bits
	movlpd	xmm5,qword ptr cos_p_0

	movsd	xmm8,xmm1				; x

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	subsd	xmm12,xmm13

	andpd	xmm9,xmm1				; x_17_h
	movlpd	xmm10,qword ptr real_0_5

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movlpd	xmm7,qword ptr cos_p_2

	mulsd	xmm12,xmm8

	mulsd	xmm5,xmm4				; p4
	mulsd	xmm4,xmm2				; x10

	movsd	xmm6,xmm2				; x6
	mulsd	xmm2,xmm2				; x12

	mulsd	xmm7,xmm0				; p8
	mulsd	xmm0,xmm6				; x14

	mulsd	xmm6,qword ptr cos_p_1	; p6	
	mulsd	xmm4,qword ptr cos_p_3	; p10
	mulsd	xmm2,qword ptr cos_p_4	; p12
	mulsd	xmm0,qword ptr cos_p_5	; p14

	subsd	xmm8,xmm9				; x_17_l
	mulsd	xmm10,xmm9				; 0.5*x_17_h

	addsd	xmm0,xmm2				; p12+p14
	
	mulsd	xmm10,xmm9				; 0.5*x_17_h*x_17_h
	movlpd	xmm11,qword ptr real_1_0

	addsd	xmm0,xmm4				; p10+p12+p14

	mulsd	xmm8,qword ptr real_0_5	; 0.5*x_17_l
	addsd	xmm9,xmm1				; x+x_17_h

	addsd	xmm0,xmm7				; p8+p10+p12+p14

	mulsd	xmm8,xmm9				; 0.5*x_17_l*(x+x_17_h)

	addsd	xmm0,xmm6				; p6+p8+p10+p12+p14

	ucomisd	xmm10,qword ptr real_2_p_m_18 ; 0.5*x_17_h*x_17_h<2**-18
	jb		cos_real__s

	subsd	xmm11,xmm10				; 1.0-0.5*x_17_h*x_17_h

	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	addsd	xmm8,xmm12

	subsd	xmm0,xmm8
	addsd	xmm0,xmm11

	ret

cos_real__s:
	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	addsd	xmm8,xmm12

	subsd	xmm0,xmm8
	subsd	xmm0,xmm10
	addsd	xmm0,xmm11

	ret

sin_real_4:
	subsd	xmm0,qword ptr real_3_pi_d_2
	movlpd	xmm13,qword ptr real_3_pi_d_2_l
	jmp		cos_real_m

cos_real_n_3:
	addsd	xmm0,qword ptr real_pi
	movlpd	xmm13,qword ptr real_m_pi_l
	jmp		cos_real_m

sin_real_n_2:
	addsd	xmm0,qword ptr real_pi_d_2
	movlpd	xmm13,qword ptr real_m_pi_d_2_l
	jmp		cos_real_m

cos_real_3:
	subsd	xmm0,qword ptr real_pi
	movlpd	xmm13,qword ptr real_pi_l

cos_real_m:
	movsd	xmm12,xmm0
	subsd	xmm0,xmm13

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	subsd	xmm12,xmm1

	movlpd	xmm9,qword ptr real_17_bits
	movlpd	xmm5,qword ptr cos_p_0

	movsd	xmm8,xmm1				; x

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	subsd	xmm12,xmm13

	andpd	xmm9,xmm1				; x_17_h
	movlpd	xmm10,qword ptr real_0_5

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movlpd	xmm7,qword ptr cos_p_2

	mulsd	xmm12,xmm8

	mulsd	xmm5,xmm4				; p4
	mulsd	xmm4,xmm2				; x10

	movsd	xmm6,xmm2				; x6
	mulsd	xmm2,xmm2				; x12

	mulsd	xmm7,xmm0				; p8
	mulsd	xmm0,xmm6				; x14

	mulsd	xmm6,qword ptr cos_p_1	; p6	
	mulsd	xmm4,qword ptr cos_p_3	; p10
	mulsd	xmm2,qword ptr cos_p_4	; p12
	mulsd	xmm0,qword ptr cos_p_5	; p14

	subsd	xmm8,xmm9				; x_17_l
	mulsd	xmm10,xmm9				; 0.5*x_17_h

	addsd	xmm0,xmm2				; p12+p14
	
	mulsd	xmm10,xmm9				; 0.5*x_17_h*x_17_h
	movlpd	xmm11,qword ptr real_m_1_0

	addsd	xmm0,xmm4				; p10+p12+p14

	mulsd	xmm8,qword ptr real_0_5	; 0.5*x_17_l
	addsd	xmm9,xmm1				; x+x_17_h

	addsd	xmm0,xmm7				; p8+p10+p12+p14

	mulsd	xmm8,xmm9				; 0.5*x_17_l*(x+x_17_h)

	addsd	xmm0,xmm6				; p6+p8+p10+p12+p14
	
	ucomisd	xmm10,qword ptr real_2_p_m_18 ; 0.5*x_17_h*x_17_h<2**-18
	jb		cos_real_m_s

	addsd	xmm11,xmm10				; -1.0+0.5*x_17_h*x_17_h

	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	addsd	xmm8,xmm12

	subsd	xmm8,xmm0
	movsd	xmm0,xmm11
	addsd	xmm0,xmm8
	ret

cos_real_m_s:
	addsd	xmm0,xmm5				; p4+p6+p8+p10+p12+p14

	addsd	xmm8,xmm12

	subsd	xmm8,xmm0

	movsd	xmm0,xmm11
	addsd	xmm8,xmm10

	addsd	xmm0,xmm8
	ret

sin_or_cos_real_too_large:
sin_or_cos_real_too_small_or_nan:
	subsd	xmm0,xmm0
	ret

_T000	ends

_T001	segment para 'CODE'

	public	tan_real

tan_real:
	ucomisd	xmm0,qword ptr real_m_0_338
	jb		tan_real_n				; x<-0.338 | NAN
	ucomisd	xmm0,qword ptr real_0_89
	jbe		tan_real_1
	ucomisd	xmm0,qword ptr real_pi_m_0_699
	jbe		tan_real_2
	ucomisd	xmm0,qword ptr real_pi_p_0_89
	jbe		tan_real_3
	ucomisd	xmm0,qword ptr real_2pi_m_0_699
	jbe		tan_real_4
	ucomisd	xmm0,qword ptr real_2pi_p_0_89
	jbe		tan_real_5

	ucomisd	xmm0,qword ptr real_36825084_pi
	jbe		tan_real_0

	ucomisd	xmm0,qword ptr real_2_p_53
	jae		tan_real_too_large	; x>=-2^53

	call	rem_36825084_pi

tan_real_pn_l:
	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm12,qword ptr real_pi_d_4_52_l

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm12,xmm1

	subsd	xmm12,xmm7
	jmp		tan_real_

tan_real_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi
	
	addsd	xmm1,qword ptr real_1_0	; x*4/pi+1
	
	movq	xmm4,qword ptr round_even_c
tan_real_pn_0:
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1
	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi+1)

	movlpd	xmm2,qword ptr real_pi_d_4_26
	movlpd	xmm3,qword ptr real_pi_d_4_26_26
	movlpd	xmm12,qword ptr real_pi_d_4_52_l

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4

	mulsd	xmm2,xmm1
	mulsd	xmm3,xmm1
	mulsd	xmm12,xmm1

tan_real_:
	andpd	xmm5,xmm1
	ucomisd	xmm1,xmm5
	jne		tan_real_0_2

	subsd	xmm0,xmm2
	subsd	xmm0,xmm3
	
	ucomisd	xmm0,qword ptr real_0_338
	ja		tan_real_0_1p
	ucomisd	xmm0,qword ptr real_m_0_338
	jae		tan_real_3_

	ucomisd	xmm0,qword ptr real_m_0_542
	ja		tan_real_0_5_n
	ucomisd	xmm0,qword ptr real_m_0_699
	ja		tan_real_s_0_5_n
	jmp		tan_real_1_0_3_n

tan_real_0_1p:
	ucomisd	xmm0,qword ptr real_0_542
	jb		tan_real_0_5_p
	ucomisd	xmm0,qword ptr real_0_699
	jb		tan_real_s_0_5_p
	jmp		tan_real_1_0_3

tan_real_0_2:
	subsd	xmm2,xmm0
	movsd	xmm1,xmm3
	addsd	xmm1,xmm2

	ucomisd	xmm1,qword ptr real_0_5_pi_m_1_18
	ja		tan_real_0_2p
	ucomisd	xmm1,qword ptr real_1_18_m_0_5_pi
	jae		tan_real_2_

	ucomisd	xmm1,qword ptr real_1_04_m_0_5_pi
	ja		tan_real_2_0_n
	ucomisd	xmm1,qword ptr real_0_89_m_0_5_pi
	ja		tan_real_s_2_n
	jmp		tan_real_1_0_n

tan_real_0_2p:
	ucomisd	xmm1,qword ptr real_0_5_pi_m_1_04
	jb		tan_real_2_0_p
	ucomisd	xmm1,qword ptr real_0_5_pi_m_0_89
	jb		tan_real_s_2_p
	jmp		tan_real_1_0_2_p

tan_real_n:
	ucomisd	xmm0,qword ptr real_m_0_89
	jae		tan_real_n_1
	ucomisd	xmm0,qword ptr real_n_pi_m_0_699
	jae		tan_real_n_2
	ucomisd	xmm0,qword ptr real_n_pi_p_0_89
	jae		tan_real_n_3
	ucomisd	xmm0,qword ptr real_n_2pi_m_0_699
	jae		tan_real_n_4
	ucomisd	xmm0,qword ptr real_n_2pi_p_0_89
	jae		tan_real_n_5

	ucomisd	xmm0,qword ptr real_m_36825084_pi
	jae		tan_real_n_0

	ucomisd	xmm0,qword ptr real_m_2_p_53
	jbe		tan_real_too_small_or_nan	; x<=-2^53 | NAN

	call	rem_n_36825084_pi
	jmp		tan_real_pn_l

tan_real_n_0:
	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi
	
	subsd	xmm1,qword ptr real_1_0	; x*4/pi-1
	
	movq	xmm4,qword ptr m_round_even_c
	jmp		tan_real_pn_0

tan_real_1:
	ucomisd	xmm0,qword ptr real_0_699
	ja		tan_real_1_2
	ucomisd	xmm0,qword ptr real_0_338
	ja		tan_real_0_5

tan_real_1_0:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm6,qword ptr tan_q_1
	movlpd	xmm5,qword ptr tan_q_2

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm7,qword ptr tan_p_1
	mulsd	xmm6,xmm2				; q2

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	mulsd	xmm5,xmm4				; q4
	mulsd	xmm2,qword ptr tan_q_3	; q6
	
	mulsd	xmm4,qword ptr tan_p_2	; p4

	addsd	xmm0,xmm2				; x8+q6

	mulsd	xmm7,xmm3				; p2

	addsd	xmm0,xmm5				; x8+q6+q4

	addsd	xmm4,xmm7				; p4+p2

	addsd	xmm0,xmm6				; x8+q6+q4+q2

	addsd	xmm4,qword ptr tan_p_0	; p4+p2+p0

	addsd	xmm0,qword ptr tan_q_0	; x8+q6+q4+q2+q0

	divsd	xmm4,xmm0				; p/q

	mulsd	xmm3,xmm1				; x3
	movsd	xmm0,xmm1				; x

	mulsd	xmm3,xmm4
	addsd	xmm0,xmm3

	ret

tan_real_m_0_5:
	ucomisd	xmm0,qword ptr real_m_0_542
	jb		tan_real_n_s_0_5

	movlpd	xmm1,qword ptr atan_0_5_53
	movlpd	xmm10,qword ptr real_49_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	lea		rdx,tan_n_0_5_t
	addsd	xmm1,qword ptr atan_0_5_53_l ; y=x+atan 0.5
	jmp		tan_real_0_5_a_s_0_5_a_s_2

tan_real_n_s_0_5:
	movlpd	xmm1,qword ptr atan_sqrt_0_5
	movlpd	xmm10,qword ptr real_51_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h
	
	lea		rdx,tan_n_s_0_5_t
	addsd	xmm1,qword ptr atan_sqrt_0_5_l ; y=x+atan sqrt 0.5
	jmp		tan_real_0_5_a_s_0_5_a_s_2

tan_real_0_5:
	ucomisd	xmm0,qword ptr real_0_542
	ja		tan_real_s_0_5

	movlpd	xmm1,qword ptr m_atan_0_5_53
	movlpd	xmm10,qword ptr real_49_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	lea		rdx,tan_0_5_t
	subsd	xmm1,qword ptr atan_0_5_53_l ; y=x-atan 0.5
	jmp		tan_real_0_5_a_s_0_5_a_s_2

tan_real_s_0_5:
	movlpd	xmm1,qword ptr m_atan_sqrt_0_5
	movlpd	xmm10,qword ptr real_51_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h
	
	lea		rdx,tan_s_0_5_t
	subsd	xmm1,qword ptr atan_sqrt_0_5_l ; y=x-atan sqrt 0.5

tan_real_0_5_a_s_0_5_a_s_2:
	subsd	xmm0,xmm10				; x_l

	movsd	xmm2,xmm1				; y
	mulsd	xmm1,xmm1				; y2

	mulsd	xmm10,qword ptr [rdx]	; 1.25|1.5|3*x_h

	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm1				; y2
	mulsd	xmm1,xmm1				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm1				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm1				; y4
	mulsd	xmm1,xmm1				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm1,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm1,xmm6				; y8+q6+q4

	mulsd	xmm0,qword ptr [rdx]	; 1.25|1.5|3*x_l

	movlpd	xmm6,qword ptr 8[rdx]	; 0.5|sqrt 0.5|sqrt 2

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm1,xmm7				; y8+q6+q4+q2

	mulsd	xmm6,xmm2				; 0.5|sqrt 0.5|sqrt 2*y

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm1,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm1				; p+q
	
	mulsd	xmm4,xmm6				; 0.5|sqrt 0.5|sqrt 2*y*(p+q)

	mulsd	xmm2,qword ptr [rdx]	; 1.25|1.5|3*y

	addsd	xmm3,xmm4				; p+y*(p+q)
	subsd	xmm1,xmm4				; q-y*(p+q)

	divsd	xmm3,xmm1				; (p-y*(p+q))/(q+y*(p+q))
	
	addsd	xmm0,qword ptr 16[rdx]	; (0.5-1.25atan0.5)_49_l | (sqrt0.5-1.5atan(sqrt0.5))_l | (sqrt2-3atan(sqrt2))_l

	mulsd	xmm2,xmm3				; 1.25|1.5|3 * y * (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm10,qword ptr 24[rdx]	; (0.5-1.25atan0.5)_49 | sqrt0.5-1.5atan(sqrt0.5) | sqrt2-3atan(sqrt2)

	addsd	xmm0,xmm2

	addsd	xmm0,xmm10				; 0.5|sqrt 0.5|sqrt 2+1.25|1.5|3y+1.25|1.5|3y * ..

	ret

tan_real_n_1:
	ucomisd	xmm0,qword ptr real_m_0_699
	ja		tan_real_m_0_5

tan_real_n_1_2:
	movlpd	xmm1,qword ptr real_pi_d_4

	addsd	xmm1,xmm0
	addsd	xmm0,xmm0				; 2x

	addsd	xmm1,qword ptr real_pi_d_4_l ; y=pi/4+x

	addsd	xmm0,qword ptr real_pi_d_2_m_1_0_52 ; 1+2x-pi/2=1-2y
	movlpd	xmm10,qword ptr real_m_pi_d_2_m_1_0_52_l
	movlpd	xmm11,qword ptr real_m_2_0
	jmp		tan_real_1_2_

tan_real_1_2:
	movlpd	xmm1,qword ptr real_pi_d_4

	subsd	xmm1,xmm0
	addsd	xmm0,xmm0				; 2x

	addsd	xmm1,qword ptr real_pi_d_4_l ; y=pi/4-x
	subsd	xmm0,qword ptr real_pi_d_2_m_1_0_52 ; 1+2x-pi/2=1-2y
	movlpd	xmm10,qword ptr real_pi_d_2_m_1_0_52_l
	movlpd	xmm11,qword ptr real_2_0

tan_real_1_2_:
	movsd	xmm2,xmm1				; y
	mulsd	xmm1,xmm1				; y2

	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm1				; y2
	mulsd	xmm1,xmm1				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm1				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm1				; y4
	mulsd	xmm1,xmm1				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm1,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm1,xmm6				; y8+q6+q4

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm1,xmm7				; y8+q6+q4+q2

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm1,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm1				; p+q

	mulsd	xmm4,xmm2				; y*(p+q)
	mulsd	xmm2,xmm11				; 2y

	subsd	xmm3,xmm4				; p-y*(p+q)
	addsd	xmm1,xmm4				; q+y*(p+q)

	divsd	xmm3,xmm1				; (p-y*(p+q))/(q+y*(p+q))
	
	mulsd	xmm2,xmm3				; 2y * (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm2,xmm10
	
	subsd	xmm0,xmm2				; 1-2y-2y * ..

	ret

tan_real_n_4:
	ucomisd	xmm0,qword ptr real_n_pi_p_1_18

	movlpd	xmm1,qword ptr real_m_3_pi_d_2
	movlpd	xmm12,qword ptr real_m_3_pi_d_2_l

	ja		tan_real_n_2_0_4_n

	ucomisd	xmm0,qword ptr real_n_2pi_m_0_89
	jb		tan_real_n_1_0_2
	ucomisd	xmm0,qword ptr real_n_2pi_m_1_18
	jb		tan_real_n_2_0_4_p
	jmp		tan_real_24

tan_real_4:
	ucomisd	xmm0,qword ptr real_pi_p_1_18

	movlpd	xmm1,qword ptr real_3_pi_d_2
	movlpd	xmm12,qword ptr real_3_pi_d_2_l

	jb		tan_real_2_0_2_p

	ucomisd	xmm0,qword ptr real_2pi_m_0_89
	ja		tan_real_1_0_2
	ucomisd	xmm0,qword ptr real_2pi_m_1_18
	ja		tan_real_2_0_4_n
	jmp		tan_real_24

tan_real_n_2:
	ucomisd	xmm0,qword ptr real_m_1_18
	ja		tan_real_n_s_2

	movlpd	xmm1,qword ptr real_m_pi_d_2
	movlpd	xmm12,qword ptr real_m_pi_d_2_l

	ucomisd	xmm0,qword ptr real_n_pi_m_0_89
	jb		tan_real_n_1_0_2
	ucomisd	xmm0,qword ptr real_n_pi_m_1_18
	jb		tan_real_n_2_0_2_n

	jmp		tan_real_24

tan_real_2:
	ucomisd	xmm0,qword ptr real_1_18
	jb		tan_real_s_2

	movlpd	xmm1,qword ptr real_pi_d_2
	movlpd	xmm12,qword ptr real_pi_d_2_l

	ucomisd	xmm0,qword ptr real_pi_m_0_89
	ja		tan_real_1_0_2
	ucomisd	xmm0,qword ptr real_pi_m_1_18
	ja		tan_real_2_0_2_n

tan_real_24:
	subsd	xmm1,xmm0				; y_1

tan_real_2_:
	movlpd	xmm2,qword ptr real_18_bits
	movsd	xmm3,xmm12

	andpd	xmm2,xmm1				; y_1_h
	addsd	xmm3,xmm1				; y

	movsd	xmm6,xmm1				; y_1
	subsd	xmm1,xmm2				; y_1-y_1_h

	movsd	xmm0,xmm2				; y_1_h
	addsd	xmm2,xmm3				; y+y_1_h
	addsd	xmm1,xmm12				; y_1_l

	mulsd	xmm0,xmm0				; y_1_h^2
	mulsd	xmm1,xmm2				; (y+y_1_h)*y_1_l

	movsd	xmm13,xmm0				; y_1_h^2
	addsd	xmm0,xmm1				; y^2

	movsd	xmm14,xmm1				; (y_1^2)_l
	movsd	xmm1,xmm3				; y
	subsd	xmm3,xmm6				; y-y_1

	movlpd	xmm5,qword ptr tan2_q_1
	movlpd	xmm9,qword ptr tan2_p_0

	subsd	xmm12,xmm3				; y_s

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm5,xmm2				; q2
	mulsd	xmm9,xmm2				; p2

	movlpd	xmm6,qword ptr tan2_q_2
	movlpd	xmm11,qword ptr tan2_p_1

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm1				; x3

	movsd	xmm8,xmm1				; x

	movlpd	xmm10,qword ptr real_0_5

	mulsd	xmm6,xmm0				; q4
	mulsd	xmm11,xmm0				; p4

	addsd	xmm5,xmm6				; q4+q2

	movlpd	xmm7,qword ptr real_1_0

	mulsd	xmm10,xmm3				; 0.5*x2
	mulsd	xmm3,xmm0				; x6	

	addsd	xmm5,qword ptr tan2_q_0	; q4+q2+q0

	mulsd	xmm0,xmm0				; x8
	mulsd	xmm3,qword ptr tan2_p_2	; p6

	mulsd	xmm5,xmm2				; (q4+q2+q0)*x3

	mulsd	xmm0,qword ptr tan2_p_3	; p8

	movsd	xmm2,xmm5				; (q4+q2+q0)*x3
	addsd	xmm5,xmm8				; (q4+q2+q0)*x3+x

	addsd	xmm0,xmm3				; p8+p6

	divsd	xmm7,xmm5				; 1/(q4+q2+q0)*x3+x

	movlpd	xmm4,qword ptr real_25_bits

	addsd	xmm0,xmm11				; p8+p6+p4
	
	andpd	xmm5,xmm4				; q_h
	
	addsd	xmm0,xmm9				; p8+p6+p4+p2

	movlpd	xmm9,qword ptr real_18_bits

;	ucomisd	xmm8,qword ptr real_0_4
	ucomisd	xmm10,qword ptr real_2_p_m_31

	subsd	xmm8,xmm5				; x-q_h	

	addsd	xmm8,xmm2				; q_l=q-q_h
	movlpd	xmm6,qword ptr real_1_0

	jb		tan_real_2_s			; x<1.25*2**-16

tan_real_2_1:
	movsd	xmm3,xmm0				; p

	mulsd	xmm14,qword ptr real_0_5 ; (0.5*x2)_l
	mulsd	xmm13,qword ptr real_0_5 ; (0.5*x2)_h

	subsd	xmm3,xmm10				; p-0.5*x2
	addsd	xmm8,xmm12				; q_l+y_s

	subsd	xmm0,xmm14				; p-(0.5*x2)_l

	andpd	xmm9,xmm7				; (1/q)_h

	mulsd	xmm5,xmm9				; q_h*(1/q)_h
	mulsd	xmm8,xmm9				; q_l*(1/q)_h

	mulsd	xmm13,xmm9				; (0.5*x2)_h*(1/q)_h
	mulsd	xmm0,xmm9				; (p-(0.5*x2)_l)*(1/q)_h
	movlpd	xmm1,qword ptr real_21_bits

	subsd	xmm6,xmm5				; 1-q_h*(1/q)_h

	andpd	xmm1,xmm0				; ((p-(0.5*x2)_l)*(1/q)_h)_h
	
	subsd	xmm6,xmm8				; 1-(q_h+q_l)*(1/q)_h

	subsd	xmm0,xmm1				; ((p-(0.5*x2)_l)*(1/q)_h)_l
	subsd	xmm1,xmm13				; ((p-(0.5*x2)_l)*(1/q)_h)_h-(0.5*x2)_h*(1/q)_h
	movlpd	xmm2,qword ptr real_21_bits

	mulsd	xmm7,xmm6				; (1/q)_l

	andpd	xmm2,xmm1				; (((p-(0.5*x2)_l)*(1/q)_h)_h-(0.5*x2)_h*(1/q)_h)_h

	mulsd	xmm3,xmm7				; (p-0.5x2)*(1/q)_l

	subsd	xmm1,xmm2				; (((p-(0.5*x2)_l)*(1/q)_h)_h-(0.5*x2)_h*(1/q)_l
	addsd	xmm2,xmm9				; (((p-(0.5*x2)_l)*(1/q)_h)_h-(0.5*x2)_h*(1/q)_h)_h+(1/q)_h

	addsd	xmm0,xmm3				; ((p-(0.5*x2)_l)*(1/q)_h)_l+(p-0.5x2)*(1/q)_l

	addsd	xmm0,xmm7				; ((p-(0.5*x2)_l)*(1/q)_h)_l+(p-0.5x2)*(1/q)_l+(1/q)_l

	addsd	xmm0,xmm1				; ((p-(0.5*x2)_l)*(1/q)_h)+(p-0.5x2)*(1/q)_l+(1/q)_l
									; -(0.5*x2)_h*(1/q)_l
	addsd	xmm0,xmm2

	ret	

tan_real_2_s:
	subsd	xmm0,xmm10				; p-0.5*x2
	addsd	xmm8,xmm12				; q_l+y_s

	andpd	xmm9,xmm7				; (1/q)_h

	mulsd	xmm0,xmm7				; (p-0.5*x2)*(1/q)

	mulsd	xmm5,xmm9				; q_h*(1/q)_h
	mulsd	xmm8,xmm9				; q_l*(1/q)_h
	
	subsd	xmm6,xmm5				; 1-q_h*(1/q)_h
	
	subsd	xmm6,xmm8				; 1-(q_h+q_l)*(1/q)_h

	mulsd	xmm6,xmm7				; (1/q)_l

	addsd	xmm0,xmm6				; (p/q)_l+(1/q)_l
	
	addsd	xmm0,xmm9				; p/q+1/q

	ret

; x<0.4
;	subsd	xmm0,xmm10				; p-0.5*x2
;	addsd	xmm8,xmm12				; q_l+y_s

;	andpd	xmm9,xmm7				; (1/q)_h

;	mulsd	xmm0,xmm7				; (p-0.5*x2)*(1/q)

;	movlpd	xmm4,qword ptr real_21_bits

;	mulsd	xmm5,xmm9				; q_h*(1/q)_h
;	mulsd	xmm8,xmm9				; q_l*(1/q)_h

;	andpd	xmm4,xmm0				; (p/q)_h
	
;	subsd	xmm6,xmm5				; 1-q_h*(1/q)_h

;	subsd	xmm0,xmm4				; (p/q)_l
;	addsd	xmm4,xmm9				; (p/q)_h+(1/q)_h
	
;	subsd	xmm6,xmm8				; 1-(q_h+q_l)*(1/q)_h

;	mulsd	xmm6,xmm7				; (1/q)_l

;	addsd	xmm0,xmm6				; (p/q)_l+(1/q)_l	
	
;	addsd	xmm0,xmm4				; p/q+1/q

;	ret

tan_real_n_s_2:
	ucomisd	xmm0,qword ptr real_m_1_04
	jb		tan_real_n_2_0

	movlpd	xmm1,qword ptr atan_sqrt_2
	movlpd	xmm10,qword ptr real_51_bits

	lea		rdx,tan_n_s_2_t

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	addsd	xmm1,qword ptr atan_sqrt_2_l ; y=x+atan sqrt 2
	jmp		tan_real_0_5_a_s_0_5_a_s_2

tan_real_s_2:
	ucomisd	xmm0,qword ptr real_1_04
	ja		tan_real_2_0

	movlpd	xmm1,qword ptr m_atan_sqrt_2
	movlpd	xmm10,qword ptr real_51_bits

	lea		rdx,tan_s_2_t

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	subsd	xmm1,qword ptr atan_sqrt_2_l ; y=x-atan sqrt 2
	jmp		tan_real_0_5_a_s_0_5_a_s_2

tan_real_n_2_0:
	movlpd	xmm1,qword ptr atan_2_53
	movlpd	xmm10,qword ptr real_49_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	addsd	xmm1,qword ptr atan_2_53_l ; y=x+atan 2
	subsd	xmm0,xmm10				; x_l

	movlpd	xmm11,qword ptr real_5_atan_2_m_2_53_l
	movlpd	xmm12,qword ptr real_5_atan_2_m_2_53
	movlpd	xmm13,qword ptr real_m_2_0
	jmp		tan_real_2_0_

tan_real_2_0:
	movlpd	xmm1,qword ptr m_atan_2_53
	movlpd	xmm10,qword ptr real_49_bits

	addsd	xmm1,xmm0
	andpd	xmm10,xmm0				; x_h

	subsd	xmm1,qword ptr atan_2_53_l ; y=x-atan 2
	subsd	xmm0,xmm10				; x_l

	movlpd	xmm11,qword ptr real_n_2_m_5_atan_2_53_l
	movlpd	xmm12,qword ptr real_n_2_m_5_atan_2_53
	movlpd	xmm13,qword ptr real_2_0

tan_real_2_0_:
	movsd	xmm2,xmm1				; y
	mulsd	xmm1,xmm1				; y2

	mulsd	xmm10,qword ptr real_5_0 ; 5*x_h

	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm1				; y2
	mulsd	xmm1,xmm1				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm1				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm1				; y4
	mulsd	xmm1,xmm1				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm1,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm1,xmm6				; y8+q6+q4

	mulsd	xmm0,qword ptr real_5_0	; 5*x_l

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm1,xmm7				; y8+q6+q4+q2

	mulsd	xmm13,xmm2				; 2*y

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm1,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm1				; p+q
	
	mulsd	xmm4,xmm13				; 2*y*(p+q)

;	mulsd	xmm2,qword ptr real_5_0	; 5*y

	addsd	xmm3,xmm4				; p+y*(p+q)
	subsd	xmm1,xmm4				; q-y*(p+q)

	divsd	xmm3,xmm1				; (p-y*(p+q))/(q+y*(p+q))
	
	addsd	xmm0,xmm11

	mulsd	xmm2,xmm3				; y * (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm10,xmm12				; 2+5*x_h-5*atan 2=2-5*y

	mulsd	xmm2,qword ptr real_5_0	; 5*y*..

	addsd	xmm0,xmm2

	addsd	xmm0,xmm10				; 2+5*y+5*y * ..

	ret

tan_real_n_2_0_4_p:
	ucomisd	xmm0,qword ptr real_n_2pi_m_1_04
	subsd	xmm1,xmm0
	jb		tan_real_s_2_p
	jmp		tan_real_2_0_p

tan_real_n_2_0_4_n:
	ucomisd	xmm0,qword ptr real_n_pi_p_1_04
	subsd	xmm1,xmm0
	ja		tan_real_s_2_n
	jmp		tan_real_2_0_n

tan_real_n_2_0_2_n:
	ucomisd	xmm0,qword ptr real_n_pi_m_1_04
	subsd	xmm1,xmm0
	jb		tan_real_s_2_p
	jmp		tan_real_2_0_p

tan_real_2_0_2_p:
	ucomisd	xmm0,qword ptr real_pi_p_1_04
	subsd	xmm1,xmm0
	jb		tan_real_s_2_p

tan_real_2_0_p:
	movlpd	xmm0,qword ptr real_h_pi_m_atan_2_52
	movlpd	xmm2,qword ptr real_h_pi_m_atan_2_52_l
	movlpd	xmm10,qword ptr real_48_bits

	subsd	xmm0,xmm1				; (0.5pi-atan 2)_h-x_h
	subsd	xmm2,xmm12				; (0.5pi-atan 2)_l-x_l
	andpd	xmm10,xmm1				; x_h

	movlpd	xmm11,qword ptr real_m_5_0
	addsd	xmm2,xmm0				; y=0.5pi-atan 2-x
	subsd	xmm1,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; -5x_h

	movsd	xmm0,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	addsd	xmm1,xmm12				; x_h_l+x_l
	addsd	xmm10,qword ptr real_2_p_2_5_pi_m_5_atan_2_53 ; -5x+(2+2.5pi-5atan 2)=2+5y

	movlpd	xmm12,qword ptr real_2_p_2_5_pi_m_5_atan_2_53_l
	movlpd	xmm13,qword ptr real_5_0
	jmp		tan_real_2_0_pn

tan_real_2_0_4_n:
	ucomisd	xmm0,qword ptr real_2pi_m_1_04
	subsd	xmm1,xmm0
	ja		tan_real_s_2_n
	jmp		tan_real_2_0_n

tan_real_2_0_2_n:
	ucomisd	xmm0,qword ptr real_pi_m_1_04
	subsd	xmm1,xmm0
	ja		tan_real_s_2_n

tan_real_2_0_n:
	movlpd	xmm0,qword ptr real_h_pi_m_atan_2_52
	movlpd	xmm2,qword ptr real_h_pi_m_atan_2_52_l
	movlpd	xmm10,qword ptr real_48_bits

	addsd	xmm0,xmm1				; (0.5pi-atan 2)_h+x_h
	addsd	xmm2,xmm12				; (0.5pi-atan 2)_l+x_l
	andpd	xmm10,xmm1				; x_h

	movlpd	xmm11,qword ptr real_m_5_0
	addsd	xmm2,xmm0				; y=0.5pi-atan 2+x
	subsd	xmm1,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; -5x_h
	
	movsd	xmm0,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	addsd	xmm1,xmm12				; x_h_l+x_l
	subsd	xmm10,qword ptr real_2_p_2_5_pi_m_5_atan_2_53 ; -5x-(2+2.5pi-5atan 2)=-2-5y

	movlpd	xmm12,qword ptr real_5_atan_2_m_2_m_2_5_pi_53_l
	movlpd	xmm13,qword ptr real_m_5_0

tan_real_2_0_pn:
	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm2				; y2
	mulsd	xmm2,xmm2				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm2				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm2				; y4
	mulsd	xmm2,xmm2				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm2,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm2,xmm6				; y8+q6+q4

	movlpd	xmm6,qword ptr real_2_0
	mulsd	xmm1,xmm11				; -5x_l

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm2,xmm7				; y8+q6+q4+q2

	mulsd	xmm6,xmm0				; 2*y

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm2,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm2				; p+q
	
	mulsd	xmm4,xmm6				; 2*y*(p+q)

	addsd	xmm3,xmm4				; p+y*(p+q)
	subsd	xmm2,xmm4				; q-y*(p+q)

	divsd	xmm3,xmm2				; (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm1,xmm12
		
	mulsd	xmm0,xmm3				; y * (p-y*(p+q))/(q+y*(p+q))

	mulsd	xmm0,xmm13				; -5*y*..

	addsd	xmm0,xmm1

	addsd	xmm0,xmm10				; -2-5*y-5*y * ..

	ret

tan_real_s_2_p:
	movlpd	xmm0,qword ptr real_h_pi_m_atan_s_2_53
	movlpd	xmm2,qword ptr real_h_pi_m_atan_s_2_53_l
	movlpd	xmm10,qword ptr real_49_bits

	subsd	xmm0,xmm1				; (0.5pi-atan sqrt 2)_h-x_h
	subsd	xmm2,xmm12				; (0.5pi-atan sqrt 2)_l-x_l
	andpd	xmm10,xmm1				; x_h

	movlpd	xmm11,qword ptr real_m_3_0
	addsd	xmm2,xmm0				; y=0.5pi-atan 2+x
	subsd	xmm1,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; -3x_h
	
	movsd	xmm0,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	addsd	xmm1,xmm12				; x_h_l+x_l
	addsd	xmm10,qword ptr real_sqrt_2_p_1_5_pi_m_3_atan_sqrt_2_53 ; -3x+(2+2.5pi-5atan 2)=sqrt 2+3y

	movlpd	xmm12,qword ptr real_sqrt_2_p_1_5_pi_m_3_atan_sqrt_2_53_l
	movlpd	xmm13,qword ptr real_3_0
	jmp		tan_real_s_2_pn

tan_real_s_2_n:
	movlpd	xmm0,qword ptr real_h_pi_m_atan_s_2_53
	movlpd	xmm2,qword ptr real_h_pi_m_atan_s_2_53_l
	movlpd	xmm10,qword ptr real_49_bits

	addsd	xmm0,xmm1				; (0.5pi-atan sqrt 2)_h+x
	addsd	xmm2,xmm12				; (0.5pi-atan sqrt 2)_l+x_l
	andpd	xmm10,xmm1				; x_h

	movlpd	xmm11,qword ptr real_m_3_0
	addsd	xmm2,xmm0				; y=0.5pi-atan 2+x
	subsd	xmm1,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; -3x_h
	
	movsd	xmm0,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	addsd	xmm1,xmm12				; x_h_l+x_l
	subsd	xmm10,qword ptr real_sqrt_2_p_1_5_pi_m_3_atan_sqrt_2_53 ; -3x-(2+2.5pi-5atan 2)=-sqrt 2-3y

	movlpd	xmm12,qword ptr real_3_atan_sqrt_2_m_sqrt_2_m_1_5_pi_m_53_l
	movlpd	xmm13,qword ptr real_m_3_0

tan_real_s_2_pn:
	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm2				; y2
	mulsd	xmm2,xmm2				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm2				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm2				; y4
	mulsd	xmm2,xmm2				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm2,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm2,xmm6				; y8+q6+q4

	movlpd	xmm6,qword ptr sqrt_2_0
	mulsd	xmm1,xmm11				; -3x_l

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm2,xmm7				; y8+q6+q4+q2

	mulsd	xmm6,xmm0				; sqrt 2*y

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm2,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm2				; p+q
	
	mulsd	xmm4,xmm6				; sqrt 2*y*(p+q)
	mulsd	xmm0,xmm13				; -3*y

	addsd	xmm3,xmm4				; p+sqrt 2*y*(p+q)
	subsd	xmm2,xmm4				; q-sqrt 2*y*(p+q)

	divsd	xmm3,xmm2				; (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm1,xmm12
	
	mulsd	xmm0,xmm3				; -3*y * (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm0,xmm1

	addsd	xmm0,xmm10				; -sqrt 2-3*y-3*y * ..

	ret

tan_real_1_0_2:
	subsd	xmm1,xmm0

tan_real_1_0_n:
	movlpd	xmm0,qword ptr real_m_pi_d_4
	movlpd	xmm2,qword ptr real_m_pi_d_4_l

	subsd	xmm0,xmm1				; -(pi/4)_h-x_h
	subsd	xmm2,xmm12				; -(pi/4)_l-x_l
	mulsd	xmm1,qword ptr real_m_2_0 ; -2x

	addsd	xmm2,xmm0				; y=-pi/4-x
	addsd	xmm12,xmm12				; 2x_l
	subsd	xmm1,qword ptr real_pi_d_2_p_1_0 ; -2x-(pi/2+1)=-1-2y

	movlpd	xmm10,qword ptr real_pi_d_2_p_1_0_l
	movlpd	xmm11,qword ptr real_2_0
	jmp		tan_real_1_0_pn

tan_real_n_1_0_2:
	subsd	xmm1,xmm0

tan_real_1_0_2_p:
	movlpd	xmm0,qword ptr real_m_pi_d_4
	movlpd	xmm2,qword ptr real_m_pi_d_4_l
	movlpd	xmm11,qword ptr real_m_2_0

	addsd	xmm0,xmm1				; -(pi/4)_h+x_h
	addsd	xmm2,xmm12				; -(pi/4)_l+x_l
	mulsd	xmm1,xmm11				; -2x

	addsd	xmm2,xmm0				; y=pi/4-x
	addsd	xmm12,xmm12				; 2x_l
	addsd	xmm1,qword ptr real_pi_d_2_p_1_0 ; (pi/2+1)-2x-=1+2y

	movlpd	xmm10,qword ptr real_m_pi_d_2_p_1_0_l
	jmp		tan_real_1_0_pn

tan_real_n_5:
	ucomisd	xmm0,qword ptr real_n_2pi_m_0_338
	movlpd	xmm12,qword ptr real_m_2_pi_l
	movlpd	xmm1,qword ptr real_2_pi
	ja		tan_real_n_s_0_5_5_p
	ucomisd	xmm0,qword ptr real_n_2pi_p_0_338
	ja		tan_real_5_n
	ucomisd	xmm0,qword ptr real_n_2pi_p_0_699
	ja		tan_real_n_s_0_5_5_n
	addsd	xmm0,xmm1
	jmp		tan_real_1_0_3_n

tan_real_5:
	ucomisd	xmm0,qword ptr real_2pi_m_0_338
	movlpd	xmm12,qword ptr real_2_pi_l
	movlpd	xmm1,qword ptr real_2_pi
	jb		tan_real_s_0_5_5
	ucomisd	xmm0,qword ptr real_2pi_p_0_338
	jb		tan_real_5_0
	ucomisd	xmm0,qword ptr real_2pi_p_0_699
	jb		tan_real_s_0_5_5_p
	subsd	xmm0,xmm1
	jmp		tan_real_1_0_3

tan_real_n_3:
	ucomisd	xmm0,qword ptr real_n_pi_m_0_338
	movlpd	xmm12,qword ptr real_m_pi_l
	movlpd	xmm1,qword ptr real_pi
	ja		tan_real_n_s_0_5_3_p
	ucomisd	xmm0,qword ptr real_n_pi_p_0_338
	ja		tan_real_3_n
	ucomisd	xmm0,qword ptr real_n_pi_p_0_699
	ja		tan_real_n_s_0_5_3_n
	addsd	xmm0,xmm1
	jmp		tan_real_1_0_3_n

tan_real_3:
	ucomisd	xmm0,qword ptr real_pi_m_0_338
	movlpd	xmm1,qword ptr real_pi
	movlpd	xmm12,qword ptr real_pi_l
	jb		tan_real_s_0_5_3
	ucomisd	xmm0,qword ptr real_pi_p_0_338
	jb		tan_real_3_0
	ucomisd	xmm0,qword ptr real_pi_p_0_699
	jb		tan_real_s_0_5_3_p
	subsd	xmm0,xmm1
	jmp		tan_real_1_0_3

tan_real_5_n:
tan_real_3_n:
	addsd	xmm0,xmm1
	jmp		tan_real_3_

tan_real_5_0:
tan_real_3_0:
	subsd	xmm0,xmm1

tan_real_3_:
	movlpd	xmm2,qword ptr real_26_bits

	andpd	xmm2,xmm0				; y_1_h
	movsd	xmm1,xmm0				; y_1

	subsd	xmm1,xmm12				; y
	movsd	xmm8,xmm0				; y_1
	subsd	xmm0,xmm2				; y_1-y_1_h

	movsd	xmm3,xmm2				; y_1_h
	addsd	xmm2,xmm1				; y+y_1_h
	subsd	xmm0,xmm12				; y_1_l

	mulsd	xmm3,xmm3				; y_1_h^2
	mulsd	xmm0,xmm2				; (y+y_1_h)*y_1_l

	addsd	xmm0,xmm3				; y^2

	subsd	xmm8,xmm1				; y_1-y

	movlpd	xmm6,qword ptr tan_q_1
	movlpd	xmm5,qword ptr tan_q_2

	subsd	xmm8,xmm12				; y_s

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm7,qword ptr tan_p_1
	mulsd	xmm6,xmm2				; q2

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	mulsd	xmm5,xmm4				; q4
	mulsd	xmm2,qword ptr tan_q_3	; q6
	
	mulsd	xmm4,qword ptr tan_p_2	; p4

	addsd	xmm0,xmm2				; x8+q6

	mulsd	xmm7,xmm3				; p2

	addsd	xmm0,xmm5				; x8+q6+q4

	addsd	xmm4,xmm7				; p4+p2

	addsd	xmm0,xmm6				; x8+q6+q4+q2

	addsd	xmm4,qword ptr tan_p_0	; p4+p2+p0

	addsd	xmm0,qword ptr tan_q_0	; x8+q6+q4+q2+q0

	divsd	xmm4,xmm0				; p/q

	mulsd	xmm3,xmm1				; x3	
	movsd	xmm0,xmm1				; x

;	movlpd	xmm2,qword ptr real_0_125

	mulsd	xmm3,xmm4
	
;	ucomisd	xmm3,xmm2
;	jae		tan_real_3_1

	addsd	xmm3,xmm8

	addsd	xmm0,xmm3

	ret

;tan_real_3_1:
;	subsd	xmm3,xmm2
;	addsd	xmm0,xmm2

;	addsd	xmm3,xmm8

;	addsd	xmm0,xmm3

;	ret

tan_real_1_0_3:
	movlpd	xmm1,qword ptr real_pi_d_4
	movlpd	xmm2,qword ptr real_pi_d_4_l

	subsd	xmm1,xmm0				; (pi/4)_h-x
	addsd	xmm2,xmm12				; (pi/4)_l+n_x_l
	mulsd	xmm0,qword ptr real_2_0 ; 2x

	addsd	xmm2,xmm1				; y=pi/4-x
	movlpd	xmm1,qword ptr real_1_0_m_pi_d_2_52
	addsd	xmm12,xmm12				; 2n_x_l
	addsd	xmm1,xmm0				; 2x+(1-pi/2)=1-2y

	movlpd	xmm11,qword ptr real_m_2_0
	movlpd	xmm10,qword ptr real_pi_d_2_m_1_0_52_l

	jmp		tan_real_1_0_pn

tan_real_1_0_3_n:
	movlpd	xmm1,qword ptr real_pi_d_4
	movlpd	xmm2,qword ptr real_pi_d_4_l

	addsd	xmm1,xmm0
	subsd	xmm2,xmm12				; (pi/4)_l-n_x_l
	mulsd	xmm0,qword ptr real_2_0 ; 2x

	addsd	xmm2,xmm1				; y=pi/4+x
	movlpd	xmm1,qword ptr real_pi_d_2_m_1_0_52
	addsd	xmm12,xmm12				; 2n_x_l
	addsd	xmm1,xmm0				; 2x+(pi/2-1)=-1+2y

	movlpd	xmm11,qword ptr real_2_0
	movlpd	xmm10,qword ptr real_m_pi_d_2_m_1_0_52_l

tan_real_1_0_pn:
	movsd	xmm0,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm2				; y2
	mulsd	xmm2,xmm2				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm2				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm2				; y4
	mulsd	xmm2,xmm2				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm2,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm2,xmm6				; y8+q6+q4

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm2,xmm7				; y8+q6+q4+q2

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm2,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm2				; p+q

	mulsd	xmm4,xmm0				; y*(p+q)
	mulsd	xmm0,xmm11				; -2y | 2y

	subsd	xmm3,xmm4				; p-y*(p+q)
	addsd	xmm2,xmm4				; q+y*(p+q)

	divsd	xmm3,xmm2				; (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm12,xmm10
	
	mulsd	xmm0,xmm3				; -2y * (p-y*(p+q))/(q+y*(p+q)) | 2y * (p-y*(p+q))/(q+y*(p+q))

	subsd	xmm0,xmm12

	addsd	xmm0,xmm1				; 1-2y-2y * .. | -1+2y+2y * ..

	ret

tan_real_n_s_0_5_5_p:
	ucomisd	xmm0,qword ptr real_n_2pi_m_0_542
	addsd	xmm0,xmm1
	jb		tan_real_0_5_p
	jmp		tan_real_s_0_5_p

tan_real_s_0_5_5_p:
	ucomisd	xmm0,qword ptr real_2pi_p_0_542
	subsd	xmm0,xmm1
	jb		tan_real_0_5_p
	jmp		tan_real_s_0_5_p

tan_real_n_s_0_5_3_p:
	ucomisd	xmm0,qword ptr real_n_pi_m_0_542
	addsd	xmm0,xmm1
	jb		tan_real_0_5_p
	jmp		tan_real_s_0_5_p

tan_real_s_0_5_3_p:
	ucomisd	xmm0,qword ptr real_pi_p_0_542
	subsd	xmm0,xmm1
	jb		tan_real_0_5_p

tan_real_s_0_5_p:
	movlpd	xmm1,qword ptr atan_sqrt_0_5
	movlpd	xmm2,qword ptr atan_sqrt_0_5_l
	movlpd	xmm10,qword ptr real_51_bits

	subsd	xmm1,xmm0				; atan sqrt 0.5_h-x
	addsd	xmm2,xmm12				; atan sqrt 0.5_l+n_x_l
	andpd	xmm10,xmm0				; x_h

	movlpd	xmm11,qword ptr real_1_5
	addsd	xmm2,xmm1				; y=atan sqrt 0.5-x
	subsd	xmm0,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; 1.5x_h

	movsd	xmm1,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	subsd	xmm0,xmm12				; x_h_l-n_x_l
	addsd	xmm10,qword ptr sqrtn_0_5_m_1_5_atann_sqrt_0_5 ; 1.5x+(sqrt 0.5-1.5atan sqrt 0.5)=sqrt 0.5+1.5y

	movlpd	xmm12,qword ptr sqrtn_0_5_m_1_5_atann_sqrt_0_5_l
	movlpd	xmm13,qword ptr real_m_1_5
	movlpd	xmm14,qword ptr sqrt_0_5
	jmp		tan_real_0_5_a_s_0_5_3_pn

tan_real_n_s_0_5_5_n:
	ucomisd	xmm0,qword ptr real_n_2pi_p_0_542
	addsd	xmm0,xmm1
	ja		tan_real_0_5_n
	jmp		tan_real_s_0_5_n

tan_real_s_0_5_5:
	ucomisd	xmm0,qword ptr real_2pi_m_0_542
	subsd	xmm0,xmm1
	ja		tan_real_0_5_n
	jmp		tan_real_s_0_5_n

tan_real_n_s_0_5_3_n:
	ucomisd	xmm0,qword ptr real_n_pi_p_0_542
	addsd	xmm0,xmm1
	ja		tan_real_0_5_n
	jmp		tan_real_s_0_5_n

tan_real_s_0_5_3:
	ucomisd	xmm0,qword ptr real_pi_m_0_542
	subsd	xmm0,xmm1
	ja		tan_real_0_5_n

tan_real_s_0_5_n:
	movlpd	xmm1,qword ptr atan_sqrt_0_5
	movlpd	xmm2,qword ptr atan_sqrt_0_5_l
	movlpd	xmm10,qword ptr real_51_bits

	addsd	xmm1,xmm0				; x_h+atan sqrt 0.5_h
	subsd	xmm2,xmm12				; -n_x_l+atan sqrt 0.5_l
	andpd	xmm10,xmm0				; x_h

	movlpd	xmm11,qword ptr real_1_5
	addsd	xmm2,xmm1				; y=x+atan sqrt 0.5
	subsd	xmm0,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; 1.5x_h

	movsd	xmm1,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	subsd	xmm0,xmm12				; x_h_l-n_x_l
	subsd	xmm10,qword ptr sqrtn_0_5_m_1_5_atann_sqrt_0_5 ; 1.5x-(sqrt 0.5-1.5atan sqrt 0.5)=-sqrt 0.5+1.5y

	movlpd	xmm12,qword ptr n_sqrtn_0_5_m_1_5_atann_sqrt_0_5_l
	movlpd	xmm13,qword ptr real_1_5
	movlpd	xmm14,qword ptr sqrt_0_5

tan_real_0_5_a_s_0_5_3_pn:
	movlpd	xmm7,qword ptr tan3_q_1
	movlpd	xmm6,qword ptr tan3_q_2

	movsd	xmm3,xmm2				; y2
	mulsd	xmm2,xmm2				; y4

	movlpd	xmm9,qword ptr tan3_q_3
	mulsd	xmm7,xmm3				; q2

	movsd	xmm4,xmm3				; y2
	mulsd	xmm3,xmm2				; y6

	movlpd	xmm8,qword ptr tan3_p_0

	movsd	xmm5,xmm2				; y4
	mulsd	xmm2,xmm2				; y8

	mulsd	xmm9,xmm3				; q6
	mulsd	xmm3,qword ptr tan3_p_2	; p6

	mulsd	xmm6,xmm5				; q4
	mulsd	xmm5,qword ptr tan3_p_1	; p4
	
	addsd	xmm2,xmm9				; y8+q6

	mulsd	xmm8,xmm4				; p2

	addsd	xmm2,xmm6				; y8+q6+q4

	mulsd	xmm0,xmm11				; 1.25|1.5x_l

	addsd	xmm3,xmm5				; p6+p4
	addsd	xmm2,xmm7				; y8+q6+q4+q2

	mulsd	xmm14,xmm1				; 0.5|sqrt 0.5*y

	addsd	xmm3,xmm8				; p6+p4+p2
	addsd	xmm2,qword ptr tan3_q_0	; y8+q6+q4+q2+q0

	movsd	xmm4,xmm3				; p
	addsd	xmm4,xmm2				; p+q

	mulsd	xmm4,xmm14				; 0.5|sqrt 0.5*y*(p+q)

	subsd	xmm3,xmm4				; p-sqrt 0.5*y*(p+q)
	addsd	xmm2,xmm4				; q+sqrt 0.5*y*(p+q)

	divsd	xmm3,xmm2				; (p-y*(p+q))/(q+y*(p+q))

	addsd	xmm0,xmm12
	
	mulsd	xmm1,xmm3				; y * (p-y*(p+q))/(q+y*(p+q))

	mulsd	xmm1,xmm13				; 1.25|1.5*y*..

	addsd	xmm0,xmm1

	addsd	xmm0,xmm10				; 0.5|sqrt 0.5+1.25|1.5*y+1.25|1.5*y * ..

	ret

tan_real_0_5_p:
	movlpd	xmm1,qword ptr atan_0_5_53
	movlpd	xmm2,qword ptr atan_0_5_53_l
	movlpd	xmm10,qword ptr real_50_bits

	subsd	xmm1,xmm0				; atan 0.5_h-x
	addsd	xmm2,xmm12				; atan 0.5_l-n_x_l
	andpd	xmm10,xmm0				; x_h

	movlpd	xmm11,qword ptr real_1_25
	addsd	xmm2,xmm1				; y=x+atan 0.5
	subsd	xmm0,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; 1.25x_h

	movsd	xmm1,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	subsd	xmm0,xmm12				; x_h_l-n_x_l
	addsd	xmm10,qword ptr real_0_5_m_1_25_atan_0_5_49 ; 1.25x+(0.5-1.25atan 0.5)=0.5+1.25y

	movlpd	xmm12,qword ptr real_0_5_m_1_25_atan_0_5_49_l
	movlpd	xmm13,qword ptr real_m_1_25
	movlpd	xmm14,qword ptr real_0_5
	jmp		tan_real_0_5_a_s_0_5_3_pn

tan_real_0_5_n:
	movlpd	xmm1,qword ptr atan_0_5_53
	movlpd	xmm2,qword ptr atan_0_5_53_l
	movlpd	xmm10,qword ptr real_50_bits

	addsd	xmm1,xmm0				; x_h+atan 0.5_h
	subsd	xmm2,xmm12				; -n_x_l+atan 0.5_l
	andpd	xmm10,xmm0				; x_h

	movlpd	xmm11,qword ptr real_1_25
	addsd	xmm2,xmm1				; y=x+atan 0.5
	subsd	xmm0,xmm10				; x_h_l
	mulsd	xmm10,xmm11				; 1.25x_h

	movsd	xmm1,xmm2				; y
	mulsd	xmm2,xmm2				; y2

	subsd	xmm0,xmm12				; x_h_l-n_x_l
	subsd	xmm10,qword ptr real_0_5_m_1_25_atan_0_5_49 ; 1.25x-(0.5-1.25atan 0.5)=-0.5+1.25y

	movlpd	xmm12,qword ptr real_1_25_atan_0_5_m_0_5_49_l
	movlpd	xmm13,qword ptr real_1_25
	movlpd	xmm14,qword ptr real_0_5
	jmp		tan_real_0_5_a_s_0_5_3_pn

tan_real_too_large:
tan_real_too_small_or_nan:
	subsd	xmm0,xmm0
	ret

_T001	ends

_T002	segment para 'CODE'

rem_36825084_pi:
	movsd	xmm1,xmm0	
	divsd	xmm0,qword ptr real_36825084_pi
	
	movq	xmm4,qword ptr round_c
	movq	xmm2,xmm0
	psrlq	xmm0,52
	psubq	xmm4,xmm0
	movq	xmm5,qword ptr mask_all_one
	psllq	xmm5,xmm4
	andpd	xmm5,xmm2
	
	movlpd	xmm2,qword ptr real_36825084_pi_27
	movlpd	xmm3,qword ptr real_36825084_pi_27_27
	movlpd	xmm4,qword ptr real_36825084_pi_54_l

	movsd	xmm0,xmm1

	mulsd	xmm2,xmm5
	mulsd	xmm3,xmm5
	mulsd	xmm4,xmm5

	subsd	xmm0,xmm2
	subsd	xmm0,xmm3
	movsd	xmm7,xmm0	
	subsd	xmm0,xmm4

	subsd	xmm7,xmm0
	subsd	xmm7,xmm4

	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi

	ucomisd	xmm1,qword ptr real_3_0
	jae		rem_36825084_pi_g3

	ucomisd	xmm1,qword ptr real_1_0
	jae		rem_36825084_pi_g1

	movlpd	xmm1,qword ptr real_0_0
	movsd	xmm5,xmm1
	movsd	xmm6,xmm1
	ret

rem_36825084_pi_g1:
	movlpd	xmm1,qword ptr real_2_0
	movlpd	xmm5,qword ptr real_0_0
	movsd	xmm6,xmm1
	ret

rem_36825084_pi_g3:
	addsd	xmm1,qword ptr real_1_0	; x*4/pi+1
	
	movq	xmm4,qword ptr round_even_c
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1
	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi+1)

	movq	xmm5,qword ptr mask_all_one_except_last
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm5,xmm4
	psllq	xmm6,xmm4
	ret

rem_n_36825084_pi:
	movsd	xmm1,xmm0	
	divsd	xmm0,qword ptr real_36825084_pi
	
	movq	xmm4,qword ptr m_round_c
	movq	xmm2,xmm0
	psrlq	xmm0,52
	psubq	xmm4,xmm0
	movq	xmm5,qword ptr mask_all_one
	psllq	xmm5,xmm4
	andpd	xmm5,xmm2
	
	movlpd	xmm2,qword ptr real_36825084_pi_27
	movlpd	xmm3,qword ptr real_36825084_pi_27_27
	movlpd	xmm4,qword ptr real_36825084_pi_54_l

	movsd	xmm0,xmm1

	mulsd	xmm2,xmm5
	mulsd	xmm3,xmm5
	mulsd	xmm4,xmm5

	subsd	xmm0,xmm2
	subsd	xmm0,xmm3
	movsd	xmm7,xmm0	
	subsd	xmm0,xmm4

	subsd	xmm7,xmm0
	subsd	xmm7,xmm4

	movlpd	xmm1,qword ptr real_4_d_pi

	mulsd	xmm1,xmm0				; x*4/pi

	ucomisd	xmm1,qword ptr real_m_3_0
	jbe		rem_n_36825084_pi_g3

	ucomisd	xmm1,qword ptr real_m_1_0
	jbe		rem_n_36825084_pi_g1

	movlpd	xmm1,qword ptr real_0_0
	movsd	xmm5,xmm1
	movsd	xmm6,xmm1
	ret

rem_n_36825084_pi_g1:
	movlpd	xmm1,qword ptr real_m_2_0
	movlpd	xmm5,qword ptr real_0_0
	movsd	xmm6,xmm1
	ret
	
rem_n_36825084_pi_g3:
	subsd	xmm1,qword ptr real_1_0	; x*4/pi-1
	
	movq	xmm4,qword ptr m_round_even_c
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1
	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2				; round_even (x*4/pi-1)

	movq	xmm5,qword ptr mask_all_one_except_last
	movq	xmm6,qword ptr mask_all_one_except_second_last
	psllq	xmm5,xmm4
	psllq	xmm6,xmm4
	ret

_T002	ends

_T003	segment para 'CODE'

	public	asin_real

asin_real:
	ucomisd	xmm0,qword ptr real_0_4

	lea		rcx,asin_c

	ja		asin_real_2

	ucomisd	xmm0,qword ptr real_m_0_4
	jb		asin_real_3				; x<0.55 | NAN

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm6,qword ptr (asin_q_4-asin_c)[rcx]
	movlpd	xmm7,qword ptr (asin_q_3-asin_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm8,qword ptr (asin_q_2-asin_c)[rcx]
	movlpd	xmm9,qword ptr (asin_q_1-asin_c)[rcx]

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movlpd	xmm10,qword ptr (asin_p_1-asin_c)[rcx]

	movsd	xmm3,xmm2				; x2
	mulsd	xmm3,xmm4				; x6

	mulsd	xmm6,xmm0				; q8
	movsd	xmm5,xmm0				; x8
	mulsd	xmm0,xmm2				; x10

	mulsd	xmm5,qword ptr (asin_p_4-asin_c)[rcx] ; p8

	mulsd	xmm7,xmm3				; q6
	mulsd	xmm3,qword ptr (asin_p_3-asin_c)[rcx] ; p6
	
	addsd	xmm0,xmm6				; x10+q8

	mulsd	xmm8,xmm4				; q4
	mulsd	xmm4,qword ptr (asin_p_2-asin_c)[rcx] ; p4

	addsd	xmm0,xmm7				; x10+q8+q6
	addsd	xmm3,xmm5				; p8+p6

	mulsd	xmm9,xmm2				; q2
	mulsd	xmm10,xmm2				; p2

	addsd	xmm0,xmm8				; x10+q8+q6+q4
	addsd	xmm3,xmm4				; p8+p6+p4

	addsd	xmm0,xmm9				; x10+q8+q6+q4+q2
	addsd	xmm3,xmm10				; p8+p6+p4+p2

	addsd	xmm0,qword ptr (asin_q_0-asin_c)[rcx] ; x10+q8+q6+q4+q2+q0
	addsd	xmm3,qword ptr (asin_p_0-asin_c)[rcx] ; p8+p6+p4+p2+p0

	divsd	xmm3,xmm0				; p/q

	mulsd	xmm2,xmm1				; x3
	movsd	xmm0,xmm1				; x

	mulsd	xmm2,xmm3
	addsd	xmm0,xmm2

	ret

asin_real_2:
	ucomisd	xmm0,qword ptr real_0_675
	jb		asin_real_0_54

	movlpd	xmm1,qword ptr real_1_0

	ucomisd	xmm0,xmm1
	subsd	xmm1,xmm0

	jae		asin_real_1_or_e

	movlpd	xmm11,qword ptr real_2_0
	
	movsd	xmm0,xmm1					; x
	mulsd	xmm1,xmm1					; x2

	mulsd	xmm11,xmm0					; 2x

	movlpd	xmm7,qword ptr (asin2_q_3-asin_c)[rcx]

	movsd	xmm2,xmm1					; x2
	mulsd	xmm1,xmm1					; x4

	sqrtsd	xmm12,xmm11					; sqrt 2x

	movlpd	xmm5,qword ptr (asin2_p_3-asin_c)[rcx]
	movlpd	xmm8,qword ptr (asin2_q_2-asin_c)[rcx]

	movsd	xmm4,xmm1					; x4

	movlpd	xmm9,qword ptr (asin2_q_1-asin_c)[rcx]
	movlpd	xmm10,qword ptr (asin2_p_1-asin_c)[rcx]

	movsd	xmm3,xmm2					; x2
	mulsd	xmm3,xmm0					; x3

	mulsd	xmm4,qword ptr (asin2_p_4-asin_c)[rcx] ; p4

	mulsd	xmm7,xmm3					; q3
	mulsd	xmm5,xmm3					; p3
	
	mulsd	xmm8,xmm2					; q2
	mulsd	xmm2,qword ptr (asin2_p_2-asin_c)[rcx] ; p2

	addsd	xmm1,xmm7					; x4+q3
	addsd	xmm4,xmm5					; p4+p3

	mulsd	xmm9,xmm0					; q1
	mulsd	xmm10,xmm0					; p1

	addsd	xmm1,xmm8					; x5+q4+q3+q2
	addsd	xmm4,xmm2					; p4+p3+p2

	addsd	xmm1,xmm9					; x5+q4+q3+q2+q1
	addsd	xmm4,xmm10					; p4+p3+p2+p1

	movlpd	xmm13,qword ptr real_21_bits

	addsd	xmm1,qword ptr (asin2_q_0-asin_c)[rcx] ; x5+q4+q3+q2+q1+q0
	addsd	xmm4,qword ptr (asin2_p_0-asin_c)[rcx] ; p4+p3+p2+p1+p0

	andpd	xmm13,xmm12					; s21

	divsd	xmm4,xmm1					; p/q

	movsd	xmm14,xmm13					; s21
	movsd	xmm15,xmm12					; s
	addsd	xmm12,xmm13					; s+s21

	mulsd	xmm13,xmm13					; s21*s21
	subsd	xmm11,xmm13					; 2x-s21*s21
	divsd	xmm11,xmm12					; sl

	addsd	xmm14,qword ptr real_m_pi_d_2	; s21-pi_d_2
	mulsd	xmm4,xmm0					; x*p/q

	movlpd	xmm0,qword ptr real_pi_d_2_l
	subsd	xmm0,xmm11					; pi_d_2_l-sl

	mulsd	xmm4,xmm15					; s*x*p/q

	subsd	xmm0,xmm4					; pi_d_2_l-sl-s*x*p/q
	subsd	xmm0,xmm14					; pi_d_2_l-sl-s*x*p/q-s21+pi_d_2

	ret

asin_real_3:
	ucomisd	xmm0,qword ptr real_m_0_675
	ja		asin_real_m_0_54

	movlpd	xmm1,qword ptr real_m_1_0

	ucomisd	xmm0,xmm1
	jbe		asin_real_m_1_or_e			; x<=-1 | NAN

	subsd	xmm0,xmm1

	movlpd	xmm11,qword ptr real_2_0
	
	movsd	xmm1,xmm0					; x
	mulsd	xmm0,xmm0					; x2

	mulsd	xmm11,xmm1					; 2x

	movlpd	xmm7,qword ptr (asin2_q_3-asin_c)[rcx]

	movsd	xmm2,xmm0					; x2
	mulsd	xmm0,xmm0					; x4

	sqrtsd	xmm12,xmm11					; sqrt 2x

	movlpd	xmm5,qword ptr (asin2_p_3-asin_c)[rcx]
	movlpd	xmm8,qword ptr (asin2_q_2-asin_c)[rcx]

	movsd	xmm4,xmm0					; x4

	movlpd	xmm9,qword ptr (asin2_q_1-asin_c)[rcx]
	movlpd	xmm10,qword ptr (asin2_p_1-asin_c)[rcx]

	movsd	xmm3,xmm2					; x2
	mulsd	xmm3,xmm1					; x3

	mulsd	xmm4,qword ptr (asin2_p_4-asin_c)[rcx] ; p4

	mulsd	xmm7,xmm3					; q3
	mulsd	xmm5,xmm3					; p3
	
	mulsd	xmm8,xmm2					; q2
	mulsd	xmm2,qword ptr (asin2_p_2-asin_c)[rcx] ; p2

	addsd	xmm0,xmm7					; x4+q3
	addsd	xmm4,xmm5					; p4+p3

	mulsd	xmm9,xmm1					; q1
	mulsd	xmm10,xmm1					; p1

	addsd	xmm0,xmm8					; x5+q4+q3+q2
	addsd	xmm4,xmm2					; p4+p3+p2

	addsd	xmm0,xmm9					; x5+q4+q3+q2+q1
	addsd	xmm4,xmm10					; p4+p3+p2+p1

	movlpd	xmm13,qword ptr real_21_bits

	addsd	xmm0,qword ptr (asin2_q_0-asin_c)[rcx] ; x5+q4+q3+q2+q1+q0
	addsd	xmm4,qword ptr (asin2_p_0-asin_c)[rcx] ; p4+p3+p2+p1+p0

	andpd	xmm13,xmm12					; s21

	divsd	xmm4,xmm0					; p/q

	movsd	xmm14,xmm13					; s21
	movsd	xmm15,xmm12					; s
	addsd	xmm12,xmm13					; s+s21
	mulsd	xmm13,xmm13					; s21*s21
	subsd	xmm11,xmm13					; 2x-s21*s21
	divsd	xmm11,xmm12					; sl

	addsd	xmm14,qword ptr real_m_pi_d_2	; s21-pi_d_2
	mulsd	xmm4,xmm1					; x*p/q

	movlpd	xmm0,qword ptr real_m_pi_d_2_l
	addsd	xmm0,xmm11					; -pi_d_2_l+sl

	mulsd	xmm4,xmm15					; s*x*p/q

	addsd	xmm0,xmm4					; -pi_d_2_l+sl+s*x*p/q
	addsd	xmm0,xmm14					; -pi_d_2_l+sl+s*x*p/q+s21-pi_d_2

	ret

asin_real_m_0_54:
	movlpd	xmm1,qword ptr real_m_0_54000000017867999524

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	lea		rcx,asin_p3_c
	lea		rdx,asin_p4_c

	cmova	rcx,rdx

	jmp		asin_real_pm_0_54

asin_real_0_54:
	movlpd	xmm1,qword ptr real_0_54000000017867999524

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	lea		rcx,asin_p1_c
	lea		rdx,asin_p2_c

	cmovb	rcx,rdx

asin_real_pm_0_54:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm7,qword ptr (asin_p1_4-asin_p1_c)[rcx]
	movlpd	xmm8,qword ptr (asin_p1_3-asin_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm7,xmm2				; p4
	mulsd	xmm8,xmm2				; p3

	movlpd	xmm9,qword ptr (asin_p1_6-asin_p1_c)[rcx]
	movlpd	xmm10,qword ptr (asin_p1_5-asin_p1_c)[rcx]

	movsd	xmm3,xmm2				; x2
	mulsd	xmm2,xmm0				; x6

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8
	
	mulsd	xmm9,xmm4				; p6
	mulsd	xmm10,xmm4				; p5

	movlpd	xmm11,qword ptr (asin_p1_8-asin_p1_c)[rcx]
	movlpd	xmm12,qword ptr (asin_p1_10-asin_p1_c)[rcx]

	mulsd	xmm4,xmm2				; x10

	movlpd	xmm13,qword ptr (asin_p1_12-asin_p1_c)[rcx]
	movlpd	xmm14,qword ptr (asin_p1_14-asin_p1_c)[rcx]

	movsd	xmm6,xmm2				; x6
	mulsd	xmm2,xmm2				; x12

	mulsd	xmm11,xmm6				; p8
	mulsd	xmm6,qword ptr (asin_p1_7-asin_p1_c)[rcx] ; p7

	mulsd	xmm12,xmm0				; p10
	mulsd	xmm0,qword ptr (asin_p1_9-asin_p1_c)[rcx] ; p9

	mulsd	xmm13,xmm4				; p12
	mulsd	xmm4,qword ptr (asin_p1_11-asin_p1_c)[rcx] ; p11

	mulsd	xmm14,xmm2				; p14
	mulsd	xmm2,qword ptr (asin_p1_13-asin_p1_c)[rcx] ; p13

	addsd	xmm13,xmm14				; p14+p12
	addsd	xmm2,xmm4				; p13+p11

	movlpd	xmm15,qword ptr (asin_p1_2-asin_p1_c)[rcx]
	
	addsd	xmm12,xmm13				; p14+p12+p10
	addsd	xmm0,xmm2				; p13+p11+p9

	mulsd	xmm15,xmm3				; p2
	
	addsd	xmm11,xmm12				; p14+p12+p10+p8
	addsd	xmm0,xmm6				; p13+p11+p9+p7

	movlpd	xmm2,qword ptr real_26_bits
	movsd	xmm4,xmm1				; x
	movlpd	xmm6,qword ptr (asin_p1_1l-asin_p1_c)[rcx]
	movlpd	xmm5,qword ptr (asin_p1_1h-asin_p1_c)[rcx]

	addsd	xmm9,xmm11				; p14+p12+p10+p8+p6
	addsd	xmm0,xmm10				; p13+p11+p9+p7+p5

	andpd	xmm2,xmm1				; x_h
	mulsd	xmm6,xmm1				; x*c1l
	movlpd	xmm13,qword ptr (asin_p1_0h-asin_p1_c)[rcx]

	addsd	xmm7,xmm9				; p14+p12+p10+p8+p6+p4
	addsd	xmm0,xmm8				; p13+p11+p9+p7+p5+p3

	subsd	xmm4,xmm2				; x_l
	mulsd	xmm2,xmm5				; x_h*c1h

	mulsd	xmm7,xmm3				; (p14+p12+p10+p8+p6+p4)(*x2)
	mulsd	xmm0,xmm1				; (p13+p11+p9+p7+p5+p3)(*x)

	movsd	xmm14,xmm13
	addsd	xmm13,xmm2				; x_h*c1h+c0h
	
	addsd	xmm0,xmm7				; p14+p13+..+p3

	subsd	xmm14,xmm13				; c0h-(x_h*c1h+c0h)
	mulsd	xmm4,xmm5				; x_l*c1h

	addsd	xmm0,xmm15				; p14+p13+..+p3+p2
;	addsd	xmm0,qword ptr (asin_p1_0l-asin_p1_c)[rcx]
	
	addsd	xmm14,xmm2				; (c0h-(x_h*c1h+c0h))+x_h*c1h
	addsd	xmm4,xmm6				; x_l*c1h+x*c1l
	
	addsd	xmm4,xmm14				; (c0h-(x_h*c1h+c0h))+x_h*c1h+x_l*c1h+x*c1l

	addsd	xmm0,xmm4
	addsd	xmm0,xmm13
	ret

asin_real_1_or_e:
	jne		asin_real_e

	movlpd	xmm0,qword ptr real_pi_d_2
	ret

asin_real_m_1_or_e:
	jb		asin_real_e					; NAN

	movlpd	xmm0,qword ptr real_m_pi_d_2
	ret

asin_real_e:
	subsd	xmm0,xmm0
	divsd	xmm0,xmm0
	ret

_T003	ends

_T004	segment para 'CODE'

	public	acos_real

acos_real:
;	ucomisd	xmm0,qword ptr real_0_58
	ucomisd	xmm0,qword ptr real_0_5
	ja		acos_real_2
	ucomisd	xmm0,qword ptr real_m_0_58
	jb		acos_real_3

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm6,qword ptr acos_q_4
	movlpd	xmm7,qword ptr acos_q_3

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm8,qword ptr acos_q_2
	movlpd	xmm9,qword ptr acos_q_1

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movlpd	xmm10,qword ptr acos_p_1

	movsd	xmm3,xmm2				; x2
	mulsd	xmm3,xmm4				; x6

	mulsd	xmm6,xmm0				; q8
	movsd	xmm5,xmm0				; x8
	mulsd	xmm0,xmm2				; x10

	mulsd	xmm5,qword ptr acos_p_4	; p8

	mulsd	xmm7,xmm3				; q6
	mulsd	xmm3,qword ptr acos_p_3 ; p6
	
	addsd	xmm0,xmm6				; x10+q8

	mulsd	xmm8,xmm4				; q4
	mulsd	xmm4,qword ptr acos_p_2 ; p4

	addsd	xmm0,xmm7				; x10+q8+q6
	addsd	xmm3,xmm5				; p8+p6

	mulsd	xmm9,xmm2				; q2
	mulsd	xmm10,xmm2				; p2

	addsd	xmm0,xmm8				; x10+q8+q6+q4
	addsd	xmm3,xmm4				; p8+p6+p4

	movlpd	xmm11,qword ptr real_21_bits

	addsd	xmm0,xmm9				; x10+q8+q6+q4+q2
	addsd	xmm3,xmm10				; p8+p6+p4+p2

	andpd	xmm11,xmm1				; x21

	addsd	xmm0,qword ptr acos_q_0	; x10+q8+q6+q4+q2+q0
	addsd	xmm3,qword ptr acos_p_0 ; p8+p6+p4+p2+p0

	mulsd	xmm2,xmm1				; x3

	divsd	xmm3,xmm0				; p/q

;	ucomisd	xmm1,qword ptr real_0_54
;	ja		acos_real_1

	movsd	xmm0,qword ptr real_pi_d_2 ; pi_d_2

	subsd	xmm1,xmm11				; x21_l
	subsd	xmm0,xmm11				; pi_d_2-x21

	mulsd	xmm2,xmm3				; x3*(p/q)

	addsd	xmm2,qword ptr real_m_pi_d_2_l ; x3*(p/q)-pi_d_2_l
	
	addsd	xmm1,xmm2				; x21_l+x3*(p/q)-pi_d_2_l

	subsd	xmm0,xmm1				; pi_d_2-x21-x21_l-x3*(p/q)+pi_d_2_l
	
	ret

;acos_real_1:
;	movlpd	xmm0,qword ptr real_pi_d_2_m_0_03125

;	subsd	xmm1,xmm11				; x21_l
;	subsd	xmm0,xmm11				; pi_d_2-0.03125-x21

;	mulsd	xmm2,xmm3				; x3*(p/q)

;	addsd	xmm1,qword ptr real_m_pi_d_2_l ; x21_l-pi_d_2_l
	
;	subsd	xmm2,qword ptr real_0_03125 ; x3*(p/q)-0.03125
	
;	addsd	xmm1,xmm2				; x21_l+x3*(p/q)-0.03125-pi_d_2_l

;	subsd	xmm0,xmm1				; pi_d_2-x21-x21_l-x3*(p/q)+pi_d_2_l
	
;	ret

acos_real_2:
	ucomisd	xmm0,qword ptr real_0_75
	jb		acos_real_0_65

	movlpd	xmm1,qword ptr real_1_0

	ucomisd	xmm0,xmm1
	
	subsd	xmm1,xmm0

	jae		acos_real_1_or_e

	movlpd	xmm11,qword ptr real_2_0
	
	movsd	xmm0,xmm1					; x
	mulsd	xmm1,xmm1					; x2

	mulsd	xmm11,xmm0					; 2x

	movlpd	xmm7,qword ptr acos2_q_3

	movsd	xmm2,xmm1					; x2
	mulsd	xmm1,xmm1					; x4

	sqrtsd	xmm12,xmm11					; sqrt 2x

	movlpd	xmm5,qword ptr acos2_p_3
	movlpd	xmm8,qword ptr acos2_q_2

	movsd	xmm4,xmm1					; x4

	movlpd	xmm9,qword ptr acos2_q_1
	movlpd	xmm10,qword ptr acos2_p_1

	movsd	xmm3,xmm2					; x2
	mulsd	xmm3,xmm0					; x3

	mulsd	xmm1,qword ptr acos2_p_4	; p4

	mulsd	xmm7,xmm3					; q3
	mulsd	xmm5,xmm3					; p3

	mulsd	xmm8,xmm2					; q2
	mulsd	xmm2,qword ptr acos2_p_2	; p2

	addsd	xmm4,xmm7					; x4+q3
	addsd	xmm1,xmm5					; p4+p3

	mulsd	xmm9,xmm0					; q1
	mulsd	xmm10,xmm0					; p1

	addsd	xmm4,xmm8					; x4+q3+q2
	addsd	xmm1,xmm2					; p4+p3+p2

	addsd	xmm4,xmm9					; x4+q3+q2+q1
	addsd	xmm1,xmm10					; p4+p3+p2+p1

	movlpd	xmm13,qword ptr real_21_bits

	addsd	xmm4,qword ptr acos2_q_0	; x4+q3+q2+q1+q0
	addsd	xmm1,qword ptr acos2_p_0	; p4+p3+p2+p1+p0

	andpd	xmm13,xmm12					; s21

	divsd	xmm1,xmm4					; p/q

	movsd	xmm14,xmm13					; s21
	movsd	xmm15,xmm12					; s
	addsd	xmm12,xmm13					; s+s21
	mulsd	xmm13,xmm13					; s21*s21
	subsd	xmm11,xmm13					; 2x-s21*s21
	divsd	xmm11,xmm12					; sl
	
	mulsd	xmm0,xmm1					; x*p/q

	mulsd	xmm0,xmm15					; s
	addsd	xmm0,xmm11					; s*x*p/q+sl
	addsd	xmm0,xmm14					; s*x*p/q+sl+s21

	ret

acos_real_0_65:
	movlpd	xmm1,qword ptr real_0_65000000004061742054

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	lea		rcx,acos_p1_c
	lea		rdx,acos_p2_c

	cmovb	rcx,rdx

	jmp		asin_real_pm_0_54

acos_real_3:
	movlpd	xmm1,qword ptr real_m_1_0

	ucomisd	xmm0,xmm1
	
	subsd	xmm0,xmm1

	jbe		acos_real_m_1_or_e

	movlpd	xmm11,qword ptr real_2_0
	
	movsd	xmm1,xmm0					; x
	mulsd	xmm0,xmm0					; x2

	mulsd	xmm11,xmm1					; 2x

	movlpd	xmm7,qword ptr acos2_q_3

	movsd	xmm2,xmm0					; x2
	mulsd	xmm0,xmm0					; x4

	sqrtsd	xmm12,xmm11					; sqrt 2x

	movlpd	xmm5,qword ptr acos2_p_3
	movlpd	xmm8,qword ptr acos2_q_2

	movsd	xmm4,xmm0					; x4

	movlpd	xmm9,qword ptr acos2_q_1
	movlpd	xmm10,qword ptr acos2_p_1

	movsd	xmm3,xmm2					; x2
	mulsd	xmm3,xmm1					; x3

	mulsd	xmm0,qword ptr acos2_p_4	; p4

	mulsd	xmm7,xmm3					; q3
	mulsd	xmm5,xmm3					; p3

	mulsd	xmm8,xmm2					; q2
	mulsd	xmm2,qword ptr acos2_p_2	; p2

	addsd	xmm4,xmm7					; x4+q3
	addsd	xmm0,xmm5					; p4+p3

	mulsd	xmm9,xmm1					; q1
	mulsd	xmm10,xmm1					; p1

	addsd	xmm4,xmm8					; x4+q3+q2
	addsd	xmm0,xmm2					; p4+p3+p2

	addsd	xmm4,xmm9					; x4+q3+q2+q1
	addsd	xmm0,xmm10					; p4+p3+p2+p1

	movlpd	xmm13,qword ptr real_21_bits

	addsd	xmm4,qword ptr acos2_q_0	; x4+q3+q2+q1+q0
	addsd	xmm0,qword ptr acos2_p_0	; p4+p3+p2+p1+p0

	andpd	xmm13,xmm12					; s21

	divsd	xmm0,xmm4					; p/q

	movsd	xmm14,xmm13					; s21
	movsd	xmm15,xmm12					; s
	addsd	xmm12,xmm13					; s+s21
	mulsd	xmm13,xmm13					; s21*s21
	subsd	xmm11,xmm13					; 2x-s21*s21
	divsd	xmm11,xmm12					; sl
	
	mulsd	xmm1,xmm0					; x*p/q

	mulsd	xmm1,xmm15					; s
	movlpd	xmm0,qword ptr real_pi

	subsd	xmm11,qword ptr real_pi_l	; sl-pi_l
	addsd	xmm1,xmm11					; s*x*p/q+sl-pi_l

	subsd	xmm0,xmm14					; pi-s21
	subsd	xmm0,xmm1					; pi-s21-(s*x*p/q+sl)

;	addsd	xmm1,xmm14					; s*x*p/q+sl+s21-pi_l
;	subsd	xmm0,xmm1					; pi-(s*x*p/q+sl+s21)

	ret

acos_real_1_or_e:
	jne		acos_real_e

	movlpd	xmm0,qword ptr real_0_0
	ret

acos_real_m_1_or_e:
	jb		acos_real_e					; NAN

	movlpd	xmm0,qword ptr real_pi
	ret

acos_real_e:
	subsd	xmm0,xmm0
	divsd	xmm0,xmm0
	ret

_T004	ends

_T005	segment para 'CODE'

	public	atan_real

atan_real:
	ucomisd	xmm0,qword ptr real_m_0_26

	movsd	xmm1,xmm0				; x

	jb		atan_real_n				; x<-0.26 | NAN

	ucomisd	xmm0,qword ptr real_1_0
	ja		atan_real_g1			; x>1.0

	ucomisd	xmm0,qword ptr real_0_70
	ja		atan_real_2

	ucomisd	xmm0,qword ptr real_0_26
	ja		atan_real_1

	ucomisd	xmm0,qword ptr real_0_0
	je		atan_real_0_0			; atan -0.0 = -0.0

	mulsd	xmm0,xmm0				; x2

	movlpd	xmm5,qword ptr atan_p_9_1
	
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movsd	xmm14,xmm6				; x2
	mulsd	xmm5,xmm6				; p2

	mulsd	xmm6,xmm0				; x6

	movlpd	xmm9,qword ptr atan_p_9_2

	movsd	xmm10,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm7,qword ptr atan_p_9_3
	movlpd	xmm12,qword ptr atan_p_9_4

	mulsd	xmm10,xmm6				; x10

	movsd	xmm2,xmm6				; x6
	mulsd	xmm7,xmm6				; p6
	mulsd	xmm6,xmm6				; x12

	mulsd	xmm2,xmm0				; x14
	mulsd	xmm12,xmm0				; p8
	mulsd	xmm0,xmm0				; x16

	mulsd	xmm10,qword ptr atan_p_9_5 ; p10
	mulsd	xmm6,qword ptr atan_p_9_6 ; p12
	mulsd	xmm2,qword ptr atan_p_9_7 ; p14
	mulsd	xmm0,qword ptr atan_p_9_8 ; p16

	addsd	xmm0,xmm2				; p16+p14
	addsd	xmm0,xmm6				; p16+p14+p12
	addsd	xmm0,xmm10				; p16+p14+p12+p10
	addsd	xmm0,xmm12				; p16+p14+p12+p10+p8
	addsd	xmm0,xmm7				; p16+p14+p12+p10+p8+p6	

	mulsd	xmm14,xmm1				; x3

	addsd	xmm0,xmm9				; p16+p14+p12+p10+p8+p6+p4
	addsd	xmm0,xmm5				; p16+p14+p12+p10+p8+p6+p4+p2
	addsd	xmm0,qword ptr atan_p_9_0 ; p16+p14+p12+p10+p8+p6+p4+p2+p0

	mulsd	xmm0,xmm14				; x3*p

	addsd	xmm0,xmm1				; x+x3*p

atan_real_0_0:
	ret

atan_real_n:
	ucomisd	xmm0,qword ptr real_m_1_0
	jb		atan_real_l_m1			; x<-1.0 | NAN

	ucomisd	xmm0,qword ptr real_m_0_70
	jb		atan_real_2n

	movlpd	xmm2,qword ptr real_m_2_0
	movlpd	xmm3,qword ptr real_m_0_5

	lea		rdx,n_atan_0_5_52
	jmp		atan_real_1pn

atan_real_1:
	movlpd	xmm2,qword ptr real_2_0
	movlpd	xmm3,qword ptr real_0_5
	
	lea		rdx,atan_0_5_52

atan_real_1pn:
	addsd	xmm0,xmm2				; -2+x
	subsd	xmm3,xmm1				; -0.5-x

	divsd	xmm2,xmm0				; 2/(2+x) = 1/(1+0.5x)

	movlpd	xmm15,qword ptr real_26_bits
	movsd	xmm0,xmm3				; 0.5-x

	lea		rcx,atan_n_0_5_8_c
	movsd	xmm11,xmm3				; (0.5-x)
	andpd	xmm15,xmm3				; (0.5-x)_h

	subsd	xmm11,xmm15				; (0.5-x)_l

	mulsd	xmm0,xmm2				; y=(0.5-x)*(1/(1+0.5x))

	movsd	xmm4,xmm0				; y
	mulsd	xmm0,xmm0				; y2

	movlpd	xmm5,qword ptr (atan_n_0_5_8_1-atan_n_0_5_8_c)[rcx]

	movsd	xmm6,xmm0				; y2
	mulsd	xmm0,xmm0				; y4

	movsd	xmm14,xmm6				; y2
	mulsd	xmm5,xmm6				; p2

	movlpd	xmm8,qword ptr real_27_bits

	mulsd	xmm6,xmm0				; y6

	movlpd	xmm9,qword ptr (atan_n_0_5_8_2-atan_n_0_5_8_c)[rcx]

	movsd	xmm10,xmm0				; y4
	mulsd	xmm0,xmm0				; y8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm12,qword ptr (atan_n_0_5_8_4-atan_n_0_5_8_c)[rcx]

	mulsd	xmm10,xmm6				; y10

	movsd	xmm7,xmm6				; x6
	mulsd	xmm6,xmm6				; x12

	mulsd	xmm12,xmm0				; p8
	mulsd	xmm0,xmm7				; x14

	andpd	xmm8,xmm4				; y_h

	mulsd	xmm7,qword ptr (atan_n_0_5_8_3-atan_n_0_5_8_c)[rcx] ; p6
	mulsd	xmm10,qword ptr (atan_n_0_5_8_5-atan_n_0_5_8_c)[rcx] ; p10
	mulsd	xmm6,qword ptr (atan_n_0_5_8_6-atan_n_0_5_8_c)[rcx] ; p12
	mulsd	xmm0,qword ptr (atan_n_0_5_8_7-atan_n_0_5_8_c)[rcx] ; p14

	movlpd	xmm13,qword ptr real_0_25
	movlpd	xmm1,qword ptr (atan_0_5_real_0_5-atan_0_5_52)[rdx]
	mulsd	xmm13,xmm8				; 0.25*y_h
	mulsd	xmm1,xmm8				; 0.5*y_h
	subsd	xmm3,xmm8				; (0.5-x)-y_h

	addsd	xmm0,xmm6				; p14+p12

	subsd	xmm3,xmm13				; (0.5-x)-1.25*y_h	
	mulsd	xmm15,xmm1				; (0.5-x)_h*0.5*y_h
	mulsd	xmm11,xmm1				; (0.5-x)_l*0.5*y_h

	addsd	xmm0,xmm10				; p14+p12+p10

	addsd	xmm3,xmm15				; (0.5-x)-1.25*y_h+(0.5-x)_h*0.5*y_h

	addsd	xmm0,xmm12				; p14+p12+p10+p8

	addsd	xmm3,xmm11				; (0.5-x)-1.25*y_h+(0.5-x)_h*0.5*y_h+(0.5-x)_l*0.5*y_h

	addsd	xmm0,xmm7				; p14+p12+p10+p8+p6

	mulsd	xmm14,xmm4				; y3

	mulsd	xmm3,xmm2				; c=((0.5-x)-1.25*y_h-(0.5-x)_h*0.5*y_h-(0.5-x)_l*0.5*y_h)*(1/(1+0.5x))

	addsd	xmm0,xmm9				; p14+p12+p10+p8+p6+p4

	movsd	xmm11,xmm8				; y_h
	addsd	xmm8,xmm3				; y_h+c

	addsd	xmm0,xmm5				; p14+p12+p10+p8+p6+p4+p2

	movlpd	xmm7,qword ptr real_40_bits
	movlpd	xmm12,qword ptr real_abs_40_bits
	andpd	xmm7,xmm8				; (y_h+c)_h
	andpd	xmm12,xmm8

	addsd	xmm0,qword ptr (atan_n_0_5_8_0-atan_n_0_5_8_c)[rcx] ; p14+p12+p10+p8+p6+p4+p2+p0

	subsd	xmm11,xmm7				; y_h-(y_h+c)_h
	addsd	xmm3,xmm11				; (y_h-(y_h+c)_h)+c

	mulsd	xmm0,xmm14				; y3*p/q

	movlpd	xmm2,qword ptr (atan_0_5_52_l-atan_0_5_52)[rdx]
	subsd	xmm2,xmm0				; atan_0_5_52_l-y3*p/q
	movlpd	xmm0,qword ptr (atan_0_5_52-atan_0_5_52)[rdx]

	ucomisd	xmm12,qword ptr real_2_p_m_13
	jb		atan_real_1_s

	subsd	xmm0,xmm7				; atan_0_5_52-(y_h+c)_h
	subsd	xmm2,xmm3				; atan_0_5_52_l-y3*p/q-(y_h+c)_l
	addsd	xmm0,xmm2				; atan 0_5-y3*p/q-(0.5-x)/(1+x)

	ret

atan_real_1_s:
	subsd	xmm2,xmm3				; atan_0_5_52_l-y3*p/q-(y_h+c)_l
	subsd	xmm2,xmm7				; atan_0_5_52_l-y3*p/q-(y_h+c)_l-(y_h+c)_h
	addsd	xmm0,xmm2				; atan 0_5-y3*p/q-(1-x)/(1+x)
	ret

atan_real_2n:
	lea		rcx,atan_n_8_c

atan_real_2n_:
	movlpd	xmm2,qword ptr real_m_1_0
	movlpd	xmm3,qword ptr real_m_1_0

	addsd	xmm0,xmm2				; 1+x
	subsd	xmm3,xmm1				; 1-x

	lea		rdx,n_atan_1_53

	divsd	xmm2,xmm0				; 1/(1+x)

	movlpd	xmm15,qword ptr real_26_bits
	movsd	xmm0,xmm3				; 1-x

	movsd	xmm11,xmm3				; (1-x)
	andpd	xmm15,xmm3				; (1-x)_h

	subsd	xmm11,xmm15				; (1-x)_l

	mulsd	xmm0,xmm2				; y=(1-x)*(1/(1+x))

	movsd	xmm4,xmm0				; y
	mulsd	xmm0,xmm0				; y2
	
	movlpd	xmm5,qword ptr (atan_n_8_1-atan_n_8_c)[rcx]

	movsd	xmm6,xmm0				; y2
	mulsd	xmm0,xmm0				; y4

	movsd	xmm14,xmm6				; y2
	mulsd	xmm5,xmm6				; p2

	movlpd	xmm8,qword ptr real_27_bits

	mulsd	xmm6,xmm0				; y6

	movlpd	xmm9,qword ptr (atan_n_8_2-atan_n_8_c)[rcx]

	movsd	xmm10,xmm0				; y4
	mulsd	xmm0,xmm0				; y8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm12,qword ptr (atan_n_8_4-atan_n_8_c)[rcx]

	mulsd	xmm10,xmm6				; y10

	movsd	xmm7,xmm6				; x6
	mulsd	xmm6,xmm6				; x12

	mulsd	xmm12,xmm0				; p8
	mulsd	xmm0,xmm7				; x14

	andpd	xmm8,xmm4				; y_h

	mulsd	xmm7,qword ptr (atan_n_8_3-atan_n_8_c)[rcx] ; p6
	mulsd	xmm10,qword ptr (atan_n_8_5-atan_n_8_c)[rcx] ; p10
	mulsd	xmm6,qword ptr (atan_n_8_6-atan_n_8_c)[rcx] ; p12
	mulsd	xmm0,qword ptr (atan_n_8_7-atan_n_8_c)[rcx] ; p14

	movlpd	xmm13,qword ptr real_2_0
	mulsd	xmm13,xmm8				; 2*y_h
	mulsd	xmm15,xmm8				; (1-x)_h*y_h

	addsd	xmm0,xmm6				; p14+p12

	subsd	xmm3,xmm13				; (1-x)-2*y_h
	mulsd	xmm11,xmm8				; (1-x)_l*y_h

	addsd	xmm0,xmm10				; p14+p12+p10

	subsd	xmm3,xmm15				; (1-x)-2*y_h-(1-x)_h*y_h

	addsd	xmm0,xmm12				; p14+p12+p10+p8

	subsd	xmm3,xmm11				; (1-x)-2*y_h-(1-x)_h*y_h-(1-x)_h*y_l
	jmp		atan_real_2pn_

atan_real_2:
	lea		rcx,atan_n_8_c

atan_real_2p_:
	movlpd	xmm2,qword ptr real_1_0
	movlpd	xmm3,qword ptr real_1_0

	addsd	xmm0,xmm2				; 1+x
	subsd	xmm3,xmm1				; 1-x

	lea		rdx,atan_1_53
	
	divsd	xmm2,xmm0				; 1/(1+x)

	movlpd	xmm15,qword ptr real_26_bits
	movsd	xmm0,xmm3				; 1-x
	
	movsd	xmm11,xmm3				; (1-x)
	andpd	xmm15,xmm3				; (1-x)_h

	subsd	xmm11,xmm15				; (1-x)_l

	mulsd	xmm0,xmm2				; y=(1-x)*(1/(1+x))

	movsd	xmm4,xmm0				; y
	mulsd	xmm0,xmm0				; y2
	
	movlpd	xmm5,qword ptr (atan_n_8_1-atan_n_8_c)[rcx]

	movsd	xmm6,xmm0				; y2
	mulsd	xmm0,xmm0				; y4

	movsd	xmm14,xmm6				; y2
	mulsd	xmm5,xmm6				; p2

	movlpd	xmm8,qword ptr real_27_bits

	mulsd	xmm6,xmm0				; y6

	movlpd	xmm9,qword ptr (atan_n_8_2-atan_n_8_c)[rcx]

	movsd	xmm10,xmm0				; y4
	mulsd	xmm0,xmm0				; y8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm12,qword ptr (atan_n_8_4-atan_n_8_c)[rcx]

	mulsd	xmm10,xmm6				; y10

	movsd	xmm7,xmm6				; x6
	mulsd	xmm6,xmm6				; x12

	mulsd	xmm12,xmm0				; p8
	mulsd	xmm0,xmm7				; x14

	andpd	xmm8,xmm4				; y_h

	mulsd	xmm7,qword ptr (atan_n_8_3-atan_n_8_c)[rcx] ; p6
	mulsd	xmm10,qword ptr (atan_n_8_5-atan_n_8_c)[rcx] ; p10
	mulsd	xmm6,qword ptr (atan_n_8_6-atan_n_8_c)[rcx] ; p12
	mulsd	xmm0,qword ptr (atan_n_8_7-atan_n_8_c)[rcx] ; p14

	movlpd	xmm13,qword ptr real_2_0
	mulsd	xmm13,xmm8				; 2*y_h
	mulsd	xmm15,xmm8				; (1-x)_h*y_h

	addsd	xmm0,xmm6				; p14+p12

	subsd	xmm3,xmm13				; (1-x)-2*y_h
	mulsd	xmm11,xmm8				; (1-x)_l*y_h

	addsd	xmm0,xmm10				; p14+p12+p10

	addsd	xmm3,xmm15				; (1-x)-2*y_h+(1-x)_h*y_h

	addsd	xmm0,xmm12				; p14+p12+p10+p8

	addsd	xmm3,xmm11				; (1-x)-2*y_h+(1-x)_h*y_h+(1-x)_h*y_l

atan_real_2pn_:
	addsd	xmm0,xmm7				; p14+p12+p10+p8+p6

	mulsd	xmm14,xmm4				; y3
	
	mulsd	xmm3,xmm2				; c=((1-x)-2*y_h-(1-x)_h*y_h-(1-x)_h*y_l)*(1/(1+x))

	addsd	xmm0,xmm9				; p14+p12+p10+p8+p6+p4

	movsd	xmm11,xmm8				; y_h
	addsd	xmm8,xmm3				; y_h+c

	addsd	xmm0,xmm5				; p14+p12+p10+p8+p6+p4+p2

	movlpd	xmm7,qword ptr (atan_n_8_real_40_bits-atan_n_8_c)[rcx]
	movlpd	xmm12,qword ptr (atan_n_8_real_abs_40_bits-atan_n_8_c)[rcx]
	andpd	xmm7,xmm8				; (y_h+c)_h
	andpd	xmm12,xmm8

	addsd	xmm0,qword ptr (atan_n_8_0-atan_n_8_c)[rcx] ; p14+p12+p10+p8+p6+p4+p2+p0

	subsd	xmm11,xmm7				; y_h-(y_h+c)_h
	addsd	xmm3,xmm11				; (y_h-(y_h+c)_h)+c
	
	mulsd	xmm0,xmm14				; y3*p/q

	movlpd	xmm2,qword ptr (atan_1_53_l-atan_1_53)[rdx]
	subsd	xmm2,xmm0				; pi_d_4_l-y3*p/q
	movlpd	xmm0,qword ptr (atan_1_53-atan_1_53)[rdx]

	ucomisd	xmm12,qword ptr (atan_n_8_real_2_p_m_12-atan_n_8_c)[rcx]
	jb		atan_real_2_s

	subsd	xmm0,xmm7				; pi_d_4-(y_h+c)_h
	subsd	xmm2,xmm3				; pi_d_4_l-y3*p/q-(y_h+c)_l
	addsd	xmm0,xmm2				; pi/4-y3*p/q-(1-x)/(1+x)

	ret

atan_real_2_s:
	subsd	xmm2,xmm3				; pi_d_4_l-y3*p/q-(y_h+c)_l
	subsd	xmm2,xmm7				; pi_d_4_l-y3*p/q-(y_h+c)_l-(y_h+c)_h
	addsd	xmm0,xmm2				; pi/4-y3*p/q-(1-x)/(1+x)
	ret

atan_real_l_m1:
	ucomisd	xmm0,qword ptr real_m_4_0
	jb		atan_real_4n			; x<4.0 | NAN

	ucomisd	xmm0,qword ptr real_m_1_4
	jb		atan_real_3n

	lea		rcx,atan_p_8_c

	jmp		atan_real_2n_

atan_real_g1:
	ucomisd	xmm0,qword ptr real_4_0
	ja		atan_real_4				; x>4.0

	ucomisd	xmm0,qword ptr real_1_4
	ja		atan_real_3

	lea		rcx,atan_p_8_c

	jmp		atan_real_2p_

atan_real_3n:
	movlpd	xmm2,qword ptr real_m_0_5
	movlpd	xmm3,qword ptr real_m_2_0

	lea		rdx,n_atan_2_0
	jmp		atan_real_3pn

atan_real_3:
	movlpd	xmm2,qword ptr real_0_5
	movlpd	xmm3,qword ptr real_2_0

	lea		rdx,atan_2_0

atan_real_3pn:
	addsd	xmm0,xmm2				; 0.5+x
	subsd	xmm3,xmm1				; 2-x
	
	divsd	xmm2,xmm0				; 0.5/(0.5+x) = 1/(1+2*x)

	movlpd	xmm15,qword ptr real_26_bits
	movsd	xmm0,xmm3				; 2-x

	movsd	xmm11,xmm3				; (2-x)
	andpd	xmm15,xmm3				; (2-x)_h

	lea		rcx,atan_n_2_8_c
	subsd	xmm11,xmm15				; (2-x)_l

	mulsd	xmm0,xmm2				; y=(2-x)*(1/(1+0.5x))

	movsd	xmm4,xmm0				; y
	mulsd	xmm0,xmm0				; y2

	movlpd	xmm5,qword ptr (atan_n_2_8_1-atan_n_2_8_c)[rcx]

	movsd	xmm6,xmm0				; y2
	mulsd	xmm0,xmm0				; y4

	movsd	xmm14,xmm6				; y2
	mulsd	xmm5,xmm6				; p2

	movlpd	xmm8,qword ptr real_27_bits

	mulsd	xmm6,xmm0				; y6

	movlpd	xmm9,qword ptr (atan_n_2_8_2-atan_n_2_8_c)[rcx]

	movsd	xmm10,xmm0				; y4
	mulsd	xmm0,xmm0				; y8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm12,qword ptr (atan_n_2_8_4-atan_n_2_8_c)[rcx]

	mulsd	xmm10,xmm6				; y10

	movsd	xmm7,xmm6				; x6
	mulsd	xmm6,xmm6				; x12

	mulsd	xmm12,xmm0				; p8
	mulsd	xmm0,xmm7				; x14

	andpd	xmm8,xmm4				; y_h

	mulsd	xmm7,qword ptr (atan_n_2_8_3-atan_n_2_8_c)[rcx] ; p6
	mulsd	xmm10,qword ptr (atan_n_2_8_5-atan_n_2_8_c)[rcx] ; p10
	mulsd	xmm6,qword ptr (atan_n_2_8_6-atan_n_2_8_c)[rcx] ; p12
	mulsd	xmm0,qword ptr (atan_n_2_8_7-atan_n_2_8_c)[rcx] ; p14

	movlpd	xmm13,qword ptr real_4_0
	movlpd	xmm1,qword ptr (atan_2_0_real_2_0-atan_2_0)[rdx]
	mulsd	xmm13,xmm8				; 4*y_h
	mulsd	xmm1,xmm8				; 2*y_h

	addsd	xmm0,xmm6				; p14+p12

	subsd	xmm3,xmm13				; (2-x)-4*y_h
	mulsd	xmm15,xmm1				; (2-x)_h*2*y_h
	mulsd	xmm11,xmm1				; (2-x)_l*2*y_h
	subsd	xmm3,xmm8				; (2-x)-y_h

	addsd	xmm0,xmm10				; p14+p12+p10

	addsd	xmm3,xmm15				; (2-x)-5*y_h+(2-x)_h*2*y_h

	addsd	xmm0,xmm12				; p14+p12+p10+p8

	addsd	xmm3,xmm11				; (2-x)-5*y_h+(2-x)_h*2*y_h+(2-x)_l*2*y_h

	addsd	xmm0,xmm7				; p14+p12+p10+p8+p6

	mulsd	xmm14,xmm4				; y3

	mulsd	xmm3,xmm2				; c=((2-x)-5*y_h-(2-x)_h*2*y_h-(2-x)_l*2*y_h)*(1/(1+0.5x))

	addsd	xmm0,xmm9				; p14+p12+p10+p8+p6+p4

	movsd	xmm11,xmm8				; y_h
	addsd	xmm8,xmm3				; y_h+c

	addsd	xmm0,xmm5				; p14+p12+p10+p8+p6+p4+p2

	movlpd	xmm7,qword ptr real_39_bits
	movlpd	xmm12,qword ptr real_abs_39_bits
	andpd	xmm7,xmm8
	andpd	xmm12,xmm8				; (y_h+c)_h

	addsd	xmm0,qword ptr (atan_n_2_8_0-atan_n_2_8_c)[rcx] ; p14+p12+p10+p8+p6+p4+p2+p0

	subsd	xmm11,xmm7				; y_h-(y_h+c)_h
	addsd	xmm3,xmm11				; (y_h-(y_h+c)_h)+c
	
	mulsd	xmm0,xmm14				; y3*p/q

	movlpd	xmm2,qword ptr (atan_2_0_l-atan_2_0)[rdx]
	subsd	xmm2,xmm0				; atan_2_0_l-y3*p/q
	movlpd	xmm0,qword ptr (atan_2_0-atan_2_0)[rdx]

	ucomisd	xmm12,qword ptr real_2_p_m_11
	jb		atan_real_3_s

	subsd	xmm0,xmm7				; atan_2_0-(y_h+c)_h
	subsd	xmm2,xmm3				; atan_2_0_l-y3*p/q-(y_h+c)_l
	addsd	xmm0,xmm2				; atan 2_0-y3*p/q-(2-x)/(1+x)

	ret

atan_real_3_s:
	subsd	xmm2,xmm3				; atan_2_0_l-y3*p/q-(y_h+c)_l
	subsd	xmm2,xmm7				; atan_2_0_l-y3*p/q-(y_h+c)_l-(y_h+c)_h
	addsd	xmm0,xmm2				; atan 2_0-y3*p/q-(1-x)/(1+x)
	ret

atan_real_4n:
	ucomisd	xmm0,qword ptr real_atan_m_large
	jb		atan_real_m_large_or_nan ; x<-5805358775541310.0840 | NAN

	movlpd	xmm2,qword ptr real_1_0
	mulsd	xmm0,xmm0				; x2

	lea		rdx,real_m_pi_d_2

	jmp		atan_real_4pn

atan_real_4:
	ucomisd	xmm0,qword ptr real_atan_large
	ja		atan_real_large			; x>5805358775541310.0840

	movlpd	xmm2,qword ptr real_1_0
	mulsd	xmm0,xmm0				; x2

	lea		rdx,real_pi_d_2

atan_real_4pn:
	divsd	xmm2,xmm1				; 1/x

	lea		rcx,atan4_p_c

	movlpd	xmm4,qword ptr (atan4_q_4-atan4_p_c)[rcx]
	movlpd	xmm3,qword ptr (atan4_p_3-atan4_p_c)[rcx]

	movsd	xmm5,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm4,xmm5				; q2
	mulsd	xmm3,xmm5				; p2

	movlpd	xmm9,qword ptr (atan4_q_3-atan4_p_c)[rcx]
	movlpd	xmm8,qword ptr (atan4_p_2-atan4_p_c)[rcx]

	movsd	xmm6,xmm0				; x4
	mulsd	xmm0,xmm5				; x6

	mulsd	xmm9,xmm6				; q4
	mulsd	xmm8,xmm6				; p4

	movlpd	xmm11,qword ptr (atan4_q_2-atan4_p_c)[rcx]
	movlpd	xmm10,qword ptr (atan4_p_1-atan4_p_c)[rcx]

	addsd	xmm4,qword ptr real_1_0	; 1+q2
	addsd	xmm3,qword ptr (atan4_p_4-atan4_p_c)[rcx] ; p0+p2
	
	movsd	xmm7,xmm6				; x4
	mulsd	xmm6,xmm6				; x8

	mulsd	xmm11,xmm0				; q6
	mulsd	xmm10,xmm0				; p6

	addsd	xmm4,xmm9				; 1+q2+q4
	addsd	xmm3,xmm8				; p0+p2+p4

	mulsd	xmm0,xmm7				; x10

	movlpd	xmm9,qword ptr (atan4_q_1-atan4_p_c)[rcx]
	movlpd	xmm8,qword ptr (atan4_p_0-atan4_p_c)[rcx]

	addsd	xmm4,xmm11				; 1+q2+q4+q6
	addsd	xmm3,xmm10				; p0+p2+p4+p6

	mulsd	xmm9,xmm6				; q8
	mulsd	xmm8,xmm6				; p8

	mulsd	xmm0,qword ptr (atan4_q_0-atan4_p_c)[rcx]; q10

	movlpd	xmm5,qword ptr real_26_bits
	movsd	xmm6,xmm1				; x
	movlpd	xmm7,qword ptr real_26_bits
	andpd	xmm5,xmm1				; x_h
	subsd	xmm6,xmm5				; x_l
	andpd	xmm7,xmm2				; (1/x)_h

	addsd	xmm4,xmm9				; 1+q2+q4+q6+q8
	addsd	xmm3,xmm8				; p0+p2+p4+p6+p8

	movlpd	xmm8,qword ptr real_1_0	
	mulsd	xmm5,xmm7				; x_h*(1/x)_h
	mulsd	xmm6,xmm7				; x_l*(1/x)_h

	addsd	xmm4,xmm0				; 1+q2+q4+q6+q8+q10

	subsd	xmm8,xmm5				; 1-x_h*(1/x)_h
	
	subsd	xmm8,xmm6				; 1-x_h*(1/x)_h-x_l*(1/x)_h

	mulsd	xmm8,xmm2				; (1-x_h*(1/x)_h-x_l*(1/x)_h)*(1/x)

	divsd	xmm3,xmm4				; p/q

	movlpd	xmm1,qword ptr (real_pi_d_2_l-real_pi_d_2)[rdx]
	movlpd	xmm0,qword ptr (real_pi_d_2-real_pi_d_2)[rdx]

	mulsd	xmm3,xmm2				; (p/q)*(1/x)

	subsd	xmm1,xmm3				; pi_d_2_l-(p/q)*(1/x)
	subsd	xmm0,xmm7				; pi_d_2-(1/x)_h
	subsd	xmm1,xmm8				; pi_d_2_l-(p/q)*(1/x)-(1/x)_l
	addsd	xmm0,xmm1
	ret

atan_real_4poly:
	movlpd	xmm3,qword ptr real_1_0
	divsd	xmm3,xmm0				; 1/x

	movlpd	xmm5,qword ptr real_26_bits
	movsd	xmm6,xmm0				; x
	movlpd	xmm7,qword ptr real_26_bits
	andpd	xmm5,xmm0				; x_h

	subsd	xmm6,xmm5				; x_l

	movsd	xmm15,xmm3				; x
	mulsd	xmm3,xmm3				; x2

	movlpd	xmm1,qword ptr atan_p_9_1
	
	movsd	xmm11,xmm3				; x2
	mulsd	xmm3,xmm3				; x4

	movsd	xmm14,xmm11				; x2
	mulsd	xmm1,xmm11				; p2

	mulsd	xmm11,xmm3				; x6

	movlpd	xmm9,qword ptr atan_p_9_2

	movsd	xmm10,xmm3				; x4
	mulsd	xmm3,xmm3				; x8

	mulsd	xmm9,xmm10				; p4

	movlpd	xmm4,qword ptr atan_p_9_3
	movlpd	xmm12,qword ptr atan_p_9_4

	mulsd	xmm10,xmm11				; x10

	movsd	xmm2,xmm11				; x6
	mulsd	xmm4,xmm11				; p6
	mulsd	xmm11,xmm11				; x12

	mulsd	xmm2,xmm3				; x14
	mulsd	xmm12,xmm3				; p8
	mulsd	xmm3,xmm3				; x16

	mulsd	xmm10,qword ptr atan_p_9_5 ; p10
	mulsd	xmm11,qword ptr atan_p_9_6 ; p12
	mulsd	xmm2,qword ptr atan_p_9_7 ; p14
	mulsd	xmm3,qword ptr atan_p_9_8 ; p16

	addsd	xmm3,xmm2				; p16+p14
	addsd	xmm3,xmm11				; p16+p14+p12
	addsd	xmm3,xmm10				; p16+p14+p12+p10

	andpd	xmm7,xmm15				; (1/x)_h

	addsd	xmm3,xmm12				; p16+p14+p12+p10+p8

	movlpd	xmm8,qword ptr real_1_0	
	mulsd	xmm5,xmm7				; x_h*(1/x)_h
	mulsd	xmm6,xmm7				; x_l*(1/x)_h

	addsd	xmm3,xmm4				; p16+p14+p12+p10+p8+p6	

	mulsd	xmm14,xmm15				; x3

	subsd	xmm8,xmm5				; 1-x_h*(1/x)_h

	addsd	xmm3,xmm9				; p16+p14+p12+p10+p8+p6+p4
	
	subsd	xmm8,xmm6				; 1-x_h*(1/x)_h-x_l*(1/x)_h

	addsd	xmm3,xmm1				; p16+p14+p12+p10+p8+p6+p4+p2

	mulsd	xmm8,xmm15				; (1-x_h*(1/x)_h-x_l*(1/x)_h)*(1/x)

	addsd	xmm3,qword ptr atan_p_9_0 ; p16+p14+p12+p10+p8+p6+p4+p2+p0

	movlpd	xmm1,qword ptr real_pi_d_2_l
	movlpd	xmm0,qword ptr real_pi_d_2

	mulsd	xmm3,xmm14				; x3*p

	subsd	xmm1,xmm3				; pi_d_2_l-(p/q)*(1/x)
	subsd	xmm0,xmm7				; pi_d_2-(1/x)_h
	subsd	xmm1,xmm8				; pi_d_2_l-(p/q)*(1/x)-(1/x)_l
	addsd	xmm0,xmm1
	ret

atan_real_m_large_or_nan:
	jp		atan_real_nan

	movlpd	xmm0,qword ptr real_m_pi_d_2
	ret

atan_real_nan:
	addsd	xmm0,xmm0
	ret

atan_real_large:
	movlpd	xmm0,qword ptr real_pi_d_2
	ret

_T005	ends

_T006	segment para 'CODE'

	public	exp_real

exp_real:
	ucomisd	xmm0,qword ptr real_ln_2_t_0_5
	ja	exp_real_2				; x>0.3.4657359027997265471

	ucomisd	xmm0,qword ptr real_n_ln_2_t_0_5
	jb	exp_real_3_n			; x<-0.34657359027997265471 | nan

	movlpd	xmm1,qword ptr n_45_d_256
	movlpd	xmm2,qword ptr n_m_45_d_256

	ucomisd	xmm0,xmm1
	ja	exp_real_p1

	ucomisd	xmm0,xmm2
	jb	exp_real_n1

	ucomisd	xmm0,qword ptr real_0_0

	lea	rcx,exp_p0_c
	lea	rdx,exp_m0_c

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	cmovb	rcx,rdx

	movlpd	xmm6,qword ptr (exp_p0_2-exp_p0_c)[rcx]
	movlpd	xmm7,qword ptr (exp_p0_4-exp_p0_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm6,xmm2				; p2

	movsd	xmm3,xmm1				; x
	mulsd	xmm1,xmm2				; x3

	movlpd	xmm8,qword ptr (exp_p0_3-exp_p0_c)[rcx]
	mulsd	xmm7,xmm0				; p4
	
	mulsd	xmm8,xmm1				; p3

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movsd	xmm5,xmm2				; x2
	mulsd	xmm2,xmm1				; x5	

	mulsd	xmm5,xmm4				; x6
	mulsd	xmm1,xmm4				; x7
	mulsd	xmm4,xmm2				; x9

	mulsd	xmm0,qword ptr (exp_p0_8-exp_p0_c)[rcx] ; p8
	mulsd	xmm2,qword ptr (exp_p0_5-exp_p0_c)[rcx]	; p5
	mulsd	xmm5,qword ptr (exp_p0_6-exp_p0_c)[rcx]	; p6
	mulsd	xmm1,qword ptr (exp_p0_7-exp_p0_c)[rcx]	; p7
	mulsd	xmm4,qword ptr (exp_p0_9-exp_p0_c)[rcx]	; p9

	addsd	xmm0,xmm4				; p9+p8

	movlpd	xmm9,qword ptr real_26_bits
	movlpd	xmm10,qword ptr real_1_0

	addsd	xmm0,xmm1				; p9+p8+p7
	addsd	xmm0,xmm5				; p9+p8+p7+p6

	andpd	xmm9,xmm3				; x_h

	addsd	xmm0,xmm2				; p9+p8+p7+p6+p5

	addsd	xmm9,xmm10				; 1+x_h

	addsd	xmm0,xmm7				; p9+p8+p7+p6+p5+p4

	subsd	xmm10,xmm9				; 1-(1+x_h)

	addsd	xmm0,xmm8				; p9+p8+p7+p6+p5+p4+p3

	addsd	xmm10,xmm3				; (1-(1+x_h))+x

	addsd	xmm0,xmm6				; p9+p8+p7+p6+p5+p4+p3+p2

	addsd	xmm0,xmm10
	addsd	xmm0,xmm9
	ret

exp_real_n1:
	subsd	xmm0,xmm2

	lea		rcx,exp_m1_c
	jmp		exp_real_np1

exp_real_p1:
	subsd	xmm0,xmm1

	lea		rcx,exp_p1_c

exp_real_np1:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm6,qword ptr (exp_p1_2-exp_p1_c)[rcx]
	movlpd	xmm7,qword ptr (exp_p1_4-exp_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm6,xmm2				; p2

	movsd	xmm3,xmm1				; x
	mulsd	xmm1,xmm2				; x3

	movlpd	xmm8,qword ptr (exp_p1_3-exp_p1_c)[rcx]
	mulsd	xmm7,xmm0				; p4
	
	mulsd	xmm8,xmm1				; p3

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movsd	xmm5,xmm2				; x2
	mulsd	xmm2,xmm1				; x5	

	mulsd	xmm5,xmm4				; x6
	mulsd	xmm1,xmm4				; x7
	mulsd	xmm4,xmm2				; x9

	mulsd	xmm0,qword ptr (exp_p1_8-exp_p1_c)[rcx] ; p8
	mulsd	xmm2,qword ptr (exp_p1_5-exp_p1_c)[rcx]	; p5
	mulsd	xmm5,qword ptr (exp_p1_6-exp_p1_c)[rcx]	; p6
	mulsd	xmm1,qword ptr (exp_p1_7-exp_p1_c)[rcx]	; p7
	mulsd	xmm4,qword ptr (exp_p1_9-exp_p1_c)[rcx]	; p9

	addsd	xmm0,xmm4				; p9+p8

	movlpd	xmm9,qword ptr real_26_bits

	addsd	xmm0,xmm1				; p9+p8+p7

	movsd	xmm11,xmm3				; x
	andpd	xmm9,xmm3				; x_h
	mulsd	xmm3,qword ptr (exp_p1_1_l-exp_p1_c)[rcx] ; x*c1_l

	addsd	xmm0,xmm5				; p9+p8+p7+p6

	subsd	xmm11,xmm9				; x_l
	mulsd	xmm9,qword ptr (exp_p1_1_h-exp_p1_c)[rcx] ; x_h*c1_h

	addsd	xmm0,xmm2				; p9+p8+p7+p6+p5
	
	movlpd	xmm10,qword ptr (exp_p1_0-exp_p1_c)[rcx]
	mulsd	xmm11,qword ptr (exp_p1_1_h-exp_p1_c)[rcx] ; x_l*c1_h
	addsd	xmm10,xmm9				; x_h*c1_h+c0
	movlpd	xmm12,qword ptr (exp_p1_0-exp_p1_c)[rcx]

	addsd	xmm0,xmm7				; p9+p8+p7+p6+p5+p4

	addsd	xmm3,xmm11				; x*c1_l+x_l*c1_h
	subsd	xmm12,xmm10				; c0-(x_h*c1_h+c0)

	addsd	xmm0,xmm8				; p9+p8+p7+p6+p5+p4+p3

	addsd	xmm12,xmm9				; (c0-(x_h*c1_h+c0))+x_h*c1_h

	addsd	xmm0,xmm6				; p9+p8+p7+p6+p5+p4+p3+p2

	addsd	xmm3,xmm12				; (c0-(x_h*c1_h+c0))+x_h*c1_h+x*c1_l+x_l*c1_h

	addsd	xmm0,qword ptr (exp_p1_0_l-exp_p1_c)[rcx]

	addsd	xmm0,xmm3
	addsd	xmm0,xmm10
	ret

exp_real_2:
	ucomisd	xmm0,qword ptr real_ln_2_t_1_5
	ja		exp_real_3

	subsd	xmm0,qword ptr real_ln2_42
	movlpd	xmm14,qword ptr real_ln2_42_l

	movsd	xmm13,xmm0
	subsd	xmm0,xmm14

	movlpd	xmm15,qword ptr real_2_0

exp_real_:
	movlpd	xmm1,qword ptr n_45_d_256
	movlpd	xmm2,qword ptr n_m_45_d_256

	ucomisd	xmm0,xmm1
	ja		exp_real_p1_

	ucomisd	xmm0,xmm2
	jb		exp_real_n1_

	ucomisd	xmm0,qword ptr real_0_0

	lea		rcx,exp_p0_c
	lea		rdx,exp_m0_c

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	cmovb	rcx,rdx

	movlpd	xmm6,qword ptr (exp_p0_2-exp_p0_c)[rcx]
	movlpd	xmm7,qword ptr (exp_p0_4-exp_p0_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm6,xmm2				; p2

	movsd	xmm3,xmm1				; x
	mulsd	xmm1,xmm2				; x3

	movlpd	xmm8,qword ptr (exp_p0_3-exp_p0_c)[rcx]
	mulsd	xmm7,xmm0				; p4
	
	mulsd	xmm8,xmm1				; p3

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movsd	xmm5,xmm2				; x2
	mulsd	xmm2,xmm1				; x5	

	mulsd	xmm5,xmm4				; x6
	mulsd	xmm1,xmm4				; x7
	mulsd	xmm4,xmm2				; x9

	mulsd	xmm0,qword ptr (exp_p0_8-exp_p0_c)[rcx] ; p8
	mulsd	xmm2,qword ptr (exp_p0_5-exp_p0_c)[rcx]	; p5
	mulsd	xmm5,qword ptr (exp_p0_6-exp_p0_c)[rcx]	; p6
	mulsd	xmm1,qword ptr (exp_p0_7-exp_p0_c)[rcx]	; p7
	mulsd	xmm4,qword ptr (exp_p0_9-exp_p0_c)[rcx]	; p9

	addsd	xmm0,xmm4				; p9+p8

	movlpd	xmm9,qword ptr real_26_bits
	movlpd	xmm10,qword ptr real_1_0

	addsd	xmm0,xmm1				; p9+p8+p7

	andpd	xmm9,xmm3				; x_h

	addsd	xmm0,xmm5				; p9+p8+p7+p6

	addsd	xmm9,xmm10				; 1+x_h

	addsd	xmm0,xmm2				; p9+p8+p7+p6+p5

	subsd	xmm10,xmm9				; 1-(1+x_h)

	addsd	xmm0,xmm7				; p9+p8+p7+p6+p5+p4

	addsd	xmm10,xmm13				; (1-(1+x_h))+xh

	addsd	xmm0,xmm8				; p9+p8+p7+p6+p5+p4+p3

	subsd	xmm10,xmm14				; (1-(1+x_h))+xh-nxl

	addsd	xmm0,xmm6				; p9+p8+p7+p6+p5+p4+p3+p2

	addsd	xmm0,xmm10
	addsd	xmm0,xmm9

	mulsd	xmm0,xmm15
	ret

exp_real_n1_:
	subsd	xmm0,xmm2
	subsd	xmm13,xmm2

	lea		rcx,exp_m1_c
	jmp		exp_real_np1_

exp_real_p1_:
	subsd	xmm0,xmm1
	subsd	xmm13,xmm1

	lea		rcx,exp_p1_c

exp_real_np1_:
	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm6,qword ptr (exp_p1_2-exp_p1_c)[rcx]
	movlpd	xmm7,qword ptr (exp_p1_4-exp_p1_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm6,xmm2				; p2

	movsd	xmm3,xmm1				; x
	mulsd	xmm1,xmm2				; x3

	movlpd	xmm8,qword ptr (exp_p1_3-exp_p1_c)[rcx]
	mulsd	xmm7,xmm0				; p4
	
	mulsd	xmm8,xmm1				; p3

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movsd	xmm5,xmm2				; x2
	mulsd	xmm2,xmm1				; x5	

	mulsd	xmm5,xmm4				; x6
	mulsd	xmm1,xmm4				; x7
	mulsd	xmm4,xmm2				; x9

	mulsd	xmm0,qword ptr (exp_p1_8-exp_p1_c)[rcx] ; p8
	mulsd	xmm2,qword ptr (exp_p1_5-exp_p1_c)[rcx]	; p5
	mulsd	xmm5,qword ptr (exp_p1_6-exp_p1_c)[rcx]	; p6
	mulsd	xmm1,qword ptr (exp_p1_7-exp_p1_c)[rcx]	; p7
	mulsd	xmm4,qword ptr (exp_p1_9-exp_p1_c)[rcx]	; p9

	movlpd	xmm9,qword ptr real_26_bits

	addsd	xmm0,xmm4				; p9+p8

	movsd	xmm11,xmm13				; xh
	andpd	xmm9,xmm3				; x_h
	mulsd	xmm3,qword ptr (exp_p1_1_l-exp_p1_c)[rcx] ; x*c1_l

	addsd	xmm0,xmm1				; p9+p8+p7

	subsd	xmm11,xmm9				; xh-x_h

	addsd	xmm0,xmm5				; p9+p8+p7+p6

	subsd	xmm11,xmm14				; x_l=(xh-x_h)-nxl

	mulsd	xmm9,qword ptr (exp_p1_1_h-exp_p1_c)[rcx] ; x_h*c1_h

	addsd	xmm0,xmm2				; p9+p8+p7+p6+p5
	
	movlpd	xmm10,qword ptr (exp_p1_0-exp_p1_c)[rcx]
	mulsd	xmm11,qword ptr (exp_p1_1_h-exp_p1_c)[rcx] ; x_l*c1_h
	addsd	xmm10,xmm9				; x_h*c1_h+c0
	movlpd	xmm12,qword ptr (exp_p1_0-exp_p1_c)[rcx]

	addsd	xmm0,xmm7				; p9+p8+p7+p6+p5+p4

	addsd	xmm3,xmm11				; x*c1_l+x_l*c1_h
	subsd	xmm12,xmm10				; c0-(x_h*c1_h+c0)

	addsd	xmm0,xmm8				; p9+p8+p7+p6+p5+p4+p3

	addsd	xmm12,xmm9				; (c0-(x_h*c1_h+c0))+x_h*c1_h

	addsd	xmm0,xmm6				; p9+p8+p7+p6+p5+p4+p3+p2

	addsd	xmm3,xmm12				; (c0-(x_h*c1_h+c0))+x_h*c1_h+x*c1_l+x_l*c1_h

	addsd	xmm0,qword ptr (exp_p1_0_l-exp_p1_c)[rcx]

	addsd	xmm0,xmm3
	addsd	xmm0,xmm10

	mulsd	xmm0,xmm15
	ret

exp_real_3_n:
	movlpd	xmm1,qword ptr real_1_d_ln2
	mulsd	xmm1,xmm0
	movq	xmm4,qword ptr m_round_c
	subsd	xmm1,qword ptr real_0_5

	ucomisd	xmm1,qword ptr real_m_1022
	jae		exp_real_3_pn

	ucomisd	xmm1,qword ptr real_m_1076
	jb		exp_real_3_n_large

	movq	xmm9,qword ptr qw_1078

	call	exp_real_3_pn_

	mulsd	xmm0,qword ptr real_2_p_m_55
	ret

exp_real_3:
	movlpd	xmm1,qword ptr real_1_d_ln2
	mulsd	xmm1,xmm0
	movq	xmm4,qword ptr round_c
	addsd	xmm1,qword ptr real_0_5

	ucomisd	xmm1,qword ptr real_1024
	jae	exp_real_3_large

exp_real_3_pn:
	movq	xmm9,qword ptr qw_1023

exp_real_3_pn_:
	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1
	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2

	movlpd	xmm13,qword ptr real_ln2_42
	movlpd	xmm14,qword ptr real_ln2_42_l

	mulsd	xmm13,xmm1
	mulsd	xmm14,xmm1

	cvtpd2dq xmm15,xmm1
	subsd	xmm0,xmm13

	movsd	xmm13,xmm0
	subsd	xmm0,xmm14

	paddq	xmm15,xmm9
	psllq	xmm15,52
	jmp		exp_real_

exp_real_3_large:
	ucomisd	xmm1,qword ptr real_1025
	jae		exp_real_3_larger

	movq	xmm9,qword ptr qw_1022

	call	exp_real_3_pn_

	mulsd	xmm0,qword ptr real_2_0
	ret

exp_real_3_larger:
	ucomisd	xmm0,qword ptr real_max
	ja		exp_real_3_inf_or_nan
	movlpd	xmm0,qword ptr qword ptr real_2_p_1023
	mulsd	xmm0,xmm0
exp_real_3_inf_or_nan:
	ret

exp_real_3_n_large:
	jp		exp_real_3_inf_or_nan	; nan
	movlpd	xmm0,qword ptr real_0_0
	ret

_T006	ends

_T007	segment para 'CODE'

	public	ln_real

ln_real:
	ucomisd	xmm0,qword ptr real_0_8243
	jb		ln_real_small			; x<0.82436063535006407342 | nan
	ucomisd	xmm0,qword ptr real_1_6487
	ja		ln_real_large			; x>1.6487212707001281468
	movlpd	xmm2,qword ptr real_1_0

	ucomisd	xmm0,qword ptr real_7_d_6
	ja		ln_real_a_7_d_6

	ucomisd	xmm0,xmm2

	subsd	xmm0,xmm2

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	jae		ln_real_0
	jmp		ln_real_s

ln_real_small:
	ucomisd	xmm0,qword ptr real_2_p_m_1022
	jae		ln_real_

	ucomisd	xmm0,qword ptr real_0_0
	jbe		ln_real_less_or_equal_0_or_nan

; denormalized number

	mulsd	xmm0,qword ptr real_2_p_55

	movlpd	xmm1,qword ptr mask_significand
	andpd	xmm1,xmm0
	psrlq	xmm0,52

	movlpd	xmm2,qword ptr real_1_0
	movlpd	xmm3,qword ptr real_0_5
	orpd	xmm2,xmm1
	orpd	xmm3,xmm1

	ucomisd	xmm2,qword ptr real_1_6487
	jbe		ln_real_dn_g1

	subsd	xmm3,qword ptr real_1_0
	psubq	xmm0,qword ptr qw_1077
	jmp		ln_real_l1_

ln_real_dn_g1:
	ucomisd	xmm2,qword ptr real_7_d_6

	subsd	xmm2,qword ptr real_1_0
	psubq	xmm0,qword ptr qw_1078

	ja		ln_real_g_7_d_6
	jmp		ln_real_g1_

ln_real_large:
	ucomisd	xmm0,qword ptr real_max
	ja		ln_real_inf_or_nan

ln_real_:
	movlpd	xmm1,qword ptr mask_significand
	andpd	xmm1,xmm0
	psrlq	xmm0,52

	movlpd	xmm2,qword ptr real_1_0
	movlpd	xmm3,qword ptr real_0_5
	orpd	xmm2,xmm1
	orpd	xmm3,xmm1

	ucomisd	xmm2,qword ptr real_1_6487
	jbe		ln_real_g1
	jmp		ln_real_l1

ln_real_0:
	movlpd	xmm3,qword ptr ln_b_q_1
	movlpd	xmm2,qword ptr ln_b_p_1

	mulsd	xmm3,xmm1				; q1
	mulsd	xmm2,xmm1				; p1
	movsd	xmm7,xmm1				; x
	movlpd	xmm5,qword ptr ln_b_q_2
	movlpd	xmm4,qword ptr ln_b_p_2
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movsd	xmm11,xmm1				; x
	mulsd	xmm7,xmm6				; x3

	movlpd	xmm9,qword ptr ln_b_q_3
	movlpd	xmm8,qword ptr ln_b_p_3

	mulsd	xmm11,xmm0				; x5

	mulsd	xmm5,xmm6				; q2
	mulsd	xmm4,xmm6				; p2

	movlpd	xmm10,qword ptr ln_b_q_4

	mulsd	xmm9,xmm7				; q3
	mulsd	xmm8,xmm7				; p3
	
	mulsd	xmm10,xmm0				; q4
	mulsd	xmm0,qword ptr ln_b_p_4	; p4

	addsd	xmm10,xmm11				; q4+x5

	addsd	xmm0,xmm8				; p3+p4
	addsd	xmm9,xmm10				; q3+q4+x5

	movlpd	xmm6,qword ptr real_17_bits

	addsd	xmm0,xmm4				; p2+p3+p4	
	addsd	xmm5,xmm9				; q2+q3+q4+x5

	andpd	xmm6,xmm1				; x_17_h
	movsd	xmm8,xmm1				; x
	movlpd	xmm4,qword ptr real_0_5

	addsd	xmm0,xmm2				; p1+p2+p3+p4
	addsd	xmm3,xmm5				; q1+q2+q3+q4+x5

	subsd	xmm8,xmm6				; x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h

	addsd	xmm0,qword ptr ln_b_p_0	; p0+p1+p2+p3+p4
	addsd	xmm3,qword ptr ln_b_q_0	; q0+q1+q2+q3+q4+x5

	mulsd	xmm8,qword ptr real_0_5	; 0.5*x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h*x_17_h
	addsd	xmm6,xmm1				; x+x_17_h

	ucomisd	xmm1,qword ptr real_2_p_m_16
	jb		ln_real_0_s

	divsd	xmm0,xmm3				; p/q

	subsd	xmm1,xmm4				; x-0.5*x_17_h*x_17_h
	mulsd	xmm6,xmm8				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm0,xmm7				; (p/q)*x3
	subsd	xmm0,xmm6				; (p/q)*x3-0.5x2_l
	addsd	xmm0,xmm1				; (p/q)*x3-0.5x2+x
	ret

ln_real_0_s:
	divsd	xmm0,xmm3				; p/q

	mulsd	xmm6,xmm8				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm0,xmm7				; (p/q)*x3
	subsd	xmm0,xmm6				; (p/q)*x3-0.5x2_l
	subsd	xmm0,xmm4				; (p/q)*x3-0.5x2
	addsd	xmm0,xmm1				; (p/q)*x3-0.5x2+x
	ret

ln_real_a_7_d_6:
	subsd	xmm0,xmm2

	mulsd	xmm0,qword ptr real_0_75
	movlpd	xmm1,qword ptr real_0_25

	lea		rcx,ln_b_c
	lea		rdx,ln_s_c

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	cmovb	rcx,rdx

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm3,qword ptr (ln_b_q_1-ln_b_c)[rcx]
	movlpd	xmm2,qword ptr (ln_b_p_1-ln_b_c)[rcx]

	mulsd	xmm3,xmm1				; q1
	mulsd	xmm2,xmm1				; p1
	movsd	xmm7,xmm1				; x
	movlpd	xmm5,qword ptr (ln_b_q_2-ln_b_c)[rcx]
	movlpd	xmm4,qword ptr (ln_b_p_2-ln_b_c)[rcx]
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movsd	xmm11,xmm1				; x
	mulsd	xmm7,xmm6				; x3

	movlpd	xmm9,qword ptr (ln_b_q_3-ln_b_c)[rcx]
	movlpd	xmm8,qword ptr (ln_b_p_3-ln_b_c)[rcx]

	mulsd	xmm11,xmm0				; x5

	mulsd	xmm5,xmm6				; q2
	mulsd	xmm4,xmm6				; p2

	movlpd	xmm6,qword ptr real_17_bits
	movlpd	xmm10,qword ptr (ln_b_q_4-ln_b_c)[rcx]

	mulsd	xmm9,xmm7				; q3
	mulsd	xmm8,xmm7				; p3
	
	andpd	xmm6,xmm1				; x_17_h

	mulsd	xmm10,xmm0				; q4
	mulsd	xmm0,qword ptr (ln_b_p_4-ln_b_c)[rcx] ; p4

	addsd	xmm10,xmm11				; q4+x5

	addsd	xmm0,xmm8				; p3+p4
	addsd	xmm9,xmm10				; q3+q4+x5

	movsd	xmm8,xmm1				; x

	addsd	xmm0,xmm4				; p2+p3+p4	
	addsd	xmm5,xmm9				; q2+q3+q4+x5

	movlpd	xmm4,qword ptr real_0_5
	subsd	xmm8,xmm6				; x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h

	addsd	xmm0,xmm2				; p1+p2+p3+p4
	addsd	xmm3,xmm5				; q1+q2+q3+q4+x5

	mulsd	xmm8,qword ptr real_0_5	; 0.5*x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h*x_17_h
	addsd	xmm6,xmm1				; x+x_17_h

	addsd	xmm0,qword ptr (ln_b_p_0-ln_b_c)[rcx] ; p0+p1+p2+p3+p4
	addsd	xmm3,qword ptr (ln_b_q_0-ln_b_c)[rcx] ; q0+q1+q2+q3+q4+x5

	subsd	xmm1,xmm4				; x-0.5*x_17_h*x_17_h
	mulsd	xmm6,xmm8				; 0.5*x_17_l*(x+x_17_h)

	divsd	xmm0,xmm3				; p/q

	movlpd	xmm2,qword ptr ln_4_d_3_53
	movlpd	xmm4,qword ptr ln_4_d_3_53_l
	addsd	xmm2,xmm1
	subsd	xmm4,xmm6

	movlpd	xmm3,qword ptr ln_4_d_3_53
	subsd	xmm3,xmm2

	mulsd	xmm0,xmm7				; (p/q)*x3

	addsd	xmm3,xmm1
	addsd	xmm3,xmm4

	addsd	xmm0,xmm3
	addsd	xmm0,xmm2
	ret

ln_real_g1:
	ucomisd	xmm2,qword ptr real_7_d_6

	subsd	xmm2,qword ptr real_1_0

	psubq	xmm0,qword ptr qw_1023

	ja		ln_real_g_7_d_6

ln_real_g1_:
	movsd	xmm1,xmm2				; x
	mulsd	xmm2,xmm2				; x2

	movlpd	xmm4,qword ptr ln_b_q_1
	movlpd	xmm3,qword ptr ln_b_p_1
	mulsd	xmm4,xmm1				; q1
	mulsd	xmm3,xmm1				; p1
	movsd	xmm8,xmm1				; x

	cvtdq2pd xmm0,xmm0

	movlpd	xmm6,qword ptr ln_b_q_2
	movlpd	xmm5,qword ptr ln_b_p_2
	movsd	xmm7,xmm2				; x2
	mulsd	xmm2,xmm2				; x4

	movsd	xmm12,xmm1				; x
	mulsd	xmm8,xmm7				; x3

	movlpd	xmm10,qword ptr ln_b_q_3
	movlpd	xmm9,qword ptr ln_b_p_3

	mulsd	xmm12,xmm2				; x5

	mulsd	xmm6,xmm7				; q2
	mulsd	xmm5,xmm7				; p2

	movlpd	xmm11,qword ptr ln_b_p_4

	mulsd	xmm10,xmm8				; q3
	mulsd	xmm9,xmm8				; p3
	
	mulsd	xmm11,xmm2				; p4
	mulsd	xmm2,qword ptr ln_b_q_4 ; q4
	
	addsd	xmm2,xmm12				; q4+x5

	addsd	xmm2,xmm10				; q3+q4+x5
	addsd	xmm9,xmm11				; p3+p4

	movlpd	xmm7,qword ptr real_17_bits

	addsd	xmm2,xmm6				; q2+q3+q4+x5
	addsd	xmm5,xmm9				; p2+p3+p4
	
	andpd	xmm7,xmm1				; x_17_h
	movsd	xmm14,xmm1				; x
	movlpd	xmm13,qword ptr real_0_5

	movlpd	xmm6,qword ptr real_ln2_42_l
	
	addsd	xmm2,xmm4				; q1+q2+q3+q4+x5
	addsd	xmm3,xmm5				; p1+p2+p3+p4
	
	subsd	xmm14,xmm7				; x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h

	mulsd	xmm6,xmm0
	mulsd	xmm0,qword ptr real_ln2_42
	
	addsd	xmm2,qword ptr ln_b_q_0	; q0+q1+q2+q3+q4+x5
	addsd	xmm3,qword ptr ln_b_p_0	; p0+p1+p2+p3+p4

	mulsd	xmm14,qword ptr real_0_5; 0.5*x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h*x_17_h
	addsd	xmm7,xmm1				; x+x_17_h

	ucomisd	xmm1,qword ptr real_2_p_m_16
	jb		ln_real_g1_s

ln_real_g1_l:
	divsd	xmm3,xmm2				; p/q

	subsd	xmm1,xmm13				; x-0.5*x_17_h*x_17_h
	mulsd	xmm7,xmm14				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm3,xmm8				; (p/q)*x3
	subsd	xmm3,xmm7				; (p/q)*x3-0.5x2_l
	addsd	xmm3,xmm6


	movsd	xmm2,xmm0
	addsd	xmm0,xmm1
	subsd	xmm2,xmm0
	addsd	xmm2,xmm1
	addsd	xmm2,xmm3
	addsd	xmm0,xmm2


;	addsd	xmm1,xmm3				; (p/q)*x3-0.5x2+x
;	addsd	xmm0,xmm1
	ret

ln_real_g1_s:
	divsd	xmm3,xmm2				; p/q

	mulsd	xmm7,xmm14				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm3,xmm8				; (p/q)*x3
	subsd	xmm3,xmm7				; (p/q)*x3-0.5x2_l
	addsd	xmm3,xmm6
	subsd	xmm3,xmm13				; (p/q)*x3-0.5x2
	addsd	xmm1,xmm3				; (p/q)*x3-0.5x2_l+x
	addsd	xmm0,xmm1
	ret

ln_real_g_7_d_6:
	mulsd	xmm2,qword ptr real_0_75
	movlpd	xmm1,qword ptr real_0_25

	lea		rcx,ln_b_c
	lea		rdx,ln_s_c

	ucomisd	xmm2,xmm1
	subsd	xmm2,xmm1

	cmovb	rcx,rdx

	movsd	xmm1,xmm2				; x
	mulsd	xmm2,xmm2				; x2

	movlpd	xmm4,qword ptr (ln_b_q_1-ln_b_c)[rcx]
	movlpd	xmm3,qword ptr (ln_b_p_1-ln_b_c)[rcx]
	mulsd	xmm4,xmm1				; q1
	mulsd	xmm3,xmm1				; p1
	movsd	xmm8,xmm1				; x

	cvtdq2pd xmm0,xmm0

	movlpd	xmm6,qword ptr (ln_b_q_2-ln_b_c)[rcx]
	movlpd	xmm5,qword ptr (ln_b_p_2-ln_b_c)[rcx]
	movsd	xmm7,xmm2				; x2
	mulsd	xmm2,xmm2				; x4

	movsd	xmm12,xmm1				; x
	mulsd	xmm8,xmm7				; x3

	movlpd	xmm10,qword ptr (ln_b_q_3-ln_b_c)[rcx]
	movlpd	xmm9,qword ptr (ln_b_p_3-ln_b_c)[rcx]

	mulsd	xmm12,xmm2				; x5

	mulsd	xmm6,xmm7				; q2
	mulsd	xmm5,xmm7				; p2

	movlpd	xmm11,qword ptr (ln_b_p_4-ln_b_c)[rcx]

	mulsd	xmm10,xmm8				; q3
	mulsd	xmm9,xmm8				; p3
	
	mulsd	xmm11,xmm2				; p4
	mulsd	xmm2,qword ptr (ln_b_q_4-ln_b_c)[rcx] ; q4
	
	addsd	xmm2,xmm12				; q4+x5

	addsd	xmm2,xmm10				; q3+q4+x5
	addsd	xmm9,xmm11				; p3+p4

	movlpd	xmm7,qword ptr real_17_bits

	addsd	xmm2,xmm6				; q2+q3+q4+x5
	addsd	xmm5,xmm9				; p2+p3+p4
	
	andpd	xmm7,xmm1				; x_17_h
	movsd	xmm14,xmm1				; x
	movlpd	xmm13,qword ptr real_0_5

	movlpd	xmm6,qword ptr real_ln2_42_l
	
	addsd	xmm2,xmm4				; q1+q2+q3+q4+x5
	addsd	xmm3,xmm5				; p1+p2+p3+p4
	
	subsd	xmm14,xmm7				; x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h

	mulsd	xmm6,xmm0
	mulsd	xmm0,qword ptr real_ln2_42
	
	addsd	xmm2,qword ptr (ln_b_q_0-ln_b_c)[rcx] ; q0+q1+q2+q3+q4+x5
	addsd	xmm3,qword ptr (ln_b_p_0-ln_b_c)[rcx] ; p0+p1+p2+p3+p4

	mulsd	xmm14,qword ptr real_0_5; 0.5*x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h*x_17_h
	addsd	xmm7,xmm1				; x+x_17_h

	addsd	xmm0,qword ptr ln_4_d_3_42
	addsd	xmm6,qword ptr ln_4_d_3_42_l
	jmp		ln_real_g1_l

ln_real_s:
	movlpd	xmm3,qword ptr ln_s_q_1
	movlpd	xmm2,qword ptr ln_s_p_1

	mulsd	xmm3,xmm1				; q1
	mulsd	xmm2,xmm1				; p1
	movsd	xmm7,xmm1				; x
	movlpd	xmm5,qword ptr ln_s_q_2
	movlpd	xmm4,qword ptr ln_s_p_2
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movsd	xmm11,xmm1				; x
	mulsd	xmm7,xmm6				; x3

	movlpd	xmm9,qword ptr ln_s_q_3
	movlpd	xmm8,qword ptr ln_s_p_3

	mulsd	xmm11,xmm0				; x5

	mulsd	xmm5,xmm6				; q2
	mulsd	xmm4,xmm6				; p2

	movlpd	xmm10,qword ptr ln_s_q_4

	mulsd	xmm9,xmm7				; q3
	mulsd	xmm8,xmm7				; p3
	
	mulsd	xmm10,xmm0				; q4
	mulsd	xmm0,qword ptr ln_s_p_4	; p4

	addsd	xmm10,xmm11				; q4+x5

	addsd	xmm0,xmm8				; p3+p4
	addsd	xmm9,xmm10				; q3+q4+x5

	movlpd	xmm6,qword ptr real_17_bits

	addsd	xmm0,xmm4				; p2+p3+p4	
	addsd	xmm5,xmm9				; q2+q3+q4+x5

	andpd	xmm6,xmm1				; x_17_h
	movsd	xmm8,xmm1				; x
	movlpd	xmm4,qword ptr real_0_5

	addsd	xmm0,xmm2				; p1+p2+p3+p4
	addsd	xmm3,xmm5				; q1+q2+q3+q4+x5

	subsd	xmm8,xmm6				; x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h

	addsd	xmm0,qword ptr ln_s_p_0	; p0+p1+p2+p3+p4
	addsd	xmm3,qword ptr ln_s_q_0	; q0+q1+q2+q3+q4+x5

	mulsd	xmm8,qword ptr real_0_5; 0.5*x_17_l
	mulsd	xmm4,xmm6				; 0.5*x_17_h*x_17_h
	addsd	xmm6,xmm1				; x+x_17_h

	ucomisd	xmm1,qword ptr real_m_2_p_m_16
	ja		ln_real_s_s

	divsd	xmm0,xmm3				; p/q

	subsd	xmm1,xmm4				; x-0.5*x_17_h*x_17_h
	mulsd	xmm6,xmm8				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm0,xmm7				; (p/q)*x3
	subsd	xmm0,xmm6				; (p/q)*x3-0.5x2_l
	addsd	xmm0,xmm1				; (p/q)*x3-0.5x2+x
	ret

ln_real_s_s:
	divsd	xmm0,xmm3				; p/q

	mulsd	xmm6,xmm8				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm0,xmm7				; (p/q)*x3
	subsd	xmm0,xmm6				; (p/q)*x3-0.5x2_l
	subsd	xmm0,xmm4				; (p/q)*x3-0.5x2
	addsd	xmm0,xmm1				; (p/q)*x3-0.5x2+x
	ret
	

ln_real_l1:
	subsd	xmm3,qword ptr real_1_0

	psubq	xmm0,qword ptr qw_1022
ln_real_l1_:
	movsd	xmm1,xmm3				; x
	mulsd	xmm3,xmm3				; x2

	movlpd	xmm4,qword ptr ln_s_q_1
	movlpd	xmm2,qword ptr ln_s_p_1
	mulsd	xmm4,xmm1				; q1
	mulsd	xmm2,xmm1				; p1
	movsd	xmm8,xmm1				; x

	cvtdq2pd xmm0,xmm0

	movlpd	xmm6,qword ptr ln_s_q_2
	movlpd	xmm5,qword ptr ln_s_p_2
	movsd	xmm7,xmm3				; x2
	mulsd	xmm3,xmm3				; x4

	movsd	xmm12,xmm1				; x
	mulsd	xmm8,xmm7				; x3

	movlpd	xmm10,qword ptr ln_s_q_3
	movlpd	xmm9,qword ptr ln_s_p_3

	mulsd	xmm12,xmm3				; x5

	mulsd	xmm6,xmm7				; q2
	mulsd	xmm5,xmm7				; p2

	movlpd	xmm11,qword ptr ln_s_p_4

	mulsd	xmm10,xmm8				; q3
	mulsd	xmm9,xmm8				; p3
	
	mulsd	xmm11,xmm3				; p4
	mulsd	xmm3,qword ptr ln_s_q_4 ; q4

	addsd	xmm3,xmm12				; q4+x5

	addsd	xmm3,xmm10				; q3+q4+x5
	addsd	xmm9,xmm11				; p3+p4

	movlpd	xmm7,qword ptr real_17_bits

	addsd	xmm3,xmm6				; q2+q3+q4+x5
	addsd	xmm5,xmm9				; p2+p3+p4	

	andpd	xmm7,xmm1				; x_17_h
	movsd	xmm14,xmm1				; x
	movlpd	xmm13,qword ptr real_0_5

	movlpd	xmm6,qword ptr real_ln2_42_l

	addsd	xmm3,xmm4				; q1+q2+q3+q4+x5
	addsd	xmm2,xmm5				; p1+p2+p3+p4

	subsd	xmm14,xmm7				; x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h

	mulsd	xmm6,xmm0
	mulsd	xmm0,qword ptr real_ln2_42

	addsd	xmm3,qword ptr ln_s_q_0	; q0+q1+q2+q3+q4+x5
	addsd	xmm2,qword ptr ln_s_p_0	; p0+p1+p2+p3+p4

	mulsd	xmm14,qword ptr real_0_5; 0.5*x_17_l
	mulsd	xmm13,xmm7				; 0.5*x_17_h*x_17_h
	addsd	xmm7,xmm1				; x+x_17_h

	ucomisd	xmm1,qword ptr real_m_2_p_m_16
	ja		ln_real_l1_s

	divsd	xmm2,xmm3				; p/q

	subsd	xmm1,xmm13				; x-0.5*x_17_h*x_17_h
	mulsd	xmm7,xmm14				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm2,xmm8				; (p/q)*x3
	subsd	xmm2,xmm7				; (p/q)*x3-0.5x2_l
	addsd	xmm2,xmm6


	movsd	xmm3,xmm0
	addsd	xmm0,xmm1
	subsd	xmm3,xmm0
	addsd	xmm3,xmm1
	addsd	xmm3,xmm2
	addsd	xmm0,xmm3

;	addsd	xmm1,xmm2				; (p/q)*x3-0.5x2+x
;	addsd	xmm0,xmm1
	ret

ln_real_l1_s:
	divsd	xmm2,xmm3				; p/q

	mulsd	xmm7,xmm14				; 0.5*x_17_l*(x+x_17_h)

	mulsd	xmm2,xmm8				; (p/q)*x3
	subsd	xmm2,xmm7				; (p/q)*x3-0.5x2_l
	addsd	xmm2,xmm6
	subsd	xmm2,xmm13				; (p/q)*x3-0.5x2
	addsd	xmm1,xmm2				; (p/q)*x3-0.5x2+x
	addsd	xmm0,xmm1
	ret

ln_real_less_or_equal_0_or_nan:
	jb		ln_real_less_0_or_nan	; x<0.0 | nan

	movsd	xmm0,qword ptr real_m_1_0
	divsd	xmm0,qword ptr real_0_0	; yield -inf
	ret

ln_real_less_0_or_nan:
	jp		ln_real_inf_or_nan		; nan

	movsd	xmm0,qword ptr real_0_0	; yield nan
	divsd	xmm0,xmm0

ln_real_inf_or_nan:
	ret

_T007	ends

_T008	segment para 'CODE'

	public	log10_real

log10_real:
;	ucomisd	xmm0,qword ptr real_0_7025
	ucomisd	xmm0,qword ptr real_0_833
;	jb		log10_real_small			; x<0.7025 | nan
	jb		log10_real_small			; x<0.833 | nan
	ucomisd	xmm0,qword ptr real_1_666
	ja		log10_real_large			; x>1.666

	movlpd	xmm2,qword ptr real_1_0

	ucomisd	xmm0,qword ptr real_7_d_6
	ja		log10_real_a_7_d_6

	ucomisd	xmm0,xmm2

	subsd	xmm0,xmm2

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	jae		log10_real_0
	jmp		log10_real_s

log10_real_small:
	ucomisd	xmm0,qword ptr real_2_p_m_1022
	jae		log10_real_

	ucomisd	xmm0,qword ptr real_0_0
	jbe		log10_real_less_or_equal_0_or_nan

; denormalized number

	mulsd	xmm0,qword ptr real_2_p_55

	movlpd	xmm1,qword ptr mask_significand
	andpd	xmm1,xmm0
	psrlq	xmm0,52

	movlpd	xmm2,qword ptr real_1_0
	movlpd	xmm3,qword ptr real_0_5
	orpd	xmm2,xmm1
	orpd	xmm3,xmm1

;	ucomisd	xmm2,qword ptr real_1_405
	ucomisd	xmm2,qword ptr real_1_666
	jbe		log10_real_dn_g1

	subsd	xmm3,qword ptr real_1_0
	psubq	xmm0,qword ptr qw_1077
	jmp		log10_real_l1_

log10_real_dn_g1:
	ucomisd	xmm2,qword ptr real_7_d_6

	subsd	xmm2,qword ptr real_1_0
	psubq	xmm0,qword ptr qw_1078

	ja		log10_real_g_7_d_6
	jmp		log10_real_g1_

log10_real_large:
	ucomisd	xmm0,qword ptr real_max
	ja		log10_real_inf_or_nan

log10_real_:
	movlpd	xmm1,qword ptr mask_significand
	andpd	xmm1,xmm0
	psrlq	xmm0,52

	movlpd	xmm2,qword ptr real_1_0
	movlpd	xmm3,qword ptr real_0_5
	orpd	xmm2,xmm1
	orpd	xmm3,xmm1

;	ucomisd	xmm2,qword ptr real_1_405
	ucomisd	xmm2,qword ptr real_1_666
	jbe		log10_real_g1
	jmp		log10_real_l1

log10_real_0:
	movlpd	xmm2,qword ptr log10_b_p_1
	movlpd	xmm3,qword ptr log10_b_q_1
	mulsd	xmm2,xmm1				; p1
	mulsd	xmm3,xmm1				; q1
	movsd	xmm7,xmm1				; x

	movlpd	xmm4,qword ptr log10_b_p_2
	movlpd	xmm5,qword ptr log10_b_q_2
	mulsd	xmm7,xmm0				; x3
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm8,qword ptr log10_b_p_3
	movlpd	xmm9,qword ptr log10_b_q_3

	mulsd	xmm4,xmm6				; p2
	mulsd	xmm5,xmm6				; q2

	movlpd	xmm10,qword ptr log10_b_p_4

	mulsd	xmm8,xmm7				; p3
	mulsd	xmm9,xmm7				; q3

	movsd	xmm11,xmm7				; x3
	mulsd	xmm7,xmm6				; x5
	
	mulsd	xmm10,xmm0				; p4
	mulsd	xmm0,qword ptr log10_b_q_4 ; q4

	addsd	xmm0,xmm7				; q4+x5

	addsd	xmm9,xmm0				; q3+q4+x5
	addsd	xmm8,xmm10				; p3+p4

	mulsd	xmm6,qword ptr real_0_5 ; 0.5x2

	addsd	xmm9,xmm5				; q2+q3+q4+x5
	addsd	xmm4,xmm8				; p2+p3+p4	

	addsd	xmm9,xmm3				; q1+q2+q3+q4+x5
	addsd	xmm2,xmm4				; p1+p2+p3+p4

	movlpd	xmm4,qword ptr real_26_bits
	movsd	xmm0,xmm1				; x

	addsd	xmm9,qword ptr log10_b_q_0 ; q0+q1+q2+q3+q4+x5
	addsd	xmm2,qword ptr log10_b_p_0 ; p0+p1+p2+p3+p4

	subsd	xmm1,xmm6				; x-0.5x2

	divsd	xmm2,xmm9				; p/q

	andpd	xmm4,xmm1				; (x-0.5x2)_h
	subsd	xmm0,xmm4				; x-(x-0.5x2)_h
	subsd	xmm0,xmm6				; (x-0.5x2)_l

	mulsd	xmm2,xmm11				; (p/q)*x3

	mulsd	xmm1,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm0,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
	mulsd	xmm4,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm0,xmm1				; (x-0.5x2) * (1/ln 10)_l+(x-0.5x2)_l * (1/ln 10)_h
	addsd	xmm0,xmm2
	addsd	xmm0,xmm4				; (x-0.5x2)*(1/ln 10) + (p/q)*x3

	ret

;log10_real_0_:
;	movlpd	xmm2,qword ptr log10_b_p_1
;	movlpd	xmm10,qword ptr log10_b_q_1
;	mulsd	xmm2,xmm1				; p1
;	mulsd	xmm10,xmm1				; q1
;	movsd	xmm7,xmm1				; x
;
;	movlpd	xmm11,qword ptr log10_b_p_2
;	movlpd	xmm5,qword ptr log10_b_q_2
;	mulsd	xmm7,xmm0				; x3
;	movsd	xmm6,xmm0				; x2
;	mulsd	xmm0,xmm0				; x4
;
;	movlpd	xmm8,qword ptr log10_b_p_3
;	movlpd	xmm9,qword ptr log10_b_q_3
;
;;	mulsd	xmm11,xmm6				; p2
;	mulsd	xmm5,xmm6				; q2
;
;	movlpd	xmm3,qword ptr log10_b_p_4
;
;	mulsd	xmm8,xmm7				; p3
;	mulsd	xmm9,xmm7				; q3
;
;	mulsd	xmm6,xmm7				; x5
;
;	mulsd	xmm3,xmm0				; p4
;	mulsd	xmm0,qword ptr log10_b_q_4 ; q4
;	
;	movsd	xmm4,xmm1				; x
;	addsd	xmm0,xmm6				; q4+x5
;	movlpd	xmm6,qword ptr real_m_0_5
;
;	addsd	xmm9,xmm0				; q3+q4+x5
;	addsd	xmm8,xmm3				; p3+p4
;
;	movlpd	xmm0,qword ptr real_14_bits
;
;	andpd	xmm0,xmm1				; x_h
;	mulsd	xmm6,xmm1 				; -0.5x
;
;	addsd	xmm9,xmm5				; q2+q3+q4+x5
;	addsd	xmm11,xmm8				; p2+p3+p4	
;
;	movsd	xmm3,xmm1				; x
;	subsd	xmm4,xmm0				; x_l
;	addsd	xmm6,qword ptr real_1_0	; 1-0.5x
;	movlpd	xmm5,qword ptr real_13_bits
;
;	addsd	xmm9,xmm10				; q1+q2+q3+q4+x5
;	addsd	xmm2,xmm11				; p1+p2+p3+p4
;	
;	andpd	xmm5,xmm6				; (1-0.5x)_h
;	mulsd	xmm3,xmm6				; (1-0.5x)*x = x-0.5x2
;
;	addsd	xmm9,qword ptr log10_b_q_0 ; q0+q1+q2+q3+q4+x5
;	addsd	xmm2,qword ptr log10_b_p_0 ; p0+p1+p2+p3+p4
;
;	subsd	xmm6,xmm5				; (1-0.5x)_l
;	mulsd	xmm0,xmm5				; (1-0.5x)_h*x_h = (x-0.5x2)_h
;	mulsd	xmm4,xmm5				; (1-0.5x)_h*x_l
;
;	divsd	xmm2,xmm9				; p/q
;
;	mulsd	xmm3,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
;	mulsd	xmm6,xmm1				; (1-0.5x)_l*x
;	mulsd	xmm0,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h
;
;	addsd	xmm6,xmm4				; (x-0.5x2)_l
;
;	mulsd	xmm6,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
;
;	mulsd	xmm2,xmm7				; (p/q)*x3
;
;	addsd	xmm6,xmm3
;	
;	addsd	xmm2,xmm6
;	
;	addsd	xmm0,xmm2
;
;	ret

log10_real_a_7_d_6:
	subsd	xmm0,xmm2

	mulsd	xmm0,qword ptr real_0_75
	movlpd	xmm1,qword ptr real_0_25

	lea		rcx,log10_b_c
	lea		rdx,log10_s_c

	ucomisd	xmm0,xmm1
	subsd	xmm0,xmm1

	cmovb	rcx,rdx

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	movlpd	xmm2,qword ptr (log10_b_p_1-log10_b_c)[rcx]
	movlpd	xmm3,qword ptr (log10_b_q_1-log10_b_c)[rcx]
	mulsd	xmm2,xmm1				; p1
	mulsd	xmm3,xmm1				; q1
	movsd	xmm7,xmm1				; x

	movlpd	xmm4,qword ptr (log10_b_p_2-log10_b_c)[rcx]
	movlpd	xmm5,qword ptr (log10_b_q_2-log10_b_c)[rcx]
	mulsd	xmm7,xmm0				; x3
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm8,qword ptr (log10_b_p_3-log10_b_c)[rcx]
	movlpd	xmm9,qword ptr (log10_b_q_3-log10_b_c)[rcx]

	mulsd	xmm4,xmm6				; p2
	mulsd	xmm5,xmm6				; q2

	movlpd	xmm10,qword ptr (log10_b_p_4-log10_b_c)[rcx]

	mulsd	xmm8,xmm7				; p3
	mulsd	xmm9,xmm7				; q3

	movsd	xmm11,xmm7				; x3
	mulsd	xmm7,xmm6				; x5
	
	mulsd	xmm10,xmm0				; p4
	mulsd	xmm0,qword ptr (log10_b_q_4-log10_b_c)[rcx] ; q4

	addsd	xmm0,xmm7				; q4+x5

	addsd	xmm9,xmm0				; q3+q4+x5
	addsd	xmm8,xmm10				; p3+p4

	mulsd	xmm6,qword ptr real_0_5 ; 0.5x2

	addsd	xmm9,xmm5				; q2+q3+q4+x5
	addsd	xmm4,xmm8				; p2+p3+p4	

	addsd	xmm9,xmm3				; q1+q2+q3+q4+x5
	addsd	xmm2,xmm4				; p1+p2+p3+p4

	movlpd	xmm4,qword ptr real_26_bits
	movsd	xmm0,xmm1				; x

	addsd	xmm9,qword ptr (log10_b_q_0-log10_b_c)[rcx] ; q0+q1+q2+q3+q4+x5
	addsd	xmm2,qword ptr (log10_b_p_0-log10_b_c)[rcx] ; p0+p1+p2+p3+p4

	subsd	xmm1,xmm6				; x-0.5x2

	divsd	xmm2,xmm9				; p/q

	andpd	xmm4,xmm1				; (x-0.5x2)_h
	subsd	xmm0,xmm4				; x-(x-0.5x2)_h
	subsd	xmm0,xmm6				; (x-0.5x2)_l

	mulsd	xmm2,xmm11				; (p/q)*x3

	mulsd	xmm1,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm0,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
	mulsd	xmm4,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm0,xmm1				; (x-0.5x2) * (1/ln 10)_l+(x-0.5x2)_l * (1/ln 10)_h

	movlpd	xmm3,qword ptr log10_4_d_3_53
	movlpd	xmm5,qword ptr log10_4_d_3_53

	addsd	xmm3,xmm4
	addsd	xmm0,qword ptr log10_4_d_3_53_l

	subsd	xmm5,xmm3

	addsd	xmm5,xmm4
	
	addsd	xmm0,xmm5

	addsd	xmm0,xmm2
	addsd	xmm0,xmm3				; (x-0.5x2)*(1/ln 10) + (p/q)*x3
	ret

log10_real_g1:
	ucomisd	xmm2,qword ptr real_7_d_6

	subsd	xmm2,qword ptr real_1_0

	psubq	xmm0,qword ptr qw_1023

	ja		log10_real_g_7_d_6

log10_real_g1_:
	movsd	xmm1,xmm2				; x
	mulsd	xmm2,xmm2				; x2

	movlpd	xmm11,qword ptr log10_b_p_1
	movlpd	xmm10,qword ptr log10_b_q_1
	mulsd	xmm11,xmm1				; p1
	mulsd	xmm10,xmm1				; q1
	movsd	xmm7,xmm1				; x

	cvtdq2pd xmm12,xmm0

	movlpd	xmm0,qword ptr log10_b_p_2
	movlpd	xmm5,qword ptr log10_b_q_2
	mulsd	xmm7,xmm2				; x3
	movsd	xmm6,xmm2				; x2
	mulsd	xmm2,xmm2				; x4

	movlpd	xmm8,qword ptr log10_b_p_3
	movlpd	xmm9,qword ptr log10_b_q_3

	mulsd	xmm0,xmm6				; p2
	mulsd	xmm5,xmm6				; q2

	movlpd	xmm3,qword ptr log10_b_p_4

	mulsd	xmm8,xmm7				; p3
	mulsd	xmm9,xmm7				; q3

	mulsd	xmm6,xmm7				; x5

	mulsd	xmm3,xmm2				; p4
	mulsd	xmm2,qword ptr log10_b_q_4 ; q4
	
	movsd	xmm4,xmm1				; x
	addsd	xmm2,xmm6				; q4+x5	
	movlpd	xmm6,qword ptr real_m_0_5

	addsd	xmm9,xmm2				; q3+q4+x5
	addsd	xmm8,xmm3				; p3+p4

	movlpd	xmm13,qword ptr real_log2_10_42_l
	movlpd	xmm2,qword ptr real_14_bits

	andpd	xmm2,xmm1				; x_h
	mulsd	xmm6,xmm1 				; -0.5x

	addsd	xmm9,xmm5				; q2+q3+q4+x5
	addsd	xmm0,xmm8				; p2+p3+p4	

	mulsd	xmm13,xmm12
	mulsd	xmm12,qword ptr real_log2_10_42

	movsd	xmm3,xmm1				; x
	subsd	xmm4,xmm2				; x_l
	addsd	xmm6,qword ptr real_1_0	; 1-0.5x
	movlpd	xmm5,qword ptr real_13_bits

	addsd	xmm9,xmm10				; q1+q2+q3+q4+x5
	addsd	xmm0,xmm11				; p1+p2+p3+p4
	
	andpd	xmm5,xmm6				; (1-0.5x)_h
	mulsd	xmm3,xmm6				; (1-0.5x)*x = x-0.5x2

	addsd	xmm9,qword ptr log10_b_q_0 ; q0+q1+q2+q3+q4+x5
	addsd	xmm0,qword ptr log10_b_p_0 ; p0+p1+p2+p3+p4

	subsd	xmm6,xmm5				; (1-0.5x)_l
	mulsd	xmm2,xmm5				; (1-0.5x)_h*x_h = (x-0.5x2)_h
	mulsd	xmm4,xmm5				; (1-0.5x)_h*x_l

	divsd	xmm0,xmm9				; p/q

	mulsd	xmm3,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm6,xmm1				; (1-0.5x)_l*x
	mulsd	xmm2,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm6,xmm4				; (x-0.5x2)_l

	mulsd	xmm6,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h

	mulsd	xmm0,xmm7				; (p/q)*x3

	addsd	xmm6,xmm3
	
	addsd	xmm0,xmm6
	
	addsd	xmm0,xmm13

	movsd	xmm3,xmm2
	addsd	xmm2,xmm12
	subsd	xmm12,xmm2
	addsd	xmm12,xmm3
	addsd	xmm0,xmm12
	addsd	xmm0,xmm2

;	addsd	xmm0,xmm2
;	addsd	xmm0,xmm12

	ret

log10_real_g_7_d_6:
	mulsd	xmm2,qword ptr real_0_75
	movlpd	xmm1,qword ptr real_0_25

	lea		rcx,log10_b_c
	lea		rdx,log10_s_c

	ucomisd	xmm2,xmm1
	subsd	xmm2,xmm1

	cmovb	rcx,rdx

	movsd	xmm1,xmm2				; x
	mulsd	xmm2,xmm2				; x2

	movlpd	xmm3,qword ptr (log10_b_p_1-log10_b_c)[rcx]
	movlpd	xmm4,qword ptr (log10_b_q_1-log10_b_c)[rcx]
	mulsd	xmm3,xmm1				; p1
	mulsd	xmm4,xmm1				; q1
	movsd	xmm8,xmm1				; x

	cvtdq2pd xmm0,xmm0

	movlpd	xmm5,qword ptr (log10_b_p_2-log10_b_c)[rcx]
	movlpd	xmm6,qword ptr (log10_b_q_2-log10_b_c)[rcx]
	mulsd	xmm8,xmm2				; x3
	movsd	xmm7,xmm2				; x2
	mulsd	xmm2,xmm2				; x4

	movlpd	xmm9,qword ptr (log10_b_p_3-log10_b_c)[rcx]
	movlpd	xmm10,qword ptr (log10_b_q_3-log10_b_c)[rcx]

	mulsd	xmm5,xmm7				; p2
	mulsd	xmm6,xmm7				; q2

	movlpd	xmm11,qword ptr (log10_b_p_4-log10_b_c)[rcx]

	mulsd	xmm9,xmm8				; p3
	mulsd	xmm10,xmm8				; q3

	movsd	xmm12,xmm8				; x3
	mulsd	xmm8,xmm7				; x5

	mulsd	xmm11,xmm2				; p4
	mulsd	xmm2,qword ptr (log10_b_q_4-log10_b_c)[rcx] ; q4
	
	addsd	xmm2,xmm8				; q4+x5
	
	addsd	xmm10,xmm2				; q3+q4+x5
	addsd	xmm9,xmm11				; p3+p4

	mulsd	xmm7,qword ptr real_0_5 ; 0.5x2

	addsd	xmm10,xmm6				; q2+q3+q4+x5
	addsd	xmm5,xmm9				; p2+p3+p4

	movlpd	xmm6,qword ptr real_log2_10_42_l

	addsd	xmm10,xmm4				; q1+q2+q3+q4+x5
	addsd	xmm3,xmm5				; p1+p2+p3+p4

	movlpd	xmm5,qword ptr real_26_bits
	movsd	xmm2,xmm1				; x

	mulsd	xmm6,xmm0
	mulsd	xmm0,qword ptr real_log2_10_42

	addsd	xmm10,qword ptr (log10_b_q_0-log10_b_c)[rcx] ; q0+q1+q2+q3+q4+x5
	addsd	xmm3,qword ptr (log10_b_p_0-log10_b_c)[rcx] ; p0+p1+p2+p3+p4

	subsd	xmm1,xmm7				; x-0.5x2

	addsd	xmm6,qword ptr log10_4_d_3_42_l
	addsd	xmm0,qword ptr log10_4_d_3_42

	divsd	xmm3,xmm10				; p/q

	andpd	xmm5,xmm1				; (x-0.5x2)_h
	subsd	xmm2,xmm5				; x-(x-0.5x2)_h
	subsd	xmm2,xmm7				; (x-0.5x2)_l

	mulsd	xmm3,xmm12				; (p/q)*x3

	mulsd	xmm1,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm2,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
	mulsd	xmm5,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm2,xmm1				; (x-0.5x2) * (1/ln 10)_l+(x-0.5x2)_l * (1/ln 10)_h
	addsd	xmm2,xmm3
	addsd	xmm2,xmm6

	movsd	xmm3,xmm0
	addsd	xmm0,xmm5
	subsd	xmm3,xmm0
	addsd	xmm3,xmm5
	addsd	xmm3,xmm2
	addsd	xmm0,xmm3

;	addsd	xmm2,xmm5				; (x-0.5x2)*(1/ln 10) + (p/q)*x3
;	addsd	xmm0,xmm2
	ret

log10_real_s:
	movlpd	xmm2,qword ptr log10_s_p_1
	movlpd	xmm3,qword ptr log10_s_q_1
	mulsd	xmm2,xmm1				; p1
	mulsd	xmm3,xmm1				; q1
	movsd	xmm7,xmm1				; x

	movlpd	xmm4,qword ptr log10_s_p_2
	movlpd	xmm5,qword ptr log10_s_q_2
	mulsd	xmm7,xmm0				; x3
	movsd	xmm6,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	movlpd	xmm8,qword ptr log10_s_p_3
	movlpd	xmm9,qword ptr log10_s_q_3

	mulsd	xmm4,xmm6				; p2
	mulsd	xmm5,xmm6				; q2

	movlpd	xmm10,qword ptr log10_s_p_4

	mulsd	xmm8,xmm7				; p3
	mulsd	xmm9,xmm7				; q3

	movsd	xmm11,xmm7				; x3
	mulsd	xmm7,xmm6				; x5
	
	mulsd	xmm10,xmm0				; p4
	mulsd	xmm0,qword ptr log10_s_q_4 ; q4

	addsd	xmm0,xmm7				; q4+x5

	addsd	xmm9,xmm0				; q3+q4+x5
	addsd	xmm8,xmm10				; p3+p4

	mulsd	xmm6,qword ptr real_0_5 ; 0.5x2

	addsd	xmm9,xmm5				; q2+q3+q4+x5
	addsd	xmm4,xmm8				; p2+p3+p4	

	addsd	xmm9,xmm3				; q1+q2+q3+q4+x5
	addsd	xmm2,xmm4				; p1+p2+p3+p4

	movlpd	xmm4,qword ptr real_26_bits
	movsd	xmm0,xmm1				; x

	addsd	xmm9,qword ptr log10_s_q_0 ; q0+q1+q2+q3+q4+x5
	addsd	xmm2,qword ptr log10_s_p_0 ; p0+p1+p2+p3+p4

	subsd	xmm1,xmm6				; x-0.5x2

	divsd	xmm2,xmm9				; p/q

	andpd	xmm4,xmm1				; (x-0.5x2)_h
	subsd	xmm0,xmm4				; x-(x-0.5x2)_h
	subsd	xmm0,xmm6				; (x-0.5x2)_l

	mulsd	xmm2,xmm11				; (p/q)*x3

	mulsd	xmm1,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm0,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
	mulsd	xmm4,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm0,xmm1				; (x-0.5x2) * (1/ln 10)_l+(x-0.5x2)_l * (1/ln 10)_h
	addsd	xmm0,xmm2
	addsd	xmm0,xmm4				; (x-0.5x2)*(1/ln 10) + (p/q)*x3

	ret

log10_real_l1:
	subsd	xmm3,qword ptr real_1_0

	psubq	xmm0,qword ptr qw_1022
log10_real_l1_:
	movsd	xmm1,xmm3				; x
	mulsd	xmm3,xmm3				; x2

	movlpd	xmm2,qword ptr log10_s_p_1
	movlpd	xmm4,qword ptr log10_s_q_1
	mulsd	xmm2,xmm1				; p1
	mulsd	xmm4,xmm1				; q1
	movsd	xmm8,xmm1				; x

	cvtdq2pd xmm0,xmm0

	movlpd	xmm5,qword ptr log10_s_p_2
	movlpd	xmm6,qword ptr log10_s_q_2
	mulsd	xmm8,xmm3				; x3
	movsd	xmm7,xmm3				; x2
	mulsd	xmm3,xmm3				; x4

	movlpd	xmm9,qword ptr log10_s_p_3
	movlpd	xmm10,qword ptr log10_s_q_3

	mulsd	xmm5,xmm7				; p2
	mulsd	xmm6,xmm7				; q2

	movlpd	xmm11,qword ptr log10_s_p_4

	mulsd	xmm9,xmm8				; p3
	mulsd	xmm10,xmm8				; q3

	movsd	xmm12,xmm8				; x3
	mulsd	xmm8,xmm7				; x5

	mulsd	xmm11,xmm3				; p4
	mulsd	xmm3,qword ptr log10_s_q_4 ; q4
	
	addsd	xmm3,xmm8				; q4+x5
	
	addsd	xmm10,xmm3				; q3+q4+x5
	addsd	xmm9,xmm11				; p3+p4

	mulsd	xmm7,qword ptr real_0_5 ; 0.5x2

	addsd	xmm10,xmm6				; q2+q3+q4+x5
	addsd	xmm5,xmm9				; p2+p3+p4

	movlpd	xmm6,qword ptr real_log2_10_42_l

	addsd	xmm10,xmm4				; q1+q2+q3+q4+x5
	addsd	xmm2,xmm5				; p1+p2+p3+p4

	movlpd	xmm5,qword ptr real_26_bits
	movsd	xmm3,xmm1				; x

	mulsd	xmm6,xmm0
	mulsd	xmm0,qword ptr real_log2_10_42

	addsd	xmm10,qword ptr log10_s_q_0 ; q0+q1+q2+q3+q4+x5
	addsd	xmm2,qword ptr log10_s_p_0 ; p0+p1+p2+p3+p4

	subsd	xmm1,xmm7				; x-0.5x2

	divsd	xmm2,xmm10				; p/q

	andpd	xmm5,xmm1				; (x-0.5x2)_h
	subsd	xmm3,xmm5				; x-(x-0.5x2)_h
	subsd	xmm3,xmm7				; (x-0.5x2)_l

	mulsd	xmm2,xmm12				; (p/q)*x3

	mulsd	xmm1,qword ptr d1ln10_26_l ; (x-0.5x2) * (1/ln 10)_l
	mulsd	xmm3,qword ptr d1ln10_26 ; (x-0.5x2)_l * (1/ln 10)_h
	mulsd	xmm5,qword ptr d1ln10_26 ; (x-0.5x2)_h * (1/ln 10)_h

	addsd	xmm3,xmm1				; (x-0.5x2) * (1/ln 10)_l+(x-0.5x2)_l * (1/ln 10)_h
	addsd	xmm3,xmm2
	addsd	xmm3,xmm6

	movsd	xmm2,xmm0
	addsd	xmm0,xmm5
	subsd	xmm2,xmm0
	addsd	xmm2,xmm5
	addsd	xmm2,xmm3
	addsd	xmm0,xmm2

;	addsd	xmm3,xmm5				; (x-0.5x2)*(1/ln 10) + (p/q)*x3
;	addsd	xmm0,xmm3
	ret

log10_real_less_or_equal_0_or_nan:
	jb		log10_real_less_0_or_nan ; x<0.0 | nan

	movsd	xmm0,qword ptr real_m_1_0
	divsd	xmm0,qword ptr real_0_0	; yield -inf
	ret

log10_real_less_0_or_nan:
	jp		log10_real_inf_or_nan	; nan

	movsd	xmm0,qword ptr real_0_0	; yield nan
	divsd	xmm0,xmm0

log10_real_inf_or_nan:
	ret

_T008	ends

_T009	segment para 'CODE'

	public	pow_real

pow_real:
	ucomisd	xmm0,qword ptr real_0_0
	je		pow_real_to_zero_or_nan	; y==0.0 | nan

	ucomisd	xmm1,qword ptr real_0_83
	jb		pow_real_small			; x<0.83 | nan
pow_real_not_small:
	ucomisd	xmm1,qword ptr real_1_66
	ja		pow_real_large

	ucomisd	xmm1,qword ptr real_7_d_6

	movlpd	xmm2,qword ptr real_1_0

	ja		pow_real_a_7_d_6

pow_real_between_0_83_and_7_d_6:
	ucomisd	xmm0,qword ptr real_power_exp_too_large
	ja		pow_real_exp_too_large

	ucomisd	xmm0,qword ptr real_power_exp_too_small
	jb		pow_real_exp_too_large_m

	ucomisd	xmm1,xmm2
	
	subsd	xmm1,xmm2

	lea		rcx,log2_b_c
	lea		rdx,log2_s_c
	cmovb	rcx,rdx

	movsd	xmm5,xmm1				; x
	mulsd	xmm1,xmm1				; x2

	movlpd	xmm2,qword ptr (log2_b_p_1-log2_b_c)[rcx]
	movlpd	xmm4,qword ptr (log2_b_q_1-log2_b_c)[rcx]
	mulsd	xmm2,xmm5				; p1
	mulsd	xmm4,xmm5				; q1
	movsd	xmm8,xmm5				; x
	movlpd	xmm3,qword ptr (log2_b_p_2-log2_b_c)[rcx]
	movlpd	xmm6,qword ptr (log2_b_q_2-log2_b_c)[rcx]
	mulsd	xmm8,xmm1				; x3
	movsd	xmm7,xmm1				; x2
	mulsd	xmm1,xmm1				; x4

	movlpd	xmm9,qword ptr (log2_b_p_3-log2_b_c)[rcx]
	movlpd	xmm10,qword ptr (log2_b_q_3-log2_b_c)[rcx]

	mulsd	xmm3,xmm7				; p2
	mulsd	xmm6,xmm7				; q2

	movlpd	xmm11,qword ptr (log2_b_p_4-log2_b_c)[rcx]

	mulsd	xmm9,xmm8				; p3
	mulsd	xmm10,xmm8				; q3
	
	mulsd	xmm11,xmm1				; p4
	
	addsd	xmm10,xmm1				; q3+x4
	addsd	xmm9,xmm11				; p3+p4

	mulsd	xmm7,qword ptr real_0_5 ; 0.5x2

	addsd	xmm10,xmm6				; q2+q3+x4
	addsd	xmm3,xmm9				; p2+p3+p4	
	addsd	xmm10,xmm4				; q1+q2+q3+x4
	addsd	xmm2,xmm3				; p1+p2+p3+p4

	movlpd	xmm3,qword ptr real_26_bits
	movsd	xmm1,xmm5				; x

	addsd	xmm10,qword ptr (log2_b_q_0-log2_b_c)[rcx] ; q0+q1+q2+q3+x4
	addsd	xmm2,qword ptr (log2_b_p_0-log2_b_c)[rcx] ; p0+p1+p2+p3+p4

	subsd	xmm5,xmm7				; x-0.5x2

	divsd	xmm2,xmm10				; p/q

	andpd	xmm3,xmm5				; (x-0.5x2)_h
	subsd	xmm1,xmm3				; x-(x-0.5x2)_h
	subsd	xmm1,xmm7				; (x-0.5x2)_l

	mulsd	xmm2,xmm8				; (p/q)*x3

	mulsd	xmm5,qword ptr d1ln2_26_l ; (x-0.5x2) * (1/ln 2)_l
	mulsd	xmm1,qword ptr d1ln2_26 ; (x-0.5x2)_l * (1/ln 2)_h
	mulsd	xmm3,qword ptr d1ln2_26 ; (x-0.5x2)_h * (1/ln 2)_h

	addsd	xmm1,xmm5				; (x-0.5x2) * (1/ln 2)_l+(x-0.5x2)_l * (1/ln 2)_h


	movsd	xmm5,xmm1				; xl
	addsd	xmm1,xmm2				; xl+r
	movlpd	xmm6,qword ptr real_26_bits

	addsd	xmm1,xmm3				; xh+xl+r

	andpd	xmm1,xmm6				; (log2 x)_h
	andpd	xmm6,xmm0				; y_h

	subsd	xmm3,xmm1				; xh-(log2 x)_h
	jmp		pow_real_2

pow_real_a_7_d_6:
	ucomisd	xmm0,qword ptr real_4605_0
	jae		pow_real_overflow		; because 1.1666666666666667407^4605>2^1024

	ucomisd	xmm0,qword ptr real_m_4834_0
	jbe		pow_real_underflow		; because 1.1666666666666667407^-4834<2^-1075

	subsd	xmm1,xmm2

	mulsd	xmm1,qword ptr real_0_75
	lea		rcx,log2_b_c
	lea		rdx,log2_s_c

	movlpd	xmm2,qword ptr real_0_25

	ucomisd	xmm1,xmm2
	subsd	xmm1,xmm2

	cmovb	rcx,rdx

	movsd	xmm5,xmm1				; x
	mulsd	xmm1,xmm1				; x2

	movlpd	xmm2,qword ptr (log2_b_p_1-log2_b_c)[rcx]
	movlpd	xmm4,qword ptr (log2_b_q_1-log2_b_c)[rcx]
	mulsd	xmm2,xmm5				; p1
	mulsd	xmm4,xmm5				; q1
	movsd	xmm8,xmm5				; x
	movlpd	xmm3,qword ptr (log2_b_p_2-log2_b_c)[rcx]
	movlpd	xmm6,qword ptr (log2_b_q_2-log2_b_c)[rcx]
	mulsd	xmm8,xmm1				; x3
	movsd	xmm7,xmm1				; x2
	mulsd	xmm1,xmm1				; x4

	movlpd	xmm9,qword ptr (log2_b_p_3-log2_b_c)[rcx]
	movlpd	xmm10,qword ptr (log2_b_q_3-log2_b_c)[rcx]

	mulsd	xmm3,xmm7				; p2
	mulsd	xmm6,xmm7				; q2

	movlpd	xmm11,qword ptr (log2_b_p_4-log2_b_c)[rcx]

	mulsd	xmm9,xmm8				; p3
	mulsd	xmm10,xmm8				; q3
	
	mulsd	xmm11,xmm1				; p4
	
	addsd	xmm10,xmm1				; q3+x4
	addsd	xmm9,xmm11				; p3+p4

	mulsd	xmm7,qword ptr real_0_5 ; 0.5x2

	addsd	xmm10,xmm6				; q2+q3+x4
	addsd	xmm3,xmm9				; p2+p3+p4	
	addsd	xmm10,xmm4				; q1+q2+q3+x4
	addsd	xmm2,xmm3				; p1+p2+p3+p4

	movlpd	xmm3,qword ptr real_26_bits
	movsd	xmm1,xmm5				; x

	addsd	xmm10,qword ptr (log2_b_q_0-log2_b_c)[rcx] ; q0+q1+q2+q3+x4
	addsd	xmm2,qword ptr (log2_b_p_0-log2_b_c)[rcx] ; p0+p1+p2+p3+p4

	subsd	xmm5,xmm7				; x-0.5x2

	divsd	xmm2,xmm10				; p/q

	andpd	xmm3,xmm5				; (x-0.5x2)_h
	subsd	xmm1,xmm3				; x-(x-0.5x2)_h
	subsd	xmm1,xmm7				; (x-0.5x2)_l

	mulsd	xmm2,xmm8				; (p/q)*x3

	mulsd	xmm5,qword ptr d1ln2_26_l ; (x-0.5x2) * (1/ln 2)_l
	mulsd	xmm1,qword ptr d1ln2_26 ; (x-0.5x2)_l * (1/ln 2)_h
	mulsd	xmm3,qword ptr d1ln2_26 ; (x-0.5x2)_h * (1/ln 2)_h


	movlpd	xmm6,qword ptr log2_4_d_3_53
	movsd	xmm7,xmm3				; xh
	addsd	xmm3,xmm6				; xh+(log2 4/3)_h

	addsd	xmm1,xmm5				; (x-0.5x2) * (1/ln 2)_l+(x-0.5x2)_l * (1/ln 2)_h

	subsd	xmm6,xmm3				; (log2 4/3)_h-(xh+(log2 4/3)_h)

	addsd	xmm6,xmm7				; ((log2 4/3)_h-(xh+(log2 4/3)_h))+xh
	addsd	xmm1,qword ptr log2_4_d_3_53_l ; xl+(log2 4/3)_l

	addsd	xmm1,xmm6				; (x+log2 4/3)_l

	movsd	xmm5,xmm1				; xl
	addsd	xmm1,xmm2				; xl+r
	movlpd	xmm6,qword ptr real_26_bits

	addsd	xmm1,xmm3				; xh+xl+r

	andpd	xmm1,xmm6				; (log2 x)_h
	andpd	xmm6,xmm0				; y_h

	subsd	xmm3,xmm1				; xh-(log2 x)_h
	jmp		pow_real_2

pow_real_small:
	ucomisd	xmm1,qword ptr real_2_p_m_1022
	jb		pow_real_negative_zero_denormalized_or_nan

pow_real_small_:
	ucomisd	xmm0,qword ptr real_4000_0
	jae		pow_real_underflow		; because 0.83^4000<2^-1075

	ucomisd	xmm0,qword ptr real_m_3810_0
	ja		log2_real_
	jmp		pow_real_overflow		; because 0.83^-3810>2^1024

pow_real_large:
	ucomisd	xmm1,qword ptr real_max
	ja		pow_real_inf

	ucomisd	xmm0,qword ptr real_1401_0
	jae		pow_real_overflow		; because 1.66^1401>2^1024

	ucomisd	xmm0,qword ptr real_m_1471_0
	jbe		pow_real_underflow		; because 1.66^-1471<2^-1075

log2_real_:
	movlpd	xmm2,qword ptr mask_significand
	andpd	xmm2,xmm1
	psrlq	xmm1,52

log2_real__:
	movlpd	xmm3,qword ptr real_1_0
	movlpd	xmm4,qword ptr real_0_5
	orpd	xmm3,xmm2
	orpd	xmm4,xmm2

	ucomisd	xmm3,qword ptr real_1_66

	movlpd	xmm5,qword ptr real_1_0

	ja		log2_real_l1

	ucomisd	xmm3,qword ptr real_7_d_6
	ja		pow_real_g_7_d_6

log2_real_g1:
	subsd	xmm3,xmm5

	psubq	xmm1,qword ptr qw_1023

	movsd	xmm6,xmm3				; x
	mulsd	xmm3,xmm3				; x2

	movlpd	xmm2,qword ptr log2_b_p_1
	movlpd	xmm5,qword ptr log2_b_q_1
	mulsd	xmm2,xmm6				; p1
	mulsd	xmm5,xmm6				; q1
	movsd	xmm9,xmm6				; x

	cvtdq2pd xmm4,xmm1

	movlpd	xmm1,qword ptr log2_b_p_2
	movlpd	xmm7,qword ptr log2_b_q_2
	mulsd	xmm9,xmm3				; x3
	movsd	xmm8,xmm3				; x2
	mulsd	xmm3,xmm3				; x4

	movlpd	xmm10,qword ptr log2_b_p_3
	movlpd	xmm11,qword ptr log2_b_q_3

	mulsd	xmm1,xmm8				; p2
	mulsd	xmm7,xmm8				; q2

	movlpd	xmm12,qword ptr log2_b_p_4

	mulsd	xmm10,xmm9				; p3
	mulsd	xmm11,xmm9				; q3
	
	mulsd	xmm12,xmm3				; p4
	
	addsd	xmm11,xmm3				; q3+x4
	addsd	xmm10,xmm12				; p3+p4

	mulsd	xmm8,qword ptr real_0_5 ; 0.5x2

	addsd	xmm11,xmm7				; q2+q3+x4
	addsd	xmm1,xmm10				; p2+p3+p4	
	addsd	xmm11,xmm5				; q1+q2+q3+x4
	addsd	xmm2,xmm1				; p1+p2+p3+p4

	movlpd	xmm3,qword ptr real_26_bits
	movsd	xmm1,xmm6				; x

	addsd	xmm11,qword ptr log2_b_q_0 ; q0+q1+q2+q3+x4
	addsd	xmm2,qword ptr log2_b_p_0 ; p0+p1+p2+p3+p4

log2_real_gl:
	subsd	xmm6,xmm8				; x-0.5x2

	divsd	xmm2,xmm11				; p/q

	andpd	xmm3,xmm6				; (x-0.5x2)_h
	subsd	xmm1,xmm3				; x-(x-0.5x2)_h
	subsd	xmm1,xmm8				; (x-0.5x2)_l

	mulsd	xmm2,xmm9				; (p/q)*x3

	mulsd	xmm6,qword ptr d1ln2_26_l ; (x-0.5x2) * (1/ln 2)_l
	mulsd	xmm1,qword ptr d1ln2_26 ; (x-0.5x2)_l * (1/ln 2)_h
	mulsd	xmm3,qword ptr d1ln2_26 ; (x-0.5x2)_h * (1/ln 2)_h

	addsd	xmm1,xmm6				; (x-0.5x2) * (1/ln 2)_l+(x-0.5x2)_l * (1/ln 2)_h

	movsd	xmm5,xmm1				; xl
	addsd	xmm1,xmm2				; xl+r
	movlpd	xmm6,qword ptr real_26_bits

	addsd	xmm1,xmm3				; xh+xl+r
	
	addsd	xmm1,xmm4				; e+xh+xl+r

	andpd	xmm1,xmm6				; (log2 x)_h
	andpd	xmm6,xmm0				; y_h
	
	subsd	xmm4,xmm1				; e-(log2 x)_h

	addsd	xmm3,xmm4				; e+xh-(log2 x)_h
	jmp		pow_real_2

log2_real_l1:
	subsd	xmm4,xmm5

	psubq	xmm1,qword ptr qw_1022

	movsd	xmm6,xmm4				; x
	mulsd	xmm4,xmm4				; x2

	movlpd	xmm2,qword ptr log2_s_p_1
	movlpd	xmm5,qword ptr log2_s_q_1
	mulsd	xmm2,xmm6				; p1
	mulsd	xmm5,xmm6				; q1
	movsd	xmm9,xmm6				; x

	movlpd	xmm3,qword ptr log2_s_p_2
	movlpd	xmm7,qword ptr log2_s_q_2
	mulsd	xmm9,xmm4				; x3
	movsd	xmm8,xmm4				; x2
	mulsd	xmm4,xmm4				; x4

	movlpd	xmm10,qword ptr log2_s_p_3
	movlpd	xmm11,qword ptr log2_s_q_3

	mulsd	xmm3,xmm8				; p2
	mulsd	xmm7,xmm8				; q2

	movlpd	xmm12,qword ptr log2_s_p_4

	mulsd	xmm10,xmm9				; p3
	mulsd	xmm11,xmm9				; q3
	
	mulsd	xmm12,xmm4				; p4

	addsd	xmm11,xmm4				; q3+x4
	addsd	xmm10,xmm12				; p3+p4

	mulsd	xmm8,qword ptr real_0_5 ; 0.5x2

	cvtdq2pd xmm4,xmm1

	addsd	xmm11,xmm7				; q2+q3+x4
	addsd	xmm3,xmm10				; p2+p3+p4	
	addsd	xmm11,xmm5				; q1+q2+q3+x4
	addsd	xmm2,xmm3				; p1+p2+p3+p4

	movlpd	xmm3,qword ptr real_26_bits
	movsd	xmm1,xmm6				; x

	addsd	xmm11,qword ptr log2_s_q_0 ; q0+q1+q2+q3+x4
	addsd	xmm2,qword ptr log2_s_p_0 ; p0+p1+p2+p3+p4

	jmp		log2_real_gl

pow_real_to_zero_or_nan:
	jp		pow_real_to_nan
	movlpd	xmm0,qword ptr real_1_0
	ret

pow_real_negative_zero_denormalized_or_nan:
	ucomisd	xmm1,qword ptr real_0_0
	jbe		pow_real_zero_negative_or_nan
	
	; denormalized > 0.0

pow_real_denormalized:
	ucomisd	xmm0,qword ptr real_1_052
	jae		pow_real_underflow		; because (2^-1022)^1.052<2^-1075

	ucomisd	xmm0,qword ptr real_m_1_052
	jbe		pow_real_overflow		; because (2^-1022)^-1.052>2^1075

	mulsd	xmm1,qword ptr real_2_p_55

	movlpd	xmm2,qword ptr mask_significand
	andpd	xmm2,xmm1

	movq	xmm5,qword ptr qw_55
	psrlq	xmm1,52

	psubq	xmm1,xmm5
	jmp		log2_real__

pow_real_zero_negative_or_nan:
	je		pow_real_zero_or_nan

	movlpd	xmm2,qword ptr mask_all_except_sign
	andpd	xmm2,xmm0				; |y|

	ucomisd	xmm2,qword ptr real_2_p_53
	jae		pow_real_negative_to_large_or_inf

	ucomisd	xmm2,qword ptr real_1_0
	jb		pow_real_negative_to_non_int

	movq	xmm3,qword ptr round_c
	psrlq	xmm2,52
	psubq	xmm3,xmm2

	movq	xmm4,qword ptr mask_all_one
	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm4,xmm3
	psllq	xmm5,xmm3
	andpd	xmm4,xmm0
	andpd	xmm5,xmm0				; 1 -> 2 and -1 -> -2

	ucomisd	xmm4,xmm0
	jne		pow_real_negative_to_non_int

	ucomisd	xmm5,xmm0
	je		pow_real_negative_to_even_int
	
pow_real_negative_to_odd_int:
	call	pow_real_negative_to_even_int
	movlpd	xmm1,qword ptr mask_sign
	xorpd	xmm0,xmm1
	ret

pow_real_negative_to_even_int:
	movlpd	xmm2,qword ptr mask_all_except_sign
	andpd	xmm1,xmm2				; |x|
	ucomisd	xmm1,qword ptr real_0_83 ; x>=0.83
	jae		pow_real_not_small

	ucomisd	xmm1,qword ptr real_2_p_m_1022
	jae		pow_real_small_
	jmp		pow_real_denormalized

pow_real_negative_to_large_or_inf:
	movlpd	xmm2,qword ptr mask_all_except_sign
	andpd	xmm1,xmm2				; |x|
	ucomisd	xmm1,qword ptr real_0_83
	jb		pow_real_small_to_large_or_inf	; because 0.83^(2^53) too large or small
	ucomisd	xmm1,qword ptr real_7_d_6

	movlpd	xmm2,qword ptr real_1_0

	ja		pow_real_large_to_large_or_inf	; because 1.16^(2^53) too large or small

	jmp		pow_real_between_0_83_and_7_d_6

pow_real_negative_to_non_int:
	ucomisd	xmm1,qword ptr real_m_max
	jb		pow_real_m_inf_to_non_int		; x==-inf
	movlpd	xmm0,qword ptr real_0_0
	divsd	xmm0,xmm0
	ret

pow_real_zero_or_nan:
	jp		pow_real_nan_to_non_zero
pow_real_zero:
	movlpd	xmm2,qword ptr real_1_0
	orpd	xmm2,xmm1						; 0.0 -> 1.0 and -0.0 -> -1.0
	ucomisd	xmm2,qword ptr real_0_0
	jb		pow_real_m_zero

pow_real_small_to_large_or_inf:
pow_real_m_zero_to_non_odd_int:
	ucomisd	xmm0,qword ptr real_0_0
	jb		pow_real_overflow

pow_real_inf_to_negative:
pow_real_underflow:
	movlpd	xmm0,qword ptr real_0_0
	ret

pow_real_m_inf_to_non_int:
pow_real_large_to_large_or_inf:
	ucomisd	xmm0,qword ptr real_0_0
	jb		pow_real_underflow

pow_real_overflow:
	movlpd	xmm0,qword ptr real_1_0
	divsd	xmm0,qword ptr real_0_0	; inf
	ret

pow_real_m_zero:
	movlpd	xmm2,qword ptr mask_all_except_sign
	andpd	xmm2,xmm0				; |y|

	ucomisd	xmm2,qword ptr real_2_p_53
	jae		pow_real_m_zero_to_non_odd_int

	ucomisd	xmm2,qword ptr real_m_1_0
	jb		pow_real_m_zero_to_non_odd_int

	movq	xmm4,qword ptr round_c
	psrlq	xmm2,52
	psubq	xmm4,xmm2

	movq	xmm5,qword ptr mask_all_one_except_last
	psllq	xmm5,xmm4
	andpd	xmm5,xmm0				; 1 -> 2 and -1 -> -2

	ucomisd	xmm5,xmm0
	je		pow_real_m_zero_to_non_odd_int

	ucomisd	xmm0,xmm3
	jb		pow_real_m_overflow

	movsd	xmm0,xmm1				; -0.0
	ret

pow_real_m_overflow:
	movlpd	xmm0,qword ptr real_m_1_0
	divsd	xmm0,qword ptr real_0_0	; -inf
	ret

pow_real_nan_to_non_zero:
pow_real_to_nan:
	addsd	xmm0,xmm1
	ret

pow_real_inf:
	ucomisd	xmm0,qword ptr real_0_0
	jb		pow_real_inf_to_negative
	movsd	xmm0,xmm1
	ret

pow_real_exp_too_large:
	ucomisd	xmm1,xmm2
	je		power_one_to_large_or_inf
	ja		pow_real_overflow
	jmp		pow_real_underflow

pow_real_exp_too_large_m:
	ucomisd	xmm1,xmm2
	je		power_one_to_large_or_inf_m
	jb		pow_real_overflow
	jmp		pow_real_underflow

power_one_to_large_or_inf:
	ucomisd	xmm0,qword ptr real_max
	ja		power_one_to_inf
	movsd	xmm0,xmm1
	ret

power_one_to_large_or_inf_m:
	ucomisd	xmm0,qword ptr real_m_max
	jb		power_one_to_inf_m
	movsd	xmm0,xmm1
	ret

power_one_to_inf_m:
power_one_to_inf:
	subsd	xmm0,xmm0
	ret


pow_real_g_7_d_6:
	subsd	xmm3,xmm5

	mulsd	xmm3,qword ptr real_0_75
	lea		rcx,log2_b_c
	lea		rdx,log2_s_c

	movlpd	xmm4,qword ptr real_0_25

	ucomisd	xmm3,xmm4
	subsd	xmm3,xmm4

	cmovb	rcx,rdx
	psubq	xmm1,qword ptr qw_1023

	movsd	xmm6,xmm3				; x
	mulsd	xmm3,xmm3				; x2

	movlpd	xmm2,qword ptr (log2_b_p_1-log2_b_c)[rcx]
	movlpd	xmm5,qword ptr (log2_b_q_1-log2_b_c)[rcx]
	mulsd	xmm2,xmm6				; p1
	mulsd	xmm5,xmm6				; q1
	movsd	xmm9,xmm6				; x

	cvtdq2pd xmm4,xmm1

	movlpd	xmm1,qword ptr (log2_b_p_2-log2_b_c)[rcx]
	movlpd	xmm7,qword ptr (log2_b_q_2-log2_b_c)[rcx]
	mulsd	xmm9,xmm3				; x3
	movsd	xmm8,xmm3				; x2
	mulsd	xmm3,xmm3				; x4

	movlpd	xmm10,qword ptr (log2_b_p_3-log2_b_c)[rcx]
	movlpd	xmm11,qword ptr (log2_b_q_3-log2_b_c)[rcx]

	mulsd	xmm1,xmm8				; p2
	mulsd	xmm7,xmm8				; q2

	movlpd	xmm12,qword ptr (log2_b_p_4-log2_b_c)[rcx]

	mulsd	xmm10,xmm9				; p3
	mulsd	xmm11,xmm9				; q3
	
	mulsd	xmm12,xmm3				; p4
	
	addsd	xmm11,xmm3				; q3+x4
	addsd	xmm10,xmm12				; p3+p4

	mulsd	xmm8,qword ptr real_0_5 ; 0.5x2

	addsd	xmm11,xmm7				; q2+q3+x4
	addsd	xmm1,xmm10				; p2+p3+p4	
	addsd	xmm11,xmm5				; q1+q2+q3+x4
	addsd	xmm2,xmm1				; p1+p2+p3+p4

	movlpd	xmm3,qword ptr real_26_bits
	movsd	xmm1,xmm6				; x

	addsd	xmm11,qword ptr (log2_b_q_0-log2_b_c)[rcx] ; q0+q1+q2+q3+x4
	addsd	xmm2,qword ptr (log2_b_p_0-log2_b_c)[rcx] ; p0+p1+p2+p3+p4

	subsd	xmm6,xmm8				; x-0.5x2

	addsd	xmm4,qword ptr log2_4_d_3_42 ; e+(log2 4/3)_h

	divsd	xmm2,xmm11				; p/q

	andpd	xmm3,xmm6				; (x-0.5x2)_h
	subsd	xmm1,xmm3				; x-(x-0.5x2)_h
	subsd	xmm1,xmm8				; (x-0.5x2)_l

	mulsd	xmm2,xmm9				; (p/q)*x3

	mulsd	xmm6,qword ptr d1ln2_26_l ; (x-0.5x2) * (1/ln 2)_l
	mulsd	xmm1,qword ptr d1ln2_26 ; (x-0.5x2)_l * (1/ln 2)_h
	mulsd	xmm3,qword ptr d1ln2_26 ; (x-0.5x2)_h * (1/ln 2)_h

	movsd	xmm7,xmm3				; xh
	addsd	xmm3,xmm4				; xh+e+(log2 4/3)_h

	addsd	xmm1,xmm6				; (x-0.5x2) * (1/ln 2)_l+(x-0.5x2)_l * (1/ln 2)_h

	subsd	xmm4,xmm3				; e+(log2 4/3)_h-(xh+e+(log2 4/3)_h)

	addsd	xmm4,xmm7				; (e+(log2 4/3)_h-(xh+e+(log2 4/3)_h))+xh
	addsd	xmm1,qword ptr log2_4_d_3_42_l ; xl+(log2 4/3)_l

	addsd	xmm1,xmm4				; (x+log2 4/3)_l

	movsd	xmm5,xmm1				; xl
	addsd	xmm1,xmm2				; xl+r
	movlpd	xmm6,qword ptr real_26_bits

	addsd	xmm1,xmm3				; e+xh+xl+r
	
	andpd	xmm1,xmm6				; (log2 x)_h
	andpd	xmm6,xmm0				; y_h
	
	subsd	xmm4,xmm1				; e-(log2 x)_h

	addsd	xmm3,xmm4				; e+xh-(log2 x)_h
;	jmp		pow_real_2


pow_real_2:
; xmm0 = y
; xmm1 = (log2 x)_h
; xmm2 = r
; xmm3 = (e+)xh-(log2 x)_h
; xmm5 = xl
; xmm6 = y_h
	movsd	xmm7,xmm0				; y
	subsd	xmm0,xmm6				; y_l
	mulsd	xmm6,xmm1				; p_h = y_h*(log2 x)_h

	addsd	xmm3,xmm2				; xh+r-(log2 x)_h
	mulsd	xmm0,xmm1				; y_l*(log2 x)_h

	addsd	xmm3,xmm5				; (log2 x)_l

	mulsd	xmm3,xmm7				; y*(log2 x)_l

	addsd	xmm0,xmm3				; p_l

	movsd	xmm7,xmm0				; p_l
	addsd	xmm0,xmm6				; p

exp2:
	ucomisd	xmm0,qword ptr real_m_0_5
	jb		exp2_l_n
	ucomisd	xmm0,qword ptr real_0_5
	ja		exp2_l
exp2_l_:
	ucomisd	xmm0,qword ptr real_m_0_25
	jbe		exp2_l_m_0_25
	ucomisd	xmm0,qword ptr real_0_25
	jae		exp2_g_0_25

	ucomisd	xmm0,qword ptr real_0_0

	lea		rcx,exp2_p0_c
	lea		rdx,exp2_m0_c

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2

	cmovb	rcx,rdx
exp2_:
	movlpd	xmm13,qword ptr (exp2_p0_2-exp2_p0_c)[rcx]
	movlpd	xmm14,qword ptr (exp2_p0_4-exp2_p0_c)[rcx]

	movsd	xmm2,xmm0				; x2
	mulsd	xmm0,xmm0				; x4

	mulsd	xmm13,xmm2				; p2

	movsd	xmm3,xmm1				; x
	mulsd	xmm1,xmm2				; x3

	movlpd	xmm15,qword ptr (exp2_p0_3-exp2_p0_c)[rcx]
	mulsd	xmm14,xmm0				; p4
	
	mulsd	xmm15,xmm1				; p3

	movsd	xmm4,xmm0				; x4
	mulsd	xmm0,xmm0				; x8

	movsd	xmm5,xmm2				; x2
	mulsd	xmm2,xmm1				; x5	

	mulsd	xmm5,xmm4				; x6
	mulsd	xmm1,xmm4				; x7
	mulsd	xmm4,xmm2				; x9

	mulsd	xmm0,qword ptr (exp2_p0_8-exp2_p0_c)[rcx] ; p8
	mulsd	xmm2,qword ptr (exp2_p0_5-exp2_p0_c)[rcx] ; p5
	mulsd	xmm5,qword ptr (exp2_p0_6-exp2_p0_c)[rcx] ; p6
	mulsd	xmm1,qword ptr (exp2_p0_7-exp2_p0_c)[rcx] ; p7
	mulsd	xmm4,qword ptr (exp2_p0_9-exp2_p0_c)[rcx] ; p9

	addsd	xmm0,xmm4				; p9+p8

	movlpd	xmm9,qword ptr real_26_bits
	andpd	xmm9,xmm6				; xh_h
	mulsd	xmm3,qword ptr (exp2_p0_1l-exp2_p0_c)[rcx] ; x*c1l

	addsd	xmm0,xmm1				; p9+p8+p7

	subsd	xmm6,xmm9				; xh_l
	mulsd	xmm9,qword ptr (exp2_p0_1h-exp2_p0_c)[rcx] ; p1h=xh_h*c1h

	addsd	xmm0,xmm5				; p9+p8+p7+p6

	movlpd	xmm1,qword ptr (exp2_p0_0h-exp2_p0_c)[rcx]
	addsd	xmm6,xmm7				; xh_l+x_l
	movsd	xmm4,xmm9				; p1h
	addsd	xmm9,xmm1				; p1h+c0h

	addsd	xmm0,xmm2				; p9+p8+p7+p6+p5

	mulsd	xmm6,qword ptr (exp2_p0_1h-exp2_p0_c)[rcx] ; (xh_l+x_l)*c1h
	subsd	xmm1,xmm9				; c0h-(p1h+c0h)

	addsd	xmm0,xmm14				; p9+p8+p7+p6+p5+p4

	addsd	xmm3,xmm6				; (xh_l+x_l)*c1h+x*c1l
	addsd	xmm1,xmm4				; (c0h-(p1h+c0h))+p1h

	addsd	xmm0,xmm15				; p9+p8+p7+p6+p5+p4+p3

	addsd	xmm1,xmm3

	addsd	xmm0,xmm13				; p9+p8+p7+p6+p5+p4+p3+p2

	addsd	xmm0,qword ptr (exp2_p0_0l-exp2_p0_c)[rcx]
	
	addsd	xmm0,xmm1
	addsd	xmm0,xmm9
	ret

exp2_l_m_0_25:
	movlpd	xmm1,qword ptr real_0_25
	addsd	xmm0,xmm1
	addsd	xmm6,xmm1

	lea		rcx,exp2_m0_25_c

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2
	jmp		exp2_

exp2_g_0_25:
	movlpd	xmm1,qword ptr real_0_25
	subsd	xmm0,xmm1
	subsd	xmm6,xmm1

	lea		rcx,exp2_p0_25_c

	movsd	xmm1,xmm0				; x
	mulsd	xmm0,xmm0				; x2
	jmp		exp2_

exp2_l_n:
	movlpd	xmm1,qword ptr real_m_0_5
	movq	xmm4,qword ptr m_round_c
	jmp		exp2_l_pn

exp2_l:
	movlpd	xmm1,qword ptr real_0_5
	movq	xmm4,qword ptr round_c

exp2_l_pn:
	addsd	xmm1,xmm0

	movq	xmm2,xmm1
	psrlq	xmm1,52
	psubq	xmm4,xmm1
	movq	xmm1,qword ptr mask_all_one
	psllq	xmm1,xmm4
	andpd	xmm1,xmm2

	subsd	xmm6,xmm1
	movsd	xmm0,xmm7

	cvtpd2dq xmm8,xmm1

	ucomisd	xmm1,qword ptr qword ptr real_1023
	ja		exp2_overflow0
	ucomisd	xmm1,qword ptr qword ptr real_m_1022
	jb		exp2_underflow0

	movq	xmm9,qword ptr qw_1023

	addsd	xmm0,xmm6

	paddq	xmm8,xmm9

	psllq	xmm8,52

	call	exp2_l_

	mulsd	xmm0,xmm8
	ret

exp2_overflow0:
	ucomisd	xmm1,qword ptr qword ptr real_1025
	ja		exp2_overflow

	movq	xmm9,qword ptr qw_1021

	addsd	xmm0,xmm6

	paddq	xmm8,xmm9

	psllq	xmm8,52

	call	exp2_l_

	mulsd	xmm0,xmm8
	mulsd	xmm0,qword ptr real_4_0
	ret

exp2_overflow:
	movlpd	xmm0,qword ptr qword ptr real_2_p_1023
	mulsd	xmm0,xmm0
	ret

exp2_underflow0:
	ucomisd	xmm1,qword ptr qword ptr real_m_1076
	jbe		exp2_underflow

	movq	xmm9,qword ptr qw_1078

	addsd	xmm0,xmm6

	paddq	xmm8,xmm9

	psllq	xmm8,52

	call	exp2_l_

	mulsd	xmm0,xmm8
	mulsd	xmm0,qword ptr real_2_p_m_55
	ret

exp2_underflow:
	movlpd	xmm0,qword ptr qword ptr real_0_0
	ret

_T009	ends

	_DATA segment

real_13_bits:
	dq	0ffffff0000000000h
real_14_bits:
	dq	0ffffff8000000000h
real_17_bits:
	dq	0fffffff000000000h
real_18_bits:
	dq	0fffffff800000000h
real_21_bits:
	dq	0ffffffff00000000h
real_25_bits:
	dq	0fffffffff0000000h
real_26_bits:
	dq	0fffffffff8000000h
real_27_bits:
	dq	0fffffffffc000000h
real_34_bits:
	dq	0fffffffffff80000h
real_39_bits:
	dq	0ffffffffffffc000h
real_40_bits:
	dq	0ffffffffffffe000h
real_47_bits:
	dq	0ffffffffffffffc0h
real_48_bits:
	dq	0ffffffffffffffe0h
real_49_bits:
	dq	0fffffffffffffff0h
real_50_bits:
	dq	0fffffffffffffff8h
real_51_bits:
	dq	0fffffffffffffffch

real_abs_40_bits:
	dq	07fffffffffffe000h
real_abs_39_bits:
	dq	07fffffffffffc000h

real_0_0:
	dq	 0.0
real_0_25:
	dq	 0.25
real_m_0_25:
	dq	-0.25
real_0_5:
	dq	 0.5
real_m_0_5:
	dq	-0.5
real_1_0:
	dq	 1.0
real_m_1_0:
	dq	-1.0
real_1_25:
	dq	 1.25
real_m_1_25:
	dq	-1.25
real_1_5:
	dq	 1.5
real_m_1_5:
	dq	-1.5
real_2_0:
	dq	 2.0
real_m_2_0:
	dq	-2.0
real_3_0:
	dq	 3.0
real_m_3_0:
	dq	-3.0
real_4_0:
	dq	 4.0
real_m_4_0:
	dq	-4.0
real_5_0:
	dq	 5.0
real_m_5_0:
	dq	-5.0

real_2_p_m_11:
	dq	 4.8828125E-4
real_2_p_m_12:
	dq	 2.44140625E-4
real_m_2_p_m_12:
	dq	-2.44140625E-4
real_2_p_m_13:
	dq	 1.220703125E-4
real_2_p_m_16:
	dq	 1.52587890625E-5
real_m_2_p_m_16:
	dq	-1.52587890625E-5
real_2_p_m_18:
	dq	 3.814697265625E-6
real_2_p_m_31:
	dq	4.656612873077392578125E-10

real_0_4:
	dq	 0.4
real_m_0_4:
	dq	-0.4
real_0_125:
	dq	 0.125

real_0_675:
	dq	 0.675
real_m_0_675:
	dq	-0.675
real_0_9920:
	dq	 0.9920
real_0_54000000017867999524:
	dq	 0.54000000017867999524
real_m_0_54000000017867999524:
	dq	-0.54000000017867999524
real_0_03125:
	dq	 0.03125
real_pi_d_2_m_0_03125:
	dq	 1.5395463267948965579

real_0_58:
	dq	 0.58
real_m_0_58:
	dq	-0.58
real_0_54:
	dq	 0.54
real_0_76:
	dq	 0.76
real_0_65000000004061742054:
	dq	0.65000000004061742054

real_0_26:
	dq	 0.26
real_m_0_26:
	dq	-0.26
real_0_70:
	dq	 0.70
real_m_0_70:
	dq	-0.70
real_1_4:
	dq	 1.4
real_m_1_4:
	dq	-1.4

;real_0_7025:
;	dq	0.7025
;real_1_405:
;	dq	1.405
real_0_8243:
	dq	0.82436063535006407342
real_1_6487:
	dq	1.6487212707001281468
real_0_833:
	dq	0.833
real_1_666:
	dq	1.666
real_7_d_6:
	dq	1.1666666666666667407
real_0_75:
	dq	0.75

ln_4_d_3_53:
	dq	2.8768207245178090137E-1
ln_4_d_3_53_l:
	dq	2.6071606164425639761E-17
ln_4_d_3_42:
	dq	2.8768207245173016417E-1
ln_4_d_3_42_l:
	dq	5.0763263831534079404E-14

log10_4_d_3_53:
	dq	1.2493873660829994676E-1
log10_4_d_3_53_l:
	dq	6.3704258509422005489E-18
log10_4_d_3_42:
	dq	1.2493873660829990513E-1
log10_4_d_3_42_l:
	dq	4.8003789274385573126E-17

log2_4_d_3_53:
	dq	4.1503749927884381332E-1
log2_4_d_3_53_l:
	dq	5.2244900613901090572E-18
log2_4_d_3_42:
	dq	4.1503749927881017356E-1
log2_4_d_3_42_l:
	dq	3.3644982136203633607E-14

mask_significand:
	dq	0000fffffffffffffh

real_1_66:
	dq	1.66
real_0_83:
	dq	0.83

real_pi:
	dq	 3.1415926535897931160
real_m_pi:
	dq	-3.1415926535897931160
real_pi_l:
	dq	 1.2246467991473532072E-16
real_m_pi_l:
	dq	-1.2246467991473532072E-16

real_pi_d_2:
	dq	 1.5707963267948965579
real_pi_d_2_l:
	dq	 6.1232339957367660359E-17

real_m_pi_d_2:
	dq	-1.5707963267948965579
real_m_pi_d_2_l:
	dq	-6.1232339957367660359E-17

real_pi_m_1_d_2:
	dq	1.07079632679489655800
real_pi_d_4:
	dq	 7.8539816339744827900E-1
real_m_pi_d_4:
	dq	-7.8539816339744827900E-1
real_pi_d_4_l:
	dq	 3.0616169978683830179E-17
real_m_pi_d_4_l:
	dq	-3.0616169978683830179E-17
real_pi_p_0_375_d_4:
	dq	 8.7914816339744830962E-1
real_pi_p_0_875_d_4:
	dq	 1.0041481633974482790
real_pi_p_1_5_d_4:
	dq	 1.1603981633974483096
real_3_pi_d_4:
	dq	 2.3561944901923449288
real_m_3_pi_d_4:
	dq	-2.3561944901923449288
real_5_pi_d_4:
	dq	 3.9269908169872413950
real_m_5_pi_d_4:
	dq	-3.9269908169872413950
real_7_pi_d_4:
	dq	 5.4977871437821379530
real_m_7_pi_d_4:
	dq	-5.4977871437821379530
real_9_pi_d_4:
	dq	 7.0685834705770345110
real_m_9_pi_d_4:
	dq	-7.0685834705770345110
real_3_pi_d_2:
	dq	 4.7123889803846896740
real_m_3_pi_d_2:
	dq	-4.7123889803846896740
real_3_pi_d_2_l:
	dq	 1.8369701987210296875E-16
real_m_3_pi_d_2_l:
	dq	-1.8369701987210296875E-16
real_2_pi:
	dq	 6.2831853071795862320
real_2_pi_l:
	dq	 2.4492935982947064143E-16
real_m_2_pi_l:
	dq	-2.4492935982947064143E-16

real_4_d_pi:
	dq	1.2732395447351627649
real_pi_d_4_26:
	dq	7.8539815545082092285E-1
real_pi_d_4_26_26:
	dq	7.9466273561479283671E-9
real_pi_d_4_52_l:
	dq	3.0616169978683830179E-17

real_36825084_pi:
	dq	 115689413.36222703755
real_m_36825084_pi:
	dq	-115689413.36222703755
real_36825084_pi_27:
	dq	115689413.0
real_36825084_pi_27_27:
	dq	3.6222703754901885986E-1
real_36825084_pi_54_l:
	dq	1.3588030639188803060E-17

real_pi_d_2_m_1_0_52:
	dq	 5.7079632679489655800E-1
real_1_0_m_pi_d_2_52:
	dq	-5.7079632679489655800E-1
real_pi_d_2_m_1_0_52_l:
	dq	 6.1232339957367660359E-17
real_m_pi_d_2_m_1_0_52_l:
	dq	-6.1232339957367660359E-17
real_pi_d_2_p_1_0:
	dq	 2.57079632679489655800
real_pi_d_2_p_1_0_l:
	dq	 6.1232339957367660359E-17
real_m_pi_d_2_p_1_0_l:
	dq	-6.1232339957367660359E-17

real_0_338:
	dq	 0.338
real_m_0_338:
	dq	-0.338
real_0_542:
	dq	 0.542
real_m_0_542:
	dq	-0.542
real_0_699:
	dq	 0.699
real_m_0_699:
	dq	-0.699
real_0_89:
	dq	 0.89
real_m_0_89:
	dq	-0.89
real_1_04:
	dq	 1.04
real_m_1_04:
	dq	-1.04
real_1_18:
	dq	 1.18
real_m_1_18:
	dq	-1.18

real_0_5_pi_m_1_18:
	dq	 3.9079632679489667568E-1
real_1_18_m_0_5_pi:
	dq	-3.9079632679489667568E-1
real_0_5_pi_m_1_04:
	dq	 5.3079632679489663349E-1
real_1_04_m_0_5_pi:
	dq	-5.3079632679489663349E-1
real_0_5_pi_m_0_89:
	dq	 6.8079632679489665570E-1
real_0_89_m_0_5_pi:
	dq	-6.8079632679489665570E-1

real_pi_m_1_18:
	dq	 1.9615926535897934002
real_n_pi_m_1_18:
	dq	-1.9615926535897934002
real_pi_m_1_04:
	dq	 2.1015926535897930805
real_n_pi_m_1_04:
	dq	-2.1015926535897930805
real_pi_m_0_89:
	dq	 2.2515926535897934357
real_n_pi_m_0_89:
	dq	-2.2515926535897934357
real_pi_m_0_699:
	dq	 2.4425926535897932723
real_n_pi_m_0_699:
	dq	-2.4425926535897932723
real_pi_m_0_542:
	dq	 2.5995926535897933007
real_n_pi_m_0_542:
	dq	-2.5995926535897933007
real_pi_m_0_338:
	dq	 2.8035926535897930378
real_n_pi_m_0_338:
	dq	-2.8035926535897930378

real_pi_p_0_338:
	dq	 3.4795926535897931942
real_n_pi_p_0_338:
	dq	-3.4795926535897931942
real_pi_p_0_542:
	dq	 3.6835926535897933753
real_n_pi_p_0_542:
	dq	-3.6835926535897933753
real_pi_p_0_699:
	dq	 3.8405926535897934038
real_n_pi_p_0_699:
	dq	-3.8405926535897934038
real_pi_p_0_89:
	dq	 4.0315926535897936844
real_n_pi_p_0_89:
	dq	-4.0315926535897936844
real_pi_p_1_04:
	dq	 4.1815926535897931515
real_n_pi_p_1_04:
	dq	-4.1815926535897931515
real_pi_p_1_18:
	dq	 4.3215926535897928318
real_n_pi_p_1_18:
	dq	-4.3215926535897928318

real_2pi_m_1_18:
	dq	 5.1031853071795865162
real_n_2pi_m_1_18:
	dq	-5.1031853071795865162
real_2pi_m_1_04:
	dq	 5.2431853071795861965
real_n_2pi_m_1_04:
	dq	-5.2431853071795861965
real_2pi_m_0_89:
	dq	 5.3931853071795865517
real_n_2pi_m_0_89:
	dq	-5.3931853071795865517
real_2pi_m_0_699:
	dq	 5.5841853071795863883
real_n_2pi_m_0_699:
	dq	-5.5841853071795863883
real_2pi_m_0_542:
	dq	 5.7411853071795864167
real_n_2pi_m_0_542:
	dq	-5.7411853071795864167
real_2pi_m_0_338:
	dq	 5.9451853071795861538
real_n_2pi_m_0_338:
	dq	-5.9451853071795861538

real_2pi_p_0_338:
	dq	 6.6211853071795863102
real_n_2pi_p_0_338:
	dq	-6.6211853071795863102
real_2pi_p_0_542:
	dq	 6.8251853071795869354
real_n_2pi_p_0_542:
	dq	-6.8251853071795869354
real_2pi_p_0_699:
	dq	 6.9821853071795860757
real_n_2pi_p_0_699:
	dq	-6.9821853071795860757
real_2pi_p_0_89:
	dq	 7.1731853071795868004
real_n_2pi_p_0_89:
	dq	-7.1731853071795868004

atan_0_5_53:
	dq	 4.6364760900080609352E-1
m_atan_0_5_53:
	dq	-4.6364760900080609352E-1
atan_0_5_53_l:
	dq	 2.2698777452961687092E-17

atan_sqrt_0_5:
	dq	 6.1547970867038737097E-1
m_atan_sqrt_0_5:
	dq	-6.1547970867038737097E-1
atan_sqrt_0_5_l:
	dq	-2.9904856561351187768E-17

real_h_pi_m_atan_s_2_53:
	dq	 6.1547970867038737097E-1
real_h_pi_m_atan_s_2_53_l:
	dq	-2.9904856561351187768E-17

real_sqrt_2_p_1_5_pi_m_3_atan_sqrt_2_53:
	dq	 3.2606526883842570363
real_sqrt_2_p_1_5_pi_m_3_atan_sqrt_2_53_l:
	dq	 3.5657102106448616432E-17
real_3_atan_sqrt_2_m_sqrt_2_m_1_5_pi_m_53_l:
	dq	-3.5657102106448616432E-17

atan_sqrt_2:
	dq	 9.5531661812450929805E-1
m_atan_sqrt_2:
	dq	-9.5531661812450929805E-1
atan_sqrt_2_l:
	dq	-1.9885105943796805915E-17

real_h_pi_m_atan_2_52:
	dq	 4.6364760900080603800E-1
real_h_pi_m_atan_2_52_l:
	dq	 7.8209928684219507951E-17
real_2_p_2_5_pi_m_5_atan_2_53:
	dq	 4.3182380450040307451
real_2_p_2_5_pi_m_5_atan_2_53_l:
	dq	-1.6406186889148070581E-16
real_5_atan_2_m_2_m_2_5_pi_53_l:
	dq	 1.6406186889148070581E-16

atan_2_53:
	dq	 1.1071487177940904090
m_atan_2_53:
	dq	-1.1071487177940904090
atan_2_53_l:
	dq	 9.4044713735663794124E-17
real_n_2_m_5_atan_2_53:
	dq	-3.5357435889704524890
real_n_2_m_5_atan_2_53_l:
	dq	-2.6134358828256379104E-17

real_5_atan_2_m_2_53:
	dq	 3.5357435889704524890
real_5_atan_2_m_2_53_l:
	dq	 2.6134358828256379104E-17

real_ln_2_t_0_5:
	dq	 3.4657359027997265471E-1
real_n_ln_2_t_0_5:
	dq	-3.4657359027997265471E-1
real_ln_2_t_1_5:
	dq	1.0397207708399179641
real_ln2_42:
	dq	0.69314718055989033019
real_ln2_42_l:
	dq	5.4979230187083711552E-14
real_1_d_ln2:
	dq	1.4426950408889634074

real_log2_10_42:
	dq	0.30102999566395283182
real_log2_10_42_l:
	dq	2.8363394551044964154E-14

;d1ln10:
;	dq	4.3429448190325181667E-1
d1ln10_26:
	dq	4.3429447710514068603E-1
d1ln10_26_l:
	dq	4.7981111416159728067E-9

;d1ln2:
;	dq	1.4426950408889633870
d1ln2_26:
	dq	1.4426950216293334961
d1ln2_26_l:
	dq	1.9259629911266174689E-8

	align	16
round_c:
	dq		3ffh+52
	dq		3ffh+52
m_round_c:
	dq		0bffh+52
	dq		0bffh+52
round_even_c:
	dq		3ffh+53
	dq		3ffh+53
m_round_even_c:
	dq		0bffh+53
	dq		0bffh+53
mask_all_one:
	dq		-1
	dq		-1
mask_all_one_except_last:
	dq		-2
	dq		-2
mask_all_one_except_second_last:
	dq		-3
	dq		-3
qw_1023:
	dq		3ffh
	dq		3ffh
qw_1022:
	dq		3feh
	dq		3feh
qw_1021:
	dq		3fdh
	dq		3fdh
qw_1077:
	dq		3ffh+54
	dq		3ffh+54
qw_1078:
	dq		3ffh+55
	dq		3ffh+55
qw_55:
	dq		55
	dq		55
mask_sign:
	dq		08000000000000000h
	dq		08000000000000000h
mask_all_except_sign:
	dq		07fffffffffffffffh
	dq		07fffffffffffffffh

real_0_43540000008249979402:
	dq	 0.43540000008249979402
real_m_0_43540000008249979402:
	dq	-0.43540000008249979402
real_0_600000000082499762577:
	dq	 0.600000000082499762577
real_m_0_600000000082499762577:
	dq	-0.600000000082499762577

;sin_p_0:
;	dq	-1.6666666666666629659E-1
;sin_p_1:
;	dq	 8.3333333333220592498E-3
;sin_p_2:
;	dq	-1.9841269829591994520E-4
;sin_p_3:
;	dq	 2.7557313627980839565E-6
;sin_p_4:
;	dq	-2.5050749232606622552E-8
;sin_p_5:
;	dq	 1.5896334589820396677E-10

sin_p_0:
	dq	-1.6666666666666635210E-1
sin_p_1:
	dq	 8.3333333333230012047E-3
sin_p_2:
	dq	-1.9841269830204560616E-4
sin_p_3:
	dq	 2.7557313816586650493E-6
sin_p_4:
	dq	-2.5050776321203382309E-8
sin_p_5:
	dq	 1.5897788850050641142E-10

sin_p1_c:
sin_p1_0h:
	dq	 5.6464247346312534948E-1
sin_p1_0l:
	dq	-6.06241788103829245082E-24
sin_p1_1h:
	dq	 8.2533560693264007568E-1
sin_p1_1l:
	dq	 7.9304552924597260244E-9
sin_p1_2:
	dq	-2.8232123673155168353E-1
sin_p1_3:
	dq	-1.3755593581121927649E-1
sin_p1_4:
	dq	 2.3526769749636338575E-2
sin_p1_5:
	dq	 6.8777964033410682668E-3
sin_p1_6:
	dq	-7.8422158064252829243E-4
sin_p1_7:
	dq	-1.6378316139497952112E-4
sin_p1_8:
	dq	 1.4102652890564176127E-5
sin_p1_9:
	dq	 2.0754701007995074451E-6

sin_p2_c:
sin_p2_0h:
	dq	 5.6464247346312534948E-1
sin_p2_0l:
	dq	-6.06241788103829245082E-24
sin_p2_1h:
	dq	 8.2533560693264007568E-1
sin_p2_1l:
	dq	 7.9304554034820284869E-9
sin_p2_2:
	dq	-2.8232123673155273824E-1
sin_p2_3:
	dq	-1.3755593580986152924E-1
sin_p2_4:
	dq	 2.3526769748731638648E-2
sin_p2_5:
	dq	 6.8777971733520841535E-3
sin_p2_6:
	dq	-7.8422151328288352071E-4
sin_p2_7:
	dq	-1.6373002515216467253E-4
sin_p2_8:
	dq	 1.4106512050855138886E-5
sin_p2_9:
	dq	 2.4764422854631738044E-6

sin_p3_c:
sin_p3_0h:
	dq	-5.6464247346312534948E-1
sin_p3_0l:
	dq	 6.06241788103829245082E-24
sin_p3_1h:
	dq	 8.2533560693264007568E-1
sin_p3_1l:
	dq	 7.9304552924597260244E-9
sin_p3_2:
	dq	 2.8232123673155168353E-1
sin_p3_3:
	dq	-1.3755593581121927649E-1
sin_p3_4:
	dq	-2.3526769749636338575E-2
sin_p3_5:
	dq	 6.8777964033410682668E-3
sin_p3_6:
	dq	 7.8422158064252829243E-4
sin_p3_7:
	dq	-1.6378316139497952112E-4
sin_p3_8:
	dq	-1.4102652890564176127E-5
sin_p3_9:
	dq	 2.0754701007995074451E-6

sin_p4_c:
sin_p4_0h:
	dq	-5.6464247346312534948E-1
sin_p4_0l:
	dq	 6.06241788103829245082E-24
sin_p4_1h:
	dq	 8.2533560693264007568E-1
sin_p4_1l:
	dq	 7.9304554034820284869E-9
sin_p4_2:
	dq	 2.8232123673155273824E-1
sin_p4_3:
	dq	-1.3755593580986152924E-1
sin_p4_4:
	dq	-2.3526769748731638648E-2
sin_p4_5:
	dq	 6.8777971733520841535E-3
sin_p4_6:
	dq	 7.8422151328288352071E-4
sin_p4_7:
	dq	-1.6373002515216467253E-4
sin_p4_8:
	dq	-1.4106512050855138886E-5
sin_p4_9:
	dq	 2.4764422854631738044E-6

cos_p_0:
	dq	 4.1666666666666588026E-2
cos_p_1:
	dq	-1.3888888888872778175E-3
cos_p_2:
	dq	 2.4801587288764459412E-5
cos_p_3:
	dq	-2.7557314167050702998E-7
cos_p_4:
	dq	 2.0875701408714520036E-9
cos_p_5:
	dq	-1.1358718309736171193E-11

; .. .5854
;tan_p_0:
;	dq	-18086151.600729089230
;tan_p_1:
;	dq	 1161461.5827075217385
;tan_p_2:
;	dq	-13169.960960193349820
;tan_q_0:
;	dq	-54258454.802187263966
;tan_q_1:
;	dq	 25187766.668997306377
;tan_q_2:
;	dq	-1329914.3444088697433
;tan_q_3:
;	dq	 13760.338151945812569

; .. .338
tan_p_0:
	dq	-18191117.789276178926
tan_p_1:
	dq	 1167963.0645372841973
tan_p_2:
	dq	-13234.676172752202547
tan_q_0:
	dq	-54573353.367828540504
tan_q_1:
	dq	 25333230.540743269026
tan_q_2:
	dq	-1337310.4614476819988
tan_q_3:
	dq	 13827.503083158084337

; ..7854
;tan2_p_0:
;	dq	 3.3283674370620949801E-2
;tan2_p_1:
;	dq	 2.5663601402049946582E-2
;tan2_p_2:
;	dq	-3.1180502523212879186E-4
;tan2_p_3:
;	dq	 4.9814468378033982921E-7
;tan2_q_0:
;	dq	-1.3338299229604572149E-1
;tan2_q_1:
;	dq	 3.4248261922569253959E-3
;tan2_q_2:
;	dq	-1.7860673544716858919E-5

; ..3678
;tan2_p_0:
;	dq	 3.3322645703933846673E-2
;tan2_p_1:
;	dq	 2.5645883816593488536E-2
;tan2_p_2:
;	dq	-3.1101629629724883994E-4
;tan2_p_3:
;	dq	 4.9436497805178155231E-7
;tan2_q_0:
;	dq	-1.3334402096273281768E-1
;tan2_q_1:
;	dq	 3.4200990512379442383E-3
;tan2_q_2:
;	dq	-1.7781628650750523380E-5

; ..3908
tan2_p_0:
	dq	 3.3321283446731200795E-2
tan2_p_1:
	dq	 2.5646503068216856824E-2
tan2_p_2:
	dq	-3.1104383115385493899E-4
tan2_p_3:
	dq	 4.9449499280323978810E-7
tan2_q_0:
	dq	-1.3334538321993547050E-1
tan2_q_1:
	dq	 3.4202642171272572627E-3
tan2_q_2:
	dq	-1.7784380596478880932E-5

; .. .2
tan3_p_0:
	dq	-18224747.034562580287
tan3_p_1:
	dq	 1170032.8518652219791
tan3_p_2:
	dq	-13254.922404240271135
tan3_q_0:
	dq	-54674241.103687740862
tan3_q_1:
	dq	 25379794.997070763260
tan3_q_2:
	dq	-1339662.7778249811381
tan3_q_3:
	dq	 13848.512058865804647

tan_0_5_t:
	dq	 1.25
	dq	 0.5
real_0_5_m_1_25_atan_0_5_49_l:
	dq	-1.8102913770216112547E-16
real_0_5_m_1_25_atan_0_5_49:
	dq	-7.9559511251007464239E-2

tan_n_0_5_t:
	dq	 1.25
	dq	-0.5
real_1_25_atan_0_5_m_0_5_49_l:
	dq	 1.8102913770216112547E-16
real_1_25_atan_0_5_m_0_5_49:
	dq	 7.9559511251007464239E-2

tan_s_0_5_t:
	dq	1.5
sqrt_0_5:
	dq	 7.07106781186547572737E-1
sqrtn_0_5_m_1_5_atann_sqrt_0_5_l:
	dq	-3.4791817252377832918E-18
sqrtn_0_5_m_1_5_atann_sqrt_0_5:
	dq	-2.1611278181903348372E-1

tan_n_s_0_5_t:
	dq	1.5
n_sqrt_0_5:
	dq	-7.07106781186547572737E-1
n_sqrtn_0_5_m_1_5_atann_sqrt_0_5_l:
	dq	 3.4791817252377832918E-18
n_sqrtn_0_5_m_1_5_atann_sqrt_0_5:
	dq	 2.1611278181903348372E-1

tan_s_2_t:
	dq	3.0
sqrt_2_0:
	dq	 1.4142135623730951455
sqrt_2_m_3_atan_sqrt_2_l:
	dq	 7.4004687159376949604E-17
sqrt_2_m_3_atan_sqrt_2:
	dq	-1.4517362920004328597

tan_n_s_2_t:
	dq	3.0
n_sqrt_2_0:
	dq	-1.4142135623730951455
n_sqrt_2_m_3_atan_sqrt_2_l:
	dq	-7.4004687159376949604E-17
n_sqrt_2_m_3_atan_sqrt_2:
	dq	 1.4517362920004328597

; .. 0.55
;asin_p_0:
;	dq	-25.316696852169688014
;asin_p_1:
;	dq	 53.530200010422156254
;asin_p_2:
;	dq	-37.683203270692622766
;asin_p_3:
;	dq	 9.8280386103977175338
;asin_p_4:
;	dq	-0.6933246588625101570
;asin_q_0:
;	dq	-151.90018111301861836
;asin_q_1:
;	dq	 389.53628156345331490
;asin_q_2:
;	dq	-360.70299781814912876
;asin_q_3:
;	dq	 144.63464250990605819
;asin_q_4:
;	dq	-23.247871426450686272

asin_p_0:
	dq	-31.133659782158286333
asin_p_1:
	dq	 63.858157457633225818
asin_p_2:
	dq	-43.244454939408448979
asin_p_3:
	dq	 10.711904434851501122
asin_p_4:
	dq	-0.7023102565817557208
asin_q_0:
	dq	-186.80195869294971089
asin_q_1:
	dq	 467.20982615762636669
asin_q_2:
	dq	-419.67491247177241576
asin_q_3:
	dq	 162.03208845920067915
asin_q_4:
	dq	-24.808857438965841169

asin_c:

asin2_p_0:
	dq	 31.367022265271895520
asin2_p_1:
	dq	-27.553457288163915706
asin2_p_2:
	dq	 7.3142287109234631615
asin2_p_3:
	dq	-0.5695539268055010984
asin2_p_4:
	dq	 2.7732700457810590539E-3
asin2_q_0:
	dq	 376.40426718326244782
asin2_q_1:
	dq	-415.33244757417799065
asin2_q_2:
	dq	 156.01490234281396852
asin2_q_3:
	dq	-22.702479601946876642

; 0.55 ..
;asin2_p_0:
;	dq	 29.355358314463529723
;asin2_p_1:
;	dq	-26.147018538045006864
;asin2_p_2:
;	dq	 7.0703500716163327766
;asin2_p_3:
;	dq	-0.5652641176899680930
;asin2_p_4:
;	dq	 2.9079909341710704143E-3
;asin2_q_0:
;	dq	 352.26429977355559231
;asin2_q_1:
;	dq	-393.02368990519767067
;asin2_q_2:
;	dq	 149.68540386246363028
;asin2_q_3:
;	dq	-22.170690309691252651

asin_p1_c:
asin_p1_0h:
	dq	 5.7043710961221538724E-1
asin_p1_0l:
	dq	 4.9248428721475757358E-23
asin_p1_1h:
	dq	 1.1881211400032043457
asin_p1_1l:
	dq	 1.4630145983574038837E-9
asin_p1_2:
	dq	 4.5284120326143617596E-1
asin_p1_3:
	dq	 6.2472394124586794195E-1
asin_p1_4:
	dq	 8.0835086833083236169E-1
asin_p1_5:
	dq	 1.2595104015172415846
asin_p1_6:
	dq	 2.0488537552293428767
asin_p1_7:
	dq	 3.5089140995443472981
asin_p1_8:
	dq	 6.2851334414813333495
asin_p1_9:
	dq	 10.128040933414240499
asin_p1_10:
	dq	 33.046781180882994988
asin_p1_11:
	dq	-52.817309641779630169
asin_p1_12:
	dq	 540.99494117159986217
asin_p1_13:
	dq	-1326.1434641099594955
asin_p1_14:
	dq	 2612.6799241572512074

asin_p2_c:
asin_p2_0h:
	dq	 5.7043710961221538724E-1
asin_p2_0l:
	dq	 4.9248428721475757358E-23
asin_p2_1h:
	dq	 1.1881211400032043457
asin_p2_1l:
	dq	 1.4630165967588482090E-9
asin_p2_2:
	dq	 4.5284120325997734291E-1
asin_p2_3:
	dq   6.2472394155362398482E-1
asin_p2_4:
	dq	 8.0835082941011759949E-1
asin_p2_5:
	dq	 1.2595128937378745615
asin_p2_6:
	dq	 2.0487338667125807312
asin_p2_7:
	dq	 3.5123184925937764866
asin_p2_8:
	dq	 6.2076105483454178113
asin_p2_9:
	dq	 11.227381892153145415
asin_p2_10:
	dq	 20.429661082626292767
asin_p2_11:
	dq	 35.926476241524127886
asin_p2_12:
	dq	 55.782391042293575367
asin_p2_13:
	dq	 64.653236450484357078
asin_p2_14:
	dq	 39.681910714502151905

asin_p3_c:
asin_p3_0h:
	dq	-5.7043710961221538724E-1
asin_p3_0l:
	dq	-4.9248428721475757358E-23
asin_p3_1h:
	dq	 1.1881211400032043457
asin_p3_1l:
	dq	 1.4630145983574038837E-9
asin_p3_2:
	dq	-4.5284120326143617596E-1
asin_p3_3:
	dq	 6.2472394124586794195E-1
asin_p3_4:
	dq	-8.0835086833083236169E-1
asin_p3_5:
	dq	 1.2595104015172415846
asin_p3_6:
	dq	-2.0488537552293428767
asin_p3_7:
	dq	 3.5089140995443472981
asin_p3_8:
	dq	-6.2851334414813333495
asin_p3_9:
	dq	 10.128040933414240499
asin_p3_10:
	dq	-33.046781180882994988
asin_p3_11:
	dq	-52.817309641779630169
asin_p3_12:
	dq	-540.99494117159986217
asin_p3_13:
	dq	-1326.1434641099594955
asin_p3_14:
	dq	-2612.6799241572512074

asin_p4_c:
asin_p4_0h:
	dq	-5.7043710961221538724E-1
asin_p4_0l:
	dq	-4.9248428721475757358E-23
asin_p4_1h:
	dq	 1.1881211400032043457
asin_p4_1l:
	dq	 1.4630165967588482090E-9
asin_p4_2:
	dq	-4.5284120325997734291E-1
asin_p4_3:
	dq   6.2472394155362398482E-1
asin_p4_4:
	dq	-8.0835082941011759949E-1
asin_p4_5:
	dq	 1.2595128937378745615
asin_p4_6:
	dq	-2.0487338667125807312
asin_p4_7:
	dq	 3.5123184925937764866
asin_p4_8:
	dq	-6.2076105483454178113
asin_p4_9:
	dq	 11.227381892153145415
asin_p4_10:
	dq	-20.429661082626292767
asin_p4_11:
	dq	 35.926476241524127886
asin_p4_12:
	dq	-55.782391042293575367
asin_p4_13:
	dq	 64.653236450484357078
asin_p4_14:
	dq	-39.681910714502151905

acos_p_0:
	dq	-23.490891740111308650
acos_p_1:
	dq	 50.216364730997767651
acos_p_2:
	dq	-35.846130541173899076
acos_p_3:
	dq	 9.5237685361261430472
acos_p_4:
	dq	-0.68995264971619463257
acos_q_0:
	dq	-140.94535044067245622
acos_q_1:
	dq	 364.72359608470605963
acos_q_2:
	dq	-341.44918263146718118
acos_q_3:
	dq	 138.79408611688072028
acos_q_4:
	dq	-22.704016182082593645

acos2_p_0:
	dq	 30.187145498002834643
acos2_p_1:
	dq	-26.731562531992352660
acos2_p_2:
	dq	 7.1724615825161839311
acos2_p_3:
	dq	-0.56708755287485912433
acos2_p_4:
	dq	 2.8497262016782816223E-3
acos2_q_0:
	dq	 362.24574597603304937
acos2_q_1:
	dq	-402.28404322843209684
acos2_q_2:
	dq	 152.32592108178161538
acos2_q_3:
	dq	-22.394016829865698526

acos_p1_c:
acos_p1_0h:
	dq	 8.6321189001609244240E-1
acos_p1_0l:
	dq	-2.7467628254551864260E-23
acos_p1_1h:
	dq	-1.3159033656120300293
acos_p1_1l:
	dq	-2.4367664774871400368E-8
acos_p1_2:
	dq	-7.4055169144604560127E-1
acos_p1_3:
	dq	-1.2132914821382745352
acos_p1_4:
	dq	-2.1344587603015683364
acos_p1_5:
	dq	-4.3088049195660635959
acos_p1_6:
	dq	-9.2462207583022237856
acos_p1_7:
	dq	-20.778559358953092584
acos_p1_8:
	dq	-48.776431616826357640
acos_p1_9:
	dq	-105.97079800530472937
acos_p1_10:
	dq	-413.00216737064670269
acos_p1_11:
	dq	662.354234414432198719
acos_p1_12:
	dq	-11016.701631003812508
acos_p1_13:
	dq	35318.9338646810210776
acos_p1_14:
	dq	-97099.956120653485414

acos_p2_c:
acos_p2_0h:
	dq	 8.6321189001609244240E-1
acos_p2_0l:
	dq	-2.7467628254551864260E-23
acos_p2_1h:
	dq	-1.3159033656120300293
acos_p2_1l:
	dq	-2.4367664108737585593E-8
acos_p2_2:
	dq	-7.4055169144296173478E-1
acos_p2_3:
	dq	-1.2132914822347449224
acos_p2_4:
	dq	-2.1344586500282272112
acos_p2_5:
	dq	-4.3088086958273930094
acos_p2_6:
	dq	-9.2457168210006930309
acos_p2_7:
	dq	-20.790839559740305731
acos_p2_8:
	dq	-48.251128736941033992
acos_p2_9:
	dq	-114.02209884122218853
acos_p2_10:
	dq	-267.05630398433208939
acos_p2_11:
	dq	-584.65850073182002689
acos_p2_12:
	dq	-1076.6291620946751664
acos_p2_13:
	dq	-1407.9468675552657260
acos_p2_14:
	dq	-936.98633843723951031

atan4_p_c:
atan4_p_0:
	dq	-51.285593469956815227
atan4_p_1:
	dq	-100.64117630107490697
atan4_p_2:
	dq	-64.297908354955467303
atan4_p_3:
	dq	-14.727705326536764119
atan4_p_4:
	dq	-0.8688437904180191795
atan4_q_0:
	dq	 153.85678040987045279
atan4_q_1:
	dq	 394.23759714914689312
atan4_q_2:
	dq	 363.49766317870364674
atan4_q_3:
	dq	 144.60833714965690433
atan4_q_4:
	dq	 23.038413151078877661

n_45_d_256:
	dq	 0.175781250000
n_m_45_d_256:
	dq	-0.175781250000

atan_p_9_0:
	dq	-3.3333333333333309279E-1
atan_p_9_1:
	dq	 1.9999999999984593990E-1
atan_p_9_2:
	dq	-1.4285714282482467330E-1
atan_p_9_3:
	dq	 1.1111110782523182794E-1
atan_p_9_4:
	dq	-9.0908902574698829957E-2
atan_p_9_5:
	dq	 7.6916554867419328900E-2
atan_p_9_6:
	dq	-6.6526935532345926605E-2
atan_p_9_7:
	dq	 5.6999867343679795628E-2
atan_p_9_8:
	dq	-3.9093313704495452621E-2

atan_0_5_52:
	dq	 4.6364760900080603800E-1
atan_0_5_52_l:
	dq	 7.8209928684219507951E-17
atan_0_5_real_0_5:
	dq	 0.5

n_atan_0_5_52:
	dq	-4.6364760900080603800E-1
n_atan_0_5_52_l:
	dq	-7.8209928684219507951E-17
n_atan_0_5_real_0_5:
	dq	-0.5

atan_n_0_5_8_c:
atan_n_0_5_8_0:
	dq	-3.3333333333333192705E-1
atan_n_0_5_8_1:
	dq	 1.9999999999920992089E-1
atan_n_0_5_8_2:
	dq	-1.4285714269165267210E-1
atan_n_0_5_8_3:
	dq	 1.1111109349119581424E-1
atan_n_0_5_8_4:
	dq	-9.0908019792184269203E-2
atan_n_0_5_8_5:
	dq	 7.6884259191928067123E-2
atan_n_0_5_8_6:
	dq	-6.5833773159939656949E-2
atan_n_0_5_8_7:
	dq	 4.8945313616423499758E-2

atan_1_53:
	dq	 7.8539816339744827900E-1
atan_1_53_l:
	dq	 3.0616169978683830179E-17

n_atan_1_53:
	dq	-7.8539816339744827900E-1
n_atan_1_53_l:
	dq	-3.0616169978683830179E-17

atan_n_8_c:
atan_n_8_0:
	dq	-3.3333333333333325932E-1
atan_n_8_1:
	dq	 1.9999999999993750555E-1
atan_n_8_2:
	dq	-1.4285714283792697032E-1
atan_n_8_3:
	dq	 1.1111110814149251225E-1
atan_n_8_4:
	dq	-9.0908830368634924168E-2
atan_n_8_5:
	dq	 7.6909493951295496150E-2
atan_n_8_6:
	dq	-6.6248652556378059830E-2
atan_n_8_7:
	dq	 5.1752788427847688790E-2
atan_n_8_real_40_bits:
	dq	0ffffffffffffe000h
atan_n_8_real_abs_40_bits:
	dq	07fffffffffffe000h
atan_n_8_real_2_p_m_12:
	dq	 2.44140625E-4

atan_p_8_c:
atan_p_8_0:
	dq	-3.3333333333333331483E-1
atan_p_8_1:
	dq	 1.9999999999997875033E-1
atan_p_8_2:
	dq	-1.4285714284904510452E-1
atan_p_8_3:
	dq	 1.1111110961868993219E-1
atan_p_8_4:
	dq	-9.0908937814301260527E-2
atan_p_8_5:
	dq	 7.6913854250452912131E-2
atan_p_8_6:
	dq	-6.6341308897488418528E-2
atan_p_8_7:
	dq	 5.2556144706942850564E-2
atan_p_8_real_39_bits:
	dq	0ffffffffffffc000h
atan_p_8_abs_real_39_bits:
	dq	07fffffffffffc000h
atan_p_8_real_2_p_m_12:
	dq	2.44140625E-4

atan_2_0:
	dq	 1.1071487177940904090
atan_2_0_l:
	dq	 9.4044713735663794124E-17
atan_2_0_real_2_0:
	dq	 2.0

n_atan_2_0:
	dq	-1.1071487177940904090
n_atan_2_0_l:
	dq	-9.4044713735663794124E-17
n_atan_2_0_real_2_0:
	dq	-2.0

atan_n_2_8_c:
atan_n_2_8_0:
	dq	-3.3333333333333042825E-1
atan_n_2_8_1:
	dq	 1.9999999999849707444E-1
atan_n_2_8_2:
	dq	-1.4285714256949089140E-1
atan_n_2_8_3:
	dq	 1.1111108323968375833E-1
atan_n_2_8_4:
	dq	-9.0907550811429177484E-2
atan_n_2_8_5:
	dq	 7.6872320463257509671E-2
atan_n_2_8_6:
	dq	-6.5674898157514843833E-2
atan_n_2_8_7:
	dq	 4.8083662211730243685E-2

real_atan_large:
	dq	 5805358775541310.0840
real_atan_m_large:
	dq	-5805358775541310.0840

exp_p0_c:
exp_p0_2:
	dq	4.9999999999999900080E-1
exp_p0_3:
	dq	1.6666666666678625619E-1
exp_p0_4:
	dq	4.1666666661027668139E-2
exp_p0_5:
	dq	8.3333334724719175524E-3
exp_p0_6:
	dq	1.3888868951434380893E-3
exp_p0_7:
	dq	1.9842988288729944998E-4
exp_p0_8:
	dq	2.4713876429938641863E-5
exp_p0_9:
	dq	2.9988651596576767477E-6

exp_p1_c:
exp_p1_0:
	dq	 1.1921772413532716328
exp_p1_0_l:
	dq	-5.3111925243256501606E-17
exp_p1_1_h:
	dq	 1.1921772360801696777
exp_p1_1_l:
	dq	 5.2731019550833480025E-9
exp_p1_2:
	dq	 5.9608862067662515827E-1
exp_p1_3:
	dq	 1.9869620689294639759E-1
exp_p1_4:
	dq	 4.9674051698174313818E-2
exp_p1_5:
	dq	 9.9348108199627475218E-3
exp_p1_6:
	dq	 1.6557962681130399766E-3
exp_p1_7:
	dq	 2.3658136938083061391E-4
exp_p1_8:
	dq	 2.9408132193586159414E-5
exp_p1_9:
	dq	 3.6463907908503166658E-6

exp_m0_c:
exp_m0_2:
	dq	4.9999999999999916733E-1
exp_m0_3:
	dq	1.6666666666656548834E-1
exp_m0_4:
	dq	4.1666666661841822439E-2
exp_m0_5:
	dq	8.3333332132295139666E-3
exp_m0_6:
	dq	1.3888871537291139647E-3
exp_m0_7:
	dq	1.9839759941175428605E-4
exp_m0_8:
	dq	2.4723414228338120148E-5
exp_m0_9:
	dq	2.5328445339119633100E-6

exp_m1_c:
exp_m1_0:
	dq	 8.3880145108698256351E-1
exp_m1_0_l:
	dq	-3.1258096785010882408E-17
exp_m1_1_h:
	dq	 8.3880144357681274414E-1
exp_m1_1_l:
	dq	 7.5101698193691390770E-9
exp_m1_2:
	dq	 4.1940072554349638878E-1
exp_m1_3:
	dq	 1.3980024184811054577E-1
exp_m1_4:
	dq	 3.4950060469065312441E-2
exp_m1_5:
	dq	 6.9900121811488523035E-3
exp_m1_6:
	dq	 1.1650024396098284090E-3
exp_m1_7:
	dq	 1.6642701498218752582E-4
exp_m1_8:
	dq	 2.0771521593253968396E-5
exp_m1_9:
	dq	 2.1676257763527338661E-6

; ln < 1

;ln_s_c:
;ln_s_p_0:
;	dq	9.1503481690678860616
;ln_s_p_1:
;	dq	20.941485866336655874
;ln_s_p_2:
;	dq	16.487417954606193859
;ln_s_p_3:
;	dq	5.1186080224958212526
;ln_s_p_4:
;	dq	4.9845734945458103349E-1
;ln_s_q_0:
;	dq	27.451044507203782530
;ln_s_q_1:
;	dq	83.412740979424398802
;ln_s_q_2:
;	dq	95.551182894484938402
;ln_s_q_3:
;	dq	50.697088912299392405
;ln_s_q_4:
;	dq	12.129116214794825268

; ln .83 .. 1

;ln_s_c:
;ln_s_p_0:
;	dq	10.602228952834687803
;ln_s_p_1:
;	dq	23.654147261303222649
;ln_s_p_2:
;	dq	18.048399385285609497
;ln_s_p_3:
;	dq	5.3866317747411187611
;ln_s_p_4:
;	dq	4.9866367203621170257E-1
;ln_s_q_0:
;	dq	31.806686858504065185
;ln_s_q_1:
;	dq	94.817456927787816312
;ln_s_q_2:
;	dq	106.17427873659880788
;ln_s_q_3:
;	dq	54.803473649357279385
;ln_s_q_4:
;	dq	12.671320252177885379

; ln .8243 .. 1

ln_s_c:
ln_s_p_0:
	dq	10.533214407052481576
ln_s_p_1:
	dq	23.526643885226203423
ln_s_p_2:
	dq	17.976077060886193948
ln_s_p_3:
	dq	5.3744490269565492468
ln_s_p_4:
	dq	4.9865516811442134326E-1
ln_s_q_0:
	dq	31.599643221157446504
ln_s_q_1:
	dq	94.279664071546818604
ln_s_q_2:
	dq	105.67819330362900132
ln_s_q_3:
	dq	54.614015226380423940
ln_s_q_4:
	dq	12.646688742839442554

; ln >= 1

;ln_b_c:
;ln_b_p_0:
;	dq	17.467871503051810578
;ln_b_p_1:
;	dq	35.785852544901331385
;ln_b_p_2:
;	dq	24.552006690337957906
;ln_b_p_3:
;	dq	6.4047236758045062999
;ln_b_p_4:
;	dq	4.9917096570160635061E-1
;ln_b_q_0:
;	dq	52.403614509155588053
;ln_b_q_1:
;	dq	146.66026851655587393
;ln_b_q_2:
;	dq	152.20905275348258101
;ln_b_q_3:
;	dq	71.576606726420877180
;ln_b_q_4:
;	dq	14.725978745938864023

; ln 1.0 .. 1.25

ln_b_c:
ln_b_p_0:
	dq	15.580409683056638315
ln_b_p_1:
	dq	32.543914666072645048
ln_b_p_2:
	dq	22.877901706403754645
ln_b_p_3:
	dq	6.1556714513765760088
ln_b_p_4:
	dq	4.9907618814155391140E-1
ln_b_q_0:
	dq	46.741229049169916721
ln_b_q_1:
	dq	132.68766578509504939
ln_b_q_2:
	dq	140.10471702854880505
ln_b_q_3:
	dq	67.303567178530471438
ln_b_q_4:
	dq	14.223951326720150945

; log10 < 1

;log10_s_c:
;log10_s_p_0:
;	dq	3.9766162055986344903
;log10_s_p_1:
;	dq	9.0998450829915000782
;log10_s_p_2:
;	dq	7.1633761863796170388
;log10_s_p_3:
;	dq	2.2235094671281157019
;log10_s_p_4:
;	dq	2.1647774010462134120E-1
;log10_s_q_0:
;	dq	27.469491586710010012
;log10_s_q_1:
;	dq	83.461621599998238707
;log10_s_q_2:
;	dq	95.597370915186246521
;log10_s_q_3:
;	dq	50.715260287037992271
;log10_s_q_4:
;	dq	12.131569554734877414

; log10 .83 .. 1

log10_s_c:
log10_s_p_0:
	dq	4.6028186381430433727
log10_s_p_1:
	dq	10.269763424759014825
log10_s_p_2:
	dq	7.8365495824134949743
log10_s_p_3:
	dq	2.3390837249823710486
log10_s_p_4:
	dq	2.1656666260147883207E-1
log10_s_q_0:
	dq	31.795144745829979627
log10_s_q_1:
	dq	94.787371070649314220
log10_s_q_2:
	dq	106.14640820241447727
log10_s_q_3:
	dq	54.792773831672434426
log10_s_q_4:
	dq	12.669919891359308295

; log10 >= 1

;log10_b_c:
;log10_b_p_0:
;	dq	7.5811637929542987635
;log10_b_p_1:
;	dq	15.533033113504695066
;log10_b_p_2:
;	dq	10.658434759740712749
;log10_b_p_3:
;	dq	2.7808975967872808788
;log10_b_p_4:
;	dq	2.1678697192356721768E-1
;log10_b_q_0:
;	dq	52.368824211608433927
;log10_b_q_1:
;	dq	146.57500964710882840
;log10_b_q_2:
;	dq	152.13582168617784873
;log10_b_q_3:
;	dq	71.551032626191883423
;log10_b_q_4:
;	dq	14.723015954370795910

; log10 1 .. 1.25

log10_b_c:
log10_b_p_0:
	dq	6.7674014091633534207
log10_b_p_1:
	dq	14.135207984866871911
log10_b_p_2:
	dq	9.9365500005391176330
log10_b_p_3:
	dq	2.6734926843772655047
log10_b_p_4:
	dq	2.1674607755999492076E-1
log10_b_q_0:
	dq	46.747552809139307328
log10_b_q_1:
	dq	132.70322218382881374
log10_b_q_2:
	dq	140.11814067349982338
log10_b_q_3:
	dq	67.308281802680511419
log10_b_q_4:
	dq	14.224501421540916013

log2_b_c:
log2_b_p_0:
	dq	 5.7248655744376097942
log2_b_p_1:
	dq	 9.7037982066316619267
log2_b_p_2:
	dq	 4.9251104233553251177
log2_b_p_3:
	dq	 0.71604182547154882066
log2_b_p_4:
	dq	 0.00024384785289470863262
log2_b_q_0:
	dq	11.904523296020823153
log2_b_q_1:
	dq	29.106873574779058345
log2_b_q_2:
	dq	24.928920420570964467
log2_b_q_3:
	dq	 8.6737948511229703286

log2_s_c:
log2_s_p_0:
	dq	 3.6543174401668601092
log2_s_p_1:
	dq	 6.9236821167562956347
log2_s_p_2:
	dq	 4.0552858971538414679
log2_s_p_3:
	dq	 0.71265600724817212974
log2_s_p_4:
	dq	 0.00061552202164347354606
log2_s_q_0:
	dq	 7.5989394915663739383
log2_s_q_1:
	dq	20.096596833512705871
log2_s_q_2:
	dq	18.945813884202145516
log2_s_q_3:
	dq	 7.4327985038948378715

exp2_p0_25_c:
exp2_p0_25_0h:
	dq	1.1892071150027210269
exp2_p0_25_0l:
	dq	3.9820152314656461110E-17
exp2_p0_25_1h:
	dq	8.2429555058479309082E-1
exp2_p0_25_1l:
	dq	8.2811696389128996998E-9
exp2_p0_25_2:
	dq	2.8567907128801478533E-1
exp2_p0_25_3:
	dq	6.6005880936045882579E-2
exp2_p0_25_4:
	dq	1.1437947568180147420E-2
exp2_p0_25_5:
	dq	1.5856362256660922264E-3
exp2_p0_25_6:
	dq	1.8317976935970924383E-4
exp2_p0_25_7:
	dq	1.8139623479154579359E-5
exp2_p0_25_8:
	dq	1.5673360359583023396E-6
exp2_p0_25_9:
	dq	1.3055968895300254492E-7

exp2_p0_c:
exp2_p0_0h:
	dq	1.0
exp2_p0_0l:
	dq	0.0
exp2_p0_1h:
	dq	6.9314716756343841553E-1
exp2_p0_1l:
	dq	1.2996506870699420233E-8
exp2_p0_2:
	dq	2.4022650695910330310E-1
exp2_p0_3:
	dq	5.5504108664725972100E-2
exp2_p0_4:
	dq	9.6181291092419882865E-3
exp2_p0_5:
	dq	1.3333558019987959767E-3
exp2_p0_6:
	dq	1.5403532681856270284E-4
exp2_p0_7:
	dq	1.5253065510864060166E-5
exp2_p0_8:
	dq	1.3190300302967161470E-6
exp2_p0_9:
	dq	1.0881074348847176580E-7

exp2_m0_c:
exp2_m0_0h:
	dq	1.0
exp2_m0_0l:
	dq	0.0
exp2_m0_1h:
	dq	6.9314716756343841553E-1
exp2_m0_1l:
	dq	1.2996506870699420233E-8
exp2_m0_2:
	dq	2.4022650695909780749E-1
exp2_m0_3:
	dq	5.5504108664691832742E-2
exp2_m0_4:
	dq	9.6181291047027026725E-3
exp2_m0_5:
	dq	1.3333557764085299593E-3
exp2_m0_6:
	dq	1.5403499520940549562E-4
exp2_m0_7:
	dq	1.5251161994200753343E-5
exp2_m0_8:
	dq	1.3166061357593046239E-6
exp2_m0_9:
	dq	9.2942318847941285694E-8

exp2_m0_25_c:
exp2_m0_25_0h:
	dq	8.4089641525371450204E-1
exp2_m0_25_0l:
	dq	4.0995050102907482601E-17
exp2_m0_25_1h:
	dq	5.8286496996879577637E-1
exp2_m0_25_1l:
	dq	9.4072813983103742430E-9
exp2_m0_25_2:
	dq	2.0200560855082275169E-1
exp2_m0_25_3:
	dq	4.6673206007799013240E-2
exp2_m0_25_4:
	dq	8.0878502812528896282E-3
exp2_m0_25_5:
	dq	1.1212140390502213245E-3
exp2_m0_25_6:
	dq	1.2952709156943405071E-4
exp2_m0_25_7:
	dq	1.2823060087120729985E-5
exp2_m0_25_8:
	dq	1.1036110895925728151E-6
exp2_m0_25_9:
	dq	7.4921899653437894396E-8

real_m_1022:
	dq	-1022.0
real_1023:
	dq	1023.0
real_1024:
	dq	1024.0
real_1025:
	dq	1025.0
real_m_1076:
	dq	-1076.0
real_2_p_m_1022:
	dq		00010000000000000h
real_2_p_m_55:
	dq		03C80000000000000h
real_2_p_53:
	dq		04340000000000000h
real_m_2_p_53:
	dq		0C340000000000000h
real_2_p_55:
	dq		04360000000000000h
real_2_p_1023:
	dq		07fe0000000000000h
real_max:
	dq		07fefffffffffffffh
real_m_max:
	dq		0ffefffffffffffffh

real_4000_0:
	dq	 4000.0
real_m_3810_0:
	dq	-3810.0
real_1401_0:
	dq	 1401.0
real_m_1471_0:
	dq	-1471.0
real_4605_0:
	dq	 4605.0
real_m_4834_0:
	dq	-4834.0
real_1_052:
	dq	 1.052
real_m_1_052:
	dq	-1.052
real_power_exp_too_large:
	dq	 6711563375777760768.0
real_power_exp_too_small:
	dq	-6393154322601327104.0

_DATA	ends

;	end

