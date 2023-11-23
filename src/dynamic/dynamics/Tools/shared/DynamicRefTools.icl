implementation module DynamicRefTools

import StdEnv
import StdDynamicLowLevelInterface;

import DynID
import DynamicLinkerInterface

::Tree= Node String [Tree] [String] //Node dynname [refstootherdynamics] [typandcode]

readRefsFromBats :: [String] *f -> ([String],[String],*f) | FileSystem f
readRefsFromBats [] w= ([], [], w)
readRefsFromBats [fstFileName:restOfFileNames] world
	#(ok,batFile,world)= fopen fstFileName FReadText world
	|not ok	
		#(referencesOfRecCall,logsOfRecCall,world)= readRefsFromBats restOfFileNames world
		#(_,world)= fclose batFile world
		= (referencesOfRecCall,["DynamicRefTools.readRefsFromBats: file "+++fstFileName+++" cannot be fopened."]++logsOfRecCall,world)

	#(line,batFile)= freadline batFile
	#(_,world)= fclose batFile world
	#(linkerCallInLine,position)= findPattern line "DynamicLinker13.exe"
	|not linkerCallInLine	
		#(referencesOfRecCall,logsOfRecCall,world)= readRefsFromBats restOfFileNames world
		= (referencesOfRecCall,["DynamicRefTools.readRefsFromBats: file "+++fstFileName+++" is not dynamic application."]++logsOfRecCall,world)

	#libReference= line % (position+22,(size line)-3)
	#libReference= CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION GetDynamicLinkerPath libReference
	#typReference= (libReference % (0,(size libReference)-5))+++".typ"
	#(referencesOfRecCall,logsOfRecCall,world)= readRefsFromBats restOfFileNames world
	= ([libReference,typReference]++referencesOfRecCall,logsOfRecCall,world)

	where
		findPattern :: String String -> (Bool,Int)
		/* searches for a pattern(2) in a string(1). gives back the 
		   position if the pattern appeard in the line */
		findPattern line pattern= matchesPattern line pattern 0
		
		matchesPattern :: String String Int -> (Bool,Int)
		matchesPattern _ "" _= (False,0)
		matchesPattern "" _ _= (False,0)
		matchesPattern line pattern position
			#patternSize= size pattern
			|(position+patternSize-1) > (size line)-1	= (False,0)
			#chance= line % (position,position+patternSize-1)
			|chance==pattern	= (True,position)
			= matchesPattern line pattern (position+1)

//GetShortPathName :: !String -> (!Bool,!String);
//This was an attempt to solve the real Eq for Paths but was not succesful
//because UtilIO does not work properly. 

createRealDynamicFilenames :: [String] *f -> ([String],*f) | FileSystem f
createRealDynamicFilenames [] w= ([],w)
createRealDynamicFilenames [fstLinkFileName:restOfLinks] world
	#(success,databaseFileName,world)= get_system_dynamic_identification fstLinkFileName world
	#(databaseFileNames,world)= createRealDynamicFilenames restOfLinks world
	|success
		= ([databaseFileName:databaseFileNames],world)
	= (databaseFileNames,world)

createRealLibraryFilenames :: [String] -> [String]
createRealLibraryFilenames []= []
createRealLibraryFilenames [fstPatient:otherPatients]
	#fstPatient= CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION GetDynamicLinkerPath fstPatient
	#typFile= ADD_TYPE_LIBRARY_EXTENSION fstPatient
	#codeFile= ADD_CODE_LIBRARY_EXTENSION fstPatient
	= [typFile,codeFile]++(createRealLibraryFilenames otherPatients)

readRefsFromDyn :: String [String] *f -> ([String],[String],[String],*f) | FileSystem f
readRefsFromDyn "" logs w= ([],[],logs,w)
readRefsFromDyn dynName logs world
	#(success,header,f,world)= open_dynamic_as_binary dynName world
	|not(success)	
		= ([],[],logs++["DynamicRefTools.readRefsFromDyn: could not open dynamic '"+++dynName+++ "' as binary;"],world)
	#(success,infoOfDyn,f)= read_rts_info_from_dynamic header f
	
	# (_,world)
		= close_dynamic_as_binary f world
	|not(success)	= ([],[],logs++["DynamicRefTools.readRefsFromDyn: could not read rts info from dynamic '"+++dynName+++";"],world)

	#(dynamics,world)= createRealDynamicFilenames (map (\s -> (GetDynamicLinkerPath+++"\\")+++DS_SYSTEM_DYNAMICS_DIR+++"\\"+++s+++"."+++EXTENSION_SYSTEM_DYNAMIC)  (arrayToList infoOfDyn.di_lazy_dynamics_a 0)) world
	#libtyps= createRealLibraryFilenames (arrayToList infoOfDyn.di_library_index_to_library_name 0)
	= (dynamics,libtyps,logs,world)
	
	where 
		arrayToList :: {#{#a}} Int -> [{#a}]
		arrayToList array index
			|size array < (index+1)	= []
			= [array.[index]: arrayToList array (index+1) ]

refTreeBuilder :: [String] *f -> ([Tree],[String],[String],*f) | FileSystem f
refTreeBuilder dynnames world= listBuilder dynnames [] [] world
	where
		listBuilder :: [String] [String] [String] *f -> ([Tree],[String],[String],*f) | FileSystem f
		//parameters: roots in list, dynamics touched so far, logs, w
		//gives back: (built trees in list, dnamics touched while bulding,
		//			   list of log messages produced so far, w.
		listBuilder [] x logs w = ([],x,logs,w)
		listBuilder [fstdynname:odynnames] toucheddyns logs world
			|isMember fstdynname toucheddyns	= listBuilder odynnames toucheddyns logs world

			#(dynRefList,libRefList,logs,nworld)= readRefsFromDyn fstdynname logs world
			#(subtrees,toucheddyns,logs,nworld)= listBuilder dynRefList [fstdynname:toucheddyns] logs nworld
			#(neighbourtrees,toucheddyns,logs,nworld)= listBuilder odynnames toucheddyns logs nworld
			= ([Node fstdynname subtrees libRefList:neighbourtrees],toucheddyns,logs,nworld)

collectReferenced :: [Tree] -> [String]
collectReferenced []= []
collectReferenced [Node dynName dynRefs otherRefs :restOfTrees]= 
	[dynName:otherRefs]++(collectReferenced dynRefs)++collectReferenced restOfTrees
