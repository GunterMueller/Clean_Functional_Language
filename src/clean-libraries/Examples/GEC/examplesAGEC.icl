implementation module examplesAGEC

import StdAGEC
import modeGEC, buttonGEC, tupleGEC, updownGEC
import calcAGEC, basicAGEC

// Integer with calculator buttons

intcalcGEC :: Int -> AGEC Int
intcalcGEC i = 	mkAGEC	{	toGEC	= \ni _ -> calcGEC ni buttons
						,	fromGEC = \b -> ^^ b
						,	value 	= i
						,	updGEC	= id
						} "intcalcGEC"
where
	buttons	  =  [ map mkBut [7..9]
				 , map mkBut [4..6]
				 , map mkBut [1..3]
				 , [mkBut 0, (Button (defCellWidth/3) "C",\_->0), (Button (defCellWidth/3) "N", \v -> 0 - v)]
				 ]

	mkBut i = (Button (defCellWidth/3) (toString i),\v -> v*10 + i)

realcalcGEC :: Real -> AGEC Real
realcalcGEC i = 	mkAGEC	{	toGEC	= newGEC
							,	fromGEC = \b -> fst (^^ b)
							,	value 	= i
							,	updGEC	= id
							} "realcalcGEC"
where
	newGEC ni Undefined 	 = calcGEC (ni ,Hide (True,1.0)) buttons
	newGEC 0.0 (Defined oval)= calcGEC (0.0,Hide (True,1.0)) buttons
	newGEC ni  (Defined oval)= calcGEC (ni,snd (^^ oval)) buttons 

	buttons	  =  [ map mkBut [7..9]
				 , map mkBut [4..6]
				 , map mkBut [1..3]
				 , [mkBut 0]
				 , [ (Button (defCellWidth/3) ".", \(v,Hide (_,_))	-> (v,  Hide (False,1.0)))
				   , (Button (defCellWidth/3) "C", \(_,hide) 		-> (0.0,Hide (True,1.0)))
				   , (Button (defCellWidth/3) "N", \(v,hide) 		-> (0.0 - v,hide))
				   ]
				 ]

	mkBut i =  (  Button (defCellWidth/3) (toString i)
				, \(v,Hide (cond,base)) -> if cond (v*10.0 + toReal i,Hide (cond,base))
											     (v+(toReal i/(base*10.0)),Hide(cond,(base*10.0)))
				)
