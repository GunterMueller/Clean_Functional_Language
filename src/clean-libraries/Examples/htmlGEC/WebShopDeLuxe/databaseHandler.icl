implementation module databaseHandler

import StdArray, StdFile, StdString, StdInt
import StdMaybe

showPrize :: Int -> String
showPrize val
	= "Euro: " +++ sval%(0,s-3) +++ "." +++ sval%(s-2,s-1)
where
	sval	= toString val
	s		= size sval
