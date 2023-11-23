implementation module edoptions

import StdTuple, StdEnum, StdList, StdFunc, StdMisc
import StdMenu, StdWindow, StdId, StdPSt, StdControl
import StdClipboard, StdControlReceiver
import EdKeyMapping, EdState, EdClient, EdKeyboard
import IDE, IdeState, ExtNotice, UtilObjectIO
import colorpickcontrol
import ioutil, morecontrols
import typewin, colourclip
import PmPath

//-- public

optionsKeyMapping :: !*(PSt *b) -> *PSt *b | Editor b;
optionsKeyMapping ps
	#	(ed,ps)			= getEditorState ps
		keyMapping		= getKeyMapping ed
		ps				= configureKeyMapping keyMapping myset ps
	= ps  
where
	myset keymap ps
		#	(ed,ps)			= getEditorState ps
			ed				= setKeyMapping keymap ed
			ps				= setEditorState ed ps
		= ps

//--

:: ECLS = {ids::[Id],act::Int,cls::[Colour],mfs::EditMenuLS General}

froot txt ps
	# (id,ps) = accPIO openId ps
	# (_,ps) = openModalDialog 0 (Dialog txt NilLS [WindowClose (noLS (closeWindow id)),WindowId id]) ps
	= ps

editColours :: !*(PSt *General) -> *(PSt *General)
editColours ps
	# (prefs,ps)		= getPrefs ps
	# (rgbid,ps)		= openRGBId  ps
	# (lsid,ps)			= openRId ps
	# (wId,ps)			= openId ps
	# (okId,ps)			= openId ps
	# (cancelId,ps)		= openId ps
	# (ids,ps)			= openIds 30 ps
	# cls =
							[ prefs.syncols.textColour
							, prefs.defcols.textColour
							, prefs.impcols.textColour
							, prefs.syncols.tabColour
							, prefs.defcols.tabColour
							, prefs.impcols.tabColour
							, prefs.syncols.commentColour
							, prefs.defcols.commentColour
							, prefs.impcols.commentColour
							, prefs.syncols.stringColour
							, prefs.defcols.stringColour
							, prefs.impcols.stringColour
							, prefs.syncols.charColour
							, prefs.defcols.charColour
							, prefs.impcols.charColour
							, prefs.syncols.backgroundColour
							, prefs.defcols.backgroundColour
							, prefs.impcols.backgroundColour
							, prefs.syncols.marginColour
							, prefs.defcols.marginColour
							, prefs.impcols.marginColour
							, prefs.syncols.keywordColour
							, prefs.defcols.keywordColour
							, prefs.impcols.keywordColour
							, prefs.syncols.typedefColour
							, prefs.defcols.typedefColour
							, prefs.impcols.typedefColour
							, prefs.syncols.typedeclColour
							, prefs.defcols.typedeclColour
							, prefs.impcols.typedeclColour
							]
	# wloc				= {act=0,ids=ids,cls=cls,mfs={zfun=froot "options - Z",xfun=froot "options - X",cfun=id,vfun=id}}
	# (siz,ps)			= controlSize
							(ColourBoxControl`` rgbid lsid cls ids 1 Nothing)
							False
							(Just (0,0))
							(Just (0,0))
							(Just (0,0)) ps
	# buttonWidth		= ContentWidth "Cancel"
	# (ilook,wloc)		= idslook wloc
	# (dback,ps)		= GetDialogBackgroundColour ps
	# wdef				= Dialog "Editor Colours"
							(	RGBColourPickControl` rgbid (prefs.syncols.textColour) ilook Nothing
							:+: ButtonControl "&Copy"
								[ ControlFunction (copyFun wId rgbid)
								, ControlWidth buttonWidth
								]
							:+: ButtonControl "&Paste"
								[ ControlFunction (pasteFun wId rgbid)
								, ControlPos (BelowPrev,zero)
								, ControlWidth buttonWidth
								]
							:+: ButtonControl "&Apply"
								[ ControlFunction (applyFun rgbid lsid)
								, ControlPos (BelowPrev,zero)
								, ControlWidth buttonWidth
								]
							:+: ButtonControl "Ca&ncel"
								[ ControlFunction (cancelFun wloc wId)
								, ControlId cancelId
								, ControlPos (BelowPrev,zero)
								, ControlWidth buttonWidth
								]
							:+: ButtonControl "&OK"
								[ ControlFunction (okFun rgbid lsid wId)
								, ControlId okId
								, ControlPos (BelowPrev,zero)
								, ControlWidth buttonWidth
								]
							:+: TextControl ".xxx" [ControlWidth (PixelWidth siz.w),ControlPos (Left,zero)]
							:+: TextControl ".dcl" [ControlWidth (PixelWidth siz.w)]
							:+: TextControl ".icl" [ControlWidth (PixelWidth siz.w)]
							:+: ColourBoxControl`` rgbid lsid cls ids 0 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 1 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 2 Nothing
							:+: TextControl "Text" []

							:+: ColourBoxControl`` rgbid lsid cls ids 3 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 4 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 5 Nothing
							:+: TextControl "Tabs" []

							:+: ColourBoxControl`` rgbid lsid cls ids 6 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 7 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 8 Nothing
							:+: TextControl "Comments" []

							:+: ColourBoxControl`` rgbid lsid cls ids 9 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 10 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 11 Nothing
							:+: TextControl "Strings" []

							:+: ColourBoxControl`` rgbid lsid cls ids 12 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 13 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 14 Nothing
							:+: TextControl "Chars" []

							:+: ColourBoxControl`` rgbid lsid cls ids 15 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 16 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 17 Nothing
							:+: TextControl "Background" []

							:+: ColourBoxControl`` rgbid lsid cls ids 18 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 19 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 20 Nothing
							:+: TextControl "Right Margin" []

							:+: ColourBoxControl`` rgbid lsid cls ids 21 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 22 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 23 Nothing
							:+: TextControl "Keywords" []

							:+: ColourBoxControl`` rgbid lsid cls ids 24 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 25 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 26 Nothing
							:+: TextControl "Typedefs" []

							:+: ColourBoxControl`` rgbid lsid cls ids 27 (Just (Left,zero))
							:+: ColourBoxControl`` rgbid lsid cls ids 28 Nothing
							:+: ColourBoxControl`` rgbid lsid cls ids 29 Nothing
							:+: TextControl "Typedecls" []

							:+: Receiver lsid lsfun []
							)
							[ WindowPen [PenBack dback]
							, WindowClose 	(cancelFun wloc wId)
							, WindowId wId
							, WindowInit (setBoxCol)
							, WindowOk okId
							, WindowCancel cancelId
							]
	# (_,ps) = openModalDialog wloc wdef ps
	= ps
where
	copyFun wId rId (ls=:{cls,act},ps)
		// get active colour control
		// and put in clipboard
//		# cur	= cls!!act
//		# ps	= setClipboard [toClipboard (toString cur)] ps
//		= (ls,ps)
		# ps	= getColourBoxColour rId cont ps
		= (ls,ps)
	where
		cont col ps
				| isNothing col = ps
				# col	= fromJust col
				# ps	= setClipboard [toClipboard (toString col)] ps
				= ps
	pasteFun wId rId (ls=:{cls,act},ps)
		// get clipboard
		// and put in active colour control
		# (its,ps)	= getClipboard ps
		| isEmpty its
			= (ls,ps)
		# its		= map fromClipboard its
		# its		= filter isJust its
		| isEmpty its
			= (ls,ps)
		# it		= fromJust (hd its)
		| it <> toStringC (fromString it)
			= (ls,ps)
		# ls		= {ls & cls = updateAt act (fromString it) cls}
		# (ls,ps)	= setBoxCol (ls,ps)
		# (clook,ls)= clslook ls
		# ps		= setColourBoxColour` rId clook ps
		= (ls,ps)
	ColourBoxControl`` rgbid lsid cls ids x p
		= ColourBoxControl` (toRGBColour (cls!!x)) (ids!!x) (mstuff rgbid lsid x) p
	where
		mstuff rgbid lsid x = (mfilter,mfunction rgbid lsid x)
		mfilter (MouseDown _ _ _) = True
		mfilter _ = False
		mfunction rgbid lsid x _ (ls,ps)
			= updateActiveInLS rgbid lsid cont (ls,ps)
		where
			cont (ls,ps)
				# (ilook,ls)	= idslook ls
				# (clook,ls)	= clslook ls
				# ps	= appPIO (SetColourBox ilook (toRGBColour clook)) ps
				# ls	= {ls & act = x}
				# (ilook,ls)	= idslook ls
				# (clook,ls)	= clslook ls
				# ps	= appPIO (SetColourBox` ilook (toRGBColour clook)) ps
				# ps	= setColourBoxId rgbid ilook ps
				# ps	= setColourBoxColour` rgbid clook ps
				= (ls,ps)

	setBoxCol (ls,ps)
		# (ilook,ls)	= idslook ls
		# (clook,ls)	= clslook ls
		# ps = appPIO (SetColourBox` ilook (toRGBColour clook)) ps
		= (ls,ps)
	idslook ls=:{ids,act} = (ids!!act, ls)
	clslook ls=:{cls,act} = (cls!!act, ls)
	toStringC :: !Colour -> String
	toStringC c = toString c
	lsfun f (ls,ps) = f (ls,ps)

	updateActiveInLS rgbid lsid cont3 (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
				| isNothing col = ps
				# col = fromJust col
				# (_,ps) = asyncSend lsid (cont2 col) ps
				= ps
		cont2 col (ls=:{act,cls},ps)
				# ls	= {ls & cls = updateAt act col cls}
				= cont3 (ls,ps)

	okFun rgbid lsid wId (ls,ps)
		= updateActiveInLS rgbid lsid cont (ls,ps)
	where
		cont (ls,ps)
			# (ls,ps) = apply (ls,ps)
			= (ls, closeWindow wId ps)
	
	cancelFun inils wId (_,ps)
		# (ls,ps) = apply (inils,ps)
		= (ls, closeWindow wId ps)
	
	applyFun rgbid lsid (ls,ps)
		= updateActiveInLS rgbid lsid apply (ls,ps)

	apply (ls=:{cls},ps)
		# (prefs,ps)	= getPrefs ps
		# syncols` =
							{ prefs.syncols
							& textColour		= cls!!0
							, tabColour			= cls!!3
							, commentColour		= cls!!6
							, stringColour		= cls!!9
							, charColour		= cls!!12
							, backgroundColour	= cls!!15
							, marginColour		= cls!!18
							, keywordColour		= cls!!21
							, typedefColour		= cls!!24
							, typedeclColour	= cls!!27
							}
		# defcols` =
							{ prefs.defcols
							& textColour		= cls!!1
							, tabColour			= cls!!4
							, commentColour		= cls!!7
							, stringColour		= cls!!10
							, charColour		= cls!!13
							, backgroundColour	= cls!!16
							, marginColour		= cls!!19
							, keywordColour		= cls!!22
							, typedefColour		= cls!!25
							, typedeclColour	= cls!!28
							}
		# impcols` =
							{ prefs.impcols
							& textColour		= cls!!2
							, tabColour			= cls!!5
							, commentColour		= cls!!8
							, stringColour		= cls!!11
							, charColour		= cls!!14
							, backgroundColour	= cls!!17
							, marginColour		= cls!!20
							, keywordColour		= cls!!23
							, typedefColour		= cls!!26
							, typedeclColour	= cls!!29
							}
		# prefs				= {prefs & syncols = syncols`, defcols = defcols`, impcols = impcols`}
		# ps				= setPrefs prefs ps
		# (windows,ps)		= accPIO getWindowsStack ps
		# ps				= doall prefs windows ps
		= (ls,ps)
	where
		doall prefs [] ps
			= ps
		doall prefs [win:rest] ps
			// need to ignore special edit windows, ie clipboard & types window...
			# (isclip,ps) = isClipboardWindow win ps
			| isclip
				= doall prefs rest ps
			# (twi,ps) = accPLoc getTypeWinInfo ps
			| isTypeWindow win twi
				= doall prefs rest ps
			# (pn,ps)		= message win (getPathName) ps
			| isNothing pn
				= doall prefs rest ps
			# pn			= fromJust pn
			# cols			= if (IsDefPathname pn) (prefs.defcols) (if (IsImpPathname pn) (prefs.impcols) (prefs.syncols))
			# (_,ps)		= message win (appFontInfo (fi_update cols)) ps
			# ps			= appPIO (updateWindow win Nothing) ps
			= doall prefs rest ps
		fi_update cols fi =
			{ fi
			& syntaxColours =
				{ fi.syntaxColours
				& textColour		= cols.textColour
				, tabColour			= cols.tabColour
				, commentColour		= cols.commentColour
				, stringColour		= cols.stringColour
				, charColour		= cols.charColour
				, backgroundColour	= cols.backgroundColour
				, marginColour		= cols.marginColour
				, keywordColour		= cols.keywordColour
				, typedefColour		= cols.typedefColour
				, typedeclColour	= cols.typedeclColour
				}
			}

defaultColours :: !*(PSt *General) -> *(PSt *General)
defaultColours ps
	# (prefs,ps)		= getPrefs ps
	# (rgbid,ps)		= openRGBId  ps
	# (wId,ps)			= openId ps
	# wloc				= 0
	# col				= case wloc of
								0 -> prefs.syncols.textColour
								1 -> prefs.syncols.tabColour
								2 -> prefs.syncols.commentColour
								3 -> prefs.syncols.stringColour
								4 -> prefs.syncols.charColour
								5 -> prefs.syncols.backgroundColour
								6 -> prefs.syncols.marginColour
								7 -> prefs.syncols.keywordColour
								8 -> prefs.syncols.typedefColour
								9 -> prefs.syncols.typedeclColour
								_ -> abort "edoptions[defaultColours]: unknown ls"
	# (dback,ps) = GetDialogBackgroundColour ps
	# wdef				= Dialog "Pick a colour"
							(	RGBColourPickControl rgbid col Nothing
							:+: PopUpControl
									[("Text"		,psel rgbid 0)
									,("Tabs"		,psel rgbid 1)
									,("Comments"	,psel rgbid 2)
									,("Strings"		,psel rgbid 3)
									,("Chars"		,psel rgbid 4)
									,("Background"	,psel rgbid 5)
									,("Keywords"	,psel rgbid 6)
									,("Typedefs"	,psel rgbid 7)
									,("Typedecls"	,psel rgbid 8)
									] wloc []
							:+: ButtonControl "Set" [ControlFunction (cset rgbid)]
							)
							[	WindowPen [PenBack dback]
							,	WindowClose 	(dlogClose wId)
							,	WindowId wId
							]
	# (_,ps) = openModalDialog wloc wdef ps
	= ps
where
	dlogClose wId (ls,ps)
		# ps				= closeWindow wId ps
		= (ls,ps)
	psel rid i (ls,ps)
		# (prefs,ps)	= getPrefs ps
		# col			= case i of
								0 -> prefs.syncols.textColour
								1 -> prefs.syncols.tabColour
								2 -> prefs.syncols.commentColour
								3 -> prefs.syncols.stringColour
								4 -> prefs.syncols.charColour
								5 -> prefs.syncols.backgroundColour
								6 -> prefs.syncols.marginColour
								7 -> prefs.syncols.keywordColour
								8 -> prefs.syncols.typedefColour
								9 -> prefs.syncols.typedeclColour
								_ -> abort "edoptions[defaultColours]: also unknown ls"
		# ps = setColourBoxColour rid col ps
		= (i,ps)
	cset rid (ls,ps)
		# ps = getColourBoxColour rid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col = ps
			# col = fromJust col
			# (prefs,ps)		= getPrefs ps
			# prefs				= {prefs & syncols = sc_update ls prefs.syncols col}
			# ps				= setPrefs prefs ps
			# (windows,ps)		= accPIO getWindowsStack ps
			= doall prefs windows ps

		sc_update 0 sc col = {sc & textColour		= col}
		sc_update 1 sc col = {sc & tabColour		= col}
		sc_update 2 sc col = {sc & commentColour	= col}
		sc_update 3 sc col = {sc & stringColour		= col}
		sc_update 4 sc col = {sc & charColour		= col}
		sc_update 5 sc col = {sc & backgroundColour	= col}
		sc_update 6 sc col = {sc & keywordColour	= col}
		sc_update 7 sc col = {sc & typedefColour	= col}
		sc_update 8 sc col = {sc & typedeclColour	= col}
		sc_update _ sc col = abort "edoptions[defaultColours:sc_update]: unknown ls"

		doall prefs [] ps
			= ps
		doall prefs [win:rest] ps
			# (pn,ps)		= message win (getPathName) ps
			| isNothing pn
				= doall prefs rest ps
			# pn			= fromJust pn
			| IsDefPathname pn || IsImpPathname pn
				= doall prefs rest ps
			# (_,ps)		= message win (appFontInfo (fi_update prefs)) ps
			# ps = appPIO (updateWindow win Nothing) ps
			= doall prefs rest ps
		fi_update prefs fi =
			{ fi
			& syntaxColours =
				{ fi.syntaxColours
				& textColour		= prefs.syncols.textColour
				, tabColour			= prefs.syncols.tabColour
				, commentColour		= prefs.syncols.commentColour
				, stringColour		= prefs.syncols.stringColour
				, charColour		= prefs.syncols.charColour
				, backgroundColour	= prefs.syncols.backgroundColour
				, keywordColour		= prefs.syncols.keywordColour
				, typedefColour		= prefs.syncols.typedefColour
				, typedeclColour	= prefs.syncols.typedeclColour
				}
			}

lineFun :: Id .Bool *(PSt *b) -> *PSt *b | Editor b;
lineFun window linenumbers ps 
	#	(_, ps)				= message window (setLineNumbers linenumbers) ps
	= ps

syncFun :: Id .Bool *(PSt *b) -> *PSt *b | Editor b;
syncFun window syntaxcolor ps 
	#	(_, ps)				= message window (appFontInfo (\fi->{fi & showSyntax = syntaxcolor})) ps
	# ps = appPIO (updateWindow window Nothing) ps
	= ps

// perform an operation on the font of the given window

fontAction :: Id .(FontDef -> .FontDef) *(PSt *c )-> *(PSt *c) | Editor c;
fontAction window fontChange ps 
	# (font, ps)			= message window msgGetFont ps
	| isNothing font
		= ps
	# font					= fromJust font
	# fontDef				= getFontDef font
	# newFontDef			= fontChange fontDef
	# (newFont, ps)			= safeOpenFont newFontDef ps
	# (r, ps)				= message window (msgSetFont newFont) ps
	| isNothing r
		= ps
	= ps

// perform an operation on the tabs of the given window

formatTabs :: Id .Int *(PSt *b) -> *PSt *b | Editor b;
formatTabs window tabSize pstate
	= tabsAction window changeTabs pstate
where
	changeTabs (t,a,s) = (tabSize,a,s)

autoTabs :: Id .Bool *(PSt *b) -> *PSt *b | Editor b;
autoTabs  window autoTab pstate
	= tabsAction window changeAuto pstate
where
	changeAuto (t,a,s) = (t,autoTab,s)

showTabs :: Id .Bool *(PSt *b) -> *PSt *b | Editor b;
showTabs window showTab pstate
	= tabsAction window changeShow pstate
where
	changeShow (t,a,s) = (t,a,showTab)

tabsAction :: Id .((Int,Bool,Bool) -> (.Int,.Bool,.Bool)) *(PSt *b) -> *PSt *b | Editor b;
tabsAction window tabsChange ps 
	#	(tabs, ps)				= message window msgGetTabs ps
	| isNothing tabs
		= ps
	#	tabs					= fromJust tabs
		newTabs					= tabsChange tabs
		(_, ps)					= message window (msgSetTabs newTabs) ps
	= ps

marginFun :: Id .Int *(PSt *b) -> *PSt *b | Editor b;
marginFun window margin ps 
	#	(_, ps)				= message window (msgSetMargin margin) ps
	= ps

//--

defaultFontAndTabs :: !*(PSt *General) -> *(PSt *General)
defaultFontAndTabs ps
	# (names, ps) = accPIO (accScreenPicture getFontNames) ps
	// filter fixed width fonts....
//	# (fixed,ps) = seqList (map (\f->accPIO (accScreenPicture (lisFixedWidth f))) names) ps
	# (fixed,ps) = accPIO (accScreenPicture (seqList (map lisFixedWidth names))) ps
	# names = lfilter fixed names
	# (prefs,ps) = getPrefs ps
	# fontdef = prefs.edwinfont
	# (initabs,iniauto,inishow,iniline,inisync) = prefs.edwintabs
	# inimargin = prefs.edwinmargin
	# fontname = fontdef.fName
	# fontsize = fontdef.fSize
	# fontSizes = [7, 8, 9, 10, 12, 14, 18, 24 ]
	// FIXME use a record for this state
	# inistate = (initabs,inimargin,iniauto,inishow,iniline,inisync)
	# (dialogId,ps)		= openId ps
	# (okId,ps)		= openId ps
	# (tabsId,ps)		= openId ps
	# (marginId,ps)		= openId ps
	# (cancelId,ps)		= openId ps
	# controls
		=	FontNameSizeControl fontname fontsize names fontSizes fontfun sizefun [ left ]
		:+:	TextControl "Tabs every" [ left ]
		:+:	EditControl (toString initabs) (PixelWidth 30) 1
			[ ControlKeyboard (const True) Able (\_ -> (tabsfun dialogId tabsId))
			, ControlId tabsId
			, ControlActivate (noLS (appPIO (setEditControlSelection tabsId 1 0)))
			] 
		:+:	TextControl "characters" []
		:+:	TextControl "Right margin" [ left ]
		:+:	EditControl (toString inimargin) (PixelWidth 30) 1
			[ ControlKeyboard (const True) Able (\_ -> (marginfun dialogId marginId))
			, ControlId marginId
			, ControlActivate (noLS (appPIO (setEditControlSelection marginId 1 0)))
			] 
		:+:	TextControl "characters" []
		:+: CheckControl
			[("Auto Indent"		,Nothing,toMark iniauto,(autofun))
			,("Show Tabs"		,Nothing,toMark inishow,(showfun))
			,("Show LineNrs"	,Nothing, toMark iniline, (linefun))
			,("Syntax Colouring"		,Nothing, toMark inisync, (syncfun))
			]
			(Columns 1)
			[left]
    	:+:	ButtonControl "OK"
			[ ControlId okId
			, ControlFunction (okfun dialogId) 
			, ControlPos (Right, zero)
			, ControlWidth (ContentWidth "Cancel")
			]
    	:+:	ButtonControl "Cancel"
			[ ControlPos (LeftOfPrev, zero) 
			, ControlFunction (cancelfun dialogId inistate fontname fontsize)
			, ControlId cancelId
			] 
    	:+:	ButtonControl "Apply"
			[ ControlPos (LeftOfPrev, zero) 
			, ControlFunction (applyfun)
			] 
	# dialog
		= Dialog "Editor Settings" controls 
	  		[ WindowId dialogId 
	  		, WindowOk okId
	  		, WindowCancel cancelId
	  		, WindowClose (cancelfun dialogId inistate fontname fontsize)
	  		]
	# (_,ps) = openModalDialog inistate dialog ps
	= ps
where
    cancelfun dialogId (t,m,a,s,l,c) fontname fontsize (ls,ps)
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c), edwinmargin=m, edwinfont = {prefs.edwinfont & fName = fontname, fSize = fontsize}} ps
     	# (ls,ps) = apply (ls,ps)
     	= (ls, closeWindow dialogId ps)
    applyfun (ls,ps)
    	= apply (ls,ps)
    okfun dialogId (ls,ps)
    	# (ls,ps) = apply (ls,ps)
    	= (ls, closeWindow dialogId ps)
    left = ControlPos (Left, zero)
    fontfun name (ls,ps)
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwinfont = {prefs.edwinfont & fName = name}} ps
    	= (ls,ps)
    sizefun size (ls,ps)
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwinfont = {prefs.edwinfont & fSize = size}} ps
    	= (ls,ps)
    tabsfun dialogId tabsId ((t,m,a,s,l,c),ps)
    	# (wstate,ps)	= accPIO (getWindow dialogId) ps
    	| isNothing wstate = ((t,m,a,s,l,c),ps)
    	# wstate		= fromJust wstate
    	# [(ok,mt):_]	= getControlTexts [tabsId] wstate
    	| not ok = ((t,m,a,s,l,c),ps)
    	| isNothing mt = ((t,m,a,s,l,c),ps)
    	# t				= fromJust mt
    	# t				= toInt t
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c)} ps
    	= ((t,m,a,s,l,c),ps)
    autofun ((t,m,a,s,l,c),ps)
    	# a = not a
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c)} ps
    	= ((t,m,a,s,l,c),ps)
    showfun ((t,m,a,s,l,c),ps)
    	# s = not s
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c)} ps
    	= ((t,m,a,s,l,c),ps)	
    linefun ((t,m,a,s,l,c),ps)
    	# l = not l
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c)} ps
    	= ((t,m,a,s,l,c),ps)
    syncfun ((t,m,a,s,l,c),ps)
    	# c = not c
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwintabs = (t,a,s,l,c)} ps
    	= ((t,m,a,s,l,c),ps)
    marginfun dialogId marginId ((t,m,a,s,l,c),ps)
    	# (wstate,ps)	= accPIO (getWindow dialogId) ps
    	| isNothing wstate = ((t,m,a,s,l,c),ps)
    	# wstate		= fromJust wstate
    	# [(ok,mt):_]	= getControlTexts [marginId] wstate
    	| not ok = ((t,m,a,s,l,c),ps)
    	| isNothing mt = ((t,m,a,s,l,c),ps)
    	# m				= fromJust mt
    	# m				= toInt m
     	# (prefs,ps) = getPrefs ps
    	# ps = setPrefs {prefs & edwinmargin = m} ps
    	= ((t,m,a,s,l,c),ps)
	apply (ls,ps)
		# (prefs,ps)		= getPrefs ps
		# (windows,ps)		= accPIO getWindowsStack ps
		# ps				= doall prefs windows ps
		= (ls,ps)
	where
		doall prefs [] ps
			= ps
		doall prefs [win:rest] ps
			// need to ignore special edit windows, ie clipboard & types window...
			# (isclip,ps) = isClipboardWindow win ps
			| isclip
				= doall prefs rest ps
			# (twi,ps) = accPLoc getTypeWinInfo ps
			| isTypeWindow win twi
				= doall prefs rest ps
			# (pn,ps)		= message win (getPathName) ps
			| isNothing pn
				= doall prefs rest ps
			# (t,a,s,l,c)	= prefs.edwintabs
			# m				= prefs.edwinmargin
			# fontname		= prefs.edwinfont.fName
			# fontsize		= prefs.edwinfont.fSize
	    	# ps			= formatTabs win t ps
			# ps			= autoTabs win a ps
	    	# ps			= showTabs win s ps
		   	# ps			= lineFun win l ps
	    	# ps			= syncFun win c ps
			# ps			= marginFun win m ps
	    	# ps			= fontAction win (\fontdef->{fontdef & fName = fontname, fSize = fontsize}) ps
			= doall prefs rest ps
