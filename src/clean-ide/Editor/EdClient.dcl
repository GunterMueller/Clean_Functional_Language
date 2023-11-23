definition module EdClient

import EdMonad, EdState, EdCommon
from EdMessage import :: EditAction

sendToActiveWindow :: .(*(EditState,*PSt *b) -> *(.c,*(EditState,*PSt *b))) !*(PSt *b) -> *(Maybe .c,*PSt *b) | Editor b

message :: !Id !.(*(EditState,*PSt *b) -> *(.c,*(EditState,*PSt *b))) !*(PSt *b) -> *(Maybe .c,*PSt *b) | Editor b;

// Messages

msgSave		::						EditAction *l nothing
msgCopy		::						EditAction *l nothing
msgCut		::						EditAction *MyEditorState nothing
msgPaste	::						EditAction *MyEditorState nothing
msgClear	::						EditAction *MyEditorState nothing
msgSetFont	:: Font	->				EditAction *l nothing
msgGetFont	::						EditAction .l Font
msgSetTabs	:: !(Int,Bool,Bool) ->	EditAction *l nothing
msgGetTabs	::						EditAction .l (Int,Bool,Bool)
