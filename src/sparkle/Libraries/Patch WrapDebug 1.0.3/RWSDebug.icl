/*
	Ronny's syntax and options for debug functions.

	Version 1.0.3
	Ronny Wichers Schreur
	ronny@cs.kun.nl
*/
implementation module RWSDebug

import Debug

show
	=	debugShowWithOptions [DebugMaxChars 79, DebugMaxDepth 5,  DebugMaxBreadth 20]

// MdM -- patched -- personal addition
show_all
	=	debugShowWithOptions [DebugMaxChars 10000000, DebugMaxDepth 250]
// ... MdM

(<<-) infix 0 :: .a !.b -> .a
(<<-) value debugValue
	=	debugBefore debugValue show value

(->>) infix 0 :: !.a .b -> .a
(->>) value debugValue
	=	debugAfter debugValue show value

<<->> :: !.a -> .a
<<->> value
	=	debugValue show value

// MdM -- patched -- personal addition
(--->>) :: !.a .b -> .a
(--->>) value debugValue
	=	debugAfter debugValue show_all value
// ... MdM