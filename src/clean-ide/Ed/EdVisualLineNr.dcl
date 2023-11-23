definition module EdVisualLineNr

import StdIOCommon, EdMonad

vDrawLineNrs :: !FontInfo !Text !ViewFrame ![Rectangle] -> (*Picture -> *Picture)
