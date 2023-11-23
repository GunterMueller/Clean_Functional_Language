
implementation module Relocations;

import StdInt,StdArray;
import ExtFile, ExtString, xcoff;
import SymbolTable;
import State;

CODE_OR_DATA_P section_n data_p :== if (section_n<>TOC_SECTION) 0 data_p;

relocate_text2 :: Int Int !Int !Int !Int !String !String  !Int   !Int !Int !SymbolIndexList  *String *String !*State -> (!*String,!*String,!*State);
relocate_text2 relocation_n end_relocation_n file_n virtual_module_offset real_module_offset text_relocations data_relocations first_symbol_n text_v_address data_v_address toc0_symbol text_a0 data_section state
	| /*FB (file_n == 8) ("relocation_n=" +++ toString relocation_n)*/ relocation_n==end_relocation_n
		= (text_a0,data_section,state);
		
/*
	optimalisatie: (gebaseerd op aanname dat de grootte van de TOC statisch bekend is *en* dat het datagebied direkt na de TOC volgt; in het dynamische geval is dit niet meer zo)
	| relocation_type==R_TRL && (relocation_size==0x8f || relocation_size==0x0f)

		= F ("R_TRL: file_n=" +++ toString file_n +++ " - " +++ name) relocate_text2 (inc relocation_n) 
		end_relocation_n file_n virtual_module_offset real_module_offset text_relocations data_relocations first_symbol_n text_v_address data_v_address toc0_symbol
		 text1 data_section1 state5;
		{
			(name,state5)
				= select_file_name file_n state4;
	
			(relocation_symbol,state2)
				= sel_symbol file_n relocation_symbol_n state;
			(toc0_symbol2,state3)
				= sel_symbol file_n toc0_symbol_n state2;
				
			(text1,data_section1,state4)
				= relocate_trl2 file_n relocation_symbol toc0_symbol2  (relocation_offset-text_v_address) data_v_address
					 first_symbol_n relocation_symbol_n data_relocations text_a0 data_section state3;
	
			(SymbolIndex toc0_symbol_n _)=toc0_symbol;
		}
*/
		= relocate_text2 (inc relocation_n) end_relocation_n file_n virtual_module_offset real_module_offset text_relocations data_relocations
		 first_symbol_n text_v_address data_v_address toc0_symbol text1 data_section state3;
		{
			(relocation_symbol,state2)
				= sel_symbol file_n  relocation_symbol_n state;
			
			(text1,state3)
				 = case relocation_type of {
					R_BR
						| relocation_size==0x8f
							->  relocate_short_branch2 relocation_symbol file_n (relocation_offset-text_v_address) virtual_module_offset 
								real_module_offset first_symbol_n relocation_symbol_n text_a0 state2;
						| relocation_size==0x99
							->  relocate_branch2 relocation_symbol file_n (relocation_offset-text_v_address) virtual_module_offset
								real_module_offset first_symbol_n relocation_symbol_n text_a0 state2;
					R_TOC
						| relocation_size==0x8f || relocation_size==0x0f
							# (toc0_symbol,state3)
								= sel_symbol file_n toc0_symbol_n state2;
							->  relocate_toc2 relocation_symbol toc0_symbol 
								(relocation_offset-text_v_address)  first_symbol_n relocation_symbol_n  text_a0 state3;
							{
								(SymbolIndex toc0_symbol_n _)=toc0_symbol;
							}
							
					R_TRL
						| relocation_size==0x8f || relocation_size==0x0f
							# (toc0_symbol,state3)
								= sel_symbol file_n toc0_symbol_n state2;
							->  relocate_toc2 relocation_symbol toc0_symbol 
								(relocation_offset-text_v_address)  first_symbol_n relocation_symbol_n  text_a0 state3;
							{
								(SymbolIndex toc0_symbol_n _)=toc0_symbol;
							}
												
					R_REF
						-> (text_a0,state2);

/*
					R_MW_BR
						| relocation_size==0x8f
							-> relocate_mw_short_branch2 relocation_symbol file_n (relocation_offset-text_v_address) virtual_module_offset 
								real_module_offset first_symbol_n relocation_symbol_n text_a0 state2;
						| relocation_size==0x99
							->  relocate_mw_branch2 relocation_symbol file_n (relocation_offset-text_v_address) virtual_module_offset
								real_module_offset first_symbol_n relocation_symbol_n text_a0 state2;
					R_MW_TOC
						| relocation_size==0x8f || relocation_size==0x0f
							->  relocate_mw_toc2 relocation_symbol
								(relocation_offset-text_v_address) first_symbol_n relocation_symbol_n text_a0 state2;
*/
					
					// relocations below ONLY for {data,toc}-sections			
					R_POS
//						#! (small_integers_file_n,small_integers_symbol_n,state3)
//							= find_name "small_integers" state2;
						#! state3
							= state2;							
						
					
						| /*FB (file_n == 8) ("relocating small_integers" +++ toString small_integers_file_n +++ " - <" +++ toString small_integers_symbol_n +++ ">")*/ relocation_size==0x1f
							-> relocate_long_pos2 relocation_symbol file_n 
									(relocation_offset-text_v_address)  
										first_symbol_n relocation_symbol_n text_a0 state3;
										
/*
					R_MW_POS
						| relocation_size==0x1f
							-> relocate_mw_long_pos2 relocation_symbol file_n 
							(relocation_offset-text_v_address)  
										first_symbol_n relocation_symbol_n text_a0 state2;
*/
					_
						-> abort "MW-relocations disabled";
			}
		}
	{							
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;
	
		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}
