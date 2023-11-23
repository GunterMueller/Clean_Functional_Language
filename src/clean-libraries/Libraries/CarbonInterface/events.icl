implementation module events;

import mac_types;
import StdInt;

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

//import StdDebug,StdString;

GetNextEvent :: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
GetNextEvent eventMask t
//	# (begin_ticks,t) = TickCount t;
	# (b,what,message,when,position,modifiers) = GetNextEvent2 eventMask t;
//	| b==b
//		# (end_ticks,t) = TickCount 0;
//		| trace_t (toString (end_ticks-begin_ticks)+++" ")
//			= (b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);
			= (b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);

GetNextEvent2 :: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int);
/*
GetNextEvent2 eventMask t
= code (eventMask=R16D0,t=O0D1U)(b=D0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.GetNextEvent
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
GetNextEvent2 eventMask t
= code (eventMask=R16D0,t=O0D1U)(b=B0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.GetNextEvent
};

EventAvail :: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
EventAvail eventMask t
=	(b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);
{
	(b,what,message,when,position,modifiers)= EventAvail2 eventMask t;
}

EventAvail2 :: !Int !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int);
/*
EventAvail2 eventMask t = code (eventMask=R16D0,t=O0D1U)(b=D0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.EventAvail
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
EventAvail2 eventMask t = code (eventMask=R16D0,t=O0D1U)(b=B0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.EventAvail
};

//import StdDebug,StdString;

WaitNextEvent :: !Int !Int !RgnHandle !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
WaitNextEvent eventMask sleep mouseRgn t
//	# (begin_ticks,t) = TickCount t;
	# (b,what,message,when,position,modifiers)= WaitNextEvent2 eventMask sleep mouseRgn t;
//	| b==b
//		# (end_ticks,t) = TickCount 0;
//		| trace_t (toString (end_ticks-begin_ticks)+++" ")
//			= (b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);
			= (b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);

//	# (b,what,message,when,position,modifiers)= WaitNextEvent2 eventMask sleep mouseRgn t;
//	=	(b,what,message,when,(position<<16)>>16,position>>16,modifiers,0);

WaitNextEvent2 :: !Int !Int !RgnHandle !*Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int);
/*
WaitNextEvent2 eventMask sleep mouseRgn t
= code (eventMask=R16D0,sleep=O0D1D2,mouseRgn=D3,t=U)(b=D0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.WaitNextEvent
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
WaitNextEvent2 eventMask sleep mouseRgn t
= code (eventMask=R16D0,sleep=O0D1D2,mouseRgn=D3,t=U)(b=B0,what=W,message=L,when=L,position=L,modifiers=W){
	call	.WaitNextEvent
};

TickCount :: !*Toolbox -> (!Int,!*Toolbox);
TickCount t = code (t=U)(r=D0,z=Z){
	call	.TickCount
};

GetMouse :: !*Toolbox -> (!Int,!Int,!*Toolbox);
GetMouse tb
=	(h,v,tb1);
	where {
		(v,h,tb1) =: GetMouse1 tb;
	};
	
GetMouse1 :: !*Toolbox -> (!Int,!Int,!*Toolbox);
GetMouse1 t = code (t=R4O0D0U)(v=W,h=W,z=Z){
	call	.GetMouse
};

Button :: !*Toolbox -> (!Bool,!*Toolbox);
/*
Button t = code (t=U)(b=D0,z=Z){
	call	.Button
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
Button t = code (t=U)(b=B0,z=Z){
	call	.Button
};

StillDown :: !*Toolbox -> (!Bool,!*Toolbox);
/*
StillDown t = code (t=U)(b=D0,z=Z){
	call	.StillDown
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
StillDown t = code (t=U)(b=B0,z=Z){
	call	.StillDown
};

WaitMouseUp :: !*Toolbox -> (!Bool,!*Toolbox);
/*
WaitMouseUp t = code (t=U)(b=D0,z=Z){
	call	.WaitMouseUp
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg		r3,r3
};
*/
WaitMouseUp t = code (t=U)(b=B0,z=Z){
	call	.WaitMouseUp
};

GetKeys :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
GetKeys t = code (t=R16O0D0U)(k0=L,k1=L,k2=L,k3=L,z=Z){
	call	.GetKeys
};

HasWaitNextEvent :: !*Toolbox -> (!Bool,!*Toolbox);
HasWaitNextEvent tb = (True, NewToolbox);

HasWaitNextEvent1 :: !*Toolbox -> Bool;
HasWaitNextEvent1 t = True;

GetCaretTime :: !*Toolbox ->(!Int,!*Toolbox);
GetCaretTime t = code (t=U)(caret_time=D0,z=Z){
	call .GetCaretTime
};

GetDoubleTime :: !*Toolbox ->(!Int,!*Toolbox);
GetDoubleTime t = code (t=U)(caret_time=D0,z=Z){
	call .GetCaretTime
};
