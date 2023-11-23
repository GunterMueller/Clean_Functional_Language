implementation module PlatformLinkOptions;

/* Memory/File layout (except for executable prefix and .loader) of the produced pef-executable: 

	Note 
	***(p)//	= p bytes alignment in file
	///(n)// 	= n bytes alignment in memory (and hence in file)

	Sections:	Layout:			Offsets:						Sizes:							Associated functions:
						
	.text		-----------		0
				xcoff #1					
				   .																		 	write_to_pef_files2 0 WriteText
				   .
				xcoff #n
				-----------		pef_text_section_size0			|
								 								|	24 * n_imported_symbols		write_imported_library_functions_code
				-----------		pef_text_section_size1			|
				***(16)****
	.data		-----------		0								|
																|	4 * n_imported_symbols		write_zero_longs_to_file
				-----------		4 * n_imported_symbols			|
				TOC xcoff#1		
					.
					.																			write_to_pef_files2 0 WriteTOC
				TOC xcoff#n		pef_toc_section_size0
				-----------
				initialized																		write_to_pef_files2 0 WriteData
				   data
				-----------		pef_data_section_size0
				////(4)////
				-----------		pef_data_section_size1
				uninialized																		write_zero_longs_to_file
				    data
				-----------		pef_bss_section_end0
				////(4)////
				-----------		pef_bss_section_end1
				***(16)****							
	.loader			etc.
*/
	
// mac specific
import StdInt,StdClass,StdFile,StdArray,StdBool,StdChar,StdString,StdMisc,StdTuple;
import mac_types,resources,memory,structure,files,pointer;
import NamesTable, Sections;
import pefConstants;
import LinkerOffsets;
import LoaderSection;
import ExtFile;
import CommonObjectToDisk;
import LinkerOffsets;

import DebugUtilities;

post_process :: !*State !*PlatformLinkOptions !*Files -> (!Bool,![!String],!*State,!*PlatformLinkOptions,!*Files);
post_process state=:{application_name} platform_link_options=:{offsets={end_bss_offset_a=pef_application_size}     /*pef_bss_section_end1=pef_application_size*/} files

	// create datafork (MAC only)
	#! (ok,platform_link_options,files) 
		= create_application_resource application_name pef_application_size platform_link_options files;
	| not ok
		= (False,["Link error while writing resource"],state,platform_link_options,files);

		= (True,[],state,platform_link_options,files);

// mac specific
:: *PlatformLinkOptions = {
	// mac specific; resource fork
		font_info							:: !(!Int, !{#Char})
	,	heap_size							:: !Int
	,	heap_size_multiple					:: !Int
	,	stack_size							:: !Int
	,	flags								:: !Int
	,	extra_application_memory			:: !Int
	,	initial_heap_size					:: !Int
	,	memory_profile_minimum_heap_size	:: !Int
	,	generate_xcoff						:: !Bool
	
	// general
	,	start_rva							:: !Int
	,	end_rva								:: !Int
	,	start_fp							:: !Int
	,	end_fp								:: !Int
	
	,	n_image_sections					:: !Int
	,	section_header_a					:: *{!SectionHeader}
	
	,	n_imported_symbols					:: !Int
	
	, 	sections							:: *Sections
	
	, 	main_file_n							:: !Int
	,	main_symbol_n						:: !Int
	
	// .loader
	,	n_loader_relocations				:: !Int
	, 	loader_relocations					:: *LoaderRelocations
	,	string_table_file_names_size		:: !Int
	,	string_table_symbol_names_size		:: !Int
	
	// offsets
	,	offsets								:: !Offset
	
/*
	// .text
	,	pef_text_section_size0				:: !Int
	,	pef_text_section_size1				:: !Int
	
	// .data
	,	pef_data_section_size0				:: !Int
	,	pef_data_section_size1				:: !Int
*/
	,	data_sections						:: !{*{#Char}}

/*	
	// .bss
	,	pef_bss_section_end0				:: !Int
	,	pef_bss_section_end1				:: !Int
*/
	
	};
/*
pef_text_section_size0,pef_text_section_size1,pef_data_section_size0,pef_data_section_size1,pef_bss_section_end0

*/	
DefaultPlatformLinkOptions :: !PlatformLinkOptions;
DefaultPlatformLinkOptions 
	= { PlatformLinkOptions |
	// mac specific; resource fork
		font_info							= (9,"Monaco")
	,	heap_size							= 0x200000
	,	heap_size_multiple					= 16
	,	stack_size							= 0x80000
	,	flags								= 8
	,	extra_application_memory			= (80<<10)
	,	initial_heap_size					= 0x200000
	,	memory_profile_minimum_heap_size	= 0
	,	generate_xcoff						= False
	
	// general
	,	start_rva							= 0
	,	end_rva								= 0
	,	start_fp							= 0
	,	end_fp								= 0
	
	,	n_image_sections					= 0
	,	section_header_a					= {}
	
	, 	n_imported_symbols					= 0
	
	,	sections							= EndSections
	
	,	main_file_n							= 0
	,	main_symbol_n						= 0
	
	// .loader
	,	n_loader_relocations				= 0
	,	loader_relocations					= undef
	,	string_table_file_names_size		= 0
	,	string_table_symbol_names_size		= 0
	
	// offsets
	,	offsets								= DefaultOffset
	
/*
	// .text
	,	pef_text_section_size0				= 0
	,	pef_text_section_size1				= 0
	
	// .data
	,	pef_data_section_size0				= 0
	,	pef_data_section_size1				= 0
*/
	,	data_sections						= {}

/*	
	// .bss
	,	pef_bss_section_end0				= 0
	,	pef_bss_section_end1				= 0
*/
	};

// Accessors; set's (all dup)
plo_set_end_rva :: !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_end_rva end_rva platform_link_options
	= { platform_link_options &
		end_rva						= end_rva
	};
	
plo_set_end_fp  :: !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_end_fp end_fp platform_link_options
	= { platform_link_options &
		end_fp						= end_fp
	};

plo_set_s_raw_data :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_s_raw_data s_raw_data i_section_header platform_link_options
	= appSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> {section_header_a & [i_section_header] = sh_set_s_raw_data s_raw_data section_header}) platform_link_options;

plo_set_fp_section :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_fp_section fp_section i_section_header platform_link_options
	= appSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> {section_header_a & [i_section_header] = sh_set_fp_section fp_section section_header}) platform_link_options;
	
plo_set_sections :: Sections !*PlatformLinkOptions  -> !*PlatformLinkOptions;
plo_set_sections sections platform_link_options 
	= { platform_link_options & sections = sections };

plo_set_main_file_n_and_symbol_n :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_main_file_n_and_symbol_n main_file_n main_symbol_n platform_link_options
	= {platform_link_options &
		main_file_n		= main_file_n
	,	main_symbol_n	= main_symbol_n
	};

// Accessors; get's
plo_get_start_fp :: !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_start_fp platform_link_options=:{start_fp}
	= (start_fp,platform_link_options);
	
plo_get_start_rva :: !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_start_rva platform_link_options=:{start_rva}
	= (start_rva,platform_link_options);
	
plo_get_sections :: !*PlatformLinkOptions -> !(!*Sections,!*PlatformLinkOptions);
plo_get_sections platform_link_options=:{sections}
	= (sections,{platform_link_options & sections = EndSections});
	
plo_get_pef_bss_section_end1 ::  !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_pef_bss_section_end1 platform_link_options=:{offsets={end_bss_offset_a=pef_bss_section_end1}}
	= (pef_bss_section_end1,platform_link_options);

plo_get_section_fp :: !Int !*PlatformLinkOptions -> !(!Int,!*PlatformLinkOptions);
plo_get_section_fp i_section_header platform_link_options
	= accSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> 
	(sh_get_fp_section section_header,section_header_a)) platform_link_options;

/*
plo_set_fp_section :: !Int !Int !*PlatformLinkOptions -> !*PlatformLinkOptions;
plo_set_fp_section fp_section i_section_header platform_link_options
	= appSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> {section_header_a & [i_section_header] = sh_set_fp_section fp_section section_header}) platform_link_options;
*/	

// dup
apply_generate_section :: !Int *File !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!*File,!*PlatformLinkOptions,!*State,!*Files);
apply_generate_section i pe_file platform_link_options state files
	#! (generate_section,platform_link_options)
		= get_generate_section i platform_link_options;
	#! (pe_file,platform_link_options,state,files)
		= generate_section pe_file platform_link_options state files;
		
	// 
	#! (section_header,platform_link_options)
		= accSectionHeader_a (\section_header_a=:{[i] = section_header} -> (section_header,section_header_a)) platform_link_options
		
	= (sh_get_is_virtual_section section_header,sh_get_s_virtual_data section_header,sh_get_s_raw_data section_header,pe_file,platform_link_options,state,files);

apply_compute_section :: !Int !Int !Int !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!Int,!Int,!*State,!*PlatformLinkOptions,!*Files);
apply_compute_section i start_rva fp platform_link_options state files
	#! (compute_section,platform_link_options)
		= get_compute_section i platform_link_options;

	// unpack section_header
	#! (section_header,platform_link_options)
		= accSectionHeader_a (\section_header_a=:{[i] = section_header} -> (section_header,section_header_a)) platform_link_options;
	#! (i_section_header,section_header,state,platform_link_options,files)
		= compute_section start_rva fp i section_header state platform_link_options files;

	// pack updated section_header
	#! platform_link_options
		= appSectionHeader_a (\section_header_a -> {section_header_a & [i] = section_header}) platform_link_options;
			
	= (sh_get_is_virtual_section section_header,i_section_header,sh_get_s_virtual_data section_header,sh_get_alignment section_header,sh_get_s_raw_data section_header,state,platform_link_options,files);
	

