/*
** Program: Clean Prover System
** Module:  OptionsMonad (.icl)
** 
** Author:  Maarten de Mol
** Created: 03 April 2001
*/

implementation module 
	OptionsMonad

import 
	StdEnv,
	StdIO,
	FileMonad,
	ProjectCenter,
	SectionCenter,
	TacticList,
	States

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeOptions :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeOptions pstate
	# (winfos, pstate)									= pstate!ls.stWindows
	# opened											= [winfo.wiId \\ winfo <- winfos | winfo.wiOpened]
	# pstate											= close winfos pstate
	# (winfos, pstate)									= pstate!ls.stWindows
	# (tfilters, pstate)								= pstate!ls.stTacticFilters
	# (view_threshold, pstate)							= pstate!ls.stOptions.optHintsViewThreshold
	# (apply_threshold, pstate)							= pstate!ls.stOptions.optHintsApplyThreshold
	# (display_options, pstate)							= pstate!ls.stDisplayOptions
	#! (error, _, pstate)								= applyFileM (applicationpath "") "options" "" FWriteText Dummy (write winfos opened display_options tfilters view_threshold apply_threshold) pstate
	| isError error										= showError error pstate
	= pstate
	where
		close :: ![WindowInfo] !*PState -> *PState
		close [] pstate
			= pstate
		close [winfo:winfos] pstate
			| not winfo.wiOpened						= close winfos pstate
			#! pstate									= close_Window winfo.wiId pstate
			= close winfos pstate
		
		write :: ![WindowInfo] ![WindowId] !DisplayOptions ![TacticFilter] !Int !Int -> FileM Dummy Dummy
		write winfos opened display_options filters view_threshold apply_threshold
			// background colours
			# dw_bg										= display_options.optDefinitionWindowBG
			# dl_bg										= display_options.optDefinitionListWindowBG
			# hw_bg										= display_options.optHintWindowBG
			# pc_bg										= display_options.optProjectCenterBG
			# pw_bg										= display_options.optProofWindowBG
			# sc_bg										= display_options.optSectionCenterBG
			# td_bg										= display_options.optTacticDialogBG
			# tl_bg										= display_options.optTacticListBG
			# tw_bg										= display_options.optTheoremWindowBG
			# thl_bg									= display_options.optTheoremListWindowBG
			// general display options
			# about										= display_options.optStartWithAboutDialog
			# indents									= display_options.optShowIndents
			=	write_colour "DefinitionWindowBG" dw_bg	>>>
				write_colour "DefinitionListWindowBG" dl_bg	>>>
				write_colour "HintWindowBG" hw_bg		>>>
				write_colour "ProjectCenterBG" pc_bg	>>>
				write_colour "ProofWindowBG" pw_bg		>>>
				write_colour "SectionCenterBG" sc_bg	>>>
				write_colour "TacticDialogBG" td_bg		>>>
				write_colour "TacticListBG" tl_bg		>>>
				write_colour "TheoremWindowBG" tw_bg	>>>
				write_colour "TheoremListWindowBG" thl_bg >>>
				writeToken "Start with about:"			>>>
				alignTo 35								>>>
				writeToken (toString about)				>>>
				advanceLine								>>>
				writeToken "Show |-bars:"				>>>
				alignTo 35								>>>
				writeToken (toString indents)			>>>
				advanceLine								>>>
				writeToken "Hints view threshold:"		>>>
				alignTo 35								>>>
				writeNumber view_threshold				>>>
				advanceLine								>>>
				writeToken "Hints apply threshold:"		>>>
				alignTo 35								>>>
				writeNumber apply_threshold				>>>
				advanceLine								>>>
				write_filters 0 filters					>>>
				mapM (writeWindowInfo opened) winfos	>>>
				advanceLine								>>>
				returnM Dummy
		
		write_colour :: !String !ExtendedColour -> FileM Dummy Dummy
		write_colour name extended_colour
			=	writeToken (name +++ ":")				>>>
				alignTo 35								>>>
				writeExtendedColour extended_colour		>>>
				advanceLine
		
		write_filters :: !Int ![TacticFilter] -> FileM Dummy Dummy
		write_filters n [filter:filters]
			=	writeToken "_WinTacticList"				>>>
				writeNumber n							>>>
				alignTo 35								>>>
				writeString filter.tfTitle				>>>
				writeToken " "							>>>
				writeFilter filter.tfNameFilter filter.tfList
														>>>
				advanceLine								>>>
				write_filters (n+1) filters
		write_filters _ []
			=	returnM Dummy

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeExtendedColour :: !ExtendedColour -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeExtendedColour extended_colour
	=	writeToken "(R:"								>>>
		writeNumber extended_colour.exRed				>>>
		writeToken ",G:"								>>>
		writeNumber extended_colour.exGreen				>>>
		writeToken ",B:"								>>>
		writeNumber extended_colour.exBlue				>>>
		writeToken ",H:"								>>>
		writeNumber extended_colour.exHue				>>>
		writeToken ",L:"								>>>
		writeNumber extended_colour.exLum				>>>
		writeToken ",S:"								>>>
		writeNumber extended_colour.exSat				>>>
		writeToken ")"

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeFilter :: !(Maybe NameFilter) ![CName] -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeFilter (Just filter) names
	# pos												= if filter.nfPositive "+" "-"
	=	writeToken pos									>>>
		writeToken " "									>>>
		writeString {c \\ c <- filter.nfFilter}
