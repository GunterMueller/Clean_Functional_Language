module linker;

import StdInt,StdFile,StdArray,StdBool,StdChar,StdString,StdClass;

import elf_linker,set_return_code;
import ArgEnv;

/*
file_names = [
	"_startup0.o","_startup1.o","_startup2.o","_system.o","t.o","nfib.o"
];

library_file_names = [
	"kernel_library"
];
*/

/*
n_args :: Int;
n_args = code {
	ccall n_args "-I"
}

program_arg :: !Int -> {#Char};
program_arg i = code {
	ccall program_arg "I-S"
}

parse_arguments = program_arguments 1 n_args;
{
	program_arguments n n_args
		| n>=n_args
			= ([],[]);
		| size argument>=2 && argument.[0]=='-' && argument.[1]=='l'
			= (files1,[argument % (2,size argument-1):libraries1]);
			= ([argument:files1],libraries1);
		{}{
			argument=program_arg n;
			(files1,libraries1)=program_arguments (inc n) n_args;
		}
}
*/

parse_arguments
	# args=getCommandLine;
	# n_args=size args;
	# a = program_arguments 1;
	{
		program_arguments n
			| n>=n_args
				= ([],[],[],[]);
			# argument=args.[n];
			| argument=="-e"
				# (files,libraries,exported_symbol_names,exported_symbol_names_files)
					= program_arguments (n+2);
				= (files,libraries,[args.[n+1]:exported_symbol_names],exported_symbol_names_files);
			| argument=="-E"
				# (files,libraries,exported_symbol_names,exported_symbol_names_files)
					= program_arguments (n+2);
				= (files,libraries,exported_symbol_names,[args.[n+1]:exported_symbol_names_files]);
			# (files,libraries,exported_symbol_names,exported_symbol_names_files)
				= program_arguments (n+1);
			| size argument>=2 && argument.[0]=='-' && argument.[1]=='l'
				= (files,[argument % (2,size argument-1):libraries],exported_symbol_names,exported_symbol_names_files);
				= ([argument:files],libraries,exported_symbol_names,exported_symbol_names_files);
	}
	= a;

Start world
	# (file_names,library_file_names,exported_symbol_names,exported_symbol_names_files) = parse_arguments;
	# [output_object_file_name:file_names] = file_names;
	# ((ok,undefined_symbols),world) = accFiles (link_elf_files2 file_names exported_symbol_names exported_symbol_names_files output_object_file_name) world;
	# world = set_return_code (if ok 0 (-1)) world;
	# (stdout,world) = stdio world;
	= print_errors undefined_symbols stdout;

print_errors [] f
	= f;
print_errors [error:errors] f
	= print_errors errors (fwritec '\n' (fwrites error f));

read_lines file
	# (line,file) = freadline file;
	| size line==0
		= ([],file);
	| line.[size line-1]=='\n'
		#! line = line % (0,size line-2);
		# (lines,file) = read_lines file;
		= ([line:lines],file);
		= ([line],file);

read_exported_symbol_names_files [exported_symbol_names_file:exported_symbol_names_files] files
	# (ok,file,files) = fopen exported_symbol_names_file FReadText files;
	| not ok
		= (False,["Could not open file: "+++exported_symbol_names_file],[],files);
	# (exported_symbol_names,file) = read_lines file;
	# (ok,files) = fclose file files
	| not ok
		= (False,["Could not read file: "+++exported_symbol_names_file],[],files);
	# (ok,errors,exported_symbol_names_in_files,files)
		= read_exported_symbol_names_files exported_symbol_names_files files;
	| not ok
		= (False,errors,[],files)
		= (True,[],append exported_symbol_names exported_symbol_names_in_files,files);
read_exported_symbol_names_files [] files
	= (True,[],[],files);

append l [] = l;
append l t = append l t;
{
	append [] t = t;
	append [e:l] t = [e:append l t];
}

link_elf_files2 file_names exported_symbol_names exported_symbol_names_files exec_file_name files
	# (ok,errors,exported_symbol_names,files)
		= case exported_symbol_names_files of {
			[]
				-> (True,[],["main":exported_symbol_names],files);
			_
				# (ok,errors,exported_symbol_names_in_files,files)
					= read_exported_symbol_names_files exported_symbol_names_files files;
				-> (ok,errors,append exported_symbol_names exported_symbol_names_in_files,files);
		  }
	| not ok
		= ((ok,errors),files);
	# (ok,undefined_symbols,files) = link_elf_files file_names exported_symbol_names exec_file_name files;
	= ((ok,undefined_symbols),files);
