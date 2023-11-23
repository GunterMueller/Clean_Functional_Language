definition module compute_graph;

from DefaultElem import class DefaultElem;
from read_dynamic import :: BinaryDynamic;
from ddState import :: DDState;

// Prefixes
:: *Prefixes = { 
		prefix_kind_set	:: !Int
	,	base_addresses	:: !*{#Int}
	};
	
DefaultPrefix :: *Prefixes;
	
// Descriptor Address Table
:: *DescriptorAddressTableEntry = {
		descriptor_name						:: !String
	,	module_name							:: !String
	,	prefixes							::  Prefixes
	,	date_library_instance_nr_on_disk	:: !Int
	};
	
DefaultDescriptorAddressTableEntry :: DescriptorAddressTableEntry;
	
:: *DescriptorAddressTable
	= {
		desc_addr_table		:: !*{DescriptorAddressTableEntry}
	,	expanded_desc_table	:: !*{#Int}									// maps an expanded offset to its base index 
	,	indices_array		:: !*{{#Int}	}								// for each block indices in desc_addr_table
	,	root_nodes			:: !{(Int,Int)}									// (start_node_i,end_node_i)
	};


usize_desc_addr_table :: !*DescriptorAddressTable -> (!Int,*DescriptorAddressTable);

BuildDescriptorAddressTable :: !BinaryDynamic -> (!Int,!Int,!DescriptorAddressTable);

	// Array elements
:: ArrayElement
	// unboxed array
	= IntElem
	| BoolElem
	| CharElem
	| RealElem
	| RecordElem !Int !Int !String
	
	// boxed array
	| BoxedElem
	;

// Nodes
:: *Nodes a
	= {
		node_i			:: !Int
	,	nodes 			:: !*{#Node a}
	};

:: Node a
	= {
		children	:: ![Child] 		
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
DefaultNodes :: !Int -> *(Nodes a) | ToInfo a;

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
	record_to_info :: !RecordInfo !Int !Int  !String !Int !*{#Char} -> (a,!*{#Char});
	string_to_info :: !Int !Int !*{#Char} -> (a,!*{#Char});
	dynamic_to_info :: !Int !Int !Int !String !Int !*{#Char} -> (a,!*{#Char});
	array_to_info :: !ArrayInfo !Int !Int !ArrayElement !Int !*{#Char} -> (a,!*{#Char})
};

:: NodeKind
	= NK
	| IntLeaf !Int !BasicValue					// graph_i of associated Int
	| CharLeaf !Int	!BasicValue								// graph_i of associated Char
	| RealLeaf !Int !BasicValue								// graph_i of associated Real
	| BoolLeaf !Int	!BasicValue					// graph_i of associated Bool
	| Closure !Int !ClosureInfo 					// n_boxed_args (superfluous = length of children
	| Indirection !Int								// node_i
	| Record !Int !Int !String !Int	!RecordInfo		// n_boxed_args (superfluous = length of children) size_of_unboxed_args (REAL takes two words) type_string (for each unboxed argument) graph_i (of first unboxed value)
	| StringLeaf !Int !Int !StringInfo				// length stringP of string info
	| Dynamic !Int !Int !Int !String !Int			// n_boxed_args (superfluous = length of children) extra_info size_of_unboxed_args (REAL takes two words) type_string (for each unboxed argument) graph_i (of first unboxed value)
	| ArrayNode !Int !Int !ArrayElement !Int !ArrayInfo 		// array_size elem_size element array_elem_start(graph_i)
	;
	
instance ToInfo NodeKind;
	
compute_nodes :: !*DescriptorAddressTable !BinaryDynamic !*DDState -> *(!*Nodes NodeKind,!*DescriptorAddressTable,!*DDState);

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
	
instance DefaultElem RecordArgsInfo;
	
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


:: StringInfo
	= {
		si_string			:: !String
	};
	
	
// if ArrayElementDescriptor is a
// - AED_BasicValue, then |ai_record_args_info| == 1 and rai_unboxed_args contains the unboxed
//   contents of the array.
// - AED_Boxed, then |ai_record_args_info| == 1 and rai_boxed_args contains the boxed contents
//   of the array.
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

get_nodes :: !*(Nodes a) -> *(.{#Node a},*Nodes b);
