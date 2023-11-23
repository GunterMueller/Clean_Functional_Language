implementation module htmlDatabase

import StdClass, StdInt, StdString
import htmlExceptions, htmlFormlib

// editor for persistent information:

universalDB :: !(!Init,!Lifespan,!a,!String) !(String a -> Judgement) !*HSt -> (a,!*HSt) | iData a
universalDB (init,lifespan,value,filename) invariant hst
# (dbf,hst)					= myDatabase Init (0,value) hst									// create / read out database file
# (dbversion,dbvalue)		= dbf.value														// version number and value stored in database
# (versionf,hst)			= myVersion Init dbversion hst 									// create / read out version number expected by this application
# version					= versionf.value												// current version number assumed in this application
| init == Init																				// we only want to read, no version conflict
	# (_,hst)				= myVersion Set dbversion hst 									// synchronize version number and
	= (dbvalue,hst)																			// return current value stored in database
| dbversion <> version																		// we want to write and have a version conflict
	# (_,hst)				= myVersion Set dbversion hst									// synchronize with new version
	# (_,hst)				= ExceptionStore ((+) (Just (filename,"Your screen data is out of date; I have retrieved the latest data."))) hst
																							// Raise exception
	= (dbvalue,hst)																			// return current version stored in database 
# exception					= invariant filename value										// no version conflict, check invariants															// check invariants
| isJust exception																			// we want to write, but invariants don't hold
	# (_,hst)				= ExceptionStore ((+) exception) hst 							// report them 
	= (value,hst)																			// return disapproved value such that it can be improved
# (versionf,hst)			= myVersion  Set (dbversion + 1) hst 							// increment version number
# (_,hst)					= myDatabase Set (versionf.value,value) hst						// update database file
= (value,hst)
where
	myDatabase init cntvalue hst 															// read the database
							= mkEditForm (init,if (lifespan == TxtFile) pFormId dbFormId filename cntvalue <@ NoForm) hst
	myVersion  init cnt hst	= mkEditForm (init,xtFormId ("vrs_db_" +++ filename) cnt) hst	// to remember version number
