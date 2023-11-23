implementation module controlmousedown1


import	StdInt, StdBool, StdFunc, StdList, StdTuple
import	textedit
from	events				import	GetMouse, GetKeys, WaitMouseUp
//from	menus				import	CheckItem, PopUpMenuSelect, InsertMenu, DeleteMenu, MacMenuHandle
import menus,quickdraw
//from	quickdraw			import	GrafPtr, QInvertRect, QClipRect
import	commondef, controldefaccess, controlclip, keyfocus, windowaccess
//from	controlcreate		import	PopUpMenuID
from	iostate				import	PSt, IOSt, 
									getIOToolbox, setIOToolbox, appIOToolbox, accIOToolbox, 
									IOStButtonFreq
from	StdPSt				import	accPIO, appPIO
//from	windowdraw			import	openDrawing, closeDrawing, openClipDrawing, closeClipDrawing, redrawPopUpItemText
import oswindow
import StdControlAttribute
import osfont,pointer

::	ControlMouseEvent
	=	{	cmePtr	::!OSWindowPtr		// The OSWindowPtr of the window
		,	cmePos	:: !Point2			// The mouse position in local coordinates
		,	cmeWhen	:: !Int				// The when field of the original event
		,	cmeMods	:: !Int				// The mods field of the original event
		}


/*	Handle mouse event in RadioControl.	*/

handleRadioControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleRadioControlMouse cmEvent clipRect _ kf itemH=:{wItemInfo=(RadioInfo info)} (ls,ps)
#	radios		= info.radioItems
	index		= info.radioIndex
	(done,newIndex,radios,(ls,ps))
				= selectradioitem cmEvent clipRect index 1 radios (ls,ps)
	itemH		= {itemH & wItemInfo= (RadioInfo {info & radioItems=radios,radioIndex=newIndex})}
|	newIndex==index
=	(done,kf,itemH,(ls,ps))
#	ps			= appPIO (appIOToolbox (setClippedControlValue cmEvent.cmePtr clipRect (radios!!(index-1)).radioItemPtr 0)) ps
=	(done,kf,itemH,(ls,ps))
where
	selectradioitem :: !ControlMouseEvent !Rect !Index !Index ![RadioItemInfo (.ls,PSt .l)] (.ls,PSt .l)
											 -> (!Bool,!Index,![RadioItemInfo (.ls,PSt .l)],(.ls,PSt .l))
	selectradioitem cmEvent=:{cmePtr,cmePos} clipRect oldIndex newIndex [radio:radios] (ls,ps)
	|	not (PointInRect cmePos (PosSizeToRect radio.radioItemPos radio.radioItemSize))
	=	(done,newIndex1,[radio:radios1],(ls1,ps1))
		with
			(done,newIndex1,radios1,(ls1,ps1))	= selectradioitem cmEvent clipRect oldIndex (newIndex+1) radios (ls,ps)
	#	(upPart,ps)		= accPIO (accIOToolbox (trackClippedControl cmePtr clipRect radio.radioItemPtr cmePos)) ps
	|	upPart==0
	=	(True,oldIndex,[radio:radios],(ls,ps))
	#	ps				= appPIO (appIOToolbox (setClippedControlValue cmePtr clipRect radio.radioItemPtr 1)) ps
		(ls,ps)			= thd3 radio.radioItem (ls,ps)
	=	(True,newIndex,[radio:radios],(ls,ps))
	selectradioitem _ _ oldIndex _ _ (ls,ps)
	=	(False,oldIndex,[],(ls,ps))


/*	Handle mouse event in CheckControl.	*/

handleCheckControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCheckControlMouse cmEvent clipRect _ kf itemH=:{wItemInfo=(CheckInfo info)} (ls,ps)
#	checks					= info.checkItems
	(done,checks,(ls,ps))	= selectcheckitem cmEvent clipRect checks (ls,ps)
	itemH					= {itemH & wItemInfo= (CheckInfo {info & checkItems=checks})}
