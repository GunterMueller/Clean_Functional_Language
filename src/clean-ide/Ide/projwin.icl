implementation module projwin

import StdArray, StdFunc, StdMisc, StdOrdList, StdTuple
import StdClipboard,StdControlReceiver,StdFileSelect,StdMenu,StdMenuElement,StdPStClass,StdSystem
import ExtListBox, ExtNotice
import EdClient
import PmProject, PmFiles, UtilStrictLists, PmPath
import edfiles, messwin, errwin
import PmDialogues, PmDriver
import PmCleanSystem
import flextextcontrol
import ioutil, morecontrols, colorpickcontrol
import projmen, menubar, colourclip
import Platform, IdePlatform
import PmDirCache, UtilIO

//-- Project Window Options...

:: PWO =
	{ fn	:: !String		// font name
	, fs	:: !Int			// font size
	, fc	:: !Colour		// foreground colour
	, bc	:: !Colour		// background colour
	, hc	:: !Colour		// header colour
	, cr	:: !AC			// active colour control in PWO dialogue
	, shift	:: !Bool		// open dcl/icl on dbl-click
	}

:: AC = HC | FC | BC

instance == AC
where
	(==) HC HC = True
	(==) FC FC = True
	(==) BC BC = True
	(==) _ _ = False
	
