implementation module write_dynamic;

import cg_name_mangling;
import read_dynamic;
import compute_graph;
import dynamics;
import ExtInt;
import DebugUtilities;
from type_io_common import get_type_name_and_module_name_from_type_string;
import DynID;
import StdEnv;
import StdDynamicLowLevelInterface;
import DefaultElem;
import StdMaybe;
import pdExtInt;
import ddState;
import BitSet;
import StdDynamicTypes;

// Layout
SepSpaces	:== "  ";
s_SepSpaces :== 2;			// size of SepSpaces

s_offset_header	:== 8;

write_one_line block_i is_indirection_line i file index_in_desc_addr_table graph markup_commands {block_table,header}
	// offset
	#! file
		= fwrites SepSpaces file;
		
	# bk_offset
		= block_table.[block_i].bk_offset;					

	#! file
		= fwrites (hex_int (i - bk_offset)) file;
	
	// Raw data
	#! file
		= fwrites SepSpaces file;
	#! file
		= fwrites (hex (toInt graph.[i + 0])) file;

	#! file
		= fwritec ' ' file;
	#! file
		= fwrites (hex (toInt graph.[i + 1])) file;
		
	#! file
		= fwritec ' ' file;
	#! file
		= fwrites (hex (toInt graph.[i + 2])) file;
		
	#! file
		= fwritec ' ' file;
	#! file
		= fwrites (hex (toInt graph.[i  + 3])) file;			

	// Prefix
	#! (prefix,partial_arity,expanded_desc_table_o)
		= decode_descriptor_offset header index_in_desc_addr_table i graph;

	#! file
		= fwrites SepSpaces file;
	#! file
		= case is_indirection_line of {
			True
				#! file
					= ljustify_f 6 "" file;
				-> file;				

			False		
				#! prefix_string
					= case prefix of {
						DPREFIX
							#! prefix
								= (toString (bit_n_to_char prefix)) +++ " (" +++ toString partial_arity +++ ")";
							-> prefix;
						_
							-> toString (bit_n_to_char prefix);
						};
				#! file
					= ljustify_f 6 prefix_string file;
				-> file;
			};
		
	// Descriptor
	#! file
		= fwrites SepSpaces file;
	#! (file,markup_commands)
		= case is_indirection_line of {
			True
				#! file
					= ljustify_f 10 "" file;
				-> (file,markup_commands);
			False
				#! (file,markup_commands)
					= case  True /*(DYNAMIC_CONTAINS_BLOCKTABLE header)*/ of {
						True
							#! bk_entries
								= block_table.[block_i].bk_entries;
							#! bk_offset
								= block_table.[block_i].bk_offset;

							#! searched_offset
								= i - bk_offset;
							#! (entry_found,entry_n)
								= look_for_index 0 (size bk_entries) searched_offset bk_entries bk_offset
							| not entry_found <<- ("look_for_index", searched_offset)
								-> (ljustify_f 10 "" file,markup_commands);
								
								#! markup_commands
									= markup_commands

								
								-> (ljustify_f 10 (hex_int_without_prefixed_zeroes entry_n) file,markup_commands);
					};
				-> (file,markup_commands);
		};
		
	#! file
		= fwrites SepSpaces file;
	= (expanded_desc_table_o,file,markup_commands);
where {
	look_for_index i limit searched_offset bk_entries bk_offset
		| searched_offset == 0
			= (True,0);
			= look_for_index2 i limit searched_offset bk_entries bk_offset;
	
	look_for_index2 i limit searched_offset bk_entries bk_offset
		| i == limit
			= (False,0);
		| (bk_entries.[i] - bk_offset) == searched_offset
			= (True,i);
		= look_for_index2 (inc i) limit searched_offset bk_entries bk_offset;
};

write_title file
	#! title
		=	"  Offset    Raw data     Prefix  Entry node  Comment\n";
	#! title_underlined
		= "  --------  -----------  ------  ----------  -------\n";
	
	#! file
		= fwrites title file;
	#! file
		= fwrites title_underlined file;
	= file;

WriteDescriptorAddressTable :: !Int !Int !BinaryDynamic !DescriptorAddressTable !*File -> (!*File,!DescriptorAddressTable);
WriteDescriptorAddressTable max_desc_name max_mod_name dynamic_info=:{descriptor_usage_table,header} /*=:{header={start_fp,descriptortable_s,descriptortable_i},descriptortable,stringtable}*/ desc_table file		
	// Write header		
	#! file 
		= write_header file;
	#! file
		= fwritec '\n' file;
	#! file
		= fwrites title_text file;
	#! file
		= fwritec '\n' file;
	#! file
		= fwrites title_underlined file;
	#! file
		= fwritec '\n' file;
		
	#! (s_desc_table,desc_table)
		= usize_desc_addr_table desc_table;
	#! (file,desc_table)
		= write_entry3 0 s_desc_table desc_table file;
		
	= (file,desc_table);
