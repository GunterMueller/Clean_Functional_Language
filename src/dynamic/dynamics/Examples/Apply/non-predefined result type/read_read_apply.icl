module read_read_apply

import StdDynamic
import StdEnv
import RWSDebug
import StdDynamicFileIO
import path

:: X
	= {
		x_r1	:: Int
	,	x_r2	:: Int 
	};

Start world
	// build_lazy_blocks *not* at entry node
	# (ok,d,world)
		= readDynamic (p +++ "\\bool2") world
	| not ok
		= abort " could not read";
		
	| size (get_real d) <> 0

//	# (_,world)
//		= writeDynamic (p +++ "\\bool3") d world
//	= world
//	= (get_real d /*,d*/ ,world)
//	= (world)
	= (d,world)

where
//	get_real (r :: Int)
//		= "detected Real"


	get_real (_ :: X) //Int)
		= "detected X"
	get_real _
		= "geen real"
