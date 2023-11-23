definition module objectloc

import StdControlClass, StdId
import gec

::	OBJECTControlId

openOBJECTControlId :: !*env -> (!OBJECTControlId,!*env) | Ids env

::	OBJECTControl ls pst
 =	OBJECTControl OBJECTControlId 
	              GenericTypeDefDescriptor
	              (            [ConsPos] pst -> pst)
	              (Arrangement [ConsPos] pst -> pst)
	              Bool
	              [ControlAttribute *(ls,pst)]

instance Controls OBJECTControl

selectOBJECTControlItem :: !OBJECTControlId !Index !(PSt .ps) -> PSt .ps
