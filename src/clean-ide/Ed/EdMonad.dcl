definition module EdMonad

// the monad that keeps track of the local EditState and another state (mostly the program state)

from StdPicture		import :: Font, :: FontMetrics, :: Colour
from StdPSt			import :: PSt, :: IOSt
from StdId			import :: Id
from StdPicture		import :: Picture
from StdClipboard	import :: ClipboardItem
from StdOverloaded	import class ==, class toString
from StdMaybe		import :: Maybe

import StateMonad 
from UtilNewlinesFile import :: NewlineConvention

from EdText			import :: Text, :: StrictList, :: TextFragment
from EdSelection	import :: Selection, :: Position, :: ColumnNr, :: LineNr

:: TabSize :== Int

:: NewTabSize :== [TabSize]

:: EditState

:: SelectInfo
	= { selection	:: !Selection
	  , selectMode	:: !SelectMode
	  }
	  
:: SelectMode
	= SelectWords Selection
	| SelectLines LineNr
	| SelectChars

:: FontInfo =
	{ thefont		:: !Font
	, lineHeight	:: !Int
	, metrics		:: !FontMetrics
	, tabSize		:: !TabSize			// logical in #chars
//	, tabWidth		:: !NewTabSize		// physical in #pixels
	, charWidth		:: !Int				// physical in #pixels
	, marginWidth	:: !Int				// logical in #chars
	, autoTab		:: !Bool
	, showTabs		:: !Bool
	, showSyntax	:: !Bool
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

DefaultSyntaxColours :: SyntaxColours

:: UndoInfo =
	{ state		:: !UndoState		// undo or redo
	, action	:: !String			// string describing action to be undone/redone
	, uninfo	:: !ActionInfo
	}

:: UndoState = None | Undo | Redo

instance == UndoState

:: IRState

:: ActionInfo
	= NoInfo
	| CopyInfo ![ClipboardItem] ![ClipboardItem]
	| CutInfo ![ClipboardItem] ![ClipboardItem] !TextFragment !Position !Selection !Bool
	| ClearInfo !TextFragment !Position !Selection !Bool
	| PasteInfo !TextFragment !TextFragment !Selection !Position !Bool
	| InsertInfo !Bool !IRState			// TextFragment should be enoughthere instead of entire edit state...
	| RemoveInfo !Bool !IRState			// TextFragment should be enough here instead of entire edit state...
	| ReplaceAllInfo !TextFragment !Selection !Selection ![(Selection,Selection,TextFragment,TextFragment)] !Bool	// newfrag oldsel newsel updatelist needsave
	| UndoneInfo !IRState !IRState		// TextFragment should be enough here instead of entire edit state...

instance toString ActionInfo
instance toString UndoState

:: EditMonad env a :== StateM *(!EditState, env) a

initEditState :: !Id !Id !String !Font !(Int,Bool,Bool,Bool,Bool) !Int !SyntaxColours !*(PSt .l) -> (EditState , *PSt .l)
appEnv			:: (.env -> .env)									->	EditMonad .env	nothing
accEnv			:: (.env -> (.a, .env))								->	EditMonad .env	.a
noResult		:: !(EditMonad .env a) *(EditState, .env)			->	(EditState, .env)
onlyEnv			:: !(EditMonad .env a) *(EditState, .env)			-> .env

// ACCESSORS & MODIFIERS

getMenuSelection		::										EditMonad .env (Maybe String)
setMenuSelection		:: (Maybe String)					->	EditMonad (PSt .l) nothing
getUndoInfo				::										EditMonad .env			UndoInfo
setUndoInfo				:: UndoInfo							->	EditMonad (PSt .l)	nothing
getLineNumbers			::										EditMonad .env			Bool
setLineNumbers			:: !Bool							->	EditMonad (PSt .l)	nothing
getNewlineConvention	::										EditMonad .env			NewlineConvention
setNewlineConvention	:: NewlineConvention				->	EditMonad (PSt .l)	nothing
getReadOnly				::										EditMonad .env Bool
setReadOnly				:: Bool								->	EditMonad (PSt .l)	nothing
getText					::										EditMonad .env			Text
setText					:: !Text							->	EditMonad (PSt .l)	nothing
getVirtualX				::										EditMonad .env			Int
setVirtualX				:: Int								->	EditMonad (PSt .l)	nothing
getFontInfo				::										EditMonad .env			FontInfo
setFontInfo				:: FontInfo							->	EditMonad (PSt .l)	nothing
appFontInfo				:: (FontInfo -> FontInfo)			->	EditMonad (PSt .l)	nothing
getWindowId				::										EditMonad .env			Id
getCursorVisibility		::										EditMonad .env			Bool
setCursorVisibility		:: Bool								->	EditMonad (PSt .l)	nothing
getSelection			::										EditMonad .env			Selection
setSelection			:: Selection						->	EditMonad (PSt .l)	nothing
getSelectMode			:: 										EditMonad .env			SelectMode
setSelectMode			:: SelectMode						->	EditMonad (PSt .l)	nothing
getPathName				::										EditMonad .env			String
setPathName				:: String							->	EditMonad (PSt .l)	nothing
getNeedSave				::										EditMonad .env			Bool
setNeedSave				:: Bool								->	EditMonad (PSt .l)	nothing
getCursorHeight			::										EditMonad .env			Int
setFont					:: Font								->	EditMonad (PSt .l)	nothing

pathNameToWindowTitle :: !String -> String
pathNameToWindowTitle` :: !String -> String

//-- P4
from StdIOBasic import :: Point2

getTimerId :: EditMonad .env Id
getToolPt :: EditMonad .env Point2
setToolPt :: Point2 -> EditMonad (PSt .l) nothing

//--

getState :: EditMonad (PSt .l) IRState
setState :: IRState -> EditMonad (PSt .l) nothing
