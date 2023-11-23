/*
** Program: Clean Prover System
** Module:  TacticList (.icl)
** 
** Author:  Maarten de Mol
** Created: 10 Januari 2001
*/

implementation module 
	TacticList

import 
	StdEnv,
	StdIO,
	ossystem,
	MdM_IOlib,
	States,
	BalancedText,
	ApplyTactic
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
:: TacticInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tiApply				:: Goal -> *PState -> *PState
	, tiName				:: !String
	, tiHelp				:: !String
	}

// ------------------------------------------------------------------------------------------------------------------------   
LightBlue					:== RGB {r=224, g=227, b=253}
MyGreen						:== RGB {r=  0, g=150, b= 75}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
AllTactics :: [CName]
// ------------------------------------------------------------------------------------------------------------------------   
AllTactics
	=	[ "Absurd"
		, "AbsurdEquality"
		, "Apply"
		, "Assume"
		, "Case"
		, "Cases"
		, "ChooseCase"
		, "Compare"
		, "Contradiction"
		, "Cut"
		, "Definedness"
		, "Discard"
		, "Exact"
		, "ExFalso"
//		, "ExpandFun"
		, "Extensionality"
		, "Generalize"
		, "Induction"
		, "Injective"
		, "Introduce"
		, "IntArith"
		, "IntCompare"
		, "MakeUnique"
		, "ManualDefinedness"
//		, "MoveInCase"
		, "MoveQuantors"
		, "Opaque"
		, "Reduce"
		, "RefineUndefinedness"
		, "Reflexive"
//		, "RemoveCase"
		, "Rename"
		, "Rewrite"
		, "Specialize"
		, "Split"
		, "SplitCase"
		, "SplitIff"
		, "Symmetric"
		, "Transitive"
		, "Transparent"
		, "Trivial"
		, "Uncurry"
		, "Undo"
		, "Unshare"
		, "Witness"
		]






	















// numbers range from 0 to 4
// ------------------------------------------------------------------------------------------------------------------------   
openTacticList :: !Int !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
openTacticList num pstate
	# (opened, pstate)								= isWindowOpened (WinTacticList num) True pstate
	| opened										= pstate
	# (menubar, pstate)								= pstate!ls.stMenuBarCreated
	# pstate										= case menubar of
														True	-> let (menu_ids, pstate1) = pstate!ls.stMenus.tactic_list_ids
																	in appPIO (markMenuItems [menu_ids !! num]) pstate1
														False	-> pstate
	# (winfo, pstate)								= new_Window (WinTacticList num) pstate
	# window_id										= winfo.wiWindowId
	# window_rid									= fromJust winfo.wiNormalRId
	# (info_rid, pstate)							= accPIO openRId pstate
	# list_id										= fromJust winfo.wiControlId
	# (list_rid, pstate)							= accPIO openRId pstate
	# (switch_to_selection_bid, pstate)				= accPIO openButtonId pstate
	# (switch_to_filter_bid, pstate)				= accPIO openButtonId pstate
	# (change_title_bid, pstate)					= accPIO openButtonId pstate
	# (change_selection_bid, pstate)				= accPIO openButtonId pstate
	# (change_filter_bid, pstate)					= accPIO openButtonId pstate
	# pos											= winfo.wiStoredPos
	# width											= winfo.wiStoredWidth
	# height										= winfo.wiStoredHeight
	# (filters, pstate)								= pstate!ls.stTacticFilters
	# filter										= filters !! num
	# (extended_bg, pstate)							= pstate!ls.stDisplayOptions.optTacticListBG
	# bg											= toColour 0 extended_bg
	# (window, pstate)								= showTacticList num filter pos width height window_id window_rid info_rid list_id list_rid switch_to_selection_bid switch_to_filter_bid change_title_bid change_selection_bid change_filter_bid bg pstate
	= snd (openWindow Nothing window pstate)

