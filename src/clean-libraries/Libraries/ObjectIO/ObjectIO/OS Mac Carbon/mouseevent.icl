implementation module mouseevent

/***
- need to incorporate input-tracking...
***/

import StdEnv//, StdIO
import StdPSt,StdControlAttribute,StdWindowAttribute
import windowaccess,windowhandle,deviceevents,iostate
import commondef
import ostypes, oswindow, ospicture
import osutil
//import controls,events,textedit
import inputtracking,keyfocus
from controls import InButton, InCheckBox, InUpButton, InDownButton, InPageUp, InPageDown, InThumb
from controls import GetCtlValue, TestControl
//from textedit import TEClick, :: TEHandle
import events
//import StdDebug, dodebug
//import dodebug
//trace_n msg f :== trace_n` msg f
trace_n _ f :== f
//from dodebug import trace_n`

/*
mapJust _ Nothing = Nothing
mapJust f (Just i) = Just (f i)
*/
//--

:: ControlMouseState
	= NothingState
	| SliderState SliderState
	| CustomState (Bool,OSRect,MouseState)
	| CustomButtonState OSRect
	| EditTextState OSRect
	| PopUpControlState (Index,[String],Point2,Size,Maybe OSWindowPtr,String)
	| PopUpEditState (Index,[String],Point2,Size,Maybe OSWindowPtr,String)
	| RadioControlState (Index,Index,OSWindowPtr)
	| CheckControlState MarkState
	| CompoundContentState (Bool,OSRect,MouseState)
	| CompoundScrollState (OSWindowPtr, OSRect, Direction, OSRect)

isCompoundContentState (CompoundContentState _) = True
isCompoundContentState _ = False

fromCompoundContentState (CompoundContentState s) = s

isCompoundScrollState (CompoundScrollState _) = True
isCompoundScrollState _ = False

fromCompoundScrollState (CompoundScrollState s) = s

isSliderState (SliderState _) = True
isSliderState _ = False

fromSliderState (SliderState s) = s

isCustomState (CustomState _) = True
isCustomState _ = False

fromCustomState (CustomState s) = s

isCustomButtonState (CustomButtonState _) = True
isCustomButtonState _ = False

fromCustomButtonState (CustomButtonState s) = s

isEditTextState (EditTextState _) = True
isEditTextState _ = False

fromEditTextState (EditTextState e) = e

isPopUpControlState (PopUpControlState _) = True
isPopUpControlState _ = False

fromPopUpControlState (PopUpControlState p) = p

isPopUpEditState (PopUpEditState _) = True
isPopUpEditState _ = False

fromPopUpEditState (PopUpEditState p) = p

isRadioControlState (RadioControlState _) = True
isRadioControlState _ = False

fromRadioControlState (RadioControlState r) = r

isCheckControlState (CheckControlState _) = True
isCheckControlState _ = False

fromCheckControlState (CheckControlState r) = r

