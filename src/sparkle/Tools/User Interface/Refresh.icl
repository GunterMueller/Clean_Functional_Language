/*
** Program: Clean Prover System
** Module:  Refresh (.icl)
** 
** Author:  Maarten de Mol
** Created: 14 February 2000
*/

implementation module 
	Refresh

import
	StdEnv,
	StdIO,
	States,
	FormattedShow

// -------------------------------------------------------------------------------------------------------------------------------------------------
:: RefreshAction =
// -------------------------------------------------------------------------------------------------------------------------------------------------
	  ChangedDisplayOption
	| ChangedProof					!TheoremPtr !Theorem !Bool
	| ChangedProofStatus			!TheoremPtr !Theorem				// only to be used after ChangedProof
	| ChangedSubgoal				!TheoremPtr !Theorem
	| CreatedSection
	| CreatedTheorem				!TheoremPtr !Theorem
	| DeletedSection				!SectionPtr !Section
	| DeletedTheorem				!TheoremPtr !Theorem
	| MovedTheorem					!TheoremPtr !Theorem !SectionPtr !SectionPtr
	| RenamedSection				!SectionPtr !Section
	| RenamedTheorem				!TheoremPtr !Theorem
	| RestartedTheorem				!TheoremPtr !Theorem

// -------------------------------------------------------------------------------------------------------------------------------------------------
visualize :: !RefreshAction !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
visualize ChangedDisplayOption pstate
	# (finfo, pstate)					= makeFormatInfo pstate
	# (definition_wins, pstate)			= pstate!ls.stWindows.winDefinitions
	# ptrs								= map fst3 definition_wins
	# rids								= map thd3 definition_wins
	# pstate							= multiple2c refreshDefinitionWindow ptrs rids finfo pstate
	# (theorem_wins, pstate)			= pstate!ls.stWindows.winTheorems
	# rids								= map thd3 theorem_wins
	# pstate							= multiple (refreshTheoremWindow True) rids pstate
	# pstate							= RefreshProofWindow (\_ -> True) pstate
	= pstate
visualize (ChangedProof ptr theorem refresh_proof) pstate
	# pstate							= case refresh_proof of
											True	-> RefreshProofWindow (\p -> p == ptr) pstate
											False	-> pstate
	# pstate							= RefreshTheoremWindow ptr pstate
	# pstate							= RefreshOtherTheoremWindows ptr pstate
	= pstate
visualize (ChangedProofStatus ptr theorem) pstate
	# pstate							= RefreshSectionWindow False theorem.thSection pstate
	= pstate
visualize (ChangedSubgoal ptr theorem) pstate
	# pstate							= RefreshProofWindow (\p -> p == ptr) pstate
	= pstate
visualize CreatedSection pstate
	# pstate							= RefreshSectionListWindow pstate
	= pstate
visualize (CreatedTheorem ptr theorem) pstate
	# pstate							= RefreshSectionListWindow pstate
	# pstate							= RefreshSectionWindow True theorem.thSection pstate
	= pstate
visualize (DeletedSection ptr section) pstate
	# pstate							= RefreshSectionListWindow pstate
	# pstate							= closeOpenedWindow (WinSection ptr) pstate
	# theorem_wins						= [WinTheorem ptr \\ ptr <- section.seTheorems]
	# pstate							= multiple closeOpenedWindow theorem_wins pstate
	# pstate							= CloseProofWindow (\ptr -> isMember ptr section.seTheorems) pstate
	= pstate
visualize (DeletedTheorem ptr theorem) pstate
	# pstate							= RefreshSectionListWindow pstate
	# pstate							= RefreshSectionWindow True theorem.thSection pstate
	# pstate							= closeOpenedWindow (WinTheorem ptr) pstate
	# pstate							= CloseProofWindow (\p -> p == ptr) pstate
	= pstate
visualize (MovedTheorem ptr theorem from_section to_section) pstate
	# pstate							= RefreshSectionListWindow pstate
	# pstate							= RefreshSectionWindow True from_section pstate
	# pstate							= RefreshSectionWindow True to_section pstate
	# (new_section, pstate)				= accHeaps (readPointer to_section) pstate
	# pstate							= TitleTheoremWindow ptr theorem new_section pstate
	= pstate
