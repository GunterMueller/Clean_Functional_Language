implementation module ExtListBox

import StdBool, StdEnum, StdList, StdMisc, StdOrdList, StdTuple, StdFunc
import StdControl, StdControlReceiver, StdId, StdPicture, StdPSt, StdReceiver, StdWindow
import StdControlAttribute
import ioutil

trace_n` _ s :== s
//import dodebug

//--

::	ExtListBoxState ps =
	{ items			:: ![String]					// All items to be displayed
	, funs			:: ![IdFun ps]					// associated double click fun
	, shiftfuns		:: ![IdFun ps]					// associated shift double click fun
	, selection		:: ![Index]						// The current selection
	, listboxId		:: !ExtListBoxId	ps			// The ids related to this list box
	, lineHeight	:: !Int
	, initHeight	:: !Int
	, lMargin		:: !Int
	, tMargin		:: !Int
	, rMargin		:: !Int
	, bMargin		:: !Int
	, pen			:: ![PenAttribute]
	, newselfun		:: ![Index] ps -> ps
	}

//--

::	ExtListBoxId p
	=	{	controlId	:: !Id							// The Id of the outmost CompoundControl
		,	receiverId	:: !R2Id (MessageIn p) MessageOut	// The Id of the Receiver2Control that handles message passing
		}

openExtListBoxId :: !*env -> (!ExtListBoxId .a,!*env)	| Ids env
openExtListBoxId env
	# (cid, env)	= openId env
	# (rid,env)		= openR2Id env
	= ({controlId=cid,receiverId=rid},env)

//--

::	MessageIn ps
	=	InGetSelection										// Request to retrieve current selection
	|	InSetSelection		[Index]							// Request to set the selection to the given index
	|	InSetSelectAll										// Request to select all items
	|	InGetItems											// Request to retrieve all current items
	|	InOpenItems			Index [ExtListBoxItem ps]		// Request to add items behind the element with the given index
	|	InAppendItems		[ExtListBoxItem ps]				// Request to add items behind the last element
	|	InCloseItems		[Index]							// Request to remove items at the given index positions
	|	InCloseAllItems										// Request to remove all current items
	|	InExecItem			Index							// Request to execute function associated with given index
	|	InSetPen			[PenAttribute]					// Request to set control pen
	|	InGetPen											// Request to get control pen
	|	InTwiddleItems		Index Index						// Request to swap two items

::	MessageOut
	=	OutGetSelection		[(String,Index)]				// Reply to retrieve the current selection
	|	OutSetSelection										// Reply to set the selection
	|	OutGetItems			[String]						// Reply to get all items
	|	OutOpenItems										// Reply to add items
	|	OutAppendItems										// Reply to append items
	|	OutCloseItems										// Reply to remove items
	|	OutCloseAllItems									// Reply to remove all items
	|	OutExecItem											// Reply to execute item
	|	OutSetPen											// Reply to set the control pen
	|	OutGetPen			[PenAttribute]					// Reply to get the control pen
	| OutTwiddleItems

//--

:: ExtListBoxItem ps :== (String,IdFun ps,IdFun ps)

:: ExtListBoxControl ls ps
	= ExtListBoxControl [ExtListBoxItem ps] [Int] ([Int] ps -> ps) (ExtListBoxId ps) [ControlAttribute *(*(ExtListBoxState ps,ls),ps)]

instance Controls ExtListBoxControl
where
	getControlType _ = "ExtListBoxControl"
	controlToHandles (ExtListBoxControl contents selection newselfun listboxId attrs) ps
		# ((lineHeight,initHeight),ps)	= accScreenPicture (liheights penAtts) ps
		# listboxState =	{ items			= items
							, funs			= funs
							, shiftfuns		= shiftfuns
							, selection		= selection
							, listboxId		= listboxId
							, lineHeight	= lineHeight
							, initHeight	= initHeight
							, lMargin		= lMargin
							, tMargin		= tMargin
							, rMargin		= rMargin
							, bMargin		= bMargin
							, pen			= penAtts
							, newselfun		= newselfun
							}
		# (listboxState,domain,ps)		= calcControlDomain listboxState ps
		= controlToHandles (imp listboxId lineHeight listboxState domain listboxAtts) ps
	where
		(items,funs,shiftfuns)			= unzip3 contents
		liheights pen pic
			# pic				= setPenAttributes pen pic
			# (metrics,pic)		= getPenFontMetrics pic
			# lineHeight		= fontLineHeight metrics
			# initHeight		= metrics.fAscent + metrics.fLeading
			= ((lineHeight,initHeight),pic)
		imp listboxId lineHeight listboxState domain listboxAtts
			# (listboxLook,listboxState)	= customlook listboxState
			=
			{	addLS	= listboxState
			,	addDef	= CompoundControl
					(NilLS)
					(
					listboxAtts ++
					[	ControlId			listboxId.controlId
					,	ControlItemSpace	0 0							// No itemspace
					,	ControlHScroll		(altScrollFunction Horizontal 10)
					,	ControlVScroll		(altScrollFunction Vertical lineHeight)
					,	ControlViewDomain	domain
					,	ControlLook			True listboxLook
					,	ControlMouse		mouseFilter Able mouseFunction
					,	elbKeyboard
					]
					)
				  :+:	Receiver2 listboxId.receiverId receiver []
			}

		listboxAtts = map toLBCA (filter isListBoxControlAttribute attrs)
		penAtts = flatten (map getControlPenAtt (filter isControlPen attrs))
		(lMargin,rMargin) = case (map getControlHMarginAtt (filter isControlHMargin attrs)) of
				[]			-> (0,0)
				[(l,r):_]	-> (l,r)
		(tMargin,bMargin) = case (map getControlVMarginAtt (filter isControlVMargin attrs)) of
				[]			-> (0,0)
				[(l,r):_]	-> (l,r)

		isListBoxControlAttribute :: !(ControlAttribute .ps) -> Bool
		isListBoxControlAttribute (ControlFunction _)		= True
		isListBoxControlAttribute ControlHide				= True
		isListBoxControlAttribute (ControlPos _)			= True
		isListBoxControlAttribute (ControlPen _)			= True
		isListBoxControlAttribute (ControlSelectState _)	= True
		isListBoxControlAttribute (ControlViewSize _)		= True
		isListBoxControlAttribute (ControlOuterSize _)		= True
		isListBoxControlAttribute (ControlResize _)			= True
		isListBoxControlAttribute (ControlMouse _ _ _)		= True
		isListBoxControlAttribute (ControlKeyboard _ _ _)	= True
		isListBoxControlAttribute _							= False
		
		toLBCA (ControlFunction f)		= ControlFunction f
		toLBCA ControlHide				= ControlHide
		toLBCA (ControlPos p)			= ControlPos p
		toLBCA (ControlPen p)			= ControlPen p
		toLBCA (ControlSelectState p)	= ControlSelectState p
		toLBCA (ControlViewSize p)		= ControlViewSize p
		toLBCA (ControlOuterSize p)		= ControlOuterSize p
		toLBCA (ControlResize p)		= ControlResize p
		toLBCA (ControlMouse a b f)		= ControlMouse a b f
		toLBCA (ControlKeyboard a b f)	= joinKeyboards elbKeyboard (ControlKeyboard a b f)
		toLBCA _ = abort "ExtListBox.icl: unsupported control attribute handed to toLBCA"
			
				
 
		
		//	The receiver function:
		//receiver :: (MessageIn *(ls,PSt .l)) (*(ExtListBoxState *(ls,PSt .l),ls),PSt .l) -> (MessageOut,(*(ExtListBoxState *(ls,PSt .l),ls),PSt .l))
		
		//	Return the current selection:
		receiver InGetSelection ((listboxState=:{items,selection},ls),ps)
			= (OutGetSelection (map (\index->(items!!(index-1),index)) selection),((listboxState,ls),ps))
		
		//	Set a new selection:
		receiver (InSetSelection newSelection) ((listboxState=:{tMargin,bMargin,lineHeight,initHeight,listboxId},ls),ps)
			# listboxState		= {ExtListBoxState | listboxState & selection=newSelection}
			# (listboxState,ps)	= applySelfun listboxState ps
			# (newLook,listboxState)
								= customlook listboxState
			# ps				= scrolltoselection listboxId lineHeight tMargin bMargin newSelection ps
			# ps				= appPIO (setListBoxLook listboxId True (True,newLook)) ps
			= (OutSetSelection,((listboxState,ls),ps))
		
		//	Set a new selection:
		receiver InSetSelectAll ((listboxState=:{tMargin,bMargin,lineHeight,initHeight,listboxId,items},ls),ps)
			# newSelection		= [1..length items]
			# listboxState		= {ExtListBoxState | listboxState & selection=newSelection}
			# (listboxState,ps)	= applySelfun listboxState ps
			# (newLook,listboxState)
								= customlook listboxState
			# ps				= scrolltoselection listboxId lineHeight tMargin bMargin newSelection ps
			# ps				= appPIO (setListBoxLook listboxId True (True,newLook)) ps
			= (OutSetSelection,((listboxState,ls),ps))
		
		//	Return the current elements:
		receiver InGetItems ((listboxState=:{items},ls),ps)
			= (OutGetItems items,((listboxState,ls),ps))
		
		// Execute element:
		receiver (InExecItem index) ((listboxState=:{funs},ls),ps)
			| index > length funs
				= (OutExecItem,((listboxState,ls),ps))
			# ps = (funs!!(index -  1)) ps
			= (OutExecItem,((listboxState,ls),ps))
		
		//	Insert elements:
		receiver (InOpenItems behindIndex newItems) ((listboxState=:{pen,items,funs,shiftfuns,selection,lineHeight,initHeight},ls),ps)
			| nrNewItems==0
				= (OutOpenItems,((listboxState,ls),ps))
			# listboxState		= {listboxState & items=allItems, funs=allFuns, shiftfuns = allShiftFuns, selection=newSelection}
			# (listboxState,newDomain,ps)
								= calcControlDomain listboxState ps
			# (newLook,listboxState)
								= customlook listboxState
			# ps				= appPIO (seq
									[ setControlViewDomain customId newDomain
									, setControlLooks [(customId,True,(True,newLook))]
									]) ps
			= (OutOpenItems,((listboxState,ls),ps))
		where
			customId				= listboxState.listboxId.controlId
			nrNewItems				= (length newItems)		// Add only items upto maxNrItems
			okNewItems				= newItems%(0,nrNewItems-1)							// These are the proper new items
			(okNewItems`,okNewFuns`,okNewShiftFuns`)= unzip3 okNewItems
			okBehindIndex			= setBetween 0 (inc (length items)) behindIndex
			(itemsBefore,itemsAfter)= splitAt (okBehindIndex-1) items
			(funsBefore,funsAfter)	= splitAt (okBehindIndex-1) funs
			(shiftfunsBefore,shiftfunsAfter)= splitAt (okBehindIndex-1) shiftfuns
			allItems				= if (okBehindIndex==0)
										 (okNewItems`++items)
										 (itemsBefore++okNewItems`++itemsAfter)
			allFuns					= if (okBehindIndex==0)
										 (okNewFuns`++funs)
										 (funsBefore++okNewFuns`++funsAfter)
			allShiftFuns				= if (okBehindIndex==0)
										 (okNewShiftFuns`++shiftfuns)
										 (shiftfunsBefore++okNewShiftFuns`++shiftfunsAfter)
			(selecBefore,selecAfter)= span (\index->index<=okBehindIndex) (sort selection)
			newSelection			= selecBefore++map ((+) nrNewItems) selecAfter
		
		//	Append elements:
		receiver (InAppendItems newItems) ((listboxState=:{pen,items,funs,shiftfuns,selection,lineHeight,initHeight},ls),ps)
			| nrNewItems==0
				= (OutOpenItems,((listboxState,ls),ps))
			# listboxState	= {listboxState & items=allItems, funs=allFuns, shiftfuns = allShiftFuns, selection=newSelection}
			# (listboxState,newDomain,ps)
							= calcControlDomain listboxState ps
			# (newLook,listboxState)
							= customlook listboxState
			# ps			= appPIO (seq
								[ setControlLooks [(customId,False,(True,newLook))]
								, setControlViewDomain customId newDomain
								]) ps
			= (OutAppendItems,((listboxState,ls),ps))
		where
			customId				= listboxState.listboxId.controlId
			nrNewItems				= (length newItems)		// Add only items upto maxNrItems
			okNewItems				= newItems%(0,nrNewItems-1)	// These are the proper new items
			(okNewItems`,okNewFuns`,okNewShiftFuns`)
									= unzip3 okNewItems
			allItems				= items ++ okNewItems`
			allFuns					= funs ++ okNewFuns`
			allShiftFuns			= shiftfuns ++ okNewShiftFuns`
			newSelection			= selection
		
		//	Remove elements:
		receiver (InCloseItems closeItems) ((listboxState=:{pen,items,funs,shiftfuns,selection,lineHeight,initHeight},ls),ps)
			| nrCloseItems==0
				= (OutCloseItems,((listboxState,ls),ps))
			# listboxState		= {listboxState & items=allItems, funs = allFuns, shiftfuns = allShiftFuns, selection=newSelection}
			# (listboxState,newDomain,ps)
								= calcControlDomain listboxState ps
			# (newLook,listboxState)
								= customlook listboxState
			# ps				= appPIO (seq
									[ setControlViewDomain customId newDomain
									, setControlLooks [(customId,True,(True,newLook))]
									]) ps
			= (OutCloseItems,((listboxState,ls),ps))
		where
			customId				= listboxState.listboxId.controlId
			nrCloseItems			= length closeItems
			allItems				= [ item \\ item <- items & i <- [1..] | not (isMember i closeItems) ]
			allFuns					= [ item \\ item <- funs & i <- [1..] | not (isMember i closeItems) ]
			allShiftFuns			= [ item \\ item <- shiftfuns & i <- [1..] | not (isMember i closeItems) ]
			newSelection			= removeMembers selection closeItems
		
		//	Remove all:
		receiver (InCloseAllItems) ((listboxState=:{pen,items,funs,selection,lineHeight,initHeight,listboxId},ls),ps)
			# listboxState	= {listboxState & items=[], funs = [], shiftfuns = [], selection=[]}
			# (listboxState,newDomain,ps)
							= calcControlDomain listboxState ps
			# (newLook,listboxState)
							= customlook listboxState
			# ps			= appPIO (seq
								[ setControlViewDomain listboxId.controlId newDomain
								, setControlLooks [(listboxId.controlId,True,(True,newLook))]
								]) ps
			= (OutCloseAllItems,((listboxState,ls),ps))
		
		// Set control pen:
		receiver (InSetPen newpen) ((listboxState=:{items,pen,listboxId},ls),ps)
			# pen							= removeDupAtt (newpen++pen)
			# ((lineHeight,initHeight),ps)	= accScreenPicture (liheights pen) ps
			# listboxState					=
				{ listboxState
				& pen			= pen
				, lineHeight	= lineHeight
				, initHeight	= initHeight
				}
			# (listboxState,newDomain,ps)	= calcControlDomain listboxState ps
			# (newLook,listboxState)		= customlook listboxState
			# ps			= appPIO (seq
								[ setControlViewDomain listboxId.controlId newDomain
								, setControlLooks [(listboxId.controlId,True,(True,newLook))]
								, setControlScrollFunction listboxId.controlId Vertical (altScrollFunction Vertical lineHeight)
								]) ps
			= (OutSetPen,((listboxState,ls),ps))
		
		// Get control pen:
		receiver (InGetPen) ((listboxState=:{pen},ls),ps)
			= (OutGetPen pen,((listboxState,ls),ps))

		receiver (InTwiddleItems idx1 idx2) ((listboxState=:{items,selection},ls),ps)
			# listboxState	= {listboxState & items = twiddled_items}
			# (newLook,listboxState)
							= customlook listboxState
			# ps			= appPIO (setControlLooks [(controlId,True,(True,newLook))]) ps
			= (OutTwiddleItems,((listboxState,ls),ps))
		where
			controlId				= listboxState.listboxId.controlId
			twiddled_items = twiddle idx1 idx2 items


