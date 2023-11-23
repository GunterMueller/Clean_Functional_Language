implementation module RelocSection;

import StdArray, StdEnum;
from ExtInt import roundup_to_multiple;
from ExtFile import FWI, write_zero_bytes_to_file;
from pdExtFile import FWW;
import Sections;
import xcoff;
import State;
import ExtString;
import pdSections;
import pdExtString;
import StdEnv;
import pdSymbolTable;

:: *RelocBlock = {
	page_rva					:: !Int,
	n_relocations				:: !Int,
	relocs						:: *[Int]
};

EmptyRelocBlock :: *RelocBlock;
EmptyRelocBlock
	= { RelocBlock |
		page_rva				= 0,
		n_relocations			= 0,
		relocs					= []
	};

:: *RelocBlocks :== *{#RelocBlock};

compute_relocs_section :: !Int !Int !Int !Int !SectionHeader !*{!SectionHeader} !State -> (!SectionHeader,!*[RelocBlock],!*{!SectionHeader},!*State);
compute_relocs_section i_reloc_section_header start_rva base_va n_imported_symbols reloc_section_header section_header_a state
	// assume order: .text, .data and .bss
	// .bss section
	# (ok,_,bss_section,section_header_a)
		= get_section_index 0 BssSectionHeader section_header_a;
	| not ok
		= abort "compute_relocs_section: internal error";

	#! {section_rva=bss_section_rva} = sh_get_pd_section_header bss_section;
	#! s_virtual_bss_data = sh_get_s_virtual_data bss_section;
	#! n_pages = (bss_section_rva + (roundup_to_multiple s_virtual_bss_data page_size)) / page_size;

	// compute fixup blocks
	#! relocs_a = { {EmptyRelocBlock & page_rva = page_size * i} \\ i <- [0..dec n_pages] };			
	#! (relocs_a,state,section_header_a)
		= count_relocations_per_xcoffs 0 0 relocs_a base_va section_header_a state n_imported_symbols ;
	#! (s_relocs_section,relocs_l) = compute_relocs_size 0 n_pages relocs_a [] 0;

	// update section header
	#! pd_section_header = {
			section_name				= ".reloc"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_INITIALIZED_DATA bitor
										  IMAGE_SCN_MEM_DISCARDABLE bitor
										  IMAGE_SCN_MEM_READ
		};
	#! reloc_section_header = reloc_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data s_relocs_section;
	= (reloc_section_header,relocs_l,section_header_a,state);
where {
	compute_relocs_size :: !Int !.Int {*RelocBlock} *[*RelocBlock] Int -> *(!Int,!*[*RelocBlock]);
	compute_relocs_size page_n n_pages relocs_a relocs_l relocs_section_i 
		| page_n == n_pages
			= (relocs_section_i,relocs_l);

			#! (page_n_reloc_block,relocs_a)
				= replace relocs_a page_n EmptyRelocBlock;
			#! (n_relocations,page_n_reloc_block)
				= page_n_reloc_block!n_relocations;
			| n_relocations == 0
				= compute_relocs_size (inc page_n) n_pages relocs_a relocs_l relocs_section_i;
			
				#! s_fixup_block
					= s_fixup_header + n_relocations * s_fixup_entry;
				= compute_relocs_size (inc page_n) n_pages relocs_a [page_n_reloc_block:relocs_l] (relocs_section_i + s_fixup_block);	
} // compute_relocs_section	

count_relocations_per_xcoffs file_n first_symbol_n relocs_a base_va section_headers state=:{n_xcoff_files} n_imported_symbols
	| file_n == n_xcoff_files
		#! (relocs_a,state,section_headers)
			= count_relocations_in_jump_table relocs_a state section_headers n_imported_symbols;
		= (relocs_a,state,section_headers); 
		
		#! (n_symbols,state) = select_n_symbols file_n state;
		#! (relocs_a,state) = count_relocations_per_xcoff relocs_a state;	
		= count_relocations_per_xcoffs (inc file_n) (first_symbol_n + n_symbols) relocs_a base_va section_headers state n_imported_symbols ;
