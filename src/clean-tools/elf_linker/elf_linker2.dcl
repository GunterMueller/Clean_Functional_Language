definition module elf_linker2;

from StdFile import ::Files;
import elf_linker_types;

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;

n_symbols_of_xcoff_list :: !Int ![Xcoff] -> (!Int,![Xcoff]);
write_elf_headers :: !Int !Int !Int !Int !Int !Int !Int !*File -> *File;

STT_NOTYPE:==0;
STT_OBJECT:==1;
STT_FUNC:==2;
STT_SECTION:==3;
STT_FILE:==4;

STB_LOCAL:==0;
STB_GLOBAL:==1;

SHN_COMMON:==0xfff2;

N_UNDEF:==0;
TEXT_SECTION:==1;
DATA_SECTION:==2;
BSS_SECTION:==3;

sort_modules :: !*SXcoff -> .SXcoff;

create_names_table :: NamesTable;
insert_symbol_in_symbol_table :: !String Int Int !NamesTable -> NamesTable;
find_symbol_in_symbol_table :: !String !NamesTable -> (!NamesTableElement,!NamesTable);

read_xcoff_file :: !String NamesTable Bool !Files Int -> (![String],!*String,!*String,!Xcoff,!NamesTable,!Files);
empty_xcoff :: .SXcoff;
