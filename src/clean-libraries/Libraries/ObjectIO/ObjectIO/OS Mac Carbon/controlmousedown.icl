implementation module controlmousedown


import	StdInt, StdBool, StdFunc
import	controls
from	events				import	WaitMouseUp
import	commondef, controlclip, controlkeyfocus, controlmousedown1, keyfocus, windowaccess
from	windowaccess		import	getCompoundContentRect,getCompoundHScrollRect,getCompoundVScrollRect, 
									getWindowContentRect,  getWindowHScrollRect,  getWindowVScrollRect
//from	iostate				import	PSt, IOSt, 
//									getIOToolbox, setIOToolbox, appIOToolbox, accIOToolbox
from	StdPSt				import	accPIO, appPIO
from	StdTime				import	wait
from	StdSystem			import	ticksPerSecond

import oswindow,quickdraw,events,pointer,ossystem, iostate

/*	handleControlMouse checks whether the mousePos (in local coordinates of the indicated window wPtr)
	actually points to a visible, able control. 
	In case the mouse did point to such a control the event is handled completely and the Bool result is True.
	In case the mouse did not point to such a control the event is not handled and the Bool result is False.
	The Toolbox function can be applied to deactivate the control that currently has the keyboard focus (this
	is only necessary in case the Bool result is False).
*/
handleControlMouse :: !OSWindowPtr !Point2 !Int !Int !(WindowStateHandle (PSt .l)) !(WindowHandles (PSt .l)) !(PSt .l)
	-> (!Bool,!IdFun *OSToolbox,!PSt .l)
handleControlMouse wPtr mousePos when mods dsH=:{wshHandle = Just dlsH=:{/*wlsState=ls,*/wlsHandle=dH=:{whSize=size,whWindowInfo=winfo}}} windows pState
	# dsH = {dsH & wshHandle = Just {dlsH & wlsHandle = dH}}
	|	hasHScroll && PointInRect mousePos hScrollRect
		= handleHMouse dsH pState
	|	hasVScroll && PointInRect mousePos vScrollRect
		= handleVMouse dsH pState
	= handleCMouse dsH pState	
where
	handleHMouse dsH=:{wshHandle = Just dlsH=:{wlsState=ls,wlsHandle=dH=:{whKeyFocus = kf}}} pState
		=	(done,id,pState2)
		with
			wInfo1							= WindowInfo {wdata & windowHScroll = Just hScroll1}
			dsH1							= {dsH & wshHandle = Just {wlsState=ls1,wlsHandle={dH & whKeyFocus = kf1, whWindowInfo = wInfo1}}}
			windows1						= setWindowHandlesWindow dsH1 windows
			pState1							= appPIO (IOStSetDevice (WindowSystemState windows1)) pState
//			pState							= appPIO (IOStReplaceDialog dsH1) pState
			(done,kf1,hScroll1,(ls1,pState2))	= handleWindowSliderControlMouse cmEvent wRect id kf (fromJust opt_hScroll) hInfo (ls,pState1)
	handleVMouse dsH=:{wshHandle = Just dlsH=:{wlsState=ls,wlsHandle=dH=:{whKeyFocus = kf}}} pState
		=	(done,id,pState2)
		with
			wInfo1							= WindowInfo {wdata & windowVScroll = Just vScroll1}
			dsH1							= {dsH & wshHandle = Just {wlsState=ls1,wlsHandle={dH & whKeyFocus = kf1, whWindowInfo = wInfo1}}}
			windows1						= setWindowHandlesWindow dsH1 windows
			pState1							= appPIO (IOStSetDevice (WindowSystemState windows1)) pState
//			pState							= appPIO (IOStReplaceDialog dsH1) pState
			(done,kf1,vScroll1,(ls1,pState2))	= handleWindowSliderControlMouse cmEvent wRect id kf (fromJust opt_vScroll) vInfo (ls,pState1)
