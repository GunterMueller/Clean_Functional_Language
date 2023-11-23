module timeprofiler

import StdArray, StdBool, StdList, StdFunc, StdTuple, StdOrdList
import StdProcess, StdId, StdMenu, StdReceiver, StdMenuElement, StdFileSelect, StdPStClass

import flexwin
import ExtNotice
import Help
import ShowProfile,time_profile_os_dependent
import Platform,PlatformObjectIO

ApplicationName	:== "ShowTimeProfile"
HelpFileName	:== ApplicationName +++ "Help"

:: ProfileViewerState =
	{ mode		:: ViewMode
	, mods		:: [FormattedProfile]
	, funs		:: [FormattedProfile]
	, pset		:: MaybePrintSetup
	, name		:: String
	}

:: MaybePrintSetup = NoPrintSetup | PrintSetup !PrintSetup;

:: ViewMode
	= ViewByModule
	| ViewByFunction

initialState
	 =
	{ mode		= ViewByFunction
	, mods		= []
	, funs		= []
	, pset		= NoPrintSetup
	, name		= ""
	}

Start world
	# (r,_,_) = clock_speed_and_profile_overhead
	| r==1
		= error_notice_and_quit
			["Profiling does not work on this computer,",
			 "because the processor does not have a time stamp counter"
			] world
	| r==2
		= error_notice_and_quit
			["Profiling does not work on this computer,",
			 "because the Windows API function QueryPerformanceFrequency failed"
			] world
	# (winId,world)		= openId world
	# (recId,world)		= openR2Id world
	# (closeId,world)	= openId world
	# (printId,world)	= openId world
	= startIO SDI initialState (init winId closeId printId recId) (atts winId closeId printId recId) world
where
	init winId closeId printId recId ps
		# ((mods,funs,name),ps)
					= open_time_file_from_command_line ps
		# hasClose	= not (isEmpty mods)
		# (viewer_mode,ps)
					= accPLoc (\vs=:{mode}-> (mode,{vs & mods = mods,funs = funs,name=name})) ps
		# info`		= case viewer_mode of
						ViewByModule	-> mods
						ViewByFunction	-> funs
		# title		= case name of
						""	-> ApplicationName
						nm	-> nm
		# (_,ps)	= openWindow Void (FlexBarWindow title info info` profileLook profileFuns recId
						[ WindowViewSize {w=980,h=400}
		//				, WindowKeyboard keyfilter Able (keyfunction (noLS(reopenfun closeId printId recId))) 
						, WindowId winId
						]) ps
		# (_,ps)	= openMenu Void (file_menu hasClose winId closeId printId recId) ps
		# (_,ps)	= openMenu Void (sort_menu recId) ps
		# (_,ps)	= openMenu Void (view_menu recId) ps
		# (_,ps)	= openMenu Void (help_menu) ps
		= installPlatformEventHandlers ps

file_menu hasClose winId closeId printId recId =
	Menu "&File"
	(	MenuItem "&Open..."	[MenuFunction (noLS (openfun winId closeId printId recId)),MenuShortKey 'O']
	:+: MenuItem "&Refresh" [MenuFunction (noLS (reopenfun winId closeId printId recId)),MenuShortKey 'R']
	:+: MenuItem "&Close"	[MenuId closeId,MenuSelectState (if hasClose Able Unable),MenuFunction (noLS (closefun winId closeId printId recId)),MenuShortKey 'W']
	:+:	MenuSeparator		[]
	:+: MenuItem "&Print..."[MenuId printId,MenuSelectState (if hasClose Able Unable),MenuFunction (noLS (printfun recId)),MenuShortKey 'P']
	:+:	MenuSeparator		[]
	:+: MenuItem "&Help"	[MenuFunction (noLS (showHelp HelpFileName))]
	:+:	MenuSeparator		[]
	:+:	MenuItem "&Quit"	[MenuFunction (noLS closeProcess),MenuShortKey 'Q']
	)[]

sort_menu recId =
	Menu "&Sort"
	(	MenuItem "Sort by &Function"		[MenuShortKey 'F', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 1))))]
	:+:	MenuItem "Sort by &Module"			[MenuShortKey 'M', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 1))))]
	:+:	MenuItem "Sort by &Time"			[MenuShortKey 'T', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 3))))]
	:+:	MenuItem "Sort by &Allocation"		[MenuShortKey 'A', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 5))))]
	:+:	MenuItem "Sort by &Strict calls"	[MenuShortKey 'S', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 6))))]
	:+:	MenuItem "Sort by &Lazy calls"		[MenuShortKey 'L', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 7))))]
	:+:	MenuItem "Sort by &Curried calls"	[MenuShortKey 'C', MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 8))))]
	) []

