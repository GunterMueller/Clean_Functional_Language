/*
** Program: Clean Prover System
** Module:  SectionMonad (.icl)
** 
** Author:  Maarten de Mol
** Created: 26 March 2001
*/

implementation module
	SectionMonad

import
	StdEnv,
	StdIO,
	Errors,
	FileMonad,
	Hints,
	Operate,
	States,
	StatusDialog,
	Tactics

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: SectionState =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	{ ssLoadSectionFunction		:: !(CName -> *(*PState -> *PState))
	, ssPointer					:: !SectionPtr
	, ssTheorems				:: ![TheoremPtr]
	, ssKnownExprVars			:: ![CExprVarPtr]
	, ssKnownPropVars			:: ![CPropVarPtr]
	, ssUsedSymbols				:: ![HeapPtr]
	, ssUsedTheorems			:: ![TheoremPtr]
	, ss_UsedSymbols			:: ![(CName, CName)]
	, ss_UsedTheorems			:: ![(CName, CName)]
	, ssSilent					:: !Bool				// used when an error occurs in the beginning of a proof (ignore the rest of the proof)
	, ssSilentIndentLevel		:: !Int					// used to keep error as local as possible
	, ssIndentLevel				:: !Int					// position of number in front of tactic (possibly zero)
	, ssCurrentTheoremPtr		:: !TheoremPtr
	, ssCurrentTheorem			:: !Theorem
	, ssStatusDialog			:: !StatusDialogEvent -> *PState -> *PState
	}

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: SectionM a :== FileM SectionState a
// -------------------------------------------------------------------------------------------------------------------------------------------------

// -------------------------------------------------------------------------------------------------------------------------------------------------
applySectionM :: !String !(SectionM a) !(CName -> *(*PState -> *PState)) !*PState -> (!Error, !SectionPtr, !*PState) | DummyValue a
// -------------------------------------------------------------------------------------------------------------------------------------------------
applySectionM name sectionm section_fun pstate
	# section									= {seName = name, seTheorems = []}
	# (ptr, pstate)								= accHeaps (newPointer section) pstate
	# sstate									=	{ ssLoadSectionFunction	= section_fun
													, ssPointer				= ptr
													, ssTheorems			= []
													, ssKnownExprVars		= []
													, ssKnownPropVars		= []
													, ssUsedSymbols			= []
													, ssUsedTheorems		= []
													, ss_UsedSymbols		= []
													, ss_UsedTheorems		= []
													, ssSilent				= False
													, ssSilentIndentLevel	= 0
													, ssIndentLevel			= 0
													, ssCurrentTheoremPtr	= nilPtr
													, ssCurrentTheorem		= EmptyTheorem
													, ssStatusDialog		= \event ps -> ps
													}
	# path										= applicationpath "Sections"
	# pstate									= openStatusDialog ("Restoring section '" +++ name +++ "'") (apply sstate) pstate
	# (error, pstate)							= pstate!ls.stRememberedError
	= (error, ptr, pstate)
	where
		apply sstate handle_event pstate
			# sstate							= {sstate & ssStatusDialog = handle_event}
			# pstate							= {pstate & ls.stRememberedError = OK}
			# path								= applicationpath "Sections"
			# (error, _, pstate)				= applyFileM path name "sec" FReadText sstate sectionm pstate
			# pstate							= {pstate & ls.stRememberedError = error}
			# pstate							= handle_event CloseStatusDialog pstate
			= pstate























