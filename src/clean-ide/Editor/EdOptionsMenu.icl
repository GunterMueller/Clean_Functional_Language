/*
 * EdOptionsMenu.icl: the options menu
 */

implementation module EdOptionsMenu

import StdTuple, StdEnum, StdList, StdFunc
import StdMenu, StdWindow, StdId, StdPSt, StdControl
import EdCommon, EdKeyMapping, EdState, EdClient
import morecontrols, ioutil

openOptionsMenu :: !(PSt *MyEditorState) -> PSt *MyEditorState
openOptionsMenu pstate
  = snd (openMenu Void optionsMenu pstate)
  
optionsMenu = Menu "Options" optionsMenuItems []
  where
	optionsMenuItems
	  =		MenuItem "Key mapping..."		[ 	MenuShortKey 'K'
	  										,	MenuFunction (noLS optionsKeyMapping) 
	  										]
	  :+:	MenuItem "Fonts and Tabs..."	[ 	MenuShortKey 'j'
	  										,	MenuFunction (noLS optionsFontAndTabs) 
	  										]

optionsKeyMapping pstate
  # (es,pstate)	= getEditorState pstate
  # keyMapping	= getKeyMapping es
    pstate		= configureKeyMapping keyMapping myset pstate
    // DvA: moet hier nu voor alle open editor windows keyboard functie veranderen...
  = pstate  
where
	myset keymap ps
		#	(ed,ps)			= getEditorState ps
			ed				= setKeyMapping keymap ed
			ps				= setEditorState ed ps
		= ps
  
optionsFontAndTabs pstate
	# (window,pstate)	= accPIO getActiveWindow pstate
	| isNothing window
		= pstate
	# window		= fromJust window
	# (names, pstate) = accPIO (accScreenPicture getFontNames) pstate	// DvA
	# ([dialogId, okId, fontId, fontSizeEditId, tabsId :_], pstate)	= accPIO (openIds 5) pstate
	# (mf,pstate)		= message window getFontInfo pstate
	| isNothing mf
		= pstate
	# fi			= fromJust mf
	# fontdef		= getFontDef fi.thefont
	# fontname		= fontdef.fName
//	# inifn			= findNameInList fontname names
	// should do checking here for name not found...
	# fontsize		= fontdef.fSize
	# fontSizes		= [7, 8, 9, 10, 12, 14, 18, 24 ]
//	# inifs			= findNameInList fontsize fontSizes
	# (mf,pstate)		= message window getFontInfo pstate
	| isNothing mf
		= pstate
	# fi			= fromJust mf
	# initabs		= fi.tabSize

	# controls
		=	CompoundControl
			(	TextControl "Font:" [ left ]
			:+:	TextControl "Size:" [ left ]
			:+:	TextControl "Tabs every" [ left ]
			) []
			
		:+:	CompoundControl
//		  	(	FontNameControl names (formatFont window) inifn [ControlId fontId]
//			:+: FontSizeControl fontSizes (formatSize window) inifs [ControlId fontSizeEditId]
			(	FontNameSizeControl fontname fontsize names fontSizes (formatFont window) (formatSize window) []
			:+:	EditControl (toString initabs) (PixelWidth 30) 1 [ControlKeyboard (const True) Able (\_ -> (tabsfun dialogId tabsId window)), ControlId tabsId] 
			:+:	TextControl "characters" []
			) []
/*			(	PopUpControl [ (name, id) \\ name <- names ] 1 [ left, ControlId fontId ]
      
			:+:	EditControl "9" (PixelWidth 30) 1 [ left, ControlId fontSizeEditId ]
			:+:	PopUpControl [ (toString fontSize
			                   , noLS 
			                     ( appPIO ( seq [ setControlTexts [(fontSizeEditId, toString fontSize)] ] )
			                     )
			                   )
						     \\ fontSize <- fontSizes
						     ] 1 [ ]

			:+:	EditControl "4" (PixelWidth 30) 1 [ left ] 
			:+:	TextControl "characters" []
			) []
*/
      
		:+:	ButtonControl "Ok"	
			[ ControlId okId
			, ControlFunction (noLS (closeWindow dialogId)) 
			, ControlPos (Right, zero)
			]
					
		:+:	ButtonControl "Cancel"
			[ ControlPos (LeftOfPrev, zero) 
			, ControlFunction (noLS (closeWindow dialogId)) 
			] 
	# dialog
		= Dialog "Font & Tabs" controls 
			[ WindowId dialogId 
			, WindowOk okId
			]
	# (_, pstate) = openModalDialog initabs dialog pstate
	= pstate
where
	left = ControlPos (Left, zero)

    tabsfun dialogId tabsId window (t,ps)
    	# (wstate,ps)	= accPIO (getWindow dialogId) ps
    	| isNothing wstate = (t,ps)
    	# wstate		= fromJust wstate
    	# (ok,mt)		= getControlText tabsId wstate
    	| not ok = (t,ps)
    	| isNothing mt = (t,ps)
    	# t				= fromJust mt
    	# t				= toInt t
    	# ps			= formatTabs window t ps
    	= (t,ps)
  
formatFont :: Id .FontName *(.a,*PSt *c) -> *(.a,*PSt *c) | Editor c;
formatFont window name pstate
	= noLS (fontAction window changeFont) pstate
where
	changeFont fontDef = { fontDef & fName = name }
	  
formatSize :: Id .FontSize *(.a,*PSt *c) -> *(.a,*PSt *c) | Editor c;
formatSize window fontSize pstate
	= noLS (fontAction window changeSize) pstate
where
	changeSize fontDef = { fontDef & fSize = fontSize }

formatTabs :: Id .Int *(PSt *b) -> *PSt *b | Editor b;
formatTabs window tabSize pstate
	= tabsAction window changeTabs pstate
where
	changeTabs (t,a,s) = (tabSize,a,s)

// perform an operation on the font of the active window

tabsAction :: Id .((Int,Bool,Bool) -> (.Int,.Bool,.Bool)) *(PSt *b) -> *PSt *b | Editor b;
tabsAction window tabsChange ps 
	#	(tabs, ps)				= message window msgGetTabs ps
	| isNothing tabs
		= ps
	#	tabs					= fromJust tabs
		newTabs					= tabsChange tabs
		(_, ps)					= message window (msgSetTabs newTabs) ps
	= ps

fontAction :: Id .(FontDef -> .FontDef) *(PSt *c )-> *(PSt *c) | Editor c;
fontAction window fontChange ps 
	# (font, ps)			= message window msgGetFont ps
	| isNothing font
		= ps
	# font					= fromJust font
	# fontDef				= getFontDef font
	# newFontDef			= fontChange fontDef
	# ((ok, newFont), ps)	= accScreenPicture (openFont newFontDef) ps
	| not ok
		# (newFont, ps)		= accScreenPicture (openDefaultFont) ps
		# (r, ps)			= message window (msgSetFont newFont) ps
		| isNothing r
			= ps
		= ps
	# (r, ps)				= message window (msgSetFont newFont) ps
	| isNothing r
		= ps
	= ps

