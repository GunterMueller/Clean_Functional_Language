definition module search

// Clean sensitive searching...

import StdId, StdPSt
import PmProject, PmPrefs
import IDE
import fbi

initFindBoxInfo :: !Prefs !*a -> *(.(FindBoxInfo *(PSt General)),*a) | Ids, accScreenPicture a

sr_find_idi			:: !Bool !*(PSt General) -> *PSt General
// find identifier
sr_find_def			:: !Bool !*(PSt General) -> *PSt General
// find definition
sr_find_imp			:: !Bool !*(PSt General) -> *PSt General
// find implementation

sr_find_def_imp_sel	:: !Bool !{#.Char} !.Pathname !.(FindBoxInfo *(PSt *General)) !*(PSt *General) -> *(PSt *General)

sw_safe_close		:: !*(PSt *General) -> *PSt *General
sw_maybe_close		:: !Id !*(PSt *General) -> (Bool,*(PSt *General))

wind_next			:: !Bool !*(PSt *General) -> *PSt *General

src_options			:: !*(PSt *General) -> *PSt *General;
