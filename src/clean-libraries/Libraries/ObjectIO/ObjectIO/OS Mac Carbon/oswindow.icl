implementation module oswindow


//	Clean Object I/O library, version 1.2


import	StdBool, StdInt, StdReal, StdClass, StdOverloaded, StdList, StdMisc, StdTuple
import	osdocumentinterface, osevent, osfont, ospicture, osrgn, ossystem, ostypes
import	windows, pointer, OS_utilities, /*textedit,*/ controls, osutil
//import  memoryaccess	//,texteditaccess
import	commondef
import controlvalidate
import menus
//import controlclip
import StdMenu

from	quickdraw import QFrameRoundRect, QOpenRgn, QNewRgn, QEraseRect, QDisposeRgn
from	quickdraw import QGetClip, QSetClip, QClipRect, QUnionRgn, QMoveTo, QFrameRect
from	quickdraw import /*QDrawString, QPenSize,*/ QGetPort, QSetPort, QPenNormal, QDiffRgn
from	quickdraw import QRectRgn, QPtInRgn, QLocalToGlobal, QBackColor, WhiteColor
from	quickdraw import QPenMode, PatCopy, SrcOr, QLineTo, QScreenRect, QForeColor
from	quickdraw import BlackColor, QInitCursor, QHideCursor, QSetCursor, QShowCursor
from	quickdraw import /*HasColorQD,*/ QTextMode, QSectRgn, QCloseRgn, QPenPat, QKillPoly
from	quickdraw import QPaintPoly, :: PolyHandle, QClosePoly, QOpenPoly, QLine
from	quickdraw import GetPortVisibleRegion, GetWindowPort, SetPortWindowPort, QEmptyRgn

import osutil
import scheduler,iostate,StdPSt,windowaccess,controlcreate
import windowdevice
//import windowcursor
import StdArray
import osmenu


DocumentWindowType	:== 0;		// The window type of a resizeable dialog	= 0 (documentProc)
ZoomVariationType	:==	8;		// The variation code of a window with zooming
ModelessDialogType	:== 4;		// The window type of a fixed size dialog	= 4 (noGrowDocProc)
ModalDialogType    	:== 5;		// The window type of a modal dialog 		= 5 (movableDBoxProc)

//-- Debugging Tools
//import nodebug
//import dodebug
trace_n` _ f :== f
DebugStr` _ f :== f
//trace_n m f :== trace_n` m f
trace_n _ f :== f

traceClip :: !*OSToolbox -> *OSToolbox
traceClip tb
	# (rgn,tb) = QNewRgn tb
	# (rgn,tb) = QGetClip rgn tb
	# (isrect,rct,tb) = osgetrgnbox rgn tb
	# tb = trace_n ("ClipRect: ",rct) tb
	= tb

traceUpdate :: !OSWindowPtr !*OSToolbox -> *OSToolbox
traceUpdate wPtr tb
	# (rct,tb) = loadUpdateBBox wPtr tb
	= trace_n ("UpdateRect: ",rct) tb

//--

osInitialiseWindows :: !*OSToolbox -> *OSToolbox
osInitialiseWindows tb = tb

oswindowFatalError :: String String -> .x
oswindowFatalError function error
	= fatalError function "oswindow" error

//--

/*	System dependent constants:
*/

OSControlTitleSpecialChars
	:== ['&']											// Special prefix characters that should be removed

/*	System dependent metrics:
*/

osMinWindowSize :: (!Int,!Int)
osMinWindowSize = (64,64)


/*	PA: moved from oswindow to here, because of differences between Mac and Windows.
*/
//	Calculating the view frame of window/compound with visibility of scrollbars.

osGetCompoundContentRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetCompoundContentRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) itemRect=:{rright,rbottom}
	| trace_n ("osGetCompoundContentRect",(visHScroll,visVScroll),itemRect) False = undef
	| visHScroll && visVScroll	= {itemRect & rright=r`,rbottom=b`}
	| visHScroll				= {itemRect &           rbottom=b`}
	| visVScroll				= {itemRect & rright=r`           }
	| otherwise					= itemRect
where
	r`							= rright -osScrollBarWidth //+ osScrollBarOverlap	//osScrollBarWidth	//osmVSliderWidth //+1
	b`							= rbottom-osScrollBarWidth //+ osScrollBarOverlap	//osScrollBarWidth	//osmHSliderHeight//+1

osGetCompoundHScrollRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetCompoundHScrollRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) itemRect=:{rleft,rtop,rright,rbottom}
	| trace_n ("osGetCompoundHScrollRect",(visHScroll,visVScroll),itemRect) False = undef
	| not visHScroll	= zero
	| otherwise			= {rleft=rleft-osScrollBarOverlap, rtop=b`-1, rright=r`, rbottom = rbottom+osScrollBarOverlap}
where
	r`					= rright -osScrollBarWidth + osScrollBarOverlap	//osmVSliderWidth + 1
	b`					= rbottom-osScrollBarWidth + osScrollBarOverlap	//osmHSliderHeight + 1

osGetCompoundVScrollRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetCompoundVScrollRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) itemRect=:{rright,rbottom,rtop}
	| trace_n ("osGetCompoundVScrollRect",(visHScroll,visVScroll),itemRect) False = undef
	| not visVScroll	= zero
	| otherwise			= {itemRect & rtop = rtop-osScrollBarOverlap, rright = rright + osScrollBarOverlap, rleft=r`-1,rbottom= b` + osScrollBarOverlap}//if visHScroll b` rbottom}
where
	r`					= rright -osScrollBarWidth + osScrollBarOverlap	//osmVSliderWidth + 1
	b`					= rbottom-osScrollBarWidth + osScrollBarOverlap	//osmHSliderHeight + 1


osGetWindowContentRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetWindowContentRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) itemRect=:{rright,rbottom}
	| visHScroll && visVScroll	= {itemRect & rright=r`,rbottom=b`}
	| visHScroll				= {itemRect &           rbottom=b`}
	| visVScroll				= {itemRect & rright=r`           }
	| otherwise					= itemRect
where
	r`							= rright - osScrollBarWidth //+ osScrollBarOverlap	//osmVSliderWidth //+1
	b`							= rbottom- osScrollBarWidth //+ osScrollBarOverlap	//osmHSliderHeight//+1

osGetWindowHScrollRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetWindowHScrollRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) {rleft,rtop,rright,rbottom}
	| not visHScroll	= zero
	| otherwise			= {rleft=rleft-osScrollBarOverlap,rtop=b`,rright= r`, rbottom=rbottom+osScrollBarOverlap}
where
	r`					= rright -osScrollBarWidth + osScrollBarOverlap	//osmVSliderWidth  + 1
	b`					= rbottom-osScrollBarWidth + osScrollBarOverlap	//osmHSliderHeight + 1

osGetWindowVScrollRect :: !OSWindowMetrics !(!Bool,!Bool) !OSRect -> OSRect
osGetWindowVScrollRect {osmHSliderHeight,osmVSliderWidth} (visHScroll,visVScroll) {rleft,rtop,rright,rbottom}
	| not visVScroll	= zero
	| otherwise			= {rleft=r`,rtop=rtop-osScrollBarOverlap,rright=rright+osScrollBarOverlap,rbottom=b`+osScrollBarOverlap}
where
	r`					= rright -osScrollBarWidth + osScrollBarOverlap	//osmVSliderWidth  + 1
	b`					= rbottom-osScrollBarWidth + osScrollBarOverlap	//osmHSliderHeight + 1


//--

/*	OKorCANCEL type is used to tell Windows that a (Custom)ButtonControl is 
	the OK, CANCEL, or normal button.
*/

::	OKorCANCEL
	=	OK | CANCEL | NORMAL

instance toString OKorCANCEL where
	toString OK     = "OK"
	toString CANCEL = "CANCEL"
	toString NORMAL = "NORMAL"

::	ScrollbarInfo
	=	{	cbiHasScroll	:: !Bool				// The scrollbar exists
		,	cbiPos			:: (Int,Int)			// Its position within the parent
		,	cbiSize			:: (Int,Int)			// Its size within the parent
		,	cbiState		:: (Int,Int,Int,Int)	// Its (min,thumb,max,thumbsize) settings
		}

//@@	Window and Dialog functions.

createProperWindow :: !OSRect  !String !Int !OSWindowPtr !Bool !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
createProperWindow rect title type behind goAway tb
	# (windowPtr,tb)	= NewCWindow 0 (OSRect2Rect rect) title False type behind goAway 0 tb
	# (err,root,tb)		= CreateRootControl windowPtr tb
	# (err,tb)			= SetWindowModified windowPtr 0 tb
	= (windowPtr,tb)

SetWindowModified :: !OSWindowPtr !Int !*OSToolbox -> (!OSStatus,!*OSToolbox)
SetWindowModified wPtr mod ioState = code {
	ccall SetWindowModified "PII:I:I"
	}

osCreateDialog :: !Bool !Bool !String !(!Int,!Int) !(!Int,!Int) !OSWindowPtr
				  !(u:s->*(OSWindowPtr,u:s))
				  !(OSWindowPtr->u:s->u:(*OSToolbox->*(u:s,*OSToolbox)))
				  !(OSWindowPtr->OSWindowPtr->OSPictContext->u:s->u:(*OSToolbox->*(u:s,*OSToolbox)))
				  !OSDInfo !u:s !*OSToolbox
			   -> (![DelayActivationInfo],!OSWindowPtr,!u:s,!*OSToolbox)
osCreateDialog isModal isClosable title pos=:(x,y) size=:(w,h) behindPtr get_focus create_controls update_controls osdinfo control_info tb
	# tb = trace_n ("osCreateDialog",((x,y),(w,h)),rect) tb
	# (windPtr,tb)		= createProperWindow rect title type behindPtr isClosable tb
	# (cPos,tb) = osGetWindowPos windPtr tb
	# (cSiz,tb) = osGetWindowViewFrameSize windPtr tb
	# tb = trace_n ("osCreateDialog",cPos,cSiz) tb
	| windPtr == OSNoWindowPtr = oswindowFatalError "osCreateDialog" "dialog creation failed."
	# (control_info,tb)	= create_controls windPtr control_info tb
	# (focusPtr,control_info)	= get_focus control_info
	# tb				= ShowWindow windPtr tb
	# tb				= case behindPtr of
							OSNoWindowPtr	-> SelectWindow windPtr tb
							_				-> tb
	# tb = trace_n ("osCreateDialog :: "+++toString windPtr) tb
//	= ([DelayActivatedWindow windPtr],windPtr,control_info,tb)
	= ([],windPtr,control_info,tb)
where
	(type,rect) = case isClosable || not isModal of
			True	->	(ModelessDialogType
						,{ rleft	= x + osWindowFrameWidth 
						 , rtop		= y + osMenuBarHeight + osWindowTitleBarHeight
						 , rright	= x + w + osWindowFrameWidth
						 , rbottom	= y + osMenuBarHeight + osWindowTitleBarHeight + h
						 }
//						,{rleft = x + 6 , rtop = y + 42, rright = x + w + 6, rbottom = y + 42 + h}
						)
			False	->	(ModalDialogType
						,{rleft = x + 6 , rtop = y + 47, rright = x + w + 6, rbottom = y + 47 + h}
						)

import StdMisc

osCreateWindow :: !OSWindowMetrics !Bool !ScrollbarInfo !ScrollbarInfo !(!Int,!Int) !(!Int,!Int)
				  !Bool !String !(!Int,!Int) !(!Int,!Int)
				  !(u:s->*(OSWindowPtr,u:s))
				  !(OSWindowPtr->u:s->u:(*OSToolbox->*(u:s,*OSToolbox)))
				  !(OSWindowPtr->OSWindowPtr->OSPictContext->u:s->u:(*OSToolbox->*(u:s,*OSToolbox)))
				  !OSDInfo !OSWindowPtr !u:s !*OSToolbox
			   -> (![DelayActivationInfo],!OSWindowPtr,!OSWindowPtr,!OSWindowPtr,!OSDInfo,!u:s,!*OSToolbox)
osCreateWindow	wMetrics isResizable hInfo=:{cbiHasScroll=hasHScroll} vInfo=:{cbiHasScroll=hasVScroll} minSize maxSize
				isClosable title pos=:(x,y) size=:(w,h)
				get_focus
				create_controls
				update_controls
				osdInfo behindPtr control_info tb
	| docf == NDI
		= oswindowFatalError "osCreateWindow" "Cannot create window for NDI process"
	| docf == SDI && (fromJust doci).osClient <> OSNoWindowPtr
		= oswindowFatalError "osCreateWindow" "Cannot create multiple windows for SDI process"
	# tb				= trace_n ("osCreateWindow",pos,size) tb
	# (windPtr,tb)		= createProperWindow rect title type behindPtr isClosable tb
	# (cPos,tb)			= osGetWindowPos windPtr tb
	# (cSiz,tb)			= osGetWindowViewFrameSize windPtr tb
	# tb				= trace_n ("osCreateWindow",cPos,cSiz) tb
	| windPtr == OSNoWindowPtr
		= oswindowFatalError "osCreateWindow" "window creation failed."
	# (hPtr,tb)			= case hasHScroll of
							True	-> trace_n ("createHScroll") 
										osCreateSliderControl windPtr pos True True True (hInfo.cbiPos) (hInfo.cbiSize) (hInfo.cbiState) tb
							False	-> (0,tb)
	# (vPtr,tb)			= case hasVScroll of
							True	-> trace_n ("createVScroll",vInfo.cbiPos,vInfo.cbiSize,vInfo.cbiState)
										osCreateSliderControl windPtr pos True True False (vInfo.cbiPos) (vInfo.cbiSize) (vInfo.cbiState) tb
							False	-> (0,tb)
	# (control_info,tb)	= create_controls windPtr control_info tb
	# (focusPtr,control_info)	= get_focus control_info	// zal hier wel wat mee moeten doen...
	# tb				= ShowWindow windPtr tb
	# tb				= InvalWindowRect windPtr (OSRect2Rect rect) tb
	# tb = case isResizable of
			True	-> DrawGrowIcon windPtr tb
			_		-> tb
	# tb				= case behindPtr of
							OSNoWindowPtr	-> SelectWindow windPtr tb
							_				-> tb
	# (port,tb)			= GetWindowPort windPtr tb
	# tb				= trace_n ("osCreateWindow",windPtr,rect,port) tb
	| docf == SDI
		# doci			= {osFrame = windPtr, osClient = windPtr, osToolbar = Nothing}
		# osdInfo		= setOSDInfoOSInfo doci osdInfo
		= ([],windPtr,hPtr,vPtr,osdInfo,control_info,tb)
	= ([],windPtr,hPtr,vPtr,osdInfo,control_info,tb)
where
	type = case isResizable of
			True	-> DocumentWindowType+ZoomVariationType
			False	-> ModelessDialogType
	rect = //{rleft = x + 6 , rtop = y + 42, rright = x + w + 6, rbottom = y + 42 + h}
			{ rleft		= x + osWindowFrameWidth 
			, rtop		= y + osMenuBarHeight + osWindowTitleBarHeight
			, rright	= x + w + osWindowFrameWidth
			, rbottom	= y + osMenuBarHeight + osWindowTitleBarHeight + h
			}
	docf = getOSDInfoDocumentInterface osdInfo
	doci = getOSDInfoOSInfo osdInfo


/*	osCreateModalDialog wMetrics isCloseable title osdocinfo currentModal size 
						dialogControls dialogInit handleOSEvents
						(getOSToolbox,setOSToolbox)
	creates a modal dialog and handles the events until either the dialog is closed or its parent process terminated.
	Events are handled according to handleOSEvents.
	Controls are created according to dialogControls                       (only if (not osModalDialogHandlesControlCreation)!).
	Before the event loop is entered, the dialogInit function is evaluated (only if (not osModalDialogHandlesWindowInit)!).
*/
::	OSModalEventHandling s
	=	OSModalEventCallback (s -> *(OSEvents,s)) (*(OSEvents,s) -> s) (OSEvent -> s -> *([Int],s))
	|	OSModalEventLoop     (s -> s)

osModalDialogHandlesMenuSelectState	:== True//False
osModalDialogHandlesWindowInit		:== False
osModalDialogHandlesControlCreation	:== False
osModalDialogHandlesEvents			:== False

osCreateModalDialog ::	!OSWindowMetrics !Bool !String !OSDInfo !(Maybe OSWindowPtr) !(!Int,!Int) 
						!(OSWindowPtr u:s -> u:s)
						!(OSWindowPtr u:s -> u:s)
						!(OSModalEventHandling u:s)
						!(!u:s -> *(*OSToolbox,u:s), !*OSToolbox -> *(u:s -> u:s))
						!u:s
			  -> (!Bool,!u:s)
