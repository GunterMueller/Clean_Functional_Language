implementation module dynamics;

import StdEnv;
import UnknownModuleOrSymbol;
import ExtString;
import StdDynamicLowLevelInterface;
import cg_name_mangling;
import StdDynamicVersion;
import pdExtInt;
import _SystemDynamic;

// filenames for conversion functions; depends on copy_stringc_to_graph and copy_graph_to_string.c 
toFileNameSubString :: !Version -> String;
toFileNameSubString version
	= "0x" +++ hex_int (fromVersion version);
	
copy_graph_to_string	:== "copy_graph_to_string";
copy__graph__to__string :== "copy__graph__to__string";

copy_string_to_graph	:== "copy_string_to_graph";
copy__string__to__graph	:== "copy__string__to__graph";	

generate_needed_label_names2 :: !String !String -> [ModuleOrSymbolUnknown];
generate_needed_label_names2 stringtable descriptor_address_table
	#! l
		= gen_label_names 0 [] []; // s_descriptor_address_table descriptor_address_table;
	= l; 
where {
	gen_label_names offset descriptor_module_table ms
		|offset == s_descriptor_address_table
			= ms;
		
		#! (prefixes,string_offset,_)
			= determine_prefixes offset descriptor_address_table;
		| length prefixes > 1 
			= abort "gen_label_names; more than one prefix";
	
		#! (descriptor_and_module_name,descriptor_module_table)
			= get_descriptor_and_module_name string_offset stringtable descriptor_module_table;
					
		#! l
			= map (\prefix -> ModuleUnknown (snd descriptor_and_module_name) (gen_label_name True descriptor_and_module_name prefix)) prefixes;
		= gen_label_names (offset + 4) descriptor_module_table (ms ++ l);
	
	s_descriptor_address_table
		= size descriptor_address_table;
} // generate_needed_label_names

get_descriptor_and_module_name :: !Int !String ![(!Int,(!String,!String))] -> ((!String,!String),[(Int,(!String,!String))]);
get_descriptor_and_module_name offset string_table descriptor_module_table
	#! result
		= filter (\(offset2,_) -> offset == offset2) descriptor_module_table
	| not (isEmpty result)
		= abort "get_descriptor_and_module_name: descriptor already decoded";
		
		#! descriptor_and_module_name
			= get_descriptor_and_module_name2 offset string_table;
		= (descriptor_and_module_name,[(offset,descriptor_and_module_name):descriptor_module_table]);

