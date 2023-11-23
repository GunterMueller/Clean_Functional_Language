/*
** Program: Clean Prover System
** Module:  ShowTheorem (.icl)
** 
** Author:  Maarten de Mol
** Created: 19 January 2000
*/

implementation module 
	ShowTheorem

import 
	StdEnv,
	StdIO,
	ossystem,
	MdM_IOlib,
	Depends,
	Hints,
	States,
	ShowDefinition,
	ShowProof,
	Operate,
	GoalPath,
	BindLexeme
from StdFunc import seq

// -------------------------------------------------------------------------------------------------------------------------------------------------
HiddenFG								:== RGB {r=180, g=180, b=120}
BG										:== RGB {r=210, g=210, b=150}
ControlBG								:== RGB {r=230, g=230, b=170}
InfoBG									:== RGB {r=220, g=220, b=160}
IconFG									:== RGB {r=170, g=170, b=110}
MyRed									:== RGB {r=250, g=220, b=160}
MyGreen									:== RGB {r=220, g=250, b=160}
IndentFG								:== RGB {r=255, g=180, b=120}
// -------------------------------------------------------------------------------------------------------------------------------------------------


// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize :: !(MarkUpText a) -> MarkUpText a
// -------------------------------------------------------------------------------------------------------------------------------------------------
normalize [CmColour _:rest]					= normalize rest
normalize [CmEndColour:rest]				= normalize rest
normalize [CmBackgroundColour _:ftext]		= normalize ftext
normalize [CmEndBackgroundColour:ftext]		= normalize ftext
normalize [CmBold:rest]						= normalize rest
normalize [CmEndBold:rest]					= normalize rest
normalize [CmItalic:ftext]					= normalize ftext
normalize [CmEndItalic:ftext]				= normalize ftext
normalize [CmBText text:rest]				= [CmText text: normalize rest]
normalize [CmIText text:rest]				= [CmText text: normalize rest]
normalize [CmUText text:rest]				= [CmText text: normalize rest]
normalize [CmLink text _:rest]				= [CmText text: normalize rest]
normalize [CmAlignI _ _: rest]				= normalize rest
normalize [CmNewlineI _ _ _: rest]			= [CmText " ": normalize rest]
normalize [CmScope: rest]					= normalize rest
normalize [CmEndScope: rest]				= normalize rest
normalize [CmTabSpace: rest]				= [CmText " ": normalize rest]
normalize [other:rest]						= [other:normalize rest]
normalize []								= []


































// -------------------------------------------------------------------------------------------------------------------------------------------------
openTheorem :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
openTheorem ptr pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	= showTheorem ptr theorem pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheorem :: !TheoremPtr !Theorem !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheorem ptr theorem pstate
	# (opened, pstate)					= isWindowOpened (WinTheorem ptr) True pstate
	| opened							= pstate
	# (winfo, pstate)					= new_Window (WinTheorem ptr) pstate
	# id								= winfo.wiWindowId
	# rid								= fromJust winfo.wiNormalRId
	# (info_rid, pstate)				= accPIO openRId pstate
	# proof_id							= fromJust winfo.wiControlId
	# (proof_rid, pstate)				= accPIO openRId pstate
	# (status_rid, pstate)				= accPIO openRId pstate
	# (sliders_id, pstate)				= accPIO openButtonId pstate
	# (fold_id, pstate)					= accPIO openButtonId pstate
	# (unfold_id, pstate)				= accPIO openButtonId pstate
	# (toggle_id, pstate)				= accPIO openButtonId pstate
	# (restart_id, pstate)				= accPIO openButtonId pstate
	# window_pos						= winfo.wiStoredPos
	# control_width						= winfo.wiStoredWidth
	# control_height					= winfo.wiStoredHeight
	# (window, pstate)					= theoremWindow ptr theorem id rid info_rid proof_id proof_rid status_rid sliders_id fold_id unfold_id toggle_id restart_id window_pos control_width control_height pstate
	= snd (openWindow 0 window pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheoremInfo :: !TheoremPtr !Theorem ![TheoremPtr] ![TheoremPtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showTheoremInfo ptr theorem true false pstate
	# (section, pstate)					= accHeaps (readPointer theorem.thSection) pstate
	# (recycle_font, recycle_code)		= IconSymbol RecycleIcon
	# (rename_font, rename_code)		= IconSymbol RenameIcon
	# (move_font, move_code)			= IconSymbol MoveIcon
	# (remove_font, remove_code)		= IconSymbol RemoveIcon
	# (view_font, view_code)			= IconSymbol ViewContentsIcon
	# fname								=	[ CmRight
											, CmBText				"Theorem:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				theorem.thName
											, CmSpaces				1
											, CmFontFace			rename_font
											, CmLink2				0 {toChar rename_code} (CmdRenameTheorem ptr)
											, CmEndFontFace
											, CmFontFace			remove_font
											, CmLink2				1 {toChar remove_code} (CmdRemoveTheorem ptr)
											, CmEndFontFace
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fsection							=	[ CmRight
											, CmBText				"in section:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				section.seName
											, CmSpaces				1
											, CmFontFace			view_font
											, CmLink2				0 {toChar view_code} (CmdShowSectionContents theorem.thSection)
											, CmEndFontFace
											, CmFontFace			move_font
											, CmLink2				0 {toChar move_code} (CmdMoveTheorem ptr)
											, CmEndFontFace
											, CmFillLine
											, CmEndBackgroundColour
											]
	# used_theorems						= theorem.thProof.pUsedTheorems
	# used_functions					= [ptr \\ ptr <- theorem.thProof.pUsedSymbols | ptrKind ptr == CFun]
	# used_conses						= [ptr \\ ptr <- theorem.thProof.pUsedSymbols | ptrKind ptr == CDataCons]
	# fused								=	[ CmRight
											, CmBText				"uses:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				(mul_text (length used_theorems) "theorem")
											, CmText				", "
											, CmText				(mul_text (length used_functions) "function")
											, CmText				", "
											, CmText				(mul_text (length used_conses) "constructor")
											, CmIText				" (see below)"
											, CmFillLine
											, CmEndBackgroundColour
											]
	# (used_by_ptrs, pstate)			= theoremsUsingTheorem ptr pstate
	# fused_by							=	[ CmRight
											, CmBText				"used by:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											, CmText				(mul_text (length used_by_ptrs) "theorem")
											, CmSpaces				1
											, CmFontFace			recycle_font
											, CmLink2				0 {toChar recycle_code} (CmdShowTheoremsUsing ptr)
											, CmEndFontFace
											, CmFillLine
											, CmEndBackgroundColour
											]
	# fhints							= case theorem.thHintScore of
											Nothing				->	[ CmText		"This theorem is not used as a hint."
																	]
											Just (a,af,lr,rl)	->	[ CmText		"apply:"
																	, CmColour		Blue
																	, CmText		(toString a)
																	, CmEndColour
																	, CmSpaces		1
																	, CmText		"apply forward:"
																	, CmColour		Blue
																	, CmText		(toString af)
																	, CmEndColour
																	, CmSpaces 		1
																	, CmText		"rewrite-lr:"
																	, CmColour		Blue
																	, CmText		(toString lr)
																	, CmEndColour
																	, CmSpaces 		1
																	, CmText		"rewrite-rl:"
																	, CmColour		Blue
																	, CmText		(toString rl)
																	, CmEndColour
																	]
	# fhints							= 	[ CmRight
											, CmBText				"hint scores:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	InfoBG
											: fhints
											] ++
											[ CmSpaces				1
											, CmSize				8
											, CmBold
											, CmLink2				0 "change" (CmdChangeHintScores ptr)
											, CmEndBold
											, CmEndSize
											, CmFillLine
											, CmEndBackgroundColour
											]
	# status_colour						= case isEmpty theorem.thProof.pLeafs of
											True	-> case isEmpty false of
														True	-> MyGreen
														False	-> MyRed
											False	-> MyRed
	# status_text						= case isEmpty theorem.thProof.pLeafs of
											True	-> case isEmpty false of
														True	-> "Q.E.D."
														False	-> "not all used theorems have been proved"
											False	-> "proof is not complete"
	# fstatus							=	[ CmRight
											, CmBText				"status:"
											, CmSpaces				1
											, CmAlign				"@RHS"
											, CmBackgroundColour	status_colour
											, CmText				status_text
											, CmFillLine
											, CmEndBackgroundColour
											]
	= (fname		++ [CmNewlineI False 3 Nothing] ++
	   fsection		++ [CmNewlineI False 3 Nothing] ++ 
	   fused		++ [CmNewlineI False 3 Nothing] ++ 
	   fused_by		++ [CmNewlineI False 3 Nothing] ++ 
	   fhints		++ [CmNewlineI False 3 Nothing] ++
	   fstatus		++ [CmNewlineI False 3 Nothing], pstate)
	where
		mul_text :: !Int !String -> String
		mul_text 1 text
			= "1 " +++ text
		mul_text n text
			= toString n +++ " " +++ text +++ "s"

