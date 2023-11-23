implementation module ReadObject;

import StdEnv;
import StdMaybe;
import xcoff;
from pdSortSymbols import sort_modules;
import ExtString, ExtFile;
import Redirections;
import what_linker,link32or64bits;
import lib;
import RWSDebugChoice;
import pdSymbolTable;
import pdExtString;
import pdExtFile;
import NamesTable;

swap_bytes i :== i;

export_internal_label_names name symbol_n file_n names_table :== names_table;

read_string_table :: !*File -> (!Bool,!String,!*File);
read_string_table file0
	| not ok
		= error file1;
	| string_table_size==0
		= (True,"",file1);
	| string_table_size<4
		= error file1;
	| not (size string_table_string==string_table_size2)
		= error file2;
		= (True,string_table_string,file2);
	{}{
		error file=(False,"",file);
		(string_table_string,file2)=freads file1 string_table_size2;
		string_table_size2=string_table_size-4;

		string_table_size=swap_bytes string_table_size0;

		(ok,string_table_size0,file1)=freadi file0;
	}

read_symbols :: !Int !*File -> (!Bool,!String,!String,!*File);
read_symbols n_symbols file0
	| not (size symbol_table_string==symbol_table_size)
		= (False,"","",file1);
		= (ok,symbol_table_string,string_table,file2);
		{
			(ok,string_table,file2)=read_string_table file1;
		}
	{
		(symbol_table_string,file1)=freads file0 symbol_table_size;
		symbol_table_size=n_symbols*SIZE_OF_SYMBOL;
	}

read_symbol_table :: !Int !Int !Int !*File -> (!Bool,!String,!String,!*File);
read_symbol_table file_offset symbol_table_offset n_symbols file0
	| not fseek_ok
		= error file1;
		= read_symbols n_symbols file1;
	{}{
		(fseek_ok,file1)=fseek file0 (file_offset + symbol_table_offset) FSeekSet;
		error file=(False,"","",file);
	}
	
