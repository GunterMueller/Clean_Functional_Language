implementation module SymbolTable;

import StdEnv;
import NamesTable;
import pdSymbolTable;

foldSt op r l :== fold_st r l;
where {
	fold_st [] st		= st;
	fold_st [a:x] st	= fold_st x (op a st);
}
	
/* MAC:
create_xcoff_mark_and_offset_arrays2 :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
create_xcoff_mark_and_offset_arrays2 n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list list0
	=	(createArray (n_xcoff_symbols+n_library_symbols) False,offset_array1,xcoff_a);
	{
		(offset_array1,xcoff_a) = fill_offsets 0 0 list0 (createArray (n_xcoff_files+n_libraries) 0) (xcoff_array n_xcoff_files);

		xcoff_array :: Int -> *{#*Xcoff};
		xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};
		
		fill_offsets :: Int Int [*Xcoff] *{#Int} *{#*Xcoff} -> (!*{#Int},!*{#*Xcoff});
		fill_offsets file_n offset [xcoff=:{n_symbols}:xcoff_list] offset_array xcoff_a
			= fill_offsets (inc file_n) (offset+n_symbols) xcoff_list {offset_array & [file_n]=offset} {xcoff_a & [file_n]=xcoff};
		fill_offsets file_n offset [] offset_array xcoff_a
			= (fill_library_offsets library_list file_n offset offset_array,xcoff_a);
		
		fill_library_offsets :: LibraryList Int Int *{#Int} -> *{#Int};
		fill_library_offsets (Library _ symbols n_symbols libraries) file_n offset offset_array
			= fill_library_offsets libraries (inc file_n) (offset+n_symbols) {offset_array & [file_n]=offset};
		fill_library_offsets EmptyLibraryList file_n offset offset_array
			= offset_array;
	}
*/

create_xcoff_boolean_array :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});
create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list list0
	=	(createArray (n_xcoff_symbols+n_library_symbols) False, offset_array1,xcoff_a);
	{
		(offset_array1,xcoff_a)=fill_offsets 0 0 list0 (createArray (n_xcoff_files+n_libraries) 0)
				(xcoff_array n_xcoff_files);
				
		xcoff_array :: !Int -> *{#*Xcoff};
		xcoff_array n = { empty_xcoff \\ i<-[0..dec n]};

		
		fill_offsets :: Int Int [*Xcoff] *{#Int} *{#*Xcoff} -> (!*{#Int},!*{#*Xcoff});
		fill_offsets file_n offset [] offset_array xcoff_a
			= (fill_library_offsets library_list file_n offset offset_array,xcoff_a);
		fill_offsets file_n offset [xcoff=:{n_symbols}:xcoff_list] offset_array xcoff_a
			= fill_offsets (inc file_n) (offset+n_symbols) xcoff_list {offset_array & [file_n]=offset} {xcoff_a & [file_n]=xcoff};
	}

mark_modules_list :: ![String] !*[*Xcoff] !Int !Int !Int !LibraryList [(!Bool,!String,!Int,!Int)] !NamesTable -> (![String],!Int,!*{#Bool},!*{#Int},!*{#*Xcoff},!NamesTable);
mark_modules_list undefined_symbols xcoff_list n_xcoff_files n_libraries n_library_symbols library_list symbols names_table
	#! (n_xcoff_symbols,xcoff_list)
		= n_symbols_of_xcoff_list 0 xcoff_list;
	#! already_marked_bool_a 
		= createArray (n_xcoff_symbols+n_library_symbols) False;
	#! (marked_bool_a,marked_offset_a,xcoff_a)
		= create_xcoff_boolean_array n_xcoff_files n_xcoff_symbols n_libraries n_library_symbols library_list xcoff_list;
	#! (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,error)
		= foldSt find_index_pairs symbols (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,"");
	= (undefined_symbols,n_xcoff_symbols,marked_bool_a,marked_offset_a,xcoff_a,names_table)
where {
	find_index_pairs label=:(_,s,file_n,symbol_n) (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,"")
		// at this all root labels are defined
		#! (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a)
			= (mark_used_modules symbol_n file_n undefined_symbols already_marked_bool_a marked_bool_a marked_offset_a xcoff_a);  
				
		// NEUTRAL (undefined_symbols,marked_offset_a,marked_bool_a,xcoff_a);
		// PC (mark_used_modules symbol_n file_n undefined_symbols already_marked_bool_a marked_bool_a marked_offset_a xcoff_a);
		// MAC # (undefined_symbols,marked_bool_a,xcoff_a)	= mark_used_modules main_symbol_n main_file_n marked_bool_a marked_offset_a xcoff_a;
		= (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,"");
			
	find_index_pairs label (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,e)
		= (undefined_symbols,already_marked_bool_a,marked_bool_a,marked_offset_a,xcoff_a,names_table,e);

	find_name2 :: !String !NamesTable -> (!Bool,!Int,!Int,!NamesTable);
	find_name2 name names_table 
		# (names_table_element,names_table)
			= find_symbol_in_symbol_table name names_table;
		= case names_table_element of {
			(NamesTableElement _ symbol_n file_n _)
				-> (True,file_n,symbol_n,names_table);
			_
				-> (False,0,0,names_table);
	  }
}

n_symbols_of_xcoff_list :: Int ![*Xcoff] -> (!Int,![*Xcoff]);
n_symbols_of_xcoff_list n_symbols0 []
	= (n_symbols0,[]);
n_symbols_of_xcoff_list n_symbols0 [xcoff=:{n_symbols}:xcoff_list0]
	= (n_symbols1,[xcoff:xcoff_list1]);
	{
		(n_symbols1,xcoff_list1)=n_symbols_of_xcoff_list (n_symbols0+n_symbols) xcoff_list0;
	}

