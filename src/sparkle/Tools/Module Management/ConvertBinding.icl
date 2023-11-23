/*
** Program: Clean Prover System
** Module:  ConvertBinding (.icl)
** 
** Author:  Maarten de Mol
** Created: 25 August 1999
*/

implementation module 
   ConvertBinding

import 
   StdEnv,
   Types,
   Errors,
   State,
   HandleError
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
Bindings_Compiler2Internal ::(TEnvironment TCompilerSymbol) -> (TErrorInfo, TEnvironment TInternalSymbol)
// -------------------------------------------------------------------------------------------------------------------------------------------------
Bindings_Compiler2Internal env
   = (Nothing, DummyEnv)