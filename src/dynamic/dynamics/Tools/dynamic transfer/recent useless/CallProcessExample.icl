module CallProcessExample

import StdEnv, CallProc

pscp = "\"C:\\Program files\\putty\\pscp.exe\""
dynamicdir = "E:\\Dynamics"
username = "dynamics" 
filename = "e:\\serialXp.txt"
newfilename = "e:\\test libs\\serialXp2.txt"
hostname = "localhost"


Log :: String *World -> *World
Log st world 
	# ( console, world ) = stdio world
	#  console = fwrites st console
	# ( ok, world ) = fclose console world 
	= world



FindLast :: Char String -> Int
// returns the index of the first occurence of c in st 
FindLast c st 
| occurences == [] = size st
| otherwise = last occurences
where
	occurences :: [Int]
	occurences = [ i \\ i <- (filter isC [0..(size st)-1]) ]
	isC i = (st.[i] == c) 

CreateCommandLine :: String String String -> String
// CreateCommandLine oldfilename newfilename hostname -> commandline
// creates a command line that copies the oldfile from the local machine
// to a newfile at the hostname machine
CreateCommandLine oldfilename newfilename hostname
	= ("cmd /c copy /Y \""+++oldfilename+++"\" \"\\\\"+++hostname+++"\\Dynamics\\"+++(ChopButLast2 newfilename)+++"\"")
	where 
		ChopButLast2 :: String -> String
		ChopButLast2 newfilename =
			newfilename % ( bsindex+1, (size newfilename))
		bsindex = FindLast '\\' ( newfilename % (0, (FindLast '\\' newfilename)-1 ) )
		

Start :: *World -> *World
Start world  
	# commandline = CreateCommandLine filename newfilename hostname
	# world = Log commandline world
	# ( ok, exitcode, os, world ) = CallProcess commandline [] "" "" "" "" 99 world
//	| not ok = abort ( "commandline error\n" )
	|otherwise = world
	