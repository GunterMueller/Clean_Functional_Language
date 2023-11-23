module dynGarbCollector

import StdEnv,Directory

from CopyFile import IsDirError, ErrorType
import fileSystem,DynamicRefTools,DynID,DynamicUtilities
from DynamicLinkerInterface import GetDynamicLinkerPath

import code from library "ClientChannel_library"

writeOutLogs :: [String] *f -> *f | FileSystem f
/*  This function gets 1. a list of log messages and 2. world, and writes them out to 
	dynGarbCollectionLog.txt;
	gives back
	1. world
*/
writeOutLogs logs world
	#(ok,log_file,world)= fopen (GetDynamicLinkerPath+++"\\"+++"dynGarbCollectorLog.txt") FAppendText world
	|not(ok)= abort (GetDynamicLinkerPath+++"\\"+++"dynGarbCollectorLog.txt file could not be fopen-ed, garbage collection is impossible")

	#veryComplicated= foldl (flip fwrites) log_file o map ((+++) "\n")
	#log_file= veryComplicated logs
	#(ok,world)= fclose log_file world
	|not(ok)= abort ("cannot close log file ("+++GetDynamicLinkerPath+++"\\"+++"dynGarbCollectionLog.txt)")
	= world

LineListReadS :: String *f -> ([String],[String],*f) | FileSystem f
/*	This function gets 1. a filename with path as string 
		(like c:\example\one.ext) and 2. world,
	and gives back the
	1. lines of the file, 2. log messages, 3.world
*/
LineListReadS fname world
	#(readok,inputfile,world)= fopen fname FReadText world
	|readok	 
		#(text,inputfile)= LineListReadF inputfile
		#(_,world)= fclose inputfile world
		= (text,[],world)
		
		#(_,world)= fclose inputfile world		
		= ([],["coolector.LineListReadS: could not (sf)open '"+++fname+++"' in FReadText mode"],world)
	where
		LineListReadF :: *File -> ([String],*File)
		LineListReadF f	#(endOfFile,f)= fend f
						|endOfFile = ([],f)
						#(line,f)= freadline f
						#(textOfRecCall,f)= LineListReadF f
						= ([((%) line (0,size(line)-2)): textOfRecCall],f)

groupByDir :: [String] *f -> ([(Path,[String])],[String],[String],*f) | FileSystem f
/*  This function gets 1. filenames with path as a list of strings
		(like [c:\example\one.ext,c:\example\two.ext]) and 2. world
	gives back 
	1. a list of sorted files (like [(c:\example<in Path type>,[one.ext,two.ext])] ),
	2. a list of files which couldn't be converted into Path type
		(they are in trouble, because they are referenced, and cannot be
		 included in the referenced files' list - maybe they will be deleted.)
	3. log messages
	4. world
*/
groupByDir [] w= ([],[],[],w)
groupByDir list w
	#(list,files_in_trouble,logs,w)= splitFilename list w
	=(foldr searchAndInsert [] list,files_in_trouble,logs,w)
where
	searchAndInsert :: (Path,String) [(Path,[String])] -> [(Path,[String])]
	/*  This function inserts a 1. file into the 2. list of grouped files produced
		so far.
		gives back the
		1. list of grouped files, including the one which was inserted just now.
	*/
	searchAndInsert (aPath, aFileName) []= 	[(aPath,[aFileName])]
	searchAndInsert (aPath, aFileName) [(hdPath,hdFileNameList):t]
		|aPath==hdPath	= [(hdPath,[aFileName:hdFileNameList]):t]
		= [(hdPath,hdFileNameList):(searchAndInsert (aPath,aFileName) t)]

	splitFilename :: [String] *f -> ([(Path,String)],[String],[String],*f) | FileSystem f
	/* gets 1. filenamelist, 2. world; 
		returns: 
		(1. converted filenamelist[(<directory,filename>)], 2.filesInTrouble, 3.logs, 4.world)
		/filesInTrouble are the files which couldn't be converted.
		 (it's quite rare) they are in trouble, because although 
		 they are referenced, they will not appear in the list of
		 referenced files, so they will be supposed to be garbage.
		 (we'll try to "save" them later)/
	*/
	splitFilename [] w	= ([],[],[],w)
	splitFilename [h:t] w
		#((a,b),w)= pd_StringToPath h w
		#(l,list_of_unconvertable_file_names,logs,w)= splitFilename t w
		|not(a)	= (l,[h:list_of_unconvertable_file_names],["collector.splitFileName: could not convert into path "+++h+++"; He is in trouble, maybe he will be deleted, although he is referenced. ":logs],w)

		= ([(splt b):l],list_of_unconvertable_file_names,logs,w)
		where
			splt :: Path -> (Path,String)
			splt (RelativePath list1)= ((RelativePath (init list1)),s1)
			where
				(PathDown s1)= last list1
	
			splt (AbsolutePath diskName list2)= ((AbsolutePath diskName (init list2)),s2)
			where
				(PathDown s2)= last list2