osCreateModalDialog wMetrics isClosable title osdinfo currentActiveModal size=:(w,h)
					dialogControls	// evaluated iff not osModalDialogHandlesControlCreation
					dialogInit		// evaluated iff not osModalDialogHandlesWindowInit
					(OSModalEventLoop eventLoop)
					(getOSToolbox, setOSToolbox)
					s
	# (tb,s)		= getOSToolbox s
	# (rect,tb)		= centerWindowRect 20 w h tb
	# rect			= fromTuple4 rect
	# (windPtr,tb)	= createProperWindow rect title type (-1) isClosable tb
	# s				= setOSToolbox tb s
	# s				= dialogControls windPtr s
	# (tb,s)		= getOSToolbox s
	# tb			= ShowWindow windPtr tb
	# tb			= SelectWindow windPtr tb
	# (err,tb) = BeginAppModalStateForWindow windPtr tb
	# s				= setOSToolbox tb s
	# s				= dialogInit windPtr s
	# s				= eventLoop s
	= (True,s)
where
	type = case isClosable of
			True	-> ModelessDialogType			// Nee: willen dan modal + close of modeless - minimise
			_		-> ModalDialogType
			
osCreateModalDialog _ _ _ _ _ _ _ _ (OSModalEventCallback _ _ _) _ _
	= oswindowFatalError "osCreateModalDialog" "OSModalEventLoop argument expected instead of OSModalEventCallback"

//	Center a dialog on the screen.

//centerWindowRect :: !Int !OSRect !*OSToolbox -> (!OSRect,!*OSToolbox)
centerWindowRect offs rwid rhgt tb
|	leftvis && topvis		= ((l, t,  r,	  b		), tb1)
|	leftvis					= ((l, st, r,	  st+b-t), tb1)
|	topvis					= ((sl,t,  sl+r-l,b		), tb1)
							= ((sl,st, sl+r-l,st+b-t), tb1)
where
	l						= (sl+sr-rwid) >> 1	//midh - rwid/2
	r						= l  + rwid
	t						= (st+sb-rhgt) >> 1 //st + (shgt-rhgt)/3
	b						= t  + rhgt
//	rwid					= rr - rl
//	rhgt					= rb - rt
	midh					= sl + (sr-sl)/2
	shgt					= sb - st
	st						= st`+ offs
	(sl,st`, sr,sb, tb1)	= QScreenRect tb
	topvis					= t >= st
	leftvis					= l >= sl


/*	Window destruction operations.
	PA: osDestroyWindow checks the process document interface and applies the appropriate destruction operation.
*/
osDestroyWindow :: !Bool !Bool !OSWindowPtr !(OSEvent -> .s -> ([Int],.s)) !OSDInfo !.s !*OSToolbox
												-> (![DelayActivationInfo],!OSDInfo, .s,!*OSToolbox)
osDestroyWindow isModal isWindow wPtr handleOSEvent osdInfo state tb
	# (err,tb) = case isModal of
			True	-> EndAppModalStateForWindow wPtr tb
			_		-> (0,tb)
	# tb = DisposeWindow wPtr tb
	# docf = getOSDInfoDocumentInterface osdInfo
	| isWindow && docf == SDI
		#!	doci		= getOSDInfoOSInfo osdInfo
			doci		= {fromJust doci & osFrame = OSNoWindowPtr, osClient = OSNoWindowPtr}
			osdInfo	= setOSDInfoOSInfo doci osdInfo
		= ([],osdInfo,state,tb)
	= ([],osdInfo,state,tb)


/*	Window graphics context access operations.
*/
osGrabWindowPictContext :: !OSWindowPtr !*OSToolbox -> (!OSPictContext,!*OSToolbox)
osGrabWindowPictContext wPtr tb
	# (port,tb)		= QGetPort tb
	// maybe also need to do something with clipping region & pen???
	# tb			= SetPortWindowPort wPtr tb
	# ((w,h),tb)	= osGetWindowSize wPtr tb
	# tb			= QClipRect (0,0,w,h) tb
//	# tb			= BeginUpdate wPtr tb
//	# tb			= trace_n ("osGrabWindowPictContext: "+++toString wPtr) tb
	= (port,tb)
	
osReleaseWindowPictContext :: !OSWindowPtr !OSPictContext !*OSToolbox -> *OSToolbox
osReleaseWindowPictContext wPtr hdc tb
//	# tb		= EndUpdate wPtr tb
//	# tb		= trace_n ("osReleaseWindowPictContext: "+++toString wPtr) tb
	# tb	= QPenNormal		tb
	# tb	= QForeColor		BlackColor tb
	= QSetPort hdc tb


/*	osBeginUpdate theWindow
		makes additional preparations to do updates. Dummy on Windows.
	osEndUpdate theWindow
		administrates and ends the update. Dummy on Windows.
	osSetUpdate theWindow
		additional work for update in context. Dummy on Windows.
*/
osBeginUpdate :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osBeginUpdate wPtr tb = BeginUpdate wPtr tb

osEndUpdate :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osEndUpdate wPtr tb = EndUpdate wPtr tb

osSetUpdate	  :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osSetUpdate wPtr tb
	= QDFlushPortBuffer wPtr 0 tb

QDFlushPortBuffer :: !Int !Int !*OSToolbox -> *OSToolbox
QDFlushPortBuffer _ _ _ = code {
	ccall QDFlushPortBuffer "II:V:I"
	}

/*	Window access operations.
*/

/*	Standard Scroll Bar settings:
*/

OSSliderMin		:== -32767		// 0 - MaxSigned2ByteInt
OSSliderMax		:==  32767		// MaxSigned2ByteInt
OSSliderRange	:==  65534		// OSSliderMax-OSSliderMin

WorkingOnFix fix old :== old

toOSscrollbarRange :: !(!Int,!Int,!Int) !Int -> (!Int,!Int,!Int,!Int)
toOSscrollbarRange (min,pos,max) siz
	| min==max
		= (OSSliderMin,OSSliderMin,OSSliderMax,1)
	| range <= OSSliderRange
		# min` = WorkingOnFix (OSSliderMin)						(min)
		# max` = WorkingOnFix (OSSliderMin + range)				(max - siz)
		# pos` = WorkingOnFix (OSSliderMin + pos - min)			(pos)
		# siz` = WorkingOnFix (siz/*OSSliderMin + siz - min*/)	(siz)
		= trace_n ((min,pos,max,siz),(min`,pos`,max`,siz`)) (min`,pos`,max`,siz`)
	# min` = OSSliderMin
	# max` = OSSliderMax
	# conv = toReal range / toReal OSSliderRange
	# siz` = toInt ((toReal (siz-min))/conv)+min`
	# pos` = toInt ((toReal (pos-min))/conv)+min`
	= trace_n ((min,pos,max,siz),(min`,pos`,max`,siz`)) (min`,pos`,max`,siz`)
where
	range = max - min

fromOSscrollbarRange :: !(!Int,!Int) !Int -> Int
fromOSscrollbarRange (min,max) pos
	| min == max
		= min
	| range <= OSSliderRange
		= pos	// - OSSliderMin + min
	# conv = toReal range / toReal OSSliderRange
	= toInt ((toReal (pos-OSSliderMin))*conv)+min
where
	range = max - min

osScrollbarIsVisible :: !(!Int,!Int) !Int -> Bool
osScrollbarIsVisible (domainMin,domainMax) viewSize
	= //trace_n ("osScrollbarIsVisible",domainMin,domainMax,viewSize)
		viewSize<domainMax-domainMin

osScrollbarsAreVisible :: !OSWindowMetrics !OSRect !(!Int,!Int) !(!Bool,!Bool) -> (!Bool,!Bool)
osScrollbarsAreVisible {osmHSliderHeight,osmVSliderWidth} {rleft=xMin,rtop=yMin,rright=xMax,rbottom=yMax} (width,height) (hasHScroll,hasVScroll)
	= //trace_n ("osScrollbarsAreVisible")
		visScrollbars (False,False)
					(hasHScroll && (osScrollbarIsVisible hRange width),hasVScroll && (osScrollbarIsVisible vRange height))
where
	hRange	= (xMin,xMax)
	vRange	= (yMin,yMax)
	
	visScrollbars :: !(!Bool,!Bool) !(!Bool,!Bool) -> (!Bool,!Bool)
	visScrollbars (showH1,showV1) (showH2,showV2)
		| showH1==showH2 && showV1==showV2
			= (showH1,showV1)
		| otherwise
			= visScrollbars (showH2,showV2) (showH,showV)
	where
		showH	= if showV2 (hasHScroll && osScrollbarIsVisible hRange (width -osmVSliderWidth )) showH2
		showV	= if showH2 (hasVScroll && osScrollbarIsVisible vRange (height-osmHSliderHeight)) showV2

inRange :: !Int !Int !Int !Int -> Int
inRange destMin destRange sourceValue sourceRange
	= destMin + (toInt (((toReal sourceValue) / (toReal sourceRange)) * (toReal destRange)))

//--
//updateWindowScroll => osSetWindowSliderPosSize
osSetWindowSliderPosSize :: !OSWindowPtr !OSWindowPtr !OSRect !*OSToolbox -> *OSToolbox
osSetWindowSliderPosSize _ OSNoWindowPtr _ tb 
	= tb
osSetWindowSliderPosSize wPtr scrollItemPtr rect tb
	# tb = trace_n ("osSetWindowSliderPosSize",scrollItemPtr,rect) tb
//	#! tb = assertPort` wPtr tb
	= appGrafport wPtr update tb
where
	x	= rect.rleft
	y	= rect.rtop
	w	= rect.rright - rect.rleft
	h	= rect.rbottom - rect.rtop
	update tb
		# tb		= MoveControl scrollItemPtr x y tb
		# tb		= SizeControl scrollItemPtr w h tb
		= tb

osSetWindowSliderThumb :: !OSWindowMetrics !OSWindowPtr !Bool !Int !(Maybe OSWindowPtr) !(Maybe OSWindowPtr) !OSRect !OSRect !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetWindowSliderThumb wMetrics theWindow isHorizontal thumb maybeHScroll maybeVScroll hScrollRect vScrollRect (maxx,maxy) redraw tb
	// look at movewindowframe in windowsize.icl v 1.1
	# tb = trace_n ("osSetWindowSliderThumb",theWindow,maybeHScroll,maybeVScroll,thumb) tb
	| isHorizontal && hasHScroll
		# tb		= SetCtlValue` hScroll thumb tb
		| not redraw = tb
//		= appGrafport theWindow (osUpdateCommonControl hScrollRect hScroll) tb
		= appClipport theWindow hScrollRect (Draw1Control hScroll) tb
	| not isHorizontal && hasVScroll
		# tb		= SetCtlValue` vScroll thumb tb
		| not redraw = tb
//		= appGrafport theWindow (osUpdateCommonControl vScrollRect vScroll) tb
		= appClipport theWindow vScrollRect (Draw1Control vScroll) tb
	= tb
where
	hasHScroll	= isJust maybeHScroll
	hScroll		= fromJust maybeHScroll
	hasVScroll	= isJust maybeVScroll
	vScroll		= fromJust maybeVScroll

osSetWindowSliderThumbSize :: !OSWindowMetrics !OSWindowPtr !OSWindowPtr !Bool !Int !Int !Int !(!Int,!Int) !OSRect !Bool !Bool !*OSToolbox -> *OSToolbox
osSetWindowSliderThumbSize _ theWindow ptr _ min max size _ rect able redraw tb
	# tb = trace_n ("osSetWindowSliderThumbSize",(theWindow,ptr,min,max),hilite) tb
//	# tb = appGrafport theWindow setthumb tb
	# tb = appClipport theWindow rect setthumb tb
	= tb
where
	hilite	= if (min < max && able) 0 255
	setthumb tb
		# tb = SetCtlMin` ptr min tb
		# tb = SetCtlMax` ptr max tb
		# tb = SetControlViewSize ptr size tb
		# tb = HiliteControl ptr hilite tb
		| not redraw = tb
//		= osUpdateCommonControl rect ptr tb
		= Draw1Control ptr tb

//--

osInvalidateWindow :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osInvalidateWindow theWindow tb
	# (visRgn,tb)			= WindowGetVisRgn theWindow tb
	# (isRect,rect,tb) = osgetrgnbox visRgn tb
//	# tb					= InvalRgn visRgn tb
//	# tb					= appGrafport theWindow (InvalRgn visRgn) tb
	# tb					= InvalWindowRgn theWindow visRgn tb
	# tb = trace_n ("osInvalidateWindow",theWindow,isRect,rect) tb
	// dispose region visRgn???
	= tb

osInvalidateWindowRect :: !OSWindowPtr !OSRect !*OSToolbox -> *OSToolbox
osInvalidateWindowRect theWindow rect tb
	#! tb = trace_n ("osInvalidateWindowRect "+++toString theWindow) tb
//	= appGrafport theWindow (InvalRect (OSRect2Rect rect)) tb	
	= InvalWindowRect theWindow (OSRect2Rect rect) tb	

osValidateWindowRect :: !OSWindowPtr !OSRect !*OSToolbox -> *OSToolbox
osValidateWindowRect theWindow rect tb
	#! tb = trace_n ("osValidateWindowRect "+++toString theWindow) tb
	= ValidWindowRect theWindow (OSRect2Rect rect) tb

osValidateWindowRgn :: !OSWindowPtr !OSRgnHandle !*OSToolbox -> *OSToolbox
osValidateWindowRgn theWindow rgn tb
	#! tb = trace_n ("osValidateWindowRgn "+++toString theWindow) tb
//	= appGrafport theWindow (ValidRgn rgn) tb
	= ValidWindowRgn theWindow rgn tb

//from quickdraw import GetRegionBounds, QGlobalToLocal
osWindowHasUpdateRect :: !OSWindowPtr !*OSToolbox -> (!Bool,!*OSToolbox)
osWindowHasUpdateRect wPtr tb
	# (rgn,tb)	= QNewRgn tb
	# tb		= GetWindowRegion wPtr kWindowUpdateRgn rgn tb
	# (empty,tb)= QEmptyRgn rgn tb
/*
	# ((l,t,r,b),tb)		= GetRegionBounds rgn tb
	# (savePort,tb) = QGetPort tb
	# tb = SetPortWindowPort wPtr tb
	# (l,t,tb) = QGlobalToLocal l t tb
	# (r,b,tb) = QGlobalToLocal r b tb
	# tb = QSetPort savePort tb
*/
	# tb		= QDisposeRgn rgn tb
/*		
	# (err,bb,tb)	= GetWindowBounds wPtr kWindowUpdateRgn tb
	| err <> 0 = abort ("loadUpdateBBox failed: " +++ toString err+++ "\n")
	# (l,t, r,b)	= toTuple4 bb
//	# tb = abort`` tb ("loadUpdateBBox",wPtr,(l,t),(r,b))
	# (ltLocal,tb)	= accGrafport wPtr (GlobalToLocal {x=l,y=t}) tb
//	# tb = abort`` tb ("loadUpdateBBox",wPtr,((l,t),(r,b)),ltLocal)
	# (rbLocal,tb)	= accGrafport wPtr (GlobalToLocal {x=r,y=b}) tb

	# tb = trace_n ("osWindowHasUpdateRect",not empty,(l,t),(r,b),bb) tb
*/
	= (not empty,tb)

//--

osDisableWindow :: !OSWindowPtr !(!Bool,!Bool) !Bool !*OSToolbox -> *OSToolbox
osDisableWindow theWindow scrollInfo modalContext tb
	# tb = trace_n ("osDisableWindow "+++toString theWindow) tb
	// need to do textedit handling for focus item here?!
	// need to do scrollbar handling here...
	= tb

osEnableWindow :: !OSWindowPtr !(!Bool,!Bool) !Bool !*OSToolbox -> *OSToolbox
osEnableWindow theWindow scrollInfo modalContext tb
	# tb = trace_n ("osEnableWindow "+++toString theWindow) tb
	// need to do textedit handling for focus item here?!
	// need to do scrollbar handling here...
	= tb

osActivateWindow :: !OSDInfo !OSWindowPtr !(OSEvent->(.s,*OSToolbox)->(.s,*OSToolbox)) !.s !*OSToolbox
	-> (![DelayActivationInfo],!.s,!*OSToolbox)
osActivateWindow osdInfo wPtr handleOSEvent state tb
	# tb = ShowWindow wPtr tb
	# tb = SelectWindow wPtr tb
	# tb = trace_n ("osActivateWindow ",wPtr) tb
	= ([],state,tb)

osActivateControl :: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (![DelayActivationInfo],!*OSToolbox)
osActivateControl parentWindow controlPtr tb
	# tb = trace_n ("osActivateControl",parentWindow,controlPtr) tb
	// alleen wat doen als EditText...
	// een of andere manier moet vorige gedeactiveerd
	= ([],tb)

osStackWindow :: !OSWindowPtr !OSWindowPtr !(OSEvent->(.s,*OSToolbox)->(.s,*OSToolbox)) !.s !*OSToolbox
	-> (![DelayActivationInfo],!.s,!*OSToolbox)
osStackWindow thisWindow behindWindow handleOSEvent state tb
	# tb = trace_n ("osStackWindow") tb
	# tb = SendBehind thisWindow behindWindow tb
	= ([],state,tb)

osHideWindow :: !OSWindowPtr !Bool !*OSToolbox -> (![DelayActivationInfo],!*OSToolbox)
osHideWindow wPtr activate tb
	# tb = trace_n ("osHideWindow "+++toString wPtr) tb
	# tb = HideWindow wPtr tb
	= ([],tb)

