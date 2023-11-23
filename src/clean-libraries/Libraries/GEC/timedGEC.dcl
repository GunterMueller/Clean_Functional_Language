definition module timedGEC

import genericgecs

// Timer editor: will cause an automatic update when it is part of any datastructure displayed in a gGEC

derive gGEC Timed

:: Timed = Timed (Int ->Int) Int		// function will be called automatically after given timeout in miliseconds						
										// function will receive the time left and should set the new timeout time
