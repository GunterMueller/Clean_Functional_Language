module Example

import CopyFile, StdEnv

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
	= ("copy /Y \""+++oldfilename+++"\" \""+++hostname+++"\\\\Dynamic\\"+++(ChopButLast2 newfilename)+++"\"")
	where
		ChopButLast2 :: String -> String
		ChopButLast2 newfilename =
			newfilename % ( bsindex+1, (size newfilename))
		bsindex = FindLast '\\' ( newfilename % (0, (FindLast '\\' newfilename)-1 ) )


//Start = CreateCommandLine "a" "C:\\WINDOWS\\DESKTOP\\distribution\\Examples\\Dynamic 0.0\\WriteDynamic\\test" "c"
Start world = FileNameFrom "C:\\Program Files\\Matyas and Zoltan's Clean 4\\Dynamics\\system dynamics\\545ff953d726e94a9904a8d2247ebf03.sysdyn"