//--
		
calcControlDomain listboxState=:{pen,items,lMargin,rMargin,tMargin,bMargin} ps
	# (dom,ps)	= accPIO (accScreenPicture calc) ps
	= (listboxState,dom,ps)
where
	calc pic
		# pic				= setPenAttributes pen pic
		# (metrics,pic)		= getPenFontMetrics pic
		# (itemWidths,pic)	= getPenFontStringWidths items pic
		# minWidth			= 0
		# maxWidth			= maxList [minWidth:itemWidths]
		# nrItems			= length items
		# height			= nrItems*(fontLineHeight metrics)
		# width				= maxWidth + lMargin + rMargin
		# height			= height + tMargin + bMargin
		# newDomain			= {corner1=zero,corner2={x=width,y=height}}
		= (newDomain,pic)

 
//removeDupAtt :: !.[a] -> .[a] | Eq a
removeDupAtt [x:xs] = [x:removeDupAtt (filter (diff x) xs)]
where
	diff (PenSize _)	(PenSize _)		= False
	diff (PenPos _)		(PenPos _)		= False
	diff (PenColour _)	(PenColour _)	= False
	diff (PenBack _)	(PenBack _)		= False
	diff (PenFont _)	(PenFont _)		= False
	diff _ _ = True
removeDupAtt _      = []

