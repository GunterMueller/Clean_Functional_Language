implementation module pdWriteState;

// winOS

import ReadWriteState;
import SymbolTable;
import State;
import ExtFile;
import ExtArray;

write_xcoff :: !*Xcoff !*File -> (!*Xcoff,!*File);
write_xcoff xcoff=:{file_name,symbol_table,n_symbols} output
	// write file_name
	#! output
		= fwritei (size file_name) output;
	#! output 
		= fwrites file_name output;

	// write symbol_table
	#! (symbol_table,output)
		= write_symbol_table symbol_table output;
		
	// write n_symbols
	#! output
		= fwritei n_symbols output;
	= ({xcoff & symbol_table = symbol_table},output);
where {
	write_symbol_table symbol_table=:{text_symbols,data_symbols,bss_symbols,imported_symbols,section_symbol_ns,symbols} output
		#! output = output
			THEN write_symbol_index_list text_symbols
			THEN write_symbol_index_list data_symbols
			THEN write_symbol_index_list bss_symbols
			THEN write_symbol_index_list imported_symbols
			;
		#! (section_symbol_ns,output)
			= loopAonOutput fwritei section_symbol_ns output;
		#! (symbols,output)
			= loopAonOutput write_symbol symbols output;
		= ({symbol_table & section_symbol_ns = section_symbol_ns, symbols = symbols},output);
	where {
		write_symbol_index_list sil output
			#! output
				= fwritei (length sil 0) output;
			= write_symbol_index_list sil output;
			where {
				write_symbol_index_list EmptySymbolIndex output
					= output;
				write_symbol_index_list (SymbolIndex symbol_n sil) output
					= write_symbol_index_list sil (fwritei symbol_n output);
				
				length EmptySymbolIndex i		= i;
				length (SymbolIndex _ sil) 	i	= length sil (inc i);	
			} // write_symbol_index_list
		
		write_symbol :: !Symbol !*File -> !*File;
		write_symbol (Module i1 i2 i3 i4 i5 s) output
			#! output = output
				FWC	(toChar MODULE_SYMBOL) 
				FWI i1 
				FWI i2 
				FWI i3 
				FWI i4	
				FWI i5 
				FWI	(size s)
				FWS	s
				;	
			= output;
			
		write_symbol (Label i0 i1 i2) output
			#! output = output
				FWC (toChar LABEL_SYMBOL)
				FWI i0
				FWI i1
				FWI i2
				;
			= output;
			
		write_symbol (SectionLabel i0 i1) output
			#! output = output
				FWC (toChar SECTIONLABEL_SYMBOL)
				FWI i0 
				FWI i1 
				;
			= output;
			
		write_symbol (ImportLabel s) output
			#! output = output
				FWC (toChar IMPORTLABEL_SYMBOL) 
				FWI (size s) 
				FWS s 
				;
			= output;
			
		write_symbol (ImportedLabel i0 i1) output
			#! output = output
				FWC (toChar IMPORTEDLABEL_SYMBOL) 
				FWI i0 
				FWI i1 
				;
			= output;
			
		write_symbol (ImportedLabelPlusOffset i0 i1 i2) output
			#! output = output
				FWC (toChar IMPORTEDLABELPLUSOFFSET_SYMBOL) 
				FWI i0 
				FWI i1 
				FWI i2 
				;
			= output;
			
			write_symbol (ImportedFunctionDescriptor i0 i1) output
			#! output = output
				FWC (toChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL) 
				FWI i0 
				FWI i1 
				;
			= output;
			
			write_symbol (EmptySymbol) output
			#! output = output
				FWC (toChar EMPTYSYMBOL_SYMBOL) 
				;
			= output;		

	}	

}
							
import CommonObjectToDisk;
import LinkerOffsets;
import ExtInt;

import DebugUtilities;

