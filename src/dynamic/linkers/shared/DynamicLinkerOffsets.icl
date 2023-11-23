implementation module DynamicLinkerOffsets;

from DynamicLink import SetCurrentLibrary, StoreLong, GetFuncAddress;
from Offsets import Remove_at_size;
import StdEnv;
import pdSymbolTable;
from LibraryInstance import ::Libraries(..);

Dcompute_imported_library_symbol_offsets_for_libraries :: !Libraries !Int Int *{#Bool} !*{#Int} !*{#Int} -> (!Libraries,!Int,!*{#Bool},!*{#Int},!*{#Int});
Dcompute_imported_library_symbol_offsets_for_libraries EmptyLibraries thunk_data_offset library_file_n marked_bool_a module_offset_a marked_offset_a
	= (EmptyLibraries,thunk_data_offset,marked_bool_a,module_offset_a,marked_offset_a);
Dcompute_imported_library_symbol_offsets_for_libraries (Libraries library_list libraries) thunk_data_offset library_file_n marked_bool_a module_offset_a marked_offset_a
	#! first_symbol_n = marked_offset_a.[size marked_offset_a+library_file_n];
	# (marked_bool_a,library_list,thunk_data_offset,module_offset_a)
		= Dcompute_imported_library_symbol_offsets library_list thunk_data_offset first_symbol_n marked_bool_a module_offset_a;
	# library_file_n = compute_new_library_file_n library_list library_file_n;
	# (libraries,thunk_data_offset,marked_bool_a,module_offset_a,marked_offset_a)
		= Dcompute_imported_library_symbol_offsets_for_libraries libraries thunk_data_offset library_file_n marked_bool_a module_offset_a marked_offset_a;
	= (Libraries library_list libraries,thunk_data_offset,marked_bool_a,module_offset_a,marked_offset_a);
	{
		compute_new_library_file_n EmptyLibraryList library_file_n
			= library_file_n;
		compute_new_library_file_n (Library _ _ _ _ library_list) library_file_n
			= compute_new_library_file_n library_list (library_file_n+1);
	}

Dcompute_imported_library_symbol_offsets :: !LibraryList !Int Int *{#Bool} !*{#Int} -> (!*{#Bool},!LibraryList,!Int,!*{#Int}); 
Dcompute_imported_library_symbol_offsets EmptyLibraryList thunk_data_offset0 symbol_n marked_bool_a module_offset_a0
	= (marked_bool_a,EmptyLibraryList,thunk_data_offset0,module_offset_a0);
Dcompute_imported_library_symbol_offsets (Library library_name base_of_client_dll library_symbols n_symbols library_list0) thunk_data_offset0 symbol_n marked_bool_a module_offset_a0
	#! (ok,library)
		= SetCurrentLibrary library_name
	|	not ok
		=	abort "Dcompute_imported_library_symbol_offsets: library doesn't exist"
		# (library,marked_bool_a, /* imported_symbols */ _,thunk_data_offset1,module_offset_a1)
			= compute_library_symbol_offsets library library_symbols symbol_n thunk_data_offset0 marked_bool_a module_offset_a0;
		| not (CloseLibrary library)
			= abort "Dcompute_imported_library_symbol_offsets: error"
			# (marked_bool_a,library_list1,thunk_data_offset2, module_offset_a2)
				= Dcompute_imported_library_symbol_offsets library_list0 thunk_data_offset1 (symbol_n+n_symbols) marked_bool_a module_offset_a1; 		
			# n_imported_symbols = (thunk_data_offset1-thunk_data_offset0) / 4;
			= (marked_bool_a, Library library_name base_of_client_dll library_symbols n_symbols/* imported_symbols n_imported_symbols*/ library_list1,thunk_data_offset2,module_offset_a2); {}
	{
		compute_library_symbol_offsets :: !*Int LibrarySymbolsList Int Int *{#Bool} *{#Int} -> (!*Int,*{#Bool},!LibrarySymbolsList, !Int,!*{#Int});
		compute_library_symbol_offsets library EmptyLibrarySymbolsList symbol_n thunk_data_offset0 marked_bool_a module_offset_a0
			= (library,marked_bool_a,EmptyLibrarySymbolsList, thunk_data_offset0 /*+4*/,module_offset_a0);
		compute_library_symbol_offsets library (LibrarySymbol symbol_name symbol_list) symbol_n thunk_data_offset0 marked_bool_a module_offset_a0
			| marked_bool_a.[symbol_n]
				#! (func_address,library1)
					= GetFuncAddress (Remove_at_size symbol_name) base_of_client_dll library;
				# ok
					= StoreLong symbol_name thunk_data_offset0 func_address;
				| not ok 
					= abort ("Dcompute_imported_library_symbol_offsets: can not store long");
					# (library2,marked_bool_a1,imported_symbols,thunk_data_offset1,module_offset_a1)
						= compute_library_symbol_offsets library1 symbol_list (symbol_n+2) (thunk_data_offset0+4) marked_bool_a
							{module_offset_a0 & [symbol_n]= func_address, [symbol_n+1]= thunk_data_offset0 };
					= (library2,marked_bool_a1,LibrarySymbol symbol_name imported_symbols,thunk_data_offset1,module_offset_a1);
				// unmarked symbol
				= compute_library_symbol_offsets library symbol_list (symbol_n+2) thunk_data_offset0 marked_bool_a module_offset_a0; 
	}
	
CloseLibrary :: !*Int -> Bool;
CloseLibrary _ = 	code { 
		ccall CloseLibrary "I-I"
	};
