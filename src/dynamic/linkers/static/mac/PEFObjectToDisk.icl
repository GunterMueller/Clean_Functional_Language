implementation module PEFObjectToDisk;

import StdInt,StdString, StdFile, StdArray, StdClass; 
import ExtFile,SymbolTable, xcoff, LinkerOffsets, ExtString, CommonObjectToDisk, State;

// utilities		

(!=) a b :== a<>b;

/*
write_pef_file :: .{#Char} .Int !.Int !.Int !.LibraryList !.Int !.Int .Bool !*Sections !.Int *{#.Bool} !*{#.Int} !*{#*Xcoff} *Files -> *(!Bool,Int,*Files);
write_pef_file application_file_name n_xcoff_files n_libraries n_library_symbols library_list0 main_symbol_n main_file_n one_pass_link sections
				n_xcoff_symbols marked_bool_a1 marked_offset_a0 xcoff_a1 files
	#
		(string_table_file_names_size,string_table_symbol_names_size,n_imported_symbols,marked_bool_a1)
			= compute_pef_string_table_size library_list0 0 0 0 n_xcoff_symbols marked_bool_a1;

		xcoff_list3 = xcoff_array_to_list 0 xcoff_a1;
		(sections1,xcoff_list4,toc_table,marked_offset_a0,marked_bool_a1)
			= split_data_symbol_lists_of_files2 marked_offset_a0 marked_bool_a1 sections xcoff_list3 EmptyTocTable;

		(pef_text_section_size0,pef_text_section_size1,pef_data_section_size0,pef_data_section_size1,pef_bss_section_end0,library_list1,module_offset_a3,xcoff_list4,marked_bool_a1)
			= compute_offsets n_xcoff_symbols n_library_symbols n_imported_symbols library_list0 xcoff_list4 marked_bool_a1;


		string_table_size=string_table_file_names_size+string_table_symbol_names_size;
		aligned_string_table_size=(string_table_size+3) bitand (-4);

		pef_bss_section_end1 = (pef_bss_section_end0+3) bitand (-4);	

	#! state
		= { EmptyState &
			n_libraries			= n_libraries
		,	n_xcoff_files 		= n_xcoff_files
		,	n_xcoff_symbols		= n_xcoff_symbols
		,	n_library_symbols	= n_library_symbols
		,	library_list 		= library_list1
		,	marked_bool_a		= marked_bool_a1
		,	marked_offset_a		= marked_offset_a0
		,	module_offset_a		= module_offset_a3
		,	xcoff_a 			= xcoff_list_to_array n_xcoff_files xcoff_list4
		,	namestable			= create_names_table
	};
	
	#! (i,loader_relocations0,state) 
		= compute_pef_loader_relocations2 n_imported_symbols state;  
		
		(n_loader_relocations,loader_relocations) = count_and_reverse_relocations loader_relocations0;

		pef_loader_section_size = 56+24*n_libraries+(n_imported_symbols<<2)+(n_loader_relocations<<1)+12+aligned_string_table_size+4;
		
	// compute main_offset
	# (i_marked_offset_a,state)
		= selacc_marked_offset_a main_file_n state;
	# (main_offset,state)
		= selacc_module_offset_a (i_marked_offset_a + main_symbol_n) state;
	

//	# main_offset=module_offset_a3.[marked_offset_a0.[main_file_n]+main_symbol_n];

	// write template
	# (pef_file,files) = create_pef_file application_file_name pef_text_section_size1 pef_bss_section_end1 pef_loader_section_size files;

	# (_,data_sections0,pef_file, files,state)
		= write_to_pef_files2 0 WriteText { {} \\ i <- [1..n_xcoff_files]} 0 0 state sections1 pef_file files;


// * BEGIN NEW
	# pef_file = pef_file
		THEN write_imported_library_functions_code library_list1 0
		THEN write_zero_bytes_to_file (((pef_text_section_size1+15) bitand (-16))-pef_text_section_size1)
		THEN write_zero_longs_to_file n_imported_symbols;
	# (end_toc_offset,data_sections1,pef_file,files,state)
		= write_to_pef_files2 0 WriteTOC data_sections0 0 (n_imported_symbols<<2) state EndSections pef_file files;
		
	# (_,_,pef_file,files,state)
		= write_to_pef_files2 0 WriteData data_sections1 0 end_toc_offset state EndSections pef_file files;
	# pef_file = pef_file
		THEN write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0)
		THEN write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2)
		THEN write_zero_bytes_to_file (((pef_bss_section_end1+15) bitand (-16))-pef_bss_section_end1)
		THEN write_pef_loader library_list1 n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size 
					main_offset n_loader_relocations loader_relocations;
	# (ok,files)=fclose pef_file files;

	= (ok,pef_bss_section_end1,files);

// * END NEW



/*
AFSLUITER
	// dummy
//	# (ok,files)=fclose pef_file files;
	= (ok,0,files);
*/


