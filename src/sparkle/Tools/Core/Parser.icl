/*
** Program: Clean Prover System
** Module:  Parser (.icl)
** 
** Author:  Maarten de Mol
** Created: 12 September 2000
**
** Note: Look in reference manual for full grammar.
*/

implementation module 
	Parser

import
	StdEnv,
	StdMaybe,
	Errors,
	ParserCombinators,
	Lexical,
	CoreTypes,
	ProveTypes,
	ParseTypes,
	Predefined
from StdFunc import seq

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PExprOrProp =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PIdentifier			!CName
	| PExpr					!PExpr
	| PProp					!PProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PFact =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PHypothesisFact		!CName ![PFactArgument]
	| PTheoremFact			!CName ![PFactArgument]

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PFactArgument =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PNoArgument
	| PArgument				!PExprOrProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PProofCommand =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  P_CmdDebug
	| P_CmdFocus			!Int
	| P_CmdRefresh
	| P_CmdRestartProof
	| P_CmdShowTypes
	| P_CmdTactic			!PTacticId
	| P_CmdTactical			!PTactical
	| P_CmdUndo				!Int
instance DummyValue PProofCommand
	where DummyValue = P_CmdRefresh

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PTactical = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTacticalCompose		!PTactical !PTactical
	| PTacticalRepeat		!Int !PTactical
	| PTacticalTry			!PTactical
	| PTacticalUnit			!PTacticId

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PTacticId = 
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  PTacticAbsurd					!CName !CName
	| PTacticAbsurdEquality			!(Maybe CName)
	| PTacticApply					!PFact !(Maybe CName) !TacticMode
	| PTacticAssume					!PProp !TacticMode
	| PTacticAxiom
	| PTacticCase					!Depth !(Maybe Int) !(Maybe CName) !TacticMode
	| PTacticCases					!PExpr !TacticMode
	| PTacticChooseCase				!(Maybe CName)
	| PTacticCompare				!PExpr !PExpr
	| PTacticCompareH				!CName !TacticMode
	| PTacticContradiction			!(Maybe CName) !TacticMode
	| PTacticCut					!PFact
	| PTacticDefinedness
	| PTacticDiscard				![CName]
	| PTacticExact					!PFact
	| PTacticExFalso				!CName
	| PTacticExpandFun				!CName !Int !(Maybe CName) !TacticMode
	| PTacticExtensionality			!CName
	| PTacticGeneralize				!PExprOrProp !CName
	| PTacticInduction				!CName !TacticMode
	| PTacticInjective				!(Maybe CName) !TacticMode
	| PTacticIntroduce				![CName]
	| PTacticIntArith				!ExprLocation !(Maybe CName) !TacticMode
	| PTacticIntCompare
	| PTacticMakeUnique
	| PTacticManualDefinedness		![CName]
	| PTacticMoveInCase				!CName !Int !(Maybe CName) !TacticMode
	| PTacticMoveQuantors			!MoveDirection !(Maybe CName) !TacticMode
	| PTacticOpaque					!PQualifiedName
	| PTacticReduce					!ReduceMode !ReduceAmount !ExprLocation !(Maybe CName) ![CName] !TacticMode
	| PTacticRefineUndefinedness	!(Maybe CName) !TacticMode
	| PTacticReflexive
	| PTacticRemoveCase				!Int !(Maybe CName) !TacticMode
	| PTacticRename					!CName !CName
	| PTacticRewrite				!RewriteDirection !Redex !PFact !(Maybe CName) !TacticMode
	| PTacticSpecialize				!CName !PExprOrProp !TacticMode
	| PTacticSplit					!(Maybe CName) !Depth !TacticMode
	| PTacticSplitCase				!Int !TacticMode
	| PTacticSplitIff				!(Maybe CName) !TacticMode
	| PTacticSymmetric				!(Maybe CName) !TacticMode
	| PTacticTransitive				!PExprOrProp
	| PTacticTransparent			!PQualifiedName
	| PTacticTrivial
	| PTacticUncurry				!(Maybe CName) !TacticMode
	| PTacticUnshare				!DestroyAfterwards !LetLocation !CName !VarLocation !(Maybe CName)
	| PTacticWitness				!PExprOrProp !(Maybe CName) !TacticMode
instance DummyValue PTacticId
	where DummyValue = PTacticTrivial

// -------------------------------------------------------------------------------------------------------------------------------------------------
class hasBrackets a :: a -> Bool
instance hasBrackets PExpr
	where	hasBrackets (PBracketExpr expr)	= True
			hasBrackets other				= False
instance hasBrackets PProp
	where	hasBrackets (PBracketProp prop)	= True
			hasBrackets other				= False
// -------------------------------------------------------------------------------------------------------------------------------------------------
















// -------------------------------------------------------------------------------------------------------------------------------------------------
fromBasicValue :: !PExpr -> PBasicValue
// -------------------------------------------------------------------------------------------------------------------------------------------------
fromBasicValue (PBasicValue value)
	= value

// -------------------------------------------------------------------------------------------------------------------------------------------------
isVariable :: !PExpr -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isVariable (PSymbol (PNamedPtr quaname) [])
	| isJust quaname.quaModuleName		= False
	= True
isVariable other
	= True

// -------------------------------------------------------------------------------------------------------------------------------------------------
fromVariable :: !PExpr -> CName
// -------------------------------------------------------------------------------------------------------------------------------------------------
fromVariable (PSymbol (PNamedPtr quaname) [])
	| isJust quaname.quaModuleName		= ""
	= quaname.quaName
fromVariable other
	= ""

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseKeyword :: !String -> Parser CLexeme CLexeme
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseKeyword word
	# upper_word						= {toUpper c \\ c <-: word}
	= Satisfy (is upper_word)
	where
		is :: !String !CLexeme -> Bool
		is word (CIdentifier ident)
			# ident						= {toUpper c \\ c <-: ident}
			= word == ident
		is word (CReserved ident)
			# ident						= {toUpper c \\ c <-: ident}
			= word == ident
		is word other
			= False


