implementation module CpmPaths

import StdEnv,Platform,PmEnvironment

append_dir_separator :: !{#Char} -> {#Char}
append_dir_separator s
	| size s>0 && s.[size s-1]==DirSeparator
		= s
		= s+++DirSeparatorString

readIDEEnvs :: !String !String !*World -> *([Target], *World)
readIDEEnvs cleanhome ideenvs world
	= openEnvironments cleanhome (append_dir_separator cleanhome+++"etc"+++DirSeparatorString+++ideenvs) world

writeIDEEnvs :: !String !String ![Target] !*World -> *(Bool, *World)
writeIDEEnvs cleanhome ideenvs envs world
	= saveEnvironments (append_dir_separator cleanhome+++"etc"+++DirSeparatorString+++ideenvs) envs world
