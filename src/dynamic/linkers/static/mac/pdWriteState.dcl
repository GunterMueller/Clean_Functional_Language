definition module pdWriteState;

// macOS

import SymbolTable, State;

//WriteXCoff :: !Xcoff !*File -> !*File;
write_raw_data :: !*State !*File !*Files -> (!*State,!*File,!*Files);
write_xcoff :: !*Xcoff !*File -> (!*Xcoff,!*File);