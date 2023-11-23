definition module interrupt

import StdId, StdPSt, IdeState

StartIntr :: !(!Id,Id) .a (.Bool -> .(.a -> .(*(PSt .b) -> *(.a,*(PSt .b))))) !*(PSt .b) -> *(PSt .b)
StopIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
ContIntr :: !(.a,!Id) !*(PSt .b) -> *(PSt .b)
