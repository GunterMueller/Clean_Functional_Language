implementation module selectively_import_and_mark_labels;

import StdEnv;
import State;
import xcoff;
import ExtString;
import ExtArray;
import link_switches;
import ExtInt;
import LinkerMessages;
import pdExtString;
import pdSymbolTable;

replace_section_label_by_label2 :: !Int !Int !*State -> (!Int,!*State);
replace_section_label_by_label2 file_n symbol_n state
	#! (symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	= replace_section_label_by_label symbol file_n symbol_n state;

replace_section_label_by_label :: !Symbol !Int !Int !*State -> (!Int,!*State);
replace_section_label_by_label s=:(SectionLabel section_n label_offset) file_n symbol_n state
	#! (section_symbol_n,state) = state!xcoff_a.[file_n].symbol_table.section_symbol_ns.[section_n];
	| section_n >= 1 && section_symbol_n <> (-1)
		#! state = { state & xcoff_a.[file_n].symbol_table.symbols.[symbol_n] = Label section_n label_offset section_symbol_n };
		= (section_symbol_n,state);
		
replace_section_label_by_label s=:(Label section_n label_offset section_symbol_n) file_n symbol_n state
	= (section_symbol_n,state);
		
has_section_label_already_been_replaced  :: !Int !Int !*State -> (!Bool,!*State);
has_section_label_already_been_replaced file_n symbol_n state
	#! (symbol,state) 
		= state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	= case symbol of {
		SectionLabel _ _	-> (False,state);
		Label _ _ _			-> (True,state);
	};

selective_import_symbol :: !Int !Int !*(!*{#Bool},!*State) -> *(!*{#Bool},!*State);
selective_import_symbol file_n symbol_n (newly_marked_bool_a,state)	
	#! (symbol_offset,state) = symbol_n_to_offset file_n symbol_n state;
	#! (marked_symbol,state) = state!marked_bool_a.[symbol_offset];
	| marked_symbol || newly_marked_bool_a.[symbol_offset]
		// has already been marked
		= (newly_marked_bool_a,state);

	#! newly_marked_bool_a = { newly_marked_bool_a & [symbol_offset] = True };
	| file_n < 0
		= (newly_marked_bool_a,state);
		
	#! (symbol,state) = state!xcoff_a.[file_n].symbol_table.symbols.[symbol_n];
	= selective_symbol_import2 symbol file_n symbol_n (newly_marked_bool_a,state);
where {
	selective_symbol_import2 symbol=:(SectionLabel section_n label_offset) _ _ (newly_marked_bool_a,state)
		#! (section_symbol_n,state) = replace_section_label_by_label symbol file_n symbol_n state;
		= selective_import_symbol file_n section_symbol_n (newly_marked_bool_a,state);

	selective_symbol_import2 (Module c1 length virtual_address c2 n_relocations relocations characteristics) _ _ (newly_marked_bool_a,state)
		= loopAst selective_module_symbol_import (newly_marked_bool_a,state) n_relocations;
	where {
		selective_module_symbol_import relocation_n (newly_marked_bool_a,state)
			#! relocation_index = relocation_n * SIZE_OF_RELOCATION;
			#! relocation_type = relocations IWORD (relocation_index+8);
			#! relocation_symbol_n = relocations ILONG (relocation_index+4);
			#! relocation_offset = relocations ILONG relocation_index;

			# (newly_marked_bool_a,state)
				= what_linker 
					(newly_marked_bool_a,state) 
					(case (((relocation_offset-virtual_address) + 4) == length) of {
					// copy&paste from mark_used_modules (pdSymbolTable)
					// when will this jump be inserted?
					False
						-> (newly_marked_bool_a,state);					
					True
						// Conditions for generating an extra jump:
						// 1.	relocation_type == REL_ABSOLUTE at section_length - 4
						// 2. 	(file_n,relocation_symbol_n) has already been linked (marked_bool_a in state)
						//
						// relocation_symbol_n is *reference* to next section
						#! (symbol_offset,state) = symbol_n_to_offset file_n relocation_symbol_n state;
						#! (next_section_has_already_been_linked,state) = state!marked_bool_a.[symbol_offset]
						| /* 1: */ relocation_type == REL_ABSOLUTE && /* 2: */ next_section_has_already_been_linked
							// There is a reference from an (yet) unlinked module (symbol_n) to another already linked module. 
							// If the unlinked module (relocation_symbol_n) does not contain an jump instruction at its end, 
							// one has to be generated. Accessing the file is expensive. Therefore the worst is assumed: there
							// is a non-jump in which case one has to be generated.
//							| False <<- ("Problem: ", file_n, symbol_n)
//								-> undef;
							# new_module_length = roundup_to_multiple (length + /* size of jump direct: */ DEBUG_DYNAMICALLY_LINKED_CODE 6 5) /* gc requirement: */ 4;
							#! new_module_n = Module c1 new_module_length virtual_address c2 (inc n_relocations) relocations characteristics;
							
							#! state = { state & jump_modules = [ {jm_file_n = file_n, jm_symbol_n = symbol_n, jm_length = length} : state.jump_modules] };
							
							// State
							#! state = upd_symbol new_module_n file_n symbol_n state;
							-> (newly_marked_bool_a,state);							

							-> (newly_marked_bool_a,state);
					_
						-> (newly_marked_bool_a,state); 
					}
				);

			= selective_import_symbol file_n relocation_symbol_n (newly_marked_bool_a,state);
	};
	
	selective_symbol_import2 (ImportLabel label_name) import_label_file_n import_label_symbol_n (newly_marked_bool_a,state)
		#! (imported_symbol_found,imported_file_n,imported_symbol_n,state)
			= find_name4 label_name state;
		| imported_symbol_found
			#! state = { state & xcoff_a.[import_label_file_n].symbol_table.symbols.[import_label_symbol_n] 
								= ImportedLabel imported_file_n imported_symbol_n };
			// ImportedLabel is immediately replaced by a SectionLabel or Label
			= import_an_import_label imported_file_n imported_symbol_n import_label_file_n import_label_symbol_n (newly_marked_bool_a,state);
			
		#! (imp_prefix_found,i) = starts "__imp_" label_name
		| fst (starts "__imp_" label_name)
			#! imported_label_name = label_name % (i,dec (size label_name));
			#! (imported_label_name_found,imported_file_n,imported_symbol_n,state)
				= find_name4 imported_label_name state;
			| imported_label_name_found
				| imported_file_n < 0
					#! state = { state & xcoff_a.[import_label_file_n].symbol_table.symbols.[import_label_symbol_n] 
										= ImportedFunctionDescriptor imported_file_n imported_symbol_n };
					= import_an_import_label imported_file_n imported_symbol_n import_label_file_n import_label_symbol_n (newly_marked_bool_a,state);
					
					// a __imp_-prefixed label name *must* be defined in a dynamic linker library
					= abort "a __imp_-prefixed label name *must* be defined in a dynamic linker library";
				= report_undefined_symbol newly_marked_bool_a state;
		| label_name == "__ImageBase"
			# state = { state & xcoff_a.[import_label_file_n].symbol_table.symbols.[import_label_symbol_n] = ImageBaseSymbol };
			= (newly_marked_bool_a,state)
			= report_undefined_symbol newly_marked_bool_a state;
	where {
		report_undefined_symbol newly_marked_bool_a state
			| import_label_file_n>=0
				# (module_name,state) = state!xcoff_a.[import_label_file_n].module_name;
				#! msg = "undefined symbol '" +++ label_name +++ "' in module "+++module_name;
				#! state = AddMessage (LinkerError msg) state;
				= (newly_marked_bool_a,state);
			#! msg = "undefined symbol '" +++ label_name +++ "'";
			#! state = AddMessage (LinkerError msg) state;
			= (newly_marked_bool_a,state);
	};

	selective_symbol_import2 (ImportedLabel imported_file_n imported_symbol_n) import_label_file_n import_label_symbol_n (newly_marked_bool_a,state)
		= import_an_import_label imported_file_n imported_symbol_n import_label_file_n import_label_symbol_n (newly_marked_bool_a,state);

	selective_symbol_import2 (ImportedLabelPlusOffset imported_file_n imported_symbol_n _) _ _ s
		= selective_import_symbol imported_file_n imported_symbol_n s;

	selective_symbol_import2 (ImportedFunctionDescriptor imported_file_n imported_symbol_n) _ _ s
		= selective_import_symbol imported_file_n imported_symbol_n s;

	selective_symbol_import2 s _ _ _
		= abort ("selective_symbol_import2 does not match; " +++ toString s);
};