visualize (RenamedSection ptr section) pstate
	# pstate							= RefreshSectionListWindow pstate
	# pstate							= TitleSectionWindow ptr section pstate
	# theorem_ptrs						= section.seTheorems
	# (theorems, pstate)				= accHeaps (readPointers theorem_ptrs) pstate
	# pstate							= multiple2c TitleTheoremWindow theorem_ptrs theorems section pstate
	= pstate
visualize (RenamedTheorem ptr theorem) pstate
	# pstate							= RefreshSectionWindow True theorem.thSection pstate
	# (section, pstate)					= accHeaps (readPointer theorem.thSection) pstate
	# pstate							= TitleTheoremWindow ptr theorem section pstate
	# pstate							= TitleProofWindow ptr theorem pstate
	# pstate							= RefreshOtherTheoremWindows ptr pstate
	= pstate
visualize (RestartedTheorem ptr theorem) pstate
	# pstate							= RefreshProofWindow (\p -> p == ptr) pstate
	# pstate							= RefreshTheoremWindow ptr pstate
	# pstate							= RefreshSectionWindow True theorem.thSection pstate
	# pstate							= RefreshOtherTheoremWindows ptr pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple :: (a *PState -> *PState) ![a] !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple change [x:xs] pstate
	# pstate							= change x pstate
	= multiple change xs pstate
multiple change [] pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple2c :: (a b c *PState -> *PState) ![a] ![b] !c !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
multiple2c change [x:xs] [y:ys] z pstate
	# pstate							= change x y z pstate
	= multiple2c change xs ys z pstate
multiple2c change [] [] z pstate
	= pstate
































// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshDefinitionWindow :: !HeapPtr !(RId (MarkUpMessage HeapPtr)) !FormatInfo !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshDefinitionWindow ptr rid finfo pstate
	# (error, ftext, pstate)			= accErrorHeapsProject (formattedShow ptr finfo) pstate
	| isError error						= ShowError error (\x->x) pstate
	# pstate							= changeMarkUpText rid ftext pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshProofWindow :: !(RId ProofCommand) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshProofWindow rid pstate
	= snd (asyncSend rid PCmdRefresh pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshSectionWindow :: !Bool !(RId (MarkUpMessage SectionCommand)) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshSectionWindow True rid pstate
	= triggerMarkUpLink rid SCmdRefresh pstate
refreshSectionWindow False rid pstate
	= triggerMarkUpLink rid SCmdRefreshDepends pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshSectionListWindow :: !(RId (MarkUpMessage SectionPtr)) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshSectionListWindow rid pstate
	# (ptrs, pstate)					= pstate!ls.stSections
	# (infos, pstate)					= accHeaps (get_sections ptrs) pstate
	# infos								= sortBy (\(p1,n1,c1)(p2,n2,c2) -> n1 < n2) infos
	# ftext								= show infos
	= changeMarkUpText rid ftext pstate
	where
		get_sections :: ![SectionPtr] !*CHeaps -> ([(SectionPtr, CName, Int)], !*CHeaps)
		get_sections [ptr:ptrs] heaps
			# (section, heaps)			= readPointer ptr heaps
			# (infos, heaps)			= get_sections ptrs heaps
			= ([(ptr,section.seName,length section.seTheorems):infos], heaps)
		get_sections [] heaps
			= ([], heaps)
	
		show :: ![(SectionPtr, CName, Int)] -> !MarkUpText SectionPtr
		show [(ptr,name,count):infos]
			=	[ CmText "section "
				, CmBold
				, CmLink name ptr
				, CmEndBold
				, CmIText (" (" +++ toString count +++ (if (count==1) " theorem)" " theorems)"))
				, CmNewline
				: show infos
				]
		show []
			= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshTheoremWindow :: !Bool !(RId TheoremCommand) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
refreshTheoremWindow True rid pstate
	= snd (asyncSend rid TCmdRefresh pstate)
refreshTheoremWindow False rid pstate
	= snd (asyncSend rid TCmdRefreshDepends pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
titleProofWindow :: !Id !Theorem !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
titleProofWindow id theorem pstate
	# title								= "PROVING THEOREM " +++ theorem.thName
	= appPIO (setWindowTitle id title) pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
titleSectionWindow :: !Id !Section !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
titleSectionWindow id section pstate
	# title								= "SECTION " +++ section.seName
	= appPIO (setWindowTitle id title) pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
titleTheoremWindow :: !Id !Theorem !Section !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
titleTheoremWindow id theorem section pstate
	# title								= "THEOREM " +++ theorem.thName +++ " IN SECTION " +++ section.seName
	= appPIO (setWindowTitle id title) pstate























// -------------------------------------------------------------------------------------------------------------------------------------------------
CloseProofWindow :: !(TheoremPtr -> Bool) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
CloseProofWindow must_close pstate
	# (mb_ids, pstate)					= pstate!ls.stWindows.winProof
	| isNothing mb_ids					= pstate
	# (theorem_ptr, id, rid)			= fromJust mb_ids
	| must_close theorem_ptr			= closeOpenedWindow WinProof pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshOtherTheoremWindows :: !TheoremPtr !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshOtherTheoremWindows ptr pstate
	# (theorem_wins, pstate)			= pstate!ls.stWindows.winTheorems
	= refresh theorem_wins ptr pstate
	where
		refresh :: ![(TheoremPtr, Id, RId TheoremCommand)] !TheoremPtr !*PState -> !*PState
		refresh [(theorem_ptr,id,rid):ids] ptr pstate
			| theorem_ptr == ptr		= refresh ids ptr pstate
			# pstate					= refreshTheoremWindow False rid pstate
			= refresh ids ptr pstate
		refresh [] ptr pstate
			= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshProofWindow :: !(TheoremPtr -> Bool) !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshProofWindow must_refresh pstate
	# (mb_ids, pstate)					= pstate!ls.stWindows.winProof
	| isNothing mb_ids					= pstate
	# (theorem_ptr, id, rid)			= fromJust mb_ids
	| must_refresh theorem_ptr			= refreshProofWindow rid pstate
	= pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshSectionWindow :: !Bool !SectionPtr !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshSectionWindow all ptr pstate
	# (section_wins, pstate)			= pstate!ls.stWindows.winSections
	# found_wins						= filter (\(section_ptr,_,_) -> section_ptr == ptr) section_wins
	| isEmpty found_wins				= pstate
	# (_, id, rid)						= hd found_wins
	= refreshSectionWindow all rid pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshSectionListWindow :: !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshSectionListWindow pstate
	# (mb_ids, pstate)					= pstate!ls.stWindows.winSectionList
	| isNothing mb_ids					= pstate
	# (id, rid)							= fromJust mb_ids
	= refreshSectionListWindow rid pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshTheoremWindow :: !TheoremPtr !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
RefreshTheoremWindow ptr pstate
	# (theorem_wins, pstate)			= pstate!ls.stWindows.winTheorems
	# found_wins						= filter (\(theorem_ptr,_,_) -> theorem_ptr == ptr) theorem_wins
	| isEmpty found_wins				= pstate
	# (_, id, rid)						= hd found_wins
	= refreshTheoremWindow True rid pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleProofWindow :: !TheoremPtr !Theorem !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleProofWindow ptr theorem pstate
	# (mb_ids, pstate)					= pstate!ls.stWindows.winProof
	| isNothing mb_ids					= pstate
	# (theorem_ptr, id, rid)			= fromJust mb_ids
	| ptr <> theorem_ptr				= pstate
	= titleProofWindow id theorem pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleSectionWindow :: !SectionPtr !Section !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleSectionWindow ptr section pstate
	# (section_wins, pstate)			= pstate!ls.stWindows.winSections
	# found_wins						= filter (\(section_ptr,_,_) -> section_ptr == ptr) section_wins
	| isEmpty found_wins				= pstate
	# (_, id, rid)						= hd found_wins
	= titleSectionWindow id section pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleTheoremWindow :: !TheoremPtr !Theorem !Section !*PState -> !*PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
TitleTheoremWindow ptr theorem section pstate
	# (theorem_wins, pstate)			= pstate!ls.stWindows.winTheorems
	# found_wins						= filter (\(theorem_ptr,_,_) -> theorem_ptr == ptr) theorem_wins
	| isEmpty found_wins				= pstate
	# (_, id, rid)						= hd found_wins
	= titleTheoremWindow id theorem section pstate