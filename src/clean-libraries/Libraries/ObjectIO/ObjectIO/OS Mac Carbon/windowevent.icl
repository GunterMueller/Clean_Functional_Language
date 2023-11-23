implementation module windowevent

/*	windowevent defines the DeviceEventFunction for the window device.
	This function is placed in a separate module because it is platform dependent.
*/


import	StdBool, StdFunc, StdList, StdMisc, StdTuple
from	ostypes				import	OSNoWindowPtr
import	commondef, controlcreate, deviceevents, iostate, windowaccess
from	StdControlAttribute	import	isControlKeyboard, getControlKeyboardAtt, 
									isControlMouse,    getControlMouseAtt, 
									isControlActivate, isControlDeactivate
from	StdWindowAttribute	import	isWindowKeyboard,  getWindowKeyboardAtt,
									isWindowMouse,     getWindowMouseAtt,
									isWindowCursor,    getWindowCursorAtt
import StdPSt
import menudevice
import osrgn,oswindow,ossystem
import osevent

import events,windows

import mouseevent, keyboardevent,osutil
import inputtracking, keyfocus

import windowcursor

from controls import InPageUp, InPageDown, InUpButton, InDownButton, HiliteControl, :: ControlHandle, TestControl

//import dodebug
trace_n _ g :== g

windoweventFatalError :: String String -> .x
windoweventFatalError function error
	= fatalError function "windowevent" error

/*	windowEvent filters the scheduler events that can be handled by this window device.
	For the time being no timer controls are added, so these events are ignored.
	windowEvent assumes that it is not applied to an empty IOSt.
*/

windowEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
windowEvent schedulerEvent pState
	# (hasDevice,pState)	= accPIO (ioStHasDevice WindowDevice) pState
	| not hasDevice			// This condition should never occur: WindowDevice must have been 'installed'
		= windoweventFatalError "WindowFunctions.dEvent" "could not retrieve WindowSystemState from IOSt"
	| otherwise
		= windowEvent schedulerEvent pState
where
	windowEvent :: !SchedulerEvent !(PSt .l) -> (!Bool,!Maybe DeviceEvent,!SchedulerEvent,!PSt .l)
	windowEvent schedulerEvent=:(ScheduleOSEvent osEvent=:(_,what,mess,_,_,_,_) _) pState=:{io=ioState}
		| not (isWindowOSEvent what)
			= (False,Nothing,schedulerEvent,pState)
		| otherwise
			# (_,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
			# (wMetrics, ioState)	= ioStGetOSWindowMetrics ioState
			  windows				= windowSystemStateGetWindowHandles wDevice
			# pState				= {pState & io=ioState}
			  (myEvent,replyToOS,deviceEvent,pState)
			  						= filterOSEvent wMetrics osEvent windows pState
			  schedulerEvent		= case replyToOS of
			  							(Just rosEvent) -> ScheduleOSEvent osEvent rosEvent
			  							_				-> schedulerEvent
			= (myEvent,deviceEvent,schedulerEvent,pState)
	where
//		isWindowOSEvent :: !Int -> Bool
		isWindowOSEvent UpdateEvent		= True
		isWindowOSEvent MouseDownEvent	= True
		isWindowOSEvent NullEvent		= True
		isWindowOSEvent MouseUpEvent	= True
		isWindowOSEvent KeyDownEvent	= True
		isWindowOSEvent KeyUpEvent		= True
		isWindowOSEvent AutoKeyEvent	= True
		isWindowOSEvent ActivateEvent	= True
		isWindowOSEvent OsEvent			= True
		isWindowOSEvent _				= False

	windowEvent schedulerEvent=:(ScheduleMsgEvent msgEvent) pState=:{io=ioState}
		# (ioId,ioState)		= ioStGetIOId ioState
		| ioId<>recLoc.rlIOId || recLoc.rlDevice<>WindowDevice
			= (False,Nothing,schedulerEvent,{pState & io=ioState})
		| otherwise
			# (_,wDevice,ioState)	= ioStGetDevice WindowDevice ioState
			  windows				= windowSystemStateGetWindowHandles wDevice
			  (found,windows)		= hasWindowHandlesWindow (toWID recLoc.rlParentId) windows
			  deviceEvent			= if found (Just (ReceiverEvent msgEvent)) Nothing
			# ioState				= ioStSetDevice (WindowSystemState windows) ioState
			# pState				= {pState & io=ioState}
			= (found,deviceEvent,schedulerEvent,pState)
	where
		recLoc						= getMsgEventRecLoc msgEvent
	
	windowEvent schedulerEvent pState
		= (False,Nothing,schedulerEvent,pState)

/*	filterOSEvent filters the OSEvents that can be handled by this window device.
*/
filterOSEvent :: !OSWindowMetrics !OSEvent !(WindowHandles (PSt .l)) !(PSt .l)
  -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,  !(PSt .l))

filterOSEvent wMetrics event=:(_,what,mess,when,h,v,mods) windows pState
	# (wPtr,pState)			= accPIO(accIOToolbox (\tb -> case what of
									MouseDownEvent
										# (_,wPtr,tb)	= FindWindow h v tb
										-> (wPtr,tb)
									MouseUpEvent		-> FrontWindow tb
									KeyDownEvent		-> FrontWindow tb
									KeyUpEvent			-> FrontWindow tb
									AutoKeyEvent		-> FrontWindow tb
									NullEvent			-> FrontWindow tb
									OsEvent				-> FrontWindow tb
									UpdateEvent			-> (mess, tb)
									ActivateEvent		-> (mess, tb)
									)) pState
	# (isMyWindow,wsH,windows)	= getWindowHandlesWindow (toWID wPtr) windows
	# (lastIO,	pState)			= accPIO ioStLastInteraction pState
//	# pState = case what of 
//				MouseDownEvent	-> trace_n ("filter",isMyWindow) pState
//				_				-> pState
//	# pState = trace_n ("filterOSEvent",what) pState
//	# pState = DebugStr ("filterOSEvent:"+++showEvent event) pState
//	| True = abort "windowevent:filterOSEvent\n"
	| not isMyWindow && lastIO
		# pState				= appPIO checkBeep pState
//*	Waarom gebeurde dit? cq waarom lopen we net te doen of we updates afhandelen die helemaal
//	niet voor ons zijn? Ging in ieder geval mis bij meerdere processen, i.e. bounce.
		# pState				= appPIO (appIOToolbox checkUpdate) pState
//*/
		# pState = trace_n ("windowevent:filterOSEvent: not my window & lastIO",wPtr) pState
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (False,Nothing,Nothing,pState)
	with
		
		checkUpdate :: !*OSToolbox -> *OSToolbox
		checkUpdate tb
			| what==UpdateEvent	= EndUpdate mess (BeginUpdate mess tb)
								= tb
		
		checkBeep :: !(IOSt .l) -> IOSt .l
		checkBeep ioState
			# (optModal,ioState)	= ioStGetIOIsModal ioState
			| isJust optModal && what==MouseDownEvent
								= beep ioState
								= ioState
	| not isMyWindow
		# pState = trace_n ("windowevent:filterOSEvent: not my window",wPtr,showEvent event) pState
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (False,Nothing,Nothing,pState)
	| what==NullEvent
//		#! pState = trace_n ("NullEvent",h,v,when) pState
		= windowNullIO wMetrics event wsH windows pState
	| what==OsEvent
		| (mess >> 24) bitand 0xFF == MouseMovedMessage
//			#! pState = trace_n ("MouseMovedEvent",h,v,when) pState
			= windowMouseMovedIO wMetrics event wsH windows pState
		// Suspend/Resume event skip and leave for processdevice
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (False,Nothing,Nothing,pState)
	| what==MouseDownEvent
		#! pState = trace_n ("MouseDownEvent",h,v,when) pState
		= windowMouseDownIO	wMetrics wsH event windows pState
	| what==MouseUpEvent
		#! pState = trace_n ("MouseUpEvent",h,v,when) pState
		= windowMouseUpIO event wsH windows pState
	| what==KeyDownEvent || what==KeyUpEvent || what==AutoKeyEvent
		#! pState = trace_n ("windowevent: KeyboardEvent") pState
		= windowKeyboardIO wsH event windows pState
	| what==UpdateEvent
		#! pState = trace_n ("windowevent: UpdateEvent") pState
		= windowUpdateIO wsH event windows pState
	| what==ActivateEvent
		# pState = trace_n ("ActivateEvent",wPtr) pState
		= windowActivateIO wsH event windows pState
	#! pState = trace_n ("windowevent: Cant get here?",showEvent event) pState
	# windows				= setWindowHandlesWindow wsH windows
	# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (False,Nothing,Nothing,pState)

