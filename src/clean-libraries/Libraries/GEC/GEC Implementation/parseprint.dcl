definition module parseprint

import GenParse, GenPrint, StdArray

class parseprint t 
where
	parseGEC:: String -> Maybe t
	printGEC:: t -> String

instance parseprint Bool, Int , Real, Char, String			
		
