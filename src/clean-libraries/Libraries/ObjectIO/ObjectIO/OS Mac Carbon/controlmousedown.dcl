definition module controlmousedown


import	windowhandle
from	commondef	import IdFun
from	iostate		import PSt, IOSt


//handleControlMouse :: !OSWindowPtr !Point2 !Int !Int !(WindowStateHandle (PSt .l)) !(PSt .l) -> (!Bool,!IdFun *OSToolbox,!PSt .l)
handleControlMouse :: !OSWindowPtr !Point2 !Int !Int !(WindowStateHandle (PSt .l)) !(WindowHandles (PSt .l)) !(PSt .l)
	-> (!Bool,!IdFun *OSToolbox,!PSt .l)
