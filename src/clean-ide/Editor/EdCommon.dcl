definition module EdCommon

from StdPSt			import :: PSt
from EdState		import class Editor, :: EditorState
from EdMonad		import :: EditMonad, :: StateM, :: EditState
from EdSelection	import :: Selection, :: Position

:: *PLocState :== MyEditorState
:: MyEditorState = MES EditorState

instance Editor MyEditorState

mRemoveSelection :: EditMonad (PSt *MyEditorState) nothing
mChangeSelectionTo	:: Selection				->	EditMonad (PSt *MyEditorState)	nothing
controlDoubleClick :: !.Bool !.Position -> .(!*(EditState,*PSt PLocState) -> *(a,*(EditState,*PSt PLocState)));
