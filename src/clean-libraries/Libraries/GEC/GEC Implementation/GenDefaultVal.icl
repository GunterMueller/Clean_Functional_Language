implementation module GenDefaultVal

import testable
import iostate, StdPSt, MersenneTwister, StdTime, StdList

gDefaultVal :: !*env -> (!t,!*env) | ggen {|*|} t & TimeEnv env
gDefaultVal env
	# (seed,env)= getBlinkInterval env
	# result	= ggen {|*|} seed (genRandInt 42)
	= (hd result,env)

GenDefaultValIfNoValue :: !(Maybe t) !*env -> (!t,!*env) | ggen {|*|} t & TimeEnv env
GenDefaultValIfNoValue maybev env
	= case maybev of
		Just v  = (v,env)
		nothing = gDefaultVal env

