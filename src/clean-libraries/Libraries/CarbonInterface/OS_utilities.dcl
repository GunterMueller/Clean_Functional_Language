definition module OS_utilities;

import mac_types;

GetDate :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
GetTime :: !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
Secs2Date :: !Int !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
Secs2Time :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
SysBeep :: !Int !*Toolbox -> *Toolbox;
GetCursor :: !Int !*Toolbox -> (!Handle,!*Toolbox);
