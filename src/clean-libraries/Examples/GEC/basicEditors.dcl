definition module basicEditors

/********************************************************************
*                                                                   *
*   This module contains some handy basic editors manually composed *
*                                                                   *
********************************************************************/

import StdGEC
                                               

mkGEC 		:: String  t 			      (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
selfGEC 	:: String (t -> t) t 		  (PSt ps) -> (PSt ps) | gGEC{|*|} t & bimap{|*|} ps
applyGECs 	:: (String,String) (a -> b) a (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps
apply2GECs  :: (String,String,String) (a -> b -> c) a b 
										  (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & gGEC{|*|} c & bimap{|*|} ps                     
mutualGEC :: (String,String)(a -> b) (b -> a) a
								 		  (PSt ps) -> (PSt ps) | gGEC{|*|} a & gGEC{|*|} b & bimap{|*|} ps                     
