implementation module texteditaccess


import	StdInt
import	textedit, pointer
import	ostoolbox

TEGetTextSize :: !TEHandle !*Toolbox -> (!Int,!*Toolbox)
TEGetTextSize hTE tb
#	(tePtr,tb)			= LoadLong hTE tb
	(size,tb)			= LoadWord (tePtr+teLengthOffset) tb
=	(size,tb)

destRectOffset		:== 0
viewRectOffset		:== 8

TESetDestRect :: !TEHandle !Rect !*Toolbox -> *Toolbox
TESetDestRect hTE rect tb
#	(tePtr,tb)			= LoadLong hTE tb
= StoreRect (tePtr+destRectOffset) rect tb

TESetViewRect :: !TEHandle !Rect !*Toolbox -> *Toolbox
TESetViewRect hTE rect tb
#	(tePtr,tb)			= LoadLong hTE tb
= StoreRect (tePtr+viewRectOffset) rect tb

StoreRect :: !Ptr !Rect !*Toolbox -> *Toolbox
StoreRect ptr (left,top, right,bottom) tb
	#	tb			= StoreWord ptr		top		tb
		tb			= StoreWord (ptr+2)	left	tb
		tb			= StoreWord (ptr+4)	bottom	tb
		tb			= StoreWord (ptr+6)	right	tb
	=	tb

