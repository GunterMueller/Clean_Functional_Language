implementation module edata;

import StdEnv;
from ExtString import CharIndex;
import xcoff;
import State;
import ExtFile;
import Sections;
import pdExtFile;
import pdSections;
import NamesTable;

EmptyEdataInfo :: EdataInfo;
EmptyEdataInfo = {
	rva_dll_name							= 0,
	exported_entries						= [],
	ordinal_base							= 0,
	n_exported_address_table_entries		= 0,
	n_exported_entries_by_name				= 0,
	rva_export_address_table				= 0,
	rva_name_pointer_table					= 0,
	rva_ordinal_table						= 0
};
	
:: EdataInfo = {
	rva_dll_name							:: !Int,
	exported_entries						:: [ExportAddressEntryState],
	ordinal_base							:: !Int,
	n_exported_address_table_entries		:: !Int,
	n_exported_entries_by_name				:: !Int,
	rva_export_address_table				:: !Int,
	rva_name_pointer_table					:: !Int,
	rva_ordinal_table						:: !Int
};
	
:: InternalName
	= InternalName !String
	| NoInternalName;
	
isInternalName :: !InternalName -> Bool; 
isInternalName (InternalName _)		= True;
isInternalName _					= False;

getInternalName :: !InternalName -> String; 
getInternalName (InternalName s)	= s;

:: Ordinal
	= Ordinal !Int
	| NoOrdinal;
	
get_ordinal :: !Ordinal -> Int;
get_ordinal (Ordinal i) 
	= i;
get_ordinal NoOrdinal
	= abort "get_ordinal";

:: ExportEntry = {
	label_name :: !String,
	internal_name :: InternalName,
	ordinal :: Ordinal,
	noname :: !Bool,
	label_rva :: !Int,
	export_address_table_entry :: !Int,
	file_n :: !Int,
	symbol_n :: !Int
	};
	
EmptyExportEntry :: ExportEntry;
EmptyExportEntry 
	= { label_name = "",
		internal_name = NoInternalName,
		ordinal = NoOrdinal,
		noname = False,
		label_rva = 0,
		export_address_table_entry = 0,
		file_n	= 0,
		symbol_n = 0
	};
	
:: ExportAddressEntryState
	= Entry !ExportEntry
	| NoEntry;
	
isEntry :: !ExportAddressEntryState -> Bool;
isEntry (Entry _)
	= True;
isEntry _
	= False;
	
getEntry :: !ExportAddressEntryState -> ExportEntry;
getEntry (Entry e)
	=  e;
getEntry NoEntry
	= abort "getEntry (internal error): cannot get entry";

instance == Ordinal
where {
	(==) NoOrdinal NoOrdinal 
		= True;
	(==) (Ordinal i) (Ordinal j)
		= i == j;
	(==) _ _
		= False;
};

// ordinals and public names must be unique
compute_export_address_table :: [ExportAddressEntryState] -> (!Bool,[ExportAddressEntryState]);
compute_export_address_table []
	= abort "compute_export_address_table: no exports";
compute_export_address_table es
	#! (min_ordinal,max_ordinal,with_ordinals,withouts)
		= split NoOrdinal NoOrdinal [] [] es;
	| min_ordinal == NoOrdinal && max_ordinal == NoOrdinal
		= (True,number_ordinals_from_base 1 es);

	#! with_ordinals
		= sortBy (\{ordinal=Ordinal ordinal1} {ordinal=Ordinal ordinal2} -> ordinal1 < ordinal2) with_ordinals;
	#! withouts
		= reverse withouts;
		
	// both ordinals have numbers
	# (Ordinal ordinal_base)
		= min_ordinal;
		
	#! i
		= intersperse_list ordinal_base with_ordinals withouts;
	= (True,i);	
