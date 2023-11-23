implementation module SendDynamic

import DynamicRefTools, CopyFile, StdString, Directory, StdEnv, 
		DynID, TCPChannel, DynamicLinkerInterface
		
from StdSystem import ticksPerSecond
from CallProc import CallProcess 

import RWSDebug

//GetDynamicLinkerPath = "C:\\Program Files\\Matyas and Zoltan's Clean 4\\Dynamics"

dynamicPort = 11702
// dynamicdir = "C:\\Doi\\Program Files\\CleanAll200\\Clean 2.0\\Tools\\Dynamics 0.0\\lazy dynamics"
// librarydir = "C:\\Doi\\Program Files\\CleanAll200\\Clean 2.0\\Tools\\Dynamics 0.0\\test libs"
// idtablename = "C:\\DynamicID1.table"
// pscp = "\"C:\\Program files\\putty\\pscp.exe\""
// username = "dynamics"
arrivedir = GetDynamicLinkerPath+++"\\arrive\\"
// the directory where the files arrive
// it is deleted before every transfer

IsLogError []  = False
IsLogError _ = True 

Log :: String *f -> *f
Log st world 
	| False <<- ("Log", st)
		= undef
//	# ( console, world ) = stdio world
//	#  console = fwrites st console
//	# ( ok, world ) = fclose console world 
	= world

List_ :: (a b -> c) [a] [b] -> [c]
List_ f [] [] = []
List_ f [x:xs] [y:ys] = [ (f x y) : List_ f xs ys ]
		

FindLast :: Char String -> Int
// returns the index of the last occurence of c in st 
FindLast c st 
| occurences == [] = size st
| otherwise = last occurences
where
	occurences :: [Int]
	occurences = [ i \\ i <- (filter isC [0..(size st)-1]) ]
	isC i = (st.[i] == c) 

Find :: Char String -> Int
// returns the index of the first occurence of c in st 
Find c st 
| occurences == [] = size st
| otherwise = hd occurences
where
	occurences :: [Int]
	occurences = [ i \\ i <- (filter isC [0..(size st)-1]) ]
	isC i = (st.[i] == c) 


CreateLocalFileName :: String -> String
CreateLocalFileName oldfilename
	| isDynamic oldfilename 
		= CONVERTED_ENCODED_DYNAMIC_FILE_NAME_INTO_PATH GetDynamicLinkerPath (WithoutExtension (FileNameFrom oldfilename))
	| otherwise
		= CONVERT_ENCODED_LIBRARY_IDENTIFICATION_INTO_RUN_TIME_LIBRARY_IDENTIFICATION GetDynamicLinkerPath (FileNameFrom oldfilename)


isDynamic :: String -> Bool
isDynamic s = (EXTENSION_SYSTEM_DYNAMIC == Extension s)

isUserDynamic :: String -> Bool
isUserDynamic s = (EXTENSION_USER_DYNAMIC == Extension s)

/*
isID :: String -> Bool
isID s = (s == WithoutExtension (FileNameFrom s) ) 
*/

instance == DynamicID1 where
	(==) id1 id2 = (toString id1) == (toString id2)


instance - [a] | Eq a 
where
	(-) infixl 6 :: [a] [a] -> [a] | Eq a
	(-) [] b = []
	(-) [hd:tl] b 
	| isMember hd b = ( tl - b )
	| otherwise = [hd: (tl-b) ] 

/*
GetIDFromDynFileName :: String -> DynamicID1
GetIDFromDynFileName name
	= fromString ( WithoutExtension ( name % ( lineindex+1 , size name ) ))
	where
		lineindex = Find '_' name
*/

GetIDFromDynFileName :: String -> DynamicID1
GetIDFromDynFileName name
	= fromString( WithoutExtension name ) 


GetIDsFromLibFileName :: String -> ( DynamicID1, DynamicID1 ) 
GetIDsFromLibFileName name
	= (id1, id2) 
	where
		id1 = fromString ( name % ( 0, lineindex ))
		id2 = fromString ( WithoutExtension ( name % (lineindex, size name )))
		
		lineindex = Find '_' name

GetIDFromUserDynamicFileName :: String *World -> (String, *World)
GetIDFromUserDynamicFileName filename world
	# ( lines, world ) = LineListReadS filename world
	= ( hd lines, world )