=	(done,kf,itemH,(ls,ps))
where
	selectcheckitem :: !ControlMouseEvent !Rect ![CheckItemInfo (.ls,PSt .l)] (.ls,PSt .l)
									  -> (!Bool,![CheckItemInfo (.ls,PSt .l)],(.ls,PSt .l))
	selectcheckitem cmEvent=:{cmePtr,cmePos} clipRect [check:checks] (ls,ps)
	|	not (PointInRect cmePos (PosSizeToRect check.checkItemPos check.checkItemSize))
	=	(done,[check:checks1],(ls1,ps1))
		with
			(done,checks1,(ls1,ps1))	= selectcheckitem cmEvent clipRect checks (ls,ps)
	#	(upPart,ps)			= accPIO (accIOToolbox (trackClippedControl cmePtr clipRect check.checkItemPtr cmePos)) ps
	|	upPart==0
	=	(True,[check:checks],(ls,ps))
	#	(title,x,oldMark,f)	= check.checkItem
		newMark				= ~oldMark
		value				= if (marked newMark) 1 0
		ps					= appPIO (appIOToolbox (setClippedControlValue cmePtr clipRect check.checkItemPtr value)) ps
		(ls,ps)				= f (ls,ps)
	=	(True,[{check & checkItem=(title,x,newMark,f)}:checks],(ls,ps))
	selectcheckitem _ _ _ (ls,ps)
	=	(False,[],(ls,ps))


/*	Handle mouse event in PopUpControl.	*/

handlePopUpControlMouse :: !ControlMouseEvent Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handlePopUpControlMouse {cmePtr} clipRect _ kf itemH=:{wItemInfo=(PopUpInfo info)} (ls,pState)
# itemH = {itemH & wItemInfo = PopUpInfo info}
#	((index1,menu,itemH),pState)	= accPIO (handlePopUpMenuEvent itemH cmePtr) pState
|	index1==0 || index1==index
=	(True,kf,itemH,(ls,pState))
#	popUps				= info.popUpInfoItems
	(tb,ioState)		= getIOToolbox pState.io
	(text,f)			= popUps!!(index1-1)
	tb					= CheckItem menu index  False tb
	tb					= CheckItem menu index1 True  tb

	(port,rgn,font,tb)	= openDrawing cmePtr tb
	tb					= QClipRect clipRect tb
//	tb					= redrawPopUpItemText itemPos itemSize text tb
	tb					= OSupdatePopUpControl clipRect cmePtr OSNoWindowPtr /*itemPos itemSize text*/ tb
	tb					= closeDrawing port font rgn [rgn] tb

	itemH				= {itemH & wItemInfo= (PopUpInfo {info & popUpInfoIndex=index1})}
	ioState				= setIOToolbox tb ioState
	(ls,pState)			= f (ls,{pState & io=ioState})
=	(True,kf,itemH,(ls,pState))
where
	info				= getWItemPopUpInfo ( itemH.wItemInfo)
	index				= info.popUpInfoIndex
	itemPos				= itemH.dItemPos
	itemSize			= itemH.dItemSize
	
	handlePopUpMenuEvent :: !(WItemHandle .ls (PSt .l)) !OSWindowPtr !(IOSt .l) -> ((Int,OSMenu,(WItemHandle .ls (PSt .l))),!IOSt .l)
	handlePopUpMenuEvent itemH=:{wItemPos=wItemPos,wItemInfo=wII=:(PopUpInfo info=:{popUpInfoIndex=pII})} wPtr ioState
	#	(tb,ioState)	= getIOToolbox ioState
		tb				= InsertMenu menu (-1) tb
		(global,tb)		= InGrafport wPtr (LocalToGlobal wItemPos) tb
		(_,itemNr,tb)	= PopUpMenuSelect menu global.y global.x pII tb
		tb				= DeleteMenu PopUpMenuID tb
		ioState			= setIOToolbox tb ioState
	=	((itemNr,menu,{itemH & wItemPos = wItemPos, wItemInfo = wII}),ioState)
	where
		menu			= itemH.wItemPtr


