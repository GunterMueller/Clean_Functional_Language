/*
** Program: Clean Prover System
** Module:  AnnotatedShow (.dcl)
** 
** Author:  Maarten de Mol
** Created: 16 February 2001
*/

definition module 
	AnnotatedShow

import
	States

:: APropH

annotateGoal			:: !CPropH !Goal !*PState -> (!APropH, !*PState)
annotateHypothesis		:: !HypothesisPtr !CPropH !Goal !*PState -> (!APropH, !*PState)
showAnnotated			:: !FormatInfo !APropH !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