/*	Handling an ActivateEvent for a window.
*/
windowActivateIO wsH=:{wshHandle = Just wlsH=:{wlsHandle={whWindowInfo,whAtts,whMode}}} event=:(_,_,wPtr,_,h,v,mods) windows pState
// /*
	# pState = trace_n ("ActivateEvent",wPtr,activated) pState

	# (found,activeModal,windows)		= getWindowHandlesActiveModalDialog windows
	  with
		getWindowHandlesActiveModalDialog :: !(WindowHandles .pst) -> *(!Bool,!Maybe WIDS,!WindowHandles .pst)
		getWindowHandlesActiveModalDialog wHs=:{whsWindows=[]}
			= (True,Nothing,wHs)
		getWindowHandlesActiveModalDialog wHs=:{whsWindows=[wsH:wsHs]}
			# (mode,wsH)	= getWindowStateHandleWindowMode wsH
			| isNothing mode
				= (False,Nothing,{wHs & whsWindows=[wsH:wsHs]})
			# mode = fromJust mode
			| mode<>Modal
				= (True,Nothing,{wHs & whsWindows=[wsH:wsHs]})
			| otherwise
				# (wids,wsH)= getWindowStateHandleWIDS wsH
				= (True,Just wids,{wHs & whsWindows=[wsH:wsHs]})

		getWindowStateHandleWindowMode :: !(WindowStateHandle .pst) -> *(!Maybe WindowMode,!WindowStateHandle .pst)
		getWindowStateHandleWindowMode wsH=:{wshHandle=Just {wlsHandle={whMode}}}
			= (Just whMode,wsH)
		getWindowStateHandleWindowMode wsH=:{wshHandle=Nothing}
			= (Nothing,wsH)

	| found && activated && (isJust activeModal) && ((fromJust activeModal).wPtr <> wPtr)
//		# (wids,wsH)			= getWindowStateHandleWIDS wsH					//@@
		# windows				= setWindowHandlesWindow wsH windows
//		# (windows, pState)		= activateFocus activated wids windows pState	//@@
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= trace_n ("a ha",wPtr) (True,Nothing,Nothing,pState)
//	| not found && mode == Modal

//	| True = abort "winActivate"
	# (isActiveProcess,pState)	= accPIO ioStIsActive pState
	# pState					= case isActiveProcess of
									True	-> pState
									False	# pState	= appPIO activateMenuSystem pState
											# pState	= appPIO (appIOToolbox (osSetCursorShape StandardCursor)) pState
											-> pState
// */
	# (active,wsH)				= getWindowStateHandleActive wsH
	| active == activated				// The window is already active or inactive, skip
		# (wids,wsH)			= getWindowStateHandleWIDS wsH					//@@
		# windows				= setWindowHandlesWindow wsH windows
		# (windows, pState)		= activateFocus activated wids windows pState	//@@
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("already in same state..") pState
		= (True,Nothing,Nothing,pState)
	| otherwise
		# (wids,wsH)			= getWindowStateHandleWIDS wsH
		# windows				= setWindowHandlesWindow wsH windows
		# (activeModal,windows)	= getWindowHandlesActiveModalDialog windows
		# (activeWindow,windows)= getWindowHandlesActiveWindow windows

		| activated
			= case activeWindow of
				(Just awids)	
								# (windows, pState)		= activateFocus False awids windows pState
								# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
								-> (True,Nothing,Just (WindowDeactivation awids),appPIO (bufferOSEvent event) pState)
				Nothing			-> case activeModal of
									(Just _)	
									//			#  windows				= setWindowHandlesWindow wsH windows
												# (windows, pState)		= activateFocus True wids windows pState
												# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
												// gaat dit niet fout als we actief worden door een geneste modale dialoog die sluit?
												-> (True,Nothing,Just (WindowInitialise wids),pState)
									_			
//												# (windows,ioState) = confirmcursorinfo h v wPtr cursor clipRgn windows pState.io
//												# pState				= {pState & io = ioState}
									//			#  windows				= setWindowHandlesWindow wsH windows
												# (windows, pState)		= activateFocus True wids windows pState
												# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
												-> trace_n ("WindowActivation",wPtr) (True,Nothing,Just (WindowActivation wids),pState)
		= case activeWindow of
			(Just awids)		// must be true and == wids ???
				# (windows, pState)		= activateFocus False wids windows pState
				# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
//				-> (True,Nothing,if (isJust activeModal) Nothing (Just (WindowDeactivation wids)),pState)
				-> (True,Nothing,if (isJust activeModal) Nothing (Just (WindowDeactivation wids)),pState)
			Nothing
				# pState = trace_n ("no active window..") pState
				# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
				-> (True,Nothing,Nothing,pState)
where
	activated					= mods bitand 1<>0
	
	cursor						= getCursor whAtts
	clipRgn						= case whWindowInfo of
									(WindowInfo {windowClip})	-> windowClip.clipRgn
									_							-> fst (osnewrgn 42)	// hack!

	getCursor :: ![WindowAttribute .ps] -> CursorShape
	getCursor atts
	#	opt_shape			= getcursorAtt atts
	|	isNothing opt_shape	= StandardCursor
							= fromJust opt_shape

	getcursorAtt :: ![WindowAttribute .ps] -> Maybe CursorShape
	getcursorAtt atts
	|	hasAtt				= Just (getWindowCursorAtt cursorAtt)
							= Nothing
	where
		(hasAtt,cursorAtt)	= cselect isWindowCursor (WindowCursor StandardCursor) atts
	

activateFocus :: !Bool !WIDS !*(WindowHandles .a) !*(PSt .b) -> *(!*(WindowHandles .a),!*(PSt .b))
activateFocus activate wids windows pState
	# (found,wsH,windows)	= getWindowHandlesWindow (toWID wids) windows
	# (keyFocus,wsH)		= getWindowStateHandleKeyFocus wsH
	#! numItems = length keyFocus.kfItems
	# pState = trace_n ("activateFocus!",activate,numItems) pState
	# (focusItem,keyFocus)	= getCurrentFocusItem keyFocus
	# (oldFocus,newFocus)	= case activate of
								True	-> (Nothing, focusItem)
								_		-> (focusItem, Nothing)
	# clipRect				= {rleft=0,rtop=0,rright=0,rbottom=0}
	# (wsH,pState)			= changeFocus False oldFocus newFocus wids.wPtr clipRect wsH pState
	# wsH					= setWindowStateHandleKeyFocus keyFocus wsH
	# windows				= setWindowHandlesWindow wsH windows
	= (windows, pState)
/*
initialFocus wids windows pState
	# (found,wsH,windows)	= getWindowHandlesWindow (toWID wids) windows
	# (keyFocus,wsH)		= getWindowStateHandleKeyFocus wsH
	# pState = trace_n ("initialFocus!") pState
	# (focusItem,keyFocus)	= getCurrentFocusItem keyFocus
	# (oldFocus,newFocus)	= (Nothing, focusItem)
	# clipRect				= {rleft=0,rtop=0,rright=0,rbottom=0}
	# (wsH,pState)			= changeFocus False oldFocus newFocus wids.wPtr clipRect wsH pState
	# wsH					= setWindowStateHandleKeyFocus keyFocus wsH
	# windows				= setWindowHandlesWindow wsH windows
	= (windows, pState)
*/

bufferOSEvent :: !OSEvent !(IOSt .l) -> IOSt .l
bufferOSEvent event ioState
	# (osEvents,ioState)	= ioStGetEvents ioState
	  osEvents				= osInsertEvents [event] osEvents
	= ioStSetEvents osEvents ioState


/*	Handling a MouseUpEvent for a window.
*/

windowMouseUpIO event=:(_,_,_,_,h,v,mods) wsH=:{wshIds=wshIds=:{wPtr}} windows pState
	# (active,pState)			= accPIO ioStIsActive pState
	# (returnEvent,wsH,pState)	= handleMouseUpEvent active h v mods wsH pState
	# windows					= setWindowHandlesWindow wsH windows
	# pState					= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (True, Nothing,returnEvent,pState)
