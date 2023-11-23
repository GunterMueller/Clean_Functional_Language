definition module SymbolTable;

from pdSymbolTable import :: Xcoff, :: LibraryList;
from NamesTable import :: NamesTable, :: SNamesTable, :: NamesTableElement;

mark_modules_list :: ![String] !*[*Xcoff] !Int !Int !Int !LibraryList [(!Bool,!String,!Int,!Int)] !NamesTable -> (![String],!Int,!*{#Bool},!*{#Int},!*{#*Xcoff},!NamesTable);

create_xcoff_boolean_array :: Int Int Int Int LibraryList [*Xcoff] -> (!*{#Bool},!*{#Int},!*{#*Xcoff});

n_symbols_of_xcoff_list :: Int ![*Xcoff] -> (!Int,![*Xcoff]);
