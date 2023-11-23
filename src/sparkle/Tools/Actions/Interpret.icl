/*
** Program: Clean Prover System
** Module:  Interpret (.icl)
** 
** Author:  Maarten de Mol
** Created: 22 August 2000
*/

implementation module 
   Interpret

import 
   StdEnv,
   StdIO,
   ossystem,
   ostick,
   MdM_IOlib,
   CoreTypes,
   CoreAccess,
   Heaps,
   ChangeDefinition,
   Rewrite,
   Print,
   States,
   BindLexeme,
   MarkUpText,
   FormattedShow,
   ShowDefinition,
   GiveType,
   LReduce
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
AlmostBGColour		:== RGB {r=215, g=215, b=240}
BGColour			:== RGB {r=200, g=200, b=225}
LightBGColour		:== RGB {r=240, g=240, b=250}
DarkBGColour		:== RGB {r=180, g=180, b=200}
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
:: ReductionState =
// ------------------------------------------------------------------------------------------------------------------------   
	{ rCurrentExpr			:: !CExprH
	, rCurrentCount			:: !Int
	, rHistory				:: ![(CExprH, Int/*, Int*/)]				// expr, count, sharedNum{heaps}
	}

// ------------------------------------------------------------------------------------------------------------------------   
boxControl text markup_attrs attrs
// ------------------------------------------------------------------------------------------------------------------------   
	# resize							= find_resize attrs
	= CompoundControl
			( MarkUpControl text markup_attrs resize )
			[ ControlHMargin			1 1
			, ControlVMargin			1 1
			, ControlItemSpace			1 1
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour Black, draw newFrame])
			: attrs
			]
	where
		find_resize [ControlResize fun:_]
			= [ControlResize fun]
		find_resize [other:rest]
			= find_resize rest
		find_resize []
			= []

// ------------------------------------------------------------------------------------------------------------------------   
openDefinition :: !(MarkUpEvent WindowCommand) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
openDefinition event pstate
	| event.meSelectEvent				= pstate
	# (ok, ptr)							= get_heap_ptr event.meLink
	| not ok							= pstate
	= showDefinition ptr pstate
	where
		get_heap_ptr :: !WindowCommand -> (!Bool, !HeapPtr)
		get_heap_ptr (CmdShowDefinition ptr)
			= (True, ptr)
		get_heap_ptr _
			= (False, DummyValue)















