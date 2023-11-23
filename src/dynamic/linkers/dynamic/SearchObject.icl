implementation module SearchObject;

/*
	problem: (from the perspective of the dynamic linker)
	
	assume a running application uses object from module x. The application uses a dynamic which
	in turn uses also a module y. If x <> y then there is no problem. But if x == y then, we have
	a problem.
	
	Are the running application and the dynamic using the same (object) module or are there two
	different but equally named (object) modules?
	
	To answer this question more information is needed. We cannot conclude soley from the modules
	whether the object module is shared or not. Here the type system comes in. Based on the type
	information available in each (object) module, the type system can decide whether a module is
	usable for the application and/or dynamic.
	
	If it decides that the module x can be shared between the application and its dynamic then
	there is no problem. But if not, there is a serious problem: we have two *equally* named 
	(object) modules (e.g. both modules are named x) with differently typed objects. The linker
	can however not load two equally named object modules and consider them different. Somehow
	we have to load them both!

	Solution: for the moment it is assumed that all loaded modules have *different* names
*/

import State;
import StdEnv;
import pdSymbolTable;

add_module :: !*Xcoff !State -> State;
add_module xcoff=:{n_symbols=n_new_xcoff_symbols} state=:{n_xcoff_files,n_xcoff_symbols,n_library_symbols}
	// HACK: see InitialLink2 in ObjectToMem.icl; it is a way to pass on the absolute address of the
	//       qd symbol.
//		#! (qd_address,state)
//				= acc_pd_state (\pd_state=:{qd_address} -> (qd_address,pd_state)) state;

	#! (marked_bool_a,state)
		= select_marked_bool_a state;
	#! (marked_offset_a,state)
		= select_marked_offset_a state;
	#! (module_offset_a,state)
		= select_module_offset_a state;
	#! n_xcoff_files_plus_libraries 
		= size marked_offset_a;
	#! n_symbols 
		= n_xcoff_symbols + n_new_xcoff_symbols + n_library_symbols;
		
	# marked_bool_a2 = createArray n_symbols False;
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};
	
	# marked_offset_a2 = createArray (n_xcoff_files_plus_libraries+1) 0;
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i] \\ i<-[0..n_xcoff_files-1]};
	  marked_offset_a2 = {marked_offset_a2 & [n_xcoff_files] = n_xcoff_symbols};
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i-1]+n_new_xcoff_symbols \\ i<-[n_xcoff_files+1..n_xcoff_files_plus_libraries]};

	# module_offset_a2 = createArray n_symbols 0; 
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};

	#! state 
		= update_state_with_xcoff xcoff state;
		
	= { state & 
		n_xcoff_files = n_xcoff_files + 1,
		n_xcoff_symbols = n_xcoff_symbols + n_new_xcoff_symbols,
		
		marked_bool_a = marked_bool_a2,
		marked_offset_a = marked_offset_a2,
		module_offset_a = module_offset_a2
	  };

add_module2 :: !*Xcoff !State -> State;
add_module2 xcoff=:{n_symbols=n_new_xcoff_symbols} state=:{n_xcoff_files,n_xcoff_symbols,n_library_symbols}
	// HACK: see InitialLink2 in ObjectToMem.icl; it is a way to pass on the absolute address of the
	//       qd symbol.
//		#! (qd_address,state)
//				= acc_pd_state (\pd_state=:{qd_address} -> (qd_address,pd_state)) state;

	#! (marked_bool_a,state) = select_marked_bool_a state;
	#! (marked_offset_a,state) = select_marked_offset_a state;
	#! (module_offset_a,state) = select_module_offset_a state;
	#! n_xcoff_files_plus_libraries = size marked_offset_a;
	#! n_symbols = n_xcoff_symbols + n_new_xcoff_symbols + n_library_symbols;

	# marked_bool_a2 = createArray n_symbols False;
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};
	
	# marked_offset_a2 = createArray (n_xcoff_files_plus_libraries+1) 0;
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i] \\ i<-[0..n_xcoff_files-1]};
	  marked_offset_a2 = {marked_offset_a2 & [n_xcoff_files] = n_xcoff_symbols};
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i-1]+n_new_xcoff_symbols \\ i<-[n_xcoff_files+1..n_xcoff_files_plus_libraries]};

	# module_offset_a2 = createArray n_symbols 0;
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};

	#! state = update_state_with_xcoff xcoff state;
		
	= { state & 
		n_xcoff_files = n_xcoff_files + 1,
		n_xcoff_symbols = n_xcoff_symbols + n_new_xcoff_symbols,
		
		// n_library_symbols, library_list, one_pass_link and namestable remain unaltered
		
		marked_bool_a = marked_bool_a2,
		marked_offset_a = marked_offset_a2,
		module_offset_a = module_offset_a2
	  };

