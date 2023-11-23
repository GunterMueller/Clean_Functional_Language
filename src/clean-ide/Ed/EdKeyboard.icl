implementation module EdKeyboard

// handling keyboard events

import StdClass, StdBool, StdArray, StdInt, StdChar, StdTuple, StdList, StdMisc
import StdIOCommon, StdWindow, StdPSt
import EdVisualText, EdVisualCursor, EdSelection, EdAction, EdKeyMapping, EdState
import StrictList
import EdActionType

//from dodebug import trace_n`
trace_n _ f :== f

backspaceKey	:== '\b'
//returnKey		:== '\n'
tabKey			:== '\t'

/* editWindowKeyboard wraps the monadic keyboard function, so that the type
 * conforms to that of a call-back function in the Object I/O library.
 */
editWindowKeyboard ::	KeyMapping
	KeyboardState
	!(!EditState, !PSt PLocState)
	->
	(!EditState, !PSt PLocState)
editWindowKeyboard keyMapping keyboardState state
  # state = noResult 
			  (	getFontInfo						>>>= \{autoTab} ->
			    keyboard autoTab keyboardState
			  )
					  state
  = state
where
	/* The keyboard function ignores 'key up'-events. In the case of 'key down' events,
	 * the cursor is temporarily disabled and the event is passed to keyDown.
	 */
	 
	//keyboard :: KeyboardState -> EditMonad (PSt .l .p) nothing
	keyboard _ (SpecialKey _ KeyUp _)	= skip
	keyboard _ (CharKey _ KeyUp)		= skip
	keyboard _ KeyLost					= skip
	keyboard autoTab keyboardState		= keyDown keyboardState
	
	where
		keyDown :: KeyboardState -> EditMonad (PSt PLocState) nothing
		
		keyDown keyboardState=:(SpecialKey key _ _)								// special keys
		  | key == enterKey || key == returnKey
		  	= (enterKeyAction autoTab)
		  = let maybeAction	= findAction keyboardState keyMapping in
			onlyIf (not (isNothing maybeAction)) 
			  ( performAction (fromJust maybeAction) )
		
		keyDown (CharKey char _)												// character keys
//		  | char == returnKey
//			= (enterKeyAction autoTab)
		  | (asciiCode >= 32 || asciiCode == toInt tabKey) && asciiCode <> 127
			= performAction (Insert (SCons (toString char) SNil))
		  | otherwise
		    = skip
		  where
		    asciiCode = toInt char
		   
		keyDown KeyLost = skip
	
noeditWindowKeyboard ::
	KeyMapping KeyboardState (!EditState, !PSt PLocState)
	-> (!EditState, !PSt PLocState)
noeditWindowKeyboard keyMapping keyboardState state
  # state = noResult 
			  (	getFontInfo						>>>= \{autoTab} ->
			    keyboard autoTab keyboardState	
			  )
					  state
  = state
where
	/* The keyboard function ignores 'key up'-events. In the case of 'key down' events,
	 * the cursor is temporarily disabled and the event is passed to keyDown.
	 */
	 
	//keyboard :: KeyboardState -> EditMonad (PSt .l .p) nothing
	keyboard _ (SpecialKey _ KeyUp _)	= skip
	keyboard _ (CharKey _ _)			= skip
	keyboard _ (KeyLost)				= skip
	keyboard autoTab keyboardState		= keyDown keyboardState
	
	where
		//keyDown :: KeyboardState -> EditMonad (PSt .l .p) nothing
		
		keyDown keyboardState=:(SpecialKey key _ _)								// special keys
		  | key == enterKey = skip
		  = let maybeAction	= findAction keyboardState keyMapping in
			onlyIf (isSafe maybeAction) 
			  ( performAction (fromJust maybeAction) )
		keyDown _ = skip
		
		isSafe Nothing = False
		isSafe (Just (Insert _)) = False
		isSafe (Just (Remove _)) = False
		isSafe _ = True
//--

enterKeyAction autoTab
	:== case autoTab of
			True	-> autoinAction
			_		-> performAction (Insert (SCons "" (SCons "" SNil)))	// ["",""]
where
	autoinAction =
		getText					>>>= \text ->
		getSelection			>>>= \{start} ->
		// if first line start in col 0...
		let
			(line,_) = getLine start.row text
			front = stripfront (line%(0,dec start.col))
		in
		performAction (Insert (SCons "" (SCons front SNil)))

	stripfront :: String -> String
	stripfront s
		= f 0
	where
		m = size s
		f i
			| i >= m
			= s
			# c = s.[i]
			| c == '\t' || c == ' '
				= f (inc i)
			= s % (0,dec i)
