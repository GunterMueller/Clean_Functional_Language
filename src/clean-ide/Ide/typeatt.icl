implementation module typeatt

import StdWindow
import IdeState
import EdKeyboard, EdMouse
//--

update_type_window :: !Bool !String ![String] !*(PSt *General) -> *PSt *General
update_type_window interact name message ps
	# atts = [typeWinKeyboard,typeWinMouse]
	= updateTypeWindow interact name atts message ps	// fun to update type info in type window, text :: !Text

typeWinKeyboard :: .WindowAttribute *(EditState,*PSt *General);
typeWinKeyboard = WindowKeyboard	(\_ -> True) Able typeKeyboard

typeWinMouse :: .WindowAttribute *(EditState,*PSt *General);
typeWinMouse = WindowMouse noMouseMoved Able editWindowMouse

//typeWinMouse = WindowMouse noMouseMoved Able (editWindowMouse newTree) // P4
//import searchtree	// P4

typeKeyboard :: .KeyboardState *(EditState,*PSt *General) -> *(EditState,*PSt *General);
typeKeyboard ks (es,ps)
	# (ed,ps)				= getEditorState ps
	# keyMapping			= getKeyMapping ed
	= noeditWindowKeyboard keyMapping ks (es,ps)