writeFilter Nothing [name:names]
	# sep												= if (isEmpty names) "" " "
	=	writeToken name									>>>
		writeToken sep									>>>
		writeFilter Nothing names						>>>
		returnM Dummy
writeFilter Nothing []
	=	returnM Dummy

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeWindowInfo :: ![WindowId] !WindowInfo -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeWindowInfo opened winfo
	# title												= make_title winfo.wiId
	| title == ""										= returnM Dummy
	= writeWindow (isMember winfo.wiId opened) title winfo
	where
		make_title :: !WindowId -> String
		make_title WinHints								= "WinHints"
		make_title WinProjectCenter						= "WinProjectCenter"
		make_title (WinProof _)							= "WinProof"
		make_title WinSectionCenter						= "WinSectionCenter"
		make_title (WinTacticList n)					= "WinTacticList" +++ toString n
		make_title _									= ""

// -------------------------------------------------------------------------------------------------------------------------------------------------
writeWindow :: !Bool !String !WindowInfo -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
writeWindow opened title winfo
	#	opened											= if opened "OPENED" "CLOSED"
	=	writeToken title								>>>
		writeToken ":"									>>>
		alignTo 35										>>>
		writeToken opened								>>>
		writeToken " "									>>>
		writeNumber winfo.wiStoredPos.vx				>>>
		writeToken "x"									>>>
		writeNumber winfo.wiStoredPos.vy				>>>
		writeToken " "									>>>
		writeNumber winfo.wiStoredWidth					>>>
		writeToken "x"									>>>
		writeNumber winfo.wiStoredHeight				>>>
		advanceLine






















// -------------------------------------------------------------------------------------------------------------------------------------------------
readOptions :: !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
readOptions pstate
	# (error, _, pstate)								= applyFileM (applicationpath "") "options" "" FReadText Dummy read_lines pstate
	| isError error										= showError error pstate
	= pstate
	where
		read_lines :: FileM Dummy Dummy
		read_lines
			=	read_line								>>= \_ ->
				ifEOF (returnM Dummy) read_lines
		
		read_line :: FileM Dummy Dummy
		read_line
			=	lookAheadF
					[ ("FirstRun",						readFirstRun)
					
					, ("DefinitionWindowBG",			readDefinitionWindowBG)
					, ("DefinitionListWindowBG",		readDefinitionListWindowBG)
					, ("HintWindowBG",					readHintWindowBG)
					, ("ProjectCenterBG",				readProjectCenterBG)
					, ("SectionCenterBG",				readSectionCenterBG)
					, ("TacticListBG",					readTacticListBG)
					, ("TheoremListWindowBG",			readTheoremListWindowBG)
					
					, ("Hints apply threshold",			readHintsApplyThreshold)
					, ("Hints view threshold",			readHintsViewThreshold)
					, ("Start with about",				readAboutStart)
					, ("Show |-bars",					readShowIndents)
					, ("WinHints",						readWindow WinHints				"WinHints")
					, ("WinProjectCenter",				readWindow WinProjectCenter		"WinProjectCenter")
					, ("WinProof",						readWindow (WinProof nilPtr)	"WinProof")
					, ("WinSectionCenter",				readWindow WinSectionCenter		"WinSectionCenter")
					, ("WinTacticList0",				readWindow (WinTacticList 0)	"WinTacticList0")
					, ("WinTacticList1",				readWindow (WinTacticList 1)	"WinTacticList1")
					, ("WinTacticList2",				readWindow (WinTacticList 2)	"WinTacticList2")
					, ("WinTacticList3",				readWindow (WinTacticList 3)	"WinTacticList3")
					, ("WinTacticList4",				readWindow (WinTacticList 4)	"WinTacticList4")
					, ("_WinTacticList0",				readTacticList 0)
					, ("_WinTacticList1",				readTacticList 1)
					, ("_WinTacticList2",				readTacticList 2)
					, ("_WinTacticList3",				readTacticList 3)
					, ("_WinTacticList4",				readTacticList 4)
					] skipLine

