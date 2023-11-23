definition module timerDevice;

import ioState;

    
TimerFunctions	::    DeviceFunctions state;

ReOpenTimers	:: ![TimerHandle s] !(IOState s) -> IOState s;
