definition module DynamicLink;

import StdEnv;

import deltaDialog, deltaIOSystem, deltaWindow, deltaIOState, StdString, StdChar;
import ProcessSerialNumber;

//GenObj :: !String !String !*Files -> (!Bool,!Bool,!String,!String,!*Files);

GetModulePath :: !String !String !Int !String -> (!Bool,!String,!Bool);
GetSymbolPath :: !String !Int !String !String !String -> (!String,!Bool,!String);

//KillClient2 :: !ProcessSerialNumber !(IOState s) -> !(IOState s);