//--
ioStGetDevice` device pState=:{io}
	# (a,b,io) = ioStGetDevice device io
	= ((a,b),{pState & io = io})
	
controlMouseDownIO :: !OSWindowMetrics !OSWindowPtr !Point2 !Int !Int !(WindowStateHandle (PSt .l)) !(WindowHandles (PSt .l)) !(PSt .l)
  -> (!Bool,!Maybe DeviceEvent,!WindowHandles (PSt .l),!WindowStateHandle (PSt .l),!(PSt .l))
controlMouseDownIO wMetrics wPtr mousePos when mods wsH=:{wshHandle=Just {wlsState=ls,wlsHandle=wls=:{whSize}}} windows ps
	# (done,returnEvent,windows,wsH1,ps1) = inWindowScrollBars wMetrics wsH ps
	| done
		= (done,returnEvent,windows,wsH1,ps1)
	= (done,returnEvent,windows3,wsH3,ps2)
	with
		windows1			= setWindowHandlesWindow wsH2 windows
		ioState1			= ioStSetDevice (WindowSystemState windows1) ps1.io
		pState1				= {ps1 & io=ioState1}
		(done,returnEvent,wsH2,pState2)		= controlMouseDownIO` mousePos wsH1 pState1

		((_,wDevice),ps2)		= ioStGetDevice` WindowDevice pState2
		windows2				= windowSystemStateGetWindowHandles wDevice
		(_,wsH3,windows3) = getWindowHandlesWindow (toWID wPtr) windows2
		

where
//	inWindowScrollBars :: !OSWindowMetrics !(WindowStateHandle (PSt .l)) !(IOSt .l) -> (!Bool,!(WindowStateHandle (PSt .l)),!(IOSt .l))
	inWindowScrollBars wMetrics wsH=:{wshHandle=Just {wlsState=ls,wlsHandle=wls=:{whKeyFocus=kf,whSize=size,whWindowInfo=WindowInfo wdata}}} ps
		| visHScroll && pointInRect mousePos hScrollRect
			= windowScrollbarMouseDownIO mousePos wPtr Horizontal wdata hScrollRect vScrollRect wsH windows ps
		| visVScroll && pointInRect mousePos vScrollRect
			= windowScrollbarMouseDownIO mousePos wPtr Vertical wdata hScrollRect vScrollRect wsH windows ps
		= (False,Nothing,windows,wsH,ps)
	where
		(visHScroll,visVScroll)		= osScrollbarsAreVisible wMetrics wDomain (toTuple size) (hasHScroll,hasVScroll)
		wDomain						= wdata.windowDomain
		hasHScroll					= isJust wdata.windowHScroll
		hasVScroll					= isJust wdata.windowVScroll
		wRect						= sizeToRect size
		hScrollRect					= osGetWindowHScrollRect wMetrics (hasHScroll,hasVScroll) wRect	// kan je ook uit ScrollInfo halen ?!
		vScrollRect					= osGetWindowVScrollRect wMetrics (hasHScroll,hasVScroll) wRect
//		cmEvent						= {cmePtr=wPtr,cmePos=mousePos,cmeWhen=when,cmeMods=toModifiers mods}
	inWindowScrollBars wMetrics wsH ps
		= (False,Nothing,windows,wsH,ps)
/*	
	windowScrollbarMouseDownIO mousePos wPtr direction {windowDomain,windowHScroll,windowVScroll} hScrollRect vScrollRect wsH windows ps
		# (upPart,ps)			= accPIO (accIOToolbox (trackClippedControl wPtr clipRect itemPtr mousePos)) ps
		| upPart <> 0
//			# state				= fromSliderState itemType
			# (thumb,ps)		= accPIO (accIOToolbox (GetCtlValue itemPtr)) ps
			# thumb`			= thumb //fromOSscrollbarRange (sliderMin, sliderMax) thumb
			# ps = trace_n (toString thumb+++".."+++toString thumb`) ps
			// moet nu thumb nog omzetten naar slider range....???
			# move				= case upPart of
									InUpButton		-> SliderDecSmall
									InDownButton	-> SliderIncSmall
									InPageUp		-> SliderDecLarge
									InPageDown		-> SliderIncLarge
									InThumb			-> SliderThumb thumb`
			# (wids,wsH)		= getWindowStateHandleWIDS wsH
			# controlInfo		= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
			= (True,Just controlInfo,windows,wsH,ps)
		= (True,Nothing,windows,wsH,ps)
	where
		hScroll	= (fromJust windowHScroll).scrollItemPtr
		vScroll	= (fromJust windowVScroll).scrollItemPtr
		clipRect = if (direction == Horizontal) hScrollRect vScrollRect
		itemPtr = if (direction == Horizontal) hScroll vScroll
		sliderMin = if (direction == Horizontal) windowDomain.rleft windowDomain.rtop
		sliderMax = if (direction == Horizontal) windowDomain.rright windowDomain.rbottom
*/
	time	= OSTime (when + 15)
	
	windowScrollbarMouseDownIO mousePos wPtr direction {windowDomain,windowHScroll,windowVScroll} hScrollRect vScrollRect wsH windows ps
		# (upPart,ps)			= accPIO (accIOToolbox (TestControl itemPtr mousePos.x mousePos.y)) ps
		= case upPart of
			0				-> (True,Nothing,windows,wsH,ps)
			InUpButton
							#  move			= SliderDecSmall
							#  (wids,wsH)	= getWindowStateHandleWIDS wsH
							#  returnEvent	= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
							#  ps			= startTrack wPtr time 0 itemPtr upPart direction False ps
							-> (True,Just returnEvent,windows,wsH,ps)
			InDownButton
							#  move			= SliderIncSmall
							#  (wids,wsH)	= getWindowStateHandleWIDS wsH
							#  returnEvent	= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
							#  ps			= startTrack wPtr time 0 itemPtr upPart direction False ps
							-> (True,Just returnEvent,windows,wsH,ps)
			InPageUp
							#  move			= SliderDecLarge
							#  (wids,wsH)	= getWindowStateHandleWIDS wsH
							#  returnEvent	= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
							#  ps			= startTrack wPtr time 0 itemPtr upPart direction False ps
							-> (True,Just returnEvent,windows,wsH,ps)
			InPageDown
							#  move			= SliderIncLarge
							#  (wids,wsH)	= getWindowStateHandleWIDS wsH
							#  returnEvent	= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
							#  ps			= startTrack wPtr time 0 itemPtr upPart direction False ps
							-> (True,Just returnEvent,windows,wsH,ps)
			InThumb			
							# (upPart,ps)	= accPIO (accIOToolbox (trackClippedControl wPtr clipRect itemPtr mousePos)) ps
							#  (thumb,ps)	= accPIO (accIOToolbox (GetCtlValue` itemPtr)) ps
							# domainRect	= rectToRectangle windowDomain
							# (sliderMin,sliderMax)
											= case direction of
												Horizontal	-> (domainRect.corner1.x, domainRect.corner2.x)
												_			-> (domainRect.corner1.y, domainRect.corner2.y)
							# thumb`		= fromOSscrollbarRange (sliderMin, sliderMax) thumb
							#  move			= SliderThumb thumb`
							#  (wids,wsH)	= getWindowStateHandleWIDS wsH
							#  returnEvent	= WindowScrollAction {wsaWIDS=wids,wsaSliderMove=move,wsaDirection=direction}
							-> (True,Just returnEvent,windows,wsH,ps)
			_				-> abort "mouseevent: unknown slider part..."
			
	where
		hScroll	= (fromJust windowHScroll).scrollItemPtr
		vScroll	= (fromJust windowVScroll).scrollItemPtr
		clipRect = if (direction == Horizontal) hScrollRect vScrollRect
		itemPtr = if (direction == Horizontal) hScroll vScroll
			
	controlMouseDownIO` pos wsH=:{wshHandle=Just wlsH=:{wlsState=ls,wlsHandle=wH=:{whAtts,whKind,whItems,whWindowInfo}}} ps
		# windowPen = case whKind of
						IsWindow	-> (getWindowInfoWindowData whWindowInfo).windowLook.lookPen
						IsDialog	-> fst (sharePen dialogPen)
						_			-> abort "window kind not supported"
		# (_,winselect,_)
				= getWindowKeyboardAtt (snd (cselect isWindowKeyboard (WindowKeyboard (const False) Unable undef) whAtts))
		# hasWindowKeyboard = Able == winselect
		# (_,(itemNr,itemPtr,itemContextPen,itemType),itemHs,(ls,ps))	= getControlsItemNr whItems (when,mods,wPtr,wMetrics) windowPen pos zero (ls,ps)
		# wsH = {wsH & wshHandle=Just {wlsState = ls,  wlsHandle={wH & whItems=itemHs}}}

		| itemNr <> 0
	//		# (updRect,ps)			= accIOToolbox (loadUpdateBBox wPtr) ps
	//		# clipRect				= IntersectRects updRect (SizeToRect whSize)
			# clipRect				= sizeToRect whSize
//			# itemRect				= posSizeToRect wItemPos wItemSize
//			# clipRect`				= intersectRects clipRect itemRect

			| isCompoundContentState itemType
				# (filtered,rect,mouseState)
										= fromCompoundContentState itemType
				| filtered
					// get current keyfocus control...
					# (kf,wsH)			= getWindowStateHandleKeyFocus wsH
					# (kfIt,kf)			= getCurrentFocusItem kf
					# (wsH,ps)			= changeFocus False kfIt (Just itemNr) wPtr clipRect wsH ps
					# wsH				= setWindowStateHandleKeyFocus kf wsH

					# (wids,wsH)		= getWindowStateHandleWIDS wsH
					# controlInfo		= case kfIt of
											Nothing	-> Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
											(Just kfItem) -> case kfItem == itemNr of
												True	-> Just (ControlMouseAction {cmWIDS=wids,cmItemNr=itemNr,cmItemPtr=itemPtr,cmMouseState=mouseState})
												_		// als oude kfItem loopt te tracken dan moeten we hem untracken...
														-> Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
					// en mousedown...etc

					# (inputTrack,ps)		= accPIO ioStGetInputTrack ps
					# inputTrack			= trackMouse wPtr itemNr inputTrack
					# ps					= appPIO (ioStSetInputTrack inputTrack) ps
					# ps					= trace_n "mouse-up in compound control" ps
					= (True,controlInfo,wsH,ps)
				# ps						= trace_n "mouse-up not in compound control" ps
				= (True,Nothing,wsH,ps)
			
			| isCompoundScrollState itemType
				# (scrollPtr,scrollRect,scrollDirection,contentRect) = fromCompoundScrollState itemType
