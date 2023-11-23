implementation module osprint

import StdEnv,memory
import ospicture, print, StdPicture, iostate
from	quickdraw import QGetPort,QSetPort, :: GrafPtr

::	PrintSetup	:==	String
::	JobInfo
	=	{	range		:: !(!Int,!Int)
		,	copies		:: !Int
		}
::	PrintInfo
	=	{	printSetup	:: PrintSetup
		,	jobInfo		:: JobInfo
		}
::	Alternative x y
	=	Cancelled x
	|	StartedPrinting y


//import nodebug	//dodebug
DebugStr` _ f :== f
trace_n` _ f :== f

os_getpagedimensions	::	!PrintSetup	!Bool
						->	(!(!Int,!Int), !(!(!Int,!Int),!(!Int,!Int)), !(!Int,!Int))
os_getpagedimensions printSetup emulateScreenRes
	# emulateScreenRes = DebugStr` ("os_getpagedimensions",emulateScreenRes) emulateScreenRes
	# (err,dimensions)	= getPageDimensionsC printSetup emulateScreenRes
	# err = DebugStr` ("err",err) err
	| err<>0	
		= abort "osPrint08: fatal error: out of memory (2)"
	= trace_n` ("os_getpagedimensions",dimensions) dimensions
	
os_defaultprintsetup	::	!*env
						->	(!PrintSetup, !*env)
os_defaultprintsetup  env
	# ((err,printSetup),env)	= getDefaultPrintSetupC env
	| err<>0
		= abort "osPrint08: fatal error: out of memory (1)"
	= (printSetup,env)
						
	
class PrintEnvironments printEnv
where
	os_printpageperpage :: !Bool !Bool 
						   !.x
						   .(.x -> .(PrintInfo -> .(*Picture -> *((.Bool,Point2),*(.state,*Picture)))))
						   (*(.state,*Picture) -> *((.Bool,Point2),*(.state,*Picture)))
						   !PrintSetup !*printEnv
						-> (Alternative .x .state,!*printEnv)
	os_printsetupdialog		:: !PrintSetup !*printEnv
							->	(!PrintSetup, !*printEnv)

// on the Mac printing in any environment behaves equal

instance PrintEnvironments (PSt .l)
where
	os_printpageperpage doDialog emulateScreen x initFun transFun printSetup pState
		= printPagePerPageBoth doDialog emulateScreen x initFun transFun printSetup pState
	os_printsetupdialog printSetup env
		= printSetupDialog printSetup env
		
instance PrintEnvironments Files
where
	os_printpageperpage doDialog emulateScreen x initFun transFun printSetup files
		= printPagePerPageBoth doDialog emulateScreen x initFun transFun printSetup files
	os_printsetupdialog printSetup env
		= printSetupDialog printSetup env

printSetupDialog printSetup env
	# ((err,printSetup),env)	= printSetupDialogC printSetup env
	| err<>0
		# err = trace_n` ("printSetupDialog",err) err
		= abort ("osprint:printSetupDialog fatal error: " +++ toString err)
	= (printSetup,env)

printPagePerPageBoth ::	!Bool !Bool
					.x 
					.(.x -> .(PrintInfo -> .(*Picture -> ((.Bool,Point2),(.state,*Picture)))))
					((.state,*Picture) -> ((.Bool,Point2),(.state,*Picture)))
					!PrintSetup !*anyEnv
				-> 	(Alternative .x .state,!*anyEnv)
printPagePerPageBoth doDialog emulateScreen x initFun transFun printSetup env
	# (os, env) = envGetToolbox env
	// open dialogs and get printInfo record
	  (err, pRecHdl, printInfo, os) = getPrintInfo doDialog emulateScreen printSetup os
	| err==1
		= abort memErrorMessage
	// possibly the user canceled printing via the dialog
	| err==2
//		# (_, os) = DisposHandle pRecHdl os 
    	= (Cancelled x, envSetToolbox os env)
    | err <> 0	= abort ("Unexpected error (osprint:printPagePerPageBoth:getPrintInfo): "+++toString err)
  	# (err, (grPort,os)) = prOpenDoc pRecHdl os			// open document
  	# err = trace_n` ("print",2,pRecHdl,grPort,err) err
	// possibly the user canceled printing via command period
	| err == 1
		= abort memErrorMessage
	| err == 2 											// not fatal error (prob. user canceled)
      	# os = prCloseDoc (grPort,os) pRecHdl 					
		  os = prClose os								// will balance call of PrOpen via getPrintInfo
