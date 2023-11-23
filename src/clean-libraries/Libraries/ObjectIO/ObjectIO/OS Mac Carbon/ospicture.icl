implementation module ospicture

//
//	Drawing functions and other operations on Pictures. 
//

import	StdInt, StdBool, StdReal, StdList, StdFunc, StdMisc
import	pointer, fonts, print
import	commondef, StdPictureDef, osfont, StdIOBasic
from	quickdraw import QGetPort, QSetPort, QForeColor, QBackColor, QPenNormal
from	quickdraw import QFrameRect, QPaintRect, QEraseRect
from	quickdraw import QKillPoly, QPaintPoly, QClosePoly, QOpenPoly, :: PolyHandle
from	quickdraw import QLineTo, QMoveTo, QGetPen, QDrawString, QFrameOval, QPaintOval
from	quickdraw import QTextMode, SrcXor, QPenMode, PatHilite, PatXor, SrcOr, BlackColor
from	quickdraw import QGetClip, QNewRgn, QSetClip, QSectRgn, HasColorQD, QDrawChar
from	quickdraw import GreenColor, BlueColor, CyanColor, MagentaColor, YellowColor, :: RGBColor
from	quickdraw import QRGBBackColor, WhiteColor, QDisposeRgn, PatCopy, QEraseOval, QFrameArc
from	quickdraw import QPenSize, QMove, QRGBForeColor, RedColor, QErasePoly, QLine, QScrollRect
from	quickdraw import QClipRect, SetPortWindowPort
from	windows import NewWindow, NewCWindow, DisposeWindow
import ostoolbox, ostypes, osutil, osrgn

//from dodebug import trace_n`
trace_n _ f :== f

::	*Picture =
	{ pTb			:: !*OSToolbox
	, pOrigin		:: !Origin
	, pPen			:: !*Pen
	, pContext		:: !OSPictContext
	, pFont			:: !(!Int,!Int,!Int)
	, pScreen		:: !Bool
	}

::	Origin	:==	Point2

//:: OSPictContext = OSPictContext	// DvA: to be invented & moved to ostypes to avoid dcl cycle

:: Pen =
	{ penSize		:: !Int
//	, penColour		:: !Colour
	, penForeColour	:: !Colour
	, penBackColour	:: !Colour
	, penPos		:: !.Point2
	, penFont		:: !Font
	}

pictureError :: String String -> .x
pictureError rule message = error rule "StdPicture" message

//	Conversion of OSToolbox to Picture and vise versa.

packPicture :: !Origin !*Pen !Bool !OSPictContext !*OSToolbox -> *Picture
packPicture origin pen=:{penSize,penPos,penForeColour,penBackColour,penFont} toScreen context tb
	# (gPtr,tb) = QGetPort tb
	# (font,tb) = GrafPtrGetFont gPtr tb
	# p	= {pTb=tb,pOrigin=origin,pPen=defaultPen,pContext=context,pScreen=toScreen, pFont = font}
	  p	= setpictpensize		penSize	p
	  p	= setpictpenpos			penPos		p
	  p	= setpictpencolour		penForeColour	p
	  p = setpictbackcolour		penBackColour p
	  p	= setpictpenfont		penFont	p
	= p

unpackPicture :: !*Picture -> (!Origin,!*Pen,!Bool,!OSPictContext,!*OSToolbox)
unpackPicture {pTb,pOrigin,pPen,pScreen,pContext,pFont}
	# pTb = GrafPtrSetFont pFont pTb
	# pTb = QPenNormal pTb
	# pTb = QForeColor BlackColor pTb
	# pTb = QBackColor WhiteColor pTb
	= (pOrigin,pPen,pScreen,pContext,pTb)

peekPicture :: !*Picture -> (!Origin,!*Pen,!Bool,!OSPictContext,!*OSToolbox)
peekPicture {pTb,pOrigin,pContext,pScreen,pPen} =
	(pOrigin,pPen,pScreen,pContext,pTb)

unpeekPicture :: !Origin !*Pen !Bool !OSPictContext !*OSToolbox -> *Picture
unpeekPicture origin pen=:{penSize,penPos,penForeColour,penBackColour,penFont} toScreen context tb
	# (gPtr,tb) = QGetPort tb
	# (font,tb) = GrafPtrGetFont gPtr tb
	=	{pTb=tb,pOrigin=origin,pPen=pen,pScreen=toScreen,pContext=context,pFont=font}

peekOSPictContext :: !*Picture -> (!OSPictContext,!*Picture)
peekOSPictContext pict=:{pContext} =
	(pContext, pict)
