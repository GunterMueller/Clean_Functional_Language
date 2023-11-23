implementation module CommonObjectToDisk;

import StdEnv;	
import xcoff;
from Relocations import relocate_text;
import State;
import PlatformLinkOptions;
import utilities;
import RWSDebugChoice;
import ExtInt;
from ExtList import splitAtPred;
import link_switches;
import pdExtInt;
import pdExtString;
import pdSymbolTable;

USE_FREADSTRING use_freadstring normal :== normal;

:: *WriteOutputRecord = {
		file_or_memory	:: !Int
	,	offset			:: !Int
	,	aligned_offset	:: !Int
	,	string			:: !{#Char}
	,	state			:: !*State
	};

class Target2 a
where
{
	WriteOutput :: !WriteOutputRecord !*a -> (!*State,*a)
};

:: *WriteState = {
		do_relocations	:: !Bool
	,	buffers			:: !*{*{#Char}}
	,	buffers_i		:: !*{#Int}
	,	text_offset		:: !Int
	,	text_buffer		:: !*{#Char}
	};
	
DefaultWriteState :: *WriteState;
DefaultWriteState
	= { WriteState |
		do_relocations	= True
	,	buffers			= {}
	,	buffers_i		= {}
	,	text_offset		= 0
	,	text_buffer		= {}
	};
		
WriteCode :: !*File !*PlatformLinkOptions !*State !*Files -> (!*File,!*PlatformLinkOptions,!*State,!*Files,!*WriteState);
WriteCode pe_file platform_link_options state=:{n_xcoff_files} files
	#! ws = DefaultWriteState;
		
	// Create buffers
	#! (buffers,buffers_i,platform_link_options)
		= create_buffers platform_link_options;
	#! ws = { ws & buffers = buffers, buffers_i	= buffers_i };
				
	#! (ws,pe_file,state,files)
		= write_code 0 0 ws pe_file state files;
		
	= (pe_file,platform_link_options,state,files,ws);
where {
	write_code :: !Int !Int !*WriteState !*File !*State !*Files -> *(!*WriteState,!*File,!*State,!*Files);
	write_code file_n first_symbol_n ws pe_file state files
		| file_n >= n_xcoff_files
			= (ws,pe_file,state,files);
	
		// open xcoff file
		#! (file_name, state)
			= select_file_name file_n state;
		#! (n_symbols, state)
			= select_n_symbols file_n state;
		#! (ok,xcoff_file,files)	
			= fopen file_name FReadData files;
		| not ok
			= abort ("Cannot read file: "+++ file_name);
			
		#! (ws,pe_file,state,xcoff_file,file_n,first_symbol_n)
			= write_optimized ws pe_file state xcoff_file file_n first_symbol_n file_name;
		
		// close xcoff file
		#! (ok,files) 				
			= fclose xcoff_file files;
		| not ok
			= abort ("Error while reading file: "+++file_name);
		= write_code (inc file_n) first_symbol_n ws pe_file state files;
}

write_optimized :: !*WriteState !*File !*State !*File !Int Int !String -> *(!*WriteState,!*File,!*State,!*File,!Int,!Int);
write_optimized ws pe_file state=:{n_xcoff_files} xcoff_file file_n first_symbol_n file_name
	#! (ws,pe_file,state,xcoff_file)
		= select_symbol_index_lists_to_write ws pe_file state xcoff_file file_n first_symbol_n;
	#! (n_symbols, state)
		= select_n_symbols file_n state;
	= (ws,pe_file,state,xcoff_file,file_n,first_symbol_n + n_symbols); 

write_code_to_pe_files :: !Int !Bool !Int !Int !(!Int,!Int) !State !Bool !*a !*Files -> ((!*a,!(!Int,!Int),!State),!*Files) | Target2 a;
write_code_to_pe_files n_xcoff_files do_relocations file_n first_symbol_n offset0 state one_pass_link pe_file files
	| file_n >= n_xcoff_files
		= ((pe_file,offset0,state),files);
	
	# (file_name, state)
		= select_file_name file_n state;
	# (n_symbols, state)
		= select_n_symbols file_n state;
	# (ok,xcoff_file,files)	
		= fopen file_name FReadData files;
	| not ok
		= abort ("Cannot read file: "+++ file_name);
	
		# (file_n,first_symbol_n,state,offset,xcoff_file,pe_file) 
			= write_code file_name file_n do_relocations first_symbol_n offset0 state xcoff_file pe_file;
	
		#! (end1,xcoff_file)
			= fposition xcoff_file;	
			
		# (ok,files) 				
			= fclose xcoff_file files;
		| not ok
			= abort ("Error while reading file: "+++file_name);
		= write_code_to_pe_files n_xcoff_files do_relocations (inc file_n) first_symbol_n offset state one_pass_link pe_file files;
where {
	// file_n < n_xcoff_files
	write_code file_name file_n do_relocations first_symbol_n offset0 state xcoff_file pe_file
		#! (state,offset,xcoff_file,pe_file) 
			= write_code_to_pe_file file_n do_relocations first_symbol_n offset0 state xcoff_file pe_file;
		| next_file_n == n_xcoff_files
			= (file_n,first_symbol_n,state,offset,xcoff_file,pe_file);
					
			#! (file_name2, state)
				= select_file_name next_file_n  state
			# (n_symbols, state)
				= select_n_symbols file_n state;
			| file_name2 == file_name
				= write_code file_name next_file_n do_relocations (first_symbol_n+n_symbols) offset state xcoff_file pe_file;
				
				= (file_n,first_symbol_n + n_symbols,state,offset,xcoff_file,pe_file);
	where {
		next_file_n 
			= inc file_n
	}		
}	

select_symbol_index_lists_to_write :: !*WriteState !*File !*State !*File !Int !Int -> *(!*WriteState,!*File,!*State,!*File);
select_symbol_index_lists_to_write ws=:{text_offset} pe_file state xcoff_file file_n first_symbol_n
	// select text symbols
	#! (text_symbols,state)		
		= selacc_text_symbols file_n state;
	#! (ws,pe_file,state,xcoff_file,text_offset)
		= write_symbol_index_lists (-1) text_symbols text_offset ws pe_file state xcoff_file;
	
	// select data symbols
	#! (data_offset,ws)
		= ws!buffers_i.[0];
	
	#! (data_symbols,state)		
		= selacc_data_symbols file_n state;
	#! (ws,pe_file,state,xcoff_file,data_offset)
		= write_symbol_index_lists 0 data_symbols data_offset ws pe_file state xcoff_file;
		
	#! ws
		= { ws & text_offset = text_offset, buffers_i.[0] = data_offset };
		
	// other symbols
	#! (extra_sections,state)
		= state!xcoff_a.[file_n].symbol_table.extra_sections;
	#! (ws,pe_file,state,xcoff_file)
		= foldSt write_user_symbol_index_list extra_sections (ws,pe_file,state,xcoff_file);
	= (ws,pe_file,state,xcoff_file);
where {
	write_user_symbol_index_list extra_section=:{es_buffer_n,es_symbols} (ws,pe_file,state,xcoff_file)
		#! (user_offset,ws)
			= ws!buffers_i.[es_buffer_n];
		#! (ws,pe_file,state,xcoff_file,user_offset)
			= write_symbol_index_lists es_buffer_n es_symbols user_offset ws pe_file state xcoff_file;
		#! ws
			= {ws & buffers_i.[es_buffer_n] = user_offset}
		= (ws,pe_file,state,xcoff_file);

	write_symbol_index_lists :: !Int !SymbolIndexList !Int !*WriteState !*File !*State !*File -> *(*WriteState,!*File,!*State,!*File,!Int);
	write_symbol_index_lists _ EmptySymbolIndex offset ws pe_file state xcoff_file
		= (ws,pe_file,state,xcoff_file,offset);
	write_symbol_index_lists buffer_n (SymbolIndex module_n symbol_list) offset ws pe_file state xcoff_file
		#! (symbol, state) 
		  	= sel_symbol file_n module_n state;
		#! (marked, state)
			= selacc_marked_bool_a (first_symbol_n+module_n) state;
		| marked 
			#! (ws,pe_file,state,xcoff_file,offset)
				= write_symbol_module_to_pe_file symbol offset ws pe_file state xcoff_file;
			= write_symbol_index_lists buffer_n symbol_list offset ws pe_file state xcoff_file;
			= write_symbol_index_lists buffer_n symbol_list offset ws pe_file state xcoff_file;
	where {
		sel_data_buffer :: !Int !*WriteState -> *(!*{#Char},!*WriteState);
		sel_data_buffer buffer_n ws=:{buffers}
			#! (buffer_n1,buffers) = replace buffers buffer_n {};
			= (buffer_n1,{ws & buffers = buffers});
			
		sel_text_buffer :: !*WriteState -> *(!*{#Char},!*WriteState);
		sel_text_buffer ws=:{text_buffer}
			= (text_buffer,{ws & text_buffer = {} });
			
		write_symbol_module_to_pe_file :: !Symbol !Int !*WriteState !*File !*State !*File -> *(!*WriteState,!*File,!*State,!*File,!Int);
		write_symbol_module_to_pe_file (Module virtual_module_offset length virtual_address file_offset n_relocations relocations characteristics) offset ws=:{do_relocations} pe_file state xcoff_file
			#! (real_module_offset,state) = selacc_module_offset_a (first_symbol_n+module_n) state;
			#!(ok,xcoff_file)
				= fseek xcoff_file file_offset FSeekSet;
			|  not ok
				= abort "write_symbol_module_to_pe_file: failed seek";
				
			#! (start,text_a0,xcoff_file,ws)
				= case (USE_FREADSTRING ((True) && (buffer_n <> (-1))) False) of {
					True
						#! (buffer,ws) = sel_data_buffer buffer_n ws;
//						#! aligned_offset = roundup_to_multiple offset 4;
						#! aligned_offset = if (characteristics bitand 0xc00000==0)
												((offset+3) bitand (-4))
												(((offset-1) bitor ((1<<(((characteristics bitand 0xf00000)>>20)-1))-1))+1)			
						#! (length2,buffer,xcoff_file)
							= freadsubstring aligned_offset length buffer xcoff_file;
						-> (aligned_offset,buffer,xcoff_file,ws);
					False
						#! (text_a0,xcoff_file)	
							= freads xcoff_file length;
						-> (0,text_a0,xcoff_file,ws);
				}

			// relocate if necessary
			#! (text_a0,state)  //(offset,pe_file,state)
				= case do_relocations of {
					False
						-> (text_a0,state);
					True
						-> relocate_text module_n length  /* end of JMP */ start 0 n_relocations file_n virtual_module_offset real_module_offset first_symbol_n state text_a0 virtual_address relocations;
				};
				
			// write
//			#! aligned_offset = roundup_to_multiple offset 4;
			#! aligned_offset = if (characteristics bitand 0xc00000==0)
									((offset+3) bitand (-4))
									(((offset-1) bitor ((1<<(((characteristics bitand 0xf00000)>>20)-1))-1))+1)
			#! (pe_file,ws)
				= case (buffer_n == (-1)) of {
					True
						#! pe_file
							= write_nop_bytes (aligned_offset - offset) pe_file;		
						#! pe_file
							= fwrites text_a0 pe_file;
						-> (pe_file,ws);
					False
						#! ws
							= USE_FREADSTRING { ws & buffers = {ws.buffers & [buffer_n] = text_a0} } (copy 0 text_a0 aligned_offset ws);
						-> (pe_file,ws);
				};
			= (ws,pe_file,state,xcoff_file,aligned_offset + length );
		where {
			copy :: !Int !{#Char} !Int *WriteState -> *WriteState; 
			copy i s j d
				| i == size s
					= d;
					= copy (inc i) s (inc j) {d & buffers.[buffer_n].[j] = s.[i]};		
		} // write_symbol_module_to_pe_file
	} // write_symbol_index_lists
	
	write_nop_bytes :: !Int !*File -> *File;
	write_nop_bytes i file
		| i == 0
			= file;
		= write_nop_bytes (dec i) (fwritec '\0' file);			
}

write_code_to_pe_file :: !Int !Bool !Int (!Int,!Int) !State !*File !*a -> (!State,(!Int,!Int),!*File,!*a) | Target2 a;
write_code_to_pe_file file_n do_relocations first_symbol_n (text_offset0,data_offset0) state xcoff_file pe_file	
	#! (text_symbols,state)		
		= selacc_text_symbols file_n state;
	#! (state,text_offset,xcoff_file,pe_file)
		= write_text_to_pe_file Text text_symbols text_offset0 state xcoff_file pe_file;
		
	#! (data_symbols,state)
		= selacc_data_symbols file_n state;
	#! (state,data_offset,xcoff_file,pe_file)
		= write_text_to_pe_file Data data_symbols data_offset0 state xcoff_file pe_file;
			
	= (state,(text_offset,data_offset),xcoff_file,pe_file);
	{
		write_text_to_pe_file :: !SymbolIndexListKind !SymbolIndexList !Int !State !*File !*a -> (!State,!Int,!*File,!*a) | Target2 a;
		write_text_to_pe_file _ EmptySymbolIndex offset0 state xcoff_file pe_file
			= (state,offset0,xcoff_file,pe_file);
		write_text_to_pe_file mode1 (SymbolIndex module_n symbol_list) offset0 state xcoff_file pe_file
			# (symbol, state) = sel_symbol file_n module_n state;
			# (marked, state) = selacc_marked_bool_a (first_symbol_n+module_n) state;
			| marked
				# (state, offset1,xcoff_file,pe_file) 
					= write_text_module_to_pe_file symbol offset0 state xcoff_file pe_file; // <<- ("marked",marked);
				= write_text_to_pe_file mode1 symbol_list offset1 state xcoff_file pe_file;
				= write_text_to_pe_file mode1 symbol_list offset0 state xcoff_file pe_file;
			{}{
				write_text_module_to_pe_file :: !Symbol !Int !State !*File !*a -> (!State,!Int,!*File,!*a) | Target2 a;
				write_text_module_to_pe_file (Module virtual_module_offset length virtual_address file_offset n_relocations relocations characteristics)
						offset0 state xcoff_file pe_file
				# o_i=first_symbol_n+module_n;
				# (real_module_offset,state) = selacc_module_offset_a o_i state;
				# (ok,xcoff_file)
					= fseek xcoff_file file_offset FSeekSet;
				|  not ok
					# (file_name, state1) = select_file_name file_n state;
					= abort ("write_text_module_to_pe_file: could not seek in file " +++ file_name +++
					         "\n This error results because the application is staically linked");

				// JMP ...	
				// only in case of dynamic linking text symbols
				# (n_relocations,text_a0,xcoff_file,state,original_length)
					= case ((n_relocations * SIZE_OF_RELOCATION) <> size relocations) of {
						True
							#! (jump_modules,state) = state!jump_modules;
							#! (jump_module,jump_modules)
								= splitAtPred (\(jump_module=:{jm_file_n,jm_symbol_n}) -> (jm_file_n == file_n && jm_symbol_n == module_n,jump_module)) jump_modules [] [];
							#! state = { state & jump_modules = jump_modules };	
							#! original_length
								= case jump_module of {
									[{jm_length}]
										-> jm_length;
									_
										-> abort "internal error; could not find jump module";
								};
							#! jump_start
								= DEBUG_DYNAMICALLY_LINKED_CODE (inc original_length) original_length
								
							#! text_a0_with_extra_jmp
								= { (createArray length (toChar 0x90)) & 
									[original_length] = toChar (DEBUG_DYNAMICALLY_LINKED_CODE 0xcc 0xe9)
								,	[jump_start] = toChar 0xe9
								};
							
							#! (n_chars_read,text_a0_with_extra_jmp,xcoff_file)
								= freadsubstring 0 original_length text_a0_with_extra_jmp xcoff_file;

							#! last_relocation_index = (n_relocations - 2) * SIZE_OF_RELOCATION;
							#! last_relocation_symbol_n = relocations ILONG (last_relocation_index+4);
							#! (sym,state) = sel_symbol file_n last_relocation_symbol_n state;
							#! (dest_address,state)
								= case sym of {
									(Module virtual_label_offset _ _ _ _ _ _)
										#! (first_symbol_n,state) = selacc_marked_offset_a file_n state;
										#! (real_module_offset,state) = selacc_module_offset_a (first_symbol_n + last_relocation_symbol_n) state;
										#! q = real_module_offset-virtual_label_offset;
										-> (q,state);
									_
										-> abort "cannot process";
								}
							#! ((x=:[{ca_begin}:_]),state) = state!begin_end_addresses
							#! current_pc = real_module_offset + jump_start;
							#! displacement = dest_address - (current_pc + 5 /* *first* PC +5, *then* the processor jumps */ );
							#! text_a0_with_extra_jmp = WriteLong text_a0_with_extra_jmp (inc jump_start) displacement;
							-> (dec n_relocations,text_a0_with_extra_jmp,xcoff_file,state,original_length);
						False
							#! (text_a0,xcoff_file)	
								= freads xcoff_file length; 
							-> (n_relocations,text_a0,xcoff_file,state,length);
					}
				// ... JMP

				# (file_name, state) = select_file_name file_n state;

				| size text_a0==length
					#!	aligned_offset = if (characteristics bitand 0xc00000==0)
												((offset0+3) bitand (-4))
												(((offset0-1) bitor ((1<<(((characteristics bitand 0xf00000)>>20)-1))-1))+1)
					#	(text_a1,state1)
							= case (do_relocations) of {
								True	-> relocate_text module_n length /* end of JMP */ 0 0 n_relocations file_n virtual_module_offset real_module_offset first_symbol_n state text_a0 virtual_address relocations;
								_		-> (text_a0,state);
							}
					#! write_output_record
						= { WriteOutputRecord |
								file_or_memory	= case mode1 of { Text->0; Data->1 }
							,	offset			= offset0
							,	aligned_offset=aligned_offset
							,	string			= text_a1 
							,	state		= state1	
						  };
					#! (state2,pe_file) = WriteOutput write_output_record pe_file;					
					= (state2,aligned_offset+length,xcoff_file,pe_file);			
			}
	}
	
write_nop_bytes :: !Int !{#Char} -> {#Char};
write_nop_bytes n string 
	= (createArray n (toChar 0x90)) +++ string;

select_data_or_code_symbols :: !SymbolIndexListKind !Int !State -> (!SymbolIndexList,!State);
select_data_or_code_symbols Text file_n state = selacc_text_symbols file_n state;
select_data_or_code_symbols Data file_n state = selacc_data_symbols file_n state;
