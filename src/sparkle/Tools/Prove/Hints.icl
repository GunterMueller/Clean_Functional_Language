/*
** Program: Clean Prover System
** Module:  Hints (.icl)
** 
** Author:  Maarten de Mol
** Created: 9 May 2001
*/

implementation module 
   Hints

import 
   StdEnv,
   StdIO,
   Definedness,
   Arith,
   Compare,
   GiveType,
   Rewrite,
   States,
   Tactics,
   ossystem
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
//BG				:== RGB {r=170, g=220, b=170}
//ControlBG		:== RGB {r=190, g=240, b=190}
//DarkBG			:== RGB {r=160, g=210, b=160}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
:: Hint =
// ------------------------------------------------------------------------------------------------------------------------   
	{ hintValue				:: !Int
	, hintTactic			:: !TacticId
	, hintText				:: !String
	}
instance DummyValue Hint
	where DummyValue	= {hintValue = 0, hintTactic = DummyValue, hintText = ""}

// ------------------------------------------------------------------------------------------------------------------------   
instance == Hint
// ------------------------------------------------------------------------------------------------------------------------   
where
	(==) hint1 hint2
		= hint1.hintTactic == hint2.hintTactic

// ------------------------------------------------------------------------------------------------------------------------   
:: HintState =
// ------------------------------------------------------------------------------------------------------------------------   
	{ currentHints			:: ![Hint]
	, history				:: ![(Bool, Int, Hint)]
	}












// ------------------------------------------------------------------------------------------------------------------------   
setTheoremHint :: !Bool !TheoremPtr !CPropH !(Maybe (Int, Int, Int, Int)) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
setTheoremHint update ptr prop hint_scores pstate
	# (hints, pstate)					= pstate!ls.stHintTheorems
	# hints								= change hints
	# pstate							= {pstate & ls.stHintTheorems = hints}
	| not update						= pstate
	# (opened, pstate)					= isWindowOpened WinHints False pstate
	| not opened						= pstate
	# (winfo, pstate)					= get_Window WinHints pstate
	# (_, pstate)						= asyncSend (fromJust winfo.wiNormalRId) CmdRefreshAlways pstate
	= pstate
	where
		change :: ![HintTheorem] -> [HintTheorem]
		change [hint:hints]
			| hint.hintPointer == ptr
				= case hint_scores of
					Nothing						-> hints
					Just (apply,applyf, lr,rl)	-> [	{ hintPointer			= ptr
														, hintProp				= prop
														, hintApplyScore		= apply
														, hintApplyForwardScore	= applyf
														, hintRewriteLRScore	= lr
														, hintRewriteRLScore	= rl
														}
													: hints
													]
			= [hint: change hints]
		change []
			= case hint_scores of
				Nothing							-> []
				Just (apply, applyf, lr, rl)	-> [	{ hintPointer			= ptr
														, hintProp				= prop
														, hintApplyScore		= apply
														, hintApplyForwardScore	= applyf
														, hintRewriteLRScore	= lr
														, hintRewriteRLScore	= rl
														}
													]















// ------------------------------------------------------------------------------------------------------------------------   
openHints :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
openHints pstate
	# (_, pstate)						= isWindowOpened (WinProof nilPtr) True pstate		// Hack -- activate window
	# (opened, pstate)					= isWindowOpened WinHints True pstate
	| opened							= pstate
	# (winfo, pstate)					= new_Window WinHints pstate
	# (text_show_rid, pstate)			= accPIO openRId pstate
	# (text_apply_rid, pstate)			= accPIO openRId pstate
	# (hints_rid, pstate)				= accPIO openRId pstate
	# (history_rid, pstate)				= accPIO openRId pstate
	# (view_threshold_id, pstate)		= accPIO openId pstate
	# (apply_threshold_id, pstate)		= accPIO openId pstate
	# (extended_bg, pstate)				= pstate!ls.stDisplayOptions.optHintWindowBG
	# bg								= toColour 0 extended_bg
	# (window, pstate)					= newHints winfo text_show_rid text_apply_rid hints_rid history_rid view_threshold_id apply_threshold_id bg pstate
	# hstate							= {currentHints = [], history = []}
	# (suggestions_id, pstate)			= pstate!ls.stMenus.suggestions_id
	# pstate							= appPIO (markMenuItems [suggestions_id]) pstate
	= snd (openWindow hstate window pstate)

// ------------------------------------------------------------------------------------------------------------------------   
//newHints :: !WindowInfo !(RId (MarkUpMessage WindowCommand)) !(RId (MarkUpMessage WindowCommand)) !Id !Id !*PState -> (_, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
newHints winfo text_show_rid text_apply_rid hints_rid history_rid view_threshold_id apply_threshold_id bg pstate
	# (metrics, _)						= osDefaultWindowMetrics 42
	# (view_threshold, pstate)			= pstate!ls.stOptions.optHintsViewThreshold
	# (apply_threshold, pstate)			= pstate!ls.stOptions.optHintsApplyThreshold
	# the_controls						= controls view_threshold apply_threshold
	# (real_size, pstate)				= controlSize the_controls True (Just(5,5)) (Just(5,5)) (Just(5,5)) pstate
	# (pos, pstate)						= case (winfo.wiStoredPos.vx == (-1) && winfo.wiStoredPos.vy == (-1)) of
											True	-> placeWindow real_size pstate
											False	-> (winfo.wiStoredPos, pstate)
	=	( Window "Tactic Suggestions Window" the_controls
			[ WindowId					winfo.wiWindowId
			, WindowClose				(noLS (close_Window WinHints))
			, WindowLook				True (\_ {newFrame} -> seq [setPenColour bg, fill newFrame])
			, WindowHMargin				5 5
			, WindowVMargin				5 5
			, WindowItemSpace			5 5
			, WindowInit				refresh
			, WindowViewSize			{real_size & w = winfo.wiStoredWidth + 2 + metrics.osmVSliderWidth + 10}
			, WindowPos					(LeftTop, OffsetVector pos)
			, WindowKeyboard			(\key -> True) Able handle_window_keyboard
			]
		, pstate
		)
	where
		controls view_threshold apply_threshold
			= 		Receiver			(fromJust winfo.wiNormalRId) receiver []
				:+:	MarkUpControl		[CmBText "Show suggestions with value >="]
											[ MarkUpBackgroundColour	bg
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpReceiver			text_show_rid
											]
											[ ControlPos				(Left, zero)
											]
				:+:	PopUpControl		[(toString i, \(ls,ps) -> refresh (ls,{ps & ls.stOptions.optHintsViewThreshold = i})) \\ i <- [1..101]] view_threshold
											[ ControlId					view_threshold_id
											]
				:+:	MarkUpControl		[CmBText "Automatically apply suggestions with value >="]
											[ MarkUpBackgroundColour	bg
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpReceiver			text_apply_rid
											]
											[ ControlPos				(RightToPrev, OffsetVector {vx=20, vy=0})
											]
				:+:	PopUpControl		[(toString i, \(ls,ps) -> refresh (ls,{ps & ls.stOptions.optHintsApplyThreshold = i})) \\ i <- [1..101]] apply_threshold
											[ ControlId					apply_threshold_id
											]
				:+:	boxedMarkUp			Black ResizeHorVer [CmText "creating"]
											[ MarkUpBackgroundColour	(changeColour 20 bg)
											, MarkUpFontFace			"Courier New"
											, MarkUpTextSize			10
											, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
											, MarkUpWidth				winfo.wiStoredWidth
											, MarkUpHeight				winfo.wiStoredHeight
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpReceiver			hints_rid
											, MarkUpLinkStyle			False (changeColour (-20) bg) (changeColour 20 bg) False Black (changeColour 20 bg)
											, MarkUpLinkStyle			False LightGrey Yellow False Black Yellow
											, MarkUpEventHandler		(sendHandler (fromJust winfo.wiNormalRId))
											, MarkUpOverrideKeyboard	check_for_function_key
											]
											[ ControlId					(fromJust winfo.wiControlId)
											, ControlPos				(Left, zero)
											]
				:+:	boxedMarkUp			Black ResizeHor [CmText "-"]
											[ MarkUpBackgroundColour	(changeColour (-10) bg)
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpFixMetrics			{fName = "Courier New", fSize = 10, fStyles = []}
											, MarkUpWidth				winfo.wiStoredWidth
											, MarkUpNrLinesI			3 2
											, MarkUpHScroll
											, MarkUpVScroll
											, MarkUpReceiver			history_rid
											, MarkUpOverrideKeyboard	check_for_function_key
											]
											[ ControlPos				(Left, zero)
											]
		
		handle_window_keyboard :: !KeyboardState !(!a, !*PState) -> (!a, !*PState)
		handle_window_keyboard key (lstate, pstate)
			= (lstate, pstate)
		
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
					# (_, pstate)			= asyncSend (fromJust winfo.wiNormalRId) (CmdApplyHint num really_apply) pstate
					= pstate
		check_for_function_key key pstate
			= pstate
		
		// Does *NOT* respond to ChangedProof / ChangedSubgoal
		// The updates are instead explicitly triggered by the refresh-function of the proof window.
		receiver :: !WindowCommand !(!HintState, !*PState) -> (!HintState, !*PState)
		receiver CmdRefreshAlways (hstate, pstate)
			= refresh (hstate, pstate)
		receiver (CmdRefreshBackground old_bg new_bg) (hstate, pstate)
			# new_look					= \_ {newFrame} -> seq [setPenColour new_bg, fill newFrame]
			# pstate					= appPIO (setWindowLook winfo.wiWindowId True (True, new_look)) pstate
			# pstate					= changeMarkUpColour text_show_rid True old_bg new_bg pstate
			# pstate					= changeMarkUpColour text_apply_rid True old_bg new_bg pstate
			# pstate					= changeMarkUpColour hints_rid False old_bg new_bg pstate
			# pstate					= changeMarkUpColour hints_rid False (changeColour 20 old_bg) (changeColour 20 new_bg) pstate
			# pstate					= changeMarkUpColour hints_rid True (changeColour (-20) old_bg) (changeColour (-20) new_bg) pstate
			# pstate					= changeMarkUpColour history_rid False (changeColour (-10) old_bg) (changeColour (-10) new_bg) pstate
			# pstate					= changeMarkUpColour history_rid True old_bg new_bg pstate
			= refresh (hstate, pstate)
		receiver (CmdApplyHint num really_apply) (hstate, pstate)
			# hints						= hstate.currentHints
			| num > length hints		= (hstate, pstate)
			# hint						= hints !! (num-1)
			= use_hint False really_apply num hint (hstate, pstate)
		receiver (CmdUpdateHints mb_ptr theorem definedness_info) (hstate, pstate)
			= refresh_info mb_ptr theorem definedness_info (hstate, pstate)
		receiver command (hstate, pstate)
			= (hstate, pstate)
		
		refresh :: !(!HintState, !*PState) -> (!HintState, !*PState)
		refresh (hstate, pstate)
			# (opened, pstate)			= isWindowOpened (WinProof nilPtr) False pstate
			| not opened				= refresh_info Nothing EmptyTheorem DummyValue (hstate, pstate)
			# (winfo, pstate)			= get_Window (WinProof nilPtr) pstate
			# ptr						= analyze winfo.wiId
			# (theorem, pstate)			= accHeaps (readPointer ptr) pstate
			# (c, definedness, pstate)	= acc2HeapsProject (findDefinednessInfo theorem.thProof.pCurrentGoal) pstate
			= refresh_info (Just ptr) theorem (c, definedness) (hstate, pstate)
			where
				analyze (WinProof ptr)	= ptr
		
		refresh_info :: !(Maybe TheoremPtr) !Theorem !(!Bool, !DefinednessInfo) !(!HintState, !*PState) -> (!HintState, !*PState)
		refresh_info Nothing _ _ (hstate, pstate)
			= (hstate, changeMarkUpText hints_rid [CmIText "No proof in progress."] pstate)
		refresh_info (Just ptr) theorem definedness_info (hstate, pstate)
			# pstate					= {pstate & ls.stBusyProving = False}
			# (extended_bg, pstate)		= pstate!ls.stDisplayOptions.optHintWindowBG
			# bg						= toColour 0 extended_bg
			# (view_threshold, pstate)	= pstate!ls.stOptions.optHintsViewThreshold
			# (apply_threshold, pstate)	= pstate!ls.stOptions.optHintsApplyThreshold
			# pstate					= changeMarkUpText hints_rid [CmIText "Finding new suggestions...."] pstate
			# goal						= theorem.thProof.pCurrentGoal
			# (hints, pstate)			= case theorem.thProof.pLeafs of
											[_:_]	-> findHints2 ptr goal definedness_info pstate
											[]		-> ([], pstate)
			# (hit, hint, hints)		= sortHints apply_threshold hints
			| hit						= use_hint True True 1 hint (hstate, pstate)
			# (finfo, pstate)			= makeFormatInfo pstate
			# (error, hints, fhints, pstate)
										= case isEmpty hints of
											False	-> showHints finfo 1 hints bg pstate
											True	-> (OK, hints, [CmIText "No suggestions available."], pstate)
			# hstate					= {hstate & currentHints = hints}
			| isError error				= (hstate, showError error pstate)
			= (hstate, changeMarkUpText hints_rid fhints pstate)
		
		use_hint :: !Bool !Bool !Int !Hint !(!HintState, !*PState) -> (!HintState, !*PState)
		use_hint automatic True num hint (hstate, pstate)
			# hstate					= {hstate & history = take 3 [(automatic,num,hint):hstate.history]}
			# (finfo, pstate)			= makeFormatInfo pstate
			# (extended_bg, pstate)		= pstate!ls.stDisplayOptions.optHintWindowBG
			# bg						= toColour 0 extended_bg
			# (fhistory, pstate)		= show_history finfo (reverse hstate.history) bg pstate
			# pstate					= changeMarkUpText history_rid fhistory pstate
			# (winfo, pstate)			= get_Window (WinProof nilPtr) pstate
			# proof_rid					= fromJust winfo.wiNormalRId
			# pstate					= {pstate & ls.stBusyProving = True}
//			# (_, pstate)				= asyncSend proof_rid (CmdRestoreEditControl hint.hintText) pstate
			# (_, pstate)				= asyncSend proof_rid (CmdApplyTactic "" hint.hintTactic) pstate
			= (hstate, pstate)
		use_hint automatic False num hint (hstate, pstate)
			# (winfo, pstate)			= get_Window (WinProof nilPtr) pstate
			# proof_rid					= fromJust winfo.wiNormalRId
			# (_, pstate)				= asyncSend proof_rid (CmdRestoreEditControl hint.hintText) pstate
			= (hstate, pstate)
		
		show_history :: !FormatInfo ![(Bool, Int, Hint)] !Colour !*PState -> (!MarkUpText WindowCommand, !*PState)
		show_history finfo [(automatic, num, hint):hints] bg pstate
			# fautomatic				= if automatic
											[CmText "Automatically", CmAlign "@1", CmText " applied suggestion "]
											[CmText "Manually", CmAlign "@1", CmText " applied suggestion "]
			# fvalue					= [CmText (toString num), CmText " ", CmColour LogicColour, CmSize 8, CmText ("(" +++ toString hint.hintValue +++ "%)"), CmEndSize, CmEndColour, CmAlign "@2", CmSpaces 1, CmText "-", CmSpaces 1]
			# (_, ftactic, pstate)		= accErrorHeapsProject (FormattedShow finfo hint.hintTactic) pstate
			# ftactic					= removeCmLink ftactic
			# fhint						= fautomatic ++ fvalue ++ [CmFontFace "Courier New"] ++ ftactic ++ [CmEndFontFace]
			# (fhints, pstate)			= show_history finfo hints bg pstate
			= (fhint ++ [CmNewlineI False 1 (Just bg)] ++ fhints, pstate)
		show_history finfo [] bg pstate
			= ([], pstate)

















