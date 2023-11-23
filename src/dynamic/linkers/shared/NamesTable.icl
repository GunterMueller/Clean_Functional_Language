implementation module NamesTable;

import StdArray, StdEnum;
from StdMisc import abort;
import StdEnv;
from ExtString import BYTE;

::	*NamesTable :== SNamesTable;
::	SNamesTable :== {!NamesTableElement};

::	NamesTableElement
	= NamesTableElement !String !Int !Int !NamesTableElement	// symbol_name symbol_n file_n symbol_list
	| EmptyNamesTableElement;
	
isEmptyNamesTableElement :: !.NamesTableElement -> Bool;
isEmptyNamesTableElement EmptyNamesTableElement	= True;
isEmptyNamesTableElement _						= False;

SYMBOL_TABLE_SIZE:==4096;
SYMBOL_TABLE_SIZE_MASK:==4095;

create_names_table :: NamesTable;
create_names_table = createArray SYMBOL_TABLE_SIZE EmptyNamesTableElement;

insert_symbol_in_symbol_table :: !String Int Int !NamesTable -> NamesTable;
insert_symbol_in_symbol_table symbol_name symbol_n file_n names_table
	#! 	symbol_hash=symbol_name_hash symbol_name;
	#! (symbol_list,names_table) = names_table![symbol_hash];
	| symbol_n == (-1)
		= abort "insert_symbol_in_symbol_table";	
	| symbol_in_symbol_table_list symbol_list
		= names_table;
		= {names_table & [symbol_hash] = NamesTableElement symbol_name symbol_n file_n symbol_list};
where {
	symbol_in_symbol_table_list EmptyNamesTableElement
		= False;
	symbol_in_symbol_table_list (NamesTableElement string  _ _ symbol_table_list)
		| string==symbol_name
			= True;
			= symbol_in_symbol_table_list symbol_table_list;
	}

find_symbol_in_symbol_table :: !String !NamesTable -> (!NamesTableElement,!NamesTable);
find_symbol_in_symbol_table symbol_name names_table
	# (symbol_list,names_table)
		= names_table![symbol_hash];
	= (symbol_in_symbol_table_list symbol_list,names_table);
	{
		symbol_hash=symbol_name_hash symbol_name;
		
		symbol_in_symbol_table_list EmptyNamesTableElement
			= EmptyNamesTableElement;
		symbol_in_symbol_table_list names_table_element=:(NamesTableElement string _ _ symbol_table_list)
			| string==symbol_name
				= names_table_element;
				= symbol_in_symbol_table_list symbol_table_list;
	}

	symbol_name_hash symbol_name = (simple_hash symbol_name 0 0) bitand SYMBOL_TABLE_SIZE_MASK;
	{
		simple_hash string index value
			| index== size string
				= value;
				= simple_hash string (inc index) (((value<<2) bitxor (value>>10)) bitxor (string BYTE index));
	}

find_symbol_in_symbol_table_new :: .{#Char} .(Int -> .(.a -> (NamesTableElement,.a))) .a -> (NamesTableElement,.a);
find_symbol_in_symbol_table_new symbol_name select1 s
	# (symbol_list,s) = select1 symbol_hash s;
	= (symbol_in_symbol_table_list symbol_list,s);
	{
		symbol_hash=symbol_name_hash symbol_name;
		
		symbol_in_symbol_table_list EmptyNamesTableElement
			= EmptyNamesTableElement;
		symbol_in_symbol_table_list names_table_element=:(NamesTableElement string _ _ symbol_table_list)
			| string==symbol_name
				= names_table_element;
				= symbol_in_symbol_table_list symbol_table_list;
	}

split_symbol_list_in_symbol_table :: .{#Char} .(Int -> .(.a -> (u:NamesTableElement,.b))) .a -> ((Int,Int,Int,v:NamesTableElement),.b), [u <= v];
split_symbol_list_in_symbol_table symbol_name select1 s
	# (symbol_list,s) = select1 symbol_hash s;
	= (symbol_in_symbol_table_list EmptyNamesTableElement symbol_list,s);
	{
		symbol_hash=symbol_name_hash symbol_name;
		
		symbol_in_symbol_table_list left EmptyNamesTableElement
			= abort ("split_symbol_list_in_symbol_table; internal error; symbol '" +++ symbol_name +++ "' not found");
		symbol_in_symbol_table_list left names_table_element=:(NamesTableElement string symbol_n file_n right)
			| string==symbol_name
				= (symbol_hash,file_n,symbol_n,concat left right);				
				#! new_left = NamesTableElement string symbol_n file_n left;
				= symbol_in_symbol_table_list new_left right;
				
		concat EmptyNamesTableElement accu
			= accu;
		concat (NamesTableElement s i1 i2 rest) accu
			= concat rest (NamesTableElement s i1 i2 accu);
	}

MergeNamesTables :: !NamesTable !NamesTable -> NamesTable;
MergeNamesTables names_table1 names_table2 
	= { (merge names_table_element1 names_table_element2) 
					\\ names_table_element1 <-: names_table1 
					&  names_table_element2 <-: names_table2 };
where
{
	merge :: !NamesTableElement !NamesTableElement -> NamesTableElement;
	merge names_table_element1 EmptyNamesTableElement
		= names_table_element1;
	merge names_table_element1 (NamesTableElement symbol_name symbol_n file_n more_names_table_elements)
		| name_in_names_table_list names_table_element1
			= abort ("MergeNamesTables: double defined symbols" +++ symbol_name);
			= merge (NamesTableElement symbol_name symbol_n file_n names_table_element1) more_names_table_elements; 
	where	
	{
		name_in_names_table_list EmptyNamesTableElement
			= False;
		name_in_names_table_list (NamesTableElement string _ _ names_table_list)
			| string == symbol_name
				= True;
				= name_in_names_table_list names_table_list
	}
}
