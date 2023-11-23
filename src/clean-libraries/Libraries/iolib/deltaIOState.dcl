definition module deltaIOState;

//	Global operations on the IOState.
// version 0.8.3

import deltaEventIO, deltaIOSystem;

from StdFile import class FileEnv, :: Files;
instance FileEnv (IOState s);

/*
::	SetGlobalCursor !CursorShape !(IOState s) -> IOState s;
<<	Set the shape of the cursor globally. This shape overrules the local cursor
	shapes of windows. >>

::	ResetCursor !(IOState s) -> IOState s;
<<	Undoes the effect of SetGlobalCursor. >>
*/

ObscureCursor	:: !(IOState s) -> IOState s;
/* Has no effect on X Windows / Open Look systems */

SetDoubleDownDistance	:: !Int !(IOState s) -> IOState s;
/* Has no effect on X Windows / Open Look systems (?) */

from cursorInternal import SetGlobalCursor,ResetCursor;