/*
// ------------------------------------------------------------------------------------------------------------------------   
findHints :: !TheoremPtr !Goal !(!Bool, ![CExprH], ![CExprH]) !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findHints ptr goal definedness_info pstate
	# (threshold, pstate)			= pstate!ls.stOptions.optHintsViewThreshold
	# (hint_theorems, pstate)		= pstate!ls.stHintTheorems
	# defined_vars					= find_vars (snd3 definedness_info)
	# reduction_options				= {roMode = Defensive, roDefinedVariables = defined_vars}
	# (_, sub, info, pstate)		= acc3HeapsProject (wellTyped goal) pstate
	# (eq_type, pstate)				= case isNilPtr info.tiEqualType of
										True	-> (DummyValue, pstate)
										False	-> accHeaps (UnsafeSubst sub (CTypeVar info.tiEqualType)) pstate
	# (var_types, pstate)			= accHeaps (get_var_types goal.glToProve sub) pstate
	# (hyps, pstate)				= accHeaps (readPointers goal.glHypotheses) pstate
	# hyp_props						= [hyp.hypProp \\ hyp <- hyps]
	# (case_vars, pstate)			= accHeapsProject (find_all_case_vars [] [goal.glToProve:hyp_props]) pstate
	# pstate						= appProject (mark_opaque True goal.glOpaque) pstate
	# hints							= []
	# (hints, pstate)				= findAbsurd threshold goal.glHypotheses hyp_props goal.glHypotheses hyp_props hints pstate
	# (hints, pstate)				= findAbsurdEquality threshold goal.glHypotheses hyp_props goal.glToProve hints pstate
	# (hints, pstate)				= findApply threshold goal.glHypotheses goal.glHypotheses hyp_props hyp_props goal.glToProve hints pstate
	# hints							= findCase threshold goal.glHypotheses hyp_props goal.glToProve hints
	# hints							= findCases threshold goal.glExprVars case_vars hints
	# hints							= findContradiction threshold goal.glHypotheses hyp_props goal.glToProve hints
	# hints							= findDefinedness threshold definedness_info hints
	# (hints, pstate)				= findExact threshold goal.glHypotheses hyp_props goal.glToProve hints pstate
	# (hints, pstate)				= findExFalso threshold goal.glHypotheses hyp_props hints pstate
	# hints							= findExtensionality threshold eq_type hints
	# hints							= findInduction threshold goal goal.glToProve var_types case_vars hints
	# (hints, pstate)				= findIntArith threshold goal.glHypotheses hyp_props goal.glToProve hints pstate
	# (hints, pstate)				= findIntCompare threshold goal hints pstate
	# (hints, pstate)				= findInjective threshold goal.glHypotheses hyp_props goal.glToProve hints pstate
	# (hints, pstate)				= findIntros threshold goal.glNewHypNum goal.glToProve hints pstate
	# (hints, pstate)				= findReduce threshold reduction_options goal.glHypotheses hyp_props goal.glToProve hints pstate
	# (hints, pstate)				= findReflexive threshold goal.glToProve hints pstate
	# (hints, pstate)				= findRewrite threshold goal.glHypotheses hyp_props goal hints pstate
	# hints							= findSplit threshold goal.glHypotheses hyp_props goal.glToProve hints
	# hints							= findSplitIff threshold goal.glHypotheses hyp_props goal.glToProve hints
	# (hints, pstate)				= findSplitCase goal.glToProve hints pstate
	# (hints, pstate)				= findTheoremHints threshold ptr hint_theorems hyp_props goal hints pstate
	# hints							= findTrivial threshold goal.glToProve hints
	# hints							= findWitness threshold goal.glHypotheses hyp_props hints
	# pstate						= appProject (mark_opaque False goal.glOpaque) pstate
	= (hints, pstate)
	where
		find_all_case_vars :: ![CExprVarPtr] ![CPropH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		find_all_case_vars vars [p:ps] heaps prj
			# (vars, heaps, prj)	= findCaseVars vars p heaps prj
			= find_all_case_vars vars ps heaps prj
		find_all_case_vars vars [] heaps prj
			= (vars, heaps, prj)
	
		get_var_types :: !CPropH !Substitution !*CHeaps -> (![CTypeH], !*CHeaps)
		get_var_types (CExprForall ptr p) sub heaps
			# (var, heaps)			= readPointer ptr heaps
			# type					= get_type var.evarInfo
			# (type, heaps)			= UnsafeSubst sub type heaps
			# (types, heaps)		= get_var_types p sub heaps
			= ([type:types], heaps) 
			where
				get_type (EVar_Type type)
					= type
				get_type other
					= DummyValue
		get_var_types (CPropForall ptr p) sub heaps
			= get_var_types p sub heaps
		get_var_types _ _ heaps
			= ([], heaps)
		
		find_vars :: ![CExprH] -> [CExprVarPtr]
		find_vars [CExprVar ptr: exprs]
			= [ptr: find_vars exprs]
		find_vars [_:exprs]
			= find_vars exprs
		find_vars []
			= []
		
		mark_opaque :: !Bool ![HeapPtr] !*CProject -> *CProject
		mark_opaque on_off [ptr:ptrs] prj
			# (_, fundef, prj)						= getFunDef ptr prj
			# fundef								= {fundef & fdOpaque = on_off}
			# (_, prj)								= putFunDef ptr fundef prj
			= mark_opaque on_off ptrs prj
		mark_opaque _ [] prj
			= prj
*/

