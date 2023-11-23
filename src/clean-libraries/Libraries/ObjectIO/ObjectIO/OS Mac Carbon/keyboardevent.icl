implementation module keyboardevent

import StdEnv//, StdIO
import StdPSt,StdControlAttribute,StdWindowAttribute
import windowaccess,windowhandle,deviceevents,iostate
import commondef
import ostypes, oswindow
import osutil,oskey
import keyfocus, inputtracking
//import events,windows
//import memoryaccess,textedit,texteditaccess
from mouseevent import changeFocus
//from textedit import TEKey, :: TEHandle
import events, controls

//import StdDebug, dodebug
trace_n _ f :== f
//from dodebug import trace_n`, toString
//import dodebug
trace_n` _ s :== s
//trace_n :== trace_n`

windowKeyboardIO :: !*(WindowStateHandle *(PSt .l)) !OSEvent !*(WindowHandles *(PSt .l)) !*(PSt .l)
	-> *(!Bool,!Maybe [Int],!Maybe DeviceEvent,!*(PSt .l))
windowKeyboardIO wsH=:{wshIds={wPtr},wshHandle= Just wshH=:{wlsHandle=wlsH}} event=:(_,what,message,i,h,v,mods) windows pState
	| /*trace_n ("windowKeyboardIO",return,isDialog)*/ False
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True, Nothing, Nothing, pState)
	| isDialog && commandPeriod
		# (deviceEvent,wsH)	= pressCancelButton mods wsH
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState = trace_n ("keyboardevent: 2") pState
		= (True, Nothing,deviceEvent,pState)
	| isDialog && tabCharacter && what <> KeyUpEvent
		= nextKeyInputFocus wPtr wsH windows pState
	# (cNr,(cPtr,cKind),wsH)= getControlFocusPtr wPtr wsH
	# wsH = trace_n ("keyinfo",cNr,cPtr,cKind) wsH
	# (pressed,deviceevent,wsH)
							// shouldn't we check for edit control first?
							// and dialog?
							= pressDefaultButton return mods wsH //return still waits for keyrepeat instead of immediate...
	# wsH = trace_n ("keyevent",cKind,pressed) wsH
	| isDialog && pressed && isJust deviceevent && not (cKind == IsEditControl)	//  need to extend for editable popups...
		#! pState = trace_n ("keyboardevent","In") pState
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True, Nothing,deviceevent,pState)
//*
	| isDialog && return && not (cKind == IsEditControl)	// see above about editpops...
		#! pState = trace_n ("keyboardevent","Out") pState
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True, Nothing,Nothing,pState)
//*/
//	# (wPtr,pState)			= accPIO (accIOToolbox FrontWindow) pState
	# (isValid,mustBuffer,keyState,theChar,theCode,pState)
							= validateKeyTracking wPtr cPtr cNr event pState
	#! pState = trace_n ("valid",isValid,mustBuffer,keyState,theCode) pState
	| not isValid
		#! pState = trace_n ("keyboardevent","invalid") pState
		# windows			= setWindowHandlesWindow wsH windows
		# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		# pState			= trace_n "not_valid..." pState
		= (True, Nothing,Nothing,pState)
	# (deviceevent,wsH,pState)
							= handleKeyboardFunction wPtr cNr cPtr keyState theChar theCode (toModifiers mods) (message,mods) wsH pState
	# windows				= setWindowHandlesWindow wsH windows
	# pState				= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	| mustBuffer
		#! pState = trace_n ("keyboardevent","buffer") pState
		# pState			= appPIO (bufferKeyboardEvents event) pState
		= (True, Nothing,deviceevent,pState)
	#! pState = trace_n ("keyboardevent","regular") pState
	= (True, Nothing,deviceevent,pState)
where
	windowKind							= wlsH.whKind
	isDialog							= windowKind == IsDialog
	(return,returnStill,commandPeriod)	= KeyEventInfo what message mods
	theASCIIChar						= getASCII message
	tabCharacter						= theASCIIChar == '\t'
