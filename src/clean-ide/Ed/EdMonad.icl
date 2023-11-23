implementation module EdMonad

// the monad that keeps track of the local EditState and another state (mostly the program state)

import StdArray, StdBool, StdChar, StdClass, StdFunc, StdInt, StdMisc
import StdMenuElement, StdPSt, StdWindow, StdSystem
import UtilNewlinesFile, StateMonad
import StdId
import EdVisualText, EdSelection, EdLook
import EdAction
import Platform,PlatformObjectIO
//import dodebug
trace_n` _ s :== s

:: ActionInfo
	= NoInfo
	| CopyInfo ![ClipboardItem] ![ClipboardItem]
	| CutInfo ![ClipboardItem] ![ClipboardItem] !TextFragment !Position !Selection !Bool
	| ClearInfo !TextFragment !Position !Selection !Bool
	| PasteInfo !TextFragment !TextFragment !Selection !Position !Bool
	| InsertInfo !Bool !IRState
	| RemoveInfo !Bool !IRState
	| ReplaceAllInfo !TextFragment !Selection !Selection ![(Selection,Selection,TextFragment,TextFragment)] !Bool
	| UndoneInfo !IRState !IRState

:: UndoInfo =
	{ state		:: !UndoState		// undo or redo
	, action	:: !String			// string describing action to be undone/redone
	, uninfo	:: !ActionInfo
	}

:: TabSize :== Int

:: NewTabSize :== [TabSize]

:: UndoState = None | Undo | Redo

:: EditState
   = { text			:: !Text
	 , pathName		:: !String
	 , windowId		:: !Id
	 , timerId		:: !Id				// P4
	 , toolPt		:: !Point2			// P4
	 , fontInfo		:: !FontInfo	 
	 , cursorInfo	:: !CursorInfo`
	 , selectInfo	:: !SelectInfo
	 , undoInfo		:: !UndoInfo
	 , needSave		:: !Bool
	 , undoeId		:: !Id
	 , lineNumbers	:: !Bool
	 , newlineConv	:: !NewlineConvention
	 , menusel		:: !Maybe String
	 , readOnly		:: !Bool
	 }

