definition module UtilObjectIO

import StdString, StdFile
import StdPSt, StdMaybe, StdPictureDef, StdId
import UtilDate

selectInputFile` :: !(PSt .l) -> (!Maybe String,!(PSt .l))
selectOutputFile` :: !String !String !String !(PSt .l) -> (!Maybe String,!(PSt .l))
selectDirectory`		:: !(PSt .l) -> (!Maybe String,!(PSt .l))
ShellDefault :: !{#Char} !(PSt .l) -> (!Int,!(PSt .l))

GetDialogBackgroundColour	:: !(PSt .l) -> (!Colour, !PSt .l)
isWindow :: !Id *(PSt .l) -> (Bool,*(PSt .l))

LaunchApplication :: !{#Char} !{#Char} !Bool !Files -> ( !Bool, !Files)
LaunchApplication` :: !{#Char} !Bool !Files -> ( !Bool, !Files)
