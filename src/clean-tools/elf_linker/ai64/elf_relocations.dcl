definition module elf_relocations;

import StdInt,StdArray,StdFile;
import elf_linker_types;

BigOrLittleEndian big little :== little;
                                                  
SIZE_OF_HEADER:==64;
SIZE_OF_SECTION_HEADER:==64;
SIZE_OF_SYMBOL:==24;                                                                     
SIZE_OF_RELOCATION:==24;

DATA_SECTION_ALIGN:==16;

SHT_RELA:==4;
SHT_REL:==9;

SHT_relocations:==SHT_RELA;

E_SHOFF_OFFSET:==40;
E_SHENTSIZE_OFFSET:==58;
E_SHNUM_OFFSET:==60;
E_SHSTRNDX_OFFSET:==62;

SH_FLAGS_OFFSET:==8;
SH_ADDR_OFFSET:==16;
SH_OFFSET_OFFSET:==24;
SH_SIZE_OFFSET:==32;
SH_LINK_OFFSET:==40;
SH_INFO_OFFSET:==44;
SH_ADDRALIGN_OFFSET:==48;

ST_INFO_OFFSET:==4;
ST_OTHER_OFFSET:==5;
ST_SHNDX:==6;
ST_VALUE_OFFSET:==8;
ST_SIZE_OFFSET:==16;

get_relocation_type relocations relocation_index:==relocations LONG (relocation_index+8);
get_relocation_symbol_n relocations relocation_index:==relocations LONG (relocation_index+12);

(BYTE) string i :== toInt (string.[i]);
                                                                                                                        
(WORD) :: !{#Char} !Int -> Int;
// (WORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);
                                                                                                                        
(LONG) :: !{#Char} !Int -> Int;
// (LONG) string i = (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(POINTER) :: !{#Char} !Int -> Int;
// (POINTER) string i = (string BYTE (i+7)<<56) bitor (string BYTE (i+6)<<48) bitor (string BYTE (i+5)<<40) bitor (string BYTE (i+4)<<32) bitor
//						(string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

(TBYTE) :: !{#Char} !Int -> Int;
// (TBYTE) string i = (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);i

shstrtab_data_relocations_section_name_offset :== 39;
shstrtab_symbol_table_section_name_offset :== 50;
shstrtab_string_table_section_name_offset :== 58;
shstrtab_size :== 68;

(FWP) infixl;
(FWP) f i :== fwritei (i>>32) (fwritei i f);

write_elf_header :: !*File -> *File;
write_shstrtab_end :: !*File -> *File;
write_symbol :: !Int !Int !Int !Int !*File -> *File;

count_text_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;
count_data_relocations :: !Int !{#Char} !{!Symbol} !XcoffArray -> Int;

write_text_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;
write_data_module_relocations :: !Symbol !Int !Int !SSymbolArray !XcoffArray !{#Int} !{#Int} !*File -> *File;

relocate_text :: !Int Int Int Int Int !{#Char} {#SXcoff} {#Int} {#Int} {!Symbol} !*{#Char} -> *{#Char};
relocate_data :: !Int !Int Int Int Int !{#Char} Int {#Int} {#Int} {!Symbol} XcoffArray !*{#Char}-> *{#Char};
