/*
** Program: Clean Prover System
** Module:  LDeltaRules (.icl)
** 
** Author:  Maarten de Mol
** Created: 18 December 2007
**
** Notes(1): In some cases, there is only one function for a class.
**           For ==, for example, always the function 'Equal' is used. 
**           It works for all basic types.
** Notes(2): Although the type 'String' does not exist, an internal
**           optimized representation of strings DOES. All functions
**           on arrays must be able to deal with this representation.
*/

implementation module 
	LDeltaRules

import
	StdEnv,
	CoreTypes,
	CoreAccess,
	LTypes,
	Predefined
	, RWSDebug

// Checks if a function (given by the pointer) has a 'known' abc-body.
// If so, the special ABCFunction field is filled in.
// Can also be used for optimalization.
// -------------------------------------------------------------------------------------------------------------------------------------------------
setDeltaRules :: !HeapPtr !ModuleName !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
setDeltaRules ptr mod_name fundef heaps prj
	| mod_name == "_SystemArray"
		| fundef.fdName == "_createArray"		= setAction (actCreateArrayU ptr) CF fundef heaps prj
		| fundef.fdName == "replace"			= setAction (actReplace ptr) CF fundef heaps prj
		| fundef.fdName == "select"				= setAction (actSelect ptr) CF fundef heaps prj
		| fundef.fdName == "uselect"			= setAction (actSelectU ptr) CF fundef heaps prj
		| fundef.fdName % (0,3) == "size"		= setAction (actSize ptr) CT fundef heaps prj
		| fundef.fdName % (0,3) == "usize"		= setAction (actSizeU ptr) CF fundef heaps prj
		| fundef.fdName == "update"				= setAction (actUpdate ptr) CF fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdBool"
		| fundef.fdName == "&&"					= setAction (actAnd ptr) CTT fundef heaps prj
		| fundef.fdName == "||"					= setAction (actOr ptr) CTT fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CF fundef heaps prj
		| fundef.fdName == "fromBool"			= setAction (actFromBool ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "not"				= setAction (actNot ptr) CT fundef heaps prj
		| fundef.fdName == "toBool"				= setAction (actToBool ptr) CF fundef heaps prj
//		| fundef.fdName == "toString"			= setAction (actToString ptr) False fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdChar"
//		| fundef.fdName == "clear_lowercase_bit"= setAction (actClearLowercaseBit ptr) CT fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CF fundef heaps prj
		| fundef.fdName == "fromChar"			= setAction (actFromChar ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "-"					= setAction (actMinus ptr) CTT fundef heaps prj
		| fundef.fdName == "one"				= setAction (actOne ptr CCharacter) CF fundef heaps prj
		| fundef.fdName == "+"					= setAction (actPlus ptr) CTT fundef heaps prj
//		| fundef.fdName == "set_lowercase_bit"	= setAction (actSetLowercaseBit ptr) CT fundef heaps prj
		| fundef.fdName == "<"					= setAction (actSmaller ptr) CTT fundef heaps prj
		| fundef.fdName == "toChar"				= setAction (actToChar ptr) CF fundef heaps prj
		| fundef.fdName == "zero"				= setAction (actZero ptr CCharacter) CF fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdInt"
		| fundef.fdName == "bitand"				= setAction (actBitAnd ptr) CTT fundef heaps prj
		| fundef.fdName == "bitnot"				= setAction (actBitNot ptr) CTT fundef heaps prj
		| fundef.fdName == "bitor"				= setAction (actBitOr ptr) CTT fundef heaps prj
		| fundef.fdName == "bitxor"				= setAction (actBitXor ptr) CTT fundef heaps prj
		| fundef.fdName == "/"					= setAction (actDiv ptr) CF fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CT fundef heaps prj
		| fundef.fdName == "fromInt"			= setAction (actFromInt ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "isEven"				= setAction (actIsEven ptr) CT fundef heaps prj
		| fundef.fdName == "isOdd"				= setAction (actIsOdd ptr) CT fundef heaps prj
		| fundef.fdName == "-"					= setAction (actMinus ptr) CTT fundef heaps prj
		| fundef.fdName == "~"					= setAction (actNegative ptr) CT fundef heaps prj
/* RWS, no instance mod Int
		| fundef.fdName == "mod"				= setAction (actMod ptr) False fundef heaps prj
*/
		| fundef.fdName == "one"				= setAction (actOne ptr CInteger) CF fundef heaps prj
		| fundef.fdName == "+"					= setAction (actPlus ptr) CTT fundef heaps prj
		| fundef.fdName == "rem"				= setAction (actRemainder ptr) CF fundef heaps prj
		| fundef.fdName == "<<"					= setAction (actShiftLeft ptr) CT fundef heaps prj
		| fundef.fdName == ">>"					= setAction (actShiftRight ptr) CT fundef heaps prj
		| fundef.fdName == "<"					= setAction (actSmaller ptr) CTT fundef heaps prj
		| fundef.fdName == "*"					= setAction (actTimes ptr) CTT fundef heaps prj
		| fundef.fdName == "toInt"
			# type								= removeStrictness (hd fundef.fdSymbolType.sytArguments)
			| basicType type					= setAction (actToInt ptr type) CF fundef heaps prj
			= (fundef, heaps, prj)
		| fundef.fdName == "zero"				= setAction (actZero ptr CInteger) CF fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdMisc"
		| fundef.fdName == "abort"				= setAction (actAbort ptr) CF fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdReal"
		| fundef.fdName == "acos"				= setAction (actAcos ptr) CF fundef heaps prj
		| fundef.fdName == "asin"				= setAction (actAsin ptr) CF fundef heaps prj
		| fundef.fdName == "atan"				= setAction (actAtan ptr) CF fundef heaps prj
		| fundef.fdName == "cos"				= setAction (actCos ptr) CF fundef heaps prj
		| fundef.fdName == "entier"				= setAction (actEntier ptr) CT fundef heaps prj
		| fundef.fdName == "exp"				= setAction (actExp ptr) CF fundef heaps prj
		| fundef.fdName == "/"					= setAction (actDiv ptr) CF fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CT fundef heaps prj
		| fundef.fdName == "fromReal"			= setAction (actFromReal ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "ln"					= setAction (actLn ptr) CF fundef heaps prj
		| fundef.fdName == "log10"				= setAction (actLogTen ptr) CF fundef heaps prj
		| fundef.fdName == "-"					= setAction (actMinus ptr) CTT fundef heaps prj
		| fundef.fdName == "~"					= setAction (actNegative ptr) CT fundef heaps prj
		| fundef.fdName == "one"				= setAction (actOne ptr CInteger) CF fundef heaps prj
		| fundef.fdName == "+"					= setAction (actPlus ptr) CTT fundef heaps prj
		| fundef.fdName == "^"					= setAction (actPower ptr) CTT fundef heaps prj
		| fundef.fdName == "sqrt"				= setAction (actSqrt ptr) CF fundef heaps prj
		| fundef.fdName == "sin"				= setAction (actSin ptr) CF fundef heaps prj
		| fundef.fdName == "<"					= setAction (actSmaller ptr) CTT fundef heaps prj
		| fundef.fdName == "tan"				= setAction (actTan ptr) CF fundef heaps prj
		| fundef.fdName == "*"					= setAction (actTimes ptr) CTT fundef heaps prj
		| fundef.fdName == "toReal"
			# type								= removeStrictness (hd fundef.fdSymbolType.sytArguments)
			| basicType type					= setAction (actToReal ptr type) CF fundef heaps prj
			= (fundef, heaps, prj)
		| fundef.fdName == "zero"				= setAction (actZero ptr CRealNumber) CF fundef heaps prj
		= (fundef, heaps, prj)
	| mod_name == "StdString"
		| fundef.fdName == ":="					= setAction (actAssign ptr) CTT fundef heaps prj
		| fundef.fdName == "+++"				= setAction (actConcat ptr) CTT fundef heaps prj
		| fundef.fdName == "+++."				= setAction (actConcat ptr) CTT fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CTT fundef heaps prj
		| fundef.fdName == "fromString"			= setAction (actFromString ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "%"					= setAction (actSlice ptr) CF fundef heaps prj
		| fundef.fdName == "<"					= setAction (actSmaller ptr) CTT fundef heaps prj
		| fundef.fdName == "toString"
			# type								= removeStrictness (hd fundef.fdSymbolType.sytArguments)
			| basicType type					= setAction (actToString ptr type) CF fundef heaps prj
			= (fundef, heaps, prj)
		= (fundef, heaps, prj)
	= (fundef, heaps, prj)
	where
		setAction :: !([LExpr] -> LExpr) !CFunctionDefinedness !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)
		setAction action definedness fundef heaps prj
			# fundef							= {fundef	& fdIsDeltaRule		= True
															, fdDeltaRule		= action
															, fdCaseVariables	= find_strict_args 0 fundef.fdSymbolType.sytArguments
															, fdDefinedness		= definedness
												  }
			= (fundef, heaps, prj)
		
		basicType :: !CTypeH -> Bool
		basicType (CBasicType _)	= True
		basicType _					= False
		
		removeStrictness :: !CTypeH -> CTypeH
		removeStrictness (CStrict type)		= type
		removeStrictness other				= other
		
		find_strict_args :: !Int ![CTypeH] -> [Int]
		find_strict_args i [CStrict type: types]
			= [i: find_strict_args (i+1) types]
		find_strict_args i [_: types]
			= find_strict_args (i+1) types
		find_strict_args _ []
			= []
















// -------------------------------------------------------------------------------------------------------------------------------------------------
actAbort :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAbort ptr [value]
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAcos :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAcos ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (acos r))
actAcos ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAsin :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAsin ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (asin r))
actAsin ptr _
	= LBottom

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAssign :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAssign ptr [expr, LSymbol _ _ LTotal [LBasicValue (LBasicInteger n), LBasicValue (LBasicCharacter c)]]
	# (ok, text)						= makeString2 expr
	| not ok							= LBottom
	# text								= text := (n, c)
	= LBasicValue (LBasicString text)
actAssign ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAtan :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAtan ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (atan r))
actAtan ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAnd :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAnd ptr [LBasicValue (LBasicBoolean b), expr]
	| b					= expr
	= LBasicValue (LBasicBoolean False)
