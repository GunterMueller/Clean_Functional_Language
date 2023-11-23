implementation module flexwin

/* TO DO:
o Content look
o Always leave first char of header string? Use clipping?
o Polling for column widths (in order to save/restore)
o Optimize setControlLook
o Button functions + header & body look updates...
o Sensible size handling
*/

//import StdEnv, StdIO
import StdEnum, StdString, StdFunc, StdList, StdBool, StdTuple, StdMisc, StdArray
import StdWindow, StdId, StdProcess, StdWindowAttribute, StdReceiver
import StdPSt, StdPicture, StdControl, StdControlReceiver
import Platform

class content_size c :: FontMetrics c -> Int

:: FlexBarState s =
	{ nrOfColumns	:: !Int
	, columnPoss	:: ![Int]
	, columnTexts	:: ![String]
	, height		:: !Int
	, windowId		:: !Id
	, headerId		:: !Id
	, receiverId	:: !R2Id (MessageIn s) (MessageOut s)
	, cursep		:: !Int			// selected column seperator ~1 if none
	, curcol		:: !Int			// selected column 0 if none negative if selected but mouse outside of button area

	, domain		:: !ViewDomain
	, info			:: !s
	, line_height	:: !Int
	, metrics		:: !FontMetrics
	, columnFuncs	:: ![(FlexBarState s) -> FlexBarState s]
	, body_look		:: !s .Int .Int [.Int] -> (.SelectState .UpdateState -> .(*Picture -> *Picture))
	}

:: MessageIn s
	= FW_DummyIn
	| FW_SetContent s
	| FW_ApplyFunction Int
	| FW_GetContent

:: MessageOut s
	= FW_DummyOut
	| FW_ContentOut s

mi2cw Nothing	= 10
mi2cw (Just w)
	| w < 5 = 5		// minimum column width, moet eigenlijk niet hier maar pas bij tekenen en afhankelijk van font
	= w

//--

::	FlexBarWindow s ls pst
	= FlexBarWindow
		Title
		[(String, Maybe Int)]
		s
		(s .Int .Int [.Int] -> (.SelectState .UpdateState -> (*Picture -> *Picture)))
		![(FlexBarState s) -> FlexBarState s]
		(R2Id (MessageIn s) (MessageOut s))
		[WindowAttribute *(ls,pst)]

flexFont = PlatformDependant
	// Win
	{ fName		= "Courier New"
	, fStyles	= []//[BoldStyle]
	, fSize		= 9//8
	}
	// Mac
	{ fName		= "Monaco"//"Courier"
	, fStyles	= []//[BoldStyle]
	, fSize		= 10//9
	}

