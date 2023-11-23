implementation module CommonObjectToDisk;

import StdFile, StdInt;
import ExtFile, ExtString, xcoff;
import SymbolTable;
import Relocations;
import State;

import DebugUtilities;

:: *WriteOutputRecord = {
	file_or_memory	:: !Int,
	offset			:: !Int,
	string			:: !{#Char},
	
	// was ChangeStateRecord
	file_n			:: !Int,
	module_n		:: !Int,
	state			:: !*State
	};


class Target2 a
where
{
	WriteOutput :: !WriteOutputRecord !*a -> (!*a,!*State);
	

	WriteLong	:: !Int !*a -> !*a;
	
	DoRelocations :: !*a -> (!Bool,!*a);
	
	BeforeWritingXcoffFile :: !Int !*a !*State -> (!*a,!*State);
	
	AfterWritingXcoffFile :: !Int !*a !*State -> (!*a,!*State)
};

:: WriteKind = WriteText | WriteData | WriteTOC | WriteDataAndToc;

instance Target2 File
where {
	WriteOutput :: !WriteOutputRecord !*File -> (!*File,!*State); 
	WriteOutput {file_or_memory,offset,string,state} pef_file
		= (fwrites string pef_file,state);
		

		
	//WriteLong :: !Int !*File -> !*File;
	WriteLong w pef_file
		= fwritei w pef_file;
		
	DoRelocations pef_file
		= (True,pef_file);
		
	BeforeWritingXcoffFile _ pef_file state
		= (pef_file,state);
		
	AfterWritingXcoffFile _ pef_file state
		= (pef_file,state);
	
};

// -----------------------
write_to_pef_files2 :: !Int !WriteKind {*String} Int Int !*State Sections !*a !*Files -> ((!Int,!{*{#Char}},!*a,!*State), !*Files) | Target2 a ;
write_to_pef_files2 file_n write_kind ds first_symbol_n offset state=:{n_xcoff_files} sections pef_file files
	| file_n == n_xcoff_files
		= ((offset,ds,pef_file,state),files);		
		
		// select from state
		# (text_v_address,state)
			= selacc_text_v_address file_n state;
		# (data_v_address,state)
			= selacc_data_v_address file_n state;
		# (text_relocations,state)
			= selacc_text_relocations file_n state;
		# (data_relocations,state)
			= selacc_data_relocations file_n state;
		# (n_symbols,state)
			= selacc_n_symbols file_n state;
			 
		//
		# (offset,data_section,ds,sections,state,pef_file,files)
			= case write_kind of {
				WriteText
					// select from state
					# (text_symbols,state)
						= selacc_text_symbols file_n state;
					# (toc0_symbol,state)
						= selacc_toc0_symbols file_n state;
						
					# (ok,text_section,data_section,sections,state,files)
						= read_text_and_data_section one_pass_link sections  state files;
					| not ok
						-> abort "write_code_to_output_files: read error 1";
						
					// new 
					# (pef_file,state)
						= BeforeWritingXcoffFile file_n pef_file state;
						
					# (_,data_section1,offset ,pef_file,state)
						= write_symbol_index_list_to_pef_file2 text_symbols file_n toc0_symbol first_symbol_n offset text_section text_v_address 
																text_relocations 
															   data_section data_v_address data_relocations state pef_file;
					
					# (pef_file,state)
						= AfterWritingXcoffFile file_n pef_file state;
						
					-> (offset,data_section1,ds,sections,state,pef_file,files);
				WriteTOC
					// select from state
					# (toc_symbols,state)
						= selacc_toc_symbols file_n state;
						
					# (data_section,ds)
						= replace ds file_n {};
					# (data_section,_,offset,pef_file,state)
						= write_symbol_index_list_to_pef_file2 toc_symbols file_n EmptySymbolIndex first_symbol_n offset data_section 
						data_v_address data_relocations {'a','b','c'} 0 {'a','b'} state pef_file;
					-> (offset,data_section,ds,sections,state,pef_file,files);

				WriteData
					// select from state
					# (data_symbols,state)
						= selacc_data_symbols file_n state;
				
					# (data_section,ds)
						= replace ds file_n {};
					# (_,_,offset,pef_file,state)
						= write_symbol_index_list_to_pef_file2 data_symbols file_n EmptySymbolIndex first_symbol_n offset data_section 
						data_v_address data_relocations {} 0 {} state pef_file;
					-> (offset,{},ds,sections,state,pef_file,files);
					
				WriteDataAndToc
					// select from state
					# (data_symbols,state)
						= selacc_data_symbols file_n state;
					# (toc_symbols,state)
						= selacc_toc_symbols file_n state;
						
					// new 
					# (pef_file,state)
						= BeforeWritingXcoffFile file_n pef_file state;
						
					// write toc and data symbols 
					# (data_section,ds)
						= replace ds file_n {};
					# (data_section,_,offset,pef_file,state)
						= write_symbol_index_list_to_pef_file2 toc_symbols file_n EmptySymbolIndex first_symbol_n offset data_section 
							data_v_address data_relocations {'a','b','c'} 0 {'a','b'} state pef_file;	
					# (_,_,offset,pef_file,state)
						= write_symbol_index_list_to_pef_file2 data_symbols file_n EmptySymbolIndex first_symbol_n offset data_section 
						data_v_address data_relocations {} 0 {} state pef_file;
						
					# (pef_file,state)
						= AfterWritingXcoffFile file_n pef_file state;
						
						
						
					-> (offset,{},ds,sections,state,pef_file,files);


			}
		= write_to_pef_files2 (inc file_n) write_kind {ds & [file_n] = data_section} (first_symbol_n + n_symbols) offset state sections pef_file files;	
{} {
	
	one_pass_link
		= True;

	read_text_and_data_section :: !Bool Sections !*State !*Files -> (!Bool,!*{#Char},!*{#Char},!Sections,!*State,!*Files);
	read_text_and_data_section one_pass_link /*(Sections text_section data_section sections)*/ initial_sections state files
		#! (text_section,data_section,sections)
			= case initial_sections of {
				EndSections
					-> ({},{},EndSections);
				(Sections text_section data_section sections)
					-> (text_section,data_section,sections)
			};
		#! (s_text_section,text_section)
			= usize text_section;
		#! (s_data_section,data_section)
			= usize data_section;
//		| s_text_section == 0 && s_data_section == 0
//			= (True,{},{},sections,state,files);			
		| s_text_section <> 0 && s_data_section <> 0
			= (True,text_section,data_section,sections,state,files);
			
		// read {text,data} section
		# (ok,xcoff_file,files)	
			= /*F ("read_text_and_data_section: " +++ file_name +++ "<" +++ toString s_text_section +++ "> <" +++ toString s_data_section +++ ">")*/ fopen file_name FReadData files;
			
	
		# (ok,text_section,xcoff_file)
			= case (ok && s_text_section == 0) of {
				True
					# (fseek_ok,xcoff_file)			
						= fseek xcoff_file text_section_offset FSeekSet;
					# (text_string,xcoff_file)
						= freads xcoff_file text_section_size;
					# (s_text_string,text_string)
						= usize text_string;
					-> (fseek_ok && s_text_string <> 0,text_string,xcoff_file);
				_
					-> (ok,text_section,xcoff_file);
			};
			
		# (ok,data_section,xcoff_file)
			= case (ok && s_data_section == 0) of {
				True
					# (fseek_ok,xcoff_file)			
						= fseek xcoff_file data_section_offset FSeekSet;
					# (data_string,xcoff_file)
						= freads xcoff_file data_section_size;
					# (s_data_string,data_string)
						= usize data_string;
					-> (fseek_ok && s_data_string <> 0,data_string,xcoff_file);
				_
					-> (ok,data_section,xcoff_file);
			};
	
		# (_,files)
			= fclose xcoff_file files;
			
		= (ok,text_section,data_section,sections,state2,files);
	where {
		(header=:{file_name,text_section_offset,text_section_size,data_section_offset,data_section_size},state2)
			= selacc_header file_n state;
	}
	
	
			
/*		
	read_text_and_data_section :: !Bool Sections !*State !*Files -> (!Bool,!*{#Char},!*{#Char},!Sections,!*State,!*Files);
	read_text_and_data_section one_pass_link /*(Sections text_section data_section sections)*/ initial_sections state files
		#! (text_section,data_section,sections)
			= case initial_sections of {
				EndSections
					-> ({},{},EndSections);
				(Sections text_section data_section sections)
					-> (text_section,data_section,sections)
			};
		
		
		# (s_text_section,text_section)
			= usize text_section;
		| (one_pass_link && ((size text_section) == 0)) || (not one_pass_link)
			# (fopen_ok,xcoff_file,files)	
				= fopen file_name FReadData files;
			
			// read .text
			# (fseek_ok,xcoff_file)			
				= fseek xcoff_file text_section_offset FSeekSet;
			# (text_string,xcoff_file)
				= freads xcoff_file text_section_size;
			
			// read .data if needed
			# (fseek2_ok,data_string,xcoff_file)
				= case (not one_pass_link) of {
				True
					# (fseek2_ok,xcoff_file)			
						= fseek xcoff_file data_section_offset FSeekSet;
					# (data_string,xcoff_file)
						= freads xcoff_file data_section_size;
					-> (fseek2_ok,data_string,xcoff_file); 
				False
					-> (True,data_section,xcoff_file);
				}
			# (fclose_ok,files)
				= fclose xcoff_file files;
			= (fopen_ok && fseek_ok && fseek2_ok && fclose_ok,text_string,data_string,sections,state2,files);
		= (True,text_section,data_section,sections,state2,files);
	where {
		(header=:{file_name,text_section_offset,text_section_size,data_section_offset,data_section_size},state2)
			= selacc_header file_n state;
	}
*/
};

write_symbol_index_list_to_pef_file2 :: !SymbolIndexList !Int !SymbolIndexList !Int !Int !*{#Char} !Int !{#Char} !*{#Char} !Int !{#Char} !*State !*a -> (!.{#Char},!.{#Char},!Int,!*a,!*State) | Target2 a;
write_symbol_index_list_to_pef_file2 EmptySymbolIndex file_n toc0_symbol first_symbol_n offset text_a0 text_v_address text_relocations data_a0 data_v_address data_relocations state pef_file
	= (text_a0,data_a0,offset,pef_file,state);

write_symbol_index_list_to_pef_file2 (SymbolIndex module_n symbol_list) file_n toc0_symbol first_symbol_n offset text_a text_v_address 
text_relocations data_a data_v_address data_relocations state pef_file
	# (marked_module_n,state)
		= selacc_marked_bool_a (first_symbol_n+module_n) state;
	| marked_module_n
		// select from xcoff
		# (symbolQ,state)
			= sel_symbol file_n module_n state;

		# (text_a,data_a,offset,pef_file,state)
			= write_data_module_to_pef_file2 symbolQ file_n offset text_a text_relocations data_a data_relocations 
											 first_symbol_n module_n text_v_address data_v_address /*symbols*/ toc0_symbol pef_file state ;
 
		= write_symbol_index_list_to_pef_file2 symbol_list file_n toc0_symbol first_symbol_n offset text_a text_v_address text_relocations data_a data_v_address data_relocations state pef_file;	
		= write_symbol_index_list_to_pef_file2 symbol_list file_n toc0_symbol first_symbol_n offset text_a text_v_address text_relocations data_a data_v_address data_relocations state pef_file;	


write_data_module_to_pef_file2 :: Symbol !Int Int *{#Char} !String !*{#Char} !String !Int !Int !Int !Int !SymbolIndexList !*a !*State -> (!*{#Char},!*{#Char},!Int,!*a,!*State) | Target2 a;
write_data_module_to_pef_file2 (Module {section_n,module_offset=virtual_module_offset,length,first_relocation_n,end_relocation_n,align=alignment})
		file_n offset0
		data_a0
		data_relocations
		text_a0
		text_relocations  
		first_symbol_n 
		module_n 
		data_v_address
		text_v_address 
		//symbols
		toc0_symbol
		pef_file0
		state
	| section_n==DATA_SECTION || section_n==TOC_SECTION || section_n == TEXT_SECTION
		# write_output_record
			= { WriteOutputRecord |
				file_or_memory		= 0
			,	offset				= offset0
			,	string				= case do_relocations of {
											True
												-> write_nop_bytes (aligned_offset0-offset0) data_string;
											False
												-> data_string;
										}
			,	file_n		= file_n,
				module_n	= module_n,
				state		= state3
		};
		# (pef_file2,state3)
			= WriteOutput write_output_record pef_file1;

		= (data_a2,text_a1,aligned_offset0+length,
		pef_file2 
		,state3);
	{}{
		(do_relocations,pef_file1)
			= DoRelocations pef_file0;
	
	
		(data_string,data_a2) = u_char_array_slice data_a1 offset (offset+length-1);
		offset=virtual_module_offset-data_v_address;
		o_i=first_symbol_n+module_n;
		
		aligned_offset0=(offset0+alignment_mask) bitand (bitnot alignment_mask);
		alignment_mask=dec (1<<alignment);
				
		(data_a1,text_a1,state3) 
		= case do_relocations of {
			True
				-> relocate_text2 first_relocation_n end_relocation_n file_n virtual_module_offset real_module_offset
								data_relocations
								text_relocations						
								first_symbol_n  data_v_address text_v_address toc0_symbol data_a0 
								text_a0 state2;
			_
				-> abort "write_data_module_to_pef_file2; no relocations allowed"; // (data_a0,text_a0,state2);
		};
								
		// added
		(real_module_offset,state2)
			= selacc_module_offset_a o_i state; 
	
	}
write_data_module_to_pef_file2 s
		file_n offset0
		data_a0
		data_relocations
		text_a0
		text_relocations  
		first_symbol_n 
		module_n 
		data_v_address
		text_v_address 
		//symbols
		toc0_symbol
		pef_file0
		state
	= (data_a0,text_a0,offset0,pef_file0,state);

	
// --------------------------------
write_imported_library_functions_code :: !Int *a !Int !*State -> *(*a,!*State) | Target2 a;
write_imported_library_functions_code descriptor_offset0 pef_file n_xcoff_symbols state=:{library_list}
	= write_imported_library_functions_code2 library_list descriptor_offset0 pef_file n_xcoff_symbols state;
{
	
	
	write_imported_library_functions_code2 :: !LibraryList !Int *a !Int !*State -> *(*a,!*State) | Target2 a;
	write_imported_library_functions_code2 EmptyLibraryList descriptor_offset pef_file n_xcoff_symbols state
		= (pef_file,state);
	
	write_imported_library_functions_code2 (Library _ imported_symbols n_symbols library_list) descriptor_offset pef_file n_xcoff_symbols state
		# (descriptor_offset,pef_file,state) 
			= write_library_functions_code imported_symbols descriptor_offset pef_file n_xcoff_symbols state;
			
		= write_imported_library_functions_code2 library_list descriptor_offset pef_file (n_xcoff_symbols+n_symbols) state;
		{
			write_library_functions_code :: !LibrarySymbolsList !Int *a !Int !*State -> *(!Int,*a,!*State) | Target2 a;
			write_library_functions_code EmptyLibrarySymbolsList descriptor_offset pef_file symbol_n state
				= (descriptor_offset,pef_file,state);
			write_library_functions_code (LibrarySymbol symbol_name symbol_list) descriptor_offset pef_file symbol_n state
				#! (marked_symbol,state)
					= selacc_marked_bool_a symbol_n state;
				| not marked_symbol
					= write_library_functions_code symbol_list descriptor_offset pef_file (symbol_n+2) state;
		
					#! pef_file
						= WriteLong (0x81828000+descriptor_offset) pef_file;
					#! pef_file
						= WriteLong 0x90410014 pef_file;
					#! pef_file
						= WriteLong 0x800C0000 pef_file;
					#! pef_file
						= WriteLong 0x804C0004 pef_file;
					#! pef_file
						= WriteLong 0x7C0903A6 pef_file;
					#! pef_file
						= WriteLong 0x4E800420 pef_file;
	
					= write_library_functions_code symbol_list (descriptor_offset+4) pef_file (symbol_n+2) state;
				
		}
}
	
/*
DISK
write_imported_library_functions_code :: LibraryList Int *File -> *File;
write_imported_library_functions_code EmptyLibraryList descriptor_offset0 pef_file0
	= pef_file0;
write_imported_library_functions_code (Library _ imported_symbols _ library_list) descriptor_offset0 pef_file0
	=	write_imported_library_functions_code library_list descriptor_offset1 pef_file1;
	{
		(descriptor_offset1,pef_file1) = write_library_functions_code imported_symbols descriptor_offset0 pef_file0;
		
		write_library_functions_code :: LibrarySymbolsList Int *File -> (!Int,!*File);
		write_library_functions_code EmptyLibrarySymbolsList descriptor_offset0 pef_file0
			= (descriptor_offset0,pef_file0);
		write_library_functions_code (LibrarySymbol symbol_name symbol_list) descriptor_offset0 pef_file0
			
			= write_library_functions_code symbol_list (descriptor_offset0+4) pef_file1;
			{
				pef_file1 = pef_file0
					FWI (/*0x81820000*/0x81828000+descriptor_offset0) FWI 0x90410014 FWI 0x800C0000 FWI 0x804C0004 
					FWI 0x7C0903A6 FWI 0x4E800420;
					
					/* NEW:
					// lwz van rechts naar links
							// linker glue code for a direct cross-TOC call 
							0x81828000	= 100000 01100 00010 1000000000000000
											 	  (d)   (a)       (d)
									lwz		r12,(0x8000+descriptor_offset0)(r2)				r12 := (0x8000+descriptor_offset0)(r2)	// load in r12 value v  
																							r12 is pointer to trans vect. for import or imported var
							0x90410014  = 100100 00010 00001 0000000000010100
											 	  (s)  (a)  	 (d)
											 	  
									stw		r2,20(r1)										20(r1) := store r2 in 20(r1), r1 = stack pointer
									
							0x800C0000	= 100000 00000 01100 0000000000000000
												  (d)   (a)      (d)
									lwz		r0,0(r12)										r0 := 0(r12) load in r0 the value 0(r12);
									
							0x804C0004	= 100000 00010 01100 0000000000000100
												   (d)   (a)     (d)	
									lwz		r2,4(r12)										load in r2 4(r12) RTOC value   r2 := RTOC
									
							0x7C0903A6	= 011111 00 0000 1001 0000 0  011 1010 011 0
											      (s)  (a)  
									mtcr	r0
										   			 
							0x4E800420	= 010011 10100 00000 00000 1000010000 0=(LK)
													BO   BI     0
													
									bcctr (=bctr)  
					*/
			}
	}
*/

	
count_and_reverse_relocations :: !*LoaderRelocations -> (!Int,!*LoaderRelocations);
count_and_reverse_relocations relocation
	= count_relocations relocation 0 EmptyRelocation;
{
	count_relocations :: !*LoaderRelocations !Int !*LoaderRelocations -> (!Int,!*LoaderRelocations);
	count_relocations (CodeRelocation i r) n result
		= count_relocations r (inc n) (CodeRelocation i result);
	count_relocations (DataRelocation i r) n result
		= count_relocations r (inc n) (DataRelocation i result);
	count_relocations (DeltaDataRelocation d i r) n result
		= count_relocations r (inc n) (DeltaDataRelocation d i result);
	count_relocations (DeltaRelocation i r) n result
		= count_relocations r (inc n) (DeltaRelocation i result);
	count_relocations (ImportedSymbolsRelocation i r) n result
		= count_relocations r (inc n) (ImportedSymbolsRelocation i result);
	count_relocations EmptyRelocation n result
		= (n,result);
}					

write_nop_bytes :: !Int !{#Char} -> !{#Char};
write_nop_bytes n string
	= (createArray n (toChar 0x90)) +++ string;