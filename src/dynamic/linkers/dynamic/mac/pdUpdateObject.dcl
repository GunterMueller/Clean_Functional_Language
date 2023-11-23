definition module pdUpdateObject;

import StdEnv;

import DLState;
import UnknownModuleOrSymbol;


generate_abc_file :: !String !String ![!ModuleOrSymbolUnknown] ![!String] !*State !*DLClientState !*DLServerState !(IOState s) -> !(!Bool,!String,![!ModuleOrSymbolUnknown],![!String],!*State,!*DLClientState,!*DLServerState,!(IOState s));

