implementation module search

import StdArray, StdEnum, StdFunc, StdMisc, StdTuple
import StdClipboard,StdControlReceiver,StdMenuElement,StdPStClass,StdWindow
import UtilStrictLists, StrictList
import EdClient
import fbi
import IDE
import UtilInterrupt
import PmParse, PmPath
import ioutil
import PmPrefs
from EdText import textToStrings
from PmDirCache import SearchDisk,FindHModule
import morecontrols,colorpickcontrol,colourclip

initFindBoxInfo :: !Prefs !*a -> *(.(FindBoxInfo *(PSt General)),*a) | Ids, accScreenPicture a
initFindBoxInfo prefs pstate
	# (dlogId,pstate)	= openId pstate
	# (intrId,pstate)	= openId pstate
	# (msgId,pstate)	= openId pstate
	# (findId,pstate)	= openId pstate
	# (closeId,pstate)	= openId pstate
	# (stringId,pstate)	= openId pstate
	# (windId,pstate)	= openId pstate
	# (recvId,pstate)	= openRId pstate
	# (windlbId,pstate)	= openExtListBoxId pstate
	# fdef				=	{ fName = prefs.src_prefs.src_fname
							, fSize = prefs.src_prefs.src_fsize
							, fStyles = []
							}
	# (fnt,pstate)	= accScreenPicture (safeOpenFixedFont fdef) pstate	// use proper font...
	# fbi				=	{ dlogId		= dlogId
							, intrId		= intrId
							, msgId			= msgId
							, findId		= findId
							, closeId		= closeId
							, stringId		= stringId
							, kind			= Implementation
							, type			= SearchImports
							, is_searching	= False
							, cleanid		= []
							, verb			= True
							, export_		= False
							, windId		= windId
							, windlbId		= windlbId
							, src_offset	= prefs.src_prefs.src_pos
							, src_font		= fnt
							, src_forg		= prefs.src_prefs.src_forc
							, src_back		= prefs.src_prefs.src_bacc
							, src_size		= prefs.src_prefs.src_siz
							, pathname		= ""
							, recvId		= recvId
							}
	= (fbi,pstate)
	
sr_find_idi :: !Bool !*(PSt General) -> *PSt General
sr_find_idi always_dialog pstate		// Find Definition & Implementation & Identifier
	# (fbi,pstate)			= getFBI pstate
	# fbi					= {fbi & kind = Identifier, type = SearchProject}
  	# (maybepath,pstate)	= sendToActiveWindow (msgGetPathName) pstate
 	| isNothing maybepath
 		# fbi				= {fbi & pathname = ""}
 		# pstate			= setFBI fbi pstate
 		= fi_dialog fbi pstate
 	# pathname				= fromJust maybepath
   	# (maybesel,pstate)		= sendToActiveWindow (msgGetSelection) pstate
 	| isNothing maybesel || always_dialog || fst (fromJust maybesel) == "" || not (CleanModId (fst (fromJust maybesel)))
 		# fbi				= {fbi & pathname = pathname}
 		# pstate			= setFBI fbi pstate
		= fi_dialog fbi pstate
 	# (selection,_)			= fromJust maybesel
	# fbi					= {fbi & cleanid = removeDup [selection:fbi.cleanid], pathname = pathname}
	# pstate				= setFBI fbi pstate
	= fi_messagebox fbi pstate

sr_find_def :: !Bool !*(PSt General) -> *PSt General
sr_find_def always_dialog pstate
	#	(fbi,pstate)	= getFBI pstate
	#	fbi				= {fbi & kind = Definition, type = SearchImports}
	= sr_find_def_imp always_dialog fbi pstate

sr_find_imp :: !Bool !*(PSt General) -> *PSt General
sr_find_imp always_dialog pstate
	#	(fbi,pstate)	= getFBI pstate
	#	fbi				= {fbi & kind = Implementation, type = SearchImports}
	= sr_find_def_imp always_dialog fbi pstate

sr_find_def_imp :: !Bool !.(FindBoxInfo *(PSt *General)) !*(PSt General) -> *PSt General
sr_find_def_imp always_dialog info pstate
  	#	(maybesel,pstate)	= sendToActiveWindow (msgGetSelection) pstate
  	#	(maybepath,pstate)	= sendToActiveWindow (msgGetPathName) pstate
 	| isNothing maybepath
		= sr_find_def_imp_sel always_dialog "" "" {info & type = SearchProject} pstate
 	| isNothing maybesel
		= sr_find_def_imp_sel always_dialog "" "" info pstate
 	#	pathname			= fromJust maybepath
 	#	(selection,_)		= fromJust maybesel
 	// filter multiline strings...
 	#	hasnewline			= or [c == '\xd' || c == '\xa' \\ c <-: selection]
 	#	string				= case hasnewline of
 								True	-> ""
 								False	-> selection
 	= sr_find_def_imp_sel always_dialog string pathname info pstate

