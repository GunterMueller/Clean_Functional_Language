implementation module layoutGEC

import genericgecs, guigecs, infragecs, StdGECExt
import StdEnv

// (,) is used to place editors next to each other

gGEC{|(,)|} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a,b) -> PAIR a b, map_from = \(PAIR a b) -> (a,b)}

	myGECGUI = spairGECGUI`
	where
		spairGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [(id1,Nothing,Nothing),(id2,Just (RightToPrev,zero),Nothing)] undef NilLS (const id) outputOnly pSt
//			= customGECGUIFun Nothing [(id1,Just (Left,zero),Nothing),(id2,Just (RightToPrev,zero),Nothing)] undef NilLS (const id) outputOnly pSt
//			= customGECGUIFun Nothing [(id1,Just (Left,zero),Just (Right,zero)),(id2,Nothing,Just (Right,zero))] undef NilLS (const id) outputOnly pSt

gGEC{|(,,)|} gGECa gGECb gGECc gecArgs=:{gec_value=tuple3,update=tuple3update} pSt
	= convert (gGEC{|*->*->*|} gGECa (gGEC{|*->*->*|}gGECb gGECc) {gecArgs & gec_value=tuple2,update=tuple2update} pSt)
where
	tuple2 = case tuple3 of
				Just (a,b,c) = Just (a,(b,c))
				Nothing	   = Nothing

	convert (tuple2handle,pst) = ({tuple2handle & gecSetValue = tuple3SetValue tuple2handle.gecSetValue
	                                        , gecGetValue = tuple3GetValue tuple2handle.gecGetValue
	                            },pst)
	
	tuple2update reason (a,(b,c)) pst = tuple3update reason (a,b,c) pst

	tuple3SetValue tuple2SetValue upd (a,b,c)  = tuple2SetValue upd (a,(b,c))
	tuple3GetValue tuple2GetValue pst
		# ((a,(b,c)),pst) = tuple2GetValue pst
		= ((a,b,c),pst)

// Below Left

gGEC{| <|*> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <|*> b) = PAIR a b, map_from = \(PAIR a b) = a <|*> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Center,zero),Nothing)
									  , (id2,Just (BelowPrev,OffsetAlign AlignLeft),Nothing)
									  ] undef NilLS (const id) outputOnly pSt

// Below Center
			
gGEC{| <|*|> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <|*|> b) = PAIR a b, map_from = \(PAIR a b) = a <|*|> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Center,zero),Nothing)
									  , (id2,Just (BelowPrev,OffsetAlign AlignCenter),Nothing)
									  ] undef NilLS (const id) outputOnly pSt
									  
// Below Right

gGEC{| <*|> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <*|> b) = PAIR a b, map_from = \(PAIR a b) = a <*|> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Center,zero),Nothing)
									  , (id2,Just (BelowPrev,OffsetAlign AlignRight),Nothing)
									  ] undef NilLS (const id) outputOnly pSt

// Right Top

gGEC{| <^*> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <^*> b) = PAIR a b, map_from = \(PAIR a b) = a <^*> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Left,zero),Nothing)
									  , (id2,Just (RightToPrev,OffsetAlign AlignTop),Nothing)
									  ] undef NilLS (const id) outputOnly pSt
// Right Center
			
gGEC{| <-*> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <-*> b) = PAIR a b, map_from = \(PAIR a b) = a <-*> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Left,zero),Nothing)
									  , (id2,Just (RightToPrev,OffsetAlign AlignCenter),Nothing)
									  ] undef NilLS (const id) outputOnly pSt

// Right Bottom

gGEC{| <.*> |} gGECa gGECb gecArgs pSt
	= convertPair bimap myGECGUI gGECa gGECb gecArgs pSt
where
	bimap = {map_to = \(a <.*> b) = PAIR a b, map_from = \(PAIR a b) = a <.*> b}

	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Left,zero),Nothing)
									  , (id2,Just (RightToPrev,OffsetAlign AlignBottom),Nothing)
									  ] undef NilLS (const id) outputOnly pSt





convertPair:: (Bimap (t a b)(PAIR a b)) (GECGUIFun (PAIR a b) (PSt .ps))  
					(TgGEC a *(PSt .ps)) (TgGEC b *(PSt .ps))
						(GECArgs (t a b) *(PSt .ps)) *(PSt .ps) -> *(!GECVALUE (t a b) *(PSt .ps),!*(PSt .ps))
	
convertPair bimap myGECGUI  gGECa gGECb gecArgs=:{gec_value=mtuple,update=tabupdate} pSt
	= convert (pairGEC myGECGUI gGECa gGECb {gecArgs & gec_value=mpair,update=pupdate} pSt)
where
	mpair = case mtuple of
				Nothing	 = Nothing
				Just tab = Just (bimap.map_to tab)

	pupdate reason pab pst = tabupdate reason (bimap.map_from pab) pst

	convert (pairhandle,pst) = ({pairhandle & gecSetValue = tupleSetValue pairhandle.gecSetValue
	                                        , gecGetValue = tupleGetValue pairhandle.gecGetValue
	                            },pst)
	
	tupleSetValue pairSetValue upd tab  = pairSetValue upd (bimap.map_to tab)
	tupleGetValue pairGetValue pst
		# (pab,pst) = pairGetValue pst
		= (bimap.map_from pab,pst)

/*
gGEC{| <^|^> |} gGECa gGECb gecArgs=:{gec_value=mtuple,update=tupdate} pSt
	= convert (pairGEC myGECGUI gGECa gGECb {gecArgs & gec_value=mpair,update=pupdate} pSt)
where
	mpair = case mtuple of
				Just (a <^|^> b) = Just (PAIR a b)
				Nothing	   		 = Nothing

	pupdate reason (PAIR a b) pst = tupdate reason (a <^|^> b) pst

	convert (pairhandle,pst) = ({pairhandle & gecSetValue = tupleSetValue pairhandle.gecSetValue
	                                        , gecGetValue = tupleGetValue pairhandle.gecGetValue
	                            },pst)
	
	tupleSetValue pairSetValue upd (a <^|^> b)  = pairSetValue upd (PAIR a b)
	tupleGetValue pairGetValue pst
		# (PAIR a b,pst) = pairGetValue pst
		= ((a <^|^> b),pst)


	myGECGUI :: GECGUIFun (PAIR a b) (PSt .ps)
	myGECGUI = myGECGUI`
	where
		myGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [ (id1,Just (Center,zero),Just (Center,zero))
									  , (id2,Just (Center,zero),Just (Center,zero))
									  ] undef NilLS (const id) outputOnly pSt


