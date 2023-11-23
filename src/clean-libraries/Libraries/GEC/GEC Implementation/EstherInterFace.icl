implementation module EstherInterFace

import StdEnv, EstherPostParser, EstherTransform, StdDynamic
import EstherScript, EstherStdEnv


/*MyEstherState world = 
	{	searchPath	= [["."]]
//	,	searchCache	= []
	,	builtin		= stdEnv
	,	env			= world
	}*/


/*Start world 
	# (console, world)	= stdio world
	# (console,world)	= shell 1 console world
	= fclose console world*/
 
unifyable :: !Dynamic !Dynamic -> (!Bool,!Dynamic)
unifyable old=:(d1::a) new=:(d2::a) = (True,new)
unifyable old new		   			= (False,old)

stringToDynamic :: !String !*World -> (!Dynamic,!*World)
stringToDynamic s world 
	# (maybe, {env=world}) = compose s {builtin = stdEnv, env = world}
	= case maybe of
		NoException d -> (d, world)
		Exception d -> (d, world)

shell :: !Int !*File !*World -> (!*File,!*World)
shell lineNr console world
	# console 			= fwrites (toString lineNr +++ ":" +++ "> ") console
	  (cmdline, console) = freadline` console
	| cmdline == "exit" = (console,world)
	| cmdline == "" 	= shell lineNr console world
	# (d, world) 		= stringToDynamic cmdline world
	  (v, t) 			= toStringDynamic d
	  console 			= fwrites ("\n" +++ cmdline +++ "\n==>\n" +++ (foldr (+++) "" v) +++ " :: " +++ t +++ "\n") console
	= shell (lineNr + 1) console world
where
	freadline` :: !*File -> (!String, !*File)
	freadline` file
		# (line, file) = freadline file
		| line == "" = ("", file)
		| line.[size line - 1] == '\n' = (line % (0, size line - 2), file)
		= (line, file)

	eval :: !Int !(a -> b) !a -> b
	eval 1 f x = f x
	eval n f x = eval (force (f x) (n - 1)) f x
	where
		force :: !.a !.b -> .b
		force _ r = r
