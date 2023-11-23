/*
** Program: Clean Prover System
** Module:  ShowProof (.icl)
** 
** Author:  Maarten de Mol
** Created: 7 November 2000
*/

implementation module 
	ShowProof

import 
	StdEnv,
	StdIO,
	ossystem,
	States,
	CoreTypes,
	CoreAccess,
	ProveTypes,
	LTypes,
	Heaps,
	Hints,
	Print,
	AnnotatedShow,
	GoalPath,
	Operate,
	GiveType,
	BindLexeme,
	ShowDefinition,
	ShowSection,
	Tactics,
	Depends,
	ApplyTactic,
	Definedness
from StdFunc import seq

// -------------------------------------------------------------------------------------------------------------------------------------------------
BG				:== RGB {r=170, g=170, b=220}
ControlBG		:== RGB {r=190, g=190, b=240}
HighlightBG		:== RGB {r=210, g=210, b=255}
InfoBG			:== RGB {r=180, g=180, b=230}
IconFG			:== RGB {r=130, g=130, b=180}

BlueBG			:== RGB {r=215, g=215, b=240}
BlueLightBG		:== RGB {r=225, g=225, b=250}
BlueDarkBG		:== RGB {r=200, g=200, b=250}
BlueDarkerBG	:== RGB {r=170, g=170, b=220}
GrayBlue		:== RGB {r=175, g=175, b=200}
LightBlue1		:== RGB {r=100, g=100, b=255}
LightBlue2		:== RGB {r=100, g=80, b=200}
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize :: !(MarkUpText a) -> MarkUpText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize [CmColour _:rest]			= normalize rest
normalize [CmEndColour:rest]		= normalize rest
normalize [CmBold:rest]				= normalize rest
normalize [CmEndBold:rest]			= normalize rest
normalize [CmBText text:rest]		= [CmText text: normalize rest]
normalize [CmLink text _:rest]		= [CmText text: normalize rest]
normalize [CmAlignI _ _: rest]		= normalize rest
normalize [CmNewlineI _ _ _: rest]	= [CmText " ": normalize rest]
normalize [CmScope: rest]			= normalize rest
normalize [CmEndScope: rest]		= normalize rest
normalize [CmTabSpace: rest]		= [CmText " ": normalize rest]
normalize [other:rest]				= [other:normalize rest]
normalize []						= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
removeQuantors :: !CPropH -> CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
removeQuantors (CExprForall var p)	= removeQuantors p
removeQuantors (CPropForall var p)	= removeQuantors p
removeQuantors other				= other

// -------------------------------------------------------------------------------------------------------------------------------------------------
findNext :: !a ![a] -> a | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------
findNext el [x:xs]
	| el == x						= case xs of
										[next:_]	-> next
										[]			-> el
	= findNext el xs
findNext el []
	= el
























// ------------------------------------------------------------------------------------------------------------------------
openProof :: !TheoremPtr !Theorem !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
openProof ptr theorem pstate
	# (same, pstate)					= sameOpen pstate
	| same								= pstate
	# (winfo, pstate)					= new_Window (WinProof ptr) pstate
	# window_id							= winfo.wiWindowId
	# window_rid						= fromJust winfo.wiNormalRId
	# (info_rid, pstate)				= accPIO openRId pstate
	# current_id						= fromJust winfo.wiControlId
	# (current_rid, pstate)				= accPIO openRId pstate
	# (subgoals_rid, pstate)			= accPIO openRId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# width								= winfo.wiStoredWidth
	# height							= winfo.wiStoredHeight
	# pos								= winfo.wiStoredPos
	# (metrics, _)						= osDefaultWindowMetrics 42
	#! (window, pstate)					= ProofWindow ptr width height pos metrics window_id window_rid info_rid current_id current_rid subgoals_rid edit_id pstate
	# lstate							= {previousCommands = [], viewIndex = -1}
	= snd (openWindow lstate window pstate)
	where
		sameOpen :: !*PState -> (!Bool, !*PState)
		sameOpen pstate
			# (_, pstate)				= isWindowOpened WinHints True pstate			// Hack -- activate window
			# (opened, pstate)			= isWindowOpened (WinProof nilPtr) True pstate
			| not opened				= (False, pstate)
			# (winfo, pstate)			= get_Window (WinProof nilPtr) pstate
			# the_ptr					= fromWinProof winfo.wiId
			| ptr == the_ptr			= (True, pstate)
			# pstate					= close_Window2 False (WinProof the_ptr) pstate
			= (False, pstate)
			where
				fromWinProof (WinProof ptr) = ptr



















// ------------------------------------------------------------------------------------------------------------------------
:: LState =
// ------------------------------------------------------------------------------------------------------------------------
	{ previousCommands				:: ![String]		// reverse order!
	, viewIndex						:: !Int				// index in previousCommands
	}

