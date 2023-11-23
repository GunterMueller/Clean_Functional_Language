implementation module standard_file;

import mac_types;
/*
SFGetFile :: !(!Int,!Int) !{#Char} !Int !Int !{#Char} !Int !{#Char} !*Toolbox -> (!Bool,!Bool,!Int,!Int,!Int,!{#Char},!*Toolbox);
SFGetFile (h,v) prompt fileFilter numTypes typeList dlgHook string64 t
= code (prompt=R74SD1,h=D0,v=A2,fileFilter=D2,numTypes=D3,typeList=U,dlgHook=D5,string64=U,t=O0D6U)
	(good=A0,copy=A0,fType=A0,vRefNum=A0,version=A0,fName=I74A0,z=Z)
{
	instruction 0x52A3801E	|	rlwimi	r3,r21,16,0,15
	instruction 0x38F60008	|	addi	r7,r22,8
	call	.SFGetFile
	instruction 0x8BA10000	|	lbz	r29,0(sp)
	instruction 0x73BD0001	|	andi.	r29,r29,1
	instruction 0x7FBD00D0	|	neg	r29,r29
	instruction 0x8B810001	|	lbz	r28,1(sp)
	instruction 0x739C0001	|	andi.	r28,r28,1
	instruction 0x7F9C00D0	|	neg	r28,r28
	instruction 0x83610002	|	lwz	r27,2(sp)
	instruction 0xAB410006	|	lha	r26,6(sp)
	instruction 0xAB210008	|	lha	r25,8(sp)
	instruction 0x3AC1000A	|	addi	r22,sp,10
	instruction 0x8BD60000	|	lbz	r30,0(r22)
	instruction 0x93D70004	|	stw	r30,4(r23)
	instruction 0x3AB70007	|	addi	r21,r23,7
	instruction 0x4800000C	|	b	l2
	instruction 0x84760001	| l1:	lwzu	r3,1(r22)
	instruction 0x94750001	|	stwu	r3,1(r21)
	instruction 0x37DEFFFF	| l2:	subic.	r30,r30,1
	instruction 0x4080FFF4	|	bge	l1
};

SFPutFile :: !(!Int,!Int) !{#Char} !{#Char} !Int !{#Char} !*Toolbox -> (!Bool,!Bool,!Int,!Int,!Int,!{#Char},!*Toolbox);
SFPutFile (h,v) prompt origName dlgHook string64 t
= code (prompt=R74SD1,h=D0,v=A2,origName=SD2,dlgHook=D3,string64=U,t=O0D4U)
	(good=A0,copy=A0,fType=A0,vRefNum=A0,version=A0,fName=I74A0,z=Z)
{
	instruction 0x52A3801E	|	rlwimi	r3,r21,16,0,15
	call	.SFPutFile
	instruction 0x8BA10000	|	lbz	r29,0(sp)
	instruction 0x73BD0001	|	andi.	r29,r29,1
	instruction 0x7FBD00D0	|	neg	r29,r29
	instruction 0x8B810001	|	lbz	r28,1(sp)
	instruction 0x739C0001	|	andi.	r28,r28,1
	instruction 0x7F9C00D0	|	neg	r28,r28
	instruction 0x83610002	|	lwz	r27,2(sp)
	instruction 0xAB410006	|	lha	r26,6(sp)
	instruction 0xAB210008	|	lha	r25,8(sp)
	instruction 0x3AC1000A	|	addi	r22,sp,10
	instruction 0x8BD60000	|	lbz	r30,0(r22)
	instruction 0x93D70004	|	stw	r30,4(r23)
	instruction 0x3AB70007	|	addi	r21,r23,7
	instruction 0x4800000C	|	b	l2
	instruction 0x84760001	| l1:	lwzu	r3,1(r22)
	instruction 0x94750001	|	stwu	r3,1(r21)
	instruction 0x37DEFFFF	| l2:	subic.	r30,r30,1
	instruction 0x4080FFF4	|	bge	l1
};
*/