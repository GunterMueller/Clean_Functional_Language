definition module WhiteBox

import StdControl, StdId

::	WhiteBox gui ls pst
 =	WhiteBox (WhiteBoxId ls) (gui ls pst) [ControlAttribute *(ls,pst)]

::	WhiteBoxId ls // = WhiteBoxId !Id

openWhiteBoxId :: !*env -> (!WhiteBoxId .ls,!*env) | Ids env

whiteBoxIdtoId :: !(WhiteBoxId .ls) -> Id

instance Controls (WhiteBox cDef) | Controls cDef

openWhiteBoxControls :: !(WhiteBoxId .ls) .(cdef .ls (PSt .l)) !(PSt .l) -> (!ErrorReport,!PSt .l) | Controls cdef
