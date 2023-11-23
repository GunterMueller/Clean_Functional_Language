/*
** Program: Clean Prover System
** Module:  Arith (.icl)
** 
** Author:  Maarten de Mol
** Created: 17 April 2001
*/

definition module
	Arith

import
	CoreTypes,
	Heaps

ArithInt			:: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)