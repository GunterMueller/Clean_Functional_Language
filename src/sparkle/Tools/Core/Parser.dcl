/*
** Program: Clean Prover System
** Module:  Parser (.dcl)
** 
** Author:  Maarten de Mol
** Created: 12 September 2000
*/

definition module 
	Parser

import
	StdEnv,
	Lexical,
	CoreTypes,
	ProveTypes,
	ParseTypes,
	Errors

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PProofCommand =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  P_CmdDebug
	| P_CmdFocus			!Int
	| P_CmdRefresh
	| P_CmdRestartProof
	| P_CmdShowTypes
	| P_CmdTactic			!PTacticId
	| P_CmdTactical			!PTactical
	| P_CmdUndo				!Int
instance DummyValue PProofCommand

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PExprOrProp =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PIdentifier			!CName
	| PExpr					!PExpr
	| PProp					!PProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PFact =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PHypothesisFact		!CName ![PFactArgument]
	| PTheoremFact			!CName ![PFactArgument]

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PFactArgument =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PNoArgument
	| PArgument				!PExprOrProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PTactical = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTacticalCompose		!PTactical !PTactical
	| PTacticalRepeat		!Int !PTactical
	| PTacticalTry			!PTactical
	| PTacticalUnit			!PTacticId

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PTacticId = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTacticAbsurd					!CName !CName
	| PTacticAbsurdEquality			!(Maybe CName)
	| PTacticApply					!PFact !(Maybe CName) !TacticMode
	| PTacticAssume					!PProp !TacticMode
	| PTacticAxiom
	| PTacticCase					!Depth !(Maybe Int) !(Maybe CName) !TacticMode
	| PTacticCases					!PExpr !TacticMode
	| PTacticChooseCase				!(Maybe CName)
	| PTacticCompare				!PExpr !PExpr
	| PTacticCompareH				!CName !TacticMode
	| PTacticContradiction			!(Maybe CName) !TacticMode
	| PTacticCut					!PFact
	| PTacticDefinedness
	| PTacticDiscard				![CName]
	| PTacticExact					!PFact
	| PTacticExFalso				!CName
	| PTacticExpandFun				!CName !Int !(Maybe CName) !TacticMode
	| PTacticExtensionality			!CName
	| PTacticGeneralize				!PExprOrProp !CName
	| PTacticInduction				!CName !TacticMode
	| PTacticInjective				!(Maybe CName) !TacticMode
	| PTacticIntroduce				![CName]
	| PTacticIntArith				!ExprLocation !(Maybe CName) !TacticMode
	| PTacticIntCompare
	| PTacticMakeUnique
	| PTacticManualDefinedness		![CName]
	| PTacticMoveInCase				!CName !Int !(Maybe CName) !TacticMode
	| PTacticMoveQuantors			!MoveDirection !(Maybe CName) !TacticMode
	| PTacticOpaque					!PQualifiedName
	| PTacticReduce					!ReduceMode !ReduceAmount !ExprLocation !(Maybe CName) ![CName] !TacticMode
	| PTacticRefineUndefinedness	!(Maybe CName) !TacticMode
	| PTacticReflexive
	| PTacticRemoveCase				!Int !(Maybe CName) !TacticMode
	| PTacticRename					!CName !CName
	| PTacticRewrite				!RewriteDirection !Redex !PFact !(Maybe CName) !TacticMode
	| PTacticSpecialize				!CName !PExprOrProp !TacticMode
	| PTacticSplit					!(Maybe CName) !Depth !TacticMode
	| PTacticSplitCase				!Int !TacticMode
	| PTacticSplitIff				!(Maybe CName) !TacticMode
	| PTacticSymmetric				!(Maybe CName) !TacticMode
	| PTacticTransitive				!PExprOrProp
	| PTacticTransparent			!PQualifiedName
	| PTacticTrivial	
	| PTacticUncurry				!(Maybe CName) !TacticMode
	| PTacticUnshare				!DestroyAfterwards !LetLocation !CName !VarLocation !(Maybe CName)
	| PTacticWitness				!PExprOrProp !(Maybe CName) !TacticMode
instance DummyValue PTacticId

class hasBrackets a :: a -> Bool
instance hasBrackets PExpr
instance hasBrackets PProp

parseExpression		:: ![CLexeme] -> (!Error, !PExpr)
parseProposition	:: ![CLexeme] -> (!Error, !PProp)
parseProofCommand	:: ![CLexeme] -> (!Error, !PProofCommand)
parseFactArguments	:: ![CLexeme] -> (!Error, ![PFactArgument])