// -------------------------------------------------------------------------------------------------------------------------------------------------
addTheorem :: !CName !CPropH -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
addTheorem name initial
	= accStates (add_theorem name initial)
	where
		add_theorem :: !CName !CPropH !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		add_theorem name initial _ _ _ sstate=:{ssPointer} pstate
			# (initial, pstate)					= accHeaps (FreshVars initial) pstate
			# (used_symbols, pstate)			= accHeaps (GetUsedSymbols initial) pstate
			# initial							= case isMember DummyValue used_symbols of
													True	-> CFalse
													False	-> initial
			# (_, finitial, pstate)				= accErrorHeapsProject (FormattedShow DummyValue initial) pstate
			# goal								= {DummyValue & glToProve = initial}
			# (leaf, pstate)					= accHeaps (newPointer (ProofLeaf goal)) pstate
			# proof								=	{ pTree				= leaf
													, pLeafs			= [leaf]
													, pCurrentLeaf		= leaf
													, pCurrentGoal		= goal
													, pFoldedNodes		= []
													, pUsedTheorems		= []
													, pUsedSymbols		= used_symbols
													}
			# theorem							= 	{ thName			= name
													, thInitial			= initial
													, thInitialText		= toText finitial
													, thProof			= proof
													, thSection			= ssPointer
													, thSubgoals		= False
													, thHintScore		= Nothing
													}
			# (theorem_ptr, pstate)				= accHeaps (newPointer theorem) pstate
			# (section, pstate)					= accHeaps (readPointer ssPointer) pstate
			# section							= {section & seTheorems = [theorem_ptr:section.seTheorems]}
			# pstate							= appHeaps (writePointer ssPointer section) pstate
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
addUsedSymbol :: !CName !String -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
addUsedSymbol name type
	= accStates (add_used_symbol name type)
	where
		add_used_symbol :: !CName !String !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		add_used_symbol name type _ _ _ sstate=:{ss_UsedSymbols} pstate
			# sstate							= {sstate & ss_UsedSymbols = ss_UsedSymbols ++ [(name,type)]}
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
addUsedTheorem :: !CName !CName -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
addUsedTheorem name section_name
	= accStates (add_used_theorem name section_name)
	where
		add_used_theorem :: !CName !CName !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		add_used_theorem name section_name _ _ _ sstate=:{ss_UsedTheorems} pstate
			# sstate							= {sstate & ss_UsedTheorems = ss_UsedTheorems ++ [(name, section_name)]}
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
checkDependencies :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
checkDependencies
	= accStates check_depends
	where
		check_depends :: !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		check_depends ssName _ _ sstate=:{ss_UsedSymbols, ss_UsedTheorems} pstate
			// check symbols
			# (all_modules, pstate)				= pstate!ls.stProject.prjModules
			# (error, all_ptrs, pstate)			= accErrorHeaps (getHeapPtrs all_modules [CFun, CDataCons]) pstate
			| isError error						= (error, Dummy, sstate, pstate)
			# (error, infos, pstate)			= accErrorHeapsProject (uumapError getDefinitionInfo all_ptrs) pstate
			| isError error						= (error, Dummy, sstate, pstate)
			# (error, symbol_ptrs, pstate)		= bindSymbols infos ss_UsedSymbols pstate
			| isError error						= (error, Dummy, sstate, pstate)
			// check theorems
			# (error, theorem_ptrs, pstate)		= checkTheorems [] ss_UsedTheorems pstate
			| isError error						= (error, Dummy, sstate, pstate)
			// accumulate
			# sstate							= {sstate	& ssUsedSymbols			= symbol_ptrs
															, ssUsedTheorems		= theorem_ptrs
												  }
			= (OK, Dummy, sstate, pstate)
			where
				bindSymbol :: ![DefinitionInfo] !(!CName, !CName) !*CHeaps !*CProject -> (!Error, !HeapPtr, !*CHeaps, !*CProject)
				bindSymbol [info:infos] (name, type) heaps prj
					| info.diName <> name			= bindSymbol infos (name, type) heaps prj
					# (error, stype, heaps, prj)	= getSymbolType info.diPointer heaps prj
					| isError error					= (error, DummyValue, heaps, prj)
					# finfo							= {DummyValue & fiNeedBrackets = True}
					# (error, ftype, heaps, prj)	= FormattedShow finfo stype heaps prj
					| isError error					= (error, DummyValue, heaps, prj)
					# ftext							= toText ftype
					| ftext <> type					= bindSymbol infos (name, type) heaps prj
					= (OK, info.diPointer, heaps, prj)
				bindSymbol [] (name, type) heaps prj
					= ([X_BindSectionSymbol ssName name type], DummyValue, heaps, prj)
				
				bindSymbols :: ![DefinitionInfo] ![(CName,CName)] !*PState -> (!Error, ![HeapPtr], !*PState)
				bindSymbols infos [(name,type):names] pstate
					# (error, ptr, pstate)			= accErrorHeapsProject (bindSymbol infos (name,type)) pstate
					| isError error
						# (output, pstate)			= handleError error ["Ignore error", "Abort load"] pstate
						| output == "Abort load"	= ([X_UnrecoveredError], DummyValue, pstate)
						# (error, ptrs, pstate)		= bindSymbols infos names pstate
						= (error, [DummyValue:ptrs], pstate)
					# (error, ptrs, pstate)			= bindSymbols infos names pstate
					= (error, [ptr:ptrs], pstate)
				bindSymbols infos [] pstate
					= (OK, [], pstate)
				
				bindTheorem :: ![TheoremPtr] !(CName, CName) !*CHeaps -> (!Error, !TheoremPtr, !*CHeaps)
				bindTheorem [ptr:ptrs] (name, section_name) heaps
					# (theorem, heaps)				= readPointer ptr heaps
					| theorem.thName <> name		= bindTheorem ptrs (name, section_name) heaps
					= (OK, ptr, heaps)
				bindTheorem [] (name, section_name) heaps
					= ([X_BindSectionTheorem ssName name section_name], nilPtr, heaps)
				
				checkTheorems :: ![CName] ![(CName, CName)] !*PState -> (!Error, ![TheoremPtr], !*PState)
				checkTheorems tried_before names pstate
					# (all_ptrs, pstate)			= allTheorems pstate
					# (error, theorem_ptrs, pstate)	= accErrorHeaps (umapError (bindTheorem all_ptrs) names) pstate
					| isError error
						# section_name				= getSectionName error
						| section_name == "?"		= (error, DummyValue, pstate)
						# (loaded, pstate)			= sectionAlreadyLoaded section_name pstate
						| loaded					= (error, DummyValue, pstate)
						# seen_before				= isMember section_name tried_before
						| seen_before				= (error, DummyValue, pstate)
