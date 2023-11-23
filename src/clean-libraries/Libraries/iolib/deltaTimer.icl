implementation module deltaTimer;

import StdClass, StdInt, StdBool;
import commonDef, ioState, deltaIOSystem, timerDevice;
import xtimer, misc;

:: CurrentTime :== (!Int,!Int,!Int); // (hours (0-23), minutes (0-59), seconds)
:: CurrentDate :== (!Int,!Int,!Int,!Int); // (year, month (1-12), day (1-31),
                                         //  day of the week (1=Sunday))
     
TicksPerSecond :== 1000;

/* Installing and removing of Timers:
*/

OpenTimer	:: !(TimerDef s (IOState s)) !(IOState s) -> IOState s;
OpenTimer timer io =  ReOpenTimers [(0,timer):timers] io`;
	   where {
	   (interval,timers,io`)=: IOStateGetTimers io;
	   };

CloseTimer	:: !TimerId !(IOState s) -> IOState s;
CloseTimer id io
		| reopen =  ReOpenTimers timers` io`;
		=  IOStateSetDevice io` (TimerSystemState (interval,timers`));
		where {
		(reopen,timers`)     =: RemoveTimer id timers;
	   (interval,timers,io`)=: IOStateGetTimers io;
		};

RemoveTimer	:: !TimerId ![TimerHandle s] -> (!Bool, ![TimerHandle s]);
RemoveTimer tid [timer=:(time,Timer id abty int fun) : timers]
	| tid == id =  (Enabled abty, timers);
	#!
	   strict1=RemoveTimer tid timers;
	#  (reopen, rest)= strict1;
		=
		(reopen, [timer : rest]);
RemoveTimer tid [] =  (False, []);


/*	Enabling and Disabling of Timers:
*/
EnableTimer	:: !TimerId !(IOState state) -> IOState state;
EnableTimer id io
		| reopen =  ReOpenTimers timers` io`;
		=  IOStateSetDevice io` (TimerSystemState (interval,timers`));
		where {
		(reopen,timers`)     =: SetTimerAbility id Able timers;
	   (interval,timers,io`)=: IOStateGetTimers io;
		};

DisableTimer	:: !TimerId !(IOState state) -> IOState state;
DisableTimer id io 
		| reopen =  ReOpenTimers timers` io`;
		=  IOStateSetDevice io` (TimerSystemState (interval,timers`));
		where {
		(reopen,timers`)     =: SetTimerAbility id Unable timers;
	   (interval,timers,io`)=: IOStateGetTimers io;
		};

SetTimerAbility	:: !TimerId !SelectState ![TimerHandle s]
	-> (!Bool, ![TimerHandle s]);
SetTimerAbility tid tab [timer=:(time,Timer id abty i f) : timers]
	| tid <> id #!
	   strict1=SetTimerAbility tid tab timers;
	#  (reopen, rest)= strict1;
		=
		 (reopen, [timer : rest]);
		=
		(not (SelectStateEqual tab abty), [(0,Timer id tab i f) : timers]);
SetTimerAbility tid tab [] =  (False, []);

/*	Changing the TimerFunction:
*/
ChangeTimerFunction	:: !TimerId !(TimerFunction s (IOState s)) !(IOState s)
	-> IOState s;
ChangeTimerFunction id f io
		=  IOStateSetDevice io` (TimerSystemState (interval,timers`));
		where {
		timers`              =: SetTimerFunction id f timers;
	   (interval,timers,io`)=: IOStateGetTimers io;
		};

SetTimerFunction	:: !TimerId !(TimerFunction s (IOState s))
	                 ![TimerHandle s] -> [TimerHandle s];
SetTimerFunction tid tfun [timer=:(time,Timer id ab int fun) : timers]
	| id == tid =  [(time,Timer id ab int tfun) : timers];
	#!
		strict1=strict1;
		=
		[timer : strict1];
	where {
	strict1=SetTimerFunction tid tfun timers;
		
	};
SetTimerFunction tid tfun [] =  [];


/*	Changing the TimerInterval:
*/
SetTimerInterval	:: !TimerId !TimerInterval !(IOState state) -> IOState state;
SetTimerInterval id i io
		| reopen =  ReOpenTimers timers` io`;
		=  IOStateSetDevice io` (TimerSystemState (interval,timers`));
		where {
		(reopen,timers`)     =: ChangeTimerInterval id i timers;
	   (interval,timers,io`)=: IOStateGetTimers io;
		};

ChangeTimerInterval	:: !TimerId !TimerInterval ![TimerHandle s]
	-> (!Bool, ![TimerHandle s]);
ChangeTimerInterval tid tint [timer=:(time,Timer id abty int f) : timers]
	| tid <> id #!
	   strict1=ChangeTimerInterval tid tint timers;
	#  (reopen, rest)= strict1;
		=
		 (reopen, [timer : rest]);
		=
		( Enabled abty  &&  tint <> int , [(time,Timer id abty tint f) : timers]);
ChangeTimerInterval tid tint [] =  (False, []);


/* Get the carets (cursor) blinking rate, but no blinking cursor on unix
*/
GetTimerBlinkInterval	:: !(IOState s) -> (!TimerInterval, !IOState s);
GetTimerBlinkInterval io =  (0,io);


/* Get current time and current date.
*/
GetCurrentTime :: !(IOState s) -> (!CurrentTime, !IOState s);
GetCurrentTime io =  (get_current_time 0, io);

GetCurrentDate :: !(IOState s) -> (!CurrentDate, !IOState s);
GetCurrentDate io =  (get_current_date 0, io);


/* Wait a specified interval of time.
*/
Wait :: !TimerInterval x -> x;
Wait interval x =  Evaluate_2 x (wait_mseconds interval); 

UWait :: !TimerInterval * x -> * x;
UWait interval x =  UEvaluate_2 x (wait_mseconds interval);

// Get the timer handles from the IOState

IOStateGetTimers	:: !(IOState s) -> (!Int, ![TimerHandle s], !IOState s);
IOStateGetTimers io =  (interval,timers,io`);
	   where {
	   (interval,timers) =: TimerSystemState_TimerHandles timer_device;
	   (timer_device,io`)=: IOStateGetDevice io TimerDevice;
	   };