/*
// -------------------------------------------------------------------------------------------------------------------------------------------------
//testWindow1 :: 
// -------------------------------------------------------------------------------------------------------------------------------------------------
testWindow1 pstate
	# (id, pstate)						= accPIO openId pstate
	# (_, pstate)						= openWindow 0 (window id) pstate
	= pstate
	where
		window id						= Window "TEST1" NilLS
											[	WindowClose			(noLS (closeWindow id))
											,	WindowId			id
											,	WindowLook			True (\_ _ -> look)
											,	WindowViewSize		{w = 200, h = 18}
											]
		
		look pic
			# pic						= setPenColour Red pic
			# pic						= drawLine {x=0,y=0} {x=99,y=0} pic
			# pic						= setPenColour Green pic
			# pic						= drawLine {x=0,y=1} {x=99,y=1} pic
			# pic						= drawLine {x=0,y=16} {x=99,y=16} pic
			# pic						= setPenColour Red pic
			# pic						= drawLine {x=0,y=17} {x=99,y=17} pic
			# pic						= setPenColour Black pic
			# ((_, font), pic)			= openFont {fName = "Courier New", fSize = 10, fStyles = []} pic
			# pic						= setPenFont font pic
			# pic						= drawAt {x=0,y=14} ("|_A" +++ {fromInt a \\ a <- [197, 184]}) pic
			# ((_, font), pic)			= openFont {fName = "Courier New", fSize = 10, fStyles = ["Bold"]} pic
			# pic						= setPenFont font pic
			# pic						= drawAt {x=100,y=13} ("|_A" +++ {fromInt a \\ a <- [197, 184]}) pic
			= pic

// -------------------------------------------------------------------------------------------------------------------------------------------------
//testWindow2 :: 
// -------------------------------------------------------------------------------------------------------------------------------------------------
testWindow2 pstate
	# (id, pstate)						= accPIO openId pstate
	# (_, pstate)						= openWindow 0 (window id) pstate
	= pstate
	where
		window id						= Window "TEST2" NilLS
											[	WindowClose			(noLS (closeWindow id))
											,	WindowId			id
											,	WindowLook			True (\_ _ -> look)
											,	WindowViewSize		{w = 100, h = 20}
											]
		
		look pic
			# ((_, font), pic)			= openFont {fName = "Symbol", fSize = 10, fStyles = []} pic
			# pic						= setPenFont font pic
			# pic						= setPenColour Red pic
			# pic						= drawLine {x=0,y=0} {x=99,y=0} pic
			# pic						= setPenColour Green pic
			# pic						= drawLine {x=0,y=1} {x=99,y=1} pic
			# pic						= drawLine {x=0,y=18} {x=99,y=18} pic
			# pic						= setPenColour Red pic
			# pic						= drawLine {x=0,y=19} {x=99,y=19} pic
			# pic						= setPenColour Black pic
			# pic						= drawAt {x=0,y=16} ("|_A" +++ {fromInt a \\ a <- [95, 96, 189]}) pic
			= pic
*/

