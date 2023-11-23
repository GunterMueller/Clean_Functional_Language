/*
** Program: Clean Prover System
** Module:  Compare (.icl)
** 
** Author:  Maarten de Mol
** Created: 20 June 2001
*/

definition module
	Compare

import
	CoreTypes,
	Heaps

CompareInts			:: !Goal !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)