where
	handleMouseUpEvent active h v mods wsH pState
	|	not active			= (Nothing,wsH,pState)
	# (inputTrack,pState)	= accPIO ioStGetInputTrack pState
	| isNothing inputTrack	= (Nothing,wsH,pState)
	# {itWindow,itControl,itKind={itkMouse}}
							= fromJust inputTrack
	# inputTrack			= untrackMouse inputTrack
	# (si,inputTrack)		= untrackSlider inputTrack
	# pState				= appPIO (ioStSetInputTrack inputTrack) pState
	# pState = appPIO (appIOToolbox stopTracking) pState
	# pState = case si of
				(Just {stiControl,stiPart=InUpButton})		-> appPIO (appIOToolbox (appClipped wPtr (HiliteControl stiControl 0))) pState
				(Just {stiControl,stiPart=InDownButton})	-> appPIO (appIOToolbox (appClipped wPtr (HiliteControl stiControl 0))) pState
				_								-> pState
	| not itkMouse
		= (Nothing,wsH,pState)
	| itWindow <> wPtr
		// generate MouseLost??? -> need way to find WIDS from wPtr
	//	# mState			= MouseLost
	//	# returnEvent		= WindowMouseAction {wmWIDS=toWIDS itWindow,wmMouseState= mState}
	//	= (Just returnEvent,wsH,pState)
		= (Nothing,wsH,pState)
	| itControl == 0		= handleMouseUpEvent` h v mods wsH pState
	= controlMouseUpEvent itControl h v mods wsH pState
	where
		// handleMouseMoveEvent` :: !Int !Int !Int !(DialogStateHandle (PSt .l .p)) !(PSt .l .p) -> PSt .l .p
		// en mouse move in control dan...?
		// controleren in input track...
		handleMouseUpEvent` h v mods wsH=:{wshIds,wshHandle=Just dlsH=:{wlsHandle=wlsH=:{whWindowInfo,whSelect,whAtts}}} pState
		|	not whSelect						= (Nothing,wsH,pState)
		|	not hasMouse || not (enabled select)= (Nothing,wsH,pState)
		|	not (filter mState)					= (Nothing,wsH,pState1)
												= (Just returnEvent,wsH,pState1)//pState3
		where
			whOrigin							= case whWindowInfo of
													(WindowInfo {windowOrigin})	-> windowOrigin
													_							-> zero
			(hasMouse,mouse)					= cselect isWindowMouse (WindowMouse (const False) Unable k`) whAtts
			(filter,select,_)					= getWindowMouseAtt mouse
			(localPos,pState1)					= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
			modifiers							= toModifiers mods
			mState								= MouseUp (whOrigin+localPos) modifiers
			returnEvent							= WindowMouseAction {wmWIDS=wshIds,wmMouseState= mState}
		
		controlMouseUpEvent itControl h v mods wsH=:{wshIds,wshHandle=Just dlsH=:{wlsHandle=wlsH=:{whWindowInfo,whSelect,whAtts,whItems}}} pState
			// find control
			// check mouse filter
			// return event
			# (found,(itemPtr,itemKind),whItems)
				= getItemPtrAndKind itControl whItems
			| trace_n ("controlMouseUpEvent",itControl,itemPtr) False = undef
			# wsH={wsH & wshHandle=Just {dlsH & wlsHandle={wlsH & whItems = whItems}}}
			# controlInfo
				= Just (ControlMouseAction {cmWIDS=wshIds,cmItemNr=itControl,cmItemPtr=itemPtr,cmMouseState=mouseState})
//			= (Nothing,wsH,pState)
			= (controlInfo,wsH,pState1)
		where
			whOrigin							= case whWindowInfo of
													(WindowInfo {windowOrigin})	-> windowOrigin
													_							-> zero
			mouseState							= MouseUp (whOrigin+localPos) modifiers
			(localPos,pState1)					= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
			modifiers							= toModifiers mods

getItemPtrAndKind :: !Int [WElementHandle .ls .ps] -> (!Bool,!(!OSWindowPtr,!ControlKind),[WElementHandle .ls .ps])
getItemPtrAndKind itemNr []
	= (False,(OSNoWindowPtr,IsOtherControl "NoControl"),[])
getItemPtrAndKind itemNr [itemH:itemHs]
	# (found,result,itemH)		= getItemPtrAndKindFromItem itemNr itemH
	| found
		= (found,result,[itemH:itemHs])
	| otherwise
		# (found,result,itemHs)	= getItemPtrAndKind itemNr itemHs
		= (found,result,[itemH:itemHs])
where
	getItemPtrAndKindFromItems :: !Int (WElementHandle .ls .ps) -> (!Bool,!(!OSWindowPtr,!ControlKind),WElementHandle .ls .ps)
	getItemPtrAndKindFromItems itemNr (WItemHandle itemH=:{wItems})
		# (found,result,items)	= getItemPtrAndKind itemNr wItems
		= (found,result,WItemHandle {itemH & wItems = items})

	getItemPtrAndKindFromItem :: !Int (WElementHandle .ls .ps) -> (!Bool,!(!OSWindowPtr,!ControlKind),(WElementHandle .ls .ps))
	getItemPtrAndKindFromItem itemNr (WItemHandle itemH=:{wItemNr,wItemKind,wItemPtr,wItemInfo})
		| wItemNr == itemNr	= case wItemKind of
			IsPopUpControl		-> (isJust (getWItemPopUpInfo wItemInfo).popUpInfoEdit,(wItemNr,wItemKind),WItemHandle itemH)
			IsCompoundControl	-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			IsCustomControl		-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			IsEditControl		-> (True,(wItemPtr,wItemKind),WItemHandle itemH)
			_					-> (False,(OSNoWindowPtr,IsButtonControl),WItemHandle itemH)
		= case wItemKind of
			IsCompoundControl	-> getItemPtrAndKindFromItems itemNr (WItemHandle itemH)
			IsLayoutControl		-> getItemPtrAndKindFromItems itemNr (WItemHandle itemH)
			_					-> (False,(OSNoWindowPtr,IsButtonControl),WItemHandle itemH)

	getItemPtrAndKindFromItem itemNr (WListLSHandle itemHs)
		# (found,result,itemHs)		= getItemPtrAndKind itemNr itemHs
		= (found,result,WListLSHandle itemHs)
	
	getItemPtrAndKindFromItem itemNr (WExtendLSHandle wExH=:{wExtendItems=itemHs})
		# (found,result,itemHs)		= getItemPtrAndKind itemNr itemHs
		= (found,result,WExtendLSHandle {wExH & wExtendItems=itemHs})
	
	getItemPtrAndKindFromItem itemNr (WChangeLSHandle wChH=:{wChangeItems=itemHs})
		# (found,result,itemHs)		= getItemPtrAndKind itemNr itemHs
		= (found,result,WChangeLSHandle {wChH & wChangeItems=itemHs})


/*	Handling a NullEvent for a window.
*/
//windowNullIO :: !OSWindowMetrics !Event !(PSt .l .p) -> PSt .l .p
windowNullIO wMetrics event=:(_,_,_,when,h,v,mods) wsH=:{wshIds=wshIds=:{wPtr}} windows pState
	#	(active,ioState)		= ioStIsActive pState.io
//		(windows,ioState)		= checkcursorinfo h v wPtr windows ioState			// in windowcursor
		(wsH,ioState)			= checkcaretblink wMetrics active wsH ioState
		pState					= {pState & io=ioState}
	//	pState					= handleASyncWindowReceivers pState
		(returnEvent,wsH,pState)= handleMouseMoveEvent True active h v when mods wsH pState
	# windows				= setWindowHandlesWindow wsH windows
	# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (True, Nothing,returnEvent,pState)

windowMouseMovedIO wMetrics event=:(_,_,_,when,h,v,mods) wsH=:{wshIds=wshIds=:{wPtr}} windows pState
	#	(active,ioState)		= ioStIsActive pState.io
//		(windows,ioState)		= checkcursorinfo h v wPtr windows ioState			// in windowcursor
		(wsH,ioState)			= checkcaretblink wMetrics active wsH ioState
		pState					= {pState & io=ioState}
	//	pState					= handleASyncWindowReceivers pState
		(returnEvent,wsH,pState)= handleMouseMoveEvent False active h v when mods wsH pState
	# windows				= setWindowHandlesWindow wsH windows
	# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (True, Nothing,returnEvent,pState)

