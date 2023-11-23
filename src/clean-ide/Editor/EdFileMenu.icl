/*
 * EdFileMenu.icl: the file menu
 */

implementation module EdFileMenu

import StdMisc, StdTuple, StdList, StdFunc
import StdMenu, StdPSt, StdPStClass, StdId, StdProcess, StdSystem
import StdFileSelect, StdWindow
import EdCommon, EdClient, EdFile, EdWindow
import EdMouse, EdKeyboard
import FontEnv
import ioutil

openFileMenu :: Id (PSt *MyEditorState) -> PSt *MyEditorState
openFileMenu undoId pstate
  = snd (openMenu Void fileMenu pstate)
where  
	fileMenu = Menu "File" fileMenuItems []
	  where
		fileMenuItems 
		  =		MenuItem "Open"			[ MenuShortKey 'O', MenuFunction (noLS (fileOpen undoId)) ]
		  :+:	MenuItem "Save"			[ MenuShortKey 'S', MenuFunction (noLS fileSave) ]
		  :+:	MenuItem "Close window" [ MenuShortKey 'W', MenuFunction (noLS fileClose) ]
		  :+:	MenuSeparator			[]
		  :+:	MenuItem "Quit"			[ MenuShortKey 'Q', MenuFunction (noLS fileQuit) ]
	
fileOpen undoId pstate

  // ask user for a file to open
  
  # (maybeString, pstate) = selectInputFile pstate
  | isNothing maybeString
	= pstate
  # pathName			= fromJust maybeString
  
  // read the file from disk
  
	((errorText,newlineConv,readOnly), pstate)	= readText pathName pstate
  | isError errorText
	= abort "error while reading file"
  # text				= fromOk errorText
  
  // open a font and then the edit window
  
  # ((_, font), pstate)	= openFontFE NonProportionalFontDef pstate
	title				= pathNameToWindowTitle pathName
  # (windowId, pstate)	= accPIO openId pstate 
  # tabs = (4,True,True,True,True)
  # (es,pstate) = getEditorState pstate
  # keyMapping = getKeyMapping es
  # pstate				= openEditWindow undoId title pathName text font tabs 0 DefaultSyntaxColours windowId [WindowKeyboard (const True) Able (editWindowKeyboard keyMapping), WindowMouse noMouseMoved Able editWindowMouse] pstate
  
  = pstate


// File --> Save

//fileSave :: (PSt EditorState) -> PSt EditorState
fileSave pstate
//  # (estate,pstate) = accPLoc (\l->(l,l)) pstate
  = snd (sendToActiveWindow msgSave pstate)//estate pstate)
  
// File --> Close

fileClose pstate
  # (maybeId, pstate)	= accPIO getActiveWindow pstate
  | isNothing maybeId 
	= pstate
  # id					= fromJust maybeId
	pstate				= closeEditWindow id pstate 
  = pstate

// File --> Quit
  
fileQuit pstate
  = closeProcess pstate

