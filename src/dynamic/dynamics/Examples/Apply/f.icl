module f

import StdDynamic, StdEnv, DynamicFileIO

:: Tree b = Node b (Tree b) (Tree b) | Leaf | Test [Tree b] Real

Start world
	#! (ok,world) 
		= writeDynamic (p +++ "\\function") dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world)
where  
	dt = dynamic count_leafs 
	
	p
		= "C:\\WINDOWS\\Desktop\\cvs\\Dynamics\\Examples\\Apply";
	
count_leafs :: (Tree Int) -> Real
count_leafs tree 
	= toReal (count tree 0)
where

	count :: (Tree Int) Int -> Int
	count Leaf n_leafs
		= inc n_leafs
	count (Node _ left right) n_leafs
		= count left (count right n_leafs)
	count q _
		= abort "count does not match";
