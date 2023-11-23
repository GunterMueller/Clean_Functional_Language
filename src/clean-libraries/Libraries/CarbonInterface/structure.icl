implementation module structure;

import mac_types;

::	Structure :== (!Handle,!Ptr);
                                       	                                       	
DereferenceHandle :: !Handle !*Toolbox -> (!Ptr,!*Toolbox);
DereferenceHandle h tb = (DereferenceHandle1 h,tb);

DereferenceHandle1 :: !Handle -> Ptr;
DereferenceHandle1 h = code (h=U)(pointer=A0){
	instruction	0x83180000	|	lwz	r24,0(r24)
};

HandleToStructure :: !Handle -> Structure;
HandleToStructure h = code (h=D0)(new_h=A0,pointer=A0){
	instruction	0x7F19C378	|	mr	r25,r24
	instruction	0x83180000	|	lwz	r24,0(r24)
};

Append_long :: !Structure !Int !*Toolbox -> (!Structure,!*Toolbox);
Append_long hp l tb = (AppendLong hp l,tb);

AppendLong :: !Structure !Int -> Structure;
AppendLong  (h,p) l = code (h=U,p=U,l=U)(new_h=A0,new_p=A0){
	instruction	0x93190000	|	stw		r24,0(r25)
	instruction 0x3B190004	|	addi	r24,r25,4
	instruction	0x7F59D378	|	mr		r25,r26
};

Append_word :: !Structure !Int !*Toolbox -> (!Structure,!*Toolbox);
Append_word hp w tb = (AppendWord hp w,tb);

AppendWord :: !Structure !Int -> Structure;
AppendWord (h,p) w = code (h=U,p=U,w=U) (new_h=A0,new_p=A0){
	instruction	0xB3190000	|	sth		r24,0(r25)
	instruction	0x3B190002	|	addi	r24,r25,2
	instruction	0x7F59D378	|	mr		r25,r26
};

Append_byte :: !Structure !Int !*Toolbox -> (!Structure,!*Toolbox);
Append_byte hp b tb = (AppendByte hp b,tb);

AppendByte :: !Structure !Int -> Structure;
AppendByte (h,p) b = code (h=U,p=U,b=U)(new_h=A0,new_p=A0){
	instruction	0x9B190000	|	stb		r24,0(r25)
	instruction	0x3B190001	|	addi	r24,r25,1
	instruction	0x7F59D378	|	mr		r25,r26
};

Append_zero_and_rect :: !Structure !Rect !*Toolbox -> (!Structure,!*Toolbox);
Append_zero_and_rect hp rect tb = (Append_zero_and_rect1 hp rect,tb);

Append_zero_and_rect1 :: !Structure !Rect -> Structure;
Append_zero_and_rect1 (h,p) (left,top,right,bottom) = code (h=U,p=U,left=U,top=U,right=U,bottom=U)(new_h=A0,new_p=A0){
	instruction	0x38600000	|	li		r3,0
	instruction 0x907C0000	|	stw		r3,0(r28)
	instruction 0xB35C0004	|	sth		r26,4(r28)
	instruction 0xB37C0006	|	sth		r27,6(r28)
	instruction	0xB31C0008	|	sth		r24,8(r28)
	instruction	0xB33C000A	|	sth		r25,10(r28)
	instruction	0x3B1C000C	|	addi	r24,r28,12
	instruction	0x7FB9EB78	|	mr		r25,r29
};

Append_string_and_align :: !Structure !{#Char} !*Toolbox -> (!Structure,!*Toolbox);
Append_string_and_align hp string tb = (Append_string_and_align1 hp string,tb);

Append_string_and_align1 :: !Structure !{#Char} -> Structure;
Append_string_and_align1 (h,p) string = code (h=U,p=U,string=U)(new_h=A0,new_p=A0){                                       		
	instruction	0x8F570007	|		lbzu	r26,7(r23)
	instruction	0x9B580000	|		stb		r26,0(r24)
	instruction	0x4800000C	|		b		l2
	instruction	0x8C770001	|	l1:	lbzu	r3,1(r23)
	instruction	0x9C780001	|		stbu	r3,1(r24)
	instruction	0x375AFFFF	|	l2:	subic.	r26,r26,1	
	instruction	0x4080FFF4	|		bge		l1
	instruction	0x3B180002	|		addi	r24,r24,2
	instruction	0x5718003C	|		clrrwi	r24,r24,1
};

Append_string :: !Structure !{#Char} !*Toolbox -> (!Structure,!*Toolbox);
Append_string hp string tb = (AppendString hp string,tb);

AppendString :: !Structure !{#Char} -> Structure;
AppendString (h,p) string = code (h=U,p=U,string=U)(new_h=A0,new_p=A0){                                       		
	instruction	0x8F570007	|		lbzu	r26,7(r23)
	instruction	0x3B18FFFF	|		addi	r24,r24,-1
	instruction	0x4800000C	|		b		l2
	instruction	0x8C770001	|	l1:	lbzu	r3,1(r23)
	instruction	0x9C780001	|		stbu	r3,1(r24)
	instruction	0x375AFFFF	|	l2:	subic.	r26,r26,1	
	instruction	0x4080FFF4	|		bge		l1
	instruction	0x3B180001	|		addi	r24,r24,1
};
