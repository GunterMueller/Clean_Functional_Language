/*
** Program: Clean Prover System
** Module:  States (.icl)
** 
** Author:  Maarten de Mol
** Created: 14 September 1999
*/

implementation module 
	States

import 
	StdEnv,
	StdIO,
	ossystem,
	CoreTypes,
	ProveTypes,
	Parser,
	FormattedShow

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: Action =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  AddedCleanModules				![ModulePtr]
	| ChangedDisplayOption
	| ChangedProof					!TheoremPtr
	| ChangedProofStatus			!TheoremPtr
	| ChangedSubgoal				!TheoremPtr
	| CreatedSection
	| CreatedTheorem				!TheoremPtr
	| MovedTheorem					!TheoremPtr !SectionPtr
	| RemovedCleanModules			![ModulePtr]
	| RemovedSection				!SectionPtr
	| RemovedTheorem				!TheoremPtr
	| RenamedSection				!SectionPtr
	| RenamedTheorem				!TheoremPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------
AlmostWhite			:== RGB {r=237,g=237,b=255}
AlmostWhiteHilite	:== RGB {r=180,g=180,b=255}
// -------------------------------------------------------------------------------------------------------------------------------------------------

// ------------------------------------------------------------------------------------------------------------------------   
:: DefinednessInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{ definedExpressions			:: ![CExprH]
	, definedVariables				:: ![CExprVarPtr]
	, undefinedExpressions			:: ![CExprH]
	, undefinedVariables			:: ![CExprVarPtr]
	}
instance DummyValue DefinednessInfo
	where DummyValue	=	{ definedExpressions		= []
							, definedVariables			= []
							, undefinedExpressions		= []
							, undefinedVariables		= []
							}

// ------------------------------------------------------------------------------------------------------------------------   
:: DefinitionFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ dfKind					:: !DefinitionKind
	, dfName					:: !NameFilter
	, dfModules					:: ![ModulePtr]							// use nilPtr for Predefined
	, dfUsing					:: ![String]
	}
instance == DefinitionFilter
	where (==) f1 f2
			# (has_nil1, list1)			= remove_nil f1.dfModules
			# (has_nil2, list2)			= remove_nil f2.dfModules
			=		(f1.dfKind == f2.dfKind)
				&&	(f1.dfName == f2.dfName)
				&&	(has_nil1 == has_nil2)
				&&	(listsEqual list1 list2)
				&&	(f1.dfUsing == f2.dfUsing)
			where
				remove_nil :: ![ModulePtr] -> (!Bool, ![ModulePtr])
				remove_nil [ptr:ptrs]
					| isNilPtr ptr			= (True, ptrs)
					# (found, ptrs)			= remove_nil ptrs
					= (found, [ptr:ptrs])
				remove_nil []
					= (False, [])

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FontsPresent =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fpSymbol				:: !Bool
	, fpVdm					:: !Bool
	, fpWebdings			:: !Bool
	, fpCourierHeight		:: !Int
	}
instance DummyValue FontsPresent
	where DummyValue = {fpSymbol = False, fpVdm = False, fpWebdings = False, fpCourierHeight = 0}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: HintTheorem =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ hintPointer			:: !TheoremPtr
	, hintProp				:: !CPropH
	, hintApplyScore		:: !Int
	, hintApplyForwardScore	:: !Int
	, hintRewriteLRScore	:: !Int
	, hintRewriteRLScore	:: !Int
	}

// ------------------------------------------------------------------------------------------------------------------------   
:: MenuInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{ interpreter_id			:: Id						// initialized at undef!
	, open_project_id			:: Id						// initialized at undef!
	, add_stdenv_id				:: Id						// initialized at undef!
	, project_center_id			:: Id						// initialized at undef!
	, remove_modules_id			:: Id						// initialized at undef!
	, remove_all_modules_id		:: Id						// initialized at undef!
	, section_center_id			:: Id						// initialized at undef!
	, save_sections_id			:: Id						// initialized at undef!
	, suggestions_id			:: Id						// initialized at undef!
	, tactic_list_ids			:: ![Id]
	}
instance DummyValue MenuInfo
	where DummyValue =	{ interpreter_id			= undef
						, open_project_id			= undef
						, add_stdenv_id				= undef
						, project_center_id			= undef
						, remove_modules_id			= undef
						, remove_all_modules_id		= undef
						, section_center_id			= undef
						, save_sections_id			= undef
						, suggestions_id			= undef
						, tactic_list_ids			= []
						}

// ------------------------------------------------------------------------------------------------------------------------   
:: NameFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ nfPositive				:: !Bool
	, nfFilter					:: ![Char]
	}
instance == NameFilter
	where (==) f1 f2
			= (f1.nfPositive == f2.nfPositive) && (f1.nfFilter == f2.nfFilter)
 
// -------------------------------------------------------------------------------------------------------------------------------------------------
:: State =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ stProject				:: !.CProject
	, stHeaps				:: !.CHeaps
	, stCachedSymbolTable	:: !.SymbolTable
	, stSections			:: ![SectionPtr]
	, stHintTheorems		:: ![HintTheorem]
	
	, stFrontEndPhase		:: !FrontEndPhase
	, stDisplayOptions		:: !DisplayOptions
	, stDisplaySpecial		:: !DisplaySpecial
	, stFontsPresent		:: !FontsPresent
	, stIntFunctions		:: !IntFunctions
	, stOptions				:: !Options
	
	, stMenus				:: !MenuInfo
	, stMenuBarCreated		:: !Bool
	, stWindows				:: ![WindowInfo]
	, stUnregisteredWindows	:: ![(Id, RId WindowCommand, String)]
	, stTacticFilters		:: ![TacticFilter]				// must always have 5 elements
	, stWindowCommandRId	:: RId WindowCommand
	, stRememberedError		:: !Error						// needed for StatusDialogs in order to display error AFTER the dialog has been closed
	, stBusyProving			:: !Bool						// true when tactics are automatically being applied (suggestions window)
	, stDuplicate			:: !Bool						// return value when polling if a function-list or theorem-list is already opened
	}
