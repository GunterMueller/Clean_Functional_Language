/*
** Program: Clean Prover System
** Module:  Definedness (.dcl)
** 
** Author:  Maarten de Mol
** Created: 03 May 2001
*/

definition module 
	Definedness

import
	States

// ------------------------------------------------------------------------------------------------------------------------   
:: Definedness =
// ------------------------------------------------------------------------------------------------------------------------   
	  IsDefined
	| IsUndefined
	| DependsOn		![CExprH]
instance DummyValue Definedness

//findDefinedVars			:: !Goal !*CHeaps !*CProject -> (!Bool, ![CExprVarPtr], ![CExprVarPtr], !*CHeaps, !*CProject)
//findDefinedExprs		:: !Goal !*CHeaps !*CProject -> (!Bool, ![CExprH], ![CExprH], !*CHeaps, !*CProject)
findDefinednessInfo		:: !Goal !*CHeaps !*CProject -> (!Bool, !DefinednessInfo, !*CHeaps, !*CProject)

class applyDefinednessInfo a :: !a !DefinednessInfo !*CProject -> (!Definedness, !*CProject)
instance applyDefinednessInfo CExprH
instance applyDefinednessInfo [a] | applyDefinednessInfo a