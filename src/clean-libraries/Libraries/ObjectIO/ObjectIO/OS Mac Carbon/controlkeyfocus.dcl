definition module controlkeyfocus


import	windowhandle
from	commondef	import	IdFun


getDeactivateKeyInputItem :: !OSWindowPtr !Rect !*KeyFocus !Point2 ![WElementHandle .ls .ps]
											-> (!*KeyFocus,!IdFun *OSToolbox,![WElementHandle .ls .ps])
