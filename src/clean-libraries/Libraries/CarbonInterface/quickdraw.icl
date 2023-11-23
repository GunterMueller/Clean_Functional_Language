implementation module quickdraw;

import mac_types;
import StdInt;
//import code from "cPrinter.o";

import StdInt,StdClass;

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
LMGetScrHRes
	# r=LMGetScrHRes1;
	= if (r>=0) r 72;

LMGetScrHRes1 :: Int;
LMGetScrHRes1 = code ()(r=D0){
	call .LMGetScrHRes
};

LMGetScrVRes :: Int;
LMGetScrVRes
	# r=LMGetScrVRes1;
	= if (r>=0) r 72;
	
LMGetScrVRes1 :: Int;
LMGetScrVRes1 = code ()(r=D0){
	call .LMGetScrVRes
};

SetPortWindowPort :: !WindowPtr !*Toolbox -> *Toolbox;
SetPortWindowPort port t = code (port=D0,t=U)(z=Z){
	call	.SetPortWindowPort
};

SetPortDialogPort :: !DialogPtr !*Toolbox -> *Toolbox;
SetPortDialogPort port t = code (port=D0,t=U)(z=Z){
	call	.SetPortDialogPort
};

GetWindowPort :: !WindowPtr !*Toolbox -> (!GrafPtr,!*Toolbox);
GetWindowPort w t = code (w=D0,t=U)(g=D0,z=Z){
	call .GetWindowPort
};

//	GrafPort Routines

QSetPort :: !GrafPtr !*Toolbox -> *Toolbox;
QSetPort port t = code (port=D0,t=U)(z=Z){
	call	.SetPort
};

QGetPort :: !*Toolbox -> (!GrafPtr,!*Toolbox);
QGetPort t = code (t=R4O0D0U)(current_port=L,z=Z){
	call	.GetPort
};

QSetOrigin :: !Int !Int !*Toolbox -> *Toolbox;
QSetOrigin h v t = code (h=D0,v=D1,t=U)(z=Z){
	call	.SetOrigin
};

QSetClip :: !RgnHandle !*Toolbox -> *Toolbox;
QSetClip rgn t = code (rgn=D0,t=U)(z=Z){
	call	.SetClip
};

QGetClip :: !RgnHandle !*Toolbox -> (!RgnHandle,!*Toolbox);
QGetClip rgn t
//	# t = IsHandleValid rgn t
//	# t = IsHeapValid t
	# t=QGetClip1 rgn t;
	= (rgn,t);

QGetClip1 :: !RgnHandle !*Toolbox -> *Toolbox;
QGetClip1 rgn t = code (rgn=D0,t=U)(z=Z){
	call	.GetClip
};

QClipRect :: !Rect !*Toolbox -> *Toolbox;
QClipRect (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.ClipRect
};

//	Cursor-Handling Routines

QInitCursor :: !*Toolbox -> *Toolbox;
QInitCursor t = code (t=U)(z=Z){
	call	.InitCursor
};

QSetCursor :: !Ptr !*Toolbox -> *Toolbox;
QSetCursor crsr t = code (crsr=D0,t=U)(z=Z){
	call	.SetCursor
};

QHideCursor :: !*Toolbox -> *Toolbox;
QHideCursor t = code (t=U)(z=Z){
	call	.HideCursor
};

QShowCursor :: !*Toolbox -> *Toolbox;
QShowCursor t = code (t=U)(z=Z){
	call	.ShowCursor
};

QObscureCursor :: !*Toolbox -> *Toolbox;
QObscureCursor t = code (t=U)(z=Z){
	call	.ObscureCursor
};

//	Pen and Line-Drawing Routines

QHidePen :: !*Toolbox -> *Toolbox;
QHidePen t = code (t=U)(z=Z){
	call	.HidePen
};

QShowPen :: !*Toolbox -> *Toolbox;
QShowPen t = code (t=U)(z=Z){
	call	.ShowPen
};

