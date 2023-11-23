module heapprofiler

import StdEnv, StdIO
import flexwin
import ExtNotice
import Help
import ShowHeapProfile,heap_profile_os_dependent
import PlatformObjectIO

ApplicationName :==  "ShowHeapProfile"
HelpFileName :== ApplicationName +++ "Help"

Start world
	# (winId,world)		= openId world
	# (recId,world)		= openR2Id world
	# (closeId,world)	= openId world
	# (printId,world)	= openId world
	# (pageId,world)	= openId world
	# (nextId,world)	= openId world
	# (prevId,world)	= openId world
	= startIO SDI Nothing (init recId winId closeId printId pageId nextId prevId) (atts recId winId closeId printId pageId nextId prevId) world
where
	init recId winId closeId printId pageId nextId prevId ps
		# (info`=:{application_name},ps)	= open_heap_file_from_command_line ps
		# ps			= appPLoc (\l->Just application_name) ps
		# (_,ps)		= openWindow Void (FlexBarWindow application_name info info` profileLook profileFuns recId
							[ WindowViewSize {w=560,h=400}
							, WindowId winId
							]) ps
		# (_,ps)		= openMenu Void (file_menu recId winId closeId printId pageId nextId prevId) ps
		# (_,ps)		= openMenu Void (sort_menu recId) ps
		# hasPrev		= fst (determine_previous_page application_name)
		# hasNext		= fst (determine_next_page application_name)
		# hasPage		= hasPrev || hasNext
		# (_,ps)		= openMenu Void (page_menu hasPage hasNext hasPrev recId pageId winId nextId prevId) ps
		# (_,ps)		= openMenu Void (help_menu) ps
		  ps = if (info`.node_size_sum>=0) (appPIO (enableMenuElements [closeId,printId]) ps) ps
		= installPlatformEventHandlers ps

file_menu recId winId closeId printId pageId nextId prevId =
	Menu "&File"
	(	MenuItem "&Open..."
		[ MenuFunction (noLS (openfun recId winId closeId printId pageId nextId prevId))
		, MenuShortKey 'O'
		]
	:+: MenuItem "&Close"
		[ MenuFunction (noLS (closefun recId winId closeId printId pageId nextId prevId))
		, MenuId closeId
		, MenuSelectState Unable
		, MenuShortKey 'W'
		]
	:+:	MenuSeparator		[]
	:+: MenuItem "&Print..."
		[ MenuFunction (noLS (printfun recId))
		, MenuId printId
		, MenuSelectState Unable
		, MenuShortKey 'P'
		]
	:+:	MenuSeparator		[]
	:+: MenuItem "&Help"
		[ MenuFunction (noLS (showHelp HelpFileName))
		]
	:+:	MenuSeparator		[]
	:+:	MenuItem "&Quit"
		[ MenuFunction (noLS closeProcess)
		, MenuShortKey 'Q'
		]
	)[]

sort_menu recId =
	Menu "&Sort"
	(	MenuItem "Sort by &Function"
		[ MenuShortKey 'F'
		, MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 1))))
		]
	:+:	MenuItem "Sort by &Module"
		[ MenuShortKey 'M'
		, MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 2))))
		]
	:+:	MenuItem "Sort by &Heap Use"
		[ MenuShortKey 'H'
		, MenuFunction (noLS (snd o (syncSend2 recId (FW_ApplyFunction 3))))
		]
	) []

page_menu hasPage hasNext hasPrev recId pageId winId nextId prevId =
	Menu "&Page"
	(	MenuItem "&Next page"
		[ MenuShortKey 'N'
		, MenuFunction (noLS (nextfun recId pageId winId nextId prevId))
		, MenuId nextId
		, MenuSelectState (if hasNext Able Unable)
		]
	:+:	MenuItem "&Previous page"
		[ MenuShortKey 'B'
		, MenuFunction (noLS (prevfun recId pageId winId nextId prevId))
		, MenuId prevId
		, MenuSelectState (if hasPrev Able Unable)
		]
	) [MenuSelectState (if hasPage Able Unable), MenuId pageId]

help_menu =
	Menu "&Help"
	(	MenuItem "&About..."	[MenuFunction (noLS (showAbout ApplicationName HelpFileName))]
	:+:	MenuItem "&Help..."		[MenuFunction (noLS (showHelp HelpFileName))]
	) []
	
atts recId winId closeId printId pageId nextId prevId =
	[ ProcessClose closeProcess
	, ProcessOpenFiles (openFiles recId winId closeId printId pageId nextId prevId)
	]

info =
	[("Function"			,Just 160)
	,("Module"				,Just 160)
	,("Heap Use (bytes)"	,Just 130)
	,("Heap Use (%)"		,Just 100)
	]

//-- Support functions...

open_heap_file_from_command_line ps
	# (commandline_arguments,ps) = initPlatformCommandLineArguments ps
	| isEmpty commandline_arguments
		# dp=NoPrintSetup
		= (empty_progstate dp,ps)
	= open_file_function (hd commandline_arguments) ps

openFiles _ _ _ _ _ _ _ [] ps = ps
openFiles recId winId closeId printId pageId nextId prevId [h:t] ps
	# (info=:{application_name},ps)
					= open_file_function h ps
	# ps			= appPLoc (const (Just application_name)) ps
	# ((err,_),ps)	= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	# ps			= appPIO (setWindowTitle winId application_name) ps	// doesn't change process title :-(
	# ps			= appPIO (enableMenuElements [closeId,printId]) ps
	= enable_disable nextId prevId pageId application_name ps
	
openfun recId winId closeId printId pageId nextId prevId ps
	# (name,ps)		= selectInputFile ps
	| isNothing name
		= ps
	# (info=:{application_name},ps)
					= open_file_function (fromJust name) ps
	# ((err,_),ps)	= syncSend2 recId (FW_SetContent info) ps
	| err <> SendOk
		= ps
	# ps			= appPIO (setWindowTitle winId application_name) ps	// doesn't change process title :-(
	# ps			= appPIO (enableMenuElements [closeId,printId]) ps
	= enable_disable nextId prevId pageId application_name ps

closefun recId winId closeId printId pageId nextId prevId ps
	# dp = NoPrintSetup
	# ((err,_),ps)	= syncSend2 recId (FW_SetContent (empty_progstate dp)) ps
	| err <> SendOk
		= ps
	# ps			= appPIO (setWindowTitle winId ApplicationName) ps
	# ps			= appPIO (disableMenuElements [closeId,printId]) ps
	# ps			= appPIO (disableMenuElements [prevId,nextId]) ps
	# ps			= appPIO (disableMenus [pageId]) ps
	= ps

printfun recId ps
	# ((err,reply),ps)		= syncSend2 recId FW_GetContent ps
	| err <> SendOk
		= ps
	| isNothing reply
		= ps
	# print_font = PCorMac {fName="Courier New",fStyles=[BoldStyle],fSize=8} {fName="Monaco",fStyles=[],fSize=9}
	# ((ok,printFont),ps)	= accPIO (accScreenPicture (openFont print_font)) ps 
	| not ok	// handle better...
		= ps
	= case (fromJust reply) of
		FW_DummyOut
					-> ps
		(FW_ContentOut fw)
					# (fw,ps)		= case fw.printingSetup of
										NoPrintSetup
											# (printingSetup,ps) = defaultPrintSetup ps
											# fw = {fw & printingSetup=PrintSetup printingSetup}
											-> (fw,ps)
										PrintSetup _
											-> (fw,ps)
					# (fw,ps)		= printTable printFont fw ps
					# (_,ps)		= syncSend2 recId (FW_SetContent fw) ps
					-> ps

nextfun recId pageId winId nextId prevId ps
	# ((err,reply),ps)		= syncSend2 recId FW_GetContent ps
	| err <> SendOk = ps
	| isNothing reply = ps
	= case (fromJust reply) of
		FW_DummyOut
					-> ps
		(FW_ContentOut fw)
					# (fw=:{application_name},ps)
									= show_next_page fw ps
					# ((err,_),ps)	= syncSend2 recId (FW_SetContent fw) ps
					| err <> SendOk
						-> ps
					# ps = appPIO (setWindowTitle winId application_name) ps
					-> enable_disable nextId prevId pageId application_name ps

prevfun recId pageId winId nextId prevId ps
	# ((err,reply),ps)		= syncSend2 recId FW_GetContent ps
	| err <> SendOk = ps
	| isNothing reply = ps
	= case (fromJust reply) of
		FW_DummyOut	-> ps
		(FW_ContentOut fw)
					# (fw=:{application_name},ps)
									= show_prev_page fw ps
					# ((err,_),ps)	= syncSend2 recId (FW_SetContent fw) ps
					| err <> SendOk
						-> ps
					# ps = appPIO (setWindowTitle winId application_name) ps
					-> enable_disable nextId prevId pageId application_name ps

enable_disable nextId prevId pageId application_name ps
	# enable		=	(if (fst(determine_previous_page application_name)) [prevId] [])
					++	(if (fst(determine_next_page application_name)) [nextId] [])
	| isEmpty enable
		# ps		= appPIO (disableMenuElements [nextId,prevId]) ps
		# ps		= appPIO (disableMenus [pageId]) ps
		= ps
	# ps			= appPIO (enableMenuElements enable) ps
	# disable		= removeMembers [nextId,prevId] enable
	# ps			= appPIO (disableMenuElements disable) ps
	# ps			= appPIO (enableMenus [pageId]) ps
	= ps

//-- Profile stuff...

open_file_function file_name pst
	# (open_ok,_,profile,pst)	= p_open_file_function file_name pst
 	| not open_ok
//		# pst	= trace_n "open_file_function failed" pst
		= (profile,pst)
	= (profile,pst)

profileFuns =
	[ appInfo` (sortBy compare_function_name)
	, appInfo` (sortBy compare_module_name)
	, appInfo` (sortBy compare_heap_use)
	, appInfo` (sortBy compare_heap_use)
	]
appInfo` f i = appInfo f` i
where
	f` i=:{node_size_list} = { i & node_size_list = f node_size_list}

profileLook {node_size_list,node_size_sum} top line_height cols = look
where
	look ss us=:{updArea,newFrame=newFrame=:{corner2={x}}} pic
		| node_size_sum < 0
			= stdUnfillUpdAreaLook ss us pic
		# (met,pic) = getPenFontMetrics pic
		# leading = met.fLeading
//		# delta_text = leading / 2
//		# delta_text = line_height - (met.fAscent) - 1	//(leading / 2)
		# delta_text = met.fDescent + 1
		# bot = top + leading + (line_height * (1  + length node_size_list))
		# pic =  unfill {corner1={newFrame.corner1 & y = top},corner2={newFrame.corner2 & y = top+leading}} pic
		# pic =  unfill {corner1={newFrame.corner1 & y = bot-leading},corner2={newFrame.corner2 & y = bot}} pic
		= draw_heap_profile_lines (cols++[x]) True node_size_list (top+line_height-delta_text) line_height delta_text node_size_sum pic

instance content_size (ProgState [a])
where
	content_size fm {node_size_list}
		# lh = fontLineHeight fm
		= lh * (1+length node_size_list) + fm.fLeading// omdat we altijd totaal laten zien...
	
