/*
** Program: Clean Prover System
** Module:  Print (.icl)
** 
** Author:  Maarten de Mol
** Created: 6 November 2000
*/

implementation module 
	Print

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	Heaps


// DEBUG
fff :: ![a] -> Int
fff l
	| isEmpty l			= 1
fff [x:xs]
	= 2
fff _
	= 3


// -------------------------------------------------------------------------------------------------------------------------------------------------
class makePrintable a :: !(a HeapPtr) !*CHeaps !*CProject -> *(!a CName, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableD :: !HeapPtr !*CHeaps !*CProject -> (!CName, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableD ptr heaps prj
	# (error, name, heaps, prj)		= getDefinitionName ptr heaps prj
	| isError error					= ("_NO_NAME_", heaps, prj)
	= (name, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableL :: ![a HeapPtr] !*CHeaps !*CProject -> (![a CName], !*CHeaps, !*CProject) | makePrintable a
// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableL [x:xs] heaps prj
	# (x, heaps, prj)				= makePrintable x heaps prj
	# (xs, heaps, prj)				= makePrintableL xs heaps prj
	= ([x:xs], heaps, prj)
makePrintableL [] heaps prj
	= ([], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableM :: !(Maybe (a HeapPtr)) !*CHeaps !*CProject -> (!Maybe (a CName), !*CHeaps, !*CProject) | makePrintable a
// -------------------------------------------------------------------------------------------------------------------------------------------------
makePrintableM (Just x) heaps prj
	# (x, heaps, prj)				= makePrintable x heaps prj
	= (Just x, heaps, prj)
makePrintableM Nothing heaps prj
	= (Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CAlgPattern 
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable pattern heaps prj
		# (cons, heaps, prj)		= makePrintableD pattern.atpDataCons heaps prj
		# scope						= repeatn (length pattern.atpExprVarScope) nilPtr
		# (result, heaps, prj)		= makePrintable pattern.atpResult heaps prj
		= ({pattern & atpDataCons = cons, atpExprVarScope = scope, atpResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable pattern heaps prj
		# (value, heaps, prj)		= makePrintable pattern.bapBasicValue heaps prj
		# (result, heaps, prj)		= makePrintable pattern.bapResult heaps prj
		= ({pattern & bapBasicValue = value, bapResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable (CBasicInteger n) heaps prj
		= (CBasicInteger n, heaps, prj)
	makePrintable (CBasicCharacter c) heaps prj
		= (CBasicCharacter c, heaps, prj)
	makePrintable (CBasicRealNumber r) heaps prj
		= (CBasicRealNumber r, heaps, prj)
	makePrintable (CBasicBoolean b) heaps prj
		= (CBasicBoolean b, heaps, prj)
	makePrintable (CBasicString s) heaps prj
		= (CBasicString s, heaps, prj)
	makePrintable (CBasicArray exprs) heaps prj
		# (exprs, heaps, prj)		= makePrintableL exprs heaps prj
		= (CBasicArray exprs, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable (CAlgPatterns type patterns) heaps prj
		# (type, heaps, prj)		= makePrintableD type heaps prj
		# (patterns, heaps, prj)	= makePrintableL patterns heaps prj
		= (CAlgPatterns type patterns, heaps, prj)
	makePrintable (CBasicPatterns type patterns) heaps prj
		# (patterns, heaps, prj)	= makePrintableL patterns heaps prj
		= (CBasicPatterns type patterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CClassRestriction
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable restriction heaps prj
		# (ptr, heaps, prj)			= makePrintableD restriction.ccrClass heaps prj
		# (types, heaps, prj)		= makePrintableL restriction.ccrTypes heaps prj
		= ({restriction & ccrClass = ptr, ccrTypes = types}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable (CExprVar ptr) heaps prj
		# (name, heaps)				= getPointerName ptr heaps
		= (name @@# [], heaps, prj)
	makePrintable (CShared ptr) heaps prj
		# (name, heaps)				= getPointerName ptr heaps
		= (name @@# [], heaps, prj)
	makePrintable (expr @# exprs) heaps prj
		# (expr, heaps, prj)		= makePrintable expr heaps prj
		# (exprs, heaps, prj)		= makePrintableL exprs heaps prj
		= (expr @# exprs, heaps, prj)
	makePrintable (ptr @@# exprs) heaps prj
		# (ptr, heaps, prj)			= makePrintableD ptr heaps prj
		# (exprs, heaps, prj)		= makePrintableL exprs heaps prj
		= (ptr @@# exprs, heaps, prj)
	makePrintable (CLet strict lets expr) heaps prj
		# (vars, exprs)				= unzip lets
		# vars						= repeatn (length vars) nilPtr
		# (exprs, heaps, prj)		= makePrintableL exprs heaps prj
		# lets						= zip2 vars exprs
		# (expr, heaps, prj)		= makePrintable expr heaps prj
		= (CLet strict lets expr, heaps, prj)
	makePrintable (CCase expr patterns def) heaps prj
		# (expr, heaps, prj)		= makePrintable expr heaps prj
		# (patterns, heaps, prj)	= makePrintable patterns heaps prj
		# (def, heaps, prj)			= makePrintableM def heaps prj
		= (CCase expr patterns def, heaps, prj)
	makePrintable (CBasicValue value) heaps prj
		# (value, heaps, prj)		= makePrintable value heaps prj
		= (CBasicValue value, heaps, prj)
	makePrintable (CCode codetype codecontents) heaps prj
		= (CCode codetype codecontents, heaps, prj)
	makePrintable CBottom heaps prj
		= (CBottom, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable (CPropVar ptr) heaps prj
		# (name, heaps)				= getPointerName ptr heaps
		= (CEqual (name @@# []) (name @@# []), heaps, prj)
	makePrintable CTrue heaps prj
		= (CTrue, heaps, prj)
	makePrintable CFalse heaps prj
		= (CFalse, heaps, prj)
	makePrintable (CNot p) heaps prj
		# (p,  heaps, prj)			= makePrintable p heaps prj
		= (CNot p, heaps, prj)
	makePrintable (CAnd p q) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		# (q, heaps, prj)			= makePrintable q heaps prj
		= (CAnd p q, heaps, prj)
	makePrintable (COr p q) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		# (q, heaps, prj)			= makePrintable q heaps prj
		= (CAnd p q, heaps, prj)
	makePrintable (CImplies p q) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		# (q, heaps, prj)			= makePrintable q heaps prj
		= (CAnd p q, heaps, prj)
	makePrintable (CIff p q) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		# (q, heaps, prj)			= makePrintable q heaps prj
		= (CIff p q, heaps, prj)
	makePrintable (CExprForall var p) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		= (CExprForall nilPtr p, heaps, prj)
	makePrintable (CExprExists var p) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		= (CExprExists nilPtr p, heaps, prj)
	makePrintable (CPropForall var p) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		= (CPropForall nilPtr p, heaps, prj)
	makePrintable (CPropExists var p) heaps prj
		# (p, heaps, prj)			= makePrintable p heaps prj
		= (CPropExists nilPtr p, heaps, prj)
	makePrintable (CEqual e1 e2) heaps prj
		# (e1, heaps, prj)			= makePrintable e1 heaps prj
		# (e2, heaps, prj)			= makePrintable e2 heaps prj
		= (CEqual e1 e2, heaps, prj)
	makePrintable (CPredicate ptr es) heaps prj
		# (name, heaps, prj)		= makePrintableD ptr heaps prj
		# (es, heaps, prj)			= makePrintableL es heaps prj
		= (CPredicate name es, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CSymbolType
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable symboltype heaps prj
		# (arguments, heaps, prj)	= makePrintableL symboltype.sytArguments heaps prj
		# (result, heaps, prj)		= makePrintable symboltype.sytResult heaps prj
		# (restrictions, heaps, prj)= makePrintableL symboltype.sytClassRestrictions heaps prj
		= ({symboltype & sytArguments = arguments, sytResult = result, sytClassRestrictions = restrictions}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makePrintable CType
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makePrintable (CTypeVar ptr) heaps prj
		# (name, heaps)				= getPointerName ptr heaps
		= (name @@^ [], heaps, prj)
	makePrintable (type1 ==> type2) heaps prj
		# (type1, heaps, prj)		= makePrintable type1 heaps prj
		# (type2, heaps, prj)		= makePrintable type2 heaps prj
		= (type1 ==> type2, heaps, prj)
	makePrintable (type @^ types) heaps prj
		# (type, heaps, prj)		= makePrintable type heaps prj
		# (types, heaps, prj)		= makePrintableL types heaps prj
		= (type @^ types, heaps, prj)
	makePrintable (ptr @@^ types) heaps prj
		# (ptr, heaps, prj)			= makePrintableD ptr heaps prj
		# (types, heaps, prj)		= makePrintableL types heaps prj
		= (ptr @@^ types, heaps, prj)
	makePrintable (CBasicType type) heaps prj
		= (CBasicType type, heaps, prj)
	makePrintable (CStrict type) heaps prj
		# (type, heaps, prj)		= makePrintable type heaps prj
		= (CStrict type, heaps, prj)
	makePrintable CUnTypable heaps prj
		= (CUnTypable, heaps, prj)













// -------------------------------------------------------------------------------------------------------------------------------------------------
class makeText a :: !a -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makeText [a] | makeText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makeText [x:xs]
		# text1						= makeText x
		| isEmpty xs				= text1
		# text2						= makeText xs
		= text1 +++ " " +++ text2
	makeText []
		= ""

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makeText CBasicType
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makeText CInteger					= "Int"
	makeText CCharacter					= "Char"
	makeText CRealNumber				= "Real"
	makeText CBoolean					= "Bool"
	makeText CString					= "String"

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance makeText (CType {#Char})
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	makeText (CTypeVar ptr)
		= "?"
	makeText (type1 ==> type2)
		= "(" +++ makeText type1 +++ " ==> " +++ makeText type2 +++ ")"
	makeText (type @^ types)
		| isEmpty types				= makeText type
		= "(" +++ makeText type +++ " " +++ makeText types +++ ")"
	makeText (name @@^ types)
		| isEmpty types				= name
		= "(" +++ name +++ " " +++ makeText types +++ ")"
	makeText (CBasicType basic)
		= makeText basic
	makeText (CStrict type)
		= "!" +++ makeText type
	makeText CUnTypable
		= "_|_"