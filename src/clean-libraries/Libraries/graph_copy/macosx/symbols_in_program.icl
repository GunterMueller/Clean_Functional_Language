implementation module symbols_in_program;

// for Mach-O for Intel 64-bits

import StdEnv;
import _SystemStrictLists;

:: SectionHeaders = {
	symbol_table_offset :: !Int,
	symbol_table_size :: !Int,
	string_table_section_n :: !Int,
	first_non_local_symbol :: !Int,
	string_table_offset :: !Int,
	string_table_size :: !Int
   };

:: Symbol = { symbol_name :: !String, symbol_value :: !Int};

exported_clean_symbol :: !Int !{#Char} -> Bool;
exported_clean_symbol i s
	| i==0
		= False;
	| s.[i]=='e' && s.[i+1]=='_' && s.[i+2]=='_'
		= True;
	| s.[i]=='_' && s.[i+1]=='_'
		| s.[i+2]=='S' && s.[i+3]=='T' && s.[i+4]=='R' && s.[i+5]=='I' && s.[i+6]=='N' && s.[i+7]=='G' &&
		  s.[i+8]=='_' && s.[i+9]=='_' && s.[i+10]=='\0'
			= True;
		| s.[i+2]=='A' && s.[i+3]=='R' && s.[i+4]=='R' && s.[i+5]=='A' && s.[i+6]=='Y' &&
		  s.[i+7]=='_' && s.[i+8]=='_' && s.[i+9]=='\0'
			= True;
		| s.[i+2]=='C' && s.[i+3]=='o' && s.[i+4]=='n' && s.[i+5]=='s'
			| s.[i+6]=='\0'
				= True;
			| s.[i+6]=='s' || s.[i+6]=='i' || s.[i+6]=='c' || s.[i+6]=='r' || s.[i+6]=='b' || s.[i+6]=='f'
				| s.[i+7]=='\0'
					= True;
				| s.[i+7]=='t' && s.[i+8]=='s' && s.[i+9]=='\0'
					= True;
				= False;
			| s.[i+6]=='a' && s.[i+7]=='\0'
				= True;
			| s.[i+6]=='t' && s.[i+7]=='s' && s.[i+8]=='\0'
				= True;
			= False;
		| s.[i+2]=='N'
			| s.[i+3]=='i' && s.[i+4]=='l' && s.[i+5]=='\0'
				= True;
			| s.[i+3]=='o' && s.[i+4]=='n' && s.[i+5]=='e' && s.[i+6] == '\0'
				= True;
			= False;
		| s.[i+2]=='T' && s.[i+3]=='u' && s.[i+4]=='p' && s.[i+5]=='l' && s.[i+6]=='e' && s.[i+7]=='\0'
			= True;
		| s.[i+2]=='J' && s.[i+3]=='u' && s.[i+4]=='s' && s.[i+5]=='t'
			| s.[i+6]=='\0'
				= True;
			| s.[i+6]=='s' || s.[i+6]=='i' || s.[i+6]=='c' || s.[i+6]=='r' || s.[i+6]=='b' || s.[i+6]=='f' ||
			  s.[i+6]=='a'
				| s.[i+7]=='\0'
					= True;
					= False;
				= False;
			= False;
	| s.[i]=='I' && s.[i+1]=='N' && s.[i+2]=='T' && s.[i+3]=='\0'
		= True;
	| s.[i]=='C' && s.[i+1]=='H' && s.[i+2]=='A' && s.[i+3]=='R' && s.[i+4]=='\0'
		= True;
	| s.[i]=='R' && s.[i+1]=='E' && s.[i+2]=='A' && s.[i+3]=='L' && s.[i+4]=='\0'
		= True;
	| s.[i]=='B' && s.[i+1]=='O' && s.[i+2]=='O' && s.[i+3]=='L' && s.[i+4]=='\0'
		= True;
	| s.[i]=='A' && s.[i+1]=='R' && s.[i+2]=='R' && s.[i+3]=='A' && s.[i+4]=='Y' && s.[i+5]=='\0'
		= True;
	| s.[i]=='n' && s.[i+1]=='_' && s.[i+2]=='_'
		| s.[i+3]=='S' && s.[i+4]=='_' && s.[i+5]=='P' && s.[i+6]>='1' && s.[i+6]<='6' && s.[i+7]=='\0'
			= True;
		| s.[i+3]=='C' && s.[i+4]=='o' && s.[i+5]=='n' && s.[i+6]=='s'
			| s.[i+7]=='s'
				| s.[i+8]=='\0'
					= True;
				| s.[i+8]=='t' && s.[i+9]=='s' && s.[i+10]=='\0'
					= True;
					= False;
			| s.[i+7]=='t' && s.[i+8]=='s' && s.[i+9]=='\0'
				= True;
				= False;
		| s.[i+3]=='J' && s.[i+4]=='u' && s.[i+5]=='s' && s.[i+6]=='t' && s.[i+7]=='s' && s.[i+8]=='\0'
			= True;
			= False;
		= False;

skip_to_null_char i s
	| i<size s && s.[i]<>'\0'
		= skip_to_null_char (i+1) s;
		= i;

string_from_string_table i s
	# e = skip_to_null_char i s;
	= s % (i,e-1);

read_nlist sym nsyms string_table symbols exe_file
	| sym >= nsyms
		= (symbols, exe_file); 
	# (ok, n_strx, exe_file) = freadi exe_file; // This is an union that can hold a n_name pointer in 32-bit version.
	| not ok = abort "No n_strx in nlist.";
	# (ok, n_type, exe_file) = freadc exe_file;
	| not ok = abort "No n_type in nlist.";
	# (ok, n_sec, exe_file) = freadc exe_file;
	| not ok = abort "No n_sec in nlist.";
	# (ok, n_desc1, exe_file) = freadc exe_file;
	| not ok = abort "No _desc in nlist.";
	# (ok, n_desc2, exe_file) = freadc exe_file;
	| not ok = abort "No _desc in nlist.";
	# (ok, n_value1, exe_file) = freadi exe_file;
	| not ok = abort "No _value in nlist.";
	# (ok, n_value2, exe_file) = freadi exe_file;
	| not ok = abort "No _value in nlist.";
	# n_value = (n_value2 << 32) + n_value1; // freadi reads four bytes (see StdInt.dcl) on 64-bits we need 8 bytes.
	| exported_clean_symbol n_strx string_table
		# symbol_name = string_from_string_table n_strx string_table;
		# symbols = [(symbol_name,n_value):symbols];
		= read_nlist (sym + 1) nsyms string_table symbols exe_file;	
	= read_nlist (sym + 1) nsyms string_table symbols exe_file;

read_symbol_table command_offset symbols exe_file
	# (ok, symoff, exe_file) = freadi exe_file;
	| not ok = abort "No symoff in symtab_command.";
	# (ok, nsyms, exe_file) = freadi exe_file;
	| not ok = abort "No nsyms in symtab_command.";
	# (ok, stroff, exe_file) = freadi exe_file;
	| not ok = abort "No stroff in symtab_command.";
	# (ok, strsize, exe_file) = freadi exe_file;
	| not ok = abort "No strsize in symtab_command.";
	# (ok, exe_file) = fseek exe_file stroff FSeekSet;
	| not ok = abort "fseek to string table error";
	# (string_table, exe_file) = freads exe_file strsize;
	| size string_table <> strsize = abort ("Error reading string table");
	# (ok, exe_file) = fseek exe_file symoff FSeekSet;
	| not ok = abort "fseek to symbol table error";
	= read_nlist 0 nsyms string_table symbols exe_file;

LC_SYMTAB :: Int;
LC_SYMTAB = 0x2;

read_load_commands commandnr ncmds command_offset symbols exe_file
	| commandnr >= ncmds
		= (symbols, exe_file)
	# (ok, cmd, exe_file) = freadi exe_file;
	| not ok = abort "No cmd in load_command.";
	# (ok, cmdsize, exe_file) = freadi exe_file;
	| not ok = abort "No cmdsize in load_command";
	# next_command_offset = command_offset + cmdsize;
	# (symbols,exe_file) = if ((cmd bitand 0xFFFFFFFF) == LC_SYMTAB) (read_symbol_table command_offset symbols exe_file) (symbols, exe_file);
	# (ok,exe_file) = fseek exe_file next_command_offset FSeekSet;
	| not ok = abort "fseek error";
	= read_load_commands (commandnr + 1) ncmds next_command_offset symbols exe_file;

MH_MAGIC_64 :: Int;
MH_MAGIC_64 = 0xFEEDFACF;

read_symbols :: !{#Char} !*Files -> (!{#Symbol},!*Files);
read_symbols file_name files
	# (ok,exe_file,files) = fopen file_name FReadData files;
	| not ok
		= abort ("Could not open file "+++file_name);
	# (ok,magic,exe_file) = freadi exe_file
	| not ok || (magic bitand 0xffffffff) <> MH_MAGIC_64
		= abort "Not a Mach-O x64 file (error in header)";
	# header_size = 32; // The sizeof(struct mach_header_64) is 32.
	# (ok,exe_file) = fseek exe_file 16 FSeekSet;
	# (ok,ncmds,exe_file) = freadi exe_file;
	| not ok = abort ("No 'number of load commands' in header.");
	# load_commands_offset = header_size;
	# (ok,exe_file) = fseek exe_file load_commands_offset FSeekSet;
	| not ok
		= abort "fseek failed";
	# (symbols,exe_file)
		= read_load_commands 0 ncmds load_commands_offset [] exe_file;
	# symbols = sortBy (\(s1,_) (s2,_) -> s1<s2) symbols;
	# symbols = {#{symbol_name=s,symbol_value=v} \\ (s,v)<-symbols};
	# (ok,files) = fclose exe_file files;
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

