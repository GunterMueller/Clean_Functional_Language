implementation module ExtFile;

import StdInt, StdClass;
from StdFile import fwritei,fwrites,fwritec;
from StdBool import &&, ||;
import pdExtFile;
import ExtString;
import ExtArray;
import StdEnv;

// from File
(FWI) infixl;
(FWI) f i :== fwritei i f;

(FWS) infixl;
(FWS) f s :== fwrites s f;

(FWC) infixl;
(FWC) f c :== fwritec c f;

(FWZ) infixl;
(FWZ) f i :== write_zero_bytes_to_file i f;

(THEN) infixl;
(THEN) a f :== f a;

write_zero_bytes_to_file :: !Int !*File -> *File;
write_zero_bytes_to_file n pef_file0
	| n==0
		= pef_file0;
		= write_zero_bytes_to_file (dec n) (fwritec '\0' pef_file0);
		
write_zero_longs_to_file :: !Int !*File -> *File;
write_zero_longs_to_file n pef_file0
	| n==0
		= pef_file0;
		= write_zero_longs_to_file (dec n) (fwritei 0 pef_file0);
		
construct_path :: !String !String -> String;
construct_path path file_name
	| (path == "") || (path == (toString path_separator))
		= path +++ file_name;
		= path +++ (toString path_separator) +++ file_name;

ExtractPathFileAndExtension :: !String -> (!String,!String);
ExtractPathFileAndExtension path_and_file 
	| dot_found && not path_separator_after_dot_found
		#! extension
			= path_and_file % (inc dot_index,size path_and_file-1);
		#! pathfile
			= path_and_file % (0, dot_index-1);
		= (pathfile,extension);
		
		= (path_and_file,"");
where {
	(dot_found,dot_index)
		= CharIndexBackwards path_and_file (size path_and_file - 1) '.';
	(path_separator_after_dot_found,path_sep_index)
		= CharIndex path_and_file (inc dot_index) path_separator;
}

loopAonOutput f a output :== loopAonOutput2 f a output
where {
	loopAonOutput2 f a output
		#! (s_a,a)
			= usize a;
		#! output
			= fwritei s_a output;
		= loopA f a output;
}

loopAurOnOutput f a output :== loopAurOnOutput f a output
where {
	loopAurOnOutput f a output
		#! (s_a,a)
			= usize a;
		#! output
			= fwritei s_a output;
		= loopAur f a output;
}
// input
loopAfillOnInput f s :== loopAfillOnInput f s
where {
	loopAfillOnInput f s
		#! (_,s_a,s)
			= freadi s;
		= loopAfill f (createArray s_a ExtArrayDefaultElem) s
}
		
loopAurfillOnInput f s :== loopAfillOnInput f s
where {
	loopAfillOnInput f s
		#! (_,s_a,s)
			= freadi s;
		= loopAfill f {ExtArrayDefaultElem \\ i <- [1..s_a]} s
}

read_int :: !Int !*{#Int} !*File -> (!*{#Int},!*File);
read_int i a input
	#! (_,n,input)
		= freadi input;
	= ({ a & [i] = n}, input);
	
extract_module_name :: !String -> String;
extract_module_name path_file_extension 
	#! (_,file_extension)
		= ExtractPathAndFile path_file_extension;
	| ends file_extension ".obj"
		= file_extension;
		= fst (ExtractPathFileAndExtension file_extension);
		
strip_abc_and_o_extension path_file_extension :== if ((ends path_file_extension ".obj") || (ends path_file_extension ".lib")) path_file_extension (fst (ExtractPathFileAndExtension path_file_extension));
strip_paths_from_file_names files :== map (\path_name_extension -> (snd (ExtractPathAndFile path_name_extension))) files;

ExtractPathAndFile :: !String -> (!String,!String);
ExtractPathAndFile path_and_file 
	#! (dir_delimiter_found,i)
		= CharIndexBackwards path_and_file (size path_and_file - 1) path_separator;
	| dir_delimiter_found
		# file_name_with_extension = path_and_file % (i+1,size path_and_file - 1);
		= (if (i == 0) (toString path_separator) (path_and_file % (0,i-1)),file_name_with_extension);
		= ("",path_and_file);

ExtractFileNameFromPath :: !String -> String;
ExtractFileNameFromPath path_and_file 
	#! (dir_delimiter_found,i)
		= CharIndexBackwards path_and_file (size path_and_file - 1) path_separator;
	| dir_delimiter_found
		= path_and_file % (i+1,size path_and_file - 1);
		= path_and_file;

ExtractFileName :: !String -> String;
ExtractFileName path_name_ext
	#! (_,name_ext) = ExtractPathAndFile path_name_ext;
	#! (name,ext) = ExtractPathFileAndExtension name_ext;
	= name;
