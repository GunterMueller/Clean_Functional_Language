implementation module osfont

import	StdInt, StdBool, StdChar, StdReal, StdArray, StdString, StdTuple
import	pointer, print, fonts, menus, quickdraw
import	ostoolbox, ostypes
from commondef import error, :: St
from osmenu import :: OSMenu
//import	commondef

::	Font =
	{ fontdef	:: !OSFontDef	// The font requested by the program
	, fontimp	:: !OSFont		// The font selected by the system
	}

::	OSFontDef
	:==	(	!String			// Name of the font
		,	![String]		// Stylistic variations
		,	!Int			// Size in points
		)
::	FontAtts
	:==	(	!Int			// font family ID
		,	!String			// font family name
		,	![String]		// style attributes
		,	!Int			// size
		,	!Bool			// flag: True iff requested size is available
		)
::	FontMetrics`
	=	{	fAscent`		:: !Int			// Distance between top    and base line
		,	fDescent`		:: !Int			// Distance between bottom and base line
		,	fLeading`		:: !Int			// Distance between two text lines
		,	fMaxWidth`		:: !Int			// Max character width including spacing
		}

GrafPtrtxFont	:== 68
GrafPtrtxFace	:== 70
GrafPtrtxSize	:== 74
/*
AppFontID		:==	2436	// $984: Word containing application font ID
SysFontFam		:==	2982	// $BA6: Word containing system font ID
SysFontSize		:==	2984	// $BA8: Word containing system font point size
*/
::	OSFont
	=	{	osfontname	:: !String	// Name of the font
		,	osfontstyles:: ![String]// Style variations of the font
		,	osfontsize	:: !Int		// Point size of the font
		,	osfontnumber:: !Int		// Id of the font
		,	osfontexists:: !Bool
		}

//	PA: added
/* DvA: removed on mac version...
instance == OSFont where
	(==) :: !OSFont !OSFont -> Bool
	(==) f1 f2 = f1.osfontsize   == f2.osfontsize   && 
	             f1.osfontstyles == f2.osfontstyles && 
	             f1.osfontname   == f2.osfontname   &&
	             f1.osfontnumber == f2.osfontnumber &&
	             f1.osfontexists == f2.osfontexists
*/
//	Font constants:
osSerifFontDef			:: OSFontDef;	osSerifFontDef			= ("Times",      [],10)
osSansSerifFontDef		:: OSFontDef;	osSansSerifFontDef		= ("Arial",      [],10)
osSmallFontDef			:: OSFontDef;	osSmallFontDef			= ("Small Fonts",[],7 )
osNonProportionalFontDef:: OSFontDef;	osNonProportionalFontDef= ("Courier",    [],10)
osSymbolFontDef			:: OSFontDef;	osSymbolFontDef			= ("Symbol",     [],10)


//	Conversion of Font into FontAtts and vice versa.

//OSfontgetimp :: !Font -> FontAtts
osFontgetimp		:: !Font -> OSFont
osFontgetimp {fontimp}
	= fontimp

osFontgetdef		:: !Font -> OSFontDef
osFontgetdef {fontdef}
	= fontdef

osSelectfont :: !OSFontDef !*OSToolbox -> (!Bool,!Font,!*OSToolbox)
osSelectfont def=:(fName,fStyles,fSize) tb
	# (fontNr,tb)				= GetFNum fName tb
	| fontNr<>0
		# (exists,tb)			= RealFont fontNr fSize tb
		# imp = {osfontnumber=fontNr,osfontname=fName,osfontstyles=fStyles,osfontsize=fSize,osfontexists=exists}
		= (exists,{fontdef=def,fontimp=imp}, tb)
	# (dFontName,tb)			= GetFontName 0 String256 tb
	  fontExists				= dFontName==fName
	  fontselector				= if fontExists osDialogfont osDefaultfont
	  (dFont,tb)				= fontselector tb
	= (fontExists, dFont,tb)

osDefaultfont :: !*OSToolbox -> (!Font,	!*OSToolbox)
osDefaultfont tb
	# (fontID,tb)	= LMGetApFontID tb
	  (fontSize,tb)	= LMGetSysFontSize tb
	  (fName,tb)	= GetFontName fontID String256 tb
	  styles		= []
	  fontSize		= if (fontSize==0) 12 fontSize
	  (exists,tb)	= RealFont fontID fontSize tb
	  def			= (fName,styles,fontSize)
	  imp		=	{ osfontnumber	= fontID
	  				, osfontname	= fName
	  				, osfontstyles	= styles
	  				, osfontsize	= fontSize
	  				, osfontexists	= exists
	  				}
	= ({fontdef=def,fontimp=imp},tb)

osDialogfont :: !*OSToolbox -> (!Font,	!*OSToolbox)
osDialogfont tb
	# (fontID,tb)	= LMGetSysFontFam tb
	  (fontSize,tb)	= LMGetSysFontSize tb
	  (fName,tb)	= GetFontName fontID String256 tb
	  styles		= []
	  fontSize		= if (fontSize==0) 12 fontSize
	  (exists,tb)	= RealFont fontID fontSize tb
	  def			= (fName,styles,fontSize)
	  imp			= {osfontnumber=fontID,osfontname=fName,osfontstyles=styles,osfontsize=fontSize,osfontexists=exists}
	= ({fontdef=def,fontimp=imp},tb)

osFontnames :: !*OSToolbox -> (![String],!*OSToolbox)
osFontnames tb
	# (mH,tb)		= NewMenu 1 "Fonts" tb
	  tb			= AddResMenu  mH fontType tb
	  (nrFonts,tb)	= CountMenuItems mH tb
	  (fNames, tb)	= getFontNames 1 nrFonts mH tb
	  tb			= DisposeMenu mH tb
	= (fNames,tb)
where
	s1				= toInt 'F'
	s2				= toInt 'O' + s1<<8
	s3				= toInt 'N' + s2<<8
	s4				= toInt 'T' + s3<<8
	fontType		= s4
	
	getFontNames :: !Int !Int !OSMenu !*OSToolbox -> ([String],!*OSToolbox)
	getFontNames i maxFontNr mH tb
		| i>maxFontNr
		= ([],tb)
		# (fName, tb) = GetItem mH i String256 tb
		  (fNames,tb) = getFontNames (i+1) maxFontNr mH tb
		= ([fName:fNames],tb)

osFontstyles :: !String !*OSToolbox -> (![String],!*OSToolbox)
osFontstyles name tb
	= (	[	"Bold"
		,	"Italic"
		,	"Underline"
		,	"Outline"
		,	"Shadow"
		,	"Condense"
		,	"Extend"
		]
	  ,	tb
	  )

osFontsizes :: !Int !Int !String !*OSToolbox -> (![Int],!*OSToolbox)
osFontsizes sizeBound1 sizeBound2 name tb
	# (fontNr,tb)			= GetFNum name  tb
	| fontNr<>0
		= fontsizes` fontNr minfontsize maxfontsize tb
	# ({fontimp={osfontnumber=fontNr}},tb)	= osDefaultfont tb
	= fontsizes` fontNr minfontsize maxfontsize tb
where
	(minfontsize,maxfontsize)
						= minmax (max 0 sizeBound1) (max 0 sizeBound2)
	
	fontsizes` :: !Int !Int !Int !*OSToolbox -> (![Int],!*OSToolbox)
	fontsizes` fontNr l u tb
		| l>u				= ([],tb)
		# (exists,tb)		= RealFont fontNr l tb
		  (sizes, tb)		= fontsizes` fontNr (l+1) u tb
		| exists
		= ([l:sizes],tb)
		= (sizes,tb)
	
	minmax :: !Int !Int -> (!Int,!Int)
	minmax x y
		| x<y
		= (x,y)
		= (y,x)

