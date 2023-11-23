module b

import StdDynamic, StdEnv

:: Tree a = Leaf | Node a (Tree a) (Tree a)

Start world
	// read function
	#! (ok,tuple_dynamic,world)
		= readDynamic (p +++ "\\trees3") world
	| not ok
		= abort " could not read"

	// get functions from dynamic
	# (count_leafs,double_tree)
		= f tuple_dynamic
		
	// write new 3 tuple		
	#! (ok,world)
		= writeDynamic (p +++ "\\tuple3") DynamicDefaultOptions 
			(dynamic (count_leafs,2,double_tree)) world
	| not ok
		= abort "could not write dynamic"

	= world
where
	f :: Dynamic -> ((Tree Int) -> Int,a -> b)
	f ((count_leafs,double_tree) :: ((Tree Int) -> Int,a -> b))
		= (count_leafs,double_tree)
		
	p
		= "C:\\WINDOWS\\Desktop\\Dynamics\\Examples\\mixed dynamics";
