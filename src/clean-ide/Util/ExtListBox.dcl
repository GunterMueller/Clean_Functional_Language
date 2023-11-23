definition module ExtListBox


//	Definition of an extended listbox control for the clean ide


import StdControl, StdControlClass, StdId, StdPSt

::	ExtListBoxId ps =
	{ controlId	:: !Id										// The Id of the outmost CompoundControl
	, receiverId	:: !R2Id (MessageIn ps) MessageOut		// The Id of the Receiver2Control that handles message passing
	}

::	MessageIn ps
	= InGetSelection										// Request to retrieve current selection
	| InSetSelection	[Index]								// Request to set the selection to the given index
	| InSetSelectAll										// Request to select all items
	| InGetItems											// Request to retrieve all current items
	| InOpenItems		Index [ExtListBoxItem ps]			// Request to add items behind the element with the given index
	| InAppendItems		[ExtListBoxItem ps]					// Request to add items behind the last element
	| InCloseItems		[Index]								// Request to remove items at the given index positions
	| InCloseAllItems										// Request to remove all current items
	| InExecItem		Index								// Request to execute function associated with given index
	| InSetPen			[PenAttribute]						// Request to set control pen
	| InGetPen												// Request to get control pen
	| InTwiddleItems Index Index

::	MessageOut
	= OutGetSelection	[(String,Index)]					// Reply to retrieve the current selection
	| OutSetSelection										// Reply to set the selection
	| OutGetItems		[String]							// Reply to get all items
	| OutOpenItems											// Reply to add items
	| OutAppendItems										// Reply to append items
	| OutCloseItems											// Reply to remove items
	| OutCloseAllItems										// Reply to remove all items
	| OutExecItem											// Reply to execute item
	| OutSetPen												// Reply to set the control pen
	| OutGetPen			[PenAttribute]						// Reply to get the control pen
	| OutTwiddleItems

:: ExtListBoxItem ps :== (String,IdFun ps,IdFun ps)

:: ExtListBoxControl ls ps
	= ExtListBoxControl
		[ExtListBoxItem ps]									// initial contents
		[Int]												// initial selected items
		([Int] ps -> ps)									// function to execture for new selection
		(ExtListBoxId ps)									// id for control
		[ControlAttribute *(*(ExtListBoxState ps,ls),ps)]	// attributes

instance Controls ExtListBoxControl

openExtListBoxId			:: !*env -> (!ExtListBoxId .a,!*env)	| Ids env

getExtListBoxSelection 		:: !(ExtListBoxId .a)								!(PSt .l) -> (!(!Bool,![(String,!Index)]),!PSt .l)
setExtListBoxSelection 		:: !(ExtListBoxId .a) ![Index]						!(PSt .l) -> PSt .l
setExtListBoxSelectionAll	:: !(ExtListBoxId .a)								!(PSt .l) -> PSt .l
getExtListBoxItems			:: !(ExtListBoxId .a)								!(PSt .l) -> (!(!Bool,![String]),!PSt .l)
openExtListBoxItems			:: !(ExtListBoxId .a) !Index ![ExtListBoxItem .a]	!(PSt .l) -> PSt .l
execExtListBoxItem  		:: !(ExtListBoxId .a) !Index						!(PSt .l) -> PSt .l
appendExtListBoxItems		:: !(ExtListBoxId .a) ![ExtListBoxItem .a]			!(PSt .l) -> PSt .l
closeExtListBoxItems		:: !(ExtListBoxId .a) ![Index]						!(PSt .l) -> PSt .l
closeAllExtListBoxItems		:: !(ExtListBoxId .a)								!(PSt .l) -> PSt .l

setExtListBoxPen :: !(ExtListBoxId .a) ![PenAttribute]							!(PSt .l) -> PSt .l
getExtListBoxPen :: !(ExtListBoxId .a)											!(PSt .l) -> (Maybe [PenAttribute],PSt .l)

showExtListBoxControl		:: !(ExtListBoxId .a)								!*(IOSt .l) -> *IOSt .l
hideExtListBoxControl		:: !(ExtListBoxId .a)								!*(IOSt .l) -> *IOSt .l
enableExtListBoxControl		:: !(ExtListBoxId .a)								!*(IOSt .l) -> *IOSt .l
disableExtListBoxControl	:: !(ExtListBoxId .a)								!*(IOSt .l) -> *IOSt .l

exec_next :: !Bool !(ExtListBoxId .ps)											!(PSt .l) -> (PSt .l)

upSelItem :: !(ExtListBoxId .ps) !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))
dnSelItem :: !(ExtListBoxId .ps) !*([a],!*PSt .l) -> *(Bool,*([a],*PSt .l))

mouseFilter :: !MouseState -> Bool;

// following state only fully exported to get attribution correct...
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