//	handleMouseMoveEvent :: !Bool !Int !Int !Int !(PSt .l) -> PSt .l
handleMouseMoveEvent isNull active h v when mods wsH=:{wshIds=wshIds=:{wPtr}} pState
	|	not active			= (Nothing,wsH,pState)
	# pState = trace_n ("handleMouseMoveEvent",isNull) pState
	# (inputTrack,pState)	= accPIO ioStGetInputTrack pState
	| isNothing inputTrack
		| isNull
			# pState			= appPIO (ioStSetInputTrack inputTrack) pState
			= (Nothing,wsH,pState)
		= handleMouseMoveEvent` h v mods wsH pState
	# inputTrack			= fromJust inputTrack
	# {itWindow,itControl,itKind={itkMouse,itkSlider}}
							= inputTrack
	| not (itkMouse || isJust itkSlider)
		| isNull
			# pState			= appPIO (ioStSetInputTrack (Just inputTrack)) pState
			= (Nothing,wsH,pState)
		= handleMouseMoveEvent` h v mods wsH pState
	| itWindow <> wPtr
		// generate MouseLost??? -> need way to find WIDS from wPtr
		# inputTrack			= untrackMouse (Just inputTrack)
		# (sti,inputTrack)		= untrackSlider inputTrack
		# pState				= appPIO (ioStSetInputTrack inputTrack) pState
		# pState = case sti of
					(Just {stiControl,stiPart=InUpButton})
						-> appPIO (appIOToolbox (appClipped wPtr (HiliteControl stiControl 0))) pState
					(Just {stiControl,stiPart=InDownButton})
						-> appPIO (appIOToolbox (appClipped wPtr (HiliteControl stiControl 0))) pState
					_	-> pState
		| not itkMouse
			= (Nothing,wsH,pState)
