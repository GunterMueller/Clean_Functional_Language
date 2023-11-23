module StaticLinker;

import StdInt,StdFile;
import PlatformLinkOptions;
from Linker import link_xcoff_files;



file_names1 = [
	":Martijn's Disk:Clean 1.3.2 (PPC):StdEnv:Clean System Files:_startup.o",
	"Clean:StdEnv1.3:Clean System Files:_system.o",

//	":Clean System Files:test.o",
	":Clean System Files:test2.o",

//	"Clean:StdEnv1.3:Clean System Files:StdInt.o",

	"Clean:Desktop Folder:CleanPrograms:Linker:Clean System Files:dynamicstart.o",

//	"callc.o",
//	"copy_int_to_string.o",
//	"copy_int_to_string.lib",
//	"Clean:Desktop Folder:CleanPrograms:Linker:Clean System Files:callc.o",

	"Clean:StdEnv1.3:Clean System Files:_library.o",

	"Clean:Desktop Folder:CleanPrograms:Linker:l.o"
];

objects_and_libraries :: (![!String],![!String],!String);
objects_and_libraries 
	= (file_names,library_file_names,executable);
where {
	executable
		= test_prj_without_clean_system_files +++ "a.xcoff"; //"Clean:Desktop Folder:CleanPrograms:a.xcoff";

	file_names :: ![!String];
	file_names = [
		// runtime system
			stdenv +++ "_startup.o"
		,	stdenv +++ "_system.o"
		,	stdenv +++ "_library.o"
		

		// stdenv
		,	stdenv +++ "_SystemEnum.o"
		,	stdenv +++ "StdInt.o"
		,	stdenv +++ "StdChar.o"
		,	stdenv +++ "StdMisc.o"
/*
		, 	stdenv +++ "_SystemArray.o"
		,	stdenv +++ "StdArray.o"
		,	stdenv +++ "StdBool.o"
		,	stdenv +++ "StdChar.o"

		,	stdenv +++ "StdCharList.o"
		,	stdenv +++ "StdClass.o"
		,	stdenv +++ "StdEnum.o"
//		,	stdenv +++ "StdEnv.o"
		,	stdenv +++ "StdFile.o"
		,	stdenv +++ "StdFunc.o"

		,	stdenv +++ "StdList.o"

		,	stdenv +++ "StdOrdList.o"
		,	stdenv +++ "StdOverloaded.o"
		,	stdenv +++ "StdReal.o"
		,	stdenv +++ "StdString.o"
		,	stdenv +++ "StdTuple.o"
*/


		// project
		//,	test_prj +++ "test.o"
		,	test_prj +++ "sieve.o"
//				,	"www:MAC Backup 3:Linker John (orginineel):l.o"
		];
		
	library_file_names :: ![!String];
	library_file_names = [
			stdenv +++ "library0"
		,	stdenv +++ "library1"
		,	stdenv +++ "library2"
		];
		
	test_prj_without_clean_system_files
		= "Clean:Test project:";
	test_prj
		= test_prj_without_clean_system_files +++ "Clean System Files:";
	stdenv 
		= "Clean:StdEnv:Clean System Files:";
}


import
	StdEnv;

Start world
	= accFiles f world;
where {
	f files
		# (file_names,library_file_names,executable)
			= objects_and_libraries;
		# normal_static_link
			= True; //False; //True;
		# static_libraries
			= [];
		# (state,files) 
			= link_xcoff_files normal_static_link file_names library_file_names static_libraries executable DefaultPlatformLinkOptions files;
		# (messages,state)
			= GetLinkerMessages state;		



		= (messages,files);
}
/*
	# (messages,state)
		= st_getLinkerMessages state;		
	# (err,world) = accFiles (WriteLinkErrors messages) world
	
	#! (ok,state)
		= st_isLinkerErrorOccured state;
*/