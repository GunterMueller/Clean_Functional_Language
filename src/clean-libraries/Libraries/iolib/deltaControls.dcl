definition module deltaControls;

//	Version 0.8.3b

import deltaIOSystem;
from ioState import :: IOState;

/* General Scrolling List  and Slider Bar definition.
	These pre-defined dialog items are implemented entirely
	in Concurrent Clean as a user-defined Control.
*/

    
::	NrVisible  :== Int;

    

/*	A ScrollingList is defined by the following attributes:
	- Id, ItemPos and SelectState (like other dialog items).
	- The minimum width of the scrolling list (Measure).
	  This attribute is important only when ChangeScrollingList is used to
	  change the items of the scrolling list. Because the width of the s. l.
	  is fixed a minimum width must be chosen then that also fits the new
	  items defined by ChangeScrollingList. When ChangeScrollingList is never
	  used a zero minimum width can be used.
	- The number of items that is visible in the list (NrVisible).
	- The item that is initially selected (ItemTitle).
	- The list of items ([ItemTitle]).
	- A DialogFunction that is called whenever a new item is selected.
	The function ScrollingList returns a DialogItem (a Control) that can
	be used in any dialog definition.
*/
ScrollingList	:: !DialogItemId !ItemPos !Measure !SelectState !NrVisible
	              !ItemTitle ![ItemTitle] !(DialogFunction s (IOState s))
		-> DialogItem s (IOState s);

/*	With ChangeScrollingList the items in the scrolling list can be changed.
	Its arguments are the id of the scrolling list, the new selected item and
	the new list of items. When the id is not the id of a ScrollingList a
	run-time error is generated.
*/
ChangeScrollingList	:: !DialogItemId !ItemTitle ![ItemTitle]
         !(DialogState s (IOState s)) -> DialogState s (IOState s);

/*	GetDefScrollingListItem retrieves the currently selected item in the
	scrolling list with the indicated id from the DialogInfo parameter
	When the id is not the id of a ScrollingList a run-time error occurs.
*/
GetScrollingListItem	:: !DialogItemId !DialogInfo -> ItemTitle;


    
::	SliderDirection	=  Horizontal | Vertical;
::	SliderPos			:== Int;
::	SliderMax			:== Int;

    

/*	A SliderBar is defined by the following attributes:
	- Id, ItemPos and SelectState, like other DialogItems.
	- SliderDirection: Horizontal or Vertical.
	- SliderPos: the initial position of the slider. This position is always
	             adjusted between 0 and SliderMax.
	- SliderMax: the slider can take on positions between 0 and SliderMax.
*/
SliderBar	:: !DialogItemId !ItemPos !SelectState !SliderDirection
	          !SliderPos !SliderMax !(DialogFunction s (IOState s))
		-> DialogItem s (IOState s);

/*	ChangeSliderBar moves the slider of the indicated bar to the new position.
	The position is always adjusted between 0 and SliderMax.
*/
ChangeSliderBar	:: !DialogItemId !SliderPos
	                !(DialogState s (IOState s)) -> DialogState s (IOState s);

/*	GetSliderPosition retrieves the current slider position of the slider bar
   with the indicated id from the DialogInfo parameter. When the id is not the
	id of a SLiderBar a run-time error is generated.
*/
GetSliderPosition	:: !DialogItemId !DialogInfo -> SliderPos;
