implementation module WriteMapFile;

import StdEnv;
import ExtFile,ExtInt,pdExtInt;
import State,LinkerMessages,NamesTable,pdSymbolTable;

:: MapRecord = {
		offset		:: !Int,
		symbol_name	:: !String,
		file_name	:: !String
	};

:: ColumnWidths	= {
		symbol_name_column	:: !Int,
		file_name_column	:: !Int
	};

generate_map_file :: !*State !*Files -> (!*State,!*Files);
generate_map_file state=:{application_name,xcoff_a}  files
	// create map file
	#! map_file_name = fst (ExtractPathFileAndExtension application_name) +++ ".map";
	#! (ok,map_file,files)
		= fopen map_file_name FWriteText files;
	| not ok
		# msg = "could not open map file '" +++ map_file_name +++ "'";
		= (AddMessage (LinkerError msg) state,files);
		
	#! map_file = fwrites ("Map file for " +++ application_name +++ "\n\n") map_file;

	// generate map
	#! column_widths = {symbol_name_column = s_symbol_name_column, file_name_column = s_file_name_column};

	#! (names_table,state) = acc_namestable (\names_table -> (names_table,{})) state;
	#! (map_records,column_widths,names_table,state)
		= generate_map_records [] 0 column_widths names_table state;
	#! map_records = sortBy (\{offset=offset1} {offset=offset2} -> offset1 < offset2) map_records;
	#! state = {state & namestable = names_table};

	// write map to disk; calculate max widths of columns
	#! tab_size = 4;
	#! column_widths = {symbol_name_column = roundup_to_multiple column_widths.symbol_name_column tab_size,
						file_name_column = roundup_to_multiple column_widths.file_name_column tab_size };

	// write header
	#! map_file = format "Offset:" max_offset_column_size map_file;
	#! map_file = format symbol_name_column column_widths.symbol_name_column map_file;
	#! map_file = format file_name_column column_widths.file_name_column map_file;
	#! map_file = fwritec '\n' map_file;

	#! map_file = foldl (f column_widths) map_file map_records;
		
	// close map file
	#! (_,files)
		= fclose map_file files;
	= (state,files);
where {
	// constants
	max_offset_column_size	= 14;
	
	// 2nd column
	symbol_name_column		= "Symbol name:";
	s_symbol_name_column	= size symbol_name_column;
	
	// 3th column
	file_name_column		= "File:";
	s_file_name_column		= size file_name_column;
	
	// write table
	f column_witdhs=:{symbol_name_column,file_name_column} map_file {offset,symbol_name,file_name}
		// write offset from base
		#! map_file = format (hex_int offset) max_offset_column_size map_file;

		// write symbol name
		#! map_file = format symbol_name symbol_name_column map_file;

		// write name of defining file
		#! map_file = fwrites file_name map_file;
		#! map_file = fwritec '\n' map_file;
		= map_file;
		
	format s max_s map_file
		#! map_file = fwrites s map_file;
		#! map_file = fwrite_tabs (max_s - size s) map_file;
		= map_file;
	where {
		fwrite_tabs n map_file
			| n == 0
				= map_file;
				= fwrite_tabs (dec n) (fwritec ' ' map_file);
	}

	generate_map_records :: ![MapRecord] !Int !ColumnWidths !NamesTable !*State -> *(![MapRecord],!ColumnWidths,!NamesTable,!*State);
	generate_map_records map_records i column_widths names_table state
		| i == SYMBOL_TABLE_SIZE
			= (map_records,column_widths,names_table,state);
			# (names_table_element,names_table) = names_table![i];
			#! (column_widths,map_records,state) 
				= generate_more_map_records names_table_element column_widths map_records state;
			= generate_map_records map_records (inc i) column_widths names_table state;
	where {
		generate_more_map_records :: !NamesTableElement !ColumnWidths ![MapRecord] !*State -> *(!ColumnWidths,![MapRecord],!*State);
		generate_more_map_records EmptyNamesTableElement column_widths map_records state
			= (column_widths,map_records,state);	
		generate_more_map_records (NamesTableElement symbol_name symbol_n file_n names_table_elements) column_widths map_records state
			| file_n < 0
				= generate_more_map_records names_table_elements column_widths map_records state;
			| state.marked_bool_a.[state.marked_offset_a.[file_n] + symbol_n]
				# (offset,state) = address_of_label2 file_n symbol_n state;
				= add_record_and_generate_more_map_records symbol_name offset file_n names_table_elements column_widths map_records state;
				// in case the module containing the symbol is used, but not the symbol name
				# (symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
				= case symbol of {
					SectionLabel section_n label_offset
						# (section_symbol_n,state) = state!xcoff_a.[file_n].symbol_table.section_symbol_ns.[section_n];
						| section_symbol_n <> -1
							# (module_symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[section_symbol_n];
							-> case module_symbol of {
								Module v_module_offset _ _ _ _ _ _
									| state.marked_bool_a.[state.marked_offset_a.[file_n] + section_symbol_n]
										# (module_offset,state) = address_of_label2 file_n section_symbol_n state;
										  offset = module_offset + (label_offset-v_module_offset);
										-> add_record_and_generate_more_map_records symbol_name offset file_n names_table_elements column_widths map_records state
										-> generate_more_map_records names_table_elements column_widths map_records state;
								_
									-> generate_more_map_records names_table_elements column_widths map_records state;
							  };
					_
						-> generate_more_map_records names_table_elements column_widths map_records state;
				  };

		add_record_and_generate_more_map_records :: !{#Char} !Int !Int !NamesTableElement !ColumnWidths ![MapRecord] !*State -> *(!ColumnWidths,![MapRecord],!*State);
		add_record_and_generate_more_map_records
				symbol_name offset file_n names_table_elements {symbol_name_column,file_name_column} map_records state
			# (file_name,state) = state!xcoff_a.[file_n].Xcoff.file_name;
			  file_name = ExtractFileNameFromPath file_name;
			  map_record = {offset = offset, symbol_name = symbol_name, file_name = file_name};
			  column_widths = {symbol_name_column = max (size symbol_name) symbol_name_column,
								file_name_column = max (size file_name) file_name_column}
			= generate_more_map_records names_table_elements column_widths [map_record:map_records] state;
	}
}
