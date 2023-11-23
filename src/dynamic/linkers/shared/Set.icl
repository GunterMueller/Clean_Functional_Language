implementation module Set

import StdEnv

:: Set a :== [a]

union :: !.[a] !u:[a] -> v:[a] | Eq a, [u <= v]
union [] set2
	= set2
union [x:xs] set2
	| isMember x set2
		= union xs set2
		= [x:union xs set2]