osGetfontcharwidths	:: !Bool !OSPictContext ![Char] !Font	!*OSToolbox -> (![Int],!*OSToolbox)
osGetfontcharwidths _ _ chars {fontimp=fontimp=:{osfontexists=exists}} tb
	| exists
	= accessfonttoolbox (getcharwidths chars) fontimp tb
	with
		getcharwidths :: ![Char] !*OSToolbox -> (![Int],!*OSToolbox)
		getcharwidths [c:cs] tb
//			# (cWidth, tb) = QStringWidth (toString c) tb
			# (cWidth, tb) = QCharWidth c tb
			  (cWidths,tb) = getcharwidths cs tb
			= ([cWidth:cWidths],tb)
		getcharwidths _ tb
			= ([],tb)
	= accessfonttoolbox (measurecharwidths chars) fontimp tb
	with
		measurecharwidths :: ![Char] !*OSToolbox -> (![Int],!*OSToolbox)
		measurecharwidths chars tb
			# (ascent,descent,maxWidth,leading,tb)	= QGetFontInfo tb
			  info									= (ascent,descent,maxWidth,leading)
			= getcharwidths chars info tb
		where
			getcharwidths :: ![Char] !(!Int,!Int,!Int,!Int) !*OSToolbox -> (![Int],!*OSToolbox)
			getcharwidths [c:cs] info tb
				# (width,(numerh,_),(denomh,_),_,tb)= QStdTxMeas 1 (toString c) (1,1) (1,1) info tb
				  (cWidths,tb)						= getcharwidths cs info tb
				= ([fontscalenumerdenom width numerh denomh:cWidths],tb)
			getcharwidths _ _ tb
				= ([],tb)