view_menu recId =
	Menu "&View"
	(	MenuItem "View by &Function"	[MenuFunction (noLS (switchView recId ViewByFunction))]
	:+:	MenuItem "View by &Module"		[MenuFunction (noLS (switchView recId ViewByModule))]
	) []

help_menu =
	Menu "&Help"
	(	MenuItem "&About..."	[MenuFunction (noLS (showAbout ApplicationName HelpFileName))]
	:+:	MenuItem "&Help..."		[MenuFunction (noLS (showHelp HelpFileName))]
	) []
	
atts winId closeId printId recId =
	[ ProcessClose closeProcess
	, ProcessOpenFiles (openFiles winId closeId printId recId)
	]

info =
	[("Module"			,Just 160)
	,("Function"		,Just 160)
	,("Time(s)"			,Just 120)
	,("Time(%)"			,Just 90)
	,("Alloc(bytes)"	,Just 100)
	,("Alloc(%)"		,Just 100)
	,("Strict(n)"		,Just 80)
	,("Lazy(n)"			,Just 80)
	,("Curried(n)"		,Just 80)
	]

//-- Support functions...

open_time_file_from_command_line ps
	# (commandline_arguments,ps) = initPlatformCommandLineArguments ps
	| isEmpty commandline_arguments
		= (([],[],""),ps)
		= open_file_function (hd commandline_arguments) ps

openFiles _ _ _ _ [] ps = ps
openFiles winId closeId printId recId [h:t] ps
	# ((mods,funs,name),ps)
						= open_file_function h ps
	# (viewer_mode,ps)	= accPLoc (\vs=:{mode}-> (mode,{vs & mods = mods, funs = funs, name = name})) ps
	# info				= case viewer_mode of
							ViewByModule	-> mods
							ViewByFunction	-> funs
	# ((err,_),ps)		= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	# ps				= appPIO (enableMenuElements [closeId,printId]) ps
	# title				= case name of
							""	-> ApplicationName
							nm	-> nm
	# ps				= appPIO (setWindowTitle winId title) ps
	= ps
	
switchView recId viewer_mode ps
	# (info,ps)		= accPLoc (\vs=:{mods,funs} -> ((mods,funs),{vs & mode = viewer_mode})) ps
	# info			= case viewer_mode of
						ViewByModule	-> fst info
						ViewByFunction	-> snd info
	// would be nice to hide function column in module view...
	# ((err,_),ps)	= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	= ps
	
error_notice_and_quit :: [.String] *World -> .World;
error_notice_and_quit strings world
	= startIO NDI  0 (okNotice strings) [] world

openfun winId closeId printId recId ps
	# (name,ps)			= selectInputFile ps
	| isNothing name
		= ps
	# ((mods,funs,name),ps)	= open_file_function (fromJust name) ps
	# (view_mode,ps)	= accPLoc (\vs=:{mode} -> (mode,{vs & mods = mods, funs = funs, name = name})) ps
	# info				= case view_mode of
							ViewByModule	-> mods
							ViewByFunction	-> funs
	# ((err,_),ps)		= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	# ps				= appPIO (enableMenuElements [closeId,printId]) ps
	# title				= case name of
							""	-> ApplicationName
							nm	-> nm
	# ps				= appPIO (setWindowTitle winId title) ps
	= ps

reopenfun winId closeId printId recId ps
	# (name,ps)				= accPLoc (\vs=:{name} -> (name,vs)) ps
	# ((mods,funs,_),ps)	= open_file_function name ps
	# (view_mode,ps)		= accPLoc (\vs=:{mode} -> (mode,{vs & mods = mods, funs = funs})) ps
	# info					= case view_mode of
								ViewByModule	-> mods
								ViewByFunction	-> funs
	# ((err,_),ps)			= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	# ps					= appPIO (enableMenuElements [closeId,printId]) ps
	# title					= case name of
								""	-> ApplicationName
								nm	-> nm
	# ps					= appPIO (setWindowTitle winId title) ps
	= ps

