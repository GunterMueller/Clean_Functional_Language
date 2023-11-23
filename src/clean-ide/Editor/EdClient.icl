implementation module EdClient

import StdArray, StdList
import StdMaybe, StdPSt, StdPStClass, StdWindow
import StdClipboard
import EdMonad, EdState, EdMessage, EdFile
import EdSelection, EdText, EdVisualCursor
import EdVisualText
import EdCommon
import ExtNotice, StrictList

//sendToActiveWindow	:: (EditAction .l .p a) (EditorState,(PSt .l)) -> (Maybe a, (EditorState,(PSt .l)))
sendToActiveWindow :: .(*(EditState,*PSt *b) -> *(.c,*(EditState,*PSt *b))) !*(PSt *b) -> *(Maybe .c,*PSt *b) | Editor b
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
	
//message		:: Id (EditAction .l .p a) (EditorState,(PSt .l)) -> (Maybe a, (EditorState,(PSt .l)))
message :: !Id !.(*(EditState,*PSt *b) -> *(.c,*(EditState,*PSt *b))) !*(PSt *b) -> *(Maybe .c,*PSt *b) | Editor b;
message windowId monad pState
  # (editorState, pState)		= getEditorState pState
  # (maybeEditId, editorState)	= findReceiver windowId editorState
  | isNothing maybeEditId
  	= (Nothing, setEditorState editorState pState)
  # editId						= fromJust maybeEditId
  # (x, pState)					= appEditState editId monad pState
  # pState						= setEditorState editorState pState
  = (Just x, pState)


// Messages

msgSave :: EditAction *l nothing
msgSave = 
	getReadOnly							>>>= \readOnly ->
	IF readOnly
	THEN
		skip
	ELSE (
		getText								>>>= \text ->
		getPathName							>>>= \pathName ->
		getNewlineConvention				>>>= \newlineConv ->
		accEnv (writeText pathName newlineConv text)	>>>= \error ->
		IF (isNothing error)
		THEN
			( setNeedSave False
			)
		ELSE
			( appEnv (okNotice ["Save failed:",fromJust error])
			)
		)

msgCopy :: EditAction *l nothing
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

msgClear :: EditAction *MyEditorState nothing
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
		setUndoInfo {state = Undo, action = " Clear", uninfo = ClearInfo fragment position orderedSelection needsave}	>>>
		setNeedSave True													>>>
		vDoCursorSafe (
			vRemoveSelection			>>>
			mRemoveSelection										>>>
			vCenterCursor
			)
		)

msgCut :: EditAction *MyEditorState nothing
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

msgPaste :: EditAction *MyEditorState nothing
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
		setUndoInfo {state = Undo, action = " Paste", uninfo = PasteInfo fragment ofragment selection position needsave}
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

msgSetFont :: Font -> EditAction *l nothing
msgSetFont font
  = setFont font

msgGetFont :: EditAction .l Font
msgGetFont 
  = getFontInfo						>>>= \{ thefont } ->
	result thefont

msgSetTabs :: !(Int,Bool,Bool) -> EditAction *l nothing
msgSetTabs (t,a,s) =
	getFontInfo														>>>= \fontinfo ->
  	setFontInfo {fontinfo & tabSize = t, autoTab = a, showTabs = s} >>>
  	setFont fontinfo.thefont >>>
  	skip

msgGetTabs :: EditAction .l (Int,Bool,Bool)
msgGetTabs 
  = getFontInfo						>>>= \{ tabSize,autoTab,showTabs } ->
	result (tabSize,autoTab,showTabs)

