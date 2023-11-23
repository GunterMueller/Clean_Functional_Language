// this is for Windows
implementation module CoclSystemDependent

import code from library "backend_library"

import StdEnv
import ArgEnv
import DirectorySeparator

// import for filesystem
import code from "cDirectory." // Windows
from filesystem import ensureDirectoryExists

PathSeparator
	:==	';'

SystemDependentDevices :: [a]
SystemDependentDevices
		=	[]

SystemDependentInitialIO :: [a]
SystemDependentInitialIO
		=	[]

ensureCleanSystemFilesExists :: !String !*Files -> (!Bool, !*Files)
// returned bool: now there is such a subfolder
ensureCleanSystemFilesExists path env
	= ensureDirectoryExists path env

import thread_message;

import code from "c_thread_message.";

set_compiler_id :: !Int -> Int
set_compiler_id compiler_id = code {
	ccall	set_compiler_id "I:I"
 };

get_compiler_id :: Int
get_compiler_id = code {
	ccall	get_compiler_id ":I"
 };

compiler_loop :: ([{#Char}] *st -> *(Bool, *st)) *st -> (!Bool, !*st)
compiler_loop compile compile_state
	| length commandArgs==2 && commandArgs!!0=="-ide"
		# wm_number=get_message_number;
		# thread_id=hex_to_int (commandArgs!!1);
		= (True,compile_files compile thread_id wm_number compile_state)
		# (r,compile_state)=compile commandArgs compile_state
		= (r,compile_state)
	where
		commandArgs
			=	tl [arg \\ arg <-: getCommandLine]

hex_to_int :: {#Char} -> Int
hex_to_int s
	= hex_to_int 0 0;
	where
		l=size s;

		hex_to_int i n
			| i==l
				= n;
				# c=s.[i];
				# i=i+1;
				# n=n<<4;
				| c<='9'
					= hex_to_int i (n bitor (toInt c-toInt '0'));
					= hex_to_int i (n bitor (toInt c-(toInt 'A'-10)));

string_to_args string
	= string_to_args 0;
	where
		l=size string;
		
		string_to_args i
			# end_spaces_i=skip_spaces i;
			| end_spaces_i==l
				= []
			| string.[end_spaces_i]=='"'
				# next_double_quote_i=skip_to_double_quote (end_spaces_i+1)
				| next_double_quote_i>=l
					= [string % (end_spaces_i,l-1)]
					# arg=string % (end_spaces_i+1,next_double_quote_i-1);
					= [arg : string_to_args (next_double_quote_i+1)];
				# space_i=skip_to_space (end_spaces_i+1)
				| space_i>=l
					= [string % (end_spaces_i,l-1)]
					# arg=string % (end_spaces_i,space_i-1);
					= [arg : string_to_args (space_i+1)];

		skip_spaces i
			| i>=l
				= l;
			# c=string.[i];
			| c==' ' || c=='\t'
				= skip_spaces (i+1);
				= i;

		skip_to_space i
			| i>=l
				= l;
			# c=string.[i];
			| c==' ' || c=='\t'
				= i;
				= skip_to_space (i+1);

		skip_to_double_quote i
			| i>=l
				= l;
			# c=string.[i];
			| c=='"'
				= i;
				= skip_to_double_quote (i+1);

compile_files compile thread_id wm_number compile_state
	# (r,a,s) =get_integers_from_message wm_number;
	| r==0
		= abort "compile_files 1";
	# string=createArray a '\0';
	# r=get_string_from_file_map_and_delete_map s string;
	| r==0
		= abort ("compile_files 2 ");
	# args=string_to_args (string % (0,size string-2))
	= case args of
		["cocl":cocl_args]
			# (ok,compile_state)=compile cocl_args compile_state
			# result=if ok 0(-1);
			# r=send_integers_to_thread thread_id wm_number get_compiler_id result;
			| r==0
				-> abort "compile_files 3";
				-> compile_files compile thread_id wm_number compile_state
		["exit"]
			-> compile_state;
		_
				-> abort "compile_files 4"
