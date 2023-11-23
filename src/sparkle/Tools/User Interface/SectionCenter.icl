/*
** Program: Clean Prover System
** Module:  SectionCenter (.icl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2001
*/

implementation module
	SectionCenter

import 
	StdEnv,
	StdIO,
	MdM_IOlib,
	Depends,
	Hints,
	NewTheorem,
	States,
	ShowSection,
	ShowTheorems,
	StoreSection,
	ossystem
from StdFunc import seq

// -------------------------------------------------------------------------------------------------------------------------------------------------
openSectionCenter :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
openSectionCenter pstate
	# (opened, pstate)					= isWindowOpened WinSectionCenter True pstate
	| opened							= pstate
	# (menubar, pstate)					= pstate!ls.stMenuBarCreated
	# pstate							= case menubar of
											True	-> let (menu_id, pstate1) = pstate!ls.stMenus.section_center_id
														in appPIO (markMenuItems [menu_id]) pstate1
											False	-> pstate
	# (winfo, pstate)					= new_Window WinSectionCenter pstate
	# window_id							= winfo.wiWindowId
	# window_rid						= fromJust winfo.wiNormalRId
	# window_pos						= winfo.wiStoredPos
	# window_width						= winfo.wiStoredWidth
	# window_height						= winfo.wiStoredHeight
	# (header_rid, pstate)				= accPIO openRId pstate
	# list_id							= fromJust winfo.wiControlId
	# (list_rid, pstate)				= accPIO openRId pstate
	# (new_id, pstate)					= accPIO openButtonId pstate
	# (load_id, pstate)					= accPIO openButtonId pstate
	# (theorem_id, pstate)				= accPIO openButtonId pstate
	# (unproved_id, pstate)				= accPIO openButtonId pstate
	# (extended_bg, pstate)				= pstate!ls.stDisplayOptions.optSectionCenterBG
	# bg								= toColour 0 extended_bg
	# control_bg						= toColour 20 extended_bg
	# icon_fg							= toColour (-20) extended_bg
	= showSectionCenter window_id window_rid header_rid list_id list_rid new_id load_id theorem_id unproved_id window_pos window_width window_height bg control_bg icon_fg pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
