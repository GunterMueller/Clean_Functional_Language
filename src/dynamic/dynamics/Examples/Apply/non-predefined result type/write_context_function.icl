module write_context_function

import StdDynamic, StdEnv
import StdDynamicFileIO
import path

:: Tree b = Node b (Tree b) (Tree b) | Leaf | Test [Tree b] Real

:: X
	= {
		x_r1	:: Int
	,	x_r2	:: Int 
	};
	
wrap x
	= dynamic x
	
Start world
	#! (ok,world) 
		= writeDynamic (p +++ "\\context_function") dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world) //, wrap {x_r1 = 1,x_r2 = 2})
where  
	dt = (dynamic count_leafs)
		
count_leafs :: (Tree Int) -> Int;
count_leafs tree 
	= count tree 0;
where
	count :: (Tree Int) Int -> Int
	count Leaf n_leafs
		= inc n_leafs
	count (Node _ left right) n_leafs
		= count left (count right n_leafs)
	count q _
		= abort "count does not match";
