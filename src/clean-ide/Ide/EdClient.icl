implementation module EdClient

// only this module should be imported by users of the editor

import StdTuple, StdList, StdArray, StdMisc, StdEnum
import StdWindow, StdClipboard, StdPSt, StdPrintText, StdId, StdPStClass
import EdVisualText, EdVisualCursor, EdAction
import EdFind, EdState, EdMessage, EdMonad, EdFile
import PmPath
import StrictList
import balance, textcharstream
import EdCommon
import EdText
import IdeState, UtilNewlinesFile


isEditWin :: Id *(PSt *l) -> *(Bool,*PSt *l) | Editor l
isEditWin windowId pState
  # (editorState, pState)		= getEditorState pState
  # (maybeEditId, editorState)	= findReceiver windowId editorState
  # iseditwin					= not (isNothing maybeEditId)
  # pState						= setEditorState editorState pState
  = (iseditwin, pState)

message :: !Id !.(EditAction *l .r) !*(PSt *l) -> *(Maybe .r,*PSt *l) | Editor l
message windowId monad pState
  # (editorState, pState)		= getEditorState pState
  # (maybeEditId, editorState)	= findReceiver windowId editorState
  | isNothing maybeEditId
  	= (Nothing, setEditorState editorState pState)
  # editId						= fromJust maybeEditId
  # (x, pState)					= appEditState editId monad pState
  # pState						= setEditorState editorState pState
  = (Just x, pState)

sendToActiveWindow :: .(EditAction *l .r) !*(PSt *l) -> *(Maybe .r,*PSt *l) | Editor l
sendToActiveWindow editAction pState
  # (maybeId, pState)			= accPIO getActiveWindow pState
  | isNothing maybeId 
	= (Nothing,pState)	// fail silently
  #	windowId					= fromJust maybeId
    (editorState,pState) 		= getEditorState pState
  # (maybeEditId, editorState)	= findReceiver windowId editorState
  | isNothing maybeEditId
  	= (Nothing,pState)
  = message windowId editAction pState
	
//--

msgSetFont :: Font -> EditAction .l nothing
msgSetFont font
  = setFont font

msgGetFont :: EditAction .l Font
msgGetFont 
  = getFontInfo						>>>= \{ thefont } ->
	result thefont

msgSetTabs :: !(Int,Bool,Bool) -> EditAction .l nothing
msgSetTabs (t,a,s) =
	getFontInfo														>>>= \fontinfo ->
  	setFontInfo {fontinfo & tabSize = t, autoTab = a, showTabs = s} >>>
  	setFont fontinfo.thefont >>>
  	skip

msgGetTabs :: EditAction .l (Int,Bool,Bool)
msgGetTabs 
  = getFontInfo						>>>= \{ tabSize,autoTab,showTabs } ->
	result (tabSize,autoTab,showTabs)

msgSetMargin :: !Int -> EditAction .l nothing
msgSetMargin m =
	getFontInfo														>>>= \fontinfo ->
  	setFontInfo {fontinfo & marginWidth = m} >>>
  	setFont fontinfo.thefont >>>
  	skip

msgGetMargin :: EditAction .l Int
msgGetMargin 
  = getFontInfo						>>>= \{ marginWidth } ->
	result marginWidth

//--

