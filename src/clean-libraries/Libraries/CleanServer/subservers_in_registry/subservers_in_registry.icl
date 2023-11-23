module subservers_in_registry;

import StdEnv,registry;

REGLOCATION :== "SOFTWARE\\Clean HTTP\0";

ERROR_FILE_NOT_FOUND:== 2;
ERROR_ACCESS_DENIED :== 5;
ERROR_NO_MORE_ITEMS :== 259;

Start w
	# rs=0;
	# (stdout,w) = stdio w;
	# (r,key,rs) = RegOpenKeyEx HKEY_LOCAL_MACHINE REGLOCATION 0 KEY_ALL_ACCESS rs;
	| r==ERROR_FILE_NOT_FOUND
		# stdout = fwrites "No subservers are stored in the registry\n" stdout;
		= snd (fclose stdout w);
	| r<>0
		| r==ERROR_ACCESS_DENIED
			= abort ("RegOpenKeyEx failed with error code "+++toString r+++" (access denied)");
			= abort ("RegOpenKeyEx failed with error code "+++toString r);

	# (data,rs) = read_key_data_strings key 0 rs;
	# (r,rs) = RegCloseKey key rs;
	| r<>0
		= abort ("RegCloseKey failed with error code "+++toString r);
	| isEmpty data
		# stdout = fwrites "No subservers are stored in the registry\n" stdout;
		= snd (fclose stdout w);
		# stdout = fwrites "The following subservers are stored in the registry:\n" stdout;
		# stdout = foldl (\f s -> fwritec '\n' (fwrites s f)) stdout data; 
		= snd (fclose stdout w);

read_key_data_strings key index rs
	# (r,value_name,type,data,rs) = RegEnumValue key index 256 0 4096 rs;
	| r==ERROR_NO_MORE_ITEMS
		= ([],rs);
	| r<>0
		= abort ("RegEnumValue failed with error code "+++toString r);
	| type==REG_SZ
		# (more_data,rs) = read_key_data_strings key (index+1) rs;
		= ([data:more_data],rs);
		= read_key_data_strings key (index+1) rs;
