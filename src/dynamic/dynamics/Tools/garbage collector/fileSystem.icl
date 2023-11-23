implementation module fileSystem

import StdEnv, Directory
from CopyFile import ErrorType

instance == PathStep
	where
	 (==) :: !PathStep !PathStep -> Bool
	 (==) PathUp PathUp = True
	 (==) (PathDown a) (PathDown b)= (smallCaps a) == (smallCaps b)
	 (==) _ _= False
	 
instance == Path
	where
	 (==) :: !Path !Path -> Bool
	 (==) (RelativePath a) (RelativePath b)= 			a==b
	 (==) (AbsolutePath x1 y1) (AbsolutePath x2 y2)= 	(smallCaps x1==smallCaps x2) && (y1==y2)
	 (==) _ _= False

smallCaps :: String -> String
smallCaps szoveg
	= (toString o map small o fromString) szoveg
	where	
		small :: Char -> Char
		small betu	|betu=='A'	= 'a'
					|betu=='B'	= 'b'
					|betu=='C'	= 'c'
					|betu=='D'	= 'd'
					|betu=='E'	= 'e'
					|betu=='F'	= 'f'
					|betu=='G'	= 'g'
					|betu=='H'	= 'h'
					|betu=='I'	= 'i'
					|betu=='J'	= 'j'
					|betu=='K'	= 'k'
					|betu=='L'	= 'l'
					|betu=='M'	= 'm'
					|betu=='N'	= 'n'
					|betu=='O'	= 'o'
					|betu=='P'	= 'p'
					|betu=='Q'	= 'q'
					|betu=='R'	= 'r'
					|betu=='S'	= 's'
					|betu=='T'	= 't'
					|betu=='U'	= 'u'
					|betu=='V'	= 'v'
					|betu=='W'	= 'w'
					|betu=='X'	= 'x'
					|betu=='Y'	= 'y'
					|betu=='Z'	= 'z'
					= betu

separate :: (a -> Bool) [a] -> ([a],[a])
/* The result is the list, separated by the condition. */
separate condition list= separate_ condition list ([],[])
where
	separate_ :: (a -> Bool) [a] ([a],[a]) -> ([a],[a])
	separate_ _ [] (list1,list2)= (list1,list2)
	separate_ condition [h:t] (fulfillingElements,notfulfillingElements)
		|condition h= separate_ condition t ([h:fulfillingElements],notfulfillingElements)
		= separate_ condition t (fulfillingElements,[h:notfulfillingElements])


collectFiles :: Path [String] *f -> ([String],[String],*f) | FileSystem f
collectFiles a b c= collectFiles_ [a] b c

collectFiles_ :: [Path] [String] *f -> ([String],[String],*f) | FileSystem f
collectFiles_ [] _ w= ([],[],w)
collectFiles_ [rootPath:otherRoots] extensions world
	#((dirError,dirEntries),world)= getDirectoryContents rootPath world
	#(rootPath_as_string,world)= pathToPD_String rootPath world
	|dirError<>NoDirError	#log_message= "fileSystem.collectFiles: could not getDirectoryContents of '"+++rootPath_as_string+++"';\n\tbecause of "+++(ErrorType dirError)+++";\n\tI did not collect files from that directory."
							= ([],[log_message],world)

	#(files,subDirs)= separate isFile dirEntries
	#fileNames_as_path= map (wholePath) files
	#(fileNames_as_string,world)= convert fileNames_as_path world     
	#resultFileNames= filter hasWishedExtension fileNames_as_string

	#subDirs= filter notDot subDirs
	#subDirNames_as_path= map (wholePath) subDirs

	#(resultOfSubDirs,logsOfSubDirs,world)= collectFiles_ subDirNames_as_path extensions world
	#(resultOfOtherRoots,logsOfOtherRoots,world)= collectFiles_ otherRoots extensions world	

	= (resultFileNames++resultOfSubDirs++resultOfOtherRoots,logsOfSubDirs++logsOfOtherRoots,world)

	where
		notDot :: DirEntry -> Bool
		notDot a	|a.fileName=="." || a.fileName==".."	= False
				= True
		
		cutLastFour :: String -> String
		cutLastFour a
			|size a < 4	= "bullshit"
			= (a % ((size a)-4,(size a)-1))

		hasWishedExtension :: String -> Bool
		hasWishedExtension a
			|isMember (cutLastFour a) (map ((+++) ".") extensions)= True
			= False

		convert :: [Path] *f -> ([String],*f) | FileSystem f
		convert [] w= ([],w)
		convert [h:t] world
			#(result,world)= pathToPD_String h world
			#(resultsOfRecCall,world)= convert t world
			= ([result:resultsOfRecCall],world)

		isFile :: DirEntry -> Bool
		isFile aDirEntry= not(aDirEntry.fileInfo.pi_fileInfo.isDirectory)

		wholePath :: DirEntry -> Path
		wholePath entry
			= case rootPath of
				(AbsolutePath diskName pathSteps)
					-> (AbsolutePath diskName (pathSteps++[(PathDown entry.fileName)]))
				(RelativePath pathSteps)
					-> (RelativePath (pathSteps++[(PathDown entry.fileName)]))
				_	-> abort "Path typed variable not valid."

