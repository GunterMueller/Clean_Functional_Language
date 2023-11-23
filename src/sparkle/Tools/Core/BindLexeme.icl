/*
** Program: Clean Prover System
** Module:  BindLexeme (.icl)
** 
** Author:  Maarten de Mol
** Created: 12 September 2000
**
** COMMENT: (29-01-2001) Removed the second call to dummyDicts (in solveTypes + solveOverloading),
**                       because it behaved incorrectly when number of arguments <> arity.
**                       Also changed dummyDicts itself; it doesn't drop arguments anymore.
**                       See tags HOPE/EPOH
*/

implementation module 
	BindLexeme

import
	StdEnv,
	StdMaybe,
	Errors,
	Parser,
	Predefined,
	CoreTypes,
	ProveTypes,
	CoreAccess,
	Heaps,
	States,
	GiveType,
	Operate
	, RWSDebug, Print

// -------------------------------------------------------------------------------------------------------------------------------------------------
class getHeapPtr a :: !a -> (!Bool, !HeapPtr)
instance getHeapPtr HeapPtr
	where getHeapPtr ptr = (True, ptr)
instance getHeapPtr ParsedPtr
	where	getHeapPtr (PHeapPtr ptr)	= (True, ptr)
			getHeapPtr (PInfixPtr ptr)	= (True, ptr)
			getHeapPtr other			= (False, DummyValue)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeAnyMember :: !a ![a] -> [a] | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeAnyMember x [y:ys]
	| x == y							= removeAnyMember x ys
	= [y:removeAnyMember x ys]
removeAnyMember x []
	= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeAnyMembers :: ![a] ![a] -> [a] | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeAnyMembers [x:xs] ys
	# ys								= removeAnyMember x ys
	= removeAnyMembers xs ys
removeAnyMembers [] ys
	= ys