//						# (msg, pstate)				= correctError error ["Load " +++ section_name, "Abort load"] pstate
//						| msg == "Abort load"		= ([X_UnrecoveredError], DummyValue, pstate)
						# pstate					= sstate.ssLoadSectionFunction section_name pstate
						= checkTheorems [section_name:tried_before] names pstate
					= (OK, theorem_ptrs, pstate)
				
				getSectionName [X_BindSectionTheorem _ _ name]
					= name
				getSectionName other
					= "?"
				
				sectionAlreadyLoaded :: !CName !*PState -> (!Bool, !*PState)
				sectionAlreadyLoaded name pstate
					# (all_ptrs, pstate)			= pstate!ls.stSections
					= accHeaps (check name all_ptrs) pstate
					where
						check :: !CName ![SectionPtr] !*CHeaps -> (!Bool, !*CHeaps)
						check name [ptr:ptrs] heaps
							# (section, heaps)		= readPointer ptr heaps
							= case section.seName == name of
								True	-> (True, heaps)
								False	-> check name ptrs heaps
						check name [] heaps
							= (False, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
setMessage :: !String -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
setMessage message
	= accStates set_message
	where
		set_message :: !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		set_message ssName _ _ sstate=:{ss_UsedSymbols, ss_UsedTheorems} pstate
			# pstate								= sstate.ssStatusDialog (NewMessage message) pstate
			= (OK, Dummy, sstate, pstate)

















// -------------------------------------------------------------------------------------------------------------------------------------------------
FindName :: !CName ![Ptr a] !*CHeaps -> (!Bool, !Ptr a, !*CHeaps) | Pointer a
// -------------------------------------------------------------------------------------------------------------------------------------------------
FindName name [ptr:ptrs] heaps
	# (ptr_name, heaps)						= getPointerName ptr heaps
	| name == ptr_name						= (True, ptr, heaps)
	= FindName name ptrs heaps
FindName name [] heaps
	= (False, nilPtr, heaps)

// -------------------------------------------------------------------------------------------------------------------------------------------------
disposeExprVars :: !Int -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
disposeExprVars n
	= accStates (dispose_vars n)
	where
		dispose_vars :: !Int !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		dispose_vars n _ _ _ sstate=:{ssKnownExprVars} pstate
			# sstate								= {sstate & ssKnownExprVars = drop n ssKnownExprVars}
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
disposePropVars :: !Int -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
disposePropVars n
	= accStates (dispose_vars n)
	where
		dispose_vars :: !Int !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		dispose_vars n _ _ _ sstate=:{ssKnownPropVars} pstate
			# sstate								= {sstate & ssKnownPropVars = drop n ssKnownPropVars}
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupBoundExprVar :: !CName -> SectionM CExprVarPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupBoundExprVar name
	= accStates (lookup name)
	where
		lookup :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !CExprVarPtr, !SectionState, !*PState)
		lookup name ssName ssLineNumber _ sstate=:{ssKnownExprVars, ssSilent, ssIndentLevel, ssCurrentTheorem} pstate
			| ssSilent								= (OK, nilPtr, sstate, pstate)
			# evars									= ssKnownExprVars ++ ssCurrentTheorem.thProof.pCurrentGoal.glExprVars
			# evars									= evars ++ find_evars ssCurrentTheorem.thProof.pCurrentGoal.glToProve
			# (found, ptr, pstate)					= acc2Heaps (FindName name evars) pstate
			| not found
				# error								= [X_UnknownExprVar ssName ssCurrentTheorem.thName ssLineNumber name]
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], nilPtr, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, nilPtr, sstate, pstate)
			= (OK, ptr, sstate, pstate)
			where
				find_evars :: !CPropH -> [CExprVarPtr]
				find_evars (CExprForall ptr p)		= [ptr: find_evars p]
				find_evars (CPropForall _ p)		= find_evars p
				find_evars _						= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupExprVar :: !CName -> SectionM CExprVarPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupExprVar name
	= accStates (lookup name)
	where
		lookup :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !CExprVarPtr, !SectionState, !*PState)
		lookup name ssName ssLineNumber _ sstate=:{ssKnownExprVars, ssSilent, ssIndentLevel, ssCurrentTheorem} pstate
			| ssSilent								= (OK, nilPtr, sstate, pstate)
			# evars									= ssKnownExprVars ++ ssCurrentTheorem.thProof.pCurrentGoal.glExprVars
			# (found, ptr, pstate)					= acc2Heaps (FindName name evars) pstate
			| not found
				# error								= [X_UnknownExprVar ssName ssCurrentTheorem.thName ssLineNumber name]
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], nilPtr, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, nilPtr, sstate, pstate)
			= (OK, ptr, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupHypothesis :: !CName -> SectionM HypothesisPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupHypothesis name
	= accStates (lookup name)
	where
		lookup :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !HypothesisPtr, !SectionState, !*PState)
		lookup name ssName ssLineNumber _ sstate=:{ssSilent, ssIndentLevel, ssCurrentTheorem} pstate
			| ssSilent								= (OK, nilPtr, sstate, pstate)
			# hyps									= ssCurrentTheorem.thProof.pCurrentGoal.glHypotheses
			# (found, ptr, pstate)					= acc2Heaps (FindName name hyps) pstate
			| not found
				# error								= [X_UnknownHypothesis ssName ssCurrentTheorem.thName ssLineNumber name]
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], nilPtr, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, nilPtr, sstate, pstate)
			= (OK, ptr, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupPropVar :: !CName -> SectionM CPropVarPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupPropVar name
	= accStates (lookup name)
	where
		lookup :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !CPropVarPtr, !SectionState, !*PState)
		lookup name ssName ssLineNumber _ sstate=:{ssKnownPropVars, ssSilent, ssIndentLevel, ssCurrentTheorem} pstate
			| ssSilent								= (OK, nilPtr, sstate, pstate)
			# pvars									= ssKnownPropVars ++ ssCurrentTheorem.thProof.pCurrentGoal.glPropVars
			# (found, ptr, pstate)					= acc2Heaps (FindName name pvars) pstate
			| not found
				# error								= [X_UnknownPropVar ssName ssCurrentTheorem.thName ssLineNumber name]
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], nilPtr, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, nilPtr, sstate, pstate)
			= (OK, ptr, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupSymbol :: !Int -> SectionM (HeapPtr, CName)
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupSymbol index
	= accStates (lookup index)
	where
		lookup :: !Int !String !Int !Int !SectionState !*PState -> (!Error, !(!HeapPtr, !CName), !SectionState, !*PState)
		// look in predef
		lookup (-9) ssName fsLineNumber fsCharNumber sstate pstate
			= (OK, (CConsPtr, "_Cons"), sstate, pstate)
		lookup index ssName fsLineNumber fsCharNumber sstate=:{ssUsedSymbols} pstate
			| index < 0 || index >= length ssUsedSymbols
				# error								= [X_ParseFile ssName fsLineNumber fsCharNumber "Symbol index out of range."]
				= (error, (DummyValue, ""), sstate, pstate)
			# ptr									= ssUsedSymbols !! index
			# (error, name, pstate)					= accErrorHeapsProject (getDefinitionName ptr) pstate
			| isError error							= (error, (DummyValue, ""), sstate, pstate)
			= (OK, (ptr, name), sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupTheorem :: !CName -> SectionM TheoremPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
lookupTheorem name
	= accStates (lookup name)
	where
		lookup :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !TheoremPtr, !SectionState, !*PState)
		lookup name ssName fsLineNumber _ sstate=:{ssPointer, ssIndentLevel, ssUsedTheorems, ssCurrentTheorem} pstate
			# (section, pstate)						= accHeaps (readPointer ssPointer) pstate
			# theorems								= ssUsedTheorems ++ section.seTheorems
			# (found, ptr, pstate)					= acc2Heaps (FindName name theorems) pstate
			| not found
				# error								= [X_UnknownTheorem ssName ssCurrentTheorem.thName fsLineNumber name]
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], nilPtr, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, nilPtr, sstate, pstate)
			= (OK, ptr, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
newExprVars :: ![CName] -> SectionM [CExprVarPtr]
// -------------------------------------------------------------------------------------------------------------------------------------------------
newExprVars names
	= accStates (new_vars names)
	where
		new_vars :: ![CName] !String !Int !Int !SectionState !*PState -> (!Error, ![CExprVarPtr], !SectionState, !*PState)
		new_vars names _ _ _ sstate=:{ssKnownExprVars} pstate
			# evars									= [{DummyValue & evarName = name} \\ name <- names]
			# (ptrs, pstate)						= accHeaps (newPointers evars) pstate
			# sstate								= {sstate & ssKnownExprVars = ptrs ++ ssKnownExprVars}
			= (OK, ptrs, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
newPropVars :: ![CName] -> SectionM [CPropVarPtr]
// -------------------------------------------------------------------------------------------------------------------------------------------------
newPropVars names
	= accStates (new_vars names)
	where
		new_vars :: ![CName] !String !Int !Int !SectionState !*PState -> (!Error, ![CPropVarPtr], !SectionState, !*PState)
		new_vars names _ _ _ sstate=:{ssKnownPropVars} pstate
			# pvars									= [{DummyValue & pvarName = name} \\ name <- names]
			# (ptrs, pstate)						= accHeaps (newPointers pvars) pstate
			# sstate								= {sstate & ssKnownPropVars = ptrs ++ ssKnownPropVars}
			= (OK, ptrs, sstate, pstate)






















// -------------------------------------------------------------------------------------------------------------------------------------------------
executeTactic :: !TacticId -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
executeTactic tactic
	= accStates (execute tactic)
	where
		execute :: !TacticId !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		execute tactic ssName fsLineNumber _ sstate=:{ssSilent, ssIndentLevel, ssCurrentTheorem, ssCurrentTheoremPtr} pstate
			| ssSilent								= (OK, Dummy, sstate, pstate)
			# (options, pstate)						= pstate!ls.stOptions
			# (error, theorem, _, pstate)			= acc3HeapsProject (applyTactic tactic ssCurrentTheoremPtr ssCurrentTheorem options) pstate
			| isError error
				# error								= [X_Message (LongDescription (hd error))]
				# error								= pushError (X_ApplySectionTactic ssName ssCurrentTheorem.thName fsLineNumber (tacticTitle tactic)) error
				# (msg, pstate)						= handleError error ["Ignore error", "Abort load"] pstate
				| msg == "Abort load"				= ([X_UnrecoveredError], Dummy, sstate, pstate)
				# sstate							= {sstate	& ssSilent				= True
																, ssSilentIndentLevel	= ssIndentLevel
													  }
				= (OK, Dummy, sstate, pstate)
			# sstate								= {sstate	& ssCurrentTheorem		= theorem
													  }
			= (OK, Dummy, sstate, pstate)

