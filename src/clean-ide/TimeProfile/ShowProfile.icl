implementation module ShowProfile

//import StdEnv
//import StdIO
//import Help
//import expand_8_3_names_in_path
//import ArgEnv

import StdArray, StdBool, StdEnum, StdFile, StdFunc, StdList, StdMisc
import StdPicture, StdPrint, StdMaybe
import ExtNotice

import time_profile_os_dependent

//import code from library "time_profiler_kernel_library"
//import code from library "shit_library"

ApplicationName :==  "ShowTimeProfile"
HelpFileName :== ApplicationName +++ "Help"

//windowSize = {w=640,h=400}

//--

/*
:: *ProgState =
	{ info			:: ProfileInfo
	, print_setup	:: PrintSetup
	, monaco_font	:: !Font
	, wind			:: !Id
	}
*/

:: ProfileInfo
	= ProfileInfo [FormattedProfile] FormattedProfile
	| NoProfileInfo

//isNoProfile :: .ProfileInfo -> .Bool;
//isNoProfile NoProfileInfo = True
//isNoProfile _ = False

:: Profile =
	{ module_name		:: String
	, function_name		:: String
	, n_strict_calls	:: Int
	, n_lazy_calls		:: Int
	, n_curried_calls	:: Int
	, n_allocated_words	:: Int
	, time				:: Real
	}

:: FormattedProfile =
	{ f_module_name			:: String
	, f_function_name		:: String
	, f_n_strict_calls		:: Int
	, f_n_lazy_calls		:: Int
	, f_n_curried_calls		:: Int
	, f_n_allocated_words	:: Int
	, f_alloc_percentage	:: Real
	, f_time				:: Real
	, f_time_percentage		:: Real
	}