// ------------------------------------------------------------------------------------------------------------------------   
findStartExpr :: !*PState -> (!CExprH, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
findStartExpr pstate
	# (mod_ptrs, pstate)				= pstate!ls.stProject.prjModules
	= findInModule mod_ptrs pstate
	where
		findInModule :: ![ModulePtr] !*PState -> (!CExprH, !*PState)
		findInModule [ptr:ptrs] pstate
			# (mod, pstate)				= accHeaps (readPointer ptr) pstate
			# fun_ptrs					= mod.pmFunPtrs
			# (ok, expr, pstate)		= findInFuns fun_ptrs pstate
			| ok						= (expr, pstate)
			= findInModule ptrs pstate
		findInModule [] pstate
			= (CBottom, pstate)
		
		findInFuns :: ![HeapPtr] !*PState -> (!Bool, !CExprH, !*PState)
		findInFuns [ptr:ptrs] pstate
			# (error, fun, pstate)		= accErrorProject (getFunDef ptr) pstate
			| isError error				= findInFuns ptrs pstate
			| fun.fdName <> "Start"		= findInFuns ptrs pstate
			= (True, fun.fdBody, pstate)
		findInFuns [] pstate
			= (False, DummyValue, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
startInterpreter :: !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
startInterpreter pstate
	# (opened, pstate)			= isWindowOpened DlgInterpreter True pstate
	| opened					= pstate
	# (menu_id, pstate)			= pstate!ls.stMenus.interpreter_id
	# pstate					= appPIO (markMenuItems [menu_id]) pstate
	# (winfo, pstate)			= new_Window DlgInterpreter pstate
	# dialog_id					= winfo.wiWindowId
	# rid						= fromJust winfo.wiNormalRId
	# pos						= winfo.wiStoredPos
	# width						= winfo.wiStoredWidth
	# height					= winfo.wiStoredHeight
	# (expr, pstate)			= findStartExpr pstate
	# (lets_id, pstate)			= accPIO openId pstate
	# (status_id, pstate)		= accPIO openId pstate
	# (status_rid, pstate)		= accPIO openRId pstate
	# expr_id					= fromJust winfo.wiControlId
	# (expr_rid, pstate)		= accPIO openRId pstate
	# (reduce_all_bid, pstate)	= accPIO openButtonId pstate
	# (reduce_rnf_bid, pstate)	= accPIO openButtonId pstate
	# (reduce_step_bid, pstate)	= accPIO openButtonId pstate
	# (undo_bid, pstate)		= accPIO openButtonId pstate
	# (restart_bid, pstate)		= accPIO openButtonId pstate
	# pstate					= {pstate & ls.stHeaps.numShared = 0}
	# (dialog, pstate)			= InterpretDLG expr dialog_id rid status_rid expr_id expr_rid reduce_all_bid reduce_rnf_bid reduce_step_bid undo_bid restart_bid pos width height pstate
	# rstate					= {rCurrentExpr = expr, rCurrentCount = 500000, rHistory = []}
	= snd (openWindow rstate dialog pstate)

// ------------------------------------------------------------------------------------------------------------------------   
// InterpretDLG :: Id -> Dialog _ _ _
// ------------------------------------------------------------------------------------------------------------------------   
InterpretDLG body own_id rid status_rid expr_id expr_rid reduce_all_bid reduce_rnf_bid reduce_step_bid undo_bid restart_bid pos width height pstate
	# (private_rid, pstate)		= accPIO openRId pstate
	# (metrics, _)				= osDefaultWindowMetrics 42
	# (finfo, pstate)			= makeFormatInfo pstate
	# the_controls				= controls metrics private_rid
	# (size, pstate)			= controlSize the_controls True (Just (5,5)) (Just (5,5)) (Just (5,5)) pstate
	= ( Window "Interpret expression" the_controls
		[ WindowId				own_id
		, WindowPos				(Fix, OffsetVector pos)
		, WindowClose			(noLS (close_Window DlgInterpreter))
		, WindowLook			True (\_ {newFrame} -> seq [setPenColour BGColour, fill newFrame])
		, WindowHMargin			5 5
		, WindowVMargin			5 5
		, WindowItemSpace		5 5
		, WindowViewSize		size
		, WindowInit			(noLS (update body 500000 (pack_tick 0) (pack_tick 0)))
		]
	  , pstate)
	where
		controls metrics private_rid
			=		Receiver			rid receive []
				:+: Receiver			private_rid add_ls []
				:+: MarkUpControl		[CmText "?"]
											[ MarkUpWidth				(width + 2 + metrics.osmVSliderWidth)
											, MarkUpNrLinesI			2 4
											, MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	BGColour
											, MarkUpReceiver			status_rid
											]
											[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h})
											]
				:+: MarkUpControl		[CmBText "Current expression:"]
											[ MarkUpFontFace			"Times New Roman"
											, MarkUpTextSize			10
											, MarkUpBackgroundColour	BGColour
											]
											[ ControlPos				(Left, zero)
											]
				:+:	boxControl			[CmText "?"]
											[ MarkUpWidth				width
											, MarkUpHeight				height
											, MarkUpBackgroundColour	LightBGColour
											, MarkUpFont				{fName = "Courier New", fSize=10, fStyles=[]}
											, MarkUpLinkStyle			False Black LightBGColour False Blue LightBGColour
											, MarkUpIgnoreMultipleSpaces
											, MarkUpReceiver			expr_rid
											, MarkUpEventHandler		openDefinition
											, MarkUpHScroll
											, MarkUpVScroll
											]
											[ ControlResize				(\current old new -> {w = current.w + new.w - old.w, h = current.h + new.h - old.h})
											, ControlPos				(Left, zero)
											, ControlId					expr_id
											]
				:+: MarkUpButton		"Restart" BGColour (snd o (asyncSend private_rid "Restart")) restart_bid
											[ ControlPos				(Right, zero)
											]
				:+: MarkUpButton		"Undo" BGColour (snd o (asyncSend private_rid "Undo")) undo_bid
											[ ControlPos				(LeftOf (fst3 restart_bid), zero)
											, ControlSelectState		Unable
											]
				:+: MarkUpButton		"Reduce Step" BGColour (snd o (asyncSend private_rid "Reduce Step")) reduce_step_bid
											[ ControlPos				(LeftOf (fst3 undo_bid), zero)
											]
				:+: MarkUpButton		"Reduce RNF" BGColour (snd o (asyncSend private_rid "Reduce RNF")) reduce_rnf_bid
											[ ControlPos				(LeftOf (fst3 reduce_step_bid), zero)
											]
				:+: MarkUpButton		"Reduce All" BGColour (snd o (asyncSend private_rid "Reduce All")) reduce_all_bid
											[ ControlPos				(LeftOf (fst3 reduce_rnf_bid), zero)
											]
		
		add_ls :: !String !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		add_ls "Reduce All" (rstate, pstate)		= reduce_many LToNF (rstate, pstate)
		add_ls "Reduce RNF" (rstate, pstate)		= reduce_many LToRNF (rstate, pstate)
		add_ls "Reduce Step" (rstate, pstate)		= reduce_step (rstate, pstate)
		add_ls "Undo" (rstate, pstate)				= undo (rstate, pstate)
		add_ls "Restart" (rstate, pstate)			= new_expression (rstate, pstate)
		
		empty_vars :: [String]
		empty_vars = []
		
		update :: !CExprH !Int !Tick !Tick !*PState -> *PState
		update expr count ticks_before ticks_after pstate
			# (finfo, pstate)					= makeFormatInfo pstate
			# finfo								= {finfo & fiNeedBrackets = False}
			# (error, cexpr, pstate)			= showInProject finfo expr pstate
			#! pstate							= case (isError error) of
													True	-> showError error pstate
													False	-> pstate
			# pstate							= changeMarkUpText expr_rid cexpr pstate
			# fcount							= [CmText "Number of reduction steps taken: ", CmBText (toString (500000 - count))]
			# fcount							= [CmRight, CmBText "Count: ", CmAlign "@@", CmBackgroundColour AlmostBGColour] ++ fcount ++ [CmFillLine, CmEndBackgroundColour]
			# ticks_difference					= tickDifference ticks_after ticks_before
			# ms_difference						= (1000 / ticksPerSecond) * ticks_difference
			# ftime								= [CmText "Time needed for last reduction: ", CmBText (toString ms_difference), CmText " ms"]
			# ftime								= [CmRight, CmBText "Time: ", CmAlign "@@", CmBackgroundColour AlmostBGColour] ++ ftime ++ [CmFillLine, CmEndBackgroundColour]
			# fstatus							= fcount ++ [CmNewlineI False 3 Nothing] ++ ftime
			# pstate							= changeMarkUpText status_rid fstatus pstate
			= pstate
			where
				name_smaller :: !String !String -> Bool
				name_smaller name1 name2
					# name1						= name1 % (1, size name1 - 1)
					# name2						= name2 % (1, size name2 - 1)
					= toInt name1 < toInt name2
				
				show_infos :: !FormatInfo ![CShared] !*PState -> (!MarkUpText WindowCommand, !*PState)
				show_infos finfo [] pstate
					= ([], pstate)
				show_infos finfo [shared:more_shared] pstate
					# fstart						= [CmRight, CmBText shared.shName, CmAlign "=", CmText " = "]
					# (error, fexpr, pstate)		= showInProject finfo shared.shExpr pstate
					#! pstate						= case (isError error) of
														True	-> showError error pstate
														False	-> pstate
					# (frest, pstate)				= show_infos finfo more_shared pstate
					= (fstart ++ fexpr ++ [CmNewline] ++ frest, pstate)
		
		reduce_step :: !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		reduce_step (rstate, pstate)
			#! (ticks_before, pstate)				= getCurrentTick pstate
			# (expr, pstate)						= accHeapsProject (convertC2L rstate.rCurrentExpr) pstate
			# ((n, expr), pstate)					= accHeapsProject (LReduce [] AsInClean LToNF 1 expr) pstate
			# (expr, pstate)						= accHeapsProject (convertL2C expr) pstate
			#! (ticks_after, pstate)				= getCurrentTick pstate
			# count									= rstate.rCurrentCount - (1-n)
			# rstate								=	{ rCurrentExpr			= expr
														, rCurrentCount			= count
														, rHistory				= [(rstate.rCurrentExpr,rstate.rCurrentCount): rstate.rHistory]
														}
			# pstate								= update expr count ticks_before ticks_after pstate
			# pstate								= enableButton undo_bid pstate
			= (rstate, pstate)
		
		reduce_many :: !LReduceTo !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		reduce_many rto (rstate, pstate)
			#! (ticks_before, pstate)				= getCurrentTick pstate
			# (expr, pstate)						= accHeapsProject (convertC2L rstate.rCurrentExpr) pstate
			# ((count, expr), pstate)				= accHeapsProject (LReduce [] AsInClean rto rstate.rCurrentCount expr) pstate
			# (expr, pstate)						= accHeapsProject (convertL2C expr) pstate
			#! (ticks_after, pstate)				= getCurrentTick pstate
			# rstate								=	{ rCurrentExpr			= expr
														, rCurrentCount			= count
														, rHistory				= [(rstate.rCurrentExpr,rstate.rCurrentCount): rstate.rHistory]
														}
			# pstate								= update expr count ticks_before ticks_after pstate
			# pstate								= enableButton undo_bid pstate
			= (rstate, pstate)
		
		simple_expr :: !CExprH -> Bool
		simple_expr (CExprVar _)					= True
		simple_expr (CShared _)						= False
		simple_expr (_ @# _)						= False
		simple_expr (_ @@# es)						= and (map simple_expr es)
		simple_expr (CLet _ _ _)					= False
		simple_expr (CCase _ _ _)					= False
		simple_expr (CBasicValue _)					= True
		simple_expr (CCode _ _)						= False
		simple_expr CBottom							= True
		
		new_expression :: !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		new_expression (rstate, pstate)
			# (opened, pstate)						= isWindowOpened DlgNewExpression True pstate
			| opened								= (rstate, pstate)
			# (winfo, pstate)						= new_Window DlgNewExpression pstate
			# dialog_id								= winfo.wiWindowId
			# (input_id, pstate)					= accPIO openId pstate
			# (show_type_rid, pstate)				= accPIO openRId pstate
			# (type_id, pstate)						= accPIO openId pstate
			# (accept_id, pstate)					= accPIO openId pstate
			# (dialog, pstate)						= NewExpressionDlg rid dialog_id input_id show_type_rid type_id accept_id pstate
			# (_, pstate)							= openDialog Nothing dialog pstate
			# pstate								= disableButton undo_bid pstate
			= (rstate,pstate)
		
		undo :: !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		undo (rstate, pstate)
			# (expr, count)							= hd rstate.rHistory
			# new_history							= tl rstate.rHistory
			# rstate								=	{ rCurrentExpr			= expr
														, rCurrentCount			= count
														, rHistory				= new_history
														}
			# (ticks, pstate)						= getCurrentTick pstate
			# pstate								= update expr count ticks ticks pstate
			# pstate								= case (isEmpty new_history) of
														True	-> disableButton undo_bid pstate
														False	-> pstate
			= (rstate, pstate)
		
		receive :: !WindowCommand !(!ReductionState, !*PState) -> (!ReductionState, !*PState)
		receive (CmdSetInterpretExpr expr) (_, pstate)
			# (ticks, pstate)						= getCurrentTick pstate
			# pstate								= {pstate & ls.stHeaps.numShared = 0}
			# pstate								= update expr 500000 ticks ticks pstate
			# rstate								= {rCurrentExpr = expr, rCurrentCount = 500000, rHistory = []}
			# pstate								= disableButton undo_bid pstate
			= (rstate, pstate)
		receive (CmdRefresh ChangedDisplayOption) (rstate,pstate)
			# (ticks, pstate)						= getCurrentTick pstate
			# pstate								= update rstate.rCurrentExpr rstate.rCurrentCount ticks ticks pstate
			= (rstate, pstate)
		receive _ (rstate, pstate)
			= (rstate, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
NewExpressionDlg rid dialog_id input_id show_type_rid type_id accept_id pstate
// ------------------------------------------------------------------------------------------------------------------------   
	# fontdef						= {fName = "Courier New", fStyles = [], fSize = 10}
	# ((_, font), pstate)			= accPIO (accScreenPicture (openFont fontdef)) pstate
	= ( Dialog "Enter New Expression" (
			EditControl			"" (PixelWidth 500) 10
									[ ControlId					input_id
									]
		:+: MarkUpControl			[]
									[ MarkUpWidth				500
									, MarkUpHeight				20
									, MarkUpBackgroundColour	BGColour
									, MarkUpTextColour			Black
									, MarkUpLinkStyle			False Black BGColour False Blue BGColour
									, MarkUpFontFace			"Courier"
									, MarkUpTextSize			10
									, MarkUpReceiver			show_type_rid
									, MarkUpEventHandler		openDefinition
									]
									[ ControlPos				(Center, NoOffset)
									]
		:+: ButtonControl		"Accept"
									[ ControlId					accept_id
									, ControlFunction			(noLS accept)
									, ControlPos				(Right, zero)
									]
		:+: ButtonControl		"Check Type"
									[ ControlPos				(LeftOf accept_id, zero)
									, ControlFunction			(noLS check_type)
									]
		)
		[ WindowId				dialog_id
		, WindowPos				(Fix, OffsetVector {vx=100,vy=100})
		, WindowClose			(noLS (close_Window DlgNewExpression))
		]
	  , pstate)
	where
		check_type :: !*PState -> *PState
		check_type pstate
			# (maybe_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
			| isNothing maybe_wstate			= pstate
			# wstate							= fromJust maybe_wstate
			# (ok, maybe_text)					= getControlText input_id wstate
			| not ok							= pstate
			| isNothing maybe_text				= pstate
			# text								= fromJust maybe_text
			# (error, expr, pstate)				= accErrorHeapsProject (buildExpr text) pstate
			| isError error						= showError error pstate
			# (finfo, pstate)					= makeFormatInfo pstate
			# (error, (info, type), pstate)		= accErrorHeapsProject (typeExpr expr) pstate
			| isError error						= showError error (changeMarkUpText show_type_rid [CmBText "!ERROR!"] pstate)
			# (error, mtext, pstate)			= accErrorHeapsProject (FormattedShow finfo type) pstate
			| isError error						= showError error pstate
			# pstate							= changeMarkUpText show_type_rid mtext pstate
			= pstate
		
		accept :: !*PState -> *PState
		accept pstate
			# (maybe_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
			| isNothing maybe_wstate			= pstate
			# wstate							= fromJust maybe_wstate
			# (ok, maybe_text)					= getControlText input_id wstate
			| not ok							= pstate
			| isNothing maybe_text				= pstate
			# text								= fromJust maybe_text
			# (error, expr, pstate)				= accErrorHeapsProject (buildExpr text) pstate
			| isError error						= showError error pstate
			# (_, pstate)						= asyncSend rid (CmdSetInterpretExpr expr) pstate
			# pstate							= close_Window DlgNewExpression pstate
			= pstate