QGetPen :: !*Toolbox -> (!Int,!Int,!*Toolbox);
QGetPen t = (x,y,t1);
{
	(y,x,t1)=QGetPen0 t;

	QGetPen0 :: !*Toolbox -> (!Int,!Int,!*Toolbox);
	QGetPen0 t = code (t=R4O0D0U)(v=W,h=W,d=Z){
		call	.GetPen
	};
}

QPenSize :: !Int !Int !*Toolbox -> *Toolbox;
QPenSize width height t = code (width=D0,height=D1,t=U)(z=Z){
	call	.PenSize
};

QPenMode :: !Int !*Toolbox -> *Toolbox;
QPenMode mode t = code (mode=D0,t=U)(z=Z){
	call	.PenMode
};

QPenPat :: !(!Int,!Int) !*Toolbox -> *Toolbox;
QPenPat (pat1,pat2) t = code (pat2=L,pat1=L,t=O0D0U)(z=I8Z){ 
	call	.PenPat
};

QPenNormal :: !*Toolbox -> *Toolbox;
QPenNormal t = code (t=U)(z=Z){
	call	.PenNormal
};

QMoveTo :: !Int !Int !*Toolbox -> *Toolbox;
QMoveTo h v t = code (h=D0,v=D1,t=U)(z=Z){
	call	.MoveTo
};

QMove :: !Int !Int !*Toolbox -> *Toolbox;
QMove dh dv t = code (dh=D0,dv=D1,t=U)(z=Z){
	call	.Move
};

QLineTo :: !Int !Int !*Toolbox -> *Toolbox;
QLineTo h v t = code (h=D0,v=D1,t=U)(z=Z){
	call	.LineTo
};


QLine :: !Int !Int !*Toolbox -> *Toolbox;
QLine dh dv t = code (dh=D0,dv=D1,t=U)(z=Z){
	call	.Line
};

//	Text-Drawing Routines

QTextFont :: !Int !*Toolbox -> *Toolbox;
QTextFont font t = code (font=D0,t=U)(z=Z){
	call	.TextFont
};

QTextFace :: !Int !*Toolbox -> *Toolbox;
QTextFace face t = code (face=D0,t=U)(z=Z){
	call	.TextFace
};

QTextMode :: !Int !*Toolbox -> *Toolbox;
QTextMode mode t = code (mode=D0,t=U)(z=Z){
	call	.TextMode
};

//QTextSizePrinter i t :== QTextSize i t;

//*
QTextSizePrinter :: !Int !*Toolbox -> *Toolbox;
QTextSizePrinter screenSize tb
// if the current picture is a printer picture, then the size of the font will be 
// adjusted to a size, that corresponds with the printer resolution
	= QTextSize (adjustToPrinterRes screenSize) tb;

adjustToPrinterRes :: !Int -> Int;	// to be found in CPrinter.c
adjustToPrinterRes _
	= code {
			ccall adjustToPrinterRes "I-I"
	};

isPrinting :: !*Toolbox ->(!Int,!*Toolbox);
isPrinting _
	= code {
			ccall isPrinting ":I:I"
	};
//*/
QTextSize :: !Int !*Toolbox -> *Toolbox;
QTextSize size t = code (size=D0,t=U)(z=Z){
	call	.TextSize
};

QDrawChar :: !Char !*Toolbox -> *Toolbox;
QDrawChar char t = code (char=D0,t=U)(z=Z){
	call	.DrawChar
};