showSectionCenter :: !Id !(RId WindowCommand) !MarkUpRId !Id !MarkUpRId !ButtonId !ButtonId !ButtonId !ButtonId !Vector2 !Int !Int !Colour !Colour !Colour !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
showSectionCenter id rid header_rid list_id list_rid new_id load_id theorem_id unproved_id pos width height bg control_bg icon_fg pstate
	# (ptrs, pstate)					= pstate!ls.stSections
	# (fsections, pstate)				= accHeaps (showSections bg ptrs) pstate
	# (real_size, pstate)				= controlSize (controls fsections) True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)						= case (pos.vx == (-1) && pos.vy == (-1)) of
											True	-> placeWindow real_size pstate
											False	-> (pos, pstate)
	= snd (openWindow Nothing (window real_size fsections) pstate)
	where
		window real_size fsections
			# (metrics, _)				= osDefaultWindowMetrics 42
			= Window "Section Center" (controls fsections)
				[ WindowId				id
				, WindowClose			(noLS (close_Window WinSectionCenter))
				, WindowPos				(LeftTop, OffsetVector pos)
				, WindowViewSize		{real_size & w = width + 2 + metrics.osmVSliderWidth + 10}
				, WindowHMargin			5 5
				, WindowVMargin			5 5
				, WindowItemSpace		5 5
				, WindowLook			True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
				, WindowMouse			(\x -> True) Able (mouse_function list_rid)
				]
		
		controls fsections
			=		Receiver			rid receive
											[]
				:+:	MarkUpControl		[CmBText "Theorem sections loaded:"]
											[ MarkUpBackgroundColour		bg
											, MarkUpFontFace				"Times New Roman"
											, MarkUpTextSize				10
											, MarkUpReceiver				header_rid
											]
											[]
				:+:	boxedMarkUp			Black ResizeHorVer fsections
											[ MarkUpBackgroundColour		control_bg
											, MarkUpFontFace				"Times New Roman"
											, MarkUpTextSize				10
											, MarkUpWidth					width
											, MarkUpHeight					height
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpLinkStyle				False Black control_bg False Blue control_bg
											, MarkUpLinkStyle				False icon_fg control_bg False Blue control_bg
											, MarkUpLinkStyle				False icon_fg control_bg False Green control_bg
											, MarkUpLinkStyle				False icon_fg control_bg False Red control_bg
											, MarkUpEventHandler			(sendHandler rid)
											, MarkUpReceiver				list_rid
											]
											[ ControlPos					(Left, zero)
											, ControlId						list_id
											]
				:+:	MarkUpButton		"new section" bg newSection new_id
											[ ControlPos					(Right, zero)
											]
				:+:	MarkUpButton		"load section" bg (restoreSection Nothing) load_id
											[ ControlPos					(LeftOf (fst3 new_id), zero)
											]
				:+:	MarkUpButton		"new theorem" bg newTheorem theorem_id
											[ ControlPos					(Right, zero)
											]
				:+:	MarkUpButton		"unproved" bg (globalEventHandler CmdShowUnprovedTheorems) unproved_id
											[ ControlPos					(LeftBottom, zero)
											]
		
		mouse_function rid _ (lstate, pstate)
			#! pstate					= deactiveMarkUp rid pstate
			= (lstate, pstate)
		
		refresh :: !*PState -> *PState
		refresh pstate
			# (extended_bg, pstate)				= pstate!ls.stDisplayOptions.optSectionCenterBG
			# bg								= toColour 0 extended_bg
			# (ptrs, pstate)					= pstate!ls.stSections
			# (fsections, pstate)				= accHeaps (showSections bg ptrs) pstate
			# pstate							= changeMarkUpText list_rid fsections pstate
			= pstate
		
		receive :: !WindowCommand !(a, !*PState) -> (a, !*PState)
		receive (CmdRefresh CreatedSection) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (CreatedTheorem _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (MovedTheorem _ _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (RemovedSection _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (RemovedTheorem _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefresh (RenamedSection _)) (lstate, pstate)
			= (lstate, refresh pstate)
		receive CmdRefreshAlways (lstate, pstate)
			= (lstate, refresh pstate)
		receive (CmdRefreshBackground old_bg new_bg) (lstate, pstate)
			# new_look							= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate							= appPIO (setWindowLook id True (True, new_look)) pstate
			# pstate							= changeMarkUpColour header_rid True old_bg new_bg pstate
			# pstate							= changeMarkUpColour list_rid False old_bg new_bg pstate
			# pstate							= changeMarkUpColour list_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate							= changeMarkUpColour list_rid False (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate							= changeMarkUpColour (snd3 new_id) True old_bg new_bg pstate
			# pstate							= changeMarkUpColour (snd3 load_id) True old_bg new_bg pstate
			# pstate							= changeMarkUpColour (snd3 theorem_id) True old_bg new_bg pstate
			# pstate							= changeMarkUpColour (snd3 unproved_id) True old_bg new_bg pstate
			= (lstate, refresh pstate)
		
		receive (CmdRemoveSection ptr) (lstate, pstate)
			# (removed, pstate)					= removeSection ptr pstate
			= case removed of
				True	-> (lstate, refresh pstate)
				False	-> (lstate, pstate)
		receive (CmdRenameSection ptr) (lstate, pstate)
			# pstate							= renameSection ptr pstate
			= (lstate, pstate)
		receive (CmdSaveSection ptr) (lstate, pstate)
			= (lstate, storeSection ptr pstate)
		receive (CmdShowSectionContents ptr) (lstate, pstate)
			# filter							= {tfSections = [ptr], tfName = {nfPositive = True, nfFilter = ['*']}, tfUsing = [], tfStatus = DontCare}
			= (lstate, showTheorems True (Just filter) pstate)
		receive command (lstate, pstate)
			= (lstate, pstate)
		
// -------------------------------------------------------------------------------------------------------------------------------------------------
showSections :: !Colour ![SectionPtr] !*CHeaps -> (!MarkUpText WindowCommand, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showSections bg ptrs heaps
	# view_contents_icon						= {iiIcon = ViewContentsIcon, iiLinkStyle = 1, iiCommand = CmdShowSectionContents}
	# rename_icon								= {iiIcon = RenameIcon, iiLinkStyle = 1, iiCommand = CmdRenameSection}
	# save_icon									= {iiIcon = SaveIcon, iiLinkStyle = 2, iiCommand = CmdSaveSection}
	# remove_icon								= {iiIcon = RemoveIcon, iiLinkStyle = 3, iiCommand = CmdRemoveSection}
	# (fsections, heaps)						= showIconList1 ptrs [view_contents_icon] show [rename_icon, save_icon, remove_icon] bg heaps
	= (fsections, heaps)
	where
		show :: !SectionPtr !Section -> MarkUpText WindowCommand
		show ptr section
			= [CmBold, CmLink section.seName (CmdShowSectionContents ptr), CmEndBold, CmItalic, CmText "(", CmText (toString (length section.seTheorems)), CmText ")", CmEndItalic]

// -------------------------------------------------------------------------------------------------------------------------------------------------
renameSection :: !SectionPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
renameSection ptr pstate
	# (section, pstate)					= accHeaps (readPointer ptr) pstate
	| section.seName == "main"			= showError [X_Internal "May not change name of main section"] pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	= snd (openModalDialog 0 (dialog section.seName dialog_id edit_id ok_id cancel_id) pstate)
	where
		dialog old_name dialog_id edit_id ok_id cancel_id
			= Dialog "Rename Section"
				(     MarkUpControl		[CmText "Rename section ", CmBText old_name, CmText " to"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	getDialogBackgroundColour
											]
											[]
				  :+: EditControl		old_name (PixelWidth 120) 1
				  							[ ControlId			edit_id
				  							]
				  :+: ButtonControl		"Ok"
				  							[ ControlPos		(Right, zero)
				  							, ControlId			ok_id
				  							, ControlFunction	(noLS (accept dialog_id edit_id))
				  							]
				  :+: ButtonControl		"Cancel"
				  							[ ControlPos		(LeftOf ok_id, zero)
				  							, ControlId			cancel_id
				  							, ControlFunction	(noLS (closeWindow dialog_id))
//				  							, ControlHide
				  							]
				)
				[ WindowId				dialog_id
				, WindowClose			(noLS (closeWindow dialog_id))
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		accept :: !Id !Id !*PState -> *PState
		accept dialog_id edit_id pstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= pstate
			# wstate					= fromJust mb_wstate
			# (ok, mb_text)				= getControlText edit_id wstate
			| not ok					= pstate
			| isNothing mb_text			= pstate
			# text						= fromJust mb_text
			| text == ""				= setActiveControl edit_id pstate
			| text == "main"			= setActiveControl edit_id (showError [X_Internal "May not name another section 'main'"] pstate)
			# (section, pstate)			= accHeaps (readPointer ptr) pstate
			# section					= {section & seName = text}
			# pstate					= appHeaps (writePointer ptr section) pstate
			# pstate					= broadcast Nothing (RenamedSection ptr) pstate
			= closeWindow dialog_id pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
newSection :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
newSection pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	= snd (openModalDialog 0 (dialog dialog_id edit_id ok_id cancel_id) pstate)
	where
		dialog dialog_id edit_id ok_id cancel_id
			= Dialog "New Section"
				(     MarkUpControl		[CmText "Give a name for the new section:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	getDialogBackgroundColour
											]
											[]
				  :+: EditControl		"" (PixelWidth 120) 1
				  							[ ControlId			edit_id
				  							]
				  :+: ButtonControl		"Ok"
				  							[ ControlPos		(Right, zero)
				  							, ControlId			ok_id
				  							, ControlFunction	(noLS (accept dialog_id edit_id))
				  							]
				  :+: ButtonControl		"Cancel"
				  							[ ControlPos		(LeftOf ok_id, zero)
				  							, ControlId			cancel_id
				  							, ControlFunction	(noLS (closeWindow dialog_id))
//				  							, ControlHide
				  							]
				)
				[ WindowId				dialog_id
				, WindowClose			(noLS (closeWindow dialog_id))
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
		
		accept :: !Id !Id !*PState -> *PState
		accept dialog_id edit_id pstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= pstate
			# wstate					= fromJust mb_wstate
			# (ok, mb_text)				= getControlText edit_id wstate
			| not ok					= pstate
			| isNothing mb_text			= pstate
			# text						= fromJust mb_text
			| text == ""				= setActiveControl edit_id pstate
			| text == "main"			= setActiveControl edit_id (showError [X_Internal "May not name another section 'main'"] pstate)
			# section					=	{ seName				= text
											, seTheorems			= []
											}
			# (ptr, pstate)				= accHeaps (newPointer section) pstate
			# (sections, pstate)		= pstate!ls.stSections
			# pstate					= {pstate & ls.stSections = [ptr:sections]}
			# pstate					= broadcast Nothing CreatedSection pstate
			= closeWindow dialog_id pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeSection :: !SectionPtr !*PState -> (!Bool, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeSection ptr pstate
	# (section, pstate)					= accHeaps (readPointer ptr) pstate
	| section.seName == "main"			= (False, showError [X_Internal "Not allowed to remove main section"] pstate)
	# (used_by, pstate)					= theoremsUsingSection ptr pstate
	| not (isEmpty used_by)
		# (theorem, pstate)				= accHeaps (readPointer (hd used_by)) pstate
		= (False, showError [X_RemoveSection section.seName ("used by theorem " +++ theorem.thName)] pstate)
	# (name, pstate)					= accHeaps (getPointerName ptr) pstate
	# frectify							= [CmText "Remove section ", CmBText name, CmText " from memory?"]
	# (ok, pstate)						= rectifyDialog frectify pstate
	| not ok							= (False, pstate)
	# (sections, pstate)				= pstate!ls.stSections
	# sections							= removeMember ptr sections
	# pstate							= {pstate & ls.stSections = sections}
	# pstate							= disable_hints section.seTheorems pstate
	# pstate							= broadcast (Just WinSectionCenter) (RemovedSection ptr) pstate
	# (opened, pstate)					= isWindowOpened WinHints False pstate
	| not opened						= (True, pstate)
	# (winfo, pstate)					= get_Window WinHints pstate
	# (_, pstate)						= asyncSend (fromJust winfo.wiNormalRId) CmdRefreshAlways pstate
	= (True, pstate)
	where
		disable_hints :: ![TheoremPtr] !*PState -> *PState
		disable_hints [ptr:ptrs] pstate
			# pstate					= setTheoremHint False ptr DummyValue Nothing pstate
			= disable_hints ptrs pstate
		disable_hints [] pstate
			= pstate