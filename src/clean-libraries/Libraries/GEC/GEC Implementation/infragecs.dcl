definition module infragecs

import testable
import parseprint, guigecs

::	GECArgs t env										// The arguments to define a GEC:
	=	{	location	:: !(!GUILoc,!OBJECTControlId)	// a legal value of an existing GUI component in which this GEC is to be created.
		,	makeUpValue	:: !MakeUpValue					// for internal purposes. This value must be True.
	    ,   outputOnly	:: !OutputOnly					// the GEC is for output purposes only (True) or can be edited by the user (False).
	    ,	gec_value	:: !.Maybe t					// the optional initial value of type t that will be created.
		,	update		:: !(Update t env)				// the interface function that a program can use to obtain information from
														// the GEC at run-time without the need for polling.
		,	hasOBJECT	:: !Bool						// create interface element to select data constructors (True) or do not create (False).
		}

derive bimap GECArgs

/**	In this module the 'standard' GEC infrastructure creation functions are defined. 
	These functions are:
		unitGEC:	defines the infrastructure for UNITs,
		pairGEC:	defines the infrastructure for PAIRs,
		objectGEC:	defines the infrastructure for OBJECTs,
		consGEC:	defines the infrastructure for CONSs,
		fieldGEC:	defines the infrastructure for FIELDs.
		eitherGEC:	defines the infrastructure for EITHERs,
		basicGEC:	defines the infrastructure for parseable/printable types (useful as a leaf-editor),
	The (GECGUIFun t env) argument of each function defines the GECGUI of this particular component (see guigecs.dcl).
*/

::	TgGEC a env
	:== ((GECArgs a env)
     -> .(env 
     -> *(!GECVALUE a env,!env)))
::	MakeUpValue	:== Bool

unitGEC   ::                         !(GECGUIFun UNIT         (PSt .ps))                      -> TgGEC UNIT         (PSt .ps)
pairGEC   ::                         !(GECGUIFun (PAIR a b)   (PSt .ps)) !(TgGEC a (PSt .ps)) 
                                                                         !(TgGEC b (PSt .ps)) -> TgGEC (PAIR   a b) (PSt .ps)
objectGEC :: !GenericTypeDefDescriptor 
             !(GECId (OBJECT a))     !(GECGUIFun (OBJECT a)   (PSt .ps)) !(TgGEC a (PSt .ps)) -> TgGEC (OBJECT a)   (PSt .ps)
consGEC   :: !GenericConsDescriptor  !(GECGUIFun (CONS   a)   (PSt .ps)) !(TgGEC a (PSt .ps)) -> TgGEC (CONS   a)   (PSt .ps)
fieldGEC  :: !GenericFieldDescriptor !(GECGUIFun (FIELD  a)   (PSt .ps)) !(TgGEC a (PSt .ps)) -> TgGEC (FIELD  a)   (PSt .ps)
eitherGEC ::                         !(GECGUIFun (EITHER a b) (PSt .ps)) !(TgGEC a (PSt .ps))
                                                                         !(TgGEC b (PSt .ps)) -> TgGEC (EITHER a b) (PSt .ps)
basicGEC  :: !String !(GECId t)      !(GECGUIFun t            (PSt .ps))                      -> TgGEC t            (PSt .ps)
          |  parseprint    t 
          &  ggen {|*|} t
