implementation module IdataSection;

import StdEnv;
import ExtFile,pdSymbolTable,link32or64bits;

write_imported_library_functions_code_32 :: !LibraryList !Int !*File -> *File;
write_imported_library_functions_code_32 EmptyLibraryList thunk_data_offset pe_file
	= pe_file;
write_imported_library_functions_code_32 (Library _ _ imported_symbols _ library_list) thunk_data_offset pe_file
	# (thunk_data_offset,pe_file) = write_library_functions_code imported_symbols thunk_data_offset pe_file;
	= write_imported_library_functions_code_32 library_list thunk_data_offset pe_file;
	{
		write_library_functions_code :: !LibrarySymbolsList !Int !*File -> (!Int,!*File);
		write_library_functions_code EmptyLibrarySymbolsList thunk_data_offset pe_file
			= (thunk_data_offset+4,pe_file);
		write_library_functions_code (LibrarySymbol symbol_name symbol_list) thunk_data_offset pe_file
			# pe_file = pe_file FWC '\377' FWC '\045'
								FWI thunk_data_offset;
			= write_library_functions_code symbol_list (thunk_data_offset+4) pe_file;
	}

write_imported_library_functions_code_64 :: !LibraryList !Int !Int !*File -> *File;
write_imported_library_functions_code_64 EmptyLibraryList thunk_data_offset jump_offset pe_file
	= pe_file;
write_imported_library_functions_code_64 (Library _ _ imported_symbols _ library_list) thunk_data_offset jump_offset pe_file
	# (thunk_data_offset,jump_offset,pe_file) = write_library_functions_code imported_symbols thunk_data_offset jump_offset pe_file;
	= write_imported_library_functions_code_64 library_list thunk_data_offset jump_offset pe_file;
	{
		write_library_functions_code :: !LibrarySymbolsList !Int !Int !*File -> (!Int,!Int,!*File);
		write_library_functions_code EmptyLibrarySymbolsList thunk_data_offset jump_offset pe_file
			= (thunk_data_offset+8,jump_offset,pe_file);
		write_library_functions_code (LibrarySymbol symbol_name symbol_list) thunk_data_offset jump_offset pe_file
			# pe_file = pe_file FWC '\377' FWC '\045'
								FWI (thunk_data_offset-(jump_offset+6));
			= write_library_functions_code symbol_list (thunk_data_offset+8) (jump_offset+6) pe_file;
	}

