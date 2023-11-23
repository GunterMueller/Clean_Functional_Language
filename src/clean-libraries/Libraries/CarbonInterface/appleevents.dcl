definition module appleevents;

from mac_types import ::Toolbox;

TypeApplSignature	:== 0x7369676E;	// 'sign'
TypeProcessSerialNumber:==0x70736E20; // 'psn '
KCoreEventClass		:==	0x61657674;	// 'aevt'
KAEMiscStandards	:== 0x6D697363;	// 'misc'
KAEQuitApplication	:==	0x71756974;	// 'quit'
KAEDoScript			:== 0x646F7363;	// 'dosc'
KeyDirectObject		:== 0x2D2D2D2D;	// '----'
TypeChar			:== 0x54455854;	// 'TEXT'
KeyErrorNumber		:==	0x6572726E;	// 'errn'
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

::	AEDescPtr :== Int;
::	AppleEventPtr :== Int;
:: AEDescListPtr :== Int;

AECreateDesc :: !Int !{#Char} !AEDescPtr -> Int;
AECreateAppleEvent :: !Int !Int !AEDescPtr !Int !Int !AppleEventPtr -> Int;
AEPutParamPtr :: !AppleEventPtr !Int !Int !{#Char} -> Int;
AESend :: !AppleEventPtr !AppleEventPtr !Int !Int !Int !Int !Int -> Int;
AEGetIntParamPtr :: !AppleEventPtr !Int !Int -> (!Int,!Int,!Int,!Int);
AEGetStringParamPtr :: !AppleEventPtr !Int !Int !{#Char} -> (!Int,!Int,!Int);
AEGetNthPtr :: !AEDescListPtr !Int !Int !{#Char} !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
AEDisposeDesc :: !AEDescPtr -> Int;
