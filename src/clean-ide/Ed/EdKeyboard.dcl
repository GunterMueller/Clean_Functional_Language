definition module EdKeyboard

// handling keyboard events

import	EdCommon, StdMaybe
from	StdIOCommon		import :: KeyboardState
from	StdPSt			import :: PSt
from	EdKeyMapping	import :: KeyMapping

editWindowKeyboard ::
	KeyMapping KeyboardState !(!EditState, !PSt PLocState) -> (!EditState, !PSt PLocState)
// editWindowKeyboard: the keyboard handling function for edit windows

noeditWindowKeyboard ::
	KeyMapping KeyboardState (!EditState, !PSt PLocState) -> (!EditState, !PSt PLocState)
// noeditWindowKeyboard: keyboard handling fun for read-only editor windows
