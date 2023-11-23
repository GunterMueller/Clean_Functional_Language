definition module System._Linux

from System._Pointer import :: Pointer

sendfile :: !Int !Int !Pointer !Int !*World -> (!Int, !*World)

PR_SET_PDEATHSIG :== 1

/**
 * Control process execution. See `man prctl`. This function is Linux-specific.
 *
 * This is the version with one argument besides the `option`.
 */
prctl1 :: !Int !Int !*World -> *(!Int, !*World)
