implementation module LinkerOffsets;

import StdEnv;
import SymbolTable;
import State;

from ExtInt import roundup_to_multiple;

import pdLinkerOffsets;

import DebugUtilities;

:: Counter 
	= SetInitialCounterTo !Int
	| Continue
	| GetCounterFrom !Int
	;
	
:: Section = {
		subsections		:: [SubSection]
	};

:: SubSection = {
	selacc_symbols  :: [SelAccSymbol],
	alignment		:: !Int

	// voor functions die toch een sub section produceren maar niet m.b.v. SymbolIndexList 's		
	,	how_sub_section_is_computed	:: HowSubSectionIsComputed
	};
	
:: HowSubSectionIsComputed
	= LoopingOnSymbolIndexList
	| ComputesSubSection !Int (!Int !*State -> !(!Int,!*State))
	;
	
:: SelAccSymbol = {
		selacc_symbol		:: (!Int !*State -> !(!SymbolIndexList,!*State))
	,	initial_offset		:: !Counter
	,	marked_computation	:: !Bool
	,	custom_index_loop 	:: CustomIndexLoop
	};
	
:: CustomIndexLoop 
	= CustomIndexLoopFunc (!Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State))
	| NoCustomIndexLoop
	;
	
DefaultSelAccSymbol :: !SelAccSymbol;
DefaultSelAccSymbol 
	= { SelAccSymbol |
		selacc_symbol		= undef
	,	initial_offset		= SetInitialCounterTo 0
	
	// a custom_index_loop loops on all symbols, regardless of marked_computation
	,	marked_computation	= True
	,	custom_index_loop	= NoCustomIndexLoop
	};

DefaultSection :: Section;	
DefaultSection 
	= { Section |
		subsections = []
	};
	
DefaultSubSection :: SubSection;
DefaultSubSection
	= { SubSection |
		selacc_symbols = []
	,	alignment = 4
	,	how_sub_section_is_computed	= LoopingOnSymbolIndexList
	};
	
:: SubSectionOffset = {
		counter			:: !Int,
		end				:: !Int,
		aligned_end		:: !Int
	};
	
DefaultSubSectionOffset :: SubSectionOffset;
DefaultSubSectionOffset
	= { SubSectionOffset |
		counter			= 100,
		end				= 0,
		aligned_end		= 0				// only set in case of SubSectionOffset
	};
	
	
// slordig; ik ga ervan uit dat er niet meer als 11 symbols + custom loop functies zijn
section_offsets
	= { DefaultSubSectionOffset \\ i <- [0..10] };
	
/*
Voor gewone statische link moet marked_toc_computation gelijk aan False zijn
*/
	
// Specification
sections_specification :: !Bool !Int -> [.Section];
sections_specification marked_toc_computation n_imported_symbols
	// two sections: a .text and .data section
	= [ text_section, data_section ];
where {
	text_section 
		= { DefaultSection &
			subsections	 = [text_sub_section, library_sub_section]
		};
	where {
		text_sub_section 
			= { DefaultSubSection &
				selacc_symbols = [text_symbols, toc_symbols, toc0_symbols]
			};
		where {
			// id = 0; loop on .text symbols from address 0
			text_symbols 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_text_symbols
				,	initial_offset		= SetInitialCounterTo 0
				};
				
			toc_symbols
			// id = 1; loop on .toc symbols. The first n_imported_symbols (from shared objects) are reserved.
			// The rest of internally defined toc-symbols are allocated. 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_toc_symbols
				,	initial_offset		= SetInitialCounterTo (n_imported_symbols << 2)
				, 	marked_computation	= marked_toc_computation
//				,	marked_computation	= False
				};
				
			// id = 2; TOC-anchor (only one symbol in a data section)
			toc0_symbols
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_toc0_symbols
				,	initial_offset		= SetInitialCounterTo 32768
				,	custom_index_loop	= CustomIndexLoopFunc compute_toc0_module_offset2
				};

		}
		
		library_sub_section
			= { DefaultSubSection &
				how_sub_section_is_computed = ComputesSubSection 0 compute_imported_library_symbol_offsets2
			};
	};

	data_section
		= { DefaultSection &
			subsections  = [data_sub_section,bss_sub_section]
		};
	where {
		data_sub_section
			= { DefaultSubSection &
				selacc_symbols = [data_symbols]
			};
		where {
			data_symbols 
				// initial offset = end of toc table
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_data_symbols
				,	initial_offset		= GetCounterFrom 1  //SetInitialCounterTo 0
				, 	marked_computation	= marked_toc_computation

//				, 	marked_computation	= False
				};
		}
		
		bss_sub_section
			= { DefaultSubSection &
				selacc_symbols = [bss_symbols]
			};
		where {
			bss_symbols
				// initial offset = end of .data symbols
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_bss_symbols
				,	initial_offset		= Continue
				};
		}
	};
}