//-- Look funs

//	The look of the custom control lists all items and the current selection
//customlook :: !(ExtListBoxState .a) .b .UpdateState *Picture -> *Picture
customlook ls=:{items,selection,pen,lineHeight,initHeight,lMargin,tMargin}
	= (customlook,ls)
where
  customlook _ {newFrame} pict
	# pict				= setPenAttributes pen pict
	# pict				= unfill newFrame pict
	# drawlines			= fst (smap drawline items (initHeight+tMargin))
	# pict				= seq drawlines pict
	# drawselection		= map drawsel selection
	# pict				= seq drawselection pict
	= pict
  where
	(x1,x2)			= (newFrame.corner1.x,newFrame.corner2.x)
	drawsel i		= hilite {corner1={x=x1,y=tMargin + (i-1)*lineHeight}, corner2={x=x2,y= tMargin + i*lineHeight-1}}
	drawline line y	= (drawAt {x=lMargin,y=y} line,y+lineHeight)

updatelook ls=:{selection,lineHeight,tMargin} oldsel (x1,x2)
	= (update,ls)
where
	update pict
		# drawselection		= map drawsel oldsel
		# pict				= seq drawselection pict
		# drawselection		= map drawsel selection
		# pict				= seq drawselection pict
		= pict

	drawsel i		= hilite {corner1={x=x1,y=tMargin + (i-1)*lineHeight}, corner2={x=x2,y= tMargin + i*lineHeight-1}}

