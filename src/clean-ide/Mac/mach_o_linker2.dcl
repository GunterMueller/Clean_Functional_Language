definition module mach_o_linker2;

from StdFile import ::Files;

::	*SymbolArray :== SSymbolArray;
::	SSymbolArray :== {!Symbol};

::	Symbol
	= Module !Int !Int !Int !Int !IndirectSymbol !Int !String	// section_n length virtual_address file_offset indirect_symbol n_relocations relocations
	| Label !Int !Int !Int										// section_n offset module_n
	| SectionLabel !Int !Int									// section_n offset
	| ImportLabel !String										// label_name
	| ImportedLabel !Int !Int 									// file_n symbol_n
	| ImportedLabelPlusOffset !Int !Int !Int					// file_n symbol_n offset
	| UndefinedLabel !Int
	| EmptySymbol;

::	IndirectSymbol = NoIndirectSymbol | IndirectSymbol !Int !String;

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

::	*Xcoff :== *SXcoff;
:: SXcoff ={
		file_name			:: !String,
		symbol_table		:: !.SSymbolTable,
		n_symbols			:: !Int
	};

::	*SymbolTable :== *SSymbolTable;
:: SSymbolTable ={
		symbols			:: !.SSymbolArray,
		text_symbols	:: !SymbolIndexList,
		data_symbols	:: !SymbolIndexList,
		bss_symbols		:: !SymbolIndexList,
		stub_symbols	:: !SymbolIndexList,
		lazy_pointer_symbols :: !SymbolIndexList,
		non_lazy_pointer_symbols :: !SymbolIndexList,
		imported_symbols:: !SymbolIndexList,
		section_symbol_ns::!.{#Int},
		section_offsets	:: !{#SectionAddressAndSymbolN}
	};

::	SectionAddressAndSymbolN = { section_address :: !Int, section_symbol_n :: !Int};

:: XcoffArray :== {#SXcoff};

n_symbols_of_xcoff_list :: !Int ![Xcoff] -> (!Int,![Xcoff]);
write_mach_o_headers :: !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !Int !*File -> *File;

SIZE_OF_SECTION_HEADER:==68;
SIZE_OF_RELOCATION:==8;

N_EXT:==0x01;

N_UNDF:==0x0;
N_SECT:==0xe;

TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;
STUBS_SECTION:==4;
LAZY_POINTERS_SECTION:==5;
NON_LAZY_POINTERS_SECTION:==6;

PPC_RELOC_VANILLA:==0;
PPC_RELOC_PAIR:==1;
PPC_RELOC_BR14:==2;
PPC_RELOC_BR24:==3;
PPC_RELOC_LO16:==5;
PPC_RELOC_HA16:==6;
PPC_RELOC_SECTDIFF:==8;
PPC_RELOC_LO16_SECTDIFF:==11;
PPC_RELOC_HA16_SECTDIFF:==12;
PPC_RELOC_LOCAL_SECTDIFF:==15;

STUB_SIZE:==36;

sort_modules :: !*SXcoff -> .SXcoff;

create_names_table :: NamesTable;
insert_symbol_in_symbol_table :: !String Int Int !NamesTable -> NamesTable;
find_symbol_in_symbol_table :: !String !NamesTable -> (!NamesTableElement,!NamesTable);

read_mach_o_file :: !String NamesTable Bool !Files Int -> (![String],!*String,!*String,!Xcoff,!NamesTable,!Files);
empty_xcoff :: .SXcoff;

determine_section_n :: !Int !Int !Int !{#SectionAddressAndSymbolN} -> Int;
