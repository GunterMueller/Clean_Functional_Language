module read_huge_tree 

import StdDynamic, StdEnv
import StdDynamicFileIO
import path

Start world
	# (ok,v,world)
		= readDynamic (p +++ "\\partially_used_dynamic") world
	| not ok
		= abort " could not read"
	= (v,world)