actAnd ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitAnd :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitAnd ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 bitand n2))
actBitAnd ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitNot :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitNot ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicInteger (bitnot n))
actBitNot ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitOr :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitOr ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 bitor n2))
actBitOr ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitXor :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitXor ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 bitxor n2))
actBitXor ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
//actClearLowercaseBit :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
//actClearLowercaseBit ptr _
//	= (pushError (X_Reduction "clear_lowercase_bit: not implemented yet.") OK, ptr @@# _)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actConcat :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actConcat ptr [expr1, expr2]
	# (ok1, text1)			= makeString2 expr1
	# (ok2, text2)			= makeString2 expr2
	| not (ok1 && ok2)		= LBottom
	= LBasicValue (LBasicString (text1 +++ text2))
actConcat ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actCos :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCos ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (cos r))
actCos ptr _
	= LBottom

// =================================================================================================================================================
// Works for all array-types.
// Optimalization for arrays of evaluated characters.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArray :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArray ptr [LBasicValue (LBasicInteger n), LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicString (createArray n c))
actCreateArray ptr [LBasicValue (LBasicInteger n), expr]
	= LBasicValue (LBasicArray (repeatn n expr))
actCreateArray ptr _
	= LBottom

// =================================================================================================================================================
// Works for all array-types.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArrayU :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArrayU ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicArray (repeatn n LBottom))
actCreateArrayU ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actDiv :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actDiv ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 / n2))
actDiv ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicRealNumber (r1 / r2))
actDiv ptr _
	= LBottom

