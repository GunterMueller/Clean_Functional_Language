implementation module infragecs

import StdBool, StdFunc, StdList, StdMisc, StdTuple
import StdPSt, StdPStClass
import GenDefaultVal, guiloc, guigecs, TRACE

//import StdBimap XXX
derive bimap GECArgs, Maybe

::	BasicSt t env
	=	{	basicVisible     :: !Bool
		,	basicGUILoc      :: !GUILoc
		,	basicOBJECTLoc   :: !OBJECTControlId
		,	basicValue	     :: !t
		}
::	UNITSt env
	=	{	unitVisible      :: !Bool
		,	unitGUILoc       :: !GUILoc
		,	unitOBJECTLoc    :: !OBJECTControlId
		}
::	OBJECTSt a env
	=	{	objectVisible    :: !Bool
		,	objectGUILoc     :: !GUILoc
		,	objectOBJECTLoc  :: !OBJECTControlId
		,	objectGECVALUE   :: GECVALUE a env
		}
::	CONSSt a env
	=	{	consVisible      :: !Bool
		,	consGUILoc       :: !GUILoc
		,	consOBJECTLoc    :: !OBJECTControlId
		,	consGECVALUE     :: GECVALUE a env
		,	consActive       :: !Bool
		,	consOpened		 :: !Bool
		}
::	FIELDSt a env
	=	{	fieldVisible     :: !Bool
		,	fieldGUILoc      :: !GUILoc
		,	fieldOBJECTLoc   :: !OBJECTControlId
		,	fieldGECVALUE    :: GECVALUE a env
		}
::	PAIRSt a b env
	=	{	pairVisible      :: !Bool
		,	pairGUILoc       :: !GUILoc
		,	pairOBJECTLoc    :: !OBJECTControlId
		,	pair1GECVALUE    :: GECVALUE a env
		,	pair2GECVALUE    :: GECVALUE b env
		}
::	EITHERSt a b env
	=	{	eitherVisible    :: !Bool
		,	eitherGUILoc     :: !GUILoc
		,	eitherOBJECTLoc  :: !OBJECTControlId
		,	either1GECVALUE  :: GECVALUE a env
		,	either2GECVALUE  :: GECVALUE b env
		,	eitherGoLeft     :: !Bool
		}

