module ChangeDynamicRefsExample

import StdEnv, DynID, ChangeDynamicRefs
 
swap (x,y) = (y,x)
 
ids :: [(String, String)]
ids = [  swap ("C:\\Program Files\\CleanAll200\\Clean 2.0\\Tools\\Dynamics 0.0\\libraries\\v_0c",
		 "C:\\Program Files\\CleanAll200\\Clean 2.0\\Tools\\Dynamics 0.0\\test libs\\f_0c")]

f :: String -> String
f id = g id ids
		
g :: String [(String, String)] -> String
g id [] = id
g id [hd:tl]  
	| id == fst hd	= snd hd
	| otherwise 	= g id tl 

ChangeCToE :: String -> String;
ChangeCToE st 
	| 'C' == st.[0] || 'c'== st.[0] = "E"+++(st%(1,size(st)))
	= st

dynname = "C:\\WINDOWS\\DESKTOP\\distribution\\Examples\\Dynamic 0.0\\DynamicApply\\value"

dynid :: DynamicID 
dynid = fromString dynname


Start world
	= ChangeDynamicReferences dynname f world
	
	
	