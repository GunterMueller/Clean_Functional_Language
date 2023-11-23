/************************************************/
/* Module:	tooltip								*/
/* 												*/
/* Auteurs:	Coen Goedegebure, Tim Nieuwenhuis	*/
/*												*/
/* Datum:	14/07/00							*/
/*												*/
/************************************************/

implementation module tooltip

import StdEnv

import StdIO, wraptextcontrol, StdDebug

Vellum = RGB {r=200,g=225,b=255}

// Shows the tooltip on screen
ShowToolTip :: !Id Int Int String !*(PSt .l) -> *PSt .l
ShowToolTip id x y s ps
	# (ws,ps)		= accPIO (getWindowViewSize id) ps
	# (lh,ps)		= accPIO (accScreenPicture getH) ps
	# (lw,ps)		= accPIO (accScreenPicture (getW (s+++" "))) ps
	# wsize			= ws.w
	# hsize			= ws.h
	# x				= if ((lw+x > wsize ) && (wsize - lw >= 0)) (wsize - lw) (if (wsize - lw >=0) (x) (0))
    # width			= if (lw+x > wsize ) (wsize-x) (lw)
    # height		= (getLines s width lw)*lh
    # y				= if (y+lh + height > hsize) (if (y-height<0) (0) (y-height)) (y+lh)
	# (toolId,ps)	= openId ps
	# (timeId,ps)	= openId ps
	# (_,ps)		= openControls id Void ( WrapText s  
													[ ControlViewSize {w=width,h=height}
													, ControlPen [PenBack Vellum]
													, ControlPos (Fix,OffsetVector {vx=x,vy=y} )
													, ControlId toolId 
													]
												) ps
	# (_,ps) 		= openTimer Void (Timer (ticksPerSecond * 3) NilLS [TimerId timeId,TimerFunction (noLS1(\_ -> appPIO (closeTimer timeId o closeControls id [toolId] False )))]) ps
	= ps

// Returns the fontWidth 
getW s pic
	# (w,pic) = getPenFontStringWidth s pic
	= (w,pic)

// Returns the fontHeight
getH pic
	# (metrics,pic) = getPenFontMetrics pic
	# lh = fontLineHeight metrics
	= (lh,pic)

// Calculate the number of lines used in the tooltip
getLines :: String Int Int -> Int
getLines  s width l
	= ((l/width))
