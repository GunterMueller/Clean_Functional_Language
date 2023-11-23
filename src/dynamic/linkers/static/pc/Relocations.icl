implementation module Relocations;

import StdEnv;
import State;
import xcoff;
import pdExtString;
import RWSDebugChoice;
import pdSymbolTable,link32or64bits;

relocate_text :: !Int !Int /* end JMP */ !Int !Int !Int !Int !Int !Int !Int !State !*{#Char} !Int !String -> (!*{#Char},!State);
relocate_text module_n length /* end JMP */ start relocation_n n_relocations file_n virtual_module_offset real_module_offset 
		/* mac: text_relocations data_relocations */
		first_symbol_n state text_a0
		// pc specific
		virtual_address relocations
	| relocation_n == n_relocations
		= (text_a0,state);
		#! relocation_index = relocation_n * SIZE_OF_RELOCATION;
		#! relocation_type = relocations IWORD (relocation_index+8);
		#! relocation_symbol_n = relocations ILONG (relocation_index+4);
		#! relocation_offset = relocations ILONG relocation_index;
		   (rec_sym,state2)= sel_symbol file_n relocation_symbol_n state;
		   (text1,state3) =
				Link32or64bits
					(case relocation_type of {
						REL_REL32
							-> Nrelocate_branch rec_sym state2 (relocation_offset+4)
								((relocation_offset-virtual_address) + /* ADDED */ start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_DIR32
							-> Nrelocate_long_pos rec_sym state2 
								((relocation_offset-virtual_address) + start)
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_ABSOLUTE
							-> (text_a0,state2);		 
					})
					(case relocation_type of {
						REL_AMD64_REL32
							-> Nrelocate_branch rec_sym state2 (relocation_offset+4)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_REL32_1
							-> Nrelocate_branch rec_sym state2 (relocation_offset+5)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_REL32_2
							-> Nrelocate_branch rec_sym state2 (relocation_offset+6)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_REL32_3
							-> Nrelocate_branch rec_sym state2 (relocation_offset+7)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_REL32_4
							-> Nrelocate_branch rec_sym state2 (relocation_offset+8)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_REL32_5
							-> Nrelocate_branch rec_sym state2 (relocation_offset+9)
								((relocation_offset-virtual_address) + start)
								virtual_module_offset real_module_offset 
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_ADDR64
							-> Nrelocate_long_pos rec_sym state2 
								((relocation_offset-virtual_address) + start)
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_ADDR32
							-> Nrelocate_long_pos rec_sym state2 
								((relocation_offset-virtual_address) + start)
								first_symbol_n relocation_symbol_n file_n text_a0;
						REL_AMD64_ABSOLUTE
							-> (text_a0,state2);		 
						REL_AMD64_ADDR32NB
							#! text_index = (relocation_offset-virtual_address) + start;
							# (offset,state) = relocate_addr32nb rec_sym state2 first_symbol_n relocation_symbol_n file_n;
							# (linker_state_base_va,state) = state!linker_state_info.linker_state_base_va;
							# text_a0 = add_to_long_at_offset (offset-linker_state_base_va) text_index text_a0;
							-> (text_a0,state);
						_
							-> (text_a0,state2);
					});
		= relocate_text module_n length /* end of JMP */ start (inc relocation_n) n_relocations file_n virtual_module_offset real_module_offset first_symbol_n state3 text1 virtual_address relocations;

Nrelocate_branch :: !Symbol !*State !Int !Int !Int !Int !Int !Int !Int !*{#Char} -> (!*{#Char}, !*State); 
Nrelocate_branch (Module virtual_label_offset _ _ _ _ _ _) state relocation_offset index virtual_module_offset real_module_offset first_symbol_n symbol_n file_n text0
	#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + symbol_n) state;
	= (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
								 (real_label_offset-real_module_offset)) index text0,
		state);
Nrelocate_branch (Label _ offset module_n) state relocation_offset index virtual_module_offset real_module_offset first_symbol_n relocation_symbol_n file_n text0
	#! (symbol,state) = sel_symbol file_n module_n state;
	#! (r_offset,state) = selacc_module_offset_a (first_symbol_n + module_n) state;
	#! real_label_offset = r_offset + offset;
	= case symbol of {
		Module virtual_label_offset _ _ _ _ _ _
			-> (add_to_long_at_offset ((virtual_label_offset-relocation_offset)+
										  (real_label_offset-real_module_offset)) index text0,
				state);
	  };
Nrelocate_branch (ImportedLabel file_n symbol_n) state relocation_offset index virtual_module_offset real_module_offset _ relocation_symbol_n current_file_n text0
	| file_n < 0
		#! (index1,state) = selacc_so_marked_offset_a file_n state;
		#! (real_label_offset,state) = selacc_module_offset_a (index1 + symbol_n) state;
		= (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
									 (real_label_offset-real_module_offset)) index text0,
			state);
		
		#! (symbol,state) = sel_symbol file_n symbol_n state;
		#! (first_symbol_n,state) = selacc_marked_offset_a file_n state;
		#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + symbol_n) state;
		= case symbol of {
			Module  _ _ _ _ _ _ _
				-> (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
											  (real_label_offset-real_module_offset)) index text0,state);
		};