osShowWindow :: !OSWindowPtr !Bool !*OSToolbox -> (![DelayActivationInfo],!*OSToolbox)
osShowWindow wPtr activate tb
	# tb = trace_n ("osShowWindow "+++toString wPtr) tb
	# tb = ShowWindow wPtr tb
	| activate
		# tb = SelectWindow wPtr tb
		= ([],tb)
	= ([],tb)

osSetWindowCursor :: !OSWindowPtr !CursorShape !*OSToolbox -> *OSToolbox
osSetWindowCursor wPtr cursorShape tb
	# tb = trace_n ("osSetWindowCursor "+++toString wPtr+++" "+++toString cursorShape) tb
	= tb
//	= setwindowcursorshape wPtr cursorShape tb
//	= setCursorShape cursorShape tb


//	Set the cursor shape.

IBeamC	:== 1
CrossC	:== 2
PlusC	:== 3
WatchC	:== 4

osSetCursorShape :: !CursorShape !*OSToolbox -> *OSToolbox
osSetCursorShape StandardCursor	tb = QInitCursor			tb
osSetCursorShape BusyCursor		tb = setCursorShape` WatchC	tb
osSetCursorShape IBeamCursor	tb = setCursorShape` IBeamC	tb
osSetCursorShape CrossCursor	tb = setCursorShape` CrossC	tb
osSetCursorShape FatCrossCursor	tb = setCursorShape` PlusC	tb
osSetCursorShape HiddenCursor	tb = QHideCursor			tb
osSetCursorShape _				tb = QInitCursor			tb

setCursorShape`	:: !Int !*OSToolbox -> *OSToolbox
setCursorShape` cursorId tb
	# (cursorH,tb)	= GetCursor cursorId	tb
	# (cursor, tb)	= LoadLong  cursorH		tb
	# tb			= QShowCursor			tb
	# tb			= QSetCursor cursor		tb
	= tb

//--

osGetWindowPos :: !OSWindowPtr !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetWindowPos wPtr tb
	// of variant uit windowinternal 'getwindowitempos' met offsets naar contents origin...
	| wPtr == OSNoWindowPtr = ((0,0),tb)	// voor sdi frame...
	= accGrafport wPtr get tb
where
	get tb
		# (err,bb,tb)	= GetWindowBounds wPtr kWindowStructureRgn tb
		| err <> 0 = abort "oswindow:osGetWindowPos:GetWindowBounds failed\n"
		# (l,t, r,b)	= toTuple4 bb
		= trace_n ("osGetWindowPos",wPtr,bb) ((l,t-osMenuBarHeight),tb)

/*
typedef UInt16                          WindowRegionCode;
enum {
                                                                /* Region values to pass into GetWindowRegion & GetWindowBounds */
    kWindowTitleBarRgn          = 0,
    kWindowTitleTextRgn         = 1,
    kWindowCloseBoxRgn          = 2,
    kWindowZoomBoxRgn           = 3,
    kWindowDragRgn              = 5,
    kWindowGrowRgn              = 6,
    kWindowCollapseBoxRgn       = 7,
    kWindowTitleProxyIconRgn    = 8,                            /* Mac OS 8.5 forward*/
    kWindowStructureRgn         = 32,
    kWindowContentRgn           = 33,                           /* Content area of the window; empty when the window is collapsed*/
    kWindowUpdateRgn            = 34,                           /* Carbon forward*/
    kWindowGlobalPortRgn        = 40                            /* Carbon forward - bounds of the windowÕs port in global coordinates; not affected by CollapseWindow*/
*/

kWindowStructureRgn		:== 32
kWindowContentRgn		:== 33
kWindowUpdateRgn		:== 34