// =================================================================================================================================================
// Works for booleans, integers, characters, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEqual :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEqual ptr [LBasicValue (LBasicBoolean b1), LBasicValue (LBasicBoolean b2)]
	= LBasicValue (LBasicBoolean (b1 == b2))
actEqual ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicBoolean (n1 == n2))
actEqual ptr [LBasicValue (LBasicCharacter c1), LBasicValue (LBasicCharacter c2)]
	= LBasicValue (LBasicBoolean (c1 == c2))
actEqual ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicBoolean (r1 == r2))
actEqual ptr [expr1, expr2]
	# (ok1, text1)						= makeString2 expr1
	# (ok2, text2)						= makeString2 expr2
	| not (ok1 && ok2)					= LBottom
	= LBasicValue (LBasicBoolean (text1 == text2))
actEqual ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actEntier :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEntier ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicInteger (entier r))
actEntier ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actExp :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actExp ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (exp r))
actExp ptr _
	= LBottom

// =================================================================================================================================================
// Works for bools and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromBool :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromBool ptr (CBasicType CBoolean) [LBasicValue (LBasicBoolean b)]
	= LBasicValue (LBasicBoolean (fromBool b))
actFromBool ptr stringtype [LBasicValue (LBasicBoolean b)]
	= LBasicValue (LBasicString (fromBool b))
