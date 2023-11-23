implementation module edfiles

import StdArray,StdFunc,StdMisc,StdTuple
import StdFileSelect,StdMenuElement,StdPStClass,StdReceiver
import ExtNotice
import EdClient, EdWindow, EdMouse, EdFile
import EdText, EdKeyboard, EdSelection
import PmPath, PmParse
import IDE, IdePlatform
//import filehist
import ioutil
import StrictList
import menubar
import UtilNewlinesFile
//import treeparse //P4

ed_ask_save_all :: !Bool !Bool (*(PSt General) -> *PSt General) !*(PSt General) -> *PSt General
ed_ask_save_all close update_in_project cont pstate
	#	(windows,pstate)	= accPIO getWindowsStack pstate
	= doall windows pstate
where
	maybeclose win ps
		| close	= ed_common_close update_in_project win ps
				= ps
	doall [] ps = cont ps
	doall [win:res] ps
		#	(ns,ps)		= message win msgGetNeedSave ps
		| isNothing ns
			= doall res ps
		#	needsave	= fromJust ns
		| not needsave
			= doall res (maybeclose win ps)
		#	(mr,ps)		= message win msgGetPathName ps
		| isNothing mr
			= doall res ps
		#	pathname	= fromJust mr
			texts		= ["Save changes to","\""+++RemovePath pathname+++"\"?"]
		= ask texts win res ps

	ask texts win res ps
		#	(sId,ps)		= openId ps
		#	(okId,ps)		= openId ps
		#	(cancelId,ps)	= openId ps
			((err,_),ps)	= openModalDialog Void (sdef sId okId cancelId) ps
		| err <> NoError
			// error handling
			// # ps = trace_n "dialog open err" ps
			= ps
		= ps
	where
		sdef sId okId cancelId =
			Dialog "Save changes?"
			(	ListLS	[TextControl txt [ControlPos (Left,zero)]
						\\ txt <- texts
						]
			:+: ButtonControl "&Cancel"
				[ ControlPos (Left,zero)
				, ControlFunction (noLS (mb_update_undoinfo o closeWindow sId))
				, ControlId cancelId
				, ControlWidth (ContentWidth "Cancel")
				]	// no more
			:+: ButtonControl "&No"
				[ ControlFunction (noLS (doall res o maybeclose win o (closeWindow sId)))
				, ControlWidth (ContentWidth "Cancel")
				]	// not this one but continue with rest
			:+: ButtonControl "&Yes"
				[ ControlId okId
				, ControlFunction (noLS (try_save sId))
				, ControlWidth (ContentWidth "Cancel")
				]	// do this one and continue
			)
			[ WindowId sId
			, WindowOk okId				// DvA: Doesn't work properly yet. Will be fixed in Object IO
			, WindowCancel cancelId
			, WindowClose (noLS (mb_update_undoinfo o closeWindow sId))
			, WindowInitActive okId
			]
		try_save sId ps
			# ps	= closeWindow sId ps
//			# ps	= save win ps
			# (reply,ps)		= message win msgSave ps
			| isNothing reply
				= okNotice ["Save failed:","Internal error [edfiles:ed_ask_save_all]","Aborting quit"] ps
			# error				= fromJust reply
			| isJust error
				= okNotice ["Save failed:",fromJust error,"Aborting quit"] ps
			# ps	= maybeclose win ps
			= doall res ps
/*
	save win ps
		# (reply,ps)		= message win msgSave ps
		| isNothing reply
			= okNotice ["Save failed:","Internal error [edfiles:ed_ask_save_all]"] ps
		# error				= fromJust reply
		| isJust error
			= okNotice ["Save failed:",fromJust error] ps
		= ps
*/
ed_open_path_sel :: .String !Selection !*(PSt General) -> *PSt General
ed_open_path_sel pathName sel ps
	# (mFHrecId,ps)	= getFHI ps
	# (_,ps)		= syncSend2 mFHrecId pathName ps
	= ed_open_cont pathName cont ps
where
	cont _ win ps
		# (_,ps) = message win (msgChangeSelection sel) ps
		= ps

ed_open_path :: .String !*(PSt General) -> *PSt General
ed_open_path pathName ps
	# (mFHrecId,ps) = getFHI ps
	# (_,ps)		= syncSend2 mFHrecId pathName ps
	= ed_open_cont pathName cont ps
where
	cont _ _ ps = ps