osSetWindowPos :: !OSWindowPtr !(!Int,!Int) !Bool !Bool !*OSToolbox -> *OSToolbox
osSetWindowPos wPtr pos=:(x,y) update inclScrollbars tb
	| wPtr == OSNoWindowPtr = tb
	# tb = appGrafport wPtr set tb
	# (pos`,tb) = osGetWindowPos wPtr tb
	= trace_n ("osSetWindowPos",wPtr,pos,pos`) tb
where
	set tb
		= MoveWindowStructure wPtr x (y+osMenuBarHeight) tb

osGetWindowViewFrameSize :: !OSWindowPtr !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetWindowViewFrameSize wPtr tb
	| wPtr == OSNoWindowPtr
		= ((0,0),tb)	// keep SDI interface happy (specifically 'getSDIWindowSize')
	# (err,bb,tb)		= GetWindowBounds wPtr kWindowContentRgn tb
	| err <> 0 = abort "oswindow:osGetWindowViewFrameSize failed\n"
	# (l,t,r,b) = toTuple4 bb
	  w = r-l
	  h = b-t
	= trace_n ("osGetWindowViewFrameSize",wPtr,bb) ((w,h),tb)

osSetWindowViewFrameSize :: !OSWindowPtr !(!Int,!Int) !*OSToolbox -> *OSToolbox
osSetWindowViewFrameSize wPtr (w,h) tb
	# tb = trace_n ("osSetWindowViewFrameSize",wPtr,w,h) tb
	= SizeWindow wPtr w h False tb

osGetWindowSize :: !OSWindowPtr !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetWindowSize wPtr tb
//	# tb = trace_n ("osGetWindowSize","enter") tb
	# (err,bb,tb)		= GetWindowBounds wPtr kWindowStructureRgn tb
	| err <> 0 = abort "oswindow:osGetWindowSize failed\n"
	# (l,t,r,b) = toTuple4 bb
	  w = r-l
	  h = b-t
//	# tb = trace_n ("osGetWindowSize","exit",wPtr) tb
	= trace_n ("osGetWindowSize",wPtr,bb) ((w,h),tb)

osSetWindowSize	:: !OSWindowPtr !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetWindowSize wPtr (w,h) update tb
	# ((fw,fh),tb)	= osGetWindowViewFrameSize wPtr tb
	# ((ww,wh),tb)	= osGetWindowSize wPtr tb
	# w				= ww + w - fw
	# h				= wh + h - fh
	= SizeWindow wPtr w h False tb

osSetWindowTitle :: !OSWindowPtr !String !*OSToolbox -> *OSToolbox
osSetWindowTitle wPtr title tb
	= SetWTitle wPtr title tb


//-- CompoundControl

osMinCompoundSize :: (!Int,!Int)
osMinCompoundSize = (0,0)	// PA: (0,0)<--WinMinimumWinSize (Check if this safe)

osCreateCompoundControl ::  !OSWindowMetrics !OSWindowPtr !(!Int,!Int) !Bool !Bool !Bool !(!Int,!Int) !(!Int,!Int)
							!ScrollbarInfo
							!ScrollbarInfo
							!*OSToolbox
						 -> (!OSWindowPtr,!OSWindowPtr,!OSWindowPtr,!*OSToolbox)
osCreateCompoundControl wMetrics parentWindow parentPos show able isTransparent (x,y) (w,h)
						hInfo=:{cbiHasScroll=hasHScroll}
						vInfo=:{cbiHasScroll=hasVScroll} tb
	# (hPtr,tb)			= case hasHScroll of
							True	# (cbi_pos_x,cbi_pos_y) = hInfo.cbiPos
									-> osCreateSliderControl parentWindow parentPos show able True (x + cbi_pos_x,y + cbi_pos_y) hInfo.cbiSize hInfo.cbiState tb
							False	-> (OSNoWindowPtr,tb)
	# (vPtr,tb)			= case hasVScroll of
							True	# (cbi_pos_x,cbi_pos_y) = vInfo.cbiPos
									-> osCreateSliderControl parentWindow parentPos show able False (x + cbi_pos_x,y + cbi_pos_y) vInfo.cbiSize vInfo.cbiState tb
							False	-> (OSNoWindowPtr,tb)
	# tb = trace_n` ("oswindow::osCreateCompoundControl",parentWindow,hPtr,vPtr) tb
	= (parentWindow,hPtr,vPtr,tb)

osDestroyCompoundControl :: !OSWindowPtr !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyCompoundControl wPtr hPtr vPtr tb
	# tb = case hPtr of
			OSNoWindowPtr	-> tb
			_				-> DisposeControl hPtr tb
	# tb = case vPtr of
			OSNoWindowPtr	-> tb
			_				-> DisposeControl vPtr tb
	# tb = trace_n` ("osDestroyCompoundControl") tb
	= tb

osUpdateCompoundControl :: !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateCompoundControl area _ parentWindow theControl tb
	// are scrollbars being updated???
	#! tb = trace_n` ("osUpdateCompoundControl ???") tb
	// do nothing on Macintosh
	= tb

osClipCompoundControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipCompoundControl _ parentPos area itemPos itemSize tb
	# tb = trace_n` ("osClipCompoundControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osInvalidateCompound :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osInvalidateCompound compoundPtr tb
	# tb = trace_n` ("osInvalidateCompound") tb
	= tb

osSetCompoundSliderThumb :: !OSWindowMetrics !OSWindowPtr !OSWindowPtr !OSWindowPtr !OSRect !Bool !Int !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCompoundSliderThumb wMetrics theWindow theCompound theScrollbar theScrollrect isHorizontal thumb (maxx,maxy) redraw tb
	// look at movewindowframe in windowsize.icl v 1.1
	# tb = trace_n` ("osSetCompoundSliderThumb ",theScrollbar,theScrollrect,redraw,thumb) tb
	# tb		= SetCtlValue theScrollbar thumb tb
	| not redraw = tb
//	= appGrafport theWindow (osUpdateCommonControl theScrollrect theScrollbar) tb
	= appClipport theWindow theScrollrect (Draw1Control theScrollbar) tb

osSetCompoundSliderThumbSize :: !OSWindowMetrics !OSWindowPtr !OSWindowPtr !OSWindowPtr !Int !Int !Int !OSRect !Bool !Bool !Bool !*OSToolbox -> *OSToolbox
osSetCompoundSliderThumbSize _ theWindow _ ptr min max size rect _ able redraw tb
	# tb = trace_n` ("osSetCompoundSliderThumbSize ",(theWindow,ptr,min,max),redraw) tb
//	= appGrafport theWindow setthumb tb
	= appClipport theWindow rect setthumb tb
where
	hilite	= if (min < max && able) 0 255
	setthumb tb
		# tb = SetCtlMin ptr min tb
		# tb = SetCtlMax ptr max tb
		# tb = SetControlViewSize ptr size tb
		# tb = HiliteControl ptr hilite tb
		| not redraw = tb
//		= osUpdateCommonControl rect ptr tb
		= Draw1Control ptr tb

osSetCompoundSelect :: !OSWindowPtr !OSWindowPtr !OSRect !(!Bool,!Bool) !(!OSWindowPtr,!OSWindowPtr) !Bool !*OSToolbox -> *OSToolbox
osSetCompoundSelect _ compoundPtr _ (hVis,vVis) (hPtr,vPtr) select tb
	# tb = trace_n` ("osSetCompoundSelect") tb
	# tb = case hVis of
			True -> HiliteControl hPtr (if select 0 255) tb
			_	-> tb
	# tb = case vVis of
			True -> HiliteControl vPtr (if select 0 255) tb
			_	-> tb
	= tb

osSetCompoundShow :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCompoundShow wPtr compoundPtr itemRect` clipRect show tb
	# tb = trace_n` ("osSetCompoundShow",show) tb
	| show
		# tb = appClipport wPtr clipRect (InvalWindowRect wPtr itemRect o QEraseRect itemRect) tb
		= tb
	# tb = appClipport wPtr clipRect (InvalWindowRect wPtr itemRect o QEraseRect itemRect) tb
	= tb
where
	itemRect = OSRect2Rect itemRect`

osSetCompoundPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCompoundPos _ (parent_x,parent_y) compoundPtr (x,y) _ update tb
	# tb = trace_n` ("osSetCompoundPos") tb
	= tb

osSetCompoundSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCompoundSize _ _ compoundPtr _ size update tb
	# tb = trace_n` ("osSetCompoundSize") tb
	= tb

osUpdateCompoundScroll :: !OSWindowPtr !OSWindowPtr !OSRect !*OSToolbox -> *OSToolbox
osUpdateCompoundScroll wPtr scrollItemPtr scrollRect=:{rleft=x,rtop=y,rbottom=b,rright=r} tb
	# tb = trace_n` ("osUpdateCompoundScroll",scrollItemPtr,scrollRect) tb
	= appGrafport wPtr f tb
where
	f tb
		# tb		= MoveControl scrollItemPtr x y tb
		# tb		= SizeControl scrollItemPtr w h tb
		= tb
	where
		w = r-x
		h = b-y
	
osCompoundMovesControls		:== False
osCompoundControlHasOrigin	:== False


//-- RadioControl

RadioButProc	:==	370	//2		// radio button
RadBoxWid		:== 32
RadBoxHight
//	:== 18
	=: GetRadioButtonHeight

GetRadioButtonHeight
	# ((err,height),_)	= GetThemeMetric kThemeMetricRadioButtonHeight OSNewToolbox
	= height

kThemeMetricRadioButtonHeight	:== 3

osGetRadioControlItemSize :: !OSWindowMetrics !String !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetRadioControlItemSize wMetrics=:{osmFont,osmHeight} text tb
	# (w,tb)	= osGetfontstringwidth False 0 text osmFont tb
	# w			= RadBoxWid+w
	# h			= RadBoxHight//osmHeight
	# tb = trace_n` ("osGetRadioControlItemSize :: width: "+++toString w+++" height: "+++toString h) tb
	= ((w,h),tb)

osGetRadioControlItemHeight :: !OSWindowMetrics -> Int
osGetRadioControlItemHeight {osmHeight}
	# h			= RadBoxHight//osmHeight
	= trace_n ("osGetRadioControlItemHeight :: height: "+++toString h) h

osGetRadioControlItemMinWidth :: !OSWindowMetrics -> Int
osGetRadioControlItemMinWidth {osmHeight}
	# w = RadBoxWid
	= trace_n ("osGetRadioControlItemMinWidth: ", w) w

osCreateRadioControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !Bool !(!Int,!Int) !(!Int,!Int) !Bool !Bool !*OSToolbox
																						   -> (!OSWindowPtr,!*OSToolbox)
osCreateRadioControl parentWindow parentPos title show able (x,y) (w,h) selected isfirst tb
	# (radioH,tb)		= NewControl parentWindow (OSRect2Rect itemRect) (validateControlTitle title) True value 0 1 RadioButProc 0 tb
	#! tb = trace_n` ("osCreateRadioControl"+++toString (radioH,parentWindow,parentPos)) tb
	# tb = case able of
			True	-> tb
			False	-> appGrafport parentWindow (HiliteControl radioH 255) tb
	# tb = case show of
			True	-> tb
			False	-> HideControl radioH tb
	= (radioH,tb)
where
	itemRect	= {rleft=x,rtop=y, rright=x+w,rbottom=y+h}
//	show		= True
//	value		= if isfirst 1 0
	value		= if selected 1 0

osDestroyRadioControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyRadioControl cPtr tb
	# tb = trace_n` ("osDestroyRadioControl") tb
	= DisposeControl cPtr tb

osUpdateRadioControl :: !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateRadioControl area _ parentWindow theControl tb
	#! tb = trace_n` ("osUpdateRadioControl",theControl,area) tb
	#! tb = assertPort` parentWindow tb
	= osUpdateCommonControl area theControl tb

osSetRadioControl :: !OSWindowPtr !OSWindowPtr !OSWindowPtr !OSRect !*OSToolbox -> *OSToolbox
osSetRadioControl wPtr current new cliprect tb
	# tb = trace_n` ("osSetRadioControl",current,new) tb
	# tb = setClippedControlValue wPtr cliprect current 0 tb
	# tb = setClippedControlValue wPtr cliprect new 1 tb
	= tb

osSetRadioControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetRadioControlSelect wPtr cPtr _ select tb
	#! tb = trace_n` ("osSetRadioControlSelect",cPtr,select) tb
	#! tb = assertPort` wPtr tb
	# tb = HiliteControl cPtr (if select 0 255) tb
	= tb

osSetRadioControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetRadioControlShow wPtr cPtr clipRect show tb
	#! tb = trace_n` ("osSetRadioControlShow",cPtr,show) tb
	| show
		= appClipport wPtr clipRect (showC cPtr) tb
	= appClipport wPtr clipRect (showC cPtr) tb
where
	showC cPtr tb
		| show = ShowControl cPtr tb
		= HideControl cPtr tb
		
osSetRadioControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetRadioControlPos wPtr (parent_x,parent_y) radioPtr (x,y) _ update tb
	#! tb = trace_n` ("osSetRadioControlPos",radioPtr,(x,y),(h,v)) tb
	#! tb = assertPort` wPtr tb
	# tb = MoveControl radioPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetRadioControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetRadioControlSize wPtr _ radioPtr _ size=:(w,h) update tb
	#! tb = trace_n` ("osSetRadioControlSize",radioPtr,size) tb
	#! tb = assertPort` wPtr tb
	# tb = SizeControl radioPtr w h tb
	= tb

osClipRadioControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipRadioControl _ parentPos area itemPos itemSize tb
	# tb = trace_n` ("osClipRadioControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb


//-- CheckControl

GetCheckBoxHeight
	# ((err,height),_)	= GetThemeMetric kThemeMetricCheckBoxHeight OSNewToolbox
	= height

kThemeMetricCheckBoxHeight	:== 2

CheckBoxProc	:==	1		// check box
CheckBoxHeigth	=: GetCheckBoxHeight

osGetCheckControlItemSize :: !OSWindowMetrics !String !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetCheckControlItemSize wMetrics=:{osmFont} text tb
	# (w,tb)	= osGetfontstringwidth False 0 text osmFont tb
	# w			= RadBoxWid+w
	# h			= CheckBoxHeigth//osmHeight
	# tb = trace_n ("osGetCheckControlItemSize :: width: "+++toString w+++" height: "+++toString h) tb
	= ((w,h),tb)

osGetCheckControlItemHeight :: !OSWindowMetrics -> Int
osGetCheckControlItemHeight _
	# h			= CheckBoxHeigth//osmHeight
	= trace_n ("osGetCheckControlItemHeight :: height: "+++toString h) h

osGetCheckControlItemMinWidth :: !OSWindowMetrics -> Int
osGetCheckControlItemMinWidth _
	# w = RadBoxWid
	= trace_n ("osGetCheckControlItemMinWidth",w) w

osCreateCheckControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !Bool !(!Int,!Int) !(!Int,!Int) !Bool !Bool !*OSToolbox
																						   -> (!OSWindowPtr,!*OSToolbox)
osCreateCheckControl parentWindow parentPos title show able (x,y) (w,h) selected isfirst tb
	# (checkH,tb)	= NewControl parentWindow (OSRect2Rect itemRect) (validateControlTitle title) True value 0 1 CheckBoxProc 0 tb
	#! tb = trace_n ("osCreateCheckControl",checkH) tb
	# tb = case able of
			True	-> tb
			False	-> appGrafport parentWindow (HiliteControl checkH 255) tb
	# tb = case show of
			True	-> tb
			False	-> HideControl checkH tb
	= (checkH,tb)
where
	itemRect	= {rleft=x,rtop=y, rright=x+w,rbottom=y+h}
	value		= if selected 1 0

osDestroyCheckControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyCheckControl cPtr tb
	# tb = trace_n ("osDestroyCheckControl") tb
	= DisposeControl cPtr tb

osUpdateCheckControl :: !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateCheckControl area _ parentWindow theControl tb
	#! tb = trace_n ("osUpdateCheckControl") tb
	#! tb = assertPort` parentWindow tb
	= osUpdateCommonControl area theControl tb

osClipCheckControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipCheckControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipCheckControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osSetCheckControl :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCheckControl wPtr cPtr cliprect check tb
	#! tb = trace_n ("osSetCheckControl",cPtr,check) tb
	# tb = setClippedControlValue wPtr cliprect cPtr (if check 1 0) tb
	= tb

osSetCheckControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCheckControlSelect wPtr cPtr _ select tb
	#! tb = trace_n ("osSetCheckControlSelect",cPtr,select) tb
	#! tb = assertPort` wPtr tb
	# tb = HiliteControl cPtr (if select 0 255) tb
	= tb

osSetCheckControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCheckControlShow wPtr cPtr clipRect show tb
	#! tb = trace_n ("osSetCheckControlShow",cPtr,show) tb
	| show
		= appClipport wPtr clipRect (ShowControl cPtr o extra) tb
	= appClipport wPtr clipRect (HideControl cPtr o extra) tb
where
	extra tb	= QBackColor WhiteColor tb
	
setnormal tb	= QPenMode PatCopy (QTextMode SrcOr tb)

osSetCheckControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCheckControlPos wPtr (parent_x,parent_y) checkPtr (x,y) _ update tb
	#! tb = trace_n ("osSetCheckControlPos",checkPtr,(x,y)) tb
	#! tb = assertPort` wPtr tb
	# tb = MoveControl checkPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetCheckControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCheckControlSize wPtr _ checkPtr _ size=:(w,h) update tb
	#! tb = trace_n ("osSetCheckControlSize",checkPtr,size) tb
	#! tb = assertPort` wPtr tb
	# tb = SizeControl checkPtr w h tb
	= tb


//-- SliderControl

ScrollBarProc	:==	386

osGetSliderControlSize :: !OSWindowMetrics !Bool !Int -> (!Int,!Int)
osGetSliderControlSize wMetrics isHorizontal length
	| isHorizontal
		# length = trace_n ("osGetSliderControlSize :: Hor: "+++toString wMetrics.osmHSliderHeight) length
		= (length,wMetrics.osmHSliderHeight)
	| otherwise
		# length = trace_n ("osGetSliderControlSize :: Ver: "+++toString wMetrics.osmVSliderWidth) length
		= (wMetrics.osmVSliderWidth,length)

osGetSliderControlMinWidth :: !OSWindowMetrics -> Int
osGetSliderControlMinWidth _
	# w = 16
	= trace_n ("osGetSliderControlMinWidth",w) w

osCreateSliderControl
	:: !OSWindowPtr !(!Int,!Int) !Bool !Bool !Bool !(!Int,!Int) !(!Int,!Int) !(!Int,!Int,!Int,!Int) !*OSToolbox
	-> (!OSWindowPtr,!*OSToolbox)
osCreateSliderControl parentWindow (parent_pos_x,parent_pos_y) show able horizontal (slider_pos_x,slider_pos_y) sliderSize sliderState=:(min,thumb,max,thumbSize) tb
	# itemRect		= posSizeToRect {x = slider_pos_x, y = slider_pos_y} (fromTuple sliderSize)
	# (sliderH,tb)	= NewControl parentWindow (OSRect2Rect itemRect) "" True value min max ScrollBarProc 0 tb
	# tb			= appGrafport parentWindow (init sliderH) tb
	= (sliderH,tb)
where
	init sliderH tb
		# tb = SetCtlMin` sliderH min tb
		# tb = SetCtlMax` sliderH max tb
		# tb = SetCtlValue` sliderH thumb tb
		# tb = SetControlViewSize sliderH thumbSize tb
		# tb = HiliteControl sliderH hilite tb
		= tb
	hilite			= if (min<max && able) 0 255
	value			= thumb


osDestroySliderControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroySliderControl wPtr tb
	# tb = trace_n ("osDestroySliderControl") tb
	= DisposeControl wPtr tb

osUpdateSliderControl :: !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateSliderControl area _ parentWindow theControl tb
	#! tb = trace_n ("osUpdateSliderControl",theControl) tb
	#! tb = assertPort` parentWindow tb
	= osUpdateCommonControl area theControl tb

osClipSliderControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipSliderControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipSliderControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osSetSliderControlThumb :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !(!Int,!Int,!Int,!Int) !*OSToolbox -> *OSToolbox
osSetSliderControlThumb wPtr cPtr rect redraw (min,thumb,max,size) tb
	# tb = SetCtlValue cPtr thumb tb
	# tb = trace_n ("osSetSliderControlThumb "+++toString thumb) tb
	| not redraw = tb
	= appGrafport wPtr (osUpdateCommonControl rect cPtr) tb

osSetSliderControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetSliderControlSelect _ cPtr _ select tb
	# tb = trace_n ("osSetSliderControlSelect") tb
	# tb = HiliteControl cPtr (if select 0 255) tb
	= tb

osSetSliderControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetSliderControlShow wPtr cPtr clipRect show tb
	# tb = trace_n ("osSetSliderControlShow") tb
	| show
		= appClipport wPtr clipRect (ShowControl cPtr) tb
	= appClipport wPtr clipRect (HideControl cPtr) tb

osSetSliderControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetSliderControlPos _ (parent_x,parent_y) sliderPtr (x,y) _ update tb
	# tb = trace_n ("osSetSliderControlPos") tb
	# tb = MoveControl sliderPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetSliderControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetSliderControlSize _ _ sliderPtr _ size=:(w,h) update tb
	# tb = trace_n ("osSetSliderControlSize") tb
	# tb = SizeControl sliderPtr w h tb
	= tb


//-- TextControl

GetTextWidth
	# ((err,white),_)	= GetThemeMetric kThemeMetricEditTextWhitespace OSNewToolbox
	# ((err,frame),_)	= GetThemeMetric kThemeMetricEditTextFrameOutset OSNewToolbox
	= white + frame

TextControlPadding =: GetTextWidth << 1

kThemeMetricEditTextWhitespace	:== 4
kThemeMetricEditTextFrameOutset	:== 5

osGetTextControlSize :: !OSWindowMetrics !String !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetTextControlSize wMetrics=:{osmFont,osmHeight} text tb
	# (textwidth,tb)	= osGetfontstringwidth False 0 text osmFont tb
	# width				= textwidth + TextControlPadding//4
	# tb = trace_n` ("osGetTextControlSize :: width: "+++toString width+++" height: "+++toString osmHeight) tb
	= ((width,osmHeight),tb)

osGetTextControlHeight :: !OSWindowMetrics -> Int
osGetTextControlHeight {osmHeight}
	= trace_n` ("osGetTextControlHeight :: height: "+++toString osmHeight) osmHeight

osGetTextControlMinWidth :: !OSWindowMetrics -> Int
osGetTextControlMinWidth {osmHeight}
	# w = 20 + TextControlPadding//4
	= trace_n ("osGetTextControlMinWidth",w) w

//%%%%%%%%

kControlStaticTextProc	:== 288

osCreateTextControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateTextControl parentWindow parentPos text show /*able*/ (x,y) (w,h) tb
	# (ctrlH,tb)	= NewControl parentWindow (OSRect2Rect itemRect) "???"/*(validateControlTitle text)*/ True 0 0 0 kControlStaticTextProc 0 tb
	#! tb = trace_n ("osCreateTextControl",ctrlH) tb
	# (err,tb)		= SetControlData ctrlH 0 "text" text tb
	# tb = case able of
			True	-> tb
			False	-> appGrafport parentWindow (HiliteControl ctrlH 255) tb
	# tb = case show of
			True	-> tb
			False	-> HideControl ctrlH tb
//	# (s,tb) = GetControlData ctrlH tb
//	# tb = trace_n ("osCreateTextControl","GetControlData",s) tb
	= (ctrlH,tb)
where
	itemRect	= {rleft=x,rtop=y, rright=x+w,rbottom=y+h}
	able		= True	// DvA: should be param...

osDestroyTextControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyTextControl cPtr tb
	# tb = trace_n ("osDestroyTextControl") tb
	= DisposeControl cPtr tb

osUpdateTextControl :: !OSRect !OSRect !String !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateTextControl area _ _ _ parentWindow theControl tb
	#! tb = trace_n ("osUpdateTextControl") tb
	#! tb = assertPort` parentWindow tb
	= osUpdateCommonControl area theControl tb

osClipTextControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipTextControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipTextControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osSetTextControlText :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !String !*OSToolbox -> *OSToolbox
osSetTextControlText wPtr cPtr cliprect _ show text tb
	#! tb = trace_n ("osSetTextControlText",cPtr,show,text) tb
	# (err,tb)	= SetControlData cPtr 0 "text" text tb
	| show
		= appClipport wPtr cliprect (osUpdateCommonControl cliprect cPtr) tb
	= tb

osSetTextControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetTextControlSelect wPtr cPtr _ select tb
	#! tb = trace_n ("osSetTextControlSelect",cPtr,select) tb
	#! tb = assertPort` wPtr tb
	# tb = HiliteControl cPtr (if select 0 255) tb
	= tb

osSetTextControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !String !*OSToolbox -> *OSToolbox
osSetTextControlShow wPtr cPtr clipRect _ show _ tb
	#! tb = trace_n ("osSetTextControlShow",cPtr,show) tb
	| show
		= appClipport wPtr clipRect (ShowControl cPtr o extra) tb
	= appClipport wPtr clipRect (HideControl cPtr o extra) tb
where
	extra tb	= QBackColor WhiteColor tb
	
osSetTextControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetTextControlPos wPtr (parent_x,parent_y) checkPtr (x,y) _ update tb
	#! tb = trace_n ("osSetTextControlPos",checkPtr,(x,y)) tb
	#! tb = assertPort` wPtr tb
	# tb = MoveControl checkPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetTextControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetTextControlSize wPtr _ checkPtr _ size=:(w,h) update tb
	#! tb = trace_n ("osSetTextControlSize",checkPtr,size) tb
	#! tb = assertPort` wPtr tb
	# tb = SizeControl checkPtr w h tb
	= tb

/*
osCreateTextControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateTextControl parentWindow parentPos text show pos=:(x,y) siz=:(w,h) tb
	#! tb = trace_n "osCreateTextControl" tb
	| show
		# tb = appGrafport parentWindow createText tb
		= (OSNoWindowPtr,tb)
	= (OSNoWindowPtr,tb)
where
	itemRect = posSizeToRect (fromTuple pos) (fromTuple siz)

	createText tb
		# (oldfont,tb)	= setDefaultFont parentWindow tb
		# tb			= TETextBox text itemRect TEFlushDefault tb
		# tb			= GrafPtrSetFont oldfont tb
		= tb

osDestroyTextControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyTextControl theControl tb
	# tb = trace_n ("osDestroyTextControl") tb
	= tb
//	= TEDispose theControl tb

osUpdateTextControl :: !OSRect !OSRect !String !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateTextControl updRect itemRect text _ parentWindow theControl tb
	#! tb		= trace_n ("osUpdateTextControl "+++toString (itemRect,updRect)) tb
	#! tb		= assertPort` parentWindow tb
	#! tb		= tracePen parentWindow tb
	#! tb		= traceClip tb
	#! tb		= traceUpdate parentWindow tb

	# (rgn,tb)	= QNewRgn tb
	# (rgn,tb)	= QGetClip rgn tb
	# tb		= QClipRect updRect tb
	# tb		= createText tb
	# tb		= QSetClip rgn tb
	# tb		= QDisposeRgn rgn tb
	= tb
where
	createText tb
		# (oldfont,tb)	= setDefaultFont parentWindow tb
		# tb			= TETextBox text itemRect TEFlushDefault tb
		# tb			= GrafPtrSetFont oldfont tb
		= tb

osClipTextControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipTextControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipTextControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osSetTextControlText :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !String !*OSToolbox -> *OSToolbox
osSetTextControlText wPtr hTE clipRect itemRect show text tb
	#! tb = trace_n ("osSetTextControlText") tb
	| show
		# tb = appGrafport wPtr createText tb
		= tb
	= tb
where
	createText tb
		# (oldfont,tb)	= setDefaultFont wPtr tb
		# tb			= TETextBox text itemRect TEFlushDefault tb
		# tb			= GrafPtrSetFont oldfont tb
		= tb

osSetTextControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetTextControlSelect _ tPtr _ select tb
	#! tb = trace_n ("osSetTextControlSelect") tb
	= tb

osSetTextControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !String !*OSToolbox -> *OSToolbox
osSetTextControlShow wPtr tPtr clipRect itemRect show text tb
	#! tb = trace_n ("osSetTextControlShow ",itemRect,show) tb
	# tb = appClipport wPtr clipRect setshow tb
	= tb
where
	setshow tb
		# tb = tracePen wPtr tb
		# tb = traceClip tb
		# tb = traceUpdate wPtr tb
		| show
			= createText tb
		# tb = QEraseRect itemRect tb
		= InvalRect itemRect tb	// werkt niet??

	createText tb
		# (oldfont,tb)	= setDefaultFont wPtr tb
		# tb			= TETextBox text itemRect TEFlushDefault tb
		# tb			= GrafPtrSetFont oldfont tb
		= tb

osSetTextControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetTextControlPos _ (parent_x,parent_y) textPtr (x,y) _ update tb
	#! tb = trace_n ("osSetTextControlPos") tb
	= tb

osSetTextControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetTextControlSize _ _ textPtr _ size update tb
	#! tb = trace_n ("osSetTextControlSize") tb
	= tb
*/

//-- EditControl

kControlEditTextProc	:== if onOSX 912 272

osCreateEditControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !Bool !Bool !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateEditControl parentWindow parentPos text show able isKeySensitive (x,y) (w,h) tb
	# itemRect			= (x,y,x+w,y+h)
	# (editc,tb)		= NewControl parentWindow itemRect "" True/*show*/ 0 0 0 kControlEditTextProc 0 tb
	# (res,tb)			= IsValidControlHandle parentWindow tb
	# (err2,emb,tb)		= case res of
							0	-> GetRootControl parentWindow tb
							_	-> (0,res,tb)
	# (err3,tb)			= EmbedControl editc emb tb
	# (err,tb)			= SetControlData editc 0 "text" text tb
	# tb = trace_n ("osCreateEditControl "+++toString (editc,itemRect,err,res,err2,err3)) tb
	= (editc,tb)
/*
	# (port,tb)		= QGetPort tb
	# tb			= SetPortWindowPort parentWindow tb
	# (hTE,tb)		= TENew itemRect itemRect tb
	# tb			= TEAutoView True hTE tb
	# tb			= TESetText text hTE tb
	# tb			= TESetSelect 0 0 hTE tb
	# tb			= QSetPort port tb
	# tb = trace_n ("osCreateEditControl "+++toString (hTE,itemRect)) tb
	= (hTE,tb)
where
	itemRect	= (x+3,y+3,x+w-3,y+h-3)
*/
	
osDestroyEditControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyEditControl theControl tb
	# tb = trace_n ("osDestroyEditControl "+++toString theControl) tb
	= DisposeControl theControl tb
/*
	= TEDispose theControl tb
*/

osUpdateEditControl :: !OSRect !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateEditControl updRect itemRect _ parentWindow theControl tb
	#! tb = trace_n ("osUpdateEditControl") tb
	#! tb = assertPort` parentWindow tb
	= osUpdateCommonControl updRect theControl tb
/*
	#! tb = trace_n ("osUpdateEditControl",marginRect,itemRect,parentWindow,theControl) tb
	#! tb = assertPort` parentWindow tb
	// force standard pen...
	# tb				= QPenNormal tb
	# tb				= QEraseRect marginRect tb
	# tb				= TEUpdate (OSRect2Rect updRect) theControl tb
	# tb				= QFrameRect marginRect tb
	= tb
where
	marginRect		= OSRect2Rect itemRect
*/

osClipEditControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipEditControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipEditControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osGetEditControlSize :: !OSWindowMetrics !Int !Int !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetEditControlSize {osmHeight} width nrlines tb
	# tb = trace_n` ("osGetEditControlSize :: "+++toString (width,osmHeight*nrlines)) tb
//	= ((width,osmHeight*nrlines + 6),tb)
	= ((width,osmHeight*nrlines),tb)

osGetEditControlHeight :: !OSWindowMetrics !Int -> Int
osGetEditControlHeight {osmHeight} nrlines
	= trace_n` ("osGetEditControlHeight :: height: "+++toString height) height
where
//	height	= osmHeight * nrlines + 6
	height	= osmHeight * nrlines
	
osGetEditControlMinWidth :: !OSWindowMetrics -> Int
osGetEditControlMinWidth _
	# w = 10
	= trace_n ("osGetEditControlMinWidth",w) w

osIdleEditControl :: !OSWindowPtr !OSRect !OSWindowPtr !*OSToolbox -> *OSToolbox
osIdleEditControl wPtr clipRect hTE tb
	#! tb = trace_n ("osIdleEditControl",wPtr,hTE,clipRect) tb
	= IdleControls wPtr tb
/*
	= appClipport wPtr clipRect (TEIdle hTE) tb
*/
osSetEditControlText :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !String !*OSToolbox -> *OSToolbox
osSetEditControlText wPtr hTE clipRect itemRect show text tb
	#! tb = trace_n ("osSetTextControlText",hTE,show,text) tb
	# (err,tb)	= SetControlData hTE 0 "text" text tb
//	| show
//		= appClipport wPtr clipRect (osUpdateCommonControl clipRect hTE) tb
	= tb
/*
	#! tb = trace_n ("osSetEditControlText "+++toString (wPtr,hTE,clipRect,itemRect,show,text)) tb
	= appGrafport wPtr settext tb
where
	settext tb
		# (clipRgn,tb)	= QNewRgn tb
		# (clipRgn,tb)	= QGetClip clipRgn tb
		# tb			= QClipRect (OSRect2Rect clipRect) tb
		# (itemRect,tb)	= QInsetRect (OSRect2Rect itemRect) tb
		# (clipRgn1,tb)	= setEditRgnRect clipRgn show itemRect tb
		# tb			= QSetClip clipRgn1 tb
		
		# tb			= setEditText text hTE itemRect tb
		# tb			= QSetClip clipRgn tb
		# tb			= QDisposeRgn clipRgn1 tb
		# tb			= QDisposeRgn clipRgn tb
		= tb

	ZeroRect = (0,0,0,0)//{rleft=0,rtop=0,rright=0,rbottom=0}

	setEditRgnRect :: !OSRgnHandle !Bool !Rect !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
	setEditRgnRect clipRgn shown itemRect tb
	#	addEditRect				= if shown ZeroRect itemRect
		(rgn,tb)				= QNewRgn tb
		tb						= QRectRgn rgn addEditRect tb
		(rgn,tb)				= QDiffRgn clipRgn rgn rgn tb
	=	(rgn,tb)
	
	setEditText :: !String !TEHandle !Rect !*OSToolbox -> *OSToolbox
	setEditText text hTE itemRect tb
	#	tb						= TESetSelect 0 32767 hTE tb
		tb						= TEDelete hTE tb
		tb						= TESetText text hTE tb
		tb						= TESetSelect 0 0 hTE tb
		tb						= TEUpdate (OSRect2Rect clipRect) hTE tb
	=	tb
*/

osGetEditControlText :: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!String,!*OSToolbox) 
osGetEditControlText wPtr hTE tb
	# (s,tb) = GetControlData hTE 0 "text" tb
	#! tb = trace_n ("osGetEditControlText ",s) tb
	= (s,tb)
/*
	#! tb = trace_n ("osGetEditControlText "+++toString hTE) tb
	= accGrafport wPtr getText tb
where
	getText tb
		#	(charsH,tb)			= TEGetText hTE tb
			(size,tb)			= TEGetTextSize hTE tb
		= handle_to_string charsH size tb
*/
osSetEditControlCursor :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Int !*OSToolbox -> *OSToolbox
osSetEditControlCursor wPtr ePtr clipRect editRect pos tb
	# data			= {toChar (pos >> 8 bitor 0xFF),toChar (pos bitor 0xFF),toChar (pos >> 8 bitor 0xFF),toChar (pos bitor 0xFF)}
	# (err,tb)		= SetControlData ePtr 0 "sele" data tb
	# tb = trace_n ("osSetEditControlCursor",ePtr,pos,err) tb
	= osUpdateCommonControl clipRect ePtr tb
/*
	# tb = trace_n ("osSetEditControlCursor") tb
	# tb = appClipport wPtr clipRect set tb
	= tb
where
	set tb
		# tb = TESetSelect pos pos ePtr tb
		= tb
*/
		
osSetEditControlSelection :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Int !Int !*OSToolbox -> *OSToolbox
osSetEditControlSelection wPtr ePtr clipRect editRect start end tb
	# data			= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
	# (err,tb)		= SetControlData ePtr 0 "sele" data tb
	# tb = trace_n ("osSetEditControlSelection",ePtr,(start,end),err) tb
//	= tb
	= osUpdateCommonControl clipRect ePtr tb
/*
	# tb = trace_n ("osSetEditControlSelection") tb
	# tb = appClipport wPtr clipRect set tb
	= tb
where
	set tb
		# tb = TESetSelect start end ePtr tb
		= tb
*/

osSetEditControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetEditControlSelect wPtr ePtr clipRect select tb
	# tb = trace_n ("osSetEditControlSelect") tb
	# tb = appClipport wPtr clipRect (HiliteControl ePtr (if select 0 255)) tb
	= tb
/*
	= tb	// no action for TE implementation
*/

osSetEditControlFocus :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetEditControlFocus wPtr ePtr clipRect focus tb
	| focus
		# (err,currentFocus,tb)
					= GetKeyboardFocus wPtr tb
		| currentFocus == ePtr
			# tb = trace_n ("osSetEditControlFocus","focus==currentFocus",err) tb
			= tb
		# (err,tb)	= SetKeyboardFocus wPtr ePtr (-1) tb
		# tb = trace_n ("osSetEditControlFocus",ePtr,focus,err) tb
		= tb
	# (err,tb)	= ClearKeyboardFocus wPtr tb
	# tb = trace_n ("osSetEditControlFocus",ePtr,focus,err) tb
	= tb
		
/*
	| focus
		= appGrafport wPtr (TEActivate ePtr /*o TESetSelect 0 32767 ePtr*/) tb
//		= appGrafport wPtr (TEActivate ePtr o TESetSelect 0 32767 ePtr) tb
	| otherwise
		= appGrafport wPtr (TEDeactivate ePtr) tb
*/

osSetEditControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetEditControlShow wPtr ePtr clipRect show tb
	| show
		= appClipport wPtr clipRect (ShowControl ePtr) tb
	# (err,focus,tb)	= GetKeyboardFocus wPtr tb
	# (err,tb) = case focus == ePtr of
			True	-> ClearKeyboardFocus wPtr tb
			_		-> (0,tb)
	= appClipport wPtr clipRect (HideControl ePtr) tb
/*
	# tb = trace_n ("osSetEditControlShow") tb
	# (itemRect,tb) = TEGetItemRect ePtr tb
	#	(l,t, r,b)		= itemRect
	#	marginRect		= (l-3,t-3, r+3,b+3)
	| show
		# tb = appGrafport wPtr (update) tb
				with
					update tb
						# tb = QEraseRect marginRect tb
						# tb = TEUpdate (OSRect2Rect clipRect) ePtr tb
						# tb = QFrameRect marginRect tb
						= tb
		= tb
	# tb = appGrafport wPtr (InvalWindowRect wPtr marginRect o QEraseRect marginRect) tb
	= appGrafport wPtr (TEDeactivate ePtr) tb
*/

osSetEditControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetEditControlPos _ (parent_x,parent_y) buttonPtr (x,y) _ update tb
	#! tb = trace_n ("osSetEditControlPos") tb
	# tb = MoveControl buttonPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetEditControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetEditControlSize _ _ buttonPtr _ size=:(w,h) update tb
	#! tb = trace_n ("osSetEditControlSize") tb
	# tb = SizeControl buttonPtr w h tb
	= tb
/*
osSetEditControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetEditControlPos wPtr pPos ePtr ePos eSiz upd tb
	# tb = trace_n ("osSetEditControlPos") tb
	= osSetEditControlPosSize wPtr pPos ePtr ePos eSiz tb

osSetEditControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetEditControlSize wPtr pPos ePtr ePos eSiz upd tb
	# tb = trace_n ("osSetEditControlSize") tb
	= osSetEditControlPosSize wPtr pPos ePtr ePos eSiz tb

osSetEditControlPosSize wPtr (parent_x,parent_y) editPtr (x,y) (w,h) tb
	#	(port,tb)			= QGetPort tb
		tb					= SetPortWindowPort wPtr tb
		tb					= InvalWindowRect wPtr  margRect tb
		tb					= QEraseRect margRect tb
		tb					= TESetDestRect editPtr itemRect tb	// Directly write destination field for moving
		tb					= TESetViewRect editPtr itemRect tb	// Directly write view        field for moving
		tb					= TECalText editPtr tb
		tb					= QSetPort port tb
	=	tb
where
	itemRect	= (x+3,y+3,x+w-3,y+h-3)
	margRect	= (x,y,x+w,y+h)
*/	

//-- PopUpControl

PopUpProc :== 400//1008
kControlPopupButtonProc				:== 400
kControlPopupFixedWidthVariant		:==   1	//= 1 << 0,
kControlPopupVariableWidthVariant	:==   2	//= 1 << 1,
kControlPopupUseAddResMenuVariant	:==   4	//= 1 << 2,
//kControlPopupUseWFontVariant  = kControlUsesOwningWindowsFontVariant

//	The fixed Menu ID for the PopUpControl:
PopUpMenuID		:==	235

//	Width of popup-arrow part:
PopUpWid		:== 20//24
PopUpHeight		=: GetPopUpHeight

GetPopUpHeight
	# ((err,height),_)	= GetThemeMetric kThemeMetricPopupButtonHeight OSNewToolbox
	= height

kThemeMetricPopupButtonHeight	:== 30


osGetPopUpControlSize :: !OSWindowMetrics ![String] !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetPopUpControlSize wMetrics=:{osmFont,osmHeight} items tb
	# (widths,tb)	= osGetfontstringwidths False 0 items osmFont tb
	  maxwidth		= listmax widths
	  w				= maxwidth + 2 + PopUpWid
	  h				= PopUpHeight//osGetPopUpControlHeight wMetrics
	= ((w+28,h),tb)
where
	listmax :: ![Int] -> Int
	listmax [x:xs]	= foldr max x xs
	listmax _		= 0

osGetPopUpControlHeight :: !OSWindowMetrics -> Int
osGetPopUpControlHeight {osmHeight}
	# h				= PopUpHeight//osmHeight + 4//2
	= h

osGetPopUpControlMinWidth :: !OSWindowMetrics -> Int
osGetPopUpControlMinWidth {osmHeight}
	# w = 2 + PopUpWid
	= w

osCreateEmptyPopUpControl :: !OSWindowPtr !(!Int,!Int) !Bool !Bool !(!Int,!Int) !(!Int,!Int) !Int !Bool !*OSToolbox
	-> (!OSWindowPtr,!OSWindowPtr,!*OSToolbox)
osCreateEmptyPopUpControl parentWindow parentPos show able (x,y) (w,h) nrItems isEditable tb
	# (ok,mId,tb)		= osNewSubMenuNr tb	// Workaround for MacOS bug...
	| not ok			= abort "oswindow:osCreateEmptyPopUpControl: unable to create menuId.\n"
	# (menuRef,tb)		= NewMenu mId "" tb
	| not isEditable
		# editPtr		= OSNoWindowPtr

		# (popupPtr,tb)	= NewControl parentWindow itemRect "" True/*show*/ 0 (-12345) 0/*(w-26)*/ (kControlPopupButtonProc+kControlPopupFixedWidthVariant) editPtr tb
		# string		= {toChar (menuRef >> 24),toChar (menuRef >> 16 bitand 0xFF),toChar (menuRef >> 8 bitand 0xFF),toChar (menuRef bitand 0xFF)}
		# (err,tb)		= SetControlData popupPtr 2 "mhan" string tb
		| err <> 0		= abort "oswindow:osCreateEmptyPopUpControl: SetControlData failed.\n"

		# tb			= SetCtlMax popupPtr 0 tb
		# tb = trace_n ("osCreateEmptyPopUpControl1",popupPtr,editPtr,((x,y),(w,h))) tb
		= (popupPtr,editPtr,tb)

	# (editPtr,tb)		= accGrafport parentWindow createEdit tb
	# tb				= AppendMenu menuRef " " tb
	# tb				= AppendMenu menuRef "-(" tb

	# (popupPtr,tb)		= NewControl parentWindow itemRect` "" True/*show*/ 0 (-12345)/*mId*/ 0/*(w-46)*/ (kControlPopupButtonProc+kControlPopupFixedWidthVariant) editPtr tb
	# string			= {toChar (menuRef >> 24),toChar (menuRef >> 16 bitand 0xFF),toChar (menuRef >> 8 bitand 0xFF),toChar (menuRef bitand 0xFF)}
	# (err,tb)			= SetControlData popupPtr 2 "mhan" string tb
	| err <> 0			= abort "oswindow:osCreateEmptyPopUpControl: SetControlData failed.\n"

	# tb				= SetCtlMax popupPtr 2 tb
	# tb				= trace_n ("osCreateEmptyPopUpControl2",popupPtr,editPtr,((x,y),(w,h))) tb
	= (popupPtr,editPtr,tb)
where
	itemRect	= (x,y,x+w,b)//{rleft=x,rtop=y, rright=x+w,rbottom=b}

	itemRect`	= (x+w-popWidth,y, x+w,b)
	editRect	= (x,y,x+w-popWidth-popSep,b)
//	updateRect	= (x+1,y+1,x+w-popWidth-1,b-1)
	popWidth	= 20//22
	popSep		= 8//6

	b = y+h

	createEdit tb
		# (editc,tb)		= NewControl parentWindow editRect "" True/*show*/ 0 0 0 kControlEditTextProc 0 tb
//		# tb				= addReturnFilter editc tb
		# (res,tb)			= IsValidControlHandle parentWindow tb
		# (err2,emb,tb)		= case res of
								0	-> GetRootControl parentWindow tb
								_	-> (0,res,tb)
		# (err3,tb)			= EmbedControl editc emb tb
		# (err,tb)			= SetControlData editc 0 "text" "" tb
//		# tb				= Draw1Control editc tb
		= (editc,tb)
/*
		# tb			= QEraseRect editRect tb
		# tb			= QFrameRect editRect tb
		
		# (oldfont,tb)	= setDialogFont parentWindow tb

		# (hTE,tb)		= TENew updateRect updateRect tb
		# tb			= TEAutoView True hTE tb	// ???
		# tb			= TESetText "" hTE tb
		# tb			= TESetSelect 0 0 hTE tb	// ???

		# tb			= GrafPtrSetFont oldfont tb
		= (hTE,tb)
*/

osCreatePopUpControlItems :: !OSWindowPtr !(Maybe OSWindowPtr) !Bool ![String] !Int !*OSToolbox -> *OSToolbox
osCreatePopUpControlItems parentPopUp editPtr able items selectedNr tb
	# tb = trace_n ("osCreatePopUpControlItems",parentPopUp,editPtr) tb
	# tb = case editable of
		True
				# (mPtr,tb)		= GetControlPopupMenuHandle parentPopUp tb
				# (n,tb)		= GetCtlMax parentPopUp tb
				# (n,tb)		= appendItems mPtr n items tb
				# tb			= SetCtlMax parentPopUp n tb

				# hTE			= fromJust editPtr
				# title			= if (selectedNr > 0 && length items >= selectedNr) (items!!(dec selectedNr)) ""
				# title`		= osValidateMenuItemTitle Nothing title
				# (err,tb)		= SetControlData hTE 0 "text" title tb
				# start			= 0
				# end			= 0
				# data			= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
				# (err,tb)		= SetControlData hTE 0 "sele" data tb
				# tb			= SetItem mPtr 1 title tb
				-> tb
		False
				# (mPtr,tb)		= GetControlPopupMenuHandle parentPopUp tb
				# (n,tb)		= GetCtlMax parentPopUp tb
				# (n,tb)		= appendItems mPtr n items tb
				# tb			= SetCtlMax parentPopUp n tb
				-> tb
	# tb					= SetCtlValue parentPopUp itemNr` tb
	= tb
/*	= case editPtr of
			(Just hTE)
				# title			= if (selectedNr > 0) (items!!(dec selectedNr)) ""
				# (err,tb)		= SetControlData hTE 0 "text" (osValidateMenuItemTitle Nothing title) tb
				# start			= 0
				# end			= 0
				# data			= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
				# (err,tb)		= SetControlData hTE 0 "sele" data tb
//				# tb			= TESetText (osValidateMenuItemTitle Nothing title) hTE tb
//				# tb			= TESetSelect 0 0 hTE tb
				-> tb
			Nothing
				-> tb
*/
where
	appendItems mPtr n [] tb	= (n,tb)
	appendItems mPtr n [title:items] tb
		# n				= n + 1
		# title`		= osValidateMenuItemTitle Nothing title
		# tb			= AppendMenu mPtr title tb
		
//		# tb			= SetItem mPtr n title tb
		| n == selectedNr && editable
			# ePtr		= fromJust editPtr
			# (err,tb)	= SetControlData ePtr 0 "text" title tb
			# start		= 0
			# end		= 0
			# data		= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
			# (err,tb)	= SetControlData ePtr 0 "sele" data tb
			= appendItems mPtr n items tb
		= appendItems mPtr n items tb
	
	editable	= isJust editPtr
	itemNr`
		| editable
			= selectedNr + 2
			= selectedNr
/*
	selectText
		| selected	= title+++check
					= title
	where
		title = " "
		check = "!"+++toString (toChar 18)
*/

osCreatePopUpControlItem :: !OSWindowPtr !(Maybe OSWindowPtr) !Int !Bool !String !Bool !Int !*OSToolbox -> (!Int,!*OSToolbox)
osCreatePopUpControlItem parentPopUp editPtr pos able title selected itemNr tb
	= undef
/*
	# tb = trace_n ("osCreatePopUpControlItem",parentPopUp,editPtr) tb
	# tb = case editable of
		True
				# (mPtr,tb)		= GetControlPopupMenuHandle parentPopUp tb
				# tb			= AppendMenu mPtr title tb
				# tb			= SetItem mPtr itemNr` (osValidateMenuItemTitle Nothing title) tb
				# (n,tb)		= GetCtlMax parentPopUp tb
				# tb			= SetCtlMax parentPopUp (inc n) tb
				-> tb
		False
				# (mPtr,tb)		= GetControlPopupMenuHandle parentPopUp tb
				# tb			= AppendMenu mPtr title tb
				# tb			= SetItem mPtr itemNr` (osValidateMenuItemTitle Nothing title) tb
				# (n,tb)		= GetCtlMax parentPopUp tb
				# tb			= SetCtlMax parentPopUp (inc n) tb
				-> tb
	| selected
		# tb					= SetCtlValue parentPopUp itemNr` tb
		= case editPtr of
			(Just hTE)
				# (err,tb)		= SetControlData hTE 0 "text" (osValidateMenuItemTitle Nothing title) tb
				# start			= 0
				# end			= 0
				# data			= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
				# (err,tb)		= SetControlData hTE 0 "sele" data tb
//				# tb			= TESetText (osValidateMenuItemTitle Nothing title) hTE tb
//				# tb			= TESetSelect 0 0 hTE tb
				-> (0,tb)
			Nothing
				-> (0,tb)
	= (0,tb)
where
	editable	= isJust editPtr
	itemNr`
		| isJust editPtr
			= itemNr + 2
			= itemNr
*/
/*
	selectText
		| selected	= title+++check
					= title
	where
		title = " "
		check = "!"+++toString (toChar 18)
*/
osDestroyPopUpControl :: !OSWindowPtr !(Maybe OSWindowPtr) !*OSToolbox -> *OSToolbox
osDestroyPopUpControl popupPtr editPtr tb
	# tb = trace_n ("osDestroyPopUpControl",popupPtr,editPtr) tb
	// if editable throw away TEHandle...
	= case editPtr of
			Nothing
				# (menuPtr,tb)		= GetControlPopupMenuHandle popupPtr tb
//				# (menuPtr,_,tb)	= GetPopUpControlData popupPtr tb
				# tb = DisposeControl popupPtr tb
//				# tb = case menuId of
//						PopUpMenuID	-> tb
//						menuId		-> DeleteMenu menuId tb
				# tb = DisposeMenu menuPtr tb
				-> tb
			(Just hTE)
//				# tb = TEDispose hTE tb
				# tb				= DisposeControl hTE tb
//				# tb = DisposeMenu popupPtr tb
				# (menuPtr,tb)		= GetControlPopupMenuHandle popupPtr tb
//				# (menuPtr,_,tb)	= GetPopUpControlData popupPtr tb
				# tb = DisposeControl popupPtr tb
//				# tb = case menuId of
//						PopUpMenuID	-> tb
//						menuId		-> DeleteMenu menuId tb
				# tb = DisposeMenu menuPtr tb
				-> tb

osHandlePopUpControlEvent :: !OSWindowPtr !(Maybe OSWindowPtr) !OSWindowPtr !Point2 !Size !Int !String !*OSToolbox -> (!Int,!*OSToolbox) 
osHandlePopUpControlEvent itemPtr editPtr wPtr wItemPos wItemSize puIndex title tb
	# tb = trace_n ("osHandlePopUpControlEvent",itemPtr,editPtr) tb
	= accGrafport wPtr (osHandlePopUpControlEvent itemPtr editPtr wPtr wItemPos wItemSize puIndex title) tb
where
	osHandlePopUpControlEvent :: !OSWindowPtr !(Maybe OSWindowPtr) !OSWindowPtr !Point2 !Size !Int !String !*OSToolbox -> (!Int,!*OSToolbox) 
	osHandlePopUpControlEvent itemPtr editPtr wPtr wItemPos wItemSize puIndex title tb
	// huidige text ophalen
	= case editPtr of
			(Just ePtr)
				# (title,tb)		= osGetPopUpControlText wPtr ePtr tb
				# (menuPtr,tb)		= GetControlPopupMenuHandle itemPtr tb
				# (getIndex,tb)		= GetCtlValue itemPtr tb
				# (text,tb)			= GetItem menuPtr getIndex String256 tb
				# tb = trace_n` ("Title",title,text,getIndex) tb

				# tb				= case title==text of
										True
											-> tb
										False
											# tb	= SetCtlValue itemPtr 1 tb
											-> SetItem menuPtr 1 title tb

//				# (global,tb)		= LocalToGlobal wItemPos tb
				# (newIndex,tb)		= TrackControl itemPtr (wItemPos.x + wItemSize.w - 20) wItemPos.y 0 tb
				# (getIndex,tb)		= GetCtlValue itemPtr tb
				# tb				= Draw1Control itemPtr tb	// shouldn't be necessary?
				# tb = trace_n ("Index",newIndex,getIndex) tb

				# (text,tb)			= GetItem menuPtr getIndex String256 tb
				# tb				= setPopUpEditText ePtr text tb

				# tb				= assertPort` wPtr tb
				# tb				= redrawPopUpEditText ePtr (toTuple wItemPos) (toTuple wItemSize) text tb


				# (title,tb)		= osGetPopUpControlText wPtr ePtr tb
				# (menuPtr,tb)		= GetControlPopupMenuHandle itemPtr tb
				# (getIndex,tb)		= GetCtlValue itemPtr tb
				# (text,tb)			= GetItem menuPtr getIndex String256 tb
				# tb = trace_n` ("Title`",title,text,getIndex) tb

				# getIndex			= getIndex - 2
				-> (getIndex,tb)
			_	
//				# (global,tb)		= LocalToGlobal wItemPos tb
				# (newIndex,tb)		= TrackControl itemPtr wItemPos.x wItemPos.y 0 tb
				# (getIndex,tb)		= GetCtlValue itemPtr tb
				# tb				= Draw1Control itemPtr tb	// shouldn't be necessary?
				# tb = trace_n ("Index",newIndex,getIndex) tb
				-> (getIndex,tb)

String256 :: String
String256 = createArray 256 '@'

osUpdatePopUpControl :: !OSRect !OSWindowPtr !OSWindowPtr !(Maybe OSWindowPtr) !(!Int,!Int) !(!Int,!Int)  !Bool !String !*OSToolbox -> *OSToolbox
osUpdatePopUpControl area parentWindow theControl editPtr pos size select text tb
	# tb			= trace_n ("osUpdatePopUpControl",parentWindow,theControl,area) tb
	| not editable
//		# (menuPtr,mId,tb)	= GetPopUpControlData theControl tb
		# tb				= osUpdateCommonControl area theControl tb
		= tb

//	# (menuPtr,mId,tb)	= GetPopUpControlData theControl tb
	# tb				= osUpdateCommonControl area theControl tb

	# tb				= assertPort` parentWindow tb
//	# tb				= redrawPopUpEditText (fromJust editPtr) pos size text tb
	= osUpdateCommonControl area (fromJust editPtr) tb

//	# (_,_,tb)			= GetPopUpControlData theControl tb
//	= tb
where
	editable = isJust editPtr
	area` = posSizeToRect pos size

osClipPopUpControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipPopUpControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipPopUpControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb


osGetPopUpControlText :: !OSWindowPtr !OSWindowPtr !*OSToolbox -> (!String,!*OSToolbox) 
osGetPopUpControlText wPtr hTE tb
	#! tb = trace_n ("osGetPopUpControlText "+++toString hTE) tb
	= GetControlData hTE 0 "text" tb
/*
	= accGrafport wPtr getText tb
where
	getText tb
		#	(charsH,tb)			= TEGetText hTE tb
			(size,tb)			= TEGetTextSize hTE tb
		= handle_to_string charsH size tb
*/

osSetPopUpControl :: !OSWindowPtr !OSWindowPtr !(Maybe OSWindowPtr) !OSRect !OSRect !Int !Int !String !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControl wPtr pPtr ePtr clipRect pPosSize old new text shown tb
	# tb = trace_n ("osSetPopUpControl",clipRect,pPosSize,text,new) tb
	| isJust ePtr
		# tb = appClipport wPtr clipRect setPopup` tb
		= tb
	# tb = appClipport wPtr clipRect setPopup tb		
	= tb
where
	setPopup tb
//		# (menuPtr,mId,tb)	= GetPopUpControlData pPtr tb
		# tb				= SetCtlValue pPtr new tb
		= tb
	setPopup` tb
//		# (menuPtr,mId,tb)	= GetPopUpControlData pPtr tb
		# tb				= SetCtlValue pPtr (new+2) tb
		# tb				= setPopUpEditText (fromJust ePtr) text tb

		# tb			= assertPort` wPtr tb
		# tb			= redrawPopUpEditText (fromJust ePtr) (toTuple pos) (toTuple siz) text tb
		= tb
	pos					= (rectToRectangle pPosSize).corner1
	siz					= rectSize pPosSize

osSetPopUpControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControlSelect wPtr pPtr clipRect select tb
	# tb = trace_n ("osSetPopUpControlSelect") tb
//	# tb = assertPort` wPtr tb
	# tb = appClipport wPtr clipRect (HiliteControl pPtr (if select 0 255)) tb
//	# tb = appGrafport wPtr (HiliteControl pPtr (if select 0 255)) tb
	= tb

osSetPopUpControlFocus :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControlFocus wPtr itemPtr clipRect focus tb
	# (editPtr,tb) = GetCtlRef itemPtr tb
	# tb = trace_n ("osSetPopUpControlFocus",itemPtr,editPtr) tb
	| focus
		# (err,currentFocus,tb)
					= GetKeyboardFocus wPtr tb
		| currentFocus == editPtr
			# tb = trace_n` ("osSetPopUpControlFocus","focus==currentFocus",err) tb
			= tb
		# (err,tb)	= SetKeyboardFocus wPtr editPtr (-1) tb
		# tb = trace_n` ("osSetPopUpControlFocus",editPtr,focus,err) tb
		= tb
	# (err,tb)	= ClearKeyboardFocus wPtr tb
	# tb = trace_n` ("osSetPopUpControlFocus",editPtr,focus,err) tb
	= tb
/*
	# (ePtr,tb) = GetCtlRef itemPtr tb
	# tb = trace_n ("osSetPopUpControlFocus",itemPtr,ePtr) tb
	| ePtr == 0
		= tb
	| focus
		= appGrafport wPtr (TEActivate ePtr o TESetSelect 0 32767 ePtr) tb
	| otherwise
		= appGrafport wPtr (TEDeactivate ePtr) tb
*/
osSetPopUpControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControlShow wPtr pPtr clipRect show tb
	# tb = trace_n ("osSetPopUpControlShow") tb
	| show
		= appClipport wPtr clipRect (ShowControl pPtr) tb
	= appClipport wPtr clipRect (HideControl pPtr) tb

osSetPopUpControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControlPos wPtr (parent_x,parent_y) popupPtr (x,y) _ update tb
	# tb = trace_n ("osSetPopUpControlPos") tb
	# tb = assertPort` wPtr tb
	| editable
		// als editable wat doen...
		= tb
	# tb = MoveControl popupPtr h v tb
	= tb
where
	editable = isJust editPtr
	editPtr = Nothing
	h = x //- parent_x
	v = y //- parent_y

osSetPopUpControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetPopUpControlSize wPtr _ popupPtr _ (w,h) update tb
	# tb = trace_n ("osSetPopUpControlSize unimplemented...") tb
	# tb = assertPort` wPtr tb
	| editable
		// als editable wat doen...
		= tb
	# tb = SizeControl popupPtr w h tb
	= tb
where
	editable = isJust editPtr
	editPtr = Nothing
/*
//	Update the complete PopUpControl: (assumes non-editable...)
redrawPopUp :: !Point2 !Size !SelectState !String !(Maybe OSWindowPtr) !*OSToolbox -> *OSToolbox
redrawPopUp itemPos=:{x,y} itemSize=:{w,h} select item editPtr tb
	# tb		= trace_n ("redrawPopUp",item,editPtr) tb
	# (wm,tb)	= osDefaultWindowMetrics tb
	# (a,d,l)	= wm.osmFontMetrics

	# ft		= wm.osmFont
	  {osfontnumber=fontNr,osfontstyles=styles,osfontsize=size,osfontname=name}
	  				= osFontgetimp ft
	# tb			= GrafPtrSetFont (fontNr,fontstylestoid styles,size) tb

	# baseOffset= a + l
	#	tb	= QEraseRect	(x,y, r1,b1)	tb

		tb	= QDrawArrow	select r y					tb
	
		tb	= case editPtr of
				Nothing
					#	tb	= QMoveTo		(x+4) (y+baseOffset)		tb
					#	tb	= QDrawString	item						tb
					->	tb
				(Just hTE)
					#	tb	= TESetSelect 0 32767 hTE tb
						tb	= TEDelete hTE tb
						tb	= TESetText item hTE tb
						tb	= TESetSelect 0 0 hTE tb
					#	tb	= TEUpdate		(x+1,y+1, x+w-17,y+h-2) hTE tb
					->	tb
	//	tb	= TEUpdate		(fromTuple4(x,y, r1,b1)) hTE tb
		tb	= QFrameRect	(x,y, r1,b1)	tb
		tb	= QMoveTo		r1 (y+2)					tb
		tb	= QLineTo		r1 b1						tb
		tb	= QLineTo		(x+2) b1					tb
	=	tb
where
	r	= x+w;	r1	= r-1
	b	= y+h;	b1	= b-1

//	Update the text selection of a PopUpControl:
redrawPopUpItemText :: !Point2 !Size !String !*OSToolbox -> *OSToolbox
redrawPopUpItemText itemPos=:{x,y} itemSize=:{w,h} item tb
	# tb		= trace_n ("redrawPopUpItemText",item) tb
	# (wm,tb) = osDefaultWindowMetrics tb
	# (a,d,l) = wm.osmFontMetrics
	
	# ft		= wm.osmFont
	  {osfontnumber=fontNr,osfontstyles=styles,osfontsize=size,osfontname=name}
	  				= osFontgetimp ft
	# tb			= GrafPtrSetFont (fontNr,fontstylestoid styles,size) tb
	
	# baseOffset = a + l
	#	tb	= QEraseRect	(x+1,y+1, x+w-17,y+h-2)	tb
	
		tb	= QMoveTo		(x+4) (y+baseOffset)	tb
		tb	= QDrawString	item					tb
	=	tb
where
	r	= x+w
*/
redrawPopUpEditText hTE (x,y) (w,h) text tb
	# tb		= trace_n ("redrawPopUpEditText",hTE,text) tb
	= osUpdateCommonControl editRect hTE tb
/*
	# (gPtr,tb)		= QGetPort tb
	# (oldfont,tb)	= GrafPtrGetFont gPtr tb

//	#	tb	= QEraseRect	(fromTuple4(x+1,y+1, x+w-22/*17*/,y+h-2))	tb
	
	#	tb = QEraseRect editRect tb
		tb = QFrameRect editRect tb
