/*
** Program: Clean Prover System
** Module:  FormattedShow (.dcl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

definition module 
	FormattedShow

import 
	StdEnv,
	MarkUpText,
	CoreTypes,
	CoreAccess,
	Operate,
	Heaps,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
LogicColour		:== RGB {r=  0, g=150, b= 75}				// fg; quantors + logical connectives
LogicDarkColour	:== RGB {r=  0, g=100, b= 25}
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
toColour :: !Int !ExtendedColour -> Colour

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
instance == ExtendedColour

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

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: IShowMode
// -------------------------------------------------------------------------------------------------------------------------------------------------
	= INoBreak
	| IBreak
	| IBreak_AfterQuantor

changeColour		:: !Int !Colour -> Colour

storeExprVar		:: !CExprVarPtr !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
storeExprVars		:: ![CExprVarPtr] !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
storePropVar		:: !CPropVarPtr !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)
storePropVars		:: ![CPropVarPtr] !FormatInfo !*CHeaps -> (!FormatInfo, !*CHeaps)

ShowExprVar			:: !FormatInfo !Bool !CExprVarPtr !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
ShowPropVar			:: !FormatInfo !Bool !CPropVarPtr !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)

class FormattedShow cdef :: !FormatInfo !cdef !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)

instance FormattedShow (CAlgPattern HeapPtr)
instance FormattedShow (CAlgTypeDef HeapPtr)
instance FormattedShow (CBasicPattern HeapPtr)
instance FormattedShow CBasicType
instance FormattedShow (CBasicValue HeapPtr)
instance FormattedShow (CCasePatterns HeapPtr)
instance FormattedShow (CClassDef HeapPtr)
instance FormattedShow (CClassRestriction HeapPtr)
instance FormattedShow (CDataConsDef HeapPtr)
instance FormattedShow (CExpr HeapPtr)
instance FormattedShow (CFunDef HeapPtr)
instance FormattedShow CInfix 
instance FormattedShow (CInstanceDef HeapPtr)
instance FormattedShow (CMemberDef HeapPtr)
instance FormattedShow (CProp HeapPtr)
instance FormattedShow (CRecordFieldDef HeapPtr)
instance FormattedShow (CRecordTypeDef HeapPtr)
instance FormattedShow (CSymbolType HeapPtr)
instance FormattedShow (CType HeapPtr)
instance FormattedShow TacticId

formattedShow :: !HeapPtr !FormatInfo !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)








:: Icon =
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

:: IconInfo item a =
	{ iiIcon				:: !Icon
	, iiLinkStyle			:: !Int
	, iiCommand				:: !(Ptr item) -> a
	}

IconSymbol			:: !Icon -> (!CName, !Int)
showIconList		:: ![Ptr item] ![IconInfo item a] !((Ptr item) -> item -> MarkUpText a) ![IconInfo item a] !*CHeaps -> (!MarkUpText a, !*CHeaps) | Pointer item
showIconList1		:: ![Ptr item] ![IconInfo item a] !((Ptr item) -> item -> MarkUpText a) ![IconInfo item a] !Colour !*CHeaps -> (!MarkUpText a, !*CHeaps) | Pointer item