// Reset silent flag if indentation is less or equal than error position.
// -------------------------------------------------------------------------------------------------------------------------------------------------
newBranch :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
newBranch
	=	accStates new_branch						>>= \next ->
		if next 
			nextSubgoal
			(returnM Dummy)
	where
		new_branch :: !String !Int !Int !SectionState !*PState -> (!Error, !Bool, !SectionState, !*PState)
		new_branch _ _ fsCharNumber sstate=:{ssSilent, ssSilentIndentLevel} pstate
			# sstate								= {sstate & ssIndentLevel = fsCharNumber}
			| ssSilent && ssSilentIndentLevel >= fsCharNumber
				# sstate							= {sstate & ssSilent = False}
				= (OK, True, sstate, pstate)
			= (OK, False, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
nextSubgoal :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
nextSubgoal
	= accStates next_subgoal
	where
		next_subgoal :: !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		next_subgoal _ _ _ sstate=:{ssSilent, ssCurrentTheorem} pstate
			| ssSilent								= (OK, Dummy, sstate, pstate)
			# proof									= ssCurrentTheorem.thProof
			# all_leafs								= proof.pLeafs
			| isEmpty all_leafs						= (OK, Dummy, sstate, pstate)
			# all_leafs								= all_leafs ++ [hd all_leafs]
			# current_leaf							= proof.pCurrentLeaf
			# new_leaf								= next current_leaf all_leafs
			# (leaf, pstate)						= accHeaps (readPointer new_leaf) pstate
			# goal									= fromLeaf leaf
			# proof									= {proof	& pCurrentLeaf			= new_leaf
																, pCurrentGoal			= goal
													  }
			# sstate								= {sstate & ssCurrentTheorem.thProof = proof}
			= (OK, Dummy, sstate, pstate)
			where
				next :: !ProofTreePtr ![ProofTreePtr] -> ProofTreePtr
				next current [ptr:ptrs]
					| current == ptr
						| isEmpty ptrs				= current
						= hd ptrs
					= next current ptrs
				next current []
					= current