//	escCharacter						= theASCIIChar == '\033'
windowKeyboardIO wsH=:{wshHandle= Nothing} event=:(_,what,message,i,h,v,mods) windows pState
	= abort "windowKeyboardIO called with window placeholder..."

//-- handleKeyboardFunction

handleKeyboardFunction :: !OSWindowPtr !Int !OSWindowPtr !KeyState !Char !.Int !.Modifiers !(!Int,!Int) !*(WindowStateHandle .a) !*(PSt .b)
	-> *(!Maybe .DeviceEvent,!*WindowStateHandle .a,!*PSt .b);
handleKeyboardFunction wPtr cNr cPtr keyState keyCode macCode modifiers info wsH=:{wshHandle=Just wlsH=:{wlsHandle=wH=:{whItems,whAtts,whKind}}} pState
	# pState = trace_n ("handleKeyboardFunction`",keyState,macCode,isSpecialKey macCode) pState
//	| macCode == 36 = trace_n "return return" (Nothing,wsH,pState)
	| cNr == 0		// window keyboard
		# pState				= trace_n "window_keyboard" pState
		| whKind == IsDialog || not okWindowKeyboardAtt	// || window unable...
			= (Nothing,wsH,pState)
		# (wids,wsH)			= getWindowStateHandleWIDS wsH
		# deviceevent			= Just (WindowKeyboardAction {wkWIDS=wids,wkKeyboardState=key})
		= (deviceevent,wsH,pState)
	# (found,ok,whItems,pState)	= toolBoxFun (okControlsKeyboard whItems cNr wPtr key keyCode info zero) pState
	# wsH						= {wsH & wshHandle = Just {wlsH & wlsHandle = {wH & whItems = whItems}}}
	| not found || not ok
		# pState				= trace_n "control_keyboard: not found or ok" pState
		= (Nothing,wsH,pState)
	# (wids,wsH)				= getWindowStateHandleWIDS wsH
	# deviceevent				= Just (ControlKeyboardAction {ckWIDS=wids,ckItemNr=cNr,ckItemPtr=cPtr,ckKeyboardState=key})
	#! pState					= trace_n "control_keyboard: found & ok" pState
	= (deviceevent,wsH,pState)
where
	toolBoxFun f ps
		# (tb,ps)		= accPIO getIOToolbox ps
		# (a,b,c,tb)	= f tb
		# ps			= appPIO (setIOToolbox tb) ps
		= (a,b,c,ps)
	key			= if (isSpecialKey macCode)
					(SpecialKey (toSpecialKey macCode) keyState modifiers)
					(CharKey keyCode keyState)
	(filter,selectState,_)
				= getWindowKeyboardAtt (snd (cselect isWindowKeyboard (WindowKeyboard (const False) Unable undef) whAtts))
	okWindowKeyboardAtt
				= filter key && selectState == Able
handleKeyboardFunction wPtr cNr cPtr keyState keyCode macCode modifiers info wsH=:{wshHandle=Nothing} pState
	= abort "handleKeyboardFunction: unexpected placeholder"

okControlsKeyboard :: !*[*WElementHandle .a .b] !Int !OSWindowPtr !KeyboardState !Char !(!Int,!Int) !Point2 !*OSToolbox
	-> *(.Bool,Bool,*[*WElementHandle .a .b],!*OSToolbox);
okControlsKeyboard [] focusNr wPtr key keyCode info parent_pos tb
	= (False,False,[],tb)
okControlsKeyboard [itemH:itemHs] focusNr wPtr key keyCode info parent_pos tb
	# (found,ok,itemH,tb)	= okControlKeyboard itemH focusNr wPtr key keyCode parent_pos tb
	| found
		= (found,ok,[itemH:itemHs],tb)
	# (found,ok,itemHs,tb)	= okControlsKeyboard itemHs focusNr wPtr key keyCode info parent_pos tb
	= (found,ok,[itemH:itemHs],tb)