// Increment Specification
sections_inc_specification :: !Int !Int -> [.Section];
sections_inc_specification text_begin data_begin
	// two sections: a .text and .data section
	= [ text_section, data_section ];
where {
	text_section 
		= { DefaultSection &
			subsections	 = [text_sub_section, library_sub_section]
		};
	where {
		text_sub_section 
			= { DefaultSubSection &
				selacc_symbols = [text_symbols/*,toc_symbols*/]
			};
		where {
			text_symbols 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_text_symbols
				,	initial_offset		= SetInitialCounterTo text_begin
				, 	custom_index_loop	= CustomIndexLoopFunc increment_bss_offset
				};
		}

		library_sub_section
			= { DefaultSubSection &
				how_sub_section_is_computed = ComputesSubSection 0 increment_imported_library_symbol_offsets2
			};
	};

	data_section
		= { DefaultSection &
			subsections  = [data_sub_section,bss_sub_section]
		};
	where {
		data_sub_section
			= { DefaultSubSection &
				selacc_symbols = [data_symbols]
			,	alignment	   = 0
			};
		where {
			data_symbols 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_data_symbols
				,	initial_offset		= SetInitialCounterTo data_begin
//				, 	marked_computation	= False
				,	custom_index_loop	= CustomIndexLoopFunc increment_bss_offset
				};
		}
		
		bss_sub_section
			= { DefaultSubSection &
				selacc_symbols = [bss_symbols]
			,	alignment		= 0 			// no changes to counter
			};
		where {
			bss_symbols
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_bss_symbols
				,	initial_offset		= SetInitialCounterTo data_begin
				,	custom_index_loop	= CustomIndexLoopFunc increment_bss_offset
				};
		}
	};
}

/* 
	layout:
	
	eerst text, dan toc en tenslotte de data symbols
*/
raw_data_specification :: [.Section];
raw_data_specification 
	// two sections: a .text and .data section
	= [ text_section ];
where {
	text_section 
		= { DefaultSection &
			subsections	 = [text_sub_section]
		};
	where {
		text_sub_section 
			= { DefaultSubSection &
				selacc_symbols = [text_symbols, data_symbols, toc_symbols]
			};
		where {
			// 0
			text_symbols 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_text_symbols
				,	initial_offset		= SetInitialCounterTo 0
				};
				
			// 1
			data_symbols 
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_data_symbols
				,	initial_offset		= SetInitialCounterTo 0
				};	

			// 2
			toc_symbols
				= { DefaultSelAccSymbol &
					selacc_symbol		= selacc_toc_symbols
				,	initial_offset		= SetInitialCounterTo 0
				};
		}

	};
}

// ---------------------------------------------------------------------------------------------------------------------------------------------------------
//ComputeOffsets :: !*State [.Section] -> (!Offset,!*State);
ComputeOffsets :: *State [.Section] -> *(.{SubSectionOffset},*State);
ComputeOffsets state=:{n_xcoff_files} sections
	#! (i,section_offsets,state=:{n_libraries})
		= foldl per_section (0,section_offsets,state) sections;
	= (section_offsets,state);

