/*
** Program: Clean Prover System
** Module:  Print (.dcl)
** 
** Author:  Maarten de Mol
** Created: 6 November 2000
*/

definition module 
	Print

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	Heaps

fff :: ![a] -> Int


class makePrintable a :: !(a HeapPtr) !*CHeaps !*CProject -> *(!a CName, !*CHeaps, !*CProject)

makePrintableD :: !HeapPtr !*CHeaps !*CProject -> (!CName, !*CHeaps, !*CProject)
makePrintableL :: ![a HeapPtr] !*CHeaps !*CProject -> (![a CName], !*CHeaps, !*CProject) | makePrintable a
makePrintableM :: !(Maybe (a HeapPtr)) !*CHeaps !*CProject -> (!Maybe (a CName), !*CHeaps, !*CProject) | makePrintable a

instance makePrintable CExpr
instance makePrintable CProp
instance makePrintable CSymbolType
instance makePrintable CType

class makeText a :: !a -> String
instance makeText [a] | makeText a
instance makeText CBasicType
instance makeText (CType {#Char})