where
	okControlKeyboard :: !*(WElementHandle .a .b) !Int !OSWindowPtr KeyboardState Char !Point2 !*OSToolbox
						-> *(.Bool,Bool,*WElementHandle .a .b,!*OSToolbox);
	okControlKeyboard (WItemHandle itemH=:{wItemNr,wItemPtr,wItemKind,wItemSelect,wItemAtts,wItemInfo,wItems,wItemShow,wItemPos}) focusNr wPtr key keyCode parent_pos tb
		| focusNr <> wItemNr
			| not wItemShow || not wItemSelect
				= (False,False,WItemHandle itemH,tb)
			# new_parent_pos = case wItemKind of
								IsCompoundControl -> movePoint wItemPos parent_pos
								IsLayoutControl -> movePoint wItemPos parent_pos
								_ -> parent_pos
			# (found,ok,wItems,tb)	= okControlsKeyboard wItems focusNr wPtr key keyCode info new_parent_pos tb
			= (found,ok,WItemHandle {itemH & wItems = wItems},tb)
		| wItemKind == IsEditControl && wItemShow && wItemSelect
			| getKeyboardStateKeyState key == KeyUp			// willen wel doorgeven aan keyboardfun???
				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
			| (isSpecialKey key) && (not (validEditControlInput keyCode))
				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
			# item_pos = movePoint wItemPos parent_pos
			# clipRect		= posSizeToRect item_pos itemH.wItemSize
			# (string,tb)	= editControlKeyboardFunction wPtr clipRect wItemPtr keyCode tb
			# editInfo		= getWItemEditInfo wItemInfo
			# editInfo		= {editInfo & editInfoText = string}
			# itemH			= {itemH & wItemInfo = EditInfo editInfo}
			= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
		| wItemKind == IsPopUpControl && wItemShow && wItemSelect && isEditable
			| getKeyboardStateKeyState key == KeyUp			// willen wel doorgeven aan keyboardfun???
				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
			| (isSpecialKey key) && (not (validEditControlInput keyCode))
				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
			# popupInfo		= getWItemPopUpInfo wItemInfo
			# editInfo		= fromJust popupInfo.popUpInfoEdit
			# editPtr		= editInfo.popUpEditPtr
			# item_pos = movePoint wItemPos parent_pos
			# clipRect		= posSizeToRect item_pos itemH.wItemSize
			# (string,tb)	= comboControlKeyboardFunction wPtr clipRect editPtr keyCode tb
			# editInfo		= {editInfo & popUpEditText = string}
			# popupInfo		= {popupInfo & popUpInfoEdit = Just editInfo}
			# itemH			= {itemH & wItemInfo = PopUpInfo popupInfo}
			# tb				= SetCtlValue wItemPtr 0 tb	// set popup menu to entry 0...
			= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
		| wItemShow && wItemSelect && isEditable
			| getKeyboardStateKeyState key == KeyUp			// willen wel doorgeven aan keyboardfun???
				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
