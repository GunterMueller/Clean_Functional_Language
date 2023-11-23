implementation module windows;

import mac_types;

InDesk :== 0;
InMenuBar :== 1;
InSysWindow :== 2;
InContent :== 3;
InDrag :== 4;
InGrow :== 5;
InGoAway :== 6;
InZoomIn :== 7;
InZoomOut :== 8;

//	Initialization and Allocation

NewWindow :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !*Toolbox -> (!WindowPtr,!*Toolbox);
NewWindow wStorage (left,top,right,bottom) title visible procID behind goAwayFlag refCon t
= code (right=W,bottom=W,left=W,top=W,wStorage=D0,title=O0D1SD2,visible=D3,
		  procID=D4,behind=D5,goAwayFlag=D6,refCon=D7,t=U) (window_pointer=D0,z=I8Z)
{
	instruction	0x7CC600D0	|	neg	r6,r6
	instruction	0x7D2900D0	|	neg	r9,r9
	call	.NewWindow
};

NewCWindow :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !*Toolbox -> (!WindowPtr,!*Toolbox);
NewCWindow wStorage (left,top,right,bottom) title visible procID behind goAwayFlag refCon t
= code (right=W,bottom=W,left=W,top=W,wStorage=D0,title=O0D1SD2,visible=D3,
		  procID=D4,behind=D5,goAwayFlag=D6,refCon=D7,t=U)(window_pointer=D0,z=I8Z)
{
	instruction	0x7CC600D0	|	neg	r6,r6
	instruction	0x7D2900D0	|	neg	r9,r9
	call	.NewCWindow
};

DisposeWindow :: !WindowPtr !*Toolbox -> *Toolbox;
DisposeWindow theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.DisposeWindow
};

//	Window Display

SetWTitle :: !WindowPtr !{#Char} !*Toolbox -> *Toolbox;
SetWTitle theWindow title t = code (theWindow=D0,title=SD1,t=U)(z=Z){
	call	.SetWTitle
};

SelectWindow :: !WindowPtr !*Toolbox -> *Toolbox;
SelectWindow theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.SelectWindow
};

HideWindow :: !WindowPtr !*Toolbox -> *Toolbox;
HideWindow theWindow t = code (theWindow=D0,t=U)(z=Z){
	call		.HideWindow
};

ShowWindow :: !WindowPtr !*Toolbox -> *Toolbox;
ShowWindow theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.ShowWindow
};

ShowHide :: !WindowPtr !Bool !*Toolbox -> *Toolbox;
ShowHide theWindow showFlag t = code (theWindow=D0,showFlag=D1,t=U)(z=Z){
	call	.ShowHide
};

SendBehind :: !WindowPtr !WindowPtr !*Toolbox -> *Toolbox;
SendBehind theWindow behindWindow t = code (theWindow=D0,behindWindow=D1,t=U)(z=Z){
	call	.SendBehind
};

DrawGrowIcon :: !WindowPtr !*Toolbox -> *Toolbox;
DrawGrowIcon theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.DrawGrowIcon
};

FrontWindow :: !*Toolbox -> (!WindowPtr,!*Toolbox);
FrontWindow t = code (t=U)(theWindow=D0,z=Z){
	call	.FrontWindow
};

//	Mouse Location

FindWindow :: !Int !Int !*Toolbox -> (!Int,!WindowPtr,!*Toolbox);
FindWindow h v t = code (h=R4D0,v=a0,t=O0D1U)(wher=D0,whichWindow=L,z=Z){
	instruction 0x52E3801E	|	rlwimi	r3,r23,16,0,15
	call	.FindWindow
};

TrackGoAway :: !WindowPtr !Int !Int !*Toolbox -> (!Bool,!*Toolbox);
/*
TrackGoAway theWindow h v t = code (theWindow=D0,h=D1,v=A0,t=U)(result=D0,z=Z){
	instruction 0x52E4801E	|	rlwimi	r4,r23,16,0,15
	call	.TrackGoAway
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg	r3,r3
};
*/
TrackGoAway theWindow h v t = code (theWindow=D0,h=D1,v=A0,t=U)(result=B0,z=Z){
	instruction 0x52E4801E	|	rlwimi	r4,r23,16,0,15
	call	.TrackGoAway
};