//--
/*
Start` :: !*World -> *World
Start` world
	# (r,_,_) = clock_speed_and_profile_overhead
	| r==1
		= error_notice_and_quit
			["Profiling does not work on this computer,",
			 "because the processor does not have a time stamp counter"
			] world
	| r==2
		= error_notice_and_quit
			["Profiling does not work on this computer,",
			 "because the windows API function QueryPerformanceFrequency failed"
			] world
	# (defaultPS, world)	= defaultPrintSetup world
	# (mf,world)			= accScreenPicture openDefaultFont world
	# (wi,world)			= openId world
	= startIO SDI (ploc wi mf defaultPS) pini patt world
where
	ploc wi mf ds =
		{ info			= NoProfileInfo
		, print_setup		= ds
		, monaco_font	= mf
		, wind			= wi
		}
	pini ps
		# (err,ps)	= openMenu undef file_menu ps
		# (err,ps)	= openMenu undef sort_menu ps
		# (err,ps)	= openMenu undef help_menu ps
		# ps		= open_profile_window ps
		# ps		= open_time_file_from_command_line ps
		= ps
	patt =
		[ ProcessClose closeProcess
		, ProcessOpenFiles openFiles
		, ProcessWindowSize windowSize
		]
	file_menu = Menu "&File"
					(	MenuItem "&Open"	[MenuShortKey 'O', MenuFunction (noLS file_open_function)]
					:+: MenuItem "&Close"	[MenuShortKey 'W', MenuFunction (noLS file_close_function)]
					:+: MenuSeparator		[]
					:+: MenuItem "Print&Setup"[MenuFunction (noLS doPrintSetupDialog)]
					:+: MenuItem "&Print"	[MenuShortKey 'P', MenuFunction (noLS printTable)]
					:+: MenuSeparator		[]
					:+: MenuItem "&Quit"	[MenuShortKey 'Q', MenuFunction quit_function]
					) []
	sort_menu = Menu "&Sort"
					(	MenuItem "Sort by &Function"      [MenuShortKey 'F', MenuFunction (noLS sort_by_function_name)]
					:+:	MenuItem "Sort by &Time"          [MenuShortKey 'T', MenuFunction (noLS sort_by_time_function)]
					:+:	MenuItem "Sort by &Allocation"    [MenuShortKey 'A', MenuFunction (noLS sort_by_allocation_function)]
					:+:	MenuItem "Sort by &Strict calls"  [MenuShortKey 'S', MenuFunction (noLS sort_by_strict_function)]
					:+:	MenuItem "Sort by &Lazy calls"    [MenuShortKey 'L', MenuFunction (noLS sort_by_lazy_function)]
					:+:	MenuItem "Sort by &Curried calls" [MenuShortKey 'C', MenuFunction (noLS sort_by_curried_function)]
					) []
	help_menu = Menu "&Help"
					(	MenuItem "&About..."	[MenuFunction (noLS (showAbout ApplicationName HelpFileName))]
					:+:	MenuItem "&Help..."		[MenuFunction (noLS (showHelp HelpFileName))]
					) []
*/
//--
/*
quit_function :: *(.a,*PSt .b) -> *(.a,*PSt .b);
quit_function (ls,ps) = (ls,closeProcess ps)

error_notice_and_quit :: [.String] *World -> .World;
error_notice_and_quit strings world
	= startIO NDI  0 (okNotice strings) [] world
*/
//-- File funs
/*
open_time_file_from_command_line :: *(PSt *ProgState) -> *PSt *ProgState;
open_time_file_from_command_line ps
	| size commandline == 1
		= ps
		= open_file_function (expand_8_3_names_in_path commandline.[1]) ps
where
	commandline
		= getCommandLine

openFiles [] ps = ps
openFiles [h:t] ps
	= open_file_function (expand_8_3_names_in_path h) ps

file_open_function :: *(PSt *ProgState) -> *PSt *ProgState;
file_open_function pst
	# (maybe_file,pst) = selectInputFile pst
	| isJust maybe_file
		= open_file_function (fromJust maybe_file) pst
	= pst

file_close_function :: *(PSt *ProgState) -> *PSt *ProgState;
file_close_function pst
	// disable menus
	// close window
	// enable menus
	# pst = appPLoc (\p->{p & info = NoProfileInfo}) pst
	= pst

open_profile_window pst
	# (wId,pst)					= accPLoc (\p=:{wind}->(wind,p)) pst
	# {w=screen_size_x}			= maxFixedWindowSize
	# ((window_look,window_height),pst)
								= window_update_function pst
	# profile_window			= Window ""
									header
									[ WindowPos (LeftTop,OffsetVector{vx=(screen_size_x-windowSize.w)>>1, vy=10})
									, WindowOuterSize windowSize
									//{w=WindowWidth,h=if (window_height<=screen_size_y-40) window_height (screen_size_y-40)}
									, WindowViewDomain {zero & corner2={x=windowSize.w,y=window_height}}
									, WindowHScroll (stdScrollFunction Horizontal 4)
									, WindowVScroll (stdScrollFunction Vertical 4)
									, WindowLook True window_look
									, WindowClose (noLS file_close_function)
									, WindowId wId
									, WindowItemSpace 0 0 
									]
	// disable 'Open'
	// open profile_window
	# (err,pst)					= openWindow undef profile_window pst
	= pst
where
	header = fn :+: ts :+: tp :+: ab :+: ap :+: sn :+: ln :+: cn
	fn = ButtonControl "Function"		[ControlWidth (PixelWidth WidthFstColumn), ControlPos (LeftTop,zero), ControlFunction (noLS sort_by_function_name)]
	ts = ButtonControl "Time(s)"		[ControlWidth (PixelWidth (Offset2-Offset1)),ControlFunction (noLS sort_by_time_function)]
	tp = ButtonControl "Time(%)"		[ControlWidth (PixelWidth (Offset3-Offset2)),ControlFunction (noLS sort_by_time_function)]
	ab = ButtonControl "Alloc(bytes)"	[ControlWidth (PixelWidth (Offset4-Offset3)),ControlFunction (noLS sort_by_allocation_function)]
	ap = ButtonControl "Alloc(%)"		[ControlWidth (PixelWidth (Offset5-Offset4)),ControlFunction (noLS sort_by_allocation_function)]
	sn = ButtonControl "Strict(#)"		[ControlWidth (PixelWidth (Offset6-Offset5)),ControlFunction (noLS sort_by_strict_function)]
	ln = ButtonControl "Lazy(#)"		[ControlWidth (PixelWidth (Offset7-Offset6)),ControlFunction (noLS sort_by_lazy_function)]
	cn = ButtonControl "Curried(#)"		[ControlWidth (PixelWidth (Offset8-Offset7)),ControlFunction (noLS sort_by_curried_function)]

//	body cId = CompoundControl NilLS [ControlLook,ControlId cId,ControlViewSize {w=400,h=200} ]

open_file_function :: {#.Char} *(PSt *ProgState) -> *PSt *ProgState;
open_file_function file_name pst
	# pst						= maybe_save_function pst
	# ((open_ok,profile),pst)	= accFiles (open_profile file_name) pst
 	| not open_ok
		# pst = trace_n "open_file_function failed" pst
		= pst
	# (total_strict_calls,total_lazy_calls,total_curried_calls,total_allocation,total_time)
								= sum_time_and_allocation profile
	# (formatted_profile,total_profile)
								= format_profile total_strict_calls total_lazy_calls total_curried_calls total_allocation total_time profile
	# formatted_profile			= sortBy ge_profile_time formatted_profile
	// Save read profile to program state
	# pst						= appPLoc (\p->{p & info = ProfileInfo formatted_profile total_profile}) pst
	// Do visual stuff
	# ((window_look,window_height),pst)
								= window_update_function pst
	# (wId,pst)					= accPLoc (\p=:{wind}->(wind,p)) pst
	// disable 'Open'
	// open profile_window
	# pst						= appPIO (setWindowLook wId True (True,window_look)) pst
	# pst						= appPIO (setWindowViewDomain wId {zero & corner2={x=780,y=window_height}}) pst
	// enable menu 'Sort'
	// enable 'Close,Print'
	= pst
*/
sum_time_and_allocation :: ![.Profile] -> .(Int,Int,Int,Int,Real);
sum_time_and_allocation l = foldl add_time_and_allocation (0,0,0,0,0.0) l
where
	add_time_and_allocation (s,l,c,a,t) {function_name,n_strict_calls,n_lazy_calls,n_curried_calls,n_allocated_words,time}
		| n_allocated_words>=0
			= (s+n_strict_calls,l+n_lazy_calls,c+n_curried_calls,a+n_allocated_words,t+time)
			= (s+n_strict_calls,l+n_lazy_calls,c+n_curried_calls,a,t+time)