msgUndo :: EditAction General nothing
msgUndo
	=	undoAction											>>>
		getUndoInfo											>>>= \undoinfo=:{state,uninfo} ->
		IF (state == Undo)
		THEN
			(case uninfo of
			(CopyInfo newclip oldclip) ->
				appEnv (setClipboard oldclip)					>>>
				setUndoInfo {undoinfo & state = Redo}
			(CutInfo newclip oldclip fragment position osel needsave) ->
				appEnv (setClipboard oldclip)					>>>
				vDoCursorSafe (
					vInsertText osel.start fragment		>>>
					vChangeSelectionTo osel				>>>
					mChangeSelectionTo osel				>>>
					vCenterCursor
					)											>>>
				setNeedSave needsave							>>>
				setUndoInfo {undoinfo & state = Redo}
			(ClearInfo fragment position osel needsave) ->
			    vDoCursorSafe (
					vInsertText osel.start fragment					>>>
					vChangeSelectionTo osel							>>>
					mChangeSelectionTo osel							>>>
					vCenterCursor
					)											>>>
				setNeedSave needsave							>>>
				setUndoInfo {undoinfo & state = Redo}
			(PasteInfo fragment ofragment selection position needsave) ->
			    vDoCursorSafe (
					vRemoveText {start=position,end=newCursorPos position fragment}	>>>
					vInsertText position ofragment									>>>
					vChangeSelectionTo selection									>>>
					mChangeSelectionTo selection									>>>
					vCenterCursor
					)															>>>
				setNeedSave needsave											>>>
				setUndoInfo {undoinfo & state = Redo}
			(ReplaceAllInfo nfrag osel nsel ulist needsave) ->
				vChangeSelectionTo emptySelection >>>
				getText														>>>= \text ->
				let
					txt` = undoReplaceAll (reverse ulist) text
				in
				vDoCursorSafe (
					// loop ulist and replace all nfrag's by ofrag
					setText txt` >>>
					vResetViewDomain										>>>
					vChangeSelectionTo osel									>>>
					mChangeSelectionTo osel									>>>
					vCenterCursor
					)					>>>
				setNeedSave needsave	>>>
				setUndoInfo {undoinfo & state = Redo}
			(UndoneInfo ini fin) ->
				setState ini									>>>
		//		getWindowId										>>>= \win ->
		//		appEnv (appPIO (updateWindow win Nothing))		>>>
				setUndoInfo {undoinfo & state = Redo}			>>>
				vResetViewDomain
			_ -> abort "EdClient: [msgUndo] unimplemented undo type"
			)
		ELSE	// assume state == Redo
			(case uninfo of
			(CopyInfo newclip oldclip) ->
				appEnv (setClipboard newclip)								>>>
				setUndoInfo {undoinfo & state = Undo}
			(CutInfo newclip oldclip fragment position osel needsave) ->
				appEnv (setClipboard newclip)								>>>
				vDoCursorSafe (
					vRemoveSelection										>>>
					mRemoveSelection										>>>
					vCenterCursor
					)														>>>
				/* should restore to pre-Undo */
				setNeedSave	True											>>>
				setUndoInfo {undoinfo & state = Undo}
			(ClearInfo fragment position osel needsave) ->
				vDoCursorSafe (
					vRemoveSelection											>>>
					mRemoveSelection										>>>
					vCenterCursor
					)														>>>
				/* should restore to pre-Undo */
				setNeedSave	True											>>>
				setUndoInfo {undoinfo & state = Undo}
			(PasteInfo fragment ofragment selection position needsave) ->
				let newPosition = newCursorPos position fragment
				in
			    vDoCursorSafe (
					vChangeSelectionTo selection								>>>
					vRemoveSelection											>>>
					mRemoveSelection										>>>
					vInsertText position fragment								>>>
					vChangeSelectionTo {start=newPosition,end=newPosition}		>>>
					mChangeSelectionTo {start=newPosition,end=newPosition}		>>>
					vCenterCursor
					)														>>>
				/* should restore to pre-Undo */
				setNeedSave	True											>>>
				setUndoInfo {undoinfo & state = Undo}
			(ReplaceAllInfo nfrag osel nsel ulist needsave) ->
				vChangeSelectionTo emptySelection >>>
				getText														>>>= \text ->
				let
					txt` = redoReplaceAll ulist text
				in
				vDoCursorSafe (
					// loop ulist and replace all nfrag's by ofrag
					setText txt` >>>
					vResetViewDomain										>>>
					vChangeSelectionTo nsel									>>>
					mChangeSelectionTo nsel									>>>
					vCenterCursor
					)					>>>
				setNeedSave True	>>>
				setUndoInfo {undoinfo & state = Undo}
			(UndoneInfo ini fin) ->
				setState fin												>>>
	//			getWindowId													>>>= \win ->
	//			appEnv (appPIO (updateWindow win Nothing))					>>>
				setUndoInfo {undoinfo & state = Undo}						>>>
				vResetViewDomain
			_ -> abort "EdClient: [msgUndo] unimplemented redo type"
			)
where
  	newCursorPos pos=:{col, row} SNil
  	  = pos
  	newCursorPos {col, row} (SCons string SNil)
  	  = {col = col + size string, row = row }
  	newCursorPos {col, row} strings
  	  = { col = size (slLast strings)
  	    , row = row + slLength strings - 1
  	    }

//--

