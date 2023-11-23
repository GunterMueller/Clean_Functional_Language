implementation module PmPath

/* OS dependent operations on filenames for windows 95 and NT */

import StdClass,StdString, StdChar, StdBool, StdChar,StdInt, StdMisc,StdArray;
import StdFile
import StdPathname

//from StdSystem import dirseparator
dirseparator	:==	'\\'				// OS separator between folder- and filenames in a pathname

import UtilDiagnostics
import UtilStrictLists, PmMyIO, PmTypes

//import StdDebug

/* The name of the system directory */

SystemDir			:== "Clean System Files";

//--

IsDefPathname :: !Pathname -> Bool;
IsDefPathname name =  equal_suffix ".dcl" name;

IsImpPathname :: !Pathname -> Bool;
IsImpPathname name =  equal_suffix ".icl" name;
	
IsPrjPathname :: !Pathname -> Bool;
IsPrjPathname name =  equal_suffix ".prj" name;

MakeDefPathname	:: !String -> Pathname;
MakeDefPathname name =  RemoveSuffix name  +++ ".dcl";

MakeImpPathname	:: !String -> Pathname;
MakeImpPathname name = RemoveSuffix name  +++ ".icl";
			
MakeABCPathname	:: !String -> Pathname;
MakeABCPathname name = RemoveSuffix name  +++ ".abc";
	
MakeObjPathname	:: !Processor !String -> Pathname;
MakeObjPathname processor name
	| processor == CurrentProcessor
		= RemoveSuffix name  +++ ".o";
	| processor == MC68000
		= RemoveSuffix name +++ ".obj0";
	| processor == MC68020
		= RemoveSuffix name +++ ".obj1";
	| processor == MC68020_and_68881
		= RemoveSuffix name +++ ".obj2";
		= abort ("MakeObjPathname: " +++  toString processor +++ " : No such processor ");
	
MakeProjectPathname	:: !String -> Pathname;
MakeProjectPathname name = RemoveSuffix name   +++ ".prj";

MakeExecPathname :: !String -> Pathname;
MakeExecPathname name = RemoveSuffix name+++".exe";
	
MakeABCSystemPathname :: !Pathname !Files -> (!Pathname,!Files);
MakeABCSystemPathname abcname files
	= (directory_name_plus_system_dir +++ sep +++ file +++ ".abc",files);
where
		directory_name_plus_system_dir
			| equal_suffix SystemDir dir
				= dir;
				= dir +++ sep +++ SystemDir;
		dir		= RemoveFilename abcname;
		sep		= toString dirseparator;
		file	= RemovePath (RemoveSuffix abcname);
	
MakeObjSystemPathname :: !Processor !Pathname !Files -> (!Pathname,!Files);
MakeObjSystemPathname processor name files
	| processor == CurrentProcessor
		= files_and_path ".o";
	| processor == MC68000
		= files_and_path ".obj0";
	| processor == MC68020
		= files_and_path ".obj1";
	| processor == MC68020_and_68881
		= files_and_path ".obj2";
		= abort ("MakeObjSystemPathname: " +++  toString processor +++ " : No such processor ");
where
		files_and_path extension = (directory_name_plus_system_dir +++ sep +++ file+++extension,files);
		directory_name_plus_system_dir
			| equal_suffix SystemDir dir
				= dir;
				= dir +++ sep +++ SystemDir;
		dir		= RemoveFilename name;
		sep		= toString dirseparator;
		file	= RemovePath (RemoveSuffix name);
	
GetModuleName :: !Pathname -> Modulename;
GetModuleName name =  RemoveSuffix (RemovePath name);

