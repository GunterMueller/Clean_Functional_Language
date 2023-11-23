/*
** Program: Clean Prover System
** Module:  ProjectCenter (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 February 2001
*/

implementation module
	ProjectCenter

import
	StdEnv,
	StdIO,
	ossystem,
	Depends,
	OpenProject,
	States,
	AddModule,
	RemoveModules,
	ShowModule,
	ShowDefinitions
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
openProjectCenter :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
openProjectCenter pstate
	# (opened, pstate)						= isWindowOpened WinProjectCenter True pstate
	| opened								= pstate
	# (menubar, pstate)						= pstate!ls.stMenuBarCreated
	# pstate								= case menubar of
												True	-> let (menu_id, pstate1) = pstate!ls.stMenus.project_center_id
															in appPIO (markMenuItems [menu_id]) pstate1
												False	-> pstate
	# (winfo, pstate)						= new_Window WinProjectCenter pstate
	# pos									= winfo.wiStoredPos
	# width									= winfo.wiStoredWidth
	# height								= winfo.wiStoredHeight
	# window_id								= winfo.wiWindowId
	# window_rid							= fromJust winfo.wiNormalRId
	# (header_rid, pstate)					= accPIO openRId pstate
	# list_id								= fromJust winfo.wiControlId
	# (list_rid, pstate)					= accPIO openRId pstate
	# (module_id, pstate)					= accPIO openButtonId pstate
	# (project_id, pstate)					= accPIO openButtonId pstate
	# (remove_id, pstate)					= accPIO openButtonId pstate
	# (remove_all_id, pstate)				= accPIO openButtonId pstate
	# (extended_bg, pstate)					= pstate!ls.stDisplayOptions.optProjectCenterBG
	# bg									= toColour 0 extended_bg
	# control_bg							= toColour 20 extended_bg
	# icon_fg								= toColour (-20) extended_bg
	= showProjectCenter pos width height window_id window_rid header_rid list_id list_rid module_id project_id remove_id remove_all_id bg control_bg icon_fg pstate

