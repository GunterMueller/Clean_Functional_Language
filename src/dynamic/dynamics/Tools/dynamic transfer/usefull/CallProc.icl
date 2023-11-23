implementation module CallProc

import StdEnv, StdIO
from clCCall_12 import winLaunchApp, winLaunchApp2, winCallProcess, winMakeCString, winReleaseCString, :: OSToolbox, :: CSTR

CallProcess :: !String [(!String,!String)] !String !String !String !String !*OSToolbox *World -> (!Bool, !Int, !*OSToolbox, *World)
CallProcess command environment directory stdin stdout stderr os world
	| size command > 0
		#	(commandptr,os)		=  winMakeCString command os
		    envstring			=  MakeEnvironmentString environment
			(envptr,os)			=  case (size envstring == 0) of
										True	-> (0, os)
										false	-> (winMakeCString envstring os)
		    (dirptr, os)		=  case (size directory == 0) of
										True	-> (0, os)
										false	-> (winMakeCString directory os)
			(inptr,  os)		=  case (size stdin  == 0) of
										True	-> (0, os)
										false	-> (winMakeCString stdin  os)
			(outptr, os)		=  case (size stdout == 0) of
										True	-> (0, os)
										false	-> (winMakeCString stdout os)
			(errptr, os)		=  case (size stderr == 0) of
										True	-> (0, os)
										false	-> (winMakeCString stderr os)
		    (success, exitcode, os) 
								=  winCallProcess commandptr envptr dirptr inptr outptr errptr os
			os					=  winReleaseCString commandptr os
			os					=  case (envptr == 0) of
										True	-> os
										false	->  (winReleaseCString envptr os)
			os					=  case (dirptr == 0) of
										True	-> os
										false	->  (winReleaseCString dirptr os)
			os					=  case (envptr == 0) of
										True	-> os
										false	-> (winReleaseCString inptr os)
			os					=  case (envptr == 0) of
										True	-> os
										false	-> (winReleaseCString outptr os)
			os					=  case (envptr == 0) of
										True	-> os
										false	-> (winReleaseCString errptr os)
			( cons, world ) = stdio world
			//cons = fwrites command cons
			( ok, world ) = fclose cons world
		= (success, exitcode, os, world)
	= (False, -1, os, world)
where
	MakeEnvironmentString [] = ""
    MakeEnvironmentString [ (name, value):rest ] = name +++ "=" +++ value +++ "\0" +++ MakeEnvironmentString rest
