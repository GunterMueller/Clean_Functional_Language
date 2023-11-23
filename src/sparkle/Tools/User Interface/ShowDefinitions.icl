/*
** Program: Clean Prover System
** Module:  ShowDefinitions (.icl)
** 
** Author:  Maarten de Mol
** Created: 28 February 2001
*/

implementation module
	ShowDefinitions

import
	StdEnv,
	StdIO,
	ossystem,
	MdM_IOlib,
	Operate,
	ShowDefinition,
	States
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
safeEq :: !ModulePtr !ModulePtr -> Bool
// ------------------------------------------------------------------------------------------------------------------------   
safeEq ptr1 ptr2
	| isNilPtr ptr1
		| isNilPtr ptr2
			= True
			= False
	| isNilPtr ptr2
		= False
		= ptr1 == ptr2

// ------------------------------------------------------------------------------------------------------------------------   
//DarkBG		:== RGB {r=230, g=190, b=40}
//DarkerBG	:== RGB {r=210, g=170, b=20}
//LightBG		:== RGB {r=250, g=210, b=60}
//LighterBG	:== RGB {r=240, g=200, b=50}

LightBlue	:== RGB {r=224, g=227, b=253}
MyGreen		:== RGB {r=  0, g=150, b= 75}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
:: FilterCommand =
// ------------------------------------------------------------------------------------------------------------------------   
	  ChangeModuleStatus	!ModulePtr				// nilPtr is predefined
	| AddAllModules
	| RemoveAllModules

// ------------------------------------------------------------------------------------------------------------------------   
showWith :: !String ![String] -> String
// ------------------------------------------------------------------------------------------------------------------------   
showWith sep [text:texts]
	| isEmpty texts 					= text
	= text +++ sep +++ showWith sep texts
showWith sep []
	= ""

// ------------------------------------------------------------------------------------------------------------------------   
separate :: !String -> [String]
// ------------------------------------------------------------------------------------------------------------------------   
separate text
	= find [] 0 (size text)
	where
		find :: ![Char] !Int !Int -> [String]
		find acc index max
			| index >= max				= case isEmpty acc of
											True	-> []
											False	-> [toString acc]
			# char						= text.[index]
			| char <> ' '				= find (acc ++ [char]) (index+1) max
			= case isEmpty acc of
				True	-> find [] (index+1) max
				False	-> [toString acc: find [] (index+1) max]





















