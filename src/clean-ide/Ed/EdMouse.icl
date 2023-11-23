implementation module EdMouse

// handling mouse events

import StdClass, StdInt, StdBool, StdArray, StdChar, StdList, StdTuple
import StdIOCommon, StdPSt, StdWindow
import EdVisualCursor, EdVisualText, EdSelection

import EdAction, EdMonad, EdCommon
import Platform

platformCommand mods
	:== PlatformDependant mods.controlDown mods.commandDown

/* editWindowMouse wraps the monadic mouse function, so that the type
 * conforms to that of a call-back function in the Object I/O library
 */
editWindowMouse :: MouseState (!EditState, !PSt PLocState) -> (EditState, PSt PLocState)
editWindowMouse mouseState state
  = noResult
	  (
	  	setVirtualX 0	>>>
	  	mouse mouseState
	  ) state 
/* P4 version
editWindowMouse :: Tree MouseState (!EditState, !PSt PLocState) -> (EditState, PSt PLocState)
editWindowMouse tree mouseState state
  # state = p4mouse tree mouseState state
*/

mouse :: MouseState -> EditMonad (PSt PLocState) nothing
mouse (MouseDown point mods=:{shiftDown} nrDown)
  = vHideCursor					>>>
    getText						>>>= \text ->
    getFontInfo					>>>= \fontInfo ->
	let
		position = pointToPosition point text fontInfo
	in
	IF ( platformCommand mods )
	THEN
	  ( case nrDown of
			1 -> singleClick position
			2 -> controlDoubleClick shiftDown position
			3 -> tripleClick position
			_ -> skip
	  )
	ELSE
	(
	IF shiftDown
	THEN 
	  ( shiftClick position )
	ELSE
	  ( case nrDown of
			1 -> singleClick position
			2 -> doubleClick position
			3 -> tripleClick position
			_ -> skip
	  )
	)        	  
mouse (MouseDrag point modifiers)		 // mouse drag
  = getSelection						>>>= \selection -> 
	getText								>>>= \text ->
	getFontInfo							>>>= \fontInfo ->
	let
		newPosition = pointToPosition point text fontInfo
	in
	getSelectMode						>>>= \selectMode ->
	
	// change the selection depending on the current selection mode
	(case selectMode of 
		SelectChars ->
			vChangeSelectionTo {start=selection.start, end=newPosition} 

		SelectWords firstWord ->
			selectWordAt newPosition		>>>= \endSelection ->
			
			IF (newPosition < firstWord.end)
			THEN
			  ( vChangeSelectionTo { start=firstWord.end
			  					   , end=endSelection.start
			  					   }
			  )
			ELSE
			  (
			  	vChangeSelectionTo { start=firstWord.start
			  					   , end=endSelection.end
			  					   }
			  )
		
		SelectLines firstLine ->
			getText						>>>= \text ->
			vChangeSelectionTo (selectLines firstLine newPosition.row text)
	)									>>>
	vDragCursor point

mouse (MouseUp point modifiers)					   // mouse up handling
  = getSelection						>>>= \selection ->
    mChangeSelectionTo selection		>>>
    IF (isEmptySelection selection)
    THEN ( vShowCursor )
    ELSE ( skip )

mouse _											   // ignore other mouse events
  = skip

// single click
//singleClick :: .Position -> .(*(EditState,*PSt *General) -> *(b,*(EditState,*PSt *General)));
singleClick position =
	vChangeSelectionTo 
		{start=position,end=position}			>>>
	setSelectMode SelectChars					>>>
    getUndoInfo                                     >>>= \undoinfo ->
    case undoinfo.uninfo of
    (InsertInfo True state) -> setUndoInfo {undoinfo & uninfo=(InsertInfo False state)}
    (RemoveInfo True state) -> setUndoInfo {undoinfo & uninfo=(RemoveInfo False state)}
    _ -> skip

// double click
//doubleClick :: .Position -> .(*(EditState,*PSt *General) -> *(b,*(EditState,*PSt *General)));
doubleClick position =
	selectWordAt position						>>>= \selection ->
	vChangeSelectionTo selection				>>>
	setSelectMode (SelectWords selection)

// triple click
//tripleClick :: .Position -> .(*(EditState,*PSt *General) -> *(b,*(EditState,*PSt *General)));
tripleClick position=:{row} =
	getText										>>>= \text ->
	vChangeSelectionTo
		 (selectLines row row text)				>>>
 	setSelectMode (SelectLines row)

// shift click
//shiftClick :: .Position -> .(*(EditState,*PSt *General) -> *(b,*(EditState,*PSt *General)));
shiftClick position =
	getSelection								>>>= \selection ->
	vChangeSelectionTo
		{start=selection.start, end=position}

//--

noMouseMoved :: !MouseState -> Bool
noMouseMoved (MouseMove _ _) = doP4
noMouseMoved _				 = True

//-- P4 --- !!! Also involves modifications to EdMonad !!!

doP4 :== False
noP4 :== True
/*
import StdTimer,tooltip,PmParse,UtilStrictLists,EdFile,treeparse

p4mouse boom mouseState state
  | noP4 = state
  # (winId,state)	= getWindowId state
  # (timId,state)	= getTimerId state
  # pos				= getMouseStatePos mouseState
  # (oldpos,state)	= getToolPt state
  # state			= case (pos == oldpos) of
  						True	-> state
  						_		-> p4fun boom timId winId pos state
  # (_,state)		= setToolPt pos state
  = state

p4fun boom timerId windowId pos state
    # (text,state)		= getText state
    # (fontInfo,state)	= getFontInfo state
	# position			= pointToPosition pos text fontInfo
	# (sel,state)		= selectWordAt position state
	# orderedSelection	= orderSelection sel
	# (fragment, _)		= getTextFragment orderedSelection text
	# str				= stringsToString fragment
	# (es,ps)			= state
	# ps				= appPIO (closeTimer timerId) ps
	# (_,ps)			= openTimer Void (tdef boom timerId windowId pos str) ps 
	= (es,ps)

tdef boom timerId winId pos str = Timer (1 * ticksPerSecond) NilLS [TimerId timerId,TimerFunction tfunctie]
where
	tfunctie nr_of_intervals (ls,ps)
//		# (def,ps)	= findDefinition str ps
		# def		= searchTree str boom
		# ps		= ShowToolTip winId pos.x pos.y def ps
		# ps		= appPIO (closeTimer timerId) ps
		= (ls,ps)

//    # (boom, ps) 	= readFileInTree ps

findDefinition str ps
	# mod				= "C:\\Projects\\CleanIDE\\Ed\\EdText.dcl"
	# ((imp,pos),ps)	= accFiles (FindDefinitionInFile False Nil str mod) ps
	# found = case pos of
		(Pos ln cn tl)	-> Just ln
		(Cls ln cn tl)	-> Just ln
		_				-> Nothing
	| isNothing found
		= (str+++" not found ",ps)
	# ln				= fromJust found
	# ((txt,_,_),ps)	= readText mod ps
	| isError txt
		= (mod+++" not read ",ps)
	# txt				= fromOk txt
	# (line,txt)		= getLine ln txt
	= (line,ps)
*/
