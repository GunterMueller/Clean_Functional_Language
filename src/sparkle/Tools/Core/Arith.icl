/*
** Program: Clean Prover System
** Module:  Arith (.icl)
** 
** Author:  Maarten de Mol
** Created: 17 April 2001
*/

implementation module
	Arith

import
	CoreAccess,
	CoreTypes,
	Heaps,
	Print,
	States

// ------------------------------------------------------------------------------------------------------------------------
:: IntTree =
// ------------------------------------------------------------------------------------------------------------------------
	  (<+>)					!IntTree !IntTree
	| (<->)					!IntTree !IntTree
	| (<*>)					!IntTree !IntTree
	| (<%>)					!IntTree !IntTree
	| <~>					!IntTree
	| IINumber				!Int
	| IIExpr				!CExprH

// ------------------------------------------------------------------------------------------------------------------------
:: IntAddition =
// ------------------------------------------------------------------------------------------------------------------------
	  IntAddition			![(Bool, IntMultiplication)]

// ------------------------------------------------------------------------------------------------------------------------
:: IntMultiplication =
// ------------------------------------------------------------------------------------------------------------------------
	  IntMultiplication		![IntBasic]

// ------------------------------------------------------------------------------------------------------------------------
:: IntBasic =
// ------------------------------------------------------------------------------------------------------------------------
	  INumber				!Int
	| IExpr					!CExprH
	| IDivision				!IntAddition !IntAddition

























