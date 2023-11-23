definition module sliderBar;


//	Version 0.8 to 1.0


import	deltaIOSystem;
from	deltaIOState import ::IOState;


/* A general Slider Bar definition, which is a dialog item
	implemented entirely in Concurrent Clean as a Control.
*/


::	SliderDirection	=	Horizontal | Vertical;
::	SliderPos		:==	Int;
::	SliderMax		:==	Int;


/*	A SliderBar is defined by the following attributes:
	- Id, ItemPos and SelectState, like other DialogItems.
	- SliderDirection: Horizontal or Vertical.
	- SliderPos: the initial position of the slider. This position is always
	             adjusted between 0 and SliderMax.
	- SliderMax: the slider can take on positions between 0 and SliderMax.
*/
SliderBar	::	!DialogItemId !ItemPos !SelectState !SliderDirection
				!SliderPos !SliderMax
				!(DialogFunction s (IOState s))
			->	DialogItem s (IOState s);

/*	ChangeSliderBar moves the slider of the indicated bar to the new
	position. The position is always adjusted between 0 and SliderMax.
*/
ChangeSliderBar		::	!DialogItemId !SliderPos
						!(DialogState s (IOState s))
					->	  DialogState s (IOState s);

/*	GetSliderPosition retrieves the current slider position of the slider
	bar with the indicated id from the DialogInfo parameter. When the id is
	not the id of a SliderBar a run-time error is generated.
*/
GetSliderPosition	::	!DialogItemId !DialogInfo -> SliderPos;
