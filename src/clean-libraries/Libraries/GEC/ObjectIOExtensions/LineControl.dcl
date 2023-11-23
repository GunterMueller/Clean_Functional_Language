definition module LineControl

import StdControlClass, StdIOCommon

::	LineControl ls pst
 =	LineControl Direction Int [ControlAttribute *(ls,pst)]

instance Controls LineControl
