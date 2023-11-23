module tree1

import StdEnv
import StdDynamic
import StdDynamicFileIO

import tree
import path

Start :: *World -> *World
Start world
	#! (ok,world)
		= writeDynamic (p +++ "\\tree1") dt world
	| not ok
		= abort "could not write dynamic"
	= world
where 
	dt
		= dynamic (Node 1 Leaf Leaf)
		
