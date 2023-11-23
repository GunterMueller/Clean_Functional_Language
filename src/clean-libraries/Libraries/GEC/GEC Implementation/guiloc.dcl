definition module guiloc

import StdControlClass, StdIOCommon, StdId

/**	GUILoc defines all possible locations for a Visual Editor Component:
*/
::	GUILoc								/** GUILoc identifies a GUI location:                                    */
	=	{	guiId		:: !Id			/** when opened, this id must refer to an opened Window/Dialog/Control.  */
		,	guiItemPos	:: !ItemPos		/**	when opened, this is the (valid!) layout location.                   */
		}

//	Access operations on GUILoc values:

instance == GUILoc

/**	inWindowGUILoc guiLoc ioSt
		returns:
			Nothing: iff guiLoc indicates a non-existing top-level window/dialog.
			Just b: b holds iff top-level window/dialog exists and is a window.
*/
inWindowGUILoc :: !GUILoc !(IOSt .ps) -> (!Maybe Bool,!IOSt .ps)

/**	openControlsInGUILoc ls cDef guiLoc pSt
		creates the controls as defined by cDef with initial logical state ls in the GUI component identified
		by guiLoc.
*/
openControlsInGUILoc :: ls !(cDef ls (PSt .ps)) !GUILoc !(PSt .ps) -> PSt .ps | Controls cDef
