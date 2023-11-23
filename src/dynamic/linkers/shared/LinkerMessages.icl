implementation module LinkerMessages;

import StdEnv;
from StdBool import not;
from StdList import isEmpty, ++;
import RWSDebugChoice;
import StdList;
import link_switches;
from StdMisc import abort;

:: LinkerMessagesState = { 
		ok							:: !Bool,
		messages_in_right_order		:: LinkerMessages,
		messages_in_reverse_order	:: LinkerMessages
	};
	
:: LinkerMessages :== [LinkerMessage];

:: LinkerMessage 
	= LinkerError !String
	| LinkerWarning !String
	| Verbose !String
	;
	
instance toString LinkerMessage
where {
	toString (LinkerError error)
		= "Linker error: " +++ error;
	toString (LinkerWarning warning)
		= "Linker warning: " +++ warning;
	toString (Verbose msg)
		= "Linker message: " +++ msg;
};
	
// Operations on Linker Messages

DefaultLinkerMessages :: LinkerMessagesState;
DefaultLinkerMessages 
	= { LinkerMessagesState | ok = True, messages_in_right_order = [], messages_in_reverse_order = [] };

class LinkError .a
where {
	isLinkerErrorOccured :: !.a -> (!Bool,!.a);
	
	addLinkMessage :: !LinkerMessage !.a -> .a
};

instance LinkError LinkerMessagesState
where {
	isLinkerErrorOccured state=:{ok} = (ok,state);
	
	addLinkMessage message linker_message_state
		= addLinkerMessage message linker_message_state
};

isLinkerError (LinkerError _) = True;
isLinkerError _ = False;

strip_linker_message (LinkerError s)	= s;
strip_linker_message (LinkerWarning s)	= s;
strip_linker_message (Verbose s)		= s;

setLinkerMessages :: !LinkerMessages !.LinkerMessagesState -> .LinkerMessagesState;
setLinkerMessages linker_messages linker_messages_state=:{messages_in_reverse_order}
	= set_linker_messages linker_messages linker_messages_state		
where {
	set_linker_messages linker_messages linker_messages_state=:{messages_in_reverse_order}
		| True <<- (map strip_linker_message linker_messages)

		#! linker_errors
			= [ m \\ m <- linker_messages | isLinkerError m];
		= { linker_messages_state &
			ok = isEmpty linker_errors
		,	messages_in_reverse_order = reverse linker_messages ++ messages_in_reverse_order
		};	
};
setLinkerMessages _ _
	= abort "setLinkerMessage: mismatch";

setLinkerError error :== setLinkerMessages [LinkerError error] DefaultLinkerMessages;

getLinkerMessages :: !LinkerMessagesState -> (!LinkerMessages,!LinkerMessagesState);
getLinkerMessages linker_messages_state=:{messages_in_right_order=[],messages_in_reverse_order=[]}
	= ([],linker_messages_state);
getLinkerMessages linker_messages_state=:{messages_in_right_order,messages_in_reverse_order=[] }
	= (messages_in_right_order,linker_messages_state);
getLinkerMessages linker_messages_state=:{messages_in_right_order,messages_in_reverse_order}
	= getLinkerMessages {linker_messages_state &
			messages_in_right_order=messages_in_right_order ++ reverse messages_in_reverse_order,
			messages_in_reverse_order=[]
		};
	
addLinkerMessage message linker_messages_state :== setLinkerMessages [message] linker_messages_state;

addLinkerDebugMessage message linker_messages_state :== DEBUG_INFO (setLinkerMessages [Verbose message] linker_messages_state) linker_messages_state;

class AddMessage .a 
where {
	AddMessage :: !LinkerMessage !*a -> *a;
	AddDebugMessage :: !String !*a -> *a;
	IsErrorOccured :: !*a -> (!Bool,!*a);
	
	GetLinkerMessages :: !*a -> (!LinkerMessages,!*a);
	
	SetLinkerMessages :: !LinkerMessages !*a -> *a
};