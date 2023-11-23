module v

import StdDynamic, StdEnv, DynamicFileIO

:: Tree a = Node a (Tree a) (Tree a) | Leaf | Test [Tree a] Real

Start world
	#! (ok,world)
		= writeDynamic (p +++ "\\value") dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world)
where 
//	dt = dynamic (dynamic 1) :: Dynamic
//	dt = dynamic (double_tree (double_tree (Node 99 tree2 tree2))) //  4 nodes and 6 leafs
	dt = dynamic (Node 99 tree2 tree2);
	
	tree2 = (Node 2 (Node 1 Leaf Leaf) Leaf)	// 2 nodes and 3 Leafs

	double_tree t 
		= Node 29 t t;

	p
		= "C:\\WINDOWS\\Desktop\\cvs\\Dynamics\\Examples\\Apply";
		
		
/*
Start world
	#! (ok,world) 
		= writeDynamic (p +++ "\\function") DynamicDefaultOptions dt world
	| not ok
		= abort "could not write dynamic"
	= (dt,world)
where  
	dt = dynamic count_leafs 
	

*/