/*
sharePicture		:: !*Picture -> (!Picture,!*Picture)
sharePicture pict=:{pOrigin,pPen,pContext,pScreen,pFont}
	# (sPen,uPen)	= sharePen pPen
	# sPicture		= {pTb = OSNewToolbox, pOrigin = pOrigin, pPen = sPen, pContext = pContext, pScreen = pScreen, pFont = pFont}
	# uPicture		= {pict & pPen = uPen}
//	# sPicture = trace_n "sharePicture" sPicture
	= (sPicture,uPicture)
*/
peekScreen :: !.(St *Picture .x) !*OSToolbox -> (!.x,!*OSToolbox)
peekScreen f tb
	# (curPort,tb)		= QGetPort tb
	# (hasColour,tb)	= HasColorQD tb
	  create			= if hasColour NewCWindow NewWindow
	# (newPort,tb)		= create 0 (0,0,20,20)/*{rtop=0,rleft=0,rright=20,rbottom=20}*/ "" False 0 (-1) False 0 tb
	| newPort == 0
		= abort "ospicture:peekScreen:failed to create screen window.\n"
//	# tb				= QSetPort newPort tb
	# tb = SetPortWindowPort newPort tb
	# picture			= packPicture zero defaultPen True 0 tb
	# (x,picture)		= f picture
	# (_,_,_,_,tb)		= unpackPicture picture
	# tb				= QSetPort curPort tb
	# tb				= DisposeWindow newPort tb
	= (x,tb)

defaultPen :: *Pen
defaultPen =
	{ penSize			= 1
	, penPos			= {x=0,y=0}
	, penForeColour		= Black
	, penBackColour		= White
	, penFont			= defaultFont
	}
where
	(defaultFont,_) = osDefaultfont OSNewToolbox

dialogPen :: *Pen
dialogPen =
	{ penSize			= 1
	, penPos			= {x=0,y=0}
	, penForeColour		= Black
	, penBackColour		= White
	, penFont			= dialogFont
	}
where
	(dialogFont,_) = osDialogfont OSNewToolbox


//	Picture interface functions.
/*	PA: Not used.
drawat :: !Point2 !(!*OSToolbox -> *OSToolbox) !*Picture -> *Picture
drawat pos=:{x=tox,y=toy} drawf p=:{pTb,pOrigin={x=ox,y=oy},pPen={penPos={x,y}}}
	# tb	= QMoveTo (tox-ox) (toy-oy) pTb
	  tb	= drawf   tb
	  tb	= QMoveTo (x-ox) (y-oy) tb
	= {p & pTb=tb}
*/

/*	Picture interface functions.
*/
apppicttoolbox :: !(IdFun *OSToolbox) !*Picture -> *Picture
apppicttoolbox f picture=:{pTb}
	# (pOrigin,pPen,pScreen,pContext,pTb) = unpackPicture picture
	# pTb = f pTb
	= packPicture pOrigin pPen pScreen pContext pTb

accpicttoolbox :: !(St *OSToolbox .x) !*Picture -> (!.x,!*Picture)
accpicttoolbox f picture=:{pTb}
	# (pOrigin,pPen,pScreen,pContext,pTb) = unpackPicture picture
	# (x,pTb) = f pTb
	= (x,packPicture pOrigin pPen pScreen pContext pTb)

setPenAttribute :: !PenAttribute !u:Pen -> u:Pen
setPenAttribute (PenSize   size)   pen =
	{pen & penSize      =max 1 size}
setPenAttribute (PenPos    {x,y})  pen =
	{pen & penPos       ={x=x,y=y} }
setPenAttribute (PenColour colour) pen =
	{pen & penForeColour=colour    }
setPenAttribute (PenBack   colour) pen =
	{pen & penBackColour=colour    }
setPenAttribute (PenFont   font)   pen =
	{pen & penFont      =font      }

sharePen :: !*Pen -> (!Pen,!*Pen)
sharePen pen=:{penSize,penForeColour,penBackColour,penPos,penFont}
	# (sPenPos,uPenPos)	= sharePoint penPos
	= ({penSize=penSize,penForeColour=penForeColour,penBackColour=penBackColour,penPos=sPenPos,penFont=penFont},{pen & penPos=uPenPos})
where
	sharePoint :: !*Point2 -> (!Point2,!*Point2)
	sharePoint point=:{x,y} = ({x=x,y=y},point)

copyPen :: !Pen -> *Pen
copyPen {penSize,penForeColour,penBackColour,penPos={x,y},penFont}
	= {penSize=penSize,penForeColour=penForeColour,penBackColour=penBackColour,penPos={x=x,y=y},penFont=penFont}


