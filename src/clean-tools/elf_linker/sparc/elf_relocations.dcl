definition module elf_relocations;

import StdInt,StdArray,StdFile;
import elf_linker_types;

BigOrLittleEndian big little :== big;

SIZE_OF_HEADER:==52;
SIZE_OF_SECTION_HEADER:==40;
SIZE_OF_SYMBOL:==16;
SIZE_OF_RELOCATION:==12;

DATA_SECTION_ALIGN:==8;

R_SPARC_NONE:==0;
R_SPARC_32:==3;
R_SPARC_WDISP30:==7;
R_SPARC_WDISP22:==8;
R_SPARC_HI22:==9;
R_SPARC_LO10:==12;
R_SPARC_UA32:==23;

SHT_RELA:==4;
SHT_REL:==9;

SHT_relocations:==SHT_RELA;

E_SHOFF_OFFSET:==32;
E_SHENTSIZE_OFFSET:==46;
E_SHNUM_OFFSET:==48;
E_SHSTRNDX_OFFSET:==50;

SH_FLAGS_OFFSET:==8;
SH_ADDR_OFFSET:==12;
SH_OFFSET_OFFSET:==16;
SH_SIZE_OFFSET:==20;
SH_LINK_OFFSET:==24;
SH_INFO_OFFSET:==28;
SH_ADDRALIGN_OFFSET:==32;

ST_INFO_OFFSET:==12;
ST_OTHER_OFFSET:==13;
ST_SHNDX:==14;
ST_VALUE_OFFSET:==4;
ST_SIZE_OFFSET:==8;

RELOCATION_TYPE_OFFSET :== 7;
RELOCATION_SYMBOL_N_OFFSET :== 4;

get_relocation_symbol_n relocations relocation_index:==relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);

(BYTE) string i :== toInt (string.[i]);

(WORD) :: !{#Char} !Int -> Int;
// (WORD) string i = (string BYTE i<<8) bitor (string BYTE (i+1));
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
// (LONG) string i = (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(POINTER) :: !{#Char} !Int -> Int;
// (POINTER) string i = (string BYTE i<<24) bitor (string BYTE (i+1)<<16) bitor (string BYTE (i+2)<<8) bitor (string BYTE (i+3));

(TBYTE) :: !{#Char} !Int -> Int;
// (TBYTE) string i = (string BYTE i<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE (i+2));

shstrtab_data_relocations_section_name_offset :== 39;
shstrtab_symbol_table_section_name_offset :== 50;
shstrtab_string_table_section_name_offset :== 58;
shstrtab_size :== 68;

(FWP) infixl;
(FWP) f i :== fwritei i f;

write_elf_header :: !*File -> *File;
write_shstrtab_end :: !*File -> *File;
write_symbol :: !Int !Int !Int !Int !*File -> *File;

count_text_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_data_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;

write_text_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_data_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;

relocate_text :: !.Int Int Int Int Int {#Char} {#SXcoff} {#Int} {#Int} {!Symbol} !*{#.Char} -> .{#Char};
relocate_data :: Int Int Int Int Int String Int {#Int} {#Int} {!Symbol} XcoffArray *{#Char}-> *{#Char};
