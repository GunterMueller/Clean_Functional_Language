implementation module lib;

// see Archive (Library) File Format in pecoff_v83.docx

import StdEnv;
import ReadObject;
import Redirections;
from ExtFile import ExtractPathAndFile;
from pdSortSymbols import sort_modules;
import LinkerMessages;
import StdMaybe;
import ExtString;
import xcoff;
import pdExtString;

make_even i :== if (isEven i) i (i+1);	

s_archive_signature				:==8;

// Archive member headers
s_archive_header				:== 60;
s_archive_header_name 			:== 16;
s_archive_header_date 			:== 12;
s_archive_header_user_id     	:== 6;
s_archive_header_group_id    	:== 6;
s_archive_header_mode        	:== 8;
s_archive_header_size        	:== 10;
s_archive_header_end_of_header	:== 2;

// Archive member offsets
o_archive_header_size			:== 48;
o_archive_header_name			:== 0;

// Constants
archive_member_header_size 		:== 60;

// Archive member header offsets
archive_member_size				 :== 48;
archive_member_size_length		 :== 10;

pad_field field field_size :== ((field +++ (createArray maximum_s_archive_header_field ' ')) % (0, field_size - 1));

maximum_s_archive_header_field	:== s_archive_header_name;

// First linker member
:: FirstLinkerMember = {
	n_xcoff_symbols :: !Int,
	offsets 		:: !{#Int},
	string_table 	:: !String
};

// Object file member
:: ObjectFileMember = {	
	xcoff_size			:: !Int,
	n_external_symbols	:: !Int,
	external_symbols	:: [(!String,!Int)],
	s_stringtable		:: !Int,
	object_file_offset	:: !Int,
	object_library_name :: !String
};

EmptyObjectFileMember :: ObjectFileMember;
EmptyObjectFileMember 
	= { ObjectFileMember |
		xcoff_size = 0,
		n_external_symbols = 0,
		external_symbols = [],
		s_stringtable = 0,
		object_file_offset = 0,
		object_library_name = ""
	};
	
:: ObjectFileMembers = {
	n_external_symbols 	:: !Int,
	s_stringtable		:: !Int,
	n_xcoff_objects		:: !Int
};

EmptyObjectFileMembers 
	= { ObjectFileMembers |
		n_external_symbols = 0,
		s_stringtable = 0,
		n_xcoff_objects = 0
	};
	
// Creation of archives
CreateArchive :: !String [String] !*Files -> ([String], !Files);
CreateArchive archive_name objects files 
	#! (ok, lib_file, files)
		= fopen archive_name FWriteData files;
	| not ok
		= (["Linker error: could not create '" +++ archive_name +++ "'"],files);
	#! lib_file
		= write_archive_header lib_file;

	#! object_file_members
		= { EmptyObjectFileMembers &
			n_xcoff_objects = length objects
		};
		
	/*
	** The ReadObjectFiles function computes the (relative) file offsets of each object module
	** to be stored in the library.
	*/ 
	#! object_file_offset
		= 0;
	#! (errors,object_file_members,object_file_member_a,longnames_index,longnames_member,files)
		= ReadObjectFiles objects 0 { EmptyObjectFileMember \\ i <- [1..object_file_members.ObjectFileMembers.n_xcoff_objects] } object_file_offset object_file_members 0 "" files;
	| not (isEmpty errors)
		= (errors,files);
		
	/*
	** Compute the size and (file) even offset of the first linker member
	*/
	#! offset_first_linker_member
		= s_archive_signature;
	#! s_first_linker_member
		= s_archive_header + 
			4 + 
			4 * object_file_members.ObjectFileMembers.n_external_symbols +
			object_file_members.ObjectFileMembers.s_stringtable;
			
	/*
	** Compute the (file) even offset and size of the second linker member
	*/
	#! offset_second_linker_member
		= offset_first_linker_member + (make_even s_first_linker_member);
	#! s_second_linker_member
		= s_archive_header +
			4 +
			4 * object_file_members.ObjectFileMembers.n_xcoff_objects +
			4 +
			2 * object_file_members.ObjectFileMembers.n_external_symbols +
			object_file_members.ObjectFileMembers.s_stringtable;
			
	// Compute the (file) even offset and size of the longnames member 
	#! offset_longnames_member
		= offset_second_linker_member + (make_even s_second_linker_member);
	#! s_longnames_member
		= s_archive_header +
			longnames_index;
			
	// Compute the (file) even offset of the start of the object members 
	#! start_offset_of_object_members
		= if (longnames_index == 0)
				offset_longnames_member
				(s_archive_header + offset_longnames_member + (make_even longnames_index));
				
	// The library template has been constructed. Write each linker member at
	// an even file offset
	
	// Write the first linker member
	#! lib_file
		= write_first_linker_member start_offset_of_object_members s_archive_signature (s_first_linker_member - s_archive_header) lib_file object_file_members object_file_member_a;
		
	#! (i,lib_file)
		= fposition lib_file
	| i <> offset_second_linker_member
		= (["Linker error: could not write archive '" +++ archive_name +++ "'"],files);	
		
	// Write the second linker member 
	#! lib_file
		= write_second_linker_member start_offset_of_object_members (s_second_linker_member - s_archive_header) lib_file object_file_members object_file_member_a;
	#! (i,lib_file)
		= fposition lib_file;
	| i <> offset_longnames_member
		= (["Linker error: could not write archive '" +++ archive_name +++ "'"],files);

	// Write longnames linker member
	#! lib_file 
		= write_longnames_member (s_longnames_member - s_archive_header) lib_file longnames_member; 
	#! (i,lib_file)
		= fposition lib_file;
	| i <> start_offset_of_object_members
		= (["Linker error: could not write archive '" +++ archive_name +++ "'"],files);	

	// Write objects
	#! (errors, lib_file, files)
		= write_objects 0 objects lib_file start_offset_of_object_members object_file_member_a files;
	
	#! (_,files)
		= fclose lib_file files;
	
	= ([],files); 
where
{
	write_objects _ [] lib_file _ _ files
		= ([],lib_file,files);
		
	write_objects i [object:objects] lib_file start_offset object_file_member_a files
		#! (errors, lib_file, files)
			= write_object lib_file files;
		| not (isEmpty errors)
			= (errors, lib_file, files);
		= write_objects (inc i) objects lib_file (make_even (start_offset + s_archive_header + object_file_member_a.[i].xcoff_size)) object_file_member_a files;
	where
	{
		write_object lib_file files
			// Write header
			#! lib_file
				= write_archive_member_header object_file_member_a.[i].object_library_name object_file_member_a.[i].xcoff_size lib_file;	
		
			#! (ok, xcoff_file, files)
				= fopen object FReadData files;
			| not ok
				#! (_,files)
					= fclose xcoff_file files;
				= ([],lib_file,files);
	
			#! (xcoff_file,lib_file)
				= copy_file xcoff_file lib_file;
			#! lib_file
				= case (isEven (start_offset + object_file_member_a.[i].xcoff_size) ) of {
					True
						-> lib_file;
					False
						-> fwritec ' ' lib_file;		
				}
				
			#! (lib_file_pos,lib_file)
				= fposition lib_file;
			| lib_file_pos <> (make_even (start_offset + s_archive_header + object_file_member_a.[i].xcoff_size))			
				= (["Linker error: could not write archive '" +++ archive_name +++ "'"],lib_file,files);	

			#! (_,files)
				= fclose xcoff_file files;
			= ([],lib_file,files);
		where
		{
			copy_file xcoff_file lib_file
				#! (xcoff_file_as_string, xcoff_file)
					= freads xcoff_file object_file_member_a.[i].xcoff_size;
				#! lib_file
					= fwrites xcoff_file_as_string lib_file;
				= (xcoff_file,lib_file);
		}
	}		
	
	write_longnames_member member_size lib_file longnames_member
		| member_size == 0
			= lib_file;
			
			#! lib_file
				= write_archive_member_header "//" member_size lib_file;
			#! lib_file
				= fwrites longnames_member lib_file;
			#! lib_file
				= case (isEven member_size) of {
					True
						-> lib_file;
					False
						-> fwritec ' ' lib_file;		
				}
			= lib_file;
		
	write_second_linker_member start_offset member_size lib_file object_file_members object_file_member_a
		#! lib_file
			= write_archive_member_header "/" member_size lib_file;
			
		/*
		** Write second linker member
		*/
		#! lib_file
			= fwritei object_file_members.ObjectFileMembers.n_xcoff_objects lib_file;
		#! lib_file
			= write_object_file_offsets 0 lib_file object_file_member_a;
		#! lib_file
			= fwritei object_file_members.ObjectFileMembers.n_external_symbols lib_file;
			
		#! symbols
			= sortBy (\(s1,i1) (s2,i2) -> (s1 < s2)) (collect_symbols 0 [] object_file_member_a);	
		#! lib_file
			= foldl fwrite_index lib_file symbols;
		#! lib_file
			= foldl fwrite_symbol lib_file symbols;
		#! lib_file
			= case (isEven member_size) of {
				True
					-> lib_file;
				False
					-> fwritec ' ' lib_file;		
			}
		= lib_file;
	where
	{
		write_object_file_offsets i lib_file object_file_member_a
			| i == size object_file_member_a
				= lib_file;
				= write_object_file_offsets (inc i) (fwritei (start_offset + object_file_member_a.[i].object_file_offset) lib_file) object_file_member_a;
				
		fwrite_index lib_file (name,index)
			# index
				= inc index;
			#! lib_file
				= fwritec (toChar index) lib_file;
			#! lib_file
				= fwritec (toChar (index>>8)) lib_file;
			= lib_file;
			
		fwrite_symbol lib_file (name,index)
		 	#! lib_file
		 		= fwrites name lib_file;
		 	#! lib_file
		 		= fwritec '\0' lib_file;
		 	= lib_file;
		 	
		collect_symbols i symbols object_file_member_a
			| i == size object_file_member_a
				= symbols;
				= collect_symbols (inc i) (symbols ++ object_file_member_a.[i].external_symbols) object_file_member_a;
			
	}
		
	write_first_linker_member start_offset lib_file_offset member_size lib_file object_file_members object_file_member_a
		#! lib_file
			= write_archive_member_header "/" member_size lib_file;
		
		/*
		** Write first linker member
		*/
		#! lib_file
			= fwritei_big_endian object_file_members.ObjectFileMembers.n_external_symbols lib_file;
		#! lib_file
			= write_file_offset lib_file 0 object_file_member_a;
		#! lib_file
			= write_string_table lib_file 0 object_file_member_a;
		#! lib_file
			= case (isEven member_size) of {
				True
					-> lib_file;
				False
					-> fwritec ' ' lib_file;		
			}
		= lib_file;
	where
	{
		fwritei_big_endian i lib_file
			#! lib_file
				= fwritec (toChar (i>>24)) lib_file;
			#! lib_file
				= fwritec (toChar (i>>16)) lib_file;
			#! lib_file
				= fwritec (toChar (i>>8)) lib_file;
			#! lib_file
				= fwritec (toChar i) lib_file;
			= lib_file;
		
		/*
		** Write Offsets-array
		*/
		write_file_offset lib_file i object_file_member_a
			| i == size object_file_member_a
				= lib_file;
					
				#! lib_file 
					= write_object_file_member_offsets lib_file object_file_member_a.[i]
				= write_file_offset lib_file (inc i) object_file_member_a;
		where
		{
			write_object_file_member_offsets lib_file {n_external_symbols,object_file_offset}
				= write_offset n_external_symbols lib_file (start_offset + object_file_offset);
			where
			{
				write_offset n_external_symbols lib_file offset
					| n_external_symbols == 0
						= lib_file;
						= write_offset (dec n_external_symbols) (fwritei_big_endian offset lib_file) offset; 
			}
		}
		
		// Write String Table
		write_string_table lib_file i object_file_member_a
			| i == size object_file_member_a
				= lib_file;
					
				#! lib_file
					= write_object_file_member_strings lib_file object_file_member_a.[i]
				= write_string_table lib_file (inc i) object_file_member_a;
		where
		{
			write_object_file_member_strings lib_file {external_symbols}
				= write_symbol external_symbols lib_file;
			where
			{
				write_symbol [] lib_file
					= lib_file;
					
				write_symbol [(s,_):ss] lib_file		
					#! lib_file
						= fwrites s lib_file;
					#! lib_file
						= fwritec '\0' lib_file;
					= write_symbol ss lib_file;
			}
		}
	}

	write_archive_header lib_file
		= fwrites "!<arch>\n" lib_file;
		
	write_archive_member_header name linker_member_size lib_file
		#! lib_file
			= fwrites (pad_field name s_archive_header_name) lib_file;
		#! lib_file
			= fwrites (pad_field "" s_archive_header_date) lib_file;
		#! lib_file
			= fwrites (pad_field "" s_archive_header_user_id) lib_file;
		#! lib_file
			= fwrites (pad_field "" s_archive_header_group_id) lib_file;
		#! lib_file
			= fwrites (pad_field "" s_archive_header_mode) lib_file;
		#! lib_file
			= fwrites (pad_field (toString linker_member_size) s_archive_header_size) lib_file;
		#! lib_file
			= fwrites (pad_field "`\n" s_archive_header_end_of_header) lib_file;
		= (lib_file);
	where
	{
		archive_header_name 
			= createArray s_archive_header_name ' '; 
	}
	
	// Read object files to collect information
	ReadObjectFiles :: ![String] !Int !*{#ObjectFileMember} Int ObjectFileMembers Int {#Char} *Files -> *([{#Char}],ObjectFileMembers,!*{#ObjectFileMember},Int,{#Char},*Files);
	ReadObjectFiles [] i object_file_member_a object_file_offset object_file_members longnames_index longnames_member files
		= ([],object_file_members,object_file_member_a,longnames_index,longnames_member,files);
		
	ReadObjectFiles [object:objects] i object_file_member_a object_file_offset object_file_members longnames_index longnames_member files
		#! (errors,object_file_member,files)
			= ReadObjectFile object i files;
		| not (isEmpty errors)
			= (errors,object_file_members,object_file_member_a,longnames_index,longnames_member,files);
			
			// Compute the longnames member. If an object module has a very long filename,
			// a reference is made to the longnames table which actually stores that name.
			#! (name,longnames_index,longnames_member)
				= object_name_within_library object longnames_index longnames_member;
			
			// A relative (even) offset of the object module within its library to be created,
			// is stored in its object_file_offsets field.
			#! object_file_member
				= { object_file_member &
					object_file_offset = object_file_offset,
					object_library_name = name
				};
				
			// The library format requires an archived object file to start on an even file
			// offset.
			#! object_file_offset
				= object_file_offset + make_even (s_archive_header + object_file_member.xcoff_size); 
			
			#! object_file_members
				= { ObjectFileMembers | object_file_members &
					n_external_symbols = object_file_members.ObjectFileMembers.n_external_symbols + object_file_member.ObjectFileMember.n_external_symbols,
					s_stringtable = object_file_members.ObjectFileMembers.s_stringtable + object_file_member.ObjectFileMember.s_stringtable
				};				
				
			= ReadObjectFiles objects (inc i) {object_file_member_a & [i] = object_file_member} object_file_offset object_file_members longnames_index longnames_member files;
	where
	{
		object_name_within_library object_path longnames_index longnames_member
			#! (_,object_file_name)
				= ExtractPathAndFile object_path;
			= case (size object_file_name < s_archive_header_name) of {
				True
					-> (object_file_name +++ "/", longnames_index, longnames_member); 
				False
					#! object_name_within_library
						= "/" +++ (toString longnames_index);
					-> (object_name_within_library, longnames_index + (size object_file_name) + 1, longnames_member +++ object_file_name +++ "\0");
				};

		ReadObjectFile file_name file_n files
			#! (errors, xcoff_size, n_external_symbols, external_def_symbols, external_ref_symbols, files)
				= read_external_symbol_names_from_xcoff_file file_name files;
			| not (isEmpty errors)
				= (errors,EmptyObjectFileMember,files);
				
			// references to symbols need not be stored.
			#! external_symbols
				= external_def_symbols;
			#! n_external_symbols
				= length external_def_symbols;
				
			#! object_file_member 
				= { EmptyObjectFileMember &
					xcoff_size = xcoff_size,
					n_external_symbols = n_external_symbols,
					external_symbols = [ (external_symbol,file_n) \\ external_symbol <- external_symbols],        //{ external_symbol \\ external_symbol <- external_symbols},
					s_stringtable = foldl (\i s -> i + (size s) + 1) 0 external_symbols
				}
			= ([],object_file_member,files);
	}
}

// Opening archives
OpenArchive :: !String !*Files -> (![String],![String],!Files);
OpenArchive archive_name files
	# (ok, lib_file, files)
		= fopen archive_name FReadData files;
	| not ok
		= Error ["Linker error: could not open archive '" +++ archive_name +++ "'."] lib_file files;
	
	# (errors,lib_file)
		= read_archive_header archive_name lib_file;
	| not (isEmpty errors)
		= Error errors lib_file files
	
	// skip first linker member
	#! (_,s_archive_member,lib_file)
		= read_archive_member_header lib_file "";
	#! (_,lib_file)
		= fseek lib_file (make_even s_archive_member) FSeekCur;
		
	// read member offsets from second linker member
	#! (_,s_archive_member,lib_file)
		= read_archive_member_header lib_file "";
	#! (member_offset_a,lib_file)
		= read_second_linker_member lib_file (make_even s_archive_member)
	
	// read longnamestable
	#! (longnames,lib_file)
		= read_longnames_member lib_file;
		
	#! (member_names,lib_file)
		= read_member_names 0 (size member_offset_a) member_offset_a [] longnames lib_file;
		
	#! (_,files)
		= fclose lib_file files;
		
	= ([],member_names,files);	
where
{
	read_archive_member_header :: !*File !String -> (String,!Int,!*File);
	read_archive_member_header lib_file longnames
		#! (archive_member_header,lib_file)
			= freads lib_file s_archive_header;
		# member_name
			= get_member_name archive_member_header;
		#! s_archive_member
			= toInt (strip_spaces (archive_member_header % (o_archive_header_size,o_archive_header_size + s_archive_header_size - 1)));
		= (member_name,s_archive_member,lib_file);
	where
	{
		get_member_name archive_member_header
			# (_,i)
				= CharIndex name 0 '/';
			| i > 0
				= name % (0,i-1);
				= case name.[1] of {
					'/'
						-> "//";
					' '
						-> "/";
					_
						# i_longnames = toInt (name % (1,size name - 1));
						# (_,i) = CharIndex longnames i_longnames '\0';
						-> longnames % (i_longnames,i-1);
				};
		where {
			name
				= strip_spaces (archive_member_header % (o_archive_header_name,o_archive_header_name + s_archive_header_name));		
		}	
	}
	
	strip_spaces s
	# (ok,i)
		= CharIndex s 0 ' ';
	| not ok
		= s
		= s % (0,i-1);
		
	read_second_linker_member :: !*File !Int -> (*{#Int},!*File);
	read_second_linker_member lib_file size
		#! (_,n_members,lib_file)
			= freadi lib_file;
		#! (member_offsets_a,lib_file)
			= read_second_linker_member_ 0 n_members (createArray n_members 0) lib_file;
		#! (_,lib_file)
			= fseek lib_file (size - 4 - (n_members * 4)) FSeekCur;
		= (member_offsets_a,lib_file);
	where {
		read_second_linker_member_ :: !Int !Int !*{#Int} !*File -> (!*{#Int},!*File);
		read_second_linker_member_ i limit member_offsets_a lib_file 
			| i == limit
				= (member_offsets_a,lib_file);
				# (_,member_offset,lib_file)
					= freadi lib_file;
				= read_second_linker_member_ (inc i) limit {member_offsets_a & [i] = member_offset} lib_file;
	}
	
	// remark: application invalidates assumptions of the file_pointer!
	read_longnames_member lib_file
		#! (member_name,s_archive_member,lib_file)
			= read_archive_member_header lib_file "";
		| member_name <> "//"
			= ("",lib_file);
			= freads lib_file s_archive_member;
			
	read_member_names :: !Int !Int {#Int} ![String] !String !*File -> (![String],!*File);
	read_member_names i limit member_offset_a member_names longnames lib_file
		|  i == limit
			= (member_names,lib_file);
			# (_,lib_file)
				= fseek lib_file member_offset_a.[i] FSeekSet;
			# (member_name,_,lib_file)
				= read_archive_member_header lib_file longnames;
			= read_member_names (inc i) limit member_offset_a (member_names ++ [member_name]) longnames lib_file;

	Error :: [String] !*File !*Files -> ([String],[String],!*Files);
	Error errors lib_file files
		# (_,files)
			= fclose lib_file files;
		= (errors,[],files);

	read_archive_header archive_name lib_file 
		# (signature,lib_file)
			= freads lib_file s_archive_signature;
		| signature == "!<arch>\n"
			= ([],lib_file);
			= (["Linker error: the archive '" +++ archive_name +++ "' is invalid."],lib_file);
}

/*
	OpenLibraryFile and StaticOpenLibraryFile
	
	opens a file as a library and checks if it is a valid library
*/
OpenLibraryFile :: !String !*Files -> (LinkerMessagesState,!Bool,!String,!Bool,!*File,!*Files);
OpenLibraryFile lib_file_name  files  
	#! (ok, lib_file, files)
		= fopen lib_file_name FReadData files;
	| not ok
		= (setLinkerError ("Linker error: could not open library '" +++ lib_file_name +++ "'"),False,"",False,lib_file,files);
	// Check for library header
	#! (arch_file_type,lib_file)
		= freads lib_file s_archive_signature;
	| arch_file_type == "!<arch>\n"
		// Read first linker member, which should be left unused
		#! (size, lib_file)
			= read_archive_member_header_size lib_file;
		#! (ok, lib_file)
			= fseek lib_file (make_even size) FSeekCur;
		= (DefaultLinkerMessages,False, "", False, lib_file, files);
		= (setLinkerError ("Linker error: archive '" +++ lib_file_name +++ "' is corrupt."),False,"", False, lib_file,files);

StaticOpenLibraryFile :: !String !*Files -> ([String],!*File,!*Files);
StaticOpenLibraryFile lib_file_name  files  
	#! (ok, lib_file, files)
		= fopen lib_file_name FReadData files;
	| not ok
		= (["Linker error: could not open archive '" +++ lib_file_name +++ "'."],lib_file,files);
		// Check for library header
		#! (arch_file_type,lib_file)
			= freads lib_file s_archive_signature;
		| arch_file_type == "!<arch>\n"
			// Read first linker member, which should be left unused
			#! (size, lib_file)
				= read_archive_member_header_size lib_file;
			#! (ok, lib_file)
				= fseek lib_file (make_even size) FSeekCur;
			= ([],lib_file, files);
			= (["Linker error: archive '" +++ lib_file_name +++ "' is corrupt."],lib_file,files);

read_archive_member_header_size lib_file
	#! (archive_member_header,lib_file)
		= freads lib_file archive_member_header_size;
	#! member_size
		= (archive_member_header % (archive_member_size, archive_member_size+archive_member_size_length-1));
	= (string_to_int member_size 0 0, lib_file);

string_to_int s i value
	| size s == i || s.[i] == ' '
		= value;
	| isDigit s.[i]
		= string_to_int s (inc i) (value * 10 + (digitToInt s.[i]));
		= abort ("read_archive_member_header: no digit" +++ (toString s.[i]));
		
CloseLibraryFile :: !*File !*Files -> *Files;
CloseLibraryFile lib_file files
	#! (ok,files)
		= fclose lib_file files;
	| not ok
		= files;
		= files;

ReadSecondLinkerMember :: !*File -> (!Int,!{#Int},!Int,!{#Int},!String,!*File);
ReadSecondLinkerMember lib_file
	#! (second_linker_member_size, lib_file)
		= read_archive_member_header_size lib_file;

	// Read Number of Members (=xcoffs)
	#! (_,n_xcoff_files,lib_file)
		= freadi lib_file;
		
	// Read Offsets (of xcoffs)
	#! xcoff_file_offsets 
		= createArray n_xcoff_files 0;
	#! (xcoff_file_offsets, lib_file)
		= read_xcoffs_file_offsets 0 n_xcoff_files xcoff_file_offsets lib_file;
		
	// Read Number of Symbols (in all n_xcoff_files files)
	#! (_,n_xcoff_symbols,lib_file)
		= freadi lib_file;
		
	// Read indices (in xcoff_file_offsets-array)
	#! indices 
		= createArray n_xcoff_symbols 0;
	#! (indices, lib_file)
		= read_indices 0 n_xcoff_symbols indices lib_file;
		
	// Read String Table
	#! second_linker_member_size_without_stringtable
		= 4 + (4 * n_xcoff_files) + 4 + (2 * n_xcoff_symbols);
	#! (string_table,lib_file)
		= freads lib_file (second_linker_member_size - second_linker_member_size_without_stringtable);
			
	// The library format requires each linker member to start on an even
	// address.
	#! (_,_,lib_file)
		= case (isEven second_linker_member_size) of {
			True
				-> (True,' ', lib_file);
			False
				-> freadc lib_file;
		}
		
	= (n_xcoff_files, xcoff_file_offsets, n_xcoff_symbols, indices, string_table, lib_file); 
where {
	read_xcoffs_file_offsets i n_xcoff_files xcoff_file_offsets lib_file
		| n_xcoff_files == i
			= (xcoff_file_offsets, lib_file);
				
			#! (_,offset,lib_file)
				= freadi lib_file;
			= read_xcoffs_file_offsets (inc i) n_xcoff_files { xcoff_file_offsets & [i] = offset + archive_member_header_size} lib_file;
			
	read_indices i n_xcoff_symbols indices lib_file
		| n_xcoff_symbols == i
			= (indices, lib_file);
			
			#! (_, index,lib_file)
				= fread_index lib_file;
			= read_indices (inc i) n_xcoff_symbols { indices & [i] = index } lib_file;
	where {
		fread_index :: !*File -> (!Bool,!Int,!*File);
		fread_index lib_file
			#! (b1,c1,lib_file)
				= freadc lib_file;
			#! (b2,c2,lib_file)
				= freadc lib_file;
			#! value
				= ((toInt c1) + ((toInt c2) << 8));	
			= (b1 && b2,value,lib_file);			
	}
}
	
/*
	read_lib_files
	
	The entire library is loaded and stored in the linker tables i.e. all object modules of the library are loaded
	as regular object modules. After loading its origin can no longer be ascertained.
*/
read_static_lib_files :: [String] [String] !NamesTable !Int [*Xcoff] !*Files !*ReadStaticLibState !RedirectionState -> ([String],[*Xcoff],[String],!NamesTable,!Int,!*Files,!*ReadStaticLibState,!RedirectionState);
read_static_lib_files [] object_names names_table file_n xcoffs files rsl_state rs
	= ([], xcoffs, object_names,  names_table, file_n, files,rsl_state,rs);
read_static_lib_files [lib_file_name:ls] object_names names_table file_n xcoffs files rsl_state rs
	#! (errors, xcoffs, object_names, names_table, file_n, files, rsl_state,rs)
		= read_lib lib_file_name object_names names_table file_n xcoffs files rsl_state rs;
	| not (isEmpty errors)
		= (errors, [], [], names_table, file_n,  files,rsl_state,rs);
	= read_static_lib_files ls object_names names_table file_n xcoffs files rsl_state rs;
where
{
	read_lib lib_file_name object_names names_table file_n xcoffs files rsl_state rs
		#! (errors, lib_file, files)
			= StaticOpenLibraryFile lib_file_name files;
		| not (isEmpty errors)
			= (errors, [], [], names_table, file_n, files,rsl_state,rs);
		# (longnames_member,lib_file)
			= skip_second_linker_member_or_read_longnames_member lib_file;
		// Read headers and object--files
		#! (object_names, lib_file, names_table, file_n, xcoffs, rsl_state,rs)
			= ReadOtherLinkerMembers lib_file_name True lib_file names_table file_n xcoffs longnames_member object_names rsl_state rs;
		# files = CloseLibraryFile lib_file files;
		= ([],xcoffs, object_names, names_table, file_n, files,rsl_state,rs);

	skip_second_linker_member_or_read_longnames_member lib_file
		#! (is_longnames_member, _, archive_member_size, lib_file) = read_archive_member_header lib_file "";
		// second linker member is missing in files created by gnu ar, instead read longnames member
		| is_longnames_member
			# (longnames_member, lib_file) = freads lib_file archive_member_size;
			#! lib_file = if (isEven archive_member_size) lib_file (thd3 (freadc lib_file));
			= (longnames_member,lib_file);
			#! (ok, lib_file) = fseek lib_file (make_even archive_member_size) FSeekCur;
			= ("",lib_file)
}
	
//	determines the type of the archive member to be read. It furthermore returns its name and size	
read_archive_member_header :: !*File !String -> (!Bool,!String,!Int,!*File);
read_archive_member_header lib_file longnames_member
	#! (archive_member_header,lib_file)
		= freads lib_file archive_member_header_size;
	#! member_size = archive_member_header % (archive_member_size, archive_member_size+archive_member_size_length-1);
	#! (is_longnames_member, name)
		= case (archive_member_header % (0,1)) of {
			"//"
				-> (True, "//");
			_
				#! (slash_found, slash_index) = CharIndex archive_member_header 0 '/';
				| not slash_found || size archive_member_header <= 0
					-> abort "read_archive_member_header: lib file corrupt";
				| slash_index==0
					| isDigit archive_member_header.[1]
						#! string_start_position = string_to_int archive_member_header 1 0
						# (_,null_index) = CharIndex longnames_member string_start_position '\0';
						-> (False,longnames_member % (string_start_position,dec null_index));
						-> (False,"/");
					-> (False, archive_member_header % (0, slash_index - 1) );
			}
	= (is_longnames_member, name, string_to_int member_size 0 0, lib_file);

/*
	if read_xcoff_object flag is true, then all object modules contained in the library are read. After reading
	its origin cannot longer be ascertained i.e. an object can come from a library or physical object module on
	disk.
*/
ReadOtherLinkerMembers :: !String !Bool !*File !NamesTable !Int [*Xcoff] !String [String] !*ReadStaticLibState !RedirectionState
										   ->  ([String],!*File,!NamesTable,!Int,[*Xcoff],!*ReadStaticLibState,!RedirectionState);
ReadOtherLinkerMembers lib_file_name read_xcoff_object lib_file names_table file_n xcoffs longnames_member object_names rsl_state rs
	# (eof,lib_file) = fend lib_file;
	| eof
		= (object_names, lib_file, names_table, file_n, xcoffs, rsl_state,rs);
	// Read archive member (both header and object-file)
	#! (is_longnames_member, object_name, sizeq, lib_file)
		= read_archive_member_header lib_file longnames_member;
	| is_longnames_member
		#! (longnames_member, lib_file) = freads lib_file sizeq;
		# lib_file = if (isEven sizeq) lib_file (thd3 (freadc lib_file));
		= ReadOtherLinkerMembers lib_file_name True lib_file names_table file_n xcoffs longnames_member object_names rsl_state rs;
				
		// object member; read object file from library if required
		#! (object_file_offset, lib_file)
			= fposition lib_file;
			
		#! (file_n,xcoff_objects,names_table,lib_file,rsl_state,rs)
			= case (ends object_name ".dll") of {
				True
					// an import library found
					# (lib_file,rsl_state)
						= read_import_library object_name lib_file rsl_state
					-> (file_n,xcoffs,names_table,lib_file,rsl_state,rs);
				_
					-> case read_xcoff_object of {
						True
							#! (any_extra_sections,errors,_,_,xcoff,names_table,lib_file,rs)
								= read_xcoff_fileI object_name lib_file_name object_file_offset names_table True lib_file file_n rs;
							| any_extra_sections
								-> abort "ReadOtherLinkerMembers: extra sections not yet implemented";
							| not errors=:[]
								-> abort ("ReadOtherLinkerMembers: error reading object module "+++object_name+++" in "+++lib_file_name);
							| rs.RedirectionState.rs_change_rts_label
								# rs & rs_change_rts_label = False;
								-> (file_n,xcoffs,names_table,lib_file,rsl_state,rs);
								-> (inc file_n,xcoffs ++ [sort_modules xcoff],names_table,lib_file,rsl_state,rs);
						False
							-> (inc file_n,[],names_table,lib_file,rsl_state,rs);
					}
				};
				
		#! (ok, lib_file)
			= fseek lib_file (make_even (object_file_offset + sizeq)) FSeekSet
		| not ok
			= abort "ReadOtherLinkerMembers: seek not found";
			= ReadOtherLinkerMembers lib_file_name True lib_file names_table /*(inc file_n)*/ file_n xcoff_objects longnames_member (object_names ++ [object_name]) rsl_state rs;

:: *ReadStaticLibState
	= {
		import_libraries	::	[ImportLibrary]
	};

:: ImportLibrary 
	= { 
		il_name		:: !String
	,	il_symbols	:: [String]
	};
	
insert_symbol_name :: !String !String !*ReadStaticLibState -> ReadStaticLibState;
insert_symbol_name symbol_name dll_name rsl_state=:{import_libraries}
	# (opt_import_library,import_libraries_without_opt_library)
		= extract_elem import_libraries (\{il_name} -> il_name == dll_name) []
	# import_libraries
		= case opt_import_library of {
			(Just import_library=:{il_symbols})
				// existing library
				# import_library
					= { import_library &
						il_symbols 		= [symbol_name:il_symbols]
					};
				-> [import_library:import_libraries_without_opt_library];
			_
				// create library
				# import_library
					= { ImportLibrary |
						il_name		= dll_name
					,	il_symbols	= [symbol_name]
					};
				-> [import_library:import_libraries];
		};
		
	// update
	# rsl_state 
		= { rsl_state &
			import_libraries	= import_libraries
		};
	= rsl_state;
	
default_rsl_state :: *ReadStaticLibState;
default_rsl_state
	= { 
		import_libraries	= []
	};
		
extract_elem [] predicate accu
	= (Nothing,accu);
extract_elem [x:xs] predicate accu
	| predicate x
		= (Just x,accu ++ xs);
		= extract_elem xs predicate [x:accu];

s_import_header 				:== 20;

// import header
import_header_sig1				:== 0;
import_header_sig2				:== 2;
import_header_machine			:== 6;
import_header_size_of_data		:== 12;
import_header_type_name_type	:== 18;

// Import Name Type
IMPORT_NAME_ORDINAL				:== 0;
IMPORT_NAME						:== 1;
IMPORT_NAME_NOPREFIX			:== 2;
IMPORT_NAME_UNDECORATE			:== 3;

read_import_library object_name lib_file rsl_state
	# (k,lib_file)
		= fposition lib_file
	# (lib_file,rsl_state)
		= read_import_header k lib_file rsl_state
	= (lib_file,rsl_state) 
where {
	read_import_header k lib_file rsl_state
		# (import_header,lib_file)
			= freads lib_file s_import_header
		| import_header IWORD import_header_sig1 <> IMAGE_FILE_MACHINE_UNKNOWN
			// example debug$S\0; ignore it for the time being
			= (lib_file,rsl_state)

		| import_header IWORD import_header_sig1 == IMAGE_FILE_MACHINE_UNKNOWN && import_header IWORD import_header_sig2 == 0xffff && import_header IWORD import_header_machine == IMAGE_FILE_MACHINE_I386
			# header_type_name_type
				= import_header BYTE (import_header_type_name_type)
				
			# size_of_data
				= import_header ILONG import_header_size_of_data
			# (strings,lib_file)
				= freads lib_file size_of_data

			# (ok,null_index1)
				= CharIndex strings 0 '\0'
			| not ok
				= abort "read_import_header";
			# symbol_name
				= extract_import_name (header_type_name_type >> 2) (strings % (0,dec null_index1))
				
			# (ok,null_index2)
				= CharIndex strings (inc null_index1) '\0'
			| not ok
				= abort "read_import_header";
			# dll_name
				= strings % (inc null_index1,dec null_index2);	
			
			# rsl_state
				= insert_symbol_name symbol_name dll_name rsl_state;
			= (lib_file,rsl_state)
};		

extract_import_name IMPORT_NAME_UNDECORATE symbol_name
	| fst (starts "_" symbol_name)
		# (at_found,at_index)
			= CharIndex symbol_name 0 '@'
			= symbol_name % (1,dec (size symbol_name));
		= abort ("extract_import_name" +++ toString IMPORT_NAME_UNDECORATE);
		
extract_import_name IMPORT_NAME_NOPREFIX symbol_name
	| fst (starts "_" symbol_name)
		= symbol_name % (1,dec (size symbol_name));