get_generate_section :: !Int !*PlatformLinkOptions -> (GenerateSectionType,!*PlatformLinkOptions);
get_generate_section section_header_i platform_link_options
	# (generate_section,platform_link_options)
		= accSectionHeader_a (\section_header_a=:{[section_header_i] = section_header} -> (sh_get_generate_section section_header,section_header_a)) platform_link_options;
	= (generate_section,platform_link_options);
	


get_compute_section :: !Int !*PlatformLinkOptions -> (ComputeSectionType,!*PlatformLinkOptions);
get_compute_section section_header_i platform_link_options
	# (compute_section,platform_link_options)
		= accSectionHeader_a (\section_header_a=:{[section_header_i] = section_header} -> (sh_get_compute_section section_header,section_header_a)) platform_link_options;
	= (compute_section,platform_link_options);
	
accSectionHeader_a :: !.(*{!SectionHeader} -> (.x,*{!SectionHeader})) !*PlatformLinkOptions -> (!.x,PlatformLinkOptions);
accSectionHeader_a f platform_link_options=:{section_header_a} 
	# (ss,section_header_a)
		= usize section_header_a;
	| ss == 0
		= abort "accSectionHeader";
	# (x,section_header_a)
		= f section_header_a;
	= (x,{ platform_link_options & section_header_a = section_header_a } );
	
appSectionHeader_a :: !.(*{!SectionHeader} -> *{!SectionHeader}) !*PlatformLinkOptions -> !*PlatformLinkOptions;
appSectionHeader_a f platform_link_options=:{section_header_a}
		# (ss,section_header_a)
		= usize section_header_a;
	| ss == 0
		= abort "appSectionHeader";
	
	=  { platform_link_options & section_header_a = f section_header_a };
// dup

create_section_header_kinds :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
create_section_header_kinds platform_link_options
	#! s_section_header_a
		= n_standard_sections;
	#! section_header_a
		= standard_section_header 0 s_section_header_a (createArray s_section_header_a DefaultSectionHeader);
	# platform_link_options 
		= { platform_link_options &
			section_header_a		= section_header_a
		,	n_image_sections		= dec s_section_header_a 
		};
	= (s_section_header_a,platform_link_options);
where {
	n_standard_sections
		= 1 /* StartPrefix */ + 3 /* {.text,.data,.loader} */;
	standard_section_header i=:0 limit section_header_a
		# dsh = DefaultSectionHeader
			DSH sh_set_kind StartPrefix
			DSH sh_set_alignment 16											// file alignment of section
			DSH sh_set_compute_section compute_start_prefix
			DSH sh_set_generate_section generate_start_prefix
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh };
		
	standard_section_header i=:1 limit section_header_a
		# pd_section_header
			= { DefaultPDSectionHeader &
				region_kind 			= 0
			,	sharing_kind			= 1
			,	memory_alignment		= 2									// halfword (2^1) alignment
			};	
		# dsh = DefaultSectionHeader
			DSH sh_set_kind TextSectionHeader
			DSH sh_set_alignment 16
			DSH sh_set_compute_section compute_text_section_header
			DSH sh_set_generate_section generate_text_section_header
			DSH sh_set_pd_section_header pd_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh };
			
	standard_section_header i=:2 limit section_header_a
		# pd_section_header
			= { DefaultPDSectionHeader &
				region_kind 			= 1
			,	sharing_kind			= 1
			,	memory_alignment		= 3									// byte (2^0) alignment
			};	
		# dsh = DefaultSectionHeader
			DSH sh_set_kind DataSectionHeader
			DSH sh_set_alignment 16
			DSH sh_set_compute_section compute_data_section_header
			DSH sh_set_generate_section generate_data_section_header
			DSH sh_set_pd_section_header pd_section_header
			;	
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh };
			
	standard_section_header i=:3 limit section_header_a
		# pd_section_header
			= { DefaultPDSectionHeader &
				region_kind 			= 4
			,	sharing_kind			= 1
			,	memory_alignment		= 0									// doubleword (2^3) alignment
			};	
		# dsh = DefaultSectionHeader
			DSH sh_set_kind LoaderSectionHeader
			DSH sh_set_alignment 16
			DSH sh_set_compute_section compute_loader_section_header
			DSH sh_set_generate_section generate_loader_section_header
			DSH sh_set_pd_section_header pd_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh };
	
	standard_section_header i limit section_header_a
		| i == limit
			= section_header_a;			
}


// symboltable

q platform_link_options=:{sections}
	= (sections,{platform_link_options & sections = EndSections});
	
// ------------------------------------------------------------------------------------------------------------------------------------------------------------
// COMPUTE

// compute_start_prefix :: ComputeSectionType;
compute_start_prefix :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_start_prefix start_rva fp i_start_prefix_section_header start_prefix 
	state=:{n_library_symbols,library_list,n_xcoff_symbols,marked_bool_a,marked_offset_a,xcoff_a,n_xcoff_files}
	platform_link_options=:{n_image_sections} files

	// compute start prefix size
	#! start_prefix_size
		= s_container_header + (n_image_sections * s_section_header) + 4;
	#! start_prefix
		= sh_set_virtual_data start_prefix_size start_prefix;
	
	// compute stringtable size for .loader and # imported symbols
	#! (string_table_file_names_size,string_table_symbol_names_size,n_imported_symbols,marked_bool_a)
		= compute_pef_string_table_size library_list 0 0 0 n_xcoff_symbols marked_bool_a;
	#! xcoff_list 
		= xcoff_array_to_list 0 xcoff_a;
		
	//# sections = EndSections;
	#! (sections,platform_link_options)
		= q platform_link_options;
	
	// remove unnecessary data from symboltable; (should probably be switched off in case of an eager link)	
//	#! (sections,xcoff_list,/*toc_table*/ _ ,marked_offset_a,marked_bool_a)
//		= split_data_symbol_lists_of_files2 marked_offset_a marked_bool_a sections xcoff_list EmptyTocTable;

	#! xcoff_list
		= [split_data_symbol_lists_without_removing_unmarked_symbols xcoff \\ xcoff <- xcoff_list ] 
		
	// compute offsets of sections

	// NEW	
	// restore state
	#! state
		= { state &
			library_list			= library_list
		,	marked_bool_a			= marked_bool_a
		,	marked_offset_a			= marked_offset_a
		,	module_offset_a			= createArray (n_xcoff_symbols + n_library_symbols) 0
		,	xcoff_a					= xcoff_list_to_array n_xcoff_files xcoff_list
	};
	
	#! (end_offset,state)
		= compute_offsets2 0 /* base */ state (sections_specification /* MPM False*/ True n_imported_symbols);
//	| True
//		= abort (toString end_offset);

//	#! (pef_text_section_size0,pef_text_section_size1,pef_data_section_size0,pef_data_section_size1,pef_bss_section_end0
//	    ,library_list,module_offset_a,xcoff_list,marked_bool_a)
//		= compute_offsets n_xcoff_symbols n_library_symbols n_imported_symbols library_list xcoff_list marked_bool_a;

/*
	# pef_bss_section_end1 
		= (pef_bss_section_end0+3) bitand (-4);
*/		
	#! platform_link_options 
		= { platform_link_options &
		// .loader
			string_table_file_names_size 		= string_table_file_names_size
		,	string_table_symbol_names_size 		= string_table_symbol_names_size
		
		// general
		,	n_imported_symbols					= n_imported_symbols
				
		, 	sections							= sections
		
		// offsets
		,	offsets								= end_offset

/*		// .text
		,	pef_text_section_size0				= pef_text_section_size0
		,	pef_text_section_size1				= pef_text_section_size1
		
		// .data
		,	pef_data_section_size0				= pef_data_section_size0
		,	pef_data_section_size1				= pef_data_section_size1
		
		// .bss
		,	pef_bss_section_end0				= pef_bss_section_end0
		,	pef_bss_section_end1				= pef_bss_section_end1
*/

		};

/*
	// restore state
	#! state
		= { state &
			library_list			= library_list
		,	marked_bool_a			= marked_bool_a
		,	marked_offset_a			= marked_offset_a
		,	module_offset_a			= module_offset_a
		,	xcoff_a					= xcoff_list_to_array n_xcoff_files xcoff_list
	};
	*/

	= (i_start_prefix_section_header,start_prefix,state,platform_link_options,files);
