/*
** Program: Clean Prover System
** Module:  DeltaRules (.icl)
** 
** Author:  Maarten de Mol
** Created: 28 August 2000
**
** Notes(1): In some cases, there is only one function for a class.
**           For ==, for example, always the function 'Equal' is used. 
**           It works for all basic types.
** Notes(2): Although the type 'String' does not exist, an internal
**           optimized representation of strings DOES. All functions
**           on arrays must be able to deal with this representation.
*/

implementation module 
	DeltaRules

import
	StdEnv,
	CoreTypes,
	CoreAccess,
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
		| fundef.fdName == "createArray"		= setAction (actCreateArray ptr) CF fundef heaps prj
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
		| fundef.fdName == "clear_lowercase_bit"= setAction (actClearLowercaseBit ptr) CT fundef heaps prj
		| fundef.fdName == "=="					= setAction (actEqual ptr) CF fundef heaps prj
		| fundef.fdName == "fromChar"			= setAction (actFromChar ptr fundef.fdSymbolType.sytResult) CF fundef heaps prj
		| fundef.fdName == "-"					= setAction (actMinus ptr) CTT fundef heaps prj
		| fundef.fdName == "one"				= setAction (actOne ptr CCharacter) CF fundef heaps prj
		| fundef.fdName == "+"					= setAction (actPlus ptr) CTT fundef heaps prj
		| fundef.fdName == "set_lowercase_bit"	= setAction (actSetLowercaseBit ptr) CT fundef heaps prj
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
		setAction :: !([CExprH] -> (Error, CExprH)) !CFunctionDefinedness !CFunDefH !*CHeaps !*CProject -> (!CFunDefH, !*CHeaps, !*CProject)
		setAction action definedness fundef heaps prj
			# fundef							= {fundef	& fdDeltaRule		= Just action
															, fdCaseVariables	= find_strict_args 0 fundef.fdSymbolType.sytArguments
															, fdDefinedness		= definedness
												  }
			= (fundef, heaps, prj)
		
		basicType :: !CTypeH -> Bool
		basicType (CBasicType _)	= True
		basicType other				= False
		
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
actAbort :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAbort ptr [value]
	= (OK, CBottom)
