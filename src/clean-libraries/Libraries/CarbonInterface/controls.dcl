definition module controls;

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

//	Control Display

SetCTitle :: !ControlHandle !{#Char} !*Toolbox -> *Toolbox;
HideControl :: !ControlHandle !*Toolbox -> *Toolbox;
ShowControl :: !ControlHandle !*Toolbox -> *Toolbox;
DrawControls :: !WindowPtr !*Toolbox -> *Toolbox;
Draw1Control :: !ControlHandle !*Toolbox -> *Toolbox;
UpdtControl :: !WindowPtr !RgnHandle !*Toolbox -> *Toolbox;

//	Mouse Location

FindControl :: !Int !Int !WindowPtr !*Toolbox -> (!ControlHandle,!Int,!*Toolbox);
TrackControl :: !ControlHandle !Int !Int !Int !*Toolbox -> (!Int,!*Toolbox);
TestControl :: !ControlHandle !Int !Int !*Toolbox -> (!Int,!*Toolbox);

//	Control Movement and Sizing

MoveControl :: !ControlHandle !Int !Int !*Toolbox -> *Toolbox;
SizeControl :: !ControlHandle !Int !Int !*Toolbox -> *Toolbox;

//	Control Setting and Range

SetCtlValue :: !ControlHandle !Int !*Toolbox -> *Toolbox;
GetCtlValue :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
SetCtlMin :: !ControlHandle !Int !*Toolbox -> *Toolbox;
GetCtlMin :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
SetCtlMax :: !ControlHandle !Int !*Toolbox -> *Toolbox;
GetCtlMax :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
HiliteControl :: !ControlHandle !Int !*Toolbox -> *Toolbox;

SetControlVisibility :: !ControlHandle !Bool !Bool !*Toolbox -> *Toolbox;

//	Removing controls

DisposeControl :: !ControlHandle !*Toolbox -> *Toolbox;
