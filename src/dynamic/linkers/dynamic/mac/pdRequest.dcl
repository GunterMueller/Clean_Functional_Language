definition module pdRequest;

import StdString;

import DLState;


// AddClient
ExtractProjectPathName :: !String -> !String;
GetShortPathName2 :: !String -> !(!Bool,!String);
StartClientApplication :: !*DLClientState !*DLServerState !*(IOState !*DLServerState) -> *(!.Bool,!ProcessSerialNumber,{#Char},!*DLClientState,!*DLServerState,!*(IOState !*DLServerState));
CloseClient :: !*DLClientState !*(IOState !*DLServerState) -> (!*DLClientState,!*(IOState !*DLServerState));
