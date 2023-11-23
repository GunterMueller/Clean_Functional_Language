implementation module get_startup_dir

import StdEnv

FStartUpDir :: !Files -> (!String, !Files);
FStartUpDir files
	# s_p = get_appl_path_address;
	# (s,s_p) = c_string_to_clean_string s_p;
	= (s,files);

c_string_to_clean_string :: !Int -> (!.{#Char},!Int);
c_string_to_clean_string s_p
	# end_p = c_string_end s_p;
	= ({c_string_char p \\ p<-[s_p..end_p-1]},s_p);

c_string_end :: !Int -> Int;
c_string_end p
	| c_string_char p<>'\0'
		= c_string_end (p+1);
		= p;

c_string_char :: !Int -> Char;
c_string_char p = code inline {
	load_ui8 0
 }

get_appl_path_address :: Int;
get_appl_path_address = code {
	pushLc appl_path
}