updateListBoxLook :: !.(ExtListBoxId .a) [.Int] !*(!(!u:(ExtListBoxState *(PSt .b)),.c),*(PSt .b)) -> *((v:(ExtListBoxState *(PSt .b)),.c),*(PSt .b)), [u <= v]
updateListBoxLook customId=:{controlId} newSelection ((lbState=:{tMargin,bMargin,selection,lineHeight},ls),ps)
	| sameSelection newSelection selection
		= ((lbState,ls),ps)
	# lbState		= {lbState & selection = newSelection}
	# (lbState,ps)	= applySelfun lbState ps
	# (wdef,ps)		= accPIO (getParentWindow controlId) ps
	| isNothing wdef
		= ((lbState,ls),ps)
	# (_,frame)		= getControlViewFrame controlId (fromJust wdef)
	| isNothing frame
		= ((lbState,ls),ps)
	# frame			= fromJust frame
	# (x1,x2)		= (frame.corner1.x,frame.corner2.x)
	# (update,lbState)
					= updatelook lbState selection (x1,x2)
	#! ps			= appPIO (appControlPicture controlId update) ps
	# (newLook,lbState)
					= customlook lbState
	#! ps			= appPIO (setListBoxLook customId False (True,newLook)) ps
	#! ps			= scrolltoselection customId lineHeight tMargin bMargin newSelection ps
	= ((lbState,ls),ps)