//				# (upPart,ps)			= accPIO (accIOToolbox (trackClippedControl wPtr scrollRect scrollPtr mousePos)) ps
				# (upPart,ps)			= accPIO (accIOToolbox (TestControl scrollPtr mousePos.x mousePos.y)) ps
				# ps = trace_n ("windowevent:control tracking: "+++toString itemNr +++" " +++ toString upPart) ps
				// nee nee nee: nu produceren we control selectie terwijl we nu gewoon moeten gaan tracken...
				= case upPart of
					InUpButton
						#  move			= SliderDecSmall
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= CompoundScrollAction {csaWIDS=wids,csaItemNr=itemNr,csaItemPtr=scrollPtr,csaSliderMove=move,csaDirection=scrollDirection}
						#  ps			= startTrack wPtr time itemNr scrollPtr upPart scrollDirection False ps
						-> (True,Just returnEvent,wsH,ps)
					InDownButton
						#  move			= SliderIncSmall
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= CompoundScrollAction {csaWIDS=wids,csaItemNr=itemNr,csaItemPtr=scrollPtr,csaSliderMove=move,csaDirection=scrollDirection}
						#  ps			= startTrack wPtr time itemNr scrollPtr upPart scrollDirection False ps
						-> (True,Just returnEvent,wsH,ps)
					InPageUp
						#  move			= SliderDecLarge
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= CompoundScrollAction {csaWIDS=wids,csaItemNr=itemNr,csaItemPtr=scrollPtr,csaSliderMove=move,csaDirection=scrollDirection}
						#  ps			= startTrack wPtr time itemNr scrollPtr upPart scrollDirection False ps
						-> (True,Just returnEvent,wsH,ps)
					InPageDown
						#  move			= SliderIncLarge
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= CompoundScrollAction {csaWIDS=wids,csaItemNr=itemNr,csaItemPtr=scrollPtr,csaSliderMove=move,csaDirection=scrollDirection}
						#  ps			= startTrack wPtr time itemNr scrollPtr upPart scrollDirection False ps
						-> (True,Just returnEvent,wsH,ps)
					InThumb			
						# (upPart,ps)	= accPIO (accIOToolbox (trackClippedControl wPtr scrollRect scrollPtr mousePos)) ps
						#  (thumb,ps)	= accPIO (accIOToolbox (GetCtlValue` scrollPtr)) ps
						# domainRect	= rectToRectangle contentRect
						# (sliderMin,sliderMax)
										= case scrollDirection of
											Horizontal	-> (domainRect.corner1.x, domainRect.corner2.x)
											_			-> (domainRect.corner1.y, domainRect.corner2.y)
						# thumb`		= fromOSscrollbarRange (sliderMin, sliderMax) thumb
						#  move			= SliderThumb thumb`
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= CompoundScrollAction {csaWIDS=wids,csaItemNr=itemNr,csaItemPtr=scrollPtr,csaSliderMove=move,csaDirection=scrollDirection}
						-> (True,Just returnEvent,wsH,ps)
					_	-> (True,Nothing,wsH,ps)
			| isSliderState itemType	// it's a slider...
				# (upPart,ps)			= accPIO (accIOToolbox (TestControl itemPtr mousePos.x mousePos.y)) ps
				# state					= fromSliderState itemType
				= case upPart of
					InUpButton
						#  move			= SliderDecSmall
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= ControlSliderAction {cslWIDS=wids,cslItemNr=itemNr,cslItemPtr=itemPtr,cslSliderMove=move}
						#  ps			= startTrack wPtr time itemNr itemPtr upPart Horizontal True ps
						-> (True,Just returnEvent,wsH,ps)
					InDownButton
						#  move			= SliderIncSmall
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= ControlSliderAction {cslWIDS=wids,cslItemNr=itemNr,cslItemPtr=itemPtr,cslSliderMove=move}
						#  ps			= startTrack wPtr time itemNr itemPtr upPart Horizontal True ps
						-> (True,Just returnEvent,wsH,ps)
					InPageUp
						#  move			= SliderDecLarge
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= ControlSliderAction {cslWIDS=wids,cslItemNr=itemNr,cslItemPtr=itemPtr,cslSliderMove=move}
						#  ps			= startTrack wPtr time itemNr itemPtr upPart Horizontal True ps
						-> (True,Just returnEvent,wsH,ps)
					InPageDown
						#  move			= SliderIncLarge
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= ControlSliderAction {cslWIDS=wids,cslItemNr=itemNr,cslItemPtr=itemPtr,cslSliderMove=move}
						#  ps			= startTrack wPtr time itemNr itemPtr upPart Horizontal True ps
						-> (True,Just returnEvent,wsH,ps)
					InThumb			
						# (upPart,ps)	= accPIO (accIOToolbox (trackClippedControl wPtr clipRect itemPtr mousePos)) ps
						#  (thumb,ps)	= accPIO (accIOToolbox (GetCtlValue` itemPtr)) ps
						# thumb`		= fromOSscrollbarRange (state.sliderMin, state.sliderMax) thumb