compute_offsets2 :: !Int !*State [.Section] -> (!Offset,!*State);
compute_offsets2 base state=:{n_xcoff_files} sections
	#! (i,section_offsets,state=:{n_libraries})
		= foldl per_section (0,section_offsets,state) sections;
	
	#! offset
		= { Offset |
		// .text section
			library_offset		= section_offsets.[0].counter
		,	end_text_offset		= section_offsets.[3].counter
		
		// .data section
		,	end_toc_offset		= section_offsets.[1].counter
		,	end_data_offset		= section_offsets.[4].counter
		,	begin_bss_offset	= section_offsets.[4].aligned_end
		,	end_bss_offset		= section_offsets.[5].counter
		,	end_bss_offset_a	= section_offsets.[5].aligned_end
	};
	= (offset,state);	
	
			

	per_section (ith_subsection,section_offsets,state) section=:{subsections}
		// code to be inserted per loop of the xcoffs
		#! (ith_subsection,section_offsets,state)
			= foldl per_xcoff_files (ith_subsection,section_offsets,state) subsections
		= (ith_subsection,section_offsets,state); 
	where {
	
		per_xcoff_files (ith_subsection,section_offsets,state=:{n_xcoff_files}) subsection=:{selacc_symbols,alignment,how_sub_section_is_computed}
		
			#! (j,section_offsets,state)
				= case how_sub_section_is_computed of {
					LoopingOnSymbolIndexList
						// set initial counters
						#! (j,section_offsets)
							= foldl compute_initial_offsets (ith_subsection,section_offsets) selacc_symbols;
							
						#! (_,_,section_offsets,state)
							= foldl per_xcoff (0,ith_subsection,section_offsets,state) [0..dec n_xcoff_files];
						-> (j,section_offsets,state);
						
					ComputesSubSection index w
						// sluit altijd direct aan op de sectie index
						#! ({counter},section_offsets)
							= section_offsets![index];
						#! (offset,state)
							= w counter state;
					
						#! section_offsets
							= { section_offsets & [ith_subsection] = {DefaultSubSectionOffset & counter = offset} };
						-> (inc ith_subsection,section_offsets,state);
				};
				
				
			// alignment geldt alleen op het niveau van subsections niet op symbol index lists
			#! (section_offset=:{counter},section_offsets)
				= section_offsets![ith_subsection];
			
			// set counter and aligned counter as end of subsection
			#! aligned_section_end
				= roundup_to_multiple counter alignment;
			#! section_offsets
				= { section_offsets & [ith_subsection] = {section_offset & end = counter, aligned_end = aligned_section_end}};
			= (j,   section_offsets,state);
		where {
			
			compute_initial_offsets (i,section_offsets) {initial_offset=initial}
				// set counter using initial counter
				#! (counter,section_offsets)
					= case initial of {
						GetCounterFrom index
							// get previously set counter
							#! ({counter},section_offsets)
								= section_offsets![index];
							-> (counter,section_offsets);
						SetInitialCounterTo initial_value
							// set counter to initial value
							-> (initial_value,section_offsets);
						Continue
							// continue with the aligned end of the previous subsection as the new counter
							#! ({aligned_end},section_offsets)
								= section_offsets![dec ith_subsection];
							-> (aligned_end,section_offsets)
					};
				#! section_offsets
					= { section_offsets & [i] = {DefaultSubSectionOffset & counter = counter} };
				= (inc i,section_offsets);

			per_xcoff (file_symbol_index,ith_subsection,section_offsets,state) file_n
				// code to be inserted per xcoff; .text
				#! (/*Added ith_subsection*/ _,section_offsets,state)
					= foldl per_symbol_index_list (ith_subsection,section_offsets,state) selacc_symbols;
				
				#! (n_symbols,state)
					= selacc_n_symbols file_n state;
				= (file_symbol_index + n_symbols,ith_subsection,section_offsets,state);	
					
				where {
					// per symbol index list
					per_symbol_index_list (ith_subsection,section_offsets,state) {selacc_symbol=sel_symbols,marked_computation,custom_index_loop} // ADDED:sel_symbols
						// select symbols
						#! (syms,state)
							= sel_symbols file_n state;
						// get counter
						#! (section_offset=:{counter /*,marked_computation*/},section_offsets)
							= section_offsets![ith_subsection];							
							
						#! (section_offsets,state)
							= case custom_index_loop of {
								NoCustomIndexLoop
									#! (counter,state)
										= case marked_computation  of {
											True
												-> compute_section_module_offsets2 0 file_n file_symbol_index syms counter state;
											False
												-> compute_unmarked_section_module_offsets2  0 file_n file_symbol_index syms counter state;
										};
				
									// update counter
									#! section_offsets
										= { section_offsets & [ith_subsection] = {section_offset & counter = counter}  
										
										};
									-> (section_offsets,state);
									
								CustomIndexLoopFunc f
									#! (counter,state)
										= f 0 file_n file_symbol_index syms counter state;

/*
									// ADDED; update counter
									#! section_offsets
										= { section_offsets & [ith_subsection] = {section_offset & counter = counter}  
										
										};
*/
										
									-> (section_offsets,state);
							};
										
						= (/* ADDED */ inc ith_subsection,section_offsets,state);
				}
		
		} // per_xcoff_files
	} // per section