where
//	sameSelection n [] = False
//	sameSelection n [o] = n == o
//	sameSelection _ _ = False
	sameSelection n o = sort n == sort o

//--

joinKeyboards (ControlKeyboard oFilter oState oKeyboard) (ControlKeyboard nFilter nState nKeyboard)
	// ignore SelectState attributs => always Able
	= ControlKeyboard filter Able keyboard
where
	filter keyState = nFilter keyState || oFilter keyState
	
	keyboard keyState ks
		| nFilter keyState
			= nKeyboard keyState ks
			= oKeyboard keyState ks

//--

elbKeyboard :: .ControlAttribute *((ExtListBoxState *(PSt .a),.b),*PSt .a);
elbKeyboard = ControlKeyboard keyFilter Able keyboard

keyFilter :: KeyboardState -> Bool
keyFilter (SpecialKey _ (KeyDown _) _) = True
keyFilter k  = False

//keyboard :: !.KeyboardState *((.ExtListBoxState *(PSt .a),.b),*PSt .a) -> *((ExtListBoxState *(PSt .a),.b),*PSt .a);
keyboard (SpecialKey key (KeyDown repeat) {shiftDown,controlDown}) ((lbState=:{tMargin,listboxId,selection,items,lineHeight,funs,shiftfuns},ls),ps)
	| key == enterKey || key == returnKey
		| not hasSelection
			= ((lbState,ls),ps)
		// execute selection
		// shift-execute
		// ? what if mul-selection
		| shiftDown
			# ps	= (shiftfuns!!(lastSelection-1)) ps
			= ((lbState,ls),ps)
		# ps	= (funs!!(lastSelection-1)) ps
		= ((lbState,ls),ps)
	| key == escapeKey
		# newSelection	= []
		= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
	| key == upKey
		// set selection one earlier
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# newIndex		= if hasSelection (max 1 (lastSelection - 1)) 1
		| shiftDown
			| hasSelection
				# listSelection = if (lastSelection < newIndex)
									[lastSelection..newIndex]
									[newIndex..lastSelection]
				# newSelection	= removeDup [newIndex:listSelection++selection]
			= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
			# newSelection	= [newIndex]
			= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
		# newSelection	= [newIndex]
		= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
	| key == downKey
		// set selection one later
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# newIndex		= if hasSelection (min nrItems (lastSelection + 1)) nrItems
		| shiftDown
			| hasSelection
				# listSelection = if (lastSelection < newIndex)
									[lastSelection..newIndex]
									[newIndex..lastSelection]
				# newSelection	= removeDup [newIndex:listSelection++selection]
			= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
			# newSelection	= [newIndex]
			= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
		# newSelection	= [newIndex]
		= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
	| key == beginKey
		// set selection first
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# newSelection	= [1]
		= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
	| key == endKey
		// set selection last
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# newSelection	= [nrItems]
		= updateListBoxLook listboxId newSelection ((lbState,ls),ps)
	# (wstate,ps)	= accPIO (getParentWindow customId) ps
	| isNothing wstate
		= ((lbState,ls),ps)
	# wstate	= fromJust wstate
	# (ok,frame) = getControlViewFrame customId wstate
	| not ok
		= ((lbState,ls),ps)
	| isNothing frame
		= ((lbState,ls),ps)
	# frame = fromJust frame
	# linesOnPage = max 1 (dec ((frame.corner2.y - frame.corner1.y) / lineHeight))
	| key == pgUpKey
		// set selection page-up
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# top = (lastSelection-2) * lineHeight + tMargin
		# newSelection	= if hasSelection
							(if (top <= frame.corner1.y)		//topLine
								(max 1 (lastSelection - linesOnPage))
								(1 + ((frame.corner1.y - tMargin) / lineHeight))	//topOfPage
							)
							1
		= updateListBoxLook listboxId [newSelection] ((lbState,ls),ps)
	| key == pgDownKey
		// set selection page-down
		// if shift - extend selection one up
		// if control ...
		// if control-shift ...
		# bot = (inc lastSelection) * lineHeight + tMargin
		# newSelection	= if hasSelection
							(if (bot >= frame.corner2.y)		//bottomLine
								(min nrItems (lastSelection + linesOnPage))
								(min nrItems (frame.corner2.y / lineHeight))	//bottomOfPage
							)
							nrItems
		= updateListBoxLook listboxId [newSelection] ((lbState,ls),ps)
	= ((lbState,ls),ps)
