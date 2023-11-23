implementation module ioState;


/* Halbe: introduced EVENTS, changed type IOState, changed access rules,
          removed Null device. */

import StdClass;
import StdInt, StdBool, StdMisc, StdString;
import misc,xtypes,xevent,xkernel;
import deltaIOSystem;
import picture;
from dialogDef import :: DialogHandle (DialHandle), :: DialogMode (Modal, Modeless);

:: Maybe a = Nothing | Just a;
    
::   * IOState * s :== (![DeviceSystemState s], !EVENTS, !*Maybe *World);
::   * EVENTS			:== Int;

:: DeviceSystemState *s
      = TimerSystemState       (TimerHandles s)
      |  WindowSystemState      (WindowHandles s)
      |  MenuSystemState Widget (MenuHandles   s (IOState s))
      |  DialogSystemState      (DialogHandles s (IOState s));

/*	The timer handles.
*/
::	TimerHandles * s :== (Int, [TimerHandle s]);
::	TimerHandle  * s :== (Int, TimerDef s (IOState s));

/* The window handles.
*/
:: WindowHandles * s :== [WindowHandle s];
:: WindowHandle  * s :== (!WindowDef s (IOState s), !Window);
:: Window :== (!WindowPtr, !XPicture);


/* Menu handle definition extended for efficient use in X toolkits.
   The MenuDef is not included, because it is not needed and without it 
   every function in deltaMenu is more straightforward.
*/
:: MenuHandles    * s * io :== (![KeyShortcut], ![MenuHandle s io], !Bool);
:: MenuItemHandle * s * io
      = MenuSeparatorHandle Widget
      |  SubMenuHandle XMenuItemHandle [MenuItemHandle s io]
      |  MenuItemGroupHandle XMenuItemHandle [MenuItemHandle s io]
      |  ItemHandle XMenuItemHandle (MenuFunction s io)
      |  RadioHandle MenuItemId [RadioMenuItemHandle s io];
:: RadioMenuItemHandle * s * io 
      = RadioItemHandle XMenuItemHandle (MenuFunction s io);
:: MenuHandle * s * io 
      = PullDownHandle SelectState XMenuHandle [MenuItemHandle s io]
      |  EmptyHandle;


/* The dialog handles.
*/
:: DialogHandles * s * io :== [DialogHandle s io];

:: Device = TimerDevice | MenuDevice | WindowDevice | DialogDevice;

:: DeviceFunctions * s :== (!ShowFunction  s,
                             !OpenFunction  s,
                             !DoIOFunction  s,
                             !CloseFunction s,
                             !HideFunction  s);

:: ShowFunction * s :== (IOState s) ->  IOState s ;
:: HideFunction * s :== (IOState s) ->  IOState s ;
:: OpenFunction * s :== (DeviceSystem s (IOState s)) ->  (IOState s) ->  IOState s  ;
:: DoIOFunction  * s :== Event ->  s -> * ( (IOState s) -> *(Bool, s, IOState s) ) ;
:: CloseFunction * s :== (IOState s) ->  IOState s ;

DummyEvents :== 0;
    
OpenEvents   :: !* World -> (!EVENTS, !* World);
OpenEvents world
   =  UEvaluate_2 (OpenEvents1 world) (open_toplevelx (init_toplevelx 0));

CloseEvents   :: !EVENTS !* World -> * World;
CloseEvents events world
   =  UEvaluate_2 (CloseEvents1 events world) (close_toplevelx 0);


OpenEvents1   :: !* World -> (!EVENTS, !* World);
OpenEvents1 world
   | 0 == (2 bitand w) = 	OpenEvents2 (StoreWorld (w bitor 2) world);
   = 	abort "OpenEvents: This world doesn't contain events";
   	where {
   	w=: LoadWorld world;
   	};

OpenEvents2   :: !* World -> (!EVENTS, !* World);
OpenEvents2 w =  code {
   	pushI 0
   };

LoadWorld :: !World -> Int;
LoadWorld w = code {
		pushI_a 0
		pop_a 1
	};

StoreWorld :: !Int !World -> *World;
StoreWorld i w = code {
		fillI_b 0 1
		pop_b 1
		pop_a 1
	};

CloseEvents1   :: !EVENTS !* World -> * World;
CloseEvents1 e world
   = 	CloseEvents2 e (StoreWorld ( LoadWorld world  bitand (-3)) world);

CloseEvents2   :: !EVENTS !* World -> * World;
CloseEvents2 e w =  code {
   	pop_b 1
   	fill_a 0 1
   	pop_a 1
   };


/*   Creation rules for IOStates:
*/

NewIOStateFromOld   :: !(IOState s) -> (!IOState t, !IOState s);
NewIOStateFromOld (ds, es, Just world)
	=  (EmptyIOState es world, (ds, DummyEvents, Nothing));

