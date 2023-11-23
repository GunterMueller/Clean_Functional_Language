definition module dialogDevice;

import deltaIOSystem, ioState;

    
DialogFunctions ::    DeviceFunctions s;
Open_dialog :: !DialogMode !(DialogDef s (IOState s)) -> DialogHandle s (IOState s);
Close_dialog :: !(DialogHandle s io) -> Widget;
DoModalDialog	:: !*s !(IOState *s) -> (!*s, !IOState *s);
DialogIO :: !Event !*s !(IOState *s) -> (!Bool, !*s, !IOState *s);
// IsModalDialog !(DialogDef s (IOState s)) -> BOOL;
GetDialogHandleFromId :: !(IOState s) !Id -> (![DialogHandle s (IOState s)], !IOState s);
ReconstructDialogHandle :: !(DialogHandle s (IOState s)) -> DialogHandle s (IOState s);
RemoveDialogHandle :: !Widget !(IOState s) -> IOState s;
ChangeDialogHandle :: !Id !(DialogHandle s (IOState s)) !(IOState s) -> IOState s;
DialogNotOpen :: !(DialogDef s (IOState s)) !(DialogHandles s (IOState s)) -> Bool;
SetDialogItemAbility :: !Widget !SelectState -> Widget;