msgSelectAll :: EditAction General nothing
msgSelectAll =
	getText																		>>>= \text ->
	let	linenr		= lastLineNr text
		(line,_)	= getLine linenr text
	in
	vDoCursorSafe (
		vChangeSelectionTo {start={row=0,col=0},end={row=linenr,col = size line}}
		)																		>>>
	mChangeSelectionTo {start={row=0,col=0},end={row=linenr,col = size line}}
	
msgCopy :: EditAction .l nothing
msgCopy =
	getText									>>>= \text ->
	getSelection							>>>= \selection ->
	accEnv getClipboard						>>>= \oldclip ->
	IF (isEmptySelection selection)
	THEN
	  ( skip )
	ELSE
	  (
		let orderedSelection	= orderSelection selection
			(fragment, _)		= getTextFragment orderedSelection text
		    string				= stringsToString fragment
		    newclip				= [toClipboard string]
		in
		appEnv (setClipboard newclip)			>>>
		setUndoInfo {state = Undo, action = " Copy", uninfo = CopyInfo newclip oldclip}
	  )

msgClear :: EditAction General nothing
msgClear =
	getSelection							>>>= \selection ->
	IF (selection.start==selection.end)
	THEN
		( skip )
	ELSE 
		(
	  	getText																>>>= \text ->
		getNeedSave															>>>= \needsave ->
		let orderedSelection	= orderSelection selection
			(fragment, _)		= getTextFragment orderedSelection text
			position = selection.end
		in
		setUndoInfo
			{ state = Undo
			, action = " Clear"
			, uninfo = ClearInfo fragment position orderedSelection needsave
			}							>>>
		setNeedSave True				>>>
		vDoCursorSafe (
			vRemoveSelection			>>>
			mRemoveSelection			>>>
			vCenterCursor
			)
		)

msgCut :: EditAction General nothing
msgCut =
	getReadOnly																>>>= \readOnly ->
	IF readOnly THEN msgCopy ELSE (
	getSelection															>>>= \selection ->
	IF (selection.start==selection.end)
	THEN
	  ( skip )
	ELSE 
	  (
	  	getText																>>>= \text ->
		accEnv getClipboard													>>>= \oldclip ->
		getNeedSave															>>>= \needsave ->
		let orderedSelection	= orderSelection selection
			(fragment, _)		= getTextFragment orderedSelection text
		    string				= stringsToString fragment
		    newclip				= [toClipboard string]
		    position = selection.end
		in
		appEnv (setClipboard newclip)										>>>
		setUndoInfo
			{ state = Undo
			, action = " Cut"
			, uninfo = CutInfo newclip oldclip fragment position orderedSelection needsave
			}	>>>
		setNeedSave True													>>>
		vDoCursorSafe (
			vRemoveSelection			>>>
			mRemoveSelection										>>>
			vCenterCursor
			)
	  ))

msgReplaceSelection :: String -> EditAction General nothing
msgReplaceSelection string
  =	getText								>>>= \text ->
  	getSelection						>>>= \selection ->
	getNeedSave							>>>= \needsave ->

	let orderedSelection	= orderSelection selection
		(ofragment, _)		= getTextFragment orderedSelection text
		fragment			= stringToStrings string
		position			= orderedSelection.start
		newPosition			= newCursorPos position fragment
	in
	vDoCursorSafe (
		vRemoveSelection					>>>
		mRemoveSelection										>>>
		vInsertText position fragment		>>>
		vChangeSelectionTo {start=newPosition,end=newPosition}	>>>
		mChangeSelectionTo {start=newPosition,end=newPosition}	>>>
		vCenterCursor
		)								>>>
	setNeedSave True					>>>
	setUndoInfo
		{ state = Undo
		, action = " Replace"
		, uninfo = PasteInfo fragment ofragment selection position needsave
		}
where
	newCursorPos :: !Position !TextFragment -> Position
  	newCursorPos pos=:{col, row} SNil
  	  = pos
  	newCursorPos {col, row} (SCons string SNil)
  	  = {col = col + size string, row = row }
  	newCursorPos {col, row} strings
  	  = { col = size (slLast strings)
  	    , row = row + slLength strings - 1
  	    }