//						# ps = trace_n (toString thumb+++".."+++toString thumb`) ps
						#  move			= SliderThumb thumb`
						#  (wids,wsH)	= getWindowStateHandleWIDS wsH
						#  returnEvent	= ControlSliderAction {cslWIDS=wids,cslItemNr=itemNr,cslItemPtr=itemPtr,cslSliderMove=move}
						-> (True,Just returnEvent,wsH,ps)
					_	-> (True,Nothing,wsH,ps)
			| isCustomState itemType
				# (filtered,itemRect,mouseState)	= fromCustomState itemType
//				# (selected,ps)						= accPIO (accIOToolbox (trackRectArea wPtr clipRect itemRect)) ps
//				| selected
				| filtered
					// get current keyfocus control...
					# (kf,wsH)			= getWindowStateHandleKeyFocus wsH
					# (kfIt,kf)			= getCurrentFocusItem kf
					# (wsH,ps)			= changeFocus False kfIt (Just itemNr) wPtr clipRect wsH ps
					# wsH				= setWindowStateHandleKeyFocus kf wsH
					
					# (wids,wsH)			= getWindowStateHandleWIDS wsH
					// hmmm, moeten we in modifiers niet de modifiers bij mouse-up zetten ipv die bij mouse-down?
//					# controlInfo	= Just (ControlSelection {csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr,csMoreData=0,csModifiers=toModifiers mods})
					# controlInfo			= Just (ControlMouseAction {cmWIDS=wids,cmItemNr=itemNr,cmItemPtr=itemPtr,cmMouseState=mouseState})
					# (inputTrack,ps)		= accPIO ioStGetInputTrack ps
					# inputTrack			= trackMouse wPtr itemNr inputTrack
					# ps					= trace_n ("trackMouse: "+++toString itemNr+++":"+++toString itemPtr) ps
					# ps					= appPIO (ioStSetInputTrack inputTrack) ps
					# ps					= trace_n "mouse-down in custom control" ps
					= (True,controlInfo,wsH,ps)
				# ps						= trace_n "mouse-down outside custom control" ps
				= (True,Nothing,wsH,ps)
			
			| isCustomButtonState itemType
				# itemRect			= fromCustomButtonState itemType
				# (selected,ps)		= accPIO (accIOToolbox (trackCustomButton wPtr clipRect itemRect)) ps
				| selected
					# (wids,wsH)			= getWindowStateHandleWIDS wsH
					// hmmm, moeten we in modifiers niet de modifiers bij mouse-up zetten ipv die bij mouse-down?
					# controlInfo	= Just (ControlSelection {csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr,csMoreData=0,csModifiers=toModifiers mods})
					# ps = trace_n "mouse-up in custom button" ps
					= (True,controlInfo,wsH,ps)
				# ps = trace_n "mouse-up outside custom button" ps
				= (True,Nothing,wsH,ps)
			
			| isEditTextState itemType
//				# shift				= (toModifiers mods).shiftDown
				# editHandle		= itemPtr
				// get current keyfocus control...
				# (kf,wsH)			= getWindowStateHandleKeyFocus wsH
				# (kfIt,kf)			= getCurrentFocusItem kf
				# (wsH,ps)			= changeFocus False kfIt (Just itemNr) wPtr clipRect wsH ps
				# wsH				= setWindowStateHandleKeyFocus kf wsH
//				setWindowStateHandleKeyFocus
				// if edit control deactivate
				// activate this one...
//				# ps				= appPIO (appIOToolbox (appClipport wPtr clipRect (TEClick (toTuple pos) shift editHandle /* o TEActivate editHandle*/))) ps
//				# ps				= appPIO (appIOToolbox (appClipport wPtr clipRect (snd o HandleControlClick editHandle (toTuple pos) mods))) ps
				# ps				= appPIO (appIOToolbox (snd o HandleControlClick wPtr editHandle (toTuple pos) mods)) ps
				# (wids,wsH)		= getWindowStateHandleWIDS wsH
				# controlInfo		= case kfIt of
										Nothing		-> Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
										Just kfItem	-> case kfItem == itemNr of
											True	-> Nothing	// ??? ControlMouseAction...
											_		-> Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
				// en mousedown...etc
				= (True,controlInfo,wsH,ps)
/*				# itemRect			= fromEditTextState itemType
				# (selected,ps)		= accPIO (accIOToolbox (trackRectArea wPtr clipRect itemRect)) ps
				| selected
					# (wids,wsH)			= getWindowStateHandleWIDS wsH
					// hmmm, moeten we in modifiers niet de modifiers bij mouse-up zetten ipv die bij mouse-down?
					# controlInfo	= Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
					# ps = trace_n "mouse-up in edit control" ps
					= (True,controlInfo,wsH,ps)
				# ps = trace_n "mouse-up outside edit control" ps
				= (True,Nothing,wsH,ps)
*/			
			| isPopUpEditState itemType
//				# shift				= (toModifiers mods).shiftDown
				# (puIndex,puTexts,wItemPos,wItemSize,editHandle,editTxt)
									= fromPopUpEditState itemType
				# editHandle		= fromJust editHandle
				// get current keyfocus control...
				# (kf,wsH)			= getWindowStateHandleKeyFocus wsH
				# (kfIt,kf)			= getCurrentFocusItem kf
				# (wsH,ps)			= changeFocus False kfIt (Just itemNr) wPtr clipRect wsH ps
				# wsH				= setWindowStateHandleKeyFocus kf wsH
//				# ps				= appPIO (appIOToolbox (appClipport wPtr clipRect (TEClick (toTuple pos) shift editHandle /* o TEActivate editHandle*/))) ps
				# ps				= appPIO (appIOToolbox (snd o HandleControlClick wPtr editHandle (toTuple pos) mods)) ps
				# (wids,wsH)		= getWindowStateHandleWIDS wsH
				# controlInfo		= Just (ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=itemNr,ckfItemPtr=itemPtr})
				// en mousedown...etc
				= (True,controlInfo,wsH,ps)
			| isPopUpControlState itemType
				// need to differentiate between arrow and body for editable popups,
				// already in controlHit testing...
				# (puIndex,puTexts,wItemPos,wItemSize,editPtr,editTxt)
									= fromPopUpControlState itemType
				# (newIndex,ps)		= accPIO (accIOToolbox(
										osHandlePopUpControlEvent itemPtr editPtr wPtr wItemPos wItemSize puIndex editTxt
										)) ps
				# ps = trace_n ("mouseevent",puIndex,newIndex) ps
				| newIndex  == 0 || newIndex == puIndex
					= (True,Nothing,wsH,ps)
