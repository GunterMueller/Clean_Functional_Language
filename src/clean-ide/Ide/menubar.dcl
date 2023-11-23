definition module menubar

// File and Edit menu handling

import IdeState, EdMonad

mb_update_undoinfo	:: !*(PSt *General) -> *PSt *General
// update menubar for new undo state

mb_update_pathname	:: !.Pathname !*(PSt *General) -> *PSt *General;
// update menubar for new current pathname

mb_enable_pathname	:: !*(PSt *General) -> *PSt *General;
// enable pathname menubar items

mb_disable_pathname	:: !*(PSt *General) -> *PSt *General;
// disable pathname menubar items
