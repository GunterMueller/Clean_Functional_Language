definition module SortSymbols;

from pdSymbolTable import :: SymbolIndexList, :: SymbolArray, :: SSymbolArray, :: Symbol;

reverse_and_sort_symbols :: !SymbolIndexList !*SymbolArray -> (!SymbolIndexList,!*SymbolArray);
reverse_symbols :: !SymbolIndexList -> SymbolIndexList;
