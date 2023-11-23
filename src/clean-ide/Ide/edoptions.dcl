definition module edoptions

// various options dialogues

from StdPSt		import :: PSt
from EdState	import :: EditorState, class Editor
from IDE		import :: General

optionsKeyMapping	:: !*(PSt *l) -> *PSt *l | Editor l
defaultColours		:: !*(PSt *General) -> *(PSt *General)
defaultFontAndTabs	:: !*(PSt *General) -> *(PSt *General)
editColours			:: !*(PSt *General) -> *(PSt *General)
