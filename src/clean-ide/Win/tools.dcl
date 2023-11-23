definition module tools

// launch supporting tools

import IdeState

shoprofun :: !*(PSt General) -> *PSt General
// launch time profiler for active project

shoheapfun :: !*(PSt General) -> *PSt General
// launch heap profiler for active project

provefun :: !*(PSt General) -> *PSt General
// launch theorem prover for active project

:: ToolInfo
toolData :: !.Prefs !*(PSt General) -> *(!.ToolInfo,!*PSt General)
toolOptions :: !.ToolInfo -> (:+: .TextControl (:+: .EditControl (:+: .ButtonControl (:+: .TextControl (:+: .EditControl (:+: .ButtonControl (:+: .TextControl (:+: .EditControl (:+: .ButtonControl .ButtonControl)))))))) .a *(PSt *General))
