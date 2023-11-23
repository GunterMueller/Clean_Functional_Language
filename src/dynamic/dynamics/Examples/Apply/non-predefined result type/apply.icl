module apply

import StdDynamic, StdEnv
import StdDynamicFileIO
import path
import RWSDebug

:: Tree a = Node a (Tree a) (Tree a) | Leaf | Test [Tree a] Real

g ([h :: Int:_] :: [Dynamic])
	= h;
g _
	= 0;
	
Start1 world
	# (_,x,world)
		= readDynamic ("huge_dynamic") world
	= (g x,world)
where
	g :: Dynamic -> Int
	g ([h :: Int:_] :: [Dynamic])	= h
	g _								= 0
	
	
Start world
	// read function
	# (ok,f,world)
		= readDynamic (p +++ "\\function") world
	| not ok
		= abort " could not read function"
		

	// value function
	# (ok,v,world)
		= readDynamic (p +++ "\\value") world
	| not ok
		= abort " could not read value"

	// write dynamically applied dynamics			
/*
	// test basic types ...
	#! dt2
		= dynamic basic_record
	#! (ok2,world)
		= writeDynamic "bool" DynamicDefaultOptions dt2 world
	| not ok2
		= abort "could not write dynamic"
				
	# (ok,b,world)
		= readDynamic "bool" world
	| not ok
		= abort " could not read"
	#! b
		= case b of
			(b :: BasicRecord)
				-> b;
			_
				-> abort "geen";
*/
/*
	# applied_dynamic
		= apply f v;


	#! (ok2,world)
		= writeDynamic "bool" DynamicDefaultOptions applied_dynamic world
	| not ok2
		= abort "could not write dynamic"
*/		
	# applied_dynamic
		= apply f v;
		

//	#! v = dynamic {{1},{1,2},{1,2,3},{1,2,3,4},{1,2,3,4,5}} :: {{Int}};
//	#! v = dynamic {1,2,3,4,5} :: {#Int};
//	#! v = dynamic {True,False,True,False,True} :: {#Bool};
//	#! v = dynamic {1.1,2.2,3.3,4.4,5.5} :: {#Real};
//	#! v = dynamic {'a','b','c','d','e'} :: {#Char};
//	#! v = dynamic basic_record;		
//	#! (ok2,world)
//		= writeDynamic "bool" HyperStrictEvaluation v world

	#! (ok2,world)
		= writeDynamic (p +++ "\\bool") applied_dynamic world

	| not ok2
		= abort "could not write dynamic"

//	#! (ok2,world)
//		= writeDynamic (p +++ "\\tuple") DynamicDefaultOptions (dynamic (applied_dynamic,v)) world

//	| not ok2
//		= abort "could not write dynamic"

		
	// ... 
	= (world);

//	= f (dynamic 1)
//	#! j = 10;
//	= (/*b, j,*/apply f v,world)
where
//	apply (f :: (Tree Int) -> Int) // (v :: a)
	apply (f :: a -> b) (v :: a)
//	apply (f :: (Tree Int) -> Real) (v :: (Tree Int))
		= dynamic f v 
	apply d1 d2
		| False <<- (d1,d2)
			= undef
		= abort "u!nmatched"
		
count_nodes Leaf accu
	= accu
count_nodes (Node _ left right) accu
	= count_nodes right (count_nodes left (inc accu))

//f d = dynamic (case d of (x :: a) -> x)