projwinOptions :: !*(PSt *General) -> *PSt *General;
projwinOptions ps
    # (dialogId,ps)	= openId ps
    # (okId,ps)		= openId ps
    # (cancelId,ps)	= openId ps
	# (hcid,ps)		= openId ps
	# (fcid,ps)		= openId ps
	# (bcid,ps)		= openId ps
	# (rgbid,ps)	= openRGBId ps
	# (lsid,ps)		= openRId ps
	# (fontNames, ps) = accPIO (accScreenPicture getFontNames) ps
	# fontSizes		= [7,8,9,10,11,12]
	# (lbId,ps)		= getPWI ps
	# (pen,ps)		= getExtListBoxPen lbId ps
	| isNothing pen
		= ps
	# pen			= fromJust pen
	# fdef			= getPenAttributeFont pen
	# inifn			= fdef.fName
	# inifs			= fdef.fSize
	# (prefs,ps)	= getPrefs ps
	# inihc			= prefs.prj_prefs.proj_topc
	# inifc			= prefs.prj_prefs.proj_forc
	# inibc			= prefs.prj_prefs.proj_bacc
	# inishift		= prefs.prj_prefs.proj_shft
	# inistate		= {fn = inifn, fs = inifs, fc = inifc, bc = inibc, hc = inihc, cr = HC, shift = inishift}
    # controls		=
    	(	LayoutControl
		(	FontNameSizeControl inifn inifs fontNames fontSizes fontfun sizefun [ left ]
		:+: RGBColourPickControl` rgbid inihc hcid (Just (Left,zero))
		) []

		:+: LayoutControl
		(	TextControl "Header:" [ left , ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inihc) hcid (mfilter,mfun rgbid lsid hcid fcid bcid HC) Nothing
		:+:	TextControl "Text:" [ left , ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inifc) fcid (mfilter,mfun rgbid lsid hcid fcid bcid FC) Nothing
		:+:	TextControl "Background:" [ left , ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inibc) bcid (mfilter,mfun rgbid lsid hcid fcid bcid BC) Nothing
		) []

	   	:+: RadioControl
	   		[("Open .dcl on double-click",Nothing,\(ls,ps)->({ls & shift = True},ps))
	   		,("Open .icl on double-click",Nothing,\(ls,ps)->({ls & shift = False},ps))
	   		] (Columns 1) (if inishift 1 2)
	   		[ControlPos (Left,zero)
	   		]
	   	:+:	ButtonControl "Ok"
  			[ ControlId okId
  			, ControlFunction (okFun rgbid lsid dialogId) 
  			, ControlPos (Right, zero)
  			, ControlWidth (ContentWidth "Cancel")
  			]
    	:+:	ButtonControl "Cancel"
  			[ ControlPos (LeftOfPrev, zero) 
  			, ControlFunction (cancelFun inistate dialogId)
  			, ControlId cancelId
  			] 
		:+: ButtonControl "Apply"
			[ ControlPos (LeftOfPrev,zero)
			, ControlFunction (applyFun rgbid lsid)
			]
  		:+: ButtonControl "Paste"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (pasteFun rgbid hcid fcid bcid)
  			]
  		:+: ButtonControl "Copy"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (copyFun rgbid)
  			]

  		:+: Receiver lsid lsfun []
		)
	# dialog		=
		Dialog "Project Window..." controls 
  		[ WindowId dialogId 
  		, WindowOk okId
  		, WindowCancel cancelId
  		, WindowClose (cancelFun inistate dialogId)
  		, WindowInit (setBoxCol hcid fcid bcid)
  		]
	# (_,ps) = openModalDialog inistate dialog ps
	= ps
where
	toStringC :: !Colour -> String
	toStringC c = toString c
	copyFun rgbid (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# ps	= setClipboard [toClipboard (toString col)] ps
			= ps
	pasteFun rgbId hcId fcId bcId (ls=:{cr},ps)
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
		# col		= fromString it
		# ls		= case cr of
						HC -> {ls & hc = col}
						FC -> {ls & fc = col}
						BC -> {ls & bc = col}
		# (ls,ps)	= setBoxCol hcId fcId bcId (ls,ps)
		# ps		= setColourBoxColour` rgbId col ps
		= (ls,ps)
	mfilter (MouseDown _ _ _) = True
	mfilter _ = False
	mfun rgbid lsid hcId fcId bcId ac _ (ls=:{fc,bc,hc,cr},ps)
		| cr == ac = (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col = ps
			# col = fromJust col
			# ps	= appPIO (case ac of
								HC	-> SetColourBox` hcId (case cr of
									HC	-> toRGBColour col
									_	-> toRGBColour hc
									)
								_	-> SetColourBox hcId (case cr of
									HC	-> toRGBColour col
									_	-> toRGBColour hc
									)
							) ps
			# ps	= appPIO (case ac of
								FC	-> SetColourBox` fcId (case cr of
									FC	-> toRGBColour col
									_	-> toRGBColour fc
									)
								_	-> SetColourBox fcId (case cr of
									FC	-> toRGBColour col
									_	-> toRGBColour fc
									)
							) ps
			# ps	= appPIO (case ac of
								BC	-> SetColourBox` bcId (case cr of
									BC	-> toRGBColour col
									_	-> toRGBColour bc
									)
								_	-> SetColourBox bcId (case cr of
									BC	-> toRGBColour col
									_	-> toRGBColour bc
									)
							) ps
			# cId = case ac of
						HC -> hcId
						FC -> fcId
						BC -> bcId
			# col` = case ac of
						HC -> hc
						FC -> fc
						BC -> bc
			# ps	= setColourBoxId rgbid cId ps
			# ps	= setColourBoxColour` rgbid col` ps
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cr},ps)
			# ls	= case cr of
						HC -> {ls & hc = col, cr = ac}
						FC -> {ls & fc = col, cr = ac}
						BC -> {ls & bc = col, cr = ac}
			= (ls,ps)
	setBoxCol hcId fcId bcId (ls=:{cr,hc,fc,bc},ps)
		# (cId,col) = case cr of
						HC	-> (hcId,hc)
						FC	-> (fcId,fc)
						BC	-> (bcId,bc)
		# ps = appPIO (SetColourBox` cId (toRGBColour col)) ps
		= (ls,ps)
	applyFun rgbid lsid (ls,ps)
		= cset rgbid lsid id (ls,ps)
	okFun rgbid lsid dialogId (ls,ps)
		= cset rgbid lsid (noLS (closeWindow dialogId)) (ls,ps)
	cancelFun inils dialogId (ls,ps)
		# ls = inils
		# (ls,ps) = apply (ls,ps)
		= (ls,closeWindow dialogId ps)
	lsfun f (ls,ps)
		= f (ls,ps)
	cset rgbid lsid finish (ls=:{cr},ps)
		# ps = getColourBoxColour rgbid cont1 ps
		= (ls,ps)
	where
		cont1 col ps
			| isNothing col = ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont4 col) ps
			= ps
		cont4 col (ls,ps)
			# ls		= case cr of
							HC -> {ls & hc = col}
							FC -> {ls & fc = col}
							BC -> {ls & bc = col}
			# (ls,ps) = apply (ls,ps)
			= finish (ls,ps)
	apply (ls=:{fn,fs,fc,bc,hc,shift},ps)
		# (lbId,ps)	= getPWI ps
		# ((fnt_ok,fnt),ps)	= accScreenPicture (openFont {fName = fn, fSize = fs, fStyles = []}) ps
		# pen2		= if fnt_ok [PenFont fnt] []
		# pen		= [PenColour fc, PenBack bc:pen2] 

		# ps			= closeAllExtListBoxItems lbId ps

		# ps		= setExtListBoxPen lbId pen ps
		# (wId,ps)	= getPWW ps
		# ps		= appPIO (setWindowLook wId True (True,(\_ {newFrame} -> fill newFrame o setPenColour hc))) ps
		# (prefs,ps) = getPrefs ps
		# prefs		=	{ prefs
						& prj_prefs.proj_forc = fc
						, prj_prefs.proj_bacc = bc
						, prj_prefs.proj_topc = hc
						, prj_prefs.proj_font = {prefs.prj_prefs.proj_font & fName = fn, fSize = fs}
						, prj_prefs.proj_shft = shift
						}
		# ps		= setPrefs prefs ps
		| not fnt_ok
			= (ls,ps)
		// set FlexBar pens...
		# (xId,ps)	= getPWX ps
		# (mId,ps)	= getPWM ps
		# ps = addFlexPens [(xId,pen2),(mId,pen2)] ps

		# ps = pm_update_project_window ps
		
		= (ls,ps)

    left = ControlPos (Left, zero)
	fontfun name (ls,ps)
		# ls		= {PWO | ls & fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {PWO | ls & fs = size}
		= (ls,ps)


//--

