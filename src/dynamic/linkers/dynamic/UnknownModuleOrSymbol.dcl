definition module UnknownModuleOrSymbol;

from StdOverloaded import class toString;

/*
** ModuleUnknown module_name symbol_name
** The module module_name is searched for. If symbol_name is not the empty string,
** then the found module must be its defining module.
*/

:: ModuleOrSymbolUnknown = ModuleUnknown !String !String 
						| SymbolUnknown !String !String
						| LibraryUnknown !String;
						
instance toString ModuleOrSymbolUnknown;
