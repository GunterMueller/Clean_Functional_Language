definition module typeatt

// WindowAttributes for the Types window

from StdWindowDef import :: WindowAttribute
import StdPSt
from EdMonad import :: EditState
from IdeState import :: General

update_type_window :: !Bool !String ![String] !*(PSt *General) -> *PSt *General

typeWinKeyboard :: .WindowAttribute *(EditState,*PSt *General);
typeWinMouse :: .WindowAttribute *(EditState,*PSt *General);
