definition module gec

import StdControl, StdControlReceiver, StdReceiver
import guiloc, objectloc
import GenEq, GenPrint

/** GECId t
		is the abstract type that represents a visual editor component with which one can
		edit values of type t.
*/
::	GECId t

openGECId :: !*env -> (!GECId t,!*env) | Ids env

GECIdtoId :: !(GECId t) -> Id

instance == (GECId t)

isGECIdBound :: !(GECId t) !(IOSt .ps) -> (!Bool,!IOSt .ps)

derive bimap GECMsgIn, GECMsgOut

/** The messages the receiver responds to:    */
::	GECMsgIn t
	=	InGetValue								/** Request for current correct value of GEC by calling Update function. */
	|	InSetValue !IncludeUpdate t				/** Store and display value on GEC infrastructure.                       */
	|	InOpenGEC								/** Request to open the GEC infrastructure one step by a CONS editor.    */
	|	InCloseGEC								/** Close the GEC infrastructure.                                        */
	|	InOpenGUI !GUILoc !OBJECTControlId		/** Show this visual interface and proceed downwards.                    */
	|	InCloseGUI !KeepActiveCONS				/** Close this visual interface and proceed downwards.                   */
	|	InSwitchCONS !IncludeUpdate ![ConsPos]	/** Make given CONS path active.                                         */
	|	InArrangeCONS !Arrangement ![ConsPos]	/** Arrange given CONS.                                                  */
::	GECMsgOut t
	=	OutGetValue t							/** Reply to InGetValue request. Return current value.                   */
	|	OutDone									/** General reply to all other GECMsgIn requests.                        */
::	IncludeUpdate
	=	YesUpdate | NoUpdate
::	KeepActiveCONS								/** KeepActiveCONS:                                                      */
	=	SkipCONS								/** Do NOT modify consActive flag of CONS editor.                        */
	|	InactivateCONS							/** Set consActive flag of CONS editor to inactive.                      */
::	Arrangement									/** Arrangement:                                                         */
	=	ArrangeHide								/** Hide CONS.                                                           */
	|	ArrangeShow								/** Show CONS.                                                           */

derive gEq IncludeUpdate, KeepActiveCONS, Arrangement
derive gPrint ConsPos, Arrangement, IncludeUpdate

::	GECReceiver t ls pst
 =	GECReceiver (GECId t) (Receiver2Function (GECMsgIn t) (GECMsgOut t) *(ls,pst))

instance Controls  (GECReceiver t)
instance Receivers (GECReceiver t)


/**	Update t env
		is the function that must be evaluated to pass updated edited values.
*/
::	Update t env :== UpdateReason t env -> env
::	UpdateReason		// The reason why the update function is evaluated
	=	Enquire			// somebody wanted to know current value in GEC infrastructure
	|	Changed			// current value has been changed in GEC infrastructure

derive gEq UpdateReason

/** SetValue t env
		is the function that can be used to insert values into the value infrastructure.
*/
::	SetValue t env :== IncludeUpdate t env -> env

::	GECGUI t env
	=	{ guiLocs     :: (GUILoc,OBJECTControlId) -> [(GUILoc,OBJECTControlId)]
		, guiOpen     :: GUILoc env -> env
		, guiClose    ::   env -> env
		, guiUpdate   :: t env -> env
		}

::	GECVALUE t env
	=	{ gecOpen     ::                               env -> env // RWS not used ???
		, gecClose    ::                               env -> env
		, gecOpenGUI  :: (GUILoc,OBJECTControlId)   -> env -> env
		, gecCloseGUI :: KeepActiveCONS             -> env -> env
		, gecGetValue ::                               env -> *(t,   env)
		, gecSetValue :: SetValue t env
		, gecSwitch   :: IncludeUpdate -> [ConsPos] -> env -> env
		, gecArrange  :: Arrangement   -> [ConsPos] -> env -> env
		, gecOpened   ::                               env -> *(Bool,env)
		}
derive bimap GECVALUE

/**	openGECGUI guiLoc gecGUIfun gec pSt
		opens a GUI associated with the GEC indicated by gec. The GUI is defined by gecGUIfun.
	closeGECGUI gec pSt
		closes the GUI associated with the GEC indicated by gec.
*/
openGECGUI  :: !(GECId t) !(!GUILoc,!OBJECTControlId) !(PSt .ps) -> PSt .ps
closeGECGUI :: !(GECId t) !KeepActiveCONS !(PSt .ps) -> PSt .ps

/** closeGEC gec pSt
		closes the GEC completely indicated by gec. The boolean result is True iff this operation 
		was successful. 
*/
openGEC  :: !(GECId t) !(PSt .ps) -> PSt .ps
closeGEC :: !(GECId t) !(PSt .ps) -> PSt .ps

::	PropagationDirection = Up | Down

derive gEq PropagationDirection

getGECvalue		:: !(GECId t)                   !(PSt .ps) -> (t,!PSt .ps)
setGECvalue		:: !(GECId t) !IncludeUpdate !t !(PSt .ps) -> PSt .ps

/**	switchGEC gec yesUpdate path
		when sent to a EITHER root GEC, it will cause this particular constructor to be chosen
		as the `active' alternative of the value that is being edited.
		When sent to any other GEC, it will have no effect.
*/
switchGEC :: !(GECId t) !IncludeUpdate ![ConsPos] !(PSt .ps) -> PSt .ps

/** arrangeGEC gec arrangement path
		when sent to a EITHER root GEC, it will cause this particular constructor to be rearranged
		visually.
		When sent to any other GEC, it will have no effect.
*/
arrangeGEC :: !(GECId t) !Arrangement ![ConsPos] !(PSt .ps) -> PSt .ps