//	handleCMouse :: !(WindowStateHandle (PSt .l)) !(PSt .l) -> (!Bool,!IdFun *OSToolbox,!PSt .l)
	handleCMouse dsH=:{wshHandle = Just dlsH=:{wlsState=ls,wlsHandle=dH}} pState
		=	(done,if done id deactivate,pState2)
		with
			items					= dH.whItems
			ableContext				= dH.whSelect
			kf						= dH.whKeyFocus
			(kf1,deactivate,items1)		= getDeactivateKeyInputItem wPtr contentRect kf mousePos items
			dsH1					= {dsH & wshHandle = Just {wlsState=ls1,wlsHandle={dH & whItems=items2,whKeyFocus=kf2}}}
			windows1				= setWindowHandlesWindow dsH1 windows
			pState1					= appPIO (IOStSetDevice (WindowSystemState windows1)) pState
	//		pState					= appPIO (IOStReplaceDialog dsH1) pState
			(_,done,kf2,items2,(ls1,pState2))
									= handleMouseInControls cmEvent contentRect deactivate ableContext kf1 items1 (ls,pState1)

//	(size,pState1)				= accPIO (accIOToolbox (OsgetWindowSize wPtr)) pState
//	(size,pState)				= (dH.whSize, pState`)
	wRect						= SizeToRect size
