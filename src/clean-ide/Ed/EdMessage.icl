implementation module EdMessage

// message passing with the editor

import StdFunc, StdMisc
import StdReceiver, StdPSt, StdId
import EdMonad

:: EditId
   :== R2Id Message Message
   
:: Message
   = MsgState EditState	// send/receive the state
   | MsgGet				// ask for the state
   | MsgOk				// signifies that a send operation was successful

:: EditAction l a :== EditMonad (PSt l) a

openEditId :: *env -> (EditId, *env) | Ids env
openEditId pstate
  = openR2Id pstate

openEditReceiver :: !EditId -> Receiver2 Message Message EditState (PSt .l)
openEditReceiver editId
  = Receiver2 editId receive []

// receive a message from the outside world

receive :: Message (EditState, PSt .l) ->
		 (Message, (EditState, PSt .l))
receive message (editState, pstate)
  = case message of
	  MsgGet				-> (MsgState editState, (editState, pstate))
	  MsgState newEditState	-> (MsgOk,			 (newEditState, pstate))
	  _						-> abort "receive (EdMessage.icl): unknown message type"

// hasEditState

hasEditState :: !EditId !*(PSt .l) -> *(Bool, *PSt .l)
hasEditState editId pstate
  # ((_, maybeResp), pstate) = syncSend2 editId MsgGet pstate
  = (isJust maybeResp, pstate)

// appEditState 

appEditState :: !EditId !.(EditAction .l .r) !*(PSt .l) -> *(.r,*PSt .l)
appEditState editId monad pState
  # (editState, pState)			= getEditState editId pState
  # (x, (editState, pState))	= monad (editState, pState)
  #!	pState					= setEditState editId editState pState
  = (x, pState)

// getEditState 

getEditState :: !EditId !*(PSt .l) -> *(EditState, *PSt .l)
getEditState editId pstate
  # ((_, maybeResp), pstate) = syncSend2 editId MsgGet pstate
  | isNothing maybeResp
	= abort "getEditState (EdMessage.icl): no response"
	= case fromJust maybeResp of
		MsgState editState	-> (editState, pstate)
		_					-> abort "getEditState (EdMessage.icl): unknown response"
  

setEditState :: !EditId !EditState !*(PSt .l) -> *PSt .l
setEditState editId editState pstate
  # ((_, maybeResp), pstate) = syncSend2 editId (MsgState editState) pstate
  | isNothing maybeResp
	= abort "setEditState (EdMessage.icl): no response"
	= case fromJust maybeResp of
		MsgOk	-> pstate
		_		-> abort "setEditState (EdMessage.icl): unknown response"