dirFiles :: Path *f -> ([String],[String],*f) | FileSystem f
	//Gives the FILEnames in the specified directory (+log messages) 
	//(and does NOT give back subdirectories)
dirFiles path world
	#((dirError,dirEntries),world)= getDirectoryContents path world
	|IsDirError dirError	#(path_as_string,world)= pathToPD_String path world
	
						= ([],["collector.dirFiles: could not getDirectoryContents of "+++path_as_string+++" because of '"+++(ErrorType dirError)+++"'."],world)
	
	#fileDirEntries= filter isFile dirEntries
	#fileNames= getFileNames fileDirEntries
	= (fileNames,[],world)
	where
		isFile :: DirEntry -> Bool
		isFile aDirEntry= not(aDirEntry.fileInfo.pi_fileInfo.isDirectory)

		getFileNames :: [DirEntry] -> [String]
		getFileNames [h:t]= [h.fileName:getFileNames t]
		getFileNames []= []

notReferencedInDirs :: [(Path,[String])] *f -> ([(Path,[String])],[String],*f) | FileSystem f
//gives back the NOT referenced dynamic, typ and lib files.
notReferencedInDirs [] world= ([],[],world)
notReferencedInDirs [(aPath,referencedFiles):otherDirs] world
	#(filesInDir,logs_of_dirFile,world)= dirFiles aPath world
	#(computedOtherDirs,logs_of_recursive_call,world)= notReferencedInDirs otherDirs world
	= ([(aPath,removeMembers (filter garbageType filesInDir) referencedFiles):computedOtherDirs],(logs_of_dirFile++logs_of_recursive_call),world)
	where
		garbageType :: String -> Bool
		//gives back True, if the specified filename is 
		//*.lib, *.typ or is dynamic
		garbageType ""= False
		garbageType x= typOrLibOrDynamic x
		where
			typOrLibOrDynamic x	
				|size x < 5	= False
				= (ends x ("."+++EXTENSION_CODE_LIBRARY))
				||(ends x ("."+++EXTENSION_TYPE_LIBRARY))
				||(ends x ("."+++EXTENSION_SYSTEM_DYNAMIC))
			where
				hasExtension :: String -> Bool
				hasExtension ""= False
				hasExtension x= x.[0]=='.' || hasExtension ((%) x (1,(size x)-1))


Purge :: [(Path,[String])] *World -> ([String],*World)
//arguments: list of files wished to be deleted, world
//returns log messages, world
Purge [] world= ([],world)
Purge [(fstDir,filenames):restOfDirs] world
	#(curDir,world)= getCurrentDirectory world
	#(dirError,world)= setCurrentDirectory fstDir world
	#(fstDir_as_string,world)= pathToPD_String fstDir world
	|IsDirError dirError	#(logs_of_recursive_call,world)= Purge restOfDirs world
						#log_message= "collector.Purge: could not setCurrentDirectory to "+++fstDir_as_string+++";\n\tI did not delete anything of that directory."
						= ([log_message:logs_of_recursive_call],
						    world)

	#(logs_of_deleteFromActualDir,world)= deleteFromActualDir filenames world
	#(dirError,world)= setCurrentDirectory curDir world
	#(logs_of_recursive_call,world)= Purge restOfDirs world
	= ((logs_of_deleteFromActualDir++logs_of_recursive_call),world)
	where
		deleteFromActualDir :: [String] *World -> ([String],*World)
		deleteFromActualDir [fstFile:restOfFiles] world
			#(dirError,world)= fremove (RelativePath [PathDown fstFile]) world
			#(fstDir_as_string,world)= pathToPD_String fstDir world
			#(logs_of_recursive_call,world)= deleteFromActualDir restOfFiles world
			|IsDirError dirError	//#(logs_of_recursive_call,world)= deleteFromActualDir restOfFiles world
								#log_message= "collector.deleteFromActualDir: could not delete '"+++fstFile+++"' from '"+++fstDir_as_string+++"' because of '"+++(ErrorType dirError)+++"';"
								= ([log_message:logs_of_recursive_call],world)

			#log_message= "collector.deleteFromActualDir: file '"+++fstFile+++"' from '"+++fstDir_as_string+++"' has been deleted. "
			= ([log_message:logs_of_recursive_call], world)
		deleteFromActualDir [] world= ([],world)		

savingFiles :: [(Path,[String])] [String] *f -> ([(Path,[String])],[String],*f) | FileSystem f
/*	This function removes those files from the 1. list, which appear in
	2. second list (as string - like c:\qwer\asdf\zxcv.lkf)
	gives back
	1. remaining of the first argument, 
	2.log messages
	3. world.
	(for filesInTrouble)
*/
savingFiles list [] w= (list,[],w)
savingFiles [] _ w= ([],[],w)
savingFiles [(aPath,[]):t] files_in_trouble w
	#(list,logs,world)= savingFiles t files_in_trouble w
	= ([(aPath,[]):list],logs,world)
