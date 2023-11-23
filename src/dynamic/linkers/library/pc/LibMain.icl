module LibMain;

import
	lib, ReadLibrary;
	
Start world
	#! (q,world) 
		= accFiles f world;	
	= q;
where
{
	f files
		// for creating an archive
		#! (errors, files)
			= CreateArchive archive_name objects files;
		| not (isEmpty errors)
			= abort ("error creating " +++ archive_name);
		= (errors,files);

/*			
		// for listing the contents of an archive
		# (static_libraries,files)
			= ReadStaticLibraries [archive_name] [] files;
		= (static_libraries,files);
*/

	archive_name 
		=  "c:\\StdEnv.lib";
		
	os = [ 	
		"StdEnv.o"
	,	"StdBool.o"
	,	"StdOverloaded.o"
	,	"StdInt.o"
	,	"StdReal.o"
	,	"StdChar.o"
	,	"StdArray.o"
	,	"_SystemArray.o"
	,	"StdString.o"
	,	"StdFile.o"
	,	"StdClass.o"
	,	"StdList.o"
	,	"StdOrdList.o"
	,	"StdTuple.o"
	,	"StdCharList.o"
	,	"StdFunc.o"
	,	"StdMisc.o"
	,	"StdEnum.o"
	,	"_SystemEnum.o"
	,	"StdDebug.o"	
		];
		
	objects
		= [ "c:\\WINDOWS\\Desktop\\Clean\\StdEnv 2.0\\Clean System Files\\" +++ o \\ o <- os ];
}
		