osGetfontstringwidth :: !Bool !OSPictContext !String !Font !*OSToolbox -> (!Int,!*OSToolbox)
osGetfontstringwidth _ _ string {fontimp=fontimp=:{osfontexists=exists}} tb
	| exists
	= accessfonttoolbox (QStringWidth string) fontimp tb
	= accessfonttoolbox (QStdTxMeasWidth string) fontimp tb
	with
		QStdTxMeasWidth :: !String !*OSToolbox -> (!Int,!*OSToolbox)
		QStdTxMeasWidth string tb
			# (ascent,descent,maxWidth,leading,tb)	= QGetFontInfo tb
			  info									= (ascent,descent,maxWidth,leading)
			  (width,(numerh,_),(denomh,_),_,tb)	= QStdTxMeas (size string) string (1,1) (1,1) info tb
			= (fontscalenumerdenom width numerh denomh,tb)

//OSgetfontstringwidths :: ![String] !FontAtts !*OSToolbox -> (![Int],!*OSToolbox)
osGetfontstringwidths	:: !Bool !OSPictContext ![String] !Font	!*OSToolbox -> (![Int],!*OSToolbox)
osGetfontstringwidths _ _ strings {fontimp=fontimp=:{osfontexists=exists}} tb
	| exists
	= accessfonttoolbox (getstringwidths strings) fontimp tb
	with
		getstringwidths :: ![String] !*OSToolbox -> (![Int],!*OSToolbox)
		getstringwidths [t:ts] tb
			# (tWidth, tb) = QStringWidth t tb
			  (tWidths,tb) = getstringwidths ts tb
			= ([tWidth:tWidths],tb)
		getstringwidths _ tb
			= ([],tb)
	= accessfonttoolbox (measurestringwidths strings) fontimp tb
	with
		measurestringwidths :: ![String] !*OSToolbox -> (![Int],!*OSToolbox)
		measurestringwidths strings tb
			# (ascent,descent,maxWidth,leading,tb)	= QGetFontInfo tb
			  info									= (ascent,descent,maxWidth,leading)
			= getstringwidths strings info tb
		where
			getstringwidths :: ![String] !(!Int,!Int,!Int,!Int) !*OSToolbox -> (![Int],!*OSToolbox)
			getstringwidths [t:ts] info tb
				# (width,(numerh,_),(denomh,_),_,tb)	= QStdTxMeas (size t) t (1,1) (1,1) info tb
				  (tWidths,tb)							= getstringwidths ts info tb
				= ([fontscalenumerdenom width numerh denomh:tWidths],tb)
			getstringwidths _ _ tb
				= ([],tb)

