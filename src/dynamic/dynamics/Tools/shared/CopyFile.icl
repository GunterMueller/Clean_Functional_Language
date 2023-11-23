implementation module CopyFile

import StdEnv, Directory


LineListWriteS :: String [String] *World -> *World
LineListWriteS filename lines world
	# ( ok, file, world ) = fopen filename FWriteText world
	| not ok = abort ("could not open file "+++filename+++"\n")
	# file = foldr fwrites file lines
	# ( ok, world ) = fclose file world
	| not ok = abort "could not close file\n" 
	| otherwise = world

LineListReadS :: String *World -> ([String],*World)
LineListReadS fnev world
	# ( ok, file, world ) = fopen fnev FReadText world
	| not ok = abort ( "cannot open file"+++fnev )
	# ( lines, file ) = LineListReadF file
	# ( ok, world ) = fclose file world
	| not ok = abort ( "cannot close file"+++fnev )
	| otherwise = ( lines, world )
//= (LineListReadF inputfile,closedfilesys)
where
	LineListReadF :: *File -> ([String], *File)
	LineListReadF f	
		# (isend, f) = fend f
		| isend	= ([], f)
		# (line,f)= freadline f
		# (lines,f)=  LineListReadF f
		| otherwise	= ( [(%) line (0,size(line)-2): lines], f )
/*
	(readok,inputfile,touchedfilesys)= sfopen fnev FReadText world
*/


CopyFile :: String String *env -> *env | FileSystem env
CopyFile inputfname outputfname filesys 
	| False // <<- ("CopyFile",inputfname,outputfname)
		= undef
	
	# ( readok, inputfile, touchedfilesys ) = fopen inputfname FReadData filesys
	| not readok  = abort( "cannot open input file: '"+++inputfname+++"'")
	# ( writeok, outputfile, nwfilesys) 	  = fopen outputfname FWriteData touchedfilesys
	| not writeok = abort( "cannot open output file: '"+++outputfname+++"'")

	# ( cnt, inputfile, copiedfile ) = CharFileCopy 0 inputfile outputfile 
	
	| False // <<- ("count", cnt)
		= undef; 

	# (closeok, almostfinalfilesystem) 				 = fclose inputfile nwfilesys
	| not closeok = abort( "cannot close input file: '"+++inputfname+++"'")
	# (closeok2, finalfilesystem) 				 = fclose copiedfile almostfinalfilesystem
	| not closeok2 = abort( "cannot close output file: '"+++outputfname+++"'")
	| readok && writeok && closeok && closeok2 = finalfilesystem

CharListWrite :: [Char] *File -> *File
// writes a list of chars onto a file
CharListWrite [] f = f
CharListWrite [c:cs] f = CharListWrite cs ( fwritec c f )

CharFileCopy :: !Int !*File !*File -> ( !Int,!*File, !*File )  
// copies the chars of an opened file to another one
CharFileCopy count infile outfile 
/*	# (isend, infile) = fend infile
	| isend = ( infile, outfile ) 
*/	# ( ok, char, infile ) = freadc infile
	| not ok
		= (count,infile,outfile)
//	| not ok = ( infile, outfile )
	# oufile = fwritec char outfile   
	
	# ( error, outfile) = ferror outfile
	| error 
		= abort "CharFileCopy: error"
	
	= CharFileCopy (inc count) infile outfile 
	
createNestedDirectories :: Path *World -> (DirError, *World)
// creates nested directories ( from the current directory, goes through the
// path and creates all the directories mentioned
createNestedDirectories path world 
	= createNestedDirectoriesLevel path 1 world

CanRecoverFrom NoDirError = True
CanRecoverFrom AlreadyExists = True
CanRecoverFrom _ = False

createNestedDirectoriesLevel :: Path Int *World -> (DirError, *World)
createNestedDirectoriesLevel (RelativePath dirnames) i world  
		| i > length( dirnames ) 
			= ( NoDirError, world )
//		| i <= length( dirnames ) 
		# ( error, world ) = createDirectory (RelativePath (take i dirnames)) world
		| not( CanRecoverFrom error ) 
			= ( error, world )
		| otherwise 
			= createNestedDirectoriesLevel (RelativePath dirnames) (i+1) world
 

createNestedDirectoriesLevel (AbsolutePath drivename dirnames) i world  
		| i > length( dirnames ) 
			= ( NoDirError, world )