//	kf							= dH.whKeyFocus
//	winfo						= dH.whWindowInfo
	wdata						= getWindowInfoWindowData winfo
	opt_hScroll					= wdata.windowHScroll
	opt_vScroll					= wdata.windowVScroll
	hasHScroll					= isJust opt_hScroll
	hasVScroll					= isJust opt_vScroll
	hInfo							= (wdata.windowDomain.rleft,wdata.windowOrigin.x,wdata.windowDomain.rright,(RectSize contentRect).w)
	vInfo							= (wdata.windowDomain.rtop,wdata.windowOrigin.y,wdata.windowDomain.rbottom,(RectSize contentRect).h)
	hScrollRect					= getWindowHScrollRect wMetrics (hasHScroll, hasVScroll) wRect
	vScrollRect					= getWindowVScrollRect wMetrics (hasHScroll, hasVScroll) wRect
	contentRect					= getWindowContentRect wMetrics (hasHScroll, hasVScroll) wRect
	cmEvent						= {cmePtr=wPtr,cmePos=mousePos,cmeWhen=when,cmeMods=mods}
	
	(wMetrics,_) = OSDefaultWindowMetrics OSNewToolbox // DvA: yuck! hebben ook IOStGetWindowMetrics???
	
	handleMouseInControls :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							 !Bool !*KeyFocus ![WElementHandle .ls (PSt .l)] (.ls,PSt .l)
				   -> (!Bool,!Bool,!*KeyFocus,![WElementHandle .ls (PSt .l)],(.ls,PSt .l))
	handleMouseInControls cmEvent clipRect deactivate ableContext kf [itemH:itemHs] ls_ps
	#	(inControl,done,kf,itemH,ls_ps)	= handleMouseInControl  cmEvent clipRect deactivate ableContext kf itemH ls_ps
	|	inControl
	=	(inControl,done,kf,[itemH:itemHs],ls_ps)
	#	(inControl,done,kf,itemHs,ls_ps)= handleMouseInControls cmEvent clipRect deactivate ableContext kf itemHs ls_ps
	=	(inControl,done,kf,[itemH:itemHs],ls_ps)
	where
		handleMouseInControl :: !ControlMouseEvent !Rect !(IdFun *OSToolbox)
								!Bool !*KeyFocus !(WElementHandle .ls (PSt .l)) (.ls,PSt .l)
					  -> (!Bool,!Bool,!*KeyFocus, !WElementHandle .ls (PSt .l), (.ls,PSt .l))
		handleMouseInControl cmEvent clipRect deactivate ableContext kf (WListLSHandle itemHs) ls_ps
		#	(inControl,done,kf,itemHs,ls_ps) = handleMouseInControls cmEvent clipRect deactivate ableContext kf itemHs ls_ps
		=	(inControl,done,kf,WListLSHandle itemHs,ls_ps)
		handleMouseInControl cmEvent clipRect deactivate ableContext kf (WExtendLSHandle {wExtendLS=exLS,wExtendItems}) (ls,ps)
		#	(inControl,done,kf,itemHs,((exLS,ls),ps)) = handleMouseInControls cmEvent clipRect deactivate ableContext kf wExtendItems ((exLS,ls),ps)
		=	(inControl,done,kf,WExtendLSHandle {wExtendLS=exLS,wExtendItems=itemHs},(ls,ps))
		handleMouseInControl cmEvent clipRect deactivate ableContext kf (WChangeLSHandle {wChangeLS=chLS,wChangeItems}) (ls,ps)
		#	(inControl,done,kf,itemHs,(chLS,ps)) = handleMouseInControls cmEvent clipRect deactivate ableContext kf wChangeItems (chLS,ps)
		=	(inControl,done,kf,WChangeLSHandle {wChangeLS=chLS,wChangeItems=itemHs},(ls,ps))
		handleMouseInControl cmEvent clipRect deactivate ableContext kf (WItemHandle itemH) ls_ps
		|	not itemH.wItemShow || not (PointInRect mousePos itemRect)
		=	(False,False,kf,WItemHandle itemH,ls_ps)
		|	not (ableContext && ableItem)
		=	(True,True,kf, WItemHandle itemH, ls_ps)
		=	(True,done,kf1,WItemHandle itemH1,ls_ps1)
			with
				(done,kf1,itemH1,ls_ps1)	= handleMouseInControl` cmEvent clipRect deactivate kf itemH ls_ps
		where
			ableItem			= itemH.wItemSelect
			itemPos				= itemH.wItemPos
			itemSize			= itemH.wItemSize
			itemRect			= PosSizeToRect itemPos itemSize
			
			handleMouseInControl` :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
									 !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
						  -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsRadioControl} ls_ps
			=	handleRadioControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsCheckControl} ls_ps
			=	handleCheckControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsPopUpControl} ls_ps
			=	handlePopUpControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsSliderControl} ls_ps
			=	handleSliderControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsEditControl} ls_ps
			=	handleEditControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsButtonControl} ls_ps
			=	handleButtonControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsCustomButtonControl} ls_ps
			=	handleCustomButtonControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsCustomControl} ls_ps
			=	handleCustomControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` cmEvent clipRect deactivate kf itemH=:{wItemKind=IsCompoundControl} ls_ps
			=	handleCompoundControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			handleMouseInControl` _ _ _ kf itemH ls_ps
			=	(False,kf,itemH,ls_ps)
			
			handleCompoundControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox)
											!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
								 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
			handleCompoundControlMouse cmEvent clipRect deactivate kf itemH ls_ps
			|	hasHScroll && PointInRect mousePos hScrollRect
			=	(done,kf1,itemH1,ls_ps1)
				with
					(done,kf1,hScroll1,ls_ps1)	= handleWindowSliderControlMouse cmEvent clipRect deactivate kf hScroll hInfo ls_ps
					itemH1						= {itemH & wItemInfo= (CompoundInfo {info & compoundHScroll=Just hScroll1})}
			|	hasVScroll && PointInRect mousePos vScrollRect
			=	(done,kf1,itemH1,ls_ps1)
				with
					(done,kf1,vScroll1,ls_ps1)	= handleWindowSliderControlMouse cmEvent clipRect deactivate kf vScroll vInfo ls_ps
					itemH1						= {itemH & wItemInfo= (CompoundInfo {info & compoundVScroll=Just vScroll1})} 
			#	(_,done,kf,items,(ls,ps))		= handleMouseInControls cmEvent clipRect1 deactivate True kf items ls_ps
				itemH							= {itemH & wItems=items}
			|	done
			=	(done,kf,itemH,(ls,ps))
			=	(True,setNoFocusItem kf,itemH,(ls,appPIO (appIOToolbox (checkDeactivate True deactivate)) ps))
			where
				mousePos						= cmEvent.cmePos
				items							= itemH.wItems
				itemPos							= itemH.wItemPos
				itemSize						= itemH.wItemSize
				info							= getWItemCompoundInfo itemH.wItemInfo
				hasHScroll						= isJust info.compoundHScroll
				hasVScroll						= isJust info.compoundVScroll
				hScroll							= fromJust info.compoundHScroll
				vScroll							= fromJust info.compoundVScroll
				hInfo							= (info.compoundDomain.rleft,info.compoundOrigin.x,info.compoundDomain.rright,(RectSize contentRect).w)
				vInfo							= (info.compoundDomain.rtop,info.compoundOrigin.y,info.compoundDomain.rbottom,(RectSize contentRect).h)
				itemRect						= PosSizeToRect itemPos itemSize
				hScrollRect						= IntersectRects (getCompoundHScrollRect wMetrics (hasHScroll, hasVScroll) itemRect) clipRect
				vScrollRect						= IntersectRects (getCompoundVScrollRect wMetrics (hasHScroll, hasVScroll) itemRect) clipRect
				contentRect						= getCompoundContentRect wMetrics (hasHScroll, hasVScroll) itemRect
				clipRect1						= IntersectRects contentRect clipRect
				
				(wMetrics,_) = OSDefaultWindowMetrics OSNewToolbox	//DvA yuck!
								
				checkDeactivate :: !Bool (IdFun *OSToolbox) !*OSToolbox -> *OSToolbox
				checkDeactivate hasId deactivate tb
				|	hasId						= deactivate tb
												= tb
	handleMouseInControls _ _ _ _ kf _ ls_ps
	=	(False,False,kf,[],ls_ps)


