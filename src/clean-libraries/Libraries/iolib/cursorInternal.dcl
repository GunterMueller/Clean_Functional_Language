definition module cursorInternal;

import ioState,xtypes,deltaIOSystem;

    
SetWidgetCursor :: !Widget !CursorShape -> Widget; 
SetGlobalCursor :: !CursorShape !(IOState s) -> IOState s;
ResetCursor :: !(IOState s) -> IOState s;

