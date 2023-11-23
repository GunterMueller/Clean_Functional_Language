definition module Drup2

import DrupGeneric, StdMaybe

:: Drup2 a

openDrup2 :: !String !*World -> (!*Drup2 a, !*World) | write{|*|}, read{|*|} a
closeDrup2 :: !*(Drup2 a) !*World -> *World | write{|*|} a

storeDrup2 :: !String !.a !*(Drup2 .a) -> *Drup2 .a | write{|*|} a
loadDrup2 :: !String !*(Drup2 .a) -> (!*Maybe .a, !*Drup2 .a) | read{|*|} a