// ------------------------------------------------------------------------------------------------------------------------   
showHints :: !FormatInfo !Int ![Hint] !Colour !*PState -> (!Error, ![Hint], !MarkUpText WindowCommand, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
showHints finfo num [hint:hints] bg pstate
	# fstars						= make_stars 0 hint.hintValue
	# (error, ftactic, pstate)		= accErrorHeapsProject (FormattedShow finfo hint.hintTactic) pstate
	| isError error					= (error, hints, DummyValue, pstate)
	# ftext							= toText ftactic +++ "."
	# hint							= {hint & hintText = ftext}
	# ftactic						= ftactic ++ [CmColour Brown, CmText ".", CmEndColour]
	# (error, hints, fhints, pstate)= showHints finfo (num+1) hints bg pstate
	# ftactic						= removeCmLink ftactic
	# link_num						= if (hint.hintValue == 100) 1 0
	# flink							= [CmFontFace "Times New Roman", CmSize 8, CmBold, CmLink2 link_num "apply" (CmdApplyHint num True), CmEndBold, CmEndSize, CmEndFontFace]
	# fhint							= [CmBText (toString num +++ ". ")] ++ fstars ++ [CmSpaces 2, CmAlign "@TACTIC"] ++ ftactic ++ [CmSpaces 1] ++ flink
	# fhint							= case hint.hintValue of
										100		-> [CmBackgroundColour Yellow: fhint] ++ [CmFillLine, CmEndBackgroundColour]
										_		-> fhint
	= (error, [hint:hints], fhint ++ [CmNewlineI False 1 (Just bg)] ++ fhints, pstate)
	where
		make_stars :: !Int !Int -> MarkUpText a
		make_stars 5 value
			= [CmSize 6, CmColour LogicColour, CmText "(", CmText (toString value), CmText ")", CmEndColour, CmEndSize]
		make_stars star_num value
			# bright				= value >= (100 - 20 * star_num)
			# colour				= if bright (if (value<>100) (RGB {r=150,g=150,b=250}) (RGB {r=50,g=50,b=150})) LightGrey
			# fstar					= [CmColour colour, CmFontFace "Wingdings", CmText {toChar 171}, CmEndFontFace, CmEndColour]
			# fstars				= make_stars (star_num+1) value
			= fstar ++ fstars
showHints finfo _ [] bg pstate
	= (OK, [], [], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
sortHints :: !Int ![Hint] -> (!Bool, !Hint, ![Hint])
// ------------------------------------------------------------------------------------------------------------------------   
sortHints treshold hints
	# hints							= sortBy (\h1 h2 -> h1.hintValue > h2.hintValue) hints
	= case hints of
		[]			-> (False, DummyValue, hints)
		[hint:_]	-> case (hint.hintValue >= treshold) of
						True	-> (True, hint, hints)
						False	-> (False, DummyValue, hints)




















/*
// ------------------------------------------------------------------------------------------------------------------------   
findAbsurd :: !Int ![HypothesisPtr] ![CPropH] ![HypothesisPtr] ![CPropH] ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findAbsurd threshold [ptr:ptrs] [hyp:hyps] all_ptrs all_hyps hints pstate
	| threshold > 100				= (hints, pstate)
	# (found, other_ptr, pstate)	= check hyp all_ptrs all_hyps pstate
	| not found						= findAbsurd threshold ptrs hyps all_ptrs all_hyps hints pstate
	# hint							= {hintValue = 100, hintTactic = TacticAbsurd ptr other_ptr}
	= ([hint:hints], pstate)
	where
		check :: !CPropH ![HypothesisPtr] ![CPropH] !*PState -> (!Bool, !HypothesisPtr, !*PState)
		check p [ptr:ptrs] [q:props] pstate
			# (con, pstate)			= accHeaps (contradict p q) pstate
			| not con				= check p ptrs props pstate
			= (True, ptr, pstate)
		check p [] [] pstate
			= (False, nilPtr, pstate)
		
		contradict :: !CPropH !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		contradict (CNot p) (CNot q) heaps
			= contradict p q heaps
		contradict (CNot p) q heaps
			= AlphaEqual p q heaps
		contradict p (CNot q) heaps
			= AlphaEqual p q heaps
		contradict p q heaps
			= (False, heaps)
findAbsurd threshold [] [] _ _ hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findAbsurdEquality :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findAbsurdEquality threshold [ptr:ptrs] [hyp:hyps] toProve hints pstate
	| threshold > 100				= (hints, pstate)
	# (hit, pstate)					= accProject (absurd_equality False hyp) pstate
	| not hit						= findAbsurdEquality threshold ptrs hyps toProve hints pstate
	# hint							= {hintValue = 100, hintTactic = TacticAbsurdEqualityH ptr}
	= findAbsurdEquality threshold ptrs hyps toProve [hint:hints] pstate
findAbsurdEquality threshold [] [] toProve hints pstate
	| threshold > 100				= (hints, pstate)
	# (hit, pstate)					= accProject (absurd_equality True toProve) pstate
	| not hit						= (hints, pstate)
	# hint							= {hintValue = 100, hintTactic = TacticAbsurdEquality}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findApply :: !Int ![HypothesisPtr] ![HypothesisPtr] ![CPropH] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findApply threshold [ptr:ptrs] all_ptrs [hyp:hyps] all_hyps toProve hints pstate
	| threshold > 80				= (hints, pstate)
	# (evars, pvars, hyp)			= strip_vars hyp
	# (conditions, hyp)				= strip_conditions hyp
	# (ok, _, _, _, _, pstate)		= acc5Heaps (Match evars pvars hyp toProve) pstate
	# hint							= {hintValue = 80, hintTactic = TacticApply (HypothesisFact ptr [])}
	# hints							= if ok [hint:hints] hints
	| length conditions <> 1		= findApply threshold ptrs all_ptrs hyps all_hyps toProve hints pstate
	# condition						= hd conditions
	# fact							= HypothesisFact ptr []
	# (hints, pstate)				= try_forward ptr evars pvars condition hyp all_ptrs all_hyps all_hyps fact 80 hints pstate
	= findApply threshold ptrs all_ptrs hyps all_hyps toProve hints pstate
	where
		strip_vars :: !CPropH -> (![CExprVarPtr], ![CPropVarPtr], !CPropH)
		strip_vars (CExprForall evar p)
			# (evars, pvars, p)		= strip_vars p
			= ([evar:evars], pvars, p)
		strip_vars (CPropForall pvar p)
			# (evars, pvars, p)		= strip_vars p
			= (evars, [pvar:pvars], p)
		strip_vars other
			= ([], [], other)
		
		strip_conditions :: !CPropH -> (![CPropH], !CPropH)
		strip_conditions (CImplies p q)
			# (ps, rhs)				= strip_conditions q
			= ([p:ps], rhs)
		strip_conditions other
			= ([], other)
		
		try_forward :: !HypothesisPtr ![CExprVarPtr] ![CPropVarPtr] !CPropH !CPropH ![HypothesisPtr] ![CPropH] ![CPropH] !UseFact !Int ![Hint] !*PState -> (![Hint], !*PState)
		try_forward the_ptr evars pvars lhs rhs [ptr:ptrs] [prop:props] all_hyps fact value hints pstate
			| ptr == the_ptr				= try_forward the_ptr evars pvars lhs rhs ptrs props all_hyps fact value hints pstate
			# (ok, sub, _, _, _, pstate)	= acc5Heaps (Match evars pvars lhs prop) pstate
			| not ok						= try_forward the_ptr evars pvars lhs rhs ptrs props all_hyps fact value hints pstate
			# (new_hyp, pstate)				= accHeaps (SafeSubst sub rhs) pstate
			| isMember new_hyp all_hyps		= try_forward the_ptr evars pvars lhs rhs ptrs props all_hyps fact value hints pstate
			# hint							= {hintValue = value, hintTactic = TacticApplyH fact ptr Implicit}
			= try_forward the_ptr evars pvars lhs rhs ptrs props all_hyps fact value [hint:hints] pstate
		try_forward _ _ _ _ _ [] [] _ _ _ hints pstate
			= (hints, pstate)
findApply threshold [] all_ptrs [] all_hyps toProve hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findCase :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findCase threshold [ptr:ptrs] [COr p q:props] prop hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticCaseH Deep ptr Implicit}
	= findCase threshold ptrs props prop [hint:hints]
findCase threshold [ptr:ptrs] [_:props] prop hints
	= findCase threshold ptrs props prop hints
findCase threshold [] [] (COr p q) hints
	| threshold > 90				= hints
	# nr_ors						= count_ors (COr p q)
	| nr_ors == 2
		# hint1						= {hintValue = 90, hintTactic = TacticCase Shallow 1}
		# hint2						= {hintValue = 90, hintTactic = TacticCase Shallow 2}
		= [hint1,hint2:hints]
	# more_hints					= [{hintValue = 90, hintTactic = TacticCase Deep n} \\ n <- [1..nr_ors]]
	= more_hints ++ hints
	where
		count_ors :: !CPropH -> Int
		count_ors (COr p q)			= count_ors p + count_ors q
		count_ors p					= 1
findCase _ _ _ _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findCases :: !Int ![CExprVarPtr] ![CExprVarPtr] ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findCases threshold [ptr:ptrs] case_vars hints
	| threshold > 60				= hints
	| not (isMember ptr case_vars)	= findCases threshold ptrs case_vars hints
	# hint							= {hintValue = 60, hintTactic = TacticCases (CExprVar ptr) Implicit}
	= findCases threshold ptrs case_vars [hint:hints]
findCases threshold [] case_vars hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findContradiction :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findContradiction threshold [ptr:ptrs] [CNot p:props] prop hints
	| threshold > 85				= hints
	| threshold > 40				= findContradiction threshold ptrs props prop hints
	# hint							= {hintValue = 40, hintTactic = TacticContradictionH ptr}
	= findContradiction threshold ptrs props prop [hint:hints]
findContradiction threshold [_:ptrs] [_:props] prop hints
	= findContradiction threshold ptrs props prop hints
findContradiction threshold [] [] (CNot p) hints
	| threshold > 85				= hints
	# hint							= {hintValue = 85, hintTactic = TacticContradiction Implicit}
	= [hint:hints]
findContradiction threshold [] [] _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findDefinedness :: !Int !(!Bool, ![CExprH], ![CExprH]) ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findDefinedness threshold (con, defs, undefs) hints
	| threshold > 100				= hints
	# hit							= con || contradict defs undefs
	| not hit						= hints
	# hint							= {hintValue = 100, hintTactic = TacticDefinedness}
	= [hint:hints]
	where
		contradict :: ![CExprH] ![CExprH] -> Bool
		contradict [expr:exprs] undefined
			| isMember expr undefined						= True
			= contradict exprs undefined
		contradict [] undefined
			= False

// ------------------------------------------------------------------------------------------------------------------------   
findExact :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findExact threshold [ptr:ptrs] [hyp:hyps] toProve hints pstate
	| threshold > 100				= (hints, pstate)
	# (equal, pstate)				= accHeaps (AlphaEqual hyp toProve) pstate
	| not equal						= findExact threshold ptrs hyps toProve hints pstate
	# hint							= {hintValue = 100, hintTactic = TacticExact (HypothesisFact ptr [])}
	= findExact threshold ptrs hyps toProve [hint:hints] pstate
findExact threshold [] [] toProve hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findExFalso :: !Int ![HypothesisPtr] ![CPropH] ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findExFalso threshold [ptr:ptrs] [CFalse:hyps] hints pstate
	| threshold > 100				= (hints, pstate)
	# hint							= {hintValue = 100, hintTactic = TacticExFalso ptr}
	= findExFalso threshold ptrs hyps [hint:hints] pstate
findExFalso threshold [ptr:ptrs] [hyp:hyps] hints pstate
	= findExFalso threshold ptrs hyps hints pstate
findExFalso threshold [] [] hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findExtensionality :: !Int !CTypeH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findExtensionality threshold (_ ==> _) hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticExtensionality "ext"}
	= [hint:hints]
findExtensionality _ _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findInduction :: !Int !Goal !CPropH ![CTypeH] ![CExprVarPtr] ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findInduction threshold goal (CExprForall ptr p) [type:types] case_vars hints
	| threshold > 80				= hints
	# hit							= is_inductive_type type
	| not hit						= findInduction threshold goal p types case_vars hints
	| not (isMember ptr case_vars)	= findInduction threshold goal p types case_vars hints
	# hint_value					= case isMember ptr goal.glInductionVars of
										True	-> 60
										False	-> 80
	| threshold > hint_value		= findInduction threshold goal p types case_vars hints		// reverse order of variables!
	# hint							= {hintValue = hint_value, hintTactic = TacticInduction ptr Implicit}
	# hints							= findInduction threshold goal p types case_vars hints		// reverse order of variables!
	= [hint:hints]
	where
		is_inductive_type :: !CTypeH -> Bool
		is_inductive_type (ptr @@^ _)
			= ptrKind ptr == CAlgType
		is_inductive_type other
			= False
findInduction threshold goal (CPropForall ptr p) types case_vars hints
	= findInduction threshold goal p types case_vars hints
findInduction _ _ _ _ _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findIntArith :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findIntArith threshold [ptr:ptrs] [hyp:hyps] toProve hints pstate
	| threshold > 80				= (hints, pstate)
	# (error, (changed, _), pstate)	= accErrorHeapsProject (actOnExprLocation AllSubExprs hyp ArithInt) pstate
	| isError error					= findIntArith threshold ptrs hyps toProve hints pstate
	| not changed					= findIntArith threshold ptrs hyps toProve hints pstate
	# hint							= {hintValue = 80, hintTactic = TacticIntArithH AllSubExprs ptr Implicit}
	= findIntArith threshold ptrs hyps toProve [hint:hints] pstate
findIntArith threshold [] [] toProve hints pstate
	| threshold > 80				= (hints, pstate)
	# (error, (changed, _), pstate)	= accErrorHeapsProject (actOnExprLocation AllSubExprs toProve ArithInt) pstate
	| isError error					= (hints, pstate)
	| not changed					= (hints, pstate)
	# hint							= {hintValue = 80, hintTactic = TacticIntArith AllSubExprs}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findIntCompare :: !Int !Goal ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findIntCompare threshold goal hints pstate
	| threshold > 100				= (hints, pstate)
	# (contradiction, pstate)		= accHeapsProject (CompareInts goal) pstate
	| not contradiction				= (hints, pstate)
	# hint							= {hintValue = 100, hintTactic = TacticIntCompare}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findInjective :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findInjective threshold [ptr:ptrs] [hyp:hyps] toProve hints pstate
	| threshold > 90				= (hints, pstate)
	# (ok, score, _, pstate)		= acc3HeapsProject (inject False hyp) pstate
	| not ok						= findInjective threshold ptrs hyps toProve hints pstate
	# value							= case score of
										1		-> 50
										2		-> 70
										3		-> 90
	| threshold > value				= findInjective threshold ptrs hyps toProve hints pstate
	# hint							= {hintValue = value, hintTactic = TacticInjectiveH ptr Implicit}
	= findInjective threshold ptrs hyps toProve [hint:hints] pstate
findInjective threshold [] [] toProve hints pstate
	# (ok, score, _, pstate)		= acc3HeapsProject (inject True toProve) pstate
	| not ok						= (hints, pstate)
	# value							= case score of
										1		-> 50
										2		-> 70
										3		-> 90
	| threshold > value				= (hints, pstate)
	# hint							= {hintValue = value, hintTactic = TacticInjective}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findIntros :: !Int !Int !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findIntros threshold num prop hints pstate
	| threshold > 75				= (hints, pstate)
	# (names, pstate)				= accHeaps (findNames num prop) pstate
	| isEmpty names					= (hints, pstate)
	# hint							= {hintValue = 75, hintTactic = TacticIntroduce names}
	= ([hint:hints], pstate)
	where
		findNames :: !Int !CPropH !*CHeaps -> (![CName], !*CHeaps)
		findNames num (CImplies p q) heaps
			# name					= "H" +++ toString num
			# (names, heaps)		= findNames (num+1) q heaps
			= ([name:names], heaps)
		findNames num (CExprForall ptr p) heaps
			# (var, heaps)			= readPointer ptr heaps
			# name					= var.evarName
			# (names, heaps)		= findNames num p heaps
			= ([name:names], heaps)
		findNames num (CPropForall ptr p) heaps
			# (var, heaps)			= readPointer ptr heaps
			# name					= var.pvarName
			# (names, heaps)		= findNames num p heaps
			= ([name:names], heaps)
		findNames num _ heaps
			= ([], heaps)

// ------------------------------------------------------------------------------------------------------------------------   
findReduce :: !Int !ReductionOptions ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findReduce threshold options [ptr:ptrs] [hyp:hyps] toProve hints pstate
	| threshold > 80				= (hints, pstate)
	# (form, pstate)				= accHeapsProject (getExprForm options hyp) pstate
	# hit							= case form of
										Reducable		-> True
										_				-> False
	| not hit						= findReduce threshold options ptrs hyps toProve hints pstate
	# hint							= {hintValue = 80, hintTactic = TacticReduceH Defensive ReduceToNF AllSubExprs ptr [] Implicit}
	= findReduce threshold options ptrs hyps toProve [hint:hints] pstate
findReduce threshold options [] [] toProve hints pstate
	| threshold > 80				= (hints, pstate)
	# (form, pstate)				= accHeapsProject (getExprForm options toProve) pstate
	# hit							= case form of
										Reducable		-> True
										_				-> False
	| not hit						= (hints, pstate)
	# hint							= {hintValue = 80, hintTactic = TacticReduce Defensive ReduceToNF AllSubExprs []}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findReflexive :: !Int !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findReflexive threshold (CImplies p q) hints pstate
	= findReflexive threshold q hints pstate
findReflexive threshold (CExprForall var p) hints pstate
	= findReflexive threshold p hints pstate
findReflexive threshold (CExprExists var p) hints pstate
	= findReflexive threshold p hints pstate
findReflexive threshold (CPropForall var p) hints pstate
	= findReflexive threshold p hints pstate
findReflexive threshold (CPropExists var p) hints pstate
	= findReflexive threshold p hints pstate
findReflexive threshold (CEqual e1 e2) hints pstate
	| threshold > 100				= (hints, pstate)
	# (equal, pstate)				= accHeaps (AlphaEqual e1 e2) pstate
	| not equal						= (hints, pstate)
	# hint							= {hintValue = 100, hintTactic = TacticReflexive}
	= ([hint:hints], pstate)
findReflexive threshold (CIff p q) hints pstate
	| threshold > 100				= (hints, pstate)
	# (equal, pstate)				= accHeaps (AlphaEqual p q) pstate
	| not equal						= (hints, pstate)
	# hint							= {hintValue = 100, hintTactic = TacticReflexive}
	= ([hint:hints], pstate)
findReflexive _ _ hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findRewrite :: !Int ![HypothesisPtr] ![CPropH] !Goal ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findRewrite threshold [ptr:ptrs] [prop:props] goal hints pstate
	# fact							= HypothesisFact ptr []
	# (forward, backward)			= rewriteScores prop
	# (hints, pstate)				= findFactRewrite threshold fact prop LeftToRight forward goal.glHypotheses goal hints pstate
	# (hints, pstate)				= findFactRewrite threshold fact prop RightToLeft backward goal.glHypotheses goal hints pstate
	= findRewrite threshold ptrs props goal hints pstate
findRewrite treshold [] [] goal hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findSplit :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findSplit threshold [ptr:ptrs] [CAnd p q:props] prop hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticSplitH ptr Deep Implicit}
	= findSplit threshold ptrs props prop [hint:hints]
findSplit threshold [ptr:ptrs] [_:props] prop hints
	= findSplit threshold ptrs props prop hints
findSplit threshold [] [] (CAnd p q) hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticSplit Deep}
	= [hint:hints]
findSplit _ _ _ _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findSplitIff :: !Int ![HypothesisPtr] ![CPropH] !CPropH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findSplitIff threshold [ptr:ptrs] [CIff p q:props] prop hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticSplitIffH ptr Implicit}
	= findSplitIff threshold ptrs props prop [hint:hints]
findSplitIff threshold [ptr:ptrs] [_:props] prop hints
	= findSplitIff threshold ptrs props prop hints
findSplitIff threshold [] [] (CIff p q) hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticSplitIff}
	= [hint:hints]
findSplitIff _ _ _ _ hints
	= hints

// BEZIG
// Remark: I am passing the CProject because I want to check for infix functions. (changes the indexes produced)
//         However, in this case it is sufficient to know the NUMBER of cases.
//         The order is not relevant (only producing hints here!)
//         This function can thus be simplified (but don't feel like it now).
// ------------------------------------------------------------------------------------------------------------------------   
findSplitCase :: !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findSplitCase prop hints pstate
	# (_, hints, pstate)			= acc2Project (find_in_prop 0 prop hints) pstate
	= (hints, pstate)
	where
		find_in_prop :: !Int !CPropH ![Hint] !*CProject -> (!Int, ![Hint], !*CProject)
		find_in_prop nr_passed CTrue hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed CFalse hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CPropVar _) hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CEqual e1 e2) hints prj
			# (nr_passed, hints, prj)		= find_in_expr nr_passed e1 hints prj
			= find_in_expr nr_passed e2 hints prj
		find_in_prop nr_passed (CNot p) hints prj
			= find_in_prop nr_passed p hints prj
		find_in_prop nr_passed (CAnd p q) hints prj
			# (nr_passed, p, prj)			= find_in_prop nr_passed p hints prj
			= find_in_prop nr_passed q hints prj
		find_in_prop nr_passed (COr p q) hints prj
			# (nr_passed, p, prj)			= find_in_prop nr_passed p hints prj
			= find_in_prop nr_passed q hints prj
		find_in_prop nr_passed (CImplies p q) hints prj
			# (nr_passed, p, prj)			= find_in_prop nr_passed p hints prj
			= find_in_prop nr_passed q hints prj
		find_in_prop nr_passed (CIff p q) hints prj
			# (nr_passed, p, prj)			= find_in_prop nr_passed p hints prj
			= find_in_prop nr_passed q hints prj
		find_in_prop nr_passed (CExprForall _ _) hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CExprExists _ _) hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CPropForall _ _) hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CPropExists _ _) hints prj
			= (nr_passed, hints, prj)
		find_in_prop nr_passed (CPredicate ptr exprs) hints prj
			= (nr_passed, hints, prj)
		
		find_in_expr :: !Int !CExprH ![Hint] !*CProject -> (!Int, ![Hint], !*CProject)
		find_in_expr nr_passed (CExprVar _) hints prj
			= (nr_passed, hints, prj)
		find_in_expr nr_passed (CShared _) hints prj
			= (nr_passed, hints, prj)
		find_in_expr nr_passed (expr @# exprs) hints prj
			# (nr_passed, hints, prj)		= find_in_expr nr_passed expr hints prj
			= find_in_exprs nr_passed exprs hints prj
		find_in_expr nr_passed (ptr @@# exprs) hints prj
			| ptrKind ptr <> CFun			= find_in_exprs nr_passed exprs hints prj
			| length exprs <> 2				= find_in_exprs nr_passed exprs hints prj
			# (_, fundef, prj)				= getFunDef ptr prj
			| not (isInfix fundef.fdInfix)	= find_in_exprs nr_passed exprs hints prj
			# (nr_passed, hints, prj)		= find_in_expr nr_passed (hd exprs) hints prj
			= find_in_expr nr_passed (hd (tl exprs)) hints prj
		find_in_expr nr_passed (CLet strict lets expr) hints prj
			# (_, exprs)					= unzip lets
			# (nr_passed, hints, prj)		= find_in_exprs nr_passed exprs hints prj
			= find_in_expr nr_passed expr hints prj
		find_in_expr nr_passed (CCase expr patterns def) hints prj
			# hint							= {hintValue = 75 - (5*nr_passed), hintTactic = TacticSplitCase (nr_passed+1) Implicit}
			# hints							= [hint:hints]
			# nr_passed						= nr_passed + 1
			# (nr_passed, hints, prj)		= find_in_expr nr_passed expr hints prj
			# (nr_passed, hints, prj)		= find_in_exprs nr_passed (get_exprs patterns) hints prj
			= case def of
				(Just e)					-> find_in_expr nr_passed e hints prj
				Nothing						-> (nr_passed, hints, prj)
			where
				get_exprs :: !CCasePatternsH -> [CExprH]
				get_exprs (CAlgPatterns _ patterns)
					= [pattern.atpResult \\ pattern <- patterns]
				get_exprs (CBasicPatterns _ patterns)
					= [pattern.bapResult \\ pattern <- patterns]
		find_in_expr nr_passed (CBasicValue value) hints prj
			= find_in_exprs nr_passed (get_exprs value) hints prj
			where
				get_exprs :: !CBasicValueH -> [CExprH]
				get_exprs (CBasicArray exprs)
					= exprs
				get_exprs _
					= []
		find_in_expr nr_passed (CCode _ _) hints prj
			= (nr_passed, hints, prj)
		find_in_expr nr_passed CBottom hints prj
			= (nr_passed, hints, prj)
		
		find_in_exprs :: !Int ![CExprH] ![Hint] !*CProject -> (!Int, ![Hint], !*CProject)
		find_in_exprs nr_passed [expr:exprs] hints prj
			# (nr_passed, hints, prj)		= find_in_expr nr_passed expr hints prj
			= find_in_exprs nr_passed exprs hints prj
		find_in_exprs nr_passed [] hints prj
			= (nr_passed, hints, prj)

// ------------------------------------------------------------------------------------------------------------------------   
findTheoremHints :: !Int !TheoremPtr ![HintTheorem] ![CPropH] !Goal ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findTheoremHints threshold ptr [thint:thints] hyps goal hints pstate
	| thint.hintPointer == ptr		= findTheoremHints threshold ptr thints hyps goal hints pstate
	# fact							= TheoremFact thint.hintPointer []
	# rule							= thint.hintProp
	| thint.hintRewriteLRScore > 0
		# (hints, pstate)			= findFactRewrite threshold fact rule LeftToRight thint.hintRewriteLRScore goal.glHypotheses goal hints pstate
		= findTheoremHints threshold ptr thints hyps goal hints pstate
	| thint.hintRewriteRLScore > 0
		# (hints, pstate)			= findFactRewrite threshold fact rule RightToLeft thint.hintRewriteRLScore goal.glHypotheses goal hints pstate
		= findTheoremHints threshold ptr thints hyps goal hints pstate
	# (evars, pvars, prop)			= strip_vars thint.hintProp
	# (conditions, prop)			= strip_conditions prop
	| thint.hintApplyScore > 0
		| threshold > thint.hintApplyScore
									= findTheoremHints threshold ptr thints hyps goal hints pstate
		# (ok, _, _, _, _, pstate)	= acc5Heaps (Match evars pvars prop goal.glToProve) pstate
		| not ok					= findTheoremHints threshold ptr thints hyps goal hints pstate
		# hint						= {hintValue = thint.hintApplyScore, hintTactic = TacticApply fact}
		= findTheoremHints threshold ptr thints hyps goal [hint:hints] pstate
	| thint.hintApplyForwardScore > 0
		| threshold > thint.hintApplyForwardScore
									= findTheoremHints threshold ptr thints hyps goal hints pstate
		| length conditions <> 1	= findTheoremHints threshold ptr thints hyps goal hints pstate
		# condition					= hd conditions
		# (hints, pstate)			= try_forward evars pvars condition prop goal.glHypotheses hyps hyps fact thint.hintApplyForwardScore hints pstate
		= findTheoremHints threshold ptr thints hyps goal hints pstate
	= findTheoremHints threshold ptr thints hyps goal hints pstate
	where
		strip_vars :: !CPropH -> (![CExprVarPtr], ![CPropVarPtr], !CPropH)
		strip_vars (CExprForall evar p)
			# (evars, pvars, p)		= strip_vars p
			= ([evar:evars], pvars, p)
		strip_vars (CPropForall pvar p)
			# (evars, pvars, p)		= strip_vars p
			= (evars, [pvar:pvars], p)
		strip_vars other
			= ([], [], other)
		
		strip_conditions :: !CPropH -> (![CPropH], !CPropH)
		strip_conditions (CImplies p q)
			# (ps, rhs)				= strip_conditions q
			= ([p:ps], rhs)
		strip_conditions other
			= ([], other)
		
		try_forward :: ![CExprVarPtr] ![CPropVarPtr] !CPropH !CPropH ![HypothesisPtr] ![CPropH] ![CPropH] !UseFact !Int ![Hint] !*PState -> (![Hint], !*PState)
		try_forward evars pvars lhs rhs [ptr:ptrs] [prop:props] all_hyps fact value hints pstate
			# (ok, sub, _, _, _, pstate)	= acc5Heaps (Match evars pvars lhs prop) pstate
			| not ok						= try_forward evars pvars lhs rhs ptrs props all_hyps fact value hints pstate
			# (new_hyp, pstate)				= accHeaps (SafeSubst sub rhs) pstate
			| isMember new_hyp all_hyps		= try_forward evars pvars lhs rhs ptrs props all_hyps fact value hints pstate
			# hint							= {hintValue = value, hintTactic = TacticApplyH fact ptr Implicit}
			= try_forward evars pvars lhs rhs ptrs props all_hyps fact value [hint:hints] pstate
		try_forward _ _ _ _ [] [] _ _ _ hints pstate
			= (hints, pstate)
findTheoremHints threshold ptr [] hyps goal hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
findTrivial :: !Int !CPropH ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findTrivial threshold (CExprForall _ p) hints
	= findTrivial threshold p hints
findTrivial threshold (CExprExists _ p) hints
	= findTrivial threshold p hints
findTrivial threshold (CPropForall _ p) hints
	= findTrivial threshold p hints
findTrivial threshold (CPropExists _ p) hints
	= findTrivial threshold p hints
findTrivial threshold (CImplies p q) hints
	= findTrivial threshold q hints
findTrivial threshold CTrue hints
	| threshold > 100				= hints
	# hint							= {hintValue = 100, hintTactic = TacticTrivial}
	= [hint:hints]
findTrivial _ _ hints
	= hints

// ------------------------------------------------------------------------------------------------------------------------   
findWitness :: !Int ![HypothesisPtr] ![CPropH] ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
findWitness threshold [ptr:ptrs] [CExprExists _ _:props] hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticWitnessH ptr Implicit}
	= findWitness threshold ptrs props [hint:hints]
findWitness threshold [ptr:ptrs] [CPropExists _ _:props] hints
	| threshold > 90				= hints
	# hint							= {hintValue = 90, hintTactic = TacticWitnessH ptr Implicit}
	= findWitness threshold ptrs props [hint:hints]
findWitness threshold [_:ptrs] [_:props] hints
	= findWitness threshold ptrs props hints
findWitness threshold [] [] hints
	= hints
























// ------------------------------------------------------------------------------------------------------------------------   
rewriteScores :: !CPropH -> (!Int, !Int)
// ------------------------------------------------------------------------------------------------------------------------   
rewriteScores CTrue
	= (0, 0)
rewriteScores CFalse
	= (0, 0)
rewriteScores (CPropVar _)
	= (0, 0)
rewriteScores (CEqual e1 e2)
	| is_base e1				= if (is_base e2) (0,0) (0,75)
	| is_base e2				= (75,0)
	| e1 == e2					= (0, 0)
	= (70,55)
	where
		is_base :: !CExprH -> Bool
		is_base (ptr @@# _)
			= ptrKind ptr == CDataCons
		is_base (CBasicValue _)
			= True
		is_base CBottom
			= True
		is_base other
			= False
rewriteScores (CNot p)
	= (0, 0)
rewriteScores (CImplies p q)
	= rewriteScores q
rewriteScores (CAnd p q)
	= (0, 0)
rewriteScores (COr p q)
	= (0, 0)
rewriteScores (CIff p q)
	| is_base p					= if (is_base q) (0,0) (0,75)
	| is_base q					= (75,0)
	| p == q					= (0, 0)
	= (70,55)
	where
		is_base :: !CPropH -> Bool
		is_base CTrue
			= True
		is_base CFalse
			= True
		is_base other
			= False
rewriteScores (CExprForall _ p)
	= rewriteScores p
rewriteScores (CExprExists _ p)
	= (0, 0)
rewriteScores (CPropForall _ p)
	= rewriteScores p
rewriteScores (CPropExists _ p)
	= (0, 0)
rewriteScores (CPredicate _ _)
	= (0, 0)

// ------------------------------------------------------------------------------------------------------------------------   
findFactRewrite :: !Int !UseFact !CPropH !RewriteDirection !Int ![HypothesisPtr] !Goal ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findFactRewrite threshold fact rule dir value [ptr:ptrs] goal hints pstate
	| threshold > value - 10		= findFactRewrite threshold fact rule dir value [] goal hints pstate
	| fact == HypothesisFact ptr []	= findFactRewrite threshold fact rule dir value ptrs goal hints pstate
	# (ok, pstate)					= accHeapsProject (checkRewriteInHypothesis rule dir ptr goal) pstate
	| not ok						= findFactRewrite threshold fact rule dir value ptrs goal hints pstate
	# hint							= {hintValue = value-10, hintTactic = TacticRewriteH dir AllRedexes fact ptr Implicit}
	= findFactRewrite threshold fact rule dir value ptrs goal [hint:hints] pstate
findFactRewrite threshold fact rule dir value [] goal hints pstate
	| threshold > value				= (hints, pstate)
	# (error, _, _, _, pstate)		= acc4HeapsProject (RewriteN dir AllRedexes fact goal) pstate
	| isError error					= (hints, pstate)
	# hint							= {hintValue = value, hintTactic = TacticRewrite dir AllRedexes fact}
	= ([hint:hints], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
realSymbolTypeArguments :: !CSymbolTypeH -> [CTypeH]
// ------------------------------------------------------------------------------------------------------------------------   
realSymbolTypeArguments syt
	# normal_args					= syt.sytArguments
	# extra_args					= get_extra_args syt.sytResult
	= normal_args ++ extra_args
	where
		get_extra_args :: !CTypeH -> [CTypeH]
		get_extra_args (type1 ==> type2)
			# types					= get_extra_args type2
			= [type1:types]
		get_extra_args _
			= []

// ------------------------------------------------------------------------------------------------------------------------   
:: ExprForm =
// ------------------------------------------------------------------------------------------------------------------------   
	  Reducable
	| RootNormalForm
	| VariableNormalForm			// not reducable (mostly used for variables)
	| Defined						// depends on defined variables
	| Undefined

// ------------------------------------------------------------------------------------------------------------------------   
class getExprForm a :: !ReductionOptions !a !*CHeaps !*CProject -> (!ExprForm, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance getExprForm (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	getExprForm options (CExprVar ptr) heaps prj
		# defined_var				= isMember ptr options.roDefinedVariables
		= case defined_var of
			True	-> (Defined, heaps, prj)
			False	-> (VariableNormalForm, heaps, prj)
	getExprForm options (CShared ptr) heaps prj
		= (VariableNormalForm, heaps, prj)			// all sharing should have been removed
	getExprForm options ((_ @# _) @# _) heaps prj
		= (Reducable, heaps, prj)
	getExprForm options ((_ @@# _) @# _) heaps prj
		= (Reducable, heaps, prj)
	getExprForm options (_ @# []) heaps prj
		= (Reducable, heaps, prj)
	getExprForm options (expr @# _) heaps prj
		# (form, heaps, prj)		= getExprForm options expr heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> (VariableNormalForm, heaps, prj)
			VariableNormalForm		-> (VariableNormalForm, heaps, prj)
			Defined					-> (VariableNormalForm, heaps, prj)
			Undefined				-> (Reducable, heaps, prj)
	getExprForm options (ptr @@# exprs) heaps prj
		| ptrKind ptr == CFun
			# (error, fundef, prj)	= getFunDef ptr prj
			| isError error			= (VariableNormalForm, heaps, prj)
			# arg_types				= realSymbolTypeArguments fundef.fdSymbolType
			= case fundef.fdOpaque of
				True	-> reducableArgs (Just fundef) False 0 options 0 arg_types exprs heaps prj
				False	-> reducableArgs (Just fundef) True  0 options 0 arg_types exprs heaps prj
		| ptrKind ptr == CDataCons
			# (error, consdef, prj)	= getDataConsDef ptr prj
			| isError error			= (VariableNormalForm, heaps, prj)
			# arg_types				= consdef.dcdSymbolType.sytArguments
			= reducableArgs Nothing False 0 options 0 arg_types exprs heaps prj
	getExprForm options (CLet False _ _) heaps prj
		= (Reducable, heaps, prj)
	getExprForm options (CLet True [(_,expr)] _) heaps prj
		# (form, heaps, prj)		= getExprForm options expr heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> (Reducable, heaps, prj)
			VariableNormalForm		-> (VariableNormalForm, heaps, prj)
			Defined					-> (Reducable, heaps, prj)
			Undefined				-> (Reducable, heaps, prj)
	getExprForm options (CCase expr _ _) heaps prj
		# (form, heaps, prj)		= getExprForm options expr heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> (Reducable, heaps, prj)
			VariableNormalForm		-> (VariableNormalForm, heaps, prj)
			Defined					-> (VariableNormalForm, heaps, prj)
			Undefined				-> (Reducable, heaps, prj)
	getExprForm options (CBasicValue value) heaps prj
		= (RootNormalForm, heaps, prj)
	getExprForm options (CCode codetype codecontents) heaps prj
		= (VariableNormalForm, heaps, prj)
	getExprForm options CBottom heaps prj
		= (Undefined, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance getExprForm (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	getExprForm options (CPropVar ptr) heaps prj
		= (VariableNormalForm, heaps, prj)
	getExprForm options CTrue heaps prj
		= (VariableNormalForm, heaps, prj)
	getExprForm options CFalse heaps prj
		= (VariableNormalForm, heaps, prj)
	getExprForm options (CEqual e1 e2) heaps prj
		# (form, heaps, prj)		= getExprForm options e1 heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> getExprForm options e2 heaps prj
			VariableNormalForm		-> getExprForm options e2 heaps prj
			Defined					-> getExprForm options e2 heaps prj
			Undefined				-> getExprForm options e2 heaps prj
	getExprForm options (CNot p) heaps prj
		= getExprForm options p heaps prj
	getExprForm options (CAnd p q) heaps prj
		# (form, heaps, prj)		= getExprForm options p heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> getExprForm options q heaps prj
			VariableNormalForm		-> getExprForm options q heaps prj
			Defined					-> getExprForm options q heaps prj
			Undefined				-> getExprForm options q heaps prj
	getExprForm options (COr p q) heaps prj
		# (form, heaps, prj)		= getExprForm options p heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> getExprForm options q heaps prj
			VariableNormalForm		-> getExprForm options q heaps prj
			Defined					-> getExprForm options q heaps prj
			Undefined				-> getExprForm options q heaps prj
	getExprForm options (CImplies p q) heaps prj
		# (form, heaps, prj)		= getExprForm options p heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> getExprForm options q heaps prj
			VariableNormalForm		-> getExprForm options q heaps prj
			Defined					-> getExprForm options q heaps prj
			Undefined				-> getExprForm options q heaps prj
	getExprForm options (CIff p q) heaps prj
		# (form, heaps, prj)		= getExprForm options p heaps prj
		= case form of
			Reducable				-> (Reducable, heaps, prj)
			RootNormalForm			-> getExprForm options q heaps prj
			VariableNormalForm		-> getExprForm options q heaps prj
			Defined					-> getExprForm options q heaps prj
			Undefined				-> getExprForm options q heaps prj
	getExprForm options (CExprForall ptr p) heaps prj
		= getExprForm options p heaps prj
	getExprForm options (CExprExists ptr p) heaps prj
		= getExprForm options p heaps prj
	getExprForm options (CPropForall ptr p) heaps prj
		= getExprForm options p heaps prj
	getExprForm options (CPropExists ptr p) heaps prj
		= getExprForm options p heaps prj
	getExprForm options (CPredicate ptr exprs) heaps prj
		= (VariableNormalForm, heaps, prj)

// ========================================================================================================================
// As in DEFENSIVE mode.
// @2: True means that the function may still be expanded.
//     False is used for the case that a erronous variable argument is encountered. (try to reduce other args)
// @3: 0 = only RNF's have been passed
//     1 = a Defined has been passed, but not a VNF
//     2 = passed a VNF somewhere
// ------------------------------------------------------------------------------------------------------------------------   
reducableArgs :: !(Maybe CFunDefH) !Bool !Int !ReductionOptions !Int ![CTypeH] ![CExprH] !*CHeaps !*CProject -> (!ExprForm, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
reducableArgs mb_fundef may_expand passed options index [CStrict type:types] [expr:exprs] heaps prj
	# (form, heaps, prj)			= getExprForm options expr heaps prj
	= case form of
		Reducable					-> (Reducable, heaps, prj)
		RootNormalForm				-> reducableArgs mb_fundef may_expand passed options (index+1) types exprs heaps prj
		VariableNormalForm			-> reducableArgs mb_fundef (expand_vnf mb_fundef may_expand) 2 options (index+1) types exprs heaps prj
		Defined						-> reducableArgs mb_fundef (expand_def mb_fundef may_expand) (max 1 passed) options (index+1) types exprs heaps prj
		Undefined					-> (Reducable, heaps, prj)
	where
		expand_vnf :: !(Maybe CFunDefH) !Bool -> Bool
		expand_vnf _ False
			= False
		expand_vnf (Just fundef) True
			| isJust fundef.fdDeltaRule							= False
			| isMember index fundef.fdCaseVariables				= False
			| isMember index fundef.fdStrictVariables			= True
			= False
		
		expand_def :: !(Maybe CFunDefH) !Bool -> Bool
		expand_def _ False
			= False
		expand_def (Just fundef) True
			| isJust fundef.fdDeltaRule							= False
			| isMember index fundef.fdCaseVariables				= False
			= True
reducableArgs mb_fundef may_expand passed options index [type:types] [expr:exprs] heaps prj
	= reducableArgs mb_fundef may_expand passed options (index+1) types exprs heaps prj
reducableArgs _ True _ _ _ _ _ heaps prj
	= (Reducable, heaps, prj)
reducableArgs Nothing False passed _ _ _ _ heaps prj
	= case passed of
		0		-> (RootNormalForm, heaps, prj)
		1		-> (RootNormalForm, heaps, prj)					// old try: Defined [strict constructor with all args Defined should be regarded as RootNormalForm!]
		2		-> (VariableNormalForm, heaps, prj)
reducableArgs (Just fundef) False passed _ _ _ _ heaps prj
	= case passed of
		0		-> (VariableNormalForm, heaps, prj)				// impossible case??
		1		-> case fundef.fdHalting of
						True	-> (Defined, heaps, prj)
						False	-> (VariableNormalForm, heaps, prj)
		2		-> (VariableNormalForm, heaps, prj)
*/




























// ------------------------------------------------------------------------------------------------------------------------   
class findCaseVars a :: ![CExprVarPtr] !a !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance findCaseVars [a] | findCaseVars a
// ------------------------------------------------------------------------------------------------------------------------   
where
	findCaseVars vars [x:xs] heaps prj
		# (vars, heaps, prj)		= findCaseVars vars x heaps prj
		= findCaseVars vars xs heaps prj
	findCaseVars vars [] heaps prj
		= (vars, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance findCaseVars (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findCaseVars vars (CExprVar ptr) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars (expr @# exprs) heaps prj
		= findCaseVars vars expr heaps prj
	findCaseVars vars (ptr @@# exprs) heaps prj
		| ptrKind ptr == CDataCons
			# (_, consdef, prj)		= getDataConsDef ptr prj
			= add vars 0 consdef.dcdSymbolType.sytArguments exprs [] heaps prj
//		| ptrKind ptr == CFun
			# (_, fundef, prj)		= getFunDef ptr prj
			= add vars 0 fundef.fdSymbolType.sytArguments exprs fundef.fdCaseVariables heaps prj
		where
			add :: ![CExprVarPtr] !Int ![CTypeH] ![CExprH] ![Int] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
			add vars index [type:types] [CExprVar ptr:exprs] case_vars heaps prj
				| not (check type)	= add vars (index+1) types exprs case_vars heaps prj
				= case isMember index case_vars of
					True			-> add [ptr:vars] (index+1) types exprs case_vars heaps prj
					False			-> add vars (index+1) types exprs case_vars heaps prj
				where
					check :: !CTypeH -> Bool
					check (CStrict type)					= check type
					check (CBasicType CInteger)				= False
					check (CBasicType CRealNumber)			= False
					check (CBasicType CCharacter)			= False
					check _									= True
			add vars index [CStrict type:types] [expr:exprs] case_vars heaps prj
				# (vars, heaps, prj)= findCaseVars vars expr heaps prj
				= add vars (index+1) types exprs case_vars heaps prj
			add vars index [type:types] [expr:exprs] case_vars heaps prj
				= add vars (index+1) types exprs case_vars heaps prj
			add vars index _ _ _ heaps prj
				= (vars, heaps, prj)
	findCaseVars vars (CLet False lets expr) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars (CLet True [(var,expr)] _) heaps prj
		= findCaseVars vars expr heaps prj
	findCaseVars vars (CCase (CExprVar ptr) patterns def) heaps prj
		= ([ptr:vars], heaps, prj)
	findCaseVars vars (CCase expr patterns def) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars (CBasicValue value) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars (CCode _ _) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars CBottom heaps prj
		= (vars, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance findCaseVars (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findCaseVars vars (CPropVar ptr) heaps prj
		= (vars, heaps, prj)
	findCaseVars vars CTrue heaps prj
		= (vars, heaps, prj)
	findCaseVars vars CFalse heaps prj
		= (vars, heaps, prj)
	findCaseVars vars (CEqual e1 e2) heaps prj
		# (vars, heaps, prj)		= findCaseVars vars e1 heaps prj
		= findCaseVars vars e2 heaps prj
	findCaseVars vars (CNot p) heaps prj
		= findCaseVars vars p heaps prj
	findCaseVars vars (CAnd p q) heaps prj
		# (vars, heaps, prj)		= findCaseVars vars p heaps prj
		= findCaseVars vars q heaps prj
	findCaseVars vars (COr p q) heaps prj
		# (vars, heaps, prj)		= findCaseVars vars p heaps prj
		= findCaseVars vars q heaps prj
	findCaseVars vars (CImplies p q) heaps prj
		# (vars, heaps, prj)		= findCaseVars vars p heaps prj
		= findCaseVars vars q heaps prj
	findCaseVars vars (CIff p q) heaps prj
		# (vars, heaps, prj)		= findCaseVars vars p heaps prj
		= findCaseVars vars q heaps prj
	findCaseVars vars (CExprForall var p) heaps prj
		= findCaseVars vars p heaps prj
	findCaseVars vars (CExprExists var p) heaps prj
		= findCaseVars vars p heaps prj
	findCaseVars vars (CPropForall var p) heaps prj
		= findCaseVars vars p heaps prj
	findCaseVars vars (CPropExists var p) heaps prj
		= findCaseVars vars p heaps prj
	findCaseVars vars (CPredicate ptr exprs) heaps prj
		= findCaseVars vars exprs heaps prj



























// ========================================================================================================================
// Copied from Tactics.icl
// Changes:
//		(1) Accepts a rewrite-rule (proposition) instead of a fact.
//		(2) Does not rewrite in assumptions. (in a hypothesis P->Q, rewriting in P is not allowed)
//		(3) Does not get arguments: Redex, TacticMode.
// Remark:
//		It is mandatory to actually carry out the rewrite step, because TYPE CORRECTNESS must
//		still be guaranteed.
// ------------------------------------------------------------------------------------------------------------------------
checkRewriteInHypothesis :: !CPropH !RewriteDirection !HypothesisPtr !Goal !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------
checkRewriteInHypothesis rule direction ptr goal heaps prj
	# (hyp, heaps)									= readPointer ptr heaps
	# hyp_prop										= simplify_hypothesis hyp.hypProp
	# (error, _, conditions, new_prop, heaps)		= rewrite direction AllRedexes rule hyp_prop heaps
	| isError error									= (False, heaps, prj)
	// create goal for type checking
	# test_goal										= {goal & glToProve = foldr (CAnd) goal.glToProve conditions}
	# new_hyp										= {DummyValue & hypProp = new_prop}
	# (new_ptr, heaps)								= newPointer new_hyp heaps
	# test_goal										= {test_goal & glHypotheses = [new_ptr: test_goal.glHypotheses]}
	// type check
	# (error, _, _, heaps, prj)						= wellTyped test_goal heaps prj
	| isError error									= (False, heaps, prj)
	// check if conditions are all closed
	# (ok, heaps)									= are_closed conditions goal heaps
	| not ok										= (False, heaps, prj)
	= (True, heaps, prj)
	where
		simplify_hypothesis :: !CPropH -> CPropH
		simplify_hypothesis (CImplies p q)
			= simplify_hypothesis q
		simplify_hypothesis (CExprForall var p)
			= CExprForall var (simplify_hypothesis p)
		simplify_hypothesis (CExprExists var p)
			= CExprExists var (simplify_hypothesis p)
		simplify_hypothesis (CPropForall var p)
			= CPropForall var (simplify_hypothesis p)
		simplify_hypothesis (CPropExists var p)
			= CPropExists var (simplify_hypothesis p)
		simplify_hypothesis p
			= p
		
		are_closed :: ![CPropH] !Goal !*CHeaps -> (!Bool, !*CHeaps)
		are_closed [] goal heaps
			= (True, heaps)
		are_closed [prop:props] goal heaps
			# (info, heaps)							= GetPtrInfo prop heaps
			# free_e								= info.freeExprVars
			# bound_e								= goal.glExprVars
			| not (are_members free_e bound_e)		= (False, heaps)
			# free_p								= info.freePropVars
			# bound_p								= goal.glPropVars
			| not (are_members free_p bound_p)		= (False, heaps)
			= are_closed props goal heaps
		
		are_members [ptr:ptrs] all
			| isMember ptr all						= are_members ptrs all
			= False
		are_members [] all
			= True
































// ------------------------------------------------------------------------------------------------------------------------
:: Connective =
// ------------------------------------------------------------------------------------------------------------------------
	  ConnectiveAnd				!LeftOrRight
	| ConnectiveExprExists		!CExprVarPtr
	| ConnectiveExprForall		!CExprVarPtr
	| ConnectiveIff				!LeftOrRight
	| ConnectiveImplies			!LeftOrRight
	| ConnectiveNot
	| ConnectiveOr				!LeftOrRight
	| ConnectivePropExists		!CPropVarPtr
	| ConnectivePropForall		!CPropVarPtr

// ------------------------------------------------------------------------------------------------------------------------
:: LeftOrRight =
// ------------------------------------------------------------------------------------------------------------------------
	  LeftArgument
	| RightArgument

// ========================================================================================================================
// True when an 'Extensionality' is applicable (argument: previous connectives encountered)
// ------------------------------------------------------------------------------------------------------------------------
extensionalityConnectives :: ![Connective] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
extensionalityConnectives [ConnectiveExprForall _: connectives]		= extensionalityConnectives connectives
extensionalityConnectives [ConnectivePropForall _: connectives]		= extensionalityConnectives connectives
extensionalityConnectives [ConnectiveImplies RightArgument: connectives]
																	= extensionalityConnectives connectives
extensionalityConnectives [_: _]									= False
extensionalityConnectives []										= True

// ========================================================================================================================
// True when an 'Induction' is applicable (argument: previous connectives encountered)
// ------------------------------------------------------------------------------------------------------------------------
inductionConnectives :: ![Connective] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
inductionConnectives [ConnectiveExprForall _: connectives]			= inductionConnectives connectives
inductionConnectives [ConnectivePropForall _: connectives]			= inductionConnectives connectives
inductionConnectives [_: _]											= False
inductionConnectives []												= True

// ========================================================================================================================
// True when a 'Reflexive' is applicable (argument: previous connectives encountered)
// ------------------------------------------------------------------------------------------------------------------------
reflexiveConnectives :: ![Connective] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
reflexiveConnectives connectives
	= trivialConnectives connectives

// ========================================================================================================================
// True when a 'SplitCase' is applicable (argument: previous connectives encountered)
// ------------------------------------------------------------------------------------------------------------------------
splitCaseConnectives :: ![Connective] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
splitCaseConnectives [ConnectiveNot: connectives]					= splitCaseConnectives connectives
splitCaseConnectives [ConnectiveAnd _: connectives]					= splitCaseConnectives connectives
splitCaseConnectives [ConnectiveOr _: connectives]					= splitCaseConnectives connectives
splitCaseConnectives [ConnectiveImplies _: connectives]				= splitCaseConnectives connectives
splitCaseConnectives [ConnectiveIff _: connectives]					= splitCaseConnectives connectives
splitCaseConnectives [_:_]											= False
splitCaseConnectives []												= True

// ========================================================================================================================
// True when a 'Trivial' is applicable (argument: previous connectives encountered)
// ------------------------------------------------------------------------------------------------------------------------
trivialConnectives :: ![Connective] -> Bool
// ------------------------------------------------------------------------------------------------------------------------
trivialConnectives [ConnectiveExprExists _: connectives]			= trivialConnectives connectives
trivialConnectives [ConnectiveExprForall _: connectives]			= trivialConnectives connectives
trivialConnectives [ConnectivePropExists _: connectives]			= trivialConnectives connectives
trivialConnectives [ConnectivePropForall _: connectives]			= trivialConnectives connectives
trivialConnectives [ConnectiveImplies RightArgument: connectives]	= trivialConnectives connectives
trivialConnectives [_: _]											= False
trivialConnectives []												= True

// ------------------------------------------------------------------------------------------------------------------------
:: ScoreInfo =
// ------------------------------------------------------------------------------------------------------------------------
	{ caseVariables				:: ![CExprVarPtr]
	, contextGoal				:: !Goal			// backup of original goal
	, definednessContradiction	:: !Bool
	, definednessInfo			:: !DefinednessInfo
	, equalityType				:: !CTypeH			// inferred type for *LAST* e1=e2
	, hypothesisProps			:: ![CPropH]
	, inductedVariables			:: ![CExprVarPtr]	// variables introduced by previous induction steps
	, newHypothesisNum			:: !Int
	, newInductionHypothesisNum	:: !Int
	, nrInductionHypotheses		:: !Int
	, opaqueFunctions			:: ![HeapPtr]
	, passedConnectives			:: ![Connective]
	, rewrittenLR				:: ![HypothesisPtr]	// hypotheses previously used for Rewrite ->
	, rewrittenRL				:: ![HypothesisPtr]	// hypotheses previously used for Rewrite <-
	, showThreshold				:: !Int
	, varTypes					:: ![CTypeH]		// types of quantified variables (in same order as quantors)
	}

// ------------------------------------------------------------------------------------------------------------------------   
findHints2 :: !TheoremPtr !Goal !(!Bool, !DefinednessInfo) !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findHints2 ptr goal (contradiction, definedness_info) pstate
	// threshold
	# (threshold, pstate)			= pstate!ls.stOptions.optHintsViewThreshold
	// typing
	# (_, sub, info, pstate)		= acc3HeapsProject (wellTyped goal) pstate
	# (eq_type, pstate)				= case isNilPtr info.tiEqualType of
										True	-> (DummyValue, pstate)
										False	-> accHeaps (UnsafeSubst sub (CTypeVar info.tiEqualType)) pstate
	# (var_types, pstate)			= accHeaps (get_var_types goal.glToProve sub) pstate
	// propositions of hypotheses
	# (hyps, pstate)				= accHeaps (readPointers goal.glHypotheses) pstate
	# hyp_props						= [hyp.hypProp \\ hyp <- hyps]
	// case-variables
	# (case_vars, pstate)			= accHeapsProject (find_all_case_vars [] [goal.glToProve:hyp_props]) pstate
	// INFO
	# info							=	{ caseVariables					= case_vars
										, contextGoal					= goal
										, definednessContradiction		= contradiction
										, definednessInfo				= definedness_info
										, equalityType					= eq_type
										, hypothesisProps				= hyp_props
										, inductedVariables				= goal.glInductionVars
										, newHypothesisNum				= goal.glNewHypNum
										, newInductionHypothesisNum		= goal.glNewIHNum
										, nrInductionHypotheses			= goal.glNrIHs
										, opaqueFunctions				= goal.glOpaque
										, passedConnectives				= []
										, rewrittenLR					= goal.glRewrittenLR
										, rewrittenRL					= goal.glRewrittenRL
										, showThreshold					= threshold
										, varTypes						= var_types
										}
	// get hints
	# pstate						= appProject (mark_opaque True goal.glOpaque) pstate
	# hints							= []
	# hints							= addDefinedness info hints
	# (hints, pstate)				= addIntCompare goal hints pstate
	# (hints, pstate)				= goalHints goal.glToProve info hints pstate
	# (hints, pstate)				= allHypHints goal hyp_props goal.glHypotheses hyp_props info hints pstate
	# (hint_theorems, pstate)		= pstate!ls.stHintTheorems
	# (hints, pstate)				= findHintTheorems hint_theorems goal.glHypotheses hyp_props goal.glToProve hints pstate
	# hints							= removeDup (renum_split_cases 1 hints)
	# hints							= filter (\hint -> hint.hintValue >= threshold) hints
	# pstate						= appProject (mark_opaque False goal.glOpaque) pstate
	= (hints, pstate)
	where
		find_all_case_vars :: ![CExprVarPtr] ![CPropH] !*CHeaps !*CProject -> (![CExprVarPtr], !*CHeaps, !*CProject)
		find_all_case_vars vars [p:ps] heaps prj
			# (vars, heaps, prj)	= findCaseVars vars p heaps prj
			= find_all_case_vars vars ps heaps prj
		find_all_case_vars vars [] heaps prj
			= (vars, heaps, prj)
	
		get_var_types :: !CPropH !Substitution !*CHeaps -> (![CTypeH], !*CHeaps)
		get_var_types (CExprForall ptr p) sub heaps
			# (var, heaps)			= readPointer ptr heaps
			# type					= get_type var.evarInfo
			# (type, heaps)			= UnsafeSubst sub type heaps
			# (types, heaps)		= get_var_types p sub heaps
			= ([type:types], heaps) 
			where
				get_type (EVar_Type type)
					= type
				get_type other
					= DummyValue
		get_var_types (CPropForall ptr p) sub heaps
			= get_var_types p sub heaps
		get_var_types _ _ heaps
			= ([], heaps)
		
		mark_opaque :: !Bool ![HeapPtr] !*CProject -> *CProject
		mark_opaque on_off [ptr:ptrs] prj
			# (_, fundef, prj)						= getFunDef ptr prj
			# fundef								= {fundef & fdOpaque = on_off}
			# (_, prj)								= putFunDef ptr fundef prj
			= mark_opaque on_off ptrs prj
		mark_opaque _ [] prj
			= prj
		
		renum_split_cases :: !Int ![Hint] -> [Hint]
		renum_split_cases n [hint=:{hintTactic = TacticSplitCase num mode}:hints]
			# hint									= {hint & hintTactic = TacticSplitCase n mode}
			= [hint: renum_split_cases (n+1) hints]
		renum_split_cases n [hint:hints]
			= [hint: renum_split_cases n hints]
		renum_split_cases _ []
			= []










// ------------------------------------------------------------------------------------------------------------------------   
newHint score tactic		:== {hintValue = score, hintTactic = tactic, hintText = ""}
// ------------------------------------------------------------------------------------------------------------------------   
hintAbsurd ptr1 ptr2		:== newHint 100		(TacticAbsurd ptr1 ptr2)
hintAbsurdEquality ptr		:== newHint 100		(TacticAbsurdEqualityH ptr)
hintApply score fact		:== newHint score	(TacticApply fact)
hintApplyH score fact ptr	:== newHint score	(TacticApplyH fact ptr Implicit)
hintCase depth num			:== newHint 80		(TacticCase depth num)
hintCaseH ptr				:== newHint 90		(TacticCaseH Deep ptr Implicit)
hintCompareH ptr			:== newHint 60		(TacticCompareH ptr Implicit)
hintContradiction			:== newHint 80		(TacticContradiction Implicit)
hintContradictionH score ptr:== newHint score	(TacticContradictionH ptr)
hintDefinedness				:== newHint 100		(TacticDefinedness)
hintExact ptr				:== newHint 100		(TacticExact (HypothesisFact ptr []))
hintExFalso ptr				:== newHint 100		(TacticExFalso ptr)
hintExtensionality score	:== newHint score	(TacticExtensionality "ext")
hintInduction score ptr		:== newHint score	(TacticInduction ptr Implicit)
hintInjective score			:== newHint score	(TacticInjective)
hintInjectiveH score ptr	:== newHint score	(TacticInjectiveH ptr Implicit)
hintIntArith score			:== newHint score	(TacticIntArith AllSubExprs)
hintIntArithH ptr			:== newHint 90		(TacticIntArithH AllSubExprs ptr Implicit)
hintIntCompare				:== newHint 100		(TacticIntCompare)
hintIntros score names		:== newHint score	(TacticIntroduce names)
hintReduce score			:== newHint score	(TacticReduce Defensive ReduceToNF AllSubExprs [])
hintReduceH ptr				:== newHint 90		(TacticReduceH Defensive ReduceToNF AllSubExprs ptr [] Implicit)
hintRefineUndefinedness s	:== newHint s		(TacticRefineUndefinedness)
hintRefineUndefinednessH p	:== newHint 90		(TacticRefineUndefinednessH p Implicit)
hintReflexive				:== newHint 100		(TacticReflexive)
hintRewrite score dir fact	:== newHint score	(TacticRewrite dir AllRedexes fact)
hintRewriteH s dir fact ptr	:== newHint s		(TacticRewriteH dir AllRedexes fact ptr Implicit)
hintRewriteHH ptr1 ptr2		:== newHint 95		(TacticRewriteH LeftToRight AllRedexes (HypothesisFact ptr1 []) ptr2 Implicit)
hintSplit					:== newHint 80		(TacticSplit Deep)
hintSplitH ptr				:== newHint 90		(TacticSplitH ptr Deep Implicit)
hintSplitCase score			:== newHint score	(TacticSplitCase 1 Implicit)
hintSplitIff				:== newHint 70		(TacticSplitIff)
hintSplitIffH ptr			:== newHint 60		(TacticSplitIffH ptr Implicit)
hintTrivial					:== newHint 100		(TacticTrivial)
hintWitness ptr				:== newHint 90		(TacticWitnessH ptr Implicit)
// ------------------------------------------------------------------------------------------------------------------------   











// ------------------------------------------------------------------------------------------------------------------------   
addDefinedness :: !ScoreInfo ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
addDefinedness info hints
	| info.showThreshold > 100					= hints
	| info.definednessContradiction				= [hintDefinedness:hints]
	# overlap									= have_overlap info.definednessInfo.definedExpressions info.definednessInfo.undefinedExpressions
	| overlap									= [hintDefinedness:hints]
	= hints
	where
		have_overlap :: ![CExprH] ![CExprH] -> Bool
		have_overlap [expr:exprs] more_exprs
			| isMember expr more_exprs			= True
			= have_overlap exprs more_exprs
		have_overlap [] _
			= False

// ------------------------------------------------------------------------------------------------------------------------   
addIntCompare :: !Goal ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
addIntCompare goal hints pstate
	# (contradiction, pstate)		= accHeapsProject (CompareInts goal) pstate
	| not contradiction				= (hints, pstate)
	= ([hintIntCompare:hints], pstate)





















// ------------------------------------------------------------------------------------------------------------------------   
:: ExprForm =
// ------------------------------------------------------------------------------------------------------------------------   
	  EF_Defined
	| EF_RootNormalForm
	| EF_Undefined
	| EF_Unknown

// ------------------------------------------------------------------------------------------------------------------------   
instance toInt ExprForm
// ------------------------------------------------------------------------------------------------------------------------   
where
	toInt EF_Defined			= 3
	toInt EF_RootNormalForm		= 4
	toInt EF_Undefined			= 1
	toInt EF_Unknown			= 2

// ------------------------------------------------------------------------------------------------------------------------   
instance < ExprForm
// ------------------------------------------------------------------------------------------------------------------------   
where
	(<) form1 form2
		= toInt form1 < toInt form2

// ========================================================================================================================
// Uses the following fields of DefinednessInfo actively:
// (1) definedVariables.
// (2) definedExpressions.
// Does *not* use the field 'undefinedExpressions' or 'undefinedVariables', because these fields are
// not used by the reduction mechanism either.
// ------------------------------------------------------------------------------------------------------------------------   
class getExprForm a :: !DefinednessInfo !a !*CHeaps !*CProject -> (!ExprForm, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance getExprForm (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	getExprForm definedness=:{definedVariables, undefinedVariables} (CExprVar ptr) heaps prj
		| isMember ptr definedVariables			= (EF_Defined, heaps, prj)
		= (EF_Unknown, heaps, prj)
	getExprForm definedness (CShared ptr) heaps prj
		# (shared, heaps)						= readPointer ptr heaps
		= getExprForm definedness shared.shExpr heaps prj
	getExprForm definedness whole=:(expr @# exprs) heaps prj
		= case isMember whole definedness.definedExpressions of
			True								-> (EF_Defined, heaps, prj)
			False								-> (EF_Unknown, heaps, prj)
	getExprForm definedness whole=:(ptr @@# exprs) heaps prj
		| ptrKind ptr == CDataCons
			# (_, cons, prj)					= getDataConsDef ptr prj
			| length exprs <> cons.dcdArity		= case isMember whole definedness.definedExpressions of
													True	-> (EF_Defined, heaps, prj)
													False	-> (EF_Unknown, heaps, prj)
			# defining_args						= selectStrictArgs cons.dcdSymbolType.sytArguments exprs
			# (form, heaps, prj)				= getExprForm definedness defining_args heaps prj
			= case form of
				EF_Defined						-> (EF_Defined, heaps, prj)
				EF_RootNormalForm				-> (EF_RootNormalForm, heaps, prj)
				EF_Undefined					-> (EF_Undefined, heaps, prj)
				EF_Unknown						-> case isMember whole definedness.definedExpressions of
													True	-> (EF_Defined, heaps, prj)
													False	-> (EF_Unknown, heaps, prj)
				_								-> (form, heaps, prj)
		| ptrKind ptr == CFun
			# (_, fun, prj)						= getFunDef ptr prj
			| length exprs <> fun.fdArity 		= case isMember whole definedness.definedExpressions of
													True	-> (EF_Defined, heaps, prj)
													False	-> (EF_Unknown, heaps, prj)
			# (known, defining_args_selector)	= getDefiningArgs fun.fdDefinedness
			| not known							= case isMember whole definedness.definedExpressions of
													True	-> (EF_Defined, heaps, prj)
													False	-> (EF_Unknown, heaps, prj)
			# defining_args						= selectDefiningArgs defining_args_selector exprs
			# (forms, heaps, prj)				= getExprForm definedness defining_args heaps prj
			# form								= min EF_Defined forms
			= case form of
				EF_Defined						-> (EF_Defined, heaps, prj)
				EF_RootNormalForm				-> (EF_Defined, heaps, prj)
				EF_Unknown						-> case isMember whole definedness.definedExpressions of
													True	-> (EF_Defined, heaps, prj)
													False	-> (EF_Unknown, heaps, prj)
				EF_Undefined					-> (EF_Undefined, heaps, prj)
		= undef
	getExprForm definedness whole=:(CLet _ _ _) heaps prj
		= case isMember whole definedness.definedExpressions of
			True								-> (EF_Defined, heaps, prj)
			False								-> (EF_Unknown, heaps, prj)
	getExprForm definedness whole=:(CCase _ _ _) heaps prj
		= case isMember whole definedness.definedExpressions of
			True								-> (EF_Defined, heaps, prj)
			False								-> (EF_Unknown, heaps, prj)
	getExprForm definedness (CBasicValue _) heaps prj
		= (EF_RootNormalForm, heaps, prj)
	getExprForm definedness (CCode _ _) heaps prj
		= (EF_Unknown, heaps, prj)
	getExprForm definedness CBottom heaps prj
		= (EF_Undefined, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance getExprForm [a] | getExprForm a
// ------------------------------------------------------------------------------------------------------------------------   
where
	getExprForm definedness xs heaps prj
		# (infos, heaps, prj)					= uumap (getExprForm definedness) xs heaps prj
		= (minList [EF_RootNormalForm:infos], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
selectDefiningArgs :: ![Bool] ![CExprH] -> [CExprH]
// ------------------------------------------------------------------------------------------------------------------------   
selectDefiningArgs [True:bs] [e:es]
	= [e: selectDefiningArgs bs es]
selectDefiningArgs [False:bs] [e:es]
	= selectDefiningArgs bs es
selectDefiningArgs _ _
	= []

// ------------------------------------------------------------------------------------------------------------------------   
selectStrictArgs :: ![CTypeH] ![CExprH] -> [CExprH]
// ------------------------------------------------------------------------------------------------------------------------   
selectStrictArgs [CStrict type:types] [expr:exprs]
	= [expr: selectStrictArgs types exprs]
selectStrictArgs [_:types] [expr:exprs]
	= selectStrictArgs types exprs
selectStrictArgs _ _
	= []

// ========================================================================================================================
// The first argument, indicating whether the function can be expanded, should always be
// initialized with TRUE. (this argument is needed to search for _|_ in later arguments of the function)
// NB: Assumes that the arity has already been checked.
// ------------------------------------------------------------------------------------------------------------------------   
functionExpandable :: !Bool ![Int] ![Int] !Int ![CTypeH] ![CExprH] !DefinednessInfo !*CHeaps !*CProject -> (!Bool, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
functionExpandable sofar case_indexes strict_indexes index [CStrict type:types] [expr:exprs] definedness heaps prj
	# (form, heaps, prj)						= getExprForm definedness expr heaps prj
	# go_on_with_defined						= not (problematic_case expr)
	# go_on_with_unknown						= (not (isMember index case_indexes)) &&
												  (isMember index strict_indexes)
	= case form of
		EF_Defined								-> functionExpandable (sofar && go_on_with_defined) case_indexes strict_indexes (index+1) types exprs definedness heaps prj
		EF_RootNormalForm						-> functionExpandable sofar case_indexes strict_indexes (index+1) types exprs definedness heaps prj
		EF_Undefined							-> (True, heaps, prj)
		EF_Unknown								-> functionExpandable (sofar && go_on_with_unknown) case_indexes strict_indexes (index+1) types exprs definedness heaps prj
	where
		problematic_case :: !CExprH -> Bool
		problematic_case (ptr @@# _)
			= isMember index case_indexes && ptrKind ptr <> CDataCons
		problematic_case other
			= isMember index case_indexes
functionExpandable sofar case_indexes strict_indexes index [type:types] [expr:exprs] definedness heaps prj
	= functionExpandable sofar case_indexes strict_indexes (index+1) types exprs definedness heaps prj
functionExpandable sofar _ _ _ _ _ _ heaps prj
	= (sofar, heaps, prj)


















// ------------------------------------------------------------------------------------------------------------------------   
class goalHints a :: !a !ScoreInfo ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance goalHints [CExpr HeapPtr]
// ------------------------------------------------------------------------------------------------------------------------   
where
	goalHints [CExprVar ptr:exprs] info hints pstate
		= goalHints exprs info hints pstate
	goalHints [CShared _: exprs] info hints pstate
		= goalHints exprs info hints pstate
	goalHints [expr1 @# exprs1: exprs2] info hints pstate
		# hints									= case reduce_anyway expr1 of
													True	-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													False	-> hints
		= goalHints [expr1:exprs1 ++ exprs2] info hints pstate
		where
			reduce_anyway :: !CExprH -> Bool
			reduce_anyway (_ @@# _) 			= True
			reduce_anyway (_ @# _)				= True
			reduce_anyway CBottom				= True
			reduce_anyway _						= False
	goalHints [ptr @@# args: exprs] info hints pstate
		| ptrKind ptr <> CFun					= goalHints (args ++ exprs) info hints pstate
		# (error, fun, pstate)					= accErrorProject (getFunDef ptr) pstate
		| isError error							= goalHints (args ++ exprs) info hints pstate
		| fun.fdOpaque							= goalHints (args ++ exprs) info hints pstate
		# arity									= getRealArity Defensive fun
		| arity > length args					= goalHints (args ++ exprs) info hints pstate
		# (reduce, pstate)						= accHeapsProject (functionExpandable True fun.fdCaseVariables fun.fdStrictVariables 0 fun.fdSymbolType.sytArguments args info.definednessInfo) pstate
		# hints									= case reduce of
													True	-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													False	-> hints
		= goalHints (args ++ exprs) info hints pstate
	goalHints [CLet False lets expr: exprs] info hints pstate
		# hints									= [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
		= goalHints ((map snd lets) ++ [expr:exprs]) info hints pstate
	goalHints [CLet True lets expr: exprs] info hints pstate
		# (_, let_exprs)						= unzip lets
		# (form, pstate)						= accHeapsProject (getExprForm info.definednessInfo let_exprs) pstate
		# hints									= case form of
													EF_RootNormalForm	-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													EF_Undefined		-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													_					-> hints
		= goalHints (let_exprs ++ [expr:exprs]) info hints pstate
	goalHints [CCase expr patterns def: exprs] info hints pstate
		# hints									= case splitCaseConnectives info.passedConnectives of
													True	-> [hintSplitCase (if (isEmpty info.passedConnectives) 80 70): hints]
													False	-> hints
		# (form, pstate)						= accHeapsProject (getExprForm info.definednessInfo expr) pstate
		# hints									= case form of
													EF_RootNormalForm	-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													EF_Undefined		-> [hintReduce (if (isEmpty info.passedConnectives) 80 70):hints]
													_					-> hints
		= goalHints [expr: concat_def (get_exprs patterns) def ++ exprs] info hints pstate
		where
			get_exprs :: !CCasePatternsH -> [CExprH]
			get_exprs (CAlgPatterns _ patterns)
				= [pattern.atpResult \\ pattern <- patterns]
			get_exprs (CBasicPatterns _ patterns)
				= [pattern.bapResult \\ pattern <- patterns]
			
			concat_def :: ![CExprH] !(Maybe CExprH) -> [CExprH]
			concat_def exprs Nothing
				= exprs
			concat_def exprs (Just expr)
				= exprs ++ [expr]
	goalHints [CBasicValue (CBasicArray list): exprs] info hints pstate
		= goalHints (list ++ exprs) info hints pstate
	goalHints [CBasicValue _: exprs] info hints pstate
		= goalHints exprs info hints pstate
	goalHints [CCode _ _: exprs] info hints pstate
		= goalHints exprs info hints pstate
	goalHints [CBottom: exprs] info hints pstate
		= goalHints exprs info hints pstate
	goalHints [] info hints pstate
		= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
instance goalHints (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	goalHints CTrue info hints pstate
		# hints									= case trivialConnectives info.passedConnectives of
													True	-> [hintTrivial: hints]
													False	-> hints
		= (hints, pstate)
	goalHints CFalse info hints pstate
		= (hints, pstate)
	goalHints (CPropVar ptr) info hints pstate
		= (hints, pstate)
	goalHints (CNot p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectiveNot: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		# hints									= case isEmpty old_connectives of
													True	-> [hintContradiction: hints]
													False	-> hints
		= goalHints p info hints pstate
	goalHints (CAnd p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveAnd LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveAnd RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# hints									= case isEmpty old_connectives of
													True	-> [hintSplit: hints]
													False	-> hints
		# (hints, pstate)						= goalHints p info_left hints pstate
		= goalHints q info_right hints pstate
	goalHints (COr p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveOr LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveOr RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# hints									= case isEmpty old_connectives of
													True	-> make_hints (1 + count_ors p + count_ors q) hints
													False	-> hints
		# (hints, pstate)						= goalHints p info_left hints pstate
		= goalHints q info_right hints pstate
		where
			make_hints :: !Int ![Hint] -> [Hint]
			make_hints 1 hints					= [hintCase Shallow 1, hintCase Shallow 2: hints]
			make_hints n hints					= [hintCase Deep num \\ num <- [1..(n+1)]] ++ hints
			
			count_ors :: !CPropH -> Int
			count_ors (COr p q)					= 1 + count_ors p + count_ors q
			count_ors _							= 0
	goalHints (CImplies p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveImplies LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveImplies RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		| not (isEmpty old_connectives)
			# (hints, pstate)					= goalHints p info_left hints pstate
			# (hints, pstate)					= goalHints q info_right hints pstate
			= (hints, pstate)
		# empty_block							= {allNames = [], inductVariables = []}
		# (blocks, pstate)						= buildNameBlocks empty_block False (CImplies p q) (info.newHypothesisNum, info.newInductionHypothesisNum) info.nrInductionHypotheses info.caseVariables pstate
		# hints									= makeIntroduceHints 80 [] blocks hints
		# (hints, pstate)						= goalHints p info_left hints pstate
		= goalHints q info_right hints pstate
	goalHints (CIff p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveAnd LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveAnd RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# (equal, pstate)						= accHeaps (AlphaEqual p q) pstate
		# hints									= case reflexiveConnectives old_connectives && equal of
													True	-> [hintReflexive: hints]
													False	-> hints
		# hints									= case isEmpty old_connectives of
													True	-> [hintSplitIff: hints]
													False	-> hints
		# (hints, pstate)						= goalHints p info_left hints pstate
		= goalHints q info_right hints pstate
	goalHints (CExprForall ptr p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectiveExprForall ptr: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		| not (isEmpty old_connectives)			= goalHints p info hints pstate
		# empty_block							= {allNames = [], inductVariables = []}
		# (blocks, pstate)						= buildNameBlocks empty_block True (CExprForall ptr p) (info.newHypothesisNum, info.newInductionHypothesisNum) info.nrInductionHypotheses info.caseVariables pstate
		# hints									= makeIntroduceHints 80 [] blocks hints
		# hints									= makeInductionHints (hd blocks) info.inductedVariables hints
		= goalHints p info hints pstate
	goalHints (CExprExists ptr p) info hints pstate
		= (hints, pstate)
	goalHints (CPropForall ptr p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectivePropForall ptr: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		| not (isEmpty old_connectives)			= goalHints p info hints pstate
		# empty_block							= {allNames = [], inductVariables = []}
		# (blocks, pstate)						= buildNameBlocks empty_block True (CPropForall ptr p) (info.newHypothesisNum, info.newInductionHypothesisNum) info.nrInductionHypotheses info.caseVariables pstate
		# hints									= makeIntroduceHints 80 [] blocks hints
		# hints									= makeInductionHints (hd blocks) info.inductedVariables hints
		= goalHints p info hints pstate
	goalHints (CPropExists ptr p) info hints pstate
		= (hints, pstate)
	goalHints (CEqual e1 e2) info hints pstate
		// Extensionality
		# hints									= case is_arrow_type info.equalityType && extensionalityConnectives info.passedConnectives of
													True	-> [hintExtensionality 85: hints]
													False	-> hints
		// Injective
		# (do_inject, inject_score, pstate)		= same_head e1 e2 pstate
		# hints									= case do_inject && isEmpty info.passedConnectives of
													True	-> [hintInjective inject_score:hints]
													False	-> hints
		// Reflexive
		# (equal, pstate)						= accHeaps (AlphaEqual e1 e2) pstate
		# hints									= case reflexiveConnectives info.passedConnectives && equal of
													True	-> [hintReflexive: hints]
													False	-> hints
		// IntArith
		# (_, (changed1, _), pstate)			= accErrorHeapsProject (ArithInt e1) pstate
		# (_, (changed2, _), pstate)			= accErrorHeapsProject (ArithInt e2) pstate
		# hints									= case changed1 || changed2 of
													True	-> [hintIntArith (if (isEmpty info.passedConnectives) 80 70): hints]
													False	-> hints
		// RefineUndefinedness
		# (ok, pstate)							= check_undefinedness e1 e2 pstate
		# hints									= case ok of
													True	-> [hintRefineUndefinedness (if (isEmpty info.passedConnectives) 80 70): hints]
													False	-> hints
		= goalHints [e1,e2] info hints pstate
		where
			is_arrow_type :: !CTypeH -> Bool
			is_arrow_type (_ ==> _)				= True
			is_arrow_type _						= False
			
			same_head :: !CExprH !CExprH !*PState -> (!Bool, !Int, !*PState)
			same_head (ptr1 @@# args1) (ptr2 @@# args2) pstate
				| ptr1 <> ptr2					= (False, 0, pstate)
				= case ptrKind ptr1 of
					CDataCons					-> (True, 80, pstate)
					CFun						-> (False, 0, pstate)
			same_head _ _ pstate
				= (False, 0, pstate)
	goalHints _ _ hints pstate
		= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
:: NameBlock =
// ------------------------------------------------------------------------------------------------------------------------   
	{ allNames					:: ![String]
	, inductVariables			:: ![CExprVarPtr]
	}

// ========================================================================================================================
// #1 - NameBlock     - The current block.
// #2 - Bool          - The mode: True = scanning foralls; False = scanning arrows.
// #3 - Prop          - The proposition. (duhhh)
// #4 - (Int,Int)     - New hypothesis number / induction hypothesis number.
// #5 - Int           - Nr of Induction Hypotheses.
// #6 - [CExprVarPtr] - List of case variables.
// #7 - *PState       - The program state. (duhhh)
// ------------------------------------------------------------------------------------------------------------------------   
buildNameBlocks :: !NameBlock !Bool !CPropH !(!Int, !Int) !Int ![CExprVarPtr] !*PState -> (![NameBlock], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildNameBlocks current_block True (CImplies p q) (new_num, new_ih_num) nr_ihs case_vars pstate
	# new_name									= case (nr_ihs > 0) of
													True	-> case new_ih_num of
																1	-> "IH"
																_	-> "IH" +++ toString new_ih_num
													False	-> "H" +++ toString new_num
	# (new_num, new_ih_num)						= case (nr_ihs > 0) of
													True	-> (new_num, new_ih_num+1)
													False	-> (new_num+1, new_ih_num)
	# nr_ihs									= case (nr_ihs > 0) of
													True	-> nr_ihs - 1
													False	-> nr_ihs
	# new_block									= {allNames = [new_name], inductVariables = []}
	# (new_blocks, pstate)						= buildNameBlocks new_block False q (new_num,new_ih_num) nr_ihs case_vars pstate
	= ([current_block: new_blocks], pstate)
buildNameBlocks current_block=:{allNames} False (CImplies p q) (new_num, new_ih_num) nr_ihs case_vars pstate
	# new_name									= case (nr_ihs > 0) of
													True	-> case new_ih_num of
																1	-> "IH"
																_	-> "IH" +++ toString new_ih_num
													False	-> "H" +++ toString new_num
	# (new_num, new_ih_num)						= case (nr_ihs > 0) of
													True	-> (new_num, new_ih_num+1)
													False	-> (new_num+1, new_ih_num)
	# nr_ihs									= case (nr_ihs > 0) of
													True	-> nr_ihs - 1
													False	-> nr_ihs
	# current_block								= {current_block & allNames = allNames ++ [new_name]}
	= buildNameBlocks current_block False q (new_num,new_ih_num) nr_ihs case_vars pstate
buildNameBlocks current_block=:{allNames,inductVariables} True (CExprForall ptr p) new_nums nr_ihs case_vars pstate
	# (var, pstate)								= accHeaps (readPointer ptr) pstate
	# current_block								= {current_block & allNames = allNames ++ [var.evarName]}
	# current_block								= case isMember ptr case_vars of
													True	-> {current_block & inductVariables = inductVariables ++ [ptr]}
													False	-> current_block
	= buildNameBlocks current_block True p new_nums nr_ihs case_vars pstate
buildNameBlocks current_block=:{allNames,inductVariables} False (CExprForall ptr p) new_nums nr_ihs case_vars pstate
	# (var, pstate)								= accHeaps (readPointer ptr) pstate
	# new_block									= case isMember ptr case_vars of
													True	-> {allNames = [var.evarName], inductVariables = [ptr]}
													False	-> {allNames = [var.evarName], inductVariables = []}
	# (new_blocks, pstate)						= buildNameBlocks new_block True p new_nums nr_ihs case_vars pstate
	= ([current_block: new_blocks], pstate)
buildNameBlocks current_block=:{allNames} True (CPropForall ptr p) new_nums nr_ihs case_vars pstate
	# (var, pstate)								= accHeaps (readPointer ptr) pstate
	# current_block								= {current_block & allNames = allNames ++ [var.pvarName]}
	= buildNameBlocks current_block True p new_nums nr_ihs case_vars pstate
buildNameBlocks current_block=:{allNames} False (CPropForall ptr p) new_nums nr_ihs case_vars pstate
	# (var, pstate)								= accHeaps (readPointer ptr) pstate
	# new_block									= {allNames = [var.pvarName], inductVariables = []}
	# (new_blocks, pstate)						= buildNameBlocks new_block True p new_nums nr_ihs case_vars pstate
	= ([current_block: new_blocks], pstate)
buildNameBlocks current_block _ _ _ _ _ pstate
	= ([current_block], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
makeInductionHints :: !NameBlock ![CExprVarPtr] ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
makeInductionHints block inducted_vars hints
	# induct_hints								= [hintInduction (if (isMember ptr inducted_vars) 50 80) ptr \\ ptr <- block.inductVariables]
	= induct_hints ++ hints

// ------------------------------------------------------------------------------------------------------------------------   
makeIntroduceHints :: !Int ![String] ![NameBlock] ![Hint] -> [Hint]
// ------------------------------------------------------------------------------------------------------------------------   
makeIntroduceHints score names [block:blocks] hints
	| isEmpty block.inductVariables				= makeIntroduceHints score (names ++ block.allNames) blocks hints
	| isEmpty names								= makeIntroduceHints (score-1) (names ++ block.allNames) blocks hints
	# intro_hint								= hintIntros score names
	= makeIntroduceHints (score-1) (names ++ block.allNames) blocks [intro_hint:hints]
makeIntroduceHints score names [] hints
	| isEmpty names								= hints
	= [hintIntros score names: hints]


















// ------------------------------------------------------------------------------------------------------------------------   
allHypHints :: !Goal ![CPropH] ![HypothesisPtr] ![CPropH] !ScoreInfo ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
allHypHints goal all_props [ptr:ptrs] [prop:props] info hints pstate
	// Exact
	# (equal, pstate)							= accHeaps (AlphaEqual prop goal.glToProve) pstate
	# hints										= case equal of
													True	-> [hintExact ptr: hints]
													False	-> hints
	// Absurd
	# (mb_ptr, pstate)							= is_any_absurd prop ptrs props pstate
	# hints										= case mb_ptr of
													Just ptr2	-> [hintAbsurd ptr ptr2: hints]
													Nothing		-> hints
	// Rewrite in ...
	# (mb_ptr, pstate)							= accHeaps (is_any_almost_contradiction prop ptrs props) pstate
	# hints										= case mb_ptr of
													Just ptr2	-> [hintRewriteHH ptr ptr2: hints]
													Nothing		-> hints
	// Apply / Rewrite (only in current goal!)
	# apply_score								= 75
	# rewrite_lr_score							= if (isMember ptr info.rewrittenRL) 0 70
	# rewrite_rl_score							= if (isMember ptr info.rewrittenLR) 0 65
	# score										= (apply_score, rewrite_lr_score, rewrite_rl_score)
	# (hints, pstate)							= findApplyRewrite (HypothesisFact ptr []) score [] [] 0 prop Nothing goal.glToProve True hints all_props pstate
	// Recursive hints
	# (hints, pstate)							= hypHints ptr prop info hints pstate
	= allHypHints goal all_props ptrs props info hints pstate
	where
		is_absurd :: !CPropH !CPropH !*PState -> (!Bool, !*PState)
		is_absurd (CNot p) (CNot q) pstate		= is_absurd p q pstate
		is_absurd (CNot p) q pstate				= accHeaps (AlphaEqual p q) pstate
		is_absurd p (CNot q) pstate				= accHeaps (AlphaEqual p q) pstate
		is_absurd _ _ pstate					= (False, pstate)
		
		is_any_absurd :: !CPropH ![HypothesisPtr] ![CPropH] !*PState -> (!Maybe HypothesisPtr, !*PState)
		is_any_absurd p [ptr:ptrs] [q:qs] pstate
			# (absurd, pstate)					= is_absurd p q pstate
			= case absurd of
				True							-> (Just ptr, pstate)
				False							-> is_any_absurd p ptrs qs pstate
		is_any_absurd _ [] [] pstate
			= (Nothing, pstate)
		
		is_any_almost_contradiction :: !CPropH ![HypothesisPtr] ![CPropH] !*CHeaps -> (!Maybe HypothesisPtr, !*CHeaps)
		is_any_almost_contradiction (CEqual e1 e2) [ptr:ptrs] [CEqual e3 e4:props] heaps
			# (e1_equals_e3, heaps)				= AlphaEqual e1 e3 heaps
			| e1_equals_e3 && absurd_equal_expressions e2 e4
												= (Just ptr, heaps)
			= is_any_almost_contradiction (CEqual e1 e2) ptrs props heaps
		is_any_almost_contradiction _ _ _ heaps
			= (Nothing, heaps)
allHypHints _ _ [] [] _ hints pstate
	= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
class hypHints a :: !HypothesisPtr !a !ScoreInfo ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance hypHints [CExpr HeapPtr]
// ------------------------------------------------------------------------------------------------------------------------   
where
	hypHints ptr [CExprVar _:exprs] info hints pstate
		= hypHints ptr exprs info hints pstate
	hypHints ptr [CShared _: exprs] info hints pstate
		= hypHints ptr exprs info hints pstate
	hypHints ptr [expr1 @# exprs1: exprs2] info hints pstate
		# hints									= case reduce_anyway expr1 of
													True	-> [hintReduceH ptr:hints]
													False	-> hints
		= hypHints ptr [expr1:exprs1 ++ exprs2] info hints pstate
		where
			reduce_anyway :: !CExprH -> Bool
			reduce_anyway (_ @@# _) 			= True
			reduce_anyway (_ @# _)				= True
			reduce_anyway CBottom				= True
			reduce_anyway _						= False
	hypHints ptr [sym @@# args: exprs] info hints pstate
		| ptrKind sym <> CFun					= hypHints ptr (args ++ exprs) info hints pstate
		# (error, fun, pstate)					= accErrorProject (getFunDef sym) pstate
		| isError error							= hypHints ptr (args ++ exprs) info hints pstate
		| fun.fdOpaque							= hypHints ptr (args ++ exprs) info hints pstate
		# arity									= getRealArity Defensive fun
		| arity > length args					= hypHints ptr (args ++ exprs) info hints pstate
		# (reduce, pstate)						= accHeapsProject (functionExpandable True fun.fdCaseVariables fun.fdStrictVariables 0 fun.fdSymbolType.sytArguments args info.definednessInfo) pstate
		# hints									= case reduce of
													True	-> [hintReduceH ptr:hints]
													False	-> hints
		= hypHints ptr (args ++ exprs) info hints pstate
	hypHints ptr [CLet False lets expr: exprs] info hints pstate
		# hints									= [hintReduceH ptr: hints]
		= hypHints ptr ((map snd lets) ++ [expr:exprs]) info hints pstate
	hypHints ptr [CLet True lets expr: exprs] info hints pstate
		# (_, let_exprs)						= unzip lets
		# (form, pstate)						= accHeapsProject (getExprForm info.definednessInfo let_exprs) pstate
		# hints									= case form of
													EF_RootNormalForm	-> [hintReduceH ptr: hints]
													EF_Undefined		-> [hintReduceH ptr: hints]
													_					-> hints
		= hypHints ptr (let_exprs ++ [expr:exprs]) info hints pstate
	hypHints ptr [CCase expr patterns def: exprs] info hints pstate
		# (form, pstate)						= accHeapsProject (getExprForm info.definednessInfo expr) pstate
		# hints									= case form of
													EF_RootNormalForm	-> [hintReduceH ptr: hints]
													EF_Undefined		-> [hintReduceH ptr: hints]
													_					-> hints
		= hypHints ptr [expr: concat_def (get_exprs patterns) def ++ exprs] info hints pstate
		where
			get_exprs :: !CCasePatternsH -> [CExprH]
			get_exprs (CAlgPatterns _ patterns)
				= [pattern.atpResult \\ pattern <- patterns]
			get_exprs (CBasicPatterns _ patterns)
				= [pattern.bapResult \\ pattern <- patterns]
			
			concat_def :: ![CExprH] !(Maybe CExprH) -> [CExprH]
			concat_def exprs Nothing
				= exprs
			concat_def exprs (Just expr)
				= exprs ++ [expr]
	hypHints ptr [CBasicValue (CBasicArray list): exprs] info hints pstate
		= hypHints ptr (list ++ exprs) info hints pstate
	hypHints ptr [CBasicValue _: exprs] info hints pstate
		= hypHints ptr exprs info hints pstate
	hypHints ptr [CCode _ _: exprs] info hints pstate
		= hypHints ptr exprs info hints pstate
	hypHints ptr [CBottom: exprs] info hints pstate
		= hypHints ptr exprs info hints pstate
	hypHints ptr [] info hints pstate
		= (hints, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
instance hypHints (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	hypHints ptr CTrue info hints pstate
		= (hints, pstate)
	hypHints ptr CFalse info hints pstate
		# hints									= case isEmpty info.passedConnectives of
													True	-> [hintExFalso ptr: hints]
													False	-> hints
		= (hints, pstate)
	hypHints ptr (CPropVar _) info hints pstate
		= (hints, pstate)
	hypHints ptr (CNot p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectiveNot: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		# (is_trivial, pstate)					= accHeaps (is_trivial p) pstate
		# hints									= case isEmpty old_connectives && not (p == info.contextGoal.glToProve) of
													True	-> [hintContradictionH (if is_trivial 95 50) ptr: hints]
													False	-> hints
		= hypHints ptr p info hints pstate
		where
			is_trivial :: !CPropH !*CHeaps -> (!Bool, !*CHeaps)
			is_trivial CTrue heaps				= (True, heaps)
			is_trivial (CAnd p q) heaps			= combine (&&) (is_trivial p) (is_trivial q) heaps
			is_trivial (COr p q) heaps			= combine (||) (is_trivial p) (is_trivial q) heaps
			is_trivial (CImplies p q) heaps		= is_trivial q heaps
			is_trivial (CEqual e1 e2) heaps		= AlphaEqual e1 e2 heaps
			is_trivial (CExprForall _ p) heaps	= is_trivial p heaps
			is_trivial (CPropForall _ p) heaps	= is_trivial p heaps
			is_trivial _ heaps					= (False, heaps)
			
			combine fun act1 act2 heaps
				# (res1, heaps)					= act1 heaps
				# (res2, heaps)					= act2 heaps
				= (fun res1 res2, heaps)
	hypHints ptr (CAnd p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveAnd LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveAnd RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# hints									= case isEmpty old_connectives of
													True	-> [hintSplitH ptr: hints]
													False	-> hints
		# (hints, pstate)						= hypHints ptr p info_left hints pstate
		= hypHints ptr q info_right hints pstate
	hypHints ptr (COr p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveOr LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveOr RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# hints									= case isEmpty old_connectives of
													True	-> [hintCaseH ptr: hints]
													False	-> hints
		# (hints, pstate)						= hypHints ptr p info_left hints pstate
		= hypHints ptr q info_right hints pstate
	hypHints ptr (CImplies p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveImplies LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveImplies RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# (hints, pstate)						= hypHints ptr p info_left hints pstate
		= hypHints ptr q info_right hints pstate
	hypHints ptr (CIff p q) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives_left					= [ConnectiveAnd LeftArgument: old_connectives]
		# info_left								= {info & passedConnectives = new_connectives_left}
		# new_connectives_right					= [ConnectiveAnd RightArgument: old_connectives]
		# info_right							= {info & passedConnectives = new_connectives_right}
		# hints									= case isEmpty old_connectives of
													True	-> [hintSplitIffH ptr: hints]
													False	-> hints
		# (hints, pstate)						= hypHints ptr p info_left hints pstate
		= hypHints ptr q info_right hints pstate
	hypHints ptr (CExprForall var p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectiveExprForall var: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		= hypHints ptr p info hints pstate
	hypHints ptr (CExprExists var p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectiveExprForall var: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		# hints									= case isEmpty old_connectives of
													True	-> [hintWitness ptr: hints]
													False	-> hints
		= hypHints ptr p info hints pstate
	hypHints ptr (CPropForall var p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectivePropForall var: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		= hypHints ptr p info hints pstate
	hypHints ptr (CPropExists var p) info hints pstate
		# old_connectives						= info.passedConnectives
		# new_connectives						= [ConnectivePropForall var: old_connectives]
		# info									= {info & passedConnectives = new_connectives}
		# hints									= case isEmpty old_connectives of
													True	-> [hintWitness ptr: hints]
													False	-> hints
		= hypHints ptr p info hints pstate
	hypHints ptr (CEqual e1 e2) info hints pstate
		// Absurd Equality
		# hints									= case absurd_equal_expressions e1 e2 && isEmpty info.passedConnectives of
													True	-> [hintAbsurdEquality ptr: hints]
													False	-> hints
		// Injective
		# (do_inject, inject_score, pstate)		= same_head e1 e2 pstate
		# hints									= case do_inject && isEmpty info.passedConnectives of
													True	-> [hintInjectiveH inject_score ptr: hints]
													False	-> hints
		// Compare using
		# (stdInt, pstate)						= pstate!ls.stProject.prjABCFunctions.stdInt
		# hints									= case comparable stdInt.intSmaller e1 e2 && isEmpty info.passedConnectives of
													True	-> [hintCompareH ptr: hints]
													False	-> hints
		// IntArith
		# (_, (changed1, _), pstate)			= accErrorHeapsProject (ArithInt e1) pstate
		# (_, (changed2, _), pstate)			= accErrorHeapsProject (ArithInt e2) pstate
		# hints									= case changed1 || changed2 of
													True	-> [hintIntArithH ptr: hints]
													False	-> hints
		// RefineUndefinedness
		# (ok, pstate)							= check_undefinedness e1 e2 pstate
		# hints									= case ok of
													True	-> [hintRefineUndefinednessH ptr: hints]
													False	-> hints
		= hypHints ptr [e1,e2] info hints pstate
		where			
			comparable :: !HeapPtr !CExprH !CExprH -> Bool
			comparable ptr1 (ptr2 @@# [arg1,arg2]) (CBasicValue (CBasicBoolean False))
				= ptr1 == ptr2
			comparable _ _ _
				= False
			
			same_head :: !CExprH !CExprH !*PState -> (!Bool, !Int, !*PState)
			same_head (ptr1 @@# args1) (ptr2 @@# args2) pstate
				| ptr1 <> ptr2					= (False, 0, pstate)
				= case ptrKind ptr1 of
					CDataCons					-> (True, 90, pstate)
					CFun						-> (False, 0, pstate)
			same_head _ _ pstate
				= (False, 0, pstate)
	hypHints _ _ _ hints pstate
		= (hints, pstate)

// ========================================================================================================================
// Local function of hypHints. (used for AbsurdEquality but also to suggest Rewrite H1 in H2.)
// ------------------------------------------------------------------------------------------------------------------------   
absurd_equal_expressions :: !CExprH !CExprH -> Bool
// ------------------------------------------------------------------------------------------------------------------------   
absurd_equal_expressions (ptr1 @@# _) (ptr2 @@# _)
	| ptrKind ptr1 <> CDataCons					= False
	| ptrKind ptr2 <> CDataCons					= False
	| ptr1 == ptr2								= False
	= True
absurd_equal_expressions (CBasicValue (CBasicInteger n1)) (CBasicValue (CBasicInteger n2))
	= n1 <> n2
absurd_equal_expressions (CBasicValue (CBasicCharacter c1)) (CBasicValue (CBasicCharacter c2))
	= c1 <> c2
absurd_equal_expressions (CBasicValue (CBasicRealNumber r1)) (CBasicValue (CBasicRealNumber r2))
	= r1 <> r2
absurd_equal_expressions (CBasicValue (CBasicBoolean b1)) (CBasicValue (CBasicBoolean b2))
	= b1 <> b2
absurd_equal_expressions (CBasicValue (CBasicString s1)) (CBasicValue (CBasicString s2))
	= s1 <> s2
absurd_equal_expressions _ _
	= False

// ========================================================================================================================
// Local function of hypHints and goalHints. (used for hint RefineUndefinedness)
// ------------------------------------------------------------------------------------------------------------------------   
check_undefinedness :: !CExprH !CExprH !*PState -> (!Bool, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
check_undefinedness (ptr @@# exprs) CBottom pstate
	| ptrKind ptr == CDataCons
		# (error, cons, pstate)					= accErrorProject (getDataConsDef ptr) pstate
		| isError error							= (False, pstate)
		| length exprs <> cons.dcdArity			= (False, pstate)
		| cons.dcdArity == 0					= (False, pstate)
		= (any_strict cons.dcdSymbolType.sytArguments, pstate)
	| ptrKind ptr == CFun
		# (error, fun, pstate)					= accErrorProject (getFunDef ptr) pstate
		| isError error							= (False, pstate)
		| unknown fun.fdDefinedness				= (False, pstate)
		| length exprs <> fun.fdArity			= (False, pstate)
		| fun.fdArity == 0						= (False, pstate)
		= (True, pstate)
	= (False, pstate)
	where
		any_strict :: ![CTypeH] -> Bool
		any_strict [CStrict _:_]				= True
		any_strict [_:types]					= any_strict types
		any_strict []							= False
check_undefinedness CBottom (ptr @@# exprs) pstate
	= check_undefinedness (ptr @@# exprs) CBottom pstate
check_undefinedness _ _ pstate
	= (False, pstate)

// PROBLEEM - type correctheid van apply/rewrite is niet gegarandeerd
// ========================================================================================================================
// @1: UseFact                - location of the apply/rewrite rule
// @2: (Int,Int,Int)          - score for (apply,rewriteLR,rewriteRL) (possibly 0; already adjusted to target]
// @3: [CPropVarPtr]          - passed proposition variables that may be unified
// @4: [CExprVarPtr]          - passed expression variables that may be unified
// @5: Int                    - number of hypotheses that have been passed
// @6: Prop                   - the apply/rewrite rule itself
// @7: (Maybe HypothesisPtr)  - the target to rewrite (hypothesis or goal)
// @8: Prop                   - proposition = target
// @9: Bool                   - True: adjust rewrite scores by examining complexity of lhs/rhs; False: always use given scores
// @10: [Hint]                - previously generated hints
// @11: [HypothesisPtr]       - ptrs to hypotheses in the current goal (used for Apply Forwards; checks for duplicates)
// @11: *PState               - pstate
// ------------------------------------------------------------------------------------------------------------------------   
findApplyRewrite :: !UseFact !(!Int, !Int, !Int) ![CPropVarPtr] ![CExprVarPtr] !Int !CPropH !(Maybe HypothesisPtr) !CPropH !Bool ![Hint] ![CPropH] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findApplyRewrite fact score pvars evars passed_hyps (CExprForall ptr p) mb_ptr target adjust hints hyp_props pstate
	= findApplyRewrite fact score pvars [ptr:evars] passed_hyps p mb_ptr target adjust hints hyp_props pstate
findApplyRewrite fact score pvars evars passed_hyps (CPropForall ptr p) mb_ptr target adjust hints hyp_props pstate
	= findApplyRewrite fact score [ptr:pvars] evars passed_hyps p mb_ptr target adjust hints hyp_props pstate
findApplyRewrite fact score pvars evars passed_hyps (CImplies p q) Nothing target adjust hints hyp_props pstate
	= findApplyRewrite fact score pvars evars (passed_hyps+1) q Nothing target adjust hints hyp_props pstate
findApplyRewrite fact (apply_score,_,_) pvars evars passed_hyps (CImplies p q) (Just ptr) target adjust hints hyp_props pstate
	| apply_score == 0							= (hints, pstate)
	# (ok, sub, _, _, _, pstate)				= acc5Heaps (Match evars pvars p target) pstate
	| not ok									= (hints, pstate)
	# (new_hyp, pstate)							= accHeaps (SafeSubst sub q) pstate
	| isMember new_hyp hyp_props				= (hints, pstate)
	= ([hintApplyH apply_score fact ptr: hints], pstate)
findApplyRewrite fact (apply_score,rewrite_score_lr,rewrite_score_rl) pvars evars passed_hyps rule mb_ptr target adjust hints hyp_props pstate
	# (applied, hints, pstate)					= case mb_ptr of
													Just ptr	-> (False, hints, pstate)
													Nothing		-> case apply_score > 0 of
																	True	-> check_apply hints pstate
																	False	-> (False, hints, pstate)
	| applied									= (hints, pstate)
	# (hints, pstate)							= check_rewrite_lr rule hints pstate
	# (hints, pstate)							= check_rewrite_rl rule hints pstate
	= (hints, pstate)
	where
		check_apply :: ![Hint] !*PState -> (!Bool, ![Hint], !*PState)
		check_apply hints pstate
			# (ok, _, _, _, _, pstate)			= acc5Heaps (Match evars pvars rule target) pstate
			= case ok of
				True							-> (True, [hintApply new_apply_score fact: hints], pstate)
				False							-> (False, hints, pstate)
			where
				new_apply_score = if (passed_hyps==0) 100 apply_score
		
		check_rewrite_lr :: !CPropH ![Hint] !*PState -> (![Hint], !*PState)
		check_rewrite_lr (CEqual lhs rhs) hints pstate
			| rewrite_score_lr == 0				= (hints, pstate)
			| basic_expr lhs && adjust			= (hints, pstate)
			# (changed, _, _, pstate)			= acc3Heaps (RewriteExpr target AllRedexes evars pvars lhs rhs) pstate
			| not changed						= (hints, pstate)
			# score								= if (basic_expr rhs && adjust) 90 rewrite_score_lr
			# hint								= case mb_ptr of
													Just ptr	-> hintRewriteH score LeftToRight fact ptr
													Nothing		-> hintRewrite score LeftToRight fact
			= ([hint:hints], pstate)
		check_rewrite_lr (CIff lhs rhs) hints pstate
			| rewrite_score_lr == 0				= (hints, pstate)
			# (changed, _, _, pstate)			= acc3Heaps (RewriteProp target AllRedexes evars pvars lhs rhs) pstate
			| not changed						= (hints, pstate)
			# hint								= case mb_ptr of
													Just ptr	-> hintRewriteH rewrite_score_lr LeftToRight fact ptr
													Nothing		-> hintRewrite rewrite_score_lr LeftToRight fact
			= ([hint:hints], pstate)
		check_rewrite_lr _ hints pstate
			= (hints, pstate)
		
		check_rewrite_rl :: !CPropH ![Hint] !*PState -> (![Hint], !*PState)
		check_rewrite_rl (CEqual lhs rhs) hints pstate
			| rewrite_score_rl == 0				= (hints, pstate)
			| basic_expr rhs && adjust			= (hints, pstate)
			# (changed, _, _, pstate)			= acc3Heaps (RewriteExpr target AllRedexes evars pvars rhs lhs) pstate
			| not changed						= (hints, pstate)
			# score								= if (basic_expr lhs && adjust) 90 rewrite_score_rl
			# hint								= case mb_ptr of
													Just ptr	-> hintRewriteH rewrite_score_rl RightToLeft fact ptr
													Nothing		-> hintRewrite rewrite_score_rl RightToLeft fact
			= ([hint:hints], pstate)
		check_rewrite_rl (CIff lhs rhs) hints pstate
			| rewrite_score_rl == 0				= (hints, pstate)
			# (changed, _, _, pstate)			= acc3Heaps (RewriteProp target AllRedexes evars pvars rhs lhs) pstate
			| not changed						= (hints, pstate)
			# hint								= case mb_ptr of
													Just ptr	-> hintRewriteH rewrite_score_rl RightToLeft fact ptr
													Nothing		-> hintRewrite rewrite_score_rl RightToLeft fact
			= ([hint:hints], pstate)
		check_rewrite_rl _ hints pstate
			= (hints, pstate)
		
		// True if RNF (or constructor)
		basic_expr :: !CExprH -> Bool
		basic_expr (ptr @@# args)				= ptrKind ptr == CDataCons
		basic_expr (CBasicValue _)				= True
		basic_expr CBottom						= True
		basic_expr _							= False

// ------------------------------------------------------------------------------------------------------------------------   
findHintTheorems :: ![HintTheorem] ![HypothesisPtr] ![CPropH] !CPropH ![Hint] !*PState -> (![Hint], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findHintTheorems [ht:hts] hyps hyp_props goal hints pstate
	# (hints, pstate)							= find ht hyps hyp_props hints pstate
	= findHintTheorems hts hyps hyp_props goal hints pstate
	where
		find :: !HintTheorem ![HypothesisPtr] ![CPropH] ![Hint] !*PState -> (![Hint], !*PState)
		find ht [ptr:ptrs] [prop:props] hints pstate
			# (hints, pstate)					= findApplyRewrite fact hyp_scores [] [] 0 rule (Just ptr) prop False hints hyp_props pstate
			= find ht ptrs props hints pstate
		find ht [] [] hints pstate
			= findApplyRewrite fact goal_scores [] [] 0 rule Nothing goal False hints hyp_props pstate
		
		fact									= TheoremFact ht.hintPointer []
		rule									= ht.hintProp
		hyp_scores								= (ht.hintApplyForwardScore, ht.hintRewriteLRScore, ht.hintRewriteRLScore)
		goal_scores								= (ht.hintApplyScore, ht.hintRewriteLRScore, ht.hintRewriteRLScore)
findHintTheorems [] _ _ _ hints pstate
	= (hints, pstate)