//			| (isSpecialKey key) && (not (validEditControlInput keyCode))
//				= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
//			# popupInfo		= getWItemPopUpInfo wItemInfo
//			# editInfo		= fromJust popupInfo.popUpInfoEdit
//			# editPtr		= editInfo.popUpEditPtr
//			# clipRect		= posSizeToRect itemH.wItemPos itemH.wItemSize
//			# (string,tb)	= editControlKeyboardFunction wPtr clipRect editPtr keyCode tb
//			# editInfo		= {editInfo & popUpEditText = string}
//			# popupInfo		= {popupInfo & popUpInfoEdit = Just editInfo}
//			# itemH			= {itemH & wItemInfo = PopUpInfo popupInfo}
			= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
		= (True,okControlKeyboardAtt,WItemHandle itemH,tb)
	where
		isEditable				= contains isControlKeyboard wItemAtts
		(filter,selectState,_)
					= getControlKeyboardAtt (snd (cselect isControlKeyboard (ControlKeyboard (const False) Unable undef) wItemAtts))
		okControlKeyboardAtt
					= filter key && selectState == Able

		isSpecialKey (SpecialKey _ _ _) = True
		isSpecialKey _ = False

		validEditControlInput key	// up/down/enter eigenlijk alleen als multiline edit???
			| key == '\036'  = True // arrows
			| key == '\037'  = True
			| key == '\034'  = True
			| key == '\035'  = True
			| key == '\010'  = True	// backspace
	//		| key == '\033'  = True // clear
			| key == '\177'  = True // del
			= False

		comboControlKeyboardFunction wPtr clipRect hTE keyCode tb
//			# tb			= appClipport wPtr clipRect (TEKey keyCode hTE) tb
			# tb			= appClipport wPtr clipRect handleKey tb
			= osGetPopUpControlText wPtr hTE tb
		where
			(mess,mods)  = info
			handleKey tb
				# (part,tb) = HandleControlKey hTE (getMacCode mess) (mess bitand 255) mods tb
				= trace_n` ("HandlePopupKey",hTE,part,mods) tb

		editControlKeyboardFunction wPtr clipRect hTE keyCode tb
//			# tb			= appClipport wPtr clipRect (TEKey keyCode hTE) tb
			# tb			= appClipport wPtr clipRect handleKey tb
			= osGetEditControlText wPtr hTE tb
		where
			(mess,mods)  = info
			handleKey tb
				# (part,tb) = HandleControlKey hTE (getMacCode mess) (mess bitand 255) mods tb
				= trace_n` ("HandleEditKey",hTE,part,mods) tb
	
	okControlKeyboard (WListLSHandle itemHs) focusNr wPtr key keyCode parent_pos tb
		# (found,ok,itemHs,tb)	= okControlsKeyboard itemHs focusNr wPtr key keyCode info parent_pos tb
		= (found,ok,WListLSHandle itemHs,tb)
	okControlKeyboard (WChangeLSHandle wChH=:{wChangeItems}) focusNr wPtr key keyCode parent_pos tb
		# (found,ok,wChangeItems,tb)	= okControlsKeyboard wChangeItems focusNr wPtr key keyCode info parent_pos tb
		= (found,ok,WChangeLSHandle {wChH & wChangeItems = wChangeItems},tb)
	okControlKeyboard (WExtendLSHandle wExH=:{wExtendItems}) focusNr wPtr key keyCode parent_pos tb
		# (found,ok,wExtendItems,tb)	= okControlsKeyboard wExtendItems focusNr wPtr key keyCode info parent_pos tb
		= (found,ok,WExtendLSHandle {wExH & wExtendItems = wExtendItems},tb)

//wil InputTrack tiepe uit iostate halen en in os-laag stoppen...lastig wordt op veel meer plaatsen gebruikt...
validateKeyTracking :: !OSWindowPtr !OSWindowPtr !Int !OSEvent !*(PSt .l) -> (!Bool,!Bool,!KeyState,!Char,!Int,!*(PSt .l))
validateKeyTracking wPtr cPtr cNr event=:(ok,keyEvent,newKeyMessage,i,h,v,mods) pState
	#! pState = trace_n ("validateKeyTracking: 0: "+++showEvent event) pState
/* help niet...
	# (vis,pState) = accPIO (accIOToolbox (IsControlVisible cPtr)) pState
	| vis == 0
		= (False,False,KeyDown False,newASCII,newCode,pState)
*/
	# (inputTrack,pState)	= accPIO ioStGetInputTrack pState
	| keyEvent == KeyDownEvent
		| not (trackingKeyboard wPtr cNr inputTrack)