where {
	number_ordinals_from_base i []
		= [];
	number_ordinals_from_base i [Entry e:es]
		= [ Entry {e & ordinal = Ordinal i} : number_ordinals_from_base (inc i) es];

	split min_ordinal max_ordinal withs withouts []
		= (min_ordinal,max_ordinal,withs,withouts);
	split min_ordinal max_ordinal withs withouts [Entry e:es]
		// order of both list is reversed
		| e.ordinal == NoOrdinal
			= split min_ordinal max_ordinal withs [e:withouts] es;
			= split (minmax min_ordinal e.ordinal min) (minmax max_ordinal e.ordinal max) [e:withs] withouts es;
	where {
		minmax NoOrdinal NoOrdinal _
			= NoOrdinal;
		minmax NoOrdinal (Ordinal i) _ 
			= (Ordinal i);
		minmax (Ordinal i) NoOrdinal _
			= (Ordinal i);
		minmax (Ordinal i) (Ordinal j) minmax
			= Ordinal (minmax i j);
	};
	
	intersperse_list _ [] []
		= [];
	
	intersperse_list ith_ordinal [] [without:withouts]
		= [ Entry {without & ordinal = Ordinal ith_ordinal} : (intersperse_list (inc ith_ordinal) [] withouts)];
		
	intersperse_list ith_ordinal l=:[w=:{ordinal=(Ordinal j)}:withs] []
		| ith_ordinal == j
			= [ Entry w : intersperse_list (inc ith_ordinal) withs []];
			
			// e.i. ith_ordinal < j because sorted in increasing order
			= [ NoEntry : intersperse_list (inc ith_ordinal) l [] ];
			
	intersperse_list ith_ordinal l=:[w=:{ordinal=(Ordinal j)}:withs] ws=:[without:withouts]
		| ith_ordinal == j
			= [ Entry w : intersperse_list (inc ith_ordinal) withs ws];
			
			// e.i. ith_ordinal < j then add a without
			= [ Entry {without & ordinal = Ordinal ith_ordinal} : intersperse_list (inc ith_ordinal) l withouts ];
};

instance toString ExportAddressEntryState
where {
	toString (Entry {label_name}) =label_name
};

compute_edata_section :: !Int !SectionHeader !Int !Int !EdataInfo !State -> (!Int,!SectionHeader,!EdataInfo,!State);
compute_edata_section i_edata_section_header edata_section_header  base_va rva_edata edata_info=:{exported_entries} state=:{application_name}	
	# dll_name
		=	snd (ExtractPathAndFile application_name)
	// reorder exported entries
	#! (_,exported_entries=:[Entry {ordinal=(Ordinal ordinal_base)}:_])
		= compute_export_address_table exported_entries;
	#! i_string_table
		= size dll_name + 1;
	#! (state,s_string_table,exported_entries,n_exported_entries_by_name)
		= foldl f1 (state,i_string_table,[],0) exported_entries;

	// Export Directory Table
	#! rva_export_directory_table
		= rva_edata;
		
	// Export Address Table (supports export by ordinal); supports export by ordinal
	#! n_exported_address_table_entries
		= length exported_entries;

	#! rva_export_address_table
		= rva_export_directory_table + s_export_directory_table;
	#! s_export_address_table
		= n_exported_address_table_entries * s_export_address_table_entry;

	// The tables below support export by name; Export Name Pointer Table
	#! rva_export_name_pointer_table
		= rva_export_address_table + s_export_address_table;
	#! s_export_name_pointer_table
		= n_exported_entries_by_name * s_export_name_pointer_entry;
		
	// Export Ordinal Table
	#! rva_export_ordinal_table
		= rva_export_name_pointer_table + s_export_name_pointer_table;
	#! s_export_ordinal_table
		= n_exported_entries_by_name * s_export_ordinal_entry;
		
	// Export Name Table (String table)
	#! rva_export_name_table
		= rva_export_ordinal_table + s_export_ordinal_table;
	#! exported_entries
		= [ update_label_rva rva_export_name_table e \\ e <- exported_entries];

	// update edata_info
	#! edata_info
		= { edata_info &
			rva_dll_name						= rva_export_name_table,
			exported_entries					= exported_entries,
			ordinal_base						= ordinal_base,
			n_exported_address_table_entries	= n_exported_address_table_entries,
			n_exported_entries_by_name			= n_exported_entries_by_name,
			rva_export_address_table			= rva_export_address_table,
			rva_name_pointer_table				= rva_export_name_pointer_table,
			rva_ordinal_table					= rva_export_ordinal_table
		};
		
	#! edata_size
		= s_export_directory_table + s_export_address_table + s_export_name_pointer_table + s_export_ordinal_table + s_string_table;

	// update section header
	#! pd_section_header = {
			section_name				= ".rdata"
		,	section_rva					= rva_export_directory_table
		,	section_flags				= IMAGE_SCN_CNT_INITIALIZED_DATA bitor 
										  IMAGE_SCN_MEM_READ
		};
	# edata_section_header = edata_section_header
		DSH sh_set_pd_section_header pd_section_header
		DSH sh_set_virtual_data edata_size;

	= (edata_size,edata_section_header,edata_info/*,section_headers*/,state);

