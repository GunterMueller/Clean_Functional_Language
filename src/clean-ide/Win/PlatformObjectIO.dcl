definition module PlatformObjectIO

import StdPSt, StdString
import StdIOCommon

initPlatformCommandLineArguments:: !*(PSt .l) -> (![String],!*PSt .l)
installPlatformEventHandlers	:: !*(PSt .l) -> *(PSt .l)
openPlatformWindowMenu			:: !*(PSt .l) -> *(PSt .l)

getWindowModified :: !Id !(IOSt .l) -> (!Maybe Bool,!IOSt .l)
setWindowModified :: !Id !String !Bool !(IOSt .l) -> IOSt .l

pAbort :: !(PSt .a) -> PSt .a
