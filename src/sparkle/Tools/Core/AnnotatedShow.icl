/*
** Program: Clean Prover System
** Module:  AnnotatedShow (.icl)
** 
** Author:  Maarten de Mol
** Created: 16 February 2001
*/

implementation module 
	AnnotatedShow

import
	StdEnv,
	StdIO,
	FormattedShow,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: AnnotateInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ aiInGoal					:: !Bool
	, aiInHypothesis			:: !HypothesisPtr
	, aiNextHypNum				:: !Int
	, aiCase					:: !Bool
	, aiContradiction			:: !Bool
	, aiExFalso					:: !Bool
	, aiIntroduce				:: !Bool
	, aiIntroducedNames			:: ![CName]
	, aiSplit					:: !Bool
	, aiSplitIff				:: !Bool
	, aiTrivial					:: !Bool
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: APropH =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  APropVar										!CPropVarPtr
	| ATrue						![ProvingAction]
	| AFalse					![ProvingAction]
	| AEqual					![ProvingAction]	!CExprH !CExprH
	| ANot						![ProvingAction]	!APropH
	| AAnd						![ProvingAction]	!APropH !APropH
	| AOr						![ProvingAction]	!APropH !APropH
	| AImplies					![ProvingAction]	!APropH !APropH
	| AIff						![ProvingAction]	!APropH !APropH
	| AExprForall				![ProvingAction]	!CExprVarPtr !APropH
	| AExprExists				![ProvingAction]	!CExprVarPtr !APropH
	| APropForall				![ProvingAction]	!CPropVarPtr !APropH
	| APropExists				![ProvingAction]	!CPropVarPtr !APropH
	| APredicate									!HeapPtr !.[CExprH]

// Mirror in FormattedShow
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: DisplayAnnotated =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ diaForall						:: [ProvingAction] -> Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaExists						:: [ProvingAction] -> Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaAnd						:: [ProvingAction] -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaOr							:: [ProvingAction] -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaNot						:: [ProvingAction] -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaImplies					:: [ProvingAction] -> Bool -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	, diaIff						:: [ProvingAction] -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand) -> (MarkUpText WindowCommand)
	}
instance DummyValue DisplayAnnotated
	where DummyValue =	{ diaForall		= \as n p -> [CmColour LogicColour, CmBText "[", CmEndColour] ++ p ++ [CmColour LogicColour, CmBText "]", CmEndColour]
						, diaExists		= \as n p -> [CmColour LogicColour, CmBText "{", CmEndColour] ++ p ++ [CmColour LogicColour, CmBText "}", CmEndColour]
						, diaAnd		= \as p q -> p ++ [CmColour LogicColour, CmBText " /\\ ", CmEndColour] ++ q
						, diaOr			= \as p q -> p ++ [CmColour LogicColour, CmBText " \\/ ", CmEndColour] ++ q
						, diaNot		= \as p -> [CmColour LogicColour, CmBText "~", CmEndColour] ++ p
						, diaImplies	= \as i p q -> p ++ [CmColour LogicColour, CmBText (if i "-> " " -> "), CmEndColour] ++ q
						, diaIff		= \as p q -> p ++ [CmColour LogicColour, CmBText " <-> ", CmEndColour] ++ q
						}














