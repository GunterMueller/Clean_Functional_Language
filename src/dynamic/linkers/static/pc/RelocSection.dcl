definition module RelocSection;

// import Sections,State;
from State import :: State;
from Sections import :: SectionHeader;

:: *RelocBlock = {
	page_rva					:: !Int,
	n_relocations				:: !Int,
	relocs						:: *[Int]
};

EmptyRelocBlock :: *RelocBlock;

:: *RelocBlocks :== *{#RelocBlock};

compute_relocs_section :: !Int !Int !Int !Int !SectionHeader !*{!SectionHeader} !State -> (!SectionHeader,!*[RelocBlock],!*{!SectionHeader},!*State);
write_reloc_section :: !*File !*[*RelocBlock] -> .File;