msgPaste :: EditAction General nothing
msgPaste =
	getReadOnly								>>>= \readOnly ->
	IF readOnly THEN skip ELSE (
	accEnv getClipboard						>>>= \clipItems ->
	let maybeString = clipItemsToString	clipItems in
	IF (isNothing maybeString)
	THEN
	  ( skip )
	ELSE
	  (
	  	getText								>>>= \text ->
  		getSelection						>>>= \selection ->
		getNeedSave							>>>= \needsave ->
		let orderedSelection	= orderSelection selection
			fragment			= stringToStrings (fromJust maybeString)
			(ofragment, _)		= getTextFragment orderedSelection text
			position			= orderedSelection.start
			newPosition			= newCursorPos position fragment
		in
		vDoCursorSafe (
			vRemoveSelection					>>>
			mRemoveSelection										>>>
			vInsertText orderedSelection.start fragment		>>>
			vChangeSelectionTo {start=newPosition,end=newPosition}	>>>
			mChangeSelectionTo {start=newPosition,end=newPosition}	>>>
			vCenterCursor
			)										>>>
		setNeedSave True							>>>
		setUndoInfo
			{ state = Undo
			, action = " Paste"
			, uninfo = PasteInfo fragment ofragment selection position needsave
			}
	  ))
		
where
	newCursorPos :: !Position !TextFragment -> Position
  	newCursorPos pos=:{col, row} SNil			= pos
  	newCursorPos {col, row} (SCons string SNil)	= {col = col + size string	, row = row }
  	newCursorPos {col, row} strings				= {col = size (slLast strings), row = row + slLength strings - 1}
  	  
	clipItemsToString :: [ClipboardItem] -> Maybe String
	clipItemsToString clipItems	  = findString (map clipToString clipItems)
	
	clipToString :: ClipboardItem -> Maybe String
	clipToString clipItem = fromClipboard clipItem
	
	findString :: [Maybe String] -> Maybe String
	findString []				= Nothing
	findString [Just string:_]	= Just string
	findString [_:rest]			= findString rest

//--

msgSave :: EditAction General (Maybe String)
msgSave = 
	getReadOnly							>>>= \readOnly ->
	IF readOnly
	THEN (
		result (Just "File is read-only")
		)
	ELSE (
		getText											>>>= \text ->
		getPathName										>>>= \pathName ->
		getNewlineConvention							>>>= \newlineConv ->
		accEnv (getPrefs)								>>>= \{newline_handling} ->
		let
			nc = case newline_handling of
					(LeaveAlone _)						-> newlineConv
					(AlwaysUse NewlineConventionNone)	-> HostNativeNewlineConvention
					(AlwaysUse conv)					-> conv
		in
		accEnv (writeText pathName nc text)	>>>= \error ->
		IF (isNothing error)
		THEN
			( setNeedSave False					>>>
			  result Nothing
			)
		ELSE
			( result error
			)
		)

msgSaveTo :: !String -> EditAction General (Maybe String)
msgSaveTo pathName =
	getText											>>>= \text ->
	accEnv (getPrefs)								>>>= \{newline_handling} ->
	let
		nc = case newline_handling of
				(LeaveAlone conv)					-> conv
				(AlwaysUse NewlineConventionNone)	-> HostNativeNewlineConvention
				(AlwaysUse conv)					-> conv
	in
	accEnv (writeText pathName nc text)	>>>= \error ->
	IF (isNothing error)
	THEN
		( setNeedSave False							>>>
		  result Nothing
		)
	ELSE
		( result error
		)
	
msgBalance :: EditAction General nothing
msgBalance =
	getText							>>>= \text ->
	getSelection					>>>= \sel ->
	IF (sel.start == sel.end)
	THEN
		(
		let pos = sel.start
			(ok,nsel) = Text_Balance pos.row pos.col pos.row pos.col text in
		IF ok
		THEN (
			vDoCursorSafe (
				vChangeSelectionTo nsel		>>>
				mChangeSelectionTo nsel
				)
			)
		ELSE
			(appEnv (appPIO beep))
		)
	ELSE
		(
		let
			(ok,nsel) = Text_Balance sel.start.row sel.start.col sel.end.row sel.end.col text
		in
		IF ok
		THEN (
			vDoCursorSafe (
				vChangeSelectionTo nsel		>>>
				mChangeSelectionTo nsel
				)
			)
		ELSE
			(appEnv (appPIO beep))
		)

msgGetUndoState :: EditAction .l (UndoState,String)
msgGetUndoState
	=	getUndoInfo				>>>= \undoinfo ->
		result (undoinfo.state,undoinfo.action)

msgGetPathName :: EditAction .l String
msgGetPathName
	= getPathName

msgSetPathName :: String -> EditAction .l nothing
msgSetPathName path =
	setPathName path

