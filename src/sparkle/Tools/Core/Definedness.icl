/*
** Program: Clean Prover System
** Module:  Definedness (.icl)
** 
** Author:  Maarten de Mol
** Created: 03 May 2001
*/

implementation module 
	Definedness

import 
	StdEnv,
	StdIO,
	States

// ------------------------------------------------------------------------------------------------------------------------   
selectDefiningArgs :: ![Bool] ![CExprH] -> [CExprH]
// ------------------------------------------------------------------------------------------------------------------------   
selectDefiningArgs [True:bs] [e:es]
	= [e: selectDefiningArgs bs es]
selectDefiningArgs [False:bs] [e:es]
	= selectDefiningArgs bs es
selectDefiningArgs _ _
	= []

// ------------------------------------------------------------------------------------------------------------------------   
getStrictArgs :: ![CTypeH] ![CExprH] -> [CExprH]
// ------------------------------------------------------------------------------------------------------------------------   
getStrictArgs [CStrict type:types] [expr:exprs]
	= [expr:getStrictArgs types exprs]
getStrictArgs [type:types] [expr:exprs]
	= getStrictArgs types exprs
getStrictArgs _ _
	= []








// ------------------------------------------------------------------------------------------------------------------------   
:: Definedness =
// ------------------------------------------------------------------------------------------------------------------------   
	  IsDefined
	| IsUndefined
	| DependsOn		![CExprH]
instance DummyValue Definedness
	where DummyValue = IsUndefined

// ------------------------------------------------------------------------------------------------------------------------   
:: DefinednessEnv =
// ------------------------------------------------------------------------------------------------------------------------   
	{ equations					:: ![(Definedness, Definedness)]
	, defined					:: ![CExprH]
	, undefined					:: ![CExprH]
	, equalities				:: ![(CExprH, CExprH)]
	, remember_equivalences		:: ![(CExprH, [CExprH])]
	}