//		# mState			= MouseLost
//		# returnEvent		= WindowMouseAction {wmWIDS=toWIDS itWindow,wmMouseState= mState}
//		= (Just returnEvent,wsH,pState)
		= (Nothing,wsH,pState)
	| itControl == 0			// in window...
		# sti = itkSlider
		| isJust sti			// tracking window slider
			// add timing checks... => SHOULD ONLY BE DONE IFNULL...
			# (itkTime,pState)	= accPIO (accIOToolbox loadTracking) pState
			| isNull && (when - kTiming) <= itkTime
				= trace_n ("timingCheck not yet") (Nothing,wsH,pState)
			// regular handling...
			# sti				= fromJust sti
			# ({x,y},pState)	= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
			# (part,pState)		= accPIO (accIOToolbox (TestControl sti.stiControl x y)) pState
			# rEvent = case sti of
				({stiControl,stiPart=InUpButton,stiDirection})
					-> if (part==InUpButton)
						(Just (WindowScrollAction {wsaWIDS = wshIds, wsaSliderMove = SliderDecSmall, wsaDirection = stiDirection}))
						Nothing
				({stiControl,stiPart=InDownButton,stiDirection})
					-> if (part==InDownButton)
						(Just (WindowScrollAction {wsaWIDS = wshIds, wsaSliderMove = SliderIncSmall, wsaDirection = stiDirection}))
						Nothing
				({stiControl,stiPart=InPageUp,stiDirection})
					-> if (part==InPageUp)
						(Just (WindowScrollAction {wsaWIDS = wshIds, wsaSliderMove = SliderDecLarge, wsaDirection = stiDirection}))
						Nothing
				({stiControl,stiPart=InPageDown,stiDirection})
					-> if (part==InPageDown)
						(Just (WindowScrollAction {wsaWIDS = wshIds, wsaSliderMove = SliderIncLarge, wsaDirection = stiDirection}))
						Nothing
				_	-> Nothing
			# (sti,pState)			= case sti.stiPart of
				InUpButton
					# inside	= part == InUpButton
					# part`		= if inside part 0
					| inside == sti.stiHilite
						-> (sti,pState)
					-> ({sti & stiHilite = inside},appPIO (appIOToolbox (appClipped wPtr (HiliteControl sti.stiControl part`))) pState)
				InDownButton
					# inside	= part == InDownButton
					# part`		= if inside part 0
					| inside == sti.stiHilite
						-> (sti,pState)
					-> ({sti & stiHilite = inside},appPIO (appIOToolbox (appClipped wPtr (HiliteControl sti.stiControl part`))) pState)
				_	-> (sti,pState)
			# inputTrack			= Just {inputTrack & itKind.itkSlider = Just sti}
			# pState = appPIO (appIOToolbox (startTracking (OSTime when))) pState
			# pState				= appPIO (ioStSetInputTrack inputTrack) pState
			= (rEvent,wsH,pState)
		= handleMouseDragEvent h v mods wsH pState
	| isJust itkSlider
		// add timing checks...
		# (itkTime,pState)	= accPIO (accIOToolbox loadTracking) pState
		| isNull && (when - kTiming) <= itkTime
			= (Nothing,wsH,pState)
		// regular handling...
		# sti = fromJust itkSlider
		# ({x,y},pState)	= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
		# (part,pState)		= accPIO (accIOToolbox (TestControl sti.stiControl x y)) pState
		# rEvent = case sti.stiIsControl of
			True ->
				case sti of
				({stiControl,stiPart=InUpButton,stiDirection})
					-> if (part==InUpButton)
						(Just (ControlSliderAction {cslWIDS = wshIds, cslSliderMove = SliderDecSmall, cslItemNr = itControl, cslItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InDownButton,stiDirection})
					-> if (part==InDownButton)
						(Just (ControlSliderAction {cslWIDS = wshIds, cslSliderMove = SliderIncSmall, cslItemNr = itControl, cslItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InPageUp,stiDirection})
					-> if (part==InPageUp)
						(Just (ControlSliderAction {cslWIDS = wshIds, cslSliderMove = SliderDecLarge, cslItemNr = itControl, cslItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InPageDown,stiDirection})
					-> if (part==InPageDown)
						(Just (ControlSliderAction {cslWIDS = wshIds, cslSliderMove = SliderIncLarge, cslItemNr = itControl, cslItemPtr = stiControl}))
						Nothing
				_	-> Nothing
			False ->
				case sti of
				({stiControl,stiPart=InUpButton,stiDirection})
					-> if (part==InUpButton)
						(Just (CompoundScrollAction {csaWIDS = wshIds, csaSliderMove = SliderDecSmall, csaDirection = stiDirection, csaItemNr = itControl, csaItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InDownButton,stiDirection})
					-> if (part==InDownButton)
						(Just (CompoundScrollAction {csaWIDS = wshIds, csaSliderMove = SliderIncSmall, csaDirection = stiDirection, csaItemNr = itControl, csaItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InPageUp,stiDirection})
					-> if (part==InPageUp)
						(Just (CompoundScrollAction {csaWIDS = wshIds, csaSliderMove = SliderDecLarge, csaDirection = stiDirection, csaItemNr = itControl, csaItemPtr = stiControl}))
						Nothing
				({stiControl,stiPart=InPageDown,stiDirection})
					-> if (part==InPageDown)
						(Just (CompoundScrollAction {csaWIDS = wshIds, csaSliderMove = SliderIncLarge, csaDirection = stiDirection, csaItemNr = itControl, csaItemPtr = stiControl}))
						Nothing
				_	-> Nothing
		# (sti,pState)			= case sti.stiPart of
			InUpButton
				# inside	= part == InUpButton
				# part`		= if inside part 0
				| inside == sti.stiHilite
					-> (sti,pState)
				-> ({sti & stiHilite = inside},appPIO (appIOToolbox (appClipped wPtr (HiliteControl sti.stiControl part`))) pState)
			InDownButton
				# inside	= part == InDownButton
				# part`		= if inside part 0
				| inside == sti.stiHilite
					-> (sti,pState)
				-> ({sti & stiHilite = inside},appPIO (appIOToolbox (appClipped wPtr (HiliteControl sti.stiControl part`))) pState)
			_	-> (sti,pState)
		# inputTrack			= Just {inputTrack & itKind.itkSlider = Just sti}
		# pState = appPIO (appIOToolbox (startTracking (OSTime when))) pState
		# pState				= appPIO (ioStSetInputTrack inputTrack) pState
		= (rEvent,wsH,pState)
	= controlMouseDragEvent itControl h v mods wsH pState
where
	// handleMouseMoveEvent` :: !Int !Int !Int !(DialogStateHandle (PSt .l .p)) !(PSt .l .p) -> PSt .l .p
	// en mouse move in control dan...?
	// controleren in input track...
	handleMouseMoveEvent` h v mods wsH=:{wshIds,wshHandle=Just dlsH=:{wlsHandle=wlsH=:{whWindowInfo,whSelect,whAtts}}} pState
	|	not whSelect						= (Nothing,wsH,pState)
	|	not hasMouse || not (enabled select)= (Nothing,wsH,pState)
	|	not (filter mState)					= (Nothing,wsH,pState1)
											= (Just returnEvent,wsH,pState1)//pState3
	where
		whOrigin							= case whWindowInfo of
												(WindowInfo {windowOrigin})	-> windowOrigin
												_							-> zero
		(hasMouse,mouse)					= cselect isWindowMouse (WindowMouse (const False) Unable k`) whAtts
		(filter,select,_)					= getWindowMouseAtt mouse
		(localPos,pState1)					= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
		modifiers							= toModifiers mods
		mState								= MouseMove (whOrigin+localPos) modifiers
		returnEvent							= WindowMouseAction {wmWIDS=wshIds,wmMouseState= mState}
	
	handleMouseDragEvent h v mods wsH=:{wshIds,wshHandle=Just dlsH=:{wlsHandle=wlsH=:{whWindowInfo,whSelect,whAtts}}} pState
	|	not whSelect						= (Nothing,wsH,pState)
	|	not hasMouse || not (enabled select)= (Nothing,wsH,pState)
	|	not (filter mState)					= (Nothing,wsH,pState1)
											= (Just returnEvent,wsH,pState1)//pState3
	where
		whOrigin							= case whWindowInfo of
												(WindowInfo {windowOrigin})	-> windowOrigin
												_							-> zero
		(hasMouse,mouse)					= cselect isWindowMouse (WindowMouse (const False) Unable k`) whAtts
		(filter,select,_)					= getWindowMouseAtt mouse
		(localPos,pState1)					= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
		modifiers							= toModifiers mods
		mState								= MouseDrag (whOrigin+localPos) modifiers
		returnEvent							= WindowMouseAction {wmWIDS=wshIds,wmMouseState= mState}

	controlMouseDragEvent itControl h v mods wsH=:{wshIds,wshHandle=Just dlsH=:{wlsHandle=wlsH=:{whItems,whWindowInfo,whSelect,whAtts}}} pState
		// find control
		// check mouse filter
		// return event
		# (found,(itemPtr,itemKind),whItems)
			= getItemPtrAndKind itControl whItems
		| trace_n ("controlMouseDragEvent",itControl,itemPtr) False = undef
		# wsH={wsH & wshHandle=Just {dlsH & wlsHandle={wlsH & whItems = whItems}}}
		# controlInfo
			= Just (ControlMouseAction {cmWIDS=wshIds,cmItemNr=itControl,cmItemPtr=itemPtr,cmMouseState=mouseState})
//			= (Nothing,wsH,pState)
		= (controlInfo,wsH,pState1)
	where
		whOrigin							= case whWindowInfo of
												(WindowInfo {windowOrigin})	-> windowOrigin
												_							-> zero
		mouseState							= MouseDrag (whOrigin+localPos) modifiers
		(localPos,pState1)					= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
		modifiers							= toModifiers mods

/*	Handling a MouseDownEvent for a window.
*/
windowMouseDownIO :: !OSWindowMetrics (WindowStateHandle (PSt .l)) !OSEvent !(WindowHandles (PSt .l)) !(PSt .l)
  -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,/*!WindowHandles (PSt .l),*/  !(PSt .l))
windowMouseDownIO wMetrics wsH event=:(_,MouseDownEvent,_,when,h,v,mods) windows pState
	# pState = trace_n ("windowMouseDownIO",0) pState
	#	(opt_modalId,pState)					= accPIO ioStGetIOIsModal pState
		(ioId,pState)							= accPIO ioStGetIOId pState
		existsModalProcess						= isJust opt_modalId
		modalProcessId							= fromJust opt_modalId
	|	existsModalProcess && not (ioId == modalProcessId)
//		# pState = trace_n ("windowMouseDownIO: exists modal & not me") pState
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("windowMouseDownIO",1) pState
		= (True,Nothing,Nothing,appPIO beep pState)
	#	(tb,pState)								= accPIO getIOToolbox pState
		(region,wPtr,tb)						= FindWindow h v tb
	|	not (knownRegion region)
//		# pState = trace_n ("windowMouseDownIO: unknown region") pState
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("windowMouseDownIO",2) pState
		= (True,Nothing,Nothing,appPIO (setIOToolbox tb) pState)
//	#	(found,dsH,ioState)						= IOStGetActiveDialog ioState
//	|	not found
//		= setIOToolbox tb ioState
//	#	(activePtr,dsH)							= DialogStateHandleGetDialogPtr dsH
	# (active,wsH)								= getWindowStateHandleActive wsH
	|	existsModalProcess && not active
//		# pState = trace_n ("windowMouseDownIO: exists modal & not active") pState
		# pState								= appPIO (beep o (setIOToolbox tb)) pState
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("windowMouseDownIO",3) pState
		= (True,Nothing,Nothing,pState)
	#	(isActiveProcess,pState)				= accPIO ioStIsActive pState
		(frontPtr,tb)							= FrontWindow tb
	|	not active || wPtr<>frontPtr || not isActiveProcess
//		# ioState								= IOStReplaceDialog dsH ioState
//		# (_,dsH1,ioState)						= IOStGetDialog (toWID wPtr) ioState
//		= activateTheWindow isActiveProcess event dsH1 tb ioState
		# (wids,wsH)							= getWindowStateHandleWIDS wsH
	// hmm, mag alleen als er geen modale dialoog actief is???
		  windows								= setWindowHandlesWindow wsH windows
		  (activeModal,windows)					= getWindowHandlesActiveModalDialog windows
		  (activeWindow,windows)				= getWindowHandlesActiveWindow windows
		  (_,wsH,windows)						= getWindowHandlesWindow (toWID wPtr) windows
		# (tb,ioState`, wsH)					= case activeModal of
													Just _		-> (tb, pState.io, wsH)
													Nothing		-> activateTheWindow isActiveProcess event wsH tb pState.io
		# pState								= {pState & io = ioState`}
// moet ook deactivate van oude regelen...
//		# pState = trace_n ("windowMouseDownIO: not active | not front | not process") pState
//		# pState = (if active id (trace_n "not active")) pState
//		# pState = (if (wPtr==frontPtr) id (trace_n "not front")) pState
//		# pState = (if isActiveProcess id (trace_n "not process")) pState
		# pState								= appPIO (setIOToolbox tb) pState
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
//		= (True,Nothing,if (isJust activeModal) Nothing (Just (WindowActivation wids)),pState)
//		= (True,Nothing,if (isJust activeModal) Nothing Nothing/*(Just (WindowActivation wids))*/,pState)
		# pState = trace_n ("windowMouseDownIO",4) pState
		= (True,Nothing,Nothing,pState)
//		= case activeWindow of
//			(Just awids)	-> (True,Nothing,Just (WindowDeactivation awids),appPIO (bufferOSEvent event) pState)
//			Nothing			-> (True,Nothing,if (isJust activeModal) Nothing (Just (WindowActivation wids)),pState)
	|	region==InDrag
//		# pState = trace_n ("windowMouseDownIO: in drag") pState
		# pState = trace_n ("windowMouseDownIO",5) pState
		= dragTheWindow			h v	wsH windows tb pState
	|	region==InGoAway
//		# pState = trace_n ("windowMouseDownIO: in go away") pState
		# pState = trace_n ("windowMouseDownIO",6) pState
		= closeTheWindow		h v	wsH windows tb pState
	|	region==InGrow
//		# pState = trace_n ("windowMouseDownIO: in grow") pState
		# pState = trace_n ("windowMouseDownIO",7) pState
		= growTheWindow			h v	wsH windows tb pState
	|	region==InZoomIn || region==InZoomOut
//		# pState = trace_n ("windowMouseDownIO: in zoom in | out") pState
		# pState = trace_n ("windowMouseDownIO",8) pState
		= zoomTheWindow region	h v	wsH windows tb pState
	# pState	= appPIO (setIOToolbox tb) pState
	#	(ableWindow,wsH)						= getWindowStateHandleSelect wsH
	|	not ableWindow
//		# pState = trace_n ("windowMouseDownIO: not ableWindow") pState
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("windowMouseDownIO",9) pState
		= (True,Nothing,Nothing,pState)
	#	(localPos,pState)						= accPIO (accIOToolbox (accGrafport wPtr (GlobalToLocal {x=h,y=v}))) pState
//	# localPos = localPos + windowOrigin

	#	(inControl,returnEvent,windows,wsH,pState)
												= controlMouseDownIO wMetrics wPtr localPos when mods wsH windows pState
	|	inControl
		# windows								= setWindowHandlesWindow wsH windows
		# pState								= appPIO (ioStSetDevice (WindowSystemState windows)) pState
//		#! pState = trace_n "windowMouseDownIO: in control" pState
		# pState = trace_n ("windowMouseDownIO",10) pState
		= (True,Nothing,returnEvent,pState)
//	#	(wsH,pState)							= accIOToolbox (clearWindowKeyFocus deactivateControl wsH) pState
//	# pState = trace_n ("windowMouseDownIO: nothing figured out...") pState
	# pState = trace_n ("windowMouseDownIO",11) pState
	= mouseInWindow wPtr localPos when mods wsH windows pState
where
	knownRegion :: !Int -> Bool
	knownRegion region
	=	region==InContent || region==InDrag || region==InGoAway || region==InGrow || region==InZoomIn || region==InZoomOut
/*	
//	clearWindowKeyFocus :: !(IdFun *Toolbox) !(DialogStateHandle .ps) !*Toolbox
//										  -> (!DialogStateHandle .ps, !*Toolbox)
	clearWindowKeyFocus deactivate dsH=:{wlsHandle=dH=:{whKind,whKeyFocus,whAtts}} tb
	|	not hasKey || whKind==IsDialog
	=	(dsH,tb)
	=	( {dsH & wlsHandle={dH & whKeyFocus=setNoFocusItem whKeyFocus}},deactivate tb)
	where
		(hasKey,_)	= cselect isWindowKeyboard (WindowKeyboard (const False) Unable k`) whAtts
*/
	mouseInWindow wPtr localPos when mods wsH=:{wshIds,wshHandle=Just wlsH=:{wlsState,wlsHandle=dH=:{whAtts}}} windows pState
	#	(hasMouse,mouse)		= cselect isWindowMouse (WindowMouse (const False) Unable k`) whAtts
		(filter,select,mouseF)	= getWindowMouseAtt mouse
//	# wsH						= {wsH & wshHandle = Just {wlsH & wlsHandle=dH}}
	|	not hasMouse || not (enabled select)
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Nothing,pState)
// start tracking...
	# pState = appPIO (startTrack) pState
		with
			startTrack io
				# (it,io)	= ioStGetInputTrack io
				# it		= trackMouse wPtr 0 it
				# io		= ioStSetInputTrack it io
				= io
// other stuff...
	#	((WindowInfo {windowOrigin = lt}),wsH)
								= getWindowStateHandleWindowInfo wsH
	#	(bMouse,pState)			= accPIO (ioStButtonFreq when localPos wPtr) pState
		modifiers				= toModifiers mods
		mState					= MouseDown (/*dhOrigin+*/lt + localPos) modifiers bMouse
	|	filter mState
		# returnEvent			= WindowMouseAction {wmWIDS=wshIds,wmMouseState= mState}
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Just returnEvent,pState)
	# windows					= setWindowHandlesWindow wsH windows
	# pState					= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (True,Nothing,Nothing,pState)

/*
	mouseInWindow wPtr localPos when mods wsH=:{wshHandle=Just wlsH=:{wlsState,wlsHandle=dH=:{whAtts}}} windows pState
	#	(hasMouse,mouse)		= cselect isWindowMouse (WindowMouse (const False) Unable k`) whAtts
		(filter,select,mouseF)	= getWindowMouseAtt mouse
//	# wsH						= {wsH & wshHandle = Just {wlsH & wlsHandle=dH}}
	|	not hasMouse || not (enabled select)
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Nothing,pState)
	#	((WindowInfo {windowOrigin = lt}),wsH)
								= getWindowStateHandleWindowInfo wsH
	#	(bMouse,pState)			= accPIO (ioStButtonFreq when localPos wPtr) pState
		modifiers				= toModifiers mods
		mState					= MouseDown (/*dhOrigin+*/lt + localPos) modifiers bMouse
	|	filter mState
/*
	= (True,Nothing,Nothing,pState2)
		with
			pState1				= appPIO (ioStSetDevice (WindowSystemState windows1)) pState
			windows1			= setWindowHandlesWindow wsH1 windows
			wsH1				= {wsH & wshHandle = Just {wlsH & wlsState = ls1, wlsHandle = dH}}
			(ls1,pState2)		= trackMouseInWindow wPtr filter mouseF (mouseF mState (wlsState,pState1))
	= (True,Nothing,Nothing,pState2)
		with
			pState1				= appPIO (ioStSetDevice (WindowSystemState windows1)) pState
			windows1			= setWindowHandlesWindow wsH1 windows
			wsH1				= {wsH & wshHandle = Just {wlsH & wlsState = ls1, wlsHandle = dH}}
			(ls1,pState2)		= trackMouseInWindow wPtr filter mouseF (wlsState,pState1)
*/
/*
		# wsH					= {wsH & wshHandle = Just {wlsH & wlsHandle=dH}}
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState

		# (ls1,pState)			= trackMouseInWindow wPtr filter mouseF (mouseF mState (wlsState,pState))

		# (_,wDevice,ioState`)	= ioStGetDevice WindowDevice pState.io
		  windows				= windowSystemStateGetWindowHandles wDevice
		  pState				= {pState & io = ioState`}
		  (_,wsH,windows)		= getWindowHandlesWindow (toWID wPtr) windows 

		# wlsH					= fromJust wsH.wshHandle
		# wsH					= {wsH & wshHandle = Just {wlsH & wlsState=ls1}}//,wlsHandle=dH}}
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Nothing,pState)

	# wsH						= {wsH & wshHandle = Just {wlsH & wlsHandle=dH}}
	# windows					= setWindowHandlesWindow wsH windows
	# pState					= appPIO (ioStSetDevice (WindowSystemState windows)) pState

	# (ls1,pState)				= trackMouseInWindow wPtr filter mouseF (wlsState,pState)

	# (_,wDevice,ioState`)		= ioStGetDevice WindowDevice pState.io
	  windows					= windowSystemStateGetWindowHandles wDevice
	  pState 					= {pState & io = ioState`}
	  (_,wsH,windows) 			= getWindowHandlesWindow (toWID wPtr) windows 

	# wlsH						= fromJust wsH.wshHandle
	# wsH						= {wsH & wshHandle = Just {wlsH & wlsState=ls1}}//,wlsHandle=dH}}
	# windows					= setWindowHandlesWindow wsH windows
	# pState					= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	= (True,Nothing,Nothing,pState)
*/
	where
		trackMouseInWindow wPtr filter mouseF (ls,pState)
		#	(down,pState)			= accPIO (accIOToolbox StillDown) pState
			(goOn,(ls,pState))		= trackMouseInWindow` wPtr down filter mouseF (ls,pState)
		|	down && goOn			= trackMouseInWindow  wPtr filter mouseF (ls,pState)
									= (ls,pState)
		where
			trackMouseInWindow` wPtr buttonDown filter mouseF (ls,pState)
			# (_,wDevice,ioState`)		= ioStGetDevice WindowDevice pState.io
			  windows					= windowSystemStateGetWindowHandles wDevice
			  pState 					= {pState & io = ioState`}
			  (_,wsH,windows) 			= getWindowHandlesWindow (toWID wPtr) windows 
			#	((WindowInfo {windowOrigin = lt}),wsH)
										= getWindowStateHandleWindowInfo wsH
			# windows					= setWindowHandlesWindow wsH windows
			# pState					= appPIO (ioStSetDevice (WindowSystemState windows)) pState

			#	(tb,pState)			= accPIO getIOToolbox pState
				(mPos,tb)			= accGrafport wPtr GetMousePosition tb
				(k1,k2,k3,k4,tb)	= GetKeys tb
				mods				= KeyMapToModifiers (k1,k2,k3,k4)
				pos					= lt+mPos
				mState				= if buttonDown (MouseDrag pos mods) (MouseUp pos mods)
				pState				= appPIO (setIOToolbox tb) pState
			|	filter mState		= (True, mouseF mState (ls,pState))
									= (True, (ls,pState))
*/			
	//dragTheWindow :: !Int !Int !(DialogStateHandle (PSt .l .p)) !*Toolbox !(PSt .l .p) -> PSt .l .p
	//dragTheWindow h v (DialogLSHandle {dlsHandle={dhPtr}}) tb pState
	dragTheWindow h v wsH=:{wshIds={wPtr}} windows tb pState
		#	(sr, tb)			= osScreenrect tb
			tb					= DragWindow wPtr h v (OSRect2Rect {sr & rright = sr.rright - 1, rbottom = sr.rbottom - 1}) tb
			pState				= appPIO (setIOToolbox tb) pState
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Nothing,pState)

	//closeTheWindow :: !Int !Int !(DialogStateHandle (PSt .l .p)) !*Toolbox !(PSt .l .p) -> PSt .l .p
	//closeTheWindow h v (DialogLSHandle dlsH=:{dlsState,dlsHandle=dH}) tb pState
	closeTheWindow h v wsH=:{wshIds={wPtr}} windows tb pState
		# (goAway,tb)			= TrackGoAway wPtr h v tb
		| not goAway
			# pState				= appPIO (setIOToolbox tb) pState
			# windows				= setWindowHandlesWindow wsH windows
			# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
			= (True,Nothing,Nothing,pState)
		# (wids,wsH)			= getWindowStateHandleWIDS wsH
		# pState				= appPIO (setIOToolbox tb) pState
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Just (WindowRequestClose wids),pState)
//		| hasAtt
//			# (_,goAtt)			= Select iswindowclose (WindowClose I) atts
//			# goF				= getwindowclosefunction goAtt
//			# ioState			= setIOToolbox tb ioState
//			# ioState			= IOStReplaceDialog (DialogLSHandle {dlsState=ls1,dlsHandle=dH}) ioState
//			# (ls1,pState2)		= goF (dlsState,pState1)
//			= pState2
//		= pState1
//			with
//				(_,_,ioState)	= IOStRemoveDialog (toWID wPtr) pState.io
//				tb1				= DisposeWindow wPtr tb
//				ioState1		= setIOToolbox tb1 ioState
//				pState1			= {pState & io=ioState1}
//	where
//		wPtr				= dH.dhPtr
//		atts				= dH.dhAtts
//		hasAtt				= Contains iswindowclose atts

	//growTheWindow :: !Int !Int !(DialogStateHandle (PSt .l .p)) !*Toolbox !(PSt .l .p) -> PSt .l .p
	growTheWindow h v wsH=:{wshIds={wPtr}} windows tb pState
		# (wids,wsH)			= getWindowStateHandleWIDS wsH
		# (maxW,maxH)			= osMaxScrollWindowSize
		# ((neww,newh),tb)		= GrowWindow wPtr h v (minWindowW,minWindowH, maxW+1,maxH+1) tb
		| neww == 0 || newh == 0
			# windows			= setWindowHandlesWindow wsH windows
			# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
			# pState			= appPIO (setIOToolbox tb) pState
			= (True,Nothing,Nothing,pState)
		# tb					= SizeWindow wPtr neww newh False tb
		# tb					= invalRect wPtr (0,0,neww,newh) tb		// brutal approximation...
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState				= appPIO (setIOToolbox tb) pState
		# info					= {wsWIDS = wids, wsSize = {w=neww,h=newh}, wsUpdateAll = systemsizing}
		# pState = trace_n ("growTheWindow",neww,newh) pState
		= (True,Nothing,Just (WindowSizeAction info),pState)
	where
		(minWindowW,minWindowH)			= osMinWindowSize
		systemsizing					= True				// DvA: need to get from Window info...

	//zoomTheWindow :: !Int !Int !Int !(WindowStateHandle (PSt .l)) !*Toolbox !(PSt .l) -> PSt .l
	zoomTheWindow region h v wsH=:{wshIds={wPtr}} windows tb pState
		# (zoom,tb)			= TrackBox wPtr h v region tb
		| not zoom
			# windows		= setWindowHandlesWindow wsH windows
			# pState		= appPIO (ioStSetDevice (WindowSystemState windows)) pState
			# pState		= appPIO (setIOToolbox tb) pState
			= (True,Nothing,Nothing,pState)
//		# (oldSize,tb)		= osGetWindowViewFrameSize wPtr tb
		# tb				= zoomWindow wPtr region True tb	//(QEraseRect (SizeToRect oldSize) tb)) tb
		# ((w,h),tb)		= osGetWindowViewFrameSize wPtr tb
		# tb				= invalRect wPtr (0,0,w,h) tb	// brutal...
		# (wids,wsH)		= getWindowStateHandleWIDS wsH
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState			= appPIO (setIOToolbox tb) pState
		# info				= {wsWIDS = wids, wsSize = {w=w,h=h}, wsUpdateAll = systemsizing}
		= (True,Nothing,Just (WindowSizeAction info),pState)
		// should really produce WindowZoomAction so that we can skip relayout on minimize since that's silly...
	where
		systemsizing = True

//activateTheWindow :: !Bool !Event !(DialogStateHandle (PSt .l .p)) !*Toolbox !(PSt .l .p) -> PSt .l .p
activateTheWindow activeIO event (wsH=:{wshIds={wPtr}}) tb ioState
	| activeIO
		# ioState = trace_n "windowevent:activateTheWindow activeIO" ioState
		= (WaitForMouseUp (SelectWindow wPtr tb), ioState, wsH)
	# ioState				= activateMenuSystem ioState
//	# ioState				= appIOToolbox (setCursorShape StandardCursor) ioState
	# ioState = trace_n "windowevent:activateTheWindow not activeIO" ioState
	=	(WaitForMouseUp (SelectWindow wPtr tb), ioState, wsH)

/*	Handling an UpdateEvent for a window.
*/

//windowUpdateIO :: (WindowStateHandle pst) _ _ -> _
windowUpdateIO :: !(WindowStateHandle (PSt .l)) !OSEvent !(WindowHandles (PSt .l)) !(PSt .l)
  -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,!(PSt .l))
windowUpdateIO {wshHandle = Nothing} _ _ _
	= windoweventFatalError "windowUpdateIO" "window placeholder not expected"
windowUpdateIO wsH (_,_,wPtr,_,_,_,_) windows pState
	# (wids,wsH) = getWindowStateHandleWIDS wsH
	= windowUpdateIO wsH wids wPtr windows pState
where
	windowUpdateIO :: !(WindowStateHandle (PSt .l)) !WIDS !Int !(WindowHandles (PSt .l)) !(PSt .l)
	  -> (!Bool,!Maybe [Int],!Maybe DeviceEvent,!(PSt .l))
	windowUpdateIO
		wsH=:{wshHandle = Just wlsH=:{wlsState = ls, wlsHandle = wH=:{whItems,whSize,whKind,whWindowInfo = info}}}
		wids wPtr windows pState
		# (updRect,pState)		//= ({rleft=0,rtop=0,rright=400,rbottom=400},pState)
								= accPIO (accIOToolbox (loadUpdateBBox wPtr)) pState
		# clipRect				= intersectRects updRect (sizeToRect whSize)
		# (controls,whItems)	= getUpdateControls whItems clipRect zero
		# (info,pState) = case info of 
							NoWindowInfo			-> (NoWindowInfo,pState)
							(GameWindowInfo inf)	-> (GameWindowInfo inf,pState)
							(WindowInfo inf)		-> accPIO (accIOToolbox (doWindowScrollers wPtr inf whSize)) pState
		# wsH					= {wsH & wshHandle = Just {wlsState = ls, wlsHandle = {wH & whItems = whItems, whWindowInfo = info}}}
		# updateInfo			= {updWIDS=wids,updWindowArea=clipRect,updControls=controls,updGContext=Nothing}
		# windows				= setWindowHandlesWindow wsH windows
		# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True,Nothing,Just (WindowUpdate updateInfo),pState)

	getUpdateControls :: ![WElementHandle .ls .pst] !OSRect !Point2 -> ([ControlUpdateInfo],[WElementHandle .ls .pst])
	getUpdateControls [] _ parent_pos
		= ([],[])
	getUpdateControls [itemH:itemHs] clipRect parent_pos
		# (l,r)		= getUpdateControl itemH clipRect parent_pos
		# (ll,rr)	= getUpdateControls itemHs clipRect parent_pos
		= (l++ll,[r:rr])

	getUpdateControl :: !(WElementHandle .ls .pst) !OSRect !Point2 -> (![ControlUpdateInfo],!(WElementHandle .ls .pst))
	getUpdateControl (WItemHandle itemH=:{wItemShow,wItemKind,wItemPtr,wItemPos,wItemSize,wItemNr}) clipRect parent_pos
		| not wItemShow
			= ([],WItemHandle itemH)
		| wItemKind == IsLayoutControl
			# (controls,whItems)	= getUpdateControls itemH.wItems clipRect (movePoint wItemPos parent_pos)
			= (controls,WItemHandle {itemH & wItems = whItems})
		# item_pos = movePoint wItemPos parent_pos
		# itemRect	= posSizeToRect item_pos wItemSize
		  clipRect`	= intersectRects clipRect itemRect
		| wItemKind == IsCompoundControl
			# (controls,whItems)	= getUpdateControls itemH.wItems clipRect item_pos
			  clipRect``	= addVector (toVector ((getWItemCompoundInfo itemH.wItemInfo).compoundOrigin - item_pos)) clipRect`
			  control`	= {cuItemNr = wItemNr, cuItemPtr = wItemPtr, cuArea = clipRect``}
			= ([control`:controls],WItemHandle {itemH & wItems = whItems})
		#  control		= {cuItemNr = wItemNr, cuItemPtr = wItemPtr, cuArea = clipRect`}
		= ([control],WItemHandle itemH)
	getUpdateControl (WListLSHandle itemHs) clipRect parent_pos
		# (controls,itemHs) = getUpdateControls itemHs clipRect parent_pos
		= (controls,WListLSHandle itemHs)
	getUpdateControl (WExtendLSHandle wExH=:{wExtendItems=itemHs}) clipRect parent_pos
		# (controls,itemHs) = getUpdateControls itemHs clipRect parent_pos
		= (controls,WExtendLSHandle {wExH & wExtendItems = itemHs})
	getUpdateControl (WChangeLSHandle wExH=:{wChangeItems=itemHs}) clipRect parent_pos
		# (controls,itemHs) = getUpdateControls itemHs clipRect parent_pos
		= (controls,WChangeLSHandle {wExH & wChangeItems = itemHs})
	
//--

//	checkcaretblink :: !OSWindowMetrics !Bool !(IOSt .l) -> IOSt .l
checkcaretblink wMetrics active wsH ioState
//	# ioState = trace_n ("Active",active) ioState
	|	not active
	=	(wsH,ioState)
	#	(tb,ioState)		= getIOToolbox ioState
		(wsH,tb)			= checkcaretblink` wMetrics wsH tb
		ioState				= setIOToolbox tb ioState
	=	(wsH,ioState)
where
	checkcaretblink` :: !OSWindowMetrics !(WindowStateHandle .ps) !*OSToolbox -> (!WindowStateHandle .ps,!*OSToolbox)
	checkcaretblink` wMetrics wsH=:{wshIds={wPtr},wshHandle= Just wlsH=:{wlsHandle=wH=:{whSelect,whKeyFocus,whItems,whWindowInfo}}} tb
	#	(focusNr,whKeyFocus)
						= getCurrentFocusItem whKeyFocus
//	#! tb = trace_n ("Focus",whSelect,focusNr) tb
	|	not whSelect || isNothing focusNr
		# wsH = {wsH & wshHandle = Just {wlsH & wlsHandle = {wH & whKeyFocus=whKeyFocus}}}
		=	(wsH,tb)
	#	caretNr			= fromJust focusNr
		(size,tb)		= (wH.whSize,tb)	//osGetWindowViewFrameSize wPtr tb
		contentRect		= osGetWindowContentRect wMetrics (hasHScroll,hasVScroll) (sizeToRect size)	// ?PosSizeToRect
		(_,items,tb)	= checkitemscaret whItems caretNr wMetrics wPtr contentRect zero tb
	=	({wsH & wshHandle = Just {wlsH & wlsHandle={wH & whItems=items, whKeyFocus=whKeyFocus}}},tb)
	where
		(hasHScroll,hasVScroll) = case whWindowInfo of
									WindowInfo windowinfo	-> (isJust windowinfo.windowHScroll,isJust windowinfo.windowVScroll)
									_						-> (False,False)


	checkitemscaret :: ![WElementHandle .ls .ps] !Int !OSWindowMetrics !OSWindowPtr !OSRect !Point2 !*OSToolbox
								   -> (!Bool,![WElementHandle .ls .ps],!*OSToolbox)
	checkitemscaret [itemH:itemHs] caretNr wMetrics wPtr clipRect parent_pos tb
	#	(found,itemH,tb)	= checkitemcaret itemH caretNr wPtr clipRect parent_pos tb
	|	found
	=	(found,[itemH:itemHs],tb)
	#	(found,itemHs,tb)	= checkitemscaret itemHs caretNr wMetrics wPtr clipRect parent_pos tb
	=	(found,[itemH:itemHs],tb)
	where
		checkitemcaret :: !(WElementHandle .ls .ps) !Int !OSWindowPtr !OSRect !Point2 !*OSToolbox
									   -> (!Bool,!WElementHandle .ls .ps, !*OSToolbox)
		checkitemcaret (WListLSHandle itemHs) caretNr wPtr clipRect parent_pos tb
		#	(found,itemHs,tb)	= checkitemscaret itemHs caretNr wMetrics wPtr clipRect parent_pos tb
		=	(found,WListLSHandle itemHs,tb)
		checkitemcaret (WExtendLSHandle dExH=:{wExtendItems=itemHs}) caretNr wPtr clipRect parent_pos tb
		#	(found,itemHs,tb)	= checkitemscaret itemHs caretNr wMetrics wPtr clipRect parent_pos tb
		=	(found,WExtendLSHandle {dExH & wExtendItems=itemHs},tb)
		checkitemcaret (WChangeLSHandle dChH=:{wChangeItems=itemHs}) caretNr wPtr clipRect parent_pos tb
		#	(found,itemHs,tb)	= checkitemscaret itemHs caretNr wMetrics wPtr clipRect parent_pos tb
		=	(found,WChangeLSHandle {dChH & wChangeItems=itemHs},tb)
		checkitemcaret (WItemHandle itemH) caretNr wPtr clipRect parent_pos tb
		#	(found,itemH,tb)	= checkitemcaret` itemH caretNr wPtr clipRect parent_pos tb
		=	(found,WItemHandle itemH,tb)
		where
			checkitemcaret` :: !(WItemHandle .ls .ps) !Int !OSWindowPtr !OSRect !Point2 !*OSToolbox
											-> (!Bool,!WItemHandle .ls .ps, !*OSToolbox)
			checkitemcaret` itemH=:{wItemSelect,wItemNr,wItemPtr,wItemKind=IsEditControl} caretNr wPtr clipRect parent_pos tb
			|	caretNr<>wItemNr		= (False,itemH,tb)
			|	able					= (True,itemH,osIdleEditControl wPtr clipRect wItemPtr tb)
										= (True,itemH,tb)
			where
				able					= wItemSelect
			checkitemcaret` itemH=:{wItemSelect,wItemNr,wItemPtr,wItemKind=IsPopUpControl,wItemInfo} caretNr wPtr clipRect parent_pos tb
			|	caretNr<>wItemNr		= (False,itemH,tb)
			|	able					= (True,itemH,osIdlePopUpControl wPtr clipRect wItemPtr editPtr tb)
										= (True,itemH,tb)
			where
				able					= wItemSelect
				info					= getWItemPopUpInfo wItemInfo
				editPtr					= mapMaybe (\{popUpEditPtr}->popUpEditPtr) info.popUpInfoEdit
			checkitemcaret` itemH=:{wItemNr,wItemKind=IsCustomControl} caretNr _ _ parent_pos tb
			=	(caretNr==wItemNr,itemH,tb)
			checkitemcaret` itemH=:{wItems,wItemSelect,wItemKind=IsCompoundControl,wItemPos} caretNr wPtr clipRect parent_pos tb
				|	not wItemSelect
					=	(False,itemH,tb)
					#	(found,items,tb)= checkitemscaret wItems caretNr wMetrics wPtr clipRect1 item_pos tb
					=	(found,{itemH & wItems=items},tb)
			where
				item_pos = movePoint wItemPos parent_pos
				info			= getWItemCompoundInfo itemH.wItemInfo
				itemRect		= posSizeToRect item_pos itemH.wItemSize
				clipRect1		= intersectRects (osGetCompoundContentRect wMetrics (hasHScroll,hasVScroll) itemRect) clipRect
				hasHScroll		= isJust info.compoundHScroll
				hasVScroll		= isJust info.compoundVScroll
			checkitemcaret` itemH _ _ _ parent_pos tb
			=	(False,itemH,tb)
	checkitemscaret _ _ _ _ _ parent_pos tb
	=	(False,[],tb)

//--

OSRect2Rect r	:== (rleft,rtop,rright,rbottom)
where
	{rleft,rtop,rright,rbottom} = r

kTiming :== 0
