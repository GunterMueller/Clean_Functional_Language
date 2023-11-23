definition module guigecs

/**	In this module the 'standard' GECGUI creation functions are defined. 
	These functions are:
		basicGECGUI:	defines a GECGUI for parseable/printable types (useful as a leaf-editor),
		unitGECGUI:		defines a GECGUI for UNITs,
		pairGECGUI:		defines a GECGUI for PAIRs,
		eitherGECGUI:	defines a GECGUI for EITHERs,
		objectGECGUI:	defines a GECGUI for OBJECTs,
		consGECGUI:		defines a GECGUI for CONSs,
		fieldGECGUI:	defines a GECGUI for FIELDs.
	Note that the type of a GECGUI creation function for type T are all of the form:
		...arguments... -> GECGUIFun T (PSt .ps)
	This allows for easy customization for special instances, in particular basicGECGUI.
	They serve as plug-ins for the GEC infrastructure creation functions (see infragecs.dcl).
*/

import StdTuple
import gec
import GenParse, GenPrint, parseprint

/** Standard metrics that are used in the visual editor.
*/
defHMargins         :== (0,0);					hMarginAtt	:== ControlHMargin   (fst defHMargins)   (snd defHMargins)
defVMargins         :== (0,0);					vMarginAtt	:== ControlVMargin   (fst defVMargins)   (snd defVMargins)
//defItemSpaces       :== (4,3);					itemSpaceAtt:== ControlItemSpace (fst defItemSpaces) (snd defItemSpaces)
defItemSpaces       :== (0,0);					itemSpaceAtt:== ControlItemSpace (fst defItemSpaces) (snd defItemSpaces)
defTextWidths       :== defCellWidth
defCellWidth		:== 108			// divideable by 2,3,4
//defCellHeight		:== 24			// divideable by 2,3,4
defCellHeight		:== 19
defWindowBackColour :== LightGrey
defTextBackColour   :== RGB {r=160,g=160,b=215}

/**	The final type of every GECGUI creation function:
*/
::	GECGUIFun a env
	:== OutputOnly -> env -> *(GECGUI a env,env)
::	OutputOnly
	=	OutputOnly | Interactive
derive gEq OutputOnly

/** The visual components.
*/
basicGECGUI		:: !String !(SetValue t (PSt .ps))                -> GECGUIFun t            (PSt .ps) | parseprint t
unitGECGUI		::                                                   GECGUIFun UNIT         (PSt .ps)
pairGECGUI		::                                                   GECGUIFun (PAIR   a b) (PSt .ps)
eitherGECGUI	::                                                   GECGUIFun (EITHER a b) (PSt .ps)
objectGECGUI	:: !GenericTypeDefDescriptor 
				   !(            [ConsPos] (PSt .ps) -> (PSt .ps))
				   !(Arrangement [ConsPos] (PSt .ps) -> (PSt .ps))
				   !Bool                                          -> GECGUIFun (OBJECT a)   (PSt .ps)
consGECGUI		:: !GenericConsDescriptor                         -> GECGUIFun (CONS   a)   (PSt .ps)
fieldGECGUI		:: !GenericFieldDescriptor                        -> GECGUIFun (FIELD  a)   (PSt .ps)

/**	Customize GECGUI creation functions:
*/
/**	trivialGECGUIFun k :: GECGUIFun t (PSt .ps)
		takes the arity k of the type t for which a GECGUI needs to be created
		and simply passes all data through recursively.
		No GECGUI is created.
*/
trivialGECGUIFun :: !Int -> GECGUIFun t (PSt .ps)


/**	customGECGUIFun maybeOBJECTControlId recursive_components private_state gui_definition update
		defines a GECGUI creation function that will create a GECGUI that:
		(1) has a GUI given by gui_definition with local state given by private_state,
		(2) reserves layout-space for its recursive components. 
			These are identified by each (id,pos,pos`) in recursive_components, for which:
				id:		the identification value for that component,
				pos:	the layout-position of that component relative to (1),
				pos`:	the layout_position of elements in this component.
		(3) it may overrule the OBJECTControl that is passed by the infrastructure (this only makes sense for
			OBJECT instances, so this is usually Nothing),
		(4) it will update values set from the outside via update.
*/
customGECGUIFun :: (Maybe OBJECTControlId) 
				   [(Id,Maybe ItemPos,Maybe ItemPos)] 
				   ls 
				   (cdef ls (PSt .ps)) 
				   (t (PSt .ps) -> (PSt .ps)) 
				-> GECGUIFun t (PSt .ps) 
				|  Controls cdef
