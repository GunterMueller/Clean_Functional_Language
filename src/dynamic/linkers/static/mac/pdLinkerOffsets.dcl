definition module pdLinkerOffsets;

import SymbolTable;

:: *ModuleOffsets :== *{#Int};

compute_module_offset :: !Int !Symbol !Int !Int !Int !*{#Int} -> (!Int,!*{#Int});
