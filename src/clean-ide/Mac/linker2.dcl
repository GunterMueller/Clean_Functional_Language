definition module linker2;

from StdFile import :: Files;

::	SymbolArray :== {!Symbol};

::	Symbol
	= Module !Module
	| Label !Label
	| ImportLabel !String
	| ImportedLabel !ImportedLabel
	| AliasModule !AliasModule
	| ImportedLabelPlusOffset !ImportedLabelPlusOffset
	| ImportedFunctionDescriptor !ImportedLabel
	| ImportedFunctionDescriptorTocModule !ImportedFunctionDescriptorTocModule
	| EmptySymbol;

	::	Module = {
			section_n				::!Int,
			module_offset			::!Int,
			length					::!Int,
			first_relocation_n		::!Int,
			end_relocation_n		::!Int,
			align					::!Int
		};
	::	Label = {
			label_section_n			::!Int,
			label_offset			::!Int,
			label_module_n			::!Int
		};
	::	ImportedLabel = {
			implab_file_n			::!Int,
			implab_symbol_n			::!Int
		};
	::	AliasModule = {
			alias_module_offset		::!Int,
			alias_first_relocation_n::!Int,
			alias_global_module_n	::!Int
		};
	::	ImportedLabelPlusOffset = {
			implaboffs_file_n		::!Int,
			implaboffs_symbol_n		::!Int,
			implaboffs_offset		::!Int
		};
	::	ImportedFunctionDescriptorTocModule = {
			imptoc_offset			::!Int,
			imptoc_file_n			::!Int,
			imptoc_symbol_n			::!Int			
		};

::	SymbolIndexList = SymbolIndex !Int !SymbolIndexList | EmptySymbolIndex;

::	NamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

::	LibraryList = Library !String !LibrarySymbolsList !Int !LibraryList | EmptyLibraryList;

::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList | EmptyLibrarySymbolsList;

:: Xcoff ={
		header				:: !XcoffHeader,
		symbol_table		:: !.SymbolTable,
		text_relocations	:: !String,
		data_relocations	:: !String,
		n_text_relocations	:: !Int,
		n_data_relocations	:: !Int,
		n_symbols			:: !Int
	};

:: XcoffHeader ={
		file_name			:: !String,
		text_section_offset	:: !Int,
		text_section_size	:: !Int,
		data_section_offset	:: !Int,
		data_section_size	:: !Int,
		text_v_address		:: !Int,
		data_v_address		:: !Int
	};

:: SymbolTable ={
		text_symbols	:: !SymbolIndexList,
		data_symbols	:: !SymbolIndexList,
		toc_symbols		:: !SymbolIndexList,
		bss_symbols		:: !SymbolIndexList,
		toc0_symbol		:: !SymbolIndexList,
		imported_symbols:: !SymbolIndexList,
		symbols			:: !.SymbolArray
	};

::	LoaderRelocations
	= CodeRelocation !Int !.LoaderRelocations
	| DataRelocation !Int !.LoaderRelocations
	| DeltaRelocation !Int !.LoaderRelocations
	| DeltaDataRelocation !Int !Int !.LoaderRelocations
	| ImportedSymbolsRelocation !Int !.LoaderRelocations
	| EmptyRelocation;

:: SymbolsArray :== {!SymbolArray};

n_symbols_of_xcoff_list :: !Int ![*Xcoff] -> (!Int,![*Xcoff]);
create_xcoff_file :: !String !Int !Int !Int !Int !Int !*Files -> *(*File,*Files);

SIZE_OF_HEADER:==20;
SIZE_OF_SECTION_HEADER:==40;
SIZE_OF_SYMBOL:==18;
SIZE_OF_RELOCATION:==10;

C_EXT:==2;
C_HIDEXT:==107;
C_FILE:==103;

XTY_ER:==0;
XTY_SD:==1;
XTY_LD:==2;
XTY_CM:==3;

N_UNDEF:==0;
TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;
TOC_SECTION:==4;

XMC_PR:==0;
XMC_TC:==3;
XMC_RW:==5;
XMC_GL:==6;
XMC_BS:==9;
XMC_DS:==10;
XMC_TC0:==15;

R_POS:==0;
R_TOC:==3;
R_TRL:==0x12; // 4;
R_BR:==10;
R_REF:==15;

R_MW_POS:==32;
R_MW_BR:==42;
R_MW_TOC:==35;

(WORD) :: !String !Int -> Int;

sort_modules :: !*Xcoff -> .Xcoff;

create_names_table :: *NamesTable;
insert_symbol_in_symbol_table :: !String Int Int !*NamesTable -> *NamesTable;
find_symbol_in_symbol_table :: !String !*NamesTable -> (!NamesTableElement,!*NamesTable);
reverse_symbols :: !SymbolIndexList -> SymbolIndexList;

read_library_files :: ![String] Int Int !*Files *NamesTable -> (![String],!LibraryList,!Int,!*Files,!*NamesTable);
read_symbol_table :: !Int !Int !*File -> (!Bool,!String,!String,!*File);
compute_xcoff_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray -> *LoaderRelocations;
compute_pef_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray Int -> *LoaderRelocations;
count_and_reverse_relocations :: !*LoaderRelocations -> (!Int,!*LoaderRelocations);
write_pef_loader_relocations :: !LoaderRelocations !*File -> *File;
write_xcoff_loader_relocations :: !LoaderRelocations !*File -> *File;
open_file_and_read_xcoff_header :: !String !*Files -> (!Bool,!String,!*File,!*Files);
read_xcoff_file :: !String *NamesTable Bool !String !*File !*Files Int -> (![String],!*String,!*String,!*Xcoff,!*NamesTable,!*Files);
empty_xcoff :: .Xcoff;

