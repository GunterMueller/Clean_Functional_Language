definition module controlmousedown1


import	windowhandle
from	commondef	import IdFun
from	iostate		import PSt, IOSt


::	ControlMouseEvent
	=	{	cmePtr	:: !OSWindowPtr		// The WindowPtr of the window
		,	cmePos	:: !Point2			// The mouse position in local coordinates
		,	cmeWhen	:: !Int				// The when field of the original event
		,	cmeMods	:: !Int				// The mods field of the original event
		}


handleRadioControlMouse       :: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCheckControlMouse       :: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handlePopUpControlMouse       :: !ControlMouseEvent  Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleEditControlMouse        :: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleButtonControlMouse      :: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCustomButtonControlMouse:: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
handleCustomControlMouse      :: !ControlMouseEvent !Rect (IdFun *OSToolbox) !*KeyFocus !(WItemHandle .ls (PSt .l)) (.ls,PSt .l)
							  								   -> (!Bool, !*KeyFocus, !WItemHandle .ls (PSt .l), (.ls,PSt .l))