totals_per_module :: ![.Profile] -> [.Profile]
totals_per_module []
	= []
totals_per_module [f=:{module_name}:l]
	# (functions,l) = split_at_next_module l
	# functions = [f:functions]
	# (total_strict_calls,total_lazy_calls,total_curried_calls,total_allocation,total_time) = sum_time_and_allocation functions
	# new_module =
			{ module_name=module_name
			, function_name="Module "+++module_name
			, n_strict_calls=total_strict_calls
			, n_lazy_calls=total_lazy_calls
			, n_curried_calls=total_curried_calls
			, n_allocated_words=total_allocation
			, time=total_time
			}
	= [new_module:totals_per_module l]
where
	split_at_next_module []
		= ([],[])
	split_at_next_module l=:[f=:{module_name=m}:t]
		| m==module_name
			# (functions,l) = split_at_next_module t
			= ([f:functions],l)
			= ([],l)

//--
/*
maybe_save_function :: *(PSt *ProgState) -> *PSt *ProgState;
maybe_save_function pst
	# (info,pst) = accPLoc (\p=:{info}->(info,p)) pst
	| isNoProfile info
		= pst
	= file_close_function pst
*/
// File i/o

open_profile :: {#.Char} !*a -> *((.Bool,[.Profile]),!*a) | FileSystem a;
open_profile file_name files
	# (open_ok,input_file,files)	= fopen file_name FReadText files
	| not open_ok
		= ((False,[]),files)
	# (profile,input_file)			= read_profile input_file
	  (_,files)						= fclose input_file files
	= ((True,profile),files)
where
	read_profile :: *File -> ([.Profile],.File);
	read_profile file
		# (compute_time_function,file) = get_compute_time_function file
		= read_function_profiles compute_time_function file
	
	read_function_profiles :: (.(Int,Int,Int) -> .Real) *File -> ([.Profile],.File);
	read_function_profiles compute_time_function file
		# (ok,function_profile,file) = read_function_profile file
		| not ok
			= ([],file)
			# (profile,file) = read_function_profiles compute_time_function file
			= ([function_profile : profile],file)
	where
		read_function_profile file
			# (ok,module_name,file) = read_function_name file
			| not ok
				= error file
			# (ok,function_name,file) = read_function_name file
			| not ok
				= error file
			# (ok,n_strict_calls,file)=freadi file
			| not ok
				= error file
			# (ok,n_lazy_calls,file)=freadi file
			| not ok
				= error file
			# (ok,n_curried_calls,file)=freadi file
			| not ok
				= error file
			# (ok,n_profiler_calls,file)=freadi file
			| not ok
				= error file
			# (ok,n_allocated_words,file)=freadi file
			| not ok
				= error file
			# (ok,time_hi,file)=freadi file
			| not ok
				= error file
			# (ok,time_lo,file)=freadi file
			| not ok
				# time_lo=time_hi
				# time_hi=0
				# time = compute_time_function (time_hi,time_lo,n_profiler_calls)
				=	(True,
					{ module_name		= module_name
					, function_name		= function_name
					, n_strict_calls	= n_strict_calls
					, n_lazy_calls		= n_lazy_calls
					, n_curried_calls	= n_curried_calls
					, n_allocated_words	= n_allocated_words
					, time				= time
					},file)
			# (ok,c,file) = freadc file
			| not ok || c<>'\n'
				= error file
				# time = compute_time_function (time_hi,time_lo,n_profiler_calls)
				=	(True,
					{ module_name		= module_name
					, function_name		= function_name
					, n_strict_calls	= n_strict_calls
					, n_lazy_calls		= n_lazy_calls
					, n_curried_calls	= n_curried_calls
					, n_allocated_words	= n_allocated_words
					, time				= time
					},file)
		where
				error file = (False,abort "error in read_function_profile",file)
		
		read_function_name :: !*File -> (!Bool,!String,!*File)
		read_function_name file
			# (ok,c,file) = freadc file
			| not ok || c==' ' || c=='\n'
				= (False,"",file)
				# (acc,file) = read_function_name [c] file
				= (True,{c \\ c <- reverse acc},file)
		where
			read_function_name acc file
				# (ok,c,file) = freadc file
				| not ok || c == ' ' || c == '\n' = (acc,file)
				= read_function_name [c:acc] file

//-- Sorting funs

ge_profile_time :: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_time {f_time = time1}			{f_time = time2}			= time1 >= time2

le_profile_name :: !.FormattedProfile !.FormattedProfile -> Bool;
le_profile_name {f_function_name = name1}	{f_function_name = name2}	= name1 <= name2

ge_profile_byte :: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_byte {f_n_allocated_words = words1} {f_n_allocated_words = words2} = words1 >= words2

ge_profile_strict :: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_strict {f_n_strict_calls = strict1} {f_n_strict_calls = strict2} = strict1 >= strict2

ge_profile_lazy :: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_lazy {f_n_lazy_calls = lazy1} {f_n_lazy_calls = lazy2} = lazy1 >= lazy2

ge_profile_curried :: !.FormattedProfile !.FormattedProfile -> Bool;
ge_profile_curried {f_n_curried_calls = curry1} {f_n_curried_calls = curry2} = curry1 >= curry2

g_profile_time :: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_time {f_time = time1}			{f_time = time2}			= time1 > time2

l_profile_name :: !.FormattedProfile !.FormattedProfile -> Bool;
l_profile_name {f_function_name = name1}	{f_function_name = name2}	= name1 < name2

l_module_name :: !.FormattedProfile !.FormattedProfile -> Bool;
l_module_name {f_module_name = name1}	{f_module_name = name2}	= name1 < name2

le_module_name :: !.Profile !.Profile -> Bool;
le_module_name {module_name = name1}	{module_name = name2}	= name1 <= name2

g_profile_byte :: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_byte {f_n_allocated_words = words1} {f_n_allocated_words = words2} = words1 > words2

g_profile_strict :: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_strict {f_n_strict_calls = strict1} {f_n_strict_calls = strict2} = strict1 > strict2

g_profile_lazy :: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_lazy {f_n_lazy_calls = lazy1} {f_n_lazy_calls = lazy2} = lazy1 > lazy2

g_profile_curried :: !.FormattedProfile !.FormattedProfile -> Bool;
g_profile_curried {f_n_curried_calls = curry1} {f_n_curried_calls = curry2} = curry1 > curry2
/*
sort_by_time_function pst :== sort_and_redraw_window ge_profile_time pst
sort_by_function_name pst :== sort_and_redraw_window le_profile_name pst
sort_by_allocation_function pst	:== sort_and_redraw_window ge_profile_byte pst
sort_by_strict_function pst	:== sort_and_redraw_window ge_profile_strict pst
sort_by_lazy_function pst :== sort_and_redraw_window ge_profile_lazy pst
sort_by_curried_function pst :== sort_and_redraw_window ge_profile_curried pst

sort_and_redraw_window :: (FormattedProfile -> FormattedProfile -> .Bool) *(PSt *ProgState) -> *PSt *ProgState;
sort_and_redraw_window compare_function pst
	# (info,pst)			= accPLoc (\p=:{info}->(info,p)) pst
	# (ProfileInfo formatted_profile total_profile) = info
	# formatted_profile		= sortBy compare_function formatted_profile
	# pst 					= appPLoc (\p->{p & info = ProfileInfo formatted_profile total_profile}) pst
	# ((look,_),pst)		= window_update_function pst
	# (wId,pst)				= accPLoc (\p=:{wind}->(wind,p)) pst
	# pst					= appPIO (setWindowLook wId True (True,look)) pst
	= pst
*/
//-- Printing look

printTable :: Font !PrintSetup [.FormattedProfile] .FormattedProfile !*(PSt .a) -> *(PrintSetup,*PSt .a);
printTable printFont printSetup functionData sumData ps
//	# (s=:(ProfileInfo functionData sumData),ps)	= accPLoc (\l=:{info}->(info,l)) ps
//	# (printFont,ps)								= accPLoc (\l=:{monaco_font}->(monaco_font,l)) ps
//	# (printSetup,ps)								= accPLoc (\l=:{print_setup}->(print_setup,l)) ps
	# (doesntFit,newPrintSetup,ps)					= print2 True True (generate_pages printFont functionData sumData) printSetup ps
//	# ps											= appPLoc (\l->{l & print_setup = newPrintSetup}) ps
	| doesntFit
		# ps = openNotice (Notice ["The paper is not wide enough to","print all columns.",
										 "Try landscape format."] (NoticeButton "Ok" id) []) ps
		= (newPrintSetup,ps)
	= (newPrintSetup,ps)
