implementation module textedit;

import mac_types;
import StdInt;// import class +;
import StdArray;// import size,size_u;
from pointer import LoadLong;

::	TEHandle	:==	Handle;
::	CharsHandle	:==	Handle;

TEFlushDefault	:==	0;		TEJustLeft		:==	0;		// Flush according to system direction
TECenter		:==	1;		TEJustCenter	:==	1;		// Centered for all scripts
TEFlushRight	:==	-1;		TEJustRight		:==	-1;		// Flush right for all scripts
TEFlushLeft		:==	-2;		TEForceLeft		:==	-2;		// Flush left for all scripts

TEScrpHandle	:==	2740;								// Handle to TextEdit scrap (0xAB4)
TEScrpLength	:==	2736;								// Size in bytes of TextEdit scrap (long, 0xAB0)

teLengthOffset	:==	60;									// The offset to the teLength field in a TERec record
hTextOffset		:==	62;									// The offset to the hText    field in a TERec record


//	Initialization, creation and disposing.
TEInit :: !*Toolbox -> *Toolbox;
TEInit t = code (t=U)(z=Z){
	call	.TEInit
};

TENew :: !Rect !Rect !*Toolbox -> (!TEHandle,!*Toolbox);
TENew (left1,top1,right1,bottom1) (left2,top2,right2,bottom2) t
=	code (right1=W,bottom1=W,left1=W,top1=W,right2=W,bottom2=W,left2=W,top2=W,t=O8D0O0D1U)(hTE=D0,z=I16Z){
	call	.TENew
};

TEDispose :: !TEHandle !*Toolbox -> *Toolbox;
TEDispose hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEDispose
};

//	Activating, deactivating.
TEActivate :: !TEHandle !*Toolbox -> *Toolbox;
TEActivate hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEActivate
};

TEDeactivate :: !TEHandle !*Toolbox -> *Toolbox;
TEDeactivate hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEDeactivate
};

//	Setting and getting text.
TEKey :: !Char !TEHandle !*Toolbox -> *Toolbox;
TEKey key hTE t = code (key=D0,hTE=D1,t=U)(z=Z){
	call	.TEKey
};

TESetText :: !{#Char} !TEHandle !*Toolbox -> *Toolbox;
TESetText string hTE t = TESetText1 string (size string) hTE t;

TESetText1 :: !{#Char} !Int !TEHandle !*Toolbox -> *Toolbox;
TESetText1 text length hTE t = code (text=SD0,length=D1,hTE=D2,t=U)(z=Z){
	instruction	0x38770008	|	addi	r3,r23,8
	call	.TESetText
};

TEGetText :: !TEHandle !*Toolbox -> (!CharsHandle,!*Toolbox);
TEGetText hTE tb
#	(tePtr,tb)	= LoadLong hTE tb;
	(charsH,tb)	= LoadLong (tePtr+hTextOffset) tb
=	(charsH,tb);

//	Setting caret and selection.
TEIdle :: !TEHandle !*Toolbox -> *Toolbox;
TEIdle hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEIdle
};

TEClick :: !(!Int,!Int) !Bool !TEHandle !*Toolbox -> *Toolbox;
TEClick (h,v) extend hTE t = code (h=D0,v=A0,extend=D1,hTE=D2,t=U)(z=Z){
	instruction	0x52E3801E	|	rlwimi	r3,r23,16,0,15
	call	.TEClick
};

TESetSelect :: !Int !Int !TEHandle !*Toolbox -> *Toolbox;
TESetSelect selStart selEnd hTE t = code (selStart=D0,selEnd=D1,hTE=D2,t=U)(z=Z){
	call	.TESetSelect
};

//	Displaying and scrolling text.
TEUpdate :: !Rect !TEHandle !*Toolbox -> *Toolbox;
TEUpdate (left,top,right,bottom) hTE t = code (right=W,bottom=W,left=W,top=W,hTE=O0D0D1,t=U)(z=I8Z){
	call	.TEUpdate
};

TETextBox :: !{#Char} !Rect !Int !*Toolbox -> *Toolbox;
TETextBox text rect align t = TETextBox1 text (size text) rect align t;

TETextBox1 :: !{#Char} !Int !Rect !Int !*Toolbox -> *Toolbox;
TETextBox1 text length (left,top,right,bottom) align t
=	code (right=W,bottom=W,left=W,top=W,text=SD0,length=D1,align=O0D2D3,t=U)(z=I8Z){
	instruction 0x38770008	|	addi	r3,r23,8
	call	.TETextBox
};

TECalText :: !TEHandle !*Toolbox -> *Toolbox;
TECalText hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TECalText
};

TEScroll :: !Int !Int !TEHandle !*Toolbox -> *Toolbox;
TEScroll dh dv hTE t = code (dh=D0,dv=D1,hTE=D2,t=U)(z=Z){
	call	.TEScroll
};

TEPinScroll :: !Int !Int !TEHandle !*Toolbox -> *Toolbox;
TEPinScroll dh dv hTE t = code (dh=D0,dv=D1,hTE=D2,t=U)(z=Z){
	call	.TEPinScroll
};

TEAutoView :: !Bool !TEHandle !*Toolbox -> *Toolbox;
TEAutoView fAuto hTE t = code (fAuto=D0,hTE=D1,t=U)(z=Z){
	call	.TEAutoView
};

TESelView :: !TEHandle !*Toolbox -> *Toolbox;
TESelView hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TESelView
};

//	Modifying text.
TEDelete :: !TEHandle !*Toolbox -> *Toolbox;
TEDelete hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEDelete
};

TEInsert :: !{#Char} !TEHandle !*Toolbox -> *Toolbox;
TEInsert string hTE t = TEInsert` string (size string) hTE t;

TEInsert` :: !{#Char} !Int !TEHandle !*Toolbox -> *Toolbox;
TEInsert` text length hTE t = code (text=SD0,length=D1,hTE=D2,t=U)(z=Z){
	instruction	0x38770008	|	addi	r3,r23,8
	call	.TEInsert
};

TECut :: !TEHandle !*Toolbox -> *Toolbox;
TECut hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TECut
};

TECopy :: !TEHandle !*Toolbox -> *Toolbox;
TECopy hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TECopy
};

TEPaste :: !TEHandle !*Toolbox -> *Toolbox;
TEPaste hTE t = code (hTE=D0,t=U)(z=Z){
	call	.TEPaste
};

//	Byte offsets and Points.

TEGetOffset :: !(!Int,!Int) !TEHandle !*Toolbox -> (!Int,!*Toolbox);
TEGetOffset (h,v) hTE t = code (h=D0,v=A0,hTE=D1,t=U)(offset=D0,z=Z){
	instruction	0x52E3801E	|	rlwimi	r3,r23,16,0,15
	call	.TEGetOffset
};