instance Windows (FlexBarWindow s) | content_size s
where
	getWindowType _ = "FlexBarWindow"
	openWindow ls (FlexBarWindow title elts info look funs receiverId atts) ps
		# (windowId,ps)				= case hasWindowIdAtt of
										Nothing		-> openId ps
										(Just wId)	-> (wId,ps)
		# (headerId,ps)				= openId ps
		# ((ok,font),ps)			= accScreenPicture (openFont flexFont) ps 
		# (metrics,ps)				= accScreenPicture (getFontMetrics font) ps
		# ((size,line_height),ps)	= accScreenPicture (profileSize info o (setPenFont font)) ps
		# domain					= {zero & corner2 = {x=last columnPoss,y=height + size}}
		# inistate					= newstate info domain line_height metrics headerId windowId
		= openWindow
			inistate
			(Window
				title
				(header font headerId inistate)
				(newatts domain font line_height windowId inistate)
			) ps
	where
		hasWindowIdAtt
			 # los = filter (isWindowId) atts
			 | isEmpty los = Nothing
			 = Just (getWindowIdAtt (hd los))
		header font headerId inistate
			= CustomControl
				{w=4096,h=height}			// zinniger maximum invullen???
				(headerLook height columnTexts columnPoss`)
				[ControlId headerId
				,ControlMouse mouseFilter Able (mouseFunction inistate)
				,ControlPos (Fix,OffsetFun 1 (\({corner1={x}},{y})->{vx = x,vy = y}))
				,ControlPen [PenFont font]
				]
			:+: Receiver2 receiverId receiver []
		newatts domain font line_height windowId inistate = 
			[ WindowPen [PenBack Vellum, PenFont font]
			, WindowLook True (flexLook inistate)
			, WindowViewDomain domain
			, WindowId windowId
			, WindowMouse mouseFilter Able (mouseFunction inistate)
			, WindowKeyboard keyboardFilter Able (keyboardFunction)
			, WindowHScroll (myScrollFunction Horizontal LR_STEP)
			, WindowVScroll (myScrollFunction Vertical line_height)
			, WindowClose (noLS closeProcess)
			: fixwinatts atts
			]
		newstate info domain line_height metrics headerId windowId = 
			{ nrOfColumns	= length elts
			, columnPoss	= columnPoss
			, columnTexts	= columnTexts
			, height		= height
			, metrics		= metrics
			, line_height	= line_height
			, windowId		= windowId
			, headerId		= headerId
			, receiverId	= receiverId
			, cursep		= ~1
			, curcol		= 0
			, domain		= domain
			, info			= info
			, columnFuncs	= funs
			, body_look		= look
			}
		height		= 20
		columnPoss	= fiddle 0 (map (mi2cw o snd)  elts) []
		columnPoss`	= [0:columnPoss]
		columnTexts	= map fst elts

appInfo :: (s->s) !(FlexBarState s) -> FlexBarState s
appInfo f fs=:{info} = {fs & info = f info}

//--

LR_STEP :== 12

keyboardFilter (SpecialKey key (KeyDown _) _)
	| key == upKey		= True
	| key == downKey	= True
	| key == beginKey	= True
	| key == endKey		= True
	| key == pgUpKey	= True
	| key == pgDownKey	= True
	| key == leftKey	= True
	| key == rightKey	= True
	= False
keyboardFilter _ = False

keyboardFunction (SpecialKey key _ mods) (fs=:{windowId,height,line_height,domain,columnPoss},ps)
	# (delta,ps) = calcDelta ps
	| delta == zero
		= (fs,ps)
	# ps = appPIO (moveWindowViewFrame windowId delta) ps
	= (fs,ps)
where
	calcDelta ps
		| key == upKey
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = min (vf.corner1.y - domain.corner1.y) line_height
			= ({zero & vy = ~delta},ps)
		| key == downKey
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = min (domain.corner2.y - vf.corner2.y) line_height
			= ({zero & vy = delta},ps)
		| key == pgUpKey
			# (vf,ph,ps) = calcPageHeight ps
			# delta = min (vf.corner1.y - domain.corner1.y) ph
			= ({zero & vy = ~delta},ps)
		| key == pgDownKey
			# (vf,ph,ps) = calcPageHeight ps
			# delta = min (domain.corner2.y - vf.corner2.y) ph
			= ({zero & vy = delta},ps)
		| key == beginKey
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = vf.corner1.y - domain.corner1.y
			= ({zero & vy = ~delta},ps)
		| key == endKey
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = max (domain.corner2.y - vf.corner2.y) 0
			= ({zero & vy = delta},ps)
		| key == leftKey && mods == NoModifiers
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = min (vf.corner1.x - domain.corner1.x) LR_STEP
			= ({zero & vx = ~delta},ps)
		| key == rightKey && mods == NoModifiers
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = min (domain.corner2.x - vf.corner2.x) LR_STEP
			= ({zero & vx = delta},ps)
		| key == leftKey && mods.controlDown
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = vf.corner1.x - domain.corner1.x
			= ({zero & vx = ~delta},ps)
		| key == rightKey && mods.controlDown
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = domain.corner2.x - vf.corner2.x
			= ({zero & vx = delta},ps)
		| key == leftKey && mods.shiftDown
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = leftCol 0 vf.corner1.x columnPoss
			= ({zero & vx = delta},ps)
		| key == rightKey && mods.shiftDown
			# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
			# delta = rightCol vf.corner1.x columnPoss
			= ({zero & vx = delta},ps)
		= (zero,ps)
	calcPageHeight ps
		# (vf,ps) = accPIO (getWindowViewFrame windowId) ps
		# vs = rectangleSize vf
		# ph = vs.h - height
		# ph = ph/line_height*line_height
		= (vf,ph,ps)
	leftCol last xpos []
		= last - xpos
	leftCol last xpos [h:t]
		| h >= xpos
			= last - xpos
		= leftCol h xpos t
	rightCol xpos [] = 0
	rightCol xpos [h:t]
		| h > xpos
			= h - xpos
		= rightCol xpos t
		
keyboardFunction _ (fs,ps)
	= (fs,ps)

//--

receiver :: !(MessageIn s) !(!FlexBarState s, !PSt .l) -> (!MessageOut s,!(!FlexBarState s, !PSt .l)) | content_size s

receiver FW_DummyIn (fs,ps) = (FW_DummyOut,(fs,ps))

receiver (FW_SetContent info) (fs=:{metrics,height,windowId,columnPoss},ps)
	# size = content_size metrics info
	# domain = {zero & corner2 = {x=last columnPoss,y=height + size}}
	# fs = {fs & info = info , domain = domain}
	# ps = appPIO (setWindowLook windowId False (True,flexLook fs)) ps
	# ps = appPIO (setWindowViewDomain windowId domain) ps
	# ps = appPIO (updateWindow windowId Nothing) ps
	= (FW_DummyOut,(fs,ps))

receiver (FW_ApplyFunction colnr) (fs=:{columnFuncs,windowId},ps)
	| colnr <= 0 || colnr > length columnFuncs = (FW_DummyOut,(fs,ps))
	# fs	= (columnFuncs!!(dec colnr)) fs
	# ps	= appPIO (setWindowLook windowId True (True,flexLook fs)) ps	// need to optimize this...
	= (FW_DummyOut,(fs,ps))

receiver (FW_GetContent) (fs=:{info},ps)
	= ((FW_ContentOut info),(fs,ps))
//---

power :: !String -> [String]
power text
	= reverse [text%(0,i)+++"..."\\i<-[-1..size text-1]]

fiddle x [] acc = reverse acc
fiddle x [w:ws] acc = fiddle (x+w) ws [x+w:acc]

fixwinatts [] = []
fixwinatts [h:t] = [fixwinatt h:fixwinatts t]

fixwinatt (WindowOuterSize s) = WindowOuterSize s
fixwinatt (WindowViewSize s) = WindowViewSize s
fixwinatt (WindowId i) = WindowId i
//fixwinatt (WindowKeyboard k a f) = WindowKeyboard k a f	--> moet integratie met bestaande regelen...
fixwinatt _ = abort "flexbar:fixwinatt: unsupported window attribute encountered"

//--

mouseFilter :: .a -> .Bool;
mouseFilter _ = True

mouseFunction :: .a !.MouseState !*(!FlexBarState s,*PSt .b) -> *(FlexBarState s,*PSt .b);
mouseFunction _ (MouseDown pos=:{x,y} mod _) (fs=:{columnPoss,headerId,height},ps)
	| not inVert
		# fs = {fs & cursep = ~1, curcol = 0}
		= (fs,ps)
	# sep		= findSep (dec (length columnPoss)) x columnPoss
	# fs		= {fs & cursep = sep}
	| sep == ~1
		# col = findCol (dec (length columnPoss)) x columnPoss
		# fs = {fs & curcol = col}
		| col <> 0 && col <= length columnPoss
			# ps = appPIO (appControlPicture headerId (pressLook fs)) ps
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
		
mouseFunction _ (MouseDrag pos=:{x,y} mod) (fs=:{cursep,curcol,columnPoss,windowId,headerId,height},ps)
	| isEmpty columnPoss
		= (fs,ps)
	| cursep == ~1
		| curcol == 0 || curcol > length columnPoss
			= (fs,ps)
		// controleren of we binnen button area zijn en blijven...
		| wasInside == isInside
			= (fs,ps)
		| isInside
			# fs = {fs & curcol = abs curcol}
			# ps = appPIO (appControlPicture headerId (pressLook fs)) ps
			= (fs,ps)
//		# ps		= appPIO (setControlLooks [(customId, False, (True,flexLook fs))]) ps
		# ps		= appPIO (appControlPicture headerId (unpressLook fs)) ps
		# fs		= {fs & curcol = ~curcol}
		= (fs,ps)
	# (vd,ps)		= accPIO (getWindowViewDomain windowId) ps
	| isNothing vd
		= (fs,ps)
	# vd			= fromJust vd

	# (changed,columnPoss`)
					= dragCol cursep x columnPoss
	| not changed
		= (fs,ps)
	# fs			= {fs & columnPoss = columnPoss`}
///*
	# ps			= appPIO (setWindowLook windowId False (True,flexLook fs)) ps	// need to optimize this...
	# ps			= appPIO (setControlLook headerId True (True,headerLook fs.height fs.columnTexts [0:fs.columnPoss])) ps	// need to optimize this...
	# (sz,ps)		= accPIO (getWindowViewFrame windowId) ps
	# cp			= /*trace_n ("csi: "+++toString (cursep))*/ (cursep)
	#! cp			= [0:columnPoss`]!!cp
//	# vf			= {corner1={x=cp,y=0},corner2={x=sz.corner2.x,y=fs.height}}
//	# ps			= appPIO (updateWindow windowId (Just vf)) ps
	# vf			= {corner1={x=cp,y=height},corner2={x=sz.corner2.x,y=sz.corner2.y}}
	# ps			= appPIO (updateWindow windowId (Just vf)) ps
	| (last columnPoss` > sz.corner2.x) || (vd.corner2.x > sz.corner2.x)
		# domain	= {vd & corner2 = {vd.corner2 & x = last columnPoss`}}
		# ps		= appPIO (setWindowViewDomain windowId domain) ps
		# fs		= {fs & domain = domain} // moet dan nu eigenlijk opnieuw look zetten...
		//--> moet hier ook header control size aanpassen...
		= (fs,ps)
