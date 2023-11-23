implementation module StdListBox

/* TO DO:
* Imporove updates...
* Use clipping in customlook...
*/

import StdBool, StdEnum, StdList, StdMisc, StdOrdList, StdTuple, StdFunc
import StdControl, StdControlReceiver, StdId, StdPicture, StdPSt, StdReceiver, StdWindow
import ioutil

::	ListBoxState =
	{	items			:: [String]						// All items to be displayed
	,	selection		:: [Index]						// The current selection
	,	listboxId		:: ListBoxId					// The ids related to this list box
	}
::	ListBoxId =
	{	controlId		:: !Id							// The Id of the Control
	,	r2Id			:: !R2Id MessageIn MessageOut	// The Id of the Receiver2Control that handles message passing
	}
::	MessageIn
	=	InGetSelection										// Request to retrieve current selection
	|	InSetSelection		[Index]							// Request to set the selection to the given index
	|	InGetItems											// Request to retrieve all current items
	|	InOpenItems			Index [String]					// Request to add items behind the element with the given index
	|	InAppendItems		[String]						// Request to add items behind the last element
	|	InCloseItems		[Index]							// Request to remove items at the given index positions
	|	InCloseAllItems										// Request to remove all current items
	| InTwiddleItems Index Index
::	MessageOut
	=	OutGetSelection		[(String,Index)]				// Reply to retrieve the current selection
	|	OutSetSelection										// Reply to set the selection
	|	OutGetItems			[String]						// Reply to get all items
	|	OutOpenItems										// Reply to add items
	|	OutAppendItems										// Reply to append items
	|	OutCloseItems										// Reply to remove items
	|	OutCloseAllItems									// Reply to remove all items
	| OutTwiddleItems

:: ListBoxControl ls ps
	= ListBoxControl [String] [Int] ListBoxId [ControlAttribute *(ls,ps)]

instance Controls ListBoxControl
where
	getControlType _ = "ListBoxControl"
	controlToHandles (ListBoxControl items selection listboxId atts) ps
		# (font,ps)				= accPIO (accScreenPicture openDialogFont) ps
		# (metrics,ps)			= accPIO (accScreenPicture (getFontMetrics font)) ps
		# (domain,ps)			= calcControlDomain items ps
		# (listboxState,newlook)= customlook listboxState
		= controlToHandles (imp listboxState newlook metrics domain) ps
	where
		nrItems				= length items
		selection`				= if (nrItems==0)
									 []
									 (filter (isBetween 1 nrItems) selection)
		listboxState		= {	items		= items
							  ,	selection	= selection`
							  ,	listboxId	= listboxId
							  }
		imp listboxState look metrics domain =
			{ addLS		= listboxState
			, addDef	= CompoundControl
				(NilLS)
				[	ControlId			listboxId.controlId
				,	ControlHScroll		(altScrollFunction Horizontal 10)
				,	ControlVScroll		(altScrollFunction Vertical (metricsLineHeight metrics))
				,	ControlViewDomain	domain
				,	ControlLook			True look
				,	ControlMouse		mouseFilter Able (mouse metrics)
				:	listboxAtts
				]
				:+: Receiver2 listboxId.r2Id receiver []
			}

		listboxAtts = map toLBCA (filter isListBoxControlAttribute atts)

		isListBoxControlAttribute :: !(ControlAttribute .ps) -> Bool
		isListBoxControlAttribute (ControlFunction _)		= True
		isListBoxControlAttribute ControlHide				= True
		isListBoxControlAttribute (ControlPos _)			= True
		isListBoxControlAttribute (ControlSelectState _)	= True
		isListBoxControlAttribute (ControlViewSize _)		= True
		isListBoxControlAttribute (ControlOuterSize _)		= True
		isListBoxControlAttribute (ControlResize _)			= True
		isListBoxControlAttribute _							= False
		
		toLBCA (ControlFunction f) = ControlFunction f`
		where
			f` ((bs,ls),ps)
				# (ls,ps) = f (ls,ps)
				= ((bs,ls),ps)
		toLBCA ControlHide				= ControlHide
		toLBCA (ControlPos p)			= ControlPos p
		toLBCA (ControlSelectState s)	= ControlSelectState s
		toLBCA (ControlViewSize s)		= ControlViewSize s
		toLBCA (ControlOuterSize s)		= ControlOuterSize s
		toLBCA (ControlResize f)		= ControlResize f
		toLBCA _ = abort "StdListBox: toLBCA: unsupported Control Attribute"
		
	