concat :: ([a], [a]) -> [a]
concat (x, y) = x ++ y


CollectLibraryFileNames :: *World -> ([String], *World) 
// collects the .lib and .typ filenames
CollectLibraryFileNames world
	# librarypath = GetDynamicLinkerPath +++ "\\" +++ DS_LIBRARIES_DIR
	# ( (ok, plibrarypath), world ) = pd_StringToPath librarypath world
	| not ok = abort("bad path: "+++librarypath)
	# ( ( error, libentries ) , world ) = getDirectoryContents plibrarypath world
	| IsDirError error = abort ("bad library directory: "+++librarypath)
	= ( map fileName libentries, world ) 
	where
		fileName {fileName} = fileName

CollectDynamicFileNames :: *World -> ([String], *World) 
// collects the dynamic filenames
CollectDynamicFileNames world
	# dynamicpath = GetDynamicLinkerPath +++ "\\" +++ DS_SYSTEM_DYNAMICS_DIR
	# ( (ok, pdynamicpath), world ) = pd_StringToPath dynamicpath world
	| not ok = abort("bad path: "+++dynamicpath)
	# ( ( error, dynentries ) , world ) = getDirectoryContents pdynamicpath world
	| IsDirError error = abort ("bad dynamic directory: "+++dynamicpath)
	= ( map fileName dynentries, world ) 
	where
		fileName {fileName} = fileName


CollectPresentDynamics :: *World -> ([String], *World)
// collects the dynamics present on this computer
CollectPresentDynamics world
	# ( libfilenames, world ) = CollectLibraryFileNames world
	# ( dynamicfilenames, world ) = CollectDynamicFileNames world
	= ( libfilenames ++ dynamicfilenames, world ) 
/*	# dynamics = map GetIDFromDynFileName dynamicfilenames
	# libraries = (concat o unzip) (map GetIDsFromLibFileName libfilenames)
	= ( dynamics ++ libraries, world )
*/

/*
GetIDFromDynamicFile :: String *World -> ( String, *World )
GetIDFromDynamicFile filename world
	| isDynamic filename = ( toString( GetIDFromDynFileName filename ) , world )
	| isUserDynamic filename = GetIDFromUserDynamicFileName filename world
	| otherwise = ( filename, world ) 	
*/

RequestDynamic :: String String *World -> *World
RequestDynamic name hostname world
	# world = Log ("Sending request for " +++name+++ "\n") world
	# ( channel, world ) = clientConnect hostname dynamicPort world
	# ( channel, world ) = Send name channel world 
	# world = Log "Waiting for dependant names\n" world
	# ( names, channel, world ) = Receive channel world
	# world = Log "Determining the names of the needed files\n" world
	# world = AssertStringList names world
	# ( presentnames, world ) = CollectPresentDynamics world
	# needednames = names - presentnames
	# world = Log "Sending the names of the needed files\n" world
	# ( channel, world )  = SendAcked needednames channel world
	# world = Log "Clearing arrive driectory\n" world
	# world = ClearDirectoryContents arrivedir world
	# world = Log "Sending the arrive directory name\n" world
	# ( channel, world )  = Send arrivedir channel world
	# world = Log "Waiting for the dynamics to arrive\n" world
	# ( filenames, channel, world ) = ReceiveAcked channel world 
	# world = Log "Loading new dynamic files\n" world
	# world = AssertChannelFileList filenames world
	# world = LoadDynamic arrivedir world 
	| isUserDynamic name 
	# world = Log "Waiting for the user dynamic link file\n" world
	# ( link, channel, world ) = Receive channel world
	# world = AssertChannelFile link world
	# world = closeChannels channel world
	= world 
	| otherwise
	# world = closeChannels channel world
	= world
	where
		AssertChannelFileList :: [ChannelFile] *World -> *World
		AssertChannelFileList list world = world
		
		AssertStringList :: [String] *World -> *World
		AssertStringList list w = w 
		
		AssertChannelFile :: ChannelFile *World -> *World
		AssertChannelFile channelfile world = world
		

