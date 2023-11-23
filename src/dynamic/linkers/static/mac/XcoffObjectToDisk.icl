implementation module XcoffObjectToDisk;

import StdInt, StdString, StdFile, StdArray, StdClass; 
import ExtFile/*,linker2*/ , SymbolTable, xcoff, LinkerOffsets, ExtString, CommonObjectToDisk;

// utilities		
(THEN) infixl;
(THEN) a f :== f a;
(!=) a b :== a<>b;

create_xcoff_file :: !String !Int !Int !Int !Int !Int !*Files -> *(*File,*Files);
create_xcoff_file xcoff_file_name text_section_size data_section_size bss_section_size loader_section_size main_offset files
	# (ok,file,files) 
		= fopen xcoff_file_name FWriteData files;
	| ok
		# file = file
			FWI 0x01df0004 FWI 0 FWI 0 FWI 0 FWI 0x00481003
			FWI 0x010b0001 FWI text_section_size FWI data_section_size FWI bss_section_size FWI main_offset FWI 0 FWI 0 FWI 0
			FWI 0x00020001 FWI 0x00020002 FWI 0x00040003 FWI 0x00020002 FWI (((toInt '1'<<8)bitor (toInt 'L'))<<16)
			FWI 0 FWI 0 FWI 0 FWI 0 FWI 0;
		# file = file
			FWS ".text\000\000\000" FWI 0 FWI 0 FWI text_section_size FWI 252 FWI 0 FWI 0 FWI 0 FWI 0x20;
		# file = file
			FWS ".data\000\000\000" FWI 0 FWI 0 FWI data_section_size FWI (252+text_section_size) FWI 0 FWI 0 FWI 0 FWI 0x40;
		# file = file
			FWS ".bss\000\000\000\000" FWI data_section_size FWI data_section_size FWI bss_section_size FWI 0 FWI 0 FWI 0 FWI 0 FWI 0x80;
		# file = file
			FWS ".loader\000" FWI 0 FWI 0 FWI loader_section_size FWI (252+text_section_size+data_section_size) FWI 0 FWI 0 FWI 0 FWI 0x1000;
		= (file,files);
		

write_xcoff_loader library_list n_libraries n_imported_symbols string_table_file_names_size string_table_size main_offset
				n_loader_relocations loader_relocations xcoff_file0
	=	xcoff_file1
			THEN write_symbol_table library_list 0 1
			THEN write_loader_relocations_for_imported_symbols 0 n_imported_symbols
			THEN write_xcoff_loader_relocations loader_relocations
			FWC '\0' FWC '\0' FWC '\0'
			THEN write_library_file_names library_list
			THEN write_symbol_string_table library_list
			THEN write_zero_bytes_to_file (aligned_string_table_size-string_table_size)
			FWI 0;
	{

		xcoff_file1 = xcoff_file0
			FWI 1 FWI n_imported_symbols FWI (n_loader_relocations+n_imported_symbols) FWI import_file_list_length FWI (1+n_libraries) 
			FWI loader_import_offset FWI string_table_size FWI (loader_import_offset+import_file_list_length);

		aligned_string_table_size=(string_table_size+3) bitand (-4);

		loader_import_offset=32+24*n_imported_symbols+12*(n_loader_relocations+n_imported_symbols);
		import_file_list_length=3+string_table_file_names_size;
		
		write_loader_relocations_for_imported_symbols symbol_n n_symbols xcoff_file
			| n_symbols==0
				= xcoff_file;
				= write_loader_relocations_for_imported_symbols (inc symbol_n) (dec n_symbols)
					(xcoff_file FWI (symbol_n<<2) FWI (3+symbol_n) FWI 0x1F000002);
	
		write_library_file_names EmptyLibraryList pef_file0
			= pef_file0;
		write_library_file_names (Library file_name _ _ libraries) pef_file0
			= write_library_file_names libraries (pef_file0 FWC '\0' FWS file_name FWC '\0' FWC '\0');
			
		write_symbol_table EmptyLibraryList string_table_offset0 file_number xcoff_file0
			= xcoff_file0;
		write_symbol_table (Library _ imported_symbols _ libraries) string_table_offset0 file_number xcoff_file0
			= write_symbol_table libraries string_table_offset1 (inc file_number) xcoff_file1;
			{
				(string_table_offset1,xcoff_file1) = write_symbol_table_entries imported_symbols string_table_offset0 xcoff_file0;

				write_symbol_table_entries :: LibrarySymbolsList Int *File -> (!Int,!*File);
				write_symbol_table_entries EmptyLibrarySymbolsList string_table_offset0 xcoff_file0
					= (string_table_offset0,xcoff_file0);
				write_symbol_table_entries (LibrarySymbol symbol_name symbols) string_table_offset0 xcoff_file0
					| size symbol_name<=8
						= write_symbol_table_entries symbols string_table_offset0
							(xcoff_file0 FWS symbol_name FWZ (8 - size symbol_name) FWI 0 FWI 0x00004000 FWI file_number FWI 0);
						= write_symbol_table_entries symbols (3 + size symbol_name + string_table_offset0)
							(xcoff_file0 FWI 0 FWI (string_table_offset0+2) FWI 0 FWI 0x00004000 FWI file_number FWI 0);
			}
			
		
		write_symbol_string_table EmptyLibraryList pef_file0
			= pef_file0;
		write_symbol_string_table (Library _ imported_symbols _ libraries) pef_file0
			= write_symbol_string_table libraries (write_symbol_strings imported_symbols pef_file0);
		
			write_symbol_strings EmptyLibrarySymbolsList pef_file0
				= pef_file0;
			write_symbol_strings (LibrarySymbol symbol_name symbols) pef_file0
				| size symbol_name<=8
					= write_symbol_strings symbols pef_file0;
					= write_symbol_strings symbols (pef_file0 FWC (toChar (inc_symbol_name_length>>8)) FWC (toChar inc_symbol_name_length) FWS symbol_name FWC '\0');
					{
						inc_symbol_name_length=inc (size symbol_name);
					}
	}