/*
OLD:
#		(xcoff_a,state)
			= acc_xcoff_a (\xcoff_a -> (xcoff_a,{})) state;
		// back to old state *******************************************
		# 
		xcoff_list4 = xcoff_array_to_list 0 xcoff_a;
		symbols_a = xcoff_list_to_symbols_array n_xcoff_files xcoff_list4;
		# marked_bool_a1 = state.marked_bool_a;
		marked_offset_a0 = state.marked_offset_a;
		module_offset_a3 = state.module_offset_a;
		
				main_offset=module_offset_a3.[marked_offset_a0.[main_file_n]+main_symbol_n];
		
	
	# (pef_file,files) = create_pef_file application_file_name pef_text_section_size1 pef_bss_section_end1 pef_loader_section_size files;

	# (_,data_sections0,pef_file, files)
		= write_to_pef_files WriteText { {} \\ i <- [1..n_xcoff_files]} xcoff_list4 0 0 marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a sections1 pef_file files;

	// conversions
	# xcoff_list5
		= xcoff_list4;

/*
	// dummy
		# (ok,files)=fclose pef_file files;
	= (ok,0,files);
*/

	# pef_file = pef_file
		THEN write_imported_library_functions_code library_list1 0
		THEN write_zero_bytes_to_file (((pef_text_section_size1+15) bitand (-16))-pef_text_section_size1)
		THEN write_zero_longs_to_file n_imported_symbols;
	# (end_toc_offset,data_sections1,pef_file,files)
		= write_to_pef_files WriteTOC data_sections0 xcoff_list5 0 (n_imported_symbols<<2) marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a EndSections pef_file files;
		
	# (_,_,pef_file,files)
		= write_to_pef_files WriteData data_sections1 xcoff_list5 0 end_toc_offset marked_bool_a1 module_offset_a3 marked_offset_a0 symbols_a EndSections pef_file files;
	# pef_file = pef_file
		THEN write_zero_bytes_to_file (pef_data_section_size1-pef_data_section_size0)
		THEN write_zero_longs_to_file ((pef_bss_section_end1-pef_data_section_size1)>>2)
		THEN write_zero_bytes_to_file (((pef_bss_section_end1+15) bitand (-16))-pef_bss_section_end1)
		THEN write_pef_loader library_list1 n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size 
					main_offset n_loader_relocations loader_relocations;
	# (ok,files)=fclose pef_file files;

	= (ok,pef_bss_section_end1,files);
*/
	
