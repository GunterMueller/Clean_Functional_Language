module 
	Example

import
	StdEnv,
	StdIO,
	StatusDialog

Delay :: !Int -> !Int
Delay num
	# list1				= repeatn 10000 num
	# num				= last list1
	# list2				= repeatn 10000 num
	# num				= last list2
	# list3				= repeatn 10000 num
	# num				= last list3
	= num
               
Start :: *World -> *World
Start world
	= startIO MDI 0 initialize [ProcessClose closeProcess] world   
	where
		initialize :: (*PSt .ps) -> *PSt .ps
		initialize state
			# state					= openStatusDialog "Converting project...." (walk_through 0) state
			= closeProcess state
			where
				walk_through num change state
					| num > 365			= change Finished state
					# state				= change (NewMessage ("Converting file " +++ toString num)) state
					= walk_through (num+1) change state