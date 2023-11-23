/*
** Program: Clean Prover System
** Module:  ProveTypes (.icl)
** 
** Author:  Maarten de Mol
** Created: 30 October 2000
*/

implementation module 
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
	where DummyValue = Shallow
instance == Depth
	where	(==) Shallow	Shallow		= True
			(==) Deep		Deep		= True
			(==) _			_			= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ExprLocation =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllSubExprs
	| SelectedSubExpr		!CName !Int !(Maybe Int)
instance DummyValue ExprLocation
	where DummyValue = AllSubExprs
instance == ExprLocation
	where	(==) AllSubExprs						AllSubExprs							= True
			(==) (SelectedSubExpr name1 num1 arg1)	(SelectedSubExpr name2 num2 arg2)	= name1 == name2 && num1 == num2 && arg1 == arg2
			(==) _									_									= False

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
	where DummyValue = {glToProve = CTrue, glHypotheses = [], glNewHypNum = 1, glNewIHNum = 1,
						glExprVars = [], glPropVars = [], glOpaque = [], glDefinedness = [],
						glInductionVars = [], glRewrittenLR = [], glRewrittenRL = [], glNrIHs = 0}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Hypothesis =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ hypName				:: !CName
	, hypProp				:: !CPropH
	}
instance DummyValue Hypothesis
	where DummyValue = {hypName = "", hypProp = DummyValue}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: MoveDirection =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  MoveIn
	| MoveOut
instance DummyValue MoveDirection
	where DummyValue = MoveIn
instance == MoveDirection
	where	(==) MoveIn		MoveIn		= True
			(==) MoveOut	MoveOut		= True
			(==) _			_			= False

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

// -------------------------------------------------------------------------------------------------------------------------------------------------
EmptyProof :: Proof
// -------------------------------------------------------------------------------------------------------------------------------------------------
EmptyProof
	= 	{ pTree				= nilPtr
		, pLeafs			= []
		, pCurrentLeaf		= nilPtr
		, pCurrentGoal		= DummyValue
		, pFoldedNodes		= []
		, pUsedTheorems		= []
		, pUsedSymbols		= []
		}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ProofTree = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ProofNode			!(Maybe Goal) !TacticId ![ProofTreePtr]
	| ProofLeaf			!Goal
instance DummyValue ProofTree
	where DummyValue = ProofLeaf DummyValue
fromLeaf :: !ProofTree -> Goal; fromLeaf (ProofLeaf goal) = goal

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
	where DummyValue = AllRedexes
instance == Redex
	where	(==) AllRedexes		AllRedexes		= True
			(==) (OneRedex n1)	(OneRedex n2)	= n1 == n2
			(==) _				_				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReduceAmount =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ReduceExactly		!Int
	| ReduceToRNF
	| ReduceToNF
instance DummyValue ReduceAmount
	where DummyValue = ReduceToNF
instance == ReduceAmount
	where	(==) (ReduceExactly steps1)		(ReduceExactly steps2)		= steps1 == steps2
			(==) ReduceToRNF				ReduceToRNF					= True
			(==) ReduceToNF					ReduceToNF					= True
			(==) _							_							= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ReduceMode =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AsInClean
	| Defensive
	| Offensive
instance DummyValue ReduceMode
	where DummyValue = Defensive
instance == ReduceMode
	where	(==) AsInClean		AsInClean		= True
			(==) Defensive		Defensive		= True
			(==) Offensive		Offensive		= True
			(==) _				_				= True

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
	where DummyValue = LeftToRight
instance == RewriteDirection
	where	(==) LeftToRight	LeftToRight		= True
			(==) RightToLeft	RightToLeft		= True
			(==) _				_				= False

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

