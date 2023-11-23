definition module gui;

// Linkers
import ProcessSerialNumber;
import DLState;

import deltaDialog;

openClientWindow :: !String !ProcessSerialNumber !*DLServerState !(IOState *DLServerState) -> (!*DLServerState,!(IOState *DLServerState));

removeClientWindow :: !*DLClientState !*DLServerState !(IOState *DLServerState) -> (!*DLServerState,!(IOState *DLServerState));

updateClientWindow :: !*DLServerState !(IOState *DLServerState) -> (!*DLServerState,!(IOState *DLServerState));

HandleRequestResult :: (!Bool,!ProcessSerialNumber,!*DLServerState,(IOState *DLServerState)) -> (!*DLServerState,IOState *DLServerState);

error :: [String] !*a !*(IOState *a) -> *(*a,*(IOState *a));

