module multiple_entry_nodes

import StdDynamic, StdEnv
import StdDynamicFileIO
import path

import StdDynamic
import StdDynamicFileIO
import path
import StdEnv
import DynamicUtilities

:: Tree a = Leaf | Node a (Tree a) (Tree a)

:: T = Zero | Single1 T | Single2 T | Double T T

Start world
	#! (ok,world)
		= writeDynamic (p +++ "\\test_dynamic") dt world
	| not ok
		= abort "could not write dynamic"
	
/*	 
	# (ok,ddd,world)
		= readDynamic (p +++ "\\test_dynamic") world
	| not ok
		= abort " could not read function"
	
	
	# x1 
		= case ddd of
			((t0 :: T,t2 :: T) :: (Dynamic,Dynamic)) 
				-> t0
			_
				-> undef
*/		

	= (world)
where 
	dt 	:: !Dynamic
	dt
		# fst_time
			= Node 1 leaf leaf // Leaf Leaf
		# snd_time
			= Node 2 fst_time fst_time
		# l
			= [dynamic fst_time,dynamic snd_time]
			
		# l
			= (dynamic s0,dynamic s2)
//		#! (l,t)
//	/		= mapSt create_huge_shared_tree list Leaf 
		= (dynamic l)
	where
		s0 
			= Single1 s1
		s1
			= Single1 s2	// vervangen door Single2 gaat ook fout
		s2
			= Double s1 s3 // Double s2 s3 ook fout moet interne ref zijn i.p.v. externe
		s3
			= Zero
			
		
	
	
	
		leaf = Leaf
	
		list
			= [1..2] //[1..3]

//		create_huge_shared_tree :: !Int !(Tree Int) -> (!Dynamic, !Tree Int)
		create_huge_shared_tree i tree
			#! node
				= Node i tree tree
			= (dynamic node, node)	
			

mapSt f l s :== map_st l s
where
	map_st [x : xs] s
	 	# (x, s) = f x s
//	 	#! s=s
		# mapSt_result = map_st xs s
		  (xs, s) = mapSt_result
		#! s = s
		= ([x : xs], s)
	map_st [] s
	 	= ([], s)
	