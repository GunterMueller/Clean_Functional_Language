implementation module EdKeyMapping

// configuring the key mapping of the editor

import StdArray,StdEnum, StdFunc, StdMisc,StdOrdList,StdTuple
import StdFileSelect,StdPStClass,StdWindow
import EdState, Table, StdListBox
import StrictList, ioutil
import EdActionType
import Platform

KeyMapFileName	:== "default.km"

//--

MAX_KEY_BINDINGS	:== 4

:: KeyMapping :== Table KeyCode Action

:: KeyCode
	= KeyCode MyModifiers SpecialKey

dummyKeycode = KeyCode NO_MODIFIERS helpKey

dummyAction = Insert SNil

instance == KeyCode where
  (==) (KeyCode myModifiers  specialKey)
       (KeyCode myModifiers` specialKey`)
    = myModifiers == myModifiers` && specialKey == specialKey`

instance toString KeyCode where
  toString (KeyCode myModifiers key)
    =	(if (myModifiers bitand SHIFT <> 0) "Shift+" "")
    +++	(if (myModifiers bitand CTRL <> 0) "Ctrl+" "") 
    +++	(if (myModifiers bitand ALT <> 0) "Alt+" "") 
    +++	toString key

instance fromString KeyCode
where
	fromString s
		# (shift,s) = hasprefix "Shift+" s
		# (ctrl,s) = hasprefix "Ctrl+" s
		# (alt,s) = hasprefix "Alt+" s
		# key = fromString s
		# modifiers = NO_MODIFIERS + (if shift SHIFT 0) + (if ctrl CTRL 0) + (if alt ALT 0)
		= KeyCode modifiers key
	where
		hasprefix p s
			# x = size p - 1
			| p == s%(0,x)
				= (True,s%(x+1,size s - 1))
			= (False,s)

instance fromString SpecialKey
where
	fromString s = case s of
		"BackSpaceKey"	-> backSpaceKey
		"BeginKey"		-> beginKey
		"ClearKey"		-> clearKey
		"DeleteKey"		-> deleteKey
		"DownKey"		-> downKey
		"EndKey"		-> endKey
		"EnterKey"		-> enterKey
		"EscapeKey"		-> escapeKey
		"F1Key"			-> f1Key
		"F2Key"			-> f2Key
		"F3Key"			-> f3Key
		"F4Key"			-> f4Key
		"F5Key"			-> f5Key
		"F6Key"			-> f6Key
		"F7Key"			-> f7Key
		"F8Key"			-> f8Key
		"F9Key"			-> f9Key
		"F10Key"		-> f10Key
		"F11Key"		-> f11Key
		"F12Key"		-> f12Key
		"F13Key"		-> f13Key
		"F14Key"		-> f14Key
		"F15Key"		-> f15Key
		"HelpKey"		-> helpKey
		"LeftKey"		-> leftKey
		"PgDownKey"		-> pgDownKey
		"PgUpKey"		-> pgUpKey
		"ReturnKey"		-> returnKey
		"RightKey"		-> rightKey
		"UpKey"			-> upKey
		_				-> helpKey	//some silly default
		
KeyMapFileVersion :== "1.0"