where
	nrItems		= length items
	customId	= listboxId.controlId
	hasSelection
		| isEmpty selection = False
		= True
	lastSelection = hd selection
keyboard _ state
	= state	//abort "ExtListBox.icl: keyboard function only supports special keys"
	
//scrolltoselection :: .Id .Int .Bool .Int !*(PSt .a) -> *PSt .a;
scrolltoselection {controlId} lineHeight tMargin bMargin selection ps
	| not singlesel = ps
	# top = (selitem-1) * lineHeight
	# bot = selitem * lineHeight + tMargin + bMargin
	# (wdef,ps) = accPIO (getParentWindow controlId) ps
	| isNothing wdef = ps
	# wdef = fromJust wdef
	# (exists,frame) = getControlViewFrame controlId wdef
	| not exists = ps
	| isNothing frame = ps
	# frame = fromJust frame
	# delta = top - frame.corner1.y
	| delta < 0
		= appPIO (moveControlViewFrame controlId {vx=0, vy=delta}) ps
	# delta = bot - frame.corner2.y
	| delta > 0
		= appPIO (moveControlViewFrame controlId {vx=0, vy=delta}) ps
	= ps
where
	singlesel = length selection == 1
	selitem = hd selection

//	The mouse responds only to MouseDowns:
mouseFilter :: !MouseState -> Bool
mouseFilter (MouseDown _ _ _)		= True
mouseFilter _						= False

applySelfun ls=:{newselfun,selection} ps
	#! ps	= newselfun selection ps
	= (ls,ps)
	
//	The mouse either sets, adds, or removes items to the selection:
//mouseFunction :: !.MouseState *((.ExtListBoxState *(PSt .a),.b),*PSt .a) -> *((ExtListBoxState *(PSt .a),.b),*PSt .a);
mouseFunction (MouseDown pos {shiftDown,controlDown} 1) ((listboxState=:{tMargin,items,selection,lineHeight,initHeight},ls),ps)
	# listboxState				= {ExtListBoxState | listboxState & selection=okSelection}
	# (listboxState,ps)			= applySelfun listboxState ps
	# (newLook,listboxState)	= customlook listboxState
	# ps						= appPIO (setControlLooks [(customId,True,(True,newLook))]) ps
	= ((listboxState,ls),ps)
