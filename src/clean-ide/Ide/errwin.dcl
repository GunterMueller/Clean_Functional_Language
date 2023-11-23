definition module errwin

// errors and warnings window

import StdPSt, StdId
import IdeState

sr_find_err			:: !Bool !*(PSt *General) -> *PSt *General
// Goto next error in error window

updateErrorWindow :: !([String]) !*(PSt *General) -> *PSt *General;
// Add lines to error window. If not open then open it

ew_is_active			:: !*(PSt *General) -> (!Bool,!*PSt *General)
ew_safe_close			:: !*(PSt *General) -> *PSt *General
ew_maybe_close			:: !Id !*(PSt *General) -> (Bool,*PSt *General)

err_init			:: !ErrPrefs *World -> *(.ErrorInfo .c,*World)
// Initialise options from prefs

err_shut			:: !(ErrorInfo .a) -> ErrPrefs
// Initialise prefs from options

err_options			:: !*(PSt *General) -> *PSt *General;
// Show options dialog for error window
