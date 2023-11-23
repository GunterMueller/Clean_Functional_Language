implementation module piObjectToDisk;

// platform independent Object to Disk

import StdEnv;

import PlatformLinkOptions, LinkerMessages;
import ExtInt, ExtFile;
import State;
import write_symbol_table;

Analyse :: !*(!Int,!Int,!*State,!*PlatformLinkOptions,!*Files) !Int  -> *(!Int,!Int,!*State,!*PlatformLinkOptions,!*Files);
Analyse (fp,start_rva,state=:{n_library_symbols,n_xcoff_symbols,n_libraries,library_list},platform_link_options,files) i		
	#! (is_virtual_section,i_section_header,s_virtual_data,alignment,s_raw_data,state,platform_link_options,files)
		= apply_compute_section i start_rva fp platform_link_options state files;

	#! (ok,state) = IsErrorOccured state;
	| not ok
		= (fp,start_rva,state,platform_link_options,files);
		
	#! start_rva
		= start_rva + (if (s_raw_data == 0) (roundup_to_multiple s_virtual_data 4096) (roundup_to_multiple s_raw_data 4096));
	#! (fp,platform_link_options)
		= case is_virtual_section of {
			True
				-> (fp,platform_link_options);				
			False
				// alignment
				#! s_raw_data_512
					= case s_raw_data of {
						0
							-> roundup_to_multiple s_virtual_data alignment;
						_
							// section containing raw data, but no virtual size e.g. resource section
							-> roundup_to_multiple s_raw_data alignment;
					};
				#! platform_link_options = plo_set_s_raw_data s_raw_data_512 i_section_header platform_link_options;
				#! platform_link_options = plo_set_fp_section fp i_section_header platform_link_options;
				-> (fp + s_raw_data_512,platform_link_options);
		}	
	= (fp,start_rva,state,platform_link_options,files);

Generate (pe_file,state,files,platform_link_options) i
	# (is_virtual_section,s_virtual_data,s_raw_text_section,pe_file,platform_link_options,state,files)
		= apply_generate_section i pe_file platform_link_options state files;

	#! (ok,state) = IsErrorOccured state;
	| not ok
		= abort "Generate: errors set"; //(pe_file,state,files,platform_link_options);

	# pe_file
		= case (is_virtual_section || s_virtual_data == 0) of {
			True
				-> pe_file;
			False
				-> write_zero_bytes_to_file (s_raw_text_section - s_virtual_data) pe_file;
		}
		
	= (pe_file,state,files,platform_link_options);

write_object_to_disk :: !PlatformLinkOptions !*State !*Files -> (!*State,!PlatformLinkOptions,!*Files);
write_object_to_disk platform_link_options state=:{application_name = application_file_name} files 
	// determine what sections are put into an executable					
	#! (s_section_header_a,state,platform_link_options)
		= create_section_header_kinds state platform_link_options;

	#! (ok,state) = IsErrorOccured state;
	| not ok
		= (state,platform_link_options,files);
		
	# section_header_index_list
		= [0..dec s_section_header_a];

	// get start filepointer (fp) and relative virtual start address		
	# (start_fp,platform_link_options) = plo_get_start_fp platform_link_options;
	# (start_rva,platform_link_options) = plo_get_start_rva platform_link_options;
		
	// Analyze
	#! (fp,end_rva,state,platform_link_options,files)
		= foldl Analyse (start_fp,start_rva,state,platform_link_options,files) section_header_index_list;

	#! (ok,state) = IsErrorOccured state;
	| not ok
		= (state,platform_link_options,files);

	# platform_link_options = plo_set_end_rva end_rva platform_link_options;

	# (generate_symbol_table,platform_link_options) = plo_get_generate_symbol_table platform_link_options;
	# (n_symbols,string_table_size,state)
		= if generate_symbol_table
			(compute_n_symbols_and_string_table_size state)
			(0,0,state);
	# platform_link_options
		= plo_set_image_symbol_table_info n_symbols string_table_size (if generate_symbol_table fp 0) platform_link_options;

	# fp = fp + n_symbols * 18 + string_table_size;
	# platform_link_options = plo_set_end_fp fp platform_link_options;

	#! (open_ok,pe_file,files)
		= fopen application_file_name FWriteData files;
	| not open_ok
		# open_error = LinkerError ("could not create '" +++ application_file_name +++ "'");
		# state = AddMessage open_error state;
		= (state,platform_link_options,files);
		
	#! (pe_file,state,files,platform_link_options)
		= case open_ok of {
			True
				#! (pe_file,state,files,platform_link_options)
					= foldl Generate (pe_file,state,files,platform_link_options) section_header_index_list;

				#! (ok,state) = IsErrorOccured state;
				| not ok
					-> (pe_file,state,files,platform_link_options);		
				-> (pe_file,state,files,platform_link_options);
			False
				-> (pe_file,state,files,platform_link_options);
		};

	# (text_va,data_va,bss_va,platform_link_options) = plo_get_text_data_bss_va platform_link_options;

	# (state,pe_file)
		= if generate_symbol_table
			(write_symbol_table text_va data_va bss_va n_symbols string_table_size state pe_file)
			(state,pe_file);

	#! (close_ok,files)
		= fclose pe_file files;
	| not close_ok
		# state = AddMessage (LinkerError ("error writing '" +++ application_file_name +++ "'")) state;
		= (state,platform_link_options,files);

	= (state,platform_link_options,files);