:: CursorInfo`	// rename to avoid conflict with Object I/O
   = { position		:: !Position
	 , virtualX		:: !Int
	 , visible		:: !Bool
	 }

:: SelectInfo
	= { selection	:: !Selection
	  , selectMode	:: !SelectMode
	  }
	  
:: SelectMode
	= SelectWords Selection
	| SelectLines LineNr
	| SelectChars

:: FontInfo =
	{ thefont			:: !Font
	, lineHeight		:: !Int
	, metrics			:: !FontMetrics
	, tabSize			:: !TabSize			// logical tabsize
//	, tabWidth			:: !NewTabSize		// physical tabsize
	, charWidth			:: !Int				// physical in #pixels
	, marginWidth		:: !Int				// logical in #chars
	, autoTab			:: !Bool
	, showTabs			:: !Bool
	, showSyntax		:: !Bool
	, syntaxColours		:: !SyntaxColours
	}

:: SyntaxColours =
	{ textColour		:: !Colour
	, backgroundColour	:: !Colour
	, marginColour		:: !Colour
	, tabColour			:: !Colour
	, commentColour		:: !Colour
	, stringColour		:: !Colour
	, charColour		:: !Colour
	, keywordColour		:: !Colour
	, typedefColour		:: !Colour
	, typedeclColour	:: !Colour
	}
	
instance toString ActionInfo
where
	toString NoInfo	= "N"
	toString (CopyInfo oclip nclip) = "C "
	toString (CutInfo oclip nclip frag pos sel ns) = "X "
	toString (PasteInfo ofrag frag sel pos ns)
		= "V "+++stringsToString ofrag+++":::"+++stringsToString frag+++":::"+++toSelString sel+++":::"+++toPosString pos+++"]]]"
	toString _ = "? "

toSelString {start,end}
    = "{ start = " +++ toPosString start +++ ", end = " +++ toPosString end +++ "}"

toPosString {col,row}
    = "{ col = " +++ toString col +++ ", row = " +++ toString row +++ "}"

instance == UndoState
where
	(==) None None = True
	(==) Undo Undo = True
	(==) Redo Redo = True
	(==) _ _ = False

instance toString UndoState
where
	toString None	= "None"
	toString Undo	= "Undo"
	toString Redo	= "Redo"

::IRState=
	{ txt	:: !Text
	, sel	:: !Selection
	, mod	:: !SelectMode
	, vix	:: !Int
	, vis	:: !Bool
	, ns	:: !Bool
	}

emptyUndoInfo :: UndoInfo
emptyUndoInfo = {state = None, action = "", uninfo = NoInfo}

getLineNumbers :: EditMonad .env Bool
getLineNumbers =
	getEditState		>>>= \{lineNumbers} ->
	result lineNumbers

setLineNumbers :: !Bool -> EditMonad (PSt .l) nothing
setLineNumbers linenumbers =
	updateEditState update	>>>
	getEditState			>>>= \{windowId} ->
	computeViewDomain		>>>= \viewDomain=:{corner1=c1=:{x}} ->
	let	maybemove = if linenumbers (moveWindowViewFrame windowId {zero & vx = x}) (id)
	in
	appEnv (appPIO (maybemove o setWindowViewDomain windowId viewDomain))
where
	update editState =
		{ editState & lineNumbers = linenumbers}

:: EditMonad env a
   :== StateM *(!EditState, env) a

/* EXPORTED FUNCTIONS */

initEditState :: !Id !Id !String !Font !(Int,Bool,Bool,Bool,Bool) !Int !SyntaxColours !*(PSt .l) -> (EditState, *PSt .l)
initEditState windowId eUndoId pathName font tabs=:(_,_,_,linenos,showSynCol) margin syncols pstate
  # (tId,pstate) = openId pstate			// P4
  # (fontInfo, pstate) = computeFontInfo font tabs margin syncols pstate
  = (	{ text			= newText
		, pathName		= pathName
		, windowId		= windowId
		, timerId		= tId	// P4
		, toolPt		= zero	// P4
		, fontInfo		= fontInfo
		, selectInfo	= { selection	= emptySelection
						  , selectMode	= SelectChars 
						  }
		, cursorInfo	= { position	= {col=0, row=0}
						  , virtualX	= 0
						  , visible		= True
						  }
		, undoInfo		= emptyUndoInfo
		, needSave		= False
		, undoeId		= eUndoId
		, lineNumbers	= linenos
		, newlineConv	= NewlineConventionNone
		, menusel		= Nothing
		, readOnly		= False
		}
	, pstate
	)
		     	  
getEditState :: EditMonad .env EditState
getEditState
  = getEditState`
  where
    getEditState` (editState, env)
      = (editState, (editState, env))

appEnv :: (.env -> .env) -> EditMonad .env nothing
appEnv envFun
  = appEnv`
  where
	appEnv` (editState, env)
	  # env = envFun env
	  = (nothing, (editState, env))

accEnv :: (.env -> (.a, .env)) -> EditMonad .env .a
accEnv envFun
  = accEnv`
  where
	accEnv` (editState, env)
	  # (a, env) = envFun env
	  = (a, (editState, env))

noResult :: !(EditMonad .env a) *(EditState, .env) 
				-> (EditState, .env)
noResult ma state
  # (_, state) = ma state
  = state

onlyEnv :: !(EditMonad .env a) *(EditState, .env) -> .env
onlyEnv ma state
  # (_, (_, env)) = ma state
  = env

// SELECTORS & MODIFIERS

getMenuSelection :: EditMonad .env (Maybe String)
getMenuSelection =
	getEditState	>>>= \{menusel} ->
	result menusel

setMenuSelection :: (Maybe String) -> EditMonad (PSt .l) nothing
setMenuSelection menusel =
	updateEditState update
where
	update editState = {editState & menusel = menusel}

getNewlineConvention :: EditMonad .env NewlineConvention
getNewlineConvention =
	getEditState	>>>= \{newlineConv} ->
	result newlineConv

setNewlineConvention :: NewlineConvention -> EditMonad (PSt .l) nothing
setNewlineConvention newlineConv =
	updateEditState update
where
	update editState = {editState & newlineConv = newlineConv}

getReadOnly :: EditMonad .env Bool
getReadOnly =
	getEditState	>>>= \{readOnly} ->
	result readOnly

setReadOnly :: Bool -> EditMonad (PSt .l) nothing
setReadOnly readOnly =
	updateEditState update
where
	update editState = {editState & readOnly = readOnly}

getText :: EditMonad .env Text
getText
  = getEditState	>>>= \{text} ->
	result text

setText :: !Text -> EditMonad (PSt .l) nothing
setText text =
	updateEditState update	>>>
	updateLook
where
    update editState
      = {editState & text = text}

getFontInfo :: EditMonad .env FontInfo
getFontInfo
  = getEditState	>>>= \{fontInfo} ->
	result fontInfo
	
setFontInfo	:: FontInfo -> EditMonad (PSt .l) nothing
setFontInfo fontInfo =
	updateEditState update
where
    update editState
      = {editState & fontInfo=fontInfo}

appFontInfo :: (FontInfo -> FontInfo) -> EditMonad (PSt .l) nothing
appFontInfo fontFun =
	updateEditState update	>>>
	updateLook
where
	update editState = {editState & fontInfo = fontFun editState.fontInfo}

getCursorVisibility :: EditMonad .env Bool
getCursorVisibility
  = getEditState	>>>= \{cursorInfo} ->
	result cursorInfo.visible
	
setCursorVisibility :: Bool -> EditMonad (PSt .l) nothing
setCursorVisibility visible =
	updateEditState update	>>>
	updateLook
where
    update editState=:{cursorInfo}
      = {editState & cursorInfo={cursorInfo & visible=visible}}

getSelection :: EditMonad .env Selection
getSelection
  = getEditState	>>>= \{selectInfo={selection}} ->
	result selection
	
setSelection :: Selection -> EditMonad (PSt .l) nothing
setSelection selection =
	updateEditState update	>>>
	updateLook
where
    update editState=:{selectInfo}
      = {editState & selectInfo={selectInfo & selection=selection}}
      
getVirtualX	:: EditMonad .env Int
getVirtualX 
  = getEditState	>>>= \{cursorInfo={virtualX}} ->
	result virtualX
	
setVirtualX :: Int -> EditMonad (PSt .l) nothing
setVirtualX virtualX
  = updateEditState update
where
    update editState=:{cursorInfo}
      = {editState & cursorInfo={cursorInfo & virtualX=virtualX}}
      
getSelectMode :: EditMonad .env SelectMode
getSelectMode
  = getEditState	>>>= \{selectInfo={selectMode}} ->
	result selectMode
	
setSelectMode :: SelectMode	-> EditMonad (PSt .l) nothing
setSelectMode selectMode
  = updateEditState update
where
    update editState=:{selectInfo}
      = {editState & selectInfo={selectInfo & selectMode=selectMode}}

getCursorHeight :: EditMonad .env Int
getCursorHeight
  = getEditState	>>>= \{fontInfo={lineHeight}} ->
	result lineHeight

getWindowId :: EditMonad .env Id
getWindowId
  = getEditState	>>>= \{windowId} ->
	result windowId

setFont :: Font -> EditMonad (PSt .l) nothing
setFont font = monad
where
	monad (editState,pState)
		# ({tabSize,autoTab,showTabs,showSyntax,marginWidth,syntaxColours},(editState,pState))
			= getFontInfo (editState,pState)
		# (linenos,(editState,pState))
			= getLineNumbers (editState,pState)
    	# tabs
    		= (tabSize,autoTab,showTabs,linenos,showSyntax)
		# (fontInfo,(editState,pState))
			= accEnv (computeFontInfo font tabs marginWidth syntaxColours) (editState,pState)
		# (_,(editState,pState))
			= updateEditState (update fontInfo)	(editState,pState)
		# (_,(editState,pState))
			= updateLook (editState,pState)
		# (_,(editState,pState))
			= vResetViewDomain (editState,pState)
		= (undef,(editState,pState))
	where
	    update fontInfo editState
	      = { editState & fontInfo = fontInfo }

updateEditState :: (EditState -> EditState) -> EditMonad (PSt .l) nothing
updateEditState editStateFun
  = updateEditState`