write_pef_loader :: !LibraryList !Int !Int !Int !Int !Int !Int !.LoaderRelocations !*File -> *File;	
write_pef_loader library_list n_libraries n_imported_symbols string_table_file_names_size string_table_symbol_names_size main_offset
				n_loader_relocations loader_relocations pef_file0
	=	pef_file1
			THEN write_library_table library_list 0 0
			THEN write_symbol_table library_list string_table_file_names_size
			FWI 0x10000 FWI n_loader_relocations FWI 0
			THEN write_loader_relocations loader_relocations
			THEN write_library_file_names library_list
			THEN write_symbol_string_table library_list
			THEN write_zero_bytes_to_file (aligned_string_table_size-string_table_size)
			FWI 0;
	{
		pef_file1 = fwritei 0 (fwritei 0 (fwritei slot_table_offset (fwritei string_table_offset (fwritei relocation_table_offset (fwritei 1 (
					fwritei n_imported_symbols (fwritei n_libraries (fwritei 0 (fwritei (-1) (fwritei 0 (fwritei (-1) (fwritei main_offset (fwritei 1 pef_file0)))))))))))));

		aligned_string_table_size=(string_table_size+3) bitand (-4);
		string_table_size=string_table_file_names_size+string_table_symbol_names_size;

		relocation_table_offset = 56+n_libraries*24+(n_imported_symbols<<2)+12;
		string_table_offset = relocation_table_offset+(n_loader_relocations<<1);
		slot_table_offset = string_table_offset+aligned_string_table_size;

		write_library_table EmptyLibraryList string_table_offset first_symbol_n pef_file0
			= pef_file0;
		write_library_table (Library file_name _ n_imported_symbols2 libraries) string_table_offset first_symbol_n pef_file0
			= write_library_table libraries (string_table_offset + 1 + size file_name) (first_symbol_n+n_imported_symbols) pef_file1;
			{
				pef_file1 = fwritei 0 (fwritei first_symbol_n (fwritei n_imported_symbols (fwritei 0 (fwritei 0 (fwritei string_table_offset pef_file0)))));
				n_imported_symbols = n_imported_symbols2>>1;
			}
	
		write_library_file_names EmptyLibraryList pef_file0
			= pef_file0;
		write_library_file_names (Library file_name _ _ libraries) pef_file0
			= write_library_file_names libraries (fwritec '\0' (fwrites file_name pef_file0));
			
		write_symbol_table EmptyLibraryList string_table_offset0 pef_file0
			= pef_file0;
		write_symbol_table (Library _ imported_symbols _ libraries) string_table_offset0 pef_file0
			= write_symbol_table libraries string_table_offset1 pef_file1;
			{
				(string_table_offset1,pef_file1) = write_symbol_table_entries imported_symbols string_table_offset0 pef_file0;
			}
			
			write_symbol_table_entries :: LibrarySymbolsList Int *File -> (!Int,!*File);
			write_symbol_table_entries EmptyLibrarySymbolsList string_table_offset0 pef_file0
				= (string_table_offset0,pef_file0);
			write_symbol_table_entries (LibrarySymbol symbol_name symbols) string_table_offset0 pef_file0
				= write_symbol_table_entries symbols (1 + size symbol_name + string_table_offset0) (fwritei (0x2000000+string_table_offset0) pef_file0);
		
		write_symbol_string_table EmptyLibraryList pef_file0
			= pef_file0;
		write_symbol_string_table (Library _ imported_symbols _ libraries) pef_file0
			= write_symbol_string_table libraries (write_symbol_strings imported_symbols pef_file0);
		
			write_symbol_strings EmptyLibrarySymbolsList pef_file0
				= pef_file0;
			write_symbol_strings (LibrarySymbol symbol_name symbols) pef_file0
				= write_symbol_strings symbols (fwritec '\0' (fwrites symbol_name pef_file0));
	}

create_pef_file :: !String Int Int Int !*Files -> *(*File,*Files);
create_pef_file pef_file_name text_section_size data_section_size loader_section_size files0
	| ok
		= (file1,files1);
		= abort ("create_pef_file: " +++ pef_file_name);  
	{}{
		(ok,file0,files1) = fopen pef_file_name FWriteData files0;

		file1 = file0	
			// container header
			FWS "Joy!"		// magic1 and magic2
			FWS "peff"		// container identifier
			FWS "pwpc"		// architecture identifier {m68k,pwpc}
			FWI 1 			// Version (1)
			FWI 0 			// Date/time stamp
			FWI 0 			// Old definition version
			FWI 0 			// Old implementation version
			FWI 0 			// Current version number
			FWW 3			// Number of sections
			FWW 2			// Number of loadable (executable) sections e.i. number of first non-loadable section
			FWI 0			// 0
			
			// section headers; .text
			FWI (-1)				// section name 
			FWI 0					// section_address
			FWI text_section_size	// exec size
			FWI text_section_size	// init size
			FWI text_section_size 	// raw size
			FWI 128					// container offset
			FWB 0					// region kind
			FWB 2					// sharing kind
			FWB 1					// alignment: halfword
			FWB 0					// reserved
			
			// section headers; .data
			FWI (-1) 
			FWI 0 
			FWI data_section_size 
			FWI data_section_size 
			FWI data_section_size 
			FWI (128+aligned_text_section_size)
			
			FWB 1
			FWB 1					// sharing kind
			FWB 3					// aligment: halfword 
			FWB 0					// reserved

			// section headers; .loader
			FWI (-1)
			FWI 0 
			FWI 0 
			FWI 0 
			FWI loader_section_size 
			FWI (128+aligned_text_section_size+aligned_data_section_size)
			FWB 4
			FWB 1
			FWB 0
			FWB 0
			
	//		FWI 0x04010000
			
			FWI 0;
			
			
			/*
			(unaligned offset of raw_data) 124 = 40 (container header) + 3(text,data,loader) * (28 section header)
			
			text_section aliigned at 16 bytes
			thus 124 aligned on 16 bytes is 128
			*/

		aligned_text_section_size=(text_section_size+15) bitand (-16);
		aligned_data_section_size=(data_section_size+15) bitand (-16);
	}
			
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

