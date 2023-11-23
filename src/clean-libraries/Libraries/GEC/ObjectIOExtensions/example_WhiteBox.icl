module example_WhiteBox

import StdEnv
import StdIO
import WhiteBox


Start world
	# (stdio,world)	= stdio world
	= startIO SDI stdio initGUI [ProcessClose closeProcess] world
where
	initGUI :: (PSt *File) -> PSt *File
	initGUI pSt
		# (wbId,pSt)	= openWhiteBoxId pSt
		# wbDef			= WhiteBox wbId (ButtonControl "Tell" [ControlFunction tell]) [ControlResize (\_ _ s -> s)]
		# wDef			= Window "Test WhiteBox..." wbDef [WindowViewSize {w=300,h=300}]
		# pSt			= snd (openWindow 0 wDef pSt)
		# mDef			= Menu "Test" (MenuItem "Add" [MenuFunction (noLS (add wbId)),MenuShortKey 'a']) []
		# pSt			= snd (openMenu undef mDef pSt)
		= pSt
	where
		add :: (WhiteBoxId Int) (PSt *File) -> PSt *File
		add wbId pSt
			= snd (openWhiteBoxControls wbId (ButtonControl "Button" [ControlPos (Center,zero),ControlFunction inc]) pSt)
		
		tell :: (Int,PSt *File) -> (Int,PSt *File)
		tell (c,pSt)
			= (c,appPLoc (fwrites (toString c+++"\n")) pSt)
		
		inc :: (Int,PSt *File) -> (Int,PSt *File)
		inc (c,pSt)
			= tell (c+1,pSt)