//			# inputTrack	= Just {itWindow=wPtr,itControl=cNr,itKind={itkMouse=False,itkKeyboard=True}}
			# inputTrack	= trackKeyboard wPtr cNr newKeyMessage inputTrack
			# pState		= appPIO (ioStSetInputTrack inputTrack) pState
			#! pState		= trace_n ("validateKeyTracking: 1") pState
			= (True,False,KeyDown False,newASCII,newCode,pState)
		//XXX--> wil hier True genereren maar moet dan eerst  snel KeyUp voor oude genereren??!!??
		# oldKeyMessage		= (fromJust inputTrack).itKind.itkChar
		# oldChar			= getASCII oldKeyMessage
		# oldCode			= getMacCode oldKeyMessage
		# inputTrack		= untrackKeyboard inputTrack
		# pState			= appPIO (ioStSetInputTrack inputTrack) pState
		#! pState			= trace_n ("validateKeyTracking: 2") pState
//		= (False,undef,pState)	// van de getrackte key...
		= (True,True,KeyUp,oldChar,oldCode,pState)	// van de getrackte key...
	| isJust inputTrack && keyEvent == KeyUpEvent
		# pState			= appPIO (ioStSetInputTrack Nothing) pState
		#! pState			= trace_n ("validateKeyTracking: 3") pState
		= (True,False,KeyUp,newASCII,newCode,pState)
	# pState				= appPIO (ioStSetInputTrack inputTrack) pState
	#! pState				= trace_n ("validateKeyTracking: 4") pState
	| keyEvent == KeyUpEvent
		// should ignore untracked keyups...
		= (False,False,KeyUp,newASCII,newCode,pState)
	// auto repeat key...
	// moet ook nog checken of repeat van getrackede key is...
	= (True,False,KeyDown True,newASCII,newCode,pState)
where
	newASCII	= getASCII newKeyMessage
	newCode		= getMacCode newKeyMessage

pressCancelButton mods wsH=:{wshHandle= Just wshH=:{wlsHandle=wlsH=:{whCancelId}}} //pState
	| isNothing whCancelId
		= (Nothing,wsH)
	# (wids,wsH)	= getWindowStateHandleWIDS wsH
	# info			= WindowCANCEL wids
	= (Just info,wsH)
pressCancelButton mods wsH=:{wshHandle= Nothing} //pState
	= abort "pressCancelButton: unexpected placeholder"

pressDefaultButton return mods wsH=:{wshHandle= Just wshH=:{wlsHandle=wlsH=:{whDefaultId}}} // pState
	| not return
		= (False,Nothing,wsH)
	| isNothing whDefaultId
		= (True,Nothing,wsH)
	# (wids,wsH)	= getWindowStateHandleWIDS wsH
	# info			= WindowOK wids
	= (True,Just info,wsH)
pressDefaultButton return mods wsH=:{wshHandle= Nothing} // pState
	= abort "pressDefaultButton: unexpected placeholder"

//--
///

getControlsItemNr :: !OSWindowPtr !*[*WElementHandle .ls .pst] -> (!Bool,!(!Int,!ControlKind),!*[*WElementHandle .ls .pst])
getControlsItemNr itemPtr [itemH:itemHs]
	# (found,result,itemH)				= getControlItemNr itemPtr itemH
	| found
		= (found,result,[itemH:itemHs])
	| otherwise
		# (found,result,itemHs)			= getControlsItemNr itemPtr itemHs
		= (found,result,[itemH:itemHs])