// ------------------------------------------------------------------------------------------------------------------------
ArithInt :: !CExprH !*CHeaps !*CProject -> (!Error, !(!Bool, !CExprH), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
ArithInt expr heaps prj
	# (abc, prj)									= prj!prjABCFunctions
	#! (error, (ok, expr), heaps, prj)				= intArith expr abc.stdInt heaps prj
	= (error, (ok, expr), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
class intArith a :: !a !IntFunctions !*CHeaps !*CProject -> (!Error, !(!Bool, !a), !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
instance intArith [a] | intArith, DummyValue a
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith [x:xs] funs heaps prj
		# (error, (changed1, x), heaps, prj)		= intArith x funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# (error, (changed2, xs), heaps, prj)		= intArith xs funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
//		| check_list xs
		= (OK, (changed1 || changed2, [x:xs]), heaps, prj)
	intArith [] funs heaps prj
		= (OK, (False, []), heaps, prj)

check_list l
	| isEmpty l
		= True
check_list [_:_]
	= True
check_list _
	= abort "check__list"

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (Maybe a) | intArith a
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith (Just x) funs heaps prj
		# (error, (changed, x), heaps, prj)			= intArith x funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, Just x), heaps, prj)
	intArith Nothing funs heaps prj
		= (OK, (False, Nothing), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (CAlgPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith pattern funs heaps prj
		# (error, (changed, result), heaps, prj)	= intArith pattern.atpResult funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# pattern									= {pattern & atpResult = result}
		= (OK, (changed, pattern), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (CBasicPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith pattern funs heaps prj
		# (error, (changed, result), heaps, prj)	= intArith pattern.bapResult funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# pattern									= {pattern & bapResult = result}
		= (OK, (changed, pattern), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (CBasicValue HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith (CBasicArray exprs) funs heaps prj
		# (error, (changed, exprs), heaps, prj)		= intArith exprs funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, CBasicArray exprs), heaps, prj)
	intArith other funs heaps prj
		= (OK, (False, other), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (CCasePatterns HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith (CAlgPatterns type patterns) funs heaps prj
		# (error, (changed, patterns), heaps, prj)	= intArith patterns funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, CAlgPatterns type patterns), heaps, prj)
	intArith (CBasicPatterns type patterns) funs heaps prj
		# (error, (changed, patterns), heaps, prj)	= intArith patterns funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, CBasicPatterns type patterns), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
instance intArith (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------
where
	intArith (CExprVar ptr) funs heaps prj
		= (OK, (False, CExprVar ptr), heaps, prj)
	intArith (expr @# exprs) funs heaps prj
		# (error, (changed1, expr), heaps, prj)		= intArith expr funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# (error, (changed2, exprs), heaps, prj)	= intArith exprs funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed1 || changed2, expr @# exprs), heaps, prj)
	intArith expr=:(ptr @@# exprs) funs heaps prj
		# is_arith_fun								= isMember ptr [funs.intAdd, funs.intSubtract, funs.intMultiply, funs.intDivide, funs.intNegate, funs.intZero, funs.intOne]
		| not is_arith_fun
			# (is_dict_create, prj)					= creates_dict ptr prj
			| is_dict_create						= (OK, (False, ptr @@# exprs), heaps, prj)
			# (error, (changed, exprs), heaps, prj)	= intArith exprs funs heaps prj
			| isError error							= (error, DummyValue, heaps, prj)
			= (OK, (changed, ptr @@# exprs), heaps, prj)
		# (int_tree, heaps, prj)					= buildIntTree expr funs heaps prj
		# int_addition								= buildIntAddition int_tree
		# (_, int_addition)							= computeConstants int_addition
		# new_expr									= buildExpr int_addition funs
		| expr <> new_expr							= (OK, (True, new_expr), heaps, prj)
		# (error, (changed, exprs), heaps, prj)		= intArith exprs funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, ptr @@# exprs), heaps, prj)
		where
			creates_dict :: !HeapPtr !*CProject -> (!Bool, !*CProject)
			creates_dict ptr prj
				# (error, consdef, prj)				= getDataConsDef ptr prj
				| isError error						= (False, prj)
				# (error, recdef, prj)				= getRecordTypeDef consdef.dcdAlgType prj
				| isError error						= (False, prj)
				= (recdef.rtdIsDictionary, prj)
	intArith (CLet strict lets expr) funs heaps prj
		# (vars, exprs)								= unzip lets
		# (error, (changed1, exprs), heaps, prj)	= intArith exprs funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# lets										= zip2 vars exprs
		# (error, (changed2, expr), heaps, prj)		= intArith expr funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed1 || changed2, CLet strict lets expr), heaps, prj)
	intArith (CCase expr patterns def) funs heaps prj
		# (error, (changed1, expr), heaps, prj)		= intArith expr funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# (error, (changed2, patterns), heaps, prj)	= intArith patterns funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		# (error, (chanegd3, def), heaps, prj)		= intArith def funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed1 || changed2 || changed2, CCase expr patterns def), heaps, prj)
	intArith (CBasicValue value) funs heaps prj
		# (error, (changed, value), heaps, prj)		= intArith value funs heaps prj
		| isError error								= (error, DummyValue, heaps, prj)
		= (OK, (changed, CBasicValue value), heaps, prj)
	intArith (CCode codetype codecontents) funs heaps prj
		= (OK, (False, CCode codetype codecontents), heaps, prj)
	intArith CBottom funs heaps prj
		= (OK, (False, CBottom), heaps, prj)























// ------------------------------------------------------------------------------------------------------------------------
buildIntTree :: !CExprH !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildIntTree expr=:(ptr @@# exprs) funs heaps prj
	| ptr == funs.intAdd							= buildAdd ptr exprs funs heaps prj
	| ptr == funs.intSubtract						= buildSubtract ptr exprs funs heaps prj
	| ptr == funs.intMultiply						= buildMultiply ptr exprs funs heaps prj
	| ptr == funs.intDivide							= buildDivide ptr exprs funs heaps prj
	| ptr == funs.intNegate							= buildNegate ptr exprs funs heaps prj
	| ptr == funs.intZero							= (IINumber 0, heaps, prj)
	| ptr == funs.intOne							= (IINumber 1, heaps, prj)
	= (IIExpr expr, heaps, prj)
buildIntTree (CBasicValue (CBasicInteger n)) funs heaps prj
	= (IINumber n, heaps, prj)
buildIntTree other funs heaps prj
	= (IIExpr other, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
buildAdd :: !HeapPtr ![CExprH] !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildAdd ptr [e1,e2] funs heaps prj
	# (t1, heaps, prj)								= buildIntTree e1 funs heaps prj
	# (t2, heaps, prj)								= buildIntTree e2 funs heaps prj
	= (t1 <+> t2, heaps, prj)
buildAdd ptr exprs funs heaps prj
	= (IIExpr (ptr @@# exprs), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
buildDivide :: !HeapPtr ![CExprH] !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildDivide ptr [e1,e2] funs heaps prj
	# (t1, heaps, prj)								= buildIntTree e1 funs heaps prj
	# (t2, heaps, prj)								= buildIntTree e2 funs heaps prj
	= (t1 <%> t2, heaps, prj)
buildDivide ptr exprs funs heaps prj
	= (IIExpr (ptr @@# exprs), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
buildMultiply :: !HeapPtr ![CExprH] !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildMultiply ptr [e1,e2] funs heaps prj
	# (t1, heaps, prj)								= buildIntTree e1 funs heaps prj
	# (t2, heaps, prj)								= buildIntTree e2 funs heaps prj
	= (t1 <*> t2, heaps, prj)
buildMultiply ptr exprs funs heaps prj
	= (IIExpr (ptr @@# exprs), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
buildNegate :: !HeapPtr ![CExprH] !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildNegate ptr [e] funs heaps prj
	# (t, heaps, prj)								= buildIntTree e funs heaps prj
	= (<~> t, heaps, prj)
buildNegate ptr exprs funs heaps prj
	= (IIExpr (ptr @@# exprs), heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
buildSubtract :: !HeapPtr ![CExprH] !IntFunctions !*CHeaps !*CProject -> (!IntTree, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
buildSubtract ptr [e1,e2] funs heaps prj
	# (t1, heaps, prj)								= buildIntTree e1 funs heaps prj
	# (t2, heaps, prj)								= buildIntTree e2 funs heaps prj
	= (t1 <-> t2, heaps, prj)
buildSubtract ptr exprs funs heaps prj
	= (IIExpr (ptr @@# exprs), heaps, prj)























// ------------------------------------------------------------------------------------------------------------------------
buildIntAddition :: !IntTree -> IntAddition
// ------------------------------------------------------------------------------------------------------------------------
buildIntAddition (t1 <+> t2)
	= add (buildIntAddition t1) (buildIntAddition t2)
	where
		add :: !IntAddition !IntAddition -> IntAddition
		add (IntAddition terms1) (IntAddition terms2)
			= IntAddition (terms1 ++ terms2)
buildIntAddition (t1 <-> t2)
	= subtract (buildIntAddition t1) (buildIntAddition t2)
	where
		subtract :: !IntAddition !IntAddition -> IntAddition
		subtract (IntAddition terms1) (IntAddition terms2)
			= IntAddition (terms1 ++ map negate_term terms2)
		
		negate_term :: !(!Bool, !IntMultiplication) -> (!Bool, !IntMultiplication)
		negate_term (sign, multiplication)
			= (not sign, multiplication)
buildIntAddition (t1 <*> t2)
	= multiply (buildIntAddition t1) (buildIntAddition t2)
	where
		multiply :: !IntAddition !IntAddition -> IntAddition
		multiply (IntAddition terms1) (IntAddition terms2)
			= IntAddition [multiply_term t1 t2 \\ t1 <- terms1, t2 <- terms2]
		
		multiply_term :: !(!Bool, !IntMultiplication) !(!Bool, !IntMultiplication) -> (!Bool, !IntMultiplication)
		multiply_term (sign1, IntMultiplication terms1) (sign2, IntMultiplication terms2)
			# sign									= (sign1 && sign2) || (not sign1 && not sign2)
			= (sign, IntMultiplication (terms1 ++ terms2))
buildIntAddition (t1 <%> t2)
	= divide (buildIntAddition t1) (buildIntAddition t2)
	where
		divide :: !IntAddition !IntAddition -> IntAddition
		divide add1 add2
			= IntAddition [(True, IntMultiplication [IDivision add1 add2])]
buildIntAddition (<~> t)
	= negate (buildIntAddition t)
	where
		negate :: !IntAddition -> IntAddition
		negate (IntAddition terms)
			= IntAddition (map negate_term terms)
		
		negate_term :: !(!Bool, !IntMultiplication) -> (!Bool, !IntMultiplication)
		negate_term (sign, multiplication)
			= (not sign, multiplication)
buildIntAddition (IINumber n)
	= IntAddition [(True, IntMultiplication [INumber n])]
buildIntAddition (IIExpr expr)
	= IntAddition [(True, IntMultiplication [IExpr expr])]
























// ------------------------------------------------------------------------------------------------------------------------
class computeConstants a :: !a -> (!Maybe Int, !a)
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
instance computeConstants IntAddition
// ------------------------------------------------------------------------------------------------------------------------
where
	computeConstants (IntAddition terms)
		# (constant, terms)							= find_constant 0 terms
		| isEmpty terms								= (Just constant, IntAddition [(True, IntMultiplication [INumber constant])])
		| constant < 0								= (Nothing, IntAddition (add_constant False (~constant) terms))
		| constant == 0								= (Nothing, IntAddition terms)
		| constant > 0								= (Nothing, IntAddition (add_constant True constant terms))
		where
			find_constant :: !Int ![(Bool, IntMultiplication)] -> (!Int, ![(Bool, IntMultiplication)])
			find_constant constant [(sign, mult): terms]
				# (mb_num, mult)					= computeConstants mult
				| isNothing mb_num
					# (constant, terms)				= find_constant constant terms
					= (constant, [(sign, mult): terms])
				# constant							= case sign of
														True	-> constant + fromJust mb_num
														False	-> constant - fromJust mb_num
				= find_constant constant terms
			find_constant constant []
				= (constant, [])
			
			add_constant :: !Bool !Int ![(Bool, IntMultiplication)] -> [(Bool, IntMultiplication)]
			add_constant True constant terms
				= terms ++ [(True, IntMultiplication [INumber constant])]
			add_constant False constant terms
				= terms ++ [(False, IntMultiplication [INumber constant])]

// ------------------------------------------------------------------------------------------------------------------------
instance computeConstants IntMultiplication
// ------------------------------------------------------------------------------------------------------------------------
where
	computeConstants (IntMultiplication terms)
		# (constant, terms)							= find_constant 1 terms
		| isEmpty terms								= (Just constant, IntMultiplication [INumber constant])
		| constant == 1								= (Nothing, IntMultiplication terms)
		= (Nothing, IntMultiplication [INumber constant: terms])
		where
			find_constant :: !Int ![IntBasic] -> (!Int, ![IntBasic])
			find_constant constant [term: terms]
				# (mb_num, term)					= computeConstants term
				| isNothing mb_num
					# (constant, terms)				= find_constant constant terms
					= (constant, [term: terms])
				# constant							= constant * fromJust mb_num
				= find_constant constant terms
			find_constant constant []
				= (constant, [])

// ------------------------------------------------------------------------------------------------------------------------
instance computeConstants IntBasic
// ------------------------------------------------------------------------------------------------------------------------
where
	computeConstants (INumber n)
		= (Just n, INumber n)
	computeConstants (IExpr expr)
		= (Nothing, IExpr expr)
	computeConstants (IDivision add1 add2)
		# (mb_num1, add1)							= computeConstants add1
		# (mb_num2, add2)							= computeConstants add2
		| isNothing mb_num1 || isNothing mb_num2	= (Nothing, IDivision add1 add2)
		# num1										= fromJust mb_num1
		# num2										= fromJust mb_num2
		# num										= num1 / num2
		= (Just num, INumber num)























// ------------------------------------------------------------------------------------------------------------------------
class buildExpr a :: !a !IntFunctions -> CExprH
// ------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------
instance buildExpr IntAddition
// ------------------------------------------------------------------------------------------------------------------------
where
	buildExpr (IntAddition [(sign,term): terms]) funs
		# expr										= buildExpr term funs
		# expr										= case sign of
														True	-> expr
														False	-> funs.intNegate @@# [expr]
		= expand expr terms
		where
			expand :: !CExprH ![(Bool, IntMultiplication)] -> CExprH
			expand e1 [(sign, term): terms]
				# e2								= buildExpr term funs
				# expr								= case sign of
														True	-> funs.intAdd @@# [e1, e2]
														False	-> funs.intSubtract @@# [e1, e2]
				= expand expr terms
			expand expr []
				= expr

// ------------------------------------------------------------------------------------------------------------------------
instance buildExpr IntMultiplication
// ------------------------------------------------------------------------------------------------------------------------
where
	buildExpr (IntMultiplication [term: terms]) funs
		# expr										= buildExpr term funs
		= expand expr terms
		where
			expand :: !CExprH ![IntBasic] -> CExprH
			expand e1 [term: terms]
				# e2								= buildExpr term funs
				# expr								= funs.intMultiply @@# [e1, e2]
				= expand expr terms
			expand expr []
				= expr

// ------------------------------------------------------------------------------------------------------------------------
instance buildExpr IntBasic
// ------------------------------------------------------------------------------------------------------------------------
where
	buildExpr (INumber n) funs
		= CBasicValue (CBasicInteger n)
	buildExpr (IExpr expr) funs
		= expr
	buildExpr (IDivision add1 add2) funs
		# e1										= buildExpr add1 funs
		# e2										= buildExpr add2 funs
		= funs.intDivide @@# [e1, e2]