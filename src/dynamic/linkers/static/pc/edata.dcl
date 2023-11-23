definition module edata;

from State import :: State;
from Sections import ::SectionHeader;
from NamesTable import :: NamesTableElement;

// functions to be used:
write_edata_section :: /*{#SectionHeader}*/ !EdataInfo !*File !State -> (!*File,!*State);
compute_edata_section :: !Int !SectionHeader !Int !Int !EdataInfo !State -> (!Int,!SectionHeader,!EdataInfo,!State);

find_exported_symbols :: ![.ExportAddressEntryState] y:[u1:(u3:Bool,{#Char},Int,Int)] u:[w:ExportAddressEntryState] *{!NamesTableElement} u5:Bool -> *(u6:Bool,z:[u2:(u4:Bool,{#Char},Int,Int)/*(found,symbol_name,file_n,symbol_n)*/],v:[x:ExportAddressEntryState],*{!NamesTableElement}), [w <= x, u <= v, u3 <= u4, u1 <= u2, y <= z, u5 <= u6];

// abstract type
EmptyEdataInfo :: EdataInfo;
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
getInternalName :: !InternalName -> String;

:: Ordinal
	= Ordinal !Int
	| NoOrdinal;

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
:: ExportAddressEntryState
	= Entry !ExportEntry
	| NoEntry;

// ordinals and public names must be unique
compute_export_address_table :: [ExportAddressEntryState] -> (!Bool,[ExportAddressEntryState]);
get_ordinal :: !Ordinal -> Int;
isEntry :: !ExportAddressEntryState -> Bool;
getEntry :: !ExportAddressEntryState -> ExportEntry;

 