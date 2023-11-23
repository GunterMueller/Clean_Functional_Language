definition module pdRequest;

from DLState import :: DLServerState, :: DLClientState;
from State import :: State;
from ProcessSerialNumber import :: ProcessSerialNumber;

// AddClient
ExtractProjectPathName :: !String -> String;
StartClientApplication3 :: !String !String !.Bool !String !*DLServerState -> *(Bool,ProcessSerialNumber,{#Char},!*DLServerState);

// Init
ParseCommandLine :: !String -> {#{#Char}};

// AddAndInit
RemoveStaticClientLibrary :: !*State -> *State;

// Close
CloseClient :: !*DLClientState -> *DLClientState;

