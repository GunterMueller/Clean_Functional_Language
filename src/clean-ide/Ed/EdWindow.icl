implementation module EdWindow

// opening and closing editor windows

import StdInt, StdClass, StdList
import StdWindow, StdControlReceiver, StdIOBasic
import EdMessage, EdMonad, EdLook, EdVisualText, EdState
import ioutil
from StdProcess import getProcessWindowSize
//---

determine_default_window_size :: !Int !*(IOSt *a) -> (!Size,!*(IOSt *a)) 
determine_default_window_size lineHeight io
	# ({w=process_window_width,h=process_window_height},io) = getProcessWindowSize io
	  default_window_width = process_window_width-40
	  default_window_width = if (default_window_width>800) 800
							(if (default_window_width<100) 100 default_window_width)
	  process_window_lines = (process_window_height-60) / lineHeight
	  default_window_lines = if (process_window_lines>40) 40
							(if (process_window_lines<5) 5 process_window_lines)
	= ({w=default_window_width,h=default_window_lines*lineHeight},io)

openEditWindow :: Id .Title String Text !Font (Int,Bool,Bool,Bool,Bool) Int SyntaxColours Id [.WindowAttribute *(EditState,*PSt *b)] !*(PSt *b) -> *PSt *b | Editor b
openEditWindow uId title pathName text font tabs margin syncols windowId atts ps
  # (editorState,ps)				= getEditorState ps
  // generate a receiver identifier and store it in the editor state
  # (editId, ps)					= openEditId ps
	editorState						= addReceiver windowId editId editorState
  // create the local state of the editor window
  # (editState, ps)					= initEditState windowId uId pathName font tabs margin syncols ps
	(_, (editState, ps))			= setText text (editState, ps)
	(fontInfo, (editState, ps))		= getFontInfo (editState, ps) 
  // compute the view domain of the visual text
	(viewDomain, (editState, ps))	= computeViewDomain (editState, ps)
  // setup the window attributes 
	editLook						= editWindowLook editState
	(default_window_size,io) = determine_default_window_size fontInfo.FontInfo.lineHeight ps.io
	ps = {ps & io=io}
	windowAttrs						= atts ++		// in this order so that new attributes override default atts
										  	[
										  	  WindowViewSize   default_window_size
											, WindowHMargin	   0 0
											, WindowVMargin	   0 0
											, WindowId		   windowId
											, WindowViewDomain viewDomain
											, WindowLook	   True editLook
											, WindowHScroll	   (altScrollFunction Horizontal fontInfo.metrics.fMaxWidth)
											, WindowVScroll	   (alignScrollFunction Vertical fontInfo.FontInfo.lineHeight)
											, WindowPos		   (Fix, OffsetVector {vx=10, vy=10})
											, WindowCursor	   IBeamCursor
											]
	// create the receiver that will be part of the
	// editor window. The receiver can be used to change features
	// of the editor from the outside (features like font, text)
  # receiver	 					= openEditReceiver editId
	// create and open the window
  # window		 					= Window title receiver windowAttrs
  # (_,ps)	 						= openWindow editState window ps
  # ps		 						= setEditorState editorState ps
  = ps
  
closeEditWindow :: !Id !*(PSt *b) -> *PSt *b | Editor b;
closeEditWindow windowId pState
  # (editorState,pState) 		= getEditorState pState
  # (maybeEditId, editorState)	= findReceiver windowId editorState
  | isNothing maybeEditId
  	= setEditorState editorState pState
  #	editorState					= removeReceiver windowId editorState
	pState						= closeWindow windowId pState
  = setEditorState editorState pState