//import DebugUtilities;

import ExtInt;
// relocate_long_pos2
relocate_long_pos2 :: Symbol !Int Int Int Int *{#Char} !*State -> (*{#Char},!*State);
relocate_long_pos2 (Module {section_n,module_offset=virtual_label_offset}) f_n index first_symbol_n symbol_n data0 state=:{pd_state={toc_p}}
//	| FB (f_n == 1 && symbol_n == 476) "relocate_long_pos2 (Module" True
//	| F "file_n=8" file_n == 8
			
	# (real_label_offset,state) 
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
//	| f_n == 1 && symbol_n == 476
		//= abort ("relocate_long_pos2 (Module" +++ hex_int real_label_offset);
//		= (add_to_long_at_offset2 (real_label_offset-virtual_label_offset + (CODE_OR_DATA_P section_n toc_p) ) index data0,state);

	= (add_to_long_at_offset (real_label_offset-virtual_label_offset + (CODE_OR_DATA_P section_n toc_p) ) index data0,state);

relocate_long_pos2 (Label {label_module_n=module_n}) file_n index first_symbol_n symbol_n data0 state
//	| FB (file_n == 1 && symbol_n == 476) "relocate_long_pos2 (Label" True
	# (relocation_module_symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_long_pos2 relocation_module_symbol file_n index first_symbol_n module_n data0 state;

relocate_long_pos2 (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) f_n index first_symbol_n1 _  data0 state=:{pd_state={toc_p}}


	| /*FB (f_n == 1 && symbol_n == 476) "relocate_long_pos2 (ImportedLabel"*/ file_n<0
		# (i_marked_offset_a,state)
			= selacc_so_marked_offset_a file_n state;
		# (real_label_offset,state)
			= selacc_module_offset_a (i_marked_offset_a+symbol_n) state;
		= (add_to_long_at_offset real_label_offset index data0,state);
		
		
		# (first_symbol_n,state)
			= selacc_marked_offset_a file_n state;
		# (relocation_symbol,state)
			= sel_symbol file_n symbol_n state;
		= relocate_long_pos_of_module_in_another_module2 relocation_symbol state first_symbol_n;
		where {
			relocate_long_pos_of_module_in_another_module2 (Module {section_n}) state first_symbol_n
			
		/*
//				#! (file_n,symbol_n,state)
//					= find_name "small_integers" state;
				#! (small_integers_entry,state)
					= address_of_label2 file_n symbol_n state;
				#! state
					=  F ("! small_integers at: " +++ (hex_int small_integers_entry)) state;
				*/		
				
				
				# (real_label_offset,state)
					= selacc_module_offset_a (first_symbol_n+symbol_n) state;
					
					
	/*
				// CODE_OR_DATA_P section_n data_p :== if (section_n<>TOC_SECTION) 0 data_p;
				#! q 
					= real_label_offset + (CODE_OR_DATA_P section_n toc_p);
				#! s
					= "**real_label_offset=" +++  hex_int q +++ " - section_n=" +++ toString section_n;
			*/		
				= /*F s*/ (add_to_long_at_offset (real_label_offset + (CODE_OR_DATA_P section_n toc_p)) index data0,state);
				
			where {
			
				address_of_label21 :: !Int !Int !State -> (!Int,!State);
				address_of_label21 file_n symbol_n state
					# (first_symbol_n,state1)
						= selacc_marked_offset_a file_n state1;
					# (marked,state1)
						= selacc_marked_bool_a (first_symbol_n+symbol_n) state1;
					| not marked 
						= F "not marked" (0,state1);
						
				//		#! (label_symbol,state)
				//			= sel_symbol file_n symbol_n state;
						| isLabel label_symbol
							#! module_n
								= getLabel_module_n label_symbol;
							#! offset
								= getLabel_offset label_symbol;
								
							#! (module_symbol,state1)
								= sel_symbol file_n module_n state1;
							| isModule module_symbol
								#! virtual_label_offset
									= getModule_virtual_label_offset module_symbol;
								#! (first_symbol_n,state1) 
									= selacc_marked_offset_a file_n state1;
								#! (real_module_offset,state1)
									= selacc_module_offset_a (first_symbol_n + module_n) state1;
								= (real_module_offset+offset-virtual_label_offset,state1);
				
								= abort "address_of_label2: internal error (isModule)";
						| isModule label_symbol
							= (sel_platform address_of_label2_pc address_of_label2_mac) state1;
							= abort "address_of_label2: not a {label,module}-symbol";
				where {
					(label_symbol,state1)
						= sel_symbol file_n symbol_n state;
						
					address_of_label2_pc state
						#! module_n
							= symbol_n;
						#! module_symbol
							= label_symbol;
							
						#! virtual_label_offset
							= getModule_virtual_label_offset module_symbol;
						#! (first_symbol_n,state) 
							= selacc_marked_offset_a file_n state;
						#! (real_module_offset,state)
							= selacc_module_offset_a (first_symbol_n + module_n) state;
							
						#! q = real_module_offset-virtual_label_offset;
						= (q,state);
						
					address_of_label2_mac state
						#! module_n
							= symbol_n;
						#! module_symbol
							= label_symbol;
							
						#! (first_symbol_n,state) 
							= selacc_marked_offset_a file_n state;
						#! (real_module_offset,state)
							= selacc_module_offset_a (first_symbol_n + module_n) state;
						= (real_module_offset,state);
				
				} // address_of_label2

			} // relocate_long_pos_of_module_in_another_module_2
		}

relocate_long_pos2 (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) f_n index first_symbol_n _ data0 state=:{pd_state={toc_p}}
//	| FB (f_n == 1 && symbol_n == 476) "relocate_long_pos2 (ImportedLabelPlusOffset" True

	# (relocation_symbol,state)
		= sel_symbol file_n symbol_n state;
	# (first_symbol_n,state)
		= selacc_marked_offset_a file_n state
	= case relocation_symbol of {
		Module {section_n}
			# (real_label_offset,state)
				= selacc_module_offset_a (first_symbol_n+symbol_n) state;
			-> (add_to_long_at_offset (real_label_offset+label_offset+ (CODE_OR_DATA_P section_n toc_p)) index data0,state);
	}
	
// relocate_short_branch2
relocate_short_branch2 :: Symbol !Int Int Int Int Int Int *{#Char} !*State -> (*{#Char},!*State);
relocate_short_branch2 (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) _ index virtual_module_offset
		real_module_offset first_symbol_n symbol_n  text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
		
	= (add_to_word_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0,state);

relocate_short_branch2 (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) file_n index virtual_module_offset real_module_offset  first_symbol_n symbol_n  text0 state
	# (symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_short_branch2 symbol file_n index virtual_module_offset real_module_offset  first_symbol_n module_n  text0 state;


// relocate_branch2
relocate_branch2 :: Symbol !Int Int Int Int Int Int  *{#Char} !*State -> (*{#Char},!*State);
relocate_branch2 (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) _ index virtual_module_offset 
		real_module_offset  first_symbol_n symbol_n text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;		
	= (add_to_branch_offset_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0,state);

relocate_branch2 (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) file_n index virtual_module_offset 
		real_module_offset  first_symbol_n symbol_n text0 state
	# (module_symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_branch2 module_symbol file_n index virtual_module_offset real_module_offset first_symbol_n module_n text0 state;

relocate_branch2 (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) _ index virtual_module_offset
		real_module_offset  first_symbol_n _  text0 state
	|  file_n<0	
		# (i_module_offset_a,state)
			= selacc_so_marked_offset_a file_n state;
		# (real_label_offset,state)
			= selacc_module_offset_a (i_module_offset_a + symbol_n) state;
		= (load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0),state);


		# (relocation_symbol,state)
			= sel_symbol file_n symbol_n state;
		# (first_symbol_n,state)
			= selacc_marked_offset_a file_n state;
		= relocate_branch_to_another_module relocation_symbol index virtual_module_offset
			real_module_offset  first_symbol_n symbol_n  text0 state;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int  Int Int  *{#Char} !*State -> (*{#Char},!*State);
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset  first_symbol_n symbol_n text0 state
				# (real_label_offset,state)
					 = selacc_module_offset_a (first_symbol_n+symbol_n) state;
				= (add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0,state);
		}
		
relocate_branch2 (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) _ index virtual_module_offset
		real_module_offset _ _ text0 state
	# (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	# (symbol,state)
		= sel_symbol file_n symbol_n state;
	= case symbol of {
		Module {section_n=TEXT_SECTION}
			# (real_label_offset,state)
				// first_symbol_n
				= selacc_module_offset_a (first_symbol_n+symbol_n) state;
			-> (add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)+label_offset) index text0,state);
	}

