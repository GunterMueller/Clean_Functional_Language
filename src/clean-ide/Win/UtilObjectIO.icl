implementation module UtilObjectIO

import code from library "util_io_shell_lib"

/*
 modify to use 'clCCall_12' functions instead of redefining them here...
*/
import StdArray, StdBool, StdClass, StdFile, StdList
import UtilDate

import StdSystem, StdWindow
import StdPathname, Directory
import	StdTuple, clCCall_12, clCrossCall_12
import	StdPSt, StdMaybe, iostate
from	deviceevents	import :: SchedulerEvent
from	osfileselect	import osInitialiseFileSelectors
from	scheduler		import handleOneEventForDevices
from	commondef		import fatalError

//--

CcRqSHELLDEFAULT	:== 1476

osIgnoreCallback :: !CrossCallInfo !*OSToolbox -> (!CrossCallInfo,!*OSToolbox)
osIgnoreCallback _ tb 
	= (return0Cci,tb)

osShellDefault :: !{#Char} !*OSToolbox -> (!Int,!*OSToolbox)
osShellDefault file tb
//	# tb = winInitialiseTooltips tb
	# (cstr,tb) = winMakeCString file tb
	# (ret,tb) = (issueCleanRequest2 osIgnoreCallback (Rq2Cci CcRqSHELLDEFAULT 0 cstr) tb)
	# tb = winReleaseCString cstr tb
	= (ret.p1,tb)


//---
SW_SHOWNORMAL	:== 1

ShellDefault :: !{#Char} !(PSt .l) -> (!Int,!(PSt .l))
ShellDefault file ps
	= accPIO (accIOToolbox (osShellDefault file)) ps
//	= accPIO (accIOToolbox (ShellExecute 0 0 file 0 0 SW_SHOWNORMAL)) ps

ShellExecute :: !Int !Int !{#Char} !Int !Int !Int !*OSToolbox -> (!Int,!*OSToolbox)
ShellExecute _ _ _ _ _ _ _ = code {
		ccall ShellExecuteA@24 "IIsIII:I:I"
	}

WinGetModulePath ::  {#Char}
WinGetModulePath
	= code inline
	{
		ccall WinGetModulePath "-S"
	}

RemoveFileName :: !String -> String;
RemoveFileName path
	| found	= (path % (0, dec position));
			= path;
where 
	(found,position)	= LastColon path last;
	last				= dec (size path);
		
LastColon :: !String !Int -> (!Bool, !Int);
LastColon s i
	| i <= 0
		= (False,0);
	| dirseparator==s.[i]
	 	= (True, i);
		= LastColon s (dec i);

//-- expand_8_3_names_in_path

FindFirstFile :: !String -> (!Int,!String);
FindFirstFile file_name
	# find_data = createArray 318 '\0';
	# handle = FindFirstFile_ file_name find_data;
	= (handle,find_data);

FindFirstFile_ :: !String !String -> Int;
FindFirstFile_ file_name find_data
	= code {
		ccall FindFirstFileA@8 "Pss:I"
	}

FindClose :: !Int -> Int;
FindClose handle = code {
		ccall FindClose@4 "PI:I"
	}

find_null_char_in_string :: !Int !String -> Int;
find_null_char_in_string i s
	| i<size s && s.[i]<>'\0'
		= find_null_char_in_string (i+1) s;
		= i;

find_data_file_name find_data
	# i = find_null_char_in_string 44 find_data;
	= find_data % (44,i-1);

find_first_file_and_close :: !String -> (!Bool,!String);
find_first_file_and_close file_name
	# (handle,find_data) = FindFirstFile file_name;
	| handle <> (-1)
		# r = FindClose handle;
		| r==r
			= (True,find_data);
			= (False,find_data);
		= (False,"");

find_last_backslash_in_string i s
	| i<0
		= (False,-1);
	| s.[i]=='\\'
		= (True,i);
		= find_last_backslash_in_string (i-1) s;

expand_8_3_names_in_path :: !{#Char} -> {#Char};
expand_8_3_names_in_path path_and_file_name
	# (found_backslash,back_slash_index) = find_last_backslash_in_string (size path_and_file_name-1) path_and_file_name;
	| not found_backslash
		= path_and_file_name;
	# path = expand_8_3_names_in_path (path_and_file_name % (0,back_slash_index-1));
	# file_name = path_and_file_name % (back_slash_index+1,size path_and_file_name-1);
	# path_and_file_name = path+++"\\"+++file_name;
	# (ok,find_data) = find_first_file_and_close (path_and_file_name+++"\0");
	| ok
		= path+++"\\"+++find_data_file_name find_data;
		= path_and_file_name;

//--
/*
import code from library "kernel_library"

Start = GetModuleFileName

MAX_PATH :== 260

GetModuleFileName :: (!Bool,!String)
GetModuleFileName
	#! buf = createArray (MAX_PATH+1) '\0'
	#! res = GetModuleFileName_ 0 buf MAX_PATH
	= (res <> 0,buf)
where
	GetModuleFileName_ :: !Int !String !Int -> !Int
	GetModuleFileName_ handle buffer buf_length
		= code {
			ccall GetModuleFileNameA@12 "PIsI:I"
			}
*/

//====

CcRqALTDIRECTORYDIALOG	:== 1475
CcRqALTFILEOPENDIALOG	:== 1478
CcRqALTFILESAVEDIALOG	:== 1479

selectInputFile` :: !(PSt .l) -> (!Maybe String,!(PSt .l))
selectInputFile` pState
	# (tb,pState)			= accPIO getIOToolbox pState
	# tb					= osInitialiseFileSelectors tb
	# (ok,name,pState,tb)	= osSelectinputfile handleOSEvent pState tb
	# pState				= appPIO (setIOToolbox tb) pState
	= (if ok (Just name) Nothing,pState)

selectOutputFile` :: !String !String !String !(PSt .l) -> (!Maybe String,!(PSt .l))
selectOutputFile` prompt filename ok pState
	# (tb,pState)			= accPIO getIOToolbox pState
	# tb					= osInitialiseFileSelectors tb
	# (ok,name,pState,tb)	= osSelectoutputfile handleOSEvent pState prompt filename ok tb
	# pState				= appPIO (setIOToolbox tb) pState
	= (if ok (Just name) Nothing,pState)

selectDirectory` :: !(PSt .l) -> (!Maybe String,!(PSt .l))
selectDirectory` env
//	= selectDirectory Nothing env
	# initial = global.[0]
	# (result,env) = selectDirectory initial env
	# (result,_) = case result of
					Nothing -> (result,global)
					(Just _) -> update_maybe_string result global
	= (result,env)
where
	selectDirectory :: !(Maybe String) !(PSt .l) -> (!Maybe String,!PSt .l)
	selectDirectory initial pState
		# (tb,pState)			= accPIO getIOToolbox pState
		# tb					= osInitialiseFileSelectors tb
		# (ok,name,pState,tb)	= osSelectdirectory handleOSEvent pState initial tb
		# pState				= appPIO (setIOToolbox tb) pState
		= (if ok (Just name) Nothing,pState)

//	handleOSEvent turns handleOneEventForDevices into the form required by osSelect(in/out)putfile.
handleOSEvent :: !OSEvent !*(PSt .l) -> *PSt .l
handleOSEvent osEvent pState
	= thd3 (handleOneEventForDevices (ScheduleOSEvent osEvent []) pState)

osSelectinputfile :: !(OSEvent->.s->.s) !.s !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectinputfile handleOSEvent state tb
	# (rcci,state,tb)	= issueCleanRequest (callback handleOSEvent) (Rq0Cci CcRqALTFILEOPENDIALOG) state tb
	# (ok,name,tb)		= getinputfilename rcci tb
	= (ok,name,state,tb)
where
	getinputfilename :: !CrossCallInfo !*OSToolbox -> (!Bool,!String,!*OSToolbox)
	getinputfilename {ccMsg=CcRETURN2,p1=ok,p2=ptr} tb
		| ok==0
			= (False,"",tb)
		| otherwise
			# (pathname,tb)	= winGetCStringAndFree ptr tb
			= (True,pathname,tb)
	getinputfilename {ccMsg=CcWASQUIT} tb
		= (False,"",tb)
	getinputfilename {ccMsg} _
		= osfileselectFatalError "osSelectinputfile" ("unexpected ccMsg field of return CrossCallInfo ("+++toString ccMsg+++")")

osSelectoutputfile :: !(OSEvent->.s->.s) !.s !String !String !String !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectoutputfile handleOSEvent state prompt filename ok tb
	# (promptptr,  tb)	= winMakeCString prompt   tb
	# (filenameptr,tb)	= winMakeCString filename tb
	# (okptr,tb)		= winMakeCString ok tb
	# (rcci,state, tb)	= issueCleanRequest (callback handleOSEvent) (Rq3Cci CcRqALTFILESAVEDIALOG promptptr filenameptr okptr) state tb
	# tb				= winReleaseCString promptptr   tb
	# tb				= winReleaseCString filenameptr tb
	# tb				= winReleaseCString okptr tb
	# (ok,name,tb)		= getoutputfilename rcci tb
	= (ok,name,state,tb)
where
	getoutputfilename :: !CrossCallInfo !*OSToolbox -> (!Bool,!String,!*OSToolbox)
	getoutputfilename {ccMsg=CcRETURN2,p1=ok,p2=ptr} tb
		| ok==0
			= (False,"",tb)
		| otherwise
			# (path,tb) = winGetCStringAndFree ptr tb
			= (True,path,tb)
	getoutputfilename {ccMsg=CcWASQUIT} tb
		= (False,"",tb)
	getoutputfilename {ccMsg} _
		= osfileselectFatalError "osSelectoutputfile" ("unexpected ccMsg field of return CrossCallInfo ("+++toString ccMsg+++")")

osSelectdirectory :: !(OSEvent->.s->.s) !.s !(Maybe String) !*OSToolbox -> (!Bool,!String,!.s,!*OSToolbox)
osSelectdirectory handleOSEvent state initial tb
	# (initialptr,  tb)	= case initial of
							Just initial	-> winMakeCString initial   tb
							Nothing			-> (0,tb)
	# (rcci,state,tb)	= issueCleanRequest (callback handleOSEvent) (Rq1Cci CcRqALTDIRECTORYDIALOG initialptr) state tb
	# tb				= case initialptr of
							0	-> tb
							_	-> winReleaseCString initialptr   tb
	# (ok,name,tb)		= getinputfilename rcci tb
	= (ok,name,state,tb)
where
	getinputfilename :: !CrossCallInfo !*OSToolbox -> (!Bool,!String,!*OSToolbox)
	getinputfilename {ccMsg=CcRETURN2,p1=ok,p2=ptr} tb
		| ok==0
			= (False,"",tb)
		| otherwise
			# (pathname,tb)	= winGetCStringAndFree ptr tb
			= (True,pathname,tb)
	getinputfilename {ccMsg=CcWASQUIT} tb
		= (False,"",tb)
	getinputfilename {ccMsg} _
		= osfileselectFatalError "osSelectdirectory" ("unexpected ccMsg field of return CrossCallInfo ("+++toString ccMsg+++")")

//	callback lifts a function::(OSEvent -> .s -> .s) to
//        a crosscallfunction::(CrossCallInfo -> .s -> *OSToolbox -> (CrossCallInfo,.s,*OSToolbox))
callback :: !(OSEvent->.s->.s) !CrossCallInfo !.s !*OSToolbox -> (!CrossCallInfo,!.s,!*OSToolbox)
callback handleOSEvent cci state tb = (return0Cci,handleOSEvent cci state,tb)

osfileselectFatalError :: String String -> .x
osfileselectFatalError function error
	= fatalError function "osaltfileselect" error

//== UNSAFE HACK...

global :: {Maybe String}
global
	#! path_name = expand_8_3_names_in_path (RemoveFileName WinGetModulePath);
	=: {Just path_name};

//update_maybe_string :: !(Maybe String) !*{(Maybe String)} -> (!(Maybe String),!*{(Maybe String)})
update_maybe_string :: !(Maybe String) !{(Maybe String)} -> (!(Maybe String),!{(Maybe String)})
update_maybe_string ms ar
//	= (ms,{ar & [0] = ms})
	= code {
		push_a 0
		pushI 0
		push_a 2
		update_a 2 3
		update_a 1 2
		updatepop_a 0 1
		update _ 1 0
		push_a 1
		update_a 1 2
		updatepop_a 0 1
	}

//===

COLOR_SCROLLBAR         :== 0
COLOR_BACKGROUND        :== 1
COLOR_ACTIVECAPTION     :== 2
COLOR_INACTIVECAPTION   :== 3
COLOR_MENU              :== 4
COLOR_WINDOW            :== 5
COLOR_WINDOWFRAME       :== 6
COLOR_MENUTEXT          :== 7
COLOR_WINDOWTEXT        :== 8
COLOR_CAPTIONTEXT       :== 9
COLOR_ACTIVEBORDER      :== 10
COLOR_INACTIVEBORDER    :== 11
COLOR_APPWORKSPACE      :== 12
COLOR_HIGHLIGHT         :== 13
COLOR_HIGHLIGHTTEXT     :== 14
COLOR_BTNFACE           :== 15
COLOR_BTNSHADOW         :== 16
COLOR_GRAYTEXT          :== 17
COLOR_BTNTEXT           :== 18
COLOR_INACTIVECAPTIONTEXT :== 19
COLOR_BTNHIGHLIGHT      :== 20

COLOR_3DDKSHADOW        :== 21
COLOR_3DLIGHT           :== 22
COLOR_INFOTEXT          :== 23
COLOR_INFOBK            :== 24

COLOR_HOTLIGHT                  :== 26
COLOR_GRADIENTACTIVECAPTION     :== 27
COLOR_GRADIENTINACTIVECAPTION   :== 28

COLOR_DESKTOP           :== COLOR_BACKGROUND
COLOR_3DFACE            :== COLOR_BTNFACE
COLOR_3DSHADOW          :== COLOR_BTNSHADOW
COLOR_3DHIGHLIGHT       :== COLOR_BTNHIGHLIGHT
COLOR_3DHILIGHT         :== COLOR_BTNHIGHLIGHT
COLOR_BTNHILIGHT        :== COLOR_BTNHIGHLIGHT

GetSysColor :: !Int -> Int
GetSysColor nIndex = code {
 ccall GetSysColor@4 "PI:I"
 }

GetDialogBackgroundColour :: !(PSt .l) -> (!Colour, !PSt .l)
GetDialogBackgroundColour ps
	= (RGB {r = rcol, g = gcol, b = bcol}, ps)
where
 col  = GetSysColor COLOR_BTNFACE
 rcol = (col bitand 0x000000FF)
 gcol = (col bitand 0x0000FF00) >> 8
 bcol = (col bitand 0x00FF0000) >> 16

isWindow :: !Id *(PSt .l) -> (Bool,*(PSt .l))
isWindow wId ps
	# (s,ps)	= accPIO getWindowsStack ps
	= (isMember wId s, ps)

WinLaunchApp ::  !{#Char} !Bool !*OSToolbox -> ( !Bool, !*OSToolbox)
WinLaunchApp _ _ _
	= code inline
	{
		ccall WinLaunchApp "SII-II"
	}

WinLaunchApp2 :: !{#Char} !{#Char} !Bool !*OSToolbox -> ( !Bool, !*OSToolbox)
WinLaunchApp2 _ _ _ _
	= code inline
	{
		ccall WinLaunchApp2 "SSII-II"
	}

LaunchApplication :: !{#Char} !{#Char} !Bool !Files -> ( !Bool, !Files)
LaunchApplication execpath homepath console files
	# (ok,_) = WinLaunchApp2 execpath homepath console 42
	= (ok,files)

LaunchApplication` :: !{#Char} !Bool !Files -> ( !Bool, !Files)
LaunchApplication` execpath  console files
	# (ok,_) = WinLaunchApp execpath console 42
	= (ok,files)
