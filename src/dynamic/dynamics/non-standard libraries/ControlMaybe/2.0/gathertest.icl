module gathertest

import StdEnv, StdIO

Start w
	= startIO MDI Void pinit [] w

pinit ps
	# c = c1 :+: nc2 :+: (ControlJust c3)
	# d = c1 :+: nc2 :+: nc2
	# (_,ps)	= openWindow Void (window b c d) ps
	# (_,ps)	= openMenu Void (Menu "File" (MenuItem "Quit" [MenuShortKey 'Q',MenuFunction (noLS closeProcess)]) []) ps
	= ps
where
	b :: Bool
	b = toBool True
	c1 = ButtonControl "Een" []
	c2 = TextControl "Twee" []
	nc2 :: ControlMaybe (TextControl) _ _
	nc2 = ControlNothing
	c3 = TextControl "Drie" []
	
	window True c d
		= Window "Test" c []
	window False c d
		= Window "Test" d []
/*	
::	:?:		t1 t2	ls	cs	= (:?:) infixr 9 (t1 ls cs) (t2 ls cs)

instance Controls ((:?:) c1 c2)	| Controls c1 & Controls c2 where
//	controlToHandles :: !((:?:) c1 (Maybe c2) .ls (PSt .l)) !(PSt .l) -> (![ControlState .ls (PSt .l)],!PSt .l)	| Controls c1 & Controls c2
	controlToHandles (c1:?:mc2) pState
		# (cs1,pState)	= controlToHandles c1 pState
		= case mc2 of 
			(Just c2)
				#  (cs2,pState)	= controlToHandles c2 pState
				-> (cs1++cs2,pState)
			Nothing
				-> (cs1,pState)
	getControlType _
		= ""
*/
::	ControlMaybe c ls pst
	=	ControlJust (c ls pst)
	|	ControlNothing

instance Controls (ControlMaybe c) | Controls c where
	controlToHandles mc pState
		= case mc of 
			(ControlJust c)
				#  (cs,pState)	= controlToHandles c pState
				-> (cs,pState)
			ControlNothing
				-> ([],pState)
	getControlType _
		= ""