Nrelocate_branch (ImportedLabelPlusOffset file_n1 symbol_n1 label_offset) state relocation_offset index virtual_module_offset real_module_offset _ relocation_symbol_n _ text0
	#! (symbol1,state) = sel_symbol file_n1 symbol_n1 state;
	#! (first_symbol_n,state) = selacc_marked_offset_a file_n1 state;
	#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + symbol_n1) state;
	= case symbol1 of {
		Module  _ _ _ _ _ _ _
				-> (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
											  (real_label_offset-real_module_offset)
											  +label_offset) index text0,
					state);
	  };
Nrelocate_branch (ImportedFunctionDescriptor file_n symbol_n) state relocation_offset index virtual_module_offset real_module_offset _ relocation_symbol_n current_file_n text0
	| file_n < 0
		#! (index1, state) = selacc_so_marked_offset_a file_n state;
		#! (real_label_offset, state) = selacc_module_offset_a (index1 + symbol_n + 1) state;
		= (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
									 (real_label_offset-real_module_offset)) index text0,
			state);
Nrelocate_branch ImageBaseSymbol state=:{linker_state_info={linker_state_base_va}} relocation_offset index virtual_module_offset real_module_offset first_symbol_n symbol_n file_n text0
	= (add_to_long_at_offset ((virtual_module_offset-relocation_offset)+
								 (linker_state_base_va-real_module_offset)) index text0,
		state);

relocate_addr32nb :: !Symbol !*State !Int !Int !Int -> (!Int,!*State);
relocate_addr32nb (Module  virtual_label_offset _ _ _ _ _ _) state first_symbol_n symbol_n _
	= selacc_module_offset_a (first_symbol_n + symbol_n) state;
relocate_addr32nb (Label _ offset module_n) state first_symbol_n symbol_n file_n	  	
	#! (symbol,state) = sel_symbol file_n module_n state;
	#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + module_n) state;
	= case symbol of {
		Module  virtual_label_offset _ _ _ _ _ _
			-> (real_label_offset+offset-virtual_label_offset,state);
		};
relocate_addr32nb (ImportedLabel file_n symbol_n) state _ _ cfile_n	  	
	| file_n<0	
		#! (index1,state) = selacc_so_marked_offset_a file_n state;
		= selacc_module_offset_a (index1 + symbol_n) state;
		#! (symbol, state) = sel_symbol file_n symbol_n state;
		#! (first_symbol_n, state) = selacc_marked_offset_a file_n state; 
		#! (real_label_offset, state) = selacc_module_offset_a (first_symbol_n+symbol_n) state;
		= case symbol of {
			Module  _ _ _ _ _ _ _
				-> (real_label_offset,state);
			};
