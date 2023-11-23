definition module pdLinkerOffsets;

import SymbolTable;
import State;

:: *ModuleOffsets :== *{#Int};

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
ComputeOffsets :: [.(.Int -> .(.Offset -> .(*State -> *(Offset,*State))))];	
compute_module_offset :: !Int !Symbol !Int !Int !Int !*{#Int} -> (!Int,!*{#Int});
