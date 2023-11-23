definition module dynamics;

from StdFile import :: Files;
from UnknownModuleOrSymbol import :: ModuleOrSymbolUnknown;
from StdDynamicVersion import :: Version;
from StdDynamicLowLevelInterface import :: DynamicHeader;

// filenames for conversion functions; keep the corresponding *.c files up-to-date!
toFileNameSubString :: !Version -> String;
	
copy_graph_to_string	:== "copy_graph_to_string";
copy__graph__to__string :== "copy__graph__to__string";

copy_string_to_graph	:== "copy_string_to_graph";
copy__string__to__graph	:== "copy__string__to__graph";

generate_needed_label_names2 :: !String !String -> [ModuleOrSymbolUnknown];
	
// used by the dynamic linker
/* format of string:
** word (4 bytes)					: offset to stringtable
** word 							: size of stringtable
** word								: offset to descriptor address table
** word								: size of descriptor address table
** size of stringtable				: stringtable
** size of descriptor address table	: descriptor address table
*/
// OUTDATED ...
//generate_needed_label_names :: String -> [ModuleOrSymbolUnknown];
// ... OUTDATED

determine_prefixes3 :: !Int -> ([Char],!Int,!Int);
get_descriptor_and_module_name :: !Int !String ![(!Int,(!String,!String))] -> ((!String,!String),[(Int,(!String,!String))]);

N_PREFIXES		:== 6;					// number of prefixes

find_prefix :: !Int !Int -> (!Bool,!Int);
	
bit_n_to_char :: !Int -> Char;

INDIRECTION_PREFIX	:== 7;
DPREFIX				:== 1;

NPREFIX_VALUE		:== 0x00000000;		// 000
DPREFIX_VALUE		:== 0x20000000;		// 001
KPREFIX_VALUE		:== 0x40000000;		// 010
CPREFIX_VALUE		:== 0x60000000;		// 011
TPREFIX_VALUE		:== 0x80000000;		// 100
RPREFIX_VALUE		:== 0xa0000000;		// 101

get_descriptor_and_module_name2 :: !Int !.{#Char} -> (!{#Char},!{#Char});

gen_label_name :: !Bool (!String,!String) !Char -> String;

// read_stringtable_and_desc_address_table :: file_name  files -> ((ok,stringtable,desc_address_table),files)
read_stringtable_and_desc_address_table :: !String !*Files -> ((!Bool,!Version,!String,!String),!*Files);

// decode_descriptor_offset2 :: offset_in_graph graph -> (prefix,partial_arity_if_D_PREFIX,expanded_offset_in_desc_table)
decode_descriptor_offset2 :: !Int !{#Char} -> (Int,Int,Int);	

// read_dynamic_as_binary :: file_name read_graph files -> ((ok,dynamic_header,graph,stringtable,descriptor_table),files);
read_dynamic_as_binary :: !String !Bool !*Files -> *(.(Bool,DynamicHeader,.{#Char},.{#Char},.{#Char}),*Files);
	
// read_stringtable_as_binary :: dynamic_header file -> (ok,stringtable,file)
read_stringtable_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);
	
// read_descriptortable_as_binary :: dynamic_header file -> (ok,descriptor_table,file)
read_descriptortable_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);

// read_graph_as_binary :: dynamic_header file -> (ok,graph,file)
read_graph_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);