closefun winId closeId printId recId ps
	# ps				= appPLoc (\vs=:{mode} -> {vs & mods = [], funs = [], name = ""}) ps
	# ((err,_),ps)		= syncSend2 recId (FW_SetContent []) ps
	| err <> SendOk
		= ps
	# ps				= appPIO (disableMenuElements [closeId,printId]) ps
	# title				= ApplicationName
	# ps				= appPIO (setWindowTitle winId title) ps
	= ps

printfun recId ps
	# (printSetup,ps) = getPrintSetup ps
	# ((err,info),ps)				= syncSend2 recId FW_GetContent ps
	| err <> SendOk || isNothing info
		= ps
	# info							= case fromJust info of
										FW_DummyOut		-> Nothing
										FW_ContentOut i	-> Just i
	| isNothing info
		= ps
	# info							= fromJust info
	# (functionData,[sumData:_])	= splitAt (dec (length info)) info
	# ((ok,printFont),ps)			= accPIO (accScreenPicture (openFont printFont)) ps 
//	| not ok
//		= ps
	# (printSetup,ps)				= printTable printFont printSetup functionData sumData ps
	# ps							= appPLoc (\vs -> {vs & pset = PrintSetup printSetup}) ps
	= ps
where
	printFont	= PlatformDependant
					{fName="Courier New",fStyles=[BoldStyle],fSize=8}
					{fName="Monaco",fStyles=[],fSize=8}

getPrintSetup :: !*(PSt u:ProfileViewerState) -> *(!PrintSetup,!*(PSt u:ProfileViewerState))
getPrintSetup ps=:{ls={pset=PrintSetup printSetup}}
	= (printSetup,ps)
getPrintSetup ps=:{ls={pset=NoPrintSetup}}
	# (printSetup,ps) = defaultPrintSetup ps
	= (printSetup,{ps & ls.pset=PrintSetup printSetup});

//-- Profile stuff...

open_file_function :: {#.Char} *a -> *((.[FormattedProfile],.[FormattedProfile],String),*a) | FileEnv a;
open_file_function file_name pst
	# ((open_ok,profile),pst)	= accFiles (open_profile file_name) pst
 	| not open_ok
		= /*trace_n "open_file_function failed"*/ (([],[],""),pst)
	# (total_strict_calls,total_lazy_calls,total_curried_calls,total_allocation,total_time)
								= sum_time_and_allocation profile

	# module_profile			= totals_per_module (sortBy le_module_name profile);
	# (formatted_module_profile,_)
								= format_profile total_strict_calls total_lazy_calls total_curried_calls total_allocation total_time module_profile;
	# formatted_module_profile	= sortBy ge_profile_time formatted_module_profile;

	# (formatted_profile,total_profile)
								= format_profile total_strict_calls total_lazy_calls total_curried_calls total_allocation total_time profile
	# formatted_profile			= sortBy ge_profile_time formatted_profile

	# info						= formatted_module_profile ++ [total_profile]
	# info`						= formatted_profile ++ [total_profile]

	= ((info,info`,file_name),pst)

profileFuns =
	[ appInfo (info_sort l_module_name)
	, appInfo (info_sort l_profile_name)
	, appInfo (info_sort g_profile_time)
	, appInfo (info_sort g_profile_time)
	, appInfo (info_sort g_profile_byte)
	, appInfo (info_sort g_profile_byte)
	, appInfo (info_sort g_profile_strict)
	, appInfo (info_sort g_profile_lazy)
	, appInfo (info_sort g_profile_curried)
	]
where	//--> needs to be param of HeaderWindow...
	info_sort sort info
		# (f,t) = splitAt (dec (length info)) info
		# f = sortBy sort f
		= f++t

//profileLook :: [.FormattedProfile] .Int .Int [.Int] -> v:(w:SelectState u:(.UpdateState -> .(*Picture -> .Picture))), [u <= w, u <= v];
profileLook lines top line_height cols = look
where
	look ss us=:{updArea,newFrame={corner2={x}}} pic
		# (met,pic) = getPenFontMetrics pic
		# delta_text = met.fDescent + 1
		= draw_profile_lines` delta_text (cols++[x]) lines top line_height updArea pic

instance content_size [a]
where
	content_size metrics lines
		# line_height = fontLineHeight metrics
		= line_height * (length lines)

