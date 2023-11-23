implementation module pdReadState;

// macOS

import StdArray;

import SymbolTable;
import ExtFile;
import ReadWriteState;

read_xcoff :: !String !Int !{#*Xcoff} !*File -> !(!{#*Xcoff},!*File);
read_xcoff state_file_name i xcoff_a input
	#! (file_name,header,input)
		= read_header input;
	#! (symbol_table,input)
		= read_symboltable input;
		
	// read text relocations
	#! (_,s_text_relocations,input)
		= freadi input;
	#! (text_relocations,input)
		= freads input s_text_relocations;
		
	// read data_relocations
	#! (_,s_data_relocations,input)
		= freadi input;
	#! (data_relocations,input)
		= freads input s_data_relocations;
		
	#! (_,n_text_relocations,input)
		= freadi input;
	#! (_,n_data_relocations,input)
		= freadi input;
	#! (_,n_symbols,input)
		= freadi input;
	
	// update xcoff
	#! xcoff 
		= { Xcoff |
			module_name			= extract_module_name file_name
		,	header				= header
		,	symbol_table		= symbol_table
		,	text_relocations	= text_relocations
		,	data_relocations	= data_relocations
		,	n_text_relocations	= n_text_relocations
		,	n_data_relocations	= n_data_relocations
		,	n_symbols			= n_symbols
		};
	= ({xcoff_a & [i] = xcoff},input);
where {
	read_header input
		// old
		// read file_name
		#! (_,s_file_name,input)
			= freadi input;
		#! (file_name,input)
			= freads input s_file_name;

//		#! file_name
//			= state_file_name;
			
		// read text section data
		#! (_,text_section_offset,input)
			= freadi input;
		#! (_,text_section_size,input)
			= freadi input;
			
		// read data section data
		#! (_,data_section_offset,input)
			= freadi input;
		#! (_,data_section_size,input)
			= freadi input;
			
		// read virtual address of {text,data} section within xcoff
		#! (_,text_v_address,input)
			= freadi input;
		#! (_,data_v_address,input)
			= freadi input;
			
		// update header
		#! header 
			= { XcoffHeader |
				file_name			= state_file_name
			,	text_section_offset	= text_section_offset
			,	text_section_size	= text_section_size
			,	data_section_offset	= data_section_offset
			,	data_section_size	= data_section_size
			,	text_v_address		= text_v_address
			,	data_v_address		= data_v_address
			};
		= (file_name,header,input);
		
	read_symboltable input
		// read {text,data,toc,bss,toc0,imported_symbols} symbols
		#! (text_symbols,input)
			= read_symbol_index_list input;
		#! (data_symbols,input)
			= read_symbol_index_list input;
		#! (toc_symbols,input)
			= read_symbol_index_list input;
		#! (bss_symbols,input)
			= read_symbol_index_list input;
		#! (toc0_symbol,input)
			= read_symbol_index_list input;
		#! (imported_symbols,input)
			= read_symbol_index_list input;
			
		// read symbols
		#! (symbols,input)
			= loopAfillOnInput read_symbol input
			
		// update symbol_table
		#! symbol_table
			= { SymbolTable |
				text_symbols		= text_symbols
			,	data_symbols		= data_symbols
			,	toc_symbols			= toc_symbols
			,	bss_symbols			= bss_symbols
			,	toc0_symbol			= toc0_symbol
			,	imported_symbols	= imported_symbols
			,	symbols				= symbols
			};
		= (symbol_table,input);
	where {
		read_symbol_index_list input
			#! (_,s_symbol_index_list,input)
				= freadi input;
			= read_symbol_index_list s_symbol_index_list input;
		where {
			read_symbol_index_list 0 input
				= (EmptySymbolIndex,input);
			read_symbol_index_list s_symbol_index_list input
				#! (_,symbol_n,input)
					= freadi input;
				#! (sils,input)
					= read_symbol_index_list (dec s_symbol_index_list) input;
				= (SymbolIndex symbol_n sils,input);
		} // read_symbol_index_list
	
		read_symbol :: !Int !*{!Symbol} !*File -> (!*{!Symbol},!*File);	
		read_symbol i symbols_a input
			#! (symbol,input)
				= read_symbol input;
			= ({symbols_a & [i] = symbol},input);
		where {
			read_symbol input
				#! (_,symbol_kind, input)
					= freadc input;
				= case (toInt symbol_kind) of {
					MODULE_SYMBOL
						#! (_,section_n,input)
							= freadi input;
						#! (_,module_offset,input)
							= freadi input;
						#! (_,length,input)
							= freadi input;
						#! (_,first_relocation_n,input)
							= freadi input;
						#! (_,end_relocation_n,input)
							= freadi input;
						#! (_,align,input)
							= freadi input;
						
						// update module symbol
						#! module_symbol
							= { Module |
								section_n			= section_n
							,	module_offset		= module_offset
							,	length				= length
							,	first_relocation_n	= first_relocation_n
							,	end_relocation_n	= end_relocation_n
							,	align				= align
							};
						-> (Module module_symbol,input);
						
					LABEL_SYMBOL
						#! (_,label_section_n,input)
							= freadi input;
						#! (_,label_offset,input)
							= freadi input;
						#! (_,label_module_n,input)
							= freadi input;
						
						// update label symbol
						#! label_symbol
							= { Label |
								label_section_n		= label_section_n
							,	label_offset		= label_offset
							,	label_module_n		= label_module_n
							};
						-> (Label label_symbol,input);
						
					IMPORTEDLABEL_SYMBOL
						#! (_,implab_file_n,input)
							= freadi input;
						#! (_,implab_symbol_n,input)
							= freadi input;
						
						// update imported label symbol
						#! imported_label
							= { ImportedLabel |
								implab_file_n		= implab_file_n
							,	implab_symbol_n		= implab_symbol_n
							};
						-> (ImportedLabel imported_label,input);
						
					ALIAS_MODULE
						#! (_,alias_module_offset,input)
							= freadi input;
						#! (_,alias_first_relocation_n,input)
							= freadi input;
						#! (_,alias_global_module_n,input)
							= freadi input;
							
						// update alias module
						#! alias_module
							= { AliasModule |
								alias_module_offset			= alias_module_offset
							,	alias_first_relocation_n	= alias_first_relocation_n
							,	alias_global_module_n		= alias_global_module_n
							};
						-> (AliasModule alias_module,input);
						
					IMPORTEDLABELPLUSOFFSET_SYMBOL
						#! (_,implaboffs_file_n,input)
							= freadi input;
						#! (_,implaboffs_symbol_n,input)
							= freadi input;
						#! (_,implaboffs_offset,input)
							= freadi input;
							
						// update imported label plus offset symbol
						#! imported_label_plus_offset
							= { ImportedLabelPlusOffset |
								implaboffs_file_n			= implaboffs_file_n
							,	implaboffs_symbol_n			= implaboffs_symbol_n
							,	implaboffs_offset			= implaboffs_offset
							};
						-> (ImportedLabelPlusOffset imported_label_plus_offset,input);
						
					IMPORTEDFUNCTIONDESCRIPTORTOCMODULE_SYMBOL
						#! (_,imptoc_offset,input)
							= freadi input;
						#! (_,imptoc_file_n,input)
							= freadi input;
						#! (_,imptoc_symbol_n,input)
							= freadi input;
							
						// update imported function descriptor toc module symbol
						#! imported_function_descriptor_toc_module
							= { ImportedFunctionDescriptorTocModule |
								imptoc_offset				= imptoc_offset
							,	imptoc_file_n				= imptoc_file_n
							,	imptoc_symbol_n				= imptoc_symbol_n
							};
						-> (ImportedFunctionDescriptorTocModule imported_function_descriptor_toc_module,input);
						
					IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL
						#! (_,implab_file_n,input)
							= freadi input;
						#! (_,implab_symbol_n,input)
							= freadi input;
						
						// update imported label symbol
						#! imported_label
							= { ImportedLabel |
								implab_file_n		= implab_file_n
							,	implab_symbol_n		= implab_symbol_n
							};
						-> (ImportedFunctionDescriptor imported_label,input);
						
					EMPTYSYMBOL_SYMBOL
						-> (EmptySymbol, input);
						
					i
						-> abort (toString i);
					
						
					
						
						
				}; // case
			
			
		} // read_symbol
		
	} // read_symboltable
			
} // read_xcoff
	