implementation module OS_utilities;

import mac_types;

GetDate :: !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
GetDate t = code (t=R14O0D0U)(year=W,month=W,day=W,dayOfWeek=I6W,z=Z){
	call	.GetTime
};

GetTime :: !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
GetTime t = code (t=R14O0D0U)(hour=I6W,minute=W,second=W,z=I2Z){
	call	.GetTime
};

Secs2Date :: !Int !*Toolbox -> (!Int,!Int,!Int,!Int,!*Toolbox);
Secs2Date secs t = code (secs=R14O0D1D0,t=U)(year=W,month=W,day=W,dayOfWeek=I6W,z=Z){
	call	.SecondsToDate
};

Secs2Time :: !Int !*Toolbox -> (!Int,!Int,!Int,!*Toolbox);
Secs2Time secs t = code (secs=R14O0D1D0,t=U)(hour=I6W,minute=W,second=W,z=I2Z){
	call	.SecondsToDate
};

SysBeep :: !Int !*Toolbox -> *Toolbox;
SysBeep duration t = code (duration=D0,t=U)(z=Z){
	call	.SysBeep
};
	
GetCursor :: !Int !*Toolbox -> (!Handle,!*Toolbox);
GetCursor cursorID t = code (cursorID=D0,t=U)(crsr_handle=D0,z=Z){
	call	.GetCursor
};
