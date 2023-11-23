/*
** Program: Clean Prover System
** Module:  Compilation (.dcl)
** 
** Author:  Maarten de Mol
** Created: 5 July 1999
**
** Contents:
*/

definition module 
   Compilation

import 
   StdEnv,
   StdMaarten,
   frontend,
   Types,
   Errors,
   ProverOptions
   
CompileICLModule :: !TModuleName !TPath !ProjectStructure *file_env -> ((Maybe !(TModule TCompilerSymbol), !TErrorInfo), *file_env) | FileEnv file_env