where 
	updateEditState` (editState, pstate)
	  #! editState = editStateFun editState
	  = (nothing, (editState, pstate))
	  
// updateLook updates the look function of the window. This
// look function is not applied, so no visible update is
// caused by updateLook.

updateLook :: EditMonad (PSt .l) nothing
updateLook 
  = getWindowId		>>>= \windowId ->
	getEditState	>>>= \editState ->
	appEnv (appPIO (setWindowLook windowId False (True,editWindowLook editState)))

// compute some properties of a font

computeFontInfo :: !Font !(Int,Bool,Bool,Bool,Bool) !Int !SyntaxColours !(PSt .l) -> (FontInfo, PSt .l)
computeFontInfo font (tabSize,autoTab,showTabs,_,showSynCol) marginWidth syncols pstate
  # (metrics, pstate)	= accPIO (accScreenPicture (getFontMetrics font)) pstate
	lineHeight			= metrics.fAscent + metrics.fDescent + metrics.fLeading
	(charWidth,pstate) = accPIO (accScreenPicture (getFontStringWidth font "M")) pstate
  = ( { thefont				= font
	  , lineHeight			= lineHeight
	  , metrics				= metrics
	  , tabSize				= tabSize
	  , autoTab				= autoTab
	  , charWidth			= charWidth
	  , marginWidth			= marginWidth
	  , showTabs			= showTabs
	  , showSyntax			= showSynCol
	  , syntaxColours		= syncols
	  }
	, pstate
	) 

DefaultSyntaxColours :: SyntaxColours
DefaultSyntaxColours =
	{ textColour		= Black
	, tabColour			= Red
	, backgroundColour	= White
	, marginColour		= White
	, commentColour		= Blue
	, stringColour		= Green
	, charColour		= Magenta
	, keywordColour		= Grey
	, typedefColour		= Black
	, typedeclColour	= Black
	}

//--

getPathName :: EditMonad .env String
getPathName =
	getEditState		>>>= \{pathName} ->
	result pathName

setPathName :: String -> EditMonad (PSt .l) nothing
setPathName path =
	updateEditState update
where
	update editState	= {editState & pathName = path}

getNeedSave :: EditMonad .env Bool
getNeedSave =
	getEditState		>>>= \{needSave} ->
	result needSave

pathNameToWindowTitle :: !String -> String
pathNameToWindowTitle pathName
	= RemovePath pathName+++" - "+++pathName
where
	RemovePath	:: !String -> String;
	RemovePath path
		| found	= path % (inc position, last);
				= path;
		where 
			(found,position)= FindLastChar dirseparator path last;
			last			= dec (size path);
	
	FindLastChar :: !Char !String !Int -> (!Bool, !Int);
	FindLastChar c s i
		| i <= 0			= (False,0);
		| c ==  s.[i]		= (True, i);
							= FindLastChar c s (dec i);

pathNameToWindowTitle` :: !String -> String
pathNameToWindowTitle` pathName
	= "["+++RemovePath pathName+++"] - "+++pathName
where
	RemovePath	:: !String -> String;
	RemovePath path
		| found	= path % (inc position, last);
				= path;
		where 
			(found,position)= FindLastChar dirseparator path last;
			last			= dec (size path);
	
	FindLastChar :: !Char !String !Int -> (!Bool, !Int);
	FindLastChar c s i
		| i <= 0			= (False,0);
		| c ==  s.[i]		= (True, i);
							= FindLastChar c s (dec i);

setNeedSave :: Bool -> EditMonad (PSt .l) nothing
setNeedSave need =
	getReadOnly												>>>= \readOnly ->
	getEditState											>>>= \{windowId,pathName} ->
	accEnv (accPIO (getWindowTitle windowId))				>>>= \oldTitle ->
	let
		windowName	= (if readOnly pathNameToWindowTitle` pathNameToWindowTitle) pathName
		windowTitle	= PlatformDependant
						/*Win*/	(if need ("*"+++windowName) windowName)
						/*Mac*/ windowName
	in

	IF (needsetwin oldTitle windowTitle)
	THEN
	(
		appEnv (appPIO (setWindowTitle windowId windowTitle))
	)
	ELSE
	(
		skip
	)	>>>

	accEnv (accPIO (getWindowModified windowId))			>>>= \wasModified ->
	IF (isJust wasModified && fromJust wasModified <> need)

	THEN
	(
	appEnv (appPIO (setWindowModified windowId windowName need))		>>>
	updateEditState update
	)
	ELSE
	(
	updateEditState update
	)														>>>
	IF needfixundo
	THEN
		(
		updateEditState undoupdate
		)
	ELSE
		skip
