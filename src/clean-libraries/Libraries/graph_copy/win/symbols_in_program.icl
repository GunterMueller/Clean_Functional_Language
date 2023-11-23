implementation module symbols_in_program;

import StdEnv;

:: Symbol = { symbol_name :: !String, symbol_value :: !Int};

freadu2 :: !*File -> (!Bool,!Int,!*File);
freadu2 file
	# (ok,c1,file) = freadc file;
	| not ok
		= (False,toInt c1,file);
	# (ok,c2,file) = freadc file;
	= (ok,((toInt c2)<<8)+toInt c1,file);

:: SectionInfo = {
	text_section_n :: !Int,
	data_section_n :: !Int,
	bss_section_n :: !Int,
	text_va :: !Int,
	data_va :: !Int,
	bss_va :: !Int
   };

read_section_headers :: !Int !Int !SectionInfo !*File -> (!SectionInfo,!*File);
read_section_headers section_n n_sections section_info exe_file
	| section_n==n_sections // section_n starts at 1
		= (section_info,exe_file);
		# (section_name,exe_file) = freads exe_file 8;
		| size section_name<>8
			= abort "Error in section header";
		# (ok,virtual_size,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,virtual_address,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# section_info
			= case section_name of {
				".text\0\0\0"
					-> {section_info & text_section_n=section_n, text_va=virtual_address};
				".data\0\0\0"
					-> {section_info & data_section_n=section_n, data_va=virtual_address};
				".bss\0\0\0\0"
					-> {section_info & bss_section_n=section_n, bss_va=virtual_address};
				_
					-> section_info;
			  }
		# (ok,s_raw_data,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,raw_data_offset,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,relocations_offset,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,line_numbers_offset,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,n_relocations,exe_file) = freadu2 exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,n_line_number,exe_file) = freadu2 exe_file;
		| not ok
			= abort "Error in section header";
		# (ok,characteristics,exe_file) = freadi exe_file;
		| not ok
			= abort "Error in section header";
		= read_section_headers (section_n+1) n_sections section_info exe_file;

skip_to_null_char i s
	| s.[i]<>'\0'
		= skip_to_null_char (i+1) s;
		= i;		

