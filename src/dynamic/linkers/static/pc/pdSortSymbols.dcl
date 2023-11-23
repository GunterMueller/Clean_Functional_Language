definition module pdSortSymbols;

from pdSymbolTable import :: Xcoff, ::Symbol;

sort_modules :: !*Xcoff -> .Xcoff;
symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