actFromBool ptr type _
	= LBottom

// =================================================================================================================================================
// Works for characters, integers and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromChar :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromChar ptr (CBasicType CCharacter) [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicCharacter (fromChar c))
actFromChar ptr (CBasicType CInteger) [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicInteger (fromChar c))
actFromChar ptr stringtype [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicString (fromChar c))
actFromChar ptr type _
	= LBottom

// =================================================================================================================================================
// Works for integers, chars, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromInt :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromInt ptr (CBasicType CInteger) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicInteger (fromInt n))
actFromInt ptr (CBasicType CCharacter) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicCharacter (fromInt n))
actFromInt ptr (CBasicType CRealNumber) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicRealNumber (fromInt n))
actFromInt ptr stringtype [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicString (fromInt n))
actFromInt ptr type _
	= LBottom

// =================================================================================================================================================
// Works for integers, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromReal :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromReal ptr (CBasicType CInteger) [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicInteger (fromReal r))
actFromReal ptr (CBasicType CRealNumber) [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (fromReal r))
actFromReal ptr stringtype [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicString (fromReal r))
actFromReal ptr type _
	= LBottom

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromString :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromString ptr stringtype [expr]
	# (ok, text)					= makeString2 expr
	| not ok						= LBottom
	= LBasicValue (LBasicString (fromString text))
actFromString ptr type _
	= LBottom

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsEven :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsEven ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicBoolean (isEven n))
actIsEven ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsOdd :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsOdd ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicBoolean (isOdd n))
actIsOdd ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actLn :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actLn ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (ln r))
actLn ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actLogTen :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actLogTen ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (log10 r))
actLogTen ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMinus :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMinus ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 - n2))
actMinus ptr [LBasicValue (LBasicCharacter c1), LBasicValue (LBasicCharacter c2)]
	= LBasicValue (LBasicCharacter (c1 - c2))
actMinus ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicRealNumber (r1 - r2))
actMinus ptr _
	= LBottom

/* RWS, no instance mod Int
// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMod :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMod ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 mod n2)))
actMod ptr _
	= (pushError (X_Reduction "Arguments of mod are not well-typed.") OK, ptr @@# _)
*/

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNegative :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNegative ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicInteger (~n))
actNegative ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (~r))
actNegative ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actNot :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNot ptr [LBasicValue (LBasicBoolean b)]
	= LBasicValue (LBasicBoolean (not b))
actNot ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOne :: !HeapPtr !CBasicType ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOne ptr CInteger []
	= LBasicValue (LBasicInteger one)
actOne ptr CCharacter []
	= LBasicValue (LBasicCharacter one)
actOne ptr CRealNumber []
	= LBasicValue (LBasicRealNumber one)
actOne ptr type _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actOr :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOr ptr [LBasicValue (LBasicBoolean b), expr]
	| not b					= expr
	= LBasicValue (LBasicBoolean True)
actOr ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPlus :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPlus ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 + n2))
actPlus ptr [LBasicValue (LBasicCharacter c1), LBasicValue (LBasicCharacter c2)]
	= LBasicValue (LBasicCharacter (c1 + c2))
actPlus ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicRealNumber (r1 + r2))
actPlus ptr _
	= LBottom

