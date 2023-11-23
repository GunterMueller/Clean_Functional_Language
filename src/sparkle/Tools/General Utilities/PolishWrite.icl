/*
** Program: Clean Prover System
** Module:  PolishWrite (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 March 2001
*/

implementation module
	PolishWrite

import
	StdEnv,
	StdIO,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
class polishWrite a :: ![HeapPtr] !a !*File !*CHeaps !*CProject -> (!*File, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
bracketWrite :: !String !*File !*CHeaps !*CProject ![*File -> *(*CHeaps -> *(*CProject -> (*File, *CHeaps, *CProject)))] -> (!*File, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
bracketWrite symbol file heaps prj fs
	# file									= fwrites "(" file
	# file									= fwrites symbol file
	# (file, heaps, prj)					= write fs file heaps prj
	# file									= fwrites ")" file
	= (file, heaps, prj)
	where
		write [f:fs] file heaps prj
			# file							= fwrites " " file
			# (file, heaps, prj)			= f file heaps prj
			= write fs file heaps prj
		write [] file heaps prj
			= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
infixWrite :: !String !*File !*CHeaps !*CProject ![*File -> *(*CHeaps -> *(*CProject -> (*File, *CHeaps, *CProject)))] -> (!*File, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
infixWrite symbol file heaps prj [f:fs]
	# file									= fwrites "{" file
	# (file, heaps, prj)					= f file heaps prj
	# file									= fwrites " " file
	# file									= fwrites symbol file
	# (file, heaps, prj)					= write fs file heaps prj
	# file									= fwrites "}" file
	= (file, heaps, prj)
	where
		write [f:fs] file heaps prj
			# file							= fwrites " " file
			# (file, heaps, prj)			= f file heaps prj
			= write fs file heaps prj
		write [] file heaps prj
			= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticWrite :: !TacticMode !String !*File !*CHeaps !*CProject ![*File -> *(*CHeaps -> *(*CProject -> (*File, *CHeaps, *CProject)))] -> (!*File, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticWrite mode symbol file heaps prj fs
	# file									= case mode of
												Implicit	-> file
												Explicit	-> fwrites "Explicit " file
	# file									= fwrites symbol file
	# (file, heaps, prj)					= write fs file heaps prj
	# file									= fwrites "." file
	= (file, heaps, prj)
	where
		write [f:fs] file heaps prj
			# file							= fwrites " " file
			# (file, heaps, prj)			= f file heaps prj
			= write fs file heaps prj
		write [] file heaps prj
			= (file, heaps, prj)















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite {#Char}
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols text file heaps prj
		# file								= fwrites text file
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (Ptr a) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols ptr file heaps prj
		# (name, heaps)						= getPointerName ptr heaps
		# file								= fwrites name file
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite HeapPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols CConsPtr file heaps prj
		# file								= fwrites "-9 _Cons" file
		= (file, heaps, prj)
	polishWrite symbols (CTupleSelectPtr arity index) file heaps prj
		# file								= fwrites "-10" file
		# file								= fwrites " " file
		# file								= fwrites (toString arity) file
		# file								= fwrites " " file
		# file								= fwrites (toString index) file
		= (file, heaps, prj)
	polishWrite symbols ptr file heaps prj
		# (_, name, heaps, prj)				= getDefinitionName ptr heaps prj
		# index								= find 0 symbols ptr
		# file								= fwrites (toString index) file
		# file								= fwrites " " file
		# file								= fwrites name file
		= (file, heaps, prj)
		where
			find :: !Int ![HeapPtr] !HeapPtr -> Int
			find index [ptr:ptrs] the_ptr
				| ptr == the_ptr			= index
				= find (index+1) ptrs the_ptr
			find _ [] _
				= -1

// separate with spaces
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite [a] | polishWrite a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols [x:xs] file heaps prj
		# (file, heaps, prj)				= polishWrite symbols x file heaps prj
		| isEmpty xs						= (file, heaps, prj)
		# file								= fwrites " " file
		= polishWrite symbols xs file heaps prj
	polishWrite symbols [] file heaps prj
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (Maybe a) | polishWrite a
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols Nothing file heaps prj
		= polishWrite symbols "NO" file heaps prj
	polishWrite symbols (Just x) file heaps prj
		= bracketWrite "YES" file heaps prj
			[ polishWrite symbols x ]
















// -------------------------------------------------------------------------------------------------------------------------------------------------
:: LetDef = {letVar :: !CExprVarPtr, letExpr :: !CExprH}
instance polishWrite LetDef
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols letdef file heaps prj
		# (file, heaps, prj)				= polishWrite symbols letdef.letVar file heaps prj
		# file								= fwrites "=" file
		# (file, heaps, prj)				= polishWrite symbols letdef.letExpr file heaps prj
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols pattern file heaps prj
		= case isEmpty pattern.atpExprVarScope of
			True	-> bracketWrite "PAT" file heaps prj
							[ polishWrite symbols pattern.atpDataCons
							, polishWrite symbols "->"
							, polishWrite symbols pattern.atpResult
							]
			False	-> bracketWrite "PAT" file heaps prj
							[ polishWrite symbols pattern.atpDataCons
							, polishWrite symbols pattern.atpExprVarScope
							, polishWrite symbols "->"
							, polishWrite symbols pattern.atpResult
							]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols pattern file heaps prj
		= bracketWrite "PAT" file heaps prj
			[ polishWrite symbols pattern.bapBasicValue
			, polishWrite symbols "->"
			, polishWrite symbols pattern.bapResult
			]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols (CBasicInteger n) file heaps prj
		= bracketWrite "INT" file heaps prj
			[ polishWrite symbols (toString n) ]
	polishWrite symbols (CBasicCharacter c) file heaps prj
		= bracketWrite "CHAR" file heaps prj
			[ polishWrite symbols (toString c) ]
	polishWrite symbols (CBasicRealNumber r) file heaps prj
		= bracketWrite "REAL" file heaps prj
			[ polishWrite symbols (toString r) ]
	polishWrite symbols (CBasicBoolean b) file heaps prj
		= bracketWrite "BOOL" file heaps prj
			[ polishWrite symbols (toString b) ]
	polishWrite symbols (CBasicString s) file heaps prj
		= bracketWrite "STRING" file heaps prj
			[ polishWrite symbols (toString (size s))
			, polishWrite symbols s
			]
	polishWrite symbols (CBasicArray exprs) file heaps prj
		= case isEmpty exprs of
			True	-> bracketWrite "ARRAY" file heaps prj
							[]
			False	-> bracketWrite "ARRAY" file heaps prj
							[ polishWrite symbols exprs ]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols (CAlgPatterns ptr patterns) file heaps prj
		# file								= fwrites "ALG" file
		# file								= fwrites " " file
		# file								= fwrites (toString (length patterns)) file
		# file								= fwrites " " file
		= polishWrite symbols patterns file heaps prj
	polishWrite symbols (CBasicPatterns ptr patterns) file heaps prj
		# file								= fwrites "BAS" file
		# file								= fwrites " " file
		# file								= fwrites (toString (length patterns)) file
		# file								= fwrites " " file
		= polishWrite symbols patterns file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols (CExprVar ptr) file heaps prj
		= polishWrite symbols ptr file heaps prj
	polishWrite symbols (CShared ptr) file heaps prj
		# (shared, heaps)					= readPointer ptr heaps
		= polishWrite symbols shared.shExpr file heaps prj
	polishWrite symbols (expr @# exprs) file heaps prj
		= case isEmpty exprs of
			True	-> infixWrite "@" file heaps prj
							[ polishWrite symbols expr ]
			False	-> infixWrite "@" file heaps prj
							[ polishWrite symbols expr
							, polishWrite symbols exprs
							]
	polishWrite symbols (CNilPtr @@# []) file heaps prj
		= polishWrite symbols "[]" file heaps prj
	polishWrite symbols (CConsPtr @@# [x, CNilPtr @@# []]) file heaps prj
		# file								= fwrites "[" file
		# (file, heaps, prj)				= polishWrite symbols x file heaps prj
		# file								= fwrites "]" file
		= (file, heaps, prj)
	polishWrite symbols (CConsPtr @@# [x,xs]) file heaps prj
		# file								= fwrites "[" file
		# (file, heaps, prj)				= polishWrite symbols x file heaps prj
		# file								= fwrites ":" file
		# (file, heaps, prj)				= polishWrite symbols xs file heaps prj
		# file								= fwrites "]" file
		= (file, heaps, prj)
	polishWrite symbols ((CBuildTuplePtr arity) @@# xs) file heaps prj
		= bracketWrite "TUPLE" file heaps prj
			[ polishWrite symbols xs ]
	polishWrite symbols ((CTupleSelectPtr arity n) @@# [tuple]) file heaps prj
		= bracketWrite "SELECT" file heaps prj
			[ polishWrite symbols (toString arity)
			, polishWrite symbols (toString n)
			, polishWrite symbols tuple
			]
	polishWrite symbols (ptr @@# exprs) file heaps prj
		= case isEmpty exprs of
			True	-> bracketWrite "@" file heaps prj
							[ polishWrite symbols ptr ]
			False	-> bracketWrite "@" file heaps prj
							[ polishWrite symbols ptr
							, polishWrite symbols exprs
							]
	polishWrite symbols (CLet strict lets expr) file heaps prj
		# letdefs							= [{letVar = var, letExpr = expr} \\ (var,expr) <- lets]
		# name								= if strict "LET!" "LET"
		= bracketWrite name file heaps prj
			[ polishWrite symbols letdefs
			, polishWrite symbols "in"
			, polishWrite symbols expr
			]
	polishWrite symbols (CCase expr patterns def) file heaps prj
		= bracketWrite "CASE" file heaps prj
			[ polishWrite symbols expr
			, polishWrite symbols patterns
			, polishWrite symbols def
			]
	polishWrite symbols (CBasicValue value) file heaps prj
		= polishWrite symbols value file heaps prj
	polishWrite symbols CBottom file heaps prj
		= polishWrite symbols "BOTTOM" file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols CTrue file heaps prj
		= polishWrite symbols "TRUE" file heaps prj
	polishWrite symbols CFalse file heaps prj
		= polishWrite symbols "FALSE" file heaps prj
	polishWrite symbols (CPropVar ptr) file heaps prj
		= polishWrite symbols ptr file heaps prj
	polishWrite symbols (CEqual e1 e2) file heaps prj
		= bracketWrite "=" file heaps prj
			[ polishWrite symbols e1
			, polishWrite symbols e2
			]
	polishWrite symbols (CNot p) file heaps prj
		# file								= fwrites "~" file
		= polishWrite symbols p file heaps prj
	polishWrite symbols (CAnd p q) file heaps prj
		= infixWrite "/\\" file heaps prj
			[ polishWrite symbols p
			, polishWrite symbols q
			]
	polishWrite symbols (COr p q) file heaps prj
		= infixWrite "\\/" file heaps prj
			[ polishWrite symbols p
			, polishWrite symbols q
			]
	polishWrite symbols (CImplies p q) file heaps prj
		= infixWrite "->" file heaps prj
			[ polishWrite symbols p
			, polishWrite symbols q
			]
	polishWrite symbols (CIff p q) file heaps prj
		= infixWrite "<->" file heaps prj
			[ polishWrite symbols p
			, polishWrite symbols q
			]
	polishWrite symbols (CExprForall ptr p) file heaps prj
		= bracketWrite "All" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols p
			]
	polishWrite symbols (CExprExists ptr p) file heaps prj
		= bracketWrite "Ex" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols p
			]
	polishWrite symbols (CPropForall ptr p) file heaps prj
		= bracketWrite "ALL" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols p
			]
	polishWrite symbols (CPropExists ptr p) file heaps prj
		= bracketWrite "EX" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols p
			]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite Depth
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols Shallow file heaps prj
		= polishWrite symbols "Shallow" file heaps prj
	polishWrite symbols Deep file heaps prj
		= polishWrite symbols "Deep" file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite ExprLocation
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols AllSubExprs file heaps prj
		= polishWrite symbols "All" file heaps prj
	polishWrite symbols (SelectedSubExpr name index mb_index) file heaps prj
		# file								= fwrites "(" file
		# file								= fwrites name file
		# file								= fwrites " " file
		# file								= fwrites (toString index) file
		# file								= fwrites " " file
		# (file, heaps, prj)				= polishWrite symbols (mapMaybe toString mb_index) file heaps prj
		# file								= fwrites ")" file
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite MoveDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols MoveIn file heaps prj
		= polishWrite symbols "In" file heaps prj
	polishWrite symbols MoveOut file heaps prj
		= polishWrite symbols "Out" file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite Redex
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols AllRedexes file heaps prj
		= polishWrite symbols "All" file heaps prj
	polishWrite symbols (OneRedex n) file heaps prj
		= polishWrite symbols (toString n) file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite ReduceAmount
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols ReduceToNF file heaps prj
		= polishWrite symbols "NF" file heaps prj
	polishWrite symbols ReduceToRNF file heaps prj
		= polishWrite symbols "RNF" file heaps prj
	polishWrite symbols (ReduceExactly n) file heaps prj
		= polishWrite symbols (toString n) file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite RewriteDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols LeftToRight file heaps prj
		= polishWrite symbols "->" file heaps prj
	polishWrite symbols RightToLeft file heaps prj
		= polishWrite symbols "<-" file heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols (TacticAbsurd ptr1 ptr2) file heaps prj
		= tacticWrite Implicit "Absurd" file heaps prj
			[ polishWrite symbols ptr1
			, polishWrite symbols ptr2
			]
	polishWrite symbols (TacticAbsurdEquality) file heaps prj
		= tacticWrite Implicit "AbsurdEquality" file heaps prj
			[]
	polishWrite symbols (TacticAbsurdEqualityH ptr) file heaps prj
		= tacticWrite Implicit "AbsurdEqualityH" file heaps prj
			[ polishWrite symbols ptr
			]
	polishWrite symbols (TacticApply fact) file heaps prj
		= tacticWrite Implicit "Apply" file heaps prj
			[ polishWrite symbols fact ]
	polishWrite symbols (TacticApplyH fact ptr mode) file heaps prj
		= tacticWrite mode "Apply" file heaps prj
			[ polishWrite symbols fact
			, polishWrite symbols "to"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticAssume prop mode) file heaps prj
		= tacticWrite mode "Assume" file heaps prj
			[ polishWrite symbols prop ]
	polishWrite symbols TacticAxiom file heaps prj
		= tacticWrite Implicit "Axiom" file heaps prj
			[]
	polishWrite symbols (TacticCase depth num) file heaps prj
		= tacticWrite Implicit "Case" file heaps prj
			[ polishWrite symbols depth
			, polishWrite symbols (toString num)
			]
	polishWrite symbols (TacticCaseH depth ptr mode) file heaps prj
		= tacticWrite mode "Case" file heaps prj
			[ polishWrite symbols depth
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticCases expr mode) file heaps prj
		= tacticWrite mode "Cases" file heaps prj
			[ polishWrite symbols expr ]
	polishWrite symbols TacticChooseCase file heaps prj
		= tacticWrite Implicit "ChooseCase" file heaps prj
			[]
	polishWrite symbols (TacticChooseCaseH ptr) file heaps prj
		= tacticWrite Implicit "ChooseCaseH" file heaps prj
			[ polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticCompare e1 e2) file heaps prj
		= tacticWrite Implicit "Compare" file heaps prj
			[ polishWrite symbols e1
			, polishWrite symbols "with"
			, polishWrite symbols e2
			]
	polishWrite symbols (TacticCompareH ptr mode) file heaps prj
		= tacticWrite mode "CompareH" file heaps prj
			[ polishWrite symbols "using"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticContradiction mode) file heaps prj
		= tacticWrite mode "Contradiction" file heaps prj
			[]
	polishWrite symbols (TacticContradictionH ptr) file heaps prj
		= tacticWrite Implicit "Contradiction" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols (TacticCut fact) file heaps prj
		= tacticWrite Implicit "Cut" file heaps prj
			[ polishWrite symbols fact ]
	polishWrite symbols TacticDefinedness file heaps prj
		= tacticWrite Implicit "Definedness" file heaps prj
			[ ]
	polishWrite symbols (TacticDiscard ptrs1 ptrs2 ptrs3) file heaps prj
		# (names1, heaps)					= getPointerNames ptrs1 heaps
		# (names2, heaps)					= getPointerNames ptrs2 heaps
		# (names3, heaps)					= getPointerNames ptrs3 heaps
		# names								= names1 ++ names2 ++ names3
		= tacticWrite Implicit "Discard" file heaps prj
			[ polishWrite symbols (toString (length ptrs1))
			, polishWrite symbols (toString (length ptrs2))
			, polishWrite symbols (toString (length ptrs3))
			, polishWrite symbols names
			]
	polishWrite symbols (TacticExact fact) file heaps prj
		= tacticWrite Implicit "Exact" file heaps prj
			[ polishWrite symbols fact ]
	polishWrite symbols (TacticExFalso ptr) file heaps prj
		= tacticWrite Implicit "ExFalso" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols (TacticExpandFun name index) file heaps prj
		= tacticWrite Implicit "ExpandFun" file heaps prj
			[ polishWrite symbols name
			, polishWrite symbols (toString index)
			]
	polishWrite symbols (TacticExpandFunH name index ptr mode) file heaps prj
		= tacticWrite mode "ExpandFunH" file heaps prj
			[ polishWrite symbols name
			, polishWrite symbols (toString index)
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticExtensionality name) file heaps prj
		= tacticWrite Implicit "Extensionality" file heaps prj
			[ polishWrite symbols name ]
	polishWrite symbols (TacticGeneralizeE expr name) file heaps prj
		= tacticWrite Implicit "GeneralizeE" file heaps prj
			[ polishWrite symbols expr
			, polishWrite symbols "to"
			, polishWrite symbols name
			]
	polishWrite symbols (TacticGeneralizeP prop name) file heaps prj
		= tacticWrite Implicit "GeneralizeP" file heaps prj
			[ polishWrite symbols prop
			, polishWrite symbols "to"
			, polishWrite symbols name
			]
	polishWrite symbols (TacticInduction ptr mode) file heaps prj
		= tacticWrite mode "Induction" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols TacticInjective file heaps prj
		= tacticWrite Implicit "Injective" file heaps prj
			[]
	polishWrite symbols (TacticInjectiveH ptr mode) file heaps prj
		= tacticWrite mode "InjectiveH" file heaps prj
			[ polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticIntroduce names) file heaps prj
		= tacticWrite Implicit "Introduce" file heaps prj
			[ polishWrite symbols names ]
	polishWrite symbols (TacticIntArith location) file heaps prj
		= tacticWrite Implicit "IntArith" file heaps prj
			[ polishWrite symbols location ]
	polishWrite symbols (TacticIntArithH location ptr mode) file heaps prj
		= tacticWrite mode "IntArithH" file heaps prj
			[ polishWrite symbols location
			, polishWrite symbols "to"
			, polishWrite symbols ptr
			]
	polishWrite symbols TacticIntCompare file heaps prj
		= tacticWrite Implicit "IntCompare" file heaps prj
			[]
	polishWrite symbols TacticMakeUnique file heaps prj
		= tacticWrite Implicit "MakeUnique" file heaps prj
			[]
	polishWrite symbols (TacticManualDefinedness ptrs) file heaps prj
		= tacticWrite Implicit "ManualDefinedness"  file heaps prj
			[ polishWrite symbols [TheoremFact ptr [] \\ ptr <- ptrs]
			]
	polishWrite symbols (TacticMoveQuantors dir) file heaps prj
		= tacticWrite Implicit "MoveQuantors" file heaps prj
			[ polishWrite symbols dir
			]
	polishWrite symbols (TacticMoveQuantorsH dir ptr mode) file heaps prj
		= tacticWrite mode "MoveQuantorsH" file heaps prj
			[ polishWrite symbols dir
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticMoveInCase name index) file heaps prj
		= tacticWrite Implicit "MoveInCase" file heaps prj
			[ polishWrite symbols name
			, polishWrite symbols (toString index)
			]
	polishWrite symbols (TacticMoveInCaseH name index ptr mode) file heaps prj
		= tacticWrite mode "MoveInCaseH" file heaps prj
			[ polishWrite symbols name
			, polishWrite symbols (toString index)
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticOpaque ptr) file heaps prj
		= tacticWrite Implicit "Opaque" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols (TacticReduce rmode amount loc ptrs) file heaps prj
		# symbol							= case rmode of
												AsInClean	-> "Reduce-"
												Defensive	-> "Reduce"
												Offensive	-> "Reduce+"
		= tacticWrite Implicit symbol file heaps prj
			[ polishWrite symbols amount
			, polishWrite symbols loc
			, polishWrite symbols "("
			, polishWrite symbols ptrs
			, polishWrite symbols ")"
			]
	polishWrite symbols (TacticReduceH rmode amount loc ptr ptrs mode) file heaps prj
		# symbol							= case rmode of
												AsInClean	-> "ReduceH-"
												Defensive	-> "ReduceH"
												Offensive	-> "ReduceH+"
		= tacticWrite mode symbol file heaps prj
			[ polishWrite symbols amount
			, polishWrite symbols loc
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			, polishWrite symbols "("
			, polishWrite symbols ptrs
			, polishWrite symbols ")"
			]
	polishWrite symbols TacticRefineUndefinedness file heaps prj
		= tacticWrite Implicit "RefineUndefinedness" file heaps prj
			[]
	polishWrite symbols (TacticRefineUndefinednessH ptr mode) file heaps prj
		= tacticWrite mode "RefineUndefinednessH" file heaps prj
			[ polishWrite symbols ptr
			]
	polishWrite symbols TacticReflexive file heaps prj
		= tacticWrite Implicit "Reflexive" file heaps prj
			[]
	polishWrite symbols (TacticRemoveCase index) file heaps prj
		= tacticWrite Implicit "RemoveCase" file heaps prj
			[ polishWrite symbols (toString index)
			]
	polishWrite symbols (TacticRemoveCaseH index ptr mode) file heaps prj
		= tacticWrite mode "RemoveCase" file heaps prj
			[ polishWrite symbols (toString index)
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticRenameE ptr name) file heaps prj
		= tacticWrite Implicit "RenameE" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols "to"
			, polishWrite symbols name
			]
	polishWrite symbols (TacticRenameP ptr name) file heaps prj
		= tacticWrite Implicit "RenameP" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols "to"
			, polishWrite symbols name
			]
	polishWrite symbols (TacticRenameH ptr name) file heaps prj
		= tacticWrite Implicit "RenameH" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols "to"
			, polishWrite symbols name
			]
	polishWrite symbols (TacticRewrite dir redex fact) file heaps prj
		= tacticWrite Implicit "Rewrite" file heaps prj
			[ polishWrite symbols dir
			, polishWrite symbols redex
			, polishWrite symbols fact
			]
	polishWrite symbols (TacticRewriteH dir redex fact ptr mode) file heaps prj
		= tacticWrite mode "Rewrite" file heaps prj
			[ polishWrite symbols dir
			, polishWrite symbols redex
			, polishWrite symbols fact
			, polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticSpecializeE ptr expr mode) file heaps prj
		= tacticWrite mode "SpecializeE" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols "with"
			, polishWrite symbols expr
			]
	polishWrite symbols (TacticSpecializeP ptr prop mode) file heaps prj
		= tacticWrite mode "SpecializeP" file heaps prj
			[ polishWrite symbols ptr
			, polishWrite symbols "with"
			, polishWrite symbols prop
			]
	polishWrite symbols (TacticSplit depth) file heaps prj
		= tacticWrite Implicit "Split" file heaps prj
			[ polishWrite symbols depth ]
	polishWrite symbols (TacticSplitH ptr depth mode) file heaps prj
		= tacticWrite mode "Split" file heaps prj
			[ polishWrite symbols depth
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticSplitCase num mode) file heaps prj
		= tacticWrite mode "SplitCase" file heaps prj
			[ polishWrite symbols (toString num) ]
	polishWrite symbols TacticSplitIff file heaps prj
		= tacticWrite Implicit "SplitIff" file heaps prj
			[]
	polishWrite symbols (TacticSplitIffH ptr mode) file heaps prj
		= tacticWrite mode "SplitIff" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols TacticSymmetric file heaps prj
		= tacticWrite Implicit "Symmetric" file heaps prj
			[]
	polishWrite symbols (TacticSymmetricH ptr mode) file heaps prj
		= tacticWrite mode "Symmetric" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols (TacticTransitiveE expr) file heaps prj
		= tacticWrite Implicit "TransitiveE" file heaps prj
			[ polishWrite symbols expr ]
	polishWrite symbols (TacticTransitiveP prop) file heaps prj
		= tacticWrite Implicit "TransitiveP" file heaps prj
			[ polishWrite symbols prop ]
	polishWrite symbols (TacticTransparent ptr) file heaps prj
		= tacticWrite Implicit "Transparent" file heaps prj
			[ polishWrite symbols ptr ]
	polishWrite symbols TacticTrivial file heaps prj
		= tacticWrite Implicit "Trivial" file heaps prj
			[]
	polishWrite symbols TacticUncurry file heaps prj
		= tacticWrite Implicit "Uncurry" file heaps prj
			[]
	polishWrite symbols (TacticUncurryH ptr mode) file heaps prj
		= tacticWrite mode "UncurryH" file heaps prj
			[ polishWrite symbols "in"
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticUnshare mode letl var varl) file heaps prj
		= tacticWrite Implicit "Unshare" file heaps prj
			[ polishWrite symbols (toString mode)
			, polishWrite symbols (toString letl)
			, polishWrite symbols var
			, polishWrite symbols (toString varl)
			]
	polishWrite symbols (TacticUnshareH mode letl var varl ptr) file heaps prj
		= tacticWrite Implicit "UnshareH" file heaps prj
			[ polishWrite symbols (toString mode)
			, polishWrite symbols (toString letl)
			, polishWrite symbols var
			, polishWrite symbols (toString varl)
			, polishWrite symbols ptr
			]
	polishWrite symbols (TacticWitnessE expr) file heaps prj
		= tacticWrite Implicit "WitnessE" file heaps prj
			[ polishWrite symbols expr ]
	polishWrite symbols (TacticWitnessP prop) file heaps prj
		= tacticWrite Implicit "WitnessP" file heaps prj
			[ polishWrite symbols prop ]
	polishWrite symbols (TacticWitnessH ptr mode) file heaps prj
		= tacticWrite mode "Witness for" file heaps prj
			[ polishWrite symbols ptr ]

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite UseFact
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols (HypothesisFact ptr args) file heaps prj
		# file								= case isEmpty args of
												True	-> file
												False	-> fwrites "(" file
		# (file, heaps, prj)				= polishWrite symbols ptr file heaps prj
		# (file, heaps, prj)				= case isEmpty args of
												True	-> (file, heaps, prj)
												False	-> polishWrite symbols args (fwrites " " file) heaps prj
		# file								= case isEmpty args of
												True	-> file
												False	-> fwrites ")" file
		= (file, heaps, prj)
	polishWrite symbols (TheoremFact ptr args) file heaps prj
		# file								= case isEmpty args of
												True	-> file
												False	-> fwrites "(" file
		# file								= fwrites "\"" file
		# (file, heaps, prj)				= polishWrite symbols ptr file heaps prj
		# file								= fwrites "\"" file
		# (file, heaps, prj)				= case isEmpty args of
												True	-> (file, heaps, prj)
												False	-> polishWrite symbols args (fwrites " " file) heaps prj
		# file								= case isEmpty args of
												True	-> file
												False	-> fwrites ")" file
		= (file, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance polishWrite UseFactArgument
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	polishWrite symbols NoArgument file heaps prj
		= polishWrite symbols "_" file heaps prj
	polishWrite symbols (ExprArgument expr) file heaps prj
		# file								= fwrites "E " file
		= polishWrite symbols expr file heaps prj
	polishWrite symbols (PropArgument prop) file heaps prj
		# file								= fwrites "P " file
		= polishWrite symbols prop file heaps prj