definition module EdLook

// the edit window update function

from	StdPicture		import :: Picture
from	StdIOCommon		import :: SelectState, :: UpdateState
import	EdMonad

editWindowLook	:: EditState SelectState !UpdateState -> (*Picture -> *Picture)
// editWindowLook: defines the look of the editor window. This function
//				   is used to handle update events.

