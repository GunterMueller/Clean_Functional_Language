implementation module GECValue

import genericgecs

openGECVALUE :: !(!GUILoc,!OBJECTControlId) !OutputOnly !Bool !(Maybe t) !(Update t (PSt .ps)) !(PSt .ps) -> (!GECVALUE t (PSt .ps),!PSt .ps)
             |  gGEC{|*|} t & bimap{|*|} ps
openGECVALUE position outputOnly hasOBJECT initValue valueUpdate pSt
	= gGEC{|*|} {location=position, makeUpValue=True, outputOnly=outputOnly,gec_value=initValue,update=valueUpdate,hasOBJECT=hasOBJECT} pSt