//	The look of the custom control lists all items and the current selection
customlook :: *ListBoxState -> (*ListBoxState, SelectState UpdateState *Picture -> *Picture)
customlook ls=:{items,selection} = (ls,customlook`)
where
	customlook` _ {newFrame} pict
		# (font,pict)		= openDialogFont pict
		# (metrics,pict)	= getFontMetrics font pict
		# height			= metricsLineHeight metrics
		# drawlines			= fst (smap (\line y->(drawAt {x=0,y=y} line,y+height)) lines (metrics.fAscent+metrics.fLeading))
		# drawselection		= map (\i->hilite {corner1={x=x1,y=(i-1)*height},corner2={x=x2,y=i*height-1}}) selection
		# pict				= unfill newFrame pict
		# pict				= setPenFont font pict
		# pict				= seq drawlines pict
		# pict				= seq drawselection pict
		= pict
	where
		lines			= items
		(x1,x2)			= (newFrame.corner1.x,newFrame.corner2.x)
	
		
//	The mouse responds only to MouseDowns:
mouseFilter :: MouseState -> Bool
mouseFilter (MouseDown _ _ ddown)	= ddown==1
mouseFilter _						= False

//	The mouse either sets, adds, or removes items to the selection:
//mouse :: MouseState (ListBoxState,PSt .l) -> (ListBoxState,PSt .l)
mouse metrics (MouseDown pos {shiftDown} _) ((listboxState,ls),ps)
	# listboxState	= {ListBoxState | listboxState & selection=okSelection}
	# (listboxState,newLook)
					= customlook listboxState
	# ps			= appPIO (setControlLooks [(controlId,True,(True,newLook))]) ps
	= ((listboxState,ls),ps)
where
	items		= listboxState.items
	nrItems		= length items
	selection	= listboxState.ListBoxState.selection
	lineHeight	= metricsLineHeight metrics
	newIndex	= pos.y/lineHeight+1
	newSelection= if (not shiftDown)				[newIndex]
				 (if (isMember newIndex selection)	(removeMembers selection [newIndex])
													[newIndex:selection])
	okSelection	= filter (isBetween 1 nrItems) newSelection
	controlId	= listboxState.listboxId.controlId
mouse _ _ _ = abort "StdListBox: unsupported mouse action"

calcControlDomain allItems ps
	# (font,ps)				= accPIO (accScreenPicture openDialogFont) ps
	# (metrics,ps)			= accPIO (accScreenPicture (getFontMetrics font)) ps
	# (itemWidths,ps)		= accPIO (accScreenPicture (getFontStringWidths font allItems)) ps
	# minWidth				= 0
	# maxWidth				= maxList [minWidth:itemWidths]
	# nrItems				= length allItems
	# height				= nrItems*(metricsLineHeight metrics)
	# newDomain				= {corner1=zero,corner2={x=maxWidth,y=height}} // calculate new domain...
	= (newDomain,ps)


//	The receiver function:
receiver :: MessageIn ((*ListBoxState,.ls),PSt .l) -> (MessageOut,((*ListBoxState,.ls),PSt .l))

//	Return the current selection:
receiver InGetSelection ((listboxState=:{items,selection},ls),ps)
	# selection = map (\index->(items!!(index-1),index)) selection
	= (OutGetSelection selection,((listboxState,ls),ps))

//	Set a new selection:
receiver (InSetSelection newSelection) ((listboxState=:{listboxId},ls),ps)
	# listboxState	= {ListBoxState | listboxState & selection=newSelection}
	# (listboxState,newlook)
					= customlook listboxState
	# ps			= appPIO (setControlLooks [(listboxId.controlId,True,(True,newlook))]) ps
	= (OutSetSelection,((listboxState,ls),ps))

//	Return the current elements:
receiver InGetItems ((listboxState=:{items},ls),ps)
	= (OutGetItems items,((listboxState,ls),ps))

//	Insert elements:
receiver (InOpenItems behindIndex newItems) ((listboxState=:{items,selection},ls),ps)
	| nrNewItems==0
		= (OutOpenItems,((listboxState,ls),ps))
	# (newDomain,ps)				= calcControlDomain allItems ps
	# listboxState	= {listboxState & items=allItems, selection=newSelection}
	# (listboxState,newlook)
					= customlook listboxState
	# ps		= appPIO (seq
						[ setControlViewDomain controlId newDomain				// WATCH OUT!!
						, setControlLooks [(controlId,True,(True,newlook))]		// ORDERING IS IMPORTANT!!
						]) ps
	| otherwise
		= (OutOpenItems,((listboxState,ls),ps))
