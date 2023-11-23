implementation module flexbar

/* TO DO:
o Content look
o Always leave first char of header string? Use clipping?
o Polling for column widths (in order to save/restore)
o Optimize setControlLook
o Button functions + header & body look updates...
o Sensible size handling
*/

import StdEnv, StdIO
import StdDebug

:: FlexBarControl ls ps =
	{ flexbarState	:: FlexBarState
	, flexbarAtts	:: [ControlAttribute *(ls,ps)]
	}

:: FlexBarState =
	{ nrOfColumns	:: !Int
	, columnPoss	:: ![Int]
	, columnTexts	:: ![String]
	, height		:: !Int
	, receiverId	:: !R2Id MessageIn MessageOut
	, customId		:: !Id
	, windowId		:: !Id
	, cursep		:: !Int
	, curcol		:: !Int
	}

:: MessageIn	= DummyIn

:: MessageOut	= DummyOut

FlexBarControl :: Id [(String, Maybe Int)] [ControlAttribute *(.ls,.ps)] !*env
				-> (!FlexBarControl .ls .ps,!*env) | Ids env
FlexBarControl windowId elements atts env
	#	nrOfColumns		= length elements
		columnWidths	= map (mi2cw o snd)  elements
		columnPoss		= fiddle 0 columnWidths []
//		columnPoss = trace_n (showl columnPoss) columnPoss
		columnTexts		= map fst elements
		height			= 20
		(receiverId,env)= openR2Id env
		(customId,env)	= openId env
	=	({flexbarState =
		{ nrOfColumns	= nrOfColumns
		, columnPoss	= columnPoss
		, columnTexts	= columnTexts
		, height		= height
		, receiverId	= receiverId
		, customId		= customId
		, windowId		= windowId
		, cursep = ~1
		, curcol = 0
		}
		,flexbarAtts = atts
		},env)

mi2cw Nothing	= 10
mi2cw (Just w)
	| w < 5 = 5		// minimum column width, moet eigenlijk niet hier maar pas bij tekenen en afhankelijk van font
	= w

instance Controls FlexBarControl
where
	//controlToHandles :: !(FlexBarControl .ls (PSt .l)) -> [ControlState .ls (PSt .l)]
	controlToHandles {flexbarState,flexbarAtts} ps
		= controlToHandles imp ps
	where
		imp =
			{ newLS		=	flexbarState
			, newDef	=
				(	CompoundControl NilLS
						[ ControlPen [PenBack Magenta]
						, ControlLook True (flexLook flexbarState)
			//			, ControlViewSize {w=400,h=flexbarState.height+40}
						, ControlViewDomain {zero & corner2 = {x=400,y=flexbarState.height + (200*15 + 120)}}
						, ControlId flexbarState.customId
						, ControlMouse mouseFilter Able (mouseFunction flexbarState)
						, ControlHScroll (stdScrollFunction Horizontal 3)
						, ControlVScroll (stdScrollFunction Vertical 3)
						, ControlResize (\oc op np -> {w=((np.w)/3*3), h=((np.h-80)/3*3)})
						: fixatts flexbarAtts
						]
				:+:	Receiver2
						flexbarState.receiverId
						receiver
						[]
				)
			}

		receiver :: MessageIn (FlexBarState,PSt .l) -> (MessageOut,(FlexBarState,PSt .l))
		receiver DummyIn (fbState,pState)
			= (DummyOut,(fbState,pState))

	getControlType :: (FlexBarControl .ls .ps) -> ControlType
	getControlType _ = "FlexBarControl"

//---

power :: !String -> [String]
power text
	= reverse [text%(0,i)+++"..."\\i<-[-1..size text-1]]

fiddle x [] acc = reverse acc
fiddle x [w:ws] acc = fiddle (x+w) ws [x+w:acc]

fixatts [] = []
fixatts [h:t] = [fixatt h:fixatts t]

fixatt :: !(ControlAttribute (.ls,.ps)) -> ControlAttribute (FlexBarState,.ps)
fixatt (ControlOuterSize s) = ControlOuterSize s
fixatt _ = abort "flexbar:fixatt: unsupported control attribute encountered"

//--

//mouseFilter (MouseDown _ _ 1)	= True
//mouseFilter (MouseDrag _ _)		= True
//mouseFilter _					= False

mouseFilter _ = True

