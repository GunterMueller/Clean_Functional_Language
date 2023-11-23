definition module SearchObject;

from State import :: State;
from pdSymbolTable import :: LibraryList, :: Xcoff;

add_module2 :: !*Xcoff !State -> State;

add_modules2 :: !*[*Xcoff] !State -> State;

add_library2 :: !Int !Int !LibraryList !State -> State;

add_module :: !*Xcoff !State -> State;

split_data_symbol_lists_without_removing_unmarked_symbols :: .a;	  
