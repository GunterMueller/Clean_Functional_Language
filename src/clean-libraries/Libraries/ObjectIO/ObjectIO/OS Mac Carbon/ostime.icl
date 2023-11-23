implementation module ostime

//	Clean Object I/O library, version 1.2

import StdOverloaded, StdClass, StdInt
import ostoolbox
from events import TickCount, GetCaretTime, ::Toolbox..
import OS_utilities
//import pointer

::	OSTime
	=	OSTime !Int

OSMaxTickCount	:==	2^31-1

osMaxTime :: OSTime
osMaxTime = OSTime OSMaxTickCount

osGetTime :: !*OSToolbox -> (!OSTime,!*OSToolbox)
osGetTime tb
	# (now,tb)	= TickCount tb
	= (OSTime now,tb)

//	OSWait waits atleast the given time (in milliseconds).
osWait :: !Int .x !*OSToolbox -> (.x,!*OSToolbox)
osWait delay x tb
	# (now,tb)	= TickCount tb
	= waitticks now delay x tb
where
	waitticks :: !Int !Int .x !*OSToolbox -> (.x,!*OSToolbox)
	waitticks then delay x tb
		# (now,tb) = TickCount tb
		| now-then>=delay
		= (x,tb)
		= waitticks then delay x tb

//	OSGetBlinkInterval returns the recommended blink interval time of a cursor (in milliseconds).
osGetBlinkInterval	::			!*OSToolbox -> (!Int,	!*OSToolbox)
osGetBlinkInterval tb
	= GetCaretTime tb

//	OSGetCurrentTime returns current (hours,minutes,seconds).
osGetCurrentTime :: !*OSToolbox -> (!(!Int,!Int,!Int),!*OSToolbox)
osGetCurrentTime tb
	# (hours,minutes,seconds,tb)= GetTime tb
	= ((hours,minutes,seconds),tb)

//	OSGetCurrentTime returns current (year,month,day,day_of_week).
osGetCurrentDate :: !*OSToolbox -> (!(!Int,!Int,!Int,!Int),!*OSToolbox)
osGetCurrentDate tb
	# (year,month,day,dayNr,tb)	= GetDate tb
	= ((year,month,day,dayNr),tb)

instance - OSTime where
	(-) :: !OSTime !OSTime -> OSTime
	(-) (OSTime new) (OSTime old)
		| old<=new
			= OSTime (new-old)
			= OSTime (OSMaxTickCount-old+new)

instance < OSTime where
	(<) :: !OSTime !OSTime -> Bool
	(<) (OSTime t1) (OSTime t2)
		= t1<t2

instance toInt OSTime where
	toInt :: !OSTime -> Int
	toInt (OSTime t) = t

instance fromInt OSTime where
	fromInt :: !Int -> OSTime
	fromInt t = OSTime (max 0 t)
