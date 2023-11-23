implementation module LinkerOffsets;

import StdEnv;
import pdSymbolTable,link32or64bits;
	
:: *ModuleOffsets :== *{#Int};

compute_module_offsets :: SymbolIndexListKind Int [*Xcoff] Int Int *{#Bool} ModuleOffsets -> (*{#Bool},!Int,!ModuleOffsets,![*Xcoff]);
compute_module_offsets _ _ [] offset0 file_symbol_index marked_bool_a module_offsets0
	= (marked_bool_a, offset0,module_offsets0, []);
compute_module_offsets kind base [xcoff=:{n_symbols,symbol_table=symbol_table=:{text_symbols,data_symbols,bss_symbols,symbols}}:xcoff_list] offset0 file_symbol_index marked_bool_a module_offsets0
	# (marked_bool_a,offset1,symbols, module_offsets1)
		= compute_section_module_offsets base file_symbol_index marked_bool_a 
			(select_kind kind) symbols offset0 module_offsets0;			  
	  (marked_bool_a,offset,module_offsets, xcoff_list)
        = compute_module_offsets kind base xcoff_list offset1 (file_symbol_index+n_symbols) marked_bool_a module_offsets1;
	= (marked_bool_a,offset,module_offsets,[{xcoff & symbol_table={symbol_table & symbols=symbols}}:xcoff_list]);
{
	select_kind :: !SymbolIndexListKind -> SymbolIndexList;
	select_kind Text = text_symbols;
	select_kind Data = data_symbols;
	select_kind Bss  = bss_symbols;
};

compute_module_offsets_for_user_defined_sections :: {#Char} Int !*[*Xcoff] Int Int *{#Bool} *{#Int} -> *(.{#Bool},Int,*{#Int},[.Xcoff]);
compute_module_offsets_for_user_defined_sections _ _ [] offset0 file_symbol_index marked_bool_a module_offsets0
	= (marked_bool_a, offset0,module_offsets0, []);
compute_module_offsets_for_user_defined_sections kind base [xcoff=:{n_symbols,symbol_table=symbol_table=:{extra_sections,symbols}}:xcoff_list] offset0 file_symbol_index marked_bool_a module_offsets0	
	# (marked_bool_a,offset1,symbols, module_offsets1)
		= compute_section_module_offsets base file_symbol_index marked_bool_a 
			(select_kind kind) symbols offset0 module_offsets0;
	  (marked_bool_a,offset,module_offsets, xcoff_list)
        = compute_module_offsets_for_user_defined_sections kind base xcoff_list offset1 (file_symbol_index+n_symbols) marked_bool_a module_offsets1;
	= (marked_bool_a,offset,module_offsets,[{xcoff & symbol_table={symbol_table & symbols=symbols}}:xcoff_list]);
{
	select_kind :: !String -> SymbolIndexList;
	select_kind user_section_name
		#! extra_section
			= filter (\{es_name} -> user_section_name == es_name) extra_sections;
		| isEmpty extra_section
			= EmptySymbolIndex;
			=  (hd extra_section).es_symbols;
}

compute_section_module_offsets :: Int Int !*{#Bool} SymbolIndexList *SymbolArray Int ModuleOffsets -> (*{#Bool},!Int,!*SymbolArray,!ModuleOffsets);
compute_section_module_offsets _ file_symbol_index marked_bool_a EmptySymbolIndex symbol_array offset0 module_offsets0
	= (marked_bool_a,offset0,symbol_array,module_offsets0 );
compute_section_module_offsets base file_symbol_index marked_bool_a (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 module_offsets0
/*
	#! (s_marked_bool_a,marked_bool_a) = usize marked_bool_a;
	| file_symbol_index+module_n >= s_marked_bool_a
		= abort ("too big: " +++ toString (file_symbol_index+module_n) +++ " file_symbol_index:" +++ toString file_symbol_index +++ " module_n: " +++ toString module_n +++ "max size: " +++ toString s_marked_bool_a);
*/
	| not marked_bool_a.[file_symbol_index+module_n]
		= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_list symbol_array offset0 module_offsets0;
		
		# (offset1,module_offsets1)=compute_module_offset base module_symbol module_n offset0 file_symbol_index module_offsets0;
		= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_list symbol_array offset1 module_offsets1;

compute_module_offset :: Int Symbol Int Int Int ModuleOffsets -> (!Int,!ModuleOffsets);
compute_module_offset 0 (Module _ length _ _ _ _ characteristics) module_n offset0 file_symbol_index module_offsets0
	| characteristics bitand 0xc00000==0
		#	aligned_offset0=(offset0+3) bitand (-4);
		=	(aligned_offset0+length,{module_offsets0 & [file_symbol_index+module_n] = aligned_offset0});
		#	aligned_offset0=((offset0-1) bitor ((1<<(((characteristics bitand 0xf00000)>>20)-1))-1))+1;
		=	(aligned_offset0+length,{module_offsets0 & [file_symbol_index+module_n] = aligned_offset0});

compute_module_offset base (Module  _ length _ _ _ _ _) module_n offset0 file_symbol_index module_offsets0
	# (offset,module_offsets1) = module_offsets0![file_symbol_index+module_n];
	= (base,{module_offsets1 & [file_symbol_index+module_n] = base + offset});

compute_module_offset base EmptySymbol module_n offset0 file_symbol_index module_offsets0
	= abort "compute_module_offset base EmptySymbol";

compute_imported_library_symbol_offsets :: !LibraryList !Int !Int !Int !Int !*{#Bool} !*{#Int} -> (!*{#Bool},!LibraryList,!Int,!Int,!*{#Int});
compute_imported_library_symbol_offsets EmptyLibraryList text_offset0 thunk_data_offset0 n_libraries symbol_n marked_bool_a module_offset_a0
	= (marked_bool_a,EmptyLibraryList,text_offset0,thunk_data_offset0,module_offset_a0);
compute_imported_library_symbol_offsets (Library library_name _ library_symbols n_symbols library_list0) text_offset0 thunk_data_offset0 n_libraries symbol_n marked_bool_a module_offset_a0
	# (marked_bool_a,imported_symbols,text_offset1,thunk_data_offset1,module_offset_a1)
		= compute_library_symbol_offsets library_symbols symbol_n text_offset0 thunk_data_offset0 marked_bool_a module_offset_a0;

	#  (marked_bool_a,library_list1,text_offset2,thunk_data_offset2,module_offset_a2)
		= compute_imported_library_symbol_offsets library_list0 text_offset1 thunk_data_offset1 (inc n_libraries) (symbol_n+n_symbols) marked_bool_a module_offset_a1;
	  n_imported_symbols = (text_offset1-text_offset0) / 6;
	= (marked_bool_a,Library library_name 0 imported_symbols n_imported_symbols library_list1,text_offset2,thunk_data_offset2,module_offset_a2);
	{
		compute_library_symbol_offsets :: LibrarySymbolsList Int Int Int *{#Bool} *{#Int} -> (*{#Bool},!LibrarySymbolsList,!Int,!Int,!*{#Int});
		compute_library_symbol_offsets EmptyLibrarySymbolsList symbol_n text_offset0 thunk_data_offset0 marked_bool_a module_offset_a0
			# thunk_data_offset0 = thunk_data_offset0+(Link32or64bits 4 8);
			= (marked_bool_a,EmptyLibrarySymbolsList,text_offset0,thunk_data_offset0,module_offset_a0);
		compute_library_symbol_offsets (LibrarySymbol symbol_name symbol_list) symbol_n text_offset0 thunk_data_offset0 marked_bool_a module_offset_a0
			| marked_bool_a.[symbol_n]
				# thunk_data_offset1 = thunk_data_offset0+(Link32or64bits 4 8);
				# (marked_bool_a1,imported_symbols,text_offset1,thunk_data_offset1,module_offset_a1)
						= compute_library_symbol_offsets symbol_list (symbol_n+2) (text_offset0+6) thunk_data_offset1 marked_bool_a 
							{module_offset_a0 & [symbol_n]=text_offset0
							,[symbol_n+1]=thunk_data_offset0 };
				= (marked_bool_a1,LibrarySymbol symbol_name imported_symbols,text_offset1,thunk_data_offset1,module_offset_a1);
				= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset0 thunk_data_offset0 marked_bool_a module_offset_a0;
	}