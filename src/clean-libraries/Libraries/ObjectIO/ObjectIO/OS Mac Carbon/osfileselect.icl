implementation module osfileselect


//	Clean Object I/O library, version 1.2


import	StdBool, StdInt, StdString, StdMisc, StdArray, StdClass, StdChar
import	osevent
from	commondef	import fatalError
import	/*standard_file,*/ files
from	pointer		import	LoadWord, LoadLong, StoreLong, StoreWord
from	quickdraw	import	QScreenRect
import	osdirectory, navigation, memory, pointer, appleevents

osInitialiseFileSelectors :: !*OSToolbox -> *OSToolbox
osInitialiseFileSelectors tb = tb

osfileselectFatalError :: String String -> .x
osfileselectFatalError function error
	= fatalError function "osfileselect" error

osSelectinputfile :: !(OSEvent->.s->.s) !.s !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectinputfile handleOSEvent state tb
	# (nav_reply_record,_,tb)		= NewPtr NavReplyRecordSize tb
	# (err,tb)						= NavGetFile 0 nav_reply_record 0 0 0 0 0 0 tb
	# (ok,file_name,tb)				= get_or_put_file_selector_result err nav_reply_record tb
	= (ok,file_name,state,tb)

osSelectoutputfile :: !(OSEvent->.s->.s) !.s !String !String !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectoutputfile handleOSEvent state prompt filename tb
	# (err,fileSpec,tb)				= FSMakeFSSpec filename tb
	// we can ignore the filespec creation error since we also want to show the dialog
	// if no (legal) path prefix was given...
//	| err <> 0
//		= (False,"",state,tb)
	# (aedesc,err,tb)				= NewPtr SizeOfAEDesc tb
	| err <> 0
		= (False,"",state,tb)
	# err
		=  AECreateDesc KeyFssString fileSpec aedesc
	| err <> 0
		= (False,"",state,tb)

	// Strip path for now...
	# filename						= strip_path filename 0 0
	// Ignores prompt for now...
	# (err,nav_dialog_options,tb)	= NavGetDefaultDialogOptions tb
	| err<>0
		# tb						= DisposePtr nav_dialog_options tb
		= (False,"",state,tb)
	# (nav_reply_record,_,tb)		= NewPtr NavReplyRecordSize tb
	# (flags,tb)					= LoadLong (nav_dialog_options+NavDialogOptionFlagsOffset) tb
	# flags							= flags bitor kNavNoTypePopup
	# tb							= StoreLong (nav_dialog_options+NavDialogOptionFlagsOffset) flags tb
	# tb							= copy_string_to_memory filename (nav_dialog_options+NavDialogOptionSavedFileNameOffset) tb
	# (err,tb)						= NavPutFile aedesc/*0*/ nav_reply_record nav_dialog_options 0 0 0 /*0x2a2a2a2a **** */ 0 tb
	# (ok,file_name,tb)				= get_or_put_file_selector_result err nav_reply_record tb
	# tb							= DisposePtr nav_dialog_options tb
	= (ok,file_name,state,tb)

osSelectdirectory :: !(OSEvent->.s->.s) !.s !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectdirectory handleOSEvent state tb
	# (nav_reply_record,_,tb)		= NewPtr NavReplyRecordSize tb
	# (err,tb)						= NavChooseFolder 0 nav_reply_record 0 0 0 0 tb
	# (ok,file_name,tb)				= get_or_put_file_selector_result err nav_reply_record tb
	= (ok,file_name,state,tb)

copy_string_to_memory s p tb
	# tb	= StoreByte p (size s) tb
	= copy_chars 0 (p+1) tb
where
	copy_chars i p tb
		| i>=size s
			= tb
		# tb = StoreByte (p+i) (toInt s.[i]) tb
		= copy_chars (i+1) p tb

//===

strip_path :: !String !Int !Int -> String
strip_path filepath p l
	| colon	= strip_path filepath (inc p) (inc p)
	= filepath%(l,dec (size filepath))
where
	(colon,p2)	= Find_colon filepath p

Find_colon :: !String !Int -> (!Bool,!Int)
Find_colon s p = Find_colon2 s p ((size s)-1)

Find_colon2 :: String !Int !Int -> (!Bool,!Int)
Find_colon2 s p l
|	p >= l				= (False,p)
|	select s p == ':'	= (True,p)
						= Find_colon2 s (p+1) l