// -------------------------------------------------------------------------------------------------------------------------------------------------
readAboutStart :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readAboutStart
	=	readToken "Start with about:"					>>>
		lookAhead
			[ ("True",		True,						accStates (store True))
			, ("False",		True,						accStates (store False))
			] (returnM Dummy)							>>>
		advanceLine
	where
		store :: !Bool !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store boolean _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optStartWithAboutDialog = boolean})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readDefinitionWindowBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readDefinitionWindowBG
	=	readToken "DefinitionWindowBG:"					>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optDefinitionWindowBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readDefinitionListWindowBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readDefinitionListWindowBG
	=	readToken "DefinitionListWindowBG:"				>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optDefinitionListWindowBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readExtendedColour :: FileM Dummy ExtendedColour
// -------------------------------------------------------------------------------------------------------------------------------------------------
readExtendedColour
	=	readToken "(R:"									>>>
		readNumber										>>= \red ->
		readToken ",G:"									>>>
		readNumber										>>= \green ->
		readToken ",B:"									>>>
		readNumber										>>= \blue ->
		readToken ",H:"									>>>
		readNumber										>>= \hue ->
		readToken ",L:"									>>>
		readNumber										>>= \lum ->
		readToken ",S:"									>>>
		readNumber										>>= \sat ->
		readToken ")"									>>>
		returnM {exRed = red, exGreen = green, exBlue = blue, exHue = hue, exLum = lum, exSat = sat}

// -------------------------------------------------------------------------------------------------------------------------------------------------
readFirstRun :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readFirstRun
	=	readToken "FirstRun"							>>>
		accStates first_run								>>>
		advanceLine
	where
		first_run :: !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		first_run _ _ _ _ pstate
			# pstate									= openProjectCenter pstate
			# pstate									= openSectionCenter pstate
			# pstate									= openTacticList 0 pstate
			= (OK, Dummy, Dummy, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintsApplyThreshold :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintsApplyThreshold
	=	readToken "Hints apply threshold:"				>>>
		readNumber										>>= \apply_threshold ->
		accStates (store apply_threshold)				>>>
		advanceLine
	where
		store :: !Int !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store apply_threshold _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stOptions.optHintsApplyThreshold = apply_threshold})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintsViewThreshold :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintsViewThreshold
	=	readToken "Hints view threshold:"				>>>
		readNumber										>>= \view_threshold ->
		accStates (store view_threshold)				>>>
		advanceLine
	where
		store :: !Int !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store view_threshold _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stOptions.optHintsViewThreshold = view_threshold})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintWindowBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readHintWindowBG
	=	readToken "HintWindowBG:"						>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optHintWindowBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readProjectCenterBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readProjectCenterBG
	=	readToken "ProjectCenterBG:"					>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optProjectCenterBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readSectionCenterBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readSectionCenterBG
	=	readToken "SectionCenterBG:"					>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optSectionCenterBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readShowIndents :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readShowIndents
	=	readToken "Show |-bars:"						>>>
		lookAhead
			[ ("True",		True,						accStates (store True))
			, ("False",		True,						accStates (store False))
			] (returnM Dummy)							>>>
		advanceLine
	where
		store :: !Bool !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store boolean _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optShowIndents = boolean})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readTacticListBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readTacticListBG
	=	readToken "TacticListBG:"						>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optTacticListBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readTheoremListWindowBG :: FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readTheoremListWindowBG
	=	readToken "TheoremListWindowBG:"				>>>
		readExtendedColour								>>= \extended_colour ->
		accStates (store extended_colour)				>>>
		advanceLine
	where
		store :: !ExtendedColour !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store extended_colour _ _ _ _ pstate
			= (OK, Dummy, Dummy, {pstate & ls.stDisplayOptions.optTheoremListWindowBG = extended_colour})