unitGEC :: !(GECGUIFun UNIT (PSt .ps)) -> TgGEC UNIT (PSt .ps)
unitGEC gecguiFun = unitGEC` gecguiFun
where
	unitGEC` gecguiFun gecArgs=:{location=(guiLoc,objLoc),makeUpValue,outputOnly,update} pSt
		# lSt = {unitVisible=False, unitGUILoc=guiLoc, unitOBJECTLoc=objLoc}
		= GEC "UNIT" gecguiFun unitFun outputOnly lSt pSt
	where
		update` r x y				= TRACE (("update UNIT",r,x)) (update r x y)
	
		unitFun _ _ InGetValue (lSt,pSt)
			# pSt					= TRACE (gGECtraceGetValue "UNIT") pSt
			= (OutGetValue UNIT,(lSt,pSt))
		unitFun {guiUpdate} uGEC msg=:(InSetValue yesUpdate v) (lSt=:{unitVisible},pSt)
			# pSt					= TRACE ("gGEC{|UNIT|}",msg) pSt
			# pSt					= if unitVisible (guiUpdate UNIT pSt) pSt
			# pSt					= if (yesUpdate === YesUpdate) (update` Changed UNIT pSt) pSt
			= (OutDone,(lSt,pSt))
		unitFun _ _ msg=:InOpenGEC st
			= TRACE ("gGEC{|UNIT|}",msg) (OutDone,st)
		unitFun {guiClose} uGEC InCloseGEC (lSt=:{unitVisible},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC "UNIT") pSt
			# pSt					= guiClose pSt
			# pSt					= appPIO (closeReceiver (GECIdtoId uGEC)) pSt
			# lSt					= {lSt & unitVisible=False}
			= (OutDone,(lSt,pSt))
		unitFun uGECGUI=:{guiOpen} uGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{unitVisible,unitGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|UNIT|}",msg) pSt
			| unitVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt) 
									                (snd (unitFun uGECGUI uGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# pSt				= guiOpen guiLoc pSt
				# lSt				= {lSt & unitVisible=True,unitGUILoc=guiLoc,unitOBJECTLoc=objLoc}
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==unitGUILoc
		unitFun {guiClose} _ (InCloseGUI _) (lSt=:{unitVisible},pSt)
			# pSt					= TRACE (gGECtraceCloseGUI "UNIT") pSt
			# pSt					= guiClose pSt
			# lSt					= {lSt & unitVisible=False}
			= (OutDone,(lSt,pSt))
		unitFun _ _ (InSwitchCONS u p) st
			= TRACE (gGECtraceSwitchCONS "UNIT" u p) (OutDone,st)
		unitFun _ _ (InArrangeCONS a p) st
			= TRACE (gGECtraceArrangeCONS "UNIT" a p) (OutDone,st)
		unitFun _ _ _ st
			= TRACE (gGECtraceDefault "UNIT") (OutDone,st)

pairGEC :: !(GECGUIFun (PAIR a b) (PSt .ps)) 
           !(TgGEC        a    (PSt .ps))
           !(TgGEC          b  (PSt .ps)) 
        -> TgGEC    (PAIR a b) (PSt .ps)
pairGEC gecguiFun gGECa gGECb = pairGEC` gecguiFun gGECa gGECb
where
	pairGEC` gecguiFun gGECa gGECb gecArgs=:{location=(guiLoc,objLoc),outputOnly,gec_value=mpair,update} pSt
		# lSt =
			{ pairVisible   = False
			, pairGUILoc    = guiLoc
			, pairOBJECTLoc = objLoc
			, pair1GECVALUE = undef
			, pair2GECVALUE = undef
			}
		= GEC "PAIR" gecguiFun pairFun outputOnly lSt pSt
	where
		update` r x y				= TRACE (("update PAIR",r,x)) (update r x y)
		(ma,mb)						= (mapMaybe leftPAIR mpair,mapMaybe rightPAIR mpair)
		
		pairFun _ _ InGetValue (lSt=:{pair1GECVALUE,pair2GECVALUE},pSt)
			# pSt				= TRACE (gGECtraceGetValue "PAIR") pSt
			# (a,pSt)			= pair1GECVALUE.gecGetValue pSt
			# (b,pSt)			= pair2GECVALUE.gecGetValue pSt
			= (OutGetValue (PAIR a b),(lSt,pSt))
		pairFun {guiUpdate} _ msg=:(InSetValue yesUpdate v=:(PAIR a b)) (lSt=:{pairVisible,pair1GECVALUE,pair2GECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|PAIR|}",msg) pSt
			# pSt				= pair1GECVALUE.gecSetValue NoUpdate a pSt
			# pSt				= pair2GECVALUE.gecSetValue NoUpdate b pSt
			# pSt				= if pairVisible (guiUpdate v pSt) pSt
			# pSt				= if (yesUpdate === YesUpdate) (update` Changed v pSt) pSt
			= (OutDone,(lSt,pSt))
		pairFun {guiLocs} pGEC msg=:InOpenGEC (lSt=:{pairGUILoc,pairOBJECTLoc},pSt)
			= (OutDone,(lSt1,pSt3))
		where
			pSt1					= TRACE ("gGEC{|PAIR|}",msg) pSt
			[aLoc,bLoc:_]			= guiLocs (pairGUILoc,pairOBJECTLoc)
			(setA,pSt2)				= gGECa {gecArgs & location=aLoc,gec_value=ma,update=updatePAIRA setB} pSt1
			(setB,pSt3)				= gGECb {gecArgs & location=bLoc,gec_value=mb,update=updatePAIRB setA} pSt2
			lSt1					= { lSt & pair1GECVALUE=setA, pair2GECVALUE=setB }
		pairFun {guiClose} pGEC InCloseGEC (lSt=:{pairVisible,pair1GECVALUE,pair2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC "PAIR") pSt
			# pSt				= guiClose pSt
			# pSt				= pair1GECVALUE.gecClose pSt
			# pSt				= pair2GECVALUE.gecClose pSt
			# pSt				= appPIO (closeReceiver (GECIdtoId pGEC)) pSt
			# lSt				= {lSt & pairVisible=False}
			= (OutDone,(lSt,pSt))
		pairFun pGUIGEC=:{guiLocs,guiOpen} pGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{pairVisible,pairGUILoc,pair1GECVALUE,pair2GECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|PAIR|}",msg) pSt
			| pairVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt)
									                (snd (pairFun pGUIGEC pGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# [aLoc,bLoc:_]		= guiLocs (guiLoc,objLoc)
				# pSt				= guiOpen guiLoc pSt
				# pSt				= pair1GECVALUE.gecOpenGUI aLoc pSt
				# pSt				= pair2GECVALUE.gecOpenGUI bLoc pSt
				# lSt				= {lSt & pairVisible=True,pairGUILoc=guiLoc,pairOBJECTLoc=objLoc}
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==pairGUILoc
		pairFun {guiClose} _ (InCloseGUI keepActiveCONS) (lSt=:{pairVisible,pair1GECVALUE,pair2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGUI "PAIR") pSt
			# pSt				= guiClose pSt
			# pSt				= pair1GECVALUE.gecCloseGUI keepActiveCONS pSt
			# pSt				= pair2GECVALUE.gecCloseGUI keepActiveCONS pSt
			# lSt				= {lSt & pairVisible=False}
			= (OutDone,(lSt,pSt))
		pairFun _ _ (InSwitchCONS u p) st
			= TRACE (gGECtraceSwitchCONS "PAIR" u p) (OutDone,st)
		pairFun _ _ (InArrangeCONS a p) st
			= TRACE (gGECtraceArrangeCONS "PAIR" a p) (OutDone,st)
		pairFun _ _ _ st
			= TRACE (gGECtraceDefault "PAIR") (OutDone,st)
		
//		updatePAIRA (_,setB) reason a pSt
		updatePAIRA setB reason a pSt
			# (b,pSt)				= setB.gecGetValue pSt
			= update` reason (PAIR a b) pSt
//		updatePAIRB (setA,_) reason b pSt
		updatePAIRB setA reason b pSt
			# (a,pSt)				= setA.gecGetValue pSt
			= update` reason (PAIR a b) pSt

objectGEC :: !GenericTypeDefDescriptor 
             !(GECId     (OBJECT a)) 
             !(GECGUIFun (OBJECT a) (PSt .ps)) 
             !(TgGEC  a          (PSt .ps))
           -> TgGEC   (OBJECT a) (PSt .ps)
objectGEC t tGEC gecguiFun gGECa = objectGEC` t tGEC gecguiFun gGECa
where
	objectGEC` t tGEC gecguiFun gGECa gecArgs=:{location=(guiLoc,objLoc),outputOnly,gec_value=mcv,update} pSt
		# lSt =
			{ objectVisible  = False 
			, objectGECVALUE = undef
			, objectGUILoc   = guiLoc
			, objectOBJECTLoc= objLoc
			}
		= GEC2 tGEC object_trace_name gecguiFun (objectFun gGECa mv) outputOnly lSt pSt
	where
		object_trace_name			= "OBJECT "+++t.gtd_name
		update` r x y				= TRACE (("update "+++object_trace_name,r,x)) (update r x y)
	
		updateOBJECTA reason a pSt
			= update` reason (OBJECT a) pSt
	
		mv							= case mcv of
										Just (OBJECT x) = Just x
										_               = Nothing
		
		objectFun _ _ _ _ InGetValue (lSt=:{objectGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceGetValue object_trace_name) pSt
			# (bound,pSt)			= objectGECVALUE.gecOpened pSt
			| bound
				# (a,pSt)			= objectGECVALUE.gecGetValue pSt
				= (OutGetValue (OBJECT a),(lSt,pSt))
			| otherwise
				= abort ("gGEC{|"+++object_trace_name+++"|}: handling request for InGetValue failed: no child GEC.")
		objectFun gGECa _ tGEC _ msg=:(InSetValue yesUpdate v=:(OBJECT a)) (lSt=:{objectVisible,objectGECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|"+++object_trace_name+++"|}",msg) pSt
			# pSt				= objectGECVALUE.gecSetValue NoUpdate a pSt
			# pSt				= if (yesUpdate === YesUpdate) (update` Changed v pSt) pSt
			= (OutDone,(lSt,pSt))
		objectFun gGECa mv {guiLocs} tGEC msg=:InOpenGEC (lSt=:{objectGUILoc,objectOBJECTLoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++object_trace_name+++"|}",msg) pSt
			# [aLoc:_]				= guiLocs (objectGUILoc,objectOBJECTLoc)
			# (setA,pSt)			= gGECa {gecArgs & location=aLoc, gec_value=mv,update=updateOBJECTA} pSt
			# lSt					= {lSt & objectGECVALUE=setA}
			= (OutDone,(lSt,pSt))
		objectFun _ _ {guiClose} tGEC InCloseGEC (lSt=:{objectVisible,objectGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC object_trace_name) pSt
			# pSt					= if objectVisible (guiClose pSt) pSt
			# pSt					= appPIO (closeReceiver (GECIdtoId tGEC)) pSt
			# lSt					= {lSt & objectVisible=False}
			# (bound,pSt)			= objectGECVALUE.gecOpened pSt
			| bound
				# pSt				= objectGECVALUE.gecClose pSt
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		objectFun gGECa mv tGUIGEC=:{guiLocs,guiOpen} tGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{objectVisible,objectGECVALUE,objectGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++object_trace_name+++"|}",msg) pSt
			| objectVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt)
									                (snd (objectFun gGECa mv tGUIGEC tGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# [aLoc:_]			= guiLocs (guiLoc,objLoc)
				# pSt				= guiOpen guiLoc pSt
				# pSt				= objectGECVALUE.gecOpenGUI aLoc pSt
				# lSt				= {lSt & objectVisible=True,objectGUILoc=guiLoc,objectOBJECTLoc=objLoc}
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==objectGUILoc
		objectFun _ _ {guiClose} _ msg=:(InCloseGUI _) (lSt=:{objectVisible,objectGECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|"+++object_trace_name+++"|}",msg,"objectVisible:",objectVisible) pSt
			# pSt				= guiClose pSt
			# pSt				= objectGECVALUE.gecCloseGUI SkipCONS pSt
			# lSt				= {lSt & objectVisible=False}
			= (OutDone,(lSt,pSt))
		objectFun _ _ _ _ (InSwitchCONS upd path) (lSt=:{objectGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceSwitchCONS object_trace_name upd path) pSt
			# pSt				= objectGECVALUE.gecSwitch upd path pSt
			= (OutDone,(lSt,pSt))
		objectFun _ _ _ _ (InArrangeCONS arr path) (lSt=:{objectGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceArrangeCONS object_trace_name arr path) pSt
			# pSt				= objectGECVALUE.gecArrange arr path pSt
			= (OutDone,(lSt,pSt))
		objectFun _ _ _ _ _ st
			= TRACE (gGECtraceDefault object_trace_name) (OutDone,st)

consGEC :: !GenericConsDescriptor
           !(GECGUIFun (CONS a) (PSt .ps)) 
           !(TgGEC  a        (PSt .ps))
        -> TgGEC    (CONS a) (PSt .ps)
consGEC d gecguiFun gGECa = consGEC` d gecguiFun gGECa
where
	consGEC` d gecguiFun gGECa gecArgs=:{location=(guiLoc,objLoc),makeUpValue,outputOnly,gec_value=mcv,update} pSt
		# lSt =
			{ consVisible    = False 
			, consGUILoc     = guiLoc
			, consOBJECTLoc  = objLoc
			, consActive     = isActive
			, consGECVALUE   = undef
			, consOpened		= False
			}
		= GEC cons_trace_name gecguiFun (consFun gGECa mv) outputOnly lSt pSt
	where
		cons_trace_name				= "CONS "+++d.gcd_name
		update` r x y				= TRACE (("update "+++cons_trace_name,r,x)) (update r x y)
	
		updateCONSA reason a pSt
			= update` reason (CONS a) pSt
	
		mv							= case mcv of
										Just (CONS x) = Just x
										_             = Nothing
		isActive					= isJust mv || makeUpValue
		
		consFun _ _ _ _ InGetValue (lSt=:{consGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceGetValue cons_trace_name) pSt
			# (bound,pSt)			= consGECVALUE.gecOpened pSt
			| bound
				# (a,pSt)			= consGECVALUE.gecGetValue pSt
				= (OutGetValue (CONS a),(lSt,pSt))
			| otherwise
				= abort ("gGEC{|"+++cons_trace_name+++"|}: handling request for InGetValue failed: no child GEC.")
		consFun gGECa mv cGECGUI cGEC msg=:(InSetValue yesUpdate v=:(CONS a)) (lSt,pSt)
			# pSt					= TRACE ("gGEC{|"+++cons_trace_name+++"|}",msg) pSt
			# (lSt=:{consGECVALUE},pSt)
									= snd (consFun gGECa mv cGECGUI cGEC (InSwitchCONS NoUpdate []) (lSt,pSt))
			# pSt					= consGECVALUE.gecSetValue NoUpdate a pSt
			# pSt					= if (yesUpdate === YesUpdate) (update` Changed v pSt) pSt
			= (OutDone,(lSt,pSt))
		consFun gGECa mv {guiLocs} cGEC msg=:InOpenGEC (lSt=:{consActive,consGUILoc,consOBJECTLoc,consGECVALUE,consOpened},pSt)
			# pSt					= TRACE ("gGEC{|"+++cons_trace_name+++"|}",msg) pSt
			# (bound,pSt)			= if consOpened (consGECVALUE.gecOpened pSt) (False,pSt)
			| consActive && not bound
				# [aLoc:_]			= guiLocs (consGUILoc,consOBJECTLoc)
				# (setA,pSt)		= gGECa {gecArgs & location=aLoc, makeUpValue=True,gec_value=mv,update=updateCONSA} pSt
				# lSt				= {lSt & consGECVALUE=setA, consOpened=True}
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		consFun _ _ {guiClose} cGEC InCloseGEC (lSt=:{consVisible,consGECVALUE,consOpened},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC cons_trace_name) pSt
			# pSt					= if consVisible (guiClose pSt) pSt
			# pSt					= appPIO (closeReceiver (GECIdtoId cGEC)) pSt
			# lSt					= {lSt & consVisible=False}
			| not consOpened
				= (OutDone,(lSt,pSt))
			# (bound,pSt)			= consGECVALUE.gecOpened pSt
			| bound
				# pSt				= consGECVALUE.gecClose pSt
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		consFun gGECa mv cGECGUI=:{guiOpen,guiLocs} cGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{consVisible,consActive,consGECVALUE,consGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++cons_trace_name+++"|}",msg,"consVisible:",consVisible,"consActive:",consActive) pSt
			| consVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			# (lSt,pSt)				= if sameGUILoc (lSt,pSt)
									                (snd (consFun gGECa mv cGECGUI cGEC (InCloseGUI SkipCONS) (lSt,pSt)))
			| consActive
				# pSt				= selectOBJECTControlItem objLoc (d.gcd_index+1) pSt
				# pSt				= guiOpen guiLoc pSt
				# [aLoc:_]			= guiLocs (guiLoc,objLoc)
				# pSt			= consGECVALUE.gecOpenGUI aLoc pSt
				# lSt			= {lSt & consGUILoc=guiLoc,consOBJECTLoc=objLoc,consVisible=True}
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==consGUILoc
		consFun _ _ {guiClose} _ (InCloseGUI keepActiveCONS) (lSt=:{consVisible,consActive,consGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGUI cons_trace_name) pSt
			# pSt					= guiClose pSt
			# lSt					= {lSt & consVisible=False,consActive=if (keepActiveCONS === InactivateCONS) False consActive}
			| consActive
				# pSt			= consGECVALUE.gecCloseGUI SkipCONS pSt
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		consFun gGECa mv cGECGUI cGEC (InSwitchCONS upd path) (lSt=:{consGUILoc,consVisible},pSt)
			# pSt					= TRACE (gGECtraceSwitchCONS cons_trace_name upd path) pSt
			| not (isEmpty path)		// path not fully traversed: this is an error.
				= abort ("gGEC{|"+++cons_trace_name+++"|}: handling request for InSwitchCONS failed: path not empty.")
			| consVisible			// already visible: nothing to do
				= (OutDone,(lSt,pSt))
			| otherwise
				# lSt				= {lSt & consActive=True}
				# (lSt=:{consGUILoc,consOBJECTLoc},pSt)
									= snd (consFun gGECa mv cGECGUI cGEC  InOpenGEC (lSt,pSt))
				# (lSt=:{consGECVALUE},pSt)
									= snd (consFun gGECa mv cGECGUI cGEC (InOpenGUI consGUILoc consOBJECTLoc) (lSt,pSt))
				# (a,pSt)		= consGECVALUE.gecGetValue pSt
				# pSt			= if (upd===YesUpdate) (updateCONSA Changed a pSt) pSt
				= (OutDone,(lSt,pSt))
		consFun gGECa mv cGECGUI cGEC (InArrangeCONS arr path) st=:({consGUILoc,consOBJECTLoc},pSt)
			# st					= TRACE (gGECtraceArrangeCONS cons_trace_name arr path) st
			| not (isEmpty path)		// path not fully traversed: this is an error.
				= abort ("gGEC{|"+++cons_trace_name+++"|}: handling request for InArrangeCONS failed: path not empty.")
			| arr === ArrangeShow
				= consFun gGECa mv cGECGUI cGEC (InOpenGUI consGUILoc consOBJECTLoc) st
			| arr === ArrangeHide
				= consFun gGECa mv cGECGUI cGEC (InCloseGUI SkipCONS) st
			| otherwise
				= TRACE ("gGEC{|"+++cons_trace_name+++"|}: missing Arrangement alternative: "+++printToString arr+++".") (OutDone,st)
		consFun _ _ _ _ _ st
			= TRACE (gGECtraceDefault cons_trace_name) (OutDone,st)

fieldGEC :: !GenericFieldDescriptor
            !(GECGUIFun (FIELD a) (PSt .ps)) 
            !(TgGEC  a         (PSt .ps)) 
         -> TgGEC    (FIELD a) (PSt .ps)
fieldGEC t gecguiFun gGECa = fieldGEC` t gecguiFun gGECa 
where
	fieldGEC` t gecguiFun gGECa gecArgs=:{location=(guiLoc,objLoc),makeUpValue,outputOnly,gec_value=mcv,update} pSt
		# lSt =
			{ fieldVisible  = False 
			, fieldGECVALUE = undef
			, fieldGUILoc   = guiLoc
			, fieldOBJECTLoc= objLoc
			}
		= GEC field_trace_name gecguiFun (fieldFun gGECa mv) outputOnly lSt pSt
	where
		field_trace_name			= "FIELD "+++t.gfd_name
		update` r x y				= TRACE (("update "+++field_trace_name,r,x)) (update r x y)
	
		updateFIELDA reason a pSt
			= update` reason (FIELD a) pSt
	
		mv							= case mcv of
										Just (FIELD x) = Just x
										_              = Nothing
		
		fieldFun _ _ _ _ InGetValue (lSt=:{fieldGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceGetValue field_trace_name) pSt
			# (bound,pSt)			= fieldGECVALUE.gecOpened pSt
			| bound
				# (a,pSt)			= fieldGECVALUE.gecGetValue pSt
				= (OutGetValue (FIELD a),(lSt,pSt))
			| otherwise
				= abort ("gGEC{|"+++field_trace_name+++"|}: handling request for InGetValue failed: no child GEC.")
		fieldFun _ _ _ tGEC msg=:(InSetValue yesUpdate v=:(FIELD a)) (lSt=:{fieldVisible,fieldGECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|"+++field_trace_name+++"|}",msg) pSt
			# pSt				= fieldGECVALUE.gecSetValue NoUpdate a pSt
			# pSt				= if (yesUpdate === YesUpdate) (update` Changed v pSt) pSt
			= (OutDone,(lSt,pSt))
		fieldFun gGECa mv {guiLocs} tGEC msg=:InOpenGEC (lSt=:{fieldGUILoc,fieldOBJECTLoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++field_trace_name+++"|}",msg) pSt
			# [aLoc:_]				= guiLocs (fieldGUILoc,fieldOBJECTLoc)
			# (setA,pSt)			= gGECa {gecArgs & location=aLoc,gec_value=mv,update=updateFIELDA} pSt
			# lSt					= {lSt & fieldGECVALUE=setA}
			= (OutDone,(lSt,pSt))
		fieldFun _ _ {guiClose} tGEC InCloseGEC (lSt=:{fieldVisible,fieldGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC field_trace_name) pSt
			# pSt					= if fieldVisible (guiClose pSt) pSt
			# pSt					= appPIO (closeReceiver (GECIdtoId tGEC)) pSt
			# lSt					= {lSt & fieldVisible=False}
			# (bound,pSt)			= fieldGECVALUE.gecOpened pSt
			| bound
				# pSt				= fieldGECVALUE.gecClose pSt
				= (OutDone,(lSt,pSt))
			| otherwise
				= (OutDone,(lSt,pSt))
		fieldFun gGECa mv tGUIGEC=:{guiLocs,guiOpen} tGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{fieldVisible,fieldGECVALUE,fieldGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++field_trace_name+++"|}",msg) pSt
			| fieldVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt)
									                (snd (fieldFun gGECa mv tGUIGEC tGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# [aLoc:_]			= guiLocs (guiLoc,objLoc)
				# pSt				= guiOpen guiLoc pSt
				# pSt				= fieldGECVALUE.gecOpenGUI aLoc pSt
				# lSt				= {lSt & fieldVisible=True,fieldGUILoc=guiLoc,fieldOBJECTLoc=objLoc}
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==fieldGUILoc
		fieldFun _ _ {guiClose} _ msg=:(InCloseGUI _) (lSt=:{fieldVisible,fieldGECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|"+++field_trace_name+++"|}",msg,"fieldVisible:",fieldVisible) pSt
			# pSt				= guiClose pSt
			# pSt				= fieldGECVALUE.gecCloseGUI SkipCONS pSt
			# lSt				= {lSt & fieldVisible=False}
			= (OutDone,(lSt,pSt))
		fieldFun _ _ _ _ (InSwitchCONS upd path) (lSt=:{fieldGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceSwitchCONS field_trace_name upd path) pSt
			# pSt				= fieldGECVALUE.gecSwitch upd path pSt
			= (OutDone,(lSt,pSt))
		fieldFun _ _ _ _ (InArrangeCONS arr path) (lSt=:{fieldGECVALUE},pSt)
			# pSt					= TRACE (gGECtraceArrangeCONS field_trace_name arr path) pSt
			# pSt				= fieldGECVALUE.gecArrange arr path pSt
			= (OutDone,(lSt,pSt))
		fieldFun _ _ _ _ _ st
			= TRACE (gGECtraceDefault field_trace_name) (OutDone,st)

eitherGEC :: !(GECGUIFun (EITHER a b) (PSt .ps))
             !(TgGEC          a    (PSt .ps))
             !(TgGEC            b  (PSt .ps)) 
          ->   TgGEC  (EITHER a b) (PSt .ps)
eitherGEC gecguiFun gGECa gGECb = eitherGEC` gecguiFun gGECa gGECb 
where
	eitherGEC` gecguiFun gGECa gGECb gecArgs=:{location=(guiLoc,objLoc),makeUpValue,outputOnly,gec_value=me,update} pSt
		# lSt =
			{ eitherVisible   = False
			, eitherGUILoc    = guiLoc
			, eitherOBJECTLoc = objLoc
			, eitherGoLeft    = goLeft
			, either1GECVALUE = undef
			, either2GECVALUE = undef
			}
		= GEC "EITHER" gecguiFun eitherFun outputOnly lSt pSt
	where
		update` r x y				= TRACE (("update EITHER",x)) (update r x y)
		goLeft						= case me of
										Just (LEFT _) -> True
										_             -> False
		
		eitherFun _ _ InGetValue (lSt=:{eitherGoLeft,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceGetValue "EITHER") pSt
			| eitherGoLeft
				# (a,pSt)	= either1GECVALUE.gecGetValue pSt
				= (OutGetValue (LEFT a),(lSt,pSt))
			| otherwise
				# (b,pSt)	= either2GECVALUE.gecGetValue pSt
				= (OutGetValue (RIGHT b),(lSt,pSt))
		eitherFun {guiUpdate} _ msg=:(InSetValue yesUpdate v) (lSt=:{eitherGoLeft,eitherVisible,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE ("gGEC{|EITHER|}",msg) pSt
			# lSt				= {lSt & eitherGoLeft=goLeft}
			# pSt				= if (eitherGoLeft==goLeft) pSt
								 (if eitherGoLeft (either1GECVALUE.gecCloseGUI InactivateCONS pSt)
								                  (either2GECVALUE.gecCloseGUI InactivateCONS pSt)
								 )
			# pSt				= if goLeft (either1GECVALUE.gecSetValue NoUpdate (leftEITHER  v) pSt)
								            (either2GECVALUE.gecSetValue NoUpdate (rightEITHER v) pSt)
			# pSt				= if eitherVisible (guiUpdate v pSt) pSt
			# pSt				= if (yesUpdate === YesUpdate) (update` Changed v pSt) pSt
			= (OutDone,(lSt,pSt))
		where
			goLeft					= isLEFT v
		eitherFun {guiLocs} eGEC msg=:InOpenGEC (lSt=:{eitherGUILoc,eitherOBJECTLoc},pSt)
			# pSt					= TRACE ("gGEC{|EITHER|}",msg) pSt
			# [aLoc,bLoc:_]			= guiLocs (eitherGUILoc,eitherOBJECTLoc)
			# (setA,pSt)			= gGECa {gecArgs & location=aLoc, makeUpValue = makeUpLeft, gec_value=maybeLEFT  me,update=updateLEFT}  pSt
			# (setB,pSt)			= gGECb {gecArgs & location=bLoc, makeUpValue = makeUpRight,gec_value=maybeRIGHT me,update=updateRIGHT} pSt
			# lSt					= {lSt & either1GECVALUE=setA,either2GECVALUE=setB}
			= (OutDone,(lSt,pSt))
		eitherFun {guiClose} eGEC InCloseGEC (lSt=:{eitherVisible,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC "EITHER") pSt
			# pSt				= guiClose pSt
			# pSt				= either1GECVALUE.gecClose pSt
			# pSt				= either2GECVALUE.gecClose pSt
			# pSt				= appPIO (closeReceiver (GECIdtoId eGEC)) pSt
			# lSt				= {lSt & eitherVisible=False}
			= (OutDone,(lSt,pSt))
		eitherFun eGUIGEC=:{guiLocs,guiOpen} eGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{eitherVisible,eitherGoLeft,either1GECVALUE,either2GECVALUE,eitherGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|EITHER|}",msg,"eitherVisible:",eitherVisible) pSt
			| eitherVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt)
									                (snd (eitherFun eGUIGEC eGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# [aLoc,bLoc:_]		= guiLocs (guiLoc,objLoc)
				# pSt				= guiOpen guiLoc pSt
				# pSt			= either1GECVALUE.gecOpenGUI aLoc pSt
				# pSt			= either2GECVALUE.gecOpenGUI bLoc pSt
				# lSt			= {lSt & eitherVisible=True,eitherGUILoc=guiLoc,eitherOBJECTLoc=objLoc}
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==eitherGUILoc
		eitherFun {guiClose} _ (InCloseGUI keepActiveCONS) (lSt=:{eitherVisible,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceCloseGUI "EITHER") pSt
			# pSt				= guiClose pSt
			# pSt				= either1GECVALUE.gecCloseGUI keepActiveCONS pSt
			# pSt				= either2GECVALUE.gecCloseGUI keepActiveCONS pSt
			# lSt				= {lSt & eitherVisible=False}
			= (OutDone,(lSt,pSt))
		eitherFun _ _ (InSwitchCONS upd path) (lSt=:{eitherGoLeft,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceSwitchCONS "EITHER" upd path) pSt
			| isEmpty path
				= abort "gGEC{|EITHER|}: handling request for InSwitchCONS failed: path is empty."
			| otherwise
				# pSt				= if sameDirection pSt
									 (if eitherGoLeft (either1GECVALUE.gecCloseGUI InactivateCONS pSt)
									                  (either2GECVALUE.gecCloseGUI InactivateCONS pSt)
									 )
				# pSt				= if newEITHERGoLeft (either1GECVALUE.gecSwitch upd path` pSt)
									                     (either2GECVALUE.gecSwitch upd path` pSt)
				# lSt				= {lSt & eitherGoLeft=newEITHERGoLeft}
				= (OutDone,(lSt,pSt))
		where
			(path`,newEITHERGoLeft)	= case path of
										[ConsLeft  : p] = (p,True)
										[ConsRight : p] = (p,False)
			sameDirection			= eitherGoLeft==newEITHERGoLeft
		eitherFun _ _ (InArrangeCONS arr path) (lSt=:{eitherGoLeft,either1GECVALUE,either2GECVALUE},pSt)
			# pSt					= TRACE (gGECtraceArrangeCONS "EITHER" arr path) pSt
			| isEmpty path
				= abort "gGEC{|EITHER|}: handling request for InArrangeCONS failed: path is empty."
			| otherwise
				# pSt				= if newEITHERGoLeft (either1GECVALUE.gecArrange arr path` pSt)
									                     (either2GECVALUE.gecArrange arr path` pSt)
				= (OutDone,(lSt,pSt))
		where
			(path`,newEITHERGoLeft)	= case path of
										[ConsLeft  : p] = (p,True)
										[ConsRight : p] = (p,False)
		eitherFun _ _ _ st
			= TRACE (gGECtraceDefault "EITHER") (OutDone,st)
		
		maybeLEFT (Just (LEFT   x)) = Just x
		maybeLEFT _                 = Nothing
		
		maybeRIGHT (Just (RIGHT x)) = Just x
		maybeRIGHT _                = Nothing
		
		makeUpLeft					= makeUpValue && (     isJust me && isLEFT (fromJust me))
		makeUpRight					= makeUpValue && (not (isJust me && isLEFT (fromJust me)))
		
		updateLEFT reason a pSt
			# pSt					= TRACE (gGECtraceBranchUpdate "EITHER" "LEFT") pSt
			= update` reason (LEFT a) pSt
		
		updateRIGHT reason b pSt
			# pSt					= TRACE (gGECtraceBranchUpdate "EITHER" "RIGHT") pSt
			= update` reason (RIGHT b) pSt

basicGEC :: !String 
            !(GECId t) 
            !(GECGUIFun t (PSt .ps)) 
         -> TgGEC    t (PSt .ps) 
         |  parseprint t & ggen{|*|} t
basicGEC type_name tGEC gecguiFun = basicGEC` type_name tGEC gecguiFun 
where
	basicGEC` type_name tGEC gecguiFun gecArgs=:{location=(guiLoc,objLoc),outputOnly,gec_value=mt,update} pSt
		# (t,    pSt)				= GenDefaultValIfNoValue mt pSt
		# lSt =
			{ basicValue     = t
			, basicVisible   = False
			, basicGUILoc    = guiLoc
			, basicOBJECTLoc = objLoc
			}
		= GEC2 tGEC type_name gecguiFun (basicFun update) outputOnly lSt pSt
	where
		basicFun _ _ _ InGetValue (lSt=:{basicValue},pSt)
			# pSt					= TRACE (gGECtraceGetValue type_name) pSt
			= (OutGetValue basicValue,(lSt,pSt))
		basicFun update {guiUpdate} _ msg=:(InSetValue yesUpdate value) (lSt=:{basicVisible},pSt)
			# pSt					= TRACE ("gGEC{|"+++type_name+++"|}",msg) pSt
			# lSt					= {lSt & basicValue=value}
			# pSt					= if basicVisible (guiUpdate value pSt) pSt
			# pSt					= if (yesUpdate === YesUpdate) (update Changed value pSt) pSt
			= (OutDone,(lSt,pSt))
		basicFun _ _ _ msg=:InOpenGEC st
			= TRACE ("gGEC{|"+++type_name+++"|}",msg) (OutDone,st)
		basicFun _ {guiClose} tGEC InCloseGEC (lSt=:{basicVisible},pSt)
			# pSt					= TRACE (gGECtraceCloseGEC type_name) pSt
			# pSt					= guiClose pSt
			# pSt					= appPIO (closeReceiver (GECIdtoId tGEC)) pSt
			# lSt					= {lSt & basicVisible=False}
			= (OutDone,(lSt,pSt))
		basicFun update tGUI=:{guiOpen,guiUpdate} tGEC msg=:(InOpenGUI guiLoc objLoc) (lSt=:{basicValue,basicVisible,basicGUILoc},pSt)
			# pSt					= TRACE ("gGEC{|"+++type_name+++"|}",msg) pSt
			| basicVisible && sameGUILoc
				= (OutDone,(lSt,pSt))
			| otherwise
				# (lSt,pSt)			= if sameGUILoc (lSt,pSt)
									                (snd (basicFun update tGUI tGEC (InCloseGUI SkipCONS) (lSt,pSt)))
				# lSt				= {lSt & basicVisible=True,basicGUILoc=guiLoc,basicOBJECTLoc=objLoc}
				# pSt				= guiOpen guiLoc pSt
				# pSt				= guiUpdate basicValue pSt
				= (OutDone,(lSt,pSt))
		where
			sameGUILoc				= guiLoc==basicGUILoc
		basicFun _ {guiClose} _ (InCloseGUI _) (lSt=:{basicVisible},pSt)
			# pSt					= TRACE (gGECtraceCloseGUI type_name) pSt
			# pSt					= guiClose pSt
			# lSt					= {lSt & basicVisible=False}
			= (OutDone,(lSt,pSt))
		basicFun _ _ _ (InSwitchCONS u p) st
			= TRACE (gGECtraceSwitchCONS type_name u p) (OutDone,st)
		basicFun _ _ _ (InArrangeCONS a p) st
			= TRACE (gGECtraceArrangeCONS type_name a p) (OutDone,st)
		basicFun _ _ _ _ st
			= TRACE (gGECtraceDefault type_name) (OutDone,st)



isLEFT :: (EITHER a b) -> Bool
isLEFT (LEFT _) = True
isLEFT _        = False

isRIGHT :: (EITHER a b) -> Bool
isRIGHT (RIGHT _) = True
isRIGHT _         = False

leftEITHER :: (EITHER a b) -> a
leftEITHER (LEFT a) = a
leftEITHER _ = abort "leftEITHER incorrectly applied to (RIGHT _)"

rightEITHER :: (EITHER a b) -> b
rightEITHER (RIGHT b) = b
rightEITHER _ = abort "rightEITHER incorrectly applied to (LEFT _)"

leftPAIR :: (PAIR a b) -> a
leftPAIR  (PAIR a b) = a

rightPAIR :: (PAIR a b) -> b
rightPAIR (PAIR a b) = b

gGECcase              type           :== "gGEC{|"+++type+++"|}"
gGECtrace             type           :== "creating "+++gGECcase type
gGECtraceBranchUpdate type source    :== gGECcase type +++ " " +++ source
gGECtraceGetValue     type           :== gGECcase type +++ " InGetValue"
gGECtraceCloseGEC     type           :== gGECcase type +++ " InCloseGEC"
gGECtraceCloseGUI     type           :== gGECcase type +++ " InCloseGUI"
gGECtraceSwitchCONS   type upd path  :== gGECcase type +++ " (InSwitchCONS "+++printToString upd+++" "+++printToString path+++")"
gGECtraceArrangeCONS  type arr path  :== gGECcase type +++ " (InArrangeCONS "+++printToString arr+++" "+++printToString path+++")"
gGECtraceDefault      type           :== "Handling messages failed of "+++type


/**	Factoring common functionality of the major functions above (unitGEC .. basicGEC). 
	Two 'kinds' of entry points:
		GEC:  allocates a GECId before calling GEC2;
		GEC2: captures the common functionality. 
		      (1) Determine the GUI component; 
		      (2) set-up the receiver infrastructure,
		      (3) activate it, 
		      (4) and finally return the handle as a result.
*/
GEC :: !String 
       !(GECGUIFun a (PSt .ps)) 
       !((GECGUI a (PSt .ps)) (GECId a) -> Receiver2Function (GECMsgIn a) (GECMsgOut a) *(.lst,PSt .ps))
       !OutputOnly
       .lst (PSt .ps)
    -> (!.GECVALUE a (PSt .ps), !PSt .ps)
GEC name gecguiFun fun outputOnly lSt pSt
	# (pGEC,pSt)	= openGECId pSt
	= GEC2 pGEC name gecguiFun fun outputOnly lSt pSt

GEC2 :: !(GECId a) 
        !String 
        !(GECGUIFun a (PSt .ps)) 
        !((GECGUI a (PSt .ps)) (GECId a) -> Receiver2Function (GECMsgIn a) (GECMsgOut a) *(.lst,PSt .ps))
        !OutputOnly
        .lst (PSt .ps)
     -> (!.GECVALUE a (PSt .ps), !PSt .ps)
GEC2 pGEC name gecguiFun fun outputOnly lSt pSt
	# pSt			= TRACE (gGECtrace name) pSt
	# (gecGUI,pSt)	= gecguiFun outputOnly pSt				// (1)
	# tDef			= GECReceiver pGEC (fun gecGUI pGEC)	// (2)
	# (_,pSt)		= openReceiver lSt tDef pSt				// (2)
	# pSt			= openGEC pGEC pSt						// (3)
	= (newGEC pGEC,pSt)										// (4)  mjp
where
	newGEC :: !(GECId t) -> .GECVALUE t (PSt .ps)
	newGEC tGEC
		= { gecOpen     = openGEC     tGEC
	      , gecClose    = closeGEC    tGEC
	      , gecOpenGUI  = openGECGUI  tGEC
	      , gecCloseGUI = closeGECGUI tGEC
	      , gecGetValue = getGECvalue tGEC
	      , gecSetValue = setGECvalue tGEC
	      , gecSwitch   = switchGEC   tGEC
	      , gecArrange  = arrangeGEC  tGEC
	      , gecOpened   = accPIO (isGECIdBound tGEC)
	      }