/*	Handle mouse event in EditControl.	*/

handleEditControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox)
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleEditControlMouse {cmePtr,cmePos,cmeMods} clipRect deactivate kf itemH=:{wItemNr,wItemPtr=hTE} (ls,ps)
#	(tb,ps)				= accPIO getIOToolbox ps
	(port,rgn,tb)		= openClipDrawing cmePtr tb
	tb					= QClipRect clipRect tb
	tb					= deactivate tb
	tb					= TEActivate hTE tb
	tb					= TEClick (cmePos.x,cmePos.y) (IntToModifiers cmeMods).shiftDown hTE tb
	tb					= closeClipDrawing port rgn tb
	ps					= appPIO (setIOToolbox tb) ps
//	itemH = {itemH & wItemNr = wItemNr, wItemPtr = hTE}
=	(True,setNewFocusItem wItemNr kf,itemH,(ls,ps))


/*	Handle mouse event in ButtonControl.	*/

handleButtonControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleButtonControlMouse {cmePtr,cmePos,cmeMods} clipRect _ kf itemH=:{wItemPtr=wItemPtr} (ls,ps)
# itemH = {itemH & wItemPtr = wItemPtr}
#	(upPart,ps)					= accPIO (accIOToolbox (trackClippedControl cmePtr clipRect wItemPtr cmePos)) ps
|	upPart==0					= (True,kf,itemH,(ls,ps))
|	isControlModsFunction fAtt	= (True,kf,itemH,getControlModsFun fAtt (IntToModifiers cmeMods) (ls,ps))
								= (True,kf,itemH,getControlFun fAtt (ls,ps))
where
	fAtt						= getControlEitherF itemH.wItemAtts

getControlEitherF :: ![ControlAttribute .ps] -> ControlAttribute .ps
getControlEitherF atts = snd (Select isEitherF (ControlFunction id) atts)
where
	isEitherF :: !(ControlAttribute .ps) -> Bool
	isEitherF att = isControlModsFunction att || isControlFunction att


/*	Handle mouse event in CustomButtonControl.	*/

handleCustomButtonControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
									!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
						 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCustomButtonControlMouse {cmePtr,cmeMods} clipRect _ kf itemH=:{wItemPos,wItemSize,wItemAtts} (ls,ps)
# itemH = {itemH & wItemPos = wItemPos, wItemSize = wItemSize, wItemAtts = wItemAtts}
#	(tb,ps)						= accPIO getIOToolbox ps
	(port,rgn,tb)				= openClipDrawing cmePtr tb
	tb							= QClipRect clipRect tb
	itemRect					= PosSizeToRect wItemPos wItemSize
	selected					= True
	tb							= QInvertRect itemRect tb
	(selected,tb)				= trackCustomButton itemRect selected tb
	tb							= closeClipDrawing port rgn tb
	ps							= appPIO (setIOToolbox tb) ps
|	not selected				= (True,kf,itemH,(ls,ps))
|	isControlModsFunction fAtt	= (True,kf,itemH,getControlModsFun fAtt (IntToModifiers cmeMods) (ls,ps))
								= (True,kf,itemH,getControlFun fAtt (ls,ps))
where
	fAtt						= getControlEitherF wItemAtts
	
	trackCustomButton :: !Rect !Bool !*OSToolbox -> (!Bool,!*OSToolbox)
	trackCustomButton itemRect selected tb
	#	(x,y,tb)						= GetMouse tb
		inside							= PointInRect {x=x,y=y} itemRect
		(stillDown,tb)					= WaitMouseUp tb
	|	stillDown && selected==inside	= trackCustomButton itemRect inside tb
	|	stillDown						= trackCustomButton itemRect inside (QInvertRect itemRect tb)
	|	not inside						= (inside,tb)
										= (inside,QInvertRect itemRect tb)


/*	Handle mouse event in CustomControl.	*/

handleCustomControlMouse :: !ControlMouseEvent !Rect (IdFun *OSToolbox) 
							!*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
				 -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCustomControlMouse {cmePtr,cmePos,cmeWhen,cmeMods} clipRect deactivate kf itemH=:{wItemNr,wItemAtts,wItemPos} (ls,pState)
