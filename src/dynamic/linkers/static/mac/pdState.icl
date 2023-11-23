implementation module pdState;

import SymbolTable;
//import State;
import State;
import DLState;
import ExtInt;

sel_platform winos macos :== macos;

sel_file_name xcoff :== sel_file_name xcoff
where {
	sel_file_name xcoff=:{header={file_name}}
		= (file_name,xcoff);
}

// PDState
:: *PDState = {
	// macOS; only used by the dynamic linker
		toc_p			:: !Int
	,	qd_address		:: !Int
	,	pointers		:: ![!Int]
	};
	
DefaultPDState :: !*PDState;
DefaultPDState 
	= { PDState |
		toc_p			= 0
	,	qd_address		= 0
	,	pointers		= []
	};
	
PutQDAddressInDLClientState :: ![!String] !*DLClientState -> !*DLClientState;
PutQDAddressInDLClientState args dl_client_state
	= app_pd_state (\pd_state -> {pd_state & qd_address = FromStringToInt (hd args) 0}) dl_client_state;


	
