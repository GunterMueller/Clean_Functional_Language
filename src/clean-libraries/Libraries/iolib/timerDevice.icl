implementation module timerDevice;

import StdClass; // RWS
import StdInt, StdBool, StdMisc, StdString;
import ioState, commonDef;
import xtimer,misc;

     
   Minterval :== 10;

    
TimerFunctions	::    DeviceFunctions state;
TimerFunctions = (ShowTimer,TimerOpen,TimerIO,TimerClose,HideTimer);

/*	Open the initial Timers */

TimerOpen	:: !(DeviceSystem s (IOState s)) !(IOState s) -> IOState s;
TimerOpen (TimerSystem timers) io
	| able =  UEvaluate_2 io` (enable_timer  install);
	=  UEvaluate_2 io` (disable_timer install);
		where {
		io`               =: IOStateSetDevice io (TimerSystemState (int,handles));
		install           =: install_timer int;
	   (able,int,handles)=: CalculateInterval (-1) timers;
		};

CalculateInterval	:: !Int ![TimerDef s (IOState s)]
	-> (!Bool,!Int,![TimerHandle s]);
CalculateInterval interval [timer=:Timer id abty int f : rest]
	| Enabled abty =  (True ,interval1,[(0,timer) : rest1]);
	=  (able2,interval2,[(0,timer) : rest2]);
	   where {
	   (able1,interval1,rest1)=: CalculateInterval (TimerGCD interval int) rest;
	   (able2,interval2,rest2)=: CalculateInterval interval rest;
	   };
CalculateInterval interval []
	| interval >= 0 =  (True, interval, []);
   =  (False, 0, []);

ReOpenTimers	:: ![TimerHandle s] !(IOState s) -> IOState s;
ReOpenTimers timers io
	| able =  UEvaluate_2 io` (enable_timer  install);
	=  UEvaluate_2 io` (disable_timer install);
		where {
		io`       =: IOStateSetDevice io (TimerSystemState (int,timers));
		install   =: install_timer int;
	   (able,int)=: ReCalcInterval False (-1) timers;
		};

ReCalcInterval	:: !Bool !Int ![TimerHandle s] -> (!Bool,!Int);
ReCalcInterval able interval [(time,Timer id abty int f) : rest]
	| not (Enabled abty) =  ReCalcInterval able interval rest;
	=  ReCalcInterval True (TimerGCD interval int) rest;
ReCalcInterval able interval []
	| interval >= 0 =  (able, interval);
   =  (False, 0);

TimerGCD	:: Int Int -> Int;
TimerGCD x y
	| y <= Minterval =  Minterval;
	| x < 0 =  y;
	| x < y =  TimerGCD y x;
	| xmy == 0 =  y;
	=  TimerGCD y xmy;
	   where {
	   xmy=: x rem y;
	   };

/*	The Timer event handling */

TimerIO	:: !Event !*s !(IOState *s) -> (!Bool, !*s, !IOState *s);
TimerIO (w,XTimerDevice,e) state io
	=  ApplyTimerFuns False funs state io``;
	   where {
	   io``          =: IOStateSetDevice io` (TimerSystemState (int,timers`));
	   (timers`,funs)=: TimersIO (int * tstate) timers;
		(int,timers)  =: TimerSystemState_TimerHandles timerdev;
		(timerdev,io`)=: IOStateGetDevice io TimerDevice;
		tstate        =: get_timer_count e;
	   };
TimerIO no_timer_event state io =  (False, state, io);

TimersIO	:: !Int ![TimerHandle *s]
   -> (![TimerHandle *s], ![*s -> *( (IOState *s) -> (*s, IOState *s)) ]);
TimersIO interval [thand=:(time,timer=:Timer id abty int fun) : rest]
	| not (Enabled abty) =  ([thand : trest], frest);
	| not its_turn =  (timers`, frest);
	=  (timers`, [fun tstate : frest]);
	   where {
	   timers`                =: [(time`,timer) : trest];
	   (trest,frest)          =: TimersIO interval rest;
	   (its_turn,tstate,time`)=: CalcTimerState interval time int;
	   };
TimersIO interval [] =  ([],[]);

CalcTimerState	:: !Int !Int !Int -> (!Bool,!Int,!Int);
CalcTimerState interval time int
	| int <= 0 =  (True , 1                   , 0          );
	| int <= Minterval =  (True , interval / Minterval, 0          );
	| int <= time` =  (True , time` / int         , time` rem int);
	=  (False, 0                   , time`      );
	   where {
	   time`=: time + interval;
	   };

ApplyTimerFuns	:: !Bool ![*s -> *( (IOState *s) -> (*s, IOState *s)) ] !*s !(IOState *s)
	-> (!Bool, !*s, !IOState *s);
ApplyTimerFuns handled [fun : rest] state io
	=  ApplyTimerFuns True rest state` io`;
	   where {
	   (state`,io`)=: fun state io;
	   };
ApplyTimerFuns handled [] state io =  (handled, state, io);

/*	Close the Timers before quitting */

TimerClose	:: !(IOState s) -> IOState s;
TimerClose io =  IOStateRemoveDevice (HideTimer io) TimerDevice;

/*	Hide the Timers before entering a nested interaction */

HideTimer	:: !(IOState s) -> IOState s;
HideTimer io =  UEvaluate_2 io (disable_timer (install_timer 0));

/* Show the Timers after quitting a nested interaction */

ShowTimer :: !(IOState s)  -> IOState s;
ShowTimer io
	| TimerEnabled timers =  UEvaluate_2 io` (enable_timer  install);
	=  UEvaluate_2 io` (disable_timer install);
	   where {
	   install           =: install_timer interval;
	   (interval,timers) =: TimerSystemState_TimerHandles timer_device;
	   (timer_device,io`)=: IOStateGetDevice io TimerDevice;
	   };

TimerEnabled :: ![TimerHandle s] -> Bool;
TimerEnabled [(time,Timer id abty int fun) : rest]
	| Enabled abty =  True;
	=  TimerEnabled rest;
TimerEnabled [] =  False;