enlarge_arrays_in_state :: !Int !Int !State -> State;
enlarge_arrays_in_state n_new_xcoff_symbols n_new_files state=:{n_xcoff_files,n_xcoff_symbols,n_library_symbols}
	#! (marked_bool_a,state) = select_marked_bool_a state;
	#! (marked_offset_a,state) = select_marked_offset_a state;
	#! (module_offset_a,state) = select_module_offset_a state;

	#! n_xcoff_files_plus_libraries = size marked_offset_a;
	#! n_symbols = n_xcoff_symbols + n_library_symbols + n_new_xcoff_symbols;

	# marked_bool_a2 = createArray n_symbols False;
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};
	
	# marked_offset_a2 = createArray (n_xcoff_files_plus_libraries+n_new_files) 0;
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i] \\ i<-[0..n_xcoff_files-1]};
//	  marked_offset_a2 = {marked_offset_a2 & [n_xcoff_files] = n_xcoff_symbols};
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i-n_new_files]+n_new_xcoff_symbols \\ i<-[n_xcoff_files+n_new_files..n_xcoff_files_plus_libraries+n_new_files-1]};

	# module_offset_a2 = createArray n_symbols 0;
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i-n_new_xcoff_symbols] \\ i<-[n_xcoff_symbols+n_new_xcoff_symbols..n_symbols-1]};

	= { state & 
		marked_bool_a = marked_bool_a2,
		marked_offset_a = marked_offset_a2,
		module_offset_a = module_offset_a2
	  };

add_modules2 :: !*[*Xcoff] !State -> State;
add_modules2 xcoff_l state
	# (n_new_xcoff_symbols,n_new_files,xcoff_l) = compute_n_new_xcoff_symbols_and_n_new_files 0 0 xcoff_l;
		with {
			compute_n_new_xcoff_symbols_and_n_new_files n_new_xcoff_symbols n_new_files []
				= (n_new_xcoff_symbols,n_new_files,[]);
			compute_n_new_xcoff_symbols_and_n_new_files n_new_xcoff_symbols n_new_files [xcoff=:{n_symbols}:xcoff_l]
				# (n_new_xcoff_symbols,n_new_files,xcoff_l) = compute_n_new_xcoff_symbols_and_n_new_files (n_new_xcoff_symbols+n_symbols) (n_new_files+1) xcoff_l;
				= (n_new_xcoff_symbols,n_new_files,[xcoff:xcoff_l]);
		}
	# state = enlarge_arrays_in_state n_new_xcoff_symbols n_new_files state;
	= add_modules3 xcoff_l state;
{
	add_modules3 :: !*[*Xcoff] !State -> State;
	add_modules3 [xcoff=:{n_symbols=n_new_xcoff_symbols}:xcoff_l] state=:{n_xcoff_files,n_xcoff_symbols}
		#! (marked_offset_a,state) = select_marked_offset_a state;
		# marked_offset_a = {marked_offset_a & [n_xcoff_files] = n_xcoff_symbols};
		#! state = update_state_with_xcoff xcoff state;
		# state = { state & 
			n_xcoff_files = n_xcoff_files + 1,
			n_xcoff_symbols = n_xcoff_symbols + n_new_xcoff_symbols,
			marked_offset_a = marked_offset_a
		  };
		= add_modules3 xcoff_l state;
	add_modules3 [] state
		= state;
}

add_library2 :: !Int !Int !LibraryList !State -> State;
add_library2 n_new_libraries n_new_library_symbols library_list state=:{n_libraries,n_xcoff_files,n_xcoff_symbols,n_library_symbols}
	#! (marked_bool_a,state) = select_marked_bool_a state;
	#! (marked_offset_a,state) = select_marked_offset_a state;
	#! (module_offset_a,state) = select_module_offset_a state;
	#! n_xcoff_files_plus_libraries = size marked_offset_a;
	#! n_symbols = n_xcoff_symbols + n_new_library_symbols + n_library_symbols;

	# marked_bool_a2 = createArray n_symbols False;
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  marked_bool_a2 = {marked_bool_a2 & [i]=marked_bool_a.[i-n_new_library_symbols] \\ i<-[n_xcoff_symbols+n_new_library_symbols..n_symbols-1]};
	
	# marked_offset_a2 = createArray (n_xcoff_files_plus_libraries+n_new_libraries) 0;
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i] \\ i<-[0..n_xcoff_files-1]};  // copy old xcoff offsets
	# marked_offset_a2 = fill_library_offsets library_list n_xcoff_files n_xcoff_symbols marked_offset_a2;
	  
	  marked_offset_a2 = {marked_offset_a2 & [i]=marked_offset_a.[i-n_new_libraries]+n_new_library_symbols 
									  		\\ i<-[n_xcoff_files+n_new_libraries..n_xcoff_files_plus_libraries+n_new_libraries - 1 ]};

	# module_offset_a2 = createArray n_symbols 0;
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i] \\ i<-[0..n_xcoff_symbols-1]};
	  module_offset_a2 = {module_offset_a2 & [i]=module_offset_a.[i-n_new_library_symbols] \\ i<-[n_xcoff_symbols+n_new_library_symbols..n_symbols-1]};

	= { state & 
		n_libraries			= n_new_libraries + n_libraries,
		n_library_symbols	= n_new_library_symbols + n_library_symbols,

		marked_bool_a = marked_bool_a2,
		marked_offset_a = marked_offset_a2,
		module_offset_a = module_offset_a2
	  };

split_data_symbol_lists_without_removing_unmarked_symbols :: .a;	  
split_data_symbol_lists_without_removing_unmarked_symbols
	// The Clean 1.3 compiler does check only when they are fully expanded. The Clean 2.0 compiler checks
	// before expansion.
	= abort "split_data_symbol_lists_without_removing_unmarked_symbols; look in source";
	