// ------------------------------------------------------------------------------------------------------------------------   
// showTacticList :: !Int !TacticFilter !Vector2 !Int !Int !Id !(RId WindowCommand) !(RId (MarkUpMessage WindowCommand)) !Id !(RId (MarkUpMessage WindowCommand)) !ButtonId !ButtonId !ButtonId !ButtonId !ButtonId !*PState -> (_, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
showTacticList num filter pos width height id rid info_rid list_id list_rid switch_to_selection_bid switch_to_filter_bid change_title_bid change_selection_bid change_filter_bid bg pstate
	# (layout_id, pstate)							= accPIO openId pstate
	# (metrics, _)									= osDefaultWindowMetrics 42
	# control										= controls metrics layout_id
	# (real_size, pstate)							= controlSize control True (Just (5,5)) (Just (5,5)) (Just (5,5)) pstate
	# (pos, pstate)									= case (pos.vx == (-1) && pos.vy == (-1)) of
														True	-> placeWindow real_size pstate
														False	-> (pos, pstate)
	= (window control real_size metrics pos, pstate)
	where
		window control real_size metrics pos
			= Window filter.tfTitle
				control
				[ WindowViewSize					{real_size & w = width + 2 + metrics.osmVSliderWidth + 10}
				, WindowItemSpace					5 5
				, WindowHMargin						5 5
				, WindowVMargin						5 5
				, WindowLook						True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
				, WindowPos							(LeftTop, OffsetVector pos)
				, WindowId							id
				, WindowClose						(noLS (close_Window (WinTacticList num)))
				, WindowInit						(noLS (refresh filter))
				, WindowKeyboard					(\x -> True) Able handle_window_keyboard
				, WindowMouse						(\x -> True) Able (myMouseFunction list_rid)
				]
		
		myMouseFunction rid _ (lstate, pstate)
			#! pstate					= deactiveMarkUp rid pstate
			= (lstate, pstate)
		
		controls metrics layout_id
			=		Receiver						rid receiver
														[]
				:+:	MarkUpControl					[CmText "creating"]
														[ MarkUpFontFace				"Times New Roman"
														, MarkUpTextSize				10
														, MarkUpBackgroundColour		bg
														, MarkUpWidth					(width + metrics.osmVSliderWidth + 2)
														, MarkUpNrLinesI				2 3
														, MarkUpReceiver				info_rid
														, MarkUpOverrideKeyboard		check_for_function_key
														]
						  								[ ControlResize					(\current old new -> {w = current.w + new.w - old.w, h = current.h})
						  								]
				:+:	boxedMarkUp						Black ResizeHorVer [CmText "creating"]
														[ MarkUpFontFace				"Times New Roman"
														, MarkUpTextSize				10
														, MarkUpBackgroundColour		(changeColour 20 bg)
														, MarkUpWidth					width
														, MarkUpHeight					height
														, MarkUpHScroll
														, MarkUpVScroll
														, MarkUpReceiver				list_rid
														, MarkUpLinkStyle				False (changeColour (-20) bg) (changeColour 20 bg) False Blue (changeColour 20 bg)
														, MarkUpLinkStyle				False Black (changeColour 20 bg) False Blue (changeColour 20 bg)
														, MarkUpEventHandler			(sendHandler rid)
														, MarkUpOverrideKeyboard		check_for_function_key
														]
														[ ControlId						list_id
														, ControlPos					(Left, zero)
														]
				:+: MarkUpControl					[]
														[ MarkUpBackgroundColour		bg
														, MarkUpOverrideKeyboard		check_for_function_key
														]
														[ ControlId						layout_id
														, ControlPos					(Right, zero)
														]
				:+:	MarkUpButton					"switch to selected list" bg switch_to_selection switch_to_selection_bid
														[ ControlPos					(LeftOf layout_id, OffsetVector {vx=6,vy=0})
														, ControlHide
														]
				:+:	MarkUpButton					"switch to filtered list" bg switch_to_filter switch_to_filter_bid
														[ ControlPos					(LeftOf layout_id, OffsetVector {vx=6,vy=0})
														, ControlHide
														]
				:+:	MarkUpButton					"change selection" bg change_selection change_selection_bid
														[ ControlPos					(LeftOf (fst3 change_title_bid), zero)
														, ControlHide
														]
				:+:	MarkUpButton					"set filter" bg change_name_filter change_filter_bid
														[ ControlPos					(LeftOf (fst3 change_title_bid), zero)
														, ControlHide
														]
				:+:	MarkUpButton					"set title" bg change_title change_title_bid
														[ ControlPos					(Right, zero)
														]
		
		handle_window_keyboard :: !KeyboardState !(!a, !*PState) -> (!a, !*PState)
		handle_window_keyboard key (lstate, pstate)
			= (lstate, check_for_function_key key pstate)
		
		check_for_function_key :: !KeyboardState !*PState -> *PState
		check_for_function_key (SpecialKey key (KeyDown False) modifiers) pstate
			# really_apply					= not modifiers.shiftDown
			| key == f1Key					= send_apply_hint 1 really_apply pstate
			| key == f2Key					= send_apply_hint 2 really_apply pstate
			| key == f3Key					= send_apply_hint 3 really_apply pstate
			| key == f4Key					= send_apply_hint 4 really_apply pstate
			| key == f5Key					= send_apply_hint 5 really_apply pstate
			| key == f6Key					= send_apply_hint 6 really_apply pstate
			| key == f7Key					= send_apply_hint 7 really_apply pstate
			| key == f8Key					= send_apply_hint 8 really_apply pstate
			| key == f9Key					= send_apply_hint 9 really_apply pstate
			| key == f10Key					= send_apply_hint 10 really_apply pstate
			| key == f11Key					= send_apply_hint 11 really_apply pstate
			| key == f12Key					= send_apply_hint 12 really_apply pstate
			= pstate
			where
				send_apply_hint :: !Int !Bool !*PState -> *PState
				send_apply_hint num really_apply pstate
					# (busy, pstate)		= pstate!ls.stBusyProving
					| busy					= pstate
					# (opened, pstate)		= isWindowOpened WinHints False pstate
					| not opened			= pstate
					# (winfo, pstate)		= get_Window WinHints pstate
					# (_, pstate)			= asyncSend (fromJust winfo.wiNormalRId) (CmdApplyHint num really_apply) pstate
					= pstate
		check_for_function_key key pstate
			= pstate
		
		set_filter :: !TacticFilter !*PState -> *PState
		set_filter filter pstate
			# (filters, pstate)						= pstate!ls.stTacticFilters
			# filters								= updateAt num filter filters
			# pstate								= {pstate & ls.stTacticFilters = filters}
			= pstate
		
		get_filter :: !*PState -> (!TacticFilter, !*PState)
		get_filter pstate
			# (filters, pstate)						= pstate!ls.stTacticFilters
			# filter								= filters !! num
			= (filter, pstate)
		
		switch_to_filter :: !*PState -> *PState
		switch_to_filter pstate
			# (filter, pstate)						= get_filter pstate
			# filter								= {filter & tfNameFilter = Just {nfFilter = ['*'], nfPositive = True}}
			# pstate								= set_filter filter pstate
			= refresh filter pstate
				
		switch_to_selection :: !*PState -> *PState
		switch_to_selection pstate
			# (filter, pstate)						= get_filter pstate
			# tactics								= [name \\ name <- AllTactics | checkNameFilter (fromJust filter.tfNameFilter) name]
			# filter								= {filter & tfNameFilter = Nothing, tfList = tactics}
			# pstate								= set_filter filter pstate
			= refresh filter pstate
		
		change_title :: !*PState -> *PState
		change_title pstate
			# (filter, pstate)						= get_filter pstate
			# (mb_title, pstate)					= changeTitle filter.tfTitle pstate
			| isNothing mb_title					= pstate
			# short_title							= fromJust mb_title
			# long_title							= toString (num+1) +++ ". " +++ short_title
			# filter								= {filter & tfTitle = short_title}
			# pstate								= set_filter filter pstate
			# pstate								= appPIO (setWindowTitle id short_title) pstate
			# (menu_ids, pstate)					= pstate!ls.stMenus.tactic_list_ids
			# menu_id								= menu_ids !! num
			# pstate								= appPIO (setMenuElementTitles [(menu_id, long_title)]) pstate
			= pstate
		
		change_name_filter :: !*PState -> *PState
		change_name_filter pstate
			# (filter, pstate)						= get_filter pstate
			# (mb_nfilter, pstate)					= changeNameFilter (fromJust filter.tfNameFilter) pstate
			| isNothing mb_nfilter					= pstate
			# nfilter								= fromJust mb_nfilter
			# filter								= {filter & tfNameFilter = Just nfilter}
			# pstate								= set_filter filter pstate
			= refresh filter pstate
		
		change_selection :: !*PState -> *PState
		change_selection pstate
			# (filter, pstate)						= get_filter pstate
			# (mb_names, pstate)					= changeSelection filter.tfList pstate
			| isNothing mb_names					= pstate
			# filter								= {filter & tfList = fromJust mb_names}
			# pstate								= set_filter filter pstate
			= refresh filter pstate

		refresh :: !TacticFilter !*PState -> *PState
		refresh filter pstate
			# (extended_bg, pstate)					= pstate!ls.stDisplayOptions.optTacticListBG
			# bg									= toColour 0 extended_bg
			# names									= case filter.tfNameFilter of
														(Just nf)	-> [name \\ name <- AllTactics | checkNameFilter nf name]
														Nothing		-> filter.tfList
			# finfo									= showInfo bg filter names
			# pstate								= changeMarkUpText info_rid finfo pstate
			# ftactics								= showTactics bg names
			# pstate								= changeMarkUpText list_rid ftactics pstate
			# pstate								= case filter.tfNameFilter of
														(Just nf)	-> appPIO (hideControls [fst3 switch_to_filter_bid, fst3 change_selection_bid]) pstate
														Nothing		-> appPIO (hideControls [fst3 switch_to_selection_bid, fst3 change_filter_bid]) pstate
			# pstate								= case filter.tfNameFilter of
														(Just nf)	-> appPIO (showControls [fst3 switch_to_selection_bid, fst3 change_filter_bid]) pstate
														Nothing		-> appPIO (showControls [fst3 switch_to_filter_bid, fst3 change_selection_bid]) pstate
			= pstate
		
		receiver :: !WindowCommand !(!lstate, !*PState) -> (!lstate, !*PState)
		receiver (CmdTacticWindow name) (lstate, pstate)
			# (opened, pstate)						= isWindowOpened (WinProof nilPtr) False pstate
			| not opened							= (lstate, showError [X_Internal "No proof in progress"] pstate)
			# (winfo, pstate)						= get_Window (WinProof nilPtr) pstate
			# ptr									= get_ptr winfo.wiId
			# (theorem, pstate)						= accHeaps (readPointer ptr) pstate
			| isEmpty theorem.thProof.pLeafs		= (lstate, showError [X_Internal "Proof is already finished"] pstate)
			# pstate								= applyName name ptr theorem theorem.thProof.pCurrentGoal pstate
			= (lstate, pstate)
			where
				get_ptr (WinProof ptr)				= ptr
		receiver (CmdRefreshBackground old_bg new_bg) (lstate, pstate)
			# new_look								= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate								= appPIO (setWindowLook id True (True, new_look)) pstate
			# pstate								= changeMarkUpColour info_rid True old_bg new_bg pstate
			# pstate								= changeMarkUpColour info_rid True (changeColour 10 old_bg) (changeColour 10 new_bg) pstate
			# pstate								= changeMarkUpColour list_rid False old_bg new_bg pstate
			# pstate								= changeMarkUpColour list_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate								= changeMarkUpColour list_rid False (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate								= changeMarkUpColour (snd3 switch_to_selection_bid) True old_bg new_bg pstate
			# pstate								= changeMarkUpColour (snd3 switch_to_filter_bid) True old_bg new_bg pstate
			# pstate								= changeMarkUpColour (snd3 change_selection_bid) True old_bg new_bg pstate
			# pstate								= changeMarkUpColour (snd3 change_filter_bid) True old_bg new_bg pstate
			# pstate								= changeMarkUpColour (snd3 change_title_bid) True old_bg new_bg pstate
			# (filter, pstate)						= get_filter pstate
			= (lstate, refresh filter pstate)
		receiver (CmdTacticInfo name) (lstate, pstate)
			= (lstate, showError [X_Internal "Tactic help not yet implemented. (module TacticList, receiver)"] pstate)
		receiver _ (lstate, pstate)
			= (lstate, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
showInfo :: !Colour !TacticFilter ![CName] -> MarkUpText WindowCommand
// ------------------------------------------------------------------------------------------------------------------------   
showInfo bg filter names
	= case filter.tfNameFilter of
		(Just nf)	->	[ CmRight
						, CmBText				"Showing:"
						, CmAlign				"@RHS"
						, CmSpaces				1
						, CmBackgroundColour	(changeColour 10 bg)
						, CmText				"all tactics"
						, CmIText				("(" +++ toString (length names) +++ ")")
						, CmFillLine
						, CmEndBackgroundColour
						, CmNewlineI			False 3 Nothing
						, CmRight
						, CmBText				"named:"
						, CmAlign				"@RHS"
						, CmSpaces				1
						, CmBackgroundColour	(changeColour 10 bg)
						] ++
						(	case nf.nfPositive of
								True	-> []
								False	-> [CmColour Red, CmText "not", CmEndColour, CmSpaces 1]
						) ++
						[ CmText				{c \\ c <- nf.nfFilter}
						, CmFillLine
						, CmEndBackgroundColour
						, CmNewlineI			False 3 Nothing
						]
		Nothing		->	[ CmRight
						, CmBText				"Showing:"
						, CmAlign				"@RHS"
						, CmSpaces				1
						, CmBackgroundColour	(changeColour 10 bg)
						, CmText				"list of tactics"
						, CmIText				("(" +++ toString (length names) +++ ")")
						, CmFillLine
						, CmEndBackgroundColour
						, CmNewlineI			False 3 Nothing
						, CmRight
						, CmBText				"selection:"
						, CmAlign				"@RHS"
						, CmSpaces				1
						, CmBackgroundColour	(changeColour 10 bg)
						, CmIText				"manually"
						, CmFillLine
						, CmEndBackgroundColour
						, CmNewlineI			False 3 Nothing
						]

// ------------------------------------------------------------------------------------------------------------------------   
showTactics :: !Colour ![CName] -> MarkUpText WindowCommand
// ------------------------------------------------------------------------------------------------------------------------   
showTactics bg [name:names]
	# (apply_font, apply_code)					= IconSymbol ApplyIcon
	# (help_font, help_code)					= IconSymbol HelpIcon
	=	[ CmFontFace				apply_font
		, CmLink2					0 {toChar apply_code} (CmdTacticWindow name)
		, CmEndFontFace
		, CmSpaces					1
		, CmBold
		, CmLink2					1 name (CmdTacticWindow name)
		, CmEndBold
		, CmAlign					"@ICON"
		, CmSpaces					1
		, CmFontFace				help_font
		, CmLink2					0 {toChar help_code} (CmdTacticInfo name)
		, CmEndFontFace
		, CmNewlineI				False 1 (Just bg)
		: showTactics bg names
		]
showTactics bg []
	=	[]



































// ------------------------------------------------------------------------------------------------------------------------   
changeTitle :: !CName !*PState -> (!Maybe CName, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
changeTitle title pstate
	# (dialog_id, pstate)							= accPIO openId pstate
	# (edit_id, pstate)								= accPIO openId pstate
	# (ok_id, pstate)								= accPIO openId pstate
	# (cancel_id, pstate)							= accPIO openId pstate
	# ((_, mb_name), pstate)						= openModalDialog title (dialog title dialog_id edit_id ok_id cancel_id) pstate
	= case mb_name of
		Just ""		-> (Nothing, pstate)
		Just n		-> (Just n, pstate)
		Nothing		-> (Nothing, pstate)
	where
		dialog title dialog_id edit_id ok_id cancel_id
			= Dialog "Change title of list of tactics"
				(		MarkUpControl				[CmText "Give a new title for the list of tactics:"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[]
					:+:	EditControl					title (PixelWidth 400) 1
														[ ControlId					edit_id
														, ControlPos				(Left, zero)
														]
					:+:	ButtonControl				"Ok"
														[ ControlPos				(Right, zero)
														, ControlId					ok_id
														, ControlFunction			ok_close
														]
					:+:	ButtonControl				"Cancel"
														[ ControlPos				(LeftBottom, zero)
														, ControlId					cancel_id
														, ControlHide
														, ControlFunction			cancel_close
														]
				)
				[		WindowId					dialog_id
				,		WindowOk					ok_id
				,		WindowCancel				cancel_id
				,		WindowClose					cancel_close
				]
			where
				cancel_close :: !(!CName, !*PState) -> (!CName, !*PState)
				cancel_close (name, pstate)
					= ("", closeWindow dialog_id pstate)
				
				ok_close :: !(!CName, !*PState) -> (!CName, !*PState)
				ok_close (name, pstate)
					# (mb_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
					| isNothing mb_wstate			= (name, pstate)
					# wstate						= fromJust mb_wstate
					# (ok, mb_text)					= getControlText edit_id wstate
					| not ok						= (name, pstate)
					| isNothing mb_text				= (name, pstate)
					# name							= fromJust mb_text
					= (name, closeWindow dialog_id pstate)

// ------------------------------------------------------------------------------------------------------------------------   
changeNameFilter :: !NameFilter !*PState -> (!Maybe NameFilter, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
changeNameFilter filter pstate
	# (dialog_id, pstate)							= accPIO openId pstate
	# (header_id, pstate)							= accPIO openId pstate
	# (name_id, pstate)								= accPIO openId pstate
	# (mode_id, pstate)								= accPIO openId pstate
	# (ok_id, pstate)								= accPIO openId pstate
	# (cancel_id, pstate)							= accPIO openId pstate
	# ((_, mb_result), pstate)						= openModalDialog (False, filter) (dialog filter dialog_id header_id name_id mode_id ok_id cancel_id) pstate
	= case mb_result of
		Just (True, filter)		-> (Just filter, pstate)
		Just (False, _)			-> (Nothing, pstate)
		Nothing					-> (Nothing, pstate)
	where
		dialog filter dialog_id header_id name_id mode_id ok_id cancel_id
			= Dialog "Change name filter of list of tactics"
				(		MarkUpControl				[CmBText "Showing:"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[]
					:+:	MarkUpControl				[CmText "all tactics"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[ ControlId					header_id
														]
					:+:	MarkUpControl				[CmBText "named:"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[ ControlPos				(LeftOf name_id, zero)
														]
					:+:	EditControl					{c \\ c <- filter.nfFilter} (PixelWidth 400) 1
														[ ControlId					name_id
														, ControlPos				(Below header_id, zero)
														]
					:+:	MarkUpControl				[CmBText "mode:"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[ ControlPos				(LeftOf mode_id, zero)
														]
					:+:	PopUpControl				[("positive (all tactics passing the name filter)", id),
													 ("negative (all tactics *not* passing the name filter)", id)] (if filter.nfPositive 1 2)
													 	[ ControlPos				(Below name_id, zero)
													 	, ControlId					mode_id
													 	, ControlWidth				(PixelWidth 400)
													 	]
					:+:	ButtonControl				"Ok"
														[ ControlPos				(Right, zero)
														, ControlId					ok_id
														, ControlFunction			ok_close
														]
					:+:	ButtonControl				"Cancel"
														[ ControlPos				(LeftBottom, zero)
														, ControlId					cancel_id
														, ControlHide
														, ControlFunction			cancel_close
														]
				)
				[		WindowId					dialog_id
				,		WindowOk					ok_id
				,		WindowCancel				cancel_id
				,		WindowClose					cancel_close
				]
			where
				cancel_close :: !(!(!Bool, !NameFilter), !*PState) -> (!(!Bool, !NameFilter), !*PState)
				cancel_close ((_, filter), pstate)
					= ((False, filter), closeWindow dialog_id pstate)
				
				ok_close :: !(!(!Bool, !NameFilter), !*PState) -> (!(!Bool, !NameFilter), !*PState)
				ok_close ((_, filter), pstate)
					# (mb_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
					| isNothing mb_wstate			= ((False, filter), pstate)
					# wstate						= fromJust mb_wstate
					# (ok, mb_text)					= getControlText name_id wstate
					| not ok						= ((False, filter), pstate)
					| isNothing mb_text				= ((False, filter), pstate)
					# name							= fromJust mb_text
					# (ok, mb_index)				= getPopUpControlSelection mode_id wstate
					| not ok						= ((False, filter), pstate)
					| isNothing mb_index			= ((False, filter), pstate)
					# index							= fromJust mb_index
					# mode							= if (index==1) True False
					# filter						= {nfFilter = [c \\ c <-: name], nfPositive = mode}
					= ((True, filter), closeWindow dialog_id pstate)

// ------------------------------------------------------------------------------------------------------------------------   
changeSelection :: ![CName] !*PState -> (!Maybe [CName], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
changeSelection names pstate
	# (dialog_id, pstate)							= accPIO openId pstate
	# (dialog_rid, pstate)							= accPIO openRId pstate
	# (list_rid, pstate)							= accPIO openRId pstate
	# (ok_id, pstate)								= accPIO openId pstate
	# (cancel_id, pstate)							= accPIO openId pstate
	# ((_, mb_result), pstate)						= openModalDialog (False, names) (dialog names dialog_id dialog_rid list_rid ok_id cancel_id) pstate
	= case mb_result of
		Just (True, names)		-> (Just names, pstate)
		Just (False, _)			-> (Nothing, pstate)
		Nothing					-> (Nothing, pstate)
	where
		dialog finitial dialog_id dialog_rid list_rid ok_id cancel_id
			= Dialog "Change selection in list of tactics"
				(		Receiver					dialog_rid receiver
														[]
					:+:	MarkUpControl				[CmText "Choose selected tactics:"]
														[ MarkUpBackgroundColour	getDialogBackgroundColour
														, MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														]
														[]
					:+:	boxedMarkUp					Black DoNotResize (show AllTactics names)
														[ MarkUpFontFace			"Times New Roman"
														, MarkUpTextSize			10
														, MarkUpVScroll
														, MarkUpWidth				225
														, MarkUpNrLinesI			15 15
														, MarkUpReceiver			list_rid
														, MarkUpLinkStyle			False Black White False Blue White
														, MarkUpLinkStyle			False Black LightBlue False Blue LightBlue
														, MarkUpEventHandler		(sendHandler dialog_rid)
														]
														[ ControlPos				(Left, zero)
														]
					:+:	ButtonControl				"Add all"
														[ ControlPos				(Left, zero)
														, ControlFunction			add_all
														]
					:+:	ButtonControl				"Remove all"
														[ ControlFunction			remove_all
														]
					:+:	ButtonControl				"Ok"
														[ ControlId					ok_id
														, ControlFunction			ok_close
														]
					:+:	ButtonControl				"Cancel"
														[ ControlPos				(LeftBottom, zero)
														, ControlId					cancel_id
														, ControlHide
														, ControlFunction			cancel_close
														]
				)
				[		WindowId					dialog_id
				,		WindowOk					ok_id
				,		WindowCancel				cancel_id
				,		WindowClose					cancel_close
				]
			where
				cancel_close :: !(!(!Bool, ![CName]), !*PState) -> (!(!Bool, ![CName]), !*PState)
				cancel_close ((_, names), pstate)
					= ((False, names), closeWindow dialog_id pstate)
				
				ok_close :: !(!(!Bool, ![CName]), !*PState) -> (!(!Bool, ![CName]), !*PState)
				ok_close ((_, names), pstate)
					= ((True, names), closeWindow dialog_id pstate)
				
				show :: ![CName] ![CName] -> MarkUpText CName
				show [name:names] selection
					= case isMember name selection of
						True	->	[ CmBackgroundColour		LightBlue
									, CmColour					MyGreen
									, CmFontFace				"Wingdings"
									, CmBText					{toChar 252}
									, CmEndFontFace
									, CmEndColour
									, CmText					" "
									, CmLink2					1 name name
									, CmFillLine
									, CmEndBackgroundColour
									, CmNewlineI				False 1 Nothing
									: show names selection
									]
						False	->	[ CmColour					White
									, CmFontFace				"Wingdings"
									, CmBText					{toChar 252}
									, CmEndFontFace
									, CmEndColour
									, CmText					" "
									, CmLink2					0 name name
									, CmNewlineI				False 1 Nothing
									: show names selection
									]
				show [] _
					= []
				
				add_all :: !(!(!Bool, ![CName]), !*PState) -> (!(!Bool, ![CName]), !*PState)
				add_all ((_, _), pstate)
					# names							= AllTactics
					# finitial						= show AllTactics names
					# pstate						= changeMarkUpText list_rid finitial pstate
					= ((False, names), pstate)
				
				remove_all :: !(!(!Bool, ![CName]), !*PState) -> (!(!Bool, ![CName]), !*PState)
				remove_all ((_, _), pstate)
					# names							= []
					# finitial						= show AllTactics names
					# pstate						= changeMarkUpText list_rid finitial pstate
					= ((False, names), pstate)
				
				receiver :: !CName !(!(!Bool, ![CName]), !*PState) -> (!(!Bool, ![CName]), !*PState)
				receiver name ((_, names), pstate)
					# names							= case isMember name names of
														True	-> removeMember name names
														False	-> sort [name:names]
					# finitial						= show AllTactics names
					# pstate						= changeMarkUpText list_rid finitial pstate
					= ((False, names), pstate)
































/*
// ------------------------------------------------------------------------------------------------------------------------   
NotImplemented :: !String -> TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
NotImplemented name
	=	{ tiApply			= \goal -> showError [X_Internal "Not implemented yet"]
		, tiName			= "@" +++ name
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
AbsurdInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
AbsurdInfo
	=	{ tiApply			= applyAbsurd
		, tiName			= "Absurd"
		, tiHelp			= "proves any goal which has contradictory hypotheses"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ApplyInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ApplyInfo
	=	{ tiApply			= applyApply
		, tiName			= "Apply"
		, tiHelp			= "apply a hypothesis to the current goal"
		}

// ------------------------------------------------------------------------------------------------------------------------   
AssumeInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
AssumeInfo
	=	{ tiApply			= applyAssume
		, tiName			= "Assume"
		, tiHelp			= "introduces a new hypothesis, which has to be proven afterwards"
		}

// ------------------------------------------------------------------------------------------------------------------------   
CaseInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
CaseInfo
	=	{ tiApply			= applyCase
		, tiName			= "Case"
		, tiHelp			= "continues with one of the cases of a disjunction"
		}

// ------------------------------------------------------------------------------------------------------------------------   
CasesInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
CasesInfo
	=	{ tiApply			= applyCases
		, tiName			= "Cases"
		, tiHelp			= "does a case-distinction on an introduced expr-var"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ContradictionInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ContradictionInfo
	=	{ tiApply			= applyContradiction
		, tiName			= "Contradiction"
		, tiHelp			= "starts an indirect demonstration, either by assuming the negation of the current goal or by proving the negation of a hypothesis"
		}

// ------------------------------------------------------------------------------------------------------------------------   
CutInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
CutInfo
	=	{ tiApply			= applyCut
		, tiName			= "Cut"
		, tiHelp			= "??"
		}

// ------------------------------------------------------------------------------------------------------------------------   
DiscardInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
DiscardInfo
	=	{ tiApply			= applyDiscard
		, tiName			= "Discard"
		, tiHelp			= "removes introduced variables and or hypotheses from the current goal"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ExactInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ExactInfo
	=	{ tiApply			= applyExact
		, tiName			= "Exact"
		, tiHelp			= "proves a goal identical to one of the hypotheses"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ExFalsoInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ExFalsoInfo
	=	{ tiApply			= applyExFalso
		, tiName			= "ExFalso"
		, tiHelp			= "proves a goal if one of the hypotheses is FALSE"
		}

// ------------------------------------------------------------------------------------------------------------------------   
GeneralizeInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
GeneralizeInfo
	=	{ tiApply			= applyGeneralize
		, tiName			= "Generalize"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
InductionInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
InductionInfo
	=	{ tiApply			= applyInduction
		, tiName			= "Induction"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
IntroduceInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
IntroduceInfo
	=	{ tiApply			= applyIntroduce
		, tiName			= "Introduce"
		, tiHelp			= "introduces one or more variables or hypotheses"
		}

// ------------------------------------------------------------------------------------------------------------------------   
LiftQuantorsInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
LiftQuantorsInfo
	=	{ tiApply			= applyLiftQuantors
		, tiName			= "LiftQuantors"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ReduceInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ReduceInfo
	=	{ tiApply			= applyReduce
		, tiName			= "Reduce"
		, tiHelp			= "reduces subexpressions in the current goal or in one of its hypotheses"
		}

// ------------------------------------------------------------------------------------------------------------------------   
ReflexiveInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
ReflexiveInfo
	=	{ tiApply			= applyReflexive
		, tiName			= "Reflexive"
		, tiHelp			= "proves a reflexive equality"
		}

// ------------------------------------------------------------------------------------------------------------------------   
RenameInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
RenameInfo
	=	{ tiApply			= applyRename
		, tiName			= "Rename"
		, tiHelp			= "renames a variable or hypothesis"
		}

// ------------------------------------------------------------------------------------------------------------------------   
RewriteInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
RewriteInfo
	=	{ tiApply			= applyRewrite
		, tiName			= "Rewrite"
		, tiHelp			= "applies a rewrite-rule (either a hypothesis or a theorem) to the current goal or a hypothesis"
		}

// ------------------------------------------------------------------------------------------------------------------------   
SpecializeInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
SpecializeInfo
	=	{ tiApply			= applySpecialize
		, tiName			= "Specialize"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
SplitInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
SplitInfo
	=	{ tiApply			= applySplit
		, tiName			= "Split"
		, tiHelp			= "splits a conjunction in its components, either in the current goal or in a hypothesis"
		}

// ------------------------------------------------------------------------------------------------------------------------   
SplitIffInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
SplitIffInfo
	=	{ tiApply			= applySplitIff
		, tiName			= "SplitIff"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
SymmetricInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
SymmetricInfo
	=	{ tiApply			= applySymmetric
		, tiName			= "Symmetric"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
TransitiveInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
TransitiveInfo
	=	{ tiApply			= applyTransitive
		, tiName			= "Transitive"
		, tiHelp			= "?"
		}

// ------------------------------------------------------------------------------------------------------------------------   
TrivialInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
TrivialInfo
	=	{ tiApply			= applyTrivial
		, tiName			= "Trivial"
		, tiHelp			= "proves TRUE"
		}

// ------------------------------------------------------------------------------------------------------------------------   
WitnessInfo :: TacticInfo
// ------------------------------------------------------------------------------------------------------------------------   
WitnessInfo
	=	{ tiApply			= applyWitness
		, tiName			= "Witness"
		, tiHelp			= "uses a witness to prove a goal starting with an existential quantor"
		}

// ------------------------------------------------------------------------------------------------------------------------   
AllInfos :: ![TacticInfo]
// ------------------------------------------------------------------------------------------------------------------------   
AllInfos
	=	[ AbsurdInfo
		, ApplyInfo
		, AssumeInfo
		, CaseInfo
		, CasesInfo
		, ContradictionInfo
		, CutInfo
		, DiscardInfo
		, ExactInfo
		, ExFalsoInfo
		, GeneralizeInfo
		, InductionInfo
		, IntroduceInfo
		, LiftQuantorsInfo
		, ReduceInfo
		, ReflexiveInfo
		, RenameInfo
		, RewriteInfo
		, SpecializeInfo
		, SplitInfo
		, SplitIffInfo
		, SymmetricInfo
		, TransitiveInfo
		, TrivialInfo
		, WitnessInfo
		]
*/