// relocate_toc2
relocate_toc2 :: Symbol Symbol Int Int Int *{#Char} !*State -> (*{#Char},State);
relocate_toc2 (Module {section_n=TOC_SECTION,module_offset=virtual_label_offset}) (Module {module_offset=virtual_toc0_offset}) index
				 first_symbol_n symbol_n  text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n + symbol_n) state;
	= (add_to_word_at_offset ((virtual_toc0_offset-virtual_label_offset)+real_label_offset-32768) index text0,state);

relocate_toc2 (AliasModule {alias_module_offset,alias_global_module_n}) (Module {module_offset=virtual_toc0_offset}) index
				 first_symbol_n symbol_n  text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (alias_global_module_n) state;
	= (add_to_word_at_offset ((virtual_toc0_offset-alias_module_offset)+real_label_offset-32768) index text0, state);

relocate_toc2 (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) (Module {module_offset=virtual_toc0_offset}) index
				 first_symbol_n symbol_n  text0 state
	# (i_module_offset,state)
		= selacc_so_marked_offset_a imptoc_file_n state;
	# (real_label_offset,state)
		= selacc_module_offset_a (i_module_offset + imptoc_symbol_n+1) state;
	= (add_to_word_at_offset ((virtual_toc0_offset-imptoc_offset)+real_label_offset-32768) index text0, state);

