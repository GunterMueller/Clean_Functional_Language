module consume

import StdEnv
import StdDynamic

:: Tree a = Leaf a | Node (Tree a) (Tree a)

Start world
	// read function
	# (ok,three_tuple,world)
		= readDynamic (p +++ "\\boompjes") world
	| not ok
		= abort " could not read"
	# (t1,t2,t3_dynamic)
		= match three_tuple;
	| count_leafs t1 0 <> count_leafs t2 0
		= abort "inequal number of leafs";
		
	// write new dynamic
	# dt
		= dynamic ((t1,t2),t3_dynamic);
	#! (ok,world)
		= writeDynamic (p +++ "\\boompjes2") DynamicDefaultOptions dt world
	| not ok
		= abort "could not write dynamic"		
	= world;	
		
//	= (count_leafs t1 0, count_leafs t2 0,t3_dynamic);
where
	match ((t1 :: Tree {#Char},t2 :: Tree {#Char},t3) :: (Dynamic,Dynamic,Dynamic))
		= (t1,t2,t3);
		
	p
		= "C:\\WINDOWS\\Desktop\\Dynamics\\Examples\\context of lazy dynamics";
		
	count_leafs (Leaf _) cnt			= inc cnt
	count_leafs (Node left right) cnt	= count_leafs left (count_leafs right cnt)
