definition module
	MarkUpText

import
	MdM_IOlib,
	StdString,
	StdInt,
	StdBool,
	StdControlClass,
	StdId,
	StdIOBasic,
	StdIOCommon,
	StdReceiver,
	StdWindowDef

:: MarkUpCommand a =
	  CmText				!String			
	| CmBText				!String				| CmIText				!String		| CmUText		!String
	| CmNewlineI			!Bool !Int !(Maybe Colour)
	| CmFillLine								| CmStartOfLine
	| CmScope									| CmEndScope
	| CmAlignI				!String !Colour
	| CmCenter									| CmBGCenter			!Colour
	| CmRight									| CmBGRight				!Colour
	| CmHorSpace			!Int				| CmSpaces				!Int
	| CmBold									| CmEndBold
	| CmItalic									| CmEndItalic
	| CmUnderline								| CmEndUnderline
	| CmSize				!Int				| CmChangeSize			!Int		| CmEndSize
	| CmColour				!Colour				| CmEndColour
	| CmBackgroundColour	!Colour				| CmEndBackgroundColour
	| CmFont				!FontDef			| CmEndFont
	| CmFontFace			!String				| CmEndFontFace
	| CmLink				!String a			| CmLink2				!Int !String !a
	| CmId					!a					| CmTextId				!String		| CmEndId
	| CmLabel				!String !Bool

	| Cm_Word				!String !Font !FontMetrics !Int !Colour !Colour
	| Cm_Link				!String a !FontMetrics !Int (!Font, !Colour, !Colour) (!Font, !Colour, !Colour)
	| Cm_HorSpace			!Int !Colour									
CmAlign t  :== CmAlignI t Black
CmTabSpace :== CmSpaces 4
CmNewline  :== CmNewlineI False 0 Nothing

:: ButtonId		:== !(!Id, !RId (MarkUpMessage Bool), !RId Bool)
:: MarkUpText a	:== [MarkUpCommand a]

:: MarkUpAttribute a ps =
	  MarkUpWidth				!Int
	| MarkUpMaxWidth			!Int
	| MarkUpHeight				!Int
	| MarkUpMaxHeight			!Int
	| MarkUpHScroll
	| MarkUpVScroll
	| MarkUpTextColour			!Colour
	| MarkUpTextSize			!Int
	| MarkUpBackgroundColour	!Colour
	| MarkUpFont				!FontDef
	| MarkUpFontFace			!String
	| MarkUpFixMetrics			!FontDef
	| MarkUpLinkStyle			!Bool !Colour !Colour !Bool !Colour !Colour
	| MarkUpSpecialClick		!(ps -> ps) !(ps -> ps)
	| MarkUpEventHandler		!((MarkUpEvent a) -> ps -> ps)
	| MarkUpNrLinesI			!Int !Int
	| MarkUpIgnoreMultipleSpaces
	| MarkUpReceiver			!(RId (MarkUpMessage a))
	| MarkUpInWindow			!Id
	| MarkUpOverrideKeyboard	!(KeyboardState -> ps -> ps)
MarkUpNrLines nr_lines :== MarkUpNrLinesI nr_lines 0

:: MarkUpEvent a =
	{ meSelectEvent				:: !Bool
	, meClickEvent				:: !Bool
	, meNrClicks				:: !Int
	, meLink					:: !a
	, meLinkIndex				:: !Maybe Int
	, meOwnRId					:: !(RId (MarkUpMessage a))
	, meModifiers				:: !Maybe Modifiers
	}

:: ResizeType =
	  DoNotResize
	| ResizeHor
	| ResizeVer
	| ResizeHorVer

MarkUpControl			:: ![MarkUpCommand a] ![MarkUpAttribute a .ps] ![ControlAttribute *(MarkUpLocalState a .ps, .ps)] -> MarkUpState a .ls .ps
MarkUpWindow			:: !String ![MarkUpCommand a] ![MarkUpAttribute a (*PSt .ps)] ![WindowAttribute *(MarkUpLocalState a (*PSt .ps), *PSt .ps)] !*(PSt .ps) -> *PSt .ps
instance Controls (MarkUpState a)

openButtonId			:: !*env -> (!ButtonId, !*env) | Ids env
openButtonIds			:: !Int !*env -> (![ButtonId], !*env) | Ids env
enableButton			:: !ButtonId !*(PSt .ls) -> *PSt .ls
enableButtons			:: ![ButtonId] !*(PSt .ls) -> *PSt .ls
deactiveMarkUp			:: !(RId (MarkUpMessage a)) !*(PSt .ps) -> *PSt .ps
disableButton			:: !ButtonId !*(PSt .ls) -> *PSt .ls
disableButtons			:: ![ButtonId] !*(PSt .ls) -> *PSt .ls
changeButtonText		:: !ButtonId !String !*(PSt .ls) -> *PSt .ls
MarkUpButton			:: !String !Colour !((*PSt .pstate) -> *PSt .pstate) !ButtonId ![ControlAttribute *(.lstate,*PSt .pstate)] -> CompoundControl (:+: (Receiver Bool) (MarkUpState Bool)) .lstate *(PSt .pstate)

