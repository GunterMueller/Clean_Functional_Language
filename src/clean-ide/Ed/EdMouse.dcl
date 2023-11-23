definition module EdMouse

// handling mouse events

from	StdIOCommon		import :: MouseState
from	StdPSt			import :: PSt
import	EdMonad, EdCommon

editWindowMouse :: MouseState (!EditState, !PSt PLocState) -> (EditState, PSt PLocState)
// editWindowMouse: handles mouse events in the edit window

noMouseMoved :: !MouseState -> Bool