where {
	
	(binary_dynamic=:{header={graph_s,graph_i,stringtable_i,stringtable_s,descriptortable_i,descriptortable_s},descriptortable,stringtable})
		= dynamic_info;

	write_entry3 i limit desc_table file
		| i == limit
			= (file,desc_table);

		// Offset
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (hex_int (i << 2)) file;
		
		// Raw data
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (hex (toInt descriptortable.[i << 2 + 0])) file;
	
	
		#! file
			= fwritec ' ' file;
		#! file
			= fwrites (hex (toInt descriptortable.[i << 2 + 1])) file;
			
		#! file
			= fwritec ' ' file;
		#! file
			= fwrites (hex (toInt descriptortable.[i << 2 + 2])) file;
			
		#! file
			= fwritec ' ' file;
		#! file
			= fwrites (hex (toInt descriptortable.[i << 2 + 3])) file;
	
		// Descriptor name
		#! file
			= fwrites SepSpaces file;
		#! (descriptor_name,desc_table)
			= desc_table!desc_addr_table.[i].descriptor_name;
		#! descriptor_name
			= expand_special_chars descriptor_name;
		#! file
			= ljustify_f descriptor_name_max descriptor_name file;
			
		// Module name
		#! file
			= fwrites SepSpaces file;
		#! (module_name,desc_table)
			= desc_table!desc_addr_table.[i].DescriptorAddressTableEntry.module_name;
		#! module_name
			= (expand_special_chars module_name);
		#! file
			= ljustify_f module_name_max module_name file;

		// Write prefix
		#! file
			= fwrites SepSpaces file;
		#! (prefix_kind_set,desc_table)
			= desc_table!desc_addr_table.[i].prefixes.prefix_kind_set
		
		#! (prefix_found,first_prefix_bit_n)
			= find_prefix (dec N_PREFIXES) prefix_kind_set;
		#! prefix
			=  (bit_n_to_char first_prefix_bit_n);
		| not prefix_found
			= abort ("WriteDescriptorAddressTable; prefix not found" +++ toString first_prefix_bit_n);
		#! file
			= ljustify_f prefix_size (toString prefix) file;

		// write library instance 			
		#! (date_library_instance_nr_on_disk,desc_table)
			= desc_table!desc_addr_table.[i].date_library_instance_nr_on_disk;
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_library_text (toString date_library_instance_nr_on_disk) file;
			
				
		// write descriptor usage table
		#! file
			= case (DYNAMIC_CONTAINS_BLOCKTABLE header) of {
				True
					#! file
						= fwrites SepSpaces file;
					#! (_,set_string)
						= enum_setSt (\j string -> string +++ "," +++ hex_int_without_prefixed_zeroes j) descriptor_usage_table.[i].bitset "";
					#! set_string
						= "{" +++ set_string % (1,dec (size set_string)) +++ "}";
					#! file
						= fwrites set_string file;
					-> file;
				False
					-> file;
			};

			
		#! file
			= fwritec '\n' file;	
		
		#! file
			= write_prefix (dec first_prefix_bit_n) (descriptor_name,module_name,file) prefix_kind_set
		
		= write_entry3 (inc i) limit desc_table file;
	where {
		write_prefix bit_n (descriptor_name,module_name,file) prefix_kind_set
			#! (prefix_found,bit_n)
				= find_prefix bit_n prefix_kind_set;
			| not prefix_found
				= file;
				
			// convert prefix bit_n to character
			#! prefix
				=  (bit_n_to_char bit_n);

			// write prefix
			#! file
				= fwrites (createArray (prefix_start + size SepSpaces) ' ') file;
			#! file
				= ljustify_f prefix_size (toString prefix) file;

			#! file
				= fwritec '\n' file;
			= write_prefix (dec bit_n) (descriptor_name,module_name,file) prefix_kind_set;
	} // write_entry
		
	// Offset/Raw data
	offset_raw_data_text
		// 12345678						12345678901
		= "Offset  " +++ SepSpaces +++ "Raw data   " +++ SepSpaces;
	offset_raw_data_underlined
		= "--------" +++ SepSpaces +++ "-----------" +++ SepSpaces;
		
	// Descriptor name
	desc_name
		= "Descriptor";
	descriptor_name_max
		= (max max_desc_name (size desc_name));

	descriptor_name_text
		= (ljustify_s descriptor_name_max desc_name) +++ SepSpaces;
	descriptor_name_underlined
		= (createArray descriptor_name_max '-') +++ SepSpaces;
		
	// Module name
	module_name
		= "Module name";
	module_name_max
		= max max_mod_name (size module_name);

	module_name_text
		= (ljustify_s module_name_max module_name) +++ SepSpaces;
	module_name_underlined
		= (createArray module_name_max '-') +++ SepSpaces;
		
	// Prefix
	prefix_text
		= "Prefix" +++ SepSpaces;
	prefix_underlined
		= "------" +++ SepSpaces;
	prefix_size
		= (size prefix_text) - (size SepSpaces);

	s_label_text
		= size label_text;
	label_text
		= if (DYNAMIC_CONTAINS_BLOCKTABLE header) 
			("Block set")
			("Label");
	label_underlined
		= if (DYNAMIC_CONTAINS_BLOCKTABLE header) 
			("---------")
			("-----");
			
	// Library
	s_library_text
		= size library_text1;
	library_text1
		= "Library";
	library_text
		= library_text1 +++ SepSpaces;
	library_underlined
		= "-------" +++ SepSpaces;

	// Title
	title_text
		= SepSpaces +++ offset_raw_data_text +++ descriptor_name_text +++ module_name_text +++ prefix_text +++ library_text +++ label_text;
	title_underlined1
		= SepSpaces +++ offset_raw_data_underlined +++ descriptor_name_underlined +++ module_name_underlined;
	prefix_start
		= (size title_underlined1) - (size SepSpaces);
	title_underlined
		= title_underlined1 +++ prefix_underlined +++ library_underlined +++ label_underlined ;

	ljustify_s :: !Int !String -> String;
	ljustify_s max s
		= {c \\ c <- (ljustify max [ c \\ c <-: s ])};

	write_header file
		#! file
			= fwrites "DESCRIPTOR ADDRESS TABLE\n" file;
		#! file
			= write_entry2 (descriptortable_s >> 2) "entries" file;
		#! file
			= write_entry2 descriptortable_i "relative file pointer" file;
		= file;
} // WriteDescriptorAddressTable

write_entry2 n comment file
	#! file
		= fwrites SepSpaces file;	
	#! file
		= fwrites {c \\ c <- (rjustify s_offset_header [ c \\ c <-: (hex_int_without_prefixed_zeroes n) ])} file;
	#! file
		= fwrites SepSpaces file;
	#! file
		= fwrites comment file;
	#! file
		= fwritec '\n' file;
	= file;

	ljustify_f :: !Int !String !*File -> *File;
	ljustify_f max1 s file
		| max1 == size s
			= fwrites s file;
			
		#! file
			= fwrites s file;
		| (max1 - (size s)) < 1
			= abort ("!max1: " +++ toString max1 +++ " " +++ toString (size s))
		#! file
			= fwrites (createArray (max1 - (size s)) ' ') file;
		= file;
	
WriteHeader :: !BinaryDynamic !*File -> *File;
WriteHeader dynamic_info=:{header} file
	#! start_fp
		= 0;			// start in dynamic file of header
	#! size1
		= 0;
	#! file
		= fwrites "HEADER\n\n" file;
	#! file
		= write_entry2 header.version_number "version number" file;


	// graph
	#! file
		= write_entry2 (start_fp + header.graph_i) "graph file pointer start" file;
	#! file
		= write_entry2 header.graph_s "graph size" file;
		
	// blocktable
	#! file
		= case (DYNAMIC_CONTAINS_BLOCKTABLE header) of {
			True
				#! file
					= write_entry2 (start_fp + header.block_table_i) "block table file pointer start" file;
				#! file
					= write_entry2 (header.block_table_s) "blocktable size" file;
				-> file;
			False
				-> file;
		};
	
	// stringtable
	#! file
		= write_entry2 (start_fp + header.stringtable_i) "stringtable file pointer start" file;
	#! file
		= write_entry2 header.stringtable_s "stringtable size" file;
		
	//descriptortable
	#! file
		= write_entry2 (start_fp + header.descriptortable_i) "descriptortable file pointer start" file;
	#! file
		= write_entry2 header.descriptortable_s "descriptortable size" file;
		
	// n_nodes
	#! file
		= write_entry2 header.n_nodes "graph nodes" file;

	//descriptortable
	#! file
		= write_entry2 (start_fp + header.descriptor_bitset_i) "descriptor bitset file pointer start" file;
	#! file
		= write_entry2 header.descriptor_bitset_s "descriptor bitset size" file;
	= file;
	
