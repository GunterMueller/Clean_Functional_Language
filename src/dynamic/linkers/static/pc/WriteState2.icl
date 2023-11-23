implementation module WriteState

from ExtString import ILONG;
from ExtFile import ExtractPathFileAndExtension, ExtractPathAndFile;
import xcoff;

import
	SymbolTable,
	State,
	ReadWriteState,
	LinkerOffsets,
	CommonObjectToDisk 

WriteXCoffArray :: !{#SXcoff} !Int !*File -> !*File
WriteXCoffArray xcoff_a i output
	| size xcoff_a == i 
		= output
		
		#! output
			= WriteXCoff xcoff_a.[i] output
		= WriteXCoffArray xcoff_a (inc i) output
//		= WriteXCoffArray xcoff_a (inc i) (fwrites (EncodeDataType xcoff_a.[i]) output)
		
/*
** ToString-class
*/
class 
	ToString a :: a -> {#Char}

/*
** ToString, Int-array
*/	
instance ToString (*{#Int})
where
	ToString a
		= EncodeString (to_string 0) //(FromIntToString (size a)) +++ (to_string 0)
	where
		to_string i
			| size a == i
				= ""
				= (FromIntToString a.[i]) +++ (to_string (inc i))

/*
** ToString, Symbol-array
*/	
instance ToString (*{!Symbol})
where
	ToString symbols_a
		= (FromIntToString (size symbols_a)) +++ (to_string 0)
	where
		n_symbols
			= size symbols_a
			
		to_string i
			| size symbols_a == i
				= ""
				= (EncodeDataType symbols_a.[i]) +++ (to_string (inc i))


WriteNamesTable :: !*State !*File -> (!*State,!*File)
WriteNamesTable state output 
	#! (namestable,state)
		= select_namestable state
	#! size_names_table
		= size namestable
	#! n_elements
		= CountNamesTableElements 0 size_names_table 0 namestable
//	#! output
//		= fwritei n_elements output
	= (state,write_names_table 0 size_names_table namestable output)	
	where					
		write_names_table i limit namestable file
			| i == limit
				= file
				
				#! file
					= write_names_table_elements namestable.[i] file
				=  write_names_table (inc i) limit namestable file	
		where
			write_names_table_elements EmptyNamesTableElement file
				= file
			write_names_table_elements (NamesTableElement s i0 i1 ntes) file
				#! file
					= fwrites s file
				#! file
					= fwritec '\n' file
				#! file
					= fwritei i0 file
				#! file
					= fwritei i1  file
				= write_names_table_elements ntes file
		
		/*
		** If the complement is extended, the amount of names table elements
		** need to be counted. Uncomment the comments above and in ReadState
		*/		
		CountNamesTableElements i limit n_names_table_elements namestable
			| i == limit
				=  n_names_table_elements
				
				#! n_names_table_elements
					= count n_names_table_elements namestable.[i]
				= CountNamesTableElements (inc i) limit n_names_table_elements namestable
			where
				count n_names_table_elements EmptyNamesTableElement
					=  n_names_table_elements
				count n_names_table_elements (NamesTableElement _ _ _ ntes)
					=  count (inc n_names_table_elements) ntes 
				
/*								
/*
** ToString, NamesTableElement
*/
instance ToString NamesTableElement
where
	ToString (NamesTableElement s i0 i1 ntes)
		= (EncodeString s) +++
			(EncodeInt i0) +++
			(EncodeInt i1) +++
			(ToString ntes)
			
	ToString EmptyNamesTableElement
		= ""
*/
									
/*
** Symbol: ToString, FromString and ==
*/

//		#! output
//						= WriteSymbol array.[i] output

WriteSymbol :: !Symbol !*File -> !*File
WriteSymbol (Module i0 i1 i2 i3 i4 i5 s) output
	#! output
		= fwritec (toChar MODULE_SYMBOL) output
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	#! output
		= fwritei i2 output
	#! output
		= fwritei i3 output
	#! output
		= fwritei i4 output
	#! output
		= fwritei i5 output
	#! output
		= fwritei (size s) output
	#! output
		= fwrites s output	
	= output
	
WriteSymbol (Label i0 i1 i2) output
	#! output
		= fwritec (toChar LABEL_SYMBOL) output
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	#! output
		= fwritei i2 output
	= output
	
WriteSymbol (SectionLabel i0 i1) output
	#! output
		= fwritec (toChar SECTIONLABEL_SYMBOL) output
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	= output

WriteSymbol (ImportLabel s) output
	#! output
		= fwritec (toChar IMPORTLABEL_SYMBOL) output
	#! output
		= fwritei (size s) output
	#! output
		= fwrites s output
	= output
	
WriteSymbol (ImportedLabel i0 i1) output
	#! output
		= fwritec (toChar IMPORTEDLABEL_SYMBOL) output 
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	= output
	
WriteSymbol (ImportedLabelPlusOffset i0 i1 i2) output
	#! output
		= fwritec (toChar IMPORTEDLABELPLUSOFFSET_SYMBOL) output 
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	#! output
		= fwritei i2 output
	= output
	
WriteSymbol (ImportedFunctionDescriptor i0 i1) output
	#! output
		= fwritec (toChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL) output 
	#! output
		= fwritei i0 output
	#! output
		= fwritei i1 output
	= output
	
WriteSymbol (EmptySymbol) output
	#! output
		= fwritec (toChar EMPTYSYMBOL_SYMBOL) output
	= output
	
instance ToString Symbol
where
	ToString (Module i0 i1 i2 i3 i4 i5 s)
		= (EncodeChar MODULE_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1) +++
			(EncodeInt i2) +++
			(EncodeInt i3) +++
			(EncodeInt i4) +++
			(EncodeInt i5) +++
			(EncodeString s)	
			
	ToString (Label i0 i1 i2)
		= (EncodeChar LABEL_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1) +++
			(EncodeInt i2)
			
	ToString (SectionLabel i0 i1)
		= (EncodeChar SECTIONLABEL_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1)
			
	ToString (ImportLabel s)
		= (EncodeChar IMPORTLABEL_SYMBOL) +++
			(EncodeString s)
			
	ToString (ImportedLabel i0 i1)
		= (EncodeChar IMPORTEDLABEL_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1) 
			
	ToString (ImportedLabelPlusOffset i0 i1 i2)
		= (EncodeChar IMPORTEDLABELPLUSOFFSET_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1) +++
			(EncodeInt i2)
			
	ToString (ImportedFunctionDescriptor i0 i1)
		= (EncodeChar IMPORTEDFUNCTIONDESCRIPTOR_SYMBOL) +++
			(EncodeInt i0) +++
			(EncodeInt i1)	
			
	ToString EmptySymbol
		= (EncodeChar EMPTYSYMBOL_SYMBOL)
		
/* 
** WARNING:
** The following two functions are machine dependent. An integer (4 bytes) is
** encoded in a string. The least significant is the first char, etc.
*/
FromIntToString :: !Int -> !String
FromIntToString v
	= { (toChar v), (toChar (v>>8)), (toChar (v>>16)), (toChar (v>>24)) }
	
	
FromStringToInt :: !String -> !Int
FromStringToInt array=:{[0]=v0, [1]=v1, [2]=v2, [3]=v3}
	= (toInt v0)+(toInt v1<<8)+(toInt v2<<16)+(toInt v3<<24);

/*
** END WARNING
*/

//EncodeString :: !String -> !String
EncodeString s :== ((FromIntToString (size s)) +++ s)



EncodeInt i :== (FromIntToString i)

//EncodeInt i :== toString i

EncodeChar i :== toString (toChar i)
EncodeDataType data :== ( ((FromIntToString (size s_data))) +++ s_data)
where
	s_data = ToString data

// ---------------------------------------------------------------------------------
WriteLibraryList :: !LibraryList !*File -> !*File
WriteLibraryList EmptyLibraryList output
	=  output
WriteLibraryList (Library s i0 lsl i1 ll) output
	#! output
		= fwrites s output
	#! output
		= fwritec '\n' output
	#! output
		= fwritei i0 output
	#! output
		= WriteLibrarySymbolsList lsl output
	#! output 
		= fwritei i1 output
	= WriteLibraryList ll output
where
	WriteLibrarySymbolsList lsl output
		#! output
			= fwritei (count lsl 0) output
		#! output
			= write_library_symbols_list lsl output
		= output
	where
		count EmptyLibrarySymbolsList i 
			= i
		count (LibrarySymbol _ lsl) i
			= count lsl (inc i)
	
		write_library_symbols_list EmptyLibrarySymbolsList output 
			= output
		write_library_symbols_list (LibrarySymbol s lsl) output
			#! output 
				= fwrites s output
			#! output
				= fwritec '\n' output
			= write_library_symbols_list lsl output

//#! output
//		= WriteLibraryList library_list
/*	 
	/*
	** Write library list
	*/
	#! library_list_s
		= ToString library_list
	#! output 
		= fwrites (EncodeString library_list_s) output
*/	  
/*
::	LibraryList = Library !String !Int !LibrarySymbolsList !Int !LibraryList 
				  | EmptyLibraryList;
*/

instance ToString !LibraryList
where
	ToString EmptyLibraryList
		= ""
	ToString (Library s i0 lsl i1 ll)
		= library_s +++ (ToString ll)
	where
		library_s
			= (EncodeString s) +++
				(EncodeInt i0) +++
				(EncodeDataType lsl) +++
				(EncodeInt i1)				
			
/*
::	LibrarySymbolsList = LibrarySymbol !String !LibrarySymbolsList 
						| EmptyLibrarySymbolsList;
*/			
instance ToString !LibrarySymbolsList
where
	ToString EmptyLibrarySymbolsList
		= ""
	ToString (LibrarySymbol s lsl)
		= s_s +++ (ToString lsl)
	where
		s_s 
			= (EncodeString s) 	
			
// ---------------------------------------------------------------------------------
						
/*
** SymbolIndexList: toString, fromString and ==
*/
instance ToString SymbolIndexList
where
	ToString EmptySymbolIndex
		= ""
	ToString (SymbolIndex i sil)
		= (EncodeInt i) +++ (ToString sil)

/*
** SSymbolTable: toString, fromString and ==
*/

WriteSymbolTable :: !SSymbolTable !*File -> !*File
WriteSymbolTable symboltable=:{text_symbols,data_symbols,bss_symbols,imported_symbols,section_symbol_ns,symbols} output
	#! output 
		= WriteSymbolIndexList text_symbols output
	#! output 
		= WriteSymbolIndexList data_symbols output
	#! output 
		= WriteSymbolIndexList bss_symbols output
	#! output 
		= WriteSymbolIndexList imported_symbols output
	#! output
		= WriteIntArray section_symbol_ns output
	#! output
		= WriteSymbolArray symbols output
	= output

	where	
		WriteSymbolIndexList symbols output
			#! output 
				= fwritei (count 0 symbols) output
			= write_symbol_index_list symbols output
		
			where
			 	count i EmptySymbolIndex 
					= i
				count i (SymbolIndex _ sil)
					= count (inc i) sil
					
				write_symbol_index_list EmptySymbolIndex output
					= output
				write_symbol_index_list (SymbolIndex i sil) output
					#! output
						= fwritei i output
					= write_symbol_index_list sil output
					
		WriteIntArray :: !{#Int} !*File -> !*File
		WriteIntArray array output
			#! output
				= fwritei (size array) output
			= write_int_array 0 (size array) array output
		where
			write_int_array i limit array output
				| i == limit
					= output
					
					#! output
						= fwritei array.[i] output
					= write_int_array (inc i) limit array output
					
		WriteSymbolArray :: {!Symbol} !*File -> !*File
		WriteSymbolArray array output
			= write_symbol_array 0 (size array) array output
		where
			write_symbol_array :: !Int !Int {!Symbol} !*File -> !*File
			write_symbol_array i limit array output
				| i == limit
					= output
					
					#! output
						= WriteSymbol array.[i] output
					= write_symbol_array (inc i) limit array output
				



instance ToString SSymbolTable
where
	ToString symboltable=:{text_symbols,data_symbols,bss_symbols,imported_symbols,section_symbol_ns,symbols}
		= (EncodeDataType text_symbols) +++
			(EncodeDataType data_symbols) +++
			(EncodeDataType bss_symbols) +++
			(EncodeDataType imported_symbols) +++
			(EncodeDataType section_symbol_ns) +++
			(EncodeDataType symbols)
	
/*
** *SXcoff: toString, fromString and ==
*/

instance ToString (*SXcoff)
where
	ToString xcoff=:{file_name,symbol_table,n_symbols}
		= (EncodeString file_name) +++
			(EncodeDataType symbol_table) +++
			(EncodeInt n_symbols)
			
		
		
WriteXCoff :: SXcoff !*File -> !*File
WriteXCoff xcoff=:{file_name,symbol_table,n_symbols} output
	#! output 
		= fwrites file_name output
	#! output
		= fwritec '\n' output
	#! output
		= fwritei n_symbols output
	= WriteSymbolTable symbol_table output
	
	
//	= fwrites (EncodeDataType symbol_table) output
			
//	#! output
//			= WriteXCoff xcoff_a.[i] output


		

/*
** =================================================================================
*/

do EmptySymbolIndex
	= ""
do (SymbolIndex i rest)
	= (toString i) +++ " - " +++ (do rest)

O :: {#Xcoff} {#Xcoff} -> Bool
O _ _
	= True
	
	
//Mouse :: *{#*SXcoff} *{#*SXcoff} -> *{#*SXcoff}
Mouse a b = a

// ---------------------------------------------------------------------------------
// invert_marked_bool_a

invert_marked_bool_a :: !*State -> (!*{#Bool},!*State)
invert_marked_bool_a state 
	#! (marked_bool_a, state)
		= select_marked_bool_a state
	#! (size, marked_bool_a)
		= usize marked_bool_a
	#! inverted_marked_bool_a
		= { False \\ i <- [1..size] }
	#! (inverted_marked_bool_a, marked_bool_a)
		= invert 0 size inverted_marked_bool_a marked_bool_a
	= (inverted_marked_bool_a,{state & marked_bool_a = marked_bool_a})
	
	where
		invert :: !Int !Int !*{#Bool} !*{#Bool} -> (!*{#Bool},!*{#Bool})
		invert i limit inverted_marked_bool_a marked_bool_a
			| i == limit
				= (inverted_marked_bool_a,marked_bool_a)
				
			#! (element,marked_bool_a)
				= marked_bool_a![i]
		//	| element
			= invert (inc i) limit {inverted_marked_bool_a & [i] = not element} marked_bool_a
		//		= invert (inc i) limit {inverted_marked_bool_a & [i] = False} marked_bool_a
				
// ---------------------------------------------------------------------------------
// Output
		
instance Output (!{#Char},!*File)
where
//	WriteOutput :: !WriteOutputRecord /*!Int !Int !{#Char}*/ (!*{#Char},!*File) -> (!*{#Char},!*File);
	WriteOutput {file_or_memory,offset,string} /*0 _ string*/ (data,file)
		= case file_or_memory of {
			0
				-> (data, fwrites string file);
			1
				-> (data +++ string, file);
				
			_
				-> abort "WriteState: internal error";
		};
			
	ChangeState {file_n,module_n,state} pe_file
		#! (Module i0 i1 i2 i3 offset i5 s, state)
			= sel_symbol file_n module_n state	
		/*
		** Retrieve the computed offset of module_n in the file
		*/	
		#! (first_symbol_n,state)
			= selacc_marked_offset_a file_n state
		#! (module_n_offset, state)
			= selacc_module_offset_a (first_symbol_n+module_n) state;	
		
	 	#! state
			= update_symbol (Module i0 i1 i2 i3 (module_n_offset+4) i5 s) file_n module_n state 
		= (state,pe_file);



/*
 	strip symbol table
 	
	marked internal references
	in principle after resolving it.  	
*/

strip_symbol_table :: !*State -> (!*{#Bool},!*State);
strip_symbol_table state=:{n_xcoff_symbols,n_library_symbols}
	#! references
		= createArray (n_xcoff_symbols + n_library_symbols) False;
	// each unmarked symbol having at least one reference is set to True
	#! (references,state)
		= mark_referenced_symbols_in_xcoff 0 0 references state;
		
	// mark external definitions
	#! (names_table,state)
		= select_namestable state;
	#! (s_names_table,names_table)
		= usize names_table;
	
	#! (references,names_table,state)
		= mark_external_definitions 0 s_names_table names_table references state;
		
	#! state
		= update_namestable names_table state;
		
	#! (references,state)
		= remove_unreferenced_symbols 0 0 references state;
		
	= (references,state); //abort ("a!" +++ (p 0 (size references) references "" )); //state; // abort "strip_symbol_tab";

/*
where {
	p i limit a s 
 		| i == limit
			= s
			
			#! (element,a)
				= a![i];
			= p (inc i) limit a (s +++ (if element "t" "f" ));
}
*/

remove_unreferenced_symbols :: !Int !Int !*{#Bool} !*State -> (!*{#Bool},!*State);
remove_unreferenced_symbols file_n first_symbol_n references state=:{n_xcoff_files}
	| file_n == n_xcoff_files // + n_libraries
		= (references,state);
		
		#! (n_symbols,state)
			= select_n_symbols file_n state;
		
		#! (references,state)
			= remove_unreferenced_symbols_in_xcoff 0 n_symbols references state;
		= remove_unreferenced_symbols (inc file_n) (first_symbol_n + n_symbols) references state;	
where //{
	remove_unreferenced_symbols_in_xcoff :: !Int !Int !*{#Bool} !*State -> (!*{#Bool},!*State);
	remove_unreferenced_symbols_in_xcoff symbol_n n_symbols references state
		| symbol_n == n_symbols
			= (references,state);
			
			#! (unreferenced_symbol,references)
				= references![first_symbol_n + symbol_n];
			| not unreferenced_symbol
				= remove_unreferenced_symbols_in_xcoff (inc symbol_n) n_symbols references state;
				
				// remove unreferenced symbol 
				//#! state
				//	= update_symbol EmptySymbol file_n symbol_n state;
				= remove_unreferenced_symbols_in_xcoff (inc symbol_n) n_symbols references state;
				
				//= abort "remove_unreferenced_symbols_in_xcoff";
//}
	
	
	
mark_external_definitions :: !Int !Int *NamesTable !*{#Bool} !*State -> (!*{#Bool},*NamesTable,!*State);
mark_external_definitions i limit names_table references state
	| i == limit
		= (references,names_table,state);
		
		#! (names_table_elements,names_table)
			= names_table![i];
		#! (references,state)
			= mark_names_table_elements names_table_elements references state;			
		= mark_external_definitions (inc i) limit names_table references state; 
where //{
	mark_names_table_elements EmptyNamesTableElement references state
		= (references,state);
	mark_names_table_elements (NamesTableElement _ symbol_n file_n ntes) references state
		#! (first_symbol_n,state)
			= case file_n < 0 of {
				True	-> selacc_so_marked_offset_a file_n state;
				False	-> selacc_marked_offset_a file_n state;	
			}
		#! references
			= { references & [first_symbol_n + symbol_n] = True };
		= mark_names_table_elements ntes references state;
//}

mark_referenced_symbols_in_xcoff :: !Int !Int !*{#Bool} !*State -> (!*{#Bool},!*State);
mark_referenced_symbols_in_xcoff file_n first_symbol_n references state=:{n_xcoff_files,n_xcoff_symbols,xcoff_a}
	| /*F (toString file_n)*/ file_n == n_xcoff_files
		= (references,state); //abort "strip_symbol_table";
		
		// for each symbol it must be known if there are references to it. Initially
		// there are no references to the symbols. A false in the reference-array 
		// means that for the corresponding symbol, no references exist.
		
		/*
			Purpose: removal of symbols not being used by references
			
			
		*/
		#! (n_symbols,state)
			= select_n_symbols file_n state;
//		#! references
//			= createArray n_symbols False;
		
		// text symbols
		#! (text_symbols,state)
			= selacc_text_symbols file_n state;
		#! (references,state)
			= mark_referenced_symbols text_symbols references state;
			
		// data symbols
		#! (data_symbols,state)
			= selacc_data_symbols file_n state;
		#! (references,state)
			= mark_referenced_symbols data_symbols references state;
			
		// bss symbols
		#! (bss_symbols,state)
			= selacc_data_symbols file_n state;
		#! (references,state)
			= mark_referenced_symbols bss_symbols references state;		
		
		#! s
			= (p 0 (size references) references "");
		
//		| True
//			= abort (p 0 (size references) references ""); //(toString (size references));
		
		= mark_referenced_symbols_in_xcoff (inc file_n) (first_symbol_n + n_symbols) references state;
where //{
	mark_referenced_symbols :: SymbolIndexList *{#Bool} !*State -> (*{#Bool},!*State);
	mark_referenced_symbols EmptySymbolIndex references state
		= (references,state);
		
	mark_referenced_symbols (SymbolIndex module_n sils) references state
	
		#! (marked_module_symbol,state)
			= selacc_marked_bool_a (first_symbol_n + module_n) state;
		| marked_module_symbol
			// references from marked symbols do not count anymore because
			// these have already been resolved; from the point of view of
			// the marked module these could already have been thrown out.
			// Thus the reference-array remains unchanged.
			= mark_referenced_symbols sils references state;

			// a unmarked module may contain references to other symbols.
			#! (Module _ _ _ _ _ n_relocations relocations,state)
				= sel_symbol file_n module_n state;
			#! (references,state)
				= mark_references 0 n_relocations references relocations state;
			= mark_referenced_symbols sils references state;
	where //{
		mark_references relocation_n n_relocations references relocations state
			| relocation_n == n_relocations
				= (references,state);

				#! (marked_relocation_symbol,state)
					= selacc_marked_bool_a (first_symbol_n + relocation_symbol_n) state;
				| marked_relocation_symbol
					= mark_references (inc relocation_n) n_relocations references relocations state;

					#! (at_least_one_reference,references)
						= references![first_symbol_n + relocation_symbol_n];
					| at_least_one_reference
						= mark_references (inc relocation_n) n_relocations references relocations state;
								
						#! references
							= { references & [first_symbol_n + relocation_symbol_n] = True };
						= mark_references (inc relocation_n) n_relocations references relocations state;
		where //{
			relocation_symbol_n=relocations ILONG (relocation_index+4);
			relocation_index=relocation_n * SIZE_OF_RELOCATION;
		//} 
//	}	
//}
				
WriteState :: !*State !*Files -> (!*State,!*Files)
WriteState state=:{n_libraries, n_xcoff_files, n_xcoff_symbols, n_library_symbols, library_list, application_name} /*, marked_bool_a, marked_offset_a, module_offset_a, xcoff_a, namestable}*/ files
	#! (path, file_name_with_extension)
		= ExtractPathAndFile application_name
	#! (file_name, _)
		= ExtractPathFileAndExtension file_name_with_extension
	#! state_file_name
		= if (path == "") (file_name +++ ".dat") (path +++ "\\" +++ file_name +++ ".dat")		
	#! (ok, output, files)
		= fopen state_file_name FWriteData files
	| not ok
		= abort "WriteState: fopen"
		
	/*
	** Compute offset of unmarked modules in .dat--file to be written
	*/
	// +4 voor de size
	#! (inverted_marked_bool_a,state)
		= invert_marked_bool_a state
		// strip_symbol_table :: !*State -> (!*{#Bool},!*State);

	#! (marked_bool_a,state)
		= select_marked_bool_a state
			
	#! (xcoff_a,state)
		= select_xcoff_a state
	#! xcoff_list 
		= xcoff_array_to_list 0 xcoff_a
 
	#! (module_offset_a,state)
		= select_module_offset_a state

	#! (inverted_marked_bool_a,text_end,module_offset_a,xcoff_list) 
		= compute_module_offsets Text 0 /* base */ xcoff_list 0 	   0 inverted_marked_bool_a module_offset_a
	#! (inverted_marked_bool_a,data_end,module_offset_a,xcoff_list)
		= compute_module_offsets Data 0 /* base */ xcoff_list text_end 0 inverted_marked_bool_a module_offset_a
	#! state = 
		{ state &
			xcoff_a = xcoff_list_to_xcoff_array xcoff_list n_xcoff_files,
			module_offset_a = module_offset_a,
			marked_bool_a = inverted_marked_bool_a
			
		}
		
/*
				#! nop_byte
					= toChar 0x90;
				#! s_data_section
					= section_headers.[DataSectionHeader].s_virtual_data;
				#! ((_,data,pe_file),state,files)
					= write_code_to_pe_filesD n_xcoff_files True 0 0 (0,0) state (0,createArray s_data_section nop_byte,pe_file) files;
*/
	
	#! output
		= fwritei data_end output
//	#! output
//		= F ("write_code: start" +++ toString data_end) output;
	
	// moved	
	#! alignment
		= 2;
	#! alignment_mask
		= dec (1 << alignment);
	#! aligned_text_end
		= (text_end + alignment_mask) bitand (bitnot alignment_mask);
	#! delta
		= aligned_text_end - text_end;

	// inserted
	#! nop_byte
		= toChar 0x90;
	#! s_data_section
		= data_end - aligned_text_end;
//	#! ((_,data,output),state,files)
//		= write_code_to_pe_filesD n_xcoff_files /*True*/ False 0 0 (0,0) state (0,createArray s_data_section nop_byte,output) files;

	#! ((data,output),state,files)
		= write_code_to_pe_files n_xcoff_files False 0 0 (0,0) state True ("",output) files  
//	| True
//		= abort data;		
	//		
	#! nop_byte
		= toChar 0x90;
	# output
		= fwrites (createArray delta nop_byte) output	
		
	#! (i,output)
		= fposition output
	| i <> (4 + text_end + delta)
		= abort ("WriteState: computed text size does not correspond with file offset" +++ (toString i))
	
	#! output
		= fwrites data output
	#! (i,output)
		= fposition output
	#! required_offset
		= 4 + data_end
	| i <> required_offset
		= abort ("Real: " +++ (toString required_offset) +++ " - " /* JOHN: hierna volgt bug  +++ (toString i) */)
		
	/*
	** JOHN:
	** De string concatenatie hierboven na het commentaar veroorzaakt de bug
	**
	** foutmelding: Integer expected at line 2348
	**
	** in WriteState.icl staat op deze regel:
	** update_a 0 -1
	*/ 
	#! state =
		{ state &
			marked_bool_a = marked_bool_a
		}
		
	/*
	** Pas op: je kunt niet zonder meer bytes voor de code/data gaan schrijven 
	** omdat de offsets vastliggen in de symbols voor elke module
	*/
		
	/*
	** Write counters
	*/
	#! output
		= fwritei n_libraries output 
	#! output
		= fwritei n_xcoff_files  output
	#! output
		= fwritei n_xcoff_symbols output
	#! output
		= fwritei n_library_symbols output
	
	#! output
		= WriteLibraryList library_list output
/*	 
	/*
	** Write library list
	*/
	#! library_list_s
		= ToString library_list
	#! output 
		= fwrites (EncodeString library_list_s) output
*/
		
	/*
	** Write marked_bool_a
	*/ 
	#! (marked_bool_a,state)
		= select_marked_bool_a state
	#! marked_bool_s
		= { if (is_true) ('T') ('F') \\ is_true <-: marked_bool_a }
	#! output
		= fwrites (EncodeString marked_bool_s) output
		
	/*
	** Write marked_offset_a
	*/
	#! (marked_offset_a,state)
		= select_marked_offset_a state
	#! marked_offset_l
		= [ i \\ i <-: marked_offset_a ]
	#! output
		= foldl (\f i -> fwrites (FromIntToString i) f ) (fwrites (FromIntToString (length marked_offset_l)) output) marked_offset_l

	/*
	** Write module_offset_a
	*/
	#! (module_offset_a,state)
		= select_module_offset_a state
	#! module_offset_l
		= [ i \\ i <-: module_offset_a ]
	#! output
		= foldl (\f i -> fwrites (FromIntToString i) f ) (fwrites (FromIntToString (length module_offset_l)) output) module_offset_l

	/*
	** Write xcoff_a
	** The total size in characters of the encoded array does not precede
	** the encoded array.
	*/ 
	#! (xcoff_a,state)
		= select_xcoff_a state
	#! output
		= WriteXCoffArray xcoff_a 0 output

	/*
	** write namestable
	*/
	#! (state,output)
		= WriteNamesTable state output
				
	/*
	** Close file
	*/
	#! (ok, files)
		= fclose output files			
	= ( state, files)	