//} // compute_offsets2

compute_toc0_module_offset2 :: !Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State);
compute_toc0_module_offset2 _ file_n file_symbol_index EmptySymbolIndex offset0 state 
	= (offset0,state);
compute_toc0_module_offset2 _ file_n file_symbol_index (SymbolIndex module_n symbol_list) offset0 state
	#! state 
		= app_module_offset_a (\module_offset_a -> {module_offset_a & [file_symbol_index + module_n] = 32768}) state;
	= compute_toc0_module_offset2 0 /* base */ file_n file_symbol_index symbol_list offset0 state;

increment_offset :: !Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State);
increment_offset _ file_n file_symbol_index EmptySymbolIndex base state 
	= (base,state);

increment_offset _ file_n file_symbol_index (SymbolIndex module_n symbol_list) base state
	// ADDED

	
/*
	#! (marked_symbol,state)
		= selacc_marked_bool_a i state;
	| not marked_symbol
		= (base,state);
*/
	#! (module_symbol,state) 
		= sel_symbol file_n module_n state;
	#! state
		= case module_symbol of {/* CHANGED */
			Module _
				-> app_module_offset_a 
				(\module_offset_a=:{[i] = offset} -> {module_offset_a & [i] = base + offset}) state;
			_
				-> state;
		};
	= increment_offset 0  file_n file_symbol_index symbol_list base state;
where {
	i = file_symbol_index +  module_n;

//(\module_offset_a=:{[file_symbol_index +  module_n] = offset} -> {module_offset_a & [file_symbol_index + module_n] = base + offset})

}

// compute_section_module_offsets2 base file_n file_symbol_index (SymbolIndex module_n symbol_list) offset0 state=:{marked_bool_a}  

	
increment_bss_offset :: !Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State);
increment_bss_offset _ file_n file_symbol_index symbol_list base state 
	= compute_section_module_offsets2 base file_n file_symbol_index symbol_list 0 state;
	
/*
increment_bss_offset _ file_n file_symbol_index (SymbolIndex module_n symbol_list) base state
/*
	#! (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	#! (marked_symbol,state)
		= selacc_marked_bool_a (first_symbol_n + file_n) state;
	| not marked_symbol
		= (base,state);
*/
		

	// ADDED
// test
	#! (marked_symbol,state)
		= selacc_marked_bool_a i state;
	| not marked_symbol
		= (base,state);

	#! (module_symbol,state) 
		= sel_symbol file_n module_n state;
	#! state
		= case module_symbol of {/* CHANGED */
			Module _
				-> app_module_offset_a 
				(\module_offset_a=:{[i] = offset} -> {module_offset_a & [i] = base + offset}) state;
			_
				-> state;
		};
	= increment_bss_offset 0  file_n file_symbol_index symbol_list base state;
where {
	i = file_symbol_index +  module_n;

//(\module_offset_a=:{[file_symbol_index +  module_n] = offset} -> {module_offset_a & [file_symbol_index + module_n] = base + offset})

}
*/
	
compute_imported_library_symbol_offsets2 :: !Int !*State -> !(!Int,!*State);
compute_imported_library_symbol_offsets2 offset state=:{library_list,n_xcoff_symbols}
	#! (marked_bool_a,state)
		= select_marked_bool_a state;
	#! (module_offset_a,state)
		= select_module_offset_a state;
	#! (library_list,offset,module_offset_a,marked_bool_a)
		= compute_imported_library_symbol_offsets library_list offset n_xcoff_symbols marked_bool_a module_offset_a;
	
	#! state 
		= { state &
			library_list	= library_list
		,	module_offset_a	= module_offset_a
		,	marked_bool_a	= marked_bool_a
		};
	= (offset,state);
	
import ExtInt;


// Needed for the Increment specs
increment_imported_library_symbol_offsets2 :: !Int !*State -> !(!Int,!*State);
increment_imported_library_symbol_offsets2 offset state=:{library_list,n_xcoff_symbols}
	#! (marked_bool_a,state)
		= select_marked_bool_a state;
	#! (module_offset_a,state)
		= select_module_offset_a state;
	#! (/*library_list*/_,_,module_offset_a,marked_bool_a)
		= increment_imported_library_symbol_offsets offset library_list offset n_xcoff_symbols marked_bool_a module_offset_a;
	
	#! state 
		= { state &
			library_list	= library_list
		,	module_offset_a	= module_offset_a
		,	marked_bool_a	= marked_bool_a
		};
	= (offset,state);
	