class ExtFileSystem f
where {
	rlf_fopen :: !{#Char} !Int !*f -> (!Bool,!*File,!*f);
	rlf_fclose :: !*File !*f -> (!Bool,!*f);
	rlf_freadline :: !*File !*f -> (!*{#Char},!*File,!*f)
};

instance ExtFileSystem Files
where {
	rlf_fopen a1 a2 a3
		= fopen a1 a2 a3;
	rlf_fclose a1 a2
		= fclose a1 a2;
	rlf_freadline a1 files
		# (b1,b2)
			= freadline a1;
		= (b1,b2,files);
};

class ImportDynamicLibrarySymbols a :: a !Int !Int !*NamesTable -> (!Int,!Int,!*NamesTable);

instance ImportDynamicLibrarySymbols LibraryList
where {
	ImportDynamicLibrarySymbols EmptyLibraryList symbol_n library_n names_table
		= (symbol_n,library_n,names_table);
	ImportDynamicLibrarySymbols (Library library_name _ library_symbols n_library_symbols library_list) symbol_n library_n names_table
		# (n_symbols,library_n,names_table)
			= ImportDynamicLibrarySymbols library_symbols 0 library_n names_table;
		= ImportDynamicLibrarySymbols library_list (symbol_n + n_symbols) (inc library_n) names_table;
};

add_underscore_if_32_bits s :== Link32or64bits ("_" +++s) s;

instance ImportDynamicLibrarySymbols LibrarySymbolsList
where {
	ImportDynamicLibrarySymbols EmptyLibrarySymbolsList symbol_n library_n names_table
		= (symbol_n,library_n,names_table);
	ImportDynamicLibrarySymbols (LibrarySymbol symbol_name_old library_symbols) symbol_n library_n names_table
		# symbol_name = add_underscore_if_32_bits symbol_name_old;
		# (names_table_element,names_table)
			= find_symbol_in_symbol_table symbol_name names_table;
		| not (isEmptyNamesTableElement names_table_element) 
			= ImportDynamicLibrarySymbols library_symbols symbol_n library_n names_table //<<- (symbol_n,symbol_name_old,"skip"); 
		# names_table = insert_symbol_in_symbol_table symbol_name symbol_n library_n names_table //<<- (symbol_n,symbol_name_old);  ;
		= ImportDynamicLibrarySymbols library_symbols (symbol_n + 2) library_n names_table;
};

read_library_files list library_n n_library_symbols0 files0 names_table0 :== read_library_files_new True list library_n n_library_symbols0 files0 names_table0;

read_library_files_new :: !Bool ![String] !Int !Int !*a !*NamesTable -> *(![String],!LibraryList,!Int,!*a,!*NamesTable) | ExtFileSystem a;
read_library_files_new _ [] library_n n_library_symbols0 files0 names_table0
	= ([],EmptyLibraryList,n_library_symbols0,files0,names_table0);
read_library_files_new use_names_table [file_name:file_names] library_n n_library_symbols0 files0 names_table0
	| ok1
		= (errors,Library library_name 0 library_symbols n_library_symbols libraries,n_library_symbols1,files2,names_table2);
		= (["Cannot read library '" +++ file_name +++ "'"],EmptyLibraryList,0,files1,names_table1);
	{}{
		(errors,libraries,n_library_symbols1,files2,names_table2)
			= read_library_files_new use_names_table file_names (inc library_n) (n_library_symbols0+n_library_symbols) files1 names_table1;
		(ok1,library_name,library_symbols,n_library_symbols,files1,names_table1)
			= read_library_file_new use_names_table  file_name library_n files0 names_table0;
	}

read_library_file library_file_name library_n files names_table :== read_library_file_new True library_file_name library_n files names_table;

read_library_file_new :: !Bool !String !Int !*a !*NamesTable -> *(!Bool,!String,!LibrarySymbolsList,!Int,!*a,!*NamesTable) | ExtFileSystem a;
read_library_file_new use_names_table library_file_name library_n files names_table
	# (ok1,library_file,files) 
		= rlf_fopen library_file_name FReadText files;
	| not ok1
		= (False,"",EmptyLibrarySymbolsList,0,files,names_table);
		
	# (library_name,library_file,files) = rlf_freadline library_file files;
	# (library_symbols,n_library_symbols,library_file,names_table,files) = read_library_symbols library_file 0 names_table files;
	# (ok2,files) = rlf_fclose library_file files;
	# library_name
		= case (size library_name==0 || library_name .[size library_name-1]<>'\n') of {
			True 	-> library_name;
			False	-> library_name % (0,size library_name-2);
		};
	| size library_name<>0 && ok2
		= (True,library_name,library_symbols,n_library_symbols,files,names_table);
		= (False,"",EmptyLibrarySymbolsList,0,files,names_table);
	{}{
		read_library_symbols file0 symbol_n names_table0 files
			# (symbol_line,file1,files)=rlf_freadline file0 files;
			| size symbol_line>1 || (size symbol_line==1 && symbol_line.[0]<>'\n')			
				# symbol_name = case symbol_line.[size symbol_line-1] of {
									'\n' -> symbol_line % (0,size symbol_line-2);
									_	 -> symbol_line;
								};
				#! symbol_name = Link32or64bits
									symbol_name
									(remove_at_sign_digits symbol_name (size symbol_name-1));
				| use_names_table
					# u_symbol_name = add_underscore_if_32_bits symbol_name;
					// check if symbol already present
					#! (names_table_element,names_table0) = find_symbol_in_symbol_table u_symbol_name names_table0;
					| not (isEmptyNamesTableElement names_table_element)
						= read_library_symbols file1 symbol_n names_table0 files;
					# names_table1 = insert_symbol_in_symbol_table u_symbol_name symbol_n library_n names_table0;
					# (library_symbols,symbol_n1,file2,names_table2,files2) = read_library_symbols file1 (symbol_n+2) names_table1 files;
					= (LibrarySymbol symbol_name library_symbols,symbol_n1,file2,names_table2,files2);
					# (library_symbols,symbol_n1,file2,names_table2,files2) = read_library_symbols file1 (symbol_n+2) names_table0 files;
					= (LibrarySymbol symbol_name library_symbols,symbol_n1,file2,names_table2,files2);
			| size symbol_line<>0
				= read_library_symbols file1 symbol_n names_table0 files;			
				= (EmptyLibrarySymbolsList,symbol_n,file1,names_table0,files);
	}

remove_at_sign_digits :: !{#Char} !Int -> {#Char};
remove_at_sign_digits s i
	| i>0
		# c=s.[i]
		| c>='0' && c<='9'
			= remove_at_sign_digits s (i-1);
		| c=='@' && i<size s-1
			= s % (0,i-1)
			= s;
		= s;

decode_line_from_library_file :: String -> Maybe String;
decode_line_from_library_file symbol_name
	| symbol_name.[size symbol_name-1] <> '\n'
		= Just symbol_name;
	| size symbol_name == 1
		= Nothing
		= Just (symbol_name % (0,size symbol_name-2));

read_library_files2 :: [[String]] !Int !Int !*{!NamesTableElement} -> *(!LibraryList,!Int,!*{!NamesTableElement});
read_library_files2 [] library_n n_library_symbols names_table
	= (EmptyLibraryList,n_library_symbols,names_table);
read_library_files2 [library:libraries] library_n n_library_symbols names_table
	# (library_name,n_new_library_symbols,library_symbols,names_table)
		= read_library_file2 library library_n names_table;
	# (libs,n_new_library_symbols,names_table)
		= read_library_files2 libraries (inc library_n) (n_library_symbols + n_new_library_symbols) names_table
	# lib = Library library_name 0 library_symbols n_new_library_symbols libs
	= (libs,n_new_library_symbols,names_table);

read_library_file2 [library_name:symbol_names] library_n names_table
	# (library_symbols,n_library_symbols,_,names_table)
		= read_library_symbols2 symbol_names 0 library_n names_table;
	= (library_name,n_library_symbols,library_symbols,names_table);

read_library_symbols2 [] symbol_n library_n names_table
	= (EmptyLibrarySymbolsList,symbol_n,library_n,names_table);
read_library_symbols2 [symbol_name:symbol_names] symbol_n library_n names_table
	# u_symbol_name = add_underscore_if_32_bits symbol_name
	# (names_table_element,names_table)
		= find_symbol_in_symbol_table u_symbol_name names_table;
	| not (isEmptyNamesTableElement names_table_element)
		= read_library_symbols2 symbol_names symbol_n library_n names_table;
	# names_table = insert_symbol_in_symbol_table u_symbol_name symbol_n library_n names_table;
	# (library_symbols_list,symbol_n,library_n,names_table)
		= read_library_symbols2 symbol_names (symbol_n + 2) library_n names_table;
	= (LibrarySymbol symbol_name library_symbols_list,symbol_n,library_n,names_table);

read_coff_header :: !*File -> (!Bool,!Int,!Int,!Int,!*File);
read_coff_header file
	#! (header_string,file) 
		= freads file SIZE_OF_HEADER;
	| not (size header_string == SIZE_OF_HEADER &&
		   header_string IWORD 0==Link32or64bits IMAGE_FILE_MACHINE_I386 IMAGE_FILE_MACHINE_AMD64)
		= error file;

	#! f_nscns = header_string IWORD 2;
	| not (f_nscns >= 2)
		= error file;
	#! f_opthdr = header_string IWORD 16;
	#! f_symptr = header_string ILONG 8;
	#! f_nsyms = header_string ILONG 12;
	| f_opthdr == 0
		= (True,f_nscns,f_symptr,f_nsyms,file);

	#! (fseek_ok,file2)
		= fseek file f_opthdr FSeekCur;
	| fseek_ok
		= (True,f_nscns,f_symptr,f_nsyms,file2);
	= (error file2);
	{}{
		error file = (False,0,0,0,file);
	}

:: Section = {
		section_segment_n			::!SectionKind,
		section_virtual_address		::!Int,
		section_size				::!Int,
		section_data_offset			::!Int,
		section_relocations_offset	::!Int,
		section_n_relocations		::!Int,
		section_relocations			::!String,
		section_characteristics		::!Int
	};

read_section_headers :: !Int !Int !*{!Section} !*[Directive] !*File -> (!Bool,*{!Section},!*[Directive],!*File);
read_section_headers section_n n_sections sections ds file
	| section_n>n_sections
		= (True,sections,ds,file);
	# (header_string,file) 
		= freads file SIZE_OF_SECTION_HEADER;
	| size header_string<>SIZE_OF_SECTION_HEADER
		= (False,sections,ds,file);
	# (ignore_section,section_segment_n,ds,file)
		= get_section_segment_n header_string ds file;
	| not ignore_section
		# sections 
			= {sections & [section_n] = {
				section_segment_n			= section_segment_n,
				section_virtual_address		= header_string ILONG 12,
				section_size				= header_string ILONG 16,
				section_data_offset			= header_string ILONG 20,
				section_relocations_offset	= header_string ILONG 24,
				section_n_relocations		= header_string IWORD 32,
				section_characteristics		= header_string ILONG 36,
				section_relocations			= ""
			}};
		= read_section_headers (inc section_n) n_sections sections ds file;
		= read_section_headers (inc section_n) n_sections sections ds file;
where {
	get_section_segment_n :: !String !*[Directive] !*File -> (!Bool,!SectionKind,!*[Directive],!*File);
	get_section_segment_n header_string ds file
		# header_string_first6 = header_string % (0,5);
		| header_string_first6==".text\0" || header_string_first6==".text$" || header_string_first6==".text."
			= (False,SK_TEXT,ds,file);
		| header_string_first6==".data\0"
			= (False,SK_DATA,ds,file);
		| header_string_first6==".rdata" && (header_string.[6]=='\0' || header_string.[6]=='$')
			= (False,SK_DATA,ds,file);
		| header_string % (0,4)==".bss\0"
			= (False,SK_BSS,ds,file);
		#! section_characteristics = header_string ILONG 36
		// if length of section name>8, / followed by decimal offset to name in string table, in ascii
		| header_string.[0]=='/' && section_characteristics bitand IMAGE_SCN_MEM_EXECUTE<>0
			= (False,SK_TEXT,ds,file);
		#! data_comdat_characteristics = IMAGE_SCN_CNT_INITIALIZED_DATA bitor IMAGE_SCN_LNK_COMDAT
		| header_string.[0]=='/' && section_characteristics bitand data_comdat_characteristics==data_comdat_characteristics
			= (False,SK_DATA,ds,file);
		| fst (starts ".drectve" header_string)
			// maybe global flags saying ignore 
			#! (ds,file)
				= handle_drectve_section header_string ds file;
			= (True,SK_UNDEF /* ignored */,ds,file);
			#! (section_found,section_kind,ds)
				= lookup_section ds header_string [];
			= (not section_found,section_kind,ds,file);

	lookup_section [] header_string rest
		= (False,SK_UNDEF,rest);
	lookup_section [d=:{dr_section_name,dr_section_kind}:ds] header_string rest
		| fst (starts dr_section_name header_string)
			= (True,dr_section_kind,[{d & dr_section_n = section_n}:rest]);
			= lookup_section ds header_string [d:rest]; 
	
	handle_drectve_section header_string ds file
		// keep track of old position
		#! (fp,file)
			= fposition file;
	
		#! section_size = header_string ILONG 16;
		#! section_data_offset = header_string ILONG 20;
		#! (ok,file)
			= fseek file section_data_offset FSeekSet;
		#! (directives,file)
			= freads file section_size;
		#! ds
			= handle_each_directive 0 (size directives) directives ds;
			
		#! (ok1,file)
			= fseek file fp FSeekSet;
		= (ds,file);
	where {
		handle_each_directive i limit directives ds
			| i >= limit
				= ds;
			#! (found,l)
				= starts_at "/section:" directives i;
			| found
				#! (found,j)
					= CharIndex directives l ',';
				| not found
					= abort "stop2";
				#! section_name
					= directives % (l,j-1);
				
				#! (found,k)
					= CharIndex directives j ' ';
				| not found
					= abort "handle_each_directive; stop";
				#! section_flags
					= directives % (inc j,dec k);
					
				#! dr
					= { Directive |
						dr_section_name 	= section_name
					,	dr_section_flags	= section_flags
					,	dr_section_kind		= SK_USER section_name
					,	dr_section_n		= -1
					};
				= handle_each_directive (inc k) limit directives [dr:ds];
				
				#! (found,k)
					= CharIndex directives i ' ';
				= handle_each_directive (inc k) limit directives ds;
	}
}

read_relocations :: !Int !Int !Int !*{!Section} !*File -> (!Bool,!*{!Section},!*File);
read_relocations file_offset section_n n_sections sections file
	| section_n>n_sections
		= (True,sections,file);

	| sections.[section_n].section_n_relocations<=0
		= read_relocations file_offset (section_n+1) n_sections sections file;
	# (sections_section_n,sections) 
		= uselect sections section_n;
	   (fseek_ok,file)
	   	= fseek file (file_offset + sections_section_n.section_relocations_offset) FSeekSet;
	| not fseek_ok
		= (False,sections,file);
	# relocation_size
		= sections_section_n.section_n_relocations * SIZE_OF_RELOCATION;
	   (relocation_string,file) 
	   	= freads file relocation_size;
	| size relocation_string<>relocation_size
		= (False,sections,file);

	= read_relocations file_offset (section_n+1) n_sections {sections & [section_n]={sections_section_n & section_relocations=relocation_string} } file;

open_xcoff_file :: !String !*Files -> (!Bool,!*File,!*Files);
open_xcoff_file file_name files 
	#! (ok, xcoff_file, files)
		= fopen file_name FReadData files;
	= (ok, xcoff_file, files);
	
close_xcoff_file :: !*File !*Files -> (!Bool,!*Files);
close_xcoff_file file files 
	= fclose file files;
	
read_external_symbol_names_from_xcoff_file :: !String !*Files ->  ([String], !Int, !Int, [String],[String],!*Files);
read_external_symbol_names_from_xcoff_file file_name files
	#! (ok, xcoff_file, files)
		= fopen file_name FReadData files;
	| not ok
		= error ["could not open " +++ file_name] xcoff_file files;
	
	#! (ok1,_,symbol_table_offset,n_symbols,xcoff_file) 
		= read_coff_header xcoff_file;
	#! (ok2,symbol_table_string,string_table,xcoff_file) 
		= read_symbol_table 0 symbol_table_offset n_symbols xcoff_file;
	| not ok1 || not ok2
		= error ["error reading symboltable or stringtable"] xcoff_file files;

	#! (n_external_symbols, external_def_symbols, external_ref_symbols)
		= extract_external_symbols 0 0 [] [] symbol_table_string string_table;
		
	#! (ok, xcoff_size) = FileSize file_name;
	| not ok
		= error ["error getting size of " +++ file_name] xcoff_file files;
	
	#! (ok, files) = fclose xcoff_file files;
	| not ok
		= (["error closing file " +++ file_name], 0, 0, [], [], files);
		
	= ([], xcoff_size, n_external_symbols, external_def_symbols, external_ref_symbols ,files); 

where {
	extract_external_symbols symbol_n n_external_symbols external_def_symbols external_ref_symbols symbol_table_string string_table
		| offset == size symbol_table_string
			= (n_external_symbols, external_def_symbols, external_ref_symbols);
			
			= case (symbol_table_string BYTE (offset+16)) of {
				C_EXT
					| n_scnum == N_UNDEF
						| n_value == 0
							// reference of an external defined symbol
							-> extract_external_symbols (symbol_n+1+n_numaux) (inc n_external_symbols) external_def_symbols [name_of_symbol:external_ref_symbols] symbol_table_string string_table;	
								
							// definition of an external BSS symbol,  
							-> extract_external_symbols (symbol_n+1+n_numaux) (inc n_external_symbols) [name_of_symbol:external_def_symbols] external_ref_symbols symbol_table_string string_table;	
				
						-> extract_external_symbols (symbol_n+1+n_numaux) (inc n_external_symbols) [name_of_symbol:external_def_symbols] external_ref_symbols symbol_table_string string_table;	
				_
					-> extract_external_symbols (symbol_n+1+n_numaux) n_external_symbols external_def_symbols external_ref_symbols symbol_table_string string_table;
			}
	where {
		offset = SIZE_OF_SYMBOL*symbol_n;
		
		name_of_symbol :: {#Char}; // to help the typechecker
		name_of_symbol
			| first_chars==0
				# string_table_offset = (symbol_table_string ILONG (offset+4))-4;
				= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
				= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
			{}{
				first_chars = symbol_table_string ILONG offset;
				
				first_zero_char_offset_or_max string offset max
					| offset>=max || string CHAR offset=='\0'
						= offset;
						= first_zero_char_offset_or_max string (offset+1) max;
			}

		x_scnlen=symbol_table_string ILONG last_aux_offset;
		n_value=symbol_table_string ILONG (offset+8);
		n_scnum=symbol_table_string IWORD (offset+12);
		n_type=symbol_table_string IWORD (offset+14);
		n_numaux=symbol_table_string BYTE (offset+17);	
		last_aux_offset=offset+SIZE_OF_SYMBOL*n_numaux;
	}
	
	error error xcoff_file files
		#! (_,files)
			= fclose xcoff_file files;
		= (error,0,0,[],[],files);
}

read_xcoff_file :: !String !Int !NamesTable !Bool !*File !Int !*RedirectionState -> (!Bool,![String],!*String,!*String,!*Xcoff,!NamesTable,!*File,!*RedirectionState);
read_xcoff_file file_name file_offset names_table0 one_pass_link file file_n rs
	= read_xcoff_fileI file_name file_name file_offset names_table0 one_pass_link file file_n rs;

// this function does the reading of an object file		
read_xcoff_fileI :: !String !String !Int !NamesTable !Bool !*File !Int !*RedirectionState -> (!Bool,![String],!*String,!*String,!*Xcoff,!NamesTable,!*File,!*RedirectionState);
read_xcoff_fileI module_name_within_lib file_name file_offset names_table0 one_pass_link file file_n rs
	#! (ok,n_sections,symbol_table_offset,n_symbols,file) 
		= read_coff_header file;
	| not ok
		= error ("corrupt file '" +++ file_name +++ "'.") file;
		
	#! sections 
		= createArray (n_sections+1) {
			section_segment_n = SK_UNDEF,
			section_virtual_address = 0,
			section_size = -1,
			section_data_offset = 0,
			section_relocations_offset = 0,
			section_n_relocations = -1,
			section_relocations = "",
			section_characteristics = 0
		};
	#! (ok,sections,ds,file) 
		= read_section_headers 1 n_sections sections [] file;
	| not ok
		= error ("corrupt section header in file '" +++ file_name +++ "'") file;

	#! (ok,sections,file) 
		= read_relocations file_offset 1 n_sections sections file;
	| not ok
		= error ("corrupt text relocations in file '" +++ file_name +++ "'") file;
		
	#! text_section = {};
	#! data_section = {};
	#! (ok,symbol_table_string,string_table,file) 
		= read_symbol_table file_offset symbol_table_offset n_symbols file;
	| not ok
		= error ("corrupt symbol table in file '" +++ file_name +++ "'") file;

		= (not (isEmpty ds),[],text_section,data_section,xcoff_file,names_table1,file,new_rs);
		{
			module_name = extract_module_name module_name_within_lib;
	
			xcoff_file = {
				file_name 		= file_name
			,	module_name		= module_name
			,	symbol_table	= symbol_table0
			,	n_symbols		= n_symbols
			};
			
			(names_table1,symbol_table0,new_rs)
				= define_symbols module_name_within_lib ds file_offset n_sections n_symbols symbol_table_string string_table sections names_table0 file_n rs;
		}
		where {		
			error error_string file 
				= (False,[error_string],empty_section_string,empty_section_string,empty_xcoff,names_table0,file,rs);
	}

empty_section_string :: .String;
empty_section_string = createArray 0 ' ';

is_nil :: [a] -> Bool;
is_nil [] = True;
is_nil _ = False;

read_xcoff_files :: !Bool ![String] !NamesTable !Bool !Files !Int !*RedirectionState -> (!Bool,![String],!Sections,!Int,![*Xcoff],!NamesTable,!Files,!*RedirectionState);
read_xcoff_files any_extra_sections file_names names_table0 one_pass_link files0 file_n rs
	= case file_names of {
		[]
			-> (any_extra_sections,[], EndSections, file_n, [], names_table0, files0,rs);
		[file_name:file_names]
			# (any_extra_sections2,error,text_section,data_section,xcoff_file0,names_table1,files1,rs1)
				= ReadXcoff file_name 0 names_table0 one_pass_link files0 file_n rs;
			| is_nil error
				#! (any_extra_sections3,error2,sections,file_n1,xcoff_files,symbol_table2,files2,rs2)
					= read_xcoff_files any_extra_sections2 file_names names_table1 one_pass_link files1 (inc file_n) rs1;
				#! xcoff_file1 = sort_modules xcoff_file0; 
				-> (any_extra_sections || any_extra_sections3,error2, Sections text_section data_section sections, file_n1, [xcoff_file1:xcoff_files], symbol_table2, files2,rs2);
				-> (any_extra_sections || any_extra_sections2,error,EndSections,file_n,[],names_table1,files1,rs1);
	};
	
ReadXcoffM :: !Bool !String !Int !NamesTable !Bool !Int !*RedirectionState !*Files  -> ((!Bool,![String],![*Xcoff],!NamesTable,!*RedirectionState),!Files);  
ReadXcoffM any_extra_sections file_name object_file_offset names_table one_pass_link file_n rs files 
	| ends file_name ".lib"
		// open library
		#! (errors,lib_file,files)
			= StaticOpenLibraryFile file_name files;
		| not (isEmpty errors)
			= ((any_extra_sections,errors,[],names_table,rs),files);
		
		// Read second linker member
		#! (_, _, size, lib_file)
			= read_archive_member_header lib_file "";
		#! (ok, lib_file)
			= fseek lib_file (make_even size) FSeekCur;
	
		//
		#! (any_extra_sections,lib_file,names_table,file_n,xcoff_list,rs)
			= read_other_linker_members any_extra_sections file_name True lib_file names_table file_n [] "" rs;
		#! xcoff_list 
			= reverse xcoff_list;		
						
		// close library
		#! files 
			= CloseLibraryFile lib_file files;
		= ((any_extra_sections,errors,xcoff_list,names_table,rs),files);			
			
		// for {o,obj}-files
		#! (any_extra_sections2,errors,_,_,xcoff,names_table,files,rs)
			= ReadXcoff file_name object_file_offset names_table one_pass_link files file_n rs;
		#! any_extra_sections
			= any_extra_sections || any_extra_sections2;
		= ((any_extra_sections,errors,[xcoff],names_table,rs),files);
where {
	read_other_linker_members :: !Bool !String !Bool !*File !NamesTable !Int ![*Xcoff] !String !*RedirectionState ->  (!Bool,!*File,!NamesTable,!Int,![*Xcoff],!*RedirectionState);		  			  				
	read_other_linker_members any_extra_sections lib_file_name read_xcoff_object lib_file names_table file_n xcoffs longnames_member rs
		#! (eof, lib_file)
			= fend lib_file;
		| eof
			= (any_extra_sections,lib_file, names_table, file_n, xcoffs,rs);
						
		/*
		** Read archive member (both header and object-file)
		*/
		#! (is_longnames_member, object_name, sizeq, lib_file)
			= read_archive_member_header lib_file longnames_member;
		| is_longnames_member
			#! (longnames_member, lib_file) 
				= freads lib_file sizeq
			#! (_,_,lib_file)
				= case (isEven sizeq) of {
					True
						-> (True,' ', lib_file);
					False
		 				-> freadc lib_file;
				}
			= read_other_linker_members any_extra_sections lib_file_name True lib_file names_table file_n xcoffs longnames_member rs;
				
			// object member; read object file from library if required					
			#! (object_file_offset, lib_file)
				= fposition lib_file;
				
			#! (any_extra_sections2,_,_,_,xcoff,names_table,lib_file,rs)
				= read_xcoff_file lib_file_name object_file_offset names_table True lib_file file_n rs;
			#! any_extra_sections = any_extra_sections || any_extra_sections2;
			#! xcoff = { xcoff & module_name = extract_module_name object_name };

			#! (ok, lib_file)
				= fseek lib_file (make_even (object_file_offset + sizeq)) FSeekSet
			| not ok
				= abort "read_other_linker_members: seek not found";
				
				= read_other_linker_members any_extra_sections lib_file_name True lib_file names_table (inc file_n) [xcoff:xcoffs] longnames_member rs;				
}

ReadXcoff :: !String !Int !NamesTable !Bool !*Files !Int !*RedirectionState -> (!Bool,![String],!*String,!*String,!*Xcoff,!NamesTable,!Files,!*RedirectionState);  
ReadXcoff file_name object_file_offset names_table one_pass_link files file_n rs
	#! (ok,file,files) 
		= fopen file_name FReadData files;
	| not ok
		= error ("Linker error: could not open file '"+++file_name+++"'.") names_table file files;

	#! (ok, file)
		= case object_file_offset of {
			0	-> (True, file);
			_	-> fseek file object_file_offset FSeekSet;
		}
	| not ok
		= error ("Linker error: file '" +++ file_name +++ "' is corrupt.") names_table file files;

	#! (any_extra_section,err,text_section,data_section,xcoff_file,names_table,file,rs)
		= read_xcoff_file file_name object_file_offset names_table one_pass_link file file_n rs
	
	#! (_,files)
		= fclose file files;			
	= (any_extra_section,err,text_section,data_section,xcoff_file,names_table,files,rs)
where {
	error error_string names_table file files
		= (False,[error_string],empty_section_string,empty_section_string,empty_xcoff,names_table, snd (fclose file files),rs );
}

define_symbols :: !String ![Directive] !Int !Int !Int !String !String {!Section} !NamesTable !Int !*RedirectionState -> (!NamesTable,!SymbolTable,!*RedirectionState);
define_symbols module_name ds file_offset n_sections n_symbols symbol_table_string string_table sections names_table file_n rs
	#! (s_names_table,names_table) = usize names_table;
	#! rs1 = { rs1 & rs_change_rts_label = isMember module_name rs1.rs_rts_modules };
	= define_symbols_lp 0 names_table empty_symbol_table rs1;
where {
		(redirect,_,rs1)
			= (False,0,rs);
	
		empty_symbol_table = {	text_symbols=EmptySymbolIndex,
								data_symbols=EmptySymbolIndex,
								bss_symbols=EmptySymbolIndex,
								imported_symbols=EmptySymbolIndex,
								section_symbol_ns=createArray (n_sections+1) (-10),
								n_sections = n_sections+1,
								symbols=createArray n_symbols EmptySymbol,
								extra_sections = map directive_to_extra_section ds
							 };
		
		directive_to_extra_section {dr_section_name,dr_section_flags}
			= { ExtraSection |
				es_name 	= dr_section_name
			,	es_flags	= toFlags 0 (size dr_section_flags) 0
			,	es_symbols	= EmptySymbolIndex
			,	es_buffer_n	= 0
			};	
		where {
			toFlags :: !Int !Int !Int -> Int;
			toFlags i limit flags 
				| i == limit
					= flags;
				= toFlags (inc i) limit (flags bitor (to_flag dr_section_flags.[i]));
					
			to_flag 'r'	= IMAGE_SCN_MEM_READ;
			to_flag 'w'	= IMAGE_SCN_MEM_WRITE;
			to_flag 's' = IMAGE_SCN_MEM_SHARED;
		}
		
		define_symbols_lp :: !Int !NamesTable !SymbolTable !*RedirectionState -> (!NamesTable,!SymbolTable,!*RedirectionState);
		define_symbols_lp symbol_n names_table symbol_table rs

			| (offset==size symbol_table_string)
				= (names_table,symbol_table,rs);
				
				= case (symbol_table_string BYTE (offset+16)) of {
					C_EXT 
						| n_scnum==N_UNDEF
							| n_value==0
								/* n_value == 0; only external reference */
								#! names_table
									= export_internal_label_names name_of_symbol symbol_n file_n names_table;
								#! symbol_table
									= {symbol_table & 
										symbols={symbol_table.symbols & [symbol_n]= ImportLabel name_of_symbol}
									,	imported_symbols= SymbolIndex symbol_n symbol_table.imported_symbols												
									};
								->	define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table rs;

								/* n_value <> 0; external definiton of a .bss symbols */
								# (names_table,symbol_table,rs)
									= case (what_linker False redirect) of {
										False
											# (names_table,rs)
												= insert_symbol_in_symbol_table_new name_of_symbol symbol_n file_n names_table rs;
											| IF_INT_64_OR_32 (n_value bitand 7==0) False
												# characteristics = 0x400003; // align 8
												# symbol_table=
													 {symbol_table & 
														symbols = {symbol_table.symbols & [symbol_n]= Module  0 n_value 0 0 0 "" characteristics},
														bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
													  };
												-> (names_table,symbol_table,rs);
												# symbol_table=
													 {symbol_table & 
														symbols = {symbol_table.symbols & [symbol_n]= Module  0 n_value 0 0 0 "" 3},
														bss_symbols = SymbolIndex symbol_n symbol_table.bss_symbols
													  };
												-> (names_table,symbol_table,rs);
										True
											-> abort ("define_symbols_lp 1: stop" +++ name_of_symbol);
									};
								->	define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table rs;
							
							/* n_scnum <> N_UNDEF, definition of external symbol */
							| (n_numaux==0 || n_type==0x20)
								# (names_table,symbol_table,rs)
									= what_linker (insert_name_and_symbol names_table symbol_table rs)
												  (insert_name_and_symbol_dynamically names_table symbol_table rs);
								-> (define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table) rs;

								# (names_table,symbol_table,rs)
									= case (what_linker False redirect) of {
										False
											# (names_table,rs)
												= insert_symbol_in_symbol_table_new name_of_symbol symbol_n file_n names_table rs;
											# symbol_table
												= new_symbol_table_with_aux n_value symbol_table
											-> (names_table,symbol_table,rs);
										_
											-> abort ("define_symbols_lp 3: stop " +++ name_of_symbol);
									};
								-> (define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table ) rs;
					C_LABEL
						| n_numaux==0
							# names_table1
								= export_internal_label_names name_of_symbol symbol_n file_n names_table;
							-> define_symbols_lp (symbol_n+1+n_numaux) names_table1 (new_symbol_table n_value symbol_table) rs;
							
							-> abort "C_LABEL";
					C_STAT
						# names_table 
							= export_internal_label_names name_of_symbol symbol_n file_n names_table;
						| n_scnum == N_ABS
							-> define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table rs;
							-> if (n_numaux==0 || n_type==0x20)
								(define_symbols_lp (symbol_n+1+n_numaux) names_table (new_symbol_table n_value symbol_table) rs) 
								(define_symbols_lp (symbol_n+1+n_numaux) names_table (new_symbol_table_with_aux n_value symbol_table) rs) ;
							
					C_FUNCTION
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table rs;
					C_FILE
						-> define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table rs;
					
					// handle also superfluous gnu stuff
					_
						-> (define_symbols_lp (symbol_n+1+n_numaux) names_table symbol_table) rs;
				};
			{
				insert_name_and_symbol names_table symbol_table rs
					# (names_table,rs) = insert_symbol_in_symbol_table_new name_of_symbol symbol_n file_n names_table rs;
					# symbol_table = new_symbol_table n_value symbol_table
					= (names_table,symbol_table,rs);

				insert_name_and_symbol_dynamically names_table0 symbol_table0 rs
					= insert_name_and_symbol names_table0 symbol_table0 rs;
				
				new_symbol_table n_value symbol_table0
					# segment_n=sections.[n_scnum].section_segment_n;
					| segment_n <> SK_UNDEF
						= {symbol_table0 & symbols = {symbol_table0.symbols & [symbol_n]=SectionLabel n_scnum n_value} };
						= symbol_table0;

				new_symbol_table_with_aux :: !Int !SymbolTable -> SymbolTable;
				new_symbol_table_with_aux n_value symbol_table0
					# {section_segment_n,section_n_relocations,section_relocations,section_size,section_virtual_address,section_data_offset,section_characteristics}
						= sections.[n_scnum];
					= case section_segment_n of {
						SK_TEXT
							# module_section_size = if (x_scnlen>0) x_scnlen section_size;
							# section_characteristics = (section_characteristics bitand -4) bitor 1;
							= {symbol_table0 &
								symbols = {symbol_table0.symbols & [symbol_n]=Module n_value module_section_size section_virtual_address (file_offset + section_data_offset) section_n_relocations section_relocations section_characteristics},
								text_symbols= SymbolIndex symbol_n symbol_table0.text_symbols,
								section_symbol_ns =  {symbol_table0.section_symbol_ns & [n_scnum]=symbol_n}
						  	};
						SK_DATA
							# module_section_size = if (x_scnlen>0) x_scnlen section_size;
							# section_characteristics = (section_characteristics bitand -4) bitor 2;
							= {symbol_table0 &
								symbols = {symbol_table0.symbols & [symbol_n]=Module n_value module_section_size section_virtual_address (file_offset + section_data_offset) section_n_relocations section_relocations section_characteristics},
								data_symbols= SymbolIndex symbol_n symbol_table0.data_symbols,
								section_symbol_ns = {symbol_table0.section_symbol_ns & [n_scnum]=symbol_n}
					 	  	};
						SK_BSS
							# section_characteristics = section_characteristics bitor 3;
							= {symbol_table0 & 
								symbols = {symbol_table0.symbols & [symbol_n]= Module n_value x_scnlen 0 0 section_n_relocations section_relocations section_characteristics},
								bss_symbols= SymbolIndex symbol_n symbol_table0.bss_symbols,
								section_symbol_ns = {symbol_table0.section_symbol_ns & [n_scnum]=symbol_n}
						  	};
						 SK_USER section_name
							# (extra_section,other_extra_sections)
								= remove_element_from_list (\{es_name} -> es_name == section_name) symbol_table0.extra_sections [];
							# extra_section = { extra_section & es_symbols = SymbolIndex symbol_n extra_section.es_symbols };
							# symbol_table0 
								= {symbol_table0 &
									symbols     ={symbol_table0.symbols & [symbol_n]=Module n_value x_scnlen section_virtual_address (file_offset + section_data_offset) section_n_relocations section_relocations section_characteristics},
									extra_sections = [extra_section:other_extra_sections],
									section_symbol_ns = {symbol_table0.section_symbol_ns & [n_scnum]=symbol_n}
							 	  };					
							= symbol_table0;
							{
								remove_element_from_list p [l:ls] s
									| p l
										= (l,ls);
										= remove_element_from_list p ls [l:s];
							}
						_
							= symbol_table0;
					};
										
				name_of_symbol :: {#Char}; // to help the typechecker
				name_of_symbol
					| first_chars==0
						# string_table_offset = (symbol_table_string ILONG (offset+4))-4;
						= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
						= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
					{}{
						first_chars = symbol_table_string ILONG offset;
						
						first_zero_char_offset_or_max :: !{#Char} !Int !Int -> Int;
						first_zero_char_offset_or_max string offset max
							| offset>=max || string CHAR offset=='\0'
								= offset;
								= first_zero_char_offset_or_max string (offset+1) max;
					}

				x_scnlen=symbol_table_string ILONG last_aux_offset;
				last_aux_offset=offset+SIZE_OF_SYMBOL*n_numaux;
				n_value=symbol_table_string ILONG (offset+8);
				n_scnum=symbol_table_string IWORD (offset+12);				
				n_type=symbol_table_string IWORD (offset+14);
				n_numaux=symbol_table_string BYTE (offset+17);
			}
		{
			offset=SIZE_OF_SYMBOL*symbol_n;
		}
	}

insert_symbol_in_symbol_table_new name_of_symbol symbol_n file_n names_table rs=:{rs_change_rts_label}
	# (s_names_table,names_table) = usize names_table;
	| not rs_change_rts_label
		= (insert_symbol_in_symbol_table name_of_symbol symbol_n file_n names_table,rs);
		# (rs_main_names_table,rs)
			= get_names_table rs;

		# (s_rs_main_names_table,rs_main_names_table) = usize rs_main_names_table;
		| s_rs_main_names_table == 0
			= abort "rs_change_rts_label is True but there is no names table";
		#! (n,rs_main_names_table)
			= find_symbol_in_symbol_table name_of_symbol rs_main_names_table
		= case n of {
			NamesTableElement s symbol_n1 file_n1 _
				#! rs = { rs & rs_main_names_table = rs_main_names_table };
				#! names_table = insert_symbol_in_symbol_table name_of_symbol symbol_n1 file_n1 names_table;
				-> (names_table,rs);
			_
				-> abort "insert_symbol_in_symbol_table_new; no mixed profiling support at the moment; ensure that all dynamics are either compiled with profiling on or off";
		  }
where {
	get_names_table rs=:{rs_main_names_table}
		= (rs_main_names_table,{rs & rs_main_names_table = {}});
}
