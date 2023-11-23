definition module deltaTimer;

import deltaEventIO, deltaIOSystem;

:: CurrentTime :== (!Int,!Int,!Int); // (hours (0-23), minutes (0-59), seconds)
:: CurrentDate :== (!Int,!Int,!Int,!Int); // (year, month (1-12), day (1-31),
                                         //  day of the week (1=sunday))

  TicksPerSecond :== 1000;

OpenTimer :: !(TimerDef s (IOState s)) !(IOState s) -> IOState s;
CloseTimer	::          !TimerId        !(IOState s) -> IOState s;
EnableTimer ::         !TimerId        !(IOState s) -> IOState s;
DisableTimer ::        !TimerId        !(IOState s) -> IOState s;
ChangeTimerFunction :: !TimerId !(TimerFunction s (IOState s)) !(IOState s)
   -> IOState s;
SetTimerInterval ::    !TimerId !TimerInterval !(IOState s) -> IOState s;
GetTimerBlinkInterval :: !(IOState s) -> (!TimerInterval, !IOState s);
GetCurrentTime ::        !(IOState s) -> (!CurrentTime,   !IOState s);
GetCurrentDate ::        !(IOState s) -> (!CurrentDate,   !IOState s);
Wait ::  !TimerInterval x     -> x;
UWait :: !TimerInterval * x -> * x;