where { 
	update_label_rva _ NoEntry
		= NoEntry;
	update_label_rva rva_export_name_table (Entry e=:{label_rva})
		= Entry {e & label_rva = rva_export_name_table + label_rva};

	f1 (state,i_string_table,exports,n_exported_entries_by_name) NoEntry
		= (state,i_string_table,exports ++ [NoEntry],n_exported_entries_by_name);
		
	f1 (state,i_string_table,exports,n_exported_entries_by_name) (Entry label=:{label_name,ordinal,noname,internal_name})	
		#! (state,n_exported_entries_by_name,i_string_table,label)
			= case noname of {
				True
					// export only by ordinal e.g. no entry in stringtable 
					// The labelname determines the address of the export.
					#! (ok,addr,state)
						= find_address_of_label label_name state;
					| not ok
						-> abort ("compute_edata_section: '" +++ label_name +++ "'  undefined.");
					-> (state,n_exported_entries_by_name,i_string_table,{label & label_rva = i_string_table, export_address_table_entry = addr - base_va });
				False
					// export by name; the internalname determines the 
					// address to export. If the internalname is empty
					// its public name is used.
					#! (is_forwarder,name)
						= isForwarder internal_name label_name;
					#! (i_string_table,state,label)
						= case is_forwarder of {
							True
								// reference to a public symbol of another DLL; now both label_name
								// and internal_name (forwarder) need to be stored
								-> (i_string_table + size name + 1,state,{label & export_address_table_entry = i_string_table});
							False
								#! (ok,addr,state)
									= find_address_of_label name state;
								| not ok
									-> abort ("compute_edata_section: '" +++ name +++ "'  undefined.");
								-> (i_string_table, state, {label & export_address_table_entry = addr - base_va}); 
						};
					-> (state,inc n_exported_entries_by_name,i_string_table + size label_name + 1,{label & label_rva = i_string_table})
			};
		= (state,i_string_table,exports ++ [Entry label],n_exported_entries_by_name);
}

isForwarder :: !InternalName !String -> (!Bool,!String);
isForwarder (InternalName internal_name) _
	= (fst (CharIndex internal_name 0 '.'),internal_name);
isForwarder NoInternalName label_name
	= (False,label_name);
		
write_edata_section :: !EdataInfo !*File !State -> (!*File,!*State);
write_edata_section  edata_info=:{exported_entries} pe_file state
	#! pe_file
		= write_export_directory_table edata_info pe_file;
	#! pe_file
		= write_export_address_table edata_info pe_file;
	#! (sorted_exported_entries,pe_file)
		= write_export_name_pointer_table edata_info pe_file;
	#! pe_file
		= write_export_ordinal_table sorted_exported_entries edata_info pe_file;
	#! (pe_file,state)
		= write_export_name_table edata_info pe_file state;		
	= (pe_file,state);	