savingFiles [(aPath,[fstFile:restOfFiles]):t] files_in_trouble world
	#whole_path_of_fstFile= toWholePath aPath fstFile
	#(whole_path_of_fstFile_as_string,world)= pathToPD_String whole_path_of_fstFile world
	|isMember whole_path_of_fstFile_as_string files_in_trouble
		#(notSavedFiles,logs,world)= savingFiles [(aPath,restOfFiles):t] files_in_trouble world
		#log_message= "collector.savingFiles: "+++whole_path_of_fstFile_as_string+++" was in trouble but I've saved him. He will not be deleted."
		= (notSavedFiles,logs++[log_message],world)
	#([(path,files):t],logs,world)= savingFiles [(aPath,restOfFiles):t] files_in_trouble world
	= ([(path,[fstFile:files]):t],logs,world)
	 
	where
		toWholePath :: Path String -> Path
		toWholePath (RelativePath l) file_name= (RelativePath (l++[PathDown file_name]))
		toWholePath (AbsolutePath diskName l) file_name= (AbsolutePath diskName (l++[PathDown file_name]))

Start :: *World -> ([String],[(Path,[String])],[String],*World)
Start world
	#world= writeOutLogs ["\n\n\n\n\n\n\n       NEW GARBAGE COLLECTION\n\n"]world
	#([rootDir_as_string:unnecessaryLines],logs,world)= LineListReadS (GetDynamicLinkerPath+++"\\"+++"rootDir.txt") world
	#world= writeOutLogs logs world
	|rootDir_as_string== ""	= abort "no root directory"

	#((ok,rootDir_as_path),world)= pd_StringToPath rootDir_as_string world
	|not ok= abort "couldn't convert rootDir into Path. \n\tGarbageCollection refused."

	#(files,logs,world) = collectFiles rootDir_as_path ["dyn","bat"] world
	#(batFiles,dynLinkFiles)= separate ((==) ".bat" o cutLastFour) files
	#world= writeOutLogs logs world

	#(root_list,world)= createRealDynamicFilenames dynLinkFiles world

	#(refTrees,touchedDyns,logs,world)= (refTreeBuilder root_list world)
	#referencedFilesFromDyns= collectReferenced refTrees
	#world= writeOutLogs (logs++["\nUsing these dynamic link files as roots:"]++dynLinkFiles++
		["\nWhich are links to: "]++root_list++
		["\nI've reached the following dynamic files:"]++touchedDyns++
		["\nThey have references to the following files:"]++referencedFilesFromDyns++
		["\n"]) world	

	#(referencedFilesFromBats,logs,world)= readRefsFromBats batFiles world
	#world= writeOutLogs (logs++["\nUsing these application roots:"]++batFiles++
		["\nI collected references to the following files:"]++referencedFilesFromBats++
		["\n"]) world	

	#referencedFiles= referencedFilesFromDyns++referencedFilesFromBats

	#(listOf`DirsWithReferencedFilenameList`,files_in_trouble,logs,world)= groupByDir referencedFiles world
	#world= writeOutLogs logs world
	#(listOf`DirsWithNotReferencedFilenameList`,logs,world)= 
		notReferencedInDirs listOf`DirsWithReferencedFilenameList` world
	#world= writeOutLogs logs world	
	#(listOf`DirsWithUnnecessaryFilenameList`,logs,world)= savingFiles listOf`DirsWithNotReferencedFilenameList` files_in_trouble world
	#world= writeOutLogs logs world	

	#(logs,world)=  Purge listOf`DirsWithUnnecessaryFilenameList` world
	#(logs,world)= lastMessage logs listOf`DirsWithUnnecessaryFilenameList` world
	#world= writeOutLogs (logs++["\n\n\n\n"]) world
	=(["I've purged these files: "],listOf`DirsWithUnnecessaryFilenameList`,["Collection ended."],world)

	where
		lastMessage :: [String] [(Path,[String])] *World -> ([String],*World)
		lastMessage	logs egyik w
			|logs==[] && egyik== []	= (["Nothing was garbage. Nice system."],w)
			|logs==[] 	#(egyik_as_stringlist,w)= tostringlist egyik w
						= ((["Nothing was garbage. (in the database library), but you still have some unnecessary files related to the dynamic system: "]
						 ++egyik_as_stringlist),w)
			= ((logs++["End of collection."]),w)

		cutLastFour :: String -> String
		cutLastFour a
			|size a < 4	= "bullshit"
			= (a % ((size a)-4,(size a)-1))

		tostringlist :: [(Path,[String])] *World -> ([String],*World)
		tostringlist [] w= ([],w)
		tostringlist [(aPath,fileNames):rest] w
			#(pathAsString,w)= pathToPD_String aPath w
			#(resultOfRecCall,w)= tostringlist rest w			
			= ((["DIR: "]++["  "+++pathAsString]++[" FILES: "]++(map ((+++) "   ") fileNames)++["\n"]++resultOfRecCall),w)