actAbort ptr other
	= (pushError (X_Reduction "Arguments of abort are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAcos :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAcos ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (acos r)))
actAcos ptr other
	= (pushError (X_Reduction "Arguments of acos are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAsin :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAsin ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (asin r)))
actAsin ptr other
	= (pushError (X_Reduction "Arguments of asin are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAssign :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAssign ptr other=:[expr, buildtuple @@# [CBasicValue (CBasicInteger n), CBasicValue (CBasicCharacter c)]]
	| buildtuple <> (CBuildTuplePtr 2)	= (pushError (X_Reduction "Arguments of := are not well-typed.") OK, ptr @@# other)
	# (ok, text)						= makeString2 expr
	| not ok							= (pushError (X_Reduction "Arguments of asin are not well-typed.") OK, ptr @@# other)
	# text								= text := (n, c)
	= (OK, CBasicValue (CBasicString text))
actAssign ptr other
	= (pushError (X_Reduction "Arguments of asin are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAtan :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAtan ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (atan r)))
actAtan ptr other
	= (pushError (X_Reduction "Arguments of atan are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actAnd :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actAnd ptr [CBasicValue (CBasicBoolean b), expr]
	| b					= (OK, expr)
	= (OK, CBasicValue (CBasicBoolean False))
actAnd ptr other
	= (pushError (X_Reduction "Arguments of && are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitAnd :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitAnd ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 bitand n2)))
actBitAnd ptr other
	= (pushError (X_Reduction "Arguments of bitand are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitNot :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitNot ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicInteger (bitnot n)))
actBitNot ptr other
	= (pushError (X_Reduction "Arguments of bitnot are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitOr :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitOr ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 bitor n2)))
actBitOr ptr other
	= (pushError (X_Reduction "Arguments of bitor are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitXor :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actBitXor ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 bitxor n2)))
actBitXor ptr other
	= (pushError (X_Reduction "Arguments of bitxor are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actClearLowercaseBit :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actClearLowercaseBit ptr other
	= (pushError (X_Reduction "clear_lowercase_bit: not implemented yet.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actConcat :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actConcat ptr other=:[expr1, expr2]
	# (ok1, text1)			= makeString2 expr1
	# (ok2, text2)			= makeString2 expr2
	| not (ok1 && ok2)		= (pushError (X_Reduction "Arguments of +++ are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicString (text1 +++ text2)))
actConcat ptr other
	= (pushError (X_Reduction "Arguments of +++ are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actCos :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCos ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (cos r)))
actCos ptr other
	= (pushError (X_Reduction "Arguments of cos are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all array-types.
// Optimalization for arrays of evaluated characters.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArray :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArray ptr [CBasicValue (CBasicInteger n), CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicString (createArray n c)))
actCreateArray ptr [CBasicValue (CBasicInteger n), expr]
	= (OK, CBasicValue (CBasicArray (repeatn n expr)))
actCreateArray ptr other
	= (pushError (X_Reduction "Arguments of createArray are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all array-types.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArrayU :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actCreateArrayU ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicArray (repeatn n CBottom)))
actCreateArrayU ptr other
	= (pushError (X_Reduction "Arguments of _createArray are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actDiv :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actDiv ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 / n2)))
actDiv ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicRealNumber (r1 / r2)))
actDiv ptr other
	= (pushError (X_Reduction "Arguments of / are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for booleans, integers, characters, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEqual :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEqual ptr [CBasicValue (CBasicBoolean b1), CBasicValue (CBasicBoolean b2)]
	= (OK, CBasicValue (CBasicBoolean (b1 == b2)))
actEqual ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicBoolean (n1 == n2)))
actEqual ptr [CBasicValue (CBasicCharacter c1), CBasicValue (CBasicCharacter c2)]
	= (OK, CBasicValue (CBasicBoolean (c1 == c2)))
actEqual ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicBoolean (r1 == r2)))
actEqual ptr other=:[expr1, expr2]
	# (ok1, text1)						= makeString2 expr1
	# (ok2, text2)						= makeString2 expr2
	| not (ok1 && ok2)					= (pushError (X_Reduction "Arguments of == are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicBoolean (text1 == text2)))
actEqual ptr other
	= (pushError (X_Reduction "Arguments of == are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actEntier :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actEntier ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicInteger (entier r)))
actEntier ptr other
	= (pushError (X_Reduction "Arguments of entier are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actExp :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actExp ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (exp r)))
actExp ptr other
	= (pushError (X_Reduction "Arguments of exp are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for bools and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromBool :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromBool ptr (CBasicType CBoolean) [CBasicValue (CBasicBoolean b)]
	= (OK, CBasicValue (CBasicBoolean (fromBool b)))
actFromBool ptr stringtype [CBasicValue (CBasicBoolean b)]
	= (OK, CBasicValue (CBasicString (fromBool b)))
actFromBool ptr type other
	= (pushError (X_Reduction "Arguments of fromBool are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for characters, integers and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromChar :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromChar ptr (CBasicType CCharacter) [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicCharacter (fromChar c)))
actFromChar ptr (CBasicType CInteger) [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicInteger (fromChar c)))
actFromChar ptr stringtype [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicString (fromChar c)))
actFromChar ptr type other
	= (pushError (X_Reduction "Arguments of fromChar are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, chars, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromInt :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromInt ptr (CBasicType CInteger) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicInteger (fromInt n)))
actFromInt ptr (CBasicType CCharacter) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicCharacter (fromInt n)))
actFromInt ptr (CBasicType CRealNumber) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicRealNumber (fromInt n)))
actFromInt ptr stringtype [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicString (fromInt n)))
actFromInt ptr type other
	= (pushError (X_Reduction "Arguments of fromInt are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromReal :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromReal ptr (CBasicType CInteger) [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicInteger (fromReal r)))
actFromReal ptr (CBasicType CRealNumber) [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (fromReal r)))
actFromReal ptr stringtype [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicString (fromReal r)))
actFromReal ptr type other
	= (pushError (X_Reduction "Arguments of fromReal are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromString :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actFromString ptr stringtype other=:[expr]
	# (ok, text)					= makeString2 expr
	| not ok						= (pushError (X_Reduction "Arguments of fromBool are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicString (fromString text)))
actFromString ptr type other
	= (pushError (X_Reduction "Arguments of fromString are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsEven :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsEven ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicBoolean (isEven n)))
actIsEven ptr other
	= (pushError (X_Reduction "Arguments of isEven are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsOdd :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actIsOdd ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicBoolean (isOdd n)))
actIsOdd ptr other
	= (pushError (X_Reduction "Arguments of isOdd are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actLn :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actLn ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (ln r)))
actLn ptr other
	= (pushError (X_Reduction "Arguments of ln are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actLogTen :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actLogTen ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (log10 r)))
actLogTen ptr other
	= (pushError (X_Reduction "Arguments of log10 are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMinus :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMinus ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 - n2)))
actMinus ptr [CBasicValue (CBasicCharacter c1), CBasicValue (CBasicCharacter c2)]
	= (OK, CBasicValue (CBasicCharacter (c1 - c2)))
actMinus ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicRealNumber (r1 - r2)))
actMinus ptr other
	= (pushError (X_Reduction "Arguments of - are not well-typed.") OK, ptr @@# other)

/* RWS, no instance mod Int
// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMod :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actMod ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 mod n2)))
actMod ptr other
	= (pushError (X_Reduction "Arguments of mod are not well-typed.") OK, ptr @@# other)
*/

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNegative :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNegative ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicInteger (~n)))
actNegative ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (~r)))
actNegative ptr other
	= (pushError (X_Reduction "Arguments of ~ are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actNot :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actNot ptr [CBasicValue (CBasicBoolean b)]
	= (OK, CBasicValue (CBasicBoolean (not b)))
actNot ptr other
	= (pushError (X_Reduction "Arguments of not are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOne :: !HeapPtr !CBasicType ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOne ptr CInteger []
	= (OK, CBasicValue (CBasicInteger one))
actOne ptr CCharacter []
	= (OK, CBasicValue (CBasicCharacter one))
actOne ptr CRealNumber []
	= (OK, CBasicValue (CBasicRealNumber one))
actOne ptr type other
	= (pushError (X_Reduction "Arguments of one are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actOr :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actOr ptr [CBasicValue (CBasicBoolean b), expr]
	| not b					= (OK, expr)
	= (OK, CBasicValue (CBasicBoolean True))
actOr ptr other
	= (pushError (X_Reduction "Arguments of || are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPlus :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPlus ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 + n2)))
actPlus ptr [CBasicValue (CBasicCharacter c1), CBasicValue (CBasicCharacter c2)]
	= (OK, CBasicValue (CBasicCharacter (c1 + c2)))
actPlus ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicRealNumber (r1 + r2)))
actPlus ptr other
	= (pushError (X_Reduction "Arguments of + are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPower :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actPower ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicRealNumber (r1 ^ r2)))
actPower ptr other
	= (pushError (X_Reduction "Arguments of ^ are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actRemainder :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actRemainder ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 rem n2)))
actRemainder ptr other
	= (pushError (X_Reduction "Arguments of rem are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actReplace :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actReplace ptr [CBasicValue (CBasicString text), CBasicValue (CBasicInteger n), CBasicValue (CBasicCharacter new_element)]
	| n >= size text		= (OK, CBottom)
	# list					= [c \\ c <-: text]
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# text					= {c \\ c <- list}
	# expr					= (CBuildTuplePtr 2) @@#	[CBasicValue (CBasicCharacter old_element),
														 CBasicValue (CBasicString text)]
	= (OK, expr)
actReplace ptr [CBasicValue (CBasicArray list), CBasicValue (CBasicInteger n), new_element]
	| n >= length list		= (OK, CBottom)
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# expr					= (CBuildTuplePtr 2) @@#	[old_element,
														 CBasicValue (CBasicArray list)]
	= (OK, expr)
actReplace ptr other
	= (pushError (X_Reduction "Arguments of replace are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelect :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelect ptr [CBasicValue (CBasicString text), CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicCharacter text.[n]))
actSelect ptr [CBasicValue (CBasicArray list), CBasicValue (CBasicInteger n)]
	= (OK, list !! n)
actSelect ptr other
	= (pushError (X_Reduction "Arguments of select are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelectU :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSelectU ptr [CBasicValue (CBasicString text), CBasicValue (CBasicInteger n)]
	= (OK, (CBuildTuplePtr 2) @@#	[CBasicValue (CBasicCharacter text.[n]),
									 CBasicValue (CBasicString text)])
actSelectU ptr [CBasicValue (CBasicArray list), CBasicValue (CBasicInteger n)]
	= (OK, (CBuildTuplePtr 2) @@#	[list !! n,
									 CBasicValue (CBasicArray list)])
actSelectU ptr other
	= (pushError (X_Reduction "Arguments of uselect are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actSetLowercaseBit :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
//actSetLowercaseBit ptr [CBasicValue (CBasicCharacter c)]
//	= (OK, CBasicValue (CBasicCharacter (set_lowercase_bit c)))
//actSetLowercaseBit ptr other
//	= (pushError (X_Reduction "Arguments of set_lowercase_bit are not well-typed.") OK, @@# ptr (Just []) other)
actSetLowercaseBit ptr other
	= (pushError (X_Reduction "set_lowercase_bit: not implemented yet.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSlice :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSlice ptr other=:[CBasicValue (CBasicString text), buildtuple @@# [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]]
	| buildtuple <> (CBuildTuplePtr 2)		= (pushError (X_Reduction "Arguments of slice are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicString (text%(n1,n2))))
actSlice ptr other=:[CBasicValue (CBasicArray list), buildtuple @@# [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]]
	| buildtuple <> (CBuildTuplePtr 2)		= (pushError (X_Reduction "Arguments of slice are not well-typed.") OK, ptr @@# other)
	# (ok, text)							= makeString list
	| not ok								= (pushError (X_Reduction "Arguments of slice are not well-typed.") OK, ptr @@# other)
	# text									= text%(n1,n2)
	# list									= [CBasicValue (CBasicCharacter c) \\ c <-: text]
	= (OK, CBasicValue (CBasicArray list))
actSlice ptr other
	= (pushError (X_Reduction "Arguments of slice are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actSqrt :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSqrt ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (sqrt r)))
actSqrt ptr other
	= (pushError (X_Reduction "Arguments of sqrt are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actSin :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSin ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (sin r)))
actSin ptr other
	= (pushError (X_Reduction "Arguments of sin are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSize :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSize ptr [CBasicValue (CBasicString text)]
	= (OK, CBasicValue (CBasicInteger (size text)))
actSize ptr [CBasicValue (CBasicArray list)]
	= (OK, CBasicValue (CBasicInteger (length list)))
actSize ptr other
	= (pushError (X_Reduction "Arguments of size are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSizeU :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSizeU ptr [CBasicValue (CBasicString text)]
	= (OK, (CBuildTuplePtr 2) @@#	[CBasicValue (CBasicInteger (size text)),
									 CBasicValue (CBasicString text)])
actSizeU ptr [CBasicValue (CBasicArray list)]
	= (OK, (CBuildTuplePtr 2) @@#	[CBasicValue (CBasicInteger (length list)),
									 CBasicValue (CBasicArray list)])
actSizeU ptr other
	= (pushError (X_Reduction "Arguments of usize are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftLeft :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftLeft ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 << n2)))
actShiftLeft ptr other
	= (pushError (X_Reduction "Arguments of << are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftRight :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actShiftRight ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 >> n2)))
actShiftRight ptr other
	= (pushError (X_Reduction "Arguments of >> are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, characters, reals and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSmaller :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actSmaller ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicBoolean (n1 < n2)))
actSmaller ptr [CBasicValue (CBasicCharacter c1), CBasicValue (CBasicCharacter c2)]
	= (OK, CBasicValue (CBasicBoolean (c1 < c2)))
actSmaller ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicBoolean (r1 < r2)))
actSmaller ptr other=:[expr1, expr2]
	# (ok1, text1)					= makeString2 expr1
	# (ok2, text2)					= makeString2 expr2
	| not (ok1 && ok2)				= (pushError (X_Reduction "Arguments of < are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicBoolean (text1 < text2)))
actSmaller ptr other
	= (pushError (X_Reduction "Arguments of < are not well-typed.") OK, ptr @@# other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
actTan :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTan ptr [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (tan r)))
actTan ptr other
	= (pushError (X_Reduction "Arguments of tan are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTimes :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actTimes ptr [CBasicValue (CBasicInteger n1), CBasicValue (CBasicInteger n2)]
	= (OK, CBasicValue (CBasicInteger (n1 * n2)))
actTimes ptr [CBasicValue (CBasicRealNumber r1), CBasicValue (CBasicRealNumber r2)]
	= (OK, CBasicValue (CBasicRealNumber (r1 * r2)))
actTimes ptr other
	= (pushError (X_Reduction "Arguments of * are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for booleans.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToBool :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToBool ptr [CBasicValue (CBasicBoolean b)]
	= (OK, CBasicValue (CBasicBoolean (toBool b)))
actToBool ptr other
	= (pushError (X_Reduction "Arguments of toBool are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for characters and integers.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToChar :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToChar ptr [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicCharacter (toChar c)))
actToChar ptr [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicCharacter (toChar n)))
actToChar ptr other
	= (pushError (X_Reduction "Arguments of toChar are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, chars and reals (NOT for strings).
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToInt :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToInt ptr (CBasicType CInteger) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicInteger (toInt n)))
actToInt ptr (CBasicType CCharacter) [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicInteger (toInt c)))
actToInt ptr (CBasicType CRealNumber) [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicInteger (toInt r)))
actToInt ptr type other
	= (pushError (X_Reduction "Arguments of toInt are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers and reals (NOT for strings).
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToReal :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToReal ptr (CBasicType CInteger) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicRealNumber (toReal n)))
actToReal ptr (CBasicType CRealNumber) [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicRealNumber (toReal r)))
actToReal ptr type other
	= (pushError (X_Reduction "Arguments of toReal are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for booleans, chars, reals, integers and strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToString :: !HeapPtr !CTypeH ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actToString ptr (CBasicType CBoolean) [CBasicValue (CBasicBoolean b)]
	= (OK, CBasicValue (CBasicString (toString b)))
actToString ptr (CBasicType CCharacter) [CBasicValue (CBasicCharacter c)]
	= (OK, CBasicValue (CBasicString (toString c)))
actToString ptr (CBasicType CInteger) [CBasicValue (CBasicInteger n)]
	= (OK, CBasicValue (CBasicString (toString n)))
actToString ptr (CBasicType CRealNumber) [CBasicValue (CBasicRealNumber r)]
	= (OK, CBasicValue (CBasicString (toString r)))
actToString ptr stringtype other=:[expr]
	# (ok, text)						= makeString2 expr
	| not ok							= (pushError (X_Reduction "Arguments of toString are not well-typed.") OK, ptr @@# other)
	= (OK, CBasicValue (CBasicString (toString text)))
actToString ptr type other
	= (pushError (X_Reduction "Arguments of toString are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for all arrays and for strings.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actUpdate :: !HeapPtr ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actUpdate ptr [CBasicValue (CBasicString text), CBasicValue (CBasicInteger n), CBasicValue (CBasicCharacter new_element)]
	| n >= size text		= (OK, CBottom)
	# list					= [c \\ c <-: text]
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	# text					= {c \\ c <- list}
	= (OK, CBasicValue (CBasicString text))
actUpdate ptr [CBasicValue (CBasicArray list), CBasicValue (CBasicInteger n), new_element]
	| n >= length list		= (OK, CBottom)
	# old_element			= list !! n
	# list					= (take n list) ++ [new_element] ++ (drop (n+1) list)
	= (OK, CBasicValue (CBasicArray list))
actUpdate ptr other
	= (pushError (X_Reduction "Arguments of update are not well-typed.") OK, ptr @@# other)

// =================================================================================================================================================
// Works for integers, characters and reals.
// -------------------------------------------------------------------------------------------------------------------------------------------------
actZero :: !HeapPtr !CBasicType ![CExprH] -> (!Error, !CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
actZero ptr CInteger []
	= (OK, CBasicValue (CBasicInteger zero))
actZero ptr CCharacter []
	= (OK, CBasicValue (CBasicCharacter zero))
actZero ptr CRealNumber []
	= (OK, CBasicValue (CBasicRealNumber zero))
actZero ptr type other
	= (pushError (X_Reduction "Arguments of zero are not well-typed.") OK, ptr @@# other)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString :: ![CExprH] -> (!Bool, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString [CBasicValue (CBasicCharacter c): rest]
	# (ok, text)			= makeString rest
	| not ok				= (False, "")
	= (True, {c} +++ text)
makeString [other: rest]
	= (False, "")
makeString []
	= (True, "")

// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString2 :: !CExprH -> (!Bool, !String)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeString2 (CBasicValue (CBasicString text))		= (True, text)
makeString2 (CBasicValue (CBasicArray list))		= makeString list
makeString2 other									= (False, "")