AnswerDynamicRequest :: *World -> ( Bool, *World )
AnswerDynamicRequest world 
	# world = Log "Waiting for dynamic request...\n" world
	# ( channel, _, world ) = serverConnect dynamicPort world
	# ( name, channel, world ) = Receive channel world
	# world = Log "Determining dependencies\n" world
	# ( ok, fullname, world ) = GetFullName name world 
	| not ok 
		= ( False, (Log (name+++" is not present\n") world) )
	# ( tree, _, logs, world ) = refTreeBuilder [fullname] world
	| IsLogError logs 
		= ( False, foldr Log world logs )
	# depnames = map FileNameFrom (collectReferenced tree)
	# world = Log "Sending the names of dependencies\n" world
	# ( channel, world ) = Send depnames channel world
	# world = Log "Waiting for the names of the needed files\n" world
	# (names, channel, world) = ReceiveAcked channel world
	# world = Log "Receiving the directory names where the files should arrive\n" world
	# ( arrivedir, channel, world) = Receive channel world
	# world = Log "Sending the dynamic files\n" world
	# channelfiles = List_ ChannelFile_ (map CreateLocalFileName names) (map (((+++)arrivedir) o FileNameFrom) names)
	# ( channel, world ) = SendAcked channelfiles channel world
	# world = Log "Sending the link file\n" world
	# ( ok, fullname, world ) = GetFullName name world
	| not ok 
		= ( False, (Log (name+++" is not present\n") world) )
	| isUserDynamic name
	# ( channel, world ) = Send (ChannelFile_ name (arrivedir+++(FileNameFrom name))) channel world
	# world = closeChannels channel world
	= ( True, world )
	| otherwise
	# world = closeChannels channel world
	= ( True, world ) 	
	where
		GetFullName :: String *World -> ( Bool, String, *World )
		GetFullName name world
			| isUserDynamic name = get_system_dynamic_identification name world 
			| isDynamic name = ( True, CONVERTED_ENCODED_DYNAMIC_FILE_NAME_INTO_PATH GetDynamicLinkerPath (WithoutExtension name), world ) 
			| otherwise = ( False, "trash", world ) 

/*	where 
		IDsFrom :: [String] -> [DynamicID1]
		IDsFrom [] = []
		IDsFrom [name: names]
			| isDynamic name = [ (fromString name) : IDsFrom names]
			# ( id1, id2 ) = GetIDsFromLibFileName name
			| otherwise = [ id1: [id2: IDsFrom names] ] 
*/

/*
		FindDynamicNameOf :: DynamicID1 *World -> ( Bool, String, *World )
		FindDynamicNameOf id world
			# ( libfilenames, world ) = CollectLibraryFileNames world
			# ( dynfilenames, world ) = CollectDynamicFileNames world
			# dynmatches = filter (((==) id) o GetIDFromDynFileName) dynfilenames
			| length dynmatches > 0 
				= ( True, hd dynmatches, world )
			# libmatches = filter (((==) id) o fst o GetIDsFromLibFileName) libfilenames
			| length libmatches > 0 
				= ( True, hd libmatches, world )
			# typmatches = filter (((==) id) o snd o GetIDsFromLibFileName) libfilenames
			| length typmatches > 0 
				= ( True, hd typmatches, world )
			| otherwise
				= ( False, "", world )
*/				
				
 
// copies only the dynamic and its dependencies to a user specified folder
StoreDynamic :: String [String] String *f -> *f | FileSystem f 
StoreDynamic filename excludelist path world
	// creates directory
	# ((ok,p),world)
		= pd_StringToPath path world
	# (dir_error,world)
		= createDirectory p world
	| not ok || IsDirError dir_error
		= abort "StoreDynamic: error creating destination directory"

	// collect the used filenames
	# ( tree, _, logs, world ) = refTreeBuilder [CreateLocalFileName filename] world
	| IsLogError logs 
		= foldr Log world logs
	# depnames = collectReferenced tree
	# names = depnames - excludelist
	// copy the included files
	= foldl CopyAFile world names  
 	where
		CopyAFile :: *f String -> *f | FileSystem f
		CopyAFile world fname 
			# world = Log (fname+++"\n") world
			= CopyFile fname (path+++(FileNameFrom fname)) world
		