sr_find_def_imp_sel :: !Bool !{#.Char} !.Pathname !.(FindBoxInfo *(PSt *General)) !*(PSt *General) -> *(PSt *General)
sr_find_def_imp_sel always_dialog selection pathname info=:{cleanid} pstate
 	#	info			= {info & cleanid = removeDup [selection:cleanid], pathname = pathname}
 	#	pstate			= setFBI info pstate
 	| size selection == 0 || not (CleanModId selection) || always_dialog
 		= fi_dialog info pstate
 	= fi_messagebox info pstate

fi_messagebox info=:{cleanid,dlogId,stringId,msgId,kind,closeId} pstate
	| isEmpty cleanid
		= pstate
	#	pstate			= closeWindow dlogId pstate
		(_,pstate)		= openModalDialog info dialog pstate
	= pstate
where
	dialog = Dialog
				( case kind of
					Definition			-> "Find Definition"
					Implementation		-> "Find Implementation"
					Identifier			-> "Find Identifier"
				)
				(	TextControl ""
						[ ControlId msgId
						, ControlWidth (PixelWidth 300)
						]	// area to show messages
				:+:	TextControl "Find:"
						[ ControlPos (Left,zero)
						]
				:+:	EditControl (hd cleanid) (PixelWidth 300) 1
						[ ControlPos (Left,zero)
						, ControlId stringId
						, ControlActivate (noLS (appPIO (setEditControlSelection stringId 1 0)))
						]
				:+: ButtonControl "Close"
						[ ControlFunction closefun
						, ControlPos (Left,zero)
						, ControlId closeId
						]
				)
				[ WindowId dlogId
				, WindowCancel closeId
				, WindowOk closeId
				, WindowClose closefun
				, WindowInit sr_find_worker
				]
	closefun (ls,ps)
		#	ps		= closeWindow dlogId ps
		= (ls, ps)

fi_dialog info=:{dlogId,msgId,stringId,cleanid,kind,type,verb,export_,closeId,findId,recvId} pstate
	#	pstate			= closeWindow dlogId pstate
		(_,pstate)		= openModalDialog info dialog pstate
	= pstate
where
	dialog =
		Dialog "Find..."
		(	TextControl ""
				[ ControlId msgId
				, ControlWidth (PixelWidth 300)
				]	// area to show messages
		:+:	TextControl "Find:"
				[ ControlPos (Left,zero)
				]
		:+:	PopUpControl [(ci,id) \\ ci <- cleanid] 0
				[ ControlPos (Left,zero)
				, ControlId stringId
				, ControlKeyboard		filterReturnKeys Able (noLS1 (\_->stringKey))
				, ControlDeactivate	(noLS stringKey)
				, ControlWidth (PixelWidth 300)
				]
		:+: RadioControl
				[("Find Definition"		,Nothing,noPS (\l->{l & kind = Definition}))
				,("Find Implementation"	,Nothing,noPS (\l->{l & kind = Implementation}))
				,("Find Identifiers"	,Nothing,noPS (\l->{l & kind = Identifier}))
				] (Columns 1)
				( case kind of
					Definition -> 1
					Implementation -> 2
					Identifier -> 3
				)
				[ ControlPos (Left,zero)
				]
		:+:	RadioControl
				[("Search in Imported Files"	,Nothing,noPS (\l->{l & type = SearchImports}))
				,("Search in Paths"				,Nothing,noPS (\l->{l & type = SearchPaths}))
				,("Search in Project"			,Nothing,noPS (\l->{l & type = SearchProject}))
				] (Columns 1)
				( case type of
					SearchImports	-> 1
					SearchPaths		-> 2
					SearchProject	-> 3
				)
				[
				]
		:+:	CheckControl
				[("Be Verbose"					,Nothing,toMark	verb	,noPS (\l->{l & verb = not l.verb}))
				,("Exported Identifiers Only"	,Nothing,toMark	export_	,noPS (\l->{l & export_ = not l.export_}))
				] (Columns 1)
				[ ControlPos (Left,zero)
				]
		:+: ButtonControl "Close"
				[ ControlFunction closefun
				, ControlPos (Left,zero)
				, ControlId closeId
				]
		:+: ButtonControl "Find"
				[ ControlId findId
				, ControlFunction findfun
				]
		:+: Receiver recvId recvfun
				[ ]
		)
		[ WindowId dlogId
		, WindowOk findId
		, WindowCancel closeId
		, WindowClose closefun
		]
	
	stringKey ps=:{io}
		# (wst,io)	= getWindow dlogId io
		  title		= fromJust (snd (hd (getControlTexts [stringId] (fromJust wst))))
		# io		= openPopUpControlItems stringId 0 [(title,id)] io
		# io		= selectPopUpControlItem stringId 0 io
		= {ps & io=io}

savefun (ls=:{dlogId,stringId,cleanid},ps)
	# (wdef,ps)		= accPIO (getWindow dlogId) ps
	| isNothing wdef
//		= trace_n "Fatal error in Find Identifier Dialog: 1" (ls,ps)
		= (ls,ps)
	# wdef			= fromJust wdef
	# [(ok,ss):_]	= getControlTexts [stringId] wdef
	| not ok
//		= trace_n "Fatal error in Find Identifier Dialog: 2" (ls,ps)
		= (ls,ps)
	| (isNothing ss)
//		= trace_n "Fatal error in Find Identifier Dialog: 3" (ls,ps)
		= (ls,ps)
	# ss			= fromJust ss
	# ls			= {ls & cleanid = removeDup [ss:cleanid]}
	# ps			= setFBI ls ps
	= (ls,ps)
closefun (ls=:{dlogId},ps)
	# (ls,ps)	= savefun (ls,ps)
	# ps		= closeWindow dlogId ps
	= (ls, ps)
findfun (ls=:{is_searching,dlogId,intrId,findId},ps)
	# (ls,ps)	= savefun (ls,ps)
	| is_searching
		# ls	= {ls & is_searching = False}
		# ps	= StopIntr (dlogId,intrId) ps
		# ps	= appPIO (setControlText findId "Find") ps
		= (ls,ps)
	# ls	= {ls & is_searching = True}
	# ps	= appPIO (setControlText findId "Stop") ps
	# (ls, ps)	= sr_find_worker (ls, ps)
	= (ls, ps)
recvfun _ (ls=:{is_searching,findId},ps)
	| is_searching
		# ls	= {ls & is_searching = False}
		# ps	= appPIO (setControlText findId "Find") ps
		= (ls,ps)
	# ls	= {ls & is_searching = True}
	# ps	= appPIO (setControlText findId "Stop") ps
	= (ls, ps)

import StdPathname, Directory

getModulesInPaths ps
	# (ep,ps) = getCurrentPaths ps
	# (pp,ps) = getFromProject PR_GetPaths ps
	= accFiles (findmods (Concat pp ep)) ps
where
	findmods Nil files
		= ([],files)
	findmods (path:!paths) files
		# ((ok,path`),files) = pd_StringToPath path files
		| not ok
			= findmods paths files
		# ((err,dir),files)		= getDirectoryContents path` files
		| err <> NoDirError
			= findmods paths files
		# dir					= map getinfo dir		// only need common fileinfo...
		# dir					= filter (\(b,n)-> (not b)) dir
		# dir					= map (\(_,n)->n) dir
		// apply extra filter to only search .icl's and .dcl's
		# dir					= filter is_interesting dir
		# dir					= map (\n->MakeFullPathname path n) dir
		# (mods,files)			= findmods paths files
		# mods					= dir ++ mods
		= (mods,files)

	getinfo {fileName,fileInfo=fi=:{pi_fileInfo=dummyname=:{isDirectory}}}
		= (isDirectory,fileName)

	is_interesting string
		# s = size string
		  suffix_4 = string % (s-4,s-1)
		  suffix_3 = string % (s-3,s-1)
		= (s >= 4 && (suffix_4==".icl" || suffix_4==".dcl")) || (s>=3 && suffix_3==".hs")

sr_find_worker :: !(FindBoxInfo *(PSt *General),!*(PSt *General)) -> (!FindBoxInfo *(PSt *General),!*PSt *General)
sr_find_worker (info=:{kind,type,dlogId=fId,intrId=tId, pathname}, pstate)
	// close search window... so that it can be opened later with the search results
	# pstate = sw_safe_close pstate
	= case type of
		SearchPaths
			# (modpaths, pstate) = getModulesInPaths pstate
			  (paths,pstate) = get_paths pstate
			  pstate = StartIntr (fId,tId) (search fId tId pathname (pathname :! (ListToStrictList modpaths)) kind paths) pstate
			-> (info,pstate)
		SearchProject	// Wrong: searches imports visible from main instead of project :-(
			# (prj,pstate)		= getProject pstate
			  ({mdn_dir,mdn_name},prj) = PR_GetRootModuleDirAndName prj
			  (paths,pstate) = get_paths pstate
			  pstate = StartIntr (fId,tId) (search fId tId (mdn_dir+++mdn_name) (mdn_name :! Nil) kind paths) pstate
			-> (info,pstate)
		SearchImports
			# (paths,pstate) = get_paths pstate
			  ({mdn_dir,mdn_name},module_path) = determine_dir_and_filename pathname paths
			  pstate = StartIntr (fId,tId) (search fId tId module_path (mdn_name :! Nil) kind paths) pstate
			-> (info,pstate)
where
	get_paths pstate
		# (syspaths,pstate) = getCurrentPaths pstate
		  (prjpaths,pstate) = getFromProject PR_GetPaths pstate
		= (AppendLists prjpaths syspaths, pstate)

	search dId iId pathname modpaths Identifier paths intr pstate
		= SearchIdentifiersInFiles dId iId (IsDefPathname pathname) info Nil modpaths paths intr pstate
	search dId iId pathname modpaths search_kind paths intr pstate
		= SearchDefinitionInFiles dId iId (IsDefPathname pathname) info Nil modpaths paths intr pstate

//--- Definition Search

SearchDefinitionInFiles :: !Id !Id !Bool !(FindBoxInfo *(PSt *General)) !(List String) !(List Pathname) !(List Pathname) !Bool !*(PSt *General)
						-> *PSt *General
SearchDefinitionInFiles dId iId is_dcl_file info=:{type} done modnames paths intr ps
	= SearchDefinitionInFiles True False is_dcl_file info done modnames intr ps
where
	imports = (type == SearchImports) || (type == SearchProject)
	
	SearchDefinitionInFiles first found is_dcl_file info done modnames True ps
		// INTERRUPT
		#	ps = StopIntr (dId,iId) ps
		= ResetButtonString ps
	SearchDefinitionInFiles first False is_dcl_file info done Nil intr ps
		// NO MORE FILES && NOT FOUND
		#	ps = StopIntr (dId,iId) ps
		#	ps = ResetButtonString ps
		=	ChangeMsgString True "Not Found" ps
	SearchDefinitionInFiles first True is_dcl_file info done Nil intr ps
		// NO MORE FILES && FOUND
		# ps = StopIntr (dId,iId) ps
		# ps = closeWindow dId ps	// close the find... info box
		# ((_,itms),ps) = getExtListBoxItems info.windlbId ps
		| length itms == 1
			= execExtListBoxItem info.windlbId 1 ps	
		= ps
	SearchDefinitionInFiles first found is_dcl_file info done ("":!rest) intr ps
		// BLANK FILENAME ???
		=	SearchDefinitionInFiles False found is_dcl_file info done rest intr ps
	SearchDefinitionInFiles first found is_dcl_file info=:{kind=search_kind,verb=verbose,cleanid,export_} done (modname:!rest) intr ps
		// ACTUAL SEARCH
		| isEmpty cleanid
			= ps
		# cleanid = hd cleanid
		| is_dcl_file && StringOccurs modname done
			// if already done move onto next...
			// slightly tricky phrasing is to make sure that if search starts in mod.icl then mod.dcl is also done...
			= SearchDefinitionInFiles False found is_dcl_file info done rest intr ps
		#	modname` = add_suffix is_dcl_file modname
			ps								= ChangeMsgString verbose ("Searching '" +++ RemovePath modname` +++ "'") ps
			(impsa,found_positions,modname`,ps)
				= SearchDefinitionInFile imports rest cleanid modname` paths ps
			found_in_file					= case found_positions of
												Pos _ _ _	-> True
												Cls _ _ _	-> True
												Ins _ _ _	-> True
												_			-> False
			find_definition					= case search_kind of
												Definition	-> True
												_			-> False
			search_icl_file_next			= found_in_file && is_dcl_file && (not find_definition)
			rest`							= if search_icl_file_next
												(modname :! impsa)
												(if is_dcl_file impsa (modname :! impsa))
			next_file_is_dcl_file			= not search_icl_file_next
			found_here						= found_in_file && (find_definition == is_dcl_file)
			found							= found || found_here
			first = first && (not is_dcl_file)
		| found_here
			# ps							= WriteFoundPositionsInSearchWindow info search_kind modname` found_positions cleanid ps
			= ContIntr (dId,iId) (SearchDefinitionInFiles first found next_file_is_dcl_file info done` rest`) ps
		= ContIntr (dId,iId) (SearchDefinitionInFiles first found next_file_is_dcl_file info done` rest`) ps
	where
		done`
			| is_dcl_file
				= (modname :! done)
				= done

		SearchDefinitionInFile imp rest cleanid modname paths ps
			| IsFullPathname modname
				# ((impsa,found_positions),ps) = seach_definition_in_file modname imp rest cleanid ps
				= (impsa,found_positions,modname,ps)
			# ((ok,path),ps) = accFiles (search_disk modname paths) ps
			| ok
				# ((impsa,found_positions),ps) = seach_definition_in_file path imp rest cleanid ps
				= (impsa,found_positions,modname,ps)
			= (rest,PosNil,modname,ps)

		seach_definition_in_file path imp rest cleanid ps
			# (win,ps) = IsOpen path ps
			| isJust win
				# (text,ps) = message (fromJust win) msgGetText ps
				= case text of
					Nothing
						-> accFiles (FindDefinitionInFile imp rest cleanid path) ps
					Just text
						# text = textToStrings text
						# text = slToList text
						# text = {t \\ t <- text}
						-> accFiles (FindDefinitionInText imp rest cleanid text) ps
			= accFiles (FindDefinitionInFile imp rest cleanid path) ps

//--- Identifier Search

SearchIdentifiersInFiles :: !Id !Id !Bool !(FindBoxInfo *(PSt *General)) !(List String) !(List Pathname) !(List Pathname) !Bool !*(PSt *General)
							-> *PSt *General
SearchIdentifiersInFiles dId iId is_dcl_file info done modnames paths True ps
	// INTERRUPT
	#	ps = StopIntr (dId,iId) ps
	#	ps = ResetButtonString ps
	=	ps
SearchIdentifiersInFiles dId iId is_dcl_file info done Nil paths intr ps
	// NO MORE TO DO
	#	ps = StopIntr (dId,iId) ps
	#	ps = ResetButtonString ps
	# ((_,itms),ps) = getExtListBoxItems info.windlbId ps
	| length itms == 0
		= ChangeMsgString True "Not Found" ps
	# ps = closeWindow dId ps
	| length itms == 1
		= execExtListBoxItem info.windlbId 1 ps	
	= ps
SearchIdentifiersInFiles dId iId is_dcl_file info done ("":!rest) paths intr ps
	// BLANK FILENAME
	=	SearchIdentifiersInFiles dId iId is_dcl_file info done rest paths intr ps
SearchIdentifiersInFiles dId iId is_dcl_file info=:{kind=search_kind,verb=verbose,type=imp,cleanid,export_} done (modname:!rest) paths intr ps
	| isEmpty cleanid = ps
	# cleanid = hd cleanid
	| not is_dcl_file && StringOccurs modname done
		= SearchIdentifiersInFiles dId iId False info done rest paths intr ps
	#	modname` = add_suffix is_dcl_file modname
	#	ps					= ChangeMsgString verbose ("Searching '" +++ RemovePath modname` +++ "'") ps
	# (impsa,found_positions,modname`,ps)
		= SearchIdentifiersInFile True rest cleanid modname` paths ps
	#	found_in_file					= case found_positions of
											PosNil	-> False
											_		-> True
	#	ps = write_found_positions found_in_file modname` found_positions cleanid ps
	| not is_dcl_file
		= ContIntr (dId,iId) (SearchIdentifiersInFiles dId iId True info done (modname:!impsa) paths) ps
		= ContIntr (dId,iId) (SearchIdentifiersInFiles dId iId False info (modname:!done) impsa paths) ps
where
	write_found_positions found_in_file modname` found_positions cleanid pstate
		| found_in_file
			= WriteFoundPositionsInSearchWindow info search_kind modname` found_positions cleanid pstate
		= pstate

	SearchIdentifiersInFile :: !Bool !(List Pathname) !String !Pathname !(List Pathname) !*(PSt *General)
								-> *(!List Modulename,IdentifierPositionList,!Pathname,!*(PSt *General))
	SearchIdentifiersInFile imp rest cleanid modname paths pstate
		| IsFullPathname modname
			# ((impsa,found_positions),ps) = search_identifiers_in_file modname imp rest cleanid pstate
			= (impsa,found_positions,modname,ps)
		# ((ok,path), pstate) = accFiles (search_disk modname paths) pstate
		| ok
			# ((impsa,found_positions),ps) = search_identifiers_in_file path imp rest cleanid pstate
			= (impsa,found_positions,modname,ps)
		= (rest,PosNil,modname,pstate)

	search_identifiers_in_file :: !Pathname !Bool !(List Pathname) !String !*(PSt *General) -> *(!(List Modulename,IdentifierPositionList),!*(PSt *General))
	search_identifiers_in_file path imp rest cleanid pstate
		# (win,pstate) = IsOpen path pstate
		| isJust win
			# (text,pstate) = message (fromJust win) msgGetText pstate
			= case text of
				Nothing
					-> accFiles (FindIdentifiersInFile imp rest cleanid path) pstate
				Just text
					# text = textToStrings text
					# text = slToList text
					# text = {t \\ t <- text}
					-> accFiles (FindIdentifiersInText imp rest cleanid text) pstate
			= accFiles (FindIdentifiersInFile imp rest cleanid path) pstate

add_suffix :: !Bool !Pathname -> Pathname
add_suffix is_dcl_file modname
	| is_dcl_file
		= MakeDefPathname modname
		= MakeImpPathname modname

search_disk :: !Modulename !(List Pathname) !*Files -> (!(!Bool,!Pathname),!*Files)
search_disk module_name paths files
	# n=n_chars_of_file_ext module_name
	| n==0
		= SearchDisk module_name paths files
		# (module_name,file_ext) = split_string n module_name
		= FindHModule module_name file_ext paths files
  where
	n_chars_of_file_ext s
		# n=size s
		| n>3 && is_3_char_file_ext (s % (n-4,n-1))
			= 4
		| n>2 && is_2_char_file_ext (s % (n-3,n-1))
			= 3
			= 0
	where
		is_3_char_file_ext ".icl" = True
		is_3_char_file_ext ".dcl" = True
		is_3_char_file_ext ".lhs" = True
		is_3_char_file_ext _ = False
		
		is_2_char_file_ext ".hs" = True
		is_2_char_file_ext _ = False
	
	split_string :: !Int !{#Char} -> (!{#Char},!{#Char})
	split_string i s
		# n=size s
		# i=n-i
		= (s % (0,i-1),s % (i,n-1))

IsOpen modname ps
	# (windows,ps)	= accPIO getWindowsStack ps
	= doall windows ps
where
	doall :: ![Id] !*(PSt *General) -> *(!.Maybe Id,!*PSt *General)
	doall [] ps = (Nothing,ps)
	doall [win:res] ps
		#	(mr,ps)		= message win msgGetPathName ps
		| isNothing mr
			= doall res ps
		#	pathname`	= fromJust mr
		| modname == pathname`
			= (Just win,ps)
		= doall res ps

//--- Search message handling

ChangeMsgString :: !.Bool !.{#Char} !*(PSt *General) -> *PSt *General
ChangeMsgString verbose message pstate
	| verbose
		#	(fbi,pstate)	= getFBI pstate
			pstate			= appPIO (setControlTexts [(fbi.msgId,message)]) pstate
		= pstate
	= pstate // change string in find message dialog

ResetButtonString pst
	# ({recvId},pst)	= getFBI pst
	# (_,pst)			= asyncSend recvId True pst
	= pst

//--- Search window handling

//WriteFoundPositionsInSearchWindow :: !SearchKind !Modulename !IdentifierPositionList !String !*(PSt General) -> *PSt General
WriteFoundPositionsInSearchWindow info search_kind modname list id pstate
	# msgtext	= WriteFoundPositionsInSearchWindow info search_kind modname list id
	= updateSearchWindow info msgtext pstate
where
	WriteFoundPositionsInSearchWindow info search_kind modname PosNil id
		= Nil
	WriteFoundPositionsInSearchWindow info search_kind modname (Pos line_n _ positions) id
		#	msgtxt	= MakeFoundPosMsg search_kind modname (inc line_n) id
		=	msgtxt :! WriteFoundPositionsInSearchWindow info search_kind modname positions id
	where
		MakeFoundPosMsg Definition mod linenr id
			# path = MakeDefPathname (RemovePath mod)
			= ("Definition found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id, path, linenr)
		MakeFoundPosMsg Implementation mod linenr id
			# path = make_implementation_file_name mod
			= ("Implementation found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id, path, linenr)
		MakeFoundPosMsg Identifier mod linenr id
			# path = RemovePath mod
			= ("Identifier found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
	WriteFoundPositionsInSearchWindow info search_kind modname (Ins line_n _ positions) id
		#	msgtxt	= MakeFoundInsMsg search_kind modname (inc line_n) id
		=	msgtxt :! WriteFoundPositionsInSearchWindow info search_kind modname positions id
	where
		MakeFoundInsMsg Definition mod linenr id
			# path = MakeDefPathname (RemovePath mod)
			= ("Instance Definition found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
		MakeFoundInsMsg Implementation mod linenr id
			# path = make_implementation_file_name mod
			= ("Instance Implementation found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
		MakeFoundInsMsg Identifier mod linenr id
			# path = RemovePath mod
			= ("Identifier found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
	WriteFoundPositionsInSearchWindow info search_kind modname (Cls line_n _ positions) id
		#	msgtxt	= MakeFoundClsMsg search_kind modname (inc line_n) id
		=	msgtxt :! WriteFoundPositionsInSearchWindow info search_kind modname positions id
	where
		MakeFoundClsMsg Definition mod linenr id
			# path = MakeDefPathname (RemovePath mod)
			= ("Class Definition found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
		MakeFoundClsMsg Implementation mod linenr id
			# path = make_implementation_file_name mod
			= ("Class Implementation found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)
		MakeFoundClsMsg Identifier mod linenr id
			# path = RemovePath mod
			= ("Identifier found in [" +++ path +++ "," +++ toString linenr +++ "]: " +++ id,path,linenr)

	make_implementation_file_name mod
		# file_name = RemovePath mod
		| IsImpPathname file_name
			= file_name
			= MakeImpPathname file_name

//-- Search Results Window...

updateSearchWindow info=:{windlbId} text ps	// fun to update error info in error window, text :: !Text
	# ({searchIds},ps)	= getMenuIds ps
	# ps		= wind_open info (searchIds.nextIds!!0) ps
	# ps		= appendExtListBoxItems windlbId [(msg,fifi path lnr,id) \\ (msg,path,lnr) <- (StrictListToList text)] ps
	= ps
where
	fifi path lnr ps
		| not_empty = OpenModule path (lineSelection lnr) ps
		= ps
	where
		not_empty	= path <> EmptyPathname

wind_open info=:{windlbId,windId,src_offset,src_font,src_size,src_forg,src_back} menu_elem_id ps
	#	elb				= ExtListBoxControl [] [] (\_ ps -> ps) windlbId
							[ ControlViewSize src_size
							, ControlResize win_resize
							, ControlPen [PenColour src_forg,PenBack src_back,PenFont src_font]
							]
		(win_size,ps)	= controlSize elb True Nothing Nothing Nothing ps
		(_,ps)			= openWindow undef (searchwin elb win_size) ps
	= ps
where
	win_resize oc ow nw = {w = oc.w + nw.w - ow.w, h = oc.Size.h + nw.Size.h - ow.Size.h}
	searchwin elb win_size = Window "Search Results"
					( elb
					)
					[ WindowId windId
					, WindowClose (noLS (sw_close windId o wind_deac))
					, WindowInit (noLS (sw_init)) 
					, WindowDeactivate (noLS wind_deac)
					, WindowInitActive windlbId.controlId
					, WindowActivate (noLS (wind_act windlbId.controlId))
					, WindowViewSize win_size
					, WindowPos (Fix, OffsetVector src_offset)
					]
wind_deac ps
	# (inf=:{windId},ps)	= getFBI ps
	# (pos,ps)	= accPIO (getWindowPos windId) ps
	| isNothing pos
		= ps
	# pos		= fromJust pos
	# (siz,ps)	= accPIO (getWindowViewSize windId) ps
	# inf		= {inf & src_offset = pos, src_size = siz}
	# ps		= setFBI inf ps
	# ({mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds},ps=:{io})
			= getMenuIds ps
	// enable Edit menu stuff
	# io = enableMenuElements [mn_cut,mn_cpy,mn_pst,mn_clr:mg_edt] io
	// enable Search menu stuff
	# io = enableMenuElements searchIds.findIds io
	# io = enableMenuElements searchIds.gotoIds io
	= {ps & io = io}

wind_act cId ps
	# ({mn_cut,mn_cpy,mn_pst,mn_clr,mg_edt,searchIds},ps=:{io})
			= getMenuIds ps
	// disable Edit menu stuff
	# io = disableMenuElements [mn_cut,mn_cpy,mn_pst,mn_clr:mg_edt] io
	// disable Search menu stuff
	# io = disableMenuElements searchIds.findIds io
	# io = disableMenuElements searchIds.gotoIds io
	# ps = {ps & io = io}
//	# ps = setActiveControl cId ps
	= ps

sw_init ps
	# ({searchIds},ps) = getMenuIds ps
	= appPIO (enableMenuElements [searchIds.nextIds!!0]) ps

sw_close windId ps
	# ({searchIds},ps) = getMenuIds ps
	# ps = appPIO (disableMenuElements [searchIds.nextIds!!0]) ps
	= closeWindow windId ps
	
sw_safe_close :: !*(PSt *General) -> *PSt *General
sw_safe_close ps
	# ({windId},ps) = getFBI ps
	# (win,ps)	= accPIO getActiveWindow ps
	| isNothing win
		= sw_close windId ps
	# win = fromJust win
	| win == windId
		# ps = wind_deac ps
		= sw_close windId ps
	= sw_close windId ps

sw_maybe_close :: !Id !*(PSt *General) -> (Bool,*(PSt *General))
sw_maybe_close win ps
	# ({windId},ps) = getFBI ps
	| win == windId
		# ps = wind_deac ps
		= (True,sw_close windId ps)
	= (False,ps)

:: SWO =
	{ fn	:: !String		// font name
	, fs	:: !Int			// font size
	, fc	:: !Colour		// foreground colour
	, bc	:: !Colour		// background colour
	, cur	:: !SWO_LS
	}

:: SWO_LS = TXT | BCK
instance == SWO_LS
where
	(==) TXT TXT = True
	(==) BCK BCK = True
	(==) _ _ = False

src_options :: !*(PSt *General) -> *PSt *General;
src_options ps
    # (dialogId,ps)	= openId ps
    # (okId,ps)		= openId ps
    # (cancelId,ps)	= openId ps
	# (rgbid,ps)	= openRGBId ps
	# (fcid,ps)		= openId ps
	# (bcid,ps)		= openId ps
	# (lsid,ps)		= openRId ps
	# (fontNames, ps) = accPIO (accScreenPicture getFontNames) ps
	# fontSizes		= [7,8,9,10,11,12]
	# (fbi,ps)		= getFBI ps
	# font			= fbi.src_font
	# fdef			= getFontDef font
	# inifn			= fdef.fName
	# inifs			= fdef.fSize
	# inifc			= fbi.src_forg
	# inibc			= fbi.src_back
	# inistate		= {fn = inifn, fs = inifs, fc = inifc, bc = inibc, cur = TXT}
    # controls		=
    	(LayoutControl 
		(	FontNameSizeControl inifn inifs fontNames fontSizes fontfun sizefun [ left ]
		:+:	RGBColourPickControl` rgbid inifc fcid (Just (Left, zero))
		) []
		:+: LayoutControl
		(	TextControl "Text:" [ left , ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inifc) fcid (mfilter,mfun rgbid lsid fcid bcid TXT) Nothing
		:+: TextControl "Background:" [ left, ControlWidth (ContentWidth "Background: ")]
		:+: ColourBoxControl` (toRGBColour inibc) bcid (mfilter,mfun rgbid lsid fcid bcid BCK) Nothing
		) []
	   	:+:	ButtonControl "Ok"
  			[ ControlId okId
  			, ControlFunction (okFun rgbid lsid dialogId) 
  			, ControlPos (Right, zero)
  			, ControlWidth (ContentWidth "Cancel")
  			]
    	:+:	ButtonControl "Cancel"
  			[ ControlPos (LeftOfPrev, zero) 
  			, ControlFunction (cancelFun inistate dialogId)
  			, ControlId cancelId
  			] 
		:+: ButtonControl "Apply"
			[ ControlPos (LeftOfPrev,zero)
			, ControlFunction (applyFun rgbid lsid)
			]
  		:+: ButtonControl "Paste"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (pasteFun rgbid fcid bcid)
  			]
  		:+: ButtonControl "Copy"
  			[ ControlPos (LeftOfPrev,zero)
  			, ControlFunction (copyFun rgbid)
  			]

  		:+: Receiver lsid lsfun []
		)
	# dialog		=
		Dialog "Search Window..." controls 
  		[ WindowId		dialogId 
  		, WindowOk		okId
  		, WindowCancel	cancelId
  		, WindowClose	(cancelFun inistate dialogId)
		, WindowInit	(setBoxCol fcid bcid)
  		]
	# (_,ps) = openModalDialog inistate dialog ps
	= ps
where
	okFun rgbid lsid dialogId (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
			# (ls,ps)= apply (ls,ps)
			= (ls,closeWindow dialogId ps)
	cancelFun inistate dialogId (ls,ps)
		# ls		= inistate
		# (ls,ps)	= apply (ls,ps)
		= (ls,closeWindow dialogId ps)
	applyFun rgbid lsid (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
			= apply (ls,ps)
	toStringC :: !Colour -> String
	toStringC c = toString c
	copyFun rgbid (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col
				= ps
			# col = fromJust col
			# ps	= setClipboard [toClipboard (toString col)] ps
			= ps
	pasteFun rgbId fcid bcid (ls=:{cur},ps)
		// get clipboard
		// and put in active colour control
		# (its,ps)	= getClipboard ps
		| isEmpty its
			= (ls,ps)
		# its		= map fromClipboard its
		# its		= filter isJust its
		| isEmpty its
			= (ls,ps)
		# it		= fromJust (hd its)
		| it <> toStringC (fromString it)
			= (ls,ps)
		# col		= fromString it
		# ls		= case cur of
						TXT -> {ls & fc = col}
						BCK -> {ls & bc = col}
		# (ls,ps)	= setBoxCol fcid bcid (ls,ps)
		# ps		= setColourBoxColour` rgbId col ps
		= (ls,ps)
	setBoxCol fcid bcid (ls=:{cur,fc,bc},ps)
		# (cId,col) = case cur of
						TXT	-> (fcid,fc)
						BCK	-> (bcid,bc)
		# ps = appPIO (SetColourBox` cId (toRGBColour col)) ps
		= (ls,ps)
	mfilter (MouseDown _ _ _) = True
	mfilter _ = False
	mfun rgbid lsid fcid bcid act _ (ls=:{cur,fc,bc},ps)
		| act == cur = (ls,ps)
		# ps = getColourBoxColour rgbid cont ps
		= (ls,ps)
	where
		cont col ps
			| isNothing col = ps
			# col = fromJust col
			# ps	= appPIO (case act of
								TXT	-> SetColourBox` fcid (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour fc
									)
								_	-> SetColourBox fcid (case cur of
									TXT	-> toRGBColour col
									_	-> toRGBColour fc
									)
							) ps
			# ps	= appPIO (case act of
								BCK	-> SetColourBox` bcid (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bc
									)
								_	-> SetColourBox bcid (case cur of
									BCK	-> toRGBColour col
									_	-> toRGBColour bc
									)
							) ps
			# cId = case act of
						TXT -> fcid
						BCK -> bcid
			# col` = case act of
						TXT -> fc
						BCK -> bc
			# ps	= setColourBoxId rgbid cId ps
			# ps	= setColourBoxColour` rgbid col` ps
			# (_,ps) = asyncSend lsid (cont2 col) ps
			= ps
		cont2 col (ls=:{cur},ps)
			# ls	= case cur of
						TXT -> {ls & fc = col, cur = act}
						BCK -> {ls & bc = col, cur = act}
			= (ls,ps)
	lsfun f (ls,ps)
		= f (ls,ps)
	apply (ls=:{fc,bc,fn,fs},ps)
		# (fbi,ps)	= getFBI ps
		# lbId		= fbi.windlbId
		# (fnt,ps)	= accScreenPicture (safeOpenFixedFont {fName = fn, fSize = fs, fStyles = []}) ps
		# pen		= [PenColour fc, PenBack bc, PenFont fnt] 
		# ps		= setExtListBoxPen lbId pen ps
		# fbi		= {fbi & src_forg = fc, src_back = bc, src_font = fnt}
		# ps		= setFBI fbi ps
		= (ls,ps)
	fontfun name (ls,ps)
		# ls		= {SWO | ls & fn = name}
		= (ls,ps)
	sizefun size (ls,ps)
		# ls		= {SWO | ls & fs = size}
		= (ls,ps)

    left = ControlPos (Left, zero)

wind_next :: !Bool !*(PSt *General) -> *PSt *General
wind_next next ps		// Find Search result	=> next is forward, otherwise backwards
	# ({windlbId=lbId},ps) = getFBI ps
	= exec_next next lbId ps