write_idata :: !.LibraryList !.Int !.Int !.Int !*File -> .File;
write_idata library_list n_libraries n_imported_symbols idata_vaddr xcoff_file0
	=	xcoff_file0
			THEN write_import_descriptors library_list (idata_vaddr+descriptor_block_size+thunk_data_size) (idata_vaddr+descriptor_block_size)
			THEN write_thunk_data library_list (idata_vaddr+descriptor_block_size+thunk_data_size+file_name_block_size)
			THEN write_library_file_names library_list
			THEN write_imported_symbols library_list;
	{
		descriptor_block_size = 20*(n_libraries+1);
		thunk_data_size = (n_imported_symbols+n_libraries)<<(Link32or64bits 2 3);
		file_name_block_size = compute_file_names_size library_list 0;
		
			compute_file_names_size EmptyLibraryList s = s;
			compute_file_names_size (Library file_name _ _ _ libraries) s
				= compute_file_names_size libraries ((s+size file_name+2) bitand (-2));

		write_import_descriptors EmptyLibraryList library_name_offset thunk_data_offset pe_file0
			= pe_file0 FWI 0 FWI 0 FWI 0 FWI 0 FWI 0;
		write_import_descriptors (Library file_name _ _ n_symbols libraries) library_name_offset thunk_data_offset pe_file0
			# pe_file0 = pe_file0 FWI 0 FWI 0 FWI 0 FWI library_name_offset FWI thunk_data_offset;
			= write_import_descriptors libraries (library_name_offset+((2+size file_name) bitand (-2)))
				(thunk_data_offset+(n_symbols+1)<<(Link32or64bits 2 3)) pe_file0;
	
		write_library_file_names EmptyLibraryList pe_file0
			= pe_file0;
		write_library_file_names (Library file_name _ _ _ libraries) pe_file0
			= write_library_file_names libraries pe_file2;
			{
				pe_file2
					| size file_name bitand 1==0
						= pe_file1 FWC '\0';
						= pe_file1;
				pe_file1 = pe_file0 FWS file_name FWC '\0';
			}

		write_thunk_data EmptyLibraryList symbols_offset0 coff_file0
			= coff_file0;
		write_thunk_data (Library _ _ imported_symbols _ libraries) symbols_offset0 coff_file0
			# (symbols_offset1,coff_file1)=write_library_thunk_data imported_symbols symbols_offset0 coff_file0;
			# coff_file1 = coff_file1 FWL 0;
			= write_thunk_data libraries symbols_offset1 coff_file1;
			{
				write_library_thunk_data EmptyLibrarySymbolsList symbols_offset0 coff_file0
				 	= (symbols_offset0,coff_file0);
 				write_library_thunk_data (LibrarySymbol symbol_name symbols) symbols_offset0 coff_file0
 					# symbols_offset1 = (symbols_offset0+size symbol_name+4) bitand (-2)
 					# coff_file0 = coff_file0 FWL symbols_offset0;
 					= write_library_thunk_data symbols symbols_offset1 coff_file0;
			}

		write_imported_symbols EmptyLibraryList coff_file0
			= coff_file0;
		write_imported_symbols (Library _ _ imported_symbols _ libraries) coff_file0
			= write_imported_symbols libraries (write_library_symbols imported_symbols coff_file0);
			{
				write_library_symbols EmptyLibrarySymbolsList coff_file0
					= coff_file0;
				write_library_symbols (LibrarySymbol symbol_name symbols) coff_file0
					= write_library_symbols symbols coff_file2;
					{
						coff_file2
							| size symbol_name bitand 1==0
								= coff_file1 FWC '\0';
								= coff_file1;
						coff_file1 = coff_file0
							FWC '\0' FWC '\0' FWS (remove_at_size symbol_name) FWC '\0';
					}
			}

		remove_at_size s = remove_at_size_i (size s-1);
		{
			remove_at_size_i -1
				= s;
			remove_at_size_i i
				| s.[i]<>'@'
					= remove_at_size_i (i-1);
					= s % (0,i-1) +++t;
					{
						t :: {#Char};
						t = createArray (size s-i) '\0';
					}
		}
	}

compute_idata_strings_size :: !LibraryList !Int !Int !Int !*{#Bool} -> (!*{#Bool},!Int,!Int);
compute_idata_strings_size EmptyLibraryList idata_string_size0 n_imported_symbols0 symbol_n marked_bool_a
	= (marked_bool_a,idata_string_size0,n_imported_symbols0);
compute_idata_strings_size (Library file_name _ imported_symbols _ libraries) idata_string_size0 n_imported_symbols0 symbol_n0 marked_bool_a
	#! idata_string_size1 = (idata_string_size0+size file_name+2) bitand (-2);	  
	   (marked_bool_a,idata_string_size2,n_imported_symbols1,symbol_n1)
		= idata_strings_size_of_symbol_names imported_symbols idata_string_size1 n_imported_symbols0 symbol_n0 marked_bool_a;
	=  compute_idata_strings_size libraries idata_string_size2 n_imported_symbols1 symbol_n1 marked_bool_a;
	{
		idata_strings_size_of_symbol_names :: !LibrarySymbolsList !Int !Int !Int !*{#Bool} -> (!*{#Bool},!Int,!Int,!Int);
		idata_strings_size_of_symbol_names EmptyLibrarySymbolsList idata_string_size0 n_imported_symbols0 symbol_n marked_bool_a
			= (marked_bool_a,idata_string_size0,n_imported_symbols0,symbol_n);
		idata_strings_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) idata_string_size0 n_imported_symbols0 symbol_n marked_bool_a
			| not marked_bool_a.[symbol_n]
				= idata_strings_size_of_symbol_names imported_symbols idata_string_size0 n_imported_symbols0 (symbol_n+2) marked_bool_a;
				= (idata_strings_size_of_symbol_names imported_symbols ((idata_string_size0+size symbol_name+4) bitand (-2)) (inc n_imported_symbols0) (symbol_n+2) marked_bool_a);
	}