LoadDynamic :: String *f -> *f | FileSystem f
LoadDynamic pathname world
	// collect the dynamics in the list
	# ( (ok, path), world ) = pd_StringToPath pathname world
	| not ok = abort ("bad directory: "+++pathname)
	# ( (error, entries), world ) = getDirectoryContents path world
	| IsDirError error = abort ("bad directory: "+++pathname)
	# names = map (fileName) entries
	// copy the files in the list
	# world = foldl CopyAFile world names  
	= world
 	where
		CopyAFile :: *f String -> *f | FileSystem f
		CopyAFile world fname
			| "." == fname = world
			| ".." == fname = world
			= CopyFile (pathname+++fname) (CreateLocalFileName fname) world

		fileName {fileName} = fileName

 	
/*
StoreDynamic :: DynamicID1 String *World -> *World
StoreDynamic id pathname world
	// collect the used filenames
	# ( idtable, world ) = LoadIDTable idtablename world
	# ( tree, _, logs, world ) = refTreeBuilder [fromJust (idtable |->| id)] world
	| IsLogError logs 
		= foldr Log world logs
	# depnames = collectReferenced tree
	// copy them to the destination directory
	# world = foldl CopyAFile world depnames
	// create a new id table and write it to the directory
	# ids = map ( fromJust o ((|<-|) idtable) ) depnames
	# newnames = map FileNameFrom depnames
	# entries = zip2 ids newnames
	# newtable = foldl AddEntry EmptyIDTable entries
	# world = SaveIDTable newtable (pathname+++"DynamicID1.table") world
	// change the references in them
	# pairs = zip2 depnames newnames
	# mapping = CreateMapping pairs
	# ( ok, world ) = ChangeReferences (map ((+++) pathname) newnames) mapping world
	| not ok = abort ("couldn't change the references\n") 
	= world
	where
		CopyAFile :: *World String -> *World
		CopyAFile world filename 
			= CopyFile filename (pathname+++(FileNameFrom filename)) world
			
		ChangeRefs :: ((String -> String), *World) String -> ((String->String), *World)
		ChangeRefs (mapping, world) filename 
			# ( ok, world ) = ChangeDynamicReferences filename mapping world  
			| not ok = abort ("couldnt change references in "+++filename+++"\n")
			= (mapping, world)
*/			
mapworld :: ( a *b -> (c,*b)) ([a],*b) -> ([c],*b)
mapworld f ([], w) = ([],w)
mapworld f ([a:as], w) 
	# ( c, w ) = f a w
	# ( cs, w ) = mapworld f (as, w)
	= ( [c:cs], w )

