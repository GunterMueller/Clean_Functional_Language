implementation module write_symbol_table;

import StdEnv;
import ExtFile,ExtInt,pdExtInt;
import State,LinkerMessages,NamesTable,pdSymbolTable;

:: MapRecord = {
	offset		:: !Int,
	section_n	:: !Int,
	symbol_name	:: !String
   };

compute_n_symbols_and_string_table_size :: !*State -> (!Int,!Int,!*State);
compute_n_symbols_and_string_table_size state
	# (names_table,state) = acc_namestable (\names_table -> (names_table,{})) state;
	# (n_symbol_records,string_table_size,names_table,state)
		= compute_n_symbols_and_string_table_size 0 0 4 names_table state;
	= (n_symbol_records,string_table_size,{state & namestable = names_table});
where {
	compute_n_symbols_and_string_table_size :: !Int !Int !Int !NamesTable !*State -> *(!Int,!Int,!NamesTable,!*State);
	compute_n_symbols_and_string_table_size i n_symbol_records string_table_size names_table state
		| i==SYMBOL_TABLE_SIZE
			= (n_symbol_records,string_table_size,names_table,state);
			# (names_table_element,names_table) = names_table![i];
			# (n_symbol_records,string_table_size,state)
				= compute_n_symbols_and_string_table_size_of_element names_table_element n_symbol_records string_table_size state;
			= compute_n_symbols_and_string_table_size (i+1) n_symbol_records string_table_size names_table state;

	compute_n_symbols_and_string_table_size_of_element :: !NamesTableElement !Int !Int !*State -> *(!Int,!Int,!*State);
	compute_n_symbols_and_string_table_size_of_element (NamesTableElement symbol_name symbol_n file_n names_table_elements) n_symbol_records string_table_size state
		| file_n < 0
			= compute_n_symbols_and_string_table_size_of_element names_table_elements n_symbol_records string_table_size state;
		| state.marked_bool_a.[state.marked_offset_a.[file_n] + symbol_n]
			# (exe_section_n,state) = section_n_of_marked_label file_n symbol_n state;
			| exe_section_n<>0
				| size symbol_name>8
					# string_table_size = string_table_size+1+size symbol_name;
					= compute_n_symbols_and_string_table_size_of_element names_table_elements (n_symbol_records+1) string_table_size state;
					= compute_n_symbols_and_string_table_size_of_element names_table_elements (n_symbol_records+1) string_table_size state;
				= compute_n_symbols_and_string_table_size_of_element names_table_elements n_symbol_records string_table_size state;
			// in case the module containing the symbol is used, but not the symbol name
			# (symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
			= case symbol of {
				SectionLabel section_n label_offset
					# (section_symbol_n,state) = state!xcoff_a.[file_n].symbol_table.section_symbol_ns.[section_n];
					| section_symbol_n <> -1
						# (module_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[section_symbol_n];
						-> case module_symbol of {
							Module v_module_offset _ _ _ _ _ characteristics
								# exe_section_n = characteristics bitand 3;
								| exe_section_n<>0 && state.marked_bool_a.[state.marked_offset_a.[file_n] + section_symbol_n]
									| size symbol_name>8
										# string_table_size = string_table_size+1+size symbol_name;
										-> compute_n_symbols_and_string_table_size_of_element names_table_elements (n_symbol_records+1) string_table_size state;
										-> compute_n_symbols_and_string_table_size_of_element names_table_elements (n_symbol_records+1) string_table_size state;
									-> compute_n_symbols_and_string_table_size_of_element names_table_elements n_symbol_records string_table_size state;
							_
								-> compute_n_symbols_and_string_table_size_of_element names_table_elements n_symbol_records string_table_size state;
						  };
				_
					-> compute_n_symbols_and_string_table_size_of_element names_table_elements n_symbol_records string_table_size state;
			  };
	compute_n_symbols_and_string_table_size_of_element EmptyNamesTableElement n_symbol_records string_table_size state
		= (n_symbol_records,string_table_size,state);
}

