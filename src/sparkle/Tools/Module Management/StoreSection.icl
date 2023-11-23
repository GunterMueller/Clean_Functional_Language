/*
** Program: Clean Prover System
** Module:  StoreSection (.dcl)
** 
** Author:  Maarten de Mol
** Created: 23 February 2001
*/

implementation module
	StoreSection

import
	StdEnv,
	StdIO,
	BindLexeme,
	CoreTypes,
	Directory,
	ProveTypes,
	SectionMonad,
	PolishWrite,
	States,
	RWSDebug

// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedSymbol :: !CName ![HeapPtr] !*CHeaps !*CProject -> (!Bool, !HeapPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedSymbol name [ptr:ptrs] heaps prj
	# (error, named, heaps, prj)		= getDefinitionName ptr heaps prj
	| isError error						= findNamedSymbol name ptrs heaps prj
	| name == named						= (True, ptr, heaps, prj)
	= findNamedSymbol name ptrs heaps prj
findNamedSymbol name [] heaps prj
	= (False, DummyValue, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedTypedSymbol :: !CName !CName ![HeapPtr] !*CHeaps !*CProject -> (!Bool, !HeapPtr, !*CHeaps, !*CProject)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedTypedSymbol name type [ptr:ptrs] heaps prj
	# (error, named, heaps, prj)		= getDefinitionName ptr heaps prj
	| isError error						= findNamedTypedSymbol name type ptrs heaps prj
	| name <> named						= findNamedTypedSymbol name type ptrs heaps prj
	# (error, symbol_type, heaps, prj)	= getSymbolType ptr heaps prj
	| isError error						= findNamedTypedSymbol name type ptrs heaps prj
	# (error, ftype, heaps, prj)		= FormattedShow {DummyValue & fiNeedBrackets = True} symbol_type heaps prj
	| isError error						= findNamedTypedSymbol name type ptrs heaps prj
	| toText ftype <> type				= findNamedTypedSymbol name type ptrs heaps prj
	= (True, ptr, heaps, prj)
findNamedTypedSymbol _ _ [] heaps prj
	= (False, DummyValue, heaps, prj)

// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedTheorem :: !CName ![TheoremPtr] !*CHeaps -> (!Bool, !TheoremPtr, !*CHeaps)
// -------------------------------------------------------------------------------------------------------------------------------------------------
findNamedTheorem name [ptr:ptrs] heaps
	# (named, heaps)					= getPointerName ptr heaps
	| name == named						= (True, ptr, heaps)
	= findNamedTheorem name ptrs heaps
findNamedTheorem name [] heaps
	= (False, nilPtr, heaps)














// -------------------------------------------------------------------------------------------------------------------------------------------------
fileExists :: !String !*PState -> (!Bool, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
fileExists file_name pstate
	= accFiles (try_to_open file_name) pstate
	where
		try_to_open :: !String !*Files -> (!Bool, !*Files)
		try_to_open file_name files
			# (ok1, file, files)		= fopen file_name FReadText files
			# (ok2, files)				= fclose file files
			= (ok1 && ok2, files)

// -------------------------------------------------------------------------------------------------------------------------------------------------
createFile :: !String !*PState -> (!Maybe *File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
createFile file_name pstate
	= accFiles (create file_name) pstate
	where
		create :: !String !*Files -> (!Maybe *File, !*Files)
		create file_name files
			# (ok, file, files)			= fopen file_name FWriteText files
			| not ok					= (Nothing, files)
			= (Just file, files)

// -------------------------------------------------------------------------------------------------------------------------------------------------
openFile :: !String !*PState -> (!Bool, !*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
openFile file_name pstate
	# ((ok, file), pstate)				= accFiles (f_open file_name FReadText) pstate
	= (ok, file, pstate)
	where
		f_open file_name mode files
			# (ok, file, files)			= fopen file_name mode files
			= ((ok, file), files)

// -------------------------------------------------------------------------------------------------------------------------------------------------
closeFile :: !*File !*PState -> (!Bool, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
closeFile file pstate
	= accFiles (fclose file) pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
truncPath :: !String -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
truncPath text
	# text_size							= size text
	# index								= last_separator (-1) 0 text_size text
	= text%(index+1,text_size-1)
	where
		last_separator :: !Int !Int !Int !String -> Int
		last_separator last_found index text_size text
			| index >= text_size		= last_found
			# char						= text.[index]
			# is_separator				= isMember char ['\\', '/']
			# last_found				= if is_separator index last_found
			= last_separator last_found (index+1) text_size text

// -------------------------------------------------------------------------------------------------------------------------------------------------
askUser :: !String !SectionPtr !Section !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
askUser file_name ptr section pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (yes_id, pstate)					= accPIO openId pstate
	# (no_id, pstate)					= accPIO openId pstate
	= snd (openModalDialog Nothing (dialog dialog_id yes_id no_id) pstate)
	where
		dialog dialog_id yes_id no_id
			= Dialog "Overwrite?"
				(		TextControl		"File already exists. Overwrite?"
											[]
					:+:	ButtonControl	"No"
											[ ControlPos		(Right, zero)
											, ControlId			no_id
											, ControlFunction	(noLS (closeWindow dialog_id))
											]
					:+: ButtonControl	"Yes"
											[ ControlPos		(LeftOf no_id, zero)
											, ControlId			yes_id
											, ControlFunction	(noLS (store file_name ptr section o closeWindow dialog_id))
											]
				)
				[	WindowId			dialog_id
				,	WindowClose			(noLS (closeWindow dialog_id))
				,	WindowOk			yes_id
				,	WindowCancel		no_id
				]

// -------------------------------------------------------------------------------------------------------------------------------------------------
notifyUser :: !String !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
notifyUser text pstate
	# (dialog_id, pstate)				= accPIO openId pstate
	# (ok_id, pstate)					= accPIO openId pstate
	= snd (openModalDialog Nothing (dialog dialog_id ok_id) pstate)
	where
		dialog dialog_id ok_id
			= Dialog "Notification"
				(		TextControl		text
											[]
					:+:	ButtonControl	"Ok"
											[ ControlPos		(Right, zero)
											, ControlId			ok_id
											, ControlFunction	(noLS (closeWindow dialog_id))
											]
				)
				[	WindowId			dialog_id
				,	WindowClose			(noLS (closeWindow dialog_id))
				,	WindowOk			ok_id
				,	WindowCancel		ok_id
				]























// -------------------------------------------------------------------------------------------------------------------------------------------------
addSpaces :: !Int !String -> String
// -------------------------------------------------------------------------------------------------------------------------------------------------
addSpaces n text
	# size_text								= size text
	# additional							= n - size_text
	# additional							= if (additional < 0) 0 additional
	# spaces								= createArray additional ' '
	= text +++ spaces

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeSection :: !SectionPtr !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeSection ptr pstate
	# (section, pstate)						= accHeaps (readPointer ptr) pstate
	# file_name								= applicationpath ("Sections\\" +++ section.seName +++ ".sec")
	# (exists, pstate)						= fileExists file_name pstate
	| not exists							= store file_name ptr section pstate
	= askUser file_name ptr section pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
store :: !String !SectionPtr !Section !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
store file_name ptr section pstate
	# (mb_file, pstate)						= createFile file_name pstate
	| isNothing mb_file						= showError [X_OpenFile file_name] pstate
	# file									= fromJust mb_file
	# (theorems, pstate)					= accHeaps (readPointers section.seTheorems) pstate
	# used_theorems							= removeDup (flatten [theorem.thProof.pUsedTheorems \\ theorem <- theorems])
	# used_symbols							= removeDup (flatten [theorem.thProof.pUsedSymbols \\ theorem <- theorems])
	# file									= fwrites "SECTION DEPENDENCIES:\n" file
	# (file, pstate)						= storeUsedTheorems used_theorems ptr file pstate
	# (file, pstate)						= storeUsedSymbols used_symbols file pstate
	# file									= fwrites "\n" file
	# file									= fwrites "SECTION DEFINES:\n" file
	# theorems								= sortBy (\t1 t2 -> t1.thName < t2.thName) theorems
	# (file, pstate)						= uuwalk (storeDefinedTheorem used_symbols) theorems file pstate
	# file									= fwrites "\n" file
	# (file, pstate)						= uuwalk (storeTheorem used_symbols) theorems file pstate
	# file									= fwrites "\n" file
	# (ok, pstate)							= closeFile file pstate
	| not ok								= showError [X_WriteToFile file_name] pstate
	= notifyUser "Section succesfully saved." pstate

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeDefinedTheorem :: ![HeapPtr] !Theorem !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeDefinedTheorem used_symbols theorem file pstate
	# file									= fwrites "  THEOREM " file
	# file									= fwrites (addSpaces 25 theorem.thName) file
	# file									= fwrites ": " file
	# (file, pstate)						= accHeapsProject (polishWrite used_symbols theorem.thInitial file) pstate
	# file									= fwrites "\n" file
	= (file, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeUsedTheorems :: ![TheoremPtr] !SectionPtr !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeUsedTheorems [ptr:ptrs] section_ptr file pstate
	# (theorem, pstate)						= accHeaps (readPointer ptr) pstate
	| theorem.thSection == section_ptr		= storeUsedTheorems ptrs section_ptr file pstate
	# (section, pstate)						= accHeaps (readPointer theorem.thSection) pstate
	# file									= fwrites ("  THEOREM " +++ (addSpaces 26 theorem.thName)) file
	# file									= fwrites (" (" +++ section.seName +++ ")\n") file
	= storeUsedTheorems ptrs section_ptr file pstate
storeUsedTheorems [] _ file pstate
	= (file, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeUsedSymbols :: ![HeapPtr] !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeUsedSymbols [ptr:ptrs] file pstate
	# (_, name, pstate)						= accErrorHeapsProject (getDefinitionName ptr) pstate
	# (_, symbol_type, pstate)				= accErrorHeapsProject (getSymbolType ptr) pstate
	# (_, ftype, pstate)					= accErrorHeapsProject (FormattedShow {DummyValue & fiNeedBrackets = True} symbol_type) pstate
	# type_text								= toText ftype
	# file									= fwrites ("  SYMBOL " +++ (addSpaces 25 name) +++ ":: \"" +++ type_text +++ "\"\n") file
	= storeUsedSymbols ptrs file pstate
storeUsedSymbols [] file pstate
	= (file, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeTheorem :: ![HeapPtr] !Theorem !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeTheorem used_symbols theorem file pstate
	# file									= store_header theorem.thHintScore file
	# file									= fwrites "  " file
	# file									= fwrites theorem.thName file
	# file									= fwrites "\n" file
	# depends								= get_used_indexes theorem.thProof.pUsedSymbols used_symbols
	# file									= store_depends depends file
	# file									= fwrites "PROOF:\n" file
	# (file, pstate)						= storeProofPtrs 2 [0] [theorem.thProof.pTree] used_symbols file pstate
	# file									= fwrites "\n" file
	= (file, pstate)
	where
		store_header Nothing file
			= fwrites "THEOREM:\n" file
		store_header (Just (apply, applyf, lr, rl)) file
			# file							= fwrites "THEOREM " file
			# file							= fwrites (toString apply) file
			# file							= fwrites "-" file
			# file							= fwrites (toString applyf) file
			# file							= fwrites "-" file
			# file							= fwrites (toString lr) file
			# file							= fwrites "-" file
			# file							= fwrites (toString rl) file
			# file							= fwrites ":\n" file
			= file
		
		store_depends depends file
			# file							= fwrites "DEPENDS:\n" file
			# file							= fwrites "  " file
			# file							= fwrites depends file
			# file							= fwrites "\n" file
			= file
		
		get_used_indexes :: ![HeapPtr] ![HeapPtr] -> String
		get_used_indexes [ptr:ptrs] all_used
			# index							= find_index 0 ptr all_used
			# more							= get_used_indexes ptrs all_used
			| more == ""					= toString index
			= toString index +++ " " +++ more
		get_used_indexes [] all_used
			= ""
		
		find_index :: !Int !HeapPtr ![HeapPtr] -> Int
		find_index index ptr [used:more_used]
			| ptr == used					= index
			= find_index (index+1) ptr more_used
		find_index index ptr []
			= -1

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeProofPtrs :: !Int ![Int] ![ProofTreePtr] ![HeapPtr] !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeProofPtrs indent [num:nums] [ptr:ptrs] used_symbols file pstate
	# (proof, pstate)						= accHeaps (readPointer ptr) pstate
	# (file, pstate)						= storeProof indent num proof used_symbols file pstate
	= storeProofPtrs indent nums ptrs used_symbols file pstate
storeProofPtrs indent [] [] used_symbols file pstate
	= (file, pstate)

// -------------------------------------------------------------------------------------------------------------------------------------------------
storeProof :: !Int !Int !ProofTree ![HeapPtr] !*File !*PState -> (!*File, !*PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
storeProof indent num (ProofLeaf goal) used_symbols file pstate
	# file									= fwrites {c \\ c <- repeatn indent ' '} file
	# num_text								= if (num <= 0) "" (toString num +++ ". ")
	# file									= fwrites num_text file
	# file									= fwrites "*\n" file
	= (file, pstate)
storeProof indent num (ProofNode _ tactic children) used_symbols file pstate
	# file									= fwrites {c \\ c <- repeatn indent ' '} file
	# num_text								= if (num <= 0) "" (toString num +++ ". ")
	# file									= fwrites num_text file
	# new_indent							= indent + size num_text
	# (file, pstate)						= accHeapsProject (polishWrite used_symbols tactic file) pstate
	# file									= fwrites "\n" file
	= case length children of
		0	-> (file, pstate)
		1	-> storeProofPtrs new_indent [0] children used_symbols file pstate
		_	-> storeProofPtrs new_indent (map inc (indexList children)) children used_symbols file pstate



































// -------------------------------------------------------------------------------------------------------------------------------------------------
selectValidFile :: ![CName] !*PState -> (Maybe CName, *PState)
// -------------------------------------------------------------------------------------------------------------------------------------------------
selectValidFile names pstate
	# names									= sort names
	# (section_ptrs, pstate)				= pstate!ls.stSections
	# (section_names, pstate)				= accHeaps (getPointerNames section_ptrs) pstate
	# (dialog_id, pstate)					= accPIO openId pstate
	# (dialog_rid, pstate)					= accPIO openRId pstate
	# (names_rid, pstate)					= accPIO openRId pstate
	# (load_id, pstate)						= accPIO openId pstate
	# (cancel_id, pstate)					= accPIO openId pstate
	# ((_, mb_mb_name), pstate)				= openModalDialog Nothing (dialog dialog_id dialog_rid names_rid load_id cancel_id names section_names) pstate
	| isNothing mb_mb_name					= (Nothing, pstate)
	= (fromJust mb_mb_name, pstate)
	where
		dialog dialog_id dialog_rid names_rid load_id cancel_id names section_names
			= Dialog "Load section"
				(		Receiver			dialog_rid set_name
												[]
					:+:	MarkUpControl		[CmBText "Select a stored section to load:"]
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	getDialogBackgroundColour
												]
												[]
					:+:	boxedMarkUp			Black DoNotResize (names_text Nothing names section_names)
												[ MarkUpFontFace			"Times New Roman"
												, MarkUpTextSize			10
												, MarkUpBackgroundColour	White
												, MarkUpLinkStyle			False Black White False Blue White
												, MarkUpWidth				200
												, MarkUpNrLinesI			15 15
												, MarkUpHScroll
												, MarkUpVScrollI			1
												, MarkUpReceiver			names_rid
												, MarkUpEventHandler		(sendHandler dialog_rid)
												]
												[ ControlPos				(Left, zero)
												]
					:+:	ButtonControl		"Load"
												[ ControlPos				(Right, zero)
												, ControlSelectState		Unable
												, ControlId					load_id
												, ControlFunction			(noLS (closeWindow dialog_id))
												]
					:+:	ButtonControl		"Cancel"
												[ ControlPos				(LeftTop, zero)
												, ControlHide
												, ControlId					cancel_id
												, ControlFunction			cancel_close
												]
				)
				[ WindowId					dialog_id
				, WindowClose				cancel_close
				, WindowOk					load_id
				, WindowCancel				cancel_id
				]
			where
				cancel_close :: !(!Maybe CName, !*PState) -> (!Maybe CName, !*PState)
				cancel_close (_, pstate)
					= (Nothing, closeWindow dialog_id pstate)
				
				set_name :: !CName !(!Maybe CName, !*PState) -> (!Maybe CName, !*PState)
				set_name name (_, pstate)
					# pstate				= appPIO (enableControl load_id) pstate
					# fnames				= names_text (Just name) names section_names
					# pstate				= changeMarkUpText names_rid fnames pstate
					= (Just name, pstate)
				
				names_text :: !(Maybe CName) ![CName] ![CName] -> MarkUpText CName
				names_text selected [name:names] sections
					# fname					= case isMember name sections of
												True	->	[ CmColour				LightGrey
															, CmSpaces				1
															, CmText				name
															, CmSpaces				1
															, CmIText				"(already loaded)"
															, CmEndColour
															, CmFillLine
															, CmNewlineI			False 1 (Just almost_white)
															]
												False	->	case (Just name == selected) of
																True	->	[ CmBackgroundColour	Yellow
																			, CmSpaces				1
																			, CmText				name
																			, CmFillLine
																			, CmEndBackgroundColour
																			, CmNewlineI			False 1 (Just almost_white)
																			]
																False	->	[ CmSpaces				1
																			, CmLink				name name
																			, CmNewlineI			False 1 (Just almost_white)
																			]
					# fnames				= names_text selected names sections
					= fname ++ fnames
					where
						almost_white = RGB {r=235, g=235, b=235}
				names_text _ [] _
					= []

// -------------------------------------------------------------------------------------------------------------------------------------------------
restoreSection :: !(Maybe CName) !*PState -> *PState
// -------------------------------------------------------------------------------------------------------------------------------------------------
restoreSection mb_name pstate
	# section_path							= applicationpath "Sections"
	# ((_, path), pstate)					= pd_StringToPath section_path pstate
	# ((_, contents), pstate)				= getDirectoryContents path pstate
	# valid_files							= get_valid_files contents
	# (mb_valid_file, pstate)				= case mb_name of
												(Just valid_file)	-> (Just valid_file, pstate)
												Nothing				-> selectValidFile valid_files pstate
	| isNothing mb_valid_file				= pstate
	# name									= fromJust mb_valid_file
	# (error, new_ptr, pstate)				= applySectionM name readSection restore pstate
	| is_unrecovered error					= notifyUser "Loading of section aborted." pstate
	| isError error							= showError error pstate
	# (sections, pstate)					= pstate!ls.stSections
	# pstate								= {pstate & ls.stSections = [new_ptr:sections]}
//	# pstate								= notifyUser ("Section '" +++ name +++ "' successfully restored.") pstate
	# pstate								= broadcast Nothing CreatedSection pstate
	| isJust mb_name						= pstate
	# (opened, pstate)						= isWindowOpened WinHints False pstate
	| not opened							= pstate
	# (winfo, pstate)						= get_Window WinHints pstate
	# (_, pstate)							= asyncSend (fromJust winfo.wiNormalRId) CmdRefreshAlways pstate
	= pstate
	where
		get_valid_files :: ![DirEntry] -> [CName]
		get_valid_files [entry=:{fileName}:entries]
			# name_size						= size fileName
			# last_four						= fileName % (name_size-4, name_size-1)
			| last_four <> ".sec"			= get_valid_files entries
			# without_four					= fileName % (0, name_size - 5)
			= [without_four: get_valid_files entries]
		get_valid_files []
			= []
		
		is_unrecovered :: !Error -> Bool
		is_unrecovered [X_UnrecoveredError]
			= True
		is_unrecovered _
			= False
		
		restore name pstate
			= restoreSection (Just name) pstate


























// -------------------------------------------------------------------------------------------------------------------------------------------------
readSection :: SectionM Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
readSection
	=	setMessage "Loading preamble"					>>>
		advanceLine										>>>
		readToken "SECTION DEPENDENCIES:"				>>>
		advanceLine										>>>
		parseDepends									>>>
		checkDependencies								>>>
		readToken "SECTION DEFINES:"					>>>
		advanceLine										>>>
		parseDefined 0									>>= \nr_theorems ->
		repeatM nr_theorems parseTheorem				>>>
		returnM DummyValue

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDefined :: !Int -> SectionM Int
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDefined count
	=	lookAheadF
			[ ("THEOREM",	parse_theorem				>>> parseDefined (count+1))
			, ("\n",		advanceLine					>>> returnM count)
			]
			(				parseErrorM "THEOREM or empty line expected."
			)
	where
		parse_theorem
			=	readToken "THEOREM"						>>>
				readName "theorem name"					>>= \name ->
				readToken ":"							>>>
				parseProp								>>= \p ->
				addTheorem name p						>>>
				advanceLine

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepends :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepends
	=	lookAheadF
			[ ("THEOREM",	parse_theorem_depends		>>> parseDepends)
			, ("SYMBOL",	parse_symbol_depends		>>> parseDepends)
			, ("\n",		advanceLine)
			]
			(				parseErrorM "THEOREM, SYMBOL or empty line expected."
			)
	where
		parse_symbol_depends
			=	readToken "SYMBOL"						>>>
				readWhile in_name						>>= \name ->
				readToken "::"							>>>
				readString								>>= \type ->
				addUsedSymbol name type					>>>
				advanceLine
		parse_theorem_depends
			=	readToken "THEOREM"						>>>
				readName "theorem name"					>>= \name ->
				readToken "("							>>>
				readName "section name"					>>= \section_name ->
				readToken ")"							>>>
				addUsedTheorem name section_name		>>>
				advanceLine
		
		in_name char
				= not (isMember char [' ', ':', '\t'])

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProof :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProof
	=	repeatUntilM "\n" parse_tactic					>>>
		returnM Dummy
	where
		parse_tactic
			=	lookAheadF
					[ ("0",		parse_n_tactic)
					, ("1",		parse_n_tactic)
					, ("2",		parse_n_tactic)
					, ("3",		parse_n_tactic)
					, ("4",		parse_n_tactic)
					, ("5",		parse_n_tactic)
					, ("6",		parse_n_tactic)
					, ("7",		parse_n_tactic)
					, ("8",		parse_n_tactic)
					, ("9",		parse_n_tactic)
					]
					( 			parseMaybeTactic >>> advanceLine
					)
			where
				parse_n_tactic
					=	newBranch						>>>
						readNumber						>>>
						readToken "."					>>>
						parseMaybeTactic				>>>
						advanceLine

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTheorem :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTheorem
	=	readToken "THEOREM"								>>>
		parse_hint_score								>>= \hint_score ->
		readToken ":"									>>>
		advanceLine										>>>
		readName "Theorem name"							>>= \name ->
		startProof name									>>>
		setMessage ("Loading theorem " +++ name)		>>>
		advanceLine										>>>
		readToken "DEPENDS:"							>>>
		advanceLine										>>>
		repeatUntilM "\n" readNumber					>>= \depends ->
		advanceLine										>>>
		readToken "PROOF:"								>>>
		advanceLine										>>>
		parseProof										>>>
		saveProof hint_score							>>>
		advanceLine
	where
		parse_hint_score :: SectionM (Maybe (Int,Int,Int,Int))
		parse_hint_score
			=	lookAheadF
					[ (":",		returnM Nothing)
					]
					(			readNumber				>>= \apply ->
								readToken "-"			>>>
								readNumber				>>= \applyf ->
								readToken "-"			>>>
								readNumber				>>= \lr ->
								readToken "-"			>>>
								readNumber				>>= \rl ->
								returnM (Just (apply,applyf,lr,rl))
					)




















// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicValue :: SectionM CBasicValueH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseBasicValue
	= lookAheadF
		[ ("(INT",		parse_int)
		, ("(CHAR",		parse_char)
		, ("(REAL",		parse_real)
		, ("(BOOL",		parse_bool)
		, ("(STRING",	parse_string)
		, ("(ARRAY",	parse_array)
		]
		(				parseErrorM "Basic value expected."
		)
	where
		parse_int
			=	readToken "(INT"						>>>
				readUntil "number" ')'					>>= \text ->
				readToken ")"							>>>
				returnM (CBasicInteger (toInt text))
		parse_char
			=	readToken "(CHAR"						>>>
				readCharacters 1						>>= \text ->
				readToken ")"							>>>
				returnM (CBasicCharacter text.[0])
		parse_real
			=	readToken "(REAL"						>>>
				readUntil "real number" ')'				>>= \text ->
				readToken ")"							>>>
				returnM (CBasicRealNumber (toReal text))
		parse_bool
			=	readToken "(BOOL"						>>>
				lookAheadF
					[ ("True",	readToken "True)"		>>> returnM (CBasicBoolean True))
					, ("False",	readToken "False)"	>>> returnM (CBasicBoolean False))
					]
					(			parseErrorM "Boolean value expected."
					)
		parse_string
			=	readToken "(STRING"						>>>
				readNumber								>>= \n ->
				readCharacters n						>>= \text ->
				readToken ")"							>>>
				returnM (CBasicString text)
		parse_array
			=	readToken "(ARRAY"						>>>
				repeatUntilM ")" parseExpr				>>= \exprs ->
				readToken ")"							>>>
				returnM (CBasicArray exprs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExpr :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExpr
	= lookAheadF
		[ ("{",			parseExprExprApply)
		, ("[",			parseExprList)
		, ("(TUPLE",	parseExprBuildTuple)
		, ("(SELECT",	parseExprSelectTuple)
		, ("(@",		parseExprSymbolApply)
		, ("(LET",		readToken "(LET"				>>> parseExprLet False)
		, ("(LET!",		readToken "(LET!"				>>> parseExprLet True)
		, ("(CASE",		parseExprCase)
		, ("(INT",		parseBasicValue					>>= \value -> returnM (CBasicValue value))
		, ("(CHAR",		parseBasicValue					>>= \value -> returnM (CBasicValue value))
		, ("(REAL",		parseBasicValue					>>= \value -> returnM (CBasicValue value))
		, ("(BOOL",		parseBasicValue					>>= \value -> returnM (CBasicValue value))
		, ("(ARRAY",	parseBasicValue					>>= \value -> returnM (CBasicValue value))
		, ("BOTTOM",	readToken "BOTTOM"				>>> returnM CBottom)
		]
		(				checkAhead isValidNameChar
							parseExprVar
							(parseErrorM "Expression expected.")
		)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprBuildTuple :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprBuildTuple
	=	readToken "(TUPLE"								>>>
		repeatUntilM ")" parseExpr						>>= \exprs ->
		readToken ")"									>>>
		returnM ((CBuildTuplePtr (length exprs)) @@# exprs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprAlgPattern :: SectionM CAlgPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprAlgPattern
	=	readToken "(PAT"								>>>
//		readNumber										>>= \index ->
//		lookupSymbol index								>>= \(ptr,name) ->
//		readToken name									>>>
		parseSymbol										>>= \ptr ->
		repeatUntilM "->" (readName "variable name")	>>= \varnames ->
		newExprVars varnames							>>= \varptrs ->
		readToken "->"									>>>
		parseExpr										>>= \expr ->
		readToken ")"									>>>
		disposeExprVars (length varnames)				>>>
		returnM		{ atpDataCons		= ptr
					, atpExprVarScope	= varptrs
					, atpResult			= expr
					}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprBasicPattern :: SectionM CBasicPatternH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprBasicPattern
	=	readToken "(PAT"								>>>
		parseBasicValue									>>= \value ->
		readToken "->"									>>>
		parseExpr										>>= \expr ->
		readToken ")"									>>>
		returnM		{ bapBasicValue		= value
					, bapResult			= expr
					}

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprCase :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprCase
	=	readToken "(CASE"								>>>
		parseExpr										>>= \expr ->
		parseExprPatterns								>>= \patterns ->
		parseExprCaseDefault							>>= \def ->
		returnM (CCase expr patterns def)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprCaseDefault :: SectionM (Maybe CExprH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprCaseDefault
	=	lookAheadF
			[ ("(YES",	parse_just)
			, ("NO",	parse_nothing)
			]
			(			parseErrorM "YES or NO expected."
			)
	where
		parse_just
			=	readToken "(YES"						>>>
				parseExpr								>>= \expr ->
				readToken ")"							>>>
				returnM (Just expr)
		parse_nothing
			=	readToken "NO"							>>>
				returnM Nothing

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprExprApply :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprExprApply
	=	readToken	"{"									>>>
		parseExpr										>>= \expr ->
		readToken "@"									>>>
		repeatUntilM "}" parseExpr						>>= \exprs ->
		readToken "}"									>>>
		returnM (expr @# exprs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLet :: !Bool -> SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLet strict
	=	parseExprLetDefs []								>>= \lets ->
		readToken "in"									>>>
		parseExpr										>>= \expr ->
		readToken ")"									>>>
		disposeExprVars (length lets)					>>>
		returnM (CLet strict lets expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLetDefs :: ![(CExprVarPtr, CExprH)] -> SectionM [(CExprVarPtr, CExprH)]
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLetDefs lets
	=	readName "let variable name"					>>= \name ->
		newExprVars [name]								>>= \ptrs ->
		readToken "="									>>>
		parseExpr										>>= \expr ->
		lookAheadF
			[ ("in",	returnM (lets ++ [(hd ptrs, expr)]))
			]
			(			parseExprLetDefs (lets ++ [(hd ptrs, expr)])
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprList :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprList
	=	readToken		"["								>>>
		lookAheadF
			[ ("]",		parse_nil nil)
			]
			(			parse_cons
			)
	where
		parse_nil value
			=	readToken "]"							>>>
				returnM value
		parse_cons
			=	parseExpr								>>= \expr ->
				lookAheadF
					[ ("]",		parse_nil (cons expr nil))
					, (":",		parse_tail expr)
					]
					(			parseErrorM "] or : expected."
					)
		parse_tail head
			=	readToken ":"							>>>
				parseExpr								>>= \tail ->
				readToken "]"							>>>
				returnM (cons head tail)
	
		nil			= CNilPtr @@# []
		cons x xs	= CConsPtr @@# [x,xs]

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprPatterns :: SectionM CCasePatternsH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprPatterns
	=	lookAheadF
			[ ("ALG",	parse_alg_patterns)
			, ("BAS",	parse_basic_patterns)
			]
			(			parseErrorM "ALG or BAS expected."
			)
	where
		parse_alg_patterns
			=	readToken "ALG"							>>>
				readNumber								>>= \n ->
				repeatM n parseExprAlgPattern			>>= \patterns ->
				typeAlgPatterns patterns				>>= \type ->
				returnM (CAlgPatterns type patterns)
		parse_basic_patterns
			=	readToken "BAS"							>>>
				readNumber								>>= \n ->
				repeatM n parseExprBasicPattern			>>= \patterns ->
				type_basic_value patterns				>>= \type ->
				returnM (CBasicPatterns type patterns)
		
		type_basic_value :: ![CBasicPatternH] -> SectionM CBasicType
		type_basic_value []
			= parseErrorM "Unable to type basic case."
		type_basic_value [p:ps]
			# (ok, type)								= typeBasicValue p.bapBasicValue
			| not ok									= parseErrorM "Unable to type basic case"
			= returnM type

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprSelectTuple :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprSelectTuple
	=	readToken "(SELECT"								>>>
		readNumber										>>= \arity ->
		readNumber										>>= \n ->
		parseExpr										>>= \tuple ->
		readToken ")"									>>>
		returnM ((CTupleSelectPtr arity n) @@# [tuple])

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprSymbolApply :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprSymbolApply
	=	readToken "(@"									>>>
//		readNumber										>>= \index ->
//		lookupSymbol index								>>= \(ptr, name) ->
//		readToken name									>>>
		parseSymbol										>>= \ptr ->
		repeatUntilM ")" parseExpr						>>= \exprs ->
		readToken ")"									>>>
		returnM (ptr @@# exprs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprVar :: SectionM CExprH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprVar
	=	readName "expression variable"					>>= \name ->
		lookupExprVar name								>>= \ptr ->
		returnM (CExprVar ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProp :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseProp
	= lookAheadF
		[ ("TRUE",		readToken "TRUE"				>>> returnM CTrue)
		, ("FALSE",		readToken "FALSE"				>>> returnM CFalse)
		, ("(=",		parsePropEq)
		, ("~",			parsePropNot)
		, ("{",			parsePropInfix)
		, ("(All",		parsePropForallE)
		, ("(Ex",		parsePropExistsE)
		, ("(ALL",		parsePropForallP)
		, ("(EX",		parsePropExistsP)
		]
		(				checkAhead isValidNameChar
							parsePropVar
							(parseErrorM "Proposition expected.")
		)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropEq :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropEq
	=	readToken "(="									>>>
		parseExpr										>>= \e1 ->
		parseExpr										>>= \e2 ->
		readToken ")"									>>>
		returnM (CEqual e1 e2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropExistsE :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropExistsE
	=	readToken "(Ex"									>>>
		readName "expression variable"					>>= \name ->
		newExprVars [name]								>>= \ptrs ->
		parseProp										>>= \p ->
		disposeExprVars 1								>>>
		readToken ")"									>>>
		returnM (CExprExists (hd ptrs) p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropExistsP :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropExistsP
	=	readToken "(EX"									>>>
		readName "proposition variable"					>>= \name ->
		newPropVars [name]								>>= \ptrs ->
		parseProp										>>= \p ->
		disposePropVars 1								>>>
		readToken ")"									>>>
		returnM (CPropExists (hd ptrs) p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropForallE :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropForallE
	=	readToken "(All"								>>>
		readName "expression variable"					>>= \name ->
		newExprVars [name]								>>= \ptrs ->
		parseProp										>>= \p ->
		disposeExprVars 1								>>>
		readToken ")"									>>>
		returnM (CExprForall (hd ptrs) p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropForallP :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropForallP
	=	readToken "(ALL"								>>>
		readName "proposition variable"					>>= \name ->
		newPropVars [name]								>>= \ptrs ->
		parseProp										>>= \p ->
		disposePropVars 1								>>>
		readToken ")"									>>>
		returnM (CPropForall (hd ptrs) p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropInfix :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropInfix
	=	readToken "{"									>>>
		parseProp										>>= \p ->
		parsePropOperator								>>= \op ->
		parseProp										>>= \q ->
		readToken "}"									>>>
		returnM (op p q)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropNot :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropNot
	=	readToken "~"									>>>
		parseProp										>>= \p ->
		returnM (CNot p)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropOperator :: SectionM (CPropH -> CPropH -> CPropH)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropOperator
	= lookAheadF
		[ ("/\\",		readToken "/\\"					>>> returnM CAnd)
		, ("\\/",		readToken "\\/"					>>> returnM COr)
		, ("->",		readToken "->"					>>> returnM CImplies)
		, ("<->",		readToken "<->"					>>> returnM CIff)
		]
		(				parseErrorM "/\\, \\/, -> or <-> expected"
		)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropVar :: SectionM CPropH
// -------------------------------------------------------------------------------------------------------------------------------------------------
parsePropVar
	=	readName "proposition variable"					>>= \name ->
		lookupPropVar name								>>= \ptr ->
		returnM (CPropVar ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSymbol :: SectionM HeapPtr
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseSymbol
	=	readNumber										>>= \index ->
		case index of
			-10		-> read_tuple_select
			_		-> read_normal index
	where
		read_normal index
			=	lookupSymbol index						>>= \(ptr, name) ->
				case (ptr == DummyValue) of
					True	->	readIdentifier			>>>
								returnM DummyValue
					False	->	readToken name			>>>
								returnM ptr
		
		read_tuple_select
			=	readNumber								>>= \arity ->
				readNumber								>>= \index ->
				returnM (CTupleSelectPtr arity index)
			






















// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepth :: SectionM Depth
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseDepth
	=	lookAheadF
			[ ("Shallow",	readToken "Shallow"			>>> returnM Shallow)
			, ("Deep",		readToken "Deep"			>>> returnM Deep)
			]
			(				parseErrorM "Depth expected."
			) 

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLocation :: SectionM ExprLocation
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseExprLocation
	=	lookAheadF
			[ ("All",		readToken "All"				>>> returnM AllSubExprs)
			]
			(				parse_selected_expr
			)
	where
		parse_selected_expr
			=	readToken "("							>>>
				readIdentifier							>>= \name ->
				readNumber								>>= \index ->
				parseMaybeInt							>>= \mb_index ->
				readToken ")"							>>>
				returnM (SelectedSubExpr name index mb_index)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFact :: SectionM UseFact
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFact
	=	lookAheadF
			[ ("(\"",		parse_applied_theorem)
			, ("(",			parse_applied_hypothesis)
			, ("\"",		parse_unapplied_theorem)
			]
			parse_unapplied_hypothesis
	where
		parse_unapplied_theorem
			=	readString								>>= \name ->
				lookupTheorem name						>>= \ptr ->
				returnM (TheoremFact ptr [])
		parse_unapplied_hypothesis
			=	readName "Hypothesis"					>>= \name ->
				lookupHypothesis name					>>= \ptr ->
				returnM (HypothesisFact ptr [])
		
		parse_applied_theorem
			=	readToken "("							>>>
				readString								>>= \name ->
				lookupTheorem name						>>= \ptr ->
				repeatUntilM ")" parseFactArgument 		>>= \args ->
				readToken ")"							>>>
				returnM (TheoremFact ptr args)
		parse_applied_hypothesis
			=	readToken "("							>>>
				readName "Hypothesis"					>>= \name ->
				lookupHypothesis name					>>= \ptr ->
				repeatUntilM ")" parseFactArgument 		>>= \args ->
				readToken ")"							>>>
				returnM (HypothesisFact ptr args)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArgument :: SectionM UseFactArgument
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseFactArgument
	=	lookAheadF
			[ ("E",			parse_expr)
			, ("P",			parse_prop)
			] parse_no
	where
		parse_expr
			=	readToken "E"							>>>
				parseExpr								>>= \expr ->
				returnM (ExprArgument expr)
		parse_prop
			=	readToken "P"							>>>
				parseProp								>>= \prop ->
				returnM (PropArgument prop)
		parse_no
			=	readToken "_"							>>>
				returnM NoArgument

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeInt :: SectionM (Maybe Int)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeInt
	=	lookAhead
			[ ("(YES",		True,	readNumber			>>= \n ->
									readToken ")"		>>>
									returnM (Just n))
			, ("NO",		True,	returnM Nothing)
			]
			(				parseErrorM "Expected a Maybe Int."
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeName :: !String -> SectionM (Maybe CName)
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeName what
	=	lookAhead
			[ ("(YES",		True,	readName what		>>= \s ->
									readToken ")"		>>>
									returnM (Just s))
			, ("NO",		True,	returnM Nothing)
			]
			(				parseErrorM ("Expected a Maybe " +++ what +++ ".")
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMoveDirection :: SectionM MoveDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMoveDirection
	=	lookAhead
			[ ("In",		True, returnM MoveIn)
			, ("Out",		True, returnM MoveOut)
			]
			(				parseErrorM "Expected a move direction ('In' or 'Out')."
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRedex :: SectionM Redex
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRedex
	=	lookAheadF
			[ ("All",		readToken "All"				>>> returnM AllRedexes)
			, ("0",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("1",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("2",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("3",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("4",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("5",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("6",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("7",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("8",			readNumber					>>= \n -> returnM (OneRedex n))
			, ("9",			readNumber					>>= \n -> returnM (OneRedex n))
			]
			(				parseErrorM "Redex expected."
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReduceAmount :: SectionM ReduceAmount
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseReduceAmount
	=	lookAheadF
			[ ("NF",		readToken "NF"				>>> returnM ReduceToNF)
			, ("RNF",		readToken "RNF"				>>> returnM ReduceToRNF)
			, ("0",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("1",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("2",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("3",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("4",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("5",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("6",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("7",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("8",			readNumber					>>= \n -> returnM (ReduceExactly n))
			, ("9",			readNumber					>>= \n -> returnM (ReduceExactly n))
			]
			(				parseErrorM "Reduce amount expected."
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteDirection :: SectionM RewriteDirection
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseRewriteDirection
	=	lookAheadF
			[ ("->",		readToken "->"				>>> returnM LeftToRight)
			, ("<-",		readToken "<-"				>>> returnM RightToLeft)
			]
			(				parseErrorM "Rewrite direction expected."
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMode :: SectionM TacticMode
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMode
	=	lookAheadF
			[ ("Implicit",	readToken "Implicit"		>>> returnM Implicit)
			, ("Explicit",	readToken "Explicit"		>>> returnM Explicit)
			]
			(				returnM Implicit
			)












// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeTactic :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseMaybeTactic
	=	lookAheadF
			[ ("*",				readToken "*"			>>>
								nextSubgoal)
			]
			parseTactic

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactic :: SectionM Dummy
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTactic
	=	parseTacticMode									>>= \mode ->
		lookAheadF
			[ ("AbsurdEqualityH",		parseTacticAbsurdEqualityH)
			, ("AbsurdEquality",		parseTacticAbsurdEquality)
			, ("Absurd",				parseTacticAbsurd)
			, ("Apply",					parseTacticApply mode)
			, ("Assume",				parseTacticAssume mode)
			, ("Axiom",					parseTacticAxiom)
			, ("Cases",					parseTacticCases mode)
			, ("Case",					parseTacticCase mode)
			, ("ChooseCaseH",			parseTacticChooseCaseH)
			, ("ChooseCase",			parseTacticChooseCase)
			, ("CompareH",				parseTacticCompareH mode)
			, ("Compare",				parseTacticCompare)
			, ("Contradiction",			parseTacticContradiction mode)
			, ("Cut",					parseTacticCut)
			, ("Definedness",			parseTacticDefinedness)
			, ("Discard",				parseTacticDiscard)
			, ("Exact",					parseTacticExact)
			, ("ExFalso",				parseTacticExFalso)
			, ("ExpandFunH",			parseTacticExpandFunH mode)
			, ("ExpandFun",				parseTacticExpandFun)
			, ("Extensionality",		parseTacticExtensionality)
			, ("GeneralizeE",			parseTacticGeneralizeE)
			, ("GeneralizeP",			parseTacticGeneralizeP)
			, ("Induction",				parseTacticInduction mode)
			, ("Introduce",				parseTacticIntroduce)
			, ("InjectiveH",			parseTacticInjectiveH mode)
			, ("Injective",				parseTacticInjective)
			, ("IntArithH",				parseTacticIntArithH mode)
			, ("IntArith",				parseTacticIntArith)
			, ("IntCompare",			parseTacticIntCompare)
			, ("MakeUnique",			parseTacticMakeUnique)
			, ("ManualDefinedness",		parseManualDefinedness)
			, ("MoveInCaseH",			parseTacticMoveInCaseH mode)
			, ("MoveInCase",			parseTacticMoveInCase)
			, ("MoveQuantorsH",			parseTacticMoveQuantorsH mode)
			, ("MoveQuantors",			parseTacticMoveQuantors)
			, ("Opaque",				parseTacticOpaque)
			, ("Reduce-",				parseTacticReduce AsInClean)
			, ("Reduce+",				parseTacticReduce Offensive)
			, ("ReduceH-",				parseTacticReduceH AsInClean mode)
			, ("ReduceH+",				parseTacticReduceH Offensive mode)
			, ("ReduceH",				parseTacticReduceH Defensive mode)
			, ("Reduce",				parseTacticReduce Defensive)
			, ("RefineUndefinednessH",	parseTacticRefineUndefinednessH mode)
			, ("RefineUndefinedness",	parseTacticRefineUndefinedness)
			, ("Reflexive",				parseTacticReflexive)
			, ("RemoveCaseH",			parseTacticRemoveCaseH mode)
			, ("RemoveCase",			parseTacticRemoveCase)
			, ("RenameE",				parseTacticRenameE)
			, ("RenameP",				parseTacticRenameP)
			, ("RenameH",				parseTacticRenameH)
			, ("Rewrite",				parseTacticRewrite mode)
			, ("SpecializeE",			parseTacticSpecializeE mode)
			, ("SpecializeP",			parseTacticSpecializeP mode)
			, ("SplitIff",				parseTacticSplitIff mode)
			, ("SplitCase",				parseTacticSplitCase mode)
			, ("Split",					parseTacticSplit mode)
			, ("Symmetric",				parseTacticSymmetric mode)
			, ("TransitiveE",			parseTacticTransitiveE)
			, ("TransitiveP",			parseTacticTransitiveP)
			, ("Transparent",			parseTacticTransparent)
			, ("Trivial",				parseTacticTrivial)
			, ("UncurryH",				parseTacticUncurryH mode)
			, ("Uncurry",				parseTacticUncurry)
			, ("Unshare",				parseTacticUnshare)
			, ("UnshareH",				parseTacticUnshareH)
			, ("WitnessE",				parseTacticWitnessE)
			, ("WitnessP",				parseTacticWitnessP)
			, ("Witness",				parseTacticWitness mode)
			]
			(							parseErrorM "Tactic expected."
			)											>>= \tactic ->
		readToken "."									>>>
		executeTactic tactic							>>>
		returnM Dummy

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurd :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurd
	=	readToken "Absurd"								>>>
		readName "Hypothesis"							>>= \name1 ->
		lookupHypothesis name1							>>= \ptr1 ->
		readName "Hypothesis"							>>= \name2 ->
		lookupHypothesis name2							>>= \ptr2 ->
		returnM (TacticAbsurd ptr1 ptr2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEquality :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEquality
	=	readToken "AbsurdEquality"						>>>
		returnM TacticAbsurdEquality

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEqualityH :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAbsurdEqualityH
	=	readToken "AbsurdEqualityH"						>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticAbsurdEqualityH ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticApply :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticApply mode
	=	readToken "Apply"								>>>
		parseFact										>>= \fact ->
		lookAheadF
			[ ("to",	parse_to fact)
			]
			(			returnM (TacticApply fact)
			)
	where
		parse_to fact
			=	readToken "to"							>>>
				readName "Hypothesis"					>>= \name ->
				lookupHypothesis name					>>= \ptr ->
				returnM (TacticApplyH fact ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAssume :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAssume mode
	=	readToken "Assume"								>>>
		parseProp										>>= \prop ->
		returnM (TacticAssume prop mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAxiom :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticAxiom
	=	readToken "Axiom"								>>>
		returnM TacticAxiom

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCase :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCase mode
	=	readToken "Case"								>>>
		parseDepth										>>= \depth ->
		lookAheadF
			[ ("0",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("1",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("2",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("3",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("4",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("5",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("6",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("7",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("8",		readNumber						>>= \n -> returnM (TacticCase depth n))
			, ("9",		readNumber						>>= \n -> returnM (TacticCase depth n))
			]
			(			readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticCaseH depth ptr mode)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCases :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCases mode
	=	readToken "Cases"								>>>
		parseExpr										>>= \expr ->
		returnM (TacticCases expr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCase :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCase
	=	readToken "ChooseCase"							>>>
		returnM TacticChooseCase

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCaseH :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticChooseCaseH
	=	readToken "ChooseCaseH"							>>>
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticChooseCaseH ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompare :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompare
	=	readToken "Compare"								>>>
		parseExpr										>>= \e1 ->
		readToken "with"								>>>
		parseExpr										>>= \e2 ->
		returnM (TacticCompare e1 e2)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompareH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCompareH mode
	=	readToken "CompareH"							>>>
		readToken "using"								>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticCompareH ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticContradiction :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticContradiction mode
	=	readToken "Contradiction"						>>>
		lookAheadF
			[ (".",		returnM (TacticContradiction mode))
			]
			(			readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticContradictionH ptr)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCut :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticCut
	=	readToken "Cut"									>>>
		parseFact										>>= \fact ->
		returnM (TacticCut fact)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDefinedness :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDefinedness
	=	readToken "Definedness"							>>>
		returnM TacticDefinedness

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDiscard :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticDiscard
	=	readToken "Discard"								>>>
		readNumber										>>= \n1 ->
		readNumber										>>= \n2 ->
		readNumber										>>= \n3 ->
		repeatM n1 (readName "Expression variable")	>>= \names1 ->
		mapM lookupExprVar names1						>>= \ptrs1 ->
		repeatM n2 (readName "Proposition variable")	>>= \names2 ->
		mapM lookupPropVar names2						>>= \ptrs2 ->
		repeatM n3 (readName "Hypothesis")				>>= \names3 ->
		mapM lookupHypothesis names3					>>= \ptrs3 ->
		returnM (TacticDiscard ptrs1 ptrs2 ptrs3)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExact :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExact
	=	readToken "Exact"								>>>
		parseFact										>>= \fact ->
		returnM (TacticExact fact)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExFalso :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExFalso
	=	readToken "ExFalso"								>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticExFalso ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFun :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFun
	=	readToken "ExpandFun"							>>>
		readIdentifier									>>= \name ->
		readNumber										>>= \index ->
		returnM (TacticExpandFun name index)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFunH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExpandFunH mode
	=	readToken "ExpandFunH"							>>>
		readIdentifier									>>= \name ->
		readNumber										>>= \index ->
		readToken "in"									>>>
		readName "Hypothesis"							>>= \hyp_name ->
		lookupHypothesis hyp_name						>>= \ptr ->
		returnM (TacticExpandFunH name index ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExtensionality :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticExtensionality
	=	readToken "Extensionality"						>>>
		readName "Variable name"						>>= \name ->
		returnM (TacticExtensionality name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralizeE :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralizeE
	=	readToken "GeneralizeE"							>>>
		parseExpr										>>= \expr ->
		readToken "to"									>>>
		readName "Expression variable"					>>= \name ->
		returnM (TacticGeneralizeE expr name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralizeP :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticGeneralizeP
	=	readToken "GeneralizeP"							>>>
		parseProp										>>= \prop ->
		readToken "to"									>>>
		readName "Expression variable"					>>= \name ->
		returnM (TacticGeneralizeP prop name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInduction :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInduction mode
	=	readToken "Induction"							>>>
		readName "Expression variable"					>>= \name ->
		lookupBoundExprVar name							>>= \ptr ->
		returnM (TacticInduction ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjective :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjective
	=	readToken "Injective"							>>>
		returnM TacticInjective

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjectiveH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticInjectiveH mode
	=	readToken "InjectiveH"							>>>
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticInjectiveH ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntroduce :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntroduce
	=	readToken "Introduce"							>>>
		repeatUntilM "." (readName "Name")				>>= \names ->
		returnM (TacticIntroduce names)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArith :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArith
	=	readToken "IntArith"							>>>
		parseExprLocation								>>= \location ->
		returnM (TacticIntArith location)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArithH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntArithH mode
	=	readToken "IntArithH"							>>>
		parseExprLocation								>>= \location ->
		readToken "to"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticIntArithH location ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntCompare :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticIntCompare
	=	readToken "IntCompare"							>>>
		returnM TacticIntCompare

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseManualDefinedness :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseManualDefinedness
	=	readToken "ManualDefinedness"					>>>
		repeatUntilM "." readString						>>= \names ->
		mapM lookupTheorem names						>>= \ptrs ->
		returnM (TacticManualDefinedness ptrs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMakeUnique :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMakeUnique
	=	readToken "MakeUnique"							>>>
		returnM TacticMakeUnique

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCase :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCase
	=	readToken "MoveInCase"							>>>
		readIdentifier									>>= \name ->
		readNumber										>>= \index ->
		returnM (TacticMoveInCase name index)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCaseH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveInCaseH mode
	=	readToken "MoveInCaseH"							>>>
		readIdentifier									>>= \name ->
		readNumber										>>= \index ->
		readToken "in"									>>>
		readName "Hypothesis"							>>= \hyp_name ->
		lookupHypothesis hyp_name						>>= \ptr ->
		returnM (TacticMoveInCaseH name index ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantors :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantors
	=	readToken "MoveQuantors"						>>>
		parseMoveDirection								>>= \dir ->
		returnM (TacticMoveQuantors dir)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantorsH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticMoveQuantorsH mode
	=	readToken "MoveQuantorsH"						>>>
		parseMoveDirection								>>= \dir ->
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticMoveQuantorsH dir ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticOpaque :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticOpaque
	=	readToken "Opaque"								>>>
		parseSymbol										>>= \ptr ->
		returnM (TacticOpaque ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduce :: !ReduceMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduce rmode
	# name							= case rmode of
										AsInClean	-> "Reduce-"
										Defensive	-> "Reduce"
										Offensive	-> "Reduce+"
	=	readToken name									>>>
		parseReduceAmount								>>= \amount ->
		parseExprLocation								>>= \loc ->
		readToken "("									>>>
		repeatUntilM ")" (readName "Variable")			>>= \varnames ->
		readToken ")"									>>>
		mapM lookupExprVar varnames						>>= \ptrs ->
		returnM (TacticReduce rmode amount loc ptrs)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduceH :: !ReduceMode !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReduceH rmode mode
	# name							= case rmode of
										AsInClean	-> "ReduceH-"
										Defensive	-> "ReduceH"
										Offensive	-> "ReduceH+"
	=	readToken name									>>>
		parseReduceAmount								>>= \amount ->
		parseExprLocation								>>= \loc ->
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		readToken "("									>>>
		repeatUntilM ")" (readName "Variable")			>>= \varnames ->
		readToken ")"									>>>
		mapM lookupExprVar varnames						>>= \ptrs ->
		returnM (TacticReduceH rmode amount loc ptr ptrs mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinedness :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinedness
	=	readToken "RefineUndefinedness"					>>>
		returnM TacticRefineUndefinedness

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinednessH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRefineUndefinednessH mode
	=	readToken "RefineUndefinednessH"				>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticRefineUndefinednessH ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReflexive :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticReflexive
	=	readToken "Reflexive"							>>>
		returnM TacticReflexive

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCase :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCase
	=	readToken "RemoveCase"							>>>
		readNumber										>>= \index ->
		returnM (TacticRemoveCase index)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCaseH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRemoveCaseH mode
	=	readToken "RemoveCase"							>>>
		readNumber										>>= \index ->
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticRemoveCaseH index ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameE :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameE
	=	readToken "RenameE"								>>>
		readName "Expression variable"					>>= \name ->
		lookupExprVar name								>>= \ptr ->
		readToken "to"									>>>
		readName "Name"									>>= \name ->
		returnM (TacticRenameE ptr name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameP :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameP
	=	readToken "RenameP"								>>>
		readName "Proposition variable"					>>= \name ->
		lookupPropVar name								>>= \ptr ->
		readToken "to"									>>>
		readName "Name"									>>= \name ->
		returnM (TacticRenameP ptr name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameH :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRenameH
	=	readToken "RenameH"								>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		readToken "to"									>>>
		readName "Name"									>>= \name ->
		returnM (TacticRenameH ptr name)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRewrite :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticRewrite mode
	=	readToken "Rewrite"								>>>
		parseRewriteDirection							>>= \dir ->
		parseRedex										>>= \redex ->
		parseFact										>>= \fact ->
		lookAheadF
			[ (".",		returnM (TacticRewrite dir redex fact))
			]
			(			readToken "in"					>>>
						readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticRewriteH dir redex fact ptr mode)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecializeE :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecializeE mode
	=	readToken "SpecializeE"							>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		readToken "with"								>>>
		parseExpr										>>= \expr ->
		returnM (TacticSpecializeE ptr expr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecializeP :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSpecializeP mode
	=	readToken "SpecializeP"							>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		readToken "with"								>>>
		parseProp										>>= \prop ->
		returnM (TacticSpecializeP ptr prop mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplit :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplit mode
	=	readToken "Split"								>>>
		parseDepth										>>= \depth ->
		lookAheadF
			[ (".",		returnM (TacticSplit depth))
			]
			(			readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticSplitH ptr depth mode)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitCase :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitCase mode
	=	readToken "SplitCase"							>>>
		readNumber										>>= \num ->
		returnM (TacticSplitCase num mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitIff :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSplitIff mode
	=	readToken "SplitIff"							>>>
		lookAheadF
			[ (".",		returnM TacticSplitIff)
			]
			(			readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticSplitIffH ptr mode)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSymmetric :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticSymmetric mode
	=	readToken "Symmetric"							>>>
		lookAheadF
			[ (".",		returnM TacticSymmetric)
			]
			(			readName "Hypothesis"			>>= \name ->
						lookupHypothesis name			>>= \ptr ->
						returnM (TacticSymmetricH ptr mode)
			)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitiveE :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitiveE
	=	readToken "TransitiveE"							>>>
		parseExpr										>>= \expr ->
		returnM (TacticTransitiveE expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitiveP :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransitiveP
	=	readToken "TransitiveP"							>>>
		parseProp										>>= \prop ->
		returnM (TacticTransitiveP prop)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransparent :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTransparent
	=	readToken "Transparent"							>>>
		parseSymbol										>>= \ptr ->
		returnM (TacticTransparent ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTrivial :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticTrivial
	=	readToken "Trivial"								>>>
		returnM TacticTrivial

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUncurry :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUncurry
	=	readToken "Uncurry"								>>>
		returnM TacticUncurry

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUncurryH :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUncurryH mode
	=	readToken "UncurryH"							>>>
		readToken "in"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticUncurryH ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUnshare :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUnshare
	=	readToken "Unshare"								>>>
		readBool										>>= \mode ->
		readNumber										>>= \letl ->
		readName "Variable"								>>= \var ->
		parseVarLocation								>>= \varl ->
		returnM (TacticUnshare mode letl var varl)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUnshareH :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticUnshareH
	=	readToken "UnshareH"							>>>
		readBool										>>= \mode ->
		readNumber										>>= \letl ->
		readName "Variable"								>>= \var ->
		parseVarLocation								>>= \varl ->
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticUnshareH mode letl var varl ptr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitnessE :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitnessE
	=	readToken "WitnessE"							>>>
		parseExpr										>>= \expr ->
		returnM (TacticWitnessE expr)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitnessP :: SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitnessP
	=	readToken "WitnessP"							>>>
		parseProp										>>= \prop ->
		returnM (TacticWitnessP prop)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitness :: !TacticMode -> SectionM TacticId
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseTacticWitness mode
	=	readToken "Witness"								>>>
		readToken "for"									>>>
		readName "Hypothesis"							>>= \name ->
		lookupHypothesis name							>>= \ptr ->
		returnM (TacticWitnessH ptr mode)

// -------------------------------------------------------------------------------------------------------------------------------------------------
parseVarLocation :: SectionM VarLocation
// -------------------------------------------------------------------------------------------------------------------------------------------------
parseVarLocation
	= lookAheadF [("All", readToken "All" >>> returnM AllVars)] (readNumber >>= \i -> returnM (JustVarIndex i))