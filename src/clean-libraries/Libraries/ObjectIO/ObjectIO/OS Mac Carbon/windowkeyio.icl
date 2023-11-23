implementation module windowkeyio


import	StdInt, StdBool, StdChar, StdFunc, StdList, StdTuple, StdArray
import	textedit
from	events				import	KeyDownEvent, AutoKeyEvent, KeyUpEvent
from	quickdraw			import	QClipRect
from	windows				import	FrontWindow
import	commondef, id, key, keyfocus, memoryaccess, roundrobin, texteditaccess, windowaccess
from	controldefaccess	import	iscontrolfunction,		getcontrolfunction, 
									iscontrolmodsfunction,	getcontrolmodsfunction, 
									iscontrolkeyboard,		getcontrolkeyboardinfo
from	controllayout		import	getWindowContentRect, getCompoundContentRect
from	iostate				import	accIOToolbox, appIOToolbox, getIOToolbox, setIOToolbox, 
									IOStGetKeyTrack, IOStSetKeyTrack, KeyTrack
from	StdPSt				import	accPIO, appPIO, appListPIO
from	windowdefaccess		import	iswindowkeyboard, getwindowkeyboardinfo
from	windowdraw			import	GrafPtr, openDrawing, closeDrawing, openClipDrawing, closeClipDrawing, hiliteDefaultButton


/*	Handling a (KeyDown/KeyUp/AutoKey)Event for a window.
*/
windowKeyIO :: !Event !(PSt .l .p) -> PSt .l .p
windowKeyIO event=:(_,keyEvent,message,_,_,_,mods) pState
#	(wPtr,ioState)						= accIOToolbox FrontWindow pState.io
	(mine,dsH,ioState)					= IOStGetDialog (toWID wPtr) ioState
	pState								= {pState & io=ioState}
|	not mine
=	pState
#	(kind,isAble,dsH)					= (\dialogH=:(DialogLSHandle {dlsHandle={dhKind,dhSelect}})
										->(dhKind,dhSelect,dialogH)) dsH
|	not isAble
=	pState
#	isDialog							= kind==IsDialogWindow
|	isDialog && returnStill				= pState
|	isDialog && commandPeriod			= pressCancelButton mods dsH pState
#	theChar								= getASCII message
|	isDialog && theChar=='\t'			= nextKeyInputFocus keyEvent dsH pState
#	(pressed,pState)					= pressDefaultButton return mods dsH pState
|	pressed
=	pState
#	(isValid,theChar,pState)			= validateKeyTracking event pState
|	not isValid
=	pState
#	(found,dsH,ioState)					= IOStGetDialog (toWID wPtr) pState.io
	pState								= {pState & io=ioState}
|	not found
=	pState
=	pState2
	with
		pState1							= appPIO (IOStReplaceDialog dsH1) pState
		(dsH1,pState2)					= handleKeyboardFunction theChar event dsH pState1