exported_z_clean_symbol_length_gt_8 :: !Int !{#Char} -> Bool;
exported_z_clean_symbol_length_gt_8 i s
	| s.[i]=='e' && s.[i+1]=='_' && s.[i+2]=='_'
		= True;
	| s.[i]=='_'   && s.[i+1]=='_'
		| s.[i+2]=='S' && s.[i+3]=='T' && s.[i+4]=='R' && s.[i+5]=='I' &&
	 	  s.[i+6]=='N' && s.[i+7]=='G' && s.[i+8]=='_' && s.[i+9]=='_' && s.[i+10]=='\0'
			= True;
		| s.[i+2]=='C' && s.[i+3]=='o' && s.[i+4]=='n' && s.[i+5]=='s' &&
		  (s.[i+6]=='s' || s.[i+6]=='i' || s.[i+6]=='c' || s.[i+6]=='r' || s.[i+6]=='b' || s.[i+6]=='f') &&
		  s.[i+7]=='t' && s.[i+8]=='s' && s.[i+9]=='\0'
			= True;
		| s.[i+2]=='A' && s.[i+3]=='R' && s.[i+4]=='R' && s.[i+5]=='A' &&
		  s.[i+6]=='Y' && s.[i+7]=='_' && s.[i+8]=='_' && s.[i+9]=='\0'
			= True;
			= False;
	| s.[i]=='n' && s.[i+1]=='_' && s.[i+2]=='_' && s.[i+3]=='C' && s.[i+4]=='o' && s.[i+5]=='n' &&
	  s.[i+6]=='s' && s.[i+7]=='s' && s.[i+8]=='t' && s.[i+9]=='s' && s.[i+10]=='\0'
		= True;
		= False;

exported_clean_symbol_length_le_8 :: !{#Char} -> Bool;
exported_clean_symbol_length_le_8 s
	| size s>=3 && s.[0]=='e' && s.[1]=='_' && s.[2]=='_'
		= True;
	| size s>=2 && s.[0]=='_' && s.[1]=='_'
		| size s>=6 && s.[2]=='C' && s.[3]=='o' && s.[4]=='n' && s.[5]=='s'
			| size s==6
				= True;
			| s.[6]=='s' || s.[6]=='i' || s.[6]=='c' || s.[6]=='r' || s.[6]=='b' || s.[6]=='f'
				| size s==7
					= True;
				= False;
			| s.[6]=='a' && size s==7
				= True;
			| size s==8 && s.[6]=='t' && s.[7]=='s'
				= True;
			= False;
		| size s==5 && s.[2]=='N' && s.[3]=='i' && s.[4]=='l'
			= True;
		| size s==6 && s.[2]=='N' && s.[3]=='o' && s.[4]=='n' && s.[5]=='e'
			= True;
		| size s==7 && s.[2]=='T' && s.[3]=='u' && s.[4]=='p' && s.[5]=='l' && s.[6]=='e'
			= True;
		| size s==6 && s.[2]=='J' && s.[3]=='u' && s.[4]=='s' && s.[5]=='t'
			= True;
		| size s==7 && s.[2]=='J' && s.[3]=='u' && s.[4]=='s' && s.[5]=='t'
			| s.[6]=='s' || s.[6]=='i' || s.[6]=='c' || s.[6]=='r' || s.[6]=='b' || s.[6]=='f' ||
			  s.[6]=='a'
				= True;
				= False;
			= False;
	| size s==3 && s.[0]=='I' && s.[1]=='N' && s.[2]=='T'
		= True;
	| size s==4 && s.[0]=='C' && s.[1]=='H' && s.[2]=='A' && s.[3]=='R'
		= True;
	| size s==4 && s.[0]=='R' && s.[1]=='E' && s.[2]=='A' && s.[3]=='L'
		= True;
	| size s==4 && s.[0]=='B' && s.[1]=='O' && s.[2]=='O' && s.[3]=='L'
		= True;
	| size s==5 && s.[0]=='A' && s.[1]=='R' && s.[2]=='R' && s.[3]=='A' && s.[4]=='Y'
		= True;
	| size s>=3 && s.[0]=='n' && s.[1]=='_' && s.[2]=='_'
		| size s==7 && s.[3]=='S' && s.[4]=='_' && s.[5]=='P' && s.[6]>='1' && s.[6]<='6'
			= True;
		| size s>=7 && s.[3]=='C' && s.[4]=='o' && s.[5]=='n' && s.[6]=='s'
			| size s>=8 && s.[7]=='s'
				| size s==8
					= True;
					= False;
				= False;
		| size s==8 && s.[3]=='J' && s.[4]=='u' && s.[5]=='s' && s.[6]=='t' && s.[7]=='s'
			= True;
			= False;
		= False;

read_symbol_name :: !{#Char} !*File -> (!{#Char},!*File);
read_symbol_name string_table exe_file
	# (ok,first4chars_or_zero,exe_file) = freadi exe_file;
	| not ok
		= abort "Error reading symbol table";
	| first4chars_or_zero==0
		# (ok,string_table_offset,exe_file) = freadi exe_file;
		| not ok
			= abort "Error reading symbol table";
			# string_table_offset = string_table_offset-4; // first 4 chars containing size not included
			| exported_z_clean_symbol_length_gt_8 string_table_offset string_table
				# zero_char_offset = skip_to_null_char string_table_offset string_table;
				= (string_table % (string_table_offset,zero_char_offset-1),exe_file);
				= ("",exe_file);
	# (ok,next4chars,exe_file) = freadi exe_file;
	| not ok
		= abort "Error reading symbol table";
	# first4chars = first4chars_or_zero;
	# has_zero_byte = (first4chars - 0x01010101) bitand (bitnot first4chars) bitand 0x80808080 <> 0;
	# c0 = toChar first4chars;
	  c1 = toChar (first4chars>>8);
	  c2 = toChar (first4chars>>16);
	  c3 = toChar (first4chars>>24);
	| has_zero_byte
		| first4chars bitand 0xff==0
			= ("",exe_file);
		| first4chars bitand 0xff00==0
			= return_exported_clean_symbol_length_le_8 {c0} exe_file;
		| first4chars bitand 0xff0000==0
			= return_exported_clean_symbol_length_le_8 {c0,c1} exe_file;
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2} exe_file;
		# c4 = toChar next4chars;
		  c5 = toChar (next4chars>>8);
		  c6 = toChar (next4chars>>16);
		  c7 = toChar (next4chars>>24);
		| next4chars bitand 0xff==0
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2,c3} exe_file;
		| next4chars bitand 0xff00==0
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2,c3,c4} exe_file;
		| next4chars bitand 0xff0000==0
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2,c3,c4,c5} exe_file;
		| next4chars bitand 0xff000000==0
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2,c3,c4,c5,c6} exe_file;
			= return_exported_clean_symbol_length_le_8 {c0,c1,c2,c3,c4,c5,c6,c7} exe_file;