// relocate_mw_long_pos2
relocate_mw_long_pos2 (Module {section_n,module_offset=virtual_label_offset}) _ index first_symbol_n symbol_n data0 state=:{pd_state={toc_p}}
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
	
	#! q
		= real_label_offset + (CODE_OR_DATA_P section_n toc_p);
		
	= /*FB (q == 0) "niets" */(add_to_long_at_offset (real_label_offset + (CODE_OR_DATA_P section_n toc_p)) index data0,state);

relocate_mw_long_pos2 (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n}) file_n index first_symbol_n symbol_n data0 state
	# (relocation_module_symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_mw_long_pos2 relocation_module_symbol file_n index first_symbol_n module_n data0 state;

relocate_mw_long_pos2 (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) _ index first_symbol_n _  data0 state=:{pd_state={toc_p}}
	| file_n<0
		# (i_marked_offset_a,state)
			= selacc_so_marked_offset_a file_n state;
		# (real_label_offset,state)
			= selacc_module_offset_a (i_marked_offset_a+symbol_n) state;
		= (add_to_long_at_offset real_label_offset index data0,state);

		# (first_symbol_n,state)
			= selacc_marked_offset_a file_n state;
		# (relocation_symbol,state)
			= sel_symbol file_n symbol_n state;
		= relocate_mw_long_pos_of_module_in_another_module relocation_symbol state;
		{
			relocate_mw_long_pos_of_module_in_another_module (Module {section_n}) state
				# (real_label_offset,state)
					= selacc_module_offset_a (first_symbol_n+symbol_n) state;
				= (add_to_long_at_offset (real_label_offset + (CODE_OR_DATA_P section_n toc_p)) index data0,state);
		}
		