where {
	write_export_directory_table edata_info=:{rva_dll_name,ordinal_base,n_exported_address_table_entries,n_exported_entries_by_name,rva_export_address_table,rva_name_pointer_table, rva_ordinal_table} pe_file
		#! pe_file = pe_file
			FWI 0									// reserved field
			FWI 0									// Time/Data Stamp
			FWW 0									// Major version
			FWW 0									// Minor version
			FWI rva_dll_name						// reference to ASCII-string containing the dll's name
			FWI ordinal_base						// starting ordinal for exports
			FWI n_exported_address_table_entries	// number of Export Address Table-entries
			FWI n_exported_entries_by_name			// number of Export Address Table-entries exported by name
			FWI rva_export_address_table			// relative address of Export Address Table
			FWI rva_name_pointer_table				// relative address of Export Name Pointer Table
			FWI rva_ordinal_table					// relative address of Export Ordinal Table 			
		= pe_file;

	write_export_address_table :: !EdataInfo !*File  -> *File;
	write_export_address_table edata_info pe_file
		#! pe_file
			= foldl write_entry pe_file edata_info.exported_entries;
		= pe_file;
	where {
		write_entry pe_file NoEntry
			= fwritei 0 pe_file;
		write_entry pe_file (Entry {export_address_table_entry})
			= fwritei export_address_table_entry pe_file;
	}
	
	write_export_name_pointer_table edata_info=:{exported_entries} pe_file
		#! sorted_exported_entries
			= sortBy sort_entry [ getEntry e \\ e <- exported_entries | check e] ;
		#! pe_file
			= foldl write_sorted_entry pe_file sorted_exported_entries;
		= (sorted_exported_entries,pe_file);
	where {
		check NoEntry
			= False;
		check (Entry e=:{noname}) 
			= not noname;
		
		sort_entry {label_name=label_name1} {label_name=label_name2}
			= label_name1 < label_name2;
			
		write_sorted_entry pe_file {label_rva}
			= fwritei label_rva pe_file;
	}
	
	write_export_ordinal_table sorted_exported_entries edata_info=:{ordinal_base} pe_file
		#! pe_file
			= foldl write_ordinal_entry pe_file sorted_exported_entries;
		= pe_file;
	where {
		write_ordinal_entry pe_file {ordinal=(Ordinal ordinal)}
			= pe_file FWW (ordinal - ordinal_base);
	}
	
	write_export_name_table edata_info=:{exported_entries} pe_file state=:{application_name}
		# dll_name
			=	snd (ExtractPathAndFile application_name)
		#! pe_file
			= append_zero dll_name pe_file;
		#! pe_file
			= foldl write_name pe_file exported_entries;
		= (pe_file,state);
	where {
		write_name pe_file NoEntry
			= pe_file;
			
		write_name pe_file (Entry {label_name,noname,internal_name})
			#! pe_file
				= case noname of {
					True
						-> pe_file;
					False
						// export by name
						#! (is_forwarder,name)
							= isForwarder internal_name label_name;
						#! pe_file 
							= case is_forwarder of {
								True
									// forwarder (in name) is put in stringtable
									-> append_zero name pe_file;
								False
									-> pe_file;
							};
						// save public name (label_name) in stringtable
						#! pe_file
							= append_zero label_name pe_file;
						-> pe_file;
				};
			= pe_file;
	}		
}

append_zero s pe_file :== fwritec '\0' (fwrites s pe_file);

find_exported_symbols :: ![.ExportAddressEntryState] y:[u1:(u3:Bool,{#Char},Int,Int)] u:[w:ExportAddressEntryState] *{!NamesTableElement} u5:Bool -> *(u6:Bool,z:[u2:(u4:Bool,{#Char},Int,Int)/*(found,symbol_name,file_n,symbol_n)*/],v:[x:ExportAddressEntryState],*{!NamesTableElement}), [w <= x, u <= v, u3 <= u4, u1 <= u2, y <= z, u5 <= u6];
find_exported_symbols [] entry_datas entries names_table all_exported_symbols_found
	= (all_exported_symbols_found,entry_datas,entries,names_table);
find_exported_symbols [Entry e=:{label_name,internal_name}:es] entry_datas entries names_table all_exported_symbols_found_until_now
	# (entry_names_table_element,names_table) 
		= find_symbol_in_symbol_table entry_name names_table;
	# (all_exported_symbols_found_until_now,entry_data,entry)
		= case entry_names_table_element of {
			(NamesTableElement _ symbol_n file_n _)
				-> (all_exported_symbols_found_until_now,(True,entry_name,file_n,symbol_n),Entry {e & file_n = file_n, symbol_n = symbol_n});
			_
				-> (False,(False,entry_name,undef,undef),Entry e);
		}
	= find_exported_symbols es [entry_data:entry_datas] [entry:entries] names_table all_exported_symbols_found_until_now; 
where 
{
	entry_name
		| isInternalName internal_name
			= getInternalName internal_name;
			= label_name;
}	
		
find_exported_symbols [_:_] _ _ _ _
	= abort "find_names: (internal error) only Entry is supported at user level";
