/*
** Program: Clean Prover System
** Module:  Conversion (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

definition module 
	Conversion

import 
	StdEnv,
	CoreTypes,
	Heaps,
	frontend

convertFrontEndSyntaxTree :: !*FrontEndSyntaxTree !*Heaps !ModuleKey !String !*CHeaps !*CProject -> (!Error, !ModulePtr, !*Heaps, !*CHeaps, !*CProject)