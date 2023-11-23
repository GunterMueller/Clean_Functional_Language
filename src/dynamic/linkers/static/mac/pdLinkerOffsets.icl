implementation module pdLinkerOffsets;

import SymbolTable;

:: *ModuleOffsets :== *{#Int};

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