ed_open_cont :: .String .(Bool  Id *(PSt General) -> *PSt General) !*(PSt General) -> *PSt General
ed_open_cont pathName cont ps
	// should first check wether this one already exists...
	# (windows,ps)	= accPIO getWindowsStack ps
	# (exists,ps)	= doall windows ps
	| isJust exists
		// bring to front...allready done by 'doall'
		= cont True (fromJust exists) ps
	// read the file from disk
	# (syspaths,ps) = getCurrentPaths ps
	  (prjpaths,ps) = getFromProject PR_GetPaths ps
	  ({mdn_name=modname},_) = determine_dir_and_filename pathName (AppendLists prjpaths syspaths)
	# ((errorText,nlConv,readOnly), ps)
					= readText pathName ps
	| isError errorText
		= okNotice
			[ "Clean Project Manager"
			, "Error while reading file:"
			, pathName
			, giveError errorText				// for debugging purposes only?
			] ps
	# text			= fromOk errorText
	# isDefMod		= IsDefPathname pathName
	# isImpMod		= IsImpPathname pathName
	# (inf,ps)		= getFromProject (PR_GetModuleInfo modname) ps
	# (prefs,ps)	= getPrefs ps
	# defaultFontdef= prefs.edwinfont
	# fontdef		= defaultFontdef
	# tabs			= prefs.edwintabs
	# margin		= prefs.edwinmargin
	// open a font and then the edit window
	# (font,ps)		= accScreenPicture (safeOpenFixedFont defaultFontdef) ps
	// error checking op font doen...?
	# title			= pathNameToWindowTitle pathName
	# title`		= pathNameToWindowTitle` pathName
	# (windowId, ps)= openId ps 
	# ({mn_und},ps)	= getMenuIds ps
	# keyboardfun	= if readOnly my_keyboard` my_keyboard
	# windowIcon	= if isDefMod DefmodIcon (if isImpMod ImpmodIcon CleanIcon)
	# syncols		= if isDefMod (prefs.defcols) (if isImpMod (prefs.impcols) (prefs.syncols))
//    # (boom, ps) 	= readFileInTree ps	// P4

	# optional_window_pos_and_size = if (isJust inf)
										(if isDefMod
											(fromJust inf).mod_edit_options.defeo.pos_size
											(fromJust inf).mod_edit_options.impeo.pos_size)
										NoWindowPosAndSize
	# ps			= openEditWindow mn_und (if readOnly title` title) pathName text font tabs margin syncols windowId (
						[ WindowClose		(noLS (ed_close windowId))
						, WindowKeyboard	(\_ -> True) Able keyboardfun
						, WindowActivate	(ed_activate title)
						, WindowDeactivate	(ed_deactivate title)
						, WindowInit		(noLS (SetWindowIcon windowId windowIcon))
						, WindowMouse		noMouseMoved Able editWindowMouse	//(editWindowMouse boom) // P4
						] ++
							(case optional_window_pos_and_size of
								WindowPosAndSize window_pos_and_size
									->	[ WindowViewSize {w=window_pos_and_size.sizex,h=window_pos_and_size.sizey}
										, WindowPos		(Fix,OffsetVector {vx=window_pos_and_size.posx,vy=window_pos_and_size.posy})
										]
								_
									->[]
							)
						) ps
	# (_,ps)		= message windowId (setNewlineConvention nlConv) ps
	# (_,ps)		= message windowId (setReadOnly readOnly) ps
	= cont False windowId ps
