implementation module StdCircuits

/********************************************************************
*                                                                   *
*   Some handy basic circuits implemented with arrow combinators    *
*                                                                   *
********************************************************************/

import StdAGEC, basicAGEC, layoutGEC
import StdEnv

selfCir :: String (a -> a) -> (GecCircuit a a) | gGEC{|*|} a
selfCir s f = 	feedback (		arr f 
							>>> edit s
						 )

applyCir :: (String,String) (a -> b) -> (GecCircuit a b) | gGEC{|*|} a & gGEC{|*|} b
applyCir (e1,e2) f = 		edit e1 
						>>>	arr f 
						>>> edit e2              

apply2Cir :: (String,String,String) (a -> b -> c) -> (GecCircuit (a,b) c) | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c                     
apply2Cir (sa,sb,sc) f =		edit sa *** edit sb 
							>>> arr uncurr
							>>> edit sc
where
	uncurr (a,b) = f a b  				                
                                                                                                
mutualCir :: (String,String)(a -> b) (b -> a) -> (GecCircuit a a) | gGEC{|*|} a & gGEC{|*|} b               
mutualCir (sa,sb) a2b b2a =	feedback (		arr a2b 
										>>> edit sa 
										>>> arr b2a 
										>>> edit sb)

loopstate :: st (GecCircuit (a, st) (b, st)) -> GecCircuit a b
loopstate st g = loop (second (delay st) >>> g)

										
// editor which only pass a value if OK is clicked

okPredEditor :: String (a -> Bool) -> (GecCircuit a a) | gGEC{|*|} a
okPredEditor s pred = 	arr toinput 
	       				>>> edit s
	       				>>> arr (frominput o ^^)
where
    toinput i 				= predAGEC test (mkval i i)
	frominput (i <|> _,_)	= i

    test (i <|> (Pressed ,_),hi)	= (False,mkval (^^ hi) (^^ hi))
    test (i <|> (_ ,Pressed),hi)	
    |	pred i						= (True, mkval i i)
    test (i <|> _,hi)				= (False,mkval i (^^ hi))

	CancelOK	= (Button defCellWidth "Cancel", Button defCellWidth "OK")
	mkval ni oi = (ni <|> CancelOK, hidAGEC oi)
										              
// pop up modal dialog if predicate until pred fullfilled 

predMDialog :: String (a -> Bool)  -> GecCircuit a a |  gGEC{|*|} a
predMDialog str pred = gecIO (gecDialog pred str)
where
	gecDialog :: (a -> Bool) String a *(PSt .ps) -> (a,*(PSt .ps)) | gGEC{|*|} a & bimap{|*|} ps 
	gecDialog pred str a pst = check a pst 
	where
		check a pst 
		| pred a 	= (a,pst)
		# (a,pst)	= createDGEC str Interactive True a pst
		= check a pst
