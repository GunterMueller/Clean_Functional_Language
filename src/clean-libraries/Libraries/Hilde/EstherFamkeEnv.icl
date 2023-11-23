implementation module EstherFamkeEnv

import StdList, FamkeProcess

famkeEnv :: [(String, Dynamic)]
famkeEnv = 
	[
	]	
	++ famkeProcess
where
	famkeProcess = 
		[	("newProcess", dynamic newProcess :: (*World -> *World) *World -> *(ProcessId, *World))
		,	("newProcessAt", dynamic newProcessAt :: String (*World -> *World) *World -> *(ProcessId, *World))
		,	("joinProcess", dynamic joinProcess :: ProcessId *World -> *World)
		,	("killProcess", dynamic killProcess :: ProcessId *World -> *World)
		,	("shutdown", dynamic shutdown :: *World -> *World)
		]