msgGetNeedSave :: EditAction .l Bool
msgGetNeedSave
	= getNeedSave

msgSetNeedSave :: Bool -> EditAction .l nothing
msgSetNeedSave ns
	= setNeedSave ns

msgGetText :: EditAction .l Text
msgGetText
	= getText

msgSetText :: !Text -> EditAction .l nothing
msgSetText text =
	setText	text							>>>
  	setSelection emptySelection				>>>
  	vCenterCursor							>>>
  	vResetViewDomain						>>>
	setNeedSave True						>>>
	setUndoInfo {state = None, action = "", uninfo = NoInfo}
	
msgRevertText :: !Text -> EditAction General nothing
msgRevertText text =
	getSelection							>>>= \selection ->
	let realsel = validateSelection selection text in
	setText	text							>>>
	vChangeSelectionTo realsel					>>>
	mChangeSelectionTo realsel					>>>
	vResetViewDomain						>>>
	setNeedSave False						>>>							// DvA: only called by revert!
	setUndoInfo {state = None, action = "", uninfo = NoInfo}			// DvA: only called by revert!
	
msgGetSelection :: EditAction .l (String,Selection)
msgGetSelection 
  = getText							>>>= \text ->
	getSelection					>>>= \selection ->
	IF (selection.start == selection.end)
	THEN
	  (
	    result ("",selection)
	  )
	ELSE
	  (
		let orderedSelection	= orderSelection selection
			(fragment, _)		= getTextFragment orderedSelection text
		    string				= stringsToString fragment in
		result (string,orderedSelection)
	  )

msgChangeSelection :: Selection -> EditAction General nothing
msgChangeSelection selection =
	vDoCursorSafe (
		getText										>>>= \text ->
		let realsel = validateSelection selection text in
		vChangeSelectionTo realsel					>>>
		mChangeSelectionTo realsel					>>>
	  	vCenterCursor
	  	)
 	
msgScrollToCursor :: EditAction .l nothing
msgScrollToCursor
	= vCenterCursor


msgScrollToLine :: LineNr -> EditAction General nothing
msgScrollToLine line =
	vDoCursorSafe (
		getText									>>>= \text ->
		let realline = validateLineNr line text in
		vChangeSelectionTo {start={col=0,row=realline},end={col=0,row=realline}} >>>
		mChangeSelectionTo {start={col=0,row=realline},end={col=0,row=realline}} >>>
		vCenterCursor
		)

//-- Find & Replace support

/*
instance toString Selection where
  toString {start,end}
    = "{ start = " +++ toString start +++ ", end = " +++ toString end +++ "}"

instance toString Position where
  toString {col,row}
    = "{ col = " +++ toString col +++ ", row = " +++ toString row +++ "}"
*/

:: FRInfo =
	{ fr_pos			:: !Selection
	, fr_search			:: !String
	, fr_replace		:: !String
	, fr_ignore_case	:: !Bool
	, fr_match_words	:: !Bool
	, fr_backwards		:: !Bool
	, fr_wraparound		:: !Bool
	, fr_regexp			:: !Bool
	}

msgFind :: !FRInfo -> EditAction General Bool
msgFind fr
	=	getText							>>>= \text ->
		let
			maybesel`
				| fr.fr_regexp
					= regexpLineSearch fr.fr_pos fr.fr_backwards fr.fr_wraparound fr.fr_ignore_case fr.fr_match_words fr.fr_search text
					= simpleLineSearch fr.fr_pos fr.fr_backwards fr.fr_wraparound fr.fr_ignore_case fr.fr_match_words fr.fr_search text
			maybesel = maybesel`
		in
		IF (isNothing maybesel)
		THEN
			(result False)
		ELSE
			(
			let
				realsel = validateSelection (fromJust maybesel) text
			in
		    vDoCursorSafe (
				vChangeSelectionTo realsel					>>>
				mChangeSelectionTo realsel					>>>
			  	vCenterCursor
			  	)	>>>
		  	result True
			)

