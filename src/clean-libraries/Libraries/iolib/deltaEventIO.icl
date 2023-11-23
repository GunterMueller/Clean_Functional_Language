implementation module deltaEventIO;

/*	Halbe: FinishIOSystem niet correct: TimerDevice wordt niet
          toegevoegd.
*/

import StdClass,StdInt, StdBool, StdMisc;

import xkernel, ioState, deltaIOSystem;
from misc import UEvaluate_2;

from timerDevice  import TimerFunctions;
from menuDevice   import MenuFunctions;
from windowDevice import WindowFunctions;
from dialogDevice import DialogFunctions;

::	InitialIO *s	:== [s -> *((IOState s) -> *(s, IOState s))];

/*	Starting an interaction:
*/

StartIO	:: !(IOSystem *s (IOState *s)) !*s !(InitialIO *s) !*World -> (!*s, !*World);
StartIO system_new s0 fs world
	= 	(sn, CloseEvents (IOStateEvents io_s2) world2);
		where {
		(events, world1) =: OpenEvents world;
		(world2, io_s2) =: IOStateGetWorld io_sn;
		(sn, io_sn)	=: DoIO io_functions s1 io_s1;
		(s1, io_s1)	=: DoInitialIO fs s0 io_s0;
		io_s0			=: ShowToplevel io_s;
		io_s =: OpenIO system` (EmptyIOState events world1);
      io_functions=: IOSystemGetDoIOFunctions system`;
		system`		=: SortIOSystem (FinishIOSystem Devices system_new);
		};


/*	Starting a nested interaction:
*/

NestIO	:: !(IOSystem *t (IOState *t)) !*t !(InitialIO *t) !(IOState *s) -> (!*t, !IOState *s);
NestIO system_new t0 fs io_s
   =  (tn, ShowIO (OldIOStateFromNew hidden_io_s io_tn));
      where {
      (tn, io_tn)            =: DoIO io_functions t1 io_t1;
		(t1, io_t1)            =: DoInitialIO fs t0 io_t0;
      io_t0                  =: ShowToplevel io_t`;
      io_t`                  =: OpenIO system` new_io_t;
      (new_io_t, hidden_io_s)=: NewIOStateFromOld hide_io_s;
      hide_io_s              =: HideIO io_s;
      io_functions           =: IOSystemGetDoIOFunctions system`;
		system`                =: SortIOSystem (FinishIOSystem Devices system_new);
      };


DoInitialIO	:: !(InitialIO *s) !*s !(IOState *s) -> (!*s, !IOState *s);
DoInitialIO [f : fs] s io
	= 	DoInitialIO fs s` io`;
		where {
		(s`, io`)=: f s io;
		};
DoInitialIO f s io =  (s, io);

ShowToplevel :: !(IOState s) -> IOState s;
ShowToplevel io_state =  UEvaluate_2 io_state (show_toplevelx 0);


HideIO :: !(IOState s) -> IOState s;
HideIO io_state =  HideIO` (UEvaluate_2 io_state (hide_toplevelx 0)) Devices;
    
HideIO` :: !(IOState s) ![Device] -> IOState s;
HideIO` io_state [d : ds]
        | exists=  hide io_state``;
   =  io_state``;
      where {
      hide                =: Device_HideFunction d;
      (exists, io_state`) =: IOStateHasDevice io_state d;
      io_state``          =: HideIO` io_state` ds;
		};
HideIO` io_state ds =  io_state;


ShowIO :: !(IOState s) -> IOState s;
ShowIO io_state
   =  ShowToplevel (ShowIO` io_state Devices);
    
