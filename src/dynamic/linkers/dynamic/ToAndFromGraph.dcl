definition module ToAndFromGraph;

from StdFile import class FileEnv, ::Files, class FileSystem;
from StdDynamicVersion import ::Version;
from StdMaybe import ::Maybe;
from DefaultElem import class DefaultElemU;

:: *ToAndFromGraphTable
	= {
		tafgt_n_from_graphs	:: !Int
	,	tafgt_from_graphs	:: !*{#ToAndFromGraphEntry}
	
	,	tafgt_n_to_graphs	:: !Int
	,	tafgt_to_graphs		:: !*{#ToAndFromGraphEntry}
	};
	
instance DefaultElemU ToAndFromGraphTable;

:: ToAndFromGraphEntryIndex
	:== Int;

:: ToAndFromGraphEntry
	= {
		tafge_version		:: !Version
	,	tafge_conversion	:: !Maybe Int				// from graph to string (address)
	};

init_to_and_from_graph_table :: !String !*env -> (!ToAndFromGraphTable,!*env) | FileEnv, FileSystem env;

get_from_graph_function_address :: !(Maybe Version) !*ToAndFromGraphTable -> (ToAndFromGraphEntry,ToAndFromGraphEntryIndex,!*ToAndFromGraphTable);

get_to_graph_function_address :: !(Maybe Version) !*ToAndFromGraphTable -> (Maybe (ToAndFromGraphEntry,ToAndFromGraphEntryIndex),!*ToAndFromGraphTable);
