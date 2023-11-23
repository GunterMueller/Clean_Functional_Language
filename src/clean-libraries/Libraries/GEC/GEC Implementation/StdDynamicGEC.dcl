definition module StdDynamicGEC

import StdAGEC

dynamicGEC  :: a -> AGEC a | TC a & gGEC {|*|} a  // shows typed in expression, resulting value + type	 					
dynamicGEC2 :: a -> AGEC a | TC a & gGEC {|*|} a  // only shows typed in expression	 					
				
derive gGEC (->), DynString

:: DynString = DynStr Dynamic String

derive generate Dynamic