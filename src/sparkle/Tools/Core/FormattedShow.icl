/*
** Program: Clean Prover System
** Module:  FormattedShow (.icl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

implementation module 
	FormattedShow

import
	StdEnv,
	MarkUpText,
	CoreTypes,
	CoreAccess,
	Operate,
	ProveTypes,
	Heaps,
	Print,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
KeywordColour	:== Grey									// 'case', 'in', 'of'
LogicColour		:== RGB {r=  0, g=150, b= 75}				// fg; quantors + logical connectives
LogicDarkColour	:== RGB {r=  0, g=100, b= 25}
VarColour		:== RGB {r= 81, g= 81, b= 41}
VarIndexColour	:== RGB {r=151, g=151, b=111}

Brown			:== RGB {r=180, g=130, b=100}
DarkBrown		:== RGB {r=150, g=110, b= 70}

DisplayMaxDepth	:== 25
DisplayError	:==	[ CmBackgroundColour		Red
					, CmColour					Yellow
					, CmBText					"!Display Error: Expression Too Large!"
					, CmEndColour
					, CmEndBackgroundColour
					]
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DisplayOptions =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ optShowRecordFuns				:: !Bool
	, optShowRecordCreation			:: !Bool
	, optShowArrayFuns				:: !Bool
	, optShowTupleFuns				:: !Bool
	, optShowDictionaries			:: !Bool
	, optShowInstanceTypes			:: !Bool
	, optShowVariableIndexes		:: !Bool
	, optShowPatterns				:: !Bool
	, optShowLetsAndCases			:: !Bool
	, optShowSharing				:: !Bool
	, optShowIndents				:: !Bool				// in Theorem Window only
	, optAlwaysBrackets				:: !Bool
	, optShowIsTrue					:: !Bool
	, optExtendedForalls			:: !Bool
	
	, optDefinitionWindowBG			:: !ExtendedColour
	, optDefinitionListWindowBG		:: !ExtendedColour
	, optHintWindowBG				:: !ExtendedColour
	, optProjectCenterBG			:: !ExtendedColour
	, optProofWindowBG				:: !ExtendedColour
	, optSectionCenterBG			:: !ExtendedColour
	, optTacticDialogBG				:: !ExtendedColour
	, optTacticListBG				:: !ExtendedColour
	, optTheoremWindowBG			:: !ExtendedColour
	, optTheoremListWindowBG		:: !ExtendedColour

	, optStartWithAboutDialog		:: !Bool
	}
instance DummyValue DisplayOptions
	where DummyValue =	{ optShowRecordFuns				= False
						, optShowRecordCreation			= False
						, optShowArrayFuns				= False
						, optShowTupleFuns				= False
						, optShowDictionaries			= False
						, optShowInstanceTypes			= False
						, optShowVariableIndexes		= False
						, optShowPatterns				= True
						, optShowLetsAndCases			= False
						, optShowSharing				= True
						, optShowIndents				= True
						, optAlwaysBrackets				= False
						, optShowIsTrue					= False
						, optExtendedForalls			= False
						
						, optDefinitionWindowBG			= DummyValue
						, optDefinitionListWindowBG		= DummyValue
						, optHintWindowBG				= DummyValue
						, optProjectCenterBG			= DummyValue
						, optProofWindowBG				= DummyValue
						, optSectionCenterBG			= DummyValue
						, optTacticDialogBG				= DummyValue
						, optTacticListBG				= DummyValue
						, optTheoremWindowBG			= DummyValue
						, optTheoremListWindowBG		= DummyValue
						
						, optStartWithAboutDialog		= True
						}

// Mirror in AnnotatedShow
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DisplaySpecial =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ disForall						:: Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disExists						:: Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disAnd						:: (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disOr							:: (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disNot						:: (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disImplies					:: Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disIff						:: (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, disBottom						:: MarkUpText WindowCommand
	, disUnequals					:: MarkUpText WindowCommand
	, disIsSpecial					:: !Bool
	}
instance DummyValue DisplaySpecial
	where DummyValue =	{ disForall		= \n p -> [CmColour LogicColour, CmBText "[", CmEndColour] ++ p ++ [CmColour LogicColour, CmBText "]", CmEndColour]
						, disExists		= \n p -> [CmColour LogicColour, CmBText "{", CmEndColour] ++ p ++ [CmColour LogicColour, CmBText "}", CmEndColour]
						, disAnd		= \p q -> p ++ [CmColour LogicColour, CmBText " /\\ ", CmEndColour] ++ q
						, disOr			= \p q -> p ++ [CmColour LogicColour, CmBText " \\/ ", CmEndColour] ++ q
						, disNot		= \p -> [CmColour LogicColour, CmBText "~", CmEndColour] ++ p
						, disImplies	= \i p q -> p ++ [CmColour LogicColour, CmBText (if i "-> " " -> "), CmEndColour] ++ q
						, disIff		= \p q -> p ++ [CmColour LogicColour, CmBText " <-> ", CmEndColour] ++ q
						, disBottom		= [CmColour Red, CmBText "_|_", CmEndColour]
						, disUnequals	= [CmText "<>"]
						, disIsSpecial	= False
						}

// ------------------------------------------------------------------------------------------------------------------------   
:: ExtendedColour =
// ------------------------------------------------------------------------------------------------------------------------   
	{ exRed					:: !Int
	, exGreen				:: !Int
	, exBlue				:: !Int
	, exHue					:: !Int
	, exLum					:: !Int
	, exSat					:: !Int
	}
instance DummyValue ExtendedColour
	where DummyValue = {exRed = 0, exGreen = 0, exBlue = 0, exHue = 0, exLum = 0, exSat = 0}
instance == ExtendedColour
	where (==) c1 c2 = c1.exRed == c2.exRed && c1.exGreen == c2.exGreen && c1.exBlue == c2.exBlue
toColour :: !Int !ExtendedColour -> Colour
toColour offset extended_colour
	= RGB {r = extended_colour.exRed + offset, g = extended_colour.exGreen + offset, b = extended_colour.exBlue + offset}

// =================================================================================================================================================
// Used to determine where brackets are required when showing a proposition.
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: PropPosition =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  LeftOfAnd
	| RightOfAnd
	| LeftOfOr
	| RightOfOr
	| LeftOfImplies
	| RightOfImplies
	| LeftOfIff
	| RightOfIff
instance == PropPosition
	where	(==) LeftOfAnd			LeftOfAnd			= True
			(==) RightOfAnd			RightOfAnd			= True
			(==) LeftOfOr			LeftOfOr			= True
			(==) RightOfOr			RightOfOr			= True
			(==) LeftOfImplies		LeftOfImplies		= True
			(==) RightOfImplies		RightOfImplies		= True
			(==) LeftOfIff			LeftOfIff			= True
			(==) RightOfIff			RightOfIff			= True
			(==) _					_					= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FormatInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{	fiNeedBrackets				:: !Bool
	,	fiPreviousPriority			:: !Maybe Int
	,	fiPreviousApplicationPtr	:: !Maybe HeapPtr
	,	fiPosition					:: !Maybe PropPosition
	,	fiOverrideNoBrackets		:: !Bool
	,	fiIsPattern					:: !Bool
	,	fiHeadPtr					:: !HeapPtr
	,	fiPassed					:: ![CSharedPtr]
	,	fiSpecial					:: !DisplaySpecial
	,	fiOptions					:: !DisplayOptions
	,	fiNextVarNum				:: !Int
	,	fiIndentQuantors			:: !Bool
	,	fiBigIndentSkip				:: !Bool
	,	fiIndentImplies				:: !Bool
	,	fiIndentEqual				:: !Bool
	,	fiPrettyTypes				:: ![CTypeH]						// used in AnnotatedShow
	}
instance DummyValue FormatInfo
	where DummyValue =	{ fiNeedBrackets			= False
						, fiPreviousPriority		= Nothing
						, fiPreviousApplicationPtr	= Nothing
						, fiPosition				= Nothing
						, fiOverrideNoBrackets		= False
						, fiIsPattern				= False
						, fiHeadPtr					= DummyValue
						, fiPassed					= []
						, fiSpecial					= DummyValue
						, fiOptions					= DummyValue
						, fiNextVarNum				= 0
						, fiIndentQuantors			= False
						, fiBigIndentSkip			= False
						, fiIndentImplies			= False
						, fiIndentEqual				= False
						, fiPrettyTypes				= []
						}

// -------------------------------------------------------------------------------------------------------------------------------------------------
class FormattedShow cdef :: !FormatInfo !cdef !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
Separate :: !Bool !(MarkUpText a) ![MarkUpText a] -> MarkUpText a
Separate first separator ftexts
	| isEmpty ftexts	= []
	| first				= flatten (map (\ftext -> separator ++ ftext) ftexts)
	| otherwise			= (hd ftexts) ++ (flatten (map (\ftext -> separator ++ ftext) (tl ftexts)))
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
changeColour :: !Int !Colour -> Colour
// -------------------------------------------------------------------------------------------------------------------------------------------------
changeColour delta (RGB rgb)
	= RGB {r = rgb.r + delta, g = rgb.g + delta, b = rgb.b + delta}
changeColour _ colour
	= colour

// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize :: !(MarkUpText a) -> MarkUpText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize [CmColour _:ftext]				= normalize ftext
normalize [CmEndColour:ftext]				= normalize ftext
normalize [CmBackgroundColour _:ftext]		= normalize ftext
normalize [CmEndBackgroundColour:ftext]		= normalize ftext
normalize [CmBold:ftext]					= normalize ftext
normalize [CmEndBold:ftext]					= normalize ftext
normalize [CmItalic:ftext]					= normalize ftext
normalize [CmEndItalic:ftext]				= normalize ftext
normalize [CmBText text:ftext]				= [CmText text: normalize ftext]
normalize [CmIText text:ftext]				= [CmText text: normalize ftext]
normalize [CmLink text _:ftext]				= [CmText text: normalize ftext]
normalize [command:ftext]					= [command: normalize ftext]
normalize []								= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeForalls :: !CPropH -> CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeForalls (CExprForall _ p)				= removeForalls p
removeForalls (CPropForall _ p)				= removeForalls p
removeForalls p								= p

// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprInProp :: !CPropH -> CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
getExprInProp (CEqual e1 CBottom)			= e1
getExprInProp _								= CBottom

// -------------------------------------------------------------------------------------------------------------------------------------------------
isSpecialCaseOrLet :: !CExprH -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isSpecialCaseOrLet (CLet strict bindings expr)
	= True
isSpecialCaseOrLet (CCase case_expr (CBasicPatterns basictype [basicpattern]) maybe_default)
	= isBasicTrue basicpattern.bapBasicValue
	where
		isBasicTrue (CBasicBoolean True)	= True
		isBasicTrue _						= False
isSpecialCaseOrLet other
	= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
isDictionaryName :: !String -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
isDictionaryName name
	# list					= [c \\ c <-: name]
	| length list < 2		= False
	= (take 2 list) == ['_v']










// -------------------------------------------------------------------------------------------------------------------------------------------------
showIndex :: !String -> MarkUpText a
// ------------------------------------------------------------------------------------------------------------------------------------------------
showIndex index
	= [CmColour VarIndexColour, CmFontFace "Times New Roman", CmSize 6, CmBText index, CmEndSize, CmEndFontFace, CmEndColour]

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeExprVar :: !CExprVarPtr !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeExprVar ptr finfo=:{fiNextVarNum} heaps
	# (var, heaps)							= readPointer ptr heaps
	# var									= {var & evarInfo = EVar_Num fiNextVarNum}
	= ({finfo & fiNextVarNum = fiNextVarNum+1}, writePointer ptr var heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeExprVars :: ![CExprVarPtr] !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeExprVars [] finfo heaps
	= (finfo, heaps)
storeExprVars [ptr:ptrs] finfo heaps
	# (finfo, heaps)						= storeExprVar ptr finfo heaps
	= storeExprVars ptrs finfo heaps

// -------------------------------------------------------------------------------------------------------------------------------------------------
storePropVar :: !CPropVarPtr !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storePropVar ptr finfo=:{fiNextVarNum} heaps
	# (var, heaps)							= readPointer ptr heaps
	# var									= {var & pvarInfo = PVar_Num fiNextVarNum}
	= ({finfo & fiNextVarNum = fiNextVarNum+1}, writePointer ptr var heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storePropVars :: ![CPropVarPtr] !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storePropVars [] finfo heaps
	= (finfo, heaps)
storePropVars [ptr:ptrs] finfo heaps
	# (finfo, heaps)						= storePropVar ptr finfo heaps
	= storePropVars ptrs finfo heaps















// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprVar :: !FormatInfo !Bool !CExprVarPtr !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprVar finfo in_quantor ptr heaps prj
	# (var, heaps)							= readPointer ptr heaps
	# show_dicts							= finfo.fiOptions.optShowDictionaries
	# show_index							= finfo.fiOptions.optShowVariableIndexes
	# is_dict								= isDictionaryName var.evarName
	| is_dict && not show_dicts				= (OK, [], heaps, prj)
	| var.evarName == "_"					= (OK, [CmText "_"], heaps, prj)
	# index									= make_index var.evarInfo
	= case show_index of
		True	-> (OK, add_colour in_quantor ([CmText var.evarName] ++ (showIndex index)), heaps, prj)
		False	-> (OK, add_colour in_quantor [CmText var.evarName], heaps, prj)
	where
		make_index :: !CExprVarInfo -> String
		make_index (EVar_Num index)
			= toString index
		make_index _
			= "?"
		
		add_colour :: !Bool !(MarkUpText a) -> MarkUpText a
		add_colour True text				= normalize text
		add_colour False text				= [CmColour VarColour:text] ++ [CmEndColour]
		
		normalize :: !(MarkUpText a) -> MarkUpText a
		normalize [CmColour _:commands]		= normalize commands
		normalize [CmEndColour:commands]	= normalize commands
		normalize [command:commands]		= [command: normalize commands]
		normalize []						= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowMaybeExprVar :: !FormatInfo !(Maybe CExprVarPtr) !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowMaybeExprVar finfo Nothing heaps prj
	= (OK, [CmText "_"], heaps, prj)
ShowMaybeExprVar finfo (Just ptr) heaps prj
	= ShowExprVar finfo False ptr heaps prj

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprScope :: !FormatInfo ![CExprVarPtr] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprScope finfo [] heaps prj
	= (OK, [], heaps, prj)
ShowExprScope finfo [var:vars] heaps prj
	# (error, fvar, heaps, prj)				= ShowExprVar finfo False var heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isEmpty vars							= (OK, fvar, heaps, prj)
	# (error, fvars, heaps, prj)			= ShowExprScope finfo vars heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	| isEmpty fvar							= (OK, fvars, heaps, prj)
	= (OK, fvar ++ [CmText " "] ++ fvars, heaps, prj)

// =================================================================================================================================================
// Produce (x, y, z). Needed for let-definitions where the lhs is a tuple.
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprVarTuple :: !FormatInfo ![Maybe CExprVarPtr] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowExprVarTuple finfo vars heaps prj
	# (error, fvars, heaps, prj)			= uumapError (ShowMaybeExprVar finfo) vars heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, [CmText "("] ++ (Separate False [CmText ", "] fvars) ++ [CmText ")"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowTypeVar :: !FormatInfo !CTypeVarPtr !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowTypeVar finfo ptr heaps
	# (var, heaps)							= readPointer ptr heaps
	= ([CmText var.tvarName], heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowTypeScope :: !FormatInfo ![CTypeVarPtr] !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowTypeScope finfo [] heaps
	= ([], heaps)
ShowTypeScope finfo [var:vars] heaps
	# (fvar, heaps)							= ShowTypeVar finfo var heaps
	| isEmpty vars							= (fvar, heaps)
	# (fvars, heaps)						= ShowTypeScope finfo vars heaps
	| isEmpty fvar							= (fvars, heaps)
	= (fvar ++ [CmText " "] ++ fvars, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowPropVar :: !FormatInfo !Bool !CPropVarPtr !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
ShowPropVar finfo in_quantor ptr heaps
	# (var, heaps)							= readPointer ptr heaps
	# show_index							= finfo.fiOptions.optShowVariableIndexes
	# index									= make_index var.pvarInfo
	= case show_index of
		True	-> (add_colour in_quantor ([CmText var.pvarName] ++ (showIndex index)), heaps)
		False	-> (add_colour in_quantor [CmText var.pvarName], heaps)
	where
		make_index :: !CPropVarInfo -> String
		make_index (PVar_Num index)
			= toString index
		make_index _
			= "?"
		
		add_colour :: !Bool !(MarkUpText a) -> MarkUpText a
		add_colour True text				= normalize text
		add_colour False text				= [CmColour VarColour:text] ++ [CmEndColour]
		
		normalize :: !(MarkUpText a) -> MarkUpText a
		normalize [CmColour _:commands]		= normalize commands
		normalize [CmEndColour:commands]	= normalize commands
		normalize [command:commands]		= [command: normalize commands]
		normalize []						= []




















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CAlgPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo pattern heaps prj
		# (finfo, heaps)					= storeExprVars pattern.atpExprVarScope finfo heaps
		| pattern.atpDataCons == CNilPtr	= show_nil_pattern finfo pattern.atpResult heaps prj
		| pattern.atpDataCons == CConsPtr	= show_cons_pattern finfo (pattern.atpExprVarScope!!0) (pattern.atpExprVarScope!!1) pattern.atpResult heaps prj
		# (error, consdef, prj)				= getDataConsDef pattern.atpDataCons prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fname								= [CmText consdef.dcdName]
		# (error, fscope, heaps, prj)		= ShowExprScope finfo pattern.atpExprVarScope heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fscope							= if (isEmpty fscope) [] [CmText " ": fscope]
		# (error, fresult, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} pattern.atpResult heaps prj
		# (error, rectype, prj)				= getRecordTypeDef consdef.dcdAlgType prj
		| isOK error						= show_record_pattern rectype fresult heaps prj
		= (OK, fname ++ fscope ++ [CmAlign "case", CmText " -> ": fresult], heaps, prj)
		where
			show_record_pattern :: !CRecordTypeDefH !(MarkUpText WindowCommand) !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
			show_record_pattern rectype fresult heaps prj
				# (error, fields, prj)		= umapError getRecordFieldDef rectype.rtdFields prj
				| isError error				= (error, DummyValue, heaps, prj)
				# ffieldnames				= [[CmText name] \\ name <- map (\field -> field.rfName) fields]
				= (OK, [CmText "{"] ++ (Separate False [CmText ", "] ffieldnames) ++ [CmText "}", CmAlign "case", CmText " -> "] ++ fresult, heaps, prj)
			
			show_nil_pattern :: !FormatInfo !CExprH !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
			show_nil_pattern finfo result heaps prj
				# finfo							= {finfo & fiNeedBrackets = False}
				# (error, fresult, heaps, prj)	= FormattedShow finfo result heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, [CmText "[]"] ++ [CmAlign "case", CmText " -> ": fresult], heaps, prj)
			
			show_cons_pattern :: !FormatInfo !CExprVarPtr !CExprVarPtr !CExprH !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
			show_cons_pattern finfo head tail result heaps prj
				# finfo							= {finfo & fiNeedBrackets = False}
				# (error, fhead, heaps, prj)	= ShowExprScope finfo [head] heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				# (error, ftail, heaps, prj)	= ShowExprScope finfo [tail] heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				# (error, fresult, heaps, prj)	= FormattedShow finfo result heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, [CmText "["] ++ fhead ++ [CmText ":"] ++ ftail ++ [CmText "]", CmAlign "case", CmText " -> ": fresult], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CAlgTypeDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo algtype heaps prj
		# fname								= [CmBold, CmText algtype.atdName, CmEndBold]
		# (fscope, heaps)					= ShowTypeScope finfo algtype.atdTypeVarScope heaps
		# fscope							= if (isEmpty fscope) [] [CmText " ":fscope]
		# (error, conses, prj)				= umapError getDataConsDef algtype.atdConstructors prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, fconses, heaps, prj)		= uumapError (FormattedShow finfo) conses heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| isEmpty fconses					= (OK, fname ++ fscope ++ [CmItalic, CmText " (no data-constructors)"], heaps, prj)
		# ftail								= Separate True [CmNewline, CmAlign "|", CmText "| ", CmAlign "datacons"] (tl fconses)
		= (OK, [CmText ":: "] ++ fname ++ fscope ++ [CmText " ", CmAlign "|", CmText "= ", CmAlign "datacons"] ++ (hd fconses) ++ ftail, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CBasicPattern HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo pattern heaps prj
		# (error, fvalue, heaps, prj)		= FormattedShow finfo pattern.bapBasicValue heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, fresult, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} pattern.bapResult heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, fvalue ++ [CmAlign "case", CmText " -> ": fresult], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow CBasicType
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo CInteger heaps prj
		= (OK, [CmText "Int"], heaps, prj)
	FormattedShow finfo CCharacter heaps prj
		= (OK, [CmText "Char"], heaps, prj)
	FormattedShow finfo CRealNumber heaps prj
		= (OK, [CmText "Real"], heaps, prj)
	FormattedShow finfo CBoolean heaps prj
		= (OK, [CmText "Bool"], heaps, prj)
	FormattedShow finfo CString heaps prj
		= (OK, [CmText "{#Char}"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CBasicValue HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (CBasicInteger num) heaps prj
		= (OK, [CmColour Red, CmText (toString num), CmEndColour], heaps, prj)
	FormattedShow finfo (CBasicCharacter char) heaps prj
		= (OK, [CmColour Red, CmText "'", CmText (toString char), CmText "'", CmEndColour], heaps, prj)
	FormattedShow finfo (CBasicRealNumber real) heaps prj
		= (OK, [CmColour Red, CmText (toString real), CmEndColour], heaps, prj)
	FormattedShow finfo (CBasicBoolean bool) heaps prj
		= (OK, [CmColour Red, CmText (toString bool), CmEndColour], heaps, prj)
	FormattedShow finfo (CBasicString string) heaps prj
		= (OK, [CmColour Red, CmText "\"", CmText string, CmText "\"", CmEndColour], heaps, prj)
	FormattedShow finfo (CBasicArray list) heaps prj
		# (error, flist, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = False}) list heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, [CmText "{"] ++ (Separate False [CmText ", "] flist) ++ [CmText "}"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CCasePatterns HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (CAlgPatterns _ patterns) heaps prj
		# (error, fpatterns, heaps, prj)	= uumapError (FormattedShow finfo) patterns heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, Separate True [CmNewline, CmTabSpace] fpatterns, heaps, prj)
	FormattedShow finfo (CBasicPatterns _ patterns) heaps prj
		# (error, fpatterns, heaps, prj)	= uumapError (FormattedShow finfo) patterns heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, Separate True [CmNewline, CmTabSpace] fpatterns, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CClassDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo classdef heaps prj
		# fstart							= [CmColour Grey, CmText "class ", CmEndColour, CmBText classdef.cldName]
		# (fscope, heaps)					= ShowTypeScope finfo classdef.cldTypeVarScope heaps
		# fscope							= if (isEmpty fscope) [] ([CmText " "] ++ fscope)
		# (error, frestrictions, heaps, prj)= uumapError (FormattedShow finfo) classdef.cldClassRestrictions heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# frestrictions						= if (isEmpty frestrictions) [] ([CmText " | "] ++ (Separate False [CmText " & "] frestrictions))
		# (error, dict_name, heaps, prj)	= getDefinitionName classdef.cldDictionary heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, members, prj)				= umapError getMemberDef classdef.cldMembers prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, fmembers, heaps, prj)		= uumapError (FormattedShow finfo) members heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| isEmpty fmembers					= (OK, fstart ++ fscope ++ frestrictions, heaps, prj)
		# fmembers							= Separate True [CmNewline, CmTabSpace] fmembers
		= (OK, fstart ++ fscope ++ frestrictions ++ [CmNewline, CmColour Grey, CmText "where", CmEndColour] ++ fmembers, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CClassRestriction HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo restriction heaps prj
		# (error, ftypes, heaps, prj)		= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) restriction.ccrTypes heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, classname, heaps, prj)	= getDefinitionName restriction.ccrClass heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fclass							= case (finfo.fiHeadPtr == restriction.ccrClass) of
												True	-> [CmText classname]
												False	-> [CmLink classname (CmdShowDefinition restriction.ccrClass)]
		= (OK, fclass ++ (Separate True [CmText " "] ftypes), heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CDataConsDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo consdef heaps prj
		# finfo								= {finfo & fiOptions.optShowDictionaries = True}
		# name								= if (isInfix consdef.dcdInfix) ("(" +++ consdef.dcdName +++ ")") consdef.dcdName
		# fname								= [CmBold, CmText name, CmEndBold]
		# (error, finfix, heaps, prj)		= FormattedShow finfo consdef.dcdInfix heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fstart							= if (isInfix consdef.dcdInfix) (fname ++ [CmText " "] ++ finfix) fname
		# (fscope, heaps)					= ShowTypeScope finfo consdef.dcdTypeVarScope heaps
		# fscope							= if (isEmpty fscope) [] (fscope ++ [CmText " "])
		# (error, ftype, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} consdef.dcdSymbolType heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, fscope ++ fstart ++ [CmAlign "dataconstype", CmText " "] ++ ftype, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showArrayCreation :: !Int ![MarkUpText WindowCommand] -> (!Bool, !MarkUpText WindowCommand)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showArrayCreation arity updates
	| arity == (-1)							= (False, [])
	# results								= map (get_element updates) [0..arity-1]
	# oks									= map fst results
	| not (and oks)							= (False, [])
	= (True, [CmText "{"] ++ (Separate False [CmText ", "] (map snd results)) ++ [CmText "}"])
	where
		get_element :: ![MarkUpText WindowCommand] !Int -> (!Bool, !MarkUpText WindowCommand)
		get_element [update: updates] num
			| length update < 5				= (False, [])
			# the_cm_text					= update !! 2      // 0 = '[', 1 = clr, 2 = num, 3 = endclr, 4 = '] ='
			# ok							= case the_cm_text of
												CmText text		-> toString num == text
												_				-> False
			| ok							= (True, drop 5 update)
			= get_element updates num
		get_element [] num
			= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
collectUpdates :: !FormatInfo !(CExpr HeapPtr) !*CHeaps !*CProject
			   -> (!Error, !Int, !MarkUpText WindowCommand, ![MarkUpText WindowCommand], !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
collectUpdates finfo expr=:(ptr @@# exprs) heaps prj
	| ptrKind ptr <> CFun
		# (error, fexpr, heaps, prj)		= FormattedShow finfo expr heaps prj
		| isError error						= (error, (-1), DummyValue, DummyValue, heaps, prj)
		= (OK, (-1), fexpr, [], heaps, prj)
	# modptr								= ptrModule ptr
	# transform								= (\arity (a,b,c,d) -> (a, arity, b, [], c, d))
	# (modname, heaps)						= getPointerName modptr heaps
	| modname <> "StdArray"					= transform (-1) (FormattedShow finfo expr heaps prj)
	# (error, fundef, prj)					= getFunDef ptr prj
	| isError error							= (error, (-1), DummyValue, DummyValue, heaps, prj)
	| fundef.fdName == "_createArray"		= case (hd exprs) of
												CBasicValue (CBasicInteger num)	-> transform num  (FormattedShow finfo expr heaps prj)
												_								-> transform (-1) (FormattedShow finfo expr heaps prj)
	| fundef.fdName <> "update"				= transform (-1) (FormattedShow finfo expr heaps prj)
	| length exprs <> 3						= transform (-1) (FormattedShow finfo expr heaps prj)
	# (error, findexexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} (hd (tl exprs)) heaps prj
	| isError error							= (error, (-1), DummyValue, DummyValue, heaps, prj)
	# (error, fupdateexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} (hd (tl (tl exprs))) heaps prj
	| isError error							= (error, (-1), DummyValue, DummyValue, heaps, prj)
	# fupdate								= [CmText "["] ++ findexexpr ++ [CmText "] = "] ++ fupdateexpr
	# (error, arity, fexpr, fupdates, heaps, prj)	
											= collectUpdates finfo (hd exprs) heaps prj
	| isError error							= (error, (-1), DummyValue, DummyValue, heaps, prj)
	= (OK, arity, fexpr, [fupdate: fupdates], heaps, prj)
collectUpdates finfo expr=:(update_expr @# [array_expr, index_expr, with_expr]) heaps prj
	= collect_updates finfo update_expr heaps prj
	where
		transform = (\arity (a,b,c,d) -> (a, arity, b, [], c, d))
		collect_updates finfo subexpr=:(ptr @@# [dict_expr]) heaps prj
			| ptrKind ptr <> CFun						= transform (-1) (FormattedShow finfo subexpr heaps prj)
			# modptr									= ptrModule ptr
			# (modname, heaps)							= getPointerName modptr heaps
			| modname <> "StdArray"						= transform (-1) (FormattedShow finfo expr heaps prj)
			# (error, fundef, prj)						= getFunDef ptr prj
			| isError error								= (error, (-1), DummyValue, DummyValue, heaps, prj)
			| fundef.fdName <> "_dictionary_Array_select_update"
														= transform (-1) (FormattedShow finfo expr heaps prj)
			# (error, index_fexpr, heaps, prj)			= FormattedShow {finfo & fiNeedBrackets = False} index_expr heaps prj
			| isError error								= (error, (-1), DummyValue, DummyValue, heaps, prj)
			# (error, with_fexpr, heaps, prj)				= FormattedShow {finfo & fiNeedBrackets = False} with_expr heaps prj
			| isError error								= (error, (-1), DummyValue, DummyValue, heaps, prj)
			# fupdate									= [CmText "["] ++ index_fexpr ++ [CmText "] = "] ++ with_fexpr
			# (error, arity, fexpr, fupdates, heaps, prj)
														= collectUpdates finfo array_expr heaps prj
			| isError error								= (error, (-1), DummyValue, DummyValue, heaps, prj)
			= (OK, arity, fexpr, [fupdate: fupdates], heaps, prj)
		collect_updates finfo other heaps prj
			= transform (-1) (FormattedShow finfo expr heaps prj)
collectUpdates finfo expr=:(create_expr @# [num_expr]) heaps prj
	= collect_create finfo create_expr heaps prj
	where
		transform = (\arity (a, b, c, d) -> (a, arity, b, [], c, d))
		collect_create finfo subexpr=:(ptr @@# [dict_expr]) heaps prj
			| ptrKind ptr <> CFun						= transform (-1) (FormattedShow finfo expr heaps prj)
			# modptr									= ptrModule ptr
			# (modname, heaps)							= getPointerName modptr heaps
			| modname <> "StdArray"						= transform (-1) (FormattedShow finfo expr heaps prj)
			# (error, fundef, prj)						= getFunDef ptr prj
			| isError error								= (error, (-1), DummyValue, DummyValue, heaps, prj)
			| fundef.fdName <> "_dictionary_Array_select__createArray"
														= transform (-1) (FormattedShow finfo expr heaps prj)
			= case num_expr of
				CBasicValue (CBasicInteger num)	-> transform num  (FormattedShow finfo expr heaps prj)
				_								-> transform (-1) (FormattedShow finfo expr heaps prj)
		collect_create finfo other heaps prj
			= transform (-1) (FormattedShow finfo expr heaps prj)
collectUpdates finfo other heaps prj
	# (error, fexpr, heaps, prj)			= FormattedShow finfo other heaps prj
	| isError error							= (error, (-1), DummyValue, DummyValue, heaps, prj)
	= (OK, (-1), fexpr, [], heaps, prj)

// =================================================================================================================================================
// Needed for FormattedShow (Expr): alternative to show tuple-selections in lets
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: ShowLet =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ slLeft		:: !CExprVarPtr
	, slIsTuple		:: !Bool
	, slTuple		:: ![Maybe CExprVarPtr]
	, slRight		:: !CExprH
	, slStrict		:: !Bool
	, slHide		:: !Bool
	}

// =================================================================================================================================================
// Needed for FormattedShow (Expr): alternative to show tuple-selections in lets
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildShowLets :: !FormatInfo !CIsStrict ![(CExprVarPtr, CExprH)] -> [ShowLet]
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildShowLets finfo strict lets
	# show_tuples							= finfo.fiOptions.optShowTupleFuns
	| show_tuples							= [{slLeft = var, slIsTuple = False, slTuple = [], slRight = expr, slStrict = strict, slHide = False} \\ (var, expr) <- lets]
	# shown									= add_to_showlets lets []
	# tuple_vars							= get_tuple_vars shown
	# (tuple_vars, shown)					= find_rhs tuple_vars shown
	# shown									= fillin_tuple_vars tuple_vars shown
	= [{show & slStrict = strict} \\ show <- shown]
	where
		add_to_showlets :: ![(CExprVarPtr, CExprH)] ![ShowLet] -> [ShowLet]
		add_to_showlets [(var,expr): lets] shown
			# shown							= addToShowLets var expr shown
			= add_to_showlets lets shown
		add_to_showlets [] shown
			= shown
		
		get_tuple_vars :: ![ShowLet] -> [(CExprVarPtr,CExprH)]
		get_tuple_vars [show:shown]
			| not show.slIsTuple			= get_tuple_vars shown
			= [(show.slLeft, CExprVar show.slLeft): get_tuple_vars shown]
		get_tuple_vars []
			= []
		
		find_rhs :: ![(CExprVarPtr,CExprH)] ![ShowLet] -> (![(CExprVarPtr,CExprH)], ![ShowLet])
		find_rhs vars [show:shown]
			| show.slIsTuple
				# (vars, shown)				= find_rhs vars shown
				= (vars, [show:shown])
			# (ok, vars)					= set_rhs vars show.slLeft show.slRight
			# show							= case ok of
												True	-> {show & slHide = True}
												False	-> show
			# (vars, shown)					= find_rhs vars shown
			= (vars, [show:shown])
			where
				set_rhs :: ![(CExprVarPtr,CExprH)] !CExprVarPtr !CExprH -> (!Bool, ![(CExprVarPtr,CExprH)])
				set_rhs [(var,expr):vars] new_var new_expr
					| var <> new_var
						# (ok, vars)		= set_rhs vars new_var new_expr
						= (ok, [(var,expr):vars])
//					| otherwise
						= (True, [(var,new_expr):vars])
				// BEZIG -- gokje??
				set_rhs [] new_var new_expr
					= (False, [])
		find_rhs vars []
			= (vars, [])
		
		fillin_tuple_vars :: ![(CExprVarPtr,CExprH)] ![ShowLet] -> [ShowLet]
		fillin_tuple_vars vars [show:shown]
			| not show.slIsTuple			= [show:fillin_tuple_vars vars shown]
			# filtered						= filter (\(ptr,expr) -> ptr == show.slLeft) vars
			| isEmpty filtered				= [show:fillin_tuple_vars vars shown]
			# show							= {show & slRight = snd (hd filtered)}
			= [show:fillin_tuple_vars vars shown]
		fillin_tuple_vars vars []
			= []

// =================================================================================================================================================
// Needed for FormattedShow (Expr): alternative to show tuple-selections in lets
// -------------------------------------------------------------------------------------------------------------------------------------------------
addToShowLets :: !CExprVarPtr !CExprH ![ShowLet] -> [ShowLet]
// -------------------------------------------------------------------------------------------------------------------------------------------------
addToShowLets var expr shown
	# (selector, tuplevar, total, sub)		= is_selector expr
	| not selector							= shown ++ [{slLeft = var, slIsTuple = False, slTuple = [], slRight = expr, slStrict = False, slHide = False}]
	= update_tuple var tuplevar sub total shown
	where
		is_selector :: !CExprH -> (!Bool, !CExprVarPtr, !Int, !Int)
		is_selector ((CTupleSelectPtr total sub) @@# [CExprVar ptr])
			= (True, ptr, total, sub)
		is_selector other
			= (False, nilPtr, 0, 0)
		
		update_tuple :: !CExprVarPtr !CExprVarPtr !Int !Int ![ShowLet] -> [ShowLet]
		update_tuple left_var tuple_var sub total [show:shown]
			| not show.slIsTuple			= [show: update_tuple left_var tuple_var sub total shown]
			| show.slLeft <> tuple_var		= [show: update_tuple left_var tuple_var sub total shown]
			# tuple							= updateAt (sub-1) (Just left_var) show.slTuple
			# show							= {show & slTuple = tuple}
			= [show:shown]
		update_tuple left_var tuple_var sub total []
			# tuple							= repeatn total Nothing
			# tuple							= updateAt (sub-1) (Just left_var) tuple
			# show							= {slLeft = tuple_var, slIsTuple = True, slTuple = tuple, slRight = CExprVar tuple_var, slStrict = False, slHide = False}
			= [show]

// =================================================================================================================================================
// Needed for FormattedShow (Expr): alternative to show tuple-selections in lets
// -------------------------------------------------------------------------------------------------------------------------------------------------
displayShowLets :: !FormatInfo ![ShowLet] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
displayShowLets finfo [show:shown] heaps prj
	| show.slHide							= displayShowLets finfo shown heaps prj
	# (error, fleft, heaps, prj)			= case show.slIsTuple of
												True	-> ShowExprVarTuple finfo show.slTuple heaps prj
												False	-> ShowExprVar finfo False show.slLeft heaps prj
	# (error, fexpr, heaps, prj)			= FormattedShow finfo show.slRight heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# fstart								= case finfo.fiOptions.optShowLetsAndCases of
												True	-> []
												False	-> case show.slStrict of
																True	-> [CmColour Grey, CmText "#! ", CmEndColour]
																False	-> [CmColour Grey, CmText "# ", CmEndColour]
	# (error, frest, heaps, prj)			= displayShowLets finfo shown heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	= (OK, fstart ++ [CmAlign "lc_start"] ++ fleft ++ [CmAlign "lc_end", CmText " = "] ++ fexpr ++
		   [CmNewline] ++ frest, heaps, prj)
displayShowLets finfo [] heaps prj
	= (OK, [], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CExpr HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (CExprVar ptr) heaps prj
		= ShowExprVar finfo False ptr heaps prj
	FormattedShow finfo (CShared ptr) heaps prj
		# show_sharing						= finfo.fiOptions.optShowSharing
		# (shared, heaps)					= readPointer ptr heaps
		| show_sharing
			# show_indexes					= finfo.fiOptions.optShowVariableIndexes
			# findex						= [CmColour VarIndexColour, CmChangeSize (-2), CmText (toString (ptrToInt ptr)), CmEndSize, CmEndColour]
			| show_indexes					= (OK, [CmText shared.shName: findex], heaps, prj)
			= (OK, [CmText shared.shName], heaps, prj)
		| isMember ptr finfo.fiPassed		= (OK, [CmIText "CYCLE_DETECTED"], heaps, prj)
		# finfo								= {finfo & fiPassed = [ptr:finfo.fiPassed]}
		= FormattedShow finfo shared.shExpr heaps prj
	FormattedShow finfo (expr @# exprs) heaps prj
		# oldfinfo							= finfo
		# finfo								= {finfo & fiPreviousPriority = Nothing, fiPreviousApplicationPtr = Nothing}
		# finfo								= {finfo & fiOptions.optShowLetsAndCases = True}
		# (error, cexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = True} expr heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, cexprs, heaps, prj)		= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) exprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, done, fresult, heaps, prj)= check_array_select_update finfo expr exprs cexpr cexprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| done								= (OK, fresult, heaps, prj)
		# (bool, ptr)						= case expr of 
												(appptr @@# args)	-> (True, appptr)
												_					-> (False, DummyValue)
		# (_, fundef, prj)					= getFunDef ptr prj
		| bool && fundef.fdIsRecordSelector	&& not finfo.fiOptions.optShowRecordFuns
											= record_select oldfinfo (to_text cexpr) fundef.fdRecordFieldDef exprs heaps prj
		= (OK, fresult, heaps, prj)
		where
			check_array_select_update finfo (ptr @@# args) exprs cexpr cexprs heaps prj
				# (error, fundef, prj)			= getFunDef ptr prj
				| isError error					= check_array_select_update finfo DummyValue exprs cexpr cexprs heaps prj
				| fundef.fdName == "_dictionary_Array_select_update" && not finfo.fiOptions.optShowArrayFuns && length exprs > 2
												= check_array_update finfo (hd exprs) (hd (tl cexprs)) (hd (tl (tl cexprs))) heaps prj
				| fundef.fdName <> "_dictionary_Array_select_select" || finfo.fiOptions.optShowArrayFuns
												= check_array_select_update finfo DummyValue exprs cexpr cexprs heaps prj
				| length exprs <> 2				= check_array_select_update finfo DummyValue exprs cexpr cexprs heaps prj
				# (error, findexexpr, heaps, prj)
												= FormattedShow {finfo & fiNeedBrackets = False} (hd (tl exprs)) heaps prj
				| isError error					= (error, False, DummyValue, heaps, prj)
				= (OK, True, (hd cexprs) ++ [CmText ".["] ++ findexexpr ++ [CmText "]"], heaps, prj)
				where
					check_array_update finfo update_expr index_fexpr with_fexpr heaps prj
						# fupdate										= [CmText "["] ++ index_fexpr ++ [CmText "] = "] ++ with_fexpr
						# (error, arity, fexpr, moreupdates,heaps,prj)	= collectUpdates finfo update_expr heaps prj
						| isError error									= (error, False, DummyValue, heaps, prj)
						# (createOK, ftexts)							= showArrayCreation arity [fupdate: moreupdates]
						| createOK										= (OK, True, ftexts, heaps, prj)
						# fallupdates									= Separate False [CmText ", "] (reverse [fupdate: moreupdates])
						= (OK, True, [CmText "{"] ++ fexpr ++ [CmText " & "] ++ fallupdates ++ [CmText "}"], heaps, prj)
			check_array_select_update finfo other exprs cexpr cexprs heaps prj
				# cexprs						= filter (not o isEmpty) cexprs
				# no_brackets					= cexpr ++ (Separate True [CmText " "] cexprs)
				| finfo.fiNeedBrackets			= (OK, False, [CmText "("] ++ no_brackets ++ [CmText ")"], heaps, prj)
				= (OK, False, no_brackets, heaps, prj)
			
			record_select finfo name fieldptr exprs heaps prj
				# finfo							= {finfo & fiOptions.optShowLetsAndCases = True}
				# (error, fielddef, prj)		= getRecordFieldDef fieldptr prj
				| isError error					= (error, DummyValue, heaps, prj)
				# (error, recorddef, prj)		= getRecordTypeDef fielddef.rfRecordType prj
				| isError error					= (error, DummyValue, heaps, prj)
				| not recorddef.rtdIsDictionary	= FormattedShowInfix finfo name CNoInfix fieldptr exprs heaps prj
				# (error, classdef, prj)		= getClassDef recorddef.rtdClassDef prj
				| isError error					= (error, DummyValue, heaps, prj)
				# (error, memberdef, prj)		= findMemberDef fielddef.rfName classdef.cldMembers prj
				| isError error					= (error, DummyValue, heaps, prj)
				# (error, ftext, heaps, prj)	= FormattedShowInfix finfo name memberdef.mbdInfix fieldptr exprs heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, ftext, heaps, prj)
				where
					findMemberDef name [memberptr: memberptrs] prj
						# (error, memberdef, prj)		= getMemberDef memberptr prj
						| isError error					= (error, DummyValue, prj)
						| memberdef.mbdName == name		= (OK, memberdef, prj)
						= findMemberDef name memberptrs prj
					findMemberDef name [] prj
						= (pushError (X_Internal "Could not match name of field in dictionary on a member of the class.") OK, DummyValue, prj)
		
			to_text [CmText text: rest]		= text +++ to_text rest
			to_text [CmLink text _: rest]	= text +++ to_text rest
			to_text [_: rest]				= to_text rest
			to_text []						= ""
	FormattedShow finfo (ptr @@# exprs) heaps prj
		# finfo								= {finfo & fiOptions.optShowLetsAndCases = True}
		# (ok, error, fpunt, heaps, prj)	= pretty_show_array_selection_update finfo ptr exprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| ok								= (OK, fpunt, heaps, prj)
		# (ok, error, fappl, heaps, prj)	= pretty_show_record finfo ptr exprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| ok								= (OK, fappl, heaps, prj)
		# (ok, error, fselect, heaps, prj)	= pretty_show_selector finfo ptr exprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| ok								= (OK, fselect, heaps, prj)
		# (ok, error, fupd, heaps, prj)		= pretty_show_updater finfo ptr exprs heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		| ok								= (OK, fupd, heaps, prj)
		# (error, name, inf, prj)			= get_name_and_infix ptr prj
		| isError error						= (error, DummyValue, heaps, prj)
		= FormattedShowInfix finfo name inf ptr exprs heaps prj
		where
			pretty_show_array_selection_update finfo ptr exprs heaps prj
				| ptrKind ptr <> CFun			= (False, OK, DummyValue, heaps, prj)
				# modptr						= ptrModule ptr
				# finfo							= {finfo & fiPreviousPriority = Nothing, fiPreviousApplicationPtr = Nothing}
				# (modname, heaps)				= getPointerName modptr heaps
				| modname <> "StdArray"			= (False, OK, DummyValue, heaps, prj)
				# (error, fundef, prj)			= getFunDef ptr prj
				| isError error					= (False, error, DummyValue, heaps, prj)
				# (error, fexprs, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = False}) exprs heaps prj
				| isError error					= (False, error, DummyValue, heaps, prj)
				| fundef.fdName == "select" && length exprs == 2 && not finfo.fiOptions.optShowArrayFuns
												= (True, OK, (hd fexprs) ++ [CmText ".["] ++ (hd (tl fexprs)) ++ [CmText "]"], heaps, prj)
				| fundef.fdName == "update" && length exprs == 3 && not finfo.fiOptions.optShowArrayFuns
												= check_updates finfo (hd exprs) ([CmText "["] ++ (hd (tl fexprs)) ++ [CmText "] = "] ++ (hd (tl (tl fexprs)))) heaps prj
				= (False, OK, DummyValue, heaps, prj)
				where
					check_updates finfo expr updatetext heaps prj
						# (error, arity, fexpr, moreupdates, heaps, prj)	= collectUpdates finfo expr heaps prj
						| isError error										= (False, error, DummyValue, heaps, prj)
						# (createOK, ftexts)								= showArrayCreation arity [updatetext: moreupdates]
						| createOK											= (True, OK, ftexts, heaps, prj)
						# fallupdates										= Separate False [CmText ", "] (reverse [updatetext: moreupdates])
						= (True, OK, [CmText "{"] ++ fexpr ++ [CmText " & "] ++ fallupdates ++ [CmText "}"], heaps, prj)
			
			pretty_show_updater finfo ptr exprs heaps prj
				| finfo.fiOptions.optShowRecordFuns	= (False, OK, DummyValue, heaps, prj)
				# (error, fundef, prj)				= getFunDef ptr prj
				| isError error						= (False, OK, DummyValue, heaps, prj)
				| not fundef.fdIsRecordUpdater		= (False, OK, DummyValue, heaps, prj)
				# (error, field, prj)				= getRecordFieldDef fundef.fdRecordFieldDef prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				# (expr, fields, prj)				= split_in_fields field.rfRecordType (hd exprs) prj
				# fields							= [(field.rfName, hd (tl exprs)): fields]
				# (error, fexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} expr heaps prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				# fstart							= [CmText "{"] ++ fexpr ++ [CmText " & "]
				# (error, ffields, heaps, prj)		= uumapError (show_field_update finfo) fields heaps prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				= (True, OK, fstart ++ Separate False [CmText ", "] ffields ++ [CmText "}"], heaps, prj)
				where
					split_in_fields recptr (ptr @@# exprs) prj
						# (error, fundef, prj)			= getFunDef ptr prj
						| isError error					= (ptr @@# exprs, [], prj)
						| not fundef.fdIsRecordUpdater	= (ptr @@# exprs, [], prj)
						# (error, field, prj)			= getRecordFieldDef fundef.fdRecordFieldDef prj
						| isError error					= (ptr @@# exprs, [], prj)
						| recptr <> field.rfRecordType	= (ptr @@# exprs, [], prj)
						# (expr, fields, prj)			= split_in_fields ptr (hd exprs) prj
						= (expr, [(field.rfName, hd (tl exprs)): fields], prj)
					split_in_fields recptr expr prj
						= (expr, [], prj)
					
					show_field_update finfo (fieldname, expr) heaps prj
						# (error, fexpr, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = False} expr heaps prj
						= (OK, [CmText fieldname, CmText " = "] ++ fexpr, heaps, prj)
		
			pretty_show_selector finfo ptr exprs heaps prj
				| finfo.fiOptions.optShowRecordFuns	= (False, OK, DummyValue, heaps, prj)
				# (error, fundef, prj)				= getFunDef ptr prj
				| isError error						= (False, OK, DummyValue, heaps, prj)
				| not fundef.fdIsRecordSelector		= (False, OK, DummyValue, heaps, prj)
				# (error, fielddef, prj)			= getRecordFieldDef fundef.fdRecordFieldDef prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				# (error, recorddef, prj)			= getRecordTypeDef fielddef.rfRecordType prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				# (error, fexprs, heaps, prj)		= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) exprs heaps prj
				| not finfo.fiOptions.optShowDictionaries && recorddef.rtdIsDictionary
													= maybe_show_field fielddef heaps prj
				= (True, OK, hd fexprs ++ [CmText ".", CmText fielddef.rfName], heaps, prj)
				where
					maybe_show_field fielddef heaps prj
						# restype					= fielddef.rfSymbolType.sytResult
						# restype					= case restype of
														CStrict type		-> type
														other				-> other
						= case restype of
							(recptr @@^ types)	-> case ptrKind recptr of
													CRecordType	-> show_record_field recptr heaps prj
													_			-> (True, OK, [CmText fielddef.rfName], heaps, prj)
							_					-> (True, OK, [CmText fielddef.rfName], heaps, prj)
						where
							show_record_field ptr heaps prj
								# (error, recordtype, prj)		= getRecordTypeDef ptr prj
								| isError error					= (True, error, DummyValue, heaps, prj)
								| recordtype.rtdIsDictionary	= (True, OK, [], heaps, prj)
								= (True, OK, [CmText fielddef.rfName], heaps, prj)
				
			pretty_show_record finfo ptr exprs heaps prj
				| finfo.fiOptions.optShowRecordFuns	= (False, OK, DummyValue, heaps, prj)
				# (error, dataconsdef, prj)			= getDataConsDef ptr prj
				| isError error						= (False, OK, DummyValue, heaps, prj)
				# (error, recorddef, prj)			= getRecordTypeDef dataconsdef.dcdAlgType prj
				| isError error						= (False, OK, DummyValue, heaps, prj)
				| recorddef.rtdIsDictionary && not finfo.fiOptions.optShowDictionaries
													= (True, OK, [], heaps, prj)
				| length recorddef.rtdFields <> length exprs
													= (False, OK, DummyValue, heaps, prj)
				# fstart							= case finfo.fiIsPattern of
														False	-> [CmText "{", CmLink recorddef.rtdName (CmdShowDefinition dataconsdef.dcdAlgType), CmText " | "]
														True	-> [CmText "{"]
				# finfo								= {finfo & fiNeedBrackets = False, fiPreviousApplicationPtr = Nothing, fiPreviousPriority = Nothing}
				# (error, fexprs, heaps, prj)		= uumapError (FormattedShow finfo) exprs heaps prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				# (error, fargs, prj)				= wrap_args fexprs recorddef.rtdFields prj
				| isError error						= (False, error, DummyValue, heaps, prj)
				= (True, OK, fstart ++ (Separate False [CmText ", "] fargs) ++ [CmText "}"], heaps, prj)
				where
					wrap_args :: ![MarkUpText a] ![HeapPtr] !*CProject -> (!Error, ![MarkUpText a], !*CProject)  
					wrap_args [fexpr: fexprs] [ptr: ptrs] prj
						# (error, fielddef, prj)	= getRecordFieldDef ptr prj
						| isError error				= (error, DummyValue, prj)
						# farg						= case finfo.fiIsPattern of
														False	-> [CmText fielddef.rfName, CmText " = "] ++ fexpr
														True	-> fexpr
						# (error, fargs, prj)		= wrap_args fexprs ptrs prj
						| isError error				= (error, DummyValue, prj)
						= (OK, [farg: fargs], prj)
					wrap_args [] [] prj
						= (OK, [], prj)
		
			get_name_and_infix ptr prj
				# kind								= ptrKind ptr
				| kind == CDataCons
					# (error, dataconsdef, prj)		= getDataConsDef ptr prj
					| isError error					= (error, DummyValue, DummyValue, prj)
					# name							= dataconsdef.dcdName
					# inf							= dataconsdef.dcdInfix
					# name							= if (isInfix inf) ("(" +++ name +++ ")") name
					= (OK, name, inf, prj)
				| kind == CMember
					# (error, memberdef, prj)		= getMemberDef ptr prj
					| isError error					= (error, DummyValue, DummyValue, prj)
					# name							= memberdef.mbdName
					# inf							= memberdef.mbdInfix
					# name							= if (isInfix inf) ("(" +++ name +++ ")") name
					= (OK, name, inf, prj)
				| kind == CFun
					# (error, fundef, prj)			= getFunDef ptr prj
					| isError error					= (error, DummyValue, DummyValue, prj)
					# name							= case finfo.fiOptions.optShowInstanceTypes of
														True	-> fundef.fdName
														False	-> case fundef.fdOldName of
																	""		-> fundef.fdName
																	_		-> fundef.fdOldName
					# inf							= fundef.fdInfix
					# name							= if (isInfix inf) ("(" +++ name +++ ")") name
//					| isJust fundef.fdDeltaRule		= (OK, fundef.fdName +++ "º", fundef.fdInfix, prj)
					= (OK, name, inf, prj)
				#! prj								= prj --->> kind
				= (pushError (X_Internal ("encountered something other than a function or data-constructor at an application")) OK, DummyValue, DummyValue, prj)
	FormattedShow finfo (CLet strict bindings expr) heaps prj
		# (finfo, heaps)					= storeExprVars (map fst bindings) finfo heaps
		# finfo								= if (finfo.fiHeadPtr == DummyValue)
												{finfo & fiOptions.optShowLetsAndCases = True} finfo
		# showlets							= buildShowLets finfo strict bindings
		# (error, flets, heaps, prj)		= displayShowLets finfo showlets heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, fexpr, heaps, prj)		= FormattedShow finfo expr heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# let_text							= if strict "let! " "let "
		| finfo.fiOptions.optShowLetsAndCases
											= (OK, [CmScope, CmColour Grey, CmText let_text, CmEndColour, CmNewline, CmTabSpace] ++ flets ++
												   [CmNewline, CmColour Grey, CmText "in ", CmEndColour, CmNewline, CmTabSpace] ++ fexpr ++ [CmEndScope], heaps, prj)
		| isSpecialCaseOrLet expr			= (OK, flets ++ [CmNewline] ++ fexpr, heaps, prj)
		= (OK, flets ++ [CmText "= "] ++ fexpr, heaps, prj)
	FormattedShow finfo=:{fiNeedBrackets} case_expr=:(CCase expr patterns maybe_default) heaps prj
		# finfo								= if (finfo.fiHeadPtr == DummyValue)
												{finfo & fiOptions.optShowLetsAndCases = True} finfo
		| isSpecialCaseOrLet case_expr && not finfo.fiOptions.optShowLetsAndCases
											= shorthand_case expr patterns maybe_default heaps prj
		# (error, cexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} expr heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, cpatterns, heaps, prj)	= FormattedShow finfo patterns heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# without_default					= [CmColour Grey, CmText "case ", CmEndColour] ++ cexpr ++ [CmColour Grey, CmText " of", CmEndColour] ++ cpatterns
		| isNothing maybe_default			= (OK, [CmScope] ++ without_default ++ [CmEndScope], heaps, prj)
		# (error, cdefault, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} (fromJust maybe_default) heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# cdefault							= [CmNewline, CmTabSpace, CmColour Grey, CmText "default", CmAlign "case", CmEndColour, CmText " -> "] ++ cdefault
		= case fiNeedBrackets of
			True	-> (OK, [CmText "(", CmScope] ++ without_default ++ cdefault ++ [CmEndScope, CmText ")"], heaps, prj)
			False	-> (OK, [CmScope] ++ without_default ++ cdefault ++ [CmEndScope], heaps, prj)
		where
			shorthand_case expr (CBasicPatterns basictype [basicpattern]) maybe_default heaps prj
				# (error, fexpr, heaps, prj)= FormattedShow {finfo & fiOptions.optShowLetsAndCases = True, fiNeedBrackets = False} expr heaps prj
				| isError error				= (error, DummyValue, heaps, prj)
				# special_pattern			= isSpecialCaseOrLet basicpattern.bapResult
				# (error, fpattern, heaps,prj)= case special_pattern of
												True	-> FormattedShow {finfo & fiOptions.optShowLetsAndCases = False, fiNeedBrackets = False} basicpattern.bapResult heaps prj
												False	-> FormattedShow {finfo & fiOptions.optShowLetsAndCases = True, fiNeedBrackets = False} basicpattern.bapResult heaps prj
				| isError error				= (error, DummyValue, heaps, prj)
				# fcasestart				= [CmCenter, CmColour Grey, CmText "| ", CmEndColour, CmAlign "lc_start"] ++ fexpr 
				# fcase						= case special_pattern of
												True	-> fcasestart ++ [CmNewline, CmTabSpace, CmScope] ++ fpattern ++ [CmEndScope]
												False	-> fcasestart ++ [CmAlign "lc_end", CmText " = "] ++ fpattern
				| isNothing maybe_default	= (OK, fcase, heaps, prj)
				# def						= fromJust maybe_default
				# (error, fdef, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = False} def heaps prj
				| isError error				= (error, DummyValue, heaps, prj)
				| isSpecialCaseOrLet def	= (OK, fcase ++ [CmNewline] ++ fdef, heaps, prj)
				= (OK, fcase ++ [CmNewline, CmText "= "] ++ fdef, heaps, prj)
			shorthand_case _ _ _ _ _
				= abort "Reached impossible case in FormattedShow (Core)"
	FormattedShow finfo (CBasicValue basicvalue) heaps prj
		= FormattedShow finfo basicvalue heaps prj
	FormattedShow finfo (CCode codeid codetexts) heaps prj
		# fstart							= [CmColour Magenta, CmText "code ", CmText codeid, CmNewline, CmText "{ "]
		# ftexts							= map (\text -> [CmText text]) codetexts
		= (OK, fstart ++ (Separate True [CmNewline, CmTabSpace] ftexts) ++ [CmNewline, CmText "}", CmEndColour], heaps, prj)
	FormattedShow finfo CBottom heaps prj
		= (OK, finfo.fiSpecial.disBottom, heaps, prj)
	FormattedShow finfo expr heaps prj
		= (OK, [CmText "XXX NOG BEZIG XXX"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
FormattedShowInfix	:: !FormatInfo !String !CInfix !HeapPtr ![CExprH] !*CHeaps !*CProject 
					-> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
FormattedShowInfix finfo name inf ptr exprs heaps prj
	# (exprs, heaps, prj)					= filterDictionaries exprs heaps prj
	| ptr == CNilPtr						= (OK, [CmText "[]"], heaps, prj)
	| isNoInfix inf							= no_infix_show finfo ptr exprs name heaps prj
	| (length exprs) < 2					= no_infix_show finfo ptr exprs name heaps prj
	| (length exprs) > 2					= no_infix_show finfo ptr exprs name heaps prj
	| ptr == CBuildTuplePtr 2				= no_infix_show finfo ptr exprs name heaps prj
	# (arg1, arg2)							= (hd exprs, hd (tl exprs))
	| ptr == CConsPtr						= show_cons finfo ptr arg1 arg2 heaps prj
	# prio									= getPriority inf
	# fleft									= {finfo & fiNeedBrackets = True, fiPreviousApplicationPtr = Just ptr, fiPreviousPriority = Just prio, fiOverrideNoBrackets = False}
	# fleft									= if (isLeftAssociative inf) {fleft & fiOverrideNoBrackets = True} fleft
	# fright								= {finfo & fiNeedBrackets = True, fiPreviousApplicationPtr = Just ptr, fiPreviousPriority = Just prio, fiOverrideNoBrackets = False}
	# fright								= if (isRightAssociative inf) {fright & fiOverrideNoBrackets = True} fright
	# (error, farg1, heaps, prj)			= FormattedShow fleft arg1 heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# (error, farg2, heaps, prj)			= FormattedShow fright arg2 heaps prj
	| isError error							= (error, DummyValue, heaps, prj)
	# name									= if (name.[0] == '(') (name % (1, size name-2)) name		// remove brackets
	# fname									= case (ptr == finfo.fiHeadPtr) of
												True	-> [CmText name]
												False	-> [CmLink name (CmdShowDefinition ptr)]
	# brackets								= if (isNothing finfo.fiPreviousPriority) finfo.fiNeedBrackets (prio <= fromJust finfo.fiPreviousPriority)
	# brackets								= if (isNothing finfo.fiPreviousApplicationPtr) brackets
												(if (ptr == fromJust finfo.fiPreviousApplicationPtr)
													(not finfo.fiOverrideNoBrackets)
													brackets)
	# brackets								= if finfo.fiOptions.optAlwaysBrackets True brackets
//	# brackets								= if (isNothing finfo.fiPreviousApplicationPtr) brackets 
//												(if (ptr == fromJust finfo.fiPreviousApplicationPtr) False brackets)
	# no_brackets							= farg1 ++ [CmText " "] ++ fname ++ [CmText " "] ++ farg2
	| brackets								= (OK, [CmText "("] ++ no_brackets ++ [CmText ")"], heaps, prj)
	= (OK, no_brackets, heaps, prj)
	where
		filterDictionaries [CExprVar ptr: exprs] heaps prj
			# (exprs, heaps, prj)				= filterDictionaries exprs heaps prj
			# show_dicts						= finfo.fiOptions.optShowDictionaries
			| show_dicts						= ([CExprVar ptr: exprs], heaps, prj)
			# (var, heaps)						= readPointer ptr heaps
			| isDictionaryName var.evarName		= (exprs, heaps, prj)
			= ([CExprVar ptr: exprs], heaps, prj)
		filterDictionaries [expr=:(ptr @@# args): exprs] heaps prj
			# (exprs, heaps, prj)				= filterDictionaries exprs heaps prj
			# show_dicts						= finfo.fiOptions.optShowDictionaries
			| show_dicts						= ([expr:exprs], heaps, prj)
			# (error, consdef, prj)				= getDataConsDef ptr prj
			| isError error						= ([expr:exprs], heaps, prj)
			# (error, recorddef, prj)			= getRecordTypeDef consdef.dcdAlgType prj
			| isError error						= ([expr:exprs], heaps, prj)
			| recorddef.rtdIsDictionary			= (exprs, heaps, prj)
			= ([expr:exprs], heaps, prj)
		filterDictionaries [expr:exprs] heaps prj
			# (exprs, heaps, prj)				= filterDictionaries exprs heaps prj
			= ([expr: exprs], heaps, prj)
		filterDictionaries [] heaps prj
			= ([], heaps, prj)
	
		no_infix_show finfo ptr exprs name heaps prj
			# fname								= case (ptr == finfo.fiHeadPtr) of
													True	-> [CmText name]
													False	-> [CmLink name (CmdShowDefinition ptr)]
			# need_brackets						= finfo.fiNeedBrackets && isNothing finfo.fiPreviousPriority
			# need_brackets						= need_brackets || finfo.fiOptions.optAlwaysBrackets
			# finfo								= {finfo & fiNeedBrackets = True, fiPreviousPriority = Nothing, fiPreviousApplicationPtr = Nothing}
			# finfo								= case (ptr == CBuildTuplePtr (length exprs)) of
													True	-> {finfo & fiNeedBrackets = False}
													False	-> finfo
			# (error, cexprs, heaps, prj)		= uumapError (FormattedShow finfo) exprs heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# nr_args							= length exprs
			| ptr == CBuildTuplePtr nr_args		= (OK, [CmText "("] ++ (Separate False [CmText ", "] cexprs) ++ [CmText ")"], heaps, prj)
			# cexprs							= filter (not o isEmpty) cexprs
			# no_brackets						= fname ++ (Separate True [CmText " "] cexprs)
			| isEmpty exprs						= (OK, no_brackets, heaps, prj)
			| need_brackets						= (OK, [CmText "("] ++ no_brackets ++ [CmText ")"], heaps, prj)
			= (OK, no_brackets, heaps, prj)
		
		show_cons finfo ptr expr1 expr2 heaps prj
			# finfo								= {finfo & fiPreviousPriority = Nothing, fiPreviousApplicationPtr = Nothing}
			# (ok, el_exprs)					= collect_cons_exprs [expr1] expr2
			| ok								= let (error, fexprs, newheaps, newprj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = False}) el_exprs heaps prj
												   in	case isError error of
												   			True	-> (error, DummyValue, newheaps, newprj)
												   			False	-> (OK, [CmText "["] ++ (Separate False [CmText ", "] fexprs) ++ [CmText "]"], newheaps, newprj)
			# (error, cexpr1, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} expr1 heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# (error, cexpr2, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} expr2 heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			= (OK, [CmText "["] ++ cexpr1 ++ [CmText ":"] ++ cexpr2 ++ [CmText "]"], heaps, prj)
		
		collect_cons_exprs el_exprs (nil_ptr @@# [])
			| nil_ptr <> CNilPtr				= (False, [])
			= (True, el_exprs)
		collect_cons_exprs el_exprs (cons_ptr @@# [el_expr, more_expr])
			| cons_ptr <> CConsPtr				= (False, [])
			# (ok, rest_exprs)					= collect_cons_exprs (el_exprs ++ [el_expr]) more_expr
			| not ok							= (False, [])
			= (True, rest_exprs)
		collect_cons_exprs el_exprs other
			= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow CFunctionDefinedness
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo CDefinednessUnknown heaps prj
		= (OK,	[ CmColour		Brown
				, CmText		"DEFINEDNESS:"
				, CmLink2		1 "manual" (CmdShowDefinedness finfo.fiHeadPtr)
				, CmEndColour
				], heaps, prj)
	FormattedShow finfo (CDefinedBy args) heaps prj
		= (OK,	[ CmColour		Brown
				, CmText		"DEFINEDNESS:"
				, CmText		"fixed["
				, CmText		(show 0 args)
				, CmText		"]"
				, CmEndColour
				], heaps, prj)
		where
			show :: !Int ![Bool] -> String
			show n [True:bs]
				= toString n +++ show (n+1) bs
			show n [False:bs]
				= show (n+1) bs
			show _ []
				= ""

:: TempPattern a = {varPatterns :: ![CExprH], patternBody :: !CExprH, patternInfo :: !FormatInfo}
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CFunDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo fundef heaps prj
		# (finfo, heaps)					= storeExprVars fundef.fdExprVarScope finfo heaps
		# fun_name							= case finfo.fiOptions.optShowInstanceTypes of
												True	-> fundef.fdName
												False	-> case fundef.fdOldName of
															""		-> fundef.fdName
															_		-> fundef.fdOldName
		# ffun_name							= [CmText fun_name]
		# fname								= [CmBold: ffun_name] ++ [CmEndBold, CmText " :: "]
		# (error, finfix, heaps, prj)		= FormattedShow finfo fundef.fdInfix heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# (error, ftype, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = True} fundef.fdSymbolType heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# ftype								= if (isEmpty finfix) ftype (finfix ++ [CmText " "] ++ ftype)
		# (vardefs, heaps)					= readPointers fundef.fdExprVarScope heaps
		# varnames							= [def.evarName \\ def <- vardefs]
		# (error, fvarnames, heaps, prj)	= ShowExprScope finfo fundef.fdExprVarScope heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fvarnames							= if (isEmpty fvarnames) [] ([CmText " "] ++ fvarnames)
		# show_cases						= finfo.fiOptions.optShowLetsAndCases
		| not show_cases					= show_patterns ffun_name {finfo & fiNeedBrackets = False} fundef varnames (fname ++ ftype ++ [CmNewline]) heaps prj
		# fpattern							= [CmBold: ffun_name] ++ [CmEndBold:fvarnames] ++ [CmNewline, CmTabSpace, CmText " = "]
		# (error, fexpr, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} fundef.fdBody heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		// EXTRA INFO . TEMPORARY
		# fextra1							= [CmColour Brown, CmText "CASE:"] ++ [CmText (toString index) \\ index <- fundef.fdCaseVariables] ++ [CmEndColour]
		# fextra2							= [CmColour Brown, CmText " STRICT:"] ++ [CmText (toString index) \\ index <- fundef.fdStrictVariables] ++ [CmEndColour]
		# fextra3							= [CmColour Brown, CmText " #DICTIONARIES:"] ++ [CmText (toString fundef.fdNrDictionaries)] ++ [CmEndColour]
		# (error, fextra4, heaps, prj)		= FormattedShow finfo fundef.fdDefinedness heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, fname ++ ftype ++ [CmNewline] ++ fpattern ++ [CmScope] ++ fexpr ++ [CmEndScope] ++ [CmNewline] ++ fextra1 ++ fextra2 ++ fextra3 ++ [CmText " "] ++ fextra4, heaps, prj)
		where
			isBasicTrue (CBasicBoolean True)	= True
			isBasicTrue _						= False
		
			show_patterns ffun_name finfo fundef varnames fstart heaps prj
				# pattern						= {varPatterns = [CExprVar var \\ var <- fundef.fdExprVarScope], 
												   patternBody = fundef.fdBody, patternInfo = finfo}
				# patterns						= collect_patterns pattern fundef.fdBody
				# (error, frest, heaps, prj)	= display_patterns ffun_name patterns heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				// EXTRA INFO . TEMPORARY
				# fextra1						= [CmColour Brown, CmText "CASE:"] ++ [CmText (toString index) \\ index <- fundef.fdCaseVariables] ++ [CmEndColour]
				# fextra2						= [CmColour Brown, CmText " STRICT:"] ++ [CmText (toString index) \\ index <- fundef.fdStrictVariables] ++ [CmEndColour]
				# fextra3						= [CmColour Brown, CmText " #DICTIONARIES:"] ++ [CmText (toString fundef.fdNrDictionaries)] ++ [CmEndColour]
				# (error, fextra4, heaps, prj)	= FormattedShow finfo fundef.fdDefinedness heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, fstart ++ frest ++ [CmNewline] ++ fextra1 ++ fextra2 ++ fextra3 ++ [CmText " "] ++ fextra4, heaps, prj)
			
			display_patterns ffun_name [pattern: patterns] heaps prj
				# (error, fpatterns, heaps, prj)	= uumapError (FormattedShow {pattern.patternInfo & fiIsPattern = True, fiNeedBrackets = True}) pattern.varPatterns heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				# fstart						= [CmBold: ffun_name] ++ [CmEndBold] ++ (Separate True [CmText " "] fpatterns)
				# fstart						= case finfo.fiOptions.optShowLetsAndCases of
													True	-> fstart ++ [CmNewline, CmTabSpace, CmText " = ", CmScope]
													False	-> fstart ++ [CmNewline, CmTabSpace,               CmScope]
				# (error, fbody, heaps, prj)	= FormattedShow pattern.patternInfo pattern.patternBody heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				# fbody							= case not finfo.fiOptions.optShowLetsAndCases && not (isSpecialCaseOrLet pattern.patternBody) of
													True	-> [CmText "= "] ++ fbody
													False	-> fbody
				# fpattern						= fstart ++ fbody ++ [CmEndScope, CmNewline]
				# (error, fpatterns, heaps, prj)= display_patterns ffun_name patterns heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, fpattern ++ [CmNewline] ++ fpatterns, heaps, prj)
			display_patterns ffun_name [] heaps prj
				= (OK, [], heaps, prj)
			
			collect_patterns pattern (CCase (CExprVar varid) (CAlgPatterns _ algpatterns) maybe_default)
				# normal_patterns		= flatten (map (collect_alg_pattern varid pattern) algpatterns)
				# default_patterns		= collect_patterns {pattern & patternBody = fromJust maybe_default} (fromJust maybe_default)
				# all_patterns			= if (isNothing maybe_default) normal_patterns (normal_patterns ++ default_patterns)
				= all_patterns
			collect_patterns pattern (CCase (CExprVar varid) (CBasicPatterns _ basicpatterns) maybe_default)
				# normal_patterns		= flatten (map (collect_basic_pattern varid pattern) basicpatterns)
				# default_patterns		= collect_patterns {pattern & patternBody = fromJust maybe_default} (fromJust maybe_default)
				# all_patterns			= if (isNothing maybe_default) normal_patterns (normal_patterns ++ default_patterns)
				= all_patterns
			collect_patterns pattern other
				= [pattern]
			
			collect_alg_pattern varid pattern algpattern
				# finfo					= pattern.patternInfo
				# change_to				= algpattern.atpDataCons @@# [CExprVar var \\ var <- algpattern.atpExprVarScope]
				# change_from			= CExprVar varid
				# varPatterns			= map (change change_from change_to) pattern.varPatterns
				# patternBody			= change change_from change_to algpattern.atpResult
				# new_pattern			= {varPatterns = varPatterns, patternBody = patternBody, patternInfo = finfo}
				= collect_patterns new_pattern new_pattern.patternBody
			
			collect_basic_pattern varid pattern basicpattern
				# change_to				= CBasicValue basicpattern.bapBasicValue
				# change_from			= CExprVar varid
				# varPatterns			= map (change change_from change_to) pattern.varPatterns
				# new_pattern			= {varPatterns = varPatterns, patternBody = basicpattern.bapResult, patternInfo = pattern.patternInfo}
				= collect_patterns new_pattern new_pattern.patternBody
			
			change (CExprVar id1) to_expr (CExprVar id2)
				| id1 == id2 							= to_expr
				= CExprVar id2
			change from_expr to_expr (ptr @# exprs)
				= ptr @# (map (change from_expr to_expr) exprs)
			change from_expr to_expr (datacons @@# exprs)
				# exprs									= map (change from_expr to_expr) exprs
				= datacons @@# exprs
			change from_expr to_expr (CLet strict bindings let_expr)
				# bindings								= [(exprvar, change from_expr to_expr expr) \\ (exprvar, expr) <- bindings]
				= CLet strict bindings (change from_expr to_expr let_expr)
			change from_expr to_expr (CCase case_expr (CAlgPatterns algtype algpatterns) maybe_default)
				# case_expr								= change from_expr to_expr case_expr
				# algpatterns							= [{algpattern & atpResult = change from_expr to_expr algpattern.atpResult} \\ algpattern <- algpatterns]
				# maybe_default							= if (isJust maybe_default) (Just (change from_expr to_expr (fromJust maybe_default))) maybe_default
				= CCase case_expr (CAlgPatterns algtype algpatterns) maybe_default
			change from_expr to_expr (CCase case_expr (CBasicPatterns basictype basicpatterns) maybe_default)
				# case_expr								= change from_expr to_expr case_expr
				# basicpatterns							= [{basicpattern & bapResult = change from_expr to_expr basicpattern.bapResult} \\ basicpattern <- basicpatterns]
				# maybe_default							= if (isJust maybe_default) (Just (change from_expr to_expr (fromJust maybe_default))) maybe_default
				= CCase case_expr (CBasicPatterns basictype basicpatterns) maybe_default
			change from_expr to_expr in_expr
				= in_expr

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow CInfix 
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo CNoInfix heaps prj
		= (OK, [], heaps, prj)
	FormattedShow finfo (CLeftAssociative prio) heaps prj
		= (OK, [CmColour Grey, CmText "infixl ", CmText (toString prio), CmEndColour], heaps, prj)
	FormattedShow finfo (CRightAssociative prio) heaps prj
		= (OK, [CmColour Grey, CmText "infixr ", CmText (toString prio), CmEndColour], heaps, prj)
	FormattedShow finfo (CNotAssociative prio) heaps prj
		= (OK, [CmColour Grey, CmText "infix ", CmText (toString prio), CmEndColour], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CInstanceDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo instancedef heaps prj
		# finfo								= {finfo & fiNeedBrackets = True}
		# fstart							= [CmColour Grey, CmText "instance ", CmEndColour, CmBold, CmText instancedef.indName, CmEndBold]
		# (error, ftypes, heaps, prj)		= uumapError (FormattedShow finfo) instancedef.indClassArguments heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# ftypes							= Separate True [CmText " "] ftypes
		# (error, frestrictions, heaps, prj)= uumapError (FormattedShow finfo) instancedef.indClassRestrictions heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# frestrictions						= if (isEmpty frestrictions) [] ([CmText " | "] ++ (Separate False [CmText " & "] frestrictions))
		# (error, membernames, heaps, prj)	= uumapError getDefinitionName instancedef.indMemberFunctions heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fmembers							= Separate True [CmNewline, CmTabSpace] (map (\name -> [CmBText name]) membernames)
		= (OK, fstart ++ ftypes ++ frestrictions ++ [CmNewline, CmColour Grey, CmText "with members", CmEndColour] ++ fmembers, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CMemberDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo memberdef heaps prj
		# (error, finfix, heaps, prj)		= FormattedShow finfo memberdef.mbdInfix heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# name								= if (isEmpty finfix) memberdef.mbdName (" (" +++ memberdef.mbdName +++ ")")
		# fstart							= finfix ++ [CmBold, CmText name, CmEndBold, CmAlign "member", CmText " :: "]
		# (error, ftype, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = True} memberdef.mbdSymbolType heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		= (OK, fstart ++ ftype, heaps, prj)

// Mirror in AnnotatedShow
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CProp HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (CPropVar ptr) heaps prj
		# (fvar, heaps)					= ShowPropVar finfo False ptr heaps
		= (OK, fvar, heaps, prj)
	FormattedShow finfo CTrue heaps prj
		= (OK, [CmColour LogicColour, CmBText "TRUE", CmEndColour], heaps, prj)
	FormattedShow finfo CFalse heaps prj
		= (OK, [CmColour LogicColour, CmBText "FALSE", CmEndColour], heaps, prj)
	FormattedShow finfo (CNot p) heaps prj
		# finfo							= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
		# finfo							= {finfo & fiNeedBrackets = True, fiPosition = Nothing}
		# (error, textp, heaps, prj)	= FormattedShow finfo p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# textp							= if (is_equal p) ([CmText "("] ++ textp ++ [CmText ")"]) textp
		= (OK, finfo.fiSpecial.disNot textp, heaps, prj)
		where
			is_equal (CEqual e1 e2)		= True
			is_equal _					= False
	FormattedShow finfo=:{fiNeedBrackets, fiPosition} (CAnd p q) heaps prj
		# finfo							= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
		# finfo							= {finfo & fiNeedBrackets = True}
		# (error, textp, heaps, prj)	= FormattedShow {finfo & fiPosition = Just LeftOfAnd} p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, textq, heaps, prj)	= FormattedShow {finfo & fiPosition = Just RightOfAnd} q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# text							= finfo.fiSpecial.disAnd textp textq
		# brackets						= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfAnd, Just LeftOfIff, Just RightOfIff]
		# brackets						= finfo.fiOptions.optAlwaysBrackets || brackets
		| not brackets					= (OK, text, heaps, prj)
		= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
	FormattedShow finfo=:{fiNeedBrackets, fiPosition} (COr p q) heaps prj
		# finfo							= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
		# finfo							= {finfo & fiNeedBrackets = True}
		# (error, textp, heaps, prj)	= FormattedShow {finfo & fiPosition = Just LeftOfOr} p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, textq, heaps, prj)	= FormattedShow {finfo & fiPosition = Just RightOfOr} q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# text							= finfo.fiSpecial.disOr textp textq
		# brackets						= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfAnd, Just RightOfAnd, Just LeftOfOr, Just LeftOfIff, Just RightOfIff]
		# brackets						= finfo.fiOptions.optAlwaysBrackets || brackets
		| not brackets					= (OK, text, heaps, prj)
		= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
	FormattedShow finfo=:{fiNeedBrackets, fiPosition, fiIndentImplies} (CImplies p q) heaps prj
		# finfo							= {finfo & fiIndentQuantors = False}
		# finfo							= {finfo & fiNeedBrackets = True}
		# (error, textp, heaps, prj)	= FormattedShow {finfo & fiPosition = Just LeftOfImplies, fiIndentImplies = False, fiIndentEqual = False} p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, textq, heaps, prj)	= FormattedShow {finfo & fiPosition = Just RightOfImplies} q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| fiIndentImplies				= (OK, finfo.fiSpecial.disImplies True (textp++[CmNewline]) textq, heaps, prj)
		# text							= finfo.fiSpecial.disImplies False textp textq
		# brackets						= case fiNeedBrackets of
											False	-> False
											True	-> fiPosition <> Just RightOfImplies
		# brackets						= finfo.fiOptions.optAlwaysBrackets || brackets
		| not brackets					= (OK, text, heaps, prj)
		= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
	FormattedShow finfo=:{fiIndentEqual, fiNeedBrackets, fiPosition} (CIff p q) heaps prj
		# finfo							= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
		# finfo							= {finfo & fiNeedBrackets = True}
		# (error, textp, heaps, prj)	= FormattedShow {finfo & fiPosition = Just LeftOfIff} p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, textq, heaps, prj)	= FormattedShow {finfo & fiPosition = Just RightOfIff} q heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| fiIndentEqual
			# fsymbol					= remove_first_space (finfo.fiSpecial.disIff [] [])
			= (OK, [CmScope] ++ textp ++ [CmNewline] ++ fsymbol ++ [CmNewline] ++ textq ++ [CmEndScope], heaps, prj)
		# text							= finfo.fiSpecial.disIff textp textq
		# brackets						= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfIff]
		# brackets						= finfo.fiOptions.optAlwaysBrackets || brackets
		| not brackets					= (OK, text, heaps, prj)
		= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
		where
			remove_first_space :: !(MarkUpText a) -> MarkUpText a
			remove_first_space [CmText " ":commands]
				= commands
			remove_first_space [command: commands]
				= [command: remove_first_space commands]
			remove_first_space []
				= []
	FormattedShow finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual} (CExprForall ptr p) heaps prj
		# next_is_quantor				= is_quantor p
		# indent_next					= fiIndentQuantors && next_is_quantor
		# indent_now					= fiIndentQuantors && not next_is_quantor
		# finfo							= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
		# finfo							= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
		# (finfo, heaps)				= storeExprVar ptr finfo heaps
		# (error, fvar, heaps, prj)		= ShowExprVar finfo True ptr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# fquantor						= finfo.fiSpecial.disForall next_is_quantor fvar
		# (error, fprop, heaps, prj)	= FormattedShow finfo p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| indent_now
			= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
			= case fiPosition of
				Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
				Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
		where
			is_quantor (CExprForall _ _)	= True
			is_quantor (CExprExists _ _)	= True
			is_quantor (CPropForall _ _)	= True
			is_quantor (CPropExists _ _)	= True
			is_quantor _					= False
	FormattedShow finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual} (CExprExists ptr p) heaps prj
		# next_is_quantor				= is_quantor p
		# indent_next					= fiIndentQuantors && next_is_quantor
		# indent_now					= fiIndentQuantors && not next_is_quantor
		# finfo							= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
		# finfo							= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
		# (finfo, heaps)				= storeExprVar ptr finfo heaps
		# (error, fvar, heaps, prj)		= ShowExprVar finfo True ptr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# fquantor						= finfo.fiSpecial.disExists next_is_quantor fvar
		# (error, fprop, heaps, prj)	= FormattedShow finfo p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| indent_now
			= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
			= case fiPosition of
				Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
				Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
		where
			is_quantor (CExprForall _ _)	= True
			is_quantor (CExprExists _ _)	= True
			is_quantor (CPropForall _ _)	= True
			is_quantor (CPropExists _ _)	= True
			is_quantor _					= False
	FormattedShow finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual} (CPropForall ptr p) heaps prj
		# next_is_quantor				= is_quantor p
		# indent_next					= fiIndentQuantors && next_is_quantor
		# indent_now					= fiIndentQuantors && not next_is_quantor
		# finfo							= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
		# finfo							= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
		# (finfo, heaps)				= storePropVar ptr finfo heaps
		# (fvar, heaps)					= ShowPropVar finfo True ptr heaps
		# fquantor						= finfo.fiSpecial.disForall next_is_quantor fvar
		# (error, fprop, heaps, prj)	= FormattedShow finfo p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| indent_now
			= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
			= case fiPosition of
				Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
				Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
		where
			is_quantor (CExprForall _ _)	= True
			is_quantor (CExprExists _ _)	= True
			is_quantor (CPropForall _ _)	= True
			is_quantor (CPropExists _ _)	= True
			is_quantor _					= False
	FormattedShow finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual} (CPropExists ptr p) heaps prj
		# next_is_quantor				= is_quantor p
		# indent_next					= fiIndentQuantors && next_is_quantor
		# indent_now					= fiIndentQuantors && not next_is_quantor
		# finfo							= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
		# finfo							= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
		# (finfo, heaps)				= storePropVar ptr finfo heaps
		# (fvar, heaps)					= ShowPropVar finfo True ptr heaps
		# fquantor						= finfo.fiSpecial.disExists next_is_quantor fvar
		# (error, fprop, heaps, prj)	= FormattedShow finfo p heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| indent_now
			= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
			= case fiPosition of
				Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
				Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
		where
			is_quantor (CExprForall _ _)	= True
			is_quantor (CExprExists _ _)	= True
			is_quantor (CPropForall _ _)	= True
			is_quantor (CPropExists _ _)	= True
			is_quantor _					= False
	FormattedShow finfo=:{fiIndentEqual} (CEqual e1 e2) heaps prj
		# finfo							= {finfo & fiNeedBrackets = False}
		# (error, text1, heaps, prj)	= case depth e1 > DisplayMaxDepth of
											True	-> (OK, DisplayError, heaps, prj)
											False	-> FormattedShow finfo e1 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| e2 == CBasicValue (CBasicBoolean True) && not finfo.fiOptions.optShowIsTrue && is_fun e1
										= (OK, text1, heaps, prj)
		# (error, text2, heaps, prj)	= case depth e2 > DisplayMaxDepth of
											True	-> (OK, DisplayError, heaps, prj)
											False	-> FormattedShow finfo e2 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| fiIndentEqual					= (OK, [CmScope] ++ text1 ++ [CmNewline, CmText "=", CmNewline] ++ text2 ++ [CmEndScope], heaps, prj)
		# text							= text1 ++ [CmText " = "] ++ text2
		# extra_brackets				= finfo.fiOptions.optAlwaysBrackets && isJust finfo.fiPosition
		| extra_brackets				= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
		= (OK, text, heaps, prj)
		where
			is_fun (_ @@# _)			= True
			is_fun other				= False
	FormattedShow finfo=:{fiNeedBrackets} (CPredicate ptr es) heaps prj
		# (error, name, heaps, prj)		= getDefinitionName ptr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, textes, heaps, prj)	= uumapError (FormattedShow finfo) es heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# text							= [CmLink name (CmdShowDefinition ptr)] ++ (Separate False [CmText " "] textes)
		| not fiNeedBrackets			= (OK, text, heaps, prj)
		= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CRecordFieldDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo field heaps prj
		# (error, rectype, prj)			= getRecordTypeDef field.rfRecordType prj
		| isError error					= (error, DummyValue, heaps, prj)
		# fname							= [CmBText field.rfName]
		# (error, ftype, heaps, prj)	= FormattedShow finfo field.rfSymbolType.sytResult heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# fselector						= [CmAlign "selector", CmTabSpace, CmLink "selector" (CmdShowDefinition field.rfSelectorFun)]
		# fupdater						= [CmAlign "updater",  CmTabSpace, CmLink "updater"  (CmdShowDefinition field.rfUpdaterFun)]
		= (OK, fname ++ [CmAlign "fieldtype", CmText " :: "] ++ ftype ++ fselector ++ fupdater, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CRecordTypeDef HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo rectype heaps prj
		# finfo							= {finfo & fiOptions.optShowDictionaries = True}
		# fname							= [CmBText rectype.rtdName]
		# (error, fields, prj)			= umapError getRecordFieldDef rectype.rtdFields prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (ftypescope, heaps)			= ShowTypeScope finfo rectype.rtdTypeVarScope heaps
		# ftypescope					= if (isEmpty ftypescope) [] [CmText " ": ftypescope]
		# fieldnames					= map (\field -> field.rfName) fields
		# len_fieldnames				= map size fieldnames
		# max_len						= maxList len_fieldnames
		# fields						= map (\field -> {field & rfName = adjust_length field.rfName max_len}) fields
		# (error, ffields, heaps, prj)	= uumapError (FormattedShow finfo) fields heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# ffields						= Separate False [CmNewline, CmText ",", CmAlign "recordfield"] ffields
		# (constructor, heaps, prj)		= show_constructor finfo rectype heaps prj
		= (OK, [CmText ":: "] ++ fname ++ ftypescope ++ [CmText " =", CmNewline, CmTabSpace, CmScope, CmText "{ ", CmAlign "recordfield"] ++ ffields ++ [CmNewline, CmText "}", CmEndScope] ++ constructor, heaps, prj)
		where
			adjust_length text max_len
				# len		= size text
				# adjust	= repeatn (max_len - len) ' '
				= text +++ (toString adjust)
			
			show_constructor finfo rectype heaps prj
				# record_funs			= finfo.fiOptions.optShowRecordFuns
				| not record_funs		= ([], heaps, prj)
				# ptr					= rectype.rtdRecordConstructor
				# (_, consdef, prj)		= getDataConsDef ptr prj
				= ([CmNewline, CmText ".", CmNewline, CmBText "record is constructed by ",
				    CmLink consdef.dcdName (CmdShowDefinition ptr)], heaps, prj)

// =================================================================================================================================================
// Abuses the fiNeedBrackets field to optionally leave out the result type (when fiNeedBrackets = FALSE)
// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CSymbolType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo symboltype heaps prj
		# (error, farguments, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) symboltype.sytArguments heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# farguments						= filter (not o isEmpty) farguments
		| not finfo.fiNeedBrackets			= (OK, Separate False [CmText " "] farguments, heaps, prj)
		# farguments						= if (isEmpty farguments) [] ((Separate False [CmText " "] farguments) ++ [CmText " -> "])
		# (error, fresult, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = False} symboltype.sytResult heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# fresult							= if (is_constant_function symboltype.sytArguments symboltype.sytResult) ([CmText "("] ++ fresult ++ [CmText ")"]) fresult
		# (addrestrictions, prj)			= build_restrictions symboltype.sytArguments prj
		# addrestrictions					= if finfo.fiOptions.optShowDictionaries [] addrestrictions
		# (error, frestrictions, heaps, prj)= uumapError (FormattedShow finfo) (symboltype.sytClassRestrictions ++ addrestrictions) heaps prj
		| isError error						= (error, DummyValue, heaps, prj)
		# frestrictions						= if (isEmpty frestrictions) [] ([CmText " | "] ++ (Separate False [CmText " & "] frestrictions))
		= (OK, farguments ++ fresult ++ frestrictions, heaps, prj)
		where
			build_restrictions :: ![CTypeH] !*CProject -> (![CClassRestrictionH], !*CProject)  
			build_restrictions [CStrict type: types] prj
				= build_restrictions [type:types] prj
			build_restrictions [ptr @@^ args: types] prj
				# (error, recorddef, prj)		= getRecordTypeDef ptr prj
				| isError error					= build_restrictions types prj
				| not recorddef.rtdIsDictionary	= build_restrictions types prj
				# restriction					= {ccrClass = recorddef.rtdClassDef, ccrTypes = args}
				# (restrictions, prj)			= build_restrictions types prj
				= ([restriction: restrictions], prj)
			build_restrictions [_: types] prj
				= build_restrictions types prj
			build_restrictions [] prj
				= ([], prj)
			
			is_constant_function :: ![CTypeH] !CTypeH -> Bool
			is_constant_function [] (_ ==> _)	= True
			is_constant_function _ _			= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow (CType HeapPtr)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (CTypeVar ptr) heaps prj
		# (fvar, heaps)					= ShowTypeVar finfo ptr heaps
		= (OK, fvar, heaps, prj)
	FormattedShow finfo (type1 ==> type2) heaps prj
		# (error, ftype1, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} type1 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, ftype2, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = False} type2 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# no_brackets					= ftype1 ++ [CmText " -> "] ++ ftype2
		| finfo.fiNeedBrackets			= (OK, [CmText "("] ++ no_brackets ++ [CmText ")"], heaps, prj)
		= (OK, no_brackets, heaps, prj)
	FormattedShow finfo (type @^ types) heaps prj
		# (error, ftype, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} type heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, ftypes, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) types heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# ftext							= ftype ++ (Separate True [CmText " "] ftypes)
		| isEmpty types					= (OK, ftext, heaps, prj)
		| not finfo.fiNeedBrackets		= (OK, ftext, heaps, prj)
		= (OK, [CmText "("] ++ ftext ++ [CmText ")"], heaps, prj)
	FormattedShow finfo (defptr @@^ types) heaps prj
		# (error, ftypesF, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = False}) types heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# tuple_bools					= [defptr == CTuplePtr n \\ n <- [2..32]]
		| or tuple_bools				= (OK, [CmText "("]  ++ (Separate False [CmText ", "] ftypesF) ++ [CmText ")"], heaps, prj)
		| defptr == CNormalArrayPtr		= (OK, [CmText "{"]  ++ (safehead ftypesF)                   ++ [CmText "}"], heaps, prj)
		| defptr == CStrictArrayPtr		= (OK, [CmText "{!"] ++ (safehead ftypesF)                   ++ [CmText "}"], heaps, prj)
		| defptr == CUnboxedArrayPtr	= (OK, [CmText "{#"] ++ (safehead ftypesF)                   ++ [CmText "}"], heaps, prj)
		| defptr == CListPtr			= (OK, [CmText "["]  ++ (safehead ftypesF)                   ++ [CmText "]"], heaps, prj)
		# (error, defname, heaps, prj)	= safeGetName defptr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# is_dict						= (take 11 [c \\ c <-: defname]) == ['dictionary_']
		# show_dicts					= finfo.fiOptions.optShowDictionaries
		| not show_dicts && is_dict		= (OK, [], heaps, prj)
		# fdef							= case (defptr == finfo.fiHeadPtr) of
											False	-> [CmLink defname (CmdShowDefinition defptr)]
											True	-> [CmText defname]
		# (error, ftypesT, heaps, prj)	= uumapError (FormattedShow {finfo & fiNeedBrackets = True}) types heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# ftext							= fdef ++ (Separate True [CmText " "] ftypesT)
		| isEmpty types					= (OK, ftext, heaps, prj)
		| not finfo.fiNeedBrackets		= (OK, ftext, heaps, prj)
		= (OK, [CmText "("] ++ ftext ++ [CmText ")"], heaps, prj)
		where
//			safehead :: ![(MarkUpText .a)] -> MarkUpText .a
			safehead []		= [CmText ""]
			safehead [f:fs]	= f
			
			safeGetName ptr heaps prj
				# kind					= ptrKind ptr
				| kind == CAlgType		= getDefinitionName ptr heaps prj
				| kind == CRecordType	= getDefinitionName ptr heaps prj
				= (pushError (X_Internal "Expected an algebraic, synonym or record type in type-application. (FormattedShow, CType)") OK, DummyValue, heaps, prj)
			
	FormattedShow finfo (CBasicType basictype) heaps prj
		= FormattedShow finfo basictype heaps prj
	FormattedShow finfo (CStrict type) heaps prj
		# (error, ftype, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} type heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		| isEmpty ftype					= (OK, [], heaps, prj)
		= (OK, [CmText "!": ftype], heaps, prj)
	FormattedShow finfo CUnTypable heaps prj
		= (OK, [CmColour Red, CmText "untypable", CmColour Black], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticShow :: !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticShow name rest
	=	[ CmColour			DarkBrown
		, CmBText			name
		, CmEndColour
		, CmText			(if (isEmpty rest) "" " ")
		, CmColour			Brown
		: normalize rest
		] ++
		[ CmEndColour
		]

// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticShow2 :: !String !(MarkUpText WindowCommand) !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticShow2 name rest1 middle rest2
	=	[ CmColour			DarkBrown
		, CmBText			name
		, CmEndColour
		, CmText			(if (isEmpty rest1) "" " ")
		, CmColour			Brown
		: normalize rest1
		] ++
		[ CmEndColour
		, CmColour			DarkBrown
		, CmBText			(" " +++ middle)
		, CmText			(if (isEmpty rest2) "" " ")
		, CmEndColour
		, CmColour			Brown
		: normalize rest2
		] ++
		[ CmEndColour
		]

// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticModeShow :: !TacticMode !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticModeShow Explicit name rest
	= tacticShow ("Explicit " +++ name) rest
tacticModeShow Implicit name rest
	= tacticShow name rest

// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticModeShow2 :: !TacticMode !String !(MarkUpText WindowCommand) !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
tacticModeShow2 Explicit name rest1 middle rest2
	= tacticShow2 ("Explicit " +++ name) rest1 middle rest2
tacticModeShow2 Implicit name rest1 middle rest2
	= tacticShow2 name rest1 middle rest2

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance FormattedShow TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	FormattedShow finfo (TacticAbsurd ptr1 ptr2) heaps prj
		# (name1, heaps)				= getPointerName ptr1 heaps
		# (name2, heaps)				= getPointerName ptr2 heaps
		# farg							= [CmText name1, CmText " ", CmText name2]
		= (OK, tacticShow "Absurd" farg, heaps, prj)
	FormattedShow finfo TacticAbsurdEquality heaps prj
		= (OK, tacticShow "AbsurdEquality" [], heaps, prj)
	FormattedShow finfo (TacticAbsurdEqualityH ptr) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticShow "AbsurdEquality" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticApply fact) heaps prj
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Apply" ffact, heaps, prj)
	FormattedShow finfo (TacticApplyH fact ptr mode) heaps prj
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (name, heaps)					= getPointerName ptr heaps
		= (OK, tacticModeShow2 mode "Apply" ffact "to" [CmText name], heaps, prj)
	FormattedShow finfo (TacticAssume prop mode) heaps prj
		# (error, fprop, heaps, prj)	= FormattedShow finfo (removeForalls prop) heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticModeShow mode "Assume" fprop, heaps, prj)
	FormattedShow finfo TacticAxiom heaps prj
		= (OK, tacticShow "Axiom" [], heaps, prj)
	FormattedShow finfo (TacticCase Shallow 1) heaps prj
		= (OK, tacticShow "Left" [], heaps, prj)
	FormattedShow finfo (TacticCase Shallow 2) heaps prj
		= (OK, tacticShow "Right" [], heaps, prj)
	FormattedShow finfo (TacticCase depth num) heaps prj
		# fdepth						= showDepth depth
		# fnum							= [CmText (toString num)]
		# fargs							= fdepth ++ [CmText " "] ++ fnum
		= (OK, tacticShow "Case" fargs, heaps, prj)
	FormattedShow finfo (TacticCaseH depth ptr mode) heaps prj
		# fdepth						= showDepth depth
		# (hyp, heaps)					= readPointer ptr heaps
		# fhyp							= [CmText hyp.hypName]
		# fargs							= fdepth ++ [CmText " "] ++ fhyp
		= (OK, tacticModeShow mode "Case" fargs, heaps, prj)
	FormattedShow finfo (TacticCases expr mode) heaps prj
		# (error, fexpr, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticModeShow mode "Cases" fexpr, heaps, prj)
	FormattedShow finfo TacticChooseCase heaps prj
		= (OK, tacticShow "ChooseCase" [], heaps, prj)
	FormattedShow finfo (TacticChooseCaseH ptr) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticShow2 "ChooseCase" [] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticCompare e1 e2) heaps prj
		# (error, fe1, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = True} e1 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# (error, fe2, heaps, prj)		= FormattedShow {finfo & fiNeedBrackets = True} e2 heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow2 "Compare" fe1 "with" fe2, heaps, prj)
	FormattedShow finfo (TacticCompareH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "Compare" [] "using" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticContradiction mode) heaps prj
		= (OK, tacticModeShow mode "Contradiction" [], heaps, prj)
	FormattedShow finfo (TacticContradictionH ptr) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticShow "Contradiction" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticCut fact) heaps prj
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Cut" ffact, heaps, prj)
	FormattedShow finfo TacticDefinedness heaps prj
		= (OK, tacticShow "Definedness" [], heaps, prj)
	FormattedShow finfo (TacticDiscard evars pvars hyps) heaps prj
		# (enames, heaps)				= getPointerNames evars heaps
		# (pnames, heaps)				= getPointerNames pvars heaps
		# (hnames, heaps)				= getPointerNames hyps heaps
		# names							= enames ++ pnames ++ hnames
		# fargs							= Separate False [CmText " "] [[CmText name] \\ name <- names]
		= (OK, tacticShow "Discard" fargs, heaps, prj)
	FormattedShow finfo (TacticExact fact) heaps prj
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Exact" ffact, heaps, prj)
	FormattedShow finfo (TacticExFalso hyp) heaps prj
		# (hyp, heaps)					= readPointer hyp heaps
		= (OK, tacticShow "ExFalso" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticExpandFun name index) heaps prj
		# findex						= [CmText " ", CmText (toString index)]
		= (OK, tacticShow "ExpandFun" [CmText name: findex], heaps, prj)
	FormattedShow finfo (TacticExpandFunH name index ptr mode) heaps prj
		# findex						= [CmText " ", CmText (toString index)]
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "ExpandFun" [CmText name: findex] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticExtensionality name) heaps prj
		= (OK, tacticShow "Extensionality" [CmText name], heaps, prj)
	FormattedShow finfo (TacticGeneralizeE expr name) heaps prj
		# (error, fexpr, heaps, prj)	= FormattedShow finfo expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow2 "Generalize" fexpr "to" [CmText name], heaps, prj)
	FormattedShow finfo (TacticGeneralizeP prop name) heaps prj
		# (error, fprop, heaps, prj)	= FormattedShow finfo prop heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow2 "Generalize" fprop "to" [CmText name], heaps, prj)
	FormattedShow finfo (TacticInduction ptr mode) heaps prj
		# (name, heaps)					= getPointerName ptr heaps
		= (OK, tacticModeShow mode "Induction" [CmText name], heaps, prj)
	FormattedShow finfo TacticInjective heaps prj
		= (OK, tacticShow "Injective" [], heaps, prj)
	FormattedShow finfo (TacticInjectiveH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "Injective" [] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticIntroduce names) heaps prj
		# ftext							= Separate False [CmText " "] [[CmText name] \\ name <- names]
		= (OK, tacticShow "Introduce" ftext, heaps, prj)
	FormattedShow finfo (TacticIntArith location) heaps prj
		# flocation						= showExprLocation location
		= (OK, tacticShow "IntArith" flocation, heaps, prj)
	FormattedShow finfo (TacticIntArithH location ptr mode) heaps prj
		# flocation						= showExprLocation location
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "IntArith" flocation "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo TacticIntCompare heaps prj
		= (OK, tacticShow "IntCompare" [], heaps, prj)
	FormattedShow finfo (TacticManualDefinedness ptrs) heaps prj
		# facts							= [TheoremFact ptr [] \\ ptr <- ptrs]
		# (error, fargs, heaps, prj)	= uumapError (showFact finfo) facts heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# fargs							= Separate False [CmText " "] fargs
		= (OK, tacticShow "ManualDefinedness" fargs, heaps, prj)
	FormattedShow finfo TacticMakeUnique heaps prj
		= (OK, tacticShow "MakeUnique" [], heaps, prj)
	FormattedShow finfo (TacticMoveQuantors dir) heaps prj
		# fdir							= showMoveDirection dir
		= (OK, tacticShow "MoveQuantors" fdir, heaps, prj)
	FormattedShow finfo (TacticMoveQuantorsH dir ptr mode) heaps prj
		# fdir							= showMoveDirection dir
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "MoveQuantors" fdir "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticMoveInCase name index) heaps prj
		# floc							= [CmText name, CmText " ", CmText (toString index)]
		= (OK, tacticShow "MoveInCase" floc, heaps, prj)
	FormattedShow finfo (TacticMoveInCaseH name index ptr mode) heaps prj
		# floc							= [CmText name, CmText " ", CmText (toString index)]
		# (name, heaps)					= getPointerName ptr heaps
		= (OK, tacticModeShow2 mode "MoveInCase" floc "in" [CmText name], heaps, prj)
	FormattedShow finfo (TacticOpaque ptr) heaps prj
		# (_, fundef, prj)				= getFunDef ptr prj
		= (OK, tacticShow "Opaque" [CmText fundef.fdName], heaps, prj)
	FormattedShow finfo (TacticReduce rmode amount loc ptrs) heaps prj
		# famount						= showReduceAmount amount
		# floc							= showExprLocation loc
		# (fptrs, heaps)				= showDefinedVars ptrs heaps
		# farguments					= famount ++ [CmText " "] ++ floc ++ fptrs
		# name							= case rmode of
											AsInClean	-> "Reduce-"
											Defensive	-> "Reduce"
											Offensive	-> "Reduce+"
		= (OK, tacticShow name farguments, heaps, prj)
	FormattedShow finfo (TacticReduceH rmode amount loc hyp ptrs mode) heaps prj
		# famount						= showReduceAmount amount
		# floc							= showExprLocation loc
		# fargs1						= famount ++ [CmText " "] ++ floc
		# (hyp, heaps)					= readPointer hyp heaps
		# fargs2						= [CmText hyp.hypName]
		# (fptrs, heaps)				= showDefinedVars ptrs heaps
		# name							= case rmode of
											AsInClean	-> "Reduce-"
											Defensive	-> "Reduce"
											Offensive	-> "Reduce+"
		= (OK, tacticModeShow2 mode name fargs1 "in" (fargs2 ++ fptrs), heaps, prj)
	FormattedShow finfo TacticRefineUndefinedness heaps prj
		= (OK, tacticShow "RefineUndefinedness" [], heaps, prj)
	FormattedShow finfo (TacticRefineUndefinednessH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "RefineUndefinedness" [] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo TacticReflexive heaps prj
		= (OK, tacticShow "Reflexive" [], heaps, prj)
	FormattedShow finfo (TacticRemoveCase index) heaps prj
		= (OK, tacticShow "RemoveCase" [CmText (toString index)], heaps, prj)
	FormattedShow finfo (TacticRemoveCaseH index ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "RemoveCase" [CmText (toString index)] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticRenameE ptr name2) heaps prj
		# (name1, heaps)				= getPointerName ptr heaps
		= (OK, tacticShow2 "Rename" [CmText name1] "to" [CmText name2], heaps, prj)
	FormattedShow finfo (TacticRenameP ptr name2) heaps prj
		# (name1, heaps)				= getPointerName ptr heaps
		= (OK, tacticShow2 "Rename" [CmText name1] "to" [CmText name2], heaps, prj)
	FormattedShow finfo (TacticRenameH ptr name2) heaps prj
		# (name1, heaps)				= getPointerName ptr heaps
		= (OK, tacticShow2 "Rename" [CmText name1] "to" [CmText name2], heaps, prj)
	FormattedShow finfo (TacticRewrite direction redex fact) heaps prj
		# fdirection					= showRewriteDirection direction
		# fredex						= showRedex redex
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# farguments					= fdirection ++ [CmText " "] ++ fredex ++ [CmText " "] ++ ffact
		= (OK, tacticShow "Rewrite" farguments, heaps, prj)
	FormattedShow finfo (TacticRewriteH direction redex fact hyp mode) heaps prj
		# fdirection					= showRewriteDirection direction
		# fredex						= showRedex redex
		# (error, ffact, heaps, prj)	= showFact finfo fact heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		# farguments1					= fdirection ++ [CmText " "] ++ fredex ++ [CmText " "] ++ ffact
		# (hyp, heaps)					= readPointer hyp heaps
		# fhyp							= [CmText hyp.hypName]
		= (OK, tacticModeShow2 mode "Rewrite" farguments1 "in" fhyp, heaps, prj)
	FormattedShow finfo (TacticSpecializeE ptr expr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		# (error, fexpr, heaps, prj)	= FormattedShow finfo expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticModeShow2 mode "Specialize" [CmText hyp.hypName] "with" fexpr, heaps, prj)
	FormattedShow finfo (TacticSpecializeP ptr prop mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		# (error, fprop, heaps, prj)	= FormattedShow finfo prop heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticModeShow2 mode "Specialize" [CmText hyp.hypName] "with" fprop, heaps, prj)
	FormattedShow finfo (TacticSplit depth) heaps prj
		= (OK, tacticShow "Split" (showDepth depth), heaps, prj)
	FormattedShow finfo (TacticSplitCase num mode) heaps prj
		= (OK, tacticModeShow mode "SplitCase" [CmText (toString num)], heaps, prj)
	FormattedShow finfo (TacticSplitH ptr depth mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		# fdepth						= showDepth depth
		= (OK, tacticModeShow mode "Split" (fdepth ++ [CmText " ", CmText hyp.hypName]), heaps, prj)
	FormattedShow finfo TacticSplitIff heaps prj
		= (OK, tacticShow "SplitIff" [], heaps, prj)
	FormattedShow finfo (TacticSplitIffH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow mode "SplitIff" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo TacticSymmetric heaps prj
		= (OK, tacticShow "Symmetric" [], heaps, prj)
	FormattedShow finfo (TacticSymmetricH ptr mode) heaps prj
		# (name, heaps)					= getPointerName ptr heaps
		= (OK, tacticModeShow mode "Symmetric" [CmText name], heaps, prj)
	FormattedShow finfo (TacticTransitiveE expr) heaps prj
		# (error, fexpr, heaps, prj)	= FormattedShow finfo expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Transitive" fexpr, heaps, prj)
	FormattedShow finfo (TacticTransitiveP prop) heaps prj
		# (error, fprop, heaps, prj)	= FormattedShow finfo prop heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Transitive" fprop, heaps, prj)
	FormattedShow finfo (TacticTransparent ptr) heaps prj
		# (_, fundef, prj)				= getFunDef ptr prj
		= (OK, tacticShow "Transparent" [CmText fundef.fdName], heaps, prj)
	FormattedShow finfo TacticTrivial heaps prj
		= (OK, tacticShow "Trivial" [], heaps, prj)
	FormattedShow finfo TacticUncurry heaps prj
		= (OK, tacticShow "Uncurry" [], heaps, prj)
	FormattedShow finfo (TacticUncurryH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "Uncurry" [] "in" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticUnshare mode letl var varl) heaps prj
		# tactic_name					= if mode "Unshare" "Unshare-"
		= (OK, tacticShow	tactic_name	[CmText (toString letl), CmText " ", CmText var, CmText " ", CmText (toString varl)], heaps, prj)
	FormattedShow finfo (TacticUnshareH mode letl var varl ptr) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		# tactic_name					= if mode "Unshare" "Unshare-"
		= (OK, tacticShow2	tactic_name	[CmText (toString letl), CmText " ", CmText var, CmText " ", CmText (toString varl)]
							"in"		[CmText hyp.hypName], heaps, prj)
	FormattedShow finfo (TacticWitnessE expr) heaps prj
		# (error, fexpr, heaps, prj)	= FormattedShow finfo expr heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Witness" fexpr, heaps, prj)
	FormattedShow finfo (TacticWitnessP prop) heaps prj
		# (error, fprop, heaps, prj)	= FormattedShow finfo prop heaps prj
		| isError error					= (error, DummyValue, heaps, prj)
		= (OK, tacticShow "Witness" fprop, heaps, prj)
	FormattedShow finfo (TacticWitnessH ptr mode) heaps prj
		# (hyp, heaps)					= readPointer ptr heaps
		= (OK, tacticModeShow2 mode "Witness" [] "for" [CmText hyp.hypName], heaps, prj)
	FormattedShow finfo tactic heaps prj
		#! heaps						= heaps --->> tactic
		= (OK, tacticShow "?tactic?" [], heaps, prj)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
formattedShow :: !HeapPtr !FormatInfo !*CHeaps !*CProject 
			  -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
formattedShow ptr finfo heaps prj
	= show (ptrKind ptr) ptr finfo heaps prj
	where
		show CAlgType ptr finfo heaps prj
			# (error, algtypedef, prj)			= getAlgTypeDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo algtypedef heaps prj
		show CClass ptr finfo heaps prj
			# (error, classdef, prj)			= getClassDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo classdef heaps prj
		show CDataCons ptr finfo heaps prj
			# finfo								= {finfo & fiHeadPtr = ptr}
			# (error, dataconsdef, prj)			= getDataConsDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# (error, rectypedef, prj)			= getRecordTypeDef dataconsdef.dcdAlgType prj
			| isOK error						= show_record_constructor finfo dataconsdef rectypedef heaps prj
			# (error, algtypedef, prj)			= getAlgTypeDef dataconsdef.dcdAlgType prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = dataconsdef.dcdAlgType} 
			= FormattedShow finfo algtypedef heaps prj
		show CFun ptr finfo heaps prj
			# (error, fundef, prj)				= getFunDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo fundef heaps prj
		show CInstance ptr finfo heaps prj
			# (error, instancedef, prj)			= getInstanceDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo instancedef heaps prj
		show CMember ptr finfo heaps prj
			# (error, memberdef, prj)			= getMemberDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# (error, classdef, prj)			= getClassDef memberdef.mbdClass prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo classdef heaps prj
		show CRecordField ptr finfo heaps prj
			# (error, recordfielddef, prj)		= getRecordFieldDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# (error, recordtypedef, prj)		= getRecordTypeDef recordfielddef.rfRecordType prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo recordtypedef heaps prj
		show CRecordType ptr finfo heaps prj
			# (error, recordtypedef, prj)		= getRecordTypeDef ptr prj
			| isError error						= (error, DummyValue, heaps, prj)
			# finfo								= {finfo & fiHeadPtr = ptr}
			= FormattedShow finfo recordtypedef heaps prj
		
		show_record_constructor :: !FormatInfo !CDataConsDefH !CRecordTypeDefH !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		show_record_constructor finfo dataconsdef rectypedef heaps prj
			# fname								= [CmBold, CmText dataconsdef.dcdName, CmText " :: ", CmEndBold]
			# finfo								= {finfo & fiNeedBrackets = True, fiOptions.optShowDictionaries = True}
			# (error, ftype, heaps, prj)		= FormattedShow finfo dataconsdef.dcdSymbolType heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			= (OK, fname ++ ftype, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showDefinedVars :: ![CExprVarPtr] !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showDefinedVars [] heaps
	= ([], heaps)
showDefinedVars ptrs heaps
	# (names, heaps)							= getPointerNames ptrs heaps
	= ([CmText " (defined "] ++ Separate False [CmText " "] (map cmtext names) ++ [CmText ")"], heaps)
	where
		cmtext text = [CmText text]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showDepth :: !Depth -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showDepth Shallow
	= [CmText "Shallow"]
showDepth Deep
	= [CmText "Deep"]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showEVar :: !UseExprVar -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showEVar (KnownExprVar name ptr)
	= [CmText name]
showEVar (UnknownExprVar name)
	= [CmText name]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showExprLocation :: !ExprLocation -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showExprLocation AllSubExprs
	= [CmText "All"]
showExprLocation (SelectedSubExpr name index Nothing)
	= [CmText "(", CmText name, CmText " ", CmText (toString index), CmText ")"]
showExprLocation (SelectedSubExpr name index (Just sub_index))
	= [CmText "(", CmText name, CmText " ", CmText (toString index), CmText "#", CmText (toString sub_index), CmText ")"]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showFact :: !FormatInfo !UseFact !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showFact finfo (HypothesisFact ptr args) heaps prj
	# (name, heaps)								= getPointerName ptr heaps
	| isEmpty args								= (OK, [CmText name], heaps, prj)
	# (error, fargs, heaps, prj)				= showFactArgs finfo args heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	= (OK, [CmText "(", CmText name, CmText " "] ++ fargs ++ [CmText ")"], heaps, prj)
showFact finfo (TheoremFact ptr args) heaps prj
	# (name, heaps)								= getPointerName ptr heaps
	# fname										= [CmText "\"", CmText name, CmText "\""]
	| isEmpty args								= (OK, fname, heaps, prj)
	# (error, fargs, heaps, prj)				= showFactArgs finfo args heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	= (OK, [CmText "("] ++ fname ++ [CmText " "] ++ fargs ++ [CmText ")"], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showFactArgs :: !FormatInfo ![UseFactArgument] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showFactArgs finfo [] heaps prj
	= (OK, [], heaps, prj)
showFactArgs finfo [NoArgument: args] heaps prj
	| isEmpty args								= (OK, [CmText "_"], heaps, prj)
	# (error, fargs, heaps, prj)				= showFactArgs finfo args heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	= (OK, [CmText "_", CmText " ": fargs], heaps, prj)
showFactArgs finfo [ExprArgument expr: args] heaps prj
	# (error, fexpr, heaps, prj)				= FormattedShow finfo expr heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	| isEmpty args								= (OK, fexpr, heaps, prj)
	# (error, fargs, heaps, prj)				= showFactArgs finfo args heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	= (OK, fexpr ++ [CmText " ": fargs], heaps, prj)
showFactArgs finfo [PropArgument prop: args] heaps prj
	# (error, fprop, heaps, prj)				= FormattedShow finfo prop heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	| isEmpty args								= (OK, fprop, heaps, prj)
	# (error, fargs, heaps, prj)				= showFactArgs finfo args heaps prj
	| isError error								= (error, DummyValue, heaps, prj)
	= (OK, fprop ++ [CmText " ": fargs], heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showMoveDirection :: !MoveDirection -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showMoveDirection MoveIn
	= [CmText "In"]
showMoveDirection MoveOut
	= [CmText "Out"]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showRedex :: !Redex -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showRedex AllRedexes
	= [CmText "All"]
showRedex (OneRedex index)
	= [CmText (toString index)]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showReduceAmount :: !ReduceAmount -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showReduceAmount ReduceToNF
	= [CmText "NF"]
showReduceAmount ReduceToRNF
	= [CmText "RNF"]
showReduceAmount (ReduceExactly n)
	= [CmText (toString n)]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showRewriteDirection :: !RewriteDirection -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showRewriteDirection LeftToRight
	= [CmText "->"]
showRewriteDirection RightToLeft
	= [CmText "<-"]



























// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Icon =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ApplyIcon
	| InfoIcon
	| HelpIcon
	| MoveIcon
	| ProveIcon
	| RecycleIcon
	| RenameIcon
	| RemoveIcon
	| SaveIcon
	| ViewContentsIcon

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: IconInfo item a =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ iiIcon				:: !Icon
	, iiLinkStyle			:: !Int
	, iiCommand				:: !(Ptr item) -> a
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
IconSymbol :: !Icon -> (!CName, !Int)
// -------------------------------------------------------------------------------------------------------------------------------------------------
IconSymbol ApplyIcon							= ("Webdings", 52)
IconSymbol InfoIcon								= ("Webdings", 105)
IconSymbol HelpIcon								= ("Webdings", 115)
IconSymbol MoveIcon								= ("Webdings", 146)
IconSymbol ProveIcon							= ("Webdings", 232)
IconSymbol RecycleIcon							= ("Webdings", 96)
IconSymbol RenameIcon							= ("Webdings", 62)
IconSymbol RemoveIcon							= ("Webdings", 114)
IconSymbol SaveIcon								= ("Wingdings", 60)
IconSymbol ViewContentsIcon						= ("Wingdings", 52)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showIconList :: ![Ptr item] ![IconInfo item a] !((Ptr item) -> item -> MarkUpText a) ![IconInfo item a] !*CHeaps -> (!MarkUpText a, !*CHeaps) | Pointer item
// -------------------------------------------------------------------------------------------------------------------------------------------------
showIconList ptrs icons1 f icons2 heaps
	# (names, heaps)							= getPointerNames ptrs heaps
	# (items, heaps)							= readPointers ptrs heaps
	# infos										= sortBy (\(n1,i1,p1)(n2,i2,p2) -> n1 < n2) [(name,item,ptr) \\ name <- names & item <- items & ptr <- ptrs]
	= (show infos, heaps)
	where
		show [(name,item,ptr):infos]
			# ficons1							= show_icons icons1 ptr
			# fthis								= f ptr item
			# ficons2							= case isEmpty icons2 of
													True	-> []
													False	-> [CmAlign "@ICONS2", CmSpaces 1: show_icons icons2 ptr]
			# frest								= show infos
			= ficons1 ++ [CmSpaces 1] ++ fthis ++ ficons2 ++ [CmNewline: frest]
		show []
			= []
		
		show_icons [icon:icons] ptr
			# (font, charcode)					= IconSymbol icon.iiIcon
			# ficon								= 	[ CmFontFace		font
													, CmLink2			icon.iiLinkStyle {toChar charcode} (icon.iiCommand ptr)
													, CmEndFontFace
													]
			# ficons							= show_icons icons ptr
			= ficon ++ ficons
		show_icons [] ptr
			= []

// Used CmNewlineI instead of CmNewline
// -------------------------------------------------------------------------------------------------------------------------------------------------
showIconList1 :: ![Ptr item] ![IconInfo item a] !((Ptr item) -> item -> MarkUpText a) ![IconInfo item a] !Colour !*CHeaps -> (!MarkUpText a, !*CHeaps) | Pointer item
// -------------------------------------------------------------------------------------------------------------------------------------------------
showIconList1 ptrs icons1 f icons2 colour heaps
	# (names, heaps)							= getPointerNames ptrs heaps
	# (items, heaps)							= readPointers ptrs heaps
	# infos										= sortBy (\(n1,i1,p1)(n2,i2,p2) -> n1 < n2) [(name,item,ptr) \\ name <- names & item <- items & ptr <- ptrs]
	= (show infos, heaps)
	where
		show [(name,item,ptr):infos]
			# ficons1							= show_icons icons1 ptr
			# fthis								= f ptr item
			# ficons2							= case isEmpty icons2 of
													True	-> []
													False	-> [CmAlign "@ICONS2", CmSpaces 1: show_icons icons2 ptr]
			# frest								= show infos
			= ficons1 ++ [CmSpaces 1] ++ fthis ++ ficons2 ++ [CmNewlineI False 1 (Just colour): frest]
		show []
			= []
		
		show_icons [icon:icons] ptr
			# (font, charcode)					= IconSymbol icon.iiIcon
			# ficon								= 	[ CmFontFace		font
													, CmLink2			icon.iiLinkStyle {toChar charcode} (icon.iiCommand ptr)
													, CmEndFontFace
													]
			# ficons							= show_icons icons ptr
			= ficon ++ ficons
		show_icons [] ptr
			= []