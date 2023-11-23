/*
DYNAMIC (from xcoff_linker.icl)
read_object_file_dynamic :: !String *NamesTable Bool !*Files !Int -> (![String],!Sections,!Int,![*Xcoff],!*NamesTable,!*Files);
read_object_file_dynamic file_name names_table0 one_pass_link files file_n
	| ends_with "_startup.o" file_name || ends_with "_library.o" file_name || ends_with "cae.o" file_name
		# (ok,xcoff_header_or_error_message,file,files) = open_file_and_read_xcoff_header file_name files;
		| not ok
			= ([xcoff_header_or_error_message],EndSections,file_n,[],names_table0,files);
		| xcoff_header_or_error_message WORD 0==0x01DF
			# (error,text_section,data_section,xcoff_file0,names_table1,files) = read_xcoff_file file_name names_table0 one_pass_link xcoff_header_or_error_message file files file_n;
			| is_nil error
				#  xcoff_file1 = store_xcoff_relocations_in_modules (sort_modules xcoff_file0);
				= ([],Sections text_section data_section EndSections,inc file_n,[xcoff_file1],names_table1,files);
				= (error,EndSections,file_n,[],names_table1,files);
		| xcoff_header_or_error_message LONG 0==0x4D574F42
			# (error,mw_sections2,mw_xcoff_files,file_n2,names_table1,files) = read_mw_object_files file_name file_n names_table0 xcoff_header_or_error_message file files;
			| is_nil error
				= ([],mw_sections2,file_n2,mw_xcoff_files,names_table1,files);
				= (error,EndSections,file_n,[],names_table1,files);
			= (["Not an xcoff file: \""+++file_name+++"\""],EndSections,file_n,[],names_table0,files);

		# (r,object_code) = generate_object_code (remove_obj_file_name_extension file_name);
			with {
				remove_obj_file_name_extension file_name
					# file_name_size=size file_name
					| file_name % (file_name_size-2,file_name_size-1)==".o"
						= file_name % (0,file_name_size-3);
			}
		| r==0
			# xcoff_header_or_error_message=object_code % (0,SIZE_OF_HEADER-1);
			# (error,text_section,data_section,xcoff_file0,names_table1)
				= read_xcoff_file_dynamic file_name object_code names_table0 one_pass_link xcoff_header_or_error_message file_n;
			| is_nil error
				# xcoff_file1 = store_xcoff_relocations_in_modules (sort_modules xcoff_file0);
				= ([],Sections text_section data_section EndSections,inc file_n,[xcoff_file1],names_table1,files);
				= (error,EndSections,file_n,[],names_table1,files);

ends_with s1 s2
	# l1 = size s1;
	# l2 = size s2;
	= l1<=l2 && s2 % (l2-l1,l2-1)==s1;

:: Ptr :== Int;
:: Toolbox :== Int;

generate_code :: !{#Char} -> (!Int,!Int,!Int);
generate_code s = code {
	ccall generatecode "s:III"
}

free_object_code :: !Int -> Int;
free_object_code i = code {
	ccall free_object_code "I:I"
}

copy_pointer_data_to_string :: !{#Char} !Ptr !Int !*Toolbox -> *Toolbox;
copy_pointer_data_to_string string handle size t0 = code (string=CD1,handle=D0,size=D2,t0=U)(t1=Z){
	call	.BlockMoveData
}	

generate_object_code :: !String -> (!Int,!String);
generate_object_code module_name
	# (r,p,object_code_size) = generate_code (module_name +++ "\0");
	# object_code = createArray object_code_size '\0';
	# t = copy_pointer_data_to_string object_code p object_code_size 0;
	| free_object_code t==0
		= (r,object_code);
*/

