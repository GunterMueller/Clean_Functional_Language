/*
** Program: Clean Prover System
** Module:  CoreCheat (.dcl)
** 
** Author:  Maarten de Mol
** Created: 22 November 2000
*/

definition module 
	CoreCheat

import
	StdEnv,
	Heap,
	CoreTypes

:: CheatCompiler = CheatCompiler

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: CheatProver =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CheatExpr		!CExprVarPtr
	| CheatType		!CTypeVarPtr

fromExpr	:: !CheatProver -> CExprVarPtr
fromType	:: !CheatProver -> CTypeVarPtr
toProver	:: !CheatCompiler -> CheatProver
toCompiler	:: !CheatProver -> CheatCompiler