import_an_import_label /* symbol to be imported */ imported_file_n imported_symbol_n /* import site */ import_label_file_n import_label_symbol_n (newly_marked_bool_a,state)
	| imported_file_n < 0
		= selective_import_symbol imported_file_n imported_symbol_n (newly_marked_bool_a,state);
	#! state
		= replace_imported_label_symbol /* symbol to be imported */ imported_file_n imported_symbol_n /* import site */ import_label_file_n import_label_symbol_n state;
	= selective_import_symbol imported_file_n imported_symbol_n (newly_marked_bool_a,state);
where {
	replace_imported_label_symbol /* symbol to be imported */ imported_file_n imported_symbol_n /* import site */ import_label_file_n import_label_symbol_n state
		#! (imported_symbol,state) 
			= state!xcoff_a.[imported_file_n].symbol_table.symbols.[imported_symbol_n];
		#! state
			= case imported_symbol of {
				SectionLabel section_n v_label_offset
					#! (section_symbol_n,state)
						= state!xcoff_a.[imported_file_n].symbol_table.section_symbol_ns.[section_n];
					#! (module_symbol,state) 
						= state!xcoff_a.[imported_file_n].symbol_table.symbols.[section_symbol_n];
					-> case module_symbol of {
						Module v_module_offset _ _ _ _ _ _
							#! state
								= { state & 
									xcoff_a.[import_label_file_n].symbol_table.symbols.[import_label_symbol_n] 
									= ImportedLabelPlusOffset imported_file_n section_symbol_n (v_label_offset-v_module_offset)
								};
							-> state;
						_
							-> state;
						};
				Label _ v_label_offset module_n
				//	at an earlier point in time, mark_used_modules has already converted a Section-
				//	Label into a Label. Re-implements a part of the SectionLabel-case.
					#! (module_symbol,state) 
						= state!xcoff_a.[imported_file_n].symbol_table.symbols.[module_n];
					-> case module_symbol of {
						Module v_module_offset _ _ _ _ _ _
							#! state
								= { state & 
									xcoff_a.[import_label_file_n].symbol_table.symbols.[import_label_symbol_n] 
									= ImportedLabelPlusOffset imported_file_n module_n (v_label_offset-v_module_offset)
								};
							-> state;
						_
							-> state;
						};	
				_ 
					-> state;
			};
		= state;
}; // import_an_import_label
