implementation module flextextcontrol

import StdArray,StdEnum, StdList, StdTuple
import StdControl, StdControlReceiver, StdId, StdPSt, StdReceiver

:: FlexText ls ps = FlexText String FlexId [ControlAttribute *(ls,ps)]

:: FlexId :== R2Id FlexMessage FlexReply

:: FlexMessage
	= FlexTextSet String
	| FlexTextGet
	| FlexPenSet FlexPen
	| FlexPenGet

:: FlexReply
	= FlexTextOK String
	| FlexPenOK FlexPen

:: FlexLS =
	{ ft	:: !String
	, pn	:: !FlexPen
	}

:: FlexPen :== [PenAttribute]

openFlexId :: !*env -> (!FlexId,!*env) | Ids env
openFlexId env = openR2Id env

setFlexTexts :: ![(FlexId,String)] !*(PSt .l) -> *PSt .l
setFlexTexts [] ps = ps
setFlexTexts [(i,t):r] ps
	# (_,ps) = syncSend2 i (FlexTextSet t)	ps
	= setFlexTexts r ps
	
setFlexPens :: ![(FlexId,FlexPen)] !*(PSt .l) -> *PSt .l
setFlexPens [] ps = ps
setFlexPens [(i,p):r] ps
	# (_,ps) = syncSend2 i (FlexPenSet p)	ps
	= setFlexPens r ps
	
addFlexPens :: ![(FlexId,FlexPen)] !*(PSt .l) -> *PSt .l
addFlexPens [] ps = ps
addFlexPens [(i,p):r] ps
	# ((_,pen),ps) = syncSend2 i FlexPenGet ps
	| isNothing pen
		= addFlexPens r ps
	# (FlexPenOK pen) = fromJust pen
	# pen = penUpdate p pen
	# (_,ps) = syncSend2 i (FlexPenSet pen)	ps
	= setFlexPens r ps
	
penUpdate p pen = removeDup (p++pen)

instance == PenAttribute
where
	(==) (PenSize _) (PenSize _) = True
	(==) (PenPos _) (PenPos _) = True
	(==) (PenColour _) (PenColour _) = True
	(==) (PenBack _) (PenBack _) = True
	(==) (PenFont _) (PenFont _) = True
	(==) _ _ = False

instance Controls FlexText
where
	getControlType _ = "FlexText"
	controlToHandles (FlexText text ftId atts) ps
		# (wid,ps) = case wAtt of
					(Just (PixelWidth p))	-> (p,ps)
					(Just (TextWidth s))	-> accPIO (accScreenPicture (detw s)) ps
					(Just (ContentWidth s))	-> accPIO (accScreenPicture (detw s)) ps
					Nothing	-> case sAtt of
						Nothing		-> accPIO (accScreenPicture (detw text)) ps
						Just {w}	-> (w,ps)
		# (hgt,ps) = case sAtt of
			Nothing		-> deth ps
			Just {h}	-> (h,ps)
		# siz = {w = wid, h = hgt}
		# satts = filterFlexAtts atts	// safe pass on...
		# (cid,ps) = accPIO openId ps
		# cid = if (isNothing iAtt) cid (fromJust iAtt)
		# inils = {ft = text, pn = getPenAtt atts}
		# (inilook,inils) = look inils
		# imp = {addLS = inils,addDef=CustomControl siz inilook [ControlId cid:satts] :+: Receiver2 ftId (recfun cid) []}
		= controlToHandles imp ps
	where
		detw s pic
			# (wid,pic) = getPenFontStringWidth s pic
			= (wid,pic)
		deth ps
			# (siz,ps)  = controlSize (TextControl "" (filterPenAtt atts)) True Nothing Nothing Nothing ps
			# hgt = siz.h
			= (hgt,ps)
		iAtt	= getIdAtt atts
		sAtt	= getSizeAtt atts
		wAtt	= getWidthAtt atts
		lmargin = 5
		rmargin = 5
		recfun cId (FlexTextSet ft) ((ls,gs),ps)
			# ls = {ls & ft = ft}
			# (look,ls) = look ls
			# ps = appPIO (setControlLooks [(cId,True,(True,look))]) ps
			= (FlexTextOK ft,((ls,gs),ps))
		recfun _ FlexTextGet ((ls=:{ft},gs),ps)
			= (FlexTextOK ft,((ls,gs),ps))
		recfun cId (FlexPenSet pn) ((ls,gs),ps)
			# ls = {ls & pn = pn}
			# (look,ls) = look ls
			# ps = appPIO (setControlLooks [(cId,True,(True,look))]) ps
			= (FlexPenOK pn,((ls,gs),ps))
		recfun _ FlexPenGet ((ls=:{pn},gs),ps)
			= (FlexPenOK pn,((ls,gs),ps))
		look ls=:{ft=text,pn=pen} = (look,ls)
		where
		  look sel {newFrame} pic
			# pic		= setPenAttributes pen pic
			# pic		= unfill newFrame pic
			# wid		= newFrame.corner2.x - newFrame.corner1.x - lmargin - rmargin
			# (met,pic)	= getPenFontMetrics pic
			# pic		= setPenPos {x = lmargin, y = met.fLeading + met.fAscent} pic
			# pic		= drawFB text wid pic
			= pic

getSizeAtt [] = Nothing
getSizeAtt [ControlViewSize s:_] = Just s
getSizeAtt [ControlOuterSize s:_] = Just s
getSizeAtt [_:atts] = getSizeAtt atts

getWidthAtt [] = Nothing
getWidthAtt [ControlWidth w:_] = Just w
getWidthAtt [_:atts] = getWidthAtt atts

getIdAtt [] = Nothing
getIdAtt [ControlId i:_] = Just i
getIdAtt [_:atts] = getIdAtt atts

getPenAtt [] = []
getPenAtt [ControlPen p:rest] = p
getPenAtt [_:r] = getPenAtt r

filterFlexAtts [] = []
filterFlexAtts [ControlResize r:rest] = [ControlResize r: filterFlexAtts rest]
filterFlexAtts [ControlTip t:rest] = [ControlTip t: filterFlexAtts rest]
filterFlexAtts [ControlPos p:rest] = [ControlPos p: filterFlexAtts rest]
filterFlexAtts [ControlPen p:rest] = [ControlPen p: filterFlexAtts rest]
filterFlexAtts [ControlMouse f s m:rest] = [ControlMouse f s m`: filterFlexAtts rest]
where
	m` ms ((ls,gs),ps)
		# (gs,ps) = m ms (gs,ps)
		= ((ls,gs),ps)
filterFlexAtts [_:rest] = filterFlexAtts rest

filterPenAtt [] = []
filterPenAtt [ControlPen p:rest] = [ControlPen p]
filterPenAtt [_:r] = filterPenAtt r

drawFB text cwidth picture
	#	(twidth,picture)	= getPenFontStringWidth text picture
	| twidth <= cwidth
		#	picture			= draw text picture
			picture			= movePenPos {zero & vx = cwidth-twidth} picture
		= picture
	#	texts				= power text
		(widths,picture)	= getPenFontStringWidths texts picture
		textl				= dropWhile (\e -> snd e > cwidth) (zip2 texts widths)
	| isEmpty textl = movePenPos {zero & vx = cwidth} picture
	#	(text,width)		= hd textl
		picture				= draw text picture
		picture				= movePenPos {zero & vx = cwidth-width} picture
	= picture
where
	power :: String -> [String]
	power text
		= reverse [text%(0,i)+++"..."\\i<-[-1..size text-1]]
