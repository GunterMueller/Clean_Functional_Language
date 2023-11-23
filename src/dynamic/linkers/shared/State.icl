implementation module State;

import StdEnv;
import pdState;
import LinkerMessages;
import RWSDebugChoice;	
import Redirections;
from utilities import foldSt;
import pdSymbolTable;
import NamesTable;
import StdMaybe;

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
	
EmptyState :: *State;
EmptyState
	# linker_state_info = {	one_pass_link = True, normal_static_link = True,linker_state_base_va = 0 };
	= { linker_state_info = linker_state_info
	,	linker_messages_state= DefaultLinkerMessages
	
	// linker tables
	,	application_name	= ""
	,	n_libraries			= 0
	,	n_xcoff_files 		= 0
	,	n_xcoff_symbols		= 0
	,	n_library_symbols	= 0
	,	marked_bool_a		= {}
	,	marked_offset_a		= {}
	,	module_offset_a		= {}
	,	xcoff_a 			= {}
	,	namestable			= create_names_table
	
	// dynamic libraries
	,	library_list 		= EmptyLibraryList
	,	library_file_names	= []
	
	,	pd_state			= DefaultPDState
	
	,	st_redirection_state	= default_redirection_state
//	,	log_file			= stderr
	,	begin_end_addresses	= []
	,	jump_modules		= []
};

