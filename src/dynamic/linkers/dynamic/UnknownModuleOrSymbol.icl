implementation module UnknownModuleOrSymbol;

import StdEnv;
import ExtFile;

/*
** ModuleUnknown module_name symbol_name
** The module module_name is searched for. If symbol_name is not the empty string,
** then the found module must be its defining module.
*/

:: ModuleOrSymbolUnknown = ModuleUnknown !String !String 	// module_name [symbol_name]
						| SymbolUnknown !String !String		//  [module_name] symbol_name
						| LibraryUnknown !String;
						
instance toString ModuleOrSymbolUnknown
where {
	toString (ModuleUnknown module_name symbol_name)
		#! (_,m)
			= ExtractPathAndFile module_name;
		= "UnknownModule, module " +++ m;
	toString (SymbolUnknown symbol_name module_name)
		= "UnknownSymbol, symbol " +++ symbol_name;
};