//		| i <= length( dirnames ) 
		# ( error, world ) = createDirectory (AbsolutePath drivename (take i dirnames)) world
		| not( CanRecoverFrom error ) 
			= ( error, world )
		| otherwise 
			= createNestedDirectoriesLevel (AbsolutePath drivename dirnames) (i+1) world


(\+\) infixl 6 :: Path Path -> Path
// concatenates the two paths
(\+\) (AbsolutePath drivename steps) path
	= AbsolutePath drivename (steps ++ PathSteps path)
(\+\) (RelativePath steps) path
	= RelativePath (steps ++ PathSteps path)
	

PathSteps :: Path -> [PathStep]
PathSteps (RelativePath dirnames) = dirnames
PathSteps (AbsolutePath drivename dirnames) = [ PathDown drivename : dirnames ]

CutLast :: Path -> (Path, Path)
CutLast path
	= ( ButLast path, RelativePath [last (PathSteps path)] )

		 
IsDirError :: DirError -> Bool
IsDirError NoDirError = False
IsDirError _ = True 


ErrorType :: DirError -> String
ErrorType NoDirError = " no dir error"
ErrorType DoesntExist = " doesnt exist"
ErrorType BadName = " bad name"
ErrorType NotEnoughSpace = " not enough space"
ErrorType AlreadyExists = " already exists"
ErrorType NoPermission = " no permission"
ErrorType MoveIntoOffspring = " move into offspring"
ErrorType MoveAcrossDisks = " move across disks"
ErrorType NotYetRemovable = " not yet removable"
ErrorType OtherDirError = " other dir error"

ButLast :: Path -> Path
ButLast (RelativePath steps) = RelativePath ( init steps )
ButLast (AbsolutePath drivename steps) = AbsolutePath drivename (init steps )

FileNameOf :: Path -> String
FileNameOf path =
	case (last (PathSteps path)) of
		 PathDown name -> name
		 PathUp -> ".."

WithoutExtension :: String -> String
WithoutExtension st 
	= st % (0, (DotIndex st)-1)

DotIndex st = DotIndexFrom ((size st)-1) st
DotIndexFrom i st 
	| i < 0 = size st 
	| st.[i] == '.' = i
	| st.[i] == '/' || st.[i] == '\\' = size st
	| otherwise = DotIndexFrom (i-1) st

HasExtension :: String -> Bool
HasExtension st = not ( (DotIndex st) == (size st) )

FileSize :: String *World -> (Int, *World) 
FileSize filename world 
	# ( ok, file, world ) = fopen filename FReadData world
	| not ok = abort ("cannot open file "+++filename+++"\n")
	# ( ok, file ) = fseek file 0 FSeekEnd
	| not ok = abort ("cannot seek in file "+++filename+++"\n")
	# ( filesize, file ) = fposition file
	# ( ok, world ) = fclose file world
	| not ok = abort ("cannot close file "+++filename+++"\n")
	= ( filesize, world )
	

FindLast :: Char String -> Int
// returns the index of the last occurence of c in st 
FindLast c st 
| occurences == [] = -1
| otherwise = last occurences
where
	occurences :: [Int]
	occurences = [ i \\ i <- (filter isC [0..(size st)-1]) ]
	isC i = (st.[i] == c) 


FileNameFrom :: String -> String
FileNameFrom fullname
	= fullname % (bslashindex+1, size fullname)
	where
		bslashindex = FindLast '\\' fullname
	
PathFrom :: String -> String
PathFrom fullname
	= fullname % (0, bslashindex)
	where
		bslashindex = FindLast '\\' fullname
	

ClearDirectoryContents :: String *World -> *World
ClearDirectoryContents dirname world
	# ( (ok, path), world ) = pd_StringToPath dirname world
	| not ok = abort ("bad directory: "+++dirname)
	# ( (error, entries), world ) = getDirectoryContents path world
	| IsDirError error = abort ("bad directory: "+++dirname)
	# filenames = map (fileName) entries
	= foldr RemoveFile world filenames
	where
		RemoveFile :: String *World -> *World
		RemoveFile name world
			| ".." == name = world
			| "." == name = world
			# ( (ok, path), world ) = pd_StringToPath (dirname+++"\\"+++name) world
			| not ok = abort ("bad dir "+++dirname+++"\\"+++name)
			# ( error, world ) = fremove path world
			| IsDirError error
				= abort ("couldnt delete "+++name)
			| otherwise 
				= world		
				
		fileName {fileName} = fileName


Extension :: String -> String
Extension s = s % (dotindex+1, size s ) where
	dotindex = FindLast '.' s 