// ---------------------------------------------------------------------------------------------------------------------------------------------------------


instance toString Offset
where {
	toString {library_offset
	,	end_text_offset,end_toc_offset,	end_data_offset,   begin_bss_offset,	end_bss_offset,	end_bss_offset_a}
	
		#! s 
			= "\nlibrary_offset: 	" +++ toString library_offset +++
			  "\nend_text_offset:	" +++ toString end_text_offset +++
			  "\nend_toc_offset:	" +++ toString end_toc_offset +++
			  "\nend_data_offset:	" +++ toString end_data_offset +++
			  "\nbegin_bss_offset:	" +++ toString begin_bss_offset +++
			  "\nend_bss_offset:	" +++ toString end_bss_offset +++
			  "\nend_bss_offset_a:	" +++ toString end_bss_offset_a;
		= abort s;

};


:: Offset = {
		// .text section
		library_offset		:: Int				// pef_text_section_size0
	,	end_text_offset		:: Int 			// pef_text_section_size1
		
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
compute_text_section_offsets base offset=:{end_toc_offset=begin_toc} state=:{library_list} 		
	#! (offset=:{library_offset},state)
		= compute_module_offsets2 compute_text_section_offsets_per_xcoff 0 base offset 0 state;
		
	#! (marked_bool_a,state)
		= select_marked_bool_a state;
	#! (module_offset_a,state)
		= select_module_offset_a state;
		
	#! (library_list,pef_text_section_size1,module_offset_a,marked_bool_a)
		= compute_imported_library_symbol_offsets /*state.*/library_list library_offset state.n_xcoff_symbols marked_bool_a module_offset_a;
	
	// update various states
//	| True
//		= abort ("! " +++ toString library_offset);
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

/*
compute_offsets2 :: !Int !*State !Offset -> (!Offset,!*State);
compute_offsets2 base state offset
	#! (offset,state)
		= foldl (\(offset,state) compute_section_offsets -> compute_section_offsets base offset state) (offset,state) 
				[compute_text_section_offsets,compute_data_section_offsets];
			
	#! {library_offset,end_text_offset,end_toc_offset,end_data_offset, begin_bss_offset,end_bss_offset,end_bss_offset_a}
		= offset;
	= (offset,state);
*/
		
compute_module_offsets2 :: (!a -> !.(Int -> !.(Int -> .(!.b -> .(!*State -> *(!.b,!*State)))))) !Int !a !.b !Int !*State -> *(!.b,!*State);
compute_module_offsets2 compute_section_offsets_per_xcoff file_n base /*[xcoff=:{n_symbols,symbol_table}:xcoff_list]*/ offset file_symbol_index state=:{n_xcoff_files}
	| file_n == n_xcoff_files
		= (offset,state);


		// body; per xcoff 		
		#! (offset,state)
			= compute_section_offsets_per_xcoff base file_n file_symbol_index offset state;
		
		#! (n_symbols,state)
			= selacc_n_symbols file_n state;
		= compute_module_offsets2 compute_section_offsets_per_xcoff (inc file_n) base offset (file_symbol_index+n_symbols) state;
	
// marked symbols; on SymbolIndexList
compute_section_module_offsets2 :: !Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State);
compute_section_module_offsets2 _ file_n file_symbol_index EmptySymbolIndex offset0 state 
	= (offset0,state);
compute_section_module_offsets2 base file_n file_symbol_index (SymbolIndex module_n symbol_list) offset0 state=:{marked_bool_a}  

	| not marked_bool_a.[file_symbol_index+module_n]
		// unmarked symbols
		= compute_section_module_offsets2 base file_n file_symbol_index symbol_list offset0 state;
 		
 //		| file_n == 0 && module_n == 292
//		= abort (":knal" +++ hex_int offset0);

		# (module_symbol, state)
			= sel_symbol file_n module_n state;
		# (offset1,state)
			= compute_module_offset2 base module_symbol module_n offset0 file_symbol_index state;
		= compute_section_module_offsets2 base file_n file_symbol_index  symbol_list  offset1 state;

