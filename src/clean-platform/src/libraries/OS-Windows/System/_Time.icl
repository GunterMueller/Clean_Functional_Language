implementation module System._Time

import StdEnv
import System.OSError
import System.Time
import System._WinBase

import code from library "msvcrt.txt"

_timegm :: !{#Int} -> Int
_timegm tm = code {
	ccall _mkgmtime "A:I"
}

/* On windows GetSystemTimeAsFileTime returns a struct containing 2 32-bit unsigned integers.
 * On 64 bit we therefore use an array of length 1, on 32 bit of length two.
 * On 64 bit we can use native integers, on 32 bit we use bigints.
 */
_nsTime :: !*World -> (!Timespec, !*World)
_nsTime w
	# (is, w) = GetSystemTimeAsFileTime (IF_INT_64_OR_32 {0} {0,0}) w
	= (fileTimeToTimeSpec is, w)

_tsSleep :: !Timespec !*World -> (!MaybeOSError (), !*World)
_tsSleep ts w = (Ok (), sleep (ts.tv_sec*1000+ts.tv_nsec/1000000) w)