msgReplace :: !FRInfo -> EditAction General Bool
msgReplace fr =
	getText							>>>= \text ->
	let
		maybesel`
			| fr.fr_regexp
				= regexpLineSearch fr.fr_pos fr.fr_backwards fr.fr_wraparound fr.fr_ignore_case fr.fr_match_words fr.fr_search text
				= simpleLineSearch fr.fr_pos fr.fr_backwards fr.fr_wraparound fr.fr_ignore_case fr.fr_match_words fr.fr_search text
		maybesel = maybesel`
	in
	IF (isNothing maybesel)
	THEN
		(result False)
	ELSE
		(
		getNeedSave				>>>= \needsave ->
		let
			realsel				= validateSelection (fromJust maybesel) text
			orderedSelection	= orderSelection realsel
			(ofragment, _)		= getTextFragment orderedSelection text
			fragment`
				| fr.fr_regexp		
								# (line,_) = getLine orderedSelection.start.row text
								= regexpLineReplace orderedSelection fr.fr_backwards fr.fr_wraparound fr.fr_ignore_case fr.fr_match_words fr.fr_search fr.fr_replace line
								= Just fr.fr_replace
			mfragment			= fragment`
			jfragment`			= stringToStrings (fromJust mfragment)
			jfragment			= jfragment`
			position			= orderedSelection.start
			newPosition			= newCursorPos position jfragment
		in
		IF (isNothing mfragment)
		THEN
			(result False)
		ELSE (
			vDoCursorSafe (
				vChangeSelectionTo realsel							>>>
				vRemoveSelection									>>>
				mRemoveSelection										>>>
				vInsertText position jfragment						>>>
				vChangeSelectionTo {start=position,end=newPosition}	>>>
				mChangeSelectionTo {start=position,end=newPosition}	>>>
				vCenterCursor
				)					>>>
			setNeedSave True		>>>
			setUndoInfo
				{ state		= Undo
				, action	= " Replace"
				, uninfo	= PasteInfo jfragment ofragment realsel position needsave
				}					>>>
			result True
			)
	)
where
	newCursorPos :: !Position !TextFragment -> Position
  	newCursorPos pos=:{col, row} SNil
  	  = pos
  	newCursorPos {col, row} (SCons string SNil)
  	  = {col = col + size string, row = row }
  	newCursorPos {col, row} strings
  	  = { col = size (slLast strings)
  	    , row = row + slLength strings - 1
  	    }

msgReplaceAll :: !FRInfo -> EditAction General Int
msgReplaceAll fr =
// handle flags...

