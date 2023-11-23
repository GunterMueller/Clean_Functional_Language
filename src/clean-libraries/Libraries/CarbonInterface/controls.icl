implementation module controls;

import mac_types;

InButton :== 10;
InCheckBox :== 11;
InUpButton :== 20;
InDownButton :== 21;
InPageUp :== 22;
InPageDown :== 23;
InThumb :== 129;

::	ControlHandle :== Int;

//	Initialization and Allocation

NewControl :: !WindowPtr !Rect !{#Char} !Bool !Int !Int !Int !Int !Int !*Toolbox -> (!ControlHandle,!*Toolbox);
NewControl theWindow (left,top,right,bottom) title visible value min max procID refCon t
= code (right=W,bottom=W,left=W,top=W,theWindow=D0,title=O0D1SD2,visible=D3,value=D4,
		min=D5,max=D6,procID=D7,refCon=A0,t=U)(control=D0,z=I8Z)
{
	instruction 0x703E001F	|	andi. r30,r1,31
	instruction	0x7C3E0850	|	sub r1,r1,r30

	instruction 0x92E1FFF8	|	stw	r23,-8(sp)
	instruction	0x7CC600D0	|	neg	r6,r6
	call	.NewControl

	instruction 0x7C21F214	|	add r1,r1,r30
};

//	Control Display

SetCTitle :: !ControlHandle !{#Char} !*Toolbox -> *Toolbox;
SetCTitle theControl title t = code (theControl=D0,title=SD1,t=U)(z=Z){
	call .SetControlTitle
};

HideControl :: !ControlHandle !*Toolbox -> *Toolbox;
HideControl theControl t = code (theControl=D0,t=U)(z=Z){
	call	.HideControl
};

ShowControl :: !ControlHandle !*Toolbox -> *Toolbox;
ShowControl theControl t = code (theControl=D0,t=U)(z=Z){
	call	.ShowControl
};

DrawControls :: !WindowPtr !*Toolbox -> *Toolbox;
DrawControls theWindow t = code (theWindow=D0,t=U)(z=Z){
	call	.DrawControls
};

Draw1Control :: !ControlHandle !*Toolbox -> *Toolbox;
Draw1Control theControl t = code (theControl=D0,t=U)(z=Z){
	call	.Draw1Control
};

UpdtControl :: !WindowPtr !RgnHandle !*Toolbox -> *Toolbox;
UpdtControl theWindow updateRgn t = code (theWindow=D0,updateRgn=D1,t=U)(z=Z){
	call	.UpdateControls
};

//	Mouse Location

FindControl :: !Int !Int !WindowPtr !*Toolbox -> (!ControlHandle,!Int,!*Toolbox);
FindControl h v theWindow t = code (h=R4D0,v=A0,theWindow=D1,t=O0D2U)(part_code=D0,whichControl=L,z=Z){
	instruction 0x52E3801E	| rlwimi	r3,r23,16,0,15
	call	.FindControl
};

TrackControl :: !ControlHandle !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
TrackControl theControl h v actionProc t = code (theControl=D0,h=D1,v=A0,actionProc=D2,t=U)(r=D0,z=Z){
	instruction 0x52E4801E	| rlwimi	r4,r23,16,0,15
	call	.TrackControl
};

TestControl :: !ControlHandle !Int !Int !*Toolbox -> (!Int,!*Toolbox);
TestControl theControl h v t = code (theControl=D0,h=D1,v=A0,t=U)(partCode=D0,z=Z){
	instruction 0x52E4801E	| rlwimi	r4,r23,16,0,15
	call	.TestControl
};

//	Control Movement and Sizing

MoveControl :: !ControlHandle !Int !Int !*Toolbox -> *Toolbox;
MoveControl theControl h v t = code (theControl=D0,h=D1,v=D2,t=U)(z=Z){
	call	.MoveControl
};

SizeControl :: !ControlHandle !Int !Int !*Toolbox -> *Toolbox;
SizeControl theControl w h t = code (theControl=D0,w=D1,h=D2,t=U)(z=Z){
	call	.SizeControl
};

//	Control Setting and Range

SetCtlValue :: !ControlHandle !Int !*Toolbox -> *Toolbox;
SetCtlValue theControl theValue t = code (theControl=D0,theValue=D1,t=U)(z=Z){
	call	.SetControlValue
};

GetCtlValue :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
GetCtlValue theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControlValue
};

SetCtlMin :: !ControlHandle !Int !*Toolbox -> *Toolbox;
SetCtlMin theControl minValue t = code (theControl=D0,minValue=D1,t=U)(z=Z){
	call	.SetControlMinimum
};

GetCtlMin :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
GetCtlMin theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControlMinimum
};

SetCtlMax :: !ControlHandle !Int !*Toolbox -> *Toolbox;
SetCtlMax theControl maxValue t = code (theControl=D0,maxValue=D1,t=U)(z=Z){
	call	.SetControlMaximum
};

GetCtlMax :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
GetCtlMax theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControlMaximum
};

HiliteControl :: !ControlHandle !Int !*Toolbox -> *Toolbox;
HiliteControl theControl hiliteState t = code (theControl=D0,hiliteState=D1,t=U)(z=Z){
	call	.HiliteControl
};

SetControlVisibility :: !ControlHandle !Bool !Bool !*Toolbox -> *Toolbox;
SetControlVisibility theControl isVisible doDraw t = code (theControl=D0,isVisible=D1,doDraw=D2,t=U)(z=Z){
	call .SetControlVisibility
};

//	Removing controls

DisposeControl :: !ControlHandle !*Toolbox -> *Toolbox;
DisposeControl theControl t = code (theControl=D0,t=U)(z=Z){
	call	.DisposeControl
};
