/*
 * EdOptionsMenu.dcl: the options menu
 */

definition module EdOptionsMenu

from StdPSt		import :: PSt
from EdCommon	import :: MyEditorState

openOptionsMenu :: !(PSt *MyEditorState) -> PSt *MyEditorState

