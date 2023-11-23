definition module wraptextcontrol

import StdControlClass

:: WrapText ls ps = WrapText String [ControlAttribute *(ls,ps)]

instance Controls WrapText

