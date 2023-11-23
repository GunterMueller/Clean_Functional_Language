implementation module FontEnv

import StdPicture, StdPSt

class FontEnv env
where
	openDialogFontFE			::			!*env -> (!Font,		 !*env)
	openFontFE				:: !FontDef	!*env -> (!(!Bool,!Font),!*env)
	getFontStringWidthFE	:: ! String	 !Font		!*env -> (!Int,			 !*env)
	getFontStringWidthsFE	:: ! [String]	 !Font		!*env -> (![Int],			 !*env)
	getFontMetricsFE		:: !Font				!*env -> (!FontMetrics,	!*env)
//	accFontEnv :: (*Picture -> (a,*Picture)) -> EditMonad !*env a

instance FontEnv Picture
where
	openDialogFontFE e			= openDialogFont e
	openFontFE f e				= openFont f e
	getFontStringWidthFE s f e	= getFontStringWidth f s e
	getFontStringWidthsFE s f e	= getFontStringWidths f s e
	getFontMetricsFE f e		= getFontMetrics f e

instance FontEnv (PSt .l)
where
	openDialogFontFE e			= accPIO (accScreenPicture (openDialogFont)) e
	openFontFE f e				= accPIO (accScreenPicture (openFont f)) e
	getFontStringWidthFE s f e	= accPIO (accScreenPicture (getFontStringWidth f s)) e
	getFontStringWidthsFE s f e	= accPIO (accScreenPicture (getFontStringWidths f s)) e
	getFontMetricsFE f e		= accPIO (accScreenPicture (getFontMetrics f)) e

instance FontEnv World where
	openDialogFontFE e			=  (accScreenPicture (openDialogFont)) e
	openFontFE f e				=  (accScreenPicture (openFont f)) e
	getFontStringWidthFE s f e	=  (accScreenPicture (getFontStringWidth f s)) e
	getFontStringWidthsFE s f e	=  (accScreenPicture (getFontStringWidths f s)) e
	getFontMetricsFE f e		=  (accScreenPicture (getFontMetrics f)) e
