implementation module DynamicLink;

import deltaDialog, deltaIOSystem, deltaWindow, deltaIOState, StdString, StdChar;
 
from StdMisc import abort;
from StdBool import not, ||, &&;
from StdInt import <;
import StdClass;

import ExtString;
import ExtFile;
import Directory;
import CallCg;
import ProcessSerialNumber;

class older_than_or_equal a	:: !a	!a	->	(!Bool,!Bool);

instance older_than_or_equal Date`
where {	
	older_than_or_equal {year`=year1,month`=month1,day`=day1} {year`=year2,month`=month2,day`=day2}
		| year1 < year2 
				= (True,False);
				| year1 == year2
					| month1 < month2
						= (True,False);
						| month1 == month2
							| day1 < day2
								= (True,False);
								
								// data equal or bigger
								= (False, day1 == day2);
							// month1 > month2
							= (False,False);
					// year1 > year2
					= (False,False);
};

instance older_than_or_equal Time`
where {
	older_than_or_equal {hours`=hours1,minutes`=minutes1,seconds`=seconds1} {hours`=hours2,minutes`=minutes2,seconds`=seconds2}
		| hours1 < hours2 
			= (True,False);
			| hours1 == hours2
				| minutes1 < minutes2
					= (True,False);
					| minutes1 == minutes2
						| seconds1 < seconds2
							= (True,False);
							// time equal or bigger
							= (False, seconds1 == seconds2);
						// minutes1 > minutes2
						= (False,False);
				// hours1 > hours2
				= (False,False);
};


instance older_than_or_equal (!Date`, !Time`)	// DateTime
where {
	older_than_or_equal (date1,time1) (date2,time2)
		# (older,equal)
			= older_than_or_equal date1 date2
		| older 
			= (True,False);
			| equal
				# (older,equal)
					= older_than_or_equal time1 time2;
				| older
					= (True,False);			
					= (False,equal);
				= (False,False);
};

instance toString DirError
where {
	toString NoDirError = "NoDirError";
	toString DoesntExist = "DoesntExist";
	toString BadName = "BadName";
	toString NotEnoughSpace = "NotEnoughSpace";
	toString AlreadyExists = "AlreadyExists";
	toString NoPermission = "NoPermission";
	toString MoveIntoOffspring = "MoveIntoOffspring";
	toString MoveAcrossDisks = "MoveAcrossDisks";
	toString NotYetRemovable = "NotYetRemovable";
	toString OtherDirError = "OtherDirError";
};


/*
GenObj :: !String !String !*Files -> (!Bool,!Bool,!String,!String,!*Files);
GenObj cgpath path_and_file files
	= GenObj2 cgpath path_and_file files;
*/
/*
	GenObj2
		
	Improvements:
		- if code generator changes path, then it can not be found (no dialogue pops up; cancel unimplemented)
		- version of code generator doesn't yet matter
*/

/*
GenObj2 :: !String !String !*Files -> (!Bool,!Bool,!String,!String,!*Files);
GenObj2 cgpath path_and_file files
	| not (ends path_and_file ".o" || ends path_and_file ".obj" || ends path_and_file ".abc")
		= abort ("DynamicLink (GenObj): file " +++ path_and_file +++ " doesn't end with {abc,o,obj}-extension");
		
		#! (path_file,extension)
			= ExtractPathFileAndExtension path_and_file;
		| extension == "obj"
			= abort ("DynamicLink (GenObj): object not generated by cg " +++ path_and_file);

			// (re)create the file_name with the {.abc,.o}-extensions
			// collect .abc info
			#! abc_path_file
				= path_file +++ ".abc";
			#! ((ok,abc_file),files)
				= pd_StringToPath abc_path_file files;
			| not ok
				= abort ("DynamicLink (GenObj):  something went wrong during path conversion 1");
			
			// collect .o info
			#! o_path_file
				= path_file +++ ".o";
			#! ((ok,o_file),files)
				= pd_StringToPath o_path_file files;
			| not ok
				= abort ("DynamicLink (GenObj):  something went wrong during path conversion 2");
				
			// get the file info
			# ((abc_dir_error,abc_file_info),files)
				= getFileInfo abc_file files;
			# ((o_dir_error,o_file_info),files)
				= getFileInfo o_file files;
					
			| (abc_dir_error == DoesntExist) && (o_dir_error == DoesntExist)
				// given path was invalid; pop up a dialogue
				= abort ("nothing exists" );
			| (abc_dir_error == DoesntExist) && (o_dir_error <> DoesntExist)
				// only .o exists; assume it to be up-to-date
				= (True,False,o_path_file,"",files);	
			| (abc_dir_error <> DoesntExist) && (o_dir_error == DoesntExist)
				// only .abc exists; then generate corresponding .o
				#! (s,ok)
					= CodeGen path_file;
				| ok
					= (True,False,s,"",files);
					
					= abort "problems during .o generation";
		
			// both extensions of the file exist. is .o out of date?
			#! abc_datetime
				= abc_file_info.pi_fileInfo.lastModified;
			#! o_datatime
				= o_file_info.pi_fileInfo.lastModified;
			#! (older,equal)
				= older_than_or_equal abc_datetime o_datatime;
			| not older && not equal
				// .abc is newer as its corresponding .o; generate a new .o
				# (s,ok)
					=  CodeGen path_file;
				| ok
					= (True,False,s,"",files);
					= abort ("not ok" +++ s);
				// .o is up-to-date 
				= (True,False,o_path_file,"",files);
*/
				
GetModulePath :: !String !String !Int !String -> (!Bool,!String,!Bool);
GetModulePath s1 s2 _ _ 
	= abort ("GetModulePath in DynamicLink not yet implemented: " +++ s1 +++ " - " +++ s2);
  	
GetSymbolPath :: !String !Int !String !String !String -> (!String,!Bool,!String);
GetSymbolPath _ _ _ _ _ 
	= abort "GetSymbolPath in DynamicLink not yet implemented";
	

