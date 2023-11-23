definition module GecArrow

import StdArrow, StdGECExt

// Initialize Editors

startGEC 	 :: ((PSt Void) -> (PSt Void)) *World -> *World

:: GecCircuit a b

// Initialize GecCircuit circuit

startCircuit :: !(GecCircuit a b) a !*(PSt .ps) -> *PSt .ps

:: CircuitCB  a ps :== a -> *(PSt ps) -> *PSt ps
:: CircuitGet a ps :== *(PSt ps) -> *(a, *PSt ps)
:: CircuitSet a ps :== a -> *(PSt ps) -> *PSt ps

evalCircuit :: (CircuitCB b .ps) !(GecCircuit a b) a !*(PSt .ps) -> (CircuitGet b .ps, CircuitSet a .ps, *PSt .ps)

// Lift visual editors to GecCircuit's

edit 		:: String -> GecCircuit a a | gGEC{|*|} a
display 	:: String -> GecCircuit a a | gGEC{|*|} a
gecMouse	:: String -> GecCircuit a MouseState					// Assign a mouse to a fresh window

// Arrow instance for GecCircuit

instance Arrow 			GecCircuit
instance ArrowChoice 	GecCircuit
instance ArrowLoop 		GecCircuit
instance ArrowCircuit 	GecCircuit

// Other GecCircuit combinators

probe 		:: String -> GecCircuit a a | toString a

self 		:: (GecCircuit a b) (GecCircuit b a) -> GecCircuit a b
feedback 	:: (GecCircuit a a) -> GecCircuit a a

sink 		:: GecCircuit a Void
source 		:: (GecCircuit a b) -> GecCircuit Void b
flowControl :: (a -> Maybe b) -> GecCircuit a b

gecIO 		:: (A. .ps: a *(PSt .ps) -> *(b, *PSt .ps)) -> GecCircuit a b