// =================================================================================================================================================
// Removes the last argument from an expression (which must be an application).
// This last argument must be the name of a let variable.
// Note that it recursively checks cases/lets.
// -------------------------------------------------------------------------------------------------------------------------------------------------
StripLastArg :: !PExpr -> (!CName, !PExpr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
StripLastArg (PApp expr exprs)
	| isEmpty exprs						= StripLastArg expr
	# (last_expr, init_exprs)			= (last exprs, init exprs)
	| not (isVariable last_expr)		= ("", PApp expr exprs)
	| isEmpty init_exprs				= (fromVariable last_expr, expr)
	= (fromVariable last_expr, PApp expr init_exprs)
StripLastArg (PSymbol ptr exprs)
	| isEmpty exprs						= ("", PSymbol ptr exprs)
	# (last_expr, init_exprs)			= (last exprs, init exprs)
	| not (isVariable last_expr)		= ("", PSymbol ptr exprs)
	= (fromVariable last_expr, PSymbol ptr init_exprs)
StripLastArg (PCase expr (PBasicPatterns patterns) maybe_default)
	# (last_arg, new_default)			= StripLastArg (fromJust maybe_default)
	| isJust maybe_default				= (last_arg, PCase expr (PBasicPatterns patterns) (Just new_default))
	# pattern							= last patterns
	# (last_arg, new_result)			= StripLastArg pattern.p_bapResult
	# new_pattern						= {pattern & p_bapResult = new_result}
	# new_patterns						= init patterns ++ [new_pattern]
	= (last_arg, PCase expr (PBasicPatterns new_patterns) maybe_default)
StripLastArg (PCase expr (PAlgPatterns patterns) maybe_default)
	# (last_arg, new_default)			= StripLastArg (fromJust maybe_default)
	| isJust maybe_default				= (last_arg, PCase expr (PAlgPatterns patterns) (Just new_default))
	# pattern							= last patterns
	# (last_arg, new_result)			= StripLastArg pattern.p_atpResult
	# new_pattern						= {pattern & p_atpResult = new_result}
	# new_patterns						= init patterns ++ [new_pattern]
	= (last_arg, PCase expr (PAlgPatterns new_patterns) maybe_default)
StripLastArg (PLet strict lets expr)
	# (last_arg, new_expr)				= StripLastArg expr
	= (last_arg, PLet strict lets new_expr)
StripLastArg other
	= ("", other)

















// =================================================================================================================================================
// Assumption: the starting '|' has already been parsed (or is not required)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseAlgPattern :: Parser CLexeme PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseAlgPattern
	= (     parseIdentifier
	    <&> <*> (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&> (Symbol (CReserved "->"))
	     &> parseGraphExpr
	  ) <@ build_pattern
	where
		build_pattern :: !(!PQualifiedName, !(![CName], !PExpr)) -> PAlgPattern
		build_pattern (name, (vars, expr))
			= {p_atpDataCons = PNamedPtr name, p_atpExprVarScope = vars, p_atpResult = expr}

// =================================================================================================================================================
// Assumption: the starting '|' has already been parsed (or is not required)
// Always parses at least one pattern.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseAlgPatterns :: Parser CLexeme [PAlgPattern]
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseAlgPatterns
	= (      (parseAlgPattern <|> parseConsPattern <|> parseNilPattern <|> parseTuplePattern)
	    <:&> (     Symbol (CReserved "|") &> parseAlgPatterns
	           <|> Succeed []
	         )
	  ) 

// =================================================================================================================================================
// Only simple arrays are accepted; & is not allowed
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseArray :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseArray
	= (     Symbol (CReserved "{")
	     &> List [CReserved ","] parseGraphExpr
	    <&  Symbol (CReserved "}")
	  ) <@ (PBasicValue o PBasicArray)

// =================================================================================================================================================
// Assumption: the starting '|' has already been parsed (or is not required)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicPattern :: Parser CLexeme PBasicPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicPattern
	= (     (parseBasicValue <@ fromBasicValue)
	    <&> (Symbol (CReserved "->"))
	     &> parseGraphExpr
	  ) <@ build_pattern
	where
		build_pattern :: !(!PBasicValue, !PExpr) -> PBasicPattern
		build_pattern (value, expr)
			= {p_bapBasicValue = value, p_bapResult = expr}

// =================================================================================================================================================
// Assumption: the starting '|' has already been parsed (or is not required)
// Always parses at least one pattern.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicPatterns :: Parser CLexeme [PBasicPattern]
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicPatterns
	= (      parseBasicPattern
	    <:&> (     Symbol (CReserved "|") &> parseBasicPatterns
	           <|> Succeed []
	         )
	  ) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicType :: Parser CLexeme CBasicType
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicType
	= (     (parseKeyword "Int"		<@ (\_ -> CInteger))
	    <|> (parseKeyword "Char"	<@ (\_ -> CCharacter))
	    <|> (parseKeyword "Real"	<@ (\_ -> CRealNumber))
	    <|> (parseKeyword "Bool"	<@ (\_ -> CBoolean))
	    <|> (parseKeyword "String"	<@ (\_ -> CString))
	  )

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicValue :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicValue
	=     (Symbol CAnyBoolDenotation)	<@ (PBasicValue o PBasicBoolean    o fromBoolDenotation)
	  <|> (Symbol CAnyCharDenotation)	<@ (PBasicValue o PBasicCharacter  o fromCharDenotation)
	  <|> Pack [CReserved "["] parseCharList [CReserved "]"]
	  <|> parseIntDenotation
	  <|> (Symbol CAnyRealDenotation)	<@ (PBasicValue o PBasicRealNumber o fromRealDenotation)
	  <|> (Symbol CAnyStringDenotation)	<@ (PBasicValue o PBasicString     o fromStringDenotation)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBrackGraph :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBrackGraph
	= (     parseSimpleGraph
	    <&> <*> parseSelection
	  ) <@ (\(expr, funs) -> seq funs expr)

// =================================================================================================================================================
// Always parses +12 as + applied to 12. ParseBrackGraph will parse it as (+12).
// Used on arguments of an application only.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBrackGraphInner :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBrackGraphInner
	= (     parseSimpleGraphInner
	    <&> <*> parseSelection
	  ) <@ (\(expr, funs) -> seq funs expr)

// =================================================================================================================================================
// No type-checking is done.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCase :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCase
	= (     Symbol (CReserved "case")
	     &> parseGraphExpr
	    <&> Symbol (CReserved "of")
	     &> parseCasePatterns
	    <&> (     (Token [CReserved "|", CReserved "default", CReserved "->"] &> parseGraphExpr) <@ Just
	          <|> Succeed Nothing
	        )
	  ) <@ build_case
	where
		build_case :: !(!PExpr, !(!PCasePatterns, !Maybe PExpr)) -> PExpr
		build_case (expr, (patterns, mb_default))
			= PCase expr patterns mb_default

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCasePatterns :: Parser CLexeme PCasePatterns
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCasePatterns
	=     parseAlgPatterns    <@ PAlgPatterns
	  <|> parseBasicPatterns  <@ PBasicPatterns

// =================================================================================================================================================
// Assumption: [ and ] are already parsed
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharList :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCharList
	=     (Symbol CAnyCharDenotation)		<@ (\lex -> make_expr [fromCharDenotation lex])
	  <|> (Symbol CAnyCharListDenotation)	<@ (make_expr o fromCharListDenotation)
	where
		make_expr :: ![Char] -> PExpr
		make_expr chars
			= foldr make_cons nil_expr chars
			where
				make_cons :: !Char !PExpr -> PExpr
				make_cons char expr
					= PSymbol (PHeapPtr CConsPtr) [PBasicValue (PBasicCharacter char), expr]
				
				nil_expr :: PExpr
				nil_expr
					= PSymbol (PHeapPtr CNilPtr) []

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandDot :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandDot
	= parseCommando <& (Symbol (CReserved "."))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommando :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommando
	=     parseTactical					<@ P_CmdTactical
	  <|> parseTactic					<@ P_CmdTactic
	  <|> parseCommandDebug
	  <|> parseCommandFocus
	  <|> parseCommandRefresh
	  <|> parseCommandShowTypes
	  <|> parseCommandUndo

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandDebug :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandDebug
	= parseKeyword "Debug" <@ (\_ -> P_CmdDebug)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandFocus :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandFocus
	= (    parseKeyword "Focus"
	    &> (Symbol CAnyIntDenotation) <@ fromIntDenotation
	  ) <@ P_CmdFocus

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandRefresh :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandRefresh
	= parseKeyword "Refresh" <@ (\_ -> P_CmdRefresh)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandShowTypes :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandShowTypes
	= parseKeyword "ShowTypes" <@ (\_ -> P_CmdShowTypes)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandUndo :: Parser CLexeme PProofCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseCommandUndo
	=     (    parseKeyword "Undo"
	        &> Optional ((Symbol CAnyIntDenotation) <@ fromIntDenotation) 1
          ) <@ P_CmdUndo
      <|> parseKeyword "Restart" <@ (\_ -> P_CmdRestartProof)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseConsPattern :: Parser CLexeme PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseConsPattern
	= (     (Symbol (CReserved "["))
	     &> (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&> (Symbol (CReserved ":"))
	     &> (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&>  (Symbol (CReserved "]"))
	     &> (Symbol (CReserved "->"))
	     &> parseGraphExpr
	  ) <@ build_pattern
	where
		build_pattern :: !(!CName, !(!CName, !PExpr)) -> PAlgPattern
		build_pattern (head, (tail, expr))
			= {p_atpDataCons = PHeapPtr CConsPtr, p_atpExprVarScope = [head,tail], p_atpResult = expr}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepth :: Parser CLexeme Depth
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepth
	=     parseKeyword "Shallow" <@ (\_ -> Shallow)
	  <|> parseKeyword "Deep"    <@ (\_ -> Deep)

// =================================================================================================================================================
// Always succeeds; default is AllSubExprs.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLocation :: Parser CLexeme ExprLocation
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLocation
	=		(		Symbol (CReserved "(")
				 &>	parse_name
				<&>	Symbol CAnyIntDenotation
				<&> Optional (parseKeyword "#" &> Symbol CAnyIntDenotation <@ Just o fromIntDenotation) Nothing
				<&	Symbol (CReserved ")")
			) <@ (\(name,(int, mb_num)) -> SelectedSubExpr name (fromIntDenotation int) mb_num)
		<|>	(		parseKeyword "All"
			) <@ (\_ -> AllSubExprs)
		<|> 		Succeed AllSubExprs
	where
		parse_name
			=       parseName
				<|> (parseKeyword "case" <@ (\_ -> "case"))
				<|> (parseKeyword "let" <@ (\_ -> "let"))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprOrProp :: Parser CLexeme PExprOrProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprOrProp
	=     parseName				<@ PIdentifier
	  <|> parseGraphExpr		<@ PExpr
	  <|> parseProp				<@ PProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprOrPropInner :: Parser CLexeme PExprOrProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprOrPropInner
	=     parseName				<@ PIdentifier
	  <|> parseBrackGraphInner	<@ PExpr
	  <|> parseProp				<@ PProp

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFact :: Parser CLexeme PFact
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFact
	=     (parseTheorem    <@ \name -> PTheoremFact name [])
	  <|> (parseHypothesis <@ \name -> PHypothesisFact name [])
	  <|> (		(Symbol (CReserved "("))
	  		 &> parseTheorem
	  		<&> <*> parseFactArgument
	  		<&  (Symbol (CReserved ")"))
	  	  ) <@ (\(name, args) -> PTheoremFact name args)
	  <|> (		(Symbol (CReserved "("))
	  		 &> parseHypothesis
	  		<&> <*> parseFactArgument
	  		<&  (Symbol (CReserved ")"))
	  	  ) <@ (\(name, args) -> PHypothesisFact name args)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArgument :: Parser CLexeme PFactArgument
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArgument
	=     (parseKeyword "_"			<@ \_ -> PNoArgument)
	  <|> (parseExprOrPropInner		<@ PArgument)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseGraphExpr :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseGraphExpr
	=     (     parseBrackGraph
	        <&> <*> parseBrackGraphInner
	      ) <@ make_application
	  <|> parseCase
	  <|> parseLet
	where
		make_application :: !(!PExpr, ![PExpr]) -> PExpr
		make_application (expr, exprs)
			| isEmpty exprs				= expr
			= PApp expr exprs

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseHypothesis :: Parser CLexeme CName
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseHypothesis
	= parseName

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIdentifier :: Parser CLexeme PQualifiedName
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIdentifier
	= (     (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&> (     (Symbol (CReserved "@") &> (Symbol CAnyIdentifier <@ fromIdentifier))
	          <|> (Succeed "")
	        )
	  ) <@ qualify
	where
		qualify :: !(!CName, !CName) -> PQualifiedName
		qualify (name1, name2)
			| name2 == ""				= {quaModuleName = Nothing, quaName = name1}
			= {quaModuleName = Just name1, quaName = name2}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIntDenotation :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseIntDenotation
	= (     (Satisfy isPlus  &> (Symbol CAnyIntDenotation)) <@ fromIntDenotation
	    <|> (Satisfy isMinus &> (Symbol CAnyIntDenotation)) <@ (\num -> ~(fromIntDenotation num))
	    <|> (Symbol CAnyIntDenotation) <@ fromIntDenotation
	  ) <@ (PBasicValue o PBasicInteger)
	where
		isPlus :: CLexeme -> Bool
		isPlus (CIdentifier "+")	= True
		isPlus other				= False
		
		isMinus :: CLexeme -> Bool
		isMinus (CIdentifier "-")	= True
		isMinus other				= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLet :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLet
	= (     (     (Symbol (CReserved "let") <@ (\_ -> False))
	          <|> (Symbol (CReserved "let!") <@ (\_ -> True))
	        )
	    <&> parseGraphExpr
	    <&> <+> parseLetDefinition
	    <&> Symbol (CReserved "in")
	     &> parseGraphExpr
	  ) <@ build_let
	where
		build_let :: !(!Bool, !(!PExpr, (![PExpr], !PExpr))) -> PExpr
		build_let (strict, (first_var, (lets, expr)))
			| not (isVariable first_var)	= PBottom
			# first_var						= fromVariable first_var
			# (rest_vars, init_defs)		= unzip (map StripLastArg (init lets))
			| isMember "" rest_vars			= PBottom
			# last_def						= last lets
			# vars							= [first_var : rest_vars]
			# defs							= init_defs ++ [last_def]
			= PLet strict (zip2 vars defs) expr

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLetDefinition :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseLetDefinition
	=     Symbol (CReserved "=")
	   &> parseGraphExpr
 
// =================================================================================================================================================
// Assumption: [ and ] are already parsed
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseList :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseList
	= (     (     List [CReserved ","] parseGraphExpr
	          <|> Succeed []
	        )
	    <&> (     (Symbol (CReserved ":") &> parseGraphExpr) <@ Just
	          <|> Succeed Nothing
	        )
	  ) <@ build_list
	where
		build_list :: (![PExpr], !Maybe PExpr) -> PExpr
		build_list ([], Nothing)
			= PSymbol (PHeapPtr CNilPtr) []
		build_list (exprs, end_expr)
			# end_expr			= if (isJust end_expr) (fromJust end_expr) (PSymbol (PHeapPtr CNilPtr) [])
			= foldr make_cons end_expr exprs
		
		make_cons :: !PExpr !PExpr -> PExpr
		make_cons expr1 expr2
			= PBracketExpr (PSymbol (PHeapPtr CConsPtr) [expr1, expr2])

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeHypothesis :: !(Maybe String) -> Parser CLexeme (Maybe CName)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeHypothesis Nothing
	= Optional (parseHypothesis <@ Just) Nothing
parseMaybeHypothesis (Just word)
	= Optional (    Optional (parseKeyword word) undef
	             &> parseHypothesis <@ Just
	           ) Nothing 

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMoveDirection :: Parser CLexeme MoveDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMoveDirection
	=      (parseKeyword "in" <@ (\_ -> MoveIn))
	   <|> (parseKeyword "out" <@ (\_ -> MoveOut))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseName :: Parser CLexeme CName
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseName
	= Symbol CAnyIdentifier <@ fromIdentifier

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseNilPattern :: Parser CLexeme PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseNilPattern
	= (     (Symbol (CReserved "["))
	     &> (Symbol (CReserved "]"))
	     &> (Symbol (CReserved "->"))
	     &> parseGraphExpr
	  ) <@ build_pattern
	where
		build_pattern :: !PExpr -> PAlgPattern
		build_pattern expr
			= {p_atpDataCons = PHeapPtr CNilPtr, p_atpExprVarScope = [], p_atpResult = expr}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseNumber :: Parser CLexeme Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseNumber
	= Symbol CAnyIntDenotation <@ fromIntDenotation

// =================================================================================================================================================
// Conventions on when brackets are needed:
//    (*) AND/OR/IMPLIES are right associative
//    (*) priorities from low to high: FORALL, IMPLIES, OR, AND, NOT (converted later!)
// Parsing:
//    (*) The grammar for propositions is left-recursive.
//        This is solved by splitting in a head and a tail.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProp :: Parser CLexeme PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProp
	= (     parsePropHead
	    <&> parsePropTail
	  ) <@ (\(p,fun) -> buildPropQuantors (fun p))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropHead :: Parser CLexeme PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropHead
	= (     (Symbol (CReserved "TRUE")) <@ (\_ -> PTrue)
	    <|> (Symbol (CReserved "FALSE")) <@ (\_ -> PFalse)
	    <|> (    Symbol (CReserved "~")
	          &> parsePropHead
	        ) <@ PNot
	    <|> (     Symbol (CReserved "[")
	           &> (Symbol CAnyIdentifier <@ fromIdentifier)
	          <&> parseTypeAnnotation
	          <&> Symbol (CReserved "]")
	           &> parseProp
	        ) <@ build_forall
	    <|> (     Symbol (CReserved "{")
	           &> (Symbol CAnyIdentifier <@ fromIdentifier)
	          <&> parseTypeAnnotation
	          <&> Symbol (CReserved "}")
	           &> parseProp
	        ) <@ build_exists
	    <|> (     parseGraphExpr
	          <&> Symbol (CReserved "=")
	           &> parseGraphExpr
	        ) <@ (\(e1,e2) -> PEqual e1 e2)
	    <|> (Pack [CReserved "("] parseProp [CReserved ")"]) <@ PBracketProp
	    <|> parseGraphExpr <@ expr_to_prop
	  )
	where
		build_forall :: !(!CName, !(!Maybe PType, !PProp)) -> PProp
		build_forall (name, (mb_type, prop))
			= PExprForall name mb_type prop
		
		build_exists :: !(!CName, !(!Maybe PType, !PProp)) -> PProp
		build_exists (name, (mb_type, prop))
			= PExprExists name mb_type prop
		
		build_var_or_predicate :: !(!PQualifiedName, ![PExpr]) -> PProp
		build_var_or_predicate (quaname, [])
			= PPropVar quaname.quaName
		build_var_or_predicate (quaname, exprs)
			= PPredicate (PNamedPtr quaname) exprs
		
		expr_to_prop :: !PExpr -> PProp
		expr_to_prop (PExprVar name)
			= PPropVar name
		expr_to_prop (PSymbol (PNamedPtr quaname) [])
			= PPropVar quaname.quaName
		expr_to_prop expr
			= PEqual expr (PBasicValue (PBasicBoolean True))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropTail :: Parser CLexeme (PProp -> PProp)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropTail
	= (     (     (Symbol (CReserved "/\\"))
	           &> parseProp
	        ) <@ (flip PAnd)
	    <|> (     (Symbol (CReserved "\\/"))
	           &> parseProp
	        ) <@ (flip POr)
	    <|> (     (Symbol (CReserved "->"))
	           &> parseProp
	        ) <@ (flip PImplies)
	    <|> (     (Symbol (CReserved "=>"))
	           &> parseProp
	        ) <@ (flip PImplies)
	    <|> (     (Symbol (CReserved "<->"))
	           &> parseProp
	        ) <@ (flip PIff)
	    <|> (     (Symbol (CReserved "<=>"))
	           &> parseProp
	        ) <@ (flip PIff)
	    <|> Succeed id
	  )

// =================================================================================================================================================
// Only simple records are accepted; & is not allowed
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRecord :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRecord 
	= (     Symbol (CReserved "{")
	    
	     &> (     (parseFields <@ make_simple_record)
	          <|> (     parseIdentifier
	                <&> (Symbol (CReserved "|"))
	                 &> parseFields
	              ) <@ make_complex_record
	        )
	    <&  Symbol (CReserved "}")
	  )
	where
		make_simple_record :: [(CName, PExpr)] -> PExpr
		make_simple_record assigns
			# field_names			= map fst assigns
			= PSymbol (PBuildRecord Nothing field_names) (map snd assigns)
		
		make_complex_record :: !(!PQualifiedName, ![(String, PExpr)]) -> PExpr
		make_complex_record (name, assigns)
			# field_names			= map fst assigns
			= PSymbol (PBuildRecord (Just name) field_names) (map snd assigns)
		
		parseFields
			= List [CReserved ","] (     (Symbol CAnyIdentifier <@ fromIdentifier)
	                                 <&> Symbol (CReserved "=")
	                                  &> parseGraphExpr
	                               )

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRedex :: Parser CLexeme Redex
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRedex
	=     Symbol CAnyIntDenotation <@ (OneRedex o fromIntDenotation)
	  <|> parseKeyword "All" <@ (\_ -> AllRedexes)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReduceAmount :: Parser CLexeme ReduceAmount
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReduceAmount
	=     Symbol CAnyIntDenotation   <@ (\n -> ReduceExactly (fromIntDenotation n))
	  <|> parseKeyword "RNF"         <@ (\_ -> ReduceToRNF)
	  <|> parseKeyword "NF"          <@ (\_ -> ReduceToNF)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteDirection :: Parser CLexeme RewriteDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteDirection
	=     parseKeyword "<-" <@ (\_ -> RightToLeft)
	  <|> parseKeyword "->" <@ (\_ -> LeftToRight)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteOccurrence :: Parser CLexeme RewriteOccurrence
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteOccurrence
	= Symbol CAnyIntDenotation <@ OneOccurrence o fromIntDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSelection :: Parser CLexeme (PExpr -> PExpr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSelection
	=     (     Symbol (CReserved ".")
	         &> parseIdentifier
	      ) <@ field_select
	  <|> (     Symbol (CReserved ".")
	         &> Symbol (CReserved "[")
	         &> parseGraphExpr
	        <&  Symbol (CReserved "]")
	      ) <@ array_select
	where
		field_select :: !PQualifiedName !PExpr -> PExpr
		field_select fieldname expr
			= PSymbol (PSelectField fieldname) [expr]
		
		array_select :: !PExpr !PExpr -> PExpr
		array_select index expr
			= PSymbol PSelectIndex [expr, index]

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSimpleGraph :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSimpleGraph
	=     parseBasicValue
	  <|> parseIdentifier                                          <@ apply o PNamedPtr
	  <|> Pack [CReserved "("] parseGraphExpr [CReserved ")"]      <@ PBracketExpr
	  <|> Pack [CReserved "["] parseList [CReserved "]"]
	  <|> parseTuple
	  <|> parseRecord
	  <|> parseArray
	  <|> Symbol (CReserved "_|_")                                 <@ (\_ -> PBottom)
	where
		apply :: !ParsedPtr -> PExpr
		apply ptr
			= PSymbol ptr []

// =================================================================================================================================================
// Always parses +12 as + applied to 12. ParseBrackGraph will parse it as (+12).
// Used on arguments of an application only.
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSimpleGraphInner :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSimpleGraphInner
	=     parseIdentifier                                          <@ apply o PNamedPtr
	  <|> Pack [CReserved "("] parseGraphExpr [CReserved ")"]      <@ PBracketExpr
	  <|> parseBasicValue
	  <|> Pack [CReserved "["] parseList [CReserved "]"]
	  <|> parseTuple
	  <|> parseRecord
	  <|> parseArray
	  <|> Symbol (CReserved "_|_")                                 <@ (\_ -> PBottom)
	where
		apply :: !ParsedPtr -> PExpr
		apply ptr
			= PSymbol ptr []

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMode :: Parser CLexeme TacticMode
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMode
	=     parseKeyword "Explicit" <@ (\_ -> Explicit)
	  <|> Succeed Implicit

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactical :: Parser CLexeme PTactical
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactical
	= (     (     parseTactic											<@ PTacticalUnit
	          <|> (parseKeyword "Repeat" &> parseTactical)				<@ (\tactical -> PTacticalRepeat 0 tactical)
	          <|> (parseKeyword "Try" &> parseTactic)					<@ (\tactic -> PTacticalTry (PTacticalUnit tactic))
	          <|> (    parseKeyword "Try"
	                &> Pack [CReserved "("] parseTactical
	                		[CReserved ")"]								<@ PTacticalTry
	              )
	          <|> (Pack [CReserved "("] parseTactical [CReserved ")"])
	        )
	    <&> (     (parseKeyword ";" &> parseTactical)       <@ (\tactical2 -> \tactical1 -> PTacticalCompose tactical1 tactical2)
	          <|> Succeed id
	        )
	  ) <@ (\(tactical, compose) -> compose tactical)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactic :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactic
	=     parseTacticAbsurd
	  <|> parseTacticAbsurdEquality
	  <|> parseTacticApply
	  <|> parseTacticAssume
	  <|> parseTacticAxiom
	  <|> parseTacticCase
	  <|> parseTacticCases
	  <|> parseTacticChooseCase
	  <|> parseTacticCompare
	  <|> parseTacticCompareH
	  <|> parseTacticContradiction
	  <|> parseTacticCut
	  <|> parseTacticDefinedness
	  <|> parseTacticDiscard
	  <|> parseTacticExact
	  <|> parseTacticExFalso
	  <|> parseTacticExpandFun
	  <|> parseTacticExtensionality
	  <|> parseTacticGeneralize
	  <|> parseTacticInduction
	  <|> parseTacticInjective
	  <|> parseTacticIntroduce
	  <|> parseTacticIntArith
	  <|> parseTacticIntCompare
	  <|> parseTacticMakeUnique
	  <|> parseTacticManualDefinedness
	  <|> parseTacticMoveInCase
	  <|> parseTacticMoveQuantors
	  <|> parseTacticOpaque
	  <|> parseTacticReduce
	  <|> parseTacticRefineUndefinedness
	  <|> parseTacticReflexive
	  <|> parseTacticRemoveCase
	  <|> parseTacticRename
	  <|> parseTacticRewrite
	  <|> parseTacticSpecialize
	  <|> parseTacticSplit
	  <|> parseTacticSplitCase
	  <|> parseTacticSplitIff
	  <|> parseTacticSymmetric
	  <|> parseTacticTransitive
	  <|> parseTacticTransparent
	  <|> parseTacticTrivial
	  <|> parseTacticUncurry
	  <|> parseTacticUnshareF
	  <|> parseTacticUnshareT
	  <|> parseTacticWitness

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurd :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurd
	= (    parseKeyword "Absurd"
	    &> parseHypothesis
	   <&> parseHypothesis
	  ) <@ (\(name1,name2) -> PTacticAbsurd name1 name2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEquality :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEquality
	= (    parseKeyword "AbsurdEquality"
	    &> parseMaybeHypothesis Nothing
	  ) <@ PTacticAbsurdEquality

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticApply :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticApply
	= (     parseTacticMode
	    <&> parseKeyword "Apply"
	     &> parseFact
	    <&> parseMaybeHypothesis (Just "to")
	  ) <@ (\(mode, (fact, mb_name)) -> PTacticApply fact mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAssume :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAssume
	= (     parseTacticMode
	    <&> parseKeyword "Assume"
	     &> parseProp
	  ) <@ (\(mode,p) -> PTacticAssume p mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAxiom :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAxiom
	= (     parseKeyword "Axiom"
	  ) <@ (\_ -> PTacticAxiom)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCase :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCase
	=     (     parseTacticMode
	        <&> parseKeyword "Case"
	         &> Optional parseDepth Shallow
	        <&> Optional (Symbol CAnyIntDenotation <@ (Just o fromIntDenotation)) Nothing
	        <&> parseMaybeHypothesis Nothing
	      ) <@ (\(mode,(depth,(mb_num,mb_name))) -> PTacticCase depth mb_num mb_name mode)
	  <|> (parseKeyword "Left" <@ (\_ -> PTacticCase Shallow (Just 1) Nothing Implicit))
	  <|> (parseKeyword "Right" <@ (\_ -> PTacticCase Shallow (Just 2) Nothing Implicit))

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCases :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCases
	= (     parseTacticMode
	    <&> parseKeyword "Cases"
	     &> parseGraphExpr
	  ) <@ (\(mode,expr) -> PTacticCases expr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCase :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCase
	= (     parseKeyword "ChooseCase"
	     &> parseMaybeHypothesis (Just "in")
	  ) <@ PTacticChooseCase

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompare :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompare
	= (     parseKeyword "Compare"
	     &> Until parseGraphExpr (isWord "with")
	    <&> parseKeyword "with"
	     &> Until parseGraphExpr (isWord ".")
	  ) <@ (\(e1,e2) -> PTacticCompare e1 e2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompareH :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompareH
	= (     parseTacticMode
	    <&> parseKeyword "Compare"
	     &> parseKeyword "using"
	     &> parseHypothesis
	  ) <@ (\(mode,name) -> PTacticCompareH name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticContradiction :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticContradiction
	= (     parseTacticMode
	    <&> parseKeyword "Contradiction"
	     &> parseMaybeHypothesis Nothing
	  ) <@ (\(mode,mb_hyp) -> PTacticContradiction mb_hyp mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCut :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCut
	= (    parseKeyword "Cut"
	    &> parseFact
	  ) <@ PTacticCut

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDefinedness :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDefinedness
	= parseKeyword "Definedness" <@ (\_ -> PTacticDefinedness)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDiscard :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDiscard
	= (    parseKeyword "Discard"
	    &> <+> parseName
	  ) <@ PTacticDiscard

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExact :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExact
	= (     parseKeyword "Exact"
	     &> parseFact
	  ) <@ PTacticExact

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExFalso :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExFalso
	= (     parseKeyword "ExFalso"
	     &> parseHypothesis
	  ) <@ PTacticExFalso

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFun :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFun
	=     (     parseTacticMode
	        <&> parseKeyword "ExpandFun"
	         &> parseName
		    <&> (Symbol CAnyIntDenotation <@ fromIntDenotation)
		    <&> parseMaybeHypothesis (Just "in")
		  ) <@ (\(mode, (name, (index, mb_name))) -> PTacticExpandFun name index mb_name mode)
	 <|>  (     parseKeyword "ExpandFun"
		     &> parseName
		    <&> (Symbol CAnyIntDenotation <@ fromIntDenotation)
	      ) <@ (\(name, index) -> PTacticExpandFun name index Nothing Implicit)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExtensionality :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExtensionality
	= (     parseKeyword "Extensionality"
	     &> Optional parseName "x"
	  ) <@ PTacticExtensionality

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralize :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralize
	= (     parseKeyword "Generalize"
		 &> parseExprOrProp
		<&> (     parseKeyword "to" &> parseName
		      <|> Succeed "gen"
		    )
	  ) <@ (\(expr_prop, name) -> PTacticGeneralize expr_prop name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInduction :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInduction
	= (     parseTacticMode
	    <&> parseKeyword "Induction"
	     &> parseName
	  ) <@ (\(mode, name) -> PTacticInduction name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjective :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjective
	=		(		parseTacticMode
				<&> parseKeyword "Injective"
				 &> parseKeyword "in"
				 &> parseHypothesis
			) <@ (\(mode, name) -> PTacticInjective (Just name) mode)
		<|> (		parseKeyword "Injective"
			) <@ (\_ -> PTacticInjective Nothing Implicit)
  
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntroduce :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntroduce
	= (     (    (parseKeyword "Intro" <|> parseKeyword "Introduce")
	          &> Optional (<+> parseName) ["_"]
	        ) <@ PTacticIntroduce
	    <|> (    (parseKeyword "Intros" <|> parseKeyword "Introduces")
	          &> Optional (<+> parseName) (repeatn 100 "_")
	        ) <@ PTacticIntroduce
	  )

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArith :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArith
	= (     parseTacticMode
	    <&> parseKeyword "IntArith"
	     &> parseExprLocation
	    <&> parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode, (location, mb_name)) -> PTacticIntArith location mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntCompare :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntCompare
	=     (     parseKeyword "IntCompare"
	      ) <@ (\_ -> PTacticIntCompare)
	  <|> (     parseKeyword "IntComp"
	      ) <@ (\_ -> PTacticIntCompare)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMakeUnique :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMakeUnique
	= (     parseKeyword "MakeUnique"
	  ) <@ (\_ -> PTacticMakeUnique)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticManualDefinedness :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticManualDefinedness
	= (     parseKeyword "ManualDefinedness"
	     &> <+> parseTheorem
	  ) <@ PTacticManualDefinedness

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCase :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCase
	= (     parseTacticMode
	    <&> parseKeyword "MoveInCase"
	     &> parseName
	    <&> (Symbol CAnyIntDenotation <@ fromIntDenotation)
	    <&> parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode,(name,(index,mb_hyp))) -> PTacticMoveInCase name index mb_hyp mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantors :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantors
	= (     parseTacticMode
	    <&> parseKeyword "MoveQuantors"
	     &> parseMoveDirection
	    <&> parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode,(dir,mb_name)) -> PTacticMoveQuantors dir mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticOpaque :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticOpaque
	= (     parseKeyword "Opaque"
	     &> parseIdentifier
	  ) <@ PTacticOpaque

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRename :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRename
	= (     parseKeyword "Rename"
		 &> parseName
		<&> parseKeyword "to"
		 &> parseName
	  ) <@ (\(name1, name2) -> PTacticRename name1 name2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduce :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduce
	=     (     parseTacticMode
	        <&> parseKeyword "Reduce"
	         &> Optional parseReduceAmount ReduceToNF
	        <&> parseExprLocation
	        <&> parseMaybeHypothesis (Just "in")
	        <&> Optional parse_defined []
	      ) <@ (\(mode,(amount,(loc,(mb_hyp,defined)))) -> PTacticReduce Defensive amount loc mb_hyp defined mode)
	  <|> (     parseTacticMode
	        <&> parseKeyword "Reduce+"
	         &> Optional parseReduceAmount ReduceToRNF
	        <&> parseExprLocation
	        <&> parseMaybeHypothesis (Just "in")
	        <&> Optional parse_defined []
	      ) <@ (\(mode,(amount,(loc,(mb_hyp,defined)))) -> PTacticReduce Offensive amount loc mb_hyp defined mode)
	  <|> (     parseTacticMode
	        <&> parseKeyword "Reduce-"
	         &> Optional parseReduceAmount ReduceToNF
	        <&> parseExprLocation
	        <&> parseMaybeHypothesis (Just "in")
	        <&> Optional parse_defined []
	      ) <@ (\(mode,(amount,(loc,(mb_hyp,defined)))) -> PTacticReduce AsInClean amount loc mb_hyp defined mode)
	where
		parse_defined
			=     parseKeyword "("
			   &> parseKeyword "defined"
			   &> <*> parseHypothesis
			  <&  parseKeyword ")" 

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinedness :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinedness
	= (     parseTacticMode
	    <&> parseKeyword "RefineUndefinedness"
	     &> parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode,mb_name) -> PTacticRefineUndefinedness mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReflexive :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReflexive
	= parseKeyword "Reflexive" <@ (\_ -> PTacticReflexive)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCase :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCase
	= (     parseTacticMode
	    <&> parseKeyword "RemoveCase"
	     &> Optional (Symbol CAnyIntDenotation <@ fromIntDenotation) 1
	    <&> parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode,(index,mb_hyp)) -> PTacticRemoveCase index mb_hyp mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRewrite :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRewrite
	=    (     parseTacticMode
	       <&> parseKeyword "Rewrite"
	        &> Optional parseRewriteDirection LeftToRight
	       <&> Optional parseRedex AllRedexes
	       <&> parseFact
	       <&> parseMaybeHypothesis (Just "in")
	     ) <@ (\(mode,(direction,(redex,(fact,mb_hyp)))) -> PTacticRewrite direction redex fact mb_hyp mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecialize :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecialize
	= (     parseTacticMode
	    <&> parseKeyword "Specialize"
	     &> parseHypothesis
	    <&> Optional (parseKeyword "with") (CIdentifier "")
	     &> parseExprOrProp
	   ) <@ (\(mode,(name,expr_prop)) -> PTacticSpecialize name expr_prop mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplit :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplit
	= (     parseTacticMode
	    <&> parseKeyword "Split"
	     &> Optional parseDepth Shallow
	    <&> parseMaybeHypothesis Nothing
	  ) <@ (\(mode,(depth,mb_name)) -> PTacticSplit mb_name depth mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitCase :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitCase
	= (     parseTacticMode
	    <&> parseKeyword "SplitCase"
	    &>  (Symbol CAnyIntDenotation <@ fromIntDenotation)
	  ) <@ (\(mode,index) -> PTacticSplitCase index mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitIff :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitIff
	= (     parseTacticMode
	    <&> parseKeyword "SplitIff"
	     &> parseMaybeHypothesis Nothing
	  ) <@ (\(mode,mb_name) -> PTacticSplitIff mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSymmetric :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSymmetric
	= (     parseTacticMode
	    <&> parseKeyword "Symmetric"
	     &> parseMaybeHypothesis Nothing
	  ) <@ (\(mode,mb_name) -> PTacticSymmetric mb_name mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitive :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitive
	= (    parseKeyword "Transitive"
	    &> parseExprOrProp
	  ) <@ PTacticTransitive

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransparent :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransparent
	= (     parseKeyword "Transparent"
	     &> parseIdentifier
	  ) <@ PTacticTransparent

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTrivial :: Parser CLexeme PTacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTrivial
	= parseKeyword "Trivial" <@ (\_ -> PTacticTrivial)

// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUncurry :: Parser CLexeme PTacticId
// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUncurry
	= (      parseTacticMode
	    <&>  parseKeyword "Uncurry"
	    &>   parseMaybeHypothesis (Just "in")
	  ) <@ (\(mode,mb_name) -> PTacticUncurry mb_name mode)

// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUnshareF :: Parser CLexeme PTacticId
// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUnshareF
	= (      (parseKeyword "Unshare" <&> parseKeyword "-")
	    &>   Optional parseNumber 1
	   <&>   parseName
	   <&>   (    (parseKeyword "All"      <@ (\_ -> AllVars))
	          <|> (parseNumber             <@ JustVarIndex)
	          <|> (Succeed                    AllVars)
	         )
	   <&>   parseMaybeHypothesis (Just "in")
	  ) <@ \(letl,(var,(varl,mb_hyp))) -> PTacticUnshare False letl var varl mb_hyp

// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUnshareT :: Parser CLexeme PTacticId
// ------------------------------------------------------------------------------------------------------------------------   
parseTacticUnshareT
	= (      parseKeyword "Unshare"
	    &>   Optional parseNumber 1
	   <&>   parseName
	   <&>   (    (parseKeyword "All"      <@ (\_ -> AllVars))
	          <|> (parseNumber             <@ JustVarIndex)
	          <|> (Succeed                    AllVars)
	         )
	   <&>   parseMaybeHypothesis (Just "in")
	  ) <@ \(letl,(var,(varl,mb_hyp))) -> PTacticUnshare True letl var varl mb_hyp

// ------------------------------------------------------------------------------------------------------------------------   
parseTacticWitness :: Parser CLexeme PTacticId
// ------------------------------------------------------------------------------------------------------------------------   
parseTacticWitness
	=     (     parseTacticMode
	        <&> parseKeyword "Witness"
	         &> parseKeyword "for"
	         &> parseHypothesis
	      ) <@ (\(mode,name) -> PTacticWitness (PExpr PBottom) (Just name) mode)
	  <|> (     parseTacticMode
	        <&> parseKeyword "Witness"
	         &> parseExprOrProp
	      ) <@ (\(mode, expr_prop) -> PTacticWitness expr_prop Nothing mode)
	  <|> (     parseKeyword "WitnessE"
	         &> parseGraphExpr
	      ) <@ (\expr -> PTacticWitness (PExpr expr) Nothing Implicit)
	  <|> (     parseKeyword "WitnessP"
	         &> parseProp
	      )  <@ (\prop -> PTacticWitness (PProp prop) Nothing Implicit)      

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTheorem :: Parser CLexeme CName
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTheorem
	=     (     Symbol (CReserved "(")
	         &> parseKeyword "theorem"
	         &> parseName
	        <&  Symbol (CReserved ")")
	      )
	  <|> (Symbol CAnyStringDenotation)	<@ fromStringDenotation

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTuple :: Parser CLexeme PExpr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTuple
	= (     Symbol (CReserved "(")
	     &> parseGraphExpr
	    <&> Symbol (CReserved ",")
	     &> List [CReserved ","] parseGraphExpr
	    <&  Symbol (CReserved ")")
	  ) <@ build_tuple
	where
		build_tuple :: !(!PExpr, ![PExpr]) -> PExpr
		build_tuple (first, [second: rest])
			# tuple_arity			= 2 + length rest
			= PSymbol (PHeapPtr (CBuildTuplePtr tuple_arity)) [first, second: rest]

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTuplePattern :: Parser CLexeme PAlgPattern
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTuplePattern
	= (     Symbol (CReserved "(")
	     &> (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&> Symbol (CReserved ",")
	     &> List [CReserved ","] (Symbol CAnyIdentifier <@ fromIdentifier)
	    <&> Symbol (CReserved ")")
	     &> Symbol (CReserved "->")
	     &> parseGraphExpr
	  ) <@ build_pattern
	where
		build_pattern :: !(!CName, !(![CName], !PExpr)) -> PAlgPattern
		build_pattern (first, ([second: rest], expr))
			# tuple_arity			= 2 + length rest
			= {p_atpDataCons = PHeapPtr (CBuildTuplePtr tuple_arity), p_atpExprVarScope = [first, second: rest], p_atpResult = expr}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseType :: Parser CLexeme PType
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseType
	= (     parseTypeHead
	    <&> parseTypeTail
	  ) <@ (\(type,f) -> f type)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeAnnotation :: Parser CLexeme (Maybe PType)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeAnnotation
	=      (     Symbol (CReserved "::")
	          &> parseType
	       ) <@ Just
	   <|> Succeed Nothing 

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeHead :: Parser CLexeme PType
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeHead
	= (     (parseBasicType <@ PBasic)
	    <|> (     parseName
	          <&> <*> parseType
	        ) <@ (\(name, types) -> PTApp (PNamedPtr {quaName = name, quaModuleName = Nothing}) types)
	    <|> (     Symbol (CReserved "(")
	           &> parseType
	          <&  Symbol (CReserved ")")
	        )
	    <|> (     Symbol (CReserved "[")
	           &> parseType
	          <&  Symbol (CReserved "]")
	        ) <@ (\type -> PTApp (PHeapPtr CListPtr) [type])
	    <|> (     Symbol (CReserved "{")
	           &> parseType
	          <&  Symbol (CReserved "}")
	        ) <@ (\type -> PTApp (PHeapPtr CNormalArrayPtr) [type])
	    <|> (     Symbol (CReserved "{!")
	           &> parseType
	          <&  Symbol (CReserved "}")
	        ) <@ (\type -> PTApp (PHeapPtr CStrictArrayPtr) [type])
	    <|> (     Symbol (CReserved "{#")
	           &> parseType
	          <&  Symbol (CReserved "}")
	        ) <@ (\type -> PTApp (PHeapPtr CUnboxedArrayPtr) [type])
	    <|> (     Symbol (CReserved "(")
	           &> parseType
	          <&> Symbol (CReserved ",")
	           &> parseType
	          <&  Symbol (CReserved ")")
	        ) <@ (\(type1, type2) -> PTApp (PHeapPtr (CTuplePtr 2)) [type1,type2])
	    <|> (     Symbol (CReserved "(")
	           &> parseType
	          <&> Symbol (CReserved ",")
	           &> parseType
	          <&> Symbol (CReserved ",")
	           &> parseType
	          <&  Symbol (CReserved ")")
	        ) <@ (\(type1, (type2, type3)) -> PTApp (PHeapPtr (CTuplePtr 3)) [type1,type2,type3])
	  )

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeTail :: Parser CLexeme (PType -> PType)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTypeTail
	= (     (    Symbol (CReserved "->")
	          &> parseType
	        ) <@ (\type2 type1 -> PArrow type1 type2)
	    <|> Succeed id
	  )

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseVariable :: Parser CLexeme CName
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseVariable
	= parseName


















// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExpression :: ![CLexeme] -> (!Error, !PExpr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExpression lexemes
	# maybe_parse				= parseGraphExpr lexemes
	| isNothing maybe_parse		= (pushError (X_Parse "Unrecognized syntax.") OK, DummyValue)
	# (input_left, expr)		= fromJust maybe_parse
	| not (isEmpty input_left)	= (pushError (X_Parse "Unrecognized symbol.") OK, DummyValue)
	= (OK, expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProposition :: ![CLexeme] -> (!Error, !PProp)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProposition lexemes
	# maybe_parse				= parseProp lexemes
	| isNothing maybe_parse		= (pushError (X_Parse "Unrecognized syntax.") OK, DummyValue)
	# (input_left, prop)		= fromJust maybe_parse
	| not (isEmpty input_left)	= (pushError (X_Parse "Unrecognized symbol.") OK, DummyValue)
	= (OK, prop)

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildPropQuantors :: !PProp -> PProp
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildPropQuantors prop
	= change_expr_quantors (find_prop_vars prop) prop
	where
		change_expr_quantors :: ![CName] !PProp -> PProp
		change_expr_quantors names (PExprForall name mb_type p)
			| isMember name names	= PPropForall name (change_expr_quantors names p)
			= PExprForall name mb_type (change_expr_quantors names p)
		change_expr_quantors names (PPropForall name p)
			= PPropForall name (change_expr_quantors names p)
		change_expr_quantors names (PExprExists name mb_type p)
			| isMember name names	= PPropExists name (change_expr_quantors names p)
			= PExprExists name mb_type (change_expr_quantors names p)
		change_expr_quantors names (PPropExists name p)
			= PPropExists name (change_expr_quantors names p)
		change_expr_quantors names p
			= p
		
		find_prop_vars :: !PProp -> [CName]
		find_prop_vars PTrue					= []
		find_prop_vars PFalse					= []
		find_prop_vars (PEqual e1 e2)			= []
		find_prop_vars (PPropVar name)			= [name]
		find_prop_vars (PNot p)					= find_prop_vars p
		find_prop_vars (PAnd p q)				= find_prop_vars p ++ find_prop_vars q
		find_prop_vars (POr p q)				= find_prop_vars p ++ find_prop_vars q
		find_prop_vars (PImplies p q)			= find_prop_vars p ++ find_prop_vars q
		find_prop_vars (PIff p q)				= find_prop_vars p ++ find_prop_vars q
		find_prop_vars (PExprForall var _ p)	= find_prop_vars p
		find_prop_vars (PExprExists var _ p)	= find_prop_vars p
		find_prop_vars (PPropForall var p)		= find_prop_vars p
		find_prop_vars (PPropExists var p)		= find_prop_vars p
		find_prop_vars (PPredicate name es)		= []
		find_prop_vars (PBracketProp p)			= find_prop_vars p

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProofCommand :: ![CLexeme] -> (!Error, !PProofCommand)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProofCommand lexemes
	# maybe_parse				= parseCommandDot lexemes
	| isNothing maybe_parse		= (pushError (X_Parse "Unrecognized syntax.") OK, DummyValue)
	# (input_left, tactic)		= fromJust maybe_parse
	| not (isEmpty input_left)	= (pushError (X_Parse "Unrecognized symbol.") OK, DummyValue)
	= (OK, tactic)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArguments :: ![CLexeme] -> (!Error, ![PFactArgument])
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArguments lexemes
	# maybe_parse				= <*> parseFactArgument lexemes
	| isNothing maybe_parse		= (pushError (X_Parse "Unrecognized syntax.") OK, DummyValue)
	# (input_left, args)		= fromJust maybe_parse
	| not (isEmpty input_left)	= (pushError (X_Parse "Unrecognized symbol.") OK, DummyValue)
	= (OK, args)