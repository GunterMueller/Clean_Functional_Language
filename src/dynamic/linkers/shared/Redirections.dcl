definition module Redirections;

from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;

:: *RedirectionState = {
	// (used to redirect rts labels to the rts labels of the main library)
		rs_main_names_table		:: !*NamesTable	
	,	rs_rts_modules			:: [String]
	,	rs_change_rts_label		:: !Bool
	};
		
default_redirection_state :: *RedirectionState;

class GetPutRedirectionState s 
where {
	get_redirection_state :: !*s -> (!*RedirectionState,!*s);
	put_redirection_state :: !*RedirectionState !*s -> *s
};