TrackBox :: !WindowPtr !Int !Int !Int !*Toolbox -> (!Bool,!*Toolbox);
/*
TrackBox theWindow h v partCode t = code (theWindow=D0,h=D1,v=A0,partCode=D2,t=U)(result=D0,z=Z){
	instruction 0x52E4801E	|	rlwimi	r4,r23,16,0,15
	call	.TrackBox
	instruction	0x70630001	|	andi.	r3,r3,1
	instruction	0x7C6300D0	|	neg	r3,r3
};
*/
TrackBox theWindow h v partCode t = code (theWindow=D0,h=D1,v=A0,partCode=D2,t=U)(result=B0,z=Z){
	instruction 0x52E4801E	|	rlwimi	r4,r23,16,0,15
	call	.TrackBox
};

//	Window Movement and Sizing

MoveWindow :: !WindowPtr !Int !Int !Bool !*Toolbox -> *Toolbox;
MoveWindow theWindow hGlobal vGlobal front t = code (theWindow=D0,hGlobal=D1,vGlobal=D2,front=D3,t=U)(z=Z){
	call	.MoveWindow
};

DragWindow :: !WindowPtr !Int !Int !Rect !*Toolbox -> *Toolbox;
DragWindow theWindow h v (left,top,right,bottom) t
= code (right=W,bottom=W,left=W,top=W,theWindow=D0,h=D1,v=A0,t=O0D2U)(z=I8Z){
	instruction 0x52E4801E	| rlwimi	r4,r23,16,0,15
	call	.DragWindow
};

GrowWindow :: !WindowPtr !Int !Int !Rect !*Toolbox -> (!(!Int,!Int),!*Toolbox);
GrowWindow theWindow h v (left,top,right,bottom) t
= code (right=W,bottom=W,left=W,top=W,theWindow=D0,h=D1,v=A0,t=O0D2U)(h2=D0,w2=D1,z=I8Z){
	instruction 0x52E4801E	| rlwimi	r4,r23,16,0,15
	call	.GrowWindow
	instruction	0x5464843E	| srwi	r4,r3,16
	instruction 0x7063FFFF	| andi.	r3,r3,65535
};

SizeWindow :: !WindowPtr !Int !Int !Bool !*Toolbox -> *Toolbox;
SizeWindow theWindow w h fUpdate t = code (theWindow=D0,w=D1,h=D2,fUpdate=D3,t=U)(z=Z){
	call	.SizeWindow
};

ZoomWindow :: !WindowPtr !Int !Bool !*Toolbox -> *Toolbox;
ZoomWindow theWindow partCode front t = code (theWindow=D0,partCode=D1,front=D2,t=U)(z=Z){
	call	.ZoomWindow
};

WindowUpdateRgn :== 34;

GetWindowRegion :: !WindowPtr !Int !RgnHandle !*Toolbox -> *Toolbox;
GetWindowRegion w i r t = code (w=D0,i=D1,r=D2,t=U)(z=Z){
	call	.GetWindowRegion
};

SetWindowStandardState :: !WindowPtr !Rect !*Toolbox -> *Toolbox;
SetWindowStandardState w (left,top,right,bottom) t = code (w=D0,right=W,bottom=W,left=W,top=W,t=O0D1U)(z=I8Z){
	call	.SetWindowStandardState
};

//	Update Region Maintenance

InvalWindowRect :: !WindowPtr !Rect !*Toolbox -> *Toolbox;
InvalWindowRect w (left,top,right,bottom) t = code (w=D0,right=W,bottom=W,left=W,top=W,t=O0D1U)(z=I8Z){
	call	.InvalWindowRect
};

ValidWindowRect :: !WindowPtr !Rect !*Toolbox -> *Toolbox;
ValidWindowRect w (left,top,right,bottom) t = code (w=D0,right=W,bottom=W,left=W,top=W,t=O0D1U)(z=I8Z){
	call	.ValidWindowRect
};

BeginUpdate :: !WindowPtr !*Toolbox -> *Toolbox;
BeginUpdate theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.BeginUpdate
};

EndUpdate :: !WindowPtr !*Toolbox -> *Toolbox;
EndUpdate theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.EndUpdate
};

GetDialogWindow :: !DialogPtr !*Toolbox -> (!WindowPtr,!*Toolbox);
GetDialogWindow dialogPtr t = code (dialogPtr=D0,t=U)(windowPtr=D0,z=Z){
	call .GetDialogWindow
};

GetDialogFromWindow :: !WindowPtr !*Toolbox -> (!DialogPtr,!*Toolbox);
GetDialogFromWindow windowPtr t = code (windowPtr=D0,t=U)(dialogPtr=D0,z=Z){
	call .GetDialogFromWindow
};