where {
	compute_pef_string_table_size :: LibraryList Int Int Int Int !*{#Bool} -> (!Int,!Int,!Int,!*{#Bool});
	compute_pef_string_table_size EmptyLibraryList string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
		= (string_table_file_names_size,string_table_symbol_names_size0,n_imported_symbols0,marked_bool_a);
	compute_pef_string_table_size (Library file_name imported_symbols _ libraries) string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a
		#! (string_table_symbol_names_size1,n_imported_symbols1,symbol_n1,marked_bool_a)
			= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a;
		=	compute_pef_string_table_size libraries (1 + size file_name + string_table_file_names_size) string_table_symbol_names_size1 n_imported_symbols1 symbol_n1 marked_bool_a;
		{
			string_table_size_of_symbol_names :: LibrarySymbolsList Int Int Int !*{#Bool} -> (!Int,!Int,!Int,!*{#Bool});
			string_table_size_of_symbol_names EmptyLibrarySymbolsList string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
				= (string_table_symbol_names_size0,n_imported_symbols0,symbol_n, marked_bool_a);
			string_table_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
				| marked_bool_a.[symbol_n]
					= string_table_size_of_symbol_names imported_symbols (1 + size symbol_name + string_table_symbol_names_size0) (inc n_imported_symbols0) (symbol_n+2) marked_bool_a;
					= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 (symbol_n+2) marked_bool_a;
		}
}

/*
		- compute size
		- fill in platform dependent section header
	*/
	
// compute_text_section_header :: ComputeSectionType;
compute_text_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_text_section_header start_rva fp i_text_section_header text_section_header state platform_link_options=:{offsets={end_text_offset=pef_text_section_size1}} files
	#! pd_section_header
		= { sh_get_pd_section_header text_section_header &
			exec_size			= pef_text_section_size1
		,	init_size			= pef_text_section_size1
	};
	
	#! text_section_header = text_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data pef_text_section_size1;
	= (i_text_section_header,text_section_header,state,platform_link_options,files);

// compute_data_section_header :: ComputeSectionType;
compute_data_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_data_section_header start_rva fp i_data_section_header data_section_header state platform_link_options=:{offsets={end_bss_offset_a=pef_bss_section_end1}} files
	#! pd_section_header
		= { sh_get_pd_section_header data_section_header &
			exec_size			= pef_bss_section_end1
		,	init_size			= pef_bss_section_end1
	};
	
	#! data_section_header = data_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data pef_bss_section_end1;
	= (i_data_section_header,data_section_header,state,platform_link_options,files);

// compute_loader_section_header :: ComputeSectionType;
compute_loader_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_loader_section_header start_rva fp i_loader_section_header loader_section_header 
	state=:{n_libraries} 
	platform_link_options=:{n_imported_symbols,string_table_file_names_size,string_table_symbol_names_size} files
	// compute loader section
	#! (i,loader_relocations0,state) 
		= compute_pef_loader_relocations2 n_imported_symbols state;		
	#! (n_loader_relocations,loader_relocations) 
		= count_and_reverse_relocations loader_relocations0;

	// compute & align .loader stringtable
	#! string_table_size
		= string_table_file_names_size+string_table_symbol_names_size;
	#! aligned_string_table_size=(string_table_size+3) bitand (-4);


	// compute .loader size
	#! pef_loader_section_size 
		= 56 + 24 * n_libraries+(n_imported_symbols<<2)+(n_loader_relocations<<1)+12+aligned_string_table_size+4;
	#! pd_section_header
		= { sh_get_pd_section_header loader_section_header &
			exec_size			= 0
		,	init_size			= 0
	};
	
	#! loader_section_header = loader_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data pef_loader_section_size;
		
	// update platform_link_options
	#! platform_link_options
		= { platform_link_options &
			n_loader_relocations		= n_loader_relocations
		,	loader_relocations			= loader_relocations
		};
	= (i_loader_section_header,loader_section_header,state,platform_link_options,files);
		
// GENERATE
(FWW2) infixl
(FWW2) f i :== fwritec (toChar (i>>8)) (fwritec (toChar i) f);

generate_start_prefix :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_start_prefix pef_file platform_link_options state files
	# pef_file
		= write_container_header pef_file;
	
	# (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;	
	#! (pef_file,section_header_a)
		= write_section_headers pef_file section_header_a;
	#! pef_file
		= write_string_table pef_file;
	#! (i,pef_file)
		= fposition pef_file;
	= (pef_file,{platform_link_options & section_header_a = section_header_a},state,files);
where {
	write_string_table pef_file
		# pef_file = pef_file 
			FWI 0;
		= pef_file;
		
	write_container_header pef_file
		#! pef_file = pef_file 
			FWS "Joy!"		// magic1 and magic2
			FWS "peff"		// container identifier
			FWS "pwpc"		// architecture identifier {m68k,pwpc}
			FWI 1 			// Version (1)
			FWI 0 			// Date/time stamp
			FWI 0 			// Old definition version
			FWI 0 			// Old implementation version
			FWI 0 			// Current version number
			FWW 3			// Number of sections
			FWW 2			// Number of loadable (executable) sections e.i. number of first non-loadable section !!!!! SHOULD BE ADAPTED
			FWI 0			// 0
			;
		= pef_file;
		
	// COULD BE SHARED
	write_section_headers :: !*File !*{!SectionHeader} -> (!*File,!*{!SectionHeader});
	write_section_headers pe_file section_header_a
		# (s_section_header_a,section_header_a)
			= usize section_header_a;
		= foldl write (pe_file,section_header_a) [0..dec s_section_header_a];
	where {
		write (pe_file,section_header_a) i
			# (section_header,section_header_a)
				= section_header_a![i];
//			| F ("write (" +++ toString i +++ ") " +++ toString (sh_get_kind section_header)) True
			
			| (sh_get_kind section_header) == StartPrefix
				= (pe_file,section_header_a);


				# pe_file
					= write_section i section_header pe_file;
				= (pe_file,section_header_a);
				//= abort "sdkdkkd";
/*
				// create section
				#! pad_zero_bytes
					= createArray s_section_name '\0';
				#! padded_section_name
					= ((pd_get_section_name section_header) +++ pad_zero_bytes) % (0,dec s_section_name);
				#! pe_file = pe_file
					FWS padded_section_name							// section name
					FWI	sh_get_s_virtual_data section_header		// virtual section size
					FWI pd_get_section_rva section_header			// rva of section
					FWI sh_get_s_raw_data section_header			// raw data size (multiple of File Align)
					FWI sh_get_fp_section section_header			// raw data (file) pointer
					FWI 0											// pointer to relocations 
					FWI 0											// pointer to linenumbers
					FWW 0											// number of relocations 
					FWW 0											// number of linenumbers 
					FWI pd_get_section_flags section_header			// section flags
				= (pe_file,section_header_a);	
*/
	}
	/*
	// Mac dependent part of section header
:: PDSectionHeader = {
		exec_size				:: !Int
	,	init_size				:: !Int
	,	region_kind				:: !Int
	,	sharing_kind			:: !Int
	,	memory_alignment		:: !Int			// in memory
	};
	*/
	
	// platform dependent
	write_section i section_header pef_file
		# {exec_size,init_size,region_kind,sharing_kind,memory_alignment}
			= sh_get_pd_section_header section_header;
/*
		# s
			= "write_section " +++ toString i +++ " - " +++ toString (sh_get_kind section_header) 
				+++ "\nfp: " +++ toString (sh_get_fp_section section_header)
				+++ "\nexec_size: " +++ toString exec_size
				+++ "\ninit_size: " +++ toString init_size
				+++ "\nraw size "+++ toString (sh_get_s_virtual_data section_header)
				;
			
		| F s True
*/
		# pef_file = pef_file
			FWI (-1)												// section name 
			FWI 0													// section_address
			FWI exec_size											// exec size
			FWI init_size											// init size
			FWI sh_get_s_virtual_data section_header				// raw size
			FWI sh_get_fp_section section_header					// container offset
			FWB region_kind											// region kind
			FWB sharing_kind										// sharing kind
			FWB memory_alignment									// memory alignment
			FWB 0													// reserved
			;
		= pef_file;
}

generate_text_section_header :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_text_section_header pef_file platform_link_options state=:{n_xcoff_files,n_xcoff_symbols,library_list} files
	# (sections,platform_link_options)
		= q platform_link_options;
	# ((_,data_sections,pef_file, state),files)
		= write_to_pef_files2 0 WriteText { {} \\ i <- [1..n_xcoff_files]} 0 0 state sections pef_file files;
//	# pef_file
//		= write_imported_library_functions_code library_list 0 pef_file;

	# (pef_file,state)
		= write_imported_library_functions_code /*library_list*/ 0 pef_file n_xcoff_symbols state;
		
	// update platform_link_options
	#! platform_link_options
		= { platform_link_options &
			data_sections = data_sections
	};
	= (pef_file,platform_link_options,state,files);
where {
	q :: !*PlatformLinkOptions -> (!*Sections,!*PlatformLinkOptions);
	q platform_link_options=:{sections}
		= (sections,{platform_link_options & sections = EndSections});
}

generate_data_section_header :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_data_section_header pef_file 
	platform_link_options=:{
	offsets={end_bss_offset_a=pef_bss_section_end1,
			 end_data_offset=pef_data_section_size0,
			 		begin_bss_offset=pef_data_section_size1,
			 		end_bss_offset=pef_bss_section_end0}
	
	,data_sections,n_imported_symbols} 
	state=:{n_xcoff_files} files

	// imported symbols
	# pef_file
		= write_zero_longs_to_file n_imported_symbols pef_file;

	# (data_sections,platform_link_options)
		= q platform_link_options;
	# ((end_toc_offset,data_sections,pef_file,state),files)
		= write_to_pef_files2 0 WriteTOC data_sections 0 (n_imported_symbols<<2) state EndSections pef_file files;
	# ((_,_,pef_file,state),files)
		= write_to_pef_files2 0 WriteData data_sections 0 end_toc_offset state EndSections pef_file files;

	// align uninitialized data on 4 byte boundary
	# pef_file
		= write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0) pef_file;

	// write uninitialized data (all zeroes) and round up to a multiple of 4
//	# pef_bss_section_end1 
//		= (pef_bss_section_end0+3) bitand (-4);

//	| True
//		= abort (toString pef_data_section_size0 +++ " - " +++ toString pef_data_section_size0);

	# pef_file
		= write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2) pef_file;
	= (pef_file,/*{ platform_link_options & pef_bss_section_end1 = pef_bss_section_end1}*/platform_link_options,state,files);