mouseFunction _ (MouseDown pos=:{x,y} mod _) (fs=:{columnPoss,customId,height},ps)
	| not inVert
		# fs = {fs & cursep = ~1, curcol = 0}
		= (fs,ps)
	# sep		= findSep (dec (length columnPoss)) x columnPoss
	# fs		= {fs & cursep = sep}
	| sep == ~1
		# col = findCol (dec (length columnPoss)) x columnPoss
		# fs = {fs & curcol = col}
		| col <> 0 && col <= length columnPoss
			# ps = appPIO (appControlPicture customId (pressLook fs)) ps
			= (fs,ps)
		= (fs,ps)
	# fs = {fs & curcol = 0}
	= (fs,ps)
where
	inVert = 0 <= y && y <= height 

	findSep -1 _ _ = /*trace_n "sep -1"*/ ~1
	findSep i x l
		# cx = l!!i
		| abs (cx - x) <= 5
			= /*trace_n ("sep "+++toString i)*/ i
		= findSep (dec i) x l
		
	findCol -1 _ _ = /*trace_n "col 1"*/ 1
	findCol i x l
		# cx = l!!i
		| x > cx
			= /*trace_n ("col "+++toString (i+2))*/ i+2
		= findCol (dec i) x l
		
mouseFunction _ (MouseDrag pos=:{x,y} mod) (fs=:{cursep,curcol,columnPoss,customId,height},ps)
	| isEmpty columnPoss = (fs,ps)
	| cursep == ~1
		| curcol == 0 || curcol > length columnPoss
			= (fs,ps)
		// controleren of we binnen button area zijn en blijven...
		| wasInside == isInside
			= (fs,ps)
		| isInside
			# fs = {fs & curcol = abs curcol}
			# ps = appPIO (appControlPicture customId (pressLook fs)) ps
			= (fs,ps)
//		# ps = appPIO (setControlLooks [(customId, False, (True,flexLook fs))]) ps
		# ps = appPIO (appControlPicture customId (unpressLook fs)) ps
		# fs = {fs & curcol = ~curcol}
		= (fs,ps)
	# (ws,ps) = accPIO (getParentWindow customId) ps
	| isNothing ws = (fs,ps)
	# ws = fromJust ws
	# (ok,vd) = getControlViewDomain customId ws
	| not ok || isNothing vd = (fs,ps)
	# vd = fromJust vd

	# (changed,columnPoss`)	= dragCol cursep x columnPoss
	| not changed = (fs,ps)
	# fs			= {fs & columnPoss = columnPoss`}
///*
	# ps			= appPIO (setControlLooks [(customId, False, (True,flexLook fs))]) ps	// need to optimize this...
	# (_,sz) =  getControlViewFrame customId ws
	# sz = fromJust sz
	# cp = /*trace_n ("csi: "+++toString (cursep))*/ (cursep)
	#! cp = [0:columnPoss`]!!cp
	# vf = {corner1={x=cp,y=0},corner2={x=sz.corner2.x,y=fs.height}}
	# ps			= appPIO (updateControl customId (Just vf)) ps
	# vf = {corner1={x=cp,y=height},corner2={x=sz.corner2.x,y=sz.corner2.y}}
	# ps			= appPIO (updateControl customId (Just vf)) ps
	| (last columnPoss` > sz.corner2.x) || (vd.corner2.x > sz.corner2.x)
		# ps			= appPIO (setControlViewDomain customId {vd & corner2 = {vd.corner2 & x = last columnPoss`}}) ps
		= (fs,ps)
//*/
/*
	# ps			= appPIO (setControlLooks [(customId, False, (True,flexLook fs))]) ps	// need to optimize this...
	# ps			= appPIO (setControlViewDomain customId {vd & corner2 = {vd.corner2 & x = last columnPoss}}) ps
*/
	= (fs,ps)
where
	inVert = 0 <= y && y <= height 
	inHorz = findCol (dec (length hcols)) x hcols == abs curcol
	hcols = [0:columnPoss]
	isInside = inHorz && inVert
	wasInside = curcol > 0

	findCol -1 _ _ = 0
	findCol i x l
		# cx = l!!i
		| x >= cx
			= inc i
		= findCol (dec i) x l
		
	
	dragCol _ _ [] = (False,[])
	dragCol (-1) _ cs = (False,cs)
	dragCol i x cs
		# (bs,cs) = splitAt i cs
		| isEmpty cs = (False,bs)
		# o = hd cs
		# m = if (isEmpty bs) 0 (last bs)
		# x = max m x
		# d = x - o
		| d == 0 = (False,bs++cs)
		# f = \c -> c + d
		# cs = map f cs
		= (True,bs++cs)

