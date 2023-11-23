implementation module compute_graph;

import cg_name_mangling;
ALLOW_NESTED_DYNAMICS :== True;

import StdEnv;
import dynamics;
import read_dynamic;
import memory;
import ddState;
import ExtInt;
import ExtSystem;
import ExtList;
import RWSDebugChoice;
import ExtArray;
import pdExtInt;
import StdDynamicLowLevelInterface;
import BitSet;
import StdDynamicTypes;

import DebugUtilities;
G a b :== b;

:: *Prefixes = {
		prefix_kind_set	:: !Int
	,	base_addresses	:: !*{#Int}
	};
	
DefaultPrefix :: *Prefixes;
DefaultPrefix
	= { Prefixes |
		prefix_kind_set	= 0
	,	base_addresses	= createArray N_PREFIXES (-1)
	};
	
:: *DescriptorAddressTableEntry = {
		descriptor_name						:: !String
	,	module_name							:: !String
	,	prefixes							::  Prefixes //{Prefix}
	,	date_library_instance_nr_on_disk	:: !Int
	};
	
DefaultDescriptorAddressTableEntry :: DescriptorAddressTableEntry;
DefaultDescriptorAddressTableEntry
	= { DescriptorAddressTableEntry |
		descriptor_name	= ""
	,	module_name		= ""
	,	prefixes		= DefaultPrefix
	,	date_library_instance_nr_on_disk	= -1
	};
	
:: *DescriptorAddressTable
	= {
		desc_addr_table		:: !*{DescriptorAddressTableEntry}
	,	expanded_desc_table	:: !*{#Int}									// maps an expanded offset to its base index 
	,	indices_array		:: !*{{#Int}	}								// for each block indices in desc_addr_table
	,	root_nodes			:: !{(Int,Int)}									// (start_node_i,end_node_i)
	};
	
DefaultDescriptorAddressTable n_desc_entries
	# desc_table
		= { 
			desc_addr_table	= { DefaultDescriptorAddressTableEntry \\ i <- [1..n_desc_entries] }
		,	expanded_desc_table = {}
		,	indices_array	= {}
		,	root_nodes		= {}
		};
	= desc_table;
	
usize_desc_addr_table :: !*DescriptorAddressTable -> (!Int,*DescriptorAddressTable);
usize_desc_addr_table desc_table=:{desc_addr_table}
	#! (s_desc_table,desc_addr_table)
		= usize desc_addr_table;
	= (s_desc_table,{desc_table & desc_addr_table = desc_addr_table});


BuildDescriptorAddressTable :: !BinaryDynamic -> (!Int,!Int,!DescriptorAddressTable);
BuildDescriptorAddressTable dynamic_info=:{descriptor_usage_table}
	#! n_desc_entries
		= size descriptor_usage_table;
	#! desc_table
		= DefaultDescriptorAddressTable n_desc_entries
	#! n_prefix_per_base_a
		= createArray n_desc_entries (0,0);
		
	#! (max_desc_name,max_mod_name,desc_table,n_prefix_per_base_a,s_expanded_desc_table)
		= build 0 n_desc_entries desc_table 0 0 n_prefix_per_base_a 0;
		
	// build expanded descriptor offset array
	#! expanded_desc_table
		= createArray s_expanded_desc_table 0  
	#! expanded_desc_table
		= build_expanded_array 0 n_desc_entries 0 n_prefix_per_base_a expanded_desc_table
		
	#! desc_table
		= { desc_table &
			expanded_desc_table = expanded_desc_table
		};
	= (max_desc_name,max_mod_name,desc_table)
where {
	(binary_dynamic=:{stringtable})
		= dynamic_info;
		
	build_expanded_array :: !Int !.Int Int {(Int,Int)} !*{#Int} -> *{#Int};
	build_expanded_array i limit j n_prefix_per_base_a expanded_desc_table
		| i == limit
			= expanded_desc_table;
			
			#! ((base,n_prefixes_for_this_base),n_prefix_per_base_a)
				= n_prefix_per_base_a![i];
				
			#! (j,expanded_desc_table)
				= fill j n_prefixes_for_this_base base expanded_desc_table
			= build_expanded_array (inc i) limit j n_prefix_per_base_a expanded_desc_table;
	where {
		fill j 0 base expanded_desc_table
			= (j,expanded_desc_table);
		fill j n_prefixes_for_this_base base expanded_desc_table
			= fill (inc j) (dec n_prefixes_for_this_base) base {expanded_desc_table & [j] = base};
	} // build_expanded_array

	build i limit desc_table max_desc_name max_mod_name n_prefix_per_base_a s_expanded_desc_table
		| i == limit
			= (max_desc_name,max_mod_name,desc_table,n_prefix_per_base_a,s_expanded_desc_table)
		
		// retrieve info
		#! (_,string_offset, prefix_kind_set)
			= determine_prefixes3 descriptor_usage_table.[i].prefix_set_and_string_ptr;
			
		#! n_prefixes_for_this_base
			= set_length prefix_kind_set
		#! (prefix_kind_set,s_expanded_desc_table)
			= case n_prefixes_for_this_base of {
				0	-> abort "BuildDescriptorAddressTable; |prefix_kind_set| = 0 corrupt dynamic";
				_ 	-> (prefix_kind_set,s_expanded_desc_table + n_prefixes_for_this_base);
			};
		#! (descriptor_name,module_name)
			= get_descriptor_and_module_name2 string_offset	stringtable;
		
		// compute lengths
		#! max_desc_name	= max ((size descriptor_name) + count_length_of_expanded_string 0 (size descriptor_name) descriptor_name 0) max_desc_name;
		#! max_mod_name		= max ((size module_name) + count_length_of_expanded_string 0 (size module_name) module_name 0) max_mod_name;
			
		// build entry
		#! d
			= DefaultDescriptorAddressTableEntry;
		#! desc_entry
			= { d &
				descriptor_name						= descriptor_name
			,	module_name							= module_name
			,	prefixes							= { d.prefixes & prefix_kind_set = prefix_kind_set }
			,	date_library_instance_nr_on_disk	= descriptor_usage_table.[i].dus_library_instance_nr_on_disk
			};	
			
		#! n_prefix_per_base_a
			= { n_prefix_per_base_a & [i] = (i,n_prefixes_for_this_base) }
		= build (inc i) limit {desc_table & desc_addr_table.[i] = desc_entry} max_desc_name max_mod_name n_prefix_per_base_a s_expanded_desc_table
} // BuildDescriptorAddressTable

:: ArrayElement
	= IntElem
	| BoolElem
	| CharElem
	| RealElem
	| RecordElem !Int !Int !String
	
	// boxed array
	| BoxedElem
	;
	
:: *Nodes a
	= {
		node_i			:: !Int
	,	nodes 			:: !*{#Node a}
	};

:: Node a
	= {
		children	:: ![Child] 		//![Int]
	,	info		:: a
	,	graph_index	:: !Int
	};
	
:: Child 
	= Internal !Bool !Int				// ok? ref to definition node
	| External !Bool !Int				// ok? before fixup: NodeIndex see StdDynamicLowLevelInterface, afterwards: ref to definition node
	;
	
get_definition_node node_i :== get_definition_node node_i
where {
	get_definition_node (Internal True node_i)	= (True,node_i);		// (is_internal,node_i)
	get_definition_node (External True node_i)	= (False,node_i);
};

DefaultNode :: (Node a) | ToInfo a;	
DefaultNode 
	= { Node |
		children	= []
	,	info		= default_info
	,	graph_index	= 0
	};
		
DefaultNodes :: !Int -> *(Nodes a) | ToInfo a;
DefaultNodes n_nodes
	= { Nodes |
		node_i			= 0
	,	nodes			= let { n d = { d \\ i <- [1..n_nodes] }; } in n DefaultNode
	};

class ToInfo a
where {

	default_info :: a;
	is_definition_node :: a -> Bool;
	more_info ::  !Int a -> Bool;
	get_more_info :: !Int a !String -> String;

	int_to_info :: !Int !*{#Char} -> (a,!*{#Char});	
	char_to_info :: !Int !*{#Char} -> (a,!*{#Char});
	real_to_info :: !Int !*{#Char} -> (a,!*{#Char});
	bool_to_info :: !Int !*{#Char} -> (a,!*{#Char});
	closure_to_info :: !ClosureInfo !Int !*{#Char} -> (a,!*{#Char});
	indirection_to_info :: !Int !*{#Char} -> (a,!*{#Char});
	record_to_info :: !RecordInfo !Int !Int !String !Int !*{#Char} -> (a,!*{#Char});
	string_to_info :: !Int !Int !*{#Char} -> (a,!*{#Char});
	dynamic_to_info :: !Int !Int !Int !String !Int !*{#Char} -> (a,!*{#Char});
	array_to_info :: !ArrayInfo !Int !Int !ArrayElement !Int !*{#Char} -> (a,!*{#Char})
};

:: NodeKind
	= NK
	| IntLeaf !Int !BasicValue									// graph_i of associated Int
	| CharLeaf !Int !BasicValue									// graph_i of associated Char
	| RealLeaf !Int !BasicValue									// graph_i of associated Real
	| BoolLeaf !Int	!BasicValue									// graph_i of associated Bool
	| Closure !Int !ClosureInfo 								// n_boxed_args (superfluous = length of children
	| Indirection !Int											// node_i
	| Record !Int !Int !String !Int	!RecordInfo					// n_boxed_args (superfluous = length of children) size_of_unboxed_args (REAL takes two words) type_string (for each unboxed argument) graph_i (of first unboxed value)
	| StringLeaf !Int !Int !StringInfo							// length stringP of string info
	| Dynamic !Int !Int !Int !String !Int						// n_boxed_args (superfluous = length of children) size_of_extra_info size_of_unboxed_args (REAL takes two words) type_string (for each unboxed argument) graph_i (of first unboxed value)
	| ArrayNode !Int !Int !ArrayElement !Int !ArrayInfo 		// array_size elem_size element array_elem_start(graph_i)
	;
	
get_real_from_graph graph_i graph
	#! l
		= FromStringToInt graph graph_i;
	#! h
		= FromStringToInt graph (graph_i + 4);
	= (ints_to_real (l,h),graph);
	
get_char_from_graph graph_i graph
	= graph![graph_i];	
	
instance ToInfo NodeKind
where {
	default_info
		= NK;

	is_definition_node NK						= abort "is_definition; NK!";
	is_definition_node (Indirection _)			= False;
	is_definition_node _						= True;

	// index (1st arg of more_info) is the node *following* the descriptor
	// The descriptor has already been processed. more_info should deliver true for the complete node 
	// minus descriptor. i Is an index into the node
	more_info _ NK								= abort "more_info; NK";
	more_info 0 (IntLeaf _ _)						= True;
	more_info i (StringLeaf string_length _ _)
		/* layout
		** 0: length
		** 1: rest of string 
		*/
		#! i_max
			= (roundup_to_multiple string_length 4) >> 2;
		= not (i > i_max);
	more_info 0 (CharLeaf _ _)								= True;
	more_info i (RealLeaf _ _)								= (i == 0) || (i == 1);
	more_info 0 (BoolLeaf _ _)								= True;
	more_info i (Record _ s_unboxed_args _ _ _)				= abort "aa"; //i < s_unboxed_args;
	more_info i (Dynamic _ s_extra_info s_unboxed_args _ _)	= i < (s_extra_info + s_unboxed_args);
	
	more_info i (ArrayNode array_size elem_size elem _ _)
		#! array_size_in_bytes
			= ARRAY_DESC_ELEMS - 4 + (roundup_to_multiple (array_size * elem_size) 4) ;
		// note the -4!
		#! array_size_in_words
			= array_size_in_bytes >> 2;
		= if (elem == BoxedElem) 
			(i < ((ARRAY_DESC_ELEMS - 4) >> 2) )
			 (i < array_size_in_words);
	more_info _ _											= False;
	
	get_more_info _ (IntLeaf graph_i _) graph	
		= toString (FromStringToInt graph graph_i);
	get_more_info _ (CharLeaf graph_i _) graph
		= "'" +++ toString (toChar (FromStringToInt graph graph_i)) +++ "'";
	get_more_info i (RealLeaf graph_i _) graph
		| i == 0
			// little endian
			#! l
				= FromStringToInt graph graph_i;
			#! h
				= FromStringToInt graph (graph_i + 4);
			= toString (ints_to_real (l,h));
			= "skip";

	get_more_info _ (BoolLeaf graph_i _) graph	
		| FromStringToInt graph graph_i <> 0
			= "True";
			= "False";
	get_more_info i (StringLeaf string_length string_start _) graph
		| i == 0
			= "length: " +++ toString string_length;
		| i == 1
			#! s
				= get_chars i
			= "\"" +++ s +++ (if (size s <= 4) "\"" "");
			
		#! last_i
			= (roundup_to_multiple string_length 4) >> 2
		| i == last_i
			= get_chars i +++ "\""
			= get_chars i;
	where {
		get_chars i
			#! n_characters_consumed
				= (dec i) * 4;
			#! n_characters_present
				= min 4 (string_length - n_characters_consumed);
			#! s
				= graph % (string_start + n_characters_consumed,string_start + n_characters_consumed + (dec n_characters_present))
			= s;
	}

	get_more_info i (Dynamic n_boxed_args s_extra_info s_unboxed_args type_string graph_i) graph
		#! s 
			= case i of {
				0	
					#! offset_to_dynamic_end
						= FromStringToInt graph graph_i;
					-> ("value at " +++ hex_int_without_prefixed_zeroes (graph_i + offset_to_dynamic_end));
				1	
					#! offset_to_type_part
						= FromStringToInt graph (graph_i + 4);

					-> ("type at " +++ hex_int_without_prefixed_zeroes (graph_i + offset_to_type_part));
				i	
					-> "get_more_info i (Dynamic";
			};
		= s; 
	
	get_more_info i (Record n_boxed_args s_unboxed_args type_string graph_i _) graph
		#! (type_index,get_more_info_i)
			= determine_type 0 0 i type_string 
		#! graph_i
			= graph_i + i << 2;
		| type_string.[type_index] == 'b'
			#! s 
				= get_more_info get_more_info_i (BoolLeaf graph_i default_elem) graph;
			= s +++ " (Bool)";
		| type_string.[type_index] == 'r'
			#! s 
				= get_more_info get_more_info_i (RealLeaf graph_i default_elem) graph;
			= s +++ " (Real)";
		| type_string.[type_index] == 'i'
			#! s 
				= get_more_info get_more_info_i (IntLeaf graph_i default_elem) graph;
			= s +++ " (Int)";
		| type_string.[type_index] == 'c'
			#! s 
				= get_more_info get_more_info_i (CharLeaf graph_i default_elem) graph;
			= s +++ " (Char)";
	
		= abort ("more info <" +++ toString type_string.[type_index]);

	where {
		determine_type type_string_i j i type_string
			| type_string_i == (size type_string)
				= abort "q (internal error) too far";
				
			// type_string_i < i
			#! relative_limit
				= case type_string.[type_string_i] of {
					'r'	-> 2;
					'b'	-> 1;
					'i'	-> 1;
					'c'	-> 1;
				};
			#! (found,j,r)
				= w 0 relative_limit j i
			| found
				// i's associated type is at index type_string_i of type_string and its relative position for
				// get_more_info is r
				= (type_string_i,r)
				//abort ("ok i=" +++ toString i +++ " current type_string_i: " +++ toString type_string_i +++ " r=" +++ toString r);
			#! s
				= toString type_string_i +++ " - " +++ toString j +++ " - " +++ toString i;
			= determine_type (inc type_string_i) j i type_string;
		where {
			w r relative_limit j i
				| r == relative_limit
					= (False,j,999);
					
				| j == i
					= (True,j,r);
				= w (inc r) relative_limit (inc j) i;	
		}
	} // get_more_info i (Record ...
	
	get_more_info i (ArrayNode s_array s_elem elem  array_element_start_graph_i _) graph
		| G (toString i) i == 0
			= toString s_array +++ " elements";
		| i == 1
			= toString elem;
		
		// i offset
		#! offset
			= (i - 2) << 2;
		#! on_elem_boundary
			= s_elem < 4 /* for bools/chars */ || (offset rem s_elem == 0)
		| on_elem_boundary && elem == IntElem
			= "#" +++ (get_more_info 0 (IntLeaf (array_element_start_graph_i + offset) default_elem) graph);
		| on_elem_boundary && elem == RealElem
			= "#" +++ (get_more_info 0 (RealLeaf (array_element_start_graph_i + offset) default_elem) graph);
		| elem == BoolElem
			#! elem_offset
				= array_element_start_graph_i + offset;
			#! base_index
				= offset;
				
			#! d
				= extract_D_from_ABCD graph elem_offset;
			#! d_string
				= get_more_info 0 (BoolLeaf 0 default_elem) (FromIntToString d);
				
			#! c
				= extract_C_from_ABCD graph elem_offset
			#! c_string
				= get_more_info 0 (BoolLeaf 0 default_elem) (FromIntToString c);
			#! c_string2
				= if ((base_index + 1) < s_array) (" " +++ c_string) "";
						
			#! b
				= extract_B_from_ABCD graph elem_offset
			#! b_string
				= get_more_info 0 (BoolLeaf 0 default_elem) (FromIntToString b);
			#! b_string2
				= if ((base_index + 2) < s_array) (" " +++ b_string) "";
				
			#! a
				= extract_A_from_ABCD graph elem_offset
			#! a_string
				= get_more_info 0 (BoolLeaf 0 default_elem) (FromIntToString a);
			#! a_string2
				= if ((base_index + 2) < s_array) (" " +++ a_string) "";
			= "#" +++ d_string +++ c_string2 +++ b_string2 +++ a_string2;
		| elem == RecordElem 0 0 ""
			//  n_boxed_args s_unboxed_args type_string
			# (RecordElem n_boxed_args s_unboxed_args type_string)
				= elem;
			# record_elem
				= Record n_boxed_args s_unboxed_args type_string (array_element_start_graph_i + offset) default_elem;
			= "#" +++ (get_more_info 0 record_elem graph);
		| elem == BoxedElem
			= "boxed";
			= "";
				
	int_to_info int_i graph
		#! intje
			= FromStringToInt graph int_i;
		#! intje
			= BV_Int intje;
		= (IntLeaf int_i intje,graph);
	char_to_info char_i graph
		# (c,graph)
			= get_char_from_graph char_i graph;
	
		= (CharLeaf char_i (BV_Char c),graph);
	real_to_info char_i graph
		#! (realtje,graph)
			= get_real_from_graph char_i graph
		= (RealLeaf char_i (BV_Real realtje),graph);
		
	bool_to_info char_i graph
		#! bool_info
			= (FromStringToInt graph char_i) ;
		#! bool_info
			= BV_Bool (bool_info <> 0);
		= (BoolLeaf char_i bool_info,graph);
				
	closure_to_info closure_info n_boxed_args graph
		= (Closure  n_boxed_args closure_info,graph);
	indirection_to_info node_i graph
		= (Indirection node_i,graph);
	record_to_info record_info n_boxed_args s_unboxed_args type_string graph_i graph 
		= (Record n_boxed_args s_unboxed_args type_string graph_i record_info,graph);
	string_to_info string_length string_offset graph
		# (str,graph)
			= u_string_slice graph string_offset (dec string_offset + string_length);
		= (StringLeaf string_length string_offset {default_elem & si_string = str},graph);
	dynamic_to_info n_boxed_args s_extra_info s_unboxed_args type_string graph_i graph
		= (Dynamic n_boxed_args s_extra_info s_unboxed_args type_string graph_i,graph);
		
	array_to_info array_info s_array s_elem elem array_element_start_graph_i graph
		= (ArrayNode s_array s_elem elem  array_element_start_graph_i array_info,graph);
};

u_string_slice :: !u:{#Char} !Int !Int -> (!*{#Char},!u:{#Char});
u_string_slice str a b
	= code inline {
		push_a 0
		.d 1 2 ii
			jsr sliceAC
		.o 1 0
	}

NewNode :: !Int !*(Nodes a) -> (!Int,!*(Nodes a));
NewNode graph_i nodes=:{node_i,nodes=nodes1}
	#! (s_nodes,nodes1)
		= usize nodes1;
	| node_i == s_nodes
		= abort ("NewNode: out of memory; node_i:" +++ toString node_i +++ " - s_nodes: " +++ toString s_nodes);
	= (node_i,{nodes & node_i = inc node_i, nodes = { nodes1 & [node_i].graph_index = graph_i}       });
	
GetNextFreeNode :: !*(Nodes a) -> (!Int,!*(Nodes a));
GetNextFreeNode nodes=:{node_i}
	= (node_i,nodes);
	
AddChild :: !Int !Int !Child !*(Nodes a) -> *(Nodes a);
AddChild parent offset child nodes
	#! (children,nodes)
		= nodes!nodes.[parent].children;
	= { nodes & 
		nodes.[parent].children = [child:children]
	};
where {
	get_node (Internal True n)	= n;
	get_node (External True n)	= n;
	get_node _					= abort "get_node; internal error";
};	
	
set_node_info :: (*{#Char} -> (a,!*{#Char})) !Int !*{#Char} (Nodes a) -> (Nodes a,!*{#Char}) | ToInfo a;
set_node_info f node_i graph nodes
	// set node info
	#! (node_info,graph)
		= f graph;
	#! nodes
		= { nodes & nodes.[node_i].Node.info = node_info  };	
	= (nodes,graph);

fxx :: !*{{#Int}	} -> *{{#Int}	};
fxx i = i;

fx2 :: !*{(Int,Int)} -> *{(Int,Int)};
fx2 i = i;

compute_nodes :: !*DescriptorAddressTable !BinaryDynamic !*DDState -> *(!*Nodes NodeKind,!*DescriptorAddressTable,!*DDState);
compute_nodes desc_table dynamic_info=:{header,descriptor_usage_table,block_table} ddstate //=:{project_name}
	| not (DYNAMIC_CONTAINS_BLOCKTABLE header)
		#! id = 0;
		#! nodes
			= DefaultNodes (inc (n_nodes ));
		#! (_,_,nodes,desc_table,ddstate,_,_)
			= compute_nodes2 id 0 {} nodes desc_table dynamic_info ddstate;
		= (nodes,desc_table,ddstate);
	
	// with block table
	#! n_nodes2
		= (n_nodes + (size block_table));
	#! nodes
		= DefaultNodes n_nodes2;
	#! indices_arrays
		= fxx { {} \\ i <- [1..size block_table] };
	#! root_nodes
		= fx2 (createArray (size block_table) (0,0));
	#! entry_node_fixup_table
		= { {} \\ i <- [1..size block_table] };
		
		
	#! s_block_table
		= size block_table;

	#! id = 0;
	#! (nodes,desc_table,ddstate,indices_arrays,root_nodes,entry_node_fixup_table)
		= loop 0 s_block_table id indices_arrays nodes desc_table ddstate root_nodes entry_node_fixup_table;		
		
	// fixup external nodes
	#! (nodes_array,nodes)
		= get_nodes nodes;
	#! nodes_array
		= fixup_external_references_in_nodes 0 n_nodes2 nodes_array entry_node_fixup_table;
	#! nodes 
		= { nodes &
			nodes	= nodes_array
		};
	
	// end
	#! desc_table
		= { desc_table & 
			indices_array = indices_arrays
		,	root_nodes 		= root_nodes
		};
	= (nodes,desc_table,ddstate);
where {	
	fixup_external_references_in_nodes :: !Int !Int !*{#Node NodeKind} !{#{#Int}} -> *{#Node NodeKind};	
	fixup_external_references_in_nodes i limit nodes_array entry_node_fixup_table
		| i == limit
			= nodes_array;
			
			# (node,nodes_array)
				= nodes_array![i];
			
			#! (children_with_external_refs,node_contains_external_references)
				= mapSt f node.children False;
			| node_contains_external_references
				#! nodes_array
					= { nodes_array & [i].children = children_with_external_refs};

				= fixup_external_references_in_nodes (inc i) limit nodes_array entry_node_fixup_table;

				= fixup_external_references_in_nodes (inc i) limit nodes_array entry_node_fixup_table;
	where {
		f node=:(External True node_index) node_contains_external_references
			# block_i
				= get_block_i node_index;
			# en_node_i
				= get_en_node_i node_index;
			# node_id
				= entry_node_fixup_table.[block_i,en_node_i];
			= (External True node_id,True);
		f node node_contains_external_references
			= (node,node_contains_external_references);
	} // fixup_external_references_in_nodes

	loop i limit id indices_arrays nodes desc_table ddstate root_nodes entry_node_fixup_table
		| i == limit
			= (nodes,desc_table,ddstate,indices_arrays,root_nodes,entry_node_fixup_table);

		| False <<- ("Block_i: ", i)
			= undef;

		#! (id,node_i,nodes,desc_table,ddstate,indices_arrays,to_node_id)
			= compute_nodes2 id i indices_arrays nodes desc_table dynamic_info ddstate;
				
		#! entry_node_fixup_table
			= { entry_node_fixup_table & [i] = to_node_id };
		#! (end_node_i,nodes)
			= GetNextFreeNode nodes;

		| False <<- ("block_i: ", i, " loop; start-node: ", inc node_i, "end-node: ",dec end_node_i)	
			= undef;

		= loop (inc i) limit id indices_arrays nodes desc_table ddstate 
			 { root_nodes & [i] = (inc node_i,dec end_node_i)} 
			entry_node_fixup_table;

	(binary_dynamic=:{header={n_nodes,graph_s,graph_i,stringtable_i,stringtable_s,descriptortable_i,descriptortable_s},stringtable,descriptortable,graph})
		= dynamic_info;
}

get_nodes :: !*(Nodes a) -> *(.{#Node a},*Nodes b);
get_nodes nodes=:{nodes=nodes1}
	= (nodes1,{nodes & nodes = {}});

from utilities import foldSt;

compute_nodes2 :: !Int !Int !*{{#Int}} !*(Nodes .NodeKind) !*DescriptorAddressTable !BinaryDynamic !*DDState ->
 *(!Int,!Int,!*Nodes NodeKind,!*DescriptorAddressTable,!*DDState,!*{{#Int}},!*{#Int});
compute_nodes2 id block_i indices_arrays nodes desc_table dynamic_info=:{header,descriptor_usage_table,block_table} ddstate //=:{project_name}
	
	// update desc_table with required addresses
	#! (id,addresses,ddstate)
		= get_label_addresses block_i id ddstate;

	| G ("size addresses: " +++ toString (size addresses)) size addresses < 0
		= abort "<0";		
	#! index_in_desc_addr_table
		= if (DYNAMIC_CONTAINS_BLOCKTABLE header) (createArray ((size addresses) >> 2) 0) {};

	#! (s_desc_table,desc_table)
		= usize_desc_addr_table desc_table;

	#! (desc_table,index_in_desc_addr_table)
		= store_label_addresses 0 s_desc_table desc_table 0 addresses index_in_desc_addr_table descriptor_usage_table block_i;

	#! (indices_arrays,graph,en_node_offsets,to_node_id)
		= case (DYNAMIC_CONTAINS_BLOCKTABLE header) of {
			True
				#! indices_arrays
					= { indices_arrays & [block_i] = index_in_desc_addr_table};
					
				#! bk_offset
					= block_table.[block_i].bk_offset;
				#! bk_size
					= block_table.[block_i].bk_size;
				#! bk_n_node_entries
					= block_table.[block_i].bk_n_node_entries;

				// BlockTable
				#! offset_and_block_id_list
					= if (bk_n_node_entries == 0) 
						[(0,0)]
						([ (block_table.[block_i].bk_entries.[index] - bk_offset ,index) \\ index <- [0..dec (size block_table.[block_i].bk_entries)] ]); // ++ [(0,0)])
				
				#! en_node_offsets
					= sortBy (\(offset1,_) (offset2,_) -> offset1 < offset2) 
						offset_and_block_id_list;
				#! to_node_id
					= createArray (length en_node_offsets) 0;
						
				#! (binary_dynamic=:{graph})
					= dynamic_info;
				#! graph
					= graph % (bk_offset, bk_offset + bk_size - 1);
					
				-> (indices_arrays,graph,en_node_offsets,to_node_id);
			False
				#! 	(binary_dynamic=:{graph})
					= dynamic_info;
				-> (indices_arrays,graph,[],{});
		};
	
	// compute nodes
	#! graph_u
		= {	c \\ c <-: graph };								// make graph unique
	#! (node_i,nodes)
		= NewNode (-1) (nodes);
		
		// BlockTable
	#! (bk_entries,block_table)
		= block_table![block_i].bk_entries;
		
	#! graph_u
		= foldSt (foo graph) [0.. dec ((size graph) >> 2)] graph_u;

	// decode graph
	#! (stringP,nodes,desc_table,ddstate,dynamics,graph_u,en_node_offsets,to_node_id)
		= case (size bk_entries) of {
			0	
				-> c 0 graph_u [node_i] nodes desc_table ddstate [] index_in_desc_addr_table en_node_offsets to_node_id;
			_	
				| False <<- ("MULTIPLE ENTRY NODES (" +++ toString (size bk_entries)+++ ")")
					->undef;
					-> mapASt (new_entry_node block_i node_i index_in_desc_addr_table) 
						bk_entries
						(0,nodes,desc_table,ddstate,[],graph_u,en_node_offsets,to_node_id);
		}; 

	| not (isEmpty en_node_offsets)
		// not all entry nodes of the current block have been used.
		= abort ("compute_nodes2; internal error; not all entry nodes of the current block have been used");
	| stringP <> bk_size
		= abort "compute_nodes2; wrong block size";	
	
	= (id,node_i,nodes,desc_table,ddstate,indices_arrays,to_node_id);
where {
	i :: {#Int} -> {#Int};
	i r
		= r;
		
	foo graph i graph_u
		#! (w,graph_u)
			= FromStringToIntU graph_u (i * 4)
		| False <<- (hex_int (bk_offset + i * 4), hex_int w)
			= undef;
		= graph_u;
		
	new_entry_node block_i node_i index_in_desc_addr_table entry_node_offset s=:(stringP,nodes,desc_table,ddstate=:{current_dynamic={block_table}},dynamics,graph_u,en_node_offsets,to_node_id)
		| stringP == block_table.[block_i].bk_size <<- ("new_entry_node",stringP)
			= s;
			= entry_node node_i index_in_desc_addr_table entry_node_offset s;
	
	entry_node node_i index_in_desc_addr_table entry_node_offset (stringP,nodes,desc_table,ddstate,dynamics,graph_u,en_node_offsets,to_node_id)

		| stringP <> entry_node_offset - bk_offset <<- ("entry_node",node_i,hex_int entry_node_offset)
			= abort ("!entry_node; wrong start of entry node; " 
			+++ toString stringP +++ " - " +++ toString (entry_node_offset - bk_offset) +++ " block_i: " +++ toString block_i 
				+++ "\nentry_node_offset: " +++ toString entry_node_offset 
				+++ "\nbk_offset: " +++ toString bk_offset);
				
		#! (s_graph_u,graph_u)
			= usize graph_u;
		#! (x,graph_u)
			= FromStringToIntU graph_u 0;
				
		| False <<- ("voor",stringP, s_graph_u, hex_int x)
			= undef;

		#! (stringP,nodes,desc_table,ddstate,dynamics,graph_u,en_node_offsets,to_node_id)
			= c stringP graph_u [node_i] nodes desc_table ddstate [] index_in_desc_addr_table en_node_offsets to_node_id;

		| False <<- ("na",stringP)
			= undef;

		= (stringP,nodes,desc_table,ddstate,dynamics,graph_u,en_node_offsets,to_node_id);

	({bk_size,bk_offset})
		= block_table.[block_i];
};

check_reference descP block_table
	| is_external_reference descP
		#! external_block_i
			= get_block_i descP;
		| not (between 0 external_block_i (dec s_block_table))
			#! msg 
				= "block " +++ toString external_block_i +++ " not between 0 and " +++ toString (dec s_block_table);
			= (False,Just msg);
			
			#! external_en_node_i
				= get_en_node_i descP;
			#! n_node_entries
				= inc (block_table.[external_block_i].bk_n_node_entries);
			| not (between 0 external_en_node_i n_node_entries)
				#! msg 
					= "en-node " +++ toString external_en_node_i +++ " of block " +++ toString external_block_i +++ " not between 0 and " +++ toString (dec n_node_entries);
				= (False,Just "");
				= (True,Nothing);
	| is_internal_reference descP <<- ("check_reference does NOT yet check internal reference")
		// should be checked
		= (True,Nothing)
				
where {
	s_block_table
		= size block_table;
};
		
c :: Int *{#Char} ![Int] *(Nodes NodeKind) *DescriptorAddressTable *DDState .a {#Int} [(Int,Int)] *{#Int} -> *(Int,*Nodes NodeKind,*DescriptorAddressTable,*DDState,.a,.{#Char},[(Int,Int)],.{#Int});
c stringP graph [] nodes desc_table ddstate dynamics _ en_node_offsets to_node_id
	= G "stop!"  (stringP,nodes,desc_table,ddstate,dynamics,graph,en_node_offsets,to_node_id);
c stringP graph temp=:[root_node:ns] nodes desc_table ddstate=:{current_dynamic={block_table}} dynamics index_in_desc_addr_table en_node_offsets to_node_id
	// check
	#! (s_graph,graph)
		= usize graph
	| G (toString stringP) stringP >= s_graph //<<- ("NEW_NODE -----------------------\n")
		| True <<- ("c",temp)
		
		#! s
			= toString stringP +++ " " +++ toString s_graph;
		= abort ("too big " +++ s +++ " " +++ toString ((length ns) + 1) +++ " <> " +++ toString (root_node));
		= abort "cannot match";
	// get descriptor
	#! (descP,graph)
		= FromStringToIntU graph stringP;

	#! q
		= " (" +++ toString (1 + length ns) +++ ") ";

	// 
	| isIndirection descP <<- (hex_int stringP +++ ": " +++ (hex_int descP) +++ q)
		#! (reference_ok,_)
			= check_reference descP block_table;
		| is_external_reference descP
			| False <<- ("EXTERNAL INDIRECTION", get_block_i descP, get_en_node_i descP)
				= undef;
			
			#! nodes
				= AddChild root_node stringP (External reference_ok descP) nodes;
			= G ("(external) indirection" ) c (stringP + 4) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
		| False <<- ("INTERNAL INDIRECTION")
			= undef;
		
		#! descP1 
			= (stringP - (get_offset_from_internal_reference descP));
		| False <<- ("stringP", stringP)
			= undef; 
		#! (node_i,graph)
			= case (descP1 < 0) of {
				True	-> (0,graph);
				_		-> FromStringToIntU3 graph descP1;
			};
		#! nodes
	  		= AddChild root_node stringP (Internal reference_ok node_i) nodes;

		= c (stringP + 4) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
		
	| descP == 0
		= abort "NULL descriptor";
	#! (j,descP,desc_table)
		= decode_descriptor descP desc_table index_in_desc_addr_table;
	| False <<- ("decode_descriptor", j, hex_int descP, "is closure", isClosure descP)
		= undef;
			
	// copy_descriptor
	#! (node_i,nodes)
		= NewNode stringP nodes;	// stringP relative w.r.t. block begin
	#! (l,en_node_offsets)
		= case ((isEmpty en_node_offsets) ) of {
			True
				-> (to_node_id,en_node_offsets);
			False
				# (offset,node_entry_i)
					= hd en_node_offsets;
				| offset == stringP
					// a definition of an entry node found
					#! to_node_id
						= { to_node_id & [node_entry_i] = node_i } <<- ("entry node found",node_i);
					-> (to_node_id,tl en_node_offsets);
					-> (to_node_id,en_node_offsets);
		}
	#! to_node_id
		= bug13 l; 
		
	#! nodes
		= AddChild root_node stringP (Internal True node_i) nodes;	
		
	#! graph
		= WriteLong graph stringP node_i;							// for indirections

	// test
	#! (descriptor_name,desc_table)
		= desc_table!desc_addr_table.[j].descriptor_name;
		
	| False <<- ("!!!",descriptor_name,stringP)
		= undef;


	| isClosure descP
		#! (arity,ddstate)
			= accMemClosure (readWord (descP - 4)) ddstate;

			
		#! temp_arity
			= arity
		#! arity
			= if (arity < 0) 1 arity		// neg. arities count as arity 1 (bug fix by John)
		
		| arity >= 256 <<- ("ARITY", arity)
			// unboxed closure
			#! n_unboxed_args
				= (arity >> 8) bitand 0x000000ff;
			#! arity
				= arity bitand 255;		
			#! n_boxed_args
				= arity - (arity bitand 255);
				
				
			#! (x,graph)
				= mapSt f [1..n_unboxed_args] graph;
			with {
				f ith_unboxed_arg graph
					#! (i,graph)
						= FromStringToIntU graph (stringP + (ith_unboxed_arg << 2));
					= (i,graph);
			
			};
			#! (a,stringP3,graph)
				= ({ BV_Unknown i \\ i <- x },stringP + 4 + (n_unboxed_args << 2),graph)
				
			#! closure_info
				= { default_elem &
					ci_closure_name			= descriptor_name
				,	ci_is_build_lazy_block	= NoLazyBlock
				,	ci_args					= { default_elem & 
												rai_unboxed_args	= a
											,	rai_n_boxed_args	= n_boxed_args
											}
				};
			#! (nodes,graph)
				= set_node_info (closure_to_info closure_info arity) node_i graph nodes;
				
			#! args
				= prepend_with_constants n_boxed_args node_i ns;
			= c stringP3 graph args nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
							
			// boxed closure
			#! (build_lazy_block_label,ddstate)
				= ddstate!build_lazy_block_label;
			#! (stringP,arity,args,closure_info,graph)
				= case (descP == build_lazy_block_label) of {
					True
						// update node
						#! (node_index,graph)
							= FromStringToIntU graph (stringP + 4 + BUILD_LAZY_DYNAMIC_ON_DISK__NODE_INDEX);
						#! (dynamic_index,graph)
							= FromStringToIntU graph (stringP + 4 + BUILD_LAZY_DYNAMIC_ON_DISK__DYNAMIC_ID);
							
						
						#! closure_info
							= { default_elem &
								ci_closure_name = descriptor_name
							,	ci_is_build_lazy_block	= BuildLazyBlock node_index dynamic_index
							};
						#! arity
							= SHARING_ACROSS_CONVERSIONS 1 0;
						-> (stringP + BUILD_LAZY_DYNAMIC_ON_DISK__BSIZE,arity,prepend_with_constants arity node_i ns,closure_info,graph);

					_
						// update node
						#! closure_info
							= { default_elem &
								ci_closure_name = descriptor_name
							};
						-> (stringP,arity,prepend_with_constants arity node_i ns,closure_info,graph);
				};

			#! (nodes,graph)
				= set_node_info (closure_to_info closure_info arity) node_i graph nodes;
			= c (stringP + 4) graph args nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

	| ddstate.int_descP + 2 == descP
		| False <<- ("INT")
			= undef;
			
		// update node
		#! (nodes,graph)
			= set_node_info (int_to_info (stringP + 4)) node_i graph nodes;
		= G "int" c (stringP + 8) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
	| ddstate.char_descP + 2 == descP
		// update node
		#! (nodes,graph)
			= set_node_info (char_to_info (stringP + 4)) node_i graph nodes;
		= G "char" c (stringP + 8) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
	| ddstate.bool_descP + 2 == descP
		// update node
		#! (nodes,graph)
			= set_node_info (bool_to_info (stringP + 4)) node_i graph nodes;
		= G "bool" c (stringP + 8) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
	| ddstate.real_descP + 2 == descP
		// update node
		#! (nodes,graph)
			= set_node_info (real_to_info (stringP + 4)) node_i graph nodes;
		= G "real" c (stringP + 12) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
	| ddstate.string_descP + 2 == descP
		#! (string_length,graph)
			= FromStringToIntU2 graph (stringP + 4);

		// update node
		#! (nodes,graph)
			= set_node_info (string_to_info string_length (stringP + 8)) node_i graph nodes;			
		= G "string" c (stringP + 8 + (roundup_to_multiple string_length 4)) graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

	| ddstate.array_descP + 2 == descP
		// get descriptor
		#! (size,graph)
			= FromStringToIntU2 graph (stringP + ARRAY_DESC_SIZE);
		#! (elem_descP,graph)
			= FromStringToIntU2 graph (stringP + ARRAY_DESC_ELEM_DESCP);
		| elem_descP == ARRAY_DESC_BOXED_DESCP
			#! args
				= prepend_with_constants size node_i ns;
				
			// update node
			#! array_info
				= { default_elem &
					ai_element_descriptor	= AED_Boxed
				,	ai_n_elements			= size
				};
			#! (nodes,graph)
				= set_node_info (array_to_info array_info size 0 BoxedElem (stringP + ARRAY_DESC_ELEMS)) node_i graph nodes;
				
			= c (stringP + ARRAY_DESC_ELEMS) graph args nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
				
		// convert encoded descP to real descP
		#! (j,elem_descP,desc_table)
			=  decode_descriptor elem_descP desc_table index_in_desc_addr_table;

		// get its name
		#! (descriptor_name,desc_table)
			= desc_table!desc_addr_table.[j].descriptor_name;
			
		| ddstate.int_descP + 2 == elem_descP	
			#! (array_info,stringP,graph)
				= CollectUnboxedArray BVK_Int size True (stringP + ARRAY_DESC_ELEMS) graph;
			#! (nodes,graph)
				= set_node_info (array_to_info array_info size 0 BoxedElem (stringP + ARRAY_DESC_ELEMS)) node_i graph nodes;
			= c stringP graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

		| ddstate.char_descP + 2 == elem_descP
			= abort "char array";
		| ddstate.bool_descP + 2 == elem_descP
			#! (array_info,stringP,graph)
				= CollectUnboxedArray BVK_Bool size True (stringP + ARRAY_DESC_ELEMS) graph;
			#! (nodes,graph)
				= set_node_info (array_to_info array_info size 0 BoxedElem (stringP + ARRAY_DESC_ELEMS)) node_i graph nodes;
			= c stringP graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

		| ddstate.real_descP + 2 == elem_descP
			#! (array_info,stringP,graph)
				= CollectUnboxedArray BVK_Real size True (stringP + ARRAY_DESC_ELEMS) graph;
			#! (nodes,graph)
				= set_node_info (array_to_info array_info size 0 BoxedElem (stringP + ARRAY_DESC_ELEMS)) node_i graph nodes;
			= c stringP graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

			// UNBOXED RECORD ARRAY
			#! stringP
				= stringP + ARRAY_DESC_ELEMS;

			// {#Record}
			// -------------
			// unboxed args
			// ------------
			// boxed args
			#! (n_boxed_args,s_unboxed_args,type_string,ddstate)
				= decode_record_descriptor elem_descP ddstate;
			#! boxed_args_startP
				= stringP + ((s_unboxed_args << 2) * size);

			#! ai_record_args_info
				= { default_elem \\ _ <- [1..size] };
				
			#! (ai_record_args_info,stringP,type_string,graph)
				= loopAst collect_unboxed_record_arguments (ai_record_args_info,stringP,type_string,graph) size;
			| stringP <> boxed_args_startP
				= abort "internal error";
				
			// update node
			#! array_info
				= { default_elem &
					ai_element_descriptor	= AED_Record descriptor_name
				,	ai_n_elements			= size
				,	ai_record_args_info		= ai_record_args_info
				};
			
			| True <<- ("unboxed record", node_i, "size: ",size)
			#! (nodes,graph)
				= set_node_info (array_to_info array_info size 0 BoxedElem (stringP + ARRAY_DESC_ELEMS)) node_i graph nodes;

			#! ns
				= prepend_with_constants (n_boxed_args * size) node_i ns;
			#! stringP
				= boxed_args_startP;		
			= c stringP graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;

			= abort "unreachable";

		// RECORDS ----------------------------------------------------------------------------------------------------------------
		#! (n_boxed_args,s_unboxed_args,type_string,ddstate)
			=
				(case (ddstate.type_cons_symbol_label + 2 == descP) of {
					True 	-> (1,4,"i",ddstate);
					_		-> decode_record_descriptor_with_type_string descP ddstate;
				})

				;
		| True <<- ("RECORD; n_boxed_args: ", n_boxed_args, "s_unboxed_args: ", s_unboxed_args,descriptor_name)


		#! (a,stringP3,graph)
			= collect_unboxed_arguments type_string (stringP + 4) graph;
		#! record_args_info
			= { default_elem &
				rai_unboxed_args = a
			};
		#! record_info
			= { default_elem &
				ri_descriptor_name	= descriptor_name
			,	ri_args				= record_args_info
			};
				
		#! (nodes,graph)
			= set_node_info (record_to_info record_info n_boxed_args s_unboxed_args type_string (stringP + 4)) node_i graph nodes;


		#! ns
			= prepend_with_constants (n_boxed_args) node_i ns;
		=  c stringP3 graph ns nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
where {
	collect_unboxed_record_arguments ith_record_args_info (ai_record_args_info,stringP,type_string,graph)
		#! (basic_value_a,stringP,graph)
			= collect_unboxed_arguments type_string stringP graph;
		#! ai_record_args_info
			= { ai_record_args_info & [ith_record_args_info] = { default_elem & rai_unboxed_args = basic_value_a } };
		= (ai_record_args_info,stringP,type_string,graph);
};

collect_boxed_elements _ (args,stringP,graph)
	#! i
		= FromStringToInt graph stringP;
	= ([i:args],stringP,graph);

CollectUnboxedArray basic_value_kind size is_unboxed_record stringP graph
	#! type_string
		= case basic_value_kind of {
			BVK_Int
				-> createArray size 'i';
			BVK_Bool
				-> createArray size 'b';
			BVK_Real
				-> createArray size 'r';
		};
		
	#! (a,stringP,graph)
		= collect_unboxed_arguments2 is_unboxed_record type_string stringP graph;
		
	#! record_args_info
		= { default_elem &
			rai_unboxed_args = a
		};

	#! array_info
		= { default_elem &
			ai_element_descriptor	= AED_BasicValue basic_value_kind
		,	ai_n_elements			= size
		,	ai_record_args_info		= {record_args_info}
		};
	= (array_info,stringP,graph);

import runtime_system;

collect_unboxed_arguments type_string stringP graph 
	:== collect_unboxed_arguments2 False type_string stringP graph;

collect_unboxed_arguments2 :: !Bool !{#Char} .Int !u:{#Char} -> ({BasicValue},Int,!v:{#Char}), [u <= v];
collect_unboxed_arguments2 is_unboxed_value_record type_string stringP graph
	| False <<- type_string
		= undef;
	#! rai_n_unboxed_args
		= n_unboxed_arguments type_string;
	| rai_n_unboxed_args == 0
		= ({},stringP,graph);
		
	#! rai_unboxed_args
		= createArray rai_n_unboxed_args BV_Invalid;
	#! (_,stringP,rai_unboxed_args,graph)
		= mapASt collect_unboxed_argument type_string (0,stringP,rai_unboxed_args,graph);
		
	#! stringP
		= if is_unboxed_value_record (roundup_to_multiple stringP ALIGNMENT) stringP;
	= (rai_unboxed_args,stringP,graph);
where {
	collect_unboxed_argument 'i' (ith_unboxed_arg,stringP,rai_unboxed_args,graph)
		#! int_value
			= FromStringToInt graph stringP;
		#! rai_unboxed_args
			= { rai_unboxed_args & [ith_unboxed_arg] = BV_Int int_value };
		= (inc ith_unboxed_arg,stringP + 4,rai_unboxed_args,graph);

	collect_unboxed_argument 'b' (ith_unboxed_arg,stringP,rai_unboxed_args,graph)
		| is_unboxed_value_record
			#! bool_value
				= toInt (graph.[stringP]) <> 0;
			#! rai_unboxed_args
				= { rai_unboxed_args & [ith_unboxed_arg] = BV_Bool bool_value };
			= (inc ith_unboxed_arg,stringP + 1,rai_unboxed_args,graph);
			
			// unboxed records:
			#! bool_value
				= FromStringToInt graph stringP <> 0;
			#! rai_unboxed_args
				= { rai_unboxed_args & [ith_unboxed_arg] = BV_Bool bool_value };
			= (inc ith_unboxed_arg,stringP + 4,rai_unboxed_args,graph);

	collect_unboxed_argument 'c' (ith_unboxed_arg,stringP,rai_unboxed_args,graph)
		| is_unboxed_value_record
			#! (char_value,graph)
				= get_char_from_graph stringP graph;
			#! rai_unboxed_args
				= { rai_unboxed_args & [ith_unboxed_arg] = BV_Char char_value };
			= (inc ith_unboxed_arg,stringP + 1,rai_unboxed_args,graph);
			
	
			// unboxed records:
			#! (char_value,graph)
				= get_char_from_graph stringP graph; 
			#! rai_unboxed_args
				= { rai_unboxed_args & [ith_unboxed_arg] = BV_Char char_value };
			= (inc ith_unboxed_arg,stringP + 4,rai_unboxed_args,graph);
			
	collect_unboxed_argument 'r' (ith_unboxed_arg,stringP,rai_unboxed_args,graph)
		#! (real_value,graph)
			= get_real_from_graph stringP graph;
		#! rai_unboxed_args
			= { rai_unboxed_args & [ith_unboxed_arg] = BV_Real real_value };
		= (inc ith_unboxed_arg,stringP + 8,rai_unboxed_args,graph);
	
	collect_unboxed_argument 'd' s
		= s;
	collect_unboxed_argument 'a' s
		= s;
	collect_unboxed_argument 'l' s
		= s;
		
	collect_unboxed_argument q s
		= abort ("collect_unboxed_argument" +++ toString q);
};



do_record n_boxed_args s_unboxed_args type_string descriptor_name stringP graph node_i nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id
	| True <<- ("do_record", descriptor_name)
	// unboxed part
	#! (a,_,graph)
		= collect_unboxed_arguments type_string (stringP + 4) graph;
		
	#! record_args_info
		= { default_elem &
			rai_unboxed_args = a
		};

	#! record_info
		= { default_elem &
			ri_descriptor_name	= descriptor_name
		,	ri_args				= record_args_info
		};
			
	#! (nodes,graph)
		= set_node_info (record_to_info record_info n_boxed_args s_unboxed_args type_string (stringP + 4)) node_i graph nodes;

	// boxed_part
	# new_stringP
		= (stringP + 4 /* skip descp */ + (s_unboxed_args << 2));
		
	# (new_stringP2,graph,nodes,desc_table,ddstate,dynamics,index_in_desc_addr_table,en_node_offsets,to_node_id)
		= foldSt (do_boxed_record_fields node_i) [1..n_boxed_args] 
		(new_stringP,graph,nodes,desc_table,ddstate,dynamics,index_in_desc_addr_table,en_node_offsets,to_node_id);

 	= (dynamics,[],"record",s_unboxed_args,nodes,graph /*added */ ,new_stringP2, desc_table, ddstate, index_in_desc_addr_table,en_node_offsets,to_node_id);
where {
	do_boxed_record_fields parent_node_i _ (stringP,graph,nodes,desc_table,ddstate,dynamics,index_in_desc_addr_table,en_node_offsets,to_node_id)
		| True <<- ("do_boxed_record_fields", stringP)
		#! (stringP,nodes,desc_table,ddstate,dynamics,graph,en_node_offsets,to_node_id)
			= c stringP graph [parent_node_i] nodes desc_table ddstate dynamics index_in_desc_addr_table en_node_offsets to_node_id;
		= (stringP,graph,nodes,desc_table,ddstate,dynamics,index_in_desc_addr_table,en_node_offsets,to_node_id);
};
		
	// work-around for a type-bug in 1.3
bug13 :: *{#Int} -> *{#Int};
bug13 i
	= i;
		
accMem3 :: (*Mem -> (!x,*Mem)) !DDState -> (!x,!DDState);
accMem3 f ddState=:{mem}
	#! (x,mem)
		= f mem;
	= (x,{ ddState & mem = mem }); 
	
accMemClosure f ddState=:{mem}
	#! (x,mem)
		= f mem;
	= (x,{ ddState & mem = mem }); 

prepend_with_constants :: !Int a [a] -> [a];
prepend_with_constants n_constants n list
	| n_constants < 0 
		= abort ("ff" +++ toString n_constants)
	| n_constants == 0 <<- ("prepend_with_constants", n_constants)
		= list;
	= prepend_with_constants (dec n_constants) n [n:list];

decode_descriptor :: !Int !DescriptorAddressTable {#Int} -> (!Int,!Int,!DescriptorAddressTable);
decode_descriptor prefix_set_and_desc_ptr desc_table index_in_desc_addr_table
	// decode descriptor
	#! encoded_descriptor
		= get_encoded_descriptor prefix_set_and_desc_ptr;
	| is_boxed encoded_descriptor <<- ("!!!",convert_to_descriptor_usage_entry encoded_descriptor, size index_in_desc_addr_table)
		= (abort "decode_descriptor; offset is 0");		
	#! offset
		= (index_in_desc_addr_table.[convert_to_descriptor_usage_entry encoded_descriptor]);
		
	#! (prefix_kind_set,desc_table)
		= desc_table!desc_addr_table.[offset].prefixes.prefix_kind_set;
	#! (descriptor_name,desc_table)
			= desc_table!desc_addr_table.[offset].descriptor_name;
			
	| False <<- ("decode_descriptor",descriptor_name, offset)
		= undef;

	// new
	#! bit_n
		= (prefix_set_and_desc_ptr >> (32 - 3)) bitand 7;

	| is_closure_prefix prefix_set_and_desc_ptr
		#! bit_n
			= G (fwrites (" bit_n: " +++ toString bit_n) stderr) bit_n;
		
		#! desc_table
			= check prefix_set_and_desc_ptr offset bit_n desc_table;
		#! (descP,desc_table)
			= desc_table!desc_addr_table.[offset].prefixes.base_addresses.[bit_n];
			
		= (offset,descP,desc_table);
		
		#! partial_arity
			= (prefix_set_and_desc_ptr >> 24) bitand 0x0000001f;
		#! desc_table
 			= check prefix_set_and_desc_ptr offset bit_n desc_table;
		#! (descP,desc_table)
			= desc_table!desc_addr_table.[offset].prefixes.base_addresses.[bit_n];
		
		#! descP2
			= descP + 2 + (partial_arity << 3);			
		= G (fwrites (" * " +++ hex_int descP +++ " ") stderr) (offset,descP2,desc_table);		
where {
	is_closure_prefix descP
		#! descP
			= descP bitand 0xe0000000;
		= (descP == NPREFIX_VALUE) || (descP == CPREFIX_VALUE);
}

decode_descriptor prefix_set_and_desc_ptr desc_table index_in_desc_addr_table
	= abort "rule mismatch";
		
isIndirection :: !Int -> Bool;
isIndirection descP 
		= is_reference descP;
	
isClosure :: !Int -> Bool;
isClosure descP
	#! is_closure 
		= descP bitand 2 == 0;
	= is_closure;
	
check descP offset bit_n desc_table
	#! (prefix_kind_set,desc_table)
		= desc_table!desc_addr_table.[offset].prefixes.prefix_kind_set;
	| prefix_kind_set bitand (1 << bit_n) == 0
		#! s
			="check: prefix not in set (bit_n)=" +++ toString bit_n +++ " prefix_kind_set= " +++ toString prefix_kind_set +++ " descP=" +++ hex_int descP;
		#! (descriptor_name,desc_table)
			= desc_table!desc_addr_table.[offset].descriptor_name;

		#! s
			= s +++ descriptor_name;
		= abort s;
		#! s
			= toString prefix_kind_set
		= desc_table;
	
store_label_addresses i limit desc_table j addresses index_in_desc_addr_table descriptor_usage_table block_i
	| i == limit
		= (desc_table,index_in_desc_addr_table);

	// has a block table 
	#! (is_element,_)
		= isBitSetMember descriptor_usage_table.[i].bitset block_i;
	| not is_element
		= store_label_addresses (inc i) limit desc_table j addresses index_in_desc_addr_table descriptor_usage_table block_i;

		// copy from above ...
		#! (prefix_kind_set,desc_table)
			= desc_table!desc_addr_table.[i].prefixes.prefix_kind_set
		#! (prefix_found,first_prefix_bit_n,j,desc_table,index_in_desc_addr_table)
			= store_address_for_each_prefix (dec N_PREFIXES) prefix_kind_set j desc_table index_in_desc_addr_table;
		= store_label_addresses (inc i) limit desc_table j addresses index_in_desc_addr_table descriptor_usage_table block_i;
		// ... copy from above
where {
	store_address_for_each_prefix bit_n prefix_kind_set j desc_table index_in_desc_addr_table
		#! (prefix_found,bit_n)
			= find_prefix bit_n prefix_kind_set;
		| not prefix_found
			= (False,-1,j,desc_table,index_in_desc_addr_table);
						
			#! (mouse_name,desc_table)
				= desc_table!desc_addr_table.[i].descriptor_name;
			#! mouse
				= FromStringToInt addresses j;
			| True <<- (mouse_name +++ " - "  +++ toString mouse +++ "j= " +++ toString j ) 
			
			#! desc_table
				= { desc_table & desc_addr_table.[i].prefixes.base_addresses.[bit_n] = mouse };
			#! index_in_desc_addr_table
				= { index_in_desc_addr_table & [j>>2] = i };
				
			= store_address_for_each_prefix (dec bit_n) prefix_kind_set (j + 4) desc_table index_in_desc_addr_table;
}

get_label_addresses :: !Int !Int !*DDState -> (!Int,!String,!*DDState);
get_label_addresses block_i id ddstate=:{first_time,project_name}
	| not (replace_command_line ("\"" +++ project_name +++ "\""))
		= abort "get_label_address; internal error";

	// send paths
	#! (msg,ddstate)
		= case first_time of {
			True
				// link project
				#! msg
					= doreqS ("DumpDynamic\n");
				| msg <> msg
					-> abort "get_label_addresses: (internal error)";
					
				#! msg = "";
				-> (msg,ddstate);
			False
				-> ("",ddstate);
		};
				
	| msg == msg
		# (file_name,ddstate)
			= ddstate!DDState.file_name;
			
		# is_initialization
			= (block_i == 0);
		# (id,_,s_adr)
			= LinkBlock file_name is_initialization id block_i;
		| is_initialization && (s_adr == s_adr)
			// get standard descriptors
			#! msg
				= "GetLabelAddressesINT\nCHAR\nBOOL\nREAL\n__STRING__\n__ARRAY__\ne____SystemDynamic__rDynamicTemp\n" 
					+++ BUILD_BLOCK_LABEL +++ "\n" +++ BUILD_LAZY_BLOCK_LABEL +++ "\n";
			#! addresses
				= doreqS msg;
			
			// update ddstate
			#! ddstate
				= { ddstate &
					first_time 		= False
				,	int_descP		= FromStringToInt addresses 0
				,	char_descP		= FromStringToInt addresses 4
				,	bool_descP		= FromStringToInt addresses 8
				,	real_descP		= FromStringToInt addresses 12
				,	string_descP	= FromStringToInt addresses 16
				,	array_descP		= FromStringToInt addresses 20
				,	e__StdDynamic__rDynamicTemp = FromStringToInt addresses 24
				,	build_block_label			= FromStringToInt addresses 28
				,	build_lazy_block_label		= FromStringToInt addresses 32
				};
				
			// strip 'garbage'
			= (id,s_adr,ddstate);			 
		= (id,s_adr,ddstate);
		
doreqS :: !String -> String;
doreqS s = 
	code { 
		ccall DoReqS "S-S"
	}

instance toString ArrayElement
where {
	toString IntElem	= "Unboxed INT";
	toString CharElem	= "Unboxed CHAR";
	toString BoolElem	= "Unboxed BOOL";
	toString RealElem	= "unboxed REAL";
	toString BoxedElem	= "Boxed elements";
	toString (RecordElem	_ _ _) = "Record element";
};

instance == ArrayElement
where {
	(==) IntElem IntElem		= True;
	(==) CharElem CharElem		= True;
	(==) BoolElem BoolElem 		= True;
	(==) RealElem RealElem		= True;
	(==) BoxedElem BoxedElem	= True;
	(==) (RecordElem _ _ _) (RecordElem	_ _ _) = True;
	(==) _ _ 					= False;
};

// decode_array_elem_descP element_descriptor ddstate -> (is_unboxed,Array Element)
decode_array_elem_descP elem_descP ddstate
	// boxed array
	| 0 == elem_descP
		= (False,BoxedElem,4,ddstate);

	// unboxed array
	| ddstate.int_descP + 2 == elem_descP
		= (True,IntElem,4,ddstate);
	| ddstate.bool_descP + 2 == elem_descP
		= (True,BoolElem,1,ddstate);
	| ddstate.real_descP + 2 == elem_descP
		= (True,RealElem,8,ddstate);
		
	// unboxed record array
	#! (record_descriptor_size,ddstate)
		= size_of elem_descP ddstate
	#! (n_boxed_args,s_unboxed_args,type_string,ddstate)
		= decode_record_descriptor elem_descP ddstate;

	= (True,RecordElem n_boxed_args s_unboxed_args type_string,record_descriptor_size,ddstate);
	
size_of descP ddstate
	| ddstate.int_descP + 2 == descP
		= abort "size_of int";
	| ddstate.char_descP + 2 == descP
		= abort "size_of char";
	| ddstate.bool_descP + 2 == descP
		= abort "size_of bool";
	| ddstate.real_descP + 2 == descP
		= abort "size_of real";
	| descP == 0
		= abort "size_of boxed";

		// record descriptor
		# (n_boxed_args,s_unboxed_args,type_string,ddstate)
			= decode_record_descriptor descP ddstate
		# record_descriptor_size
			= (s_unboxed_args + n_boxed_args) * 4
		= (record_descriptor_size,ddstate);

// Utility
set_length :: !Int -> Int;
set_length index
	| index < 0 || index > 255
		= abort "set_length: index out of range";
	= set.[index];
where {
	set :: {#Int};
	set =>
    {
	/*   0-15  */	0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
	/*  16-31  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	/*  32-47  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	/*  48-63  */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/*  64-79  */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	/*  80-95  */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/*  96-111 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/* 112-127 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	/* 128-143 */	1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
	/* 144-159 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/* 160-175 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/* 176-191 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	/* 192-207 */	2, 3, 3, 4, 3, 4, 4, 5, 3, 4, 4, 5, 4, 5, 5, 6,
	/* 208-223 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	/* 224-239 */	3, 4, 4, 5, 4, 5, 5, 6, 4, 5, 5, 6, 5, 6, 6, 7,
	/* 240-255 */	4, 5, 5, 6, 5, 6, 6, 7, 5, 6, 6, 7, 6, 7, 7, 8
    };
 }
 
// 
FromStringToIntU2 :: !*{#Char} !Int -> (!Int,!*{#Char});
FromStringToIntU2 array i	
	#! (v0,array)
		= array![i];
	#! (v1,array)
		= array![i+1];
	#! (v2,array)
		= array![i+2];
	#! (v3,array)
		= array![i+3];
	#! i
		= (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
	= (i,array);
	
FromStringToIntU3 :: !*{#Char} !Int -> (!Int,!*{#Char});
FromStringToIntU3 array i	
	| False <<- i
		= undef;
		
		# i = 
			i - 10;
		# i = 
			i + 10;
	#! (v0,array)
		= array![i];
	#! (v1,array)
		= array![i+1];
	#! (v2,array)
		= array![i+2];
	#! (v3,array)
		= array![i+3];
	#! i 
		= (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
	= (i,array);
	
accMem1 :: (*Mem -> (!x,*Mem)) !DDState -> (!x,!DDState);
accMem1 f ddState=:{mem}
	#! (x,mem)
		= f mem;
	= (x,{ ddState & mem = mem }); 
		
decode_record_descriptor_with_type_string :: !Int !*DDState -> (!Int,!Int,!String,!*DDState);
decode_record_descriptor_with_type_string descP ddstate
	#! (arity,ddstate)
		= accMem1 (readHalfWord (descP - 2)) ddstate;

	| True <<- ("decode_record_descriptor_with_type_string ", arity)

	#! (n_boxed_args,s_unboxed_args,type_string,ddstate)
		= case (arity >= 256) of {
			True
				| True <<- ("DECODE_RECORD_DESCRIPTOR")
				#! (n_boxed_args,ddstate)
					= accMem2 (readHalfWord descP) ddstate;
				#! n_unboxed_args
					= (arity - 256) - n_boxed_args;
				// note: |type_string| need not equal n_unboxed_args because reals take two bytes
				#! (type_string,ddstate)
					= get_type_string (descP + 2) ddstate;
				-> (n_boxed_args,n_unboxed_args,type_string,ddstate);
			False
				-> (arity,0,"",ddstate);
		};
	= (n_boxed_args,s_unboxed_args,type_string,ddstate);
where {
	get_type_string pointer ddstate
		#! (s_type_string,ddstate)
			= type_string_size pointer ddstate 0;
		#! (_,type_string,ddstate)
			= loopAst collect_type_string (pointer,createArray s_type_string ' ',ddstate) s_type_string;
		= (type_string,ddstate);
	where {
		type_string_size pointer ddstate size1
			#! (c,ddstate)
				= accMem2 (readByte pointer) ddstate;
			| (toChar c) <> '\0'
				= type_string_size (inc pointer) ddstate (inc size1);
				= (size1,ddstate);
				
		collect_type_string i (pointer,type_string,ddstate)
			#! (c,ddstate)
				= accMem2 (readByte pointer) ddstate;
			#! type_string 
				= { type_string & [i] = toChar c };
			= (inc pointer,type_string,ddstate);
	};
};

decode_record_descriptor :: !Int !*DDState -> (!Int,!Int,!String,!*DDState);
decode_record_descriptor descP ddstate
	= decode_record_descriptor_with_type_string descP ddstate;

decode_record_descriptor_old :: !Int !*DDState -> (!Int,!Int,!String,!*DDState);
decode_record_descriptor_old descP ddstate
	#! (arity,ddstate)
		= accMem1 (readHalfWord (descP - 2)) ddstate;
	#! (n_boxed_args,s_unboxed_args,type_string,ddstate)
		= case (arity >= 256) of {
			True
				#! (n_boxed_args,ddstate)
					= accMem2 (readHalfWord descP) ddstate;
				#! n_unboxed_args
					= (arity - 256) - n_boxed_args;
				// note: |type_string| need not equal n_unboxed_args because reals take two bytes
				#! (type_string,ddstate)
					= case (n_unboxed_args == 0) of { //(n_unboxed_args == 0) of {
						True 	-> ("compute_graph; line 865",ddstate);
						False	-> F ("** " +++ toString n_boxed_args) types_of_unboxed_fields (descP + 2) ddstate;
					};
				-> (n_boxed_args,n_unboxed_args,type_string,ddstate);
			False
				-> (arity,0,"",ddstate);
		};
	= (n_boxed_args,s_unboxed_args,type_string,ddstate);
where {
	// assumption: at least one unboxed arguments 
	types_of_unboxed_fields type_string_p1 ddstate
		#! (type_string_pstart,ddstate)
			= skip_d_and_boxed_args type_string_p1 ddstate;
		#! (type_string_pend,ddstate)
			= type_string_length type_string_pstart ddstate;
		#! type_string_length
			= type_string_pend - type_string_pstart;
			
		#! (type_string,ddstate)
			= collect_type_info 0 type_string_length type_string_pstart (createArray type_string_length ' ') ddstate;
		= (type_string,ddstate);
	where {
		skip_d_and_boxed_args type_string_p ddstate
			#! (c,ddstate)
				= accMem2 (readByte type_string_p) ddstate;
			#! c
				= toChar c;
			| c == 'd' || c == 'a'
				= skip_d_and_boxed_args (inc type_string_p) ddstate;
				= (type_string_p,ddstate);				
				
		type_string_length type_string_p ddstate
			#! (c,ddstate)
				= accMem2 (readByte type_string_p) ddstate;
			#! c
				= toChar c;
			| c == '\0'
				= ( type_string_p,ddstate);
				= type_string_length (inc type_string_p) ddstate;
		
		collect_type_info i limit type_string_p type_string ddstate
			| i == limit
				= (type_string,ddstate);

			#! (c,ddstate)
				= accMem2 (readByte type_string_p) ddstate;
			= collect_type_info (inc i) limit (inc type_string_p) {type_string & [i] = toChar c} ddstate;
	} // types_of_unboxed_fields
}

accMem2 f ddState=:{mem}
	#! (x,mem)
		= f mem;
	= (x,{ ddState & mem = mem }); 

// RunTime graph
:: RunTimeGraph
	= BasicValueInfo !Int
	| RecordInfo !RecordInfo
	;

:: BasicValue
	= BV_Invalid
	| BV_Char !Char
	| BV_Int !Int
	| BV_Bool !Bool
	| BV_Real !Real
	| BV_Unknown !Int
	;
	
		
instance DefaultElem BasicValue
where {
	default_elem 
		= BV_Invalid;
};

			
:: NodeRefInfo 
	= EntryNode !Int
	| NodeRef !Int
	;
		
:: RecordInfo
	= {
		ri_descriptor_name	:: !String
	,	ri_args				:: !RecordArgsInfo
	};
	
:: RecordArgsInfo
	= {
		rai_unboxed_args	:: {BasicValue}
	,	rai_n_boxed_args	:: !Int
	};
	
instance DefaultElem RecordArgsInfo
where {
	default_elem 
		= {
			rai_unboxed_args	= {}
		,	rai_n_boxed_args		= 0
		};
};

	
instance DefaultElem RecordInfo
where {
	default_elem
		= {
		ri_descriptor_name	= ""
	,	ri_args				= default_elem
	};
};	

:: ClosureInfo 
	= { 
		ci_closure_name			:: !String
	,	ci_is_build_lazy_block	:: !BuildLazyBlock
	,	ci_args					:: !RecordArgsInfo
	};
	
:: BuildLazyBlock
	= NoLazyBlock
	| BuildLazyBlock !Int !Int 		// NodeIndex (Dynamic ID)
	;

isBuildLazyBlock :: !BuildLazyBlock -> (!Bool,!Int,!Int);
isBuildLazyBlock (BuildLazyBlock node_index dynamic_index)	= (True,node_index,dynamic_index);
isBuildLazyBlock _	= (False,0,0);
	
instance DefaultElem ClosureInfo
where {
	default_elem
		= {
			ci_closure_name = "" 
		,	ci_is_build_lazy_block	= NoLazyBlock
		,	ci_args = default_elem
		};
};

:: StringInfo
	= {
		si_string			:: !String
	};

instance DefaultElem StringInfo
where {
	default_elem
		= { si_string = "" };
};		

:: ArrayInfo
	= { 
		ai_element_descriptor	:: !ArrayElementDescriptor
	,	ai_n_elements			:: !Int
	,	ai_record_args_info		:: !{#RecordArgsInfo}
	};

	
:: ArrayElementDescriptor
	= AED_Invalid
	| AED_BasicValue BasicValueKind
	| AED_Record !String
	| AED_Boxed
	;
	
:: BasicValueKind
	= BVK_Int
	| BVK_Char
	| BVK_Real
	| BVK_Bool
	;
		
instance DefaultElem ArrayInfo
where {
	default_elem
		= { 
			ai_element_descriptor	= AED_Invalid
		,	ai_n_elements			= 0
		,	ai_record_args_info		= {}
		};
};