where {
	q :: !*PlatformLinkOptions -> (!{*{#Char}},!*PlatformLinkOptions);
	q platform_link_options=:{data_sections}
		= (data_sections,{platform_link_options & data_sections = {}});
}

generate_loader_section_header :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_loader_section_header pef_file 
	platform_link_options=:{n_loader_relocations,main_file_n,main_symbol_n,n_imported_symbols,string_table_file_names_size,string_table_symbol_names_size}
	state=:{library_list,n_libraries} files

	// compute main_offset
	# (i_marked_offset_a,state)
		= selacc_marked_offset_a main_file_n state;
	# (main_offset,state)
		= selacc_module_offset_a (i_marked_offset_a + main_symbol_n) state;

	#! (loader_relocations,platform_link_options)
		= select_loader_relocations platform_link_options;


	#! (state,pef_file)
		= write_pef_loader n_imported_symbols string_table_file_names_size string_table_symbol_names_size main_offset n_loader_relocations loader_relocations state pef_file;
		
//	#! pef_file
//		= write_pef_loader library_list n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size main_offset n_loader_relocations loader_relocations pef_file;
	= (pef_file,platform_link_options,state,files);
where {
	select_loader_relocations platform_link_options=:{loader_relocations}
		= (loader_relocations,{ platform_link_options & loader_relocations = undef});

}
find_root_symbols :: *{!NamesTableElement} !*PlatformLinkOptions -> *(.Bool,Int,Int,.Bool,[(.Bool,{#Char},Int,Int)],*{!NamesTableElement},*PlatformLinkOptions);
find_root_symbols names_table platform_link_options
	// find root symbols which are main entry and any exported symbols
	# main_entry
		= "main";
	# (main_entry_names_table_element,names_table)
		= find_symbol_in_symbol_table main_entry names_table;

	// INSERT HERE SHARED OBJECT SUPPORT
	# all_exported_symbols_found
		= True;
	# entry_datas
		= [];

	// collect results
	# (main_entry_found,main_file_n,main_symbol_n)
		= has_main_entry_been_found main_entry_names_table_element;		
	= (main_entry_found,main_file_n,main_symbol_n,			// main entry
	   all_exported_symbols_found,entry_datas,				// exported symbols (found,symbol_name,file_n,symbol_n)
	   names_table,											// names table
	   platform_link_options);								// platform dependent link options
where {
	has_main_entry_been_found (NamesTableElement _ main_symbol_n main_file_n _)
		= (True,main_file_n,main_symbol_n);
	has_main_entry_been_found _
		= (False,undef,undef);
}
	

/*
// resources; mac specific
create_application_resource2 :: !{#Char} !Int /*(!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int*/ PlatformLinkOptions !*Files -> (!Bool,!*Files);
create_application_resource2 file_name pef_application_size {font_info,heap_size,heap_size_multiple,stack_size,flags,extra_application_memory /*application_and_extra_memory_size*/,initial_heap_size,memory_profile_minimum_heap_size} /*font_info heap_size heap_size_multiple stack_size flags application_and_extra_memory_size initial_heap_size memory_profile_minimum_heap_size*/ files
	| error_n<>0
		= (False,files);
	| ref_num==(-1)
		= (False,files);
	| res_error<>0 /* || not ok0 */ || not ok1 || not ok2 || not ok3 || not ok4
		= (False,files);
		= (True,files);
{}{
	application_and_extra_memory_size
		= pef_application_size + extra_application_memory; 
		
		
	(res_error,_)=ResError (CloseResFile ref_num t8);

	(ok5,t8)=add_font_resource font_info t7;
	(ok4,t7)=add_prfl_resource 0 t6;

//	(ok3,t6)=add_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
	(ok3,t6)=change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
	(ok2,t5)=add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t4;
	(ok1,t4)=add_cfrg_resource file_name t2;
/*
	(ok1,t4)=add_code1_resource t3;
	(ok0,t3)=add_code0_resource t2;
*/
	(ref_num,t2)=open_resource_file t1;

	(error_n,t1)=SetFileType "APPL" file_name NewToolbox;
	/*
	(error_n,t1)=SetFileTypeAndCreator "APPL" null_string4 file_name NewToolbox;
	null_string4=null_string2+++null_string2;
	null_string2=null_string1+++null_string1;
	null_string1=toString '\0';
	*/
	
	open_resource_file t0
		| ref_num0<>(-1)
			= (ref_num0,t2); {
				t2 = t1
						THEN remove_resource "PRFL" 128
						THEN remove_resource "Font" 128
//						THEN remove_resource "SIZE" (-1)
						THEN remove_resource "SIZE" 0
						THEN remove_resource "SIZE" 1
						THEN remove_resource "STHP" 0
						THEN remove_resource "cfrg" 0;
			}
			= HOpenResFile 0 0 file_name 3 (HCreateResFile 0 0 file_name t1);
		{}{
			(ref_num0,t1)=HOpenResFile 0 0 file_name 3 t0;
		}
}

remove_resource resource_name n t0
	| handle==0
		= t1;
		= RemoveResource handle t1;
	{}{
		(handle,t1)=Get1Resource resource_name n t0;
	}

add_cfrg_resource :: String *Int -> (!Bool,!*Int);
add_cfrg_resource file_name t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_cfrg_handle file_name handle) "cfrg" 0 "" t1);
		(handle,_,t1) = NewHandle (75+(size file_name)) t0;
	}

fill_cfrg_handle file_name handle
	= h1;
{
	(h1,_)=AppendString s20 file_name;
	s20=AppendByte s19 (file_name_length);
	s19=AppendWord s18 (file_name_length+75);
	s18=AppendLong s17 0;
	s17=AppendLong s16 0;
	s16=AppendLong s15 0;
	s15=AppendLong s14 0;
	s14=AppendLong s13 0x101;
	s13=AppendLong s12 0;
	s12=AppendLong s11 0;
	s11=AppendLong s10 0;
	s10=AppendLong s9 0;
	s9=AppendString s8 "pwpc";
	s8=AppendLong s7 1;
	s7=AppendLong s6 0;
	s6=AppendLong s5 0;
	s5=AppendLong s4 0;
	s4=AppendLong s3 0;
	s3=AppendLong s2 1;
	s2=AppendLong s1 0;
	s1=AppendLong s0 0;
	s0=HandleToStructure handle;
	
	file_name_length= size file_name;
}

/*
add_code0_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_0 handle) "CODE" 0 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_0) t0;
		code_resource_0=code_resource0;
	}

add_code1_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_1 handle) "CODE" 1 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_1) t0;
		code_resource_1=code_resource1;
	}

fill_resource_handle resource handle
	=	h;
	{
		(h,_) = add_strings_to_structure resource (HandleToStructure handle);
		
		add_strings_to_structure [] structure = structure;
		add_strings_to_structure [s:l] structure = add_strings_to_structure l (AppendString structure s);
	};
*/

add_prfl_resource :: Int *Int -> (!Bool,!*Int);
add_prfl_resource heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "PRFL" 128 "" t1);
		(handle2,_)=AppendLong s0 heap_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 4 t0;
	}

add_sthp_resource :: Int Int Int Int Int *Int -> (!Bool,!*Int);
add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "STHP" 0 "" t1);
		(handle2,_)=AppendLong s4 initial_heap_size;
		s4=AppendLong s3 flags;
		s3=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size_multiple;
		s1=AppendLong s0 stack_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 20 t0;
	}

change_size_resource :: Int *Int -> (!Bool,!*Int);
change_size_resource heap_size t
	# (flags,t)=get_size_flags_and_remove_resource t
	= add_size_resource flags heap_size t;

get_size_flags_and_remove_resource :: *Int -> (!Int, !*Int);
get_size_flags_and_remove_resource t
	# (handle,t)=Get1Resource "SIZE" (-1) t;
//	# t=test_res_error "Get1Resource" t
	| handle==0
		=(0,t);
	# (ptr,t)=DereferenceHandle handle t;
	# (flags,t)=LoadWord ptr t;
	# t=RemoveResource handle t
//	# t=test_res_error "RemoveResource" t
	= (flags,t);

test_res_error s t
	# (error_n,t)=ResError t
	| error_n<>0
		=	abort ("res error " +++ toString error_n +++ " " +++ s +++ "\n");
		=	t;

