definition module pdState;

// import SymbolTable;
from pdSymbol import :: Xcoff {header}, :: XcoffHeader{file_name}
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

//PutQDAddressInDLClientState :: ![!String] !*DLClientState -> !*DLClientState;

