definition module prefix

from StdPSt		import :: PSt
from IdeState	import :: General

add_prefix_selection	:: !*(PSt General) -> *PSt General
// add prefix to each line of selection

rem_prefix_selection	:: !*(PSt General) -> *PSt General
// remove prefix from each line of selection

change_prefix_dlog		:: !*(PSt General) -> *PSt General
// dialogue to change prefix for above operations

shift_selection_right	:: !*(PSt General) -> *PSt General
// block indent

shift_selection_left	:: !*(PSt General) -> *PSt General
// block outdent

increment_integers_in_selection :: !*(PSt General) -> *PSt General

decrement_integers_in_selection :: !*(PSt General) -> *PSt General
