module a

import StdDynamic, StdEnv

:: Tree a = Leaf | Node a (Tree a) (Tree a)


Start world
	#! (ok,world) 
		= writeDynamic (p +++ "\\trees") DynamicDefaultOptions dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world)
where
	dt = dynamic (count_leafs,double_tree)
	
	count_leafs :: (Tree Int) -> Int
	count_leafs tree 
		= count tree 0
	where
		count :: (Tree Int) Int -> Int
		count Leaf n_leafs
			= inc n_leafs
		count (Node _ left right) n_leafs
			= count left (count right n_leafs)
		count q _
			= abort "count does not match"
			
	double_tree t 
		= Node 29 t t;

	p
		= "C:\\WINDOWS\\Desktop\\Dynamics\\Examples\\mixed dynamics";
