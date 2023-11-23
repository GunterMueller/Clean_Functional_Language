definition module elf_relocations;

import StdInt,StdArray,StdFile;
import elf_linker_types;

BigOrLittleEndian big little :== little;
                                                                                                                        
SIZE_OF_HEADER:==52;
SIZE_OF_SECTION_HEADER:==40;
SIZE_OF_SYMBOL:==16;
SIZE_OF_RELOCATION:==8;

DATA_SECTION_ALIGN:==8;

R_386_NONE:==0;
R_386_32:==1;
R_386_PC32:==2;
R_386_PLT32:==4;

SHT_RELA:==4;
SHT_REL:==9;

SHT_relocations:==SHT_REL;

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

RELOCATION_TYPE_OFFSET:== 4;
RELOCATION_SYMBOL_N_OFFSET:== 5;

get_relocation_symbol_n relocations relocation_index:==relocations TBYTE (relocation_index+RELOCATION_SYMBOL_N_OFFSET);

(BYTE) string i :== toInt (string.[i]);
                                                                                                                        
(WORD) :: !{#Char} !Int -> Int;
// (WORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
// (LONG) string i = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(POINTER) :: !{#Char} !Int -> Int;
// (POINTER) string i = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(TBYTE) :: !{#Char} !Int -> Int;
// (TBYTE) string i = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);i

shstrtab_data_relocations_section_name_offset :== 38;
shstrtab_symbol_table_section_name_offset :== 48;
shstrtab_string_table_section_name_offset :== 56;
shstrtab_size :== 64;

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
