definition module CpmPaths

import PmEnvironment

readIDEEnvs :: !String !String !*World -> *([Target], *World)

writeIDEEnvs :: !String !String ![Target] !*World -> *(Bool, *World)