OldIOStateFromNew   :: !(IOState s) !(IOState t) -> IOState s;
OldIOStateFromNew (ds, DummyEvents, Nothing) (ds`, es, Just world) =  (ds, es, Just world);

EmptyIOState   :: !EVENTS !*World -> IOState s;
EmptyIOState es world =  ([],es,Just world);

IOStateEvents   :: !(IOState s) -> EVENTS;
IOStateEvents (_, es, _) =  es;

IOStateClosed :: !(IOState s) -> (!Bool, !IOState s);
IOStateClosed io_state=:([],_, _) =  (True, io_state);
IOStateClosed io_state =  (False, io_state);

IOStateGetAnyDevice :: !(IOState s) -> (!DeviceSystemState s, !IOState s);
IOStateGetAnyDevice io_state=:([d : ds],_, _) =  (d, io_state);

IOStateSetDevice :: !(IOState s) !(DeviceSystemState s) -> IOState s;
IOStateSetDevice (ds,es,w) d
   #!
		strict1=strict1;
		=
		(strict1, es,w);
      where {
      priority=: Priority (DeviceSystemStateToDevice d);
      strict1=SetDevice ds priority d;
		};

SetDevice :: ![DeviceSystemState s] !Int !(DeviceSystemState s)
   -> [DeviceSystemState s];
SetDevice [WindowSystemState x : ds] priority d=:(WindowSystemState x`)
   =  [d : ds];
SetDevice [MenuSystemState w x : ds] priority d=:(MenuSystemState w` x`) 
   =  [d : ds];
SetDevice [DialogSystemState x : ds] priority d=:(DialogSystemState x`)
   =  [d : ds];
SetDevice [TimerSystemState  x : ds] priority d=:(TimerSystemState x`)
   =  [d : ds];
SetDevice ds=:[sorted_d : sorted_ds] priority d
       | priority >  Priority (DeviceSystemStateToDevice sorted_d) =  [d : ds];
   #!
		strict1=strict1;
		=
		[sorted_d : strict1];
	where {
	strict1=SetDevice sorted_ds priority d;
		
	};
SetDevice ds priority d =  [d];

IOStateGetDevice :: !(IOState s) !Device -> (!DeviceSystemState s, !IOState s);
IOStateGetDevice ([],es,w) device
   =  abort "Can't perform any event I/O operations on an empty IOState\n";
IOStateGetDevice iostate=:(ds,es,_) d =  (DevicesGetDevice ds d, iostate);

DevicesGetDevice :: ![DeviceSystemState s] !Device -> DeviceSystemState s;
DevicesGetDevice [d=:WindowSystemState x : ds] WindowDevice   =  d;
DevicesGetDevice [d=:MenuSystemState w x : ds] MenuDevice     =  d;
DevicesGetDevice [d=:DialogSystemState x : ds] DialogDevice   =  d;
DevicesGetDevice [d=:TimerSystemState  x : ds] TimerDevice    =  d;
DevicesGetDevice [d : ds] device =  DevicesGetDevice ds device;
DevicesGetDevice ds device =  abort "Device not present in IOState.\n";

IOStateRemoveDevice :: !(IOState s) !Device -> IOState s;
IOStateRemoveDevice (ds,es,world) d #!
		strict1=strict1;
		=
		(strict1, es, world);
	where {
	strict1=DevicesRemoveDevice ds d;
		
	};

DevicesRemoveDevice :: ![DeviceSystemState s] !Device -> [DeviceSystemState s];
DevicesRemoveDevice [WindowSystemState  x : ds] WindowDevice =  ds;
DevicesRemoveDevice [MenuSystemState  w x : ds] MenuDevice   =  ds;
DevicesRemoveDevice [DialogSystemState  x : ds] DialogDevice =  ds;
DevicesRemoveDevice [TimerSystemState   x : ds] TimerDevice  =  ds;
DevicesRemoveDevice [d` : ds] d #!
		strict1=strict1;
		=
		[d` : strict1];
	where {
	strict1=DevicesRemoveDevice ds d;
		
	};
DevicesRemoveDevice ds d =  ds;

IOStateHasDevice   :: !(IOState s) !Device -> (!Bool, !IOState s);
IOStateHasDevice iostate=:(ds,_,_) d =  (DevicesHasDevice ds d, iostate);

DevicesHasDevice :: ![DeviceSystemState s] !Device -> Bool;
DevicesHasDevice [d=:TimerSystemState   x : ds] TimerDevice  =  True;
DevicesHasDevice [d=:MenuSystemState w  x : ds] MenuDevice   =  True;
DevicesHasDevice [d=:WindowSystemState  x : ds] WindowDevice =  True;
DevicesHasDevice [d=:DialogSystemState  x : ds] DialogDevice =  True;
DevicesHasDevice [d` : ds] d =  DevicesHasDevice ds d;
DevicesHasDevice ds d =  False;


/* Access-rules on Devices:
*/
DeviceSystemStateToDevice :: !(DeviceSystemState s) -> Device;
DeviceSystemStateToDevice (WindowSystemState x) =  WindowDevice;
DeviceSystemStateToDevice (MenuSystemState w x) =  MenuDevice;
DeviceSystemStateToDevice (DialogSystemState x) =  DialogDevice;
DeviceSystemStateToDevice (TimerSystemState  x) =  TimerDevice;

TimerSystemState_TimerHandles :: !(DeviceSystemState s) -> TimerHandles s;
TimerSystemState_TimerHandles (TimerSystemState handles) =  handles;


Priority :: !Device -> Int;
Priority TimerDevice  =  4;
Priority MenuDevice   =  3;
Priority DialogDevice =  2;
Priority WindowDevice =  1;

IOStateGetWorld :: (IOState *s) -> (!*World, IOState *s);
IOStateGetWorld (ds,es,Just world)
	=	(world, (ds, es, Nothing));

IOStateSetWorld :: !*World (IOState *s) -> IOState *s;
IOStateSetWorld world (ds,es,Nothing)
	=	(ds, es, Just world);
