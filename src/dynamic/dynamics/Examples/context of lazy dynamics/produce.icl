module produce

import StdEnv
import StdDynamic

:: Tree a = Leaf a | Node (Tree a) (Tree a)

Start world
	#! (ok,world)
		= writeDynamic (p +++ "\\boompjes") DynamicDefaultOptions dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world)
where
	p
		= "C:\\WINDOWS\\Desktop\\Dynamics\\Examples\\context of lazy dynamics";
		
	dt
		= dynamic (tree1,tree2,tree3)
		
		
	tree1
		= dynamic Leaf "Boom1"
	tree2
		= dynamic  Leaf "Boom2"
	tree3
		= dynamic  Leaf "Boom3"
	