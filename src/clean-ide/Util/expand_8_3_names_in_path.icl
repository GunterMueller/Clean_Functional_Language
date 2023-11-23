implementation module expand_8_3_names_in_path

//import StdEnv;
import StdArray, StdBool, StdChar, StdClass, StdInt, StdString;

FindFirstFile :: !String -> (!Int,!String);
FindFirstFile file_name
	# find_data = createArray 318 '\0';
	# handle = FindFirstFile_ file_name find_data;
	= (handle,find_data);

FindFirstFile_ :: !String !String -> Int;
FindFirstFile_ file_name find_data
	= code {
		ccall FindFirstFileA@8 "Pss:I"
		}

FindClose :: !Int -> Int;
FindClose handle = code {
		ccall FindClose@4 "PI:I"
	}

find_null_char_in_string :: !Int !String -> Int;
find_null_char_in_string i s
	| i<size s && s.[i]<>'\0'
		= find_null_char_in_string (i+1) s;
		= i;

find_data_file_name find_data
	# i = find_null_char_in_string 44 find_data;
	= find_data % (44,i-1);

find_first_file_and_close :: !String -> (!Bool,!String);
find_first_file_and_close file_name
	# (handle,find_data) = FindFirstFile file_name;
	| handle <> (-1)
		# r = FindClose handle;
		| r==r
			= (True,find_data);
			= (False,find_data);
		= (False,"");

find_last_backslash_in_string i s
	| i<0
		= (False,-1);
	| s.[i]=='\\'
		= (True,i);
		= find_last_backslash_in_string (i-1) s;

expand_8_3_names_in_path :: !{#Char} -> {#Char};
expand_8_3_names_in_path path_and_file_name
	# (found_backslash,back_slash_index) = find_last_backslash_in_string (size path_and_file_name-1) path_and_file_name;
	| not found_backslash
		= path_and_file_name;
	# path = expand_8_3_names_in_path (path_and_file_name % (0,back_slash_index-1));
	# file_name = path_and_file_name % (back_slash_index+1,size path_and_file_name-1);
	# path_and_file_name = path+++"\\"+++file_name;
	# (ok,find_data) = find_first_file_and_close (path_and_file_name+++"\0");
	| ok
		= path+++"\\"+++find_data_file_name find_data;
		= path_and_file_name;