write_loader_relocations :: !LoaderRelocations !*File -> *File;
write_loader_relocations EmptyRelocation pef_file
	= pef_file;
write_loader_relocations (CodeRelocation i relocations) pef_file
	# deci = dec i;
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x40+(deci>>8))) pef_file));
write_loader_relocations (DataRelocation i relocations) pef_file
	# deci = dec i;
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x42+(deci>>8))) pef_file));
write_loader_relocations (DeltaDataRelocation d i relocations) pef_file
	# d_4 =  d>>2;
	= write_loader_relocations relocations (fwritec (toChar (((d_4 bitand 3)<<6) bitor i)) (fwritec (toChar ((d_4>>2))) pef_file));
write_loader_relocations (DeltaRelocation i relocations) pef_file
	# deci = dec i;
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x80+(deci>>8))) pef_file));
write_loader_relocations (ImportedSymbolsRelocation i relocations) pef_file
	# deci = dec i;
	= write_loader_relocations relocations (fwritec (toChar deci) (fwritec (toChar (0x4a+(deci>>8))) pef_file));

	first_zero_char_offset string offset
		| offset >= size string
			= offset;
		| string CHAR offset=='\0'
			= offset;
			= first_zero_char_offset string (offset+1);
			
(<::) infixr;
(<::) f g:==let { (a,b)=g; } in f a b;

(<:::) infixr;
(<:::) f g :== let { (a,b,c) = g; } in f a b c;

compute_pef_loader_relocations2 :: !Int !*State -> (!Int,*LoaderRelocations,!*State);
compute_pef_loader_relocations2 n_imported_symbols state=:{n_xcoff_files}
	# (relocation_offset0,relocations0,state)
		= loop_xcoff_a select_toc_symbols 0 0 (n_imported_symbols<<2) (imported_symbol_relocations n_imported_symbols) state;
	= loop_xcoff_a select_data_symbols 0 0 relocation_offset0 relocations0 state;
