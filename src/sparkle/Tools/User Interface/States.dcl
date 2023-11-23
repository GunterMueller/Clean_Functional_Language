/*
** Program: Clean Prover System
** Module:  States (.dcl)
** 
** Author:  Maarten de Mol
** Created: 14 September 1999
*/

definition module 
   States

import 
	StdEnv,
	StdPSt,
	CoreTypes,
	ProveTypes,
	Parser,
	FormattedShow

// -------------------------------------------------------------------------------------------------------------------------------------------------
AlmostWhite			:== RGB {r=237,g=237,b=255}
AlmostWhiteHilite	:== RGB {r=180,g=180,b=255}
// -------------------------------------------------------------------------------------------------------------------------------------------------

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

// ------------------------------------------------------------------------------------------------------------------------   
:: DefinednessInfo =
// ------------------------------------------------------------------------------------------------------------------------   
	{ definedExpressions			:: ![CExprH]
	, definedVariables				:: ![CExprVarPtr]
	, undefinedExpressions			:: ![CExprH]
	, undefinedVariables			:: ![CExprVarPtr]
	}
instance DummyValue DefinednessInfo

// ------------------------------------------------------------------------------------------------------------------------   
:: DefinitionFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ dfKind					:: !DefinitionKind
	, dfName					:: !NameFilter
	, dfModules					:: ![ModulePtr]							// use nilPtr for Predefined
	, dfUsing					:: ![String]
	}
instance == DefinitionFilter

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: FontsPresent =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ fpSymbol				:: !Bool
	, fpVdm					:: !Bool
	, fpWebdings			:: !Bool
	, fpCourierHeight		:: !Int
	}
instance DummyValue FontsPresent

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

// ------------------------------------------------------------------------------------------------------------------------   
:: NameFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ nfPositive				:: !Bool
	, nfFilter					:: ![Char]
	}
instance == NameFilter

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

// ------------------------------------------------------------------------------------------------------------------------   
:: TacticFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tfTitle					:: !CName
	, tfNameFilter				:: !Maybe NameFilter
	, tfList					:: ![CName]
	}

// ------------------------------------------------------------------------------------------------------------------------   
:: TheoremFilter =
// ------------------------------------------------------------------------------------------------------------------------   
	{ tfSections				:: ![SectionPtr]
	, tfName					:: !NameFilter
	, tfUsing					:: ![String]
	, tfStatus					:: !TheoremStatus
	}
instance == TheoremFilter

// ------------------------------------------------------------------------------------------------------------------------   
:: TheoremStatus =
// ------------------------------------------------------------------------------------------------------------------------   
	  Proved
	| Unproved
	| DontCare
instance == TheoremStatus

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
instance == WindowId

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: *IOState					:== *IOSt	*State
:: *PState					:== *PSt	*State

:: MarkUpRId				:== RId (MarkUpMessage WindowCommand)
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
class StateAcc a 
// -------------------------------------------------------------------------------------------------------------------------------------------------
where
	appProject				:: .(*CProject -> *CProject) 				!*a -> *a
	accProject				:: .(*CProject -> (.b, *CProject))			!*a -> (.b, !*a)
	showInProject			:: !FormatInfo !def							!*a -> (!Error, !MarkUpText WindowCommand, !*a) | FormattedShow def
	
	appHeaps				:: .(*CHeaps -> *CHeaps)					!*a -> *a
	accHeaps				:: .(*CHeaps -> (.b, *CHeaps))				!*a -> (.b, !*a)

instance StateAcc State
instance StateAcc (PSt *State)

acc2Project				:: .(*CProject -> (.a, .b, *CProject)) !*state -> (.a, .b, !*state) | StateAcc state
acc3Project				:: .(*CProject -> (.a, .b, .c, *CProject)) !*state -> (.a, .b, .c, !*state) | StateAcc state
accErrorProject			:: .(*CProject -> (Error, .a, *CProject)) !*state -> (Error, .a, !*state) | StateAcc state
acc2Heaps				:: .(*CHeaps -> (.a, .b, *CHeaps)) !*state -> (.a, .b, !*state) | StateAcc state
acc3Heaps				:: .(*CHeaps -> (.a, .b, .c, *CHeaps)) !*state -> (.a, .b, .c, !*state) | StateAcc state
acc4Heaps				:: .(*CHeaps -> (.a, .b, .c, .d, *CHeaps)) !*state -> (.a, .b, .c, .d, !*state) | StateAcc state
acc5Heaps				:: .(*CHeaps -> (.a, .b, .c, .d, .e, *CHeaps)) !*state -> (.a, .b, .c, .d, .e, !*state) | StateAcc state
accErrorHeaps			:: .(*CHeaps -> (Error, .a, *CHeaps)) !*state -> (Error, .a, !*state) | StateAcc state

appHeapsProject			:: .(*CHeaps -> .(*CProject -> (*CHeaps, *CProject))) !*PState -> *PState
appErrorHeapsProject	:: .(*CHeaps -> .(*CProject -> (Error, *CHeaps, *CProject))) !*PState -> (!Error, !*PState)
accHeapsProject			:: .(*CHeaps -> .(*CProject -> (.a, *CHeaps, *CProject))) !*PState -> (.a, !*PState)
accErrorHeapsProject	:: .(*CHeaps -> .(*CProject -> (Error, .a, *CHeaps, *CProject))) !*PState -> (!Error, .a, !*PState)
acc2HeapsProject		:: .(*CHeaps -> .(*CProject -> (.a, .b, *CHeaps, *CProject))) !*PState -> (.a, .b, !*PState)
acc3HeapsProject		:: .(*CHeaps -> .(*CProject -> (.a, .b, .c, *CHeaps, *CProject))) !*PState -> (.a, .b, .c, !*PState)
acc4HeapsProject		:: .(*CHeaps -> .(*CProject -> (.a, .b, .c, .d, *CHeaps, *CProject))) !*PState -> (.a, .b, .c, .d, !*PState)

allTheorems				:: !*PState -> (![TheoremPtr], !*PState)

globalEventHandler		:: !WindowCommand !*PState -> *PState
broadcast				:: !(Maybe WindowId) !Action !*PState -> *PState
isWindowOpened			:: !WindowId !Bool !*PState -> (!Bool, !*PState)
close_Window			:: !WindowId !*PState -> *PState
close_Window2			:: !Bool !WindowId !*PState -> *PState
get_Window				:: !WindowId !*PState -> (!WindowInfo, !*PState)
new_Window				:: !WindowId !*PState -> (!WindowInfo, !*PState)
newWindowInfo			:: !WindowId !*PState -> (!WindowInfo, !*PState)
placeWindow				:: !Size !*PState -> (!Vector2, !*PState)

close_UnregisteredWindow	:: !Id !*PState -> *PState
new_UnregisteredWindow		:: !String !*PState -> (!Id, !RId WindowCommand, !*PState)

makeFormatInfo			:: !*PState -> (!FormatInfo, !*PState)
detectFonts				:: !*PState -> *PState
setDisplaySpecial		:: !*PState -> *PState
unsetDisplaySpecial		:: !*PState -> *PState
catchError				:: (*PState -> (!Error, *PState)) !*PState -> *PState

checkNameFilter			:: !NameFilter !String -> Bool