return_exported_clean_symbol_length_le_8 :: !{#Char} !*File -> (!{#Char},!*File);
return_exported_clean_symbol_length_le_8 symbol_name exe_file
	| exported_clean_symbol_length_le_8 symbol_name
		= (symbol_name,exe_file);
		= ("",exe_file);

read_symbol_table :: !Int !Int !{#Char} ![({#Char},Int)] !*File !SectionInfo -> (![({#Char},Int)],!*File);
read_symbol_table symbol_n n_symbols string_table symbol_table exe_file section_info
	| symbol_n<n_symbols
		# (symbol_name,exe_file) = read_symbol_name string_table exe_file;
		# (ok,value,exe_file) = freadi exe_file;
		| not ok
			= abort "Error reading symbol table";
		# (ok,section_n,exe_file) = freadu2 exe_file;
		| not ok
			= abort "Error reading symbol table";
		# (ok,type,exe_file) = freadu2 exe_file;
		| not ok
			= abort "Error reading symbol table";
		# (ok,storage_class,exe_file) = freadc exe_file;
		| not ok
			= abort "Error reading symbol table";
		# (ok,n_aux_symbols,exe_file) = freadc exe_file;
		| not ok
			= abort "Error reading symbol table";
		| not (storage_class=='\02' /*|| storage_class=='\65'*/) /*IMAGE_SYM_CLASS_EXTERNAL IMAGE_SYM_CLASS_FUNCTION*/
		|| size symbol_name==0
			| n_aux_symbols=='\0'
				= read_symbol_table (symbol_n+1) n_symbols string_table symbol_table exe_file section_info;
				# exe_file = skip_aux_entries n_aux_symbols exe_file;
				= read_symbol_table (symbol_n+1+toInt n_aux_symbols) n_symbols string_table symbol_table exe_file section_info;
		| section_n==section_info.text_section_n
			#! value = value+section_info.text_va;
			# symbol_table = [(symbol_name,value):symbol_table];
			| n_aux_symbols=='\0'
				= read_symbol_table (symbol_n+1) n_symbols string_table symbol_table exe_file section_info;
				# exe_file = skip_aux_entries n_aux_symbols exe_file;
				= read_symbol_table (symbol_n+1+toInt n_aux_symbols) n_symbols string_table symbol_table exe_file section_info;
		| section_n==section_info.data_section_n
			#! value = value+section_info.data_va;
			# symbol_table = [(symbol_name,value):symbol_table];
			| n_aux_symbols=='\0'
				= read_symbol_table (symbol_n+1) n_symbols string_table symbol_table exe_file section_info;
				# exe_file = skip_aux_entries n_aux_symbols exe_file;
				= read_symbol_table (symbol_n+1+toInt n_aux_symbols) n_symbols string_table symbol_table exe_file section_info;
		| section_n==section_info.bss_section_n
			#! value = value+section_info.bss_va;
			# symbol_table = [(symbol_name,value):symbol_table];
			| n_aux_symbols=='\0'
				= read_symbol_table (symbol_n+1) n_symbols string_table symbol_table exe_file section_info;
				# exe_file = skip_aux_entries n_aux_symbols exe_file;
				= read_symbol_table (symbol_n+1+toInt n_aux_symbols) n_symbols string_table symbol_table exe_file section_info;
			| n_aux_symbols=='\0'
				= read_symbol_table (symbol_n+1) n_symbols string_table symbol_table exe_file section_info;
				# exe_file = skip_aux_entries n_aux_symbols exe_file;
				= read_symbol_table (symbol_n+1+toInt n_aux_symbols) n_symbols string_table symbol_table exe_file section_info;
		= (symbol_table,exe_file);

skip_aux_entries n_aux_symbols exe_file
	# n_aux_bytes = 18 * toInt n_aux_symbols;
	# (aux_bytes,exe_file) = freads exe_file n_aux_bytes;
	| size aux_bytes<>n_aux_bytes
		= abort ("Error reading symbol table");
	= exe_file;

read_symbols :: !{#Char} !*Files -> (!{#Symbol},!*Files);
read_symbols file_name files
	# (ok,exe_file,files) = fopen file_name FReadData files;
	| not ok
		= abort ("Could not open file "+++file_name);
	# (ok,exe_file) = fseek exe_file 0x3c FSeekSet;
	| not ok
		= abort "fseek failed";
	# (ok,pe_header_offset,exe_file) = freadi exe_file;
	# (ok,exe_file) = if (pe_header_offset<>0x40)
						(fseek exe_file pe_header_offset FSeekSet)
						(True,exe_file);
	| not ok
		= abort ("fseek to "+++toString pe_header_offset+++" failed");
	# (ok,c,exe_file) = freadc exe_file;
	| not ok || c<>'P'
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,c,exe_file) = freadc exe_file;
	| not ok || c<>'E'
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,c,exe_file) = freadc exe_file;
	| not ok || c<>'\0'
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,c,exe_file) = freadc exe_file;
	| not ok || c<>'\0'
		= abort "Not a PECOFF image file (error in PE header)";

	// read the PE header
	# (ok,machine,exe_file) = freadu2 exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";
	| machine<>IF_INT_64_OR_32 0x8664 0x14c // IMAGE_FILE_MACHINE_AMD64 or IMAGE_FILE_MACHINE_I386
		= abort (IF_INT_64_OR_32
			"Not a PECOFF image file for an AMD64 processor"
			"Not a PECOFF image file for an IA32 processor");
	# (ok,n_sections,exe_file) = freadu2 exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,time_date_stamp,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,symbol_table_offset,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";
	| symbol_table_offset==0
		= abort "This PECOFF image file does not have a symbol table";		
	# (ok,n_symbols,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,s_optional_header,exe_file) = freadu2 exe_file;
	| not ok || s_optional_header<88 // size of standard and windows specific fields
		= abort "Not a PECOFF image file (error in PE header)";
	# (ok,characteristics,exe_file) = freadu2 exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in PE header)";

	// read the stamdard fields of the optional PE header (not optional for an image)
	# (ok,magic,exe_file) = freadu2 exe_file;
	| not ok || magic<>IF_INT_64_OR_32 0x20b 0x10b // PE32+ or PE32 executable
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,major_linker_version,exe_file) = freadc exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,minor_linker_version,exe_file) = freadc exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,s_code,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,s_initialised_data,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,s_uninitialised_data,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,entry_point,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,base_of_code,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	// base_of_data only for PE32
	# (ok,base_of_data,exe_file) = IF_INT_64_OR_32 (True,0,exe_file) (freadi exe_file);
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";

	// read the windows specific fields of the optional PE header (not optional for an image)
	# (ok,image_base,exe_file) = freadi exe_file;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";
	# (ok,exe_file) = fseek exe_file (s_optional_header-IF_INT_64_OR_32 28 32) FSeekCur;
	| not ok
		= abort "Not a PECOFF image file (error in optional PE header)";

	# section_info = {text_section_n=0,data_section_n=0,bss_section_n=0,
					  text_va=0,data_va=0,bss_va=0};
	# (section_info,exe_file)
		= read_section_headers 1 n_sections section_info exe_file;
	# section_info &
		text_va=image_base+section_info.text_va,
		data_va=image_base+section_info.data_va,
		bss_va=image_base+section_info.bss_va;
	# {text_section_n,data_section_n,bss_section_n,text_va,data_va,bss_va} = section_info;
	| text_section_n==0 || data_section_n==0 || bss_section_n==0
		= abort "Error in section headers, .text, .data or .bss section missing";
	// read the string table of the symbol table
	# string_table_offset = symbol_table_offset + 18 * n_symbols;
	# (ok,exe_file) = fseek exe_file string_table_offset FSeekSet;
	| not ok
		= abort "fseek failed";
	# (ok,string_table_size,exe_file) = freadi exe_file;
	| not ok
		= abort "Error reading string table size";
	# (string_table,exe_file) = freads exe_file string_table_size;
	# string_table_size = string_table_size-4; // includes 4 bytes with size
	| size string_table<>string_table_size
		= abort ("Error reading string table");
	# (ok,exe_file) = fseek exe_file symbol_table_offset FSeekSet;
	| not ok
		= abort "fseek failed";
	// read the symbol table
	# (symbols,exe_file) = read_symbol_table 0 n_symbols string_table [] exe_file section_info;
	# symbols = sortBy (\(s1,_) (s2,_) -> s1<s2) symbols;
	# symbols = {#{symbol_name=s,symbol_value=v} \\ (s,v)<-symbols};
	# (ok,files) = fclose exe_file files;
	| not ok
		= abort "Read error";
	= (symbols,files);

get_symbol_value :: !{#Char} !{#Symbol} -> Int;
get_symbol_value symbol_name symbols
	= find_symbol 0 (size symbols) symbol_name symbols;
{
	find_symbol :: !Int !Int !{#Char} !{#Symbol} -> Int;
	find_symbol left right s symbols
		| left<right
			# m = left+((right-left)>>1);
			# s_name = symbols.[m].symbol_name;
			| s==s_name
				= symbols.[m].symbol_value;
			| s<s_name
				= find_symbol left m s symbols;
				= find_symbol (m+1) right s symbols;
			= -1;
}