relocate_mw_long_pos2 (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) _ index first_symbol_n _  data0 state=:{pd_state={toc_p}}
	# (first_symbol_n,state)
		= selacc_marked_offset_a file_n state;
	# (relocation_symbol,state)
		= sel_symbol file_n symbol_n state;
	= case relocation_symbol of {
			Module {section_n}
				# (real_label_offset,state)
					= selacc_module_offset_a (first_symbol_n+symbol_n) state;
				-> (add_to_long_at_offset (real_label_offset+label_offset+ (CODE_OR_DATA_P section_n toc_p)) index data0,state);
	}
		
// relocate_mw_short_branch2
relocate_mw_short_branch2 (Module {section_n=TEXT_SECTION}) _ index virtual_module_offset real_module_offset first_symbol_n symbol_n text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;	
	= (add_to_word_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0,state);

relocate_mw_short_branch2 (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) file_n index virtual_module_offset real_module_offset  first_symbol_n symbol_n  text0 state
	# (relocation_module_symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_mw_short_branch2 relocation_module_symbol file_n index virtual_module_offset real_module_offset first_symbol_n module_n text0 state;


relocate_mw_branch2 (Module {section_n=TEXT_SECTION}) file_n index virtual_module_offset
		real_module_offset first_symbol_n symbol_n text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;		
	= (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0,state);

relocate_mw_branch2 (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) file_n index virtual_module_offset 
		real_module_offset  first_symbol_n symbol_n text0 state
	# (relocation_module_symbol,state)
		= sel_symbol file_n module_n state;
	= relocate_mw_branch2 relocation_module_symbol file_n index virtual_module_offset real_module_offset first_symbol_n module_n text0 state;

relocate_mw_branch2 (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) _ index virtual_module_offset
		real_module_offset first_symbol_n _ text0 state
	| file_n<0
		# (i_marked_offset_a,state)
			= selacc_so_marked_offset_a file_n state;
		# (real_label_offset,state)
			= selacc_module_offset_a (i_marked_offset_a+symbol_n) state;
		= (load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0),state);

		# (relocation_symbol,state)
			= sel_symbol file_n symbol_n state;
		# (first_symbol_n,state)
			= selacc_marked_offset_a file_n state;
		= relocate_branch_to_another_module relocation_symbol index virtual_module_offset real_module_offset  first_symbol_n symbol_n text0 state;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int Int Int *{#Char} !*State-> (*{#Char},!*State);
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset first_symbol_n symbol_n text0 state
				# (real_label_offset,state) 
					= selacc_module_offset_a (first_symbol_n+symbol_n) state;
				= (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0,state);
		}

relocate_mw_branch2 (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) _ index 
		virtual_module_offset real_module_offset first_symbol_n _ text0 state
	# (relocation_symbol,state)
		= sel_symbol file_n symbol_n state;
	=	case relocation_symbol of {
			Module {section_n=TEXT_SECTION}
				# (first_symbol_n,state)
					= selacc_marked_offset_a file_n state;
				# (real_label_offset,state)
					= selacc_module_offset_a (first_symbol_n+symbol_n) state;
				-> (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)+label_offset) index text0,state);
		}

	
// relocate_mw_toc2
relocate_mw_toc2 (Module {section_n=TOC_SECTION}) index first_symbol_n symbol_n text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (first_symbol_n+symbol_n) state;
	= (add_to_word_at_offset (real_label_offset-32768) index text0,state);

relocate_mw_toc2 (AliasModule {alias_global_module_n}) index first_symbol_n symbol_n text0 state
	# (real_label_offset,state)
		= selacc_module_offset_a (alias_global_module_n) state;
	= (add_to_word_at_offset (real_label_offset-32768) index text0,state);

relocate_mw_toc2 (ImportedFunctionDescriptorTocModule {imptoc_file_n,imptoc_symbol_n}) index first_symbol_n symbol_n text0 state
	# (i_marked_offset_a,state)
		= selacc_so_marked_offset_a imptoc_file_n state;
	# (real_label_offset,state)
		= selacc_module_offset_a (i_marked_offset_a+imptoc_symbol_n+1) state;	
	= (add_to_word_at_offset (real_label_offset-32768) index text0,state);