where 
	generate_pages printFont functionData sumData { printSetup, jobInfo={ range=(first,last), copies } } picture
 		# {page=page=:{w=maxX,h=maxY},resolution=(horizontal_dpi,_)} = getPageDimensions printSetup True
// 		# widthFstColumn = maxX-Offset8-Pos0
//		# ((line_height,ascent),picture) = formatInfo printFont picture
		# (metrics,picture) = getFontMetrics printFont picture
		# line_height = fontLineHeight metrics
		# nrLinesPerPage = (maxY+1)/line_height
		# pages_without_sum = groupBy (nrLinesPerPage-2) functionData
		# printed_pages = pages_without_sum % (first-1,last-1)
		| isEmpty printed_pages
			= ([],picture,False)
		// ensure, that sum is always printed, regardless of the range of pages the user has choosen
		# (all_but_last,last_page) = splitAt ((length printed_pages)-1) printed_pages
		# last_page_1 = (hd last_page) % (0,nrLinesPerPage-4)	// there needs to be place for the sum line
		# new_last_page = last_page_1 ++ [sumData]
		# pages = all_but_last ++ [new_last_page]
		// ok
		# landscape = maxX > maxY;
		# column_positions=if landscape column_l_positions column_p_positions;
		# column_positions = PCorMac [pos*horizontal_dpi/72 \\ pos<- column_positions] column_positions;
		# page` = {x=maxX,y=maxY}
		# all_drawfuncs 
		    = map (\lines_in_one_page -> 
					print_table column_positions printFont (line_height,metrics) [{corner1=zero,corner2=page`}] {corner1=zero,corner2=page`} lines_in_one_page)
				  pages
		= (	flatten (repeatn copies all_drawfuncs ),
			picture,
			False
		  )
	where
//		column_p_positions = [4,120,240,290,340,400,450,500,550,590]
//		column_l_positions = [4,200,400,460,520,590,650,710,770,830]
		column_p_positions = [2,100,200,260,310,370,420,470,520,570]
		column_l_positions = [3,30*8,44*8,54*8,60*8,68*8,74*8,80*8,86*8,94*8]

		print_table cols printFont (line_height,{fLeading,fAscent,fDescent}) updArea newFrame=:{corner2={x=totalWidth}} lines picture
			# picture	= setPenFont printFont picture
			# picture	= draw_table_header cols (fLeading + fAscent) (fLeading+line_height+2) totalWidth picture
			# delta_text= fDescent + 1
			# picture	= draw_profile_lines delta_text cols lines (fLeading+line_height+4) line_height updArea picture
			= picture

groupBy :: !Int [x] -> [[x]]
groupBy n [] = []
groupBy n l = [(take n l ) : (groupBy n (drop n l))] 

print2 :: .Bool .Bool (PrintInfo -> .(*Picture -> *(.DrawFuns,*Picture,Bool))) PrintSetup *a -> (Bool,PrintSetup,*a) | PrintEnvironments a
print2 doDialog emulateScreen prFun printSetup printEnv
	# (alt,printEnv) = printPagePerPage doDialog emulateScreen 0 initFun stateTransition printSetup printEnv
	= case alt of
		StartedPrinting (_,usedPrintSetup,doesntFit) 	-> (doesntFit,usedPrintSetup,printEnv)
 		Cancelled _										-> (False,printSetup,printEnv)
where
	initFun :: .e .PrintInfo *Picture -> (.(Bool,Point2),(PrintState,*Picture))
  	initFun _ printInfo picture
  		# (drawFuns,picture,doesntFit) = prFun printInfo picture
  		= ((isEmpty drawFuns,zero), ((drawFuns,printInfo.printSetup,doesntFit),picture))

	stateTransition :: ((.[*Picture -> *Picture],.c,.d),*Picture) -> (.(Bool,e),(([*Picture -> *Picture],.c,.d),*Picture)) | zero e;
  	stateTransition (([drawFun:rest],printSetup,doesntFit),picture)
  		= ((isEmpty rest,zero), ((rest,printSetup,doesntFit), drawFun picture))
  	stateTransition (([],printSetup,doesntFit),picture)
  		= ((True,zero), (([],printSetup,doesntFit), picture))

:: PrintState :== (DrawFuns,PrintSetup,Bool)
:: DrawFuns :== [*Picture -> *Picture]
/*
doPrintSetupDialog :: *(PSt *ProgState) -> *PSt *ProgState;
doPrintSetupDialog ps
	# (printSetup,ps)	= accPLoc (\l=:{print_setup}->(print_setup,l)) ps
	# (printSetup,ps)	= printSetupDialog printSetup ps
	= appPLoc (\l->{l & print_setup = printSetup}) ps
*/
//-- Profile Look

//window_update_function :: *(PSt *ProgState) -> *(w:(x:a -> v:(.UpdateState -> u:(*Picture -> .Picture))),*PSt *ProgState), [u <= v, v <= x, v <= w];
/*
window_update_function ps
	# (font,ps) = accPLoc (\p=:{monaco_font}->(monaco_font,p)) ps
	# ({fAscent,fDescent},ps)
				= accPIO (accScreenPicture (getFontMetrics font)) ps
	# (info,ps) = accPLoc (\p=:{info}->(info,p)) ps
	# height	= case info of
					NoProfileInfo									-> 6 + QUICK_FIX
					(ProfileInfo formatted_profile total_profile)	-> 6+(fAscent+fDescent+1)*(2+length formatted_profile)+QUICK_FIX
	= ((drawfun info font,height),ps)
where
	drawfun NoProfileInfo _
		= no_draw
	where
		no_draw ss us=:{updArea} picture 
			= seq (map unfill updArea) picture

	drawfun (ProfileInfo formatted_profile total_profile) window_font
		= draw_profile
	where
		draw_profile ss us=:{updArea,newFrame={corner2={x=totalWidth}}} picture
			# picture		= seq (map unfill updArea) picture
			# (metrics,picture) = getFontMetrics window_font picture
			# line_height	= fontLineHeight metrics
			# picture		= setPenFont window_font picture
			# first_line	= QUICK_FIX
			# picture		= draw_profile_lines cols lines first_line line_height updArea picture
			= picture
		where
			lines = formatted_profile++[total_profile]
			cols = [col0,col1,col2,col3,col4,col5,col6,col7,col8,WidthFstColumn+totalWidth]
*/
QUICK_FIX :== 20
/*
formatInfo :: .Font *Picture -> (.(Int,Int),.Picture);
formatInfo window_font pict
	# ({fAscent,fDescent},pict)=getFontMetrics window_font pict
	# line_height=fAscent+fDescent+1
	= ((line_height,fAscent),pict)
*/
//--

//format_string_r :: .Int u:(a v:Char) -> a Char | Array .a, [u <= v];
format_string_r length string
	# string_size=size string
	| string_size >= length
		= string
		= (createArray (length-string_size) ' ')+++string

format_real :: .Int .Int .Int .Real .Real -> {#Char};
format_real n_spaces n d m r
	| r<0.0
		= format_negative_real (if (n_spaces<1) 0 (dec n_spaces)) n d m (~r)
	# s=toString (toInt (m*r))
	  l=size s
	| l<=d
		= createArray n_spaces ' ' +++ createArray n '0' +++"."+++createArray (d-l) '0'+++s
	| l<=n+d
		= createArray n_spaces ' ' +++ createArray (n+d-l) '0' +++insert_dot_in_string s l d
	| l<=n_spaces+n+d
		= createArray (n_spaces+n+d-l) ' '+++ insert_dot_in_string s l d
		= insert_dot_in_string s l d

format_negative_real :: .Int .Int .Int a a -> {#Char} | * , toInt a;
format_negative_real n_spaces n d m r
	# s=toString (toInt (m*r))
	  l=size s
	| l<=d
		= createArray n_spaces ' ' +++"-"+++ createArray n '0' +++"."+++ createArray (d-l) '0' +++s
	| l<=n+d
		= createArray n_spaces ' ' +++"-"+++ createArray (n+d-l) '0' +++insert_dot_in_string s l d
	| l<=n_spaces+n+d
		= createArray (n_spaces+n+d-l) ' ' +++ "-"+++insert_dot_in_string s l d
		= "-"+++insert_dot_in_string s l d

insert_dot_in_string :: {#.Char} .Int .Int -> {#Char};
insert_dot_in_string s l d = s % (0,l-1-d) +++"."+++ s % (l-d,l-1)

format_profile :: .Int .Int .Int .Int .Real [.Profile] -> ([.FormattedProfile],.FormattedProfile);
format_profile total_strict_calls total_lazy_calls total_curried_calls total_allocation total_time profile_list
	= ([format_profile p \\ p<-profile_list],
	   { f_module_name			= "All Modules"
	   , f_function_name		= "Total"
	   , f_n_strict_calls		= total_strict_calls
	   , f_n_lazy_calls			= total_lazy_calls
	   , f_n_curried_calls		= total_curried_calls
	   , f_n_allocated_words	= total_allocation
	   , f_alloc_percentage		= 100.0
	   , f_time					= total_time
	   , f_time_percentage		= 100.0
	   })
where
	format_profile {module_name,function_name,n_strict_calls,n_lazy_calls,n_curried_calls,n_allocated_words,time} =
		{ f_module_name			= module_name
		, f_function_name		= function_name
		, f_time				= time
		, f_time_percentage		= (time*100.0)/total_time
		, f_n_allocated_words	= n_allocated_words
		, f_alloc_percentage	= (toReal (n_allocated_words)*100.0)/toReal total_allocation
		, f_n_strict_calls		= n_strict_calls
		, f_n_lazy_calls		= n_lazy_calls
		, f_n_curried_calls		= n_curried_calls
		}

n_words_to_n_bytes_string n_words
	| n_words>0
		| n_words<536870912 /* 1<<29 */
			= toString (n_words<<2);
			# n_words_d_25=n_words/25;
			# r=n_words-25*n_words_d_25;
			# r1=r/10;
			# r0=r-10*r1;
			= toString n_words_d_25+++{toChar (48+r1),toChar (48+r0)};
		| n_words>= -536870912 /* -(1<<29) */
			= toString (n_words<<2);
			# n_words_d_25=n_words/25;
			# r= ~(n_words-25*n_words_d_25);
			# r1=r/10;
			# r0=r-10*r1;
			= toString n_words_d_25+++{toChar (48+r1),toChar (48+r0)};

//-- Draw funs

(>:) infixl
(>:) f g:== g f

drawLeft :: !.Point2 !.{#Char} !*Picture -> *Picture;
drawLeft position=:{x} s picture
	# (width,picture)	= getPenFontStringWidth s picture
	= drawAt {position & x = x - width} s picture


myGrey = RGB {r=MaxRGB*9/10,g= MaxRGB*9/10,b= MaxRGB*9/10}

draw_profile_lines :: .Int [.Int] ![.FormattedProfile] .Int .Int UpdateArea *Picture -> *Picture;
draw_profile_lines delta_text cols lines top line_height area picture
	# y = top + line_height - delta_text
	= draw_profile_lines False lines y picture
where
//	delta_text = 2
	
	in_area y [{corner1={y=y1},corner2={y=y2}}:areas]
		= (y >= y1-line_height && y <= y2+line_height) || in_area y areas
	in_area y []
		= False
	
	draw_profile_lines _ [] y picture
		= picture
	draw_profile_lines background_box [{f_module_name,f_function_name,f_time,f_time_percentage,f_n_allocated_words,f_alloc_percentage,f_n_strict_calls,f_n_lazy_calls,f_n_curried_calls}:lines] y picture
		| not (in_area y area)
			= draw_profile_lines (not background_box) lines (y+line_height) picture
		# y_pos
			= y
		# picture 
			= case background_box of
				True
					# picture
						= setPenColour myGrey picture
					# picture
						= fill {corner1={x=col0,y=y_pos-line_height + delta_text},corner2={x=col9,y=y_pos + delta_text}} picture
					-> setPenColour Black picture
				False
//					# picture
//						= setPenColour White picture
					# picture
						= unfill {corner1={x=col0,y=y_pos-line_height + delta_text},corner2={x=col9,y=y_pos + delta_text}} picture
					-> picture	//setPenColour Black picture
		# (cs1,picture) = cut_string f_module_name wdthFstCol picture
		# (cs2,picture) = cut_string f_function_name wdthSndCol picture
		# picture=picture
			>: drawAt {x=col0+5,y=y} cs1
			>: drawAt {x=col1+5,y=y} cs2
			>: drawLeft {x=col3-4,y=y} (format_real 0 1 6 1000000.0 f_time)
			>: drawLeft {x=col4-4,y=y} (format_real 0 2 3 1000.0 f_time_percentage)
			>: drawLeft {x=col5-4,y=y} (n_words_to_n_bytes_string f_n_allocated_words)
			>: drawLeft {x=col6-4,y=y} (format_real 0 2 3 1000.0 (f_alloc_percentage))
			>: drawLeft {x=col7-4,y=y} (toString f_n_strict_calls)
			>: drawLeft {x=col8-4,y=y} (toString f_n_lazy_calls)
			>: drawLeft {x=col9-4,y=y} (toString f_n_curried_calls)
		= draw_profile_lines (not background_box) lines (y+line_height) picture

	col0 = cols!!0//Pos0
	col1 = cols!!1//wdthFstCol+Offset2
	col2 = cols!!2//wdthFstCol+Offset3
	col3 = cols!!3//wdthFstCol+Offset4
	col4 = cols!!4//wdthFstCol+Offset5
	col5 = cols!!5//wdthFstCol+Offset6
	col6 = cols!!6//wdthFstCol+Offset7
	col7 = cols!!7//wdthFstCol+Offset8
	col8 = cols!!8//wdthFstCol+totalWidth
	col9 = cols!!9
	col10 = cols!!10
	
	wdthFstCol = col1 - col0 - 10
	wdthSndCol = col2 - col1 - 10

// poging tot geinverteerde versie van draw_profile_lines
draw_profile_lines` :: .Int [.Int] ![.FormattedProfile] .Int .Int !UpdateArea *Picture -> *Picture;
draw_profile_lines` _ _ _ _ _ [] picture = picture
draw_profile_lines` _ _ [] _ _ _ picture = picture
draw_profile_lines` delta_text cols lines top line_height [area:rest] picture
	# (s,f) = rect_lines area
	# picture = draw_profile_lines (isEven s) s f (top + line_height + (s * line_height) - delta_text) picture
	
	= draw_profile_lines` delta_text cols lines top line_height rest picture
where
//	delta_text = 2
	
//	base_y = top + line_height - delta_text
	maxline = dec (length lines)
	
	rect_lines {corner1={y=y1},corner2={y=y2}}
		= (max 0 ((y1-top)/line_height), min maxline ((y2-top)/line_height))
	
	draw_profile_lines
		background_box
		s f
		y_pos picture
		| s > f = picture
		# {f_module_name,f_function_name,f_time,f_time_percentage,f_n_allocated_words,f_alloc_percentage,f_n_strict_calls,f_n_lazy_calls,f_n_curried_calls} = lines!!s
		# picture 
			= case background_box of
				True
					# picture
						= setPenColour myGrey picture
					# picture
						= fill {corner1={x=col0,y=y_pos-line_height + delta_text},corner2={x=col10,y=y_pos + delta_text}} picture
					-> setPenColour Black picture
				False
//					# picture
//						= setPenColour White picture
					# picture
						= unfill {corner1={x=col0,y=y_pos-line_height + delta_text},corner2={x=col10,y=y_pos + delta_text}} picture
					-> picture	//setPenColour Black picture
		# (cs1,picture) = cut_string f_module_name wdthFstCol picture
		# (cs2,picture) = cut_string f_function_name wdthSndCol picture
		# picture=picture
			>: drawAt {x=col0+5,y=y_pos} cs1
			>: drawAt {x=col1+5,y=y_pos} cs2
			>: drawClipLeft (col2+5) {x=col3-5,y=y_pos} (format_real 6 1 6 1000000.0 f_time)
			>: drawClipLeft (col3+5) {x=col4-5,y=y_pos} (format_real 2 2 3 1000.0 f_time_percentage)
			>: drawClipLeft (col4+5) {x=col5-5,y=y_pos} (format_string_r 12 (n_words_to_n_bytes_string f_n_allocated_words))
			>: drawClipLeft (col5+5) {x=col6-5,y=y_pos} (format_real 2 2 3 1000.0 (f_alloc_percentage))
			>: drawClipLeft (col6+5) {x=col7-5,y=y_pos} (format_string_r 10 (toString f_n_strict_calls))
			>: drawClipLeft (col7+5) {x=col8-5,y=y_pos} (format_string_r 10 (toString f_n_lazy_calls))
			>: drawClipLeft (col8+5) {x=col9-5,y=y_pos} (format_string_r 10 (toString f_n_curried_calls))
		= draw_profile_lines (not background_box) (inc s) f (y_pos+line_height) picture

	drawClipLeft :: !.Int !.Point2 !.{#Char} !*Picture -> *Picture;

//	drawClipLeft _ position str picture = drawLeft position str picture
	
	drawClipLeft minx position=:{x,y} str picture
		= appClipPicture (toRegion {corner1={x=minx,y=y-20},corner2={x=x,y=y+20}}) (drawLeft position str) picture
	
//	drawClipLeft minx position=:{x,y} str picture
//		= appClipPicture (toRegion {corner1={x=minx,y=y-20},corner2={x=x,y=y+20}}) (drawAt {position & x = minx} str) picture

/*
	drawClipLeft minx position=:{x} str picture
		# (width,picture)	= getPenFontStringWidth str picture
		| width < wid
			= drawAt {position & x = x - width} str picture
		# (cs,picture) = cut_string str wid picture
		# (width,picture)	= getPenFontStringWidth cs picture
		| width < wid
			= drawAt {position & x = x - width} cs picture
		= picture
	where
		wid = x - minx
*/	

	col0 = cols!!0//Pos0
	col1 = cols!!1//wdthFstCol+Offset2
	col2 = cols!!2//wdthFstCol+Offset3
	col3 = cols!!3//wdthFstCol+Offset4
	col4 = cols!!4//wdthFstCol+Offset5
	col5 = cols!!5//wdthFstCol+Offset6
	col6 = cols!!6//wdthFstCol+Offset7
	col7 = cols!!7//wdthFstCol+Offset8
	col8 = cols!!8//wdthFstCol+totalWidth
	col9 = cols!!9
	col10 = cols!!10
	
	wdthFstCol = col1 - col0 - 10
	wdthSndCol = col2 - col1 - 10

Pos0:==4
WidthFstColumn :== 280
WidthSndColumn :== 280
Offset1:==0
Offset2:==100
Offset3:==160
Offset4:==240
Offset5:==280
Offset6:==330
Offset7:==395
Offset8:==475

col0 = Pos0
col1 = col0 + WidthSndColumn
col2 = WidthFstColumn+ WidthSndColumn+Offset2
col3 = WidthFstColumn+ WidthSndColumn+Offset3
col4 = WidthFstColumn+ WidthSndColumn+Offset4
col5 = WidthFstColumn+ WidthSndColumn+Offset5
col6 = WidthFstColumn+ WidthSndColumn+Offset6
col7 = WidthFstColumn+ WidthSndColumn+Offset7
col8 = WidthFstColumn+ WidthSndColumn+Offset8
//col8 = WidthFstColumn+totalWidth

cut_string :: .String .Int *Picture -> (String,*Picture);
// hoef je alleen opnieuw te bepalen bij verplaatsen colom dus niet in standaard look...?
// analoog geldt voor formatting funs...
cut_string str width pic
	# (wid,pic) = getPenFontStringWidth str pic
	| wid <= width
		= (str,pic)
	# (fitting_string,pic) = firstAfterList f l pic
	| isNothing fitting_string
		= ("",pic)
//		= abort "This program has a bug. It was wrongly assumed, that the first column is wide enough" 
	= (fromJust fitting_string,pic)
where
	f cut_str pic
		# (w,pic) = getPenFontStringWidth cut_str pic
		= (w > width,pic)

	l = [(str % (0,n))+++"..." \\ n <- reverse [0..(size str)-1]]

	firstAfterList f [] s = (Nothing,s)
	firstAfterList f [h:t] s
		# (b,s) = f h s
		| b
			= firstAfterList f t s
		= (Just h,s)

//draw_table_header :: !Int .Int .Int .Int *Picture -> *Picture
draw_table_header cols y line_y window_width picture
	= picture
//		>: unfill {corner1={x=0,y=0},corner2={x=window_width,y=line_y}}
		>: drawAt {x=cols!!0+5,y=y} "Module"
		>: drawAt {x=cols!!1+5,y=y} "Function"
		>: drawLeft {x=cols!!3,y=y} "Time(s)"
		>: drawLeft {x=cols!!4,y=y} "Time(%)"
		>: drawLeft {x=cols!!5,y=y} "Alloc(bytes)"
		>: drawLeft {x=cols!!6,y=y} "Alloc(%)"
		>: drawLeft {x=cols!!7,y=y} "Strict(n)"
		>: drawLeft {x=cols!!8,y=y} "Lazy(n)"
		>: drawLeft {x=cols!!9,y=y} "Curried(n)"
		>: drawLine {x=0,y=line_y} {x=window_width,y=line_y}