/*	Handle mouse event in SliderControl.	*/

::	TrackedControl
	=	{	trackWindow	:: OSWindowPtr		// The window in which the control resides
		,	trackHandle	:: ControlHandle	// The handle of the control
		,	trackPart	:: Int				// The part of the control being tracked
		}

handleSliderControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleSliderControlMouse cmEvent=:{cmePtr,cmePos={x,y}} clipRect _ kf itemH=:{wItemPtr} (ls,ps)
# itemH = {itemH & wItemPtr = wItemPtr}
#	(part,ps)				= accPIO (accIOToolbox (TestControl wItemPtr x y)) ps
	delay					= ticksPerSecond/10
	track					= {trackWindow=cmePtr,trackHandle=wItemPtr,trackPart=part}
|	part==InUpButton		= (True,kf,itemH,doHilitSlider clipRect delay track (sliderFun SliderDecSmall) (ls,ps))
|	part==InDownButton		= (True,kf,itemH,doHilitSlider clipRect delay track (sliderFun SliderIncSmall) (ls,ps))
|	part==InPageUp			= (True,kf,itemH,doSlider      clipRect delay track (sliderFun SliderDecLarge) (ls,ps))
|	part==InPageDown		= (True,kf,itemH,doSlider      clipRect delay track (sliderFun SliderIncLarge) (ls,ps))
|	part==InThumb			= (True,kf,itemH,moveSliderThumb cmePtr cmEvent.cmePos clipRect wItemPtr state sliderFun (ls,ps))
							with
								state	= info.sliderInfoState
							= (True,kf,itemH,(ls,ps))
where
	info					= getWItemSliderInfo itemH.wItemInfo
	sliderFun				= info.sliderInfoAction
	
//	doHilitSlider :: !Rect !Int !TrackedControl !(IOFunction (.ls,PSt .l .p)) (.ls,PSt .l .p) -> (.ls,PSt .l .p)
	doHilitSlider clipRect delay track=:{trackWindow,trackHandle,trackPart} f (ls,ps)
	#	ps					= appPIO (appIOToolbox (hiliteClippedControl trackWindow clipRect trackHandle trackPart)) ps
		(ls,ps)				= doSlider clipRect delay track f (ls,ps)
		ps					= appPIO (appIOToolbox (hiliteClippedControl trackWindow clipRect trackHandle 0)) ps
	=	(ls,ps)
	
//	doSlider :: !Rect !Int !TrackedControl !(IOFunction (.ls,PSt .l .p)) (.ls,PSt .l .p) -> (.ls,PSt .l .p)
	doSlider clipRect delay track=:{trackWindow} f (ls,pState)
	#	(ls,pState)			= f (ls,pState)
//		(found,pState)		= accPIO (IOStFindDialog (toWID trackWindow)) pState
//	|	not found
//	=	(ls,pState)
	#	(tb,pState)			= accPIO getIOToolbox pState
		tb					= wait delay tb
		(mouseDown,tb)		= WaitMouseUp tb
	|	not mouseDown
	=	(ls,appPIO (setIOToolbox tb) pState)
	#	(mPos,tb)			= InGrafport trackWindow GetMousePosition tb
		(part,tb)			= TestControl track.trackHandle mPos.x mPos.y tb
	|	part==track.trackPart
	=	doSlider clipRect 0 track f (ls,appPIO (setIOToolbox tb) pState)
	#	(stillTracking,tb)	= waitForMouseInControlPart track tb
		pState				= appPIO (setIOToolbox tb) pState
	|	stillTracking
	=	doSlider clipRect 0 track f (ls,pState)
	=	(ls,pState)
	where
		waitForMouseInControlPart :: !TrackedControl !*OSToolbox -> (!Bool,!*OSToolbox)
		waitForMouseInControlPart track=:{trackWindow,trackHandle,trackPart} tb
		#	(mouseDown,tb)	= WaitMouseUp tb
		|	not mouseDown
		=	(False,tb)
		#	(mPos,tb)		= InGrafport trackWindow GetMousePosition tb
			(part,tb)		= TestControl trackHandle mPos.x mPos.y tb
		|	part==trackPart
		=	(True,tb)
		=	waitForMouseInControlPart track tb
	
	moveSliderThumb :: !OSWindowPtr !Point2 !Rect !ControlHandle SliderState !(SliderAction *(.ls,PSt .l)) (.ls,PSt .l)
																										-> (.ls,PSt .l)
	moveSliderThumb wPtr pos clipRect controlH state sliderFun (ls,pState)
	#	(tb,pState)			= accPIO getIOToolbox pState
		(finalPart,tb)		= trackClippedControl wPtr clipRect controlH pos tb
	|	finalPart<>InThumb
	=	(ls,appPIO (setIOToolbox tb) pState)
	#	(thumb,tb)			= GetCtlValue controlH tb
		pState				= appPIO (setIOToolbox tb) pState
		thumb				= fromOSscrollbarRange (state.sliderMin, state.sliderMax) thumb
	=	sliderFun (SliderThumb thumb) (ls,pState)

