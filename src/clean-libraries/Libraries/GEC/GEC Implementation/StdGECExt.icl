implementation module StdGECExt

import StdEnv
import StdIO
import genericgecs, GECValue, StdAGEC
import store, TRACE

nothing _ _ pSt = pSt
tracing r x pSt = DO_TRACE (r,x) pSt

createNGEC :: String OutputOnly Bool a (Update a (PSt .ps)) *(PSt .ps) -> *((GECVALUE a *(PSt .ps)),*(PSt .ps)) | gGEC{|*|} a & bimap{|*|} ps
createNGEC title outputOnly hasOBJECT initval userUpdate pSt
	# (objId,pSt)	= openOBJECTControlId pSt
	= case accPIO (searchWindowIdWithTitle title) pSt of
		(Nothing,pSt)
			#	(id,pSt)	= openId pSt
			#	(_,pSt)		= openWindow undef 
								(Window title NilLS 
											[	WindowId id
											, 	WindowViewSize {w=600,h=350}
											, 	WindowLook     True stdUnfillNewFrameLook
											, 	WindowPen      [PenBack defWindowBackColour]
											,	WindowHScroll  (stdScrollFunction Horizontal 20)
											,	WindowVScroll  (stdScrollFunction Horizontal 20)
											,	WindowViewDomain {zero & corner2={x=600,y=350}}
											]) pSt
			#	guiLoc		= {guiId=id,guiItemPos=(Fix,OffsetVector {vx=hOffset,vy=vOffset})}
			# 	(setA,pSt)	= openGECVALUE (guiLoc,objId) outputOnly hasOBJECT (Just initval) (why_changed id) pSt
			#	pSt			= setA.gecOpenGUI (guiLoc,objId) pSt
			= 	(setA,pSt)
		(Just id,pSt)
			#	guiLoc		= {guiId=id,guiItemPos=(Left,OffsetVector {vy=vOffset, vx=hOffset})}
			# 	(setA,pSt)	= openGECVALUE (guiLoc,objId) outputOnly hasOBJECT (Just initval) (why_changed id) pSt
			#	pSt			= setA.gecOpenGUI (guiLoc,objId) pSt
			= 	(setA,pSt)
where
	why_changed wId reason t pSt = adjustViewDomain wId (userUpdate reason t pSt)
	
	hOffset		= 10		// The horizontal margin 
	vOffset		= 10		// The vertical distance between the GUIs of two subsequent GECs
	
	adjustViewDomain wId pSt
		= case accPIO (getWindow wId) pSt of
			(Just wSt,pSt)
				# topLevelIds	= [fromJust mId \\ (_,mId)<-getControlTypes wSt | isJust mId]
				# topLevelSizes	= map (\id -> (\{w,h} -> (w,h)) (snd (getControlOuterSize id wSt))) topLevelIds
				# (ws,hs)		= unzip topLevelSizes
				# (w, h)		= (maxList [0:ws] + hOffset,sum hs + (length ws)*vOffset)
				# pSt			= appPIO (setWindowViewDomain wId {zero & corner2={x=w,y=h}}) pSt
				= pSt
			(Nothing, pSt)
				= abort "Could not access WState from window."


searchWindowIdWithTitle :: String (IOSt .ps) -> (Maybe Id,IOSt .ps)
searchWindowIdWithTitle title ioSt
	# (id_types,ioSt)		= getWindowStack ioSt
	# ids					= map fst id_types
	# (maybe_titles,ioSt)	= seqList (map getWindowTitle ids) ioSt
	# titles				= map fromJust maybe_titles
	# title_index			= titles ?? title
	| title_index < 0		// title does not occur
		= (Nothing,ioSt)
	| otherwise
		= (Just (ids !! title_index),ioSt)
where
	(??) infixl 9 :: ![a] a -> Int | == a 
	(??) list x 
	    = searchIndex list 0 x 
	where 
	    searchIndex :: ![a] !Int a -> Int | == a 
	    searchIndex [] _ _ 
	        = -1 
	    searchIndex [x:xs] i y 
	        | x==y      = i 
	        | otherwise = searchIndex xs (i+1) y

createDummyGEC :: OutputOnly a (Update a (PSt .ps)) *(PSt .ps) -> *((GECVALUE a *(PSt .ps)),*(PSt .ps))
createDummyGEC outputOnly a userUpdate pSt
#	(myStore,pSt)	=	openStoreId pSt
#	(_,pSt)			=	openStore myStore (Just a) pSt
= 	({ gecOpen    = id
	, gecClose    = id
	, gecOpenGUI  = \_ -> id
	, gecCloseGUI = \_ -> id
	, gecGetValue = readStore myStore
	, gecSetValue = update myStore
	, gecSwitch   = \_ _-> id
	, gecArrange  = \_ _ -> id
	, gecOpened   = \env -> (True,env)
	},pSt)