// -------------------------------------------------------------------------------------------------------------------------------------------------
//theoremWindow :: !TheoremPtr !Theorem !Id !(RId WindowCommand) _ !Id _ _ !ButtonId !ButtonId !ButtonId !Vector2 !Int !Int !*PState -> (_, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
theoremWindow ptr theorem id rid info_rid proof_id proof_rid status_rid sliders_id fold_id unfold_id toggle_id restart_id pos width height pstate
	# (section_name, pstate)			= accHeaps (getPointerName theorem.thSection) pstate
	# (metrics, _)						= osDefaultWindowMetrics 42
	# the_controls						= controls metrics width height
	# (real_size, pstate)				= controlSize the_controls True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)						= case (pos.vx == (-1) && pos.vy == (-1)) of
											True	-> placeWindow real_size pstate
											False	-> (pos, pstate)
	=	( Window ("Theorem Info (" +++ theorem.thName +++ ")") the_controls
			[ WindowId					id
			, WindowClose				(noLS (close_Window (WinTheorem ptr)))
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour BG, fill newFrame])
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowInit				(noLS refreshAll)
			, WindowViewSize			real_size
			, WindowPos					(LeftTop, OffsetVector pos)
			]
		, pstate
		)
	where
		controls metrics width height
			= 		Receiver			rid receiver []
				:+:	MarkUpControl		[CmText "?"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpFixMetrics			{fName = "Times New Roman", fStyles = [], fSize = 10}
											, MarkUpBackgroundColour	BG
											, MarkUpWidth				(width + 2 + metrics.osmVSliderWidth)
											, MarkUpNrLinesI			6 15
											, MarkUpReceiver			info_rid
											, MarkUpLinkStyle			False IconFG InfoBG False Blue InfoBG
											, MarkUpLinkStyle			False IconFG InfoBG False Red InfoBG
											, MarkUpEventHandler		(clickHandler globalEventHandler)
											]
				  							[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
				  							]
				:+:	boxedMarkUp			Black ResizeHorVer [CmText "?"]
											[ MarkUpWidth				width
											, MarkUpHeight				height
											, MarkUpBackgroundColour	ControlBG
											, MarkUpFontFace			"Courier New"
											, MarkUpTextSize			10
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpReceiver			proof_rid
//				  							, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
				  							, MarkUpLinkStyle			False BG ControlBG False Black ControlBG
				  							, MarkUpLinkStyle			False Brown ControlBG False Blue ControlBG
				  							, MarkUpLinkStyle			False Black ControlBG False Green BG
				  							, MarkUpLinkStyle			False Black ControlBG False Red BG
				  							, MarkUpEventHandler		(sendHandler rid)
											]
											[ ControlPos				(Left, zero)
											, ControlId					proof_id
											]
				:+:	boxedMarkUp			Black ResizeHor [CmIText "?"]
											[ MarkUpReceiver			status_rid
											, MarkUpWidth				width
											, MarkUpNrLines				6
											, MarkUpBackgroundColour	BG
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpHScroll
											, MarkUpVScroll
				  							, MarkUpLinkStyle			False Black MyGreen False Blue MyGreen
				  							, MarkUpLinkStyle			False Black MyRed False Blue MyRed
				  							, MarkUpLinkStyle			False Black ControlBG False Blue ControlBG
				  							, MarkUpEventHandler		(clickHandler globalEventHandler)
											]
											[ ControlPos				(Left, zero)
				  							, ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
											]
				:+: MarkUpButton		"reset sliders" BG (redrawMarkUpSliders proof_rid o redrawMarkUpSliders status_rid) sliders_id
											[ ControlPos				(LeftBottom, zero)
											]
				:+:	MarkUpButton		"restart" BG (restart ptr) restart_id
											[ ControlPos				(Right, zero)
											]
				:+:	MarkUpButton		(if theorem.thSubgoals "hide goals" "show goals")
										BG (toggle toggle_id) toggle_id
											[ ControlPos				(LeftOf (fst3 restart_id), zero)
											]
				:+:	MarkUpButton		"unfold all" BG unfold_all unfold_id
											[ ControlPos				(LeftOf (fst3 toggle_id), zero)
											]
				:+:	MarkUpButton		"fold inactive" BG fold_inactive fold_id
											[ ControlPos				(LeftOf (fst3 unfold_id), zero)
											]
				
		go_prove :: !*PState -> *PState
		go_prove pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= openProof ptr theorem pstate
		
		fold_inactive :: !*PState -> *PState
		fold_inactive pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem_proved			= isEmpty theorem.thProof.pLeafs
			| theorem_proved			= unfold_all pstate
			# ((_, fold_ptrs), pstate)	= accHeaps (find_folded False [theorem.thProof.pTree] theorem.thProof.pCurrentLeaf) pstate
			# theorem					= {theorem & thProof.pFoldedNodes = fold_ptrs}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			= refreshProof theorem pstate
			where
				find_folded :: !Bool ![ProofTreePtr] !ProofTreePtr !*CHeaps -> (!(!Bool, ![ProofTreePtr]), !*CHeaps)
				find_folded foldable [] leaf heaps
					= ((False, []), heaps)
				find_folded foldable [ptr:ptrs] leaf heaps
					| ptr == leaf
						# ((_, f), heaps)	= find_folded foldable ptrs leaf heaps
						= ((True, f), heaps)
					# (node, heaps)			= readPointer ptr heaps
					# children				= get_children node
					# ((ok1, f1), heaps)	= find_folded (length children > 1) children leaf heaps
					# f1_extra				= if (foldable && not ok1) [ptr] []
					# ((ok2, f2), heaps)	= find_folded foldable ptrs leaf heaps
					= ((ok1 || ok2, f1 ++ f1_extra ++ f2), heaps)
				
				get_children :: !ProofTree -> [ProofTreePtr]
				get_children (ProofLeaf _)
					= []
				get_children (ProofNode _ _ children)
					= children
		
		unfold_all :: !*PState -> *PState
		unfold_all pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem					= {theorem & thProof.pFoldedNodes = []}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			= refreshProof theorem pstate
		
		toggle :: !ButtonId !*PState -> *PState
		toggle button_id pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# new_mode					= not theorem.thSubgoals
			# theorem					= {theorem & thSubgoals = new_mode}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= refreshProof theorem pstate
			= case new_mode of
				True	-> changeButtonText button_id "hide intermediate goals" pstate
				False	-> changeButtonText button_id "show intermediate goals" pstate
		
		highlightProof :: !Theorem !ProofTreePtr !*PState -> *PState
		highlightProof theorem highlight_ptr pstate
			# (finfo, pstate)			= makeFormatInfo pstate
			# (error, fproof, pstate)	= accErrorHeapsProject (showProof finfo theorem.thSubgoals theorem.thProof theorem.thProof.pCurrentLeaf theorem.thProof.pTree) pstate
			| isError error				= showError error pstate
			# pstate					= changeMarkUpText proof_rid fproof pstate
			= pstate
		
		refreshProof :: !Theorem !*PState -> *PState
		refreshProof theorem pstate
			# (finfo, pstate)			= makeFormatInfo pstate
			# (error, fproof, pstate)	= accErrorHeapsProject (showProof finfo theorem.thSubgoals theorem.thProof theorem.thProof.pCurrentLeaf theorem.thProof.pTree) pstate
			| isError error				= showError error pstate
			# pstate					= changeMarkUpText proof_rid fproof pstate
			= pstate
		
		refreshRest :: !Theorem !*PState -> *PState
		refreshRest theorem pstate
			# (_, true, false, pstate)	= isTheoremProved ptr pstate
			# (finfo, pstate)			= showTheoremInfo ptr theorem true false pstate
			# pstate					= changeMarkUpText info_rid finfo pstate
			# (fstatus, pstate)			= showUsed theorem true false pstate
			# pstate					= changeMarkUpText status_rid fstatus pstate
			= pstate
		
		refreshAll :: !*PState -> *PState
		refreshAll pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# pstate					= refreshProof theorem pstate
			# pstate					= refreshRest theorem pstate
			= pstate
		
		receiver :: !WindowCommand !(!a, !*PState) -> (!a, !*PState)
		receiver CmdRefreshAlways (lstate, pstate)
			= (lstate, refreshAll pstate)
		receiver (CmdRefresh ChangedDisplayOption) (lstate, pstate)
			= (lstate, refreshAll pstate)
		receiver (CmdRefresh (ChangedProof theorem_ptr)) (lstate, pstate)
			| ptr <> theorem_ptr		= (lstate, pstate)
			= (lstate, refreshAll pstate)
		receiver (CmdRefresh (ChangedProofStatus theorem_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= (lstate, refreshRest theorem pstate)
		receiver (CmdRefresh (MovedTheorem theorem_ptr _)) (lstate, pstate)
			| ptr <> theorem_ptr		= (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			= (lstate, refreshRest theorem pstate)
		receiver (CmdRefresh (RemovedSection section_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			| theorem.thSection <> section_ptr
										= (lstate, pstate)
			= (lstate, close_Window (WinTheorem ptr) pstate)
		receiver (CmdRefresh (RenamedSection section_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			| theorem.thSection <> section_ptr
										= (lstate, pstate)
			= (lstate, refreshRest theorem pstate)
		receiver (CmdRefresh (RemovedTheorem removed_ptr)) (lstate, pstate)
			| ptr <> removed_ptr		= (lstate, pstate)
			= (lstate, close_Window (WinTheorem ptr) pstate)
		receiver (CmdRefresh (RenamedTheorem theorem_ptr)) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			| ptr == theorem_ptr
				# pstate				= appPIO (setWindowTitle id ("Theorem Info (" +++ theorem.thName +++ ")")) pstate
				= (lstate, refreshRest theorem pstate)
			| isMember theorem_ptr theorem.thProof.pUsedTheorems
				# pstate				= refreshProof theorem pstate
				# pstate				= refreshRest theorem pstate
				= (lstate, pstate)
			= (lstate, pstate)
		receiver (CmdRefresh other) (lstate, pstate)
			= (lstate, pstate)
		
		receiver (CmdProveSubgoal leaf_ptr) (lstate, pstate)
			# (leaf, pstate)			= accHeaps (readPointer leaf_ptr) pstate
			# goal						= fromLeaf leaf
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem					= {theorem & thProof.pCurrentLeaf = leaf_ptr, thProof.pCurrentGoal = goal}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# (winfos, pstate)			= pstate!ls.stWindows
			= case is_proof_window_open winfos of
				True					-> (lstate, broadcast (Just (WinTheorem ptr)) (ChangedSubgoal ptr) pstate)
				False					-> (lstate, openProof ptr theorem pstate)
			where
				is_proof_window_open :: ![WindowInfo] -> Bool
				is_proof_window_open [{wiId = WinProof theorem_ptr, wiOpened = True}:_]
					= ptr == theorem_ptr
				is_proof_window_open [_:winfos]
						= is_proof_window_open winfos
				is_proof_window_open []
					= False
		receiver (CmdShowDefinition ptr) (lstate, pstate)
			= (lstate, showDefinition ptr pstate)
		// Warning: opening a modal dialog that updates this window will cause a cycle in spine
		// Fix: send a asynchronous message to the global event handler
		receiver (CmdUndoToSubgoal leaf_ptr) (lstate, pstate)
			# (rid, pstate)				= pstate!ls.stWindowCommandRId
			# (_, pstate)				= asyncSend rid (CmdBrowseProof proof_rid ptr leaf_ptr) pstate
			= (lstate, pstate)
		receiver (CmdFoldNode node_ptr) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem					= {theorem & thProof.pFoldedNodes = [node_ptr:theorem.thProof.pFoldedNodes]}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= refreshProof theorem pstate
			= (lstate, pstate)
		receiver (CmdUnfoldNode node_ptr) (lstate, pstate)
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# theorem					= {theorem & thProof.pFoldedNodes = removeMember node_ptr theorem.thProof.pFoldedNodes}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= refreshProof theorem pstate
			= (lstate, pstate)
		receiver command (lstate, pstate)
			= (lstate, pstate)




































// -------------------------------------------------------------------------------------------------------------------------------------------------
changeHintScores :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
changeHintScores ptr pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	# (used, apply, applyf, lr, rl)		= case theorem.thHintScore of
											Just (apply,applyf,lr,rl)	-> (True, apply, applyf, lr, rl)
											Nothing						-> (False, 0, 0, 0, 0)
	# (dialog_id, pstate)				= accPIO openId pstate
	# (used_id, pstate)					= accPIO openId pstate
	# (apply_id, pstate)				= accPIO openId pstate
	# (applyf_id, pstate)				= accPIO openId pstate
	# (lr_id, pstate)					= accPIO openId pstate
	# (rl_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	= snd (openModalDialog Nothing (dialog theorem used apply applyf lr rl dialog_id used_id apply_id applyf_id lr_id rl_id ok_id cancel_id) pstate)
	where
		dialog theorem used apply applyf lr rl dialog_id used_id apply_id applyf_id lr_id rl_id ok_id cancel_id
			= Dialog ("Change hint scores of theorem '" +++ theorem.thName +++ "'")
				(		TextControl		"Used in suggestions window:"
											[]
					:+:	PopUpControl	[("Yes (use in suggestions window)", go_use), ("No (do not use in suggestions window)", go_unuse)] (if used 1 2)
											[ ControlId				used_id
											]
					:+:	TextControl		"Score for 'Apply':"
											[ ControlPos			(LeftOf apply_id, zero)
											]
					:+:	PopUpControl	[(toString n, id) \\ n <- [0..100]] (apply + 1)
											[ ControlId				apply_id
											, ControlPos			(Below used_id, zero)
											, ControlSelectState	(if used Able Unable)
											]
					:+:	TextControl		"Score for 'Apply forwards':"
											[ ControlPos			(LeftOf applyf_id, zero)
											]
					:+:	PopUpControl	[(toString n, id) \\ n <- [0..100]] (applyf + 1)
											[ ControlId				applyf_id
											, ControlPos			(Below apply_id, zero)
											, ControlSelectState	(if used Able Unable)
											]
					:+:	TextControl		"Score for 'Rewrite left-to-right':"
											[ ControlPos			(LeftOf lr_id, zero)
											]
					:+:	PopUpControl	[(toString n, id) \\ n <- [0..100]] (lr + 1)
											[ ControlId				lr_id
											, ControlPos			(Below applyf_id, zero)
											, ControlSelectState	(if used Able Unable)
											]
					:+:	TextControl		"Score for 'Rewrite right-to-left':"
											[ ControlPos			(LeftOf rl_id, zero)
											]
					:+:	PopUpControl	[(toString n, id) \\ n <- [0..100]] (rl + 1)
											[ ControlId				rl_id
											, ControlPos			(Below lr_id, zero)
											, ControlSelectState	(if used Able Unable)
											]
					:+:	ButtonControl	"Cancel"
											[ ControlPos			(Right, zero)
											, ControlId				cancel_id
											, ControlFunction		(noLS (closeWindow dialog_id))
											]
					:+:	ButtonControl	"Ok"
											[ ControlPos			(LeftOf cancel_id, zero)
											, ControlId				ok_id
											, ControlFunction		(noLS accept)
											]
				)
				[ WindowId				dialog_id
				, WindowClose			(noLS (closeWindow dialog_id))
				, WindowOk				ok_id
				, WindowCancel			cancel_id
				]
			where
				go_use :: !(!a, !*PState) -> (!a, !*PState)
				go_use (lstate, pstate)
					#! pstate					= appPIO (enableControl apply_id) pstate
					#! pstate					= appPIO (enableControl applyf_id) pstate
					#! pstate					= appPIO (enableControl lr_id) pstate
					#! pstate					= appPIO (enableControl rl_id) pstate
					= (lstate, pstate)
				
				go_unuse :: !(!a, !*PState) -> (!a, !*PState)
				go_unuse (lstate, pstate)
					#! pstate					= appPIO (disableControl apply_id) pstate
					#! pstate					= appPIO (disableControl applyf_id) pstate
					#! pstate					= appPIO (disableControl lr_id) pstate
					#! pstate					= appPIO (disableControl rl_id) pstate
					= (lstate, pstate)
				
				accept :: !*PState -> *PState
				accept pstate
					// wstate
					# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
					| isNothing mb_wstate		= pstate
					# wstate					= fromJust mb_wstate
					// used
					# (ok, mb_used)				= getPopUpControlSelection used_id wstate
					| not ok					= pstate
					| isNothing mb_used			= pstate
					# used						= mb_used == Just 1
					// apply
					# (ok, mb_apply)			= getPopUpControlSelection apply_id wstate
					| not ok					= pstate
					| isNothing mb_apply		= pstate
					# apply						= fromJust mb_apply - 1
					// apply forward
					# (ok, mb_applyf)			= getPopUpControlSelection applyf_id wstate
					| not ok					= pstate
					| isNothing mb_applyf		= pstate
					# applyf					= fromJust mb_applyf - 1
					// rewrite left-to-right
					# (ok, mb_lr)				= getPopUpControlSelection lr_id wstate
					| not ok					= pstate
					| isNothing mb_lr			= pstate
					# lr						= fromJust mb_lr - 1
					// rewrite right-to-left
					# (ok, mb_rl)				= getPopUpControlSelection rl_id wstate
					| not ok					= pstate
					| isNothing mb_rl			= pstate
					# rl						= fromJust mb_rl - 1
					// admin
					# hintscore					= case used of
													True	-> Just (apply, applyf, lr, rl)
													False	-> Nothing
					# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
					# theorem					= {theorem & thHintScore = hintscore}
					# pstate					= appHeaps (writePointer ptr theorem) pstate
					# pstate					= closeWindow dialog_id pstate
					# (info, pstate)			= get_Window (WinTheorem ptr) pstate
					# (_, pstate)				= asyncSend (fromJust info.wiNormalRId) CmdRefreshAlways pstate
					# pstate					= setTheoremHint True ptr theorem.thInitial hintscore pstate
					= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
restart :: !TheoremPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
restart ptr pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (edit_id, pstate)					= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	# (theorem, pstate)					= accHeaps (readPointer ptr) pstate
	= snd (openModalDialog Nothing (dialog dialog_id edit_id ok_id theorem.thInitialText) pstate)
	where
		dialog dialog_id edit_id ok_id initial_text
			= Dialog "Start theorem over"
				(		TextControl		"Start all over again, using as initial statement for theorem:"
											[]
					:+:	EditControl		initial_text (PixelWidth 400) 10
											[ ControlPos			(Left, zero)
											, ControlId				edit_id
											]
					:+:	ButtonControl	"Go!"
											[ ControlPos			(Right, zero)
											, ControlId				ok_id
											, ControlFunction		(noLS (go dialog_id edit_id))
											]
				)
				[ WindowId				dialog_id
				, WindowOk				ok_id
				, WindowClose			(noLS (closeWindow dialog_id))
				]
		
		go :: !Id !Id !*PState -> *PState
		go dialog_id edit_id pstate
			# (mb_wstate, pstate)		= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate		= pstate
			# wstate					= fromJust mb_wstate
			# (ok, mb_text)				= getControlText edit_id wstate
			| not ok					= pstate
			| isNothing mb_text			= pstate
			# text						= fromJust mb_text
			# (error, prop, pstate)		= accErrorHeapsProject (buildProp text) pstate
			| isError error				= showError error pstate
			# (fresh_prop, pstate)		= accHeaps (FreshVars prop) pstate
			# goal						= {DummyValue & glToProve = fresh_prop}
			# (used_symbols, pstate)	= accHeaps (GetUsedSymbols fresh_prop) pstate
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (leaf, pstate)			= accHeaps (newPointer (ProofLeaf goal)) pstate
			# (used_by, pstate)			= theoremsUsingTheorem ptr pstate
			| not (isEmpty used_by)		= showError [X_Internal "Used by other theorems"] pstate
			| isJust theorem.thHintScore= showError [X_Internal "Hint score not disabled"] pstate
			# theorem					=	{ theorem & 
											  thProof.pTree				= leaf
											, thProof.pLeafs			= [leaf]
											, thProof.pCurrentLeaf		= leaf
											, thProof.pCurrentGoal		= goal
											, thProof.pUsedTheorems		= []
											, thProof.pUsedSymbols		= used_symbols
											, thInitial					= prop
											, thInitialText				= text
											}
			# pstate					= appHeaps (writePointer ptr theorem) pstate
			# pstate					= broadcast Nothing (ChangedProof ptr) pstate
			# pstate					= broadcast Nothing (ChangedProofStatus ptr) pstate
			= closeWindow dialog_id pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RGBYellow		= toRGBColour Yellow
RGBControlBG	= toRGBColour ControlBG
LineColour		= Brown
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: UndoState =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ previousPtr						:: !Maybe ProofTreePtr
	, currentPtr						:: !ProofTreePtr
	, nextPtrs							:: ![ProofTreePtr]
	, dialogId							:: !Id
	, dialogRId							:: !RId String
	, locationRId						:: !RId (MarkUpMessage HeapPtr)
	, goalRId							:: !RId (MarkUpMessage WindowCommand)
	, previousId						:: !ButtonId
	, stepIds							:: ![ButtonId]
	, undoId							:: !ButtonId
	, cancelId							:: !Id
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
undo :: !(RId (MarkUpMessage WindowCommand)) !TheoremPtr !ProofTreePtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
undo proof_rid theorem_ptr proof_ptr pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (dialog_rid, pstate)				= accPIO openRId pstate
	# (location_rid, pstate)			= accPIO openRId pstate
	# (goal_rid, pstate)				= accPIO openRId pstate
	# (undo_id, pstate)					= accPIO openButtonId pstate
	# (previous_id, pstate)				= accPIO openButtonId pstate
	# (step_ids, pstate)				= accPIO (openButtonIds 5) pstate
	# (cancel_id, pstate)				= accPIO openId pstate
	# (finfo, pstate)					= makeFormatInfo pstate
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (theorem, pstate)					= accHeaps (readPointer theorem_ptr) pstate
	# (mb_previous, pstate)				= accHeaps (find_previous [theorem.thProof.pTree] proof_ptr) pstate
	# ustate							=	{ previousPtr		= mb_previous
											, currentPtr		= proof_ptr
											, nextPtrs			= []				// filled in by show
											, dialogId			= dialog_id
											, dialogRId			= dialog_rid
											, locationRId		= location_rid
											, goalRId			= goal_rid
											, previousId		= previous_id
											, stepIds			= step_ids
											, undoId			= undo_id
											, cancelId			= cancel_id
											}
	= snd (openModalDialog ustate (dialog ustate metrics) pstate)
	where
		dialog ustate metrics
			= Dialog "Browse proof"
				(	CompoundControl (controls ustate metrics)
						[ ControlItemSpace		5 5
						, ControlVMargin		5 5
						, ControlHMargin		5 5
						, ControlLook			True (\_ {newFrame} -> seq [setPenColour BG, fill newFrame])
						]
				)
				[ WindowId						ustate.dialogId
				, WindowClose					(noLS (do_close ustate))
				, WindowCancel					ustate.cancelId
				, WindowHMargin					0 0
				, WindowVMargin					0 0
				, WindowItemSpace				0 0
				, WindowInit					show
				]
		
		do_close :: !UndoState !*PState -> *PState
		do_close ustate pstate
			# pstate					= changeMarkUpDraw proof_rid False change pstate
			= closeWindow ustate.dialogId pstate
			where
				change (S_LinkId (CmdUndoToSubgoal ptr)) area
					= case area.smartBGColour == RGBYellow of
						True	-> (True, {area & smartBGColour = RGBControlBG})
						False	-> (False, area)
				change _ area
					= (False, area)
		
		controls ustate metrics
			=		Receiver		ustate.dialogRId receive
										[]
				:+:	MarkUpControl	[CmText "creating"]
										[ MarkUpFontFace			"Times New Roman"
										, MarkUpTextSize			10
										, MarkUpBackgroundColour	BG
										, MarkUpWidth				(640 + 2 + metrics.osmVSliderWidth)
										, MarkUpNrLinesI			7 18
										, MarkUpReceiver			ustate.locationRId
										]
										[]
				:+: boxedMarkUp		Black DoNotResize [CmText "creating"]
										[ MarkUpFontFace			"Courier New"
										, MarkUpTextSize			10
										, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
										, MarkUpBackgroundColour	ControlBG
										, MarkUpLinkStyle			False Black ControlBG False Black ControlBG
										, MarkUpLinkStyle			False LogicColour ControlBG False LogicColour ControlBG
										, MarkUpLinkStyle			False Black ControlBG False Black ControlBG
										, MarkUpLinkStyle			False LineColour ControlBG False LineColour ControlBG
										, MarkUpHScroll
										, MarkUpVScroll
										, MarkUpWidth				640
										, MarkUpNrLines				25
										, MarkUpReceiver			ustate.goalRId
										]
										[ ControlPos				(Left, zero)
										]
				:+: MarkUpButton	"Undo" BG (do_undo ustate.dialogId) ustate.undoId
										[ ControlPos				(Right, zero)
										]
				:+:	ButtonControl	"Cancel"
										[ ControlPos				(LeftTop, zero)
										, ControlId					ustate.cancelId
										, ControlFunction			(noLS (do_close ustate))
										, ControlHide
										]
				:+:	MarkUpButton	"Previous" BG (snd o asyncSend ustate.dialogRId "Previous") ustate.previousId
										[ ControlPos				(LeftBottom, zero)
										]
				:+:	MarkUpButton	"Next(1)" BG (snd o asyncSend ustate.dialogRId "Next(1)") (ustate.stepIds !! 0)
										[]
				:+:	MarkUpButton	"Next(2)" BG (snd o asyncSend ustate.dialogRId "Next(2)") (ustate.stepIds !! 1)
										[]
				:+:	MarkUpButton	"Next(3)" BG (snd o asyncSend ustate.dialogRId "Next(3)") (ustate.stepIds !! 2)
										[]
				:+:	MarkUpButton	"Next(4)" BG (snd o asyncSend ustate.dialogRId "Next(4)") (ustate.stepIds !! 3)
										[]
				:+:	MarkUpButton	"Next(5)" BG (snd o asyncSend ustate.dialogRId "Next(5)") (ustate.stepIds !! 4)
										[]
		
		receive :: !String !(!UndoState, !*PState) -> (!UndoState, !*PState)
		receive "Previous" (ustate, pstate)
			= previous (ustate, pstate)
		receive "Next(1)" (ustate, pstate)
			= next 0 (ustate, pstate)
		receive "Next(2)" (ustate, pstate)
			= next 1 (ustate, pstate)
		receive "Next(3)" (ustate, pstate)
			= next 2 (ustate, pstate)
		receive "Next(4)" (ustate, pstate)
			= next 3 (ustate, pstate)
		receive "Next(5)" (ustate, pstate)
			= next 4 (ustate, pstate)
		
		do_undo :: !Id !*PState -> *PState
		do_undo dialog_id pstate
			# (theorem, pstate)			= accHeaps (readPointer theorem_ptr) pstate
			# was_finished				= isEmpty theorem.thProof.pLeafs
			# (proof_node, pstate)		= accHeaps (readPointer proof_ptr) pstate
			# (to_be_removed, pstate)	= accHeaps (to_be_removed proof_node) pstate
			# (error, proof, pstate)	= accErrorHeaps (goToProofStep proof_ptr proof_node to_be_removed theorem.thProof) pstate
			| isError error				= showError error pstate
			# theorem					= {theorem & thProof = proof}
			# pstate					= appHeaps (writePointer theorem_ptr theorem) pstate
			# pstate					= resetDependencies theorem_ptr pstate
			# pstate					= broadcast Nothing (ChangedProof theorem_ptr) pstate
			# pstate					= case was_finished of
											True	-> broadcast Nothing (ChangedProofStatus theorem_ptr) pstate
											False	-> pstate
			= closeWindow dialog_id pstate
			where
				to_be_removed :: !ProofTree !*CHeaps -> (![ProofTreePtr], !*CHeaps)
				to_be_removed (ProofLeaf goal) heaps
					= ([], heaps)
				to_be_removed (ProofNode mb_goal tactic_id ptrs) heaps
					# (nodes, heaps)	= readPointers ptrs heaps
					# (more_ptrs, heaps)= umap to_be_removed nodes heaps
					= (ptrs ++ flatten more_ptrs, heaps)
		
		disect :: !ProofTree -> (!Bool, !TacticId, !Goal, ![ProofTreePtr])
		disect (ProofNode (Just goal) tactic children)
			= (True, tactic, goal, children)
		disect other
			= (False, DummyValue, DummyValue, DummyValue)
		
		show_tactic_in_node :: !FormatInfo !ProofTreePtr !*PState -> (!MarkUpText a, !Goal, ![ProofTreePtr], !*PState)
		show_tactic_in_node finfo ptr pstate
			# (node, pstate)			= accHeaps (readPointer ptr) pstate
			# (ok, tactic, goal, next)	= disect node
			| not ok					= ([CmColour Brown, CmText "*", CmEndColour], DummyValue, [], pstate)
			# (_, ftactic, pstate)		= accErrorHeapsProject (FormattedShow finfo tactic) pstate
			# ftactic					= removeCmLink ftactic
			# ftactic					=	[ CmFontFace			"Courier New"
											: ftactic
											] ++
											[ CmColour				Brown
											, CmBText				"."
											, CmEndColour
											, CmEndFontFace
											]
			= (ftactic, goal, next, pstate)
		
		show_next :: !FormatInfo !Int ![ProofTreePtr] !*PState -> (!MarkUpText a, !*PState)
		show_next finfo num [] pstate
			| num > 5					= ([], pstate)
			# fthis						=	[ CmBackgroundColour	InfoBG
											, CmRight
											, CmText				((toString num) +++ ":")
											, CmAlign				"@2"
											, CmSpaces				1
											, CmColour				Brown
											, CmText				"-"
											, CmEndColour
											, CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI			False 3 (Just BG)
											]
			# (frest, pstate)			= show_next finfo (num+1) [] pstate
			= (fthis ++ frest, pstate)
		show_next finfo num [ptr:ptrs] pstate
			| num > 5					= ([], pstate)
			# (ftactic, _, _, pstate)	= show_tactic_in_node finfo ptr pstate
			# fthis						=	[ CmBackgroundColour	InfoBG
											, CmRight
											, CmText				((toString num) +++ ":")
											, CmAlign				"@2"
											, CmSpaces				1
											: ftactic
											] ++
											[ CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI			False 3 (Just BG)
											]
			# (frest, pstate)			= show_next finfo (num+1) ptrs pstate
			= (fthis ++ frest, pstate)
		
		show :: !(!UndoState, !*PState) -> (!UndoState, !*PState)
		show (ustate, pstate)
			# (finfo, pstate)			= makeFormatInfo pstate
			# (fbefore, _, _, pstate)	= case ustate.previousPtr of
											(Just ptr)		-> show_tactic_in_node finfo ptr pstate
											Nothing			-> ([CmColour Brown, CmIText "none", CmEndColour], DummyValue, [], pstate)
			# fbefore					=	[ CmRight
											, CmBText				"Previous tactic:"
											, CmAlign				"@1"
											, CmSpaces				1
											, CmBackgroundColour	InfoBG
											: fbefore
											] ++
											[ CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI			False 3 (Just BG)
											]
			# (fnow, goal, next, pstate)= show_tactic_in_node finfo ustate.currentPtr pstate
			# fcurrent					=	[ CmRight
											, CmBText				"Current tactic:"
											, CmAlign				"@1"
											, CmSpaces				1
											, CmBackgroundColour	Yellow
											: fnow
											] ++
											[ CmFillLine
											, CmEndBackgroundColour
											, CmNewlineI			False 3 (Just BG)
											]
			# ustate					= {ustate & nextPtrs = next}
			# (fnext, pstate)			= show_next finfo 1 next pstate
			# fnext						=	[ CmRight
											, CmBText				"Next tactics:"
											, CmAlign				"@1"
											, CmSpaces				1
											: fnext
											]
			# pstate					= changeMarkUpText ustate.locationRId (fbefore ++ fcurrent ++ fnext) pstate
			# (theorem, pstate)			= accHeaps (readPointer theorem_ptr) pstate
			# (error, _, fgoal, pstate)	= showToProve finfo {theorem & thProof.pCurrentGoal = goal, thProof.pLeafs = [nilPtr]} pstate
			| isError error				= (ustate, showError error pstate)
			# pstate					= changeMarkUpText ustate.goalRId fgoal pstate
			# pstate					= case isJust ustate.previousPtr of
											True	-> enableButton ustate.previousId pstate
											False	-> disableButton ustate.previousId pstate
			# pstate					= enable_steps ustate.stepIds ustate.nextPtrs theorem.thProof.pLeafs pstate
			# pstate					= changeMarkUpDraw proof_rid True change pstate
			= (ustate, pstate)
			where
				enable_steps :: ![ButtonId] ![ProofTreePtr] ![ProofTreePtr] !*PState -> *PState
				enable_steps [id:ids] [] leafs pstate
					# pstate			= disableButton id pstate
					= enable_steps ids [] leafs pstate
				enable_steps [id:ids] [ptr:ptrs] leafs pstate
					# pstate			= case isMember ptr leafs of
											True	-> disableButton id pstate
											False	-> enableButton id pstate
					= enable_steps ids ptrs leafs pstate
				enable_steps [] [] leafs pstate
					= pstate