/*
LoadDynamic :: String *World -> *World
LoadDynamic pathname world
	// find out which ids are new
	# ( storedidtable, world ) = LoadIDTable (pathname+++"DynamicID1.table") world
	# oldids = IDsFrom storedidtable
	# ( idtable, world ) = LoadIDTable idtablename world
	# ids = oldids - (IDsFrom idtable)
	// copy the needed files 
	# names = map (fromJust o ((|->|) storedidtable)) ids
	# (newnames, world) = mapworld CreateLocalFileName (names, world)
	# world = foldl CopyAFile world (zip2 names newnames)
	// modify and save the id table
	# idtable = foldl AddEntry idtable (zip2 ids newnames)
	# world = SaveIDTable idtable idtablename world
	// change the references in the new files 
	# storednames = map (fromJust o ((|->|) storedidtable)) oldids
	# localnames = map (fromJust o ((|->|) idtable)) oldids 
	# mapping = CreateMapping (zip2 storednames localnames)
	# ( ok, world ) = ChangeReferences newnames mapping world
	| not ok = abort "couldnt change references"
	= world 
	where
		CopyAFile :: *World (String,String) -> *World
		CopyAFile world (old, new) 
			= CopyFile (pathname+++old) new world
*/
/*
SendDynamicRequest :: DynamicID1 String *World -> *World
SendDynamicRequest id hostname world
	# ( {rChannel, sChannel}, world) = clientConnect hostname world
//	# ( sChannel, world ) = send (toByteSeq "dynamic") sChannel world
//	# world = Log "dynamic word sent\n" world 
	# ( sChannel, world ) = send (toByteSeq (toString id)) sChannel world
	# world = closeChannels sChannel rChannel world
	= world
 

ReceiveDynamicRequest :: *World -> ( Bool, DynamicID1, IPAddress, *World )
ReceiveDynamicRequest world
	// wait for connection 
	# ({ sChannel, rChannel }, ip, world ) = serverConnect world
	# world = Log "connection established\n" world 
	# (localaddress, world ) = lookupIPAddress "localhost" world
	// wait for id to arrive
	# ( idstring, rChannel, world ) = stringReceive rChannel world
	# world = closeChannels sChannel rChannel world
	= ( True, (fromString idstring), ip, world )
*/ 
/*
SendStringList :: [String] String *World -> *World
SendStringList strings hostname world
	# ({ sChannel, rChannel}, world) = clientConnect hostname world
	# ( sChannel, world ) = send (toByteSeq( toString (length strings))) sChannel world
//	# world = Log ("sent number of strings = "+++(toString (length strings))+++"\n") world
	# ( sChannel, rChannel, world ) = foldl SendAString (sChannel, rChannel, world) strings
	= closeChannels sChannel rChannel world
	where 
		SendAString :: (*TCP_SChannel, *TCP_RChannel, *World) String -> ( *TCP_SChannel, *TCP_RChannel, *World )
		SendAString (sc, rc, world) string
//			# world = Log (string+++" ") world
			# (sc, world) = send (toByteSeq string) sc world
			# (ack, rc, world ) = receive rc world
			= ( sc, rc, world )

ReceiveStringList :: *World -> ([String], *World)
ReceiveStringList world
	# ({ sChannel, rChannel}, _, world) = serverConnect world
	# ( nstring, rChannel, world ) = stringReceive rChannel world
//	# world = Log ("received number of files = "+++nstring+++"\n") world
	# n = toInt nstring
	# ( ids, sChannel, rChannel, world ) = ReceiveNString n sChannel rChannel world
	# world = closeChannels sChannel rChannel world
	= ( ids, world ) 
	where 
		ReceiveNString :: Int *TCP_SChannel *TCP_RChannel *World -> ( [String], *TCP_SChannel, *TCP_RChannel, *World )
		ReceiveNString 0 sChannel rChannel world = ( [], sChannel, rChannel, world )
		ReceiveNString i sChannel rChannel world 
			# ( string, rChannel, world ) = stringReceive rChannel world
			# ( sChannel, world ) = send (toByteSeq "ack") sChannel world
//			# world = Log (string+++" ") world
			# ( strings, sChannel, rChannel, world ) = ReceiveNString (i-1) sChannel rChannel world
			= ( [string: strings], sChannel, rChannel, world )

SendDynamicID1List :: [DynamicID1] String *World -> *World
SendDynamicID1List ids hostname world
	= SendStringList (map toString ids) hostname world
			 
			 
ReceiveDynamicID1List :: *World -> ([DynamicID1], *World)
ReceiveDynamicID1List world
	= (ids, newworld)
	where
		( strings, newworld ) = ReceiveStringList world
		ids = map fromString strings
*/		
/*
// receives a dynamic id list
ReceiveDynamicID1List :: *World -> ([DynamicID1], *World)
ReceiveDynamicID1List world
	# ({ sChannel, rChannel}, _, world) = serverConnect world
	# ( nstring, rChannel, world ) = stringReceive rChannel world
	# world = Log ("received number of files = "+++nstring+++"\n") world
	# n = toInt nstring
	# ( ids, sChannel, rChannel, world ) = ReceiveNDynamicID1 n sChannel rChannel world
	# world = closeChannels sChannel rChannel world
	= ( ids, world ) 
	where 
		ReceiveNDynamicID1 0 sChannel rChannel world = ( [], sChannel, rChannel, world )
		ReceiveNDynamicID1 i sChannel rChannel world 
			# ( idstring, rChannel, world ) = stringReceive rChannel world
			# ( sChannel, world ) = send (toByteSeq "ack") sChannel world
			# world = Log ((idstring)+++" ") world
			# ( ids, sChannel, rChannel, world ) = ReceiveNDynamicID1 (i-1) sChannel rChannel world
			= ( [(fromString idstring): ids], sChannel, rChannel, world )
*/
/*	
SendDynamicsToHost :: [DynamicID1] String *World -> (Bool, *World)
SendDynamicsToHost ids hostname world 
	// establish a connection and send the number of files
	# ({ sChannel=sc, rChannel=rc }, world) = clientConnect hostname world
	# (sc, world)					= send (toByteSeq (length ids)) sc world
	# world						= closeRChannel rc world
	# world						= closeChannel sc world
	// send the files
	# ( toFileName, _, world) = LoadIDTable idtablename world
	# (ok, world) = SendFilesToHost (map toFileName ids) hostname world
	| not ok = (False, world)
	// send that transfer is over 
	# ({ sChannel=sc, rChannel=rc }, world) = clientConnect hostname world
	# world = Log ("sending transfer end\n") world
	# (sc, world)					= send (toByteSeq "transfer end") sc world
	# world						= closeRChannel rc world
	# world						= closeChannel sc world
	= (True, world)
*/
/*	
ReceiveDynamics :: *World -> (Bool, [DynamicID1], *World)
ReceiveDynamics world
	// receiving the number of files
	# ({ sChannel=sc, rChannel=rc }, world) = serverConnect world
	# ( snumfiles, rChannel, world ) = stringReceive rChannel world
	# ( numfiles ) = toInt snumfiles
	# world = closeRChannel rChannel world
	# world = closeChannel sChannel world
	// receiving the files
	# ( ok, dynnames, _, world ) = ReceiveNFiles numfiles world
	| not ok = (False, [], world )
	// wait for handshake
	# world = Log "Waiting for end transfer signal..." world
	# ({ sChannel, rChannel }, world)  = serverConnect world
	# ( snumfiles, rChannel, world ) = stringReceive rChannel world
	# world = Log "OK!\n" world
	# world = closeRChannel rChannel world
	# world = closeChannel sChannel world
*/ 	
	
