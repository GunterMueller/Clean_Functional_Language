module SendDynamicExample

import StdEnv, SendDynamic 

import code from library "StaticClientChannel_library"

hostname = "localhost"
 
//Start :: *World -> (Bool, *World)
//Start world = SendDynamicToHost dynamicname hostname world
Start world = Loop world

Loop world
	# (ok, world) = AnswerDynamicRequest world
	| not ok = ( False, world )
	= Loop world