// relocate_trl2
/*
Als de toc klein genoeg is dan, kunnen i.p.v. R_TOC-reloctaties R_TRLs gegenereerd worden als optimalisatie. Dit betekent dat een
symbool m.b.v. een offset vanaf de TOC geaddresseerd kunnen worden. Een lwz instructie wordt dan vervangen door een addi
*/
relocate_trl2 :: !Int Symbol Symbol Int Int Int Int String *String *String !*State -> (!*String,!*String,!*State);
relocate_trl2  file_n symbol toc0_symbol index data_v_address first_symbol_n symbol_n data_relocations text0 data0 state
	= case symbol of {
		Module {section_n=TOC_SECTION,length=4,first_relocation_n,end_relocation_n}
			| first_relocation_n+1==end_relocation_n && relocation_type==R_POS && relocation_size==0x1f
				-> relocate_trl1 relocation_index state;
			{}{
				relocation_index=first_relocation_n * SIZE_OF_RELOCATION;
				
				relocation_type=data_relocations BYTE (relocation_index+9);
				relocation_size=data_relocations BYTE (relocation_index+8);
			}
		AliasModule {alias_first_relocation_n}
			-> relocate_trl1 relocation_index state;
			{
				relocation_index=alias_first_relocation_n * SIZE_OF_RELOCATION;
			}
		_
			-> abort "relocate_trl2"; //(relocate_toc symbol toc0_symbol index first_symbol_n symbol_n text0 state,data0);
	}
	{
		relocate_trl1 :: !Int !*State -> (!*String,!*String,!*State);
		relocate_trl1 relocation_index state
			# (relocation_symbol,state)
				= sel_symbol file_n relocation_symbol_n state;
			= relocate_trl2 relocation_symbol first_symbol_n relocation_symbol_n state;
		{
			relocation_symbol_n=(inc (data_relocations LONG (relocation_index+4))) >> 1;
			
			relocation_offset=data_relocations LONG relocation_index;
		
			(offset,data1)=read_long data0 (relocation_offset-data_v_address);


			relocate_trl2 :: Symbol Int Int !*State-> (!*String,!*String,!*State);
			relocate_trl2 (Module {section_n,module_offset=virtual_label_offset}) first_symbol_n symbol_n state
				# (real_label_offset,state)
					= selacc_module_offset_a (first_symbol_n + symbol_n) state; 
				# new_offset 
					= real_label_offset+offset-virtual_label_offset;
				= relocate_trl3 section_n new_offset state;
			relocate_trl2 (Label {label_offset=offset,label_module_n=module_n}) first_symbol_n symbol_n state
				# (module_relocation_symbol,state)
					= sel_symbol file_n module_n state;
				= relocate_trl2 module_relocation_symbol first_symbol_n module_n state;	

			relocate_trl2 (ImportedLabel {implab_file_n=imported_file_n,implab_symbol_n=imported_symbol_n}) first_symbol_n symbol_n state
				| imported_file_n<0
					# (text1,state)
						= relocate_toc2 symbol toc0_symbol index first_symbol_n symbol_n text0 state;
					= (text1,data1,state);

					# (imported_symbol,state)
						= sel_symbol imported_file_n imported_symbol_n state;
					# (i_marked_offset_a,state)
						= selacc_marked_offset_a imported_file_n state;
					# (real_label_offset,state)
						= selacc_module_offset_a (i_marked_offset_a+imported_symbol_n) state;
					# new_offset
						= real_label_offset+offset;	
					= case imported_symbol of {
						Module {section_n}
							-> relocate_trl3 section_n new_offset state;
					};

			relocate_trl2 (ImportedLabelPlusOffset {implaboffs_file_n=imported_file_n,implaboffs_symbol_n=imported_symbol_n,implaboffs_offset=label_offset}) 
				first_symbol_n symbol_n state
					# (imported_symbol,state)
						= sel_symbol imported_file_n imported_symbol_n state;
					# (i_marked_offset_a,state)
						= selacc_marked_offset_a imported_file_n state;
					# (real_label_offset,state)
						= selacc_module_offset_a (i_marked_offset_a+imported_symbol_n) state;
					# new_offset
						= real_label_offset+label_offset+offset;
					= case imported_symbol of {
						Module {section_n}
							-> relocate_trl3 section_n new_offset state;
					};

			relocate_trl3 :: Int Int !*State-> (!*String,!*String,!*State);
			relocate_trl3 section_n new_offset state 
				| (section_n==DATA_SECTION || section_n==BSS_SECTION) && (new_offset bitand 0xffff)==new_offset
					= (change_lwz_to_addi (new_offset-32768) index text0,data1,state);
					
					# (text0,state) 
						= relocate_toc2 symbol toc0_symbol index first_symbol_n symbol_n text0 state;
					= (text0,data1,state);
		}

	}