// ------------------------------------------------------------------------------------------------------------------------
getDefinitions :: !DefinitionFilter !*PState -> (![DefinitionInfo], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
getDefinitions filter pstate
	# modules							= filter.dfModules
	# kind								= filter.dfKind
	# (_, ptrs, pstate)					= accErrorHeaps (getHeapPtrs modules [kind]) pstate
	# (_, infos, pstate)				= accErrorHeapsProject (uumapError getDefinitionInfo ptrs) pstate
	# infos								= [info \\ info <- infos | checkNameFilter filter.dfName info.diName]
	= case filter.dfKind of
		CFun	-> check_using infos pstate
		_		-> (infos, pstate)
	where
		check_using :: ![DefinitionInfo] !*PState -> (![DefinitionInfo], !*PState)
		check_using [info:infos] pstate
			# (infos, pstate)			= check_using infos pstate
			# (_, fun, pstate)			= accErrorProject (getFunDef info.diPointer) pstate
			# (using, pstate)			= accHeapsProject (IsUsing fun.fdBody filter.dfUsing) pstate
			= case using of
				True	-> ([info:infos], pstate)
				False	-> (infos, pstate)
		check_using [] pstate
			= ([], pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
getModuleNames :: ![ModulePtr] !*PState -> (![CName], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
getModuleNames [ptr:ptrs] pstate
	# (names, pstate)					= getModuleNames ptrs pstate
	| isNilPtr ptr						= (["_Predefined":names], pstate)
	# (name, pstate)					= accHeaps (getPointerName ptr) pstate
	= ([name:names], pstate)
getModuleNames []pstate
	= ([], pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showInfos :: !Colour !Bool ![DefinitionInfo] -> MarkUpText WindowCommand
// -------------------------------------------------------------------------------------------------------------------------------------------------
showInfos bg show_modules [info:infos]
	# (info_font, info_code)			= IconSymbol InfoIcon
	# (using_font, using_code)			= IconSymbol RecycleIcon
	# flinks							=	[ CmFontFace		info_font
											, CmLink2			1 {toChar info_code} (CmdShowDefinition info.diPointer)
											, CmEndFontFace
											, CmFontFace		using_font
											, CmLink2			1 {toChar using_code} (CmdShowDefinitionsUsing info.diPointer)
											, CmEndFontFace
											, CmSpaces 1
											]
	# ftext								=	[ CmBold
											, CmLink			info.diName (CmdShowDefinition info.diPointer)
											, CmEndBold
											]
	# fmodule							=	[ CmAlign			"@MODULE"
											, CmSize			7
											, CmColour			Grey
											, CmIText			(" (" +++ info.diModuleName +++ ")")
											, CmEndColour
											, CmEndSize
											]
	# frest								= showInfos bg show_modules infos
	= case show_modules of
		True	-> flinks ++ ftext ++ fmodule ++ [CmNewlineI False 1 (Just bg)] ++ frest
		False	-> flinks ++ ftext ++ [CmNewlineI False 1 (Just bg)] ++ frest
showInfos _ _ []
	= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
showNameFilter :: !NameFilter -> MarkUpText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
showNameFilter nf
	# ftext								= [CmBText "named ", CmBText {c \\ c <- nf.nfFilter}]
	| nf.nfPositive
		= ftext
		= [CmBText "not ": ftext]

// -------------------------------------------------------------------------------------------------------------------------------------------------
showFilter :: !Colour !DefinitionFilter !Int !*PState -> (!MarkUpText a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showFilter bg filter nr_defs pstate
	# kind_name							= toString filter.dfKind
	# kind_names						= if (kind_name == "class") "classes" (kind_name +++ "s")
	# kind_names						= "all " +++ kind_names
	# fkind								=	[ CmBText				"Showing: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmText				kind_names
											, CmIText				(" (" +++ toString nr_defs +++ ")")
											, CmFillLine
											, CmEndBackgroundColour
											]
	# (module_names, pstate)			= getModuleNames filter.dfModules pstate
	# module_names						= sort module_names
	# fmodules							=	[ CmRight
											, CmBText				"from: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmText				(showWith ", " module_names)
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fnamed							=	[ CmRight
											, CmBText				"named: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmColour				Red
											, CmBText				(if filter.dfName.nfPositive "" "not ")
											, CmEndColour
											, CmText				{c \\ c <- filter.dfName.nfFilter}
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fusing							= 	[ CmRight
											, CmBText				"using: "
											, CmAlign				"@RHS"
											, CmBackgroundColour	(changeColour 10 bg)
											, CmText				(showWith ", " filter.dfUsing)
											, CmFillLine
											, CmEndBackgroundColour
											]
	= (fkind ++ [CmNewlineI False 3 Nothing] ++ fmodules ++ [CmNewlineI False 3 Nothing] ++ fnamed ++ [CmNewlineI False 3 Nothing] ++ fusing ++ [CmNewlineI False 3 Nothing], pstate)
















// ------------------------------------------------------------------------------------------------------------------------   
showDefinitions :: !(Maybe Id) !(Maybe DefinitionFilter) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showDefinitions mb_id Nothing pstate
	# filter							= {dfModules = [], dfKind = CFun, dfName = {nfFilter = ['*'], nfPositive = True}, dfUsing = []}
	# (mb_filter, pstate)				= changeFilter filter pstate
	| isNothing mb_filter				= pstate
	= showDefinitions mb_id mb_filter pstate
showDefinitions mb_id (Just filter) pstate
	# (ids, pstate)						= pstate!ls.stUnregisteredWindows
	# (opened, id, pstate)				= already_opened ids pstate
	| opened							= setActiveWindow id pstate
	# (id, rid, pstate)					= new_UnregisteredWindow "DefinitionList" pstate
	# (extended_bg, pstate)				= pstate!ls.stDisplayOptions.optDefinitionListWindowBG
	# bg								= toColour 0 extended_bg
	# (window, pstate)					= theWindow bg filter id rid pstate
	# (_, pstate)						= openWindow filter window pstate
	= pstate
	where
		already_opened :: ![(Id, RId WindowCommand,String)] !*PState -> (!Bool, Id, !*PState)
		already_opened [(id,rid,_): ids] pstate
			| Just id == mb_id			= already_opened ids pstate
			# (_, pstate)				= syncSend rid (CmdCheckDefinitionFilter filter) pstate
			# (same, pstate)			= pstate!ls.stDuplicate
			| same						= (True, id, pstate)
			= already_opened ids pstate
		already_opened [] pstate
			= (False, undef, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
//theWindow :: !ExtendedColour !DefinitionFilter !Id !(RId WindowCommand) !*PState -> (_, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
theWindow bg filter id rid pstate
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (filter_rid, pstate)				= accPIO openRId pstate
	# (list_rid, pstate)				= accPIO openRId pstate
	# (sliders_bid, pstate)				= accPIO openButtonId pstate
	# (change_bid, pstate)				= accPIO openButtonId pstate
	# the_controls						= controls filter_rid list_rid sliders_bid change_bid metrics
	# (real_size, pstate)				= controlSize the_controls True (Just (5,5)) (Just (5,5)) (Just (5,5)) pstate
	# (pos, pstate)						= placeWindow real_size pstate
	=	( Window "List of definitions"
			the_controls
			[ WindowId					id
			, WindowClose				(noLS (close_UnregisteredWindow id))
			, WindowViewSize			real_size
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
			, WindowInit				(receive filter_rid list_rid sliders_bid change_bid CmdRefreshAlways)
			, WindowPos					(LeftTop, OffsetVector pos)
			]
		, pstate
		)
	where
		controls filter_rid list_rid sliders_bid change_bid metrics
			=		Receiver			rid (receive filter_rid list_rid sliders_bid change_bid)
											[]
				:+: MarkUpControl		[CmBText "?"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bg
											, MarkUpWidth				(302 + metrics.osmVSliderWidth)
											, MarkUpNrLinesI			4 9
											, MarkUpReceiver			filter_rid
											]
				  							[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
											]
				:+: boxedMarkUp			Black ResizeHorVer [CmIText "creating"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpWidth				300
											, MarkUpHeight				400
											, MarkUpBackgroundColour	(changeColour 20 bg)
											, MarkUpReceiver			list_rid
											, MarkUpLinkStyle			False Black (changeColour 20 bg) False Blue (changeColour 20 bg)
											, MarkUpLinkStyle			False (changeColour (-20) bg) (changeColour 20 bg) False Blue (changeColour 20 bg)
											, MarkUpEventHandler		(sendHandler rid)
											]
											[ ControlPos				(Left, zero)
											]
				:+: MarkUpButton		"change filter" bg (snd o asyncSend rid CmdChangeFilter) change_bid
											[ ControlPos				(Right, zero)
											]
				:+: MarkUpButton		"reset sliders" bg (redrawMarkUpSliders list_rid) sliders_bid
											[ ControlPos				(LeftBottom, zero)
											]
		
//		refresh :: _ _ !DefinitionFilter !*PState -> *PState
		refresh filter_rid list_rid filter pstate
			# (extended_bg, pstate)		= pstate!ls.stDisplayOptions.optDefinitionListWindowBG
			# bg						= toColour 0 extended_bg
			# (infos, pstate)			= getDefinitions filter pstate
			# infos						= sortBy (\i1 i2 -> i1.diName < i2.diName) infos
			# finfos					= showInfos bg (length filter.dfModules <> 1) infos
			# pstate					= changeMarkUpText list_rid finfos pstate
			# (ffilter, pstate)			= showFilter bg filter (length infos) pstate
			# pstate					= changeMarkUpText filter_rid ffilter pstate
			= pstate
				
//		receive :: _ _ _ _ !WindowCommand !(!DefinitionFilter, !*PState) -> (!DefinitionFilter, !*PState)
		receive filter_rid list_rid _ _ CmdRefreshAlways (filter, pstate)
			= (filter, refresh filter_rid list_rid filter pstate)
		receive filter_rid list_rid _ _ (CmdRefresh (RemovedCleanModules ptrs)) (filter, pstate)
			# (removed, modules)		= safe_remove filter.dfModules ptrs
			| not removed				= (filter, pstate)
			# filter					= {filter & dfModules = modules}
			= (filter, refresh filter_rid list_rid filter pstate)
			where
				safe_remove [ptr:ptrs] to_remove
					| isNilPtr ptr
						# (removed, ptrs)			= safe_remove ptrs to_remove
						= (removed, [ptr:ptrs])
					| isMember ptr to_remove
						# (_, ptrs)					= safe_remove ptrs to_remove
						= (True, ptrs)
					# (removed, ptrs)				= safe_remove ptrs to_remove
					= (removed, [ptr:ptrs])
				safe_remove [] to_remove
					= (False, [])
		receive filter_rid list_rid sliders_bid change_bid (CmdRefreshBackground old_bg new_bg) (filter, pstate)
			# new_look								= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate								= appPIO (setWindowLook id True (True, new_look)) pstate
			# pstate								= changeMarkUpColour filter_rid True old_bg new_bg pstate
			# pstate								= changeMarkUpColour filter_rid True (changeColour 10 old_bg) (changeColour 10 new_bg) pstate
			# pstate								= changeMarkUpColour list_rid False old_bg new_bg pstate
			# pstate								= changeMarkUpColour list_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate								= changeMarkUpColour list_rid False (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate								= changeMarkUpColour (snd3 sliders_bid) True old_bg new_bg pstate
			# pstate								= changeMarkUpColour (snd3 change_bid) True old_bg new_bg pstate
			= (filter, refresh filter_rid list_rid filter pstate)
		
		receive filter_rid list_rid _ _ CmdChangeFilter (filter, pstate)
			# (mb_filter, pstate)		= changeFilter filter pstate
			| isNothing mb_filter		= (filter, pstate)
			# filter					= fromJust mb_filter
			# pstate					= refresh filter_rid list_rid filter pstate
			= (filter, pstate)
		receive _ _ _ _ (CmdCheckDefinitionFilter filter1) (filter2, pstate)
			# pstate					= {pstate & ls.stDuplicate = filter1 == filter2}
			= (filter2, pstate)
		receive _ _ _ _ (CmdShowDefinition ptr) (filter, pstate)
			= (filter, showDefinition ptr pstate)
		receive _ _ _ _ (CmdShowDefinitionsUsing ptr) (filter, pstate)
			# (modules, pstate)			= pstate!ls.stProject.prjModules
			# name_filter				= {nfFilter = ['*'], nfPositive = True}
			# (_, name, pstate)			= accErrorHeapsProject (getDefinitionName ptr) pstate
			# new_filter				= {dfKind = CFun, dfModules = [nilPtr:modules], dfName = name_filter, dfUsing = [name]}
			= (filter, showDefinitions (Just id) (Just new_filter) pstate)
		receive _ _ _ _ command (filter, pstate)
			= (filter, pstate)































// ------------------------------------------------------------------------------------------------------------------------   
changeFilter :: !DefinitionFilter !*PState -> (!Maybe DefinitionFilter, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
changeFilter filter pstate
	# bgcolour							= getDialogBackgroundColour
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (dialog_id, pstate)				= accPIO openId pstate
	# (dialog_rid, pstate)				= accPIO openRId pstate
	# (kinds_id, pstate)				= accPIO openId pstate
	# (modules_id, pstate)				= accPIO openId pstate
	# (modules_rid, pstate)				= accPIO openRId pstate
	# (name_id, pstate)					= accPIO openId pstate
	# (positive_id, pstate)				= accPIO openId pstate
	# (using_id, pstate)				= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	# (fmodules, pstate)				= showModules filter pstate
	# dialog							= filter_dialog dialog_id dialog_rid kinds_id modules_id modules_rid name_id positive_id using_id ok_id cancel_id fmodules bgcolour metrics
	# ((_,mb_mb_filter), pstate)		= openModalDialog (Just filter) dialog pstate
	= case mb_mb_filter of
		Nothing			-> (Nothing, pstate)
		Just mb_filter	-> (mb_filter, pstate)
	where
		filter_dialog dialog_id dialog_rid kinds_id modules_id modules_rid name_id positive_id using_id ok_id cancel_id fmodules bgcolour metrics
			= Dialog "Change definition filter"
				(		Receiver		dialog_rid (receive modules_rid)
											[]
					:+: MarkUpControl	[CmBText "Showing:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[]
					:+: PopUpControl	[("all algebraic types",		setKind CAlgType using_id),
										 ("all classes", 				setKind CClass using_id),
										 ("all class instances",		setKind CInstance using_id),
										 ("all class members",			setKind CMember using_id),
										 ("all data-constructors",		setKind CDataCons using_id),
										 ("all functions",				setKind CFun using_id),
										 ("all record fields",			setKind CRecordField using_id),
										 ("all record types",			setKind CRecordType using_id)]
										 	(def_index filter.dfKind)
										 	[ ControlId					kinds_id
										 	, ControlWidth				(PixelWidth (300+metrics.osmVSliderWidth+2))
										 	]
					:+: MarkUpControl	[ CmRight
										, CmBText						"from:"
										, CmAlign						"@END"
										, CmNewline
										, CmRight
										, CmSize						8
										, CmText						"["
										, CmLink						"add all" AddAllModules
										, CmText						"]"
										, CmAlign						"@END"
										, CmNewline
										, CmRight
										, CmText						"["
										, CmLink						"remove all" RemoveAllModules
										, CmText						"]"
										, CmAlign						"@END"
										, CmEndSize
										]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											, MarkUpLinkStyle			False DarkGrey bgcolour False Blue bgcolour
											, MarkUpEventHandler		(clickHandler (\cmd state -> snd (asyncSend dialog_rid cmd state)))
											]
											[ ControlPos				(LeftOf modules_id, zero)
											]
					:+: boxedMarkUp		Black DoNotResize fmodules
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	White
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpWidth				300
											, MarkUpHeight				400
											, MarkUpLinkStyle			False Black LightBlue False Blue LightBlue
											, MarkUpLinkStyle			False Black White False Blue White
											, MarkUpReceiver			modules_rid
											, MarkUpEventHandler		(clickHandler (\cmd state -> snd (asyncSend dialog_rid cmd state)))
											]
											[ ControlPos				(Below kinds_id, zero)
											, ControlId					modules_id
											]
					:+: MarkUpControl	[CmBText "named:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf name_id, zero)
											]
					:+: EditControl		{c \\ c <- filter.dfName.nfFilter} (PixelWidth (300+metrics.osmVSliderWidth+2)) 1
											[ ControlPos				(Below modules_id, zero)
											, ControlId					name_id
											]
					:+:	MarkUpControl	[CmBText "mode:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf positive_id, zero)
											]
					:+:	PopUpControl	[("positive (all that pass the name filter)", id),
										 ("negative (all that do NOT pass the name filter)",id)] (if filter.dfName.nfPositive 1 2)
										 	[ ControlPos				(Below name_id, zero)
										 	, ControlId					positive_id
										 	, ControlWidth				(PixelWidth (300+metrics.osmVSliderWidth+2))
										 	]
					:+:	MarkUpControl	[CmBText "using:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	bgcolour
											]
											[ ControlPos				(LeftOf using_id, zero)
											]
					:+:	EditControl		(showWith " " filter.dfUsing) (PixelWidth (300+metrics.osmVSliderWidth+2)) 1
											[ ControlPos				(Below positive_id, zero)
											, ControlId					using_id
											]
					:+: ButtonControl	"Ok"
											[ ControlId					ok_id
											, ControlPos				(Right, zero)
											, ControlFunction			(accept dialog_id name_id positive_id using_id)
											]
					:+: ButtonControl	"Cancel"
											[ ControlId					cancel_id
											, ControlPos				(LeftOf ok_id, zero)
											, ControlFunction			(refuse dialog_id)
											, ControlHide
											]
				)
				[ WindowId				dialog_id
				, WindowClose			(refuse dialog_id)
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		def_index :: !DefinitionKind -> Index
		def_index CAlgType				= 1
		def_index CClass				= 2
		def_index CInstance				= 3
		def_index CMember				= 4
		def_index CDataCons				= 5
		def_index CFun					= 6
		def_index CRecordType			= 7
		def_index CRecordField			= 8
		
		setKind :: !DefinitionKind !Id !(!Maybe DefinitionFilter, !*PState) -> (!Maybe DefinitionFilter, !*PState)
		setKind kind using_id (Just filter, pstate)
			# pstate					= case kind of
											CFun	-> appPIO (enableControl using_id) pstate
											_		-> appPIO (disableControl using_id) pstate
			= (Just {filter & dfKind = kind}, pstate)
		
		refuse :: !Id !(!Maybe DefinitionFilter, !*PState) -> (!Maybe DefinitionFilter, !*PState)
		refuse dialog_id (_, pstate)
			= (Nothing, closeWindow dialog_id pstate)
		
		accept :: !Id !Id !Id !Id !(!Maybe DefinitionFilter, !*PState) -> (!Maybe DefinitionFilter, !*PState)
		accept dialog_id name_id positive_id using_id (Just filter, pstate)
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= (Just filter, pstate)
			# wstate					= fromJust mb_wstate
			# (ok, mb_text)				= getControlText name_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_text			= (Just filter, pstate)
			# named						= fromJust mb_text
			# (ok, mb_index)			= getPopUpControlSelection positive_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_index		= (Just filter, pstate)
			# positive_index			= fromJust mb_index
			# (ok, mb_text)				= getControlText using_id wstate
			| not ok					= (Just filter, pstate)
			| isNothing mb_text			= (Just filter, pstate)
			# using						= case filter.dfKind of
											CFun	-> sort (separate (fromJust mb_text))
											_		-> []
			# filter					= {filter	& dfName.nfFilter		= [c \\ c <-: named]
													, dfName.nfPositive		= (positive_index == 1)
													, dfUsing				= using
										  }
//			# pstate					= snd (asyncSend window_rid (CmdSetDefinitionFilter filter) pstate)
			= (Just filter, closeWindow dialog_id pstate)
		
		receive :: !(RId (MarkUpMessage FilterCommand)) !FilterCommand !(!Maybe DefinitionFilter, !*PState) -> (!Maybe DefinitionFilter, !*PState)
		receive modules_rid (ChangeModuleStatus ptr) (Just filter, pstate)
			# modules					= change ptr filter.dfModules
			# filter					= {filter & dfModules = modules}
			# (fmodules, pstate)		= showModules filter pstate
			# pstate					= changeMarkUpText modules_rid fmodules pstate
			= (Just filter, pstate)
			where
				change :: !ModulePtr ![ModulePtr] -> [ModulePtr]
				change mod_ptr [ptr:ptrs]
					| safeEq mod_ptr ptr
						= ptrs
						= [ptr: change mod_ptr ptrs]
				change mod_ptr []
					= [mod_ptr]
		receive modules_rid AddAllModules (Just filter, pstate)
			# (all_modules, pstate)		= pstate!ls.stProject.prjModules
			# filter					= {filter & dfModules = [nilPtr: all_modules]}
			# (fmodules, pstate)		= showModules filter pstate
			# pstate					= changeMarkUpText modules_rid fmodules pstate
			= (Just filter, pstate)
		receive modules_rid RemoveAllModules (Just filter, pstate)
			# filter					= {filter & dfModules = []}
			# (fmodules, pstate)		= showModules filter pstate
			# pstate					= changeMarkUpText modules_rid fmodules pstate
			= (Just filter, pstate)
		receive modules_rid change (Just filter, pstate)
			= (Just filter, pstate)
		
		showModules :: !DefinitionFilter !*PState -> (!MarkUpText FilterCommand, !*PState)
		showModules filter pstate
			# (predef, in_ptrs)			= disect filter.dfModules
			# (all_ptrs, pstate)		= pstate!ls.stProject.prjModules
			# (module_infos, pstate)	= show all_ptrs in_ptrs pstate
			# module_infos				= sortBy (\(n1,_)(n2,_) -> n1 < n2) module_infos
			# predef_info				= case predef of
											True	->	[ CmBackgroundColour	LightBlue
														, CmColour				MyGreen
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				0 "_Predefined" (ChangeModuleStatus nilPtr)
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI			False 1 Nothing
														]
											False	->	[ CmColour				White
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				1 "_Predefined" (ChangeModuleStatus nilPtr)
														, CmNewlineI			False 1 Nothing
														]
			# module_infos				= [("A",predef_info):module_infos]
			= (flatten (map snd module_infos), pstate)
			where
				disect :: ![ModulePtr] -> (!Bool, ![ModulePtr])
				disect [ptr:ptrs]
					# (predef, ptrs)	= disect ptrs
					| isNilPtr ptr		= (True, ptrs)
					= (predef, [ptr:ptrs])
				disect []
					= (False, [])
				
				show :: ![ModulePtr] ![ModulePtr] !*PState -> (![(CName, MarkUpText FilterCommand)], !*PState)
				show [ptr:ptrs] in_ptrs pstate
					# (name, pstate)	= accHeaps (getPointerName ptr) pstate
					# fmodule			= case isMember ptr in_ptrs of
											True	->	[ CmBackgroundColour	LightBlue
														, CmColour				MyGreen
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				0 name (ChangeModuleStatus ptr)
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI			False 1 Nothing
														]
											False	->	[ CmColour				White
														, CmFontFace			"Wingdings"
														, CmBText				{toChar 252}
														, CmEndFontFace
														, CmEndColour
														, CmText				" "
														, CmLink2				1 name (ChangeModuleStatus ptr)
														, CmNewlineI			False 1 Nothing
														]
					# info				= (name, fmodule)
					# (infos, pstate)	= show ptrs in_ptrs pstate
					= ([info:infos], pstate)
				show [] _ pstate
					= ([], pstate)