// -------------------------------------------------------------------------------------------------------------------------------------------------
EmptyTheorem :: Theorem
// -------------------------------------------------------------------------------------------------------------------------------------------------
EmptyTheorem
	=	{ thName			= ""
		, thInitial			= DummyValue
		, thInitialText		= ""
		, thProof			= EmptyProof
		, thSection			= nilPtr
		, thSubgoals		= False
		, thHintScore		= Nothing
		}

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
	where DummyValue = TacticTrivial

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) (TacticAbsurd p1 q1)					(TacticAbsurd p2 q2)				= p1 == p2 && q1 == q2
	(==) TacticAbsurdEquality					TacticAbsurdEquality				= True
	(==) (TacticAbsurdEqualityH p1)				(TacticAbsurdEqualityH p2)			= p1 == p2
	(==) (TacticApply f1)						(TacticApply f2)					= f1 == f2
	(==) (TacticApplyH f1 p1 m1)				(TacticApplyH f2 p2 m2)				= f1 == f2 && p1 == p2 && m1 == m2
	(==) (TacticAssume p1 m1)					(TacticAssume p2 m2)				= p1 == p2 && m1 == m2
	(==) TacticAxiom							TacticAxiom							= True
	(==) (TacticCase d1 i1)						(TacticCase d2 i2)					= d1 == d2 && i1 == i2
	(==) (TacticCaseH d1 p1 m1)					(TacticCaseH d2 p2 m2)				= d1 == d2 && p1 == p2 && m1 == m2
	(==) (TacticCases e1 m1)					(TacticCases e2 m2)					= e1 == e2 && m1 == m2
	(==) TacticChooseCase						TacticChooseCase					= True
	(==) (TacticChooseCaseH p1)					(TacticChooseCaseH p2)				= p1 == p2
	(==) (TacticCompare e1 f1)					(TacticCompare e2 f2)				= e1 == e2 && f1 == f2
	(==) (TacticCompareH p1 m1)					(TacticCompareH p2 m2)				= p1 == p2 && m1 == m2
	(==) (TacticContradiction m1)				(TacticContradiction m2)			= m1 == m2
	(==) (TacticContradictionH p1)				(TacticContradictionH p2)			= p1 == p2
	(==) (TacticCut f1)							(TacticCut f2)						= f1 == f2
	(==) TacticDefinedness						TacticDefinedness					= True
	(==) (TacticDiscard e1 p1 h1)				(TacticDiscard e2 p2 h2)			= e1 == e2 && p1 == p2 && h1 == h2
	(==) (TacticExact f1)						(TacticExact f2)					= f1 == f2
	(==) (TacticExFalso p1)						(TacticExFalso p2)					= p1 == p2
	(==) (TacticExpandFun n1 i1)				(TacticExpandFun n2 i2)				= n1 == n2 && i1 == i2
	(==) (TacticExpandFunH n1 i1 h1 m1)			(TacticExpandFunH n2 i2 h2 m2)		= n1 == n2 && i1 == i2 && h1 == h2 && m1 == m2
	(==) (TacticExtensionality n1)				(TacticExtensionality n2)			= n1 == n2
	(==) (TacticGeneralizeE e1 n1)				(TacticGeneralizeE e2 n2)			= e1 == e2 && n1 == n2
	(==) (TacticGeneralizeP p1 n1)				(TacticGeneralizeP p2 n2)			= p1 == p2 && n1 == n2
	(==) (TacticInduction e1 m1)				(TacticInduction e2 m2)				= e1 == e2 && m1 == m2
	(==) TacticInjective						TacticInjective						= True
	(==) (TacticInjectiveH h1 m1)				(TacticInjectiveH h2 m2)			= h1 == h2 && m1 == m2
	(==) (TacticIntroduce l1)					(TacticIntroduce l2)				= l1 == l2
	(==) (TacticIntArith l1)					(TacticIntArith l2)					= l1 == l2
	(==) (TacticIntArithH l1 h1 m1)				(TacticIntArithH l2 h2 m2)			= l1 == l2 && h1 == h2 && m1 == m2
	(==) TacticIntCompare						TacticIntCompare					= True
	(==) TacticMakeUnique						TacticMakeUnique					= True
	(==) (TacticManualDefinedness ptrs1)		(TacticManualDefinedness ptrs2)		= ptrs1 == ptrs2
	(==) (TacticMoveInCase n1 i1)				(TacticMoveInCase n2 i2)			= True
	(==) (TacticMoveInCaseH n1 i1 h1 m1)		(TacticMoveInCaseH n2 i2 h2 m2)		= n1 == n2 && i1 == i2 && h1 == h2 && m1 == m2
	(==) (TacticMoveQuantors d1)				(TacticMoveQuantors d2)				= d1 == d2
	(==) (TacticMoveQuantorsH d1 h1 m1)			(TacticMoveQuantorsH d2 h2 m2)		= d1 == d2 && h1 == h2 && m1 == m2
	(==) (TacticOpaque p1)						(TacticOpaque p2)					= p1 == p2
	(==) (TacticReduce r1 a1 l1 e1)				(TacticReduce r2 a2 l2 e2)			= r1 == r2 && a1 == a2 && l1 == l2 && e1 == e2
	(==) (TacticReduceH r1 a1 l1 h1 e1 m1)		(TacticReduceH r2 a2 l2 h2 e2 m2)	= r1 == r2 && a1 == a2 && l1 == l2 && h1 == h2 && e1 == e2 && m1 == m2
	(==) TacticRefineUndefinedness				TacticRefineUndefinedness			= True
	(==) (TacticRefineUndefinednessH p1 m1)		(TacticRefineUndefinednessH p2 m2)	= p1 == p2 && m1 == m2
	(==) TacticReflexive						TacticReflexive						= True
	(==) (TacticRemoveCase n1)					(TacticRemoveCase n2)				= n1 == n2
	(==) (TacticRemoveCaseH n1 h1 m1)			(TacticRemoveCaseH n2 h2 m2)		= n1 == n2 && h1 == h2 && m1 == m2
	(==) (TacticRenameE e1 n1)					(TacticRenameE e2 n2)				= e1 == e2 && n1 == n2
	(==) (TacticRenameP p1 n1)					(TacticRenameP p2 n2)				= p1 == p2 && n1 == n2
	(==) (TacticRenameH h1 n1)					(TacticRenameH h2 n2)				= h1 == h2 && n1 == n2
	(==) (TacticRewrite d1 r1 f1)				(TacticRewrite d2 r2 f2)			= d1 == d2 && r1 == r2 && f1 == f2
	(==) (TacticRewriteH d1 r1 f1 h1 m1)		(TacticRewriteH d2 r2 f2 h2 m2)		= d1 == d2 && r1 == r2 && f1 == f2 && h1 == h2 && m1 == m2
	(==) (TacticSpecializeE h1 e1 m1)			(TacticSpecializeE h2 e2 m2)		= h1 == h2 && e1 == e2 && m1 == m2
	(==) (TacticSpecializeP h1 p1 m1)			(TacticSpecializeP h2 p2 m2)		= h1 == h2 && p1 == p2 && m1 == m2
	(==) (TacticSplit d1)						(TacticSplit d2)					= d1 == d2
	(==) (TacticSplitH h1 d1 m1)				(TacticSplitH h2 d2 m2)				= h1 == h2 && d1 == d2 && m1 == m2
	(==) (TacticSplitCase n1 m1)				(TacticSplitCase n2 m2)				= n1 == n2 && m1 == m2
	(==) TacticSplitIff							TacticSplitIff						= True
	(==) (TacticSplitIffH h1 m1)				(TacticSplitIffH h2 m2)				= h1 == h2 && m1 == m2
	(==) TacticSymmetric						TacticSymmetric						= True
	(==) (TacticSymmetricH h1 m1)				(TacticSymmetricH h2 m2)			= h1 == h2 && m1 == m2
	(==) (TacticTransitiveE e1)					(TacticTransitiveE e2)				= e1 == e2
	(==) (TacticTransitiveP p1)					(TacticTransitiveP p2)				= p1 == p2
	(==) (TacticTransparent p1)					(TacticTransparent p2)				= p1 == p2
	(==) TacticTrivial							TacticTrivial						= True
	(==) TacticUncurry							TacticUncurry						= True
	(==) (TacticUncurryH h1 m1)					(TacticUncurryH h2 m2)				= h1 == h2 && m1 == m2
	(==) (TacticUnshare m1 v1 l1 a1)			(TacticUnshare m2 v2 l2 a2)			= m1 == m2 && v1 == v2 && l1 == l2 && a1 == a2
	(==) (TacticUnshareH m1 v1 l1 a1 h1)		(TacticUnshareH m2 v2 l2 a2 h2)		= m1 == m2 && v1 == v2 && l1 == l2 && a1 == a2 && h1 == h2
	(==) (TacticWitnessE e1)					(TacticWitnessE e2)					= e1 == e2
	(==) (TacticWitnessP p1)					(TacticWitnessP p2)					= p1 == p2
	(==) (TacticWitnessH h1 m1)					(TacticWitnessH h2 m2)				= h1 == h2 && m1 == m2
	(==) _										_									= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: TacticMode =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  Explicit
	| Implicit