instance DummyValue State
	where DummyValue =	{ stProject					= DummyValue
						, stHeaps					= DummyValue
						, stCachedSymbolTable		= newHeap
						, stSections				= []
						, stHintTheorems			= []
						, stFrontEndPhase			= FrontEndPhaseConvertModules
						, stDisplayOptions			= DummyValue
						, stDisplaySpecial			= DummyValue
						, stFontsPresent			= DummyValue
						, stIntFunctions			= DummyValue
						, stOptions					= DummyValue
						, stMenus					= DummyValue
						, stMenuBarCreated			= False
						, stWindows					= []
						, stUnregisteredWindows		= []
						, stTacticFilters			= [fullTacticFilter 1, emptyTacticFilter 2, emptyTacticFilter 3, emptyTacticFilter 4, emptyTacticFilter 5]
						, stWindowCommandRId		= undef
						, stRememberedError			= OK
						, stBusyProving				= False
						, stDuplicate				= False
						}

// ------------------------------------------------------------------------------------------------------------------------   
:: TacticFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tfTitle					:: !CName
	, tfNameFilter				:: !Maybe NameFilter
	, tfList					:: ![CName]
	}
fullTacticFilter n = {tfTitle = "List of tactics (" +++ toString n +++ ")", tfNameFilter = Just {nfFilter = ['*'], nfPositive = True}, tfList = []}
emptyTacticFilter n = {tfTitle = "List of tactics (" +++ toString n +++ ")", tfNameFilter = Nothing, tfList = []}

// ------------------------------------------------------------------------------------------------------------------------   
:: TheoremFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tfSections				:: ![SectionPtr]
	, tfName					:: !NameFilter
	, tfUsing					:: ![String]
	, tfStatus					:: !TheoremStatus
	}
instance == TheoremFilter
	where (==) f1 f2
			=		(listsEqual f1.tfSections f2.tfSections)
				&&	(f1.tfName == f2.tfName)
				&&	(listsEqual f1.tfUsing f2.tfUsing)
				&&	(f1.tfStatus == f2.tfStatus)

// ------------------------------------------------------------------------------------------------------------------------   
:: TheoremStatus =
// ------------------------------------------------------------------------------------------------------------------------   
	  Proved
	| Unproved
	| DontCare
instance == TheoremStatus
	where	(==)	Proved		Proved		= True
			(==)	Unproved	Unproved	= True
			(==)	DontCare	DontCare	= True
			(==)	_			_			= False

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: WindowCommand =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  CmdApplyHint				!Int !Bool								// hints window
	| CmdApplyTactic			!String !TacticId						// proof window
	| CmdApplyTactical			!String !PTactical						// proof window
	| CmdBrowseProof			!(RId (MarkUpMessage WindowCommand)) !TheoremPtr !ProofTreePtr	// theorem window
	| CmdChangeFilter													// filter windows
	| CmdChangeHintScores		!TheoremPtr								// theorem window
	| CmdCheckDefinitionFilter	!DefinitionFilter						// definition list window
	| CmdCheckTheoremFilter		!TheoremFilter							// theorem list window
	| CmdDebug															// proof window
	| CmdExecuteCmdLine			!String !Int							// proof window (bug avoidance)
	| CmdFocusCommandline												// proof window
	| CmdFocusSubgoal			!Int									// proof window
	| CmdFoldNode				!ProofTreePtr							// theorem window
	| CmdMoveTheorem			!TheoremPtr								// list of theorems window
	| CmdProve					!TheoremPtr								// theorem list window, proof window (when new theorem was created)
	| CmdProveByClicking		![ProvingAction]						// proof window
	| CmdProveSubgoal			!ProofTreePtr							// theorem window
	| CmdRefresh				!Action									// several windows
	| CmdRefreshAlways													// several windows (internal use!)
	| CmdRefreshBackground		!Colour !Colour							// several windows (changing background colour)
	| CmdRemoveModule			!ModulePtr								// project window
	| CmdRemoveSection			!SectionPtr								// section center
	| CmdRemoveTheorem			!TheoremPtr								// list of theorems window
	| CmdRenameSection			!SectionPtr								// section center
	| CmdRenameTheorem			!TheoremPtr								// list of theorems
	| CmdRestartProof													// proof window
	| CmdRestoreEditControl		!String									// proof window
	| CmdTacticInfo				!CName									// tacticlist window
	| CmdTacticWindow			!CName									// tacticlist window
	| CmdSaveSection			!SectionPtr								// section center
	| CmdSetInterpretExpr		!CExprH									// interpreter dialog
	| CmdShowDefinedness		!HeapPtr								// definition window
	| CmdShowDefinition			!HeapPtr								// several windows
	| CmdShowDefinitionsUsing	!HeapPtr								// definition list window
	| CmdShowModule				!(Maybe ModulePtr)						// projectcenter window (Nothing=Predefined)
	| CmdShowModuleContents		!(Maybe ModulePtr)						// projectcenter window (Nothing=Predefined)
	| CmdShowSectionContents	!SectionPtr								// sectionlist window
	| CmdShowVariableTypes												// proof window
	| CmdShowTheorem			!TheoremPtr								// theoremlist window
	| CmdShowTheoremsUsing		!TheoremPtr								// list of theorems window
	| CmdShowUnprovedTheorems											// section center
	| CmdTogglePropositions												// list of theorems window
	| CmdUndoTactics			!Int									// proof window
	| CmdUndoToSubgoal			!ProofTreePtr							// theorem window
	| CmdUnfoldNode				!ProofTreePtr							// theorem window
	| CmdUpdateHints			!(Maybe TheoremPtr) !Theorem !(!Bool, !DefinednessInfo)	// hints window
	| CmdUseHypothesis			!HypothesisPtr							// proof window