where
	getControlItemNrFromwItems itemPtr (WItemHandle itemH=:{wItems})
		# (found,result,items)			= getControlsItemNr itemPtr wItems
		= (found,result,WItemHandle {itemH & wItems = items})
	getControlItemNrFromwItems itemPtr _ = abort "getControlItemNrFromwItems: called with non-item handle"

	getControlItemNr :: !Int !(WElementHandle .ls .pst) -> (!Bool,!(!OSWindowPtr,!ControlKind),!(WElementHandle .ls .pst))
	getControlItemNr itemPtr (WItemHandle itemH=:{wItems,wItemNr,wItemKind,wItemPtr})
		| itemPtr == wItemPtr
			= (True,(wItemNr,wItemKind),WItemHandle itemH)
		= case wItemKind of
			IsCompoundControl			-> getControlItemNrFromwItems itemPtr (WItemHandle itemH)
			IsLayoutControl				-> getControlItemNrFromwItems itemPtr (WItemHandle itemH)
			_							-> (False,(0,IsButtonControl),WItemHandle itemH)
				
	getControlItemNr cPtr (WListLSHandle itemHs)
		# (found,result,itemHs)		= getControlsItemNr cPtr itemHs
		= (found,result,WListLSHandle itemHs)
	
	getControlItemNr cPtr (WExtendLSHandle wExH=:{wExtendItems=itemHs})
		# (found,result,itemHs)		= getControlsItemNr cPtr itemHs
		= (found,result,WExtendLSHandle {wExH & wExtendItems=itemHs})
	
	getControlItemNr cPtr (WChangeLSHandle wChH=:{wChangeItems=itemHs})
		# (found,result,itemHs)		= getControlsItemNr cPtr itemHs
		= (found,result,WChangeLSHandle {wChH & wChangeItems=itemHs})

getControlsItemNr _ _
	= (False,(0,IsButtonControl),[])

//--
import osevent

/*	bufferKeyboardEvents buffers the events in the OSEvents environment.
*/
bufferKeyboardEvents :: !OSEvent !(IOSt .l) -> IOSt .l
bufferKeyboardEvents event ioState
	# (osEvents,ioState)	= ioStGetEvents ioState
	  osEvents				= osInsertEvents [event] osEvents
	= ioStSetEvents osEvents ioState


//--

getControlFocusPtr :: !OSWindowPtr !*(WindowStateHandle .a) -> *(!Int,!(!Int,!ControlKind),!*(WindowStateHandle .a));
getControlFocusPtr wPtr wsH
/*
	# (keyFocus,wsH)	= getWindowStateHandleKeyFocus wsH
	# (focusItem,keyFocus)
						= getCurrentFocusItem keyFocus
	# wsH				= setWindowStateHandleKeyFocus keyFocus wsH
	| isNothing focusItem
		= (0,(OSNoWindowPtr,IsButtonControl),wsH)
	# itemNr			= fromJust focusItem
//	# {wshHandle = Just wlsH=:{wlsHandle=wH}}
//						= wsH
	# wlsH = case wsH.wshHandle of
				(Just wlsH) -> wlsH
				_ -> abort "getControlFocusPtr unexpected placeholder"
	# wH = wlsH.wlsHandle
	# (found,result,itemHs)
						= getControlsItemPtr itemNr wH.whItems
	# wsH				= {wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}}
	= (itemNr,result,wsH)
*/
	# ((err,itemPtr),_)	= GetKeyboardFocus wPtr OSNewToolbox
	| itemPtr == 0
		= oldControlFocusPtr wPtr wsH
	# wlsH = case wsH.wshHandle of
				(Just wlsH) -> wlsH
				_ -> abort "getControlFocusPtr unexpected placeholder"
	# wH = wlsH.wlsHandle
	# (found,(itemNr,itemKind),itemHs)
						= getControlsItemNr itemPtr wH.whItems
	# wsH				= {wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}}
	= (itemNr,(itemPtr,itemKind),wsH)

oldControlFocusPtr wPtr wsH
	# (keyFocus,wsH)	= getWindowStateHandleKeyFocus wsH
	# (focusItem,keyFocus)
						= getCurrentFocusItem keyFocus
	# wsH				= setWindowStateHandleKeyFocus keyFocus wsH
	| isNothing focusItem
		= (0,(OSNoWindowPtr,IsButtonControl),wsH)
	# itemNr			= fromJust focusItem
