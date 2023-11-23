/*
** Program: Clean Prover System
** Module:  CoreAccess (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 August 2000
*/

definition module 
	CoreAccess

import
	StdEnv,
	CoreTypes,
	Heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DefinitionInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ diPointer			:: !HeapPtr
	, diInfix			:: !Bool							// hack -- is handy!
	, diKind			:: !DefinitionKind
	, diModuleName		:: !CName
	, diName			:: !CName
	, diArity			:: !CArity
	}

getAlgTypeDef		:: !HeapPtr !*CProject -> (!Error, !CAlgTypeDefH, !*CProject)
getClassDef			:: !HeapPtr !*CProject -> (!Error, !CClassDefH, !*CProject)
getDataConsDef		:: !HeapPtr !*CProject -> (!Error, !CDataConsDefH, !*CProject)
getFunDef			:: !HeapPtr !*CProject -> (!Error, !CFunDefH, !*CProject)
getInstanceDef		:: !HeapPtr !*CProject -> (!Error, !CInstanceDefH, !*CProject)
getMemberDef		:: !HeapPtr !*CProject -> (!Error, !CMemberDefH, !*CProject)
getRecordFieldDef	:: !HeapPtr !*CProject -> (!Error, !CRecordFieldDefH, !*CProject)
getRecordTypeDef	:: !HeapPtr !*CProject -> (!Error, !CRecordTypeDefH, !*CProject)

putAlgTypeDef		:: !HeapPtr !CAlgTypeDefH		!*CProject -> (!Error, !*CProject)
putClassDef			:: !HeapPtr !CClassDefH			!*CProject -> (!Error, !*CProject)
putDataConsDef		:: !HeapPtr !CDataConsDefH		!*CProject -> (!Error, !*CProject)
putFunDef			:: !HeapPtr !CFunDefH			!*CProject -> (!Error, !*CProject)
putInstanceDef		:: !HeapPtr !CInstanceDefH		!*CProject -> (!Error, !*CProject)
putMemberDef		:: !HeapPtr !CMemberDefH		!*CProject -> (!Error, !*CProject)
putRecordFieldDef	:: !HeapPtr !CRecordFieldDefH	!*CProject -> (!Error, !*CProject)
putRecordTypeDef	:: !HeapPtr !CRecordTypeDefH	!*CProject -> (!Error, !*CProject)

getHeapPtrs			:: ![ModulePtr] ![DefinitionKind] !*CHeaps -> (!Error, ![HeapPtr], !*CHeaps)
getDefinitionInfo	:: !HeapPtr			!*CHeaps	!*CProject -> (!Error, !DefinitionInfo, !*CHeaps, !*CProject)
getDefinitionArity	:: !HeapPtr			!*CHeaps	!*CProject -> (!Error, !CArity, !*CHeaps, !*CProject)
getDefinitionInfix	:: !HeapPtr			!*CHeaps	!*CProject -> (!Error, !CInfix, !*CHeaps, !*CProject)
getDefinitionName	:: !HeapPtr			!*CHeaps	!*CProject -> (!Error, !CName, !*CHeaps, !*CProject)
getSymbolType		:: !HeapPtr			!*CHeaps	!*CProject -> (!Error, !CSymbolTypeH, !*CHeaps, !*CProject)
isDictionary		:: !CTypeH						!*CProject -> (!Bool, !*CProject)
countDictionaries	:: !CSymbolTypeH				!*CProject -> (!Int, !*CProject)

safePtrEq			:: !(Ptr a) !(Ptr a) -> Bool
findABCFunctions	:: !*CHeaps !*CProject -> (!*CHeaps, !*CProject)



// ------- debug ---------- //
class eval a :: !a -> a
instance eval [a] | eval a
instance eval (Maybe a) | eval a
instance eval (CAlgPattern a)
instance eval (CBasicPattern a)
instance eval (CBasicValue a)
instance eval (CCasePatterns a)
instance eval (CExpr a)
instance eval (CProp a)