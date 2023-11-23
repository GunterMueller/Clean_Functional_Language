implementation module pdUpdateObject;

// macOs
import StdEnv;

import DLState;
import UnknownModuleOrSymbol;

import CallCg;

generate_abc_file :: !String !String ![!ModuleOrSymbolUnknown] ![!String] !*State !*DLClientState !*DLServerState !(IOState s) -> !(!Bool,!String,![!ModuleOrSymbolUnknown],![!String],!*State,!*DLClientState,!*DLServerState,!(IOState s));
generate_abc_file module_path_name o_path_file objs libs state dl_client_state=:{cgpath} dl_server_state=:{application_path} io
	#! state
		= AddMessage (LinkerWarning "generate_abc_file in module pdUpdateObnject.icl has not completely been tested") state;
	#! (object_path_name,ok)
		= CodeGen module_path_name cgpath;
	| ok
		= (ok,object_path_name,objs,libs,state,dl_client_state,dl_server_state,io);
		
	#! state
		= AddMessage (LinkerError "error during code generation; see warning also warning above") state;
	= (False,"",objs,libs,state,dl_client_state,dl_server_state,io);