//	# {wshHandle = Just wlsH=:{wlsHandle=wH}}
//						= wsH
	# wlsH = case wsH.wshHandle of
				(Just wlsH) -> wlsH
				_ -> abort "getControlFocusPtr unexpected placeholder"
	# wH = wlsH.wlsHandle
	# (found,result,itemHs)
						= getControlsItemPtr itemNr wH.whItems
	# wsH				= {wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}}
	= (itemNr,result,wsH)


getControlsItemPtr :: !Int !*[*WElementHandle .ls .pst] -> (!Bool,!(!OSWindowPtr,!ControlKind),!*[*WElementHandle .ls .pst])
getControlsItemPtr itemNr [itemH:itemHs]
	# (found,result,itemH)				= getControlItemPtr itemNr itemH
	| found
		= (found,result,[itemH:itemHs])
	| otherwise
		# (found,result,itemHs)			= getControlsItemPtr itemNr itemHs
		= (found,result,[itemH:itemHs])
where
	getControlItemPtrFromwItems itemNr (WItemHandle itemH=:{wItems})
		# (found,result,items)			= getControlsItemPtr itemNr wItems
		= (found,result,WItemHandle {itemH & wItems = items})
	getControlItemPtrFromwItems itemNr _ = abort "getControlItemPtrFromwItems: called with non-item handle"

	getControlItemPtr :: !Int !(WElementHandle .ls .pst) -> (!Bool,!(!OSWindowPtr,!ControlKind),!(WElementHandle .ls .pst))
	getControlItemPtr itemNr (WItemHandle itemH=:{wItems,wItemNr,wItemSelect,wItemInfo,wItemKind,wItemPtr,wItemPos,wItemSize})
		| itemNr == wItemNr
			= (True,(wItemPtr,wItemKind),WItemHandle itemH)
		= case wItemKind of
			IsCompoundControl			-> getControlItemPtrFromwItems itemNr (WItemHandle itemH)
			IsLayoutControl				-> getControlItemPtrFromwItems itemNr (WItemHandle itemH)
			_							-> (False,(0,IsButtonControl),WItemHandle itemH)
				
	getControlItemPtr cPtr (WListLSHandle itemHs)
		# (found,result,itemHs)		= getControlsItemPtr cPtr itemHs
		= (found,result,WListLSHandle itemHs)
	
	getControlItemPtr cPtr (WExtendLSHandle wExH=:{wExtendItems=itemHs})
		# (found,result,itemHs)		= getControlsItemPtr cPtr itemHs
		= (found,result,WExtendLSHandle {wExH & wExtendItems=itemHs})
	
	getControlItemPtr cPtr (WChangeLSHandle wChH=:{wChangeItems=itemHs})
		# (found,result,itemHs)		= getControlsItemPtr cPtr itemHs
		= (found,result,WChangeLSHandle {wChH & wChangeItems=itemHs})

getControlsItemPtr _ _
	= (False,(0,IsButtonControl),[])

//===

nextKeyInputFocus wPtr wsH windows pState
	# (err1,pState)	= accPIO (accIOToolbox (AdvanceKeyboardFocus wPtr)) pState
	# ((err2,itemPtr),pState)	= accPIO (accIOToolbox (GetKeyboardFocus wPtr)) pState
	# pState = trace_n` ("nextKeyInputFocus",wPtr,err1,err2) pState
	| itemPtr == 0
 		= (True, Nothing,Nothing,pState)
	# (wids,wsH)		= getWindowStateHandleWIDS wsH
	# wlsH = case wsH.wshHandle of
				(Just wlsH) -> wlsH
				_ -> abort "nextKeyInputFocus unexpected placeholder"
	# wH = wlsH.wlsHandle
	# (found,(itemNr,_),itemHs)
						= getControlsItemNr itemPtr wH.whItems
	# wsH				= {wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}}
	# windows			= setWindowHandlesWindow wsH windows
	# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	# deviceevent		= ControlGetKeyFocus
							{ ckfWIDS		= wids
							, ckfItemNr		= itemNr
							, ckfItemPtr	= itemPtr
							}
	= (True, Nothing,Just deviceevent,pState)


