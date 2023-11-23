implementation module lib

import StdArray, StdBool, StdEnum, StdList, StdMisc, StdOrdList
import StdString

//-- from ReadObject

import StdFile
import UtilIO
import xcoff

:: Section = {
		section_segment_n			::!Int,
		section_virtual_address		::!Int,
		section_size				::!Int,
		section_data_offset			::!Int,
		section_relocations_offset	::!Int,
		section_n_relocations		::!Int,
		section_relocations			::!String
	};

(CHAR) string i :== string.[i];
(BYTE) string i :== toInt (string.[i]);

(IWORD) :: !String !Int -> Int;
(IWORD) string i = (string BYTE (i+1)<<8) bitor (string BYTE i);

(ILONG) :: !String !Int -> Int;
(ILONG) string i
	= (string BYTE (i+3)<<24) bitor (string BYTE (i+2)<<16) bitor (string BYTE (i+1)<<8) bitor (string BYTE i);

read_external_symbol_names_from_xcoff_file :: !String !*Files ->  (![String], !Int, !Int, ![String],![String],!*Files);
read_external_symbol_names_from_xcoff_file file_name files
	#! (ok, xcoff_file, files)
		= fopen file_name FReadData files;
	| not ok
		= error ["could not open " +++ file_name] xcoff_file files;
	
	#! (ok,_,symbol_table_offset,n_symbols,xcoff_file) 
		= read_coff_header xcoff_file;
	#! (ok,symbol_table_string,string_table,xcoff_file) 
		= read_symbol_table 0 symbol_table_offset n_symbols xcoff_file;
	| not ok
		= error ["error reading symboltable or stringtable"] xcoff_file files;

	#! (n_external_symbols, external_def_symbols, external_ref_symbols)
		= extract_external_symbols 0 0 [] [] symbol_table_string string_table;
		
	#! ((ok, xcoff_size),files)
		= FFileSize file_name files;
	| not ok
		= error ["error getting size of " +++ file_name] xcoff_file files;
	
	#! (ok, files)
		= fclose xcoff_file files;
	| not ok
		= (["error closing file " +++ file_name], 0, 0, [], [], files);
		
	= ([], xcoff_size, n_external_symbols, external_def_symbols, external_ref_symbols ,files); 

