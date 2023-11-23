definition module LinkerMessages;

from link_switches import DEBUG_INFO;

// Linker Messages; messages should added in reverse order
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
	
// Operations on Linker Messages
DefaultLinkerMessages :: LinkerMessagesState;

class LinkError .a
where {
	isLinkerErrorOccured :: !.a -> (!Bool,!.a);
	
	addLinkMessage :: !LinkerMessage !.a -> .a
};

instance LinkError LinkerMessagesState;

setLinkerMessages :: !LinkerMessages !.LinkerMessagesState -> .LinkerMessagesState;

setLinkerError error :== setLinkerMessages [LinkerError error] DefaultLinkerMessages;
getLinkerMessages :: !LinkerMessagesState -> (!LinkerMessages,!LinkerMessagesState);

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