where
	nrItems		= length items
	hasSelection= not (isEmpty selection)
	[prevIndex:_]= selection
	listSelection
		| prevIndex < newIndex
			= [prevIndex..newIndex]
			= [newIndex..prevIndex]
	newIndex	= (pos.y-tMargin)/lineHeight+1
	newSelection
		| shiftDown
			| hasSelection
				= removeDup [newIndex:listSelection++selection]
			= [newIndex]
		| controlDown
			| isMember newIndex selection
				= removeMembers selection [newIndex]
			= [newIndex:selection]
		= [newIndex]
	okSelection	= filter (isBetween 1 nrItems) newSelection
	customId	= listboxState.listboxId.controlId

mouseFunction (MouseDown pos {shiftDown} _) ((listboxState=:{tMargin,items,funs,shiftfuns,lineHeight,initHeight},ls),ps)
// double click
	# listboxState				= {ExtListBoxState | listboxState & selection=okSelection}
	# (listboxState,ps)			= applySelfun listboxState ps
	# (newLook,listboxState)	= customlook listboxState
	# ps						= appPIO (setControlLooks [(customId,True,(True,newLook))]) ps
	| newIndex < 1 || newIndex > length funs
		= ((listboxState,ls),ps)
	| shiftDown
		# ps	= (shiftfuns!!(newIndex-1)) ps
		= ((listboxState,ls),ps)
	# ps	= (funs!!(newIndex-1)) ps
	= ((listboxState,ls),ps)
where
	customId	= listboxState.listboxId.controlId
	newIndex	= (pos.y-tMargin)/lineHeight+1
	nrItems		= length items
	newSelection= [newIndex]
	okSelection	= filter (isBetween 1 nrItems) newSelection