/*
	# pState = trace_n ("keyboardevent","tabevent") pState
	# (keyFocus,wsH)	= getWindowStateHandleKeyFocus wsH
	# (focusItem,keyFocus)
						= getCurrentFocusItem keyFocus
	| isNothing focusItem
		#! numItems = length keyFocus.kfItems
		# pState = trace_n ("keyboardevent","noFocusItem",wPtr,numItems) pState
		# wsH			= setWindowStateHandleKeyFocus keyFocus wsH
		# windows		= setWindowHandlesWindow wsH windows
		# pState		= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		= (True, Nothing,Nothing,pState)
	# (nextFocus,keyFocus)
						= setNextFocusItem focusItem keyFocus
	| isNothing nextFocus
		# wsH			= setWindowStateHandleKeyFocus keyFocus wsH
		# windows		= setWindowHandlesWindow wsH windows
		# pState		= appPIO (ioStSetDevice (WindowSystemState windows)) pState
		#! pState = trace_n ("keyboardevent","noNextFocus") pState
		= (True, Nothing,Nothing,pState)
	// currently clipRect is unused by osSetFocus functions so can safely pass dummy value
	// if and when we add focus outlines we'll need to pass correct rects...
	# clipRect = {rleft=0,rtop=0,rright=0,rbottom=0}
	# (wsH,pState)		= changeFocus True focusItem nextFocus wPtr clipRect wsH pState
	# wsH				= setWindowStateHandleKeyFocus keyFocus wsH
	# (wids,wsH)		= getWindowStateHandleWIDS wsH
	# wlsH = case wsH.wshHandle of
				(Just wlsH) -> wlsH
				_ -> abort "windowKeyboardIO unexpected placeholder"
	# wH = wlsH.wlsHandle

	# (found,(itemPtr,_),itemHs)
						= getControlsItemPtr (fromJust nextFocus) wH.whItems
	# wsH				= {wsH & wshHandle=Just {wlsH & wlsHandle={wH & whItems=itemHs}}}
	# windows			= setWindowHandlesWindow wsH windows
	# pState			= appPIO (ioStSetDevice (WindowSystemState windows)) pState
	# deviceevent		= ControlGetKeyFocus {ckfWIDS=wids,ckfItemNr=fromJust nextFocus,ckfItemPtr=itemPtr}
	#! pState = trace_n ("keyboardevent","controlgetkeyfocus") pState
	= (True, Nothing,Just deviceevent,pState)
*/

/*
ControlPartCode HandleControlKey (
    ControlRef inControl, 
    SInt16 inKeyCode, 
    SInt16 inCharCode, 
    EventModifiers inModifiers
);
*/
HandleControlKey :: !OSWindowPtr !Int !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
HandleControlKey _ _ _ _ _ = code {
	ccall HandleControlKey "PIIII:I:I"
	}

AdvanceKeyboardFocus :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
AdvanceKeyboardFocus _ _ = code {
	ccall AdvanceKeyboardFocus "PI:I:I"
	}

GetKeyboardFocus :: !OSWindowPtr !*OSToolbox -> (!(!Int,!OSWindowPtr),!*OSToolbox)
GetKeyboardFocus _ _ = code {
	ccall GetKeyboardFocus "PI:II:I"
	}

IsControlVisible :: !OSWindowPtr !*OSToolbox -> (!Int,!*OSToolbox)
IsControlVisible _ _ = code {
	ccall IsControlVisible "PI:I:I"
	}