//				change :: !(SmartId a) !(SmartDrawArea a) -> (!Bool, !SmartDrawArea a)
				change (S_LinkId (CmdUndoToSubgoal ptr)) area
					= case ptr == ustate.currentPtr of
						True	-> (True, {area & smartBGColour = RGBYellow})
						False	-> case area.smartBGColour == RGBYellow of
									True	-> (True, {area & smartBGColour = RGBControlBG})
									False	-> (False, area)
				change _ area
					= (False, area)
		
		next :: !Int !(!UndoState, !*PState) -> (!UndoState, !*PState)
		next num (ustate, pstate)
			# children					= ustate.nextPtrs
			| num >= length children	= (ustate, pstate)
			# ustate					= {ustate	& previousPtr		= Just ustate.currentPtr
													, currentPtr		= children !! num
										  }
			= show (ustate, pstate)
		
		previous :: !(!UndoState, !*PState) -> (!UndoState, !*PState)
		previous (ustate, pstate)
			# mb_previous				= ustate.previousPtr
			| isNothing mb_previous		= (ustate, pstate)
			# previous					= fromJust mb_previous
			# (theorem, pstate)			= accHeaps (readPointer theorem_ptr) pstate
			# (mb_previous, pstate)		= accHeaps (find_previous [theorem.thProof.pTree] previous) pstate
			# ustate					= {ustate	& previousPtr		= mb_previous
													, currentPtr		= previous
										  }
			= show (ustate, pstate)
		
		find_previous :: ![ProofTreePtr] !ProofTreePtr !*CHeaps -> (!Maybe ProofTreePtr, !*CHeaps)
		find_previous [] target heaps
			= (Nothing, heaps)
		find_previous [ptr:ptrs] target heaps
			# (node, heaps)				= readPointer ptr heaps
			# (_, _, _, children)		= disect node
			| isMember target children	= (Just ptr, heaps)
			= find_previous (children ++ ptrs) target heaps

















