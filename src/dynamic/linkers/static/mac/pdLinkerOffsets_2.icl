implementation module pdLinkerOffsets;

import StdEnv;
import SymbolTable;
import State;
import LinkerOffsets;

from ExtInt import roundup_to_multiple;

:: *ModuleOffsets :== *{#Int};

:: Offset = {
		// .text section
		library_offset		:: Int				// pef_text_section_size0
	,	end_text_offset		:: Int 				// pef_text_section_size1
		
		// .data section
	,	end_toc_offset		:: Int				// pef_toc_section_size0
	,	end_data_offset 	:: Int				// pef_data_section_size0
	,   begin_bss_offset	:: Int				// pef_data_section_size1
	,	end_bss_offset		:: Int				// pef_bss_section_end0
	,	end_bss_offset_a	:: Int				// pef_bss_section_end1
	};

DefaultOffset :: !Offset;
DefaultOffset
	= { Offset |
		// .text section
		library_offset		= 0				// pef_text_section_size0
	,	end_text_offset		= 0 			// pef_text_section_size1
		
		// .data section
	,	end_toc_offset		= 0				// pef_toc_section_size0
	,	end_data_offset		= 0				// pef_data_section_size0
	,   begin_bss_offset	= 0				// pef_data_section_size1
	,	end_bss_offset		= 0				// pef_bss_section_end0
	,	end_bss_offset_a	= 0				// pef_bss_section_end1
	};

ComputeOffsets :: [.(.Int -> .(.Offset -> .(*State -> *(Offset,*State))))];	
ComputeOffsets
	 = [compute_text_section_offsets,compute_data_section_offsets];


/*
	on xcoff:
	
	
	[ 
		initial value is end_toc_offset
		marked, selacc_data_symbols
		end value is 
		
	

*/
// compute .data section
compute_data_section_offsets :: !Int !Offset !*State -> (!Offset,!*State);
compute_data_section_offsets base offset=:{end_toc_offset} state
	// compute initialized data section
	#! (offset=:{end_data_offset},state)
		= compute_module_offsets2 compute_data_section_offsets_per_xcoff 0 base {offset & end_data_offset = end_toc_offset} 0 state;
	
	#! begin_bss_offset
		= roundup_to_multiple end_data_offset 4;
	#! offset
		= { offset &
			begin_bss_offset = begin_bss_offset
		,	end_bss_offset = begin_bss_offset
		};
		
	// compute uninitialized data section
	#! (offset=:{end_bss_offset},state)
		= compute_module_offsets2 compute_bss_section_offsets_per_xcoff 0 base offset 0 state;
	#! offset
		= { offset &
			end_bss_offset_a = roundup_to_multiple end_bss_offset 4
		};
	= (offset,state);

where {
	compute_data_section_offsets_per_xcoff :: !Int !Int !Int !Offset !*State -> *(!Offset,*State);
	compute_data_section_offsets_per_xcoff base file_n file_symbol_index offset=:{end_data_offset=data_offset} state
		// select text symbols
		#! (data_symbols,state)
			= selacc_data_symbols file_n state;
		#! (data_offset,state)
			// compute_unmarked_section_module_offsets2
			// compute_section_module_offsets2
			= compute_unmarked_section_module_offsets2 base file_n file_symbol_index data_symbols data_offset state;
		= ({offset & end_data_offset = data_offset},state);

	compute_bss_section_offsets_per_xcoff :: !Int !Int !Int !Offset !*State -> *(!Offset,*State);
	compute_bss_section_offsets_per_xcoff base file_n file_symbol_index offset=:{end_bss_offset=bss_offset} state
		// select text symbols
		#! (bss_symbols,state)
			= selacc_bss_symbols file_n state;
		#! (bss_offset,state)
			= compute_section_module_offsets2 base file_n file_symbol_index bss_symbols bss_offset state;
		= ({offset & end_bss_offset = bss_offset},state);
}
	
// compute .text section
compute_text_section_offsets :: !Int !Offset !*State -> (!Offset,!*State);
compute_text_section_offsets base offset state=:{library_list} 		
	#! (offset=:{library_offset},state)
		= compute_module_offsets2 compute_text_section_offsets_per_xcoff 0 base offset 0 state;
		
	#! (marked_bool_a,state)
		= select_marked_bool_a state;
	#! (module_offset_a,state)
		= select_module_offset_a state;
		
	#! (library_list,pef_text_section_size1,module_offset_a,marked_bool_a)
		= compute_imported_library_symbol_offsets /*state.*/library_list library_offset state.n_xcoff_symbols marked_bool_a module_offset_a;
	
	// update various states
	#! offset
		= { offset &
			end_text_offset	= pef_text_section_size1
		};
		
	#! state
		= { state &
			marked_bool_a	= marked_bool_a
		,	module_offset_a	= module_offset_a
		,	library_list	= library_list
		};	
	= (offset,state);
where {
	compute_text_section_offsets_per_xcoff :: !Int !Int !Int !Offset !*State -> *(!Offset,*State);
	compute_text_section_offsets_per_xcoff base file_n file_symbol_index offset=:{library_offset=text_offset,end_toc_offset=toc_offset} state
		// select text symbols
		#! (text_symbols,state)
			= selacc_text_symbols file_n state;
		#! (text_offset,state)
			= compute_section_module_offsets2 base file_n file_symbol_index text_symbols text_offset state;
	
		// select toc symbols
		#! (toc_symbols,state)
			= selacc_toc_symbols file_n state;
		#! (toc_offset,state)
			// = compute_section_module_offsets2 base file_n file_symbol_index toc_symbols toc_offset state;
			= compute_unmarked_section_module_offsets2 base file_n file_symbol_index toc_symbols toc_offset state;
	
		// select toc0 symbols
		#! (toc0_symbol,state)
			= selacc_toc0_symbols file_n state;
		#! state 
			= app_module_offset_a (compute_toc0_module_offset file_symbol_index toc0_symbol) state;
		= ({ offset & library_offset = text_offset, end_toc_offset = toc_offset},state);
}

compute_module_offset :: !Int !Symbol !Int !Int !Int !*{#Int} -> (!Int,!*{#Int});
compute_module_offset 0 (Module {length,align=alignment}) module_n offset0 file_symbol_index module_offsets0
	= (aligned_offset0+length,{module_offsets0 & [file_symbol_index+module_n] = aligned_offset0});
	{
		aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
		alignment_mask=dec (1<<alignment);
	}
compute_module_offset base (Module _) module_n _ file_symbol_index module_offsets
	#! (offset,module_offset)
		= module_offsets![file_symbol_index + module_n];
	= (base,{module_offset & [file_symbol_index + module_n] = base + offset});
		
compute_module_offset _ (AliasModule _) module_n offset0 file_symbol_index module_offsets0
	= (offset0,module_offsets0);
compute_module_offset _ (ImportedFunctionDescriptorTocModule _) module_n offset0 file_symbol_index module_offsets0
	= (offset0,module_offsets0);
	
// libraries
compute_imported_library_symbol_offsets :: LibraryList Int Int !*{#Bool} *{#Int} -> (!LibraryList,!Int,!*{#Int},!*{#Bool});
compute_imported_library_symbol_offsets library_list text_offset symbol_n marked_bool_a module_offset_a
	# (library_list,text_offset,_,module_offset_a,marked_bool_a)
		= compute_imported_library_symbol_offsets_lp library_list text_offset 0 symbol_n module_offset_a marked_bool_a;
		with {
			compute_imported_library_symbol_offsets_lp :: LibraryList Int Int Int *{#Int} !*{#Bool} -> (!LibraryList,!Int,!Int,!*{#Int},!*{#Bool});
			compute_imported_library_symbol_offsets_lp EmptyLibraryList text_offset toc_offset symbol_n module_offset_a marked_bool_a
				=	(EmptyLibraryList,text_offset,toc_offset,module_offset_a,marked_bool_a);

			compute_imported_library_symbol_offsets_lp (Library library_name library_symbols n_symbols library_list) text_offset0 toc_offset symbol_n module_offset_a marked_bool_a
			#	(imported_symbols,text_offset1,toc_offset,module_offset_a,marked_bool_a)
					= compute_library_symbol_offsets library_symbols symbol_n text_offset0 toc_offset module_offset_a marked_bool_a;
						with {
							compute_library_symbol_offsets :: LibrarySymbolsList Int Int Int *{#Int} !*{#Bool} -> (!LibrarySymbolsList,!Int,!Int,!*{#Int},!*{#Bool});
							compute_library_symbol_offsets EmptyLibrarySymbolsList symbol_n text_offset toc_offset module_offset_a marked_bool_a
								= (EmptyLibrarySymbolsList,text_offset,toc_offset,module_offset_a,marked_bool_a);
							compute_library_symbol_offsets (LibrarySymbol symbol_name symbol_list) symbol_n text_offset toc_offset module_offset_a marked_bool_a
								| marked_bool_a.[symbol_n]
									# (imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a)
										= compute_library_symbol_offsets symbol_list (symbol_n+2) (text_offset+24) (toc_offset+4)
											{module_offset_a & [symbol_n]=text_offset,[symbol_n+1]=toc_offset} marked_bool_a;
									= (LibrarySymbol symbol_name imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a);
									= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
						}
			#
				(library_list,text_offset,toc_offset,module_offset_a, marked_bool_a)
					= compute_imported_library_symbol_offsets_lp library_list text_offset1 toc_offset (symbol_n+n_symbols) module_offset_a marked_bool_a;
				n_imported_symbols2 = (text_offset1-text_offset0) / 12;
			=	(Library library_name imported_symbols n_imported_symbols2 library_list,text_offset,toc_offset,module_offset_a,marked_bool_a);
		}
	= (library_list,text_offset,module_offset_a,marked_bool_a);
	
// on SymbolIndexLists  
compute_toc0_module_offset file_symbol_index EmptySymbolIndex module_offsets
	=	module_offsets;
compute_toc0_module_offset file_symbol_index (SymbolIndex module_n EmptySymbolIndex) module_offsets
	=	{module_offsets & [file_symbol_index+module_n] = 32768};