relocate_addr32nb (ImportedLabelPlusOffset file_n symbol_n label_offset) state /* first_symbol_n*/ _ _ _	  	
	#! (symbol, state) = sel_symbol file_n symbol_n state;
	#! (first_symbol_n, state) = selacc_marked_offset_a file_n state; 
	#! (real_label_offset, state) = selacc_module_offset_a (first_symbol_n+symbol_n) state;
	= case symbol of {
		Module  _ _ _ _ _ _ _
			-> (real_label_offset+label_offset,state);
		};
relocate_addr32nb (ImportedFunctionDescriptor file_n symbol_n) state first_symbol_n _ _
	| file_n < 0
		#! (index1, state) = selacc_so_marked_offset_a file_n state;
		#! (real_label_offset, state) = selacc_module_offset_a (index1 + symbol_n + 1) state;
		= (real_label_offset,state);

Nrelocate_long_pos :: !Symbol !*State !Int !Int !Int !Int !*{#Char} -> (!*{#Char},!*State);
Nrelocate_long_pos (Module  virtual_label_offset _ _ _ _ _ _) state index first_symbol_n symbol_n _ data0
	#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + symbol_n) state;
	= (add_to_long_at_offset real_label_offset index data0,state);
Nrelocate_long_pos (Label _ offset module_n) state index first_symbol_n symbol_n file_n data0	  	
	#! (symbol,state) = sel_symbol file_n module_n state;
	#! (real_label_offset,state) = selacc_module_offset_a (first_symbol_n + module_n) state;
	= case symbol of {
		Module  virtual_label_offset _ _ _ _ _ _
			-> (add_to_long_at_offset (real_label_offset+offset-virtual_label_offset) index data0 ,
				state);
		};	  
Nrelocate_long_pos (ImportedLabel file_n symbol_n) state index _ /* first_symbol_n */ _ cfile_n data0	  	
	| file_n<0	
		#! (index1,state) = selacc_so_marked_offset_a file_n state;
		#! (real_label_offset,state) = selacc_module_offset_a (index1 + symbol_n) state;
		= (add_to_long_at_offset real_label_offset index data0, state);
		 
		#! (symbol, state) = sel_symbol file_n symbol_n state;
		#! (first_symbol_n, state) = selacc_marked_offset_a file_n state; 
		#! (real_label_offset, state) = selacc_module_offset_a (first_symbol_n+symbol_n) state;
		= case symbol of {
			Module  _ _ _ _ _ _ _
				-> (add_to_long_at_offset real_label_offset index data0,
					 state);
			};
Nrelocate_long_pos (ImportedLabelPlusOffset file_n symbol_n label_offset) state index /* first_symbol_n*/ _ _ _ data0	  	
	#! (symbol, state) = sel_symbol file_n symbol_n state;
	#! (first_symbol_n, state) = selacc_marked_offset_a file_n state; 
	#! (real_label_offset, state) = selacc_module_offset_a (first_symbol_n+symbol_n) state;
	= case symbol of {
		Module  _ _ _ _ _ _ _
			-> (add_to_long_at_offset (real_label_offset+label_offset) index data0,
				 state);
		};
Nrelocate_long_pos (ImportedFunctionDescriptor file_n symbol_n) state index first_symbol_n _ _ data0
	| file_n < 0
		#! (index1, state) = selacc_so_marked_offset_a file_n state;
		#! (real_label_offset, state) = selacc_module_offset_a (index1 + symbol_n + 1) state;
		= (add_to_long_at_offset real_label_offset index data0,
				 state);

add_to_long_at_offset :: !Int !Int !*{#Char} -> *{#Char};
add_to_long_at_offset w index array
	#!	index1 = index+1;
		index2 = index+2;
		index3 = index+3;
	#! (v0,array) = array![index]
	#! (v1,array) = array![index1]
	#! (v2,array) = array![index2]
	#! (v3,array) = array![index3]
	#! v = (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);
	#! new_v = v + w;
	= {array & [index]=toChar new_v,[index1]=toChar (new_v>>8),[index2]=toChar (new_v>>16),[index3]=toChar (new_v>>24)};
