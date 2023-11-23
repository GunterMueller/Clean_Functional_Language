/*
 * EdFileMenu.dcl: the file menu
 */

definition module EdFileMenu

from StdId		import :: Id
from StdPSt		import :: PSt
from EdCommon	import :: MyEditorState

openFileMenu :: Id (PSt *MyEditorState) -> PSt *MyEditorState