write_symbol_table :: !Int !Int !Int !Int !Int !*State !*File -> (!*State,!*File);
write_symbol_table text_va data_va bss_va n_symbols string_table_size state=:{application_name} exe_file
	# (names_table,state) = acc_namestable (\names_table -> (names_table,{})) state;
	# (symbol_records,names_table,state) = generate_symbol_records [] 0 names_table state;
	# state = {state & namestable = names_table};
	| n_symbols<>length symbol_records
		= abort ("error in write_symbol_table "+++toString n_symbols+++" "+++toString (length symbol_records));

	# (string_table_offset,exe_file) = write_symbols symbol_records text_va data_va bss_va 4 exe_file;
	| string_table_offset<>string_table_size
		= abort ("error in write_symbol_table "+++toString string_table_offset+++" "+++toString string_table_size);

	# exe_file = exe_file <<< string_table_size;
	# exe_file = write_string_table symbol_records exe_file;
/*
	# exe_file = exe_file <<< "symbols: " <<< n_symbol_records <<< "\n";
	# exe_file = exe_file <<< int_hex text_va <<< " .text\n";
	# exe_file = exe_file <<< int_hex data_va <<< " .data\n";
	# exe_file = exe_file <<< int_hex bss_va <<< " .bss\n";
	# exe_file = foldl (write_symbol text_va data_va bss_va) exe_file symbol_records;
*/
	= (state,exe_file);
where {
	generate_symbol_records :: ![MapRecord] !Int !NamesTable !*State -> *(![MapRecord],!NamesTable,!*State);
	generate_symbol_records symbol_records i names_table state
		| i==SYMBOL_TABLE_SIZE
			= (symbol_records,names_table,state);
			# (names_table_element,names_table) = names_table![i];
			# (symbol_records,state) = generate_more_symbol_records names_table_element symbol_records state;
			= generate_symbol_records symbol_records (i+1) names_table state;
	where {
		generate_more_symbol_records :: !NamesTableElement ![MapRecord] !*State -> *(![MapRecord],!*State);
		generate_more_symbol_records EmptyNamesTableElement symbol_records state
			= (symbol_records,state);	
		generate_more_symbol_records (NamesTableElement symbol_name symbol_n file_n names_table_elements) symbol_records state
			| file_n < 0
				= generate_more_symbol_records names_table_elements symbol_records state;
			| state.marked_bool_a.[state.marked_offset_a.[file_n] + symbol_n]
				# (offset,exe_section_n,state) = address_and_section_n_of_marked_label file_n symbol_n state;
				| exe_section_n<>0
					= add_record_and_generate_more_symbol_records symbol_name offset exe_section_n names_table_elements symbol_records state;
					= generate_more_symbol_records names_table_elements symbol_records state;
				// in case the module containing the symbol is used, but not the symbol name
				# (symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				= case symbol of {
					SectionLabel section_n label_offset
						# (section_symbol_n,state) = state!xcoff_a.[file_n].symbol_table.section_symbol_ns.[section_n];
						| section_symbol_n <> -1
							# (module_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[section_symbol_n];
							-> case module_symbol of {
								Module v_module_offset _ _ _ _ _ characteristics
									# exe_section_n = characteristics bitand 3;
									| exe_section_n<>0 && state.marked_bool_a.[state.marked_offset_a.[file_n] + section_symbol_n]
										#! real_module_offset = state.module_offset_a.[state.marked_offset_a.[file_n] + section_symbol_n];
										# module_offset = real_module_offset - v_module_offset;
										  offset = module_offset + (label_offset-v_module_offset);
										-> add_record_and_generate_more_symbol_records symbol_name offset exe_section_n names_table_elements symbol_records state;
										-> generate_more_symbol_records names_table_elements symbol_records state;
								_
									-> generate_more_symbol_records names_table_elements symbol_records state;
							  };
					_
						-> generate_more_symbol_records names_table_elements symbol_records state;
				  };

		add_record_and_generate_more_symbol_records :: !{#Char} !Int !Int !NamesTableElement ![MapRecord] !*State -> *(![MapRecord],!*State);
		add_record_and_generate_more_symbol_records symbol_name offset section_n names_table_elements symbol_records state
			# map_record = {offset = offset, section_n = section_n, symbol_name = symbol_name};
			= generate_more_symbol_records names_table_elements [map_record:symbol_records] state;
	}
}

