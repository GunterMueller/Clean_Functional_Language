implementation module pdWriteState;

// macOS
from StdMisc import abort;
import SymbolTable;
import ReadWriteState;
import ExtFile;
import ExtArray;
import State;

write_xcoff :: !*Xcoff !*File -> (!*Xcoff,!*File);
write_xcoff xcoff=:{header,symbol_table,text_relocations,data_relocations,n_text_relocations,n_data_relocations,n_symbols} output
	#! output
		= write_header header output;
	#! (symbol_table,output)
		= write_symboltable symbol_table output;
		
	#! output = output
		FWI		size text_relocations
		FWS		text_relocations
		FWI		size data_relocations
		FWS		data_relocations
		FWI		n_text_relocations
		FWI		n_data_relocations
		FWI		n_symbols
		;
	= ({xcoff & symbol_table = symbol_table},output); 
where {
	write_header header=:{file_name,text_section_offset,text_section_size,data_section_offset,data_section_size,text_v_address,data_v_address} output
		#! output = output
			FWI size file_name
			FWS file_name
			FWI text_section_offset
			FWI text_section_size
			FWI data_section_offset
			FWI data_section_size
			FWI text_v_address
			FWI data_v_address
			;
		= output;
		
	write_symboltable symbol_table=:{text_symbols,data_symbols,toc_symbols,bss_symbols,toc0_symbol,imported_symbols,symbols} output
		#! output = output
			THEN write_symbol_index_list text_symbols
			THEN write_symbol_index_list data_symbols
			THEN write_symbol_index_list toc_symbols
			THEN write_symbol_index_list bss_symbols
			THEN write_symbol_index_list toc0_symbol
			THEN write_symbol_index_list imported_symbols
			;
		#! (symbols,output)
			= loopAonOutput write_symbol symbols output;
		= ({symbol_table & symbols = symbols},output);
	where {
		write_symbol_index_list sil output
			# output
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
		
		
		write_symbol (Module {section_n,module_offset,length,first_relocation_n,end_relocation_n,align}) output
			#! output = output	
				FWC (toChar MODULE_SYMBOL)
				FWI section_n
				FWI module_offset
				FWI length
				FWI first_relocation_n
				FWI end_relocation_n
				FWI align
				;
			= output;
			
		write_symbol (Label {label_section_n,label_offset,label_module_n}) output
			#! output = output
				FWC (toChar LABEL_SYMBOL)
				FWI label_section_n
				FWI label_offset
				FWI label_module_n
				;
			= output;
			
		write_symbol (ImportedLabel {implab_file_n,implab_symbol_n}) output
			#! output = output
				FWC (toChar IMPORTEDLABEL_SYMBOL)
				FWI implab_file_n
				FWI implab_symbol_n
				;
			= output;
			
		write_symbol (AliasModule {alias_module_offset,alias_first_relocation_n,alias_global_module_n}) output
			#! output = output
				FWC (toChar ALIAS_MODULE)
				FWI alias_module_offset
				FWI alias_first_relocation_n
				FWI alias_global_module_n
				;
			= output;
			
		write_symbol (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n,implaboffs_offset}) output
			#! output = output
				FWC (toChar IMPORTEDLABELPLUSOFFSET_SYMBOL)
				FWI implaboffs_file_n
				FWI implaboffs_symbol_n
				FWI implaboffs_offset
				;
			= output; 
			
		write_symbol (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) output
			#! output = output
				FWC (toChar IMPORTEDFUNCTIONDESCRIPTORTOCMODULE_SYMBOL)
				FWI imptoc_offset
				FWI imptoc_file_n
				FWI imptoc_symbol_n
				;
			= output;
			
		write_symbol (ImportedFunctionDescriptor {implab_file_n,implab_symbol_n}) output
			#! output = output
				FWC (toChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL)
				FWI implab_file_n
				FWI implab_symbol_n
				;
			= output;
			
		write_symbol EmptySymbol output
			#! output = output
				FWC (toChar EMPTYSYMBOL_SYMBOL)
				;
			= output;
		
	} // write_symboltabel
	
} // WriteXCoff
/*

where {
	write_header header=:{file_name,text_section_offset,text_section_size,data_section_offset,data_section_size,text_v_address,data_v_address} output
		#! output = output
			FWI size file_name
			FWS file_name
			FWI text_section_offset
			FWI text_section_size
			FWI data_section_offset
			FWI data_section_size
			FWI text_v_address
			FWI data_v_address
			;
		= output;
		
	write_symboltable symbol_table=:{text_symbols,data_symbols,toc_symbols,bss_symbols,toc0_symbol,imported_symbols,symbols} output
		#! output = output
			THEN write_symbol_index_list text_symbols
			THEN write_symbol_index_list data_symbols
			THEN write_symbol_index_list toc_symbols
			THEN write_symbol_index_list bss_symbols
			THEN write_symbol_index_list toc0_symbol
			THEN write_symbol_index_list imported_symbols
			;
		#! output
			= write_symbols symbols output;
		= output;
	where {
		write_symbol_index_list sil output
			# output
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
		
		
		write_symbols symbols output
			#! output 
				= fwritei (size symbols) output;
			#! (_,output)
				= loopA write_symbol symbols output;
			= output;
		where {
			write_symbol (Module {section_n,module_offset,length,first_relocation_n,end_relocation_n,align}) output
				#! output = output	
					FWC (toChar MODULE_SYMBOL)
					FWI section_n
					FWI module_offset
					FWI length
					FWI first_relocation_n
					FWI end_relocation_n
					FWI align
					;
				= output;
				
			write_symbol (Label {label_section_n,label_offset,label_module_n}) output
				#! output = output
					FWC (toChar LABEL_SYMBOL)
					FWI label_section_n
					FWI label_offset
					FWI label_module_n
					;
				= output;
				
			write_symbol (ImportedLabel {implab_file_n,implab_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTLABEL_SYMBOL)
					FWI implab_file_n
					FWI implab_symbol_n
					;
				= output;
				
			write_symbol (AliasModule {alias_module_offset,alias_first_relocation_n,alias_global_module_n}) output
				#! output = output
					FWC (toChar ALIAS_MODULE)
					FWI alias_module_offset
					FWI alias_first_relocation_n
					FWI alias_global_module_n
					;
				= output;
				
			write_symbol (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n,implaboffs_offset}) output
				#! output = output
					FWC (toChar IMPORTEDLABELPLUSOFFSET_SYMBOL)
					FWI implaboffs_file_n
					FWI implaboffs_symbol_n
					FWI implaboffs_offset
					;
				= output; 
				
			write_symbol (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTEDFUNCTIONDESCRIPTORTOCMODULE_SYMBOL)
					FWI imptoc_offset
					FWI imptoc_file_n
					FWI imptoc_symbol_n
					;
				= output;
				
			write_symbol (ImportedFunctionDescriptor {implab_file_n,implab_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL)
					FWI implab_file_n
					FWI implab_symbol_n
					;
				= output;
				
			write_symbol EmptySymbol output
				#! output = output
					FWC (toChar EMPTYSYMBOL_SYMBOL)
					;
				= output;
		} // write_symbols
		
	} // write_symboltabel
	
} // WriteXCoff
*/