compute_unmarked_section_module_offsets2 :: !Int !Int !Int !SymbolIndexList  !Int !*State -> (!Int,!*State);
compute_unmarked_section_module_offsets2 _ file_n file_symbol_index EmptySymbolIndex offset0 state 
	= (offset0,state);
compute_unmarked_section_module_offsets2 base file_n file_symbol_index (SymbolIndex module_n symbol_list) offset0 state  
	| file_n == 0 && module_n == 192
		= abort "!I!JK#WJJKEJKJ";
	# (module_symbol, state)
		= sel_symbol file_n module_n state;
	# (offset1,state)
		= compute_module_offset2 base module_symbol module_n offset0 file_symbol_index state;
		= compute_unmarked_section_module_offsets2 base file_n file_symbol_index  symbol_list offset1 state;

compute_module_offset2 :: !Int !Symbol !Int !Int !Int !*State -> (!Int,!*State);
compute_module_offset2 0 (Module {length,align=alignment}) module_n offset0 file_symbol_index state=:{module_offset_a}
	#! module_offset_a
		= {module_offset_a & [file_symbol_index+module_n] = aligned_offset0};
	= (aligned_offset0+length,{state & module_offset_a = module_offset_a});
	{
		aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
		alignment_mask=dec (1<<alignment);
	}
	
compute_module_offset2 base (Module _) module_n _ file_symbol_index state=:{module_offset_a}
	#! (offset,module_offset)
		= module_offset_a![file_symbol_index + module_n];
	#! module_offset_a
		= {module_offset & [file_symbol_index + module_n] = base + offset};
	= (base,{state & module_offset_a = module_offset_a});
		
compute_module_offset2 _ (AliasModule _) module_n offset0 file_symbol_index state
	= (offset0,state);
compute_module_offset2 _ (ImportedFunctionDescriptorTocModule _) module_n offset0 file_symbol_index state
	= (offset0,state);



//--------------------------------------------------------
// -------------
// zou eigenlijk nog wat aan gedaan moeten worden; misschien abstractie van het platform