// ignore_case
// match_words
// backwards	<- pointless flag...
// wraparound	<- pointless flag...
// regexp

	getText							>>>= \text ->
	getNeedSave						>>>= \needsave ->
	let
		lines			= textToStrings text
		(ulist,lines`)	= allFun emptySelection [] ({e \\ e <- slToList lines})
		text`			= stringsToText (slFromList [e \\ e <-: lines`])
	in
	vChangeSelectionTo emptySelection	>>>
	mChangeSelectionTo emptySelection	>>>
	setText text`					>>>
	setNeedSave True				>>>
	setUndoInfo
		{ state		= Undo
		, action	= " ReplaceAll"
		, uninfo	= ReplaceAllInfo (stringToStrings fr.fr_replace) fr.fr_pos emptySelection ulist needsave
		}							>>>
	vResetViewDomain				>>>
	result (length ulist)
where
	searchFun :: !Selection !*{String} -> (!Maybe Selection,!*{String})
	searchFun pos txt
		| fr.fr_regexp
			= regexpLineSearch` pos False False fr.fr_ignore_case fr.fr_match_words fr.fr_search txt
			= simpleLineSearch` pos False False fr.fr_ignore_case fr.fr_match_words fr.fr_search txt

	replaceFun :: !Selection !*{String} -> (!String,!*{String})
	replaceFun sel txt
		| fr.fr_regexp
			# (line,txt) = uselect txt sel.start.row
			# mfrg = regexpLineReplace sel False False fr.fr_ignore_case fr.fr_match_words fr.fr_search fr.fr_replace line
			# nfrg = fromJust mfrg
			= (nfrg,replaceText` sel nfrg txt)
		= (fr.fr_replace,replaceText` sel fr.fr_replace txt)
		
	allFun :: !Selection ![(Selection,Selection,TextFragment,TextFragment)] !*{String} -> (![(Selection,Selection,TextFragment,TextFragment)],!*{String})
	allFun pos acc txt
		# (msel,txt)			= searchFun pos txt
		| isNothing msel
			= (reverse acc,txt)
		# sel			= fromJust msel
		# osel			= orderSelection sel
		# (frag,txt)	= getTextFragment` osel txt
		# (nfrg,txt)	= replaceFun osel txt
		# endpos		= newCursorPos osel.start nfrg
		= allFun {start=endpos,end=endpos} [(osel,{osel & end = endpos},frag,stringToStrings nfrg):acc] txt

  	newCursorPos :: !Position !String -> Position
  	newCursorPos {col, row} string
  	  = {col = col + size string, row = row }
  	
 	getTextFragment` :: !Selection !*{String} -> (!TextFragment,!*{String})
 	getTextFragment` {start={col=col1,row=row1},end={col=col2,row=row2}} text
	  | row1 == row2 
		# (line,text) = uselect text row1
		= ( SCons (line % (col1, col2 - 1)) SNil
		  , text
		  )
	  = abort "EdClient: ReplaceAll: fragment must be single line..."
  	
	replaceText` :: !Selection !String !*{String} -> *{String}
	replaceText` sel=:{start={col=col1,row=row1},end={col=col2,row=row2}} string text
		| row1 <> row2
		  = abort "EdClient: ReplaceAll: fragment must be single line..."
		# (firstLine,text)	= uselect text row1
		# left = firstLine%(0, col1 - 1)
		# right = firstLine%(col2, size firstLine - 1)
	
		# newLine			= left +++ string +++ right
		= update text row1 newLine
		

undoReplaceAll [] text
	= text
undoReplaceAll [(osel,nsel,ofrg,nfrg):rest] text
	# text = replaceText nsel ofrg text
	= undoReplaceAll rest text

redoReplaceAll [] text
	= text
redoReplaceAll [(osel,nsel,ofrg,nfrg):rest] text
	# text = replaceText osel nfrg text
	= redoReplaceAll rest text

//-- Ed Text Printing

msgPrint :: !PrintSetup -> EditAction .l PrintSetup
msgPrint printSetup
  = getText								>>>= \text ->
	getPathName							>>>= \pathName ->
	getFontInfo							>>>= \fontInfo ->
	getLineNumbers						>>>= \linenos ->
	accEnv (myPrintText printSetup pathName text fontInfo linenos)

myPrintText	:: !PrintSetup !String !Text !FontInfo !Bool !*env  -> (PrintSetup,*env)	| PrintEnvironments env
myPrintText printsetup path text info linenos env
	#	fdef	= getFontDef info.thefont
		((_,printsetup),env)	= printText2 path "page " True LeftJustify
					fdef
					info.tabSize
					textstream
					printsetup
					env
	= (printsetup,env)
where
	textstream
		| linenos
			= Text2TextCharStreamWithLinenrs info.tabSize text
		= Text2TextCharStream text

Text2TextCharStream txt
	# txt		= textToStrings txt
	# txt		= slMap (\str -> str +++. "\n") txt
	= {tcs_txt	= txt, tcs_col = 0, tcs_sav = (SNil,0)}

Text2TextCharStreamWithLinenrs tabWidth txt
	# txt		= textToStrings txt
	# txt		= tabs2spaces tabWidth txt
	# txt		= func 1 txt
	= {tcs_txt	= txt, tcs_col = 0, tcs_sav = (SNil,0)}
where
	width = 5
	
	func i SNil
		= SNil
	func i (SCons h t)
		= SCons ((pads width i) +++. h +++. "\n") (func (inc i) t)
	
	pads w i = blanks%(0,w-intlength) +++. intstring +++. " "
	where
		intstring = toString i
		intlength = size intstring
		blanks = "         "

msgDetab :: EditAction .l nothing
msgDetab =
	getText								>>>= \text ->
	let
		text1				= textToStrings text
		text2				= tabs2spaces 4 text1
		text`				= stringsToText text2
	in
	setText	text`							>>>
	vResetViewDomain						>>>
	setNeedSave True						>>>
	setUndoInfo {state = None, action = "", uninfo = NoInfo}
	

tabs2spaces tabwidth text
	# text = slMap fun` text
	= text
where
	fun` line
		# line = a2l line
		# s = length line
		# line = doit 0 s line [] tabwidth
		# line = l2a line
		= line
	where
		doit i s l m n
			| i >= s = reverse m
			# c = l!!i
			| c == '\t'
				# m = repeatn n ' ' ++ m
				= doit (inc i) s l m tabwidth
			= doit (inc i) s l [c:m] (safemod (dec n) tabwidth)
	
		safemod x m
			# s = x rem m
			| s <= 0 = s + m
			= s
		
		a2l a = [c \\ c <-: a]
		l2a l = {c \\ c <- l}

