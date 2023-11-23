/*
** Program: Clean Prover System
** Module:  BindLexeme (.dcl)
** 
** Author:  Maarten de Mol
** Created: 13 September 2000
*/

definition module 
	BindLexeme

import
	StdEnv,
	Parser,
	CoreTypes,
	States,
	Heaps,
	Errors

typeBasicValue		:: !(CBasicValue a) -> (!Bool, !CBasicType)

bindExpr			:: ![CName] !PExpr	!*CHeaps !*CProject -> (!Error, !CExprH,		!*CHeaps, !*CProject)
buildExpr			:: !String			!*CHeaps !*CProject -> (!Error, !CExprH,		!*CHeaps, !*CProject)

bindProp			:: ![CName] !PProp	!*CHeaps !*CProject -> (!Error, !CPropH,		!*CHeaps, !*CProject)
buildProp			:: !String			!*CHeaps !*CProject -> (!Error, !CPropH,		!*CHeaps, !*CProject)

bindProofCommand	:: !PProofCommand	!*PState -> (!Error, !WindowCommand,	!*PState)
buildProofCommand	:: !String			!*PState -> (!Error, !WindowCommand,	!*PState)

bindFactArgument	:: !CName !Goal !PFactArgument !*CHeaps !*CProject -> (!Error, !UseFactArgument, !*CHeaps, !*CProject)
bindRelativeExpr	:: !PExpr !Goal !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
bindRelativeProp	:: !PProp !Goal !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
bindTactic			:: !PTacticId !Goal ![TheoremPtr] !Options !*CHeaps !*CProject -> (!Error, !TacticId, !*CHeaps, !*CProject)

BindQualifiedFunction		:: !PQualifiedName !*CHeaps !*CProject -> (!Maybe HeapPtr, !*CHeaps, !*CProject)
