definition module LinkerOffsets;

import StdEnv;
import SymbolTable;
import State;
instance toString Offset;

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
	
DefaultOffset :: Offset;
	
// zou eigenlijk nog wat aan gedaan moeten worden; misschien abstractie van het platform

compute_offsets :: !Int !Int !Int !LibraryList ![*Xcoff] !*{#Bool} -> (!Int,!Int,!Int,!Int,!Int,!LibraryList,!*{#Int},![*Xcoff],!*{#Bool});
//compute_offsets2 :: !Int !*State !Offset -> (!Offset,!*State);

// NEW exported
compute_offsets2 :: !Int !*State [.Section] -> (!Offset,!*State);

sections_specification :: !Bool !Int -> [.Section];
//sections_specification :: !Int -> [.Section];
// Increment Specification
sections_inc_specification :: !Int !Int -> [.Section];

// NEW datatypes
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
	| ComputesSubSection !Int (Int *State -> (Int,*State))
	;
	
:: SelAccSymbol = {
		selacc_symbol		:: (Int *State -> (SymbolIndexList,*State))
	,	initial_offset		:: !Counter
	,	marked_computation	:: !Bool
	,	custom_index_loop 	:: CustomIndexLoop
	};
	
:: CustomIndexLoop 
	= CustomIndexLoopFunc (Int Int Int SymbolIndexList Int *State -> (Int,*State))
	| NoCustomIndexLoop
	;
	
DefaultSelAccSymbol :: SelAccSymbol;


DefaultSection :: Section;	

DefaultSubSection :: SubSection;

	
:: SubSectionOffset = {
		counter			:: !Int,
		end				:: !Int,
		aligned_end		:: !Int
	};
	
DefaultSubSectionOffset :: SubSectionOffset;
raw_data_specification :: [.Section];
ComputeOffsets :: *State [.Section] -> *(.{SubSectionOffset},*State);