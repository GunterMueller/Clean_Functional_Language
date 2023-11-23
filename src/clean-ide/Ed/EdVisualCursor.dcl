definition module EdVisualCursor

// visual operations on the cursor and selections

from	StdIOCommon import :: ViewFrame, :: Rectangle, :: Point2
import	EdMonad, EdMovement


vUpdateCursor	:: !Bool !Position !Int !FontInfo !Text !ViewFrame ![Rectangle]
												->	(*Picture -> *Picture)
// vUpdateCursor:	updates the cursor

vShowCursor		::									EditMonad (PSt .l) nothing
vHideCursor		::									EditMonad (PSt .l) nothing
// exported only for use by mouse functions to hide cursor during mouse edits

vCenterCursor	::									EditMonad (PSt .l) nothing
// vCenterCursor:	checks to see whether the cursor is within the view frame.
//					If it is not, the cursor is centered in the directions in which
//					it is necessary to make the cursor visible.

vScrollToCursor	::									EditMonad (PSt .l) nothing
// vScrollToCursor:	scrolls the view frame up to the point that the cursor 
//					becomes visible.

vDragCursor		::	!Point2						->	EditMonad (PSt .l) nothing
// vDragToCursor:	scrolls the view frame up to the point that the cursor 
//					becomes visible with space to spare.

vMoveCursor		:: !Movement					->	EditMonad (PSt .l) nothing

vDoCursorSafe	:: (EditMonad (PSt .l) a)		->	EditMonad (PSt .l) a

vChangeSelectionTo	:: Selection				->	EditMonad (PSt .l) nothing
// vChangeSelectionTo:	changes the selection from the current selection
//						to the given selection and redraws, so that the display
//						reflects this change

vUpdateSelection :: !Selection FontInfo Text ViewFrame [Rectangle]
												->	(*Picture -> *Picture)
// vUpdateSelection:	updates the selection in the frame 
//						within the given update area

vRemoveSelection	::								EditMonad (PSt .l) nothing