// -------------------------------------------------------------------------------------------------------------------------------------------------
showUsed :: !Theorem ![TheoremPtr] ![TheoremPtr] !*PState -> (!MarkUpText WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showUsed theorem true false pstate
	# ptrs								= theorem.thProof.pUsedTheorems
	# (names, pstate)					= accHeaps (getPointerNames ptrs) pstate
	# (ptrs, names)						= unzip (sortBy (\(_,n1)(_,n2)->n1<n2) (zip2 ptrs names))
	# ftheorems							= show_theorems ptrs names
	# ftheorems							= case isEmpty ptrs of
											True	->	[ CmBackgroundColour		MyGreen
														, CmSpaces					1
														, CmFontFace				"Wingdings"
														, CmText					{toChar 159}
														, CmEndFontFace
														, CmSpaces					1
														, CmIText					"proof\0script does not depend on other theorems"
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI				False 1 Nothing
														]
											False	-> ftheorems
	# functions							= [ptr \\ ptr <- theorem.thProof.pUsedSymbols | ptrKind ptr == CFun]
	# (error, infos, pstate)			= accErrorHeapsProject (uumapError getDefinitionInfo functions) pstate
	| isError error						= ([], showError error pstate)
	# infos								= sortBy (\i1 i2 -> i1.diName < i2.diName) infos
	# ffunctions						= show_functions infos
	# ffunctions						= case isEmpty infos of
											True	->	[ CmBackgroundColour		ControlBG
														, CmSpaces					1
														, CmFontFace				"Wingdings"
														, CmText					{toChar 159}
														, CmEndFontFace
														, CmSpaces					1
														, CmIText					"proof\0script does not make use of\0any imported functions"
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI				False 1 Nothing
														]
											False	-> ffunctions
	# conses							= [ptr \\ ptr <- theorem.thProof.pUsedSymbols | ptrKind ptr == CDataCons]
	# (error, infos, pstate)			= accErrorHeapsProject (uumapError getDefinitionInfo conses) pstate
	| isError error						= ([], showError error pstate)
	# infos								= sortBy (\i1 i2 -> i1.diName < i2.diName) infos
	# fconses							= show_conses infos
	# fconses							= case isEmpty infos of
											True	->	[ CmBackgroundColour		ControlBG
														, CmSpaces					1
														, CmFontFace				"Wingdings"
														, CmText					{toChar 159}
														, CmEndFontFace
														, CmSpaces					1
														, CmIText					"proof\0script does not make use of\0any imported constructors"
														, CmFillLine
														, CmEndBackgroundColour
														, CmNewlineI				False 1 Nothing
														]
											False	-> fconses
	= (ftheorems ++ ffunctions ++ fconses, pstate)
	where
		show_theorems :: ![TheoremPtr] ![CName] -> MarkUpText WindowCommand
		show_theorems [ptr:ptrs] [name:names]
			# (colour, status, ln)		= case isMember ptr true of
											True	-> (MyGreen, " (proved)", 0)
											False	-> (MyRed, " (unproved)", 1)
			=	[ CmBackgroundColour	colour
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"proof script depends on theorem "
				, CmBold
				, CmLink2				ln name (CmdShowTheorem ptr)
				, CmEndBold
				, CmIText				status
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show_theorems ptrs names
				]
		show_theorems [] []
			= []
		
		show_functions :: ![DefinitionInfo] -> MarkUpText WindowCommand
		show_functions [info:infos]
			=	[ CmBackgroundColour	ControlBG
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"proof script makes use of function"
				, CmAlign				"@SYMBOL"
				, CmSpaces				1
				, CmBold
				, CmLink2				2 info.diName (CmdShowDefinition info.diPointer)
				, CmEndBold
				, CmAlign				"@MODULE"
				, CmSpaces				1
				, CmText				"in module "
				, CmBold
				, CmLink2				2 info.diModuleName (CmdShowModule (Just (ptrModule info.diPointer)))
				, CmEndBold
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show_functions infos
				]
		show_functions []
			= []
		
		show_conses :: ![DefinitionInfo] -> MarkUpText WindowCommand
		show_conses [info:infos]
			=	[ CmBackgroundColour	ControlBG
				, CmSpaces				1
				, CmFontFace			"Wingdings"
				, CmText				{toChar 159}
				, CmEndFontFace
				, CmSpaces				1
				, CmText				"proof script makes use of constructor"
				, CmAlign				"@SYMBOL"
				, CmSpaces				1
				, CmBold
				, CmLink2				2 info.diName (CmdShowDefinition info.diPointer)
				, CmEndBold
				, CmAlign				"@MODULE"
				, CmSpaces				1
				, CmText				"in module "
				, CmBold
				, CmLink2				2 info.diModuleName (CmdShowModule (Just (ptrModule info.diPointer)))
				, CmEndBold
				, CmFillLine
				, CmEndBackgroundColour
				, CmNewlineI			False 1 Nothing
				: show_conses infos
				]
		show_conses []
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
showProof :: !FormatInfo !Bool !Proof !ProofTreePtr !ProofTreePtr !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
showProof finfo subgoals proof current_ptr proof_ptr heaps prj
	# (node, heaps)						= readPointer proof_ptr heaps
	# (error, fproof, heaps, prj)		= show_node finfo subgoals False 0 proof_ptr node proof.pFoldedNodes heaps prj
	| isError error						= (error, DummyValue, heaps, prj)
	# fproof							= case isEmpty proof.pLeafs of
											True	-> fproof ++ [CmNewline, CmColour LogicColour, CmBText "Q.E.D.", CmEndColour]
											False	-> fproof
	= (error, [CmSpaces 1, CmScope: fproof] ++ [CmEndScope], heaps, prj)
	where
		show_node :: !FormatInfo !Bool !Bool !Int !ProofTreePtr !ProofTree ![ProofTreePtr] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		show_node finfo subgoals behind_number nr_indents ptr (ProofNode mb_goal tactic children) folded heaps prj
			# (error, fstart, heaps, prj)		= maybe_show_goal ptr (subgoals || ptr == proof_ptr) mb_goal behind_number nr_indents heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# behind_number						= behind_number && not (subgoals || ptr == proof_ptr)
			# fprefix							= case behind_number of
													True	-> []
													False	-> build_prefix finfo True nr_indents
			# findent							= [CmAlign (toString nr_indents)]
			# (error, ftactic, heaps, prj)		= FormattedShow finfo tactic heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# ftactic							= removeCmLink ftactic
			# ftactic							= ftactic ++ [CmColour Brown, CmText ".", CmEndColour]
			# ftactic							= [CmId (CmdUndoToSubgoal ptr):ftactic] ++ [CmEndId]
			# ftactic							= case subgoals of
													_		-> ftactic ++ [CmSpaces 1, CmBold, CmFontFace "Times New Roman", CmSize 8, CmLink2 0 "browse" (CmdUndoToSubgoal ptr), CmEndSize, CmEndFontFace, CmEndBold]
			# nr_children						= length children
			| nr_children == 0					= (OK, fstart ++ fprefix ++ findent ++ ftactic, heaps, prj)
			| nr_children == 1
				# (child, heaps)				= readPointer (hd children) heaps
				# (error, frest, heaps, prj)	= show_node finfo subgoals False nr_indents (hd children) child folded heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, fstart ++ fprefix ++ findent ++ ftactic ++ [CmNewline:frest], heaps, prj)
			| nr_children > 1
				# (error, frest, heaps, prj)	= show_ptrs finfo subgoals nr_indents 1 children folded heaps prj
				| isError error					= (error, DummyValue, heaps, prj)
				= (OK, fstart ++ fprefix ++ findent ++ ftactic ++ [CmNewline:frest], heaps, prj)
			= undef
		show_node finfo subgoals behind_number nr_indents ptr (ProofLeaf goal) folded heaps prj
			# (error, fstart, heaps, prj)		= maybe_show_goal ptr (subgoals || ptr == proof_ptr) (Just goal) behind_number nr_indents heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# behind_number						= behind_number && not (subgoals || ptr == proof_ptr)
			# fprefix							= case behind_number of
													True	-> []
													False	-> build_prefix finfo True nr_indents
			# findent							= [CmAlign (toString nr_indents)]
			# ftext								= [CmBold, CmLink2 1 "*" (CmdProveSubgoal ptr), CmEndBold]
			= (OK, fstart ++ fprefix ++ findent ++ ftext, heaps, prj)
		
		show_ptrs :: !FormatInfo !Bool !Int !Int ![ProofTreePtr] ![ProofTreePtr] !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, !*CHeaps, !*CProject)
		show_ptrs finfo subgoals nr_indents num [ptr:ptrs] folded heaps prj
			# fprefix							= build_prefix finfo True nr_indents
			# findent							= [CmAlign (toString nr_indents)]
			| isMember ptr folded
				# (nr_tactics, nr_goals, heaps)	= summary [ptr] 0 0 heaps
				# fsummary_text					=	[	CmColour	HiddenFG
													,	CmText		"<hidden: "
													,	CmBText		(toString nr_tactics)
													,	CmText		(if (nr_tactics==1) " tactic" " tactics")
													,	CmText		"; "
													,	CmBText		(toString nr_goals)
													,	CmText		(if (nr_goals==1) " subgoal" " subgoals")
													,	CmText		">"
													,	CmEndColour
													]
				# fpath							= [CmBold, CmLink2 2 (toString num) (CmdUnfoldNode ptr), CmText ".", CmEndBold] ++ fsummary_text ++ [CmNewline]
				# (error, frest, heaps, prj)	= show_ptrs finfo subgoals nr_indents (num+1) ptrs folded heaps prj
				= (OK, fprefix ++ findent ++ fpath ++ frest, heaps, prj)
			# (node, heaps)						= readPointer ptr heaps
			# (error, fpath, heaps, prj)		= show_node finfo subgoals True (nr_indents + 1) ptr node folded heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# fpath								= [CmBold, CmLink2 3 (toString num) (CmdFoldNode ptr), CmEndBold, CmBText ".": fpath] ++ [CmNewline]
			# (error, frest, heaps, prj)		= show_ptrs finfo subgoals nr_indents (num+1) ptrs folded heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			= (OK, fprefix ++ findent ++ fpath ++ frest, heaps, prj)
		show_ptrs finfo subgoals align_as num [] folded heaps prj
			= (OK, [], heaps, prj)
		
		build_prefix :: !FormatInfo !Bool !Int -> MarkUpText WindowCommand
		build_prefix finfo=:{fiOptions} may_branch num
			| not fiOptions.optShowIndents		= []
			= show_prefixes 0 may_branch num
			where
				show_prefixes :: !Int !Bool !Int -> MarkUpText WindowCommand
				show_prefixes i may_branch num
					| i >= num					= []
					# draw_lines				= case (i < num-1) || not may_branch of
													True	->		[CmLines [(N,S)]]
													False	->		[CmLines [(N,S),(Middle,E)],
																	 CmLines [(W,Middle)]]
					# prefix					= 	[	CmAlign		(toString i)
													,	CmColour	IndentFG
													:	draw_lines
													]
													++
													[	CmEndColour
													]
					= prefix ++ show_prefixes (i+1) may_branch num
		
		maybe_show_goal :: !ProofTreePtr !Bool !(Maybe Goal) !Bool !Int !*CHeaps !*CProject -> (!Error, !MarkUpText WindowCommand, *CHeaps, !*CProject)
		maybe_show_goal ptr True (Just goal) behind_number nr_indents heaps prj
			# fprefix							= case behind_number of
													True	-> []
													False	-> build_prefix finfo False nr_indents
			# (error, ftoprove, heaps, prj)		= FormattedShow finfo goal.glToProve heaps prj
			| isError error						= (error, DummyValue, heaps, prj)
			# ftoprove							= normalize (removeCmLink ftoprove)
			# colour							= Grey
			= (OK, fprefix ++ [CmAlign (toString nr_indents), CmColour colour, CmText "{": ftoprove] ++ [CmText "}", CmEndColour, CmNewline], heaps, prj)
		maybe_show_goal ptr _ _ _ _ heaps prj
			= (OK, [], heaps, prj)
		
		summary :: ![ProofTreePtr] !Int !Int !*CHeaps -> (!Int, !Int, !*CHeaps)
		summary [] nr_tactics nr_goals heaps
			= (nr_tactics, nr_goals, heaps)
		summary [ptr:ptrs] nr_tactics nr_goals heaps
			# (node, heaps)						= readPointer ptr heaps
			= case node of
				ProofLeaf _						-> summary ptrs nr_tactics (nr_goals+1) heaps
				ProofNode _ _ children			-> summary (children++ptrs) (nr_tactics+1) nr_goals heaps