definition module System._Time

/**
 * This is a platform-specific module. Use the general interface in System.Time
 * instead.
 */

from Data.Error import :: MaybeError
from System.OSError import :: MaybeOSError, :: OSError, :: OSErrorCode, :: OSErrorMessage
from System.Time import :: Timespec

//* The resolution of the system clock.
CLK_PER_SEC	:== 1000

_timegm :: !{#Int} -> Int

//* _nsTime uses GetSystemTimeAsFileTime
_nsTime :: !*World -> (!Timespec, !*World)

//* _tsSleep uses Sleep
_tsSleep :: !Timespec !*World -> (!MaybeOSError (), !*World)