// -------------------------------------------------------------------------------------------------------------------------------------------------
class markDefinedVariables	a :: !a ![CName]							-> a
class getQualifiedNames		a :: !a										-> [PQualifiedName]
class bindQualifiedNames	a :: !a ![DefinitionInfo]					-> a
class findInfix				a :: !a										-> a
class freeVars				a :: !a										-> (![CName], ![(CName, PType)], ![CName])
class collectApplications	a :: !a										-> a
class arrangeBrackets		a :: !a !*CHeaps !*CProject					-> (!Error, !a, !*CHeaps, !*CProject)
// bindVariables :: PProp [CName, CExprVarPtr] [CName, CPropVarPtr] -> CProp
class typeCases				a :: !a !*CProject							-> (!Error, !a, !*CProject)
class bindRecords			a :: !a ![DefinitionInfo] !*CHeaps !*CProject	-> (!Error, !a, !*CHeaps, !*CProject)
class dummyDicts			a :: !(a b) !*CHeaps !*CProject				-> (!(a b), !*CHeaps, !*CProject) | getHeapPtr b
class convertPointer		c :: !(c ParsedPtr) !*CProject				-> (!Error, !c HeapPtr, !*CProject)
class instantiateClasses	a :: !TypingInfo !a !*CProject				-> (!Error, (!TypingInfo, !a), !*CProject)
class createDictionaries	a :: !TypingInfo !a !*CHeaps !*CProject		-> (!Error, (!TypingInfo, !a), !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------   
find :: !CName ![(CName, a)] -> Maybe a
// -------------------------------------------------------------------------------------------------------------------------------------------------   
find name []
	= Nothing
find name1 [(name2,ptr):rest]
	| name1 == name2			= Just ptr
	= find name1 rest

// =================================================================================================================================================
// if result is True the element is removed from the list
// -------------------------------------------------------------------------------------------------------------------------------------------------   
myIsMember :: !a ![a] -> (!Bool, ![a]) | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------   
myIsMember x [hd:tl]
	| x == hd				= (True, tl)
	#! (found, tl)			= myIsMember x tl
	= (found, [hd:tl])
myIsMember x []
	= (False, [])















// =================================================================================================================================================
// markDefinedVariables:
//    replace PNamedPtr by PVariablePtr if it is clear that the name has been defined
//    (needed for symbols that can both be a defined variable and a function/constructor;
//     choose the variable case)
// =================================================================================================================================================

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables [a] | markDefinedVariables a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables [] names
		= []
	markDefinedVariables [x:xs] names
		#! x					= markDefinedVariables x names
		#! xs					= markDefinedVariables xs names
		= [x:xs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables (Maybe a) | markDefinedVariables a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables Nothing names
		= Nothing
	markDefinedVariables (Just x) names
		#! x					= markDefinedVariables x names
		= Just x

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables pattern names
		# names					= names ++ pattern.p_atpExprVarScope
		= {pattern & p_atpResult = markDefinedVariables pattern.p_atpResult names}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables pattern names
		= {pattern & p_bapResult = markDefinedVariables pattern.p_bapResult names}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables (PBasicArray exprs) names
		#! exprs				= markDefinedVariables exprs names
		= PBasicArray exprs
	markDefinedVariables other names
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables (PAlgPatterns patterns) names
		= PAlgPatterns (markDefinedVariables patterns names)
	markDefinedVariables (PBasicPatterns patterns) names
		= PBasicPatterns (markDefinedVariables patterns names)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables (PExprVar name) names
		= PExprVar name
	markDefinedVariables (PApp expr exprs) names
		#! expr					= markDefinedVariables expr names
		#! exprs				= markDefinedVariables exprs names
		= PApp expr exprs
	markDefinedVariables (PSymbol ptr=:(PNamedPtr quaname=:{quaName,quaModuleName}) exprs) names
		#! exprs				= markDefinedVariables exprs names
		| isJust quaModuleName	= PSymbol ptr exprs
		| quaName == "_"		= PApp (PExprVar "_") exprs
		| isMember quaName names= PApp (PExprVar quaName) exprs
		= PSymbol ptr exprs
	markDefinedVariables (PSymbol ptr exprs) names
		#! exprs				= markDefinedVariables exprs names
		= PSymbol ptr exprs
	markDefinedVariables (PLet strict lets expr) names
		# (vars, exprs)			= unzip lets
		# names					= names ++ vars
		#! exprs				= markDefinedVariables exprs names
		# lets					= zip2 vars exprs
		#! expr					= markDefinedVariables expr names
		= PLet strict lets expr
	markDefinedVariables (PCase expr patterns def) names
		#! expr					= markDefinedVariables expr names
		#! patterns				= markDefinedVariables patterns names
		#! def					= markDefinedVariables def names
		= PCase expr patterns def
	markDefinedVariables (PBasicValue value) names
		= PBasicValue (markDefinedVariables value names)
	markDefinedVariables PBottom names
		= PBottom
	markDefinedVariables (PBracketExpr expr) names
	 	= PBracketExpr (markDefinedVariables expr names)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance markDefinedVariables PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	markDefinedVariables PTrue names
		= PTrue
	markDefinedVariables PFalse names
		= PFalse
	markDefinedVariables (PPropVar name) names
		= PPropVar name
	markDefinedVariables (PNot p) names
		= PNot (markDefinedVariables p names)
	markDefinedVariables (PAnd p q) names
		= PAnd (markDefinedVariables p names) (markDefinedVariables q names)
	markDefinedVariables (POr p q) names
		= POr (markDefinedVariables p names) (markDefinedVariables q names)
	markDefinedVariables (PImplies p q) names
		= PImplies (markDefinedVariables p names) (markDefinedVariables q names)
	markDefinedVariables (PIff p q) names
		= PIff (markDefinedVariables p names) (markDefinedVariables q names)
	markDefinedVariables (PExprForall var mb_type p) names
		# names						= [var:names]
		= PExprForall var mb_type (markDefinedVariables p names)
	markDefinedVariables (PExprExists var mb_type p) names
		# names						= [var:names]
		= PExprExists var mb_type (markDefinedVariables p names)
	markDefinedVariables (PPropForall var p) names
		# names						= [var:names]
		= PPropForall var (markDefinedVariables p names)
	markDefinedVariables (PPropExists var p) names
		# names						= [var:names]
		= PPropExists var (markDefinedVariables p names)
	markDefinedVariables (PEqual e1 e2) names
		= PEqual (markDefinedVariables e1 names) (markDefinedVariables e2 names)
	markDefinedVariables (PPredicate ptr es) names
		= PPredicate ptr (markDefinedVariables es names)
	markDefinedVariables (PBracketProp p) names
		= PBracketProp (markDefinedVariables p names)



















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames [a] | getQualifiedNames a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames []
		= []
	getQualifiedNames [x:xs]
		#! names				= getQualifiedNames x
		#! more_names			= getQualifiedNames xs
		= names ++ more_names

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames (Maybe a) | getQualifiedNames a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames Nothing
		= []
	getQualifiedNames (Just x)
		= getQualifiedNames x

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames pattern
		#! names				= getQualifiedNames pattern.p_atpDataCons
		#! more_names			= getQualifiedNames pattern.p_atpResult
		= names ++ more_names

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames pattern
		= getQualifiedNames pattern.p_bapResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames (PBasicArray exprs)
		= getQualifiedNames exprs
	getQualifiedNames other
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames (PAlgPatterns patterns)
		= getQualifiedNames patterns
	getQualifiedNames (PBasicPatterns patterns)
		= getQualifiedNames patterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames (PExprVar name)
		= []
	getQualifiedNames (PApp expr exprs)
		#! names				= getQualifiedNames expr
		#! more_names			= getQualifiedNames exprs
		= names ++ more_names
	getQualifiedNames (PSymbol ptr exprs)
		#! names				= getQualifiedNames ptr
		#! more_names			= getQualifiedNames exprs
		= names ++ more_names
	getQualifiedNames (PLet strict lets expr)
		#! names				= getQualifiedNames (map snd lets)
		#! more_names			= getQualifiedNames expr
		= names ++ more_names
	getQualifiedNames (PCase expr patterns def)
		#! names				= getQualifiedNames expr
		#! more_names			= getQualifiedNames patterns
		#! even_more_names		= getQualifiedNames def
		= names ++ more_names ++ even_more_names
	getQualifiedNames (PBasicValue value)
		= getQualifiedNames value
	getQualifiedNames PBottom
		= []
	getQualifiedNames (PBracketExpr e)
		= getQualifiedNames e

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames ParsedPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames (PNamedPtr quaname)
		= [quaname]
	getQualifiedNames other
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance getQualifiedNames PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	getQualifiedNames PTrue
		= []
	getQualifiedNames PFalse
		= []
	getQualifiedNames (PPropVar name)
		= []
	getQualifiedNames (PNot p)
		= getQualifiedNames p
	getQualifiedNames (PAnd p q)
		#! names				= getQualifiedNames p
		#! more_names			= getQualifiedNames q
		= names ++ more_names
	getQualifiedNames (POr p q)
		#! names				= getQualifiedNames p
		#! more_names			= getQualifiedNames q
		= names ++ more_names
	getQualifiedNames (PImplies p q)
		#! names				= getQualifiedNames p
		#! more_names			= getQualifiedNames q
		= names ++ more_names
	getQualifiedNames (PIff p q)
		#! names				= getQualifiedNames p
		#! more_names			= getQualifiedNames q
		= names ++ more_names
	getQualifiedNames (PExprForall var mb_type p)
		= getQualifiedNames p
	getQualifiedNames (PExprExists var mb_type p)
		= getQualifiedNames p
	getQualifiedNames (PPropForall var p)
		= getQualifiedNames p
	getQualifiedNames (PPropExists var p)
		= getQualifiedNames p
	getQualifiedNames (PEqual e1 e2)
		= (getQualifiedNames e1) ++ (getQualifiedNames e2)
	getQualifiedNames (PPredicate ptr es)
		#! names				= getQualifiedNames ptr
		#! more_names			= getQualifiedNames es
		= names ++ more_names
	getQualifiedNames (PBracketProp p)
		= getQualifiedNames p




















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames [a] | bindQualifiedNames a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames [] infos
		= []
	bindQualifiedNames [x:xs] infos
		#! x					= bindQualifiedNames x infos
		#! xs					= bindQualifiedNames xs infos
		= [x:xs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames (Maybe a) | bindQualifiedNames a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames Nothing infos
		= Nothing
	bindQualifiedNames (Just x) infos
		= Just (bindQualifiedNames x infos)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames pattern infos
		# (mb_name, ptr)		= bindQualifiedPtr pattern.p_atpDataCons infos
		# datacons				= if (isJust mb_name) PUnknownPtr ptr
		= {pattern	& p_atpResult		= bindQualifiedNames pattern.p_atpResult infos
					, p_atpDataCons		= datacons}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames pattern infos
		= {pattern & p_bapResult = bindQualifiedNames pattern.p_bapResult infos}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames (PBasicArray exprs) infos
		= PBasicArray (bindQualifiedNames exprs infos)
	bindQualifiedNames other infos
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames (PAlgPatterns patterns) infos
		= PAlgPatterns (bindQualifiedNames patterns infos)
	bindQualifiedNames (PBasicPatterns patterns) infos
		= PBasicPatterns (bindQualifiedNames patterns infos)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames (PExprVar name) infos
		= PExprVar name
	bindQualifiedNames (PApp expr exprs) infos
		#! expr					= bindQualifiedNames expr infos
		#! exprs				= bindQualifiedNames exprs infos
		= PApp expr exprs
	bindQualifiedNames (PSymbol ptr exprs) infos
		#! (mb_name, ptr)		= bindQualifiedPtr ptr infos
		#! exprs				= bindQualifiedNames exprs infos
		| isJust mb_name		= PApp (PExprVar (fromJust mb_name)) exprs
		= PSymbol ptr exprs
	bindQualifiedNames (PLet strict lets expr) infos
		# (vars, exprs)			= unzip lets
		#! exprs				= bindQualifiedNames exprs infos
		# lets					= zip2 vars exprs
		#! expr					= bindQualifiedNames expr infos
		= PLet strict lets expr
	bindQualifiedNames (PCase expr patterns def) infos
		#! expr					= bindQualifiedNames expr infos
		#! patterns				= bindQualifiedNames patterns infos
		#! def					= bindQualifiedNames def infos
		= PCase expr patterns def
	bindQualifiedNames (PBasicValue value) infos
		= PBasicValue (bindQualifiedNames value infos)
	bindQualifiedNames PBottom infos
		= PBottom
	bindQualifiedNames (PBracketExpr e) infos
		= PBracketExpr (bindQualifiedNames e infos)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindQualifiedPtr :: !ParsedPtr ![DefinitionInfo] -> (!Maybe CName, !ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindQualifiedPtr ptr=:(PNamedPtr qua_name) [info:infos]
	# mod_ok				= case qua_name.quaModuleName of
								Nothing		-> True
								(Just name)	-> info.diModuleName == name
	# name_ok				= qua_name.quaName == info.diName
	| mod_ok && name_ok
		| info.diInfix		= (Nothing, PInfixPtr info.diPointer)
		= (Nothing, PHeapPtr info.diPointer)
	= bindQualifiedPtr ptr infos
bindQualifiedPtr (PNamedPtr quaname) []
	= (Just quaname.quaName, DummyValue)
bindQualifiedPtr ptr other
	= (Nothing, ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindQualifiedNames PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindQualifiedNames PTrue infos
		= PTrue
	bindQualifiedNames PFalse infos
		= PFalse
	bindQualifiedNames (PPropVar name) infos
		= PPropVar name
	bindQualifiedNames (PNot p) infos
		#! p					= bindQualifiedNames p infos
		= PNot p
	bindQualifiedNames (PAnd p q) infos
		#! p					= bindQualifiedNames p infos
		#! q					= bindQualifiedNames q infos
		= PAnd p q
	bindQualifiedNames (POr p q) infos
		#! p					= bindQualifiedNames p infos
		#! q					= bindQualifiedNames q infos
		= POr p q
	bindQualifiedNames (PImplies p q) infos
		#! p					= bindQualifiedNames p infos
		#! q					= bindQualifiedNames q infos
		= PImplies p q
	bindQualifiedNames (PIff p q) infos
		#! p					= bindQualifiedNames p infos
		#! q					= bindQualifiedNames q infos
		= PIff p q
	bindQualifiedNames (PExprForall var mb_type p) infos
		#! p					= bindQualifiedNames p infos
		= PExprForall var mb_type p
	bindQualifiedNames (PExprExists var mb_type p) infos
		#! p					= bindQualifiedNames p infos
		= PExprExists var mb_type p
	bindQualifiedNames (PPropForall var p) infos
		#! p					= bindQualifiedNames p infos
		= PPropForall var p
	bindQualifiedNames (PPropExists var p) infos
		#! p					= bindQualifiedNames p infos
		= PPropExists var p
	bindQualifiedNames (PEqual e1 e2) infos
		#! e1					= bindQualifiedNames e1 infos
		#! e2					= bindQualifiedNames e2 infos
		= PEqual e1 e2
	bindQualifiedNames (PPredicate ptr es) infos
		#! es					= bindQualifiedNames es infos
		= PPredicate ptr es
	bindQualifiedNames (PBracketProp p) infos
		#! p					= bindQualifiedNames p infos
		= PBracketProp p

// -------------------------------------------------------------------------------------------------------------------------------------------------
BindQualifiedNames :: !a !*CHeaps !*CProject -> (!Error, !a, !*CHeaps, !*CProject) | getQualifiedNames a & bindQualifiedNames a & DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindQualifiedNames term heaps prj
	# qualified						= removeDup (getQualifiedNames term)
	# (mod_ptrs, prj)				= prj!prjModules
	# mod_ptrs						= [nilPtr: mod_ptrs]
	# (error, ptrs1, heaps)			= getHeapPtrs mod_ptrs [CMember] heaps
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, infos1, heaps, prj)	= uumapError getDefinitionInfo ptrs1 heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, ptrs2, heaps)			= getHeapPtrs mod_ptrs [CFun] heaps
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, infos2, heaps, prj)	= uumapError getDefinitionInfo ptrs2 heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, ptrs3, heaps)			= getHeapPtrs mod_ptrs [CDataCons] heaps
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, infos3, heaps, prj)	= uumapError getDefinitionInfo ptrs3 heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# infos							= filterInfos (infos1 ++ infos2 ++ infos3) qualified
	# term							= bindQualifiedNames term infos
	= (OK, term, heaps, prj)
	where
		filterInfos :: ![DefinitionInfo] ![PQualifiedName] -> [DefinitionInfo]
		filterInfos [info:infos] names
			# name1					= {quaModuleName = Nothing, quaName = info.diName}
			# name2					= {quaModuleName = Just info.diModuleName, quaName = info.diName}
			#! (found, names)		= myIsMember name1 names
			| found					= [info: filterInfos infos names]
			#! (found, names)		= myIsMember name2 names
			| found					= [info: filterInfos infos names]
			= filterInfos infos names
		filterInfos [] names
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
BindQualifiedFunction :: !PQualifiedName !*CHeaps !*CProject -> (!Maybe HeapPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindQualifiedFunction qua_name heaps prj
	# (mod_ptrs, prj)				= prj!prjModules
	# mod_ptrs						= [nilPtr: mod_ptrs]
	# (error, ptrs, heaps)			= getHeapPtrs mod_ptrs [CFun] heaps
	| isError error					= (Nothing, heaps, prj)
	# (error, infos, heaps, prj)	= uumapError getDefinitionInfo ptrs heaps prj
	| isError error					= (Nothing, heaps, prj)
	= case qua_name.quaModuleName of
		(Just name)		-> find1 qua_name.quaName name infos heaps prj
		Nothing			-> find2 qua_name.quaName      infos heaps prj
	where
		find1 :: !CName !CName ![DefinitionInfo] !*CHeaps !*CProject -> (!Maybe HeapPtr, !*CHeaps, !*CProject)
		find1 name mod_name [info:infos] heaps prj
			| name <> info.diName			= find1 name mod_name infos heaps prj
			| mod_name <> info.diModuleName	= find1 name mod_name infos heaps prj
			= (Just info.diPointer, heaps, prj)
		find1 _ _ [] heaps prj
			= (Nothing, heaps, prj)
		
		find2 :: !CName ![DefinitionInfo] !*CHeaps !*CProject -> (!Maybe HeapPtr, !*CHeaps, !*CProject)
		find2 name [info:infos] heaps prj
			| name <> info.diName			= find2 name infos heaps prj
			= (Just info.diPointer, heaps, prj)
		find2 _ [] heaps prj
			= (Nothing, heaps, prj)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix [a] | findInfix a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix [x:xs]
		# x							= findInfix x
		# xs						= findInfix xs
		= [x:xs]
	findInfix []
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix (Maybe a) | findInfix a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix (Just x)
		# x							= findInfix x
		= Just x
	findInfix Nothing
		= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix pattern
		# result					= findInfix pattern.p_atpResult
		= {pattern & p_atpResult = result}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix pattern
		# result					= findInfix pattern.p_bapResult
		= {pattern & p_bapResult = result}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix (PBasicArray exprs)
		# exprs						= findInfix exprs
		= PBasicArray exprs
	findInfix other
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix (PAlgPatterns patterns)
		# patterns					= findInfix patterns
		= PAlgPatterns patterns
	findInfix (PBasicPatterns patterns)
		# patterns					= findInfix patterns
		= PBasicPatterns patterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix (PExprVar name)
		= PExprVar name
	findInfix (PApp expr exprs)
		# expr						= findInfix expr
		# exprs						= findInfix exprs
		= traverse expr exprs
		where
			// creates superfluous APP nodes; these are removed by collectApplications
			traverse acc []
				= acc
			traverse lhs [PSymbol (PInfixPtr ptr) []: [expr:exprs]]
				# rhs				= traverse expr exprs
				= PSymbol (PInfixPtr ptr) [lhs, rhs]
			traverse acc [expr:exprs]
				= traverse (PApp acc [expr]) exprs
	findInfix (PSymbol ptr [])
		= PSymbol ptr []
	findInfix (PSymbol ptr exprs)
		= findInfix (PApp (PSymbol ptr []) exprs)
	findInfix (PLet strict lets expr)
		# (vars, exprs)				= unzip lets
		# exprs						= findInfix exprs
		# lets						= zip2 vars exprs
		# expr						= findInfix expr
		= PLet strict lets expr
	findInfix (PCase expr patterns def)
		# expr						= findInfix expr
		# patterns					= findInfix patterns
		# def						= findInfix def
		= PCase expr patterns def
	findInfix (PBasicValue value)
		# value						= findInfix value
		= PBasicValue value
	findInfix PBottom
		= PBottom
	findInfix (PBracketExpr expr)
		= PBracketExpr (findInfix expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance findInfix PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	findInfix PTrue
		= PTrue
	findInfix PFalse
		= PFalse
	findInfix (PPropVar name)
		= PPropVar name
	findInfix (PEqual e1 e2)
		# e1						= findInfix e1
		# e2						= findInfix e2
		= PEqual e1 e2
	findInfix (PNot p)
		# p							= findInfix p
		= PNot p
	findInfix (PAnd p q)
		# p							= findInfix p
		# q							= findInfix q
		= PAnd p q
	findInfix (POr p q)
		# p							= findInfix p
		# q							= findInfix q
		= POr p q
	findInfix (PImplies p q)
		# p							= findInfix p
		# q							= findInfix q
		= PImplies p q
	findInfix (PIff p q)
		# p							= findInfix p
		# q							= findInfix q	
		= PIff p q
	findInfix (PExprForall var mb_type p)
		# p							= findInfix p
		= PExprForall var mb_type p
	findInfix (PExprExists var mb_type p)
		# p							= findInfix p
		= PExprExists var mb_type p
	findInfix (PPropForall var p)
		# p							= findInfix p
		= PPropForall var p
	findInfix (PPropExists var p)
		# p							= findInfix p
		= PPropExists var p
	findInfix (PPredicate ptr es)
		# es						= findInfix es
		= PPredicate ptr es
	findInfix (PBracketProp p)
		# p							= findInfix p
		= PBracketProp p




















// -------------------------------------------------------------------------------------------------------------------------------------------------
add :: !(![a], ![b], ![c]) !(![a], ![b], ![c]) -> (![a], ![b], ![c])
// -------------------------------------------------------------------------------------------------------------------------------------------------
add (xs1, ys1, zs1) (xs2, ys2, zs2)
	= (xs1 ++ xs2, ys1 ++ ys2, zs1 ++ zs2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars [a] | freeVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars [x:xs]
		= add (freeVars x) (freeVars xs)
	freeVars []
		= ([], [], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars (Maybe a) | freeVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars (Just x)
		= freeVars x
	freeVars Nothing
		= ([], [], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars pattern
		# (evars, types, pvars)		= freeVars pattern.p_atpResult
		# bound						= pattern.p_atpExprVarScope
		# evars						= removeAnyMembers evars bound
		= (evars, types, pvars)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars pattern
		= freeVars pattern.p_bapResult

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars (PBasicArray exprs)
		= freeVars exprs
	freeVars other
		= ([], [], [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars (PAlgPatterns patterns)
		= freeVars patterns
	freeVars (PBasicPatterns patterns)
		= freeVars patterns

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars (PExprVar name)
		= ([name], [], [])
	freeVars (PApp expr exprs)
		= add (freeVars expr) (freeVars exprs)
	freeVars (PSymbol ptr exprs)
		= freeVars exprs
	freeVars (PLet strict lets expr)
		# (vars, exprs)				= unzip lets
		# (evars, types, pvars)		= add (freeVars exprs) (freeVars expr)
		# evars						= removeAnyMembers evars vars
		= (evars, types, pvars)
	freeVars (PCase expr patterns def)
		= add (freeVars expr) (add (freeVars patterns) (freeVars def))
	freeVars (PBasicValue value)
		= freeVars value
	freeVars PBottom
		= ([], [], [])
	freeVars (PBracketExpr expr)
		= freeVars expr

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance freeVars PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	freeVars PTrue
		= ([], [], [])
	freeVars PFalse
		= ([], [], [])
	freeVars (PPropVar name)
		= ([], [], [name])
	freeVars (PNot p)
		= freeVars p
	freeVars (PAnd p q)
		= add (freeVars p) (freeVars q)
	freeVars (POr p q)
		= add (freeVars p) (freeVars q)
	freeVars (PImplies p q)
		= add (freeVars p) (freeVars q)
	freeVars (PIff p q)
		= add (freeVars p) (freeVars q)
	freeVars (PExprForall var mb_type p)
		#! (evars, types, pvars)	= freeVars p
		# evars						= removeAnyMember var evars
		# types						= case mb_type of
										Just type	-> [(var,type):types]
										Nothing		-> types
		= (evars, types, pvars)
	freeVars (PExprExists var mb_type p)
		#! (evars, types, pvars)	= freeVars p
		# evars						= removeAnyMember var evars
		# types						= case mb_type of
										Just type	-> [(var,type):types]
										Nothing		-> types
		= (evars, types, pvars)
	freeVars (PPropForall var p)
		#! (evars, types, pvars)	= freeVars p
		# pvars						= removeAnyMember var pvars
		= (evars, types, pvars)
	freeVars (PPropExists var p)
		#! (evars, types, pvars)	= freeVars p
		# pvars						= removeAnyMember var pvars
		= (evars, types, pvars)
	freeVars (PEqual e1 e2)
		= add (freeVars e1) (freeVars e2)
	freeVars (PPredicate ptr es)
		= freeVars es
	freeVars (PBracketProp p)
		= freeVars p

// -------------------------------------------------------------------------------------------------------------------------------------------------
FreeVars :: a -> (![CName], ![(CName, PType)], ![CName]) | freeVars a
// -------------------------------------------------------------------------------------------------------------------------------------------------
FreeVars x
	# (evars, types, pvars)			= freeVars x
	= (removeDup evars, types, removeDup pvars)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications [a] | collectApplications a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications [x:xs]
		= [collectApplications x: collectApplications xs]
	collectApplications []
		= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (Maybe a) | collectApplications a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (Just x)
		= Just (collectApplications x)
	collectApplications Nothing
		= Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications pattern
		= {pattern & p_atpResult = collectApplications pattern.p_atpResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CAlgPattern def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications pattern
		= {pattern & atpResult = collectApplications pattern.atpResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications pattern
		= {pattern & p_bapResult = collectApplications pattern.p_bapResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CBasicPattern def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications pattern
		= {pattern & bapResult = collectApplications pattern.bapResult}

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (PBasicArray exprs)
		= PBasicArray (collectApplications exprs)
	collectApplications other
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CBasicValue def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (CBasicArray exprs)
		= CBasicArray (collectApplications exprs)
	collectApplications other
		= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (PAlgPatterns patterns)
		= PAlgPatterns (collectApplications patterns)
	collectApplications (PBasicPatterns patterns)
		= PBasicPatterns (collectApplications patterns)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CCasePatterns def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (CAlgPatterns type patterns)
		= CAlgPatterns type (collectApplications patterns)
	collectApplications (CBasicPatterns type patterns)
		= CBasicPatterns type (collectApplications patterns)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (PExprVar name)
		= PExprVar name
	collectApplications (PApp (PBracketExpr expr) exprs)
		= collectApplications (PApp expr exprs)
	collectApplications (PApp (PApp expr exprs1) exprs2)
		= collectApplications (PApp expr (exprs1 ++ exprs2))
	collectApplications (PApp (PSymbol ptr exprs1) exprs2)
		= collectApplications (PSymbol ptr (exprs1 ++ exprs2))
	collectApplications (PApp expr exprs)
		= PApp (collectApplications expr) (collectApplications exprs)
	collectApplications (PSymbol ptr exprs)
		= PSymbol ptr (collectApplications exprs)
	collectApplications (PLet strict lets expr)
		# (vars, exprs)					= unzip lets
		# exprs							= collectApplications exprs
		# lets							= zip2 vars exprs
		# expr							= collectApplications expr
		= PLet strict lets expr
	collectApplications (PCase expr patterns def)
		# expr							= collectApplications expr
		# patterns						= collectApplications patterns
		# def							= collectApplications def
		= PCase expr patterns def
	collectApplications (PBasicValue value)
		= PBasicValue (collectApplications value)
	collectApplications PBottom
		= PBottom
	collectApplications (PBracketExpr expr)
		= PBracketExpr (collectApplications expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CExpr def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications (CExprVar ptr)
		= CExprVar ptr
	collectApplications (CShared ptr)
		= CShared ptr
	collectApplications ((expr @# exprs1) @# exprs2)
		= collectApplications (expr @# (exprs1 ++ exprs2))
	collectApplications ((ptr @@# exprs1) @# exprs2)
		= collectApplications (ptr @@# (exprs1 ++ exprs2))
	collectApplications (expr @# exprs)
		= (collectApplications expr) @# (collectApplications exprs)
	collectApplications (ptr @@# exprs)
		= ptr @@# (collectApplications exprs)
	collectApplications (CLet strict lets expr)
		# (vars, exprs)					= unzip lets
		# exprs							= collectApplications exprs
		# lets							= zip2 vars exprs
		# expr							= collectApplications expr
		= CLet strict lets expr
	collectApplications (CCase expr patterns def)
		# expr							= collectApplications expr
		# patterns						= collectApplications patterns
		# def							= collectApplications def
		= CCase expr patterns def
	collectApplications (CBasicValue value)
		= CBasicValue (collectApplications value)
	collectApplications (CCode codetype codecontents)
		= CCode codetype codecontents
	collectApplications CBottom
		= CBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications PTrue
		= PTrue
	collectApplications PFalse
		= PFalse
	collectApplications (PPropVar name)
		= PPropVar name
	collectApplications (PEqual e1 e2)
		= PEqual (collectApplications e1) (collectApplications e2)
	collectApplications (PNot p)
		= PNot (collectApplications p)
	collectApplications (PAnd p q)
		= PAnd (collectApplications p) (collectApplications q)
	collectApplications (POr p q)
		= POr (collectApplications p) (collectApplications q)
	collectApplications (PImplies p q)
		= PImplies (collectApplications p) (collectApplications q)
	collectApplications (PIff p q)
		= PIff (collectApplications p) (collectApplications q)
	collectApplications (PExprForall var mb_type p)
		= PExprForall var mb_type (collectApplications p)
	collectApplications (PExprExists var mb_type p)
		= PExprExists var mb_type (collectApplications p)
	collectApplications (PPropForall var p)
		= PPropForall var (collectApplications p)
	collectApplications (PPropExists var p)
		= PPropExists var (collectApplications p)
	collectApplications (PPredicate ptr es)
		= PPredicate ptr (collectApplications es)
	collectApplications (PBracketProp p)
		= PBracketProp (collectApplications p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance collectApplications (CProp def_ptr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	collectApplications CTrue
		= CTrue
	collectApplications CFalse
		= CFalse
	collectApplications (CPropVar ptr)
		= CPropVar ptr
	collectApplications (CNot p)
		= CNot (collectApplications p)
	collectApplications (CAnd p q)
		= CAnd (collectApplications p) (collectApplications q)
	collectApplications (COr p q)
		= COr (collectApplications p) (collectApplications q)
	collectApplications (CImplies p q)
		= CImplies (collectApplications p) (collectApplications q)
	collectApplications (CIff p q)
		= CIff (collectApplications p) (collectApplications q)
	collectApplications (CExprForall var p)
		= CExprForall var (collectApplications p)
	collectApplications (CExprExists var p)
		= CExprExists var (collectApplications p)
	collectApplications (CPropForall var p)
		= CPropForall var (collectApplications p)
	collectApplications (CPropExists var p)
		= CPropExists var (collectApplications p)
	collectApplications (CEqual e1 e2)
		= CEqual (collectApplications e1) (collectApplications e2)
	collectApplications (CPredicate ptr es)
		= CPredicate ptr (collectApplications es)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets [a] | arrangeBrackets a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets [x:xs] heaps prj
		#! (error, x, heaps, prj)		= arrangeBrackets x heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, xs, heaps, prj)		= arrangeBrackets xs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, [x:xs], heaps, prj)
	arrangeBrackets [] heaps prj
		= (OK, [], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets (Maybe a) | arrangeBrackets a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets (Just x) heaps prj
		#! (error, x, heaps, prj)		= arrangeBrackets x heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, Just x, heaps, prj)
	arrangeBrackets Nothing heaps prj
		= (OK, Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets pattern heaps prj
		#! (error, result, heaps, prj)	= arrangeBrackets pattern.p_atpResult heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, {pattern & p_atpResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets pattern heaps prj
		#! (error, result, heaps, prj)	= arrangeBrackets pattern.p_bapResult heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, {pattern & p_bapResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets (PBasicArray exprs) heaps prj
		#! (error, exprs, heaps, prj)	= arrangeBrackets exprs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PBasicArray exprs, heaps, prj)
	arrangeBrackets other heaps prj
		= (OK, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets (PAlgPatterns patterns) heaps prj
		#! (error, patterns, heaps, prj)= arrangeBrackets patterns heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PAlgPatterns patterns, heaps, prj)
	arrangeBrackets (PBasicPatterns patterns) heaps prj
		#! (error, patterns, heaps, prj)= arrangeBrackets patterns heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PBasicPatterns patterns, heaps, prj)

// BEZIG -- DEBUGGING
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets (PExprVar ptr) heaps prj
		= (OK, PExprVar ptr, heaps, prj)
	arrangeBrackets (PApp expr exprs) heaps prj
		#! (error, expr, heaps, prj)	= arrangeBrackets expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, exprs, heaps, prj)	= arrangeBrackets exprs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PApp expr exprs, heaps, prj)
	arrangeBrackets (PSymbol ptr exprs) heaps prj
		# brackets						= case exprs of
											[e1,e2]		-> hasBrackets e2
											_			-> False
		# (error, exprs, heaps, prj)	= arrangeBrackets exprs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= combine brackets ptr exprs heaps prj
		where
			combine :: !Bool !ParsedPtr ![PExpr] !*CHeaps !*CProject -> (!Error, !PExpr, !*CHeaps, !*CProject)
			combine False ptr1 exprs=:[arg1, PSymbol ptr2 [arg2, arg3]] heaps prj // arg1 op1 arg2 op2 arg3
				// retreive infix of ptr1
				# (ok1, heap_ptr1)						= getHeapPtr ptr1
				| not ok1								= (OK, PSymbol ptr1 exprs, heaps, prj)
				# (error, inf1, heaps, prj)				= getDefinitionInfix heap_ptr1 heaps prj
				| isError error							= (error, DummyValue, heaps, prj)
				| not (isInfix inf1)					= (OK, PSymbol ptr1 exprs, heaps, prj)
				// retreive infix of ptr2
				# (ok2, heap_ptr2)						= getHeapPtr ptr2
				| not ok2								= (OK, PSymbol ptr1 exprs, heaps, prj)
				# (error, inf2, heaps, prj)				= getDefinitionInfix heap_ptr2 heaps prj
				| isError error							= (error, DummyValue, heaps, prj)
				| not (isInfix inf2)					= (OK, PSymbol ptr1 exprs, heaps, prj)
				// both are infix, so re-arrange brackets
				# left_brackets							= PSymbol ptr2 [PSymbol ptr1 [arg1,arg2], arg3]
				# right_brackets						= PSymbol ptr1 [arg1, PSymbol ptr2 [arg2,arg3]]
				| heap_ptr1 == heap_ptr2
					| isLeftAssociative inf1			= (OK, left_brackets, heaps, prj)
					| isRightAssociative inf1			= (OK, right_brackets, heaps, prj)
					# (error, name, heaps, prj)			= getDefinitionName heap_ptr1 heaps prj
					| isError error						= (error, DummyValue, heaps, prj)
					# error_msg							= "No associativity specified for operator '" +++ name +++ "'"
					= (pushError (X_Parse error_msg) OK, DummyValue, heaps, prj)
				# (prio1, prio2)						= (getPriority inf1, getPriority inf2)
				| prio1 < prio2							= (OK, right_brackets, heaps, prj)
				| prio1 == prio2						= (OK, left_brackets, heaps, prj)		// behaviour as in Clean
				| prio1 > prio2							= (OK, left_brackets, heaps, prj)
			combine _ ptr exprs heaps prj
				= (OK, PSymbol ptr exprs, heaps, prj)
	arrangeBrackets (PLet strict lets expr) heaps prj
		# (vars, exprs)					= unzip lets
		#! (error, exprs, heaps, prj)	= arrangeBrackets exprs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# lets							= zip2 vars exprs
		#! (error, expr, heaps, prj)	= arrangeBrackets expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PLet strict lets expr, heaps, prj)
	arrangeBrackets (PCase expr patterns def) heaps prj
		#! (error, expr, heaps, prj)	= arrangeBrackets expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, patterns, heaps, prj)= arrangeBrackets patterns heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, def, heaps, prj)		= arrangeBrackets def heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PCase expr patterns def, heaps, prj)
	arrangeBrackets (PBasicValue value) heaps prj
		#! (error, value, heaps, prj)	= arrangeBrackets value heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PBasicValue value, heaps, prj)
	arrangeBrackets PBottom heaps prj
		= (OK, PBottom, heaps, prj)
	arrangeBrackets (PBracketExpr expr) heaps prj
		#! (error, expr, heaps, prj)	= arrangeBrackets expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, expr, heaps, prj)

// =================================================================================================================================================
// Priorities from high to low: <->, /\, \/, ->
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance arrangeBrackets PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	arrangeBrackets PTrue heaps prj
		= (OK, PTrue, heaps, prj)
	arrangeBrackets PFalse heaps prj
		= (OK, PFalse, heaps, prj)
	arrangeBrackets (PPropVar name) heaps prj
		= (OK, PPropVar name, heaps, prj)
	arrangeBrackets (PEqual e1 e2) heaps prj
		# (error, e1, heaps, prj)		= arrangeBrackets e1 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, e2, heaps, prj)		= arrangeBrackets e2 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PEqual e1 e2, heaps, prj)
	arrangeBrackets (PNot p) heaps prj
		# (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PNot p, heaps, prj)
	arrangeBrackets (PAnd p q) heaps prj
		# brackets						= hasBrackets q
		# (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, q, heaps, prj)		= arrangeBrackets q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, combine_and brackets p q, heaps, prj)
		where
			combine_and :: !Bool !PProp !PProp -> PProp
			combine_and False p (POr q r)			// p /\ q \/ r  ==> (p /\ q) \/ r
				= POr (PAnd p q) r
			combine_and False p (PImplies q r)		// p /\ q -> r  ==> (p /\ q) -> r
				= PImplies (PAnd p q) r
			combine_and _ p q
				= PAnd p q
	arrangeBrackets (POr p q) heaps prj
		# brackets						= hasBrackets q
		# (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, q, heaps, prj)		= arrangeBrackets q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, combine_or brackets p q, heaps, prj)
		where
			combine_or :: !Bool !PProp !PProp -> PProp
			combine_or False p (PImplies q r)		// p \/ q -> r  ==> (p \/ q) -> r
				= PImplies (POr p q) r
			combine_or _ p q
				= POr p q
	arrangeBrackets (PImplies p q) heaps prj
		# brackets						= hasBrackets q
		# (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, q, heaps, prj)		= arrangeBrackets q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, combine_implies brackets p q, heaps, prj)
		where
			combine_implies :: !Bool !PProp !PProp -> PProp
			combine_implies _ p q
				= PImplies p q
	arrangeBrackets (PIff p q) heaps prj
		# brackets						= hasBrackets q
		# (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, q, heaps, prj)		= arrangeBrackets q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, combine_iff brackets p q, heaps, prj)
		where
			combine_iff :: !Bool !PProp !PProp -> PProp
			combine_iff False p (PAnd q r)			// p <-> q /\ r  ==> (p <-> q) /\ r
				= PAnd (PIff p q) r
			combine_iff False p (POr q r)			// p <-> q \/ r  ==> (p <-> q) \/ r
				= POr (PIff p q) r
			combine_iff False p (PImplies q r)		// p <-> q -> r  ==> (p <-> q) -> r
				= PImplies (PIff p q) r
			combine_iff _ p q
				= PIff p q
	arrangeBrackets (PExprForall var mb_type p) heaps prj
		#! (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PExprForall var mb_type p, heaps, prj)
	arrangeBrackets (PExprExists var mb_type p) heaps prj
		#! (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PExprExists var mb_type p, heaps, prj)
	arrangeBrackets (PPropForall var p) heaps prj
		#! (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PPropForall var p, heaps, prj)
	arrangeBrackets (PPropExists var p) heaps prj
		#! (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PPropExists var p, heaps, prj)
	arrangeBrackets (PPredicate ptr exprs) heaps prj
		#! (error, exprs, heaps, prj)	= arrangeBrackets exprs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, PPredicate ptr exprs, heaps, prj)
	arrangeBrackets (PBracketProp p) heaps prj
		#! (error, p, heaps, prj)		= arrangeBrackets p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, p, heaps, prj)


















// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVars :: ![CName] ![(CName, CExprVarPtr)] !*CHeaps -> (![CExprVarPtr], ![(CName, CExprVarPtr)], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVars [name:names] evars heaps
	# (ptr, heaps)					= newPointer {DummyValue & evarName = name} heaps
	# evars							= [(name,ptr):evars]
	# (ptrs, evars, heaps)			= bindExprVars names evars heaps
	= ([ptr:ptrs], evars, heaps)
bindExprVars [] evars heaps
	= ([], evars, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropVars :: ![CName] ![(CName, CPropVarPtr)] !*CHeaps -> (![CPropVarPtr], ![(CName, CPropVarPtr)], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropVars [name:names] pvars heaps
	# (ptr, heaps)					= newPointer {DummyValue & pvarName = name} heaps
	# pvars							= [(name,ptr):pvars]
	# (ptrs, pvars, heaps)			= bindPropVars names pvars heaps
	= ([ptr:ptrs], pvars, heaps)
bindPropVars [] pvars heaps
	= ([], pvars, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesL :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] ![PExpr] !*CHeaps -> (![CExpr ParsedPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesL evars pvars [expr:exprs] heaps
	#! (expr, heaps)				= bindVariablesE evars pvars expr heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	= ([expr:exprs], heaps)
bindVariablesL evars pvars [] heaps
	= ([], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesM :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !(Maybe PExpr) !*CHeaps -> (!Maybe (CExpr ParsedPtr), !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesM evars pvars (Just expr) heaps
	#! (expr, heaps)				= bindVariablesE evars pvars expr heaps
	= (Just expr, heaps)
bindVariablesM evars pvars Nothing heaps
	= (Nothing, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesAP :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PAlgPattern !*CHeaps -> (!CAlgPattern ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesAP evars pvars pattern heaps
	# (ptrs, evars, heaps)			= bindExprVars pattern.p_atpExprVarScope evars heaps
	#! (result, heaps)				= bindVariablesE evars pvars pattern.p_atpResult heaps
	= ({atpExprVarScope = ptrs, atpResult = result, atpDataCons = pattern.p_atpDataCons}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesBP :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PBasicPattern !*CHeaps -> (!CBasicPattern ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesBP evars pvars pattern heaps
	#! (value, heaps)				= bindVariablesBV evars pvars pattern.p_bapBasicValue heaps
	#! (result, heaps)				= bindVariablesE evars pvars pattern.p_bapResult heaps
	= ({bapResult = result, bapBasicValue = value}, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesBV :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PBasicValue !*CHeaps -> (!CBasicValue ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesBV evars pvars (PBasicInteger num) heaps
	= (CBasicInteger num, heaps)
bindVariablesBV evars pvars (PBasicCharacter char) heaps
	= (CBasicCharacter char, heaps)
bindVariablesBV evars pvars (PBasicRealNumber real) heaps
	= (CBasicRealNumber real, heaps)
bindVariablesBV evars pvars (PBasicBoolean bool) heaps
	= (CBasicBoolean bool, heaps)
bindVariablesBV evars pvars (PBasicString string) heaps
	= (CBasicString string, heaps)
bindVariablesBV evars pvars (PBasicArray exprs) heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	= (CBasicArray exprs, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesCP :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PCasePatterns !*CHeaps -> (!CCasePatterns ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesCP evars pvars (PAlgPatterns patterns) heaps
	#! (patterns, heaps)			= umap (bindVariablesAP evars pvars) patterns heaps
	= (CAlgPatterns DummyValue patterns, heaps)
bindVariablesCP evars pvars (PBasicPatterns patterns) heaps
	#! (patterns, heaps)			= umap (bindVariablesBP evars pvars) patterns heaps
	= (CBasicPatterns DummyValue patterns, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesE :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PExpr !*CHeaps -> (!CExpr ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesE evars pvars (PExprVar name) heaps
	# mb_ptr						= find name evars
	| isNothing mb_ptr				= abort "Impossible case reached in bindVariablesE."	// impossible; addQuantors should have been executed
	= (CExprVar (fromJust mb_ptr), heaps)
bindVariablesE evars pvars (PApp expr exprs) heaps
	#! (expr, heaps)				= bindVariablesE evars pvars expr heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	= (expr @# exprs, heaps)
bindVariablesE evars pvars (PSymbol ptr exprs) heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	= (ptr @@# exprs, heaps)
bindVariablesE evars pvars (PLet strict lets expr) heaps
	# (vars, exprs)					= unzip lets
	# (ptrs, evars, heaps)			= bindExprVars vars evars heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	# lets							= zip2 ptrs exprs
	#! (expr, heaps)				= bindVariablesE evars pvars expr heaps
	= (CLet strict lets expr, heaps)
bindVariablesE evars pvars (PCase expr patterns def) heaps
	#! (expr, heaps)				= bindVariablesE evars pvars expr heaps
	#! (patterns, heaps)			= bindVariablesCP evars pvars patterns heaps
	#! (def, heaps)					= bindVariablesM evars pvars def heaps
	= (CCase expr patterns def, heaps)
bindVariablesE evars pvars (PBasicValue value) heaps
	#! (value, heaps)				= bindVariablesBV evars pvars value heaps
	= (CBasicValue value, heaps)
bindVariablesE evars pvars PBottom heaps
	= (CBottom, heaps)
bindVariablesE evars pvars (PBracketExpr expr) heaps
	= bindVariablesE evars pvars expr heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesP :: ![(CName, CExprVarPtr)] ![(CName, CPropVarPtr)] !PProp !*CHeaps -> (!CProp ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindVariablesP evars pvars PTrue heaps
	= (CTrue, heaps)
bindVariablesP evars pvars PFalse heaps
	= (CFalse, heaps)
bindVariablesP evars pvars (PPropVar name) heaps
	# mb_ptr						= find name pvars
	| isNothing mb_ptr				= abort "Impossible case reached in bindVariablesP."	// impossible; addQuantors should have been executed
	= (CPropVar (fromJust mb_ptr), heaps)
bindVariablesP evars pvars (PEqual e1 e2) heaps
	#! (e1, heaps)					= bindVariablesE evars pvars e1 heaps
	#! (e2, heaps)					= bindVariablesE evars pvars e2 heaps
	= (CEqual e1 e2, heaps)
bindVariablesP evars pvars (PNot p) heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	= (CNot p, heaps)
bindVariablesP evars pvars (PAnd p q) heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	#! (q, heaps)					= bindVariablesP evars pvars q heaps
	= (CAnd p q, heaps)
bindVariablesP evars pvars (POr p q) heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	#! (q, heaps)					= bindVariablesP evars pvars q heaps
	= (COr p q, heaps)
bindVariablesP evars pvars (PImplies p q) heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	#! (q, heaps)					= bindVariablesP evars pvars q heaps
	= (CImplies p q, heaps)
bindVariablesP evars pvars (PIff p q) heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	#! (q, heaps)					= bindVariablesP evars pvars q heaps
	= (CIff p q, heaps)
bindVariablesP evars pvars (PExprForall name mb_type p) heaps
	# (ptrs, evars, heaps)			= bindExprVars [name] evars heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	= (CExprForall (hd ptrs) p, heaps)
bindVariablesP evars pvars (PExprExists name mb_type p) heaps
	# (ptrs, evars, heaps)			= bindExprVars [name] evars heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	= (CExprExists (hd ptrs) p, heaps)
bindVariablesP evars pvars (PPropForall name p) heaps
	# (ptrs, pvars, heaps)			= bindPropVars [name] pvars heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	= (CPropForall (hd ptrs) p, heaps)
bindVariablesP evars pvars (PPropExists name p) heaps
	# (ptrs, pvars, heaps)			= bindPropVars [name] pvars heaps
	#! (p, heaps)					= bindVariablesP evars pvars p heaps
	= (CPropExists (hd ptrs) p, heaps)
bindVariablesP evars pvars (PPredicate ptr exprs) heaps
	#! (exprs, heaps)				= bindVariablesL evars pvars exprs heaps
	= (CPredicate ptr exprs, heaps)
bindVariablesP evars pvars (PBracketProp p) heaps
	= bindVariablesP evars pvars p heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
BindVariables :: !PProp !*CHeaps -> (!CProp ParsedPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindVariables prop heaps
	# (enames, _, pnames)			= FreeVars prop
	# (evars, heaps)				= newPointers [{DummyValue & evarName = name} \\ name <- enames] heaps
	# (pvars, heaps)				= newPointers [{DummyValue & pvarName = name} \\ name <- pnames] heaps
	# (prop, heaps)					= bindVariablesP (zip2 enames evars) (zip2 pnames pvars) prop heaps
	# prop							= introduce_foralls pvars evars prop
	= (prop, heaps)
	where
		introduce_foralls :: ![CPropVarPtr] ![CExprVarPtr] !(CProp a) -> CProp a
		introduce_foralls [pvar:pvars] evars prop
			= CPropForall pvar (introduce_foralls pvars evars prop)
		introduce_foralls [] [evar:evars] prop
			= CExprForall evar (introduce_foralls [] evars prop)
		introduce_foralls [] [] prop
			= prop
































// -------------------------------------------------------------------------------------------------------------------------------------------------
typeBasicValue :: !(CBasicValue a) -> (!Bool, !CBasicType)
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeBasicValue (CBasicInteger _)		= (True, CInteger)
typeBasicValue (CBasicCharacter _)		= (True, CCharacter)
typeBasicValue (CBasicRealNumber _)		= (True, CRealNumber)
typeBasicValue (CBasicBoolean _)		= (True, CBoolean) 
typeBasicValue (CBasicString _)			= (True, CString)
typeBasicValue other					= (False, DummyValue)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases [a] | typeCases a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases [] prj
		= (OK, [], prj)
	typeCases [x:xs] prj
		#! (error, x, prj)			= typeCases x prj
		| isError error				= (error, DummyValue, prj)
		#! (error, xs, prj)			= typeCases xs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, [x:xs], prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (Maybe a) | typeCases a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases Nothing prj
		= (OK, Nothing, prj)
	typeCases (Just x) prj
		#! (error, x, prj)			= typeCases x prj
		| isError error				= (error, DummyValue, prj)
		= (OK, Just x, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CAlgPattern ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases pattern prj
		#! (error, expr, prj)		= typeCases pattern.atpResult prj
		| isError error				= (error, DummyValue, prj)
		= (OK, {pattern & atpResult = expr}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CBasicPattern ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases pattern prj
		#! (error, expr, prj)		= typeCases pattern.bapResult prj
		| isError error				= (error, DummyValue, prj)
		= (OK, {pattern & bapResult = expr}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CBasicValue ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases (CBasicArray exprs) prj
		#! (error, exprs, prj)		= typeCases exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CBasicArray exprs, prj)
	typeCases other prj
		= (OK, other, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CCasePatterns ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases (CAlgPatterns type patterns) prj
		#! (error, patterns, prj)	= typeCases patterns prj
		| isError error				= (error, DummyValue, prj)
		# pattern					= hd patterns
		# (ok, ptr)					= getHeapPtr pattern.atpDataCons
		| not ok					= (pushError (X_Type "Unable to type algebraic case.") OK, DummyValue, prj)
		# (error, dataconsdef, prj)	= getDataConsDef ptr prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CAlgPatterns (PHeapPtr dataconsdef.dcdAlgType) patterns, prj)
	typeCases (CBasicPatterns type patterns) prj
		#! (error, patterns, prj)	= typeCases patterns prj
		| isError error				= (error, DummyValue, prj)
		# pattern					= hd patterns
		# (ok, type)				= typeBasicValue pattern.bapBasicValue
		| not ok					= (pushError (X_Type "Unable to type basic case.") OK, DummyValue, prj)
		= (OK, CBasicPatterns type patterns, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CExpr ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases (CExprVar ptr) prj
		= (OK, CExprVar ptr, prj)
	typeCases (CShared ptr) prj
		= (OK, CShared ptr, prj)
	typeCases (expr @# exprs) prj
		#! (error, expr, prj)		= typeCases expr prj
		| isError error				= (error, DummyValue, prj)
		#! (error, exprs, prj)		= typeCases exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, expr @# exprs, prj)
	typeCases (ptr @@# exprs) prj
		#! (error, exprs, prj)		= typeCases exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, ptr @@# exprs, prj)
	typeCases (CLet strict lets expr) prj
		# (vars, exprs)				= unzip lets
		#! (error, exprs, prj)		= typeCases exprs prj
		| isError error				= (error, DummyValue, prj)
		# lets						= zip2 vars exprs
		#! (error, expr, prj)		= typeCases expr prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CLet strict lets expr, prj)
	typeCases (CCase expr patterns def) prj
		#! (error, expr, prj)		= typeCases expr prj
		| isError error				= (error, DummyValue, prj)
		#! (error, patterns, prj)	= typeCases patterns prj
		| isError error				= (error, DummyValue, prj)
		#! (error, def, prj)		= typeCases def prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CCase expr patterns def, prj)
	typeCases (CBasicValue value) prj
		#! (error, value, prj)		= typeCases value prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CBasicValue value, prj)
	typeCases (CCode codetype codecontents) prj
		= (OK, CCode codetype codecontents, prj)
	typeCases CBottom prj
		= (OK, CBottom, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance typeCases (CProp ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	typeCases (CPropVar ptr) prj
		= (OK, CPropVar ptr, prj)
	typeCases CTrue prj
		= (OK, CTrue, prj)
	typeCases CFalse prj
		= (OK, CFalse, prj)
	typeCases (CNot p) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CNot p, prj)
	typeCases (CAnd p q) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= typeCases q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CAnd p q, prj)
	typeCases (COr p q) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= typeCases q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, COr p q, prj)
	typeCases (CImplies p q) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= typeCases q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CImplies p q, prj)
	typeCases (CIff p q) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= typeCases q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CIff p q, prj)
	typeCases (CExprForall var p) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CExprForall var p, prj)
	typeCases (CExprExists var p) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CExprExists var p, prj)
	typeCases (CPropForall var p) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPropForall var p, prj)
	typeCases (CPropExists var p) prj
		#! (error, p, prj)			= typeCases p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPropExists var p, prj)
	typeCases (CEqual e1 e2) prj
		#! (error, e1, prj)			= typeCases e1 prj
		| isError error				= (error, DummyValue, prj)
		#! (error, e2, prj)			= typeCases e2 prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CEqual e1 e2, prj)
	typeCases (CPredicate ptr exprs) prj
		#! (error, exprs, prj)		= typeCases exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPredicate ptr exprs, prj)






















// =================================================================================================================================================
// Binds: - record creation
//        - field selection
// HACK: It will also bind ARRAY selection to the overloaded select member.
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords [a] | bindRecords a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords [x:xs] infos heaps prj
		#! (error, x, heaps, prj)		= bindRecords x infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, xs, heaps, prj)		= bindRecords xs infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, [x:xs], heaps, prj)
	bindRecords [] infos heaps prj
		= (OK, [], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (Maybe a) | bindRecords a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords (Just x) infos heaps prj
		#! (error, x, heaps, prj)		= bindRecords x infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, Just x, heaps, prj)
	bindRecords Nothing infos heaps prj
		= (OK, Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CAlgPattern ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords pattern infos heaps prj
		#! (error, expr, heaps, prj)	= bindRecords pattern.atpResult infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, {pattern & atpResult = expr}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CBasicPattern ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords pattern infos heaps prj
		#! (error, expr, heaps, prj)	= bindRecords pattern.bapResult infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, {pattern & bapResult = expr}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CBasicValue ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords (CBasicArray exprs) infos heaps prj
		#! (error, expr, heaps, prj)	= bindRecords exprs infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CBasicArray exprs, heaps, prj)
	bindRecords other infos heaps prj
		= (OK, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CCasePatterns ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords (CAlgPatterns type patterns) infos heaps prj
		#! (error, patterns, heaps, prj)= bindRecords patterns infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CAlgPatterns type patterns, heaps, prj)
	bindRecords (CBasicPatterns type patterns) infos heaps prj
		#! (error, patterns, heaps, prj)= bindRecords patterns infos heaps prj
		| isError error				= (error, DummyValue, heaps, prj)
		= (OK, CBasicPatterns type patterns, heaps, prj)

// =================================================================================================================================================
// Checks if the first element of the list is a RECORD DENOTATION.
// If so, the pointer to that record is returned.
// Usage: in x.Record.field (called on x.Record, should deliver RecordPtr+x)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordPointer :: ![CExpr ParsedPtr] ![DefinitionInfo] -> (!Maybe HeapPtr, ![CExpr ParsedPtr])
// -------------------------------------------------------------------------------------------------------------------------------------------------
getRecordPointer original=:[(PSelectField quaname) @@# [expr]] infos
	# mb_ptr					= find quaname infos
	| isNothing mb_ptr			= (Nothing, original)
	= (mb_ptr, [expr])
	where
		find :: !PQualifiedName ![DefinitionInfo] -> Maybe HeapPtr
		find quaname [info:infos]
			| quaname.quaName <> info.diName		= find quaname infos
			| isNothing quaname.quaModuleName		= Just info.diPointer
			# mod_name								= fromJust quaname.quaModuleName
			| mod_name <> info.diModuleName			= find quaname infos
			= Just info.diPointer
		find quaname []
			= Nothing
getRecordPointer other infos
	= (Nothing, other)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CExpr ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords (CExprVar ptr) infos heaps prj
		= (OK, CExprVar ptr, heaps, prj)
	bindRecords (CShared ptr) infos heaps prj
		= (OK, CShared ptr, heaps, prj)
	bindRecords (expr @# exprs) infos heaps prj
		#! (error, expr, heaps, prj)	= bindRecords expr infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, exprs, heaps, prj)	= bindRecords exprs infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, expr @# exprs, heaps, prj)
	bindRecords ((PSelectField quaname) @@# exprs) infos heaps prj
		# (mb_recpointer, exprs)		= getRecordPointer exprs infos
		# (mod_ptrs, prj)				= prj!prjModules
		# (error, ptrs, heaps)			= getHeapPtrs mod_ptrs [CRecordField] heaps
		| isError error					= (error, DummyValue, heaps, prj)		
		# (error, infos, heaps, prj)	= uumapError getDefinitionInfo ptrs heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (infos, prj)					= find quaname.quaName mb_recpointer infos prj
		| isEmpty infos					= (pushError (X_Type error_msg1) OK, DummyValue, heaps, prj)
		| (length infos) > 1			= (pushError (X_Type error_msg2) OK, DummyValue, heaps, prj)
		# (error, fielddef, prj)		= getRecordFieldDef (hd infos).diPointer prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, (PHeapPtr fielddef.rfSelectorFun) @@# exprs, heaps, prj)
		where
			error_msg1 => "Unable to find record field '" +++ quaname.quaName +++ "'."
			error_msg2 => "Multiple definitions found for record field '" +++ quaname.quaName +++ "'."
			
			find :: !CName !(Maybe HeapPtr) ![DefinitionInfo] !*CProject -> (![DefinitionInfo], !*CProject)
			find fieldname Nothing [info:infos] prj
				# (infos, prj)						= find fieldname Nothing infos prj
				| info.diName <> fieldname			= (infos, prj)
				= ([info:infos], prj)
			find fieldname (Just recptr) [info:infos] prj
				# (infos, prj)						= find fieldname (Just recptr) infos prj
				| info.diName <> fieldname			= (infos, prj)
				# (error, fielddef, prj)			= getRecordFieldDef info.diPointer prj
				| isError error						= (infos, prj)
				| fielddef.rfRecordType <> recptr	= (infos, prj)
				= ([info:infos], prj)
			find fieldname _ [] prj
				= ([], prj)
	bindRecords (ptr @@# exprs) infos heaps prj
		#! (error, ptr, heaps, prj)		= bindRecords ptr infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, exprs, heaps, prj)	= bindRecords exprs infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, ptr @@# exprs, heaps, prj)
	bindRecords (CLet strict lets expr) infos heaps prj
		# (vars, exprs)					= unzip lets
		#! (error, exprs, heaps, prj)	= bindRecords exprs infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# lets							= zip2 vars exprs
		#! (error, expr, heaps, prj)	= bindRecords expr infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CLet strict lets expr, heaps, prj)
	bindRecords (CCase expr patterns def) infos heaps prj
		#! (error, expr, heaps, prj)	= bindRecords expr infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, patterns, heaps, prj)= bindRecords patterns infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, def, heaps, prj)		= bindRecords def infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CCase expr patterns def, heaps, prj)
	bindRecords (CBasicValue value) infos heaps prj
		#! (error, value, heaps, prj)	= bindRecords value infos heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CBasicValue value, heaps, prj)
	bindRecords (CCode codetype codecontents) infos heaps prj
		= (OK, CCode codetype codecontents, heaps, prj)
	bindRecords CBottom infos heaps prj
		= (OK, CBottom, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords ParsedPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords ptr=:(PBuildRecord mb_name fields) [info:infos] heaps prj
		| isNothing mb_name				= check_fields ptr fields info infos heaps prj
		# name							= fromJust mb_name
		| info.diName <> name.quaName	= bindRecords ptr infos heaps prj
		| isNothing name.quaModuleName	= check_fields ptr fields info infos heaps prj
		# mod_name						= fromJust name.quaModuleName
		| info.diModuleName <> mod_name	= bindRecords ptr infos heaps prj
		= check_fields ptr fields info infos heaps prj
		where
			check_fields :: !ParsedPtr ![CName] !DefinitionInfo ![DefinitionInfo] !*CHeaps !*CProject -> (!Error, !ParsedPtr, !*CHeaps, !*CProject)
			check_fields ptr fields info infos heaps prj
				# (error, rectype, prj)				= getRecordTypeDef info.diPointer prj
				| isError error						= (error, DummyValue, heaps, prj)
				# (error, fieldnames, heaps, prj)	= uumapError getDefinitionName rectype.rtdFields heaps prj
				| isError error						= (error, DummyValue, heaps, prj)
				| same fields fieldnames			= (OK, PHeapPtr rectype.rtdRecordConstructor, heaps, prj)
				= bindRecords ptr infos heaps prj
			
			same :: ![CName] ![CName] -> Bool
			same [name:names] more_names
				# (found, more_names)		= myIsMember name more_names
				| not found					= False
				= same names more_names
			same [] more_names
				= isEmpty more_names
	bindRecords (PBuildRecord mb_name fields) [] heaps prj
		= (pushError (X_Type error_msg) OK, DummyValue, heaps, prj)
		where
			error_msg	=> "Could not find record fitting the fields '" +++ (show_fields fields) +++ "'."
			
			show_fields :: ![CName] -> String
			show_fields [name:names]	= name +++ " " +++ show_fields names
			show_fields []				= ""
	bindRecords PSelectIndex infos heaps prj
		# (mb_select_member, prj)		= prj!prjArraySelectMember
		| isNothing mb_select_member	= (pushError (X_Type "Error. Could not locate select function in StdArray.") OK, DummyValue, heaps, prj)
		= (OK, PHeapPtr (fromJust mb_select_member), heaps, prj)
	bindRecords other infos heaps prj
		= (OK, other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance bindRecords (CProp ParsedPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	bindRecords (CPropVar ptr) infos heaps prj
		= (OK, CPropVar ptr, heaps, prj)
	bindRecords CTrue info heaps prj
		= (OK, CTrue, heaps, prj)
	bindRecords CFalse info heaps prj
		= (OK, CFalse, heaps, prj)
	bindRecords (CNot p) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CNot p, heaps, prj)
	bindRecords (CAnd p q) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, q, heaps, prj)		= bindRecords q info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CAnd p q, heaps, prj)
	bindRecords (COr p q) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, q, heaps, prj)		= bindRecords q info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, COr p q, heaps, prj)
	bindRecords (CImplies p q) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, q, heaps, prj)		= bindRecords q info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CImplies p q, heaps, prj)
	bindRecords (CIff p q) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, q, heaps, prj)		= bindRecords q info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CIff p q, heaps, prj)
	bindRecords (CExprForall var p) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CExprForall var p, heaps, prj)
	bindRecords (CExprExists var p) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CExprExists var p, heaps, prj)
	bindRecords (CPropForall var p) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CPropForall var p, heaps, prj)
	bindRecords (CPropExists var p) info heaps prj
		#! (error, p, heaps, prj)		= bindRecords p info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CPropExists var p, heaps, prj)
	bindRecords (CEqual e1 e2) info heaps prj
		#! (error, e1, heaps, prj)		= bindRecords e1 info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		#! (error, e2, heaps, prj)		= bindRecords e2 info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CEqual e1 e2, heaps, prj)
	bindRecords (CPredicate ptr exprs) info heaps prj
		#! (error, exprs, heaps, prj)	= bindRecords exprs info heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, CPredicate ptr exprs, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
BindRecords :: !a !*CHeaps !*CProject -> (!Error, !a, !*CHeaps, !*CProject) | bindRecords a & DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindRecords term heaps prj
	# (mod_ptrs, prj)				= prj!prjModules
	# (error, ptrs, heaps)			= getHeapPtrs mod_ptrs [CRecordType] heaps
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, infos, heaps, prj)	= uumapError getDefinitionInfo ptrs heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, term, heaps, prj)		= bindRecords term infos heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, term, heaps, prj)





























// -------------------------------------------------------------------------------------------------------------------------------------------------
dummyDictsL :: ![(a b)] !*CHeaps !*CProject -> (![(a b)], !*CHeaps, !*CProject) | dummyDicts a & getHeapPtr b
// -------------------------------------------------------------------------------------------------------------------------------------------------
dummyDictsL [x:xs] heaps prj
	# (x, heaps, prj)				= dummyDicts x heaps prj
	# (xs, heaps, prj)				= dummyDictsL xs heaps prj
	= ([x:xs], heaps, prj)
dummyDictsL [] heaps prj
	= ([], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
dummyDictsM :: !(Maybe (a b)) !*CHeaps !*CProject -> (!(Maybe (a b)), !*CHeaps, !*CProject) | dummyDicts a & getHeapPtr b
// -------------------------------------------------------------------------------------------------------------------------------------------------
dummyDictsM (Just x) heaps prj
	# (x, heaps, prj)				= dummyDicts x heaps prj
	= (Just x, heaps, prj)
dummyDictsM Nothing heaps prj
	= (Nothing, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts pattern heaps prj
		# (result, heaps, prj)		= dummyDicts pattern.atpResult heaps prj
		= ({pattern & atpResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts pattern heaps prj
		# (result, heaps, prj)		= dummyDicts pattern.bapResult heaps prj
		= ({pattern & bapResult = result}, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts (CBasicArray exprs) heaps prj
		# (exprs, heaps, prj)		= dummyDictsL exprs heaps prj
		= (CBasicArray exprs, heaps, prj)
	dummyDicts other heaps prj
		= (other, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts (CAlgPatterns type patterns) heaps prj
		# (patterns, heaps, prj)	= dummyDictsL patterns heaps prj
		= (CAlgPatterns type patterns, heaps, prj)
	dummyDicts (CBasicPatterns type patterns) heaps prj
		# (patterns, heaps, prj)	= dummyDictsL patterns heaps prj
		= (CBasicPatterns type patterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts (CExprVar ptr) heaps prj
		= (CExprVar ptr, heaps, prj)
	dummyDicts (CShared ptr) heaps prj
		= (CShared ptr, heaps, prj)
	// BEZIG -- dit is vast en zeker fout!!!!!!!!!!!!!!
	dummyDicts (ptr @@# exprs) heaps prj
		# (exprs, heaps, prj)		= dummyDictsL exprs heaps prj
		# (ok, heap_ptr)			= getHeapPtr ptr
		| not ok					= (ptr @@# exprs, heaps, prj)
		# (error, type, heaps, prj)	= getSymbolType heap_ptr heaps prj
		| isError error				= (ptr @@# exprs, heaps, prj)
		# (nr_dicts, prj)			= countDictionaries type prj
		// HOPE
//		# nr_args					= length type.sytArguments
//		# nr_non_dicts				= nr_args - nr_dicts
//		# exprs						= drop (length exprs - nr_non_dicts) exprs
		// EPOH
		# bottoms					= repeatn nr_dicts CBottom
		= (ptr @@# (bottoms ++ exprs), heaps, prj)
	dummyDicts (expr @# exprs) heaps prj
		# (expr, heaps, prj)		= dummyDicts expr heaps prj
		# (exprs, heaps, prj)		= dummyDictsL exprs heaps prj
		= (expr @# exprs, heaps, prj)
	dummyDicts (CCase expr patterns def) heaps prj
		# (expr, heaps, prj)		= dummyDicts expr heaps prj
		# (patterns, heaps, prj)	= dummyDicts patterns heaps prj
		# (def, heaps, prj)			= dummyDictsM def heaps prj
		= (CCase expr patterns def, heaps, prj)
	dummyDicts (CLet strict lets expr) heaps prj
		# (vars, exprs)				= unzip lets
		# (exprs, heaps, prj)		= dummyDictsL exprs heaps prj
		# lets						= zip2 vars exprs
		# (expr, heaps, prj)		= dummyDicts expr heaps prj
		= (CLet strict lets expr, heaps, prj)
	dummyDicts (CBasicValue value) heaps prj
		# (value, heaps, prj)		= dummyDicts value heaps prj
		= (CBasicValue value, heaps, prj)
	dummyDicts (CCode codetype codecontents) heaps prj
		= (CCode codetype codecontents, heaps, prj)
	dummyDicts CBottom heaps prj
		= (CBottom, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance dummyDicts CProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	dummyDicts (CPropVar ptr) heaps prj
		= (CPropVar ptr, heaps, prj)
	dummyDicts CTrue heaps prj
		= (CTrue, heaps, prj)
	dummyDicts CFalse heaps prj
		= (CFalse, heaps, prj)
	dummyDicts (CNot p) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		= (CNot p, heaps, prj)
	dummyDicts (CAnd p q) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		# (q, heaps, prj)			= dummyDicts q heaps prj
		= (CAnd p q, heaps, prj)
	dummyDicts (COr p q) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		# (q, heaps, prj)			= dummyDicts q heaps prj
		= (COr p q, heaps, prj)
	dummyDicts (CImplies p q) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		# (q, heaps, prj)			= dummyDicts q heaps prj
		= (CImplies p q, heaps, prj)
	dummyDicts (CIff p q) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		# (q, heaps, prj)			= dummyDicts q heaps prj
		= (CIff p q, heaps, prj)
	dummyDicts (CExprForall var p) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		= (CExprForall var p, heaps, prj)
	dummyDicts (CExprExists var p) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		= (CExprExists var p, heaps, prj)
	dummyDicts (CPropForall var p) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		= (CPropForall var p, heaps, prj)
	dummyDicts (CPropExists var p) heaps prj
		# (p, heaps, prj)			= dummyDicts p heaps prj
		= (CPropExists var p, heaps, prj)
	dummyDicts (CEqual e1 e2) heaps prj
		# (e1, heaps, prj)			= dummyDicts e1 heaps prj
		# (e2, heaps, prj)			= dummyDicts e2 heaps prj
		= (CEqual e1 e2, heaps, prj)
	dummyDicts (CPredicate ptr exprs) heaps prj
		# (exprs, heaps, prj)		= dummyDictsL exprs heaps prj
		= (CPredicate ptr exprs, heaps, prj)




























// -------------------------------------------------------------------------------------------------------------------------------------------------
convertParsedPointer :: !ParsedPtr -> (!Error, !HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertParsedPointer parsed_ptr
	# (ok, heap_ptr)				= getHeapPtr parsed_ptr
	| not ok						= (pushError (X_Internal "Error. Could not convert pointer.") OK, DummyValue)
	= (OK, heap_ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPointerMaybe :: !(Maybe (a ParsedPtr)) !*CProject -> (!Error, !Maybe (a HeapPtr), !*CProject) | convertPointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPointerMaybe (Just x) prj
	#! (error, x, prj)				= convertPointer x prj
	= (error, Just x, prj)
convertPointerMaybe Nothing prj
	= (OK, Nothing, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPointerList :: ![(a ParsedPtr)] !*CProject -> (!Error, ![(a HeapPtr)], !*CProject) | convertPointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
convertPointerList [x:xs] prj
	#! (error, x, prj)				= convertPointer x prj
	| isError error					= (error, [], prj)
	#! (error, xs, prj)				= convertPointerList xs prj
	| isError error					= (error, [], prj)
	= (OK, [x:xs], prj)
convertPointerList [] prj
	= (OK, [], prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer pattern prj
		#! (error, datacons)		= convertParsedPointer pattern.atpDataCons
		| isError error				= (error, DummyValue, prj)
		#! (error, expr, prj)		= convertPointer pattern.atpResult prj
		| isError error				= (error, DummyValue, prj)
		= (OK, {pattern & atpDataCons = datacons, atpResult = expr}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer pattern prj
		#! (error, value, prj)		= convertPointer pattern.bapBasicValue prj
		| isError error				= (error, DummyValue, prj)
		#! (error, expr, prj)		= convertPointer pattern.bapResult prj
		| isError error				= (error, DummyValue, prj)
		= (OK, {pattern & bapBasicValue = value, bapResult = expr}, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer (CBasicInteger num) prj
		= (OK, CBasicInteger num, prj)
	convertPointer (CBasicCharacter char) prj
		= (OK, CBasicCharacter char, prj)
	convertPointer (CBasicRealNumber num) prj
		= (OK, CBasicRealNumber num, prj)
	convertPointer (CBasicBoolean bool) prj
		= (OK, CBasicBoolean bool, prj)
	convertPointer (CBasicString text) prj
		= (OK, CBasicString text, prj)
	convertPointer (CBasicArray exprs) prj
		#! (error, exprs, prj)		= convertPointerList exprs prj
		| isError error				= (error, DummyValue, prj)
		= (error, CBasicArray exprs, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer (CAlgPatterns type patterns) prj
		#! (error, type)			= convertParsedPointer type
		| isError error				= (error, DummyValue, prj)
		#! (error, patterns, prj)	= convertPointerList patterns prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CAlgPatterns type patterns, prj)
	convertPointer (CBasicPatterns basictype patterns) prj
		#! (error, patterns, prj)	= convertPointerList patterns prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CBasicPatterns basictype patterns, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer (CExprVar ptr) prj
		= (OK, CExprVar ptr, prj)
	convertPointer (CShared ptr) prj
		= (OK, CShared ptr, prj)
	convertPointer (expr @# exprs) prj
		#! (error, expr, prj)		= convertPointer expr prj
		| isError error				= (error, DummyValue, prj)
		#! (error, exprs, prj)		= convertPointerList exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, expr @# exprs, prj)
	convertPointer (ptr @@# exprs) prj
		#! (error, ptr)				= convertParsedPointer ptr
		| isError error				= (error, DummyValue, prj)
		#! (error, exprs, prj)		= convertPointerList exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, ptr @@# exprs, prj)
	convertPointer (CLet strict lets expr) prj
		# (vars, exprs)				= unzip lets
		#! (error, exprs, prj)		= convertPointerList exprs prj
		| isError error				= (error, DummyValue, prj)
		# lets						= zip2 vars exprs
		#! (error, expr, prj)		= convertPointer expr prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CLet strict lets expr, prj)
	convertPointer (CCase expr patterns def) prj
		#! (error, expr, prj)		= convertPointer expr prj
		| isError error				= (error, DummyValue, prj)
		#! (error, patterns, prj)	= convertPointer patterns prj
		| isError error				= (error, DummyValue, prj)
		#! (error, def, prj)		= convertPointerMaybe def prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CCase expr patterns def, prj)
	convertPointer (CBasicValue value) prj
		#! (error, value, prj)		= convertPointer value prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CBasicValue value, prj)
	convertPointer (CCode codetype codecontents) prj
		= (OK, CCode codetype codecontents, prj)
	convertPointer CBottom prj
		= (OK, CBottom, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance convertPointer CProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	convertPointer (CPropVar ptr) prj
		= (OK, CPropVar ptr, prj)
	convertPointer CTrue prj
		= (OK, CTrue, prj)
	convertPointer CFalse prj
		= (OK, CFalse, prj)
	convertPointer (CNot p) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CNot p, prj)
	convertPointer (CAnd p q) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= convertPointer q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CAnd p q, prj)
	convertPointer (COr p q) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= convertPointer q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, COr p q, prj)
	convertPointer (CImplies p q) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= convertPointer q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CImplies p q, prj)
	convertPointer (CIff p q) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		#! (error, q, prj)			= convertPointer q prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CIff p q, prj)
	convertPointer (CExprForall var p) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CExprForall var p, prj)
	convertPointer (CExprExists var p) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CExprExists var p, prj)
	convertPointer (CPropForall var p) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPropForall var p, prj)
	convertPointer (CPropExists var p) prj
		#! (error, p, prj)			= convertPointer p prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPropExists var p, prj)
	convertPointer (CEqual e1 e2) prj
		#! (error, e1, prj)			= convertPointer e1 prj
		| isError error				= (error, DummyValue, prj)
		#! (error, e2, prj)			= convertPointer e2 prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CEqual e1 e2, prj)
	convertPointer (CPredicate ptr exprs) prj
		#! (error, ptr)				= convertParsedPointer ptr
		| isError error				= (error, DummyValue, prj)
		#! (error, exprs, prj)		= convertPointerList exprs prj
		| isError error				= (error, DummyValue, prj)
		= (OK, CPredicate ptr exprs, prj)





























// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses [a] | instantiateClasses a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info [x:xs] prj
		# (error, (info, x), prj)			= instantiateClasses info x prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, xs), prj)			= instantiateClasses info xs prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, [x:xs]), prj)
	instantiateClasses info [] prj
		= (OK, (info, []), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (Maybe a) | instantiateClasses a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info (Just x) prj
		# (error, (info, x), prj)			= instantiateClasses info x prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, Just x), prj)
	instantiateClasses info Nothing prj
		= (OK, (info, Nothing), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info pattern prj
		# (error, (info, result), prj)		= instantiateClasses info pattern.atpResult prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, {pattern & atpResult = result}), prj) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info pattern prj
		# (error, (info, result), prj)		= instantiateClasses info pattern.bapResult prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, {pattern & bapResult = result}), prj) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info (CBasicArray exprs) prj
		# (error, (info, exprs), prj)		= instantiateClasses info exprs prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CBasicArray exprs), prj)
	instantiateClasses info value prj
		= (OK, (info, value), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info (CAlgPatterns type patterns) prj
		# (error, (info, patterns), prj)	= instantiateClasses info patterns prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CAlgPatterns type patterns), prj)
	instantiateClasses info (CBasicPatterns type patterns) prj
		# (error, (info, patterns), prj)	= instantiateClasses info patterns prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CBasicPatterns type patterns), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info (CExprVar ptr) prj
		= (OK, (info, CExprVar ptr), prj)
	instantiateClasses info (CShared ptr) prj
		= (OK, (info, CShared ptr), prj)
	instantiateClasses info (expr @# exprs) prj
		# (error, (info, expr), prj)		= instantiateClasses info expr prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, exprs), prj)		= instantiateClasses info exprs prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, expr @# exprs), prj)
	instantiateClasses info (ptr @@# exprs) prj
		# (symboltype, info)				= get_symboltype info
		# (error, (info, exprs), prj)		= instantiateClasses info exprs prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, ptr, nr_dicts, prj)		= instantiateMember ptr symboltype.sytArguments symboltype.sytResult prj
		| isError error						= (error, (info, DummyValue), prj)
		# dicts								= repeatn nr_dicts CBottom
		= (OK, (info, ptr @@# (dicts ++ exprs)), prj)
		where
			get_symboltype info
				= (hd info.tiSymbolTypes, {info & tiSymbolTypes = tl info.tiSymbolTypes})
	instantiateClasses info (CCase expr patterns def) prj
		# (error, (info, expr), prj)		= instantiateClasses info expr prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, patterns), prj)	= instantiateClasses info patterns prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, def), prj)			= instantiateClasses info def prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CCase expr patterns def), prj)
	instantiateClasses info (CLet strict lets expr) prj
		# (vars, exprs)						= unzip lets
		# (error, (info, exprs), prj)		= instantiateClasses info exprs prj
		| isError error						= (error, (info, DummyValue), prj)
		# lets								= zip2 vars exprs
		# (error, (info, expr), prj)		= instantiateClasses info expr prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CLet strict lets expr), prj)
	instantiateClasses info (CBasicValue value) prj
		# (error, (info, value), prj)		= instantiateClasses info value prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CBasicValue value), prj)
	instantiateClasses info (CCode codetype codecontents) prj
		= (OK, (info, CCode codetype codecontents), prj)
	instantiateClasses info CBottom prj
		= (OK, (info, CBottom), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance instantiateClasses (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	instantiateClasses info CTrue prj
		= (OK, (info, CTrue), prj)
	instantiateClasses info CFalse prj
		= (OK, (info, CFalse), prj)
	instantiateClasses info (CPropVar ptr) prj
		= (OK, (info, CPropVar ptr), prj)
	instantiateClasses info (CNot p) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CNot p), prj)
	instantiateClasses info (CAnd p q) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, q), prj)			= instantiateClasses info q prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CAnd p q), prj)
	instantiateClasses info (COr p q) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, q), prj)			= instantiateClasses info q prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, COr p q), prj)
	instantiateClasses info (CImplies p q) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, q), prj)			= instantiateClasses info q prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CImplies p q), prj)
	instantiateClasses info (CIff p q) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, q), prj)			= instantiateClasses info q prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CIff p q), prj)
	instantiateClasses info (CExprForall var p) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CExprForall var p), prj)
	instantiateClasses info (CExprExists var p) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CExprExists var p), prj)
	instantiateClasses info (CPropForall var p) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CPropForall var p), prj)
	instantiateClasses info (CPropExists var p) prj
		# (error, (info, p), prj)			= instantiateClasses info p prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CPropExists var p), prj)
	instantiateClasses info (CEqual e1 e2) prj
		# (error, (info, e1), prj)			= instantiateClasses info e1 prj
		| isError error						= (error, (info, DummyValue), prj)
		# (error, (info, e2), prj)			= instantiateClasses info e2 prj
		| isError error						= (error, (info, DummyValue), prj)
		= (OK, (info, CEqual e1 e2), prj)
	// BEZIG -- werkt nog niet
	instantiateClasses info (CPredicate ptr exprs) prj
		= (OK, (info, CPredicate ptr exprs), prj)


























// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries [a] | createDictionaries a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info [x:xs] heaps prj
		# (error, (info, x), heaps, prj)	= createDictionaries info x heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, xs), heaps, prj)	= createDictionaries info xs heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, [x:xs]), heaps, prj)
	createDictionaries info [] heaps prj
		= (OK, (info, []), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (Maybe a) | createDictionaries a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info (Just x) heaps prj
		# (error, (info, x), heaps, prj)	= createDictionaries info x heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, Just x), heaps, prj)
	createDictionaries info Nothing heaps prj
		= (OK, (info, Nothing), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info pattern heaps prj
		# (error, (info, res), heaps, prj)	= createDictionaries info pattern.atpResult heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, {pattern & atpResult = res}), heaps, prj) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info pattern heaps prj
		# (error, (info, res), heaps, prj)	= createDictionaries info pattern.bapResult heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, {pattern & bapResult = res}), heaps, prj) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info (CBasicArray exprs) heaps prj
		# (error, (info, exprs), heaps, prj)= createDictionaries info exprs heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CBasicArray exprs), heaps, prj)
	createDictionaries info value heaps prj
		= (OK, (info, value), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info (CAlgPatterns type prns) heaps prj
		# (error, (info, prns), heaps, prj)	= createDictionaries info prns heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CAlgPatterns type prns), heaps, prj)
	createDictionaries info (CBasicPatterns type prns) heaps prj
		# (error, (info, prns), heaps, prj)	= createDictionaries info prns heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CBasicPatterns type prns), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info (CExprVar ptr) heaps prj
		= (OK, (info, CExprVar ptr), heaps, prj)
	createDictionaries info (CShared ptr) heaps prj
		= (OK, (info, CShared ptr), heaps, prj)
	createDictionaries info (expr @# exprs) heaps prj
		# (error, (info, expr), heaps, prj)	= createDictionaries info expr heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, exprs), heaps, prj)= createDictionaries info exprs heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, expr @# exprs), heaps, prj)
	createDictionaries info (ptr @@# exprs) heaps prj
		# (symboltype, info)				= get_symboltype info
		# (error, (info, exprs), heaps, prj)= createDictionaries info exprs heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, exprs, heaps, prj)		= new_dicts exprs symboltype.sytArguments heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, ptr @@# exprs), heaps, prj)
		where
			get_symboltype info
				= (hd info.tiSymbolTypes, {info & tiSymbolTypes = tl info.tiSymbolTypes})
			
			new_dicts :: ![CExprH] ![CTypeH] !*CHeaps !*CProject -> (!Error, ![CExprH], !*CHeaps, !*CProject)
			new_dicts [] [] heaps prj
				= (OK, [], heaps, prj)
			new_dicts [expr:exprs] [ptr @@^ args: types] heaps prj
				# (error, exprs, heaps, prj)	= new_dicts exprs types heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				| ptrKind ptr <> CRecordType	= (OK, [expr:exprs], heaps, prj)
				# (error, rectype, prj)			= getRecordTypeDef ptr prj
				| isError error					= (error, DummyValue, heaps, prj)
				| not rectype.rtdIsDictionary	= (OK, [expr:exprs], heaps, prj)
				# (error, expr, heaps, prj)		= createDictionary ptr args heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, [expr:exprs], heaps, prj)
			new_dicts [expr:exprs] [type:types] heaps prj
				# (error, exprs, heaps, prj)	= new_dicts exprs types heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, [expr:exprs], heaps, prj)
	createDictionaries info (CCase expr prns def) heaps prj
		# (error, (info, expr), heaps, prj)	= createDictionaries info expr heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, prns), heaps, prj)	= createDictionaries info prns heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, def), heaps, prj)	= createDictionaries info def heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CCase expr prns def), heaps, prj)
	createDictionaries info (CLet strict lets expr) heaps prj
		# (vars, exprs)						= unzip lets
		# (error, (info, exprs), heaps, prj)= createDictionaries info exprs heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# lets								= zip2 vars exprs
		# (error, (info, expr), heaps, prj)	= createDictionaries info expr heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CLet strict lets expr), heaps, prj)
	createDictionaries info (CBasicValue value) heaps prj
		# (error, (info, value), heaps, prj)= createDictionaries info value heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CBasicValue value), heaps, prj)
	createDictionaries info (CCode codetype codecontents) heaps prj
		= (OK, (info, CCode codetype codecontents), heaps, prj)
	createDictionaries info CBottom heaps prj
		= (OK, (info, CBottom), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance createDictionaries (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	createDictionaries info CTrue heaps prj
		= (OK, (info, CTrue), heaps, prj)
	createDictionaries info CFalse heaps prj
		= (OK, (info, CFalse), heaps, prj)
	createDictionaries info (CPropVar ptr) heaps prj
		= (OK, (info, CPropVar ptr), heaps, prj)
	createDictionaries info (CNot p) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CNot p), heaps, prj)
	createDictionaries info (CAnd p q) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, q), heaps, prj)	= createDictionaries info q heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CAnd p q), heaps, prj)
	createDictionaries info (COr p q) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, q), heaps, prj)	= createDictionaries info q heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, COr p q), heaps, prj)
	createDictionaries info (CImplies p q) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, q), heaps, prj)	= createDictionaries info q heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CImplies p q), heaps, prj)
	createDictionaries info (CIff p q) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, q), heaps, prj)	= createDictionaries info q heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CIff p q), heaps, prj)
	createDictionaries info (CExprForall var p) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CExprForall var p), heaps, prj)
	createDictionaries info (CExprExists var p) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CExprExists var p), heaps, prj)
	createDictionaries info (CPropForall var p) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CPropForall var p), heaps, prj)
	createDictionaries info (CPropExists var p) heaps prj
		# (error, (info, p), heaps, prj)	= createDictionaries info p heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CPropExists var p), heaps, prj)
	createDictionaries info (CEqual e1 e2) heaps prj
		# (error, (info, e1), heaps, prj)	= createDictionaries info e1 heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		# (error, (info, e2), heaps, prj)	= createDictionaries info e2 heaps prj
		| isError error						= (error, (info, DummyValue), heaps, prj)
		= (OK, (info, CEqual e1 e2), heaps, prj)
	createDictionaries info (CPredicate ptr es) heaps prj
		= (OK, (info, CPredicate ptr es), heaps, prj)



















// =================================================================================================================================================
// Case 1: class has no members, only restrictions
// Case 2: class has no restrictions, only members
// In case 1, there will never exist an instance.
// In case 2, the restrictions will always be stored at the members.
// -------------------------------------------------------------------------------------------------------------------------------------------------
createDictionary :: !HeapPtr ![CTypeH] !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createDictionary recptr types heaps prj
	| not (and (map type_ok types))			= (pushError (X_Internal ("Can not create a dictionary, because overloading was not solved.")) OK, DummyValue, heaps, prj)
	# (error, rectype, prj)					= getRecordTypeDef recptr prj
	| isError error							= (error, DummyValue, heaps, prj)
	| not rectype.rtdIsDictionary			= (pushError (X_Internal ("Expected a dictionary, got '" +++ rectype.rtdName +++ "'")) OK, DummyValue, heaps, prj)
	# classptr								= rectype.rtdClassDef
	# (error, classdef, prj)				= getClassDef classptr prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isEmpty classdef.cldMembers			= createCompoundDictionary rectype.rtdRecordConstructor classdef types heaps prj
	= createInstanceDictionary rectype.rtdRecordConstructor classdef types heaps prj
	where
		type_ok :: !CTypeH -> Bool
		type_ok (CStrict type)		= type_ok type
		type_ok (CBasicType _)		= True
		type_ok (type @^ types)		= (type_ok type) && (and (map type_ok types))
		type_ok (ptr @@^ types)		= and (map type_ok types)
		type_ok types				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
createCompoundDictionary :: !HeapPtr !CClassDefH ![CTypeH] !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createCompoundDictionary makedict classdef types heaps prj
	# sub									= {DummyValue & subTypeVars = zip2 classdef.cldTypeVarScope types}
	# (error, fields, heaps, prj)			= uumapError (createRestrictionField sub) classdef.cldClassRestrictions heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, makedict @@# fields, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
createInstanceDictionary :: !HeapPtr !CClassDefH ![CTypeH] !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createInstanceDictionary makedict classdef types heaps prj
	# (error, sub, indef, prj)				= findInstance classdef.cldName classdef.cldInstances types prj
	| isError error							= (error, DummyValue, heaps, prj)
	# members								= indef.indMemberFunctions
	# (error, fields, heaps, prj)			= uumapError (createMemberField types sub indef classdef) members heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, makedict @@# fields, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
createRestrictionField :: !Substitution !CClassRestrictionH !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createRestrictionField sub restr heaps prj
	# (error, classdef, prj)				= getClassDef restr.ccrClass prj
	| isError error							= (error, DummyValue, heaps, prj)
	# types									= map (SimpleSubst sub) restr.ccrTypes
	= createDictionary classdef.cldDictionary types heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
createMemberField :: ![CTypeH] !Substitution !CInstanceDefH !CClassDefH !HeapPtr !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createMemberField types sub indef classdef funptr heaps prj
	# (error, fundef, prj)					= getFunDef funptr prj
	| isError error							= (error, DummyValue, heaps, prj)
	# instance_vars							= indef.indTypeVarScope
	# (instance_var_names, heaps)			= getPointerNames instance_vars heaps
//	# heaps									= heaps --->> instance_var_names
	# (fun_var_ptrs, heaps)					= findNamedPointers instance_var_names fundef.fdSymbolType.sytTypeVarScope heaps
	# subst_to_inst							= {DummyValue & subTypeVars = zip2 fun_var_ptrs (map CTypeVar instance_vars)}
	# funargs								= SimpleSubst subst_to_inst fundef.fdSymbolType.sytArguments
	# funargs								= SimpleSubst sub funargs
	# (error, expr_args, heaps, prj)		= create_dicts funargs heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, funptr @@# expr_args, heaps, prj)
	where
		create_dicts :: ![CTypeH] !*CHeaps !*CProject -> (!Error, ![CExprH], !*CHeaps, !*CProject)
		create_dicts [ptr @@^ args: types] heaps prj
			| ptrKind ptr <> CRecordType	= (OK, [], heaps, prj)
			# (error, rectype, prj)			= getRecordTypeDef ptr prj
			| isError error					= (error, DummyValue, heaps, prj)
			| not rectype.rtdIsDictionary	= (OK, [], heaps, prj)
			# (error, expr, heaps, prj)		= createDictionary ptr args heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			# (error, exprs, heaps, prj)	= create_dicts types heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			= (OK, [expr:exprs], heaps, prj)
		create_dicts [CStrict type: types] heaps prj
			= create_dicts [type:types] heaps prj
		create_dicts other heaps prj
			= (OK, [], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
findInstance :: !CName ![HeapPtr] ![CTypeH] !*CProject -> (!Error, !Substitution, !CInstanceDefH, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findInstance name ptrs types prj
	# (error, indefs, prj)					= umapError getInstanceDef ptrs prj
	| isError error							= (error, DummyValue, DummyValue, prj)
	= find_instance name (sort indefs) types prj
	where
		find_instance :: !CName ![CInstanceDefH] ![CTypeH] !*CProject -> (!Error, !Substitution, !CInstanceDefH, !*CProject)
		find_instance name [indef:indefs] types prj
			# (ok, unification)				= unify indef.indClassArguments types
			# sub							= {DummyValue & subTypeVars = unification}
			| ok							= (OK, sub, indef, prj)
			= find_instance name indefs types prj
		find_instance name [] types prj
			= (pushError (X_Type ("No proper instance available of '" +++ name +++ "'.")) OK, DummyValue, DummyValue, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
findMember :: !CName !CInstanceDefH !*CProject -> (!Error, !(!HeapPtr, !CFunDefH), !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findMember name indef prj
	= find name indef.indMemberFunctions prj
	where
		find :: !CName ![HeapPtr] !*CProject -> (!Error, !(!HeapPtr, !CFunDefH), !*CProject)
		find name [ptr:ptrs] prj
			# (error, fundef, prj)			= getFunDef ptr prj
			| isError error					= (error, DummyValue, prj)
			| fundef.fdOldName == name		= (OK, (ptr, fundef), prj)
			= find name ptrs prj
		find name [] prj
			= (pushError (X_Internal "Impossible case reached; findMember failed.") OK, DummyValue, prj)

// =================================================================================================================================================
// Input is a member of a class, together with a specific type.
// Output should be the corresponding member of the correct INSTANCE.
// Also gives the number of dictionary arguments as output.
// -------------------------------------------------------------------------------------------------------------------------------------------------
instantiateMember :: !HeapPtr ![CTypeH] !CTypeH !*CProject -> (!Error, !HeapPtr, !Int, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
instantiateMember ptr funargs funresult prj
	| ptrKind ptr <> CMember				= (OK, ptr, 0, prj)
	// HOPE
//	| not (and (map type_ok funargs))		= (pushError (X_Internal "Could not solve overloading.") OK, DummyValue, DummyValue, prj)
//	| not (type_ok funresult)				= (pushError (X_Internal "Could not solve overloading.") OK, DummyValue, DummyValue, prj)
	// EPOH
	# (error, memberdef, prj)				= getMemberDef ptr prj
	| isError error							= (error, DummyValue, DummyValue, prj)
	# (error, classdef, prj)				= getClassDef memberdef.mbdClass prj
	| isError error							= (error, DummyValue, DummyValue, prj)
	# (error, indefs, prj)					= umapError getInstanceDef classdef.cldInstances prj
	| isError error							= (error, DummyValue, DummyValue, prj)
	# (error, candidates, prj)				= umapError (findMember memberdef.mbdName) (sort indefs) prj
	| isError error							= (error, DummyValue, DummyValue, prj)
	# forbidden_vars						= get_vars [funresult:funargs]
	# (mb_funptr, nr_dicts, prj)			= find_candidate forbidden_vars candidates (make_arrow_type funargs funresult) prj
	| isNothing mb_funptr					= (pushError (X_Internal "No suitable instance found.") OK, DummyValue, DummyValue, prj)
	= (OK, fromJust mb_funptr, nr_dicts, prj)
	where
		type_ok :: !CTypeH -> Bool
		type_ok (CStrict type)				= type_ok type
		type_ok (CBasicType _)				= True
		type_ok (type @^ types)				= (type_ok type) && (and (map type_ok types))
		type_ok (ptr @@^ types)				= and (map type_ok types)
		type_ok (type1 ==> type2)			= type_ok type1 && type_ok type2
		type_ok types						= False
		
		find_candidate :: ![CTypeVarPtr] ![(HeapPtr, CFunDefH)] !CTypeH !*CProject -> (!Maybe HeapPtr, !Int, !*CProject)
		find_candidate forbidden_vars [(ptr,fun):candidates] funtype prj
			# (normal_args, nr_dicts, prj)	= drop_dicts fun.fdSymbolType.sytArguments prj
			# (ok1, sub)					= unify (make_arrow_type normal_args fun.fdSymbolType.sytResult) funtype
			# ok2							= is_valid_sub sub forbidden_vars
			| ok1 && ok2					= (Just ptr, nr_dicts, prj)
			= find_candidate forbidden_vars candidates funtype prj
		find_candidate _ [] funtype prj
			= (Nothing, 0, prj)
		
		make_arrow_type :: ![CTypeH] !CTypeH -> CTypeH
		make_arrow_type [type:types] result
			= type ==> (make_arrow_type types result)
		make_arrow_type [] result
			= result
		
		drop_dicts :: ![CTypeH] !*CProject -> (![CTypeH], !Int, !*CProject)
		drop_dicts [type:types] prj
			# (is_dict, prj)				= isDictionary type prj
			# (types, nr_dicts, prj)		= drop_dicts types prj
			= case is_dict of
				True	-> (types, nr_dicts+1, prj)
				False	-> ([type:types], nr_dicts, prj)
		drop_dicts [] prj
			= ([], 0, prj)
		
		get_vars :: ![CTypeH] -> [CTypeVarPtr]
		get_vars [CTypeVar ptr: types]
			= [ptr: get_vars types]
		get_vars [type1 ==> type2: types]
			= get_vars [type1,type2: types]
		get_vars [ptr @@^ types: more_types]
			= get_vars (types ++ more_types)
		get_vars [type @^ types: more_types]
			= get_vars [type:(types ++ more_types)]
		get_vars [CBasicType _: types]
			= get_vars types
		get_vars [CStrict type: types]
			= get_vars [type:types]
		get_vars [CUnTypable: types]
			= get_vars types
		get_vars []
			= []
		
		is_valid_sub :: ![(CTypeVarPtr, CTypeH)] ![CTypeVarPtr] -> Bool
		is_valid_sub [(ptr,_):sub] ptrs
			| isMember ptr ptrs				= False
			= is_valid_sub sub ptrs
		is_valid_sub [] ptrs
			= True





















// -------------------------------------------------------------------------------------------------------------------------------------------------
BindVarTypes :: ![(CName, PType)] !*CHeaps !*CProject -> (![(CName, CTypeH)], !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindVarTypes var_types heaps prj
	# (mod_ptrs, prj)						= prj!prjModules
	# mod_ptrs								= [nilPtr: mod_ptrs]
	# (_, ptrs, heaps)						= getHeapPtrs mod_ptrs [CAlgType] heaps
	# (_, infos1, heaps, prj)				= uumapError getDefinitionInfo ptrs heaps prj
	# (error, ptrs, heaps)					= getHeapPtrs mod_ptrs [CRecordType] heaps
	# (_, infos2, heaps, prj)				= uumapError getDefinitionInfo ptrs heaps prj
	# infos									= infos1 ++ infos2
	= bind var_types infos heaps prj
	where
		bind [(name,type):var_types] infos heaps prj
			# (type, heaps)					= BindType type infos heaps
			# (var_types, heaps, prj)		= bind var_types infos heaps prj
			= ([(name,type):var_types], heaps, prj)
		bind [] infos heaps prj
			= ([], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
BindType :: !PType ![DefinitionInfo] !*CHeaps -> (!CTypeH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
BindType type infos heaps
	# (vars_found, type)					= bind_ptrs type infos
	# vars_found							= removeDup vars_found
	# (var_ptrs, heaps)						= umap allocate_var vars_found heaps
	= (convert vars_found var_ptrs type, heaps)
	where
		bind_ptrs :: !PType ![DefinitionInfo] -> (![CName], !PType)
		bind_ptrs (PArrow type1 type2) infos
			# (names1, type1)				= bind_ptrs type1 infos
			# (names2, type2)				= bind_ptrs type2 infos
			= (names1 ++ names2, PArrow type1 type2)
		bind_ptrs (PTApp (PNamedPtr quaname) types) infos
			# (names, types)				= bind_more_ptrs types infos
			# name							= quaname.quaName
			= case find name infos of
				Just ptr	-> (names, PTApp (PHeapPtr ptr) types)
				Nothing		-> ([name:names], PTypeVar name)
			where
				find :: !CName ![DefinitionInfo] -> Maybe HeapPtr
				find name [info:infos]
					| info.diName == name	= Just info.diPointer
					= find name infos
				find name []
					= Nothing
		bind_ptrs (PTApp (PHeapPtr ptr) types) infos
			# (names, types)				= bind_more_ptrs types infos
			= (names, PTApp (PHeapPtr ptr) types)
		bind_ptrs (PBasic basic) infos
			= ([], PBasic basic)
		
		bind_more_ptrs :: ![PType] ![DefinitionInfo] -> (![CName], ![PType])
		bind_more_ptrs [type:types] infos
			# (names1, type)				= bind_ptrs type infos
			# (names2, types)				= bind_more_ptrs types infos
			= (names1 ++ names2, [type:types])
		bind_more_ptrs [] infos
			= ([], [])
		
		allocate_var :: !CName !*CHeaps -> (!CTypeVarPtr, !*CHeaps)
		allocate_var name heaps
			# var							= {DummyValue & tvarName = name}
			= newPointer var heaps
		
		convert :: ![CName] ![CTypeVarPtr] !PType -> CTypeH
		convert names ptrs (PTypeVar name)
			= find name names ptrs
			where
				find :: !CName ![CName] ![CTypeVarPtr] -> CTypeH
				find name1 [name2:names] [ptr:ptrs]
					| name1 == name2		= CTypeVar ptr
					= find name1 names ptrs
				find name1 [] []
					= CUnTypable
		convert names ptrs (PArrow type1 type2)
			= (convert names ptrs type1) ==> (convert names ptrs type2)
		convert names ptrs (PTApp (PHeapPtr ptr) types)
			# types							= map (convert names ptrs) types
			= ptr @@^ types
		convert names ptrs (PBasic basic)
			= CBasicType basic

// -------------------------------------------------------------------------------------------------------------------------------------------------
SolveOverloading :: !(Maybe Goal) !CExprH !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
SolveOverloading mb_goal expr heaps prj
	// Phase 0: collect applications
	# expr									= collectApplications expr
	// Phase 1: instantiate classes
	# (error, (info, type), heaps, prj)		= case mb_goal of
												Just goal	-> typeExprInGoal expr goal heaps prj
												Nothing		-> typeExpr expr heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, (info, expr), prj)			= instantiateClasses info expr prj
	| isError error							= (error, DummyValue, heaps, prj)
	// Phase 2: create dictionaries (HOPE)
//	# (expr, prj)							= dummyDicts expr prj
	# (error, (info, type), heaps, prj)		= case mb_goal of
												Just goal	-> typeExprInGoal expr goal heaps prj
												Nothing		-> typeExpr expr heaps prj
	| isError error							= (error, DummyValue, heaps, prj)		
	# (error, (info, expr), heaps, prj)		= createDictionaries info expr heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, expr, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
SolveTypes :: !(Maybe Goal) ![(CName, CTypeH)] !CPropH !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
SolveTypes mb_goal var_types prop heaps prj
	// Phase 0: collect applications
	# prop									= collectApplications prop
	// Phase 1: instantiate classes
	# (error, info, heaps, prj)				= case mb_goal of
												Just goal	-> typePropInGoal prop goal var_types heaps prj
												Nothing		-> typeProp prop var_types heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, (info, prop), prj)			= instantiateClasses info prop prj
	| isError error							= (error, DummyValue, heaps, prj)
	// Phase 2: create dictionaries (HOPE)
//	# (prop, prj)							= dummyDicts prop prj
	# (error, info, heaps, prj)				= case mb_goal of
												Just goal	-> typePropInGoal prop goal var_types heaps prj
												Nothing		-> typeProp prop var_types heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, (info, prop), heaps, prj)		= createDictionaries info prop heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, prop, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExpr :: ![CName] !PExpr !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExpr extra_vars expr heaps prj
	# expr							= markDefinedVariables expr extra_vars
	# (error, expr, heaps, prj)		= BindQualifiedNames expr heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# expr							= findInfix expr
	# (evars, var_types, pvars)		= FreeVars expr
	| not (isEmpty evars)			= (pushError (X_Internal ("A free variable was found. (" +++ hd evars +++ ")")) OK, DummyValue, heaps, prj)
	# expr							= collectApplications expr
	# (error, expr, heaps, prj)		= arrangeBrackets expr heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (expr, heaps)					= bindVariablesE [] [] expr heaps
	# (error, expr, prj)			= typeCases expr prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (expr, heaps, prj)			= dummyDicts expr heaps prj
	# (error, expr, heaps, prj)		= BindRecords expr heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, expr, prj)			= convertPointer expr prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, expr, heaps, prj)		= SolveOverloading Nothing expr heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, expr, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildExpr :: !String !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildExpr text heaps prj
	# (error, lexemes)				= parseLexemes text
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, expr)					= parseExpression lexemes
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, expr, heaps, prj)		= bindExpr [] expr heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, expr, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProp :: ![CName] !PProp !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProp extra_vars prop heaps prj
	# prop							= markDefinedVariables prop extra_vars
	# (error, prop, heaps, prj)		= BindQualifiedNames prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# prop							= findInfix prop
	# (evars, var_types, pvars)		= FreeVars prop
	# (var_types, heaps, prj)		= BindVarTypes var_types heaps prj
	# prop							= collectApplications prop
	# (error, prop, heaps, prj)		= arrangeBrackets prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (prop, heaps)					= BindVariables prop heaps
	# (error, prop, prj)			= typeCases prop prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (prop, heaps, prj)			= dummyDicts prop heaps prj
	# (error, prop, heaps, prj)		= BindRecords prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, prop, prj)			= convertPointer prop prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, prop, heaps, prj)		= SolveTypes Nothing var_types prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, prop, heaps, prj)

// Without SolveTypes
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProp2 :: ![CName] !PProp !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProp2 extra_vars prop heaps prj
	# prop							= markDefinedVariables prop extra_vars
	# (error, prop, heaps, prj)		= BindQualifiedNames prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# prop							= findInfix prop
	# prop							= collectApplications prop
	# (error, prop, heaps, prj)		= arrangeBrackets prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (prop, heaps)					= BindVariables prop heaps
	# (error, prop, prj)			= typeCases prop prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (prop, heaps, prj)			= dummyDicts prop heaps prj
	# (error, prop, heaps, prj)		= BindRecords prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, prop, prj)			= convertPointer prop prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, prop, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildProp :: !String !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildProp text heaps prj
	# (error, lexemes)				= parseLexemes text
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, prop)					= parseProposition lexemes
	| isError error					= (error, DummyValue, heaps, prj)
	# (error, prop, heaps, prj)		= bindProp [] prop heaps prj
	| isError error					= (error, DummyValue, heaps, prj)
	= (OK, prop, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProofCommand :: !PProofCommand !*PState -> (!Error, !WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindProofCommand P_CmdDebug pstate
	= (OK, CmdDebug, pstate)
bindProofCommand (P_CmdFocus num) pstate
	= (OK, CmdFocusSubgoal num, pstate)
bindProofCommand P_CmdRefresh pstate
	= (OK, CmdRefreshAlways, pstate)
bindProofCommand P_CmdRestartProof pstate
	= (OK, CmdRestartProof, pstate)
bindProofCommand P_CmdShowTypes pstate
	= (OK, CmdShowVariableTypes, pstate)
bindProofCommand (P_CmdTactic ptactic) pstate
	# (opened, pstate)						= isWindowOpened (WinProof nilPtr) False pstate
	| not opened							= (pushError (X_Internal "No proof active. Can not bind command.") OK, DummyValue, pstate)
	# (winfo, pstate)						= get_Window (WinProof nilPtr) pstate
	# ptr									= fromWinProof winfo.wiId
	# (theorem, pstate)						= accHeaps (readPointer ptr) pstate
	# goal									= theorem.thProof.pCurrentGoal
	# (theorems, pstate)					= allTheorems pstate
	# (options, pstate)						= pstate!ls.stOptions
	# (error, tactic, pstate)				= accErrorHeapsProject (bindTactic ptactic goal theorems options) pstate
	= (error, CmdApplyTactic "" tactic, pstate)
	where
		fromWinProof (WinProof ptr)			= ptr
bindProofCommand (P_CmdTactical tactical) pstate
	= (OK, CmdApplyTactical "" tactical, pstate)
bindProofCommand (P_CmdUndo count) pstate
	= (OK, CmdUndoTactics count, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildProofCommand :: !String !*PState -> (!Error, !WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildProofCommand text pstate
	# (error, lexemes)				= parseLexemes text
	| isError error					= (error, DummyValue, pstate)
	# (error, tactic)				= parseProofCommand lexemes
	| isError error					= (error, DummyValue, pstate)
	# (error, tactic, pstate)		= bindProofCommand tactic pstate
	| isError error					= (error, DummyValue, pstate)
	= (OK, tactic, pstate)
















// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVar :: !CName ![CExprVarPtr] !*CHeaps -> (!Bool, !CExprVarPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVar name [ptr:ptrs] heaps
	# (var, heaps)							= readPointer ptr heaps
	| var.evarName == name					= (True, ptr, heaps)
	= bindExprVar name ptrs heaps
bindExprVar name [] heaps
	= (False, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVars2 :: ![CName] ![CExprVarPtr] !*CHeaps -> (!Maybe CName, ![CExprVarPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindExprVars2 [name:names] all_ptrs heaps
	# (ok, ptr, heaps)						= bindExprVar name all_ptrs heaps
	| not ok								= (Just name, [], heaps)
	# (mb_error, ptrs, heaps)				= bindExprVars2 names all_ptrs heaps
	= (mb_error, [ptr:ptrs], heaps)
bindExprVars2 [] all_ptrs heaps
	= (Nothing, [], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindFact :: !String !PFact !Goal ![TheoremPtr] !*CHeaps !*CProject -> (!Error, !UseFact, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindFact tactic (PHypothesisFact name args) goal theorems heaps prj
	# (error, args, heaps, prj)				= uumapError (bindFactArgument tactic goal) args heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, ptr, heaps)					= bindHypothesis tactic name goal.glHypotheses heaps
	| isError error
		# (error2, ptr, heaps)				= bindTheorem tactic name theorems heaps
		| isError error2					= (error, DummyValue, heaps, prj)
		= (OK, TheoremFact ptr args, heaps, prj)
	= (OK, HypothesisFact ptr args, heaps, prj)
bindFact tactic (PTheoremFact name args) goal theorems heaps prj
	# (error, args, heaps, prj)				= uumapError (bindFactArgument tactic goal) args heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, ptr, heaps)					= bindTheorem tactic name theorems heaps
	= (error, TheoremFact ptr args, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindFactArgument :: !CName !Goal !PFactArgument !*CHeaps !*CProject -> (!Error, !UseFactArgument, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindFactArgument name goal PNoArgument heaps prj
	= (OK, NoArgument, heaps, prj)
bindFactArgument name goal (PArgument expr_prop) heaps prj
	# (error, mb_expr, mb_prop, heaps, prj)	= bindRelativeExprOrProp name expr_prop goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= case mb_expr of
		(Just expr)		-> (OK, ExprArgument expr, heaps, prj)
		Nothing			-> (OK, PropArgument (fromJust mb_prop), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindForallExprVar :: !String !CPropH !*CHeaps -> (!Bool, !CExprVarPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindForallExprVar name (CExprForall ptr p) heaps
	# (var, heaps)							= readPointer ptr heaps
	| var.evarName == name					= (True, ptr, heaps)
	= bindForallExprVar name p heaps
bindForallExprVar name (CPropForall ptr p) heaps
	= bindForallExprVar name p heaps
bindForallExprVar name other heaps
	= (False, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindHypothesis :: !CName !CName ![HypothesisPtr] !*CHeaps -> (!Error, !HypothesisPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindHypothesis tactic name [ptr:ptrs] heaps
	# (hyp, heaps)							= readPointer ptr heaps
	| hyp.hypName == name					= (OK, ptr, heaps)
	= bindHypothesis tactic name ptrs heaps
bindHypothesis tactic name [] heaps
	= (pushError (X_ApplyTactic tactic ("Unable to find hypothesis '" +++ name +++ "'.")) OK, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropVar :: !CName ![CPropVarPtr] !*CHeaps -> (!Bool, !CPropVarPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindPropVar name [ptr:ptrs] heaps
	# (var, heaps)							= readPointer ptr heaps
	| var.pvarName == name					= (True, ptr, heaps)
	= bindPropVar name ptrs heaps
bindPropVar name [] heaps
	= (False, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeExpr :: !PExpr !Goal !*CHeaps !*CProject -> (!Error, !CExprH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeExpr expr goal heaps prj
	# (enames, heaps)						= getPointerNames goal.glExprVars heaps
	# (error, prop, heaps, prj)				= bindProp2 enames (PEqual expr PBottom) heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (ok, expr_vars, expr)					= disect prop
	| not ok								= (pushError (X_Internal "Could not bind expression.") OK, DummyValue, heaps, prj)
	# (ok, expr, heaps)						= bind expr_vars goal.glExprVars expr heaps
	| not ok								= (pushError (X_Internal "Could not bind expression; free variables were found.") OK, DummyValue, heaps, prj)
	# (error, expr, heaps, prj)				= SolveOverloading (Just goal) expr heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, expr, heaps, prj)
	where
		disect :: !CPropH -> (!Bool, ![CExprVarPtr], !CExprH)
		disect (CExprForall var p)
			# (ok, vars, e)					= disect p
			= (ok, [var:vars], e)
		disect (CEqual e CBottom)
			= (True, [], e)
		disect other
			= (False, [], CBottom)
		
		bind :: ![CExprVarPtr] ![CExprVarPtr] !CExprH !*CHeaps -> (!Bool, !CExprH, !*CHeaps)
		bind [ptr:ptrs] known_ptrs expr heaps
			# (var, heaps)					= readPointer ptr heaps
			# (ok, known_ptr, heaps)		= bindExprVar var.evarName known_ptrs heaps
			| not ok						= (False, DummyValue, heaps)
			# (expr, heaps)					= SafeSubst {DummyValue & subExprVars = [(ptr,CExprVar known_ptr)]} expr heaps
			= bind ptrs known_ptrs expr heaps
		bind [] _ expr heaps
			= (True, expr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeProp :: !PProp !Goal !*CHeaps !*CProject -> (!Error, !CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeProp prop goal heaps prj
	# (_, var_types, _)						= FreeVars prop
	# (var_types, heaps, prj)				= BindVarTypes var_types heaps prj
	# nr_foralls1							= count_foralls1 prop
	# (enames, heaps)						= getPointerNames goal.glExprVars heaps
	# (error, prop, heaps, prj)				= bindProp2 enames prop heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# nr_foralls2							= count_foralls2 prop
	# (ok, prop, heaps)						= bind (nr_foralls2 - nr_foralls1) prop goal heaps
	| not ok								= (pushError (X_Internal "Could not bind proposition; free variables were found.") OK, DummyValue, heaps, prj)
	# (error, prop, heaps, prj)				= SolveTypes (Just goal) var_types prop heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, prop, heaps, prj)
	where
		count_foralls1 :: !PProp -> Int
		count_foralls1 (PPropForall _ p)	= 1 + count_foralls1 p
		count_foralls1 (PExprForall _ _ p)	= 1 + count_foralls1 p
		count_foralls1 (PBracketProp p)		= count_foralls1 p
		count_foralls1 other				= 0
		
		count_foralls2 :: !CPropH -> Int
		count_foralls2 (CPropForall var p)	= 1 + count_foralls2 p
		count_foralls2 (CExprForall var p)	= 1 + count_foralls2 p
		count_foralls2 other				= 0
		
		bind :: !Int !CPropH !Goal !*CHeaps -> (!Bool, !CPropH, !*CHeaps)
		bind 0 prop goal heaps
			= (True, prop, heaps)
		bind n (CExprForall ptr p) goal heaps
			# (var, heaps)					= readPointer ptr heaps
			# (ok, known_ptr, heaps)		= bindExprVar var.evarName goal.glExprVars heaps
			| not ok						= (False, DummyValue, heaps)
			# (p, heaps)					= SafeSubst {DummyValue & subExprVars = [(ptr,CExprVar known_ptr)]} p heaps
			= bind (n-1) p goal heaps
		bind n (CPropForall ptr p) goal heaps
			# (var, heaps)					= readPointer ptr heaps
			# (ok, known_ptr, heaps)		= bindPropVar var.pvarName goal.glPropVars heaps
			| not ok						= (False, DummyValue, heaps)
			# (p, heaps)					= SafeSubst {DummyValue & subPropVars = [(ptr,CPropVar known_ptr)]} p heaps
			= bind (n-1) p goal heaps
		bind n other goal heaps
			= (False, DummyValue, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeExprOrProp :: !CName !PExprOrProp !Goal !*CHeaps !*CProject -> (!Error, !Maybe CExprH, !Maybe CPropH, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindRelativeExprOrProp tactic (PIdentifier name) goal heaps prj
	# (ok, ptr, heaps)						= bindExprVar name goal.glExprVars heaps
	| ok									= (OK, Just (CExprVar ptr), Nothing, heaps, prj)
	# (ok, ptr, heaps)						= bindPropVar name goal.glPropVars heaps
	| ok									= (OK, Nothing, Just (CPropVar ptr), heaps, prj)
	= (error, Nothing, Nothing, heaps, prj)
	where
		error = [X_ApplyTactic tactic ("Could not find definition of variable '" +++ name +++ "'.")]
bindRelativeExprOrProp tactic (PExpr expr) goal heaps prj
	# (error, expr, heaps, prj)				= bindRelativeExpr expr goal heaps prj
	= (error, (Just expr), Nothing, heaps, prj)
bindRelativeExprOrProp tactic (PProp prop) goal heaps prj
	# (error, prop, heaps, prj)				= bindRelativeProp prop goal heaps prj
	= (error, Nothing, (Just prop), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTactic :: !PTacticId !Goal ![TheoremPtr] !Options !*CHeaps !*CProject -> (!Error, !TacticId, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTactic (PTacticAbsurd name1 name2) goal theorems options heaps prj
	# (error, ptr1, heaps)					= bindHypothesis "Absurd" name1 goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, ptr2, heaps)					= bindHypothesis "Absurd" name2 goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticAbsurd ptr1 ptr2, heaps, prj)
bindTactic (PTacticAbsurdEquality Nothing) goal theorems options heaps prj
	= (OK, TacticAbsurdEquality, heaps, prj)
bindTactic (PTacticAbsurdEquality (Just name)) goal theorems options heaps prj
	# (error, hyp, heaps)					= bindHypothesis "AbsurdEquality" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticAbsurdEqualityH hyp, heaps, prj)
bindTactic (PTacticApply fact Nothing _) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Apply" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticApply fact, heaps, prj)
bindTactic (PTacticApply fact (Just name) mode) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Apply" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, hyp, heaps)					= bindHypothesis "Apply" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticApplyH fact hyp mode, heaps, prj)
bindTactic (PTacticAssume p mode) goal theorems options heaps prj
	# (error, prop, heaps, prj)				= bindRelativeProp p goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticAssume prop mode, heaps, prj)
bindTactic PTacticAxiom goal theorems options heaps prj
	= (OK, TacticAxiom, heaps, prj)
bindTactic (PTacticCase depth (Just num) Nothing _) goal theorems options heaps prj
	= (OK, TacticCase depth num, heaps, prj)
bindTactic (PTacticCase depth Nothing (Just name) mode) goal theorems options heaps prj
	# (error, hyp, heaps)					= bindHypothesis "Case" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticCaseH depth hyp mode, heaps, prj)
bindTactic (PTacticCase depth _ _ mode) goal theorems options heaps prj
	= (pushError (X_Parse "Must supply EITHER number OR hypothesis-name to Case-tactic.") OK, DummyValue, heaps, prj)
bindTactic (PTacticCases expr mode) goal theorems options heaps prj
	# (error, expr, heaps, prj)				= bindRelativeExpr expr goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticCases expr mode, heaps, prj)
bindTactic (PTacticChooseCase Nothing) goal theorems options heaps prj
	= (OK, TacticChooseCase, heaps, prj)
bindTactic (PTacticChooseCase (Just name)) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "ChooseCase" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticChooseCaseH ptr, heaps, prj)
bindTactic (PTacticCompare e1 e2) goal theorems options heaps prj
	# (error, e1, heaps, prj)				= bindRelativeExpr e1 goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, e2, heaps, prj)				= bindRelativeExpr e2 goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticCompare e1 e2, heaps, prj)
bindTactic (PTacticCompareH name mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Compare" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticCompareH ptr mode, heaps, prj)
bindTactic (PTacticContradiction Nothing mode) goal theorems options heaps prj
	= (OK, TacticContradiction mode, heaps, prj)
bindTactic (PTacticContradiction (Just name) _) goal theorems options heaps prj
	# (error, hyp, heaps)					= bindHypothesis "Contradiction" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticContradictionH hyp, heaps, prj)
bindTactic (PTacticCut fact) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Cut" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticCut fact, heaps, prj)
bindTactic PTacticDefinedness goal theorems options heaps prj
	= (OK, TacticDefinedness, heaps, prj)
bindTactic (PTacticDiscard names) goal theorems options heaps prj
	# (error, evars, pvars, hyps, heaps)	= find_names names heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticDiscard evars pvars hyps, heaps, prj)
	where
		find_names :: ![CName] !*CHeaps -> (!Error, ![CExprVarPtr], ![CPropVarPtr], ![HypothesisPtr], !*CHeaps)
		find_names [name:names] heaps
			# (error, evars, pvars, hyps, heaps)
											= find_names names heaps
			| isError error					= (error, DummyValue, DummyValue, DummyValue, heaps)
			# (ok, evar, heaps)				= bindExprVar name goal.glExprVars heaps
			| ok							= (OK, [evar:evars], pvars, hyps, heaps)
			# (ok, pvar, heaps)				= bindPropVar name goal.glPropVars heaps
			| ok							= (OK, evars, [pvar:pvars], hyps, heaps)
			# (error, hyp, heaps)			= bindHypothesis "" name goal.glHypotheses heaps
			| isOK error					= (OK, evars, pvars, [hyp:hyps], heaps)
			= (pushError (X_ApplyTactic "Discard" ("Unable to find definition of '" +++ name +++ "'.")) OK, DummyValue, DummyValue, DummyValue, heaps)
		find_names [] heaps
			= (OK, [], [], [], heaps)
bindTactic (PTacticExact fact) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Exact" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticExact fact, heaps, prj)
bindTactic (PTacticExFalso name) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "ExFalso" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticExFalso ptr, heaps, prj)
bindTactic (PTacticExpandFun name index Nothing _) goal theorems options heaps prj
	= (OK, TacticExpandFun name index, heaps, prj)
bindTactic (PTacticExpandFun name index (Just hyp) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "ExpandFun" hyp goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticExpandFunH name index ptr mode, heaps, prj)
bindTactic (PTacticExtensionality name) goal theorems options heaps prj
	= (OK, TacticExtensionality name, heaps, prj)
bindTactic (PTacticGeneralize expr_prop name) goal theorems options heaps prj
	# (error, mb_expr, mb_prop, heaps, prj)	= bindRelativeExprOrProp "Generalize" expr_prop goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isJust mb_expr						= (OK, TacticGeneralizeE (fromJust mb_expr) name, heaps, prj)
	| isJust mb_prop						= (OK, TacticGeneralizeP (fromJust mb_prop) name, heaps, prj)
	= undef
bindTactic (PTacticInduction name mode) goal theorems options heaps prj
	# (ok, var, heaps)						= bindExprVar name goal.glExprVars heaps
	| ok									= (OK, TacticInduction var mode, heaps, prj)
	# (ok, var, heaps)						= bindForallExprVar name goal.glToProve heaps
	| ok									= (OK, TacticInduction var mode, heaps, prj)
	= (pushError (X_ApplyTactic "Induction" ("Could not find definition of variable '" +++ name +++ "'.")) OK, DummyValue, heaps, prj)
bindTactic (PTacticInjective Nothing _) goal theorems options heaps prj
	= (OK, TacticInjective, heaps, prj)
bindTactic (PTacticInjective (Just name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Injective" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticInjectiveH ptr mode, heaps, prj)
bindTactic (PTacticIntroduce names) goal theorems options heaps prj
	# (names, heaps)						= rectify names goal.glToProve (goal.glNewHypNum, goal.glNewIHNum) goal.glNrIHs heaps
	= (OK, TacticIntroduce names, heaps, prj)
	where
		rectify :: ![CName] !CPropH !(!Int, !Int) !Int !*CHeaps -> (![CName], !*CHeaps)
		rectify ["_":names] (CImplies p q) (hyp_num, ih_num) 0 heaps
			# (names, heaps)				= rectify names q (hyp_num+1, ih_num) 0 heaps
			= (["H" +++ toString hyp_num: names], heaps)
		rectify ["_":names] (CImplies p q) (hyp_num, ih_num) n heaps
			# (names, heaps)				= rectify names q (hyp_num, ih_num+1) (n-1) heaps
			# new_name						= if (ih_num == 1) "IH" ("IH" +++ toString ih_num)
			= ([new_name: names], heaps)
		rectify [name:names] (CImplies p q) (hyp_num, ih_num) n heaps
			# n								= if (n>0) (n-1) n
			# (names, heaps)				= rectify names q (hyp_num, ih_num) n heaps
			= ([name:names], heaps)
		rectify [name:names] (CExprForall ptr p) nums nr_ihs heaps
			# (var, heaps)					= readPointer ptr heaps
			# (names, heaps)				= rectify names p nums nr_ihs heaps
			| name <> "_"					= ([name:names], heaps)
			= ([var.evarName:names], heaps)
		rectify [name:names] (CPropForall ptr p) nums nr_ihs heaps
			# (var, heaps)					= readPointer ptr heaps
			# (names, heaps)				= rectify names p nums nr_ihs heaps
			| name <> "_"					= ([name:names], heaps)
			= ([var.pvarName:names], heaps)
		rectify names other nums nr_ihs heaps
			= (filter (\name -> name <> "_") names, heaps)
bindTactic (PTacticIntArith location Nothing _) goal theorems options heaps prj
	= (OK, TacticIntArith location, heaps, prj)
bindTactic (PTacticIntArith location (Just name) mode) goal theorems options heaps prj
	# (error, hyp, heaps)					= bindHypothesis "IntArith" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticIntArithH location hyp mode, heaps, prj)
bindTactic PTacticIntCompare goal theorems options heaps prj
	= (OK, TacticIntCompare, heaps, prj)
bindTactic PTacticMakeUnique goal theorems options heaps prj
	= (OK, TacticMakeUnique, heaps, prj)
bindTactic (PTacticManualDefinedness names) goal theorems options heaps prj
	# (error, ptrs, heaps)					= bindTheorems "ManualDefinedness" names theorems heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticManualDefinedness ptrs, heaps, prj)
bindTactic (PTacticMoveInCase name index Nothing _) goal theorems options heaps prj
	= (OK, TacticMoveInCase name index, heaps, prj)
bindTactic (PTacticMoveInCase name index (Just hyp_name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "MoveInCase" hyp_name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticMoveInCaseH name index ptr mode, heaps, prj)
bindTactic (PTacticMoveQuantors dir Nothing _) goal theorems options heaps prj
	= (OK, TacticMoveQuantors dir, heaps, prj)
bindTactic (PTacticMoveQuantors dir (Just name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "LiftQuantors" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticMoveQuantorsH dir ptr mode, heaps, prj)
bindTactic (PTacticOpaque qua_name) goal theorems options heaps prj
	# (mb_ptr, heaps, prj)					= BindQualifiedFunction qua_name heaps prj
	= case mb_ptr of
		(Just ptr)	-> (OK, TacticOpaque ptr, heaps, prj)
		Nothing		-> ([X_ApplyTactic "Opaque" ("Unable to find definition of '" +++ qua_name.quaName +++ "'.")], DummyValue, heaps, prj)
bindTactic (PTacticReduce rmode amount loc Nothing var_names _) goal theorems options heaps prj
	# (mb_name, ptrs, heaps)				= bindExprVars2 var_names goal.glExprVars heaps
	= case mb_name of
		(Just name)	-> ([X_ApplyTactic "Reduce" ("Unable to find variable '" +++ name +++ "'.")], DummyValue, heaps, prj)
		Nothing		-> (OK, TacticReduce rmode amount loc ptrs, heaps, prj)
bindTactic (PTacticReduce rmode amount loc (Just name) var_names mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Reduce" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	# (mb_name, ptrs, heaps)				= bindExprVars2 var_names goal.glExprVars heaps
	= case mb_name of
		(Just name)	-> ([X_ApplyTactic "Reduce" ("Unable to find variable '" +++ name +++ "'.")], DummyValue, heaps, prj)
		Nothing		-> (OK, TacticReduceH rmode amount loc ptr ptrs mode, heaps, prj)
bindTactic (PTacticRefineUndefinedness Nothing _) goal theorems options heaps prj
	= (OK, TacticRefineUndefinedness, heaps, prj)
bindTactic (PTacticRefineUndefinedness (Just name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "RefineUndefinedness" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticRefineUndefinednessH ptr mode, heaps, prj)
bindTactic PTacticReflexive goal theorems options heaps prj
	= (OK, TacticReflexive, heaps, prj)
bindTactic (PTacticRemoveCase index Nothing _) goal theorems options heaps prj
	= (OK, TacticRemoveCase index, heaps, prj)
bindTactic (PTacticRemoveCase index (Just name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "RemoveCase" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticRemoveCaseH index ptr mode, heaps, prj)
bindTactic (PTacticRename name1 name2) goal theorems options heaps prj
	# (ok, ptr, heaps)						= bindExprVar name1 goal.glExprVars heaps
	| ok									= (OK, TacticRenameE ptr name2, heaps, prj)
	# (ok, ptr, heaps)						= bindPropVar name1 goal.glPropVars heaps
	| ok									= (OK, TacticRenameP ptr name2, heaps, prj)
	# (error, ptr, heaps)					= bindHypothesis "Rename" name1 goal.glHypotheses heaps
	| isOK error							= (OK, TacticRenameH ptr name2, heaps, prj)
	# error									= [X_ApplyTactic "Rename" ("Could not find definition of '" +++ name1 +++ "'.")]
	= (error, DummyValue, heaps, prj)
bindTactic (PTacticRewrite direction redex fact Nothing _) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Rewrite" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticRewrite direction redex fact, heaps, prj)
bindTactic (PTacticRewrite direction redex fact (Just name) mode) goal theorems options heaps prj
	# (error, fact, heaps, prj)				= bindFact "Rewrite" fact goal theorems heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, ptr, heaps)					= bindHypothesis "Rewrite" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticRewriteH direction redex fact ptr mode, heaps, prj)
bindTactic (PTacticSpecialize name expr_prop mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Specialize" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, mb_expr, mb_prop, heaps, prj)	= bindRelativeExprOrProp "Specialize" expr_prop goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isJust mb_expr						= (OK, TacticSpecializeE ptr (fromJust mb_expr) mode, heaps, prj)
	| isJust mb_prop						= (OK, TacticSpecializeP ptr (fromJust mb_prop) mode, heaps, prj)
	= undef
bindTactic (PTacticSplit Nothing depth mode) goal theorems options heaps prj
	= (OK, TacticSplit depth, heaps, prj)
bindTactic (PTacticSplit (Just name) depth mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Split" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticSplitH ptr depth mode, heaps, prj)
bindTactic (PTacticSplitCase num mode) goal theorems options heaps prj
	= (OK, TacticSplitCase num mode, heaps, prj)
bindTactic (PTacticSplitIff Nothing _) goal theorems options heaps prj
	= (OK, TacticSplitIff, heaps, prj)
bindTactic (PTacticSplitIff (Just name) mode) goal theorems options heaps prj
	# (error, hyp, heaps)					= bindHypothesis "SplitIff" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticSplitIffH hyp mode, heaps, prj)
bindTactic (PTacticSymmetric Nothing _) goal theorems options heaps prj
	= (OK, TacticSymmetric, heaps, prj)
bindTactic (PTacticSymmetric (Just name) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Symmetric" name goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticSymmetricH ptr mode, heaps, prj)
bindTactic (PTacticTransitive expr_prop) goal theorems options heaps prj
	# (error, mb_expr, mb_prop, heaps, prj)	= bindRelativeExprOrProp "Transitive" expr_prop goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isJust mb_expr						= (OK, TacticTransitiveE (fromJust mb_expr), heaps, prj)
	| isJust mb_prop						= (OK, TacticTransitiveP (fromJust mb_prop), heaps, prj)
	= undef
bindTactic (PTacticTransparent qua_name) goal theorems options heaps prj
	# (mb_ptr, heaps, prj)					= BindQualifiedFunction qua_name heaps prj
	= case mb_ptr of
		(Just ptr)	-> (OK, TacticTransparent ptr, heaps, prj)
		Nothing		-> ([X_ApplyTactic "Transparent" ("Unable to find definition of '" +++ qua_name.quaName +++ "'.")], DummyValue, heaps, prj)
bindTactic PTacticTrivial goal theorems options heaps prj
	= (OK, TacticTrivial, heaps, prj)
bindTactic (PTacticUncurry Nothing _) goal theorems options heaps prj
	= (OK, TacticUncurry, heaps, prj)
bindTactic (PTacticUncurry (Just hyp) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Uncurry" hyp goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticUncurryH ptr mode, heaps, prj)
bindTactic (PTacticUnshare mode letl var varl Nothing) goal theorems options heaps prj
	= (OK, TacticUnshare mode letl var varl, heaps, prj)
bindTactic (PTacticUnshare mode letl var varl (Just hyp)) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Unshare" hyp goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticUnshareH mode letl var varl ptr, heaps, prj)
bindTactic (PTacticWitness _ (Just hyp) mode) goal theorems options heaps prj
	# (error, ptr, heaps)					= bindHypothesis "Witness" hyp goal.glHypotheses heaps
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, TacticWitnessH ptr mode, heaps, prj)
bindTactic (PTacticWitness expr_or_prop Nothing _) goal theorems options heaps prj
	# (error, mb_expr, mb_prop, heaps, prj)	= bindRelativeExprOrProp "Witness" expr_or_prop goal heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isJust mb_expr						= (OK, TacticWitnessE (fromJust mb_expr), heaps, prj)
	| isJust mb_prop						= (OK, TacticWitnessP (fromJust mb_prop), heaps, prj)
	= undef

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTheorem :: !CName !CName ![TheoremPtr] !*CHeaps -> (!Error, !TheoremPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTheorem tactic name [ptr:ptrs] heaps
	# (theorem, heaps)						= readPointer ptr heaps
	| theorem.thName == name				= (OK, ptr, heaps)
	= bindTheorem tactic name ptrs heaps
bindTheorem tactic name [] heaps
	= (pushError (X_ApplyTactic tactic ("Could not find theorem with name '" +++ name +++ "'")) OK, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTheorems :: !CName ![CName] ![TheoremPtr] !*CHeaps -> (!Error, ![TheoremPtr], !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bindTheorems tactic [name:names] ptrs heaps
	# (error, ptr, heaps)					= bindTheorem tactic name ptrs heaps
	| isError error							= (error, DummyValue, heaps)
	# (error, ptrs, heaps)					= bindTheorems tactic names ptrs heaps
	= (error, [ptr:ptrs], heaps)
bindTheorems tactic [] ptrs heaps
	= (OK, [], heaps)