/*	Attribute functions.
*/
getpictpen :: !*Picture -> (!Pen,!*Picture)
getpictpen picture=:{pPen}
	# (sPen,uPen)	= sharePen pPen
	= (sPen,{picture & pPen=uPen})

setpictpen :: !Pen !*Picture -> *Picture
setpictpen {penSize,penPos,penForeColour,penBackColour,penFont} p
	# p = setpictpensize	penSize	p
	# p = setpictpenpos		penPos	p
	# p = setpictpencolour	penForeColour	p
	# p = setpictbackcolour penBackColour p
	# p = setpictpenfont	penFont	p
	= p

setpictorigin :: !Origin !*Picture -> *Picture
setpictorigin origin p
	= {p & pOrigin = origin}
	
getpictorigin :: !*Picture -> (!Origin,!*Picture)
getpictorigin p=:{pOrigin}
	= (pOrigin,p)
	

//	Set & Get the PenPosition:
setpictpenpos :: !Point2 !*Picture -> *Picture
setpictpenpos penpos=:{x,y} p=:{pTb,pOrigin=o,pPen}
	# tb = QMoveTo (x-o.x) (y-o.y) pTb
	# pp = {pPen & penPos={x=x,y=y}}
	= {p & pTb=tb, pPen=pp}

getpictpenpos :: !*Picture -> (!Point2,!*Picture)
getpictpenpos picture=:{pPen={penPos={x,y}}}
	= ({x=x,y=y},picture)

movepictpenpos :: !Vector2 !*Picture -> *Picture
movepictpenpos v=:{vx,vy} p=:{pTb,pPen=pen}
	= {p & pTb=QMove vx vy pTb,pPen={pen & penPos=movePoint v pen.penPos}}