ShowIO` :: !(IOState s) ![Device] -> IOState s;
ShowIO` io_state [d : ds]
        | exists=  show io_state``;
   =  io_state``;
      where {
      show                =: Device_ShowFunction d;
      (exists, io_state`) =: IOStateHasDevice io_state d;
      io_state``          =: ShowIO` io_state` ds;
		};
ShowIO` io_state ds =  io_state;


OpenIO :: !(IOSystem s (IOState s)) !(IOState s) -> IOState s;
OpenIO [d : ds] io_state
   =  open d (OpenIO ds io_state);
      where {
      open=: Device_OpenFunction (DeviceSystemToDevice d);
      };
OpenIO ds io_state =  io_state;


DoIO :: ![DoIOFunction *s] !*s !(IOState *s) -> (!*s, !IOState *s);
DoIO io_functions state io_state
       | closed=  (state`, io_state``);
   =  DoIO io_functions state` io_state``;
      where {
      (closed, io_state``)=: IOStateClosed io_state`;
      (state`, io_state`) =: LetDevicesDoIO io_functions event state io_state;
      event               =: GetNextEvent;
      };

LetDevicesDoIO :: ![DoIOFunction *s] !Event !*s !(IOState *s) -> (!*s, !IOState *s);
LetDevicesDoIO [do_io : do_io`s] event state io_state
    | this_made_sense=  (state`, io_state`);
   =  LetDevicesDoIO do_io`s event state` io_state`;
      where {
      (this_made_sense, state`, io_state`)=: do_io event state io_state;
      };
LetDevicesDoIO do_io event state io_state =  (state, io_state);


/*  Quit the interaction in which this function is applied:
*/
QuitIO :: !(IOState s) -> IOState s;
QuitIO io =  QuitIO` (UEvaluate_2 io (hide_toplevelx 0));

QuitIO` :: !(IOState s) -> IOState s;
QuitIO` io_state
   | closed  =  io_state`;
   =  QuitIO` (close io_state``);
      where {
      close=: Device_CloseFunction (DeviceSystemStateToDevice device);
      (device, io_state``)=: IOStateGetAnyDevice io_state`;
      (closed, io_state` )=: IOStateClosed io_state;
      };

/* Apply a number of IOState transitions on the IOState:
   the functions will be evaluated from their left to right appearence in the list.
*/

ChangeIOState :: ![(IOState s) ->  IOState s ] !(IOState s) -> IOState s;
ChangeIOState [f : fs] io_state #!
		strict1=strict1;
		=
		ChangeIOState fs strict1;
	where {
	strict1=(f io_state);
		
	};
ChangeIOState fs io_state       =  io_state;

/* The interface layer to all Event devices:
*/

Devices :== [TimerDevice, MenuDevice, WindowDevice, DialogDevice];

FinishIOSystem	:: ![Device] !(IOSystem s (IOState s)) -> IOSystem s (IOState s);
FinishIOSystem [d : ds] io_system
		| IOSystemContainsDevice io_system d=  FinishIOSystem ds io_system;
	=  FinishIOSystem ds (InsertIOSystem (EmptyDevice d) d (Priority d) io_system);
FinishIOSystem ds io_system =  io_system;

EmptyDevice :: !Device -> DeviceSystem s (IOState s);
EmptyDevice MenuDevice   =  MenuSystem   [];
EmptyDevice DialogDevice =  DialogSystem [];
EmptyDevice WindowDevice =  WindowSystem [];
EmptyDevice TimerDevice  =  TimerSystem  [];

IOSystemGetDoIOFunctions :: !(IOSystem s (IOState s)) -> [DoIOFunction s];
IOSystemGetDoIOFunctions [d : ds]
   #!
		strict1=strict1;
		strict2=strict2;
		=
		[strict1 : strict2];
      where {
      device=: DeviceSystemToDevice d;
      strict1=Device_DoIOFunction device;
		strict2=IOSystemGetDoIOFunctions ds;
		};
IOSystemGetDoIOFunctions ds =  [];

Device_ShowFunction :: !Device -> ShowFunction s;
Device_ShowFunction device #!
      strict1=Device_Functions device;
	#
      (show, open, io, close, hide)= strict1;
		=
		show;

Device_OpenFunction :: !Device -> OpenFunction s;
Device_OpenFunction device #!
      strict1=Device_Functions device;
    #  (show, open, io, close, hide)= strict1;
		=
		open;

Device_DoIOFunction :: !Device -> DoIOFunction s;
Device_DoIOFunction device #!
      strict1=Device_Functions device;
     # (show, open, io, close, hide)= strict1;
		=
		io;

Device_CloseFunction :: !Device -> CloseFunction s;
Device_CloseFunction device #!
      strict1=Device_Functions device;
    #  (show, open, io, close, hide)= strict1;
		=
		close;

Device_HideFunction :: !Device -> HideFunction s;
Device_HideFunction device #!
      strict1=Device_Functions device;
    #  (show, open, io, close, hide)= strict1;
		=
		hide;

Device_Functions :: !Device -> DeviceFunctions s;
Device_Functions TimerDevice  =  TimerFunctions;
Device_Functions MenuDevice   =  MenuFunctions;
Device_Functions WindowDevice =  WindowFunctions;
Device_Functions DialogDevice =  DialogFunctions;

SortIOSystem :: !(IOSystem s (IOState s)) -> IOSystem s (IOState s);
SortIOSystem [d : ds]
   =  InsertIOSystem d device (Priority device) (SortIOSystem ds);
      where {
      device=: DeviceSystemToDevice d;
      };
SortIOSystem ds =  ds;

InsertIOSystem :: !(DeviceSystem s (IOState s)) !Device !Int !(IOSystem s (IOState s)) 
   -> IOSystem s (IOState s);
InsertIOSystem d device priority devices=:[sorted_d : sorted_ds]
     | priority >=  Priority (DeviceSystemToDevice sorted_d) =  [d : devices];
   #!
		strict1=strict1;
		=
		[sorted_d : strict1];
	where {
	strict1=InsertIOSystem d device priority sorted_ds;
		
	};
InsertIOSystem d device priority ds =  [d];

IOSystemContainsDevice :: !(IOSystem s (IOState s)) !Device -> Bool;
IOSystemContainsDevice [d : ds] device
       | eq_Device (DeviceSystemToDevice d) device=  True;
   =  IOSystemContainsDevice ds device;
IOSystemContainsDevice ds device =  False;


DeviceSystemToDevice	:: !(DeviceSystem s (IOState s)) -> Device;
DeviceSystemToDevice (TimerSystem  x) =  TimerDevice;
DeviceSystemToDevice (WindowSystem x) =  WindowDevice;
DeviceSystemToDevice (MenuSystem   x) =  MenuDevice;
DeviceSystemToDevice (DialogSystem x) =  DialogDevice;

eq_Device :: !Device !Device -> Bool;
eq_Device TimerDevice  TimerDevice  =  True;
eq_Device WindowDevice WindowDevice =  True;
eq_Device MenuDevice   MenuDevice   =  True;
eq_Device DialogDevice DialogDevice =  True;
eq_Device d d` =  False;