//*/
/*
	# ps			= appPIO (setControlLooks [(customId, False, (True,flexLook fs))]) ps	// need to optimize this...
	# ps			= appPIO (setControlViewDomain customId {vd & corner2 = {vd.corner2 & x = last columnPoss}}) ps
*/
	= (fs,ps)
where
	inVert		= 0 <= y && y <= height 
	inHorz		= findCol (dec (length hcols)) x hcols == abs curcol
	hcols		= [0:columnPoss]
	isInside	= inHorz && inVert
	wasInside	= curcol > 0

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

mouseFunction _ (MouseUp pos=:{x,y} mod) (fs=:{columnPoss,columnFuncs,windowId,headerId,curcol},ps)
	| curcol > 0 && curcol <= length columnPoss
		# fs	= (columnFuncs!!(dec curcol)) fs
		# ps	= appPIO (setWindowLook windowId True (True,flexLook fs)) ps	// need to optimize this...
		# ps	= appPIO (appControlPicture headerId (unpressLook fs)) ps
		# fs	= {fs & curcol = 0}
		= (fs,ps)
	# fs		= {fs & curcol = 0}
	= (fs,ps)
mouseFunction _ _ (fs=:{windowId,curcol},ps)
	| curcol <> 0
		# ps	= appPIO (setWindowLook windowId True (True,flexLook fs)) ps	// need to optimize this...
		# fs	= {fs & curcol = 0}
		= (fs,ps)
	= (fs,ps)

