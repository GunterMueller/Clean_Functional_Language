implementation module PlatformLinkOptions;

import StdEnv;
import Sections;
import State;
import xcoff;
import LinkerOffsets;
import CommonObjectToDisk;
import LinkerMessages;
import ExtFile, ExtString, ExtInt; 

from RelocSection import ::RelocBlock, compute_relocs_section,write_reloc_section;
from IdataSection import compute_idata_strings_size;
from IdataSection import write_imported_library_functions_code_32,
						 write_imported_library_functions_code_64,write_idata;
from WriteMapFile import generate_map_file;
from ReadObject import read_coff_header;
import edata;
import pdSections,pdExtFile,pdExtString,pdExtInt,pdSymbolTable;
import NamesTable,link32or64bits;

::	LinkOptions = {
		open_console_window			:: !Bool,
		relocations_needed			:: !Bool,
		generate_symbol_table		:: !Bool,
		make_dll					:: !Bool,
		make_map_file				:: !Bool,
		make_resource				:: !Bool,
		resource_file_name			:: !String,
		c_stack_size				:: !Int
 	};

:: *PlatformLinkOptions = {
	// true link options
		plo_lo						:: !LinkOptions
	// sections
	,	n_image_sections			:: !Int
	,	section_header_a			:: *{!SectionHeader}
	,	any_extra_sections			:: !Bool
	// .idata 
	,	idata_strings_size			:: !Int
	,	n_imported_symbols			:: !Int
	// general
	,	start_rva					:: !Int
	,	end_rva						:: !Int
	,	start_fp					:: !Int
	,	end_fp						:: !Int
	, 	sections					:: *Sections
	, 	main_file_n					:: !Int
	,	main_symbol_n				:: !Int
	// pc specific
	,	base_va						:: !Int
	,	main_entry					:: !String
	// .edata
	,	edata_info					:: !EdataInfo
	,	exported_symbols			:: [ExportAddressEntryState]
	// .relocs
	,	relocs_info					:: *[*RelocBlock]
	// .rscr
	,	resource_file				:: !*File
	,	resource_size				:: !Int
	,	resource_delta				:: !Int
	,	image_symbol_table_info		:: !ImageSymbolTableInfo
	// temporary storage of data section 
	,	data						:: *{#Char}
	,	n_buffers					:: !Int
	,	data_buffers				:: !*{*{#Char}}
	};

:: ImageSymbolTableInfo = { n_symbols :: !Int, string_table_size :: !Int, symbol_table_offset :: !Int };

DefaultPlatformLinkOptions :: PlatformLinkOptions;
DefaultPlatformLinkOptions
	# link_options =  {
		open_console_window			= True,
		relocations_needed			= False,
		generate_symbol_table		= False,
		make_dll					= False,
		make_map_file				= False,
		make_resource				= False,
		resource_file_name			= "",
		c_stack_size				= 0
	  };
	= {	plo_lo = link_options
	
	// sections
	,	n_image_sections			= 0
	,	section_header_a			= {}
	,	any_extra_sections			= False
			
	// .idata
	,	idata_strings_size			= 0
	,	n_imported_symbols			= 0

	// general
	,	start_rva					= 0
	,	base_va						= 0x400000
	,	end_rva						= 0
	,	start_fp					= 0
	,	end_fp						= 0
	
	,	sections					= EndSections
	
	,	main_file_n					= 0
	,	main_symbol_n				= 0
	
	,	main_entry					= "_mainCRTStartup"
		
	// .edata
	,	edata_info					= EmptyEdataInfo
	,	exported_symbols			= []
		
	// .reloc
	,	relocs_info					= []	
		
	// .rscr
	,	resource_file				= stderr
	,	resource_size				= 0
	,	resource_delta				= 0
	
	,	image_symbol_table_info		= { n_symbols=0, string_table_size=0,symbol_table_offset=0 }

	// .text
	,	data						= {}
	,	n_buffers					= 1
	,	data_buffers				= {}
	};

plo_get_console_window :: !*PlatformLinkOptions -> (!Bool,!*PlatformLinkOptions);
plo_get_console_window platform_link_options=:{plo_lo={open_console_window}}
	= (open_console_window,platform_link_options);

plo_get_generate_symbol_table :: !*PlatformLinkOptions -> (!Bool,!*PlatformLinkOptions);
plo_get_generate_symbol_table platform_link_options=:{plo_lo={generate_symbol_table}}
	= (generate_symbol_table,platform_link_options);
	
use_overloaded_write_to_disk :== False;

create_buffers :: !*PlatformLinkOptions -> ({*{#Char}},!*{#Int},*PlatformLinkOptions);
create_buffers platform_link_options=:{n_buffers}
	#! buffers = { {} \\ i <- [1..n_buffers]};
	#! (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;

	// create user buffers		
	#! (buffers,section_header_a)
		= create_buffers_loop 0 section_header_a buffers;
		
	// create data buffer
	#! (_,_,data_section,section_header_a)
		= get_section_index 0 DataSectionHeader section_header_a;
	#! buffers = { buffers & [0] = createArray (sh_get_s_virtual_data data_section) ' '};
	// restore platform_link_options		
	#! platform_link_options = { platform_link_options & section_header_a = section_header_a };
	= (buffers,createArray n_buffers 0,platform_link_options);
	where {
		create_buffers_loop i section_header_a buffers
			#! (found,i,user_section_header,section_header_a)
				= get_section_index2 equal i (UserSectionHeader "" 0 0) section_header_a;
			| not found
				= (buffers,section_header_a);
				
				#! buffer_n = getBuffer user_section_header;
				#! buffers = { buffers & [buffer_n] = createArray (sh_get_s_virtual_data user_section_header) ' '};
				= create_buffers_loop (inc i) section_header_a buffers;
								
		equal (UserSectionHeader _ _ _) (UserSectionHeader _ _ _)	= True;
		equal _ _													= False;
		
		getBuffer :: SectionHeader -> Int;
		getBuffer user_section_header
			= case (sh_get_kind user_section_header) of {
				UserSectionHeader _ _ buffer_n
					-> buffer_n
			};
	} // create_buffers
	
post_process :: !*State !*PlatformLinkOptions !*Files -> (!Bool,[String],!*State,!*PlatformLinkOptions,!*Files);
post_process state=:{application_name} platform_link_options=:{plo_lo={make_map_file}} files
	// generate map file
	#! (state,files)
		= case make_map_file of {
			True
				-> generate_map_file state files;
			False
				-> (state,files);
		};	
	= (True,[],state,platform_link_options,files);

plo_set_gen_relocs :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_gen_relocs gen_relocs platform_link_options
	= { platform_link_options & plo_lo.relocations_needed = gen_relocs };

plo_set_generate_symbol_table :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_generate_symbol_table generate_symbol_table platform_link_options
	= {platform_link_options & plo_lo.generate_symbol_table = generate_symbol_table};

plo_set_gen_linkmap :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;	
plo_set_gen_linkmap gen_linkmap platform_link_options
	= { platform_link_options & plo_lo.make_map_file = gen_linkmap };

plo_set_gen_resource :: !Bool !String !*PlatformLinkOptions -> *PlatformLinkOptions;	
plo_set_gen_resource make_resource resource_file_name platform_link_options=:{plo_lo}
	# plo_lo & make_resource = make_resource, resource_file_name = resource_file_name
	= { platform_link_options & plo_lo = plo_lo };
	
plo_set_s_raw_data :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_s_raw_data s_raw_data i_section_header platform_link_options
	= appSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> {section_header_a & [i_section_header] = sh_set_s_raw_data s_raw_data section_header}) platform_link_options;

plo_set_fp_section :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_fp_section fp_section i_section_header platform_link_options
	= appSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> {section_header_a & [i_section_header] = sh_set_fp_section fp_section section_header}) platform_link_options;

plo_set_sections :: Sections !*PlatformLinkOptions  -> *PlatformLinkOptions;
plo_set_sections sections platform_link_options 
	= { platform_link_options & sections = sections };

plo_set_main_file_n_and_symbol_n :: !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_main_file_n_and_symbol_n main_file_n main_symbol_n platform_link_options
	= {platform_link_options &
		main_file_n		= main_file_n
	,	main_symbol_n	= main_symbol_n
	};
	
plo_any_extra_sections :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_any_extra_sections b platform_link_options
	= { platform_link_options & any_extra_sections = b };
	
plo_set_n_buffers :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_n_buffers n_buffers platform_link_options
	= { platform_link_options & n_buffers = n_buffers };
	
plo_get_n_buffers :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_n_buffers platform_link_options=:{n_buffers}
	= (n_buffers,platform_link_options);

plo_set_c_stack_size :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_c_stack_size c_stack_size platform_link_options
	= { platform_link_options & plo_lo.c_stack_size = c_stack_size };

plo_set_base_va :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_base_va base_va platform_link_options
	= { platform_link_options & base_va = base_va };

plo_set_make_dll :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_make_dll make_dll platform_link_options
	= { platform_link_options & plo_lo.make_dll = make_dll };

plo_set_exported_symbols :: [(String,String)] !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_exported_symbols exported_functions platform_link_options
	= { platform_link_options & exported_symbols = [ Entry { EmptyExportEntry &
							label_name		= public_name
						,	internal_name	= InternalName internal_name
						} \\ (public_name,internal_name) <- exported_functions] };
	
plo_set_main_entry :: !String !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_main_entry main_entry platform_link_options
	= { platform_link_options & main_entry = main_entry };

plo_set_image_symbol_table_info :: !Int !Int !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_image_symbol_table_info n_symbols string_table_size symbol_table_offset platform_link_options
	= { platform_link_options & image_symbol_table_info
		= {n_symbols=n_symbols, string_table_size=string_table_size, symbol_table_offset=symbol_table_offset} };

get_pdata_rva_and_size section_header_a
	# (_,_,pdata_section,section_header_a)
		= get_section_index 0 PDataSectionHeader section_header_a;
	#! {section_rva=pdata_rva} = sh_get_pd_section_header pdata_section;
	#! pdata_size = sh_get_s_virtual_data pdata_section;
	= (pdata_rva,pdata_size,section_header_a);

generate_start_prefix :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_start_prefix _ pe_file platform_link_options=:{plo_lo={c_stack_size,open_console_window,make_dll,relocations_needed,make_resource},end_rva,main_entry,base_va,end_fp,n_image_sections,image_symbol_table_info} state files
	# (pe_file,state,files,platform_link_options)
		= create_coff_fileN pe_file  state files platform_link_options;
	= (pe_file,platform_link_options,state,files);
where {
	create_coff_fileN pe_file state=:{application_name} files static_linker_state
		#! pe_file = write_ms_dos_stub pe_file;
		#! pe_file = write_pe_signature pe_file;		
		#! pe_file = write_coff_header make_dll pe_file;
						
		# (section_header_a,static_linker_state)
			= accSectionHeader_a (\section_header_a -> (section_header_a,{})) static_linker_state;
		#! (pe_file,state,section_header_a)
			= write_optional_header pe_file state section_header_a;

		#! (pe_file,section_header_a)
			= write_section_headers pe_file section_header_a;
	
		= (pe_file,state,files,{static_linker_state & section_header_a = section_header_a});
	where {
		write_ms_dos_stub pe_file
			#! executable_size
				= roundup_to_multiple end_fp 512;
		
			#! pe_file = pe_file
				FWS "MZ"
				FWW (executable_size rem 512)
				FWW (executable_size / 512)
				FWW 0
				FWW 4									// MZ-header / 16
				FWW 0
				FWW 0
				FWW 0
				FWW 0
				FWW 0
				FWW 0
				FWW 0
				FWW 0x40								// PE-header offset
				FWW 0
				FWW 0
				FWW 0;
			#! pe_file = pe_file
				FWB 0x0e								// push cs
				FWB 0x1f								// pop ds
				FWB 0xba FWB 0x0d FWB 0x00				// mov dx,offset msg$
				FWB 0xb4 FWB 0x09						// mov ah,9
				FWB 0xcd FWB 0x21						// int 21h				; write string
				FWB 0xb4 FWB 0x4c						// mov ah,4ch
				FWB 0xcd FWB 0x21						// int 21h				; exit
				FWS "Win32 required$"
				FWI 0x40								// PE-header offset
			= pe_file;
			
		write_pe_signature pe_file
			= pe_file FWI 0x00004550;

		write_coff_header make_dll pe_file
			# {n_symbols,string_table_size,symbol_table_offset} = image_symbol_table_info;
			#! pe_file = pe_file
				FWW (Link32or64bits IMAGE_FILE_MACHINE_I386 IMAGE_FILE_MACHINE_AMD64)
				FWW n_image_sections						// number of sections
				FWI 0										// timedata stamp
				FWI symbol_table_offset						// pointer to symboltable
				FWI	n_symbols								// number of entries in symboltable
				FWW	(Link32or64bits s_optional_header_32 s_optional_header_64) // optional header size
				FWW ( IMAGE_FILE_EXECUTABLE_IMAGE	bitor	// Characteristics
					 IMAGE_FILE_LINE_NUMS_STRIPPED	bitor
					 IMAGE_FILE_LOCAL_SYMS_STRIPPED bitor
					 (Link32or64bits IMAGE_FILE_32BIT_MACHINE IMAGE_FILE_LARGE_ADDRESS_AWARE) bitor
					 (if make_dll IMAGE_FILE_DLL 0) bitor
					 (if relocations_needed 0 IMAGE_FILE_RELOCS_STRIPPED));
			= pe_file;
		
		write_optional_header :: !*File !*State !*{!SectionHeader} -> (!*File,!*State,!*{!SectionHeader});	
		write_optional_header pe_file state section_header_a
			// Standard fields; write .text size in header
			# (_,_,text_section,section_header_a) = get_section_index 0 TextSectionHeader section_header_a;
			#! text_section_size_512 = sh_get_s_raw_data text_section;
	
			// write .data size in header
			# (_,_,data_section,section_header_a)
				= get_section_index 0 DataSectionHeader section_header_a;
			#! data_section_size_512
				= sh_get_s_raw_data data_section;
				
			// write .bss size in header
			# (_,_,bss_section,section_header_a)
				= get_section_index 0 BssSectionHeader section_header_a;
			#! bss_section_size_512
				= roundup_to_multiple (sh_get_s_virtual_data bss_section) (sh_get_alignment bss_section)
			#! pe_file = pe_file
				FWW (Link32or64bits 0x010b 0x020b)			// magic number; normal executable
				FWW 0										// linker version
				FWI text_section_size_512					// code size (.text)
				FWI data_section_size_512					// initialized data size (.data)
				FWI bss_section_size_512;					// uninitialized data size (.bss)
			// write the rva's of entrypoint, code and initialized data
			#! (ok,entry_point_va,state)
				= find_address_of_label main_entry state;
			| not ok
				= abort "create_coff_fileN: no main entry";
			#! entry_point_rva = entry_point_va - base_va;
			#! {section_rva=base_of_code_rva} = sh_get_pd_section_header text_section;			
			#! {section_rva=base_of_initialized_data_rva} = sh_get_pd_section_header data_section;
			#! pe_file = pe_file
				FWI entry_point_rva							// rva of entry point
				FWI base_of_code_rva;						// rva base of code (.text)
			#! pe_file = Link32or64bits
							(pe_file FWI
							 base_of_initialized_data_rva)	// rva base of initiliazed data (.data)
							pe_file;
			// Optional Header Windows NT-Specific Fields
			# (_,_,start_prefix,section_header_a)
				= get_section_index 0 StartPrefix section_header_a;
			#! start_prefix_size_512
				= sh_get_s_raw_data start_prefix;			
			#! image_size
				= roundup_to_multiple end_rva 4096;
			#! pe_file = pe_file	
				FWL base_va									// preferred address of 1st byte of image (64K multiple)
				FWI 4096									// section alignment (page size)
				FWI sh_get_alignment start_prefix			// file alignment (valid for all raw data)
				FWI 0x00000004								// Windows 4.0 required
				FWI 0x00000001								// executable version 1.0
				FWI 0x00000004								// subsystem 4.0
				FWI 0										// reserved
				FWI image_size								// size of image (multiple of Section Alignment)
				FWI start_prefix_size_512
				
				
				FWI	0										// image file checksum
				FWW (if open_console_window					// required subsystem
				   	IMAGE_SUBSYSTEM_WINDOWS_CUI
					IMAGE_SUBSYSTEM_WINDOWS_GUI)
	  			FWW 0										// obsolete
				FWL c_stack_size							// stack reserve size
				FWL 0x1000									// stack commit size
				FWL 0x100000								// heap reserve size
				FWL	0x1000									// heap commit size
				FWI 0 										// obsolete
				FWI n_data_directories;						// number of data directories
					
			// Optional Header Data Directories (rva,size); determine tuple for .idata
			# (_,_,idata_section,section_header_a)
				= get_section_index 0 IDataSectionHeader section_header_a;
			
			#! {section_rva=idata_rva} = sh_get_pd_section_header idata_section;
			#! idata_size = sh_get_s_virtual_data idata_section; 
				
			// determine tuple for .edata
			#! (edata_rva,edata_size,section_header_a)
				= case make_dll of {
					True
						#! (_,_,edata_section,section_header_a)
							= get_section_index 0 EDataSectionHeader section_header_a;
						#! {section_rva=edata_rva} = sh_get_pd_section_header edata_section;		
						#! edata_size = sh_get_s_virtual_data edata_section;
						-> (edata_rva,edata_size,section_header_a);
					False
						-> (0,0,section_header_a);
				};
			
			# (pdata_rva,pdata_size,section_header_a)
				= Link32or64bits
					(0,0,section_header_a)
					(get_pdata_rva_and_size section_header_a);

			// determine tuple for .reloc
			#! (reloc_rva,reloc_size,section_header_a)
				= case relocations_needed of {
					True
						#! (_,_,reloc_section,section_header_a)
							= get_section_index 0 RelocSectionHeader section_header_a;
						#! {section_rva=reloc_rva} = sh_get_pd_section_header reloc_section;
						#! reloc_size = sh_get_s_virtual_data reloc_section;
						-> (reloc_rva,reloc_size,section_header_a);
					False
						-> (0,0,section_header_a);
				};
				
			// determine tuple for .rscr
			#! (resource_rva,resource_size,section_header_a)
				= case make_resource of {
					True
						#! (_,_,resource_section,section_header_a)
							= get_section_index 0 ResourceSectionHeader section_header_a;
						#! {section_rva=resource_rva}
							= sh_get_pd_section_header resource_section;
						#! resource_size
							= sh_get_s_raw_data resource_section;
						-> (resource_rva,resource_size,section_header_a);
					False
						-> (0,0,section_header_a);
				};
				
			#! pe_file = pe_file
				FWI edata_rva								// Export Table										 
				FWI edata_size 
				FWI idata_rva								// Import Table 
				FWI idata_size 
				FWI resource_rva							// Resource Table
				FWI resource_size
				FWI pdata_rva								// Exception Table
				FWI pdata_size
				FWI 0										// Security Table 
				FWI 0 
				FWI reloc_rva								// Base Relocation Table 
				FWI reloc_size 
				FWI 0										// Debug 
				FWI 0 
				FWI 0										// Copyright
				FWI 0
				FWI 0										// Global Ptr 
				FWI 0 
				FWI 0										// TLS Table
				FWI 0 
				FWI 0										// Load Config Table 
				FWI 0 
				FWI 0										//  Reserved 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0 
				FWI 0;
			= (pe_file,state,section_header_a);
		
		write_section_headers :: !*File !*{!SectionHeader} -> (!*File,!*{!SectionHeader});
		write_section_headers pe_file section_header_a
			# (s_section_header_a,section_header_a)
				= usize section_header_a;
			= foldl write (pe_file,section_header_a) [0..dec s_section_header_a];
		where {
			write (pe_file,section_header_a) i
				# (section_header=:{section_name,section_rva,section_flags},section_header_a)
					= section_header_a![i];
				| (sh_get_kind section_header) == StartPrefix
					= (pe_file,section_header_a);

					#! {section_name,section_rva,section_flags}
						= sh_get_pd_section_header section_header;
					// create section
					#! pad_zero_bytes
						= createArray s_section_name '\0';
					#! padded_section_name
						= (section_name +++ pad_zero_bytes) % (0,dec s_section_name);

					#! pe_file = pe_file
						FWS padded_section_name							// section name
						FWI	sh_get_s_virtual_data section_header		// virtual section size
						FWI section_rva									// rva of section

						FWI sh_get_s_raw_data section_header			// raw data size (multiple of File Align)
						FWI sh_get_fp_section section_header			// raw data (file) pointer
						FWI 0											// pointer to relocations 
						FWI 0											// pointer to linenumbers
						FWW 0											// number of relocations 
						FWW 0											// number of linenumbers 
						FWI section_flags								// section flags
					= (pe_file,section_header_a);	
		}
	}
}

instance Target2 (!*{#Char},!*File)
where {
 	WriteOutput {file_or_memory=write_kind,offset,aligned_offset,string,state} (data,pe_file)
		#! (data,pe_file)
			= case write_kind of {
				0
					// .text
					#! delta = aligned_offset - offset;
					#! pe_file = write_n_bytes delta pe_file;
					#! pe_file = fwrites string pe_file;	 
					-> (data,pe_file);
				1
					// .data
					#! data = copy 0 string aligned_offset data;
					-> (data,pe_file);
			};
		= (state,(data,pe_file));
	where {
		copy :: !Int !{#Char} !Int !*{#Char} -> *{#Char};
		copy i s j d
			| i == size s
				= d;
				= copy (inc i) s (inc j) {d & [j + 0] = s.[i]};
			
		write_n_bytes :: !Int !*File -> *File;
		write_n_bytes 0 pe_file
			= pe_file;
		write_n_bytes n pe_file
			= write_n_bytes (dec n) (fwritec '\0' pe_file);
	}
};

compute_jump_table_va base_va n_imported_symbols section_header_a
	#! (_,_,text_section,section_header_a)
		= get_section_index 0 TextSectionHeader section_header_a;
	#! {section_rva=text_section_rva} = sh_get_pd_section_header text_section;
	#! text_s_virtual_data = sh_get_s_virtual_data text_section;
	#! jump_table_va = base_va + text_section_rva + text_s_virtual_data - (n_imported_symbols * 6);
	= (jump_table_va,section_header_a);

generate_text_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_text_section_header _ pe_file platform_link_options=:{base_va,n_imported_symbols} state=:{n_xcoff_files,n_libraries,library_list} files
	#! nop_byte = toChar 0x90;
	
	# (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;
	#! (_,_,data_section,section_header_a)
		= get_section_index 0 DataSectionHeader section_header_a;
	#! s_virtual_data_section = sh_get_s_virtual_data data_section;
			
	# (data,pe_file,state,files,platform_link_options,section_header_a)
		= case use_overloaded_write_to_disk of {
			True
				#! (((data,pe_file),_,state),files)
					= write_code_to_pe_files n_xcoff_files True 0 0 (0,0) state False (createArray s_virtual_data_section nop_byte,pe_file) files;
				-> (data,pe_file,state,files,platform_link_options,section_header_a);
			False
				#! platform_link_options = { platform_link_options & section_header_a = section_header_a };
				#! (pe_file,platform_link_options,state,files,ws)
					= WriteCode pe_file platform_link_options state files;
				#! (buffers,ws) = sel_buffers ws;
				#! platform_link_options = { platform_link_options & data_buffers = buffers };
				
				#! (section_header_a,platform_link_options)
					= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;
				-> ({},pe_file,state,files,platform_link_options,section_header_a);
		};

	// write DLL call's
	# (_,_,idata_section,section_header_a)
		= get_section_index 0 IDataSectionHeader section_header_a;
	# {section_rva=idata_section_rva} = sh_get_pd_section_header idata_section;
	#! thunk_data_va = base_va + idata_section_rva + 20 * (inc n_libraries);

	# (jump_table_va,section_header_a)
		= Link32or64bits
			(0,section_header_a)
			(compute_jump_table_va base_va n_imported_symbols section_header_a);

	// direct jumps are redirected to *indirect* jumps in the jumptable. The jumptable contains indirect jumps
	// via the thunktable which is filled in by the loader with the proper addresses.
	#! pe_file = Link32or64bits
					(write_imported_library_functions_code_32 library_list thunk_data_va pe_file)
					(write_imported_library_functions_code_64 library_list thunk_data_va jump_table_va pe_file);
	// platfrom_link_options
	# platform_link_options = { platform_link_options & section_header_a = section_header_a, data = data };
		
	= (pe_file,platform_link_options,state,files);
where {
	sel_buffers ws=:{buffers}
		= (buffers,{ws & buffers = {}});
};

generate_data_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_data_section_header _ pe_file platform_link_options=:{data} state=:{n_xcoff_files,n_libraries,library_list} files
	// assumption: .text precedes .data
	#! (data,platform_link_options)
		= case use_overloaded_write_to_disk of {
			True
				-> sel_data2 platform_link_options;
			False
				-> sel_data platform_link_options;
		};
	#! pe_file
		= fwrites data pe_file;
	= (pe_file,platform_link_options ,state,files);
where {
	sel_data platform_link_options=:{data_buffers}
		#! (data,data_buffers)
			= replace data_buffers 0 {};
		= (data,{ platform_link_options & data_buffers = data_buffers});
		
	sel_data2 platform_link_options=:{data}
		= (data,{ platform_link_options & data = {} });
}

generate_bss_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_bss_section_header _ pe_file platform_link_options state files
	= (pe_file,platform_link_options,state,files);

generate_idata_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_idata_section_header _ pe_file platform_link_options=:{n_imported_symbols} state=:{n_libraries,library_list} files
	# (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;
	# (_,_,idata_section,section_header_a)
		= get_section_index 0 IDataSectionHeader section_header_a;
	# {section_rva=idata_rva} = sh_get_pd_section_header idata_section;
	#! pe_file = write_idata library_list n_libraries n_imported_symbols idata_rva pe_file;
	= (pe_file,{platform_link_options & section_header_a = section_header_a},state,files);

generate_pdata_section :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_pdata_section _ pe_file platform_link_options=:{section_header_a,base_va} state files
	# (_,_,text_section,section_header_a) = get_section_index 0 TextSectionHeader section_header_a;
	# {section_rva=text_section_rva} = sh_get_pd_section_header text_section;
	# text_s_virtual_data = sh_get_s_virtual_data text_section;

	# (ok,clean_unwind_info_va,state)
		= find_address_of_label "clean_unwind_info" state;
	| not ok
		= abort "generate_pdata_section: clean_unwind_info label not defined";

	# pe_file = pe_file FWI text_section_rva FWI (text_section_rva+text_s_virtual_data-1) FWI (clean_unwind_info_va-base_va);
	= (pe_file,{platform_link_options & section_header_a = section_header_a},state,files);

generate_edata_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_edata_section_header _ pe_file platform_link_options state files
	#! (edata_info,platform_link_options)
		= platform_link_options!edata_info;
	#! (pe_file,state)
		= write_edata_section edata_info pe_file state;
	= (pe_file,platform_link_options,state,files);

generate_reloc_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_reloc_section_header _ pe_file platform_link_options state files
	#! (relocs_info,platform_link_options)
		= y platform_link_options;
	#! pe_file
		= write_reloc_section pe_file relocs_info;
	= (pe_file,platform_link_options,state,files);
where {
	y platform_link_options=:{relocs_info}
		= (relocs_info,{platform_link_options & relocs_info = []});
}

apply_generate_section :: !Int *File !*PlatformLinkOptions !*State !*Files -> (!Bool,!Int,!Int,!*File,!*PlatformLinkOptions,!*State,!*Files);
apply_generate_section i pe_file platform_link_options state files
	#! (generate_section,platform_link_options)
		= get_generate_section i platform_link_options;

	// unpack section_header
	#! (section_header,platform_link_options)
		= accSectionHeader_a (\section_header_a=:{[i] = section_header} -> (section_header,section_header_a)) platform_link_options
	#! (pe_file,platform_link_options,state,files)
		= generate_section section_header pe_file platform_link_options state files;		
		
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
	# (compute_section,platform_link_options=:{end_fp})
		= accSectionHeader_a (\section_header_a=:{[section_header_i] = section_header} -> (sh_get_compute_section section_header,section_header_a)) platform_link_options;
	= (compute_section,platform_link_options);
	
accSectionHeader_a :: !.(*{!SectionHeader} -> (.x,*{!SectionHeader})) !*PlatformLinkOptions -> (!.x,PlatformLinkOptions);
accSectionHeader_a f platform_link_options=:{section_header_a} 
 	# (x,section_header_a) = f section_header_a;
	= (x,{ platform_link_options & section_header_a = section_header_a } );
	
getSectionHeader_a :: !*PlatformLinkOptions -> (!*{!SectionHeader},PlatformLinkOptions);
getSectionHeader_a platform_link_options=:{section_header_a} 
	= (section_header_a,{ platform_link_options & section_header_a = {} } );
	
appSectionHeader_a :: !.(*{!SectionHeader} -> *{!SectionHeader}) !*PlatformLinkOptions -> *PlatformLinkOptions;
appSectionHeader_a f platform_link_options=:{section_header_a}
	# (ss,section_header_a) = usize section_header_a;
	=  { platform_link_options & section_header_a = f section_header_a };
	
// Accessors; sets
plo_set_console_window :: !Bool !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_console_window ocw platform_link_options
	= { platform_link_options & plo_lo.open_console_window = ocw };

plo_set_end_rva :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_end_rva end_rva platform_link_options
	= { platform_link_options & end_rva = end_rva };

plo_set_end_fp  :: !Int !*PlatformLinkOptions -> *PlatformLinkOptions;
plo_set_end_fp end_fp platform_link_options
	= { platform_link_options & end_fp = end_fp };

// Accessors; gets
plo_get_base_va :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_base_va platform_link_options
	= platform_link_options!base_va;

plo_get_text_data_bss_va :: !*PlatformLinkOptions -> (!Int,!Int,!Int,!*PlatformLinkOptions);
plo_get_text_data_bss_va platform_link_options=:{base_va,section_header_a}
	# (text_rva,data_rva,vss_rva,section_header_a) = get_text_data_bss_rva section_header_a;
	  platform_link_options & section_header_a=section_header_a
	= (base_va+text_rva,base_va+data_rva,base_va+vss_rva,platform_link_options);
{
	get_text_data_bss_rva section_header_a
		# (text_rva,section_header_a) = get_section_rva TextSectionHeader section_header_a;
		  (data_rva,section_header_a) = get_section_rva DataSectionHeader section_header_a;
		  (bss_rva,section_header_a) = get_section_rva BssSectionHeader section_header_a;
		= (text_rva,data_rva,bss_rva,section_header_a);

	get_section_rva section_header_kind section_header_a
		# (_,_,text_section_header,section_header_a) = get_section_index 0 section_header_kind section_header_a;
		#! section_rva = (sh_get_pd_section_header text_section_header).section_rva;
		= (section_rva,section_header_a);
}

plo_get_start_fp :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_start_fp platform_link_options=:{start_fp}
	= (start_fp,platform_link_options);
	
plo_get_start_rva :: !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_start_rva platform_link_options=:{start_rva}
	= (start_rva,platform_link_options);

plo_get_section_fp :: !Int !*PlatformLinkOptions -> (!Int,!*PlatformLinkOptions);
plo_get_section_fp i_section_header platform_link_options
	= accSectionHeader_a (\section_header_a=:{[i_section_header] = section_header} -> 
	(sh_get_fp_section section_header,section_header_a)) platform_link_options;
	
// Extra sections
:: ExtraSections
	= RelocSection !Bool
	| ExportSection !Bool
	| ResourceSection !Bool
	| UserSection !String !Int !Int	// section_name section_flags buffer_n
	;

look_for_user_sections :: !*State !*PlatformLinkOptions -> ([ExtraSections],!*State,!*PlatformLinkOptions);
look_for_user_sections state platform_link_options=:{any_extra_sections=False}
	= ([],state,platform_link_options);
look_for_user_sections state=:{n_xcoff_files} platform_link_options
	#! (buffer_n,extra_sections_db,state)
		= look_for_user_sections_loop 0 n_xcoff_files 1 /* 0 for data buffer */ state [];
	#! platform_link_options
		= { platform_link_options &
			n_buffers	= buffer_n
		};
	= ([ e_s_db \\ (_,e_s_db) <- extra_sections_db],state,platform_link_options);
where {
	look_for_user_sections_loop i limit buffer_n state extra_sections_db
		| i == limit
			= (buffer_n,extra_sections_db,state);
			
		# (extra_sections,state)
			= state!xcoff_a.[i].symbol_table.extra_sections;
		#! (buffer_n,extra_sections_db,state)
			= case (isEmpty extra_sections) of {
				True
					-> (buffer_n,extra_sections_db,state);
				_
					# (buffer_n,extra_sections_db,state,modified_extra_sections)
						= add_non_duplicate_sections extra_sections extra_sections_db buffer_n state [];
					# state
						= { state & xcoff_a.[i].symbol_table.extra_sections = modified_extra_sections};

					-> (buffer_n,extra_sections_db,state);
			};
		#! (ok,state)
			= IsErrorOccured state;
		| not ok
			= (buffer_n,extra_sections_db,state);
		
		= look_for_user_sections_loop (inc i) limit buffer_n state extra_sections_db ;
	where {	
		add_non_duplicate_sections [] extra_sections_db buffer_n state modified_extra_sections
			= (buffer_n,extra_sections_db,state,modified_extra_sections);

		add_non_duplicate_sections [es=:{es_name,es_flags}:ess] extra_sections_db buffer_n state modified_extra_sections
			#! e_s_dbs
				= filter (\(_,UserSection s _ _) -> es_name == s) extra_sections_db
			| not (isEmpty e_s_dbs)
				#! flags
					= getFlags (hd e_s_dbs);
				| flags == es_flags
					// name already existed hence its buffer also
					#! modified_extra_sections
						= [{es & es_buffer_n = getBuffer (hd e_s_dbs)}:modified_extra_sections];
					= add_non_duplicate_sections ess extra_sections_db buffer_n state modified_extra_sections;
	
					#! msg
						= "User defined section \"" +++ es_name +++ "\" has been defined with different flags";
					#! state
						= AddMessage (LinkerError msg) state;
					=  (buffer_n,extra_sections_db,state,modified_extra_sections);
				
				// es_name did not exist; allocate a buffer_n for it
				#! modified_extra_sections
					= [{es & es_buffer_n = buffer_n}:modified_extra_sections];
				= add_non_duplicate_sections ess [(buffer_n,UserSection es_name es_flags buffer_n):extra_sections_db] (inc buffer_n) state modified_extra_sections;
					
		where {
			getFlags (_,UserSection s f _)
				= f;
			getBuffer (buffer_n,_)
				= buffer_n;
		};
	}; // look_for_user_sections_loop
};	
		
create_section_header_kinds :: !*State !*PlatformLinkOptions -> (!Int,!*State,!*PlatformLinkOptions);
create_section_header_kinds state platform_link_options=:{any_extra_sections,plo_lo={relocations_needed,make_dll,make_resource}}
	# (user_sections,state,platform_link_options)
		= look_for_user_sections state platform_link_options;
	#! (ok,state)
		= IsErrorOccured state;
	| not ok
		= (0,state,platform_link_options);
		
	# s_section_header_a
		= n_standard_sections 
			+ (if relocations_needed 1 0) 
			+ (if make_dll 1 0)
			+ (if make_resource 1 0)
			+ (if any_extra_sections (length user_sections) 0)
			;
	
	# section_header_a
		= standard_section_header 0 s_section_header_a (createArray s_section_header_a DefaultSectionHeader) 
		([RelocSection relocations_needed,ExportSection make_dll,ResourceSection make_resource] ++ (if any_extra_sections user_sections []));
	# platform_link_options 
		= { platform_link_options &
			section_header_a		= section_header_a
		,	n_image_sections		= dec s_section_header_a 
		};
	= (s_section_header_a,state,platform_link_options); 
	
where {
	fp_alignment 
		= 512;
		
	// standard sections
	n_standard_sections 
		= Link32or64bits 5 6;
		
	standard_section_header i=:0 limit section_header_a extra_sections
		# dsh = DefaultSectionHeader
			DSH sh_set_kind StartPrefix
			DSH sh_set_index i
			DSH sh_set_alignment fp_alignment
			DSH sh_set_compute_section compute_start_prefix
			DSH sh_set_generate_section generate_start_prefix;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh } extra_sections;

	standard_section_header i=:1 limit section_header_a extra_sections
		# dsh = DefaultSectionHeader
			DSH sh_set_kind TextSectionHeader
			DSH	sh_set_index i
			DSH sh_set_alignment fp_alignment
			DSH sh_set_compute_section compute_text_section_header
			DSH sh_set_generate_section generate_text_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh } extra_sections;
		
	standard_section_header i=:2 limit section_header_a extra_sections
		# dsh = DefaultSectionHeader
			DSH sh_set_kind DataSectionHeader
			DSH	sh_set_index i
			DSH sh_set_alignment fp_alignment
			DSH sh_set_compute_section compute_data_section_header
			DSH sh_set_generate_section generate_data_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh } extra_sections;
		
	standard_section_header i=:3 limit section_header_a extra_sections
		# dsh = DefaultSectionHeader
			DSH sh_set_kind BssSectionHeader
			DSH	sh_set_index i
			DSH sh_set_is_virtual_section True
			DSH sh_set_alignment fp_alignment
			DSH sh_set_compute_section compute_bss_section_header
			DSH sh_set_generate_section generate_bss_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh } extra_sections;
		
	standard_section_header i=:4 limit section_header_a extra_sections
		# dsh = DefaultSectionHeader
			DSH sh_set_kind IDataSectionHeader
			DSH	sh_set_index i
			DSH sh_set_alignment fp_alignment
			DSH sh_set_compute_section compute_idata_section_header
			DSH sh_set_generate_section generate_idata_section_header
			;
		= standard_section_header (inc i) limit { section_header_a & [i] = dsh} extra_sections;
		
	standard_section_header i=:5 limit section_header_a extra_sections
		| Link32or64bits False True
			# dsh = DefaultSectionHeader
				DSH sh_set_kind PDataSectionHeader
				DSH	sh_set_index i
				DSH sh_set_alignment fp_alignment
				DSH sh_set_compute_section compute_pdata_section_header
				DSH sh_set_generate_section generate_pdata_section
				;
			= standard_section_header (inc i) limit { section_header_a & [i] = dsh} extra_sections;

	standard_section_header i limit section_header_a []
		= section_header_a;
	standard_section_header i limit section_header_a [extra_section:extra_sections]
		# (is_new_section_added,dsh) 
			= case extra_section of {
				RelocSection True
					# dsh = DefaultSectionHeader
						DSH sh_set_kind RelocSectionHeader
						DSH	sh_set_index i
						DSH sh_set_alignment fp_alignment
						DSH sh_set_compute_section compute_reloc_section_header
						DSH sh_set_generate_section generate_reloc_section_header
						;
					-> (True,dsh);
				ExportSection True
					# dsh = DefaultSectionHeader
						DSH sh_set_kind EDataSectionHeader
						DSH	sh_set_index i
						DSH sh_set_alignment fp_alignment
						DSH sh_set_compute_section compute_edata_section_header
						DSH sh_set_generate_section generate_edata_section_header
						;
					-> (True,dsh);
				ResourceSection True
					# dsh = DefaultSectionHeader
						DSH sh_set_kind ResourceSectionHeader
						DSH	sh_set_index i
						DSH sh_set_alignment fp_alignment
						DSH sh_set_compute_section compute_resource_section_header
						DSH sh_set_generate_section generate_resource_section_header
						;
					-> (True,dsh);				
				(UserSection section_name flags buffer_n)
					# dsh = DefaultSectionHeader
						DSH sh_set_kind (UserSectionHeader section_name flags buffer_n)
						DSH	sh_set_index i
						DSH sh_set_alignment fp_alignment
						DSH sh_set_compute_section compute_user_section_header
						DSH sh_set_generate_section generate_user_section_header
						;
					-> (True,dsh);
					
				_
					-> (False,undef);
				};
		| is_new_section_added
			= standard_section_header (inc i) limit { section_header_a & [i] = dsh} extra_sections;
			
			= standard_section_header i limit section_header_a extra_sections;
}

find_root_symbols :: *{!NamesTableElement} !*PlatformLinkOptions -> *(.Bool,Int,Int,.Bool,[(.Bool,{#Char},Int,Int)],*{!NamesTableElement},*PlatformLinkOptions);
find_root_symbols names_table platform_link_options=:{main_entry,exported_symbols}
	// find root symbols which are main entry and any exported symbols
	# (main_entry_names_table_element,names_table)
		= find_symbol_in_symbol_table main_entry names_table; 

	# (all_exported_symbols_found,entry_datas,exported_symbols,names_table)
		= find_exported_symbols exported_symbols [] /*exported_symbols*/ [] names_table True;

	// collect results
	# (main_entry_found,main_file_n,main_symbol_n)
		= has_main_entry_been_found main_entry_names_table_element;		
	# platform_link_options = { platform_link_options & exported_symbols = exported_symbols };
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

// COMPUTE
compute_start_prefix :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_start_prefix start_rva fp i_start_prefix_section_header start_prefix state=:{marked_bool_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_image_sections,n_imported_symbols,idata_strings_size,base_va} files
	// .idata section
	#! (marked_bool_a,idata_strings_size,n_imported_symbols)
		= compute_idata_strings_size library_list 0 0 n_xcoff_symbols marked_bool_a;
		
	// .edata
	#! edata_info = { EmptyEdataInfo & exported_entries = exported_symbols };
		
	#! platform_link_options
		= { platform_link_options &
			idata_strings_size	= idata_strings_size,
			n_imported_symbols	= n_imported_symbols,
			start_rva			= start_rva,
			start_fp			= fp,
			edata_info			= edata_info
		};
		
	#! start_prefix_size
		= s_ms_dos_header + s_pe_header + s_xcoff_header + (Link32or64bits s_optional_header_32 s_optional_header_64) + (s_section_table_entry * n_image_sections);

	#! start_prefix = sh_set_virtual_data start_prefix_size start_prefix;
	#! state = { state & marked_bool_a = marked_bool_a, module_offset_a = createArray (n_xcoff_symbols+n_library_symbols) 0 };
	= (i_start_prefix_section_header,start_prefix,state,platform_link_options,files);


compute_text_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_text_section_header start_rva fp i_text_section_header text_section_header state=:{marked_bool_a,module_offset_a,xcoff_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	#! xcoff_list = xcoff_array_to_list 0 xcoff_a;
	
	// body
	#! start_va = base_va + start_rva;
	#! (marked_bool_a,text_end_va,module_offset_a, xcoff_list)
		= compute_module_offsets Text 0 xcoff_list start_va 0 marked_bool_a module_offset_a;
	#! text_end_va = text_end_va + 6 * n_imported_symbols;

	// update section header
	#! pd_section_header = {
			section_name				= ".text"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_CODE bitor
								 		  IMAGE_SCN_MEM_EXECUTE bitor
	 							 		  IMAGE_SCN_MEM_READ
		};

	#! text_section_header = text_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data (text_end_va - start_va);
	
	// to be removed:
	#! state = { state & marked_bool_a = marked_bool_a,
						 module_offset_a = module_offset_a,
						 xcoff_a = xcoff_list_to_xcoff_array xcoff_list state.n_xcoff_files
		};
	= (i_text_section_header,text_section_header,state,platform_link_options,files);

compute_data_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_data_section_header start_rva fp i_data_section_header data_section_header state=:{xcoff_a,marked_bool_a,module_offset_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	#! xcoff_list 
		= xcoff_array_to_list 0 xcoff_a;

	// body
	#! start_va
		= base_va + start_rva;
	#! (marked_bool_a,data_end_va,module_offset_a, xcoff_list)
		= compute_module_offsets Data 0 xcoff_list start_va 0 marked_bool_a module_offset_a;

	// update section header
	#! pd_section_header = {
			section_name				= ".data"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_INITIALIZED_DATA bitor
	 									  IMAGE_SCN_MEM_READ bitor
	 							 		  IMAGE_SCN_MEM_WRITE
		};

	#! data_section_header = data_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data (data_end_va - start_va);

	#! state
		= { state &
			marked_bool_a = marked_bool_a,
			module_offset_a = module_offset_a,
			xcoff_a = xcoff_list_to_xcoff_array xcoff_list state.n_xcoff_files
		};
	= (i_data_section_header,data_section_header,state,platform_link_options,files);

compute_bss_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_bss_section_header start_rva fp i_bss_section_header bss_section_header state=:{xcoff_a,marked_bool_a,module_offset_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	#! xcoff_list 
		= xcoff_array_to_list 0 xcoff_a;

	// body
	#! start_va
		= base_va + start_rva;
	#! (marked_bool_a,bss_end_va,module_offset_a, xcoff_list)
		= compute_module_offsets Bss 0 xcoff_list start_va 0 marked_bool_a module_offset_a;
		
	// update section header
	#! pd_section_header = {
			section_name				= ".bss"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_UNINITIALIZED_DATA bitor
	 							 		  IMAGE_SCN_MEM_READ bitor
	 									  IMAGE_SCN_MEM_WRITE
		};
		
	#! bss_section_header = bss_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data (bss_end_va - start_va);

	#! state
		= { state &
			marked_bool_a = marked_bool_a,
			module_offset_a = module_offset_a,
			xcoff_a = xcoff_list_to_xcoff_array xcoff_list state.n_xcoff_files
		};
	= (i_bss_section_header,bss_section_header,state,platform_link_options,files);

compute_idata_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_idata_section_header start_rva fp i_idata_section_header idata_section_header state=:{marked_bool_a,module_offset_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	#! start_va = base_va + start_rva;
		
	// .text section *must* precede .idata
	# (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;
	#! (_,_,text_section,section_header_a)
		= get_section_index 0 TextSectionHeader section_header_a;
	#! {section_rva=text_section_rva} = sh_get_pd_section_header text_section;
	#! text_s_virtual_data = sh_get_s_virtual_data text_section;
		
	#! jump_table_va = base_va + text_section_rva + text_s_virtual_data - (n_imported_symbols * 6); 		
	#! thunk_data_va = start_va + 20 * (inc n_libraries);
	#! (marked_bool_a,library_list,_,_,module_offset_a)
		= compute_imported_library_symbol_offsets library_list jump_table_va thunk_data_va (~n_libraries) n_xcoff_symbols marked_bool_a module_offset_a;
	
	// update section header
	#! pd_section_header = {
			section_name				= ".idata"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_INITIALIZED_DATA bitor
										  IMAGE_SCN_MEM_READ bitor
	 									  IMAGE_SCN_MEM_WRITE
		};
	#! idata_section_header = idata_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data ((inc n_libraries) * 20 +
								 ((n_imported_symbols + n_libraries) << (Link32or64bits 2 3)) + idata_strings_size);

	// to be removed
	#! state = { state & library_list = library_list, marked_bool_a = marked_bool_a, module_offset_a = module_offset_a };
	= (i_idata_section_header,idata_section_header,state,{platform_link_options & section_header_a = section_header_a},files);

compute_pdata_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_pdata_section_header start_rva fp i_pdata_section_header pdata_section_header state platform_link_options=:{base_va} files
	# start_va = base_va + start_rva;
	# pd_section_header = {
			section_name	= ".pdata"
		,	section_rva		= start_rva
		,	section_flags	= IMAGE_SCN_CNT_INITIALIZED_DATA bitor IMAGE_SCN_MEM_READ
		};
	# pdata_section_header = pdata_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data 12;
	= (i_pdata_section_header,pdata_section_header,state,platform_link_options,files);

compute_reloc_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_reloc_section_header start_rva fp i_reloc_section_header reloc_section_header state=:{n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	# (section_header_a,platform_link_options)
		= accSectionHeader_a (\section_header_a -> (section_header_a,{})) platform_link_options;
	#! (reloc_section_header,relocs_l,section_header_a,state)
		= compute_relocs_section i_reloc_section_header start_rva base_va n_imported_symbols reloc_section_header section_header_a state;
	#! platform_link_options = { platform_link_options & relocs_info = relocs_l };
 	= (i_reloc_section_header,reloc_section_header,state,{platform_link_options & section_header_a = section_header_a},files);

compute_edata_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files-> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_edata_section_header start_rva fp i_edata_section_header edata_section_header state=:{n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{base_va,edata_info} files
	#! (_,edata_section_header,edata_info,state)
		= compute_edata_section i_edata_section_header edata_section_header base_va start_rva edata_info state;
	#! platform_link_options = { platform_link_options & edata_info = edata_info };
	= (i_edata_section_header,edata_section_header,state,platform_link_options,files);
	
compute_resource_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_resource_section_header start_rva fp i_resource_section_header resource_section_header state platform_link_options=:{plo_lo={resource_file_name}} files
	// find resource; open resource file
	#! (ok,resource_file,files)
		= fopen resource_file_name FReadData files;
	| not ok 
		#! msg = "could not open resource file" +++ resource_file_name;
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));
	
	// find and check PE signature
	#! (ok,resource_file) 
		= fseek resource_file FP_PE_HEADER FSeekSet; 
	| not ok
		#! msg = "resource '" +++ resource_file_name +++ "' is corrupt; could not locate PE signature" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));

	#! (ok,fp_pe_signature,resource_file)
		= freadi resource_file;
	| not ok
		#! msg = "resource '" +++ resource_file_name +++ "' is corrupt; could not seek to PE signature" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));
	#! (ok,resource_file) 
		= fseek resource_file fp_pe_signature FSeekSet; 
	| not ok
		#! msg = "resource '" +++ resource_file_name +++ "' is corrupt; could not locate PE signature" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));
	#! (ok,pe_signature,resource_file)
		= freadi resource_file;
	| pe_signature <> PE_HEADER
		#! msg = "file '" +++ resource_file_name +++ "' is not a resource" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));

	// read xcoff header
	#! (ok,n_sections,_,_,resource_file)
		= read_coff_header resource_file;
	| not ok 
		#! msg = "resource '" +++ resource_file_name +++ "' is corrupt; could not read xcoff header" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));
	
	// search resource section
	#! (ok,resource_rva,s_raw_data,resource_file)
		= search_resource_section 0 n_sections resource_file;
	| not ok
		#! msg = "resource '" +++ resource_file_name +++ "' is corrupt; error scanning through section headers" 
	 	= (i_resource_section_header,resource_section_header,AddMessage (LinkerError msg) state,platform_link_options,snd (fclose resource_file files));
		
	// update platform_link_options
	#! platform_link_options
		= { platform_link_options &
			resource_file	= resource_file
		,	resource_size	= s_raw_data
		,	resource_delta	= start_rva - resource_rva
		};
		
	// update section header
	#! pd_section_header = {
			section_name				= ".rsrc"
		,	section_rva					= start_rva
		,	section_flags				= IMAGE_SCN_CNT_INITIALIZED_DATA bitor
										  IMAGE_SCN_MEM_READ bitor
	 									  IMAGE_SCN_MEM_WRITE
		};
	#! resource_section_header = resource_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data 0
		DSH	sh_set_s_raw_data s_raw_data
		;
	= (i_resource_section_header,resource_section_header,state,platform_link_options,files);
where {
	search_resource_section section_n n_sections resource_file
		| section_n == n_sections
			= (False,0,0,resource_file);

			#! (section_name,resource_file)
				= freads resource_file s_section_name;
			| fst (starts ".rsrc\0" section_name)
				// skip virtual size and rva/offset
				#! (ok,_,resource_file)
					= freadi resource_file;
				| not ok
					= (False,0,0,resource_file);

				// read section rva, raw data size and position fp to resource start
				#! (ok0,section_rva,resource_file)
					= freadi resource_file;
				#! (ok1,s_raw_data,resource_file)
					= freadi resource_file;
				#! (ok2,fp_raw_data,resource_file)
					= freadi resource_file;
				| not ok0 || not ok1 || not ok2
					= (False,0,0,resource_file);
					
				#! (ok,resource_file) 
					= fseek resource_file fp_raw_data FSeekSet;
				= (ok,section_rva,s_raw_data,resource_file)
	
			#! (ok,resource_file) 
				= fseek resource_file s_section_without_name FSeekCur;
			| not ok
				= (False,0,0,resource_file);
			= search_resource_section (inc section_n) n_sections resource_file
	where {
		s_section_without_name = s_section_table_entry - s_section_name
	}
}	

get_resource_file platform_link_options=:{resource_file}
	= (resource_file,{platform_link_options & resource_file = stderr});

generate_resource_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_resource_section_header _ pe_file platform_link_options=:{resource_size,resource_delta} state files
	#! (resource_file,platform_link_options) = get_resource_file platform_link_options
	// copy and close resource
	#! resource_info
		= { ResourceInfo |
			min_data_entry_rva	= 0
		,	max_data_entry_rva	= 0
		,	min_max_initialized	= False
		
		,	n_bytes_copied		= 0
		,	n_bytes_to_copy		= resource_size
		
		,	delta				= resource_delta
		,	child_rvas			= []
		};
	
	#! (ok1,resource_file,pe_file)
		= copy_resource_section resource_info resource_file pe_file;			

	// close resource file
	#! (ok2,files)
		= fclose resource_file files;
				
	| not ok1 || not ok2 
		#! (resource_file_name,platform_link_options) = platform_link_options!plo_lo.resource_file_name;
		#! msg
			= "resource '" +++ resource_file_name +++ "' could not be linked"  
	 	= (pe_file,platform_link_options,AddMessage (LinkerError msg) state,files);
	 	
	#! platform_link_options
		= { platform_link_options &
			resource_file	= stderr
		};
	= (pe_file,platform_link_options,state,files);
where {
	copy_resource_section :: !*ResourceInfo !*File !*File -> (!Bool,!*File,!*File);
	copy_resource_section resource_info=:{delta=0,n_bytes_to_copy} resource_file pe_file
		= copy_bytes n_bytes_to_copy resource_file pe_file;

	copy_resource_section resource_info resource_file pe_file
		#! (resource_info,resource_file,pe_file)
			= copy_resource_dir_with_its_entries resource_info resource_file pe_file;
		#! (resource_info,resource_file,pe_file)
			= copy_resource_dir_tables resource_info resource_file pe_file //(True,resource_file,pe_file);
		| not resource_info.min_max_initialized
			// no resource data entries; so nothing to relocate
			# {n_bytes_copied, n_bytes_to_copy} = resource_info
			= copy_bytes (n_bytes_to_copy - n_bytes_copied) resource_file pe_file

		// resource data entries occupy min_data_entry_va - max_data_entry_rva; despite the suffix
		// rva it are virtual addresses (va's); copy bytes before data entries, if any
		#! n_bytes_copied_before_data_entries
			= resource_info.min_data_entry_rva - resource_info.n_bytes_copied;
		#! (ok1,resource_file,pe_file)
			= copy_bytes n_bytes_copied_before_data_entries resource_file pe_file;

		// copy and relocate the data entries
		#! n_resource_data_entries
			= ((resource_info.max_data_entry_rva + s_resource_data_entry) - resource_info.min_data_entry_rva) / s_resource_data_entry;
		#! (ok2,resource_info,resource_file,pe_file)
			= relocate_and_copy_data_entries n_resource_data_entries resource_info resource_file pe_file;
		# resource_info
			= { resource_info &
				n_bytes_copied	= resource_info.n_bytes_copied + n_bytes_copied_before_data_entries
			};
		= write_rest_of_bytes (ok1 && ok2) resource_info resource_file pe_file;
	where {
		write_rest_of_bytes :: !Bool !*ResourceInfo !*File !*File -> (!Bool,!*File,!*File);
		write_rest_of_bytes False resource_info=:{n_bytes_to_copy,n_bytes_copied} resource_file pe_file
			= (False,resource_file,pe_file);

		write_rest_of_bytes ok resource_info=:{n_bytes_to_copy,n_bytes_copied} resource_file pe_file
			= copy_bytes (n_bytes_to_copy - n_bytes_copied) resource_file pe_file;
	
		relocate_and_copy_data_entries :: !Int *ResourceInfo *File *File -> *(.Bool,*ResourceInfo,.File,.File);
		relocate_and_copy_data_entries 0 resource_info resource_file pe_file
			= (True,resource_info,resource_file,pe_file);
		relocate_and_copy_data_entries entry_n resource_info=:{delta,n_bytes_copied} resource_file pe_file
			// read, relocate and write data virtual address (va)
			#! (ok1,data_va,resource_file)
				= freadi resource_file;
			#! pe_file
				= fwritei (data_va + delta) pe_file;
			
			// read and write size
			#! (ok2,size,resource_file)
				= freadi resource_file;
			#! pe_file
				= fwritei size pe_file;
				
			// read and write codepage
			#! (ok3,codepage,resource_file)
				= freadi resource_file;
			#! pe_file
				= fwritei codepage pe_file;				
				
			// read and write reserved
			#! (ok4,reserved,resource_file)
				= freadi resource_file;
			#! pe_file
				= fwritei reserved pe_file;				
			| not (ok1 && ok2 && ok3 && ok4)
				= (False,resource_info,resource_file,pe_file);
			= relocate_and_copy_data_entries (dec entry_n) {resource_info & n_bytes_copied = n_bytes_copied + s_resource_data_entry} resource_file pe_file;

		copy_resource_dir_tables :: !*ResourceInfo !*File !*File -> (!*ResourceInfo,!*File,!*File);
		copy_resource_dir_tables resource_info=:{child_rvas=[],n_bytes_copied} resource_file pe_file
			= (resource_info,resource_file,pe_file);
			
		copy_resource_dir_tables resource_info=:{n_bytes_copied,n_bytes_to_copy} resource_file pe_file
			// sanity checks
			| n_bytes_copied >= n_bytes_to_copy
				= abort "copy_resource_dir_tables; error copying resource directory table";
				
			#! (child,children,resource_info)
				= u_sel_child_rvas resource_info;
			| child <> n_bytes_copied
				= abort ("copy_resource_dir_tables; error too few resource nodes" +++ hex_int n_bytes_copied +++ " - " +++ hex_int child ); //+++ toString (length child_rvas));

			// read resource directory table				
			#! resource_info
				= {resource_info & child_rvas = children }
			#! (resource_info,resource_file,pe_file)
				= copy_resource_dir_with_its_entries resource_info resource_file pe_file;
 			= copy_resource_dir_tables  resource_info resource_file  pe_file;
			
		u_sel_child_rvas :: !*ResourceInfo -> (!Int,.[Int],!*ResourceInfo);	
		u_sel_child_rvas resource_info=:{child_rvas=[child:children]}
			= (child,children,{resource_info & child_rvas = []});

	}
	
	copy_bytes :: !Int !*File !*File -> (!Bool,!*File,!*File);
	copy_bytes 0 resource_file pe_file
		= (True,resource_file,pe_file);

	copy_bytes n_bytes_to_copy resource_file pe_file
		// copy first words
		#! n_words_to_copy
			= n_bytes_to_copy / 4;		
		#! (ok,resource_file,pe_file)
			= copy_words n_words_to_copy resource_file pe_file
		| not ok
			=  (False,resource_file,pe_file);
			
		// copy bytes
		#! n_bytes_to_copy
			= n_bytes_to_copy rem 4;
		= copy_bytes2 n_bytes_to_copy resource_file pe_file;

	copy_words :: !Int !*File !*File -> (!Bool,!*File,!*File);
	copy_words 0 resource_file pe_file
		= (True,resource_file,pe_file);
	copy_words n_words_to_copy resource_file pe_file
		#! (ok,byte,resource_file)
			= freadi resource_file;
		| not ok
			= (False,resource_file,pe_file);
		= copy_words (dec n_words_to_copy) resource_file (fwritei byte pe_file);
	
	copy_bytes2 :: !Int !*File !*File -> (!Bool,!*File,!*File);
	copy_bytes2 0 resource_file pe_file
		= (True,resource_file,pe_file);
	copy_bytes2 n_bytes_to_copy resource_file pe_file
		#! (ok,byte,resource_file)
			= freadc resource_file;
		| not ok
			= (False,resource_file,pe_file);
		= copy_bytes2 (dec n_bytes_to_copy) resource_file (fwritec byte pe_file);
}

:: *ResourceInfo
	= { 
		min_data_entry_rva		:: !Int
	,	max_data_entry_rva		:: !Int
	
	,	n_bytes_copied			:: !Int
	,	n_bytes_to_copy		:: !Int
	,	min_max_initialized		:: !Bool
	
	, 	delta					:: !Int
	
	,	child_rvas				:: *[Int]
	};

copy_resource_dir_with_its_entries resource_info resource_file pe_file
	#! (n_name_entries,n_id_entries,resource_info,resource_file,pe_file)
		= copy_resource_directory_table resource_file pe_file resource_info
		
	// copy name RVA entries
	#! (resource_file,pe_file,resource_info)
		= copy_entries n_name_entries True resource_file pe_file resource_info;

	// copy integerID entries
	#! (resource_file,pe_file,resource_info)
		= copy_entries n_id_entries False resource_file pe_file resource_info;
	= (resource_info,resource_file,pe_file);
where {
	copy_resource_directory_table resource_file pe_file resource_info=:{n_bytes_copied}
		#! (resource_directory_table,resource_file)
			= freads resource_file s_resource_directory_table;
		#! n_name_entries
			= resource_directory_table IWORD 12;				// number of name entries
		#! n_id_entries
			= resource_directory_table IWORD 14;				// number of id entries
		#! pe_file
			= fwrites resource_directory_table pe_file;
		= (n_name_entries,n_id_entries,{ resource_info & n_bytes_copied = n_bytes_copied + s_resource_directory_table},resource_file,pe_file);

	copy_entries 0 is_name_entry resource_file pe_file resource_info
		= (resource_file,pe_file,resource_info);			
	copy_entries n_entries is_name_entry resource_file pe_file resource_info=:{child_rvas,delta,n_bytes_copied}
		// read and write RVA of name RVA or integer ID
		#! (ok,name_rva_OR_integer_id,resource_file)
			= freadi resource_file;
		| not ok
			= abort "copy_entries; error during read";
		#! pe_file
			= fwritei name_rva_OR_integer_id pe_file;
						
		// read and write RVA data entry or subdirectory
		#! (ok,rva_of_data_entry_OR_subdirectory_rva,resource_file)
			= freadi resource_file;
		#! pe_file
			= fwritei rva_of_data_entry_OR_subdirectory_rva pe_file;

		#! resource_info
			= case (rva_of_data_entry_OR_subdirectory_rva bitand 0x80000000) of {
				0
					// high bit is zero; rva of a resource data entry
					#! rva_resource_data_entry
						= rva_of_data_entry_OR_subdirectory_rva bitand 0x7fffffff;
					#! resource_info
						= min_max rva_resource_data_entry resource_info;
					-> resource_info;
					 //((rva_resource_data_entry + delta) bitand 0x7fffffff,resource_info);
				_
					// high bit is set; rva of another resource directory table
					#! rva_subdirectory
						= rva_of_data_entry_OR_subdirectory_rva bitand 0x7fffffff;
					-> { resource_info & child_rvas = merge [rva_subdirectory] resource_info.child_rvas };
			}
		= copy_entries (dec n_entries) is_name_entry resource_file pe_file {resource_info & n_bytes_copied = n_bytes_copied + s_resource_directory_entry};
	where {
		min_max rva_resource_data_entry resource_info=:{min_data_entry_rva,max_data_entry_rva,min_max_initialized=True}
			#! resource_info
				= { resource_info &
					min_data_entry_rva	= min rva_resource_data_entry min_data_entry_rva
				,	max_data_entry_rva	= max rva_resource_data_entry max_data_entry_rva
				};
			= resource_info;		min_max rva_resource_data_entry resource_info=:{min_max_initialized}
			#! resource_info
				= { resource_info &
					min_data_entry_rva	= rva_resource_data_entry
				,	max_data_entry_rva	= rva_resource_data_entry
				,	min_max_initialized	= True
				};
			= resource_info;
	} // copy_entries
} // copy_resource_dir_with_its_entries

compute_user_section_header :: !Int !Int !Int !SectionHeader !*State !*PlatformLinkOptions !*Files -> *(!Int,!SectionHeader,!*State,!*PlatformLinkOptions,!*Files);
compute_user_section_header start_rva fp i_user_section_header user_section_header  state=:{marked_bool_a,module_offset_a,xcoff_a,n_library_symbols,n_xcoff_symbols,n_libraries,library_list} platform_link_options=:{exported_symbols,n_imported_symbols,idata_strings_size,base_va} files
	#! xcoff_list 
		= xcoff_array_to_list 0 xcoff_a;
	
	// body
	#! user_section_start_va
		= base_va + start_rva;
	#! (user_section_name,user_section_flags)
		= get_user_section_name user_section_header;
		
	#! (marked_bool_a,user_section_end_va,module_offset_a, xcoff_list)
		= compute_module_offsets_for_user_defined_sections user_section_name 0 xcoff_list user_section_start_va 0 marked_bool_a module_offset_a;

	// update section header
	#! pd_section_header = {
			section_name				= user_section_name
		,	section_rva					= start_rva
		,	section_flags				= user_section_flags
		};
	#! user_section_header = user_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data (user_section_end_va - user_section_start_va);
		
	#! state
		= { state &
			marked_bool_a = marked_bool_a,
			module_offset_a = module_offset_a,
			xcoff_a = xcoff_list_to_xcoff_array xcoff_list state.n_xcoff_files
		};

	= (i_user_section_header,user_section_header,state,platform_link_options,files);
where {
	get_user_section_name user_section_header
		#! kind
			= sh_get_kind user_section_header;
		= case kind of {
			UserSectionHeader user_section_name user_section_flags _
				-> (user_section_name,user_section_flags)
			};
}

generate_user_section_header :: !SectionHeader !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files);
generate_user_section_header user_section_header pe_file platform_link_options=:{base_va} state=:{n_xcoff_files,n_libraries,library_list} files
	#! (pe_file,platform_link_options)
		= case use_overloaded_write_to_disk of {
			True
				-> abort "generate_user_section_header: you cannot write user defined sections using the overloaded version";
			False
				#! buffer_n
					= get_user_section_buffer_n user_section_header;
				#! (user_data,platform_link_options)
					= sel_user_data buffer_n platform_link_options;
				#! pe_file
					= fwrites user_data pe_file;
				-> (pe_file,platform_link_options);
		}; 
	= (pe_file,platform_link_options,state,files);				
where {
	get_user_section_buffer_n user_section_header
		#! kind
			= sh_get_kind user_section_header;
		= case kind of {
			UserSectionHeader _ _ buffer_n
				-> buffer_n
			};
			
	sel_user_data buffer_n platform_link_options=:{data_buffers}
		#! (data,data_buffers)
			= replace data_buffers buffer_n {};
		= (data,{ platform_link_options & data_buffers = data_buffers});
}
