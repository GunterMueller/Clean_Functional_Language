/*
 * EdEditMenu.dcl: the edit menu
 */

definition module EdEditMenu

from StdPSt		import :: PSt
from EdCommon	import :: MyEditorState

openEditMenu :: (PSt *MyEditorState) -> PSt *MyEditorState

