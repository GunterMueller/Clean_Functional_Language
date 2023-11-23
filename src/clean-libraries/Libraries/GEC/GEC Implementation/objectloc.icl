implementation module objectloc

import StdBool, StdList, StdMisc, StdTuple
import StdControl, StdControlAttribute, StdControlReceiver, StdId, StdPSt
import guigecs
import ColourTextControl

::	OBJECTControlId
	=	{	objectId :: !Id
		,	colId    :: !ColourTextControlId
		,	recId    :: !RId Int
		}

openOBJECTControlId :: !*env -> (!OBJECTControlId,!*env) | Ids env
openOBJECTControlId env
	# (id, env)	= openId                  env
	# (cid,env) = openColourTextControlId env
	# (rid,env) = openRId                 env
	= ({objectId=id,colId=cid,recId=rid},env)

instance Controls OBJECTControl where
	controlToHandles objControl=:(OBJECTControl _ _ _ _ _ atts) pSt
		= case filter isControlSelectState atts of
			[ControlSelectState Unable:_]			// This object should be represented as a colour text control
				= uneditableOBJECTControl objControl pSt
			enabled									// This object should be represented as a pop up control
				= editableOBJECTControl objControl pSt
	getControlType _
		= "OBJECTControl"

/** An uneditable OBJECTControl is a ColourTextControl that can be modified by the program only.
*/
uneditableOBJECTControl (OBJECTControl {colId,recId} gtd switchFun arrangeFun createOBJECTControl atts) pSt
	| createOBJECTControl
		= controlToHandles impl pSt
	| otherwise
		= ([],pSt)
where
	conses		= gtd.gtd_conses
	consNames	= [gtd_cons.gcd_name \\ gtd_cons <- conses]
	impl		=     ColourTextControl colId "" defTextBackColour 
						[ ControlViewSize {w=defCellWidth,h=defCellHeight}//ControlWidth (PixelWidth defTextWidths)
						: atts
						]
				  :+: Receiver recId handleMsg []
	
	handleMsg :: Int (.ls,PSt .ps) -> (.ls,PSt .ps)
	handleMsg i (lSt,pSt)
		= (lSt,setColourTextControlText colId (consNames!!(i-1)) pSt)

/**	An editable OBJECTControl is a PopUpControl that can be selected by the user, and modified by the program.
*/
editableOBJECTControl (OBJECTControl {objectId,recId} gtd switchFun arrangeFun createOBJECTControl atts) pSt
	= controlToHandles impl pSt
where
	conses	= gtd.gtd_conses
	index0	= 1
	impl	= { addLS = index0
			  , addDef= ListLS (repeatn n (
			  			    PopUpControl
			                   (  [  (gtd_cons.gcd_name, \((_,lSt),pSt) -> ((index,lSt),switchFun (getConsPath gtd_cons) pSt))
			                      \\ gtd_cons <- conses & index <- [1..]
			                      ]
			                   ++ [  ("Hide...",arrange arrangeFun ArrangeHide)
			                      ,  ("Show...",arrange arrangeFun ArrangeShow)
			                      ]
			                   )
			                   index0 
			                   [ ControlId    objectId
			                   , ControlWidth (PixelWidth defTextWidths)
			                   : map liftControlAttribute atts
			                   ]
			            ))
			            :+: Receiver recId handleMsg []
			  }
	n		= if createOBJECTControl 1 0
	
	handleMsg :: Int (.(Int,.ls),PSt .ps) -> (.(Int,.ls),PSt .ps)
	handleMsg i ((_,lSt),pSt)
		= ((i,lSt),appPIO (selectPopUpControlItem objectId i) pSt)
	
	arrange :: (Arrangement [ConsPos] (PSt .ps) -> (PSt .ps)) Arrangement (.(Int,.ls),PSt .ps) -> (.(Int,.ls),PSt .ps)
	arrange arrangeFun arr ((i,lSt),pSt)
		# pSt	= arrangeFun arr (getConsPath (conses!!(i-1))) pSt
		= case accPIO (getParentWindow objectId) pSt of
			(Nothing,pSt)
				= fatalError ("arrange ... "+++printToString arr) "objectloc" "parent window could not be found."
			(Just wSt,pSt)
				= case getPopUpControlItem objectId wSt of
					(True,Just texts)
						# (before,[text:after])
									= splitAt (i-1) texts
						# new_text	= if (arr===ArrangeHide) (safeAppend ellipsis text) (safeRemove ellipsis text)
				//		# pSt		= appPIO (setPopUpControlItemTexts objectId (before++[new_text:after])) pSt		PA: not yet implemented
						# pSt		= appPIO (selectPopUpControlItem objectId i) pSt
						= ((i,lSt),pSt)
					wrong_result
						= fatalError ("arrange ... "+++printToString arr) "objectloc" "item entries could not be found."
	where
		ellipsis	= "..."
		
		safeAppend :: !String !String -> String
		safeAppend suffix text
			| size_text > size_suffix && text%(size_text-size_suffix,size_text-1) == suffix
				= text
			| otherwise
				= text +++ suffix
		where
			size_text	= size text
			size_suffix	= size suffix
		
		safeRemove :: !String !String -> String
		safeRemove suffix text
			| size_text > size_suffix && text%(size_text-size_suffix,size_text-1) == suffix
				= text%(0,size_text-size_suffix-1)
			| otherwise
				= text
		where
			size_text	= size text
			size_suffix	= size suffix

