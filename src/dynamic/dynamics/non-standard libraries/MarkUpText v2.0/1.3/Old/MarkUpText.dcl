definition module
	MarkUpText

import
	StdString,
	StdInt,
	StdBool,
	StdIOBasic,
	StdIOCommon,
	StdControlClass,
	StdWindowDef

:: MarkUpCommand a =
	  CmText				!String			
	| CmBText				!String				| CmIText				!String		| CmUText		!String
	| CmNewline									| CmFillLine						| CmStartOfLine
	| CmScope									| CmEndScope
	| CmAlign				!String
	| CmCenter									| CmBGCenter			!Colour
	| CmRight									| CmBGRight				!Colour
	| CmHorSpace			!Int				| CmTabSpace
	| CmBold									| CmEndBold
	| CmItalic									| CmEndItalic
	| CmUnderline								| CmEndUnderline
	| CmSize				!Int				| CmChangeSize			!Int		| CmEndSize
	| CmColour				!Colour				| CmEndColour
	| CmBackgroundColour	!Colour				| CmEndBackgroundColour
	| CmFont				!FontDef			| CmEndFont
	| CmFontFace			!String				| CmEndFontFace
	| CmLink				!String a
	| CmLabel				!String

	| Cm_Word				!String !Font !FontMetrics !Int !Colour !Colour
	| Cm_Link				!String a !FontMetrics !Int (!Font, !Colour, !Colour) (!Font, !Colour, !Colour)
	| Cm_HorSpace			!Int !Colour									

:: MarkUpText a :== [MarkUpCommand a]

:: MarkUpAttribute a ps =
	  MarkUpWidth				!Int
	| MarkUpMaxWidth			!Int
	| MarkUpHeight				!Int
	| MarkUpMaxHeight			!Int
	| MarkUpTextColour			!Colour
	| MarkUpTextSize			!Int
	| MarkUpBackgroundColour	!Colour
	| MarkUpFont				!FontDef
	| MarkUpFontFace			!String
	| MarkUpLinkStyle			!Bool !Colour !Colour !Bool !Colour !Colour
	| MarkUpEventHandler		((!MarkUpEvent a) -> Id -> (RId (MarkUpMessage a)) -> ps -> ps)
	| MarkUpNrLines				!Int
	| MarkUpIgnoreMultipleSpaces
	| MarkUpReceiver			(!RId (MarkUpMessage a))
	| MarkUpInWindow			!Id

:: MarkUpEvent a =
	  MarkUpLinkSelected		a
	| MarkUpLinkClicked			!Int a

MarkUpControl :: [!MarkUpCommand a] [!MarkUpAttribute a .ps] [!ControlAttribute *(MarkUpLocalState a .ps, .ps)] -> !MarkUpState a .ls .ps
MarkUpWindow :: !String [!MarkUpCommand a] [!MarkUpAttribute a (*PSt .ps)] [!WindowAttribute *(MarkUpLocalState a (*PSt .ps), *PSt .ps)] (*PSt .ps) -> *PSt .ps
instance Controls (MarkUpState a)

changeMarkUpText		:: !(RId !(MarkUpMessage a)) !(MarkUpText a) !(*PSt .ps) -> !*PSt .ps
jumpToMarkUpLabel		:: !(RId !(MarkUpMessage a)) !String !(*PSt .ps) -> !*PSt .ps

toText :: !(MarkUpText a) -> !String



































:: MarkUpMessage a =
	  MarkUpChangeText			!(MarkUpText a)
	| MarkUpJumpTo				!String

:: MarkUpState a ls ps =
	{ musCommands				:: [!MarkUpCommand a]
	, musCustomAttributes		:: [!MarkUpAttribute a ps]
	, musControlAttributes		:: [!ControlAttribute *(MarkUpLocalState a ps, ps)]
	, musWindowAttributes		:: [!WindowAttribute *(MarkUpLocalState a ps, ps)]
	, musIsControl				:: !Bool
	}

:: MarkUpLocalState a ps =
	{ mulIsControl					:: !Bool
	, mulId							:: !Id
//	, mulWindowId					:: Id					// lazy -- sometimes gets an abort 
	, mulReceiverId					:: (!RId (MarkUpMessage a))
	, mulCommands					:: [!MarkUpCommand a]
	, mulViewDomain					:: !ViewDomain
	, mulViewSize					:: !Size
	, mulDrawFunctions				:: [(!Rectangle, *Picture -> *Picture)]
	, mulHighlightDrawFunctions		:: [(!Rectangle, !Int, a, *Picture -> *Picture)]
	, mulActiveLink					:: !Int
	, mulWidth						:: !Int
	, mulMaxWidth					:: !Int
	, mulHeight						:: !Int
	, mulMaxHeight					:: !Int
	, mulIgnoreMultipleSpaces		:: !Bool
	, mulNrLines					:: !Int
	, mulNormalLink					:: (!Bool, !Colour, !Colour)
	, mulSelectedLink				:: (!Bool, !Colour, !Colour)
	, mulInitialColour				:: !Colour
	, mulInitialFontDef				:: !FontDef
	, mulInitialBackgroundColour	:: !Colour
	, mulEventHandler				:: ((!MarkUpEvent a) -> Id -> (RId (MarkUpMessage a)) -> ps -> ps)
	, mulBaselines					:: [!Int]				// for each line: fAscent + fDescent of largest font
	, mulSkips						:: [!Int]				// for each line: fLeading of largest font
	, mulScopes						:: [!Scope]
	, mulLabels						:: [(!String, !Int, !Int)]
	}

:: Scope