// =================================================================================================================================================
// Works for reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPower :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPower ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicRealNumber (r1 ^ r2))
actPower ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actRemainder :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actRemainder ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 rem n2))
actRemainder ptr _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actReplace :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actReplace ptr [LBasicValue (LBasicString text), LBasicValue (LBasicInteger n), LBasicValue (LBasicCharacter new_element)]
	| n >= size text		= LBottom
	# list					= [c \\ c <-: text]
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# text					= {c \\ c <- list}
	# expr					= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
								[ LBasicValue (LBasicCharacter old_element)
								, LBasicValue (LBasicString text)
								]
	= expr
actReplace ptr [LBasicValue (LBasicArray list), LBasicValue (LBasicInteger n), new_element]
	| n >= length list		= LBottom
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# expr					= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
								[ LBasicValue (LBasicCharacter old_element)
								, LBasicValue (LBasicArray list)
								]
	= undef
actReplace ptr _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelect :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelect ptr [LBasicValue (LBasicString text), LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicCharacter text.[n])
actSelect ptr [LBasicValue (LBasicArray list), LBasicValue (LBasicInteger n)]
	= list !! n
actSelect ptr _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelectU :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelectU ptr [LBasicValue (LBasicString text), LBasicValue (LBasicInteger n)]
	= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
		[ LBasicValue (LBasicCharacter text.[n])
		, LBasicValue (LBasicString text)
		]
actSelectU ptr [LBasicValue (LBasicArray list), LBasicValue (LBasicInteger n)]
	= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
		[ list !! n
		, LBasicValue (LBasicArray list)
		]
actSelectU ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
//actSetLowercaseBit :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
//actSetLowercaseBit ptr [LBasicValue (LBasicCharacter c)]
//	= LBasicValue (LBasicCharacter (set_lowercase_bit c)))
//actSetLowercaseBit ptr _
//	= (pushError (X_Reduction "Arguments of set_lowercase_bit are not well-typed.") OK, @@# ptr (Just []) _)
//actSetLowercaseBit ptr _
//	= (pushError (X_Reduction "set_lowercase_bit: not implemented yet.") OK, ptr @@# _)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSlice :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSlice ptr [LBasicValue (LBasicString text), LSymbol (LCons _) _ LTotal [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]]
	= LBasicValue (LBasicString (text%(n1,n2)))
actSlice ptr [LBasicValue (LBasicArray list), LSymbol (LCons _) _ LTotal [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]]
	# (ok, text)							= makeString list
	| not ok								= LBottom
	# text									= text%(n1,n2)
	# list									= [LBasicValue (LBasicCharacter c) \\ c <-: text]
	= LBasicValue (LBasicArray list)
actSlice ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actSqrt :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSqrt ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (sqrt r))
actSqrt ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actSin :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSin ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (sin r))
actSin ptr _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSize :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSize ptr [LBasicValue (LBasicString text)]
	= LBasicValue (LBasicInteger (size text))
actSize ptr [LBasicValue (LBasicArray list)]
	= LBasicValue (LBasicInteger (length list))
actSize ptr _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSizeU :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSizeU ptr [LBasicValue (LBasicString text)]
	= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
		[ LBasicValue (LBasicInteger (size text))
		, LBasicValue (LBasicString text)
		]
actSizeU ptr [LBasicValue (LBasicArray list)]
	= LSymbol (LCons {lciAnnotatedStrictVars=0}) (CBuildTuplePtr 2) LTotal
		[ LBasicValue (LBasicInteger (length list))
		, LBasicValue (LBasicArray list)
		]
actSizeU ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftLeft :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftLeft ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 << n2))
actShiftLeft ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftRight :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftRight ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 >> n2))
actShiftRight ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, characters, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSmaller :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSmaller ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicBoolean (n1 < n2))
actSmaller ptr [LBasicValue (LBasicCharacter c1), LBasicValue (LBasicCharacter c2)]
	= LBasicValue (LBasicBoolean (c1 < c2))
actSmaller ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicBoolean (r1 < r2))
actSmaller ptr [expr1, expr2]
	# (ok1, text1)					= makeString2 expr1
	# (ok2, text2)					= makeString2 expr2
	| not (ok1 && ok2)				= LBottom
	= LBasicValue (LBasicBoolean (text1 < text2))