//--

unpressLook :: !(FlexBarState s) !*Picture -> *Picture;
unpressLook fs=:{columnPoss,height,curcol} pict
	| curcol == 0
		= pict
	# columnPoss`	= [0:columnPoss]
	# spos			= columnPoss`!!(dec curcol)
	# epos			= columnPoss`!!curcol
	= drawFrame height spos epos pict

// pressLook generates the pressed button look for the curcol pressed button...
pressLook :: !(FlexBarState s) !*Picture -> *Picture
pressLook fs=:{columnPoss,height,curcol} pict
	| curcol == 0 = pict
	= pressLook pict
where
	pressLook picture
		# picture		= setPenSize 1 picture
		# columnPoss`	= [0:columnPoss]
		# spos			= columnPoss`!!(dec curcol)
		# epos			= columnPoss`!!curcol
		# picture		= setPenColour Black picture
		# picture		= drawAt {x=spos,y=0} {zero & vx = epos-spos-1} picture
		# picture		= drawAt {x=spos,y=0} {zero & vy = height-1} picture
		# picture		= setPenColour LighterGrey picture
		# picture		= drawAt {x=spos,y=height-1} {zero & vx = epos-spos} picture
		# picture		= drawAt {x=epos-1,y=0} {zero & vy = height-1} picture
		# picture		= setPenColour Grey picture
		# picture		= drawAt {x=spos+1,y=1} {zero & vx = epos-spos-3} picture
		# picture		= drawAt {x=spos+1,y=1} {zero & vy = height-3} picture
		# picture		= setPenColour LightGrey picture
		# picture		= drawAt {x=spos+2,y=height-2} {zero & vx = epos-spos-2} picture
		# picture		= drawAt {x=epos-2,y=1} {zero & vy = height-3} picture
		= picture

