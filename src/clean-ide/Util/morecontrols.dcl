definition module morecontrols

from StdIOBasic import :: IdFun
from StdControlDef import :: ControlAttribute
from StdClass import class toString, class ==
import StdControlClass

:: FontNameSizeControl ls pst =
  FontNameSizeControl
	.String
	.Int
	[.String]
	[.Int]
	(String -> IdFun *(ls,pst))
	(Int -> IdFun *(ls,pst))
	[.ControlAttribute *(ls,pst)]

instance Controls FontNameSizeControl
