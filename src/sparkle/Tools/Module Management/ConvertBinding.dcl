/*
** Program: Clean Prover System
** Module:  ConvertBinding (.dcl)
** 
** Author:  Maarten de Mol
** Created: 25 August 1999
*/

definition module 
   ConvertBinding

import 
   StdEnv,
   Types,
   Errors,
   State,
   HandleError
   
Bindings_Compiler2Internal ::(TEnvironment TCompilerSymbol) -> (TErrorInfo, TEnvironment TInternalSymbol)