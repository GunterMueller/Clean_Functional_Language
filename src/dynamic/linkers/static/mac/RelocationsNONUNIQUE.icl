// NON-UNIQUE
// SymbolArray (=symbol_a) :== {!Symbol}
relocate_text :: Int Int !Int !Int !String !String SymbolsArray !Int {#Int} {#Int} !Int !Int !SymbolIndexList SymbolArray *String *String -> (!*String,!*String);
relocate_text relocation_n end_relocation_n /* start */ virtual_module_offset real_module_offset text_relocations data_relocations symbols_a first_symbol_n marked_offset_a0 module_offset_a /* end */ text_v_address data_v_address toc0_symbol symbol_a text_a0 data_section
	| relocation_n==end_relocation_n
		= (text_a0,data_section);
	| relocation_type==R_TRL && (relocation_size==0x8f || relocation_size==0x0f)
		= relocate_text (inc relocation_n) 
		end_relocation_n /* start */ virtual_module_offset real_module_offset text_relocations data_relocations symbols_a first_symbol_n marked_offset_a0 module_offset_a /* end */ text_v_address data_v_address toc0_symbol
		symbol_a text1 data_section1;
		{
			(text1,data_section1)
				= relocate_trl symbol_a.[relocation_symbol_n] symbol_a.[toc0_symbol_n] (relocation_offset-text_v_address) data_v_address
					module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a data_relocations text_a0 data_section;
	
			(SymbolIndex toc0_symbol_n _)=toc0_symbol;
		}
		
		= relocate_text (inc relocation_n) end_relocation_n /* start */ virtual_module_offset real_module_offset text_relocations data_relocations symbols_a first_symbol_n marked_offset_a0 module_offset_a /* end */ text_v_address data_v_address toc0_symbol symbol_a text1 data_section;
		{
			text1 = case relocation_type of {
				R_BR
					| relocation_size==0x8f
						-> /*F "R_BR: 1"*/ relocate_short_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset 
							real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a text_a0;
					| relocation_size==0x99
						-> relocate_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset
							real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a text_a0;
				R_TOC
					| relocation_size==0x8f || relocation_size==0x0f
						-> relocate_toc symbol_a.[relocation_symbol_n] symbol_a.[toc0_symbol_n] 
							(relocation_offset-text_v_address) module_offset_a first_symbol_n relocation_symbol_n marked_offset_a0 text_a0;
						{
							(SymbolIndex toc0_symbol_n _)=toc0_symbol;
						}
				R_REF
					-> text_a0;
				R_MW_BR
					| relocation_size==0x8f
						-> relocate_mw_short_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset 
							real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a text_a0;
					| relocation_size==0x99
						-> relocate_mw_branch symbol_a.[relocation_symbol_n] (relocation_offset-text_v_address) virtual_module_offset
							real_module_offset module_offset_a first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a text_a0;
				R_MW_TOC
					| relocation_size==0x8f || relocation_size==0x0f
						-> relocate_mw_toc symbol_a.[relocation_symbol_n]
							(relocation_offset-text_v_address) module_offset_a first_symbol_n relocation_symbol_n marked_offset_a0 text_a0;
				
				// relocations below only for {data,toc}-sections			
				R_POS
					| relocation_size==0x1f
						-> relocate_long_pos symbol_a.[relocation_symbol_n] (relocation_offset -  /*virtual_section_offset*/ /*data_v_address*/ text_v_address) module_offset_a 
									first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a /*data0*/ text_a0;
				R_MW_POS
					| relocation_size==0x1f
						-> relocate_mw_long_pos symbol_a.[relocation_symbol_n] (relocation_offset - /*virtual_section_offset*/ /*data_v_address*/ text_v_address) module_offset_a 
									first_symbol_n relocation_symbol_n symbol_a marked_offset_a0 symbols_a /*data0*/ text_a0;
				
			}
		}
	{							
		relocation_type=text_relocations BYTE (relocation_index+9);
		relocation_size=text_relocations BYTE (relocation_index+8);
		relocation_symbol_n=(inc (text_relocations LONG (relocation_index+4))) >> 1;
		relocation_offset=text_relocations LONG relocation_index;
	
		relocation_index=relocation_n * SIZE_OF_RELOCATION;
	}

// NON-UNIQUE
relocate_long_pos :: Symbol Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
relocate_long_pos (Module {section_n,module_offset=virtual_label_offset}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= add_to_long_at_offset (real_label_offset-virtual_label_offset) index data0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_long_pos (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= relocate_long_pos symbol_a.[module_n] index module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a data0;
relocate_long_pos (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
	| file_n<0
		=	add_to_long_at_offset real_label_offset index data0;
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		=	relocate_long_pos_of_module_in_another_module symbols_a.[file_n,symbol_n];
		{
			relocate_long_pos_of_module_in_another_module (Module {section_n})
				= add_to_long_at_offset real_label_offset index data0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
/*			relocate_long_pos_of_module_in_another_module (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n})
				= case symbols_a.[file_n,module_n] of {
					Module {section_n,module_offset=v_module_offset}
						-> add_to_long_at_offset (real_label_offset+(offset-v_module_offset)) index data0;
						{
							real_label_offset = module_offset_a.[first_symbol_n+module_n];
						}
				}
*/
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_long_pos (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
		=	case (symbols_a.[file_n,symbol_n]) of {
				Module {section_n}
					-> add_to_long_at_offset (real_label_offset+label_offset) index data0;
					{
						real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					}
			}
		{
			first_symbol_n = marked_offset_a0.[file_n];
		}
		
// NON-UNIQUE
relocate_short_branch :: Symbol Int Int Int {#Int} Int Int {!Symbol} *{#Char} -> *{#Char};
relocate_short_branch (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) index virtual_module_offset
		real_module_offset {[o_i]=real_label_offset} first_symbol_n symbol_n symbol_a text0
	= add_to_word_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0;
	{
		o_i=first_symbol_n+symbol_n;
	}
relocate_short_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset real_module_offset module_offset_a first_symbol_n symbol_n symbol_a text0
	= relocate_short_branch symbol_a.[module_n] index virtual_module_offset real_module_offset module_offset_a first_symbol_n module_n symbol_a text0;

// NON-UNIQUE
relocate_branch :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
relocate_branch (Module {section_n=TEXT_SECTION,module_offset=virtual_label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= add_to_branch_offset_at_offset ((virtual_module_offset-virtual_label_offset)+(real_label_offset-real_module_offset)) index text0;
	{
		real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= relocate_branch symbol_a.[module_n] index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;
relocate_branch (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	| file_n<0
		= load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0);
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		= relocate_branch_to_another_module symbols_a.[file_n,symbol_n] index virtual_module_offset
			real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
/*
			relocate_branch_to_another_module (Label TEXT_SECTION offset module_n) index virtual_module_offset 
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= relocate_branch_to_a_label_in_another_module symbol_a.[module_n] index (virtual_module_offset+offset)
					real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;

				relocate_branch_to_a_label_in_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
				relocate_branch_to_a_label_in_another_module (Module {section_n=TEXT_SECTION,module_offset=v_module_offset} index offset
						real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
					= add_to_branch_offset_at_offset ((offset-v_module_offset)+(real_label_offset-real_module_offset)) index text0;
					{
						real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
					}
*/
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_branch (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	=	case (symbols_a.[file_n,symbol_n]) of {
			Module {section_n=TEXT_SECTION}
				->	add_to_branch_offset_at_offset (virtual_module_offset+(real_label_offset-real_module_offset)+label_offset) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}	
		}
	{
		first_symbol_n = marked_offset_a0.[file_n];
	}
	
// NON-UNIQUE

/*
// NON UNIQUE
relocate_mw_short_branch (Module {section_n=TEXT_SECTION}) index virtual_module_offset real_module_offset {[o_i]=real_label_offset} first_symbol_n symbol_n symbol_a text0
	= add_to_word_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
	{
		o_i=first_symbol_n+symbol_n;
	}
relocate_mw_short_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset real_module_offset module_offset_a first_symbol_n symbol_n symbol_a text0
	= relocate_mw_short_branch symbol_a.[module_n] index virtual_module_offset real_module_offset module_offset_a first_symbol_n module_n symbol_a text0;
*/
relocate_mw_branch (Module {section_n=TEXT_SECTION}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
	{
		real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_branch (Label {label_section_n=TEXT_SECTION,label_offset=offset,label_module_n=module_n}) index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
	= relocate_mw_branch symbol_a.[module_n] index virtual_module_offset 
		real_module_offset module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a text0;
relocate_mw_branch (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	| file_n<0
		= load_toc_after_branch index (add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0);
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		= relocate_branch_to_another_module symbols_a.[file_n,symbol_n] index virtual_module_offset
			real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0;
		{
			relocate_branch_to_another_module :: Symbol Int Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray *{#Char} -> *{#Char};
			relocate_branch_to_another_module (Module {section_n=TEXT_SECTION}) index virtual_module_offset
					real_module_offset module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a text0
				= add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_mw_branch (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index virtual_module_offset
		real_module_offset module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a text0
	=	case (symbols_a.[file_n,symbol_n]) of {
			Module {section_n=TEXT_SECTION}
				->	add_to_branch_offset_at_offset (virtual_module_offset+real_label_offset-(real_module_offset+index)+label_offset) index text0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}	
		}
	{
		first_symbol_n = marked_offset_a0.[file_n];
	}
// NON_UNIQUE
relocate_trl :: Symbol Symbol Int Int {#Int} Int Int {!Symbol} {#Int} SymbolsArray String *String *String -> (!*String,!*String);
relocate_trl symbol toc0_symbol index data_v_address module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data_relocations text0 data0
	= case symbol of {
		Module {section_n=TOC_SECTION,length=4,first_relocation_n,end_relocation_n}
			| first_relocation_n+1==end_relocation_n && relocation_type==R_POS && relocation_size==0x1f
				-> relocate_trl1 relocation_index;
			{}{
				relocation_index=first_relocation_n * SIZE_OF_RELOCATION;
				
				relocation_type=data_relocations BYTE (relocation_index+9);
				relocation_size=data_relocations BYTE (relocation_index+8);
			}
		AliasModule {alias_first_relocation_n}
			-> relocate_trl1 relocation_index;
			{
				relocation_index=alias_first_relocation_n * SIZE_OF_RELOCATION;
			}
		_
			-> (relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data0);
	}
	{
		relocate_trl1 :: Int -> (!*String,!*String);
		relocate_trl1 relocation_index
			= relocate_trl2 symbol_a.[relocation_symbol_n] first_symbol_n relocation_symbol_n;
		{
			relocation_symbol_n=(inc (data_relocations LONG (relocation_index+4))) >> 1;
			relocation_offset=data_relocations LONG relocation_index;
		
			(offset,data1)=read_long data0 (relocation_offset-data_v_address);

			relocate_trl2 :: Symbol Int Int -> (!*String,!*String);
			relocate_trl2 (Module {section_n,module_offset=virtual_label_offset}) first_symbol_n symbol_n
				= relocate_trl3 section_n new_offset;
				{
					new_offset = real_label_offset+offset-virtual_label_offset;
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			relocate_trl2 (Label {label_offset=offset,label_module_n=module_n}) first_symbol_n symbol_n
				= relocate_trl2 symbol_a.[module_n] first_symbol_n module_n;
			relocate_trl2 (ImportedLabel {implab_file_n=imported_file_n,implab_symbol_n=imported_symbol_n}) first_symbol_n symbol_n
				| imported_file_n<0
					=	(relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data1);
					=	case (symbols_a.[imported_file_n,imported_symbol_n]) of {
							Module {section_n}
								-> relocate_trl3 section_n new_offset;
						};
						{
							new_offset=real_label_offset+offset;
							real_label_offset = module_offset_a.[marked_offset_a0.[imported_file_n]+imported_symbol_n];
						}
			relocate_trl2 (ImportedLabelPlusOffset {implaboffs_file_n=imported_file_n,implaboffs_symbol_n=imported_symbol_n,implaboffs_offset=label_offset}) first_symbol_n symbol_n
				=	case (symbols_a.[imported_file_n,imported_symbol_n]) of {
						Module {section_n}
							-> relocate_trl3 section_n new_offset;
					};
					{
						new_offset=real_label_offset+label_offset+offset;
						real_label_offset = module_offset_a.[marked_offset_a0.[imported_file_n]+imported_symbol_n];
					}

			relocate_trl3 :: Int Int -> (!*String,!*String);
			relocate_trl3 section_n new_offset
				| (section_n==DATA_SECTION || section_n==BSS_SECTION) && (new_offset bitand 0xffff)==new_offset
					= (change_lwz_to_addi (new_offset-32768) index text0,data1);
					= (relocate_toc symbol toc0_symbol index module_offset_a first_symbol_n symbol_n marked_offset_a0 text0,data1);
		}
	}
// NON-UNIQUE
relocate_mw_long_pos (Module {section_n,module_offset=virtual_label_offset}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= add_to_long_at_offset real_label_offset index data0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_long_pos (Label {label_section_n=section_n,label_offset=offset,label_module_n=module_n}) index module_offset_a first_symbol_n symbol_n symbol_a marked_offset_a0 symbols_a data0
	= relocate_mw_long_pos symbol_a.[module_n] index module_offset_a first_symbol_n module_n symbol_a marked_offset_a0 symbols_a data0;
relocate_mw_long_pos (ImportedLabel {implab_file_n=file_n,implab_symbol_n=symbol_n}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
	| file_n<0
		=	add_to_long_at_offset real_label_offset index data0;
		{
			real_label_offset = module_offset_a.[marked_offset_a0.[file_n + size marked_offset_a0]+symbol_n];
		}
		=	relocate_mw_long_pos_of_module_in_another_module symbols_a.[file_n,symbol_n];
		{
			relocate_mw_long_pos_of_module_in_another_module (Module {section_n})
				= add_to_long_at_offset real_label_offset index data0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
			first_symbol_n = marked_offset_a0.[file_n];
		}
relocate_mw_long_pos (ImportedLabelPlusOffset {implaboffs_file_n=file_n,implaboffs_symbol_n=symbol_n,implaboffs_offset=label_offset}) index module_offset_a first_symbol_n _ symbol_a marked_offset_a0 symbols_a data0
	=	case (symbols_a.[file_n,symbol_n]) of {
			Module {section_n}
				-> add_to_long_at_offset (real_label_offset+label_offset) index data0;
				{
					real_label_offset = module_offset_a.[first_symbol_n+symbol_n];
				}
		}
	{
		first_symbol_n = marked_offset_a0.[file_n];
	}
	
/*
// relocate_toc	
relocate_toc :: Symbol Symbol Int {#Int} Int Int {#Int} *{#Char} -> *{#Char};
relocate_toc (Module {section_n=TOC_SECTION,module_offset=virtual_label_offset}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-virtual_label_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_toc (AliasModule {alias_module_offset,alias_global_module_n}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-alias_module_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[alias_global_module_n];
	}
relocate_toc (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) (Module {/*section_n=TOC_SECTION,*/module_offset=virtual_toc0_offset}) index
				module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset ((virtual_toc0_offset-imptoc_offset)+real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[marked_offset_a.[imptoc_file_n + size marked_offset_a]+imptoc_symbol_n+1];
	}
*/

// NON-UNIQUE
/*
relocate_mw_toc (Module {section_n=TOC_SECTION}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[first_symbol_n+symbol_n];
	}
relocate_mw_toc (AliasModule {alias_global_module_n}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[alias_global_module_n];
	}
relocate_mw_toc (ImportedFunctionDescriptorTocModule {imptoc_file_n,imptoc_symbol_n}) index module_offset_a first_symbol_n symbol_n marked_offset_a text0
	=	add_to_word_at_offset (real_label_offset-32768) index text0;
	{
		real_label_offset=module_offset_a.[marked_offset_a.[imptoc_file_n + size marked_offset_a]+imptoc_symbol_n+1];
	}
*/