mouseFunction arg state
//	= abort "ExtListBox.icl: mouse only supports MouseDowns"
	= trace_n` ("ExtListBox.icl: unexpected argument to mouseFunction",arg) state

//	The functions below take care of the proper communication with the receiver that
//	belongs to the listbox control.

getExtListBoxSelection :: !(ExtListBoxId .a) !(PSt .l) -> (!(!Bool,![(String,!Index)]),!PSt .l)
getExtListBoxSelection {receiverId} pState
	# ((_,maybe_out),pState)	= syncSend2 receiverId InGetSelection pState
	| isNothing maybe_out
		= ((False,[]),pState)
	# result					= case (fromJust maybe_out) of
									(OutGetSelection selection)	-> (True,selection)
									_							-> (False,[])
	| otherwise
		= (result,pState)

setExtListBoxSelection :: !(ExtListBoxId .a) ![Index] !(PSt .l) -> PSt .l
setExtListBoxSelection {receiverId} selection pState
	= snd (syncSend2 receiverId (InSetSelection selection) pState)

setExtListBoxSelectionAll :: !(ExtListBoxId .a) !(PSt .l) -> PSt .l
setExtListBoxSelectionAll {receiverId} pState
	= snd (syncSend2 receiverId InSetSelectAll pState)

getExtListBoxItems :: !(ExtListBoxId .a) !(PSt .l) -> (!(!Bool,![String]),!PSt .l)
getExtListBoxItems {receiverId} pState
	# ((_,maybe_out),pState)	= syncSend2 receiverId InGetItems pState
	| isNothing maybe_out
		= ((False,[]),pState)
	# result					= case (fromJust maybe_out) of
									(OutGetItems items)	-> (True,items)
									_					-> (False,[])
	| otherwise
		= (result,pState)

openExtListBoxItems :: !(ExtListBoxId .a) !Index ![ExtListBoxItem .a] !(PSt .l) -> PSt .l
openExtListBoxItems {receiverId} index items pState
	= snd (syncSend2 receiverId (InOpenItems index items) pState)

execExtListBoxItem  :: !(ExtListBoxId .a) !Index !(PSt .l) -> PSt .l
execExtListBoxItem {receiverId} index  pState
	= snd (syncSend2 receiverId (InExecItem index) pState)

appendExtListBoxItems :: !(ExtListBoxId .a) ![ExtListBoxItem .a] !(PSt .l) -> PSt .l
appendExtListBoxItems {receiverId} items pState
	= snd (syncSend2 receiverId (InAppendItems items) pState)

closeExtListBoxItems :: !(ExtListBoxId .a) ![Index] !(PSt .l) -> PSt .l
closeExtListBoxItems {receiverId} items pState
	= snd (syncSend2 receiverId (InCloseItems items) pState)

closeAllExtListBoxItems :: !(ExtListBoxId .a) !(PSt .l) -> PSt .l
closeAllExtListBoxItems {receiverId} pState
	= snd (syncSend2 receiverId (InCloseAllItems) pState)

showExtListBoxControl :: !(ExtListBoxId .a) !*(IOSt .l) -> *IOSt .l
showExtListBoxControl {controlId} ioState = showControls [controlId] ioState

hideExtListBoxControl :: !(ExtListBoxId .a) !*(IOSt .l) -> *IOSt .l
hideExtListBoxControl {controlId} ioState = hideControls [controlId] ioState

enableExtListBoxControl :: !(ExtListBoxId .a) !*(IOSt .l) -> *IOSt .l
enableExtListBoxControl {controlId} ioState = enableControls [controlId] ioState

disableExtListBoxControl :: !(ExtListBoxId .a) !*(IOSt .l) -> *IOSt .l
disableExtListBoxControl {controlId} ioState = disableControls [controlId] ioState

setExtListBoxPen :: !(ExtListBoxId .a) ![PenAttribute] !(PSt .l) -> PSt .l
setExtListBoxPen {receiverId} pen ps
	= snd (syncSend2 receiverId (InSetPen pen) ps)

getExtListBoxPen :: !(ExtListBoxId .a) !(PSt .l) -> (Maybe [PenAttribute],PSt .l)
getExtListBoxPen {receiverId} ps
	# ((_,maybe_out),ps)	= syncSend2 receiverId InGetPen ps
	| isNothing maybe_out
		= (Nothing,ps)
	# result					= case (fromJust maybe_out) of
									(OutGetPen pen)		-> (Just pen)
									_					-> Nothing
	| otherwise
		= (result,ps)

setListBoxLook listboxId=:{controlId} redraw newlook io = setControlLook controlId redraw newlook io

exec_next :: !Bool !(ExtListBoxId .ps) !(PSt .l) -> (PSt .l)
exec_next next lbId ps
	#	((ok,sel),ps)	= getExtListBoxSelection lbId ps
	| not ok = ps
	#	fun				= if next inc dec
		idx				= (if (isEmpty sel) 1 (fun (snd(hd sel))))
		((ok,lst),ps)	= getExtListBoxItems lbId ps
	| not ok =  ps
	#	num				= length lst
	| num == 0 = ps
	#	idx				= normalise idx 1 num num
		ps				= execExtListBoxItem lbId idx ps
		ps				= setExtListBoxSelection lbId [idx] ps
	= ps
where
	normalise num min max incr
		| num < min = normalise (num+incr) min max incr
		| num > max = normalise (num-incr) min max incr
		= num

upSelItem :: !(ExtListBoxId .ps) !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
upSelItem lbId=:{receiverId} (ls,ps)
	// get sel
	# ((ok,sel),ps)	= getExtListBoxSelection lbId ps
	// if not single sel fail...
	| not ok || length sel <> 1
		= (False,(ls,ps))
	// if first fail...
	# (_,sel) = hd sel
	| sel == 1
		= (False,(ls,ps))
	// twiddle with prev
	# ((_,r),ps) = syncSend2 receiverId (InTwiddleItems sel (dec sel)) ps
	| isNothing r
		= (False,(ls,ps))
	# ls = twiddle sel (dec sel) ls
	# ps = setExtListBoxSelection lbId [dec sel] ps
	= (True,(ls,ps))
dnSelItem :: !(ExtListBoxId .ps) !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
dnSelItem lbId=:{receiverId} (ls,ps)
	// get sel
	# ((ok,sel),ps)	= getExtListBoxSelection lbId ps
	// if not single sel fail...
	| not ok || length sel <> 1
		= (False,(ls,ps))
	// if last fail...
	# ((ok,its),ps)	= getExtListBoxItems lbId ps
	| not ok
		= (False,(ls,ps))
	# (_,sel) = hd sel
	| sel == length its
		= (False,(ls,ps))
	// twiddle with prev
	# ((_,r),ps) = syncSend2 receiverId (InTwiddleItems sel (inc sel)) ps
	| isNothing r
		= (False,(ls,ps))
	# ls = twiddle sel (inc sel) ls
	# ps = setExtListBoxSelection lbId [inc sel] ps
	= (True,(ls,ps))

//	Auxiliary functions:

smap f [x:xs] s
	# (y,s)	= f x s
	# (ys,s)= smap f xs s
	= ([y:ys],s)
smap _ _ s
	= ([],s)

isBetween :: x x x -> Bool	| Ord x
isBetween low up x
	= low<=x && x<=up

setBetween :: x x x -> x | Ord x
setBetween low up x
	| x<low		= low
	| x<up		= x
	| otherwise	= up

twiddle idx1 idx2 items = updateAt idx1` itm2 (updateAt idx2` itm1 items)
where
	itm1 = items!!idx1`	// do error checks...
	itm2 = items!!idx2`	// do error checks...
	idx1` = dec idx1
	idx2` = dec idx2
	