changeMarkUpText		:: !(RId !(MarkUpMessage a)) !(MarkUpText a) !(*PSt .ps) -> !*PSt .ps
changeMarkUpDraw		:: !(RId !(MarkUpMessage a)) !Bool !((SmartId a) -> (SmartDrawArea a) -> (Bool, SmartDrawArea a)) !(*PSt .ps) -> !*PSt .ps
jumpToMarkUpLabel		:: !(RId !(MarkUpMessage a)) !String !(*PSt .ps) -> !*PSt .ps
redrawMarkUpSliders		:: !(RId !(MarkUpMessage a)) !(*PSt .ps) -> !*PSt .ps
triggerMarkUpLink		:: !(RId !(MarkUpMessage a)) !a !(*PSt .ps) -> !*PSt .ps
scrollMarkUpToBottom	:: !(RId !(MarkUpMessage a)) !*(PSt .ps) -> !*PSt .ps

toText					:: !(MarkUpText a) -> !String
changeCmLink			:: (a -> b) !(MarkUpText a) -> !MarkUpText b
removeCmLink			:: !(MarkUpText a) -> !MarkUpText b

clickHandler			:: (.command -> .state -> .state) (MarkUpEvent .command) .state -> .state
sendHandler				:: !(RId command) (MarkUpEvent command) !*(PSt .state) -> *PSt .state

rectifyDialog			:: !(MarkUpText Bool) !*(PSt .a) -> (!Bool, !*PSt .a)
boxedMarkUp				:: .Colour .ResizeType [.(MarkUpCommand a)] [.(MarkUpAttribute a *(PSt .b))] [.(ControlAttribute *(.c,*(PSt .b)))] -> .(CompoundControl (MarkUpState a) .c *(PSt .b))
titledMarkUp			:: !Colour !Colour !ResizeType !(MarkUpText a) !(MarkUpText b) ![MarkUpAttribute b .c] ![ControlAttribute *(.d,.c)] -> CompoundControl (:+: (MarkUpState a) (:+: CustomControl (MarkUpState b))) .d .c

































:: MarkUpMessage a =
	  MarkUpChangeText			!(MarkUpText a)
	| MarkUpChangeDraw			!Bool !((SmartId a) -> (SmartDrawArea a) -> (Bool, SmartDrawArea a))
	| MarkUpDeactivate
	| MarkUpDrawAtLabel			!String (*Picture -> *Picture)
	| MarkUpJumpTo				!String
	| MarkUpResetSliders
	| MarkUpTrigger				!a
	| MarkUpScrollLeftBottom

:: MarkUpState a ls ps =
	{ musCommands				:: ![MarkUpCommand a]
	, musCustomAttributes		:: ![MarkUpAttribute a ps]
	, musControlAttributes		:: ![ControlAttribute *(MarkUpLocalState a ps, ps)]
	, musWindowAttributes		:: ![WindowAttribute *(MarkUpLocalState a ps, ps)]
	, musIsControl				:: !Bool
	}

:: MarkUpLocalState a ps =
	{ mulIsControl					:: !Bool
	, mulId							:: !Id					// always generated
	, mulOuterId					:: !Id
	, mulScrollIds					:: !(!Id, !Id)			// always generated; not always used
	, mulReceiverId					:: !(RId (MarkUpMessage a))
	, mulCommands					:: ![MarkUpCommand a]
	, mulViewDomain					:: !ViewDomain
	, mulScroll						:: !(!Bool, !Bool)		// (needs horizontal scrollbar, needs vertical scrollbar)
	, mulResize						:: Size -> Size -> Size -> Size
	, mulViewSize					:: !Size
	, mulKeyboard					:: !KeyboardState -> ps -> ps
	, mulDrawFunctions				:: ![SmartDrawArea a]
	, mulHighlightDrawFunctions		:: ![(a, SmartDrawArea a)]
	, mulActiveLink					:: !Int
	, mulWidth						:: !Int
	, mulMaxWidth					:: !Int
	, mulHeight						:: !Int
	, mulMaxHeight					:: !Int
	, mulIgnoreMultipleSpaces		:: !Bool
	, mulFixedMetrics				:: !Maybe FontMetrics
	, mulNrLines					:: !(!Int, !Int)
	, mulLinkStyles					:: [(!Bool, !Colour, !Colour, !Bool, !Colour, !Colour)]
	, mulSpecialClick				:: !Maybe ((ps->ps),(ps->ps))
	, mulInitialColour				:: !Colour
	, mulInitialFontDef				:: !FontDef
	, mulInitialBackgroundColour	:: !Colour
	, mulPreviousMouseMove			:: !Point2				// ignore duplicate move commands (generated by Object I/O)
	, mulEventHandler				:: ((MarkUpEvent a) -> ps -> ps)
	, mulBaselines					:: ![Int]				// for each line: fAscent + fDescent of largest font
	, mulSkips						:: ![Int]				// for each line: fLeading of largest font
	, mulScopes						:: ![Scope]
	, mulLabels						:: ![(String, Int, Int)]
	}

:: Scope