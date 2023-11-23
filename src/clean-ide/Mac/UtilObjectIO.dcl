definition module UtilObjectIO

/* OS dependent module */

/* Primitives which 'should be' in the standard CLEAN IO lib */

import StdString, StdFile
import UtilDate
import StdPSt, StdMaybe, StdPictureDef, StdId

selectInputFile`		:: !(PSt .l) -> (!Maybe String,!(PSt .l))
selectOutputFile`		:: !String !String !String !(PSt .l) -> (!Maybe String,!(PSt .l))
selectDirectory`		:: !(PSt .l) -> (!Maybe String,!(PSt .l))
ShellDefault :: !{#Char} !(PSt .l) -> (!Int,!(PSt .l))

GetDialogBackgroundColour :: !(PSt .l) -> (!Colour, !PSt .l)
isWindow :: !Id *(PSt .l) -> (Bool,*(PSt .l))
