implementation module appleevents;

from mac_types import ::Toolbox;

TypeApplSignature	:== 0x7369676E;	// 'sign'
TypeProcessSerialNumber:==0x70736E20; // 'psn '
KCoreEventClass		:==	0x61657674;	// 'aevt'
KAEMiscStandards	:== 0x6D697363;	// 'misc'
KAEQuitApplication	:==	0x71756974;	// 'quit'
KAEDoScript			:== 0x646F7363;	// 'dosc'
KeyDirectObject		:== 0x2D2D2D2D;	// '----'
TypeChar			:== 0x54455854;	// 'TEXT'
KeyErrorNumber		:== 0x6572726E;	// 'errn'
KeyErrorString		:== 0x65727273;	// 'errs'
TypeLongInteger		:== 0x6C6F6E67;	// 'long'
KeyFssString		:== 0x66737320; // 'fss '

SizeOfAEDesc :== 8;
SizeOfAppleEvent :== 8;

KAutoGenerateReturnID :== -1;
KAnyTransactionID :== 0;
KAENoReply :== 1;
KAEWaitReply :== 3;
KAENormalPriority :== 0;
KNoTimeOut :== -2;

:: AEDescPtr :== Int;
:: AppleEventPtr :== Int;
:: AEDescListPtr :== Int;

AECreateDesc :: !Int !{#Char} !AEDescPtr -> Int;
AECreateDesc typeCode data result_p = code (typeCode=D0,data=CD1S2,result_p=D3)(error_code=D0){
	call	.AECreateDesc
}

AECreateAppleEvent :: !Int !Int !AEDescPtr !Int !Int !AppleEventPtr -> Int;
AECreateAppleEvent theAEEventClass theAEEventID target returnID transactionID result_p
= code (theAEEventClass=D0,theAEEventID=D1,target=D2,returnID=D3,transactionID=D4,result_p=D5)(error_code=D0){
	call	.AECreateAppleEvent
}

AEPutParamPtr :: !AppleEventPtr !Int !Int !{#Char} -> Int;
AEPutParamPtr theAppleEvent theAEKeyword typeCode data
= code (theAppleEvent=D0,theAEKeyword=D1,typeCode=D2,data=CD3S4)(error_code=D0){
	call	.AEPutParamPtr
}

AESend :: !AppleEventPtr !AppleEventPtr !Int !Int !Int !Int !Int -> Int;
AESend theAppleEvent reply sendMode sendPriority timeOutInTicks idleProc filterProc
= code (theAppleEvent=D0,reply=D1,sendMode=D2,sendPriority=D3,timeOutInTicks=D4,idleProc=D5,filterProc=D6)(error_code=D0){
	call	.AESend
}

AEGetIntParamPtr :: !AppleEventPtr !Int !Int -> (!Int,!Int,!Int,!Int);
AEGetIntParamPtr theAppleEvent theAEKeyword desiredType
= code (theAppleEvent=R12D0,theAEKeyword=D1,desiredType=O0D3O4D4O8D6D2)(error_code=D0,typeCode=L,value=L,actualSize=L){
	instruction 0x39000004	|	li	r8,4
	call	.AEGetParamPtr
}

AEGetStringParamPtr :: !AppleEventPtr !Int !Int !{#Char} -> (!Int,!Int,!Int);
AEGetStringParamPtr theAppleEvent theAEKeyword desiredType string
= code (theAppleEvent=R8D0,theAEKeyword=D1,desiredType=D2,string=O0D3O4D6CD4S5)(error_code=D0,typeCode=L,actualSize=L){
	call	.AEGetParamPtr
}

AEGetNthPtr :: !AEDescListPtr !Int !Int !{#Char} !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
AEGetNthPtr theAEDescList index desiredType dataPtr t
	= code (theAEDescList=D0,index=D1,desiredType=D2,dataPtr=R12O0D3O4D4O8D7CD5S6,t=U)(r=D0,theAEKeyword=L,typeCode=L,actualSize=L,z=Z){
		call .AEGetNthPtr
	}; 

AEDisposeDesc :: !AEDescPtr -> Int;
AEDisposeDesc theAEDesc = code (theAEDesc=D0)(error_code=D0){
	call	.AEDisposeDesc
}