where
	doall [] ps = (Nothing,ps)
	doall [win:res] ps
		#	(mr,ps)		= message win msgGetPathName ps
		| isNothing mr
			= doall res ps
		#	pathname`	= fromJust mr
		| pathName == pathname`
			#	ps	= setActiveWindow win ps
			= (Just win,ps)
		= doall res ps

	giveError (Error s) = s
	giveError _ = ""

ed_activate :: !String !*(!EditState,!*PSt General) -> *(EditState,*PSt General)
ed_activate title (ls,ps)
	# (menuIds,ps)			= getMenuIds ps
	# (undoInfo,(ls,ps))	= getUndoInfo (ls,ps)
	# (pathname,(ls,ps))	= getPathName (ls,ps)

	# (text,(ls,ps))		= getText (ls,ps)
	# (sel,(ls,ps))			= getSelection (ls,ps)
	# sel					= orderSelection sel
	# (frag,_)				= getTextFragment sel text
	# frag					= dofrag frag
	# (_,(ls,ps))			= setMenuSelection frag (ls,ps)

	# iofun					= case undoInfo.state of
								None	-> disableMenuElements [menuIds.mn_und] o setMenuElementTitles [(menuIds.mn_und,"&Undo")]
								Undo	-> enableMenuElements [menuIds.mn_und] o setMenuElementTitles [(menuIds.mn_und,"&Undo"+++undoInfo.action)]
								Redo	-> enableMenuElements [menuIds.mn_und] o setMenuElementTitles [(menuIds.mn_und,"Redo"+++undoInfo.action)]
	# filename				= RemovePath pathname
	#! ps					= appPIO
								( iofun
								o setMenuElementTitles
									[(menuIds.mn_sav,"&Save " +++filename)
									,(menuIds.mn_rev,"&Revert " +++filename)
									,(menuIds.mn_oth,"Open " +++(makeOther filename))
									,(menuIds.mn_prt,"&Print " +++ filename)
									: handlefrag frag menuIds
									]
								o enableMenuElements
									[ menuIds.mn_sav
									, menuIds.mn_sva
									, menuIds.mn_rev
									, menuIds.mn_oth
									, menuIds.mn_prt
									, menuIds.md_est
									: ismodule pathname (menuIds.moduleIds) []
									]
								) ps
	= (ls,ps)
where
	ismodule s t f
		| lengths < 4
			= f
		| s%(firsts,lasts) == ".icl"
			= t
		| s%(firsts,lasts) == ".dcl"
			= t
		= f
	where
		lengths = size s
		firsts = lengths - 4
		lasts = dec lengths

	dofrag (SCons (str) SNil) 
		| CleanModId str
			= Just str
		= Nothing
	dofrag _ = Nothing

	handlefrag (Just str) mIds
		=
			[(mIds.mn_odm,"Open "+++(MakeDefPathname str))
			,(mIds.mn_oim,"Open "+++(MakeImpPathname str))
			]
	handlefrag _ mIds =
			[(mIds.mn_odm,"Open Definition...")
			,(mIds.mn_oim,"Open Implementation...")
			]

makeOther pth
	| IsDefPathname pth = MakeImpPathname pth
	= MakeDefPathname pth

ed_deactivate title (ls,ps)
	# (menuIds,ps)	= getMenuIds ps
	# ps			= appPIO
						( setMenuElementTitles
							[ (menuIds.mn_sav,"&Save")
							, (menuIds.mn_rev,"&Revert")
							, (menuIds.mn_oth,"Open Other")
							, (menuIds.mn_odm,"Open Definition...")
							, (menuIds.mn_oim,"Open Implementation...")
							, (menuIds.mn_prt,"&Print")
							, (menuIds.mn_und,"&Undo")
							]
						o disableMenuElements
							[ menuIds.mn_sav
							, menuIds.mn_sva
							, menuIds.mn_rev
							, menuIds.mn_oth
							, menuIds.mn_prt
							, menuIds.mn_und
							, menuIds.md_est
							: menuIds.moduleIds
							]
						) ps
	= (ls,ps)

ed_new :: !String !*(PSt General) -> *PSt General
ed_new suffix ps
	// ask user for a file to open
	#	(maybeString, ps) = selectOutputFile "New..." suffix ps
	| isNothing maybeString
		= ps
	#	pathName			= fromJust maybeString
		text				= newText
		title				= pathNameToWindowTitle pathName
		(windowId, ps)		= accPIO openId ps
	#	({mn_und},ps)		= getMenuIds ps
		(prefs,ps)			= getPrefs ps
		defaultFontdef		= prefs.edwinfont
		defaultTabs			= prefs.edwintabs
		defaultMargin		= prefs.edwinmargin
	#	isDefMod			= IsDefPathname pathName
	#	isImpMod			= IsImpPathname pathName
	#	defaultSync			= if isDefMod (prefs.defcols) (if isImpMod (prefs.impcols) (prefs.syncols))
	
		((_, defaultFont), ps)
							= accPIO (accScreenPicture (openFont defaultFontdef)) ps
//    # (boom, ps) 	= readFileInTree ps	// P4
	#	ps					= openEditWindow mn_und title pathName text defaultFont defaultTabs defaultMargin defaultSync windowId 
								[ WindowClose		(noLS (ed_close windowId))
								, WindowKeyboard	(\_ -> True) Able (my_keyboard)
								, WindowActivate	(ed_activate title)
								, WindowDeactivate	(ed_deactivate title)
								, WindowMouse		noMouseMoved Able editWindowMouse	//(editWindowMouse boom)
								] ps
	# nlConv = case prefs.newline_handling of
				(LeaveAlone NewlineConventionNone)	-> HostNativeNewlineConvention
				(LeaveAlone conv)					-> conv
				(AlwaysUse NewlineConventionNone)	-> HostNativeNewlineConvention
				(AlwaysUse conv)					-> conv
	#	(_,ps)				= message windowId (setNewlineConvention nlConv) ps
  	#	(reply,ps)				= message windowId msgSave ps
  	| isNothing reply
  		# ps = okNotice ["File creation failed","Internal error [edfiles:ed_new]"] ps
  		# ps = ed_common_close False windowId ps
  		= ps
  	# error					= fromJust reply
  	| isJust error
  		# ps = okNotice ["File creation failed",fromJust error] ps
  		# ps = ed_common_close False windowId ps
  		= ps
	# (mFHrecId,ps)			= getFHI ps
	# (_,ps)				= syncSend2 mFHrecId pathName ps
  = ps

ed_close :: !Id !*(PSt General) -> *PSt General
ed_close win ps
	#	(mr,ps)		= message win msgGetPathName ps
	| isNothing mr
		= ps
	#	pathname	= fromJust mr
		(ns,ps)		= message win msgGetNeedSave ps
	| isNothing ns
		= ed_common_close True win ps
	#	needsave	= fromJust ns
	| not needsave
		= ed_common_close True win ps
	#	texts		= ["Save changes to","\""+++RemovePath pathname+++"\"","before closing?"]
		ps			= ask texts win ps
	= ps
where
	save_cont win sId ps
		# ps			= closeWindow sId ps
		# (reply,ps)	= message win msgSave ps
		| isNothing reply
			# (cnId,ps) = openId ps
			# (_,ps)	= openModalDialog Void (edef ["Save failed.","Internal error [edfiles:ed_close]"] sId cnId) ps
			= ps
		# error			= fromJust reply
		| isJust error
			# (cnId,ps) = openId ps
			# (_,ps)	= openModalDialog Void (edef ["Save failed.",fromJust error] sId cnId) ps
			= ps
		# ps			= ed_common_close True win ps
		= ps
	buttonWidth = ContentWidth "Cancel"
	ask texts win ps
		#	(sids,ps)	= accPIO (openIds 3) ps
			(_,ps)	= openModalDialog undef (sdef sids) ps
		= ps
	where
		sdef [sId,okId,cancelId:_] = Dialog "Save changes?"
				(	ListLS [TextControl txt [ControlPos (Left,zero)]
					\\ txt <- texts
					]
				:+: ButtonControl "&Cancel"
					[ ControlPos (Left,zero)
					, ControlId cancelId
					, ControlFunction (noLS (closeWindow sId))
					]	// no more
				:+: ButtonControl "&No"
					[ ControlFunction (noLS (ed_common_close True win o (closeWindow sId)))
					]
				:+: ButtonControl "&Yes"
					[ ControlId okId
					, ControlFunction (noLS (save_cont win sId))
					]	// do this one and continue
				)
				[ WindowOk okId
				, WindowCancel cancelId
				, WindowId sId
				, WindowClose (noLS (closeWindow sId))
				, WindowInitActive okId
				]
		sdef _ = abort "edfiles: not enough ids"
	edef texts sId cnId = Dialog ""
		(	ListLS [TextControl txt [ControlPos (Left,zero)]
			\\ txt <- texts
			]
		:+: ButtonControl "Cancel"
			[ ControlPos (Left,zero)
			, ControlFunction (noLS (closeWindow sId))
			, ControlWidth buttonWidth
			, ControlId cnId
			]	// no more
		:+: ButtonControl "Close"
			[ ControlFunction (noLS (ed_common_close True win o (closeWindow sId)))
			, ControlWidth buttonWidth
			]	// not this one but continue with rest
		)
		[ WindowCancel cnId
		, WindowId sId
		]

ed_common_close :: !Bool !Id !*(PSt General) -> *PSt General
ed_common_close update_in_project win ps
	# (clip,ps) = cw_maybe_close win ps
	| clip
		= ps	// ???
	# (active,ps) = accPIO getActiveWindow ps
	# (_,ps) = case active of
				Nothing	-> (active,ps)
				(Just act)	-> (if (act==win) (ed_deactivate "???") id) (active,ps)
	// update win info in project
	# (nam,ps)	= message win msgGetPathName ps
	| isNothing nam
		# ps = okTimedNotice ["ed_common_close error 1"] 3000 ps
		= closeEditWindow win ps	// this should not occur
	# nam		= fromJust nam	
	# (pos,ps)	= accPIO (getWindowPos win) ps
	| isNothing pos
		# ps = okTimedNotice ["ed_common_close error 2"] 3000 ps
		= closeEditWindow win ps	// this should not occur
	# pos		= fromJust pos
	# (siz,ps)	= accPIO (getWindowViewSize win) ps
	# (syspaths,ps) = getCurrentPaths ps
	  (prjpaths,ps) = getFromProject PR_GetPaths ps
	  ({mdn_name=modname},_) = determine_dir_and_filename nam (AppendLists prjpaths syspaths)
	# isDefmod	= IsDefPathname nam
	# pos_size	= WindowPosAndSize {posx = pos.vx,posy=pos.vy,sizex=siz.w,sizey=siz.Size.h}
	# update	= \inf=:{mod_edit_options=mod_edit_options=:{defeo,impeo}} -> if isDefmod
					{inf & mod_edit_options={mod_edit_options & defeo = {defeo & pos_size = pos_size}, defopen = not update_in_project}}
					{inf & mod_edit_options={mod_edit_options & impeo = {impeo & pos_size = pos_size}, impopen = not update_in_project}}
	# ps		= appProject (\p -> PR_UpdateModule modname update p) ps
	= closeEditWindow win ps

ed_save :: !Id !*(PSt General) -> (!Bool,!*PSt General)
ed_save win ps
	#	(reply,ps)			= message win msgSave ps
	| isNothing reply
		# ps = okNotice ["Save failed:","Internal error [edfiles:ed_save]"] ps
		= (False,ps)	// shouldn't happen
	# error = fromJust reply
	| isNothing error
		= (True,ps)
	# ps = okNotice ["Save failed:",fromJust error] ps
	= (False,ps)

ed_save_as :: !*(PSt General) -> *PSt General
ed_save_as ps
	# (win,ps)				= accPIO getActiveWindow ps
	| isNothing win
		= ps
	# win					= fromJust win
	# (isEdit,ps)			= isEditWin win ps
	| not isEdit
		= ps
	# (mpath,ps)			= message win msgGetPathName ps
	| isNothing mpath
		= ps
	# o_pathname			= fromJust mpath
	# (maybeString, ps) 	= selectOutputFile "Save as:" o_pathname ps
	| isNothing maybeString
		= ps
	# pathname				= fromJust maybeString
	# (_,ps)				= message win (setReadOnly False) ps
	# (_,ps)				= message win (msgSetPathName pathname) ps
	# (reply,ps)			= message win (msgSave) ps
	| isNothing reply
		= okNotice ["Save as failed:","Internal error [edfiles:ed_save_as]"] ps
	# error					= fromJust reply
	| isJust error
		= okNotice ["Save as failed:",fromJust error] ps

	# (prefs,ps)			= getPrefs ps
	# cols					= if (IsDefPathname pathname) (prefs.defcols) (if (IsImpPathname pathname) (prefs.impcols) (prefs.syncols))
	# (_,ps)				= message win (appFontInfo (fi_update cols)) ps
	# ps					= appPIO (updateWindow win Nothing) ps

	# (menuIds,ps)			= getMenuIds ps
	# filename				= RemovePath pathname
	# ps					= appPIO
								( setMenuElementTitles
									[(menuIds.mn_sav,"&Save " +++filename)
									,(menuIds.mn_rev,"&Revert " +++filename)
									,(menuIds.mn_oth,"Open " +++(makeOther filename))
									,(menuIds.mn_prt,"&Print " +++ filename)
									]
								) ps
	# (mFHrecId,ps)			= getFHI ps
	# (_,ps)				= syncSend2 mFHrecId pathname ps
	= ps
where
	fi_update cols fi =
		{ fi
		& syntaxColours =
			{ fi.syntaxColours
			& textColour		= cols.textColour
			, tabColour			= cols.tabColour
			, commentColour		= cols.commentColour
			, stringColour		= cols.stringColour
			, charColour		= cols.charColour
			, backgroundColour	= cols.backgroundColour
			, marginColour		= cols.marginColour
			, keywordColour		= cols.keywordColour
			}
		}

ed_save_copy_as :: !*(PSt General) -> *PSt General
ed_save_copy_as ps
	# (win,ps)				= accPIO getActiveWindow ps
	| isNothing win
		= ps
	# win					= fromJust win
	# (isEdit,ps)			= isEditWin win ps
	| not isEdit
		= ps
	# (mpath,ps)			= message win msgGetPathName ps
	| isNothing mpath
		= ps
	# pathname				= fromJust mpath
	# (maybeString, ps) 	= selectOutputFile "Save Copy As:" pathname ps
	| isNothing maybeString
		= ps
	# pathName				= fromJust maybeString
	# (reply,ps)				= message win (msgSaveTo pathName) ps
	| isNothing reply
		= okNotice ["Save copy as failed:","Internal error [edfiles:ed_save_copy_as]"] ps
	# error					= fromJust reply
	| isJust error
		= okNotice ["Save copy as failed:",fromJust error] ps
	= ps

ed_save_all :: !*(PSt General) -> *PSt General
ed_save_all pstate
	# (windows,pstate)	= accPIO getWindowsStack pstate
	= doall windows pstate
where
	doall [] ps = ps
	doall [win:res] ps
		# (isEdit,ps)		= isEditWin win ps
		| not isEdit
			= doall res ps
		#! (reply,ps)		= message win msgSave ps
		| isNothing reply
			# ps 			= okNotice ["Save failed:","Internal error [edfiles:ed_save_all]"] ps
			= doall res ps
		# error				= fromJust reply
		| isJust error
			# ps			= okNotice ["Save failed:",fromJust error] ps
			= doall res ps
		= doall res ps

ed_print_setup :: !*(PSt General) -> *PSt General
ed_print_setup ps
	# (setup,ps)	= getPrintSetup ps
	# (setup,ps)	= printSetupDialog setup ps
	= setPrintSetup setup ps

ed_print :: !*(PSt General) -> *PSt General
ed_print ps
	# (printSetup,ps)	= getPrintSetup ps
	# (res,ps)			= sendToActiveWindow (msgPrint printSetup) ps
	| isJust res
		# printSetup = fromJust res
		# ps = setPrintSetup printSetup ps
		= ps			// success
	// try something else...
	= ps

ed_print_all :: !*(PSt General) -> *PSt General
ed_print_all pstate
	# (printSetup,pstate)	= getPrintSetup pstate
	#	(windows,pstate)	= accPIO getWindowsStack pstate
	= doall printSetup windows pstate
where
	doall printSetup [] ps = setPrintSetup printSetup ps
	doall printSetup [win:res] ps
		# (rep,ps)		= message win (msgPrint printSetup) ps
		| isNothing rep
			= doall printSetup res ps
		# printSetup = fromJust rep
		= doall printSetup res ps

ed_revert :: !*(PSt General) -> *PSt General
ed_revert ps
	#	(win,ps)				= accPIO getActiveWindow ps
	| isNothing win = ps
	= ed_revert_win (fromJust win) ps

ed_revert_win :: !Id !*(PSt General) -> *PSt General
ed_revert_win win ps
	#	(mpath,ps)				= message win msgGetPathName ps
	| isNothing mpath
		= ps
	#	pathName				= fromJust mpath
	// read the file from disk
	#	((errorText,nlConv,_), ps)			= readText pathName ps
	| isError errorText
		= openNotice (Notice
			[ "Clean Project Manager"
			, "Error while reading file:"
			, pathName
			, giveError errorText				// only for debugging purposes
			]
			(NoticeButton "OK" id)
			[]) ps
	#	text					= fromOk errorText
		(_,ps)					= message win (msgRevertText text) ps
		(_,ps)					= message win (setNewlineConvention nlConv) ps
	= mb_update_undoinfo ps
where
	giveError (Error s) = s
	giveError _ = ""


//--

my_keyboard ks (es,ps)
	# (ed,ps)				= getEditorState ps
	# keyMapping			= getKeyMapping ed
	= editWindowKeyboard keyMapping ks (es,ps)

my_keyboard` ks (es,ps)
	# (ed,ps)				= getEditorState ps
	# keyMapping			= getKeyMapping ed
	= noeditWindowKeyboard keyMapping ks (es,ps)