compute_offsets :: !Int !Int !Int !LibraryList ![*Xcoff] !*{#Bool} -> (!Int,!Int,!Int,!Int,!Int,!LibraryList,!*{#Int},![*Xcoff],!*{#Bool});
compute_offsets n_xcoff_symbols n_library_symbols n_imported_symbols library_list0 xcoff_list4 marked_bool_a
	# base = 0;

	# (pef_text_section_size0,pef_toc_section_size0,module_offset_a0,xcoff_list4,marked_bool_a)
		= compute_module_offsets (n_xcoff_symbols+n_library_symbols) xcoff_list4 (n_imported_symbols<<2) marked_bool_a;

//	| True
//		= abort ("**" +++ toString pef_toc_section_size0);

	# (pef_data_section_size0,module_offset_a1,xcoff_list4)
		= compute_data_module_offsets base xcoff_list4 pef_toc_section_size0 0 module_offset_a0;


	# pef_data_section_size1 
		= (pef_data_section_size0+3) bitand (-4);

	# (pef_bss_section_end0,module_offset_a2,xcoff_list4,marked_bool_a)
		= compute_bss_module_offsets base xcoff_list4 pef_data_section_size1 0 marked_bool_a module_offset_a1;
		
	# (library_list1,pef_text_section_size1,module_offset_a3,marked_bool_a)
		= compute_imported_library_symbol_offsets library_list0 pef_text_section_size0 n_xcoff_symbols marked_bool_a module_offset_a2;
	= (pef_text_section_size0,pef_text_section_size1,pef_data_section_size0,pef_data_section_size1,pef_bss_section_end0,library_list1,module_offset_a3,xcoff_list4,marked_bool_a);

//:: *ModuleOffsets :== *{#Int};


// on Xcoff
compute_module_offsets :: Int [*Xcoff] Int *{#Bool} -> (!Int,!Int,!ModuleOffsets,![*Xcoff],*{#Bool});
compute_module_offsets n_symbols xcoff_list toc_offset0 marked_bool_a
	= compute_files_module_offsets xcoff_list 0 toc_offset0 0 (createArray n_symbols 0) marked_bool_a;
	{
		compute_files_module_offsets :: ![*Xcoff] Int Int Int ModuleOffsets *{#Bool} -> (!Int,!Int,!ModuleOffsets,![*Xcoff],*{#Bool});
		compute_files_module_offsets [] text_offset0 toc_offset0 file_symbol_index module_offsets0 marked_bool_a
			= (text_offset0,toc_offset0,module_offsets0,[],marked_bool_a);
			
		compute_files_module_offsets [xcoff=:{n_symbols,symbol_table}:xcoff_list] text_offset0 toc_offset0 file_symbol_index module_offsets0 marked_bool_a
			#! (text_offsetN,toc_offsetN,module_offsetsN,xcoff_listN,marked_bool_aN)
				= compute_files_module_offsets xcoff_list text_offset1 toc_offset1 (file_symbol_index+n_symbols) module_offsets3 marked_bool_a1;
			= (text_offsetN,toc_offsetN,module_offsetsN,[{xcoff & symbol_table = {symbol_table & symbols = symbols2}} : xcoff_listN],marked_bool_aN);
			{
				base = 0;
				
				(text_offset1,module_offsets1,marked_bool_a1,symbols1)
					= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_table.text_symbols symbols text_offset0 module_offsets0;

				(toc_offset1,module_offsets2,symbols2)
					= compute_data_section_module_offsets base file_symbol_index symbol_table.toc_symbols symbols1 toc_offset0 module_offsets1;

				module_offsets3
					= compute_toc0_module_offset file_symbol_index symbol_table.toc0_symbol module_offsets2;
					
				symbols=symbol_table.symbols;
			}
	}

compute_bss_module_offsets :: !Int ![*Xcoff] Int Int !*{#Bool} ModuleOffsets -> (!Int,!ModuleOffsets,![*Xcoff],!*{#Bool});
compute_bss_module_offsets _ [] bss_offset0 file_symbol_index marked_bool_a module_offsets
	= (bss_offset0,module_offsets,[],marked_bool_a);

compute_bss_module_offsets base [xcoff=:{n_symbols,symbol_table}:xcoff_list] bss_offset0 file_symbol_index marked_bool_a module_offsets
	# (bss_offset1,module_offsets,marked_bool_a,symbols) 
		= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_table.bss_symbols symbol_table.symbols bss_offset0 module_offsets;
	#! (bss_offset2,module_offsets,xcoff_list,marked_bool_a)
		= compute_bss_module_offsets base xcoff_list bss_offset1 (file_symbol_index+n_symbols) marked_bool_a module_offsets;
	= (bss_offset2,module_offsets,[{xcoff & symbol_table = {symbol_table & symbols = symbols}} : xcoff_list],marked_bool_a);

compute_data_module_offsets :: !Int ![*Xcoff] !Int !Int ModuleOffsets -> (!Int,!ModuleOffsets,![*Xcoff]);
compute_data_module_offsets _ [] data_offset0 file_symbol_index module_offsets0
	= (data_offset0,module_offsets0,[]);

compute_data_module_offsets base [xcoff=:{n_symbols,symbol_table}:xcoff_list] data_offset0 file_symbol_index module_offsets
	# (data_offset1,module_offsets,symbols) 
		= compute_data_section_module_offsets base file_symbol_index symbol_table.data_symbols symbol_table.symbols data_offset0 module_offsets;
	#! (data_offset2,module_offsets,xcoff_list)
		= compute_data_module_offsets base xcoff_list data_offset1 (file_symbol_index+n_symbols) module_offsets;
	= (data_offset2,module_offsets,[{xcoff & symbol_table = {symbol_table & symbols = symbols}} : xcoff_list]);
	
	
// on SymbolIndexLists  
compute_toc0_module_offset file_symbol_index EmptySymbolIndex module_offsets
	=	module_offsets;
compute_toc0_module_offset file_symbol_index (SymbolIndex module_n EmptySymbolIndex) module_offsets
	=	{module_offsets & [file_symbol_index+module_n] = 32768};


// marked symbols
compute_section_module_offsets :: Int Int *{#Bool} SymbolIndexList *SymbolArray Int ModuleOffsets -> (!Int,!ModuleOffsets,*{#Bool},*SymbolArray);
compute_section_module_offsets _ file_symbol_index marked_bool_a EmptySymbolIndex symbol_array offset0 module_offsets0
	= (offset0,module_offsets0,marked_bool_a,symbol_array);
compute_section_module_offsets base file_symbol_index marked_bool_a (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 module_offsets0
	| not marked_bool_a.[file_symbol_index+module_n]
		// unmarked symbols
		= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_list symbol_array offset0 module_offsets0;
		
		# (offset1,module_offsets1)
			= compute_module_offset base module_symbol module_n offset0 file_symbol_index module_offsets0;
		= compute_section_module_offsets base file_symbol_index marked_bool_a symbol_list symbol_array offset1 module_offsets1;

// unmarked symbols
compute_data_section_module_offsets :: Int Int SymbolIndexList *SymbolArray Int ModuleOffsets -> (!Int,!ModuleOffsets,*SymbolArray);
compute_data_section_module_offsets _ file_symbol_index EmptySymbolIndex symbol_array0 offset0 module_offsets0
	= (offset0,module_offsets0,symbol_array0);

compute_data_section_module_offsets base file_symbol_index (SymbolIndex module_n symbol_list) symbol_array=:{[module_n]=module_symbol} offset0 module_offsets0
	# (offset1,module_offsets1)
		= compute_module_offset base module_symbol module_n offset0 file_symbol_index module_offsets0;	
	= compute_data_section_module_offsets base file_symbol_index symbol_list symbol_array offset1 module_offsets1;

// --------------------------------------------------------------------------------------------------------------------------------------------------
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
									
									/* ADDED: */
									# (imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a)
										= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
									= (LibrarySymbol symbol_name imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a);
									
//									= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
									
						}
			#
				(library_list,text_offset,toc_offset,module_offset_a, marked_bool_a)
					= compute_imported_library_symbol_offsets_lp library_list text_offset1 toc_offset (symbol_n+n_symbols) module_offset_a marked_bool_a;
//				n_imported_symbols2 = (text_offset1-text_offset0) / 12;
			=	(Library library_name imported_symbols n_symbols library_list,text_offset,toc_offset,module_offset_a,marked_bool_a);
		}
	= (library_list,text_offset,module_offset_a,marked_bool_a);
	
	
	
	
	

/*
OLD
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
									
									/*
									/* ADDED: */
									# (imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a)
										= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
									= (LibrarySymbol symbol_name imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a);
		*/
									
									= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
									
						}
			#
				(library_list,text_offset,toc_offset,module_offset_a, marked_bool_a)
					= compute_imported_library_symbol_offsets_lp library_list text_offset1 toc_offset (symbol_n+n_symbols) module_offset_a marked_bool_a;
				n_imported_symbols2 = (text_offset1-text_offset0) / 12;
			=	(Library library_name imported_symbols n_imported_symbols2 library_list,text_offset,toc_offset,module_offset_a,marked_bool_a);
		}
	= (library_list,text_offset,module_offset_a,marked_bool_a);
*/
	
// eventueel samenvoegen met compute_imported_library_symbol_offsets

increment_imported_library_symbol_offsets :: !Int LibraryList Int Int !*{#Bool} *{#Int} -> (!LibraryList,!Int,!*{#Int},!*{#Bool});
increment_imported_library_symbol_offsets base library_list text_offset symbol_n marked_bool_a module_offset_a
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
							//	| marked_bool_a.[symbol_n]
									// ADDED
									# (text_offset,module_offset_a)
										= module_offset_a![symbol_n];
									# (imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a)
										= compute_library_symbol_offsets symbol_list (symbol_n+2) (text_offset+24) (toc_offset+4)
											{module_offset_a & [symbol_n]=base + text_offset /*ADDED: ,[symbol_n+1]=toc_offset*/} marked_bool_a;
								
								
									= (LibrarySymbol symbol_name imported_symbols,text_offset,toc_offset,module_offset_a,marked_bool_a);
							// loosing librray symbol		= compute_library_symbol_offsets symbol_list (symbol_n+2) text_offset toc_offset module_offset_a marked_bool_a;
									
									//abort "increment_imported_library_symbol_offsets: oude symbolen mogen niet uit lib lijst" //
						}
			#
				(library_list,text_offset,toc_offset,module_offset_a, marked_bool_a)
					= compute_imported_library_symbol_offsets_lp library_list text_offset1 toc_offset (symbol_n+n_symbols) module_offset_a marked_bool_a;
//	ADDED:			n_imported_symbols2 = (text_offset1-text_offset0) / 12;
			=	(Library library_name imported_symbols /* ADDED n_imported_symbols2*/ n_symbols library_list,text_offset,toc_offset,module_offset_a,marked_bool_a);
		}
	= (library_list,text_offset,module_offset_a,marked_bool_a);

	