// xcoff_a access
app_xcoff_a :: ({#*Xcoff} -> {#*Xcoff}) !*State -> *State;
app_xcoff_a  f state=:{xcoff_a}
	= { state & xcoff_a = f xcoff_a };
	
acc_xcoff_a :: ({#*Xcoff} -> (!.x,!{#*Xcoff})) !*State -> (!.x,!*State);
acc_xcoff_a f state=:{xcoff_a}
	#! (x,xcoff_a)
		= f xcoff_a;
	= (x,{ state & xcoff_a = xcoff_a });

selacc_xcoff :: !Int (*Xcoff -> (!.x,!*Xcoff)) !*State -> (!.x,!*State);
selacc_xcoff i f state=:{xcoff_a}
	#! (xcoff,xcoff_a)
		= replace xcoff_a i empty_xcoff;
	#! (x,xcoff)
		= f xcoff;
	= (x,{state & xcoff_a = {xcoff_a & [i] = xcoff}});

selapp_xcoff :: !Int (*Xcoff -> *Xcoff) !*State -> *State;
selapp_xcoff i f state=:{xcoff_a}
	#! (xcoff,xcoff_a)
		= replace xcoff_a i empty_xcoff;
	= {state & xcoff_a = {xcoff_a & [i] = f xcoff}};
	
// xcoff_a; symbol_table access
selacc_symbol_table :: !Int (*SymbolTable -> (!.x,!*SymbolTable)) !*State -> (!.x,!*State);
selacc_symbol_table i f state
		= selacc_xcoff i w1 state;
where {
	w1 xcoff=:{symbol_table}
		#! (x,symbol_table)
			= f symbol_table;
		= (x, {xcoff & symbol_table = symbol_table})
}

selapp_symbol_table :: !Int (*SymbolTable -> *SymbolTable) !*State -> *State;
selapp_symbol_table i f state
	= selapp_xcoff i w2 state;
where {
	w2 :: !*Xcoff -> *Xcoff;
	w2 xcoff=:{symbol_table}
		= {xcoff & symbol_table = f symbol_table};
}

// symbols
selacc_symbols :: !Int (*SymbolArray -> (!.x,!*SymbolArray)) !*State -> (!.x,!*State);
selacc_symbols file_n  f state
		= selacc_symbol_table file_n w3 state;
where { 
	w3 symbol_table=:{symbols}
		#! (x,symbols)
			= f symbols;
		= (x, {symbol_table & symbols = symbols} );
}

selapp_symbols :: !Int (*SymbolArray -> *SymbolArray) !*State -> *State;
selapp_symbols file_n f state
	= selapp_symbol_table file_n w4 state;
where {
	w4 :: !*SymbolTable -> *SymbolTable;
	w4 symbol_table=:{symbols}
		= {symbol_table & symbols = f symbols};
}
	
sel_symbol file_n symbol_n state :== sel_symbol file_n symbol_n state
where { 	
	sel_symbol file_n symbol_n state
		= state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
}

class UpdateSymbol a
where {
	upd_symbol :: !Symbol !Int !Int !*a -> *a
};

instance UpdateSymbol State 
where {
	upd_symbol symbol file_n symbol_n state
		= update_symbol symbol file_n symbol_n state
};

instance UpdateSymbol {#*Xcoff}
where {
	upd_symbol symbol file_n symbol_n xcoff_a
		| file_n < 0
			= abort "update_symbol: not a dll";
			= { xcoff_a & [file_n].symbol_table.symbols.[symbol_n] = symbol };
};

update_symbol :: !Symbol !Int !Int !State -> State;
update_symbol symbol file_n symbol_n state
	| file_n < 0
		= abort "update_symbol: not a dll";
		= { state & xcoff_a.[file_n].symbol_table.symbols.[symbol_n] = symbol };

// marked_bool_a access
acc_marked_bool_a :: (*{#Bool} -> (!.x,!*{#Bool})) !*State -> (!.x,!*State);
acc_marked_bool_a f state=:{marked_bool_a} 
	#! (x,marked_bool_a)
		= f marked_bool_a;
	= (x,{state & marked_bool_a = marked_bool_a});
	
selacc_marked_bool_a :: !Int !*State -> (!Bool,!*State);
selacc_marked_bool_a i state
	= state!marked_bool_a.[i];
	
// module_offset_a access
acc_module_offset_a :: (*{#Int} -> (!.x,!*{#Int})) !*State -> (!.x,!*State);
acc_module_offset_a f state=:{module_offset_a} 
	#! (x,module_offset_a)
		= f module_offset_a;
	= (x,{state & module_offset_a = module_offset_a});
	
app_module_offset_a :: (*{#Int} -> *{#Int}) !*State -> *State;
app_module_offset_a f state=:{module_offset_a}	
	= { state & module_offset_a = f module_offset_a };
	
selacc_module_offset_a :: !Int !*State -> (!Int,!*State);
selacc_module_offset_a i state
	= state!module_offset_a.[i];
		
// marked_offset_a access
acc_marked_offset_a :: (*{#Int} -> (!.x,!*{#Int})) !*State -> (!.x,!*State);
acc_marked_offset_a f state=:{marked_offset_a} 
	#! (x,marked_offset_a)
		= f marked_offset_a;
	= (x,{state & marked_offset_a = marked_offset_a});
	
selacc_marked_offset_a :: !Int !*State -> (!Int,!*State);
selacc_marked_offset_a i state
	= state!marked_offset_a.[i];
	
selacc_so_marked_offset_a :: !Int !*State -> (!Int,!*State);
selacc_so_marked_offset_a file_n state
	#! (s_marked_offset_a,state)
		= acc_marked_offset_a usize state;
	= selacc_marked_offset_a (file_n + s_marked_offset_a) state;
		
// namestable access
app_namestable :: (*NamesTable -> *NamesTable) !*State -> *State;
app_namestable f state=:{namestable}
	= { state & namestable = (f namestable) };

acc_namestable :: (*NamesTable -> (!.x,!*NamesTable)) !*State -> (!.x,!*State);
acc_namestable f state=:{namestable}
	#! (x,namestable)
		= f namestable;
	= (x, { state & namestable = namestable } );

// General
// select_namestable state					:== acc_namestable (\namestable -> (namestable,{})) state; 

update_namestable :: NamesTable !State -> State;
update_namestable namestable state
	= {state & namestable = namestable};
	
select_marked_bool_a :: !State -> (!*{#Bool},!State);
select_marked_bool_a state=:{marked_bool_a}
	= (marked_bool_a,{state & marked_bool_a = {}});

select_marked_offset_a :: !State -> (!*{#Int},!State);
select_marked_offset_a state=:{marked_offset_a}
	= (marked_offset_a,{state & marked_offset_a = {}});
	
select_module_offset_a :: !State -> (!*{#Int},!State);
select_module_offset_a state=:{module_offset_a}
	= (module_offset_a,{state & module_offset_a = {}});
	
select_xcoff_a :: !State -> (!{#*Xcoff},!State);
select_xcoff_a state=:{xcoff_a}
	= (xcoff_a,{state & xcoff_a = {}});
	
update_state_with_xcoff :: !*Xcoff !State -> State;
update_state_with_xcoff xcoff state=:{xcoff_a,n_xcoff_files}
	= {state & xcoff_a = fill_xcoff_array xcoff 0 n_xcoff_files xcoff_a (xcoff_array (n_xcoff_files+1)) };
{
	xcoff_array :: !Int -> *{#*Xcoff};
	xcoff_array n = {empty_xcoff \\ i<-[0..dec n]};
	
	fill_xcoff_array :: *Xcoff !Int !Int !*{#*Xcoff} !*{#*Xcoff} -> *{#*Xcoff};
	fill_xcoff_array xcoff i n_xcoff_files old_xcoff_a new_xcoff_a
		| i == n_xcoff_files
			= {new_xcoff_a & [n_xcoff_files] = xcoff};
			
			#! (old_xcoff,old_xcoff_a1) 
				= replace old_xcoff_a i empty_xcoff;
			= fill_xcoff_array xcoff (inc i) n_xcoff_files old_xcoff_a1 {new_xcoff_a & [i] = old_xcoff};
}

find_name :: !String !State -> (!Int,!Int,!State);
find_name name state
	#! (namestable,state)
		= select_namestable state;
	#! (names_table_element,namestable)
		= find_symbol_in_symbol_table name namestable
	#! state
		= update_namestable namestable state;
	
	= case names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			-> (file_n,symbol_n,state);
		_
			-> abort ("find_name: name not found" +++ name );
	  };

address_of_label2 :: !Int !Int !State -> (!Int,!State);
address_of_label2 file_n symbol_n state
	#! (maybe_address,state)
		= address_of_label2_ file_n symbol_n state;
	| isNothing maybe_address
		= abort "address_of_label2; internal error";
		
		= (fromJust maybe_address,state);

address_of_label2_ :: !Int !Int !*State -> (!Maybe Int,!*State);
address_of_label2_ file_n symbol_n state
	#! (first_symbol_n,state1)
		= selacc_marked_offset_a file_n state1;
	#! (marked,state1)
		= selacc_marked_bool_a (first_symbol_n+symbol_n) state1;
	| not marked 
		= (Just 0,state1)
		
		| isLabel label_symbol
			#! module_n
				= getLabel_module_n label_symbol;
			#! offset
				= getLabel_offset label_symbol;
				
			#! (module_symbol,state1)
				= sel_symbol file_n module_n state1;
			| isModule module_symbol
				#! virtual_label_offset
					= getModule_virtual_label_offset module_symbol;
				#! (first_symbol_n,state1) 
					= selacc_marked_offset_a file_n state1;
				#! (real_module_offset,state1)
					= selacc_module_offset_a (first_symbol_n + module_n) state1;
				= (Just (real_module_offset+offset-virtual_label_offset),state1);
				
				= (Nothing,state1)
		| isModule label_symbol
			#! (a,state1)
				= (sel_platform address_of_label2_pc address_of_label2_mac) state1;
			= (Just a,state1);
			= (Nothing,state1);
where {
	isModule :: !Symbol -> Bool;
	isModule (Module  _ _ _ _ _ _ _)	= True;
	isModule s						= False;

	(label_symbol,state1)
		= sel_symbol file_n symbol_n state;
		
	address_of_label2_pc state
		#! module_n
			= symbol_n;
		#! module_symbol
			= label_symbol;
			
		#! virtual_label_offset
			= getModule_virtual_label_offset module_symbol;
		#! (first_symbol_n,state) 
			= selacc_marked_offset_a file_n state;
		#! (real_module_offset,state)
			= selacc_module_offset_a (first_symbol_n + module_n) state;
			
		#! q = real_module_offset-virtual_label_offset;
		| True
		= (q,state);
		
	address_of_label2_mac state
		#! module_n
			= symbol_n;
		#! module_symbol
			= label_symbol;
			
		#! (first_symbol_n,state) 
			= selacc_marked_offset_a file_n state;
		#! (real_module_offset,state)
			= selacc_module_offset_a (first_symbol_n + module_n) state;
		= (real_module_offset,state);

} // address_of_label2

find_address_of_label :: !String !State -> (!Bool,!Int,!State);
find_address_of_label label state
	#! (ok,file_n,label_n,state)
		= find_name2 label state;
	| not ok
		= (False,0,state);
	#! (addr,state)
		= address_of_label2 file_n label_n state;
	= (True,addr,state);

find_name2 :: !String !State -> (!Bool,!Int,!Int,!State);
find_name2 name state 
	#! (namestable,state)
		= select_namestable state;
	#! (names_table_element,namestable)
		= find_symbol_in_symbol_table name namestable;
	#! state
		= update_namestable namestable state;
	
	= case names_table_element of {
		(NamesTableElement _ symbol_n file_n _)
			-> (True,file_n,symbol_n,state);
		_
			-> (False,0,0,state);
	  };
	  
find_name4 :: !String !State -> (!Bool,!Int,!Int,!State);
find_name4 name state = find_name2 name state;


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
is_defined_symbol symbol_name state
	#! (namestable,state)
		= select_namestable state;
	#! (names_table_element,namestable)
		= find_symbol_in_symbol_table symbol_name namestable;
	#! state
		= update_namestable namestable state;
	= case names_table_element of {
		NamesTableElement _ symbol_n file_n _ 
			-> (True,file_n,symbol_n,state);
		_
			-> (False,0,0,state);
	};
	
strip_linker_message (LinkerError s)	= s;
strip_linker_message (LinkerWarning s)	= s;
strip_linker_message (Verbose s)		= s;
strip_linker_message _					= abort "strip_linker_message";

fflush f = (True,f);

instance AddMessage State
where {
	AddMessage linker_message state=:{linker_messages_state}
/*
		// log ...
		#! log_file
			= fwrites (strip_linker_message linker_message) state.log_file;
		#! log_file
			= fwritec '\n' log_file;
		#! (ok,log_file)
			= fflush log_file;
		| not ok <<- linker_message
			= abort "AddMessage: could not flush";
		# state
			= {state & log_file = log_file}
		// ... log
*/
		# linker_messages_state = addLinkerMessage linker_message linker_messages_state;
		= {state & linker_messages_state = linker_messages_state};

	AddDebugMessage linker_message state=:{linker_messages_state}
		# linker_messages_state = addLinkerDebugMessage linker_message linker_messages_state;
		= {state & linker_messages_state = linker_messages_state};

	IsErrorOccured state=:{linker_messages_state}
		#! (ok,linker_messages_state) = isLinkerErrorOccured linker_messages_state;
		 = (ok,state);

	GetLinkerMessages state=:{linker_messages_state}
		#! (messages,linker_messages_state) = getLinkerMessages linker_messages_state;
		= (messages,{state & linker_messages_state=linker_messages_state});
		
	SetLinkerMessages messages state=:{linker_messages_state}
/*
		// log ...
		# log_file
			=	state.log_file
		#! log_file
			= foldSt (\msg log_file -> fwritec '\n' (fwrites (strip_linker_message msg) log_file) )  messages log_file
		#! (ok,log_file)
			= fflush log_file;
		| not ok
			= abort "SetLinkerMessages: could not flush";
		# state
			= {state & log_file = log_file}
		// ... log
*/
		#! linker_messages_state
			= setLinkerMessages messages linker_messages_state;
		= {state & linker_messages_state = linker_messages_state};
};

app_pdstate :: (*PDState -> *PDState) !*State -> *State;
app_pdstate f state=:{pd_state}
	#! pd_state
		= f pd_state;
	= { state & pd_state = pd_state };
	
acc_pdstate :: (*PDState -> (!.x,!*PDState)) !*State -> (!.x,!*State);
acc_pdstate f state=:{pd_state}
	#! (x,pd_state)
		= f pd_state;
	= (x,{ state & pd_state = pd_state});
		

find_name3 :: .Int .Int !*State -> *(.Bool,{#Char},*State);
find_name3 file_n relocation_symbol_n state
	#! (names_table,state)
		= select_namestable state;
	#! (s_names_table,names_table)
		= usize names_table;
		
	#! (found,name,names_table)
		= search 0 s_names_table names_table
	#! state
		= update_namestable names_table state;
	= (found,name,state);
where {
	search i limit names_table
		| i == limit
			= (False,"",names_table);

		#! (names_table_element,names_table)
			= names_table![i];
		#! (found,name)
			= search_in_names_table names_table_element;
		| not found
			= search (inc i) limit names_table;

			= (found,name,names_table);
	
	search_in_names_table EmptyNamesTableElement
		= (False,"");
	search_in_names_table (NamesTableElement name n_symbol_n n_file_n rest)
		| n_symbol_n == relocation_symbol_n && n_file_n == file_n
			= (True,name);
		= search_in_names_table rest;		
}

instance GetPutRedirectionState State
where {
	get_redirection_state state=:{st_redirection_state}
		= (st_redirection_state,{ state & st_redirection_state = default_redirection_state } );
	put_redirection_state redirection_state state
		= { state & st_redirection_state = redirection_state };
};

// for use in marked_bool_a and module_offset_a
class symbol_n_to_offset s :: !.Int !.Int !*s -> *(Int,*s);

instance symbol_n_to_offset State
where {
	symbol_n_to_offset file_n symbol_n state
		#! (first_symbol_n,state)
			= case (file_n < 0) of {
				True	
					#! (s_marked_offset,state)
						= acc_marked_offset_a usize state;
					-> state!marked_offset_a.[s_marked_offset + file_n];
				False
					-> state!marked_offset_a.[file_n];
			};
		#! symbol_index
			= first_symbol_n + symbol_n;
		= (symbol_index,state);
};