/* getfontmetrics changed by MW for printing */
osGetfontmetrics :: !Bool !OSPictContext !Font !*OSToolbox -> (!(!Int,!Int,!Int,!Int), !*OSToolbox)
osGetfontmetrics _ _ {fontimp=fontimp=:{osfontnumber=fontNr,osfontsize=fSize,osfontexists=exists}} tb
    # (isPrinting,tb) = isPrinting tb
	| isPrinting<>0
		# (exists,tb)		= RealFont fontNr fSize tb
		| exists
			= accessfonttoolbox getmetrics fontimp tb
		= accessfonttoolbox QStdTextMeasInfo fontimp tb
	| exists
		= accessfonttoolbox getmetrics fontimp tb
	= accessfonttoolbox QStdTextMeasInfo fontimp tb
	where
		QStdTextMeasInfo :: !*OSToolbox -> (!(!Int,!Int,!Int,!Int),!*OSToolbox)
		QStdTextMeasInfo tb
			# (ascent,descent,maxWidth,leading,tb)			= QGetFontInfo tb
			  info											= (ascent,descent,maxWidth,leading)
			  (_,(numerh,numerv),(denomh,denomv),info,tb)	= QStdTxMeas 1 "m" (72,72)
			  															 (adjustToPrinterRes 72,adjustToPrinterRes 72)
			  															 info tb
			  // "AdjustToPrinterRes 72" by MW. 72 was choosen, because no rounding errors will occur then
			  (ascent,descent,maxWidth,leading)				= info
			  ascent										= fontscalenumerdenom ascent   numerv denomv
			  descent										= fontscalenumerdenom descent  numerv denomv
			  leading										= fontscalenumerdenom leading  numerv denomv
			  maxWidth										= fontscalenumerdenom maxWidth numerh denomh
			= ((ascent,descent,leading,maxWidth),tb)
		getmetrics :: !*OSToolbox -> (!(!Int,!Int,!Int,!Int),!*OSToolbox)
		getmetrics tb
			# (ascent,descent,maxWidth,leading,tb)	= QGetFontInfo tb
			= ((ascent,descent,leading,maxWidth),tb)

/*	The previous version (MW):
getfontmetrics :: !FontAtts !*OSToolbox -> (!FontMetrics,!*OSToolbox)
getfontmetrics font=:(_,_,_,_,exists) tb
	| exists
	= accessfonttoolbox getmetrics font tb
	with
		getmetrics :: !*OSToolbox -> (!FontMetrics,!*OSToolbox)
		getmetrics tb
			# (ascent,descent,maxWidth,leading,tb)	= QGetFontInfo tb
			= ({fAscent=ascent,fDescent=descent,fLeading=leading,fMaxWidth=maxWidth},tb)
	= accessfonttoolbox QStdTextMeasInfo font tb
	with
		QStdTextMeasInfo :: !*OSToolbox -> (!FontMetrics,!*OSToolbox)
		QStdTextMeasInfo tb
			# (ascent,descent,maxWidth,leading,tb)			= QGetFontInfo tb
			  info											= (ascent,descent,maxWidth,leading)
			  (_,(numerh,numerv),(denomh,denomv),info,tb)	= QStdTxMeas 1 "m" (1,1) (1,1) info tb
			  (ascent,descent,maxWidth,leading)				= info
			  ascent										= fontscalenumerdenom ascent   numerv denomv
			  descent										= fontscalenumerdenom descent  numerv denomv
			  leading										= fontscalenumerdenom leading  numerv denomv
			  maxWidth										= fontscalenumerdenom maxWidth numerh denomh
			= ({fAscent=ascent,fDescent=descent,fLeading=leading,fMaxWidth=maxWidth},tb)
*/

fontscalenumerdenom :: !Int !Int !Int -> Int
fontscalenumerdenom x numer denom
	| numer==denom
	= x
	| x_fract+0.5==x_real
	= x_int+1			// for x::Int, if x is odd: toInt (x+0.5)==x+1; if x is even: toInt (x+0.5)==x.
	= x_int
where
	x_real	= (toReal (x*numer))/toReal denom
	x_int	= toInt x_real
	x_fract	= toReal x_int


// MW: This function will only be called with a screen grafport, not with a printer
// grafport. This function is only used to store the font size
// (in screen points) temporarily, and immediately restore that size in the picture.
// This function is only called from "openDrawing" (module windowdraw) and
// "accessfonttoolbox" (this module). Conclusion: With this function, no wrong
// printer fontsizes will reach the application program. I don't have to change it. 

