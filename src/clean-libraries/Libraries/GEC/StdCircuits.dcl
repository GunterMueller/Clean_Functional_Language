definition module StdCircuits

/********************************************************************
*                                                                   *
*   Some handy basic circuits implemented with arrow combinators    *
*                                                                   *
********************************************************************/

import GecArrow

selfCir 	 ::  String 		   		(a -> a) 			-> (GecCircuit a a) 	| gGEC{|*|} a
applyCir 	 :: (String,String) 		(a -> b) 			-> (GecCircuit a b) 	| gGEC{|*|} a & gGEC{|*|} b
apply2Cir 	 :: (String,String,String) 	(a -> b -> c) 		-> (GecCircuit (a,b) c) | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c                     
mutualCir	 :: (String,String)		   	(a -> b) (b -> a) 	-> (GecCircuit a a) 	| gGEC{|*|} a & gGEC{|*|} b               

/*
loopstate 	 : creates a loop retaining a state
*/
loopstate 	 :: st (GecCircuit (a, st) (b, st)) 			-> GecCircuit a b


/*
okPredEditor : Adds Ok / Cancel buttons; only passes a value if OK is pressed and predicate is true
predMDialog  : Pops up modal dialog until predicated is fullfilled
*/

okPredEditor :: String 					(a -> Bool) 		-> (GecCircuit a a) 	| gGEC{|*|} a
predMDialog  :: String 					(a -> Bool)  		-> (GecCircuit a a) 	| gGEC{|*|} a
