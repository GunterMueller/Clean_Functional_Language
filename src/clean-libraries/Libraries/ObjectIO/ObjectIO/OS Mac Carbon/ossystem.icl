implementation module ossystem

import StdInt, StdTuple, StdReal
import ostoolbox,ostypes,osfont, osdocumentinterface
import pointer
from	quickdraw	import LMGetScrHRes, LMGetScrVRes, QScreenRect

//import StdDebug, dodebug
//import dodebug
trace_n` _ f :== f

::	OSWindowMetrics
	=	{	osmFont				:: !Font				// The internal Font used in Windows for controls
		,	osmFontMetrics		:: !(!Int,!Int,!Int)	// The ascent, descent, leading of osmFont
		,	osmHeight			:: !Int					// The height of the internal Font
		,	osmHorMargin		:: !Int					// The default horizontal margin
		,	osmVerMargin		:: !Int					// The default vertical   margin
		,	osmHorItemSpace		:: !Int					// The default horizontal item space
		,	osmVerItemSpace		:: !Int					// The default vertical   item space
		,	osmHSliderHeight	:: !Int					// The default height of a horizontal slider control
		,	osmVSliderWidth		:: !Int					// The default width  of a vertical   slider control
		}

OSdirseparator			:== ':'

osHomepath :: !String -> String
osHomepath fname
	= fname

import StdArray, files, osdirectory

// app or bundle path?
osApplicationpath :: !String -> String
osApplicationpath fname
	= FStartUpDir +++ ":" +++ fname
where
	FStartUpDir :: String
	FStartUpDir
		| result==0
			= pathName % (0,size pathName-2)
	where
		(result,wd_vref_num,directory_id,tb1)	= HGetVol NewToolbox;
		(pathName,_)	= Get_directory_path wd_vref_num directory_id "" tb1;
	

OSnewlineChars			:== "\xD"

OStickspersecond		:== 60

mmperinch		:== 25.4

WindowScreenBorder	:== 4									// Conventional distance between window and screen

osWindowFrameWidth     :: Int;	
osWindowFrameWidth
//	= 0//6
	=: osWindowFrameSizes.rleft

osWindowTitleBarHeight :: Int;	
osWindowTitleBarHeight
//	= 22//20;
	=: osWindowFrameSizes.rtop

osWindowFrameSizes :: OSRect
osWindowFrameSizes =: getWindowFrameSizes

import windows

getWindowFrameSizes
	# (wind,tb)		= NewCWindow 0 (0,0,20,20) "" False 0 (-1) False 0 OSNewToolbox
	| wind == 0
		= trace_n` ("NewCWindow failed") {rleft=0,rtop=22,rright=0,rbottom=0}
	# (err,tl,br,tb)	= GetWindowStructureWidths wind tb
	| err <> 0
		= trace_n` ("GetWindowStructureWidths failed") {rleft=0,rtop=22,rright=0,rbottom=0}
	# rect = {rleft = tl bitand 0xFFFF, rtop = tl >> 16,rright = br bitand 0xFFFF, rbottom = br >> 16}
	= rect
	//trace_n` ("GetWindowStructureWidths",rect,wind) rect

osMenuBarHeight			:: Int
osMenuBarHeight
//	= 22
	=: getMenuBarheight

getMenuBarheight
	# ((err,hgt),_)	= GetThemeMenuBarHeight OSNewToolbox
	| err <> 0 = trace_n` ("getWindowTitlebarheight",err,hgt) 22
	# hgt = (hgt >> 16) bitand 0xFFFF
	= hgt

osScrollBarWidth		:: Int
osScrollBarWidth
//	= 15//16
	=: getScrollBarWidth

getScrollBarWidth
	# ((err,wdth),_)	= GetThemeMetric kThemeMetricScrollBarWidth OSNewToolbox
	| err <> 0			= trace_n` ("getScrollBarWidth",err,wdth) 15
	= wdth

osScrollBarOverlap		:: Int
osScrollBarOverlap
//	= 0//1
	=: getScrollBarOverlap