GrafPtrGetFont :: !GrafPtr !*OSToolbox -> (!(!Int,!Int,!Int),!*OSToolbox)
GrafPtrGetFont gPtr tb
	# (nr,tb)		= GetPortTextFont gPtr tb
	  (style,tb)	= GetPortTextFace gPtr tb
	  (size,tb)		= GetPortTextSize gPtr tb
	= ((nr,style>>8,size), tb)

GrafPtrSetFont :: !(!Int,!Int,!Int) !*OSToolbox -> *OSToolbox
GrafPtrSetFont (nr,style,size) tb
	# tb			= QTextFont nr		tb
	  tb			= QTextFace style	tb
	  tb			= QTextSizePrinter size	tb	// MW: "Printer"
	= tb
/*
GrafPtrGetFont :: !GrafPtr !*OSToolbox -> (!(!Int,!Int,!Int),!*OSToolbox)
GrafPtrGetFont gPtr tb
	# (nr,tb)		= LoadWord (gPtr+GrafPtrtxFont) tb
	  (style,tb)	= LoadWord (gPtr+GrafPtrtxFace) tb
	  (size,tb)		= LoadWord (gPtr+GrafPtrtxSize) tb
	= ((nr,style>>8,size), tb)

GrafPtrSetFont :: !(!Int,!Int,!Int) !*OSToolbox -> *OSToolbox
GrafPtrSetFont (nr,style,size) tb
	# tb			= QTextFont nr		tb
	  tb			= QTextFace style	tb
	  tb			= QTextSizePrinter size	tb	// MW: "Printer"
	= tb
*/
// MW: if the current grafport is a printer grafport, then the size of the font
// will be adjusted. All functions, that set a font in a picture use this function.

accessfonttoolbox :: !(St *OSToolbox .x) !OSFont !*OSToolbox -> (!.x,!*OSToolbox)
accessfonttoolbox f {osfontnumber=nr,osfontstyles=style,osfontsize=size} tb
	# (gPtr,tb)		= QGetPort tb
	  (cFont,tb)	= GrafPtrGetFont gPtr tb
	  tb			= GrafPtrSetFont (nr,fontstylestoid style,size) tb
	  (x,tb)		= f tb
	  tb			= GrafPtrSetFont cFont tb
	= (x,tb)


fontstylestoid :: ![String] -> Int
fontstylestoid [style:styles]
	= styleid+(fontstylestoid styles)
where
	styleid	= case style of
				"Bold"		-> Bold
				"Italic"	-> Italic
				"Underline"	-> Underline
				"Outline"	-> Outline
				"Shadow"	-> Shadow
				"Condense"	-> Condense
				"Extend"	-> Extend
				_			-> 0
fontstylestoid _ = 0

idtofontstyles :: !Int -> [String]
idtofontstyles styleword
	= idtofontstyles` styleword [Bold,Italic,Underline,Outline,Shadow,Condense,Extend]
where
	idtofontstyles` :: !Int ![Int] -> [String]
	idtofontstyles` 0 _
		= []
	idtofontstyles` styleword [styleflag:styleflags]
		| notStyleFlag
		= styles
		= [style:styles]
	where
		notStyleFlag	= styleword bitand styleflag == 0
		styles			= idtofontstyles` (styleword-styleflag) styleflags
		style			= case styleflag of
							Bold		-> "Bold"
							Italic		-> "Italic"
							Underline	-> "Underline"
							Outline		-> "Outline"
							Shadow		-> "Shadow"
							Condense	-> "Condense"
							Extend		-> "Extend"
							_			-> error "idtofontstyles" "font"
												 "Fatal error: unmatched styleflag value ("+++toString styleflag+++")"
	idtofontstyles` _ _
		= []

String256 :: String
String256
	= string128 +++ string128
where
	string128 = "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"

/*
:: ScriptCode	:== Int

GetApplicationScript :: !*OSToolbox -> (!*ScriptCode,!*OSToolbox)
GetApplicationScript _ = code {
	ccall "P:I:I"
	}

GetThemeFont :: !ThemeFontID !ScriptCode !
extern OSStatus 
GetThemeFont(
  ThemeFontID   inFontID,
  ScriptCode    inScript,
  Str255        outFontName,       /* can be NULL */
  SInt16 *      outFontSize,
  Style *       outStyle)                                     AVAILABLE_MAC_OS_X_VERSION_10_0_AND_LATER;
*/