/*
DYNAMIC (from linker2.icl)
read_xcoff_file_dynamic :: !String {#Char} *NamesTable Bool !String Int -> (![String],!*String,!*String,!*Xcoff,!*NamesTable);
read_xcoff_file_dynamic file_name object_code names_table0 one_pass_link header_string file_n
	# (ok1,n_sections,symbol_table_offset,n_symbols,offset) = parse_xcoff_header_dynamic header_string object_code;
	| not ok1
		= error ("Not an xcoff file: \""+++file_name+++"\"");
	#	(ok2,text_relocation_offset,n_text_relocations,text_section_offset,text_section_size,text_v_address,offset)
			= read_xcoff_text_or_data_section_header_dynamic ".text" offset object_code;
	| not ok2
		= error "Error in text section header";
	#	(ok3,data_relocation_offset,n_data_relocations,data_section_offset,data_section_size,data_v_address,offset)
			= read_xcoff_text_or_data_section_header_dynamic ".data" offset object_code;
	| not ok3
		= error "Error in data section header";
	#	(ok4,offset)
			= read_other_section_headers_dynamic n_sections offset object_code;
	| not ok4
		= error "Error in section header";
	#	(ok5,text_section)
			= read_text_section_dynamic one_pass_link text_section_offset text_section_size object_code;
	| not ok5
		= error "Error in text section";
	#	(ok6,data_section)
			= read_section_dynamic one_pass_link data_section_offset data_section_size object_code;
	| not ok6
		= error "Error in data section";
	#	(ok7,text_relocations)
			= read_relocations_dynamic text_relocation_offset n_text_relocations object_code;
	| not ok7
		= error "Error in text relocations";
	#	(ok8,data_relocations)
			= read_relocations_dynamic data_relocation_offset n_data_relocations object_code;
	| not ok8
		= error "Error in data relocations";
	#	(ok9,symbol_table_string,string_table)
			= read_symbol_table_dynamic symbol_table_offset n_symbols object_code;
	| not ok9
		= error ("Error in symbol table "+++file_name);
		= ([],text_section,data_section,xcoff_file,names_table1);
		{
			xcoff_file={header=header,symbol_table=symbol_table0,n_symbols=n_symbols_2,
						text_relocations=text_relocations,data_relocations=data_relocations,
						n_text_relocations=n_text_relocations,n_data_relocations=n_data_relocations};
			header={file_name=file_name,text_section_offset=text_section_offset,data_section_offset=data_section_offset,
					text_section_size=text_section_size,data_section_size=data_section_size,
					text_v_address=text_v_address,data_v_address=data_v_address};
			(names_table1,symbol_table0)
					=define_symbols n_symbols_2 symbol_table_string string_table names_table0 file_n;
			n_symbols_2						= (inc n_symbols) >> 1;
		}
	{
		error :: String -> (![String],!*String,!*String,!*Xcoff,!*NamesTable);
		error error_string
			= ([error_string],empty_section_string,empty_section_string,empty_xcoff,names_table0);
	}

parse_xcoff_header_dynamic :: String String -> (!Bool,!Int,!Int,!Int,!Int);
parse_xcoff_header_dynamic header_string object_code
	# f_nscns=header_string WORD 2;
	| not (header_string WORD 0==0x01DF && f_nscns>=2)
		= (False,0,0,0,SIZE_OF_HEADER);
		# f_symptr=header_string LONG 8;
		  f_nsyms=header_string LONG 12;
		  f_opthdr=header_string WORD 16;
		= (True,f_nscns,f_symptr,f_nsyms,SIZE_OF_HEADER+f_opthdr);

read_xcoff_text_or_data_section_header_dynamic :: String Int String -> (!Bool,!Int,!Int,!Int,!Int,!Int,!Int);
read_xcoff_text_or_data_section_header_dynamic section_name offset object_code
	# header_string = object_code % (offset,offset+SIZE_OF_SECTION_HEADER-1);
	# offset = offset + SIZE_OF_SECTION_HEADER;
	| (size header_string==SIZE_OF_SECTION_HEADER && header_string % (0,4)==section_name && header_string CHAR 5=='\0')
		= (True,s_relptr,s_nreloc,s_scnptr,s_size,s_vaddr,offset);{
			s_vaddr=header_string LONG 12;
			s_size=header_string LONG 16;
			s_scnptr=header_string LONG 20;
			s_relptr=header_string LONG 24;
			s_nreloc=header_string WORD 32;
		}
		= (False,0,0,0,0,0,offset);

read_other_section_headers_dynamic :: Int Int String -> (!Bool,!Int);
read_other_section_headers_dynamic n_sections offset object_code
	| n_sections==2
		= (True,offset);
	# header_string = object_code % (offset,offset+SIZE_OF_SECTION_HEADER-1);
	# offset=offset+SIZE_OF_SECTION_HEADER;
	| not (size header_string==SIZE_OF_SECTION_HEADER)
		= (False,offset);
		= read_other_section_headers_dynamic (dec n_sections) offset object_code;

read_text_section_dynamic :: Bool Int Int String -> (!Bool,!*String);
read_text_section_dynamic one_pass_link offset section_size object_code
	| one_pass_link && section_size > 2048
		= (True,empty_section_string);
		= read_section_dynamic one_pass_link offset section_size object_code;

read_section_dynamic :: Bool Int Int String -> (!Bool,!*String);
read_section_dynamic one_pass_link offset section_size object_code
	| not one_pass_link || section_size==0
		= (True,empty_section_string)
	# section_string = object_code %. (offset,offset+section_size-1);
	| size section_string==section_size
		= (True,section_string);
		= (False,section_string);

(%.) ::!{#Char} !(!Int,!Int) -> .{#Char};
(%.) str (a,b) = code {
	.d 1 2 ii
		jsr sliceAC
	.o 1 0
}

read_relocations_dynamic offset n_relocations object_code
	| n_relocations==0
		= (True,"");
		# relocation_size=n_relocations * SIZE_OF_RELOCATION;
		# relocation_string = object_code % (offset,offset+relocation_size-1);
		= (size relocation_string==relocation_size,relocation_string);

read_symbol_table_dynamic :: !Int !Int !String -> (!Bool,!String,!String);
read_symbol_table_dynamic symbol_table_offset n_symbols object_code
	= read_symbols_dynamic n_symbols symbol_table_offset object_code;

	read_symbols_dynamic :: Int Int String -> (!Bool,!String,!String);
	read_symbols_dynamic n_symbols symbol_table_offset object_code
		# symbol_table_size=n_symbols*SIZE_OF_SYMBOL;
		  symbol_table_string=object_code % (symbol_table_offset,symbol_table_offset+symbol_table_size-1);
		| not (size symbol_table_string==symbol_table_size)
			= (False,"","");
			# (ok,string_table)=read_string_table_dynamic (symbol_table_offset+symbol_table_size) object_code;
			= (ok,symbol_table_string,string_table);

	read_string_table_dynamic :: Int String -> (!Bool,!String);
	read_string_table_dynamic offset object_code
		# string_table_size = object_code LONG offset;
		# offset=offset+4;
		| string_table_size==0
			= (True,"");
		| string_table_size<4
			= error;
		# string_table_size2=string_table_size-4;
		# string_table_string = object_code % (offset,offset+string_table_size2-1);
		| not (size string_table_string==string_table_size2)
			= error;
			= (True,string_table_string);
		{}{
			error=>(False,"");
		}
*/
