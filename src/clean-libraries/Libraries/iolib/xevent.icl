implementation module xevent;

//
// Version 0.84sp
//
// Interface to X Events.
//


from xtypes  import :: Widget;
from xkernel import single_event_catch;


     

XMenuDevice             :== 1;
XNullDevice             :== 4;
XTimerDevice            :== 5;
XWindowDevice           :== 6;
XDialogDevice           :== 7;

XWindowMouse            :== 3;
XWindowKeyboard         :== 2;
XWindowActivate         :== 20;
XWindowDeactivate       :== 21;
XWindowUpdate           :== 22;
XWindowClosed           :== 23;

XButtonUp               :== 1;
XButtonDown             :== 2;
XButtonStillDown        :== 3;
XDoubleClick            :== 4;
XTripleClick            :== 5;
XKeyUp                  :== 1;
XKeyDown                :== 2;
XKeyStillDown           :== 3;

XDialogButton           :== 30;
XDialogClosed           :== 31;
XDialogRadioButton      :== 32;
XDialogCheckButton      :== 33;
XDialogRedraw           :== 34;
XDialogMouse            :== 35;
XDialogApply            :== 36;
XDialogReset            :== 37;
XDialogIMouse           :== 38;
XDialogIRedraw          :== 39;
XDialogActivate         :== 40;
XAboutRedraw            :== 41;
XAboutHelp              :== 42;


    

:: XDevice      :== Int;
:: XEvent       :== Int;
:: Event        :== (Widget,XDevice,XEvent);
:: MouseEvent   :== (!Int,!Int,!Int,!Int,!Int,!Int,!Int);
:: KeyEvent     :== (!Int,!Int,!Int,!Int,!Int,!Int);
:: NullEvent    :== (!Int,!Int,!Int);
:: DialogEvent  :== (!Int, !Widget);


    

GetNextEvent ::    Event;
GetNextEvent = (w,d,e);
                   where {
                   (w,d)=: single_event_catch 0;
                   e=: 0;
                   }; // this is were an event specification should be.
