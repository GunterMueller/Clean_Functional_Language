implementation module read_dynamic;

import
	StdEnv;
	
import dynamics;
import StdDynamicLowLevelInterface;
import directory_structure;
import ExtArray;
import StdDynamicTypes;

:: BinaryDynamic = {
		header					:: !DynamicHeader
	,	graph					:: !String

	// string version (obsolete)
	,	stringtable				:: !String
	,	descriptortable			:: !String
	
	//  using StdDynamicLowLevelInterface
	,	block_table				:: !BlockTable
	,	block_table_as_string	:: !String
	,	descriptor_usage_table	:: !DescriptorUsageTable
	,	bd_dynamic_info			:: !DynamicInfo
	};

instance DefaultElem BinaryDynamic
where {
	default_elem
		= DefaultBinaryDynamic;
};
		
DefaultBinaryDynamic :: BinaryDynamic;
DefaultBinaryDynamic
	= {	BinaryDynamic |
		header					= default_dynamic_header
	,	graph					= ""

	// string version (obsolete)
	,	stringtable				= ""
	,	descriptortable			= ""
	
	//  using StdDynamicLowLevelInterface
	,	block_table				= default_block_table
	,	block_table_as_string	= {}
	,	descriptor_usage_table	= default_descriptor_usage_table
	,	bd_dynamic_info			= default_elem
	};
	
import RWSDebugChoice;

read_dynamic :: !String !String !*Files -> ((!Bool,!BinaryDynamic),!*Files);
read_dynamic file_name ddir files
	#! ((ok1,dynamic_header,graph,stringtable,descriptortable),files)
		= read_dynamic_as_binary file_name True files;
	| not ok1
		= ((ok1,DefaultBinaryDynamic),files);
		
	// read descriptor usage table (and block table)
	#! (ok2,dynamic_header=:{n_nodes},file,files)
		= open_dynamic_as_binary file_name files;
		
	#! (ok3,descriptor_usage_table,file)
		= read_descriptor_usage_table_from_dynamic dynamic_header file;
			
	#! (ok4,block_table,block_table_as_string,file)
		= case (DYNAMIC_CONTAINS_BLOCKTABLE dynamic_header) of {
			True
				#! (ok,block_table,file)
					= read_block_table_from_dynamic dynamic_header file;
				#! (ok2,block_table_as_string,file)
					= read_block_table_as_string_from_dynamic dynamic_header file;
				-> (ok&&ok2,block_table,block_table_as_string,file);
			False
				// no blocktable
				-> (True,default_block_table,{},file);
			};


	#! (ok5,dynamic_info,file)
		= read_rts_info_from_dynamic dynamic_header file;

	#! dynamic_info
		= FILE_IDENTIFICATION 
			{ dynamic_info & di_library_index_to_library_name = { APPEND_LIBRARY_PATH ddir id \\ id <-: dynamic_info.di_library_index_to_library_name } }
			dynamic_info;
			
	#! (ok6,files)
		= close_dynamic_as_binary file files;
	
	#! default_binary_dynamic
		= { DefaultBinaryDynamic &
			header					= dynamic_header
		,	graph					= graph
			
		// string version (obsolete)
		,	stringtable				= stringtable
		,	descriptortable			= descriptortable
		
		//  using StdDynamicLowLevelInterface
		,	block_table				= block_table
		,	block_table_as_string	= block_table_as_string
		,	descriptor_usage_table	= descriptor_usage_table
		,	bd_dynamic_info			= dynamic_info
		};
	= ((ok1&&ok2&&ok3&&ok4&&ok5&&ok6,default_binary_dynamic),files);
