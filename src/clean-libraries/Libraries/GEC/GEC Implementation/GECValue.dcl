definition module GECValue

import genericgecs
from   guigecs import defTextWidths, defWindowBackColour

openGECVALUE :: !(!GUILoc,!OBJECTControlId) !OutputOnly !Bool !(Maybe t) !(Update t (PSt .ps)) !(PSt .ps) -> (!GECVALUE t (PSt .ps),!PSt .ps) 
             |  gGEC{|*|} t & bimap{|*|} ps