// -------------------------------------------------------------------------------------------------------------------------------------------------
readOpenClosed :: FileM Dummy Bool
// -------------------------------------------------------------------------------------------------------------------------------------------------
readOpenClosed
	=	lookAhead
			[ ("OPENED", True,							returnM True)
			, ("CLOSED", True,							returnM False)
			] (parseErrorM "Expected OPENED or CLOSED.")

// -------------------------------------------------------------------------------------------------------------------------------------------------
readTacticList :: !Int -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readTacticList n
	=	readToken ("_WinTacticList" +++ toString n)		>>>
		readString										>>= \title ->
		lookAheadF
			[ ("+",		read_positive_filter)
			, ("-",		read_negative_filter)
			]
			(			read_tactic_list
			)											>>= \(mb_filter, list) ->
		advanceLine										>>>
		accStates (store n title mb_filter list)
	where
		read_positive_filter
			=	readToken "+"							>>>
				readString								>>= \filter ->
				returnM (Just {nfPositive = True, nfFilter = [c \\ c <-: filter]}, [])
		read_negative_filter
			=	readToken "-"							>>>
				readString								>>= \filter ->
				returnM (Just {nfPositive = False, nfFilter = [c \\ c <-: filter]}, [])
		read_tactic_list
			=	repeatUntilM "\n" (readName "Tactic")	>>= \names ->
				returnM (Nothing, names)
		
		store :: !Int !String !(Maybe NameFilter) ![CName] !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store n title mb_filter names _ _ _ _ pstate
			# filter									= {tfTitle = title, tfNameFilter = mb_filter, tfList = names}
			# (filters, pstate)							= pstate!ls.stTacticFilters
			# filters									= updateAt n filter filters
			# pstate									= {pstate & ls.stTacticFilters = filters}
			// names for tactic filters have lost support....
//			# (menu_ids, pstate)						= pstate!ls.stMenus.tactic_list_ids
//			# menu_id									= menu_ids !! n
//			# menu_title								= toString (n+1) +++ ". " +++ title
//			# pstate									= appPIO (setMenuElementTitles [(menu_id, menu_title)]) pstate
			= (OK, Dummy, Dummy, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
readWindow :: !WindowId !String -> FileM Dummy Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
readWindow id name
	=	readToken name									>>>
		readToken ":"									>>>
		readOpenClosed									>>= \opened ->
		readNumber										>>= \vx ->
		readToken "x"									>>>
		readNumber										>>= \vy ->
		readNumber										>>= \width ->
		readToken "x"									>>>
		readNumber										>>= \height ->
		accStates (store vx vy width height opened)		>>>
		advanceLine
	where
		store :: !Int !Int !Int !Int !Bool !String !Int !Int !Dummy !*PState -> (!Error, !Dummy, !Dummy, !*PState)
		store vx vy width height opened _ _ _ _ pstate
			# (winfo, pstate)							= newWindowInfo id pstate
			# winfo										= {winfo	& wiStoredPos		= {vx=vx, vy=vy}
																	, wiStoredWidth		= width
																	, wiStoredHeight	= height
																	, wiOpened			= False
														  }
			# (winfos, pstate)							= pstate!ls.stWindows
			# pstate									= {pstate & ls.stWindows = [winfo:winfos]}
			# pstate									= case opened of
															True	-> case id of
																			WinProjectCenter		-> openProjectCenter pstate
																			WinSectionCenter		-> openSectionCenter pstate
																			WinTacticList n			-> openTacticList n pstate
																			_						-> pstate
															False	-> pstate
			= (OK, Dummy, Dummy, pstate)