// ------------------------------------------------------------------------------------------------------------------------
// ProofWindow :: !Ids -> Window
// ------------------------------------------------------------------------------------------------------------------------
ProofWindow ptr width height pos metrics id rid info_rid current_id current_rid subgoals_rid edit_id pstate
	# (real_size, pstate)			= controlSize controls True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)					= case (pos.vx == (-1) && pos.vy == (-1)) of
										True	-> placeWindow real_size pstate
										False	-> (pos, pstate)
	= (Window "Proof window" controls
			[ WindowActivate			(noLS (setActiveControl edit_id))
			, WindowId					id
			, WindowClose				(noLS (close_Window (WinProof ptr)))
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour BG, fill newFrame])
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowViewSize			real_size
			, WindowInit				(noLS refresh)
			, WindowPos					(LeftTop, OffsetVector pos)
			, WindowKeyboard			(\key -> True) Able handle_window_keyboard
			], pstate)
	where
		controls
			= 		Receiver		rid receiver
										[]
				:+:	MarkUpControl	[CmText "?"]
										[ MarkUpFontFace			"Times New Roman"
										, MarkUpTextSize			10
										, MarkUpNrLinesI			3 6
										, MarkUpReceiver			info_rid
										, MarkUpBackgroundColour	BG
										, MarkUpWidth				(width + 2 + metrics.osmVSliderWidth)
										, MarkUpLinkStyle			False IconFG InfoBG False Blue InfoBG
										, MarkUpEventHandler		(clickHandler globalEventHandler)
										, MarkUpOverrideKeyboard	check_for_function_key
										]
										[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
										]
				:+:	boxedMarkUp		Black ResizeHorVer [CmText "creating"]
										[ MarkUpFontFace			"Courier New"
										, MarkUpTextSize			10
										, MarkUpBackgroundColour	ControlBG
										, MarkUpWidth				width
										, MarkUpHeight				height
										, MarkUpHScroll
										, MarkUpVScroll
										, MarkUpReceiver			current_rid
										, MarkUpEventHandler		(sendHandler rid)
										, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
										, MarkUpLinkStyle			False Black ControlBG True Black ControlBG
										, MarkUpLinkStyle			False LogicColour ControlBG False LogicDarkColour ControlBG
										, MarkUpLinkStyle			False Black ControlBG False LogicDarkColour ControlBG
										, MarkUpLinkStyle			False Blue ControlBG False Blue ControlBG
										, MarkUpOverrideKeyboard	check_for_function_key
										]
										[ ControlPos				(Left, zero)
										, ControlId					current_id
										]
				:+:	boxedMarkUp		Black ResizeHor [CmText "creating"]
										[ MarkUpFontFace			"Courier New"
										, MarkUpTextSize			10
										, MarkUpBackgroundColour	BG
										, MarkUpNrLines				4
										, MarkUpHScroll
										, MarkUpVScroll
										, MarkUpReceiver			subgoals_rid
										, MarkUpEventHandler		(sendHandler rid)
										, MarkUpLinkStyle			False Black ControlBG False Blue ControlBG
										, MarkUpWidth				width
										, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
										, MarkUpOverrideKeyboard	check_for_function_key
										]
										[ ControlPos				(Left, zero)
										]
				:+:	EditControl		"" (PixelWidth (width + 2 + metrics.osmVSliderWidth)) 3
										[ ControlId					edit_id
										, ControlPos				(Left, zero)
										, ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
										, ControlKeyboard			(\_ -> True) Able keyboard_handler
										]
		
		handle_window_keyboard :: !KeyboardState !(!LState, !*PState) -> (!LState, !*PState)
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
			| key == pgUpKey				= snd (asyncSend rid (CmdFocusSubgoal (-1)) pstate)
			| key == pgDownKey				= snd (asyncSend rid (CmdFocusSubgoal 0) pstate)
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
		
		keyboard_handler :: !KeyboardState !(!LState, !*PState) -> (!LState, !*PState)
		keyboard_handler tkey=:(SpecialKey key (KeyDown False) modifiers) (lstate, pstate)
			# (mb_wstate, pstate)			= accPIO (getWindow id) pstate
			# wstate						= fromJust mb_wstate
			# (ok, mb_text)					= getControlText edit_id wstate
			| not ok						= (lstate, pstate)
			| isNothing mb_text				= (lstate, pstate)
			# old_text						= fromJust mb_text
		
			| key == enterKey
				# dot_pos					= last_dot (size old_text-1) old_text
				| dot_pos < 0				= (lstate, pstate)
				# lstate					=	{ previousCommands		= [old_text: lstate.previousCommands]
												, viewIndex				= -1
												}
				# (_, pstate)				= asyncSend rid (CmdExecuteCmdLine old_text dot_pos) pstate
				= (lstate, pstate)
			| key == leftKey && modifiers.altDown
				| lstate.viewIndex + 1 >= length lstate.previousCommands
											= (lstate, pstate)
				# new_line					= lstate.previousCommands !! (lstate.viewIndex+1)
				# lstate					= {lstate & viewIndex = lstate.viewIndex+1}
				# pstate					= appPIO (setControlText edit_id new_line) pstate
				# pstate					= appPIO (setEditControlCursor edit_id 1000) pstate
				= (lstate, pstate)
			| key == rightKey && modifiers.altDown
				| lstate.viewIndex < 0		= (lstate, pstate)
				# new_line					= case lstate.viewIndex of 
												0	-> ""
												n	-> lstate.previousCommands !! (n-1)
				# lstate					= {lstate & viewIndex = lstate.viewIndex-1}
				# pstate					= appPIO (setControlText edit_id new_line) pstate
				# pstate					= appPIO (setEditControlCursor edit_id 1000) pstate
				= (lstate, pstate)
			// delete garbage generated by the Object I/O
			# pstate						= case isMember key [f1Key, f2Key, f3Key, f4Key, f5Key, f6Key, f7Key, f8Key, f9Key, f10Key, f11Key, f12Key, downKey, upKey] of
												True	-> snd (asyncSend rid (CmdRestoreEditControl old_text) pstate)
												False	-> pstate
			// check for function keys
			# pstate						= check_for_function_key tkey pstate
			= (lstate, pstate)
			where
				last_dot :: !Int !String -> Int
				last_dot pos text
					| pos < 0				= -1
					= case text.[pos] of
						'.'		-> pos
						'\n'	-> last_dot (pos-1) text
						'\r'	-> last_dot (pos-1) text
						'\t'	-> last_dot (pos-1) text
						' '		-> last_dot (pos-1) text
						_		-> -1
		keyboard_handler _ (lstate, pstate)
			= (lstate, pstate)
		
		refresh :: !*PState -> *PState
		refresh pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= refresh_theorem theorem pstate
		
		refresh_theorem :: !Theorem !*PState -> *PState
		refresh_theorem theorem pstate
			# (finfo, pstate)			= showInfo ptr theorem pstate
			# pstate					= changeMarkUpText info_rid finfo pstate
			# (finfo, pstate)			= makeFormatInfo pstate
			# (error, definedness_info, ftext, pstate)
										= showToProve finfo theorem pstate
			| isError error				= showError error pstate
			# pstate					= changeMarkUpText current_rid ftext pstate
			# (error, ftext, pstate)	= showSubgoals finfo theorem.thProof pstate
			| isError error				= showError error pstate
			# pstate					= changeMarkUpText subgoals_rid ftext pstate
			# pstate					= case isEmpty theorem.thProof.pLeafs of
											True	-> pstate
											False	-> jumpToMarkUpLabel subgoals_rid "@CURRENT" pstate
			# pstate					= scrollMarkUpToBottom current_rid pstate
			# can_not_undo				= (isEmpty theorem.thProof.pLeafs) || (theorem.thProof.pTree == theorem.thProof.pCurrentLeaf)
			# (opened, pstate)			= isWindowOpened WinHints False pstate
			| not opened				= pstate
			# (winfo, pstate)			= get_Window WinHints pstate
			# (_, pstate)				= asyncSend (fromJust winfo.wiNormalRId) (CmdUpdateHints (Just ptr) theorem definedness_info) pstate
			= pstate
			where
				findPtr :: !Int !ProofTreePtr ![ProofTreePtr] -> Int
				findPtr num the_ptr [ptr:ptrs]
					| ptr == the_ptr	= num
					= findPtr (num+1) the_ptr ptrs
				findPtr num the_ptr []
					= 0
		
		receiver :: !WindowCommand !(!LState, !*PState) -> (!LState, !*PState)
		receiver CmdRefreshAlways (lstate, pstate)
			= (lstate, refresh pstate)
		receiver (CmdRefresh ChangedDisplayOption) (lstate, pstate)
			= (lstate, refresh pstate)
		receiver (CmdRefresh (ChangedProof theorem_ptr)) (lstate, pstate)
			= case ptr == theorem_ptr of
				True	-> (lstate, refresh pstate)
				False	-> (lstate, pstate)
		receiver (CmdRefresh (ChangedSubgoal theorem_ptr)) (lstate, pstate)
			| ptr == theorem_ptr
				# (_, pstate)			= isWindowOpened WinHints True pstate
				# pstate				= setActiveWindow id pstate
				# pstate				= refresh pstate
				= (lstate, pstate)
			= (lstate, pstate)
		receiver (CmdRefresh (CreatedTheorem theorem_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# proof_finished			= isEmpty theorem.thProof.pLeafs
			| not proof_finished		= (lstate, pstate)
			= (lstate, globalEventHandler (CmdProve theorem_ptr) pstate)
		receiver (CmdRefresh (MovedTheorem theorem_ptr _)) (lstate, pstate)
			| ptr <> theorem_ptr		= (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (finfo, pstate)			= showInfo ptr theorem pstate
			# pstate					= changeMarkUpText info_rid finfo pstate
			= (lstate, pstate)
		receiver (CmdRefresh (RemovedSection section_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= case theorem.thSection == section_ptr of
				True	-> (lstate, close_Window (WinProof ptr) pstate)
				False	-> (lstate, pstate)
		receiver (CmdRefresh (RemovedTheorem theorem_ptr)) (lstate, pstate)
			= case ptr == theorem_ptr of
				True	-> (lstate, close_Window (WinProof ptr) pstate)
				False	-> (lstate, pstate)
		receiver (CmdRefresh (RenamedSection section_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# in_section				= theorem.thSection == section_ptr
			| not in_section			= (lstate, pstate)
			# (finfo, pstate)			= showInfo ptr theorem pstate
			# pstate					= changeMarkUpText info_rid finfo pstate
			= (lstate, pstate)
		receiver (CmdRefresh (RenamedTheorem theorem_ptr)) (lstate, pstate)
			| ptr <> theorem_ptr		= (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (finfo, pstate)			= showInfo ptr theorem pstate
			# pstate					= changeMarkUpText info_rid finfo pstate
			= (lstate, pstate)
		receiver (CmdRestoreEditControl text) (lstate, pstate)
			# pstate					= appPIO (setControlText edit_id text) pstate
			# pstate					= appPIO (setEditControlCursor edit_id 1000) pstate
			= (lstate, pstate)
	
		receiver (CmdProveByClicking [KnowArguments tactic]) (lstate, pstate)
			# (_, pstate)					= asyncSend rid (CmdApplyTactic "" tactic) pstate
			= (lstate, pstate)
		receiver (CmdUseHypothesis hyp_ptr) (lstate, pstate)
//			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
//			= (lstate, useHypothesis hyp_ptr ptr theorem theorem.thProof.pCurrentGoal pstate)
			= (lstate, pstate)
		receiver (CmdProveByClicking actions) (lstate, pstate)
			= (lstate, pstate)
		receiver (CmdExecuteCmdLine text dot_pos) (lstate, pstate)
			// temp hack
			| text%(0,4) == "Print"
				# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
				# toProve					= theorem.thProof.pCurrentGoal.glToProve
				# (toProve, pstate)			= accHeapsProject (makePrintable toProve) pstate
				#! pstate					= pstate --->> toProve
				= (lstate, pstate)
			/*
			| text%(0,2) == "toL"
				# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
				# (error, goal, pstate)		= accErrorHeapsProject (convertC2L theorem.thProof.pCurrentGoal) pstate
				| isError error				= (lstate, showError error pstate)
				# theorem					= {theorem & thProof.pCurrentGoal = goal}
				# pstate					= appHeaps (writePointer ptr theorem) pstate
				# pstate					= appPIO (setControlText edit_id "") pstate
				= (lstate, pstate)
			| text%(0,2) == "toC"
				# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
				# (error, goal, pstate)		= accErrorHeapsProject (convertL2C theorem.thProof.pCurrentGoal) pstate
				| isError error				= (lstate, showError error pstate)
				# theorem					= {theorem & thProof.pCurrentGoal = goal}
				# pstate					= appHeaps (writePointer ptr theorem) pstate
				# pstate					= appPIO (setControlText edit_id "") pstate
				= (lstate, pstate)
			*/
			// end temp hack
			#! pstate						= appPIO (setControlText edit_id "") pstate
			# (error, command, pstate)		= buildProofCommand text pstate
			| isError error
				# pstate					= appPIO (setControlText edit_id (text%(0,dot_pos))) pstate
				# lstate					= {lstate & viewIndex = 0}
				# pstate					= showError error pstate
				= (lstate, pstate)
			# command						= set_in_command (text%(0,dot_pos)) command
			# pstate						= {pstate & ls.stRememberedError = OK}
			# (_, pstate)					= asyncSend rid command pstate
			# (error, pstate)				= pstate!ls.stRememberedError
			| isError error
				# pstate					= appPIO (setControlText edit_id (text%(0,dot_pos))) pstate
				# lstate					= {lstate & viewIndex = 0}
				# pstate					= showError error pstate
				= (lstate, pstate)
			= (lstate, pstate)
			where
				set_in_command :: !String !WindowCommand -> WindowCommand
				set_in_command restore (CmdApplyTactic _ tactic)
					= CmdApplyTactic restore tactic
				set_in_command restore (CmdApplyTactical _ tactical)
					= CmdApplyTactical restore tactical
				set_in_command _ command
					= command
		receiver CmdFocusCommandline (lstate, pstate)
			# pstate						= setActiveControl edit_id pstate
			= (lstate, pstate)
		receiver (CmdFocusSubgoal (-1)) (lstate, pstate)		// previous subgoal
			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
			# leafs							= theorem.thProof.pLeafs
			| isEmpty leafs					= (lstate, pstate)
			# leaf_ptr						= findNext theorem.thProof.pCurrentLeaf (reverse leafs)
			# (leaf, pstate)				= accHeaps (readPointer leaf_ptr) pstate
			# goal							= fromLeaf leaf
			# theorem						= {theorem	& thProof.pCurrentGoal	= goal
														, thProof.pCurrentLeaf	= leaf_ptr}
			# pstate						= appHeaps (writePointer ptr theorem) pstate
			= (lstate, refresh_theorem theorem pstate)
		receiver (CmdFocusSubgoal 0) (lstate, pstate)			// next subgoal
			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
			# leafs							= theorem.thProof.pLeafs
			| isEmpty leafs					= (lstate, pstate)
			# leaf_ptr						= findNext theorem.thProof.pCurrentLeaf leafs
			# (leaf, pstate)				= accHeaps (readPointer leaf_ptr) pstate
			# goal							= fromLeaf leaf
			# theorem						= {theorem	& thProof.pCurrentGoal	= goal
														, thProof.pCurrentLeaf	= leaf_ptr}
			# pstate						= appHeaps (writePointer ptr theorem) pstate
			= (lstate, refresh_theorem theorem pstate)
		receiver (CmdFocusSubgoal n) (lstate, pstate)
			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
			# total							= length theorem.thProof.pLeafs
			| (n < 1) || (n > total)
				# error						= [X_Internal "No such goal"]
				# pstate					= {pstate & ls.stRememberedError = error}
				# pstate					= showError error pstate
				= (lstate, pstate)
			# new_leaf						= theorem.thProof.pLeafs !! (n-1)
			# (leaf, pstate)				= accHeaps (readPointer new_leaf) pstate
			# goal							= fromLeaf leaf
			# theorem						= {theorem	& thProof.pCurrentGoal	= goal
														, thProof.pCurrentLeaf	= new_leaf}
			# pstate						= appHeaps (writePointer ptr theorem) pstate
			= (lstate, refresh_theorem theorem pstate)
		receiver (CmdApplyTactic restore tactic) (lstate, pstate)
			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
			# (options, pstate)				= pstate!ls.stOptions
			#! (error, theorem, _, pstate)	= acc3HeapsProject (applyTactic tactic ptr theorem options) pstate
			| isError error
				# pstate					= {pstate & ls.stRememberedError = error, ls.stBusyProving = False}
				# pstate					= showError error pstate
				# pstate					= case restore of
												""		-> pstate
												text	-> appPIO (setControlText edit_id restore) pstate
				= (lstate, pstate)
			# pstate						= appHeaps (writePointer ptr theorem) pstate
			# pstate						= refresh_theorem theorem pstate
			# pstate						= broadcast (Just (WinProof ptr)) (ChangedProof ptr) pstate
			| isEmpty theorem.thProof.pLeafs
				# (dialog_id, pstate)		= accPIO openId pstate
				# dialog					= Dialog "Q.E.D." (     TextControl   "Proof finished! Q.E.D." [] 
																:+: ButtonControl "Ok" [ControlPos (Center, zero), ControlFunction (noLS (closeWindow dialog_id))]
															  ) [WindowClose (noLS (closeWindow dialog_id)), WindowId dialog_id]
				# pstate					= snd (openModalDialog 0 dialog pstate)
				# pstate					= broadcast (Just (WinProof ptr)) (ChangedProofStatus ptr) pstate
				= (lstate, pstate)
			= (lstate, pstate)
		receiver (CmdApplyTactical restore tactical) (lstate, pstate)
			# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
			# (all_theorems, pstate)		= allTheorems pstate
			# (options, pstate)				= pstate!ls.stOptions
			# (error, theorem, _, pstate)	= acc3HeapsProject (applyTactical tactical ptr all_theorems theorem options) pstate
			| isError error
				# pstate					= {pstate & ls.stRememberedError = error}
				# pstate					= showError error pstate
				# pstate					= case restore of
												""		-> pstate
												text	-> appPIO (setControlText edit_id restore) pstate
				= (lstate, pstate)
			# pstate						= appHeaps (writePointer ptr theorem) pstate
			# pstate						= refresh_theorem theorem pstate
			# pstate						= broadcast (Just (WinProof ptr)) (ChangedProof ptr) pstate
			| isEmpty theorem.thProof.pLeafs
				# (dialog_id, pstate)		= accPIO openId pstate
				# dialog					= Dialog "Q.E.D." (     TextControl   "Proof finished! Q.E.D." [] 
																:+: ButtonControl "Ok" [ControlPos (Center, zero), ControlFunction (noLS (closeWindow dialog_id))]
															  ) [WindowClose (noLS (closeWindow dialog_id)), WindowId dialog_id]
				# pstate					= snd (openModalDialog 0 dialog pstate)
				# pstate					= broadcast (Just (WinProof ptr)) (ChangedProofStatus ptr) pstate
				= (lstate, pstate)
			= (lstate, pstate)
		receiver (CmdShowDefinition ptr) (lstate, pstate)
			# pstate					= showDefinition ptr pstate
			= (lstate, pstate)
		receiver CmdShowVariableTypes (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (error, sub, _, pstate)	= acc3HeapsProject (wellTyped theorem.thProof.pCurrentGoal) pstate
			| isError error
				# pstate				= {pstate & ls.stRememberedError = error}
				# pstate				= showError error pstate
				= (lstate, pstate)
			#! pstate					= showTypingInfo sub (reverse theorem.thProof.pCurrentGoal.glExprVars) pstate
			= (lstate, pstate)
		receiver (CmdUndoTactics count) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (error, proof, pstate)	= accErrorHeaps (undoProofSteps count theorem.thProof) pstate
			| isError error
				# pstate				= {pstate & ls.stRememberedError = error}
				# pstate				= showError error pstate
				= (lstate, pstate)
			# theorem					= {theorem & thProof = proof}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= resetDependencies ptr pstate
			# pstate					= refresh_theorem theorem pstate
			# pstate					= broadcast (Just (WinProof ptr)) (ChangedProof ptr) pstate
			= (lstate, pstate)
		receiver CmdRestartProof (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# was_qed					= isEmpty theorem.thProof.pLeafs
			# (fresh, pstate)			= accHeaps (FreshVars theorem.thInitial) pstate
			# first_goal				= {DummyValue & glToProve = fresh}
			# (leaf, pstate)			= accHeaps (newPointer (ProofLeaf first_goal)) pstate
			# proof						=	{ pTree				= leaf
											, pLeafs			= [leaf]
											, pCurrentLeaf		= leaf
											, pCurrentGoal		= first_goal
											, pFoldedNodes		= []
											, pUsedTheorems		= []
											, pUsedSymbols		= []
											}
			# theorem					= {theorem & thProof = proof}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= resetDependencies ptr pstate
			# pstate					= refresh_theorem theorem pstate
			# pstate					= broadcast (Just (WinProof ptr)) (ChangedProof ptr) pstate
			# pstate					= case was_qed of
											True	-> broadcast (Just (WinProof ptr)) (ChangedProofStatus ptr) pstate
											False	-> pstate
			= (lstate, pstate)
		receiver CmdDebug (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (print, pstate)			= accHeapsProject (makePrintable theorem.thProof.pCurrentGoal.glToProve) pstate
			#! pstate					= pstate --->> print
			= (lstate, pstate)
		receiver cmd (lstate, pstate)
			= (lstate, pstate)























// ------------------------------------------------------------------------------------------------------------------------
showInfo :: !TheoremPtr !Theorem !*PState -> (!MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showInfo ptr theorem pstate
	# section_ptr							= theorem.thSection
	# (section, pstate)						= accHeaps (readPointer section_ptr) pstate
	# (info_font, info_code)				= IconSymbol InfoIcon
	# (view_font, view_code)				= IconSymbol ViewContentsIcon
	# ftheorem								=	[ CmRight
												, CmBText				"Theorem:"
												, CmSpaces				1
												, CmAlign				"@RHS"
												, CmBackgroundColour	InfoBG
												, CmText				theorem.thName
												, CmSpaces				1
												, CmFontFace			info_font
												, CmLink2				0 {toChar info_code} (CmdShowTheorem ptr)
												, CmEndFontFace
												, CmFillLine
												, CmEndBackgroundColour
												]
	# fsection								=	[ CmRight
												, CmBText				"in section:"
												, CmSpaces				1
												, CmAlign				"@RHS"
												, CmBackgroundColour	InfoBG
												, CmText				section.seName
												, CmSpaces				1
												, CmFontFace			view_font
												, CmLink2				0 {toChar view_code} (CmdShowSectionContents theorem.thSection)
												, CmEndFontFace
												, CmFillLine
												, CmEndBackgroundColour
												]
	# nr_subgoals							= length theorem.thProof.pLeafs
	# index									= findPtr 1 theorem.thProof.pCurrentLeaf theorem.thProof.pLeafs
	# index_text							= if (nr_subgoals > 0)
												("subgoal " +++ toString index +++ " of " +++ toString nr_subgoals)
												("no more subgoals")
	# fproving								=	[ CmRight
												, CmBText				"proving:"
												, CmSpaces				1
												, CmAlign				"@RHS"
												, CmBackgroundColour	InfoBG
												, CmText				index_text
												, CmSpaces				1
												, CmIText				"(see below)"
												, CmFillLine
												, CmEndBackgroundColour
												]
	= (ftheorem ++ [CmNewlineI False 3 Nothing] ++ fsection ++ [CmNewlineI False 3 Nothing] ++ fproving, pstate)
	where
		findPtr :: !Int !ProofTreePtr ![ProofTreePtr] -> Int
		findPtr num the_ptr [ptr:ptrs]
			| ptr == the_ptr	= num
			= findPtr (num+1) the_ptr ptrs
		findPtr num the_ptr []
			= 0

// ------------------------------------------------------------------------------------------------------------------------
showSubgoals :: !FormatInfo !Proof !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showSubgoals finfo proof pstate
	# fproven								=	[ CmBackgroundColour		HighlightBG
												, CmSpaces					1
												, CmFontFace				"Wingdings"
												, CmText					{toChar 159}
												, CmEndFontFace
												, CmSpaces					1
												, CmFontFace				"Times New Roman"
												, CmIText					"all subgoals have been proven!"
												, CmEndFontFace
												, CmFillLine
												, CmEndBackgroundColour
												]
	| isEmpty proof.pLeafs					= (OK, fproven, pstate)
	= accErrorHeapsProject (show 0 proof.pLeafs) pstate
	where
		show :: !Int ![ProofTreePtr] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		show num [ptr:ptrs] heaps prj
			# (leaf, heaps)					= readPointer ptr heaps
			# goal							= fromLeaf leaf
			# (error, ftoprove, heaps, prj)	= FormattedShow finfo goal.glToProve heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			# ftoprove						=	[ CmColour					Grey
												: normalize ftoprove
												] ++
												[ CmEndColour
												]
			# fstart						= case (ptr == proof.pCurrentLeaf) of
												True	->	[ CmLabel					"@CURRENT" False
															, CmBackgroundColour		HighlightBG
															, CmSpaces					1
															, CmFontFace				"Wingdings"
															, CmText					{toChar 159}
															, CmEndFontFace
															, CmSpaces					1
															, CmFontFace				"Times New Roman"
															, CmItalic
															, CmText					("subgoal " +++ toString (num+1) +++ ":")
															, CmEndItalic
															, CmEndFontFace
															, CmSpaces					1
															, CmAlign					"@PROP"
															]
												False	->	[ CmBackgroundColour		ControlBG
															, CmSpaces					1
															, CmFontFace				"Wingdings"
															, CmText					{toChar 159}
															, CmEndFontFace
															, CmSpaces					1
															, CmFontFace				"Times New Roman"
															, CmItalic
															, CmLink					("subgoal " +++ toString (num+1) +++ ":") (CmdFocusSubgoal (num+1))
															, CmEndItalic
															, CmEndFontFace
															, CmSpaces					1
															, CmAlign					"@PROP"
															]
			# fend							=	[ CmFillLine
												, CmEndBackgroundColour
												, CmNewlineI				False 1 Nothing
												]
			# fsubgoal						= fstart ++ ftoprove ++ fend
			# (error, frest, heaps, prj)	= show (num+1) ptrs heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			= (OK, fsubgoal ++ frest, heaps, prj)
		show num [] heaps prj
			= (OK, [], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------
showExprVars :: !FormatInfo ![CExprVarPtr] ![CTypeH] ![CExprVarPtr] ![CExprVarPtr] !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showExprVars finfo [] [] defs undefs pstate
	= (OK, [], pstate)
showExprVars finfo [ptr:ptrs] [type:types] defs undefs pstate
	# (error, fname, pstate)				= accErrorHeapsProject (FormattedShow finfo (make_expr_var ptr)) pstate
	| isError error							= (error, DummyValue, pstate)
	# (error, ftype, pstate)				= accErrorHeapsProject (FormattedShow finfo type) pstate
	| isError error							= (error, DummyValue, pstate)
	# fname									= normalize fname
	# fdefined								= case isMember ptr defs of
												True	-> case isMember ptr undefs of
															True	-> [CmColour Brown, CmText "(both defined and undefined)", CmEndColour]
															False	-> [CmColour LogicColour, CmText "(defined)", CmEndColour]
												False	-> case isMember ptr undefs of
															True	-> [CmColour Red, CmText "(undefined)", CmEndColour]
															False	-> []
	# fvar									=	[ CmTabSpace
												, CmBold
												: fname
												] ++
												[ CmEndBold
												, CmAlign		"@TYPE"
												, CmSpaces		1
												, CmText		"::"
												, CmSpaces		1
												: ftype
												] ++
												[ CmAlign		"@DEFINED"
												, CmSpaces		2
												: fdefined
												] ++
												[ CmNewline
												]
	# (error, fvars, pstate)				= showExprVars finfo ptrs types defs undefs pstate
	| isError error							= (error, DummyValue, pstate)
	= (OK, fvar ++ fvars, pstate)
	where
		// needed to build a (CExpr HeapPtr) instead of a (CExpr a)
		make_expr_var :: !CExprVarPtr -> CExprH
		make_expr_var ptr
			= CExprVar ptr

