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