/*
** Program: Clean Prover System
** Module:  ProveTypes (.dcl)
** 
** Author:  Maarten de Mol
** Created: 30 October 2000
*/

definition module 
	ProveTypes

import
	StdEnv,
	StdIOBasic,
	CoreTypes,
	LTypes,
	ParseTypes,
	MarkUpText

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Depth =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  Shallow
	| Deep
instance DummyValue Depth
instance == Depth

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ExprLocation =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllSubExprs
	| SelectedSubExpr		!CName !Int !(Maybe Int)
instance DummyValue ExprLocation
instance == ExprLocation

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Goal =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ glToProve				:: !CPropH
	, glHypotheses			:: ![HypothesisPtr]
	, glNewHypNum			:: !Int						// used for creating new names for hypotheses
	, glNewIHNum			:: !Int						// used for creating new names for Induction Hypotheses
	, glExprVars			:: ![CExprVarPtr]
	, glPropVars			:: ![CPropVarPtr]
	, glOpaque				:: ![HeapPtr]				// local administration for Opaque/Transparent
	, glDefinedness			:: ![(HeapPtr, [Bool])]		// local administration for ManualDefinedness
	, glInductionVars		:: ![CExprVarPtr]			// variables created by induction (reduce induction likeliness)
	, glRewrittenLR			:: ![HypothesisPtr]			// hypotheses used for rewriting (LR) in the current goal (do not propose RL as hint)
	, glRewrittenRL			:: ![HypothesisPtr]			// hypotheses used for rewriting (RL) in the current goal (do not propose LR as hint)
	, glNrIHs				:: !Int						// number of p -> q (at the top) where p is an induction hypothesis
	}
instance DummyValue Goal

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Hypothesis =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ hypName				:: !CName
	, hypProp				:: !CPropH
	}
instance DummyValue Hypothesis

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: MoveDirection =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  MoveIn
	| MoveOut
instance DummyValue MoveDirection
instance == MoveDirection

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Proof =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ pTree					:: !ProofTreePtr
	, pLeafs				:: ![ProofTreePtr]
	, pCurrentLeaf			:: !ProofTreePtr
	, pCurrentGoal			:: !Goal
	, pFoldedNodes			:: ![ProofTreePtr]				// for user interface only
	, pUsedTheorems			:: ![TheoremPtr]
	, pUsedSymbols			:: ![HeapPtr]					// used functions + data-constructors
	}
EmptyProof :: Proof

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ProofTree = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ProofNode			!(Maybe Goal) !TacticId ![ProofTreePtr]
	| ProofLeaf			!Goal
instance DummyValue ProofTree
fromLeaf :: !ProofTree -> Goal

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ProvingAction =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  KnowArguments			!TacticId

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Redex =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllRedexes
	| OneRedex				!Int
instance DummyValue Redex
instance == Redex

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReduceAmount =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ReduceExactly		!Int
	| ReduceToRNF
	| ReduceToNF
instance DummyValue ReduceAmount
instance == ReduceAmount

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReduceMode =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AsInClean
	| Defensive
	| Offensive
instance DummyValue ReduceMode
instance == ReduceMode

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReductionStrategy =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  Lazy
	| Eager

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: RewriteDirection =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LeftToRight
	| RightToLeft
instance DummyValue RewriteDirection
instance == RewriteDirection

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: RewriteOccurrence =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllOccurrences
	| OneOccurrence			!Int

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Section =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ seName				:: !CName
	, seTheorems			:: ![TheoremPtr]
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Theorem =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ thName				:: !CName
	, thInitial				:: !CPropH
	, thInitialText			:: !String
	, thProof				:: !Proof
	, thSection				:: !SectionPtr
	, thSubgoals			:: !Bool
	, thHintScore			:: !Maybe (Int, Int, Int, Int)			// apply, apply forward, rewrite ->, rewrite <-
	}
