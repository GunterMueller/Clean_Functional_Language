definition module EdState

// the global state of the editor process

from StdId			import :: Id
from StdPSt			import :: PSt
from StdMaybe		import :: Maybe
from EdKeyMapping	import :: KeyMapping
from EdMessage		import :: EditId

class Editor env
where
	getEditorState :: !*env -> *(!EditorState,!*env)
	setEditorState :: !EditorState !*env -> *env

instance Editor (PSt *l) | Editor l

:: EditorState

initEditorState		:: !KeyMapping					->	EditorState

findReceiver		:: !Id			!EditorState	->	(!Maybe EditId, !EditorState)
addReceiver			:: Id EditId	!EditorState	->	EditorState
removeReceiver		:: Id			!EditorState	->	EditorState

getKeyMapping		::				!EditorState	->	KeyMapping
setKeyMapping		:: KeyMapping	!EditorState	->	EditorState