instance DummyValue WindowCommand
	where DummyValue	= CmdShowVariableTypes

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: WindowInfo =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ wiId					:: !WindowId
	, wiOpened				:: !Bool
	, wiWindowId			:: !Id
	, wiControlId			:: !Maybe Id
	, wiNormalRId			:: !Maybe (RId WindowCommand)
	, wiSpecialRId			:: !Maybe (RId (MarkUpMessage WindowCommand))
	, wiStoredPos			:: !Vector2
	, wiStoredWidth			:: !Int
	, wiStoredHeight		:: !Int
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: WindowId =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  DlgInterpreter
	| DlgNewExpression
	| DlgNewTheorem
	| DlgShowDefinitions
	| WinDefinition				!HeapPtr
	| WinHints
	| WinModule					!(Maybe ModulePtr)				// Nothing = Predefined module
	| WinProjectCenter
	| WinProof					!TheoremPtr
	| WinSection				!SectionPtr
	| WinSectionCenter
	| WinTacticList				!Int
	| WinTheorem				!TheoremPtr

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance == WindowId
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	(==) DlgInterpreter			DlgInterpreter			= True
	(==) DlgNewExpression		DlgNewExpression		= True
	(==) DlgNewTheorem			DlgNewTheorem			= True
	(==) DlgShowDefinitions		DlgShowDefinitions		= True
	(==) (WinDefinition ptr1)	(WinDefinition ptr2)	= ptr1 == ptr2
	(==) WinHints				WinHints				= True
	(==) (WinModule mb_ptr1)	(WinModule mb_ptr2)		= mb_ptr1 == mb_ptr2
	(==) WinProjectCenter		WinProjectCenter		= True
	(==) (WinProof _)			(WinProof _)			= True
	(==) (WinSection ptr1)		(WinSection ptr2)		= ptr1 == ptr2
	(==) WinSectionCenter		WinSectionCenter		= True
	(==) (WinTacticList i1)		(WinTacticList i2)		= i1 == i2
	(==) (WinTheorem ptr1)		(WinTheorem ptr2)		= ptr1 == ptr2
	(==) _						_						= False


// -------------------------------------------------------------------------------------------------------------------------------------------------
:: *IOState					:== *IOSt	*State
:: *PState					:== *PSt	*State

:: MarkUpRId				:== RId (MarkUpMessage WindowCommand)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
listsEqual :: ![a] ![a] -> Bool | == a
// -------------------------------------------------------------------------------------------------------------------------------------------------
listsEqual [x:xs] list
	# (found, ys)					= check x list
	| not found						= False
	= listsEqual xs ys
	where
		check :: !a ![a] -> (!Bool, ![a]) | == a
		check x [y:ys]
			| x == y				= (True, ys)
			# (found, ys)			= check x ys
			= (found, [y:ys])
		check x []
			= (False, [])
listsEqual [] list
	= isEmpty list






















// -------------------------------------------------------------------------------------------------------------------------------------------------
class StateAcc a 
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appProject				:: .(*CProject -> *CProject) 				!*a -> *a
	accProject				:: .(*CProject -> (.b, *CProject))			!*a -> (.b, !*a)
	showInProject			:: !FormatInfo !def							!*a -> (!Error, !MarkUpText WindowCommand, !*a) | FormattedShow def
	
	appHeaps				:: .(*CHeaps -> *CHeaps)					!*a -> *a
	accHeaps				:: .(*CHeaps -> (.b, *CHeaps))				!*a -> (.b, !*a)













// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2Project :: .(*CProject -> (.a, .b, *CProject)) !*state -> (.a, .b, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2Project fun state
	# ((result1, result2), state)		= accProject (changed_fun fun) state
	= (result1, result2, state)
	where
		changed_fun fun prj
			# (result1, result2, prj)	= fun prj
			= ((result1, result2), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3Project :: .(*CProject -> (.a, .b, .c, *CProject)) !*state -> (.a, .b, .c, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3Project fun state
	# ((result1, result2, result3), state)		= accProject (changed_fun fun) state
	= (result1, result2, result3, state)
	where
		changed_fun fun prj
			# (result1, result2, result3, prj)	= fun prj
			= ((result1, result2, result3), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorProject :: .(*CProject -> (Error, .a, *CProject)) !*state -> (Error, .a, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorProject fun state
	# ((error, result), state)			= accProject (changed_fun fun) state
	= (error, result, state)
	where
		changed_fun fun prj
			# (error, result, prj)		= fun prj
			= ((error, result), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2Heaps :: .(*CHeaps -> (.a, .b, *CHeaps)) !*state -> (.a, .b, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2Heaps fun state
	# ((result1, result2), state)		= accHeaps (changed_fun fun) state
	= (result1, result2, state)
	where
		changed_fun fun prj
			# (result1, result2, prj)	= fun prj
			= ((result1, result2), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3Heaps :: .(*CHeaps -> (.a, .b, .c, *CHeaps)) !*state -> (.a, .b, .c, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3Heaps fun state
	# ((result1, result2, result3), state)		= accHeaps (changed_fun fun) state
	= (result1, result2, result3, state)
	where
		changed_fun fun prj
			# (result1, result2, result3, prj)	= fun prj
			= ((result1, result2, result3), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc4Heaps :: .(*CHeaps -> (.a, .b, .c, .d, *CHeaps)) !*state -> (.a, .b, .c, .d, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc4Heaps fun state
	# ((result1, result2, result3, result4), state)		= accHeaps (changed_fun fun) state
	= (result1, result2, result3, result4, state)
	where
		changed_fun fun prj
			# (result1, result2, result3, result4, prj)	= fun prj
			= ((result1, result2, result3, result4), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc5Heaps :: .(*CHeaps -> (.a, .b, .c, .d, .e, *CHeaps)) !*state -> (.a, .b, .c, .d, .e, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc5Heaps fun state
	# ((result1, result2, result3, result4, result5), state)		= accHeaps (changed_fun fun) state
	= (result1, result2, result3, result4, result5, state)
	where
		changed_fun fun prj
			# (result1, result2, result3, result4, result5, prj)	= fun prj
			= ((result1, result2, result3, result4, result5), prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorHeaps :: .(*CHeaps -> (Error, .a, *CHeaps)) !*state -> (Error, .a, !*state) | StateAcc state
// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorHeaps fun state
	# ((error, result), state)			= accHeaps (changed_fun fun) state
	= (error, result, state)
	where
		changed_fun fun prj
			# (error, result, prj)		= fun prj
			= ((error, result), prj)















// -------------------------------------------------------------------------------------------------------------------------------------------------
instance StateAcc State
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appProject fun state
		# prj							= fun state.stProject
		= {state & stProject = prj}
	accProject fun state
		# (result, prj)					= fun state.stProject
		= (result, {state & stProject = prj})
	showInProject finfo def state
		# (error, ftext, heaps, prj)	= FormattedShow finfo def state.stHeaps state.stProject
		= (error, ftext, {state & stHeaps = heaps, stProject = prj})
	appHeaps fun state
		# heaps							= fun state.stHeaps
		= {state & stHeaps = heaps}
	accHeaps fun state
		# (result, heaps)				= fun state.stHeaps
		= (result, {state & stHeaps = heaps})

// -------------------------------------------------------------------------------------------------------------------------------------------------
instance StateAcc (PSt *State)
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appProject fun pstate
		= appPLoc (appProject fun) pstate
	accProject fun pstate
		= accPLoc (accProject fun) pstate
	showInProject finfo def pstate
		# (error, ftext, state)			= showInProject finfo def pstate.ls
		= (error, ftext, {pstate & ls = state})
	appHeaps fun pstate
		= appPLoc (appHeaps fun) pstate
	accHeaps fun pstate
		= accPLoc (accHeaps fun) pstate











// -------------------------------------------------------------------------------------------------------------------------------------------------
appHeapsProject :: .(*CHeaps -> .(*CProject -> (*CHeaps, *CProject))) !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
appHeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (heaps, prj)						= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
appErrorHeapsProject :: .(*CHeaps -> .(*CProject -> (Error, *CHeaps, *CProject))) !*PState -> (!Error, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
appErrorHeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (error, heaps, prj)				= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= (error, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accHeapsProject :: .(*CHeaps -> .(*CProject -> (.a, *CHeaps, *CProject))) !*PState -> (.a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
accHeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (result, heaps, prj)				= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= (result, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorHeapsProject :: .(*CHeaps -> .(*CProject -> (Error, .a, *CHeaps, *CProject))) !*PState -> (!Error, .a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
accErrorHeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (error, result, heaps, prj)		= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= (error, result, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2HeapsProject :: .(*CHeaps -> .(*CProject -> (.a, .b, *CHeaps, *CProject))) !*PState -> (.a, .b, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc2HeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (res1, res2, heaps, prj)			= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= (res1, res2, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3HeapsProject :: .(*CHeaps -> .(*CProject -> (.a, .b, .c, *CHeaps, *CProject))) !*PState -> (.a, .b, .c, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc3HeapsProject fun pstate
	# state								= pstate.ls
	# heaps								= state.stHeaps
	# prj								= state.stProject
	# (res1, res2, res3, heaps, prj)	= fun heaps prj
	# state								= {state & stHeaps = heaps, stProject = prj}
	# pstate							= {pstate & ls = state}
	= (res1, res2, res3, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
acc4HeapsProject :: .(*CHeaps -> .(*CProject -> (.a, .b, .c, .d, *CHeaps, *CProject))) !*PState -> (.a, .b, .c, .d, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
acc4HeapsProject fun pstate
	# state									= pstate.ls
	# heaps									= state.stHeaps
	# prj									= state.stProject
	# (res1, res2, res3, res4, heaps, prj)	= fun heaps prj
	# state									= {state & stHeaps = heaps, stProject = prj}
	# pstate								= {pstate & ls = state}
	= (res1, res2, res3, res4, pstate)

// ------------------------------------------------------------------------------------------------------------------------   
allTheorems :: !*PState -> (![TheoremPtr], !*PState)
// ------------------------------------------------------------------------------------------------------------------------   
allTheorems pstate
	# (all_sections, pstate)				= pstate!ls.stSections
	# (all_theorems, pstate)				= accHeaps (gather [] all_sections) pstate
	= (all_theorems, pstate)
	where
		gather :: ![TheoremPtr] ![SectionPtr] !*CHeaps -> (![TheoremPtr], !*CHeaps)
		gather passed [ptr:ptrs] heaps
			# (section, heaps)				= readPointer ptr heaps
			= gather (passed ++ section.seTheorems) ptrs heaps
		gather passed [] heaps
			= (passed, heaps)

















// -------------------------------------------------------------------------------------------------------------------------------------------------
globalEventHandler :: !WindowCommand !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
globalEventHandler command pstate
	# (rid, pstate)							= pstate!ls.stWindowCommandRId
	# (_, pstate)							= asyncSend rid command pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
broadcast :: !(Maybe WindowId) !Action !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
broadcast mb_wid action pstate
	# (winfos, pstate)						= pstate!ls.stWindows
	# pstate								= send winfos pstate
	# (ids, pstate)							= pstate!ls.stUnregisteredWindows
	# rids									= map snd3 ids
	# pstate								= uwalk send_u rids pstate
	# pstate								= update_menus action pstate
	= pstate
	where
		send :: ![WindowInfo] !*PState -> *PState
		send [winfo:winfos] pstate
			| Just winfo.wiId == mb_wid		= send winfos pstate
			| not winfo.wiOpened			= send winfos pstate
			# pstate						= case winfo.wiNormalRId of
												(Just rid)	-> snd (asyncSend rid (CmdRefresh action) pstate)
												Nothing		-> pstate
			# pstate						= case winfo.wiSpecialRId of
												(Just rid)	-> triggerMarkUpLink rid (CmdRefresh action) pstate
												Nothing		-> pstate
			= send winfos pstate
		send [] pstate
			= pstate
		
		send_u :: !(RId WindowCommand) !*PState -> *PState
		send_u rid pstate
			= snd (asyncSend rid (CmdRefresh action) pstate)
		
		update_menus :: !Action !*PState -> *PState
		update_menus (AddedCleanModules ptrs) pstate
			| isEmpty ptrs					= pstate
			# (project_id, pstate)			= pstate!ls.stMenus.open_project_id
			# (stdenv_id, pstate)			= pstate!ls.stMenus.add_stdenv_id
			# pstate						= appPIO (disableMenuElements [project_id, stdenv_id]) pstate
			# (remove_id, pstate)			= pstate!ls.stMenus.remove_modules_id
			# (remove_all_id, pstate)		= pstate!ls.stMenus.remove_all_modules_id
			# pstate						= appPIO (enableMenuElements [remove_id, remove_all_id]) pstate
			= pstate
		update_menus (RemovedCleanModules _) pstate
			# (modules, pstate)				= pstate!ls.stProject.prjModules
			| not (isEmpty modules)			= pstate
			# (project_id, pstate)			= pstate!ls.stMenus.open_project_id
			# (stdenv_id, pstate)			= pstate!ls.stMenus.add_stdenv_id
			# pstate						= appPIO (enableMenuElements [project_id, stdenv_id]) pstate
			# (remove_id, pstate)			= pstate!ls.stMenus.remove_modules_id
			# (remove_all_id, pstate)		= pstate!ls.stMenus.remove_all_modules_id
			# pstate						= appPIO (disableMenuElements [remove_id, remove_all_id]) pstate
			= pstate
		update_menus action pstate
			= pstate

// @2: TRUE means that the window will be focused when it is opened
// -------------------------------------------------------------------------------------------------------------------------------------------------
isWindowOpened :: !WindowId !Bool !*PState -> (!Bool, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
isWindowOpened wid focus pstate
	# (winfos, pstate)						= pstate!ls.stWindows
	# filtered_winfos						= filter (\winfo -> winfo.wiId == wid) winfos
	| isEmpty filtered_winfos				= (False, pstate)
	# winfo									= hd filtered_winfos
	= case winfo.wiOpened && focus of
		True	-> (True, setActiveWindow winfo.wiWindowId pstate)
		False	-> (winfo.wiOpened, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
close_Window :: !WindowId !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
close_Window (WinProof ptr) pstate
	= close_Window2 True (WinProof ptr) pstate
close_Window wid pstate
	= close_Window2 False wid pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
close_Window2 :: !Bool !WindowId !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
close_Window2 notify_hints wid pstate
	# (winfos, pstate)						= pstate!ls.stWindows
	# (winfos, pstate)						= admin_close winfos pstate
	# pstate								= {pstate & ls.stWindows = winfos}
	# pstate								= update_menus wid pstate
	= pstate
	where
		admin_close :: ![WindowInfo] !*PState -> (![WindowInfo], !*PState)
		admin_close [winfo:winfos] pstate
			# (winfos, pstate)				= admin_close winfos pstate
			# pstate						= case notify_hints && winfo.wiOpened && winfo.wiId == WinHints of
												True	-> snd (asyncSend (fromJust winfo.wiNormalRId) (CmdUpdateHints Nothing EmptyTheorem DummyValue) pstate)
												False	-> pstate
			| winfo.wiId <> wid				= ([winfo:winfos], pstate)
			| not winfo.wiOpened			= ([winfo:winfos], pstate)
			# (mb_pos, pstate)				= accPIO (getWindowPos winfo.wiWindowId) pstate
			# pos							= case mb_pos of
												(Just pos)		-> pos
												Nothing			-> zero
			# has_control					= isJust winfo.wiControlId
			# is_markup						= isJust winfo.wiSpecialRId
			| has_control
				# (mb_wstate, pstate)		= accPIO (getWindow winfo.wiWindowId) pstate
				| isNothing mb_wstate		= ([winfo:winfos], pstate)
				# wstate					= fromJust mb_wstate
				# (ok, size)				= getControlOuterSize (fromJust winfo.wiControlId) wstate
				| not ok					= ([winfo:winfos], pstate)
				# (metrics, _)				= osDefaultWindowMetrics 42
				# width						= size.w - 2 - metrics.osmVSliderWidth
				# height					= size.h - 2 - metrics.osmHSliderHeight
				# pstate					= closeWindow winfo.wiWindowId pstate
				# winfo						= {winfo	& wiOpened			= False
														, wiStoredPos		= pos
														, wiStoredWidth		= width
														, wiStoredHeight	= height}
				= ([winfo:winfos], pstate)
			| is_markup
				# (size, pstate)			= accPIO (getWindowViewSize winfo.wiWindowId) pstate
				# pstate					= closeWindow winfo.wiWindowId pstate
				# winfo						= {winfo	& wiOpened				= False
														, wiStoredPos			= pos
														, wiStoredWidth			= size.w
														, wiStoredHeight		= size.h}
				= ([winfo:winfos], pstate)
			# pstate						= closeWindow winfo.wiWindowId pstate
			# winfo							= {winfo & wiOpened = False}
			= ([winfo:winfos], pstate)
		admin_close [] pstate
			= ([], pstate)
		
		update_menus :: !WindowId !*PState -> *PState
		update_menus DlgInterpreter pstate
			# (interpreter_id, pstate)		= pstate!ls.stMenus.interpreter_id
			# pstate						= appPIO (unmarkMenuItems [interpreter_id]) pstate
			= pstate
		update_menus WinHints pstate
			# (suggestions_id, pstate)		= pstate!ls.stMenus.suggestions_id
			# pstate						= appPIO (unmarkMenuItems [suggestions_id]) pstate
			= pstate
		update_menus WinProjectCenter pstate
			# (menu_id, pstate)				= pstate!ls.stMenus.project_center_id
			# pstate						= appPIO (unmarkMenuItems [menu_id]) pstate
			= pstate
		update_menus WinSectionCenter pstate
			# (menu_id, pstate)				= pstate!ls.stMenus.section_center_id
			# pstate						= appPIO (unmarkMenuItems [menu_id]) pstate
			= pstate
		update_menus (WinTacticList num) pstate
			# (list_ids, pstate)			= pstate!ls.stMenus.tactic_list_ids
			# menu_id						= list_ids !! num
			# pstate						= appPIO (unmarkMenuItems [menu_id]) pstate
			= pstate
		update_menus wid pstate
			= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
get_Window :: !WindowId !*PState -> (!WindowInfo, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
get_Window wid pstate
	# (winfos, pstate)						= pstate!ls.stWindows
	# winfos								= filter (\winfo -> winfo.wiId == wid) winfos
	= (hd winfos, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
new_Window :: !WindowId !*PState -> (!WindowInfo, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
new_Window wid pstate
	# (winfos, pstate)						= pstate!ls.stWindows
	# (mb_winfo, winfos)					= split winfos
	# (winfo, pstate)						= newWindowInfo wid pstate
	# winfo									= case mb_winfo of
												(Just old)	-> {winfo	& wiStoredPos		= old.wiStoredPos
																		, wiStoredWidth		= old.wiStoredWidth
																		, wiStoredHeight	= old.wiStoredHeight
																		}
												Nothing		-> winfo
	# pstate								= {pstate & ls.stWindows = [winfo: winfos]}
	= (winfo, pstate)
	where
		split :: ![WindowInfo] -> (!Maybe WindowInfo, ![WindowInfo])
		split [winfo:winfos]
			| winfo.wiId == wid				= (Just winfo, winfos)
			# (mb_winfo, winfos)			= split winfos
			= (mb_winfo, [winfo:winfos])
		split []
			= (Nothing, [])

// BEZIG -- klopt misschien niet
// -------------------------------------------------------------------------------------------------------------------------------------------------
newWindowInfo :: !WindowId !*PState -> (!WindowInfo, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
newWindowInfo wid=:DlgInterpreter pstate
	= buildWindowInfo wid True True False zero 600 200 pstate
newWindowInfo wid=:DlgNewExpression pstate
	= buildWindowInfo wid False False False zero 0 0 pstate
newWindowInfo wid=:DlgNewTheorem pstate
	= buildWindowInfo wid False False False zero 0 0 pstate
newWindowInfo wid=:DlgShowDefinitions pstate
	= buildWindowInfo wid False True False zero 0 0 pstate
newWindowInfo wid=:(WinDefinition _) pstate
	= buildWindowInfo wid False False True minus 0 0 pstate
newWindowInfo wid=:(WinHints) pstate
	= buildWindowInfo wid True True False minus 300 450 pstate
newWindowInfo wid=:(WinModule _) pstate
	= buildWindowInfo wid True True False minus 300 450 pstate
newWindowInfo wid=:WinProjectCenter pstate
	= buildWindowInfo wid True True False minus 175 400 pstate
newWindowInfo wid=:(WinProof ptr) pstate
	= buildWindowInfo wid True True False minus 500 400 pstate
newWindowInfo wid=:(WinSection ptr) pstate
	= buildWindowInfo wid False False True minus 0 0 pstate
newWindowInfo wid=:WinSectionCenter pstate
	= buildWindowInfo wid True True False {vx=208,vy=0} 175 400 pstate
newWindowInfo wid=:(WinTacticList 0) pstate
	# (size, pstate)						= accPIO getProcessWindowSize pstate
	# (metrics, _)							= osDefaultWindowMetrics 42
	# window_width							= 8 + (5 + 1 + 175 + metrics.osmVSliderWidth + 1 + 5)
	= buildWindowInfo wid True True False {vx=size.w-window_width, vy=0} 175 377 pstate
newWindowInfo wid=:(WinTacticList n) pstate
	= buildWindowInfo wid True True False minus 175 400 pstate
newWindowInfo wid=:(WinTheorem ptr) pstate
	= buildWindowInfo wid True True False minus 450 300 pstate
newWindowInfo wid pstate
	= (abort "newWindowInfo", pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
minus :== {vx = 0-1, vy = 0-1}

// -------------------------------------------------------------------------------------------------------------------------------------------------
buildWindowInfo :: !WindowId !Bool !Bool !Bool !Vector2 !Int !Int !*PState -> (!WindowInfo, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildWindowInfo wid control_id rid markup_rid pos width height pstate
	# (id, pstate)							= accPIO openId pstate
	# (control_id, pstate)					= case control_id of
												True	-> justify (accPIO openId pstate)
												False	-> (Nothing, pstate)
	# (rid, pstate)							= case rid of
												True	-> justify (accPIO openRId pstate)
												False	-> (Nothing, pstate)
	# (special_rid, pstate)					= case markup_rid of
												True	-> justify (accPIO openRId pstate)
												False	-> (Nothing, pstate)
	# winfo									=	{ wiId				= wid
												, wiOpened			= True
												, wiWindowId		= id
												, wiControlId		= control_id
												, wiNormalRId		= rid
												, wiSpecialRId		= special_rid
												, wiStoredPos		= pos
												, wiStoredWidth		= width
												, wiStoredHeight	= height
												}
	= (winfo, pstate)
	where
		justify (id, pstate) = (Just id, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
close_UnregisteredWindow :: !Id !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
close_UnregisteredWindow id pstate
	# (windows, pstate)			= pstate!ls.stUnregisteredWindows
	# windows					= close id windows
	# pstate					= {pstate & ls.stUnregisteredWindows = windows}
	= closeWindow id pstate
	where
		close :: !Id ![(Id, RId WindowCommand,String)] -> [(Id, RId WindowCommand,String)]
		close the_id [(id,rid,name):ids]
			| the_id == id		= ids
			= [(id,rid,name): close the_id ids]
		close _ []
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
new_UnregisteredWindow :: !String !*PState -> (!Id, !RId WindowCommand, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
new_UnregisteredWindow name pstate
	# (id, pstate)				= accPIO openId pstate
	# (rid, pstate)				= accPIO openRId pstate
	# (windows, pstate)			= pstate!ls.stUnregisteredWindows
	# windows					= [(id,rid,name):windows]
	# pstate					= {pstate & ls.stUnregisteredWindows = windows}
	= (id, rid, pstate)





















// rect1 /\ rect2
// -------------------------------------------------------------------------------------------------------------------------------------------------
computeOverlap :: !Rectangle !Rectangle -> Rectangle
// -------------------------------------------------------------------------------------------------------------------------------------------------
computeOverlap rect1 rect2
	=	{ corner1 = {x = max rect1.corner1.x rect2.corner1.x, y = max rect1.corner1.y rect2.corner1.y}
		, corner2 = {x = min rect1.corner2.x rect2.corner2.x, y = min rect1.corner2.y rect2.corner2.y}
		}

// rect1 - rect2
// -------------------------------------------------------------------------------------------------------------------------------------------------
subtractRectangle :: !Rectangle !Rectangle -> [Rectangle]
// -------------------------------------------------------------------------------------------------------------------------------------------------
subtractRectangle rect1 rect2
	# rect2							= computeOverlap rect1 rect2
	| not (rectify rect2)			= [rect1]
	# nw							=	{ corner1 = {x = rect1.corner1.x, y = rect1.corner1.y}
										, corner2 = {x = rect2.corner1.x, y = rect2.corner1.y}
										}
	# n								=	{ corner1 = {x = rect2.corner1.x, y = rect1.corner1.y}
										, corner2 = {x = rect2.corner2.x, y = rect2.corner1.y}
										}
	# ne							=	{ corner1 = {x = rect2.corner2.x, y = rect1.corner1.y}
										, corner2 = {x = rect1.corner2.x, y = rect2.corner1.y}
										}
	# w								=	{ corner1 = {x = rect1.corner1.x, y = rect2.corner1.y}
										, corner2 = {x = rect2.corner1.x, y = rect2.corner2.y}
										}
	# e								=	{ corner1 = {x = rect2.corner2.x, y = rect2.corner1.y}
										, corner2 = {x = rect1.corner2.x, y = rect2.corner2.y}
										}
	# sw							=	{ corner1 = {x = rect1.corner1.x, y = rect2.corner2.y}
										, corner2 = {x = rect2.corner1.x, y = rect1.corner2.y}
										}
	# s								=	{ corner1 = {x = rect2.corner1.x, y = rect2.corner2.y}
										, corner2 = {x = rect2.corner2.x, y = rect1.corner2.y}
										}
	# se							=	{ corner1 = {x = rect2.corner2.x, y = rect2.corner2.y}
										, corner2 = {x = rect1.corner2.x, y = rect1.corner2.y}
										}
	= filter rectify [nw,n,ne,e,se,s,sw,w]
	where
		rectify rect
			= rect.corner1.x < rect.corner2.x && rect.corner1.y < rect.corner2.y

// -------------------------------------------------------------------------------------------------------------------------------------------------
freeRectangles :: !*PState -> (![Rectangle], ![Rectangle], !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
freeRectangles pstate
	# size							= maxFixedWindowSize
	# initial						= {corner1 = zero, corner2 = {x=size.w, y=size.h}}
	# (winfos, pstate)				= pstate!ls.stWindows
	# (free, occupied, pstate)		= subtract [winfo.wiWindowId \\ winfo <- winfos | winfo.wiOpened && is_window winfo.wiId] [initial] [] pstate
	# (more_wins, pstate)			= pstate!ls.stUnregisteredWindows
	# (free, occupied, pstate)		= subtract (map fst3 more_wins) free occupied pstate
	= (free, occupied, pstate)
	where
		subtract :: ![Id] ![Rectangle] ![Rectangle] !*PState -> (![Rectangle], ![Rectangle], !*PState)
		subtract [id:ids] free occupied pstate
			# (mb_vector, pstate)	= accPIO (getWindowPos id) pstate
			| isNothing mb_vector	= subtract ids free occupied pstate
			# vector				= fromJust mb_vector
			# (size, pstate)		= accPIO (getWindowOuterSize id) pstate
			# rect					= {corner1 = {x=vector.vx, y=vector.vy}, corner2 = {x=vector.vx+size.w, y=vector.vy+size.h}}
			# still_free			= map (\r -> subtractRectangle r rect) free
			= subtract ids (flatten still_free) [rect:occupied] pstate
		subtract [] free occupied pstate
			= (free, occupied, pstate)
		
		is_window :: !WindowId -> Bool
		is_window DlgNewExpression		= False
		is_window DlgNewTheorem			= False
		is_window _						= True
		
		fills :: !Point2 ![Rectangle] !*Picture -> (!Bool, !*Picture)
		fills v [rect:rects] pict
			# rect					= {rect	& corner1.x = rect.corner1.x + v.x
											, corner1.y = rect.corner1.y + v.y
											, corner2.x = rect.corner2.x + v.x
											, corner2.y = rect.corner2.y + v.y
									  }
			# pict					= setPenColour White pict
			# pict					= fill rect pict
			= fills v rects pict
		fills v [] pict
			= (False, pict)

// -------------------------------------------------------------------------------------------------------------------------------------------------
placeWindow :: !Size !*PState -> (!Vector2, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
placeWindow size pstate
	# (free, occupied, pstate)		= freeRectangles pstate
	# free							= sortBy (\r1 r2 -> r1.corner1.x + r1.corner1.y < r2.corner1.x + r2.corner1.y) free
	= (find free free size, pstate)
	where
		find :: ![Rectangle] ![Rectangle] !Size -> Vector2
		find [rect:rects] free size
			# candidate				= {corner1 = rect.corner1, corner2 = {x = rect.corner1.x + size.w - 1, y = rect.corner1.y + size.h - 1}}
			# not_free				= repeated_subtract [candidate] free
			| isEmpty not_free		= {vx = rect.corner1.x, vy = rect.corner1.y}
			= find rects free size
		find [] free size
			= zero
		
		repeated_subtract :: ![Rectangle] ![Rectangle] -> [Rectangle]
		repeated_subtract not_free [rect:rects]
			# not_free				= flatten [subtractRectangle r rect \\ r <- not_free]
			= repeated_subtract not_free rects
		repeated_subtract not_free []
			= not_free
















// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFormatInfo :: !*PState -> (!FormatInfo, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
makeFormatInfo pstate
	# (options, pstate)			= pstate!ls.stDisplayOptions
	# (special, pstate)			= pstate!ls.stDisplaySpecial
	= ({DummyValue	& fiOptions					= options
					, fiSpecial					= special
	  }, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
detectFonts :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
detectFonts pstate
	# (fontnames, pstate)		= accPIO (accScreenPicture getFontNames) pstate
	# ((_,font),pstate)			= accPIO (accScreenPicture (openFont {fName = "Courier New", fSize = 10, fStyles = []})) pstate
	# (metrics, pstate)			= accPIO (accScreenPicture (getFontMetrics font)) pstate
	# pstate					= {pstate	& ls.stFontsPresent.fpSymbol			= isMember "Symbol" fontnames
											, ls.stFontsPresent.fpWebdings			= isMember "Webdings" fontnames
											, ls.stFontsPresent.fpVdm				= isMember "VDM and Z 1.0" fontnames
											, ls.stFontsPresent.fpCourierHeight		= metrics.fAscent + metrics.fDescent + metrics.fLeading
								  }
	= pstate

// Mirror in AnnotatedShow
// -------------------------------------------------------------------------------------------------------------------------------------------------
setDisplaySpecial :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
setDisplaySpecial pstate
	# (has_symbol, pstate)		= pstate!ls.stFontsPresent.fpSymbol
	# (has_vdm, pstate)			= pstate!ls.stFontsPresent.fpVdm
	| has_vdm					= {pstate & ls.stDisplaySpecial = build_display_special "VDM and Z 1.0" vdm, ls.stOptions.optDisplaySpecial = True}
	| has_symbol				= {pstate & ls.stDisplaySpecial = build_display_special "Symbol" symbol, ls.stOptions.optDisplaySpecial = True}
	= pstate
	where
		symbol					= map (\num -> {toChar num}) [34,36,216,217,218,174,171,94,185]
		vdm						= map (\num -> {toChar num}) [34,36,216,217,218,222,219,94,185]
		
		quantor :: !String !String !Bool !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		quantor font quantor next fvar
			=	[ CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, CmText				quantor
				, CmEndFontFace
				] ++ fvar ++
				[ CmText				(if next "" ".")
				, CmEndColour
				, CmEndBold
				]
		
		unary_op :: !String !String !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		unary_op font op fp
			=	[ CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, CmText				op
				, CmEndFontFace
				, CmEndColour
				, CmEndBold
				] ++ fp
		
		binary_op :: !Bool !String !String !(MarkUpText WindowCommand) !(MarkUpText WindowCommand) -> MarkUpText WindowCommand
		binary_op indent font op fp fq
			=	fp ++
				[ CmText				(if indent "" " ")
				, CmBold
				, CmColour				LogicColour
				, CmFontFace			font
				, CmText				op
				, CmEndFontFace
				, CmEndColour
				, CmEndBold
				, CmText				" "
				] ++ fq
		
		build_display_special :: !String ![String] -> DisplaySpecial
		build_display_special font [forall,exists,not,and,or,implies,iff,bottom,unequals]
			=	{ disForall				= \n p	-> quantor font forall n p
				, disExists				= \n p	-> quantor font exists n p
				, disNot				= \p	-> unary_op font not p
				, disAnd				= \p q	-> binary_op False font and p q
				, disOr					= \p q	-> binary_op False font or p q
				, disImplies			= \i p q-> binary_op i font implies p q
				, disIff				= \p q	-> binary_op False font iff p q
				, disBottom				= [CmColour Red, CmFontFace font, CmText bottom, CmEndFontFace, CmEndColour]
				, disUnequals			= [CmFontFace font, CmText unequals, CmEndFont]
				, disIsSpecial			= True
				}

// -------------------------------------------------------------------------------------------------------------------------------------------------
unsetDisplaySpecial :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
unsetDisplaySpecial pstate
	= {pstate	& ls.stDisplaySpecial				= DummyValue
				, ls.stOptions.optDisplaySpecial	= False
	  }

// -------------------------------------------------------------------------------------------------------------------------------------------------
catchError :: (*PState -> (!Error, *PState)) !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
catchError action state
   # (error, state) = action state
   = showError error state














// -------------------------------------------------------------------------------------------------------------------------------------------------
checkNameFilter :: !NameFilter !String -> Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkNameFilter filter text
	# ok								= check 0 (size text) filter.nfFilter
	| filter.nfPositive
		= ok
		= not ok
	where
		check :: !Int !Int ![Char] -> Bool
		check now max []
			= now == max
		check now max ['*']
			= True
		check now max ['?':chars]
			| now >= max				= False
			# char						= text.[now]
			= check (now+1) max chars
		check now max ['*':chars]
			| now >= max				= False
			# ok1						= check now max chars
			# ok2						= check (now+1) max ['*':chars]
			= ok1 || ok2
		check now max [char:chars]
			| now >= max				= False
			| text.[now] <> char		= False
			= check (now+1) max chars