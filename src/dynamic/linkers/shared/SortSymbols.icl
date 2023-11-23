implementation module SortSymbols;

import StdArray;
from pdSortSymbols import symbol_index_less_or_equal;
import pdSymbolTable;
import StdEnv;

::	SortArray :== {#SortElement};
::	SortElement = { index::!Int, offset::!Int };

sort_symbols :: !SymbolIndexList !*SymbolArray -> (!SymbolIndexList,!*SymbolArray);
sort_symbols symbols symbol_array0
	=	(array_to_list sorted_array 0,symbol_array1);
	{
		sorted_array=heap_sort array;
		(array,symbol_array1)=fill_array new_array 0 symbols symbol_array0;
		new_array=createArray n_elements {index=0,offset=0};
		n_elements=length_of_symbol_index_list symbols 0;
		
		fill_array :: *SortArray Int SymbolIndexList *SymbolArray -> (!*SortArray,!*SymbolArray);
		fill_array a i EmptySymbolIndex symbol_array
			= (a,symbol_array);
		fill_array a i (SymbolIndex index l) symbol_array=:{[index]=m}
			= c a i m symbol_array;
			{
/*
				// pc
				c :: *SortArray Int Symbol SymbolArray -> (!*SortArray,!SymbolArray);
				c a i (Module _ offset _ _ _ _ _) symbol_array
					= fill_array {a & [i]={index=index,offset=offset}} (inc i) l symbol_array;

				//mac
				c :: *SortArray Int Symbol *SymbolArray -> (!*SortArray,!*SymbolArray);
				c a i (Module {module_offset}) symbol_array
					= fill_array {a & [i]={index=index,offset=module_offset}} (inc i) l symbol_array;
*/


				c :: *SortArray Int Symbol *SymbolArray -> (!*SortArray,!*SymbolArray);
				c a i symbol symbol_array
					= fill_array {a & [i]={index=index,offset=symbol_get_offset symbol}} (inc i) l symbol_array;				
			};
		
		array_to_list :: SortArray Int -> SymbolIndexList;
		array_to_list a i
			| i<n_elements
				= SymbolIndex a.[i].index (array_to_list a (inc i));
				= EmptySymbolIndex;
			
		heap_sort :: *SortArray -> *SortArray;
		heap_sort a
			| n_elements<2
				=	a
				=	sort_heap max_index (init_heap (n_elements>>1) a);
				{
					sort_heap :: Int *SortArray -> *SortArray;
					sort_heap i a=:{[i]=a_i,[0]=a_0}
						| i==1
							= { a & [0]=a_i,[i]=a_0}; 
							= sort_heap deci (add_element_to_heap {a & [i]=a_0} a_i 0 deci);{
								deci=dec i;
							}
				
					init_heap :: Int *SortArray -> *SortArray;
					init_heap i a0
						| i>=0
							= init_heap (dec i) (add_element_to_heap1 a0 i max_index); {
								add_element_to_heap1 :: *SortArray Int Int -> *SortArray;
								add_element_to_heap1 a=:{[i]=ir} i max_index
									= add_element_to_heap a ir i max_index;
							}
							= a0;
					
					max_index=dec n_elements;
				}
		
		add_element_to_heap :: *SortArray SortElement Int Int -> *SortArray;
		add_element_to_heap a ir i max_index
			= heap_sort_lp a i (inc (i+i)) max_index ir;
		{
			heap_sort_lp :: *SortArray Int Int Int SortElement-> *SortArray;
			heap_sort_lp a i j max_index ir
				| j<max_index
					= heap_sort1 a i j max_index ir;
				{
					heap_sort1 :: !*SortArray !Int !Int !Int !SortElement -> *SortArray;
					heap_sort1 a i j max_index ir
						# j1=inc j;
						# (a_j,a) = a![j];
						# (a_j_1,a) = a![j1]; 
						= heap_sort1 a_j a_j_1 a i j max_index ir;
					{
						heap_sort1 :: !SortElement !SortElement !*SortArray !Int !Int !Int !SortElement -> *SortArray;
						heap_sort1 a_j a_j_1 a i j max_index ir
						| a_j.SortElement.offset < a_j_1.SortElement.offset
							= heap_sort2 a i (inc j) max_index ir;
							= heap_sort2 a i j max_index ir;
					}
				}
				| j>max_index
					= {a & [i] = ir};
					= heap_sort2 a i j max_index ir;
				{}{
					heap_sort2 a=:{[j]=a_j} i j max_index ir
						= heap_sort2 a_j a i j max_index ir;
					{
						heap_sort2 :: SortElement *SortArray !Int !Int !Int SortElement-> *SortArray;
						heap_sort2 a_j a i j max_index ir
						| ir.SortElement.offset<a_j.SortElement.offset
							= heap_sort_lp {a & [i] = a_j} j (inc (j+j)) max_index ir;
			   				= {a & [i] = ir};
			   		}
				}
		}
	}

length_of_symbol_index_list EmptySymbolIndex length
	= length;
length_of_symbol_index_list (SymbolIndex _ l) length
	= length_of_symbol_index_list l (inc length);

symbols_are_sorted :: SymbolIndexList {!Symbol} -> Bool;
symbols_are_sorted EmptySymbolIndex symbol_array
	= True;
symbols_are_sorted (SymbolIndex i1 l) symbol_array
	=	sorted_symbols2 i1 l symbol_array;
	{
		sorted_symbols2 :: Int SymbolIndexList {!Symbol} -> Bool;
		sorted_symbols2 i1 EmptySymbolIndex symbol_array
			= True;
		sorted_symbols2 i1 (SymbolIndex i2 l) symbol_array
			= symbol_index_less_or_equal i1 i2 symbol_array && sorted_symbols2 i2 l symbol_array;
	}

reverse_and_sort_symbols :: !SymbolIndexList !*SymbolArray -> (!SymbolIndexList,!*SymbolArray);
reverse_and_sort_symbols symbols symbol_array
	| symbols_are_sorted reversed_symbols symbol_array
		= (reversed_symbols,symbol_array);
		= sort_symbols reversed_symbols symbol_array;
	{}{
		reversed_symbols=reverse_symbols symbols;
	}

reverse_symbols :: !SymbolIndexList -> SymbolIndexList;
reverse_symbols l = reverse_symbols l EmptySymbolIndex;
{
	reverse_symbols EmptySymbolIndex t = t;
	reverse_symbols (SymbolIndex i l) t = reverse_symbols l (SymbolIndex i t);
}
