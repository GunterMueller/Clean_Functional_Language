/*
** Program: Clean Prover System
** Module:  PolishWrite (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 March 2001
*/

definition module
	PolishWrite

import
	CoreTypes,
	Heaps,
	ProveTypes

class polishWrite a			:: ![HeapPtr] !a !*File !*CHeaps !*CProject -> (!*File, !*CHeaps, !*CProject)

instance polishWrite {#Char}
instance polishWrite (Ptr a)				| Pointer a
instance polishWrite HeapPtr
instance polishWrite [a]					| polishWrite a
instance polishWrite (Maybe a)				| polishWrite a

instance polishWrite (CAlgPattern HeapPtr)
instance polishWrite (CBasicPattern HeapPtr)
instance polishWrite (CBasicValue HeapPtr)
instance polishWrite (CCasePatterns HeapPtr)
instance polishWrite (CExpr HeapPtr)
instance polishWrite (CProp HeapPtr)

instance polishWrite Depth
instance polishWrite Redex
instance polishWrite ReduceAmount
instance polishWrite RewriteDirection
instance polishWrite TacticId
instance polishWrite UseFact