where {

	select_toc_symbols symbol_table=:{toc_symbols}
		= (toc_symbols,symbol_table);
		
	select_data_symbols symbol_table=:{data_symbols}
		= (data_symbols,symbol_table);
		
		
	loop_xcoff_a :: (*SymbolTable -> (SymbolIndexList,*SymbolTable)) Int Int Int !*LoaderRelocations !*State -> (!Int,*LoaderRelocations,!*State);
	loop_xcoff_a select_symbols xcoff_n first_symbol_n relocation_offset0 relocations0 state =:{n_xcoff_files}
		| xcoff_n == n_xcoff_files
			= (relocation_offset0,relocations0,state);
		
		# (n_symbols,state)
			= selacc_xcoff xcoff_n (\xcoff=:{n_symbols} -> (n_symbols,xcoff)) state;
		# (toc_symbols,state)
			= selacc_symbol_table xcoff_n /*(\symbol_table=:{toc_symbols} -> (toc_symbols,symbol_table))*/ select_symbols state;
		= loop_xcoff_a select_symbols (inc xcoff_n) (first_symbol_n + n_symbols)
			<::: loop_symbol_index_list xcoff_n toc_symbols first_symbol_n relocation_offset0 relocations0 state;
			
			
	/*
		compute_data_relocations_of_files :: ![Xcoff] Int Int !*LoaderRelocations -> *LoaderRelocations;
	compute_data_relocations_of_files [] first_symbol_n relocation_offset0 relocations0
		= relocations0;
	compute_data_relocations_of_files [xcoff=:{n_symbols,symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n relocation_offset0 relocations0
		= compute_data_relocations_of_files xcoff_list (first_symbol_n+n_symbols) 
			<:: compute_loader_relocations_of_file data_symbols symbols first_symbol_n data_relocations relocation_offset0 relocations0;
		*/

	loop_symbol_index_list :: !Int !SymbolIndexList !Int !Int *LoaderRelocations !*State -> (!Int,!*LoaderRelocations,!*State);
	loop_symbol_index_list _ EmptySymbolIndex first_symbol_n relocation_offset0 relocations0 state
		= (relocation_offset0,relocations0,state);
		
	loop_symbol_index_list file_n (SymbolIndex module_n symbol_list) first_symbol_n relocation_offset0 relocations0 state
		# (is_symbol_marked,state)
			= selacc_marked_bool_a (first_symbol_n+module_n) state;
		| not is_symbol_marked
			= loop_symbol_index_list file_n symbol_list first_symbol_n relocation_offset0 relocations0 state;
			
			# (symbol,state)
				= sel_symbol file_n module_n state;
			= loop_symbol_index_list file_n symbol_list first_symbol_n
				<::: compute_symbol_relocations symbol relocation_offset0 relocations0 state;
	where {
		compute_symbol_relocations :: Symbol Int *LoaderRelocations !*State -> (!Int,!*LoaderRelocations,!*State);
		compute_symbol_relocations (Module {section_n,module_offset=virtual_module_offset,first_relocation_n,end_relocation_n}) relocation_offset0 relocations0 state
			| section_n==DATA_SECTION || section_n==TOC_SECTION
				# (data_relocations,state)
					= selacc_xcoff file_n (\xcoff=:{data_relocations} -> (data_relocations,xcoff)) state;
				# (real_module_offset,state)
					= selacc_module_offset_a (first_symbol_n + module_n) state;	
				= loop_relocations file_n first_relocation_n end_relocation_n virtual_module_offset real_module_offset data_relocations first_symbol_n 
									  relocation_offset0 relocations0 state; 	
		compute_symbol_relocations (AliasModule _) relocation_offset0 relocations0 state
			= (relocation_offset0,relocations0,state);
			
		compute_symbol_relocations (ImportedFunctionDescriptorTocModule _) relocation_offset0 relocations0 state
			= (relocation_offset0,relocations0,state);		
	} // loop_symbol_index_list


	loop_relocations :: !Int !Int !Int !Int !Int !String !Int !Int *LoaderRelocations !*State -> (!Int,!*LoaderRelocations,!*State);
	loop_relocations file_n relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations first_symbol_n /* <::: */ relocation_offset0 relocations0 state
		| relocation_n==end_relocation_n
			= (relocation_offset0,relocations0,state);
		= loop_relocations file_n (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations first_symbol_n
			<::: compute_relocation relocation_type relocation_offset0 relocations0 state;
	where {
		compute_relocation :: Int  Int *LoaderRelocations !*State -> (!Int,!*LoaderRelocations,!*State);
		compute_relocation relocation_type relocation_offset0 relocations0 state
			| (relocation_type==R_POS || relocation_type==R_MW_POS) && relocation_size==0x1f
				# offset 
					= real_module_offset + (relocation_offset-virtual_module_offset);
				# (relocation_symbol,state)
					= sel_symbol file_n relocation_symbol_n state;
				= compute_loader_relocation relocation_symbol offset first_symbol_n relocation_offset0 relocations0 state;
		
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;
	
		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	} // loop_relocations
	
	compute_loader_relocation :: Symbol Int Int Int *LoaderRelocations !*State -> (!Int,!*LoaderRelocations,!*State);
	compute_loader_relocation (Module {section_n}) offset first_symbol_n relocation_offset0 relocations0 state
		# (relocation_offset,relocations)
			= loader_relocation section_n offset relocation_offset0 relocations0;
		= (relocation_offset,relocations,state);
		
	compute_loader_relocation (Label {label_section_n}) offset first_symbol_n relocation_offset0 relocations0 state
		# (relocation_offset,relocations)
			= loader_relocation label_section_n offset relocation_offset0 relocations0;
		= (relocation_offset,relocations,state);
		
	compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset first_symbol_n relocation_offset0 relocations0 state
		| implab_file_n<0
			# (relocation_offset,relocations)
				= loader_code_relocation offset relocation_offset0 relocations0;
			= (relocation_offset,relocations, state);
			
			# (first_symbol_n,state)
				= selacc_marked_offset_a implab_file_n state;
			# (imported_symbol,state)
				= sel_symbol implab_file_n implab_symbol_n state;
			= compute_loader_relocation imported_symbol offset first_symbol_n relocation_offset0 relocations0 state;
		
	compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset first_symbol_n relocation_offset0 relocations0 state
		# (first_symbol_n,state)
			= selacc_marked_offset_a implaboffs_file_n state;
		# (imported_label_plus_offset_symbol,state)
			= sel_symbol implaboffs_file_n implaboffs_symbol_n state;
		=	compute_loader_relocation imported_label_plus_offset_symbol offset first_symbol_n  relocation_offset0 relocations0 state;
	

	loader_relocation :: Int Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_relocation section_n offset relocation_offset0 relocations0
		| section_n==TEXT_SECTION
			= loader_code_relocation offset relocation_offset0 relocations0;
		| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
			= loader_data_relocation offset relocation_offset0 relocations0;

	loader_code_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_code_relocation offset relocation_offset0 (CodeRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,CodeRelocation (inc n) relocations);
	loader_code_relocation offset relocation_offset0 relocations0
		= (offset+4,CodeRelocation 1 (loader_delta_relocations (offset-relocation_offset0) relocations0));

	loader_data_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_data_relocation offset relocation_offset0 (DataRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,DataRelocation (inc n) relocations);
	loader_data_relocation offset relocation_offset0 relocations0
		| displacement>0 && displacement<1024 && (displacement bitand 3)==0
			= (offset+4,DeltaDataRelocation displacement 1 relocations0);
			= (offset+4,DataRelocation 1 (loader_delta_relocations displacement relocations0));
		{}{
			displacement=offset-relocation_offset0;
		}

	loader_delta_relocations 0 relocations
		= relocations;
	loader_delta_relocations offset relocations
		| offset<=4096
			= DeltaRelocation offset relocations;
			= loader_delta_relocations (offset-4096) (DeltaRelocation 4096 relocations);	
	
/*
	compute_loader_relocations :: Int Int Int Int String Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocations relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations
			first_symbol_n symbol_a relocation_offset0 relocations0
		| relocation_n==end_relocation_n
			= (relocation_offset0,relocations0);
			= compute_loader_relocations (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations first_symbol_n symbol_a
			  <:: compute_relocation relocation_type symbol_a relocation_offset0 relocations0;
	{		
		compute_relocation :: Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
		compute_relocation relocation_type symbol_a relocation_offset0 relocations0
			| (relocation_type==R_POS || relocation_type==R_MW_POS) && relocation_size==0x1f
				# offset = real_module_offset+(relocation_offset-virtual_module_offset);
				= compute_loader_relocation symbol_a.[relocation_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
		
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;

		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}

	compute_loader_relocation :: Symbol Int Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocation (Module {section_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		= loader_relocation section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (Label {label_section_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		= loader_relocation label_section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		| implab_file_n<0
			=	loader_code_relocation offset relocation_offset0 relocations0;
			=	compute_loader_relocation symbol_a.[implab_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
			{
				first_symbol_n = marked_offset_a.[implab_file_n];
				symbol_a=symbols_a.[implab_file_n];		
			}
	compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		=	compute_loader_relocation symbol_a.[implaboffs_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
		{
			first_symbol_n = marked_offset_a.[implaboffs_file_n];
			symbol_a=symbols_a.[implaboffs_file_n];		
		}

	loader_relocation :: Int Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_relocation section_n offset relocation_offset0 relocations0
		| section_n==TEXT_SECTION
			= loader_code_relocation offset relocation_offset0 relocations0;
		| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
			= loader_data_relocation offset relocation_offset0 relocations0;

	loader_code_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_code_relocation offset relocation_offset0 (CodeRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,CodeRelocation (inc n) relocations);
	loader_code_relocation offset relocation_offset0 relocations0
		= (offset+4,CodeRelocation 1 (loader_delta_relocations (offset-relocation_offset0) relocations0));

	loader_data_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_data_relocation offset relocation_offset0 (DataRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,DataRelocation (inc n) relocations);
	loader_data_relocation offset relocation_offset0 relocations0
		| displacement>0 && displacement<1024 && (displacement bitand 3)==0
			= (offset+4,DeltaDataRelocation displacement 1 relocations0);
			= (offset+4,DataRelocation 1 (loader_delta_relocations displacement relocations0));
		{}{
			displacement=offset-relocation_offset0;
		}

	loader_delta_relocations 0 relocations
		= relocations;
	loader_delta_relocations offset relocations
		| offset<=4096
			= DeltaRelocation offset relocations;
			= loader_delta_relocations (offset-4096) (DeltaRelocation 4096 relocations);
}
*/
					
	imported_symbol_relocations :: !Int -> !*LoaderRelocations;
	imported_symbol_relocations 0
		= EmptyRelocation;
	imported_symbol_relocations n_imported_symbols
		| n_imported_symbols<=512
			= ImportedSymbolsRelocation n_imported_symbols EmptyRelocation;
			= ImportedSymbolsRelocation 512 (imported_symbol_relocations (n_imported_symbols-512));
}

	

	

compute_pef_loader_relocations :: ![Xcoff] {#Bool} {#Int} {#Int} SymbolsArray Int -> *LoaderRelocations;
compute_pef_loader_relocations xcoffs marked_bool_a module_offset_a marked_offset_a symbols_a n_imported_symbols
	= compute_loader_relocations_of_files xcoffs 0 (n_imported_symbols<<2) (imported_symbol_relocations n_imported_symbols);
{
	imported_symbol_relocations :: !Int -> !*LoaderRelocations;
	imported_symbol_relocations 0
		= EmptyRelocation;
	imported_symbol_relocations n_imported_symbols
		| n_imported_symbols<=512
			= ImportedSymbolsRelocation n_imported_symbols EmptyRelocation;
			= ImportedSymbolsRelocation 512 (imported_symbol_relocations (n_imported_symbols-512));
	
	compute_loader_relocations_of_files :: ![Xcoff] Int Int !*LoaderRelocations -> *LoaderRelocations;
	compute_loader_relocations_of_files [] first_symbol_n relocation_offset0 relocations0
		= compute_data_relocations_of_files xcoffs 0 relocation_offset0 relocations0;
	compute_loader_relocations_of_files [xcoff=:{n_symbols,symbol_table={toc_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n relocation_offset0 relocations0
		= compute_loader_relocations_of_files xcoff_list (first_symbol_n+n_symbols) 
		  <:: compute_loader_relocations_of_file toc_symbols symbols first_symbol_n data_relocations relocation_offset0 relocations0;

	compute_data_relocations_of_files :: ![Xcoff] Int Int !*LoaderRelocations -> *LoaderRelocations;
	compute_data_relocations_of_files [] first_symbol_n relocation_offset0 relocations0
		= abort (toString relocation_offset0); //relocations0;
	compute_data_relocations_of_files [xcoff=:{n_symbols,symbol_table={data_symbols,symbols},data_relocations}:xcoff_list] first_symbol_n relocation_offset0 relocations0
		= compute_data_relocations_of_files xcoff_list (first_symbol_n+n_symbols) 
			<:: compute_loader_relocations_of_file data_symbols symbols first_symbol_n data_relocations relocation_offset0 relocations0;

	compute_loader_relocations_of_file :: SymbolIndexList SymbolArray Int String Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocations_of_file EmptySymbolIndex symbol_table first_symbol_n data_relocations relocation_offset0 relocations0
		= (relocation_offset0,relocations0);
	compute_loader_relocations_of_file (SymbolIndex module_n symbol_list) symbol_table=:{[module_n] = symbol} first_symbol_n data_relocations relocation_offset0 relocations0
		| not (marked_bool_a.[first_symbol_n+module_n])
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations relocation_offset0 relocations0;
			= compute_loader_relocations_of_file symbol_list symbol_table first_symbol_n data_relocations
				<:: compute_data_loader_relocations symbol relocation_offset0 relocations0;

		{
			compute_data_loader_relocations :: Symbol Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
			compute_data_loader_relocations (Module {section_n,module_offset=virtual_module_offset,first_relocation_n,end_relocation_n}) relocation_offset0 relocations0
				| section_n==DATA_SECTION || section_n==TOC_SECTION
					= compute_loader_relocations first_relocation_n end_relocation_n virtual_module_offset real_module_offset data_relocations
												 first_symbol_n symbol_table relocation_offset0 relocations0;
				{}{
					real_module_offset = module_offset_a.[first_symbol_n+module_n];
				}
			compute_data_loader_relocations (AliasModule _) relocation_offset0 relocations0
				= (relocation_offset0,relocations0);
			compute_data_loader_relocations (ImportedFunctionDescriptorTocModule _) relocation_offset0 relocations0
				= (relocation_offset0,relocations0);
		}

	compute_loader_relocations :: Int Int Int Int String Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocations relocation_n end_relocation_n virtual_module_offset real_module_offset text_relocations
			first_symbol_n symbol_a relocation_offset0 relocations0
		| relocation_n==end_relocation_n
			= (relocation_offset0,relocations0);
			= compute_loader_relocations (inc relocation_n) end_relocation_n virtual_module_offset real_module_offset text_relocations first_symbol_n symbol_a
			  <:: compute_relocation relocation_type symbol_a relocation_offset0 relocations0;
	{		
		compute_relocation :: Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
		compute_relocation relocation_type symbol_a relocation_offset0 relocations0
			| (relocation_type==R_POS || relocation_type==R_MW_POS) && relocation_size==0x1f
				# offset = real_module_offset+(relocation_offset-virtual_module_offset);
				= compute_loader_relocation symbol_a.[relocation_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
		
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;

		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}

	compute_loader_relocation :: Symbol Int Int {!Symbol} Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	compute_loader_relocation (Module {section_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		= loader_relocation section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (Label {label_section_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		= loader_relocation label_section_n offset relocation_offset0 relocations0;
	compute_loader_relocation (ImportedLabel {implab_file_n,implab_symbol_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		| implab_file_n<0
			=	loader_code_relocation offset relocation_offset0 relocations0;
			=	compute_loader_relocation symbol_a.[implab_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
			{
				first_symbol_n = marked_offset_a.[implab_file_n];
				symbol_a=symbols_a.[implab_file_n];		
			}
	compute_loader_relocation (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n}) offset first_symbol_n symbol_a relocation_offset0 relocations0
		=	compute_loader_relocation symbol_a.[implaboffs_symbol_n] offset first_symbol_n symbol_a relocation_offset0 relocations0;
		{
			first_symbol_n = marked_offset_a.[implaboffs_file_n];
			symbol_a=symbols_a.[implaboffs_file_n];		
		}

	loader_relocation :: Int Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_relocation section_n offset relocation_offset0 relocations0
		| section_n==TEXT_SECTION
			= loader_code_relocation offset relocation_offset0 relocations0;
		| section_n==DATA_SECTION || section_n==BSS_SECTION || section_n==TOC_SECTION
			= loader_data_relocation offset relocation_offset0 relocations0;

	loader_code_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_code_relocation offset relocation_offset0 (CodeRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,CodeRelocation (inc n) relocations);
	loader_code_relocation offset relocation_offset0 relocations0
		= (offset+4,CodeRelocation 1 (loader_delta_relocations (offset-relocation_offset0) relocations0));

	loader_data_relocation :: Int Int *LoaderRelocations -> (!Int,!*LoaderRelocations);
	loader_data_relocation offset relocation_offset0 (DataRelocation n relocations)
		| offset==relocation_offset0 && n<512
			= (offset+4,DataRelocation (inc n) relocations);
	loader_data_relocation offset relocation_offset0 relocations0
		| displacement>0 && displacement<1024 && (displacement bitand 3)==0
			= (offset+4,DeltaDataRelocation displacement 1 relocations0);
			= (offset+4,DataRelocation 1 (loader_delta_relocations displacement relocations0));
		{}{
			displacement=offset-relocation_offset0;
		}

	loader_delta_relocations 0 relocations
		= relocations;
	loader_delta_relocations offset relocations
		| offset<=4096
			= DeltaRelocation offset relocations;
			= loader_delta_relocations (offset-4096) (DeltaRelocation 4096 relocations);
}
*/