//1.3
instance Target2 !(!*{#Char},!*File)
//3.1
/*2.0
instance Target2 (!*{#Char},!*File)
0.2*/
where {
//1.3
	WriteOutput  :: !*WriteOutputRecord !*(!*{#Char},!*File) -> *(!*State,*(!*{#Char},!*File));
//3.1
	WriteOutput {file_or_memory=write_kind,offset,module_n, string,state,file_n} (data,pe_file)		
		// write to disk or buffer
//		#! aligned_offset
//			= roundup_to_multiple offset 4;
		#! (state,(data,pe_file),module_fp)
			= case write_kind of {
				0
					// .text
/*
					#! delta
						= aligned_offset - offset;
					#! pe_file
						= write_n_bytes delta pe_file;
*/
					// fp offset of module within complement
					#! (module_fp,pe_file)
						= fposition pe_file;
						
					#! pe_file
						= fwrites string pe_file;
						
					
					-> (state,(data,pe_file),module_fp);
				1
					// .data
					#! (s_data,data)
						= usize data;
					#! new_size
						= /*aligned_offset*/ offset + size string;
				
					#! data
						= case (new_size < s_data) of {
							True
								// buffer big enough
								//#! (_,data)
								//	= usize data;
								-> data; //data2;
							False
								// buffer too small
	 							#! new_buffer_size
									= min (roundup_to_multiple new_size next_buffer_size_factor) (s_data + next_buffer_size_factor);
								#! (_,data)
									= copy 0 data 0 (createArray new_buffer_size '\0');
								-> data;
						};
					#! (_,data)
						= copy 0 string /*aligned_offset*/ offset data;
					-> (state,(data,pe_file),/*aligned_offset*/ offset);
				
			};
		
		// update current module symbol
		#! (Module  i1 i2 i3 _ i5 s, state)
			= sel_symbol file_n module_n state;
	
	 	#! state
			= debug_complement 
				(update_symbol (Module  i1 i2 i3 module_fp i5 s) file_n module_n state)
				(state);
				/*
				#! state 
			= ;
				*/
				
				
		= (state,(data,pe_file));
	where {
		copy :: !Int !{#Char} !Int !*{#Char} -> !(!Int,!*{#Char});
		copy i s j d
			| i == size s
				= (j,d);
				= copy (inc i) s (inc j) {d & [j + 0] = s.[i]};
			
		/*
		write_n_bytes :: !Int !*File -> !*File;
		write_n_bytes 0 pe_file
			= pe_file;
		write_n_bytes n pe_file
			= write_n_bytes (dec n) (fwritec '\0' pe_file);
		*/
	}
};

s_initial_buffer		:== 8192;
next_buffer_size_factor :== 4096;

// write raw data of unmarked symbols
write_raw_data :: !*State !*File !*Files -> (!*State,!*File,!*Files);
write_raw_data state=:{n_xcoff_files} output files
	#! s_virtual_data_section
		= s_initial_buffer;
		
	// write text symbols
	#! (((data,output),(text_end,data_end),state),files)
		= write_code_to_pe_files n_xcoff_files False 0 0 (0,0) state True (createArray s_virtual_data_section '\0',output) files;
		
	// update module offset
	#! (begin_data_fp,output)
		= debug_complement (fposition output) (0,output);
	#! (xcoff_a,state)
		= loopAfill (f begin_data_fp)/* dummy: */ (createArray n_xcoff_files 0) state;

	#! output
		= fwrites (data % (0,dec data_end)) output;
	= (state,output,files);	
where {
	f :: !Int !Int !*{#Int} !*State -> *(!*{#Int},*State);
	f begin_data_fp file_n a state
		#! (data_symbols,state)
			= selacc_data_symbols file_n state;
		= (a,loop_on_data_symbols data_symbols state);
	where {
		loop_on_data_symbols EmptySymbolIndex state
			= state;
		loop_on_data_symbols (SymbolIndex module_n sil) state
			#! (Module  i1 i2 i3 offset i5 s,state)
				= sel_symbol file_n module_n state;
			#! state
				= update_symbol (Module  i1 i2 i3 (begin_data_fp + offset) i5 s) file_n module_n state;
			= loop_on_data_symbols sil state;
	}
}