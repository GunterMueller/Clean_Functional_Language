implementation module cache_variable;

import StdEnv;
import compile;

:: StateVariableContents = State !.DclCache | NoState;

:: StateVariableRecord = {version_number::!Int,contents::!.StateVariableContents};

state_variable_array :: {#StateVariableRecord};
state_variable_array =: {{version_number=0,contents=NoState}};

update_state_variable_array :: !{#StateVariableRecord} !StateVariableRecord !Int -> (!Int,!{#StateVariableRecord});
update_state_variable_array array state_variable_record version_number
	= code {
		pushI 0
		update rStateVariableRecord 1 1
	};

make_unique :: !StateVariableContents -> .StateVariableContents;
make_unique _
	= code {
		fill_a 0 1
		pop_a 1
	};

store_state :: !*DclCache -> Int;
store_state state
	# array = state_variable_array;
	# {version_number,contents} = array.[0];
	= case contents of {
		NoState
			# version_number=version_number+1;
			# (version_number,array) = update_state_variable_array array {version_number=version_number,contents=State state} version_number;
			-> version_number;
		_
			# version_number=version_number+1;
			# (version_number,array) = update_state_variable_array array {version_number=version_number,contents=State state} version_number;
			-> version_number;
	  };

load_state :: Int -> .DclCache;
load_state version_number_argument
	# array = state_variable_array;
	# {version_number,contents} = array.[0];
	= case (make_unique contents) of {
		State state
			# (version_number,array) = update_state_variable_array array {version_number=version_number,contents=NoState} version_number;
			| version_number==version_number_argument
				-> state
				-> state
	}; 
