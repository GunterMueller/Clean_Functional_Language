implementation module ColourTextControl

import StdBool, StdInt, StdList, StdMisc
import StdControl, StdControlAttribute, StdControlReceiver, StdId, StdPicture, StdReceiver, StdPSt

::	ColourTextControlId
	=	{	r2Id :: !R2Id MsgIn MsgOut
		,	cId  :: !Id
		}
::	MsgIn  = GetTextIn          | SetTextIn !String
::	MsgOut = GetTextOut !String | SetTextOut

instance Controls ColourTextControl where
	controlToHandles (ColourTextControl {r2Id,cId} txt colour atts) pSt
	//	# (size,pSt)		= controlSize (PopUpControl [] 1 atts) True Nothing Nothing Nothing pSt
		# (size,pSt)		= getSize atts pSt
		# ((font,metrics),pSt)
							= accPIO (accScreenPicture getFontInfo) pSt
		= controlToHandles (impl size metrics font) pSt
	where
		getSize atts pSt
			= case filter (\att -> isControlOuterSize att || isControlViewSize att) atts of
				[ControlOuterSize s : _] = (s,pSt)
				[ControlViewSize  s : _] = (s,pSt)
				nothing                  = controlSize (PopUpControl [] 1 atts) True Nothing Nothing Nothing pSt
		impl size metrics font
							= { addLS = txt
							  , addDef=		CustomControl size (look  txt)
												[ ControlPen         [PenFont font,PenBack colour]
												, ControlSelectState Unable
												, ControlId          cId
												: map liftControlAttribute atts
												]
										:+: Receiver2 r2Id receiverFun []
							  }
		where
			look txt _ {newFrame} picture
				# picture	= unfill newFrame picture
				# picture	= setPenColour Black picture
				# picture	= draw newFrame picture
				# picture	= setPenColour White picture
				# picture	= drawAt {x=0,y=h-1} {vx=w,vy=0} picture
				# picture	= drawAt {x=w-1,y=h-1} {vx=0,vy= ~h} picture
				# picture	= setPenColour Black picture
				# picture	= drawAt {x=metrics.fMaxWidth/2,y=h-(h-(fontLineHeight metrics))/2-metrics.fDescent} txt picture
				= picture
			where
				{w,h}		= rectangleSize newFrame
			
			receiverFun :: !MsgIn !((String,.ls),PSt .ps) -> (!MsgOut,!((String,.ls),PSt .ps))
			receiverFun GetTextIn ((txt,lSt),pSt)
				= (GetTextOut txt,((txt,lSt),pSt))
			receiverFun (SetTextIn txt) ((_,lSt),pSt)
				# pSt		= appPIO (setControlLook cId True (True,look txt)) pSt
				= (SetTextOut,((txt,lSt),pSt))
			
			liftControlAttribute :: !(ControlAttribute *(.ls,.pSt)) -> ControlAttribute *(.(.add,.ls),.pSt)
			liftControlAttribute (ControlActivate     f)       = ControlActivate   (liftFun f)
			liftControlAttribute (ControlDeactivate   f)       = ControlDeactivate (liftFun f)
			liftControlAttribute (ControlFunction     f)       = ControlFunction   (liftFun f)
			liftControlAttribute  ControlHide                  = ControlHide
			liftControlAttribute (ControlId           x)       = ControlId x
			liftControlAttribute (ControlKeyboard     kf st f) = ControlKeyboard kf st (lift2Fun f)
			liftControlAttribute (ControlMinimumSize  x)       = ControlMinimumSize x
			liftControlAttribute (ControlModsFunction f)       = ControlModsFunction   (lift2Fun f)
			liftControlAttribute (ControlMouse        mf st f) = ControlMouse    mf st (lift2Fun f)
			liftControlAttribute (ControlPen          x)       = ControlPen         x
			liftControlAttribute (ControlPos          x)       = ControlPos         x
			liftControlAttribute (ControlResize       f)       = ControlResize      f
			liftControlAttribute (ControlSelectState  x)       = ControlSelectState x
			liftControlAttribute (ControlTip          x)       = ControlTip         x
			liftControlAttribute (ControlWidth        x)       = ControlWidth       x
			liftControlAttribute (ControlHMargin      x y)     = ControlHMargin   x y
			liftControlAttribute (ControlHScroll      f)       = ControlHScroll   f
			liftControlAttribute (ControlItemSpace    x y)     = ControlItemSpace x y
			liftControlAttribute (ControlLook         x f)     = ControlLook      x f
			liftControlAttribute (ControlOrigin       x)       = ControlOrigin      x
			liftControlAttribute (ControlOuterSize    x)       = ControlOuterSize   x
			liftControlAttribute (ControlViewDomain   x)       = ControlViewDomain  x
			liftControlAttribute (ControlViewSize     x)       = ControlViewSize    x
			liftControlAttribute (ControlVMargin      x y)     = ControlVMargin   x y
			liftControlAttribute (ControlVScroll      f)       = ControlVScroll     f
			
			liftFun  f   ((add,ls),pSt) = let (ls`,pSt`) = f   (ls,pSt) in ((add,ls`),pSt`)
			lift2Fun f x ((add,ls),pSt) = let (ls`,pSt`) = f x (ls,pSt) in ((add,ls`),pSt`)
		
		getFontInfo picture
			# (font, picture)	= openDialogFont picture
			# picture			= setPenFont font picture
			# (metrics,picture)	= getPenFontMetrics picture
			= ((font,metrics),picture)
	getControlType _
		= "ColourTextControl"

openColourTextControlId :: !*env -> (!ColourTextControlId,!*env) | Ids env
openColourTextControlId env
	# (r2id,env)	= openR2Id env
	# (cId, env)	= openId   env
	= ({r2Id=r2id,cId=cId},env)

getColourTextControlText :: !ColourTextControlId !(PSt .ps) -> (!Maybe String,!PSt .ps)
getColourTextControlText {r2Id} pSt
	= case syncSend2 r2Id GetTextIn pSt of
		((SendOk,Just (GetTextOut str)),pSt) = (Just str,pSt)
		(unexpectedAnswer,              pSt) = abort "getColourTextControlText: unexpected reply."

setColourTextControlText :: !ColourTextControlId !String !(PSt .ps) -> PSt .ps
setColourTextControlText {r2Id} txt pSt
	= case syncSend2 r2Id (SetTextIn txt) pSt of
		((SendOk,Just SetTextOut),pSt) = pSt
		(unexpectedAnswer,        pSt) = abort "setColourTextControlText: unexpected reply."