//		tb = setPopUpEditText hTE text tb
//		tb	= TEUpdate		(fromTuple4(x+1,y+1, x+w-22/*17*/,y+h-2)) hTE tb
		tb	= TEUpdate updateRect hTE tb

	# tb			= GrafPtrSetFont oldfont tb
	=	tb
*/
where
	editRect	= (x,y,x+w-22,y+h)
	updateRect	= (x+1,y+1,x+w-22-1,y+h-1)

setPopUpEditText hTE text tb
	# tb		= trace_n ("setPopUpEditText",hTE,text) tb
	# (err,tb)		= SetControlData hTE 0 "text" (osValidateMenuItemTitle Nothing text) tb
	# start			= 0
	# end			= 0
	# data			= {toChar (start >> 8 bitor 0xFF),toChar (start bitor 0xFF),toChar (end >> 8 bitor 0xFF),toChar (end bitor 0xFF)}
	# (err,tb)		= SetControlData hTE 0 "sele" data tb
/*
	#	tb	= TESetSelect 0 32767 hTE tb
		tb	= TEDelete hTE tb
		tb	= TESetText text hTE tb
		tb	= TESetSelect 0 0 hTE tb
*/
	= tb

//osGainFocusPopUpControl
//osLoseFocusPopUpControl

osIdlePopUpControl :: !OSWindowPtr !OSRect !OSWindowPtr !(Maybe OSWindowPtr) !*OSToolbox -> *OSToolbox
osIdlePopUpControl wPtr clipRect cPtr ePtr tb
	#! tb = trace_n ("osIdlePopUpControl",wPtr,ePtr,clipRect) tb
	| isNothing ePtr = tb
	= IdleControls wPtr tb
