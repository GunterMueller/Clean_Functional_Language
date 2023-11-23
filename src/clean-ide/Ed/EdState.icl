implementation module EdState

// the global state of the editor process

import StdList, StdFunc, StdTuple, StdBool, StdMisc
import StdId, StdMaybe, StdReceiver, StdPSt
import EdKeyMapping, EdMessage, Table

class Editor env
where
	getEditorState :: !*env -> *(!EditorState,!*env)
	setEditorState :: !EditorState !*env -> *env

instance Editor (PSt *l) | Editor l
where
	getEditorState ps = accPLoc getEditorState ps
	setEditorState es ps = appPLoc (setEditorState es) ps

:: EditorState
	= { windows		:: Table Id EditId
	  , keyMapping	:: KeyMapping
	  }

initEditorState :: !KeyMapping -> EditorState
initEditorState km
	= { windows		= tableNew
	  , keyMapping	= km
	  }

getKeyMapping :: !EditorState -> KeyMapping
getKeyMapping { keyMapping } = keyMapping

setKeyMapping :: KeyMapping !EditorState -> EditorState
setKeyMapping keyMapping editorState
  = { editorState & keyMapping = keyMapping }
  
addReceiver :: Id EditId !EditorState -> EditorState
addReceiver windowId editId editorState=:{ windows }
  = { editorState & windows = tableInsert (windowId, editId) windows }

removeReceiver :: Id !EditorState -> EditorState
removeReceiver windowId editorState=:{ windows }
  = { editorState & windows = tableRemove windowId windows }

// lookup the window identification number in the global administration

findReceiver :: !Id !EditorState -> (!Maybe EditId, !EditorState)
findReceiver windowId (es=:{ windows })
  | isEmpty matches = (Nothing, es)
  | otherwise       = (Just (hd matches), es)
  where
    matches = tableLookup windowId windows

