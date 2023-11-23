implementation module wraptextcontrol

import StdEnv, StdIO, StdDebug

//Start = splitwords "zin met vier woorden"

:: WrapText ls ps = WrapText String [ControlAttribute *(ls,ps)]

instance Controls WrapText
where
	getControlType _ = "WrapText"
	controlToHandles (WrapText text atts) ps
		# (w,ps) = accPIO (accScreenPicture detw) ps
		# (h`,ps) = accPIO (accScreenPicture (deth` w)) ps
		# (h,ps) = deth ps
		# wid = if (isNothing sAtt) w ((fromJust sAtt).w)
		# hgt = if (isNothing sAtt) h ((fromJust sAtt).h)
		# siz = {w = wid, h = h`}//hgt}
		= controlToHandles (imp siz) ps
	where
		texts = splitlines text
		wtexts = map splitwords texts
		imp	size = CustomControl size look atts
		look sel {newFrame} pic
			# pic			= unfill newFrame pic
			# wid			= newFrame.corner2.x - newFrame.corner1.x
			# (met,pic)		= getPenFontMetrics pic
			# pic			= setPenPos {zero & y = met.fLeading + met.fAscent} pic
			# (sp,pic)		= getPenFontStringWidth " " pic
/*
			# (wwdths,pic)	= seqlist getPenFontStringWidths wtexts pic
			# wtext			= zip2 wtext wwdth
			# stext			= wrap wtext sp wid
*/			
			# (stexts,pic) = seqlist (wtext2stext sp wid) wtexts pic
			# stext = flatten stexts

			# pic			= drawWT 0 (fontLineHeight met) stext pic
			= pic
		wtext2stext sp wid wtext pic
			# (wwdth,pic)	= getPenFontStringWidths wtext pic
			# wtext			= zip2 wtext wwdth
			# stext			= wrap wtext sp wid
			= (stext,pic)
		sAtt	= getSizeAtt atts
		detw pic
			# (fnt,pic)	= openDefaultFont pic
			# (wids,pic)	= seqlist (getFontStringWidth fnt) texts pic
			# wid = maxlist wids
			= (wid,pic)
		maxlist [] = 0
		maxlist [h:t] = max h (maxlist t)
		deth` wid pic
			# (sp,pic)		= getPenFontStringWidth " " pic
			# (stexts,pic) = seqlist (wtext2stext sp wid) wtexts pic
			# stext = flatten stexts
			# (met,pic)		= getPenFontMetrics pic
			= (length stext * (fontLineHeight met),pic)
		seqlist f [] s = ([],s)
		seqlist f [h:t] s
			# (h,s) = f h s
			# (t,s) = seqlist f t s
			= ([h:t],s)
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
		| (string.[x] == ' ')
			= (dec x,scanspace x)
//		| (isControl string.[x])
//			= (x, scanspace x)
		= scanword (inc x)
	scanspace x
		| x >= l = l
		| (string.[x] == ' ')
			= scanspace (inc x)
		= x

isNewline '\n' = True
isNewline _ = False

splitlines s
	| size s == 0 = []
	= [s%(b,e-1) \\ (b,e) <- bes2]
where
	bes1 = [i \\ i <- [1..(size s - 1)] | (isNewline s.[i]) <> (isNewline s.[i-1])]
	bes2
		| isNewline s.[0]
			= zip` bes1
			= zip` [0:bes1]

	zip` [b] = [(b,size s)]
	zip` [b,e:r] = [(b,e):zip` r]
	zip` _ = []

			
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

