implementation module StdObjectIOExt

import StdList, StdMisc
import iostate
import StdIO

//	Extension for Object I/O

/**	This function should be in StdControl.
*/
closeControl :: !Id !Bool !(IOSt .l) -> IOSt .l
closeControl id relayout ioSt
	= case getParentId id ioSt of
		(Just wId,ioSt)	= closeControls wId [id] relayout ioSt
		(nothing, ioSt)	= ioSt


getPopUpControlItemIndex :: !Id !String !(IOSt .ps) -> (!Index,!IOSt .ps)
getPopUpControlItemIndex popUpId text ioSt
	= accWState getItemIndex popUpId ioSt
where
	getItemIndex :: !WState -> Index
	getItemIndex wSt
		= case getPopUpControlItem popUpId wSt of
			(True,Just labels)
				= case span ((<>) text) labels of
					(uneq,[eq:_]) = length uneq + 1
					(uneq,[])     = 0
			wrong
				= 0

accWState :: !(WState -> .a) !Id !(IOSt .l) -> (.a,!IOSt .l)
accWState accFun id ioSt
	= case getWindow id ioSt of							// is id a top-level GUI object?
		(Just wSt,ioSt)	= (accFun wSt,ioSt)
		(nothing, ioSt)
			= case getParentWindow id ioSt of			// is id a child GUI object?
				(Just wSt,ioSt)	= (accFun wSt,ioSt)
				(nothing, ioSt)
					= (abort "accWState returned undefined value.",ioSt)

/**	This function should be in StdId.
*/
isIdBound :: !Id !(IOSt .ps) -> (!Bool,!IOSt .ps)
isIdBound id ioSt
	# (idTable,ioSt)= ioStGetIdTable ioSt
	# (yes,idTable)	= memberIdTable id idTable
	# ioSt			= ioStSetIdTable idTable ioSt
	= (yes,ioSt)
