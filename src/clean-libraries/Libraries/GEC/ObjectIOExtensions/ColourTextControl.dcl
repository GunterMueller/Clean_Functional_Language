definition module ColourTextControl

import StdControlClass, StdId

::	ColourTextControl ls pst
 =	ColourTextControl ColourTextControlId String Colour [ControlAttribute *(ls,pst)]
::	ColourTextControlId

instance Controls ColourTextControl

openColourTextControlId :: !*env -> (!ColourTextControlId,!*env) | Ids env

getColourTextControlText :: !ColourTextControlId !(PSt .ps) -> (!Maybe String,!PSt .ps)
setColourTextControlText :: !ColourTextControlId !String !(PSt .ps) -> PSt .ps