WriteStringTable :: !BinaryDynamic !*File -> *File;
WriteStringTable dynamic_info file
	#! file
		= fwrites ("STRING TABLE\n") file;

	#! file
		= write_entry2 stringtable_s "total size" file;
	#! file
		= write_entry2 stringtable_i "relative file pointer" file;
	#! file
		= fwritec '\n' file;
				
	#! raw_data_text
		= "Raw data";
	#! ascii_text
		= "Ascii";
	#! offset_text
		= "Offset"
	#! title
		= SepSpaces +++ offset_text +++ createArray (8 - (size offset_text)) ' ' +++ SepSpaces +++ raw_data_text +++ createArray (hex_line * 3 - (size raw_data_text) + 1) ' ' +++ ascii_text;
	#! title_underlined
		= SepSpaces +++ createArray 8 '-' +++ SepSpaces +++ createArray (hex_line * 3 - 1) '-' +++ SepSpaces +++ createArray hex_line '-';
	#! file 
		= fwrites title file;
	#! file
		= fwritec '\n' file;
	#! file 
		= fwrites title_underlined file;
	#! file
		= fwritec '\n' file;
		
	#! file
		= write_string_table 0 (createArray hex_line ' ') file;
	= file;
where {
	(binary_dynamic=:{header={graph_s,graph_i,stringtable_i,stringtable_s,descriptortable_i,descriptortable_s},stringtable})
		= dynamic_info;
	start_fp
		= 0;
 
	hex_line = 16; 				// 12 bytes per line

	write_string_table :: !Int !*{Char} !*File -> *File;
	write_string_table i buffer file
		| i == stringtable_s
			= file;
		
		// write offset
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (hex_int i) file;
			
		#! file
			= fwritec ' ' file;
	
		// write one hex line	
		#! (i,buffer,file)
			= write_one_hex_line 0 i buffer file;
		= write_string_table i buffer file;		
	where {
		write_one_hex_line :: !Int !Int !*{Char} !*File -> (!Int,!*{Char},!*File);
		write_one_hex_line j i buffer file
			| (j == hex_line) || (i == stringtable_s)
				#! file
					= fwrites (createArray ((hex_line - j) * 3 + (size SepSpaces)) ' ') file;
				#! (buffer,file)
					= write_buffer 0 j buffer file;
					
				#! file
					= fwritec '\n' file;
				= (i,buffer,file);

			#! file
				= fwritec ' ' file;
			#! c
				= stringtable.[i];
			#! file
				= fwrites (hex (toInt c)) file;
				
			= write_one_hex_line (inc j) (inc i) { buffer & [j] = c } file;
		where {
			write_buffer i limit buffer file
				| i == limit
					= (buffer,file);
					
				#! (c,buffer) = buffer![i]
				#! file
					= fwritec (if (isPrint c) c '.') file;
				= write_buffer (inc i) limit buffer file;			
		} // write_one_hex_line
	} // write_string_table
}

// ----------------------------------------------------------------------------------------
import ExtArray;
import RWSDebugChoice;
import utilities;

instance toString Child
where {
	toString (Internal True child_node_i)	= "@" +++ toString child_node_i;
	toString (External True child_node_i)	= "*" +++ toString child_node_i;
	toString _								= "??";

};

create_string :: [String] -> String;
create_string []
	= "";
create_string l
	| False <<- ("&&&",l)
		= undef; 
	# x = count_string_size l 0;
	# s
		= createArray (x) ' ';
	| False <<- ("create_string",x)
		= undef;
	= collect_strings 0 l s;
where {
	count_string_size [] size1
		= size1;
	count_string_size [x:xs] size1
		= count_string_size xs (size1 + size x);
		
	collect_strings _ [] s
		= s;
	collect_strings i [x:xs] s
		# s_x
			= size x;
		# s
			= { s & [i+j] = x.[j] \\ j <- [0..dec s_x] };
		= collect_strings (i + s_x) xs s;
};
 
convert_node node=:{graph_index, info=Record r0 r1 r2 r3	(record_info=:{ri_descriptor_name,ri_args}),children}
	#! record_info
		= { record_info &
			ri_args.rai_n_boxed_args	= length children 			
		};
	#! node 
		= { node &
			info = Record r0 r1 r2 r3 record_info
		,	children = reversed_children
		};
	= node;
where {
	reversed_children
		= reverse children;
};		

convert_node node=:{graph_index, info=ArrayNode r0 r1 r2 r3	(array_info=:{ai_element_descriptor}),children}
	# node
		= case ai_element_descriptor of {
			AED_Invalid
				-> abort "convert_node; invalid array descriptor";
			AED_Boxed
				#! record_args_info
					= { { default_elem & rai_n_boxed_args = length children} };
				#! array_info
					= { array_info & ai_record_args_info = record_args_info };
				#! node 
					= { node & 
						info = ArrayNode r0 r1 r2 r3 array_info
					,	children = reversed_children
					};
				-> node;
			AED_BasicValue _
				-> node;
			AED_Record _
				-> node;
		};
	= node;
where {
	reversed_children
		= reverse children;
}
	
convert_node node=:{children}
	= {node & children = reverse children };

to_string_unboxed_record_arg _ _ (BV_Int int) (node_index_in_string,strings)
	#! strings
		= { strings & [node_index_in_string] = toString int +++ " (Int)" };
	= (inc node_index_in_string,strings);
to_string_unboxed_record_arg is_unboxed_value_record ith_bool (BV_Bool bool) (node_index_in_string,strings)
	| is_unboxed_value_record
		#! (string,strings)
			= strings![node_index_in_string];
		#! strings
			= { strings & [node_index_in_string] = string +++ toString bool +++ " "};
		#! node_index_in_string
			= if ((ith_bool rem 4) == 3) (inc node_index_in_string) node_index_in_string;
		= (node_index_in_string,strings);

		#! strings
			= { strings & [node_index_in_string] = toString bool +++ " (Bool)" };
		= (inc node_index_in_string,strings);

