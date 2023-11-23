definition module State;

from StdMisc import abort;
from StdArray import class Array (..);
from StdMaybe import :: Maybe;
from pdState import :: PDState, sel_platform, 
		get_header, get_text_relocations, get_data_relocations, get_n_symbols,
		get_text_v_address, get_data_v_address, get_toc0_symbols, get_toc_symbols;
from pdSymbolTable import :: Xcoff {symbol_table, file_name, module_name, n_symbols},
		:: LibraryList, :: Symbol,
		:: SymbolTable, :: SSymbolTable {symbols, data_symbols, text_symbols, bss_symbols},
		:: SymbolIndexList,
		:: SymbolArray, :: SSymbolArray;

from Redirections import :: RedirectionState, class GetPutRedirectionState;
from LinkerMessages import :: LinkerMessagesState, class AddMessage;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;

:: *State = {
	// misc
		linker_state_info	:: !LinkerStateInfo
	,	linker_messages_state:: !LinkerMessagesState
	
	// linker tables
	,	application_name	:: !String
	,	n_libraries			:: !Int
	,	n_xcoff_files 		:: !Int
	,	n_xcoff_symbols		:: !Int
	,	n_library_symbols	:: !Int
	
	,	marked_bool_a		:: !*{#Bool}
	,	marked_offset_a		:: !*{#Int}
	,	module_offset_a		:: !*{#Int}
	,	xcoff_a 			:: !*{#*Xcoff}
	,	namestable			:: !*NamesTable

	// dynamic libraries
	,	library_list 		:: !LibraryList
	,	library_file_names	:: [String]
	
	,	pd_state			:: !*PDState

	, 	st_redirection_state	:: !*RedirectionState
//	,	log_file			:: !*File
	
	,	begin_end_addresses	:: ![CodeAddress]

	,	jump_modules		:: [JumpModule]					// modules which are to be extended with a jump (file_n,symbol_n)
};

::	LinkerStateInfo = {
		one_pass_link			:: !Bool,
		normal_static_link		:: !Bool,
		linker_state_base_va	:: !Int
	};

:: CodeAddress
	= {
		ca_begin	:: !Int
	,	ca_end		:: !Int
	};
	
:: JumpModule
	= {
		jm_file_n	:: !Int
	,	jm_symbol_n	:: !Int
	,	jm_length	:: !Int
	};

EmptyState :: *State;

// xcoff_a access
app_xcoff_a :: ({#*Xcoff} -> {#*Xcoff}) !*State -> *State;
acc_xcoff_a :: ({#*Xcoff} -> (!.x,!{#*Xcoff})) !*State -> (!.x,!*State);
selacc_xcoff :: !Int (*Xcoff -> (!.x,!*Xcoff)) !*State -> (!.x,!*State);
selapp_xcoff :: !Int (*Xcoff -> *Xcoff) !*State -> *State;

// xcoff_a; symbol_table access
selacc_symbol_table :: !Int (*SymbolTable -> (!.x,!*SymbolTable)) !*State -> (!.x,!*State);

// xcoff_a; symbols
selacc_symbols :: !Int (*SymbolArray -> (!.x,!*SymbolArray)) !*State -> (!.x,!*State);
selapp_symbols :: !Int (*SymbolArray -> *SymbolArray) !*State -> *State;

// xcoff_a; symbol access
sel_symbol file_n symbol_n state :== sel_symbol file_n symbol_n state
where { 	
	sel_symbol file_n symbol_n state
		= state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
}
update_symbol :: !Symbol !Int !Int !State -> State;

class UpdateSymbol a
where {
	upd_symbol :: !Symbol !Int !Int !*a -> *a
};

instance UpdateSymbol State;
instance UpdateSymbol {#*Xcoff};

// marked_bool_a access
acc_marked_bool_a :: (*{#Bool} -> (!.x,!*{#Bool})) !*State -> (!.x,!*State);
selacc_marked_bool_a :: !Int !*State -> (!Bool,!*State);
	
// module_offset_a access
acc_module_offset_a :: (*{#Int} -> (!.x,!*{#Int})) !*State -> (!.x,!*State);
app_module_offset_a :: (*{#Int} -> *{#Int}) !*State -> *State;
selacc_module_offset_a :: !Int !*State -> (!Int,!*State);
		
// marked_offset_a access
acc_marked_offset_a :: (*{#Int} -> (!.x,!*{#Int})) !*State -> (!.x,!*State);	
selacc_marked_offset_a :: !Int !*State -> (!Int,!*State);	
selacc_so_marked_offset_a :: !Int !*State -> (!Int,!*State);
		
// namestable access
app_namestable :: (*NamesTable -> *NamesTable) !*State -> *State;
acc_namestable :: (*NamesTable -> (!.x,!*NamesTable)) !*State -> (!.x,!*State);

// General
select_namestable state					:== acc_namestable (\namestable -> (namestable,{})) state; 
update_namestable :: NamesTable !State -> State;
select_marked_bool_a :: !State -> (!*{#Bool},!State);
select_marked_offset_a :: !State -> (!*{#Int},!State);
select_module_offset_a :: !State -> (!*{#Int},!State);
select_xcoff_a :: !State -> (!{#*Xcoff},!State);
update_state_with_xcoff :: !*Xcoff !State -> State;

find_name :: !String !State -> (!Int,!Int,!State);
find_address_of_label :: !String !State -> (!Bool,!Int,!State);
address_of_label2 :: !Int !Int !State -> (!Int,!State);
address_of_label2_ :: !Int !Int !*State -> (!Maybe Int,!*State);

find_name4 :: !String !State -> (!Bool,!Int,!Int,!State);

// General
select_file_name file_n state :== sel_platform 
	(state!xcoff_a.[file_n].file_name)
	(abort "macOS: selecties direkt maken pdSymbolTable)")
	; 
	
select_module_name file_n state 
	:==  (state!xcoff_a.[file_n].module_name);
	
// winos specific				
select_n_symbols file_n state :== sel_platform
	(state!xcoff_a.[file_n].n_symbols)
	(abort "select_n_symbols (state): macOS");
	
selacc_bss_symbols file_n state :== 
	(state!xcoff_a.[file_n].symbol_table.bss_symbols)
	;
	
selacc_data_symbols file_n state :== 
	(state!xcoff_a.[file_n].symbol_table.data_symbols)
	;
		
selacc_text_symbols file_n state :== 
	(state!xcoff_a.[file_n].symbol_table.text_symbols)
	;
	
// macOS specific

// for xcoff:
selacc_text_relocations file_n state :== sel_platform
	(abort "selacc_text_relocations (state): winOS")
	(selacc_xcoff file_n get_text_relocations state);

selacc_data_relocations file_n state :== sel_platform
	(abort "selacc_data_relocations (state): winOS")
	(selacc_xcoff file_n get_data_relocations state);
	
selacc_header file_n state :== sel_platform
	(abort "selacc_header (state): winOS")
	(selacc_xcoff file_n get_header state);
	
selacc_n_symbols file_n state :== sel_platform
	(abort "selacc_n_symbols (state): winOS")
	(selacc_xcoff file_n get_n_symbols state);
	
selacc_text_v_address file_n state 	:== sel_platform
	(abort "selacc_text_v_address (state): winOS")
	(selacc_xcoff file_n get_text_v_address state);
	
selacc_data_v_address file_n state 	:== sel_platform
	(abort "selacc_data_v_address (state): winOS")
	(selacc_xcoff file_n get_data_v_address state);
	
selacc_toc0_symbols file_n state 	:== sel_platform
	(abort "selacc_toc0_symbols (state): winOS")
	(selacc_symbol_table file_n get_toc0_symbols state);
	
selacc_toc_symbols file_n state 	:== sel_platform
	(abort "selacc_toc_symbols (state): winOS")
	(selacc_symbol_table file_n get_toc_symbols state);

is_defined_symbol :: !String !*State -> (!Bool,!Int,!Int,!*State);

instance AddMessage State;

app_pdstate :: (*PDState -> *PDState) !*State -> *State;
acc_pdstate :: (*PDState -> (!.x,!*PDState)) !*State -> (!.x,!*State);

find_name3 :: .Int .Int !*State -> *(.Bool,{#Char},*State);

instance GetPutRedirectionState State;

class symbol_n_to_offset s :: !.Int !.Int !*s -> *(Int,*s);

instance symbol_n_to_offset State;