where
	controlId			= listboxState.listboxId.controlId
	nrNewItems				= length newItems									// Add any number of new items
	okBehindIndex			= setBetween 0 (length items) behindIndex
	(itemsBefore,itemsAfter)= splitAt (okBehindIndex-1) items
	allItems				= if (okBehindIndex==0)
								 (newItems++items)
								 (itemsBefore++newItems++itemsAfter)
	(selecBefore,selecAfter)= span (\index->index<=okBehindIndex) (sort selection)
	newSelection			= selecBefore++map ((+) nrNewItems) selecAfter

//	Append elements:
receiver (InAppendItems newItems) ((listboxState=:{items,selection},ls),ps)
	| nrNewItems==0
		= (OutOpenItems,((listboxState,ls),ps))
	# listboxState	= {listboxState & items=allItems}
	# (listboxState,newlook)
					= customlook listboxState
	# (newDomain,ps) = calcControlDomain allItems ps
	# ps		= appPIO (seq
						[ setControlViewDomain controlId newDomain				// WATCH OUT!!
						, setControlLooks [(controlId,True,(True,newlook))]		// ORDERING IS IMPORTANT!!
						]) ps
	| otherwise
		= (OutAppendItems,((listboxState,ls),ps))
where
	controlId				= listboxState.listboxId.controlId
	allItems				= items++newItems
	nrNewItems = length newItems

receiver (InTwiddleItems idx1 idx2) ((listboxState=:{items,selection},ls),ps)
	# listboxState	= {listboxState & items = twiddled_items}
	# (listboxState,newlook)
					= customlook listboxState
	# ps			= appPIO (setControlLooks [(controlId,True,(True,newlook))]) ps
	= (OutTwiddleItems,((listboxState,ls),ps))
where
	controlId				= listboxState.listboxId.controlId
	twiddled_items = twiddle idx1 idx2 items

//	Remove elements:
receiver (InCloseItems closeItems) ((listboxState=:{items,selection},ls),ps)
	| nrCloseItems==0
		= (OutCloseItems,((listboxState,ls),ps))
	# listboxState	= {listboxState & items=allItems, selection=newSelection}
	# (listboxState,newlook)
					= customlook listboxState
	# (newDomain,ps) = calcControlDomain allItems ps
	# ps		= appPIO (seq
							[ setControlViewDomain controlId newDomain
							, setControlLooks [(controlId,True,(True,newlook))]
							]) ps
	= (OutCloseItems,((listboxState,ls),ps))
where
	controlId				= listboxState.listboxId.controlId
	nrCloseItems			= length closeItems
	allItems				= [ item \\ item <- items & i <- [1..] | not (isMember i closeItems) ]
	newSelection			= removeMembers selection closeItems

//	Remove all:
receiver (InCloseAllItems) ((listboxState=:{items,selection},ls),ps)
	# listboxState	= {listboxState & items=allItems, selection=newSelection}
	# (listboxState,newlook)
					= customlook listboxState
	# (newDomain,ps) = calcControlDomain allItems ps
	# ps			= appPIO (seq
								[ setControlViewDomain controlId newDomain
								, setControlLooks [(controlId,True,(True,newlook))]
								]) ps
	= (OutCloseAllItems,((listboxState,ls),ps))
where
	controlId				= listboxState.listboxId.controlId
	allItems				= []
	newSelection			= []
	

openListBoxId :: !*env -> (!ListBoxId,!*env)	| Ids env
openListBoxId env
	# (cid, env)	= openId env
	# (r2id,env)	= openR2Id env
	= ({controlId=cid,r2Id=r2id},env)


//	The functions below take care of the proper communication with the receiver that
//	belongs to the listbox control.

getListBoxSelection :: !ListBoxId !(PSt .l) -> (!(!Bool,![(String,!Index)]),!PSt .l)
getListBoxSelection {r2Id} ps
	# ((_,maybe_out),ps)	= syncSend2 r2Id InGetSelection ps
	| isNothing maybe_out
		= ((False,[]),ps)
	# result					= case (fromJust maybe_out) of
									(OutGetSelection selection)	-> (True,selection)
									_							-> (False,[])
	| otherwise
		= (result,ps)