to_string_unboxed_record_arg is_unboxed_value_record ith_bool (BV_Char char) (node_index_in_string,strings)
	| is_unboxed_value_record
		#! (string,strings)
			= strings![node_index_in_string];
		#! strings
			= { strings & [node_index_in_string] = string +++ "'" +++ toString char +++ "' "};
		#! node_index_in_string
			= if ((ith_bool rem 4) == 3) (inc node_index_in_string) node_index_in_string;
		= (node_index_in_string,strings);

		#! strings
			= { strings & [node_index_in_string] = toString char +++ " (Char)" };
		= (inc node_index_in_string,strings);

to_string_unboxed_record_arg _ _ (BV_Real real) (node_index_in_string,strings)
	#! strings
		= { strings & [node_index_in_string] = toString real +++ " (Real)" };
	= (node_index_in_string + 2,strings);
	
to_string_unboxed_record_arg _ _ k _
	| True <<- ("to_string_unboxed_record_arg",k)
	= abort "to_string_unboxed_record_arg";

import runtime_system;

find_internal_node node_offset node_i node=:{graph_index}
	| node_offset <> graph_index
		= Nothing;
		= Just node_i;

node_index_to_string node_i
	= "@" +++ toString node_i;

import typetable;
import type_io_read;

:: *LazyDynamic
	= {
		ld_dynamic_info			:: !DynamicInfo
	,	ld_type_table			:: !*{*TypeTable}
	};
	
instance DefaultElemU LazyDynamic
where {
	default_elemU
		= {
			ld_dynamic_info			= default_elem
		,	ld_type_table			= {}
		};	
};
	
read_type_table i type_name (type_tables,files)
	# (ok,rti,tio_common_defs,type_io_state,names_table,files)
		= read_type_information_new False (ADD_TYPE_LIBRARY_EXTENSION type_name) {} files;

	// create new type table
	# new_type_table
		= { default_type_table &
			tt_type_io_state		= type_io_state
		,	tt_tio_common_defs		= { x \\ x <-: tio_common_defs }
		,	tt_n_tio_common_defs	= size tio_common_defs
		,	tt_rti					= rti
		};
		
	#! type_tables
		= { type_tables & [i] = new_type_table };
	= (type_tables,files);

WriteDynamicInfo :: !.DynamicInfo !*File !*Files -> (!*File,!*Files);
WriteDynamicInfo bd_dynamic_info=:{di_disk_type_equivalent_classes,di_library_instance_to_library_index,di_library_index_to_library_name,di_lazy_dynamics_a,di_type_redirection_table} file files
	// Library instance table
	#! file
		= fwrites ("\nLIBRARY INSTANCE TABLE (format: lazy(library_instance_i,lazy_dynamic_index))\n\n") file;
	#! file
		= fwrites title file;
	#! file
		= fwrites title_underlined file;
		
	#! file
		= mapAiStS print_library_instance di_library_instance_to_library_index file RTID_DISKID_RENUMBER_START;
	#! file
		= fwritec '\n' file;

	// Library String Table
	#! file
		= fwrites ("\nLIBRARY STRING TABLE\n\n") file;
	#! file
		= fwrites title2 file;
	#! file
		= fwrites title2_underlined file;
	#! file
		= mapAiSt (print_library_name s_library_string_table_index) di_library_index_to_library_name file;
	#! file
		= fwritec '\n' file;
	
	// External Dynamics Table
	#! file
		= case (size di_lazy_dynamics_a) of {
			0
				-> file;
			_
				#! file
					= fwrites ("\nLAZY DYNAMICS TABLE\n\n") file;
				#! file
					= fwrites title3 file;
				#! file
					= fwrites title3_underlined file;
				#! file
					= mapAiSt (print_library_name s_dynamic_index_name) di_lazy_dynamics_a file;
				#! file
					= fwritec '\n' file;
				-> file;
		};

	// TYPE EQUIVALENT CLASSES ...; read type tables from main dynamic
	#! type_tables
		= to_help_the_type_checker { default_type_table \\ _ <- [1.. (size di_library_index_to_library_name)] };
	#! (type_tables,files)
		= mapAiSt read_type_table di_library_index_to_library_name (type_tables,files);

	// print type tables
	#! (file,type_tables)
		= case (size di_disk_type_equivalent_classes == 0) of {
			False
				// title
				#! file
					= fwrites ("\nTYPE EQUIVALENT CLASSES\n\n") file;
				#! file
					= fwrites title4 file;
				#! file
					= fwrites title4_underlined file;

				#! (type_tables,file)
					= mapAiSt print_type_equivalent_class di_disk_type_equivalent_classes (type_tables,file);
					
				#! file
					= fwrites "\n\n" file;
				-> (file,type_tables);
			_
				-> (file,type_tables);
		};
	// ... TYPE EQUIVALENT CLASSES

	= (file,files);
