definition module ioState;


import picture, deltaIOSystem, xtypes, xevent;
from dialogDef import :: DialogHandle (DialHandle), :: DialogMode (Modal,Modeless);

:: * IOState * s;
:: * EVENTS;

:: DeviceSystemState *s = TimerSystemState       (TimerHandles s)
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
:: MenuHandles * s * io :== (![KeyShortcut], ![MenuHandle s io], !Bool);
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
:: OpenFunction * s :== (DeviceSystem s (IOState s)) -> (IOState s) ->  IOState s  ;
:: DoIOFunction  * s :== Event ->  s -> * ( (IOState s) -> *(Bool, s, IOState s) ) ;
:: CloseFunction * s :== (IOState s) ->  IOState s ;


    

OpenEvents	:: !* World -> (!EVENTS, !* World);
CloseEvents	:: !EVENTS !* World -> * World;

NewIOStateFromOld	:: !(IOState s) -> (!IOState t, !IOState s);
OldIOStateFromNew	:: !(IOState s) !(IOState t) -> IOState s;
EmptyIOState	:: !EVENTS !*World -> IOState s;
IOStateEvents	:: !(IOState s) -> EVENTS;

IOStateClosed ::       !(IOState s) -> (!Bool, !IOState s);
IOStateGetAnyDevice :: !(IOState s) -> (!DeviceSystemState s, !IOState s);
IOStateSetDevice ::    !(IOState s) !(DeviceSystemState s) -> IOState s;
IOStateHasDevice ::    !(IOState s) !Device -> (!Bool, !IOState s);
IOStateGetDevice ::    !(IOState s) !Device -> (!DeviceSystemState s, !IOState s);
IOStateRemoveDevice :: !(IOState s) !Device -> IOState s;

IOStateGetWorld :: (IOState *s) -> (!*World, IOState *s);
IOStateSetWorld :: !*World (IOState *s) -> IOState *s;


// Access-rules on DeviceSystemStates:

DeviceSystemStateToDevice :: !(DeviceSystemState s) -> Device;

TimerSystemState_TimerHandles :: !(DeviceSystemState s) -> TimerHandles s;

Priority :: !Device -> Int;