//-0-

handleWindowSliderControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !ScrollInfo !(!Int,!Int,!Int,!Int) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !ScrollInfo, (.ls,PSt .l))
handleWindowSliderControlMouse cmEvent=:{cmePtr,cmePos={x,y}} clipRect _ kf itemH=:{scrollItemPtr} (min,origin,max,size) (ls,ps)
# itemH = {itemH & scrollItemPtr = scrollItemPtr}
#	(part,ps)				= accPIO (accIOToolbox (TestControl scrollItemPtr x y)) ps
	delay					= ticksPerSecond/10
	track					= {trackWindow=cmePtr,trackHandle=scrollItemPtr,trackPart=part}
|	part==InUpButton		= (True,kf,itemH,doHilitSlider clipRect delay track (sliderFun SliderDecSmall) (ls,ps))
|	part==InDownButton		= (True,kf,itemH,doHilitSlider clipRect delay track (sliderFun SliderIncSmall) (ls,ps))
|	part==InPageUp			= (True,kf,itemH,doSlider      clipRect delay track (sliderFun SliderDecLarge) (ls,ps))
|	part==InPageDown		= (True,kf,itemH,doSlider      clipRect delay track (sliderFun SliderIncLarge) (ls,ps))
|	part==InThumb			= (True,kf,itemH,moveSliderThumb cmePtr cmEvent.cmePos clipRect scrollItemPtr state sliderFun (ls,ps))
							= (True,kf,itemH,(ls,ps))
where
//	info					= itemH//getWItemSliderInfo itemH.wItemInfo
	state = {sliderMin = min,sliderMax = max,sliderThumb = origin}
	sliderFun move (ls,ps)
		# thumb = itemH.scrollFunction (RectToRectangle clipRect) state move
//		# tb = OSsetWindowSliderThumb wMetrics cmePtr isHorizontal thumb (maxx,maxy) redraw tb
		# ps = appPIO (appIOToolbox (SetCtlValue scrollItemPtr (toSliderRange min max thumb))) ps
		= (ls,ps)
	
//	doHilitSlider :: !Rect !Int !TrackedControl !(IOFunction (.ls,PSt .l .p)) (.ls,PSt .l .p) -> (.ls,PSt .l .p)
	doHilitSlider clipRect delay track=:{trackWindow,trackHandle,trackPart} f (ls,ps)
	#	ps					= appPIO (appIOToolbox (hiliteClippedControl trackWindow clipRect trackHandle trackPart)) ps
		(ls,ps)				= doSlider clipRect delay track f (ls,ps)
		ps					= appPIO (appIOToolbox (hiliteClippedControl trackWindow clipRect trackHandle 0)) ps
	=	(ls,ps)
	
//	doSlider :: !Rect !Int !TrackedControl !(IOFunction (.ls,PSt .l .p)) (.ls,PSt .l .p) -> (.ls,PSt .l .p)
	doSlider clipRect delay track=:{trackWindow} f (ls,pState)
	#	(ls,pState)			= f (ls,pState)
