definition module StdObjectIOExt

import StdIO

/**	This function should be in StdControl.
*/
closeControl :: !Id !Bool !(IOSt .l) -> IOSt .l
getPopUpControlItemIndex :: !Id !String !(IOSt .ps) -> (!Index,!IOSt .ps)
accWState :: !(WState -> .a) !Id !(IOSt .l) -> (.a,!IOSt .l)

/**	This function should be in StdId.
*/
isIdBound :: !Id !(IOSt .ps) -> (!Bool,!IOSt .ps)