# itemH = {itemH & wItemAtts = wItemAtts, wItemPos = wItemPos, wItemNr = wItemNr}
#	ioState				= appIOToolbox deactivate pState.io
	kf					= setNewFocusItem wItemNr kf
	(filter,feel)		= getCustomControlMouse wItemAtts
	itemPos				= wItemPos
	offset				= {vx=0-itemPos.x,vy=0-itemPos.y}
	(buttonFreq,ioState)= IOStButtonFreq cmeWhen cmePos cmePtr ioState
	modifiers			= IntToModifiers cmeMods
	mouseState			= MouseDown {x=cmePos.x-itemPos.x,y=cmePos.y-itemPos.y} modifiers buttonFreq
	pState				= {pState & io=ioState}
|	filter mouseState
=	(True,kf,itemH,trackCustomControl cmePtr offset filter feel (feel mouseState (ls,pState)))
=	(True,kf,itemH,trackCustomControl cmePtr offset filter feel (ls,pState))
where
	trackCustomControl :: !OSWindowPtr !Vector2 !MouseStateFilter !(MouseFunction (.ls,PSt .l)) (.ls,PSt .l)
																							 -> (.ls,PSt .l)
	trackCustomControl wPtr offset filter feel (ls,pState)
	#	(down,pState)			= accPIO (accIOToolbox WaitMouseUp) pState
		(goOn,(ls,pState))		= trackCustomControl` wPtr offset down filter feel (ls,pState)
	|	down && goOn			= trackCustomControl  wPtr offset      filter feel (ls,pState)
								= (ls,pState)
	where
		trackCustomControl` :: !OSWindowPtr !Vector2 !Bool !MouseStateFilter !(MouseFunction (.ls,PSt .l)) (.ls,PSt .l)
																								 -> (!Bool,(.ls,PSt .l))
		trackCustomControl` wPtr offset buttonDown filter feel (ls,pState=:{io = ioState})
//		#	(found,ioState)		= IOStFindDialog (toWID wPtr) ioState
//		|	not found			= (False,(ls,{pState & io=ioState}))
// moet nu met kijken in windows...
		#	(tb,ioState)		= getIOToolbox ioState
			(mPos,tb)			= InGrafport wPtr GetMousePosition tb
			(k1,k2,k3,k4,tb)	= GetKeys tb
			mods				= KeyMapToModifiers (k1,k2,k3,k4)
			localPos			= addPointVector offset mPos
			mouseState			= if buttonDown (MouseDrag localPos mods) (MouseUp localPos mods)
			ioState				= setIOToolbox tb ioState
			pState				= {pState & io=ioState}
		|	filter mouseState	= (True,feel mouseState (ls,pState))
								= (True,(ls,pState))

getCustomControlMouse :: ![ControlAttribute .ps] -> (!MouseStateFilter,!MouseFunction .ps)
getCustomControlMouse atts
|	isControlMouse att
=	(filter,mouseF)
	with
		(filter,_,mouseF)	= getControlMouseAtt att
|	isControlModsFunction att
=	(const True,modsToMouseFunction (getControlModsFun att))
=	(const True,toMouseFunction (getControlFun att))
where
	(_,att) = Select isFeel (ControlFunction id) atts
	
	isFeel :: !(ControlAttribute .ps) -> Bool
	isFeel att = isControlFunction att || isControlModsFunction att || isControlMouse att
	
//	modsToMouseFunction :: !(ModsIOFunction .ps) !MouseState .ps -> .ps
	modsToMouseFunction f mouseState pState
	=	f (getMouseStateModifiers mouseState) pState
	
//	toMouseFunction :: !(IOFunction .ps) MouseState .ps -> .ps
	toMouseFunction f _ ps = f ps

//~~~

//	openDrawing saves the current Grafport, sets the new Grafport, saves its ClipRgn and font settings.
openDrawing :: !OSWindowPtr !*OSToolbox -> (!GrafPtr,!OSRgnHandle,!(!Int,!Int,!Int),!*OSToolbox)
openDrawing wPtr tb
#	(port,tb)	= QGetPort				tb
	tb			= QSetPort wPtr			tb
	(rgn, tb)	= QNewRgn				tb
	(rgn1,tb)	= QGetClip rgn			tb
	(font,tb)	= GrafPtrGetFont wPtr	tb
=	(port,rgn1,font,tb)

//	closeDrawing restores the font settings and ClipRgn, restores the Grafport, and disposes the RgnHandles.
closeDrawing :: !GrafPtr !(!Int,!Int,!Int) !OSRgnHandle ![OSRgnHandle] !*OSToolbox -> *OSToolbox
closeDrawing port (nr,style,size) clipRgn disposeRgns tb
#	tb	= GrafPtrSetFont	(nr,style,size) tb
	tb	= QSetClip			clipRgn tb
	tb	= QPenNormal		tb
	tb	= QForeColor		BlackColor tb
	tb	= QSetPort			port tb
	tb	= disposeRgnHs		disposeRgns tb
=	tb


//~~~~

PopUpMenuID		:==	235

/*	GrafPort access rules:
*/
InGrafport :: !OSWindowPtr !(St *OSToolbox .x) !*OSToolbox -> (!.x, !*OSToolbox)
InGrafport wPtr f tb
#	(port,tb)	= QGetPort tb
	tb			= QSetPort wPtr tb
	(x,tb)		= f tb
	tb			= QSetPort port tb
=	(x,tb)

LocalToGlobal :: !Point2 !*OSToolbox -> (!Point2,!*OSToolbox)
LocalToGlobal {x,y} tb
#	(x,y,tb)	= QLocalToGlobal x y tb
=	({x=x,y=y},tb)

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

//WindowGetSize :: !OSWindowPtr !*OSToolbox -> (!Size,!*OSToolbox)
WindowGetSize wPtr tb
	# rectPtr			= wPtr+16
	  (rect,tb)	= LoadRect rectPtr tb
	  (l,t, r,b) = toTuple4 rect
	= ({w=r-l, h=b-t},tb)

//InGrafport2 :: !OSWindowPtr !(IdFun *OSToolbox) !*OSToolbox -> *OSToolbox
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

/*	Conversion of modifiers as found in events.
*/
ModifiersToInt :: !Modifiers -> Int
ModifiersToInt {shiftDown,optionDown,commandDown,controlDown}
=	mask shiftDown 512 bitor (mask optionDown 2048 bitor (mask commandDown 256 bitor mask controlDown 4096))
where
	mask :: !Bool !Int -> Int
	mask down n	|	down	= n
							= 0

IntToModifiers :: !Int -> Modifiers
IntToModifiers flags
=	{	shiftDown	= FlagIsSet flags 512
	,	optionDown	= FlagIsSet flags 2048
	,	commandDown	= FlagIsSet flags 256
	,	controlDown	= FlagIsSet flags 4096
	,	altDown		= False
	}

FlagIsSet flags flag	:== (flags bitand flag) <> 0

/*	Calculation rules on Points, Sizes, and Vectors:
*/
addPointVector :: !Vector2 !Point2 -> Point2
addPointVector {vx,vy} {x,y} = {x=x+vx,y=y+vy}

/*	Convert a KeyMap (returned by GetKeys) into Modifiers (5 Booleans of which altDown==False).
*/
KeyMapToModifiers :: !(!Int,!Int,!Int,!Int) -> Modifiers
KeyMapToModifiers (w1,word,w3,w4)
=	{shiftDown=shift<>0,optionDown=option<>0,commandDown=command<>0,controlDown=control<>0,altDown=False}
where
	shift	= word bitand ShiftMask
	option	= word bitand OptionMask
	command	= word bitand CommandMask
	control	= word bitand ControlMask


ShiftMask				:== 1
OptionMask				:== 4
CommandMask				:== 32768
ControlMask				:== 8
