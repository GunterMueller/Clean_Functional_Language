definition module clipboard

// Clipboard window handling

import StdId, StdPSt, StdMenuDef
import EdState

:: ClipInfo

class Clipper env where
	getClipInfo		:: !*env -> *(!ClipInfo,!*env)
	setClipInfo		:: !ClipInfo !*env -> *env

instance Clipper (PSt *l) | Clipper l

isClipboardWindow	:: !Id !*env -> (Bool,*env) | Clipper env

initClipInfo		:: Id [Id] *env -> *(ClipInfo,*env) | Ids env
clipMenuItems		:: !Id !Id !ClipInfo -> .MenuItem .c *(PSt *l) | Clipper , Editor l
cw_maybe_close		:: !Id !*(PSt *l) -> (Bool,*PSt *l) | Clipper, Editor l

// avoid compiler warnings...

:: ClipState`
instance == ClipState`