// Mirror in States
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildDisplayAnnotated :: !*PState -> (!DisplayAnnotated, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildDisplayAnnotated pstate
	# (has_symbol, pstate)		= pstate!ls.stFontsPresent.fpSymbol
	# (has_vdm, pstate)			= pstate!ls.stFontsPresent.fpVdm
	| has_vdm					= (build_display_annotated "VDM and Z 1.0" vdm, pstate)
	| has_symbol				= (build_display_annotated "Symbol" symbol, pstate)
	= (DummyValue, pstate)
	where
		symbol					= map (\num -> {toChar num}) [34,36,216,217,218,174,171]
		vdm						= map (\num -> {toChar num}) [34,36,216,217,218,222,219]
		
		quantor :: ![ProvingAction] !String !String !Bool !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		quantor actions font quantor next fvar
			=	[ CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, fquantor
				, CmEndFontFace
				] ++ change_fvar fvar ++
				[ CmText				(if next "" ".")
				, CmEndColour
				, CmEndBold
				]
			where
				fquantor				= if (isEmpty actions)
											(CmText quantor)
											(CmLink2 1 quantor (CmdProveByClicking actions))
				
				change_fvar [CmText "::": commands]
					= [CmEndBold, CmColour type_colour, CmText "::": removeCmLink commands] ++ [CmEndColour, CmBold]
				change_fvar [CmText "::PROP"]
					= [CmEndBold, CmColour type_colour, CmText "::PROP"] ++ [CmEndColour, CmBold]
				change_fvar [command: commands]
					= [command: change_fvar commands]
				change_fvar []
					= []
				
				type_colour
					= RGB {r=0, g=190, b=75}
		
		unary_op :: ![ProvingAction] !String !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		unary_op actions font op fp
			=	[ CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, fop
				, CmEndFontFace
				, CmEndColour
				, CmEndBold
				] ++ fp
			where
				fop						= if (isEmpty actions)
											(CmText op)
											(CmLink2 1 op (CmdProveByClicking actions))
		
		binary_op :: ![ProvingAction] !Bool !String !String !(MarkUpText WindowCommand) !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		binary_op actions indent font op fp fq
			=	fp ++
				[ CmText				(if indent "" " ")
				, CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, fop
				, CmEndFontFace
				, CmEndColour
				, CmEndBold
				, CmText				" "
				] ++ fq
			where
				fop						= if (isEmpty actions)
											(CmText op)
											(CmLink2 1 op (CmdProveByClicking actions))
		
		build_display_annotated :: !String ![String] -> DisplayAnnotated
		build_display_annotated font [forall,exists,not,and,or,implies,iff]
			=	{ diaForall				= \as n p	-> quantor as font forall n p
				, diaExists				= \as n p	-> quantor as font exists n p
				, diaNot				= \as p		-> unary_op as font not p
				, diaAnd				= \as p q	-> binary_op as False font and p q
				, diaOr					= \as p q	-> binary_op as False font or p q
				, diaImplies			= \as i p q -> binary_op as i font implies p q
				, diaIff				= \as p q	-> binary_op as False font iff p q
				}




















// -------------------------------------------------------------------------------------------------------------------------------------------------
showAnnotated :: !FormatInfo !APropH !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showAnnotated finfo prop pstate
	# (display, pstate)					= buildDisplayAnnotated pstate
	= accErrorHeapsProject (showAProp display finfo prop) pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
annotateGoal :: !CPropH !Goal !*PState -> (!APropH, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
annotateGoal prop goal pstate
	= accHeaps (annotate info prop) pstate
	where
		info
			=	{ aiInGoal				= True
				, aiInHypothesis		= nilPtr
				, aiNextHypNum			= goal.glNewHypNum
				, aiCase				= False
				, aiContradiction		= True
				, aiExFalso				= False
				, aiIntroduce			= True
				, aiIntroducedNames		= []
				, aiSplit				= True
				, aiSplitIff			= True
				, aiTrivial				= True
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
annotateHypothesis :: !HypothesisPtr !CPropH !Goal !*PState -> (!APropH, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
annotateHypothesis ptr prop goal pstate
	= accHeaps (annotate info prop) pstate
	where
		info
			=	{ aiInGoal				= False
				, aiInHypothesis		= ptr
				, aiNextHypNum			= goal.glNewHypNum
				, aiCase				= True
				, aiContradiction		= True
				, aiExFalso				= True
				, aiIntroduce			= False
				, aiIntroducedNames		= []
				, aiSplit				= True
				, aiSplitIff			= True
				, aiTrivial				= False
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
annotate :: !AnnotateInfo !CPropH !*CHeaps -> (!APropH, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
annotate info (CPropVar ptr) heaps
	= (APropVar ptr, heaps)
annotate info CTrue heaps
	# trivial_action					= case info.aiTrivial of
											True	-> [KnowArguments TacticTrivial]
											False	-> []
	= (ATrue trivial_action, heaps)
annotate info CFalse heaps
	# exfalso_action					= case info.aiExFalso of
											True	-> [KnowArguments (TacticExFalso info.aiInHypothesis)]
											False	-> []
	= (AFalse exfalso_action, heaps)
annotate info (CEqual e1 e2) heaps
	= (AEqual [] e1 e2, heaps)
annotate info (CNot p) heaps
	# p_info							= { info	& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (p, heaps)						= annotate p_info p heaps
	# contradict_action					= case info.aiContradiction of
											True	-> case info.aiInGoal of
														True	-> [KnowArguments (TacticContradiction Implicit)]
														False	-> [KnowArguments (TacticContradictionH info.aiInHypothesis)]
											False	-> []
	= (ANot contradict_action p, heaps)
annotate info (CAnd p q) heaps
	# p_info							= { info	& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (p, heaps)						= annotate p_info p heaps
	# q_info							= { info	& aiCase			= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (q, heaps)						= annotate q_info q heaps
	# split_action						= case info.aiSplit of
											True	-> case info.aiInGoal of
														True	-> [KnowArguments (TacticSplit Deep)]
														False	-> [KnowArguments (TacticSplitH info.aiInHypothesis Deep Implicit)]
											False	-> []
	= (AAnd split_action p q, heaps)
annotate info (COr p q) heaps
	# p_info							= { info	& aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (p, heaps)						= annotate p_info p heaps
	# q_info							= { info	& aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (q, heaps)						= annotate q_info q heaps
	# case_action						= case info.aiCase of
											True	-> case info.aiInGoal of
														True	-> []
														False	-> [KnowArguments (TacticCaseH Deep info.aiInHypothesis Implicit)]
											False	-> []
	= (AOr case_action p q, heaps)
annotate info (CImplies p q) heaps
	# p_info							= { info	& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (p, heaps)						= annotate p_info p heaps
	# q_info							= { info	& aiIntroducedNames	= ["H" +++ toString info.aiNextHypNum: info.aiIntroducedNames]
													, aiNextHypNum		= info.aiNextHypNum+1
													, aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiSplit			= False
													, aiSplitIff		= False}
	# (q, heaps)						= annotate q_info q heaps
	# intro_action						= case info.aiIntroduce of
											True	-> [KnowArguments (TacticIntroduce (reverse q_info.aiIntroducedNames))]
											False	-> []
	= (AImplies intro_action p q, heaps)
annotate info (CIff p q) heaps
	# p_info							= { info	& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (p, heaps)						= annotate p_info p heaps
	# q_info							= { info	& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False
													, aiTrivial			= False}
	# (q, heaps)						= annotate q_info q heaps
	# split_action						= case info.aiSplit of
											True	-> case info.aiInGoal of
														True	-> [KnowArguments TacticSplitIff]
														False	-> [KnowArguments (TacticSplitIffH info.aiInHypothesis Implicit)]
											False	-> []
	= (AIff split_action p q, heaps)
annotate info (CExprForall ptr p) heaps
	# (var, heaps)						= readPointer ptr heaps
	# p_info							= { info	& aiIntroducedNames	= [var.evarName: info.aiIntroducedNames]
													, aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiSplit			= False
													, aiSplitIff		= False}
	# (p, heaps)						= annotate p_info p heaps
	# intro_action						= case info.aiIntroduce of
											True	-> [KnowArguments (TacticIntroduce (reverse p_info.aiIntroducedNames))]
											False	-> []
	= (AExprForall intro_action ptr p, heaps)
annotate info (CExprExists ptr p) heaps
	# (var, heaps)						= readPointer ptr heaps
	# p_info							= {info		& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False}
	# (p, heaps)						= annotate p_info p heaps
	= (AExprExists [] ptr p, heaps)
annotate info (CPropForall ptr p) heaps
	# (var, heaps)						= readPointer ptr heaps
	# p_info							= { info	& aiIntroducedNames	= [var.pvarName: info.aiIntroducedNames]
													, aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiSplit			= False
													, aiSplitIff		= False}
	# (p, heaps)						= annotate p_info p heaps
	# intro_action						= case info.aiIntroduce of
											True	-> [KnowArguments (TacticIntroduce (reverse p_info.aiIntroducedNames))]
											False	-> []
	= (APropForall intro_action ptr p, heaps)
annotate info (CPropExists ptr p) heaps
	# (var, heaps)						= readPointer ptr heaps
	# p_info							= {info		& aiCase			= False
													, aiContradiction	= False
													, aiExFalso			= False
													, aiIntroduce		= False
													, aiSplit			= False
													, aiSplitIff		= False}
	# (p, heaps)						= annotate p_info p heaps
	= (APropExists [] ptr p, heaps)
annotate info (CPredicate ptr exprs) heaps
	= (APredicate ptr exprs, heaps)







































// Mirror in FormattedShowShow
// -------------------------------------------------------------------------------------------------------------------------------------------------
showAProp :: !DisplayAnnotated !FormatInfo !APropH !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showAProp display finfo (APropVar ptr) heaps prj
	= FormattedShow finfo (HPropVar ptr) heaps prj
showAProp display finfo (ATrue commands) heaps prj
	| isEmpty commands
		# (error, fprop, heaps, prj)	= FormattedShow finfo HTrue heaps prj
		= (error, fprop, heaps, prj)
	= (OK, [CmBold, CmLink2 1 "TRUE" (CmdProveByClicking commands), CmEndBold], heaps, prj)
showAProp display finfo (AFalse commands) heaps prj
	| isEmpty commands
		# (error, fprop, heaps, prj)	= FormattedShow finfo HFalse heaps prj
		= (error, fprop, heaps, prj)
	= (OK, [CmBold, CmLink2 1 "FALSE" (CmdProveByClicking commands), CmEndBold], heaps, prj)
showAProp display finfo=:{fiIndentEqual} (AEqual commands e1 e2) heaps prj
	# finfo								= {finfo & fiNeedBrackets = False}
	# (error, fe1, heaps, prj)			= case depth e1 > DisplayMaxDepth of
											True	-> (OK, DisplayError, heaps, prj)
											False	-> FormattedShow finfo e1 heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	| e2 == CBasicValue (CBasicBoolean True) && not finfo.fiOptions.optShowIsTrue && is_fun e1
										= (OK, fe1, heaps, prj)
	# (error, fe2, heaps, prj)			= case depth e2 > DisplayMaxDepth of
											True	-> (OK, DisplayError, heaps, prj)
											False	-> FormattedShow finfo e2 heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# fequal							= case isEmpty commands of
											True	-> [CmText "="]
											False	-> [CmText "="]
	| fiIndentEqual						= (OK, [CmScope] ++ fe1 ++ [CmNewline] ++ fequal ++ [CmNewline] ++ fe2 ++ [CmEndScope], heaps, prj)
	# extra_brackets					= finfo.fiOptions.optAlwaysBrackets && isJust finfo.fiPosition
	= case extra_brackets of
		True	-> (OK, [CmText "("] ++ fe1 ++ [CmText " "] ++ fequal ++ [CmText " "] ++ fe2 ++ [CmText ")"], heaps, prj)
		False	-> (OK, fe1 ++ [CmText " "] ++ fequal ++ [CmText " "] ++ fe2, heaps, prj)
	where
		is_fun (_ @@# _)				= True
		is_fun other					= False
showAProp display finfo (ANot commands p) heaps prj
	# finfo								= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
	# finfo								= {finfo & fiNeedBrackets = True, fiPosition = Nothing}
	# (error, textp, heaps, prj)		= showAProp display finfo p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# textp								= if (is_equal p) ([CmText "("] ++ textp ++ [CmText ")"]) textp
	= (OK, display.diaNot commands textp, heaps, prj)
	where
		is_equal (AEqual _ e1 e2)		= True
		is_equal _						= False
showAProp display finfo=:{fiNeedBrackets, fiPosition} (AAnd commands p q) heaps prj
	# finfo								= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
	# finfo								= {finfo & fiNeedBrackets = True}
	# (error, textp, heaps, prj)		= showAProp display {finfo & fiPosition = Just LeftOfAnd} p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, textq, heaps, prj)		= showAProp display {finfo & fiPosition = Just RightOfAnd} q heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# text								= display.diaAnd commands textp textq
	# brackets							= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfAnd, Just LeftOfIff, Just RightOfIff]
	# brackets							= finfo.fiOptions.optAlwaysBrackets || brackets
	| not brackets						= (OK, text, heaps, prj)
	= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
showAProp display finfo=:{fiNeedBrackets, fiPosition} (AOr commands p q) heaps prj
	# finfo								= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
	# finfo								= {finfo & fiNeedBrackets = True}
	# (error, textp, heaps, prj)		= showAProp display {finfo & fiPosition = Just LeftOfOr} p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, textq, heaps, prj)		= showAProp display {finfo & fiPosition = Just RightOfOr} q heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# text								= display.diaOr commands textp textq
	# brackets							= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfAnd, Just RightOfAnd, Just LeftOfOr, Just LeftOfIff, Just RightOfIff]
	# brackets							= finfo.fiOptions.optAlwaysBrackets || brackets
	| not brackets						= (OK, text, heaps, prj)
	= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
// BEZIG
showAProp display finfo=:{fiNeedBrackets, fiPosition, fiIndentImplies} (AImplies commands p q) heaps prj
//	# finfo								= {finfo & fiIndentQuantors = False}
	# finfo								= {finfo & fiNeedBrackets = True}
	# (error, textp, heaps, prj)		= showAProp display {finfo & fiPosition = Just LeftOfImplies, fiIndentImplies = False, fiIndentEqual = False, fiIndentQuantors = False} p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, textq, heaps, prj)		= showAProp display {finfo & fiPosition = Just RightOfImplies} q heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	| fiIndentImplies					= (OK, display.diaImplies commands True (textp++[CmNewline]) textq, heaps, prj)
	# text								= display.diaImplies commands False textp textq
	# brackets							= case fiNeedBrackets of
											False	-> False
											True	-> fiPosition <> Just RightOfImplies
	# brackets							= finfo.fiOptions.optAlwaysBrackets || brackets
	| not brackets						= (OK, text, heaps, prj)
	= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
showAProp display finfo=:{fiIndentEqual, fiNeedBrackets, fiPosition} (AIff commands p q) heaps prj
	# finfo								= {finfo & fiIndentQuantors = False, fiIndentImplies = False, fiIndentEqual = False}
	# finfo								= {finfo & fiNeedBrackets = True}
	# (error, textp, heaps, prj)		= showAProp display {finfo & fiPosition = Just LeftOfIff} p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (error, textq, heaps, prj)		= showAProp display {finfo & fiPosition = Just RightOfIff} q heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	| fiIndentEqual
		# fsymbol						= remove_first_space (display.diaIff commands [] [])
		= (OK, [CmScope] ++ textp ++ [CmNewline] ++ fsymbol ++ [CmNewline] ++ textq ++ [CmEndScope], heaps, prj)
	# text								= display.diaIff commands textp textq
	# brackets							= case fiNeedBrackets of
											False	-> False
											True	-> isMember fiPosition [Nothing, Just LeftOfIff]
	# brackets							= finfo.fiOptions.optAlwaysBrackets || brackets
	| not brackets						= (OK, text, heaps, prj)
	= (OK, [CmText "("] ++ text ++ [CmText ")"], heaps, prj)
	where
		remove_first_space :: !(MarkUpText a) -> MarkUpText a
		remove_first_space [CmText " ":commands]
			= commands
		remove_first_space [command: commands]
			= [command: remove_first_space commands]
		remove_first_space []
			= []
// BEZIG
showAProp display finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiBigIndentSkip, fiIndentImplies, fiIndentEqual, fiPrettyTypes} (AExprForall commands ptr p) heaps prj
	# next_is_quantor					= is_quantor p
	# next_is_implies					= is_implies p
	# indent_next						= fiIndentQuantors && (next_is_quantor || next_is_implies)
	# indent_now						= fiIndentQuantors && not next_is_quantor
	# finfo								= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
	# finfo								= {finfo & fiBigIndentSkip = fiBigIndentSkip || next_is_implies, fiNeedBrackets = False, fiPosition = Nothing}
	# (finfo, heaps)					= storeExprVar ptr finfo heaps
	# (error, fvar, heaps, prj)			= ShowExprVar finfo True ptr heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (var, heaps)						= readPointer ptr heaps
	# (finfo, fvar, heaps, prj)			= add_type finfo fvar fiPrettyTypes heaps prj
	# fquantor							= display.diaForall commands next_is_quantor fvar
	# (error, fprop, heaps, prj)		= showAProp display finfo p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# skip_spaces						= if fiBigIndentSkip 6 2
	| indent_now
		= (OK, fquantor ++ [CmNewline, CmSpaces skip_spaces, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
		= case fiPosition of
			Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
			Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
	where
		is_quantor (AExprForall _ _ _)	= True
		is_quantor (AExprExists _ _ _)	= True
		is_quantor (APropForall _ _ _)	= True
		is_quantor (APropExists _ _ _)	= True
		is_quantor _					= False
		
		is_implies (AImplies _ _ _)		= True
		is_implies _					= False
		
		add_type :: !FormatInfo !(MarkUpText WindowCommand) ![CTypeH] !*CHeaps !*CProject -> (!FormatInfo, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		add_type finfo fvar [type:types] heaps prj
			# (_, ftype, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} type heaps prj
			= ({finfo & fiPrettyTypes = types}, fvar ++ [CmText "::"] ++ ftype, heaps, prj)
		add_type finfo fvar [] heaps prj
			= (finfo, fvar, heaps, prj)
showAProp display finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual, fiPrettyTypes} (AExprExists commands ptr p) heaps prj
	# next_is_quantor					= is_quantor p
	# indent_next						= fiIndentQuantors && next_is_quantor
	# indent_now						= fiIndentQuantors && not next_is_quantor
	# finfo								= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
	# finfo								= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
	# (finfo, heaps)					= storeExprVar ptr finfo heaps
	# (error, fvar, heaps, prj)			= ShowExprVar finfo True ptr heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# (var, heaps)						= readPointer ptr heaps
	# (finfo, fvar, heaps, prj)			= add_type finfo fvar fiPrettyTypes heaps prj
	# fquantor							= display.diaExists commands next_is_quantor fvar
	# (error, fprop, heaps, prj)		= showAProp display finfo p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	| indent_now
		= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
		= case fiPosition of
			Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
			Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
	where
		is_quantor (AExprForall _ _ _)	= True
		is_quantor (AExprExists _ _ _)	= True
		is_quantor (APropForall _ _ _)	= True
		is_quantor (APropExists _ _ _)	= True
		is_quantor _					= False
		
		add_type :: !FormatInfo !(MarkUpText WindowCommand) ![CTypeH] !*CHeaps !*CProject -> (!FormatInfo, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		add_type finfo fvar [type:types] heaps prj
			# (_, ftype, heaps, prj)	= FormattedShow {finfo & fiNeedBrackets = True} type heaps prj
			= ({finfo & fiPrettyTypes = types}, fvar ++ [CmText "::"] ++ ftype, heaps, prj)
		add_type finfo fvar [] heaps prj
			= (finfo, fvar, heaps, prj)
showAProp display finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiBigIndentSkip, fiIndentImplies, fiIndentEqual} (APropForall commands ptr p) heaps prj
	# next_is_quantor					= is_quantor p
	# next_is_implies					= is_implies p
	# indent_next						= fiIndentQuantors && (next_is_quantor || next_is_implies)
	# indent_now						= fiIndentQuantors && not next_is_quantor
	# finfo								= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
	# finfo								= {finfo & fiBigIndentSkip = fiBigIndentSkip || next_is_implies, fiNeedBrackets = False, fiPosition = Nothing}
	# (finfo, heaps)					= storePropVar ptr finfo heaps
	# (fvar, heaps)						= ShowPropVar finfo True ptr heaps
	# fvar								= fvar ++ [CmText "::PROP"]
	# fquantor							= display.diaForall commands next_is_quantor fvar
	# (error, fprop, heaps, prj)		= showAProp display finfo p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# skip_spaces						= if fiBigIndentSkip 6 2
	| indent_now
		= (OK, fquantor ++ [CmNewline, CmSpaces skip_spaces, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
		= case fiPosition of
			Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
			Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
	where
		is_quantor (AExprForall _ _ _)	= True
		is_quantor (AExprExists _ _ _)	= True
		is_quantor (APropForall _ _ _)	= True
		is_quantor (APropExists _ _ _)	= True
		is_quantor _					= False
		
		is_implies (AImplies _ _ _)		= True
		is_implies _					= False
showAProp display finfo=:{fiNeedBrackets, fiPosition, fiIndentQuantors, fiIndentImplies, fiIndentEqual} (APropExists commands ptr p) heaps prj
	# next_is_quantor					= is_quantor p
	# indent_next						= fiIndentQuantors && next_is_quantor
	# indent_now						= fiIndentQuantors && not next_is_quantor
	# finfo								= {finfo & fiIndentQuantors = indent_next, fiIndentImplies = fiIndentQuantors && fiIndentImplies, fiIndentEqual = fiIndentQuantors && fiIndentEqual}
	# finfo								= {finfo & fiNeedBrackets = False, fiPosition = Nothing}
	# (finfo, heaps)					= storePropVar ptr finfo heaps
	# (fvar, heaps)						= ShowPropVar finfo True ptr heaps
	# fvar								= fvar ++ [CmText "::PROP"]
	# fquantor							= display.diaExists commands next_is_quantor fvar
	# (error, fprop, heaps, prj)		= showAProp display finfo p heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	| indent_now
		= (OK, fquantor ++ [CmNewline, CmSpaces 2, CmScope] ++ fprop ++ [CmEndScope], heaps, prj)
		= case fiPosition of
			Nothing		-> (OK, fquantor ++ fprop, heaps, prj)
			Just _		-> (OK, [CmText "("] ++ fquantor ++ fprop ++ [CmText ")"], heaps, prj)
	where
		is_quantor (AExprForall _ _ _)	= True
		is_quantor (AExprExists _ _ _)	= True
		is_quantor (APropForall _ _ _)	= True
		is_quantor (APropExists _ _ _)	= True
		is_quantor _					= False
showAProp display finfo (APredicate ptr exprs) heaps prj
	= FormattedShow finfo (CPredicate ptr exprs) heaps prj