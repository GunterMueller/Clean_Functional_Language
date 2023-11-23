implementation module files;

import mac_types;

GetVInfo :: !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetVInfo ioNamePtr t = code (ioNamePtr=R64O0D0SD1,t=U)(ioResult=D0,ioVRefNum=I64A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x90810012	|	stw	r4,18(sp)
	instruction 0xB1410016	|	sth	r10,22(sp)
	instruction 0x3940FFFF	|	li	r10,-1
	instruction 0xB141001C	|	sth	r10,28(sp)
	call	.PBHGetVInfoSync
	instruction 0xAB210016	|	lha	r25,22(sp)
};

GetCatInfo1 :: !Int !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetCatInfo1 ioVRefNum ioNamePtr t = code (ioVRefNum=R108O0D0U,ioNamePtr=SD1,t=U)(ioResult=D0,ioDrParID=I108A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x90810012	|	stw	r4,18(sp)
	instruction 0xB3210016	|	sth	r25,22(sp)
	instruction 0xB141001C	|	sth	r10,28(sp)
	instruction 0x91410030	|	stw	r10,48(sp)
	call	.PBGetCatInfoSync
	instruction 0x83210064	|	lwz	r25,100(sp)
};

GetCatInfo2 :: !Int !Int !{#Char} !*Toolbox -> (!Int,!{#Char},!Int,!*Toolbox);
GetCatInfo2 ioVRefNum ioDrDirID s t = code (ioVRefNum=R108O0D0U,ioDrDirID=U,s=U,t=U)(ioResult=D0,ioDrParID=A0,ioNamePtr=I108A0,z=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x91570004	|	stw	r10,4(r23)
	instruction 0x3AD70007	|	addi	r22,r23,7
	instruction 0x92C10012	|	stw	r22,18(sp)
	instruction 0xB3410016	|	sth	r26,22(sp)
	instruction 0x3940FFFF	|	li	r10,-1
	instruction 0xB141001C	|	sth	r10,28(sp)
	instruction 0x93210030 |	stw	r25,48(sp)
	call	.PBGetCatInfoSync
	instruction 0x83210064	|	lwz	r25,100(sp)
};

GetCatInfo3 :: !Int !Int !{#Char} !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
GetCatInfo3 ioVRefNum ioDirID ioNamePtr t = code (ioVRefNum=R108O0D0U,ioDirID=U,ioNamePtr=SD1,t=U)(ioResult=D0,ioFlAttrib=A0,ioDrDirID=I108A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x90810012	|	stw	r4,18(sp)
	instruction 0xB3410016	|	sth	r26,22(sp)
	instruction 0xB141001C	|	sth	r10,28(sp)
	instruction 0x93210030	|	stw	r25,48(sp)
	call	.PBGetCatInfoSync
	instruction 0x8B41001E	|	lbz	r26,30(sp)
	instruction 0x83210030	|	lwz	r25,48(sp)
};
/*
GetWDInfo :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
GetWDInfo ioVRefNum t = code (ioVRefNum=R52O0D0D1,t=U)(ioResult=D0,ioWDVRefNum=A0,ioWDDirId=I52A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x91410012	|	stw	r10,18(sp)
	instruction 0xB3210016	|	sth	r25,22(sp)
	instruction 0xB141001A	|	sth	r10,26(sp)
	call	.PBGetWDInfoSync
	instruction 0xAB410016	|	lha	r26,22(sp)
	instruction 0x83210030	|	lwz	r25,48(sp)
};
*/

HGetVol :: !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
HGetVol t = code (t=R52O0D0U)(ioResult=D0,ioWDVRefNum=A0,ioWDDirId=I52A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x91410012	|	stw	r10,18(sp)
	call	.PBHGetVolSync
	instruction 0xAB410020	|	lha	r26,32(sp)
	instruction 0x83210030	|	lwz	r25,48(sp)
};

/*
OpenWD :: !Int !Int !*Toolbox -> Int;
OpenWD ioVRefNum ioWDDirID t = code (ioVRefNum=R52O0D0U,ioWDDirID=U,t=U)(ioWDVRefNum=I52A0){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x91410012	|	stw	r10,18(sp)
	instruction 0xB3410016	|	sth	r26,22(sp)
	instruction 0x9141001C	|	stw	r10,28(sp)
	instruction 0x93210030	|	stw	r25,48(sp)
	call	.PBOpenWDSync
	instruction 0xAB010016	|	lha	r24,22(sp)
};
*/

GetFInfo :: !{#Char} !*Toolbox -> (!Int,!Int,!*Toolbox);
GetFInfo ioNamePtr t = code (ioNamePtr=R80O0D0SD1,t=U)(ioResult=D0,ioDate_and_Time=I80A0,t2=Z){
	instruction 0x39400000	|	li	r10,0
	instruction 0x9141000C	|	stw	r10,12(sp)
	instruction 0x90810012	|	stw	r4,18(sp)
	instruction 0xB1410016	|	sth	r10,22(sp)
	instruction 0xB141001A	|	sth	r10,26(sp)
	instruction 0x91410030	|	stw	r10,48(sp)
	instruction 0x3940FFFF	|	li	r10,-1
	instruction 0xB141001C	|	sth	r10,28(sp)
	call	.PBHGetFInfoSync
	instruction 0x8321004C	|	lwz	r25,76(sp)
};

SetFileType :: !{#Char} !{#Char} !*Toolbox -> (!Int,!*Toolbox);
SetFileType type ioNamePtr t = code (type=R80U,ioNamePtr=U,t=U)(ioResult=I80D0,t2=Z){
	instruction 0x83B60008	|	lwz       r29,0x0008(r22)
	instruction 0x39400000	|	li        r10,0
	instruction 0x9141000C	|	stw       r10,0x000C(SP)
	instruction 0x3B770007	|	addi      r27,r23,7
	instruction 0x93610012	|	stw       r27,0x0012(SP)
	instruction 0xB1410016	|	sth       r10,0x0016(SP)
	instruction 0xB141001A	|	sth       r10,0x001A(SP)
	instruction 0x91410030	|	stw       r10,0x0030(SP)
	instruction 0x3940FFFF	|	li        r10,-1
	instruction 0xB141001C	|	sth       r10,0x001C(SP)
	instruction 0x7C230B78	|	mr        r3,SP
	call	.PBHGetFInfoSync
	instruction 0x7C630735	|	extsh.    r3,3
	instruction 0x41820008	|	be        $+8
	:SetFileType1
		jmp	SetFileType2
	instruction 0x93610012	|	stw       r27,0x0012(SP)
	instruction 0x93A10020	|	stw       r29,0x0020(SP)
	instruction 0x39400000	|	li        r10,0
	instruction 0x91410030	|	stw       r10,0x0030(SP)
	instruction 0x7C230B78	|	mr        r3,SP
	call	.PBHSetFInfoSync
	:SetFileType2
};

SetFileTypeAndCreator :: !{#Char} !{#Char} !{#Char} !*Toolbox -> (!Int,!*Toolbox);
SetFileTypeAndCreator type creator ioNamePtr t = code (type=R80U,creator=U,ioNamePtr=U,t=U)(ioResult=I80D0,t2=Z){
	instruction 0x83B50008	|	lwz       r29,0x0008(r21)
	instruction 0x83960008	|	lwz       r28,0x0008(r22)
	instruction 0x39400000	|	li        r10,0
	instruction 0x9141000C	|	stw       r10,0x000C(SP)
	instruction 0x3B770007	|	addi      r27,r23,7
	instruction 0x93610012	|	stw       r27,0x0012(SP)
	instruction 0xB1410016	|	sth       r10,0x0016(SP)
	instruction 0xB141001A	|	sth       r10,0x001A(SP)
	instruction 0x91410030	|	stw       r10,0x0030(SP)
	instruction 0x3940FFFF	|	li        r10,-1
	instruction 0xB141001C	|	sth       r10,0x001C(SP)
	instruction 0x7C230B78	|	mr        r3,SP
	call	.PBHGetFInfoSync
	instruction 0x7C630735	|	extsh.    r3,3
	instruction 0x41820008	|	be        $+8
	:SetFileTypeAndCreator1
		jmp	SetFileTypeAndCreator2
	instruction 0x93610012	|	stw       r27,0x0012(SP)
	instruction 0x93A10020	|	stw       r29,0x0020(SP)
	instruction 0x93810024	|	stw       r28,0x0024(SP)
	instruction 0x39400000	|	li        r10,0
	instruction 0x91410030	|	stw       r10,0x0030(SP)
	instruction 0x7C230B78	|	mr        r3,SP
	call	.PBHSetFInfoSync
	:SetFileTypeAndCreator2
};
/*
LaunchApplication :: !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
LaunchApplication file_name flags t
= code (file_name=R20SD0,flags=D1,t=U)(result=I20D0,t2=Z){
	instruction 0x90610000	|	stw		r3,0(sp)
	instruction 0x39404C43	|	li		r10,'LC'
	instruction 0x91410004	|	stw		r10,4(SP)
	instruction 0x39400006	|	li		r10,6
	instruction 0x91410008	|	stw		r10,8(SP)
	instruction 0xB141000C	|	sth		r10,12(SP)
	instruction 0x9081000E	|	stw		r4,14(SP)
	instruction 0x7C230B78	|	mr		r3,SP	
	call	.LaunchApplication
}
*/
from StdArray import class Array(..),instance Array {#} Char;

FSMakeFSSpec :: !{#Char} !*Toolbox -> (!Int,!{#Char},!*Toolbox);
FSMakeFSSpec file_name t
	# fs_spec = createArray 70 '\0';
	# (r,t) = fs_make_fs_spec 0 0 file_name fs_spec t;
	= (r,fs_spec,t);
{
fs_make_fs_spec :: !Int !Int !{#Char} !{#Char} !*Toolbox -> (!Int,!*Toolbox);
fs_make_fs_spec v_refnum dir_id file_name fs_spec t
	= code (v_refnum=D0,dir_id=D1,file_name=SD2,fs_spec=CD3,t=U)(r=D0,t2=Z){
		call .FSMakeFSSpec
	}
}

LaunchApplicationFSSpec :: !{#Char} !Int !*Toolbox -> (!Int,!*Toolbox);
LaunchApplicationFSSpec fs_spec flags t
	= code (fs_spec=R44CD0,flags=D1,t=U)(result=I44D0,t2=Z){
		instruction 0x39404C43	|	li		r10,'LC'
		instruction 0x91410004	|	stw		r10,4(SP)
		instruction 0x39400020	|	li		r10,32
		instruction 0x91410008	|	stw		r10,8(SP)
		instruction 0x39400000	|	li		r10,0
		instruction 0x91410000	|	stw		r10,0(sp)
		instruction 0xB141000C	|	sth		r10,12(SP)
		instruction 0xB081000E	|	sth		r4,14(SP)
		instruction 0x90610010	|	stw		r3,16(sp)
		instruction 0x91410028	|	stw		r10,40(sp)
		instruction 0x7C230B78	|	mr		r3,SP	
		call	.LaunchApplication
	}
