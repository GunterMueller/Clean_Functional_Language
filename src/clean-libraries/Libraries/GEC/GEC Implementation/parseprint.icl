implementation module parseprint

import GenParse, GenPrint, StdArray, StdEnv

class parseprint t 
where
	parseGEC:: String -> Maybe t
	printGEC:: t -> String

instance parseprint Bool   
where 
	parseGEC t = parseString t
	printGEC t = printToString t		
instance parseprint Int   
where 
	parseGEC t = parseString t
	printGEC t = printToString t		
instance parseprint Real   
where 
	parseGEC t = parseString t
	printGEC t = printToString t		
instance parseprint Char   
where 
	parseGEC t = if (size t > 0) (Just t.[0]) Nothing
	printGEC t = toString t		
instance parseprint String   
where 
	parseGEC t = Just t
	printGEC t = t		
		
