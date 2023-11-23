/*
 * EdEditMenu.icl: the edit menu
 */

implementation module EdEditMenu

import StdTuple, StdFunc
import StdMenu, StdPSt
import EdClient, EdCommon

openEditMenu :: (PSt *MyEditorState) -> PSt *MyEditorState
openEditMenu pstate
  = snd (openMenu Void editMenu pstate)
  
editMenu = Menu "Edit" editMenuItems []
  where
	editMenuItems
	  =		MenuItem "Cut"				[ MenuShortKey 'X', MenuFunction (noLS editCut) ]
	  :+:	MenuItem "Copy"				[ MenuShortKey 'C', MenuFunction (noLS editCopy) ]
	  :+:	MenuItem "Paste"			[ MenuShortKey 'V', MenuFunction (noLS editPaste) ]
	  :+:	MenuItem "Clear"			[					MenuFunction (noLS editClear) ]

editPaste pstate
	= snd (sendToActiveWindow msgPaste pstate)
editCopy  pstate
	= snd (sendToActiveWindow msgCopy pstate)
editCut   pstate
	= snd (sendToActiveWindow msgCut pstate)
editClear pstate
	= snd (sendToActiveWindow msgClear pstate)