// ------------------------------------------------------------------------------------------------------------------------   
// showProjectCenter :: !Vector2 !Int !Int !Id _ !Id _ !ButtonId !ButtonId !ButtonId !ButtonId !Colour !Colour !Colour !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
showProjectCenter pos width height window_id window_rid header_rid list_id list_rid module_id remove_id remove_all_id project_id bg control_bg icon_fg pstate
	# (modules, pstate)						= pstate!ls.stProject.prjModules
	# (fmodules, pstate)					= accHeaps (showModules bg control_bg icon_fg modules) pstate
	# the_control							= controls fmodules (isEmpty modules)
	# (real_size, pstate)					= controlSize the_control True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)							= case (pos.vx == (-1) && pos.vy == (-1)) of
												True	-> placeWindow real_size pstate
												False	-> (pos, pstate)
	= snd (openWindow Nothing (window real_size the_control) pstate)
	where
		controls fmodules empty
			=		Receiver				window_rid receive
												[]
				:+:	MarkUpControl			[CmBText "Clean modules loaded:"]
												[ MarkUpBackgroundColour			bg
												, MarkUpFontFace					"Times New Roman"
												, MarkUpTextSize					10
												, MarkUpReceiver					header_rid
												]
												[]
				:+:	boxedMarkUp				Black ResizeHorVer fmodules
												[ MarkUpWidth						width
												, MarkUpHeight						height
												, MarkUpHScroll
												, MarkUpVScroll
												, MarkUpReceiver					list_rid
												, MarkUpBackgroundColour			control_bg
												, MarkUpFontFace					"Times New Roman"
												, MarkUpTextSize					10
												, MarkUpLinkStyle					False icon_fg control_bg False Blue control_bg
												, MarkUpLinkStyle					False icon_fg control_bg False Red control_bg
												, MarkUpLinkStyle					False Black control_bg False Blue control_bg
												, MarkUpEventHandler				(clickHandler (click_handler window_rid))
												]
												[ ControlPos						(Left, zero)
					  							, ControlId							list_id
												]
				:+:	MarkUpButton			"open project" bg (catchError openProject) project_id
												[ ControlPos						(Right, zero)
												, ControlSelectState				(if empty Able Unable)
												]
				:+:	MarkUpButton			"add module" bg addModule module_id
												[ ControlPos						(LeftOf (fst3 project_id), zero)
												]
				:+:	MarkUpButton			"remove modules" bg (removeModules False []) remove_id
												[ ControlPos						(Right, zero)
												, ControlSelectState				(if empty Unable Able)
												]
				:+:	MarkUpButton			"remove all" bg remove_all remove_all_id
												[ ControlPos						(LeftOf (fst3 remove_id), zero)
												, ControlSelectState				(if empty Unable Able)
												]
		
		window real_size the_control
			# (metrics, _)					= osDefaultWindowMetrics 42
			= Window "Project Center" the_control
					[ WindowId				window_id
					, WindowHMargin			5 5
					, WindowVMargin			5 5
					, WindowItemSpace		5 5
					, WindowViewSize		{real_size & w = width + 2 + metrics.osmVSliderWidth + 10}
					, WindowPos				(LeftTop, OffsetVector pos)
					, WindowLook			True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
					, WindowClose			(noLS (close_Window WinProjectCenter))
					, WindowMouse			(\x -> True) Able (mouse_function list_rid)
					]

		mouse_function rid _ (lstate, pstate)
			#! pstate					= deactiveMarkUp rid pstate
			= (lstate, pstate)
		
		click_handler :: !(RId WindowCommand) !WindowCommand !*PState -> *PState
		click_handler window_rid command pstate
			= snd (asyncSend window_rid command pstate)
		
		remove_all :: !*PState -> *PState
		remove_all pstate
			# (ptrs, pstate)				= pstate!ls.stProject.prjModules
			= removeModules True ptrs pstate
		
		refresh :: !*PState -> *PState
		refresh pstate
			# (extended_bg, pstate)			= pstate!ls.stDisplayOptions.optProjectCenterBG
			# bg							= toColour 0 extended_bg
			# control_bg					= toColour 20 extended_bg
			# icon_fg						= toColour (-20) extended_bg
			# (modules, pstate)				= pstate!ls.stProject.prjModules
			# (fmodules, pstate)			= accHeaps (showModules bg control_bg icon_fg modules) pstate
			# pstate						= changeMarkUpText list_rid fmodules pstate
			= case (isEmpty modules) of
				True	-> disableButtons [remove_id, remove_all_id] (enableButton project_id pstate)
				False	-> enableButtons [remove_id, remove_all_id] (disableButton project_id pstate)
		
		receive CmdRefreshAlways (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (AddedCleanModules mods)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (RemovedCleanModules mods)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefreshBackground old_bg new_bg) (lstate, pstate)
			# new_look						= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate						= appPIO (setWindowLook window_id True (True, new_look)) pstate
			# pstate						= changeMarkUpColour header_rid True old_bg new_bg pstate
			# pstate						= changeMarkUpColour list_rid False old_bg new_bg pstate
			# pstate						= changeMarkUpColour list_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate						= changeMarkUpColour list_rid False (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate						= changeMarkUpColour (snd3 project_id) True old_bg new_bg pstate
			# pstate						= changeMarkUpColour (snd3 module_id) True old_bg new_bg pstate
			# pstate						= changeMarkUpColour (snd3 remove_id) True old_bg new_bg pstate
			# pstate						= changeMarkUpColour (snd3 remove_all_id) True old_bg new_bg pstate
			= (lstate, refresh pstate)
		
		receive (CmdRemoveModule ptr) (lstate, pstate)
			= (lstate, removeModules True [ptr] pstate)
		receive (CmdShowModule mb_ptr) (lstate, pstate)
			= (lstate, showModule mb_ptr pstate)
		receive (CmdShowModuleContents Nothing) (lstate, pstate)
			# filter						= {dfKind = CFun, dfName = {nfPositive = True, nfFilter = ['*']}, dfModules = [nilPtr], dfUsing = []}
			= (lstate, showDefinitions Nothing (Just filter) pstate)
		receive (CmdShowModuleContents (Just ptr)) (lstate, pstate)
			# filter						= {dfKind = CFun, dfName = {nfPositive = True, nfFilter = ['*']}, dfModules = [ptr], dfUsing = []}
			= (lstate, showDefinitions Nothing (Just filter) pstate)
		receive msg (lstate,pstate)
			= (lstate, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
showModules :: !Colour !Colour !Colour ![ModulePtr] !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// ------------------------------------------------------------------------------------------------------------------------   
showModules bg control_bg icon_fg modules heaps
	# info_link								= {iiIcon = InfoIcon, iiLinkStyle = 0, iiCommand = CmdShowModule o Just}
	# view_contents_link					= {iiIcon = ViewContentsIcon, iiLinkStyle = 0, iiCommand = CmdShowModuleContents o Just}
	# remove_link							= {iiIcon = RemoveIcon, iiLinkStyle = 1, iiCommand = CmdRemoveModule}
	# (fmodules, heaps)						= showIconList1 modules [info_link,view_contents_link] show [remove_link] icon_fg heaps
	# (info_font, info_code)				= IconSymbol InfoIcon
	# (view_font, view_code)				= IconSymbol ViewContentsIcon
	# (remove_font, remove_code)			= IconSymbol RemoveIcon
	# fpredefined							= [CmFontFace info_font, CmLink2 0 {toChar info_code} (CmdShowModule Nothing), CmEndFontFace] ++
											  [CmFontFace view_font, CmLink2 0 {toChar view_code} (CmdShowModuleContents Nothing), CmEndFontFace] ++
											  [CmSpaces 1] ++ [CmBold, CmLink2 2 "_Predefined" (CmdShowModuleContents Nothing), CmEndBold, CmAlign "@ICONS2", CmSpaces 1] ++
											  [CmFontFace remove_font, CmColour LightGrey, CmText {toChar remove_code}, CmEndColour, CmEndFontFace, CmNewlineI False 1 (Just icon_fg)]
	= (fpredefined ++ fmodules, heaps)
	where
		show ptr mod
			= [CmBold, CmLink2 2 mod.pmName (CmdShowModuleContents (Just ptr)), CmEndBold]