// -------------------------------------------------------------------------------------------------------------------------------------------------
saveProof :: !(Maybe (Int,Int,Int,Int)) -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
saveProof hint_score
	= accStates save_proof
	where
		save_proof :: !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		save_proof _ _ _ sstate=:{ssCurrentTheoremPtr, ssCurrentTheorem} pstate
			# theorem								= {ssCurrentTheorem & thHintScore = hint_score}
			# pstate								= appHeaps (writePointer ssCurrentTheoremPtr theorem) pstate
			# pstate								= setTheoremHint False ssCurrentTheoremPtr theorem.thInitial hint_score pstate
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
startProof :: !CName -> SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
startProof name
	= accStates (prove name)
	where
		prove :: !CName !String !Int !Int !SectionState !*PState -> (!Error, !Dummy, !SectionState, !*PState)
		prove name ssName fsLineNumber _ sstate=:{ssPointer} pstate
			# (section, pstate)						= accHeaps (readPointer ssPointer) pstate
			# (found, ptr, pstate)					= acc2Heaps (FindName name section.seTheorems) pstate
			| not found
				# error								= [X_UnknownTheorem ssName "X" fsLineNumber name]
				= (error, Dummy, sstate, pstate)
			# (theorem, pstate)						= accHeaps (readPointer ptr) pstate
			# sstate								= {sstate	& ssSilent				= False
																, ssIndentLevel			= 0
																, ssCurrentTheoremPtr	= ptr
																, ssCurrentTheorem		= theorem
													  }
			= (OK, Dummy, sstate, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
typeAlgPatterns :: ![CAlgPatternH] -> SectionM HeapPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
typeAlgPatterns patterns
	= accStates (type patterns)
	where
		type :: ![CAlgPatternH] !String !Int !Int !SectionState !*PState -> (!Error, !HeapPtr, !SectionState, !*PState)
		type [] ssName fsLineNumber fsCharNumber sstate pstate
			# error									= [X_ParseFile ssName fsLineNumber fsCharNumber "Unable to type algebraic case."]
			= (error, DummyValue, sstate, pstate)
		type [p:ps] _ _ _ sstate pstate
			# (error, consdef, pstate)				= accErrorProject (getDataConsDef p.atpDataCons) pstate
			| isError error							= (error, DummyValue, sstate, pstate)
			= (OK, consdef.dcdAlgType, sstate, pstate)