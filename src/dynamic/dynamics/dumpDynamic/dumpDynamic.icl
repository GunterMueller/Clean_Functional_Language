module dumpDynamic

from StdReal import entier; // RWS marker

import StdEnv
import ArgEnv
import ddState, write_dynamic, dynamics
from utilities import foldSt 
import Directory
import StdMaybe;
import memory;

:: State
	= {
		dynamics_to_be_dumped	:: [String]
	,	display_help			:: Bool
	,	output_folder			:: Maybe String
	}
	
initial_state
	= {
		dynamics_to_be_dumped	= []
	,	display_help			= False
	,	output_folder			= Nothing
	}

parse_command_line :: [String] !State !*World -> (!State,!*World)	
parse_command_line ["--help":_] state world
	= ({state & display_help = True},world)
parse_command_line ["--output", output_folder: args] state world
	= parse_command_line args {state & output_folder = Just output_folder} world
parse_command_line [dyn_file: args] state=:{dynamics_to_be_dumped} world
	= parse_command_line args {state & dynamics_to_be_dumped = [expand_8_3_names_in_path dyn_file:dynamics_to_be_dumped]} world
parse_command_line [] state=:{display_help,dynamics_to_be_dumped} world
	= ({state & display_help = display_help || (isEmpty dynamics_to_be_dumped)},world)

import expand_8_3_names_in_path;

Start world
	#! commandline
		= getCommandLine
/*
//		= help {
			"exec"
		,	"C:\\Process crash\\Dynamics\\famkeProgram.dyn"
		}
		with
			help :: !{String} -> !{String}
			help i = i
*/		
	#! (state,world)
		= parse_command_line (tl [ arg \\ arg <-: commandline ]) initial_state world;
	| state.display_help
		#! help
			= [
				"Usage: dumpDynamic [FILE]..."
			, 	"Converts a binary dynamic to a readable ASCII-representation."
			,	""
			,	"--help				This text"
			,	"--output <folder>		Place output in <folder>"
			,	""
			,	"Report bugs to <clean@cs.kun.nl>."
			,	""
			]
		= quit help world
		
		
	# (ok,world)
		= case state.output_folder of
			Nothing
				-> (True,world)
			Just output_folder
				#! ((ok,output_folder_p),world)
					= pd_StringToPath output_folder world
				#! (dir_error,world)
					= createDirectory output_folder_p world
				#! ok
					= ok && (not ((dir_error == NoDirError) && (dir_error == AlreadyExists)))
				-> (ok,world)
	| not ok
		#! error = "Error: could not create folder '" +++ (fromJust state.output_folder) +++ "'"
		= quit [error] world

	#! (mem,world)
		= getMemory world;
	#! (_,initial_dynamic_list,ddState,world)
		= InitialDDState mem world;	

	#! (ddState,world,errors)
		= foldSt dump_a_dynamic state.dynamics_to_be_dumped (ddState,world,[])
		with
			dump_a_dynamic file_name (ddState,world,errors)
				#! ddState
					= { DDState|  ddState & file_name = file_name };
			
				#! (ddState,world,errors)
					= do_dynamic ddState world errors state.output_folder;
					
				= (ddState,world,errors)
	= quit (reverse errors) world
where
	quit lines world
		#! stderr
			= foldSt (\line stderr -> fwritec '\n' (fwrites line stderr)) lines stderr
		= (stderr,world)
