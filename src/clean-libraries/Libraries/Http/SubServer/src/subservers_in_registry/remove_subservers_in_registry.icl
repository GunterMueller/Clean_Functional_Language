module remove_subservers_in_registry;

import StdEnv,registry;

REGLOCATION :== "SOFTWARE\\Clean HTTP\0";

ERROR_FILE_NOT_FOUND:== 2;
ERROR_ACCESS_DENIED :== 5;

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
	# (r,rs) = RegCloseKey key rs;
	| r<>0
		= abort ("RegCloseKey failed with error code "+++toString r);
	# (r,rs) = RegDeleteKey HKEY_LOCAL_MACHINE REGLOCATION rs;
	| r<>0
		= abort ("RegDeleteKey failed with error code "+++toString r);

	# stdout = fwrites "The subservers have been removed from the registry\n" stdout;
	= snd (fclose stdout w);
