definition module NamesTable;

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;
	
SYMBOL_TABLE_SIZE:==4096;
isEmptyNamesTableElement :: !.NamesTableElement -> Bool;

create_names_table :: NamesTable;
insert_symbol_in_symbol_table :: !String Int Int !NamesTable -> NamesTable;
find_symbol_in_symbol_table :: !String !NamesTable -> (!NamesTableElement,!NamesTable);

MergeNamesTables :: !NamesTable !NamesTable -> NamesTable;

find_symbol_in_symbol_table_new :: .{#Char} .(Int -> .(.a -> (NamesTableElement,.a))) .a -> (NamesTableElement,.a);
split_symbol_list_in_symbol_table :: .{#Char} .(Int -> .(.a -> (u:NamesTableElement,.b))) .a -> ((Int,Int,Int,v:NamesTableElement),.b), [u <= v];