//	= appClipport wPtr clipRect (TEIdle hTE) tb
where
	hTE = fromJust ePtr

//-- ButtonControl


GetButtonHeight
	# ((err,height),_)	= GetThemeMetric kThemeMetricPushButtonHeight OSNewToolbox
	= height

kThemeMetricPushButtonHeight	:== 19

PushButProc				:==	368	//0		// simple button

//MinButWid				:== 10//55

ButtonHeightPlatinum	:== 20
ButtonHeightAqua		:== 20
ButtonHeight
//	:== ButtonHeightAqua
	=: GetButtonHeight

ButtonWidthPlatinum		:== 12
ButtonWidthAqua			:== 24
ButtonWidth
//	:== ButtonWidthAqua
	=: GetButtonHeight	//???

osGetButtonControlSize :: !OSWindowMetrics !String !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetButtonControlSize wMetrics=:{osmFont,osmHeight} text tb
//	# (width,tb)	= osGetfontstringwidth False 0 (validateControlTitle text) osmFont tb
	# ((width,h),tb)= osGetThemeTextDimensions (validateControlTitle text) tb
//	# width			= max MinButWid (ButtonWidth+width)
	# width			= ButtonWidth + width
	# tb = trace_n ("osGetButtonControlSize :: width: "+++toString width+++" height: "+++toString ButtonHeight) tb
	= ((width,ButtonHeight),tb)
	
