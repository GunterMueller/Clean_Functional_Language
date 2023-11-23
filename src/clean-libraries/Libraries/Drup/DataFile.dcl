definition module DataFile

import StdMaybe, DrupGeneric, Drup

:: DataFile

openDataFile 	:: !String !*World -> (!*DataFile, !*World)
closeDataFile 	:: !*DataFile !*World -> *World

storeDataFile 	:: !String !.a !*DataFile -> *DataFile | write{|*|} a
loadDataFile 	:: !String !*DataFile -> (!*Maybe .a, !*DataFile) | read{|*|} a

removeDataFile 	:: !String !*DataFile -> *DataFile

