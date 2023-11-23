definition module ChangeDynamicRefs

import DynID

ChangeDynamicReferences :: String (String -> String) *World -> (Bool, *World)
// ChangeDynamicReferences dyn f w
// changes the references in dyn that is stored on the disk. 
// it changes each x reference to f(x)