get_descriptor_and_module_name2 :: !Int !.{#Char} -> (!{#Char},!{#Char});
get_descriptor_and_module_name2 offset string_table
	#! i
		= offset - 4;

	// extract descriptor name
	#! l_descriptor_name
		= FromStringToInt string_table i;
	#! descriptor_name_start
		= i + 4;
	#! descriptor_name
		= string_table % (descriptor_name_start, descriptor_name_start + l_descriptor_name - 1);
		
	// extract module name
	#! module_length_start
		= descriptor_name_start + ((l_descriptor_name + 3) / 4) * 4;
	#! l_module_name
		= FromStringToInt string_table module_length_start;
	| (l_module_name bitand 0x80000000) == 0
	 	/*
	 	** The signed bit of module length is not set, then the module name
	 	** follows the function. no indirection has to be taken.
	 	*/
	 	#! module_name_start 
	 		= module_length_start + 4;
	 	#! module_name
	 		= string_table % (module_name_start, module_name_start + l_module_name - 1);
	 	= (descriptor_name,module_name);
	 		
		/*
		** length of module name was negative, which means it is a
		** relative offset from that length in the string to the 
		** proper module name.
		*/
		#! module_length_start_indirection
			= module_length_start + l_module_name - 4;
		#! l_module_name
			= FromStringToInt string_table module_length_start_indirection;
		#! module_name_start
			= module_length_start_indirection + 4;
		#! module_name
			= string_table % (module_name_start, module_name_start + l_module_name - 1);
		= (descriptor_name,module_name); 

determine_prefixes :: !Int !String -> ([Char],!Int,!Int);
determine_prefixes offset descriptor_address_table
	= (
		[ to_char_prefix (get_prefix prefix_kind_set) \\ get_prefix <- GET_PREFIX_FUNC | (get_prefix prefix_kind_set) <> 0]	
		,string_offset,prefix_kind_set);
where {
	(string_offset,prefix_kind_set)
		= get_string_offset_and_prefix_kind_set offset descriptor_address_table;
} // determine_prefixes 

determine_prefixes3 :: !Int -> ([Char],!Int,!Int);
determine_prefixes3 prefix_set_and_string_ptr 
	#! string_offset
		= get_string_offset prefix_set_and_string_ptr;
	#! prefix_kind_set
		= get_prefix_set prefix_set_and_string_ptr;	
	= ( 
		[ to_char_prefix (get_prefix prefix_kind_set) \\ get_prefix <- GET_PREFIX_FUNC | (get_prefix prefix_kind_set) <> 0]	
		,string_offset,prefix_kind_set);

N_PREFIXES		:== 6;					// number of prefixes

find_prefix :: !Int !Int -> (!Bool,!Int);
find_prefix bit_n prefix_kind_set
	|  bit_n < 0
		= (False,-1);
			
		#! s = ("find_prefix " +++ toString prefix_kind_set +++ " - " +++ toString bit_n +++" - " +++ toString (1 << bit_n))
		| prefix_kind_set bitand (1 << bit_n) == 0
			= find_prefix (dec bit_n) prefix_kind_set;
			= (True,bit_n);
	
// bit_n_to_char :: bit_n -> character		
bit_n_to_char :: !Int -> Char;
bit_n_to_char 0		= 'n';
bit_n_to_char 1		= 'd';
bit_n_to_char 2		= 'k';
bit_n_to_char 3		= 'c';
bit_n_to_char 4		= 't';
bit_n_to_char 5		= 'r';
bit_n_to_char c 	= abort ("bit_n_to_char: " +++ toString c);
		
INDIRECTION_PREFIX	:== 7;
DPREFIX				:== 1;

NPREFIX_VALUE		:== 0x00000000;		// 000
DPREFIX_VALUE		:== 0x20000000;		// 001
KPREFIX_VALUE		:== 0x40000000;		// 010
CPREFIX_VALUE		:== 0x60000000;		// 011
TPREFIX_VALUE		:== 0x80000000;		// 100
RPREFIX_VALUE		:== 0xa0000000;		// 101


/*
** decodes an entry of descriptor address table. The
** most significant byte contains the set of required prefixes. The less significant
** bytes contain the stringtable offset
*/
get_string_offset_and_prefix_kind_set offset descriptor_address_table
	:== (get_string_offset_and_prefix_kind_set2 offset descriptor_address_table);
where {
	get_string_offset_and_prefix_kind_set2 :: !Int !String -> (!Int,!Int);
	get_string_offset_and_prefix_kind_set2 offset descriptor_address_table
		#! prefix_kind_set_and_string_table_offset
			= FromStringToInt descriptor_address_table offset;
		#! string_offset
			= get_string_offset prefix_kind_set_and_string_table_offset; // bitand 0x00ffffff;
		#! prefix_kind_set
			= get_prefix_set prefix_kind_set_and_string_table_offset;
		= (string_offset,prefix_kind_set)
} 


gen_label_name :: !Bool (!String,!String) !Char -> String;
gen_label_name expand q=:(descriptor_name,module_name) descriptor_prefix
	#! module_name
		= if expand (expand_special_chars module_name) module_name;
	#! descriptor_name
		= if expand (expand_special_chars descriptor_name) descriptor_name;
	#! label_name
		= case module_name of {
			/*
			** system functions e.g. INT, Cons, Nil are not at all prefixed with 
			** their defining module name _system.
			*/ 
			"__system"
				-> case descriptor_name of {
					/*
					** The descriptor names for objects of the standard environment are irregular.
					** They therefore need to be translated manually to the proper label names.
					*/
					"INT"
						-> "INT";
					"Cons"
						-> "__Cons";
					"__Cons"
						-> "__Cons";
						
					"Nil"
						-> "__Nil";
					"__Nil"
						-> "__Nil";
					"ARRAY"
						-> "ARRAY";
					"__ARRAY__"
						-> descriptor_name;
					"__STRING__"
						-> descriptor_name;
					"BOOL"
						-> "BOOL";
					"REAL"
						-> "REAL";
					"CHAR"
						-> "CHAR";
					"__Tuple"
						-> descriptor_name;
					"AP"
						-> "e__system__" +++ toString descriptor_prefix +++ "AP";
					"__ind"
						->  "e__system__" +++ toString descriptor_prefix +++ "ind";
					"EMPTY"
						| descriptor_prefix=='d'
							-> "EMPTY";
						| descriptor_prefix=='n'
							-> "__cycle__in__spine";
							-> abort "gen_label_name EMPTY";
					_
						| fst (starts "__S_P" descriptor_name)
							-> toString descriptor_prefix +++ descriptor_name;

						// handle unboxed lists
						# unmangled_descriptor_name = fst q
						# s_unmangled_descriptor_name = size unmangled_descriptor_name;
						# (is_unboxed_list,i_begin_element_string) = starts "[#" unmangled_descriptor_name
						| is_unboxed_list && unmangled_descriptor_name.[dec s_unmangled_descriptor_name] == ']'
							#! (is_tail_strict,i_end_element_string)
								= if (unmangled_descriptor_name.[s_unmangled_descriptor_name - 2] == '!')
										(True,s_unmangled_descriptor_name - 3)
										(False,s_unmangled_descriptor_name - 2)
										;
										
							// determine the kind of unboxed list (Int,Real,Char,Bool,File,{})
							#! element = unmangled_descriptor_name % (i_begin_element_string,i_end_element_string);
							#! letter
								= case element of {
									"{}"			-> 'a';
									element_type	-> toLower element.[0];
								}
								
							#! list_constructor
								= "__Cons" +++ toString letter;
							#! list_constructor
								= if is_tail_strict (list_constructor +++ "ts") list_constructor;
							-> list_constructor;

							-> abort ("<gen_label_name>: !unboxed object not supported " +++ descriptor_name +++ " - " +++ module_name +++ " !" +++ unmangle_name (fst q));	
				}; // case function_name		
			_
				->  ("e__" +++ module_name +++ "__" +++ toString descriptor_prefix +++ descriptor_name);
		} // case module_name
		
	= label_name;
	
read_stringtable_and_desc_address_table :: !String !*Files -> ((!Bool,!Version,!String,!String),!*Files);
read_stringtable_and_desc_address_table file_name files
	#! ((ok,{version_number},_,stringtable,desctable),files)
		= read_dynamic_as_binary file_name False files
	= ((ok,toVersion version_number,stringtable,desctable),files);
	
decode_descriptor_offset2 :: !Int !{#Char} -> (Int,Int,Int);	
decode_descriptor_offset2 graph_o graph
	#! encoded_descp
		= FromStringToInt graph graph_o;	
	| True
	#! prefix
		= (encoded_descp >> (32 - 3)) bitand 7;
	#! partial_arity
		= case prefix of {
			DPREFIX
				#! partial_arity
					= (encoded_descp >> 24) bitand 0x0000001f;
				-> partial_arity;
			_
				-> 999;
		};
	#! expanded_desc_table_o
		= ((encoded_descp bitand 0x00ffffff) - 4) >> 2;
	// -4 because 0 is being used for boxed arguments in arrays
	= (prefix,partial_arity,expanded_desc_table_o);			
			
read_dynamic_as_binary :: !String !Bool !*Files -> *(.(Bool,DynamicHeader,.{#Char},.{#Char},.{#Char}),*Files);
read_dynamic_as_binary file_name read_graph files
	# (ok1,dynamic_header,file,files)
		= open_dynamic_as_binary file_name files;
	| not ok1
		= ((False,default_dynamic_header,{},{},{}),files);
		
	# (ok2,stringtable,file)
		= read_stringtable_as_binary dynamic_header file;
	# (ok3,desctable,file)
		= read_descriptortable_as_binary dynamic_header file;
	# (ok4,graph,file)
		= case read_graph of {
			True	-> read_graph_as_binary dynamic_header file;
			False	-> (True,{},file)
		};
	# (ok5,files)
		= close_dynamic_as_binary file files;
	= ((ok1&&ok2&&ok3&&ok4&&ok5,dynamic_header,graph,stringtable,desctable),files);
	
read_stringtable_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);
read_stringtable_as_binary dynamic_header=:{stringtable_i,stringtable_s} file
	// Read stringtable					
	#! (ok2,file)
		= fseek file stringtable_i FSeekSet;
	#! (stringtable,file)
		= freads file stringtable_s;
	= (ok2,stringtable,file);
	
read_descriptortable_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);
read_descriptortable_as_binary dynamic_header=:{descriptortable_i,descriptortable_s} file
	#! (ok3,file)
		= fseek file descriptortable_i FSeekSet;	
	#! (desctable,file)
		= freads file descriptortable_s;
	= (ok3,desctable,file);
	
read_graph_as_binary :: !.DynamicHeader !*File -> (Bool,.{#Char},!*File);
read_graph_as_binary dynamic_header=:{graph_i,graph_s} file
	#! (ok3,file)
		= fseek file graph_i FSeekSet;	
	#! (graph,file)
		= freads file graph_s;
	= (ok3,graph,file);