//				# newText			= if (newIndex < 0)
//										(editTxt)
//										(puTexts!!(newIndex-1))
//				# ps				= appPIO (appIOToolbox(
//										osSetPopUpControl wPtr itemPtr editPtr clipRect
//											(posSizeToRect wItemPos wItemSize) puIndex newIndex newText True
//										)) ps 
				# (wids,wsH)		= getWindowStateHandleWIDS wsH
				# controlInfo		= Just (ControlSelection
										{csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr
										,csMoreData=newIndex,csModifiers = toModifiers mods
										})
				= (True,controlInfo,wsH,ps)
			
//			# ps = appPIO (appIOToolbox (settbpen wPtr itemContextPen)) ps
			# (upPart,ps)			= accPIO (accIOToolbox (trackClippedControl wPtr clipRect itemPtr mousePos)) ps
			# ps = trace_n ("windowevent`:control tracking: "+++toString itemNr +++" " +++ toString upPart) ps
			// nee nee nee: nu produceren we control selectie terwijl we nu gewoon moeten gaan tracken...
			| upPart <> 0
				# (wids,wsH)			= getWindowStateHandleWIDS wsH
				| isRadioControlState itemType
					# (newIndex,oldIndex,oldPtr)	= fromRadioControlState itemType
					# newPtr						= itemPtr
					# ps							= appPIO (appIOToolbox (osSetRadioControl wPtr oldPtr newPtr clipRect)) ps
					# controlInfo					= Just (ControlSelection {csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr,csMoreData=0,csModifiers=toModifiers mods})
					= (True,controlInfo,wsH,ps)
				| isCheckControlState itemType
					# checkState					= fromCheckControlState itemType
					# ps							= appPIO (appIOToolbox (osSetCheckControl wPtr itemPtr clipRect (if (marked checkState) False True))) ps
					# controlInfo					= Just (ControlSelection {csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr,csMoreData=0,csModifiers=toModifiers mods})
					= (True,controlInfo,wsH,ps)
				# controlInfo = Just (ControlSelection {csWIDS=wids,csItemNr=itemNr,csItemPtr=itemPtr,csMoreData=0,csModifiers=toModifiers mods})
				= (True,controlInfo,wsH,ps)
			= (True,Nothing,wsH,ps)
		| hasWindowKeyboard
			// get current keyfocus control...
			# (kf,wsH)			= getWindowStateHandleKeyFocus wsH
			# (kfIt,kf)			= getCurrentFocusItem kf
			# (wsH,ps)			= changeFocus False kfIt Nothing wPtr zero wsH ps
			# kf				= setNoFocusItem kf
			# wsH				= setWindowStateHandleKeyFocus kf wsH
			= (False,Nothing,wsH,ps)
		= (False,Nothing,wsH,ps)

getControlsItemNr
	:: [WElementHandle .ls (PSt .pst)] !(!Int,!Int,!OSWindowPtr,!OSWindowMetrics) !Pen !Point2 !Point2 (.ls,(PSt .pst))
	-> (!Bool,!(!Int,!Int,!Pen,!ControlMouseState),[WElementHandle .ls (PSt .pst)],(.ls,(PSt .pst)))
getControlsItemNr [itemH:itemHs] info=:(when,mods,wPtr,wMetrics) pen pos parent_pos ps
	# (found,result,itemH,ps)				= getControlItemNr itemH pen pos parent_pos ps
	| found
		= (found,result,[itemH:itemHs],ps)
	| otherwise
		# (found,result,itemHs,ps)			= getControlsItemNr itemHs info pen pos parent_pos ps
		= (found,result,[itemH:itemHs],ps)