//	Set & Get the PenSize:
setpictpensize :: !Int !*Picture -> *Picture
setpictpensize w p=:{pTb,pPen=pPen=:{penSize}}
	| w<0
		= pictureError "SetPenSize" "applied to negative width"
	# w` = if (w==0) 1 w
	= {p & pTb = QPenSize w` w` pTb, pPen={pPen & penSize=w`}}

getpictpensize :: !*Picture -> (!Int,!*Picture)
getpictpensize picture=:{pPen={penSize}}
	= (penSize,picture)


//	Set & Get the PenColour:
setpictpencolour :: !Colour !*Picture -> *Picture
setpictpencolour colour p
	| asRGB
	= setRGBColour rgbColour p
	with
		setRGBColour :: !RGBColour !*Picture -> *Picture
		setRGBColour rgb p=:{pTb,pPen=pen}
			# (hasColorQD,tb)	= HasColorQD pTb
			  pen				= {pen & penForeColour=colour}
			| hasColorQD
			= {p & pPen=pen,pTb=QRGBForeColor (toMacRGB rgb) tb}
			= {p & pPen=pen,pTb=QForeColor WhiteColor tb}
		where
			toMacRGB :: !RGBColour -> (!Int,!Int,!Int)
			toMacRGB {r,g,b}
				= (macRGB r,macRGB g,macRGB b)
			where
				macRGB :: !Int -> Int
				macRGB x
					| x>=MaxRGB	= 65535
					| x<=0		= 0
								= toInt (65535.0*((toReal x)/(toReal MaxRGB)))
	= setMacColour colour p
	with
		setMacColour :: !Colour !*Picture -> *Picture
		setMacColour colour p=:{pTb,pPen=pen}
			= {p & pPen={pen & penForeColour=colour},pTb=QForeColor color pTb}
		where
			color		= case colour of
							Black	-> BlackColor
							White	-> WhiteColor
							Red		-> RedColor
							Green	-> GreenColor
							Blue	-> BlueColor
							Cyan	-> CyanColor
							Magenta	-> MagentaColor
							Yellow	-> YellowColor
where
	(asRGB,rgbColour)	= case colour of
							RGB rgb		-> (True, rgb)
							DarkGrey	-> (True, {r=dark,  g=dark,  b=dark})
							Grey		-> (True, {r=medium,g=medium,b=medium})
							LightGrey	-> (True, {r=light, g=light, b=light})
							_			-> (False,WhiteRGB)
	dark	= MaxRGB/4
	medium	= MaxRGB/2
	light	= MaxRGB*3/4
	

getpictpencolour :: !*Picture -> (!Colour,!*Picture)
getpictpencolour picture=:{pPen={penForeColour}}
	= (penForeColour,picture)

//	Set & Get the PenColour:
setpictbackcolour :: !Colour !*Picture -> *Picture
setpictbackcolour colour p
	| asRGB
	= setRGBColour rgbColour p
	with
		setRGBColour :: !RGBColour !*Picture -> *Picture
		setRGBColour rgb p=:{pTb,pPen=pen}
			# (hasColorQD,tb)	= HasColorQD pTb
			  pen				= {pen & penBackColour=colour}
			| hasColorQD
			= {p & pPen=pen,pTb=QRGBBackColor (toMacRGB rgb) tb}
			= {p & pPen=pen,pTb=QBackColor WhiteColor tb}
		where
			toMacRGB :: !RGBColour -> (!Int,!Int,!Int)
			toMacRGB {r,g,b}
				= (macRGB r,macRGB g,macRGB b)
			where
				macRGB :: !Int -> Int
				macRGB x
					| x>=MaxRGB	= 65535
					| x<=0		= 0
								= toInt (65535.0*((toReal x)/(toReal MaxRGB)))
	= setMacColour colour p
	with
		setMacColour :: !Colour !*Picture -> *Picture
		setMacColour colour p=:{pTb,pPen=pen}
			= {p & pPen={pen & penBackColour=colour},pTb=QBackColor color pTb}
		where
			color		= case colour of
							Black	-> BlackColor
							White	-> WhiteColor
							Red		-> RedColor
							Green	-> GreenColor
							Blue	-> BlueColor
							Cyan	-> CyanColor
							Magenta	-> MagentaColor
							Yellow	-> YellowColor
where
	(asRGB,rgbColour)	= case colour of
							RGB rgb		-> (True, rgb)
							DarkGrey	-> (True, {r=dark,  g=dark,  b=dark})
							Grey		-> (True, {r=medium,g=medium,b=medium})
							LightGrey	-> (True, {r=light, g=light, b=light})
							_			-> (False,WhiteRGB)
	dark	= MaxRGB/4
	medium	= MaxRGB/2
	light	= MaxRGB*3/4

getpictbackcolour :: !*Picture -> (!Colour,!*Picture)
getpictbackcolour picture=:{pPen={penBackColour}}
	= (penBackColour,picture)


//	Set & Get the font attributes:
setpictpenfont :: !Font !*Picture -> *Picture
setpictpenfont font p=:{pTb,pPen=pen}
	= {p & pTb = GrafPtrSetFont (fontNr,fontstylestoid styles,size) pTb,pPen={pen & penFont=font}}
where
	{osfontnumber=fontNr,osfontstyles=styles,osfontsize=size}	= osFontgetimp font

getpictpenfont :: !*Picture -> (!Font,!*Picture)
getpictpenfont picture=:{pPen={penFont}}
	= (penFont,picture)

setpictpendefaultfont :: !*Picture -> *Picture
setpictpendefaultfont p=:{pTb,pPen=pen}
	= {p & pTb=GrafPtrSetFont (fontNr,fontstylestoid styles,size) tb1,pPen={pen & penFont=defaultFont}}
where
	(defaultFont,tb1)	= osDefaultfont pTb
	{osfontnumber=fontNr,osfontstyles=styles,osfontsize=size}	= osFontgetimp defaultFont

//--

getcurve_rect_begin_end :: !Point2 !Curve -> (!OSRect,!Point2,!Point2)
getcurve_rect_begin_end start=:{x,y} {curve_oval={oval_rx,oval_ry},curve_from,curve_to,curve_clockwise}
	| curve_clockwise	= (rect,end,start)
	| otherwise			= (rect,start,end)
where
	rx`					= toReal (abs oval_rx)
	ry`					= toReal (abs oval_ry)
	cx					= x -(toInt ((cos curve_from)*rx`))
	cy					= y +(toInt ((sin curve_from)*ry`))
	ex					= cx+(toInt ((cos curve_to  )*rx`))
	ey					= cy-(toInt ((sin curve_to  )*ry`))
	end					= {x=ex,y=ey}
	rect				= {rleft=cx-oval_rx,rtop=cy-oval_ry,rright=cx+oval_rx,rbottom=cy+oval_ry}

//--

toRGBtriple :: !Colour -> (!Int,!Int,!Int)
toRGBtriple (RGB {r,g,b})	= (setBetween r MinRGB MaxRGB,setBetween g MinRGB MaxRGB,setBetween b MinRGB MaxRGB)
toRGBtriple Black			= (MinRGB,MinRGB,MinRGB)
toRGBtriple DarkGrey		= ( MaxRGB>>2,    MaxRGB>>2,    MaxRGB>>2)
toRGBtriple Grey			= ( MaxRGB>>1,    MaxRGB>>1,    MaxRGB>>1)
toRGBtriple LightGrey		= ((MaxRGB>>2)*3,(MaxRGB>>2)*3,(MaxRGB>>2)*3)
toRGBtriple White			= (MaxRGB,MaxRGB,MaxRGB)
toRGBtriple Red				= (MaxRGB,MinRGB,MinRGB)
toRGBtriple Green			= (MinRGB,MaxRGB,MinRGB)
toRGBtriple Blue			= (MinRGB,MinRGB,MaxRGB)
toRGBtriple Cyan			= (MinRGB,MaxRGB,MaxRGB)
toRGBtriple Magenta			= (MaxRGB,MinRGB,MaxRGB)
toRGBtriple Yellow			= (MaxRGB,MaxRGB,MinRGB)

//-- clipping regions...

pictgetcliprgn :: !*Picture -> (!OSRgnHandle,!*Picture)
pictgetcliprgn pict
	# (origin,pen,toS,ctxt,tb)	= peekPicture pict
	# (cliprgn,tb)				= QNewRgn tb
	# (cliprgn,tb)				= QGetClip cliprgn tb
	# pict						= unpeekPicture origin pen toS ctxt tb
	= (cliprgn,pict)

pictsetcliprgn :: !OSRgnHandle !*Picture -> *Picture
pictsetcliprgn cliprgn pict
	# (origin,pen,toS,ctxt,tb)	= peekPicture pict
//	# tb = QOffsetRgn cliprgn (~origin.x) (~origin.y) tb
	# tb						= QSetClip cliprgn tb
	# pict						= unpeekPicture origin pen toS ctxt tb
	= pict

pictandcliprgn :: !OSRgnHandle !*Picture -> *Picture
pictandcliprgn newrgn pict
	# (origin,pen,toS,ctxt,tb)	= peekPicture pict
//	# tb = QOffsetRgn newrgn (~origin.x) (~origin.y) tb
	# (cliprgn,tb)				= QNewRgn tb
	# (cliprgn,tb)				= QGetClip cliprgn tb
//	# cliprgn = trace_rgn "pictandcliprgn o: " cliprgn
//	# newrgn = trace_rgn "pictandcliprgn a: " newrgn
	# (cliprgn`,tb)			= QSectRgn cliprgn newrgn cliprgn tb
//	# tb = trace_n ("pictandcliprgn",cliprgn,cliprgn`) tb
//	# cliprgn = trace_rgn "pictandcliprgn n: " cliprgn`
	# tb						= QSetClip cliprgn tb
	# tb						= QDisposeRgn cliprgn tb
	# pict						= unpeekPicture origin pen toS ctxt tb
	= pict

//---

setpictnormalmode :: !*Picture -> *Picture
setpictnormalmode pt
	= apppicttoolbox setnormalmode pt

setpictxormode :: !*Picture -> *Picture
setpictxormode pt
	= apppicttoolbox setxormode pt

setpicthilitemode :: !*Picture -> *Picture
setpicthilitemode pt
	= apppicttoolbox sethilitemode pt

setnormalmode tb
	= QPenMode PatCopy (QTextMode SrcOr tb)

setxormode tb
	= QPenMode PatXor (QTextMode SrcXor tb)

sethilitemode tb
	# (hasColorQD,tb)	= HasColorQD tb
	| hasColorQD
		= QPenMode PatHilite (QTextMode PatHilite tb)
	= QPenMode PatXor (QTextMode SrcOr tb)

//-- Point & Line

pictdrawpoint :: !Point2 !*Picture -> *Picture
pictdrawpoint point=:{x,y} pict=:{pOrigin={x=ox,y=oy},pTb=tb,pPen}
//	# tb	= QLineTo (x-ox) (y-oy) tb
	# tb	= QPaintRect (x-ox,y-oy,x-ox+1,y-oy+1) tb
	# pp	= {pPen & penPos = {pPen.penPos & x = x + 1}}
	= {pict & pTb = tb, pPen = pp}

pictdrawlineto :: !Point2 !*Picture -> *Picture
pictdrawlineto point=:{x,y} pict=:{pOrigin={x=ox,y=oy},pTb=tb,pPen=pp}
	# tb	= QLineTo (x-ox) (y-oy) tb
	# pp	= {pp & penPos = {x=x,y=y}}
	= {pict & pTb = tb, pPen = pp}

pictundrawlineto :: !Point2 !*Picture -> *Picture
pictundrawlineto pos pict
	= undrawit (pictdrawlineto pos) pict

pictdrawline :: !Point2 !Point2 !*Picture -> *Picture
pictdrawline a b=:{x,y} pict=:{pOrigin={x=ox,y=oy},pTb=tb,pPen=pp}
	# tb	= QMoveTo (a.x-ox) (a.y-oy) tb
	# tb	= QLineTo (x-ox) (y-oy) tb
	# pp	= {pp & penPos = {x=x,y=y}}
	= {pict & pTb = tb, pPen = pp}

pictundrawline :: !Point2 !Point2 !*Picture -> *Picture
pictundrawline a b pict
	= undrawit (pictdrawline a b) pict

// Char & String

pictdrawchar :: !Char !*Picture -> *Picture
pictdrawchar char pict=:{pOrigin={x=ox,y=oy},pTb=tb, pPen}
	# tb		= QDrawChar char tb
	# (x,y,tb)	= QGetPen tb	
	# pp		= {pPen & penPos = {x=x+ox,y=y+oy}}
	= {pict & pTb = tb, pPen = pp}

pictundrawchar :: !Char !*Picture -> *Picture
pictundrawchar char pict
	= undrawit (pictdrawchar char) pict

pictdrawstring :: !String !*Picture -> *Picture
pictdrawstring string pict=:{pOrigin={x=ox,y=oy},pTb=tb, pPen}
	# tb		= QDrawString string tb
	# (x,y,tb)	= QGetPen tb	
	# pp		= {pPen & penPos = {x=x+ox,y=y+oy}}
	= {pict & pTb = tb, pPen = pp}

pictundrawstring :: !String !*Picture -> *Picture
pictundrawstring string pict
	= undrawit (pictdrawstring string) pict

//-- Oval

pictdrawoval :: !Point2 !Oval !*Picture -> *Picture
pictdrawoval center oval pict=:{pOrigin=origin,pTb=tb}
	# tb = QFrameOval (ovalToRect (center-origin) oval) tb
	= {pict & pTb = tb}

pictundrawoval :: !Point2 !Oval !*Picture -> *Picture
pictundrawoval center oval pict
	= undrawit (pictdrawoval center oval) pict
	
pictfilloval :: !Point2 !Oval !*Picture -> *Picture
pictfilloval center oval pict=:{pOrigin=origin,pTb=tb}
	# tb = QPaintOval (ovalToRect (center-origin) oval) tb
	= {pict & pTb = tb}
	
pictunfilloval :: !Point2 !Oval !*Picture -> *Picture
pictunfilloval center oval pict=:{pOrigin=origin,pTb=tb}
	# tb = QEraseOval (ovalToRect (center-origin) oval) tb
	= {pict & pTb = tb}

ovalToRect :: !Point2 !Oval -> Rect
ovalToRect {x,y} {oval_rx,oval_ry}
//	= {rleft=x-oval_rx,rtop=y-oval_ry,rright=x+oval_rx,rbottom=y+oval_ry}
	= (x-oval_rx,y-oval_ry,x+oval_rx,y+oval_ry)

/*	General undrawing function: 
	draw with penColour to White; and restore penColour after drawing.
*/
undrawit :: !(IdFun *Picture) !*Picture -> *Picture
undrawit f picture=:{pPen={penBackColour=back}}
	# (colour,picture)	= getpictpencolour picture
	# picture			= setpictpencolour back picture
	# picture			= f picture
	= setpictpencolour colour picture

//-- Curve

pictdrawcurve :: !Bool !Point2 !Curve !*Picture -> *Picture
pictdrawcurve movePen start curve pict=:{pOrigin=origin,pTb=tb,pPen}
	# (pos,tb)	= arc movePen curve QFrameArc origin start tb
	#! pPen = case movePen of
		True	-> {pPen & penPos = {x=pos.x,y=pos.y}}
		False	-> pPen
	= {pict & pTb = tb, pPen = pPen}

pictundrawcurve :: !Bool !Point2 !Curve !*Picture -> *Picture
pictundrawcurve movePen start curve pict
	= pict	// XXX

pictfillcurve :: !Bool !Point2 !Curve !*Picture -> *Picture
pictfillcurve movePen start curve pict
	= pict	// XXX

pictunfillcurve :: !Bool !Point2 !Curve !*Picture -> *Picture
pictunfillcurve movePen start curve pict
	= pict	// XXX

arc :: !Bool !Curve !(Rect Int Int *OSToolbox -> *OSToolbox) !Origin !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
arc move curve drawf origin pos tb
#	tb	= drawf r startAngle arcAngle tb
| move
	#	tb	= QMoveTo endPos.x endPos.y tb
	=	(endPos+origin,tb)
=	(endPos+origin,tb)
where
	(r,startAngle,arcAngle,endPos)	= curvetoarc (pos-origin) curve

curvetoarc :: !Point2 !Curve -> (Rect,Int,Int,Point2)
curvetoarc {x,y} {curve_oval={oval_rx,oval_ry},curve_from,curve_to,curve_clockwise}
=	(rect,startAngle,arcAngle,{x=ex,y=ey})
where
	rect =
//		{ rleft	= cx-oval_rx
//		, rtop	= cy-oval_ry
//		, rright= cx+oval_rx
//		, rbottom=cy+oval_ry
//		}
		( cx-oval_rx
		, cy-oval_ry
		, cx+oval_rx
		, cy+oval_ry
		)
	rx`			= toReal oval_rx
	ry`			= toReal oval_ry
	cx			= x -(toInt ((cos curve_from)*rx`))
	cy			= y +(toInt ((sin curve_from)*ry`))
	ex			= cx+(toInt ((cos curve_to  )*rx`))
	ey			= cy-(toInt ((sin curve_to  )*ry`))
	a			= radtodeg curve_from
	b			= radtodeg curve_to
	d			= a-b
	startAngle	= 90-a
	arcAngle
	|	a<b		= if curve_clockwise (360+d) d
	|	a>b		= if curve_clockwise d (d-360)
				= 360
	
	radtodeg :: !Real -> Int
	radtodeg rads = (toInt ((rads/PI)*180.0)) rem 360

//-- OSRect

pictdrawrect :: !OSRect !*Picture -> *Picture
pictdrawrect rect=:{rleft=x1,rtop=y1,rright=x2,rbottom=y2} pict=:{pOrigin={x=ox,y=oy}, pTb=tb}
	# tb	= QFrameRect rect` tb
	= {pict & pTb = tb}
where
//	rect`	= {rleft = l,rtop = t,rright = r, rbottom = b}
	rect`	= ( l, t, r, b)
	(l,r)	= minmax (x1 - ox) (x2 - ox)
	(t,b)	= minmax (y1 - oy) (y2 - oy)
	
pictundrawrect :: !OSRect !*Picture -> *Picture
pictundrawrect rect pict=:{pTb = tb}
	= undrawit (pictdrawrect rect) pict
	
pictfillrect :: !OSRect !*Picture -> *Picture
pictfillrect rect=:{rleft=x1,rtop=y1,rright=x2,rbottom=y2} pict=:{pOrigin={x=ox,y=oy}, pTb=tb}
	# tb	= QPaintRect rect` tb
	= {pict & pTb = tb}
where
//	rect`	= {rleft = l,rtop = t,rright = r, rbottom = b}
	rect`	= ( l, t, r, b)
	(l,r)	= minmax (x1 - ox) (x2 - ox)
	(t,b)	= minmax (y1 - oy) (y2 - oy)

pictunfillrect :: !OSRect !*Picture -> *Picture
pictunfillrect rect=:{rleft=x1,rtop=y1,rright=x2,rbottom=y2} pict=:{pOrigin={x=ox,y=oy}, pTb=tb}
	# tb	= QEraseRect rect` tb
	= {pict & pTb = tb}
where
//	rect`	= {rleft = l,rtop = t,rright = r, rbottom = b}
	rect`	= ( l, t, r, b)
	(l,r)	= minmax (x1 - ox) (x2 - ox)
	(t,b)	= minmax (y1 - oy) (y2 - oy)
	
//-- Polygon

pictdrawpolygon :: !Point2 !Polygon !*Picture -> *Picture
pictdrawpolygon start polygon pict=:{pTb = tb, pOrigin = origin}
	# tb	= drawpolygon polygon (start-origin) tb
	= {pict & pTb = tb}

pictundrawpolygon :: !Point2 !Polygon !*Picture -> *Picture
pictundrawpolygon start polygon pict
	= undrawit (pictdrawpolygon start polygon) pict

pictfillpolygon :: !Point2 !Polygon !*Picture -> *Picture
pictfillpolygon start polygon pict=:{pTb = tb, pOrigin = origin}
	# base			= start - origin
	# (polyH,tb)	= QOpenPoly tb
	# tb			= drawpolygon polygon base tb
	# tb			= QClosePoly polyH tb
	# tb			= QPaintPoly polyH tb
	# tb			= QKillPoly  polyH tb
	= {pict & pTb = tb}

pictunfillpolygon :: !Point2 !Polygon !*Picture -> *Picture
pictunfillpolygon start polygon pict=:{pTb = tb, pOrigin = origin}
	# base			= start - origin
	# (polyH,tb)	= QOpenPoly tb
	# tb			= drawpolygon polygon base tb
	# tb			= QClosePoly polyH tb
	# tb			= QErasePoly polyH tb
	# tb			= QKillPoly  polyH tb
	= {pict & pTb = tb}

drawpolygon :: !Polygon !Point2 !*OSToolbox -> *OSToolbox
drawpolygon {polygon_shape} base=:{x,y} tb
#	tb			= QMoveTo   x y tb
	tb			= drawshape x y polygon_shape tb
	tb			= QLineTo   x y tb
=	tb
where
	drawshape :: !Int !Int ![Vector2] !*OSToolbox -> *OSToolbox
	drawshape x y [{vx,vy}:vs] tb
	=	drawshape vx vy vs (QLine vx vy tb)
	drawshape _ _ _ tb
	=	tb


//--

pictscroll :: !OSRect !Vector2 !*Picture -> (!OSRect,!*Picture)
pictscroll r` vc=:{vx,vy} pict=:{pTb,pOrigin}
	# (cliprgn,pTb)	= QNewRgn pTb
	# (cliprgn,pTb)	= QGetClip cliprgn pTb
	# (rgnH,pTb)	= QNewRgn pTb
	# pTb			= QClipRect (OSRect2Rect r) pTb
	# pTb			= QScrollRect (OSRect2Rect r) vx vy rgnH pTb
	//---
	# (oldRgn,pTb)	= osnewrectrgn r pTb
	# (newRgn,pTb)	= osnewrectrgn r2 pTb
//	# (updRgn,pTb)	= osnewrectrgn updRect pTb
//	# (rgnH,pTb)	= QDiffRgn rgnH updRgn rgnH pTb
//	# (rgnH,pTb)	= QDiffRgn updRgn rgnH rgnH pTb
//	# (_,oldbb,pTb)	= osgetrgnbox oldRgn pTb
//	# (_,newbb,pTb)	= osgetrgnbox newRgn pTb
	# (newRgn,pTb)	= QSectRgn oldRgn newRgn newRgn pTb
//	# (_,sctbb,pTb)	= osgetrgnbox newRgn pTb
	# (wPtr,pTb)	= QGetPort pTb
	# (updRgn, pTb)	= loadUpdateRegion wPtr pTb
//	# (sq,rgnbb,pTb)= osgetrgnbox rgnH pTb
	# (rgnH,pTb)	= QSectRgn newRgn updRgn rgnH pTb
//	# (rgnH,pTb)	= QSectRgn newRgn rgnH rgnH pTb
	# pTb			= osdisposergn oldRgn pTb
	# pTb			= osdisposergn newRgn pTb
//	# pTb			= trace_n` ("pictscroll",oldbb,newbb,sctbb,rgnbb,sq) pTb
//	# pTb			= osdisposergn updRgn pTb
	//---
	# (_,bb,pTb)	= osgetrgnbox rgnH pTb
	# pTb			= osdisposergn rgnH pTb
	# pTb			= QSetClip cliprgn pTb
	# pTb			= osdisposergn cliprgn pTb
//	# pTb			= trace_n` ("pictscroll",r,vx,vy,bb) pTb
	= (bb, {pict & pTb = pTb})
where
	r = subVector (toVector pOrigin) r`
	r2 = addVector vc r
	updRect	| vx < 0	= {rleft = r.rright + vx - 1, rtop = r.rtop - 1, rright = r.rright + 1, rbottom = r.rbottom + 1}
			| vx > 0	= {rleft = r.rleft - 1, rtop = r.rtop - 1, rright = r.rleft + vx + 1, rbottom = r.rbottom + 1}
			| vy < 0	= {rleft = r.rleft - 1, rtop = r.rbottom + vy - 1, rright = r.rright + 1, rbottom = r.rbottom + 1}
			| vy > 0	= {rleft = r.rleft - 1, rtop = r.rtop - 1, rright = r.rright + 1, rbottom = r.rtop + vy + 1}
			| otherwise	= {rleft = 0, rtop = 0, rright = 0, rbottom = 0}

//--

getResolutionC :: !OSPictContext !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
getResolutionC context tb
	# (res,tb) = os_getresolution tb
	= (res,tb)
	
getPictureScalingFactors :: !OSPictContext !*OSToolbox -> (!(!Int,!Int),!(!Int,!Int),!OSPictContext,!*OSToolbox)
getPictureScalingFactors ctxt tb
	= ((1,1),(1,1),ctxt,tb)

//--

getpictpenattributes :: !*Picture -> (![PenAttribute],!*Picture)
getpictpenattributes picture
	# (pen,picture)	= getpictpen picture
	= (getpenattribute pen,picture)
where
	getpenattribute :: !Pen -> [PenAttribute]
	getpenattribute {penSize,penForeColour,penBackColour,penPos,penFont}
		= [PenSize penSize,PenPos penPos,PenColour penForeColour,PenBack penBackColour,PenFont penFont]

getPenPenPos :: !*Pen -> (!Point2,!*Pen)
getPenPenPos pen=:{penPos={x,y}} = ({x=x,y=y},pen)

//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r
