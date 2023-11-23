definition module System.Linux.ProcessControl

import qualified System._Linux
from System._Linux import PR_SET_PDEATHSIG

/**
 * Control process execution. See `man prctl`. This function is Linux-specific.
 *
 * This is the version with one argument besides the `option`.
 *
 * @type !Int !Int !*World -> *(!Int, !*World)
 */
prctl1 option arg2 w :== 'System._Linux'.prctl1 option arg2 w
