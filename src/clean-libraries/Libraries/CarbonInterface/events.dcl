definition module events;

import mac_types;

//	Event masks

MDownMask	:== 2;
MUpMask 	:== 4;
KeyDownMask :== 8;
KeyUpMask	:== 16;
AutoKeyMask :== 32;
UpdateMask	:== 64;
DiskMask	:== 128;
ActivMask	:== 256;
NetworkMask :== 1024;
DriverMask	:== 2048;
OsMask		:== 0x8000;
HighLevelEventMask:==0x800000;

//	Device masks

MouseMask		:== 6;		// MouseDown | MouseUp
KeyboardMask	:== 56;		// KeyDown	 | KeyUp | AutoKey

//	Event codes

NullEvent		:== 0;
MouseDownEvent	:== 1;
MouseUpEvent	:== 2;
KeyDownEvent	:== 3;
KeyUpEvent		:== 4;
AutoKeyEvent	:== 5;
UpdateEvent 	:== 6;
DiskEvent		:== 7;
ActivateEvent	:== 8;
NetworkEvent	:== 10;
DriverEvent 	:== 11;
OsEvent			:== 15;
HighLevelEvent	:== 23;
InetEvent		:== 24;

//	Flags for suspend and resume events

ResumeFlag				:== 1;
ConvertClipboardFlag	:== 2;

//	Message codes for operating-system events

SuspendResumeMessage	:== 1;		// $01
MouseMovedMessage		:== 250;	// $FA

GetNextEvent	:: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
EventAvail		:: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
WaitNextEvent	:: !Int !Int !RgnHandle !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
TickCount			:: !*Toolbox -> (!Int,!*Toolbox);
GetMouse			:: !*Toolbox -> (!Int,!Int,!*Toolbox);
Button				:: !*Toolbox -> (!Bool,!*Toolbox);
StillDown			:: !*Toolbox -> (!Bool,!*Toolbox);
WaitMouseUp			:: !*Toolbox -> (!Bool,!*Toolbox);
GetKeys				:: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
HasWaitNextEvent	:: !*Toolbox -> (!Bool,!*Toolbox);
GetCaretTime :: !*Toolbox -> (!Int,!*Toolbox);
GetDoubleTime :: !*Toolbox -> (!Int,!*Toolbox);