pm_open_project_window :: !*(PSt *General) -> *(PSt *General)
pm_open_project_window ps
	# (menuIds,ps)		= getMenuIds ps
	# (prefs,ps)		= getPrefs ps
	# pw_xvec			= prefs.prj_prefs.proj_pos
	# pw_xsiz			= prefs.prj_prefs.proj_siz
	# (wId,ps)			= getPWW ps
	# (lbId,ps)			= getPWI ps
	# (xxId,ps)			= getPWX ps
	# (mmId,ps)			= getPWM ps
	# (lcId,ps)			= openId ps
	# (lc2Id,ps)		= openId ps
	# (lc3Id,ps)		= openId ps
	# pw_main			= ""
	# pw_exec			= ""
	# (fnt,ps)			= accScreenPicture (getFont prefs.prj_prefs.proj_font) ps
	# pen				= [PenBack prefs.prj_prefs.proj_bacc, PenColour prefs.prj_prefs.proj_forc, PenFont fnt]
	# topc				= \butw -> top_controls lbId.controlId lcId lc2Id lc3Id xxId mmId pw_main pw_exec butw fnt
	# (pw_min_size,ps)	= controlSize (topc 0) True Nothing Nothing Nothing ps
	# lbox				= \ini siz -> PWListBox ini lbId lc2Id
							(PlatformDependant
							 (/* Win */ pw_min_size.Size.h+4)
							 (/* Mac */ pw_min_size.Size.h)
							 )siz pen
	# pw_xpos			= (LeftTop,OffsetVector pw_xvec)
	# butwidth			= pw_xsiz.w
	# (err,ps)			= openWindow Void (
							ProjectWindow "project"
							(lbox False {Size | pw_xsiz & h = pw_xsiz.Size.h - 
								PlatformDependant
								(/* Win */ pw_min_size.Size.h+4)
								(/* Mac */ pw_min_size.Size.h)
								})
							lbId.controlId
							(topc butwidth)
							wId
							pw_xsiz
							pw_xpos
							prefs.prj_prefs.proj_topc
							menuIds
							) ps
	| err <> NoError = abort "unable to open Project window"
	= ps
where
	proj_activate cId ps
		# ({mn_clo,mn_sav,mn_sva,mn_und,md_cmp,md_chk,md_gen,md_cst,md_est,mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds,moduleIds},ps=:{io})
			= getMenuIds ps
		# io = setMenuElementTitles
				[(mn_sav,"Save Project")
				,(mn_und,"&Undo")						// shouldn't be here...
				] io
		# mg_edt = removeAt 3 mg_edt					// hack to avoid disabling "Select All"
		# l1 = [mn_und,mn_clo,mn_cut,mn_cpy,mn_pst,mn_clr:mg_edt]
		# io = disableMenuElements l1 io
		# io = disableMenuElements searchIds.findIds io
		# io = disableMenuElements searchIds.gotoIds io
//		# projModuleIds = removeMembers moduleIds [md_cmp,md_chk,md_gen]
		# projModuleIds = moduleIds
		# io = enableMenuElements projModuleIds io
		# l2 = removeMembers [mn_sav,mn_sva,md_cmp,md_chk,md_gen,md_cst,md_est] projModuleIds
		# io = disableMenuElements l2 io
		# ps = {ps & io = io}
//		# ps = setActiveControl cId ps
		= ps

	proj_deactivate ps
		# ({mn_clo,mn_sav,mn_sva,md_cmp,md_chk,md_gen,md_cst,md_est,mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds},ps=:{io})
			= getMenuIds ps
		# io = setMenuElementTitles [(mn_sav,"Save")] io
		# io = disableMenuElements [mn_sav,mn_sva,md_cmp,md_chk,md_gen,md_cst,md_est] io
		# io = enableMenuElements [mn_clo,mn_cut,mn_cpy,mn_pst,mn_clr:mg_edt] io
		# io = enableMenuElements searchIds.findIds io
		# io = enableMenuElements searchIds.gotoIds io
		= {ps & io = io}

	getFont fd pic
		# ((ok,fnt),pic) = openFont fd pic
		| not ok
			= openDialogFont pic
		= (fnt,pic)

	ProjectWindow title lb lbId tc wId pw_xsiz pw_xpos topc menuIds
		= Window title
			(	tc
			:+:	lb
			)
			[ WindowId			wId
			, WindowViewSize	pw_xsiz
			, WindowPos			pw_xpos
			, WindowPen			[PenBack topc]
			, WindowLook		True (\_ {newFrame,updArea} -> seq (map unfill updArea))
			, WindowInit		(noLS ((proj_activate lbId) o SetWindowIcon wId ProjectIcon))
			// setWindowViewSize forces resize of listbox... actually forces proper init...
			, WindowInitActive	lbId
			, WindowActivate	(noLS (proj_activate lbId))
			, WindowDeactivate	(noLS proj_deactivate)
			]

	PWListBox ini lbId lc2Id minh size pen
		= ExtListBoxControl
						[]	// contents
						[]	// initial selection
						(\_ ps -> ps)
						lbId
						[ ControlOuterSize size
						, ControlResize (\_ _ nw -> {Size | nw & h = nw.Size.h - minh})
						, ControlPos (if ini (Left,zero) (Below lc2Id,OffsetVector {zero & vx = ~10, vy = 10}))
						, ControlPen pen
						, ControlHMargin 10 10
						, ControlVMargin 3 3
						, extKeyboard
//						, ControlMouse mouseFilter Able mouseFunction
						]

	top_controls lbId localId local2Id local3Id xxId mmId pw_main pw_exec butw fnt =
			(
				FlexText pw_exec xxId
					[ ControlPen [PenColour Black,PenBack LightGrey, PenFont fnt]
					, ControlResize (\cc _ nw -> {cc & w = nw.w - 20})
					, ControlId local3Id
					, ControlPos (Fix,OffsetVector {vx=10,vy=10})
					, ControlWidth (PixelWidth (butw-20))
					]
			:+:	FlexText pw_main mmId
					[ ControlPen [PenColour Black,PenBack LightGrey, PenFont fnt]
					, ControlResize (\cc _ nw -> {cc & w = nw.w - 20})
					, ControlPos (Below local3Id,OffsetVector {zero & vy = 5})
					, ControlId local2Id
					, ControlWidth (PixelWidth (butw-20))
					]
			)
	
