module targettest

import StdEnv, StdIO
import target

EnvironmentPath :== applicationpath "IDEEnvs"

Start world
	# (ok,iniTargets,world)	= openTargets EnvironmentPath world
	= ok