setListBoxSelection :: !ListBoxId ![Index] !(PSt .l) -> PSt .l
setListBoxSelection {r2Id} selection ps
	= snd (syncSend2 r2Id (InSetSelection selection) ps)

getListBoxItems :: !ListBoxId !(PSt .l) -> (!(!Bool,![String]),!PSt .l)
getListBoxItems {r2Id} ps
	# ((_,maybe_out),ps)	= syncSend2 r2Id InGetItems ps
	| isNothing maybe_out
		= ((False,[]),ps)
	# result					= case (fromJust maybe_out) of
									(OutGetItems items)	-> (True,items)
									_					-> (False,[])
	| otherwise
		= (result,ps)

openListBoxItems :: !ListBoxId !Index ![String] !(PSt .l) -> PSt .l
openListBoxItems {r2Id} index items ps
	= snd (syncSend2 r2Id (InOpenItems index items) ps)

appendListBoxItems :: !ListBoxId ![String] !(PSt .l) -> PSt .l
appendListBoxItems {r2Id} items ps
	= snd (syncSend2 r2Id (InAppendItems items) ps)

closeListBoxItems :: !ListBoxId ![Index] !(PSt .l) -> PSt .l
closeListBoxItems {r2Id} items ps
	= snd (syncSend2 r2Id (InCloseItems items) ps)

closeAllListBoxItems :: !ListBoxId !(PSt .l) -> PSt .l
closeAllListBoxItems {r2Id} ps
	= snd (syncSend2 r2Id (InCloseAllItems) ps)

upListBoxSelItem :: !ListBoxId !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
upListBoxSelItem lbId=:{r2Id} (ls,ps)
	// get sel
	# ((ok,sel),ps)	= getListBoxSelection lbId ps
	// if not single sel fail...
	| not ok || length sel <> 1
		= (False,(ls,ps))
	// if first fail...
	# (_,sel) = hd sel
	| sel == 1
		= (False,(ls,ps))
	// twiddle with prev
	# ((_,r),ps) = syncSend2 r2Id (InTwiddleItems sel (dec sel)) ps
	| isNothing r
		= (False,(ls,ps))
	# ls = twiddle sel (dec sel) ls
	# ps = setListBoxSelection lbId [dec sel] ps
	= (True,(ls,ps))
dnListBoxSelItem :: !ListBoxId !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
dnListBoxSelItem lbId=:{r2Id} (ls,ps)
	// get sel
	# ((ok,sel),ps)	= getListBoxSelection lbId ps
	// if not single sel fail...
	| not ok || length sel <> 1
		= (False,(ls,ps))
	// if last fail...
	# ((ok,its),ps)	= getListBoxItems lbId ps
	| not ok
		= (False,(ls,ps))
	# (_,sel) = hd sel
	| sel == length its
		= (False,(ls,ps))
	// twiddle with prev
	# ((_,r),ps) = syncSend2 r2Id (InTwiddleItems sel (inc sel)) ps
	| isNothing r
		= (False,(ls,ps))
	# ls = twiddle sel (inc sel) ls
	# ps = setListBoxSelection lbId [inc sel] ps
	= (True,(ls,ps))

showListBoxControl :: !ListBoxId !*(IOSt .l) -> *IOSt .l
showListBoxControl {controlId} io = showControls [controlId] io

hideListBoxControl :: !ListBoxId !*(IOSt .l) -> *IOSt .l
hideListBoxControl {controlId} io = hideControls [controlId] io

enableListBoxControl :: !ListBoxId !*(IOSt .l) -> *IOSt .l
enableListBoxControl {controlId} io = enableControls [controlId] io

disableListBoxControl :: !ListBoxId !*(IOSt .l) -> *IOSt .l
disableListBoxControl {controlId} io = disableControls [controlId] io

//	Auxiliary functions:

metricsLineHeight :: !FontMetrics -> Int
metricsLineHeight {fAscent,fDescent,fLeading} = fAscent+fDescent+fLeading

//smap :: (x -> s -> (y, s)) [x] s -> ([y],s)
smap f xs s
	= smap` xs [] s
where
	smap` [x:xs] ys s
		# (y,s)	= f x s
		= smap` xs [y:ys] s
	smap` _ ys s
		= (reverse ys,s)

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
	itm1 = items!!idx1`	// add error checks...
	itm2 = items!!idx2`	// add error checks...
	idx1` = dec idx1
	idx2` = dec idx2
	