change_lwz_to_addi :: Int Int *{#Char} -> *{#Char};
change_lwz_to_addi w index array=:{[index_2]=a_i_2}
	| (toInt a_i_2 bitand 252) == 128
		= {array & [index_2]=toChar ((toInt a_i_2 bitand 3) bitor 56),[index]=toChar (w>>8),[index1]=toChar w};
	{}{
		index_2 = index-2;
		index1 = inc index;
	}

add_to_word_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_word_at_offset w index array=:{[index]=v0,[index1]=v1}
	= {array & [index]=toChar (new_v>>8),[index1]=toChar new_v};  {
		new_v=v+w;
		v = (toInt v0<<8) + (toInt v1);
		index1 = inc index;
	}

add_to_branch_offset_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_branch_offset_at_offset w index array=:{[index]=v0,[index1]=v1,[index2]=v2,[index3]=v3}
	= {array & [index]=new_v0,[index1]=toChar (new_v>>16),[index2]=toChar (new_v>>8),[index3]=toChar (new_v)};
where
	{
		new_v0 = toChar ((toInt v0 bitand 0xfc) bitor ((new_v>>24) bitand 3));
		
		new_v=v+w;
		v = ((toInt v0 bitand 3)<<24)+(toInt v1<<16)+(toInt v2<<8)+(toInt v3);

		index1 = index+1;
		index2 = index+2;
		index3 = index+3;
	}
	
/*
add_to_long_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_long_at_offset w index array
	# (s_array,array)
		= usize array;
	| index < 0 || index >= s_array
		= abort ("index out of range; index: " +++ toString index +++ " - size: " +++ toString s_array);
		= add_to_long_at_offset2 w index array;
*/

add_to_long_at_offset2 :: Int Int *{#Char} -> *{#Char};
add_to_long_at_offset2 w index array=:{[index]=v0,[index1]=v1,[index2]=v2,[index3]=v3}
	| v == 24
		= abort ("add_to_long_at_offset; address=" +++ toString new_v);
		= abort ("not 24" +++ toString v);	
	
/*
	= {array & [index]=toChar (new_v>>24),[index1]=toChar (new_v>>16),[index2]=toChar (new_v>>8),[index3]=toChar new_v};*/
	 where {
		new_v=v+w;
		v = (toInt v0<<24) + (toInt v1<<16)+(toInt v2<<8)+toInt v3;
		index1=index+1;
		index2=index+2;
		index3=index+3;
	}


add_to_long_at_offset :: Int Int *{#Char} -> *{#Char};
add_to_long_at_offset w index array=:{[index]=v0,[index1]=v1,[index2]=v2,[index3]=v3}
//	| FB (v == 24) "24 found" True
//	| v == 24
//		= abort ("add_to_long_at_offset; address=" +++ toString w);
	= {array & [index]=toChar (new_v>>24),[index1]=toChar (new_v>>16),[index2]=toChar (new_v>>8),[index3]=toChar new_v}; where {
		new_v=v+w;
		v = (toInt v0<<24) + (toInt v1<<16)+(toInt v2<<8)+toInt v3;
		index1=index+1;
		index2=index+2;
		index3=index+3;
	}

load_toc_after_branch :: Int *{#Char} -> *{#Char};
load_toc_after_branch index text0=:{[index4]=n0,[index5]=n1,[index6]=n2,[index7]=n3}
	| n0==toChar 0x60 && n1=='\0' && n2=='\0' && n3=='\0'
		= {text0 & [index4]=toChar 0x80,[index5]=toChar 0x41,[index6]=toChar 0x00,[index7]=toChar 0x14};
	{}{
		index4=index+4;
		index5=index+5;
		index6=index+6;
		index7=index+7;
	}