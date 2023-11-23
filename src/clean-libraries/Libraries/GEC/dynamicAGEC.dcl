definition module dynamicAGEC

import StdAGEC

//dynamicAGEC  :: a -> AGEC a | TC a //& gGEC {|*|} a  // shows typed in expression, resulting value + type	 					
dynamicAGEC :: a -> AGEC a | TC a  // only shows typed in expression	 					
				
derive gGEC (->), DynString

:: DynString = DynStr Dynamic String

ShowValueDynamic :: Dynamic -> String
ShowTypeDynamic  :: Dynamic -> String

derive ggen Dynamic