where
	update editState	= {editState & needSave = need}
	needsetwin Nothing _ = True
	needsetwin (Just oldtitle) newtitle = oldtitle <> newtitle
	needfixundo = not need
	undoupdate editState=:{undoInfo} = {editState & undoInfo = fix undoInfo}
	fix ui=:{uninfo,state}
		# info = case uninfo of		// fix to correct undo'd need save state after save
			(NoInfo)				-> NoInfo
			(CopyInfo x y)			-> CopyInfo x y
			(CutInfo a b c d e ns)	-> CutInfo a b c d e True
			(ClearInfo a b c ns)	-> ClearInfo a b c True
			(PasteInfo a b c d ns)	-> PasteInfo a b c d True
			(InsertInfo a ir)		-> InsertInfo a {ir & ns = True}
			(RemoveInfo a ir)		-> RemoveInfo a {ir & ns = True}
			(ReplaceAllInfo nfrag osel nsel ul ns) -> (ReplaceAllInfo nfrag osel nsel ul True)
			(UndoneInfo or nr)		-> UndoneInfo {or & ns = (state==Undo)} {nr & ns = (state==Redo)}
		= {ui & uninfo = info}

getUndoInfo :: EditMonad .env UndoInfo
getUndoInfo
	=	getEditState		>>>= \{undoInfo} ->
		result undoInfo

