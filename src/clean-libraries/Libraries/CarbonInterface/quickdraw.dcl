definition module quickdraw;

import mac_types;

BlackColor:==33;
WhiteColor:==30;
RedColor:==205;
GreenColor:==341;
BlueColor:==409;
CyanColor:==273;
MagentaColor:== 137;
YellowColor:== 69;

PatCopy :== 8;
PatOr :== 9;
PatXor :== 10;
PatBic :== 11;
NotPatCopy :== 12;
NotPatOr :== 13;
NotPatXor :== 14;
NotPatBic :== 15;
PatHilite :== 50;

White :== (0,0);
Black :== (-1,-1);
Gray :== (1437226410,1437226410);
LtGray :== (-2011002846,-2011002846);
DkGray :== (2011002845,2011002845);

Bold :== 1;
Italic :== 2;
Underline :== 4;
Outline :== 8;
Shadow :== 16;
Condense :== 32;
Extend :== 64;

SrcCopy :== 0;
SrcOr :== 1;
SrcXor :== 2;
SrcBic :== 3;

::	GrafPtr :== Int;
::	PicHandle :== Int;
::	PolyHandle :== Int;
::	RGBColor :== (!Int,!Int,!Int);

LMGetScrHRes :: Int;
LMGetScrVRes :: Int;

SetPortWindowPort :: !WindowPtr !*Toolbox -> *Toolbox;
SetPortDialogPort :: !DialogPtr !*Toolbox -> *Toolbox;
GetWindowPort :: !WindowPtr !*Toolbox -> (!GrafPtr,!*Toolbox);

//	GrafPort Routines

QSetPort :: !GrafPtr !*Toolbox -> *Toolbox;
QGetPort :: !*Toolbox -> (!GrafPtr,!*Toolbox);
QSetOrigin :: !Int !Int !*Toolbox -> *Toolbox;
QSetClip :: !RgnHandle !*Toolbox -> *Toolbox;
QGetClip :: !RgnHandle !*Toolbox -> (!RgnHandle,!*Toolbox);
QClipRect :: !Rect !*Toolbox -> *Toolbox;

//	Cursor-Handling Routines

QInitCursor :: !*Toolbox -> *Toolbox;
QSetCursor :: !Ptr !*Toolbox -> *Toolbox;
QHideCursor :: !*Toolbox -> *Toolbox;
QShowCursor :: !*Toolbox -> *Toolbox;
QObscureCursor :: !*Toolbox -> *Toolbox;

//	Pen and Line-Drawing Routines

QHidePen :: !*Toolbox -> *Toolbox;
QShowPen :: !*Toolbox -> *Toolbox;
QGetPen :: !*Toolbox -> (!Int,!Int,!*Toolbox);
QPenSize :: !Int !Int !*Toolbox -> *Toolbox;
QPenMode :: !Int !*Toolbox -> *Toolbox;
QPenPat :: !(!Int,!Int) !*Toolbox -> *Toolbox;
QPenNormal :: !*Toolbox -> *Toolbox;
QMoveTo :: !Int !Int !*Toolbox -> *Toolbox;
QMove :: !Int !Int !*Toolbox -> *Toolbox;
QLineTo :: !Int !Int !*Toolbox -> *Toolbox;
QLine :: !Int !Int !*Toolbox -> *Toolbox;

//	Text-Drawing Routines

