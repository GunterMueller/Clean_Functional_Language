module linker;

import StdEnv;
import ArgEnv;
import xcoff_linker;

find_comma i n a
	| i<n
		| a.[i]==","
			= i;
			= find_comma (i+1) n a;
		= -1;

to_int s
	| size s==0
		= 0
	# last_char=s.[size s-1];
	| last_char=='m' || last_char=='M'
		= to_int (s % (0,size s-2)) << 20;
	| last_char=='k' || last_char=='K'
		= to_int (s % (0,size s-2)) << 10;
		= toInt s;

Start world
	# args = getCommandLine;
	# n_args = size args;
	# output_file_name = args.[n_args-1]
	# heap_size = to_int args.[1]
	# initial_heap_size = to_int args.[2]
	# heap_size_multiple = toInt args.[3]
	# extra_application_memory = to_int args.[4]
	# stack_size = to_int args.[5]
	# flags = toInt args.[6]
	# first_object_file_index = 7
	# comma_arg_index = find_comma first_object_file_index (n_args-1) args;
	| comma_arg_index<0
		= (False,["Usage: linker heap_size initial_heap_size heap_size_multiple extra_application_memory stack_size flags object_files , library_files output_file"]);
	# object_file_names = [args.[file_name_i] \\ file_name_i<-[first_object_file_index..comma_arg_index-1]];
	# library_file_names = [args.[file_name_i] \\ file_name_i<-[comma_arg_index+1..n_args-2]];
	# ((ok1,undefined_symbols),world)
		= accFiles
			(link_xcoff_files object_file_names library_file_names output_file_name
			(9,"Monaco") heap_size heap_size_multiple stack_size flags extra_application_memory initial_heap_size 0 False True) world;
	= (ok1,undefined_symbols);
