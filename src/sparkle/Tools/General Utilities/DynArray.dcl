definition module
	DynArray

import
	StdArray

:: *DynIntArray
createDynIntArray :: !Int !Int !Int -> *DynIntArray
selectDynIntArray :: !*DynIntArray !Int -> (!Int, !*DynIntArray)
updateDynIntArray :: !*DynIntArray !Int !Int -> *DynIntArray