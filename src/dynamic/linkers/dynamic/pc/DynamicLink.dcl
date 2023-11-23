definition module DynamicLink;

from ProcessSerialNumber import :: ProcessSerialNumber;

// At start-up time
FirstInstanceOfServer2 :: !Bool -> Bool;
is_first_instance :: Bool;

// cmd_line must be zeroterminated
StartProcess :: !String !String !String -> (!Bool,!Int);
KillClient :: !Int -> Bool;

// Communication at link time
ReplyReq :: !Int -> Bool;	
ReplyReqS :: !String -> Bool;
ReceiveCodeDataAdr :: !Int !Int -> (!Bool,!*Int,!*Int);
ReceiveReqWithTimeOutE :: !Bool -> (!Bool,!ProcessSerialNumber,!String);
GenerateObjectFileOld :: !String !String -> Bool;

// Memory functions
StoreLong :: !String !Int !Int -> Bool;
SetCurrentLibrary :: !String -> (!Bool,!*Int);
GetFuncAddress :: !String !Int !*Int -> (!Int, !*Int);
mwrites :: !Int !Int !{#Char} !*Int -> *Int;
MakeNonUnique :: !*Int -> (!*Int, !Int);

GetDynamicLinkerPath :: String;
FlushBuffers :: !Int -> Int;
PassCommandLine :: !String -> Bool;
