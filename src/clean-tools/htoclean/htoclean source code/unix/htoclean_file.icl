implementation module htoclean_file;

// for unix

import StdEnv;

//import ArgEnv;
//args=:getCommandLine;

// assume little endian if 64 bit
global_argc :== IF_INT_64_OR_32 global_argc_64 (global_argc_64 bitand 0xffffffff);

global_argc_64 :: Int;
global_argc_64 = code {
	pushLc global_argc
	load_i 0
}

global_argv :: Int;
global_argv = code {
	pushLc global_argv
	load_i 0
}

load_i :: !Int -> Int;
load_i p = code {
	load_i 0
}

load_ui8 :: !Int -> Int;
load_ui8 p = code inline {
	load_ui8 0
};

load_ui8_char :: !Int -> Char;
load_ui8_char p = code inline {
	load_ui8 0
};

c_string_end :: !Int -> Int;
c_string_end c_string_p
	| load_ui8 c_string_p<>0
		= c_string_end (c_string_p+1);
		= c_string_p;

c_string_length :: !Int -> Int;
c_string_length c_string_p = c_string_end c_string_p-c_string_p;

c_string_to_string :: !Int !Int -> {#Char};
c_string_to_string p length = {load_ui8_char (p+i) \\ i<-[0..length-1]};

program_arg_i :: !Int !Int -> {#Char};
program_arg_i argv i
	# string_p = load_i (argv+IF_INT_64_OR_32 (i<<3) (i<<2));
	= c_string_to_string string_p (c_string_length string_p);

program_args :: {#{#Char}};
program_args
	#! n_args = global_argc;
	#! arg_v = global_argv;
	= {program_arg_i arg_v arg_n \\ arg_n<-[0..n_args-1]};

args=:program_args;

n_args:==size args;
program_arg i:==args.[i];

DirectorySeparator :== '/';

wait_for_keypress :: !*World -> *World;
wait_for_keypress w
	= w;

get_path_name :: !*World -> (!Bool,!String,!*World);
get_path_name w
	# n_arguments=n_args;
	| n_arguments<>2
		# stderr=fwrites "Usage: htoclean h_file_name\n" stderr;
		  stderr=fwrites "Generates a .icl and .dcl file for a c header file\n" stderr;
		  (_,w) = fclose stderr w;
		= (False,"",w);
		# path_name = program_arg 1;
		= (True,path_name,w);
