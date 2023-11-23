definition module flextextcontrol

import StdControlClass, StdId

:: FlexText ls ps
	= FlexText String FlexId [ControlAttribute *(ls,ps)]

instance Controls FlexText

openFlexId		:: !*env -> (!FlexId,!*env) | Ids env

setFlexTexts	:: ![(FlexId, String)] !*(PSt .l) -> *PSt .l
setFlexPens		:: ![(FlexId,FlexPen)] !*(PSt .l) -> *PSt .l
addFlexPens		:: ![(FlexId,FlexPen)] !*(PSt .l) -> *PSt .l

:: FlexId //:== R2Id FlexMessage FlexReply

:: FlexMessage
	= FlexTextSet String
	| FlexTextGet
	| FlexPenSet FlexPen
	| FlexPenGet

:: FlexPen :== [PenAttribute]

:: FlexReply
	= FlexTextOK String
	| FlexPenOK FlexPen