mouseFunction _ _ (fs=:{customId,curcol},ps)
	| curcol <> 0
		# ps	= appPIO (setControlLooks [(customId, True, (True,flexLook fs))]) ps	// need to optimize this...
		# fs	= {fs & curcol = 0}
		= (fs,ps)
	= (fs,ps)

//--

unpressLook fs=:{columnPoss,height,curcol} pict
	| curcol == 0 = pict
	# columnPoss` = [0:columnPoss]
	# spos = columnPoss`!!(dec curcol)
	# epos = columnPoss`!!curcol
	= drawFrame height spos epos pict

// pressLook generates the pressed button look for the curcol pressed button...
pressLook :: FlexBarState *Picture -> *Picture
pressLook fs=:{columnPoss,height,curcol} pict
	| curcol == 0 = pict
	= pressLook pict
where
	pressLook picture
		# picture = setPenSize 1 picture
		# columnPoss` = [0:columnPoss]
		# spos = columnPoss`!!(dec curcol)
		# epos = columnPoss`!!curcol
		# picture	= setPenColour Black picture
		# picture	= drawAt {x=spos,y=0} {zero & vx = epos-spos-1} picture
		# picture	= drawAt {x=spos,y=0} {zero & vy = height-1} picture
		# picture	= setPenColour LighterGrey picture
		# picture	= drawAt {x=spos,y=height-1} {zero & vx = epos-spos} picture
		# picture	= drawAt {x=epos-1,y=0} {zero & vy = height-1} picture
		# picture	= setPenColour Grey picture
		# picture	= drawAt {x=spos+1,y=1} {zero & vx = epos-spos-3} picture
		# picture	= drawAt {x=spos+1,y=1} {zero & vy = height-3} picture
		# picture	= setPenColour LightGrey picture
		# picture	= drawAt {x=spos+2,y=height-2} {zero & vx = epos-spos-2} picture
		# picture	= drawAt {x=epos-2,y=1} {zero & vy = height-3} picture
		= picture

LighterGrey = RGB {r=225,g=225,b=225}

flexLook :: FlexBarState SelectState UpdateState -> (IdFun *Picture)
flexLook flexbarState=:{columnTexts,columnPoss,height} ss us=:{newFrame,updArea}
	# columnPoss = [0:columnPoss]
	= seq
	[ setPenColour backgroundColour
	, seq (map fill updArea)
//	, fill newFrame
	, setPenColour foregroundColour
	, setPenPos {x=2,y=14}
	:	[ drawFB text (columnPoss!!i) (columnPoss!!j)
		\\ text <- columnTexts
		& i <- [0..]
		& j <- [1..]
		]
	++	[ setPenPos {x=2,y=20}
		, setPenSize 2
		:	[ drawSep (columnPoss!!i) (columnPoss!!j)
			\\ text <- columnTexts
			& i <- [0..]
			& j <- [1..]
			]
		]
	++	[ setPenPos {x=2,y=20}
		, setPenSize 1
		:	[ drawFrame height (columnPoss!!i) (columnPoss!!j)
			\\ text <- columnTexts
			& i <- [0..]
			& j <- [1..]
			]
		]
	++	(if (newFrame.corner2.x > last columnPoss)
		[ drawFrame height (last columnPoss) (newFrame.corner2.x) ]
		[]
		)
	++ [contentLook height columnPoss ss us]
	]
where
	foregroundColour = Black
	backgroundColour = LightGrey
	leading = 5
	trailing = 5
		
	drawFB text spos epos picture
		# (twidth,picture)		= getPenFontStringWidth text picture
		# picture				= movePenPos {zero & vx = leading} picture
		| twidth <= kwidth
			#	picture			= draw text picture
				picture			= movePenPos {zero & vx = cwidth-twidth-leading} picture
			= picture
		#	texts				= power text
			(widths,picture)	= getPenFontStringWidths texts picture
			textl				= dropWhile (\e -> snd e > kwidth) (zip2 texts widths)
		| isEmpty textl = movePenPos {zero & vx = cwidth-leading} picture
		#	(text,width)		= hd textl
			picture				= draw text picture
			picture				= movePenPos {zero & vx = cwidth-width-leading} picture
		= picture
	where
		cwidth = epos - spos
		kwidth = cwidth - leading - trailing
	
	drawSep spos epos picture
