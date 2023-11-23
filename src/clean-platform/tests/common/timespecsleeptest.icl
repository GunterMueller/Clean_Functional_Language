module timespecsleeptest

import StdEnv
import System.CommandLine
import System.Time
import Data.Error
import Data.Tuple

Start w
	# (start, w) = nsTime w
	= case timespecSleep {tv_sec=3, tv_nsec=0} w of
		(Error e, w) = abort (toString e +++ "\n")
		(Ok (), w)
			# (end, w) = nsTime w
			# secDiff = end.tv_sec-start.tv_sec
			= setReturnCode
				(if (secDiff == 3) 0 1)
				w