compute_xcoff_string_table_size :: LibraryList Int Int Int Int !{#Bool} -> (!Int,!Int,!Int);
compute_xcoff_string_table_size EmptyLibraryList string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n marked_bool_a
	=	(string_table_file_names_size,string_table_symbol_names_size0,n_imported_symbols0);
compute_xcoff_string_table_size (Library file_name imported_symbols _ libraries) string_table_file_names_size string_table_symbol_names_size0 n_imported_symbols0 symbol_n0 marked_bool_a
	=	compute_xcoff_string_table_size libraries (3 + size file_name + string_table_file_names_size) string_table_symbol_names_size1 n_imported_symbols1 symbol_n1 marked_bool_a;
	{
		(string_table_symbol_names_size1,n_imported_symbols1,symbol_n1)
			= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 symbol_n0;
		
		string_table_size_of_symbol_names :: LibrarySymbolsList Int Int Int -> (!Int,!Int,!Int);
		string_table_size_of_symbol_names EmptyLibrarySymbolsList string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			= (string_table_symbol_names_size0,n_imported_symbols0,symbol_n);
		string_table_size_of_symbol_names (LibrarySymbol symbol_name imported_symbols) string_table_symbol_names_size0 n_imported_symbols0 symbol_n
			| not marked_bool_a.[symbol_n]
				= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 n_imported_symbols0 (symbol_n+2);
			| size symbol_name<=8
				= string_table_size_of_symbol_names imported_symbols string_table_symbol_names_size0 (inc n_imported_symbols0) (symbol_n+2);
				= string_table_size_of_symbol_names imported_symbols (3 + size symbol_name + string_table_symbol_names_size0) (inc n_imported_symbols0) (symbol_n+2);
	}

/*
write_output_file a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 a14 :== write_output_file_ a2 a3 a4 a5 a6 a7 a8 a9 a10 a11 a12 a13 a14;

write_output_file_ :: !Bool .{#Char} .Int !.Int !.Int !.LibraryList SymbolAndFileN .Bool !*Sections !.Int {#.Bool} {#.Int} !*{#*Xcoff} *Files -> (!Bool,Int,*Files);
write_output_file_ generate_xcoff application_file_name n_xcoff_files n_libraries n_library_symbols library_list0
		{symbol_n=main_symbol_n,file_n=main_file_n} one_pass_link sections n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2
	| not generate_xcoff
		= write_pef_file   application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 
							main_symbol_n main_file_n one_pass_link sections 
							n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2;
/*		= write_xcoff_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0
							main_symbol_n main_file_n one_pass_link sections
							n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files2;
*/
*/

write_xcoff_file :: .{#Char} .Int !.Int !.Int !.LibraryList .Int .Int .Bool !*Sections !.Int {#.Bool} {#.Int} !*{#*Xcoff} *Files -> *(!Bool,Int,*Files);
write_xcoff_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 
		main_symbol_n main_file_n one_pass_link sections
		n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1
		files
	#
		xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;

	//	(marked_bool_a1,xcoff_list3) = mark_toc0_symbols 0 marked_bool_a1_ xcoff_list3_;

		(sections1,xcoff_list4,toc_table)
			= split_data_symbol_lists_of_files2 marked_offset_a0 marked_bool_a1 sections xcoff_list3 EmptyTocTable;

		(string_table_file_names_size,string_table_size,n_imported_symbols)
			= compute_xcoff_string_table_size library_list0 0 0 0 n_xcoff_symbols marked_bool_a1 ;

		symbols_a = xcoff_list_to_symbols_array n_xcoff_files xcoff_list4;	

		(pef_text_section_size0,pef_text_section_size1,pef_data_section_size0,pef_data_section_size1,pef_bss_section_end0,library_list1,module_offset_a3,xcoff_list4)
			= compute_offsets n_xcoff_symbols n_library_symbols n_imported_symbols library_list0 xcoff_list4 marked_bool_a1;

/*
		(pef_text_section_size0,pef_toc_section_size0,module_offset_a0)
			= compute_module_offsets (n_xcoff_symbols+n_library_symbols) xcoff_list4 (n_imported_symbols<<2) marked_bool_a1;

		(pef_data_section_size0,module_offset_a1)
			= compute_data_module_offsets xcoff_list4 pef_toc_section_size0 0 module_offset_a0;

		pef_data_section_size1 = (pef_data_section_size0+3) bitand (-4);

		(pef_bss_section_end0,module_offset_a2)
			= compute_bss_module_offsets xcoff_list4 pef_data_section_size1 0 marked_bool_a1 module_offset_a1;

		(library_list1,pef_text_section_size1,module_offset_a3)
			= compute_imported_library_symbol_offsets library_list0 pef_text_section_size0 n_xcoff_symbols marked_bool_a1 module_offset_a2;
*/

		pef_bss_section_end1 = (pef_bss_section_end0+3) bitand (-4);

		pef_text_section_size2=(pef_text_section_size1+3) bitand (-4);
		main_offset=module_offset_a3.[marked_offset_a0.[main_file_n]+main_symbol_n];
		loader_relocations0 = compute_xcoff_loader_relocations xcoff_list4 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a;
		(n_loader_relocations,loader_relocations) = count_and_reverse_relocations loader_relocations0;

		xcoff_loader_section_size = 32+24*n_imported_symbols+12*(n_loader_relocations+n_imported_symbols)+3+string_table_file_names_size+string_table_size;

	# (pef_file,files) = create_xcoff_file application_file_name pef_text_section_size1 pef_data_section_size1 (pef_bss_section_end1-pef_data_section_size1)
							xcoff_loader_section_size main_offset files;
	# (data_sections0,pef_file,files,xcoff_list5)
		= write_code_to_output_files xcoff_list4 0 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a one_pass_link sections1 pef_file files;
	# pef_file = pef_file
		THEN write_imported_library_functions_code library_list1 0
		THEN write_zero_bytes_to_file (pef_text_section_size2-pef_text_section_size1)
	 	THEN write_zero_longs_to_file n_imported_symbols;
	# (end_toc_offset,data_sections1,pef_file)
		= write_toc_to_pef_files data_sections0 xcoff_list5 0 (n_imported_symbols<<2) marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a pef_file;
	# pef_file = pef_file
		THEN write_data_to_pef_files data_sections1 xcoff_list5 0 end_toc_offset marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a
		THEN write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0)
//		THEN write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2)
		THEN write_xcoff_loader library_list1 n_libraries n_imported_symbols string_table_file_names_size string_table_size
				main_offset n_loader_relocations loader_relocations;
	# (ok,files)=fclose pef_file files;
	= (ok,/* pef_text_section_size2 + */ pef_bss_section_end1,files);
	
compute_xcoff_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray -> *LoaderRelocations;
compute_xcoff_loader_relocations xcoffs marked_bool_a module_offset_a marked_offset_a symbols_a
	= compute_loader_relocations_of_files xcoffs xcoffs 0 EmptyRelocation;
{
	compute_loader_relocations_of_files :: ![Xcoff] ![Xcoff] Int !*LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_files [] xcoffs first_symbol_n relocations0
		= compute_data_relocations_of_files xcoffs 0 relocations0;
	compute_loader_relocations_of_files [xcoff=:{n_symbols,symbol_table={toc_symbols,symbols},data_relocations}:xcoff_list] xcoffs first_symbol_n relocations0
		# relocations1 = compute_loader_relocations_of_file toc_symbols symbols first_symbol_n data_relocations relocations0;
		= compute_loader_relocations_of_files xcoff_list xcoffs (first_symbol_n+n_symbols) relocations1;
	
	compute_data_relocations_of_files :: ![Xcoff] Int !*LoaderRelocations -> *LoaderRelocations;
	compute_data_relocations_of_files [] first_symbol_n relocations0
		= relocations0;
	compute_data_relocations_of_files [xcoff=:{n_symbols,symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n relocations0
		# relocations1 = compute_loader_relocations_of_file data_symbols symbols first_symbol_n data_relocations relocations0;
		= compute_data_relocations_of_files xcoff_list (first_symbol_n+n_symbols) relocations1;

	compute_loader_relocations_of_file :: SymbolIndexList SymbolArray Int String *LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_file EmptySymbolIndex symbol_table first_symbol_n data_relocations relocations0
		= relocations0;
	compute_loader_relocations_of_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} first_symbol_n data_relocations relocations0
		| not marked_bool_a.[first_symbol_n+module_n]
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations relocations0;
			# relocations1 = compute_data_loader_relocations symbol relocations0;
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations relocations1;
			{
				compute_data_loader_relocations :: Symbol *LoaderRelocations -> *LoaderRelocations;
				compute_data_loader_relocations (Module {section_n,module_offset=virtual_module_offset,first_relocation_n,end_relocation_n}) relocations0
					| section_n==DATA_SECTION || section_n==TOC_SECTION
						= compute_loader_relocations first_relocation_n end_relocation_n virtual_module_offset real_module_offset data_relocations
												 first_symbol_n symbol_table relocations0;
					{}{
						real_module_offset = module_offset_a.[first_symbol_n+module_n];
					}
				compute_data_loader_relocations (AliasModule _) relocations0
					= relocations0;
				compute_data_loader_relocations (ImportedFunctionDescriptorTocModule _) relocations0
					= relocations0;
			}

	compute_loader_relocations :: Int Int Int Int String Int {!Symbol} *LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations
			first_symbol_n symbol_a relocations0
		| relocation_n==end_relocation_n
			= relocations0;
			# relocations1 = compute_relocation relocation_type symbol_a relocations0;
			= compute_loader_relocations (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations
										first_symbol_n symbol_a relocations1;
		{
			compute_relocation :: Int {!Symbol} *LoaderRelocations -> *LoaderRelocations;
			compute_relocation R_POS symbol_a relocations0
				| relocation_size==0x1f
					# offset = real_module_offset+(relocation_offset-virtual_module_offset);
					= compute_loader_relocation symbol_a.[relocation_symbol_n] offset relocations0;

			relocation_type=text_relocations BYTE (relocation_index+9);
			relocation_size=text_relocations BYTE (relocation_index+8);
			relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
			relocation_offset=text_relocations LONG relocation_index;

			relocation_index=relocation_n * SIZE_OF_RELOCATION;
		}

		compute_loader_relocation :: Symbol Int *LoaderRelocations -> *LoaderRelocations;
		compute_loader_relocation (Module {section_n}) offset relocations0
			= loader_relocation section_n offset relocations0;
		compute_loader_relocation (Label {label_section_n}) offset relocations0
			= loader_relocation label_section_n offset relocations0;
		compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset relocations0
			| implab_file_n<0
				=	CodeRelocation offset relocations0;
				=	compute_loader_relocation symbols_a.[implab_file_n,implab_symbol_n] offset relocations0;
		compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset relocations0
			= compute_loader_relocation symbols_a.[implaboffs_file_n,implaboffs_symbol_n] offset relocations0;

		loader_relocation :: Int Int *LoaderRelocations -> *LoaderRelocations;
		loader_relocation section_n offset relocations0
			| section_n==TEXT_SECTION
				= CodeRelocation offset relocations0;
			| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
				= DataRelocation offset relocations0;
	}

write_xcoff_loader_relocations :: !LoaderRelocations !*File -> *File;
write_xcoff_loader_relocations EmptyRelocation xcoff_file0
	= xcoff_file0;
write_xcoff_loader_relocations (CodeRelocation i relocations) xcoff_file0
	= write_xcoff_loader_relocations relocations (xcoff_file0 FWI i FWI 0 FWI 0x1f000002);
write_xcoff_loader_relocations (DataRelocation i relocations) xcoff_file0
	= write_xcoff_loader_relocations relocations (xcoff_file0 FWI i FWI 1 FWI 0x1f000002);



