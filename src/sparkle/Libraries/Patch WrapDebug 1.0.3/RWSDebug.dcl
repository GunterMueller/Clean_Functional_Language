/*
	Ronny's syntax and options for debug functions.

	Version 1.0.3
	Ronny Wichers Schreur
	ronny@cs.kun.nl
*/
definition module RWSDebug

// print b, then evaluate a
(<<-) infix 0 :: .a !.b -> .a

// evaluate a, then print b
(->>) infix 0 :: !.a .b -> .a

// evaluate and print a
<<->> :: !.a -> .a

// MdM -- patched -- personal addition
(--->>) :: !.a .b -> .a
// ... MdM