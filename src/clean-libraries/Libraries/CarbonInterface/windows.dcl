definition module windows;

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
NewCWindow :: !Ptr !Rect !{#Char} !Bool !Int !WindowPtr !Bool !Int !*Toolbox -> (!WindowPtr,!*Toolbox);
DisposeWindow :: !WindowPtr !*Toolbox -> *Toolbox;

//	Window Display

SetWTitle :: !WindowPtr !{#Char} !*Toolbox -> *Toolbox;
SelectWindow :: !WindowPtr !*Toolbox -> *Toolbox;
HideWindow :: !WindowPtr !*Toolbox -> *Toolbox;
ShowWindow :: !WindowPtr !*Toolbox -> *Toolbox;
ShowHide :: !WindowPtr !Bool !*Toolbox -> *Toolbox;
SendBehind :: !WindowPtr !WindowPtr !*Toolbox -> *Toolbox;
DrawGrowIcon :: !WindowPtr !*Toolbox -> *Toolbox;
FrontWindow :: !*Toolbox -> (!WindowPtr,!*Toolbox);

//	Mouse Location

FindWindow :: !Int !Int !*Toolbox -> (!Int,!WindowPtr,!*Toolbox);
TrackGoAway :: !WindowPtr !Int !Int !*Toolbox -> (!Bool,!*Toolbox);
TrackBox :: !WindowPtr !Int !Int !Int !*Toolbox -> (!Bool,!*Toolbox);

//	Window Movement and Sizing

MoveWindow :: !WindowPtr !Int !Int !Bool !*Toolbox -> *Toolbox;
DragWindow :: !WindowPtr !Int !Int !Rect !*Toolbox -> *Toolbox;
GrowWindow :: !WindowPtr !Int !Int !Rect !*Toolbox -> (!(!Int,!Int),!*Toolbox);
SizeWindow :: !WindowPtr !Int !Int !Bool !*Toolbox -> *Toolbox;
ZoomWindow :: !WindowPtr !Int !Bool !*Toolbox -> *Toolbox;

WindowUpdateRgn :== 34;

GetWindowRegion :: !WindowPtr !Int !RgnHandle !*Toolbox -> *Toolbox;

SetWindowStandardState :: !WindowPtr !Rect !*Toolbox -> *Toolbox;

//	Update Region Maintenance

InvalWindowRect :: !WindowPtr !Rect !*Toolbox -> *Toolbox;
ValidWindowRect :: !WindowPtr !Rect !*Toolbox -> *Toolbox;
BeginUpdate :: !WindowPtr !*Toolbox -> *Toolbox;
EndUpdate :: !WindowPtr !*Toolbox -> *Toolbox;

GetDialogWindow :: !DialogPtr !*Toolbox -> (!WindowPtr,!*Toolbox);
GetDialogFromWindow :: !WindowPtr !*Toolbox -> (!DialogPtr,!*Toolbox);