selectOBJECTControlItem :: !OBJECTControlId !Index !(PSt .ps) -> PSt .ps
selectOBJECTControlItem {recId} i pSt
	= snd (syncSend recId i pSt)

liftControlAttribute :: !(ControlAttribute *(.ls,.pst)) -> ControlAttribute *(.(.new,.ls),.pst)
liftControlAttribute (ControlActivate     f) = ControlActivate   (lift f)
liftControlAttribute (ControlDeactivate   f) = ControlDeactivate (lift f)
liftControlAttribute (ControlFunction     f) = ControlFunction   (lift f)
liftControlAttribute  ControlHide            = ControlHide
liftControlAttribute (ControlId           x) = ControlId         x
liftControlAttribute (ControlKeyboard x y f) = ControlKeyboard x y (lift1 f)
liftControlAttribute (ControlMinimumSize  x) = ControlMinimumSize x
liftControlAttribute (ControlModsFunction f) = ControlModsFunction (lift1 f)
liftControlAttribute (ControlMouse    x y f) = ControlMouse    x y (lift1 f)
liftControlAttribute (ControlPen          x) = ControlPen      x
liftControlAttribute (ControlPos          x) = ControlPos      x
liftControlAttribute (ControlResize       f) = ControlResize   f
liftControlAttribute (ControlSelectState  x) = ControlSelectState x
liftControlAttribute (ControlTip          x) = ControlTip      x
liftControlAttribute (ControlWidth        x) = ControlWidth    x
liftControlAttribute (ControlHMargin    x y) = ControlHMargin x y
liftControlAttribute (ControlHScroll      f) = ControlHScroll  f
liftControlAttribute (ControlItemSpace  x y) = ControlItemSpace x y
liftControlAttribute (ControlLook       x f) = ControlLook      x f
liftControlAttribute (ControlOrigin       x) = ControlOrigin    x
liftControlAttribute (ControlOuterSize	  x) = ControlOuterSize x
liftControlAttribute (ControlViewDomain   x) = ControlViewDomain x
liftControlAttribute (ControlViewSize     x) = ControlViewSize   x
liftControlAttribute (ControlVMargin    x y) = ControlVMargin  x y
liftControlAttribute (ControlVScroll      f) = ControlVScroll   f

lift f ((new,ls),pst)
	# (ls,pst) = f (ls,pst)
	= ((new,ls),pst)
lift1 f x ((new,ls),pst)
	# (ls,pst) = f x (ls,pst)
	= ((new,ls),pst)

fatalError :: !String !String !String -> .x
fatalError rule moduleName error
	= abort ("Fatal error in rule "+++rule+++" ["+++moduleName+++"]: "+++error+++".\n")