/*
	# commandline = pscp+++" -pw "+++username+++" \""+++filename+++"\" \""+++
						username+++"@"+++hostname+++":"+++newfilename+++"\""					
*/
	
/*
ReceiveNFiles :: Int *World -> ( Bool, [DynamicID1], [(DynamicID1, DynamicID1)], *World )
// like ReceiveFile, difference is this receives n files instead of one
// result is ( success, [dynamicfilenames], [(remote ids, local ids)], world )
ReceiveNFiles 0 world 
	= ( True, [], [], world )
ReceiveNFiles i world 
	# ( ok, oldfilename, newfilename, world ) = ReceiveFile world
	| not ok = ( False, [], [], world )
	# ( ok, dyns, pairs, world ) = ReceiveNFiles (i-1) world
	| not ok = ( False, [], [], world )
	# newpairs = [(fromString (WithoutExtension oldfilename), fromString (WithoutExtension newfilename)) : pairs ] 
	| isDynamic oldfilename
	= ( True, [(fromString newfilename): dyns], newpairs, world )
	| otherwise
	= ( True, dyns, newpairs, world )
*/	
/*
SendDynamicID1List :: [DynamicID1] String *World -> *World
SendDynamicID1List ids hostname world
	# ({ sChannel, rChannel}, world) = clientConnect hostname world
	# ( sChannel, world ) = send (toByteSeq( toString (length ids))) sChannel world
	# world = Log ("sent number of files = "+++(toString (length ids))+++"\n") world
	# ( sChannel, rChannel, world ) = foldl SendAnID (sChannel, rChannel, world) ids
	= closeChannels sChannel rChannel world
	where 
		SendAnID :: (*TCP_SChannel, *TCP_RChannel, *World) DynamicID1 -> ( *TCP_SChannel, *TCP_RChannel, *World )
		SendAnID (sc, rc, world) id
			# world = Log ((toString id)+++" ") world
			# (sc, world) = send (toByteSeq (toString id)) sc world
			# (ack, rc, world ) = receive rc world
			= ( sc, rc, world )
*/
/*
	// wait for a connection
	# world = Log "Waiting for a dynamic to come...\n" world
	# ({ sChannel, rChannel }, world)  = serverConnect world
	# ( snumfiles, rChannel, world ) = stringReceive rChannel world
	# ( numfiles ) = toInt snumfiles
	# world = closeRChannel rChannel world
	# world = closeChannel sChannel world
	// receive the files
	# ( ok, dynnames, ids, world ) = ReceiveNFiles numfiles world
	| not ok = (False, fst (hd ids), world )
	// wait for handshake
	# world = Log "Waiting for end transfer signal..." world
	# ({ sChannel, rChannel }, world)  = serverConnect world
	# ( snumfiles, rChannel, world ) = stringReceive rChannel world
	# world = Log "OK!\n" world
	# world = closeRChannel rChannel world
	# world = closeChannel sChannel world
	// change the references in dynamics
	# world = Log "changing the references in files\n" world 
	# (ok, world) = ChangeReferences dynnames ids world
	# world = Log "\n\n" world
	= ( ok, fst (hd ids), world )
*/	
/*
SendDynamicToHost :: String String *World -> (Bool, *World)
// send a dynamic with its dependencies through network to a host
// result is trueif the operation succeeds (filename, hostname, w ) -> ( succeed, w )
SendDynamicToHost filename hostname world 
	// build a tree from the referenced files
	#( tree, _, _, world ) = refTreeBuilder [filename] world
	# list = collectReferenced tree
	// establish a connection and send the number of files
	# (mbIPAddr, world)	= lookupIPAddress hostname world
	|	isNothing mbIPAddr	 
		= abort ( hostname +++" not found\n")
	# (tReport, mbDuplexChan, world) = connectTCP_MT (Just (5*ticksPerSecond)) (fromJust mbIPAddr, dynamicPort) world
	|	tReport <> TR_Success
		= abort (   hostname+++" does not respond on port "   +++toString dynamicPort+++"\n")
	# { sChannel=sc, rChannel=rc }= fromJust mbDuplexChan
	# world = Log ("connected to "+++hostname+++"\n") world
	# world = Log ("sending the number of files="+++(toString(length list))+++"\n") world
	# (sc, world)					= send (toByteSeq (length list)) sc world
	# world						= closeRChannel rc world
	# world						= closeChannel sc world
	// send the files
	# (ok, world) = SendFilesToHost list hostname world
	| not ok = (False, world)
	// send that transfer is over 
	# (mbIPAddr, world)	= lookupIPAddress hostname world
	|	isNothing mbIPAddr	 
		= abort ( hostname +++" not found\n")
	# (tReport, mbDuplexChan, world) = connectTCP_MT (Just (5*ticksPerSecond)) (fromJust mbIPAddr, dynamicPort) world
	|	tReport <> TR_Success
		= abort (   hostname+++" does not respond on port "   +++toString dynamicPort+++"\n")
	# { sChannel=sc, rChannel=rc }= fromJust mbDuplexChan
	# world = Log ("connected to "+++hostname+++"\n") world
	# world = Log ("sending transfer end\n") world
	# (sc, world)					= send (toByteSeq "transfer end") sc world
	# world						= closeRChannel rc world
	# world						= closeChannel sc world
	= (True, world)
*/
/*
IsDynError :: Bool -> Bool
IsDynError NoDynError = False
IsDynError _ = True
*/
/*
hasExtension :: String -> Bool
hasExtension ""= False
hasExtension x= x.[0]=='.' || hasExtension ((%) x (1,(size x)-1))
*/
/*	where
		WriteLine :: (String, String) *World -> *World
		WriteLine (a,b) world
			= Log ("("+++a+++", "+++b+++")\n") world
*/
/*
ReceiveDynamic :: *World -> (Bool, DynamicID1, *World)
ReceiveDynamic world 
	# world = Log "Waiting for a dynamic to come...\n" world
	# ({ sChannel, rChannel }, _, world)  = serverConnect world
	# ( idstring, rChannel, world ) = stringReceive rChannel world
	# id = fromString idstring
	# world = closeChannels sChannel rChannel world
	# world = Log ("id "+++idstring+++" arrived, waiting for the file\n") world
	# (ok, _, filename, world) = ReceiveFile world
	| not ok = ( False, id, world )
	= ( True, id, world )
*/	
/*
SendDynamicToHost :: DynamicID1 IDTable String *World -> (Bool, *World)
SendDynamicToHost id idtable hostname world
	# ({ sChannel, rChannel }, world)  = clientConnect hostname world
	# (sChannel, world)  = send (toByteSeq (toString id)) sChannel world
	# world = closeChannels sChannel rChannel world
	| isNothing (idtable |->| id) = ( False, world )
	| otherwise = SendFileToHost (fromJust (idtable |->| id)) hostname world
*/		
