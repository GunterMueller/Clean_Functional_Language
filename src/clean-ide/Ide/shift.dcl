definition module shift

// block indent functions

from StdPSt import PSt,IOSt
from IdeState import General

shift_selection_right	:: !*(PSt General) -> *PSt General
shift_selection_left	:: !*(PSt General) -> *PSt General

replace_lines_and_redraw :: (Int -> {#Char} -> .{#Char}) !*(PSt *General) -> *PSt *General;