where {
	count_relocations_per_xcoff relocs_a state
		// .text
		#! (text_symbols,state) = selacc_text_symbols file_n state;
		#! (relocs_a,state) = count_relocations_per_section_kind text_symbols relocs_a state;

		// .data
		#! (data_symbols,state) = selacc_data_symbols file_n state;
		#! (relocs_a,state) = count_relocations_per_section_kind data_symbols relocs_a state;

		// .bss 
		#! (bss_symbols,state) = selacc_bss_symbols file_n state;
		#! (relocs_a,state) = count_relocations_per_section_kind bss_symbols relocs_a state;
		= (relocs_a,state);
	where {
		count_relocations_per_section_kind EmptySymbolIndex relocs_a state
			= (relocs_a,state);
		count_relocations_per_section_kind (SymbolIndex module_n sils) relocs_a state
			#! (module_symbol,state) = sel_symbol file_n module_n state;
			#! (relocs_a,state) = count_relocations_per_module module_symbol relocs_a state;
			= count_relocations_per_section_kind sils relocs_a state;
		where {
			count_relocations_per_module (Module _ _ virtual_address _ n_relocations relocations _) relocs_a state
				#! (marked_module, state) = selacc_marked_bool_a (first_symbol_n + module_n) state;
				| not marked_module
					// not marked_module implies its symbols not marked
					= (relocs_a,state);
					// marked module, the symbols it contains are then also marked
					#! (module_va,state) = selacc_module_offset_a (first_symbol_n + module_n) state;
					= count_relocations 0 n_relocations relocations (module_va - base_va) relocs_a state;
			where {
				count_relocations :: !Int !Int {#Char} Int *{*RelocBlock} *State -> *(!*{*RelocBlock},!*State);
				count_relocations relocation_n n_relocations relocations module_rva relocs_a state
					| relocation_n == n_relocations
						= (relocs_a,state);
						// conditions: symbol is marked && is absolute reference
						// {relative,absolute}  {marked,unmarked} {definition,reference} symbol;
						| relocation_type == REL_REL32 || relocation_type == REL_ABSOLUTE
							= count_relocations (inc relocation_n) n_relocations relocations module_rva relocs_a state;
							// a marked, absolute {definition,reference} 
							#! (reloc_symbol,state) = sel_symbol file_n relocation_symbol_n state;
							// a marked, absolute referenced symbol
							#! rva = module_rva + (relocation_offset - virtual_address);
							#! page_n = rva / page_size;
							// compute fixups (=relocations)
							#! (page_relocs,relocs_a) = replace relocs_a page_n EmptyRelocBlock;
							#! mask = dec (1 << i_reloc_type);
							#! offset = (rva - page_relocs.page_rva) bitand mask;
							#! updated_page_relocs
								= { page_relocs &
									n_relocations = inc page_relocs.n_relocations,
									relocs = [(IMAGE_REL_BASED_HIGHLOW << i_reloc_type) bitor offset : page_relocs.relocs]
								};
							#! relocs_a = { relocs_a & [page_n] = updated_page_relocs };
							= count_relocations (inc relocation_n) n_relocations relocations module_rva relocs_a state;
				where {
					relocation_type = relocations IWORD (relocation_index+8);
					relocation_symbol_n = relocations ILONG (relocation_index+4);
					relocation_offset = relocations ILONG relocation_index;
					relocation_index = relocation_n * SIZE_OF_RELOCATION;
				}
			}
		}  
	}

	count_relocations_in_jump_table :: {*RelocBlock} !*State !*{!SectionHeader} !Int -> ({*RelocBlock},!*State,!*{!SectionHeader});
	count_relocations_in_jump_table relocs_a state section_headers n_imported_symbols
		#! (ok,_,text_section,section_headers)
			= get_section_index 0 TextSectionHeader section_headers;	
		#! pd_text_section = sh_get_pd_section_header text_section;
		#! jump_table_rva = pd_text_section.section_rva + (sh_get_s_virtual_data text_section) - (n_imported_symbols * 6);
		#! relocs_a = count_jump_relocations 0 n_imported_symbols (jump_table_rva + 2) relocs_a;
		= (relocs_a,state,section_headers);
	where {	
		count_jump_relocations imported_symbol_n n_imported_symbols jump_table_entry_rva relocs_a
			| imported_symbol_n == n_imported_symbols
				= relocs_a;
				#! page_n = jump_table_entry_rva / page_size;
				#! (page_relocs,relocs_a) = replace relocs_a page_n EmptyRelocBlock;
				#! mask = dec (1 << i_reloc_type);
				#! offset = (jump_table_entry_rva - page_relocs.page_rva) bitand mask;
				#! updated_page_relocs
					= { page_relocs &
						n_relocations = inc page_relocs.n_relocations,
						relocs = [(IMAGE_REL_BASED_HIGHLOW << i_reloc_type) bitor offset : page_relocs.relocs]
					};
				#! relocs_a = { relocs_a & [page_n] = updated_page_relocs };
				= count_jump_relocations (inc imported_symbol_n) n_imported_symbols (jump_table_entry_rva + 6) relocs_a;
	}
}

write_reloc_section :: !*File !*[*RelocBlock] -> .File;
write_reloc_section pe_file relocs_info
	#! (s_relocs_section,pe_file) = write_reloc_blocks (reverse relocs_info) 0 pe_file; 
	= pe_file;
where {
	write_reloc_blocks [] relocs_section_i pe_file
		= (relocs_section_i,pe_file);
	write_reloc_blocks [reloc_block=:{page_rva,n_relocations,relocs} : reloc_blocks] relocs_section_i pe_file
		#! block_size = s_fixup_header + n_relocations * s_fixup_entry;
		#! pe_file = pe_file FWI page_rva FWI block_size;
		#! pe_file = foldl (\pe_file r -> pe_file FWW r) pe_file relocs;
		= write_reloc_blocks reloc_blocks (relocs_section_i + block_size) pe_file;
}