gGEC{|(,)|} gGECa gGECb gecArgs=:{gec_value=mtuple,update=tupdate} pSt
	= convert (pairGEC spairGECGUI gGECa gGECb {gecArgs & gec_value=mpair,update=pupdate} pSt)
where
	mpair = case mtuple of
				Just (a,b) = Just (PAIR a b)
				Nothing	   = Nothing

	pupdate reason (PAIR a b) pst = tupdate reason (a,b) pst

	convert (pairhandle,pst) = ({pairhandle & gecSetValue = tupleSetValue pairhandle.gecSetValue
	                                        , gecGetValue = tupleGetValue pairhandle.gecGetValue
	                            },pst)
	
	tupleSetValue pairSetValue upd (a,b)  = pairSetValue upd (PAIR a b)
	tupleGetValue pairGetValue pst
		# (PAIR a b,pst) = pairGetValue pst
		= ((a,b),pst)


	spairGECGUI :: GECGUIFun (PAIR a b) (PSt .ps)
	spairGECGUI = spairGECGUI`
	where
		spairGECGUI` outputOnly pSt
			# (id1,pSt)	= openId pSt
			# (id2,pSt)	= openId pSt
			= customGECGUIFun Nothing [(id1,Just (Left,zero),Just (Right,zero)),(id2,Nothing,Just (Right,zero))] undef NilLS (const id) outputOnly pSt*/									  			