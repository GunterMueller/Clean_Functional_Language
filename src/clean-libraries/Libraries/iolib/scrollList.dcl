definition module scrollList;


//	Version 0.8 to 1.0


import	deltaIOSystem;
from	deltaIOState import :: IOState;


/*	A general Scrolling List definition, which is a dialog item
	implemented entirely in Concurrent Clean as a Control.
*/


::	NrVisible  :== Int;


/*	A ScrollingList is defined by the following attributes:
	- Id, ItemPos and SelectState (like other dialog items).
	- The minimum width of the scrolling list (Measure).
	  This attribute is important only when ChangeScrollingList is used to
	  change the items of the scrolling list. Because the width of dialog
	  elements is always fixed a suited minimum width must be chosen in
	  which new items defined by ChangeScrollingList will also fit.
	  When ChangeScrollingList is never applied a zero minimum width is safe.
	- The number of items that is visible in the list (NrVisible).
	- The item that is initially selected (ItemTitle).
	- The list of items ([ItemTitle]).
	- A DialogFunction that is called whenever a new item is selected.
	The function ScrollingList returns a DialogItem (a Control) that can
	be used in any dialog definition.
*/
ScrollingList	::	!DialogItemId !ItemPos !Measure !SelectState !NrVisible
					!ItemTitle ![ItemTitle]
					!(DialogFunction s (IOState s))
				->	DialogItem s (IOState s);

/*	With ChangeScrollingList the items in the scrolling list can be changed.
	Its arguments are:
	-	the id of the scrolling list,
	-	the new selected item,
	-	and the new list of items.
	When the id is not the id of a ScrollingList a run-time error is
	generated.
*/
ChangeScrollingList	::	!DialogItemId !ItemTitle ![ItemTitle]
						!(DialogState s (IOState s))
					->	  DialogState s (IOState s);

/*	GetScrollingListItem retrieves the currently selected item in the
	scrolling list with the indicated id from the DialogInfo parameter
	When the id is not the id of a ScrollingList a run-time error occurs.
*/
GetScrollingListItem::	!DialogItemId !DialogInfo -> ItemTitle;
