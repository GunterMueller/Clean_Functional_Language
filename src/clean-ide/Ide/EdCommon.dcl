definition module EdCommon

import EdMonad
from IdeState import :: General

:: *PLocState :== General

mChangeSelectionTo	:: Selection				->	EditMonad (PSt General)	nothing
mRemoveSelection	:: 								EditMonad (PSt General) nothing
controlDoubleClick	:: !.Bool !.Position		->	EditMonad (PSt General) nothing
