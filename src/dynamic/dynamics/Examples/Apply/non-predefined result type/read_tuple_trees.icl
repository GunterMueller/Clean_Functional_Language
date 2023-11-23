module read_tuple_trees

import StdDynamic
import StdDynamicFileIO
import path
import StdEnv
import DynamicUtilities

//Start :: *World -> *World
Start world
	# (ok,tuple_trees,world)
		= readDynamic (p +++ "\\tuple_trees") world
	| not ok
		= abort " could not read"
		
	= tuple_trees 