where
	getControlItemNrFromwItems (WItemHandle itemH=:{wItems,wItemPos}) pen pos parent_pos ps
		# (found,result,items,ps)	= getControlsItemNr wItems info pen pos (movePoint wItemPos parent_pos) ps
		= (found,result,WItemHandle {itemH & wItems = items},ps)

	getControlItemNr
		:: (WElementHandle .ls (PSt .pst)) !Pen !Point2 !Point2 (.ls,(PSt .pst))
		-> (!Bool,!(!Int,!Int,!Pen,!ControlMouseState),(WElementHandle .ls (PSt .pst)),(.ls,(PSt .pst)))
	getControlItemNr (WItemHandle itemH=:{wItems,wItemAtts,wItemNr,wItemSelect,wItemInfo,wItemKind,wItemPtr,wItemPos,wItemSize}) pen pos parent_pos ps
		| not (itemH.wItemShow && wItemSelect) = (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
		= case wItemKind of
			IsButtonControl				-> case (controlHit pos (movePoint wItemPos parent_pos) wItemSize) of
											True	-> (True,(itemNr,wItemPtr,pen,NothingState),WItemHandle itemH,ps)
											False	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsCheckControl				-> case (checkHit pos checkInfo.checkItems item_pos) of
											(Just (checkPtr,checkMark))	-> (True,(itemNr,checkPtr,pen,CheckControlState checkMark),WItemHandle itemH,ps)
											Nothing	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsCompoundControl			-> getCompoundItemNr pos pen (WItemHandle itemH) parent_pos ps
			IsCustomButtonControl		-> case (controlHit pos item_pos wItemSize) of
											True	-> (True,(itemNr,wItemPtr,pen,CustomButtonState itemRect),WItemHandle itemH,ps)
											False	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsCustomControl				-> case (controlHit pos item_pos wItemSize && okCustomMouse) of
											True	# (ls,ps) = ps
													# (cMouse,ps) = accPIO (ioStButtonFreq when pos wPtr) ps
													# customState = MouseDown (pos - item_pos) (toModifiers mods) cMouse	// <- need to determine number down...
													# ps = (ls,ps)
													-> (True,(itemNr,wItemPtr,pen,CustomState (customFilter customState,itemRect,customState)),WItemHandle itemH,ps)
											False	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsEditControl				-> case (controlHit pos item_pos wItemSize) of
											True	-> (True,(itemNr,wItemPtr,pen,EditTextState itemRect),WItemHandle itemH,ps)
											False	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsLayoutControl				-> getControlItemNrFromwItems (WItemHandle itemH) pen pos parent_pos ps
			IsPopUpControl				
										#	popupPos = if (isJust popupInfo.popUpInfoEdit) {item_pos & x = item_pos.x + wItemSize.w - 20/*16*/} item_pos
										-> case (controlHit pos popupPos popupSiz) of
											True
												#	popupState		= PopUpControlState (popupIndex,popupTexts,item_pos,wItemSize,popupEditP,popupEditT)
												-> (True,(itemNr,wItemPtr,pen,popupState),WItemHandle itemH,ps)
											False	-> case (controlHit pos (movePoint popupPos` parent_pos) popupSiz`) of
												True
													#	popupState`		= PopUpEditState (popupIndex,popupTexts,item_pos,wItemSize,popupEditP,popupEditT)
													-> (True,(itemNr,wItemPtr,pen,popupState`),WItemHandle itemH,ps)
												False-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsRadioControl				-> case (radioHit pos radioInfo.radioItems item_pos) of
											(Just (radioPtr,newIndex))	-> (True,(itemNr,radioPtr,pen,RadioControlState (newIndex,oldIndex,oldPtr)),WItemHandle itemH,ps)
											Nothing	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsSliderControl				-> case (controlHit pos (movePoint wItemPos parent_pos) wItemSize) of
											True	-> (True,(itemNr,wItemPtr,pen,SliderState ((getWItemSliderInfo wItemInfo).sliderInfoState)),WItemHandle itemH,ps)
											False	-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsTextControl				-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			IsOtherControl _			-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)
			_							-> (False,(0,0,pen,NothingState),WItemHandle itemH,ps)

	where
		itemNr							= wItemNr
		item_pos = movePoint wItemPos parent_pos
		itemRect						= posSizeToRect item_pos wItemSize
		
		(customFilter,customSelect,customFunction)
								= getControlMouseAtt (snd (cselect isControlMouse dummyCustomMouse wItemAtts))
		dummyCustomMouse		= ControlMouse (const False) Unable undef
		okCustomMouse			= enabled customSelect

		popupInfo		= getWItemPopUpInfo wItemInfo
		popupIndex		= popupInfo.popUpInfoIndex
		popupTexts		= map fst (popupInfo.popUpInfoItems)
		popupEditP		= mapMaybe (\{popUpEditPtr}->popUpEditPtr) popupInfo.popUpInfoEdit
		popupEditT		= case popupInfo.popUpInfoEdit of
							(Just {popUpEditText}) -> popUpEditText
							_ -> ""
		popupSiz		= if (isJust popupInfo.popUpInfoEdit) {wItemSize & w = 20/*16*/} wItemSize
		popupPos`		= wItemPos
		popupSiz`		= if (isJust popupInfo.popUpInfoEdit) {wItemSize & w = wItemSize.w - 22} wItemSize
		
		radioInfo	= getWItemRadioInfo wItemInfo
		oldIndex	= radioInfo.radioIndex
		oldPtr		= ((radioInfo.radioItems)!!(oldIndex-1)).radioItemPtr
		
		radioHit pos [] parent_pos
			= Nothing
		radioHit pos [{radioItemPos,radioItemSize,radioItemPtr,radioItem=(_,radioIndex,_)}:rest] parent_pos
			| controlHit pos (movePoint radioItemPos parent_pos) radioItemSize
				= Just (radioItemPtr,radioIndex)
			= radioHit pos rest parent_pos
		
		checkInfo = getWItemCheckInfo wItemInfo
		
		checkHit pos [] parent_pos
			= Nothing
		checkHit pos [{checkItemPos,checkItemSize,checkItemPtr,checkItem=(_,_,checkMark,_)}:rest] parent_pos
			| controlHit pos (movePoint checkItemPos parent_pos) checkItemSize
				= Just (checkItemPtr,checkMark)
			= checkHit pos rest parent_pos
				
	getControlItemNr (WListLSHandle itemHs) pen cPtr parent_pos ps
		# (found,itemNr,itemHs,ps)		= getControlsItemNr itemHs (when,mods,wPtr,wMetrics) pen cPtr parent_pos ps
		= (found,itemNr,WListLSHandle itemHs,ps)
	getControlItemNr (WExtendLSHandle wExH=:{wExtendLS=extLS,wExtendItems=itemHs}) pen cPtr parent_pos (ls,ps)
		# (found,itemNr,itemHs,((extLS,ls),ps))		= getControlsItemNr itemHs (when,mods,wPtr,wMetrics) pen cPtr parent_pos ((extLS,ls),ps)
		= (found,itemNr,WExtendLSHandle {wExtendLS=extLS, wExtendItems=itemHs},(ls,ps))	
	getControlItemNr (WChangeLSHandle wChH=:{wChangeLS=chLS,wChangeItems=itemHs}) pen cPtr parent_pos (ls,ps)
		# (found,itemNr,itemHs,(chLS,ps))		= getControlsItemNr itemHs (when,mods,wPtr,wMetrics) pen cPtr parent_pos (chLS,ps)
		= (found,itemNr,WChangeLSHandle {wChangeLS = chLS, wChangeItems=itemHs},(ls,ps))

	controlHit mPos=:{x=mx,y=my} cPos=:{x=cx,y=cy} cSize=:{w=cw,h=ch}
		= cx < mx && mx < (cx + cw) && cy < my && my < (cy + ch)

	controlHit` mPos=:{x=mx,y=my} {rleft=cx,rtop=cy,rright=cx`,rbottom=cy`}
		= cx < mx && mx < cx` && cy < my && my < cy`

	getCompoundItemNr pos pen (WItemHandle itemH=:{wItems,wItemNr,wItemSelect,wItemInfo,wItemKind,wItemPtr,wItemPos,wItemSize,wItemAtts}) parent_pos (ls,ps)
//		#! wItemNr = trace_n ("CompoundRects",contentRect,hScrollRect,vScrollRect,visHScroll,visVScroll) wItemNr
		| visHScroll && hScrollHit
			= (True,(wItemNr,wItemPtr,compoundPen,CompoundScrollState (hPtr, hScrollRect, Horizontal, cContentRect)),WItemHandle itemH,(ls,ps))
		| visVScroll && vScrollHit
			= (True,(wItemNr,wItemPtr,compoundPen,CompoundScrollState (vPtr, vScrollRect, Vertical, cContentRect)),WItemHandle itemH,(ls,ps))
		# (found,result,itemH,(ls,ps)) =  getControlItemNrFromwItems (WItemHandle itemH) compoundPen pos parent_pos (ls,ps)
		| found			// one of the compound controls was selected
			= (found,result,itemH,(ls,ps))
		| contentHit && okControlMouse	// mouse-down in content region but not in control, mousefun enabled
			# itemRect			= contentRect
			# (bMouse,ps)		= accPIO (ioStButtonFreq when pos wPtr) ps
			# mstate			= MouseDown (pos - item_pos + compoundOrigin) (toModifiers mods) bMouse	// <- need to determine number down...
	//		#! ps				= compoundMouseIO mfilter mfunction mstate ps
			# bool = mfilter mstate
			= (True,(wItemNr,wItemPtr,compoundPen,CompoundContentState (bool,contentRect,mstate)), itemH,(ls,ps))
		= (False,(0,0,pen,NothingState), itemH,(ls,ps))
	where
		info			= getWItemCompoundInfo wItemInfo
		compoundLook	= info.compoundLookInfo.compoundLook
		compoundPen		= compoundLook.lookPen
		compoundOrigin	= info.compoundOrigin
		
		domainRect				= info.compoundDomain
		hasScrolls				= (isJust info.compoundHScroll,isJust info.compoundVScroll)
		visScrolls				= osScrollbarsAreVisible wMetrics domainRect (toTuple wItemSize) hasScrolls
		(visHScroll,visVScroll)	= visScrolls
		hPtr					= (fromJust info.compoundHScroll).scrollItemPtr
		vPtr					= (fromJust info.compoundVScroll).scrollItemPtr
		item_pos = movePoint wItemPos parent_pos
		contentRect				= /*getCompoundContentRect wMetrics visScrolls*/ (posSizeToRect item_pos wItemSize)
		hScrollRect				= osGetCompoundHScrollRect wMetrics visScrolls contentRect
		vScrollRect				= osGetCompoundVScrollRect wMetrics visScrolls contentRect
		cContentRect			= osGetCompoundContentRect wMetrics visScrolls contentRect
		hScrollHit				= controlHit` pos hScrollRect
		vScrollHit				= controlHit` pos vScrollRect
		contentHit				= controlHit` pos contentRect
		
		(mfilter,selectState,mfunction)
								= getControlMouseAtt (snd (cselect isControlMouse dummyControlMouse wItemAtts))
		dummyControlMouse		= ControlMouse (const False) Unable undef
		okControlMouse			= enabled selectState

getControlsItemNr _ _ pen _ parent_pos ps
	= (False,(0,0,pen,NothingState),[],ps)

//--

startTrack wPtr time itemNr itemPtr upPart direction isControl ps
	# (hilite,ps) = case upPart of
				InUpButton		-> (True,appPIO (appIOToolbox (appClipped wPtr (HiliteControl itemPtr upPart))) ps)
				InDownButton	-> (True,appPIO (appIOToolbox (appClipped wPtr (HiliteControl itemPtr upPart))) ps)
				_				-> (False,ps)
	// trackSlider...
	# (inputTrack,ps)	= accPIO ioStGetInputTrack ps
	# sinfo = {stiControl = itemPtr, stiPart = upPart, stiHilite = hilite, stiDirection = direction, stiIsControl = isControl}
	# inputTrack		= trackSlider wPtr itemNr sinfo inputTrack
	# ps				= appPIO (ioStSetInputTrack inputTrack) ps
	# ps = appPIO (appIOToolbox (startTracking time)) ps
	// ...trackSlider
	= ps

from controls import TrackControl, :: ControlHandle, HiliteControl
from quickdraw import QInvertRect

trackClippedControl :: !OSWindowPtr !OSRect !OSWindowPtr !Point2 !*OSToolbox -> (!Int,!*OSToolbox)
trackClippedControl wPtr clipRect controlH {x,y} tb
= accClipport wPtr clipRect (TrackControl controlH x y 0) tb

trackCustomButton :: !OSWindowPtr !OSRect !OSRect !*OSToolbox -> (!Bool,!*OSToolbox)
trackCustomButton wPtr clipRect itemRect tb
	= accClipport wPtr clipRect (track itemRect True o QInvertRect (OSRect2Rect itemRect)) tb
where
	track :: !OSRect !Bool !*OSToolbox -> (!Bool,!*OSToolbox)
	track itemRect selected tb
		# (x,y,tb)			= GetMouse tb
		# inside			= pointInRect {x=x,y=y} itemRect
		# (stillDown,tb)	= WaitMouseUp tb
		| stillDown && selected == inside
			= track itemRect inside tb
		| stillDown
			= track itemRect inside (QInvertRect (OSRect2Rect itemRect) tb)
		| not inside
			= (inside,tb)
		= (inside,QInvertRect (OSRect2Rect itemRect) tb)

//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r

//==

changeFocus :: !Bool !(Maybe Int) !(Maybe Int) !OSWindowPtr !OSRect !*(WindowStateHandle .a) !*(PSt .c) -> *(!*(WindowStateHandle .a),!*PSt .c)
changeFocus tabbing oldItemNr newItemNr wPtr clipRect wsH=:{wshHandle=Just wlsH=:{wlsState=ls,wlsHandle=wH=:{whItems}}} ps
	| oldItemNr == newItemNr = (wsH,ps)
	# (found,(ptr,knd),whItems)	= getFocuseableItemPtrAndKind` oldItemNr whItems
	# ps = case found of
			True	-> setFocus knd wPtr clipRect ptr False ps
			_		-> ps
	# (found,(ptr,knd),whItems)	= getFocuseableItemPtrAndKind` newItemNr whItems
	# ps = case found of
			True	-> setFocus knd wPtr clipRect ptr True ps
			_		-> ps
	# wsH				= {wsH & wshHandle=Just {wlsState = ls,  wlsHandle={wH & whItems=whItems}}}
	= (wsH,ps)
where
	setFocus IsEditControl wPtr clipRect itemPtr focus ps
		= appPIO (appIOToolbox set) ps
		where
			set tb
				# tb = osSetEditControlFocus wPtr itemPtr clipRect focus tb
				= tb
	setFocus IsCompoundControl wPtr clipRect itemPtr focus ps
		= ps	//appPIO (appIOToolbox (osSetCompoundControlFocus wPtr itemPtr clipRect focus)) ps
	setFocus IsCustomControl wPtr clipRect itemPtr focus ps
		= ps	//appPIO (appIOToolbox (osSetCustomControlFocus wPtr itemPtr clipRect focus)) ps
	setFocus IsPopUpControl wPtr clipRect itemPtr focus ps
		= appPIO (appIOToolbox (osSetPopUpControlFocus wPtr itemPtr clipRect focus)) ps

getFocuseableItemPtrAndKind` itemNr whItems
	= case itemNr of
		Nothing		-> (False,(OSNoWindowPtr,IsOtherControl "NoControl"),whItems)
		Just itemNr	-> getFocuseableItemPtrAndKind itemNr whItems
		
getFocuseableItemPtrAndKind :: !Int [WElementHandle .ls .ps] -> (!Bool,!(!OSWindowPtr,!ControlKind),[WElementHandle .ls .ps])
getFocuseableItemPtrAndKind itemNr []
	= (False,(OSNoWindowPtr,IsOtherControl "NoControl"),[])
getFocuseableItemPtrAndKind itemNr [itemH:itemHs]
	# (found,result,itemH)		= getControlItemPtrAndKindFromItem itemNr itemH
	| found
		= (found,result,[itemH:itemHs])
	| otherwise
		# (found,result,itemHs)	= getFocuseableItemPtrAndKind itemNr itemHs
		= (found,result,[itemH:itemHs])
where
	getControlItemPtrAndKindFromItems :: !Int (WElementHandle .ls .ps) -> (!Bool,!(!OSWindowPtr,!ControlKind),WElementHandle .ls .ps)
	getControlItemPtrAndKindFromItems itemNr (WItemHandle itemH=:{wItems})
		# (found,result,items)	= getFocuseableItemPtrAndKind itemNr wItems
		= (found,result,WItemHandle {itemH & wItems = items})

	getControlItemPtrAndKindFromItem :: !Int (WElementHandle .ls .ps) -> (!Bool,!(!OSWindowPtr,!ControlKind),(WElementHandle .ls .ps))
	getControlItemPtrAndKindFromItem itemNr (WItemHandle itemH=:{wItemNr,wItemKind,wItemPtr,wItemInfo})
		| wItemNr == itemNr	= case wItemKind of
			IsPopUpControl		-> (isJust (getWItemPopUpInfo wItemInfo).popUpInfoEdit,(wItemPtr,wItemKind),WItemHandle itemH)
			IsCompoundControl	-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			IsCustomControl		-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			IsEditControl		-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			_					-> (False,(OSNoWindowPtr,IsButtonControl),WItemHandle itemH)
		= case wItemKind of
			IsCompoundControl	-> getControlItemPtrAndKindFromItems itemNr (WItemHandle itemH)
			IsLayoutControl		-> getControlItemPtrAndKindFromItems itemNr (WItemHandle itemH)
			_					-> (False,(OSNoWindowPtr,IsButtonControl),WItemHandle itemH)

	getControlItemPtrAndKindFromItem itemNr (WListLSHandle itemHs)
		# (found,result,itemHs)		= getFocuseableItemPtrAndKind itemNr itemHs
		= (found,result,WListLSHandle itemHs)
	
	getControlItemPtrAndKindFromItem itemNr (WExtendLSHandle wExH=:{wExtendItems=itemHs})
		# (found,result,itemHs)		= getFocuseableItemPtrAndKind itemNr itemHs
		= (found,result,WExtendLSHandle {wExH & wExtendItems=itemHs})
	
	getControlItemPtrAndKindFromItem itemNr (WChangeLSHandle wChH=:{wChangeItems=itemHs})
		# (found,result,itemHs)		= getFocuseableItemPtrAndKind itemNr itemHs
		= (found,result,WChangeLSHandle {wChH & wChangeItems=itemHs})

//from quickdraw import SetPortWindowPort
HandleControlClick :: !OSWindowPtr !OSWindowPtr !(!Int,!Int) !Int !*OSToolbox -> (!Int,!*OSToolbox)
HandleControlClick wPtr cPtr (x,y) mods tb
//	# tb = SetPortWindowPort wPtr tb
//	# (gpos,tb)	= lGetMouse tb
//	# (lpos,tb) = lGlobalToLocal gpos tb
//	# (part,tb) = HandleControlClick cPtr gpos/*pos*/ 0/*mods*/ (-1) tb
	# (part,tb) = HandleControlClick cPtr pos mods (-1) tb
//	# tb = trace_n ("HandleControlClick",(cPtr,(x,y),pos`),(pos,gpos,lpos,(pos2tuple pos,pos2tuple gpos,pos2tuple lpos)),mods,part) tb
	# tb = trace_n ("HandleControlClick",(cPtr,(x,y),pos),mods,part) tb
	= (part,tb)
where
	pos		= y << 16 bitor x
//	pos` = ((pos >> 16) bitand 0xFFFF,pos bitand 0xFFFF)
//	pos2tuple pos = ((pos >> 16) bitand 0xFFFF,pos bitand 0xFFFF)
	HandleControlClick :: !OSWindowPtr !Int !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
	HandleControlClick _ _ _ _ _ = code {
		ccall HandleControlClick "PIIII:I:I"
		}
/*
lGetMouse :: !*OSToolbox -> (!Int,!*OSToolbox)
lGetMouse _ = code {
	ccall GetMouse "P:VI:I"
	}

lGlobalToLocal :: !Int !*OSToolbox -> (!Int,!*OSToolbox)
lGlobalToLocal g tb
	# r		= {g}
	# tb	= GlobalToLocal r tb
	= (r.[0],tb)
where
	GlobalToLocal :: !{#Int} !*OSToolbox -> *OSToolbox
	GlobalToLocal _ _ = code {
		ccall GlobalToLocal "PA:V:I"
		}
*/

GetCtlValue` :: !ControlHandle !*OSToolbox -> (!Int,!*OSToolbox);
GetCtlValue` theControl t = code (theControl=D0,t=U)(v=D0,z=Z){
	call	.GetControl32BitValue
	};