//		(found,pState)		= accPIO (IOStFindDialog (toWID trackWindow)) pState
//	|	not found
//	=	(ls,pState)
	#	(tb,pState)			= accPIO getIOToolbox pState
		tb					= wait delay tb
		(mouseDown,tb)		= WaitMouseUp tb
	|	not mouseDown
	=	(ls,appPIO (setIOToolbox tb) pState)
	#	(mPos,tb)			= InGrafport trackWindow GetMousePosition tb
		(part,tb)			= TestControl track.trackHandle mPos.x mPos.y tb
	|	part==track.trackPart
	=	doSlider clipRect 0 track f (ls,appPIO (setIOToolbox tb) pState)
	#	(stillTracking,tb)	= waitForMouseInControlPart track tb
		pState				= appPIO (setIOToolbox tb) pState
	|	stillTracking
	=	doSlider clipRect 0 track f (ls,pState)
	=	(ls,pState)
	where
		waitForMouseInControlPart :: !TrackedControl !*OSToolbox -> (!Bool,!*OSToolbox)
		waitForMouseInControlPart track=:{trackWindow,trackHandle,trackPart} tb
		#	(mouseDown,tb)	= WaitMouseUp tb
		|	not mouseDown
		=	(False,tb)
		#	(mPos,tb)		= InGrafport trackWindow GetMousePosition tb
			(part,tb)		= TestControl trackHandle mPos.x mPos.y tb
		|	part==trackPart
		=	(True,tb)
		=	waitForMouseInControlPart track tb
	
	moveSliderThumb :: !OSWindowPtr !Point2 !Rect !ControlHandle SliderState !(SliderAction *(.ls,PSt .l)) (.ls,PSt .l)
																										-> (.ls,PSt .l)
	moveSliderThumb wPtr pos clipRect controlH state sliderFun (ls,pState)
	#	(tb,pState)			= accPIO getIOToolbox pState
		(finalPart,tb)		= trackClippedControl wPtr clipRect controlH pos tb
	|	finalPart<>InThumb
	=	(ls,appPIO (setIOToolbox tb) pState)
	#	(thumb,tb)			= GetCtlValue controlH tb
		pState				= appPIO (setIOToolbox tb) pState
		thumb				= fromOSscrollbarRange (state.sliderMin, state.sliderMax) thumb
	=	sliderFun (SliderThumb thumb) (ls,pState)


//---

/*	GrafPort access rules:
*/
InGrafport :: !OSWindowPtr !(St *OSToolbox .x) !*OSToolbox -> (!.x, !*OSToolbox)
InGrafport wPtr f tb
#	(port,tb)	= QGetPort tb
	tb			= QSetPort wPtr tb
	(x,tb)		= f tb
	tb			= QSetPort port tb
=	(x,tb)

GlobalToLocal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
GlobalToLocal {x,y} tb
#	(x,y,tb)	= QGlobalToLocal x y tb
=	({x=x,y=y},tb)

/*	Mouse access functions:
*/
GetMousePosition :: !*OSToolbox -> (!Point2, !*OSToolbox)
GetMousePosition tb
#	(x,y,tb)	= GetMouse tb
=	({x=x,y=y},tb)

WaitForMouseUp :: !*OSToolbox -> *OSToolbox
WaitForMouseUp tb
#	(mouseDown,tb)	= WaitMouseUp tb
|	mouseDown		= WaitForMouseUp tb
					= tb

//	Determine the size of a window. 

//WindowGetSize :: !WindowPtr !*Toolbox -> (!Size,!*Toolbox)
WindowGetSize wPtr tb
	# rectPtr			= wPtr+16
	  (rect,tb)	= LoadRect rectPtr tb
	  (l,t, r,b) = toTuple4 rect
	= ({w=r-l, h=b-t},tb)

//InGrafport2 :: !WindowPtr !(IdFun *Toolbox) !*Toolbox -> *Toolbox
InGrafport2 wPtr f tb
#	(port,tb)	= QGetPort tb
	tb			= QSetPort wPtr tb
	tb			= f tb
	tb			= QSetPort port tb
=	tb

//LoadRect :: !Ptr !*OSToolbox -> (!Rect,!*OSToolbox)
LoadRect ptr tb
	#	(top,   tb)	= LoadWord ptr		tb
		(left,  tb)	= LoadWord (ptr+2)	tb
		(bottom,tb)	= LoadWord (ptr+4)	tb
		(right, tb)	= LoadWord (ptr+6)	tb
	=	({rleft=left,rtop=top,rright= right,rbottom=bottom},tb)
//import oswindow
toSliderRange min max thumb
	# (_,res,_,_) = toOSscrollbarRange (min,thumb,max) thumb
	= res
 