actSmaller ptr _
	= LBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
actTan :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTan ptr [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (tan r))
actTan ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTimes :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTimes ptr [LBasicValue (LBasicInteger n1), LBasicValue (LBasicInteger n2)]
	= LBasicValue (LBasicInteger (n1 * n2))
actTimes ptr [LBasicValue (LBasicRealNumber r1), LBasicValue (LBasicRealNumber r2)]
	= LBasicValue (LBasicRealNumber (r1 * r2))
actTimes ptr _
	= LBottom

// =================================================================================================================================================
// Works for booleans.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToBool :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToBool ptr [LBasicValue (LBasicBoolean b)]
	= LBasicValue (LBasicBoolean (toBool b))
actToBool ptr _
	= LBottom

// =================================================================================================================================================
// Works for characters and integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToChar :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToChar ptr [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicCharacter (toChar c))
actToChar ptr [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicCharacter (toChar n))
actToChar ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, chars and reals (NOT for strings).
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToInt :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToInt ptr (CBasicType CInteger) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicInteger (toInt n))
actToInt ptr (CBasicType CCharacter) [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicInteger (toInt c))
actToInt ptr (CBasicType CRealNumber) [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicInteger (toInt r))
actToInt ptr type _
	= LBottom

// =================================================================================================================================================
// Works for integers and reals (NOT for strings).
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToReal :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToReal ptr (CBasicType CInteger) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicRealNumber (toReal n))
actToReal ptr (CBasicType CRealNumber) [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicRealNumber (toReal r))
actToReal ptr type _
	= LBottom

// =================================================================================================================================================
// Works for booleans, chars, reals, integers and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToString :: !HeapPtr !CTypeH ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToString ptr (CBasicType CBoolean) [LBasicValue (LBasicBoolean b)]
	= LBasicValue (LBasicString (toString b))
actToString ptr (CBasicType CCharacter) [LBasicValue (LBasicCharacter c)]
	= LBasicValue (LBasicString (toString c))
actToString ptr (CBasicType CInteger) [LBasicValue (LBasicInteger n)]
	= LBasicValue (LBasicString (toString n))
actToString ptr (CBasicType CRealNumber) [LBasicValue (LBasicRealNumber r)]
	= LBasicValue (LBasicString (toString r))
actToString ptr stringtype [expr]
	# (ok, text)						= makeString2 expr
	| not ok							= LBottom
	= LBasicValue (LBasicString (toString text))
actToString ptr type _
	= LBottom

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actUpdate :: !HeapPtr ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actUpdate ptr [LBasicValue (LBasicString text), LBasicValue (LBasicInteger n), LBasicValue (LBasicCharacter new_element)]
	| n >= size text		= LBottom
	# list					= [c \\ c <-: text]
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# text					= {c \\ c <- list}
	= LBasicValue (LBasicString text)
actUpdate ptr [LBasicValue (LBasicArray list), LBasicValue (LBasicInteger n), new_element]
	| n >= length list		= LBottom
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	= LBasicValue (LBasicArray list)
actUpdate ptr _
	= LBottom

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actZero :: !HeapPtr !CBasicType ![LExpr] -> LExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
actZero ptr CInteger []
	= LBasicValue (LBasicInteger zero)
actZero ptr CCharacter []
	= LBasicValue (LBasicCharacter zero)
actZero ptr CRealNumber []
	= LBasicValue (LBasicRealNumber zero)
actZero ptr type _
	= LBottom


















// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString :: ![LExpr] -> (!Bool, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString [LBasicValue (LBasicCharacter c): rest]
	# (ok, text)			= makeString rest
	| not ok				= (False, "")
	= (True, {c} +++ text)
makeString [_: rest]
	= (False, "")
makeString []
	= (True, "")

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString2 :: !LExpr -> (!Bool, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString2 (LBasicValue (LBasicString text))		= (True, text)
makeString2 (LBasicValue (LBasicArray list))		= makeString list
makeString2 _									= (False, "")