LighterGrey :: .Colour;
LighterGrey = RGB {r=225,g=225,b=225}

Vellum = RGB {r=255,g=255,b=225}

flexLook :: !(FlexBarState s) SelectState !UpdateState -> (IdFun *Picture)
flexLook flexbarState=:{columnTexts,columnPoss,height,line_height,info,body_look,domain} ss us=:{newFrame,updArea}
	# columnPoss = [0:columnPoss]
	= seq
		[ /*headerLook height columnTexts columnPoss ss us
		, */body_look info height line_height columnPoss ss us
		, back_look domain ss us
		]
	
headerLook :: .Int [.{#Char}] [.Int] .a !.UpdateState -> .(*Picture -> *Picture);
headerLook height columnTexts columnPoss ss us=:{newFrame,updArea}
	= seq
	[ setPenColour backgroundColour
//	, seq (map fill updArea)
	, fill {zero & corner2 = {x=newFrame.corner2.x, y=20}}
	, setPenColour foregroundColour
	, setPenPos {x=2,y=14}
	:	[ drawFB text (columnPoss!!i) (columnPoss!!j)
		\\ text <- columnTexts
		& i <- [0..]
		& j <- [1..]
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
	
drawFrame :: !.Int !.Int !.Int !*Picture -> *Picture;
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

//-- Profile stuff...

//profileSize :: (a b) *Picture -> (.(Int,Int),.Picture) | length a;
profileSize lines pic
	# (fMetrics,pic)	= getPenFontMetrics pic
	# line_height		= fontLineHeight fMetrics
	# height			= content_size fMetrics lines
	= ((height,line_height),pic)

//--

back_look domain ss us=:{updArea}
	= look updArea
where
	look [] pict
		= pict
	look [ua:us] pict
		# pict = updBelow pict
		= look us pict
	where
		updBelow pict
			|	(domain.corner2.y < ua.corner2.y)
				= unfill
					{ ua
					& corner1 = {x = ua.corner1.x, y = max domain.corner2.y ua.corner1.y}
					} pict
			= pict
	
//--

myScrollFunction :: !Direction !Int -> ScrollFunction
myScrollFunction direction d
	= stdScrollFunction` direction d
where
	stdScrollFunction` :: !Direction !Int !ViewFrame !SliderState !SliderMove -> Int
	stdScrollFunction` direction d viewFrame {sliderThumb=x} move
		# d				= abs d
		  viewFrameSize	= rectangleSize viewFrame
		  edge			= if (direction==Horizontal) viewFrameSize.w viewFrameSize.h
		= case move of
			SliderIncSmall	-> x+d
			SliderDecSmall	-> x-d
			SliderIncLarge	-> x+edge/d*d
			SliderDecLarge	-> x-edge/d*d
			SliderThumb x	-> x	//x/d*d

//--

instance accScreenPicture (PSt .l)
where
	accScreenPicture f ps = accPIO (accScreenPicture f) ps

instance toString (FlexBarState a) where toString fs = "FlexBarState"
