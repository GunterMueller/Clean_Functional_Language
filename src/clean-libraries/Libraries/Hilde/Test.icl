module Test

import StdEnv, StdDebug, FamkeKernel, CleanTricks, FamkeProcess, YlseFileServer, FamkeConcurrentClean

TRACE x y :== trace_n x y; import StdDebug

Start world = StartProcess pipe world
where
	pipe famke
		# (ys, famke) = ``P`` (\f -> ([TRACE n n \\ n <- [0..99]], f)) famke
		= foldr TRACE famke ys

map``P`` :: (a -> b) ![a] !*World -> ([b], !*World) | SendGraph{|*|}, ReceiveGraph{|*|}, TC b
map``P`` _ [] famke = ([], famke)
map``P`` f [x:xs] famke 
	# (y, famke) = ``P`` (\famke -> (f x, famke)) famke
	  (ys, famke) = map``P`` f xs famke
	= ([y:ys], famke)

derive SendGraph []
derive ReceiveGraph []
derive bimap (,,)
 
/*
Start world = StartProcess p world
where
	p famke
		# (id, famke) = newProcess q famke
//		  famke = killProcess id famke
		  famke = shutdown famke
		= famke
		
	q famke
		= q (TRACE "..." famke)
*/
/*
Start world = StartProcess p world
where
	p famke
		# fileserver = FamkeNameServer
		  (_, famke) = newProcess (StartFileServer fileserver ".") famke
		  (ok, famke) = writeFileAt fileserver ["<<"] (dynamic 1) famke
		| not ok = abort "writeFileAt failed"
		# (maybe, famke) = listFolderAt fileserver [] famke
		= case maybe of
			Just list -> print list famke
			Nothing -> abort "ListFolderAt failed"

	print [x:xs] famke
		| trace_tn x
		= print xs famke
	print [] famke = famke
*/
/*
Start world = StartProcess (\f -> (famkeFib 4 f)) world
where
	p1 famke 
		# (id, famke) = processId famke
		= TRACE "P1" (reuseProcess id p2 famke)
//		= TRACE "P1" (snd (newProcess p2 famke))
	p2 famke = TRACE "P2" (snd (newProcess p3 famke))
	p3 famke = TRACE "P3" famke

	nProcess 1 famke = TRACE "nProcess 1" famke
	nProcess n famke = TRACE ("nProcess " +++ toString n) (snd (newProcess (nProcess (n - 1)) famke))
	
	famkeFib :: !Int !*World -> *World
	famkeFib n famke
		| n < 2 = TRACE ("famkeFib " +++ toString n) famke
		# (id, famke) = newProcess (famkeFib (n - 1)) famke
		  famke = TRACE ("famkeFib " +++ toString n +++ ": newProcess (famkeFib " +++ toString (n - 1) +++ ") == " +++ toString id) famke
		  famke = famkeFib (n - 2) famke
		  famke = TRACE ("famkeFib " +++ toString n +++ ": famkeFib " +++ toString (n - 2)) famke
		  famke = joinProcess id famke
		  famke = TRACE ("famkeFib " +++ toString n +++ ": joinProcess " +++ toString id) famke
		= famke
/*
	famkeFib` :: !Int !*World -> (!Int, !*World)
	famkeFib` n famke
		| n < 2 = (1, TRACE ("famkeFib " +++ toString n +++ " == 1") famke)
		# (x, famke) = ``P`` (famkeFib` (n - 2)) famke
		  (y, famke) = famkeFib` (n - 1) famke
		  famke = TRACE ("famkeFib " +++ toString (n - 1) +++ " == " +++ toString y) famke
		  famke = TRACE ("``P`` (famkeFib " +++ toString (n - 2) +++ ") == " +++ toString x) famke
		  z = x + y + 1
		= (z, TRACE ("famkeFib " +++ toString n +++ " == " +++ toString z) famke)
*/
*/