setUndoInfo :: UndoInfo -> EditMonad (PSt .l) nothing
setUndoInfo undoInfo
	=	getEditState				>>>= \{undoeId} ->
		appEnv (appPIO (mfun undoeId))	>>>
		updateEditState update
where
    update editState
      = {editState & undoInfo = undoInfo}
	mfun r		= case undoInfo.state of
					None	-> disableMenuElements [r] o setMenuElementTitles [(r,"Undo")]
					Undo	-> enableMenuElements [r] o setMenuElementTitles [(r,"Undo"+++undoInfo.action)]
					Redo	-> enableMenuElements [r] o setMenuElementTitles [(r,"Redo"+++undoInfo.action)]

//-- P4

getTimerId :: EditMonad .env Id
getTimerId
  = getEditState	>>>= \{timerId} ->
	result timerId

getToolPt :: EditMonad .env Point2
getToolPt
  = getEditState	>>>= \{toolPt} ->
	result toolPt

setToolPt :: Point2 -> EditMonad (PSt .l) nothing
setToolPt toolPt =
	updateEditState update
where
	update editState	= {editState & toolPt = toolPt}

//--

getState :: EditMonad (PSt .l) IRState
getState =
	getEditState	>>>= \{text,selectInfo={selection,selectMode},cursorInfo={virtualX,visible},needSave} ->
	result {txt=text,sel=selection,mod=selectMode,vix=virtualX,vis=visible,ns=needSave}

setState :: IRState -> EditMonad (PSt .l) nothing
setState state =
	updateEditState update		>>>
	updateLook					>>>
	setNeedSave     state.ns
where
	update editState=:{selectInfo,cursorInfo}
	  =	{ editState
		& text			= text
		, selectInfo	= {selectInfo & selection=selection, selectMode=selectMode}
		, cursorInfo	= {cursorInfo & virtualX = virtualX, visible = visible}
		}
	text		= state.txt
	selection	= state.sel
	selectMode	= state.mod
	virtualX	= state.vix
	visible		= state.vis

