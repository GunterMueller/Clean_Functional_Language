definition module typewin

// Types window

import StdPSt, StdId, StdWindowDef
from UtilStrictLists import :: List
from EdMonad import :: EditState, :: EditMonad, :: StateM
from PmPrefs import :: TypPrefs
from EdMessage import :: EditId

iniTypeWinInfo :: !Id !Id ![Id] !TypPrefs !*a -> *(.TypeWinInfo,*a) | Ids, accScreenPicture a
// initialise type window info

updateTypeWindow :: !Bool !String [WindowAttribute *(EditState,*(PSt *l))] ![String] !*(PSt *l) -> *PSt *l | Typer l
// add content to the types window

isTypeWindow :: !Id !.TypeWinInfo -> Bool
// is window the Types window

tw_maybe_close :: !Id !*(PSt *l) -> *(Bool,*(PSt *l)) | Typer l
// tw_maybe_close :: close window if it is types window

tw_safe_close :: !*(PSt *l) -> *PSt *l | Typer l
// tw_safe_close :: close types window

class Typer env
where
	getTypeWinInfo :: !*env -> *(!TypeWinInfo, !*env)
	setTypeWinInfo :: !TypeWinInfo !*env -> *env

:: TypeWinInfo

// TypeWinInfo accessors
TW_GetInf :: !TypeWinInfo -> TypPrefs
TW_SetUpd :: ![Id] !TypeWinInfo -> TypeWinInfo

// message passing with types window
maybe_type_win_message :: !Id .(EditMonad *(PSt *l) .c) !*(PSt *l) -> (Maybe .c,*(PSt *l)) | Typer l
type_win_message :: !.(EditMonad *(PSt *l) .c) !*(PSt *l) -> *(Maybe .c,*(PSt *l)) | Typer l

// dialogue to set colours for types window
typewinColours :: !*(PSt *l) -> *(PSt *l) | Typer l
