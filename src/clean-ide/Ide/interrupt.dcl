definition module interrupt

// version B of interrupt routines
// todo: reintegrate with version A (UtilInterrupt)

import StdId, StdPSt

StartIntr :: !(!Id,Id) .a (.Bool -> .(.a -> .(*(PSt .l) -> *(.a,*(PSt .l))))) !*(PSt .l) -> *(PSt .l)
StopIntr :: !(.a,!Id) !*(PSt .l) -> *(PSt .l)
ContIntr :: !(.a,!Id) !*(PSt .l) -> *(PSt .l)