getScrollBarOverlap
	# ((err,wdth),_)	= GetThemeMetric kThemeMetricScrollBarOverlap OSNewToolbox
	| err <> 0			= trace_n` ("getScrollBarOverlap",err,wdth) 15
	= wdth

osMMtoHPixels :: !Real -> Int
osMMtoHPixels mm
//	= toInt ((mm*toReal (fst (LoadWord ScrnHResAddress OSNewToolbox)))/mmperinch)
	= toInt ((mm*toReal LMGetScrHRes)/mmperinch)

osMMtoVPixels :: !Real -> Int
osMMtoVPixels mm
//	= toInt ((mm*toReal (fst (LoadWord ScrnVResAddress OSNewToolbox)))/mmperinch)
	= toInt ((mm*toReal LMGetScrVRes)/mmperinch)

osMaxScrollWindowSize :: (!Int,!Int)	// moet je eigenlijk dynamisch evalueren aangezien window op verschillende schermen kan staan...
osMaxScrollWindowSize
	=	(	sR-osScrollBarWidth-dScrwW+osScrollBarOverlap
		,	sB-osScrollBarWidth-dScrwW-osWindowTitleBarHeight-osMenuBarHeight+osScrollBarOverlap
		)
where	dScrwW			= WindowScreenBorder<<1
		(_,_, sR,sB,_)	= QScreenRect OSNewToolbox

osMaxFixedWindowSize :: (!Int,!Int)
osMaxFixedWindowSize
	=	(	w+osScrollBarWidth-osScrollBarOverlap
		,	h+osScrollBarWidth-osScrollBarOverlap
		)
where	(w,h)			= osMaxScrollWindowSize

osScreenrect :: !*OSToolbox -> (!OSRect,!*OSToolbox)
osScreenrect tb
	# (sl,st,sr,sb, tb)	= QScreenRect tb
	// subtract menubar from top???
//	#! tb = trace_n ("OSscreenrect "+++toString (sl,st,sr,sb)) tb
	= ({rleft=sl,rtop=st,rright=sr,rbottom=sb-osMenuBarHeight},tb)
where
	dScrwW			= WindowScreenBorder<<1

osPrintSetupTypical :: Bool
osPrintSetupTypical = True

osGetProcessWindowDimensions :: !OSDInfo !*OSToolbox -> (!OSRect,!*OSToolbox)
osGetProcessWindowDimensions osd tb
	# (sl,st,sr,sb, tb)	= QScreenRect tb
	= ({rleft=sl,rtop=st,rright=sr,rbottom=sb-osMenuBarHeight},tb)

osDefaultWindowMetrics	:: !*OSToolbox -> (!OSWindowMetrics,!*OSToolbox)
osDefaultWindowMetrics tb
	# (font,tb)							= osDialogfont tb
	# ((ascent,descent,leading,_),tb)	= osGetfontmetrics False 0 font tb
	# height							= ascent+descent+leading
	=	(
		{ osmFont				= font
		, osmFontMetrics		= (ascent,descent,leading)
		, osmHeight				= height
		, osmHorMargin			= 10
		, osmVerMargin			= 10
		, osmHorItemSpace		= 10
		, osmVerItemSpace		= 10
		, osmHSliderHeight		= osScrollBarWidth
		, osmVSliderWidth		= osScrollBarWidth
		}, tb)

osStripOuterSize		:: !Bool !Bool !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osStripOuterSize mdi resize tb
	= ((if resize (osScrollBarWidth-osScrollBarOverlap) 0,if resize (osScrollBarWidth-osScrollBarOverlap) 0),tb)

///////////

kThemeDocumentWindow          :== 0
//GetThemeWindowRegion	:: OS X only!!
/*
extern OSStatus 
GetThemeWindowRegion(
  ThemeWindowType             flavor,
  const Rect *                contRect,
  ThemeDrawState              state,
  const ThemeWindowMetrics *  metrics,
  ThemeWindowAttributes       attributes,
  WindowRegionCode            winRegion,
  RgnHandle                   rgn)
*/ 
GetThemeMenuBarHeight :: !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
GetThemeMenuBarHeight _ = code {
	ccall GetThemeMenuBarHeight "P:II:I"
	}

:: ThemeMetric	:== Int

kThemeMetricScrollBarWidth		:== 0		// 16,15
kThemeMetricScrollBarOverlap	:== 9		//  1, 0

GetThemeMetric :: !ThemeMetric !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
GetThemeMetric _ _ = code {
	ccall GetThemeMetric "PI:II:I"
	}

GetWindowStructureWidths :: !WindowPtr !*OSToolbox -> (!Int,!Int,!Int,!*OSToolbox)
GetWindowStructureWidths _ _ = code {
	ccall GetWindowStructureWidths "PI:III:I"
	}
//extern OSStatus 
//GetWindowStructureWidths(
//  WindowRef   inWindow,
//  Rect *      outRect)                                        AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER;