instance DummyValue TacticMode
	where DummyValue	= Implicit
instance == TacticMode
	where	(==) Explicit		Explicit	= True
			(==) Implicit		Implicit	= True
			(==) _				_			= False

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
	where DummyValue = HypothesisFact nilPtr []
instance == UseFact
	where	(==) (HypothesisFact ptr1 args1)	(HypothesisFact ptr2 args2)		= ptr1 == ptr2 && args1 == args2
			(==) (TheoremFact ptr1 args1)		(TheoremFact ptr2 args2)		= ptr1 == ptr2 && args1 == args2
			(==) _								_								= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UseFactArgument =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  NoArgument
	| ExprArgument			!CExprH
	| PropArgument			!CPropH
instance DummyValue UseFactArgument
	where DummyValue = NoArgument
instance == UseFactArgument
	where	(==) NoArgument						NoArgument						= True
			(==) (ExprArgument e1)				(ExprArgument e2)				= e1 == e2
			(==) (PropArgument p1)				(PropArgument p2)				= p1 == p2
			(==) _								_								= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: VarLocation =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AllVars
	| JustVarIndex			!Int
instance DummyValue VarLocation
	where	DummyValue	= AllVars
instance == VarLocation
	where	(==) AllVars						AllVars							= True
			(==) (JustVarIndex i1)				(JustVarIndex i2)				= i1 == i2
			(==) _								_								= False
instance toString VarLocation
	where	toString AllVars													= "All"
			toString (JustVarIndex i)											= toString i

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








/*
// -------------------------------------------------------------------------------------------------------------------------------------------------
isCommand :: !Command -> !Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isCommand (Tactic tactic)
	= False
isCommand other
	= True

// -------------------------------------------------------------------------------------------------------------------------------------------------
isTactic :: !Command -> !Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isTactic (Tactic tactic)
	= True
isTactic other
	= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
fromTactic :: !Command -> !TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
fromTactic (Tactic tactic)
	= tactic
*/