// ------------------------------------------------------------------------------------------------------------------------   
buildEquations :: ![CPropH] !*CProject -> (![(Definedness, Definedness)], ![(CExprH, [CExprH])], !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
buildEquations [CEqual e1 e2: props] prj
	# (defined1, prj)							= defined e1 prj
	# (defined2, prj)							= defined e2 prj
	# remember1									= remember e1 defined1
	# remember2									= remember e2 defined2
	# (equations, remembered, prj)				= buildEquations props prj
	= ([(defined1, defined2): equations], remember1 ++ remember2 ++ remembered, prj)
	where
		remember :: !CExprH !Definedness -> [(CExprH, [CExprH])]
		remember expr (DependsOn exprs)
			= case exprs == [expr] of
				True							-> []
				False							-> [(expr, exprs)]
		remember expr _
			= []
	
		// Only simplifies E to [E1..En] if (Defined E) <-> (Defined E1) /\ .. /\ (Defined En)
		defined :: !CExprH !*CProject -> (!Definedness, !*CProject)
		defined expr=:(ptr @@# args) prj
			| ptrKind ptr == CDataCons
				# (error, consdef, prj)			= getDataConsDef ptr prj
				| isError error					= (DependsOn [expr], prj)
				| length args<>consdef.dcdArity	= (DependsOn [expr], prj)
				# args							= getStrictArgs consdef.dcdSymbolType.sytArguments args
				= defined_list args prj
			| ptrKind ptr == CFun
				# (error, fundef, prj)			= getFunDef ptr prj
				| isError error					= (DependsOn [expr], prj)
				# (known, defining_selector)	= getDefiningArgs fundef.fdDefinedness
				| not known						= (DependsOn [expr], prj)
				| length args <> fundef.fdArity	= (DependsOn [expr], prj)
				# args							= selectDefiningArgs defining_selector args
				= defined_list args prj
			= (DependsOn [expr], prj)
		defined (CBasicValue value) prj
			= (IsDefined, prj)
		defined CBottom prj
			= (IsUndefined, prj)
		defined expr prj
			= (DependsOn [expr], prj)
		
		defined_list :: ![CExprH] !*CProject -> (!Definedness, !*CProject)
		defined_list [expr:exprs] prj
			# (defined1, prj)					= defined expr prj
			# (defined2, prj)					= defined_list exprs prj
			= case defined1 of
				IsDefined		-> (defined2, prj)
				IsUndefined		-> (IsUndefined, prj)
				DependsOn es1	-> case defined2 of
									IsDefined		-> (defined1, prj)
									IsUndefined		-> (IsUndefined, prj)
									DependsOn es2	-> (DependsOn (removeDup (es1 ++ es2)), prj)
		defined_list [] prj
			= (IsDefined, prj)
buildEquations [CNot (CEqual expr CBottom): props] prj
	= buildEquations [CEqual expr (CBasicValue (CBasicBoolean True)): props] prj
buildEquations [CNot (CEqual CBottom expr): props] prj
	= buildEquations [CEqual expr (CBasicValue (CBasicBoolean True)): props] prj
buildEquations [CNot (CNot p):props] prj
	= buildEquations [p:props] prj
buildEquations [CAnd p q:props] prj
	= buildEquations [p,q:props] prj
buildEquations [_:props] prj
	= buildEquations props prj
buildEquations [] prj
	= ([], [], prj)

// ------------------------------------------------------------------------------------------------------------------------   
initialDefinednessEnv :: !Goal !*CHeaps !*CProject -> (!DefinednessEnv, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
initialDefinednessEnv goal heaps prj
	# (hyps, heaps)								= readPointers goal.glHypotheses heaps
	# props										= [hyp.hypProp \\ hyp <- hyps]
	# props										= add_assumptions goal.glToProve props
	# (equations, remembered, prj)				= buildEquations props prj
	= ({equations = equations, defined = [], undefined = [], equalities = [], remember_equivalences = remembered}, heaps, prj)
	where
		add_assumptions :: !CPropH ![CPropH] -> [CPropH]
		add_assumptions (CExprForall var p) props
			= add_assumptions p props
		add_assumptions (CPropForall var p) props
			= add_assumptions p props
		add_assumptions (CImplies p q) props
			= add_assumptions q [p:props]
		add_assumptions (CNot p) props
			= [p:props]
		add_assumptions other props
			= [CNot other: props]















// ------------------------------------------------------------------------------------------------------------------------   
findDefined :: ![(Definedness, Definedness)] -> (!Bool, ![CExprH], ![(Definedness, Definedness)])
// ------------------------------------------------------------------------------------------------------------------------   
findDefined [(DependsOn exprs,IsDefined): equations]
	= (True, exprs, equations)
findDefined [(IsDefined,DependsOn exprs): equations]
	= (True, exprs, equations)
findDefined [equation: equations]
	# (ok, exprs, equations)					= findDefined equations
	= (ok, exprs, [equation:equations])
findDefined []
	= (False, DummyValue, [])

// Refines E1 to E2 if Defined E1 -> Defined E2 (always returns the old expressions as well)
// @1 indicates whether CBottom was encountered along the way.
// ------------------------------------------------------------------------------------------------------------------------   
refineDefined :: ![CExprH] !*CProject -> (!Bool, [CExprH], !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
refineDefined [old=:(expr @# exprs):olds] prj
	# (bottom, news, prj)						= refineDefined [expr:olds] prj
	= (bottom, [old:news], prj)
refineDefined [old=:(ptr @@# exprs):olds] prj
	# (error, symbol_type, prj)					= get_sym_type ptr prj
	| isError error
		# (bottom, news, prj)					= refineDefined olds prj
		= (bottom, [old:news], prj)
	# exprs										= getStrictArgs symbol_type.sytArguments exprs
	# (bottom, news, prj)						= refineDefined (exprs ++ olds) prj
	= (bottom, [old:news], prj)
	where
		get_sym_type ptr prj
			| ptrKind ptr == CFun
				# (error, fundef, prj)			= getFunDef ptr prj
				= (error, fundef.fdSymbolType, prj)
			| ptrKind ptr == CDataCons
				# (error, consdef, prj)			= getDataConsDef ptr prj
				= (error, consdef.dcdSymbolType, prj)
			= ([X_Internal "Expected a function or data-constructor (refineDefined in module Definedness)"], DummyValue, prj)
refineDefined [old=:(CLet True [(var,e1)] e2):olds] prj
	# (bottom, news, prj)						= refineDefined [e1,e2:olds] prj
	= (bottom, [old:news], prj)
refineDefined [old=:(CLet False lets expr):olds] prj
	# (bottom, news, prj)						= refineDefined [expr:olds] prj
	= (bottom, [old:news], prj)
refineDefined [CBasicValue value:olds] prj
	= refineDefined olds prj
refineDefined [CBottom:_] prj
	= (True, [], prj)
refineDefined [old:olds] prj
	# (bottom, news, prj)						= refineDefined olds prj
	= (bottom, [old:news], prj)
refineDefined [] prj
	= (False, [], prj)

// ------------------------------------------------------------------------------------------------------------------------   
propagateDefined :: ![CExprH] ![(Definedness, Definedness)] -> [(Definedness, Definedness)]
// ------------------------------------------------------------------------------------------------------------------------   
propagateDefined exprs [(defined1, defined2):equations]
	# defined3									= remove exprs defined1
	# defined4									= remove exprs defined2
	# equations									= propagateDefined exprs equations
	= case contradict defined3 defined4 of
		True	-> [(defined1, defined2):equations]
		False	-> [(defined3, defined4):equations]
	where
		remove :: ![CExprH] !Definedness -> Definedness
		remove exprs (DependsOn more_exprs)
			# more_exprs						= removeMembers more_exprs exprs
			| isEmpty more_exprs				= IsDefined
			= DependsOn more_exprs
		remove exprs defined
			= defined
		
		contradict :: !Definedness !Definedness -> Bool
		contradict IsDefined	IsUndefined		= True
		contradict IsUndefined	IsDefined		= True
		contradict _			_				= False
propagateDefined exprs []
	= []













// ------------------------------------------------------------------------------------------------------------------------   
findUndefined :: ![(Definedness, Definedness)] -> (!Bool, !CExprH, ![(Definedness, Definedness)])
// ------------------------------------------------------------------------------------------------------------------------   
findUndefined [(DependsOn [expr],IsUndefined): equations]
	= (True, expr, equations)
findUndefined [(IsUndefined,DependsOn [expr]): equations]
	= (True, expr, equations)
findUndefined [equation: equations]
	# (ok, expr, equations)						= findUndefined equations
	= (ok, expr, [equation:equations])
findUndefined []
	= (False, DummyValue, [])

// ------------------------------------------------------------------------------------------------------------------------   
propagateUndefined :: !CExprH ![(Definedness, Definedness)] -> [(Definedness, Definedness)]
// ------------------------------------------------------------------------------------------------------------------------   
propagateUndefined expr [(defined1, defined2):equations]
	# defined3									= remove expr defined1
	# defined4									= remove expr defined2
	# equations									= propagateUndefined expr equations
	= case contradict defined3 defined4 of
		True	-> [(defined1, defined2):equations]
		False	-> [(defined3, defined4):equations]
	where
		remove :: !CExprH !Definedness -> Definedness
		remove expr (DependsOn exprs)
			| isMember expr exprs				= IsUndefined
			= DependsOn exprs
		remove expr defined
			= defined
		
		contradict :: !Definedness !Definedness -> Bool
		contradict IsDefined	IsUndefined		= True
		contradict IsUndefined	IsDefined		= True
		contradict _			_				= False
propagateUndefined expr []
	= []

















// ------------------------------------------------------------------------------------------------------------------------   
findEquality :: ![(Definedness, Definedness)] -> (!Bool, !CExprH, !CExprH, ![(Definedness, Definedness)])
// ------------------------------------------------------------------------------------------------------------------------   
findEquality [(DependsOn [e1],DependsOn [e2]): equations]
	| e1 == e2									= findEquality equations
	= (True, e1, e2, equations)
findEquality [equation: equations]
	# (ok, e1, e2, equations)					= findEquality equations
	= (ok, e1, e2, [equation:equations])
findEquality []
	= (False, DummyValue, DummyValue, [])

// ------------------------------------------------------------------------------------------------------------------------   
propagateEquality :: !CExprH !CExprH ![(Definedness, Definedness)] -> [(Definedness, Definedness)]
// ------------------------------------------------------------------------------------------------------------------------   
propagateEquality e1 e2 [(defined1, defined2):equations]
	= [(replace e1 e2 defined1, replace e1 e2 defined2):propagateEquality e1 e2 equations]
	where
		replace :: !CExprH !CExprH !Definedness -> Definedness
		replace e1 e2 (DependsOn exprs)
			= DependsOn (removeDup (change e1 e2 exprs))
		replace expr exprs defined
			= defined
		
		change :: !CExprH !CExprH ![CExprH] -> [CExprH]
		change e1 e2 [expr:exprs]
			| e1 == expr						= [e2: exprs]
			= [expr: change e1 e2 exprs]
		change e1 e2 []
			= []
propagateEquality expr exprs []
	= []

// ------------------------------------------------------------------------------------------------------------------------   
propagateEquality2 :: !CExprH !CExprH ![(CExprH, CExprH)] -> [(CExprH, CExprH)]
// ------------------------------------------------------------------------------------------------------------------------   
propagateEquality2 e1 e2 [(f1,f2):equalities]
	# equalities								= propagateEquality2 e1 e2 equalities
	| e1 == f2
		= [(f1,e2):equalities]
		= [(f1,f2):equalities]
propagateEquality2 e1 e2 []
	= []













// ------------------------------------------------------------------------------------------------------------------------   
solveDefinednessEnv :: !DefinednessEnv !*CProject -> (!DefinednessEnv, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
solveDefinednessEnv env prj
	# (ok, exprs, equations)					= findDefined env.equations
	| ok
		# (bottom, exprs, prj)					= refineDefined exprs prj
		| bottom
			# equations							= [(IsDefined, IsUndefined):equations]
			# env								= {env & equations = equations}
			= solveDefinednessEnv env prj
		# defined								= exprs ++ env.defined
		# equations								= propagateDefined exprs equations
		# env									= {env & defined = defined, equations = equations}
		= solveDefinednessEnv env prj
	# (ok, expr, equations)						= findUndefined env.equations
	| ok
		# undefined								= [expr:env.undefined]
		# equations								= propagateUndefined expr equations
		# env									= {env & undefined = undefined, equations = equations}
		= solveDefinednessEnv env prj
	# (ok, e1, e2, equations)					= findEquality env.equations
	| ok
		# equalities							= [(e1,e2): propagateEquality2 e1 e2 env.equalities]
		# equations								= propagateEquality e1 e2 equations
		# env									= {env & equations = equations, equalities = equalities}
		= solveDefinednessEnv env prj
	# (defined, undefined)						= check_equalities env.defined env.undefined env.equalities
	= (addRememberedEquivalences env.remember_equivalences {env & defined = defined, undefined = undefined}, prj)
	where
		check_equalities :: ![CExprH] ![CExprH] ![(CExprH, CExprH)] -> (![CExprH], ![CExprH])
		check_equalities defined undefined [(e1,e2):equalities]
			| isMember e2 defined				= check_equalities [e1:defined] undefined equalities
			| isMember e2 undefined				= check_equalities defined [e1:undefined] equalities
			= check_equalities defined undefined equalities
		check_equalities defined undefined []
			= (defined, undefined)

// ------------------------------------------------------------------------------------------------------------------------   
addRememberedEquivalences :: ![(CExprH, [CExprH])] !DefinednessEnv -> DefinednessEnv
// ------------------------------------------------------------------------------------------------------------------------   
addRememberedEquivalences [(expr,exprs):equivalences] env
	# env										= case (is_defined exprs env) of
													True	-> {env & defined = [expr:env.defined]}
													False	-> env
	# env										= case (is_undefined exprs env) of
													True	-> {env & undefined = [expr:env.undefined]}
													False	-> env
	= addRememberedEquivalences equivalences env
	where
		is_defined :: ![CExprH] !DefinednessEnv -> Bool
		is_defined [expr:exprs] env
			= case isMember expr env.defined of
				True							-> is_defined exprs env
				False							-> False
		is_defined [] env
			= True
		
		is_undefined :: ![CExprH] !DefinednessEnv -> Bool
		is_undefined [expr:exprs] env
			= case isMember expr env.undefined of
				True							-> True
				False							-> is_undefined exprs env
		is_undefined [] env
			= False
addRememberedEquivalences [] env
	= env

/*
// ------------------------------------------------------------------------------------------------------------------------   
findDefinedVars :: !Goal !*CHeaps !*CProject -> (!Bool, ![CExprVarPtr], ![CExprVarPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
findDefinedVars goal heaps prj
	# (env, heaps, prj)							= initialDefinednessEnv goal heaps prj
	# (env, prj)								= solveDefinednessEnv env prj
	= (contradiction env.equations, scan env.defined, scan env.undefined, heaps, prj)
	where
		scan :: ![CExprH] -> [CExprVarPtr]
		scan [CExprVar ptr: exprs]				= [ptr: scan exprs]
		scan [_:exprs]							= scan exprs
		scan []									= []
		
		contradiction :: ![(Definedness,Definedness)] -> Bool
		contradiction [(IsDefined,IsUndefined):_]
			= True
		contradiction [(IsUndefined,IsDefined):_]
			= True
		contradiction [_:equations]
			= contradiction equations
		contradiction []
			= False

// ------------------------------------------------------------------------------------------------------------------------   
findDefinedExprs :: !Goal !*CHeaps !*CProject -> (!Bool, ![CExprH], ![CExprH], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
findDefinedExprs goal heaps prj
	# (env, heaps, prj)							= initialDefinednessEnv goal heaps prj
	# (env, prj)								= solveDefinednessEnv env prj
	= (contradiction env.equations, env.defined, env.undefined, heaps, prj)
	where
		contradiction :: ![(Definedness,Definedness)] -> Bool
		contradiction [(IsDefined,IsUndefined):_]
			= True
		contradiction [(IsUndefined,IsDefined):_]
			= True
		contradiction [_:equations]
			= contradiction equations
		contradiction []
			= False
*/

// ------------------------------------------------------------------------------------------------------------------------   
findDefinednessInfo :: !Goal !*CHeaps !*CProject -> (!Bool, !DefinednessInfo, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
findDefinednessInfo goal heaps prj
	# (env, heaps, prj)							= initialDefinednessEnv goal heaps prj
	# (env, prj)								= solveDefinednessEnv env prj
	# info										=	{ definedExpressions		= env.defined
													, definedVariables			= scan env.defined
													, undefinedExpressions		= env.undefined
													, undefinedVariables		= scan env.undefined
													}
	= (contradiction env.equations, info, heaps, prj)
	where
		scan :: ![CExprH] -> [CExprVarPtr]
		scan [CExprVar ptr: exprs]				= [ptr: scan exprs]
		scan [_:exprs]							= scan exprs
		scan []									= []
		
		contradiction :: ![(Definedness,Definedness)] -> Bool
		contradiction [(IsDefined,IsUndefined):_]
			= True
		contradiction [(IsUndefined,IsDefined):_]
			= True
		contradiction [_:equations]
			= contradiction equations
		contradiction []
			= False














// ------------------------------------------------------------------------------------------------------------------------   
class applyDefinednessInfo a :: !a !DefinednessInfo !*CProject -> (!Definedness, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance applyDefinednessInfo CExprH
// ------------------------------------------------------------------------------------------------------------------------   
where
	applyDefinednessInfo :: !CExprH !DefinednessInfo !*CProject -> (!Definedness, !*CProject)
	applyDefinednessInfo expr=:(ptr @@# args) info prj
		| ptrKind ptr == CDataCons
			# (error, consdef, prj)				= getDataConsDef ptr prj
			| isError error						= (DependsOn [expr], prj)
			| length args <> consdef.dcdArity	= (DependsOn [expr], prj)
			# args								= getStrictArgs consdef.dcdSymbolType.sytArguments args
			= applyDefinednessInfo [args] info prj
		| ptrKind ptr == CFun
			# (error, fundef, prj)				= getFunDef ptr prj
			| isError error						= (DependsOn [expr], prj)
			| length args <> fundef.fdArity		= (DependsOn [expr], prj)
			# (known, defining_selector)		= getDefiningArgs fundef.fdDefinedness
			| not known							= (DependsOn [expr], prj)
			# args								= selectDefiningArgs defining_selector args
			= applyDefinednessInfo [args] info prj
		= (DependsOn [expr], prj)
	applyDefinednessInfo (CBasicValue value) info prj
		= (IsDefined, prj)
	applyDefinednessInfo CBottom info prj
		= (IsUndefined, prj)
	applyDefinednessInfo expr info prj
		| isMember expr info.definedExpressions		= (IsDefined, prj)
		| isMember expr info.undefinedExpressions	= (IsUndefined, prj)
		= (DependsOn [expr], prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance applyDefinednessInfo [a] | applyDefinednessInfo a
// ------------------------------------------------------------------------------------------------------------------------   
where
	applyDefinednessInfo :: ![a] !DefinednessInfo !*CProject -> (!Definedness, !*CProject) | applyDefinednessInfo a
	applyDefinednessInfo [x:xs] info prj
		# (defined1, prj)						= applyDefinednessInfo x info prj
		# (defined2, prj)						= applyDefinednessInfo xs info prj
		= (combine defined1 defined2, prj)
		where
			combine :: !Definedness !Definedness -> Definedness
			combine IsDefined defined
				= defined
			combine defined IsDefined
				= defined
			combine IsUndefined _
				= IsUndefined
			combine _ IsUndefined
				= IsUndefined
			combine (DependsOn exprs1) (DependsOn exprs2)
				= DependsOn (exprs1 ++ exprs2)
	applyDefinednessInfo [] info prj
		= (IsDefined, prj)