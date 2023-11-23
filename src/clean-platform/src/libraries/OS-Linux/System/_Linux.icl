implementation module System._Linux

import System._Pointer

sendfile :: !Int !Int !Pointer !Int !*World -> (!Int, !*World)
sendfile out_fd in_fd offset count w = code {
		ccall sendfile "IIpI:I:A"
	}

prctl1 :: !Int !Int !*World -> *(!Int, !*World)
prctl1 option arg2 w = code {
	ccall prctl "II:I:A"
}
