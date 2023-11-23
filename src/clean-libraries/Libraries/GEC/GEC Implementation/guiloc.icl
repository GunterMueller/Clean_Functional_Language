implementation module guiloc

import StdBool, StdList, StdMisc, StdTuple
import StdControl, StdId, StdWindow

instance == GUILoc where
	(==) loc loc` = loc.guiId==loc`.guiId && fst loc.guiItemPos==fst loc`.guiItemPos

isTopLevelGUILoc :: !GUILoc !(IOSt .ps) -> (!Bool,!IOSt .ps)
isTopLevelGUILoc {guiId} ioSt
	= case getParentId guiId ioSt of
		(Just parentId,ioSt)	= (guiId == parentId,ioSt)
		(nothing,      ioSt)	= (False,ioSt)

inWindowGUILoc :: !GUILoc !(IOSt .ps) -> (!Maybe Bool,!IOSt .ps)
inWindowGUILoc {guiId} ioSt
	= case getParentId guiId ioSt of
		(Nothing,ioSt)					// No GUI bound to guiId
			= (Nothing,ioSt)
		(Just parentId,ioSt)			// parentId of parent GUI of guiId
			# (wids,ioSt)	= getWindowStack ioSt
			= case filter (\(wid`,_) -> wid`==parentId) wids of
				[(_,wkind):_]
					= (Just (wkind==windowkind),ioSt)
				neither_window_nor_dialog
					= (Nothing,ioSt)
where
	windowkind	= getWindowType (Window undef NilLS undef)

openControlsInGUILoc :: ls !(cDef ls (PSt .ps)) !GUILoc !(PSt .ps) -> PSt .ps | Controls cDef
openControlsInGUILoc ls cDef guiLoc=:{guiId,guiItemPos} pSt=:{io}
	= case inWindowGUILoc guiLoc io of
		(Nothing,io)
			= abort ("openControlsInGUILoc: invalid GUILoc argument.\n")
		(Just inWindow,io)
			# (toplevel,io)	= isTopLevelGUILoc guiLoc io
			# (topId,   io) = openId io
			# pSt			= {pSt & io=io}
			| toplevel
				= case openControls          guiId ls (wrapControls topId guiItemPos cDef) pSt of
					(NoError,pSt)	= pSt
					(error,  pSt)	= abort ("openControlsInGUILoc: could not open controls in Window/Dialog: "+++toString error)
			| otherwise
				= case openRecursiveControls guiId ls (wrapControls topId guiItemPos cDef) pSt of
					(NoError,pSt)	= pSt
					(error,  pSt)	= abort ("openControlsInGUILoc: could not open controls in recursive control: "+++toString error)
where
	wrapControls :: !Id !ItemPos !(cDef .ls .pst) -> LayoutControl cDef .ls .pst | Controls cDef
	wrapControls topId itemPos cDef
		= LayoutControl cDef [ControlId topId,ControlPos itemPos]