where {
	to_help_the_type_checker :: {#TypeTable} -> {#TypeTable};
	to_help_the_type_checker i = i;

	print_type_equivalent_class i type_equations (type_tables,file)
		| size type_equations < 2
			= abort "print_type_equivalent_class: internal error; type equivalent table-entry must at least have two types in it";
			
		// write
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_dynamic_index_name (toString i) file;
			
		#! (type_name,type_tables)
			= get_type_name type_equations.[0] type_tables;
		#! file 
			= fwrites (SepSpaces +++ type_name +++ ":") file;
			

		// print eager type equations
		#! file
			= fwrites " {" file;
		# (type_tables,_,file)
			= mapAiSt filter_eager_type_equation type_equations (type_tables,False,file);
		#! file
			= fwritec '}' file;
			
		#! file
			= fwrites " - " file;
			
		// print lazy type equations
		#! file
			= fwrites "{" file;
		# (type_tables,_,file)
			= mapAiSt filter_lazy_type_equation type_equations (type_tables,False,file);
		#! file
			= fwritec '}' file;
			
		#! file
			= fwritec '\n' file;

		= (type_tables,file);
	where {
		filter_eager_type_equation i t=:(LIT_TypeReference (LibRef _) _) s
			= print_type_equation i t s;
		filter_eager_type_equation i _ s
			= s;
			
		filter_lazy_type_equation i _ s
			= s;
	}
		
	get_type_name (LIT_TypeReference library_instance_reference tio_type_reference=:{tio_type_without_definition,tio_tr_module_n,tio_tr_type_def_n}) type_tables
		# maybe_type_table_i
			= case library_instance_reference of {
				LibRef disk_library_instance_i
					| not (isTypeWithoutDefinition tio_type_reference)
						# type_table_i
							= get_index_in_di_library_index_to_library_name di_library_instance_to_library_index.[disk_library_instance_i];
						-> Just type_table_i;
						-> Nothing;
			};

		# (type_name,type_tables)
			= case maybe_type_table_i of {
				Just type_table_i
					-> get_type_name_from_type_tables tio_tr_type_def_n tio_tr_module_n type_table_i type_tables;
				Nothing
					-> (fromJust tio_type_without_definition,type_tables)
			};
		= (type_name,type_tables);
						
	get_type_name_from_type_tables dtr_tr_type_def_n dtr_tr_module_n type_table_i type_tables
		#! (tio_td_name,type_tables)
			= type_tables![type_table_i].tt_tio_common_defs.[dtr_tr_module_n].tio_com_type_defs.[dtr_tr_type_def_n].tio_td_name;
		#! (tis_string_table,type_tables)
			= type_tables![type_table_i].tt_type_io_state.tis_string_table;
		#! type_name
			= get_name_from_string_table tio_td_name tis_string_table;
		= (type_name,type_tables);

	get_module_name_from_type_tables {tio_type_without_definition=Just s} type_table_i type_tables
		# (type_name,module_name)
			= get_type_name_and_module_name_from_type_string s
		= (module_name,type_tables);

	get_module_name_from_type_tables {tio_tr_module_n=dtr_tr_module_n} type_table_i type_tables
		#! (tio_module,type_tables)
			= type_tables![type_table_i].tt_tio_common_defs.[dtr_tr_module_n].tio_module;
		#! (tis_string_table,type_tables)
			= type_tables![type_table_i].tt_type_io_state.tis_string_table;
		#! module_name
			= get_name_from_string_table tio_module tis_string_table;
		= (module_name,type_tables);
		
	print_type_redirection i type_reference (type_tables,file)
		// write
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_dynamic_index_name (toString i) file;

		#! file
			= fwrites SepSpaces file;
		#! (type_name,type_tables)
			= get_type_name type_reference type_tables;

		#! file
			= fwrites type_name file;
		#! file
			= fwrites " " file;
		#! (type_tables,_,file)
			= print_type_equation i type_reference (type_tables,False,file)

			
		#! file
			= fwritec '\n' file;

		= (type_tables,file);
			
	print_type_equation i (LIT_TypeReference (LibRef disk_library_instance_i) tio_type_reference=:{tio_type_without_definition,tio_tr_module_n,tio_tr_type_def_n}) (type_tables,first_type_equation_printed,file)
		#! file
			= case (not first_type_equation_printed) of { 
				True	-> fwrites "(" file;
				_		-> fwrites ",(" file;
			};
			
		#! (module_name,type_tables)
			= case tio_type_without_definition of {
				Nothing
					// The type equivalent equations may not contain predefined types without definition because they will
					// be mapped to a shared library instance which contains among other things the run-time system which
					// provides the definitions for these types.
					# type_table_i
						= get_index_in_di_library_index_to_library_name di_library_instance_to_library_index.[disk_library_instance_i];
			
					# (module_name,type_tables)
						= get_module_name_from_type_tables tio_type_reference type_table_i type_tables;
					-> (module_name,type_tables);
				Just type_name
					-> (type_name,type_tables);
			};
		
		#! file
			= fwrites module_name file;
		#! file
			= fwrites ("," +++ toString disk_library_instance_i +++ ")") file;
		= (type_tables,first_type_equation_printed,file);

	print_library_name s_column1 library_name_index library_name file
		// write library stringtable index			
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_column1 (toString library_name_index) file;
			
		// write library string
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (FILE_IDENTIFICATION (extract_dynamic_or_library_identification library_name) library_name) file;
	
		#! file
			= fwritec '\n' file;

		= file;
	
	print disk_library_instance_i maybe_library_name_index comments file
		// write library instance number
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_library_instance (toString disk_library_instance_i) file;

		// write library stringtable index			
		#! file
			= fwrites SepSpaces file;
		#! file
			= ljustify_f s_library_string_table_index (if (isNothing maybe_library_name_index) "" (fromJust maybe_library_name_index)) file;
			
		// write comments
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites comments file;

		#! file
			= fwritec '\n' file;
		= file;
		
	print_library_instance disk_library_instance_i (LIK_LibraryInstance {LIK_LibraryInstance | lik_index_in_di_library_index_to_library_name}) file
		# library_name 
			= di_library_index_to_library_name.[lik_index_in_di_library_index_to_library_name];
		# comments 
			= FILE_IDENTIFICATION (extract_dynamic_or_library_identification library_name) library_name;
		# file
			= print disk_library_instance_i (Just (toString lik_index_in_di_library_index_to_library_name)) comments file
	
		= file;

	s_library_instance
		= size library_instance;
	library_instance
		= "Instance";
	library_instance_underlined
		= "--------";
		
	s_library_string_table_index
		= size library_string_table_index;
	library_string_table_index
		= "String table index";
	library_string_table_index_underlined
		= "------------------";	
		
	s_library_name
		= size library_name;
	library_name
		= "Library name";
	library_name_underlined 
		= "------------";
		
	s_dynamic_index_name
		= size dynamic_index_name;
	dynamic_index_name
		= "Index";
	dynamic_index_underlined
		= "-----";
		
	s_external_dynamic_name
		= size external_dynamic_name;
	external_dynamic_name
		= "Name";
	external_dynamic_name_underlined
		= "----";
		
	s_type_equivalent_class_name
		= size type_equivalent_class_name;
	type_equivalent_class_name
		= "Type name: (module name,ith library instance) - (module name,ith library instance,lazy dynamic index)";
	type_equivalent_class_name_underlined
		= "-----------------------------------------------------------------------------------------------------";
			
	s_type_redirection
		= size type_redirection;
	type_redirection
		= "Type redirection";
	type_redirection_underlined
		= "----------------";
		
	s_comments_name
		= size comments_name;
	comments_name
		= "Comments";
	comments_name_underlined
		= "--------";

	title 
		= SepSpaces +++ library_instance +++ SepSpaces +++ library_string_table_index +++ SepSpaces +++ comments_name +++ "\n";
	title_underlined
		= SepSpaces +++ library_instance_underlined +++ SepSpaces +++ library_string_table_index_underlined +++ SepSpaces +++ comments_name_underlined +++ "\n";
		
	title2
		= SepSpaces +++ library_string_table_index +++ SepSpaces +++ library_name +++ "\n";
	title2_underlined
		= SepSpaces +++ library_string_table_index_underlined +++ SepSpaces +++ library_name_underlined +++ "\n";
		
	title3
		= SepSpaces +++ dynamic_index_name +++ SepSpaces +++ external_dynamic_name +++ "\n";
	title3_underlined
		= SepSpaces +++ dynamic_index_underlined +++ SepSpaces +++ external_dynamic_name_underlined +++ "\n";
		
		
	title4
		= SepSpaces +++ dynamic_index_name +++ SepSpaces +++ type_equivalent_class_name +++ "\n";
	title4_underlined
		= SepSpaces +++ dynamic_index_underlined +++ SepSpaces +++ type_equivalent_class_name_underlined +++ "\n";
		
	title5
		= SepSpaces +++ dynamic_index_name +++ SepSpaces +++ type_redirection +++ "\n";
	title5_underlined
		= SepSpaces +++ dynamic_index_underlined +++ SepSpaces +++ type_redirection_underlined +++ "\n";		

};

force_bool_array :: !*{*{#Bool}} -> *{*{#Bool}};
force_bool_array i
	= i;
	
force_string_array :: !*{*{#{#Char}}} -> *{*{#{#Char}}};
force_string_array i
	= i;

WriteGraph :: !*DescriptorAddressTable !BinaryDynamic *(Nodes NodeKind) !*File !*DDState -> *(*Nodes NodeKind,!*File,!*DescriptorAddressTable,!*DDState);
WriteGraph desc_table=:{root_nodes} dynamic_info=:{header={graph_i,graph_s},graph,block_table,bd_dynamic_info={di_lazy_dynamics_a}} nodes file ddState=:{e__StdDynamic__rDynamicTemp}
	// to be moved; general
	#! (nodes_a,nodes)
		= get_nodes nodes;
	#! nodes_a
		= { convert_node node \\ node <-: nodes_a };
				
	// specific for writegraph
	#! nodes
		= { nodes & nodes = nodes_a };

	// header ...
	#! file
		= fwrites ("ENCODED GRAPH\n") file;

	#! file
		= write_entry2 graph_s "total size" file;
	#! file
		= write_entry2 graph_i "relative file pointer" file;
	#! file
		= fwritec '\n' file;
	#! file
		= write_title file;
	// ... header
	
	# n_blocks
		= size block_table;
	# block_strings
		= force_string_array  { {} \\ _ <- [1..n_blocks] };

	# line_is_node_start
		= force_bool_array { {} \\ _ <- [1..n_blocks] }; 
	# indirections
		= force_bool_array { {} \\ _ <- [1..n_blocks] };
	
	# (block_strings,line_is_node_start,indirections,nodes,markup_nodes)
		= loopAst convert_block_to_readable_string (block_strings,line_is_node_start,indirections,nodes,[]) n_blocks;

	# (file,desc_table,nodes)
		= mapAiSt (write_block line_is_node_start indirections) block_strings (file,desc_table,nodes);
		
	= (nodes,file,desc_table,ddState);
where {
	write_block line_is_node_start indirections block_i block_string (file,desc_table,nodes)
		# file
			= fwrites ("\nBlock: " +++ toString block_i +++ "\n") file;
			
		# (file,desc_table,nodes)
			= mapAiSt write_line block_string (file,desc_table,nodes);
		= (file,desc_table,nodes) ;
	where {
		write_line ith_line string (file,desc_table,nodes)
			#! (index_in_desc_addr_table,desc_table)
				= desc_table!indices_array.[block_i];
				
			#! extra
				= not line_is_node_start.[block_i].[ith_line];
				
			#! graph_offset
				= (bk_offset + (ith_line << 2));
			#! (_,file,_)
				= write_one_line block_i extra graph_offset file index_in_desc_addr_table graph [] dynamic_info;
			# (file,nodes)
				= case string of {
					""	
						| indirections.[block_i].[ith_line]
							#! reference
								= FromStringToInt graph graph_offset;
							| is_internal_reference reference
								# reference_relative_to_block_start
									= dereference_internal_reference (graph_offset - bk_offset) reference;
									
								#! (nodes1,nodes)
									= get_nodes nodes;
								#! (start_node_i,end_node_i)
									= root_nodes.[block_i];
									
								#! (maybe_node_i,nodes1)
									= findAieuSE (find_internal_node reference_relative_to_block_start) start_node_i (inc end_node_i) nodes1;
								| isNothing maybe_node_i
									-> (fwrites ("CORRUPT: internal reference to ?? \n") file,nodes);
									
									
								#! node_i
									= fromJust maybe_node_i;
								#! nodes
									= { nodes & nodes = nodes1 };
								-> (fwrites ("internal reference to " +++ node_index_to_string node_i +++ "\n") file,nodes);

								#! indirection_text
									= "external reference to block " +++ hex_int_without_prefixed_zeroes (get_block_i reference)
									+++ " with entry node " +++ hex_int_without_prefixed_zeroes (get_en_node_i reference) +++ "\n";
								-> (fwrites indirection_text file,nodes);
							
							// no indirection; just empty
							-> (fwritec '\n' file,nodes);
					_	-> (fwrites (string +++ "\n") file,nodes);
				};
			= (file,desc_table,nodes);
			
		bk_offset
				= block_table.[block_i].bk_offset;					
	};
	
	convert_block_to_readable_string block_i s=:(block_strings,line_is_node_start,indirections,nodes,markup_nodes)
		| False <<- ("???",block_i)
			= undef;

		#! bk_size
			= block_table.[block_i].bk_size;
		| False <<- ("convert_block_to_readable_string",block_i,bk_size >> 2)
			= undef;


		#! string 
			= createArray (bk_size >> 2) ""; 
		| False <<- ("aaaa",size string, bk_size)
			= undef;	
		#! line_is_node_start_for_block_i 
			= createArray (bk_size >> 2) False;	
		#! indirection
			= createArray (bk_size >> 2) True;

		#! (start_node,end_node)
			= root_nodes.[block_i];

		#! (string,line_is_node_start_for_block_i,indirection,nodes)
			= foldSt (line_print bk_size) [start_node..end_node] (string,line_is_node_start_for_block_i,indirection,nodes);
			
		#! indirections
			= { indirections & [block_i] = indirection };
		#! line_is_node_start
			= { line_is_node_start & [block_i] = line_is_node_start_for_block_i };
			
		#! (s_string,string)
			= usize string;

		#! block_strings
			= { block_strings & [block_i] = string };
		= (block_strings,line_is_node_start,indirections,nodes,markup_nodes);
	where {
		get_nodes_size nodes1=:{nodes}
			# (size,nodes)
				= usize nodes;
			= (size,{nodes1 & nodes = nodes});
			
		({bk_offset,bk_size})
			= block_table.[block_i]; 			

		line_print bk_size node_i (string,line_is_node_start_for_block_i,indirection,nodes)
			# (s_nodes,nodes)
				= get_nodes_size nodes;
			| not (between 0 node_i (dec s_nodes)) <<- ("line_print",node_i)
				= abort ("line_print; invalid range " +++ toString node_i +++ " in 0 - " +++ toString (dec s_nodes));
				
			# (node=:{graph_index},nodes)
				= nodes!nodes.[node_i];
			| graph_index == (-1) <<- ("graph_index",graph_index)
				= (string,line_is_node_start_for_block_i,indirection,nodes);

			# node_index_in_string
				= graph_index >> 2;
				
			| not (between 0 graph_index (dec bk_size))
				= abort "line_print: block is corrupt";

			// mark as node start
			# line_is_node_start_for_block_i
				= { line_is_node_start_for_block_i & [node_index_in_string] = True };
			# (string,indirection)
				= case node.info of {
					NK
						-> (string,indirection);
					_
						
						#! (end_node_index_in_string,string)
							= to_string node_index_in_string node string;
						| False <<- ("-- ",node_index_in_string,size string,end_node_index_in_string)
							-> undef;

						// test...
						#! (s_indirection,indirection)
							= usize indirection;
						| not ((between 0 node_index_in_string (dec s_indirection)) && (between 0 (dec end_node_index_in_string) (dec s_indirection)))
							-> abort ("kdkd" +++ toString end_node_index_in_string +++ toString s_indirection);
						// ...test
													
						#! indirection
							= { indirection & [line_i] = False \\ line_i <- [node_index_in_string..dec end_node_index_in_string] };

						-> (string,indirection);	
				};
			= (string,line_is_node_start_for_block_i,indirection,nodes);
		where {
			prefix_string graph_index
				= node_index_to_string node_i +++ ": ";
			
			to_string node_index_in_string {info=IntLeaf _ (BV_Int int),graph_index} strings
				#! strings
					= { strings & 
						[node_index_in_string] = prefix_string graph_index +++ "Int" 
					,	[node_index_in_string + 1]	 = toString int
					};

				= (node_index_in_string + 2,strings);
			to_string node_index_in_string {info=CharLeaf _ (BV_Char chartje),graph_index} strings
				#! strings
					= { strings & 
						[node_index_in_string] = prefix_string graph_index +++ "Char" 
					,	[node_index_in_string + 1]	 = toString chartje
					};
				= (node_index_in_string + 2,strings);
			to_string node_index_in_string {info=RealLeaf _ (BV_Real realtje),graph_index} strings
				#! strings
					= { strings & 
						[node_index_in_string] = prefix_string graph_index +++ "Real"
					,	[inc node_index_in_string] = toString realtje
					};
				= (node_index_in_string + 3,strings);
			to_string node_index_in_string {info=BoolLeaf _ (BV_Bool bool),graph_index} strings
				#! strings
					= { strings & 
						[node_index_in_string] = prefix_string graph_index +++ "Bool"
					,	[node_index_in_string + 1]	 = toString bool
					};
				= (node_index_in_string + 2,strings);
			to_string node_index_in_string {children,info=Closure _ {ci_closure_name,ci_is_build_lazy_block,ci_args={rai_unboxed_args}},graph_index} strings
				#! children_string
					= map (\k -> " " +++ toString k) children;
				#! strings
					= { strings & [node_index_in_string] = prefix_string graph_index +++  
						(if (size rai_unboxed_args == 0) "Closure '" 
						("Unboxed closure " +++ toString (size rai_unboxed_args) +++ " '")				
						)
						 +++ toString ci_closure_name +++ "'" +++ create_string children_string};
						  
				#! (is_lazy_block,node_index,dynamic_index)
					= isBuildLazyBlock ci_is_build_lazy_block;
				| is_lazy_block
					| not (between 0 dynamic_index (dec (size di_lazy_dynamics_a)))
						= abort "to_string (Closure): dynamic is corrupt";
					#! strings
						= { strings & 
							[node_index_in_string + 1] = "Block: " +++ toString (get_block_i node_index) +++ ", entry: " +++ toString (get_en_node_i node_index)
						,	[node_index_in_string + 2] = "Dynamic index: " +++ toString dynamic_index +++ " '" +++ di_lazy_dynamics_a.[dynamic_index] +++ "'"
						};
					= (node_index_in_string + 3,strings);
					
				#! strings 
					= foldSt (\i strings -> {strings & [node_index_in_string + i] = f (rai_unboxed_args.[dec i]) } ) [1..size rai_unboxed_args] strings;
				with {
					f (BV_Unknown i)	= toString i +++ " (Unknown type)";
				}
				= (node_index_in_string + 1 + size rai_unboxed_args,strings);
			to_string node_index_in_string {children,info=Record _ _ _ _ {ri_descriptor_name,ri_args},graph_index} strings
				| False <<- ("Record", children)
					= undef;
				// 
				#! (n_unboxed_args,n_boxed_args)
					= (size ri_args.rai_unboxed_args, ri_args.rai_n_boxed_args);
			
				// create node_string
				#! children_string
					= map (\k -> " " +++ toString k) children;
				#! node_string
					= prefix_string graph_index +++ ri_descriptor_name +++ create_string children_string // +++ " >>" +++ toString n_unboxed_args +++ " " +++ toString n_boxed_args;
				#! strings
					= { strings & [node_index_in_string] = node_string };
					
				#! (node_index_in_string_end_unboxed_args,strings)
					= mapAiSt (to_string_unboxed_record_arg False) ri_args.rai_unboxed_args (inc node_index_in_string,strings);
				= (node_index_in_string_end_unboxed_args,strings);
				
				// Node
			to_string node_index_in_string {info=StringLeaf _ _ {si_string},graph_index} strings
				#! strings
					= { strings & 
						[node_index_in_string]		 = prefix_string graph_index +++ "String" 
					,	[node_index_in_string + 1]	 = toString (size si_string)
					,	[node_index_in_string + 2]	 = "'" +++ si_string +++ "'"
					};
				= (node_index_in_string + 2 /* ERROR */ + ((roundup_to_multiple (size si_string) ALIGNMENT) >> 2),strings);
			to_string node_index_in_string {info=Dynamic _ _ _ _ _} strings
				= abort "dynamics are not recognised";
			to_string node_index_in_string {children,info=ArrayNode _ _ _ _ {ai_n_elements,ai_element_descriptor,ai_record_args_info},graph_index} strings
				| False <<- ("ArrayNode")
					= undef;
				#! children_string
					= map (\k -> " " +++ toString k) children;
				#! node_string
					= prefix_string graph_index +++ "Array"  +++ create_string children_string 
				#! strings
					= { strings & [node_index_in_string] = node_string };
				#! strings
					= { strings & [inc node_index_in_string] = "size: " +++ toString ai_n_elements};
				#! strings
					= { strings & [node_index_in_string + 2] = "element: " +++ toString ai_element_descriptor};
					
				// print all unboxed arguments
				#! is_unboxed_value_record
					= case ai_element_descriptor of {
						AED_BasicValue	_	-> True;
						_					-> False;
					};
				#! (node_index_in_string,strings)
					= mapASt (to_string_unboxed_records is_unboxed_value_record) ai_record_args_info (node_index_in_string + 3,strings);
				= (node_index_in_string,strings);
			where {
				to_string_unboxed_records is_unboxed_value_record record_args_info (node_index_in_string,strings)
					#! (node_index_in_string,strings)
						= mapAiSt (to_string_unboxed_record_arg is_unboxed_value_record) record_args_info.rai_unboxed_args (node_index_in_string,strings);
					= (node_index_in_string,strings);
			};
		}; // line_print
	}
};

instance toString ArrayElementDescriptor
where {
	toString (AED_BasicValue basic_value_kind)	= toString basic_value_kind;
	toString (AED_Record descriptor_name)		= descriptor_name;
	toString AED_Boxed							= "Boxed";
};

instance toString BasicValueKind
where {
	toString BVK_Int	= "Int";
	toString BVK_Real	= "Real";
	toString BVK_Bool	= "Bool";
};

decode_descriptor_offset :: !DynamicHeader !{#Int} !Int !{#Char} -> (Int,Int,Int);	
decode_descriptor_offset header indices graph_o graph
//	| F ("graph_o: " +++ toString graph_o +++ " size graph: " +++ toString (size graph)) True
	# (prefix,partial_arity,expanded_desc_table_o)
		= decode_descriptor_offset2 graph_o graph;
	# expanded_desc_table_o
		= if (DYNAMIC_CONTAINS_BLOCKTABLE header) indices.[expanded_desc_table_o] expanded_desc_table_o;
	= (prefix,partial_arity,expanded_desc_table_o);

check :: !.a -> .a;
check i
	| F "Check" True
		= i;	
		
WriteBlockTable :: !BinaryDynamic !*File -> *File;
WriteBlockTable dynamic_info=:{header={block_table_i,block_table_s},block_table,graph,block_table_as_string} file
	| not (DYNAMIC_CONTAINS_BLOCKTABLE dynamic_info.header)
		= file;
		
	#! file
		= write_header file;
		
	#! (offset,file)
		= write_entry 0 ("number of blocks " +++ hex_int_without_prefixed_zeroes ( FromStringToInt block_table_as_string 0) ) file;
	#! file
		= fwritec '\n' file;
		
	#! file
		= loop offset block_table_s file;
	= file;
where {
	loop offset limit file
		| offset == limit
			= file;
			
		#! block_i
			= FromStringToInt block_table_as_string offset;
		#! bk_offset
			= block_table.[block_i].bk_offset
			
		#! (offset,file)
			= write_entry offset ("Block " +++ hex_int_without_prefixed_zeroes block_i) file; 
		#! (offset,file)
			= write_entry offset ("Block starts at " +++ hex_int_without_prefixed_zeroes bk_offset) file;
		#! (offset,file)
			= write_entry offset ("Block size " +++ hex_int_without_prefixed_zeroes block_table.[block_i].bk_size) file;

		#! bk_entries
			= block_table.[block_i].bk_entries;


		#! (offset,file)
			= write_entry offset ("Node entries: "  +++ 
				(hex_int_without_prefixed_zeroes ((if ((size bk_entries) == 0) 1 0) +  block_table.[block_i].bk_n_node_entries))) file;
			
		#! (offset,file)
			= case ((size bk_entries) == 0) of {
				True	->	(offset,file);
				False	->	write_entry_node_offsets 0 (size bk_entries) offset file bk_entries bk_offset;
			};
			
		#! file
			= fwritec '\n' file;
			
			
		= loop offset limit file;
		
	write_entry_node_offsets i limit offset file bk_entries bk_offset
		| i == limit
			= (offset,file);
			
		#! (offset,file)
			= write_entry offset ("Entry node " 
				+++ hex_int_without_prefixed_zeroes i
				+++ " at offset " +++ hex_int_without_prefixed_zeroes (bk_entries.[i] - bk_offset)) file;
		= write_entry_node_offsets (inc i) limit offset file bk_entries bk_offset;

	write_entry offset title file
		// Offset
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (hex_int offset) file;
			
		// Raw data
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites (hex_int (FromStringToInt block_table_as_string offset)) file;
					
		#! file
			= fwrites SepSpaces file;
		#! file
			= fwrites title file;
			
		#! file
			= fwritec '\n' file;
		= (offset + 4,file);

	write_header file
		#! file
			= fwrites "BLOCK TABLE\n" file;
		#! file
			= write_entry2 block_table_s "entries" file;
		#! file
			= write_entry2 block_table_i "relative file pointer" file;
		#! file
			= fwritec '\n' file;
			
		#! file
			= fwrites title file;
		#! file
			= fwritec '\n' file;

		#! file
			= fwrites title_underlined file;
		#! file
			= fwritec '\n' file;

		= file;

	offset_raw_data_text
		// 12345678						12345678901
		= "Offset  " +++ SepSpaces +++ "Raw data" +++ SepSpaces;
	offset_raw_data_underlined
		= "--------" +++ SepSpaces +++ "--------" +++ SepSpaces;

	title	
		= SepSpaces +++ offset_raw_data_text +++ 		"Comment";
	title_underlined
		= SepSpaces +++ offset_raw_data_underlined	+++ "-------";
} // WriteBlockTable