QTextFont :: !Int !*Toolbox -> *Toolbox;
QTextFace :: !Int !*Toolbox -> *Toolbox;
QTextMode :: !Int !*Toolbox -> *Toolbox;
QTextSize :: !Int !*Toolbox -> *Toolbox;
QDrawChar :: !Char !*Toolbox -> *Toolbox;
QDrawString :: !{#Char} !*Toolbox -> *Toolbox;
QCharWidth :: !Char !*Toolbox -> (!Int, !*Toolbox);
QStringWidth :: !{#Char} !*Toolbox -> (!Int, !*Toolbox);
QGetFontInfo :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);

//QTextSizePrinter i t :== QTextSize i t;
//adjustToPrinterRes i :== i;
QTextSizePrinter :: !Int !*Toolbox -> *Toolbox;
adjustToPrinterRes :: !Int -> Int;
//isPrinting :: !*Toolbox ->(!Int,!*Toolbox);

//	Drawing in Color

QForeColor :: !Int !*Toolbox -> *Toolbox;
QRGBBackColor :: !RGBColor !*Toolbox -> *Toolbox;
QRGBForeColor :: !RGBColor !*Toolbox -> *Toolbox;
QSetCPixel :: !Int !Int !RGBColor !*Toolbox -> *Toolbox;
QBackColor :: !Int !*Toolbox -> *Toolbox;

//	Calculations with Rectangles

//	Graphic Operations on Rectangles

QFrameRect :: !Rect !*Toolbox -> *Toolbox;
QPaintRect :: !Rect !*Toolbox -> *Toolbox;
QEraseRect :: !Rect !*Toolbox -> *Toolbox;
QInvertRect :: !Rect !*Toolbox -> *Toolbox;

//	Graphic operations on Ovals

QFrameOval :: !Rect !*Toolbox -> *Toolbox;
QPaintOval :: !Rect !*Toolbox -> *Toolbox;
QEraseOval :: !Rect !*Toolbox -> *Toolbox;
QInvertOval :: !Rect !*Toolbox -> *Toolbox;

//	Graphic Operations on Rounded-Corner Rectangles

QFrameRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QPaintRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QEraseRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QInvertRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;

//	Graphic Operations on Arcs and Wedges

QFrameArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QPaintArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QEraseArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QInvertArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;

//	Calculations with Regions

QNewRgn :: !*Toolbox -> (!RgnHandle, !*Toolbox);
QOpenRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QCloseRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QDisposeRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QRectRgn :: !RgnHandle !Rect !*Toolbox -> *Toolbox;
QSectRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QUnionRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QDiffRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QPtInRgn :: !(!Int,!Int) !RgnHandle !*Toolbox -> (!Bool, !*Toolbox);
QEmptyRgn :: !RgnHandle !*Toolbox -> (!Bool, !*Toolbox);

GetPortBounds :: !GrafPtr !*Toolbox -> (!Rect,!*Toolbox);
GetRegionBounds :: !RgnHandle !*Toolbox -> (!Rect,!*Toolbox);
GetPortClipRegion :: !GrafPtr !RgnHandle !*Toolbox -> *Toolbox;
GetPortVisibleRegion :: !GrafPtr !RgnHandle !*Toolbox -> *Toolbox;

//	Graphic Operations on Regions

QFrameRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QPaintRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QEraseRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QInvertRgn :: !RgnHandle !*Toolbox -> *Toolbox;

//	Bit Transfer Operations

QScrollRect :: !Rect !Int !Int !RgnHandle !*Toolbox -> *Toolbox;
CopyBitsWithBitMapPointers :: !Ptr !Ptr !Rect !Rect !Int !RgnHandle !*Toolbox -> *Toolbox;
GetPortBitMapForCopyBits :: !GrafPtr !*Toolbox -> (!Ptr,!*Toolbox);
//CopyBits :: !Ptr !Int !Rect !Ptr !Int !Rect !Rect !Rect !Int !RgnHandle !*Toolbox -> *Toolbox;
	
//	Pictures

QOpenPicture :: !Rect !*Toolbox -> (!PicHandle, !*Toolbox);
QClosePicture :: !PicHandle !*Toolbox -> *Toolbox;
QDrawPicture :: !PicHandle !Rect !*Toolbox -> *Toolbox;
QKillPicture :: !PicHandle !*Toolbox -> *Toolbox;

//	Calculations with Polygons

QOpenPoly :: !*Toolbox -> (!PolyHandle, !*Toolbox);
QClosePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QKillPoly :: !PolyHandle !*Toolbox -> *Toolbox;
QOffsetPoly :: !PolyHandle !Int !Int !*Toolbox -> *Toolbox;
QOffsetRgn :: !RgnHandle !Int !Int !*Toolbox -> *Toolbox;

//	Graphic Operations on Polygons

QFramePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QPaintPoly :: !PolyHandle !*Toolbox -> *Toolbox;
QErasePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QInvertPoly :: !PolyHandle !*Toolbox -> *Toolbox;

//	Calculations with Points

//	Miscellaneous Routines

QLocalToGlobal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
QGlobalToLocal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
QScreenRect :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
HasColorQD	:: !*Toolbox -> (!Bool,!*Toolbox);
QStdTxMeas	:: !Int !{#Char} !(!Int,!Int) !(!Int,!Int) !(!Int,!Int,!Int,!Int) !*Toolbox -> (!Int,!(!Int,!Int),!(!Int,!Int),!(!Int,!Int,!Int,!Int),!*Toolbox);

GetPortTextFont :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
GetPortTextFace :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
GetPortTextSize :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
