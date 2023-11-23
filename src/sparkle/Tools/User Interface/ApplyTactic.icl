/*
** Program: Clean Prover System
** Module:  ApplyTactic (.icl)
** 
** Author:  Maarten de Mol
** Created: 11 Januari 2001
**
** WARNING: Indexes are always counted from 0 here (popup-items as well!!!)
*/

implementation module 
	ApplyTactic

import 
	StdEnv,
	StdIO,
	ControlMaybe,
	MdM_IOlib,
	Arith,
	Compare,
	Definedness,
	States,
	Operate,
	GiveType,
	BindLexeme,
	Tactics,
	FileMonad
from StdFunc import seq

// ------------------------------------------------------------------------------------------------------------------------   
GrayGreen		:== RGB {r=175,g=200,b=175}
LightGreen		:== RGB {r=200,g=225,b=200}
LighterGreen	:== RGB {r=210,g=235,b=210}
id2				:== \x y -> y
id3				:== \x y z -> z
id4				:== \x y z q -> q
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
applyToDialog :: !TheoremPtr !Theorem !TacticId !*PState -> (!Error, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
applyToDialog ptr theorem tactic pstate
	# (options, pstate)						= pstate!ls.stOptions
	#! (error, theorem, _, pstate)			= acc3HeapsProject (applyTactic tactic ptr theorem options) pstate
	| isError error							= (error, pstate)
	# pstate								= appHeaps (writePointer ptr theorem) pstate
	# pstate								= broadcast Nothing (ChangedProof ptr) pstate
	= (OK, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
//GreenDialog :: !Id !Id !String _ _ -> _
// ------------------------------------------------------------------------------------------------------------------------   
GreenDialog dialog_id cancel_id title controls attributes
	= Dialog ("APPLY TACTIC"/* +++ title*/)
		(CompoundControl (controls :+: invisible_close)
			[ ControlHMargin			5 5
			, ControlVMargin			5 5
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour GrayGreen, fill newFrame])
			]
		)
		[ WindowHMargin					0 0
		, WindowVMargin					0 0
		, WindowCancel					cancel_id
		, WindowId						dialog_id
		, WindowClose					(noLS (closeWindow dialog_id))
		: attributes
		]
	where
		invisible_close
			= ButtonControl				"Cancel"
											[ ControlPos		(LeftTop, zero)
											, ControlId			cancel_id
											, ControlFunction	(noLS close_window)
											, ControlHide
											]
		
		close_window pstate
			= closeWindow dialog_id pstate

// ------------------------------------------------------------------------------------------------------------------------   
//greenDialog :: _
// ------------------------------------------------------------------------------------------------------------------------   
greenDialog title controls attributes
	= Dialog title
		(CompoundControl controls
			[ ControlHMargin			5 5
			, ControlVMargin			5 5
			, ControlLook				True (\_ {newFrame} -> seq [setPenColour GrayGreen, fill newFrame])
			]
		)
		[ WindowHMargin					0 0
		, WindowVMargin					0 0
		: attributes
		]

// ------------------------------------------------------------------------------------------------------------------------   
//textControl :: !String _ -> _
// ------------------------------------------------------------------------------------------------------------------------   
textControl text extra_attributes attributes
	= MarkUpControl [CmText text]
		[ MarkUpFontFace				"Times New Roman"
		, MarkUpTextSize				10
		, MarkUpBackgroundColour		GrayGreen //getDialogBackgroundColour
		: extra_attributes
		]
		attributes

// ------------------------------------------------------------------------------------------------------------------------   
//btextControl :: !String _ -> _
// ------------------------------------------------------------------------------------------------------------------------   
btextControl text extra_attributes attributes
	= MarkUpControl [CmBText text]
		[ MarkUpFontFace				"Times New Roman"
		, MarkUpTextSize				10
		, MarkUpBackgroundColour		GrayGreen //getDialogBackgroundColour
		: extra_attributes
		]
		attributes

// ------------------------------------------------------------------------------------------------------------------------   
//itextControl :: !String _ -> _
// ------------------------------------------------------------------------------------------------------------------------   
itextControl text extra_attributes attributes
	= MarkUpControl [CmIText text]
		[ MarkUpFontFace				"Times New Roman"
		, MarkUpTextSize				10
		, MarkUpBackgroundColour		GrayGreen //getDialogBackgroundColour
		: extra_attributes
		]
		attributes


// ------------------------------------------------------------------------------------------------------------------------   
normalize :: !(MarkUpText a) -> MarkUpText a
// ------------------------------------------------------------------------------------------------------------------------   
normalize [CmColour _:mtext]			= normalize mtext
normalize [CmEndColour:mtext]			= normalize mtext
normalize [CmLink text _:mtext]			= [CmText text: normalize mtext]
normalize [CmBold:mtext]				= normalize mtext
normalize [CmEndBold:mtext]				= normalize mtext
normalize [CmBText text:mtext]			= [CmText text: normalize mtext]
normalize [command:mtext]				= [command: normalize mtext]
normalize []							= []








































// ------------------------------------------------------------------------------------------------------------------------   
:: Argument =
// ------------------------------------------------------------------------------------------------------------------------   
	{ arName					:: !String
	, arIdentifier				:: !String
	, arNameId					:: !Id
	, arId						:: !Id
	, arDuplicate				:: !Bool
	, arType					:: !Char
	, arEditInitial				:: !String
	, arPopUpItems				:: ![String]
	, arPopUpInitial			:: !Int
	}
	
// ------------------------------------------------------------------------------------------------------------------------   
:: Target =
// ------------------------------------------------------------------------------------------------------------------------   
	{ taName					:: !String
	, taCurrentGoal				:: !Bool
	, taHypothesis				:: !HypothesisPtr
	, taArguments				:: ![Argument]
	}