pm_update_project_window :: !*(PSt *General) -> *PSt *General
pm_update_project_window ps
	# (interact, ps) = getInteract ps
	| not interact
		=	ps
	// interact
		=	pm_update_project_window_interactive ps

getProjwinPaths ps
	# (prjpaths,ps)	= getFromProject PR_GetPaths ps
	# (syspaths,ps)	= getCurrentPaths ps
	# (fstate,ps)	= getFstate ps
	# srcpaths		= Map (\d -> lookup d fstate) (AppendLists prjpaths syspaths)
	= (srcpaths,ps)
where
	lookup d [] = (False,d)
	lookup d [(u,d`):ds]
		| d == d` = (u,d)
		= lookup d ds

updFstate d u ps
	# (fstate,ps)	= getFstate ps
	# fstate		= update d u fstate
	# ps			= setFstate fstate ps
	= ps
where
	update d u [] = [(u,d)]
	update d u [e=:(_,d`):fs]
		| d == d` = [(u,d):fs]
		= [e:update d u fs]

pm_update_project_window_interactive :: !*(PSt *General) -> *PSt *General
pm_update_project_window_interactive ps
	# (lbId,ps)		= getPWI ps
	# (xxId,ps)		= getPWX ps
	# (mmId,ps)		= getPWM ps
	# (prefs,ps)	= getPrefs ps

	# (modules,ps)	= getFromProject PR_GetModuleStuff ps
	# (xp,ps)		= getFromProject PR_GetExecPath ps
	# (mm,ps)		= getFromProject PR_GetRootModuleName ps
	# (wId,ps)		= getPWW ps
	# (ws,ps)		= accPIO (getWindow wId) ps
	# (ok,mframe)	= case ws of
						Nothing		-> (False,Nothing)
						Just ws		-> getControlViewFrame lbId.controlId ws
	# (ok,mdomain)	= case ws of
						Nothing		-> (False,Nothing)
						Just ws		-> getControlViewDomain lbId.controlId ws
	# ps			= closeAllExtListBoxItems lbId ps
	# (ok,mframe`)	= case ws of
						Nothing		-> (False,Nothing)
						Just ws		-> getControlViewFrame lbId.controlId ws
	# (ok,mdomain`)	= case ws of
						Nothing		-> (False,Nothing)
						Just ws		-> getControlViewDomain lbId.controlId ws
	# (srcpaths,ps)	= getProjwinPaths ps
	# (appPath,ps)	= getStup ps
	  (prjPath,ps) = getFromProject PR_GetRootDir ps
	# lbItems		= items srcpaths appPath prjPath modules prefs.prj_prefs.proj_shft
	# ps			= appendExtListBoxItems lbId lbItems ps
	# ps			= case mframe of
						Nothing
							-> ps
						(Just jframe)
							# ps	= appPIO (moveControlViewFrame lbId.controlId (toVector jframe.corner1)) ps
//							# ps	= updateControl	// useless for now since moveviewframe & setviewdomain both already trigger updates...
							-> ps
	# xp			= symPath appPath prjPath xp
	# mm			= symPath appPath prjPath mm
	# ps			= setFlexTexts [(xxId,xp),(mmId,mm)] ps
	= ps
where
	items srcpaths appPath prjPath modules shift
		# mods			= StrictListToList modules
		| isEmpty mods
			= []
		# [(root,rootdir,_,_):mods]	= mods
		# mods					= filter isInPaths mods
		# mods					= sortBy (\(a,b,_,_) (c,d,_,_) -> less a b c d) mods
		# moditems				= makenice True "" mods
		# rootitem				= (GetModuleName root, open_imp rootdir (MakeImpPathname root), openif rootdir root)
		= [rootitem:moditems]
	where
		isInPaths (_,p,_,_) = any p srcpaths
		where
			any p Nil
				= False
			any p ((_,b) :! tl)
				= p == b || any p tl

		openif rootdir root ps
			# defpath		= MakeDefPathname root
			# path			= rootdir +++ defpath
			# (exists,ps)	= accFiles (FExists path) ps
			| exists
				= ed_open_path_sel path emptySelection ps
				= open_imp rootdir (MakeImpPathname root) ps

		less a b c d
			| before b d = True		// use < -ordening of searchpaths...
			| b == d
				= a < c
			= False

		before x y = bf srcpaths
		where
			bf Nil = False
			bf ((_,p):!r)
				| p == y = False
				| p == x = True
				= bf r

		makenice _ _ [] = []
		makenice u s l=:[(imp_mod_name_with_ext,b,_,_):r]
			| s <> b	// new directory
				# u`			= isUnfoldedDir b srcpaths
				  dir			= symPath appPath prjPath b
				  pw_separator	= if u`
				  					("\\\\--- "+++dir,pm_update_project_window_interactive o updFstate b False,id)
				  					("//--- "+++dir,pm_update_project_window_interactive o updFstate b True,id)
				= [pw_separator : makenice u` b l]
			| u
				= [(GetModuleName imp_mod_name_with_ext,f imp_mod_name_with_ext, f` imp_mod_name_with_ext):makenice u s r]	// add seperators...
				= makenice u s r
		where
			f imp_mod_name_with_ext
				= if shift
					(open_def b imp_mod_name_with_ext)
					(open_imp b imp_mod_name_with_ext)

			f` imp_mod_name_with_ext
				= if shift
					(open_imp b imp_mod_name_with_ext)
					(open_def b imp_mod_name_with_ext)

			isUnfoldedDir d Nil = False
			isUnfoldedDir d ((u,d`):!ds)
				| d == d` = u
				= isUnfoldedDir d ds

	open_def dirpath imp_mod_name_with_ext ps
		# imp_mod_file_name = replace_dots_by_dir_separators (RemoveSuffix imp_mod_name_with_ext)
		# dcl_file_name = imp_mod_file_name +++ ".dcl"
		# path			= dirpath +++ dcl_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# hs_file_name	= imp_mod_file_name +++ ".hs"
		# path			= dirpath +++ hs_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# lhs_file_name	= imp_mod_file_name +++ ".lhs"
		# path			= dirpath +++ lhs_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".dcl" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".hs" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".lhs" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		= could_not_find_notice dcl_file_name ps

	open_imp dirpath imp_mod_name_with_ext ps
		# imp_mod_file_name = replace_dots_by_dir_separators (RemoveSuffix imp_mod_name_with_ext)
		# icl_file_name	= imp_mod_file_name +++ ".icl"
		# path			= dirpath +++ icl_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# hs_file_name	= imp_mod_file_name +++ ".hs"
		# path			= dirpath +++ hs_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# lhs_file_name = imp_mod_file_name +++ ".lhs"
		# path			= dirpath +++ lhs_file_name
		# (exists,ps)	= accFiles (FExists path) ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".icl" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".hs" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		# (exists,path,ps)	= exists_module imp_mod_file_name ".lhs" ps
		| exists
			= ed_open_path_sel path emptySelection ps
		= could_not_find_notice icl_file_name ps

	could_not_find_notice path ps
		= okNotice
			[ "Clean Project Manager"
			, "Could not find file:"
			, path
			] ps

	exists_module :: {#Char} {#Char} *(PSt *General) -> *(!Bool,{#Char},!*(PSt *General))
	exists_module module_name file_ext ps
		# (srcpaths,ps) = get_project_and_environment_paths ps
		# ((ok,fullpath),ps) = accFiles (FindHModule module_name file_ext srcpaths) ps
		= (ok,GetLongPathName fullpath,ps)

get_project_and_environment_paths :: *(PSt *General) -> *(!(List {#Char}),!*(PSt *General))
get_project_and_environment_paths ps
	# (syspaths,ps)			= getCurrentPaths ps
	# (prj,ps)				= getProject ps
	# prjpaths				= PR_GetPaths prj
	= (AppendLists prjpaths syspaths,ps)

// pm_set: set main module
pm_set :: !*(PSt *General) -> *PSt *General
pm_set ps
	# (win,ps)	= accPIO getActiveWindow ps
	| isNothing win
		= okNotice ["Unable to set main module.","There is no active module window."] ps
	# win		= fromJust win
	# (path,ps)	= message win msgGetPathName ps
	| isNothing path
		= okNotice ["Unable to set main module.","There is no active module window."] ps
	# path			= fromJust path
	# (project,ps)	= getFromProject (\l->l) ps
	// check if mod in project already has settings...
	# info			= PR_GetModuleInfo (GetModuleName path) project
	| isJust info
		# info	= fromJust info
		# eo	= info.mod_edit_options.impeo
		# co	= info.compilerOptions
		# project = PR_SetRoot path eo co project
		# ps	= appProject (const project) ps
		# ps	= pm_update_project_window ps
		= ps
	# (pos,ps)	= accPIO (getWindowPos win) ps
	| isNothing pos
		= ps	// this should not occur
	# pos		= fromJust pos
	# (siz,ps)	= accPIO (getWindowViewSize win) ps
	# (nlc,ps)	= sendToActiveWindow getNewlineConvention ps
	| isNothing nlc
		= ps	// this should not occur
	# nlc		= fromJust nlc
	# pos_size	= WindowPosAndSize {posx = pos.vx,posy=pos.vy,sizex=siz.w,sizey=siz.Size.h}
	# eo		= {newlines = nlc}
	# weo		= {eo = eo,pos_size = pos_size}
	#	wco				= DefaultCompilerOptions
		project`		= PR_SetRoot path weo wco project
		ps				= appProject (const project`) ps
		ps = pm_update_project_window ps
	= ps
		
pm_compile :: !*(PSt *General) -> *PSt *General;
pm_compile ps
	= DoProcess "compiling"  (CompileProjectModule Compilation) (\_ _ _ _-> id) ps
/*
	// timed variant
	# (stick,ps)	= getCurrentTick ps
	# ps = DoProcess "compiling"  (CompileProjectModule Compilation) (\_ _ _ _-> id) ps
	# (etick,ps)	= getCurrentTick ps
	# ps = updateErrorWindow ["Compiler Timing: " +++ toString ((tickDifference etick stick) / ticksPerSecond)] ps
	= ps
*/
	
pm_check :: !*(PSt *General) -> *PSt *General;
pm_check ps
	= DoProcess "checking"  (CompileProjectModule SyntaxCheck) (\_ _ _ _-> id) ps

pm_gen_asm :: !*(PSt *General) -> *PSt *General;
pm_gen_asm ps
	= DoProcess "generating"  GenAsmProjectModule open_gen_asm ps
where
	open_gen_asm winpath modname ok newpaths ps
		| not (ok && newpaths)
			= ps
		# apath			= MakeAssemblySystemPathname winpath
		= ed_open_assembly apath ps
	ed_open_assembly pathName ps
		# (mFHrecId,ps)	= getFHI ps
		# (_,ps)		= syncSend2 mFHrecId pathName ps
		= ed_open_cont pathName cont ps
	where
		cont wasopen win ps
			| wasopen
				= ed_revert_win win ps
			# (_,ps) = message win mess ps
			= ps
		mess es
			# ((_,b,c),es) = msgGetTabs es
			= msgSetTabs (8,b,c) es
			

pm_upto :: !Bool !*(PSt *General) -> *PSt *General;
pm_upto force ps
	# ps = ed_ask_save_all False True (enableProjectMenu o bring_project_upto_date force cont o disableProjectMenu) ps
	= mb_update_undoinfo ps
where
	cont path linked ok ps
		| linked || not ok
			= closeInfo ps
		= showInfo (Level1 "Project is up to date") ps

pm_exec :: !*(PSt *General) -> *PSt *General;
pm_exec ps
	# ps = ed_ask_save_all False True (enableProjectMenu o bring_project_upto_date False cont o disableProjectMenu) ps
	= mb_update_undoinfo ps
where
	cont execpath linked ok ps
		# ps		= closeInfo ps
		| not ok
			= ps
		# (lo,ps)	= getFromProject PR_GetLinkOptions ps
		  (prj_path`,ps) = getFromProject PR_GetRootDir ps
		# (app_path,ps)				= getStup ps
		# execpath					= fulPath app_path prj_path` execpath
		= RunProgram execpath ps

pm_run :: !*(PSt *General) -> *PSt *General;
pm_run ps
	# (app_path,ps)				= getStup ps
	  (prj_path`,ps) = getFromProject PR_GetRootDir ps
	# (execpath,ps)				= getFromProject PR_GetExecPath ps
	# execpath					= fulPath app_path prj_path` execpath
	= RunProgram execpath ps

bring_project_upto_date :: !Bool CleanupCont !*(PSt *General) -> *PSt *General
bring_project_upto_date force continuation ps
	#	ps				= ew_safe_close ps							// close error window
	#	ps				= tw_safe_close ps							// close types window
	= BringProjectUptoDate force continuation ps

//--

disableProjectMenu ps
	# (mIds,ps)	= getMenuIds ps
	# ps		= appPIO (disableMenus [mIds.pm_menuid]) ps
	= ps
enableProjectMenu ps
	# (mIds,ps)	= getMenuIds ps
	# ps		= appPIO (enableMenus [mIds.pm_menuid]) ps
	= ps
//--

pm_build :: !.a -> .a;
pm_build ps			// rebuild project from scratch
	= ps

pm_link :: !.a -> .a;
pm_link ps			// relink project
	// fake it by deleting exe
	= ps

pm_copt :: !*(PSt *General) -> *PSt *General
pm_copt ps
	//-> only for module + ide, now added cursel in projwin
	// current active added... (need to check if active is part of project...)
	# (lbId,ps)			= getPWI ps
	# (project,ps)		= getFromProject (\l->l) ps
	# (path,ps)			= sendToActiveWindow msgGetPathName ps
	| isJust path
		# path			= fromJust path
		# (syspaths,ps) = getCurrentPaths ps
		  (prjpaths,ps) = getFromProject PR_GetPaths ps
		  ({mdn_name=mod},_) = determine_dir_and_filename path (AppendLists prjpaths syspaths)
		# minf			= PR_GetModuleInfo mod project
		| isNothing minf
			// module not found in project...
			// currently do nothing (could add to proj, but disappears when not in deps...)
			= okNotice ["This module is not part of the current project."] ps
		# minf			= fromJust minf
		# projco		= minf.compilerOptions
		# setco			= \co -> appProject (\l->PR_UpdateModule mod (\mi->{mi & compilerOptions = co}) l)
		= doCompilerOptionsDialog "Module Options" projco setco ps
	// should check if project window is active...
	// otherwise this behaviour is unintuitive
	# (pwId,ps)			= getPWW ps
	# (awId,ps)			= accPIO getActiveWindow ps
	| isNothing awId || pwId <> fromJust awId
		= ps
	# ((hassel,sel),ps)	= getExtListBoxSelection lbId ps
	| hassel && notEmpty sel
		// work on sel ...
		# sel			= map fst sel
		# mod			= hd sel
		# minf			= PR_GetModuleInfo mod project
		| isNothing minf
			= ps
		# minf			= fromJust minf
		# projco		= minf.compilerOptions
		# setco			= \co -> appProject (\l->PR_UpdateModules sel (\mi->{mi & compilerOptions = co}) l)
		= doCompilerOptionsDialog "Module Options" projco setco ps
	// work op nothing... ?!
	= ps

pm_coprefs :: !*(PSt *General) -> *PSt *General;
pm_coprefs ps
	# (prefs=:{compopts},ps) = getPrefs ps
	# setco = \co -> setPrefs {prefs & compopts = co}
	= doCompilerOptionsDialog "Module Defaults" compopts setco ps

getActiveModules ps
	#	(winpath,ps)		= sendToActiveWindow msgGetPathName ps
	| isNothing winpath
		# (winId,ps)		= accPIO getActiveWindow ps
		| isNothing winId
			= ([],ps)
		# winId				= fromJust winId
		# (pw,ps)			= isProjWin winId ps
		| not pw
			= ([],ps)
		# (lbId,ps)			= getPWI ps
		# ((hassel,sel),ps)	= getExtListBoxSelection lbId ps
		| hassel && notEmpty sel
			# sel			= [findIclModule s \\ (s,_) <- sel]
			# (sel,ps)		= seqList sel ps
			# sel			= [m \\ Just m <- sel]
			= (sel,ps)
		= ([],ps)
	#	winpath 			= fromJust winpath
	| IsImpPathname winpath
		= ([winpath],ps)
	| IsDefPathname winpath
		= ([MakeImpPathname winpath],ps)
	= ([],ps)

findIclModule :: !Modulename !*(PSt General) -> (!Maybe Pathname,!*PSt General)
findIclModule module_name ps
	# (srcpaths,ps) = get_project_and_environment_paths ps
	# ((ok,fullpath),ps) = accFiles (FindHModule module_name ".icl" srcpaths) ps
	| not ok
		= (Nothing, ps)
		= (Just (GetLongPathName fullpath), ps)

DoProcess msg compile cont ps
	# (paths,ps)			= getActiveModules ps
	# ps					= ed_ask_save_all False True (init paths) ps
	# ps					= mb_update_undoinfo ps
	= ps
where
	init paths ps
		#	(project,ps)		= getFromProject (\l->l) ps
			ps					= ew_safe_close ps
			ps					= tw_safe_close ps
		= okcont paths project ps	

	okcont [] project ps
		= final project ps
	okcont [path:paths] project ps	
		= compile path project (setproject path paths) ps
	
	setproject winpath paths ok newpaths newproject ps
		# modname				= GetModuleName winpath
		# ps					= cont winpath modname ok newpaths ps
		= okcont paths newproject ps
	
	final newproject ps
		# ps = closeInfo ps
		# ps = appProject (const newproject) ps
		# ps = pm_save ps
		# ps = pm_update_project_window ps
		= ps

pm_save_as :: !*(PSt *General) -> *PSt *General
pm_save_as ps
	# (pn,ps)	= selectOutputFile "Save Project as:" "*.prj" ps
	| isNothing pn
		= ps
	# pn		= fromJust pn
	# ps		= setProjectFilePath pn ps
	# ps		= pm_save ps
	# (recId,ps) = getPHI ps
	# (_,ps)	= syncSend2 recId pn ps
	# ps		= pm_set_window_title pn ps
	= pm_menu_add pn ps

pm_save_copy_as :: !*(PSt *General) -> *PSt *General
pm_save_copy_as ps
	# (pn,ps)	= selectOutputFile "Save copy of Project as:" "*.prj" ps
	| isNothing pn
		= ps
	# pn		= fromJust pn
	#	(project,ps)	= getFromProject (\l->l) ps
	# (project,ps)		= pm_save_common pn project ps
	#	ps				= appProject (const project) ps
	= ps

pm_save :: !*(PSt *General) -> *PSt *General
pm_save ps
	#	(project,ps)	= getFromProject (\l->l) ps
		(pathname,ps)	= getProjectFilePath ps
	# (project,ps) = pm_save_common pathname project ps
	#	project			= PR_SetSaved project
		ps				= appProject (const project) ps
	= ps

pm_save_common pathname project ps
	| pathname == ""
		= (project,ps)	// don't save dummy project...

	#	(startupdir,ps)	= getStup ps
		prjpath			= MakeProjectPathname pathname
		(ok,ps)			= accFiles (SaveProjectFile prjpath project startupdir) ps
	| not ok
		#	ps			= okNotice
							[ "The file "+++RemovePath prjpath+++" could not be saved because"
							, "of a file I/O error."
							] ps
		= (project,ps)
	# (prefs,ps)		= getPrefs ps
	= (project,ps)

pm_maybe_save :: !Id !*(PSt *General) -> (Bool,*PSt *General)
pm_maybe_save win ps
	// if win is project window -> save project
	# (wId,ps) = getPWW ps
	| wId == win
		= (True,pm_save ps)
	= (False,ps)

pm_save_project_as_template :: !*(PSt *General) -> *PSt *General
pm_save_project_as_template ps
	# (project,ps) = getProject ps
	| not (PR_ProjectSet project)
		= okNotice ["No open project"] ps
	# (pathname,ps)	= getProjectFilePath ps
	| size pathname==0
		= ps
	# (pn,ps) = selectOutputFile "Save Project Template:" "*.prt" ps
	= case pn of
		Nothing
			-> ps
		Just prt_path
			# (startupdir,ps) = getStup ps
			  (ok,ps) = accFiles (save_project_template_file prt_path project startupdir) ps
			| not ok
				-> okNotice	[ "The file "+++RemovePath prt_path+++" could not be saved because"
							, "of a file I/O error."] ps
				-> ps

pm_set_window_title :: .Title !*(PSt *General) -> *PSt *General;
pm_set_window_title pathname ps
	# (wId,ps) = getPWW ps
	# name = RemovePath pathname
	= appPIO (setWindowTitle wId (name+++" - "+++pathname)) ps

pm_get_projwin_possiz :: *(PSt *General) -> *(.(Vector2,Size),*PSt *General);
pm_get_projwin_possiz ps
	# (wId,ps)	= getPWW ps
	# (siz,ps)	= accPIO (getWindowViewSize wId) ps
	# (vec,ps)	= accPIO (getWindowPos wId) ps
	# vec		= fromJust vec
	= ((vec,siz),ps)

isProjWin :: !Id !*(PSt *General) -> (!Bool,!*PSt *General)
isProjWin win ps
	# (wId,ps) = getPWW ps
	= (wId == win,ps)

extKeyboard = ControlKeyboard keyFilter Able keyboard

keyFilter :: KeyboardState -> Bool
keyFilter (CharKey '+' _)  = True
keyFilter (CharKey '-' _)  = True
keyFilter _  = False

updFstate` l ps
	# (fstate,ps)	= getFstate ps
	# fstate		= foldl update fstate l
	# ps			= setFstate fstate ps
	= ps
where
	update [] (d, u)
		= [(u,d)]
	update [e=:(_,d`):fs] (d, u)
		| d == d` = [(u,d):fs]
		= [e:update fs (d, u)]

keyboard (CharKey '+' (KeyDown False)) ((lbState=:{tMargin,listboxId,selection,items,lineHeight,funs,shiftfuns},ls),ps)
		| not hasSelection
			= ((lbState,ls),ps)
		# (appPath,ps)	= getStup ps
		  (prjPath,ps) = getFromProject PR_GetRootDir ps
		# ps = updFstate` (map (\(p,b)-> (fulPath appPath prjPath p,b)) selItems) ps
		# ps = pm_update_project_window_interactive ps
		= ((lbState,ls),ps)
where
	nrItems		= length items
	customId	= listboxId.controlId
	hasSelection
		| isEmpty selection = False
		= True
	lastSelection = hd selection
	selItems = [(items!!(x-1)%(6,256),True) \\ x <- selection | items!!(x-1)%(0,5) == "//--- " || items!!(x-1)%(0,5) == "\\\\--- "]
keyboard (CharKey '-' (KeyDown False)) ((lbState=:{tMargin,listboxId,selection,items,lineHeight,funs,shiftfuns},ls),ps)
		| not hasSelection
			= ((lbState,ls),ps)
		# (appPath,ps)	= getStup ps
		  (prjPath,ps) = getFromProject PR_GetRootDir ps
		# ps = updFstate` (map (\(p,b)-> (fulPath appPath prjPath p,b)) selItems) ps
		# ps = pm_update_project_window_interactive ps
		= ((lbState,ls),ps)
where
	nrItems		= length items
	customId	= listboxId.controlId
	hasSelection
		| isEmpty selection = False
		= True
	lastSelection = hd selection
	selItems = [(items!!(x-1)%(6,256),False) \\ x <- selection | items!!(x-1)%(0,5) == "//--- " || items!!(x-1)%(0,5) == "\\\\--- "]
keyboard _ state
	= state
