definition module projwin

import StdId, StdWindow
import IDE

isProjWin :: !Id !*(PSt *General) -> (!Bool,!*PSt *General)

projwinOptions :: !*(PSt *General) -> *PSt *General;

pm_open_project_window :: !*(PSt *General) -> *(PSt *General)

pm_update_project_window :: !*(PSt *General) -> *PSt *General

pm_set :: !*(PSt *General) -> *PSt *General

pm_compile	:: !*(PSt *General) -> *PSt *General;
pm_check	:: !*(PSt *General) -> *PSt *General;
pm_gen_asm	:: !*(PSt *General) -> *PSt *General;
pm_upto		:: !Bool !*(PSt *General) -> *PSt *General;
pm_exec		:: !*(PSt *General) -> *PSt *General;
pm_run		:: !*(PSt *General) -> *PSt *General;
pm_build	:: !.a -> .a;
pm_link		:: !.a -> .a;

pm_copt :: !*(PSt *General) -> *PSt *General

pm_coprefs :: !*(PSt *General) -> *PSt *General;

pm_save :: !*(PSt *General) -> *PSt *General
pm_save_as :: !*(PSt *General) -> *PSt *General
pm_save_copy_as :: !*(PSt *General) -> *PSt *General
pm_maybe_save :: !Id !*(PSt *General) -> (Bool,*PSt *General)
pm_save_project_as_template :: !*(PSt *General) -> *PSt *General
pm_set_window_title :: .Title !*(PSt *General) -> *PSt *General;
pm_get_projwin_possiz :: *(PSt *General) -> *(.(Vector2,Size),*PSt *General);
