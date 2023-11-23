definition module FontEnv

import StdPSt, StdPicture

class FontEnv env
where
	openDialogFontFE		:: !*env -> (!Font,		 !*env)
	openFontFE				:: !FontDef	!*env -> (!(!Bool,!Font),!*env)
	getFontStringWidthFE	:: ! String	 !Font		!*env -> (!Int,			 !*env)
	getFontStringWidthsFE	:: ! [String]	 !Font		!*env -> (![Int],			 !*env)
	getFontMetricsFE		:: !Font				!*env -> (!FontMetrics,	!*env)
//	accFontEnv :: (*Picture -> (a,*Picture)) -> EditMonad !*env a

instance FontEnv Picture
instance FontEnv (PSt .l)
instance FontEnv World
