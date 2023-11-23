definition module pdWriteState;

// winOS

from State import :: State;
from pdSymbolTable import Xcoff;
	
write_raw_data :: !*State !*File !*Files -> (!*State,!*File,!*Files);
write_xcoff :: !*Xcoff !*File -> (!*Xcoff,!*File);