/*
WriteXCoff :: !Xcoff !*File -> !*File;
WriteXCoff xcoff=:{header,symbol_table,text_relocations,data_relocations,n_text_relocations,n_data_relocations,n_symbols} output
	#! output = output
		THEN	write_header header
		THEN	write_symboltable symbol_table
		FWI		size text_relocations
		FWS		text_relocations
		FWI		size data_relocations
		FWS		data_relocations
		FWI		n_text_relocations
		FWI		n_data_relocations
		FWI		n_symbols
		;
	= output; 
where {
	write_header header=:{file_name,text_section_offset,text_section_size,data_section_offset,data_section_size,text_v_address,data_v_address} output
		#! output = output
			FWI size file_name
			FWS file_name
			FWI text_section_offset
			FWI text_section_size
			FWI data_section_offset
			FWI data_section_size
			FWI text_v_address
			FWI data_v_address
			;
		= output;
		
	write_symboltable symbol_table=:{text_symbols,data_symbols,toc_symbols,bss_symbols,toc0_symbol,imported_symbols,symbols} output
		#! output = output
			THEN write_symbol_index_list text_symbols
			THEN write_symbol_index_list data_symbols
			THEN write_symbol_index_list toc_symbols
			THEN write_symbol_index_list bss_symbols
			THEN write_symbol_index_list toc0_symbol
			THEN write_symbol_index_list imported_symbols
			;
		#! output
			= write_symbols symbols output;
		= output;
	where {
		write_symbol_index_list sil output
			# output
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
		
		
		write_symbols symbols output
			#! output 
				= fwritei (size symbols) output;
			#! (_,output)
				= loopA write_symbol symbols output;
			= output;
		where {
			write_symbol (Module {section_n,module_offset,length,first_relocation_n,end_relocation_n,align}) output
				#! output = output	
					FWC (toChar MODULE_SYMBOL)
					FWI section_n
					FWI module_offset
					FWI length
					FWI first_relocation_n
					FWI end_relocation_n
					FWI align
					;
				= output;
				
			write_symbol (Label {label_section_n,label_offset,label_module_n}) output
				#! output = output
					FWC (toChar LABEL_SYMBOL)
					FWI label_section_n
					FWI label_offset
					FWI label_module_n
					;
				= output;
				
			write_symbol (ImportedLabel {implab_file_n,implab_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTLABEL_SYMBOL)
					FWI implab_file_n
					FWI implab_symbol_n
					;
				= output;
				
			write_symbol (AliasModule {alias_module_offset,alias_first_relocation_n,alias_global_module_n}) output
				#! output = output
					FWC (toChar ALIAS_MODULE)
					FWI alias_module_offset
					FWI alias_first_relocation_n
					FWI alias_global_module_n
					;
				= output;
				
			write_symbol (ImportedLabelPlusOffset {implaboffs_file_n,implaboffs_symbol_n,implaboffs_offset}) output
				#! output = output
					FWC (toChar IMPORTEDLABELPLUSOFFSET_SYMBOL)
					FWI implaboffs_file_n
					FWI implaboffs_symbol_n
					FWI implaboffs_offset
					;
				= output; 
				
			write_symbol (ImportedFunctionDescriptorTocModule {imptoc_offset,imptoc_file_n,imptoc_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTEDFUNCTIONDESCRIPTORTOCMODULE_SYMBOL)
					FWI imptoc_offset
					FWI imptoc_file_n
					FWI imptoc_symbol_n
					;
				= output;
				
			write_symbol (ImportedFunctionDescriptor {implab_file_n,implab_symbol_n}) output
				#! output = output
					FWC (toChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL)
					FWI implab_file_n
					FWI implab_symbol_n
					;
				= output;
				
			write_symbol EmptySymbol output
				#! output = output
					FWC (toChar EMPTYSYMBOL_SYMBOL)
					;
				= output;
		} // write_symbols
		
	} // write_symboltabel
	
} // WriteXCoff
*/
import
	LinkerOffsets,
	CommonObjectToDisk,
	xcoff,
	ExtString,
	ExtInt;
	

