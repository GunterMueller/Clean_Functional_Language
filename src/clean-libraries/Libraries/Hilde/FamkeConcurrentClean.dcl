definition module FamkeConcurrentClean

import StdGeneric
from FamkeKernel import :: FamkeChannel

:: ProcId

``P`` :: !(*World -> *(a, *World)) !*World -> (a, !*World) | SendGraph{|*|}, ReceiveGraph{|*|}, TC a

generic SendGraph a :: !a !*(FamkeChannel String String) !*World -> *(!*FamkeChannel String String, !*World)
generic ReceiveGraph b :: !*(FamkeChannel String String) !*World -> *(!b, *FamkeChannel String String, *World)

derive SendGraph UNIT, PAIR, EITHER, CONS, FIELD, OBJECT, String, Char, Int, Real, Bool, Dynamic
derive ReceiveGraph UNIT, PAIR, EITHER, CONS, FIELD, OBJECT, String, Char, Int, Real, Bool, Dynamic
