definition module projmen

// The Project menu...

import StdReceiver
import PmProject, IdeState

ProjListMenu :: Id Id (R2Id PLMMessage PLMReply) -> NewLS (:+: RadioMenu (Receiver2 PLMMessage PLMReply)) .a *(PSt *General)

pm_menu_add :: .Pathname !*(PSt *General) -> *PSt *General;

pm_menu_rem :: !*(PSt *General) -> *PSt *General;

pm_new :: !*(PSt *General) -> *PSt *General;

pm_new_project_using_template :: !*(PSt *General) -> *PSt *General;

pm_open :: !*(PSt *General) -> *PSt *General;

pm_open_path :: !.String !*(PSt *General) -> *PSt *General;

pm_switch :: !.Pathname !*(PSt *General) -> (!Bool,!*PSt *General);
