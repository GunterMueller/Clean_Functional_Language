/*
** Program: Clean Prover System
** Module:  Core (.dcl)
** 
** Author:  Maarten de Mol
** Created: 13 September 1999
*/

definition module 
	Rewrite

import 
	StdEnv,
	CoreTypes,
	CoreAccess,
	ProveTypes,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReductionOptions =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ roAmount							:: !ReduceAmount 
	, roMode							:: !ReduceMode
	, roDefinedVariables				:: ![CExprVarPtr]
	, roDefinedExpressions				:: ![CExprH]
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReductionStatus 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= NotReducable							// root normal form found (but not bottom)
	| UndefinedForm							// bottom
	| VariableForm							// always stop reduction (also used for opaque functions)
	| MaybeVariableForm	![CExprVarPtr]		// check if all variables occur in options.roDefined (only in function reduction)
	| ReducedOnce							// only used in ReduceStep
instance DummyValue ReductionStatus
instance == ReductionStatus

/*
ReduceStep			:: !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
InnerReduceStep		:: !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!ReductionStatus, !CExprH), !*CHeaps, !*CProject)
ReduceOld			:: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
InnerReduce			:: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !ReductionStatus, !CExprH), !*CHeaps, !*CProject)
ReduceAll			:: !ReductionOptions !Int !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !CExprH), !*CHeaps, !*CProject)
*/

ReduceNF			:: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !CExprH), !*CHeaps, !*CProject)
ReduceRNF			:: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Int, !Bool, !CExprH), !*CHeaps, !*CProject)
ReduceSteps			:: !Int !ReductionOptions !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)

getRealArity		:: !ReduceMode !CFunDefH -> Int