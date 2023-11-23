implementation module osmouse

//	Clean Object I/O library, version 1.2

from ostoolbox import :: OSToolbox
import pointer, events

// RWS ??? returned resolution
osGetDoubleClickTime :: !*OSToolbox -> (!Int, !*OSToolbox)
osGetDoubleClickTime toolbox
	= GetDoubleTime toolbox
