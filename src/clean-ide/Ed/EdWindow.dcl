definition module EdWindow

// opening and closing editor windows

from StdWindow		import :: Title, :: WindowAttribute
from StdPSt			import :: PSt
from StdId			import :: Id
from StdPicture		import :: Font
from EdText			import :: Text
from EdState		import class Editor
import EdMonad, StdIOBasic, StdMaybe


// openEditWindow: create a new edit window with the given properties
openEditWindow ::
	Id											// undo menu item id
	.Title										// window title
	String										// file path
	Text										// initial text
	!Font										// initial font
	(Int,Bool,Bool,Bool,Bool)					// tabs
	Int											// right margin (0 means no margin)
	SyntaxColours								// syntax colours
	Id											// window id
	[.WindowAttribute *(EditState,*PSt *b)]		// initial attributes
	!*(PSt *b) -> *PSt *b | Editor b;

closeEditWindow ::
	!Id											// window id
	!*(PSt *b) -> *PSt *b | Editor b;