section_n_of_marked_label :: !Int !Int !*State -> (!Int,!*State);
section_n_of_marked_label file_n symbol_n state
	# (label_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	= case label_symbol of {
		Label _ _ module_n		
			# (module_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[module_n];
			-> case module_symbol of {
				Module _ _ _ _ _ _ characteristics
					-> (characteristics bitand 3,state);
			   };
		Module _ _ _ _ _ _ characteristics
			-> (characteristics bitand 3,state);
	  };

address_and_section_n_of_marked_label :: !Int !Int !*State -> (!Int,!Int,!*State);
address_and_section_n_of_marked_label file_n symbol_n state
	# (label_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	= case label_symbol of {
		Label _ offset module_n		
			# (module_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[module_n];
			-> case module_symbol of {
				Module virtual_label_offset _ _ _ _ _ characteristics
					#! real_module_offset = state.module_offset_a.[state.marked_offset_a.[file_n] + module_n];
					-> (real_module_offset+offset-virtual_label_offset,characteristics bitand 3,state);
			   };
		Module virtual_label_offset _ _ _ _ _ characteristics
			# module_n = symbol_n;
			#! real_module_offset = state.module_offset_a.[state.marked_offset_a.[file_n] + module_n];
			-> (real_module_offset-virtual_label_offset,characteristics bitand 3,state);
	  };
/*
write_symbol text_va data_va bss_va file {symbol_name,offset,section_n}
	| section_n==1
		= file <<< int_hex (offset-text_va) <<< ' ' <<< section_n <<< ' ' <<< symbol_name <<< '\n';
	| section_n==2
		= file <<< int_hex (offset-data_va) <<< ' ' <<< section_n <<< ' ' <<< symbol_name <<< '\n';
	| section_n==3
		= file <<< int_hex (offset-bss_va) <<< ' ' <<< section_n <<< ' ' <<< symbol_name <<< '\n';

hex_char :: !Int -> Char;
hex_char i
	= toChar (48+(7 bitand ((9-i)>>IF_INT_64_OR_32 63 31))+i);

int_hex :: !Int -> String;
int_hex i
	= {hex_char ((i>>((7-n)<<2)) bitand 0xf) \\ n<-[0..7]};
*/

write_symbols [{symbol_name,offset,section_n}:symbols] text_va data_va bss_va string_table_offset file
	# (string_table_offset,file) = write_symbol_name symbol_name string_table_offset file;
	# file = case section_n of {
				1 -> file <<< (offset-text_va);
				2 -> file <<< (offset-data_va);
				3 -> file <<< (offset-text_va);
			   }
	# file = file <<< toChar (section_n) <<< toChar (section_n>>8);
	# file = file <<< '\0'; // IMAGE_SYM_TYPE_NULL
	# file = if (section_n==1)
				(file <<< '\2')  // IMAGE_SYM_DTYPE_FUNCTION
				(file <<< '\0'); // IMAGE_SYM_DTYPE_NULL
	# file = file <<< '\2'; // IMAGE_SYM_CLASS_EXTERNAL
	# file = file <<< '\0'; // NumberOfAuxSymbols
	= write_symbols symbols text_va data_va bss_va string_table_offset file;
{
	write_symbol_name symbol_name string_table_offset file
		| size symbol_name>8
			# file=file <<< 0 <<< string_table_offset;
			= (string_table_offset+1+size symbol_name,file);
			# file=file <<< symbol_name;
			# file=write_n_zeros (8-size symbol_name) file;
			= (string_table_offset,file);

	write_n_zeros n file
		| n>=4
			= write_n_zeros (n-4) (file<<<0);
		| n==0
			= file;
		| n==1
			= file <<< '\0';
		| n==2
			= file <<< "\0\0";
		| n==3
			= file <<< "\0\0\0";
}

write_symbols [] text_va data_va bss_va string_table_offset file
	= (string_table_offset,file);

write_string_table [{symbol_name}:symbols] file
	| size symbol_name<=8
		= write_string_table symbols file;
		= write_string_table symbols (file<<<symbol_name<<<'\0');
write_string_table [] file
	= file;
