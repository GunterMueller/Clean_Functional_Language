/*
** Program: Clean Prover System
** Module:  Main
** 
** Author:  Maarten de Mol
** Created: 26 May 1999
*/

module 
	Sparkle

import 
	StdEnv,
	StdIO,
	States,
	ArgEnv,
	States,
	MenuBar,
	ProjectCenter,
	OpenProject,
	OptionsMonad,
	RemoveModules,
	SectionCenter,
	ShowModule,
	ShowDefinition,
	ShowDefinitions,
	ShowProof,
	ShowTheorem,
	ShowTheorems,
	TacticList,
	Predefined
	, RWSDebug
   
// -------------------------------------------------------------------------------------------------------------------------------------------------
Start :: !*World -> *World
// -------------------------------------------------------------------------------------------------------------------------------------------------
Start world
	# (symbol_table, world)			= buildCachedSymbolTable world
	= startIO MDI {DummyValue & stCachedSymbolTable = symbol_table} Initialize [ProcessClose close_process] world

// -------------------------------------------------------------------------------------------------------------------------------------------------
Initialize :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
Initialize state
	# (eventhandler_rid, state)		= accPIO openRId state
	# (_, state)					= openReceiver Nothing (Receiver eventhandler_rid eventHandler []) state
	# state							= {state & ls.stWindowCommandRId = eventhandler_rid}
	# state							= detectFonts state
	# (ptr, state)					= accHeaps (newPointer {seName = "main", seTheorems = []}) state
	# state							= {state & ls.stSections = [ptr]}
	# (predefined, state)			= accHeaps buildPredefined state
	# state							= {state & ls.stProject.prjPredefined = predefined}
	# state							= readOptions state
	# state							= createMenuBar (setDisplaySpecial state)
	# state							= aboutDialog False state
	# commandline_options			= getCommandLine
	| size commandline_options < 2	= state
	# project_name					= select commandline_options 1
	# state							= catchError (openNamedProject project_name) state
	= state

// =================================================================================================================================================
// Function borrowed from the predef.icl module. (called init_identifiers there)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildCachedSymbolTable :: !*World -> (!*SymbolTable, !*World)
// -------------------------------------------------------------------------------------------------------------------------------------------------
buildCachedSymbolTable world
	# local_predefined_idents		= predefined_idents
	= init_predefined_idents 0 local_predefined_idents newHeap world
	where
		init_predefined_idents :: !Int !{!Ident} !*SymbolTable !*World -> (!*SymbolTable, !*World)
		init_predefined_idents i idents heap world
			| i < size idents
				| size idents.[i].id_name > 0
					# (heap, world)		= initPtr idents.[i].id_info EmptySymbolTableEntry heap world
					= init_predefined_idents (i+1) idents heap world
//				| otherwise
					= init_predefined_idents (i+1) idents heap world
//			| otherwise
				= (heap, world)

// -------------------------------------------------------------------------------------------------------------------------------------------------
eventHandler :: !WindowCommand !(a, !*PState) -> (!a, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
eventHandler (CmdBrowseProof proof_rid theorem_ptr proof_ptr) (lstate, pstate)
	= (lstate, undo proof_rid theorem_ptr proof_ptr pstate)
eventHandler (CmdChangeHintScores theorem_ptr) (lstate, pstate)
	= (lstate, changeHintScores theorem_ptr pstate)
eventHandler (CmdMoveTheorem ptr) (lstate, pstate)
	= (lstate, moveTheorem ptr pstate)
eventHandler (CmdProve ptr) (lstate, pstate)
	# (theorem, pstate)				= accHeaps (readPointer ptr) pstate
	= (lstate, openProof ptr theorem pstate)
eventHandler (CmdRemoveModule ptr) (lstate, pstate)
	= (lstate, removeModules True [ptr] pstate)
eventHandler (CmdRemoveTheorem ptr) (lstate, pstate)
	= (lstate, removeTheorem ptr pstate)
eventHandler (CmdRenameTheorem ptr) (lstate, pstate)
	= (lstate, renameTheorem ptr pstate)
eventHandler (CmdShowDefinition ptr) (lstate, pstate)
	= (lstate, showDefinition ptr pstate)
eventHandler (CmdShowModule mb_ptr) (lstate, pstate)
	= (lstate, showModule mb_ptr pstate)
eventHandler (CmdShowModuleContents mb_ptr) (lstate, pstate)
	# filter_ptrs					= if (isNothing mb_ptr) [nilPtr] [fromJust mb_ptr]
	# filter						= {dfKind = CFun, dfName = {nfPositive = True, nfFilter = ['*']}, dfModules = filter_ptrs, dfUsing = []}
	= (lstate, showDefinitions Nothing (Just filter) pstate)
eventHandler (CmdShowSectionContents ptr) (lstate, pstate)
	# filter						= {tfSections = [ptr], tfName = {nfPositive = True, nfFilter = ['*']}, tfUsing = [], tfStatus = DontCare}
	= (lstate, showTheorems True (Just filter) pstate)
eventHandler (CmdShowTheorem ptr) (lstate, pstate)
	= (lstate, openTheorem ptr pstate)
eventHandler (CmdShowTheoremsUsing ptr) (lstate, pstate)
	# (all_sections, pstate)		= pstate!ls.stSections
	# (name, pstate)				= accHeaps (getPointerName ptr) pstate
	# new_filter					=	{ tfSections		= all_sections
										, tfName			= {nfFilter = ['*'], nfPositive = True}
										, tfUsing			= [name]
										, tfStatus			= DontCare
										}
	= (lstate, showTheorems True (Just new_filter) pstate)
eventHandler CmdShowUnprovedTheorems (lstate, pstate)
	# (all_sections, pstate)		= pstate!ls.stSections
	# new_filter					=	{ tfSections		= all_sections
										, tfName			= {nfFilter = ['*'], nfPositive = True}
										, tfUsing			= []
										, tfStatus			= Unproved
										}
	= (lstate, showTheorems True (Just new_filter) pstate)
eventHandler command (lstate, pstate)
	= (lstate, pstate)