//		# picture	= movePenPos {vx = cwidth, vy = -20} picture
//		# picture	= draw {zero & vy = 20} picture
		= picture
//	where
//		cwidth = epos - spos

drawFrame :: !.Int !.Int !.Int !*Picture -> .Picture;
drawFrame height spos epos picture
	# picture	= setPenColour LighterGrey picture
	# picture	= drawAt {x=spos,y=0} {zero & vx = epos-spos-1} picture
	# picture	= drawAt {x=spos,y=0} {zero & vy = height-2} picture
	# picture	= setPenColour Black picture
	# picture	= drawAt {x=spos,y=height-1} {zero & vx = epos-spos} picture
	# picture	= drawAt {x=epos-1,y=0} {zero & vy = height-1} picture
	# picture	= setPenColour LightGrey picture
	# picture	= drawAt {x=spos+1,y=1} {zero & vx = epos-spos-3} picture
	# picture	= drawAt {x=spos+1,y=1} {zero & vy = height-4} picture
	# picture	= setPenColour Grey picture
	# picture	= drawAt {x=spos+1,y=height-2} {zero & vx = epos-spos-2} picture
	# picture	= drawAt {x=epos-2,y=1} {zero & vy = height-3} picture
	= picture
//	where
//		t1 = 0
//		t2 = 1
		
contentLook :: .Int [.Int] -> (!SelectState !UpdateState !*Picture -> !*Picture)
contentLook top cols = look
where	// need to use updArea...
	look ss us=:{newFrame,updArea} picture
		# picture = lookone ss {us & updArea = updAreaOne} picture
		# picture = looktwo ss {us & updArea = updAreaTwo} picture
		# picture = lookthree ss {us & updArea = updAreaThree} picture
		= picture
	where
		lookone = drawColOne col0 col1 top
		looktwo = drawColTwo col1 col2 top
		lookthree = drawColThree col2 col3 top
		col0 = cols!!0
		col1 = cols!!1
		col2 = cols!!2
		col3 = cols!!3
		updAreaOne = map fromJust (filter isJust (map (toCol col0 col1) updArea))
		updAreaTwo = map fromJust (filter isJust (map (toCol col1 col2) updArea))
		updAreaThree = map fromJust (filter isJust (map (toCol col2 col3) updArea))
		bot = newFrame.corner2.y
		toCol left right {corner1={x=l,y=t},corner2={x=r,y=b}}
			# t = trace_n ("B t: "+++toString t+++"\tl: "+++toString l+++"\tb: "+++toString b+++"\tr: "+++toString r) t
			# t = max t top
			# b = min b bot
			# l = max l left
			# r = min r right
			| t >= b || l >= r = Nothing
			= trace_n ("A t: "+++toString t+++"\tl: "+++toString l+++"\tb: "+++toString b+++"\tr: "+++toString r) Just {corner1={x=l,y=t},corner2={x=r,y=b}}
/*
	= drawCols colours cols
where
	colours = [Red,Green,Yellow,Blue,Grey,Cyan,Magenta:colours]
	drawCols [col:cols] [start,end:rest] picture
		# picture = setPenColour col picture
		# picture = fillAt {x=start,y=top} {box_w = end-start,box_h = newFrame.corner2.y - top} picture
		= drawCols cols [end:rest] picture
	drawCols _ _ picture = picture
*/
import ioutil

drawColOne start end top selstate updstate=:{newFrame,updArea} picture
	# picture = setPenColour Yellow picture
	# picture = seq (map fill updArea) picture
	# picture = setPenColour Black picture
	# picture = seq [drawLines (up t) (dn b) \\ {corner1={y=t},corner2={y=b}} <- updArea] picture
	= picture
where
	skip = 5
	first = top + skip + line
	line = 15
	last = first + (200 * line)
	up t = max first ((t-20)/15*15+20)
	dn b = min last ((b-20)/15*15+20+15)
	drawLines f l = trace_n ("f: "+++toString f+++"\tl: "+++toString l) seq [drawRight {x=end-5,y=y} n \\ n <- [(f-skip)/15..] & y <- [f,f+line..l]]

drawColTwo start end top selstate updstate=:{newFrame,updArea} picture
	# picture = setPenColour Green picture
	# picture = seq (map fill updArea) picture
	= picture
	
drawColThree start end top selstate updstate=:{newFrame,updArea} picture
	# picture = setPenColour Red picture
	# picture = seq (map fill updArea) picture
	= picture
	
