implementation module clipboard

import StdFunc,StdMisc
import StdClipboard,StdMenuElement,StdTimer,StdWindow
import EdWindow, EdText, EdClient, EdVisualCursor
import IDE
import ioutil

/*
o Don't allow Clipboard window title to set 'need save' on clipboard changes...
o Remember clipboard pos and size...
*/

//--

class Clipper env where
	getClipInfo :: !*env -> *(!ClipInfo,!*env)
	setClipInfo :: !ClipInfo !*env -> *env

instance Clipper (PSt *l) | Clipper l
where
	getClipInfo ps		= accPLoc getClipInfo ps
	setClipInfo ci ps	= appPLoc (setClipInfo ci) ps

//--

:: ClipInfo =
	{ clip_clipId	:: !Id			// Id of clipboard window
	, clip_itemId	:: !Id			// Id of show/hide clipboard entry
	, clip_undoId	:: !Id			// Id of undo/redo menu entry
	, clip_timeId	:: !Id			// Id of timer
	, clip_state	:: !ClipState`	// Shown or Hidden
	, menuIds		:: ![Id]
	}

:: ClipState` = Shown | Hidden

instance == ClipState`
where
	(==) Shown Shown = True
	(==) Hidden Hidden = True
	(==) _ _ = False

//--

isClipboardWindow :: !Id !*env -> (Bool,*env) | Clipper env
isClipboardWindow wId ps
	# ({clip_clipId},ps) = getClipInfo ps
	= (clip_clipId == wId,ps)

cw_maybe_close :: !Id !*(PSt *l) -> (Bool,*PSt *l) | Clipper, Editor l
cw_maybe_close win ps
	# (ci,ps) = getClipInfo ps
	| ci.clip_clipId <> win
		= (False,ps)
	// change menu...
	# ps				= appPIO (setMenuElementTitles [(ci.clip_itemId,"Show Clipboard")]) ps
	// close timer...
	# ps				= appPIO (closeTimer ci.clip_timeId) ps
	// close window...
	# ps				= closeEditWindow ci.clip_clipId ps
	# ci				= {ci & clip_state = Hidden}
	# ps				= setClipInfo ci ps
	# (act,ps) = accPIO getActiveWindow ps
	| isNothing act = (True,ps)
	# act = fromJust act
	| win <> act = (True,ps)
	# ps				= deactivate ps
	= (True,ps)
	
initClipInfo :: Id [Id] *env -> *(ClipInfo,*env) | Ids env
initClipInfo undoId menuIds env
	# (clipId,env)		= openId env
	# (itemId,env)		= openId env
	# (timeId,env)		= openId env
	= ({clip_clipId=clipId,clip_itemId=itemId,clip_undoId=undoId,clip_timeId=timeId,clip_state=Hidden,menuIds=menuIds},env)


deactivate ps
	# (ci,ps)			= getClipInfo ps
	# ps				= appPIO ( enableMenuElements ci.menuIds ) ps
	= ps

clipMenuItems :: !Id !Id !ClipInfo -> .MenuItem .c *(PSt *l) | Clipper , Editor l
clipMenuItems mn_sav mn_rev ci
	= MenuItem "&Show Clipboard" [MenuFunction (noLS showClip), MenuId ci.clip_itemId]
where
	showClip ps
		# (ci,ps)			= getClipInfo ps
		| ci.clip_state == Hidden
			# ((_, fnt), ps)	= accScreenPicture (openFont NonProportionalFontDef) ps // depends on ide and project prefs?
			# (clip,ps)			= getClipboard ps
			# newText			= StringToText (getString clip)
			// start timer...
			# (err,ps)			= openTimer undef (tdef ci.clip_timeId ci.clip_clipId) ps
			| err <> NoError = ps
			// change menu...
			# ps				= appPIO (setMenuElementTitles [(ci.clip_itemId,"Hide Clipboard")]) ps
			# tbs				= (4,False,False,False,False)
			# ps				= openEditWindow ci.clip_undoId "Clipboard" "" newText fnt tbs 0 DefaultSyntaxColours ci.clip_clipId
									[WindowActivate		(noLS activate)
									,WindowDeactivate	(noLS deactivate)
									,WindowClose		(noLS showClip)
									] ps
			# ci				= {ci & clip_state = Shown}
			# ps				= setClipInfo ci ps
			# (_,ps)			= message ci.clip_clipId (vHideCursor) ps
			= ps
		| otherwise
			// change menu...
			# ps				= appPIO (setMenuElementTitles [(ci.clip_itemId,"Show Clipboard")]) ps
			// close timer...
			# ps				= appPIO (closeTimer ci.clip_timeId) ps
			// close window...
			# ps				= closeEditWindow ci.clip_clipId ps
			# ci				= {ci & clip_state = Hidden}
			# ps				= setClipInfo ci ps
			# ps				= deactivate ps
			= ps
	where
		activate ps
			# ps = appPIO
					( disableMenuElements [mn_sav,mn_rev:ci.menuIds]
					o setMenuElementTitles [(mn_sav,"Save"),(mn_rev,"Revert")]
					) ps
			= ps
		tdef tId cId = Timer 1000 (NilLS) [TimerId tId, TimerFunction (noLS1 (const (show cId)))]
		show cId ps
			# (new,ps)	= clipboardHasChanged ps
			| new
				# (clip,ps)	= getClipboard ps
				# newtext	= StringToText (getString clip)
				# (_,ps)	= message cId (msgSetText newtext) ps
				# (_,ps)	= message cId (msgSetNeedSave False) ps
				# (_,ps)	= message cId (vHideCursor) ps
				= ps
			| otherwise
				= ps
	
		getString [clip:clips]
			# clip = fromClipboard clip
			| isNothing clip
				= getString clips
			| otherwise
				= fromJust clip
		getString []
			= ""
