module tuple_trees

import StdDynamic
import StdDynamicFileIO
import path
import StdEnv
import DynamicUtilities

//Start :: *World -> *World
Start world
	# (ok,tree1,world)
		= readDynamic (p +++ "\\tree1") world
	| not ok
		= abort " could not read"


	# (ok,tree2,world)
		= readDynamic (p +++ "\\tree2") world
	| not ok
		= abort " could not read"

	# (ok,tree3,world)
		= readDynamic (p +++ "\\tree3") world
	| not ok
		= abort " could not read"

		
	# tuple_trees
		= f tree1 tree2 tree3 //(tree1) //,tree2,tree3)
		
	#! (ok,world)
		= writeDynamic (p +++ "\\tuple_trees") tuple_trees world
	| not ok
		= abort "could not write dynamic"
	= world
where 
	f (t1 :: a) (t2 :: a) (t3 :: a)
		= dynamic (t1,t2,t3)
// partially_used_dynamic