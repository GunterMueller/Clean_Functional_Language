implementation module wraptextcontrol

import StdEnv, StdIO

//Start = splitwords "zin met vier woorden"

:: WrapText ls ps = WrapText String [ControlAttribute *(ls,ps)]

instance Controls WrapText
where
	getControlType _ = "WrapText"
	controlToHandles (WrapText text atts) ps
		# (w,ps) = accPIO (accScreenPicture detw) ps
		# (h,ps) = deth ps
		# wid = if (isNothing sAtt) w ((fromJust sAtt).w)
		# hgt = if (isNothing sAtt) h ((fromJust sAtt).h)
		# siz = {w = wid, h = hgt}
		= controlToHandles (imp siz) ps
	where
		wtext = splitwords text
		imp	size = CustomControl size look atts
		look sel {newFrame} pic
			# pic			= unfill newFrame pic
			# wid			= newFrame.corner2.x - newFrame.corner1.x
			# (met,pic)		= getPenFontMetrics pic
			# pic			= setPenPos {zero & y = met.fLeading + met.fAscent} pic
			# (wwdth,pic)	= getPenFontStringWidths wtext pic
			# (sp,pic)		= getPenFontStringWidth " " pic
			# wtext			= zip2 wtext wwdth
			# stext			= wrap wtext sp wid
			# pic			= drawWT 0 (fontLineHeight met) stext pic
			= pic
		sAtt	= getSizeAtt atts
		detw pic
			# (fnt,pic)	= openDefaultFont pic
			# (wid,pic)	= getFontStringWidth fnt text pic
			= (wid,pic)
		deth ps
			# (siz,ps)	= controlSize (TextControl "" []) True Nothing Nothing Nothing ps
			# hgt		= siz.h
			= (hgt,ps)

getSizeAtt [] = Nothing
getSizeAtt [ControlViewSize s:_] = Just s
getSizeAtt [_:atts] = getSizeAtt atts

splitwords :: String -> [String]
splitwords string
	= splitwords 0
where
	splitwords i
		| i >= l = []
		# (s,r) = scanword i
//		| s == r = []
		= [string%(i,s):splitwords r]
	l = size string
	scanword x
		| x >= l = (dec l,l)
		| string.[x] == ' '
			= (dec x,scanspace x)
		= scanword (inc x)
	scanspace x
		| x >= l = l
		| string.[x] == ' '
			= scanspace (inc x)
		= x
			
wrap :: .[(String,Int)] Int Int -> [String]
wrap [] _ _ = []
wrap list sp width
	#	list = exp list 0
		(h,t)	= span (\(_,_,w)->w<width) list
		// moet hier wat doen voor het geval eerste string te breed... flextext of zo...
	#!	(h,t) = if (isEmpty h) (splitAt 1 t) (h,t)	// (abort "Word too long in string to be wrapped!") h
	#	h		= map fst3 h
		h		= foldl (\l r -> l +++ " " +++ r) "" h
		t		= map (\(s,w,_)->(s,w)) t
		t		= wrap t sp width
	= [h:t]
where
	exp [] _ = []
	exp [(s,w):t] x = [(s,w,x+w): exp t (x+w+sp)]



drawWT _ _ [] picture = picture
drawWT x dy [line:text] picture
	#	picture			= draw line picture
		(pos,picture)	= getPenPos picture
		dx				= x - (pos.x)
		picture			= movePenPos {vx = dx, vy = dy} picture
	= drawWT x dy text picture