where
	extract_external_symbols symbol_n n_external_symbols external_def_symbols external_ref_symbols symbol_table_string string_table
		| offset == size symbol_table_string
			= (n_external_symbols, external_def_symbols, external_ref_symbols);
			
			= case (symbol_table_string BYTE (offset+16)) of
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
	where
		offset = SIZE_OF_SYMBOL*symbol_n;
		
						name_of_symbol :: {#Char}; // to help the typechecker
				name_of_symbol
					| first_chars==0
						= string_table % (string_table_offset,dec (first_zero_char_offset_or_max string_table string_table_offset (size string_table)));
						with
							string_table_offset :: Int;
							string_table_offset = (symbol_table_string ILONG (offset+4))-4;
						= symbol_table_string % (offset,dec (first_zero_char_offset_or_max symbol_table_string offset (offset+8)));
					where
						first_chars :: Int;
						first_chars = symbol_table_string ILONG offset;
						
						first_zero_char_offset_or_max string offset max
							| offset>=max || string CHAR offset=='\0'
								= offset;
								= first_zero_char_offset_or_max string (offset+1) max;

				last_aux_offset=offset+SIZE_OF_SYMBOL*n_numaux;
				
				n_value :: Int;
				n_value=symbol_table_string ILONG (offset+8);
				
				n_scnum :: Int;
				n_scnum=symbol_table_string IWORD (offset+12);
				
				n_numaux :: Int;
				n_numaux=symbol_table_string BYTE (offset+17);
	
	error error xcoff_file files
		#! (_,files)
			= fclose xcoff_file files;
		= (error,0,0,[],[],files);

read_symbols :: !Int !*File -> (!Bool,!String,!String,!*File);
read_symbols n_symbols file0
	| not (size symbol_table_string==symbol_table_size)
		= (False,"","",file1);
		= (ok,symbol_table_string,string_table,file2);
		with
			(ok,string_table,file2)=read_string_table file1;
where
		(symbol_table_string,file1)=freads file0 symbol_table_size;
		symbol_table_size=n_symbols*SIZE_OF_SYMBOL;

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
where
		error file=(False,"",file);
		(string_table_string,file2)=freads file1 string_table_size2;
		string_table_size2=string_table_size-4;

		string_table_size=swap_bytes string_table_size0;

		(ok,string_table_size0,file1)=freadi file0;

swap_bytes i :== i;

read_symbol_table :: !Int !Int !Int !*File -> (!Bool,!String,!String,!*File);
read_symbol_table file_offset symbol_table_offset n_symbols file0
	| not fseek_ok
		= error file1;
		= read_symbols n_symbols file1;
where
		(fseek_ok,file1)=fseek file0 (file_offset + symbol_table_offset) FSeekSet;
		error file=(False,"","",file);

read_coff_header :: !*File -> (!Bool,!Int,!Int,!Int,!*File);
read_coff_header file
	#! (header_string,file) 
		= freads file SIZE_OF_HEADER;
	| not (size header_string == SIZE_OF_HEADER && header_string IWORD 0==0x014c /*&& f_nscns >= 2*/)
		= error file;
	
	#! f_nscns 
		= header_string IWORD 2;
	| not (f_nscns >= 2)
		= error file;
	#! f_opthdr
		 = header_string IWORD 16;
	#! f_symptr
		 = header_string ILONG 8;
	#! f_nsyms
		= header_string ILONG 12;
	| f_opthdr == 0
		= (True,f_nscns,f_symptr,f_nsyms,file);

	#! (fseek_ok,file2)
		= fseek file f_opthdr FSeekCur;
	| fseek_ok
		= (True,f_nscns,f_symptr,f_nsyms,file2);
	= (error file2);
where
		error file = (False,0,0,0,file);

//-- from ExtFile(pcExtFile)

ExtractPathAndFile :: !String -> (!String,!String);
ExtractPathAndFile path_and_file 
	#! (dir_delimiter_found,i)
		= CharIndexBackwards path_and_file (size path_and_file - 1) '\\';
	| dir_delimiter_found
		= (path_and_file % (0,i-1),path_and_file % (i+1,size path_and_file - 1));
		= ("",path_and_file);

CharIndexBackwards :: !String !Int !Char -> (!Bool,!Int);
CharIndexBackwards s i char
	| i == (-1)
		= (False,size s);
		
		| s.[i] == char
			= (True,i);
			= CharIndexBackwards s (dec i) char;
			
//-- from ExtString

CharIndex  :: !String !Int !Char -> (!Bool,!Int); 
CharIndex s i char
	| i == (size s)
		= (False,size s);
		
		| i < (size s)
			| s.[i] == char
				= (True,i);
				= CharIndex s (inc i) char;
			= abort "CharIndex: index out of range";

//--
		
make_even i :== if (isEven i) i (i+1)


s_archive_signature				:==8

/*
** Archive member headers
*/
s_archive_header				:== 60
s_archive_header_name 			:== 16
s_archive_header_date 			:== 12
s_archive_header_user_id     	:== 6
s_archive_header_group_id    	:== 6
s_archive_header_mode        	:== 8
s_archive_header_size        	:== 10
s_archive_header_end_of_header	:== 2

/*
** Archive member offsets
*/
o_archive_header_size			:== 48
o_archive_header_name			:== 0

pad_field field field_size :== ((field +++ (createArray maximum_s_archive_header_field ' ')) % (0, field_size - 1))

maximum_s_archive_header_field	:== s_archive_header_name

/*
** First linker member
*/
:: FirstLinkerMember = {
	n_xcoff_symbols :: !Int,
	offsets 		:: !{#Int},
	string_table 	:: !String
	}

/*
** Object file member
*/
:: ObjectFileMember = {	
	xcoff_size			:: !Int,
	n_external_symbols	:: !Int,
	external_symbols	:: [(!String,!Int)],
	s_stringtable		:: !Int,
	object_file_offset	:: !Int,
	object_library_name :: !String
	}

EmptyObjectFileMember 
	= { ObjectFileMember |
		xcoff_size = 0,
		n_external_symbols = 0,
		external_symbols = [],
		s_stringtable = 0,
		object_file_offset = 0,
		object_library_name = ""
	}
	
:: ObjectFileMembers = {
	n_external_symbols 	:: !Int,
	s_stringtable		:: !Int,
	n_xcoff_objects		:: !Int
	}

EmptyObjectFileMembers 
	= { ObjectFileMembers |
		n_external_symbols = 0,
		s_stringtable = 0,
		n_xcoff_objects = 0
	}

ReadObjectFile file_name file_n files
	#! (errors, xcoff_size, n_external_symbols, external_def_symbols, external_ref_symbols, files)
		= read_external_symbol_names_from_xcoff_file file_name files
	| not (isEmpty errors)
		= (errors,EmptyObjectFileMember,files)
		
	#! external_symbols
		= external_def_symbols ++ external_ref_symbols
	#! object_file_member 
		= { EmptyObjectFileMember &
			xcoff_size = xcoff_size,
			n_external_symbols = n_external_symbols,
			external_symbols = [ (external_symbol,file_n) \\ external_symbol <- external_symbols],        //{ external_symbol \\ external_symbol <- external_symbols},
			s_stringtable = foldl (\i s -> i + (size s) + 1) 0 external_symbols
		}
	= ([],object_file_member,files)

ReadObjectFiles :: ![String] !Int !*{# ObjectFileMember} !Int !ObjectFileMembers !Int !String !*Files -> *(![String],ObjectFileMembers,{#ObjectFileMember},Int,String,!*Files)
ReadObjectFiles [] i object_file_member_a object_file_offset object_file_members longnames_index longnames_member files
	= ([],object_file_members,object_file_member_a,longnames_index,longnames_member,files)
	
ReadObjectFiles [object:objects] i object_file_member_a object_file_offset object_file_members longnames_index longnames_member files
	#! (errors,object_file_member,files)
		= ReadObjectFile object i files
	| not (isEmpty errors)
		= (errors,object_file_members,object_file_member_a,longnames_index,longnames_member,files)
		
		/*
		** Compute the longnames member. If an object module has a very long filename,
		** a reference is made to the longnames table which actually stores that name.
		*/
		#! (name,longnames_index,longnames_member)
			= object_name_within_library object longnames_index longnames_member
		
		/*
		** A relative (even) offset of the object module within its library to be created,
		** is stored in its object_file_offsets field.
		*/
		#! object_file_member
			= { object_file_member &
				object_file_offset = object_file_offset,
				object_library_name = name
			}
			
		/*
		** The library format requires an archived object file to start on an even file
		** offset.
		*/
		#! object_file_offset
			= object_file_offset + make_even (s_archive_header + object_file_member.xcoff_size) 
		
		#! object_file_members
			= { ObjectFileMembers | object_file_members &
				n_external_symbols = object_file_members.ObjectFileMembers.n_external_symbols + object_file_member.ObjectFileMember.n_external_symbols,
				s_stringtable = object_file_members.ObjectFileMembers.s_stringtable + object_file_member.ObjectFileMember.s_stringtable
			}				
			
		= ReadObjectFiles objects (inc i) {object_file_member_a & [i] = object_file_member} object_file_offset object_file_members longnames_index longnames_member files
where
	object_name_within_library :: !String !Int !String -> (!String,!Int,!String)
	object_name_within_library object_path longnames_index longnames_member
		#! (_,object_file_name)
			= ExtractPathAndFile object_path
		= case (size object_file_name < s_archive_header_name) of
			True
				-> (object_file_name +++ "/", longnames_index, longnames_member) 
			False
				#! object_name_within_library
					= "/" +++ (toString longnames_index)
				-> (object_name_within_library, longnames_index + (size object_file_name) + 1, longnames_member +++ object_file_name +++ "\0")

		
CreateArchive :: !String ![String] !*Files -> (![String], !Files)
CreateArchive archive_name objects files  
	#! (ok, lib_file, files)
		= fopen archive_name FWriteData files
	| not ok
		= (["could not create " +++ archive_name],files)
	#! lib_file
		= write_archive_header lib_file

	#! object_file_members
		= { EmptyObjectFileMembers &
			n_xcoff_objects = length objects
		}
		
	/*
	** The ReadObjectFiles function computes the (relative) file offsets of each object module
	** to be stored in the library.
	*/ 
	#! object_file_offset
		= 0
	#! (errors,object_file_members,object_file_member_a,longnames_index,longnames_member,files)
		= ReadObjectFiles objects 0 { EmptyObjectFileMember \\ i <- [1..object_file_members.ObjectFileMembers.n_xcoff_objects] } object_file_offset object_file_members 0 "" files
	| not (isEmpty errors)
		#! (_,files)
			= fclose lib_file files
		= (errors,files)
		
	/*
	** Compute the size and (file) even offset of the first linker member
	*/
	#! offset_first_linker_member
		= s_archive_signature 
	#! s_first_linker_member
		= s_archive_header + 
			4 + 
			4 * object_file_members.ObjectFileMembers.n_external_symbols +
			object_file_members.ObjectFileMembers.s_stringtable
			
	/*
	** Compute the (file) even offset and size of the second linker member
	*/
	#! offset_second_linker_member
		= offset_first_linker_member + (make_even s_first_linker_member)
	#! s_second_linker_member
		= s_archive_header +
			4 +
			4 * object_file_members.ObjectFileMembers.n_xcoff_objects +
			4 +
			2 * object_file_members.ObjectFileMembers.n_external_symbols +
			object_file_members.ObjectFileMembers.s_stringtable
			
	/*
	** Compute the (file) even offset and size of the longnames member 
	*/
	#! offset_longnames_member
		= offset_second_linker_member + (make_even s_second_linker_member)
	#! s_longnames_member
		= s_archive_header +
			longnames_index
			
	/*
	** Compute the (file) even offset of the start of the object members 
	*/
	#! start_offset_of_object_members
		= if (longnames_index == 0)
				offset_longnames_member
				(s_archive_header + offset_longnames_member + (make_even longnames_index))
				
	/*
	** The library template has been constructed. Write each linker member at
	** an even file offset
	*/
	
	
	/*
	** Write the first linker member
	*/
	#! lib_file
		= write_first_linker_member start_offset_of_object_members s_archive_signature (s_first_linker_member - s_archive_header) lib_file object_file_members object_file_member_a
		
	#! (i,lib_file)
		= fposition lib_file
	| i <> offset_second_linker_member
		#! (_,files)
			= fclose lib_file files
		= sabort "(internal error): 1ste linker member, library file out of sync with template" files
		
	/*
	** Write the second linker member 
	*/
	#! lib_file
		= write_second_linker_member start_offset_of_object_members (s_second_linker_member - s_archive_header) lib_file object_file_members object_file_member_a
	#! (i,lib_file)
		= fposition lib_file
	| i <> offset_longnames_member
		#! (_,files)
			= fclose lib_file files
		= sabort "(internal error): 2nd linker member, library file out of sync with template" files
		
	/*
	** Write longnames linker member
	*/
	#! lib_file 
		= write_longnames_member (s_longnames_member - s_archive_header) lib_file longnames_member 
	#! (i,lib_file)
		= fposition lib_file
	| i <> start_offset_of_object_members
		#! (_,files)
			= fclose lib_file files
		= sabort "(internal error): longnames linker member, library file out of sync with template" files
	
	/*
	** Write objects
	*/
	#! (errors, lib_file, files)
		= write_objects 0 objects lib_file start_offset_of_object_members object_file_member_a files
	
	#! (_,files)
		= fclose lib_file files
	
	= (errors,files)
	
	// Aanpassen van object member offsets m.b.v.  start_offset!!!!!!!!!!
where
//	write_objects :: !Int ![] !*File !Int ... !*Files -> (![String],!*File,!*Files)
	write_objects _ [] lib_file _ _ files
		= ([],lib_file,files)
		
	write_objects i [object:objects] lib_file start_offset object_file_member_a files
		#! (errors, lib_file, files)
			= write_object lib_file files
		| not (isEmpty errors)
			= (errors, lib_file, files)
		= write_objects (inc i) objects lib_file (make_even (start_offset + s_archive_header + object_file_member_a.[i].xcoff_size)) object_file_member_a files
	where
		write_object :: !*File !*Files -> *(![String],!*File,!*Files)
		write_object lib_file files
			/*
			** Write header
			*/
			#! lib_file
				= write_archive_member_header object_file_member_a.[i].object_library_name object_file_member_a.[i].xcoff_size lib_file	
		
			#! (ok, xcoff_file, files)
				= fopen object FReadData files
			| not ok
				#! (_,files)
					= fclose xcoff_file files
				= (["could not open " +++ object],lib_file,files)
	
			#! (xcoff_file,lib_file)
				= copy_file xcoff_file lib_file
			#! lib_file
				= case (isEven (start_offset + object_file_member_a.[i].xcoff_size) ) of
					True
						-> lib_file
					False
						-> fwritec ' ' lib_file		
				
			#! (lib_file_pos,lib_file)
				= fposition lib_file
			| lib_file_pos <> (make_even (start_offset + s_archive_header + object_file_member_a.[i].xcoff_size))
				= abort ("write_object:  error in file offset calculation. "
					+++ (toString lib_file_pos) +++ " - " +++ (toString (start_offset + s_archive_header + object_file_member_a.[i].xcoff_size)) )
				
			//| i == (start_offset + make_even (object_file_member_a.[i].xcoff_size))
			//	= abort "nee"
				
			#! (ok,files)
				= fclose xcoff_file files
			| not ok
				= (["could not close " +++ object],lib_file,files)
			= ([],lib_file,files)
		where
			copy_file xcoff_file lib_file
				#! (xcoff_file_as_string, xcoff_file)
					= freads xcoff_file object_file_member_a.[i].xcoff_size
				#! lib_file
					= fwrites xcoff_file_as_string lib_file
				= (xcoff_file,lib_file)

	write_longnames_member member_size lib_file longnames_member
		| member_size == 0
			= lib_file
			
			#! lib_file
				= write_archive_member_header "//" member_size lib_file
			#! lib_file
				= fwrites longnames_member lib_file
			#! lib_file
				= case (isEven member_size) of
					True
						-> lib_file
					False
						-> fwritec ' ' lib_file		
			= lib_file
		
	write_second_linker_member start_offset member_size lib_file object_file_members object_file_member_a
		#! lib_file
			= write_archive_member_header "/" member_size lib_file
			
		/*
		** Write second linker member
		*/
		#! lib_file
			= fwritei object_file_members.ObjectFileMembers.n_xcoff_objects lib_file
		#! lib_file
			= write_object_file_offsets 0 lib_file object_file_member_a
		#! lib_file
			= fwritei object_file_members.ObjectFileMembers.n_external_symbols lib_file
			
		#! symbols
			= sortBy (\(s1,i1) (s2,i2) -> (s1 < s2)) (collect_symbols 0 [] object_file_member_a)	
		#! lib_file
			= foldl fwrite_index lib_file symbols
		#! lib_file
			= foldl fwrite_symbol lib_file symbols
		#! lib_file
			= case (isEven member_size) of
				True
					-> lib_file
				False
					-> fwritec ' ' lib_file		
		= lib_file
	where
		write_object_file_offsets i lib_file object_file_member_a
			| i == size object_file_member_a
				= lib_file
				= write_object_file_offsets (inc i) (fwritei (start_offset + object_file_member_a.[i].object_file_offset) lib_file) object_file_member_a
				
		fwrite_index lib_file (name,index)
			#! lib_file
				= fwritec (toChar index) lib_file
			#! lib_file
				= fwritec (toChar (index>>8)) lib_file
			= lib_file
			
		fwrite_symbol lib_file (name,index)
		 	#! lib_file
		 		= fwrites name lib_file
		 	#! lib_file
		 		= fwritec '\0' lib_file
		 	= lib_file
		 	
		collect_symbols i symbols object_file_member_a
			| i == size object_file_member_a
				= symbols
				= collect_symbols (inc i) (symbols ++ object_file_member_a.[i].external_symbols) object_file_member_a
			
		
	

	write_first_linker_member start_offset lib_file_offset member_size lib_file object_file_members object_file_member_a
		#! lib_file
			= write_archive_member_header "/" member_size lib_file
		
		/*
		** Write first linker member
		*/
		#! lib_file
			= fwritei_big_endian object_file_members.ObjectFileMembers.n_external_symbols lib_file
		#! lib_file
			= write_file_offset lib_file 0 object_file_member_a
		#! lib_file
			= write_string_table lib_file 0 object_file_member_a
		#! lib_file
			= case (isEven member_size) of
				True
					-> lib_file
				False
					-> fwritec ' ' lib_file		
		= lib_file
	where
		fwritei_big_endian i lib_file
			#! lib_file
				= fwritec (toChar (i>>24)) lib_file
			#! lib_file
				= fwritec (toChar (i>>16)) lib_file
			#! lib_file
				= fwritec (toChar (i>>8)) lib_file
			#! lib_file
				= fwritec (toChar i) lib_file
			= lib_file
		
		/*
		** Write Offsets-array
		*/
		write_file_offset lib_file i object_file_member_a
			| i == size object_file_member_a
				= lib_file
					
				#! lib_file 
					= write_object_file_member_offsets lib_file object_file_member_a.[i]
				= write_file_offset lib_file (inc i) object_file_member_a
		where
			write_object_file_member_offsets lib_file {n_external_symbols,object_file_offset}
				= write_offset n_external_symbols lib_file (start_offset + object_file_offset)
			where
				write_offset n_external_symbols lib_file offset
					| n_external_symbols == 0
						= lib_file
						= write_offset (dec n_external_symbols) (fwritei_big_endian offset lib_file) offset 
		
		/*
		** Write String Table
		*/	
		write_string_table lib_file i object_file_member_a
			| i == size object_file_member_a
				= lib_file
					
				#! lib_file
					= write_object_file_member_strings lib_file object_file_member_a.[i]
				= write_string_table lib_file (inc i) object_file_member_a
		where
			write_object_file_member_strings lib_file {external_symbols}
				= write_symbol external_symbols lib_file
			where
				write_symbol [] lib_file
					= lib_file
					
				write_symbol [(s,_):ss] lib_file		
					#! lib_file
						= fwrites s lib_file
					#! lib_file
						= fwritec '\0' lib_file
					= write_symbol ss lib_file
		
		
	/* write_first_linker_member */

	write_archive_header lib_file
		= fwrites "!<arch>\n" lib_file
		
	write_archive_member_header name linker_member_size lib_file
		#! lib_file
			= fwrites (pad_field name s_archive_header_name) lib_file
		#! lib_file
			= fwrites (pad_field "" s_archive_header_date) lib_file
		#! lib_file
			= fwrites (pad_field "" s_archive_header_user_id) lib_file
		#! lib_file
			= fwrites (pad_field "" s_archive_header_group_id) lib_file
		#! lib_file
			= fwrites (pad_field "" s_archive_header_mode) lib_file
		#! lib_file
			= fwrites (pad_field (toString linker_member_size) s_archive_header_size) lib_file
		#! lib_file
			= fwrites (pad_field "`\n" s_archive_header_end_of_header) lib_file
		= (lib_file)						
/*		
	where
		archive_header_name 
			= createArray s_archive_header_name ' ' 
*/
// Read a .lib
read_archive_header archive_name lib_file 
	# (signature,lib_file)
		= freads lib_file s_archive_signature
	| signature == "!<arch>\n"
		= ([],lib_file)
		
		= (["File '" +++ archive_name +++ "' is not a valid library file"],lib_file)
		
OpenArchive :: !String !*Files -> (![String],![String],!Files)
OpenArchive archive_name files
	# (ok, lib_file, files)
		= fopen archive_name FReadData files
	| not ok
		= Error ["could not open " +++ archive_name] lib_file files
	
	# (errors,lib_file)
		= read_archive_header archive_name lib_file
	| not (isEmpty errors)
		= Error errors lib_file files
	
	
	// skip first linker member
	#! (_,s_archive_member,lib_file)
		= read_archive_member_header lib_file ""
	#! (_,lib_file)
		= fseek lib_file (make_even s_archive_member) FSeekCur
		
	// read member offsets from second linker member
	#! (_,s_archive_member,lib_file)
		= read_archive_member_header lib_file ""
	#! (member_offset_a,lib_file) 
		= read_second_linker_member lib_file (make_even s_archive_member)
	
	// read longnamestable
	#! (longnames,lib_file)
		= read_longnames_member lib_file
		
	#! (member_names,lib_file)
		= read_member_names 0 (size member_offset_a) member_offset_a [] longnames lib_file
		
	#! (_,files)
		= fclose lib_file files
		
	= ([],member_names,files)
where
	read_archive_member_header :: !*File !String -> (String,!Int,!*File)
	read_archive_member_header lib_file longnames
		#! (archive_member_header,lib_file)
			= freads lib_file s_archive_header
		# member_name
			= get_member_name archive_member_header
		#! s_archive_member
			= toInt (strip_spaces (archive_member_header % (o_archive_header_size,o_archive_header_size + s_archive_header_size - 1)))
		= (member_name,s_archive_member,lib_file)
	where
		get_member_name archive_member_header
			# (_,i)
				= CharIndex name 0 '/'
			| i > 0
				= name % (0,i-1)
			
				= case name.[1] of
					'/'
						-> "//"
					' '
						-> "/"
					_
						# i_longnames
							= toInt (name % (1,size name - 1))
						# (_,i)
							= CharIndex longnames i_longnames '\0'
						-> longnames % (i_longnames,i-1)
						
		where
			name
				= strip_spaces (archive_member_header % (o_archive_header_name,o_archive_header_name + s_archive_header_name))		
	
	strip_spaces s
	# (ok,i)
		= CharIndex s 0 ' '
	| not ok
		= s
		= s % (0,i-1)
		
		
	read_second_linker_member :: !*File !Int -> (*{#Int},!*File)
	read_second_linker_member lib_file size
		#! (_,n_members,lib_file)
			= freadi lib_file
		#! (member_offsets_a,lib_file)
			= read_second_linker_member_ 0 n_members (createArray n_members 0) lib_file
		#! (_,lib_file)
			= fseek lib_file (size - 4 - (n_members * 4)) FSeekCur
		= (member_offsets_a,lib_file)
	where
		read_second_linker_member_ :: !Int !Int !*{#Int} !*File -> (!*{#Int},!*File)
		read_second_linker_member_ i limit member_offsets_a lib_file 
			| i == limit
				= (member_offsets_a,lib_file)
				
				# (_,member_offset,lib_file)
					= freadi lib_file
				= read_second_linker_member_ (inc i) limit {member_offsets_a & [i] = member_offset} lib_file
	
	
	// remark: application invalidates assumptions of the file_pointer!
	read_longnames_member lib_file
		#! (member_name,s_archive_member,lib_file)
			= read_archive_member_header lib_file ""
		| member_name <> "//"
			= ("",lib_file)
			
			= freads lib_file s_archive_member
			
	read_member_names :: !Int !Int {#Int} ![String] !String !*File -> (![String],!*File)
	read_member_names i limit member_offset_a member_names longnames lib_file
		|  i == limit
			= (member_names,lib_file)
			
			# (_,lib_file)
				= fseek lib_file member_offset_a.[i] FSeekSet
			# (member_name,_,lib_file)
				= read_archive_member_header lib_file longnames
			= read_member_names (inc i) limit member_offset_a (member_names ++ [member_name]) longnames lib_file
			
		
	Error :: ![String] !*File !*Files -> (![String],![String],!*Files)
	Error errors lib_file files
		# (_,files)
			= fclose lib_file files
		= (errors,[],files)

/*
** Constants
*/
archive_member_header_size :== 60

/*
** Archive member header offsets
*/
archive_member_size :== 48
archive_member_size_length :== 10

sabort :: !String !.a -> .b
sabort s _ = abort s;

getExternalNames :: .{#Char} *Files -> *(.([{#Char}],[{#Char}],[{#Char}]),*Files);
getExternalNames file files
	# (msg,_,_,symsdef,symsref,files) = read_external_symbol_names_from_xcoff_file file files
	= ((msg,symsdef,symsref),files)

