implementation module Redirections;

import StdArray;
import StdMaybe;
import NamesTable;

:: *RedirectionState = {
		rs_main_names_table		:: !*NamesTable
	,	rs_rts_modules			:: [String]
	,	rs_change_rts_label		:: !Bool
	};
		
default_redirection_state :: *RedirectionState;
default_redirection_state 
	= { RedirectionState |
		rs_main_names_table		= {}
	,	rs_rts_modules			= []
	,	rs_change_rts_label		= False
	};
	
class GetPutRedirectionState s 
where {
	get_redirection_state :: !*s -> (!*RedirectionState,!*s);
	put_redirection_state :: !*RedirectionState !*s -> *s
};


