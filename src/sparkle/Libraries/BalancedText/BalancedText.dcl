definition module
	BalancedText

import
	StdInt,
	StdString,
	StdPictureDef,
	StdControlClass,
	StdWindowDef

:: BalancedTextAttribute =
	  BalancedTextColour			!Colour
	| BalancedTextBackgroundColour	!Colour
	| BalancedTextFont				!FontDef
	| BalancedTextFontSize			!Int
	| BalancedTextFontStyle			![String]
	| BalancedTextFontFace			!String

BalancedTextControl ::         !String !Int       ![BalancedTextAttribute] ![ControlAttribute *(.ls, .ps)]                -> BalancedTextState .ls .ps
BalancedTextWindow  :: !String !String !Int !Size ![BalancedTextAttribute] ![WindowAttribute *(Int, *PSt .ps)] !*(PSt .ps) -> *PSt .ps

instance Controls BalancedTextState





























// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
:: BalancedTextState ls ps =
// ---------------------------------------------------------------------------------------------------------------------------------------------------------------------
	{ batText					:: !String
	, batWidth					:: !Int
	, batCustomAttributes		:: ![BalancedTextAttribute]
	, batControlAttributes		:: ![ControlAttribute *(ls, ps)]
	}