SaveKeyMapFile	:: !{#Char} !KeyMapping !*Files -> (!Bool, !*Files);
SaveKeyMapFile	keymapPath keyMapping files
	#! (opened, file, files)	=	fopen keymapPath FWriteText files
	| not opened
		=	(False, files)
	#! options					=	WriteTable dummyKeycode dummyAction keyMapping
	#! file						=	WriteOptionsFile KeyMapFileVersion options file
	=	fclose file files
	
ReadKeyMapFile	:: !{#Char} !*Files -> ((!KeyMapping, !Bool, !{#Char}),!*Files)
ReadKeyMapFile keymapPath ps
	#	(opened, file, ps)		= fopen keymapPath FReadData ps
	| not opened
		= ((tableNew,False,"The file \"" +++  keymapPath +++ "\" could not be opened."),ps)
	#	(version, file)			= ReadVersion file
	| version <> KeyMapFileVersion
		#	(_, ps)				= fclose file ps
		=	((tableNew,False,"The file \"" +++  keymapPath +++ "\" has the wrong version."+++version+++"<<<"),ps)
	#!	(options, file)			= ReadOptionsFile file
		keyMapping				= ReadTable dummyKeycode dummyAction options
		(closed, ps)			= fclose file ps
	| not closed
		=	((keyMapping, True,"The file \"" +++ keymapPath +++ "\" clould not be closed."), ps)	// warning genereren of zo?
	=	((keyMapping, True,""), ps)
	
saveKM km ps
	# (fn,ps) = selectOutputFile "Save keymapping as..." "*.km" ps
	| isNothing fn
		= ps
	# fn = fromJust fn
	# (ok,ps) = accFiles (SaveKeyMapFile fn km) ps
	| not ok
		= ps
	= ps

openKM ps
	# (fn,ps) = selectInputFile ps
	| isNothing fn
		= (Nothing,ps)
	# fn = fromJust fn
	# ((km,ok,msg),ps) = accFiles (ReadKeyMapFile fn) ps
	| not ok
		= (Nothing,ps)
	=  (Just km,ps)

// findAction searches the key mapping table for a key that
// matches the keyboard state. If it finds a match, it returns
// the corresponding action.

findAction :: !KeyboardState !KeyMapping -> Maybe Action
findAction keyboardState keyMapping
	| isEmpty matches	= Nothing
	= Just (hd matches)
where
	keyCode = convertKeyboardState keyboardState
	matches	= tableLookup keyCode keyMapping
  
// convertKeyboardState converts the I/O lib type KeyboardState
// to the KeyCode type, which can be used to index the key mapping.

convertKeyboardState :: KeyboardState -> KeyCode
convertKeyboardState (SpecialKey special _ modifiers )
  = KeyCode (convertModifiers modifiers) special
convertKeyboardState (CharKey char _)
  = abort "convertKeyboardState (EdKeyMapping.icl): character key not allowed"
convertKeyboardState KeyLost
  = abort "convertKeyboardState (EdKeyMapping.icl): key lost allowed"

macKeyMapping :: KeyMapping
macKeyMapping
  = foldr tableInsert tableNew
	[ (KeyCode (SHIFT + ALT) 	leftKey,		Select	WordLeft)
	, (KeyCode (CTRL + SHIFT)	leftKey,		Select	StartOfLine)
	, (KeyCode (SHIFT)			leftKey,		Select	CharLeft)
	, (KeyCode (ALT)			leftKey,		Move	WordLeft)
	, (KeyCode (CTRL)			leftKey,		Move	StartOfLine)
	, (KeyCode NO_MODIFIERS		leftKey,		Move	CharLeft)

	, (KeyCode (ALT + SHIFT)	rightKey,		Select	WordRight)
	, (KeyCode (SHIFT + CTRL)	rightKey,		Select	EndOfLine)
	, (KeyCode (SHIFT)			rightKey,		Select	CharRight)
	, (KeyCode (ALT)			rightKey,		Move	WordRight)
	, (KeyCode (CTRL)			rightKey,		Move	EndOfLine)
	, (KeyCode NO_MODIFIERS		rightKey,		Move	CharRight)

	, (KeyCode (ALT + SHIFT)	upKey,			Select	PageUp)
	, (KeyCode (CTRL + SHIFT)	upKey,			Select	StartOfText)
	, (KeyCode (SHIFT)			upKey,			Select	LineUp)
	, (KeyCode (ALT)			upKey,			Move	PageUp)
	, (KeyCode (CTRL)			upKey,			Move	StartOfText)
	, (KeyCode NO_MODIFIERS		upKey,			Move	LineUp)

	, (KeyCode (ALT + SHIFT)	downKey,		Select	PageDown)
	, (KeyCode (CTRL + SHIFT)	downKey,		Select	EndOfText)
	, (KeyCode (SHIFT)			downKey,		Select	LineDown)
	, (KeyCode (ALT)			downKey,		Move	PageDown)
	, (KeyCode (CTRL)			downKey,		Move	EndOfText)
	, (KeyCode NO_MODIFIERS		downKey,		Move	LineDown)

	, (KeyCode NO_MODIFIERS		beginKey,		Scroll	StartOfText)
	, (KeyCode NO_MODIFIERS		endKey,			Scroll	EndOfText)
	, (KeyCode NO_MODIFIERS		pgUpKey,		Scroll	PageUp)
	, (KeyCode NO_MODIFIERS		pgDownKey,		Scroll	PageDown)
		
	, (KeyCode (CTRL)			clearKey,		Remove	EndOfLine)
	, (KeyCode (ALT)			clearKey,		Remove	WordRight)
	, (KeyCode NO_MODIFIERS		clearKey,		Remove	CharRight)
	
	, (KeyCode (CTRL)			deleteKey,		Remove	EndOfLine)
	, (KeyCode (ALT)			deleteKey,		Remove	WordRight)
	, (KeyCode NO_MODIFIERS		deleteKey,		Remove	CharRight)
	
	, (KeyCode (CTRL)			backSpaceKey,	Remove	StartOfLine)
	, (KeyCode (ALT)			backSpaceKey,	Remove	WordLeft)
	, (KeyCode NO_MODIFIERS		backSpaceKey,	Remove	CharLeft)
	]

allKeys
      = PlatformDependant
        // Windows
        [ leftKey, rightKey, upKey, downKey
		, pgUpKey, pgDownKey, /*clearKey,*/ deleteKey	// ClearKey only on MacOS...
		, backSpaceKey, beginKey, endKey
		, f1Key, f2Key, f3Key, f4Key, f5Key
		, f6Key, f7Key, f8Key, f9Key, f10Key
		, f11Key, f12Key, f13Key, f14Key, f15Key
		]
		// Macintosh
        [ leftKey, rightKey, upKey, downKey
		, pgUpKey, pgDownKey, clearKey, deleteKey	// ClearKey only on MacOS...
		, backSpaceKey, beginKey, endKey
		, f1Key, f2Key, f3Key, f4Key, f5Key
		, f6Key, f7Key, f8Key, f9Key, f10Key
		, f11Key, f12Key, f13Key, f14Key, f15Key
		]

/*** MyModifiers ***/

:: MyModifiers :== Int

NO_MODIFIERS	:== 0
SHIFT			:== 1
CTRL			:== 2
ALT				:== 4

convertModifiers :: Modifiers -> MyModifiers
convertModifiers { shiftDown, altDown, controlDown, optionDown, commandDown }
  = ( if shiftDown SHIFT 0 )
  + ( if (controlDown || commandDown) CTRL 0 )
  + ( if (altDown || optionDown) ALT 0 )
		

/*********************************************************
 THE DIALOG THAT ALLOWS THE USER TO CHANGE THE KEY MAPPING
 *********************************************************/

:: KeyMappingDialogState
	= { keyMapping		:: KeyMapping
	  , dialogFont		:: Font
	  }
	  
configureKeyMapping :: KeyMapping (KeyMapping (PSt .l) -> (PSt .l)) (PSt .l) -> (PSt .l)
configureKeyMapping keyMapping setKeyMapping pstateIds

	// Compute the line height of the dialog font
	
  # (font, pstate)			= accScreenPicture openDialogFont pstate
  # (metrics, pstate)		= accScreenPicture (getFontMetrics font)  pstate
    lineHeight				= metrics.fAscent + metrics.fDescent + metrics.fLeading
  
	// Compute the width of the widest action description and key description
	
  # (actionWidths, pstate)	= accScreenPicture (getFontStringWidths font (map toString allActions)) pstate
    maxActionWidth			= maxList actionWidths
  # (keyWidths, pstate)		= accScreenPicture (getFontStringWidths font (map toString allKeys)) pstate
	(maxModWidth, pstate)	= accScreenPicture (getFontStringWidth font "Ctrl+Alt+Shift+") pstate
    maxKeyWidth				= maxList keyWidths + maxModWidth
   
	// keyControl is a control where you can set a certain key and see what
	// action it is associated with. The size depends on both its own size and
	// the size of the actionControl. To compute the sizes of both controls, they 
	// are passed dummy arguments (i.e. []) first. Then the maximum width is computed 
	// and the sizes of both controls are based on this width.
	
	// Here the size of the keyControl is computed. It is passed the dummy argument [], because
	// the maximum width is not known yet. 
	
  # (keySize, pstate)		= controlSize (keyControl maxActionWidth lineHeight []) False Nothing Nothing Nothing pstate
  # listBox					= ListBoxControl [] [] listBoxId 
									[ ControlViewSize {w=maxModWidth+maxKeyWidth,h=3*lineHeight}
									] 
  # (actionSize, pstate)	= controlSize (actionControl listBox []) False Nothing Nothing Nothing pstate
	maxWidth				= max actionSize.w keySize.w
  # (_, pstate)				= openModalDialog
  								{ keyMapping = keyMapping, dialogFont = font }	// local state of dialog
  								(dialog	maxWidth keySize actionSize maxActionWidth lineHeight listBox)			// dialog definition
  								pstate
  = pstate
where
	actionControl listBox sizeAttr
	  =		CompoundControl
	  		(	TextControl "Action:"	[ControlWidth (ContentWidth "Mapped from:"), ControlPos (Left, zero) ]
			:+:	PopUpControl	( zip2	(map toString allActions)
  		           					(repeat updateMappedFrom)
								) 1						[ ControlId actionId ]
			:+:	TextControl "Mapped from:" 					[ ControlPos (Left, zero) ]			
			:+: listBox
	  		) [ ControlPos (Left, zero), ControlLook True box : sizeAttr]
    keyControl maxActionWidth lineHeight sizeAttr
	  =		CompoundControl
	  		(	TextControl "Key:"									[ ControlPos (Left, zero) ]
			:+:	CheckControl [ ("Shift +", Nothing, NoMark, updateMappedTo) ] (Columns 1)	[ ControlId shiftId ]
			:+:	CheckControl [ ("Ctrl +",  Nothing, NoMark, updateMappedTo) ] (Columns 1)	[ ControlId ctrlId ]
			:+:	CheckControl [ ("Alt +",   Nothing, NoMark, updateMappedTo) ] (Columns 1)	[ ControlId altId ]
			:+:	PopUpControl	( zip2	(map toString allKeys)
										(repeat updateMappedTo)
								) 1									[ ControlId keyId ]
			:+:	TextControl "Currently mapped to:"  		[ ControlPos (Left, zero) ]
			:+: TextControl "" [ControlWidth (PixelWidth maxActionWidth),ControlId mappedToId]
			) [ ControlPos (Left, zero), ControlLook True box: sizeAttr]
	buttonsControl
	  =		ButtonControl "Open..."	[ControlPos (Left, zero), ControlFunction openkm]
	  :+:	ButtonControl "Save..." [ControlFunction savekm]
	  :+:	ButtonControl "Bind"  	[ControlFunction bindKey]
	  :+:	ButtonControl "Remove binding" [ ControlFunction removeBinding ]
	  :+:	ButtonControl "Cancel" 		[ ControlFunction (noLS (closeWindow dialogId)) ]
	  :+:	ButtonControl "Ok" 			[ ControlId okId
	  										, ControlFunction storeKeyMapping 
	  										]
    openkm (ls,ps)
    	# (km,ps) = openKM ps
    	| isNothing km = (ls,ps)
    	# km = fromJust km
    	= updateMappedFrom (updateMappedTo ({ls & keyMapping = km},ps))
    savekm (ls=:{keyMapping},ps)
    	# ps = saveKM keyMapping ps
    	= (ls,ps)
    dialogContents maxWidth keySize actionSize maxActionWidth lineHeight listBox
      =		(keyControl maxActionWidth lineHeight)		[ ControlViewSize { keySize & w = maxWidth }]
      :+:	(actionControl listBox)	[ ControlViewSize { actionSize & w = maxWidth }]
      :+:	buttonsControl
      
    dialog maxWidth keySize actionSize maxActionWidth lineHeight listBox
	  = Dialog "Key mapping" (dialogContents maxWidth keySize actionSize maxActionWidth lineHeight listBox)
			[ WindowId dialogId
			, WindowOk okId
			, WindowInit (seq [ updateMappedFrom, updateMappedTo ])
			]
	(dialogId,pstateIds0)			= openId pstateIds
	(shiftId,pstateIds1)			= openId pstateIds0
	(altId,pstateIds2)				= openId pstateIds1
	(ctrlId,pstateIds3)				= openId pstateIds2
	(okId,pstateIds4)				= openId pstateIds3
	(keyId,pstateIds5)				= openId pstateIds4
	(actionId,pstateIds6)			= openId pstateIds5
	(mappedToId,pstateIds7)			= openId pstateIds6
	(listBoxId, pstate)				= accPIO openListBoxId pstateIds7
	
	// updateMappedTo updates the text control that displays which action
	// a key is currently mapped to.
	
	updateMappedTo (dialogState=:{keyMapping}, pstate)
      # (wstate, pstate)	= accPIO (getWindow dialogId) pstate
      | isNothing wstate = (dialogState,pstate)
      # wstate = fromJust wstate
		keyCode					= getKeyCode wstate
		actions					= tableLookup keyCode keyMapping
		text					= if (isEmpty actions) "<nothing>" (toString (hd actions))
	  # pstate					= appPIO (setControlTexts [(mappedToId, text)]) pstate
	  = (dialogState, pstate)		
	
	// updateMappedFrom updates the list box that displays the keys that are
	// currently associated with the selected action.
		
	updateMappedFrom (dialogState=:{keyMapping}, pstate)
      # (wstate, pstate)	= accPIO (getWindow dialogId) pstate
      | isNothing wstate = (dialogState,pstate)
      # wstate = fromJust wstate
		actionIndex				= getPopUp actionId wstate
		action					= allActions !! actionIndex
		keys					= tableLookup action (tableInvert keyMapping)
		keyNames				= map toString keys
	  # ((_, strings), pstate)	= getListBoxItems	listBoxId pstate
	  # pstate					= closeListBoxItems listBoxId [1..length strings] pstate
	  # pstate					= openListBoxItems	listBoxId 0 keyNames pstate
      = (dialogState, pstate)
              
    box :: Look
	box = \_ { newFrame } -> draw newFrame
	
	// storeKeyMapping stores the possibly changed key mapping,
	// (the local state of the dialog) in the global state.
	
	storeKeyMapping (dialogState=:{keyMapping}, pstate)
	  # pstate			= setKeyMapping keyMapping pstate
	  # pstate			= closeWindow dialogId pstate
	  = (dialogState, pstate)
	
	// getCheckbox returns the status of a single checkbox in 
	// as a boolean. It simplifies the complicated result from
	// the I/O lib function, i.e. [(Bool,Maybe [Index])].
	
	getCheckbox :: Id WState -> Bool
	getCheckbox id wstate
		# (ok,cs) = getCheckControlSelection id wstate
		| not ok = abort "EdKeyMapping[getCheckbox]: wrong id"
		| isNothing cs = abort "EdKeyMapping[getCheckbox]: strange error"
		# cs = fromJust cs
		= not (isEmpty cs)

	// getPopUp returns the index (first = 0) of the currently selected
	// item in the popup control
	
	getPopUp :: Id WState -> Int
	getPopUp id wstate
		# (ok,cs) = getPopUpControlSelection id wstate
		| not ok = abort "EdKeyMapping[getPopUp]: wrong id"
		| isNothing cs = abort "EdKeyMapping[getPopUp]: strange error"
		# cs = fromJust cs
		= dec cs
     
	// getKeyCode computes the key code given the current settings in
	// the dialog (modifiers + key)
	
	getKeyCode wstate
		# shift	= getCheckbox shiftId wstate
		# ctrl	= getCheckbox ctrlId wstate
		# alt	= getCheckbox altId wstate
		# myModifiers
				= (if shift SHIFT 0) + (if ctrl CTRL 0) + (if alt ALT 0)
		= KeyCode myModifiers key
	  where
		// get the current index of the key popup menu and find the corresponding key
		key						= allKeys !! keyIndex
		keyIndex				= getPopUp keyId wstate
	    	  

	// removeBinding removes the selected key bindings
	
	removeBinding :: (u:KeyMappingDialogState, PSt .l) -> (u:KeyMappingDialogState, PSt .l)
	removeBinding (dialogState=:{ keyMapping}, pstate)
      # (wstate, pstate)	= accPIO (getWindow dialogId) pstate
      | isNothing wstate = (dialogState,pstate)
      # wstate = fromJust wstate

		// find the current action

		actionIndex				= getPopUp actionId wstate
		action					= allActions !! actionIndex

		currentKeys				= tableLookup action (tableInvert keyMapping)
		((_, sel), pstate)		= getListBoxSelection listBoxId pstate
		indices					= map snd sel
		pstate					= closeListBoxItems listBoxId indices pstate
		selectedKeys			= foldr (\index rest -> [ currentKeys !! (index-1) : rest ]) [] indices
		
		dialogState				= { dialogState 
								  & keyMapping = foldr tableRemove keyMapping selectedKeys
								  }
		
		(dialogState, pstate)	= updateMappedFrom (dialogState, pstate)
		(dialogState, pstate)	= updateMappedTo   (dialogState, pstate)
				
		
	  = (dialogState, pstate)
	    
	// bindKey adds a binding to the key mapping table. It binds the
	// currently selected action to the selected key (including modifiers).
	
	bindKey :: (u:KeyMappingDialogState, PSt .l) -> (u:KeyMappingDialogState, PSt .l)
	bindKey (dialogState=:{ keyMapping}, pstate)
      # (wstate, pstate)	= accPIO (getWindow dialogId) pstate
      | isNothing wstate = (dialogState,pstate)
      # wstate = fromJust wstate
		keyCode					= getKeyCode wstate
		// find the current action
		actionIndex				= getPopUp actionId wstate
		action					= allActions !! actionIndex
	  	// update the key mapping and the representation on the screen
	  	// (unless the maximum number of keys has been reached)
		nrKeys					= length (tableLookup action (tableInvert keyMapping))
	  | nrKeys >= MAX_KEY_BINDINGS
	    = (dialogState, pstate)
	  # dialogState				= { dialogState
	  							  & keyMapping = addBinding keyCode action keyMapping
	  							  }
		(dialogState, pstate)	= updateMappedFrom (dialogState, pstate)
		(dialogState, pstate)	= updateMappedTo   (dialogState, pstate)
	  = ( dialogState, pstate )
	  where
		//addBinding :: KeyCode Action -> (KeyMapping -> KeyMapping)
		addBinding keyCode action keyMapping
		  # keyMapping = tableRemove keyCode keyMapping
		  # keyMapping = tableInsert (keyCode, action) keyMapping
		  = keyMapping

