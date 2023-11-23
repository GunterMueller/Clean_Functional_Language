implementation module basicArrowEditors

/********************************************************************
*                                                                   *
*   Some handy basic editors implemented with editor combinators    *
*                                                                   *
********************************************************************/

import StdEnv
import StdGEC, StdGECExt, GecArrow

// the gGEC{|*|} (= gGECstar defined belwo) defined in the paper is a slightly simplified version of createNGEC 


mkGEC :: String  t (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
mkGEC s  v env = startCircuit (edit s) v env 

selfGEC :: String (t -> t) t (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
selfGEC s f v env                                                           
= startCircuit (feedback (arr f >>>                 
  						  edit s)
  			   ) v env                

applyGECs :: (String,String) (a -> b) a (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps
applyGECs (e1,e2) f v env
= startCircuit (edit e1 >>>                 
  				arr f >>>                 
  				edit e2) v env                

apply2GECs :: (String,String,String) (a -> b -> c) a b (PSt ps) -> (PSt ps)                     
                                                        | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c & bimap{|*|} ps                     
apply2GECs (sa,sb,sc) f va vb env                                                       
= startCircuit (edit sa *** edit sb >>>                 
  				arr uncurr >>>                 
  				edit sc) (va,vb) env
where
	uncurr (a,b) = f a b  				                
                                                                                                
mutualGEC :: (String,String)(a -> b) (b -> a) a
		  								   (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps                     
mutualGEC (sa,sb) a2b b2a va env
= startCircuit (feedback (arr a2b >>> edit sa >>>                 
  						  arr b2a >>> edit sb)) va env                