//		  (_, os) = DisposHandle pRecHdl os
		= (Cancelled x, envSetToolbox os env)  
	| err == -30872										// not fatal error (no default printer)
		// FIXME: want to provide more truthful reporting than 'Cancelled'
		= (Cancelled x, envSetToolbox os env)
    | err <> 0	= abort ("Unexpected error (osprint:printPagePerPageBoth:prOpenDoc): "+++toString err)
  	# ((pRecHdl,os),finalState) = printPages transFun (False,initFun x printInfo) (False,undef) undef (pRecHdl,os)
      os = prCloseDoc (grPort,os) pRecHdl 					// do the balancing functions
      os = prClose os
//    # (_, os) = DisposHandle pRecHdl os 
    = (StartedPrinting finalState, envSetToolbox os env)  

memErrorMessage	= "error: not enough extra memory for printing"

printPages _ _ (True,_) state intPict
  =(intPict,state)
printPages fun (inited,initFun) iOrig state (grPort,os)
  // prOpenPage will completely reinitialize the picture
  # os = trace_n` ("printPages",0) os
  # (err, os)	= prOpenPage grPort os
  | err <> 0								// probably: the user canceled printing
	 # os = trace_n` ("printPages",1,err) os
	 # (_, os)	= prClosePage grPort os
	 = ((grPort,os),state)
  # ((done,origin),state,os)	= case inited of
  					True	-> (iOrig,state,os)
  					_		# picture = packPicture zero defaultPen False 0 os
  							# (endOrig,(initState,picture)) = initFun picture	// get initialised state
  							# (_,_,_,_,os) = unpackPicture picture
  							# os = trace_n` ("printPages",2) os
  							-> (endOrig,initState,os)
  | done
	# os = trace_n` ("printPages",3) os
	# (_, os)	= prClosePage grPort os
  	= ((grPort,os),state)
  #	picture = packPicture origin defaultPen False 0 os
	// apply drawfunctions contained in this page
	(endOrig,(state,picture))			= fun (state,picture)
	// finish drawing
	(_,_,_,_,os) = unpackPicture picture
   	// end page
   	(ok, os)	= prClosePage grPort os
  | ok==0
	 # os = trace_n` ("printPages",4) os
	 = ((grPort,os),state)
  // draw rest of pages
  # os = trace_n` ("printPages",5)  os
  =	printPages fun (True,undef) endOrig state (grPort,os)      

zeroOrigin :== zero 		

///////////////////////////////////////////////////////////////////////////////

getPrintInfo :: !Bool !Bool !PrintSetup !*OSToolbox -> (!Int, !PRecHdl, !PrintInfo,!*OSToolbox)
getPrintInfo doDialog emulateScreen printSetup os
  #	( 	errCode,
    	pRecHdl,	
        first, last,
		copies,
		outPrintSetup,
		os ) = getPrintInfoC (if doDialog 1 0) (if emulateScreen 1 0) printSetup os
	first` = max 1 first
	last` = max first` last
	copies` = max 1 copies
  =( errCode,
  	 pRecHdl,
  	 { printSetup = outPrintSetup
	 , jobInfo =	{ range = (first`,last`)
	 				, copies = copies`
	 				}
	 },
     os
   )

 


os_printsetuptostring	::	!PrintSetup -> String
os_printsetuptostring printSetup
	= printSetup
	
os_stringtoprintsetup	::	!String -> PrintSetup
os_stringtoprintsetup string
	= string

envGetToolbox :: !*env -> (!*OSToolbox,!*env)
envGetToolbox env
  = (0,env)

envSetToolbox :: !*OSToolbox !*env -> *env
envSetToolbox os env
  = env

os_printsetupvalid		::	!PrintSetup !*env
						->	(!Bool, !*env)
os_printsetupvalid ps env
	= printsetupstringvalid ps env