where
	update myStore YesUpdate na pst 
	# pst = writeStore myStore na pst
	= userUpdate Changed na pst
	update myStore _ na pst = writeStore myStore na pst

createMouseGEC :: String OutputOnly (Update MouseState (PSt .ps)) *(PSt .ps) -> *((GECVALUE MouseState *(PSt .ps)),*(PSt .ps)) 
createMouseGEC title outputOnly userUpdate pSt
	# (objId,pSt)	= openOBJECTControlId pSt
	= case accPIO (searchWindowIdWithTitle title) pSt of
		(Nothing,pSt)
			#	(id,pSt)	= openId pSt
			#	(_,pSt)		= openWindow undef 
								(Window title NilLS 
											[	WindowId id
											, 	WindowViewSize {w=600,h=350}
											, 	WindowLook     True stdUnfillNewFrameLook
											, 	WindowPen      [PenBack defWindowBackColour]
											,	WindowHScroll  (stdScrollFunction Horizontal 20)
											,	WindowVScroll  (stdScrollFunction Horizontal 20)
											,	WindowViewDomain {zero & corner2={x=600,y=350}}
											,	WindowMouse (const True) Able (noLS1 (mymouse))
											]) pSt
			=	createDummyGEC outputOnly MouseLost userUpdate pSt
		(Just id,pSt)
			= 	createDummyGEC outputOnly MouseLost userUpdate pSt
where
	mymouse mousestate pst = userUpdate Changed mousestate pst 

	why_changed wId reason t pSt = adjustViewDomain wId (userUpdate reason t pSt)
	
	hOffset		= 10		// The horizontal margin 
	vOffset		= 10		// The vertical distance between the GUIs of two subsequent GECs
	
	adjustViewDomain wId pSt
		= case accPIO (getWindow wId) pSt of
			(Just wSt,pSt)
				# topLevelIds	= [fromJust mId \\ (_,mId)<-getControlTypes wSt | isJust mId]
				# topLevelSizes	= map (\id -> (\{w,h} -> (w,h)) (snd (getControlOuterSize id wSt))) topLevelIds
				# (ws,hs)		= unzip topLevelSizes
				# (w, h)		= (maxList [0:ws] + hOffset,sum hs + (length ws)*vOffset)
				# pSt			= appPIO (setWindowViewDomain wId {zero & corner2={x=w,y=h}}) pSt
				= pSt
			(Nothing, pSt)
				= abort "Could not access WState from window."

createDGEC :: String OutputOnly Bool a  *(PSt .ps) -> (a,*(PSt .ps)) | gGEC{|*|} a & bimap{|*|} ps
createDGEC title outputOnly hasOBJECT initval pSt
	# (objId,pSt)	= openOBJECTControlId pSt
	# (id,pSt)	= openId pSt
	# (rid,pSt)	= openRId pSt
	# ((_,Just lst),pSt)	= openModalDialog initval 
					(Dialog title  (Receiver rid receiverfun [])
							[	WindowId id
							, 	WindowViewSize {w=600,h=350}
							, 	WindowLook     True stdUnfillNewFrameLook
							, 	WindowPen      [PenBack defWindowBackColour]
							,	WindowHScroll  (stdScrollFunction Horizontal 20)
							,	WindowVScroll  (stdScrollFunction Horizontal 20)
							,	WindowViewDomain {zero & corner2={x=600,y=350}}
							,	WindowInit		(createEditor rid id objId)
							,	WindowClose	   (\(ls,ps) -> (ls,closeWindow id ps))
							]) pSt
	= (lst,pSt)
where
	createEditor rid id objId (ls,pSt)
	#	guiLoc			= {guiId=id,guiItemPos=(Left,OffsetVector {vy=vOffset, vx=hOffset})}
	# 	(handlA,pSt)	= openGECVALUE (guiLoc,objId) outputOnly hasOBJECT (Just initval) (myupdate rid) pSt
	# 	pSt 			= handlA.gecOpenGUI (guiLoc,objId) pSt
	= handlA.gecGetValue pSt

	myupdate rid r a pst 
	# (_,pst) =	asyncSend rid a pst
	=pst

	hOffset		= 10		// The horizontal margin 
	vOffset		= 10		// The vertical distance between the GUIs of two subsequent GECs
	
receiverfun:: a (a,*(PSt .ps)) -> (a,*(PSt .ps))
receiverfun na (a,pst) = (na,pst)