osGetButtonControlHeight :: !OSWindowMetrics -> Int
osGetButtonControlHeight {osmHeight}
	= trace_n ("osGetButtonControlHeight :: height: "+++toString ButtonHeight) ButtonHeight
	
osGetButtonControlMinWidth :: !OSWindowMetrics -> Int
osGetButtonControlMinWidth {osmHeight}
	# w = ButtonWidth//MinButWid
	= trace_n ("osGetButtonControlMinWidth",w) w

osCreateButtonControl :: !OSWindowPtr !(!Int,!Int) !String !Bool !Bool !(!Int,!Int) !(!Int,!Int) !OKorCANCEL !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateButtonControl parentWindow parentPos=:(ox,oy) title show able (x,y) (w,h) okOrCancel tb
	# (buttonH,tb)	= NewControl parentWindow itemRect (validateControlTitle title) show 0 0 1 PushButProc refcon tb
	# (err,root,tb)	= GetRootControl parentWindow tb
	# (err,tb)		= EmbedControl buttonH root tb
//	# (err,tb)		= SetControlData buttonH 0 "dflt" string tb
	# (err,tb)		= case okOrCancel of
						OK	-> SetWindowDefaultButton parentWindow buttonH tb
						_	-> (0,tb)
	| err <> 0		= abort "oswindow:osCreateButtonControl:SetControlData failed\n"
	| able
		= (buttonH,tb)
	# tb			= HiliteControl buttonH 255 tb
	= (buttonH,tb)
where
	string = case okOrCancel of
		OK		-> "1"
		_		-> "0"
	itemRect = (x,y, x+w,y+h)
	refcon = 0

osDestroyButtonControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyButtonControl wPtr tb
	# tb = trace_n ("osDestroyButtonControl") tb
	= DisposeControl wPtr tb

osUpdateButtonControl :: !OSRect !OSRect !(!Int,!Int) !OSWindowPtr !OSWindowPtr !*OSToolbox -> *OSToolbox
osUpdateButtonControl clipRect buttonRect _ parentWindow theControl tb
	#! tb = trace_n ("osUpdateButtonControl",parentWindow,theControl,buttonRect) tb
	#! tb = assertPort` parentWindow tb
	# (ref,tb)	= GetCtlRef theControl tb
	#  tb = trace_n ("osUpdateButtonControl",ref) tb
//	# (saveRgn,tb)	= QNewRgn tb
//	# (saveRgn,tb)	= QGetClip saveRgn tb
//	# tb			= QClipRect (OSRect2Rect clipRect) tb
	# tb			= Draw1Control theControl tb
//	# tb			= QSetClip saveRgn tb
//	# tb			= QDisposeRgn saveRgn tb
	= tb

osClipButtonControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipButtonControl _ parentPos clipRect itemPos itemSize tb
	# tb = trace_n ("osClipButtonControl") tb
	# (clipRgn,tb)	= QNewRgn tb
	# (aidRgn1,tb)	= QNewRgn tb
	# (aidRgn2,tb)	= QNewRgn tb
	# tb			= QOpenRgn aidRgn2 tb
	# tb			= QFrameRoundRect buttonRect 10 10 tb
	# tb			= QCloseRgn aidRgn2 tb
	# tb			= QRectRgn aidRgn1 (OSRect2Rect clipRect) tb
	# (aidRgn1,tb)	= QSectRgn aidRgn1 aidRgn2 aidRgn1 tb
	# (clipRgn,tb)	= QUnionRgn clipRgn aidRgn1 clipRgn tb
	# tb			= QDisposeRgn aidRgn1 tb
	# tb			= QDisposeRgn aidRgn2 tb
	= (clipRgn,tb)
where
	rect			= posSizeToRect (fromTuple itemPos) (fromTuple itemSize)
	(l,t, r,b)		= toTuple4 rect
	buttonRect		= /*if (isJust itemId && isJust defId && fromJust defId==fromJust itemId) (l-4,t-4, r+4,b+4)*/ (toTuple4 rect)

osSetButtonControlText :: !OSWindowPtr !OSWindowPtr !OSRect !String !*OSToolbox -> *OSToolbox
osSetButtonControlText wPtr bPtr _ text tb
	#! tb = trace_n ("osSetButtonControlText") tb
	= SetCTitle bPtr (validateControlTitle text) tb

osSetButtonControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetButtonControlSelect wPtr bPtr clipRect select tb
	# tb = trace_n ("osSetButtonControlSelect",select) tb
//	# tb = HiliteControl bPtr (if select 0 255) tb
	# tb = appClipport wPtr clipRect (HiliteControl bPtr (if select 0 255)) tb
	= tb

osSetButtonControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetButtonControlShow wPtr bPtr clipRect show tb
	#! tb = trace_n ("osSetButtonControlShow: "+++toString show+++" "+++toString bPtr) tb
	| show
		= appClipport wPtr clipRect (ShowControl bPtr) tb
	= appClipport wPtr clipRect (HideControl bPtr) tb

osSetButtonControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetButtonControlPos _ (parent_x,parent_y) buttonPtr (x,y) _ update tb
	#! tb = trace_n ("osSetButtonControlPos") tb
	# tb = MoveControl buttonPtr h v tb
	= tb
where
	h = x //- parent_x
	v = y //- parent_y

osSetButtonControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetButtonControlSize _ _ buttonPtr _ size=:(w,h) update tb
	#! tb = trace_n ("osSetButtonControlSize") tb
	# tb = SizeControl buttonPtr w h tb
	= tb


//-- CustomButtonControl

osCreateCustomButtonControl :: !OSWindowPtr !(!Int,!Int) !Bool !Bool !(!Int,!Int) !(!Int,!Int) !OKorCANCEL !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateCustomButtonControl parentWindow parentPos show able (x,y) (w,h) okOrCancel tb
	# tb = trace_n "oswindow::osCreateCustomButtonControl unimplemented." tb
	= (0,tb)

osDestroyCustomButtonControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyCustomButtonControl wPtr tb
	# tb = trace_n ("osDestroyCustomButtonControl") tb
	= tb

osClipCustomButtonControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipCustomButtonControl _ parentPos area itemPos itemSize tb
	# tb = trace_n ("osClipCustomButtonControl") tb
	= oscliprectrgn parentPos area itemPos itemSize tb

osSetCustomButtonControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCustomButtonControlSelect _ cPtr _ select tb
	#! tb = trace_n ("osSetCustomButtonControlSelect") tb
	= tb

osSetCustomButtonControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCustomButtonControlShow wPtr cPtr itemRect clipRect show tb
	#! tb = trace_n ("osSetCustomButtonControlShow") tb
	| show
		= tb
	# tb = appClipport wPtr clipRect (InvalWindowRect wPtr (OSRect2Rect itemRect) o QEraseRect (OSRect2Rect itemRect)) tb
	= tb

osSetCustomButtonControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCustomButtonControlPos _ (parent_x,parent_y) cPtr (x,y) _ update tb
	#! tb = trace_n ("osSetCustomButtonControlPos") tb
	= tb

osSetCustomButtonControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCustomButtonControlSize _ _ cPtr _ size update tb
	#! tb = trace_n ("osSetCustomButtonControlSize") tb
	= tb

osCustomButtonControlHasOrigin	:== False

//-- CustomControl

osCreateCustomControl :: !OSWindowPtr !(!Int,!Int) !Bool !Bool !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSWindowPtr,!*OSToolbox)
osCreateCustomControl parentWindow parentPos show able (x,y) (w,h) tb
	# tb = trace_n "oswindow::osCreateCustomControl unimplemented."	tb
	= (0,tb)

osDestroyCustomControl :: !OSWindowPtr !*OSToolbox -> *OSToolbox
osDestroyCustomControl wPtr tb
	# tb = trace_n ("osDestroyCustomControl: nothing to do") tb
	= tb

osClipCustomControl :: !OSWindowPtr !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
osClipCustomControl _ parentPos area itemPos itemSize tb
	#! tb = trace_n ("osClipCustomControl: ") tb
	= oscliprectrgn parentPos area /*(0,0)*/itemPos itemSize tb

osSetCustomControlSelect :: !OSWindowPtr !OSWindowPtr !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCustomControlSelect _ cPtr _ select tb
	#! tb = trace_n ("osSetCustomControlSelect ") tb
	= tb

osSetCustomControlShow :: !OSWindowPtr !OSWindowPtr !OSRect !OSRect !Bool !*OSToolbox -> *OSToolbox
osSetCustomControlShow wPtr cPtr itemRect clipRect show tb
	#! tb = trace_n ("osSetCustomControlShow",show,itemRect,clipRect) tb
	| show
		= tb
	# tb = appClipport wPtr clipRect (InvalWindowRect wPtr (OSRect2Rect itemRect) o QEraseRect (OSRect2Rect itemRect)) tb
	= tb

osSetCustomControlPos :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCustomControlPos _ (parent_x,parent_y) customPtr (x,y) _ update tb
	#! tb = trace_n ("osSetCustomControlPos ") tb
	= tb

osSetCustomControlSize :: !OSWindowPtr !(!Int,!Int) !OSWindowPtr !(!Int,!Int) !(!Int,!Int) !Bool !*OSToolbox -> *OSToolbox
osSetCustomControlSize _ _ customPtr _ size update tb
	#! tb = trace_n ("osSetCustomControlSize ") tb
	= tb

osCustomControlHasOrigin		:== False

//-- common control utilities

osUpdateCommonControl area theControl tb
//	# (saveRgn,tb)	= QNewRgn tb
//	# (saveRgn,tb)	= QGetClip saveRgn tb
//	# tb			= QClipRect (OSRect2Rect area) tb
	# tb			= Draw1Control theControl tb
//	# tb			= QSetClip saveRgn tb
//	# tb			= QDisposeRgn saveRgn tb
	# tb = trace_n ("osUpdateCommonControl") tb
	= tb

oscliprectrgn :: !(!Int,!Int) !OSRect !(!Int,!Int) !(!Int,!Int) !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
oscliprectrgn parent_pos=:(parent_x,parent_y) rect (x,y) (w,h) tb
	# tb = trace_n ("cliprect: "+++toString (intersectRects area item)) tb
	= osnewrectrgn (intersectRects area item) tb
where
	area	= subVector (fromTuple parent_pos) rect
	x`		= x-parent_x
	y`		= y-parent_y
	item	= {rleft=x`,rtop=y`,rright=x`+w,rbottom=y`+h}

//-- DvA

/*
QDrawArrow :: !SelectState !Int !Int !*OSToolbox -> *OSToolbox
QDrawArrow select x y tb
	|	enabled select	= fillpolygon arrow base (QPenNormal tb)
						= QPenNormal (fillpolygon arrow base (QPenPat Gray tb))
where
	Gray = (1437226410,1437226410);

	base			= {x=x-16,y=y+6}
	arrow			= {polygon_shape=[{vx=12,vy=0},{vx= -6,vy=6}]}
	
	fillpolygon :: !Polygon !Point2 !*OSToolbox -> *OSToolbox
	fillpolygon {polygon_shape} base=:{x,y} tb
	#	(polyH,tb)	= QOpenPoly tb
		tb			= QMoveTo   x y tb
		tb			= drawshape x y polygon_shape tb
		tb			= QLineTo   x y tb
		tb			= QClosePoly polyH tb
		tb			= QPaintPoly polyH tb
		tb			= QKillPoly  polyH tb
	=	tb
	where
		drawshape :: !Int !Int ![Vector2] !*OSToolbox -> *OSToolbox
		drawshape x y [{vx,vy}:vs] tb
		=	drawshape vx vy vs (QLine vx vy tb)
		drawshape _ _ _ tb
		=	tb
*/
/*
TEGetItemRect :: !TEHandle !*OSToolbox -> (!Rect,!*OSToolbox)
TEGetItemRect hTE tb
	#	(tePtr,tb)			= LoadLong hTE tb
		(rect,tb)			= LoadRect` (tePtr+0) tb
	=	(rect,tb)
where
	LoadRect` :: !Ptr !*OSToolbox -> (!Rect,!*OSToolbox)
	LoadRect` ptr tb
		#	(top,   tb)	= LoadWord ptr		tb
			(left,  tb)	= LoadWord (ptr+2)	tb
			(bottom,tb)	= LoadWord (ptr+4)	tb
			(right, tb)	= LoadWord (ptr+6)	tb
		=	((left,top,right,bottom),tb)
*/

//-- DvA... for MacOS 8.5

import code from library "appear_library"

import memory, StdEnum

kControlBevelButtonMenuValueTag		=: "mval"
kControlBevelButtonMenuHandleTag	=: "mhnd"


//--

setDialogFont wPtr tb
	# (gPtr,tb)		= QGetPort tb
	# (oldfont,tb)	= GrafPtrGetFont gPtr tb
	# (ft,tb)		= osDialogfont tb
	  {osfontnumber=fontNr,osfontstyles=styles,osfontsize=size,osfontname=name}
	  				= osFontgetimp ft
	# tb			= GrafPtrSetFont (fontNr,fontstylestoid styles,size) tb
	= (oldfont,tb)