// ------------------------------------------------------------------------------------------------------------------------   
buildEditArgument :: !String !String !String !*PState -> (!Argument, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildEditArgument name identifier initial pstate
	# (name_id, pstate)						= accPIO openId pstate
	# (id, pstate)							= accPIO openId pstate
	# arg									=	{ arName			= name
												, arIdentifier		= identifier
												, arNameId			= name_id
												, arId				= id
												, arDuplicate		= False
												, arType			= 'E'
												, arEditInitial		= initial
												, arPopUpItems		= []
												, arPopUpInitial	= 0
												}
	= (arg, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
buildPopUpArgument :: !String !String ![String] !Int !*PState -> (!Argument, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildPopUpArgument name identifier items initial pstate
	# (name_id, pstate)						= accPIO openId pstate
	# (id, pstate)							= accPIO openId pstate
	# arg									=	{ arName			= name
												, arIdentifier		= identifier
												, arNameId			= name_id
												, arId				= id
												, arDuplicate		= False
												, arType			= 'P'
												, arEditInitial		= ""
												, arPopUpItems		= items
												, arPopUpInitial	= initial
												}
	= (arg, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
no_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
no_args _ pstate
	= (False, [], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
buildTargets :: !Goal (CPropH *PState -> (Bool, [Argument], *PState)) (CPropH *PState -> (Bool, [Argument], *PState)) !*PState
			 -> (![Target], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
buildTargets goal build_current build_hyp pstate
	# (current_ok, current_args, pstate)	= build_current goal.glToProve pstate
	# current_target						=	{ taName			= "current goal"
												, taCurrentGoal		= True
												, taHypothesis		= nilPtr
												, taArguments		= current_args
												}
	# (hyp_targets, pstate)					= build_hyp_targets (reverse goal.glHypotheses) pstate
	# targets								= case current_ok of
												True	-> [current_target: hyp_targets]
												False	-> hyp_targets
	# (targets, _)							= remove_duplicates_t targets []
	= (targets, pstate)
	where
		// MdM -- 2.0 BUG -- have to remove this type -- otherwise crash or inexplicable type error
		// build_hyp_targets :: ![HypothesisPtr] !*PState -> (![Target], !*PState)
		build_hyp_targets [ptr:ptrs] pstate
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# (ok, arguments, pstate)		= build_hyp hyp.hypProp pstate
			| not ok						= build_hyp_targets ptrs pstate
			# target						=	{ taName			= "hypothesis " +++ hyp.hypName
												, taCurrentGoal		= False
												, taHypothesis		= ptr
												, taArguments		= arguments
												}
			# (targets, pstate)				= build_hyp_targets ptrs pstate
			= ([target:targets], pstate)
		build_hyp_targets [] pstate
			= ([], pstate)
		
		remove_duplicates_t :: ![Target] ![(String,Id)] -> (![Target], ![(String,Id)])
		remove_duplicates_t [target:targets] passed
			# (arguments, passed)			= remove_duplicates_a target.taArguments passed
			# target						= {target & taArguments = arguments}
			# (targets, passed)				= remove_duplicates_t targets passed
			= ([target:targets], passed)
		remove_duplicates_t [] passed
			= ([], passed)
		
		remove_duplicates_a :: ![Argument] ![(String,Id)] -> (![Argument], ![(String,Id)])
		remove_duplicates_a [arg:args] passed
			# filtered						= filter (\(name,i) -> name == arg.arIdentifier) passed
			| isEmpty filtered
				# (args, passed)			= remove_duplicates_a args [(arg.arIdentifier,arg.arId):passed]
				= ([arg:args], passed)
			# (_, id)						= hd filtered
			# arg							= {arg & arId = id, arDuplicate = True}
			# (args, passed)				= remove_duplicates_a args passed
			= ([arg:args], passed)
		remove_duplicates_a [] passed
			= ([], passed)

// ------------------------------------------------------------------------------------------------------------------------   
applyDialog :: !String !TheoremPtr !Theorem ![Target] (Bool -> HypothesisPtr -> [String] -> [Int] -> *PState -> (Error, TacticId, *PState)) !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyDialog tactic theorem_ptr theorem targets finish pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (name_id, pstate)						= accPIO openId pstate
	# (target_id, pstate)					= accPIO openId pstate
	# (args_id, pstate)						= accPIO openId pstate
	# (args_rid, pstate)					= accPIO openRId pstate
	# (ok_id, pstate)						= accPIO openId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	# controls								= map (build_target_control args_id) targets
	= snd (openModalDialog 0 (dialog dialog_id name_id target_id args_id args_rid ok_id cancel_id controls targets) pstate)
	where
		dialog dialog_id name_id target_id args_id args_rid ok_id cancel_id controls targets
			= greenDialog ("APPLY TACTIC " +++ tactic)
				(		btextControl		"Apply tactic:"
												[]
												[]
				  :+:	textControl 		tactic
				  								[]
				  								[ ControlId				name_id
				  								]
				  :+:	btextControl		"Target:"
				  								[]
				  								[ ControlPos			(LeftOf target_id, zero)
				  								]
				  :+:	PopUpControl		[(target.taName,focus args_rid targets index) \\ target <- targets & index <- indexList targets] 0
				  								[ ControlId				target_id
				  								, ControlPos			(Below name_id, zero)
				  								, ControlSelectState	(if (length targets < 2) Unable Able)
				  								]
				  :+:	btextControl		"Arguments:"
				  								[]
				  								[ ControlPos			(LeftOf args_id, zero)
				  								]
				  :+:	textControl			"-"
				  								[ MarkUpWidth			400
				  								, MarkUpReceiver		args_rid
				  								]
				  								[ ControlId				args_id
				  								, ControlPos			(Below target_id, zero)
				  								]
				  :+:	ButtonControl		"Cancel"
				  								[ ControlPos			(Right, zero)
				  								, ControlFunction		(noLS (closeWindow dialog_id))
				  								, ControlId				cancel_id
				  								]
				  :+:	ButtonControl		"Ok"
				  								[ ControlPos			(LeftOf cancel_id, zero)
				  								, ControlId				ok_id
				  								, ControlFunction		(go dialog_id targets)
				  								]
				  :+:						(ListLS controls)
				)
				[ WindowId					dialog_id
				, WindowClose				(noLS (closeWindow dialog_id))
				, WindowInit				(focus args_rid targets 0)
				, WindowOk					ok_id
				, WindowCancel				cancel_id
				]
		
		build_target_control args_id target
			= ListLS (build_argument_controls target.taArguments args_id)
		
		build_argument_controls [arg:args] previous_id
			# text_control					= itextControl (arg.arName +++ ":")
													[]
													[ ControlPos	(LeftOf arg.arId, zero)
													, ControlId		arg.arNameId
													, ControlHide
													]
			# edit_control					= build_edit_control arg previous_id
			# popup_control					= build_popup_control arg previous_id
//			# single_control				= build_text_control arg previous_id
			# control						= text_control :+: edit_control :+: popup_control // :+: single_control
			# controls						= build_argument_controls args arg.arId
			= [control: controls]
		build_argument_controls [] previous_id
			= []
		
		build_edit_control arg previous_id
			| arg.arType <> 'E'				= ControlNothing
			| arg.arDuplicate				= ControlNothing
			# edit_control					= EditControl arg.arEditInitial (PixelWidth 400) 1
													[ ControlId				arg.arId
													, ControlPos			(Below previous_id, zero)
													, ControlHide
													]
			= ControlJust edit_control
		
		build_popup_control arg previous_id
			| arg.arType <> 'P'				= ControlNothing
			| arg.arDuplicate				= ControlNothing
//			| length arg.arPopUpItems == 1	= ControlNothing
			# popup_control					= PopUpControl [(name,id) \\ name <- arg.arPopUpItems] (arg.arPopUpInitial+1)
													[ ControlId				arg.arId
													, ControlPos			(Below previous_id, zero)
													, ControlHide
													, ControlWidth			(PixelWidth 400)
													]
			= ControlJust popup_control
		
		build_text_control arg previous_id
			| arg.arType <> 'P'				= ControlNothing
			| length arg.arPopUpItems <> 1	= ControlNothing
			| arg.arDuplicate				= ControlNothing
			# text_control					= textControl (hd arg.arPopUpItems)
													[ MarkUpWidth			400
													]
													[ ControlPos			(Below previous_id, zero)
													, ControlHide
													, ControlId				arg.arId
													]
			= ControlJust text_control
		
		focus :: !(RId (MarkUpMessage a)) ![Target] !Int !(!Int, !*PState) -> (!Int, !*PState)
		focus args_rid targets new (previous,pstate)
			# previous_target				= targets !! previous
			# new_target					= targets !! new
			# names							= [CmIText (arg.arName +++ " ") \\ arg <- new_target.taArguments]
			# names							= if (isEmpty new_target.taArguments) [CmIText "--none--"] names
			# pstate						= changeMarkUpText args_rid names pstate
			# pstate						= appPIO (uwalk hideControl [arg.arId \\ arg <- previous_target.taArguments]) pstate
			# pstate						= appPIO (uwalk hideControl [arg.arNameId \\ arg <- previous_target.taArguments]) pstate
			# pstate						= appPIO (uwalk showControl [arg.arId \\ arg <- new_target.taArguments]) pstate
			# pstate						= appPIO (uwalk showControl [arg.arNameId \\ arg <- new_target.taArguments]) pstate
			= (new, pstate)
		
		// MdM -- 2.0 BUG -- have to remove this type -- otherwise crash or inexplicable type error
		// go :: !Id ![Target] !(!Int, !*PState) -> (!Int, !*PState)
		go dialog_id targets (num, pstate)
			# target						= targets !! num
			# (mb_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate			= (num, pstate)
			# wstate						= fromJust mb_wstate
			# (texts, indexes)				= get_selections target.taArguments wstate
			# (error, tactic, pstate)		= finish target.taCurrentGoal target.taHypothesis texts indexes pstate
			| isError error					= (num, showError error pstate)
			# (error, pstate)				= applyToDialog theorem_ptr theorem tactic pstate
			| isError error					= (num, showError error pstate)
			= (num, closeWindow dialog_id pstate)
			where
				get_selections :: ![Argument] !WState -> (![String], ![Int])
				get_selections [arg:args] wstate
					| arg.arType == 'E'
						# (ok, mb_text)			= getControlText arg.arId wstate
						| not ok				= get_selections args wstate
						| isNothing mb_text		= get_selections args wstate
						# text					= fromJust mb_text
						# (texts, indexes)		= get_selections args wstate
						= ([text:texts], indexes)
					| arg.arType == 'P' && length arg.arPopUpItems == 1
						# (texts, indexes)		= get_selections args wstate
						= (texts, [0:indexes])
					| arg.arType == 'P'
						# (ok, mb_index)		= getPopUpControlSelection arg.arId wstate
						| not ok				= get_selections args wstate
						| isNothing mb_index	= get_selections args wstate
						# index					= fromJust mb_index - 1
						# (texts, indexes)		= get_selections args wstate
						= (texts, [index:indexes])
					= get_selections args wstate
				get_selections [] wstate
					= ([], [])
















// ------------------------------------------------------------------------------------------------------------------------   
showNumTh :: !Int -> String
// ------------------------------------------------------------------------------------------------------------------------   
showNumTh num
	| isMember num [11..13]					= toString num +++ "th"
	| (num - 1) rem 10 == 0					= toString num +++ "st"
	| (num - 2) rem 10 == 0					= toString num +++ "nd"
	| (num - 3) rem 10 == 0					= toString num +++ "rd"
	| otherwise								= toString num +++ "th"

// ------------------------------------------------------------------------------------------------------------------------   
class findRedexes a :: !a !Int !FormatInfo !*CHeaps !*CProject -> (![String], !Int, !*CHeaps, !*CProject)
class reducable a   :: !a -> Bool
// ------------------------------------------------------------------------------------------------------------------------   

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes [a] | findRedexes a
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes [x:xs] num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes x num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes xs num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes [] num finfo heaps prj
		= ([], num, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance reducable [a] | reducable a
// ------------------------------------------------------------------------------------------------------------------------   
where
	reducable [x:xs]
		= reducable x || reducable xs
	reducable []
		= False

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (Maybe a) | findRedexes a
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes (Just x) num finfo heaps prj
		= findRedexes x num finfo heaps prj
	findRedexes Nothing num finfo heaps prj
		= ([], num, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CAlgPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes pattern num finfo heaps prj
		= findRedexes pattern.atpResult num finfo heaps prj

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CBasicValue HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes (CBasicArray exprs) num finfo heaps prj
		= findRedexes exprs num finfo heaps prj
	findRedexes other num finfo heaps prj
		= ([], num, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance reducable (CBasicValue HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	reducable (CBasicArray exprs)
		= reducable exprs
	reducable other
		= False

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CBasicPattern HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes pattern num finfo heaps prj
		= findRedexes pattern.bapResult num finfo heaps prj

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CCasePatterns HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes (CAlgPatterns _ patterns) num finfo heaps prj
		= findRedexes patterns num finfo heaps prj
	findRedexes (CBasicPatterns _ patterns) num finfo heaps prj
		= findRedexes patterns num finfo heaps prj

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes (CExprVar ptr) num finfo heaps prj
		= ([], num, heaps, prj)
	findRedexes (CShared ptr) num finfo heaps prj
		# (shared, heaps)					= readPointer ptr heaps
		= findRedexes shared.shExpr num finfo heaps prj
	findRedexes (expr @# exprs) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes expr num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes exprs num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes expr=:(ptr @@# exprs) num finfo heaps prj
		# (text, heaps, prj)				= showRedex num expr finfo heaps prj
		# (texts, num, heaps, prj)			= findRedexes exprs (num+1) finfo heaps prj
		= ([text:texts], num, heaps, prj)
	findRedexes expr=:(CLet strict lets res_expr) num finfo heaps prj
		# (text, heaps, prj)				= showRedex num expr finfo heaps prj
		# (vars, exprs)						= unzip lets
		# (texts1, num, heaps, prj)			= findRedexes exprs (num+1) finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes res_expr num finfo heaps prj
		= ([text:texts1++texts2], num, heaps, prj)
	findRedexes expr=:(CCase case_expr patterns def) num finfo heaps prj
		# (text, heaps, prj)				= showRedex num expr finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes case_expr (num+1) finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes patterns num finfo heaps prj
		# (texts3, num, heaps, prj)			= findRedexes def num finfo heaps prj
		= ([text:texts1 ++ texts2 ++ texts3], num, heaps, prj)
	findRedexes (CBasicValue value) num finfo heaps prj
		= findRedexes value num finfo heaps prj
	findRedexes (CCode _ _) num finfo heaps prj
		= ([], num, heaps, prj)
	findRedexes CBottom num finfo heaps prj
		= ([], num, heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
instance reducable (CExpr HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	reducable (CExprVar ptr)
		= False
	reducable (CShared ptr)
		= True
	reducable (expr @# exprs)
		= reducable expr || reducable exprs
	reducable (ptr @@# args)
		= True
	reducable (CLet strict lets expr)
		= True
	reducable (CCase expr patterns def)
		= True
	reducable (CBasicValue value)
		= reducable value
	reducable (CCode codetype codecontents)
		= False
	reducable CBottom
		= False

// ------------------------------------------------------------------------------------------------------------------------   
instance findRedexes (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	findRedexes CTrue num info heaps prj
		= ([], num, heaps, prj)
	findRedexes CFalse num info heaps prj
		= ([], num, heaps, prj)
	findRedexes (CEqual e1 e2) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes e1 num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes e2 num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes (CPropVar ptr) num finfo heaps prj
		= ([], num, heaps, prj)
	findRedexes (CNot p) num finfo heaps prj
		= findRedexes p num finfo heaps prj
	findRedexes (CAnd p q) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes p num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes q num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes (COr p q) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes p num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes q num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes (CImplies p q) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes p num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes q num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes (CIff p q) num finfo heaps prj
		# (texts1, num, heaps, prj)			= findRedexes p num finfo heaps prj
		# (texts2, num, heaps, prj)			= findRedexes q num finfo heaps prj
		= (texts1 ++ texts2, num, heaps, prj)
	findRedexes (CExprForall var p) num finfo heaps prj
		= findRedexes p num finfo heaps prj
	findRedexes (CExprExists var p) num finfo heaps prj
		= findRedexes p num finfo heaps prj
	findRedexes (CPropForall var p) num finfo heaps prj
		= findRedexes p num finfo heaps prj
	findRedexes (CPropExists var p) num finfo heaps prj
		= findRedexes p num finfo heaps prj
	findRedexes (CPredicate ptr exprs) num finfo heaps prj
		= findRedexes exprs num finfo heaps prj

// ------------------------------------------------------------------------------------------------------------------------   
instance reducable (CProp HeapPtr)
// ------------------------------------------------------------------------------------------------------------------------   
where
	reducable CTrue
		= False
	reducable CFalse
		= False
	reducable (CPropVar ptr)
		= False
	reducable (CEqual e1 e2)
		= reducable e1 || reducable e2
	reducable (CNot p)
		= reducable p
	reducable (CAnd p q)
		= reducable p || reducable q
	reducable (COr p q)
		= reducable p || reducable q
	reducable (CImplies p q)
		= reducable p || reducable q
	reducable (CIff p q)
		= reducable p || reducable q
	reducable (CExprForall var p)
		= reducable p
	reducable (CExprExists var p)
		= reducable p
	reducable (CPropForall var p)
		= reducable p
	reducable (CPropExists var p)
		= reducable p
	reducable (CPredicate ptr exprs)
		= reducable exprs

// ------------------------------------------------------------------------------------------------------------------------   
showRedex :: !Int !CExprH !FormatInfo !*CHeaps !*CProject -> (!String, !*CHeaps, !*CProject)
// ------------------------------------------------------------------------------------------------------------------------   
showRedex num expr finfo heaps prj
	# (_, fexpr, heaps, prj)				= FormattedShow finfo expr heaps prj
	= ("just the " +++ showNumTh num +++ " redex (" +++ toText fexpr +++ ")", heaps, prj)

































// ------------------------------------------------------------------------------------------------------------------------   
applyAbsurd :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyAbsurd ptr theorem goal pstate
	# hyp_ptrs								= reverse goal.glHypotheses
	# (hyps, pstate)						= accHeaps (readPointers hyp_ptrs) pstate
	# (pairs, pstate)						= accHeaps (findPairs hyp_ptrs hyps) pstate
	# (targets, pstate)						= buildTargets goal (current_args pairs) no_args pstate
	| isEmpty targets						= showError (pushError (X_ApplyTactic "Absurd" "No contradictory hypotheses can be found") OK) pstate
	= applyDialog "Absurd" ptr theorem targets (finish pairs) pstate
	where
		findPairs :: ![HypothesisPtr] ![Hypothesis] !*CHeaps -> (![(HypothesisPtr, CName, HypothesisPtr, CName)], !*CHeaps)
		findPairs [ptr:ptrs] [hyp:hyps] heaps
			# (ok, ptr2, name2, heaps)		= findContradict hyp.hypProp ptrs hyps heaps
			| not ok						= findPairs ptrs hyps heaps
			# (pairs, heaps)				= findPairs ptrs hyps heaps
			= ([(ptr, hyp.hypName, ptr2, name2): pairs], heaps)
		findPairs [] [] heaps
			= ([], heaps)
		
		findContradict :: !CPropH ![HypothesisPtr] ![Hypothesis] !*CHeaps -> (!Bool, !HypothesisPtr, !CName, !*CHeaps)
		findContradict p [ptr:ptrs] [hyp:hyps] heaps
			# (ok, heaps)					= isContradict p hyp.hypProp heaps
			| not ok						= findContradict p ptrs hyps heaps
			= (True, ptr, hyp.hypName, heaps)
		findContradict p [] [] heaps
			= (False, nilPtr, DummyValue, heaps)
		
		isContradict :: !CPropH !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		isContradict (CNot p) (CNot q) heaps
			= isContradict p q heaps
		isContradict (CNot p) q heaps
			= AlphaEqual p q heaps
		isContradict p (CNot q) heaps
			= AlphaEqual p q heaps
		isContradict p q heaps
			= (False, heaps)
		
		current_args :: [(HypothesisPtr, CName, HypothesisPtr, CName)] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args pairs prop pstate
			| isEmpty pairs					= (False, [], pstate)
			# (pairs, pstate)				= buildPopUpArgument "pair" "P" ["hypothesis " +++ name1 +++ " contradicts with hypothesis " +++ name2 \\ (_,name1,_,name2) <- pairs] 0 pstate
			= (True, [pairs], pstate)
		
		finish :: [(HypothesisPtr, CName, HypothesisPtr, CName)] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish pairs True _ [] [pair] pstate
			# (ptr1, _, ptr2, _)			= pairs !! pair
			= (OK, TacticAbsurd ptr1 ptr2, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyAbsurdEquality :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyAbsurdEquality ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError (pushError (X_ApplyTactic "AbsurdEquality" "No usable contradictory equalities were found.") OK) pstate
	= applyDialog "AbsurdEquality" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (ok, pstate)					= accProject (absurd_equality True prop) pstate
			= (ok, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (ok, pstate)					= accProject (absurd_equality False prop) pstate
			= (ok, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticAbsurdEquality, pstate)
		finish False ptr [] [] pstate
			= (OK, TacticAbsurdEqualityH ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyApply :: !(Maybe HypothesisPtr) !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyApply mb_ptr ptr theorem goal pstate
	# (hyp_ptrs, hyp_names, pstate)			= case mb_ptr of
												Nothing		-> acc2Heaps (getHypothesisNames (reverse goal.glHypotheses)) pstate
												Just ptr	-> let (hyp,pstate`) = accHeaps (readPointer ptr) pstate
																in ([ptr], [hyp.hypName], pstate`)
	# (theorems, pstate)					= case mb_ptr of
												Nothing		-> allTheorems pstate
												Just ptr	-> ([], pstate)
	# (theorems, pstate)					= accHeaps (getTheorems theorems) pstate
	# theorems								= sortBy (\(n1,p1)(n2,p2) -> n1 < n2) theorems
	# (theorem_names, theorem_ptrs)			= unzip theorems
	# hyp_targets							= case mb_ptr of
												Nothing		-> hyp_args hyp_names theorem_names
												Just ptr	-> no_args
	# (targets, pstate)						= buildTargets goal (current_args hyp_names theorem_names) hyp_targets pstate
	| isEmpty targets						= showError [X_ApplyTactic "Apply" "None of the hypotheses and theorems can be used as a rule."] pstate
	= applyDialog "Apply" ptr theorem targets (finish hyp_ptrs theorem_ptrs) pstate
	where
		is_rule :: !CPropH -> Bool
		is_rule (CImplies p q)				= True
		is_rule (CExprForall var p)			= True
		is_rule (CPropForall var p)			= True
		is_rule other						= False
		
		getHypothesisNames :: ![HypothesisPtr] !*CHeaps -> (![HypothesisPtr], ![CName], !*CHeaps)
		getHypothesisNames [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
			| not (is_rule hyp.hypProp)		= getHypothesisNames ptrs heaps
			# (ptrs, names, heaps)			= getHypothesisNames ptrs heaps
			= ([ptr:ptrs], [hyp.hypName:names], heaps)
		getHypothesisNames [] heaps
			= ([], [], heaps)
		
		getTheorems :: ![TheoremPtr] !*CHeaps -> (![(CName, TheoremPtr)], !*CHeaps)
		getTheorems [ptr:ptrs] heaps
			# (theorem, heaps)				= readPointer ptr heaps
			# is_rule						= is_rule theorem.thInitial
			| not is_rule					= getTheorems ptrs heaps
			# (theorems, heaps)				= getTheorems ptrs heaps
			= ([(theorem.thName,ptr):theorems], heaps)
		getTheorems [] heaps
			= ([], heaps)

		current_args :: ![CName] ![CName] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args hyp_names theorem_names prop pstate
			# names							= ["hypothesis " +++ name \\ name <- hyp_names] ++
											  ["theorem " +++ name \\ name <- theorem_names]
			| isEmpty names					= (False, [], pstate)
			# (fact, pstate)				= buildPopUpArgument "rule" "R" names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			= (True, [fact, args], pstate)
		
		hyp_args :: ![CName] ![CName] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args hyp_names theorem_names prop pstate
			# names							= ["hypothesis " +++ name \\ name <- hyp_names] ++
											  ["theorem " +++ name \\ name <- theorem_names]
			| isEmpty names					= (False, [], pstate)
			# (fact, pstate)				= buildPopUpArgument "rule" "R" names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (new hypothesis)", "explicit (introduce in goal)"] 0 pstate
			= (True, [fact,args,mode], pstate)
		
		finish :: ![HypothesisPtr] ![TheoremPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish hyp_ptrs theorem_ptrs True _ [args] [fact] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# fact							= if (fact < length hyp_ptrs)
													(HypothesisFact (hyp_ptrs !! fact) args)
													(TheoremFact (theorem_ptrs !! (fact - length hyp_ptrs)) args)
			= (OK, TacticApply fact, pstate)
		finish hyp_ptrs theorem_ptrs False ptr [args] [fact,mode] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# fact							= if (fact < length hyp_ptrs)
													(HypothesisFact (hyp_ptrs !! fact) args)
													(TheoremFact (theorem_ptrs !! (fact - length hyp_ptrs)) args)
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticApplyH fact ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyAssume :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyAssume ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Assume" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			# (prop, pstate)				= buildEditArgument "proposition" "P" "" pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (new hypothesis)", "explicit (in current goal)"] 0 pstate
			= (True, [prop,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [prop] [mode] pstate
			# (error, lexemes)				= parseLexemes prop
			| isError error					= (error, DummyValue, pstate)
			# (error, prop)					= parseProposition lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, prop, pstate)			= accErrorHeapsProject (bindRelativeProp prop goal) pstate
			| isError error					= (error, DummyValue, pstate)
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticAssume prop mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyCase :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyCase ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Case" "No disjunction found in current goal or a hypothesis."] pstate
	= applyDialog "Case" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (finfo, pstate)				= makeFormatInfo pstate
			# (texts, pstate)				= split_goal prop finfo pstate
			| isEmpty texts					= (False, [], pstate)
			# (cases, pstate)				= buildPopUpArgument "alternative" "A" texts 0 pstate
			= (True, [cases], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# nr_ors						= count_ors prop
			| nr_ors == 0					= (False, [], pstate)
			# (depth, pstate)				= buildPopUpArgument "depth" "D" ["shallow (only use top-level OR)": if (nr_ors > 1) ["deep (use all ORs)"] []] 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [depth,mode], pstate)
		
		split_goal :: !CPropH !FormatInfo !*PState -> (![String], !*PState)
		split_goal (COr p q) finfo pstate
			# ps							= deep_ors (COr p q)
			| length ps < 3					= (["left", "right"], pstate)
			# (names, pstate)				= show ps 1 finfo pstate
			= (["left", "right":names], pstate)
		split_goal other finfo pstate
			= ([], pstate)
		
		count_ors :: !CPropH -> Int
		count_ors (COr p q)					= 1 + count_ors p + count_ors q
		count_ors _							= 0
		
		deep_ors :: !CPropH -> [CPropH]
		deep_ors (COr p q)					= deep_ors p ++ deep_ors q
		deep_ors other						= [other]
		
		show :: ![CPropH] !Int !FormatInfo !*PState -> (![String], !*PState)
		show [p:ps] num finfo pstate
			# start							= "inner, " +++ showNumTh num
			# (rest, pstate)				= show ps (num+1) finfo pstate
			# (_, ftext, pstate)			= accErrorHeapsProject (FormattedShow finfo p) pstate
			# text							= toText ftext
			= ([start +++ " (" +++ text +++ ")":rest], pstate)
		show [] num finfo pstate
			= ([], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [alternative] pstate
			# depth							= if (alternative < 2) Shallow Deep
			# num							= if (alternative < 2) (alternative+1) (alternative-1)
			= (OK, TacticCase depth num, pstate)
		finish False ptr [] [depth,mode] pstate
			# depth							= if (depth==0) Shallow Deep
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticCaseH depth ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyCases :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyCases ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Cases" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (expr, pstate)				= buildEditArgument "expression" "E" "" pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace variable)", "explicit (introduce equality)"] 0 pstate
			= (True, [expr,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [expr] [mode] pstate
			# (error, lexemes)				= parseLexemes expr
			| isError error					= (error, DummyValue, pstate)
			# (error, expr)					= parseExpression lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, expr, pstate)			= acc2HeapsProject (bindRelativeExpr expr goal) pstate
			| isError error					= (error, DummyValue, pstate)
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticCases expr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyChooseCase :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyChooseCase ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "ChooseCase" "Not applicable in current goal or any of its hypotheses."] pstate
	= applyDialog "ChooseCase" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (ok, _, pstate)				= acc2HeapsProject (chooseCase True prop goal) pstate
			= (ok, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (ok, _, pstate)				= acc2HeapsProject (chooseCase False prop goal) pstate
			= (ok, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticChooseCase, pstate)
		finish False ptr [] [] pstate
			= (OK, TacticChooseCaseH ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyCompare :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyCompare ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	= applyDialog "Compare" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			# (e1, pstate)					= buildEditArgument "e1" "E1" "" pstate
			# (e2, pstate)					= buildEditArgument "e2" "E2" "" pstate
			= (True, [e1,e2], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args (CEqual (ptr @@# [e1,e2]) (CBasicValue (CBasicBoolean False))) pstate
			# (error, info, pstate)			= accErrorHeapsProject (getDefinitionInfo ptr) pstate
			| isError error					= (False, [], pstate)
			| info.diModuleName <> "StdInt"	= (False, [], pstate)
			| info.diName <> "<"			= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [mode], pstate)
		hyp_args _ pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [e1,e2] [] pstate
			// e1
			# (error, lexemes)				= parseLexemes e1
			| isError error					= (error, DummyValue, pstate)
			# (error, e1)					= parseExpression lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, e1, pstate)			= acc2HeapsProject (bindRelativeExpr e1 goal) pstate
			| isError error					= (error, DummyValue, pstate)
			// e2
			# (error, lexemes)				= parseLexemes e2
			| isError error					= (error, DummyValue, pstate)
			# (error, e2)					= parseExpression lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, e2, pstate)			= acc2HeapsProject (bindRelativeExpr e2 goal) pstate
			| isError error					= (error, DummyValue, pstate)
			= (OK, TacticCompare e1 e2, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticCompareH ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyContradiction :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyContradiction ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	= applyDialog "Contradiction" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (assume hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [mode], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			= (True, [], pstate)
			
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticContradiction mode, pstate)
		finish False ptr [] [] pstate
			= (OK, TacticContradictionH ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyCut :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyCut ptr theorem goal pstate
	# hyp_ptrs								= reverse goal.glHypotheses
	# (hyp_names, pstate)					= accHeaps (getPointerNames hyp_ptrs) pstate
	# (theorems, pstate)					= allTheorems pstate
	# (theorems, pstate)					= accHeaps (addTheoremNames theorems) pstate
	# theorems								= sortBy (\(n1,p1)(n2,p2) -> n1 < n2) theorems
	# (theorem_names, theorem_ptrs)			= unzip theorems
	# (targets, pstate)						= buildTargets goal (current_args hyp_names theorem_names) no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Cut" "No theorems or hypotheses available to introduce."] pstate
	= applyDialog "Cut" ptr theorem targets (finish hyp_ptrs theorem_ptrs) pstate
	where
		addTheoremNames :: ![TheoremPtr] !*CHeaps -> (![(CName, TheoremPtr)], !*CHeaps)
		addTheoremNames [ptr:ptrs] heaps
			# (name, heaps)					= getPointerName ptr heaps
			# (theorems, heaps)				= addTheoremNames ptrs heaps
			= ([(name,ptr):theorems], heaps)
		addTheoremNames [] heaps
			= ([], heaps)
		
		current_args :: ![CName] ![CName] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args hyp_names theorem_names prop pstate
			# all_names						= ["hypothesis " +++ name \\ name <- hyp_names] ++
											  ["theorem " +++ name \\ name <- theorem_names]
			| isEmpty all_names				= (False, [], pstate)
			# (fact, pstate)				= buildPopUpArgument "fact" "F" all_names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			= (True, [fact,args], pstate)
		
		finish :: ![HypothesisPtr] ![TheoremPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish hyp_ptrs theorem_ptrs True _ [args] [fact] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# fact							= if (fact < length hyp_ptrs)
													(HypothesisFact (hyp_ptrs !! fact) args)
													(TheoremFact (theorem_ptrs !! (fact - length hyp_ptrs)) args)
			= (OK, TacticCut fact, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyDefinedness :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyDefinedness ptr theorem goal pstate
	# (con, definedness_info, pstate)		= acc2HeapsProject (findDefinednessInfo goal) pstate
	# defined								= definedness_info.definedExpressions
	# undefined								= definedness_info.undefinedExpressions
	# can_apply								= con || contradict defined undefined
	| not can_apply							= showError [X_ApplyTactic "Definedness" "No contradictory definedness could be detected."] pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Definedness" ptr theorem targets finish pstate
	where
		contradict :: ![CExprH] ![CExprH] -> Bool
		contradict [expr:exprs] undefined
			| isMember expr undefined		= True
			= contradict exprs undefined
		contradict [] undefined
			= False
		
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			= (True, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticDefinedness, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyDiscard :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyDiscard ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Discard" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			# (names, pstate)				= buildEditArgument "names" "N" "" pstate
			= (True, [names], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [names] [] pstate
			# (error, lexemes)				= parseLexemes names
			| isError error					= (error, DummyValue, pstate)
			# (ok, names)					= get_names lexemes
			| not ok || isEmpty names		= (pushError (X_ApplyTactic "Discard" "Unable to read list of identifiers.") OK, DummyValue, pstate)
			# (options, pstate)				= pstate!ls.stOptions
			= accErrorHeapsProject (bindTactic (PTacticDiscard names) goal [] options) pstate
			
		get_names :: ![CLexeme] -> (!Bool, ![CName])
		get_names [CIdentifier name:lexemes]
			# (ok, names)					= get_names lexemes
			= (ok, [name:names])
		get_names [_:_]
			= (False, [])
		get_names []
			= (True, [])

// ------------------------------------------------------------------------------------------------------------------------   
applyExact :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyExact ptr theorem goal pstate
	# (hyp_ptrs, hyp_names, pstate)			= acc2Heaps (find_hyps (reverse goal.glHypotheses)) pstate
	# (theorems, pstate)					= allTheorems pstate
	# (theorem_ptrs, theorem_names, pstate)	= acc2Heaps (find_theorems theorems) pstate
	# fact_names							= ["hypothesis " +++ name \\ name <- hyp_names] ++
											  ["theorem " +++ name \\ name <- theorem_names]
	# (targets, pstate)						= buildTargets goal (current_args fact_names) no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Exact" "None of the hypotheses or theorems equals the current goal."] pstate
	= applyDialog "Exact" ptr theorem targets (finish hyp_ptrs theorem_ptrs) pstate
	where
		find_hyps :: ![HypothesisPtr] !*CHeaps -> (![HypothesisPtr], ![CName], !*CHeaps)
		find_hyps [] heaps
			= ([], [], heaps)
		find_hyps [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
//			# (equal, heaps)				= AlphaEqual hyp.hypProp goal.glToProve heaps
//			| not equal						= find_hyps ptrs heaps
			# (ptrs, names, heaps)			= find_hyps ptrs heaps
			= ([ptr:ptrs], [hyp.hypName:names], heaps)
		
		find_theorems :: ![TheoremPtr] !*CHeaps -> (![TheoremPtr], ![CName], !*CHeaps)
		find_theorems [] heaps
			= ([], [], heaps)
		find_theorems [ptr:ptrs] heaps
			# (theorem, heaps)				= readPointer ptr heaps
//			# (equal, heaps)				= AlphaEqual theorem.thInitial goal.glToProve heaps
//			| not equal						= find_theorems ptrs heaps
			# (ptrs, names, heaps)			= find_theorems ptrs heaps
			= ([ptr:ptrs], [theorem.thName:names], heaps)
		
		current_args :: ![String] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args fact_names _ pstate
			| isEmpty fact_names			= (False, [], pstate)
			# (fact, pstate)				= buildPopUpArgument "rule" "R" fact_names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			= (True, [fact, args], pstate)
		
		finish :: ![HypothesisPtr] ![TheoremPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish hyps theorems True _ [args] [fact] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# fact							= case fact >= length hyps of
												True	-> TheoremFact (theorems !! (fact - length hyps)) args
												False	-> HypothesisFact (hyps !! fact) args
			= (OK, TacticExact fact, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyExFalso :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyExFalso ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal no_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "ExFalso" "None of the hypotheses is FALSE."] pstate
	= applyDialog "ExFalso" ptr theorem targets finish pstate
	where
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args CFalse pstate
			= (True, [], pstate)
		hyp_args _ pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish False ptr _ _ pstate
			= (OK, TacticExFalso ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyExpandFun :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyExpandFun ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "ExpandFun" "No functions in the current goal or any of its hypotheses."] pstate
	= applyDialog "ExpandFun" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# just_funs						= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations just_funs prop) pstate
			| isEmpty locations				= (False, [], pstate)
			# text_locations				= [name +++ " (occurrence " +++ toString index +++ ")" \\ (name, index) <- locations]
			# (locs, pstate)				= buildPopUpArgument "function" "F" text_locations 0 pstate
			= (True, [locs], pstate)

		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# just_funs						= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations just_funs prop) pstate
			| isEmpty locations				= (False, [], pstate)
			# text_locations				= [name +++ " (occurrence " +++ toString index +++ ")" \\ (name, index) <- locations]
			# unique_id						= foldr (+++) "" text_locations
			# (locs, pstate)				= buildPopUpArgument "function" unique_id text_locations 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [locs, mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [locs] pstate
			# just_funs						= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations just_funs goal.glToProve) pstate
			# (name, index)					= locations !! locs
			= (OK, TacticExpandFun name index, pstate)
		finish False ptr [] [locs,mode] pstate
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# just_funs						= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations just_funs hyp.hypProp) pstate
			# (name, index)					= locations !! locs
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticExpandFunH name index ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyExtensionality :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyExtensionality ptr theorem goal pstate
	# (ok, e1, e2)							= get_equal goal.glToProve
	| not ok								= showError [X_ApplyTactic "Extensionality" "Current goal is not an equality."] pstate
	# (error, (_, type), pstate)			= accErrorHeapsProject (typeExprInGoal e1 goal) pstate
	| isError error							= showError error pstate
	| not (is_fun_type type)				= showError [X_ApplyTactic "Extensionality" "Not a function."] pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Extensionality" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			# (name, pstate)				= buildEditArgument "name" "N" "x" pstate
			= (True, [name], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [name] _ pstate
			| name == ""					= ([X_Internal "Invalid (empty) name."], DummyValue, pstate)
			# chars_ok						= and [isValidNameChar c \\ c <-: name]
			| not chars_ok					= ([X_Internal "Invalid (illegal characters) name."], DummyValue, pstate)
			= (OK, TacticExtensionality name, pstate)
		
		get_equal :: !CPropH -> (!Bool, !CExprH, !CExprH)
		get_equal (CEqual e1 e2)			= (True, e1, e2)
		get_equal _							= (False, DummyValue, DummyValue)
		
		is_fun_type :: !CTypeH -> Bool
		is_fun_type (type ==> type2)		= True
		is_fun_type _						= False

// ------------------------------------------------------------------------------------------------------------------------   
applyGeneralize :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyGeneralize ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Generalize" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (type, pstate)				= buildPopUpArgument "type" "T" ["expression", "proposition"] 0 pstate
			# (term, pstate)				= buildEditArgument "term" "X" "" pstate
			# (name, pstate)				= buildEditArgument "varname" "V" "gen" pstate
			= (True, [type,term,name], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [text,name] [0] pstate
			| name == ""					= ([X_Internal "Empty varname not allowed"], DummyValue, pstate)
			# (error, lexemes)				= parseLexemes text
			| isError error					= (error, DummyValue, pstate)
			# (error, expr)					= parseExpression lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, expr, pstate)			= acc2HeapsProject (bindRelativeExpr expr goal) pstate
			| isError error					= (error, DummyValue, pstate)
			= (OK, TacticGeneralizeE expr name, pstate)
		finish True _ [text,name] [1] pstate
			| name == ""					= ([X_Internal "Empty varname not allowed"], DummyValue, pstate)
			# (error, lexemes)				= parseLexemes text
			| isError error					= (error, DummyValue, pstate)
			# (error, prop)					= parseProposition lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, prop, pstate)			= acc2HeapsProject (bindRelativeProp prop goal) pstate
			| isError error					= (error, DummyValue, pstate)
			= (OK, TacticGeneralizeP prop name, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyInduction :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyInduction ptr theorem goal pstate
	# (error, sub, info, pstate)			= acc3HeapsProject (wellTyped goal) pstate
	| isError error							= showError [X_ApplyTactic "Induction" "Goal could not be typed.": error] pstate
	# (var_ptrs1, var_names1, pstate)		= acc2Heaps (find_introduced_vars (reverse goal.glExprVars) sub) pstate
	# (var_ptrs2, var_names2, pstate)		= acc2Heaps (find_forall_vars goal.glToProve sub) pstate
	# var_ptrs								= var_ptrs1 ++ var_ptrs2
	| isEmpty var_ptrs						= showError [X_ApplyTactic "Induction" "No variable available to do case-distinction on."] pstate
	# (targets, pstate)						= buildTargets goal (current_args var_names1 var_names2) no_args pstate
	= applyDialog "Induction" ptr theorem targets (finish var_ptrs) pstate
	where
		find_introduced_vars :: ![CExprVarPtr] !Substitution !*CHeaps -> (![CExprVarPtr], ![CName], !*CHeaps)
		find_introduced_vars [ptr:ptrs] sub heaps
			# (var, heaps)					= readPointer ptr heaps
			# can_do_case					= check_case var.evarInfo sub
			| not can_do_case				= find_introduced_vars ptrs sub heaps
			# (ptrs, names, heaps)			= find_introduced_vars ptrs sub heaps
			= ([ptr:ptrs], [var.evarName:names], heaps)
		find_introduced_vars [] sub heaps
			= ([], [], heaps)
		
		find_forall_vars :: !CPropH !Substitution !*CHeaps -> (![CExprVarPtr], ![CName], !*CHeaps)
		find_forall_vars (CExprForall ptr p) sub heaps
			# (var, heaps)					= readPointer ptr heaps
			# can_do_case					= check_case var.evarInfo sub
			| not can_do_case				= find_forall_vars p sub heaps
			# (ptrs, names, heaps)			= find_forall_vars p sub heaps
			= ([ptr:ptrs], [var.evarName:names], heaps)
		find_forall_vars (CPropForall ptr p) sub heaps
			= find_forall_vars p sub heaps
		find_forall_vars other sub heaps
			= ([], [], heaps)
		
		check_case :: !CExprVarInfo !Substitution -> Bool
		check_case (EVar_Type type) sub
			# type							= SimpleSubst sub type
			= is_case_type type
			where
				is_case_type :: !CTypeH -> Bool
				is_case_type (CBasicType CBoolean)
					= True
				is_case_type (ptr @@^ types)
					= ptrKind ptr == CAlgType
				is_case_type other
					= False
		check_case other sub
			= False
		
		current_args :: ![String] ![String] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args introduced_names forall_names prop pstate
			# names							= [name +++ " (introduced)" \\ name <- introduced_names] ++
											  [name +++ " (forall)" \\ name <- forall_names]
			# (var, pstate)					= buildPopUpArgument "variable" "V" names 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace variable)", "explicit (introduce equality)"] 0 pstate
			= (True, [var,mode], pstate)
		
		finish :: ![CExprVarPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish var_ptrs True _ [] [var,mode] pstate
			# var_ptr						= var_ptrs !! var
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticInduction var_ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyInjective :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyInjective ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Injective" "Not applicable in current goal or any hypothesis."] pstate
	= applyDialog "Injective" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (ok, _, _, pstate)			= acc3HeapsProject (inject True prop goal) pstate
			| not ok						= (False, [], pstate)
			= (True, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (ok, _, _, pstate)			= acc3HeapsProject (inject False prop goal) pstate
			| not ok						= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce new hypothesis)"] 0 pstate
			= (True, [mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticInjective, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticInjectiveH ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyIntroduce :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyIntroduce ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal (current_args goal.glNrIHs goal.glNewHypNum goal.glNewIHNum) no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Introduce" "Nothing to introduce."] pstate
	= applyDialog "Introduce" ptr theorem targets finish pstate
	where
		current_args :: !Int !Int !Int !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args nr_ihs hyp_num ih_num prop pstate
			# (suggested_names, pstate)		= accHeaps (intro_names prop nr_ihs hyp_num ih_num) pstate
			| suggested_names == ""			= (False, [], pstate)
			# (names, pstate)				= buildEditArgument "names" "N" suggested_names pstate
			= (True, [names], pstate)
		
		intro_names :: !CPropH !Int !Int !Int !*CHeaps -> (!String, !*CHeaps)
		intro_names (CImplies p q) nr_ihs hyp_num ih_num heaps
			# name							= case nr_ihs > 0 of
												True	-> case hyp_num of
															1	-> "IH"
															_	-> "IH" +++ toString hyp_num
												False	-> "H" +++ toString hyp_num
			# new_nr_ihs					= if (nr_ihs>0) (nr_ihs-1) nr_ihs
			# new_hyp_num					= if (nr_ihs>0) hyp_num (hyp_num+1)
			# new_ih_num					= if (nr_ihs>0) (ih_num+1) ih_num
			# (names, heaps)				= intro_names q new_nr_ihs new_hyp_num new_ih_num heaps
			| names == ""					= (name, heaps)
			= (name +++ " " +++ names, heaps)
		intro_names (CExprForall ptr p) nr_ihs hyp_num ih_num heaps
			# (var, heaps)					= readPointer ptr heaps
			# (names, heaps)				= intro_names p nr_ihs hyp_num ih_num heaps
			| names == ""					= (var.evarName, heaps)
			= (var.evarName +++ " " +++ names, heaps)
		intro_names (CPropForall ptr p) nr_ihs hyp_num ih_num heaps
			# (var, heaps)					= readPointer ptr heaps
			# (names, heaps)				= intro_names p nr_ihs hyp_num ih_num heaps
			| names == ""					= (var.pvarName, heaps)
			= (var.pvarName +++ " " +++ names, heaps)
		intro_names _ nr_ihs hyp_num ih_num heaps
			= ("", heaps)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [names] [] pstate
			# (error, lexemes)				= parseLexemes names
			| isError error					= (error, DummyValue, pstate)
			# (ok, names)					= get_names lexemes
			| not ok						= (pushError (X_ApplyTactic "Introduce" "Could not parse list of identifiers.") OK, DummyValue, pstate)
			| isEmpty names					= (pushError (X_ApplyTactic "Introduce" "Could not parse list of identifiers.") OK, DummyValue, pstate)
			# (options, pstate)				= pstate!ls.stOptions
			# (_, tactic, pstate)			= acc2HeapsProject (bindTactic (PTacticIntroduce names) goal [] options) pstate
			= (OK, tactic, pstate)
		
		get_names :: ![CLexeme] -> (!Bool, ![CName])
		get_names [CIdentifier name:lexemes]
			# (ok, names)					= get_names lexemes
			= (ok, [name:names])
		get_names [_:_]
			= (False, [])
		get_names []
			= (True, [])

// ------------------------------------------------------------------------------------------------------------------------   
applyIntArith :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyIntArith ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "IntArith" "Not applicable in current goal or any of its hypotheses."] pstate
	= applyDialog "IntArith" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# find_exprs					= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations find_exprs prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# texts							= ["all occurrences" : texts]
			# (locs, pstate)				= buildPopUpArgument "location" "L" texts 0 pstate
			= (True, [locs], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# find_exprs					= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations find_exprs prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# texts							= ["all occurrences" : texts]
			# (locs, pstate)				= buildPopUpArgument "location" (foldr (+++) "" texts) texts 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [locs,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [loc] pstate
			# find_exprs					= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations find_exprs goal.glToProve) pstate
			# (locations, _, pstate)		= check_locations locations goal.glToProve pstate
			# location						= if (loc == 0) (AllSubExprs) (locations !! (loc-1))
			= (OK, TacticIntArith location, pstate)
		finish False ptr [] [loc,mode] pstate
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# find_exprs					= {DummyValue & findVars = False, findCases = False, findLets = False, findKinds = [CFun]}
			# (locations, pstate)			= accHeapsProject (GetExprLocations find_exprs hyp.hypProp) pstate
			# (locations, _, pstate)		= check_locations locations hyp.hypProp pstate
			# location						= if (loc == 0) (AllSubExprs) (locations !! (loc-1))
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticIntArithH location ptr mode, pstate)
		
		check_locations :: ![(CName, Int)] !CPropH !*PState -> (![ExprLocation], ![String], !*PState)
		check_locations [(name,index): locations] p pstate
			# location						= SelectedSubExpr name index Nothing
			# (error, (ok, _), pstate)		= accErrorHeapsProject (actOnExprLocation location p ArithInt) pstate
			| isError error					= check_locations locations p pstate
			| not ok						= check_locations locations p pstate
			# (indexes, texts, pstate)		= check_locations locations p pstate
			# text							= "occurrence " +++ toString index +++ " of " +++ name
			= ([SelectedSubExpr name index Nothing:indexes], [text:texts], pstate)
		check_locations [] p pstate
			= ([], [], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyIntCompare :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyIntCompare ptr theorem goal pstate
	# (contradiction, pstate)				= accHeapsProject (CompareInts goal) pstate
	| not contradiction						= showError [X_ApplyTactic "IntCompare" "No contradictory integer comparisons were found."] pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "IntCompare" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			= (True, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticIntCompare, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyMakeUnique :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyMakeUnique ptr theorem goal pstate
	# (goal, pstate)						= accHeaps (FreshVars goal) pstate
	# (ptr_info, pstate)					= accHeaps (GetPtrInfo goal) pstate
	# (ok, pstate)							= accHeaps (MakeUniqueNames ptr_info) pstate
	| not ok								= showError [X_ApplyTactic "MakeUnique" "No duplicate names found in current goal."] pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "MakeUnique" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			= (True, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticMakeUnique, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyManualDefinedness :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyManualDefinedness ptr theorem goal pstate
	# (section_ptrs, pstate)				= pstate!ls.stSections
	# (sections, pstate)					= accHeaps (umap readPointer section_ptrs) pstate
	# sections								= sortBy (\s1-> \s2-> s1.seName < s2.seName) sections
	# (options, names, pstate)				= acc2HeapsProject (find_theorems sections) pstate
	| isEmpty options						= showError [X_ApplyTactic "ManualDefinedness" "Not applicable, because no definedness theorems are available."] pstate
	# (targets, pstate)						= buildTargets goal (current_args names) hyp_args pstate
	= pstate
//	= applyDialog "MoveInCase" ptr theorem targets finish pstate
	where
		find_theorems :: ![Section] !*CHeaps !*CProject -> (![[TheoremPtr]], [String], !*CHeaps, !*CProject)
		find_theorems [section:sections] heaps prj
			# (theorems, names, heaps, prj)	= filter_theorems section.seTheorems heaps prj
//			# section_option				= case theorems of
//												[x:[y:_]]	-> [(theorems, "ALL definedness theorems(" +++ toString (length theorems) +++ ") from section " +++ section.seName)]
//												_			-> []
//			# invidual_options				= zip2
			= ([], [], heaps, prj)
		
		filter_theorems :: ![TheoremPtr] !*CHeaps !*CProject -> (![TheoremPtr], ![String], !*CHeaps, !*CProject)
		filter_theorems [ptr:ptrs] heaps prj
			# (ok, name, _, heaps, prj)		= isManualDefinedness ptr heaps prj
			| not ok						= filter_theorems ptrs heaps prj
			# (ptrs, names, heaps, prj)		= filter_theorems ptrs heaps prj
			= ([ptr:ptrs], [name:names], heaps, prj)
		filter_theorems [] heaps prj
			= ([], [], heaps, prj)
		
		current_args :: ![String] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args theorem_options prop pstate
//			| isEmpty definedness_theorems	= (False, [], pstate)
//			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
//			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases prop) pstate
//			# (_, texts, pstate)			= check_locations locations prop pstate
//			| isEmpty texts					= (False, [], pstate)
//			# (locs, pstate)				= buildPopUpArgument "location" "L" ["?"] 0 pstate
			= (True, /*[locs]*/[], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			= (False, [], pstate)
		
		/*
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [loc] pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases goal.glToProve) pstate
			# (locations, _, pstate)		= check_locations locations goal.glToProve pstate
			# (name, index)					= locations !! loc
			= (OK, TacticMoveInCase name index, pstate)
		finish False ptr [] [loc,mode] pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases hyp.hypProp) pstate
			# (locations, _, pstate)		= check_locations locations hyp.hypProp pstate
			# (name, index)					= locations !! loc
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticMoveInCaseH name index ptr mode, pstate)
		
		check_locations :: ![(CName, Int)] !CPropH !*PState -> (![(CName, Int)], ![String], !*PState)
		check_locations [(name,index): locations] p pstate
			# location						= SelectedSubExpr name index Nothing
			# (error, (ok, _), pstate)		= accErrorHeapsProject (actOnExprLocation location p moveInCase) pstate
			| isError error					= check_locations locations p pstate
			| not ok						= check_locations locations p pstate
			# (locs, texts, pstate)			= check_locations locations p pstate
			# loc							= (name, index)
			# text							= "occurrence " +++ toString index +++ " of " +++ name
			= ([loc:locs], [text:texts], pstate)
		check_locations [] p pstate
			= ([], [], pstate)
	*/

// ------------------------------------------------------------------------------------------------------------------------   
applyMoveInCase :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyMoveInCase ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "MoveInCase" "Not applicable in current goal or any of its hypotheses."] pstate
	= applyDialog "MoveInCase" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# (locs, pstate)				= buildPopUpArgument "location" "L" texts 0 pstate
			= (True, [locs], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# (locs, pstate)				= buildPopUpArgument "location" (foldr (+++) "" texts) texts 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [locs,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [loc] pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases goal.glToProve) pstate
			# (locations, _, pstate)		= check_locations locations goal.glToProve pstate
			# (name, index)					= locations !! loc
			= (OK, TacticMoveInCase name index, pstate)
		finish False ptr [] [loc,mode] pstate
			# funs_cases					= {DummyValue & findVars = False, findCases = False, findLets = False}
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# (locations, pstate)			= accHeapsProject (GetExprLocations funs_cases hyp.hypProp) pstate
			# (locations, _, pstate)		= check_locations locations hyp.hypProp pstate
			# (name, index)					= locations !! loc
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticMoveInCaseH name index ptr mode, pstate)
		
		check_locations :: ![(CName, Int)] !CPropH !*PState -> (![(CName, Int)], ![String], !*PState)
		check_locations [(name,index): locations] p pstate
			# location						= SelectedSubExpr name index Nothing
			# (error, (ok, _), pstate)		= accErrorHeapsProject (actOnExprLocation location p moveInCase) pstate
			| isError error					= check_locations locations p pstate
			| not ok						= check_locations locations p pstate
			# (locs, texts, pstate)			= check_locations locations p pstate
			# loc							= (name, index)
			# text							= "occurrence " +++ toString index +++ " of " +++ name
			= ([loc:locs], [text:texts], pstate)
		check_locations [] p pstate
			= ([], [], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyMoveQuantors :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyMoveQuantors ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Skolemize" "No foralls can be moved in the current goal or any of its hypotheses."] pstate
	= applyDialog "MoveQuantors" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# ((move_in, _), pstate)		= accHeaps (moveQuantors MoveIn prop) pstate
			# ((move_out, _), pstate)		= accHeaps (moveQuantors MoveOut prop) pstate
			| move_in && move_out
				# (direction, pstate)		= buildPopUpArgument "direction" "D0" ["from top-level inwards", "from inwards to top-level"] 0 pstate
				= (True, [direction], pstate)
			| move_in
				# (direction, pstate)		= buildPopUpArgument "direction" "D1" ["from top-level inwards"] 0 pstate
				= (True, [direction], pstate)
			| move_out
				# (direction, pstate)		= buildPopUpArgument "direction" "D2" ["from inwards to top-level"] 0 pstate
				= (True, [direction], pstate)
			= (False, [], pstate)
	
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			# ((move_in, _), pstate)		= accHeaps (moveQuantors MoveIn prop) pstate
			# ((move_out, _), pstate)		= accHeaps (moveQuantors MoveOut prop) pstate
			| move_in && move_out
				# (direction, pstate)		= buildPopUpArgument "direction" "D0" ["from top-level inwards", "from inwards to top-level"] 0 pstate
				= (True, [direction, mode], pstate)
			| move_in
				# (direction, pstate)		= buildPopUpArgument "direction" "D1" ["from top-level inwards"] 0 pstate
				= (True, [direction, mode], pstate)
			| move_out
				# (direction, pstate)		= buildPopUpArgument "direction" "D2" ["from inwards to top-level"] 0 pstate
				= (True, [direction, mode], pstate)
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [direction] pstate
			# ((move_in, _), pstate)		= accHeaps (moveQuantors MoveIn goal.glToProve) pstate
			# ((move_out, _), pstate)		= accHeaps (moveQuantors MoveOut goal.glToProve) pstate
			# direction						= case move_in of
												True	-> case move_out of
															True	-> case direction of
																		0	-> MoveIn
																		1	-> MoveOut
															False	-> MoveIn
												False	-> MoveOut
			= (OK, TacticMoveQuantors direction, pstate)
		finish False ptr [] [direction, mode] pstate
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# ((move_in, _), pstate)		= accHeaps (moveQuantors MoveIn goal.glToProve) pstate
			# ((move_out, _), pstate)		= accHeaps (moveQuantors MoveOut goal.glToProve) pstate
			# direction						= case move_in of
												True	-> case move_out of
															True	-> case direction of
																		0	-> MoveIn
																		1	-> MoveOut
															False	-> MoveIn
												False	-> MoveOut
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticMoveQuantorsH direction ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyOpaque :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyOpaque ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	= applyDialog "Opaque" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args _ pstate
			# (edit, pstate)				= buildEditArgument "function" "F" "" pstate
			= (True, [edit], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [name] [] pstate
			# quaname						= {quaName = name, quaModuleName = Nothing}
			# (mb_ptr, pstate)				= accHeapsProject (BindQualifiedFunction quaname) pstate
			= case mb_ptr of
				Nothing		-> ([X_ApplyTactic "Opaque" "Not a valid function name."], DummyValue, pstate)
				Just ptr	-> (OK, TacticOpaque ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyReduce :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyReduce ptr theorem goal pstate
	# (finfo, pstate)						= makeFormatInfo pstate
	# (targets, pstate)						= buildTargets goal (current_args finfo) (hyp_args finfo) pstate
	| isEmpty targets						= showError [X_ApplyTactic "Reduce" "Nothing to reduce."] pstate
	= applyDialog "Rewrite" ptr theorem targets finish pstate
	where
		current_args :: !FormatInfo !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args finfo prop pstate
			# (texts, _, pstate)			= acc2HeapsProject (findRedexes prop 1 finfo) pstate
			| isEmpty texts					= (False, [], pstate)
			# (amount, pstate)				= buildPopUpArgument "amount" "A" ["to normal form", "to root normal form", "single step"] 0 pstate
			# (locations, pstate)			= accHeapsProject (GetExprLocations DummyValue prop) pstate
			| isEmpty locations				= (False, [], pstate)
			# texts							= ["occurrence " +++ toString i +++ " of " +++ n \\ (n,i) <- locations]
			# texts							= ["all occurrences": texts]
			# (loc, pstate)					= buildPopUpArgument "location" "L" texts 0 pstate
			# (options, pstate)				= pstate!ls.stOptions
			# (special, pstate)				= buildPopUpArgument "special" "S"
												[ "smart, defensive reduction strategy for theorem proving"
												, "smart, offensive reduction strategy for theorem proving"
												, "normal reduction strategy as used in Clean"] 0 pstate
			= (True, [amount,loc,special], pstate)
		
		hyp_args :: !FormatInfo !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args finfo prop pstate
			# (texts, _, pstate)			= acc2HeapsProject (findRedexes prop 1 finfo) pstate
			| isEmpty texts					= (False, [], pstate)
			# (amount, pstate)				= buildPopUpArgument "amount" "A" ["to normal form", "to root normal form", "single step"] 0 pstate
			# (locations, pstate)			= accHeapsProject (GetExprLocations DummyValue prop) pstate
			| isEmpty locations				= (False, [], pstate)
			# texts							= ["occurrence " +++ toString i +++ " of " +++ n \\ (n,i) <- locations]
			# texts							= ["all occurrences": texts]
			# (loc, pstate)					= buildPopUpArgument "location" (foldr (+++) "" texts) texts 0 pstate
			# (options, pstate)				= pstate!ls.stOptions
			# (special, pstate)				= buildPopUpArgument "special" "S"
												[ "smart, defensive reduction strategy for theorem proving"
												, "smart, offensive reduction strategy for theorem proving"
												, "normal reduction strategy as used in Clean"] 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [amount,loc,special,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [amount,loc,special] pstate
			# amount						= case amount of
												0	-> ReduceToNF
												1	-> ReduceToRNF
												2	-> (ReduceExactly 1)
			# (locations, pstate)			= accHeapsProject (GetExprLocations DummyValue goal.glToProve) pstate
			# location						= if (loc == 0) AllSubExprs (make_loc (locations !! (loc-1)))
			# special						= case special of
												0	-> Defensive
												1	-> Offensive
												2	-> AsInClean
			= (OK, TacticReduce special amount location [], pstate)
			where
				make_loc (n,i) = SelectedSubExpr n i Nothing
		finish False ptr [] [amount,loc,special,mode] pstate
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# amount						= case amount of
												0	-> ReduceToNF
												1	-> ReduceToRNF
												2	-> (ReduceExactly 1)
			# (locations, pstate)			= accHeapsProject (GetExprLocations DummyValue hyp.hypProp) pstate
			# location						= if (loc == 0) AllSubExprs (make_loc (locations !! (loc-1)))
			# special						= case special of
												0	-> Defensive
												1	-> Offensive
												2	-> AsInClean
			# mode							= case mode of
												0	-> Implicit
												1	-> Explicit
			= (OK, TacticReduceH special amount location ptr [] mode, pstate)
			where
				make_loc (n,i) = SelectedSubExpr n i Nothing

// ------------------------------------------------------------------------------------------------------------------------   
applyRefineUndefinedness :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyRefineUndefinedness ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "RefineUndefinedness" "Neither the current goal or a hypothesis can be refined."] pstate
	= applyDialog "RefineUndefinedness" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (ok, _, pstate)				= acc2Project (refineUndefinedness prop) pstate
			| not ok						= (False, [], pstate)
			= (True, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (ok, _, pstate)				= acc2Project (refineUndefinedness prop) pstate
			| not ok						= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticRefineUndefinedness, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticRefineUndefinednessH ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyReflexive :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyReflexive ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Reflexive" "Current goal is not a reflexive equality."] pstate
	= applyDialog "Reflexive" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (possible, pstate)			= accHeaps (check prop) pstate
			| not possible					= (False, DummyValue, pstate)
			= (True, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticReflexive, pstate)
		
		check :: !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		check (CExprForall var p) heaps
			= check p heaps
		check (CExprExists var p) heaps
			= check p heaps
		check (CPropForall var p) heaps
			= check p heaps
		check (CPropExists var p) heaps
			= check p heaps
		check (CImplies p q) heaps
			= check q heaps
		check (CEqual e1 e2) heaps
			= AlphaEqual e1 e2 heaps
		check (CIff p q) heaps
			= AlphaEqual p q heaps
		check prop heaps
			= (False, heaps)

// ------------------------------------------------------------------------------------------------------------------------   
applyRemoveCase :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyRemoveCase ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "RemoveCase" "Not applicable in current goal or any of its hypotheses."] pstate
	= applyDialog "RemoveCase" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# cases							= {DummyValue & findVars = False, findCases = True, findLets = False, findKinds = []}
			# (locations, pstate)			= accHeapsProject (GetExprLocations cases prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# (locs, pstate)				= buildPopUpArgument "location" "L" texts 0 pstate
			= (True, [locs], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# cases							= {DummyValue & findVars = False, findCases = True, findLets = False, findKinds = []}
			# (locations, pstate)			= accHeapsProject (GetExprLocations cases prop) pstate
			# (_, texts, pstate)			= check_locations locations prop pstate
			| isEmpty texts					= (False, [], pstate)
			# (locs, pstate)				= buildPopUpArgument "location" (foldr (+++) "" texts) texts 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [locs,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [loc] pstate
			# cases							= {DummyValue & findVars = False, findCases = True, findLets = False, findKinds = []}
			# (locations, pstate)			= accHeapsProject (GetExprLocations cases goal.glToProve) pstate
			# (indexes, _, pstate)			= check_locations locations goal.glToProve pstate
			# index							= indexes !! loc
			= (OK, TacticRemoveCase index, pstate)
		finish False ptr [] [loc,mode] pstate
			# cases							= {DummyValue & findVars = False, findCases = True, findLets = False, findKinds = []}
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# (locations, pstate)			= accHeapsProject (GetExprLocations cases goal.glToProve) pstate
			# (indexes, _, pstate)			= check_locations locations hyp.hypProp pstate
			# index							= indexes !! loc
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticRemoveCaseH index ptr mode, pstate)
		
		check_locations :: ![(CName, Int)] !CPropH !*PState -> (![Int], ![String], !*PState)
		check_locations [(name,index): locations] p pstate
			# location						= SelectedSubExpr name index Nothing
			# (error, (ok, _), pstate)		= accErrorHeapsProject (actOnExprLocation location p removeCase) pstate
			| isError error					= check_locations locations p pstate
			| not ok						= check_locations locations p pstate
			# (indexes, texts, pstate)		= check_locations locations p pstate
			# text							= "occurrence " +++ toString index +++ " of " +++ name
			= ([index:indexes], [text:texts], pstate)
		check_locations [] p pstate
			= ([], [], pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyRename :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyRename ptr theorem goal pstate
	# (evarnames, pstate)					= accHeaps (getPointerNames goal.glExprVars) pstate
	# evars									= zip2 goal.glExprVars evarnames
	# evars									= sortBy (\(_,n1)(_,n2) -> n1 < n2) evars
	# (pvarnames, pstate)					= accHeaps (getPointerNames goal.glPropVars) pstate
	# pvars									= zip2 goal.glPropVars pvarnames
	# pvars									= sortBy (\(_,n1)(_,n2) -> n1 < n2) pvars
	# (hypnames, pstate)					= accHeaps (getPointerNames goal.glHypotheses) pstate
	# hyps									= zip2 goal.glHypotheses hypnames
	# hyps									= sortBy (\(_,n1)(_,n2) -> n1 < n2) hyps
	| isEmpty evars && isEmpty pvars && isEmpty hyps
											= showError [X_ApplyTactic "Rename" "No variables or hypotheses have been introduced."] pstate	
	# (targets, pstate)						= buildTargets goal (current_args evars pvars hyps) no_args pstate
	= applyDialog "Rename" ptr theorem targets (finish (map fst evars) (map fst pvars) (map fst hyps)) pstate
	where
		current_args :: ![(CExprVarPtr, CName)] ![(CPropVarPtr, CName)] ![(HypothesisPtr, CName)] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args evars pvars hyps prop pstate
			# enames						= ["expression variable " +++ name \\ (_, name) <- evars]
			# pnames						= ["proposition-variable " +++ name \\ (_, name) <- pvars]
			# hnames						= ["hypothesis " +++ name \\ (_, name) <- hyps]
			# (item, pstate)				= buildPopUpArgument "item" "I" (enames ++ pnames ++ hnames) 0 pstate
			# (name, pstate)				= buildEditArgument "name" "N" "" pstate
			= (True, [item,name], pstate)
		
		finish :: ![CExprVarPtr] ![CPropVarPtr] ![HypothesisPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish evars pvars hyps True _ [name] [index] pstate
			| name == ""					= ([X_Internal "Invalid (empty) name."], DummyValue, pstate)
			# check							= and [isValidNameChar c \\ c <-: name]
			| not check						= ([X_Internal "Invalid (illegal characters) name."], DummyValue, pstate)
			| index < length evars
				# evar						= evars !! index
				= (OK, TacticRenameE evar name, pstate)
			# index							= index - length evars
			| index < length pvars
				# pvar						= pvars !! index
				= (OK, TacticRenameP pvar name, pstate)
			# index							= index - length pvars
			# hyp							= hyps !! index
			= (OK, TacticRenameH hyp name, pstate)

/*
// ------------------------------------------------------------------------------------------------------------------------   
applyRemoveNotNot :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyRemoveNotNot ptr theorem goal pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	# (text2_id, pstate)					= accPIO openId pstate
	# (hyps_id, pstate)						= accPIO openId pstate
	# to_prove								= notnot goal.glToProve
	# (hyps, pstate)						= accHeaps (find_hyps (reverse goal.glHypotheses)) pstate
	| isEmpty hyps && not to_prove			= ShowError [X_ApplyTactic "RemoveNotNot" "No top-level consecutive nots were found"] id pstate
	= snd (openModalDialog 0 (dialog dialog_id cancel_id text2_id hyps_id to_prove hyps) pstate)
	where
		dialog dialog_id cancel_id text2_id hyps_id to_prove hyps
			= GreenDialog dialog_id cancel_id "RemoveNotNot"
				(     textControl	"(1)"
										[ MarkUpTextColour		(if to_prove Black Grey)
										]
										[]
				  :+: textControl	"Remove two consecutive nots from the current goal"
				  						[ MarkUpTextColour		(if to_prove Black Grey)
				  						]
				  						[]
				  :+: ButtonControl	"Go!"
				  						[ ControlPos			(Right, zero)
				  						, ControlSelectState	(if to_prove Able Unable)
				  						, ControlFunction		(noLS (go1 dialog_id))
				  						]
				  :+: textControl	"(2)"
				  						[ MarkUpTextColour		(if (isEmpty hyps) Grey Black)
				  						]
				  						[ ControlPos			(Left, zero)
				  						]
				  :+: textControl	"Remove two consecutive nots from a hypothesis:"
				  						[ MarkUpTextColour		(if (isEmpty hyps) Grey Black)
				  						]
				  						[ ControlId				text2_id
				  						]
				  :+: textControl	"[use hypothesis]"
				  						[ MarkUpTextColour		(if (isEmpty hyps) Grey Black)
				  						]
				  						[ ControlPos			(Below text2_id, zero)
				  						]
				  :+: PopUpControl	[(name,id) \\ (ptr,name) <- hyps] 1
				  						[ ControlSelectState	(if (isEmpty hyps) Unable Able)
				  						, ControlId				hyps_id
				  						]
				  :+: ButtonControl	"Go!"
				  						[ ControlPos			(Right, zero)
				  						, ControlSelectState	(if (isEmpty hyps) Unable Able)
				  						, ControlFunction		(noLS (go2 hyps dialog_id hyps_id))
				  						]
				)
				[]
		
		notnot :: !CPropH -> Bool
		notnot (CNot (CNot p))				= True
		notnot other						= False
		
		find_hyps :: ![HypothesisPtr] !*CHeaps -> ([(HypothesisPtr,CName)], !*CHeaps)
		find_hyps [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
			| not (notnot hyp.hypProp)		= find_hyps ptrs heaps
			# (hyps, heaps)					= find_hyps ptrs heaps
			= ([(ptr,hyp.hypName):hyps], heaps)
		find_hyps [] heaps
			= ([], heaps) 
		
		go1 :: !Id !*PState -> *PState
		go1 dialog_id pstate
			# tactic						= TacticRemoveNotNot InToProve
			= apply tactic (closeWindow dialog_id pstate)
		
		go2 :: ![(HypothesisPtr, CName)] !Id !Id !*PState -> *PState
		go2 hyps dialog_id hyps_id pstate
			# (mb_wstate, pstate)			= accPIO (getWindow dialog_id) pstate
			| isNothing mb_wstate			= pstate
			# wstate						= fromJust mb_wstate
			# (ok, mb_index)				= getPopUpControlSelection hyps_id wstate
			| not ok || isNothing mb_index	= pstate
			# index							= fromJust mb_index
			# (ptr, name)					= hyps !! (index-1)
			# tactic						= TacticRemoveNotNot (InHypothesis (KnownHypothesis name ptr))
			= apply tactic (closeWindow dialog_id pstate)
*/

// ------------------------------------------------------------------------------------------------------------------------   
applyRewrite :: !(Maybe HypothesisPtr) !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyRewrite mb_ptr ptr theorem goal pstate
	# (hyps, pstate)						= case mb_ptr of
												Nothing		-> accHeaps (find_hyps (reverse goal.glHypotheses)) pstate
												Just ptr	-> let (hyp,pstate`) = accHeaps (readPointer ptr) pstate
																in ([(ptr,hyp.hypName)], pstate`)
	# (theorems, pstate)					= case mb_ptr of
												Nothing		-> allTheorems pstate
												Just ptr	-> ([], pstate)
	# (theorems, pstate)					= accHeaps (find_theorems theorems) pstate
	# theorems								= sortBy (\(_,name1) (_,name2) -> name1 < name2) theorems
	| isEmpty hyps && isEmpty theorems		= showError [X_ApplyTactic "Rewrite" "No hypothesis or theorem can be used as a rewrite-rule."] pstate
	# rule_names							= ["hypothesis " +++ name \\ (ptr, name) <- hyps] ++
											  ["theorem " +++ name \\ (ptr, name) <- theorems]
	# hyp_targets							= case mb_ptr of
												Nothing		-> hyp_args rule_names
												Just ptr	-> no_args
	# (targets, pstate)						= buildTargets goal (current_args rule_names) hyp_targets pstate
	= applyDialog "Rewrite" ptr theorem targets (finish (map fst hyps) (map fst theorems)) pstate
	where
		find_hyps :: ![HypothesisPtr] !*CHeaps -> (![(HypothesisPtr, CName)], !*CHeaps)
		find_hyps [ptr:ptrs] heaps
			# (hyp, heaps)					= readPointer ptr heaps
			| not (is_rule hyp.hypProp)		= find_hyps ptrs heaps
			# (hyps, heaps)					= find_hyps ptrs heaps
			= ([(ptr,hyp.hypName):hyps], heaps)
		find_hyps [] heaps
			= ([], heaps)
				
		find_theorems :: ![TheoremPtr] !*CHeaps -> (![(TheoremPtr, CName)], !*CHeaps)
		find_theorems [ptr:ptrs] heaps
			# (theorem, heaps)				= readPointer ptr heaps
			# is_rule						= is_rule theorem.thInitial
			| not is_rule					= find_theorems ptrs heaps
			# (theorems, heaps)				= find_theorems ptrs heaps
			= ([(ptr,theorem.thName):theorems], heaps)
		find_theorems [] heaps
			= ([], heaps)
		
		is_rule :: !CPropH -> Bool
		is_rule (CExprForall var p)			= is_rule p
		is_rule (CPropForall var p)			= is_rule p
		is_rule (CEqual e1 e2)				= True
		is_rule (CIff p1 p2)				= True
		is_rule other						= False
		
		current_args :: ![String] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args rule_names _ pstate
			# (rules, pstate)				= buildPopUpArgument "rule" "R" rule_names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			# (direction, pstate)			= buildPopUpArgument "direction" "D" ["-> (from left-to-right)", "<- (from right-to-left)"] 0 pstate
			# redex_names					= ["all redexes": ["just the " +++ showNumTh num +++ " redex" \\ num <- [1..25]]]
			# (redex, pstate)				= buildPopUpArgument "redex" "E" redex_names 0 pstate
			= (True, [rules,args,direction,redex], pstate)
		
		hyp_args :: ![String] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args rule_names _ pstate
			# (rules, pstate)				= buildPopUpArgument "rule" "R" rule_names 0 pstate
			# (args, pstate)				= buildEditArgument "applied-to" "A" "" pstate
			# (direction, pstate)			= buildPopUpArgument "direction" "D" ["-> (from left-to-right)", "<- (from right-to-left)"] 0 pstate
			# redex_names					= ["all redexes": ["just the " +++ showNumTh num +++ " redex" \\ num <- [1..25]]]
			# (redex, pstate)				= buildPopUpArgument "redex" "E" redex_names 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [rules,args,direction,redex,mode], pstate)
				
		finish :: ![HypothesisPtr] ![TheoremPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish hyps theorems True _ [args] [fact,direction,redex] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# direction						= if (direction == 0) LeftToRight RightToLeft
			# redex							= if (redex == 0) AllRedexes (OneRedex redex)
			# fact							= if (fact < length hyps)
												 (HypothesisFact (hyps !! fact) args)
												 (TheoremFact (theorems !! (fact - length hyps)) args)
			= (OK, TacticRewrite direction redex fact, pstate)
		finish hyps theorems False ptr [args] [fact,direction,redex,mode] pstate
			# (error, lexemes)				= parseLexemes args
			| isError error					= (error, DummyValue, pstate)
			# (error, pargs)				= parseFactArguments lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, args, pstate)			= accErrorHeapsProject (uumapError (bindFactArgument "Apply" goal) pargs) pstate
			| isError error					= (error, DummyValue, pstate)
			# direction						= if (direction == 0) LeftToRight RightToLeft
			# redex							= if (redex == 0) AllRedexes (OneRedex redex)
			# fact							= if (fact < length hyps)
												 (HypothesisFact (hyps !! fact) args)
												 (TheoremFact (theorems !! (fact - length hyps)) args)
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticRewriteH direction redex fact ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applySpecialize :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applySpecialize ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal no_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Specialize" "None of the hypotheses starts with a FORALL."] pstate
	= applyDialog "Specialize" ptr theorem targets finish pstate
	where
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args (CExprForall var p) pstate
			# (expr, pstate)				= buildEditArgument "expression" "E" "" pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [expr, mode], pstate)
		hyp_args (CPropForall var p) pstate
			# (prop, pstate)				= buildEditArgument "proposition" "P" "" pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [prop, mode], pstate)
		hyp_args _ pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish False ptr [term] [mode] pstate
			# mode							= if (mode==0) Implicit Explicit
			# (hyp, pstate)					= accHeaps (readPointer ptr) pstate
			# (expr_mode, prop_mode)		= find_mode hyp.hypProp
			| expr_mode
				# (error, lexemes)			= parseLexemes term
				| isError error				= (error, DummyValue, pstate)
				# (error, expr)				= parseExpression lexemes
				| isError error				= (error, DummyValue, pstate)
				# (error, expr, pstate)		= accErrorHeapsProject (bindRelativeExpr expr goal) pstate
				| isError error				= (error, DummyValue, pstate)
				= (OK, TacticSpecializeE ptr expr mode, pstate)
			| prop_mode
				# (error, lexemes)			= parseLexemes term
				| isError error				= (error, DummyValue, pstate)
				# (error, prop)				= parseProposition lexemes
				| isError error				= (error, DummyValue, pstate)
				# (error, prop, pstate)		= accErrorHeapsProject (bindRelativeProp prop goal) pstate
				| isError error				= (error, DummyValue, pstate)
				= (OK, TacticSpecializeP ptr prop mode, pstate)
			= undef
			where
				find_mode :: !CPropH -> (!Bool, !Bool)
				find_mode (CExprForall _ _)	= (True, False)
				find_mode (CPropForall _ _)	= (False, True)

// ------------------------------------------------------------------------------------------------------------------------   
applySplit :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applySplit ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Split" "Neither the goal or a hypothesis is a conjunction."] pstate
	= applyDialog "Split" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args (CAnd p q) pstate
			# (depth, pstate)				= case (is_and p || is_and q) of
												True	-> buildPopUpArgument "depth" "D1" ["shallow (only top-level ands)", "deep (all ands)"] 0 pstate
												False	-> buildPopUpArgument "depth" "D2" ["shallow (only top-level ands)"] 0 pstate
			= (True, [depth], pstate)
		current_args _ pstate
			= (False, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args (CAnd p q) pstate
			# (depth, pstate)				= case (is_and p || is_and q) of
												True	-> buildPopUpArgument "depth" "D1" ["shallow (only top-level ands)", "deep (all ands)"] 0 pstate
												False	-> buildPopUpArgument "depth" "D2" ["shallow (only top-level ands)"] 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [depth,mode], pstate)
		hyp_args _ pstate
			= (False, [], pstate)
		
		is_and :: !CPropH -> Bool
		is_and (CAnd p q)					= True
		is_and _							= False
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [depth] pstate
			# depth							= if (depth == 0) Shallow Deep
			= (OK, TacticSplit depth, pstate)
		finish False ptr [] [depth,mode] pstate
			# depth							= if (depth == 0) Shallow Deep
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticSplitH ptr depth mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applySplitCase :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applySplitCase ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "SplitCase" "No cases found in current goal."] pstate
	= applyDialog "SplitCase" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# cases							= {DummyValue & findVars = False, findCases = True, findLets = False, findKinds = []}
			# (locations, pstate)			= accHeapsProject (GetExprLocations cases prop) pstate
			# numbers						= [1..length locations]
			| isEmpty numbers				= (False, [], pstate)
			# (cases, pstate)				= buildPopUpArgument "case#" "c" (map toString numbers) 0 pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (introduce conditions as hypotheses)", "explicit (introduce conditions in current goal)"] 0 pstate
			= (True, [cases,mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [casenum,mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticSplitCase (casenum+1) mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applySplitIff :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applySplitIff ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Split" "Neither the goal or a hypothesis is a <-> statement."] pstate
	= applyDialog "SplitIff" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args (CIff p q) pstate
			= (True, [], pstate)
		current_args _ pstate
			= (False, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args (CIff p q) pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [mode], pstate)
		hyp_args _ pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticSplitIff, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticSplitIffH ptr mode, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applySymmetric :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applySymmetric ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Symmetric" "Current goal is not an equality."] pstate
	= applyDialog "Symmetric" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# possible						= check prop
			| not possible					= (False, DummyValue, pstate)
			= (True, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# possible						= check prop
			| not possible					= (False, DummyValue, pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal"] 0 pstate
			= (True, [mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticSymmetric, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode==0) Implicit Explicit
			= (OK, TacticSymmetricH ptr mode, pstate)
		
		check :: !CPropH -> Bool
		check (CExprForall var p)			= check p
		check (CExprExists var p)			= check p
		check (CPropForall var p)			= check p
		check (CPropExists var p)			= check p
		check (CImplies p q)				= check q
		check (CEqual e1 e2)				= True
		check (CIff p q)					= True
		check (CNot p)						= check p
		check prop							= False

// ------------------------------------------------------------------------------------------------------------------------   
applyTransitive :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyTransitive ptr theorem goal pstate
	# (emode, pmode)						= check goal.glToProve
	# (targets, pstate)						= buildTargets goal (current_args emode pmode) no_args pstate
	= applyDialog "Transitive" ptr theorem targets (finish emode pmode) pstate
	where
		current_args :: !Bool !Bool !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args True _ prop pstate
			# (expr, pstate)				= buildEditArgument "expression" "E" "" pstate
			= (True, [expr], pstate)
		current_args _ True prop pstate
			# (prop, pstate)				= buildEditArgument "proposition" "P" "" pstate
			= (True, [prop], pstate)
		current_args _ _ prop pstate
			= (False, [], pstate)
		
		finish :: !Bool !Bool !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ True _ [expr_text] [] pstate
			# (error, lexemes)				= parseLexemes expr_text
			| isError error					= (error, DummyValue, pstate)
			# (error, expr)					= parseExpression lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, expr, pstate)			= accErrorHeapsProject (bindRelativeExpr expr goal) pstate
			| isError error					= (error, DummyValue, pstate)
			= (OK, TacticTransitiveE expr, pstate)
		finish _ True True _ [prop_text] [] pstate
			# (error, lexemes)				= parseLexemes prop_text
			| isError error					= (error, DummyValue, pstate)
			# (error, prop)					= parseProposition lexemes
			| isError error					= (error, DummyValue, pstate)
			# (error, prop, pstate)			= accErrorHeapsProject (bindRelativeProp prop goal) pstate
			| isError error					= (error, DummyValue, pstate)
			= (OK, TacticTransitiveP prop, pstate)
		
		check :: !CPropH -> (!Bool, !Bool)
		check (CEqual e1 e2)				= (True, False)
		check (CIff p q)					= (False, True)
		check _								= (False, False)

// ------------------------------------------------------------------------------------------------------------------------   
applyTransparent :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyTransparent ptr theorem goal pstate
	| isEmpty goal.glOpaque					= showError [X_ApplyTactic "Transparent" "No opaque identifiers to be made transparent."] pstate
	# (_, names, pstate)					= accErrorHeapsProject (uumapError getDefinitionName goal.glOpaque) pstate
	# names_ptrs							= sortBy (\(n1,p1)(n2,p2) -> n1 < n2) (zip2 names goal.glOpaque)
	# (targets, pstate)						= buildTargets goal (current_args (map fst names_ptrs)) no_args pstate
	= applyDialog "Transparent" ptr theorem targets (finish (map snd names_ptrs)) pstate
	where
		current_args :: ![CName] !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args names _ pstate
			# (function, pstate)			= buildPopUpArgument "function" "F" names 1 pstate
			= (True, [function], pstate)
		
		finish :: ![HeapPtr] !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish ptrs True _ [] [index] pstate
			# ptr							= ptrs !! index
			= (OK, TacticTransparent ptr, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyTrivial :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyTrivial ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args no_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Trivial" "Current goal is not equal to TRUE"] pstate
	= applyDialog "Trivial" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args (CExprForall _ p) pstate
			= current_args p pstate
		current_args (CExprExists _ p) pstate
			= current_args p pstate
		current_args (CPropForall _ p) pstate
			= current_args p pstate
		current_args (CPropExists _ p) pstate
			= current_args p pstate
		current_args (CImplies p q) pstate
			= current_args q pstate
		current_args CTrue pstate
			= (True, [], pstate)
		current_args _ pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticTrivial, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyUndo :: !Proof !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyUndo proof pstate
	| isEmpty proof.pLeafs					= showError [X_ApplyTactic "Undo" "Undo on a finished proof is ambiguous."] pstate
	# (finfo, pstate)						= makeFormatInfo pstate
	# (error, ftexts, pstate)				= acc2HeapsProject (findPathPtr [] proof.pTree proof.pCurrentLeaf finfo) pstate
	| isError error							= showError error pstate
	| isEmpty ftexts						= showError [X_ApplyTactic "Undo" "Nothing to undo"] pstate
	# (error, fgoal, pstate)				= accErrorHeapsProject (FormattedShow finfo proof.pCurrentGoal.glToProve) pstate
	| isError error							= showError error pstate
	# ftexts								= ftexts ++ [removeCmLink fgoal]
	# (dialog_id, pstate)					= accPIO openId pstate
	# (dialog_rid, pstate)					= accPIO openRId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	# (undo_rid, pstate)					= accPIO openRId pstate
	# (go_id, pstate)						= accPIO openId pstate
	# (courier_height, pstate)				= pstate!ls.stFontsPresent.fpCourierHeight
	= snd (openModalDialog 1 (dialog dialog_id dialog_rid cancel_id undo_rid go_id ftexts courier_height) pstate)
	where
		dialog dialog_id dialog_rid cancel_id undo_rid go_id ftexts courier_height
			= GreenDialog dialog_id cancel_id "Undo"
					(     Receiver			dialog_rid set_selected
												[]
					  :+: textControl		"Select which goal in the path to the current goal to go back to:"
												[]
												[]
					  :+: CompoundControl (
					      MarkUpControl		(withNumbers 1 (length ftexts-1) ftexts)
					  							[ MarkUpFontFace			"Courier New"
					  							, MarkUpTextSize			10
					  							, MarkUpBackgroundColour	LightGreen
					  							, MarkUpLinkStyle			False Grey LightGreen False Grey Yellow
					  							, MarkUpWidth				500
					  							, MarkUpNrLines				10
					  							, MarkUpHScroll
					  							, MarkUpVScroll
					  							, MarkUpReceiver			undo_rid
					  							, MarkUpEventHandler		(clickHandler (eventHandler dialog_rid undo_rid ftexts))
					  							]
					  							[]
					  					   )	[ ControlLook				True (\_ {newFrame} -> seq [setPenColour Black, draw newFrame])
					  					   		, ControlPos				(Left, zero)
					  					   		, ControlHMargin			1 1
					  					   		, ControlVMargin			1 1
					  					   		]
					  :+: ButtonControl		"Go!"
					  							[ ControlPos				(Right, zero)
					  							, ControlId					go_id
					  							, ControlFunction			(undo dialog_id)
					  							]
					)
					[ WindowInit			(noLS (jumpToMarkUpLabel undo_rid "@LastScreen"))
					]
		
		set_selected :: !Int !(!Int, !*PState) -> (!Int, !*PState)
		set_selected selected (_, pstate)
			= (selected, pstate)
	
		findPathPtr :: [MarkUpText Int] !ProofTreePtr !ProofTreePtr !FormatInfo !*CHeaps !*CProject -> (!Error, [MarkUpText Int], !*CHeaps, !*CProject)
		findPathPtr ftexts current dst finfo heaps prj
			| current == dst				= (OK, ftexts, heaps, prj)
			# (node, heaps)					= readPointer current heaps
			= findPath ftexts node dst finfo heaps prj
		
		findPathPtrs :: [MarkUpText Int] ![ProofTreePtr] !ProofTreePtr !FormatInfo !*CHeaps !*CProject -> (!Error, [MarkUpText Int], !*CHeaps, !*CProject)
		findPathPtrs ftexts [current:currents] dst finfo heaps prj
			# (error, ftexts`, heaps, prj)	= findPathPtr ftexts current dst finfo heaps prj
			| isOK error
				= (OK, ftexts`, heaps, prj)
				= findPathPtrs ftexts currents dst finfo heaps prj
		findPathPtrs ftexts [] dst finfo heaps prj
			= (pushError (X_Internal "") OK, DummyValue, heaps, prj)
		
		findPath :: [MarkUpText Int] !ProofTree !ProofTreePtr !FormatInfo !*CHeaps !*CProject -> (!Error, [MarkUpText Int], !*CHeaps, !*CProject)
		findPath ftexts (ProofLeaf goal) dst finfo heaps prj
			= (pushError (X_Internal "") OK, DummyValue, heaps, prj)
		findPath ftexts (ProofNode Nothing _ _) dst finfo heaps prj
			= (pushError (X_Internal "Cannot undo when no intermediate goals are stored") OK, DummyValue, heaps, prj)
		findPath ftexts (ProofNode (Just goal) tactic children) dst finfo heaps prj
			# (error, ftexts, heaps, prj)	= findPathPtrs ftexts children dst finfo heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			# (error, ftactic, heaps, prj)	= FormattedShow finfo tactic heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			# ftactic						= removeCmLink ftactic
			# ftactic						= [CmBackgroundColour LighterGreen, CmSize 7, CmColour Brown, CmText " ||   ", CmAlign "goal", CmText "{", CmEndColour: ftactic] ++ [CmColour Brown, CmText "}", CmEndColour, CmEndSize, CmFillLine, CmEndBackgroundColour]
			# (error, fgoal, heaps, prj)	= FormattedShow finfo goal.glToProve heaps prj
			| isError error					= (error, DummyValue, heaps, prj)
			# fgoal							= removeCmLink fgoal
			# ftext							= fgoal ++ [CmNewline] ++ ftactic ++ [CmNewline]
			= (OK, [ftext:ftexts], heaps, prj)
		
		withNumbers :: !Int !Int ![MarkUpText Int] -> MarkUpText Int
		withNumbers selected num [ftext:ftexts]
			| selected == num
				=	[ CmBText				"[X]"
					, CmText				" "
					, CmAlign				"goal"
					: ftext
					] ++ withNumbers selected (num-1) ftexts
				=	[ CmBold
					, CmLink 				"[ ]" num
					, CmEndBold
					, CmText				" "
					, CmAlign				"goal"
					: ftext
					] ++ withNumbers selected (num-1) ftexts
		withNumbers _ _ []
			= []
		
		eventHandler :: !(RId Int) !(RId (MarkUpMessage Int)) ![MarkUpText Int] !Int !*PState -> *PState
		eventHandler dialog_rid undo_rid ftexts selected pstate
			# ftext						 	= withNumbers selected (length ftexts-1) ftexts
			# pstate						= changeMarkUpText undo_rid ftext pstate
			# pstate						= snd (asyncSend dialog_rid selected pstate)
			= pstate
		
		undo :: !Id !(!Int, !*PState) -> (!Int, !*PState)
		undo own_id (count, pstate)
			# (opened, pstate)				= isWindowOpened (WinProof nilPtr) False pstate
			| not opened					= (count, pstate)
			# (winfo, pstate)				= get_Window (WinProof nilPtr) pstate
			# (_, pstate)					= asyncSend (fromJust winfo.wiNormalRId) (CmdUndoTactics count) pstate
			= (count, closeWindow own_id pstate)

// ------------------------------------------------------------------------------------------------------------------------   
applyUncurry :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyUncurry ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Uncurry" "Nothing to uncurry in current goal or any of its hypotheses."] pstate
	= applyDialog "Uncurry" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (error, (ok, _), pstate)		= accErrorHeapsProject (recurse ncurry prop) pstate
			| isError error					= (False, [], pstate)
			| not ok						= (False, [], pstate)
			= (True, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (error, (ok, _), pstate)		= accErrorHeapsProject (recurse ncurry prop) pstate
			| isError error					= (False, [], pstate)
			| not ok						= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [mode], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [] [] pstate
			= (OK, TacticUncurry, pstate)
		finish False ptr [] [mode] pstate
			# mode							= if (mode == 0) Implicit Explicit
			= (OK, TacticUncurryH ptr mode, pstate)

:: VarOption = {voVarName :: !CName, voLetIndex :: !Int, voName :: !String}
// ------------------------------------------------------------------------------------------------------------------------   
applyUnshare :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyUnshare ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Unshare" "No let in current goal or any of its hypotheses."] pstate
	= applyDialog "Unshare" ptr theorem targets (finish theorem.thProof.pCurrentGoal) pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args prop pstate
			# (varoptions, pstate)			= accHeapsProject (search_prop prop) pstate
			| isEmpty varoptions			= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["remove let binding afterwards", "do not remove let binding afterwards"] 0 pstate
			# (var, pstate)					= buildPopUpArgument "var" "V" (map (\x->x.voName) varoptions) 0 pstate
			# (varl, pstate)				= buildPopUpArgument "location" "L" ["All","1","2","3","4","5","6"] 0 pstate
			= (True, [mode,var,varl], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args prop pstate
			# (varoptions, pstate)			= accHeapsProject (search_prop prop) pstate
			| isEmpty varoptions			= (False, [], pstate)
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["remove let binding afterwards", "do not remove let binding afterwards"] 0 pstate
			# (var, pstate)					= buildPopUpArgument "var" "V" (map (\x->x.voName) varoptions) 0 pstate
			# (varl, pstate)				= buildPopUpArgument "location" "L" ["All","1","2","3","4","5","6"] 0 pstate
			= (True, [mode,var,varl], pstate)
		
		finish :: !Goal !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish goal True hyp_ptr [] [mode,var,varl] pstate
			# mode							= mode == 0
			# (varoptions, pstate)			= accHeapsProject (search_prop goal.glToProve) pstate
			# varoption						= varoptions !! var
			# varl							= if (varl == 0) AllVars (JustVarIndex varl)
			= (OK, TacticUnshare mode varoption.voLetIndex varoption.voVarName varl, pstate)
		finish goal False hyp_ptr [] [mode,var,varl] pstate
			# mode							= mode == 0
			# (hyp, pstate)					= accHeaps (readPointer hyp_ptr) pstate
			# (varoptions, pstate)			= accHeapsProject (search_prop hyp.hypProp) pstate
			# varoption						= varoptions !! var
			# varl							= if (varl == 0) AllVars (JustVarIndex varl)
			= (OK, TacticUnshareH mode varoption.voLetIndex varoption.voVarName varl hyp_ptr, pstate)
		
		search_prop :: !CPropH !*CHeaps !*CProject -> (![VarOption], !*CHeaps, !*CProject)
		search_prop prop heaps prj
			# (locs, heaps, prj)			= GetExprLocations {findVars=False, findCases=False, findLets=True, findKinds=[]} prop heaps prj
			= search_locs locs prop heaps prj
		
		search_locs :: ![(CName, Int)] !CPropH !*CHeaps !*CProject -> (![VarOption], !*CHeaps, !*CProject)
		search_locs [(_,let_index): locs] prop heaps prj
			# (ok, expr, heaps, prj)		= getExprOnLocationInProp "let" let_index prop heaps prj
			| not ok						= search_locs locs prop heaps prj
			# (varoptions1, heaps, prj)		= search_expr let_index expr heaps prj
			# (varoptions2, heaps, prj)		= search_locs locs prop heaps prj
			= (varoptions1 ++ varoptions2, heaps, prj)
		search_locs [] prop heaps prj
			= ([], heaps, prj)
		
		search_expr :: !Int !CExprH !*CHeaps !*CProject -> (![VarOption], !*CHeaps, !*CProject)
		search_expr let_index (CLet False defs _) heaps prj
			= build_options let_index defs heaps prj
		search_expr let_index _ heaps prj
			= ([], heaps, prj)
		
		build_options :: !Int ![(CExprVarPtr, CExprH)] !*CHeaps !*CProject -> (![VarOption], !*CHeaps, !*CProject)
		build_options let_index [(ptr, _): defs] heaps prj
			# (var, heaps)					= readPointer ptr heaps
			# varoption						=	{ voVarName					= var.evarName
												, voLetIndex				= let_index
												, voName					= "variable '" +++ var.evarName +++ "' in let " +++ toString let_index
												}
			# (varoptions, heaps, prj)		= build_options let_index defs heaps prj
			= ([varoption: varoptions], heaps, prj)
		build_options let_index [] heaps prj
			= ([], heaps, prj)

// ------------------------------------------------------------------------------------------------------------------------   
applyWitness :: !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyWitness ptr theorem goal pstate
	# (targets, pstate)						= buildTargets goal current_args hyp_args pstate
	| isEmpty targets						= showError [X_ApplyTactic "Witness" "Neither the current goal or any hypothesis starts with an existential quantor."] pstate
	= applyDialog "Witness" ptr theorem targets finish pstate
	where
		current_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		current_args (CExprExists _ _) pstate
			# (witness, pstate)				= buildEditArgument "witness" "W" "" pstate
			= (True, [witness], pstate)
		current_args (CPropExists _ _) pstate
			# (witness, pstate)				= buildEditArgument "witness" "W" "" pstate
			= (True, [witness], pstate)
		current_args _ pstate
			= (False, [], pstate)
		
		hyp_args :: !CPropH !*PState -> (!Bool, ![Argument], !*PState)
		hyp_args (CExprExists _ _) pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [mode], pstate)
		hyp_args (CPropExists _ _) pstate
			# (mode, pstate)				= buildPopUpArgument "mode" "M" ["implicit (replace hypothesis)", "explicit (introduce in current goal)"] 0 pstate
			= (True, [mode], pstate)
		hyp_args other pstate
			= (False, [], pstate)
		
		finish :: !Bool !HypothesisPtr ![String] ![Int] !*PState -> (!Error, !TacticId, !*PState)
		finish True _ [witness] [] pstate
			# (error, lexemes)				= parseLexemes witness
			| isError error					= (error, DummyValue, pstate)
			| is_expr_exists goal.glToProve
				# (error, expr)				= parseExpression lexemes
				| isError error				= (error, DummyValue, pstate)
				# (error, expr, pstate)		= acc2HeapsProject (bindRelativeExpr expr goal) pstate
				| isError error				= (error, DummyValue, pstate)
				= (OK, TacticWitnessE expr, pstate)
			| is_prop_exists goal.glToProve
				# (error, prop)				= parseProposition lexemes
				| isError error				= (error, DummyValue, pstate)
				# (error, prop, pstate)		= acc2HeapsProject (bindRelativeProp prop goal) pstate
				| isError error				= (error, DummyValue, pstate)
				= (OK, TacticWitnessP prop, pstate)
			= (pushError (X_Internal "Impossible case; goal isn't exists after all??") OK, DummyValue, pstate)
			where
				is_expr_exists :: !CPropH -> Bool
				is_expr_exists (CExprExists _ _)	= True
				is_expr_exists _					= False

				is_prop_exists :: !CPropH -> Bool
				is_prop_exists (CPropExists _ _)	= True
				is_prop_exists _					= False
		finish False ptr [] [mode] pstate
			| mode == 0						= (OK, TacticWitnessH ptr Implicit, pstate)
			| mode == 1						= (OK, TacticWitnessH ptr Explicit, pstate)





















// ------------------------------------------------------------------------------------------------------------------------   
applyName :: !String !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
applyName name ptr theorem goal pstate
	# (busy, pstate)							= pstate!ls.stBusyProving
	| busy										= pstate
	= apply_name name goal pstate
	where
		apply_name "Absurd" goal pstate					= applyAbsurd ptr theorem goal pstate
		apply_name "AbsurdEquality" goal pstate			= applyAbsurdEquality ptr theorem goal pstate
		apply_name "Apply" goal pstate					= applyApply Nothing ptr theorem goal pstate
		apply_name "Assume" goal pstate					= applyAssume ptr theorem goal pstate
		apply_name "Case" goal pstate					= applyCase ptr theorem goal pstate
		apply_name "Cases" goal pstate					= applyCases ptr theorem goal pstate
		apply_name "ChooseCase" goal pstate				= applyChooseCase ptr theorem goal pstate
		apply_name "Compare" goal pstate				= applyCompare ptr theorem goal pstate
		apply_name "Contradiction" goal pstate			= applyContradiction ptr theorem goal pstate
		apply_name "Cut" goal pstate					= applyCut ptr theorem goal pstate
		apply_name "Definedness" goal pstate			= applyDefinedness ptr theorem goal pstate
		apply_name "Discard" goal pstate				= applyDiscard ptr theorem goal pstate
		apply_name "Exact" goal pstate					= applyExact ptr theorem goal pstate
		apply_name "ExFalso" goal pstate				= applyExFalso ptr theorem goal pstate
		apply_name "ExpandFun" goal pstate				= applyExpandFun ptr theorem goal pstate
		apply_name "Extensionality" goal pstate			= applyExtensionality ptr theorem goal pstate
		apply_name "Generalize" goal pstate				= applyGeneralize ptr theorem goal pstate
		apply_name "Induction" goal pstate				= applyInduction ptr theorem goal pstate
		apply_name "Injective" goal pstate				= applyInjective ptr theorem goal pstate
		apply_name "Introduce" goal pstate				= applyIntroduce ptr theorem goal pstate
		apply_name "IntArith" goal pstate				= applyIntArith ptr theorem goal pstate
		apply_name "IntCompare" goal pstate				= applyIntCompare ptr theorem goal pstate
		apply_name "MakeUnique" goal pstate				= applyMakeUnique ptr theorem goal pstate
		apply_name "ManualDefinedness" goal pstate		= applyManualDefinedness ptr theorem goal pstate
		apply_name "MoveInCase" goal pstate				= applyMoveInCase ptr theorem goal pstate
		apply_name "MoveQuantors" goal pstate			= applyMoveQuantors ptr theorem goal pstate
		apply_name "Opaque" goal pstate					= applyOpaque ptr theorem goal pstate
		apply_name "Reduce" goal pstate					= applyReduce ptr theorem goal pstate
		apply_name "RefineUndefinedness" goal pstate	= applyRefineUndefinedness ptr theorem goal pstate
		apply_name "Reflexive" goal pstate				= applyReflexive ptr theorem goal pstate
		apply_name "RemoveCase" goal pstate				= applyRemoveCase ptr theorem goal pstate
		apply_name "Rename" goal pstate					= applyRename ptr theorem goal pstate
		apply_name "Rewrite" goal pstate				= applyRewrite Nothing ptr theorem goal pstate
		apply_name "Specialize" goal pstate				= applySpecialize ptr theorem goal pstate
		apply_name "Split" goal pstate					= applySplit ptr theorem goal pstate
		apply_name "SplitCase" goal pstate				= applySplitCase ptr theorem goal pstate
		apply_name "SplitIff" goal pstate				= applySplitIff ptr theorem goal pstate
		apply_name "Symmetric" goal pstate				= applySymmetric ptr theorem goal pstate
		apply_name "Transitive" goal pstate				= applyTransitive ptr theorem goal pstate
		apply_name "Transparent" goal pstate			= applyTransparent ptr theorem goal pstate
		apply_name "Trivial" goal pstate				= applyTrivial ptr theorem goal pstate
		apply_name "Uncurry" goal pstate				= applyUncurry ptr theorem goal pstate
		apply_name "Unshare" goal pstate				= applyUnshare ptr theorem goal pstate
		apply_name "Witness" goal pstate				= applyWitness ptr theorem goal pstate
		apply_name _ goal pstate						= pstate


























/*
// ------------------------------------------------------------------------------------------------------------------------   
useHypothesis :: !HypothesisPtr !TheoremPtr !Theorem !Goal !*PState -> *PState
// ------------------------------------------------------------------------------------------------------------------------   
useHypothesis hyp_ptr ptr theorem goal pstate
	# (hyp, pstate)								= accHeaps (readPointer hyp_ptr) pstate
	# (ok, tactic, pstate)						= maybeImmediate hyp_ptr hyp.hypProp goal pstate
	| ok										= applyToDialog ptr theorem tactic pstate
	# (rewrite, apply)							= is_rule hyp.hypProp
	| rewrite									= applyRewrite (Just hyp_ptr) ptr theorem goal pstate
	| apply										= applyApply (Just hyp_ptr) ptr theorem goal pstate
	= pstate
	where
		is_rule :: !CPropH -> (!Bool, !Bool)
		is_rule (CExprForall var p)
			= is_rule p
		is_rule (CPropForall var p)
			= is_rule p
		is_rule (CImplies p q)
			# (rewrite, apply)					= is_rule q
			| rewrite							= (rewrite, False)
			= (False, True)
		is_rule (CEqual e1 e2)
			= (True, False)
		is_rule (CIff p1 p2)
			= (True, False)
		is_rule other
			= (False, False)

// ------------------------------------------------------------------------------------------------------------------------   
maybeImmediate :: !HypothesisPtr !CPropH !Goal !*PState -> (!Bool, !TacticId, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
maybeImmediate hyp_ptr prop goal pstate
	= try	[ maybeAbsurd
			, maybeAbsurdEquality
			, maybeExact
			, maybeExFalso
			] pstate
	where
		try :: ![HypothesisPtr -> CPropH -> Goal -> *(*PState -> (Bool, TacticId, *PState))] !*PState -> (!Bool, !TacticId, !*PState)
		try [fun: funs] pstate
			# (ok, tactic, pstate)				= fun hyp_ptr prop goal pstate
			| ok								= (True, tactic, pstate)
			= try funs pstate
		try [] pstate
			= (False, DummyValue, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
maybeAbsurd :: !HypothesisPtr !CPropH !Goal !*PState -> (!Bool, !TacticId, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
maybeAbsurd ptr prop goal pstate
	# ptrs										= goal.glHypotheses
	= acc2Heaps (check ptr prop ptrs) pstate
	where
		check :: !HypothesisPtr !CPropH ![HypothesisPtr] !*CHeaps -> (!Bool, !TacticId, !*CHeaps)
		check ptr prop [hyp_ptr: hyp_ptrs] heaps
			# (hyp, heaps)						= readPointer hyp_ptr heaps
			# (ok, heaps)						= contradict prop hyp.hypProp heaps
			| ok								= (True, TacticAbsurd ptr hyp_ptr, heaps)
			= check ptr prop hyp_ptrs heaps
		check ptr prop [] heaps
			= (False, DummyValue, heaps)
		
		contradict :: !CPropH !CPropH !*CHeaps -> (!Bool, !*CHeaps)
		contradict (CNot p) (CNot q) heaps
			= contradict p q heaps
		contradict (CNot p) q heaps
			= AlphaEqual p q heaps
		contradict p (CNot q) heaps
			= AlphaEqual p q heaps
		contradict p q heaps
			= (False, heaps)

// ------------------------------------------------------------------------------------------------------------------------   
maybeAbsurdEquality :: !HypothesisPtr !CPropH !Goal !*PState -> (!Bool, !TacticId, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
maybeAbsurdEquality ptr prop goal pstate
	# (ok, pstate)								= accProject (absurd_equality False prop) pstate
	| ok										= (True, TacticAbsurdEqualityH ptr, pstate)
	= (False, DummyValue, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
maybeExact :: !HypothesisPtr !CPropH !Goal !*PState -> (!Bool, !TacticId, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
maybeExact ptr prop goal pstate
	# (ok, pstate)								= accHeaps (AlphaEqual prop goal.glToProve) pstate
	| ok										= (True, TacticExact (HypothesisFact ptr []), pstate)
	= (False, DummyValue, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
maybeExFalso :: !HypothesisPtr !CPropH !Goal !*PState -> (!Bool, !TacticId, !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
maybeExFalso ptr CFalse goal pstate
	= (True, TacticExFalso ptr, pstate)
maybeExFalso ptr _ goal pstate
	= (False, DummyValue, pstate)
*/