where
	(return,returnStill,commandPeriod)	= KeyEventInfo keyEvent message mods
	
	nextKeyInputFocus :: !Int !(DialogStateHandle (PSt .l .p)) !(PSt .l .p) -> PSt .l .p
	nextKeyInputFocus keyEvent dsH=:(DialogLSHandle dlsH=:{dlsHandle=dH=:{dhPtr,dhKeyFocus,dhItems}}) pState
	#	focusItem				= getCurrentFocusItem dhKeyFocus
	|	keyEvent==KeyUpEvent || isNothing focusItem
	=	appPIO (IOStReplaceDialog dsH) pState
	#	(nextFocus,kf)			= setNextFocusItem focusItem dhKeyFocus
	|	isNothing nextFocus
	=	appPIO (IOStReplaceDialog dsH) pState
	#	curNr					= fromJust focusItem
		nextNr					= fromJust nextFocus
		(tb,pState)				= accPIO getIOToolbox pState
		(size,tb)				= WindowGetSize dhPtr tb
		contentRect				= getWindowContentRect (isJust dH.dhHScroll) (isJust dH.dhVScroll) (SizeToRect size)
		(items,tb)				= selectInputItem curNr nextNr dhPtr contentRect dhItems tb
		dsH						= DialogLSHandle {dlsH & dlsHandle={dH & dhItems=items,dhKeyFocus=kf}}
		pState					= appListPIO [setIOToolbox tb,IOStReplaceDialog dsH] pState
	=	pState
	where
		selectInputItem :: !Int !Int !WindowPtr !Rect ![DElementHandle .ls .ps] !*Toolbox -> (![DElementHandle .ls .ps],!*Toolbox)
		selectInputItem curNr newNr wPtr clipRect [itemH:itemHs] tb
		#	(itemH, tb)		= selectInputItem` curNr newNr wPtr clipRect itemH  tb
			(itemHs,tb)		= selectInputItem  curNr newNr wPtr clipRect itemHs tb
		=	([itemH:itemHs],tb)
		where
			selectInputItem` :: !Int !Int !WindowPtr !Rect !(DElementHandle .ls .ps) !*Toolbox -> (!DElementHandle .ls .ps,!*Toolbox)
			selectInputItem` curNr newNr wPtr clipRect (DListLSHandle itemHs) tb
			#	(itemHs,tb)	= selectInputItem curNr newNr wPtr clipRect itemHs tb
			=	(DListLSHandle itemHs,tb)
			selectInputItem` curNr newNr wPtr clipRect (DExtendLSHandle dExH=:{dExtendItems}) tb
			#	(itemHs,tb)	= selectInputItem curNr newNr wPtr clipRect dExtendItems tb
			=	(DExtendLSHandle {dExH & dExtendItems=itemHs},tb)
			selectInputItem` curNr newNr wPtr clipRect (DChangeLSHandle dChH=:{dChangeItems}) tb
			#	(itemHs,tb)	= selectInputItem curNr newNr wPtr clipRect dChangeItems tb
			=	(DChangeLSHandle {dChH & dChangeItems=itemHs},tb)
			selectInputItem` curNr newNr wPtr clipRect (DItemHandle itemH) tb
			#	(itemH,tb)	= selectInputItem`` curNr newNr wPtr clipRect itemH tb
			=	(DItemHandle itemH,tb)
			where
				selectInputItem`` :: !Int !Int !WindowPtr !Rect !(DItemHandle .ls .ps) !*Toolbox -> (!DItemHandle .ls .ps,!*Toolbox)
				selectInputItem`` curNr newNr wPtr clipRect itemH=:{dItemKind=IsEditControl,dItemNr,dItemId,dItemHandle} tb
				#	tb				= deactivateInputItem curNr dItemNr wPtr clipRect dItemHandle tb
					tb				= activateInputItem   newNr dItemNr wPtr clipRect dItemHandle tb
				=	(itemH,tb)
				where
					deactivateInputItem :: !Int !Int !WindowPtr !Rect !TEHandle !*Toolbox -> *Toolbox
					deactivateInputItem curNr myNr wPtr clipRect hTE tb
					|	curNr<>myNr
					=	tb
					#	(port,rgn,tb)	= openClipDrawing wPtr	tb
						tb				= QClipRect clipRect	tb
						tb				= TEDeactivate hTE tb
						tb				= closeClipDrawing port rgn tb
					=	tb
					
					activateInputItem :: !Int !Int !WindowPtr !Rect !TEHandle !*Toolbox -> *Toolbox
					activateInputItem newNr myNr wPtr clipRect hTE tb
					|	newNr<>myNr
					=	tb
					#	(port,rgn,tb)	= openClipDrawing wPtr	tb
						tb				= QClipRect clipRect	tb
						tb				= TEActivate hTE tb
						tb				= TESetSelect 0 32767 hTE tb
						tb				= closeClipDrawing port rgn tb
					=	tb
				selectInputItem`` curNr newNr wPtr clipRect itemH=:{dItemKind=IsCompoundControl,dItemParts} tb
				#	(itemHs,tb)		= selectInputItem curNr newNr wPtr clipRect1 dItemParts tb
				=	({itemH & dItemParts=itemHs},tb)
				where
					info			= getDItemCompoundInfo (fromJust itemH.dItemInfo)
					itemRect		= PosSizeToRect itemH.dItemPos itemH.dItemSize
					clipRect1		= IntersectRects clipRect (getCompoundContentRect hasHScroll hasVScroll itemRect)
					hasHScroll		= isJust info.compoundHScroll
					hasVScroll		= isJust info.compoundVScroll
				selectInputItem`` _ _ _ _ itemH tb
				=	(itemH,tb)
		selectInputItem _ _ _ _ _ tb
		=	([],tb)
	
	handleKeyboardFunction :: !Char !Event !(DialogStateHandle (PSt .l .p)) (PSt .l .p)
										-> (!DialogStateHandle (PSt .l .p),  PSt .l .p)
	handleKeyboardFunction keyCode event dsH=:(DialogLSHandle dlsH=:{dlsHandle=dH=:{dhKeyFocus}}) pState
	#	focusItem						= getCurrentFocusItem dhKeyFocus
	|	isNothing focusItem
	=	handleWindowKeyboard keyCode event dsH pState
	=	handleControlKeyboard (fromJust focusItem) keyCode event dsH pState
	where
		handleWindowKeyboard :: !Char !Event !(DialogStateHandle (PSt .l .p)) (PSt .l .p)
										  -> (!DialogStateHandle (PSt .l .p),  PSt .l .p)
		handleWindowKeyboard keyCode event dsH=:(DialogLSHandle dlsH=:{dlsState,dlsHandle=dH}) pState
		#	(_,what,message,_,_,_,mods)	= event
			(hasKeys,keys)				= Select iswindowkeyboard (WindowKeyboard (K False) Unable K`) dH.dhAtts
			(filter,select,keysF)		= getwindowkeyboardinfo keys
		|	not hasKeys || not (enabled select)
		=	(dsH,pState)
		#	macCode						= (message>>8) bitand 255
			keyState					= keyEventToKeyState what
			modifiers					= IntToModifiers mods
			key							= if (isSpecialKey macCode)
											 (SpecialKey (toSpecialKey macCode) keyState modifiers)
											 (CharKey    keyCode                keyState)
		|	not (filter key)
		=	(dsH,pState)
		#	(ls, pState)				= keysF key (dlsState,pState)
		=	(DialogLSHandle {dlsH & dlsState=ls},pState)
		
		handleControlKeyboard :: !Int !Char !Event !(DialogStateHandle (PSt .l .p)) (PSt .l .p)
												-> (!DialogStateHandle (PSt .l .p),  PSt .l .p)
		handleControlKeyboard focusNr keyCode event (DialogLSHandle {dlsState=ls,dlsHandle=dH=:{dhPtr,dhItems}}) pState
		#	(tb,pState)					= accPIO getIOToolbox pState
			(size,tb)					= WindowGetSize dhPtr tb
			contentRect					= getWindowContentRect (isJust dH.dhHScroll) (isJust dH.dhVScroll) (SizeToRect size)
			ableContext					= True
			(_,tb,items,(ls,pState))	= controlsKeyboard focusNr dhPtr contentRect keyCode event ableContext tb dhItems (ls,pState)
			pState						= appPIO (setIOToolbox tb) pState
			dsH							= DialogLSHandle {dlsState=ls,dlsHandle={dH & dhItems=items}}
		=	(dsH,pState)
		where
			controlsKeyboard :: !Int !WindowPtr !Rect !Char !Event !Bool !*Toolbox ![DElementHandle .ls .ps] (.ls,.ps)
															   -> (!Bool,!*Toolbox,![DElementHandle .ls .ps],(.ls,.ps))
			controlsKeyboard focusNr wPtr clipRect keyCode event ableContext tb [itemH:itemHs] (ls,ps)
			#	(done,tb,itemH,(ls,ps))	= controlKeyboard focusNr wPtr clipRect keyCode event ableContext tb itemH (ls,ps)
			|	done
			=	(done,tb,[itemH:itemHs],(ls,ps))
			#	(done,tb,itemHs,(ls,ps))= controlsKeyboard focusNr wPtr clipRect keyCode event ableContext tb itemHs (ls,ps)
			=	(done,tb,[itemH:itemHs],(ls,ps))
			where
				controlKeyboard :: !Int !WindowPtr !Rect !Char !Event !Bool !*Toolbox !(DElementHandle .ls .ps) (.ls,.ps)
																  -> (!Bool,!*Toolbox, !DElementHandle .ls .ps, (.ls,.ps))
				controlKeyboard focusNr wPtr clipRect keyCode event ableContext tb (DListLSHandle itemHs) (ls,ps)
				#	(done,tb,itemHs,(ls,ps))			= controlsKeyboard focusNr wPtr clipRect keyCode event ableContext tb itemHs (ls,ps)
				=	(done,tb,DListLSHandle itemHs,(ls,ps))
				controlKeyboard focusNr wPtr clipRect keyCode event ableContext tb (DExtendLSHandle dExH=:{dExtendLS,dExtendItems=itemHs}) (ls,ps)
				#	(done,tb,itemHs,((dExtendLS,ls),ps))= controlsKeyboard focusNr wPtr clipRect keyCode event ableContext tb itemHs ((dExtendLS,ls),ps)
				=	(done,tb,DExtendLSHandle {dExH & dExtendLS=dExtendLS,dExtendItems=itemHs},(ls,ps))
				controlKeyboard focusNr wPtr clipRect keyCode event ableContext tb (DChangeLSHandle dChH=:{dChangeLS,dChangeItems=itemHs}) (ls,ps)
				#	(done,tb,itemHs,(dChangeLS,ps))		= controlsKeyboard focusNr wPtr clipRect keyCode event ableContext tb itemHs (dChangeLS,ps)
				=	(done,tb,DChangeLSHandle {dChH & dChangeLS=dChangeLS,dChangeItems=itemHs},(ls,ps))
				controlKeyboard focusNr wPtr clipRect keyCode event ableContext tb (DItemHandle itemH) (ls,ps)
				#	(done,tb,itemH,(ls,ps))				= controlKeyboard` focusNr wPtr clipRect keyCode event ableContext tb itemH (ls,ps)
				=	(done,tb,DItemHandle itemH,(ls,ps))
				where
					controlKeyboard` :: !Int !WindowPtr !Rect !Char !Event !Bool !*Toolbox !(DItemHandle .ls .ps) (.ls,.ps)
																	   -> (!Bool,!*Toolbox, !DItemHandle .ls .ps, (.ls,.ps))
					controlKeyboard` focusNr wPtr clipRect keyCode event ableContext tb itemH=:{dItemKind=IsEditControl,dItemNr,dItemAtts} (ls,ps)
					|	focusNr<>dItemNr
					=	(False,tb,itemH,(ls,ps))
					|	not itemH.dItemSelect || not ableContext
					=	(True,tb,itemH,(ls,ps))
					|	not (validEditControlInput keyCode event)
					=	(True,tb,itemH,(ls,ps))
					#	tb					= clippedTEKey wPtr clipRect itemH.dItemHandle keyCode tb
						hTE					= itemH.dItemHandle
						(charsH,tb)			= TEGetText hTE tb
						(size,tb)			= TEGetTextSize hTE tb
						(string,tb)			= handle_to_string charsH size tb
						itemH				= {itemH & dItemText=string}
						(filter,able,keysF)	= getcontrolkeyboardinfo (snd (Select iscontrolkeyboard (ControlKeyboard (K False) Unable K`) dItemAtts))
					|	not (enabled able)
					=	(True,tb,itemH,(ls,ps))
					#	(_,what,message,_,_,_,mods)
											= event
						macCode				= getMacCode message
						keyState			= keyEventToKeyState what
						modifiers			= IntToModifiers mods
						key					= if (isSpecialKey macCode)
												 (SpecialKey (toSpecialKey macCode) keyState modifiers)
												 (CharKey    keyCode                keyState)
					|	not (filter key)
					=	(True,tb,itemH,(ls,ps))
					=	(True,tb,itemH,keysF key (ls,ps))
					where
						validEditControlInput :: !Char !Event -> Bool
						validEditControlInput keyCode event=:(_,what,message,_,_,_,_)
						|	what==KeyUpEvent			= False
						|	not (isSpecialKey macCode)	= True
						|	keyCode=='\036'				= True
						|	keyCode=='\037'				= True
						|	keyCode=='\034'				= True
						|	keyCode=='\035'				= True
						|	keyCode=='\177'				= True
														= False
						where
							macCode						= getMacCode message
							
					//	clippedTEKey before calling TrackControl sets the clipping region of the window.
						clippedTEKey :: !WindowPtr !Rect !TEHandle !Char !*Toolbox -> *Toolbox
						clippedTEKey wPtr clipRect hTE keyCode tb
						#	(port,rgn,tb)	= openClipDrawing wPtr	tb
							tb				= QClipRect clipRect	tb
							tb				= TEKey keyCode hTE		tb
							tb				= closeClipDrawing port rgn tb
						=	tb
					controlKeyboard` focusNr wPtr clipRect keyCode event ableContext tb itemH=:{dItemKind=IsCustomControl,dItemNr,dItemAtts} (ls,ps)
					|	focusNr<>dItemNr
					=	(False,tb,itemH,(ls,ps))
					|	not itemH.dItemSelect || not ableContext
					=	(True,tb,itemH,(ls,ps))
					#	(filter,able,keysF)	= getcontrolkeyboardinfo (snd (Select iscontrolkeyboard (ControlKeyboard (K False) Unable K`) dItemAtts))
					|	not (enabled able)
					=	(True,tb,itemH,(ls,ps))
					#	(_,what,message,_,_,_,mods)
											= event
						macCode				= getMacCode message
						keyState			= keyEventToKeyState what
						modifiers			= IntToModifiers mods
						key					= if (isSpecialKey macCode)
												 (SpecialKey (toSpecialKey macCode) keyState modifiers)
												 (CharKey    keyCode                keyState)
					|	not (filter key)
					=	(True,tb,itemH,(ls,ps))
					=	(True,tb,itemH,keysF key (ls,ps))
					controlKeyboard` focusNr wPtr clipRect keyCode event ableContext tb itemH=:{dItemKind=IsCompoundControl,dItemParts} (ls,ps)
					#	ableContext				= ableContext && itemH.dItemSelect
						(done,tb,itemHs,(ls,ps))= controlsKeyboard focusNr wPtr clipRect1 keyCode event ableContext tb dItemParts (ls,ps)
					=	(done,tb,{itemH & dItemParts=itemHs},(ls,ps))
					where
						itemRect				= PosSizeToRect itemH.dItemPos itemH.dItemSize
						clipRect1				= IntersectRects clipRect (getCompoundContentRect hasHScroll hasVScroll itemRect)
						info					= getDItemCompoundInfo (fromJust itemH.dItemInfo)
						hasHScroll				= isJust info.compoundHScroll
						hasVScroll				= isJust info.compoundVScroll
					controlKeyboard` _ _ _ _ _ _ tb itemH (ls,ps)
					=	(False,tb,itemH,(ls,ps))
			controlsKeyboard _ _ _ _ _ _ tb _ (ls,ps)
			=	(False,tb,[],(ls,ps))
	
/*	validateKeyTracking ensures that programs always get key sequences of KeyDown False,KeyDown True*,KeyUp. 
	It should be applied to a keyboard event, i.e.: what==(KeyDown/KeyUp/AutoKey)Event.
	If the event conflicts with this sequence, validateKeyTracking ensures that the currently tracked
	key will be terminated with a KeyUp KeyState or started with a KeyDown KeyState. 
	The Bool result is True iff the event should be further processed.
	The Char result is the character code of the key being tracked.
*/
	validateKeyTracking :: !Event !(PSt .l .p) -> (!Bool,!Char,!PSt .l .p)
	validateKeyTracking event=:(ok,keyEvent,newKeyMessage,i,h,v,mods) pState
	#	(opt_keytrack,pState)	= accPIO IOStGetKeyTrack pState
	|	keyEvent==KeyDownEvent
	=	(True,newASCII,validateKeyDown opt_keytrack pState)
		with
			validateKeyDown :: !(Maybe KeyTrack) !(PSt .l .p) -> PSt .l .p
			validateKeyDown Nothing pState
			=	appPIO (IOStSetKeyTrack (Just newKeyMessage)) pState
			validateKeyDown (Just oldKeyMessage) pState
			#	pState			= windowKeyIO (ok,KeyUpEvent,oldKeyMessage,i,h,v,0) pState
			=	appPIO (IOStSetKeyTrack (Just newKeyMessage)) pState
	|	isNothing opt_keytrack
	=	validateStartKeyTracking pState
		with
			validateStartKeyTracking :: !(PSt .l .p) -> (!Bool,!Char,!PSt .l .p)
			validateStartKeyTracking pState
			|	keyEvent<>AutoKeyEvent
			=	(False,newASCII,pState)
			#	pState			= windowKeyIO (ok,KeyDownEvent,newKeyMessage,i,h,v,0) pState
				pState			= appPIO (IOStSetKeyTrack (Just newKeyMessage)) pState
			=	(True, newASCII,pState)
	#	oldKeyMessage			= fromJust opt_keytrack
		valid					= newMacCode==getMacCode oldKeyMessage
	|	not valid || keyEvent==AutoKeyEvent
	=	(valid,newASCII,pState)
	#	pState					= appPIO (IOStSetKeyTrack Nothing) pState
	=	(valid,getASCII oldKeyMessage,pState)
	where
		newASCII				= getASCII   newKeyMessage
		newMacCode				= getMacCode newKeyMessage
	
	pressDefaultButton :: !Bool !Int !(DialogStateHandle (PSt .l .p)) !(PSt .l .p) -> (!Bool, !PSt .l .p)
	pressDefaultButton False _ dsH pState
	=	(False, appPIO (IOStReplaceDialog dsH) pState)
	pressDefaultButton _ mods dsH=:(DialogLSHandle dlsH=:{dlsState,dlsHandle=dH=:{dhDefaultId}}) pState
	|	isNothing dhDefaultId
	=	(False,appPIO (IOStReplaceDialog dsH) pState)
	=	(found,pState3)
		with
			items			= dH.dhItems
			wPtr			= dH.dhPtr
			(size,pState1)	= accPIO (accIOToolbox (WindowGetSize wPtr)) pState
			contentRect		= getWindowContentRect (isJust dH.dhHScroll) (isJust dH.dhVScroll) (SizeToRect size)
			dsH1			= DialogLSHandle {dlsState=ls1,dlsHandle={dH & dhItems=items1}}
			pState2			= appPIO (appIOToolbox tbF o IOStReplaceDialog dsH1) pState1
			(found,tbF,items1,(ls1,pState3))
							= selectAbleButton (fromJust dhDefaultId) mods wPtr contentRect items (dlsState,pState2)
	
	pressCancelButton :: !Int !(DialogStateHandle (PSt .l .p)) !(PSt .l .p) -> PSt .l .p
	pressCancelButton mods dsH=:(DialogLSHandle dlsH=:{dlsState,dlsHandle=dH=:{dhCancelId}}) pState
	|	isNothing dhCancelId
	=	appPIO (IOStReplaceDialog dsH) pState
	=	pState3
		with
			items			= dH.dhItems
			wPtr			= dH.dhPtr
			(size,pState1)	= accPIO (accIOToolbox (WindowGetSize wPtr)) pState
			contentRect		= getWindowContentRect (isJust dH.dhHScroll) (isJust dH.dhVScroll) (SizeToRect size)
			dsH1			= DialogLSHandle {dlsState=ls1,dlsHandle={dH & dhItems=items1}}
			pState2			= appPIO (appIOToolbox tbF o IOStReplaceDialog dsH1) pState1
			(_,tbF,items1,(ls1,pState3))
							= selectAbleButton (fromJust dhCancelId) mods wPtr contentRect items (dlsState,pState2)
	
	selectAbleButton :: !Id !Int !WindowPtr Rect ![DElementHandle .ls .ps] (.ls,.ps)
						-> (!Bool,!IdFun *Toolbox,![DElementHandle .ls .ps],(.ls,.ps))
	selectAbleButton id mods wPtr clipRect [itemH:itemHs] (ls,ps)
	#	(found,tbF,itemH,(ls,ps)) = selectAbleButtonControl id mods wPtr clipRect itemH (ls,ps)
	|	found
	=	(found,tbF,[itemH:itemHs],(ls,ps))
	#	(found,tbF,itemHs,(ls,ps)) = selectAbleButton id mods wPtr clipRect itemHs (ls,ps)
	=	(found,tbF,[itemH:itemHs],(ls,ps))
	where
		selectAbleButtonControl :: !Id !Int !WindowPtr Rect !(DElementHandle .ls .ps) (.ls,.ps)
									-> (!Bool,!IdFun *Toolbox,!DElementHandle .ls .ps,(.ls,.ps))
		selectAbleButtonControl id mods wPtr clipRect (DListLSHandle itemHs) (ls,ps)
		#	(found,tbF,itemHs,(ls,ps)) = selectAbleButton id mods wPtr clipRect itemHs (ls,ps)
		=	(found,tbF,DListLSHandle itemHs,(ls,ps))
		selectAbleButtonControl id mods wPtr clipRect (DExtendLSHandle {dExtendLS=exLS,dExtendItems}) (ls,ps)
		#	(found,tbF,itemHs,((exLS,ls),ps)) = selectAbleButton id mods wPtr clipRect dExtendItems ((exLS,ls),ps)
		=	(found,tbF,DExtendLSHandle {dExtendLS=exLS,dExtendItems=itemHs},(ls,ps))
		selectAbleButtonControl id mods wPtr clipRect (DChangeLSHandle {dChangeLS=chLS,dChangeItems}) (ls,ps)
		#	(found,tbF,itemHs,(chLS,ps)) = selectAbleButton id mods wPtr clipRect dChangeItems (chLS,ps)
		=	(found,tbF,DChangeLSHandle {dChangeLS=chLS,dChangeItems=itemHs},(ls,ps))
		selectAbleButtonControl id mods wPtr clipRect (DItemHandle itemH) (ls,ps)
		#	(found,tbF,itemH,(ls,ps)) = selectAbleButtonHandle id mods wPtr clipRect itemH (ls,ps)
		=	(found,tbF,DItemHandle itemH,(ls,ps))
		where
			selectAbleButtonHandle :: !Id !Int !WindowPtr Rect !(DItemHandle .ls .ps) (.ls,.ps)
									   -> (!Bool,!IdFun *Toolbox,!DItemHandle .ls .ps, (.ls,.ps))
			selectAbleButtonHandle id mods wPtr clipRect itemH=:{dItemId,dItemKind,dItemSelect,dItemPos,dItemSize} (ls,ps)
			|	dItemKind==IsCompoundControl
			=	(found,tbF,itemH1,(ls1,ps1))
				with
					clipRect1						= IntersectRects clipRect (PosSizeToRect dItemPos dItemSize)
					(found,tbF,itemHs1,(ls1,ps1))	= selectAbleButton id mods wPtr clipRect1 itemH.dItemParts (ls,ps)
					itemH1							= {itemH & dItemParts=itemHs1}
			|	dItemKind<>IsButtonControl && dItemKind<>IsCustomButtonControl
			=	(False,I,itemH, (ls, ps ))
			|	isNothing dItemId || id<>fromJust dItemId
			=	(False,I,itemH, (ls, ps ))
			|	not dItemSelect
			=	(False,I,itemH, (ls, ps ))
			=	(True,tbF,itemH,(ls1,ps1))
				with
					f			= getButtonFunction mods itemH
					(ls1,ps1)	= f (ls,ps)
					itemRect	= PosSizeToRect dItemPos dItemSize
					tbF			= hiliteDefaultButton` (dItemKind==IsCustomButtonControl) itemRect clipRect wPtr
					
					getButtonFunction :: !Int !(DItemHandle .ls .ps) -> IOFunction *(.ls,.ps)
					getButtonFunction mods {dItemAtts}
					|	iscontrolfunction fAtt	= getcontrolfunction fAtt
												= getcontrolmodsfunction fAtt (IntToModifiers mods)
					where
						(_,fAtt)				= Select isEitherFunction (ControlFunction I) dItemAtts
						
						isEitherFunction att	= iscontrolfunction att || iscontrolmodsfunction att
					
					hiliteDefaultButton` :: !Bool !Rect !Rect !WindowPtr !*Toolbox -> *Toolbox
					hiliteDefaultButton` isCustomButton rect clip wPtr tb
					#	(port,rgn,font,tb)		= openDrawing wPtr tb
						tb						= hiliteDefaultButton isCustomButton rect clip tb
						tb						= closeDrawing port font rgn [rgn] tb
					=	tb
	selectAbleButton _ _ _ _ _ (ls,ps)
	=	(False,I,[],(ls,ps))