//	setClippedControlValue before calling SetCtlValue sets the clipping region of the window.
setClippedControlValue :: !OSWindowPtr !OSRect !ControlHandle !Int !*OSToolbox -> *OSToolbox
setClippedControlValue wPtr clipRect controlH x tb
= appClipport wPtr clipRect (SetCtlValue controlH x) tb

//	hiliteClippedControl before calling HiliteControl sets the clipping region of the window.
hiliteClippedControl :: !OSWindowPtr !OSRect !ControlHandle !Int !*OSToolbox -> *OSToolbox
hiliteClippedControl wPtr clipRect controlH partCode tb
= appClipport wPtr clipRect (HiliteControl controlH partCode) tb

//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r

/*	GrafPort access rules:
*/
accGrafport :: !OSWindowPtr !.(St *OSToolbox .x) !*OSToolbox -> (!.x, !*OSToolbox)
accGrafport wPtr f tb
	| wPtr == 0		= abort "osutil:accGrafport: called with nil wPtr"
	#	(port,tb)	= QGetPort tb
		tb			= SetPortWindowPort wPtr tb
		(x,tb)		= f tb
		tb			= QSetPort port tb
	=	(x,tb)

appGrafport :: !OSWindowPtr !.(*OSToolbox -> *OSToolbox) !*OSToolbox -> *OSToolbox
appGrafport wPtr f tb
	| wPtr == 0		= abort "osutil:appGrafport: called with nil wPtr"
	#	(port,tb)	= QGetPort tb
		tb			= SetPortWindowPort wPtr tb
		tb			= f tb
		tb			= QSetPort port tb
	=	tb

accClipport :: !OSWindowPtr !OSRect !.(St *OSToolbox .x) !*OSToolbox -> (!.x, !*OSToolbox)
accClipport wPtr clipRect f tb
	| wPtr == 0		= abort "osutil:accClipport: called with nil wPtr"
	# (port,rgn,tb)	= openClipDrawing wPtr tb
	# tb			= QClipRect (OSRect2Rect clipRect) tb
	# (x,tb)		= f tb
	# tb			= closeClipDrawing port rgn tb
	= (x,tb)
	
appClipport :: !OSWindowPtr !OSRect !.(*OSToolbox -> *OSToolbox) !*OSToolbox -> *OSToolbox
appClipport wPtr clipRect f tb
	| wPtr == 0		= abort "osutil:appClipport: called with nil wPtr"
	# (port,rgn,tb)	= openClipDrawing wPtr tb
	#! tb			= QClipRect (OSRect2Rect clipRect) tb
	# tb			= f tb
	= closeClipDrawing port rgn tb
	
//	openClipDrawing saves the current Grafport, sets the new Grafport, and saves its ClipRgn.
openClipDrawing :: !OSWindowPtr !*OSToolbox -> (!GrafPtr,!OSRgnHandle,!*OSToolbox)
openClipDrawing wPtr tb
#	(port,tb)	= QGetPort		tb
	tb			= SetPortWindowPort wPtr	tb
	(rgn, tb)	= QNewRgn		tb
	(rgn, tb)	= QGetClip rgn	tb
//	(font,tb)	= GrafPtrGetFont wPtr tb
=	(port,rgn,tb)

//	closeClipDrawing restores the ClipRgn, restores the Grafport, and disposes the ClipRgn.
closeClipDrawing :: !GrafPtr !OSRgnHandle !*OSToolbox -> *OSToolbox
closeClipDrawing port clipRgn tb
//#	tb	= GrafPtrSetFont font tb
#	tb	= QSetClip		clipRgn	tb
	tb	= QDisposeRgn	clipRgn	tb
	tb	= QSetPort		port	tb
=	tb

//====

//	Get the RgnHandle to visible region of a window (!do not dispose this handle!).

WindowGetVisRgn :: !OSWindowPtr !*OSToolbox -> (!OSRgnHandle,!*OSToolbox)
WindowGetVisRgn wPtr tb
	# (gp,tb)	= GetWindowPort wPtr tb
	# (rgn,tb)	= osnewrgn tb
	# tb		= GetPortVisibleRegion gp rgn tb
	= (rgn,tb)

//====

:: OSControlPtr 	:== OSWindowPtr
:: OSControlPart	:== Int
:: OSRegionCode		:== Int

import code from library "more85_library"

GetWindowBounds :: !OSWindowPtr !OSRegionCode !*OSToolbox -> (!Int,!OSRect,!*OSToolbox)
GetWindowBounds wPtr rgnCode tb
	# (err,tl,br,tb)	= GetWindowBounds wPtr rgnCode tb
	= (err,{rleft = tl bitand 0xFFFF, rtop = tl >> 16,rright = br bitand 0xFFFF, rbottom = br >> 16},tb)
where
	GetWindowBounds :: !OSWindowPtr !Int !*OSToolbox -> (!Int,!Int,!Int,!*OSToolbox)
	GetWindowBounds _ _ _ = code {
		ccall GetWindowBounds "II:III:I"
		}

MoveWindowStructure :: !OSWindowPtr !Int !Int !*OSToolbox -> *OSToolbox
MoveWindowStructure wPtr hGlobal vGlobal tb
	# hGlobal = hGlobal bitand 0xFFFF
	# vGlobal = vGlobal bitand 0xFFFF
	# hv	= (hGlobal << 16) bitor vGlobal
//	# (err,tb)	= MoveWindowStructure wPtr hv tb
	# (err,tb)	= MoveWindowStructure wPtr hGlobal vGlobal tb
	| err <> 0 = abort "MoveWindowStructure failed\n"
	= tb
where
/*
	MoveWindowStructure :: !OSWindowPtr !Int !*OSToolbox -> (!Int,!*OSToolbox)
	MoveWindowStructure _ _ _ = code {
		ccall MoveWindowStructure "II:I:I"
		}
*/
	MoveWindowStructure :: !OSWindowPtr !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
	MoveWindowStructure _ _ _ _ = code {
		ccall MoveWindowStructure "III:I:I"
		}

GetControlData :: !OSControlPtr !OSControlPart !String !*OSToolbox -> (!String,!*OSToolbox)
GetControlData cPtr cPart tag tb
	# iTag	= ((toInt tag.[0]) << 24) bitor ((toInt tag.[1]) << 16) bitor ((toInt tag.[2]) << 8) bitor ((toInt tag.[3]) << 0)
	# (err,iSize,tb)	= GetControlDataSize cPtr cPart iTag tb
	| err <> 0 = ("",tb)
	# iBuffer			= createArray iSize '@'
	# (err,oSize,tb)	= GetControlData cPtr cPart iTag iSize iBuffer tb
	| err <> 0 = ("",tb)
	= (iBuffer,tb)
where
	GetControlData :: !OSControlPtr !OSControlPart !Int !Int !String !*OSToolbox -> (!Int,!Int,!*OSToolbox)
	GetControlData _ _ _ _ _ _ = code {
		ccall GetControlData "PIIIIs:II:I"
		}

	GetControlDataSize :: !OSControlPtr !OSControlPart !Int !*OSToolbox -> (!Int,!Int,!*OSToolbox)
	GetControlDataSize _ _ _ _ = code {
		ccall GetControlDataSize "PIII:II:I"
		}
	
SetControlData :: !OSControlPtr !OSControlPart !String !String !*OSToolbox -> (!Int,!*OSToolbox)
SetControlData cPtr cPart tag data tb
	| size tag <> 4 = abort "oswindow:SetControlData:not a four char tag.\n"
	# iTag	= ((toInt tag.[0]) << 24) bitor ((toInt tag.[1]) << 16) bitor ((toInt tag.[2]) << 8) bitor ((toInt tag.[3]) << 0)
	# ssize	= size data
	= SetControlData cPtr cPart iTag ssize data tb
where
	SetControlData :: !OSControlPtr !Int !Int !Int !String !*OSToolbox -> (!Int,!*OSToolbox)
	SetControlData cPtr cPart tagName inSize inBuff tb = code {
		ccall SetControlData "PIIIIs:I:I"
		}

SetControlViewSize :: !OSControlPtr !Int !*OSToolbox -> *OSToolbox
SetControlViewSize cPtr viewSize tb = code {
	ccall SetControlViewSize "PII:V:I"
	}

SetCtlMin` :: !ControlHandle !Int !*OSToolbox -> *OSToolbox;
SetCtlMin` theControl minValue t = code (theControl=D0,minValue=D1,t=U)(z=Z){
	call	.SetControl32BitMinimum
	};

GetCtlMin` :: !ControlHandle !*OSToolbox -> (!Int,!*OSToolbox);
GetCtlMin` theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControl32BitMinimum
	};

SetCtlMax` :: !ControlHandle !Int !*OSToolbox -> *OSToolbox;
SetCtlMax` theControl maxValue t = code (theControl=D0,maxValue=D1,t=U)(z=Z){
	call	.SetControl32BitMaximum
	};

GetCtlMax` :: !ControlHandle !*OSToolbox -> (!Int,!*OSToolbox);
GetCtlMax` theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControl32BitMaximum
	};

SetCtlValue` :: !ControlHandle !Int !*OSToolbox -> *OSToolbox;
SetCtlValue` theControl theValue t = code (theControl=D0,theValue=D1,t=U)(z=Z){
	call	.SetControl32BitValue
	};

GetCtlValue` :: !ControlHandle !*OSToolbox -> (!Int,!*OSToolbox);
GetCtlValue` theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControl32BitValue
	};

InvalWindowRgn :: !WindowPtr !RgnHandle !*Toolbox -> *Toolbox;
InvalWindowRgn theWindow theRegion t = code (theWindow=D0,theRegion=D1,t=U)(z=Z){
	call	.InvalWindowRgn
	};

ValidWindowRgn :: !WindowPtr !RgnHandle !*Toolbox -> *Toolbox;
ValidWindowRgn theWindow theRegion t = code (theWindow=D0,theRegion=D1,t=U)(z=Z){
	call	.ValidWindowRgn
	};

SetCtlRef :: !ControlHandle !Int !*Toolbox -> *Toolbox;
SetCtlRef theControl theValue t = code (theControl=D0,theValue=D1,t=U)(z=Z){
	call	.SetControlReference
	};

GetCtlRef :: !ControlHandle !*Toolbox -> (!Int,!*Toolbox);
GetCtlRef theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControlReference
	};

GetControlPopupMenuID :: !OSControlPtr !*OSToolbox -> (!Int,!*OSToolbox)
GetControlPopupMenuID _ _ = code {
	ccall GetControlPopupMenuID "PI:I:I"
	}

GetControlPopupMenuHandle :: !OSControlPtr !*OSToolbox -> (!OSMenu,!*OSToolbox)
GetControlPopupMenuHandle _ _ = code {
	ccall GetControlPopupMenuHandle "PI:I:I"
	}

QInsetRect :: !(!Int,!Int,!Int,!Int) !*OSToolbox -> (!(!Int,!Int,!Int,!Int),!*OSToolbox)
QInsetRect (l,t,r,b) tb = code (l=W,t=W,r=W,b=W,tb=O0D0U)(l`=W,t`=W,r`=W,b`=W,zr=Z){
	call	.InsetRect
	}

CreateRootControl :: !Int !*OSToolbox -> (!Int,!Int,!*OSToolbox)
CreateRootControl _ _ = code {
	ccall CreateRootControl "PI:II:I"
	}

EmbedControl :: !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
EmbedControl _ _ _ = code {
	ccall EmbedControl "PII:I:I"
	}

IdleControls :: !OSWindowPtr !*OSToolbox -> *OSToolbox
IdleControls _ _ = code {
	ccall IdleControls "PI:V:I"
	}

IsValidControlHandle :: !Int !*OSToolbox -> (!Int,!*OSToolbox)
IsValidControlHandle _ _ = code {
	ccall IsValidControlHandle "PI:I:I"
	}

GetRootControl :: !OSWindowPtr !*OSToolbox -> (!Int,!OSControlPtr,!*OSToolbox)
GetRootControl _ _ = code {
	ccall GetRootControl "PI:II:I"
	}

SetKeyboardFocus :: !OSWindowPtr !OSControlPtr !Int !*OSToolbox -> (!Int,!*OSToolbox)
SetKeyboardFocus _ _ _ _ = code {
	ccall SetKeyboardFocus "PIII:I:I"
	}

GetKeyboardFocus :: !OSWindowPtr !*OSToolbox -> (!Int,!OSControlPtr,!*OSToolbox)
GetKeyboardFocus _ _ = code {
	ccall GetKeyboardFocus "PI:II:I"
	}

ClearKeyboardFocus :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
ClearKeyboardFocus _ _ = code {
	ccall ClearKeyboardFocus "PI:I:I"
	}

BeginAppModalStateForWindow :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
BeginAppModalStateForWindow _ _ = code {
	ccall BeginAppModalStateForWindow "PI:I:I"
	}

EndAppModalStateForWindow :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
EndAppModalStateForWindow _ _ = code {
	ccall EndAppModalStateForWindow "PI:I:I"
	}

SetWindowDefaultButton :: !OSWindowPtr !OSControlPtr !*OSToolbox -> (!Int,!*OSToolbox)
SetWindowDefaultButton _ _ _ = code {
	ccall SetWindowDefaultButton "PII:I:I"
	}

:: ThemeMetric	:== Int

GetThemeMetric :: !ThemeMetric !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
GetThemeMetric _ _ = code {
	ccall GetThemeMetric "PI:II:I"
	}

///////////

onOSX =: fst (runningCarbonOSX OSNewToolbox)

runningCarbonOSX tb
	# (err,res,tb)	= Gestalt "sysv" tb
	| err <> 0 = abort "Gestalt failed.\n"
	= (res >= 0x01000, tb)

Gestalt :: !String !*Int -> (!Int,!Int,!*Int)
Gestalt sSel tb
	| size sSel <> 4 = abort "Gestalt not called with four-char selector.\n"
	# iSel	= ((toInt sSel.[0]) << 24) bitor ((toInt sSel.[1]) << 16) bitor ((toInt sSel.[2]) << 8) bitor ((toInt sSel.[3]) << 0)
	= Gestalt iSel tb
where
	Gestalt :: !Int !*Int -> (!Int,!Int,!*Int)
	Gestalt _ _ = code {
		ccall Gestalt "PI:II:I"
		}
/*
import code from "keyfilter."

addReturnFilter :: !OSWindowPtr !*OSToolbox -> *OSToolbox
addReturnFilter editc tb = code {
	ccall addReturnFilter "I:V:I"
	}
*/
//import code from "keyfilter.xo"

:: ThemeFontID	:== Int

kThemePushButtonFont          :== 105

:: ThemeDrawState	:== Int
:: CFStringRef		:== Int
:: Boolean			:== Int
:: PointRef			:== Int
:: SInt16Ref		:== Int
:: OSStatus			:== Int

osGetThemeTextDimensions :: !String !*OSToolbox -> (!(!Int,!Int),!*OSToolbox)
osGetThemeTextDimensions s tb
	# (sref,tb)				= CFStringCreateWithCString 0 (s+++"\0") 0 tb
	# tb = DebugStr` ("CFStringCreateWithCString",sref) tb
	# (boundsref,err,tb)	= NewPtr 4 tb
	# tb = DebugStr` ("NewPtr4",err,boundsref) tb
	# (baseref,err,tb)		= NewPtr 2 tb
	# tb = DebugStr` ("NewPtr2",err,baseref) tb
	# (err,tb)				= GetThemeTextDimensions sref kThemePushButtonFont 0 0 boundsref baseref tb
	# tb = DebugStr` ("GetThemeTextDimensions",err) tb
	# (v,tb)				= LoadWord boundsref tb
	# (h,tb)				= LoadWord (boundsref+2) tb
	# tb					= DisposePtr boundsref tb
	# tb					= DisposePtr baseref tb
	# tb					= CFRelease sref tb
	# tb = DebugStr` ("osGetThemeTextDimensions",s,h,v) tb
	= ((h,v),tb)
	
GetThemeTextDimensions :: !CFStringRef !ThemeFontID !ThemeDrawState !Boolean !PointRef !SInt16Ref !*OSToolbox-> (!OSStatus,!*OSToolbox)
GetThemeTextDimensions _ _ _ _ _ _ _ = code {
	ccall GetThemeTextDimensions "IIIIII:I:I"
	}

//CFStringRef CFStringCreateWithCString(CFAllocatorRef alloc, const char *cStr, CFStringEncoding encoding);
CFStringCreateWithCString :: !Int !String !Int !*OSToolbox -> (!CFStringRef,!*OSToolbox)
CFStringCreateWithCString _ _ _ _ = code {
	ccall CFStringCreateWithCString "IsI:I:I"
	}

CFRelease :: !Int !*OSToolbox -> *OSToolbox
CFRelease _ _ = code {
	ccall CFRelease "I:V:I"
	}
/*
extern OSStatus 
GetThemeTextDimensions(
  CFStringRef      inString,
  ThemeFontID      inFontID,
  ThemeDrawState   inState,
  Boolean          inWrapToWidth,
  Point *          ioBounds,
  SInt16 *         outBaseline)                               AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER;
*/