add_font_resource :: (Int, {#Char}) *Int -> (!Bool,!*Int);
add_font_resource (font_size, font_name) t0
	| font_size == 0 || font_name == ""
		= (True, t0)
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "Font" 128 "" t1);
		(handle2,_)=AppendString s2 font_name;
		s2=AppendByte s1 font_name_size;
		s1=AppendWord s0 font_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle (3 + font_name_size) t0;
		font_name_size = size font_name;
	}

add_size_resource :: Int Int *Int -> (!Bool,!*Int);
add_size_resource flags heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "SIZE" (-1) "" t1);
		(handle2,_)=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size;
		s1=AppendWord s0 flags;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 10 t0;
	}

read_application_options :: !{#Char} !*Files -> (!Bool,(!Int,!{#Char}),!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!*Files);
read_application_options file_name files
	# (pef_read, pef_size, files)
		=	read_pef_size_from_data_fork file_name files
	| not pef_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (ref_num, t)
		=	HOpenResFile 0 0 file_name 1 NewToolbox
	| ref_num == (-1)
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (size_read, _, minimum_size, t)
		=	read_size_resource t
	| not size_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (sthp_read, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t)
		=	read_sthp_resource t
	| not sthp_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (_, font_size, font_name, t)
		=	read_font_resource t
	# (_, profile_heap_size, t)
		=	read_prfl_resource t
	# (res_error, _)
		=	ResError (CloseResFile ref_num t);
	| res_error <> 0
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
		=	(True, (font_size, font_name), heap_size, heap_size_multiple, stack_size,
				flags, initial_heap_size, profile_heap_size, pef_size,
					minimum_size-heap_size-stack_size, files);

read_font_resource :: !*Toolbox -> (!Bool,!Int,!{#Char},!*Toolbox);
read_font_resource t
	# (handle,t)
		=	Get1Resource "Font" 128 t
	| handle==0
		=	(False, 0,"",t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (font_size, t) =	LoadWord ptr t;
	  ptr 	=	ptr+2;
	# (font_name_size, t) = LoadByte ptr t;
	  ptr	  	=	ptr+1;
	# (font_name, _, t)
		=	LoadString 0 font_name_size (createArray font_name_size ' ') ptr t;
	= (False, font_size, font_name, t);

read_size_resource :: *Int -> (!Bool,!Int,!Int,!*Int);
read_size_resource t
	# (handle,t)
		=	Get1Resource "SIZE" (-1) t
	| handle==0
		=	(False, 0, 0, t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (flags, t)=	LoadWord ptr t;
	  ptr	  	=	ptr+6; /* skip (long) size */
	# (minimum_size, t)
		=	LoadLong ptr t;
		=	(True, flags, minimum_size, t);

read_sthp_resource :: *Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
read_sthp_resource t
	# (handle,t)
		=	Get1Resource "STHP" 0 t
	| handle==0
		=	(False, 0, 0, 0, 0, 0, t);
	# (ptr, t)		=	DereferenceHandle handle t;
	# (stack_size, t)	=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (heap_size_multiple, t) =	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (heap_size, t)	=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (flags, t)		=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (initial_heap_size, t) =	LoadLong ptr t;
	=	(True, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t);

read_prfl_resource :: *Toolbox -> (!Bool,!Int,!*Toolbox);
read_prfl_resource t
	# (handle,t)		=	Get1Resource "PRFL" 128 t
	| handle==0
		=	(False, 0, t);
		# (ptr, t)		=	DereferenceHandle handle t;
		# (profile_heap_size, t)		=	LoadLong ptr t;
		= (True, profile_heap_size, t);

read_pef_size_from_data_fork :: {#Char} *Files -> (!Bool,!Int,!*Files);
read_pef_size_from_data_fork name files
	# (open,file,files) = fopen name FReadData files;
	| not open
		=	(False, 0, files);
	# (magic, file)		=	freads file 12;
	| magic <> "Joy!peffpwpc"
		=	(False, 0, snd (fclose file files));
	# (sought, file)		=	fseek file 0x30 FSeekSet;
	| not sought
		=	(False, 0, snd (fclose file files));
	# (read, pef_size, file)		=	freadi file;
	| not read
		=	(False, 0, snd (fclose file files));
	# (closed, files)		=	fclose file files;
	| not closed
		=	(False, 0, files);
		=	(True, pef_size, files);

LoadString :: Int Int *{#Char} Ptr *Toolbox -> (!*{#Char},Ptr,!*Toolbox);
LoadString n size string ptr t
	| n == size
		= (string, ptr, t);
		# (char, t) = LoadByte (ptr+n) t;
		= LoadString (n+1) size {string & [n] = toChar char} ptr t;


/*
length_resource [] = 0;
length_resource [s:l] = size s+length_resource l;

code_resource0=
   ["\000\000\000\060\000\000\000\060\000\000\000\010\000\000\000\040",
    "\000\000\077\074\000\001\251\360"];

code_resource1=
   ["\000\000\000\001\116\126\376\246\110\347\003\030\107\356\377\322",
    "\111\356\376\246\101\372\002\342\056\010\130\207\046\207\160\000",
    "\047\100\000\004\056\013\125\217\110\172\002\300\057\074\160\167",
    "\160\143\160\001\057\000\110\156\377\332\110\156\376\316\110\156",
    "\376\322\077\074\000\001\252\132\112\137\147\006\160\002\140\000",
    "\002\030\125\217\057\056\377\332\110\172\002\210\057\014\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\006\160\003\140\000\001\354\125\217",
    "\057\056\377\332\110\172\002\124\110\154\000\004\110\156\377\337",
    "\077\074\000\005\252\132\112\137\146\014\160\000\020\056\377\337",
    "\014\100\000\002\147\006\160\004\140\000\001\276\125\217\057\056",
    "\377\332\110\172\002\036\110\154\000\010\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\006\160\005\140\000\001\220\125\217\057\056\377\332",
    "\110\172\001\350\110\154\000\014\110\156\377\337\077\074\000\005",
    "\252\132\112\137\146\014\160\000\020\056\377\337\014\100\000\002",
    "\147\006\160\006\140\000\001\142\125\217\057\056\377\332\110\172",
    "\001\260\110\154\000\020\110\156\377\337\077\074\000\005\252\132",
    "\112\137\146\014\160\000\020\056\377\337\014\100\000\002\147\006",
    "\160\007\140\000\001\064\125\217\057\056\377\332\110\172\001\160",
    "\110\154\000\024\110\156\377\337\077\074\000\005\252\132\112\137",
    "\146\014\160\000\020\056\377\337\014\100\000\002\147\006\160\010",
    "\140\000\001\006\125\217\057\056\377\332\110\172\001\066\110\154",
    "\000\030\110\156\377\337\077\074\000\005\252\132\112\137\146\014",
    "\160\000\020\056\377\337\014\100\000\002\147\006\160\011\140\000",
    "\000\330\125\217\057\056\377\332\110\172\000\370\110\154\000\034",
    "\110\156\377\337\077\074\000\005\252\132\112\137\146\014\160\000",
    "\020\056\377\337\014\100\000\002\147\006\160\012\140\000\000\252",
    "\125\217\057\056\377\332\110\172\000\266\110\154\000\040\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\004\160\013\140\174\125\217\057\056",
    "\377\332\110\172\000\176\110\154\000\044\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\004\160\014\140\120\075\174\252\376\377\340\035\174",
    "\000\007\377\342\102\056\377\343\160\000\055\100\377\344\102\156",
    "\377\350\102\156\377\352\055\174\000\000\000\301\377\354\102\056",
    "\377\360\035\174\000\001\377\361\075\174\000\004\377\362\055\100",
    "\377\370\055\100\377\374\101\356\377\340\054\010\055\107\377\364",
    "\057\014\040\106\116\220\130\117\114\356\030\300\376\226\116\136",
    "\116\165\012\123\145\164\120\164\162\123\151\172\145\000\022\115",
    "\141\153\145\104\141\164\141\105\170\145\143\165\164\141\142\154",
    "\145\000\016\114\115\107\145\164\103\165\162\101\160\116\141\155",
    "\145\000\012\106\151\156\144\123\171\155\142\157\154\000\020\107",
    "\145\164\123\150\141\162\145\144\114\151\142\162\141\162\171\000",
    "\007\106\123\103\154\157\163\145\000\000\006\106\123\122\145\141",
    "\144\000\006\116\145\167\120\164\162\000\006\107\145\164\105\117",
    "\106\000\006\106\123\117\160\145\156\000\014\111\156\164\145\162",
    "\146\141\143\145\114\151\142\000\100\100\100\000\174\010\002\246",
    "\275\301\377\270\220\001\000\010\224\041\376\050\140\173\000\000",
    "\061\341\000\070\062\001\001\070\063\241\001\074\063\301\001\100",
    "\063\341\001\104\062\201\001\106\062\241\001\110\062\301\001\114",
    "\201\233\000\000\200\233\000\034\141\221\000\000\140\214\000\000",
    "\110\000\004\155\200\101\000\024\143\345\000\000\070\200\000\000",
    "\142\054\000\000\110\000\004\131\200\101\000\024\054\003\000\000",
    "\101\202\000\014\070\140\000\013\110\000\004\060\201\233\000\004",
    "\250\177\000\000\143\304\000\000\110\000\004\065\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\014\110\000\004\014",
    "\201\233\000\010\200\176\000\000\060\143\000\007\110\000\004\021",
    "\200\101\000\024\140\163\000\000\054\023\000\000\100\202\000\014",
    "\070\140\000\015\110\000\003\344\060\223\000\007\124\232\000\070",
    "\200\276\000\000\220\275\000\000\201\233\000\014\143\105\000\000",
    "\250\177\000\000\143\244\000\000\110\000\003\325\200\101\000\024",
    "\054\003\000\000\100\202\000\024\200\235\000\000\200\276\000\000",
    "\174\204\050\000\101\206\000\014\070\140\000\016\110\000\003\234",
    "\201\233\000\020\250\177\000\000\110\000\003\245\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\017\110\000\003\174",
    "\250\232\000\066\124\205\020\072\174\245\040\024\124\245\030\070",
    "\174\272\050\024\060\245\000\064\220\241\001\214\250\332\000\070",
    "\124\322\020\072\176\122\060\024\126\122\030\070\176\132\220\024",
    "\062\122\000\064\250\372\000\074\124\350\020\072\175\010\070\024",
    "\125\010\030\070\175\032\100\024\202\050\000\110\176\072\210\024",
    "\063\021\000\040\201\061\000\004\125\075\020\072\177\251\350\020",
    "\127\275\030\070\177\270\350\024\201\121\000\024\177\361\120\024",
    "\202\361\000\034\176\361\270\024\203\061\000\020\175\161\120\256",
    "\175\153\007\165\101\202\000\024\211\237\000\001\175\214\007\165",
    "\063\377\000\001\100\202\377\364\210\177\000\001\174\143\007\165",
    "\063\377\000\001\101\202\000\024\210\237\000\001\174\204\007\165",
    "\063\377\000\001\100\202\377\364\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\067\071\377\377",
    "\073\200\000\000\100\201\000\304\210\377\000\000\174\347\007\165",
    "\101\202\000\024\211\037\000\001\175\010\007\165\063\377\000\001",
    "\100\202\377\364\063\337\000\001\211\077\000\001\175\051\007\165",
    "\143\337\000\000\101\202\000\024\211\137\000\001\175\112\007\165",
    "\063\377\000\001\100\202\377\364\175\176\370\020\231\176\377\377",
    "\201\233\000\024\127\206\020\072\174\306\260\024\060\176\377\377",
    "\142\007\000\000\141\350\000\000\074\200\160\167\140\204\160\143",
    "\070\240\000\001\140\156\000\000\110\000\002\065\200\101\000\024",
    "\070\200\000\000\230\236\377\377\054\003\000\000\101\202\000\014",
    "\070\140\000\020\110\000\002\004\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\063\234\000\001",
    "\174\234\310\000\101\204\377\104\203\061\000\004\073\200\000\000",
    "\143\036\000\000\057\031\000\000\100\231\000\304\201\036\000\020",
    "\060\350\377\377\201\076\000\000\057\211\000\000\100\236\000\030",
    "\201\136\000\004\175\127\120\024\063\352\377\377\211\052\377\377",
    "\110\000\000\074\143\337\000\000\071\040\000\000\211\176\000\000",
    "\054\013\000\000\101\202\000\044\141\050\000\000\061\050\000\001",
    "\054\211\000\010\100\204\000\024\175\210\370\024\210\154\000\001",
    "\057\003\000\000\100\232\377\344\063\377\377\377\211\337\000\000",
    "\231\077\000\000\201\233\000\030\143\344\000\000\124\345\020\072",
    "\174\145\260\056\142\245\000\000\142\206\000\000\110\000\001\121",
    "\200\101\000\024\231\337\000\000\200\265\000\000\220\276\000\010",
    "\054\003\000\000\100\202\001\040\210\324\000\000\054\206\000\002",
    "\101\206\000\014\070\140\000\021\110\000\001\020\063\234\000\001",
    "\063\336\000\030\177\034\310\000\101\230\377\104\201\001\001\214",
    "\200\150\000\024\174\172\030\024\201\062\000\024\177\372\110\024",
    "\200\261\000\010\070\300\000\000\057\205\000\000\100\235\000\170",
    "\201\075\000\004\201\135\000\000\175\037\120\024\174\377\120\056",
    "\054\011\000\001\100\202\000\020\175\147\370\024\221\150\000\000",
    "\110\000\000\104\054\211\000\000\100\206\000\020\175\207\030\024",
    "\221\210\000\000\110\000\000\060\057\011\000\002\100\232\000\014",
    "\070\140\000\022\110\000\000\224\125\044\020\072\174\211\040\020",
    "\124\204\030\070\174\230\040\024\201\104\377\300\175\107\120\024",
    "\221\110\000\000\060\306\000\001\063\275\000\014\177\206\050\000",
    "\101\234\377\220\201\233\000\040\200\232\000\030\110\000\000\161",
    "\200\101\000\024\200\222\000\024\174\232\040\024\200\272\000\044",
    "\177\304\050\024\201\233\000\044\142\143\000\000\200\232\000\034",
    "\174\237\040\024\174\223\040\020\110\000\000\105\200\101\000\024",
    "\054\036\001\000\100\200\000\014\070\140\000\023\110\000\000\034",
    "\143\314\000\000\110\000\000\051\200\101\000\024\070\140\000\000",
    "\110\000\000\010\113\377\376\360\200\001\001\340\060\041\001\330",
    "\174\010\003\246\271\301\377\270\116\200\000\040\200\014\000\000",
    "\220\101\000\024\174\011\003\246\200\114\000\004\116\200\004\040"];
*/
*/

// resources; mac specific
create_application_resource :: !{#Char} !Int /*(!Int, !{#Char}) !Int !Int !Int !Int !Int !Int !Int*/ PlatformLinkOptions !*Files -> (!Bool,!PlatformLinkOptions,!*Files);
create_application_resource file_name pef_application_size platform_link_options=:{font_info,heap_size,heap_size_multiple,stack_size,flags,extra_application_memory /*application_and_extra_memory_size*/,initial_heap_size,memory_profile_minimum_heap_size} /*font_info heap_size heap_size_multiple stack_size flags application_and_extra_memory_size initial_heap_size memory_profile_minimum_heap_size*/ files
	| error_n<>0
		= (False,platform_link_options,files);
	| ref_num==(-1)
		= (False,platform_link_options,files);
	| res_error<>0 /* || not ok0 */ || not ok1 || not ok2 || not ok3 || not ok4
		= (False,platform_link_options,files);
		= (True,platform_link_options,files);
{}{
	application_and_extra_memory_size
		= pef_application_size + extra_application_memory; 
		
		
	(res_error,_)=ResError (CloseResFile ref_num t8);

	(ok5,t8)=add_font_resource font_info t7;
	(ok4,t7)=add_prfl_resource 0 t6;

//	(ok3,t6)=add_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
	(ok3,t6)=change_size_resource (heap_size+stack_size+application_and_extra_memory_size) t5;
	(ok2,t5)=add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t4;
	(ok1,t4)=add_cfrg_resource file_name t2;
/*
	(ok1,t4)=add_code1_resource t3;
	(ok0,t3)=add_code0_resource t2;
*/
	(ref_num,t2)=open_resource_file t1;

	(error_n,t1)=SetFileType "APPL" file_name NewToolbox;
	/*
	(error_n,t1)=SetFileTypeAndCreator "APPL" null_string4 file_name NewToolbox;
	null_string4=null_string2+++null_string2;
	null_string2=null_string1+++null_string1;
	null_string1=toString '\0';
	*/
	
	open_resource_file t0
		| ref_num0<>(-1)
			= (ref_num0,t2); {
				t2 = t1
						THEN remove_resource "PRFL" 128
						THEN remove_resource "Font" 128
//						THEN remove_resource "SIZE" (-1)
						THEN remove_resource "SIZE" 0
						THEN remove_resource "SIZE" 1
						THEN remove_resource "STHP" 0
						THEN remove_resource "cfrg" 0;
			}
			= HOpenResFile 0 0 file_name 3 (HCreateResFile 0 0 file_name t1);
		{}{
			(ref_num0,t1)=HOpenResFile 0 0 file_name 3 t0;
		}
}

remove_resource resource_name n t0
	| handle==0
		= t1;
		= RemoveResource handle t1;
	{}{
		(handle,t1)=Get1Resource resource_name n t0;
	}

add_cfrg_resource :: String *Int -> (!Bool,!*Int);
add_cfrg_resource file_name t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_cfrg_handle file_name handle) "cfrg" 0 "" t1);
		(handle,_,t1) = NewHandle (75+(size file_name)) t0;
	}

fill_cfrg_handle file_name handle
	= h1;
{
	(h1,_)=AppendString s20 file_name;
	s20=AppendByte s19 (file_name_length);
	s19=AppendWord s18 (file_name_length+75);
	s18=AppendLong s17 0;
	s17=AppendLong s16 0;
	s16=AppendLong s15 0;
	s15=AppendLong s14 0;
	s14=AppendLong s13 0x101;
	s13=AppendLong s12 0;
	s12=AppendLong s11 0;
	s11=AppendLong s10 0;
	s10=AppendLong s9 0;
	s9=AppendString s8 "pwpc";
	s8=AppendLong s7 1;
	s7=AppendLong s6 0;
	s6=AppendLong s5 0;
	s5=AppendLong s4 0;
	s4=AppendLong s3 0;
	s3=AppendLong s2 1;
	s2=AppendLong s1 0;
	s1=AppendLong s0 0;
	s0=HandleToStructure handle;
	
	file_name_length= size file_name;
}

/*
add_code0_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_0 handle) "CODE" 0 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_0) t0;
		code_resource_0=code_resource0;
	}

add_code1_resource t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource (fill_resource_handle code_resource_1 handle) "CODE" 1 "" t1);
		(handle,_,t1) = NewHandle (length_resource code_resource_1) t0;
		code_resource_1=code_resource1;
	}

fill_resource_handle resource handle
	=	h;
	{
		(h,_) = add_strings_to_structure resource (HandleToStructure handle);
		
		add_strings_to_structure [] structure = structure;
		add_strings_to_structure [s:l] structure = add_strings_to_structure l (AppendString structure s);
	};
*/

add_prfl_resource :: Int *Int -> (!Bool,!*Int);
add_prfl_resource heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "PRFL" 128 "" t1);
		(handle2,_)=AppendLong s0 heap_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 4 t0;
	}

add_sthp_resource :: Int Int Int Int Int *Int -> (!Bool,!*Int);
add_sthp_resource heap_size heap_size_multiple stack_size flags initial_heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "STHP" 0 "" t1);
		(handle2,_)=AppendLong s4 initial_heap_size;
		s4=AppendLong s3 flags;
		s3=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size_multiple;
		s1=AppendLong s0 stack_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 20 t0;
	}

change_size_resource :: Int *Int -> (!Bool,!*Int);
change_size_resource heap_size t
	# (flags,t)=get_size_flags_and_remove_resource t
	= add_size_resource flags heap_size t;

get_size_flags_and_remove_resource :: *Int -> (!Int, !*Int);
get_size_flags_and_remove_resource t
	# (handle,t)=Get1Resource "SIZE" (-1) t;
//	# t=test_res_error "Get1Resource" t
	| handle==0
		=(0,t);
	# (ptr,t)=DereferenceHandle handle t;
	# (flags,t)=LoadWord ptr t;
	# t=RemoveResource handle t
//	# t=test_res_error "RemoveResource" t
	= (flags,t);

test_res_error s t
	# (error_n,t)=ResError t
	| error_n<>0
		=	abort ("res error " +++ toString error_n +++ " " +++ s +++ "\n");
		=	t;

add_font_resource :: (Int, {#Char}) *Int -> (!Bool,!*Int);
add_font_resource (font_size, font_name) t0
	| font_size == 0 || font_name == ""
		= (True, t0)
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "Font" 128 "" t1);
		(handle2,_)=AppendString s2 font_name;
		s2=AppendByte s1 font_name_size;
		s1=AppendWord s0 font_size;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle (3 + font_name_size) t0;
		font_name_size = size font_name;
	}

add_size_resource :: Int Int *Int -> (!Bool,!*Int);
add_size_resource flags heap_size t0
	| handle==0
		= (False,t1);
		= (error_n==0,t2);
	{}{
		(error_n,t2)=ResError (AddResource handle2 "SIZE" (-1) "" t1);
		(handle2,_)=AppendLong s2 heap_size;
		s2=AppendLong s1 heap_size;
		s1=AppendWord s0 flags;
		s0=HandleToStructure handle;
		(handle,_,t1) = NewHandle 10 t0;
	}

read_application_options :: !{#Char} !*Files -> (!Bool,(!Int,!{#Char}),!Int,!Int,!Int,!Int,!Int,!Int,!Int,!Int,!*Files);
read_application_options file_name files
	# (pef_read, pef_size, files)
		=	read_pef_size_from_data_fork file_name files
	| not pef_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (ref_num, t)
		=	HOpenResFile 0 0 file_name 1 NewToolbox
	| ref_num == (-1)
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files)
	# (size_read, _, minimum_size, t)
		=	read_size_resource t
	| not size_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (sthp_read, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t)
		=	read_sthp_resource t
	| not sthp_read
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
	# (_, font_size, font_name, t)
		=	read_font_resource t
	# (_, profile_heap_size, t)
		=	read_prfl_resource t
	# (res_error, _)
		=	ResError (CloseResFile ref_num t);
	| res_error <> 0
		=	(False, (0, ""), 0, 0, 0, 0, 0, 0, 0, 0, files);
		=	(True, (font_size, font_name), heap_size, heap_size_multiple, stack_size,
				flags, initial_heap_size, profile_heap_size, pef_size,
					minimum_size-heap_size-stack_size, files);

read_font_resource :: !*Toolbox -> (!Bool,!Int,!{#Char},!*Toolbox);
read_font_resource t
	# (handle,t)
		=	Get1Resource "Font" 128 t
	| handle==0
		=	(False, 0,"",t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (font_size, t) =	LoadWord ptr t;
	  ptr 	=	ptr+2;
	# (font_name_size, t) = LoadByte ptr t;
	  ptr	  	=	ptr+1;
	# (font_name, _, t)
		=	LoadString 0 font_name_size (createArray font_name_size ' ') ptr t;
	= (False, font_size, font_name, t);

read_size_resource :: *Int -> (!Bool,!Int,!Int,!*Int);
read_size_resource t
	# (handle,t)
		=	Get1Resource "SIZE" (-1) t
	| handle==0
		=	(False, 0, 0, t);
	# (ptr, t)
		=	DereferenceHandle handle t;
	# (flags, t)=	LoadWord ptr t;
	  ptr	  	=	ptr+6; /* skip (long) size */
	# (minimum_size, t)
		=	LoadLong ptr t;
		=	(True, flags, minimum_size, t);

read_sthp_resource :: *Toolbox -> (!Bool,!Int,!Int,!Int,!Int,!Int,!*Toolbox);
read_sthp_resource t
	# (handle,t)
		=	Get1Resource "STHP" 0 t
	| handle==0
		=	(False, 0, 0, 0, 0, 0, t);
	# (ptr, t)		=	DereferenceHandle handle t;
	# (stack_size, t)	=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (heap_size_multiple, t) =	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (heap_size, t)	=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (flags, t)		=	LoadLong ptr t;
	  ptr	  	=	ptr+4;
	# (initial_heap_size, t) =	LoadLong ptr t;
	=	(True, stack_size, heap_size_multiple, heap_size, flags, initial_heap_size, t);

read_prfl_resource :: *Toolbox -> (!Bool,!Int,!*Toolbox);
read_prfl_resource t
	# (handle,t)		=	Get1Resource "PRFL" 128 t
	| handle==0
		=	(False, 0, t);
		# (ptr, t)		=	DereferenceHandle handle t;
		# (profile_heap_size, t)		=	LoadLong ptr t;
		= (True, profile_heap_size, t);

read_pef_size_from_data_fork :: {#Char} *Files -> (!Bool,!Int,!*Files);
read_pef_size_from_data_fork name files
	# (open,file,files) = fopen name FReadData files;
	| not open
		=	(False, 0, files);
	# (magic, file)		=	freads file 12;
	| magic <> "Joy!peffpwpc"
		=	(False, 0, snd (fclose file files));
	# (sought, file)		=	fseek file 0x30 FSeekSet;
	| not sought
		=	(False, 0, snd (fclose file files));
	# (read, pef_size, file)		=	freadi file;
	| not read
		=	(False, 0, snd (fclose file files));
	# (closed, files)		=	fclose file files;
	| not closed
		=	(False, 0, files);
		=	(True, pef_size, files);

LoadString :: Int Int *{#Char} Ptr *Toolbox -> (!*{#Char},Ptr,!*Toolbox);
LoadString n size string ptr t
	| n == size
		= (string, ptr, t);
		# (char, t) = LoadByte (ptr+n) t;
		= LoadString (n+1) size {string & [n] = toChar char} ptr t;


/*
length_resource [] = 0;
length_resource [s:l] = size s+length_resource l;

code_resource0=
   ["\000\000\000\060\000\000\000\060\000\000\000\010\000\000\000\040",
    "\000\000\077\074\000\001\251\360"];

code_resource1=
   ["\000\000\000\001\116\126\376\246\110\347\003\030\107\356\377\322",
    "\111\356\376\246\101\372\002\342\056\010\130\207\046\207\160\000",
    "\047\100\000\004\056\013\125\217\110\172\002\300\057\074\160\167",
    "\160\143\160\001\057\000\110\156\377\332\110\156\376\316\110\156",
    "\376\322\077\074\000\001\252\132\112\137\147\006\160\002\140\000",
    "\002\030\125\217\057\056\377\332\110\172\002\210\057\014\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\006\160\003\140\000\001\354\125\217",
    "\057\056\377\332\110\172\002\124\110\154\000\004\110\156\377\337",
    "\077\074\000\005\252\132\112\137\146\014\160\000\020\056\377\337",
    "\014\100\000\002\147\006\160\004\140\000\001\276\125\217\057\056",
    "\377\332\110\172\002\036\110\154\000\010\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\006\160\005\140\000\001\220\125\217\057\056\377\332",
    "\110\172\001\350\110\154\000\014\110\156\377\337\077\074\000\005",
    "\252\132\112\137\146\014\160\000\020\056\377\337\014\100\000\002",
    "\147\006\160\006\140\000\001\142\125\217\057\056\377\332\110\172",
    "\001\260\110\154\000\020\110\156\377\337\077\074\000\005\252\132",
    "\112\137\146\014\160\000\020\056\377\337\014\100\000\002\147\006",
    "\160\007\140\000\001\064\125\217\057\056\377\332\110\172\001\160",
    "\110\154\000\024\110\156\377\337\077\074\000\005\252\132\112\137",
    "\146\014\160\000\020\056\377\337\014\100\000\002\147\006\160\010",
    "\140\000\001\006\125\217\057\056\377\332\110\172\001\066\110\154",
    "\000\030\110\156\377\337\077\074\000\005\252\132\112\137\146\014",
    "\160\000\020\056\377\337\014\100\000\002\147\006\160\011\140\000",
    "\000\330\125\217\057\056\377\332\110\172\000\370\110\154\000\034",
    "\110\156\377\337\077\074\000\005\252\132\112\137\146\014\160\000",
    "\020\056\377\337\014\100\000\002\147\006\160\012\140\000\000\252",
    "\125\217\057\056\377\332\110\172\000\266\110\154\000\040\110\156",
    "\377\337\077\074\000\005\252\132\112\137\146\014\160\000\020\056",
    "\377\337\014\100\000\002\147\004\160\013\140\174\125\217\057\056",
    "\377\332\110\172\000\176\110\154\000\044\110\156\377\337\077\074",
    "\000\005\252\132\112\137\146\014\160\000\020\056\377\337\014\100",
    "\000\002\147\004\160\014\140\120\075\174\252\376\377\340\035\174",
    "\000\007\377\342\102\056\377\343\160\000\055\100\377\344\102\156",
    "\377\350\102\156\377\352\055\174\000\000\000\301\377\354\102\056",
    "\377\360\035\174\000\001\377\361\075\174\000\004\377\362\055\100",
    "\377\370\055\100\377\374\101\356\377\340\054\010\055\107\377\364",
    "\057\014\040\106\116\220\130\117\114\356\030\300\376\226\116\136",
    "\116\165\012\123\145\164\120\164\162\123\151\172\145\000\022\115",
    "\141\153\145\104\141\164\141\105\170\145\143\165\164\141\142\154",
    "\145\000\016\114\115\107\145\164\103\165\162\101\160\116\141\155",
    "\145\000\012\106\151\156\144\123\171\155\142\157\154\000\020\107",
    "\145\164\123\150\141\162\145\144\114\151\142\162\141\162\171\000",
    "\007\106\123\103\154\157\163\145\000\000\006\106\123\122\145\141",
    "\144\000\006\116\145\167\120\164\162\000\006\107\145\164\105\117",
    "\106\000\006\106\123\117\160\145\156\000\014\111\156\164\145\162",
    "\146\141\143\145\114\151\142\000\100\100\100\000\174\010\002\246",
    "\275\301\377\270\220\001\000\010\224\041\376\050\140\173\000\000",
    "\061\341\000\070\062\001\001\070\063\241\001\074\063\301\001\100",
    "\063\341\001\104\062\201\001\106\062\241\001\110\062\301\001\114",
    "\201\233\000\000\200\233\000\034\141\221\000\000\140\214\000\000",
    "\110\000\004\155\200\101\000\024\143\345\000\000\070\200\000\000",
    "\142\054\000\000\110\000\004\131\200\101\000\024\054\003\000\000",
    "\101\202\000\014\070\140\000\013\110\000\004\060\201\233\000\004",
    "\250\177\000\000\143\304\000\000\110\000\004\065\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\014\110\000\004\014",
    "\201\233\000\010\200\176\000\000\060\143\000\007\110\000\004\021",
    "\200\101\000\024\140\163\000\000\054\023\000\000\100\202\000\014",
    "\070\140\000\015\110\000\003\344\060\223\000\007\124\232\000\070",
    "\200\276\000\000\220\275\000\000\201\233\000\014\143\105\000\000",
    "\250\177\000\000\143\244\000\000\110\000\003\325\200\101\000\024",
    "\054\003\000\000\100\202\000\024\200\235\000\000\200\276\000\000",
    "\174\204\050\000\101\206\000\014\070\140\000\016\110\000\003\234",
    "\201\233\000\020\250\177\000\000\110\000\003\245\200\101\000\024",
    "\054\003\000\000\101\202\000\014\070\140\000\017\110\000\003\174",
    "\250\232\000\066\124\205\020\072\174\245\040\024\124\245\030\070",
    "\174\272\050\024\060\245\000\064\220\241\001\214\250\332\000\070",
    "\124\322\020\072\176\122\060\024\126\122\030\070\176\132\220\024",
    "\062\122\000\064\250\372\000\074\124\350\020\072\175\010\070\024",
    "\125\010\030\070\175\032\100\024\202\050\000\110\176\072\210\024",
    "\063\021\000\040\201\061\000\004\125\075\020\072\177\251\350\020",
    "\127\275\030\070\177\270\350\024\201\121\000\024\177\361\120\024",
    "\202\361\000\034\176\361\270\024\203\061\000\020\175\161\120\256",
    "\175\153\007\165\101\202\000\024\211\237\000\001\175\214\007\165",
    "\063\377\000\001\100\202\377\364\210\177\000\001\174\143\007\165",
    "\063\377\000\001\101\202\000\024\210\237\000\001\174\204\007\165",
    "\063\377\000\001\100\202\377\364\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\067\071\377\377",
    "\073\200\000\000\100\201\000\304\210\377\000\000\174\347\007\165",
    "\101\202\000\024\211\037\000\001\175\010\007\165\063\377\000\001",
    "\100\202\377\364\063\337\000\001\211\077\000\001\175\051\007\165",
    "\143\337\000\000\101\202\000\024\211\137\000\001\175\112\007\165",
    "\063\377\000\001\100\202\377\364\175\176\370\020\231\176\377\377",
    "\201\233\000\024\127\206\020\072\174\306\260\024\060\176\377\377",
    "\142\007\000\000\141\350\000\000\074\200\160\167\140\204\160\143",
    "\070\240\000\001\140\156\000\000\110\000\002\065\200\101\000\024",
    "\070\200\000\000\230\236\377\377\054\003\000\000\101\202\000\014",
    "\070\140\000\020\110\000\002\004\210\277\000\001\174\245\007\165",
    "\063\377\000\001\101\202\000\024\210\337\000\001\174\306\007\165",
    "\063\377\000\001\100\202\377\364\063\377\000\001\063\234\000\001",
    "\174\234\310\000\101\204\377\104\203\061\000\004\073\200\000\000",
    "\143\036\000\000\057\031\000\000\100\231\000\304\201\036\000\020",
    "\060\350\377\377\201\076\000\000\057\211\000\000\100\236\000\030",
    "\201\136\000\004\175\127\120\024\063\352\377\377\211\052\377\377",
    "\110\000\000\074\143\337\000\000\071\040\000\000\211\176\000\000",
    "\054\013\000\000\101\202\000\044\141\050\000\000\061\050\000\001",
    "\054\211\000\010\100\204\000\024\175\210\370\024\210\154\000\001",
    "\057\003\000\000\100\232\377\344\063\377\377\377\211\337\000\000",
    "\231\077\000\000\201\233\000\030\143\344\000\000\124\345\020\072",
    "\174\145\260\056\142\245\000\000\142\206\000\000\110\000\001\121",
    "\200\101\000\024\231\337\000\000\200\265\000\000\220\276\000\010",
    "\054\003\000\000\100\202\001\040\210\324\000\000\054\206\000\002",
    "\101\206\000\014\070\140\000\021\110\000\001\020\063\234\000\001",
    "\063\336\000\030\177\034\310\000\101\230\377\104\201\001\001\214",
    "\200\150\000\024\174\172\030\024\201\062\000\024\177\372\110\024",
    "\200\261\000\010\070\300\000\000\057\205\000\000\100\235\000\170",
    "\201\075\000\004\201\135\000\000\175\037\120\024\174\377\120\056",
    "\054\011\000\001\100\202\000\020\175\147\370\024\221\150\000\000",
    "\110\000\000\104\054\211\000\000\100\206\000\020\175\207\030\024",
    "\221\210\000\000\110\000\000\060\057\011\000\002\100\232\000\014",
    "\070\140\000\022\110\000\000\224\125\044\020\072\174\211\040\020",
    "\124\204\030\070\174\230\040\024\201\104\377\300\175\107\120\024",
    "\221\110\000\000\060\306\000\001\063\275\000\014\177\206\050\000",
    "\101\234\377\220\201\233\000\040\200\232\000\030\110\000\000\161",
    "\200\101\000\024\200\222\000\024\174\232\040\024\200\272\000\044",
    "\177\304\050\024\201\233\000\044\142\143\000\000\200\232\000\034",
    "\174\237\040\024\174\223\040\020\110\000\000\105\200\101\000\024",
    "\054\036\001\000\100\200\000\014\070\140\000\023\110\000\000\034",
    "\143\314\000\000\110\000\000\051\200\101\000\024\070\140\000\000",
    "\110\000\000\010\113\377\376\360\200\001\001\340\060\041\001\330",
    "\174\010\003\246\271\301\377\270\116\200\000\040\200\014\000\000",
    "\220\101\000\024\174\011\003\246\200\114\000\004\116\200\004\040"];
*/