EmptyTheorem :: Theorem

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TacticId = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  TacticAbsurd					!HypothesisPtr !HypothesisPtr
	| TacticAbsurdEquality
	| TacticAbsurdEqualityH			!HypothesisPtr
	| TacticApply					!UseFact
	| TacticApplyH					!UseFact !HypothesisPtr !TacticMode
	| TacticAssume					!CPropH !TacticMode
	| TacticAxiom
	| TacticCase					!Depth !Int
	| TacticCaseH					!Depth !HypothesisPtr !TacticMode
	| TacticCases					!CExprH !TacticMode
	| TacticChooseCase
	| TacticChooseCaseH				!HypothesisPtr
	| TacticCompare					!CExprH !CExprH
	| TacticCompareH				!HypothesisPtr !TacticMode
	| TacticContradiction			!TacticMode
	| TacticContradictionH			!HypothesisPtr
	| TacticCut						!UseFact
	| TacticDefinedness
	| TacticDiscard					![CExprVarPtr] ![CPropVarPtr] ![HypothesisPtr]
	| TacticExact					!UseFact
	| TacticExFalso					!HypothesisPtr
	| TacticExpandFun				!CName !Int
	| TacticExpandFunH				!CName !Int !HypothesisPtr !TacticMode
	| TacticExtensionality			!CName
	| TacticGeneralizeE				!CExprH !CName
	| TacticGeneralizeP				!CPropH !CName
	| TacticInduction				!CExprVarPtr !TacticMode
	| TacticInjective
	| TacticInjectiveH				!HypothesisPtr !TacticMode
	| TacticIntroduce				![CName]
	| TacticIntArith				!ExprLocation
	| TacticIntArithH				!ExprLocation !HypothesisPtr !TacticMode
	| TacticIntCompare
	| TacticMakeUnique
	| TacticManualDefinedness		![TheoremPtr]
	| TacticMoveInCase				!CName !Int
	| TacticMoveInCaseH				!CName !Int !HypothesisPtr !TacticMode
	| TacticMoveQuantors			!MoveDirection
	| TacticMoveQuantorsH			!MoveDirection !HypothesisPtr !TacticMode
	| TacticOpaque					!HeapPtr
	| TacticReduce					!ReduceMode !ReduceAmount !ExprLocation ![CExprVarPtr]
	| TacticReduceH					!ReduceMode !ReduceAmount !ExprLocation !HypothesisPtr ![CExprVarPtr] !TacticMode
	| TacticRefineUndefinedness
	| TacticRefineUndefinednessH	!HypothesisPtr !TacticMode
	| TacticReflexive
	| TacticRemoveCase				!Int
	| TacticRemoveCaseH				!Int !HypothesisPtr !TacticMode
	| TacticRenameE					!CExprVarPtr !CName
	| TacticRenameP					!CPropVarPtr !CName
	| TacticRenameH					!HypothesisPtr !CName
	| TacticRewrite					!RewriteDirection !Redex !UseFact
	| TacticRewriteH				!RewriteDirection !Redex !UseFact !HypothesisPtr !TacticMode
	| TacticSpecializeE				!HypothesisPtr !CExprH !TacticMode
	| TacticSpecializeP				!HypothesisPtr !CPropH !TacticMode
	| TacticSplit					!Depth
	| TacticSplitH					!HypothesisPtr !Depth !TacticMode
	| TacticSplitCase				!Int !TacticMode
	| TacticSplitIff
	| TacticSplitIffH				!HypothesisPtr !TacticMode
	| TacticSymmetric
	| TacticSymmetricH				!HypothesisPtr !TacticMode
	| TacticTransitiveE				!CExprH
	| TacticTransitiveP				!CPropH
	| TacticTransparent				!HeapPtr
	| TacticTrivial
	| TacticUncurry
	| TacticUncurryH				!HypothesisPtr !TacticMode
	| TacticUnshare					!DestroyAfterwards !LetLocation !CName !VarLocation
	| TacticUnshareH				!DestroyAfterwards !LetLocation !CName !VarLocation !HypothesisPtr
	| TacticWitnessE				!CExprH
	| TacticWitnessP				!CPropH
	| TacticWitnessH				!HypothesisPtr !TacticMode
instance DummyValue TacticId
instance == TacticId

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TacticMode =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  Explicit
	| Implicit
instance DummyValue TacticMode
instance == TacticMode

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UseExprVar =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  KnownExprVar			!CName !CExprVarPtr
	| UnknownExprVar		!CName

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UseFact =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  HypothesisFact		!HypothesisPtr		![UseFactArgument]
	| TheoremFact			!TheoremPtr			![UseFactArgument]
instance DummyValue UseFact
instance == UseFact

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UseFactArgument =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  NoArgument
	| ExprArgument			!CExprH
	| PropArgument			!CPropH
instance DummyValue UseFactArgument
instance == UseFactArgument

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: VarLocation =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllVars
	| JustVarIndex			!Int
instance DummyValue VarLocation
instance == VarLocation
instance toString VarLocation

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DestroyAfterwards	:== Bool
:: ExprInProp			:== CPropH					// [x][y].expr = FALSE
:: HypothesisPtr		:== Ptr Hypothesis
:: LetLocation			:== Int
:: ProofTreePtr			:== Ptr ProofTree
:: SectionPtr			:== Ptr Section
:: TheoremPtr			:== Ptr Theorem
:: UseWeight			:== Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------








//isCommand :: !Command -> !Bool
//isTactic :: !Command -> !Bool
//fromTactic :: !Command -> !TacticId