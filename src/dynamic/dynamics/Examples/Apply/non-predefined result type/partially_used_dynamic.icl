module partially_used_dynamic

import StdDynamic
import StdDynamicFileIO
import path
import StdEnv
import DynamicUtilities

:: Tree a = Leaf | Node a (Tree a) (Tree a)

Start :: *World -> *World
Start world
	#! (ok,world)
		= writeDynamic (p +++ "\\partially_used_dynamic") dt world
	| not ok
		= abort "could not write dynamic"
	= world
where 
	dt 	:: !Dynamic
	dt
		#! (l,t)
			= mapSt create_huge_shared_tree list Leaf 
		= NF (dynamic l)
//		= NF (dynamic l1 )
	where
		list
			= [1..3]
		l1
			= [dynamic (i,shared) \\ i <- [1..3] ]
		shared
			= "Shared"
			  
//			= [0,1..9]
//			= [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16] 	// dumpDynamic crash
		create_huge_shared_tree i tree
			#! node
				= Node i tree tree
			= (dynamic node, node)	
			

mapSt f l s :== map_st l s
where
	map_st [x : xs] s
	 	# (x, s) = f x s
		  mapSt_result = map_st xs s
		  (xs, _) = mapSt_result
		#! s = second_of_2_tuple mapSt_result
		= ([x : xs], s)
	map_st [] s
	 	= ([], s)
	
second_of_2_tuple t :== e2
	where
		(_,e2) = t

map2St f l1 l2 st :== map2_st l1 l2 st
  where
	map2_st [h1:t1] [h2:t2] st
		# (h, st) = f h1 h2 st
		  (t, st) = map2_st t1 t2 st
		#! st = st
		= ([h:t], st)
	map2_st _ _ st
		#! st = st
		= ([], st)
