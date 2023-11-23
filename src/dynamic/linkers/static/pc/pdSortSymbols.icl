implementation module pdSortSymbols;

import StdArray;
import SymbolTable;
from SortSymbols import reverse_and_sort_symbols;
import pdSymbolTable;
import StdEnv;

symbol_index_less_or_equal :: Int Int {!Symbol} -> Bool;
symbol_index_less_or_equal i1 i2 {[i1]=m1,[i2]=m2}
	= case (m1,m2) of {
		(Module offset1 _ _ _ _ _ _,Module offset2 _ _ _ _ _ _)
			-> offset1<=offset2; 
	};

sort_modules :: !*Xcoff -> .Xcoff;
sort_modules xcoff
	= { xcoff & symbol_table = 
		{ symbol_table &
			text_symbols=text_symbols1,
			data_symbols=data_symbols1,
			bss_symbols=bss_symbols1,
			symbols=symbols3
		}
	  }
where
{
	(text_symbols1,symbols1)=reverse_and_sort_symbols text_symbols symbols0;
	(data_symbols1,symbols2)=reverse_and_sort_symbols data_symbols symbols1;
	(bss_symbols1,symbols3)=reverse_and_sort_symbols bss_symbols symbols2;
	({symbol_table}) =xcoff;
	({text_symbols,data_symbols,bss_symbols,symbols=symbols0}) = symbol_table;
};