QDrawString :: !{#Char} !*Toolbox -> *Toolbox;
/*
QDrawString s t = code (s=U,t=U)(z=Z){
	instruction	0x38800000	|	li		r4,0
	instruction	0x38770008	|	addi	r3,r23,8
	instruction	0x80B70004	|	lwz		r5,4(r23)
	call	.DrawText
};
*/
QDrawString s t = code (s=CD0S2,t=U)(z=Z){
	instruction	0x38800000	|	li		r4,0
	call	.DrawText
};

QCharWidth :: !Char !*Toolbox -> (!Int,!*Toolbox);
QCharWidth char t = code (char=D0,t=U)(width=D0,z=Z){
	call	.CharWidth
};

QStringWidth :: !{#Char} !*Toolbox -> (!Int,!*Toolbox);
QStringWidth s t = code (s=CD0S2,t=U)(width=D0,z=Z){
	instruction	0x38800000	|	li		r4,0
	call	.TextWidth
};

QGetFontInfo :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
QGetFontInfo t = code (t=R8O0D0U)(ascent=W,descent=W,widMax=W,leading=W,z=Z){
	call	.GetFontInfo
};

//	Drawing in Color

QForeColor :: !Int !*Toolbox -> *Toolbox;
QForeColor color t = code (color=D0,t=U)(z=Z){
	call	.ForeColor
};

QRGBBackColor :: !RGBColor !*Toolbox -> *Toolbox;
QRGBBackColor (red,green,blue) t = code (blue=R2W,green=W,red=W,t=O0D0U)(z=I8Z){
	call	.RGBBackColor
};

QRGBForeColor :: !RGBColor !*Toolbox -> *Toolbox;
QRGBForeColor (red,green,blue) t = code (blue=R2W,green=W,red=W,t=O0D0U)(z=I8Z){
	call	.RGBForeColor
};

QSetCPixel :: !Int !Int !RGBColor !*Toolbox -> *Toolbox;
QSetCPixel h v (red,green,blue) t = code (blue=R2W,green=W,red=W,h=D0,v=D1,t=O0D2U)(z=I8Z){
	call	.SetCPixel
};

QBackColor :: !Int !*Toolbox -> *Toolbox;
QBackColor color t = code (color=D0,t=U)(z=Z){
	call	.BackColor
};

//	Calculations with Rectangles

//	Graphic Operations on Rectangles

QFrameRect :: !Rect !*Toolbox -> *Toolbox;
QFrameRect (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.FrameRect
};

QPaintRect :: !Rect !*Toolbox -> *Toolbox;
QPaintRect (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.PaintRect
};

QEraseRect :: !Rect !*Toolbox -> *Toolbox;
QEraseRect (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.EraseRect
};

QInvertRect :: !Rect !*Toolbox -> *Toolbox;
QInvertRect (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.InvertRect
};

//	Graphic operations on Ovals

QFrameOval :: !Rect !*Toolbox -> *Toolbox;
QFrameOval (left,top,right,bottom) t = code (right=W, bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.FrameOval
};

QPaintOval :: !Rect !*Toolbox -> *Toolbox;
QPaintOval (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.PaintOval
};

QEraseOval :: !Rect !*Toolbox -> *Toolbox;
QEraseOval (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.EraseOval
};

QInvertOval :: !Rect !*Toolbox -> *Toolbox;
QInvertOval (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=O0D0U)(z=I8Z){
	call	.InvertOval
};

//	Graphic Operations on Rounded-Corner Rectangles

QFrameRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QFrameRoundRect (left,top,right,bottom) ovalWidth ovalHeight t
= code (right=W,bottom=W,left=W,top=W,ovalWidth=O0D0D1,ovalHeight=D2,t=U)(z=I8Z){
	call	.FrameRoundRect
};

QPaintRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QPaintRoundRect (left,top,right,bottom) ovalWidth ovalHeight t
= code (right=W,bottom=W,left=W,top=W,ovalWidth=O0D0D1,ovalHeight=D2,t=U)(z=I8Z){
	call	.PaintRoundRect
};

QEraseRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QEraseRoundRect (left,top,right,bottom) ovalWidth ovalHeight t
= code (right=W,bottom=W,left=W,top=W,ovalWidth=O0D0D1,ovalHeight=D2,t=U)(z=I8Z){
	call	.EraseRoundRect
};

QInvertRoundRect :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QInvertRoundRect (left,top,right,bottom) ovalWidth ovalHeight t
= code (right=W,bottom=W,left=W,top=W,ovalWidth=O0D0D1,ovalHeight=D2,t=U)(z=I8Z){
	call	.InvertRoundRect
};

//	Graphic Operations on Arcs and Wedges

QFrameArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QFrameArc (left,top,right,bottom) startAngle arcAngle t
= code (right=W,bottom=W,left=W,top=W,startAngle=O0D0D1,arcAngle=D2,t=U)(z=I8Z){
	call	.FrameArc
};

QPaintArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QPaintArc (left,top,right,bottom) startAngle arcAngle t
= code (right=W,bottom=W,left=W,top=W,startAngle=O0D0D1,arcAngle=D2,t=U)(z=I8Z){
	call	.PaintArc
};

QEraseArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QEraseArc (left,top,right,bottom) startAngle arcAngle t
= code (right=W,bottom=W,left=W,top=W,startAngle=O0D0D1,arcAngle=D2,t=U)(z=I8Z){
	call	.EraseArc
};

QInvertArc :: !Rect !Int !Int !*Toolbox -> *Toolbox;
QInvertArc (left,top,right,bottom) startAngle arcAngle t
= code (right=W,bottom=W,left=W,top=W,startAngle=O0D0D1,arcAngle=D2,t=U)(z=I8Z){
	call	.InvertArc
};

//	Calculations with Regions

QNewRgn :: !*Toolbox -> (!RgnHandle, !*Toolbox);
QNewRgn t = code (t=U)(region=D0,z=Z){
	call	.NewRgn
};

QOpenRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QOpenRgn region t = code (region=U,t=U)(z=Z){
	call	.OpenRgn
};

QCloseRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QCloseRgn region t = code (region=D0,t=U)(z=Z){
	call	.CloseRgn
};

QDisposeRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QDisposeRgn region t = code (region=D0,t=u)(z=Z){
	call	.DisposeRgn
};

QRectRgn :: !RgnHandle !Rect !*Toolbox -> *Toolbox;
QRectRgn rgn (left,top,right,bottom) t = code (right=W, bottom=W, left=W, top=W,rgn=D0,t=O0D1U)(z=I8Z){
	call	.RectRgn
};

QSectRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QSectRgn srcRgnA srcRgnB dstRgn t = code (srcRgnA=D0,srcRgnB=D1,dstRgn=D2,t=U)(srcRgn`=A0,z=Z){
	call	.SectRgn
};

QUnionRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QUnionRgn srcRgnA srcRgnB dstRgn t = code (srcRgnA=D0,srcRgnB=D1,dstRgn=D2,t=U)(srcRgn`=A0,z=Z){
	call	.UnionRgn
};

QDiffRgn :: !RgnHandle !RgnHandle !RgnHandle !*Toolbox -> (!RgnHandle, !*Toolbox);
QDiffRgn srcRgnA srcRgnB dstRgn t = code (srcRgnA=D0,srcRgnB=D1,dstRgn=D2,t=U)(srcRgn`=A0,z=Z){
	call	.DiffRgn
};

QPtInRgn :: !(!Int,!Int) !RgnHandle !*Toolbox -> (!Bool,!*Toolbox);
QPtInRgn (x,y) rgn t = code (x=D0,y=A0,rgn=D1,t=U)(b=B0,z=Z){
	instruction 0x52E3801E	|	rlwimi	r3,r23,16,0,15
	call	.PtInRgn
};

QEmptyRgn :: !RgnHandle !*Toolbox -> (!Bool, !*Toolbox);
QEmptyRgn region t = code (region=D0,t=U)(empty_region=B0,z=Z){
	call	.EmptyRgn
};

GetPortBounds :: !GrafPtr !*Toolbox -> (!Rect,!*Toolbox);
GetPortBounds port t
	# ((top,left,bottom,right),t) = GetPortBounds1 port t;
	= ((left,top,right,bottom),t);

GetPortBounds1 :: !GrafPtr !*Toolbox -> (!Rect,!*Toolbox);
GetPortBounds1 port t = code (port=D0,t=R8O0D1U)(top=W,left=W,bottom=W,right=W,z=Z){
	call .GetPortBounds
};

GetRegionBounds :: !RgnHandle !*Toolbox -> (!Rect,!*Toolbox);
GetRegionBounds rgn t
	# ((top,left,bottom,right),t) = GetRegionBounds1 rgn t;
	= ((left,top,right,bottom),t);

GetRegionBounds1 :: !RgnHandle !*Toolbox -> (!Rect,!*Toolbox);
GetRegionBounds1 rgn t = code (rgn=D0,t=R8O0D1U)(top=W,left=W,bottom=W,right=W,z=Z){
	call .GetRegionBounds
};

GetPortClipRegion :: !GrafPtr !RgnHandle !*Toolbox -> *Toolbox;
GetPortClipRegion port clipRgn t = code (port=D0,clipRgn=D1,t=U)(z=Z){
	call .GetPortClipRegion
};

GetPortVisibleRegion :: !GrafPtr !RgnHandle !*Toolbox -> *Toolbox;
GetPortVisibleRegion port clipRgn t = code (port=D0,clipRgn=D1,t=U)(z=Z){
	call .GetPortVisibleRegion
};

//	Graphic Operations on Regions

QFrameRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QFrameRgn region t = code (region=D0,t=U)(z=Z){
	call	.FrameRgn
};

QPaintRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QPaintRgn region t = code (region=D0,t=U)(z=Z){
	call	.PaintRgn
};

QEraseRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QEraseRgn region t = code (region=D0,t=U)(z=Z){
	call	.EraseRgn
};

QInvertRgn :: !RgnHandle !*Toolbox -> *Toolbox;
QInvertRgn region t = code (region=D0,t=U)(z=Z){
	call	.InvertRgn
};

//	Bit Transfer Operations

QScrollRect :: !Rect !Int !Int !RgnHandle !*Toolbox -> *Toolbox;
QScrollRect (left,top,right,bottom) dh dv updateRgn t
= code (right=W,bottom=W,left=W,top=W,dh=O0D0D1,dv=D2,updateRgn=D3,t=U)(z=I8Z){
	call	.ScrollRect
};

CopyBitsWithBitMapPointers :: !Ptr !Ptr !Rect !Rect !Int !RgnHandle !*Toolbox -> *Toolbox;
CopyBitsWithBitMapPointers source_pointer dest_pointer
	(srcLeft,srcTop,srcRight,srcBottom) (destLeft,destTop,destRight,destBottom) mode maskRgn t
= code (
	source_pointer=D0,dest_pointer=D1,
	srcRight=W, srcBottom=W, srcLeft=W, srcTop=W,
	destRight=W, destBottom=W, destLeft=W, destTop=W,
	mode=D4, maskRgn=D5, t=O8D2O0D3U)(z=I16Z)
{
	call	.CopyBits
};

GetPortBitMapForCopyBits :: !GrafPtr !*Toolbox -> (!Ptr,!*Toolbox);
GetPortBitMapForCopyBits g t = code (g=D0,t=U)(bitmap_pointer=D0,z=Z){
	call .GetPortBitMapForCopyBits
};
/*
CopyBits :: !Ptr !Int !Rect !Ptr !Int !Rect !Rect !Rect !Int !RgnHandle !*Toolbox -> *Toolbox;
CopyBits
	srcBaseAddr srcRowBytes (srcBoundsLeft,srcBoundsTop,srcBoundsRight,srcBoundsBottom)
	destBaseAddr destRowBytes (destBoundsLeft,destBoundsTop,destBoundsRight,destBoundsBottom)
	(srcLeft,srcTop,srcRight,srcBottom) (destLeft,destTop,destRight,destBottom)
	mode maskRgn t =
code (
	srcBoundsRight=W, srcBoundsBottom=W, srcBoundsLeft=W, srcBoundsTop=W, srcRowBytes=W, srcBaseAddr=L,
	destBoundsRight=W, destBoundsBottom=W, destBoundsLeft=W, destBoundsTop=W, destRowBytes=W, destBaseAddr=L,
	srcRight=W, srcBottom=W, srcLeft=W, srcTop=W,
	destRight=W, destBottom=W, destLeft=W, destTop=W,
	mode=D4, maskRgn=D5, t=O30D0O16D1O8D2O0D3U)(z=I44Z)
{
	call	.CopyBits
};
*/
//	Pictures

QOpenPicture :: !Rect !*Toolbox -> (!PicHandle, !*Toolbox);
QOpenPicture (left,top,right,bottom) t = code (right=W,bottom=W,left=W,top=W,t=R4O4D0D1)(pic_handle=L,z=I8Z){
	call	.OpenPicture
};

QClosePicture :: !PicHandle !*Toolbox -> *Toolbox;
QClosePicture picture t = code (picture=U,t=U)(z=Z){
	call	.ClosePicture
};

QDrawPicture :: !PicHandle !Rect !*Toolbox -> *Toolbox;
//QDrawPicture picture (left,top,right,bottom) c = code (right=W,bottom=W,left=W,top=W,picture=D0,c=O4D1U)(z=I8Z){
QDrawPicture picture (left,top,right,bottom) c = code (right=W,bottom=W,left=W,top=W,picture=D0,c=O0D1U)(z=I8Z){
	call	.DrawPicture
};

QKillPicture :: !PicHandle !*Toolbox -> *Toolbox;
QKillPicture picture t = code (picture=D0,t=U)(z=Z){
	call	.KillPicture
};

//	Calculations with Polygons

QOpenPoly :: !*Toolbox -> (!PolyHandle, !*Toolbox);
QOpenPoly t = code (t=D0)(poly=D0,z=Z){
	call	.OpenPoly
};

QClosePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QClosePoly poly t = code (poly=U,t=U)(z=Z){
	call	.ClosePoly
};

QKillPoly :: !PolyHandle !*Toolbox -> *Toolbox;
QKillPoly poly t = code (poly=D0,t=U)(z=Z){
	call	.KillPoly
};

QOffsetPoly :: !PolyHandle !Int !Int !*Toolbox -> *Toolbox;
QOffsetPoly poly dh dv t = code (poly=D0,dh=D1,dv=D2,t=U)(z=Z){
	call	.OffsetPoly
};

QOffsetRgn :: !RgnHandle !Int !Int !*Toolbox -> *Toolbox;
QOffsetRgn region dh dv t = code (region=D0,dh=D1,dv=D2,t=U)(z=Z){
	call	.OffsetRgn
};

//	Graphic Operations on Polygons

QFramePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QFramePoly poly t = code (poly=D0,t=U)(z=Z){
	call	.FramePoly
};

QPaintPoly :: !PolyHandle !*Toolbox -> *Toolbox;
QPaintPoly poly t = code (poly=D0,t=U)(z=Z){
	call	.PaintPoly
};

QErasePoly :: !PolyHandle !*Toolbox -> *Toolbox;
QErasePoly poly t = code (poly=D0,t=U)(z=Z){
	call	.ErasePoly
};

QInvertPoly :: !PolyHandle !*Toolbox -> *Toolbox;
QInvertPoly poly t = code (poly=D0,t=U)(z=Z){
	call	.InvertPoly
};

//	Calculations with Points

//	Miscellaneous Routines

QLocalToGlobal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
QLocalToGlobal h v t = (nh,nv,z);
{
	(nv,nh,z)= QLocalToGlobal h v t;

	QLocalToGlobal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
	QLocalToGlobal h v t = code (h=W,v=W,t=O0D0U)(nvr=W,nhr=W,zr=Z){
		call	.LocalToGlobal
	};
}

QGlobalToLocal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
QGlobalToLocal h v t = (nh,nv,z);
{
	(nv,nh,z)= QGlobalToLocal h v t;
	
	QGlobalToLocal :: !Int !Int !*Toolbox -> (!Int,!Int,!*Toolbox);
	QGlobalToLocal h v t = code (h=W,v=W,t=O0D0U)(nvr=W,nhr=W,zr=Z){
		call	.GlobalToLocal
	};
}

QScreenRect :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
QScreenRect tb = (left, top, right, bottom, tb);
	{
		(left,top,right,bottom) = QScreenRect1 0;
	};

QScreenRect1 :: !Int -> (!Int,!Int,!Int,!Int);
QScreenRect1 dummy = code (dummy=R56O0D0U)(left=I56A0,top=A0,right=A0,bottom=A0){
	call	.GetQDGlobalsScreenBits
	instruction 0xAB430006	| lha	r26,6(r3)
	instruction 0xAB630008	| lha	r27,8(r3)
	instruction 0xAB03000A	| lha	r24,10(r3)
	instruction 0xAB23000C	| lha	r25,12(r3)
};


HasColorQD :: !*Toolbox -> (!Bool,!*Toolbox);
HasColorQD tb = (True,tb);

HasColorQD1 :: Bool;
HasColorQD1 = True;

//	Customizing Quickdraw Operations

QStdTxMeas :: !Int !{#Char} !(!Int,!Int) !(!Int,!Int) !(!Int,!Int,!Int,!Int) !*Toolbox -> (!Int,!(!Int,!Int),!(!Int,!Int),!(!Int,!Int,!Int,!Int),!*Toolbox);
QStdTxMeas byteCount s (srcnumerh,srcnumerv) (srcdenomh,srcdenomv) (srcascent,srcdescent,srcwidMax,srcleading) tb
	= (width,(destnumerh,destnumerv),(destdenomh,destdenomv),(destascent,destdescent,destwidMax,destleading),tb1)
where {
	(width,numer,denom,ascdesc,widlead,tb1)
		= QStdTxMeas` byteCount s srcnumerv srcnumerh srcdenomv srcdenomh srcascent srcdescent srcwidMax srcleading tb;
	(destnumerh,destnumerv)	= longTo2Word numer;
	(destdenomh,destdenomv)	= longTo2Word denom;
	(destdescent,destascent)= longTo2Word ascdesc;
	(destleading,destwidMax)= longTo2Word widlead;
};

QStdTxMeas` :: !Int !{#Char} !Int !Int !Int !Int !Int !Int !Int !Int !*Toolbox -> (!Int,!Int,!Int,!Int,!Int,!*Toolbox);
QStdTxMeas` byteCount s srcnumerv srcnumerh srcdenomv srcdenomh srcascent srcdescent srcwidMax srcleading tb
	= code	(srcleading=W,srcwidMax=W,srcdescent=W,srcascent=W,srcdenomh=W,srcdenomv=W,srcnumerh=W,srcnumerv=W,byteCount=D0,s=U,tb=O0D2O4D3O16D4U)
			(width=D0,numer=L,denom=L,ascdesc=L,widlead=L,z=Z){
		instruction	0x38970008		|	addi	r4,r23,8
		call	.StdTxMeas
	};

longTo2Word :: !Int -> (!Int,!Int);
longTo2Word long = (word1,word2);
where {
	word1	= (long<<16)>>16;
	word2	= long>>16;
};

GetPortTextFont :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
GetPortTextFont port t = code (port=D0,t=U)(n=D0,z=Z){
	call .GetPortTextFont
};

GetPortTextFace :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
GetPortTextFace port t = code (port=D0,t=U)(n=D0,z=Z){
	call .GetPortTextFace
};

GetPortTextSize :: !GrafPtr !*Toolbox -> (!Int,*Toolbox);
GetPortTextSize port t = code (port=D0,t=U)(n=D0,z=Z){
	call .GetPortTextSize
};

//----------

import StdMisc, StdString;

IsHeapValid :: !*Toolbox -> *Toolbox;
IsHeapValid tb
	# (r,tb)	= IsHeapValid tb;
	| r==0		= abort "Invalid Heap detected\n";
	= tb;
where {
	IsHeapValid :: !*Toolbox -> (!Int,!*Toolbox);
	IsHeapValid _ = code {
		ccall IsHeapValid ":I:I"
		};
};

IsHandleValid :: !Int !*Toolbox -> *Toolbox;
IsHandleValid handle tb
	# (r,tb)	= IsHandleValid handle tb;
	| r==0		= abort ("Invalid Handle detected: "+++toString handle+++"\n");
	= tb;
where {
	IsHandleValid :: !Int !*Toolbox -> (!Int,!*Toolbox);
	IsHandleValid _ _ = code {
		ccall IsHandleValid "I:I:I"
		};
};