// ------------------------------------------------------------------------------------------------------------------------
showPropVars :: !FormatInfo ![CPropVarPtr] !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showPropVars finfo [] pstate
	= (OK, [], pstate)
showPropVars finfo [ptr:ptrs] pstate
	# (error, fname, pstate)				= accErrorHeapsProject (FormattedShow finfo (make_prop_var ptr)) pstate
	| isError error							= (error, DummyValue, pstate)
	# fname									= normalize fname
	# fvar									=	[ CmTabSpace
												, CmBold
												: fname
												] ++
												[ CmEndBold
												, CmAlign		"@TYPE"
												, CmSpaces		1
												, CmText		"::"
												, CmSpaces		1
												, CmColour		LogicColour
												, CmText		"PROP"
												, CmEndColour
												, CmNewline
												]
	# (error, fvars, pstate)				= showPropVars finfo ptrs pstate
	| isError error							= (error, DummyValue, pstate)
	= (OK, fvar ++ fvars, pstate)
	where
		// needed to get (CProp HeapPtr) instead of most general type (CProp a)
		make_prop_var :: !CPropVarPtr -> CPropH
		make_prop_var ptr
			= CPropVar ptr

// ------------------------------------------------------------------------------------------------------------------------
showHyps :: !FormatInfo ![HypothesisPtr] !Goal !*PState -> (!Error, !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showHyps finfo [] goal pstate
	= (OK, [CmTabSpace, CmIText "none", CmNewline], pstate)
showHyps finfo [ptr:ptrs] goal pstate
	# (hyp, pstate)							= accHeaps (readPointer ptr) pstate
	# (aprop, pstate)						= annotateHypothesis ptr hyp.hypProp goal pstate
	# (error, fprop, pstate)				= showAnnotated finfo aprop pstate
	| isError error							= (error, DummyValue, pstate)
//	# (equal, pstate)						= accHeaps (AlphaEqual hyp.hypProp goal.glToProve) pstate
//	# exact_action							= [KnowArguments (TacticExact (HypothesisFact ptr []))]
//	# exact_link							= CmdProveByClicking exact_action
	# fprop									= [CmTabSpace, CmBold, CmLink2 2 (hyp.hypName +++ ":") (CmdUseHypothesis ptr), CmEndBold, CmAlign "@PROP", CmSpaces 1: fprop]
	| isEmpty ptrs							= (OK, fprop ++ [CmNewline], pstate)
	# (error, fprops, pstate)				= showHyps finfo ptrs goal pstate
	| isError error							= (error, DummyValue, pstate)
	= (OK, fprop ++ [CmNewline:fprops], pstate)

// ------------------------------------------------------------------------------------------------------------------------
showToProve :: !FormatInfo !Theorem !*PState -> (!Error, !(!Bool, !DefinednessInfo), !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------
showToProve finfo theorem pstate
	# (error, sub, info, pstate)			= acc3HeapsProject (wellTyped theorem.thProof.pCurrentGoal) pstate
	#! pstate								= case isError error of
												True	-> let (print, pstate2) = accHeapsProject (makePrintableI info) pstate
															in showError error (pstate2 --->> print)
												False	-> pstate
//	| isError error							= (error, DummyValue, pstate)
	# proof									= theorem.thProof
	| isEmpty proof.pLeafs					= (OK, (False, DummyValue), [CmColour LogicColour, CmBText "Q.E.D.", CmEndColour], pstate)
	# goal									= proof.pCurrentGoal
	#! pstate								= appProject (setManualDefinedness goal) pstate
	# (con, definedness_info, pstate)		= acc2HeapsProject (findDefinednessInfo goal) pstate
	#! pstate								= appProject (unsetManualDefinedness goal) pstate
	# defined_vars							= definedness_info.definedVariables
	# undefined_vars						= definedness_info.undefinedVariables
	// expr-vars
	# expr_vars								= reverse goal.glExprVars
	# top_vars								= get_top_vars goal.glToProve
	# (vars, pstate)						= accHeaps (readPointers expr_vars) pstate
	# (tops, pstate)						= accHeaps (readPointers top_vars) pstate
	# types									= [SimpleSubst sub (get_type var.evarInfo) \\ var <- vars]
	# top_types								= [SimpleSubst sub (get_type var.evarInfo) \\ var <- tops]
	# (ptr_info, pstate)					= accHeaps (GetPtrInfo types) pstate
	# (ptr_info, pstate)					= accHeaps (getPtrInfo top_types ptr_info) pstate
	# used_type_vars						= ptr_info.freeTypeVars
	# (new_type_vars, pstate)				= accHeaps (build_vars (take (length used_type_vars) ['abcdefghijklmnopqrstuvwxyz'])) pstate
	# sub_names								= {DummyValue & subTypeVars = zip2 used_type_vars [CTypeVar new_var \\ new_var <- new_type_vars]}
	# types									= SimpleSubst sub_names types
	# top_types								= SimpleSubst sub_names top_types
	# (finfo, pstate)						= accHeaps (storeExprVars expr_vars finfo) pstate
	# (error, fvars1, pstate)				= showExprVars finfo expr_vars types defined_vars undefined_vars pstate
	| isError error							= (error, DummyValue, DummyValue, pstate)
	// prop-vars
	# prop_vars								= reverse goal.glPropVars
	# (finfo, pstate)						= accHeaps (storePropVars prop_vars finfo) pstate
	# (error, fvars2, pstate)				= showPropVars finfo prop_vars pstate
	| isError error							= (error, DummyValue, DummyValue, pstate)
	# (atoprove, pstate)					= annotateGoal goal.glToProve goal pstate
	# (error, ftoprove, pstate)				= showAnnotated {finfo & fiIndentQuantors = True, fiIndentImplies = True, fiIndentEqual = True, fiPrettyTypes = top_types} atoprove pstate
	| isError error							= (error, DummyValue, DummyValue, pstate)
	# fvars									= fvars1 ++ fvars2
	// hypotheses
	# (error, fhyps, pstate)				= showHyps finfo (reverse goal.glHypotheses) proof.pCurrentGoal pstate
	| isError error							= (error, DummyValue, DummyValue, pstate)
	// wrap-ip
	# fvars									= case (isEmpty expr_vars) && (isEmpty prop_vars) of
												True	-> [CmTabSpace, CmIText "none", CmNewline]
												False	-> fvars
	# fvars									= [CmSpaces 1, CmFontFace "Times New Roman", CmUnderline, CmIText "Assume variables:", CmEndUnderline, CmEndFontFace, CmNewline: fvars]
	# fhyps									= [CmSpaces 1, CmFontFace "Times New Roman", CmUnderline, CmIText "Assume hypotheses:", CmEndUnderline, CmEndFontFace, CmNewline: fhyps]
	# fstart								= fvars ++ fhyps
	# fstart								= if (isEmpty fstart) [CmTabSpace, CmText "-", CmNewline] fstart
	# fmiddle								= [CmBold, CmLink2 3 "|==============================================================================================================================================" CmdRefreshAlways, CmEndBold, CmNewlineI True 0 Nothing]
	# fend									= [CmTabSpace, CmScope:ftoprove] ++ [CmEndScope]
	= (OK, (con, definedness_info), fstart ++ fmiddle ++ fend, pstate)
	where
		get_top_vars :: !CPropH -> [CExprVarPtr]
		get_top_vars (CExprForall var p)
			= [var: get_top_vars p]
		get_top_vars (CExprExists var p)
			= [var: get_top_vars p]
		get_top_vars (CPropForall var p)
			= get_top_vars p
		get_top_vars (CPropExists var p)
			= get_top_vars p
		get_top_vars other
			= []
	
		get_type :: !CExprVarInfo -> CTypeH
		get_type (EVar_Type type)			= type
		get_type _							= CUnTypable
		
		build_vars :: ![Char] !*CHeaps -> (![CTypeVarPtr], !*CHeaps)
		build_vars [name:names] heaps
			# new_var						= {DummyValue & tvarName = {name}}
			# (new_ptr, heaps)				= newPointer new_var heaps
			# (new_ptrs, heaps)				= build_vars names heaps
			= ([new_ptr:new_ptrs], heaps)
		build_vars [] heaps
			= ([], heaps)
		
		scan_for_vars :: ![CExprH] -> [CExprVarPtr]
		scan_for_vars [CExprVar ptr: exprs]	= [ptr: scan_for_vars exprs]
		scan_for_vars [_:exprs]				= scan_for_vars exprs
		scan_for_vars []					= []

// ------------------------------------------------------------------------------------------------------------------------
showTypingInfo :: !Substitution ![CExprVarPtr] !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------
showTypingInfo sub vars pstate
	| isEmpty vars							= showError [X_Type "No variables introduced."] pstate
	# (var_names, types, pstate)			= acc2Heaps (make_types vars sub) pstate
	# (ptr_info, pstate)					= accHeaps (GetPtrInfo types) pstate
	# used_type_vars						= ptr_info.freeTypeVars
	# (new_type_vars, pstate)				= accHeaps (build_vars (take (length used_type_vars) ['abcdefghijklmnopqrstuvwxyz'])) pstate
	# sub_names								= {DummyValue & subTypeVars = zip2 used_type_vars [CTypeVar new_var \\ new_var <- new_type_vars]}
	# types									= SimpleSubst sub_names types
	# (finfo, pstate)						= makeFormatInfo pstate
	# (ftext, pstate)						= show finfo var_names types pstate
	= MarkUpWindow "Typing information" ftext
		[ MarkUpFontFace			"Courier New"
		, MarkUpTextSize			10
		, MarkUpBackgroundColour	BlueLightBG
		]
		[] pstate
	where
		make_types :: ![CExprVarPtr] !Substitution !*CHeaps -> (![CName], ![CTypeH], !*CHeaps)
		make_types [ptr:ptrs] sub heaps
			# (var, heaps)					= readPointer ptr heaps
			# type							= read_type var.evarInfo
			# type							= SimpleSubst sub type
			# (names, types, heaps)			= make_types ptrs sub heaps
			= ([var.evarName:names], [type:types], heaps)
			where
				read_type :: !CExprVarInfo -> CTypeH
				read_type (EVar_Type type)	= type
				read_type other				= CUnTypable
		make_types [] sub heaps
			= ([], [], heaps)
		
		build_vars :: ![Char] !*CHeaps -> (![CTypeVarPtr], !*CHeaps)
		build_vars [name:names] heaps
			# new_var						= {DummyValue & tvarName = {name}}
			# (new_ptr, heaps)				= newPointer new_var heaps
			# (new_ptrs, heaps)				= build_vars names heaps
			= ([new_ptr:new_ptrs], heaps)
		build_vars [] heaps
			= ([], heaps)
	
		show :: !FormatInfo ![CName] ![CTypeH] !*PState -> (!MarkUpText WindowCommand, !*PState)
		show finfo [name:names] [type:types] pstate
			# (_, ftype, pstate)			= accErrorHeapsProject (FormattedShow finfo type) pstate
			# ftext							= [CmBText name, CmAlign "1", CmBText " :: ", CmAlign "2"] ++ ftype ++ [CmNewline]
			# (ftexts, pstate)				= show finfo names types pstate
			= (ftext ++ ftexts, pstate)
		show finfo [] [] pstate
			= ([], pstate)