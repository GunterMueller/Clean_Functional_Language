definition module typereify

from general import ::Optional
from syntax import
	::Ident, ::FunDef, ::IndexRange, ::TypeHeaps,
	::SymbolTable, ::SymbolTableEntry, ::Heap,
	::CommonDefsR,::DclInstanceMemberTypeAndFunctions,
	::DclModule, ::CommonDefs, ::CheckedTypeDef, ::TypeDef, ::TypeRhs, ::ClassDef, ::VarHeap, ::VarInfo
from predef import
	::PredefinedSymbols, ::PredefinedSymbol

addDclTypeFunctions :: !Int !*{#DclModule} !*VarHeap !*SymbolTable
						-> (!*{#DclModule},!*VarHeap,!*SymbolTable)

addIclTypeFunctions :: !Int !Int !*{#FunDef} !*{#CheckedTypeDef} !*{#ClassDef} !*VarHeap !*SymbolTable
				 -> (!IndexRange,!*{#FunDef},!*{#CheckedTypeDef},!*{#ClassDef},!*VarHeap,!*SymbolTable)

buildTypeFunctions :: !Int !*{#FunDef} !{#CommonDefs} !*PredefinedSymbols !*VarHeap !*TypeHeaps
									  -> (!*{#FunDef},!*PredefinedSymbols,!*VarHeap,!*TypeHeaps)