loopAinc f a s inc_i :== loop2 f s a inc_i
where
{
	loop2 f s a inc_i
		#! (s_a,a)
			= usize a;
		= loop 0 s_a a s f inc_i;
		 
	loop i limit a s f inc_i
		| i == limit
			= (a,s)
			
			#! s
				= f i s;
			= loop (i + inc_i) limit a s f inc_i;
}

instance Target2 (*File,Int,WriteKind)
where {
	// step 1
	BeforeWritingXcoffFile file_n (pef_file,_,write_kind) state
		# (new_text_or_data_section_offset,pef_file)
			= fposition pef_file;
		# (text_or_data_v_address,state)
			= case write_kind of {
				WriteText
					-> selacc_xcoff file_n (\xcoff=:{header} -> (header.text_v_address,{xcoff & header = {header & text_section_offset = new_text_or_data_section_offset}})) state;
				WriteDataAndToc
					-> selacc_xcoff file_n (\xcoff=:{header} -> (header.data_v_address,{xcoff & header = {header & data_section_offset = new_text_or_data_section_offset}})) state;
			};
//		| F ("v_address: " +++ toString text_or_data_v_address) True
		= ((pef_file,text_or_data_v_address,write_kind),state);

	// step 2
	DoRelocations pef_file
		= (False,pef_file);

	// step 3
	WriteOutput {file_or_memory,offset,string,file_n,module_n,state} (pef_file,section_offset,write_kind)
//		| F ("WriteOutput: " +++ toString section_offset +++ " - " +++ toString (size string)) True
		// write part of .text or .data (also toc)
		#! pef_file
			= fwrites string pef_file;
			
		// update (relative) module_offset in symbol to its new offset within new .text
		#! (Module module1=:{first_relocation_n,end_relocation_n,module_offset=old_module_offset,length},state)
			= sel_symbol file_n module_n state;
		#! state
			= update_symbol (Module {module1 & module_offset = section_offset}) file_n module_n state;
			
		// now update the virtual addresses of its relocations; OPTIMALISATION *VERY* NECESSARY!!!; per xcoff and unique
		#! ((text_or_data_v_address,n_relocations,relocations),state)
			= case write_kind of {
				WriteText
					-> selacc_xcoff file_n (\xcoff=:{header={text_v_address},text_relocations,n_text_relocations} -> ((text_v_address,n_text_relocations,text_relocations),xcoff)) state;
				WriteDataAndToc
					-> selacc_xcoff file_n (\xcoff=:{header={data_v_address},data_relocations,n_data_relocations} -> ((data_v_address,n_data_relocations,data_relocations),xcoff)) state;
			};
		#! (_,new_relocations)
			= loopAinc (g section_offset text_or_data_v_address length relocations old_module_offset) relocations (createArray (n_relocations * SIZE_OF_RELOCATION)' ') SIZE_OF_RELOCATION;
		#! state
			= case write_kind of {
				WriteText
					-> selapp_xcoff file_n (\xcoff -> {xcoff & text_relocations = new_relocations}) state;
				WriteDataAndToc
					-> selapp_xcoff file_n (\xcoff -> {xcoff & data_relocations = new_relocations}) state;
			};
		= ((pef_file,section_offset + size string,write_kind),state);
	where {
		g section_offset text_v_address length relocations old_module_offset relocation_index new_relocations
			// get a virtual address within {.text,.data} section
			#! relocation_offset
				= relocations LONG relocation_index;
				
			// copy a long to new array
			#! (n_bytes,new_index,new_relocations)
				= case (relocation_offset>=old_module_offset && relocation_offset<old_module_offset+length) of {
					True
						// compute offset from the module
						#! offset_from_module
							= relocation_offset - old_module_offset;
						#! new_relocations
							= write_long (section_offset + offset_from_module) relocation_offset new_relocations;
						-> (SIZE_OF_RELOCATION - 4,relocation_index + 4,new_relocations);

					False
						-> (SIZE_OF_RELOCATION,relocation_index,new_relocations);
				};
				
			// copy SIZE_OF_RELOCATION - 4 (for long) bytes
			#! new_relocations
				= copy_bytes n_bytes new_index new_relocations;
			= new_relocations;
		where {
			copy_bytes 0 index s
				= s;
			copy_bytes n_bytes index s 
				= copy_bytes (dec n_bytes) (inc index) {s & [index] = relocations.[index]};
		}
	} // WriteOutput

	// step 4
	WriteLong w pef_file
		= abort "WriteLong"; //fwritei w pef_file;
	
	// step 5		
	AfterWritingXcoffFile file_n (pef_file,new_text_or_data_section_size,write_kind) state
		// change header to reflect new size of .text
		# state
			= case write_kind of {
				WriteText
					-> selapp_xcoff file_n (\xcoff=:{header} -> {xcoff & header = {header & text_section_size = new_text_or_data_section_size}}) state;
				WriteDataAndToc
					-> selapp_xcoff file_n (\xcoff=:{header} -> {xcoff & header = {header & data_section_size = new_text_or_data_section_size}}) state;
			};
		= ((pef_file,0,write_kind),state);
};

import DebugUtilities;

// write raw data of unmarked symbols
write_raw_data :: !*State !*File !*Files -> (!*State,!*File,!*Files);
write_raw_data state=:{n_xcoff_files} output files		
	# sections
		= EndSections;	// SHOULD BE PASSED BY LINKER TO AVOID READING OBJECT FILES TWICE	

	// write text symbols	
	# ((_,data_sections,(output,_,_), state),files)
		= write_to_pef_files2 0 WriteText { {} \\ i <- [1..n_xcoff_files]} 0 /* offset: */ 0 state sections (output,0,WriteText) files;

	// write data symbols
	# ((_,data_sections,(output,_,_), state),files)
		= write_to_pef_files2 0 WriteDataAndToc data_sections 0 0 state EndSections (output,0,WriteDataAndToc) files;		
	= (state,output,files);
		
