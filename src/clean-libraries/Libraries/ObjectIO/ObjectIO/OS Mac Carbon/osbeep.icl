implementation module osbeep

//	Clean Object I/O library, version 1.2

//from	clCCall_12		import WinBeep
from	OS_utilities	import SysBeep, :: Toolbox
from	ostoolbox		import :: OSToolbox

osBeep :: !*OSToolbox -> *OSToolbox
osBeep toolbox
//	= WinBeep toolbox
	= SysBeep 1 toolbox
