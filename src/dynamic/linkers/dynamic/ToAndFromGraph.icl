implementation module ToAndFromGraph;

import StdEnv;
import StdDynamicVersion;
import StdMaybe;
import Directory;
import utilities;
import ExtString;
import dynamics;
import ExtInt;
from ExtArray import findAst;
import DefaultElem;
import _SystemDynamic;
	
:: *ToAndFromGraphTable
	= {
		tafgt_n_from_graphs	:: !Int
	,	tafgt_from_graphs	:: !*{#ToAndFromGraphEntry}
	
	,	tafgt_n_to_graphs	:: !Int
	,	tafgt_to_graphs		:: !*{#ToAndFromGraphEntry}
	};
	
instance DefaultElemU ToAndFromGraphTable
where {
	default_elemU 
		= {
			tafgt_n_from_graphs	= 0
		,	tafgt_from_graphs	= {}
			
		,	tafgt_n_to_graphs	= 0
		,	tafgt_to_graphs		= {}
		};
};

:: ToAndFromGraphEntry
	= {
		tafge_version		:: !Version
	,	tafge_conversion	:: !Maybe Int				// from graph to string (address)
	};
	
:: ToAndFromGraphEntryIndex
	:== Int;
	
instance DefaultElemU ToAndFromGraphEntry
where {
	default_elemU
		= {
			tafge_version		= DefaultVersion
		,	tafge_conversion	= Nothing
		};
};
	
init_to_and_from_graph_table :: !String !*env -> (!ToAndFromGraphTable,!*env) | FileEnv, FileSystem env;
init_to_and_from_graph_table dlink_dir io
	#! ((ok,dlink_path),io)
		= accFiles (pd_StringToPath dlink_dir) io;
	#! ((dir_error,dir_entries),io)
		= accFiles (getDirectoryContents dlink_path) io
	| dir_error <> NoDirError
		= abort "init_to_and_from_graph_table: internal error 2";
		
	#! ((n_from_graphs,from_graphs),(n_to_graphs,to_graphs))
		= foldSt fill_to_and_from_graph_table dir_entries ((0,[]),(0,[]));	
	#! from_graphs
		= sortBy less_version from_graphs;
	#! to_graphs
		= sortBy less_version to_graphs;
		
	#! to_and_from_graph_table
		= { default_elemU &
			tafgt_n_from_graphs	= n_from_graphs
		,	tafgt_from_graphs	= {{default_elemU & tafge_version = fg} \\ fg <- from_graphs}
		
		,	tafgt_n_to_graphs	= n_to_graphs		
		,	tafgt_to_graphs		= {{default_elemU & tafge_version = tg} \\ tg <- to_graphs}
		};			
	= (to_and_from_graph_table,io);
where {
	fill_to_and_from_graph_table {fileName} (fromg=:(n_from_graphs,from_graphs),tog=:(n_to_graphs,to_graphs))
		#! (found,s_prefix)
			= starts copy_graph_to_string_0x fileName;
		| found
			// graph -> string
			#! version
				= toVersion (from_base_i fileName 16 s_prefix 8);
			= ((inc n_from_graphs,[version:from_graphs]),tog);
			
		#! (found,s_prefix)
			= starts copy_string_to_graph_0x fileName;
		| found
			// string -> graph
			#! version
				= toVersion (from_base_i fileName 16 s_prefix 8);
			= (fromg,(inc n_to_graphs,[version:to_graphs]));
			
			= (fromg,tog);

	copy_graph_to_string_0x
		=> copy_graph_to_string +++ "_0x";
		
	copy_string_to_graph_0x
		=> copy_string_to_graph +++ "_0x";
		
	// smallest major and minor at start of the version list
	less_version {major=major1,minor=minor1} {major=major2,minor=minor2}
		| major1 < major2
			= True;
			| major1 == major2
				= minor1 < minor2;
				= False;
};

get_from_graph_function_address :: !(Maybe Version) !*ToAndFromGraphTable -> (ToAndFromGraphEntry,ToAndFromGraphEntryIndex,!*ToAndFromGraphTable);
get_from_graph_function_address Nothing to_and_from_graph_table=:{tafgt_n_from_graphs}
	| tafgt_n_from_graphs == 0
		= abort "get_from_graph_function_address; error no conversion functions";
		
	#! most_recent_conversion_i
		= dec tafgt_n_from_graphs;
	#! (entry,to_and_from_graph_table)
		= to_and_from_graph_table!tafgt_from_graphs.[most_recent_conversion_i];
	= (entry,most_recent_conversion_i,to_and_from_graph_table);

get_from_graph_function_address (Just s) to_and_from_graph_table=:{tafgt_n_from_graphs}
	= abort "get_from_graph_function_address; unimplemented";
	
get_to_graph_function_address :: !(Maybe Version) !*ToAndFromGraphTable -> (Maybe (ToAndFromGraphEntry,ToAndFromGraphEntryIndex),!*ToAndFromGraphTable);
get_to_graph_function_address (Just version) to_and_from_graph_table=:{tafgt_n_to_graphs,tafgt_to_graphs}
	= findAst lookup_graph_to to_and_from_graph_table tafgt_n_to_graphs;
where {
	lookup_graph_to i to_and_from_graph_table
		#! (tafge=:{tafge_version},to_and_from_graph_table)
			= to_and_from_graph_table!tafgt_to_graphs.[i];
		| version == tafge_version
			= (Just (tafge, i),to_and_from_graph_table);
			
			= (Nothing,to_and_from_graph_table);
}
